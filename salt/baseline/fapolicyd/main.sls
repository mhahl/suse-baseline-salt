# fapolicyd - File Access Policy Daemon (execution control / allowlisting)

{% from 'baseline/map.jinja' import running_in_container with context %}

{% set fapolicyd = pillar.get('baseline:fapolicyd', {}) %}
{% set enabled = fapolicyd.get('enabled', False) %}

{% if enabled %}
fapolicyd_package:
  pkg.installed:
    - name: fapolicyd

fapolicyd_config:
  file.managed:
    - name: /etc/fapolicyd/fapolicyd.conf
    - source: salt://baseline/fapolicyd/templates/fapolicyd.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - require:
      - pkg: fapolicyd_package

{% if not running_in_container %}
fapolicyd_service:
  service.running:
    - name: fapolicyd
    - enable: True
    - watch:
      - file: fapolicyd_config
    - require:
      - pkg: fapolicyd_package
{% else %}
fapolicyd_service_skipped:
  test.show_notification:
    - text: "Skipping fapolicyd service (running in container)"
{% endif %}

{% else %}
fapolicyd_disabled:
  test.show_notification:
    - text: "fapolicyd is disabled in pillar (baseline:fapolicyd:enabled)"
{% endif %}
