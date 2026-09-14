"""Render tests for baseline.timesyncd (systemd-timesyncd NTP).

Timesyncd replaces the old chrony formula: one fewer daemon, no extra
package, and the superseded chrony package/config are removed so the
two clients never fight for the clock. Server list reuses the
baseline:ntp pillar (servers, optional fallback).

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render(path, grains=None, pillar=None, **context):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
        extensions=["jinja2.ext.do"],
    )
    pillar = pillar or {}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return env.get_template(path).render(
        grains=grains or {}, salt=salt, **context
    )


def test_dropin_renders_servers_and_optional_fallback():
    ntp = {"servers": ["time1.example.com", "time2.example.com"]}
    out = render("baseline/timesyncd/templates/timesyncd.conf.jinja", ntp=ntp)
    assert "NTP=time1.example.com time2.example.com" in out
    assert "FallbackNTP" not in out  # omitted, not emptied: distro defaults apply

    out = render(
        "baseline/timesyncd/templates/timesyncd.conf.jinja",
        ntp={**ntp, "fallback": ["pool.ntp.org"]},
    )
    assert "FallbackNTP=pool.ntp.org" in out


def test_dropin_defaults_to_pool():
    out = render("baseline/timesyncd/templates/timesyncd.conf.jinja", ntp={})
    assert "NTP=pool.ntp.org" in out


def test_init_manages_service_and_removes_chrony():
    grains = {"os_family": "Suse"}
    out = render("baseline/timesyncd/init.sls", grains)
    assert "name: systemd-timesyncd" in out
    assert "99-baseline.conf" in out
    assert "service.dead" in out  # chronyd stopped first
    assert "pkg.removed" in out  # superseded chrony package gone
    assert "name: /etc/chrony.conf" in out
