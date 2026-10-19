base:
  '*':
    - baseline
    - overstate
  # overstate_cis tunables (pillar/overstate_cis.sls) — gated to the
  # same nodegroup as the state top.sls entry, so non-members carry no
  # unused pillar.
  'site-lhm-development':
    - match: nodegroup
    - overstate_cis
  # Encrypted per-fleet overlays (see pillar/secrets/prod.sls.example +
  # README.md "Secrets"). Uncomment when the ciphertext file exists —
  # later entries win in pillar merge, so secrets override the empty
  # placeholders in the section files. CI never targets these (defaults
  # keep both joins disabled), so no GPG key is needed in CI.
  # 'salt-prod-*':
  #   - secrets.prod
