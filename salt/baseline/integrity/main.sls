# File integrity monitoring (rpm + optional AIDE)

{% set use_aide = salt['pillar.get']('baseline:integrity:use_aide', False) %}

{% from 'baseline/map.jinja' import running_in_container with context %}

integrity_packages:
  pkg.installed:
    - pkgs:
      - rpm
      - cronie
      {% if use_aide %} - aide {% endif %}

{% if use_aide %}
aide_config:
  file.managed:
    - name: /etc/aide/aide.conf
    - source: salt://baseline/integrity/templates/aide.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

aide_db_init:
  cmd.run:
    - name: /usr/sbin/aide --init
    - creates: /var/lib/aide/aide.db.new.gz
    - require:
      - pkg: integrity_packages
      - file: aide_config
{% endif %}

# Ensure required directories exist for cron (critical in containers)
cron_directories:
  file.directory:
    - names:
      - /var/spool/cron/crontabs
      - /etc/cron.d
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
    - require:
      - pkg: integrity_packages

{% if not running_in_container %}
# Ensure cron daemon is running (required for cron.present to take effect)
cron_service:
  service.running:
    - name: cron
    - enable: True
    - require:
      - pkg: integrity_packages
      - file: cron_directories

# Daily rpm verification (lightweight)
integrity_rpm_check:
  cron.present:
    - name: /usr/bin/rpm -Va --nomtime --nosize --nomd5 2>&1 | logger -t rpm-integrity
    - user: root
    - hour: 4
    - minute: 17
    - require:
      - pkg: integrity_packages
      - file: cron_directories
      - service: cron_service
{% else %}
# Skip cron job management in containers
cron_container_skip:
  test.show_notification:
    - text: "Skipping cron.present and cron service (running in container)"
{% endif %}
