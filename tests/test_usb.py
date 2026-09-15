"""Render tests for baseline.usb storage blocking.

USB storage is blocked by default. Disabling it must remove a file
already deployed — skipping the managed file leaves the blacklist in
place, so pillar cannot re-enable storage.

Run from the repo root: ``python3 -m pytest tests/ -q``.
"""

from pathlib import Path

import jinja2

REPO_ROOT = Path(__file__).resolve().parents[1]
SALT_ROOT = REPO_ROOT / "salt"


def render_usb(block_storage):
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(SALT_ROOT)),
        keep_trailing_newline=True,
    )
    tpl = env.get_template("baseline/usb/init.sls")
    pillar = {"baseline:usb:block_storage": block_storage}
    salt = {"pillar.get": lambda key, default=None: pillar.get(key, default)}
    return tpl.render(salt=salt)


def test_block_writes_modprobe_file():
    rendered = render_usb(True)
    assert "file.managed:" in rendered
    assert "blacklist usb-storage" in rendered
    assert "file.absent:" not in rendered


def test_disable_removes_modprobe_file():
    rendered = render_usb(False)
    assert "file.absent:" in rendered
    assert "/etc/modprobe.d/99-baseline-usb-storage.conf" in rendered
    assert "blacklist usb-storage" not in rendered
