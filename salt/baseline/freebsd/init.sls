# Salt 3008 (Argon) no longer ships the FreeBSD service execution module
# ("great module migration"): without the vendored copy in
# salt/_modules/freebsdservice.py, no module provides the `service`
# virtual name and every service.* state fails. Sync first (order: 1)
# so service.* works in the same run that introduces the module —
# mirroring overstate.grype's sync step.
freebsd_sync_modules:
  module.run:
    - name: saltutil.sync_modules
    - reload_modules: True
    - order: 1

include:
  - baseline.netbird
  - baseline.schedule
  - baseline.updates
