{% from "baseline/systemd-resolved/map.jinja" import resolved with context %}
systemd_resolved_package:
  pkg.installed:
    - name: {{ resolved.pkg }}

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

{% if grains.get('os_family', '') == 'Suse' %}
# openSUSE/SLE netconfig rewrites /etc/resolv.conf on network events,
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
{% endif %}

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
