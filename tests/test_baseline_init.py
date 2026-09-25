"""Render tests for the Tumbleweed-only baseline guard.

``baseline/init.sls`` includes the modules on Tumbleweed and fails fast
anywhere else instead of half-applying Tumbleweed package names and
paths. Detection is multi-signal: some Salt versions/images report
Tumbleweed hosts as ``os=SUSE`` instead of ``openSUSE Tumbleweed``, so
family Suse plus a date-shaped osrelease (VERSION_ID=YYYYMMDD) also
admits, while Leap/SLES short numeric majors stay rejected.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905, "osrelease": "20250905"}
# Tumbleweed as some minions report it: bare "SUSE" with a rolling date.
TW_SUSE = {"os": "SUSE", "os_family": "Suse",
           "osmajorrelease": 20250905, "osrelease": "20250905"}
LEAP15 = {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 15,
          "osrelease": "15.6"}
LEAP16 = {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 16,
          "osrelease": "16.0"}
# SLES as Salt reports it: os-release ID=sles maps to bare os="SUSE"
# (salt/grains/core.py _OS_NAME_MAP), with osfullname "SLES".
# Rejected like everything non-TW.
SLES = {"os": "SUSE", "os_family": "Suse", "osfullname": "SLES",
        "osmajorrelease": 15, "osrelease": "15.5"}
# The reported fleet case: os="SUSE" but osfullname correctly says
# Tumbleweed. Admitted via osfullname.
TW_SUSE_FULLNAME = {"os": "SUSE", "os_family": "Suse",
                    "osfullname": "openSUSE Tumbleweed",
                    "osmajorrelease": 20260922, "osrelease": "20260922"}

MODULES = ("banner", "freeipa", "netbird", "profile", "schedule",
           "systemd-resolved", "timesyncd", "trivy", "updates", "usb")


def render_init(grains):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/init.sls")
    salt = {"pillar.get": lambda key, default=None: default}
    return tpl.render(grains=grains, salt=salt)


def test_tumbleweed_includes_modules():
    rendered = render_init(dict(TW))
    assert "test.fail_without_changes" not in rendered
    for module in MODULES:
        assert f"- baseline.{module}" in rendered


def test_suse_with_rolling_date_is_admitted():
    rendered = render_init(dict(TW_SUSE))
    assert "test.fail_without_changes" not in rendered
    for module in MODULES:
        assert f"- baseline.{module}" in rendered


def test_suse_grain_with_tumbleweed_fullname_is_admitted():
    rendered = render_init(dict(TW_SUSE_FULLNAME))
    assert "test.fail_without_changes" not in rendered
    for module in MODULES:
        assert f"- baseline.{module}" in rendered


def test_other_os_fails_fast_with_grains_in_message():
    for grains in (LEAP15, LEAP16, SLES,
                   {"os": "Debian", "os_family": "Debian",
                    "osrelease": "12"},
                   {}):
        rendered = render_init(dict(grains))
        assert "test.fail_without_changes" in rendered
        assert "include:" not in rendered
        assert "got os=" in rendered
