{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/schedule.sls — daily trivy_scan.publish, persisted to the minion
# config so it survives restarts. publish() scans and pushes the summary
# to the mine via mine.send (no mine_functions config, no restart needed).

# NOTE: the state ID is snake_case but the scheduled job keeps its
# established name explicitly — Overstate's Schedules tab and goss read
# the job name, so renaming it would break both.
trivy_cve_scan:
  schedule.present:
    - name: trivy-cve-scan
    - function: trivy_scan.publish
    - days: 1
    - splay: {{ trivy.schedule_splay }}
    - persist: True
    - return_job: False
