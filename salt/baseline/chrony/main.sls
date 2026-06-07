{% from 'baseline/map.jinja' import running_in_container with context %}

chrony_package:
  pkg.installed:
    - name: chrony

chrony_config:
  file.managed:
    - name: /etc/chrony.conf
    - source: salt://baseline/chrony/templates/chrony.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        ntp: {{ salt['pillar.get']('baseline:ntp', {}) }}
    - require:
      - pkg: chrony_package

{% if not running_in_container %}
chrony_service:
  service.running:
    - name: chronyd
    - enable: True
    - watch:
      - file: chrony_config
{% else %}
# Still enable (but do not start) so goss/container tests see enabled: true
chrony_enabled:
  service.enabled:
    - name: chronyd
    - require:
      - pkg: chrony_package
{% endif %}
