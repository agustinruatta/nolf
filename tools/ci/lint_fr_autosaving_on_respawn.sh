#!/usr/bin/env bash
# tools/ci/lint_fr_autosaving_on_respawn.sh
#
# AC-FR-12.5 / FR-006 AC-5: FailureRespawn must NOT call save_to_slot from
# its step-9 restore callback. The fr_autosaving_on_respawn forbidden pattern.
# Story FR-006.

set -euo pipefail

FILE="src/gameplay/failure_respawn/failure_respawn_service.gd"
if [ ! -f "$FILE" ]; then
    echo "LINT SKIP: $FILE does not exist"
    exit 0
fi

# Extract the _on_ls_restore function body (from `func _on_ls_restore` to next `^func `).
# AWK extracts lines between the function declaration and the next top-level func.
BODY=$(awk '/^func _on_ls_restore/,/^func [^_]/{ if ($0 !~ /^func [^_]/) print }' "$FILE")

# Look for save_to_slot calls inside the body (excluding comments).
VIOLATION=$(echo "$BODY" | grep -E "[^#]*\.save_to_slot\b|[^#]*save_to_slot\(0" || true)

if [ -n "$VIOLATION" ]; then
    echo "LINT FAIL (FR-006 AC-5): _on_ls_restore body contains save_to_slot — forbidden pattern fr_autosaving_on_respawn"
    echo "$VIOLATION"
    exit 1
fi
echo "LINT PASS: fr_autosaving_on_respawn OK"
exit 0
