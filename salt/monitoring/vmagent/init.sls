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

# Install vmagent from the openSUSE Build Service Percona repository
# (provides VictoriaMetrics package containing vmagent, vmalert, etc.)
vmagent_repo:
  file.managed:
    - name: /etc/zypp/repos.d/server_database_percona.repo
    - source: https://download.opensuse.org/repositories/server:/database:/percona/openSUSE_Tumbleweed/server:database:percona.repo
    - skip_verify: true

vmagent_repo_refresh:
  cmd.run:
    - name: zypper --gpg-auto-import-keys -n refresh server_database_percona
    - require:
      - file: vmagent_repo

vmagent_package:
  pkg.installed:
    - name: VictoriaMetrics
    - require:
      - cmd: vmagent_repo_refresh

# Ensure the packaged victoria-metrics server unit is not enabled
# (we only want the vmagent agent from this package)
victoria_metrics_server_disabled:
  service.dead:
    - name: victoria-metrics
    - enable: False
    - require:
      - pkg: vmagent_package

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
      - pkg: vmagent_package
      - file: vmagent_service_file

{% else %}

vmagent_disabled:
  test.show_notification:
    - text: "vmagent is disabled in pillar (monitoring:vmagent:enabled)"

{% endif %}