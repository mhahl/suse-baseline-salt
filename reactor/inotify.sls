{# Reactor: answer file-tamper events from the inotify beacon.
   Feeding beacon (minion config), scoped to baseline-owned files plus
   auth/ssh material:
     beacons:
       inotify:
         - files:
             /etc/systemd/resolved.conf: {mask: [modify, attrib]}
             /etc/zypp/zypp.conf: {mask: [modify, attrib]}
             /etc/shadow: {mask: [modify, attrib]}
             /etc/ssh/sshd_config: {mask: [modify, attrib]}
           interval: 60
   Baseline-owned paths re-apply their owning module (self-heal); other
   watched paths (passwd/shadow/sudoers/sshd_config) only leave a syslog
   audit line — point those at a notify runner for paging. Any other
   non-empty path gets the audit line too; only a missing path renders
   nothing. Confirm the exact tag and data fields
   on your master with: salt-run state.event pretty=True #}
{% set healing = {
  '/etc/systemd/resolved.conf': 'baseline.systemd-resolved',
  '/etc/resolv.conf': 'baseline.systemd-resolved',
  '/etc/systemd/timesyncd.conf.d/99-baseline.conf': 'baseline.timesyncd',
  '/etc/zypp/zypp.conf': 'baseline.updates',
  '/etc/modprobe.d/99-baseline-usb-storage.conf': 'baseline.usb',
  '/etc/profile.d/99-baseline.sh': 'baseline.profile',
  '/etc/motd.d/99-steggy': 'baseline.banner',
} %}
{% set path = data.get('path', '') %}
{% if path in healing %}
{% set mod = healing[path] %}
reapply_{{ mod | replace('.', '_') | replace('-', '_') }}:
  local_state.apply:
    - tgt: {{ data['id'] }}
    - arg:
      - {{ mod }}
{% elif path %}
audit_{{ path | replace('/', '_') | replace('.', '_') | replace('-', '_') }}:
  local_cmd.run:
    - tgt: {{ data['id'] }}
    - arg:
      - "logger -t salt-reactor 'inotify: {{ path }} changed ({{ data.get('change', 'unknown') }})'"
{% endif %}
