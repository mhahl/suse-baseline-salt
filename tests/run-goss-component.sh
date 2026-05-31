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

echo ""
echo "================================================================================"
echo ">>> GOSS + SALT TEST RUNNER"
echo ">>> Component: $COMPONENT"
echo "================================================================================"

docker run --rm --privileged --user root \
  -v "$REPO_ROOT:/workspace" \
  opensuse/tumbleweed:latest \
  /bin/bash -x -euo pipefail -c '
    COMPONENT="'"$COMPONENT"'"
    echo ""
    echo "================================================================================"
    echo ">>> SETTING UP CONTAINER FOR: ${COMPONENT}"
    echo "================================================================================"

    # Ensure we are running as root (required for zypper, mkdir in /, etc.)
    if [ "$(id -u)" -ne 0 ]; then
      echo "ERROR: Docker container is not running as root (current uid: $(id -u))."
      echo "This usually means --user root was not passed to docker run."
      exit 1
    fi

    zypper --non-interactive refresh >/dev/null 2>&1 || true

    # Base packages needed by most components
    PACKAGES="salt-minion curl ca-certificates systemd procps iproute2 firewalld"

    # Extra packages required by specific components
    if [[ "$COMPONENT" == "integrity" ]]; then
      PACKAGES="$PACKAGES cronie"
    fi

    zypper --non-interactive install --no-recommends $PACKAGES >/dev/null

    # Fix for cron module in minimal containers (required for Salt's cron.present to load)
    if [[ "$COMPONENT" == "integrity" ]]; then
      mkdir -p /var/spool/cron/crontabs /etc/cron.d
      # Some images need the spool initialized
      touch /var/spool/cron/crontabs/root 2>/dev/null || true
    fi

    curl -L https://github.com/goss-org/goss/releases/latest/download/goss-linux-amd64 -o /usr/local/bin/goss
    chmod +rx /usr/local/bin/goss

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

    echo ""
    echo "================================================================================"
    echo ">>> SALT APPLY: baseline.${COMPONENT}.main"
    echo "================================================================================"
    salt-call --local --retcode-passthrough state.apply baseline.${COMPONENT}.main --log-level=warning

    echo ""
    echo "================================================================================"
    echo ">>> GOSS VALIDATION"
    echo "================================================================================"
    GOSSFILE="/workspace/goss/${COMPONENT}.yaml"
    if [ -f "$GOSSFILE" ]; then
      goss --gossfile "$GOSSFILE" validate
    else
      echo "No goss test file found: $GOSSFILE"
    fi

    echo ""
    echo "================================================================================"
    echo ">>> FINISHED: ${COMPONENT}"
    echo "================================================================================"
  '
