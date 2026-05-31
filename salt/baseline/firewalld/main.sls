# Firewalld hardening - default deny with explicit allow list

firewalld_package:
  pkg.installed:
    - name: firewalld

firewalld_service:
  service.running:
    - name: firewalld
    - enable: True
    - require:
      - pkg: firewalld_package

# Set default zone to drop (very restrictive)
firewalld_default_zone:
  cmd.run:
    - name: firewall-cmd --set-default-zone=drop
    - unless: firewall-cmd --get-default-zone | grep -q '^drop$'
    - require:
      - service: firewalld_service

# Allow services from pillar (e.g. ssh, http, https, cockpit, etc.)
{% for svc in pillar.get('baseline:firewalld:allowed_services', ['ssh']) %}
firewalld_allow_{{ svc }}:
  cmd.run:
    - name: firewall-cmd --permanent --add-service={{ svc }}
    - unless: firewall-cmd --list-services | grep -qw {{ svc }}
    - require:
      - cmd: firewalld_default_zone
{% endfor %}

# Allow custom ports from pillar
{% for port in pillar.get('baseline:firewalld:allowed_ports', []) %}
firewalld_allow_port_{{ port | replace('/', '_') }}:
  cmd.run:
    - name: firewall-cmd --permanent --add-port={{ port }}
    - unless: firewall-cmd --list-ports | grep -qw {{ port }}
    - require:
      - cmd: firewalld_default_zone
{% endfor %}

firewalld_reload:
  cmd.run:
    - name: firewall-cmd --reload
    - onchanges:
      - cmd: firewalld_allow_ssh
      - cmd: firewalld_default_zone
      - cmd: firewalld_allow_*
