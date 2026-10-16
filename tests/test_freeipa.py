"""Render tests for the openSUSE and Fedora FreeIPA client branches.

Tumbleweed adds the OBS repo; Fedora uses its base repo. Both install the
FreeIPA client package only — no domain enrollment. Disabling on Tumbleweed
removes the repo but keeps already-installed packages, mirroring how the
croniter providers stay installed in baseline.schedule's disabled
branches.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_freeipa(pillar_freeipa, grains=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/freeipa/init.sls")
    pillar = {"baseline:freeipa": pillar_freeipa}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=grains or {"os_family": "Suse"}, salt=salt)


def test_enabled_adds_repo_and_installs_client():
    rendered = render_freeipa({})
    assert "pkgrepo.managed:" in rendered
    assert "- name: security:idm" in rendered
    assert "security:/idm/openSUSE_Tumbleweed" in rendered
    assert "pkg.installed:" in rendered
    assert "- freeipa-client" in rendered
    assert "- fromrepo: security:idm" in rendered
    assert "- pkgrepo: freeipa_obs_repo" in rendered
    assert "gpgkey: https://download.opensuse.org/repositories/security:/idm/openSUSE_Tumbleweed/repodata/repomd.xml.key" in rendered
    # zypper prompts on new/rotated keys: both states auto-import natively
    assert rendered.count("- gpgautoimport: True") == 2
    assert "rpm --import" not in rendered
    assert "pkgrepo.absent:" not in rendered


def test_disabled_removes_repo_only():
    rendered = render_freeipa({"enabled": False})
    assert "pkgrepo.absent:" in rendered
    assert "- name: security:idm" in rendered
    assert "pkg.installed:" not in rendered


def test_custom_repo_and_packages():
    rendered = render_freeipa(
        {
            "repo_name": "security:idm",
            "repo_url": "https://example.invalid/idm/",
            "packages": ["freeipa-client", "oddjob"],
        }
    )
    assert "https://example.invalid/idm/" in rendered
    assert "- oddjob" in rendered


def test_fedora_installs_client_without_obs_repo_or_zypper_options():
    rendered = render_freeipa({}, grains={"os": "Fedora", "os_family": "RedHat"})
    assert "pkg.installed:" in rendered
    assert "- freeipa-client" in rendered
    assert "pkgrepo.managed:" not in rendered
    assert "pkgrepo.absent:" not in rendered
    assert "fromrepo:" not in rendered
    assert "gpgautoimport:" not in rendered
