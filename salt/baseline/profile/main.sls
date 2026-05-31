# Deploy hardened bash profile (history forensics, session security, umask, etc.)
baseline_bash_profile:
  file.managed:
    - name: /etc/profile.d/99-baseline.sh
    - source: salt://baseline/profile/templates/99-baseline.sh
    - user: root
    - group: root
    - mode: '0644'
