# Baseline hardening state
#
# This is the main entry point. It aggregates the different categories
# of baseline configuration for better modularity.
include:
  - baseline.system.init
  - baseline.hardening.init
  - baseline.network.init

  # Monitoring is kept separate (see salt/monitoring/)
  # - monitoring.init

