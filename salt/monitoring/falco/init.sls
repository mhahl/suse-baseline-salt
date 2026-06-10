{% set falco = salt['pillar.get']('monitoring:falco', {}) %}
{% set enabled = salt['pillar.get']('monitoring:falco:enabled', False) %}

{% if enabled %}

falco_gpg_key:
  cmd.run:
    - name: rpm --import https://falco.org/repo/falcosecurity-packages.asc
    - unless: rpm -qa | grep -q 'gpg-pubkey.*falcosecurity'

falco_repo:
  file.managed:
    - name: /etc/zypp/repos.d/falcosecurity.repo
    - source: https://falco.org/repo/falcosecurity-rpm.repo
    - skip_verify: true
    - require:
      - cmd: falco_gpg_key

falco_repo_refresh:
  cmd.run:
    - name: zypper --gpg-auto-import-keys -n refresh falcosecurity
    - require:
      - file: falco_repo

falco_package:
  pkg.installed:
    - name: falco
    - env:
        FALCO_FRONTEND: noninteractive
    - require:
      - cmd: falco_repo_refresh

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