"""Layout tests for the sectioned baseline + overstate pillars.

pillar/baseline.sls aggregates pillar/baseline/*.sls; pillar/overstate.sls
aggregates pillar/overstate/*.sls. Each section owns exactly one
top-level fragment (baseline:<section>, overstate:<section>, or root
mine_functions) with a banner documenting WHY, CONSUMED BY, and EXAMPLE.
Grype lives under overstate: (decoupled, reusable without baseline);
legacy baseline:grype pillar still merges as a fallback in code.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
PILLAR_ROOT = REPO_ROOT / "pillar"
SECTION_DIR = PILLAR_ROOT / "baseline"

# pillar.get keys read by salt/baseline/* (grep pillar.get in salt/).
EXPECTED_BASELINE_KEYS = {
    "systemd_resolved",
    "ntp",
    "updates",
    "usb",
    "schedule",
    "freeipa",
    "netbird",
    "minion",
    "proxy",
}

# pillar.get keys read by salt/overstate/*.
EXPECTED_OVERSTATE_KEYS = {
    "grype",
}


def _load(path):
    return yaml.safe_load(path.read_text()) or {}


def test_aggregator_includes_resolve_to_files():
    for agg_name, section in (("baseline.sls", "baseline"), ("overstate.sls", "overstate")):
        agg = _load(PILLAR_ROOT / agg_name)
        includes = agg.get("include", [])
        assert includes, "{} must include section files".format(agg_name)
        for entry in includes:
            assert entry.startswith(section + "."), entry
            target = PILLAR_ROOT / section / (entry.split(".", 1)[1] + ".sls")
            assert target.is_file(), "include {} -> missing {}".format(entry, target)


def test_every_state_key_has_a_section():
    found = set()
    for path in sorted(SECTION_DIR.glob("*.sls")):
        data = _load(path)
        baseline = data.get("baseline", {})
        if isinstance(baseline, dict):
            found.update(baseline.keys())
    missing = EXPECTED_BASELINE_KEYS - found
    assert not missing, "no section file defines: {}".format(sorted(missing))
    assert "grype" not in found, "grype must live under overstate:, not baseline:"
    over_found = set()
    for path in sorted((PILLAR_ROOT / "overstate").glob("*.sls")):
        data = _load(path)
        overstate = data.get("overstate", {})
        if isinstance(overstate, dict):
            over_found.update(overstate.keys())
    assert EXPECTED_OVERSTATE_KEYS <= over_found


def test_sections_own_exactly_one_fragment():
    for path in sorted(SECTION_DIR.glob("*.sls")):
        data = _load(path)
        assert isinstance(data, dict), path.name
        if path.name == "10-mine.sls":
            assert "mine_functions" in data, "mine section must define mine_functions"
            assert "baseline" not in data, "mine section must not nest under baseline:"
            continue
        assert "mine_functions" not in data, "{} must not define root mine_functions".format(path.name)
        baseline = data.get("baseline")
        assert isinstance(baseline, dict) and len(baseline) == 1, \
            "{} must own exactly one baseline:<section> key".format(path.name)


def test_mine_functions_at_root_with_expected_functions():
    data = _load(SECTION_DIR / "10-mine.sls")
    mine = data.get("mine_functions", {})
    assert "grains.items" in mine
    assert "network.ip_addrs" in mine


def test_join_secrets_default_to_empty_placeholders():
    freeipa = _load(SECTION_DIR / "06-freeipa.sls")["baseline"]["freeipa"]["join"]
    assert freeipa["enabled"] is False
    assert freeipa["password"] == ""
    netbird = _load(SECTION_DIR / "07-netbird.sls")["baseline"]["netbird"]["join"]
    assert netbird["enabled"] is False
    assert netbird["setup_key"] == ""


def test_section_files_carry_banners():
    for path in sorted(SECTION_DIR.glob("*.sls")):
        text = path.read_text()
        assert "WHY:" in text, "{} missing WHY banner".format(path.name)
        assert "CONSUMED BY:" in text, "{} missing CONSUMED BY banner".format(path.name)
        assert "EXAMPLE" in text, "{} missing EXAMPLE banner".format(path.name)
    for path in sorted((PILLAR_ROOT / "overstate").glob("*.sls")):
        text = path.read_text()
        assert "WHY:" in text, "{} missing WHY banner".format(path.name)
        assert "CONSUMED BY:" in text, "{} missing CONSUMED BY banner".format(path.name)
        assert "EXAMPLE" in text, "{} missing EXAMPLE banner".format(path.name)


def test_overstate_grype_defaults():
    data = _load(PILLAR_ROOT / "overstate" / "01-grype.sls")
    grype = data["overstate"]["grype"]
    assert grype["version"].startswith("v")
    assert "amd64" in grype["hashes"]


def test_top_serves_baseline_and_overstate_by_default():
    data = _load(PILLAR_ROOT / "top.sls")
    served = data.get("base", {}).get("*", [])
    assert "baseline" in served
    assert "overstate" in served
    # Secrets overlays are per-fleet opt-in (commented until the
    # ciphertext file exists) — never served by default.
    assert not any(str(entry).startswith("secrets.") for entry in served)


def test_secrets_example_scaffold_is_unloadable_template():
    example = PILLAR_ROOT / "secrets" / "prod.sls.example"
    assert example.is_file()
    text = example.read_text()
    assert "#!yaml|gpg" in text
    assert "baseline:" in text
    assert "PASTE-GPG-CIPHERTEXT" in text
    # The .example suffix means Salt never loads it — only the real
    # prod.sls (ciphertext) is rendered when targeted in top.sls.
    assert example.suffix == ".example"


def test_committed_secret_files_must_be_encrypted():
    for path in sorted((PILLAR_ROOT / "secrets").glob("*.sls")):
        first = path.read_text().splitlines()[0].strip()
        assert first == "#!yaml|gpg", \
            "{} holds real pillar data and must be GPG-encrypted".format(path.name)


def test_master_gpg_example_exists():
    example = REPO_ROOT / "master.d" / "gpg.conf.example"
    assert example.is_file()
    assert "gpg_keydir" in example.read_text()
