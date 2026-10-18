# =====================================================================
# SECTION: baseline:firewalld — Firewall baseline
#
# WHY: The default firewalld zone on both Tumbleweed and Fedora ships
#   with services (mdns, dhcpv6-client, cockpit) that are not needed on
#   managed servers.  This module enforces an allow-list: declare which
#   services the default zone should permit, and everything else gets
#   stripped.  Default: SSH only.
#
#   Group overrides extend the list via pillar targeting — a webserver
#   overlay sets services: [ssh, http, https] and the state handles the
#   diff (adds http/https, continues to remove mDNS/cockpit).  Each
#   overlay declares the COMPLETE set (Salt replaces lists on merge).
#
#   Additionally, the NetBird WireGuard VPN interface (default: wt0) is
#   assigned to the `trusted` zone so mesh traffic (management SSH,
#   inter-host discovery) is unrestricted while the physical interface
#   stays locked down.
#
# CONSUMED BY: salt/baseline/firewalld/init.sls via
#   pillar.get('baseline:firewalld:services', ['ssh']).  Each service
#   is ensured present; known non-essential services not in the list
#   are removed.
#
# EXAMPLE — allow http/https on web servers:
#   # pillar/roles/webserver.sls (targeted via pillar/top.sls):
#   baseline:
#     firewalld:
#       services:
#         - ssh
#         - http
#         - https
#
# EXAMPLE — keep dhcpv6-client on stateless hosts:
#   baseline:
#     firewalld:
#       services:
#         - ssh
#         - dhcpv6-client
# =====================================================================
baseline:
  firewalld:
    enabled: true
    # Services the default zone should permit.  The state ensures each
    # is present and removes known non-essential services not in this
    # list.  Per-role overlays extend this — each declares the COMPLETE
    # set (Salt replaces lists on pillar merge).
    services:
      - ssh
    # NetBird interface → trusted zone (only when the interface exists)
    netbird_trusted: true
    netbird_interface: wt0