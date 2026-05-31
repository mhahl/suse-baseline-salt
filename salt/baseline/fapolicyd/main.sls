# fapolicyd - File Access Policy Daemon (execution control / allowlisting)

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

fapolicyd_service:
  service.running:
    - name: fapolicyd
    - enable: True
    - watch:
      - file: fapolicyd_config
    - require:
      - pkg: fapolicyd_package
