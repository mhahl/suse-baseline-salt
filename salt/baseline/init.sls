{# Supported platforms: openSUSE Tumbleweed and Fedora. Preserve the
   observed Tumbleweed grain variants; Fedora requires RedHat + os=Fedora. #}
{% set _os = grains.get('os', '') %}
{% set _fullname = grains.get('osfullname', '') %}
{% set _family = grains.get('os_family', '') %}
{% set _release = (grains.get('osrelease', '') ~ '') %}
{% set _rolling = _release|length == 8 and _release >= '20000000' and _release <= '20991231' %}
{% set _is_tw = _family == 'Suse' and (_fullname == 'openSUSE Tumbleweed' or _os == 'openSUSE Tumbleweed' or _rolling) %}
{% set _is_fedora = _family == 'RedHat' and _os == 'Fedora' %}
{% if _is_tw or _is_fedora %}
include:
  - baseline.banner
  - baseline.minion
  - baseline.profile
  - baseline.systemd-resolved
  - baseline.timesyncd
  - baseline.grype
  - baseline.usb
{% if _is_tw %}
  - baseline.suse
{% else %}
  - baseline.redhat
{% endif %}
{% else %}
unsupported_platform:
  test.fail_without_changes:
    - name: supports openSUSE Tumbleweed or Fedora (got os={{ _os or 'unknown' }} os_family={{ _family or 'unknown' }} fullname={{ _fullname or 'unknown' }} release={{ _release or 'unknown' }})
{% endif %}
