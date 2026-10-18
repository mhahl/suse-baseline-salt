# Firewall baseline (baseline.firewalld).
#
# TWO hardening actions:
#
# 1. Harden the default firewalld zone to an explicit allow-list
#    Pillar defines which services to keep (baseline:firewalld:services).
#    The state ensures allowed services are present and removes known
#    non-essential services (mdns, dhcpv6-client, cockpit, ...) that
#    are NOT in the allow-list.  This composes with pillar targeting:
#    a webserver overlay sets services: [ssh, http, https] and only
#    those remain in the default zone.
#
# 2. Assign NetBird WireGuard interface (wt0 by default) to the trusted
#    zone so management traffic over the mesh VPN is unrestricted.
#    Only runs when the interface actually exists (safe: post-join).
#
# All permanent changes are batched before a single firewall-cmd --reload
# that only fires when something actually changed.

{% set enabled = salt['pillar.get']('baseline:firewalld:enabled', True) %}

# Allow-list: services the default zone should permit.  Per-role overlays
# (e.g. webserver → [ssh, http, https]) extend this list.  Each overlay
# must declare the COMPLETE set — Salt replaces lists on merge.
{% set services = salt['pillar.get']('baseline:firewalld:services', ['ssh']) %}

# Known non-essential services shipped by default that are removed unless
# explicitly included in the allow-list above.
{% set _cruft = [
  'mdns',
  'dhcpv6-client',
  'cockpit',
  'samba-client',
  'ipp-client',
] %}

{% set nb_enabled = salt['pillar.get']('baseline:netbird:enabled', True) %}
{% set nb_trusted = salt['pillar.get']('baseline:firewalld:netbird_trusted', True) %}
{% set nb_iface = salt['pillar.get']('baseline:firewalld:netbird_interface', 'wt0') %}

{% if enabled %}
firewalld_package:
  pkg.installed:
    - name: firewalld

firewalld_service:
  service.running:
    - name: firewalld
    - enable: True
    - require:
      - pkg: firewalld_package

# ── Ensure each allowed service is present ──────────────────────────
{% for svc in services %}
firewalld_add_{{ svc | replace('-', '_') }}:
  cmd.run:
    - name: firewall-cmd --permanent --add-service={{ svc }}
    - unless: firewall-cmd --query-service={{ svc }}
    - require:
      - service: firewalld_service
    - require_in:
      - cmd: firewalld_reload

{% endfor %}
# ── Remove known cruft not in the allow-list ───────────────────────
{% for svc in _cruft %}
{% if svc not in services %}
firewalld_remove_{{ svc | replace('-', '_') }}:
  cmd.run:
    - name: firewall-cmd --permanent --remove-service={{ svc }}
    - onlyif: firewall-cmd --query-service={{ svc }}
    - require:
      - service: firewalld_service
    - require_in:
      - cmd: firewalld_reload

{% endif %}
{% endfor %}
# ── NetBird trusted zone ───────────────────────────────────────────
{% if nb_enabled and nb_trusted %}
firewalld_netbird_trusted:
  cmd.run:
    - name: firewall-cmd --permanent --zone=trusted --add-interface={{ nb_iface }}
    - onlyif: ip link show {{ nb_iface }} 2>/dev/null && ! firewall-cmd --zone=trusted --query-interface={{ nb_iface }} 2>/dev/null
    - require:
      - service: firewalld_service
    - require_in:
      - cmd: firewalld_reload

{% endif %}
# ── Reload to apply permanent changes ──────────────────────────────
firewalld_reload:
  cmd.run:
    - name: firewall-cmd --reload
    - onchanges:
{% for svc in services %}
      - cmd: firewalld_add_{{ svc | replace('-', '_') }}
{% endfor %}
{% for svc in _cruft %}
{% if svc not in services %}
      - cmd: firewalld_remove_{{ svc | replace('-', '_') }}
{% endif %}
{% endfor %}
{% if nb_enabled and nb_trusted %}
      - cmd: firewalld_netbird_trusted
{% endif %}
    - require:
      - service: firewalld_service

{% else %}
# Disabled: remove the NetBird trusted-zone binding if it was previously
# set, then reload.  Default zone services are left as-is — consistent
# with the project's convention that disabling removes what it manages
# but does not revert base-system state.

{% if nb_enabled and nb_trusted %}
firewalld_netbird_trusted_remove:
  cmd.run:
    - name: firewall-cmd --permanent --zone=trusted --remove-interface={{ nb_iface }}
    - onlyif: firewall-cmd --zone=trusted --query-interface={{ nb_iface }} 2>/dev/null
    - require_in:
      - cmd: firewalld_reload

{% endif %}
firewalld_reload:
  cmd.run:
    - name: firewall-cmd --reload
    - onchanges:
{% if nb_enabled and nb_trusted %}
      - cmd: firewalld_netbird_trusted_remove
{% endif %}
    - unless: test -f /etc/firewalld/firewalld.conf
{% endif %}