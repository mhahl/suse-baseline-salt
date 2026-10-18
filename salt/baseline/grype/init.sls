# baseline.grype/init.sls — DEPRECATED shim over overstate.grype.
# Grype moved to the overstate namespace (reusable without baseline).
# baseline/init.sls no longer includes it. Apply overstate.grype instead;
# this wrapper remains for one release so `state.apply baseline.grype`
# keeps working.
include:
  - overstate.grype
