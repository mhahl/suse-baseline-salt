{% from "baseline/grype/map.jinja" import grype with context %}
# baseline.grype/schedule.sls — daily grype_scan.publish, persisted to the minion
# config so it survives restarts. publish() scans and pushes two mine keys
# via mine.send (no mine_functions config, no restart needed): the slim
# summary and the full detail report.
# Overstate: the job name grype-cve-scan and both mine keys
# grype.scan_summary + grype.scan_detail are stable contracts for the
# Schedules/Mine/Vulnerabilities tabs.
# mine.update does NOT refresh these keys — they live only as long as this
# daily job refreshes them (default Salt mine_interval is 60m, so a missed
# run leaves a stale/missing entry until the next success).

# NOTE: the state ID is snake_case but the scheduled job keeps its
# established name explicitly — Overstate's Schedules tab and goss read
# the job name, so renaming it would break both.
# splay is clamped 0..86400 (default 600) so a bad pillar value cannot
# stampede the master or break schedule.present.
{% set _splay = grype.schedule_splay|int(600) %}
{% if _splay < 0 or _splay > 86400 %}
{% set _splay = 600 %}
{% endif %}
grype_cve_scan:
  schedule.present:
    - name: grype-cve-scan
    - function: grype_scan.publish
    - days: 1
    - splay: {{ _splay }}
    - persist: True
    - return_job: False
    - run_on_start: False
