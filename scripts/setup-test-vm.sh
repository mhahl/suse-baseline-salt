#!/usr/bin/env bash
#
# setup-test-vm.sh
#
# Utility script to prepare a SUSE VM (Tumbleweed or Leap/SLES) for testing
# the suse-baseline-salt repository.
#
# Usage:
#   ./scripts/setup-test-vm.sh
#
# What it does:
#   - Installs required packages (salt, make, curl, etc.)
#   - Downloads and installs Goss
#   - Prepares /srv/salt and /srv/pillar directories
#   - Creates symlinks from the current repository
#   - Prints next steps for applying states and running tests
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Basic sanity check that we are inside the expected repository structure
if [[ ! -d "$REPO_ROOT/salt/baseline" || ! -d "$REPO_ROOT/goss" ]]; then
    echo "ERROR: This script must be run from inside a clone of suse-baseline-salt."
    echo "Expected to find salt/baseline/ and goss/ directories relative to the script."
    exit 1
fi

echo "==> Preparing SUSE VM for suse-baseline-salt testing"
echo "    Repository root: $REPO_ROOT"
echo

# --- Check we are on a SUSE system ------------------------------------------
if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: This script is intended for openSUSE / SLES systems."
    exit 1
fi

source /etc/os-release
if [[ "${ID_LIKE:-}" != *"suse"* && "${ID}" != "opensuse-tumbleweed" && "${ID}" != "opensuse-leap" ]]; then
    echo "WARNING: This does not look like a SUSE system (detected: ${PRETTY_NAME:-unknown})"
    read -r -p "Continue anyway? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

echo "Detected: ${PRETTY_NAME:-$ID}"

# --- Require root -----------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

# --- Refresh repositories ---------------------------------------------------
echo "==> Refreshing package repositories..."
zypper --non-interactive refresh

# --- Install required packages ----------------------------------------------
echo "==> Installing required packages..."

PACKAGES=(
    salt-minion          # provides salt-call
    make
    curl
    git
    ca-certificates
)

# Packages commonly used by the baseline states
PACKAGES+=(
    audit
    cronie
    firewalld
    systemd-resolved
    chrony
)

zypper --non-interactive install --no-recommends "${PACKAGES[@]}"

# --- Install Goss -----------------------------------------------------------
GOSS_VERSION="${GOSS_VERSION:-v0.4.9}"
GOSS_URL="https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-amd64"
GOSS_BIN="/usr/local/bin/goss"

if [[ ! -x "$GOSS_BIN" ]]; then
    echo "==> Installing Goss ${GOSS_VERSION}..."
    curl -fsSL "$GOSS_URL" -o "$GOSS_BIN"
    chmod +x "$GOSS_BIN"
else
    echo "==> Goss already installed: $(goss --version 2>/dev/null || echo 'unknown version')"
fi

# --- Prepare Salt directories -----------------------------------------------
echo "==> Preparing Salt file roots..."

mkdir -p /srv/salt /srv/pillar

# Create symlinks from the repository (idempotent)
if [[ -d "$REPO_ROOT/salt/baseline" ]]; then
    ln -sfn "$REPO_ROOT/salt" /srv/salt/baseline-repo
    ln -sfn "$REPO_ROOT/pillar" /srv/pillar/baseline-repo

    # Create minimal top files if they don't exist
    if [[ ! -f /srv/salt/top.sls ]]; then
        cat > /srv/salt/top.sls << 'EOF'
base:
  '*':
    - baseline-repo.baseline.init
EOF
    fi

    if [[ ! -f /srv/pillar/top.sls ]]; then
        cat > /srv/pillar/top.sls << 'EOF'
base:
  '*':
    - baseline-repo.baseline
EOF
    fi

    echo "    Symlinked repository into /srv/salt and /srv/pillar"
else
    echo "    WARNING: Could not find salt/baseline in repo root."
    echo "    You will need to manually set up /srv/salt and /srv/pillar."
fi

# --- Final instructions -----------------------------------------------------
echo
echo "==================================================================="
echo "  SUSE VM setup complete!"
echo "==================================================================="
echo
echo "Next steps:"
echo
echo "  1. Apply the baseline (local mode):"
echo "     salt-call --local state.apply baseline --log-level=info"
echo
echo "  2. Run all Goss tests:"
echo "     make goss"
echo
echo "  3. Run tests for a specific component:"
echo "     make goss-sysctl"
echo "     make goss-firewalld"
echo "     make goss-profile"
echo
echo "  4. (Optional) Install goss via make if you prefer a local binary:"
echo "     make install-goss"
echo
echo "Repository location on this VM: $REPO_ROOT"
echo
echo "Happy testing!"
echo "==================================================================="
