{# baseline.timesyncd/init.sls — clock sync via systemd-timesyncd.
   Replaces baseline.chrony: one fewer daemon, no extra package, and no
   fight between two NTP clients. Server list comes from the same
   baseline:ntp pillar the chrony state used (servers, optional
   fallback); chrony-only keys (iburst, driftfile, ...) are inert now.
   Apply with: salt '*' state.apply baseline.timesyncd
   (also included in the full baseline). #}
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

# Stop chronyd first so the two daemons never step the clock together,
# then remove the superseded package and its config.
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
