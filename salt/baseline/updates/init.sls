updates_zypper_config:
  file.managed:
    - name: /etc/zypp/zypp.conf
    - source: salt://baseline/updates/templates/zypp.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

{% if salt['pillar.get']('baseline:updates:auto_dup', False) %}
tumbleweed_full_update:
  cmd.run:
    - name: /usr/bin/zypper --non-interactive dup --no-recommends
    - onlyif: /usr/bin/zypper --non-interactive list-updates | grep -q 'security'
    - timeout: 3600
{% endif %}

last_update_marker:
  cmd.run:
    - name: date -Iseconds > /var/log/baseline-last-update
