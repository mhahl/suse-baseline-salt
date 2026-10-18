"""Render tests for baseline.proxy egress proxy configuration.

Empty pillar values mean direct connection (stale proxy lines are
deleted, never left behind). Non-empty values are written additively:
existing unrelated lines are preserved. /etc/sysconfig/proxy is
Suse-only (zypper reads PROXY_* natively); /etc/dnf/dnf.conf proxy= is
RedHat-only. Recurring commands (updates, grype) additionally get
per-command env: so they work without a minion restart.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_proxy(pillar_proxy, grains=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
        extensions=["jinja2.ext.do"],
    )
    tpl = env.get_template("baseline/proxy/init.sls")
    pillar = {"baseline:proxy": pillar_proxy}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(grains=grains or {"os_family": "Suse"}, salt=salt)


def test_empty_proxy_removes_stale_lines():
    rendered = render_proxy({})
    assert "proxy_environment_exists:" in rendered
    # http/https (lower + upper) render delete stanzas when unset;
    # no_proxy keeps its loopback default so master IPC never proxies.
    assert rendered.count("mode: delete") == 4
    assert "no_proxy: 'localhost,127.0.0.1,::1'" in rendered
    assert "file.keyvalue:" in rendered  # sysconfig disabled branch
    assert "PROXY_ENABLED: 'no'" in rendered


def test_set_proxy_writes_environment_additively():
    rendered = render_proxy({"http_proxy": "http://proxy:8080",
                             "https_proxy": "http://proxy:8080",
                             "no_proxy": "localhost"})
    assert "http_proxy: 'http://proxy:8080'" in rendered
    assert "HTTP_PROXY: 'http://proxy:8080'" in rendered
    assert "mode: delete" not in rendered
    assert "PROXY_ENABLED: 'yes'" in rendered
    assert "NO_PROXY: 'localhost'" in rendered


def test_suse_manages_sysconfig_redhat_manages_dnf():
    suse = render_proxy({"http_proxy": "http://proxy:8080"})
    assert "proxy_sysconfig_exists:" in suse
    assert "- name: /etc/sysconfig/proxy" in suse
    assert "proxy_dnf_config" not in suse
    redhat = render_proxy({"http_proxy": "http://proxy:8080"},
                          grains={"os_family": "RedHat"})
    assert "proxy_dnf_config:" in redhat
    assert "proxy: 'http://proxy:8080'" in redhat
    assert "sysconfig" not in redhat
    redhat_empty = render_proxy({}, grains={"os_family": "RedHat"})
    assert "proxy_dnf_config_absent:" in redhat_empty
    assert "grep -q '^proxy=' /etc/dnf/dnf.conf" in redhat_empty
