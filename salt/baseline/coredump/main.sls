# System-wide core dump hardening (systemd-coredump)
# Complements the per-shell ulimit in the profile module.

coredump_config:
  file.managed:
    - name: /etc/systemd/coredump.conf.d/99-baseline.conf
    - source: salt://baseline/coredump/templates/99-baseline-coredump.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - dir_mode: '0755'

  service.running:
    - name: systemd-coredump.socket
    - enable: True
    - watch:
      - file: coredump_config
