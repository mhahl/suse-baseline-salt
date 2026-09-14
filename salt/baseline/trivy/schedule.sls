{% from "baseline/trivy/map.jinja" import trivy with context %}
# baseline.trivy/schedule.sls — daily trivy_scan.publish, persisted to the minion
# config so it survives restarts. publish() scans and pushes the summary
# to the mine via mine.send (no mine_functions config, no restart needed).

trivy-cve-scan:
  schedule.present:
    - function: trivy_scan.publish
    - days: 1
    - splay: {{ trivy.schedule_splay }}
    - persist: True
    - return_job: False
