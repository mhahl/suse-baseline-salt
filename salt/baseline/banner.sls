# /srv/salt/baseline/banner.sls
motd_banner:
  file.managed:
    - name: /etc/motd.d/99-steggy
    - source: salt://baseline/templates/banner/99-steggy
    - user: root
    - group: root
    - mode: '0644'
    - template: null
