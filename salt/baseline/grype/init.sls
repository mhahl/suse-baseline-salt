# baseline.grype/init.sls — Grype CVE scanning: install, scan, daily schedule.
# Apply with: salt '*' state.apply baseline.grype
# (also included in the full baseline).
# Mine key for the dashboard: grype.scan_summary (see README.md).

grype_sync_modules:
  module.run:
    - name: saltutil.sync_modules
    - reload_modules: True
    - order: 1

include:
  - baseline.grype.install
  - baseline.grype.scan
  - baseline.grype.schedule
