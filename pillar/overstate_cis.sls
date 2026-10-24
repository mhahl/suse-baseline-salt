# =====================================================================
# SECTION: overstate_cis — upstream CIS hardening formula (overstate-cis)
#
# WHY: Applies the read-only clone of github.com/mhahl/overstate-cis,
#   present on the master file roots as salt://overstate_cis/
#   (entrypoint init.sls — the top.sls MUST NOT target sub-states).
#   Gated to the site-lhm-development nodegroup via salt/top.sls +
#   pillar/top.sls (match: nodegroup; nodegroup defined master-side).
#
# CONSUMED BY: salt://overstate_cis/init.sls via
#   pillar.get('overstate_cis', ...). enforce False = audit-only
#   (only audit.sls runs); True = packages/config/services run.
#   Controls only need to be listed when turning a control OFF.
#
# ROLLOUT: audit dry-run first (works even with enforce True):
#   salt 'site-lhm-development' state.apply overstate_cis test=True
# Then apply for real; flip enforce to False to stop re-enforcement.
# No reboot needed unless bootloader/SELinux changed or
# legacy_apparmor_migration armed /.autorelabel (leave False unless
# importing pre-Feb-2025 / Leap 15.x hosts).
# =====================================================================
overstate_cis:
  # Master switch. True = apply hardening; False = audit-only.
  enforce: True
  # CIS level: 1 (L2 blocks stay off — no opt-in flags set).
  level: 1

  # Conflict avoidance: baseline already owns these controls, so the
  # formula must not fight it over the same files/services.
  controls:
    firewalld: False              # baseline:firewalld manages zones/services (12-firewalld.sls)
    firewalld_default_zone: False
    firewall_strict_drop: False   # baseline owns default-zone; also L2-gated
    sshd: False                   # baseline:ssh owns sshd (FreeIPA key-only/GSSAPI auth)
    usb_storage: False            # baseline:usb blocks usb-storage + uas

  # sysctl is owned solely by the formula now (sysctl_kernel control →
  # /etc/sysctl.d/99-cis.conf). The formula's CIS base set is
  # IPv4-network focused; carry over the kernel-memory + IPv6 hardening
  # that baseline.sysctl used to provide so nothing silently regresses.
  # network.sls merges this over its sysctl_base (extra keys win).
  sysctl:
    kernel.kptr_restrict: 2
    kernel.dmesg_restrict: 1
    kernel.randomize_va_space: 2
    kernel.sysrq: 0
    fs.suid_dumpable: 0
    net.ipv6.conf.all.accept_redirects: 0
    net.ipv6.conf.default.accept_redirects: 0
    net.ipv6.conf.all.accept_source_route: 0
    net.ipv6.conf.default.accept_source_route: 0
    net.ipv6.conf.all.forwarding: 0
    net.ipv6.conf.default.forwarding: 0

  # Optional overrides (formula defaults are sane; set only what you need):
  # sshd_options:
  #   PermitRootLogin: 'no'
  #   PasswordAuthentication: 'no'
  # log_server: '@localhost'
  # lookup:
  #   selinux_runtime_managed: True   # hosts WITH libselinux-bindings (security:SELinux)
