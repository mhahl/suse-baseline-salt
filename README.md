# SUSE Baseline

> SaltStack states + pillar for a focused security/forensics baseline on **openSUSE Tumbleweed** (and modern SUSE).

[![Salt](https://img.shields.io/badge/Salt-3006%2B-blue)](https://saltproject.io/)
[![openSUSE](https://img.shields.io/badge/openSUSE-Tumbleweed%20%7C%20Leap-green)](https://www.opensuse.org/)
[![Goss](https://img.shields.io/badge/Tests-Goss-orange)](https://goss.rocks/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## ✨ Features

This project provides a **modular** baseline for SUSE systems.

| Category     | Modules |
|--------------|---------|
| **System**       | `systemd-resolved`, `timesyncd`, `profile`, `banner`, `updates`, `schedule`, `trivy` |
| **Hardening**    | `usb` |

### Highlights

- **Forensic-ready** bash history and session controls
- **Strong privacy defaults** (DNS-over-TLS + DNSSEC, hardened NTP)
- **Modern security controls** (USB storage blocking)
- **Vulnerability scanning** — daily Trivy OS-package scans with summaries published to the Salt Mine (`trivy.scan_summary`)
- **Overstate-ready scheduling** — hourly mine updates plus a nightly highstate, visible in Overstate's Schedules tab
- **Pillar-driven** — DNS, NTP, USB, schedule, trivy and update behavior are configurable via pillar

---

## 🚀 Quick Start

```bash
# Apply the full baseline
salt '*' state.apply baseline
```

Or include it via your top file / highstate.

---

## 📦 Configuration

All configuration lives in pillar. See the modular structure:

```yaml
# pillar/top.sls
base:
  '*':
    - baseline
```

### Example Pillar

See:
- [`pillar/baseline.sls`](pillar/baseline.sls) — baseline system + hardening settings (usb, ntp, resolved, updates, schedule, trivy) plus top-level `mine_functions` for the Salt Mine

---

## 🛠️ Development & Testing

### On a SUSE VM (Recommended)

```bash
# One-time setup
sudo ./scripts/setup-test-vm.sh

# Run tests
make lint
make goss
make goss-timesyncd
```

### Available Make Targets

| Command                    | Description                     |
|---------------------------|---------------------------------|
| `make lint`               | Run yamllint                    |
| `make goss`               | Run all Goss tests              |
| `make goss-<component>`   | Run tests for a specific module |
| `make install-goss`       | Download Goss binary            |

See the [Makefile](Makefile) for more options.

### CI

Goss tests run in containers on `opensuse-tumbleweed` runners:

- **Baseline** tests: [`.forgejo/workflows/baseline.yml`](.forgejo/workflows/baseline.yml)

The workflow is triggered on push/PR to relevant paths (states, pillar, and the corresponding Goss test files). It lints all YAML with yamllint before applying states and running Goss.

---

## 📁 Project Structure

```
salt/
├── _modules/               # custom execution modules (synced automatically)
│   └── trivy_scan.py       # scan/publish for the trivy module
└── baseline/               # System + hardening (flat: one dir per module)
    ├── init.sls            # includes banner, profile, schedule,
    │                       # systemd-resolved, timesyncd, trivy, updates, usb
    ├── banner/
    ├── profile/
    ├── schedule/           # hourly mine.update + nightly highstate
    ├── systemd-resolved/
    ├── timesyncd/          # NTP via systemd-timesyncd (replaces chrony)
    ├── trivy/              # daily Trivy CVE scans + mine publishing
    ├── updates/
    └── usb/

pillar/
├── baseline.sls            # baseline.* settings + top-level mine_functions
└── top.sls

tests/
├── test_timesyncd.py             # timesyncd drop-in + init render tests
├── test_trivy_map.py             # trivy platform/arch selection render tests
├── test_trivy_scan.py            # pytest unit tests for the trivy_scan module
└── test_systemd_resolved_map.py  # resolved package selection render tests
```

---

## ✅ Verification

After applying the states, run these checks:

```bash
# System
resolvectl status
timedatectl show-timesync --all

# Hardening
lsmod | grep -E 'usb_storage|uas' || true
cat /etc/modprobe.d/99-baseline-usb-storage.conf

# Scheduling (Overstate fleets)
cat /etc/salt/minion.d/_schedule.conf
salt-call schedule.list
salt-call mine.update && salt-call mine.get '*' grains.items

# Vulnerability scanning
ls -la /var/cache/trivy/report.json
salt-call trivy_scan.publish
salt-run mine.get '*' trivy.scan_summary
```

---

## 🖥️ Deploying to Overstate

Overstate is a web UI in front of one Salt master: you accept keys, fire
jobs, and read returns there, while Salt still does the work. This baseline is built to drop into it — states show up
in the file browser, pillar in the pillar browser, and the `schedule` module
feeds the Schedules tab while `mine_functions` feeds the Mine browser.

### 1. Place the trees where the master serves them

| This repo | Overstate dev (`salt-srv/`) | Bare-metal / Quadlet prod |
|---|---|---|
| `salt/baseline/` | `salt-srv/salt/baseline/` | `/srv/salt/baseline/` (or `/var/lib/overstate/srv/salt/baseline/`) |
| `pillar/baseline.sls` | `salt-srv/pillar/baseline.sls` | `/srv/pillar/baseline.sls` (or `/var/lib/overstate/srv/pillar/…`) |
| `pillar/top.sls` | `salt-srv/pillar/top.sls` | `/srv/pillar/top.sls` (or `/var/lib/overstate/srv/pillar/…`) |

Overstate's demo tree (`salt-srv/salt/top.sls` → `demo`) shows the expected
shape. Keep both trees in git and sync them with Overstate's
`scripts/sync-file-roots.sh`; the app only ever reads them.

Deploy from a checkout of this repo on the master host:

```sh
sudo make overstate-deploy
# Custom roots (e.g. an Overstate dev checkout) — no sudo needed
# when you own the target. Use an absolute path: make expands `$H`
# itself, so `~` and `$HOME` do not survive the command line
# (escape as `$$HOME` if you must use it):
make overstate-deploy OVERSTATE_SRV=/Users/mhahl/Developer/overstate/salt-srv
```

The target copies `salt/baseline/`, `salt/_modules/`, and
`pillar/baseline.sls` into place, creates missing top files with a
baseline entry, and never touches existing top files — if one lacks a
baseline entry it prints the exact lines to add. Re-running is safe.

> **Fresh prod installs:** `install.sh` seeds only the demo files, flattened
> at `/var/lib/overstate/srv/` (`top.sls` + `demo.sls` at the root) — that
> location is *outside* the master's file/pillar roots. The target creates
> the `salt/` + `pillar/` subdirs; fold demo into the live top file with
> `sudo cp /var/lib/overstate/srv/demo.sls /var/lib/overstate/srv/salt/demo.sls`.
>
> Use plain copies, not symlinks: the container only sees inside its
> `/var/lib/overstate/srv` bind mount, so links pointing elsewhere on the
> host dangle inside the master.

### 2. Let the master serve pillar

Overstate ships file roots only — add pillar roots on the master:

```yaml
# /etc/salt/master.d/pillar.conf  (adapt paths to your layout)
pillar_roots:
  base:
    - /srv/pillar
```

```yaml
# .../pillar/top.sls (this repo's file, served as-is)
base:
  '*':
    - baseline
```

Pillar provides two things here: `baseline.*` settings for the states, and
top-level `mine_functions` (`grains.items`, `network.ip_addrs`), which
minions read straight from pillar — no minion config drop-ins needed.

### 3. Include baseline in the state top file

`state.apply baseline` works without touching top, but the **nightly
highstate runs `state.highstate`**, so the top file must include it:

```yaml
# salt-srv/salt/top.sls (dev) — keep demo, add baseline
base:
  '*':
    - demo
    - baseline
```

### 4. Enroll minions and apply from the Overstate UI

1. Install the minion, point it at the master, and **accept the key by
   fingerprint** (`auto_accept` stays off outside dev).
2. Jobs → new job → target `*` → function `state.apply` → args `baseline`.
   Dry-run first with `test=True` — Overstate shows the JID for tracing.
3. Minion detail → **Mine** tab shows `grains.items` / `network.ip_addrs`
   after the first push, plus `trivy.scan_summary` (severity counts,
   fixable total, top 20 CVEs) after the first Trivy scan; the
   **Schedules** tab shows `mine-update-hourly`, `highstate-nightly`,
   and `trivy-cve-scan`. No extra grants needed: Overstate's eauth
   already permits `mine.update`, `mine.*`, `state.apply`,
   `state.highstate`, and `schedule.*` (see `salt-config/api.conf` and
   Overstate's `docs/deployment.md`).

### 5. What runs itself afterwards

- **Hourly**: `mine-update-hourly` runs `mine.update` (`hours: 1`,
  `splay: 300`), refreshing the Mine data Overstate browses — on top of
  Salt's built-in 60-minute `mine_interval`.
- **Nightly**: `highstate-nightly` runs `state.highstate` at `02:17`
  (`cron: "17 2 * * *"`, `splay: 900`), so the fleet reconverges without
  stampeding the master.
- **Daily**: `trivy-cve-scan` runs `trivy_scan.publish` (`days: 1`,
  `splay: 600`), refreshing the vulnerability DB, re-scanning OS
  packages, and pushing a fresh `trivy.scan_summary` to the mine.
- Tune or disable either in pillar under `baseline:schedule`; disabling a
  job removes it from the minion (`schedule.absent`) instead of leaving a
  stale schedule behind.

---

## ⚠️ Important Notes

- **USB storage** is blocked by default (`usb` module; set `baseline:usb:block_storage: false` to allow it).
- **Automatic `zypper dup` is disabled by default** — set `baseline:updates:auto_dup: true` to enable it.
- **No SSH hardening** is included (assumed to be handled by FreeIPA).

---

## 📋 Requirements

- Salt minion on openSUSE Tumbleweed or Leap 15.x+
- Root access for package installation

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repo
2. Add or update a module under `salt/baseline/`
3. Add corresponding Goss tests in `goss/`
4. Update pillar examples
5. Run `make lint` and `make goss-<your-module>`

### Naming conventions

- **State IDs are `snake_case`** (`trivy_cache_dir`). Never reuse a scheduled
  job's name as a state ID — pass it via `- name:` instead, so renaming
  states can't silently rename jobs out from under the Schedules tab.
- **All baseline pillar nests under `baseline:`** (`baseline:trivy`,
  `baseline:ntp`). The only top-level exception is `mine_functions`, which
  Salt reads exclusively from the pillar root.
- **`map.jinja` selects on `os_family`, never exact `os` strings**
  (openSUSE reports "openSUSE Leap", never bare "openSUSE").
- **Platform variation lives in `map.jinja` + `pillar.get` merges**; SLS
  files stay declarative with no grain conditionals except whole-state
  gates.

---

**Made for real-world SUSE environments.**  
Contributions and feedback are appreciated!