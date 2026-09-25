baseline:
  systemd_resolved:
    # AdGuard resolvers over strict DNS-over-TLS (DNSOverTLS=yes in the
    # template). The #suffix sets the DoT SNI/auth hostname — equivalent
    # to kdig's +tls-sni. Port is always 853: systemd-resolved does not
    # support custom DoT ports. Servers are tried in order; FallbackDNS
    # stays empty because strict TLS never downgrades anyway.
    dns: "51.161.136.107#dns.adguard.sigaint.au 139.99.149.92#dns.adguard.sigaint.au 139.99.210.89#dns.adguard.sigaint.au 139.99.210.170#dns.adguard.sigaint.au"

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
    sync_modules:
      enabled: true
      # Daily saltutil.sync_modules so custom execution modules reach
      # minions without waiting for the next highstate. Splayed like
      # the other daily jobs.
      splay: 600

  # FreeIPA client (baseline.freeipa): install-only from the OBS
  # security:idm repo for Tumbleweed. Enrollment (ipa-client-install)
  # stays manual — it needs interactive admin credentials. Disabling
  # removes the repo but keeps already-installed packages.
  freeipa:
    enabled: true
    repo_name: 'security:idm'
    repo_url: 'https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/'
    packages:
      - freeipa-client

  # NetBird mesh-VPN client (baseline.netbird): install + daemon from
  # the official NetBird RPM repo. Joining (`netbird up`) stays manual —
  # it needs an SSO login or a setup key. Disabling removes the repo and
  # stops the daemon but keeps already-installed packages.
  netbird:
    enabled: true
    repo_name: 'netbird'
    repo_url: 'https://pkgs.netbird.io/yum/'
    packages:
      - netbird
    enable_service: true

  # Minion master addresses (baseline.minion): IPs, not DNS, with
  # native Salt failover across the prod masters. Default is Salt's
  # built-in 'salt' hostname (zero behavior change).
  minion:
    enabled: true
    masters:
      - 139.99.210.89   # salt-42e5.overstate.syd.prod
      - 139.99.210.170  # salt-b2b6.overstate.syd.prod
      - 139.99.149.92   # salt-c010.overstate.syd.prod

  # Trivy CVE scanning (baseline.trivy): daily OS-package scans with a
  # small summary published to the Salt Mine under trivy.scan_summary
  # (counts, fixable total, top 20 CVEs). All keys are optional.
  trivy:
    pkg_version: ''       # exact package pin (empty = repo latest)
    severities: 'HIGH,CRITICAL'
    top_n: 20             # CVEs kept in the mine summary 'top' list
    skip_db_update: False # True = offline scans only, manage DB separately
    cache_dir: '/var/cache/trivy'
    report_path: '/var/cache/trivy/report.json'
    run_initial_scan: True  # one scan on first apply (skipped if a report exists)
    schedule_splay: 600     # seconds of random delay so the fleet scans evenly

# Salt Mine functions, read by minions straight from pillar. Stays top
# level: Salt only reads mine_functions from the pillar root. Kept small
# on purpose: grains + addresses are what Overstate's Mine browser and
# targeting need. Pushed hourly by the mine-update-hourly schedule above
# (on top of Salt's built-in 60-minute mine_interval).
mine_functions:
  grains.items: []
  network.ip_addrs: []
