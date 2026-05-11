# Deploy custom bash profile for all users
baseline_bash_profile:
  file.managed:
    - name: /etc/profile.d/99-baseline.sh
    - source: salt://baseline/profile/templates/99-baseline.sh
    - user: root
    - group: root
    - mode: '0755'
