{% from "baseline/grype/map.jinja" import grype with context %}
# baseline.grype/scan.sls — cache dir plus one initial scan on first apply.
# Routine scans run from the daily schedule (schedule.sls). The report
# is chmodded 0640 by grype_scan.scan (local-only, not world-readable).

grype_cache_dir:
  file.directory:
    - name: {{ grype.cache_dir }}
    - mode: 755

{% if grype.run_initial_scan %}
# Gate on the canonical GitHub-install path (see _modules/_grype_bin).
# Skip when the binary is absent (failed/never-ran install): a scan that
# cannot run only records an error payload. The daily schedule reports
# the missing binary loudly enough via the module's error message.
# require: below is ordering only (cache, modules, binary first);
# onlyif/unless are the actual skip conditions.
grype_initial_scan:
  module.run:
    - name: grype_scan.scan
    - unless: test -s {{ grype.report_path }}
    - onlyif: test -x /usr/local/bin/grype
    - require:
      - file: grype_cache_dir
      - module: grype_sync_modules
      - archive: grype_binary
{% endif %}
