# Kernel and network sysctl hardening (SUSE baseline)
# See: https://documentation.suse.com/sles/15-SP6/html/SLES-all/cha-sec-sysctl.html

{% set enabled = salt['pillar.get']('baseline:sysctl:enabled', True) %}

{% if enabled %}
{% from 'baseline/map.jinja' import running_in_container with context %}

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

{% if not running_in_container %}
  cmd.run:
    - name: /sbin/sysctl --system
    - onchanges:
      - file: sysctl_baseline_hardening
    - require:
      - file: sysctl_baseline_hardening
{% else %}
sysctl_skipped_in_container:
  test.show_notification:
    - text: "Skipping sysctl --system (running in container - most kernel params are restricted or read-only)"
{% endif %}
{% endif %}
