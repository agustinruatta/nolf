#!/usr/bin/env bash
# tools/ci/check_raw_input_constants.sh
#
# AC-INPUT-6.1 (BLOCKING): no raw input constants (KEY_*, JOY_BUTTON_*,
# JOY_AXIS_*, MOUSE_BUTTON_*) in src/ outside InputActions class and
# OS.is_debug_build()-gated blocks. All input checks MUST route through
# InputMap actions (Core Rule 1).
#
# EXEMPTIONS
#   - Comment lines (start with `#` after whitespace strip) are skipped.
#   - Lines containing `# raw-input-ok:` are skipped (use this for code that
#     legitimately needs the raw constant, e.g., debug overlays building
#     InputEventKey instances dynamically).
#   - All files under src/core/input/ are skipped (InputActions definition).
#   - Lines containing `OS.is_debug_build()` are skipped (debug-only paths).
#
# Exit 0 = no violations; exit 1 = violations found.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VIOLATIONS=0
OFFENDERS=""

while IFS= read -r LINE; do
    # Skip files under src/core/input/
    if echo "$LINE" | grep -q '/src/core/input/'; then continue; fi
    # Strip leading file:lineno: prefix to inspect content
    CONTENT=$(echo "$LINE" | sed -E 's/^[^:]+:[0-9]+://')
    STRIPPED=$(echo "$CONTENT" | sed -e 's/^[[:space:]]*//')
    # Skip comment lines
    if [[ "$STRIPPED" == \#* ]]; then continue; fi
    # Skip exempted lines
    if echo "$LINE" | grep -q 'raw-input-ok:'; then continue; fi
    # Skip OS.is_debug_build()-gated lines
    if echo "$LINE" | grep -q 'OS\.is_debug_build'; then continue; fi
    OFFENDERS+="$LINE"$'\n'
    VIOLATIONS=$(( VIOLATIONS + 1 ))
done < <(grep -rPn '\b(KEY_|JOY_BUTTON_|JOY_AXIS_|MOUSE_BUTTON_)[A-Z_]+' \
    "$PROJECT_ROOT/src/" --include="*.gd" 2>/dev/null \
    || true)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "PASS: check_raw_input_constants — no violations"
    exit 0
else
    echo "FAIL: $VIOLATIONS raw-input-constant violation(s):"
    echo "$OFFENDERS"
    exit 1
fi
