#!/usr/bin/env bash
# tools/ci/lint_respawn_triggered_sole_publisher.sh
#
# AC-FR-12.4: respawn_triggered must be emitted ONLY by failure_respawn_service.gd.
# Sole-publisher invariant per ADR-0002:183 + Story FR-006.

set -euo pipefail

MATCHES=$(grep -rn --include="*.gd" "respawn_triggered\.emit" src/ 2>/dev/null \
          | grep -v "src/gameplay/failure_respawn/failure_respawn_service.gd" \
          || true)

if [ -n "$MATCHES" ]; then
    echo "LINT FAIL (FR-006 AC-3): respawn_triggered emitted outside failure_respawn_service.gd:"
    echo "$MATCHES"
    exit 1
fi
echo "LINT PASS: respawn_triggered sole-publisher OK"
exit 0
