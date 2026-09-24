{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/clean.sls — remove the schedule, package, and cache.
# Apply with: salt '<minion>' state.apply baseline.trivy.clean

trivy_cve_scan:
  schedule.absent:
    - name: trivy-cve-scan

trivy_package:
  pkg.removed:
    - name: trivy

trivy_cache_dir:
  file.absent:
    - name: {{ trivy.cache_dir }}
