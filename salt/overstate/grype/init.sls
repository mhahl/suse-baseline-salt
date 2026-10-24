# overstate.grype/init.sls — Grype CVE scanning: install, scan, daily schedule.
# Apply with: salt '*' state.apply overstate.grype
# (also included in the full overstate namespace; decoupled from baseline).
# Mine keys for the dashboard: grype.scan_summary (slim) +
# grype.scan_detail (full findings) — see README.md.

{# FreeBSD: grype ships no FreeBSD binaries (linux/darwin/windows only),
   so the whole overstate namespace is a no-op there. Skipped, not
   failed: highstate stays green and the grype-cve-scan schedule never
   renders on FreeBSD hosts. #}
{% if grains.get('os_family', '') == 'FreeBSD' %}
freebsd_overstate_skipped:
  test.skip_sls:
    - name: overstate.grype requires grype Linux binaries; skipped on FreeBSD
{% else %}
grype_sync_modules:
  module.run:
    - name: saltutil.sync_modules
    - reload_modules: True
    - order: 1

include:
  - overstate.grype.install
  - overstate.grype.scan
  - overstate.grype.schedule
{% endif %}
