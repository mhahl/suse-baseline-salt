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

  updates:
    auto_dup: false

  usb:
    block_storage: true

