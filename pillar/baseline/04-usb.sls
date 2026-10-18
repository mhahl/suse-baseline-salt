# =====================================================================
# SECTION: baseline:usb — USB mass-storage blocking
#
# WHY: USB storage is the classic data-exfiltration / BadUSB drop
#   vector. Blocking at the modprobe layer (blacklist usb-storage +
#   uas) survives reboots and is removable in one pillar flip for
#   break-glass workstations.
#
# CONSUMED BY: salt/baseline/usb/init.sls via
#   pillar.get('baseline:usb:block_storage', True). True writes
#   /etc/modprobe.d/99-baseline-usb-storage.conf + rmmod; False removes
#   the file so storage works again.
#
# EXAMPLE — allow USB storage on a transfer host:
#   baseline:
#     usb:
#       block_storage: false
# =====================================================================
baseline:
  usb:
    block_storage: true
