# Auditd forensic rules for SUSE baseline
# Requires audit package (usually present on Tumbleweed)

{% from 'baseline/map.jinja' import running_in_container with context %}

audit_package:
  pkg.installed:
    - name: audit

audit_rules:
  file.managed:
    - name: /etc/audit/rules.d/99-baseline.rules
    - source: salt://baseline/audit/templates/99-baseline-audit.rules.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0640'
    - require:
      - pkg: audit_package

{% if not running_in_container %}
  cmd.run:
    - name: /sbin/augenrules --load
    - onchanges:
      - file: audit_rules
    - require:
      - file: audit_rules
{% else %}
augenrules_skipped_in_container:
  test.show_notification:
    - text: "Skipping augenrules --load (running in container - audit subsystem is limited)"
{% endif %}

{% if not running_in_container %}
auditd_service:
  service.running:
    - name: auditd
    - enable: True
    - watch:
      - file: audit_rules
    - require:
      - pkg: audit_package
      - cmd: audit_rules
{% else %}
# Still enable (but do not start) so goss/container tests see enabled: true
auditd_enabled:
  service.enabled:
    - name: auditd
    - require:
      - pkg: audit_package
{% endif %}
