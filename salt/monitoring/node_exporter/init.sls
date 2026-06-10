{% set node_exporter = salt['pillar.get']('monitoring:node_exporter', {}) %}
{% set enabled = salt['pillar.get']('monitoring:node_exporter:enabled', False) %}

{% if enabled %}

node_exporter_package:
  pkg.installed:
    - name: golang-github-prometheus-node_exporter

node_exporter_config:
  file.managed:
    - name: /etc/sysconfig/prometheus-node_exporter
    - contents: |
        ARGS="--web.listen-address={{ node_exporter.get('listen_address', ':9100') }}"
    - user: root
    - group: root
    - mode: '0644'

node_exporter_service:
  service.running:
    - name: prometheus-node_exporter
    - enable: True
    - watch:
      - file: node_exporter_config
    - require:
      - pkg: node_exporter_package

{% else %}

node_exporter_disabled:
  test.show_notification:
    - text: "node_exporter is disabled in pillar (monitoring:node_exporter:enabled)"

{% endif %}
