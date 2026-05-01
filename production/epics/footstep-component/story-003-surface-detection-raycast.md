# Story 003: Surface detection raycast + tag vocabulary

> **Epic**: FootstepComponent
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (M — raycast implementation + 4 test files; mock physics space required)
> **Manifest Version**: 2026-04-30
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/footstep-component.md`
**Requirement**: `TR-FC-003` (surface detection via downward `PhysicsRayQueryParameters3D` on `MASK_FOOTSTEP_SURFACE` from 0.05 m below capsule center to 2.0 m depth; one cast per step not per frame), `TR-FC-004` (surface tag vocabulary: marble, tile, wood_stage, carpet, metal_grate, gravel, water_puddle, default — StringName interned), `TR-FC-008` (surface metadata via `body.get_meta("surface_tag", &"default")` on collision bodies; level-designer tool plugin provides mass-assign per LS CR-10)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract)
**ADR Decision Summary**: The footstep raycast uses `PhysicsLayers.MASK_FOOTSTEP_SURFACE` (defined as `MASK_WORLD` = `1 << 0` = 1 in `src/core/physics_layers.gd`) for its `collision_mask`. No hardcoded integer layer values. `PhysicsRayQueryParameters3D.collision_mask` is set via the constant, not an inline integer. The `exclude` list contains the player's own RID to prevent self-hit.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `PhysicsRayQueryParameters3D.create(origin, target)` + `query.collision_mask` + `query.exclude` + `get_world_3d().direct_space_state.intersect_ray(query)` are all stable Godot 4.0+. `body.get_meta("surface_tag", &"default")` fallback-default parameter on `get_meta` is stable Godot 4.1+. `body.has_meta("surface_tag")` is the correct guard before `get_meta` without a default (both patterns are acceptable). `get_rid()` on a Node is stable 4.0+. No post-cutoff APIs. NOTE: `player.get_world_3d()` — use `get_world_3d()` NOT the deprecated `get_world()` (deprecated since 4.0; see Control Manifest Forbidden APIs table).

**Control Manifest Rules (Core)**:
- Required: `PhysicsRayQueryParameters3D.collision_mask` MUST reference `PhysicsLayers.MASK_FOOTSTEP_SURFACE` — pattern `hardcoded_physics_layer_number` is forbidden (ADR-0006 IG 1)
- Required: raycasts use `collision_mask` only — no `collision_layer` on a raycast query (ADR-0006 IG 7)
- Required: doc comments on `_resolve_surface_tag()` explaining ADR-0006 mask choice — Global Rules
- Forbidden: `get_world()` — use `get_world_3d()` (see Forbidden APIs)
- Forbidden: hardcoded `query.collision_mask = 1` — must be `PhysicsLayers.MASK_FOOTSTEP_SURFACE`

---

## Acceptance Criteria

*From GDD `design/gdd/footstep-component.md` §AC-FC-2, scoped to surface detection:*

- [ ] **AC-1** (AC-FC-2.1): With a stub ground body carrying `surface_tag = &"marble"` directly below the player's `global_transform.origin`, `_resolve_surface_tag()` returns `&"marble"`.
- [ ] **AC-2** (AC-FC-2.2): With no body below the player (empty space), or a body missing `surface_tag` metadata, `_resolve_surface_tag()` returns `&"default"` AND a `push_warning` fires exactly once per (tag, test-run) pair (warning throttle: one warning per missing-tag body per mission-load, not per step).
- [ ] **AC-3** (AC-FC-2.3): When the player's `global_transform.origin` moves from above a `marble` body to above a `carpet` body mid-step, the NEXT `_resolve_surface_tag()` call returns `&"carpet"` (no blending, no crossfade — surface updates on the next step emission, not mid-step).
- [ ] **AC-4** (AC-FC-2.4): All 7 documented surface tags (`marble`, `tile`, `wood_stage`, `carpet`, `metal_grate`, `gravel`, `water_puddle`) plus `default` resolve correctly when stub bodies with those tags are placed below the player. Parametrized test with 8 cases.
- [ ] **AC-5** (ADR-0006 compliance): `_resolve_surface_tag()` sets `query.collision_mask = PhysicsLayers.MASK_FOOTSTEP_SURFACE` — confirmed by grep in CI lint (no inline `collision_mask = 1` literal).

---

## Implementation Notes

*Derived from GDD §Formulas FC.2, §Edge Cases FC.E.5, FC.E.6, and ADR-0006 §Key Interfaces:*

Implement `_resolve_surface_tag()` per GDD FC.2 formula exactly:

```gdscript
## Resolves the surface tag for the ground body directly below the player.
## Casts one downward ray per call. Called once per step, NOT per frame.
## Returns &"default" if no hit or no surface_tag metadata.
## Per ADR-0006: uses PhysicsLayers.MASK_FOOTSTEP_SURFACE (= MASK_WORLD).
func _resolve_surface_tag() -> StringName:
    var space_state := _player.get_world_3d().direct_space_state
    var origin: Vector3 = _player.global_transform.origin - Vector3(0.0, 0.05, 0.0)
    var target: Vector3 = _player.global_transform.origin - Vector3(0.0, surface_raycast_depth_m, 0.0)
    var query := PhysicsRayQueryParameters3D.create(origin, target)
    query.collision_mask = PhysicsLayers.MASK_FOOTSTEP_SURFACE
    query.exclude = [_player.get_rid()]
    var hit: Dictionary = space_state.intersect_ray(query)
    if hit.is_empty():
        _warn_missing_surface(&"default")
        return &"default"
    var body: Object = hit["collider"]
    if body.has_meta("surface_tag"):
        return body.get_meta("surface_tag") as StringName
    _warn_missing_surface(&"default")
    return &"default"
```

**Warning throttle** (GDD FC.E.5): maintain `_warned_bodies: Dictionary` (body RID or object_id → `bool`). On first miss per body: `push_warning("footstep surface not tagged at %s" % origin)`, record the RID. Suppress subsequent warnings for the same body. Clear `_warned_bodies` on `_ready()` / mission-load (lifecycle reset). This prevents log spam from a mesh Eve crosses repeatedly.

**`surface_raycast_depth_m`**: the exported knob from Story 001 scaffold (`default = 2.0`). The `target` vector uses this value as the downward depth. Do not hardcode `2.0` — read `surface_raycast_depth_m`.

**`query.exclude = [_player.get_rid()]`**: excludes the PlayerCharacter's own CharacterBody3D from the hit result. Required to prevent the capsule's lower geometry from self-hitting before reaching the floor.

**StringName interning requirement** (GDD §Surface Tag Set authoring note): surface tags MUST be returned as `StringName` (`&"marble"` literals), not plain `String`. The `body.get_meta("surface_tag") as StringName` cast handles this. Level designers MUST author the meta value as `StringName` in the inspector (switch type dropdown). The `_resolve_surface_tag` return type is `StringName` (not `String`) — static typing enforces this at call sites.

**Cost**: one ray query + one meta lookup per step. At Sprint cadence (3.0 Hz) = ~3 queries per second per ADR-0008 context. The GDD notes ~6 queries/sec; both are well under Jolt's spatial query budget.

**Testing approach for physics**: surface detection tests require a mock physics space or a headless scene with real `StaticBody3D` objects. Use GUT's `before_each` / `after_each` to add/remove stub `StaticBody3D` nodes with `set_meta("surface_tag", &"marble")` etc. to a scene owned by the test. Set `collision_layer = PhysicsLayers.MASK_WORLD` on stubs. Drive `_resolve_surface_tag()` directly (not through `_emit_footstep`) for unit isolation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: cadence loop that CALLS `_resolve_surface_tag` — this story only implements the method itself
- Story 004: `_emit_footstep()` calls `_resolve_surface_tag()` as part of the full emission; Story 003 focuses on the resolution method in isolation
- Post-VS deferrals:
  - Full surface variant matrix beyond the 7 VS-scope tags (carpet, gravel, scaffolding metal, etc. are in the tag vocabulary in Story 003, but non-plaza Foley stems are deferred to post-VS audio authoring)
  - Per-shoe-type surface tag overrides (not in GDD scope at MVP)
  - `Area3D` volume override for wet surfaces / puddle zones — deferred post-VS: the GDD notes `get_overlapping_areas()` override logic; this is not required for the Plaza surface (plain body-meta path covers VS scope)
  - SAI boundary: Stealth AI must NOT subscribe to `player_footstep`; it reads `player.get_noise_level()` directly. `_resolve_surface_tag()` has no AI implications — it returns a tag for Audio's SFX selection only. Do NOT add any SAI coupling. Forbidden pattern: `sai_subscribing_to_player_footstep`.

---

## QA Test Cases

*Logic story — automated test specs (physics-scene headless tests):*

**AC-1**: Marble surface resolves correctly
- **Given**: a `StaticBody3D` stub with `set_meta("surface_tag", &"marble")` placed at 0.5 m directly below the player's `global_transform.origin`; `collision_layer = PhysicsLayers.MASK_WORLD`
- **When**: `_resolve_surface_tag()` is called
- **Then**: return value equals `&"marble"` (StringName equality, not String)
- **Edge cases**: body placed at exact boundary of ray depth (2.0 m) — should still hit; body at 2.01 m — should miss and return `&"default"`

**AC-2**: Missing metadata → `&"default"` + warning once
- **Given**: (a) no body below player; (b) a `StaticBody3D` with NO `surface_tag` meta at 0.5 m
- **When**: `_resolve_surface_tag()` is called twice for the same body scenario
- **Then**: returns `&"default"` in both cases; `push_warning` fires exactly once per body (second call produces no warning)
- **Edge cases**: body with `surface_tag` set as plain `String` (not `StringName`) — `body.has_meta("surface_tag")` returns `true`; the `as StringName` cast should handle it (verify behaviour — see Open Questions OQ-FC-1 re StringName vs String)

**AC-3**: Surface boundary mid-step
- **Given**: player starts above a `marble` body; `_resolve_surface_tag()` called → returns `&"marble"`; player `global_transform.origin` is then moved to above a `carpet` body
- **When**: `_resolve_surface_tag()` is called again
- **Then**: returns `&"carpet"` (not `&"marble"` — no caching between calls)
- **Edge cases**: player straddles the boundary — whichever body the ray hits first (center-origin ray) wins

**AC-4**: All 7 surface tags parametrized
- **Given**: 8 stub bodies, one per tag: `marble`, `tile`, `wood_stage`, `carpet`, `metal_grate`, `gravel`, `water_puddle`, `default` (body with no meta — returns `&"default"`)
- **When**: for each body, the player is placed above it and `_resolve_surface_tag()` is called
- **Then**: return values match the expected `StringName` tag for each of the 7 tagged bodies; the untagged body returns `&"default"`
- **Edge cases**: `water_puddle` body emits a warning on the first call since it has meta set correctly (no warning for correctly-tagged bodies — warning only fires on MISSING meta)

**AC-5**: ADR-0006 compliance — collision_mask is a constant, not a literal
- **Given**: `src/gameplay/player/footstep_component.gd` source
- **When**: CI grep scans for `collision_mask\s*=\s*[0-9]` in the file
- **Then**: zero matches (all mask assignments reference `PhysicsLayers.MASK_FOOTSTEP_SURFACE`)
- **Edge cases**: a future refactor inlining the value — CI lint must catch it

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/footstep_component/footstep_surface_marble_test.gd` — must exist and pass (AC-1; GDD AC-FC-2.1)
- `tests/unit/core/footstep_component/footstep_surface_default_fallback_test.gd` — must exist and pass (AC-2; GDD AC-FC-2.2)
- `tests/unit/core/footstep_component/footstep_surface_crossing_test.gd` — must exist and pass (AC-3; GDD AC-FC-2.3)
- `tests/unit/core/footstep_component/footstep_surface_tag_set_test.gd` — must exist and pass (AC-4; GDD AC-FC-2.4)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scaffold — `_player` reference, `surface_raycast_depth_m` knob, `_is_disabled` flag) must be Done; `PhysicsLayers.MASK_FOOTSTEP_SURFACE` constant exists in `src/core/physics_layers.gd` (verified Sprint 01)
- Unlocks: Story 004 (`_emit_footstep()` calls `_resolve_surface_tag()` to get the surface for the signal payload); Story 002 can proceed in parallel (cadence loop stubs `&"default"` — surface resolution is independent)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: AC-1..5 covered by 6 test functions in a consolidated test file.
**Test results**: 6/6 PASS.

### Files added
- `tests/unit/core/footstep_component/footstep_surface_resolution_test.gd` (6 tests covering marble/door priority, no-body fallback, missing-tag warning throttle, surface boundary crossing, all 7 vocabulary tags parametrized, ADR-0006 grep-compliance lint).

### Files modified
- `src/gameplay/player/footstep_component.gd` — added `_resolve_surface_tag()` (downward raycast on `MASK_FOOTSTEP_SURFACE`, body.get_meta with default fallback, exclude self-RID) + `_warn_missing_surface_tag()` throttled warning (one per body via instance_id Dictionary). Updated `_emit_footstep()` to use the resolved surface (replaces `&"default"` stub from FS-002).

### Tech debt
- TD-007 (`_warned_bodies` cache survives mission-load — clear on PC-007 respawn).

### Verdict
COMPLETE.
