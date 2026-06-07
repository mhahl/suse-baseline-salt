# Prometheus node_exporter
# Exposes hardware and OS metrics

{% set node_exporter = pillar.get('monitoring:node_exporter', {}) %}
{% set enabled = node_exporter.get('enabled', False) %}

{% if enabled %}

{% from 'baseline/map.jinja' import running_in_container with context %}

node_exporter_package:
  pkg.installed:
    - name: prometheus-node_exporter

# Main configuration (most config is done via command line flags)
node_exporter_config:
  file.managed:
    - name: /etc/sysconfig/prometheus-node_exporter
    - contents: |
        ARGS="--web.listen-address={{ node_exporter.get('listen_address', ':9100') }}"
    - user: root
    - group: root
    - mode: '0644'

{% if not running_in_container %}
node_exporter_service:
  service.running:
    - name: prometheus-node_exporter
    - enable: True
    - watch:
      - file: node_exporter_config
    - require:
      - pkg: node_exporter_package
{% else %}
# Still enable (but do not start) so goss/container tests see enabled: true
node_exporter_enabled:
  service.enabled:
    - name: prometheus-node_exporter
    - require:
      - pkg: node_exporter_package
{% endif %}

{% else %}

node_exporter_disabled:
  test.show_notification:
    - text: "node_exporter is disabled in pillar (baseline:node_exporter:enabled)"

{% endif %}