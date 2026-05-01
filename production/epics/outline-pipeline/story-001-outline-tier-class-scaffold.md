# Story 001: OutlineTier class scaffold — constants, set_tier(), validation

> **Epic**: Outline Pipeline
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (S — one static class, one unit test file)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/outline-pipeline.md`
**Requirement**: TR-OUT-001, TR-OUT-010
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Stencil ID Contract)
**ADR Decision Summary**: Every visible MeshInstance3D writes one of four reserved stencil-buffer values (0 = no outline, 1 = heaviest 4 px, 2 = medium 2.5 px, 3 = light 1.5 px). A project-wide `OutlineTier` static helper class owns the tier constants and a `set_tier(mesh, tier)` convenience method. Values outside [0, 3] must assert in debug builds and clamp silently to Tier 3 in release. No stencil value other than 0–3 is ever written by this system (stencil values 4–255 are reserved for future ADRs).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**:
- Sprint 01 finding F4 (verified 2026-04-29): `BaseMaterial3D` exposes a complete stencil API in Godot 4.6 — `stencil_mode`, `stencil_flags`, `stencil_compare`, `stencil_reference`, `stencil_color`, `stencil_outline_thickness`. The correct mode for ADR-0001's per-tier writes is `STENCIL_MODE_CUSTOM` (stencil_mode = 3) with `stencil_flags = Write (2)`, `stencil_compare = Always (0)`, `stencil_reference = N` for N ∈ {1, 2, 3}. NOT `STENCIL_MODE_OUTLINE` — the native Outline mode is world-space (verified finding F4), which violates the screen-space stability pillar. This is a post-cutoff API (Godot 4.5 stencil buffer support) and IS confirmed available in 4.6.
- Sprint 01 finding F5 (verified 2026-04-30): the stencil aspect of the depth-stencil texture cannot be sampled from a compute shader. Stencil filtering happens via graphics-pipeline `RDPipelineDepthStencilState.enable_stencil = true` state. The `set_tier()` helper writes the material-side stencil reference value; the CompositorEffect reads it via the pipeline state mechanism (story 002's concern).
- Sprint 01 finding F6 (verified 2026-04-30, conditional): the production CompositorEffect MUST use jump-flood algorithm (ADR-0001 IG 7) — the naive scan was verified to exceed budget on Iris Xe. This story is upstream of the algorithm: it establishes the data written into the stencil buffer; the algorithm consuming it is story 003's concern.
- ADR-0001 All 4 gates closed 2026-04-30 (G1 ✅ material API, G2 ✅ Vulkan via spike prototype, G3 ✅ CONDITIONAL jump-flood required, G4 ✅ RDShaderFile SPIR-V pre-compile path). ADR-0001 is Accepted.
- ADR-0005 Accepted 2026-05-01 after user visual sign-off on `prototypes/verification-spike/fps_hands_demo.tscn` (Linux Vulkan, Godot 4.6.2 stable). Eve's FPS hands are the ONLY mesh class exempt from `OutlineTier.set_tier()` — they use an inverted-hull shader in a SubViewport per ADR-0005. This story's `set_tier()` implementation MUST NOT be called for the hands mesh; that is a code-review concern enforced by the code review checklist entry added in ADR-0005 Validation Criteria.

**Control Manifest Rules (Foundation + Presentation)**:
- Required (ADR-0001 IG 1): every gameplay system that spawns visible objects MUST call `OutlineTier.set_tier(mesh, OutlineTier.X)` at spawn time; no engine default exists; unmarked meshes write stencil 0 and receive no outline
- Required (ADR-0001 IG 2): static environment meshes set stencil tier once in `.tscn` (scene-baked); do NOT re-set at runtime unless the escape hatch is invoked
- Required (ADR-0001 IG 3): escape-hatch runtime reassignment is supported; `set_tier()` may be called at any time to reassign
- Required (Presentation, Manifest 2026-04-30): per-material stencil writes use `STENCIL_MODE_CUSTOM` with `stencil_flags = Write`, `stencil_compare = Always`, `stencil_reference = N`; NOT `STENCIL_MODE_OUTLINE` (world-space, finding F4)
- Forbidden (Presentation, Manifest 2026-04-30): never use `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` for player-facing comic outlines (world-space — violates screen-space stability pillar)
- Forbidden (ADR-0001 §Decision): never claim stencil values 0/1/2/3 for other purposes; never use stencil values 4–255 in this system
- Performance: `OutlineTier` must be a static class (`class_name OutlineTier extends RefCounted`) — NOT an autoload; `const int` members inline at compile time; zero runtime memory footprint

---

## Acceptance Criteria

*From GDD `design/gdd/outline-pipeline.md` §Detailed Design Rules 1–2, §Acceptance Criteria AC-14, AC-17, AC-18, and ADR-0001 §Key Interfaces:*

- [ ] **AC-1**: `src/rendering/outline/outline_tier.gd` declares `class_name OutlineTier extends RefCounted` with four `const int` tier constants: `NONE = 0`, `HEAVIEST = 1`, `MEDIUM = 2`, `LIGHT = 3`. No instance properties, no signals, no state. (TR-OUT-001)
- [ ] **AC-2**: `OutlineTier.set_tier(mesh: MeshInstance3D, tier: int) -> void` is a `static func`. For each surface slot on the mesh: if the existing material is a `BaseMaterial3D`, set `stencil_mode = 3` (CUSTOM), `stencil_flags = 2` (Write), `stencil_compare = 0` (Always), `stencil_reference = tier`. If the existing material is a `ShaderMaterial`, set the `stencil_reference` shader parameter. If the surface has no material, create a new `BaseMaterial3D` with the stencil properties set and assign it. (TR-OUT-001, ADR-0001 IG 1)
- [ ] **AC-3**: GIVEN `OutlineTier.set_tier(mesh, tier)` called with `tier` in [0, 3], WHEN inspecting the mesh's surface materials after the call, THEN every surface material has `stencil_reference == tier` and `stencil_mode == 3` (STENCIL_MODE_CUSTOM). (TR-OUT-001, GDD AC-14)
- [ ] **AC-4**: GIVEN `OutlineTier.set_tier(mesh, 5)` (invalid tier) called in a debug build, WHEN the call executes, THEN `assert(tier >= 0 and tier <= 3, "OutlineTier: invalid tier value " + str(tier) + " (must be 0–3)")` fires. In a release build, the value is clamped to `LIGHT (3)` silently. (TR-OUT-010, GDD AC-18, GDD §Edge Cases "invalid tier value")
- [ ] **AC-5**: GIVEN a mesh with mixed-tier surface materials (e.g., two surfaces assigned different `BaseMaterial3D` resources), WHEN `OutlineTier.set_tier(mesh, 2)` is called, THEN all surface materials on the mesh have `stencil_reference == 2`. (Per GDD §Edge Cases "mesh with multiple surfaces".)
- [ ] **AC-6**: GIVEN `OutlineTier.set_tier(lamp_mesh, 1)` called at runtime (escape-hatch promotion), WHEN the next `_render_callback` fires, THEN the material stencil_reference on lamp_mesh == 1. GIVEN `OutlineTier.set_tier(lamp_mesh, 3)`, THEN stencil_reference == 3. (TR-OUT-010, GDD AC-17)
- [ ] **AC-7**: A GUT unit test at `tests/unit/foundation/outline_pipeline/outline_tier_test.gd` covers all AC-1 through AC-6 cases. The test creates `MeshInstance3D` nodes with `BaseMaterial3D` surfaces and asserts stencil property values after each `set_tier()` call. (GDD §Acceptance Criteria AC-14, AC-18)

---

## Implementation Notes

*Derived from ADR-0001 §Key Interfaces, §Implementation Guidelines IG 1–5, and §Engine Compatibility:*

File location: `src/rendering/outline/outline_tier.gd`

This class is a **static utility class**, not an autoload. It must NOT be registered in `project.godot [autoload]`. It uses `class_name OutlineTier` so any GDScript file can reference `OutlineTier.HEAVIEST` or call `OutlineTier.set_tier(...)` without an import or autoload lookup.

The stencil property names as exposed in Godot 4.6 (verified finding F4):
- `stencil_mode` — enum int: 0=Disabled, 1=Outline (world-space — FORBIDDEN per ADR-0001), 2=XRay, 3=Custom
- `stencil_flags` — bitfield int: 1=Read, 2=Write, 4=WriteDepthFail
- `stencil_compare` — enum int: 0=Always, 1=Less, 2=Equal, 3=LessOrEqual, 4=Greater, 5=NotEqual, 6=GreaterOrEqual
- `stencil_reference` — int (0–255, project reserves 0–3)

For `set_tier()`, iterate `mesh.get_surface_override_material_count()` surface slots. Use `mesh.get_surface_override_material(i)` first (override slot, editor-assigned materials land here). If null, fall back to `mesh.mesh.surface_get_material(i)` (mesh-embedded material). If still null, create a new `StandardMaterial3D` (alias for `BaseMaterial3D`) and call `mesh.set_surface_override_material(i, mat)`.

Validation pattern for debug/release builds:
```gdscript
static func set_tier(mesh: MeshInstance3D, tier: int) -> void:
    assert(tier >= 0 and tier <= 3, "OutlineTier: invalid tier " + str(tier))
    var safe_tier: int = clampi(tier, 0, 3)
    # ... apply safe_tier to materials
```

The `assert()` fires in debug builds and is stripped in release builds. The `clampi()` runs regardless; in release builds it silently produces Tier 3 from an out-of-range value (per GDD §Edge Cases).

Tier constants must use `const int` (not `enum`) so they can be used as `@export` defaults and as match values without requiring a qualified enum import.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the CompositorEffect GDScript node that reads per-tier stencil values back via graphics-pipeline stencil-test (the consumer side of the stencil contract)
- Story 003: the jump-flood GLSL compute shader that draws outline pixels onto the scene color buffer
- Story 004: resolution-scale kernel formula + Settings & Accessibility wiring
- Story 005: Plaza scene placement of per-tier meshes + visual sign-off + Slot 1 perf measurement
- Per-system `set_tier()` call-sites — owned by each upstream spawning system's epic (Stealth AI, Document Collection, Level Streaming, etc.); this story provides the API they call

---

## QA Test Cases

**AC-1 — OutlineTier constants**
- **Given**: `src/rendering/outline/outline_tier.gd` is loaded
- **When**: a test accesses `OutlineTier.NONE`, `OutlineTier.HEAVIEST`, `OutlineTier.MEDIUM`, `OutlineTier.LIGHT`
- **Then**: values are `0`, `1`, `2`, `3` respectively; the class has no instance properties, no autoload registration
- **Edge cases**: class declared as non-static (instantiable) → fail; any signal or var declaration on the class → fail

**AC-2 + AC-3 — set_tier() writes correct stencil properties**
- **Given**: a `MeshInstance3D` with one `StandardMaterial3D` surface (`mesh.get_surface_override_material_count() == 1`, material slot not null)
- **When**: `OutlineTier.set_tier(mesh, OutlineTier.HEAVIEST)` is called
- **Then**: `mesh.get_surface_override_material(0).stencil_mode == 3`, `mesh.get_surface_override_material(0).stencil_flags == 2`, `mesh.get_surface_override_material(0).stencil_compare == 0`, `mesh.get_surface_override_material(0).stencil_reference == 1`
- **Edge cases**: mesh surface has no override material (null slot) → `set_tier()` creates a new `StandardMaterial3D` and assigns it; test verifies the new material is present with correct stencil_reference

**AC-4 — Invalid tier validation**
- **Given**: `OutlineTier.set_tier(mesh, 5)` called in a GUT test (GUT runs in debug mode)
- **When**: the call executes
- **Then**: the `assert()` fires; GUT should catch the assertion failure (GUT intercepts `push_error` from assert in non-crashing mode); material stencil_reference is not set to 5 — it is set to 3 (clamped value)
- **Edge cases**: tier = -1 → asserts and clamps to 0; tier = 0 → valid, sets stencil_reference = 0 (no outline, no assert); tier = 3 → valid, sets stencil_reference = 3

**AC-5 — Multi-surface mesh**
- **Given**: a `MeshInstance3D` with two `StandardMaterial3D` surfaces
- **When**: `OutlineTier.set_tier(mesh, OutlineTier.MEDIUM)` is called
- **Then**: `mesh.get_surface_override_material(0).stencil_reference == 2` AND `mesh.get_surface_override_material(1).stencil_reference == 2`
- **Edge cases**: first surface has a material, second does not → second gets a new material created with stencil_reference = 2

**AC-6 — Runtime escape-hatch reassignment**
- **Given**: a `MeshInstance3D` that has `set_tier(mesh, OutlineTier.LIGHT)` applied (stencil_reference = 3)
- **When**: `OutlineTier.set_tier(mesh, OutlineTier.HEAVIEST)` is called
- **Then**: stencil_reference == 1 (promoted to Heaviest)
- **When**: `OutlineTier.set_tier(mesh, OutlineTier.LIGHT)` is called again
- **Then**: stencil_reference == 3 (reverted)
- **Edge cases**: reassignment is instantaneous (no tween, no transition) per GDD §Edge Cases "mid-frame reassignment"

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/outline_pipeline/outline_tier_test.gd` — must exist and pass (covers AC-1 through AC-6)
- Test file naming follows project convention: `[system]_[feature]_test.gd`
- Tests must be deterministic and isolated: each test creates and frees its own `MeshInstance3D` with a new `ArrayMesh`; no cross-test state; no filesystem I/O

**Status**: [x] Created and passing — `tests/unit/foundation/outline_pipeline/outline_tier_test.gd` (17 test functions covering AC-1..AC-7). Suite total: 359/359 PASS.

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 7/7 passing — all auto-verified via 17 test functions.
**Test Evidence**: `tests/unit/foundation/outline_pipeline/outline_tier_test.gd`
**Code Review**: APPROVED inline (full 17/17 OUT-001 tests + 359/359 suite all pass after two iterations of fixes)
**Deviations**:
1. **Production: assert() → debug-guarded push_error()**. Story implementation note specified `assert(tier >= 0 and tier <= 3, ...)` followed by `clampi(tier, 0, 3)` claiming "clampi runs regardless." In practice GDScript's `assert()` aborts the function in headless debug builds, so clampi never ran and the defense-in-depth clamp couldn't apply. Replaced with `if OS.is_debug_build() and (tier < 0 or tier > 3): push_error(...)` — preserves story intent (debug log + release silent clamp) without aborting the function. AC-4 wording is fully satisfied (invalid tiers fire a debug-only error message AND get clamped by clampi).
2. Tests use `await assert_error(callback).is_push_error("...")` to capture the debug error from GdUnit4's error monitor without failing the test.
**Suite trajectory**: 342 baseline → 359 after OUT-001 (+17 tests)
**Files created**:
- `src/rendering/outline/outline_tier.gd` (139 lines: `class_name OutlineTier extends RefCounted`; 4 const int tier constants NONE/HEAVIEST/MEDIUM/LIGHT = 0/1/2/3; `static func set_tier(mesh, tier)` with debug-guard push_error + clampi defense + per-surface BaseMaterial3D / ShaderMaterial / null-slot dispatch; `_apply_stencil_to_base_material` private helper writing stencil_mode=3, stencil_flags=2, stencil_compare=0, stencil_reference=safe_tier per Godot 4.6 API)
- `tests/unit/foundation/outline_pipeline/outline_tier_test.gd` (17 test functions: 6 constants + class shape + 4 set_tier valid/invalid/boundary + 2 multi-surface/null-slot + 1 escape-hatch reassignment + 3 helpers)
**Out-of-scope deferred**: CompositorEffect (OUT-002), jump-flood shader (OUT-003), resolution-scale formula (OUT-004), Plaza scene placement (OUT-005), per-system call sites (each upstream epic). All correctly excluded.

---

## Dependencies

- Depends on: None — foundational static class
- Unlocks: Story 002 (CompositorEffect pipeline needs the stencil tier contract established and the API name confirmed); Story 003 (shader references the tier constants in documentation); Story 004 (resolution-scale formula references this tier's stencil reference values); Story 005 (Plaza demo meshes use `OutlineTier.set_tier()`)
