# =====================================================================
# SECTION: baseline:freeipa — client install + opt-in domain join
#
# WHY: Identity is assumed to come from FreeIPA (no local SSH
#   hardening in this baseline). Tumbleweed has no base freeipa-client
#   package, so it uses the OBS security:idm repo; Fedora uses its base
#   repos. Install-only by default — join needs a service-account
#   credential and must never happen by accident.
#
# CONSUMED BY: salt/baseline/freeipa/init.sls via
#   pillar.get('baseline:freeipa', {}). join.enabled renders
#   ipa-client-install --unattended (idempotent on
#   /etc/ipa/default.conf, --no-ntp keeps timesyncd the sole NTP
#   client). Secrets travel via env + hide_output, never in the state
#   name. Missing domain/principal/password fails closed.
#
# EXAMPLE — auto-join (password in ENCRYPTED pillar only):
#   baseline:
#     freeipa:
#       join:
#         enabled: true
#         domain: 'example.com'
#         # realm: 'EXAMPLE.COM'  # defaults to upper(domain)
#         # server: 'ipa.example.com'  # omit for DNS discovery
#         principal: 'svc-enroll'
#         password: 'ENCRYPTED-HERE'
#         mkhomedir: true
#         no_ntp: true
# =====================================================================
baseline:
  freeipa:
    enabled: true
    repo_name: 'security:idm'
    repo_url: 'https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/'
    packages:
      - freeipa-client
    join:
      enabled: false
      domain: ''       # e.g. 'example.com' (required when joining)
      realm: ''        # defaults to upper(domain), e.g. 'EXAMPLE.COM'
      server: ''       # optional, e.g. 'ipa.example.com' (omit for DNS discovery)
      principal: ''    # e.g. 'svc-enroll' (required when joining)
      password: ''     # svc-account password, encrypted pillar only
      mkhomedir: true
      no_ntp: true
      extra_args: ''   # e.g. '--ssh-trust-dns --no-ssh'
