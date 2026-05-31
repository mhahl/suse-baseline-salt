# GRUB2 bootloader hardening

{% set grub_password = salt['pillar.get']('baseline:grub:password_hash') %}

{% from 'baseline/map.jinja' import running_in_container with context %}

grub_config:
  file.append:
    - name: /etc/default/grub
    - text: |
        GRUB_DISABLE_RECOVERY=true
        GRUB_DISABLE_OS_PROBER=true
    - unless: grep -q "GRUB_DISABLE_RECOVERY=true" /etc/default/grub

{% if not running_in_container %}
grub_update:
  cmd.run:
    - name: /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
    - onchanges:
      - file: grub_config
    - onlyif: test -f /boot/grub2/grub.cfg
{% else %}
grub_update_skipped:
  test.show_notification:
    - text: "Skipping grub2-mkconfig (running in container - no real bootloader)"
{% endif %}

{% if grub_password %}
grub_password:
  file.managed:
    - name: /boot/grub2/user.cfg
    - contents: |
        set superusers="root"
        password_pbkdf2 root {{ grub_password }}
    - user: root
    - group: root
    - mode: '0600'
    - makedirs: True
    - watch_in:
      - cmd: grub_update
{% endif %}
