# =====================================================================
# SECTION: baseline:ntp — clock source for systemd-timesyncd
#
# WHY: TLS, DNSSEC, and forensic timelines all depend on a correct
#   clock. timesyncd is the ONLY NTP client here (chronyd is removed in
#   salt/baseline/timesyncd/init.sls) so two daemons can never step the
#   clock together.
#
# CONSUMED BY: salt/baseline/timesyncd/init.sls via
#   pillar.get('baseline:ntp', {}) into templates/timesyncd.conf.jinja
#   (NTP=, optional FallbackNTP= — omitted, not emptied, when unset so
#   distro compiled-in defaults still apply).
#
# EXAMPLE — internal NTP + public fallback:
#   baseline:
#     ntp:
#       servers: ['ntp.example.com']
#       fallback: ['pool.ntp.org']
# =====================================================================
baseline:
  ntp:
    servers:
      - time1.google.com
      - time2.google.com
      - time3.google.com
      - time4.google.com
