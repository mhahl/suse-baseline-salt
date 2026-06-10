# SUSE Baseline

> SaltStack states + pillar for a focused security/forensics baseline on **openSUSE Tumbleweed** (and modern SUSE).

[![Salt](https://img.shields.io/badge/Salt-3006%2B-blue)](https://saltproject.io/)
[![openSUSE](https://img.shields.io/badge/openSUSE-Tumbleweed%20%7C%20Leap-green)](https://www.opensuse.org/)
[![Goss](https://img.shields.io/badge/Tests-Goss-orange)](https://goss.rocks/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## ✨ Features

This project provides a **modular** baseline for SUSE systems with clear separation between hardening and observability.

| Category     | Modules |
|--------------|---------|
| **System**       | `systemd-resolved`, `chrony`, `profile`, `banner`, `updates` |
| **Hardening**    | `usb` |
| **Monitoring**   | `falco`, `node_exporter`, `vmagent` |

### Highlights

- **Forensic-ready** bash history and session controls
- **Strong privacy defaults** (DNS-over-TLS + DNSSEC, hardened NTP)
- **Modern security controls** (Falco, execution allowlisting, USB blocking)
- **Observability out of the box** (Falco events + Prometheus metrics via VictoriaMetrics)
- **Fully modular** — enable only what you need via pillar

---

## 🚀 Quick Start

```bash
# Apply the full baseline
salt '*' state.apply baseline

# Or apply just monitoring
salt '*' state.apply monitoring
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
    - monitoring.falco
    - monitoring.node_exporter
    - monitoring.vmagent
```

### Example Pillar

See:
- [`pillar/baseline.sls`](pillar/baseline.sls) — baseline system + hardening settings (usb, ntp, resolved, updates)
- [`pillar/monitoring/falco.sls`](pillar/monitoring/falco.sls)
- [`pillar/monitoring/node_exporter.sls`](pillar/monitoring/node_exporter.sls)
- [`pillar/monitoring/vmagent.sls`](pillar/monitoring/vmagent.sls)

---

## 🛠️ Development & Testing

### On a SUSE VM (Recommended)

```bash
# One-time setup
sudo ./scripts/setup-test-vm.sh

# Run tests
make lint
make goss
make goss-falco
make goss-vmagent
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

- **Goss tests** run in a container on `opensuse-tumbleweed` runners on push/PR to relevant paths.

See [`.forgejo/workflows/goss.yml`](.forgejo/workflows/goss.yml).

(Linting and other checks can be added to the Forgejo workflows as needed.)

---

## 📁 Project Structure

```
salt/
├── baseline/               # Core hardening
│   ├── init.sls
│   ├── system/             # Core system services
│   ├── hardening/          # Security & hardening
│   └── network/            # Network configuration
│
├── monitoring/             # Observability
│   ├── init.sls
│   ├── falco/
│   ├── node_exporter/
│   └── vmagent/

pillar/
├── baseline/
│   ├── system/
│   ├── hardening/
│   └── network/
│
└── monitoring/
    ├── falco.sls
    ├── node_exporter.sls
    └── vmagent.sls
```

---

## ✅ Verification

After applying the states, run these checks:

```bash
# System
resolvectl status
chronyc sources
systemctl status falco prometheus-node_exporter vmagent

# Hardening
lsmod | grep -E 'usb_storage|uas' || true
cat /etc/modprobe.d/99-baseline-usb-storage.conf

# Monitoring
curl -s http://localhost:9100/metrics | head
journalctl -u falco -n 20
```

---

## ⚠️ Important Notes

- **USB storage** is blocked by default (`usb` module).
- **No SSH hardening** is included (assumed to be handled by FreeIPA).
- Several modules are **disabled by default** — enable them explicitly in pillar.
- `vmagent` (and other VictoriaMetrics tools) are installed from the openSUSE Build Service Percona repository.

---

## 📋 Requirements

- Salt minion on openSUSE Tumbleweed or Leap 15.x+
- Root access for package installation

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repo
2. Add or update a module under `salt/baseline/` or `salt/monitoring/`
3. Add corresponding Goss tests in `goss/`
4. Update pillar examples
5. Run `make lint` and `make goss-<your-module>`

---

**Made for real-world SUSE environments.**  
Contributions and feedback are appreciated!