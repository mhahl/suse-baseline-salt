"""Render tests for baseline.trivy (Tumbleweed-only).

Trivy comes from the community package: install is a plain
``pkg.installed``, the initial scan requires it, and ``auto_dup`` in
baseline.updates is purely pillar-driven now that there is no other OS
left to protect.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905, "cpuarch": "x86_64"}


def render(path, grains=None, pillar=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
        extensions=["jinja2.ext.do"],
    )
    pillar = pillar or {}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return env.get_template(path).render(
        grains=grains or dict(TW), salt=salt
    )


def render_map(pillar=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
        extensions=["jinja2.ext.do"],
    )
    tpl = env.from_string(
        "{% from 'baseline/trivy/map.jinja' import trivy with context %}"
        "{{ trivy.severities }}|{{ trivy.pkg_version }}|{{ trivy.top_n }}"
    )
    pillar = pillar or {}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=dict(TW), salt=salt).strip()


def test_map_defaults_and_pillar_merge():
    assert render_map() == "HIGH,CRITICAL||20"
    assert render_map({"baseline:trivy": {"pkg_version": "0.74.0"}}).endswith(
        "|0.74.0|20"
    )


def test_install_is_plain_package():
    rendered = render("baseline/trivy/install.sls")
    assert "pkg.installed:" in rendered
    assert "- name: trivy" in rendered
    assert "pkgrepo.managed" not in rendered
    assert "Linux-" not in rendered
    assert "test.fail_without_changes" not in rendered


def test_install_honors_version_pin():
    rendered = render(
        "baseline/trivy/install.sls",
        pillar={"baseline:trivy": {"pkg_version": "0.74.0"}},
    )
    assert "- version: 0.74.0" in rendered


def test_init_always_includes_all_parts():
    rendered = render("baseline/trivy/init.sls")
    assert "baseline.trivy.install" in rendered
    assert "baseline.trivy.scan" in rendered
    assert "baseline.trivy.schedule" in rendered
    assert "reload_modules: True" in rendered


def test_initial_scan_requires_package():
    rendered = render("baseline/trivy/scan.sls")
    assert "onlyif: test -x /usr/bin/trivy" in rendered
    assert "- module: trivy_sync_modules" in rendered
    assert "- pkg: trivy_package" in rendered
    assert "trivy_binary" not in rendered


def test_auto_dup_is_pillar_driven():
    pillar = {"baseline:updates:auto_dup": True}
    on = render("baseline/updates/init.sls", pillar=pillar)
    assert "tumbleweed_full_update" in on
    assert "dup --dry-run" in on
    off = render("baseline/updates/init.sls")
    assert "tumbleweed_full_update" not in off
    assert "updates_zypper_config" in off  # zypp config still applies
