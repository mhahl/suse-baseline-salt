{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/install.sls — install the community Trivy package.
trivy_package:
  pkg.installed:
    - name: trivy
{% if trivy.pkg_version %}
    - version: {{ trivy.pkg_version }}
{% endif %}
