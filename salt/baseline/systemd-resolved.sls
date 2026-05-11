# Install systemd-resolved (provided by systemd-network on openSUSE)
systemd_resolved_package:
  pkg.installed:
    - name: systemd-resolved

# Main configuration from Pillar
resolved_config:
  file.managed:
    - name: /etc/systemd/resolved.conf
    - source: salt://baseline/templates/systemd-resolved/resolved.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        dns: {{ salt['pillar.get']('baseline:systemd_resolved', {}) }}

# Ensure the stub resolver symlink (required for systemd-resolved)
resolv_conf_symlink:
  file.symlink:
    - name: /etc/resolv.conf
    - target: /run/systemd/resolve/stub-resolv.conf
    - force: True
    - require:
      - file: resolved_config

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
