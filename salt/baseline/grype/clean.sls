# baseline.grype/clean.sls — DEPRECATED shim. See overstate.grype.clean.
# Apply with: salt '<minion>' state.apply overstate.grype.clean
include:
  - overstate.grype.clean
