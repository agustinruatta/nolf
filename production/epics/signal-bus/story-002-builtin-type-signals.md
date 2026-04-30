# Story 002: Built-in-type signal declarations on `events.gd`

> **Epic**: Signal Bus
> **Status**: Complete (2026-04-30)
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-30 (rolled forward from 2026-04-29 by `/dev-story` 2026-04-30 — Foundation rules unchanged; additive Feature/Presentation/Polish updates only)

## Context

**GDD**: `design/gdd/signal-bus.md`
**Requirement**: Signal Bus AC 3 (partial — only the built-in-type subset of the 40-signal taxonomy)

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) §Key Interfaces
**ADR Decision Summary**: 40 typed signals across 9 gameplay domains + 3 infrastructure domains (Persistence, Settings, UI). Each signal declared with exact name + parameter types + parameter order. Enums in payloads are owned by the concept's class (e.g., `StealthAI.AlertState`), never by the bus.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript signal declarations resolve types at parse time. References to enum classes that don't exist (`StealthAI.AlertState`, `CombatSystemNode.DeathCause`, etc.) cause parse failure. **This story declares only signals whose payloads use built-in types.** Domain-specific typed signals land in paired commits with each consumer epic.

**Control Manifest Rules (Foundation)**:
- Required: signal signatures use explicit types — `: Variant` permitted only on `setting_changed` (the documented Variant exception)
- Required: signal naming follows `subject_verb_past` convention (e.g., `health_changed`, `document_collected`)
- Forbidden: never define enums on `events.gd` (pattern `event_bus_enum_definition`)
- Performance: all 40 signals analyzed in ADR-0002 §Performance Implications — within budget at expected emit frequencies

---

## Acceptance Criteria

*From GDD AC 3, scoped to the built-in-type subset for this story:*

- [ ] **AC-3-A**: All Player domain signals declared (`player_interacted(target: Node3D)`, `player_footstep(surface: StringName, noise_radius_m: float)`)
- [ ] **AC-3-B**: All Documents domain signals declared (`document_collected(document_id: StringName)`, `document_opened(document_id: StringName)`, `document_closed(document_id: StringName)`)
- [ ] **AC-3-C**: All Mission domain signals **except** `section_entered`/`section_exited` declared (`objective_started(objective_id: StringName)`, `objective_completed(objective_id: StringName)`, `mission_started(mission_id: StringName)`, `mission_completed(mission_id: StringName)`, `scripted_dialogue_trigger(scene_id: StringName)`, `cutscene_started(scene_id: StringName)`, `cutscene_ended(scene_id: StringName)`). Note: `section_entered/exited` deferred to Level Streaming epic (depends on `LevelStreamingService.TransitionReason`).
- [ ] **AC-3-D**: All Failure & Respawn domain signals declared (`respawn_triggered(section_id: StringName)`)
- [ ] **AC-3-E**: All Dialogue domain signals declared (`dialogue_line_started(speaker_id: StringName, line_id: StringName)`, `dialogue_line_finished(speaker_id: StringName)`)
- [ ] **AC-3-F**: Inventory domain signals **except** those needing weapon-id type lookups: `gadget_equipped(gadget_id: StringName)`, `gadget_used(gadget_id: StringName, position: Vector3)`, `weapon_switched(weapon_id: StringName)`, `ammo_changed(weapon_id: StringName, current: int, reserve: int)`, `gadget_activation_rejected(gadget_id: StringName)`, `weapon_dry_fire_click(weapon_id: StringName)`
- [ ] **AC-3-G**: Combat domain signals using only built-in types: `player_health_changed(current: float, max_health: float)`, `enemy_damaged(enemy: Node, amount: float, source: Node)`, `enemy_killed(enemy: Node, killer: Node)`, `weapon_fired(weapon: Resource, position: Vector3, direction: Vector3)`, `player_damaged(amount: float, source: Node, is_critical: bool)`. **Defer**: `player_died(cause: CombatSystemNode.DeathCause)` — needs Combat epic's enum.
- [ ] **AC-3-H**: Civilian domain signals using only built-in types: `civilian_panicked(civilian: Node, cause_position: Vector3)`. **Defer**: `civilian_witnessed_event` (needs `CivilianAI.WitnessEventType`).
- [ ] **AC-3-I**: Persistence domain signals using only built-in types: `game_saved(slot: int, section_id: StringName)`, `game_loaded(slot: int)`. **Defer**: `save_failed(reason: SaveLoad.FailureReason)` — needs Save/Load epic's enum (Save/Load epic IS in Foundation, may land in same milestone — see Dependencies).
- [ ] **AC-3-J**: Settings domain signals: `setting_changed(category: StringName, name: StringName, value: Variant)` (the SOLE Variant payload), `settings_loaded()` (no payload).

**Total: ~25 of 40 signals declared in this story.** The remaining ~15 typed signals land with consumer epics:
- AI/Stealth domain (6 signals): with Stealth AI epic — all reference `StealthAI.*` enums
- `section_entered/exited` (Mission domain): with Level Streaming epic — references `LevelStreamingService.TransitionReason`
- `player_died`: with Combat epic — references `CombatSystemNode.DeathCause`
- `civilian_witnessed_event`: with Civilian AI epic — references `CivilianAI.WitnessEventType`
- `save_failed`: with Save/Load epic in same Foundation milestone (or earlier if `SaveLoad.FailureReason` enum lands first)
- `ui_context_changed`: with UI Framework epic — references `InputContext.Context`

---

## Implementation Notes

*Derived from ADR-0002 §Key Interfaces:*

1. Replace the Sprint 01 skeleton's `smoke_test_pulse` with the production signals from the AC subset above. Group signals by domain with section comments matching ADR-0002 §Key Interfaces (`# ─── Combat domain ───`, etc.).
2. Preserve exact signatures from ADR-0002 §Key Interfaces verbatim (parameter names, types, and order). Code review rejects any deviation.
3. Each signal declaration is a single line — no docstrings, no inline comments past the signal line. Domain-section comments are above the group, not on the signal lines.
4. `Resource` parameter on `weapon_fired(weapon: Resource, ...)` is intentional — `Resource` is built-in; the actual weapon class lands later as a `WeaponData extends Resource` and is type-compatible with the `Resource` annotation here.
5. **Do not declare deferred signals** even as commented stubs. Each consumer epic adds its own domain in a paired commit.
6. After this story lands, `events.gd` declares ~25 signals; the file is ~80–100 lines. Story 003's EventLogger updates to subscribe to these signals.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload registration + structural purity (already done before this story starts)
- Story 003: EventLogger updates to subscribe to these signals
- Story 005: schema integrity automated grep tests (AC 13, 14)
- Each consumer epic: domain-specific typed signals using class-owned enums

---

## QA Test Cases

**AC-3-A through AC-3-J**: Signal declarations match ADR-0002 §Key Interfaces verbatim
- **Given**: `src/core/signal_bus/events.gd` after this story is implemented
- **When**: a parse-time test instantiates `SignalBusEvents` and inspects each signal's signature via `Object.get_signal_list()`
- **Then**: each declared signal exists with exact name + correct parameter count + correct parameter types (built-in only)
- **Edge cases**: parameter type mismatch (e.g., `int` vs `StringName`); parameter order swap; renamed signal that breaks grep against ADR-0002

**Combined integrity check (cross-cutting AC 3 partial)**:
- **Given**: parsed `Events` autoload + ADR-0002 §Key Interfaces canonical list
- **When**: an automated test compares signal signatures against the ADR's canonical set, scoped to non-deferred signals
- **Then**: every signal in the in-scope subset matches; deferred signals are not present (they land in their respective epic's commits)
- **Edge cases**: a signal accidentally added with a deferred type (parse fails — clear error); a deferred signal is added prematurely (test catches it)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/events_signal_taxonomy_test.gd` — must exist and pass; verifies the in-scope subset of the 40-signal taxonomy

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload registration finalized)
- Unlocks: Story 003 (EventLogger needs real signals to subscribe to), Story 006 (edge case tests use real signals)
- Cross-epic: AC 3 fully closes only after Stealth AI, Combat, Level Streaming, Civilian AI, Save/Load, and UI Framework epics each ship their domain signals

---

## Completion Notes

**Completed**: 2026-04-30
**Criteria**: 10/10 passing — all AC verified by automated tests
**Test Evidence (Logic — BLOCKING)**:
- `tests/unit/foundation/events_signal_taxonomy_test.gd` — 11 test functions covering AC-3-A through AC-3-J + deferred-absence guard
- Test suite hardened post-code-review: `class_name` discrimination added for all 6 TYPE_OBJECT signal args (`player_interacted`, `enemy_damaged`, `enemy_killed`, `weapon_fired`, `player_damaged`, `civilian_panicked`) — distinguishes `Node` from `Node3D` from `Resource` per qa-tester finding
- Suite result: 23/23 PASS, 0 errors, 0 failures
**Deviations**:
- ADVISORY: `cutscene_started`/`cutscene_ended` placed under dedicated `# ─── Cutscenes domain ───` banner rather than under Mission (per ADR-0002 amendment 2026-04-29 which added Cutscenes as a separate domain). Test grouping under AC-3-C remains correct.
- ADVISORY: `signal save_failed(reason: int)` removed from the bus along with the SB-001 skeleton cleanup. The Save/Load epic (Story SL-001+) will re-add it as `signal save_failed(reason: SaveLoad.FailureReason)` once the `FailureReason` enum lands. Until then `save_failed` is intentionally absent — verified by `test_events_taxonomy_deferred_signals_not_present`.
**Code Review**: Complete (`/code-review` 2026-04-30 — APPROVED WITH SUGGESTIONS; class_name discrimination gap fixed before this report)
**Manifest version**: rolled forward 2026-04-29 → 2026-04-30 during `/dev-story` (Foundation rules unchanged)
**Final signal count**: 31 in-scope signals across 9 domains (Player, Documents, Mission, Cutscenes, Failure & Respawn, Dialogue, Inventory, Combat, Civilian, Persistence, Settings). Remaining ~10–12 deferred signals land in paired commits with consumer epics.
