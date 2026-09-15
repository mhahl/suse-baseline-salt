"""overstate-checkout keeps the Overstate file-roots dir a real git checkout.

Overstate's Sync now button (and scripts/sync-file-roots.sh) runs
``git fetch`` + ``git pull --ff-only`` on FILE_ROOTS, which refuses
anything that is not a checkout with an upstream: plain copies made by
``make overstate-deploy`` report "not a git checkout". These tests run
the Makefile target against a local source repo (no network) and assert
the deployed dir satisfies the whole sync contract:

- ``.git`` present, upstream tracking set, tree clean
- full ``salt/`` + ``pillar/`` trees with top files
- world-readable bits (``a+rX``) so the non-root master workers that
  read the bind mount can traverse the tree
- re-running pulls new upstream commits (the sync path), still clean

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

import os
import stat
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
MAKE = ["make", "--no-print-directory", "-C", str(REPO_ROOT)]


def _git(*args, cwd):
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True,
    )


@pytest.fixture()
def source_repo(tmp_path):
    """A minimal states repo standing in for origin."""
    src = tmp_path / "src"
    (src / "salt" / "baseline").mkdir(parents=True)
    (src / "pillar").mkdir(parents=True)
    (src / "salt" / "top.sls").write_text("base:\n  '*':\n    - baseline\n")
    (src / "salt" / "baseline" / "init.sls").write_text("baseline:\n  test.nop: []\n")
    (src / "pillar" / "top.sls").write_text("base:\n  '*':\n    - baseline\n")
    (src / "pillar" / "baseline.sls").write_text("baseline: {}\n")
    _git("init", "-b", "main", cwd=src)
    _git("config", "user.email", "test@example.com", cwd=src)
    _git("config", "user.name", "test", cwd=src)
    _git("add", "-A", cwd=src)
    _git("commit", "-m", "seed", cwd=src)
    return src


def _checkout(source_repo, srv, **overrides):
    env = dict(os.environ)
    env["OVERSTATE_SRV"] = str(srv)
    env["OVERSTATE_REPO"] = str(source_repo)
    env["OVERSTATE_BRANCH"] = "main"
    env.update(overrides)
    return subprocess.run(
        [*MAKE, "overstate-checkout"],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def test_checkout_creates_tracking_checkout(source_repo, tmp_path):
    srv = tmp_path / "srv"
    proc = _checkout(source_repo, srv)
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert (srv / ".git").is_dir()
    upstream = _git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}", cwd=srv)
    assert upstream.stdout.strip() == "origin/main"
    porcelain = _git("status", "--porcelain", cwd=srv)
    assert porcelain.stdout.strip() == ""
    assert (srv / "salt" / "baseline" / "init.sls").is_file()
    assert (srv / "salt" / "top.sls").is_file()
    assert (srv / "pillar" / "baseline.sls").is_file()
    assert "owner:" in proc.stdout, "target must report checkout ownership"


def test_checkout_is_world_readable(source_repo, tmp_path):
    srv = tmp_path / "srv"
    proc = _checkout(source_repo, srv)
    assert proc.returncode == 0, proc.stderr or proc.stdout
    target = srv / "salt" / "baseline" / "init.sls"
    mode = target.stat().st_mode
    assert mode & stat.S_IROTH, "master workers need o+r on files"
    assert (srv / "salt").stat().st_mode & stat.S_IXOTH, "o+x on dirs"


def test_recheckout_pulls_new_commits(source_repo, tmp_path):
    srv = tmp_path / "srv"
    assert _checkout(source_repo, srv).returncode == 0
    (source_repo / "salt" / "baseline" / "extra.sls").write_text("x:\n  test.nop: []\n")
    _git("add", "-A", cwd=source_repo)
    _git("commit", "-m", "extra", cwd=source_repo)
    proc = _checkout(source_repo, srv)
    assert proc.returncode == 0, proc.stderr or proc.stdout
    assert (srv / "salt" / "baseline" / "extra.sls").is_file()
    head = _git("rev-parse", "HEAD", cwd=srv)
    origin = _git("rev-parse", "HEAD", cwd=source_repo)
    assert head.stdout.strip() == origin.stdout.strip()
    porcelain = _git("status", "--porcelain", cwd=srv)
    assert porcelain.stdout.strip() == ""


def test_nonempty_non_checkout_refuses(source_repo, tmp_path):
    srv = tmp_path / "srv"
    (srv / "salt").mkdir(parents=True)
    (srv / "salt" / "legacy.sls").write_text("untracked local file\n")
    proc = _checkout(source_repo, srv)
    assert proc.returncode != 0
    assert "not a git checkout" in (proc.stdout + proc.stderr).lower()
    assert (srv / "salt" / "legacy.sls").is_file(), "refusal must change nothing"
