# =====================================================================
# SECTION: baseline:schedule — minion scheduler jobs (Overstate-visible)
#
# WHY: Fleets drift without a heartbeat. Three jobs keep Overstate's
#   Schedules tab truthful: hourly mine.push (grains/addresses), nightly
#   highstate (splayed 02:17 so the fleet never stampedes the master),
#   and daily saltutil.sync_modules (closes the window where the master
#   serves new _modules/ but minions still run the old copy).
#   Disabling a job REMOVES it (schedule.absent) — never leaves a stale
#   job behind.
#
# CONSUMED BY: salt/baseline/schedule/init.sls via
#   pillar.get('baseline:schedule', {}). The highstate cron: expression
#   needs croniter importable by the minion (system RPM + pip fallback
#   in Salt's own Python for onedir/venv minions).
#
# EXAMPLE — office hours highstate, no hourly mine push:
#   baseline:
#     schedule:
#       mine_update: {enabled: false}
#       highstate: {cron: "17 3 * * 1-5", splay: 600}
# =====================================================================
baseline:
  schedule:
    # Minion scheduler jobs, visible in Overstate's Schedules tab.
    enabled: true
    mine_update:
      enabled: true
      hours: 1
      splay: 300
      run_on_start: true
    highstate:
      enabled: true
      # Nightly highstate, off the exact hour + splayed so the fleet
      # does not stampede the master at once.
      cron: "17 2 * * *"
      splay: 900
    sync_modules:
      enabled: true
      # Daily saltutil.sync_modules so custom execution modules reach
      # minions without waiting for the next highstate. Splayed like
      # the other daily jobs.
      splay: 600
