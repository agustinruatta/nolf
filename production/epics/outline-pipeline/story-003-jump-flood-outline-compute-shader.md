# Story 003: Jump-flood outline compute shader — Stage 2 algorithm + outline color composition

> **Epic**: Outline Pipeline
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: 4-6 hours (L — GLSL compute shader authoring, jump-flood algorithm implementation, outline color validation)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/outline-pipeline.md`
**Requirement**: TR-OUT-003, TR-OUT-006, TR-OUT-008
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Stencil ID Contract), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary (ADR-0001)**: Stage 2 of the outline `CompositorEffect` is a GLSL compute shader (`outline_jump_flood.glsl`) that reads the per-pixel tier-mask intermediate texture produced by Stage 1 (story 002) as a regular `image2D`. For each pixel that is NOT interior to any tier, the shader samples the neighborhood using the jump-flood distance-field algorithm and writes outline color `#1A1A1A` (RGB 26/255 each) to the scene color buffer at pixels within a tier-specific kernel radius of a tier-marked pixel. The algorithm MUST be jump-flood (Bgolus-style, `log2(max_radius_px)` ping-pong passes) — the naive `(2·max_radius_px+1)²` scan is explicitly forbidden (verified finding F6, exceeds 2 ms budget on Iris Xe). Reference implementation: `dmlary/godot-stencil-based-outline-compositor-effect` (MIT, Godot 4.5).
**ADR Decision Summary (ADR-0008)**: The outline pass is within Slot 3 (Post-Process chain 2.5 ms Iris Xe cap). Jump-flood on Iris Xe at 75% scale is extrapolated to ~0.4 ms — within budget with margin. Performance evidence is measured in story 005 (Plaza scene + `/perf-profile`).

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**:
- Sprint 01 finding F6 (verified 2026-04-30, CONDITIONAL PASS): naive `(2·max_radius_px+1)²` scan ≈ 0.92 ms on RTX 4070 Vulkan at 1080p; extrapolated to ~6.4 ms on Intel Iris Xe at 1080p native and ~3.7 ms at 1440×810 (75% scale fallback). Both exceed the 2.0 ms ADR-0001 budget. Jump-flood (dmlary reference) is ~10× cheaper at the same outline width; estimated ~0.4 ms on Iris Xe at 75% scale. This finding is the binding constraint on the algorithm chosen here. ADR-0001 IG 7 is the formal rule.
- Sprint 01 finding F5 (verified 2026-04-30): the intermediate tier-mask texture from Stage 1 is a regular RGBA16F texture (not the depth-stencil attachment); it is bindable as an `image2D` in a compute shader without any stencil-aspect complications. The compute shader path is clean once the stencil-test hardware has done its work in Stage 1.
- Sprint 01 finding G4 (verified 2026-04-30): `RDShaderFile` (`.glsl`) shaders are SPIR-V pre-compiled at edit-time import, not via Shader Baker. The `.glsl.import` file is created by Godot's `glsl` importer. Both the stencil_pass and outline shaders from the spike were pre-compiled successfully. The outline compute shader in this story uses the same `.glsl` → `RDShaderFile` → `get_spirv()` → `rd.shader_create_from_spirv()` path.
- ADR-0005 verified Accepted 2026-05-01 (user visual sign-off on `fps_hands_demo.tscn`): Eve's FPS hands use an inverted-hull shader inside a SubViewport with `transparent_bg = true`. The SubViewport is composited over the main view via CanvasLayer (layer 10) AFTER the main camera's `CompositorEffect` completes (CanvasLayer render order is deterministic by layer index). Therefore: the jump-flood pass runs on the main framebuffer BEFORE the hands SubViewport is composited on top. The hands outline (inverted-hull, not stencil) does NOT interfere with the jump-flood pass. No special handling is needed in this shader for the hands. GDD §Detailed Design Rule 9: outline pass does NOT apply to CanvasLayer UI (including the hands SubViewport composite) — those are drawn after.
- Glow rework in Godot 4.6: glow processes BEFORE tonemapping (changed from 4.5 and earlier). The outline pass runs `POST_OPAQUE` (before glow and tonemapping). This means outline pixels are subject to the glow pass if glow is enabled. Art Bible 8J item 7 specifies glow is DISABLED in this project — no issue. Document this in the shader comment for future maintenance.
- SMAA 1x (Godot 4.5+ option): can be applied after the outline pass to smooth screen-level aliasing. Not in VS scope; flagged as post-VS option.

**Control Manifest Rules (Presentation)**:
- Required (ADR-0001 IG 7): production algorithm MUST be jump-flood (Bgolus-style) or equivalent log2-pass distance-field; naive scan is forbidden
- Required (ADR-0001 §Decision): outline color MUST be `#1A1A1A` (RGB 26, 26, 26, normalized 0.1020); single uniform across all tiers; no tier produces a different outline color
- Required (GDD §Detailed Design Rule 16): the shader defines exactly 4 branches (tier 0 discard, tier 1 kernel, tier 2 kernel, tier 3 kernel); no hardcoded pixel weights — all read from uniforms
- Forbidden (Presentation, Manifest 2026-04-30): never use the naive `(2·max_radius_px+1)²` scan as production algorithm (verified F6 budget failure)
- Forbidden (GDD §Detailed Design Rule 3, Rule 10): outline color MUST NOT vary by tier; lighting MUST NOT affect outline color (pass runs on color buffer after diegetic lighting is baked in, writing outline atop it)
- Performance Guardrail: total GPU outline pass ≤2.0 ms on Iris Xe at 75% scale; jump-flood estimated ~0.4 ms with margin (ADR-0001 §Performance Implications, verified F6 extrapolation). Measurement deferred to story 005 (Plaza scene `/perf-profile`).

---

## Acceptance Criteria

*From GDD `design/gdd/outline-pipeline.md` §Acceptance Criteria AC-10, AC-11, AC-16, AC-22, and ADR-0001 IG 7:*

- [ ] **AC-1**: `src/rendering/outline/shaders/outline_jump_flood.glsl` is a GLSL compute shader (`#version 450`). It reads the RGBA16F intermediate tier-mask texture from story 002's Stage 1 as an input image (`layout(set=0, binding=0) uniform sampler2D tier_mask_texture`) and writes outline pixels to the scene color buffer (`layout(set=0, binding=1, rgba16f) uniform restrict image2D scene_color_texture`). (TR-OUT-006, TR-OUT-008, ADR-0001 Stage 2)
- [ ] **AC-2**: The algorithm is jump-flood: `ceil(log2(max_radius_px))` ping-pong passes (e.g., 3 passes for a 4-px outline). Each pass samples 8 neighbors at `step_size = max_radius / 2^pass_index` offsets. The output of each pass seeds the input of the next. After all passes, every non-interior pixel knows its distance to the nearest tier-marked pixel. (TR-OUT-006, ADR-0001 IG 7, finding F6)
- [ ] **AC-3**: Per-tier kernel radius uniforms: `uniform float tier1_radius_px`, `uniform float tier2_radius_px`, `uniform float tier3_radius_px`. These are set by the owning `OutlineCompositorEffect` GDScript from the tier weight table `[4.0, 2.5, 1.5]` at 1080p reference, multiplied by the resolution-scale factor (story 004 wires the actual resolution-scale; for VS this story uses `resolution_scale = 1.0` as the default). A pixel is drawn as an outline if its jump-flood nearest-tier-marked-pixel distance ≤ the applicable tier's radius. (TR-OUT-002, TR-OUT-004 partial, GDD Formula 1)
- [ ] **AC-4**: GIVEN any pixel drawn as an outline by the shader, WHEN the outline color is inspected, THEN the color written to the scene color buffer is exactly `vec4(26.0/255.0, 26.0/255.0, 26.0/255.0, 1.0)` (= `#1A1A1A`). No tier produces a different outline color. The color is declared as a `uniform vec4 outline_color` with default `vec4(0.10196, 0.10196, 0.10196, 1.0)`. (TR-OUT-003, GDD AC-10, GDD §Detailed Design Rule 3)
- [ ] **AC-5**: GIVEN a guard (Tier 2 stencil marker in the tier mask) and ironwork environment (Tier 3 stencil marker) in the same frame, WHEN the compute shader runs, THEN pixels adjacent to the guard's silhouette receive the Tier 2 kernel radius (2.5 px at 1080p), and pixels adjacent to the ironwork receive the Tier 3 kernel radius (1.5 px). Pixels with no nearby tier-marked pixel receive no outline. Pixels marked as Tier 0 (no-outline) produce no outline on their own edges. (TR-OUT-002, GDD AC-6, AC-7, AC-9)
- [ ] **AC-6**: GIVEN varying diegetic lighting (warm amber vs cool moonlight), WHEN the outline is drawn, THEN the outline color is constant `#1A1A1A` regardless of the ambient light behind the outlined pixel. The jump-flood pass runs AFTER diegetic lighting is baked into the scene color buffer; it overwrites the selected pixels with the flat outline color rather than multiplying or blending with the lit scene. (TR-OUT-009, GDD AC-11)
- [ ] **AC-7**: GIVEN Godot Shader Baker pre-compile enabled, WHEN the game loads a scene for the first time (post-bake), THEN the outline shader does not cause a measurable first-frame stutter (≤16 ms frame time on first load). Verified by confirming the `.glsl.import` SPIR-V pre-compile artifact exists after project open (per finding G4). (TR-OUT-006, GDD AC-22)

---

## Implementation Notes

*Derived from ADR-0001 §Key Interfaces Stage 2, ADR-0001 IG 7, verification-log finding F6, and the dmlary/godot-stencil-based-outline-compositor-effect reference (MIT, Godot 4.5):*

The jump-flood algorithm (Bgolus's "wide outlines" blog + dmlary reference) works in distance-field space:

1. **Seed pass**: For each pixel, if `tier_mask.r > 0.0` (interior to some tier), store `(uv, tier_marker)` as the "nearest seed" for that pixel. Non-interior pixels store `(invalid_uv, 0.0)`.
2. **Jump passes** (N = ceil(log2(max_radius_px)) iterations): Each pass samples 8 neighbors at offsets `±step_size` pixels (in each axis and diagonal). For each neighbor, if its stored nearest-seed distance to the current pixel is smaller than the current pixel's stored nearest-seed distance, update. Step size halves each iteration: `step = max_radius >> i`.
3. **Output pass**: For each pixel, the stored `nearest_seed_uv` gives the closest tier-marked pixel. If the distance to that seed ≤ the tier's radius AND the current pixel is NOT already interior to the same tier (i.e., it is an edge pixel), write the outline color. Otherwise write nothing (let the existing scene color pass through).

The intermediate texture from Stage 1 stores `R` channel only (tier marker float). Use a single-channel intermediate or the R channel of the RGBA16F texture. Two ping-pong textures are needed for the jump-flood passes (read from one, write to the other, swap each pass).

Push constants or UBO for per-pass parameters: `step_size` (int), `frame_size` (vec2 — needed for UV-to-pixel conversion). Tier radius uniforms can be per-effect uniforms set from GDScript at `_render_callback` time.

The `OutlineCompositorEffect.gd` Stage 2 dispatch:
```gdscript
# After Stage 1 (story 002) produces tier_mask_intermediate_texture:
# Dispatch jump-flood compute passes
var num_passes: int = ceili(log2(max(tier1_radius_px, tier2_radius_px, tier3_radius_px)))
for i: int in range(num_passes):
    var step_size: int = int(pow(2, num_passes - 1 - i))
    # bind ping-pong textures, dispatch, swap
# Dispatch final output pass: write outline_color to scene color buffer
```

The workgroup size should be `8x8x1` (a typical good-performance choice for fullscreen compute; matches dmlary's reference). The compute shader is dispatched with `ceil(render_width / 8)` × `ceil(render_height / 8)` workgroups.

**Reference implementation**: dmlary/godot-stencil-based-outline-compositor-effect (MIT). The algorithm is identical; the modifications for The Paris Affair are: (a) 3 tiers instead of 1, each with its own radius threshold; (b) tier-specific pixel radii sourced from the GDD Formula 1 weight table `[0.0, 4.0, 2.5, 1.5]`; (c) production GLSL must be rewritten to production standards (static-typed uniforms, comment blocks, no debug output in release).

**Glow rework note (Godot 4.6)**: glow processes before tonemapping in Godot 4.6. Since the outline pass runs `POST_OPAQUE` (before glow), outline pixels WILL go through the glow pass if glow is enabled. Art Bible 8J item 7 disables glow in this project. Add a comment in the shader source: `// NOTE: Godot 4.6 glow runs before tonemapping. Art Bible 8J item 7 disables glow — outline color is not subject to glow bloom. If glow is re-enabled, outline pixels may bloom. Verify and re-disable if needed.`

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Stage 1 stencil-test pipeline that produces the intermediate tier-mask texture this shader reads
- Story 004: resolution-scale uniform wiring; `resolution_scale`-adjusted kernel width formula (Formula 2); this story uses `resolution_scale = 1.0` as a placeholder uniform for VS
- Story 005: visual sign-off screenshots; Slot 1 perf measurement via `/perf-profile`; comparison of outline thickness at each tier at 1080p against GDD pixel targets
- PostProcessStack integration: wiring this shader into the final `Compositor` chain (PostProcessStack epic)
- SMAA anti-aliasing pass after outlines (flagged as post-VS polish option in GDD §Open Questions)
- Per-tier outline-color customisation beyond the default `#1A1A1A` — explicitly deferred post-VS per EPIC.md VS Scope Guidance

---

## QA Test Cases

*Visual/Feel story — manual verification steps required, supported by automated SPIR-V pre-compile check.*

**AC-1 + AC-7 — Shader compiles and pre-compiles to SPIR-V**
- **Setup**: open the project in Godot 4.6.2 editor; verify `src/rendering/outline/shaders/outline_jump_flood.glsl` is imported
- **Verify**: `.godot/imported/` contains a `.res` file corresponding to `outline_jump_flood.glsl`; the import file has `importer="glsl"` and `type="RDShaderFile"`; `ResourceLoader.load("res://src/rendering/outline/shaders/outline_jump_flood.glsl").get_spirv()` returns a non-null `RDShaderSPIRV` with no error
- **Pass condition**: SPIR-V artifact exists; no GLSL compile errors in editor output

**AC-2 + AC-3 — Jump-flood algorithm visual correctness — Plaza reference**
- **Setup**: run the Plaza reference scene (story 005 scene, or a minimal 3-mesh scene with Tier 1, 2, 3 meshes) with `OutlineCompositorEffect` active (Stage 1 + Stage 2)
- **Verify**: screenshot the scene; measure outline pixel width at each tier using an image editor (count dark pixels crossing the silhouette edge)
- **Pass condition**: Tier 1 outline is 4 ± 0.5 px at 1080p native (`resolution_scale = 1.0`); Tier 2 is 2.5 ± 0.5 px; Tier 3 is 1.5 ± 0.5 px; no outline present on Tier 0 areas
- **Evidence path**: `production/qa/evidence/story-003-outline-thickness-evidence.md` + annotated screenshot

**AC-4 — Outline color uniformity**
- **Setup**: same Plaza scene as above
- **Verify**: use the Godot remote debugger color picker or an external screenshot tool to sample the outline pixel color at three locations (Tier 1 silhouette, Tier 2 silhouette, Tier 3 silhouette)
- **Pass condition**: all three sampled colors are within ±2 RGB units of (26, 26, 26) in sRGB. No tier produces a visually different outline tint.
- **Evidence**: included in `production/qa/evidence/story-003-outline-thickness-evidence.md` with color sample values

**AC-5 — Per-tier radius correctness in a mixed-tier frame**
- **Setup**: Plaza scene with both a Tier 2 guard mesh and a Tier 3 environment mesh visible simultaneously
- **Verify**: outline thickness on the guard silhouette is visibly thicker than on the environment mesh; no outline on the document-overlay Tier 0 stand-in mesh
- **Pass condition**: visible pixel-weight hierarchy between guard (2.5 px) and environment (1.5 px) is discernible at 1080p; a pixel-level count confirms the difference (2.5 px > 1.5 px by at least 0.5 px margin)

**AC-6 — Lighting invariance**
- **Setup**: same guard mesh rendered in two lighting conditions: full ambient (bright) and near-zero ambient (dark)
- **Verify**: outline color samples in both conditions
- **Pass condition**: outline color is (26, 26, 26) ± 2 in both bright and dark lighting conditions; the outline does NOT brighten, darken, or tint with scene illumination

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/story-003-outline-thickness-evidence.md` — annotated screenshots showing per-tier outline thickness measurements at 1080p, outline color samples, lighting-invariance comparison; includes lead sign-off confirming visual targets match GDD §Formulas Formula 1 (4 / 2.5 / 1.5 px) and Art Bible 4.4 color `#1A1A1A`
- SPIR-V pre-compile artifact confirmed in `.godot/imported/` (can be verified by automated CI step in the `tests/` directory or manually documented in evidence)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Stage 1 CompositorEffect must produce the RGBA16F intermediate tier-mask texture that this Stage 2 shader reads; the intermediate texture format and binding conventions must be consistent)
- Unlocks: Story 004 (resolution-scale wiring adds the `resolution_scale` uniform this shader already declares as a placeholder at value 1.0); Story 005 (Plaza scene visual sign-off requires Stage 1 + Stage 2 both working)
