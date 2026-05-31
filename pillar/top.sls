base:
  '*':
    # Baseline - now modular by category
    - baseline.system
    - baseline.hardening
    - baseline.network

    # Monitoring & Observability (modular)
    - monitoring.falco
    - monitoring.node_exporter
    - monitoring.vmagent
