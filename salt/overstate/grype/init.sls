# overstate.grype/init.sls — Grype CVE scanning: install, scan, daily schedule.
# Apply with: salt '*' state.apply overstate.grype
# (also included in the full overstate namespace; decoupled from baseline).
# Mine keys for the dashboard: grype.scan_summary (slim) +
# grype.scan_detail (full findings) — see README.md.

grype_sync_modules:
  module.run:
    - name: saltutil.sync_modules
    - reload_modules: True
    - order: 1

include:
  - overstate.grype.install
  - overstate.grype.scan
  - overstate.grype.schedule
