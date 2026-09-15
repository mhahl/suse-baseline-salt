"""Render tests for baseline.trivy platform selection and guards.

The zypper branch used to match ``os == 'openSUSE'``, but Salt reports
"openSUSE Leap" / "openSUSE Tumbleweed" — so the whole SUSE fleet fell
through to ``unsupported`` and failed the baseline. These tests pin the
os_family-based selection, the cpuarch tarball mapping, the tar
dependency, the Tumbleweed-only auto_dup gate, and the unsupported-OS
skip (which keeps one stray host from reddening the full baseline).

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2
import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render(path, grains, pillar=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
        extensions=["jinja2.ext.do"],
    )
    pillar = pillar or {}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return env.get_template(path).render(grains=grains, salt=salt)


def render_map(grains, pillar=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
        extensions=["jinja2.ext.do"],
    )
    tpl = env.from_string(
        "{% from 'baseline/trivy/map.jinja' import trivy with context %}"
        "{{ trivy.install_flavor }}|{{ trivy.arch }}"
    )
    pillar = pillar or {}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=grains, salt=salt).strip()


LEAP = {"os": "openSUSE Leap", "os_family": "Suse", "osmajorrelease": 15,
        "cpuarch": "x86_64"}
TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905, "cpuarch": "x86_64"}
SLES = {"os": "SLES", "os_family": "Suse", "osmajorrelease": 15,
        "cpuarch": "x86_64"}
SLES_ARM = dict(SLES, cpuarch="aarch64")
RHEL = {"os": "RedHat", "os_family": "RedHat", "osmajorrelease": 9,
        "cpuarch": "x86_64"}
DEBIAN = {"os": "Debian", "os_family": "Debian", "osmajorrelease": 12,
          "cpuarch": "x86_64"}


@pytest.mark.parametrize("grains", [LEAP, TW])
def test_suse_desktop_family_uses_zypper(grains):
    assert render_map(grains) == "zypper|64bit"


def test_sles_uses_binary_with_cpu_arch():
    assert render_map(SLES) == "binary|64bit"
    assert render_map(SLES_ARM) == "binary|ARM64"


def test_rhel_uses_rpm_repo():
    assert render_map(RHEL) == "rpm_repo|64bit"


def test_unknown_os_is_unsupported():
    assert render_map(DEBIAN) == "unsupported|64bit"


def test_binary_install_needs_tar_before_tarball():
    rendered = render("baseline/trivy/install.sls", SLES_ARM)
    assert "Linux-ARM64.tar.gz" in rendered
    assert "- name: tar" in rendered
    assert "- pkg: trivy_tar" in rendered


def test_rpm_install_uses_repo_not_tarball():
    rendered = render("baseline/trivy/install.sls", RHEL)
    assert "pkgrepo.managed" in rendered
    assert "Linux-" not in rendered


def test_unsupported_install_still_fails_direct_apply():
    rendered = render("baseline/trivy/install.sls", DEBIAN)
    assert "test.fail_without_changes" in rendered


def test_trivy_init_skips_unsupported_platforms():
    assert "baseline.trivy.install" in render("baseline/trivy/init.sls", LEAP)
    assert "include:" not in render("baseline/trivy/init.sls", DEBIAN)


def test_initial_scan_skipped_without_binary():
    rendered = render("baseline/trivy/scan.sls", SLES)
    assert "onlyif: test -x /usr/bin/trivy -o -x /usr/local/bin/trivy" in rendered


def test_auto_dup_only_on_tumbleweed():
    pillar = {"baseline:updates:auto_dup": True}
    tw = render("baseline/updates/init.sls", TW, pillar)
    assert "tumbleweed_full_update" in tw
    assert "dup --dry-run" in tw
    assert "list-patches" not in tw
    leap = render("baseline/updates/init.sls", LEAP, pillar)
    assert "tumbleweed_full_update" not in leap
    assert "updates_zypper_config" in leap  # zypp config still applies
    assert "file.keyvalue:" in leap
    assert "file.managed:" not in leap


def test_trivy_init_reloads_modules_after_sync():
    rendered = render("baseline/trivy/init.sls", TW)
    assert "reload_modules: True" in rendered


def test_initial_scan_requires_sync_and_install():
    rendered = render("baseline/trivy/scan.sls", TW)
    assert "- module: trivy_sync_modules" in rendered
    assert "- pkg: trivy_package" in rendered
    binary = render("baseline/trivy/scan.sls", SLES)
    assert "- cmd: trivy_binary" in binary
