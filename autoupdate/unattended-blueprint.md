# Unattended Upgrades Guide

A blueprint for setting up safe, low-resource automatic updates.

---

## 1. Installation & Initialization

Install the necessary packages and enable the background systemd
timers using the native Debian configuration utility.

```bash
sudo apt update
sudo apt install unattended-upgrades needrestart -y
sudo dpkg-reconfigure unattended-upgrades
```
* **Note:** Select **Yes** at the blue prompt to activate the
daily update timers.

---

## 2. Optimized Local Configuration

Create a dedicated local override file.

```bash
sudo ${EDITOR} /etc/apt/apt.conf.d/52unattended-upgrades-local
```

Paste pieces of the following configuration, according to needs and taste.
(`needrestart` is required to restart serivces immediately when
underlying dependencies update.)

```text
// Optional: restrict updates strictly to security patches
Unattended-Upgrade::Allowed-Origins {
    "\({distro_id}:\){distro_codename}-security";
};

// Prevent the server from running out of disk space.
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
APT::Periodic::AutocleanInterval "7";

// Force services to restart in memory rather than full reboot.
Unattended-Upgrade::Automatic-Reboot "false";
Needs-Restart::Command "restart";

// Keep memory usage low (Zero) during the update process.
Unattended-Upgrade::Cache-Commit-Interval "0";

// Only run updates when on main AC power, if applicable.
Unattended-Upgrade::Only-On-AC-Power "true";
```

---

## 3. Locking Updates to a Specific Time (3:00 AM)

Debian applies a default randomized delay that can cause upgrades to
trigger in the middle of the day. To force the upgrade process to run
exclusively at 3:00 AM, override the systemd timer configuration.

```bash
sudo systemctl edit apt-daily-upgrade.timer
```

Paste:

```ini
[Timer]
OnCalendar=
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=0
```
*(The empty `OnCalendar=` line clears the default OS rules
so the specified window takes priority).*


### Apply the Schedule Changes

```bash
sudo systemctl restart apt-daily-upgrade.timer
```
---

## 4. Verification & Testing

### Verify the Next Run Time

Confirm that systemd has locked the next update execution to 3:00 AM:

```bash
systemctl list-timers apt-daily-upgrade.timer
```

### Run a Syntax and Process Dry-Run

Execute a simulation to verify that your new local override
configuration contains no errors or broken syntax:

```bash
sudo unattended-upgrade --dry-run --debug
```

### Review Update Logs

To audit what packages were successfully updated overnight, read the
historical log files using:

```bash
cat /var/log/unattended-upgrades/unattended-upgrades.log
```
