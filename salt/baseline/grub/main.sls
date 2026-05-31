# GRUB2 bootloader hardening

{% set grub_password = salt['pillar.get']('baseline:grub:password_hash') %}

grub_config:
  file.append:
    - name: /etc/default/grub
    - text: |
        GRUB_DISABLE_RECOVERY=true
        GRUB_DISABLE_OS_PROBER=true
    - unless: grep -q "GRUB_DISABLE_RECOVERY=true" /etc/default/grub

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
{% endif %}

grub_update:
  cmd.run:
    - name: /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
    - onchanges:
      - file: grub_config
      - file: grub_password
    - onlyif: test -f /boot/grub2/grub.cfg
