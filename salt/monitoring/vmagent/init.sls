{% set vmagent = salt['pillar.get']('monitoring:vmagent', {}) %}
{% set enabled = salt['pillar.get']('monitoring:vmagent:enabled', False) %}

{% if enabled %}

vmagent_user:
  user.present:
    - name: vmagent
    - system: True
    - home: /var/lib/vmagent
    - createhome: True

vmagent_directories:
  file.directory:
    - names:
      - /var/lib/vmagent
      - /etc/vmagent
    - user: vmagent
    - group: vmagent
    - mode: '0755'
    - require:
      - user: vmagent_user

vmagent_binary:
  file.managed:
    - name: /usr/local/bin/vmagent
    - source: https://github.com/VictoriaMetrics/VictoriaMetrics/releases/latest/download/vmagent-linux-amd64.tar.gz
    - source_hash: https://github.com/VictoriaMetrics/VictoriaMetrics/releases/latest/download/vmagent-linux-amd64.tar.gz.sha256
    - archive_format: tar
    - tar_options: --strip-components=1
    - user: root
    - group: root
    - mode: '0755'
    - unless: test -x /usr/local/bin/vmagent

vmagent_scrape_config:
  file.managed:
    - name: /etc/vmagent/scrape.yml
    - source: salt://monitoring/vmagent/templates/scrape.yml.jinja
    - template: jinja
    - user: vmagent
    - group: vmagent
    - mode: '0644'
    - context:
        vmagent: {{ vmagent | tojson }}
    - require:
      - file: vmagent_directories

vmagent_service_file:
  file.managed:
    - name: /etc/systemd/system/vmagent.service
    - source: salt://monitoring/vmagent/templates/vmagent.service.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        vmagent: {{ vmagent | tojson }}

vmagent_service:
  service.running:
    - name: vmagent
    - enable: True
    - watch:
      - file: vmagent_scrape_config
      - file: vmagent_service_file
    - require:
      - file: vmagent_binary
      - file: vmagent_service_file

{% else %}

vmagent_disabled:
  test.show_notification:
    - text: "vmagent is disabled in pillar (monitoring:vmagent:enabled)"

{% endif %}