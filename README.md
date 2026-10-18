# SUSE Baseline

> SaltStack states + pillar: a focused security/forensics `baseline` on **openSUSE Tumbleweed and Fedora** (fails fast on unsupported grains) plus a decoupled `overstate` namespace (fleet visibility — Grype CVE scanning to the Salt Mine) reusable with zero baseline configuration.

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
| **System (baseline)** | `banner`, `profile`, `systemd-resolved`, `timesyncd`, `updates`, `schedule`, `freeipa`, `netbird`, `minion` |
| **Visibility (overstate)** | `grype` (install + scan + daily schedule + clean, mine keys `grype.scan_summary`/`grype.scan_detail`) |
| **Hardening** | `usb` |

- **Forensic-ready** bash history and session controls
- **Strong privacy defaults** (DNS-over-TLS + DNSSEC, hardened NTP via systemd-timesyncd — the only NTP client here)
- **Modern security controls** (USB storage blocking)
- **Vulnerability scanning (overstate)** — daily Grype filesystem scans with summaries published to the Salt Mine (`grype.scan_summary` slim + `grype.scan_detail` full), no baseline required
- **Identity and mesh VPN clients** — FreeIPA from OBS on Tumbleweed or Fedora base repositories, and NetBird from its official repo (install + opt-in auto-join via pillar)
- **Overstate-ready scheduling** — hourly mine updates, nightly highstate, and daily jobs, visible in Overstate's Schedules tab
- **Pillar-driven** — DNS, NTP, USB, schedule, freeipa (incl. `join`), netbird (incl. `join`), update behavior via `baseline.*`; Grype tuning via `overstate:grype` (legacy `baseline:grype` still merges as fallback)

---

## 🚀 Quick Start

```bash
# Full fleet (highstate composes both via salt/top.sls)
salt '*' state.highstate

# Or target namespaces independently:
salt '*' state.apply baseline          # OS hardening only (no grype)
salt '*' state.apply overstate         # fleet visibility only (grype)
salt '*' state.apply overstate.grype   # standalone CVE scanning, zero baseline config
```

Or include them via your top file / highstate.

---

## 📦 Configuration

All configuration lives in pillar:

```yaml
# pillar/top.sls (defaults; per-fleet secrets appended after — later wins)
base:
  '*':
    - baseline
    - overstate
```

See [`pillar/baseline.sls`](pillar/baseline.sls) (aggregator over [`pillar/baseline/`](pillar/baseline/)) and [`pillar/overstate.sls`](pillar/overstate.sls) (aggregator over [`pillar/overstate/`](pillar/overstate/)) for every knob. Each section file carries a banner with WHY it exists, which state consumes it, and a copy-pastable override EXAMPLE. `pillar/top.sls` serves both (`- baseline`, `- overstate`) so highstate preserves full-fleet behavior while each namespace stays independently applicable. Notable defaults:

- `baseline:usb:block_storage: true` — USB storage blocked
- `baseline:updates:auto_dup: false` — no upgrade runs unless opted in (`zypper dup` on Tumbleweed, `dnf upgrade --refresh` on Fedora)
- `baseline:freeipa:enabled: true` — OBS `security:idm` repo on Tumbleweed; Fedora base repo; install-only unless `join.enabled` with `domain`/`principal`/`password` (encrypted pillar)
- `baseline:netbird:enabled: true` — official NetBird repo + daemon; opt-in join via `join.enabled` + `setup_key` (encrypted pillar); repo signing is configured per package manager
- `baseline:minion:masters` — minion's master IPs with native failover (default `['salt']`; minion restarts on change)
- `overstate:grype:version` + `hashes` — pinned GitHub release + per-arch sha256 (supply-chain control; refresh both from `checksums.txt` on bump)
- `overstate:grype:nice_level: 19` — daily scans at lowest CPU priority + idle I/O (never starve workloads)
- `baseline:proxy:http_proxy/https_proxy/no_proxy` — egress proxy (empty = direct); covers zypper/dnf upgrades, Grype DB/scan, `/etc/environment` + native tool config

---

## 🔐 Secrets (encrypted pillar)

`overstate:grype` needs no secrets (version, hashes, severities are public). Encrypt these instead:

| Secret | Pillar key | Notes |
|---|---|---|
| IPA svc-account password | `baseline:freeipa:join:password` | Long-lived credential; prefer per-host OTPs where possible |
| NetBird setup key | `baseline:netbird:join:setup_key` | Reusable until expiry/revocation; set reuse limits + rotation runbook |
| Proxy credentials (if any) | `baseline:proxy:http_proxy` as `http://user:pass@proxy:8080` | Only when the proxy itself needs auth |

The repo ships empty-string placeholders; real values live in an encrypted overlay that wins by merge order. Ciphertext is safe to commit — the private key is not.

### 1. One-time master setup

```bash
sudo -u salt gpg --homedir /etc/salt/gpgkeys --gen-key  # no passphrase: unattended master
# copy master.d/gpg.conf.example to /etc/salt/master.d/gpg.conf, then:
sudo -u salt gpg --homedir /etc/salt/gpgkeys --import private.key
sudo -u salt gpg --homedir /etc/salt/gpgkeys --import-ownertrust  # mark ultimately trusted (6)
systemctl reload salt-master  # Overstate prod: restart the salt-master container
```

`/etc/salt/gpgkeys` must be a persistent volume (mode `0700`, master-user owned) **outside** the Overstate bind mount — Sync now syncs the repo checkout only.

### 2. Add the overlay

```bash
cp pillar/secrets/prod.sls.example pillar/secrets/prod.sls
echo -n 's3cret' | gpg --encrypt --armor -r <master-key-id>  # paste output over each PASTE-* block
```

```yaml
# pillar/top.sls — uncomment the targeting (later entries win in pillar merge):
  'salt-prod-*':
    - secrets.prod
```

### 3. Verify without leaking

```bash
salt 'one-minion' saltutil.refresh_pillar
salt 'one-minion' pillar.get baseline:freeipa:join       # targeted get only
salt '*' state.apply baseline.freeipa test=True          # dry-run before enforcing
```

Never run `pillar.items` in shared terminals or Overstate Jobs — returns are visible. The join states already pass secrets via `env:` with `hide_output` + quiet logs.

### 4. Rotate

Re-encrypt the new value into `pillar/secrets/prod.sls`, highstate, then revoke server-side (NetBird dashboard key expiry; IPA password reset / `user-disable`). Re-joining IPA needs manual `ipa-client-install --uninstall` first. CI needs no GPG key: defaults keep both joins disabled with empty secrets, and CI never targets `secrets.*`.

> Enterprise end-state is Vault (`ext_pillar`), not GPG — dynamic leases, audit, rotation. Same overlay pattern applies; GPG is the zero-infra start.

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
| `make goss` | Run the openSUSE Tumbleweed Goss suite |
| `goss --gossfile goss/fedora.yaml validate --format tap` | Run Fedora Goss tests |
| `make goss-<component>` | Tests for one module, e.g. `goss-timesyncd` |
| `make install-goss` | Download Goss binary |
| `make apply` | `state.apply baseline` locally |
| `make highstate` | `state.highstate` locally |
| `make links` | Symlink `/srv/salt` + `/srv/pillar` to this repo |
| `make overstate-checkout` | Clone/fast-forward this repo at the Overstate roots |

### CI

CI runs separate `opensuse-tumbleweed` and `fedora-latest` container jobs ([`.forgejo/workflows/baseline.yml`](.forgejo/workflows/baseline.yml)). Both lint YAML, apply the baseline with `--retcode-passthrough`, and run the matching Goss suite. Fedora uses DNF and Fedora-specific checks.

---

## 📁 Project Structure

```
salt/
├── _modules/               # custom execution modules (synced automatically)
│   └── grype_scan.py       # scan/publish for overstate.grype (reads overstate:grype, fallback baseline:grype)
├── overstate/              # decoupled fleet-visibility namespace (no baseline required)
│   ├── init.sls            # includes overstate.grype
│   └── grype/              # install + scan + daily schedule + clean + map.jinja
└── baseline/               # your custom OS hardening plus shared and family includes
    ├── init.sls            # grain guard + shared module includes (no grype)
    ├── redhat/             # Fedora group includes freeipa, netbird, schedule, updates
    ├── suse/               # Tumbleweed group includes freeipa, netbird, schedule, updates
    ├── banner/
    ├── freeipa/            # OBS repo on Tumbleweed; Fedora base package + opt-in ipa-client-install join
    ├── grype/              # DEPRECATED shim -> overstate.grype (one release)
    ├── minion/             # minion master address: IP, not DNS
    ├── netbird/            # official NetBird repo + daemon + opt-in `netbird up` join
    ├── profile/
    ├── proxy/              # egress proxy env + native tool config
    ├── schedule/           # mine-update-hourly, highstate-nightly, sync-modules-daily
    ├── systemd-resolved/   # DoT resolvers + stub symlink + netconfig guard
    ├── timesyncd/          # NTP via systemd-timesyncd
    ├── updates/            # zypp on Tumbleweed; minimal DNF config + optional upgrade on Fedora
    └── usb/                # USB mass-storage blacklist

pillar/
├── baseline.sls            # aggregator over baseline/*.sls
├── overstate.sls           # aggregator over overstate/*.sls (overstate:grype)
├── secrets/                # encrypted overlays (ciphertext committable; see Secrets below)
│   └── prod.sls.example    # template — copy to prod.sls, paste gpg ciphertext (never loaded as .example)
├── baseline/               # one file per concern, each with WHY + consumer + EXAMPLE
│   ├── 01-systemd-resolved.sls  # baseline:systemd_resolved (DoT resolvers)
│   ├── 02-ntp.sls               # baseline:ntp (timesyncd servers)
│   ├── 03-updates.sls           # baseline:updates (auto_dup opt-in)
│   ├── 04-usb.sls               # baseline:usb (block_storage)
│   ├── 05-schedule.sls          # baseline:schedule (mine/highstate/sync jobs)
│   ├── 06-freeipa.sls           # baseline:freeipa (+ opt-in join)
│   ├── 07-netbird.sls           # baseline:netbird (+ opt-in join)
│   ├── 08-minion.sls            # baseline:minion (master IPs + failover)
│   ├── 11-proxy.sls             # baseline:proxy (egress http_proxy/https_proxy/no_proxy)
│   └── 10-mine.sls              # mine_functions (TOP LEVEL — Salt only reads root)
├── overstate/              # decoupled visibility pillar
│   └── 01-grype.sls             # overstate:grype (version/hashes/scan tuning)
└── top.sls                 # serves `- baseline` + `- overstate` (+ targeted secrets.* overlays)

master.d/                    # master-side configs (copy to /etc/salt/master.d/, never applied from repo)
└── gpg.conf.example        # GPG keydir for encrypted pillar (see Secrets below)

reactor/                     # master-side examples (needs reactor.conf wiring below)
├── service.sls             # service beacon → restart resolved/timesyncd
├── inotify.sls             # inotify beacon → re-apply owning module / audit line
├── diskspace.sls           # diskspace beacon → vacuum journal + zypper clean + grype db (keeps report.json)
└── reactor.conf.example    # master wiring (file_roots + tag map)

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

# Opt-in joins (only when join.enabled in pillar)
netbird status                          # Connected when joined
test -f /etc/ipa/default.conf && klist  # enrolled when joined

# Update configuration
test -f /etc/zypp/zypp.conf  # openSUSE Tumbleweed
test -f /etc/dnf/dnf.conf   # Fedora

# Minion master address
cat /etc/salt/minion.d/99-baseline.conf

# Scheduling (Overstate fleets)
cat /etc/salt/minion.d/_schedule.conf
salt-call schedule.list
salt-call mine.update && salt-call mine.get '*' grains.items

# Vulnerability scanning via overstate.grype (report is 0640, summary + detail go to mine)
salt '*' state.apply overstate.grype
ls -l /var/cache/grype/report.json
python3 -m json.tool /var/cache/grype/report.json >/dev/null
salt-call grype_scan.scan | head -60          # full result, split by publish()
salt-call grype_scan.publish                  # summary + detail -> mine
salt-run mine.get tgt='*' fun='grype.scan_summary'
salt-run mine.get tgt='web01' fun='grype.scan_detail'
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
3. Minion detail → **Mine** tab shows grains/addresses after the first push, plus `grype.scan_summary` after the first `overstate.grype` scan; the **Vulns** tab shows the full `grype.scan_detail` report; the **Schedules** tab shows `mine-update-hourly`, `highstate-nightly`, `sync-modules-daily` (baseline) and `grype-cve-scan` (overstate). Standalone customers: Jobs → `state.apply` → args `overstate.grype` with zero baseline config.

### 5. What runs itself afterwards

- **Hourly**: `mine-update-hourly` runs `mine.update`, refreshing the Mine data Overstate browses (grains/addresses from `mine_functions`).
- **Nightly**: `highstate-nightly` runs `state.highstate` at `02:17` (splayed, so the fleet doesn't stampede the master) — highstate composes `baseline` + `overstate` via `salt/top.sls`.
- **Daily**: `sync-modules-daily` syncs custom execution modules, and `grype-cve-scan` updates the vulnerability DB, re-scans, and pushes via `mine.send` under two stable keys — slim `grype.scan_summary` (`counts`, `total`, `fixable`, `top`, `distro`, versions, `scanned_at`) for fleet-wide readers plus complete `grype.scan_detail` (every finding with namespace/urls) for per-minion readers. The raw multi-megabyte Grype JSON stays on the minion at `report_path`. Error results land on both keys so a failed scan never leaves a stale detail report behind.
- Both grype mine keys are **not** part of `mine_functions` (no restart needed) and are **not** refreshed by `mine.update`: a missed daily run leaves stale/missing entries until the next success. `skip_db_update: True` means offline scans only — refresh the DB externally (`grype db update`) or results go stale.
- Tune or disable any of them in pillar under `baseline:schedule`; disabling a job removes it from the minion instead of leaving a stale schedule behind. `baseline:grype:schedule_splay` is clamped 0..86400 (default 600); `top_n` is clamped 0..100 (default 20) so the Mine payload stays small.

### 6. Reactor (optional, master-side)

`reactor/` holds master-side answers to minion beacon events:

| Event | Example | Action |
|---|---|---|
| service beacon: resolved/timesyncd down | `reactor/service.sls` | `service.start` on that minion |
| inotify beacon: baseline file changed | `reactor/inotify.sls` | re-apply the owning `baseline.*` module |
| diskspace beacon: usage ≥ 85% | `reactor/diskspace.sls` | vacuum journal + `zypper clean` + `rm -rf /var/cache/grype/db/*` (keeps `report.json`) |

Wiring (one time): `make overstate-checkout` ships `reactor/`; copy `reactor/reactor.conf.example` to `/etc/salt/master.d/reactor.conf` and reload the master; confirm live tags with `salt-run state.event pretty=True`. Guards are fail-closed, and minion beacons themselves are not in this baseline yet — each example header shows the beacon block that feeds it.

---

## ⚠️ Important Notes

- **Grype migration (`baseline.grype` → `overstate.grype`):** `state.apply baseline` no longer pulls scanning; highstate still does both (`salt/top.sls`: `- baseline`, `- overstate`). Move pillar verbatim `baseline:{grype:{...}}` → `overstate:{grype:{...}}` (legacy key still merges as fallback, overstate wins). `state.apply baseline.grype` still works for one release via deprecated shim. Goss: `make goss` now validates baseline/fedora **plus** `goss/overstate.yaml`; CI applies `baseline` then `overstate` and validates both suites.

- **Supported platforms:** openSUSE Tumbleweed and Fedora. The guard keeps the existing Tumbleweed grain variants and admits Fedora only for `os_family=RedHat` and `os=Fedora`; other platforms fail fast.
- **USB storage** is blocked by default (set `baseline:usb:block_storage: false` to allow it — that removes a previously deployed blacklist file).
- **Automatic upgrades are disabled by default** — set `baseline:updates:auto_dup: true` to enable `zypper dup` on Tumbleweed or `dnf upgrade --refresh` on Fedora.
- **Package-manager behavior branches by family:** FreeIPA uses OBS on Tumbleweed and Fedora's base repositories; NetBird signing configuration differs between zypper and DNF.
- **No SSH hardening** is included (assumed to be handled by FreeIPA).
- **Auto-join is opt-in and secret-safe.** `baseline:freeipa:join.enabled` needs `domain`/`principal`/`password`; `baseline:netbird:join.enabled` needs `setup_key`. Store both secrets in encrypted pillar (GPG/sops/Vault), never plaintext — states pass them via `env` with `hide_output` + quiet logs so they never appear in state names or Overstate job output. Joins are idempotent (FreeIPA skips when `/etc/ipa/default.conf` exists; NetBird skips when `status` reports connected); re-joining IPA requires manual `ipa-client-install --uninstall` first.

---

## 📋 Requirements

- Salt minion on openSUSE Tumbleweed or Fedora
- Root access for package installation

---

## 🤝 Contributing

1. Fork the repo
2. Add or update a module under `salt/baseline/`
3. Add corresponding Goss tests in `goss/`
5. Run `make lint`, `make test`, and `make goss-<your-module>`

### Conventions

- **Branch on `os_family` only for platform differences.** Keep common modules shared; use the Suse and RedHat include groups for divergent states. Validate Tumbleweed grains with the existing fullname/`os`/rolling-release paths, and Fedora with `os_family=RedHat` plus `os=Fedora`. New external repos must be Salt-managed with `gpgcheck` and documented key provenance.
- **State IDs are `snake_case`** (`grype_cache_dir`). Never reuse a scheduled job's name as a state ID — pass it via `- name:` instead.
- **All baseline pillar nests under `baseline:`**. The only top-level exception is `mine_functions`, which Salt reads exclusively from the pillar root.
- **Pillar merges live in `map.jinja`** (grype); SLS files stay declarative.
- **Disabling removes.** A disabled module removes what it manages (repo, schedule, config) but keeps already-installed packages — never leave a running job behind.
