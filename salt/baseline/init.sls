# Baseline hardening state (includes all sub-modules)
include:
  - baseline.systemd-resolved.main
  - baseline.chrony.main
  - baseline.banner.main
  - baseline.profile.main

  # Additional hardening (added 2026)
  - baseline.sysctl.main
  - baseline.coredump.main
  - baseline.audit.main
  - baseline.sudo.main
  - baseline.pam.main
  - baseline.firewalld.main
  - baseline.fapolicyd.main
  - baseline.usb.main
  - baseline.grub.main
  - baseline.integrity.main
  - baseline.updates.main
