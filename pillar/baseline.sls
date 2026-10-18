# pillar/baseline.sls — aggregator for the sectioned baseline pillar.
#
# LAYOUT: one file per concern under pillar/baseline/*.sls, each with a
# banner explaining WHY it exists, which state consumes it, and a copy-
# pastable override EXAMPLE. This file only wires them together via
# include: so pillar/top.sls stays `- baseline` + `- overstate` entries
# (stable for Overstate's pillar browser + master pillar_roots).
#
# DECOUPLED: grype lives under pillar/overstate/ (overstate:grype) —
# reusable without any baseline configuration. Legacy baseline:grype
# pillar still merges as a fallback in overstate map.jinja + module.
#
# CONVENTIONS (enforced by tests/test_pillar_layout.py):
# - All baseline knobs nest under `baseline:`. The ONLY top-level
#   exception is `mine_functions` (10-mine.sls) — Salt reads it
#   exclusively from the pillar root.
# - Join secrets (freeipa join.password, netbird join.setup_key) live in
#   ENCRYPTED pillar overlays (GPG/sops/Vault), never plaintext here.
#   These section files ship empty-string placeholders + fail-closed
#   states when enabled without secrets.
# - Salt deep-merges each `baseline:<section>` fragment across includes
#   (smart merging), so overrides in extra top.sls entries (e.g. per-
#   host or per-role files) win over these defaults.
include:
  - baseline.01-systemd-resolved
  - baseline.02-ntp
  - baseline.03-updates
  - baseline.04-usb
  - baseline.05-schedule
  - baseline.06-freeipa
  - baseline.07-netbird
  - baseline.08-minion
  - baseline.10-mine
  - baseline.11-proxy
