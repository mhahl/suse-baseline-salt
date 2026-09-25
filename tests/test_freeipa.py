"""Render tests for baseline.freeipa client installs.

The module adds the OBS security:idm repo and installs the FreeIPA
client package (install only — no domain enrollment). Disabling it must
remove the repo but keep already-installed packages, mirroring how the
croniter providers stay installed in baseline.schedule's disabled
branches.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_freeipa(pillar_freeipa):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/freeipa/init.sls")
    pillar = {"baseline:freeipa": pillar_freeipa}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(salt=salt)


def test_enabled_adds_repo_and_installs_client():
    rendered = render_freeipa({})
    assert "pkgrepo.managed:" in rendered
    assert "- name: security:idm" in rendered
    assert "security:/idm/openSUSE_Tumbleweed" in rendered
    assert "rpm --import" in rendered
    assert "repodata/repomd.xml.key" in rendered
    assert "- unless: rpm -q gpg-pubkey-6dd785ca" in rendered
    assert "- cmd: freeipa_repo_key" in rendered
    assert "pkg.installed:" in rendered
    assert "- freeipa-client" in rendered
    assert "- fromrepo: security:idm" in rendered
    assert "- pkgrepo: freeipa_obs_repo" in rendered
    assert "pkgrepo.absent:" not in rendered


def test_custom_keyid_overrides_default():
    rendered = render_freeipa({"repo_keyid": "deadbeef"})
    assert "- unless: rpm -q gpg-pubkey-deadbeef" in rendered
    assert "gpg-pubkey-6dd785ca" not in rendered


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
