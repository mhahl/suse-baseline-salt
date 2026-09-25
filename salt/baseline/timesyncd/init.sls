{# Clock sync via systemd-timesyncd, the only NTP client on these
   hosts. chronyd is stopped, disabled, and removed with its config so
   a leftover install can never step the clock alongside timesyncd.
   Server list comes from baseline:ntp (servers, optional fallback).
   Apply with: salt '*' state.apply baseline.timesyncd #}
timesyncd_config:
  file.managed:
    - name: /etc/systemd/timesyncd.conf.d/99-baseline.conf
    - source: salt://baseline/timesyncd/templates/timesyncd.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - context:
        ntp: {{ salt['pillar.get']('baseline:ntp', {}) }}

# Stop and disable chronyd first so the two daemons never step the
# clock together, then remove the superseded package and its config.
# All three are green no-ops where chrony was never installed.
chronyd_service:
  service.dead:
    - name: chronyd
    - enable: False

timesyncd_service:
  service.running:
    - name: systemd-timesyncd
    - enable: True
    - watch:
      - file: timesyncd_config
    - require:
      - file: timesyncd_config
      - service: chronyd_service

chrony_package:
  pkg.removed:
    - name: chrony
    - require:
      - service: timesyncd_service

chrony_config:
  file.absent:
    - name: /etc/chrony.conf
    - require:
      - pkg: chrony_package
