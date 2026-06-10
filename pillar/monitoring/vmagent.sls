# Pillar data for VictoriaMetrics agent (vmagent) - Monitoring module
# See: salt/monitoring/vmagent/

monitoring:
  vmagent:
    enabled: true

    # Remote VictoriaMetrics / vminsert write endpoint
    remote_write_url: "https://vm.example.com/api/v1/write"

    # Scrape configuration (YAML as string)
    scrape_configs: |
      - job_name: 'node'
        static_configs:
          - targets: ['localhost:9100']

      # Add more jobs here as needed
      # - job_name: 'cadvisor'
      #   static_configs:
      #     - targets: ['localhost:8080']
