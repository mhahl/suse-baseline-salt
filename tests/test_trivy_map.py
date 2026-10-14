"""Render tests for baseline.trivy and update branches on both platforms.

Trivy comes from the Tumbleweed community package or Fedora's base repos.
The install is ``pkg.installed``, the initial scan requires it, and ``auto_dup`` in
baseline.updates selects the platform's update command.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905, "cpuarch": "x86_64"}
FEDORA = {"os": "Fedora", "os_family": "RedHat",
          "osrelease": "43", "cpuarch": "x86_64"}


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
    assert "test -x /usr/local/bin/trivy" in rendered
    assert "test -x /usr/bin/trivy" in rendered
    assert "- module: trivy_sync_modules" in rendered
    assert "- pkg: trivy_package" in rendered
    assert "trivy_binary" not in rendered


def test_schedule_renders_daily_publish_for_overstate():
    rendered = render("baseline/trivy/schedule.sls")
    # Stable Overstate contracts: snake_case state ID, hyphenated job name.
    assert "trivy_cve_scan:" in rendered
    assert "- name: trivy-cve-scan" in rendered
    assert "function: trivy_scan.publish" in rendered
    assert "- days: 1" in rendered
    assert "- splay: 600" in rendered
    assert "- persist: True" in rendered
    assert "- return_job: False" in rendered


def test_schedule_splay_clamped_to_day():
    bad = render(
        "baseline/trivy/schedule.sls",
        pillar={"baseline:trivy": {"schedule_splay": 999999}},
    )
    assert "- splay: 600" in bad
    negative = render(
        "baseline/trivy/schedule.sls",
        pillar={"baseline:trivy": {"schedule_splay": -5}},
    )
    assert "- splay: 600" in negative
    ok = render(
        "baseline/trivy/schedule.sls",
        pillar={"baseline:trivy": {"schedule_splay": 300}},
    )
    assert "- splay: 300" in ok


def test_auto_dup_is_pillar_driven():
    pillar = {"baseline:updates:auto_dup": True}
    on = render("baseline/updates/init.sls", pillar=pillar)
    assert "tumbleweed_full_update" in on
    assert "dup --dry-run" in on
    off = render("baseline/updates/init.sls")
    assert "tumbleweed_full_update" not in off
    assert "updates_zypper_config" in off  # zypp config still applies


def test_zypp_conf_created_before_keyvalue():
    # file.keyvalue cannot open a missing file (minimal images),
    # so the state ensures an empty one first without touching existing.
    rendered = render("baseline/updates/init.sls")
    assert "updates_zypp_conf_exists" in rendered
    assert "- replace: False" in rendered
    assert "- file: updates_zypp_conf_exists" in rendered


def test_fedora_updates_use_minimal_dnf_conf_and_gate_upgrade():
    off = render("baseline/updates/init.sls", grains=dict(FEDORA))
    assert "/etc/dnf/dnf.conf" in off
    assert "updates_dnf_conf_exists" in off
    assert "updates_zypper_config" not in off
    assert "zypper" not in off
    assert "dnf upgrade --refresh -y" not in off

    on = render(
        "baseline/updates/init.sls",
        grains=dict(FEDORA),
        pillar={"baseline:updates:auto_dup": True},
    )
    assert "dnf upgrade --refresh -y" in on
    assert "dnf -q check-update --refresh" in on
    assert "tumbleweed_full_update" not in on
    assert "zypper" not in on
