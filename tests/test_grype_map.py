"""Render tests for overstate.grype (decoupled from baseline).

Grype ships as a pinned GitHub release tarball to /usr/local/bin/grype
(no distro package on either platform). The install extracts the
versioned tarball, the initial scan requires it, and the daily schedule
publishes the mine summary. Canonical pillar is overstate:grype with
legacy baseline:grype merged first (overstate wins).

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
        "{% from 'overstate/grype/map.jinja' import grype with context %}"
        "{{ grype.severities }}|{{ grype.version }}|{{ grype.top_n }}"
    )
    pillar = pillar or {}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=dict(TW), salt=salt).strip()


def test_map_defaults_and_pillar_merge():
    assert render_map() == "HIGH,CRITICAL|v0.120.1|20"
    assert render_map({"overstate:grype": {"version": "v0.121.0"}}).endswith(
        "|v0.121.0|20"
    )


def test_map_legacy_baseline_fallback_and_overstate_wins():
    legacy = render_map({"baseline:grype": {"version": "v0.119.0"}})
    assert legacy.endswith("|v0.119.0|20")
    both = render_map({"baseline:grype": {"version": "v0.119.0"},
                       "overstate:grype": {"version": "v0.121.0"}})
    assert both.endswith("|v0.121.0|20")


def test_install_fetches_pinned_github_release():
    rendered = render("overstate/grype/install.sls")
    assert "archive.extracted:" in rendered
    assert "https://github.com/anchore/grype/releases/download/v0.120.1" in rendered
    assert "grype_0.120.1_linux_amd64.tar.gz" in rendered
    assert "source_hash: sha256=0a9ee97ef5ae2ee953b0a80098105052e846cdbe319a57d808b519c33cd1343d" in rendered
    assert "pkg.installed" not in rendered
    assert "/usr/local/bin/grype version" in rendered


def test_install_honors_version_pin_and_arch():
    rendered = render(
        "overstate/grype/install.sls",
        pillar={
            "overstate:grype": {
                "version": "v0.121.0",
                "hashes": {"amd64": "sha256=custom_amd64_digest"},
            }
        },
    )
    assert "grype_0.121.0_linux_amd64.tar.gz" in rendered
    assert "source_hash: sha256=custom_amd64_digest" in rendered
    arm = render("overstate/grype/install.sls",
                 grains={"os": "Fedora", "os_family": "RedHat",
                         "osrelease": "43", "cpuarch": "aarch64"})
    assert "linux_arm64.tar.gz" in arm
    assert "source_hash: sha256=29f47391dc283aa79fcc38e65224cd61f64dec0ecfd0db7074128ebf8ff23514" in arm


def test_init_always_includes_all_parts():
    rendered = render("overstate/grype/init.sls")
    assert "overstate.grype.install" in rendered
    assert "overstate.grype.scan" in rendered
    assert "overstate.grype.schedule" in rendered
    assert "reload_modules: True" in rendered


def test_initial_scan_requires_binary():
    rendered = render("overstate/grype/scan.sls")
    assert "onlyif: test -x /usr/local/bin/grype" in rendered
    assert "- module: grype_sync_modules" in rendered
    assert "- archive: grype_binary" in rendered
    assert "grype_scan.scan" in rendered


def test_schedule_renders_daily_publish_for_overstate():
    rendered = render("overstate/grype/schedule.sls")
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
        "overstate/grype/schedule.sls",
        pillar={"overstate:grype": {"schedule_splay": 999999}},
    )
    assert "- splay: 600" in bad
    negative = render(
        "overstate/grype/schedule.sls",
        pillar={"overstate:grype": {"schedule_splay": -5}},
    )
    assert "- splay: 600" in negative
    ok = render(
        "overstate/grype/schedule.sls",
        pillar={"overstate:grype": {"schedule_splay": 300}},
    )
    assert "- splay: 300" in ok


def test_clean_removes_binary_and_cache():
    rendered = render("overstate/grype/clean.sls")
    assert "- name: grype-cve-scan" in rendered
    assert "- name: /usr/local/bin/grype" in rendered
    assert "grype_cache_dir" in rendered
def test_map_nice_level_default_and_override():
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
        extensions=["jinja2.ext.do"],
    )
    tpl = env.from_string(
        "{% from 'overstate/grype/map.jinja' import grype with context %}"
        "{{ grype.nice_level }}"
    )
    salt = {"pillar.get": lambda key, default=None: {}}
    assert tpl.render(grains=dict(TW), salt=salt).strip() == "19"
    salt = {"pillar.get": lambda key, default=None:
            {"overstate:grype": {"nice_level": 10}}.get(key, default)}
    assert tpl.render(grains=dict(TW), salt=salt).strip() == "10"
