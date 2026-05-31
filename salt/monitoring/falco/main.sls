# Falco security runtime monitoring
# https://falco.org/

{% set falco = pillar.get('monitoring:falco', {}) %}
{% set enabled = falco.get('enabled', False) %}

{% if enabled %}

# Add Falco official repository
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

# Main Falco configuration
falco_config:
  file.managed:
    - name: /etc/falco/falco.yaml
    - source: salt://baseline/falco/templates/falco.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        falco: {{ falco | tojson }}
    - require:
      - pkg: falco_package

# Enable and start Falco
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
    - text: "Falco is disabled in pillar (baseline:falco:enabled)"

{% endif %}