# baseline.trivy/init.sls — Trivy CVE scanning: install, scan, daily schedule.
# Apply with: salt '*' state.apply baseline.trivy
# (also included in the full baseline).
# Mine key for the dashboard: trivy.scan_summary (see README.md).

{% from "baseline/trivy/map.jinja" import trivy with context %}
trivy_sync_modules:
  module.run:
    - name: saltutil.sync_modules
    - order: 1

{# Unsupported platforms skip trivy instead of failing the whole
   baseline: install.sls still fails loudly on direct apply. #}
{% if trivy.install_flavor != 'unsupported' %}
include:
  - baseline.trivy.install
  - baseline.trivy.scan
  - baseline.trivy.schedule
{% endif %}
