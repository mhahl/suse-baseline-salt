{# Minion's addresses for its masters: IPs, not DNS, with native
   Salt failover across the list. The default ['salt'] is Salt's own
   built-in default, so an untouched pillar changes nothing. #}
{% set cfg = salt['pillar.get']('baseline:minion', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set masters = cfg.get('masters', ['salt']) %}
{% if masters is string %}
{% set masters = [masters] %}
{% endif %}

{% if enabled %}
minion_master_config:
  file.managed:
    - name: /etc/salt/minion.d/99-baseline.conf
    - contents: |
        # Managed by baseline.minion — masters by IP, not DNS.
        master:
{% for addr in masters %}
          - {{ addr }}
{% endfor %}
        master_type: failover
    - user: root
    - group: root
    - mode: '0644'

# The new addresses apply on minion restart: run it only where systemd
# supervises the minion (never in CI containers) and only on config
# change. The job's own return is lost on restart — accepted.
minion_restart:
  module.run:
    - name: service.restart
    - m_name: salt-minion
    - onchanges:
      - file: minion_master_config
    - onlyif: test -d /run/systemd/system
{% else %}
minion_master_config:
  file.absent:
    - name: /etc/salt/minion.d/99-baseline.conf
{% endif %}
