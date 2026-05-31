baseline:
  systemd_resolved:
    dns: "76.76.2.22#xldfopbe6w.dns.controld.com"
  ntp:
    servers:
      - time1.google.com
      - time2.google.com
      - time3.google.com
      - time4.google.com
    iburst: True

  # === New hardening modules (2026) ===

  sysctl:
    enabled: true
    # rp_filter: 1
    # dmesg_restrict: 1
    # ptrace_scope: 2

  coredump:
    max_use: "2G"
    keep_free: "4G"
    max_file_size: "1G"

  audit:
    enabled: true

  sudo:
    allowed_groups:
      - wheel
    # allowed_users: []

  pam:
    faillock_deny: 5
    faillock_unlock_time: 900
    pw_minlen: 15
    pw_minclass: 4

  firewalld:
    allowed_services:
      - ssh
    # allowed_ports:
    #   - 8080/tcp

  fapolicyd:
    enabled: false   # Enable with care - requires trust database population

  usb:
    block_storage: true

  grub:
    # password_hash: "grub.pbkdf2.sha512.10000.XXXX..."   # Generate with grub2-mkpasswd-pbkdf2

  integrity:
    use_aide: false   # Set true to deploy AIDE (heavier)

  updates:
    auto_dup: false   # Dangerous on Tumbleweed - use with extreme caution

