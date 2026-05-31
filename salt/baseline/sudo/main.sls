# Hardened sudo configuration

sudo_package:
  pkg.installed:
    - name: sudo

sudo_hardening:
  file.managed:
    - name: /etc/sudoers.d/99-baseline
    - source: salt://baseline/sudo/templates/99-baseline-sudoers.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0440'
    - require:
      - pkg: sudo_package

  # Validate sudoers syntax on change
  cmd.run:
    - name: /usr/sbin/visudo -c -f /etc/sudoers.d/99-baseline
    - onchanges:
      - file: sudo_hardening
    - require:
      - file: sudo_hardening
