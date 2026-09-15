{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/scan.sls — cache dir plus one initial scan on first apply.
# Routine scans run from the daily schedule (schedule.sls).

trivy_cache_dir:
  file.directory:
    - name: {{ trivy.cache_dir }}
    - mode: 755

{% if trivy.run_initial_scan %}
# Skip when the binary is absent (failed/never-ran install): a scan that
# cannot run only records an error payload. The daily schedule reports the
# missing binary loudly enough via the module's error message.
trivy_initial_scan:
  module.run:
    - name: trivy_scan.scan
    - unless: test -s {{ trivy.report_path }}
    - onlyif: test -x /usr/bin/trivy -o -x /usr/local/bin/trivy
    - require:
      - file: trivy_cache_dir
      - module: trivy_sync_modules
{% if trivy.install_flavor == 'binary' %}
      - cmd: trivy_binary
{% elif trivy.install_flavor in ('zypper', 'rpm_repo') %}
      - pkg: trivy_package
{% endif %}
{% endif %}
