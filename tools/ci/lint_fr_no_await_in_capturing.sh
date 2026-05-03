#!/usr/bin/env bash
# tools/ci/lint_fr_no_await_in_capturing.sh
#
# AC-FR-12.3 / FR-006 AC-2: No `await` in F&R's CAPTURING body between
# save_to_slot and transition_to_section. Synchronous CR-4 ordering invariant.
# Story FR-006.

set -euo pipefail

FILE="src/gameplay/failure_respawn/failure_respawn_service.gd"
if [ ! -f "$FILE" ]; then
    echo "LINT SKIP: $FILE does not exist"
    exit 0
fi

# Extract _on_player_died body and check for await (excluding comment lines).
BODY=$(awk '/^func _on_player_died/,/^func [^_]/{ if ($0 !~ /^func [^_]/) print }' "$FILE")

# Strip comment-only lines, then look for await keyword.
VIOLATION=$(echo "$BODY" | grep -vE "^\s*#" | grep -E "\baw[a]it\b" || true)

if [ -n "$VIOLATION" ]; then
    echo "LINT FAIL (FR-006 AC-2): _on_player_died body contains await — breaks CR-4 synchronous ordering"
    echo "$VIOLATION"
    exit 1
fi
echo "LINT PASS: no await in F&R CAPTURING body"
exit 0
