# =====================================================================
# SECTION: baseline:systemd_resolved — DNS-over-TLS resolvers
#
# WHY: DNS is plaintext by default (ISP / LAN snooping, hijack). This
#   forces all lookups through systemd-resolved with DNSOverTLS +
#   DNSSEC, stub listener, and an empty FallbackDNS so resolution never
#   falls back to unconfigured resolvers.
#
# CONSUMED BY: salt/baseline/systemd-resolved/init.sls via
#   pillar.get('baseline:systemd_resolved', {}) into
#   templates/resolved.conf.jinja (DNS=, DNSOverTLS=).
#
# EXAMPLE — Cloudflare strict TLS:
#   baseline:
#     systemd_resolved:
#       dns: "1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com"
#       dns_over_tls: "yes"
# =====================================================================
baseline:
  systemd_resolved:
    # AdGuard resolvers over DNS-over-TLS (DNSOverTLS=opportunistic by
    # default, overridable via dns_over_tls: 'yes' or 'opportunistic').
    # The #suffix sets the DoT SNI/auth hostname — equivalent to kdig's
    # +tls-sni. Port is always 853: systemd-resolved does not support
    # custom DoT ports. Servers are tried in order; FallbackDNS stays
    # empty so resolution never falls back to unconfigured resolvers.
    dns: "51.161.136.107#dns.adguard.sigaint.au 139.99.149.92#dns.adguard.sigaint.au 139.99.210.89#dns.adguard.sigaint.au 139.99.210.170#dns.adguard.sigaint.au"
    dns_over_tls: "opportunistic"
