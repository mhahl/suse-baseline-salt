# pillar/overstate.sls — aggregator for the Overstate integration pillar.
#
# LAYOUT: one file per concern under pillar/overstate/*.sls, each with a
# banner explaining WHY it exists, which state consumes it, and a copy-
# pastable override EXAMPLE. This file only wires them together via
# include: so pillar/top.sls lists `- overstate` alongside `- baseline`
# (stable for Overstate's pillar browser + master pillar_roots).
#
# DECOUPLED FROM BASELINE: other customers apply overstate.* with zero
# baseline configuration. Canonical keys live under `overstate:`.
# Legacy `baseline:grype` pillar still merges as a fallback in
# salt/overstate/grype/map.jinja and salt/_modules/grype_scan.py during
# migration (overstate wins).
include:
  - overstate.01-grype
