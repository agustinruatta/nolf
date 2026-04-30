# Story 002: CompositorEffect stencil-test pipeline — per-tier graphics passes + intermediate tier-mask texture

> **Epic**: Outline Pipeline
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 4-6 hours (L — Vulkan RenderingDevice API, per-tier graphics pipelines, intermediate texture management)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/outline-pipeline.md`
**Requirement**: TR-OUT-005, TR-OUT-002, TR-OUT-009
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Stencil ID Contract), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary (ADR-0001)**: The outline pass is a 2-stage `CompositorEffect`. Stage 1 (this story) uses three graphics pipelines — one per tier (T=1, 2, 3) — each with `RDPipelineDepthStencilState.enable_stencil = true` and `front_op_reference = T`. Each pipeline renders a fullscreen triangle; the GPU's stencil-test hardware filters fragments so only pixels whose scene stencil == T run the fragment shader. The fragment shader writes a tier-marker float (1.0 / 0.66 / 0.33 for T = 1/2/3) to an RGBA16F intermediate texture. After all three passes, this texture is a per-pixel tier-mask ready for Stage 2 (story 003's jump-flood compute shader). Stage 2 is NOT part of this story.
**ADR Decision Summary (ADR-0008)**: Outline Pipeline is Slot 3 of the frame budget (Post-Process chain 2.5 ms total on Iris Xe). The outline `CompositorEffect` must fit within 2.0 ms of that 2.5 ms slot. ADR-0008 is Proposed; the slot allocation is the normative input. Per-story perf gate deferred to story 005 (Plaza scene measurement).

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**:
- Sprint 01 finding F5 (verified 2026-04-30, Godot 4.6.2 stable, Linux Vulkan, RTX 4070): The stencil aspect of the depth-stencil texture is NOT directly sampleable from a compute shader. `RenderSceneBuffersRD.get_depth_layer(0)` returns the combined depth-stencil texture RID; binding it as a sampler in a compute shader exposes only the depth aspect. The correct API: build a graphics pipeline with `RDPipelineDepthStencilState.enable_stencil = true`, attach the scene's depth-stencil as the framebuffer's depth attachment, and let the GPU stencil-test hardware filter fragments. ADR-0001 §Key Interfaces pseudocode showing `sample_stencil(SCREEN_UV)` was wrong — finding F5 corrects this. The verified pattern is in `prototypes/verification-spike/stencil_compositor_outline.gd`.
- Sprint 01 finding F4 (verified 2026-04-29): `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` is world-space (outlines shrink at distance). NOT used here. The stencil values written by story 001's `OutlineTier.set_tier()` (STENCIL_MODE_CUSTOM path) are what this pipeline reads.
- Sprint 01 finding F6 (verified 2026-04-30, CONDITIONAL): naive `(2·max_radius_px+1)²` neighborhood scan exceeds the 2 ms budget on Intel Iris Xe even with 75% resolution-scale fallback (~3.7 ms at 1440×810 extrapolated from RTX 4070 measurement). This story's Stage 1 only builds the intermediate texture; Stage 2's algorithm choice (story 003) is where F6's constraint applies. However, this story MUST produce a clean intermediate texture that story 003's jump-flood shader can consume — the intermediate texture format and layout are load-bearing.
- Sprint 01 finding F2 (verified 2026-04-29, ADR-0003 context but applies here): `RDShaderFile` (`.glsl`) shaders are pre-compiled to SPIR-V at edit-time import via Godot's `glsl` importer. Both `stencil_pass.glsl` and `outline.glsl` in the spike were verified to produce `.glsl.import` files pointing to SPIR-V `.res` in `.godot/imported/`. This is the compilation path for the GLSL shaders used by `CompositorEffect`; it differs from `ShaderMaterial`'s Shader Baker path (finding F5 reframe of G4).
- `CompositorEffect` (Godot 4.3+ feature, in LLM training data conceptually, but the stencil-test graphics-pipeline pattern is post-cutoff per ADR-0001 §Engine Compatibility). Use `effect_callback_type = POST_OPAQUE` to ensure the stencil buffer is populated before the outline pass runs. Verified in the spike: first-frame stencil-read bug (GitHub issue #110629) was NOT triggered with `POST_OPAQUE` + `StandardMaterial3D.STENCIL_MODE_CUSTOM` setup.
- The production `CompositorEffect` node belongs to `PostProcessStack` autoload (ADR-0007, autoload slot 6). This story creates the `CompositorEffect` resource and its GLSL shaders; wiring it into `PostProcessStack` is a PostProcessStack epic concern. For VS, the `CompositorEffect` may be placed directly on the scene's `Camera3D` for validation.

**Control Manifest Rules (Presentation)**:
- Required (ADR-0001 §Key Interfaces): CompositorEffect stencil-test uses `RDPipelineDepthStencilState.enable_stencil = true`, `front_op_compare = COMPARE_OP_EQUAL`, `front_op_reference = N`, `front_op_compare_mask = 0xFF`; attach `RenderSceneBuffersRD.get_depth_layer(0)` as the framebuffer's depth attachment
- Required (ADR-0001 IG 7): jump-flood algorithm is mandatory in the production outline pass; this story's Stage 1 does NOT implement the outline algorithm — it implements only the intermediate tier-mask texture generation that the jump-flood Stage 2 (story 003) reads
- Forbidden (Presentation, Manifest 2026-04-30): never `sample_stencil(SCREEN_UV)` from a compute shader; stencil aspect is not sampleable; use the graphics-pipeline stencil-test pattern (finding F5)
- Forbidden (Presentation, Manifest 2026-04-30): never use `STENCIL_MODE_OUTLINE` (world-space) in any production pass
- Forbidden (ADR-0001 Alternative 3): never use three separate `CompositorEffect` resources (one per tier) — the single CompositorEffect with three internal graphics-pipeline passes is the mandated pattern
- Performance Guardrail (ADR-0001 §Performance + ADR-0008 Slot 3): outline pass setup CPU < 0.1 ms; GPU outline pass ≤2.0 ms on Iris Xe at 75% scale; intermediate texture is RGBA16F (no new depth buffer — zero memory overhead beyond the intermediate texture, ~8 MB at 1080p for RGBA16F)

---

## Acceptance Criteria

*From GDD `design/gdd/outline-pipeline.md` §Acceptance Criteria AC-1, AC-2, AC-5 (partial), AC-16, and ADR-0001 §Key Interfaces:*

- [ ] **AC-1**: `src/rendering/outline/outline_compositor_effect.gd` declares `class_name OutlineCompositorEffect extends CompositorEffect`. It is a `Resource` with `_render_callback(effect_callback_type: int, render_data: RenderData)` implemented. The `effect_callback_type` check inside `_render_callback` verifies the call is `POST_OPAQUE` before proceeding. (TR-OUT-005)
- [ ] **AC-2**: In `_render_callback`, three graphics pipelines are created (or cached from `_init`/`_ready`): one per tier T ∈ {1, 2, 3}, each with `RDPipelineDepthStencilState.enable_stencil = true`, `front_op_compare = COMPARE_OP_EQUAL`, `front_op_reference = T`, `front_op_compare_mask = 0xFF`, `front_op_compare_write_mask = 0x00` (stencil read-only in this pass — do not overwrite it). (TR-OUT-002, TR-OUT-009, ADR-0001 §Key Interfaces Stage 1)
- [ ] **AC-3**: Each per-tier pipeline renders a fullscreen triangle using a `stencil_pass.glsl` vertex+fragment shader. The fragment shader writes `vec4(float(tier_marker), 0.0, 0.0, 1.0)` to the RGBA16F intermediate texture (tier_marker = `1.0`, `0.6667`, `0.3333` for T = 1, 2, 3 respectively). Pixels not passing the stencil test write nothing (the intermediate texture retains its cleared value of `vec4(0.0)`). (TR-OUT-002)
- [ ] **AC-4**: An RGBA16F intermediate texture is allocated at `_render_callback` time (or lazily at correct size) matching the current render target dimensions. It is cleared to `vec4(0.0)` before the three stencil-test passes run. The texture is accessible to story 003's Stage 2 compute shader as a `sampler2D` or `image2D` input. (TR-OUT-005, preparation for TR-OUT-006)
- [ ] **AC-5**: The `CompositorEffect` runs `POST_OPAQUE` (after opaque geometry pass, before transparent geometry pass and CanvasLayer UI). This is enforced by setting `effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE` in the `_init` or constructor. (TR-OUT-005, TR-OUT-009, GDD §Detailed Design Rule 8, GDD §Acceptance Criteria AC-19 composition order)
- [ ] **AC-6**: GIVEN stencil values in the scene stencil buffer (placed by materials using `STENCIL_MODE_CUSTOM` per story 001), WHEN the three per-tier passes execute, THEN the intermediate texture contains non-zero values only at pixels where the scene stencil matches one of {1, 2, 3}. Pixels with stencil 0 (Tier 0 / no-outline, including the document-overlay ColorRect) produce `vec4(0.0)` in the intermediate texture. (TR-OUT-002, TR-OUT-009, GDD AC-9 — no outline on dim ColorRect)
- [ ] **AC-7**: The `CompositorEffect` node can be attached to a `Camera3D`'s `Compositor` in the scene editor. Attaching and running the scene does not crash, does not produce Vulkan validation layer errors related to stencil state, and logs no RID-leak warnings during normal scene shutdown (the cleanup leak in the spike was identified as a `_free_all` shutdown-ordering issue, not a correctness concern, but production code should use `_notification(NOTIFICATION_PREDELETE)` cleanup). (ADR-0001 §Key Interfaces + verification-log G2 notes)

---

## Implementation Notes

*Derived from ADR-0001 §Key Interfaces (Stage 1 pipeline), verification-log findings F4, F5, and the spike prototype `prototypes/verification-spike/stencil_compositor_outline.gd`:*

The spike prototype at `prototypes/verification-spike/stencil_compositor_outline.gd` is the validated API reference. It MUST NOT be migrated to production as-is (it uses the naive outline scan algorithm — forbidden by ADR-0001 IG 7). However, the Stage 1 stencil-test pipeline code is transferable as a starting point, rewritten to production standards (static typing, doc comments, DI-friendly structure).

File structure:
```
src/rendering/outline/
├── outline_tier.gd                  (story 001 — already exists)
├── outline_compositor_effect.gd     (this story — Stage 1 + frame for Stage 2)
├── shaders/
│   ├── stencil_pass.glsl            (this story — per-tier stencil-test vertex+fragment)
│   └── outline_jump_flood.glsl      (story 003 — jump-flood compute shader)
```

Pipeline construction pattern (from ADR-0001 §Key Interfaces, post-F5 amendment):
1. Obtain `RenderingDevice rd = RenderingServer.get_rendering_device()` in `_render_callback`.
2. For each tier T ∈ {1, 2, 3}: create `RDPipelineDepthStencilState` with `enable_stencil = true`, `front_op_compare = COMPARE_OP_EQUAL`, `front_op_reference = T`, `front_op_compare_mask = 0xFF`, `front_op_compare_write_mask = 0x00`.
3. Create a framebuffer attaching the intermediate RGBA16F texture as color attachment AND `RenderSceneBuffersRD.get_depth_layer(0)` as the depth-stencil attachment. Do NOT create a new depth buffer — reuse the scene's existing one.
4. Load `stencil_pass.glsl` via `ResourceLoader.load("res://src/rendering/outline/shaders/stencil_pass.glsl")` — returns an `RDShaderFile`; call `.get_spirv()` to get `RDShaderSPIRV`; call `rd.shader_create_from_spirv(spirv)` to get a shader RID.
5. Build a fullscreen-triangle vertex buffer (3 clip-space verts: `vec2(-1,-1), vec2(3,-1), vec2(-1,3)`) — no vertex attributes needed if the vertex shader reconstructs UV from `VERTEX_INDEX`.
6. For each tier pass: submit `rd.draw_list_begin(framebuffer, ...)` → `rd.draw_list_bind_pipeline(pipeline_rid)` → `rd.draw_list_bind_uniform_set(...)` (tier marker push constant) → `rd.draw_list_draw(false, 1)` → `rd.draw_list_end()`.

The `stencil_pass.glsl` fragment shader receives the tier marker as a push constant (or a uniform) and outputs it as the red channel of the intermediate texture.

Pipeline RID management: cache pipeline RIDs in member variables; rebuild only when render target dimensions change (use `RenderSceneBuffersRD.get_internal_size()` to detect resize).

**Cleanup**: in `_notification(NOTIFICATION_PREDELETE)`, explicitly call `rd.free_rid()` on all cached pipeline RIDs, shader RIDs, framebuffer RID, and intermediate texture RID. This prevents the benign-but-noisy leak warning seen in the spike's forced-shutdown scenario.

The `PostProcessStack` autoload (ADR-0007 slot 6) eventually owns the `Compositor` resource that references this `CompositorEffect`. For VS validation, attach the effect directly to the demo Camera3D's `Compositor` in the Plaza scene (story 005). Do NOT wire into PostProcessStack in this story — that is PostProcessStack epic scope.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `OutlineTier.set_tier()` — the material-side stencil write (this story is the reader side)
- Story 003: the jump-flood compute Stage 2 that reads the intermediate tier-mask texture and writes outline pixels; the `outline_jump_flood.glsl` shader is story 003's deliverable
- Story 004: `resolution_scale` uniform wiring into the outline shader; resolution-scale-aware kernel width calculation
- Story 005: Plaza scene placement of tier-tagged meshes; visual sign-off; Slot 1 perf measurement
- PostProcessStack integration: wiring the `OutlineCompositorEffect` into the `PostProcessStack` autoload's `Compositor` chain (PostProcessStack epic)

---

## QA Test Cases

*Integration story — automated test + visual verification required.*

**AC-1 + AC-5 — CompositorEffect type + callback type**
- **Given**: `OutlineCompositorEffect.new()` instance
- **When**: inspecting the resource type and `effect_callback_type`
- **Then**: resource is-a `CompositorEffect`; `effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE`
- **Edge cases**: effect_callback_type set to `POST_TRANSPARENT` → would cause outline to miss the opaque stencil buffer state; test must assert POST_OPAQUE specifically

**AC-2 + AC-3 — Per-tier pipeline builds without error**
- **Given**: an initialized `OutlineCompositorEffect` with a mock `RenderData` stub (or a real minimal scene with stencil-tagged meshes)
- **When**: `_render_callback` is invoked
- **Then**: no GDScript errors, no Vulkan validation layer errors in the console; three pipeline RIDs are non-null after the call
- **Edge cases**: RenderingDevice not available (headless test environment) → `_render_callback` should check `RenderingServer.get_rendering_device() != null` and return early with a `push_warning`; the test asserts the early-return path does not crash

**AC-6 — Intermediate texture tier-mask correctness**
- **Setup**: a 3-mesh Plaza scene: one mesh with `stencil_reference = 1` (Tier HEAVIEST), one with `stencil_reference = 2` (Tier MEDIUM), one with `stencil_reference = 0` (Tier NONE — document overlay stand-in)
- **Verify**: screenshot the intermediate texture after Stage 1 runs (add a `@tool` debug mode to `OutlineCompositorEffect` that saves the intermediate texture to `user://debug_tier_mask.png`)
- **Pass condition**: pixels overlapping Tier 1 mesh show R ≈ 1.0; Tier 2 mesh pixels show R ≈ 0.667; Tier 0 mesh pixels show R = 0.0 (no tier marker). Background (no mesh) also R = 0.0.
- **Evidence path**: `production/qa/evidence/story-002-tier-mask-evidence.md` + intermediate texture screenshot

**AC-7 — No Vulkan validation errors or RID leaks**
- **Setup**: run the Plaza reference scene with `OutlineCompositorEffect` attached to the Camera3D; enable Vulkan validation layer (or use Godot's built-in `--debug-gpu-access-violations`)
- **Verify**: console output contains no `Vulkan error`, no `ERROR: … RID leaked`, no `Invalid parameter` messages during a 60-second run and graceful quit
- **Pass condition**: clean console; `_notification(NOTIFICATION_PREDELETE)` cleanup verified by inserting a `print("OutlineCompositorEffect: freed RIDs")` log line and confirming it appears at scene exit

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/outline_pipeline/outline_compositor_pipeline_test.gd` — integration test OR documented playtest confirming per-tier pipeline initializes without error in a scene context
- `production/qa/evidence/story-002-tier-mask-evidence.md` — intermediate texture debug screenshot confirming tier-mask correctness (AC-6 visual verification)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (OutlineTier class must exist — materials must have stencil_reference set before this pass can read them; also confirms the stencil property names used in `stencil_pass.glsl`)
- Unlocks: Story 003 (jump-flood Stage 2 needs the intermediate tier-mask texture produced by this story's Stage 1); Story 005 (Plaza visual scene depends on both Stage 1 + Stage 2 working together)
