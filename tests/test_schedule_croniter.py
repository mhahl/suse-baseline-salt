"""Render tests for the baseline.schedule croniter dependency.

The nightly highstate uses a ``cron:`` expression, which the minion can
only evaluate with the ``croniter`` Python module installed. These tests
render the real ``salt/baseline/schedule/init.sls`` with stubbed grains
and pillar and assert both providers are installed — the versioned
system packages matching the minion's own interpreter (classic RPM
minions) and ``croniter`` in Salt's own Python (onedir/venv/container
minions) — and required by the cron job in the enabled branch. In the
disabled branches the packages stay installed but removing a stale job
must not depend on them.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

PY313 = {"pythonversion": [3, 13, 0, "final", 0]}
PY314 = {"pythonversion": [3, 14, 0, "final", 0]}


def render_init(pillar_schedule, grains=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/schedule/init.sls")
    pillar = {"baseline:schedule": pillar_schedule}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(
        grains=dict(PY313) if grains is None else grains, salt=salt
    )


def test_cron_job_requires_croniter_package():
    rendered = render_init({})
    assert "- name: python313-croniter" in rendered
    assert "- name: python313-pip" in rendered
    assert "pip.installed:" in rendered
    assert "- name: croniter" in rendered
    assert "schedule.present:" in rendered
    assert "- pkg: schedule_croniter_package" in rendered
    assert "- pkg: schedule_pip_package" in rendered
    assert "- pip: schedule_croniter_pip" in rendered


def test_package_names_track_interpreter_minor():
    rendered = render_init({}, grains=dict(PY314))
    assert "- name: python314-croniter" in rendered
    assert "- name: python314-pip" in rendered
    assert "python313" not in rendered


def test_disabled_branches_need_no_package_require():
    rendered = render_init({"enabled": False})
    assert "- name: python313-croniter" in rendered
    assert "- name: python313-pip" in rendered
    assert "pip.installed:" in rendered
    assert "schedule.absent:" in rendered
    assert "- pkg: schedule_croniter_package" not in rendered
    assert "- pip: schedule_croniter_pip" not in rendered
