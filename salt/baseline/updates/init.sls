{# Edit the vendor zypp.conf in place. A wholesale file.managed wipe
   drops distro/admin keys (excludedocs, solver, credentials paths)
   that libzypp compiled defaults do not restore. #}
updates_zypper_config:
  file.keyvalue:
    - name: /etc/zypp/zypp.conf
    - separator: ' = '
    - append_if_not_found: True
    - key_values:
        solver.onlyRequires: 'true'
        solver.allowVendorChange: 'false'
        download.use_deltarpm: 'true'

{# zypper dup is a rolling-release operation: running it on Leap/SLES
   production hosts risks vendor-change breakage, so auto_dup applies to
   Tumbleweed only no matter what pillar requests. Tumbleweed has no
   patch metadata, so list-patches never fires — gate on dup --dry-run. #}
{% set auto_dup = salt['pillar.get']('baseline:updates:auto_dup', False) and grains.get('os', '') == 'openSUSE Tumbleweed' %}
{% if auto_dup %}
tumbleweed_full_update:
  cmd.run:
    - name: /usr/bin/zypper --non-interactive dup --no-recommends --allow-downgrade
    - onlyif: /usr/bin/zypper --non-interactive dup --dry-run --no-recommends --allow-downgrade 2>/dev/null | grep -qE 'going to be (upgraded|installed|removed)'
    - timeout: 3600
{% endif %}

# Runs only when something actually changed (zypp config or the dup above),
# so a no-op highstate stays green instead of reporting a change every run.
last_update_marker:
  cmd.run:
    - name: date -Iseconds > /var/log/baseline-last-update
    - onchanges:
      - file: updates_zypper_config
{% if auto_dup %}
      - cmd: tumbleweed_full_update
{% endif %}
