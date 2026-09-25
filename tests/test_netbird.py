"""Render tests for baseline.netbird client installs.

The module adds the official NetBird RPM repo, installs the client
package, and enables the daemon (no network join — `netbird up` needs
an SSO login or a setup key). Disabling it must remove the repo and
stop the daemon but keep already-installed packages, mirroring how the
croniter providers stay installed in baseline.schedule's disabled
branches.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_netbird(pillar_netbird):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/netbird/init.sls")
    pillar = {"baseline:netbird": pillar_netbird}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(salt=salt)


def test_enabled_adds_repo_installs_client_and_runs_service():
    rendered = render_netbird({})
    assert "pkgrepo.managed:" in rendered
    assert "- name: netbird" in rendered
    assert "https://pkgs.netbird.io/yum/" in rendered
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
