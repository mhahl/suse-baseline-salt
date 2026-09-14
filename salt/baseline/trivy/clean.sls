{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/clean.sls — remove the schedule, package/binary/repo, and cache.
# Apply with: salt '<minion>' state.apply baseline.trivy.clean

trivy-cve-scan:
  schedule.absent: []

{% if trivy.install_flavor == 'rpm_repo' %}
trivy repository:
  pkgrepo.absent:
    - name: trivy
{% endif %}

trivy package:
  pkg.removed:
    - name: trivy

{% if trivy.install_flavor == 'binary' %}
{% set _tar = 'trivy_' ~ trivy.version ~ '_Linux-' ~ trivy.arch ~ '.tar.gz' %}
trivy binary:
  file.absent:
    - name: /usr/local/bin/trivy

trivy tarball:
  file.absent:
    - name: {{ trivy.cache_dir }}/{{ _tar }}
{% endif %}

trivy cache dir:
  file.absent:
    - name: {{ trivy.cache_dir }}
