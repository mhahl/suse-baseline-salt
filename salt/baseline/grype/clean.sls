{% from "baseline/grype/map.jinja" import grype with context %}
# baseline.grype/clean.sls — remove the schedule, binary, and cache.
# Apply with: salt '<minion>' state.apply baseline.grype.clean

grype_cve_scan:
  schedule.absent:
    - name: grype-cve-scan

grype_binary:
  file.absent:
    - name: /usr/local/bin/grype

grype_cache_dir:
  file.absent:
    - name: {{ grype.cache_dir }}
