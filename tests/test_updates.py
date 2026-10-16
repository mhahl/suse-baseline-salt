"""Render tests for baseline.updates across openSUSE Tumbleweed and Fedora.

Tumbleweed edits /etc/zypp/zypp.conf in place via file.keyvalue and
optionally runs zypper dup when baseline:updates:auto_dup is True.
Fedora ensures /etc/dnf/dnf.conf exists without replacing vendor keys
and optionally runs dnf upgrade --refresh when auto_dup is True.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_updates(auto_dup=False, grains=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/updates/init.sls")
    pillar = {"baseline:updates:auto_dup": auto_dup}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=grains or {"os_family": "Suse"}, salt=salt)


def test_suse_manages_zypp_conf_and_skips_dup_by_default():
    rendered = render_updates(False, {"os_family": "Suse"})
    assert "updates_zypp_conf_exists:" in rendered
    assert "updates_zypper_config:" in rendered
    assert "solver.onlyRequires: 'true'" in rendered
    assert "solver.allowVendorChange: 'false'" in rendered
    assert "tumbleweed_full_update:" not in rendered
    assert "fedora_full_update:" not in rendered
    assert "- file: updates_zypper_config" in rendered


def test_suse_auto_dup_enables_zypper_dup():
    rendered = render_updates(True, {"os_family": "Suse"})
    assert "tumbleweed_full_update:" in rendered
    assert "zypper --non-interactive dup" in rendered
    assert "- cmd: tumbleweed_full_update" in rendered


def test_fedora_manages_dnf_conf_and_skips_upgrade_by_default():
    rendered = render_updates(False, {"os_family": "RedHat"})
    assert "updates_dnf_conf_exists:" in rendered
    assert "- name: /etc/dnf/dnf.conf" in rendered
    assert "updates_zypper_config:" not in rendered
    assert "fedora_full_update:" not in rendered
    assert "- file: updates_dnf_conf_exists" in rendered


def test_fedora_auto_dup_enables_dnf_upgrade():
    rendered = render_updates(True, {"os_family": "RedHat"})
    assert "fedora_full_update:" in rendered
    assert "dnf upgrade --refresh -y" in rendered
    assert "- cmd: fedora_full_update" in rendered
