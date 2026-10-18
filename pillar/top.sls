base:
  '*':
    - baseline
    - overstate
  # Encrypted per-fleet overlays (see pillar/secrets/prod.sls.example +
  # README.md "Secrets"). Uncomment when the ciphertext file exists —
  # later entries win in pillar merge, so secrets override the empty
  # placeholders in the section files. CI never targets these (defaults
  # keep both joins disabled), so no GPG key is needed in CI.
  # 'salt-prod-*':
  #   - secrets.prod
