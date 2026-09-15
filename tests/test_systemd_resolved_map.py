"""Render tests for baseline/systemd-resolved package selection.

openSUSE Leap 15.x (and SLES/SLED 15) ship the resolver inside the
monolithic ``systemd`` package — no separate ``systemd-resolved``
package exists there, so a hard ``pkg.installed: systemd-resolved``
fails. Tumbleweed / Leap 16+ split it out. These tests render the
real ``map.jinja`` + ``init.sls`` with stubbed grains and assert the
right package is selected while the stub-resolver symlink stays put.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2
import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_map(grains):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.from_string(
        "{% from 'baseline/systemd-resolved/map.jinja' import resolved"
        " with context %}{{ resolved.pkg }}"
    )
    return tpl.render(grains=grains).strip()


def render_init(grains):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/systemd-resolved/init.sls")
    salt = {"pillar.get": lambda key, default=None: default}
    return tpl.render(grains=grains, salt=salt)


@pytest.mark.parametrize(
    "grains",
    [
        {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 15},
        {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": "15"},
        {"os": "SLES", "os_family": "Suse", "osmajorrelease": 15},
    ],
)
def test_suse_15_uses_monolithic_systemd_package(grains):
    assert render_map(grains) == "systemd"


@pytest.mark.parametrize(
    "grains",
    [
        {"os": "openSUSE Tumbleweed", "os_family": "Suse",
         "osmajorrelease": 20250905},
        {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 16},
        {"os": "SLES", "os_family": "Suse", "osmajorrelease": 16},
        {},
    ],
)
def test_modern_suse_uses_split_package(grains):
    assert render_map(grains) == "systemd-resolved"


@pytest.mark.parametrize(
    "grains",
    [
        {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 15},
        {"os": "openSUSE Tumbleweed", "os_family": "Suse",
         "osmajorrelease": 20250905},
    ],
)
def test_netconfig_guard_only_on_suse(grains):
    rendered = render_init(grains)
    assert 'NETCONFIG_DNS_POLICY=""' in rendered
    other = render_init({"os_family": "Debian", "osmajorrelease": "12"})
    assert "NETCONFIG_DNS_POLICY" not in other


def test_restorecon_only_when_selinux_enforced():
    enforcing = render_init(
        {
            "os_family": "RedHat",
            "selinux": {"enabled": True, "enforced": True},
        }
    )
    assert "restorecon -Rv /run/systemd/resolve" in enforcing
    assert "onlyif: command -v restorecon" in enforcing
    assert "onchanges:" in enforcing
    assert "- service: resolved_service" in enforcing
    restorecon = enforcing.split("resolved_selinux_restorecon:", 1)[1]
    assert "watch:" not in restorecon

    permissive = render_init(
        {
            "os_family": "RedHat",
            "selinux": {"enabled": True, "enforced": False},
        }
    )
    assert "restorecon" not in permissive

    suse = render_init(
        {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 15}
    )
    assert "restorecon" not in suse


def test_init_wires_selected_package_and_keeps_stub_symlink():
    leap = render_init({"os": "openSUSE Leap", "os_family": "Suse",
                        "osmajorrelease": 15})
    assert "- name: systemd\n" in leap
    assert "target: /run/systemd/resolve/stub-resolv.conf" in leap

    tw = render_init({"os": "openSUSE Tumbleweed", "os_family": "Suse",
                      "osmajorrelease": 20250905})
    assert "- name: systemd-resolved\n" in tw
    assert "target: /run/systemd/resolve/stub-resolv.conf" in tw
