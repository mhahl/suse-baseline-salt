# Auditd forensic rules for SUSE baseline
# Requires audit package (usually present on Tumbleweed)

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

  cmd.run:
    - name: /sbin/augenrules --load
    - onchanges:
      - file: audit_rules
    - require:
      - file: audit_rules

auditd_service:
  service.running:
    - name: auditd
    - enable: True
    - watch:
      - file: audit_rules
    - require:
      - pkg: audit_package
      - cmd: audit_rules
