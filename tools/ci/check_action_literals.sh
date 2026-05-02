#!/usr/bin/env bash
# tools/ci/check_action_literals.sh
#
# AC-INPUT-1.2 (BLOCKING): no double-quoted action string literals passed
# as function arguments outside InputActions. All action references must use
# &"..." StringName literals or InputActions.* constants.
#
# HEURISTIC: matches double-quoted lowercase identifiers immediately followed
# by `)` — captures `func("foo_bar")` patterns. Excludes &"..." StringName
# literals via the (?<!&) lookbehind. Excludes InputActions / class_name /
# extends lines, and excludes the InputActions definition file itself.
#
# EXEMPTION: lines containing `# action-literal-ok:` are skipped (use this
# annotation when a non-action lowercase string is legitimately passed as
# a function argument, e.g., bus name in AudioServer.set_bus_volume_db("SFX", 0.0)).
#
# Exit 0 = no violations; exit 1 = violations found.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VIOLATIONS=0
OFFENDERS=""

while IFS= read -r LINE; do
    # Strip leading file:lineno: prefix to inspect the source content
    CONTENT=$(echo "$LINE" | sed -E 's/^[^:]+:[0-9]+://')
    STRIPPED=$(echo "$CONTENT" | sed -e 's/^[[:space:]]*//')
    # Skip comment lines
    if [[ "$STRIPPED" == \#* ]]; then continue; fi
    # Skip lines exempted by the action-literal-ok marker
    if echo "$LINE" | grep -q 'action-literal-ok:'; then continue; fi
    # Skip lines containing InputActions. or class_name / extends patterns
    if echo "$LINE" | grep -qE 'InputActions\.|class_name|extends|action-literal-ok'; then continue; fi
    OFFENDERS+="$LINE"$'\n'
    VIOLATIONS=$(( VIOLATIONS + 1 ))
done < <(grep -rPn '(?<!&)"[a-z][a-z0-9_]+"\s*\)' \
    "$PROJECT_ROOT/src/" --include="*.gd" 2>/dev/null \
    | grep -v 'src/core/input/input_actions\.gd:' \
    || true)

if [ "$VIOLATIONS" -eq 0 ]; then
    echo "PASS: check_action_literals — no violations"
    exit 0
else
    echo "FAIL: $VIOLATIONS double-quoted action-literal violation(s):"
    echo "$OFFENDERS"
    exit 1
fi
