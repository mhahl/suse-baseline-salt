"""Render tests for the baseline.schedule croniter dependency.

The nightly highstate uses a ``cron:`` expression, which the minion can
only evaluate with the ``croniter`` Python module installed. These tests
render the real ``salt/baseline/schedule/init.sls`` with a stubbed
pillar and assert the ``python313-croniter`` package is installed and
required by the cron job — in both the enabled and disabled branches
(removing a stale job must not depend on the package being present).

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_init(pillar_schedule):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/schedule/init.sls")
    pillar = {"baseline:schedule": pillar_schedule}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(salt=salt)


def test_cron_job_requires_croniter_package():
    rendered = render_init({})
    assert "- name: python313-croniter" in rendered
    assert "schedule.present:" in rendered
    assert "- pkg: schedule_croniter_package" in rendered


def test_disabled_branches_need_no_package_require():
    rendered = render_init({"enabled": False})
    assert "- name: python313-croniter" in rendered
    assert "schedule.absent:" in rendered
    assert "- pkg: schedule_croniter_package" not in rendered
