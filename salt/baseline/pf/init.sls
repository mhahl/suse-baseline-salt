{# FreeBSD firewall baseline (baseline.pf).
   PF is the FreeBSD in-base firewall. Unlike firewalld (which owns its
   config via firewall-cmd), this module deliberately NEVER owns
   /etc/pf.conf: it manages a single anchor ruleset at
   /etc/pf.baseline.rules and appends one `anchor` line to pf.conf, so
   it composes with whatever PF management already exists on the host.
   Rules are only validated and loaded when PF is actually running
   (pfctl -s info); the module never enables PF on a host where it is
   off — set baseline:firewalld:enabled false or enable PF out-of-band.
   The allow-list + NetBird trusted rules mirror baseline.firewalld's
   pillar keys (baseline:firewalld:*), so the pillar contract stays
   unified across platforms.
   Disabling removes the rules file and the anchor, then reloads.
   Apply with: salt '*' state.apply baseline.pf #}
{% set enabled = salt['pillar.get']('baseline:firewalld:enabled', True) %}
{% set services = salt['pillar.get']('baseline:firewalld:services', ['ssh']) %}
{% set nb_enabled = salt['pillar.get']('baseline:netbird:enabled', True) %}
{% set nb_trusted = salt['pillar.get']('baseline:firewalld:netbird_trusted', True) %}
{% set nb_iface = salt['pillar.get']('baseline:firewalld:netbird_interface', 'wt0') %}

pf_conf_exists:
  file.managed:
    - name: /etc/pf.conf
    - contents: ""
    - replace: False
    - user: root
    - group: wheel
    - mode: '0644'

{% if enabled %}
pf_rules_file:
  file.managed:
    - name: /etc/pf.baseline.rules
    - source: salt://baseline/pf/templates/pf.rules.jinja
    - template: jinja
    - user: root
    - group: wheel
    - mode: '0640'
    - context:
        services: {{ services }}
        nb_enabled: {{ nb_enabled }}
        nb_trusted: {{ nb_trusted }}
        nb_iface: {{ nb_iface }}
    - require:
      - file: pf_conf_exists

pf_anchor_statement:
  file.blockreplace:
    - name: /etc/pf.conf
    - marker_start: "# BEGIN baseline managed anchor"
    - marker_end: "# END baseline"
    - content: 'anchor "baseline" load ruleset from "/etc/pf.baseline.rules"'
    - append_if_not_found: True
    - require:
      - file: pf_rules_file
      - file: pf_conf_exists

# Validate before loading; both only run when PF is actually up. A
# reload on a host where PF is off would be a no-op anyway, and writing
# the config files while off is harmless — they self-heal on the next
# run once PF is enabled out-of-band.
pf_validate:
  cmd.run:
    - name: pfctl -nf /etc/pf.conf
    - onchanges:
      - file: pf_rules_file
      - file: pf_anchor_statement
    - failhard: True
    - order: 1
    - onlyif: pfctl -s info >/dev/null 2>&1

pf_reload:
  cmd.run:
    - name: pfctl -f /etc/pf.conf
    - onchanges:
      - file: pf_rules_file
      - file: pf_anchor_statement
    - require:
      - cmd: pf_validate
    - onlyif: pfctl -s info >/dev/null 2>&1
{% else %}
pf_rules_file:
  file.absent:
    - name: /etc/pf.baseline.rules
    - require:
      - file: pf_conf_exists

# Removing the managed block: blockreplace with empty content deletes it.
pf_anchor_statement:
  file.blockreplace:
    - name: /etc/pf.conf
    - marker_start: "# BEGIN baseline managed anchor"
    - marker_end: "# END baseline"
    - content: ""
    - require:
      - file: pf_rules_file
      - file: pf_conf_exists

pf_reload:
  cmd.run:
    - name: pfctl -f /etc/pf.conf
    - onchanges:
      - file: pf_anchor_statement
    - onlyif: pfctl -s info >/dev/null 2>&1
{% endif %}
