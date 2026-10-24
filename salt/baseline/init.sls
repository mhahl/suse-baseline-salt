{# Supported platforms: openSUSE Tumbleweed, Fedora, and FreeBSD 15+.
   Preserve the observed Tumbleweed grain variants; Fedora requires
   RedHat + os=Fedora; FreeBSD requires os_family=FreeBSD with a 15.x or
   newer release (13.x is EOL and 15.0 is past EOL — both fail fast). #}
{% set _os = grains.get('os', '') %}
{% set _fullname = grains.get('osfullname', '') %}
{% set _family = grains.get('os_family', '') %}
{% set _release = (grains.get('osrelease', '') ~ '') %}
{% set _rolling = _release|length == 8 and _release >= '20000000' and _release <= '20991231' %}
{% set _is_tw = _family == 'Suse' and (_fullname == 'openSUSE Tumbleweed' or _os == 'openSUSE Tumbleweed' or _rolling) %}
{% set _is_fedora = _family == 'RedHat' and _os == 'Fedora' %}
{# FreeBSD osrelease looks like "15.1-RELEASE": the major is the integer
   before the first dot. #}
{% set _fb_major = (_release.split('.')[0]|int) if _family == 'FreeBSD' else 0 %}
{% set _is_freebsd = _family == 'FreeBSD' and _fb_major >= 15 %}
{% if _is_tw or _is_fedora or _is_freebsd %}
include:
  - baseline.banner
  - baseline.minion
  - baseline.profile
  - baseline.proxy
  - baseline.ssh
{% if _is_tw or _is_fedora %}
  - baseline.firewalld
  - baseline.systemd-resolved
  - baseline.timesyncd
  - baseline.usb
{% else %}
  - baseline.pf
  - baseline.unbound
  - baseline.ntpd
{% endif %}
{% if _is_tw %}
  - baseline.suse
{% elif _is_fedora %}
  - baseline.redhat
{% else %}
  - baseline.freebsd
{% endif %}
{% else %}
unsupported_platform:
  test.fail_without_changes:
    - name: supports openSUSE Tumbleweed, Fedora, or FreeBSD 15+ (got os={{ _os or 'unknown' }} os_family={{ _family or 'unknown' }} fullname={{ _fullname or 'unknown' }} release={{ _release or 'unknown' }})
{% endif %}
