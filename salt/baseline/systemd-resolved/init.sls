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
