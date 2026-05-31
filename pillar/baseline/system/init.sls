# System pillar data - Core system services and configuration
baseline:
  systemd_resolved:
    dns: "76.76.2.22#xldfopbe6w.dns.controld.com"

  ntp:
    servers:
      - time1.google.com
      - time2.google.com
      - time3.google.com
      - time4.google.com
    iburst: true

  coredump:
    max_use: "2G"
    keep_free: "4G"
    max_file_size: "1G"

  updates:
    auto_dup: false   # Dangerous on Tumbleweed - use with extreme caution
