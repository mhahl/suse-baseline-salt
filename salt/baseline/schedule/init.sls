{# Minion scheduler jobs for Overstate-managed fleets.
   Overstate's Schedules tab reads these via schedule.list, so keep the
   job names stable. Disabled jobs are removed (absent), not left behind:
   a nightly highstate that keeps running after being "disabled" would be
   a nasty surprise. #}
{% set sched = salt['pillar.get']('baseline:schedule', {}) %}
{% set enabled = sched.get('enabled', True) %}
{% set mine_cfg = sched.get('mine_update', {}) %}
{% set highstate_cfg = sched.get('highstate', {}) %}
{% set sync_cfg = sched.get('sync_modules', {}) %}

{# python3-croniter is the virtual name: python313-croniter Provides it
   on Tumbleweed/Leap 16; Leap 15.x ships python3-croniter itself. A
   hard-coded python313-croniter fails pkg.installed on Leap 15.
   The system package only covers minions running on the system Python.
   Onedir/venv/container minions ship an isolated interpreter that never
   sees system site-packages (upstream: "Missing python-croniter" despite
   the RPM being installed), so install croniter into Salt's own Python
   as well via pip. Salt reads HAS_CRONITER once at minion start: after
   the first apply that installs either provider, restart salt-minion
   once, or the scheduler keeps logging "Missing python-croniter.
   Ignoring job highstate-nightly" until then. #}
schedule_croniter_package:
  pkg.installed:
    - name: python3-croniter

schedule_croniter_pip:
  pip.installed:
    - name: croniter

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
      - pip: schedule_croniter_pip
{% else %}
baseline_highstate_nightly:
  schedule.absent:
    - name: highstate-nightly
{% endif %}

{# Custom execution modules (trivy_scan and friends) only reach minions
   via saltutil.sync_modules. The nightly highstate syncs as a side
   effect, but a dedicated daily job closes the window where the master
   already serves new module code while minions still run the old copy. #}
{% if enabled and sync_cfg.get('enabled', True) %}
baseline_sync_modules:
  schedule.present:
    - name: sync-modules-daily
    - function: saltutil.sync_modules
    - days: 1
    - splay: {{ sync_cfg.get('splay', 600) }}
{% else %}
baseline_sync_modules:
  schedule.absent:
    - name: sync-modules-daily
{% endif %}
