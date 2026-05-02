#!/usr/bin/env bash
# tools/ci/check_debug_action_gating.sh
#
# AC-INPUT-5.3 (partial) — Verify debug input actions are properly gated.
#
# Rules enforced:
#   1. Debug actions (debug_toggle_ai, debug_noclip, debug_spawn_alert) must NOT
#      appear as InputMap declarations in project.godot [input] block.
#   2. The runtime registration method in src/core/input/input_actions.gd must
#      use both InputMap.add_action and InputMap.action_add_event.
#
# Exit: 0 on pass, non-zero on any violation.
# Ref:  design/gdd/input.md §Group 6, story IN-001 AC-INPUT-5.3.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJECT_ROOT"

PASS=true

# ---------------------------------------------------------------------------
# Check 1: debug action names must NOT appear in project.godot [input] block.
# We grep for the pattern `<action_name>={` which is how project.godot declares
# InputMap entries. A const reference like `DEBUG_TOGGLE_AI` is fine — only
# the InputMap declaration format triggers this check.
# ---------------------------------------------------------------------------
DEBUG_ACTIONS=("debug_toggle_ai" "debug_noclip" "debug_spawn_alert")

for action in "${DEBUG_ACTIONS[@]}"; do
  if grep -E "^${action}=\{" project.godot > /dev/null 2>&1; then
    echo "FAIL [Check 1]: '${action}' found as InputMap entry in project.godot" \
         "— debug actions must be runtime-registered only (AC-INPUT-5.3)" >&2
    PASS=false
  fi
done

if [ "$PASS" = true ]; then
  echo "PASS [Check 1]: No debug actions declared in project.godot [input] block"
fi

# ---------------------------------------------------------------------------
# Check 2: runtime registration in input_actions.gd uses InputMap.add_action.
# ---------------------------------------------------------------------------
INPUT_ACTIONS_FILE="src/core/input/input_actions.gd"

if [ ! -f "$INPUT_ACTIONS_FILE" ]; then
  echo "FAIL [Check 2]: $INPUT_ACTIONS_FILE does not exist" >&2
  exit 1
fi

if ! grep -q 'InputMap\.add_action' "$INPUT_ACTIONS_FILE"; then
  echo "FAIL [Check 2]: InputMap.add_action not found in $INPUT_ACTIONS_FILE" \
       "— runtime registration is required for debug actions (AC-INPUT-5.3)" >&2
  PASS=false
else
  echo "PASS [Check 2]: InputMap.add_action found in $INPUT_ACTIONS_FILE"
fi

# ---------------------------------------------------------------------------
# Check 3: runtime registration uses InputMap.action_add_event.
# ---------------------------------------------------------------------------
if ! grep -q 'InputMap\.action_add_event' "$INPUT_ACTIONS_FILE"; then
  echo "FAIL [Check 3]: InputMap.action_add_event not found in $INPUT_ACTIONS_FILE" \
       "— runtime event binding is required for debug actions (AC-INPUT-5.3)" >&2
  PASS=false
else
  echo "PASS [Check 3]: InputMap.action_add_event found in $INPUT_ACTIONS_FILE"
fi

# ---------------------------------------------------------------------------
# Check 4 (IN-004 extension): registration call site is wrapped in
# OS.is_debug_build() guard at the InputContext autoload _ready().
# ---------------------------------------------------------------------------
INPUT_CONTEXT_FILE="src/core/ui/input_context.gd"

if [ ! -f "$INPUT_CONTEXT_FILE" ]; then
  echo "FAIL [Check 4]: $INPUT_CONTEXT_FILE does not exist" >&2
  PASS=false
elif ! grep -qE 'if[[:space:]]+OS\.is_debug_build\(\)[[:space:]]*:' "$INPUT_CONTEXT_FILE"; then
  echo "FAIL [Check 4]: 'if OS.is_debug_build():' guard not found in $INPUT_CONTEXT_FILE" \
       "— debug action registration must only run in debug builds (AC-INPUT-5.3 sub-check b)" >&2
  PASS=false
elif ! grep -q 'InputActions\._register_debug_actions()' "$INPUT_CONTEXT_FILE"; then
  echo "FAIL [Check 4]: InputActions._register_debug_actions() call not found in $INPUT_CONTEXT_FILE" >&2
  PASS=false
else
  echo "PASS [Check 4]: 'if OS.is_debug_build():' guard wraps _register_debug_actions() call"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$PASS" = false ]; then
  echo ""
  echo "FAIL: debug action gating check failed — see errors above" >&2
  exit 1
fi

echo ""
echo "PASS: debug action gating verified (AC-INPUT-5.3)"
exit 0
