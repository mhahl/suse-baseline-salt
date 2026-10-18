# =====================================================================
# SECTION: mine_functions (TOP LEVEL — not under baseline:)
#
# WHY: Salt ONLY reads mine_functions from the pillar ROOT — nesting it
#   under baseline: silently disables it. Kept deliberately small
#   (grains + addresses are what Overstate's Mine browser and targeting
#   need). Pushed hourly by the mine-update-hourly schedule in
#   05-schedule.sls (on top of Salt's built-in 60-minute mine_interval).
#   Grype keys are NOT here: grype_scan.publish uses mine.send (no
#   restart needed, but mine.update does NOT refresh them).
#
# CONSUMED BY: salt minion mine module directly (no state file).
#
# EXAMPLE — also publish custom grains:
#   mine_functions:
#     grains.items: []
#     network.ip_addrs: []
#     network.interfaces: []
# =====================================================================
mine_functions:
  grains.items: []
  network.ip_addrs: []
