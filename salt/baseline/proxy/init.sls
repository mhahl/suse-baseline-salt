{# Egress proxy (baseline.proxy): system-wide env + native tool config.
   Empty pillar values = direct connection (delete stale lines, never
   leave a proxy behind when unset). Non-empty values are written
   additively — existing unrelated lines in each file are preserved.
   /etc/sysconfig/proxy is Suse-only (zypper reads PROXY_* natively);
   /etc/dnf/dnf.conf proxy= is RedHat-only. Recurring Salt-run commands
   (updates, grype scan) additionally get per-command env: so they work
   immediately; the minion daemon itself needs one restart after a
   day-0 proxy change for archive.extracted/pkgrepo downloads. #}
{% set proxy = salt['pillar.get']('baseline:proxy', {}) %}
{% set http_proxy = proxy.get('http_proxy', '') %}
{% set https_proxy = proxy.get('https_proxy', '') %}
{% set no_proxy = proxy.get('no_proxy', 'localhost,127.0.0.1,::1') %}
{% set _family = grains.get('os_family', '') %}
{% set _pairs = [('http_proxy', http_proxy), ('https_proxy', https_proxy), ('no_proxy', no_proxy),
                 ('HTTP_PROXY', http_proxy), ('HTTPS_PROXY', https_proxy), ('NO_PROXY', no_proxy)] %}

proxy_environment_exists:
  file.managed:
    - name: /etc/environment
    - contents: ""
    - replace: False
    - user: root
    - group: root
    - mode: '0644'

{% for var, value in _pairs %}
{% if value %}
proxy_env_{{ var | lower }}:
  file.keyvalue:
    - name: /etc/environment
    - separator: '='
    - append_if_not_found: True
    - key_values:
        {{ var }}: '{{ value }}'
    - require:
      - file: proxy_environment_exists
{% else %}
proxy_env_{{ var | lower }}_absent:
  file.line:
    - name: /etc/environment
    - content: '{{ var }}='
    - match: '^{{ var }}=.*'
    - mode: delete
    - require:
      - file: proxy_environment_exists
{% endif %}
{% endfor %}

{% if _family == 'Suse' %}
proxy_sysconfig_exists:
  file.managed:
    - name: /etc/sysconfig/proxy
    - contents: ""
    - replace: False
    - user: root
    - group: root
    - mode: '0644'

{% if http_proxy or https_proxy %}
proxy_sysconfig_enabled:
  file.keyvalue:
    - name: /etc/sysconfig/proxy
    - separator: '='
    - append_if_not_found: True
    - key_values:
        PROXY_ENABLED: 'yes'
        HTTP_PROXY: '{{ http_proxy }}'
        HTTPS_PROXY: '{{ https_proxy }}'
        NO_PROXY: '{{ no_proxy }}'
    - require:
      - file: proxy_sysconfig_exists
{% else %}
proxy_sysconfig_disabled:
  file.keyvalue:
    - name: /etc/sysconfig/proxy
    - separator: '='
    - append_if_not_found: True
    - key_values:
        PROXY_ENABLED: 'no'
    - require:
      - file: proxy_sysconfig_exists
{% endif %}
{% elif _family == 'RedHat' %}
{% if http_proxy %}
proxy_dnf_config:
  file.keyvalue:
    - name: /etc/dnf/dnf.conf
    - separator: '='
    - append_if_not_found: True
    - key_values:
        proxy: '{{ http_proxy }}'
{% else %}
proxy_dnf_config_absent:
  file.replace:
    - name: /etc/dnf/dnf.conf
    - pattern: '^proxy=.*'
    - repl: ''
    - onlyif: test -f /etc/dnf/dnf.conf && grep -q '^proxy=' /etc/dnf/dnf.conf
{% endif %}
{% endif %}
