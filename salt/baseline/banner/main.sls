# MOTD banner (late-loading via 99- prefix)
motd_banner:
  file.managed:
    - name: /etc/motd.d/99-steggy
    - source: salt://baseline/banner/templates/99-steggy
    - user: root
    - group: root
    - mode: '0644'
    - template: null
