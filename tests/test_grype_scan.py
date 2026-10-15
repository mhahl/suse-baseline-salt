"""Unit tests for salt/_modules/grype_scan.py.

Pure stdlib + pytest; no Salt runtime needed. The module under test only
touches Salt dunders (``__pillar__``, ``__grains__``, ``__salt__``) inside
function bodies, so it imports cleanly and tests inject plain stubs.
Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

import importlib.util
import json
from pathlib import Path
from unittest import mock

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
MOD_PATH = REPO_ROOT / "salt" / "_modules" / "grype_scan.py"


def load_module(pillar=None, grains=None, salt=None):
    spec = importlib.util.spec_from_file_location("grype_scan", MOD_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.__pillar__ = {"baseline": {"grype": pillar or {}}}
    mod.__grains__ = {"id": "web01", **(grains or {})}
    if salt is not None:
        mod.__salt__ = salt
    return mod


def match(vid, severity, pkg="openssl", installed="3.1.4", fixed=("3.1.5",)):
    return {
        "vulnerability": {
            "id": vid,
            "severity": severity,
            "fix": {"versions": list(fixed), "state": "fixed"},
        },
        "artifact": {"name": pkg, "version": installed},
    }


@pytest.fixture()
def mod():
    return load_module()


def test_summarize_counts_only_wanted_severities(mod):
    report = {"matches": [
        match("CVE-2024-1", "Critical"),
        match("CVE-2024-2", "High"),
        match("CVE-2024-3", "Medium"),
        match("CVE-2024-4", "Low"),
    ]}
    out = mod._summarize(report, "HIGH,CRITICAL", 20)
    assert out["counts"] == {"HIGH": 1, "CRITICAL": 1}
    assert out["total"] == 2
    assert out["fixable"] == 2
    assert out["severity_filter"] == "HIGH,CRITICAL"


def test_summarize_top_sorted_and_limited(mod):
    report = {"matches": [
        match("CVE-2024-9", "High"),
        match("CVE-2024-1", "Critical"),
        match("CVE-2024-2", "Critical", fixed=()),
    ]}
    out = mod._summarize(report, "HIGH,CRITICAL", 2)
    assert [f["cve"] for f in out["top"]] == ["CVE-2024-1", "CVE-2024-2"]
    assert out["fixable"] == 2  # empty versions list is not fixable
    entry = out["top"][0]
    assert entry == {"cve": "CVE-2024-1", "pkg": "openssl",
                     "installed": "3.1.4", "fixed": "3.1.5",
                     "severity": "CRITICAL"}


def test_summarize_skips_malformed_entries(mod):
    report = {"matches": [
        "not-a-dict",
        None,
        {"vulnerability": {"id": "", "severity": "Critical"},
         "artifact": {"name": "x", "version": "1"}},
        {"artifact": {"name": "lonely"}},
        {"NoMatches": True},
    ]}
    out = mod._summarize(report, "HIGH,CRITICAL", 20)
    assert out["total"] == 0
    assert out["top"] == []


def test_summarize_empty_report(mod):
    out = mod._summarize({}, "HIGH,CRITICAL", 20)
    assert out == {"severity_filter": "HIGH,CRITICAL",
                   "counts": {"HIGH": 0, "CRITICAL": 0},
                   "total": 0, "fixable": 0, "top": [],
                   "distro": {}}


def test_summarize_carries_distro(mod):
    report = {"distro": {"name": "fedora", "version": "43"},
              "matches": []}
    out = mod._summarize(report, "HIGH,CRITICAL", 20)
    assert out["distro"] == {"name": "fedora", "version": "43"}


def test_publish_sends_summary_under_mine_key():
    sent = {}

    def fake_send(name, *args, **kwargs):
        sent["name"] = name
        sent["args"] = args
        sent["kwargs"] = kwargs
        return True

    mod = load_module(salt={"mine.send": fake_send})
    mod.scan = lambda *a, **k: {"total": 3}  # noqa: E731 -- stub the scan
    assert mod.publish() is True
    assert sent["name"] == mod.MINE_KEY == "grype.scan_summary"
    assert sent["kwargs"] == {"mine_function": "grype_scan.scan"}


def test_grype_version_parses_and_fails_soft(mod):
    version_proc = mock.Mock(stdout=json.dumps({"version": "v0.120.1"}))
    status_proc = mock.Mock(stdout=json.dumps({"built": "2026-10-01T00:00:00Z"}))

    def fake_run(cmd, **kwargs):
        if cmd[1:2] == ["version"]:
            return version_proc
        return status_proc

    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        assert mod._grype_version("grype") == {
            "grype_version": "v0.120.1",
            "db_built_at": "2026-10-01T00:00:00Z"}
    with mock.patch.object(mod._subprocess, "run", side_effect=OSError):
        assert mod._grype_version("grype") == {
            "grype_version": "", "db_built_at": ""}


def test_scan_builds_dir_scan_command_and_caches_report(tmp_path):
    report = {"matches": [match("CVE-2024-1", "Critical")]}
    report_file = tmp_path / "report.json"
    report_file.write_text(json.dumps(report), encoding="utf-8")

    seen = {}

    def fake_run(cmd, **kwargs):
        if cmd[1:2] == ["version"]:
            return mock.Mock(returncode=0, stdout=json.dumps(
                {"version": "v0.120.1"}), stderr="")
        if cmd[1:2] == ["db"]:
            return mock.Mock(returncode=0, stdout=json.dumps(
                {"built": "2026-10-01T00:00:00Z"}), stderr="")
        seen["cmd"] = cmd
        seen["env"] = kwargs.get("env", {})
        assert cmd[1] == "dir:/"
        assert "-o" in cmd and "json" in cmd
        assert "--by-cve" in cmd
        # The module writes the report itself via --file; emulate grype.
        return mock.Mock(returncode=0, stdout="", stderr="")

    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(report_file),
                              "severities": "CRITICAL",
                              "top_n": 5})
    mod._grype_bin = lambda: "/usr/local/bin/grype"  # noqa: E731 -- stub
    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        out = mod.scan()
    assert seen["cmd"][seen["cmd"].index("--file") + 1] == str(report_file)
    assert seen["env"].get("GRYPE_DB_CACHE_DIR") == str(tmp_path / "db")
    assert out["total"] == 1 and out["minion"] == "web01"
    assert "scanned_at" in out and out["top"][0]["cve"] == "CVE-2024-1"
    assert out["grype_version"] == "v0.120.1"


def test_scan_skip_db_update_disables_auto_update(tmp_path):
    report_file = tmp_path / "report.json"
    report_file.write_text(json.dumps({"matches": []}), encoding="utf-8")
    seen = {}

    def fake_run(cmd, **kwargs):
        if cmd[1:2] in (["version"], ["db"]):
            return mock.Mock(returncode=0, stdout="{}", stderr="")
        seen["env"] = kwargs.get("env", {})
        return mock.Mock(returncode=0, stdout="", stderr="")

    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(report_file),
                              "skip_db_update": True})
    mod._grype_bin = lambda: "/usr/local/bin/grype"  # noqa: E731 -- stub
    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        mod.scan()
    assert seen["env"].get("GRYPE_DB_AUTO_UPDATE") == "false"


def test_grype_bin_prefers_managed_path(mod):
    with mock.patch.object(mod._os.path, "exists", return_value=True):
        assert mod._grype_bin() == "/usr/local/bin/grype"
    with mock.patch.object(mod._os.path, "exists", return_value=False):
        assert mod._grype_bin() == "grype"


def test_scan_failed_run_does_not_republish_stale_report(tmp_path):
    report = {"matches": [match("CVE-2024-1", "Critical")]}
    report_file = tmp_path / "report.json"
    report_file.write_text(json.dumps(report), encoding="utf-8")

    def fake_run(cmd, **kwargs):
        return mock.Mock(returncode=1, stdout="", stderr="db update failed")

    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(report_file)})
    mod._grype_bin = lambda: "/usr/local/bin/grype"  # noqa: E731 -- stub
    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        out = mod.scan()
    assert out["minion"] == "web01"
    assert "grype exited 1" in out["error"]
    assert "total" not in out
    assert "top" not in out
    assert "scanned_at" not in out
    assert "db update failed" in out["stderr_tail"]


def test_scan_missing_binary_names_the_fix(tmp_path):
    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(tmp_path / "report.json")})
    mod._grype_bin = lambda: "/nonexistent/grype"  # noqa: E731 -- no binary
    out = mod.scan()
    assert out["minion"] == "web01"
    assert "baseline.grype" in out["error"]
    assert "grype" in out["error"]


def test_coerce_top_n_clamps_for_mine(mod):
    assert mod._coerce_top_n(5) == 5
    assert mod._coerce_top_n(0) == 0
    assert mod._coerce_top_n(999) == 100
    assert mod._coerce_top_n(-3) == 0
    assert mod._coerce_top_n("bad") == 20
    assert mod._coerce_top_n(None) == 20


def test_scan_creates_nested_report_parent_and_restricts_perms(tmp_path):
    report = {"matches": [match("CVE-2024-1", "Critical")]}
    nested = tmp_path / "nested" / "deep" / "report.json"

    def fake_run(cmd, **kwargs):
        if cmd[1:2] == ["version"]:
            return mock.Mock(returncode=0, stdout=json.dumps(
                {"version": "v0.120.1"}), stderr="")
        if cmd[1:2] == ["db"]:
            return mock.Mock(returncode=0, stdout="{}", stderr="")
        # Emulate grype writing the report to --file.
        out_idx = cmd.index("--file") + 1
        Path(cmd[out_idx]).write_text(json.dumps(report), encoding="utf-8")
        return mock.Mock(returncode=0, stdout="", stderr="")

    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(nested)})
    mod._grype_bin = lambda: "/usr/local/bin/grype"  # noqa: E731 -- stub
    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        out = mod.scan()
    assert out["total"] == 1
    assert nested.exists()
    assert oct(nested.stat().st_mode & 0o777) == "0o640"


def test_scan_empty_cache_dir_uses_default_db_env(tmp_path):
    report_file = tmp_path / "report.json"
    report_file.write_text(json.dumps({"matches": []}), encoding="utf-8")
    seen = {}

    def fake_run(cmd, **kwargs):
        if cmd[1:2] in (["version"], ["db"]):
            return mock.Mock(returncode=0, stdout="{}", stderr="")
        seen["env"] = kwargs.get("env", {})
        return mock.Mock(returncode=0, stdout="", stderr="")

    mod = load_module(pillar={"cache_dir": "",
                              "report_path": str(report_file)})
    mod._grype_bin = lambda: "/usr/local/bin/grype"  # noqa: E731 -- stub
    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        out = mod.scan()
    assert "GRYPE_DB_CACHE_DIR" not in seen["env"]
    assert out["total"] == 0
