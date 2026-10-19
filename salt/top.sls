base:
  '*':
    - baseline
    - overstate
  # overstate_cis — upstream CIS DIL v2.0.0 hardening formula
  # (salt://overstate_cis/, entrypoint init.sls only — never target
  # sub-states). Gated to the site-lhm-development nodegroup, which
  # must be defined master-side (Overstate groups or
  # /etc/salt/master.d/nodegroups.conf). The formula's
  # 0-guard-supported-os-family guard fails closed on unsupported OSes.
  'site-lhm-development':
    - match: nodegroup
    - overstate_cis
