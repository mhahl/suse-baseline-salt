"""Render tests for the reactor/ examples.

Each example renders its action only for the event it owns and nothing
otherwise (reactor no-op): allowlisted services for service.sls,
baseline-owned or watched paths for inotify.sls, over-threshold usage
for diskspace.sls. These tests render the real files with representative
beacon event payloads — confirm the exact live tags/fields with
``salt-run state.event pretty=True`` before enforcing on a master.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]


def render_reactor(name, data):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(REPO_ROOT)),
        keep_trailing_newline=True,
    )
    return env.get_template("reactor/{}".format(name)).render(data=data)


def test_service_restarts_allowlisted_daemon_when_down():
    out = render_reactor("service.sls", {
        "id": "host1", "service_name": "systemd-timesyncd", "state": False,
    })
    assert "local_service.start:" in out
    assert "- tgt: host1" in out
    assert "- systemd-timesyncd" in out


def test_service_ignores_running_and_unknown_services():
    running = render_reactor("service.sls", {
        "id": "host1", "service_name": "systemd-resolved", "state": True,
    })
    assert "local_service.start:" not in running
    unknown = render_reactor("service.sls", {
        "id": "host1", "service_name": "cron", "state": False,
    })
    assert "local_service.start:" not in unknown
    assert render_reactor("service.sls", {"id": "host1"}).strip() == ""


def test_inotify_reapplies_owning_module():
    out = render_reactor("inotify.sls", {
        "id": "host1", "path": "/etc/zypp/zypp.conf", "change": "modify",
    })
    assert "local_state.apply:" in out
    assert "- tgt: host1" in out
    assert "- baseline.updates" in out
    assert "local_cmd.run:" not in out


def test_inotify_audit_logs_watched_non_baseline_paths():
    out = render_reactor("inotify.sls", {
        "id": "host1", "path": "/etc/shadow", "change": "attrib",
    })
    assert "local_state.apply:" not in out
    assert "local_cmd.run:" in out
    assert "salt-reactor" in out
    assert "/etc/shadow" in out


def test_inotify_audit_logs_unlisted_paths_and_ignores_empty():
    out = render_reactor("inotify.sls", {"id": "host1", "path": "/tmp/noise"})
    assert "local_state.apply:" not in out
    assert "local_cmd.run:" in out
    assert render_reactor("inotify.sls", {"id": "host1"}).strip() == ""


def test_diskspace_cleans_only_over_threshold():
    over = render_reactor("diskspace.sls", {"id": "host1", "usage": 90})
    assert "journalctl --vacuum-size=500M" in over
    assert "zypper --non-interactive clean --all" in over
    assert "- tgt: host1" in over
    assert "local_cmd.run:" not in render_reactor(
        "diskspace.sls", {"id": "host1", "usage": 40})
    # Percent-string payloads and missing fields still act: the beacon
    # only fires over threshold.
    assert "local_cmd.run:" in render_reactor(
        "diskspace.sls", {"id": "host1", "usage": "87%"})
    assert "local_cmd.run:" in render_reactor(
        "diskspace.sls", {"id": "host1"})


def test_reactor_conf_wires_all_examples():
    conf = (REPO_ROOT / "reactor" / "reactor.conf.example").read_text()
    assert "salt/beacon/*/service/*" in conf
    assert "salt/beacon/*/inotify/*" in conf
    assert "salt/beacon/*/diskspace/*" in conf
    assert "salt://service.sls" in conf
    assert "salt://inotify.sls" in conf
    assert "salt://diskspace.sls" in conf
    assert "/var/lib/overstate/srv/reactor" in conf
