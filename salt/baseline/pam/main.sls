# PAM hardening (faillock + password quality)

pam_packages:
  pkg.installed:
    - pkgs:
      - pam
      - pam-config
      - cracklib

faillock_config:
  file.managed:
    - name: /etc/security/faillock.conf
    - source: salt://baseline/pam/templates/faillock.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: pam_packages

pwquality_config:
  file.managed:
    - name: /etc/security/pwquality.conf
    - source: salt://baseline/pam/templates/pwquality.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: pam_packages

# Note: login.defs is partially managed by other packages.
# Consider adding a state that sets specific values if needed in the future.
