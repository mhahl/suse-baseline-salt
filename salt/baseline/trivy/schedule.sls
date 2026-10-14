{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/schedule.sls — daily trivy_scan.publish, persisted to the minion
# config so it survives restarts. publish() scans and pushes the summary
# to the mine via mine.send (no mine_functions config, no restart needed).
# Overstate: the job name trivy-cve-scan and the mine key
# trivy.scan_summary are stable contracts for the Schedules/Mine tabs.
# mine.update does NOT refresh this key — it lives only as long as this
# daily job refreshes it (default Salt mine_interval is 60m, so a missed
# run leaves a stale/missing entry until the next success).

# NOTE: the state ID is snake_case but the scheduled job keeps its
# established name explicitly — Overstate's Schedules tab and goss read
# the job name, so renaming it would break both.
# splay is clamped 0..86400 (default 600) so a bad pillar value cannot
# stampede the master or break schedule.present.
{% set _splay = trivy.schedule_splay|int(600) %}
{% if _splay < 0 or _splay > 86400 %}
{% set _splay = 600 %}
{% endif %}
trivy_cve_scan:
  schedule.present:
    - name: trivy-cve-scan
    - function: trivy_scan.publish
    - days: 1
    - splay: {{ _splay }}
    - persist: True
    - return_job: False
    - run_on_start: False
