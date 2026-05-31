# Tumbleweed update policy (security-focused)

updates_zypper_config:
  file.managed:
    - name: /etc/zypp/zypp.conf
    - source: salt://baseline/updates/templates/zypp.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

# Ensure system is current (use with care on Tumbleweed - this does a full dup)
{% if salt['pillar.get']('baseline:updates:auto_dup', False) %}
tumbleweed_full_update:
  cmd.run:
    - name: /usr/bin/zypper --non-interactive dup --no-recommends
    - onlyif: /usr/bin/zypper --non-interactive list-updates | grep -q 'security'
    - timeout: 3600
{% endif %}

# Record last baseline update check
last_update_marker:
  file.managed:
    - name: /var/log/baseline-last-update
    - contents: |
        Last baseline update run: {{ salt['cmd.run']('date -Iseconds') }}
    - user: root
    - group: root
    - mode: '0644'
