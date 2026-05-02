#!/usr/bin/env bash
# tools/ci/check_dismiss_order.sh
#
# AC-INPUT-3.2 (BLOCKING): every modal dismiss handler that calls
# InputContext.pop() must call set_input_as_handled() within the 5 lines
# immediately preceding the pop() call (Core Rule 7 — consume-before-pop order).
#
# USAGE
#   tools/ci/check_dismiss_order.sh [search-root...]
#   default search-roots = "src tests/integration"
#
# EXEMPTIONS
#   - Comment-only lines (start with `#` after whitespace strip) are skipped.
#   - Lines annotated with `# dismiss-order-ok:` are skipped (use this for
#     legitimate non-modal pops like section-transition cleanup; the trailing
#     text after the colon documents WHY the exemption applies).
#
# OUTPUT
#   Prints offending file:line for each pop() that lacks a preceding consume.
#   Exit code 0 = no violations; exit code 1 = at least one violation.
#
# This script is invoked from the GdUnit4 test
# tests/unit/foundation/dismiss_order_lint_test.gd to keep the CI gate inside
# the standard headless test suite.

set -uo pipefail

if [ "$#" -gt 0 ]; then
    SEARCH_ROOTS=( "$@" )
else
    SEARCH_ROOTS=( "src" "tests/integration" )
fi
VIOLATIONS=0

# Find every .gd file containing InputContext.pop() (anywhere — code or comment)
while IFS= read -r FILE; do
    # For each pop() match, classify and inspect.
    while IFS=':' read -r LINE_NO LINE_TEXT; do
        # Skip comment-only lines (the literal pop() appears in doc comments)
        STRIPPED=$(echo "$LINE_TEXT" | sed -e 's/^[[:space:]]*//')
        if [[ "$STRIPPED" == \#* ]]; then
            continue
        fi
        # Skip exempted lines (legitimate non-modal pops)
        if echo "$LINE_TEXT" | grep -q 'dismiss-order-ok:'; then
            continue
        fi
        # Inspect the 5 lines immediately preceding the pop()
        START=$(( LINE_NO - 5 ))
        if [ "$START" -lt 1 ]; then START=1; fi
        END=$(( LINE_NO - 1 ))
        if [ "$END" -lt 1 ]; then END=1; fi
        if ! sed -n "${START},${END}p" "$FILE" | grep -q 'set_input_as_handled'; then
            echo "VIOLATION: $FILE:$LINE_NO — InputContext.pop() not preceded by set_input_as_handled() within 5 lines"
            VIOLATIONS=$(( VIOLATIONS + 1 ))
        fi
    done < <(grep -n 'InputContext\.pop()' "$FILE" 2>/dev/null || true)
done < <(find "${SEARCH_ROOTS[@]}" -type f -name '*.gd' 2>/dev/null \
    | xargs grep -l 'InputContext\.pop()' 2>/dev/null \
    || true)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "PASS: no dismiss-order violations found in: ${SEARCH_ROOTS[*]}"
    exit 0
else
    echo "FAIL: $VIOLATIONS dismiss-order violation(s) found"
    exit 1
fi
