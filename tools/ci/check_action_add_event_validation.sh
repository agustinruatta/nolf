#!/usr/bin/env bash
# tools/ci/check_action_add_event_validation.sh
#
# AC-INPUT-6.2 (BLOCKING): every InputMap.action_add_event() call is preceded
# by InputMap.has_action() within the 5 lines immediately before (Core Rule 6 —
# prevents silent duplicate-action creation).
#
# EXEMPTIONS
#   - Comment lines are skipped.
#   - Lines containing `# action-validation-ok:` are skipped.
#
# Exit 0 = no violations; exit 1 = violations found.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VIOLATIONS=0
OFFENDERS=""

while IFS= read -r FILE; do
    while IFS=':' read -r LINE_NO LINE_TEXT; do
        STRIPPED=$(echo "$LINE_TEXT" | sed -e 's/^[[:space:]]*//')
        if [[ "$STRIPPED" == \#* ]]; then continue; fi
        if echo "$LINE_TEXT" | grep -q 'action-validation-ok:'; then continue; fi
        START=$(( LINE_NO - 5 ))
        if [ "$START" -lt 1 ]; then START=1; fi
        END=$(( LINE_NO - 1 ))
        if [ "$END" -lt 1 ]; then END=1; fi
        if ! sed -n "${START},${END}p" "$FILE" | grep -q 'InputMap\.has_action('; then
            OFFENDERS+="$FILE:$LINE_NO — InputMap.action_add_event() not preceded by InputMap.has_action() within 5 lines"$'\n'
            VIOLATIONS=$(( VIOLATIONS + 1 ))
        fi
    done < <(grep -n 'InputMap\.action_add_event(' "$FILE" 2>/dev/null || true)
done < <(find "$PROJECT_ROOT/src" -type f -name '*.gd' 2>/dev/null \
    | xargs grep -l 'InputMap\.action_add_event(' 2>/dev/null \
    || true)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "PASS: check_action_add_event_validation — no violations"
    exit 0
else
    echo "FAIL: $VIOLATIONS action_add_event-without-has_action violation(s):"
    echo "$OFFENDERS"
    exit 1
fi
