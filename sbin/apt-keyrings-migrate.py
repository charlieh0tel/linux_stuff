#!/usr/bin/env python3
"""Moves local apt keyrings to /etc/apt/keyrings and removes risky leftovers.

1. Keyrings that a source names in signed-by, that no package owns and no
   maintainer or cron script manages, move to /etc/apt/keyrings and the
   sources follow.
2. Keys in /etc/apt/trusted.gpg.d and /etc/apt/trusted.gpg that no package
   owns are deleted: apt trusts them for every repository.
3. Keyrings that no source names, and files in sources.list.d that apt
   ignores, are listed, or deleted with --delete-orphans.

Disabled sources count as using their keyrings.  Everything changed or
deleted is copied under /var/backups/apt-keyrings-migrate-TIMESTAMP first.
"""

import argparse
import dataclasses
import datetime
import difflib
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

SOURCES_LIST = "/etc/apt/sources.list"
SOURCES_D = "/etc/apt/sources.list.d"
OLD_KEYRINGS = "/usr/share/keyrings"
NEW_KEYRINGS = "/etc/apt/keyrings"
TRUSTED_D = "/etc/apt/trusted.gpg.d"
TRUSTED = "/etc/apt/trusted.gpg"
DPKG_INFO = "/var/lib/dpkg/info"
CRON_DIRS = [
    "/etc/cron.d",
    "/etc/cron.hourly",
    "/etc/cron.daily",
    "/etc/cron.weekly",
    "/etc/cron.monthly",
]
BACKUPS = "/var/backups"
MAINTAINER_SCRIPTS = (".preinst", ".postinst", ".prerm", ".postrm", ".config")

# The file names apt reads in sources.list.d; it ignores everything else.
APT_SOURCE_NAME = re.compile(r"^[A-Za-z0-9_.-]+\.(list|sources)$")
LIST_ENTRY = re.compile(r"^\s*(#\s*)?(deb|deb-src)\s+(.*)$")
LIST_SIGNED_BY = re.compile(r"(signed-by=)([^\s\]]+)")
DEB822_SIGNED_BY = re.compile(r"^(Signed-By:[ \t]*)(/.*)$", re.MULTILINE)


@dataclasses.dataclass
class Entry:
    file: str
    enabled: bool
    uri: str
    keys: list
    inline_key: bool = False


class Tree:
    """Maps real paths to files under --root."""

    def __init__(self, root):
        self.root = os.path.abspath(root)

    def fs(self, path):
        return os.path.join(self.root, path.lstrip("/"))

    def exists(self, path):
        return os.path.lexists(self.fs(path))

    def read(self, path):
        with open(self.fs(path), encoding="utf-8", errors="surrogateescape") as f:
            return f.read()

    def listdir(self, path):
        try:
            names = sorted(os.listdir(self.fs(path)))
        except FileNotFoundError:
            return []
        return [os.path.join(path, n) for n in names]

    def files(self, path):
        return [
            p
            for p in self.listdir(path)
            if os.path.isfile(self.fs(p)) or os.path.islink(self.fs(p))
        ]


def path_keys(value):
    """Returns the absolute paths in a signed-by value, skipping fingerprints."""
    return [v for v in re.split(r"[\s,]+", value) if v.startswith("/")]


def parse_list(path, text):
    entries = []
    for line in text.splitlines():
        m = LIST_ENTRY.match(line)
        if not m:
            continue
        rest = m.group(3)
        keys = []
        if rest.startswith("["):
            options, _, rest = rest[1:].partition("]")
            for option in options.split():
                name, _, value = option.partition("=")
                if name == "signed-by":
                    keys += path_keys(value)
        uri = (rest.split() or [""])[0]
        entries.append(Entry(path, m.group(1) is None, uri, keys))
    return entries


def parse_deb822(path, text):
    entries = []
    for stanza in re.split(r"\n[ \t]*\n", text):
        fields = {}
        field = None
        for line in stanza.splitlines():
            if line.startswith("#"):
                continue
            if line[:1] in (" ", "\t") and field:
                fields[field] += "\n" + line.strip()
                continue
            name, sep, value = line.partition(":")
            if sep:
                field = name.strip().lower()
                fields[field] = value.strip()
        if "uris" not in fields:
            continue
        signed_by = fields.get("signed-by", "")
        inline = "\n" in signed_by
        entries.append(
            Entry(
                path,
                fields.get("enabled", "yes").lower() != "no",
                fields["uris"],
                [] if inline else path_keys(signed_by),
                inline,
            )
        )
    return entries


def source_files(tree):
    """Returns (files apt reads, other files in sources.list.d)."""
    read, stray = [], []
    if tree.exists(SOURCES_LIST):
        read.append(SOURCES_LIST)
    for path in tree.files(SOURCES_D):
        if APT_SOURCE_NAME.match(os.path.basename(path)):
            read.append(path)
        else:
            stray.append(path)
    return read, stray


def parse_sources(tree, files):
    entries = []
    for path in files:
        text = tree.read(path)
        if path.endswith(".sources"):
            entries += parse_deb822(path, text)
        else:
            entries += parse_list(path, text)
    return entries


def dpkg_owned(tree):
    """Returns the apt keyring paths that installed packages own."""
    owned = set()
    for path in glob.glob(tree.fs(DPKG_INFO) + "/*.list"):
        with open(path, encoding="utf-8", errors="surrogateescape") as f:
            for line in f:
                if line.startswith(("/etc/apt/", OLD_KEYRINGS + "/")):
                    owned.add(line.rstrip("\n"))
    return owned


def script_texts(tree):
    """Returns {path: text} for maintainer and cron scripts."""
    paths = [p for p in tree.files(DPKG_INFO) if p.endswith(MAINTAINER_SCRIPTS)]
    for d in CRON_DIRS:
        paths += tree.files(d)
    texts = {}
    for path in paths:
        try:
            texts[path] = tree.read(path)
        except (OSError, UnicodeDecodeError):
            pass
    return texts


def managed_by(path, scripts):
    return [s for s, text in scripts.items() if path in text]


def rewrite(path, text, moves):
    """Returns text with keyring paths in signed-by values replaced."""

    def swap(value):
        return re.sub(r"[^\s,]+", lambda m: moves.get(m.group(0), m.group(0)), value)

    if path.endswith(".sources"):
        return DEB822_SIGNED_BY.sub(lambda m: m.group(1) + swap(m.group(2)), text)
    out = []
    for line in text.splitlines(keepends=True):
        if LIST_ENTRY.match(line):
            line = LIST_SIGNED_BY.sub(lambda m: m.group(1) + swap(m.group(2)), line)
        out.append(line)
    return "".join(out)


def same_file(a, b):
    with open(a, "rb") as fa, open(b, "rb") as fb:
        return fa.read() == fb.read()


def readable_keyring(path):
    if not shutil.which("gpg"):
        return True
    with tempfile.TemporaryDirectory() as home:
        result = subprocess.run(
            ["gpg", "--batch", "--show-keys", path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=dict(os.environ, GNUPGHOME=home),
        )
    return result.returncode == 0


class Migrator:
    def __init__(self, tree, dry_run):
        self.tree = tree
        self.dry_run = dry_run
        self.errors = 0
        self.backed_up = False
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        self.backup_dir = os.path.join(BACKUPS, "apt-keyrings-migrate-" + stamp)

    def say(self, verb, path, note=""):
        print(f"{verb:7} {path}" + (f"  ({note})" if note else ""))

    def error(self, message):
        print(f"error   {message}", file=sys.stderr)
        self.errors += 1

    def backup(self, path):
        dest = self.tree.fs(os.path.join(self.backup_dir, path.lstrip("/")))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(self.tree.fs(path), dest, follow_symlinks=False)
        self.backed_up = True

    def delete(self, path, note=""):
        self.say("delete", path, note)
        if not self.dry_run:
            self.backup(path)
            os.unlink(self.tree.fs(path))

    def copy(self, src, dest):
        self.say("move", src, "to " + dest)
        if not self.dry_run:
            os.makedirs(self.tree.fs(NEW_KEYRINGS), mode=0o755, exist_ok=True)
            tmp = self.tree.fs(dest) + ".new"
            shutil.copyfile(self.tree.fs(src), tmp)
            os.chmod(tmp, 0o644)
            os.replace(tmp, self.tree.fs(dest))

    def write(self, path, old, new):
        self.say("edit", path)
        diff = difflib.unified_diff(
            old.splitlines(keepends=True),
            new.splitlines(keepends=True),
            path,
            path,
        )
        sys.stdout.writelines("        " + line for line in diff)
        if not self.dry_run:
            self.backup(path)
            fs = self.tree.fs(path)
            tmp = fs + ".new"
            with open(tmp, "w", encoding="utf-8", errors="surrogateescape") as f:
                f.write(new)
            shutil.copymode(fs, tmp)
            os.replace(tmp, fs)

    def run(self, delete_orphans):
        tree = self.tree
        read, stray = source_files(tree)
        entries = parse_sources(tree, read)
        owned = dpkg_owned(tree)
        scripts = script_texts(tree)

        used = {}
        for entry in entries:
            for key in entry.keys:
                used.setdefault(key, []).append(entry)

        # 1. Move keyrings that sources name.
        moves = {}
        for key in sorted(used):
            if os.path.dirname(key) == NEW_KEYRINGS:
                continue
            if not tree.exists(key):
                files = sorted({e.file for e in used[key]})
                self.say("warn", key, "named by " + ", ".join(files) + " but missing")
                continue
            if key in owned:
                continue
            managers = managed_by(key, scripts)
            if managers:
                self.say("keep", key, "managed by " + ", ".join(managers))
                continue
            dest = os.path.join(NEW_KEYRINGS, os.path.basename(key))
            if tree.exists(dest) and not same_file(tree.fs(key), tree.fs(dest)):
                self.error(f"{key}: {dest} exists with other contents; skipped.")
                continue
            if not readable_keyring(tree.fs(key)):
                self.error(f"{key}: gpg cannot read it; skipped.")
                continue
            moves[key] = dest

        for key, dest in moves.items():
            if not tree.exists(dest):
                self.copy(key, dest)
            else:
                self.say("move", key, f"{dest} already has it")
        for path in read:
            old = tree.read(path)
            new = rewrite(path, old, moves)
            if new != old:
                self.write(path, old, new)
        for key in moves:
            self.delete(key, "moved")
        used = {moves.get(k, k) for k in used}

        # 2. Delete globally trusted keys that no package owns.
        trusted = tree.files(TRUSTED_D)
        if tree.exists(TRUSTED):
            trusted.append(TRUSTED)
        for key in trusted:
            if key not in owned and key not in moves:
                self.delete(key, "trusted for every repository")
        for entry in entries:
            if (
                entry.enabled
                and not entry.keys
                and not entry.inline_key
                and not entry.uri.startswith("cdrom:")
            ):
                self.say(
                    "warn",
                    entry.file,
                    f"{entry.uri} has no Signed-By; only package-owned "
                    "global keys can verify it now",
                )

        # 3. Orphans.
        verb = "delete" if delete_orphans else "orphan"
        for d in (OLD_KEYRINGS, NEW_KEYRINGS):
            for key in tree.files(d):
                if key in used or key in owned or key in moves:
                    continue
                managers = managed_by(key, scripts)
                if managers:
                    self.say("keep", key, "managed by " + ", ".join(managers))
                elif delete_orphans:
                    self.delete(key, "no source uses it")
                else:
                    self.say(verb, key, "no source uses it")
        for path in stray:
            if delete_orphans:
                self.delete(path, "apt ignores it")
            else:
                self.say(verb, path, "apt ignores it")

        if self.backed_up:
            print(f"backups in {self.backup_dir}")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "-n", "--dry-run", action="store_true", help="show what would change"
    )
    parser.add_argument(
        "--delete-orphans",
        action="store_true",
        help="delete unused keyrings and files apt ignores in sources.list.d",
    )
    parser.add_argument(
        "--update", action="store_true", help="run apt-get update afterwards"
    )
    parser.add_argument(
        "--root", default="/", help="operate on a copy of the filesystem here"
    )
    args = parser.parse_args()

    testing = os.path.abspath(args.root) != "/"
    if testing and args.update:
        parser.error("--update makes no sense with --root.")
    if not (args.dry_run or testing) and os.geteuid() != 0:
        parser.error("run as root, or use --dry-run.")

    migrator = Migrator(Tree(args.root), args.dry_run)
    migrator.run(args.delete_orphans)

    if args.update and not args.dry_run:
        result = subprocess.run(["apt-get", "update"])
        if result.returncode != 0:
            migrator.error("apt-get update failed; backups are kept for undo.")
    return 1 if migrator.errors else 0


if __name__ == "__main__":
    sys.exit(main())
