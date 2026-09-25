"""Render tests for baseline.minion master addresses (IPs, not DNS).

The module writes the minion's master list to a drop-in with native
Salt failover, defaulting to Salt's built-in ``salt`` hostname (zero
behavior change), and restarts the minion on change only where systemd
supervises it. A lone string is accepted and wrapped to a list.
Disabling removes the drop-in.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

PROD_MASTERS = ["139.99.210.89", "139.99.210.170", "139.99.149.92"]


def render_minion(pillar_minion):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/minion/init.sls")
    pillar = {"baseline:minion": pillar_minion}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(salt=salt)


def test_default_keeps_salt_builtin_hostname():
    rendered = render_minion({})
    assert "file.managed:" in rendered
    assert "- name: /etc/salt/minion.d/99-baseline.conf" in rendered
    assert "- salt" in rendered
    assert "master_type: failover" in rendered
    assert "file.absent:" not in rendered


def test_master_list_rendered_with_failover():
    rendered = render_minion({"masters": list(PROD_MASTERS)})
    for addr in PROD_MASTERS:
        assert f"- {addr}" in rendered
    assert "master_type: failover" in rendered
    assert "master: salt" not in rendered


def test_lone_string_wrapped_to_list():
    rendered = render_minion({"masters": "139.99.210.89"})
    assert "- 139.99.210.89" in rendered
    assert "master_type: failover" in rendered


def test_restart_wired_to_config_change():
    rendered = render_minion({"masters": list(PROD_MASTERS)})
    assert "- name: service.restart" in rendered
    assert "- m_name: salt-minion" in rendered
    assert "- file: minion_master_config" in rendered
    assert "onlyif: test -d /run/systemd/system" in rendered


def test_disabled_removes_dropin():
    rendered = render_minion({"enabled": False})
    assert "file.absent:" in rendered
    assert "- name: /etc/salt/minion.d/99-baseline.conf" in rendered
    assert "file.managed:" not in rendered
    assert "service.restart" not in rendered
