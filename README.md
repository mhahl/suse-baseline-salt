# SUSE Baseline

> SaltStack states + pillar for a focused security/forensics baseline on **openSUSE Tumbleweed and Fedora**. `baseline/init.sls` fails fast on unsupported OS grains.

[![Salt](https://img.shields.io/badge/Salt-3006%2B-blue)](https://saltproject.io/)
[![openSUSE](https://img.shields.io/badge/openSUSE-Tumbleweed-green)](https://www.opensuse.org/)
[![Fedora](https://img.shields.io/badge/Fedora-supported-blue?logo=fedora)](https://getfedora.org/)
[![Goss](https://img.shields.io/badge/Tests-Goss-orange)](https://goss.rocks/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## ✨ Features

| Category | Modules |
|----------|---------|
| **Supported OS** | openSUSE Tumbleweed, Fedora |
| **System** | `banner`, `profile`, `systemd-resolved`, `timesyncd`, `updates`, `schedule`, `trivy`, `freeipa`, `netbird`, `minion` |
| **Hardening** | `usb` |

- **Forensic-ready** bash history and session controls
- **Strong privacy defaults** (DNS-over-TLS + DNSSEC, hardened NTP via systemd-timesyncd — the only NTP client here)
- **Modern security controls** (USB storage blocking)
- **Vulnerability scanning** — daily Trivy OS-package scans with summaries published to the Salt Mine (`trivy.scan_summary`)
- **Identity and mesh VPN clients** — FreeIPA from OBS on Tumbleweed or Fedora base repositories, and NetBird from its official repo (clients only; enrollment/join stays manual)
- **Overstate-ready scheduling** — hourly mine updates, nightly highstate, and daily jobs, visible in Overstate's Schedules tab
- **Pillar-driven** — DNS, NTP, USB, schedule, trivy, freeipa, netbird, and update behavior are configurable via pillar

---

## 🚀 Quick Start

```bash
# Apply the full baseline (openSUSE Tumbleweed or Fedora)
salt '*' state.apply baseline
```

Or include it via your top file / highstate.

---

## 📦 Configuration

All configuration lives in pillar:

```yaml
# pillar/top.sls
base:
  '*':
    - baseline
```

See [`pillar/baseline.sls`](pillar/baseline.sls) for every knob (`baseline.*` settings plus top-level `mine_functions` for the Salt Mine). Notable defaults:

- `baseline:usb:block_storage: true` — USB storage blocked
- `baseline:updates:auto_dup: false` — no upgrade runs unless opted in (`zypper dup` on Tumbleweed, `dnf upgrade --refresh` on Fedora)
- `baseline:freeipa:enabled: true` — OBS `security:idm` repo on Tumbleweed; Fedora base repo; no enrollment
- `baseline:netbird:enabled: true` — official NetBird repo + daemon, no network join; repo signing is configured per package manager
- `baseline:minion:masters` — minion's master IPs with native failover (default `['salt']`; minion restarts on change)

---

## 🛠️ Development & Testing

### On an openSUSE Tumbleweed or Fedora VM

```bash
# One-time setup (installs OS-specific package dependencies)
sudo ./scripts/setup-test-vm.sh

# Shared checks
make lint
make test

# Tumbleweed Goss suite
make goss
make goss-timesyncd

# Fedora Goss suite
goss --gossfile goss/fedora.yaml validate --format tap
```

### Make targets

| Command | Description |
|---------|-------------|
| `make lint` | Run yamllint |
| `make test` | Run pytest unit/render tests |
| `make goss` | Run the openSUSE Tumbleweed Goss suite |
| `goss --gossfile goss/fedora.yaml validate --format tap` | Run Fedora Goss tests |
| `make goss-<component>` | Tests for one module, e.g. `goss-timesyncd` |
| `make install-goss` | Download Goss binary |
| `make apply` | `state.apply baseline` locally |
| `make highstate` | `state.highstate` locally |
| `make links` | Symlink `/srv/salt` + `/srv/pillar` to this repo |
| `make overstate-checkout` | Clone/fast-forward this repo at the Overstate roots |

### CI

CI runs separate `opensuse-tumbleweed` and `fedora-latest` container jobs ([`.forgejo/workflows/baseline.yml`](.forgejo/workflows/baseline.yml)). Both lint YAML, run `pytest`, apply the baseline with `--retcode-passthrough`, and run the matching Goss suite. Fedora uses DNF and Fedora-specific checks.

---

## 📁 Project Structure

```
salt/
├── _modules/               # custom execution modules (synced automatically)
│   └── trivy_scan.py       # scan/publish for the trivy module
└── baseline/               # Salt modules plus shared and family includes
    ├── init.sls            # grain guard + shared module includes
    ├── redhat/             # Fedora group includes freeipa, netbird, schedule, updates
    ├── suse/               # Tumbleweed group includes freeipa, netbird, schedule, updates
    ├── banner/
    ├── freeipa/            # OBS repo on Tumbleweed; Fedora base package (no enroll)
    ├── minion/             # minion master address: IP, not DNS
    ├── netbird/            # official NetBird repo + daemon (no join)
    ├── profile/
    ├── schedule/           # mine-update-hourly, highstate-nightly, sync-modules-daily
    ├── systemd-resolved/   # DoT resolvers + stub symlink + netconfig guard
    ├── timesyncd/          # NTP via systemd-timesyncd
    ├── trivy/              # install + scan + daily schedule + clean
    ├── updates/            # zypp on Tumbleweed; minimal DNF config + optional upgrade on Fedora
    └── usb/                # USB mass-storage blacklist

pillar/
├── baseline.sls            # baseline.* settings + top-level mine_functions
└── top.sls

reactor/                     # master-side examples (needs reactor.conf wiring below)
├── service.sls             # service beacon → restart resolved/timesyncd
├── inotify.sls             # inotify beacon → re-apply owning module / audit line
├── diskspace.sls           # diskspace beacon → vacuum journal + Tumbleweed zypper clean
└── reactor.conf.example    # master wiring (file_roots + tag map)

tests/                       # pytest render/unit tests, one file per module
```

---

## ✅ Verification

After applying the states:

```bash
# System
resolvectl status
timedatectl show-timesync --all
systemctl is-enabled chronyd 2>/dev/null || echo "chronyd not present (good)"

# Hardening
lsmod | grep -E 'usb_storage|uas' || true
cat /etc/modprobe.d/99-baseline-usb-storage.conf

# Identity / VPN clients — openSUSE Tumbleweed
zypper lr security:idm && rpm -q freeipa-client
zypper lr netbird && rpm -q netbird && systemctl is-active netbird

# Identity / VPN clients — Fedora
rpm -q freeipa-client
dnf repolist netbird && rpm -q netbird && systemctl is-active netbird

# Update configuration
test -f /etc/zypp/zypp.conf  # openSUSE Tumbleweed
test -f /etc/dnf/dnf.conf   # Fedora

# Minion master address
cat /etc/salt/minion.d/99-baseline.conf

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

Overstate is a web UI in front of one Salt master: you accept keys, fire jobs, and read returns there, while Salt still does the work. This baseline drops into it — states show up in the file browser, pillar in the pillar browser, the `schedule` module feeds the Schedules tab, and `mine_functions` feeds the Mine browser.

### 1. Place the trees where the master serves them

Deploy as a git checkout of this repo on the master host, so Overstate's Files → **Sync now** button (fetch + `pull --ff-only`) works on it:

```sh
sudo make overstate-checkout
# Custom roots (e.g. an Overstate dev checkout) — no sudo needed
# when you own the target; use an absolute path:
make overstate-checkout OVERSTATE_SRV=/path/to/salt-srv
```

The target clones (or fast-forwards, never force-updates) this repo at `OVERSTATE_SRV`, checks out `OVERSTATE_BRANCH` (default `main`) tracking its upstream, leaves the tree clean, and opens permissions to `a+rX` for the master workers. A non-empty directory that is not a checkout is never touched. Re-running is safe and is exactly what Sync now does from the UI.

> Use plain copies, not symlinks: the container only sees inside its bind mount, so links pointing elsewhere on the host dangle inside the master.

### 2. Let the master serve pillar

Overstate ships file roots only — add pillar roots on the master (`/etc/salt/master.d/pillar.conf`, adapted to your layout), serving this repo's `pillar/top.sls` as-is. Pillar provides `baseline.*` settings plus top-level `mine_functions` (`grains.items`, `network.ip_addrs`) — no minion config drop-ins needed.

### 3. Include baseline in the state top file

`state.apply baseline` works without touching top, but the **nightly highstate runs `state.highstate`**, so the top file must include it alongside any demo states.

### 4. Enroll minions and apply from the UI

1. Install the minion, point it at the master, and **accept the key by fingerprint** (`auto_accept` stays off outside dev).
2. Jobs → new job → target `*` → function `state.apply` → args `baseline`. Dry-run first with `test=True`.
3. Minion detail → **Mine** tab shows grains/addresses after the first push, plus `trivy.scan_summary` after the first scan; the **Schedules** tab shows `mine-update-hourly`, `highstate-nightly`, `sync-modules-daily`, and `trivy-cve-scan`.

### 5. What runs itself afterwards

- **Hourly**: `mine-update-hourly` runs `mine.update`, refreshing the Mine data Overstate browses.
- **Nightly**: `highstate-nightly` runs `state.highstate` at `02:17` (splayed, so the fleet doesn't stampede the master).
- **Daily**: `sync-modules-daily` syncs custom execution modules, and `trivy-cve-scan` refreshes the vulnerability DB, re-scans, and pushes a fresh mine summary.
- Tune or disable any of them in pillar under `baseline:schedule`; disabling a job removes it from the minion instead of leaving a stale schedule behind.

### 6. Reactor (optional, master-side)

`reactor/` holds master-side answers to minion beacon events:

| Event | Example | Action |
|---|---|---|
| service beacon: resolved/timesyncd down | `reactor/service.sls` | `service.start` on that minion |
| inotify beacon: baseline file changed | `reactor/inotify.sls` | re-apply the owning `baseline.*` module |
| diskspace beacon: usage ≥ 85% | `reactor/diskspace.sls` | vacuum journal + `zypper clean` |

Wiring (one time): `make overstate-checkout` ships `reactor/`; copy `reactor/reactor.conf.example` to `/etc/salt/master.d/reactor.conf` and reload the master; confirm live tags with `salt-run state.event pretty=True`. Guards are fail-closed, and minion beacons themselves are not in this baseline yet — each example header shows the beacon block that feeds it.

---

## ⚠️ Important Notes

- **Supported platforms:** openSUSE Tumbleweed and Fedora. The guard keeps the existing Tumbleweed grain variants and admits Fedora only for `os_family=RedHat` and `os=Fedora`; other platforms fail fast.
- **USB storage** is blocked by default (set `baseline:usb:block_storage: false` to allow it — that removes a previously deployed blacklist file).
- **Automatic upgrades are disabled by default** — set `baseline:updates:auto_dup: true` to enable `zypper dup` on Tumbleweed or `dnf upgrade --refresh` on Fedora.
- **Package-manager behavior branches by family:** FreeIPA uses OBS on Tumbleweed and Fedora's base repositories; NetBird signing configuration differs between zypper and DNF.
- **No SSH hardening** is included (assumed to be handled by FreeIPA).
- **No network joins.** FreeIPA enrollment (`ipa-client-install`) and NetBird join (`netbird up`) stay manual — both need credentials this baseline will not carry.

---

## 📋 Requirements

- Salt minion on openSUSE Tumbleweed or Fedora
- Root access for package installation

---

## 🤝 Contributing

1. Fork the repo
2. Add or update a module under `salt/baseline/`
3. Add corresponding Goss tests in `goss/`
4. Add a render test in `tests/` and update pillar examples
5. Run `make lint`, `make test`, and `make goss-<your-module>`

### Conventions

- **Branch on `os_family` only for platform differences.** Keep common modules shared; use the Suse and RedHat include groups for divergent states. Validate Tumbleweed grains with the existing fullname/`os`/rolling-release paths, and Fedora with `os_family=RedHat` plus `os=Fedora`. New external repos must be Salt-managed with `gpgcheck` and documented key provenance.
- **State IDs are `snake_case`** (`trivy_cache_dir`). Never reuse a scheduled job's name as a state ID — pass it via `- name:` instead.
- **All baseline pillar nests under `baseline:`**. The only top-level exception is `mine_functions`, which Salt reads exclusively from the pillar root.
- **Pillar merges live in `map.jinja`** (trivy); SLS files stay declarative.
- **Disabling removes.** A disabled module removes what it manages (repo, schedule, config) but keeps already-installed packages — never leave a running job behind.
