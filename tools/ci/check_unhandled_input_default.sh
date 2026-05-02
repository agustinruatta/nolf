#!/usr/bin/env bash
# tools/ci/check_unhandled_input_default.sh
#
# AC-INPUT-6.3 (ADVISORY): lists every `func _input(` usage in src/ outside
# InputActions definition and OS.is_debug_build()-gated blocks. ADR-0004
# mandates `_unhandled_input()` as the project default; `_input()` is reserved
# for priority cases (e.g., debug overlays) and requires a code-review-approved
# justification comment on the line above the function declaration.
#
# This script ALWAYS exits 0 (advisory only) — it produces a list for manual
# code-review attention rather than blocking CI.
#
# EXEMPTIONS
#   - Comment lines are skipped.
#   - Files under src/core/input/ and src/core/ui/ are skipped (input infra).
#   - Lines containing `# unhandled-input-ok:` are skipped.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ADVISORY_COUNT=0
ADVISORIES=""

while IFS= read -r LINE; do
    # Skip files under input infrastructure
    if echo "$LINE" | grep -qE '/src/core/(input|ui)/'; then continue; fi
    # Skip tools/ paths
    if echo "$LINE" | grep -q '/tools/'; then continue; fi
    # Strip leading file:lineno: prefix
    CONTENT=$(echo "$LINE" | sed -E 's/^[^:]+:[0-9]+://')
    STRIPPED=$(echo "$CONTENT" | sed -e 's/^[[:space:]]*//')
    # Skip comment lines
    if [[ "$STRIPPED" == \#* ]]; then continue; fi
    # Skip exempted lines
    if echo "$LINE" | grep -q 'unhandled-input-ok:'; then continue; fi
    ADVISORIES+="$LINE"$'\n'
    ADVISORY_COUNT=$(( ADVISORY_COUNT + 1 ))
done < <(grep -rPn 'func[[:space:]]+_input[[:space:]]*\(' \
    "$PROJECT_ROOT/src/" --include="*.gd" 2>/dev/null \
    || true)

echo "ADVISORY: $ADVISORY_COUNT _input() usage(s) found outside input/UI infra:"
if [ "$ADVISORY_COUNT" -gt 0 ]; then
    echo "$ADVISORIES"
    echo "Each usage must be justified by a code-review-approved comment per AC-INPUT-6.3."
fi
echo "PASS: check_unhandled_input_default — advisory only (always exits 0)"
exit 0
