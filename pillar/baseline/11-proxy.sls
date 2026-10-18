# =====================================================================
# SECTION: baseline:proxy — egress HTTP proxy for restricted networks
#
# WHY: Classified / corporate fleets have no direct internet: package
#   upgrades (zypper dup / dnf upgrade), Grype DB downloads + GitHub
#   release fetches, and repo refreshes must traverse an egress proxy.
#   Empty values = direct connection (defaults, zero behavior change).
#   Set http_proxy/https_proxy to enable; no_proxy always ships loopback
#   so Salt master/minion IPC never hairpins through the proxy.
#
# enabled (default True): master switch for Salt's proxy file management.
#   True  — manage /etc/environment, /etc/sysconfig/proxy (Suse) and
#           /etc/dnf/dnf.conf (RedHat); empty values strip stale
#           proxy lines, so direct connection is actively enforced.
#   False — leave all proxy files completely untouched, stale proxy
#           lines included. Useful when proxy config is managed
#           out-of-band (YaST, image template). NOTE: this does NOT
#           affect per-command env: that baseline.updates and the grype
#           scan build from the proxy values below — those still apply.
#
# CONSUMED BY:
#   - salt/baseline/proxy/init.sls via pillar.get('baseline:proxy', {})
#     (/etc/environment for login shells/tooling, /etc/sysconfig/proxy
#     PROXY_* on Suse for zypper, /etc/dnf/dnf.conf proxy= on RedHat)
#   - salt/baseline/updates/init.sls (env: on dup/upgrade commands)
#   - salt/_modules/grype_scan.py _proxy_opts() (scan + DB download env,
#     lower- and upper-case variants since tooling disagrees on case)
#
# DAY-0 NOTE: Salt's archive.extracted (grype tarball) and pkgrepo
#   refreshes run in the minion daemon's own env — after first setting a
#   proxy, restart salt-minion once (or set a systemd override
#   Environment=http_proxy=...) so downloads pick it up. Recurring
#   state-run commands work immediately via per-command env:.
#
# EXAMPLE — corporate egress proxy:
#   baseline:
#     proxy:
#       enabled: true
#       http_proxy: 'http://proxy.example.com:8080'
#       https_proxy: 'http://proxy.example.com:8080'
#       no_proxy: 'localhost,127.0.0.1,::1,.example.com'
#
# EXAMPLE — proxy managed out-of-band (Salt stops touching it):
#   baseline:
#     proxy:
#       enabled: false
# =====================================================================
baseline:
  proxy:
    enabled: true
    http_proxy: ''
    https_proxy: ''
    no_proxy: 'localhost,127.0.0.1,::1'
