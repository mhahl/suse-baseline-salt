{# Minion's addresses for its masters: IPs, not DNS, with native
   Salt failover across the list. The default ['salt'] is Salt's own
   built-in default, so an untouched pillar changes nothing.
   FreeBSD keeps the config under /usr/local/etc/salt (the FreeBSD
   salt package's config dir) and names the rc service salt_minion. #}
{% set _family = grains.get('os_family', '') %}
{% set _conf_dir = '/usr/local/etc/salt/minion.d' if _family == 'FreeBSD' else '/etc/salt/minion.d' %}
{% set _svc = 'salt_minion' if _family == 'FreeBSD' else 'salt-minion' %}
{% set _group = 'wheel' if _family == 'FreeBSD' else 'root' %}
{% set cfg = salt['pillar.get']('baseline:minion', {}) %}
{% set enabled = cfg.get('enabled', True) %}
{% set masters = cfg.get('masters', ['salt']) %}
{% if masters is string %}
{% set masters = [masters] %}
{% endif %}

{% if enabled %}
minion_master_config:
  file.managed:
    - name: {{ _conf_dir }}/99-baseline.conf
    - contents: |
        # Managed by baseline.minion — masters by IP, not DNS.
        master:
{% for addr in masters %}
          - {{ addr }}
{% endfor %}
        master_type: failover
    - user: root
    - group: {{ _group }}
    - mode: '0644'

# The new addresses apply on minion restart: run it only where the
# service is actually supervised (never in CI containers) and only on
# config change. The job's own return is lost on restart — accepted.
minion_restart:
  module.run:
    - name: service.restart
    - m_name: {{ _svc }}
    - onchanges:
      - file: minion_master_config
{% if _family == 'FreeBSD' %}
    - onlyif: test -x /usr/local/etc/rc.d/{{ _svc }}
{% else %}
    - onlyif: test -d /run/systemd/system
{% endif %}
{% else %}
minion_master_config:
  file.absent:
    - name: {{ _conf_dir }}/99-baseline.conf
{% endif %}
