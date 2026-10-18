{% set _family = grains.get('os_family', '') %}
{% set auto_dup = salt['pillar.get']('baseline:updates:auto_dup', False) %}
{% set _proxy = salt['pillar.get']('baseline:proxy', {}) %}
{% set _proxy_env = [] %}
{% if _proxy.get('http_proxy', '') %}
{% do _proxy_env.append(('http_proxy', _proxy.get('http_proxy', ''))) %}
{% do _proxy_env.append(('HTTP_PROXY', _proxy.get('http_proxy', ''))) %}
{% endif %}
{% if _proxy.get('https_proxy', '') %}
{% do _proxy_env.append(('https_proxy', _proxy.get('https_proxy', ''))) %}
{% do _proxy_env.append(('HTTPS_PROXY', _proxy.get('https_proxy', ''))) %}
{% endif %}
{% if _proxy.get('no_proxy', '') %}
{% do _proxy_env.append(('no_proxy', _proxy.get('no_proxy', ''))) %}
{% do _proxy_env.append(('NO_PROXY', _proxy.get('no_proxy', ''))) %}
{% endif %}

{% if _family == 'Suse' %}
{# Edit the vendor zypp.conf in place. A wholesale file.managed wipe
   drops distro/admin keys (excludedocs, solver, credentials paths)
   that libzypp compiled defaults do not restore. file.keyvalue cannot
   open a missing file, so ensure an (empty = compiled defaults) one
   exists first without ever touching an existing file's contents. #}
updates_zypp_conf_exists:
  file.managed:
    - name: /etc/zypp/zypp.conf
    - contents: ""
    - replace: False
    - user: root
    - group: root
    - mode: '0644'

updates_zypper_config:
  file.keyvalue:
    - name: /etc/zypp/zypp.conf
    - separator: ' = '
    - append_if_not_found: True
    - key_values:
        solver.onlyRequires: 'true'
        solver.allowVendorChange: 'false'
        download.use_deltarpm: 'true'
    - require:
      - file: updates_zypp_conf_exists
{% elif _family == 'RedHat' %}
{# Keep the distro's DNF defaults; do not replace or invent solver keys. #}
updates_dnf_conf_exists:
  file.managed:
    - name: /etc/dnf/dnf.conf
    - contents: ""
    - replace: False
    - user: root
    - group: root
    - mode: '0644'
{% endif %}

{% if auto_dup and _family == 'Suse' %}
{# zypper dup is Tumbleweed's rolling-release update mechanism. Proxy
   travels via per-command env: (immediate, no daemon restart); the
   persistent PROXY_* config lives in baseline.proxy. #}
tumbleweed_full_update:
  cmd.run:
    - name: /usr/bin/zypper --non-interactive dup --no-recommends --allow-downgrade
    - onlyif: /usr/bin/zypper --non-interactive dup --dry-run --no-recommends --allow-downgrade 2>/dev/null | grep -qE 'going to be (upgraded|installed|removed)'
    - timeout: 3600
{% if _proxy_env %}
    - env:
{% for key, value in _proxy_env %}
      - {{ key }}: {{ value }}
{% endfor %}
{% endif %}
{% elif auto_dup and _family == 'RedHat' %}
fedora_full_update:
  cmd.run:
    - name: dnf upgrade --refresh -y
    - onlyif: dnf -q check-update --refresh >/dev/null 2>&1; test $? -eq 100
    - timeout: 3600
{% if _proxy_env %}
    - env:
{% for key, value in _proxy_env %}
      - {{ key }}: {{ value }}
{% endfor %}
{% endif %}
{% endif %}

# Record changes only when package-manager configuration or an update changes.
last_update_marker:
  cmd.run:
    - name: date -Iseconds > /var/log/baseline-last-update
    - onchanges:
{% if _family == 'Suse' %}
      - file: updates_zypper_config
{% if auto_dup %}
      - cmd: tumbleweed_full_update
{% endif %}
{% elif _family == 'RedHat' %}
      - file: updates_dnf_conf_exists
{% if auto_dup %}
      - cmd: fedora_full_update
{% endif %}
{% endif %}
