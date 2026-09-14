{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/clean.sls — remove the schedule, package/binary/repo, and cache.
# Apply with: salt '<minion>' state.apply baseline.trivy.clean

trivy_cve_scan:
  schedule.absent:
    - name: trivy-cve-scan

{% if trivy.install_flavor == 'rpm_repo' %}
trivy_repository:
  pkgrepo.absent:
    - name: trivy
{% endif %}

trivy_package:
  pkg.removed:
    - name: trivy

{% if trivy.install_flavor == 'binary' %}
{% set _tar = 'trivy_' ~ trivy.version ~ '_Linux-' ~ trivy.arch ~ '.tar.gz' %}
trivy_binary:
  file.absent:
    - name: /usr/local/bin/trivy

trivy_tarball:
  file.absent:
    - name: {{ trivy.cache_dir }}/{{ _tar }}
{% endif %}

trivy_cache_dir:
  file.absent:
    - name: {{ trivy.cache_dir }}
