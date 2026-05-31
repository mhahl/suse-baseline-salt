# USB / Removable media control

{% set block_usb_storage = salt['pillar.get']('baseline:usb:block_storage', True) %}

{% if block_usb_storage %}
usb_storage_block:
  file.managed:
    - name: /etc/modprobe.d/99-baseline-usb-storage.conf
    - contents: |
        # Block USB storage devices (baseline hardening)
        blacklist usb-storage
        blacklist uas
    - user: root
    - group: root
    - mode: '0644'

  cmd.run:
    - name: rmmod usb_storage uas 2>/dev/null || true
    - onlyif: lsmod | grep -qE 'usb_storage|uas'
{% endif %}
