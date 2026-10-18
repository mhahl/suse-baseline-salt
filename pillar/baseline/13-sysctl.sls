# =====================================================================
# SECTION: baseline:sysctl — Kernel and network sysctl hardening
#
# WHY: Default kernel parameters prioritise compatibility over security.
#   This module locks down ASLR, restricts kernel info disclosure, blocks
#   IP spoofing and ICMP redirect attacks, enables SYN flood protection,
#   and disables IP forwarding.  All settings are safe on both Tumbleweed
#   and Fedora — none interfere with normal server operation.
#
# CONSUMED BY: salt/baseline/sysctl/init.sls via
#   pillar.get('baseline:sysctl:enabled', True).  True writes
#   /etc/sysctl.d/99-baseline.conf and runs sysctl --system; False
#   removes the file and reloads defaults.
#
# EXAMPLE — disable on a router / NAT host:
#   baseline:
#     sysctl:
#       enabled: false
#   (then manage forwarding in a separate /etc/sysctl.d/ file)
# =====================================================================
baseline:
  sysctl:
    enabled: true