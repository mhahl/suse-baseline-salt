{# Tumbleweed-only baseline: fail fast anywhere else instead of
   half-applying states written for Tumbleweed package names and paths.
   Detection is multi-signal on purpose: some Salt versions/images
   report Tumbleweed hosts as os="SUSE" instead of the canonical
   "openSUSE Tumbleweed". What every Tumbleweed (and rolling-snapshot
   sibling) has is a date-shaped osrelease (VERSION_ID=YYYYMMDD),
   while Leap/SLES report short numeric majors ("15.5", "16.0") —
   so family Suse + rolling date admits, everything else fails. #}
{% set _os = grains.get('os', '') %}
{% set _family = grains.get('os_family', '') %}
{% set _release = (grains.get('osrelease', '') ~ '') %}
{% set _rolling = _release|length == 8 and _release >= '20000000' and _release <= '20991231' %}
{% set _is_tw = _os == 'openSUSE Tumbleweed' or (_family == 'Suse' and _rolling) %}
{% if _is_tw %}
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
{% else %}
tumbleweed_only:
  test.fail_without_changes:
    - name: suse-baseline supports openSUSE Tumbleweed only (got os={{ _os or 'unknown' }} family={{ _family or 'unknown' }} release={{ _release or 'unknown' }} codename={{ grains.get('oscodename', 'unknown') }})
{% endif %}
