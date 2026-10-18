"""Render tests for the openSUSE and Fedora FreeIPA client branches.

Tumbleweed adds the OBS repo; Fedora uses its base repo. Both install the
FreeIPA client package by default (install-only). Domain join via
ipa-client-install is opt-in through join.enabled + domain/principal/
password (encrypted pillar): secrets go via env with hide_output, the
join is skipped when /etc/ipa/default.conf exists, and --no-ntp keeps
timesyncd the sole NTP client. Disabling on Tumbleweed removes the repo
but keeps already-installed packages, mirroring how the croniter
providers stay installed in baseline.schedule's disabled branches.

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


def test_join_disabled_by_default():
    rendered = render_freeipa({})
    assert "freeipa_join:" not in rendered
    assert "IPA_JOIN_PASSWORD" not in rendered


def test_join_enabled_renders_idempotent_secret_free_command():
    rendered = render_freeipa({"join": {
        "enabled": True, "domain": "example.com",
        "principal": "svc-enroll", "password": "s3cret",
    }})
    assert "freeipa_join:" in rendered
    assert "cmd.run:" in rendered
    assert "--domain=example.com" in rendered
    assert "--realm=EXAMPLE.COM" in rendered
    assert "--principal=svc-enroll" in rendered
    # Secret via env, never inline in the state name.
    assert "- IPA_JOIN_PASSWORD: s3cret" in rendered
    assert '--password="$IPA_JOIN_PASSWORD"' in rendered
    assert "--password=s3cret" not in rendered
    assert "--password s3cret" not in rendered
    assert "--mkhomedir" in rendered
    assert "--no-ntp" in rendered
    assert "hide_output: True" in rendered
    assert "output_loglevel: quiet" in rendered
    assert "unless: test -f /etc/ipa/default.conf" in rendered
    assert "- pkg: freeipa_client" in rendered


def test_join_optional_server_realm_flags():
    rendered = render_freeipa({"join": {
        "enabled": True, "domain": "example.com", "realm": "EXAMPLE.ORG",
        "server": "ipa.example.com", "principal": "svc", "password": "p",
        "mkhomedir": False, "no_ntp": False, "extra_args": "--no-ssh",
    }})
    assert "--realm=EXAMPLE.ORG" in rendered
    assert "--server=ipa.example.com" in rendered
    assert "--no-mkhomedir" in rendered
    assert "--no-ntp" not in rendered
    assert "--no-ssh" in rendered


def test_join_missing_creds_fails_closed():
    for join in ({"enabled": True}, {"enabled": True, "domain": "example.com"},
                 {"enabled": True, "domain": "example.com", "principal": "svc"}):
        rendered = render_freeipa({"join": join})
        assert "test.fail_without_changes:" in rendered
        assert "domain, principal and password" in rendered
        assert "freeipa_join:" not in rendered
