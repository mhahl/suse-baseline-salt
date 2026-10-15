"""Grype CVE scan summary for the Salt Mine.

Scheduled daily via :func:`publish`, which runs a ``grype dir:/``
OS/filesystem scan, caches the full JSON report on the minion, and pushes
a small summary dict to the mine under the ``grype.scan_summary`` key.
The mine never carries the full report. All behavior is driven by
``baseline:grype`` in ``pillar/baseline.sls``.

Overstate notes: the mine key and the ``grype-cve-scan`` job name are
stable contracts — the Schedules tab reads them via ``schedule.list``
and the Mine tab reads ``grype.scan_summary``. ``publish`` uses
``mine.send`` (not ``mine_functions`` pillar) so no minion restart is
needed, but ``mine.update`` does NOT refresh this key: it lives only
as long as the daily schedule refreshes it (see ``schedule.sls``).

``skip_db_update: True`` means offline scans only — the DB is never
refreshed by this module. Manage it externally (e.g. ``grype db update``)
or scans go stale silently. The DB cache lives under
``<cache_dir>/db`` via ``GRYPE_DB_CACHE_DIR``.
"""

import datetime as _dt
import json as _json
import os as _os
import subprocess as _subprocess

MINE_KEY = "grype.scan_summary"

_SEVERITY_RANK = {
    "CRITICAL": 0,
    "HIGH": 1,
    "MEDIUM": 2,
    "LOW": 3,
    "NEGLIGIBLE": 4,
    "UNKNOWN": 5,
}


def _opt(name, default=None):
    try:
        return __pillar__.get("baseline", {}).get("grype", {}).get(name, default)  # noqa: F821
    except (AttributeError, NameError):
        return default


def _grype_bin():
    # GitHub releases install to /usr/local/bin/grype (see
    # baseline/grype/install.sls). No distro package exists on either
    # platform, so there is a single canonical path plus PATH fallback.
    if _os.path.exists("/usr/local/bin/grype"):
        return "/usr/local/bin/grype"
    return "grype"


def _coerce_top_n(value, default=20):
    """Clamp the mine 'top' list size to 0..100, never raises."""
    try:
        number = int(value)
    except (TypeError, ValueError):
        return default
    return max(0, min(100, number))


def _grype_version(binpath, env=None):
    """Best-effort Grype and vulnerability-DB versions, never raises."""
    info = {"grype_version": "", "db_built_at": ""}
    try:
        proc = _subprocess.run(
            [binpath, "version", "-o", "json"],
            capture_output=True, text=True, timeout=120, env=env,
        )
        payload = _json.loads(proc.stdout or "{}")
    except (OSError, ValueError, _subprocess.SubprocessError):
        payload = None
    if isinstance(payload, dict):
        for key in ("version", "Version"):
            if payload.get(key):
                info["grype_version"] = str(payload[key])
                break
    try:
        proc = _subprocess.run(
            [binpath, "db", "status", "-o", "json"],
            capture_output=True, text=True, timeout=120, env=env,
        )
        status = _json.loads(proc.stdout or "{}")
    except (OSError, ValueError, _subprocess.SubprocessError):
        return info
    info["db_built_at"] = _parse_db_built(status)
    return info


def _parse_db_built(status):
    """Extract a build timestamp from `grype db status -o json` shapes."""
    candidates = []
    if isinstance(status, dict):
        candidates.append(status)
        for key in ("db", "database", "status"):
            nested = status.get(key)
            if isinstance(nested, dict):
                candidates.append(nested)
            elif isinstance(nested, list):
                candidates.extend(
                    [i for i in nested if isinstance(i, dict)])
    elif isinstance(status, list):
        candidates.extend([i for i in status if isinstance(i, dict)])
    for item in candidates:
        for key in ("built", "Built", "updatedAt", "UpdatedAt",
                    "buildTimestamp", "published"):
            if item.get(key):
                return str(item[key])
    return ""


def _summarize(report, severities, top_n):
    """Build the mine-sized summary from a parsed Grype JSON report."""
    if not isinstance(severities, str):
        severities = "HIGH,CRITICAL"
    top_n = _coerce_top_n(top_n)
    wanted = [s.strip().upper() for s in severities.split(",") if s.strip()]
    counts = {sev: 0 for sev in wanted}
    total = 0
    fixable = 0
    findings = []
    distro = {}
    if isinstance(report, dict):
        raw_distro = report.get("distro")
        if isinstance(raw_distro, dict):
            distro = {"name": str(raw_distro.get("name", "")),
                      "version": str(raw_distro.get("version", ""))}
        matches = report.get("matches", [])
    else:
        matches = []
    for match in matches if isinstance(matches, list) else []:
        if not isinstance(match, dict):
            continue
        vuln = match.get("vulnerability")
        artifact = match.get("artifact")
        if not isinstance(vuln, dict) or not isinstance(artifact, dict):
            continue
        sev = str(vuln.get("severity", "UNKNOWN")).upper()
        if sev not in counts:
            continue
        vuln_id = str(vuln.get("id", ""))
        if not vuln_id:
            continue
        counts[sev] += 1
        total += 1
        fix = vuln.get("fix") or {}
        versions = fix.get("versions") if isinstance(fix, dict) else None
        fixed_list = [str(v) for v in versions
                      if str(v)] if isinstance(versions, list) else []
        fixed = ",".join(fixed_list)
        if fixed:
            fixable += 1
        findings.append({
            "cve": vuln_id,
            "pkg": str(artifact.get("name", "")),
            "installed": str(artifact.get("version", "")),
            "fixed": fixed,
            "severity": sev,
            "namespace": str(vuln.get("namespace", "")),
            "urls": [str(u) for u in vuln.get("urls", [])
                     if str(u)] if isinstance(vuln.get("urls"), list) else [],
        })
    findings.sort(key=lambda f: (_SEVERITY_RANK.get(f["severity"], 99),
                                 f["cve"]))
    slim_keys = ("cve", "pkg", "installed", "fixed", "severity")
    return {
        "severity_filter": ",".join(wanted),
        "counts": counts,
        "total": total,
        "fixable": fixable,
        "top": [{k: f[k] for k in slim_keys}
                for f in findings[:top_n]],
        "distro": distro,
        "detailed_report": findings,
    }


def _scan_env(cache_dir, skip_db_update):
    env = dict(_os.environ)
    if cache_dir:
        env["GRYPE_DB_CACHE_DIR"] = _os.path.join(cache_dir, "db")
    env["GRYPE_DB_AUTO_UPDATE"] = "false" if skip_db_update else "true"
    return env


def scan(severities=None, top_n=None):
    """Run the Grype filesystem scan, cache the full report, return everything.

    Reads defaults from the ``grype`` pillar; explicit arguments win.
    ``top_n`` is clamped to 0..100 so the mine payload stays small for
    Overstate's Mine browser. The cached report is chmodded 0640
    best-effort (CVE counts are local-only, not world-readable).
    Severity filtering happens in :func:`_summarize` — Grype has no
    server-side severity flag, so the CLI always scans everything and
    the mine keeps only the wanted severities.

    The return holds a slim ``top`` list plus a full ``detailed_report``
    list (every wanted finding, with namespace/urls for triage).
    :func:`publish` strips ``detailed_report`` before pushing to the
    mine — a 1000-finding host would otherwise push ~200KB per minion
    into the shared mine on every run. Read the detail on demand via
    ``grype_scan.scan`` (Overstate Jobs → job return).
    """
    severities = severities or _opt("severities", "HIGH,CRITICAL")
    top_n = _coerce_top_n(_opt("top_n", 20) if top_n is None else top_n)
    cache_dir = _opt("cache_dir", "/var/cache/grype") or ""
    default_report = _os.path.join(
        cache_dir, "report.json") if cache_dir else "/var/cache/grype/report.json"
    report_path = _opt("report_path", default_report) or default_report
    skip_db_update = bool(_opt("skip_db_update", False))
    binpath = _grype_bin()
    env = _scan_env(cache_dir, skip_db_update)
    cmd = [
        binpath, "dir:/",
        "-o", "json",
        "--file", report_path,
        "--by-cve",
        "-q",
    ]
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
            cmd, capture_output=True, text=True, timeout=1800, env=env,
        )
    except FileNotFoundError:
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "grype binary not found at {}: apply "
                         "baseline.grype on this minion - its install step "
                         "failed or never ran".format(binpath)}
    except (OSError, _subprocess.SubprocessError) as exc:
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "scan failed to run: {}".format(exc)}
    if proc.returncode != 0:
        # A leftover report.json from a previous success must not be
        # summarized with a fresh scanned_at — Overstate would show
        # stale CVE counts as a current scan.
        return {"minion": __grains__.get("id", ""),  # noqa: F821
                "error": "grype exited {}".format(proc.returncode),
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
    summary["report_path"] = report_path
    summary.update(_grype_version(binpath, env=env))
    return summary


def publish():
    """Run :func:`scan` and push the slim summary to the mine.

    This is the function the daily schedule calls. Uses ``mine.send``
    with inline data (not ``mine_function``) so the bulky
    ``detailed_report`` list is stripped first — the mine keeps counts,
    the ``top`` list and metadata only. Needs no ``mine_functions``
    minion config (and no minion restart); the result lands under the
    ``grype.scan_summary`` key.
    """
    result = scan()
    result.pop("detailed_report", None)
    return __salt__["mine.send"](MINE_KEY, result)  # noqa: F821
