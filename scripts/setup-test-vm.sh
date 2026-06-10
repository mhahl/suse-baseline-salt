#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# sanity check
if [[ ! -d "$REPO_ROOT/salt/baseline" || ! -d "$REPO_ROOT/goss" ]]; then
    echo "ERROR: This script must be run from inside a clone of suse-baseline-salt."
    echo "Expected to find salt/baseline/ and goss/ directories relative to the script."
    exit 1
fi

echo "==> Preparing SUSE VM for suse-baseline-salt testing"
echo "    Repository root: $REPO_ROOT"
echo

# check SUSE
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

# require root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

# refresh repos
echo "==> Refreshing package repositories..."
zypper --non-interactive refresh

# install packages
echo "==> Installing required packages..."

PACKAGES=(
    salt-minion          # provides salt-call
    make
    curl
    git
    ca-certificates
)

# baseline packages
PACKAGES+=(
    audit
    cronie
    firewalld
    systemd-resolved
    chrony
)

zypper --non-interactive install --no-recommends "${PACKAGES[@]}"

# install goss
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

# prepare salt dirs (for traditional /srv usage on a full minion)
echo "==> Preparing Salt file roots..."

mkdir -p /srv/salt /srv/pillar

# Clean up any old namespaced layout from previous runs of this script
rm -f /srv/salt/top.sls
rm -rf /srv/salt/baseline-repo
rm -f /srv/pillar/top.sls
rm -rf /srv/pillar/baseline-repo

# Make the state modules available directly under /srv/salt
# (baseline/ and monitoring/ are the top-level state entry points)
if [[ -d "$REPO_ROOT/salt/baseline" ]]; then
    ln -sfn "$REPO_ROOT/salt/baseline" /srv/salt/baseline
    ln -sfn "$REPO_ROOT/salt/monitoring" /srv/salt/monitoring

    # Symlink pillar tree so the repository's pillar/top.sls is used
    ln -sfn "$REPO_ROOT/pillar" /srv/pillar

    echo "    Symlinked baseline/ and monitoring/ into /srv/salt"
    echo "    Symlinked pillar/ into /srv/pillar"
else
    echo "    WARNING: Could not find salt/baseline in repo root."
    echo "    You will need to manually set up /srv/salt and /srv/pillar."
fi

# Optional: create a simple top.sls for highstate usage (state.apply without args).
# Not required for the recommended "state.apply baseline" command.
if [[ -d /srv/salt/baseline ]]; then
    cat > /srv/salt/top.sls << 'EOF'
base:
  '*':
    - baseline
    - monitoring
EOF
    echo "    Created /srv/salt/top.sls for highstate"
fi

# For reliable "local" usage (especially on dev machines or when system minion config
# doesn't point at /srv), we recommend using explicit roots on the command line.
# This avoids depending on /etc/salt/minion or /srv being in the default file_roots.

# final instructions
echo
echo "==================================================================="
echo "  SUSE VM setup complete!"
echo "==================================================================="
echo
echo "Next steps:"
echo
echo "  1. Apply the baseline (local/masterless mode):"
echo "     # Recommended (works reliably even on dev machines without system /srv config):"
echo "     salt-call --local \\"
echo "       --file-root=\"$REPO_ROOT/salt\" \\"
echo "       --pillar-root=\"$REPO_ROOT/pillar\" \\"
echo "       state.apply baseline --log-level=info"
echo
echo "     # Alternative if you want to use the /srv symlinks created above:"
echo "     salt-call --local state.apply baseline --log-level=info"
echo
echo "  2. Run all Goss tests:"
echo "     make goss"
echo
echo "  3. Run tests for a specific component:"
echo "     make goss-chrony"
echo "     make goss-profile"
echo "     make goss-systemd-resolved"
echo "     make goss-usb"
echo
echo "  4. (Optional) Install goss via make if you prefer a local binary:"
echo "     make install-goss"
echo
echo "Repository location: $REPO_ROOT"
echo "(The explicit --file-root/--pillar-root command above is recommended for reliable 'local' runs.)"
echo
echo "Happy testing!"
echo "==================================================================="
