"""Unit tests for salt/_modules/trivy_scan.py.

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
MOD_PATH = REPO_ROOT / "salt" / "_modules" / "trivy_scan.py"


def load_module(pillar=None, grains=None, salt=None):
    spec = importlib.util.spec_from_file_location("trivy_scan", MOD_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.__pillar__ = {"baseline": {"trivy": pillar or {}}}
    mod.__grains__ = {"id": "web01", **(grains or {})}
    if salt is not None:
        mod.__salt__ = salt
    return mod


def vuln(vid, severity, pkg="openssl", installed="3.1.4", fixed="3.1.5"):
    return {
        "VulnerabilityID": vid,
        "PkgName": pkg,
        "InstalledVersion": installed,
        "FixedVersion": fixed,
        "Severity": severity,
    }


@pytest.fixture()
def mod():
    return load_module()


def test_summarize_counts_only_wanted_severities(mod):
    report = {"Results": [{"Vulnerabilities": [
        vuln("CVE-2024-1", "CRITICAL"),
        vuln("CVE-2024-2", "HIGH"),
        vuln("CVE-2024-3", "MEDIUM"),
        vuln("CVE-2024-4", "LOW"),
    ]}]}
    out = mod._summarize(report, "HIGH,CRITICAL", 20)
    assert out["counts"] == {"HIGH": 1, "CRITICAL": 1}
    assert out["total"] == 2
    assert out["fixable"] == 2
    assert out["severity_filter"] == "HIGH,CRITICAL"


def test_summarize_top_sorted_and_limited(mod):
    report = {"Results": [{"Vulnerabilities": [
        vuln("CVE-2024-9", "HIGH"),
        vuln("CVE-2024-1", "CRITICAL"),
        vuln("CVE-2024-2", "CRITICAL", fixed=""),
    ]}]}
    out = mod._summarize(report, "HIGH,CRITICAL", 2)
    assert [f["cve"] for f in out["top"]] == ["CVE-2024-1", "CVE-2024-2"]
    assert out["fixable"] == 2  # empty FixedVersion is not fixable
    entry = out["top"][0]
    assert entry == {"cve": "CVE-2024-1", "pkg": "openssl",
                     "installed": "3.1.4", "fixed": "3.1.5",
                     "severity": "CRITICAL"}


def test_summarize_skips_malformed_entries(mod):
    report = {"Results": [
        "not-a-dict",
        {"Vulnerabilities": [None, "x", {"PkgName": "lonely"}]},
        {"NoVulns": True},
    ]}
    out = mod._summarize(report, "HIGH,CRITICAL", 20)
    assert out["total"] == 0
    assert out["top"] == []


def test_summarize_empty_report(mod):
    out = mod._summarize({}, "HIGH,CRITICAL", 20)
    assert out == {"severity_filter": "HIGH,CRITICAL",
                   "counts": {"HIGH": 0, "CRITICAL": 0},
                   "total": 0, "fixable": 0, "top": []}


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
    assert sent["name"] == mod.MINE_KEY == "trivy.scan_summary"
    assert sent["kwargs"] == {"mine_function": "trivy_scan.scan"}


def test_trivy_version_parses_and_fails_soft(mod):
    payload = {"Version": "0.74.0",
               "VulnerabilityDB": {"UpdatedAt": "2026-08-14T11:00:00Z"}}
    proc = mock.Mock(stdout=json.dumps(payload))
    with mock.patch.object(mod._subprocess, "run", return_value=proc):
        assert mod._trivy_version("trivy") == {
            "trivy_version": "0.74.0",
            "db_updated_at": "2026-08-14T11:00:00Z"}
    with mock.patch.object(mod._subprocess, "run", side_effect=OSError):
        assert mod._trivy_version("trivy") == {
            "trivy_version": "", "db_updated_at": ""}


def test_scan_builds_os_scan_command_and_caches_report(tmp_path):
    report = {"Results": [{"Vulnerabilities": [vuln("CVE-2024-1", "CRITICAL")]}]}
    report_file = tmp_path / "report.json"
    report_file.write_text(json.dumps(report), encoding="utf-8")

    seen = {}

    def fake_run(cmd, **kwargs):
        if cmd[1:2] == ["version"]:
            return mock.Mock(
                returncode=0, stdout=json.dumps(
                    {"Version": "0.74.0", "VulnerabilityDB":
                     {"UpdatedAt": "2026-08-14T11:00:00Z"}}), stderr="")
        seen["cmd"] = cmd
        assert "--pkg-types" in cmd and "os" in cmd
        assert "--scanners" in cmd and "vuln" in cmd
        # The module writes the report itself via --output; emulate trivy.
        return mock.Mock(returncode=0, stdout="", stderr="")

    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(report_file),
                              "severities": "CRITICAL",
                              "top_n": 5,
                              "skip_db_update": True})
    mod._trivy_bin = lambda: "/usr/bin/trivy"  # noqa: E731 -- stub lookup
    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        out = mod.scan()
    assert "--skip-db-update" in seen["cmd"]
    assert "--severity" in seen["cmd"]
    assert seen["cmd"][seen["cmd"].index("--severity") + 1] == "CRITICAL"
    assert out["total"] == 1 and out["minion"] == "web01"
    assert "scanned_at" in out and out["top"][0]["cve"] == "CVE-2024-1"
    assert out["trivy_version"] == "0.74.0"


def test_trivy_bin_prefers_managed_path(mod):
    with mock.patch.object(mod._os.path, "exists", return_value=True):
        assert mod._trivy_bin() == "/usr/local/bin/trivy"
    with mock.patch.object(
        mod._os.path, "exists",
        side_effect=lambda p: p == "/usr/bin/trivy",
    ):
        assert mod._trivy_bin() == "/usr/bin/trivy"
    with mock.patch.object(mod._os.path, "exists", return_value=False):
        assert mod._trivy_bin() == "trivy"


def test_scan_failed_run_does_not_republish_stale_report(tmp_path):
    report = {"Results": [{"Vulnerabilities": [vuln("CVE-2024-1", "CRITICAL")]}]}
    report_file = tmp_path / "report.json"
    report_file.write_text(json.dumps(report), encoding="utf-8")

    def fake_run(cmd, **kwargs):
        return mock.Mock(returncode=1, stdout="", stderr="db update failed")

    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(report_file)})
    mod._trivy_bin = lambda: "/usr/bin/trivy"  # noqa: E731 -- stub lookup
    with mock.patch.object(mod._subprocess, "run", side_effect=fake_run):
        out = mod.scan()
    assert out["minion"] == "web01"
    assert "trivy exited 1" in out["error"]
    assert "total" not in out
    assert "top" not in out
    assert "scanned_at" not in out
    assert "db update failed" in out["stderr_tail"]


def test_scan_missing_binary_names_the_fix(tmp_path):
    mod = load_module(pillar={"cache_dir": str(tmp_path),
                              "report_path": str(tmp_path / "report.json")})
    mod._trivy_bin = lambda: "/nonexistent/trivy"  # noqa: E731 -- no binary
    out = mod.scan()
    assert out["minion"] == "web01"
    assert "baseline.trivy" in out["error"]
    assert "trivy" in out["error"]
