# Story 005: Plaza per-tier visual validation — composition order, Slot 1 perf measurement, sign-off

> **Epic**: Outline Pipeline
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: 3-4 hours (M — scene authoring, per-tier mesh placement, screenshot evidence, perf capture)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/outline-pipeline.md`
**Requirement**: TR-OUT-002, TR-OUT-003, TR-OUT-005, TR-OUT-006, TR-OUT-009
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Stencil ID Contract), ADR-0005 (FPS Hands Outline Rendering), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary (ADR-0001)**: Production outline pipeline must run as a single `CompositorEffect` on Forward+ render path; all four tiers must be visible in-scene at correct pixel widths; Slot 1 cost must be measured on minimum target hardware. This story assembles the first production-representative Plaza scene, places representative meshes for each tier (Eve-slot Tier 0 exemption documented, Plaza document Tier 1, Plaza guard Tier 2, Plaza environment Tier 3), verifies the full pipeline (stories 001–004) produces correct visual output, captures the measured Slot 3 cost, and obtains visual sign-off. This sign-off replaces/augments the Sprint 01 sign-off on `prototypes/verification-spike/fps_hands_demo.tscn` for the production code path.
**ADR Decision Summary (ADR-0005)**: Eve's FPS hands DO NOT participate in the stencil outline pipeline. They render in a SubViewport via an inverted-hull shader per ADR-0005, composited via CanvasLayer AFTER the main camera's `CompositorEffect` completes. This story verifies that the hands SubViewport composition does NOT interfere with the main outline pass — the test confirms no stencil corruption where the hands SubViewport overlaps world geometry.
**ADR Decision Summary (ADR-0008)**: Outline Pipeline is part of Slot 3 (Post-Process chain, 2.5 ms cap on Iris Xe). The outline-specific sub-budget from ADR-0001 is 2.0 ms. This story measures the actual cost on Vulkan-Linux (RTX 4070 as proxy) and records it toward the ADR-0008 Gate 1 evidence trail. Note: ADR-0008 is Proposed; its acceptance gates (Gate 1 Iris Xe measurement, Gate 2 RTX 2060 informative) are not fully closeable until the Restaurant reference scene and Iris Xe hardware access are available — those are post-VS per EPIC.md VS Scope Guidance. This story measures Slot 3 cost on the current dev hardware as a documented interim measurement.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**:
- Sprint 01 finding F5 (verified 2026-04-30): confirmed `POST_OPAQUE` effect_callback_type ensures the outline pass runs after opaque geometry has populated the stencil buffer. Stencil is populated by story 001's `OutlineTier.set_tier()` materials; the pass correctly reads them. Composition order (outline → sepia-dim → transparent → CanvasLayer UI) is locked by `CompositorEffect` execution ordering in Godot 4.6.
- Sprint 01 finding F6 (verified 2026-04-30): jump-flood algorithm (story 003) is the production algorithm. This story validates that the production algorithm meets the 2.0 ms budget on the current dev hardware and extrapolates to Iris Xe (or measures directly if Iris Xe hardware is available at the time this story executes).
- Sprint 01 finding F4 (verified 2026-04-29): native `stencil_mode = STENCIL_MODE_OUTLINE` is world-space — confirming its absence from any production mesh in this scene is part of the review checklist.
- ADR-0005 Accepted 2026-05-01 after user visual sign-off on `fps_hands_demo.tscn` (Linux Vulkan, Arch, Godot 4.6.2 stable). The baseline is documented in `prototypes/verification-spike/verification-log.md` §ADR-0005 → Accepted. This story's sign-off on the production Plaza scene is a new artifact at a higher confidence level (production code path, not prototype).
- ADR-0001 visual sign-off (2026-05-01): `stencil_compositor_demo.tscn` prototype verified screen-space stability of outlines via the production CompositorEffect path. This story validates the same API in production code on a more representative scene.
- Godot 4.6 D3D12 explicitly disabled; project forces Vulkan on Windows via `project.godot [rendering] rendering_device/driver.windows="vulkan"`. All measurements and sign-offs on Vulkan only (ADR-0001 Amendment A2 + technical-preferences.md). D3D12 parity is not a concern.

**Control Manifest Rules (Presentation + Foundation)**:
- Required (ADR-0001 IG 1): every `MeshInstance3D` in the Plaza demo scene MUST have `OutlineTier.set_tier()` called or have the stencil property set via the scene editor — no unmarked visible meshes allowed
- Required (ADR-0001 IG 4): comedic hero props (oversized signage, labeled crates) get Tier 1 HEAVIEST locally regardless of surrounding environment tier
- Required (ADR-0001 IG 7): the jump-flood algorithm is active in the production outline shader (verified by the pass completing within budget and producing correct pixel widths)
- Required (Presentation, Manifest 2026-04-30): outline pass runs `POST_OPAQUE` — verified by correct visual output (world geometry outlined, transparent surfaces and CanvasLayer UI not outlined)
- Forbidden (Presentation, Manifest 2026-04-30): never use `STENCIL_MODE_OUTLINE` on any mesh in this scene; code review verifies all materials use `STENCIL_MODE_CUSTOM` or no stencil modification
- Performance Guardrail (ADR-0008 Slot 3): Post-Process chain ≤2.5 ms on Iris Xe, with outline sub-budget ≤2.0 ms; this story measures and records the cost on dev hardware as interim evidence; per-slot CI gate deferred to ADR-0008 Gate 1 (Restaurant reference scene)

---

## Acceptance Criteria

*From GDD `design/gdd/outline-pipeline.md` §Acceptance Criteria AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-19, AC-21, and EPIC.md Definition of Done:*

- [ ] **AC-1**: A Plaza reference scene exists at `tests/reference_scenes/outline_pipeline_plaza_demo.tscn`. The scene contains: a Camera3D with `OutlineCompositorEffect` attached via a `Compositor` resource; a static environment plane (Tier 3, stencil_reference = 3); a Plaza guard stand-in mesh (capsule or box, Tier 2, stencil_reference = 2); a document prop stand-in mesh (flat plane, Tier 1, stencil_reference = 1); a document-overlay dim stand-in ColorRect on a CanvasLayer (Tier 0, no stencil write — standard CanvasLayer rendering); a comedic signage stand-in mesh (box with Tier 1, surrounded by Tier 3 environment). (TR-OUT-002, GDD AC-8)
- [ ] **AC-2**: GIVEN the Plaza reference scene running at 1080p native (`resolution_scale = 1.0`), WHEN a screenshot is taken and outline pixel widths are measured, THEN: Tier 1 outlines (document stand-in, signage) are 4 ± 0.5 px; Tier 2 outline (guard stand-in) is 2.5 ± 0.5 px; Tier 3 outline (environment plane) is 1.5 ± 0.5 px; the document-overlay ColorRect has NO outline on its edges. (TR-OUT-002, GDD AC-5, AC-6, AC-7, AC-8, AC-9)
- [ ] **AC-3**: GIVEN the Plaza reference scene, WHEN outline colors are sampled at Tier 1, Tier 2, and Tier 3 silhouettes, THEN all three are (26, 26, 26) ± 2 in sRGB. No tier produces a different outline color. (TR-OUT-003, GDD AC-10)
- [ ] **AC-4**: GIVEN the Plaza scene with the Camera3D rotated to face away from all geometry (pure sky / cleared framebuffer), WHEN a screenshot is taken, THEN no outlines are visible — the shader discards all Tier 0 pixels with zero cost. (GDD §Edge Cases "geometry-free direction")
- [ ] **AC-5**: GIVEN a bright ambient light and a near-zero ambient light applied to the same guard stand-in mesh in the Plaza scene, WHEN screenshots are taken in both conditions, THEN the guard's outline thickness and color are identical in both shots. Diegetic lighting does not weaken outlines. (TR-OUT-009, GDD AC-11)
- [ ] **AC-6**: GIVEN the Plaza scene with a `SubViewportContainer` + `SubViewport` stand-in for Eve's hands (CanvasLayer layer = 10, `transparent_bg = true`), WHEN the main camera's `CompositorEffect` runs and the SubViewport is composited, THEN the world outline pass does NOT show stencil corruption at the SubViewport overlap region; outline pixels behind the transparent parts of the SubViewport are correctly visible. (ADR-0005 non-interference verification, GDD §Interactions "Player Character FPS hands exception")
- [ ] **AC-7**: GIVEN the Plaza reference scene at 1080p (dev hardware, Vulkan-Linux), WHEN 300 frames are captured via the Godot profiler and the per-frame CompositorEffect callback duration is measured, THEN the outline pass p95 cost is recorded in `production/qa/evidence/story-005-slot1-perf-evidence.md`. If the measurement is ≤2.0 ms: PASS against ADR-0001 budget. If between 2.0 ms and 2.5 ms: log a WARNING (within Slot 3 overall cap but over outline sub-budget). If >2.5 ms: FAIL — investigate before sign-off. (TR-OUT-006, ADR-0008 Slot 3 sub-budget, GDD AC-21 deferred from Restaurant to Plaza for VS)
- [ ] **AC-8**: GIVEN Shader Baker pre-compile active (`.glsl.import` SPIR-V artifacts exist), WHEN the Plaza scene is loaded fresh (first run post-bake), THEN the first frame loads within 16 ms (no first-frame stutter from shader compilation). Verified by recording the first-frame time in `production/qa/evidence/story-005-slot1-perf-evidence.md`. (TR-OUT-006, GDD AC-22)
- [ ] **AC-9**: Visual sign-off is documented in `production/qa/evidence/story-005-visual-signoff.md` containing: annotated screenshot with tier-thickness measurements; outline color samples; performance measurement from AC-7; confirmation that production code (stories 001–004) matches the Sprint 01 prototype visual output and supersedes the `fps_hands_demo.tscn` baseline for the stencil-path meshes. (EPIC.md Definition of Done — "Visual sign-off on production Plaza scene")

---

## Implementation Notes

*Derived from ADR-0001 §Migration Plan, ADR-0008 §Verification Contract, EPIC.md Definition of Done, and Sprint 01 verification-log §ADR-0005 → Accepted:*

The Plaza reference scene is a minimal test scene — NOT a full game-world scene. It uses stand-in primitives (capsules, boxes, planes) with production `OutlineTier.set_tier()` applied. The purpose is to exercise the full production pipeline (stories 001–004) in a controlled, repeatable, version-controlled scene.

Scene setup procedure:
1. Create `tests/reference_scenes/outline_pipeline_plaza_demo.tscn` with a `Node3D` root.
2. Add a `Camera3D` with a `Compositor` resource assigned; add `OutlineCompositorEffect` to the Compositor's `effects` array.
3. Add a `DirectionalLight3D` (one cascade only per ADR-0008 Constraint — cascade count = 1 locked; validate this is configured correctly in the scene).
4. Add environment stand-in: a large ground plane `MeshInstance3D` → `OutlineTier.set_tier(ground_plane, OutlineTier.LIGHT)` in `_ready()` OR set `stencil_mode = 3, stencil_flags = 2, stencil_compare = 0, stencil_reference = 3` in the scene editor on the material.
5. Add guard stand-in: a `CapsuleMesh` `MeshInstance3D` → `stencil_reference = 2`.
6. Add document stand-in: a flat `PlaneMesh` `MeshInstance3D` → `stencil_reference = 1`.
7. Add comedic signage stand-in: a `BoxMesh` next to the environment plane → `stencil_reference = 1` (Tier 1 locally per ADR-0001 IG 4).
8. Add a `CanvasLayer` (layer = 10) with a `ColorRect` covering 1/4 of the screen — simulates the document-overlay dim; NOT a stencil writer; should have NO outline on its edges.
9. Add a `SubViewportContainer` + `SubViewport` stand-in (empty, `transparent_bg = true`) on a CanvasLayer (layer = 10) — simulates the hands SubViewport position; verify world outline is visible behind it.

Performance measurement procedure:
- Use `Performance.get_monitor(Performance.RENDER_GPU_FRAME_TIME)` or Godot's built-in Profiler (Remote Profiler in editor, "GPU" category, "PostProcess" slot).
- Alternatively, add a `Time.get_ticks_usec()` before/after the `_render_callback` dispatch in a debug build.
- Record 300 frames, compute p50/p95/p99 of the outline pass cost.
- Record: hardware (CPU model, GPU model, driver version), OS, Godot version, render resolution, `resolution_scale` value, shadow cascade count.

The sign-off document format mirrors ADR-0008 §Verification Contract Gate evidence format:
```
production/qa/evidence/story-005-visual-signoff.md
production/qa/evidence/story-005-slot1-perf-evidence.md
production/qa/evidence/story-005-plaza-outline-annotated.png
```

**ADR-0008 deferred context**: ADR-0008 Gate 1 requires measurement on the full Restaurant dense-interior reference scene on Iris Xe hardware. That measurement is explicitly deferred post-VS per EPIC.md VS Scope Guidance. The Plaza demo measurement in this story is an interim measurement on dev hardware. It closes the EPIC.md Definition of Done item "Slot 1 cost measured" for VS purposes. ADR-0008 Gate 1 remains open and is scheduled for the first Production sprint that ships an outline-bearing complex scene.

---

## Out of Scope

*Handled by neighbouring stories and post-VS deferrals — do not implement here:*

- Story 001: `OutlineTier.set_tier()` implementation (must be DONE before this story)
- Story 002: `OutlineCompositorEffect` Stage 1 pipeline (must be DONE)
- Story 003: jump-flood compute shader Stage 2 (must be DONE)
- Story 004: resolution-scale wiring (must be DONE)
- Post-VS deferral: Restaurant scene reference cost measurement (planned for first Production sprint that ships outline-bearing complex scene — explicitly deferred per EPIC.md VS Scope Guidance)
- Post-VS deferral: Iris Xe hardware measurement (deferred per EPIC.md — no Iris Xe hardware access confirmed for VS; ADR-0008 Gate 1 tracks this)
- Post-VS deferral: per-tier outline-color customisation beyond default `#1A1A1A`
- Post-VS deferral: LOD-based thickness scaling
- ADR-0005 Gates G3, G4, G5 (resolution-scale toggle on rigged hands mesh, animated mesh artifacts, Shader Baker × `material_overlay`) — Player Character epic scope, not outline pipeline epic scope
- PostProcessStack integration: full `Compositor` chain with sepia-dim pass ordered after outline (PostProcessStack epic)

---

## QA Test Cases

*Visual/Feel story — manual verification with screenshot evidence required.*

**AC-1 — Plaza demo scene exists with all 5 tier representatives**
- **Setup**: open `tests/reference_scenes/outline_pipeline_plaza_demo.tscn` in Godot 4.6.2 editor
- **Verify**: scene tree contains Camera3D with Compositor+OutlineCompositorEffect, plus 5 MeshInstance3D nodes (ground plane Tier 3, guard capsule Tier 2, document plane Tier 1, signage box Tier 1, CanvasLayer ColorRect Tier 0) and a SubViewport stand-in
- **Pass condition**: scene opens without errors; all mesh materials have `stencil_reference` set; no `STENCIL_MODE_OUTLINE` materials present (code review checklist gate)

**AC-2 — Per-tier outline thickness at 1080p**
- **Setup**: run the Plaza demo at 1080p, `resolution_scale = 1.0`; take a screenshot
- **Verify**: measure outline pixel width at each tier silhouette (a pixel editor or the Godot remote debugger's zoom tool)
- **Pass condition**: Tier 1 = 4 ± 0.5 px, Tier 2 = 2.5 ± 0.5 px, Tier 3 = 1.5 ± 0.5 px, Tier 0 ColorRect = 0 px (no outline)
- **Evidence**: `production/qa/evidence/story-005-plaza-outline-annotated.png` with measurement callouts

**AC-3 — Outline color uniformity**
- **Setup**: same screenshot as AC-2
- **Verify**: sample outline pixel color at each tier; record RGB values
- **Pass condition**: all three tiers sample to (26, 26, 26) ± 2; no tint or hue variation
- **Evidence**: color sample values noted in `production/qa/evidence/story-005-visual-signoff.md`

**AC-5 — Lighting does not weaken outlines**
- **Setup**: set ambient light energy to 2.0 (bright); screenshot. Set ambient light energy to 0.01 (near-dark); screenshot
- **Verify**: guard stand-in outline is visible and same pixel width in both shots; outline color is consistent
- **Pass condition**: outline thickness identical ± 0.5 px; color ± 2 RGB; silhouette readable in both lighting conditions

**AC-6 — SubViewport hands non-interference**
- **Setup**: Plaza demo scene with SubViewport stand-in active (CanvasLayer layer = 10, SubViewport transparent_bg = true)
- **Verify**: screenshot the area where the SubViewport overlaps world geometry; no stencil corruption (stray outlines, color artifacts, black boxes)
- **Pass condition**: world outlines are visible through transparent areas of the SubViewport; no artifacts at overlap boundaries

**AC-7 — Slot 1 performance measurement**
- **Setup**: run the Plaza demo for 300 frames; measure outline pass GPU cost via Godot Profiler
- **Verify**: record p50/p95/p99 values
- **Pass condition**: p95 ≤ 2.0 ms (PASS); 2.0–2.5 ms (WARNING, log); >2.5 ms (FAIL, investigate)
- **Evidence**: `production/qa/evidence/story-005-slot1-perf-evidence.md` with per-percentile table, hardware spec, shadow cascade count

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/story-005-visual-signoff.md` — structured sign-off document containing: hardware spec, annotated screenshot, per-tier thickness measurements, outline color samples, lighting-invariance comparison, SubViewport non-interference confirmation, lead sign-off
- `production/qa/evidence/story-005-slot1-perf-evidence.md` — performance measurement table (p50/p95/p99 GPU cost, hardware spec, shadow cascade count = 1 confirmed, Shader Baker first-frame time)
- `production/qa/evidence/story-005-plaza-outline-annotated.png` — annotated screenshot referenced by the sign-off document

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (OutlineTier class), Story 002 (CompositorEffect Stage 1), Story 003 (jump-flood Stage 2), Story 004 (resolution-scale wiring) — all four must be DONE before this story begins
- Unlocks: Epic Definition of Done (all stories implemented + sign-off = outline pipeline VS COMPLETE); ADR-0008 Gate 1 evidence trail (interim measurement before Restaurant + Iris Xe measurement in first Production sprint)
- Post-VS dependency note: update `production/epics/outline-pipeline/EPIC.md` ADR-0008 deferral note with the Plaza measurement result and schedule for Restaurant + Iris Xe measurement
