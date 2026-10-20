# linux_stuff

## apt repositories

`bin/apt-repo-*.sh` add third-party apt repositories the modern way and
install what each one is for.  Run them as root; they are safe to re-run.

Each script:

- fetches the vendor's key over https and keeps only the pinned primary key
  (with its subkeys), refusing expired or revoked keys;
- installs it as `/etc/apt/keyrings/NAME.gpg` and writes a deb822
  `/etc/apt/sources.list.d/NAME.sources` signed by only that key;
- removes whatever earlier setups of the same repository left behind:
  old `.list` files, disabled entries, `~`, `.save` and `.distUpgrade`
  copies, and their keyrings once nothing else uses them.  Files owned by a
  package are never touched.

| Script | Repository | Installs |
|---|---|---|
| `apt-repo-charlieh0tel.sh` | charlieh0tel.github.io/apt-repo | nothing; `apt install` what you need |
| `apt-repo-chrome.sh` | Google Chrome | `google-chrome-stable` |
| `apt-repo-docker.sh` | Docker CE | `docker-ce` and plugins, replacing Ubuntu's Docker packages |
| `apt-repo-github-cli.sh` | GitHub CLI | `gh` |
| `apt-repo-google-cloud.sh` | Google Cloud CLI | `google-cloud-cli` |
| `apt-repo-kicad.sh` | KiCad 10.0 PPA | `kicad`, pinned over Ubuntu's KiCad |
| `apt-repo-mozilla.sh` | Mozilla | `firefox`, pinned over Ubuntu's, and removes the snap |
| `apt-repo-netdata.sh` | Netdata stable | `netdata` with cloud and statistics off; `--reset` wipes it first |
| `apt-repo-signal.sh` | Signal | `signal-desktop` |
| `apt-repo-tailscale.sh` | Tailscale | `tailscale` |

Chrome and Tailscale manage their own keys.  `apt-repo-tailscale.sh` hands
the repository over to the key from `tailscale-archive-keyring`, and
`apt-repo-chrome.sh` leaves Chrome's source and key to Chrome's own scripts,
only setting `repo_add_once` in `/etc/default/google-chrome`.  Both use a
pinned key just to bootstrap a fresh install.

`bin/apt-repo-lib.sh` holds the shared code.  Setting `APT_REPO_ROOT` points
every file the scripts touch at a test tree.

### Cleaning up old keys

`bin/apt-keyrings-migrate.py` tidies up after older setups:

- moves keyrings that a source names but no package owns into
  `/etc/apt/keyrings`, and updates the sources;
- deletes keys in `/etc/apt/trusted.gpg.d` and `/etc/apt/trusted.gpg` that no
  package owns, since apt trusts those for every repository;
- lists keyrings no source uses, and files apt ignores in `sources.list.d`;
  `--delete-orphans` deletes them.

Disabled sources count as using their keys, and keys that a package's
scripts or a cron job manage (such as Chrome's) are left alone.  Everything
changed or deleted is backed up under
`/var/backups/apt-keyrings-migrate-TIMESTAMP` first.

```
sudo bin/apt-keyrings-migrate.py -n                  # show what would change
sudo bin/apt-keyrings-migrate.py --delete-orphans --update
```
