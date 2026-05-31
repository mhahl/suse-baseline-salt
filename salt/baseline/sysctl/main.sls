# Kernel and network sysctl hardening (SUSE baseline)
# See: https://documentation.suse.com/sles/15-SP6/html/SLES-all/cha-sec-sysctl.html

{% set enabled = salt['pillar.get']('baseline:sysctl:enabled', True) %}

{% if enabled %}
sysctl_baseline_hardening:
  file.managed:
    - name: /etc/sysctl.d/99-baseline-hardening.conf
    - source: salt://baseline/sysctl/templates/99-baseline-hardening.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        pillar: {{ pillar.get('baseline', {}) | tojson }}

  cmd.run:
    - name: /sbin/sysctl --system
    - onchanges:
      - file: sysctl_baseline_hardening
    - require:
      - file: sysctl_baseline_hardening
{% endif %}
