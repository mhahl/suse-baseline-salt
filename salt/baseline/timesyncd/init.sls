{# Clock sync via systemd-timesyncd, the only NTP client on these
   hosts. Server list comes from baseline:ntp (servers, optional
   fallback).
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

timesyncd_service:
  service.running:
    - name: systemd-timesyncd
    - enable: True
    - watch:
      - file: timesyncd_config
    - require:
      - file: timesyncd_config
