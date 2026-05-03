# Story 005: WorldEnvironment glow ban + forbidden post-process enforcement

> **Epic**: Post-Process Stack
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (S — validation logic + scene-load hook + unit test + lint check)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/post-process-stack.md`
**Requirement**: TR-PP-004, TR-PP-005, TR-PP-006
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (FPS Hands Outline Rendering) — shares the enforcement concern that rendering decisions are locked by ADR; ADR-0008 (Performance Budget Distribution) — WorldEnvironment misconfiguration (glow enabled) would add unmeasured cost to Slot 3
**ADR Decision Summary**: The GDD mandates glow disabled project-wide (Art Bible 8J item 7). Godot 4.6 changed glow to process BEFORE tonemapping (VERSION.md HIGH risk) — this means glow enabled would affect emissive materials (bomb device indicator lamps, Plaza street lamps) in an unexpected and period-inauthentic way. Enforcement is scene-load-time validation: assert in debug, warn and forcibly disable in release. Tonemapping must remain `TONEMAP_LINEAR` (engine default) on all `WorldEnvironment` nodes.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: CRITICAL — Godot 4.6 changed glow order: glow now processes BEFORE tonemapping (VERSION.md HIGH risk flag). This is the stated reason the GDD forbids glow (GDD Core Rule 4: "Godot 4.6 changed glow order to process before tonemapping, which would affect emissive materials unexpectedly"). When writing the glow-check enforcement, verify that `WorldEnvironment.glow_enabled` is the correct property name in Godot 4.6 and that disabling it at runtime via `Environment.glow_enabled = false` takes effect on the same frame (no deferred compositor rebuild required). Consult `docs/engine-reference/godot/modules/rendering.md` and `docs/engine-reference/godot/breaking-changes.md` for the 4.6 glow rework API surface before implementing the enforcement hook. `TONEMAP_LINEAR` is the Godot 4.6 default tonemap mode — verify the constant name has not changed in 4.6 (it was `Environment.TONE_MAPPER_LINEAR` in earlier versions; check the exact name in `docs/engine-reference/`).

**Control Manifest Rules (Foundation + Presentation)**:
- Required: glow enforcement mode is `assert_in_debug_warn_in_release` (GDD §Tuning Knobs — locked, changing requires ADR amendment)
- Forbidden: `glow_enabled = true` in any project source GDScript file — GDD anti-pattern `modern_post_process_stack`; GDD Acceptance Criterion 22 (lint check)
- Forbidden: any `WorldEnvironment` enabling bloom, chromatic aberration, SSR, motion blur, DoF, vignette, film grain, color-grading LUTs (GDD Core Rule 7)
- Guardrail: tonemapping must be engine default (neutral linear) on all WorldEnvironment nodes — any deviation from this requires ADR amendment (GDD Core Rule 8)

---

## Acceptance Criteria

*From GDD `design/gdd/post-process-stack.md` §Acceptance Criteria AC-9, AC-10, AC-11, AC-21, AC-22:*

- [ ] **AC-1**: GIVEN any scene loads, WHEN its `WorldEnvironment.glow_enabled` property is checked by the PostProcessStack validation hook at `_ready()` or via `SceneTree.node_added` signal, THEN: (a) in debug build, if `glow_enabled == true`, an `assert(false, "Glow is forbidden per Art Bible 8J / Post-Process Stack GDD — scene: [scene path]")` fires; (b) in release build, a `push_warning(...)` fires and `environment.glow_enabled` is forcibly set to `false` on the same frame.
- [ ] **AC-2**: GIVEN the project's WorldEnvironment configuration files across all scenes (currently the plaza stand-in scene), WHEN audited, THEN no `WorldEnvironment` node has `glow_enabled = true`, `bloom_amount > 0`, `ssr_enabled = true`, `motion_blur_enabled = true`, `dof_blur_far_enabled = true`, `dof_blur_near_enabled = true`, or any equivalent forbidden post-process effect property set to an active value.
- [ ] **AC-3**: GIVEN any `WorldEnvironment` in the project, WHEN `environment.tonemap_mode` is read at scene-load time, THEN it equals the Godot 4.6 neutral linear tonemap constant (verify exact constant name against `docs/engine-reference/godot/modules/rendering.md` before implementing). No AgX, Filmic, Reinhard variants.
- [ ] **AC-4**: GIVEN any GDScript file in the project source (`src/`), WHEN grepped for the string `glow_enabled = true`, THEN zero matches (lint check per GDD AC-22). Test files that explicitly test Godot glow-enable behavior are the only permitted exception (must be in `tests/` not `src/`).
- [ ] **AC-5**: GIVEN the debug build runs and a test scene temporarily sets `WorldEnvironment.glow_enabled = true`, WHEN the scene-load validation hook fires, THEN an assertion failure or push_error with the message text "Glow is forbidden per Art Bible 8J" is produced. (Confirms the enforcement hook is actually running, not silently bypassed.)

---

## Implementation Notes

*Derived from GDD §Detailed Design Core Rules 4 and 7 + §Edge Cases "glow enabled in a scene" + §Tuning Knobs glow_enforcement_mode:*

**Where to hook the check**: PostProcessStack `_ready()` can connect to `SceneTree.node_added` and check each newly added `WorldEnvironment` node. Alternatively, validate explicitly when the game's scene management (Level Streaming) loads a new section — subscribe to the `scene_changed` or equivalent event via `Events`. The `SceneTree.node_added` approach is more robust (catches editor-loaded scenes too).

```gdscript
func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    # Also validate any WorldEnvironment already in the tree at boot
    for we in get_tree().get_nodes_in_group("world_environments"):
        _validate_world_environment(we)

func _on_node_added(node: Node) -> void:
    if node is WorldEnvironment:
        _validate_world_environment(node)

func _validate_world_environment(we: WorldEnvironment) -> void:
    if we.environment == null:
        return
    if we.environment.glow_enabled:
        var msg := "Glow is forbidden per Art Bible 8J / Post-Process Stack GDD. Scene: " + we.scene_file_path
        if OS.is_debug_build():
            assert(false, msg)
        else:
            push_warning(msg)
            we.environment.glow_enabled = false
    # Tonemap check (verify exact constant name before shipping)
    # if we.environment.tonemap_mode != Environment.TONE_MAPPER_LINEAR:
    #     push_warning("Tonemap mode must be TONE_MAPPER_LINEAR per GDD Core Rule 8")
```

**WorldEnvironment group**: Add any `WorldEnvironment` in scene files to the group `"world_environments"` to support the initial sweep in `_ready()`. This is a scene-authoring convention, not a code requirement.

**Tonemap constant name**: The GDD references "engine default (neutral linear)." In Godot 4.6 the constant is `Environment.TONE_MAPPER_LINEAR`. Verify against `docs/engine-reference/godot/modules/rendering.md` before using in code — this name may have changed with the 4.6 glow rework. If the constant name differs, update the code and add a comment citing the docs reference.

**Lint check for `glow_enabled = true`** (AC-4): This is a CI grep check, not a runtime check. Add to `tests/unit/foundation/post_process_stack/glow_ban_lint_test.gd`:
```
func test_no_glow_enabled_in_src():
    # Grep src/ for glow_enabled = true
    # Use DirAccess to walk src/ and FileAccess to read each .gd file
    # Assert zero matches
```

**Forbidden post-process properties** (AC-2): The full list from GDD Core Rule 7 — `bloom` (note: Godot uses `glow_*` naming, not `bloom_*`; Godot's "Glow" IS the bloom effect), `chromatic_aberration_enabled`, `ssr_enabled` (screen-space reflections), `motion_blur_enabled` (if it exists in the `Environment` resource), `dof_blur_far_enabled`, `dof_blur_near_enabled`. Verify exact property names in `docs/engine-reference/godot/modules/rendering.md` for Godot 4.6.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: PostProcessStack autoload scaffold (must be DONE before `_ready()` hook can be added here)
- Story 007: Verifying that no bloom halo is visible around emissive materials in the plaza scene (visual confirmation)
- Level Streaming epic: per-section WorldEnvironment authoring (each section author must ensure their scene's WorldEnvironment passes this validation)

---

## QA Test Cases

**AC-1 — Glow enforcement hook fires**
- Given: a test scene with a `WorldEnvironment` node where `environment.glow_enabled = true` is explicitly set
- When: the scene is loaded (PostProcessStack `_on_node_added` fires)
- Then: in debug build, `assert(false, ...)` fires with the "Art Bible 8J" message; in a simulated release-mode test, `push_warning` is called and `we.environment.glow_enabled` is set to `false`
- Edge cases: WorldEnvironment with `environment == null` → no crash, silent skip; node_added fires before PostProcessStack is ready → check initialization order

**AC-3 — Tonemap mode is neutral linear**
- Given: the project's WorldEnvironment configuration (plaza stand-in scene)
- When: `environment.tonemap_mode` is read at test time
- Then: value equals `Environment.TONE_MAPPER_LINEAR` (verify constant name before assertion)
- Edge cases: tonemap_mode changed by accident in editor UI → validation hook logs a warning (non-blocking at VS scope)

**AC-4 — Lint: no glow_enabled = true in src/**
- Given: all `.gd` files under `src/`
- When: each file's contents are read and searched for the exact string `glow_enabled = true`
- Then: zero matches
- Edge cases: test files in `tests/` may legitimately set `glow_enabled = true` for behavior verification — the grep scope is `src/` only; verify the grep path boundary is correct

**AC-5 — Hook actually runs (not silently bypassed)**
- Given: debug build running
- When: a scene with `WorldEnvironment.glow_enabled = true` is added to the scene tree during a unit test
- Then: an error (assert or push_error) is captured by the GUT error-listener; test passes if and only if the error contains "Art Bible 8J"
- Edge cases: PostProcessStack not yet connected to `node_added` signal → silent miss; hook connected but `assert()` suppressed → check that GUT captures assert failures

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/post_process_stack/glow_ban_enforcement_test.gd` — must exist and pass
- Covers: AC-1 (enforcement hook fires on glow-enabled WorldEnvironment), AC-4 (lint grep confirms zero `glow_enabled = true` in src/), AC-5 (hook is actually running)
- AC-2 and AC-3 (scene-level audits of the actual WorldEnvironment configs) documented in `production/qa/evidence/glow-ban-audit-evidence.md` with per-scene audit results

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PostProcessStack `_ready()` scaffold must be DONE; this story adds the `node_added` hook to that `_ready()`)
- Unlocks: Story 007 (visual verification that glow ban is in effect — no bloom halos on emissive materials)
