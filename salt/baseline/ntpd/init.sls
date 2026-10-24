{# Clock sync via FreeBSD's base ntpd (baseline.ntpd) — the FreeBSD
   counterpart of baseline.timesyncd. No package to install: ntpd ships
   in the FreeBSD base system. Config from baseline:ntp (servers,
   optional fallback). ntpd_sync_on_start allows one step at boot (the
   modern replacement for ntpdate) then slews only. ntpdate is disabled
   so two daemons can never step the clock together.
   Apply with: salt '*' state.apply baseline.ntpd #}
{% set ntp = salt['pillar.get']('baseline:ntp', {}) %}

ntpd_config:
  file.managed:
    - name: /etc/ntp.conf
    - source: salt://baseline/ntpd/templates/ntp.conf.jinja
    - template: jinja
    - user: root
    - group: wheel
    - mode: '0644'
    - context:
        ntp: {{ ntp }}

ntpd_rc_config:
  file.managed:
    - name: /etc/rc.conf.d/ntpd
    - contents: |
        ntpd_sync_on_start="YES"
    - user: root
    - group: wheel
    - mode: '0644'
    - require:
      - file: ntpd_config

# The deprecated ntpdate one-shot is disabled (green no-op where it does
# not exist); ntpd_sync_on_start above replaces it.
ntpdate_service:
  service.disabled:
    - name: ntpdate

ntpd_service:
  service.running:
    - name: ntpd
    - enable: True
    - watch:
      - file: ntpd_config
    - require:
      - file: ntpd_config
      - file: ntpd_rc_config
      - service: ntpdate_service
