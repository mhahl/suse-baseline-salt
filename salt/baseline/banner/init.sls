{# Legal-notice MOTD banner. FreeBSD has no /etc/motd.d (that is a
   systemd/pam_motd concept) — base reads a single /etc/motd file. #}
{% set _family = grains.get('os_family', '') %}
{% set _motd = '/etc/motd' if _family == 'FreeBSD' else '/etc/motd.d/99-steggy' %}
{% set _group = 'wheel' if _family == 'FreeBSD' else 'root' %}
motd_banner:
  file.managed:
    - name: {{ _motd }}
    - source: salt://baseline/banner/templates/99-steggy
    - user: root
    - group: {{ _group }}
    - mode: '0644'
    - template: False
