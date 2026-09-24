systemd_resolved_package:
  pkg.installed:
    - name: systemd-resolved

resolved_runtime_dir:
  file.directory:
    - name: /run/systemd/resolve
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
    - require:
      - pkg: systemd_resolved_package

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

# Tumbleweed netconfig rewrites /etc/resolv.conf on network events,
# ripping out the stub symlink below. An empty DNS policy tells it to
# leave resolv.conf alone; safe here because systemd-resolved (enforced
# below) owns DNS on these hosts.
netconfig_dns_policy:
  file.replace:
    - name: /etc/sysconfig/network/config
    - pattern: '^NETCONFIG_DNS_POLICY=.*'
    - repl: 'NETCONFIG_DNS_POLICY=""'
    - append_if_not_found: True
    - onlyif: test -f /etc/sysconfig/network/config
    - require_in:
      - file: resolv_conf_symlink

resolv_conf_symlink:
  file.symlink:
    - name: /etc/resolv.conf
    - target: /run/systemd/resolve/stub-resolv.conf
    - force: True
    - require:
      - pkg: systemd_resolved_package
      - file: resolved_runtime_dir
      - file: resolved_config

resolved_service:
  service.running:
    - name: systemd-resolved
    - enable: True
    - watch:
      - file: resolved_config
    - require:
      - pkg: systemd_resolved_package
      - file: resolv_conf_symlink
      - file: resolved_config

{% if grains.get('selinux', {}).get('enforced', False) %}
# SELinux-enforcing hosts: the runtime dir and the stub files the daemon
# creates under it inherit tmpfs context, so DNS breaks until contexts are
# restored to policy defaults. Run restorecon after the service actually
# starts or restarts (onchanges), not on every highstate — cmd.run with
# watch still executes unconditionally. The onlyif keeps hosts without
# policycoreutils a green no-op; non-enforcing hosts skip this state.
resolved_selinux_restorecon:
  cmd.run:
    - name: restorecon -Rv /run/systemd/resolve
    - onlyif: command -v restorecon
    - require:
      - file: resolv_conf_symlink
      - service: resolved_service
    - onchanges:
      - service: resolved_service
{% endif %}
