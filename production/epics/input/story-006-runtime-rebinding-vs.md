# Story 006: Runtime rebinding API — Vertical Slice scope

> **Epic**: Input
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 hours (M — 4 integration + 1 unit test file; temp file I/O teardown required)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/input.md`
**Requirements**: `TR-INP-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework) + ADR-0003 (Save Format Contract)
**ADR Decision Summary**: Runtime rebinding uses `InputMap.action_erase_events(action)` + `InputMap.action_add_event(action, event)` called consecutively in the same function with no `await` between them (GDD Core Rule 6). Settings & Accessibility owns the rebinding UI and ConfigFile persistence to `user://settings.cfg [controls]` section (separate from SaveGame per ADR-0003 IG 10). Input owns the binding primitive (`has_event()` for conflict detection) and the held-key flush contract (Core Rule 9). Settings GDD owns the conflict-resolution UI and the SDL2→SDL3 migration story for legacy settings files.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `InputMap.action_erase_events()`, `InputMap.action_add_event()`, `InputMap.has_action()`, `InputMap.has_event()` are stable since Godot 4.0. `ConfigFile` for `user://settings.cfg` is stable since Godot 4.0. SDL3 gamepad driver change in 4.5 means gamepad button-index drift in legacy `settings.cfg` files — Settings GDD owns the migration story but tests in this epic that write/read gamepad bindings must use stable button-index constants. `Input.action_release()` is the correct API for the held-key flush (Core Rule 9); verify it exists in Godot 4.6 (`docs/engine-reference/godot/`). Test teardown MUST delete `user://test_settings.cfg` in `_exit_tree()` per `coding-standards.md` isolation rule — shared filesystem state contaminates subsequent test runs.

**Control Manifest Rules (Core)**:
- Required: `action_erase_events` + `action_add_event` called consecutively with no `await` between them (GDD Core Rule 6)
- Required: every `action_add_event()` call preceded by `InputMap.has_action()` guard (Core Rule 6 / AC-INPUT-6.2)
- Required: `Input.action_release(action_name)` called after every rebind commit (Core Rule 9 — prevents held-key ghost state)
- Required: test teardown deletes temp ConfigFile (`user://test_settings.cfg`) in `_exit_tree()`
- Forbidden: `await` between `action_erase_events` and `action_add_event` (GDD Core Rule 6 — transient-unbind hazard)
- Note: Gamepad rebinding parity is post-MVP per `technical-preferences.md` — this story implements and tests the KB/M rebinding path only; gamepad rebinding is out of scope

---

## Acceptance Criteria

*From GDD `design/gdd/input.md` §Acceptance Criteria, scoped to this story:*

- [ ] **AC-INPUT-4.1 [Logic] BLOCKING (VS)**: Fresh `InputMap` with `move_forward` bound to `W`; test calls `InputMap.action_erase_events(&"move_forward")` then `InputMap.action_add_event(&"move_forward", InputEventKey(T, pressed=true))`; injected `InputEventKey(T, pressed=true)` → `event.is_action_pressed(&"move_forward")` returns `true`; injected `InputEventKey(W, pressed=true)` → returns `false`. Evidence: `tests/unit/core/input/input_rebind_runtime_test.gd`.
- [ ] **AC-INPUT-4.2(a) [Logic] BLOCKING (VS)**: Conflict-detection primitive: attempt to rebind action A to event E already bound to action B; `InputMap.has_event(E)` returns `true` (Input owns this primitive; conflict-resolution UI is Settings scope per AC-INPUT-4.2(b) which belongs in Settings GDD). Evidence: `tests/unit/core/input/input_has_event_test.gd`.
- [ ] **AC-INPUT-4.3 [Integration] BLOCKING (VS)**: Clean test environment; `ProjectSettings.globalize_path("user://test_settings.cfg")` resolved to a temp path; test (a) writes known rebinding `move_forward → T` to that file, (b) restarts input loading from that path, (c) injects `InputEventKey(T)`; `event.is_action_pressed(&"move_forward")` returns `true`. Test tears down temp file in `_exit_tree()`. Evidence: `tests/integration/core/input/input_rebind_persistence_test.gd`.
- [ ] **AC-INPUT-4.4 [Integration] BLOCKING (VS) — full round-trip**: Clean test environment; sequence: (a) rebind `move_forward → T` via Settings API (or direct `InputMap` call), (b) write `user://test_settings.cfg`, (c) clear runtime `InputMap` for the action (`action_erase_events`), (d) re-load the cfg from disk, (e) inject `InputEventKey(T)`; `event.is_action_pressed(&"move_forward")` returns `true`. Round-trip atomic. Evidence: `tests/integration/core/input/rebind_round_trip_test.gd`.
- [ ] **AC-INPUT-7.3 [Integration] BLOCKING (VS)**: `Input.parse_input_event(InputEventKey(W, pressed=true))` with `move_forward → W` binding; test rebinds `move_forward → T` via `action_erase_events` + `action_add_event`; Settings calls `Input.action_release(&"move_forward")` immediately after; `Input.is_action_pressed(&"move_forward")` returns `false` until player presses `T` (Core Rule 9 held-key flush). Evidence: `tests/integration/core/input/rebind_held_key_flush_test.gd`.

---

## Implementation Notes

*Derived from GDD §Detailed Rules Core Rules 6, 9 + §Edge Cases (player rebinds while holding key):*

**What this story tests, NOT implements**: Settings & Accessibility (epic not yet authored) owns the runtime rebinding UI, conflict-resolution, and the persistence wire format. This story tests the **primitive APIs** that Settings will call: the `InputMap` erase/add pair, the `has_event()` conflict detection query, the ConfigFile round-trip shape, and the `Input.action_release()` held-key flush.

**ConfigFile persistence wire format** (Input's contract with Settings GDD):

`user://settings.cfg [controls]` section persists `InputEvent` subclass fields manually because `InputEvent` is not directly ConfigFile-serializable. Minimum required fields per subclass:
- `InputEventKey`: `keycode: int`, `physical_keycode: int`, `modifiers_mask: int`
- `InputEventMouseButton`: `button_index: int`, `modifiers_mask: int`
- `InputEventJoypadButton`: `button_index: int`

The wire format is a Settings GDD concern — this story only tests that a written + re-loaded binding results in the correct `is_action_pressed()` behavior. The test may use a simplified manual-serialization helper; Settings GDD will own the canonical implementation.

**No-await discipline** (AC-INPUT-4.1): the erase/add pair must be in the same function, no `await` between them. The test verifies the sequential call semantics. The CI check from Story 004 (AC-INPUT-6.2) gates the `action_add_event` → `has_action` guard; this story's test validates the functional behavior.

**Held-key flush** (AC-INPUT-7.3):
```gdscript
# Pattern Settings must use after every rebind commit:
InputMap.action_erase_events(&"move_forward")
InputMap.action_add_event(&"move_forward", new_event_T)
Input.action_release(&"move_forward")  # Core Rule 9 — flush ghost held state
```

**ConfigFile read/write helper** (test-only utility):
```gdscript
static func write_rebinding_to_cfg(path: String, action: StringName, keycode: Key) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("controls", str(action) + ".type", "key")
    cfg.set_value("controls", str(action) + ".keycode", keycode)
    cfg.save(path)

static func load_rebinding_from_cfg(path: String, action: StringName) -> InputEventKey:
    var cfg := ConfigFile.new()
    cfg.load(path)
    var ev := InputEventKey.new()
    ev.keycode = cfg.get_value("controls", str(action) + ".keycode", KEY_NONE) as Key
    return ev
```
This is a simplified test helper — not the production implementation. Settings GDD owns the canonical format.

**Gamepad rebinding parity** is explicitly post-MVP per `technical-preferences.md`. Do not add gamepad rebinding tests in this story. The gamepad conflict-detection path (AC-INPUT-4.2(a) for gamepad events) is technically available via `InputMap.has_event()` but the end-to-end rebinding flow for gamepad is out of scope.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 005: AC-INPUT-7.3's prerequisite pattern (held-key persistence) — established there; Story 006 extends it with the flush call
- Settings & Accessibility epic: production rebinding UI, conflict-resolution UI (AC-INPUT-4.2(b)), persistence wire format ownership, SDL2→SDL3 migration, `user://settings.cfg` format versioning, hold-to-toggle accessibility (Core Rule 9), dynamic glyph swapping
- Post-MVP: full gamepad rebinding parity — including chord bindings for weapon slots, button-index-drift migration in existing settings files

---

## QA Test Cases

**AC-INPUT-4.1 — Rebind replaces old binding**
- **Given**: `move_forward` bound to `W` in `project.godot`; `InputMap.action_erase_events(&"move_forward")` then `InputMap.action_add_event(&"move_forward", InputEventKey(KEY_T, pressed=true))` called in sequence, no await
- **When**: `InputEventKey(KEY_T, pressed=true)` injected
- **Then**: `event.is_action_pressed(&"move_forward")` returns `true`
- **When**: `InputEventKey(KEY_W, pressed=true)` injected
- **Then**: returns `false`
- **Teardown**: restore `move_forward → W` binding after test (to avoid polluting catalog tests from Story 001)
- **Edge cases**: `await` accidentally inserted between erase/add (would cause action to be transiently unbound — the test itself does not exercise this path, but the CI linter from Story 004 catches it in production code)

**AC-INPUT-4.2(a) — has_event() conflict detection**
- **Given**: `move_forward` bound to `W`; another action `sprint` is NOT bound to `W`
- **When**: `InputMap.has_event(InputEventKey(KEY_W))` called (note: check Godot 4.6 API for `has_event` vs `action_has_event` — verify the correct method name against `docs/engine-reference/godot/`)
- **Then**: returns `true` (the event IS already bound to an action)
- **When**: `InputMap.has_event(InputEventKey(KEY_X))` called (X is not bound to any action)
- **Then**: returns `false`
- **Edge cases**: Godot 4.6 `InputMap` does not have a top-level `has_event()` — it may be `action_has_event(action_name, event)` per action. Verify the correct API for "does any action have this event?" before implementing; if it requires iterating over all actions, document the approach in the test

**AC-INPUT-4.3 — Persistence load from ConfigFile**
- **Given**: temp file at `user://test_settings.cfg` with `move_forward → KEY_T` written via test helper
- **When**: test restarts InputMap loading from that path (or simulates a load by applying the cfg to the InputMap manually)
- **Then**: `InputEventKey(KEY_T, pressed=true)` causes `event.is_action_pressed(&"move_forward")` to return `true`
- **Teardown**: delete `user://test_settings.cfg` in `_exit_tree()`
- **Edge cases**: file not found → `ConfigFile.load()` returns error; test must handle gracefully and fail clearly; keycode stored as int but loaded as float (ConfigFile type drift) → add explicit int cast in the read path

**AC-INPUT-4.4 — Full round-trip: rebind → write → clear → reload → verify**
- **Given**: clean test environment; `move_forward → W` as baseline
- **When**: sequence (a)-(e) per AC-INPUT-4.4
- **Then**: `InputEventKey(KEY_T, pressed=true)` → `event.is_action_pressed(&"move_forward")` = `true` after reload
- **Teardown**: restore `move_forward → W`; delete temp cfg
- **Edge cases**: step (c) clears the runtime binding — test must not query `is_action_pressed` between step (c) and (d) (action is transiently unbound); assert the final state only after step (e)

**AC-INPUT-7.3 — Held-key flush on rebind**
- **Given**: `Input.parse_input_event(InputEventKey(KEY_W, pressed=true))` called; `Input.is_action_pressed(&"move_forward")` returns `true`
- **When**: rebind sequence: `InputMap.action_erase_events(&"move_forward")`, `InputMap.action_add_event(&"move_forward", InputEventKey(KEY_T))`, `Input.action_release(&"move_forward")`
- **Then**: `Input.is_action_pressed(&"move_forward")` returns `false` (flush cleared the ghost state)
- **When**: `Input.parse_input_event(InputEventKey(KEY_T, pressed=true))` injected
- **Then**: `Input.is_action_pressed(&"move_forward")` returns `true` (new binding active)
- **Teardown**: release T key; restore `move_forward → W`
- **Edge cases**: `Input.action_release()` not called → `is_action_pressed` may still return `true` after rebind (the failure case this rule prevents; optionally add a "wrong behavior" subtest to document)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/core/input/input_rebind_runtime_test.gd` — must exist and pass (AC-INPUT-4.1)
- `tests/unit/core/input/input_has_event_test.gd` — must exist and pass (AC-INPUT-4.2a)
- `tests/integration/core/input/input_rebind_persistence_test.gd` — must exist and pass (AC-INPUT-4.3)
- `tests/integration/core/input/rebind_round_trip_test.gd` — must exist and pass (AC-INPUT-4.4)
- `tests/integration/core/input/rebind_held_key_flush_test.gd` — must exist and pass (AC-INPUT-7.3)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (InputActions constants), Story 002 (InputContextStack autoload), Story 005 (held-key pattern from AC-INPUT-5.1 provides the test pattern extended by AC-INPUT-7.3)
- Unlocks: Settings & Accessibility epic (uses the rebinding primitive APIs tested here); the conflict-resolution UI (AC-INPUT-4.2(b)) belongs in Settings GDD as AC-SA-6.3 per GDD note
