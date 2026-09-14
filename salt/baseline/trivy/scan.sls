{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/scan.sls — cache dir plus one initial scan on first apply.
# Routine scans run from the daily schedule (schedule.sls).

trivy_cache_dir:
  file.directory:
    - name: {{ trivy.cache_dir }}
    - mode: 755

{% if trivy.run_initial_scan %}
trivy_initial_scan:
  module.run:
    - name: trivy_scan.scan
    - unless: test -s {{ trivy.report_path }}
    - require:
      - file: trivy_cache_dir
{% endif %}
