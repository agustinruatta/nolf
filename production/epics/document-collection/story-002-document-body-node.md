# Story 002: DocumentBody node — collision layer, stencil tier, interact priority

> **Epic**: Document Collection
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 hours (S — 1 script + 1 .tscn template + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-collection.md`
**Requirement**: TR-DC-003, TR-DC-004
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract) + ADR-0001 (Stencil ID Contract)
**ADR Decision Summary (ADR-0006)**: Every gameplay script touching `collision_layer`, `collision_mask`, or `set_collision_layer_value()` MUST use `PhysicsLayers.*` constants — bare integer literals are PR-rejected. `LAYER_INTERACTABLES` bodies carry `collision_layer = MASK_INTERACTABLES` and `collision_mask = 0`: they participate in raycasts but do NOT block movement. This is the physics encoding of "documents don't push Eve."

**ADR Decision Summary (ADR-0001)**: Tier values are fixed: 0=None / 1=HEAVIEST (4 px @ 1080p, for "look here" objects) / 2=MEDIUM / 3=LIGHT. Uncollected `DocumentBody` nodes receive Tier 1 per the ADR-0001 canonical table (Documents domain, row cited by name). `OutlineTier.set_tier(mesh, OutlineTier.Tier1)` is called at spawn. Environment meshes set stencil tier once in the `.tscn` (scene-baked); runtime override is only needed when a mesh changes tier.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `StaticBody3D`, `CollisionShape3D`, `BoxShape3D`, and `MeshInstance3D` are stable Godot 4.0+ node types. `STENCIL_MODE_CUSTOM` (stencil_mode = 3) for per-material stencil writes is verified in Sprint 01 (ADR-0001 Finding F4). `OutlineTier.set_tier()` is an internal project API backed by `STENCIL_MODE_CUSTOM` — use it, not `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` which is world-space and forbidden. Jolt 4.6 is the default physics engine; `StaticBody3D` behaviour is unchanged from GodotPhysics for non-dynamic bodies.

**Control Manifest Rules (Feature layer)**:
- Required: every gameplay script touching `collision_layer` MUST use `PhysicsLayers.*` constants — ADR-0006 IG 1
- Required: `LAYER_INTERACTABLES` bodies set `collision_mask = 0` (they participate in raycasts but do not block movement) — ADR-0006 IG 8
- Required: `OutlineTier.set_tier(mesh, OutlineTier.Tier1)` called at spawn for uncollected documents — ADR-0001 IG 1
- Required: stencil tier value is scene-baked in the `.tscn` template (not set at runtime) — ADR-0001 IG 2
- Forbidden: bare integer literals for `collision_layer` / `collision_mask` — `hardcoded_physics_layer_number` — ADR-0006 IG 1
- Forbidden: `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` for player-facing outlines (world-space, violates Art Bible screen-space pillar) — ADR-0001 §Engine Compatibility Finding F4
- Forbidden: emission shader, animation cycle, or pulse on DocumentBody mesh — GDD FP-V-DC-1 / FP-V-DC-2
- Guardrail: `collision_layer` must be `LAYER_INTERACTABLES` with no other bits set — GDD §C.5.6 lint #5; extra bits = build failure

---

## Acceptance Criteria

*From GDD `design/gdd/document-collection.md` §H.1 (AC-DC-1.1 partial — body spec), §C.3, §C.5.8:*

- [ ] **AC-1**: `src/gameplay/documents/document_body.gd` declares `class_name DocumentBody extends StaticBody3D`. Exported fields: `@export var document: Document` (required — CI lint #1 enforces non-null + non-empty id) and `get_interact_priority() -> int` returning `0` (DOCUMENT priority — highest, beats TERMINAL=1 / PICKUP=2 / DOOR=3). Class has a doc comment. No `_process` or `_physics_process` override.
- [ ] **AC-2**: `DocumentBody` sets `collision_layer` using `PhysicsLayers.MASK_INTERACTABLES` (no other bits) and `collision_mask = 0`. No bare integer literals for layer values appear in `document_body.gd`. Verified by unit test + CI static-analysis lint.
- [ ] **AC-3**: `res://src/gameplay/documents/document_body.tscn` exists as the canonical template per GDD §C.5.8. Scene structure: `DocumentBody` (StaticBody3D root with `document_body.gd` script) → `CollisionShape3D` child (BoxShape3D, size `Vector3(0.30, 0.05, 0.20)`) + `MeshInstance3D` child (mesh = null in template, assigned in derived scenes). Node is added to group `&"section_documents"` in the template.
- [ ] **AC-4**: The `DocumentBody` template node has stencil Tier 1 set via `OutlineTier.set_tier()` call-site or scene-baked material on the `MeshInstance3D`. This results in stencil reference value `1` (heaviest, 4 px @ 1080p) per ADR-0001. Verified by reading the material's `stencil_mode`, `stencil_flags`, and `stencil_reference` values in a unit test or CI scene-property check.
- [ ] **AC-5**: GIVEN a `DocumentBody` unit test instantiates the template scene, WHEN `get_interact_priority()` is called, THEN it returns `0`. WHEN `collision_layer` is read, THEN it equals `PhysicsLayers.MASK_INTERACTABLES` with no other bits. WHEN `collision_mask` is read, THEN it equals `0`.

---

## Implementation Notes

*Derived from GDD §C.3, §C.5.8, ADR-0006 IG 1/6/7/8, and ADR-0001 IG 1/2:*

`DocumentBody` is a pure data-presentation node. It has no per-frame cost (`_process` / `_physics_process` forbidden per CR-15 zero-steady-state budget). Its only runtime logic is `get_interact_priority() -> int`.

```gdscript
## Uncollected document pickup body. Carries a Document Resource reference.
## Lives at Section/Documents/ in the section scene tree; freed on pickup.
## Layer: LAYER_INTERACTABLES only. Stencil: Tier 1 (4 px, heaviest).
class_name DocumentBody
extends StaticBody3D

## The Document Resource for this pickup. Must be non-null with a non-empty id.
## Assigned by Level Designer in the instanced scene.
@export var document: Document

## Returns DOCUMENT interact priority (0 = highest; beats TERMINAL=1, PICKUP=2, DOOR=3).
func get_interact_priority() -> int:
    return 0
```

Template scene structure (GDD §C.5.8):
```
DocumentBody  [StaticBody3D, script = document_body.gd]
  collision_layer = PhysicsLayers.MASK_INTERACTABLES
  collision_mask  = 0
  group: &"section_documents"
  ├── CollisionShape3D
  │     shape = BoxShape3D(size = Vector3(0.30, 0.05, 0.20))
  └── MeshInstance3D
        mesh = null   ← LD assigns per-category mesh in derived instance
```

Stencil tier: set `STENCIL_MODE_CUSTOM` (stencil_mode = 3, stencil_flags = 2 Write, stencil_compare = 0 Always, stencil_reference = 1) on the `MeshInstance3D`'s override material surface 0. Scene-baked in the template `.tscn` so every instance inherits Tier 1 without runtime `set_tier()` call. This aligns with ADR-0001 IG 2 ("static environment meshes set the stencil tier once in the `.tscn`").

Naming: `document_body.gd` (snake_case matching class) and `document_body.tscn` (matching root node name convention from technical-preferences.md — PascalCase root node `DocumentBody` maps to PascalCase `.tscn` name).

The `MeshInstance3D` mesh is left null in the template; the level designer assigns the per-category mesh (one of 7 from GDD §V.1) in the instanced derived scene. This story does NOT create any of the 7 category meshes — those are art-pipeline assets.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `Document` Resource schema (`@export var document: Document` type comes from Story 001)
- Story 003: `DocumentCollection` — the subscriber that processes `player_interacted` signals targeting this body
- Story 005: Plaza-section `.tres` Document Resources and actual scene placement
- Art pipeline: the 7 category meshes per GDD §V.1 (Operational Memo flat plane, Personnel Dossier stacked planes, etc.) — these are assets, not code
- `OutlineTier` escape-hatch runtime reassignment — only needed if a document mesh changes tier mid-session (reserved for VS edge cases via `tier_override` field)

---

## QA Test Cases

**AC-1 + AC-5 — DocumentBody class declaration and interact priority**
- Given: `document_body.tscn` instantiated in a test scene
- When: a unit test calls `get_interact_priority()` on the root node
- Then: returns `0`
- Edge cases: script not attached (node has no method) → type error; method returns wrong value → priority collision with TERMINAL/PICKUP

**AC-2 — Collision layer uses PhysicsLayers constants**
- Given: `document_body.gd` source
- When: a CI static-analysis grep scans for integer literals on `collision_layer` / `collision_mask` assignments
- Then: zero bare integer literals found; only `PhysicsLayers.*` constants used
- Edge cases: `set_collision_layer_value(int, bool)` with a bare index — also prohibited

**AC-2 + AC-5 — Collision layer value is LAYER_INTERACTABLES only**
- Given: `document_body.tscn` instantiated in a test scene
- When: a unit test reads `collision_layer` and `collision_mask`
- Then: `collision_layer == PhysicsLayers.MASK_INTERACTABLES`; `collision_mask == 0`; no other bits set
- Edge cases: extra layer bit set → GDD §C.5.6 lint #5 build failure

**AC-3 — Template scene structure**
- Given: `res://src/gameplay/documents/document_body.tscn`
- When: a unit test loads the scene and inspects node children
- Then: root is `DocumentBody` (StaticBody3D); has a `CollisionShape3D` child with `BoxShape3D` size `≈ Vector3(0.30, 0.05, 0.20)` (within 0.001 tolerance); has a `MeshInstance3D` child; root is in group `&"section_documents"`
- Edge cases: missing CollisionShape3D → raycast misses; BoxShape3D wrong dimensions → CI lint #6 height violations possible

**AC-4 — Stencil Tier 1 scene-baked**
- Given: `DocumentBody` template's `MeshInstance3D` material
- When: a unit test reads `surface_get_material(0).stencil_mode` and `stencil_reference`
- Then: `stencil_mode == 3` (CUSTOM) and `stencil_reference == 1` (Tier 1 heaviest)
- Edge cases: material null (template mesh is null in template — stencil must be set on the override material, not the mesh material)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/document_collection/document_body_node_test.gd` — must exist and pass
  - `test_interact_priority_returns_zero`
  - `test_collision_layer_is_interactables_only`
  - `test_collision_mask_is_zero`
  - `test_template_scene_has_correct_child_structure`
  - `test_stencil_tier_one_scene_baked`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Document class must be registered for `@export var document: Document` to resolve)
- Unlocks: Story 003 (DocumentCollection handler does `target is DocumentBody` type-check), Story 005 (Plaza placement instantiates this template)

---

## Completion Notes

**Completed**: 2026-05-03
**Criteria**: 5/5 passing
**Deviations**: None blocking. Three advisory notes (test naming style, untested null-document edge case, stencil-test load-failure attribution) — non-blocking, documented in code-review.
**Test Evidence**: `tests/unit/feature/document_collection/document_body_node_test.gd` (6 test functions covering AC-1..AC-5 + CR-15 bonus)
**Code Review**: Complete — godot-gdscript-specialist CLEAN, godot-specialist CLEAN, qa-tester TESTABLE; LP-CODE-REVIEW + QL-TEST-COVERAGE gates skipped (Solo review mode)
