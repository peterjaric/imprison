#!/bin/sh

# Guest-side entrypoint: run the given command (default: pi) as the
# workspace mount owner, with the working directory set to the workspace mount.

set -e

export PATH="/root/.pi/agent/bin:$PATH"

cd "$WORKSPACE_DIR"

if [ "$#" -eq 0 ]; then
  set -- pi
fi

exec "$@"
