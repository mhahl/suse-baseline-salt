# overstate/init.sls — Overstate integration states (reusable without baseline).
#
# This namespace holds fleet-visibility tooling consumed by the Overstate
# web UI (Schedules / Mine / Vulnerabilities tabs). It is deliberately
# decoupled from `baseline/` (your custom OS hardening): other customers
# can apply `overstate.grype` without any baseline configuration.
#
# Apply with: salt '*' state.apply overstate
# Or standalone: salt '*' state.apply overstate.grype
include:
  - overstate.grype
