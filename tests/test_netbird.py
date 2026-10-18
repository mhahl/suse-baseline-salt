"""Render tests for baseline.netbird client installs.

The module adds the official NetBird RPM repo, installs the client
package, and enables the daemon. Network join (`netbird up`) is opt-in
via join.enabled + setup_key (encrypted pillar): the key is passed via
env with hide_output so it never lands in the state name, and the join
is skipped when `netbird status` already reports connected. Disabling
must remove the repo and stop the daemon but keep already-installed
packages, mirroring how the croniter providers stay installed in
baseline.schedule's disabled branches.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_netbird(pillar_netbird, grains=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/netbird/init.sls")
    pillar = {"baseline:netbird": pillar_netbird}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=grains or {"os_family": "Suse"}, salt=salt)


def test_enabled_adds_repo_installs_client_and_runs_service():
    rendered = render_netbird({})
    assert "pkgrepo.managed:" in rendered
    assert "- name: netbird" in rendered
    assert "https://pkgs.netbird.io/yum/" in rendered
    assert "gpgkey: https://pkgs.netbird.io/yum/repodata/repomd.xml.key" in rendered
    # zypper prompts on new/rotated keys: both states auto-import natively
    assert rendered.count("- gpgautoimport: True") == 2
    assert "rpm --import" not in rendered
    assert "pkg.installed:" in rendered
    assert "- netbird" in rendered
    assert "- fromrepo: netbird" in rendered
    assert "- pkgrepo: netbird_repo" in rendered
    assert "service.running:" in rendered
    assert "- pkg: netbird_client" in rendered
    assert "pkgrepo.absent:" not in rendered


def test_service_opt_out_disables_daemon():
    rendered = render_netbird({"enable_service": False})
    assert "service.disabled:" in rendered
    assert "service.running:" not in rendered
    assert "pkg.installed:" in rendered


def test_disabled_removes_repo_and_stops_service():
    rendered = render_netbird({"enabled": False})
    assert "pkgrepo.absent:" in rendered
    assert "- name: netbird" in rendered
    assert "service.dead:" in rendered
    assert "pkg.installed:" not in rendered


def test_custom_repo_and_packages():
    rendered = render_netbird(
        {
            "repo_url": "https://example.invalid/netbird/",
            "packages": ["netbird", "netbird-ui"],
        }
    )
    assert "https://example.invalid/netbird/" in rendered
    assert "- netbird-ui" in rendered


def test_fedora_uses_repo_signing_and_skips_zypper_auto_import():
    rendered = render_netbird({}, grains={"os": "Fedora", "os_family": "RedHat"})
    assert "pkgrepo.managed:" in rendered
    assert "https://pkgs.netbird.io/yum/" in rendered
    assert "gpgkey: https://pkgs.netbird.io/yum/repodata/repomd.xml.key" in rendered
    assert "gpgcheck: 1" in rendered
    assert "repo_gpgcheck: 1" in rendered
    assert "gpgautoimport:" not in rendered
    assert "pkg.installed:" in rendered
    assert "- netbird" in rendered
    assert "- fromrepo: netbird" in rendered
    assert "service.running:" in rendered


def test_join_disabled_by_default():
    rendered = render_netbird({})
    assert "netbird_join:" not in rendered
    assert "NB_SETUP_KEY" not in rendered


def test_join_enabled_renders_idempotent_secret_free_command():
    rendered = render_netbird({"join": {"enabled": True, "setup_key": "KEY-123"}})
    assert "netbird_join:" in rendered
    assert "cmd.run:" in rendered
    # Secret via env, never inline in the state name.
    assert "- NB_SETUP_KEY: KEY-123" in rendered
    assert 'netbird up --setup-key "$NB_SETUP_KEY"' in rendered
    assert "--setup-key KEY-123" not in rendered
    assert "hide_output: True" in rendered
    assert "output_loglevel: quiet" in rendered
    assert "unless: netbird status" in rendered
    assert "grep -qi connected" in rendered
    assert "- pkg: netbird_client" in rendered
    assert "- service: netbird_service" in rendered


def test_join_optional_flags():
    rendered = render_netbird({"join": {
        "enabled": True, "setup_key": "K",
        "hostname": "web01", "management_url": "https://nb.example.com",
        "extra_args": "--rosenpass-permissive",
    }})
    assert "--hostname web01" in rendered
    assert "--management-url https://nb.example.com" in rendered
    assert "--rosenpass-permissive" in rendered


def test_join_missing_key_fails_closed():
    rendered = render_netbird({"join": {"enabled": True}})
    assert "test.fail_without_changes:" in rendered
    assert "join:setup_key is required" in rendered
    assert "netbird_join:" not in rendered
