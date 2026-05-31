# Pillar data for Falco (Monitoring module)
# See: salt/monitoring/falco/

monitoring:
  falco:
    enabled: false

    # Where Falco should send events (Falco HTTP output or Falcosidekick)
    http_output_url: "https://falco.sigaint.au"

    # Optional: Additional Falco settings
    # json_output: true
    # priority: notice
