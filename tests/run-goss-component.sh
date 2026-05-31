#!/bin/bash
#
# Local helper to run goss tests for a single component using Docker + openSUSE Tumbleweed.
# Usage:
#   ./tests/run-goss-component.sh sysctl
#   ./tests/run-goss-component.sh profile
#

set -euo pipefail

COMPONENT=${1:-}

if [[ -z "$COMPONENT" ]]; then
  echo "Usage: $0 <component>"
  echo "Available components: profile, systemd-resolved, chrony, banner, sysctl, coredump, audit, sudo, pam, firewalld, usb, grub, integrity, updates"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Testing component: $COMPONENT"

docker run --rm --privileged \
  -v "$REPO_ROOT:/workspace" \
  opensuse/tumbleweed:latest \
  /bin/bash -euo pipefail -c '
    COMPONENT="'"$COMPONENT"'"
    echo "=== Setting up for $COMPONENT ==="

    zypper --non-interactive refresh >/dev/null 2>&1 || true
    zypper --non-interactive install --no-recommends \
      salt-minion curl ca-certificates systemd procps iproute2 firewalld >/dev/null

    curl -fsSL https://goss.rocks/install.sh | sh >/dev/null 2>&1
    export PATH="/usr/local/bin:$PATH"

    mkdir -p /srv/salt /srv/pillar /etc/salt

    cp -r /workspace/salt/* /srv/salt/

    cat > /srv/salt/top.sls << EOF
base:
  "*":
    - baseline.${COMPONENT}.main
EOF

    cp /workspace/pillar/baseline.sls /srv/pillar/baseline.sls

    cat > /srv/pillar/top.sls << EOF
base:
  "*":
    - baseline
EOF

    cat > /etc/salt/minion << EOF
file_roots:
  base:
    - /srv/salt
pillar_roots:
  base:
    - /srv/pillar
EOF

    echo "Applying Salt state..."
    salt-call --local --retcode-passthrough state.apply baseline.${COMPONENT}.main --log-level=warning

    echo "Running Goss..."
    GOSSFILE="/workspace/goss/${COMPONENT}.yaml"
    if [ -f "$GOSSFILE" ]; then
      goss --gossfile "$GOSSFILE" validate
    else
      echo "No goss test file found: $GOSSFILE"
    fi
  '
