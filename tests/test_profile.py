"""Render and shell-compatibility tests for baseline.profile and baseline.banner.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

import subprocess
from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render(path):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    return env.get_template(path).render()


def test_profile_state_manages_profile_dropin():
    rendered = render("baseline/profile/init.sls")
    assert "baseline_bash_profile:" in rendered
    assert "- name: /etc/profile.d/99-baseline.sh" in rendered
    assert "- source: salt://baseline/profile/templates/99-baseline.sh" in rendered


def test_profile_script_is_posix_sh_safe_when_sourced():
    script = SALT_ROOT / "baseline" / "profile" / "templates" / "99-baseline.sh"
    proc = subprocess.run(
        ["/bin/sh", "-c", f'. "{script}" && [ "$(umask)" = "0027" ] && [ "$EDITOR" = "vi" ]'],
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr


def test_banner_state_manages_motd_dropin():
    rendered = render("baseline/banner/init.sls")
    assert "motd_banner:" in rendered
    assert "- name: /etc/motd.d/99-steggy" in rendered
    assert "- source: salt://baseline/banner/templates/99-steggy" in rendered
