{# Minion scheduler jobs for Overstate-managed fleets.
   Overstate's Schedules tab reads these via schedule.list, so keep the
   job names stable. Disabled jobs are removed (absent), not left behind:
   a nightly highstate that keeps running after being "disabled" would be
   a nasty surprise. #}
{% set sched = salt['pillar.get']('baseline:schedule', {}) %}
{% set enabled = sched.get('enabled', True) %}
{% set mine_cfg = sched.get('mine_update', {}) %}
{% set highstate_cfg = sched.get('highstate', {}) %}

{# The nightly highstate uses a cron expression, which the minion only
   evaluates with the croniter module installed (source package
   python-croniter, binary python3-croniter on SUSE). #}
schedule_croniter_package:
  pkg.installed:
    - name: python3-croniter

{% if enabled and mine_cfg.get('enabled', True) %}
baseline_mine_update:
  schedule.present:
    - name: mine-update-hourly
    - function: mine.update
    - hours: {{ mine_cfg.get('hours', 1) }}
    - splay: {{ mine_cfg.get('splay', 300) }}
    - run_on_start: {{ mine_cfg.get('run_on_start', True) }}
{% else %}
baseline_mine_update:
  schedule.absent:
    - name: mine-update-hourly
{% endif %}

{% if enabled and highstate_cfg.get('enabled', True) %}
baseline_highstate_nightly:
  schedule.present:
    - name: highstate-nightly
    - function: state.highstate
    - cron: "{{ highstate_cfg.get('cron', '17 2 * * *') }}"
    - splay: {{ highstate_cfg.get('splay', 900) }}
    - require:
      - pkg: schedule_croniter_package
{% else %}
baseline_highstate_nightly:
  schedule.absent:
    - name: highstate-nightly
{% endif %}
