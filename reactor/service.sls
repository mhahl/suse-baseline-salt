{# Reactor: restart baseline daemons reported down by the service beacon.
   Feeding beacon (minion config):
     beacons:
       service:
         - services: {systemd-resolved: {}, systemd-timesyncd: {}}
           interval: 60
   Tag wired in reactor.conf.example. Only allowlisted services render an
   action, and only when reported not-running — anything else is a no-op.
   Confirm the exact tag and data fields on your master with:
   salt-run state.event pretty=True #}
{% set allowed = ['systemd-resolved', 'systemd-timesyncd'] %}
{% set svc = data.get('service_name', '') %}
{% set running = data.get('state', data.get('running', True)) %}
{% if svc in allowed and not running %}
restart_{{ svc | replace('-', '_') }}:
  local_service.start:
    - tgt: {{ data['id'] }}
    - arg:
      - {{ svc }}
{% endif %}
