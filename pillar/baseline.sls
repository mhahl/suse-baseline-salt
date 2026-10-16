baseline:
  systemd_resolved:
    # AdGuard resolvers over DNS-over-TLS (DNSOverTLS=opportunistic by
    # default, overridable via dns_over_tls: 'yes' or 'opportunistic').
    # The #suffix sets the DoT SNI/auth hostname — equivalent to kdig's
    # +tls-sni. Port is always 853: systemd-resolved does not support
    # custom DoT ports. Servers are tried in order; FallbackDNS stays
    # empty so resolution never falls back to unconfigured resolvers.
    dns: "51.161.136.107#dns.adguard.sigaint.au 139.99.149.92#dns.adguard.sigaint.au 139.99.210.89#dns.adguard.sigaint.au 139.99.210.170#dns.adguard.sigaint.au"
    dns_over_tls: "opportunistic"

  ntp:
    servers:
      - time1.google.com
      - time2.google.com
      - time3.google.com
      - time4.google.com

  updates:
    # Uses zypper dup on Tumbleweed and dnf upgrade on Fedora.
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

  # FreeIPA client (baseline.freeipa): OBS security:idm repo on
  # Tumbleweed; Fedora uses its base repo. Enrollment remains manual.
  # Disabling removes the Tumbleweed repo but keeps installed packages.
  freeipa:
    enabled: true
    repo_name: 'security:idm'
    repo_url: 'https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/'
    packages:
      - freeipa-client

  # NetBird mesh-VPN client (baseline.netbird): same official RPM repo
  # on both platforms; zypper auto-import and Fedora gpgkey/repo_gpgcheck
  # settings differ. Joining (`netbird up`) stays manual. Disabling removes
  # the repo and stops the daemon but keeps installed packages.
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

  # Grype CVE scanning (baseline.grype): daily filesystem scans with a
  # slim summary published to the Salt Mine under grype.scan_summary
  # (counts, fixable total, top 20 CVEs, distro) plus the full findings
  # under grype.scan_detail. All keys are optional.
  # Overstate: the grype-cve-scan job name and both grype.scan_* mine
  # keys are stable (Schedules/Mine/Vulnerabilities tabs). publish() uses
  # mine.send, not mine_functions below — mine.update does NOT refresh
  # these keys, so a missed daily run leaves stale/missing entries until
  # the next success (default mine_interval 60m). skip_db_update True = offline scans
  # only: refresh the DB externally (grype db update) or results go
  # stale. Report is stored 0640 (local-only). splay is clamped
  # 0..86400 in schedule.sls; top_n is clamped 0..100 in the module.
  # version pins the GitHub release (binary to /usr/local/bin/grype);
  # hashes pins the per-arch tarball sha256 digests.
  grype:
    version: 'v0.120.1'   # GitHub release tag, e.g. v0.120.1
    hashes:
      amd64: 'sha256=0a9ee97ef5ae2ee953b0a80098105052e846cdbe319a57d808b519c33cd1343d'
      arm64: 'sha256=29f47391dc283aa79fcc38e65224cd61f64dec0ecfd0db7074128ebf8ff23514'
    severities: 'HIGH,CRITICAL'
    top_n: 20             # CVEs kept in the mine summary 'top' list (0..100)
    skip_db_update: False # True = offline scans only, manage DB separately
    cache_dir: '/var/cache/grype'
    report_path: '/var/cache/grype/report.json'
    run_initial_scan: True  # one scan on first apply (skipped if a report exists)
    schedule_splay: 600     # seconds of random delay so the fleet scans evenly (0..86400)

# Salt Mine functions, read by minions straight from pillar. Stays top
# level: Salt only reads mine_functions from the pillar root. Kept small
# on purpose: grains + addresses are what Overstate's Mine browser and
# targeting need. Pushed hourly by the mine-update-hourly schedule above
# (on top of Salt's built-in 60-minute mine_interval).
mine_functions:
  grains.items: []
  network.ip_addrs: []
