# Story 001: InputActions static class + project.godot action catalog

> **Epic**: Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 hours (M — 1 new file + project.godot edit + fixture file + 2 test files)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/input.md`
**Requirements**: `TR-INP-001`, `TR-INP-002`, `TR-INP-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

> **TR-INP-002 drift note**: the registry entry (revised 2026-04-23) says "30 actions (27 gameplay/UI + 3 debug)" reflecting the dedicated `takedown` addition. The GDD (revised 2026-04-27) now documents **36 actions** (33 gameplay/UI + 3 debug) — `takedown` and `use_gadget` were split to distinct dedicated keys per Settings CR-22 + Combat CR-3, and the full 36-action catalog was audited in the 2026-04-27 design-review pass. The GDD is authoritative; TR-INP-002 needs a registry revision to "36 actions (33 gameplay/UI + 3 debug)". This story implements against the GDD's 36-action count.

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: ADR-0004 mandates three locked InputMap actions (`ui_cancel = Esc + B/Circle`, `interact = E + A/Cross`, `pause = Esc + START`) and requires every `ui_*` action to have both KB/M and gamepad bindings declared in `project.godot [input]` (Finding F3 / IG 14). ADR-0007 confirms `InputContext` is at autoload line 4; the `InputActions` class itself is a static class, NOT an autoload, residing at `res://src/core/input/input_actions.gd`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (per EPIC.md — SDL3 gamepad backend 4.5+; dual-focus split 4.6 sidestepped by `_unhandled_input + ui_cancel`)
**Engine Notes**: `InputMap` and `InputEvent` subclasses are stable since Godot 4.0. `StringName` literal syntax (`&"name"`) is stable since 4.0. Debug-action runtime registration via `InputMap.add_action()` + `InputMap.action_add_event()` is stable since 4.0. Post-cutoff note: SDL3 gamepad driver change in 4.5 affects button-index mapping for gamepad bindings in `project.godot`; `JOY_BUTTON_B` (button_index=1) is verified correct for 4.6.2 per ADR-0004 Finding F3. Verify `JOY_BUTTON_A` (button_index=0) and other gamepad bindings against `docs/engine-reference/godot/` before sprint.

**Control Manifest Rules (Core)**:
- Required: `PhysicsLayers.*` constants for any collision references (not applicable to this story — no physics)
- Required: static typing on all GDScript variables, parameters, and return types
- Required: doc comments on all public APIs (every `const` in `InputActions` needs a one-line doc comment)
- Forbidden: `hardcoded_physics_layer_number` (not applicable), `unregistered_autoload` (not applicable — `InputActions` is a static class, not an autoload)
- Global: `class_name` registered, no autoload registration needed
- Global: `project.godot [autoload]` block MUST NOT be modified by this story — only the `[input]` section is touched

---

## Acceptance Criteria

*From GDD `design/gdd/input.md` §Acceptance Criteria, scoped to this story:*

- [ ] **AC-INPUT-1.1 [Logic] BLOCKING**: `project.godot [input]` block declares all 36 InputMap actions with their default bindings matching Section C of `design/gdd/input.md`; for every action row, `InputMap.action_has_event(action_name, event)` returns `true` for the listed default keyboard event AND for the listed default gamepad event (where present). Evidence: `tests/unit/core/input/input_action_catalog_test.gd` + fixture `tests/fixtures/input/expected_bindings.yaml`.
- [ ] **AC-INPUT-1.3 [Logic] BLOCKING**: `res://src/core/input/input_actions.gd` declares `class_name InputActions` and contains exactly **36 constants** (33 gameplay/UI + 3 debug); every constant value is a StringName literal (`&"name"`) that satisfies `InputMap.has_action(value)` when queried in a test scene. Evidence: `tests/unit/core/input/input_actions_constants_test.gd`.
- [ ] **AC-INPUT-9.1 [Config] BLOCKING**: `res://src/core/input/input_actions.gd` file exists with `class_name InputActions`; no system imports it via `preload("res://src/core/input/...")` literal path — all consumers use the `class_name` global. Evidence: `tests/unit/core/input/input_actions_path_test.gd` (file-existence + class_name check) + CI grep for `preload.*input_actions`.
- [ ] **AC-INPUT-5.3 [Code-Review] BLOCKING** (partial — debug action constants): debug action constants (`debug_toggle_ai`, `debug_noclip`, `debug_spawn_alert`) do NOT appear in `project.godot [input]` — they are runtime-registered only; the runtime registration block in `InputActions._register_debug_actions()` is wrapped in `if OS.is_debug_build():` AND uses `InputMap.add_action()` + `InputMap.action_add_event()` for each debug action. Evidence: `tools/ci/check_debug_action_gating.sh`.

---

## Implementation Notes

*Derived from ADR-0004 §Implementation Guidelines + GDD §Detailed Rules + GDD §Acceptance Criteria:*

**File to create**: `res://src/core/input/input_actions.gd`

```gdscript
## Static class declaring every InputMap action name as a typed StringName constant.
## Import via class_name InputActions — never via preload() literal path.
## Consumers: every system that reads InputMap actions project-wide.
class_name InputActions
extends RefCounted

# ── Group 1: Movement ──────────────────────────────────────────────────────
## Axis-based movement: read via Input.get_vector() in _physics_process.
const MOVE_FORWARD  := &"move_forward"
const MOVE_BACKWARD := &"move_backward"
const MOVE_LEFT     := &"move_left"
const MOVE_RIGHT    := &"move_right"
const LOOK_HORIZONTAL := &"look_horizontal"
const LOOK_VERTICAL   := &"look_vertical"
const JUMP    := &"jump"
const CROUCH  := &"crouch"
const SPRINT  := &"sprint"

# ── Group 2: Combat & Weapons ──────────────────────────────────────────────
## Press/Hold semantics: read via event.is_action_pressed() in _unhandled_input.
const FIRE_PRIMARY      := &"fire_primary"
const AIM_DOWN_SIGHTS   := &"aim_down_sights"
const RELOAD            := &"reload"
const WEAPON_SLOT_1     := &"weapon_slot_1"
const WEAPON_SLOT_2     := &"weapon_slot_2"
const WEAPON_SLOT_3     := &"weapon_slot_3"
const WEAPON_SLOT_4     := &"weapon_slot_4"
const WEAPON_SLOT_5     := &"weapon_slot_5"
const WEAPON_NEXT       := &"weapon_next"
const WEAPON_PREV       := &"weapon_prev"

# ── Group 3: Gadgets ───────────────────────────────────────────────────────
## takedown and use_gadget are DISTINCT actions on distinct default keys (Q / F).
## No shared-binding router. Two keys = no swallowed keystrokes (Pillar 3).
const TAKEDOWN          := &"takedown"
const USE_GADGET        := &"use_gadget"
const GADGET_NEXT       := &"gadget_next"
const GADGET_PREV       := &"gadget_prev"

# ── Group 4: Interaction ───────────────────────────────────────────────────
## ADR-0004 locked: E + JOY_BUTTON_A. Resolved by Player Character raycast priority.
const INTERACT          := &"interact"

# ── Group 5: UI & Menus ───────────────────────────────────────────────────
## ADR-0004 locked: ui_cancel = Esc + B/Circle; pause = Esc + START.
const UI_CANCEL         := &"ui_cancel"
const PAUSE             := &"pause"
const UI_UP             := &"ui_up"
const UI_DOWN           := &"ui_down"
const UI_LEFT           := &"ui_left"
const UI_RIGHT          := &"ui_right"
const UI_ACCEPT         := &"ui_accept"
const QUICKSAVE         := &"quicksave"
const QUICKLOAD         := &"quickload"

# ── Group 6: Debug (registered at runtime in debug builds only) ────────────
## These constants exist in the class but the actions are NOT in project.godot.
## _register_debug_actions() is called from the InputContext autoload _ready(),
## wrapped in `if OS.is_debug_build():`.
const DEBUG_TOGGLE_AI    := &"debug_toggle_ai"
const DEBUG_NOCLIP       := &"debug_noclip"
const DEBUG_SPAWN_ALERT  := &"debug_spawn_alert"

# ── Debug action registration ──────────────────────────────────────────────

## Registers debug InputMap actions at runtime. Called from InputContextStack._ready().
## Wrapped in OS.is_debug_build() at the call site — this method must NOT be
## called in release builds. Uses InputMap.add_action() + action_add_event()
## per GDD Core Rule 11. Validates with has_action() before add_event() per Core Rule 6.
static func _register_debug_actions() -> void:
    _register_debug_action(DEBUG_TOGGLE_AI,   KEY_F1)
    _register_debug_action(DEBUG_NOCLIP,      KEY_F2)
    _register_debug_action(DEBUG_SPAWN_ALERT, KEY_F3)

static func _register_debug_action(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var ev := InputEventKey.new()
    ev.keycode = keycode
    ev.pressed = true
    if InputMap.has_action(action):
        InputMap.action_add_event(action, ev)
```

**project.godot `[input]` block** must be populated with all 36 bindings matching GDD Section C. Key constraints:
- Every `ui_*` action must have BOTH KB/M AND gamepad bindings (ADR-0004 IG 14 / Finding F3).
- `ui_cancel` must declare `KEY_ESCAPE` + `InputEventJoypadButton(button_index=1)` (JOY_BUTTON_B).
- `interact` must declare `KEY_E` + `InputEventJoypadButton(button_index=0)` (JOY_BUTTON_A).
- `pause` must declare `KEY_ESCAPE` + `InputEventJoypadButton(button_index=11)` (JOY_BUTTON_START).
- Debug actions (`debug_toggle_ai`, `debug_noclip`, `debug_spawn_alert`) must NOT appear in the `[input]` block.
- Verify gamepad button indices against `docs/engine-reference/godot/` before finalizing — SDL3 driver change in 4.5 affects button-index mapping.

**Fixture to create**: `tests/fixtures/input/expected_bindings.yaml` — one row per action from GDD Section C, listing `action_name`, `kb_event_type`, `kb_event_value`, `gamepad_event_type`, `gamepad_event_value` (null where gamepad is not applicable). This fixture is the single source of truth for AC-INPUT-1.1 assertions; it must match GDD Section C exactly.

**`_register_debug_actions()` call site**: This static method is called from `InputContextStack._ready()` (Story 002), not from `InputActions` itself. This story only declares the static class and the method body. The call site is out-of-scope here and lands in Story 002.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `InputContextStack` autoload production implementation; `_register_debug_actions()` call site from `_ready()`
- Story 003: Integration tests for context-gated routing (AC-INPUT-2.2, 2.3, 3.1, 3.2)
- Story 004: Full CI grep enforcement scripts (`check_raw_input_constants.sh`, `check_action_literals.sh`)
- Story 006: Runtime rebinding API (VS scope) — `action_erase_events` + `action_add_event` tests
- AC-INPUT-1.2 (Code-Review grep CI script for unquoted string literals) lands in Story 004 alongside the other CI grep guards

---

## QA Test Cases

**AC-INPUT-1.1 — Action catalog integrity against project.godot**
- **Given**: the project loaded normally; `tests/fixtures/input/expected_bindings.yaml` present with 36 rows
- **When**: the test iterates every row and calls `InputMap.action_has_event(row.action_name, row.kb_event)` and `InputMap.action_has_event(row.action_name, row.gamepad_event)` (where gamepad_event is not null)
- **Then**: every call returns `true`; `InputMap.get_actions().size()` is at least 36 (project may include Godot built-in `ui_*` actions)
- **Edge cases**: missing action in `project.godot` → `InputMap.has_action()` returns false; wrong gamepad button_index → `action_has_event()` returns false; debug actions (`debug_*`) must NOT appear in `InputMap` in a non-debug headless test run (they are registered only in debug builds)

**AC-INPUT-1.3 — InputActions constants count + values**
- **Given**: `InputActions` script loaded via `class_name` global
- **When**: a test reflects on `InputActions` via `ClassDB` or direct constant enumeration (list all exported constants via `get_script_constant_map()` on an `InputActions` instance)
- **Then**: exactly 36 constants are declared; every constant value is a `StringName`; every constant satisfies `InputMap.has_action(value)` (skipping debug constants in non-debug build — use `if OS.is_debug_build()` guard in test)
- **Edge cases**: count ≠ 36 → test names missing constants in the failure message; duplicate `StringName` values (two constants pointing to same action name) → should be detectable via set-uniqueness check

**AC-INPUT-9.1 — File path + class_name + no preload**
- **Given**: the file `res://src/core/input/input_actions.gd` committed to the project
- **When**: a test calls `load("res://src/core/input/input_actions.gd")` and reads its `get_global_name()`
- **Then**: load returns non-null; `get_global_name() == &"InputActions"`
- **When**: CI grep runs `grep -rPn 'preload.*input_actions' src/ --include="*.gd"`
- **Then**: zero matches
- **Edge cases**: file not committed → `load()` returns null; wrong `class_name` declaration → `get_global_name()` returns `&""`

**AC-INPUT-5.3 (partial) — Debug actions absent from project.godot**
- **Given**: `project.godot` source
- **When**: grep checks `grep -n 'debug_toggle_ai\|debug_noclip\|debug_spawn_alert' project.godot`
- **Then**: zero matches — debug actions are not declared in the `[input]` block
- **Given**: `src/core/input/input_actions.gd`
- **When**: grep checks for `_register_debug_actions` definition body containing `OS.is_debug_build` — actually the call site is in Story 002; this check verifies the method uses `InputMap.add_action` + `InputMap.action_add_event`
- **Then**: the registration method body contains both `InputMap.add_action` and `InputMap.action_add_event` calls
- **Edge cases**: debug action accidentally added to `project.godot` → grep fires; `_register_debug_actions` missing `has_action` guard before `action_add_event` → Core Rule 6 violation (caught by Story 004's full CI suite)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/input/input_action_catalog_test.gd` — must exist and pass (AC-INPUT-1.1)
- `tests/unit/core/input/input_actions_constants_test.gd` — must exist and pass (AC-INPUT-1.3)
- `tests/unit/core/input/input_actions_path_test.gd` — must exist and pass (AC-INPUT-9.1)
- `tools/ci/check_debug_action_gating.sh` — must exist; CI passes with zero violations (AC-INPUT-5.3 partial)
- `tests/fixtures/input/expected_bindings.yaml` — must exist and reflect GDD Section C

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — foundational static class with no upstream system dependencies; `project.godot` stub must already have a `[input]` block (Sprint 01 scaffolding)
- Unlocks: Story 002 (`InputContextStack._ready()` calls `InputActions._register_debug_actions()`), Story 003 (integration tests reference `InputActions.*` constants), Story 004 (CI grep guards validate `InputActions` usage), all subsequent consumer epics (Player Character, Combat, Inventory, Menu System, Save/Load)
