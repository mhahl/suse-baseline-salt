{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/scan.sls — cache dir plus one initial scan on first apply.
# Routine scans run from the daily schedule (schedule.sls). The report
# is chmodded 0640 by trivy_scan.scan (local-only, not world-readable).

trivy_cache_dir:
  file.directory:
    - name: {{ trivy.cache_dir }}
    - mode: 755

{% if trivy.run_initial_scan %}
# Gate on both binary locations (see _modules/_trivy_bin): the distro
# package installs /usr/bin/trivy, a pinned binary lives at
# /usr/local/bin/trivy. Skip when neither is present — a scan that
# cannot run only records an error payload. The daily schedule reports
# the missing binary loudly enough via the module's error message.
# require: below is ordering only (cache, modules, package first);
# onlyif/unless are the actual skip conditions.
trivy_initial_scan:
  module.run:
    - name: trivy_scan.scan
    - unless: test -s {{ trivy.report_path }}
    - onlyif: test -x /usr/local/bin/trivy || test -x /usr/bin/trivy
    - require:
      - file: trivy_cache_dir
      - module: trivy_sync_modules
      - pkg: trivy_package
{% endif %}
