# SUSE Baseline (suse-baseline-salt)

SaltStack states + pillar for a focused security/forensics baseline on **openSUSE Tumbleweed** (and modern SUSE).

## What it does

**Core modules** (original narrow forensic/privacy focus):

- **systemd-resolved** — Strict DNS-over-TLS + DNSSEC, no fallback, no MulticastDNS/LLMNR
- **chrony** — Hardened NTP
- **banner** + **profile** — Forensic bash history, session security, umask, etc.

**Additional hardening modules** (added for broader baseline):

- **sysctl** — Kernel & network hardening (official SUSE recommendations + modern defaults)
- **coredump** — Systemd-coredump limits + storage control
- **audit** — Forensic auditd rules (file watches, privilege escalation, etc.)
- **sudo** — Require TTY, full logging, restricted paths
- **pam** — faillock (lockout), pwquality, strong password policies
- **firewalld** — Default-deny with explicit allow list from pillar
- **fapolicyd** — Execution control / allowlisting (disabled by default)
- **usb** — Block USB storage devices
- **grub** — Bootloader password + hardened GRUB settings
- **integrity** — rpm -Va checks (+ optional AIDE)
- **updates** — Zypper policy for Tumbleweed (auto-dup is off by default)

## Quick start

```bash
# Target a minion (or use your normal targeting)
salt '*' state.apply baseline
```

Or via top file / highstate if you already include `baseline` in your pillar top.

## Pillar configuration

See [pillar/baseline.sls](pillar/baseline.sls). Example:

```yaml
baseline:
  systemd_resolved:
    dns: "76.76.2.22#xldfopbe6w.dns.controld.com"   # Control D DoT endpoint
  ntp:
    servers:
      - time1.google.com
      - time2.google.com
    iburst: true
```

Override in your own pillar as needed.

## Important notes / warnings

- The resolved module **forcefully manages** `/etc/resolv.conf` (symlink takeover). This is intentional for the privacy goals but will conflict with NetworkManager or other resolvers if they are also active.
- History settings and `PROMPT_COMMAND` changes are aggressive for incident-response purposes. Test in a safe environment first.
- `TMOUT`, fancy prompts, and some hardening only apply to interactive shells.
- **USB storage is blocked by default** in this baseline.
- **Firewalld is placed in drop mode** — only explicitly allowed services/ports will work.
- **No SSH hardening module** is included (managed by FreeIPA in the target environment).
- **No AppArmor states** (Tumbleweed uses SELinux in the target deployment).
- Several modules (grub password, fapolicyd, AIDE, automatic updates) are conservative or disabled by default — review pillar before enabling.

## Verification (after apply)

```bash
# DNS + NTP (original)
resolvectl status
chronyc sources

# New hardening
sysctl -a | grep -E 'rp_filter|dmesg_restrict|ptrace_scope'
cat /etc/systemd/coredump.conf.d/99-baseline.conf
auditctl -l | head
sudo -l
cat /etc/security/faillock.conf
firewall-cmd --list-all
lsmod | grep -E 'usb_storage|uas' || echo "USB storage blocked (good)"
ls /etc/sudoers.d/99-baseline
cat /var/log/baseline-last-update

# MOTD (on new login)
cat /etc/motd.d/99-steggy
```

## Requirements

- Salt minion on openSUSE Tumbleweed (or recent Leap/SLES where the states are known to work)
- `systemd-resolved` and `chrony` packages available

## Layout

```
salt/baseline/
├── init.sls
├── systemd-resolved/
├── chrony/
├── profile/
├── banner/
├── sysctl/
├── coredump/
├── audit/
├── sudo/
├── pam/
├── firewalld/
├── fapolicyd/
├── usb/
├── grub/
├── integrity/
└── updates/
pillar/
└── baseline.sls
```

## Testing

This repository uses [Goss](https://goss.rocks/) for validating Salt states on a real SUSE system.

### GitHub Actions

Only **yamllint** runs in CI on push/PR:

```bash
make lint
```

See [.github/workflows/yamllint.yml](.github/workflows/yamllint.yml).

### Manual Testing on a SUSE VM

Tests are intended to be run manually on a SUSE VM (Tumbleweed or Leap) after applying the Salt states.

#### Quick VM Setup

Run the following script on a fresh SUSE VM to install Salt, Goss, and prepare the environment:

```bash
sudo ./scripts/setup-test-vm.sh
```

This will:
- Install `salt-minion`, `make`, `goss`, and common packages used by the baseline
- Set up symlinks under `/srv/salt` and `/srv/pillar`
- Print the next commands to apply states and run tests

#### Running Tests

```bash
# Install goss (if not already present)
make install-goss

# Run yamllint
make lint

# Run all Goss tests
make goss

# Run tests for a specific component
make goss-sysctl
make goss-firewalld
make goss-profile
```

### Adding new tests

1. Create `goss/<component>.yaml`
2. Add it to `goss/goss.yaml` (for `make goss`)
3. Optionally add a convenience target in the Makefile

Contributions and feedback welcome. This started as a personal hardening collection and is intentionally small.


