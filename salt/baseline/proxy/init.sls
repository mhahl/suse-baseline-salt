{# Egress proxy (baseline.proxy): system-wide env + native tool config.
   Empty pillar values = direct connection (delete stale lines, never
   leave a proxy behind when unset). Non-empty values are written
   additively — existing unrelated lines in each file are preserved.
   /etc/sysconfig/proxy is Suse-only (zypper reads PROXY_* natively);
   /etc/dnf/dnf.conf proxy= is RedHat-only; FreeBSD's pkg fetches honor
   the proxy via PKG_ENV in /usr/local/etc/pkg.conf. Recurring Salt-run
   commands (updates, grype scan) additionally get per-command env: so
   they work immediately; the minion daemon itself needs one restart
   after a day-0 proxy change for archive.extracted/pkgrepo downloads.

   baseline:proxy:enabled (default True) is the master switch. Set it
   to False to stop managing proxy files entirely: /etc/environment,
   /etc/sysconfig/proxy and /etc/dnf/dnf.conf are left untouched,
   stale proxy lines included. Note that baseline.updates and the grype
   scan still add per-command env: from whatever proxy values are set
   in pillar — that is independent of this module. #}
{% set proxy = salt['pillar.get']('baseline:proxy', {}) %}
{% set enabled = proxy.get('enabled', True) %}
{% set http_proxy = proxy.get('http_proxy', '') %}
{% set https_proxy = proxy.get('https_proxy', '') %}
{% set no_proxy = proxy.get('no_proxy', 'localhost,127.0.0.1,::1') %}
{% set _family = grains.get('os_family', '') %}
{% set _pairs = [('http_proxy', http_proxy), ('https_proxy', https_proxy), ('no_proxy', no_proxy),
                 ('HTTP_PROXY', http_proxy), ('HTTPS_PROXY', https_proxy), ('NO_PROXY', no_proxy)] %}

{% if enabled %}
{% if _family != 'FreeBSD' %}
{# /etc/environment is a Linux (PAM/systemd) concept — FreeBSD does not
   read it; package fetches there get the proxy via pkg.conf below. #}
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
proxy_env_{{ var }}:
  file.keyvalue:
    - name: /etc/environment
    - separator: '='
    - append_if_not_found: True
    - key_values:
        {{ var }}: '{{ value }}'
    - require:
      - file: proxy_environment_exists
{% else %}
proxy_env_{{ var }}_absent:
  file.line:
    - name: /etc/environment
    - content: '{{ var }}='
    - match: '^{{ var }}=.*'
    - mode: delete
    - require:
      - file: proxy_environment_exists
{% endif %}
{% endfor %}
{% endif %}

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
{% elif _family == 'FreeBSD' %}
{# FreeBSD package fetches honor the proxy via pkg.conf PKG_ENV (UCL
   block). Written inside a managed block so stale proxy lines are
   never left behind; the block is removed when unset. #}
{% if http_proxy or https_proxy %}
proxy_pkgconf_exists:
  file.managed:
    - name: /usr/local/etc/pkg.conf
    - contents: ""
    - replace: False
    - user: root
    - group: wheel
    - mode: '0644'

proxy_pkg_env:
  file.blockreplace:
    - name: /usr/local/etc/pkg.conf
    - marker_start: "# BEGIN baseline managed pkg proxy"
    - marker_end: "# END baseline"
    - content: |
        PKG_ENV: {
{% if http_proxy %}
          http_proxy: "{{ http_proxy }}",
{% endif %}
{% if https_proxy %}
          https_proxy: "{{ https_proxy }}",
{% endif %}
{% if no_proxy %}
          no_proxy: "{{ no_proxy }}",
{% endif %}
        }
    - append_if_not_found: True
    - require:
      - file: proxy_pkgconf_exists
{% else %}
proxy_pkg_env_absent:
  file.blockreplace:
    - name: /usr/local/etc/pkg.conf
    - marker_start: "# BEGIN baseline managed pkg proxy"
    - marker_end: "# END baseline"
    - content: ""
    - onlyif: test -f /usr/local/etc/pkg.conf
{% endif %}
{% endif %}
{% endif %}
