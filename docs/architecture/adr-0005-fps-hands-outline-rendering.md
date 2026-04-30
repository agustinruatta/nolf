# ADR-0005: FPS Hands Outline Rendering (Inverted-Hull Exception)

## Status

**Proposed** — moves to Accepted once the remaining verification gates pass. **Gate 1 ✅ PASS** (2026-04-29 Sprint 01 spike — `prototypes/verification-spike/fps_hands_demo.tscn`): inverted-hull capsule renders correct outline on Linux Vulkan; thickness tuning is a production concern, not a gate. **Gate 2 ✅ CLOSED BY REMOVAL** (2026-04-30 Amendment A6): D3D12 is no longer a target backend per ADR-0001 Amendment A2 + `project.godot [rendering] rendering_device/driver.windows="vulkan"`; cross-platform parity collapses to single-Vulkan verification. **Gates 3, 4, 5 still pending** — production scope (resolution-scale toggle behavior, animated rigged hand mesh, Shader Baker × `material_overlay`) requires the actual hands rendering production story.

## Date

2026-04-19

## Last Verified

2026-04-30 (Amendment A6: Gate 2 — D3D12/Windows parity — closed by removal per project decision to force Vulkan on Windows. Gate 1 also closed via Sprint 01 spike `prototypes/verification-spike/fps_hands_demo.tscn`. Status stays Proposed pending Gates 3, 4, 5 — production-scope. Earlier: 2026-04-23 Amendment A5 added Gate 5 Shader Baker × `material_overlay` compatibility verification.)

## Decision Makers

User (project owner) · godot-shader-specialist (technical validation) · `/architecture-decision` skill (via Session B of `/design-system player-character` revision)

## Summary

First-person player hands in *The Paris Affair* cannot participate in ADR-0001's stencil-based outline system because the standard Godot FPS-hands pattern renders inside a `SubViewport` (to isolate FOV 55° from world FOV 75° and prevent clipping through geometry), and the GPU stencil plane is per-framebuffer — SubViewport stencil writes never reach the main camera's outline `CompositorEffect`. A dual-camera shared-framebuffer workaround is not buildable in pure GDScript in Godot 4.6 (no API to run two camera projections into one framebuffer without a SubViewport). **Hands are therefore the project's single explicit exception to ADR-0001: they achieve the heaviest outline tier via an inverted-hull shader technique applied to the hands material itself, inside the hands `SubViewport`.** Every other mesh class in the game continues to use ADR-0001 stencil tiers.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering |
| **Knowledge Risk** | LOW — Inverted-hull outlining via front-face-culled extruded mesh is a stable Godot 3.x+ technique; `SubViewport` compositing is stable 4.0+. No post-cutoff APIs are load-bearing. SubViewport compositing ordering with the main camera's outline `CompositorEffect` from ADR-0001 verified on Vulkan via Sprint 01 spike. (Was LOW-MEDIUM pre-2026-04-30 due to D3D12 cross-platform unknown; D3D12 no longer targeted per Amendment A6.) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/rendering.md`, ADR-0001, godot-shader-specialist technical memo (2026-04-19) |
| **Post-Cutoff APIs Used** | None as load-bearing dependencies. Shader Baker (4.5) will compile the inverted-hull shader; this is an optimization, not a correctness requirement. |
| **Verification Required** | (1) Editor prototype: hands stand-in mesh in SubViewport with inverted-hull material; visual match to adjacent stencil-based outlined world object on **Vulkan/Linux**. **CLOSED 2026-04-29** via `prototypes/verification-spike/fps_hands_demo.tscn`. (2) ~~Same prototype on **D3D12/Windows** — identical visual output.~~ **CLOSED BY REMOVAL 2026-04-30 (Amendment A6)** — D3D12 not targeted; Vulkan-only on both Linux and Windows. (3) Confirm outline width scales correctly when `resolution_scale` switches from 1.0 → 0.75 (Iris Xe branch). Production scope. |

> **Note**: LOW-MEDIUM Knowledge Risk. The inverted-hull pattern predates the LLM's knowledge cutoff and is well-documented in community tutorials; no breaking changes in 4.4–4.6 affect this approach.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001** (Stencil ID Contract) — explicit coexistence. Hands are the single mesh class excepted from ADR-0001's stencil mechanism. ADR-0005 MUST cite and honor ADR-0001's visual target (tier-HEAVIEST, 4 px at 1080p, `#1A1A1A` outline color) even though it implements that target via a different technique. |
| **Enables** | Player Character GDD AC-11.1 (hands visibly outlined) without requiring GDExtension work. |
| **Blocks** | None. Does not block any other ADR or GDD. |
| **Ordering Note** | Sibling-level to ADR-0001/0002/0003/0004. ADR-0005 was drafted during Session B of the Player Character GDD revision cycle (2026-04-19). |

## Context

### Problem Statement

The Player Character GDD specifies first-person hands rendered at FOV 55° (narrower than world FOV 75°) to prevent "stretched gorilla arms" at wide FOV — a standard convention for FPS hands. The GDD further specifies hands carry the heaviest outline tier per ADR-0001 (tier HEAVIEST, 4 px at 1080p) to visually anchor Eve's presence in the first-person view.

These two requirements conflict:

- **FPS hands pattern**: render hands in a `SubViewport` with its own camera at FOV 55°; composite the SubViewport onto the main view. This is the canonical Godot approach for different-FOV FPS hands and also solves the problem of hands clipping through world geometry.
- **ADR-0001 stencil contract**: every outlined object writes a stencil value (0/1/2/3) to the main framebuffer's stencil plane during the opaque pass. The outline `CompositorEffect` reads that stencil per-pixel and selects kernel width per tier.

The GPU stencil plane is **per-framebuffer**. A mesh rendered into a `SubViewport` writes stencil into the SubViewport's framebuffer, not the main camera's. The outline `CompositorEffect` runs on the main camera and has no way to see the SubViewport's stencil plane.

The obvious workaround — render hands via a second `Camera3D` that shares the main camera's framebuffer (no SubViewport) — was investigated by godot-shader-specialist and is **not buildable in pure GDScript in Godot 4.6**. Only one `Camera3D` is "current" per `Viewport` at a time; there is no documented GDScript API to run two camera projections (different FOV, different cull mask) into the same framebuffer without a SubViewport. A workable dual-camera solution would require GDExtension (`RenderingDevice` direct manipulation), which is out of scope for a first-time solo Godot dev on a 6–9 month MVP timeline.

Without a decision here, the Player Character GDD's AC-11.1 (hands have visible outline) cannot be implemented and the review-flagged conflict (B-10) blocks the GDD from moving past revision.

### Current State

- ADR-0001 (Stencil ID Contract) is Proposed. Implementation has not started.
- Player Character GDD is mid-revision (Session B of 4). Section I (Visual/Audio) currently says hands "Rendered on a dedicated viewport layer" and calls `OutlineTier.set_tier(hands_mesh, HEAVIEST)` on `_ready()` — both are now incorrect given this ADR.
- No hands mesh or material exists yet.
- The outline `CompositorEffect` shader has not been written.

### Constraints

- **Engine: Godot 4.6, Forward+ renderer, GDScript primary.** No GDExtension in the project. Any solution requiring direct `RenderingServer` / `RenderingDevice` work is out of scope.
- **Visual target: tier-HEAVIEST match.** Hands must visually match ADR-0001 tier 1 (4 px outline at 1080p native, `#1A1A1A` near-black color) within perceptual tolerance. A close-range observer should not be able to tell that hands use a different outline technique than adjacent world objects.
- **Performance: outline pass ≤2 ms total per Art Bible 8F.** The hands outline budget must fit within that or claim a small dedicated slice. Target: ≤0.3 ms for hands outline on Iris Xe (16% of the shared 2 ms budget — reasonable since hands are low-poly and on-screen always).
- **Cross-platform: Linux + Windows, both on Vulkan.** Project decision (ADR-0001 Amendment A2 + `project.godot [rendering]`) forces Vulkan on Windows; D3D12 no longer targeted. Single-backend verification surface.
- **Resolution scale: must honor ADR-0001's 75% Iris Xe fallback.** Hands outline scales with the rest of the world when `resolution_scale = 0.75`.
- **Single mesh class exception.** This ADR defines the hands as the only exception to ADR-0001's stencil contract. No other mesh class may adopt the inverted-hull approach without a new ADR or an amendment here.
- **Animated mesh.** Hands will be rigged and animated (idle sway, interact reach, gadget poses). The outline technique must survive skeletal deformation without breaking at joint normals.

### Requirements

- Hands render at FOV 55° without clipping through world geometry.
- Hands have a visible ~4-pixel outline at 1080p native, color `#1A1A1A`, on both backends.
- Hands outline survives skeletal animation without visible artifacts at finger joints or wrist.
- Hands outline width scales proportionally when the project-wide `resolution_scale` drops to 0.75 for integrated graphics.
- The technique does not require GDExtension, `RenderingDevice` direct access, or any post-cutoff API as a load-bearing element.
- The outline `CompositorEffect` from ADR-0001 continues to work unchanged for every other mesh class — this ADR does not modify ADR-0001's shader, stencil values, or tier assignment rules.

## Decision

**Render FPS hands inside a `SubViewport` at FOV 55° (standard FPS-hands pattern, preserved). Apply a custom `HandsOutlineMaterial` to the hands mesh with two passes: (1) a front-face-culled, vertex-extruded inverted-hull pass that outputs a flat outline color, and (2) the standard PBR-ish fill pass. The outline is baked into the SubViewport before compositing onto the main view. Hands do NOT call `OutlineTier.set_tier` and do NOT write stencil values. ADR-0001's stencil contract governs every other mesh class unchanged.**

### Architecture

```
                       ┌────────────────────────────────┐
                       │  Main Camera (FOV 75)          │
                       │  Renders world geometry to the │
                       │  main framebuffer.             │
                       │  World meshes write stencil 1/2/3 │
                       │  per ADR-0001.                 │
                       └──────────────┬─────────────────┘
                                      │ ADR-0001 outline
                                      │ CompositorEffect reads
                                      │ stencil, applies Sobel
                                      │ outline per tier.
                                      ▼
              ┌─────────────────────────────────────────────────┐
              │  Main framebuffer: color + depth + stencil +    │
              │  WORLD OUTLINE baked in.                        │
              └────────────────────────┬────────────────────────┘
                                       │
                                       ▼
                       ┌────────────────────────────────┐
                       │  Hands SubViewport (FOV 55)    │
                       │  Separate framebuffer.         │
                       │  Hands mesh uses               │
                       │  HandsOutlineMaterial (2 pass):│
                       │    Pass 1 (inverted hull):     │
                       │      - front-face culled       │
                       │      - verts extruded along    │
                       │        normal by outline_width │
                       │      - outputs outline color   │
                       │    Pass 2 (fill):              │
                       │      - standard back-face cull │
                       │      - PBR-ish shading         │
                       │  → SubViewport framebuffer has │
                       │    hands + hands outline baked │
                       │    in (no stencil needed).     │
                       └──────────────┬─────────────────┘
                                      │ composited over
                                      │ main framebuffer via
                                      │ CanvasLayer (top layer)
                                      ▼
                            FINAL FRAME OUTPUT
```

### Key Interfaces

```gdscript
# res://src/gameplay/player/hands_outline_material.gdshader
# Shader on the hands mesh; two passes via render_mode and pass setup.

shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.102, 0.102, 0.102, 1.0);
// outline_world_width is the extrusion distance in local mesh units.
// Tuned to ~4 px visual thickness at 1080p native at typical hand-to-camera distance.
uniform float outline_world_width : hint_range(0.001, 0.02) = 0.006;
uniform float resolution_scale = 1.0;  // wired from Settings & Accessibility; 1.0 default, 0.75 on Iris Xe

void vertex() {
    // Extrude along normal in local space by outline_world_width * resolution_scale.
    VERTEX += NORMAL * outline_world_width * resolution_scale;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
```

```gdscript
# Pass 2 (fill) is a separate ShaderMaterial on a second surface or
# a second ShaderMaterial pass via MeshInstance3D.material_overlay /
# surface_override_material slots. Exact mechanism decided during
# implementation (both options work; material_overlay is simpler but
# does not support per-material Shader Baker compilation — tradeoff
# documented in the Implementation Guidelines below).
```

```gdscript
# res://src/gameplay/player/player_character.gd — _ready snippet
# Hands do NOT call OutlineTier.set_tier — they use ADR-0005, not ADR-0001 stencil.

func _ready() -> void:
    # ... other setup ...
    # NOTE: hands outline is owned by HandsOutlineMaterial per ADR-0005.
    # Do NOT call OutlineTier.set_tier on hands_mesh.

    var hands_material := preload("res://src/gameplay/player/hands_outline_material.tres")
    var settings_scale: float = Settings.get_resolution_scale()  # returns 1.0 or 0.75
    hands_material.set_shader_parameter("resolution_scale", settings_scale)
    # material_overlay, NOT material_override: overlay preserves the mesh's per-surface
    # PBR materials for the fill pass while adding the outline pass on top.
    # material_override would clobber the fill materials. Corrected 2026-04-21 —
    # PC GDD AC-9.1 and ADR-0005 are now aligned on this choice.
    $HandsRig/HandsMesh.material_overlay = hands_material

    # Subscribe to resolution-scale changes (same signal ADR-0001 uses).
    Events.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category == &"graphics" and name == &"resolution_scale":
        $HandsRig/HandsMesh.material_overlay.set_shader_parameter(
            "resolution_scale", float(value)
        )
```

### Implementation Guidelines

1. **Hands are the ONLY mesh class excepted from ADR-0001.** Do NOT extend the inverted-hull technique to any other mesh in the project without a new ADR. Adding a second exception widens the surface area for outline-width drift (hull extrusion and Sobel edge detect will never be pixel-identical).
2. **Outline color MUST match ADR-0001's uniform (`#1A1A1A`).** If ADR-0001 changes the outline color, this ADR's `outline_color` uniform default MUST be updated in the same PR. The color is defined in Art Bible Section 4.4 — both ADRs are downstream consumers.
3. **`outline_world_width` is the hands' single tuning knob.** Starting value: 0.006 local-space units. This number was chosen to produce ~4 px visual width at 1080p native when the hand mesh is at its typical camera distance (0.5–0.8 m). The value is perceptually validated, not math-derived; if the hand mesh scale changes significantly, re-tune.
4. **`resolution_scale` uniform is MANDATORY.** It must be wired to the same `Settings.get_resolution_scale()` source that ADR-0001's outline `CompositorEffect` reads. When resolution drops to 75%, both outlines scale proportionally. Without this wiring, the hands outline stays 4 px while the world outline drops to 3 px at 75% scale — visible divergence.
5. **Vertex normal authoring.** Hands mesh MUST have smoothed vertex normals across finger joints and the wrist. Sharp normal breaks (auto-generated hard edges) will produce visible inverted-hull gaps or spikes under animation. The hands mesh specification in the `/asset-spec` run for the Player Character system will include this as a hard authoring rule.
6. **Animated extrusion.** The inverted hull is computed in the vertex shader AFTER skeletal deformation (Godot's skeleton animation runs before user `vertex()` code). No special handling needed — standard Godot spatial shader pipeline. Verify during prototype.
7. **Shader Baker.** Compile `hands_outline_material.gdshader` via Shader Baker at export time to eliminate runtime shader compilation on first frame. The `material_overlay` slot supports baked shaders as of 4.5. If `material_overlay` is NOT used (two-surface approach instead), same applies to the per-surface ShaderMaterial.
8. **Z-fighting prevention.** The inverted-hull pass uses `depth_draw_always` and `cull_front`; the fill pass uses standard depth-test and `cull_back`. Render order inside the SubViewport follows material `render_priority`: outline material gets `render_priority = -1` (drawn before fill), fill material gets `render_priority = 0`. This prevents the fill from occluding its own outline at silhouette edges.
9. **SubViewport update mode.** Set the hands SubViewport `update_mode = UPDATE_ALWAYS`. Hands must render every frame even when paused (pause menu shows hands in idle pose for document overlays per PC GDD Section E.5).
10. **SubViewport transparent clear.** Set `SubViewport.transparent_bg = true` so the composite onto the main view preserves world outline visible behind gaps in the hands mesh (e.g., between fingers).
11. **Compositing.** The hands SubViewport is attached to a `SubViewportContainer` under a `CanvasLayer` with `layer = 10` (above HUD at 8–9, below document overlay at 20 — to be formalized in the Control Manifest). The CanvasLayer renders over the main 3D scene after ADR-0001's outline `CompositorEffect` completes. This ensures the world's outline is already baked in before hands are composited on top.

## Alternatives Considered

### Alternative 1: Dual-camera shared framebuffer (cull-mask + second Camera3D)

- **Description**: Place the hands mesh on a dedicated visual layer (e.g., layer 11). Main camera cull-masks it out. A child `Camera3D` with FOV 55° and a cull-mask including only layer 11 renders hands into the SAME framebuffer as the main camera. Hands write stencil normally, the main outline `CompositorEffect` sees their stencil, AC-11.1 holds without exception.
- **Pros**: Conceptually clean — hands would be a normal outlined mesh; no per-mesh exception; no width-drift between techniques. If buildable, it would be the preferred approach.
- **Cons**: **Not buildable in pure GDScript in Godot 4.6.** Only one `Camera3D` is current per `Viewport` at a time. There is no documented GDScript API to run two camera projections into the same framebuffer without a SubViewport. Implementing this would require GDExtension with direct `RenderingDevice` access — schedule a second scene draw with a different projection matrix into the main framebuffer between the main camera pass and the outline `CompositorEffect`. That is an engineering investment (GDExtension setup, C++ build pipeline, cross-platform compilation) of 2–4 weeks minimum, out of scope for the 6–9 month MVP.
- **Estimated Effort**: 5–10× the chosen approach (GDExtension learning curve + native code + cross-platform verification).
- **Rejection Reason**: Out of scope for a first-time solo Godot dev within the MVP timeline. Listed here as the approach to revisit if the project ever needs per-pixel outline parity on hands (e.g., if playtest reveals the inverted-hull technique produces visibly different silhouettes).

### Alternative 2: No outline on hands

- **Description**: Accept that hands are the one on-screen asset without a black outline. Remove AC-11.1 from the Player Character GDD; remove the `OutlineTier.set_tier(hands_mesh, HEAVIEST)` call.
- **Pros**: Zero implementation cost. Zero engine risk. Zero cross-platform verification.
- **Cons**: Hands are the most player-visible asset in a first-person game. The rest of the world has a black outline; hands would not. This either reads as "hands are a ghost / belong to a different game" or requires the player to adjust their visual model of the game. Art Bible Section 1 Principle 2 (Silhouette Owns Readability) depends on consistent outline application across all foreground objects. This alternative violates the visual identity pillar for a system that has a lower-cost workaround (Option C, chosen).
- **Estimated Effort**: Negligible.
- **Rejection Reason**: Visual identity risk is too high given that Option C is implementable today with known Godot patterns. Listed here as the documented fallback if both verification gates of this ADR fail.

### Alternative 3: Screen-space post-process outline inside the hands SubViewport

- **Description**: Write a second `CompositorEffect` (or a post-process quad) that lives inside the hands SubViewport and applies a Sobel edge-detect outline to whatever is rendered there. This would give hands a true screen-space outline (Sobel character matching ADR-0001's outline algorithm).
- **Pros**: Visually closer to ADR-0001's Sobel output than inverted hull (which is a hull extrusion, not an edge-detect).
- **Cons**: Duplicates the outline `CompositorEffect` shader logic in a second location. Requires the ADR-0001 shader to be generalized to run on a SubViewport with potentially different kernel tuning. Adds a second full-screen pass inside the SubViewport (cost: ~0.3–0.5 ms on Iris Xe at hand-SubViewport resolution, which is smaller than full screen but still non-trivial). More maintenance burden: any change to the outline algorithm has to be replicated. And the SubViewport's stencil is still isolated — without stencil, the SubViewport `CompositorEffect` has to outline every visible pixel, not just tier-1 pixels, which is actually fine for hands (everything in the hands SubViewport IS a hand) but couples this ADR tightly to ADR-0001's shader internals.
- **Estimated Effort**: 2× chosen approach (dual shader maintenance; one additional full-screen pass).
- **Rejection Reason**: The inverted-hull technique is visually near-identical to Sobel at close range on curved surfaces (hands), and does not require duplicating ADR-0001's shader. The marginal visual gain does not justify the ongoing maintenance cost. Listed here in case post-launch playtest reveals a perceptible difference — if so, this ADR can be superseded to switch to Alternative 3.

### Alternative 4: Flat-billboard hands sprite with baked outline

- **Description**: Abandon 3D rigged hands entirely. Use a 2D sprite with pre-authored animation frames, overlaid on the HUD layer. Outline is pre-baked into the sprite art.
- **Pros**: Zero rendering complexity; outline is literally a PNG.
- **Cons**: No rigged animation; no procedural aim/gadget blending; no depth-correct gadget hold poses; no physics-driven hand reactions (which are in scope for Mission Scripting "script-driven cinematic moments"). This is a retro choice suitable for a different art direction (e.g., 1990s CRPG). *The Paris Affair*'s stylized-3D direction per Art Bible Section 1 is not compatible.
- **Estimated Effort**: Large initial art burden; low rendering effort.
- **Rejection Reason**: Violates the project's stylized-3D art direction. Not a credible option for this game.

## Consequences

### Positive

- Hands visible with heaviest-tier outline as Player Character GDD AC-11.1 requires.
- Implementable today with known Godot 4.x patterns; no GDExtension, no post-cutoff API load-bearing.
- Visual identity pillar (Art Bible Principle 2 — Silhouette Owns Readability) preserved across all on-screen assets.
- No changes required to ADR-0001 — the stencil contract is unaffected by this exception; hands are simply not a participant.
- Inverted-hull pass has predictable, low performance cost (~0.1–0.3 ms on Iris Xe for the expected hand geometry).
- Shader Baker can precompile the hands outline shader at export time, eliminating first-frame stutter.
- Cross-platform identical behavior — inverted hull is pure vertex math; no stencil API, no backend-specific behavior.

### Negative

- Hands outline uses a different technique (hull extrusion) than the rest of the world (screen-space Sobel). At close range, the silhouette character may differ subtly — hull outlines follow normals, Sobel follows depth/normal discontinuities. Mitigation: perceptual validation during verification gate; if perceptibly different, consider Alternative 3 before accepting.
- `outline_world_width` is manually tuned, not math-derived from pixel target. Re-tuning required if the hand mesh scale or typical viewing distance changes. Documented as tuning knob (starting value 0.006 local-space units).
- Vertex-normal authoring discipline on the hands mesh is now load-bearing — sharp normal breaks will produce visible outline artifacts. This is a non-trivial constraint on the hands asset pipeline.
- Adds two draw calls per frame for hands (outline pass + fill pass). At ~5–10k triangles each, <0.1 ms combined on Iris Xe. Acceptable.
- One project-wide exception exists to the ADR-0001 stencil contract. Future systems reading ADR-0001 must also read this ADR to understand that hands are different.

### Neutral

- The hands SubViewport is already required by the FPS-hands FOV pattern; this ADR does not add a SubViewport, it just uses the one that exists.
- The `resolution_scale` signal from Settings & Accessibility is consumed by both ADR-0001 and ADR-0005. This is a mild coupling that both ADRs share; acceptable.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Inverted-hull extrusion produces visible artifacts at finger joints or wrist under animation (sharp normal discontinuities) | MEDIUM | LOW-MEDIUM | Vertex-normal authoring rule on hands mesh (documented in Implementation Guideline 5). Verification gate explicitly tests animated hand pose; if artifacts appear, fix in mesh authoring before shipping. |
| `outline_world_width` drifts from ADR-0001 tier-1 visual target when `resolution_scale` switches to 0.75 on Iris Xe | MEDIUM | MEDIUM | `resolution_scale` uniform mandatory (Implementation Guideline 4). Wired to the same `Settings.get_resolution_scale()` source ADR-0001 uses. Verification gate 3 confirms parity. |
| SubViewport composite runs BEFORE the main camera's outline `CompositorEffect` completes, producing visible frame latency or ordering artifacts | LOW | MEDIUM | Implementation Guideline 11: hands CanvasLayer sits at layer 10 (above 3D scene, below overlays). CanvasLayer render order in Godot is deterministic by layer index. Verification gate confirms the composite happens after the outline pass. |
| Inverted-hull approach looks subtly different from Sobel outline at close range, breaking visual-consistency target | MEDIUM | LOW | Perceptual validation during gate 1 prototype. If perceptibly different, either re-tune `outline_world_width` (usually resolves it) or supersede with Alternative 3 (screen-space SubViewport post-process). |
| Animating mesh with skeletal deformation interacts badly with the inverted-hull vertex extrusion at runtime | LOW | MEDIUM | Skeletal deformation runs before user `vertex()` code in Godot's spatial shader pipeline; extrusion is applied to the post-skinned vertex. Verification gate explicitly tests rigged animation. |
| Future developer adds a second exception (another mesh class using inverted-hull instead of stencil) without going through ADR process — contract drift | MEDIUM | LOW | Implementation Guideline 1 + code-review checklist entry: "Is this mesh calling OutlineTier.set_tier? If no, does it appear in ADR-0005's scope? If still no, block the PR." |
| Shader Baker mishandles the two-pass material in 4.6 export | LOW | MEDIUM | Gate 1 runs in editor where Shader Baker is optional. Export-time test pending first export build (flagged in project backlog when export pipeline lands). |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (frame time) — hands SubViewport render setup | N/A (no project) | <0.05 ms (SubViewport is a standard Godot node; update cost is the mesh update, not SubViewport overhead) | Part of the 16.6 ms frame budget |
| GPU (frame time) — hands inverted-hull pass @ 1080p on RTX 2060 | N/A | 0.03–0.08 ms (~5–10k triangles, vertex-bound, minimal fragment work) | — |
| GPU (frame time) — hands inverted-hull pass on Iris Xe at 75% scale | N/A | 0.10–0.25 ms | — |
| GPU (frame time) — hands fill pass | N/A | 0.05–0.15 ms (PBR-ish, low triangle count, small screen coverage) | Shared with ADR-0001 outline budget; hands total ≤0.3 ms target |
| Memory — HandsOutlineMaterial resource | N/A | <20 KB (shader + uniforms) | Negligible |
| Memory — hands SubViewport texture | N/A | ~2 MB at 1920×1080 RGBA8; ~1 MB at 75% scale | Negligible |

> Total hands rendering cost: ≤0.3 ms on Iris Xe at 75% scale. Combined with ADR-0001's 2 ms outline pass budget, the entire outlining system fits within 2.3 ms (~14% of frame budget), leaving 14+ ms for gameplay, physics, AI, and audio.

## Migration Plan

This is the project's fifth ADR. No existing code or saves to migrate. Implementation order:

1. **Verification gate 1** (Vulkan/Linux, 30 minutes): create a minimal scene with a main camera rendering a cube with ADR-0001 tier-1 stencil outline, plus a SubViewport containing a test hand-stand-in mesh with the inverted-hull shader. Confirm visual parity (both objects have a ~4 px black outline). Confirm outline survives when the stand-in mesh is parented to a simple `Skeleton3D` with an animated pose.
2. ~~**Verification gate 2** (D3D12/Windows): run the same scene via Windows build, confirm identical output.~~ **CLOSED BY REMOVAL 2026-04-30 (Amendment A6)** — D3D12 not targeted.
3. **Verification gate 3** (resolution scale): toggle `resolution_scale` uniform from 1.0 to 0.75; confirm both world outline (ADR-0001) and hands outline (this ADR) scale proportionally in the frame.
4. If all three gates pass: author the production `HandsOutlineMaterial` resource, wire `resolution_scale` to the Settings signal, and implement Player Character hands per revised GDD.
5. Set ADR-0005 status Proposed → Accepted.

**Rollback plan**: If gate 1 or gate 2 fails (e.g., inverted-hull produces unacceptable artifacts, or backend parity breaks), supersede this ADR with one selecting Alternative 3 (screen-space SubViewport post-process outline) OR Alternative 2 (no outline on hands, last resort). Player Character GDD AC-11.1 must be reconciled accordingly.

## Validation Criteria

- [ ] **Gate 1** — Vulkan/Linux prototype renders hands-stand-in with ~4 px outline matching an adjacent stencil-outlined cube.
- [x] ~~**Gate 2** — same scene renders identically on D3D12/Windows.~~ **CLOSED BY REMOVAL 2026-04-30 (Amendment A6)** — D3D12 not targeted; Vulkan-only on both Linux and Windows.
- [ ] **Gate 3** — `resolution_scale` toggle (1.0 → 0.75) scales both outlines proportionally; no visible divergence.
- [ ] **Gate 4** — animated rigged hand mesh (idle sway + interact reach) shows no outline artifacts at finger joints or wrist.
- [ ] **Gate 5** (added 2026-04-23 per godot-specialist 2026-04-22 §6) — In a Godot 4.6 export build, verify Shader Baker compiles `hands_outline_material.gdshader` assigned via `material_overlay` on the skinned hands mesh. If Shader Baker excludes `material_overlay` slots from baking in 4.6, escalate to the two-surface `ShaderMaterial` fallback described in Implementation Guideline 7 (the `material_overlay` vs two-surface tradeoff stated in the Key Interfaces code comment). **This gate MUST pass before Prototype phase completes.** Moved from Polish phase (prior scope) to Prototype phase because discovering a Shader Baker exclusion during Polish would force a cascading refactor through every hands-holding weapon pose and every FPS-hands animation state — a costly and schedule-breaking rework. Prototype-phase verification is cheap; Polish-phase discovery is not.
- [ ] Hands material does NOT call `OutlineTier.set_tier`; the PC GDD and the hands scene script are both consistent with this.
- [ ] `resolution_scale` uniform is wired to the same `Settings.get_resolution_scale()` source that ADR-0001's `CompositorEffect` reads.
- [ ] Outline color `#1A1A1A` matches ADR-0001 outline color uniform (code review verifies both are using the same source constant when ADR-0001 implementation lands).
- [ ] Code review checklist entry: "If this PR touches a mesh instantiation, does the mesh call `OutlineTier.set_tier` OR does it appear in ADR-0005's scope (hands)? Reject PRs that fail both."
- [ ] Hands mesh asset-spec authoring rule: smoothed vertex normals across finger joints and wrist.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/player-character.md` | Player Character (system 8) — Visual/Audio Section | "FPS hands rendered at FOV 55° with tier HEAVIEST outline" | Hands render in SubViewport at FOV 55°; outline achieved via inverted-hull shader (tier-HEAVIEST visual target without stencil participation). |
| `design/gdd/player-character.md` | AC-11.1 | "No head-bob, no sprint whoosh, no damage-edge vignette, no stamina bar, no hold-E interact meter" (implicit: outlined hands present, not absent) | Outline remains visible on hands without violating the no-modern-UX pillar. |
| `design/art/art-bible.md` | Section 1 Principle 2 — Silhouette Owns Readability | "All foreground objects have outline contributing to figure-ground" | Hands participate in the outline visual identity via an alternate technique. |
| `docs/architecture/adr-0001-stencil-id-contract.md` | ADR-0001 Implementation Guideline 1 | "Every visible object must declare its outline tier" | ADR-0005 registers hands as an explicit exception to ADR-0001. Any reader of ADR-0001 should cross-reference this ADR. |

## Revision History

- **2026-04-30 (Amendment A6 — Gate 2 D3D12 closed by removal)**: Project-level decision (ADR-0001 Amendment A2 + `project.godot [rendering] rendering_device/driver.windows="vulkan"`) drops D3D12 as a target backend. Cross-platform parity collapses to single-Vulkan verification on Linux and Windows. Effects on this ADR: Gate 2 closes by removal; §Status, §Knowledge Risk, §Verification Required, §Constraints, §Migration Plan §gate 2, §Validation Criteria Gate 2 updated. Gate 1 also confirmed PASS this date via Sprint 01 spike `prototypes/verification-spike/fps_hands_demo.tscn` (Linux Vulkan visual verification — inverted-hull capsule renders correct outline; thickness tuning is a production concern, not a gate). Status stays Proposed: Gates 3, 4, 5 require the actual hands rendering production story (resolution-scale toggle behavior on rigged mesh, animated mesh artifacts, Shader Baker × `material_overlay` compatibility in export build).
- **2026-04-23 (Amendment A5 — Gate 5 added; moved Shader Baker × `material_overlay` compatibility to Prototype phase)**: per godot-specialist 2026-04-22 §6 to avoid costly refactor if Shader Baker excludes `material_overlay` slots from baking in 4.6.

## Related

- **ADR-0001** (Stencil ID Contract) — parent; this ADR is an explicit coexistence exception. ADR-0001 governs all other mesh classes; ADR-0005 governs hands only.
- **Art Bible** Section 4.4 (color palette — outline `#1A1A1A`), Section 1 Principle 2 (Silhouette Owns Readability) — visual targets this ADR implements.
- **Player Character GDD** Section I (Visual/Audio) — the consuming GDD. PC GDD Section I will be edited as part of Session B revision to cite this ADR and remove the `OutlineTier.set_tier(hands_mesh, HEAVIEST)` call. AC-11.1 is unchanged (the "what" — outlined hands); AC-10.1 is rewritten to test the inverted-hull material is applied.
- **Godot community reference**: inverted-hull outline is a well-documented technique since Godot 3.x; examples exist in community tutorials for cel-shading and toon rendering.
- **Future ADR (if needed)**: if playtest reveals hull-vs-Sobel divergence as a visual problem, a superseding ADR can switch to Alternative 3 (screen-space post-process in hands SubViewport). Cost is moderate; change is contained to hands.
