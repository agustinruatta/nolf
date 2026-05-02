# OUT-005 Visual Sign-Off — Plaza Outline Pipeline

**Story**: `production/epics/outline-pipeline/story-005-plaza-per-tier-visual-validation.md`
**Reference scene**: `tests/reference_scenes/outline_pipeline_plaza_demo.tscn`
**Status**: ⏸️ **PENDING USER PLAYTEST** — implementation lands the structural pieces; this doc captures the procedure and the user's eyeball verdict.

---

## Procedure

1. Open the project in Godot 4.6 editor
2. Open `tests/reference_scenes/outline_pipeline_plaza_demo.tscn`
3. Press **F6** (Run Current Scene)
4. Take a screenshot at native 1920×1080 — save to
   `production/qa/evidence/story-005-plaza-outline-annotated.png`
5. Use a pixel ruler (GIMP, Krita, ImageMagick) to measure outline thickness
   at each tier's silhouette
6. Sample outline color at each tier (color picker)
7. Repeat with `resolution_scale = 0.75` — Run scene again, then in the
   Remote Inspector set `OutlineCompositorEffect.resolution_scale = 0.75` and
   capture a second screenshot

---

## AC-2 — Per-tier thickness at native 1080p

Expected: Tier 1 = 4 ± 0.5 px · Tier 2 = 2.5 ± 0.5 px · Tier 3 = 1.5 ± 0.5 px

| Tier | Mesh | Expected (px) | Measured (px) | Pass / Fail |
|------|------|--------------|---------------|-------------|
| 1 (HEAVIEST) | DocumentStandIn | 4 ± 0.5 | _____ | ⏳ |
| 1 (HEAVIEST) | SignageStandIn | 4 ± 0.5 | _____ | ⏳ |
| 2 (MEDIUM) | GuardStandIn | 2.5 ± 0.5 | _____ | ⏳ |
| 3 (LIGHT) | GroundPlane | 1.5 ± 0.5 | _____ | ⏳ |
| 0 (NONE) | DocumentDimRect | 0 (no outline) | _____ | ⏳ |

---

## AC-3 — Outline color uniformity

Expected: all tiers sample to (26, 26, 26) ± 2 sRGB.

| Tier | Sample location | Expected RGB | Measured RGB | Pass / Fail |
|------|-----------------|--------------|--------------|-------------|
| 1 | DocumentStandIn edge | (26, 26, 26) ± 2 | _____ | ⏳ |
| 2 | GuardStandIn edge | (26, 26, 26) ± 2 | _____ | ⏳ |
| 3 | GroundPlane horizon | (26, 26, 26) ± 2 | _____ | ⏳ |

---

## AC-4 — Geometry-free direction

Expected: rotate camera to face away from all geometry → no outlines.

- [ ] Confirmed clean framebuffer with zero outline pixels: ⏳

---

## AC-5 — Lighting invariance

Expected: outline thickness + color identical between bright + dark ambient.

- [ ] Bright ambient screenshot captured: ⏳
- [ ] Dark ambient screenshot captured: ⏳
- [ ] Side-by-side comparison shows identical outline: ⏳

---

## AC-6 — SubViewport composition non-interference

Expected: world outline is visible behind the (transparent) hands SubViewport;
no stencil corruption at the SubViewport overlap region.

- [ ] No stencil corruption visible at HandsSubViewport overlap: ⏳

---

## AC-9 — Visual sign-off

- [ ] Annotated screenshot saved at `production/qa/evidence/story-005-plaza-outline-annotated.png`
- [ ] User confirms production code matches the Sprint 01 prototype visual output (`prototypes/verification-spike/fps_hands_demo.tscn` baseline)

**Sign-off**: ⏳ pending user playtest

---

## Implementation status (2026-05-01 — Sprint 03 close-out)

- ✅ **OUT-003 jump-flood GPU dispatch LANDED**: full `RenderingDevice.compute_list_*`
  command stream implemented in `outline_compositor_effect.gd::_dispatch_jump_flood_pass`.
  Set 0 (tier-mask + scene color) + Set 1 (ping-pong seed buffers) + 48-byte
  std430 push constant + `compute_list_add_barrier` between passes. Earlier
  STUB caveat is RESOLVED.
- ✅ **OutlineCompositorEffect wired to Main.tscn**: `src/core/main.gd::_attach_outline_compositor`
  attaches `OutlineCompositorEffect` via `Compositor` resource on the player
  Camera3D after spawn. The actual VS Plaza demo (F5 → run) now drives the
  full Stage 1 + Stage 2 pipeline — same script path as production wiring
  through `PostProcessStack` (deferred to PostProcessStack epic).
- ✅ **Plaza CSG geometry stencil-tagged**: `src/core/main.gd::_apply_plaza_outline_tiers`
  walks the plaza tree and sets `stencil_mode = 3 / flags = 2 / compare = 0 /
  reference = T` on each CSG material at runtime. Walls + floor + pillar =
  Tier 3 LIGHT (1.5 px); the three crates = Tier 1 HEAVIEST (4 px) so the
  demo visibly shows tier variation.
- The reference scene at `tests/reference_scenes/outline_pipeline_plaza_demo.tscn`
  also has materials with stencil values baked in directly (independent of
  the runtime tagging path).
- The `HandsSubViewport` is empty (no mesh) in the reference scene — purpose
  is to verify the composition framebuffer does NOT corrupt the world stencil.
  The actual hands rendering lives in `PlayerCharacter.tscn` (PC-008).
