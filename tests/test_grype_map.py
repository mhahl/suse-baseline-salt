"""Render tests for baseline.grype.

Grype ships as a pinned GitHub release tarball to /usr/local/bin/grype
(no distro package on either platform). The install extracts the
versioned tarball, the initial scan requires it, and the daily schedule
publishes the mine summary.

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
        "{% from 'baseline/grype/map.jinja' import grype with context %}"
        "{{ grype.severities }}|{{ grype.version }}|{{ grype.top_n }}"
    )
    pillar = pillar or {}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=dict(TW), salt=salt).strip()


def test_map_defaults_and_pillar_merge():
    assert render_map() == "HIGH,CRITICAL|v0.120.1|20"
    assert render_map({"baseline:grype": {"version": "v0.121.0"}}).endswith(
        "|v0.121.0|20"
    )


def test_install_fetches_pinned_github_release():
    rendered = render("baseline/grype/install.sls")
    assert "archive.extracted:" in rendered
    assert "https://github.com/anchore/grype/releases/download/v0.120.1" in rendered
    assert "grype_0.120.1_linux_amd64.tar.gz" in rendered
    assert "pkg.installed" not in rendered
    assert "/usr/local/bin/grype version" in rendered


def test_install_honors_version_pin_and_arch():
    rendered = render(
        "baseline/grype/install.sls",
        pillar={"baseline:grype": {"version": "v0.121.0"}},
    )
    assert "grype_0.121.0_linux_amd64.tar.gz" in rendered
    arm = render("baseline/grype/install.sls",
                 grains={"os": "Fedora", "os_family": "RedHat",
                         "osrelease": "43", "cpuarch": "aarch64"})
    assert "linux_arm64.tar.gz" in arm


def test_init_always_includes_all_parts():
    rendered = render("baseline/grype/init.sls")
    assert "baseline.grype.install" in rendered
    assert "baseline.grype.scan" in rendered
    assert "baseline.grype.schedule" in rendered
    assert "reload_modules: True" in rendered


def test_initial_scan_requires_binary():
    rendered = render("baseline/grype/scan.sls")
    assert "onlyif: test -x /usr/local/bin/grype" in rendered
    assert "- module: grype_sync_modules" in rendered
    assert "- archive: grype_binary" in rendered
    assert "grype_scan.scan" in rendered


def test_schedule_renders_daily_publish_for_overstate():
    rendered = render("baseline/grype/schedule.sls")
    # Stable Overstate contracts: snake_case state ID, hyphenated job name.
    assert "grype_cve_scan:" in rendered
    assert "- name: grype-cve-scan" in rendered
    assert "function: grype_scan.publish" in rendered
    assert "- days: 1" in rendered
    assert "- splay: 600" in rendered
    assert "- persist: True" in rendered
    assert "- return_job: False" in rendered


def test_schedule_splay_clamped_to_day():
    bad = render(
        "baseline/grype/schedule.sls",
        pillar={"baseline:grype": {"schedule_splay": 999999}},
    )
    assert "- splay: 600" in bad
    negative = render(
        "baseline/grype/schedule.sls",
        pillar={"baseline:grype": {"schedule_splay": -5}},
    )
    assert "- splay: 600" in negative
    ok = render(
        "baseline/grype/schedule.sls",
        pillar={"baseline:grype": {"schedule_splay": 300}},
    )
    assert "- splay: 300" in ok


def test_clean_removes_binary_and_cache():
    rendered = render("baseline/grype/clean.sls")
    assert "- name: grype-cve-scan" in rendered
    assert "- name: /usr/local/bin/grype" in rendered
    assert "grype_cache_dir" in rendered
