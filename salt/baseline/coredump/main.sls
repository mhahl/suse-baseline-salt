# System-wide core dump hardening (systemd-coredump)
# Complements the per-shell ulimit in the profile module.

{% from 'baseline/map.jinja' import running_in_container with context %}

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

{% if not running_in_container %}
  service.running:
    - name: systemd-coredump.socket
    - enable: True
    - watch:
      - file: coredump_config
{% else %}
coredump_socket_skipped:
  test.show_notification:
    - text: "Skipping systemd-coredump.socket management (running in container)"
{% endif %}
