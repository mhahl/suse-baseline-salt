updates_zypper_config:
  file.managed:
    - name: /etc/zypp/zypp.conf
    - source: salt://baseline/updates/templates/zypp.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

{# zypper dup is a rolling-release operation: running it on Leap/SLES
   production hosts risks vendor-change breakage, so auto_dup applies to
   Tumbleweed only no matter what pillar requests. #}
{% set auto_dup = salt['pillar.get']('baseline:updates:auto_dup', False) and grains.get('os', '') == 'openSUSE Tumbleweed' %}
{% if auto_dup %}
tumbleweed_full_update:
  cmd.run:
    - name: /usr/bin/zypper --non-interactive dup --no-recommends
    - onlyif: /usr/bin/zypper --non-interactive list-patches 2>/dev/null | grep -qi 'security'
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
