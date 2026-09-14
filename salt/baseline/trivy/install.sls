{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/install.sls — install a pinned Trivy per OS flavor:
# rpm_repo (RHEL 9/10) via the official Trivy RPM repo,
# zypper (openSUSE) via the community package,
# binary (SLES and fallback) from the GitHub release tarball.
{% if trivy.install_flavor == 'rpm_repo' %}
trivy_repository:
  pkgrepo.managed:
    - name: trivy
    - humanname: Trivy repository
    - baseurl: https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
    - gpgcheck: 1
    - enabled: 1
    - gpgkey: https://aquasecurity.github.io/trivy-repo/rpm/public.key

trivy_package:
  pkg.installed:
    - name: trivy
{% if trivy.pkg_version %}
    - version: {{ trivy.pkg_version }}
{% endif %}
    - require:
      - pkgrepo: trivy_repository
{% elif trivy.install_flavor == 'zypper' %}
trivy_package:
  pkg.installed:
    - name: trivy
{% if trivy.pkg_version %}
    - version: {{ trivy.pkg_version }}
{% endif %}
{% elif trivy.install_flavor == 'binary' %}
{% set _tar = 'trivy_' ~ trivy.version ~ '_Linux-' ~ trivy.arch ~ '.tar.gz' %}
{% set _url = 'https://github.com/aquasecurity/trivy/releases/download/v' ~ trivy.version ~ '/' ~ _tar %}
# tar extracts the release below; minimal images (e.g. SLES) may not ship it.
trivy_tar:
  pkg.installed:
    - name: tar

trivy_tarball:
  file.managed:
    - name: {{ trivy.cache_dir }}/{{ _tar }}
    - source: {{ _url }}
    - source_hash: https://github.com/aquasecurity/trivy/releases/download/v{{ trivy.version }}/trivy_{{ trivy.version }}_checksums.txt
    - makedirs: True
    - unless: /usr/local/bin/trivy --version 2>/dev/null | grep -q {{ trivy.version }}
    - require:
      - pkg: trivy_tar

trivy_binary:
  cmd.run:
    - name: tar -xzf {{ trivy.cache_dir }}/{{ _tar }} -C /usr/local/bin trivy
    - onchanges:
      - file: trivy_tarball
{% else %}
trivy_unsupported_os:
  test.fail_without_changes:
    - name: trivy formula supports RHEL 9/10, SLES, and openSUSE only
{% endif %}
