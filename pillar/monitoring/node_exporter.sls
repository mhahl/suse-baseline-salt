# Pillar data for Prometheus node_exporter (Monitoring module)
# See: salt/monitoring/node_exporter/

monitoring:
  node_exporter:
    enabled: false

    # Address node_exporter will listen on
    listen_address: ":9100"

    # Optional: Extra command line arguments
    # extra_args: "--collector.textfile.directory=/var/lib/node_exporter/textfile"
