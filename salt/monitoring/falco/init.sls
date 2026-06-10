{% set falco = pillar.get('monitoring:falco', {}) %}
{% set enabled = falco.get('enabled', False) %}

{% if enabled %}

falco_repo:
  pkgrepo.managed:
    - name: falco
    - humanname: Falco
    - baseurl: https://download.falco.org/packages/rpm
    - gpgkey: https://falco.org/repo/falcosecurity-3672BA8F.asc
    - gpgcheck: 1
    - enabled: 1

falco_package:
  pkg.installed:
    - name: falco
    - require:
      - pkgrepo: falco_repo

falco_config:
  file.managed:
    - name: /etc/falco/falco.yaml
    - source: salt://monitoring/falco/templates/falco.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        falco: {{ falco | tojson }}
    - require:
      - pkg: falco_package

falco_service:
  service.running:
    - name: falco
    - enable: True
    - watch:
      - file: falco_config
    - require:
      - pkg: falco_package

{% else %}

falco_disabled:
  test.show_notification:
    - text: "Falco is disabled in pillar (monitoring:falco:enabled)"

{% endif %}