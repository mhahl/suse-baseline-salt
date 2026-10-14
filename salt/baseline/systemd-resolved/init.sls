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
{% if grains.get('selinux', {}).get('enforced', False) %}
      - cmd: resolved_selinux_relabel
{% endif %}
    - require:
      - pkg: systemd_resolved_package
      - file: resolv_conf_symlink
      - file: resolved_config
{% if grains.get('selinux', {}).get('enforced', False) %}
      - cmd: resolved_selinux_relabel
{% endif %}

{% if grains.get('selinux', {}).get('enforced', False) %}
# SELinux-enforcing hosts: systemd-resolved has to run in its own
# systemd_resolved_t domain. The exec transition keys off the binary
# carrying the systemd_resolved_exec_t file context, so on hosts whose
# files were never (re)labelled the daemon stays in init_t — and init_t is
# denied setattr on the net_conf_t / systemd_resolved_var_run_t files the
# daemon manages at startup (the "won't start until permissive" failure).
# Relabel the binary plus the runtime tree, BEFORE the service state runs.
# The onlyif gates on the label actually being wrong, so quiet highstates
# skip the command (no churn) while any drift self-heals; the service
# watches it so a relabel really restarts the daemon into the right domain.
# Hosts without policycoreutils stay green no-ops.
resolved_selinux_relabel:
  cmd.run:
    - name: restorecon -Rv /usr/lib/systemd/systemd-resolved /run/systemd/resolve
    - onlyif: command -v restorecon && test -e /usr/lib/systemd/systemd-resolved && ! ls -Z /usr/lib/systemd/systemd-resolved | grep -q systemd_resolved_exec_t
    - require:
      - file: resolved_runtime_dir
      - file: resolv_conf_symlink
      - file: resolved_config
{% endif %}
