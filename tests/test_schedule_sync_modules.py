"""Render tests for the baseline sync-modules schedule job.

Custom execution modules (``trivy_scan`` and friends) only reach minions
via ``saltutil.sync_modules``. Relying on the next highstate leaves a
window where the master serves new module code but minions still run the
old copy, so a daily sync job closes the gap. These tests render the real
``salt/baseline/schedule/init.sls`` and assert the job is present by
default, tunable via pillar, and removed (not left behind) when disabled
— the same contract as the mine/highstate jobs.

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


def test_sync_modules_scheduled_by_default():
    rendered = render_init({})
    assert "baseline_sync_modules:" in rendered
    assert "schedule.present:" in rendered
    assert "- name: sync-modules-daily" in rendered
    assert "- function: saltutil.sync_modules" in rendered
    assert "- days: 1" in rendered


def test_sync_modules_splay_tunable():
    rendered = render_init({"sync_modules": {"splay": 120}})
    assert "- splay: 120" in rendered


def test_sync_modules_removed_when_disabled():
    rendered = render_init({"sync_modules": {"enabled": False}})
    assert "schedule.absent:" in rendered
    assert "- name: sync-modules-daily" in rendered
    assert "- function: saltutil.sync_modules" not in rendered


def test_sync_modules_removed_when_schedule_disabled():
    rendered = render_init({"enabled": False})
    assert "- function: saltutil.sync_modules" not in rendered
