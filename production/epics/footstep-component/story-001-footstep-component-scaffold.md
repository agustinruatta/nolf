# Story 001: FootstepComponent node scaffold + parent assertion

> **Epic**: FootstepComponent
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 1-2 hours (S — new script file + one test file)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/footstep-component.md`
**Requirement**: `TR-FC-001` (partial — node existence and emission infrastructure), `TR-FC-008` (surface metadata authoring contract consumed at runtime; parent-assertion validates correct attachment)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0006 (Collision Layer Contract)
**ADR Decision Summary**: FootstepComponent is a `Node` child of `PlayerCharacter` that publishes `Events.player_footstep(surface: StringName, noise_radius_m: float)` through the `Events` autoload (ADR-0002). It uses `PhysicsLayers.MASK_FOOTSTEP_SURFACE` for its downward raycast (ADR-0006). It does NOT implement any state mutation on PlayerCharacter. Per ADR-0002 IG 3, FootstepComponent connects to no signals — it is a pure publisher with no subscriptions.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Node` child lifecycle, `_ready()` parent type assertion, `push_error()` / `is_instance_valid()` are all stable Godot 4.0+. No post-cutoff APIs involved in scaffolding. `get_parent() is PlayerCharacter` requires the `class_name PlayerCharacter` to be resolvable at import time — ensure PlayerCharacter script is committed before or alongside this story. `PhysicsLayers` class exists at `res://src/core/physics_layers.gd` (verified Sprint 01).

**Control Manifest Rules (Core)**:
- Required: every gameplay script touching `PhysicsRayQueryParameters3D.collision_mask` MUST reference `PhysicsLayers.*` constants — ADR-0006 IG 1
- Required: static typing on all GDScript `var` and function signatures — Global Rules
- Required: doc comments on all public classes and exported properties — Global Rules
- Forbidden: hardcoded integer layer numbers in gameplay code — `hardcoded_physics_layer_number`
- Forbidden: attaching FootstepComponent to any node that is not a direct child of `PlayerCharacter` — GDD Forbidden Patterns

---

## Acceptance Criteria

*From GDD `design/gdd/footstep-component.md` §Acceptance Criteria, scoped to scaffold:*

- [ ] **AC-1** (AC-FC-6.1): `src/gameplay/player/footstep_component.gd` declares `class_name FootstepComponent extends Node`. Its `_ready()` asserts `get_parent() is PlayerCharacter`; when the assertion fails it calls `push_error("FootstepComponent must be a direct child of PlayerCharacter")` AND sets `_is_disabled = true`.
- [ ] **AC-2** (AC-FC-6.1): When `_is_disabled == true`, subsequent `_physics_process` ticks emit zero `Events.player_footstep` signals (no null-deref cascade from an invalid parent).
- [ ] **AC-3** (scaffold completeness): The script declares all instance fields required by downstream stories with correct static types: `_is_disabled: bool`, `_step_accumulator: float`, `_player: PlayerCharacter` (typed reference set in `_ready`), `CADENCE_BY_STATE: Dictionary` (populated in `_ready` from exported cadence knobs), and the four exported knobs (`cadence_walk_hz: float = 2.2`, `cadence_sprint_hz: float = 3.0`, `cadence_crouch_hz: float = 1.6`, `surface_raycast_depth_m: float = 2.0`).
- [ ] **AC-4** (static typing + doc comments): every public method and exported property has a doc comment; no untyped `var` declarations.

---

## Implementation Notes

*Derived from GDD §Detailed Design (Core Rules), §Formulas (FC.1), and ADR-0006 §Key Interfaces:*

**File location**: `src/gameplay/player/footstep_component.gd` (sibling of `player_character.gd` per EPIC.md §Definition of Done; match PlayerCharacter scene structure).

**Scaffold structure**:

```gdscript
## FootstepComponent — child node of PlayerCharacter.
## Emits Events.player_footstep(surface, noise_radius_m) each step.
## Per ADR-0002: sole publisher of player_footstep; Audio lane only.
## Per GDD footstep-component.md §Core Rules: does NOT mutate player state.
class_name FootstepComponent extends Node

## Walk cadence in Hz. Safe range: 1.8–2.8. Owned by Audio Director.
@export var cadence_walk_hz: float = 2.2
## Sprint cadence in Hz. Safe range: 2.5–3.6. Owned by Audio Director.
@export var cadence_sprint_hz: float = 3.0
## Crouch cadence in Hz. Safe range: 1.2–2.0. Owned by Audio Director.
@export var cadence_crouch_hz: float = 1.6
## Downward ray depth in metres. Safe range: 1.0–4.0. Owned by Gameplay Programmer.
@export var surface_raycast_depth_m: float = 2.0

## Typed parent reference set in _ready.
var _player: PlayerCharacter
## If true, _ready() assertion failed — all _physics_process ticks are no-ops.
var _is_disabled: bool = false
## Seconds accumulated since last step emission.
var _step_accumulator: float = 0.0
## Precomputed state→interval dictionary (seconds per step per state).
var CADENCE_BY_STATE: Dictionary = {}
```

**`_ready()` logic**:
1. Assert `get_parent() is PlayerCharacter`. On failure: `push_error(...)`, `_is_disabled = true`, `return`.
2. Assign `_player = get_parent() as PlayerCharacter`.
3. Populate `CADENCE_BY_STATE`: `{ PlayerEnums.MovementState.WALK: 1.0 / cadence_walk_hz, ... }`. This is the only place cadence values are computed — do not recompute per frame.

**`_physics_process(delta)` stub**: check `_is_disabled` first; return immediately if true. Remaining cadence logic lands in Story 002.

**No signal connections in this script** — FootstepComponent is a pure publisher with no subscriptions (per ADR-0002 IG 3 consumer-side rule; FootstepComponent is not a subscriber).

**PlayerEnums import**: GDD references `PlayerEnums.MovementState`. Confirm the enum lives on `PlayerCharacter` directly or on a `PlayerEnums` helper class alongside `player_character.gd` before writing this story — the import path determines the `CADENCE_BY_STATE` key type. If `MovementState` is an inner enum on `PlayerCharacter`, keys are `PlayerCharacter.MovementState.WALK` etc. (see Open Questions).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: step cadence `_physics_process` loop, phase-preservation accumulator, suppression guards (Idle/Jump/Fall/Dead)
- Story 003: `_resolve_surface_tag()` downward raycast implementation, surface tag vocabulary
- Story 004: `_emit_footstep()` signal emission, noise_radius_m mirroring, emission-rate guard, integration test with Audio subscriber

---

## QA Test Cases

*Logic story — automated test specs:*

**AC-1 + AC-2**: FootstepComponent parent assertion
- **Given**: a `FootstepComponent` node attached to a bare `Node3D` (not a `PlayerCharacter`)
- **When**: the scene tree processes `_ready()`
- **Then**: `_is_disabled == true`; `push_error` was called (verify via GUT's `assert_error_emitted` or a spy on `push_error`); a subsequent manual call to `_physics_process(0.016)` emits zero `Events.player_footstep` signals (assert signal spy count == 0)
- **Edge cases**: `get_parent()` returns `null` (bare `add_child` before entering tree) — should also set `_is_disabled = true` without null-deref

**AC-3**: Scaffold fields exist with correct types
- **Given**: `FootstepComponent.new()` instantiated
- **When**: a unit test reads property metadata via `get_property_list()`
- **Then**: all 4 exported knobs present with correct default values (`cadence_walk_hz == 2.2`, `cadence_sprint_hz == 3.0`, `cadence_crouch_hz == 1.6`, `surface_raycast_depth_m == 2.0`); `_is_disabled` defaults to `false`; `_step_accumulator` defaults to `0.0`
- **Edge cases**: a missing `@export` causes the knob to not appear in the inspector (non-blocking but breaks designer workflow)

**AC-4**: Static typing — automated lint check
- **Given**: `src/gameplay/player/footstep_component.gd` source
- **When**: a CI grep test scans for untyped `var ` declarations (lines matching `^\s*var [^:]*$` pattern, excluding comments)
- **Then**: zero matches
- **Edge cases**: `var _player` without `: PlayerCharacter` type annotation — must fail the lint

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/footstep_component/footstep_parent_assertion_test.gd` — must exist and pass (AC-1, AC-2)
- `tests/unit/core/footstep_component/footstep_scaffold_fields_test.gd` — must exist and pass (AC-3, AC-4)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: PlayerCharacter script (`src/gameplay/player/player_character.gd`) must be committed so `get_parent() is PlayerCharacter` resolves; `PhysicsLayers` class at `res://src/core/physics_layers.gd` (verified Sprint 01).
- Unlocks: Story 002 (cadence loop requires the scaffold fields and `_player` reference), Story 003 (surface resolution uses `_player.global_transform.origin`)
