"""Render tests for the shared baseline/systemd-resolved state.

The resolver package name is shared by both supported platforms. The
netconfig guard is conditional on the Tumbleweed config path existing,
while the restorecon block still keys off the live SELinux state.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"

TW = {"os": "openSUSE Tumbleweed", "os_family": "Suse",
      "osmajorrelease": 20250905}


def render_init(grains=None):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/systemd-resolved/init.sls")
    salt = {"pillar.get": lambda key, default=None: default}
    return tpl.render(grains=grains if grains is not None else dict(TW),
                      salt=salt)


def test_init_installs_split_package_and_keeps_stub_symlink():
    rendered = render_init()
    assert "- name: systemd-resolved\n" in rendered
    assert "target: /run/systemd/resolve/stub-resolv.conf" in rendered


def test_netconfig_guard_always_renders():
    rendered = render_init()
    assert 'NETCONFIG_DNS_POLICY=""' in rendered
    assert "onlyif: test -f /etc/sysconfig/network/config" in rendered


def test_relabel_only_when_selinux_enforced_and_label_wrong():
    enforcing = render_init(
        {**TW, "selinux": {"enabled": True, "enforced": True}}
    )
    assert "restorecon -Rv /usr/lib/systemd/systemd-resolved /run/systemd/resolve" in enforcing
    assert "command -v restorecon && test -e /usr/lib/systemd/systemd-resolved" in enforcing
    assert "! ls -Z /usr/lib/systemd/systemd-resolved | grep -q systemd_resolved_exec_t" in enforcing
    # The service must require + watch the relabel so it starts in the
    # systemd_resolved_t domain and restarts when the label is fixed.
    assert "- cmd: resolved_selinux_relabel" in enforcing

    permissive = render_init(
        {**TW, "selinux": {"enabled": True, "enforced": False}}
    )
    assert "restorecon" not in permissive
    assert "resolved_selinux_relabel" not in permissive

    assert "restorecon" not in render_init()


def test_resolved_conf_template_renders_dot_and_dns():
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/systemd-resolved/templates/resolved.conf.jinja")
    default_out = tpl.render(dns={"dns": "1.1.1.1#cloudflare-dns.com"})
    assert "DNS=1.1.1.1#cloudflare-dns.com" in default_out
    assert "DNSOverTLS=opportunistic" in default_out
    assert "DNSSEC=yes" in default_out

    strict_out = tpl.render(dns={"dns": "1.1.1.1", "dns_over_tls": "yes"})
    assert "DNSOverTLS=yes" in strict_out
