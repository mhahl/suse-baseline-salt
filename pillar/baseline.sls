baseline:
  systemd_resolved:
    # Quad9 public DNS (malware-blocking, DNSSEC-validating). Both the
    # primary and secondary are listed so resolution survives one being
    # unreachable; the #suffix sets the DoT SNI hostname, which matters
    # for DNS-over-TLS authentication. Personal resolvers (e.g. Controld
    # with a per-account hostname) belong in host-specific pillar.
    dns: "9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net"

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

  schedule:
    # Minion scheduler jobs, visible in Overstate's Schedules tab.
    enabled: true
    mine_update:
      enabled: true
      hours: 1
      splay: 300
      run_on_start: true
    highstate:
      enabled: true
      # Nightly highstate, off the exact hour + splayed so the fleet
      # does not stampede the master at once.
      cron: "17 2 * * *"
      splay: 900

# Salt Mine functions, read by minions straight from pillar. Kept small
# on purpose: grains + addresses are what Overstate's Mine browser and
# targeting need. Pushed hourly by the mine-update-hourly schedule above
# (on top of Salt's built-in 60-minute mine_interval).
mine_functions:
  grains.items: []
  network.ip_addrs: []

# Trivy CVE scanning (baseline.trivy): daily OS-package scans with a
# small summary published to the Salt Mine under trivy.scan_summary
# (counts, fixable total, top 20 CVEs). All keys are optional.
trivy:
  version: '0.74.0'     # exact version for the tarball URL (SLES/binary flavor)
  arch: '64bit'         # tarball arch suffix: '64bit' or 'ARM64'
  pkg_version: ''       # exact package pin for repo installs (empty = repo latest)
  severities: 'HIGH,CRITICAL'
  top_n: 20             # CVEs kept in the mine summary 'top' list
  skip_db_update: False # True = offline scans only, manage DB separately
  cache_dir: '/var/cache/trivy'
  report_path: '/var/cache/trivy/report.json'
  run_initial_scan: True  # one scan on first apply (skipped if a report exists)
  schedule_splay: 600     # seconds of random delay so the fleet scans evenly
