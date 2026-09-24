# baseline.trivy/init.sls — Trivy CVE scanning: install, scan, daily schedule.
# Apply with: salt '*' state.apply baseline.trivy
# (also included in the full baseline).
# Mine key for the dashboard: trivy.scan_summary (see README.md).

trivy_sync_modules:
  module.run:
    - name: saltutil.sync_modules
    - reload_modules: True
    - order: 1

include:
  - baseline.trivy.install
  - baseline.trivy.scan
  - baseline.trivy.schedule
