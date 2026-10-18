# =====================================================================
# SECTION: baseline:minion — master addresses (IPs, not DNS)
#
# WHY: If DNS is down or poisoned the minion must still find its
#   master. A static IP list with master_type: failover gives native
#   Salt failover across the prod masters with zero DNS dependency.
#   Default ['salt'] is Salt's own built-in default, so an untouched
#   pillar changes nothing.
#
# CONSUMED BY: salt/baseline/minion/init.sls via
#   pillar.get('baseline:minion', {}). Writes
#   /etc/salt/minion.d/99-baseline.conf; restarts salt-minion on change
#   only where systemd supervises it (never in CI containers).
#
# EXAMPLE — single lab master as a lone string (auto-wrapped to list):
#   baseline:
#     minion:
#       masters: '10.0.0.5'
# =====================================================================
baseline:
  minion:
    enabled: true
    masters:
      - 139.99.210.89   # salt-42e5.overstate.syd.prod
      - 139.99.210.170  # salt-b2b6.overstate.syd.prod
      - 139.99.149.92   # salt-c010.overstate.syd.prod
