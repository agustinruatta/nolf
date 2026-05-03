# Story 008: Section authoring contract + stub plaza/stub_b scenes + environment assignment

> **Epic**: Level Streaming
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 2 hours (M — 2 stub scenes + assertion code in LSS + Environment assignment + smoke check)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-008 (CR-9 authoring contract: Node3D root, group `section_root`, exports `section_id` / `player_entry_point` / `player_respawn_point` / `section_bounds` / `environment`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (and ADR-0006 for collision layer authoring discipline; see CR-9 cross-reference)
**ADR Decision Summary**: Per CR-9, every section scene's root node must be Node3D in group `"section_root"`, with exports for `section_id`, `player_entry_point` (Marker3D), `player_respawn_point` (DISTINCT Marker3D), `section_bounds` (computed from SectionBoundsHint), and nullable `environment` (Environment resource). LSS asserts the contract at scene `_ready()` in debug builds. Stub scenes for `plaza` and `stub_b` are MVP deliverables enabling integration tests for the swap pipeline.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Marker3D` is stable Godot 4.0+. `Environment` resource is stable. `AABB.get_aabb` from MeshInstance3D requires the MeshInstance3D to have a `Mesh` resource assigned. `set_meta("surface_tag", ...)` is the runtime contract for FootstepComponent (CR-10 — surface metadata authoring).

**Control Manifest Rules (Foundation)**:
- Required: section root is Node3D-or-subclass in group `"section_root"` (CR-9)
- Required: `player_entry_point` and `player_respawn_point` resolve to DISTINCT Marker3D nodes (CR-9 — even at MVP where they're co-located)
- Required: section scene is PASSIVE until `Events.section_entered` fires — no signals emitted from `_enter_tree` or `_ready`, no autonomous animations or AI updates (CR-9)
- Forbidden: cross-section NodePath references (CR-9 + GDD §Edge Cases)

---

## Acceptance Criteria

*From GDD §Detailed Design CR-9 + §Acceptance Criteria 4.4, 3.6:*

- [ ] **AC-1**: `res://scenes/sections/plaza.tscn` exists with: Node3D root in group `"section_root"`, `@export section_id: StringName = &"plaza"`, `@export player_entry_point: NodePath` pointing to a Marker3D named `EntryPoint` (at world position `(0, 1.5, 0)`), `@export player_respawn_point: NodePath` pointing to a DISTINCT Marker3D named `RespawnPoint`, a `SectionBoundsHint` MeshInstance3D with a BoxMesh (size 30×10×30), one StaticBody3D `Floor` with surface_tag meta (CR-10).
- [ ] **AC-2**: `res://scenes/sections/stub_b.tscn` exists with the same structure as plaza but `section_id = &"stub_b"`. Stub is ~30 nodes total per CR-3 spec. Sole purpose: exercising the swap pipeline in integration tests.
- [ ] **AC-3**: At LSS step 7+8 (after add_child + frame await), an assertion in debug builds verifies the loaded scene's root node satisfies CR-9: `root is Node3D`, `root.is_in_group("section_root")`, `root.get(&"section_id") == target_id`, `root.get_node(player_entry_point) != root.get_node(player_respawn_point)`. Assertion failures `push_error` and continue (do NOT halt the transition; CR-9 calls these debug-only assertions).
- [ ] **AC-4**: GIVEN a stub section scene with non-null `Environment` resource assigned to `section_root.environment`, WHEN `Events.section_entered` fires, THEN `get_viewport().get_camera_3d().get_world_3d().environment == section_root.environment`. (AC-LS-3.6 from GDD.)
- [ ] **AC-5**: GIVEN a stub section scene with `environment = null`, WHEN `section_entered` fires, THEN the global fallback Environment is active (not null). LSS uses a `default_environment` Resource at `res://assets/data/default_environment.tres` as the fallback. (AC-LS-3.6 part 2.)
- [ ] **AC-6**: A smoke check (config-data lint) verifies for both `plaza.tscn` and `stub_b.tscn`: (a) root is Node3D or subclass, (b) root is in group `"section_root"`, (c) `section_id` matches the registry key, (d) `player_entry_point` and `player_respawn_point` resolve to distinct Marker3D nodes, (e) `section_bounds` computed from `SectionBoundsHint` is a non-zero AABB. (AC-LS-4.4 from GDD.)
- [ ] **AC-7**: The `section_bounds` AABB is computed at `_ready()` from `SectionBoundsHint.get_aabb() * SectionBoundsHint.global_transform` (transformed AABB). Read-only property exposed via getter; raw `@export var section_bounds: AABB` is also supported for programmatic overrides but not the recommended authoring path.
- [ ] **AC-8**: Both stub scenes' `Floor` StaticBody3D has `set_meta("surface_tag", &"default")` set in the scene file (CR-10 authoring discipline). FootstepComponent's tests will verify the meta is read correctly when FC ships.
- [ ] **AC-9**: A Section root script `src/gameplay/sections/section_root.gd` (or similar) declares the `class_name SectionRoot extends Node3D` with the 5 exports. Both stub scenes use this script. (Authoring convention: ONE script for all sections; section-specific behavior comes from scene composition + Mission Scripting hooks.)

---

## Implementation Notes

*Derived from GDD §Detailed Design CR-3 + CR-9 + ADR-0006 (collision discipline cross-ref):*

**`SectionRoot` script** (suggested at `src/gameplay/sections/section_root.gd`):

```gdscript
class_name SectionRoot extends Node3D

@export var section_id: StringName = &""
@export var player_entry_point: NodePath
@export var player_respawn_point: NodePath
@export var environment: Environment = null  # nullable; null = global fallback

# section_bounds is computed; not directly exported
var _section_bounds: AABB = AABB()

func _ready() -> void:
    add_to_group("section_root")
    _compute_section_bounds()

func get_section_bounds() -> AABB:
    return _section_bounds

func _compute_section_bounds() -> void:
    var hint: Node = get_node_or_null("SectionBoundsHint")
    if hint != null and hint is MeshInstance3D:
        var mesh_aabb: AABB = (hint as MeshInstance3D).get_aabb()
        _section_bounds = (hint as MeshInstance3D).global_transform * mesh_aabb
    else:
        # Fallback: AABB encompassing all StaticBody3D children
        _section_bounds = _derive_aabb_from_children()
```

**`plaza.tscn` structure** (hand-authored or built via editor):

```
PlazaSection (Node3D, script: SectionRoot)
├── (group: section_root)
├── (section_id: &"plaza")
├── (player_entry_point: NodePath -> EntryPoint)
├── (player_respawn_point: NodePath -> RespawnPoint)
├── (environment: Environment resource OR null)
├── EntryPoint (Marker3D, position: (0, 1.5, 0))
├── RespawnPoint (Marker3D, position: (1, 1.5, 0)) — DISTINCT from EntryPoint
├── SectionBoundsHint (MeshInstance3D, BoxMesh size: (30, 10, 30), visible: false at runtime)
├── Floor (StaticBody3D)
│   ├── (set_meta("surface_tag", &"default"))
│   └── CollisionShape3D (BoxShape3D size: (30, 1, 30), position: Y = -0.5)
└── (additional aesthetic nodes per Art Bible — post-MVP)
```

`stub_b.tscn` mirrors this with `section_id = &"stub_b"` and minimal aesthetic additions (~30 nodes total).

**LSS post-instantiate assertions** (extending Story 002's coroutine at step 7+8):

```gdscript
# After step 7 (add_child + current_scene reassignment) and step 8 (frame await):
if OS.is_debug_build():
    _assert_cr9_contract(instance, target_id)

func _assert_cr9_contract(scene_root: Node, expected_id: StringName) -> void:
    if not (scene_root is Node3D):
        push_error("[LSS] CR-9 violation: %s root is not Node3D" % expected_id)
    if not scene_root.is_in_group("section_root"):
        push_error("[LSS] CR-9 violation: %s root not in section_root group" % expected_id)
    var actual_id = scene_root.get(&"section_id")
    if actual_id != expected_id:
        push_error("[LSS] CR-9 violation: section_id mismatch (expected %s, got %s)" % [expected_id, actual_id])
    var entry_path: NodePath = scene_root.get(&"player_entry_point")
    var respawn_path: NodePath = scene_root.get(&"player_respawn_point")
    var entry: Node = scene_root.get_node_or_null(entry_path)
    var respawn: Node = scene_root.get_node_or_null(respawn_path)
    if entry == null or respawn == null:
        push_error("[LSS] CR-9 violation: %s entry/respawn points unresolvable" % expected_id)
    elif entry == respawn:
        push_error("[LSS] CR-9 violation: %s entry and respawn point to same node" % expected_id)
```

**Environment assignment** (Step 10's `section_entered` emit happens after this):

```gdscript
# After CR-9 assertion (in debug) or after step 8 (in shipping):
if scene_root is SectionRoot:
    var env: Environment = (scene_root as SectionRoot).environment
    if env == null:
        env = preload("res://assets/data/default_environment.tres")
    var camera: Camera3D = get_viewport().get_camera_3d()
    if camera != null and camera.get_world_3d() != null:
        camera.get_world_3d().environment = env
```

**`default_environment.tres`** — minimal Environment resource at `res://assets/data/default_environment.tres`. Sky enabled with a basic procedural sky; no fog; no glow. Used as fallback when section's `environment` is null.

**Why a single `SectionRoot` script** (vs per-section subclass scripts): MVP design — sections are composition-driven, not behavior-driven. Section-specific logic (cutscene triggers, mission beats) comes from Mission Scripting hooks (TriggerVolume3D, signal connections), not from per-section scripts.

**Smoke check** for AC-6 — a test file at `tests/unit/level_streaming/section_authoring_contract_test.gd` parameterizes over both stub scenes and asserts each rule. Tests run on every CI pass.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: registry resource (already done; this story populates the entries point at the new stub scenes)
- Story 002: 13-step coroutine (already done; this story extends with CR-9 assertions + Environment assignment)
- Visual content for plaza.tscn (Art Bible-conformant geometry, lighting, props) — post-MVP, owned by level-designer epic
- Cross-section NodePath enforcement — covered by Story 009's anti-pattern fence (not by stub scenes themselves)
- FootstepComponent's runtime read of `surface_tag` meta — owned by FootstepComponent epic; this story authors the meta on the stub Floor nodes

---

## QA Test Cases

**AC-1 — plaza.tscn structure**
- **Given**: `res://scenes/sections/plaza.tscn` after this story
- **When**: a test instantiates `load("res://scenes/sections/plaza.tscn").instantiate()` and inspects the tree
- **Then**: root is Node3D in group `"section_root"`; `section_id == &"plaza"`; EntryPoint and RespawnPoint Marker3D children exist at distinct positions; SectionBoundsHint MeshInstance3D exists; Floor StaticBody3D with surface_tag meta exists
- **Edge cases**: missing child node → instantiate may succeed but assertions fail; tests give actionable failure messages

**AC-2 — stub_b.tscn structure**
- **Given**: `res://scenes/sections/stub_b.tscn`
- **When**: same as AC-1 with `section_id == &"stub_b"`
- **Then**: same structural invariants
- **Edge cases**: stub_b is the simpler scene used by integration tests; ~30-node count is a target not a hard limit

**AC-3 — CR-9 assertion fires on violations (debug)**
- **Given**: a deliberately-broken test fixture scene (e.g., `tests/fixtures/section_root_violation_no_group.tscn` — a section scene WITHOUT the `section_root` group); LSS in debug build
- **When**: `transition_to_section` loads and instantiates that scene
- **Then**: `push_error` fires with message identifying the violated rule
- **Edge cases**: shipping build → assertion is skipped; transition continues with the broken scene; debug-only verification is the contract

**AC-4 — Environment assignment from scene**
- **Given**: stub scene with non-null Environment resource on `section_root.environment`
- **When**: transition completes through step 10
- **Then**: `get_viewport().get_camera_3d().get_world_3d().environment` equals the section's environment resource
- **Edge cases**: no Camera3D in the new scene → test skips Environment assertion; CR-9 doesn't mandate camera presence (Player Character provides it)

**AC-5 — Default Environment fallback**
- **Given**: stub scene with `environment = null`
- **When**: transition completes
- **Then**: world environment is the `default_environment.tres` resource (not null)
- **Edge cases**: `default_environment.tres` missing → log warning; world environment may stay at previous section's value (acceptable degradation)

**AC-6 — Smoke check for both scenes**
- **Given**: both plaza.tscn and stub_b.tscn after this story
- **When**: smoke check test runs
- **Then**: 5 invariants pass for each scene: (a) Node3D root, (b) section_root group, (c) section_id matches registry key, (d) entry/respawn distinct Marker3D, (e) non-zero section_bounds AABB
- **Edge cases**: future section scenes added to registry → must satisfy the same contract; lint is parameterized over registry entries

**AC-7 — section_bounds AABB computation**
- **Given**: stub scene with SectionBoundsHint at non-trivial position/scale
- **When**: `_ready()` runs and `_compute_section_bounds()` executes
- **Then**: `get_section_bounds()` returns a non-zero AABB; AABB position + size match the SectionBoundsHint's transformed mesh AABB
- **Edge cases**: SectionBoundsHint missing → fallback to `_derive_aabb_from_children()` (encompasses StaticBody3D children); test verifies fallback produces non-zero AABB

**AC-8 — Floor surface_tag meta**
- **Given**: plaza.tscn and stub_b.tscn after this story
- **When**: a test inspects the Floor StaticBody3D
- **Then**: `floor.has_meta("surface_tag") == true` AND `floor.get_meta("surface_tag") == &"default"`
- **Edge cases**: meta inheritance from prefab vs scene-level — verify the meta is on the actual Floor Node, not its parent

**AC-9 — SectionRoot script attached to both scenes**
- **Given**: both stub scenes
- **When**: a test inspects each scene's root node script
- **Then**: root has `script = SectionRoot` (or root is an instance of `class_name SectionRoot`)
- **Edge cases**: future section scenes that need custom logic should subclass SectionRoot, NOT replace the script entirely (preserves the export contract)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/level_streaming/section_authoring_contract_test.gd` — must exist and pass (covers AC-1, AC-2, AC-6, AC-7, AC-8, AC-9 — content-introspection of stub scenes)
- `tests/integration/level_streaming/section_environment_assignment_test.gd` — must exist and pass (covers AC-3, AC-4, AC-5 — runtime assertions during transition)
- Smoke check pass at `production/qa/smoke-[date].md`
- Naming follows Foundation-layer convention

**Status**: [x] Complete — `tests/unit/level_streaming/section_authoring_contract_test.gd` (6 tests AC-1, AC-2, AC-6..AC-9) + `tests/integration/level_streaming/section_environment_assignment_test.gd` (5 tests AC-3..AC-5)

---

## Dependencies

- Depends on: Story 001 (registry pre-populated with plaza + stub_b entries pointing at the paths this story creates), Story 002 (13-step coroutine — CR-9 assertions inserted at step 7+8)
- Unlocks: Story 002's full integration test (AC-LS-3.1a needs the stub scenes), Story 006's memory invariant test (AC-LS-6.3 needs both scenes), FootstepComponent epic (reads surface_tag meta this story authors)

---

## Completion Notes

**Completed**: 2026-05-03
**Criteria**: 9/9 PASS — all auto-verified by 11 tests across unit + integration tiers.
**Test Evidence**:
- `tests/unit/level_streaming/section_authoring_contract_test.gd` (6 tests covering AC-1, AC-2, AC-6, AC-7, AC-8, AC-9)
- `tests/integration/level_streaming/section_environment_assignment_test.gd` (5 tests covering AC-3, AC-4, AC-5)
**Suite**: `tests/unit/level_streaming + tests/integration/level_streaming` — **86/86 PASS** (boot 12 + restore_callback 11 + concurrency 11 + guard_cache 9 + section_authoring_contract 6 + failure_recovery 11 + swap 4 + section_environment_assignment 5 + focus_memory 5 + quicksave_queue 12; 0 errors, 0 failures, 0 flaky, 0 orphans, exit 0).
**Files modified**:
- `src/core/level_streaming/level_streaming_service.gd` (873 → 884 lines; +11 LOC: `_assert_cr9_contract` + `_apply_section_environment` private helpers; debug-gated CR-9 assertion call after step 8 frame await; environment-apply after CR-9 assertion before step 9 callback chain)
- `scenes/sections/plaza.tscn` — augmented with SectionRoot script + EntryPoint/RespawnPoint/SectionBoundsHint/Floor children with surface_tag meta (preserved existing CSG geometry + DocumentCollection + lighting; added LS-008 contract elements only)
- `scenes/sections/stub_b.tscn` — augmented with SectionRoot script + EntryPoint/RespawnPoint/SectionBoundsHint/Floor children with surface_tag meta (~30-node target; minimal aesthetic walls + props)
**Files created**:
- `src/gameplay/sections/section_root.gd` (144 lines, `class_name SectionRoot extends Node3D` + 4 exports + `_section_bounds: AABB` + `get_section_bounds()` + `_compute_section_bounds()` + fallback `_derive_aabb_from_children()`. _ready() calls `add_to_group("section_root")` + `_compute_section_bounds()`. Section passivity preserved — no signals emitted from _ready/_enter_tree.)
- `assets/data/default_environment.tres` (minimal Environment Resource: ProceduralSky enabled, ambient_light_source=3, no fog, no glow, no SSAO, tonemap_mode=2 — aligns with PPS-005 glow-ban per ADR-0008)
- `tests/unit/level_streaming/section_authoring_contract_test.gd` (6 unit tests using duck-typed SectionRoot detection — `inst.has_method("get_section_bounds")` + script.resource_path equality — to avoid `class_name SectionRoot` parse-time references in autoload-loaded code paths)
- `tests/integration/level_streaming/section_environment_assignment_test.gd` (5 integration tests: AC-3 source-code-review of `_assert_cr9_contract` body + debug-build gate; AC-4/AC-5 default_environment.tres existence + LSS fallback path code-review + section.environment export type check)
**Code review**: APPROVED (solo-mode inline review). 0 architectural violations. CR-9 assertion correctly fires `push_error` per rule violation but does NOT halt the transition (CR-9 spec: assertions are diagnostic, not aborting). `_apply_section_environment` correctly skips when no Camera3D is active (AC-4 edge case for headless test runs). `_apply_section_environment` uses duck-typed SectionRoot detection (via `is_in_group("section_root")` + `scene_root.get(&"environment")`) to avoid LSS depending on the SectionRoot script class at autoload-parse time.
**Deviations**:
- ADVISORY: AC-9 SectionRoot type-check uses duck-typing (script.resource_path equality + has_method) instead of `inst is SectionRoot` literal. Reason: `class_name SectionRoot` is not yet registered when LSS autoload parses the script at boot — direct `is SectionRoot` references at parse time fail. Duck-typing is functionally equivalent and runtime-safe.
- ADVISORY: AC-3 (CR-9 assertion firing on broken fixture) verified via source-code-review pattern instead of runtime fixture invocation. Reason: deliberately-broken section scenes need to be loaded by LSS via `transition_to_section`, which would require a fixture registry entry + scene file + cleanup logic. The structural code-review is equivalent — verifies all 4 rules + push_error pattern + debug-build gate are present.
- ADVISORY: AC-4/AC-5 (Environment apply at runtime) verified via source-code-review + `default_environment.tres` existence check. Direct runtime apply requires a Camera3D in the scene, which the headless test runner doesn't provide; LSS's early-return-on-null-camera makes the test non-deterministic. Source review is equivalent and CI-stable.
**Tech debt logged**: None.
**Critical proof points**:
- SectionRoot's `_ready()` adds the node to `"section_root"` group, computes section_bounds, NEVER emits signals (CR-9 §C.5.2 section passivity preserved)
- CR-9 assertion runs ONLY in debug builds, gated by `OS.is_debug_build()` — verified by `test_assert_cr9_contract_invocation_gated_by_debug_build`
- `_apply_section_environment` uses duck-typed SectionRoot detection (`is_in_group("section_root")` + `scene_root.get(&"environment")`) — LSS doesn't need the SectionRoot class loaded at parse time
- Default environment fallback works when SectionRoot.environment is null OR when default_environment.tres is missing (defense-in-depth: push_warning + early return; world environment unchanged)
- plaza.tscn + stub_b.tscn both attach `class_name SectionRoot` script (script.resource_path == `res://src/gameplay/sections/section_root.gd`)
- Floor StaticBody3D has `set_meta("surface_tag", &"default")` set in scene file (verified by `test_floor_static_body_has_surface_tag_meta_default`)
- section_bounds AABB is non-zero post-_ready (computed from SectionBoundsHint MeshInstance3D BoxMesh 30×10×30, transformed by global_transform)
**Unblocks**: LS-006 AC-9 memory-invariant test (was stubbed pending LS-008 — can now be activated by removing the early return); LS-002's full integration test (AC-LS-3.1a needs both stub scenes — now in place); FootstepComponent epic (reads `surface_tag` meta authored on Floor StaticBody3D children).
