monitoring:
  falco:
    enabled: true
    http_output_url: "https://falco-sidekick.sigaint.au"
    additional_rules:
      - { url: 'https://raw.githubusercontent.com/falcosecurity/rules/main/rules/falco-incubating_rules.yaml', dest: '/etc/falco/falco-incubating_rules.yaml' }
      - { url: 'https://raw.githubusercontent.com/falcosecurity/rules/main/rules/falco-sandbox_rules.yaml',    dest: '/etc/falco/falco-sandbox_rules.yaml' }
