{# Tumbleweed-only baseline: fail fast anywhere else instead of
   half-applying states written for Tumbleweed package names and paths.
   Detection keys off osfullname first on purpose: observed minions
   report os="SUSE" while osfullname correctly says "openSUSE
   Tumbleweed", so the abbreviated os grain alone cannot be trusted.
   The rolling-date fallback (VERSION_ID=YYYYMMDD, which Leap/SLES
   short numeric majors like "15.5"/"16.0" never match) covers
   reporters where even osfullname is off. #}
{% set _os = grains.get('os', '') %}
{% set _fullname = grains.get('osfullname', '') %}
{% set _family = grains.get('os_family', '') %}
{% set _release = (grains.get('osrelease', '') ~ '') %}
{% set _rolling = _release|length == 8 and _release >= '20000000' and _release <= '20991231' %}
{% set _is_tw = _fullname == 'openSUSE Tumbleweed' or _os == 'openSUSE Tumbleweed' or (_family == 'Suse' and _rolling) %}
{% if _is_tw %}
include:
  - baseline.banner
  - baseline.freeipa
  - baseline.minion
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
    - name: suse-baseline supports openSUSE Tumbleweed only (got os={{ _os or 'unknown' }} fullname={{ _fullname or 'unknown' }} release={{ _release or 'unknown' }})
{% endif %}
