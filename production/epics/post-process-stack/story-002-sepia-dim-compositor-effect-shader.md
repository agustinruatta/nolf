# Story 002: Sepia dim CompositorEffect shader + Compositor wiring

> **Epic**: Post-Process Stack
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: 3-4 hours (M — shader file + CompositorEffect GDScript wrapper + Compositor node scene wiring + visual evidence)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/post-process-stack.md`
**Requirement**: TR-PP-003
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (FPS Hands Outline Rendering) + ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: ADR-0005 established the CompositorEffect chain ordering: the outline pass (Outline Pipeline epic) runs first in the chain inside the main camera's Compositor; the sepia dim pass runs second, reading the post-outline color buffer. The sepia dim `CompositorEffect` must NOT modify the depth/stencil buffer (GDD §Interactions — it reads the post-outline color buffer only). ADR-0008 Slot 3 allocates 2.5 ms total for the full post-process chain (outline 2.0 ms + sepia dim + resolution-scale composite 0.5 ms combined); the sepia pass alone targets ≤0.5 ms at 1080p on RTX 2060 (TR-PP-009).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `CompositorEffect` (4.3+) is stable for screen-texture sampling. The sepia dim shader samples `screen_texture` (via `uniform sampler2D screen_texture : hint_screen_texture`) — this hint is stable 4.3+. CRITICAL: Godot 4.6 changed glow to process BEFORE tonemapping (VERSION.md HIGH risk flag). The sepia dim pass runs on the post-outline color buffer after tonemapping has already been applied; verify that the `screen_texture` sampled by the sepia dim `CompositorEffect` is the post-tonemap buffer (not the pre-tonemap HDR buffer). This must be confirmed during visual verification (Story 007) — if the buffer is pre-tonemap, the dim will apply to HDR values and produce clipping artifacts. The `hint_screen_texture` convention in `canvas_item` shaders provides the LDR post-tonemap buffer; the equivalent for a `CompositorEffect` compute/fragment shader may differ — check `docs/engine-reference/godot/modules/rendering.md` before assuming. Shader texture uniform type changed from `Texture2D` to `Texture` in Godot 4.4 (control manifest §Forbidden APIs) — use `Texture` base type in any GDScript-side uniform references.

**Control Manifest Rules (Presentation)**:
- Required: `CompositorEffect` is the mandated mechanism for post-process passes (not manual viewport chains) — control manifest §Forbidden APIs row "Manual post-process viewport chains"
- Required: sepia dim pass must run SECOND in the chain (after outline, before resolution-scale composition) per TR-PP-001 and GDD Core Rule 1
- Forbidden: sepia dim shader must NOT modify depth or stencil buffer (GDD §Interactions — outline stencil must be intact for Outline Pipeline)
- Forbidden: `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` — not relevant here but the rule applies to all rendering work (ADR-0001)
- Guardrail: sepia pass ≤0.5 ms at 1080p RTX 2060; full chain (outline + sepia + resolution-scale) ≤2.5 ms on Iris Xe at 0.75 scale (ADR-0008 Slot 3, TR-PP-009) — advisory until ADR-0008 Accepted

---

## Acceptance Criteria

*From GDD `design/gdd/post-process-stack.md` §Detailed Design Core Rules + §Visual/Audio + Formulas 1 and 3:*

- [ ] **AC-1**: `assets/shaders/post_process/spatial_post_sepia_dim.gdshader` exists and declares uniforms: `dim_intensity : hint_range(0.0, 1.0) = 0.0`, `luminance_mul = 0.30`, `saturation_mul = 0.25`, `sepia_tint : source_color = vec4(1.10, 1.00, 0.75, 1.0)`. Shader implements Formula 1 (GDD §Formulas): desaturate → sepia tint → luminance multiply → `mix(original, result, dim_intensity)`. When `dim_intensity = 0.0`, output is pixel-identical to input.
- [ ] **AC-2**: `src/foundation/post_process/sepia_dim_effect.gd` declares `class_name SepiaDimEffect extends CompositorEffect` with a `set_dim_intensity(value: float) -> void` method that updates the shader uniform on the internal shader material. The shader resource path `assets/shaders/post_process/spatial_post_sepia_dim.gdshader` is wired as the effect's shader.
- [ ] **AC-3**: GIVEN `dim_intensity = 0.0`, WHEN the sepia dim effect renders, THEN the output frame is visually identical to the input (no color shift, no luminance reduction). Confirmed by screenshot comparison at `production/qa/evidence/`.
- [ ] **AC-4**: GIVEN `dim_intensity = 1.0`, WHEN the sepia dim effect renders on the Restaurant section stand-in scene, THEN the frame appears warm-sepia at approximately 30% luminance. No banding, no HDR clipping, no color anomalies. Confirmed by screenshot at `production/qa/evidence/`.
- [ ] **AC-5**: The `CompositorEffect` is mounted on the active `Camera3D`'s `Compositor` node, positioned AFTER the outline pass and BEFORE the resolution-scale composition step (GDD Core Rule 1 + ADR-0005 chain ordering). The ordering is confirmed by the `PostProcessStack.CHAIN_ORDER` constant from Story 001 matching the registered effect order.
- [ ] **AC-6**: GIVEN `dim_intensity = 0.0` (effect inactive), WHEN the GPU timer for the sepia dim pass is sampled, THEN the pass contributes effectively 0 additional ms vs. a frame without the effect mounted (the pass still executes but its `mix()` at weight 0.0 produces a no-op — acceptable; full bypass via Story 003's state machine is Story 003's scope).

---

## Implementation Notes

*Derived from GDD §Visual/Audio + §Formulas 1 and 3 + ADR-0005 §Architecture + ADR-0008 Slot 3:*

**Shader file** (`assets/shaders/post_process/spatial_post_sepia_dim.gdshader`):

This is a `CompositorEffect` shader — it samples the full-screen color buffer and writes the transformed result. The desaturation formula from GDD Formula 1:

```
gray = dot(c, vec3(0.299, 0.587, 0.114))
c_desaturated = mix(vec3(gray), c, saturation_mul)
c_tinted = c_desaturated * sepia_tint.rgb
c_dimmed = c_tinted * luminance_mul
output = mix(c, c_dimmed, dim_intensity)
```

All three operations (desaturate, tint, luminance reduce) are applied in one pass before the `mix()`. This is the correct order per GDD Formula 1 (`apply_sepia_dim(c) = luminance_mul * sepia_tint * desaturate(c)`).

**CompositorEffect wrapper** (`src/foundation/post_process/sepia_dim_effect.gd`):

- Extends `CompositorEffect`
- Holds a reference to the shader material
- Exposes `set_dim_intensity(value: float)` — called by Story 003's tween
- The `_render_callback(effect_callback_type, render_data)` method executes the screen-space pass; consult `docs/engine-reference/godot/modules/rendering.md` for the current Godot 4.6 `CompositorEffect` callback signature before implementing

**Buffer access note**: Verify that the screen texture accessed via `hint_screen_texture` in a `CompositorEffect` shader represents the post-tonemapping LDR buffer, not the HDR pre-tonemap buffer. If it is pre-tonemap, HDR values > 1.0 will cause visible clipping after the luminance_mul * 0.30 reduction. The GDD assumption (and the visual target) is post-tonemap. If the buffer is pre-tonemap, raise this as an open question before shipping this story.

**Compositor chain position**: The sepia dim `CompositorEffect` resource is assigned to `CompositorEffect` slot index 1 (0-indexed: outline = 0, sepia_dim = 1, resolution_scale = 2). This matches `PostProcessStack.CHAIN_ORDER[1]` from Story 001. The `Compositor.compositor_effects` Array property governs order.

**Naming**: shader file follows project convention `[type]_[category]_[name].gdshader` → `spatial_post_sepia_dim.gdshader`. The pass is screen-space (a 2D operation on the 3D render output), but `CompositorEffect` shaders don't use `shader_type canvas_item` — they use a compute/fragment approach. Name the file to indicate its role in the 3D pipeline.

**Shader Baker (Godot 4.5+)**: The sepia dim shader is used on every document pickup; first-use compile stutter would be visible. Flag this shader for Shader Baker inclusion in the export configuration (GDD Edge Cases + ADR-0005 Consequences). This is an implementation note for the export pipeline — not a blocking gate for VS.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: PostProcessStack autoload class declaration and CHAIN_ORDER constant
- Story 003: Tween state machine that calls `set_dim_intensity()` over time (0.5 s ease-in/out)
- Story 004: Document Overlay calling `enable_sepia_dim()` / `disable_sepia_dim()` via the public API
- Story 007: Full-stack performance measurement and 4.6 glow rework composition verification

---

## QA Test Cases

*Visual/Feel story — manual verification steps:*

**AC-3**: Sepia dim at dim_intensity = 0.0 is transparent
- Setup: boot the plaza stand-in scene (or any scene with the CompositorEffect mounted); set `dim_intensity = 0.0` via shader parameter; take a screenshot
- Verify: the screenshot is visually identical to a reference screenshot taken with the CompositorEffect disabled entirely; no tint, no luminance shift, no color fringing
- Pass condition: no visible difference between the two screenshots when overlaid at 50% opacity in any image editor

**AC-4**: Sepia dim at dim_intensity = 1.0 matches GDD Formula 1 target
- Setup: boot the plaza stand-in scene; set `dim_intensity = 1.0`; take a screenshot
- Verify: (a) scene appears warm-sepia with visibly reduced brightness (~30% of original); (b) a color-picker on a known warm-amber surface (e.g., a warm light source) shows the sepia-tinted, low-luminance value consistent with GDD Formula 1 worked example (approx `(0.207, 0.165, 0.113)` for the amber input sample); (c) no banding or HDR clipping artifacts visible; (d) outlines from the outline pass are visible in the sepia frame (dimmed proportionally — intended per GDD Core Rule 3)
- Pass condition: visual match to GDD §Visual/Audio reference screenshots; no artifacts; color direction warm/sepia/dim confirmed by lead sign-off

**AC-5**: Chain position verification
- Setup: inspect the `Compositor.compositor_effects` Array on the active Camera3D in the running scene
- Verify: effect at index 0 is the outline `CompositorEffect` (Outline Pipeline); effect at index 1 is `SepiaDimEffect`; effect at index 2 is the resolution-scale step
- Pass condition: array length == 3; index 1 is `SepiaDimEffect` type; indices match `PostProcessStack.CHAIN_ORDER`

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/sepia-dim-shader-evidence.md` with:
  - Screenshot: plaza scene at `dim_intensity = 0.0` (must show no visual change vs. no effect)
  - Screenshot: plaza scene at `dim_intensity = 1.0` (must show warm sepia at ~30% luminance)
  - Screenshot: plaza scene at `dim_intensity = 0.5` (mid-transition reference)
  - Confirmation that no HDR clipping or banding is visible
  - Lead sign-off
- `production/qa/evidence/sepia-dim-shader-evidence.md` also records the buffer type finding (pre-tonemap vs. post-tonemap) for the Story 007 verification chain

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PostProcessStack autoload scaffold must be DONE; CHAIN_ORDER constant defines slot index 1)
- Unlocks: Story 003 (tween state machine calls `set_dim_intensity()` on the SepiaDimEffect), Story 007 (performance verification builds on the production shader)
