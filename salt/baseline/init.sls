{# Tumbleweed-only baseline: fail fast anywhere else instead of
   half-applying states written for Tumbleweed package names and paths. #}
{% if grains.get('os', '') != 'openSUSE Tumbleweed' %}
tumbleweed_only:
  test.fail_without_changes:
    - name: suse-baseline supports openSUSE Tumbleweed only (got {{ grains.get('os', 'unknown') }})
{% else %}
include:
  - baseline.banner
  - baseline.freeipa
  - baseline.netbird
  - baseline.profile
  - baseline.schedule
  - baseline.systemd-resolved
  - baseline.timesyncd
  - baseline.trivy
  - baseline.updates
  - baseline.usb
{% endif %}
