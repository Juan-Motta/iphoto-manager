#!/usr/bin/env bash
# Runs the test suite. With Command Line Tools only (no Xcode), the Swift Testing
# macro plugin lives in a subfolder the compiler does not search by default.
set -euo pipefail
PLUGINS="$(dirname "$(xcrun --find swift)")/../lib/swift/host/plugins/testing"
if [ -d "$PLUGINS" ]; then
  exec swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
fi
exec swift test "$@"
