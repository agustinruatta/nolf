# Story 007: Full-stack visual + performance verification (4.6 glow rework + Slot 3 budget)

> **Epic**: Post-Process Stack
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Estimate**: 3-4 hours (M — multi-pass visual verification + performance profiling + evidence documentation)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/post-process-stack.md`
**Requirement**: TR-PP-009
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (FPS Hands Outline Rendering) + ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: ADR-0005 confirmed that the outline pass runs first in the Compositor chain and the sepia dim reads the post-outline buffer (Gate 1 PASS on Vulkan-Linux 2026-04-29). This story verifies the complete post-process chain (outline → sepia dim → resolution-scale composition) composes correctly under Godot 4.6's changed glow order. ADR-0008 Slot 3 allocates 2.5 ms total for the post-process chain on Iris Xe at 0.75 scale (outline 2.0 ms + sepia dim + resolution-scale composite 0.5 ms). ADR-0008 is Proposed — performance gates are advisory until ADR-0008 reaches Accepted, but measurements must be captured and filed in `production/qa/evidence/` now to inform the ADR-0008 Gate 1 measurement pass.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: CRITICAL VERIFICATION — Godot 4.6 changed glow order to process BEFORE tonemapping (VERSION.md HIGH risk, `docs/engine-reference/godot/breaking-changes.md`). With `WorldEnvironment.glow_enabled = false` (enforced by Story 005), glow is disabled and the order change should be inert. However, this must be explicitly verified: confirm that on the production stack, disabling glow in `WorldEnvironment` prevents ANY glow contribution (pre- or post-tonemap) in the rendered frame. Also verify that the `screen_texture` buffer sampled by the sepia dim `CompositorEffect` is the post-tonemap LDR buffer, not an HDR pre-tonemap buffer (Story 002 flagged this as an open question). Additionally verify that the full chain (outline CompositorEffect at index 0 + sepia dim CompositorEffect at index 1 + resolution-scale composition) produces no shader compilation failures, no Z-order glitches, and no visual artifacts on Vulkan-Linux. Vulkan-Windows verification is in scope per EPIC.md Definition of Done (4.6 glow rework + outline compose correctly on Vulkan-Linux + Vulkan-Windows).

**Control Manifest Rules (Presentation)**:
- Required: production outline algorithm is jump-flood (ADR-0001 IG 7 + control manifest §Presentation) — verify outline algorithm is NOT the naive scan from the Sprint 01 prototype
- Required: outline pass uses `STENCIL_MODE_CUSTOM` (not `STENCIL_MODE_OUTLINE`) — control manifest §Forbidden Approaches (outline rendering)
- Required: `CompositorEffect` is the post-process mechanism (not manual viewport chains)
- Forbidden: sepia dim must NOT dim the Document Overlay card (GDD Core Rule 3) — verified via screenshot showing CanvasLayer card at full saturation
- Guardrail: sepia pass ≤0.5 ms at 1080p RTX 2060; full chain ≤2.5 ms on Iris Xe at 0.75 scale (ADR-0008 Slot 3, TR-PP-009) — advisory until ADR-0008 Accepted; measurements filed as evidence regardless

---

## Acceptance Criteria

*From GDD `design/gdd/post-process-stack.md` §Acceptance Criteria AC-15 through AC-20 + EPIC.md Definition of Done:*

- [ ] **AC-1**: GIVEN the plaza stand-in scene running on Vulkan-Linux, WHEN the full post-process chain executes (outline → sepia dim at `dim_intensity = 1.0` → resolution-scale composition), THEN the frame renders without shader compilation errors, without Z-order glitches between the outline and sepia layers, and without visible color space artifacts (no banding, no HDR clipping). Confirmed by screenshot at `production/qa/evidence/`.
- [ ] **AC-2**: GIVEN Godot 4.6's glow-before-tonemapping change, WHEN `WorldEnvironment.glow_enabled = false` (enforced by Story 005) and the post-process chain runs, THEN no glow contribution appears in the rendered frame — no bloom halo around emissive surfaces (plaza street lamps, any emissive material in the stand-in scene). Confirmed by screenshot with explicit emissive material in scene.
- [ ] **AC-3**: GIVEN the sepia dim is ACTIVE (`dim_intensity = 1.0`) and a Document Overlay stub card is rendered on `CanvasLayer` at layer index 20, WHEN the frame renders, THEN the world behind the card appears warm-sepia at ~30% luminance AND the card itself appears at full saturation (no sepia tint on the card content). Confirmed by screenshot.
- [ ] **AC-4**: GIVEN `resolution_scale = 0.75` applied via Story 006, WHEN the plaza stand-in scene renders with outline + sepia dim active, THEN both the outline pass and the sepia dim pass scale correctly (no fixed-pixel artifacts, no misaligned passes, no full-res bleed into the 0.75-scale buffer). Confirmed by screenshot at 1080p output.
- [ ] **AC-5**: GIVEN the sepia dim pass active on RTX 2060 at 1080p native, WHEN the GPU pass timer is profiled, THEN the sepia dim pass alone completes in ≤0.5 ms (target ≤0.3 ms per GDD §Acceptance Criteria AC-18). Measurement filed in `production/qa/evidence/post-process-stack-perf-evidence.md`.
- [ ] **AC-6**: GIVEN `resolution_scale = 0.75` on a device matching Iris Xe profile (or RTX 2060 used as proxy with scaling applied), WHEN the full chain (outline + sepia dim + resolution-scale) runs, THEN total post-process cost is ≤2.5 ms (ADR-0008 Slot 3 cap). Measurement filed in evidence. *Advisory until ADR-0008 Accepted — measurement captured now for ADR-0008 Gate 1 pre-work.*
- [ ] **AC-7**: GIVEN the sepia dim pass is IDLE (`dim_intensity = 0.0`), WHEN profiled, THEN the pass contributes effectively 0 additional ms vs. a frame with only the outline pass active (GDD AC-19 — the pass still executes but its mix() at weight 0.0 is effectively free; the bypass via `_sepia_state == IDLE` from Story 003 should short-circuit before calling the CompositorEffect).
- [ ] **AC-8**: The full chain produces correct results on Vulkan-Windows — same screenshots and performance profile as Vulkan-Linux, confirming platform parity (EPIC.md Definition of Done: Vulkan-Linux + Vulkan-Windows). Evidence filed in `production/qa/evidence/`.

---

## Implementation Notes

*Derived from GDD §Acceptance Criteria §Visual/Audio + EPIC.md Definition of Done + ADR-0008 §Verification Contract:*

This is a verification story — no new production code is written. The work is:

1. **Set up the verification scene**: extend the plaza stand-in scene (or create a dedicated verification scene at `tests/reference_scenes/post_process_stack_verify.tscn`) with:
   - Main `Camera3D` with `Compositor` node holding all 3 CompositorEffects in order
   - At least one emissive surface (a warm light source or a colored emissive material — substitute if Plaza scene not yet authored)
   - A stub `CanvasLayer` at layer 20 with a colored `ColorRect` (simulating the Document Overlay card)
   - `WorldEnvironment` with `glow_enabled = false` and `tonemap_mode = TONE_MAPPER_LINEAR`

2. **Screenshot captures** (per GDD §Visual/Audio reference screenshots):
   - Scene at `dim_intensity = 0.0` (sepia IDLE): confirm outline visible, no glow halos
   - Scene at `dim_intensity = 0.5` (mid-transition): confirm partial sepia
   - Scene at `dim_intensity = 1.0` (sepia ACTIVE): confirm warm sepia at ~30% luminance, CanvasLayer card at full saturation, outline visible but proportionally dimmed
   - All at `resolution_scale = 1.0` AND `resolution_scale = 0.75`

3. **4.6 glow rework check**: With `WorldEnvironment.glow_enabled = false`, take a screenshot of an emissive surface. If no bloom halo is visible, the glow ban is confirmed effective. If any halo appears, escalate: glow may be leaking via a non-WorldEnvironment mechanism (material emission map, Environment override per mesh, etc.) — investigate before shipping.

4. **Buffer type confirmation** (Story 002 open question): Inspect the sepia dim shader output at `dim_intensity = 1.0`. If HDR clipping is visible (extreme bright surfaces becoming pure white then sepia-tinted), the buffer is pre-tonemap. If the output matches the GDD Formula 1 worked example for typical color values, the buffer is post-tonemap. Document finding in the evidence file.

5. **Performance profiling**: Use Godot's built-in profiler (`Project > Tools > Profiler`) or `RenderingServer.get_frame_profile_measurement()` to capture per-pass GPU times. Profile at:
   - 1080p, `resolution_scale = 1.0`, sepia ACTIVE (RTX 2060 target)
   - 1080p, `resolution_scale = 0.75`, sepia ACTIVE (Iris Xe proxy — if Iris Xe not available, note RTX 2060 at 0.75 scale as proxy measurement)
   - 1080p, `resolution_scale = 1.0`, sepia IDLE (confirm ~0 ms contribution)

6. **Vulkan-Windows check**: Run the same verification scene on a Windows machine via Vulkan (not D3D12 — project forces Vulkan on Windows per Amendment A2 in `project.godot`). Same screenshots, same perf profile. File separately in evidence as `post-process-stack-verify-windows-[date].md`.

**Known risk — 4.6 glow rework**: If screenshots show unexpected color shifts in the rendered world under the sepia dim pass (particularly on emissive materials), the cause may be the 4.6 glow-before-tonemap ordering interacting with the HDR buffer. Steps: (a) confirm `WorldEnvironment.glow_enabled = false` is in effect; (b) check if the `CompositorEffect` is sampling the pre-tonemap or post-tonemap buffer; (c) if pre-tonemap, the luminance_mul = 0.30 will cause HDR values > 1.0 to clip to white after multiplication, then be sepia-tinted — this would appear as blown-out white sepia highlights. Escalate to an open question in this story's evidence file if found.

**Shader Baker note**: Before final export, flag `spatial_post_sepia_dim.gdshader` for Shader Baker inclusion (GDD §Edge Cases). This story's scope is the runtime verification; export pipeline setup is a separate concern.

---

## Out of Scope

*Handled by other epics or post-VS:*

- Outline Pipeline epic: production outline algorithm validation (jump-flood cost measurement against TR-OUT-006 2.0 ms budget) — Outline Pipeline's own stories own that evidence
- ADR-0008 Gate 1 (Iris Xe hardware measurement on the Restaurant reference scene): this story captures proxy measurements on available hardware; the full Gate 1 pass requires the Restaurant dense-interior reference scene which is a later Production sprint artifact
- `set_glow_intensity()` and `set_render_scale()` Settings hookup polish (post-VS per EPIC.md)
- Shader Baker export pipeline configuration

---

## QA Test Cases

*Visual/Feel story — manual verification steps:*

**AC-1 + AC-2**: Shader compilation + no glow halos
- Setup: boot the verification scene on Vulkan-Linux; ensure `WorldEnvironment.glow_enabled = false`; place an emissive material in the scene; run with sepia `dim_intensity = 1.0`
- Verify: (a) no shader compilation errors in Godot output log; (b) no Z-order glitch between outline and sepia layers; (c) emissive surface is bright per its albedo but has NO bloom halo around it
- Pass condition: zero errors in output; screenshots show clean sepia dim without artifacts; emissive material visible as intended flat color without halo

**AC-3**: Document Overlay card at full saturation during sepia
- Setup: run verification scene with stub CanvasLayer at layer 20 (colored `ColorRect`); set `dim_intensity = 1.0`
- Verify: the world behind the card is warm-sepia; the `ColorRect` (simulating the card) retains its original full-saturation color
- Pass condition: color-picker on the `ColorRect` in the screenshot shows the same RGB values as when `dim_intensity = 0.0`; world behind shows sepia transformation

**AC-4**: Resolution scale 0.75 — no mis-aligned passes
- Setup: set `resolution_scale = 0.75` via the Story 006 signal; run with sepia active and outline active
- Verify: outline width appears consistent at the scaled resolution; sepia dim covers the full scaled frame; no visible seam or alignment artifact between the 0.75-scale internal buffer and the 1.0-scale output
- Pass condition: screenshots at 0.75 and 1.0 scale show consistent visual quality with expected outline thickness difference

**AC-5 + AC-6 + AC-7**: Performance profiling
- Setup: Godot profiler active; run 30-second capture of the verification scene on RTX 2060 (target hardware)
- Verify: per-pass GPU times captured for: (a) sepia dim pass ACTIVE: ≤0.5 ms; (b) full chain ACTIVE: ≤2.5 ms at 0.75 scale; (c) sepia dim pass IDLE: ~0 ms
- Pass condition: measurements within budget; documented in evidence file with hardware specs, Godot version, resolution, per-pass timings

**AC-8**: Vulkan-Windows platform parity
- Setup: run the same verification scene on Windows with Vulkan backend (`project.godot` forces Vulkan per Amendment A2)
- Verify: screenshots match Vulkan-Linux output within perceptual tolerance; no Windows-specific rendering artifacts; sepia dim correct; glow ban in effect
- Pass condition: lead sign-off on visual parity between Linux and Windows captures

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `production/qa/evidence/post-process-stack-visual-evidence.md` with:
  - Screenshot set: dim_intensity = 0.0, 0.5, 1.0 at resolution_scale = 1.0 and 0.75
  - Screenshot: emissive surface confirming no glow halo (AC-2)
  - Screenshot: CanvasLayer card at full saturation vs. sepia world background (AC-3)
  - Buffer type finding (pre-tonemap vs. post-tonemap from Story 002 open question)
  - 4.6 glow rework confirmation: clean or escalation note
- `production/qa/evidence/post-process-stack-perf-evidence.md` with:
  - Hardware: CPU model, GPU model, OS + Vulkan driver version
  - Per-pass timings (sepia ACTIVE p95, sepia IDLE p95, full chain p95)
  - Resolution: 1080p native + 1080p × 0.75 scale
  - Note: "ADR-0008 Slot 3 advisory gate — measurements filed for ADR-0008 Gate 1 pre-work; gate formally closes when ADR-0008 reaches Accepted and Restaurant reference scene measurements are available"
- `production/qa/evidence/post-process-stack-verify-windows-[date].md` (Vulkan-Windows parity screenshots + lead sign-off)
- Lead sign-off on visual correctness

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-006 (all must be DONE; this story verifies the complete assembled stack)
- Unlocks: EPIC.md Definition of Done (post-process stack VS complete); Document Overlay UI epic can proceed with confidence in the sepia dim API; ADR-0008 Gate 1 measurement pass has pre-work data
