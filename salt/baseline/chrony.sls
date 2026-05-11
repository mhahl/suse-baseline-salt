chrony_package:
  pkg.installed:
    - name: chrony

chrony_config:
  file.managed:
    - name: /etc/chrony.conf
    - source: salt://baseline/templates/chrony/chrony.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        ntp: {{ salt['pillar.get']('baseline:ntp', {}) }}
    - require:
      - pkg: chrony_package

chrony_service:
  service.running:
    - name: chronyd
    - enable: True
    - restart: True
    - watch:
      - file: chrony_config
