# Firewalld hardening - default deny with explicit allow list

{% from 'baseline/map.jinja' import running_in_container with context %}

firewalld_package:
  pkg.installed:
    - name: firewalld

{% if not running_in_container %}
firewalld_service:
  service.running:
    - name: firewalld
    - enable: True
    - require:
      - pkg: firewalld_package
{% else %}
# Still enable (but do not start) so goss/container tests see enabled: true
firewalld_enabled:
  service.enabled:
    - name: firewalld
    - require:
      - pkg: firewalld_package
{% endif %}

# Set default zone to drop (very restrictive) - only when firewalld is manageable
{% if not running_in_container %}
firewalld_default_zone:
  cmd.run:
    - name: firewall-cmd --set-default-zone=drop
    - unless: firewall-cmd --get-default-zone | grep -q '^drop$'
    - require:
      - service: firewalld_service
{% endif %}

{% if not running_in_container %}
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
{% else %}
# Skip all runtime firewall-cmd operations in containers
firewalld_container_skip:
  test.show_notification:
    - text: "Skipping firewalld runtime configuration (running in container)"
{% endif %}
