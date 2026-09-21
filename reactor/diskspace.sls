{# Reactor: bounded cleanup when the diskspace beacon fires. This
   baseline's disk hogs are the journal, zypper caches, and trivy data —
   all regenerable — so vacuuming them automatically is safe. The trivy
   report.json (mine source of truth) is kept. Feeding beacon:
     beacons:
       diskspace:
         - interval: 300
           threshold: 85%
   The guard re-checks usage when the field is present (the beacon only
   fires over threshold, so a missing field still acts). Confirm the exact
   tag and data fields on your master with:
   salt-run state.event pretty=True #}
{% set usage = data.get('usage', 100) | string | replace('%', '') | int %}
{% if usage >= 85 %}
disk_cleanup_journal:
  local_cmd.run:
    - tgt: {{ data['id'] }}
    - arg:
      - journalctl --vacuum-size=500M
disk_cleanup_zypper:
  local_cmd.run:
    - tgt: {{ data['id'] }}
    - arg:
      - zypper --non-interactive clean --all
{% endif %}
