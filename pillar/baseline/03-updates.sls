# =====================================================================
# SECTION: baseline:updates — package-manager config + opt-in upgrade
#
# WHY: Tumbleweed (rolling) and Fedora diverge in tooling (zypper dup
#   vs dnf upgrade) but share one safety rule: NEVER auto-upgrade
#   unless explicitly opted in. The state always enforces sane solver
#   config; the upgrade command only renders when auto_dup is true.
#
# CONSUMED BY: salt/baseline/updates/init.sls via
#   pillar.get('baseline:updates:auto_dup', False). Suse edits
#   /etc/zypp/zypp.conf in place (file.keyvalue); RedHat ensures
#   /etc/dnf/dnf.conf exists without replacing vendor keys.
#
# EXAMPLE — enable nightly rolling upgrades:
#   baseline:
#     updates:
#       auto_dup: true
# =====================================================================
baseline:
  updates:
    # Uses zypper dup on Tumbleweed and dnf upgrade on Fedora.
    auto_dup: true
