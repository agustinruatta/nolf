# Story 004: Anti-pattern CI enforcement + debug action gating

> **Epic**: Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (S-M — CI shell scripts + one unit test; no new GDScript systems)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/input.md`
**Requirements**: `TR-INP-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: Three forbidden patterns are registered in `docs/registry/architecture.yaml`: `direct_input_global_query` (skipping the InputContext gate), `unregistered_action` (using raw string literals not in InputActions), `cross_context_event_consumption` (handler consuming without checking context). CI grep guards are the primary enforcement mechanism. ADR-0004 mandates `_unhandled_input()` as the project default; `_input()` is reserved for priority cases only (e.g., debug overlays) and requires a code-review-approved comment.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Shell scripts using `grep` and POSIX tools are engine-agnostic. The GDScript source file patterns being grepped (`*.gd`) are stable. CI command per `coding-standards.md`: `godot --headless --script tests/gdunit4_runner.gd`. No post-cutoff API concerns for CI tooling.

**Control Manifest Rules (Core)**:
- Required: CI scripts must run on Linux (primary CI platform per technical-preferences.md)
- Required: every script is marked executable and referenced from the project's CI configuration
- Forbidden: `hardcoded_physics_layer_number` (not applicable — no physics in this story)
- Global: `docs/registry/architecture.yaml` entries for input forbidden patterns must be confirmed present; if absent, add them in this story's PR per ADR convention

---

## Acceptance Criteria

*From GDD `design/gdd/input.md` §Acceptance Criteria, scoped to this story:*

- [ ] **AC-INPUT-1.2 [Code-Review] BLOCKING**: CI command `grep -rPn '(?<!&)"[a-z][a-z0-9_]+"\s*\)' src/ --include="*.gd" | grep -vE 'InputActions\.|class_name|extends'` runs; zero matches outside `res://src/core/input/input_actions.gd` declarations (heuristic — flags double-quoted lowercase identifiers passed as function arguments; `&"foo"` StringName literals correctly skipped). Evidence: `tools/ci/check_action_literals.sh`.
- [ ] **AC-INPUT-5.3 [Code-Review] BLOCKING — full debug-action gating check**: **(a)** debug action constants (`debug_toggle_ai`, `debug_noclip`, `debug_spawn_alert`) do NOT appear in `project.godot [input]` section (grep check); **(b)** the runtime registration block in `InputActions._register_debug_actions()` (or equivalent) is wrapped in `if OS.is_debug_build():` at the call site in `InputContextStack._ready()` AND uses `InputMap.add_action()` + `InputMap.action_add_event()` for each debug action; **(c)** `InputMap.has_action(action)` is called BEFORE each `action_add_event()` (Core Rule 6 guard). Evidence: `tools/ci/check_debug_action_gating.sh`.
- [ ] **AC-INPUT-6.1 [Code-Review] BLOCKING**: CI command `grep -rPn '\b(KEY_|JOY_BUTTON_|JOY_AXIS_|MOUSE_BUTTON_)[A-Z_]+' src/ --include="*.gd" | grep -vE 'OS\.is_debug_build|^src/core/input/'` runs; zero matches outside `InputActions` class and `OS.is_debug_build()`-gated blocks. All input checks MUST route through InputMap actions (Core Rule 1). Evidence: `tools/ci/check_raw_input_constants.sh`.
- [ ] **AC-INPUT-6.2 [Code-Review] BLOCKING**: CI command `grep -rPn 'InputMap\.action_add_event\(' src/ --include="*.gd"` runs; for every match, the immediately preceding 5 lines contain an `InputMap.has_action(` check on the same action name (Core Rule 6 — prevents silent duplicate-action creation). Evidence: `tools/ci/check_action_add_event_validation.sh`.
- [ ] **AC-INPUT-6.3 [Code-Review] ADVISORY**: CI command `grep -rPn 'func _input\s*\(' src/ --include="*.gd" | grep -vE 'OS\.is_debug_build|^src/core/input/|tools/'` runs; every match is accompanied by a code-review-approved comment justifying use of `_input()` over `_unhandled_input()`. Evidence: `tools/ci/check_unhandled_input_default.sh`.

---

## Implementation Notes

*Derived from GDD §Acceptance Criteria §Anti-pattern enforcement + GDD §Detailed Rules Core Rules 1, 5, 6:*

This story creates five shell scripts in `tools/ci/`. Each script is self-contained, executable, outputs violations to stdout, and exits with status 1 if violations are found (0 = pass).

**Script specifications:**

`tools/ci/check_action_literals.sh` — AC-INPUT-1.2:
```bash
#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VIOLATIONS=$(grep -rPn '(?<!&)"[a-z][a-z0-9_]+"\s*\)' \
    "$PROJECT_ROOT/src/" --include="*.gd" \
    | grep -vE 'InputActions\.|class_name|extends' \
    | grep -vE '^.*src/core/input/input_actions\.gd:')
if [ -n "$VIOLATIONS" ]; then
    echo "FAIL: Double-quoted action string literals found outside InputActions:"
    echo "$VIOLATIONS"
    exit 1
fi
echo "PASS: check_action_literals — no violations"
```

`tools/ci/check_raw_input_constants.sh` — AC-INPUT-6.1:
```bash
#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VIOLATIONS=$(grep -rPn '\b(KEY_|JOY_BUTTON_|JOY_AXIS_|MOUSE_BUTTON_)[A-Z_]+' \
    "$PROJECT_ROOT/src/" --include="*.gd" \
    | grep -vE 'OS\.is_debug_build' \
    | grep -vE 'src/core/input/')
if [ -n "$VIOLATIONS" ]; then
    echo "FAIL: Raw input constants (KEY_/JOY_BUTTON_/etc.) found outside InputActions:"
    echo "$VIOLATIONS"
    exit 1
fi
echo "PASS: check_raw_input_constants — no violations"
```

`tools/ci/check_action_add_event_validation.sh` — AC-INPUT-6.2:
Uses Python or awk to check that every `InputMap.action_add_event(` call is preceded by `InputMap.has_action(` within 5 lines. Bash alone is fragile for multi-line context; use Python:
```python
#!/usr/bin/env python3
# Checks that every InputMap.action_add_event() call is preceded by InputMap.has_action()
# within the previous 5 lines in the same file.
```

`tools/ci/check_dismiss_order.sh` — AC-INPUT-3.2 (from Story 003, but registered here as part of the full CI script suite):
```bash
#!/usr/bin/env bash
# Checks that set_input_as_handled() appears before InputContext.pop() in every dismiss handler.
```

`tools/ci/check_debug_action_gating.sh` — AC-INPUT-5.3:
```bash
#!/usr/bin/env bash
# (a) Verify debug actions absent from project.godot [input] section
# (b) Verify registration call site is wrapped in OS.is_debug_build()
# (c) Verify has_action() guard precedes action_add_event() in _register_debug_actions
```

`tools/ci/check_unhandled_input_default.sh` — AC-INPUT-6.3 (ADVISORY):
```bash
#!/usr/bin/env bash
# Lists all _input() usages outside InputActions and debug blocks; exits 0 always (advisory).
# Outputs a list for manual review in the CI log.
```

**docs/registry/architecture.yaml additions**: confirm that the three input forbidden patterns are present in the registry. If absent, append:
- `direct_input_global_query` — skipping InputContext.is_active() check before consuming input
- `unregistered_action` — using Input.is_action_* with a string literal not declared in InputActions
- `cross_context_event_consumption` — handler consuming an event without checking its required context

**Unit test for debug action registration** (AC-INPUT-5.3 — test complement to the CI script):
`tests/unit/core/input/debug_action_gating_test.gd` — verifies the logical behavior:
- In a debug build: `InputMap.has_action(&"debug_toggle_ai")` returns `true` after `InputActions._register_debug_actions()` is called
- `InputMap.has_action(&"debug_noclip")` and `InputMap.has_action(&"debug_spawn_alert")` also return `true`
- Calling `_register_debug_actions()` twice is idempotent (the `has_action` guard prevents duplicate registration)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `InputActions` static class definition and `_register_debug_actions()` method body
- Story 002: `InputContextStack._ready()` call site for `_register_debug_actions()`
- Story 003: `check_dismiss_order.sh` is specified in Story 003's AC-INPUT-3.2; this story implements the full CI suite including that script for completeness
- Consumer epics: the CI scripts in this story will accumulate violations as consumer epics are implemented — each consumer is responsible for passing these checks at the time it ships

---

## QA Test Cases

**AC-INPUT-6.1 — Raw input constants grep**
- **Given**: source tree contains only `InputActions` and the test fixtures from Stories 001-003
- **When**: `check_raw_input_constants.sh` runs
- **Then**: exits 0 (no raw constant usage outside InputActions / debug blocks)
- **Edge cases**: test fixture from Story 003 uses `KEY_ESCAPE` in event construction — the event construction in a test file lives under `tests/`, not `src/`; confirm the grep pattern targets `src/` only (if tests also need to be clean, update the script scope)

**AC-INPUT-6.2 — has_action() guard before action_add_event()**
- **Given**: `InputActions._register_debug_actions()` uses the `has_action` guard pattern per Story 001
- **When**: `check_action_add_event_validation.sh` runs
- **Then**: exits 0; the debug registration method passes the 5-line lookback check
- **Edge cases**: Python script encounters a file with Windows line endings (CRLF) → normalize with `.strip()` in Python parser; empty `src/` directory → script exits 0 with "no matches found" message

**AC-INPUT-5.3 — Debug action gating (full)**
- **Given**: `project.godot` without debug actions in `[input]`; `input_context.gd` with `_ready()` calling `InputActions._register_debug_actions()` wrapped in `if OS.is_debug_build():`
- **When**: `check_debug_action_gating.sh` runs
- **Then**: all three sub-checks pass (absent from project.godot; wrapped in is_debug_build; has_action guard present)
- **Edge cases**: `_register_debug_actions()` moved to a different call site → script may need updating; document the expected call site location in the script's header comment

**AC-INPUT-1.2 — Action literal grep**
- **Given**: source tree after Stories 001-003 are implemented
- **When**: `check_action_literals.sh` runs
- **Then**: exits 0; all action references in test fixtures use `&"..."` StringName literals or `InputActions.*` constants, not bare `"..."` double-quoted strings
- **Edge cases**: GUT assertion strings (`assert_eq("move_forward", ...)`) may false-positive — refine grep pattern or add a `tests/` exclusion if needed

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/input/debug_action_gating_test.gd` — must exist and pass (AC-INPUT-5.3 behavior complement)
- `tools/ci/check_action_literals.sh` — must exist; CI passes with zero violations (AC-INPUT-1.2)
- `tools/ci/check_raw_input_constants.sh` — must exist; CI passes with zero violations (AC-INPUT-6.1)
- `tools/ci/check_action_add_event_validation.sh` — must exist; CI passes (AC-INPUT-6.2)
- `tools/ci/check_debug_action_gating.sh` — must exist; CI passes (AC-INPUT-5.3)
- `tools/ci/check_unhandled_input_default.sh` — must exist; outputs advisory report (AC-INPUT-6.3 — advisory, exits 0)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (InputActions class exists; `_register_debug_actions()` defined), Story 002 (InputContextStack autoload exists with `_ready()` calling registration), Story 003 (dismiss fixtures exist for `check_dismiss_order.sh` to scan)
- Unlocks: all consumer epics (Player Character, Combat, Inventory, Menu System, Save/Load) — the CI scripts gate every sprint that touches input; all consumer stories pass these checks before marking Done
