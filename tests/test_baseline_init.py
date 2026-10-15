"""Render tests for the openSUSE Tumbleweed and Fedora baseline guard.

The guard preserves the existing Tumbleweed grain variants and adds
Fedora only when os_family is RedHat and os is Fedora.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905, "osrelease": "20250905"}
FEDORA = {"os": "Fedora", "osfullname": "Fedora Linux",
          "os_family": "RedHat", "osrelease": "43"}
TW_OS_ONLY = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
              "osrelease": "15.6"}
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

COMMON_MODULES = ("banner", "minion", "profile", "systemd-resolved",
                  "timesyncd", "grype", "usb")


def render_init(grains):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/init.sls")
    salt = {"pillar.get": lambda key, default=None: default}
    return tpl.render(grains=grains, salt=salt)


def test_tumbleweed_includes_common_modules_and_suse_group():
    rendered = render_init(dict(TW))
    assert "test.fail_without_changes" not in rendered
    for module in COMMON_MODULES:
        assert f"- baseline.{module}" in rendered
    assert "- baseline.suse" in rendered
    assert "- baseline.redhat" not in rendered




def test_suse_os_grain_path_is_preserved():
    rendered = render_init(dict(TW_OS_ONLY))
    assert "test.fail_without_changes" not in rendered
    assert "- baseline.suse" in rendered


def test_family_groups_include_divergent_modules():
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(str(SALT_ROOT)))
    for family in ("suse", "redhat"):
        rendered = env.get_template(f"baseline/{family}/init.sls").render()
        for module in ("freeipa", "netbird", "schedule", "updates"):
            assert f"- baseline.{module}" in rendered


def test_suse_with_rolling_date_is_admitted():
    rendered = render_init(dict(TW_SUSE))
    assert "test.fail_without_changes" not in rendered
    for module in COMMON_MODULES:
        assert f"- baseline.{module}" in rendered
    assert "- baseline.suse" in rendered
    assert "- baseline.redhat" not in rendered


def test_fedora_includes_common_modules_and_redhat_group():
    rendered = render_init(dict(FEDORA))
    assert "test.fail_without_changes" not in rendered
    for module in COMMON_MODULES:
        assert f"- baseline.{module}" in rendered
    assert "- baseline.redhat" in rendered
    assert "- baseline.suse" not in rendered


def test_suse_grain_with_tumbleweed_fullname_is_admitted():
    rendered = render_init(dict(TW_SUSE_FULLNAME))
    assert "test.fail_without_changes" not in rendered
    for module in COMMON_MODULES:
        assert f"- baseline.{module}" in rendered
    assert "- baseline.suse" in rendered
    assert "- baseline.redhat" not in rendered


def test_other_os_fails_fast_with_grains_in_message():
    for grains in (LEAP15, LEAP16, SLES,
                   {"os": "Debian", "os_family": "Debian",
                    "osrelease": "12"},
                   {"os": "CentOS", "os_family": "RedHat"},
                   {}):
        rendered = render_init(dict(grains))
        assert "test.fail_without_changes" in rendered
        assert "include:" not in rendered
        assert "got os=" in rendered
        assert "os_family=" in rendered
