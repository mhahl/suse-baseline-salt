"""Render tests for baseline/systemd-resolved (Tumbleweed-only).

Tumbleweed splits the resolver into the ``systemd-resolved`` subpackage,
so the package is fixed — no map selection. The netconfig guard always
renders (Tumbleweed always ships netconfig), while the restorecon block
still keys off the live SELinux state.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905}


def render_init(grains=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/systemd-resolved/init.sls")
    salt = {"pillar.get": lambda key, default=None: default}
    return tpl.render(grains=grains if grains is not None else dict(TW),
                      salt=salt)


def test_init_installs_split_package_and_keeps_stub_symlink():
    rendered = render_init()
    assert "- name: systemd-resolved\n" in rendered
    assert "target: /run/systemd/resolve/stub-resolv.conf" in rendered


def test_netconfig_guard_always_renders():
    rendered = render_init()
    assert 'NETCONFIG_DNS_POLICY=""' in rendered
    assert "onlyif: test -f /etc/sysconfig/network/config" in rendered


def test_restorecon_only_when_selinux_enforced():
    enforcing = render_init(
        {**TW, "selinux": {"enabled": True, "enforced": True}}
    )
    assert "restorecon -Rv /run/systemd/resolve" in enforcing
    assert "onlyif: command -v restorecon" in enforcing
    assert "onchanges:" in enforcing
    assert "- service: resolved_service" in enforcing
    restorecon = enforcing.split("resolved_selinux_restorecon:", 1)[1]
    assert "watch:" not in restorecon

    permissive = render_init(
        {**TW, "selinux": {"enabled": True, "enforced": False}}
    )
    assert "restorecon" not in permissive

    assert "restorecon" not in render_init()
