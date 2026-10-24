{# Forensic / session hardening for login shells. FreeBSD: /etc/profile.d
   is sourced by base sh (14+); bash is NOT in the base system, so install
   it so the bash-specific history hardening below actually applies when
   users run bash. Default login shells are left untouched — root stays on
   csh unless an admin changes it (csh does not read /etc/profile). #}
{% set _family = grains.get('os_family', '') %}
{% set _group = 'wheel' if _family == 'FreeBSD' else 'root' %}
{% if _family == 'FreeBSD' %}
profile_bash_package:
  pkg.installed:
    - name: bash
{% endif %}
baseline_bash_profile:
  file.managed:
    - name: /etc/profile.d/99-baseline.sh
    - source: salt://baseline/profile/templates/99-baseline.sh
    - user: root
    - group: {{ _group }}
    - mode: '0644'
{% if _family == 'FreeBSD' %}
    - require:
      - pkg: profile_bash_package
{% endif %}
