# =====================================================================
# SECTION: baseline:netbird — mesh-VPN client + opt-in network join
#
# WHY: Fleet members reach the Salt master and each other over an
#   encrypted mesh even on hostile LANs. One official RPM repo serves
#   both families (zypper gpgautoimport vs DNF gpgkey/repo_gpgcheck
#   branch in the state). Install + daemon by default — `netbird up`
#   needs a setup key and must never happen by accident.
#
# CONSUMED BY: salt/baseline/netbird/init.sls via
#   pillar.get('baseline:netbird', {}). join.enabled renders
#   netbird up --setup-key "$NB_SETUP_KEY" (idempotent on
#   `netbird status | grep -qi connected`). Key travels via env +
#   hide_output, never in the state name. Missing setup_key fails
#   closed.
#
# EXAMPLE — auto-join (key in ENCRYPTED pillar only):
#   baseline:
#     netbird:
#       join:
#         enabled: true
#         setup_key: 'A1B2C3D4-XXXX-...'
#         # hostname: 'web01'  # omit to use system hostname
#         # management_url: 'https://nb.example.com'  # self-hosted only
# =====================================================================
baseline:
  netbird:
    enabled: true
    repo_name: 'netbird'
    repo_url: 'https://pkgs.netbird.io/yum/'
    packages:
      - netbird
    enable_service: true
    join:
      enabled: false
      setup_key: ''      # required when joining, e.g. 'A1B2C3D4-XXXX-...'
      hostname: ''       # optional, omit to use system hostname
      management_url: '' # optional, for self-hosted controllers
      extra_args: ''     # e.g. '--rosenpass-permissive'
