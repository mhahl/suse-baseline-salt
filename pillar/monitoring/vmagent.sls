monitoring:
  vmagent:
    enabled: true
    # Remote write target for vmagent (where scraped metrics are sent)
    target_url: "https://vm.example.com/api/v1/write"
