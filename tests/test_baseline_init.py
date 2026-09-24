"""Render tests for the Tumbleweed-only baseline guard.

``baseline/init.sls`` includes the modules on openSUSE Tumbleweed and
fails fast anywhere else instead of half-applying Tumbleweed package
names and paths.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905}
LEAP = {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 15}


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
    for module in ("banner", "freeipa", "netbird", "profile", "schedule",
                   "systemd-resolved", "timesyncd", "trivy", "updates",
                   "usb"):
        assert f"- baseline.{module}" in rendered


def test_other_os_fails_fast():
    for grains in (LEAP, {"os": "Debian", "os_family": "Debian"}, {}):
        rendered = render_init(dict(grains))
        assert "test.fail_without_changes" in rendered
        assert "include:" not in rendered
