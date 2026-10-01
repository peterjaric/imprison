#!/bin/sh

# Guest-side init

set -e

# Place holders for workspace-specific setup if not defined in imprison.config.
pre_setup() {
  :
}

post_setup() {
  :
}

# Load per-workspace overrides (e.g. PACKAGES) from imprison.config, if present.
[ -f "$WORKSPACE_DIR/imprison.config" ] && . "$WORKSPACE_DIR/imprison.config"

echo "Running pre-setup..."
pre_setup

# Install every package/group listed in packages.txt (skip blanks/comments),
# plus any extras from imprison.config's PACKAGES variable.
packages=$(grep -vE '^[[:space:]]*(#|$)' "$(dirname "$0")/packages.txt")
dnf install -y $packages ${PACKAGES:-}

# Install pi (pi.dev), once.
if ! command -v pi >/dev/null 2>&1; then
  curl -fsSL https://pi.dev/install.sh -o /tmp/pi-install.sh
  setsid sh /tmp/pi-install.sh < /dev/null
  rm -f /tmp/pi-install.sh
fi

echo "Running post-setup..."
post_setup


