# Story 003: RaycastProvider DI interface + PerceptionCache struct

> **Epic**: Stealth AI
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (M — 3 new files, DI pattern, cold-start tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-016`, `TR-SAI-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) — Accessor Conventions carve-out; coding standards (DI over singletons per `.claude/docs/coding-standards.md`)
**ADR Decision Summary**: `PhysicsDirectSpaceState3D.intersect_ray` is an engine built-in and cannot be monkey-patched for testability. The perception system exposes an `IRaycastProvider` DI seam so unit tests can substitute a `CountingRaycastProvider` that scripted results without touching the physics engine. All public accessors (`has_los_to_player`, `takedown_prompt_active`) read from `_perception_cache` — no new raycast per call. The cache is updated once per physics frame by F.1.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `PhysicsDirectSpaceState3D` is obtained via `get_world_3d().direct_space_state` in `_ready()` or the first physics frame — NOT stored from `_init()` (space state is only valid inside the scene tree). In Godot 4.6, `PhysicsRayQueryParameters3D.create(from, to, mask, exclude)` is the idiomatic constructor. The `exclude` array should include the guard's own RID (`[get_rid()]`) to prevent the guard self-reporting as an occluder. `Engine.get_physics_frames()` is stable (used for frame_stamp in the cache).

**Control Manifest Rules (Feature)**:
- Required (global — coding standards): public methods are unit-testable via DI; prefer DI over singletons/autoloads for system-internal collaborators
- Required (global — coding standards): static typing required on all GDScript — every `var` declares its type; every function declares parameter types and return type
- Guardrail: the `CountingRaycastProvider` is a test-only type; it MUST NOT appear in production scene files or exported vars

---

## Acceptance Criteria

*From GDD `design/gdd/stealth-ai.md` §F.1 (RaycastProvider DI interface) + §F.1 (Perception cache struct) + TR-SAI-016 + TR-SAI-017:*

- [ ] **AC-1**: `res://src/gameplay/stealth/raycast_provider.gd` declares three classes (one per file or split into separate files — GDD OQ-SAI-8 recommends one file for the three closely-related types):
  - `class_name IRaycastProvider extends RefCounted` with `func cast(query: PhysicsRayQueryParameters3D) -> Dictionary` that calls `push_error` and returns `{}`.
  - `class_name RealRaycastProvider extends IRaycastProvider` with `_space_state: PhysicsDirectSpaceState3D` initialized via `_init(space_state)`, and `cast` delegating to `_space_state.intersect_ray(query)`.
  - `class_name CountingRaycastProvider extends IRaycastProvider` with `call_count: int = 0` and `scripted_result: Dictionary = {}`, incrementing `call_count` on each `cast()` call and returning `scripted_result`.
- [ ] **AC-2**: `res://src/gameplay/stealth/perception_cache.gd` declares `class_name PerceptionCache extends RefCounted` with typed fields:
  ```gdscript
  var initialized: bool = false
  var frame_stamp: int = 0
  var los_to_player: bool = false
  var los_to_player_position: Vector3 = Vector3.ZERO
  var los_to_dead_bodies: Dictionary = {}  ## instance_id: int -> bool
  var last_sight_stimulus_cause: StealthAI.AlertCause = StealthAI.AlertCause.SAW_PLAYER
  var last_sight_position: Vector3 = Vector3.ZERO
  ```
- [ ] **AC-3**: `res://src/gameplay/stealth/perception.gd` declares `class_name Perception extends Node` with `func init(raycast_provider: IRaycastProvider) -> void` that stores the provider. After `init` is called, the `Perception` node holds a reference to the injected provider and calls `raycast_provider.cast(...)` instead of calling `direct_space_state.intersect_ray` directly.
- [ ] **AC-4** (AC-SAI-3.9.d cold-start): Before `init` has been called and before F.1 has ever ticked, `_perception_cache.initialized == false` and `has_los_to_player()` returns `false` safely (no crash, no error log). `CountingRaycastProvider.call_count` remains 0 — no raycast issued from the accessor on cold-start.
- [ ] **AC-5** (AC-SAI-3.9.a + AC-SAI-3.9.b): GIVEN `_perception_cache.initialized == true` and `los_to_player == true` (populated by a prior F.1 tick), WHEN `has_los_to_player()` is called, THEN returns `true` AND `call_count` is unchanged (cache-hit path). GIVEN `los_to_player == false`, WHEN accessor called, THEN returns `false` AND `call_count` unchanged.
- [ ] **AC-6** (AC-SAI-3.9.c stale-by-1-frame): The cache frame_stamp is the `Engine.get_physics_frames()` value at last write. Accessors invoked between physics frames (e.g., at a 10 Hz idle tick) receive a value at most 1 frame old. Unit test: write `los_to_player = true` with a known `frame_stamp`, advance simulated frame counter by 1, call accessor — asserts it returns the stale cached value without issuing a new raycast.
- [ ] **AC-7**: `RealRaycastProvider._init` requires a valid `PhysicsDirectSpaceState3D`. In production, this is obtained in `_ready()` via `get_world_3d().direct_space_state` — NEVER from `_init()` of the guard script (space state is unavailable before the node enters the tree).

---

## Implementation Notes

*Derived from GDD §F.1 (RaycastProvider DI interface section) + coding standards:*

The three `IRaycastProvider` types are small enough to coexist in one file but GDScript's `class_name` registration requires top-level declarations. Use three separate files:
- `src/gameplay/stealth/raycast_provider.gd` — `IRaycastProvider`
- `src/gameplay/stealth/real_raycast_provider.gd` — `RealRaycastProvider`
- `src/gameplay/stealth/counting_raycast_provider.gd` — `CountingRaycastProvider` (test-only; not referenced in any `.tscn`)

Alternatively, GDScript inner classes are permitted if they all live in one file without individual `class_name` registrations — but Story 004's test harness needs `CountingRaycastProvider` resolvable by name. Use separate files.

The `Perception` node's `init(provider)` method must be called before the first physics frame where F.1 runs. In production, `Guard._ready()` does:
```gdscript
var space_state := get_world_3d().direct_space_state
var provider := RealRaycastProvider.new(space_state)
$Perception.init(provider)
```

In unit tests, the harness does:
```gdscript
var counter := CountingRaycastProvider.new()
guard.get_node("Perception").init(counter)
```

The `@abstract` annotation (GDScript 4.5+) is available and appropriate for `IRaycastProvider.cast()` but the GDD spec uses `push_error` for the base implementation — use whichever approach avoids the error in test harnesses. Recommended: `@abstract` on `IRaycastProvider` (prevents instantiation); remove the `push_error` body.

`PhysicsRayQueryParameters3D` `exclude` array should contain `[guard.get_rid()]` to prevent the guard body from occluding its own vision raycast. Do NOT include `eve_rid` in the exclude array — Eve IS a valid hit target (LOS to player = true when the ray reaches Eve).

Raycast mask for LOS: `PhysicsLayers.MASK_AI_VISION_OCCLUDERS` (composite constant defined in ADR-0006 — includes LAYER_WORLD but excludes LAYER_PLAYER and LAYER_AI so the ray passes through other guards and civilians to reach Eve, but stops at world geometry).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: F.1 sight fill formula (calls `perception.raycast_provider.cast(...)` but is implemented in Story 004)
- Story 005: `has_los_to_player()` method body (reads `_perception_cache` — wired in Story 005)
- Story 006: `takedown_prompt_active()` method body (uses cache + arc math — wired in Story 006)
- Post-VS: dead-body LOS entries (`los_to_dead_bodies` dict) — present in the struct schema but only populated once SAW_BODY mechanics are needed (no body to find in VS)

---

## QA Test Cases

**AC-1 — IRaycastProvider base class error**
- Given: `IRaycastProvider.new()` instantiation (if not `@abstract`)
- When: `cast(PhysicsRayQueryParameters3D.new())` called on the base instance
- Then: `push_error` fires and `{}` is returned (base implementation guard)
- Edge cases: `@abstract` annotation instead → direct instantiation causes GDScript error; subclass must override

**AC-2 — PerceptionCache field types**
- Given: `PerceptionCache.new()`
- When: field values read immediately after construction
- Then: `initialized == false`, `frame_stamp == 0`, `los_to_player == false`, `los_to_player_position == Vector3.ZERO`, `los_to_dead_bodies == {}`, `last_sight_position == Vector3.ZERO`
- Edge cases: wrong type annotation (e.g., `los_to_player: int`) → GDScript static-typing error at assignment

**AC-4 — Cold-start safe-false**
- Given: a `Perception` node with no `init` call yet (or `_perception_cache.initialized == false`)
- When: `has_los_to_player()` is called
- Then: returns `false`; no crash; `CountingRaycastProvider.call_count == 0` if provider injected; no `push_error` or `push_warning` in output
- Edge cases: accessed before `_ready()` completes → must not crash (guard `is_node_ready()` or initialized flag)

**AC-5 — Cache-hit path (no raycast issued)**
- Given: `_perception_cache.initialized = true`, `los_to_player = true`, `CountingRaycastProvider` injected
- When: `has_los_to_player()` called 3 times
- Then: returns `true` all 3 times; `call_count == 0` (no new raycasts from accessor path)
- Edge cases: cache corrupted (initialized=true but frame_stamp stale) → stale-by-1-frame is acceptable; test documents this explicitly

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_has_los_accessor_test.gd` — AC-SAI-3.9 (5 scenarios)
- `tests/unit/feature/stealth_ai/raycast_provider_test.gd` — DI interface + CountingRaycastProvider call counting

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (needs `StealthAI.AlertCause` for `PerceptionCache.last_sight_stimulus_cause` type)
- Unlocks: Story 004 (F.1 sight fill injects `IRaycastProvider` via the `Perception` node), Story 005 (`has_los_to_player` reads from `PerceptionCache`)
