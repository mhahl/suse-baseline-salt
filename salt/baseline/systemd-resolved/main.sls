# Install systemd-resolved (available directly on openSUSE Tumbleweed 2026+)

{% from 'baseline/map.jinja' import running_in_container with context %}

systemd_resolved_package:
  pkg.installed:
    - name: systemd-resolved

# Ensure runtime directory exists (created by the package/service on first start)
resolved_runtime_dir:
  file.directory:
    - name: /run/systemd/resolve
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
    - require:
      - pkg: systemd_resolved_package

# Main configuration from Pillar
resolved_config:
  file.managed:
    - name: /etc/systemd/resolved.conf
    - source: salt://baseline/systemd-resolved/templates/resolved.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        dns: {{ salt['pillar.get']('baseline:systemd_resolved', {}) }}
    - require:
      - pkg: systemd_resolved_package

# Ensure the stub resolver symlink (required for systemd-resolved).
# Do this even in containers so goss tests can assert the symlink.
# Note: force: True intentionally takes over /etc/resolv.conf from other managers.
resolv_conf_symlink:
  file.symlink:
    - name: /etc/resolv.conf
    - target: /run/systemd/resolve/stub-resolv.conf
    - force: True
    - require:
      - pkg: systemd_resolved_package
      - file: resolved_runtime_dir
      - file: resolved_config

{% if not running_in_container %}
# Enable and start the service
resolved_service:
  service.running:
    - name: systemd-resolved
    - enable: True
    - watch:
      - file: resolved_config
    - require:
      - pkg: systemd_resolved_package
      - file: resolv_conf_symlink
{% else %}
# Still enable (but do not start) so goss/container tests see enabled: true
resolved_enabled:
  service.enabled:
    - name: systemd-resolved
    - require:
      - pkg: systemd_resolved_package
      - file: resolv_conf_symlink
{% endif %}
