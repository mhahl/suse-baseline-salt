monitoring:
  vmagent:
    enabled: true
    remote_write_url: "https://vm.example.com/api/v1/write"
    scrape_configs: |
      - job_name: 'node'
        static_configs:
          - targets: ['localhost:9100']
