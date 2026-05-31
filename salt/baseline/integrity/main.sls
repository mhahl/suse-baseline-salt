# File integrity monitoring (rpm + optional AIDE)

{% set use_aide = salt['pillar.get']('baseline:integrity:use_aide', False) %}

integrity_packages:
  pkg.installed:
    - pkgs:
      - rpm
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

# Daily rpm verification (lightweight)
integrity_rpm_check:
  cron.present:
    - name: /usr/bin/rpm -Va --nomtime --nosize --nomd5 2>&1 | logger -t rpm-integrity
    - user: root
    - hour: 4
    - minute: 17
    - require:
      - pkg: integrity_packages
