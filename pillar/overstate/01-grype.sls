# =====================================================================
# SECTION: overstate:grype — daily CVE scanning to the Salt Mine
#
# WHY: Fleet visibility for the Overstate web UI, decoupled from OS
#   hardening in baseline/. No distro package ships grype, so the state
#   fetches the pinned GitHub release tarball (version pin + per-arch
#   sha256 is the supply chain control). A daily grype-cve-scan
#   publishes a slim summary (grype.scan_summary) for fleet-wide readers
#   plus full findings (grype.scan_detail) for per-minion readers — the
#   raw multi-megabyte JSON stays on the minion at report_path (0640).
#   Other customers can apply overstate.grype with zero baseline config.
#
# CONSUMED BY: salt/overstate/grype/map.jinja via
#   pillar.get('overstate:grype', {}) with legacy fallback to
#   pillar.get('baseline:grype', {}) (merged first, overstate wins),
#   install.sls / scan.sls / schedule.sls, and salt/_modules/grype_scan.py
#   (top_n clamped 0..100, schedule_splay clamped 0..86400, nice_level
#   clamped 0..19 in the module — default 19, lowest CPU priority).
#   Overstate: job name grype-cve-scan + both mine keys are stable —
#   do not rename.
#
# EXAMPLE — weekly offline scan (manage DB externally):
#   overstate:
#     grype:
#       skip_db_update: true
#       severities: 'MEDIUM,HIGH,CRITICAL'
#       top_n: 50
#
# MIGRATION — move legacy keys verbatim:
#   baseline: {grype: {...}}  ->  overstate: {grype: {...}}
#
# NOTE — bumping version: refresh BOTH hashes from the release
#   checksums.txt:
#   https://github.com/anchore/grype/releases/download/<version>/grype_<stripped>_checksums.txt
# =====================================================================
overstate:
  grype:
    version: 'v0.120.1'   # GitHub release tag, e.g. v0.120.1
    hashes:
      amd64: 'sha256=0a9ee97ef5ae2ee953b0a80098105052e846cdbe319a57d808b519c33cd1343d'
      arm64: 'sha256=29f47391dc283aa79fcc38e65224cd61f64dec0ecfd0db7074128ebf8ff23514'
    severities: 'HIGH,CRITICAL'
    top_n: 20             # CVEs kept in the mine summary 'top' list (0..100)
    skip_db_update: False # True = offline scans only, manage DB separately
    cache_dir: '/var/cache/grype'
    report_path: '/var/cache/grype/report.json'
    run_initial_scan: True  # one scan on first apply (skipped if a report exists)
    schedule_splay: 600     # seconds of random delay so the fleet scans evenly (0..86400)
    nice_level: 19          # scan CPU priority 0..19 (19 = lowest, never starves workloads)
