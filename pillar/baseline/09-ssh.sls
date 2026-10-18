# =====================================================================
# SECTION: baseline:ssh — SSH daemon hardening
#
# WHY: SSH is the most exposed service on every minion.  This state
#   enforces key-only + GSSAPI authentication (via FreeIPA/Kerberos),
#   modern crypto, aggressive rate-limiting, and disabled forwarding
#   to minimise the attack surface.  Privilege escalation is handled
#   by FreeIPA sudo rules, so root SSH login is disabled entirely.
#
# CONSUMED BY: salt/baseline/ssh/init.sls via
#   pillar.get('baseline:ssh:enabled', True).  True writes
#   /etc/ssh/sshd_config.d/01-baseline-sshd.conf; False removes it.
#
# EXAMPLE — disable SSH hardening on a bastion host:
#   baseline:
#     ssh:
#       enabled: false
# =====================================================================
baseline:
  ssh:
    enabled: true