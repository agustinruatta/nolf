#!/usr/bin/env bash
# run-next-sprint.sh — start a fresh `claude` session pre-loaded with the
# bootstrap prompt for the next pending sprint per the multi-sprint roadmap.
#
# Usage:   tools/run-next-sprint.sh [04|05|06|07|08]
# If no sprint number is given, the script reads production/session-state/active.md
# and picks the first sprint whose section is not yet marked closed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROADMAP="$ROOT/production/sprints/multi-sprint-roadmap-pre-art.md"
PROMPTS="$ROOT/production/sprints/sprint-bootstrap-prompts.md"
STATE="$ROOT/production/session-state/active.md"

if [[ ! -f "$ROADMAP" ]] || [[ ! -f "$PROMPTS" ]]; then
    echo "ERROR: roadmap or bootstrap prompts missing. Re-run the planner."
    exit 1
fi

sprint_num="${1:-}"

if [[ -z "$sprint_num" ]]; then
    # Auto-detect: find the highest sprint number marked Complete in active.md,
    # then increment. Default to 04 if no sprint is closed yet.
    last_done=$(grep -oE 'Sprint 0[0-9].*close-out|Sprint 0[0-9].*COMPLETE' "$STATE" 2>/dev/null \
        | grep -oE '0[0-9]' | sort -nr | head -1 || echo "03")
    sprint_num=$(printf "%02d" $((10#$last_done + 1)))
fi

case "$sprint_num" in
    04|05|06|07|08) ;;
    *)
        echo "ERROR: sprint $sprint_num is outside the pre-art roadmap (04–08)."
        echo "Sprint 09+ requires user decision on art commission path — see roadmap."
        exit 2
        ;;
esac

# Extract the sprint's bootstrap prompt block from the prompts file
prompt=$(awk -v sprint="Sprint $sprint_num" '
    $0 ~ "^## " sprint { in_sprint=1; next }
    in_sprint && /^## / { exit }
    in_sprint && /^```$/ { in_block = !in_block; next }
    in_sprint && in_block { print }
' "$PROMPTS")

if [[ -z "$prompt" ]]; then
    echo "ERROR: could not extract bootstrap prompt for Sprint $sprint_num."
    exit 3
fi

echo "==========================================================="
echo " Launching Sprint $sprint_num in a fresh autonomous session"
echo "==========================================================="
echo
echo "$prompt"
echo
echo "==========================================================="
echo
echo "Copy the prompt above into your fresh \`claude\` session, OR"
echo "pipe it directly:"
echo
echo "    cd $ROOT && claude << 'PROMPT_EOF'"
echo "$prompt"
echo "PROMPT_EOF"
echo
