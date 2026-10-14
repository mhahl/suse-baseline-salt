"""Trivy CVE scan summary for the Salt Mine.

Scheduled daily via :func:`publish`, which runs a ``trivy rootfs /``
OS-package scan, caches the full JSON report on the minion, and pushes
a small summary dict to the mine under the ``trivy.scan_summary`` key.
The mine never carries the full report. All behavior is driven by
``baseline:trivy`` in ``pillar/baseline.sls``.

Overstate notes: the mine key and the ``trivy-cve-scan`` job name are
stable contracts — the Schedules tab reads them via ``schedule.list``
and the Mine tab reads ``trivy.scan_summary``. ``publish`` uses
``mine.send`` (not ``mine_functions`` pillar) so no minion restart is
needed, but ``mine.update`` does NOT refresh this key: it lives only
as long as the daily schedule refreshes it (see ``schedule.sls``).

``skip_db_update: True`` means offline scans only — the DB is never
refreshed by this module. Manage it externally (e.g. a separate
``trivy db update`` run) or scans go stale silently.
"""

import datetime as _dt
import json as _json
import os as _os
import subprocess as _subprocess

MINE_KEY = "trivy.scan_summary"

_SEVERITY_RANK = {
    "CRITICAL": 0,
    "HIGH": 1,
    "MEDIUM": 2,
    "LOW": 3,
    "UNKNOWN": 4,
}


def _opt(name, default=None):
    try:
        return __pillar__.get("baseline", {}).get("trivy", {}).get(name, default)  # noqa: F821
    except (AttributeError, NameError):
        return default


def _trivy_bin():
    # Distro packages install /usr/bin/trivy on both Tumbleweed and
    # Fedora. Prefer /usr/local/bin first so a manually pinned binary
    # wins over a stale distro package — scan.sls gates on both paths
    # so the initial scan is not skipped when only one exists.
    for candidate in ("/usr/local/bin/trivy", "/usr/bin/trivy"):
        if _os.path.exists(candidate):
            return candidate
    return "trivy"


def _coerce_top_n(value, default=20):
    """Clamp the mine 'top' list size to 0..100, never raises."""
    try:
        number = int(value)
    except (TypeError, ValueError):
        return default
    return max(0, min(100, number))


def _trivy_version(binpath):
    """Best-effort Trivy and vulnerability-DB versions, never raises."""
    info = {"trivy_version": "", "db_updated_at": ""}
    try:
        proc = _subprocess.run(
            [binpath, "version", "--format", "json"],
            capture_output=True, text=True, timeout=120,
        )
        payload = _json.loads(proc.stdout or "{}")
    except (OSError, ValueError, _subprocess.SubprocessError):
        return info
    if isinstance(payload, dict):
        info["trivy_version"] = str(payload.get("Version", ""))
        db = payload.get("VulnerabilityDB", {})
        if isinstance(db, dict):
            info["db_updated_at"] = str(db.get("UpdatedAt", ""))
    return info


def _summarize(report, severities, top_n):
    """Build the mine-sized summary from a parsed Trivy JSON report."""
    if not isinstance(severities, str):
        severities = "HIGH,CRITICAL"
    top_n = _coerce_top_n(top_n)
    wanted = [s.strip().upper() for s in severities.split(",") if s.strip()]
    counts = {sev: 0 for sev in wanted}
    total = 0
    fixable = 0
    findings = []
    results = report.get("Results", []) if isinstance(report, dict) else []
    for result in results:
        if not isinstance(result, dict):
            continue
        for vuln in result.get("Vulnerabilities", []) or []:
            if not isinstance(vuln, dict):
                continue
            sev = str(vuln.get("Severity", "UNKNOWN")).upper()
            if sev not in counts:
                continue
            counts[sev] += 1
            total += 1
            fixed = str(vuln.get("FixedVersion", "") or "")
            if fixed:
                fixable += 1
            findings.append({
                "cve": str(vuln.get("VulnerabilityID", "")),
                "pkg": str(vuln.get("PkgName", "")),
                "installed": str(vuln.get("InstalledVersion", "")),
                "fixed": fixed,
                "severity": sev,
            })
    findings.sort(key=lambda f: (_SEVERITY_RANK.get(f["severity"], 99),
                                 f["cve"]))
    return {
        "severity_filter": ",".join(wanted),
        "counts": counts,
        "total": total,
        "fixable": fixable,
        "top": findings[:top_n],
    }


def scan(severities=None, top_n=None):
    """Run the Trivy OS scan, cache the full report, return the summary.

    Reads defaults from the ``trivy`` pillar; explicit arguments win.
    ``top_n`` is clamped to 0..100 so the mine payload stays small for
    Overstate's Mine browser. The cached report is chmodded 0640
    best-effort (CVE counts are local-only, not world-readable).
    """
    severities = severities or _opt("severities", "HIGH,CRITICAL")
    top_n = _coerce_top_n(_opt("top_n", 20) if top_n is None else top_n)
    cache_dir = _opt("cache_dir", "/var/cache/trivy") or ""
    default_report = _os.path.join(
        cache_dir, "report.json") if cache_dir else "/var/cache/trivy/report.json"
    report_path = _opt("report_path", default_report) or default_report
    binpath = _trivy_bin()
    cmd = [
        binpath, "rootfs", "/",
        "--scanners", "vuln",
        "--pkg-types", "os",
        "--severity", severities,
        "--format", "json",
        "--output", report_path,
        "--quiet",
    ]
    if cache_dir:
        cmd += ["--cache-dir", _os.path.join(cache_dir, "db")]
    if _opt("skip_db_update", False):
        cmd += ["--skip-db-update"]
    try:
        if cache_dir:
            _os.makedirs(cache_dir, exist_ok=True)
        parent = _os.path.dirname(report_path)
        if parent:
            _os.makedirs(parent, exist_ok=True)
    except OSError as exc:
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "cannot create cache dir for {}: {}".format(
                    report_path, exc)}
    try:
        proc = _subprocess.run(
            cmd, capture_output=True, text=True, timeout=1800,
        )
    except FileNotFoundError:
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "trivy binary not found at {}: apply "
                         "baseline.trivy on this minion - its install step "
                         "failed or never ran".format(binpath)}
    except (OSError, _subprocess.SubprocessError) as exc:
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "scan failed to run: {}".format(exc)}
    if proc.returncode != 0:
        # A leftover report.json from a previous success must not be
        # summarized with a fresh scanned_at — Overstate would show
        # stale CVE counts as a current scan.
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "trivy exited {}".format(proc.returncode),
                "retcode": proc.returncode,
                "stderr_tail": (proc.stderr or "")[-500:]}
    try:
        with open(report_path, encoding="utf-8") as handle:
            report = _json.load(handle)
    except (OSError, ValueError) as exc:
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "unreadable report {}: {}".format(report_path, exc),
                "retcode": proc.returncode,
                "stderr_tail": (proc.stderr or "")[-500:]}
    try:
        _os.chmod(report_path, 0o640)
    except OSError:
        pass
    summary = _summarize(report, severities, top_n)
    summary["minion"] = __grains__.get("id", "")  # noqa: F821
    summary["scanned_at"] = _dt.datetime.now(
        _dt.timezone.utc).isoformat(timespec="seconds")
    summary.update(_trivy_version(binpath))
    return summary


def publish():
    """Run :func:`scan` and push the summary to the mine.

    This is the function the daily schedule calls. Uses ``mine.send``
    so no ``mine_functions`` minion config (and no minion restart) is
    needed; the result lands under the ``trivy.scan_summary`` key.
    """
    return __salt__["mine.send"](  # noqa: F821
        MINE_KEY, mine_function="trivy_scan.scan")
