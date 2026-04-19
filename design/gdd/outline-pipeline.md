# Outline Pipeline

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists (godot-shader-specialist, technical-artist, art-director per routing)
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Pillar 1 (Comedy Is a Visual Category — comedic props get heaviest outline); Pillar 3 (Silhouette Owns Readability — outline carries figure-ground separation); Pillar 5 (Period Authenticity — comic-book visual signature)

## Summary

Outline Pipeline is the project's comic-book outline post-process — a full-screen shader that renders dark outlines around visible geometry at three tiered pixel weights (4 / 2.5 / 1.5 px at 1080p) to match the Art Bible's *"If a panel from a 1966 spy comic could slot in"* rule. It reads the stencil buffer per pixel (value written by every renderable object per ADR-0001) to select the correct kernel width: Eve and key interactives get the heaviest outline; PHANTOM guards get medium; environment gets light; unmarked geometry (stencil 0) gets none. Implemented as a Godot 4.6 `CompositorEffect`. Performance budget: ≤2.0 ms at 1080p. Resolution scale 0.75 default-on for Intel Iris Xe-class integrated graphics. ADR-0001 is the architectural contract.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Effort: `L` · Implementation contract: ADR-0001 (Stencil ID Contract) · Key art bible sections: 1, 3.4, 8C, 8F, 8J

## Overview

The Outline Pipeline is the single most identity-defining rendering system in *The Paris Affair* — it is the reason the game looks like a 1966 spy-comic panel instead of a generic low-poly indie. Every frame, after all opaque geometry has rendered, a full-screen `CompositorEffect` shader runs: it samples the depth and stencil buffers per pixel, detects edges where depth changes sharply (Sobel edge-detect kernel), and draws near-black outlines (`#1A1A1A`) at one of three weights based on the stencil tier of the object behind the pixel.

The system's architectural contract is **ADR-0001 (Stencil ID Contract)**. Key decisions locked there:

- **4 stencil values**: `0 = no outline`, `1 = heaviest (4 px) — Eve, gadget pickups, bomb components, comedic hero props`, `2 = medium (2.5 px) — PHANTOM guards`, `3 = light (1.5 px) — environment, civilians`.
- **Every `MeshInstance3D` must be paired with `OutlineTier.set_tier(mesh, tier)`** at spawn time. The forbidden pattern `unmarked_visible_mesh` enforces this in code review.
- **Escape-hatch runtime tier reassignment** (e.g., the swinging lamp in Lower Scaffolds can be promoted to tier 1 during a focal moment).
- **4 verification gates** pending before the ADR moves from Proposed to Accepted: material API exposure, stencil read on Vulkan and D3D12, perf on Iris Xe.

This GDD's job is to articulate the shader's design-level behavior: what the player sees (Art Bible Section 1 Principle 2 — *Silhouette Owns Readability*), how the tiered weights communicate (outline hierarchy signals importance without HUD chrome), how the outline survives diegetic lighting variance (lighting does NOT weaken outlines — this is per Art Bible's rule that alert state is signaled through audio, not visuals), and how the pipeline integrates with Post-Process Stack's sepia-dim effect (outline runs before sepia, so the dim darkens both world and outlines equally).

**Non-goals of this GDD:** re-specifying the stencil contract (ADR-0001) or shader implementation details (a future ADR *Outline Shader Implementation* — Sobel vs Laplacian kernel, edge threshold tuning — will cover those).

## Player Fantasy

**"The Page Points at What Matters."** You play a spy comic where the artist has inked the important things thicker. When you enter a room, your eye lands — without thinking — on the gadget on the table, the uncollected document on the desk, the chloroform bottle on the shelf. Not because they glow. Not because they pulse. Not because a tooltip fires. Because they are drawn the way a 1966 comic artist draws a plot-relevant prop: with the fattest, most confident line on the panel.

This is **NOLF1's diegetic discipline married to Saul Bass's figure-ground clarity**. NOLF1 made important things visually distinct through lighting, prop placement, and character contrast — never through modern UI markers. The Outline Pipeline replaces that job with a tiered line-weight hierarchy:

- **Tier 1 (Heaviest, 4 px at 1080p)** — Eve and key interactives (gadget pickups, bomb components, uncollected documents, comedic hero props). The eye goes here first. A comedic signboard in the Plaza gets the heaviest outline locally — it is **the joke's punchline, visually**.
- **Tier 2 (Medium, 2.5 px)** — PHANTOM guards. Always legible, always a threat, never hidden by atmospheric lighting because lighting doesn't weaken outlines here (diegetic lighting rule from Art Bible).
- **Tier 3 (Light, 1.5 px)** — environment, civilians, set dressing. The thinnest line in the frame, giving scene depth without competing for attention.

You read the scene like reading a Villemot Air France poster: hierarchy first, detail second.

**Pillars served:**
- **Pillar 1 (Comedy Without Punchlines)** — the heaviest outline *is* the punchline; no character needs to quip.
- **Pillar 2 (Discovery Rewards Patience)** — the line weight quietly marks what rewards closer looking; patient observers read the hierarchy and find the hidden documents.
- **Pillar 3 (Stealth is Theatre)** — you read the stage before you move through it; the outline is how the scene tells you where drama lives.

Players will never say *"the outline system is great."* They will say *"I always know where to look."*

## Detailed Design

### Core Rules

1. **Every visible MeshInstance3D writes a stencil tier at spawn.** Per ADR-0001 + forbidden pattern `unmarked_visible_mesh`. The spawning system calls `OutlineTier.set_tier(mesh, tier)` before the mesh renders its first frame. Unmarked meshes receive stencil 0 and render with NO outline — visible bug, caught by code review.

2. **Stencil values map to outline weights (locked by ADR-0001):**

   | Stencil | Tier | Weight at 1080p | Assigned to |
   |---|---|---|---|
   | 0 | NONE | No outline | Invisible collision meshes; document-overlay dim ColorRect; intentionally un-outlined geometry |
   | 1 | HEAVIEST | 4 px | Eve, gadget pickups, bomb components, uncollected documents, **comedic hero props locally** |
   | 2 | MEDIUM | 2.5 px | PHANTOM guards (all variants, all helmet types) |
   | 3 | LIGHT | 1.5 px | Environment geometry, civilians |

3. **Outline color is fixed: near-black `#1A1A1A` (Art Bible 4.4).** Uniform across all tiers. The tier varies KERNEL WIDTH, not color. This preserves the "ink on saturated color" comic-panel identity — ink is always black.

4. **Pixel weights scale with render resolution.** At 75% resolution scale (Intel Iris Xe default), the tier weights become `3 / 1.875 / 1.125 px` internally, upscaled to output. The shader reads `resolution_scale` uniform and scales kernel width accordingly. At 1440p, weights scale up proportionally (5.33 / 3.33 / 2.0 px).

5. **Comedic hero props get heaviest-tier treatment LOCALLY regardless of placement.** Per Art Bible 1 Principle 3 (Comedy Is a Visual Category): oversized signage, absurdist labeled crates, comedic documents — each gets stencil 1 locally, even if surrounded by tier-3 environment. This is how the outline system serves Pillar 1.

6. **Lighting does NOT weaken outlines.** The outline pass runs AFTER opaque geometry pass + before transparent/UI. Diegetic lighting variance (warm Plaza amber, cool Upper Structure moonlight, flickering Bomb Chamber fluorescent) affects the geometry beneath — NOT the outline. A guard in deep shadow still reads clearly because the medium outline is visible regardless of scene brightness. This honors Art Bible Section 1 Principle 2 (*Silhouette Owns Readability*) and the locked NOLF1 rule (alert state via audio, not visuals).

7. **Runtime tier reassignment is supported via `OutlineTier.set_tier(mesh, new_tier)`.** Systems can promote or demote an object's outline at runtime. Example (from Art Bible): the swinging lamp in Lower Scaffolds is normally Tier 3 (Light); during a scripted focal moment, the lamp controller calls `set_tier(lamp_mesh, 1)` to draw the player's eye. The shader does not change — only the stencil value on the material.

8. **Outline pass runs as a single `CompositorEffect` on the active `Camera3D`.** It is NOT per-mesh, NOT multi-pass, NOT applied to individual materials. One shader, one pass, sampling depth + stencil buffers per pixel and branching on stencil value.

9. **Outline pass does NOT apply to screen-space UI or CanvasLayer elements.** UI is drawn after the outline pass (per ADR-0001 render order: opaque → outline → transparent → CanvasLayer UI). UI owns its own visual language via ADR-0004 (UI Framework) — no outline there.

10. **Performance budget: ≤2.0 ms at 1080p (per Art Bible 8F + architecture.yaml).** Target: 0.8–1.5 ms on RTX 2060. On Intel Iris Xe integrated graphics, the 75% resolution-scale fallback is default-on to stay within budget. Budget is enforced by `/perf-profile` audits against a reference scene (Restaurant dense-interior as worst case).

11. **Anti-pattern fences** (registered in architecture.yaml from ADR-0001):
    - `unmarked_visible_mesh` — every `MeshInstance3D` MUST have a paired `OutlineTier.set_tier(mesh, tier)` call
    - Outline color MUST be `#1A1A1A` (no tier-color variation)
    - Outline pass MUST run exactly once per frame, NOT per-tier multi-pass
    - Stencil values 4–255 are reserved for future use; this system uses 0–3 ONLY

### States and Transitions

Outline Pipeline is **stateless within the frame** but has a few startup states:

| State | Description | Duration |
|---|---|---|
| `UNINITIALIZED` | `CompositorEffect` resource not yet loaded; shader not compiled | Pre-`_ready()` of the owning Camera3D |
| `BAKING` | Shader Baker (Godot 4.5+) pre-compiles the outline shader variants | One-time at project build or first-run (~0–500 ms) |
| `READY` | Shader loaded, stencil read API verified, `CompositorEffect` active on camera | Persistent; runs once per frame |
| `FALLBACK` | Low-spec mode: resolution scale = 0.75 OR uniform-weight outline if stencil tier-branching is unavailable | Set at startup based on hardware detection |

**Runtime "state" per pixel:** each pixel reads its stencil tier and branches to one of four outcomes: `discard` (tier 0), edge-detect with 4 px kernel (tier 1), 2.5 px kernel (tier 2), 1.5 px kernel (tier 3). This is execution-state, not system-state.

### Interactions with Other Systems

#### Stencil-writing systems (11 upstream contributors)

Every system that spawns `MeshInstance3D` objects MUST write the correct tier:

| System | Objects spawned | Tier assignment |
|---|---|---|
| Player Character (8) | Eve's FPS hands mesh | Tier 1 (heaviest) |
| Stealth AI (10) | PHANTOM guards (bowl-helmet, open-face, elite variants) | Tier 2 (medium) |
| Combat & Damage (11) | Weapon meshes (when visible); NPC death props | Weapons: Tier 1 if held by Eve, Tier 2 if held by guard. Death props: Tier 3. |
| Inventory & Gadgets (12) | Gadget pickups in world; equipped gadget visible on Eve | Pickups: Tier 1. Equipped-to-Eve: Tier 1. |
| Document Collection (17) | Uncollected documents in world; document preview meshes | Tier 1 (uncollected); N/A (collected ones vanish) |
| Civilian AI (15) | Paris civilians | Tier 3 (light). BQA contact in Plaza: Tier 1 at pickup distance only. |
| Mission & Level Scripting (13) | Scripted props (bomb device, relay rack, named environmental items) | Tier 1 (hero props); Tier 3 (scripted but non-hero); comedic signage Tier 1 locally |
| Level Streaming (9) | Environment geometry (ironwork, walls, furniture, grating) | Tier 3 (light) |

#### Downstream consumer

| System | Nature |
|---|---|
| Post-Process Stack (5) | Outline pass runs **before** sepia-dim composition. Sepia dim multiplies over both world geometry AND outlines — outlines darken proportionally. Post-Process Stack respects the outline pass's output buffer and does not write to depth/stencil after. |

#### Settings & Accessibility integration

`Settings & Accessibility` exposes a `resolution_scale` setting that defaults to:
- `1.0` on RTX 2060-class and higher
- `0.75` on integrated graphics (detected via `RenderingServer.get_video_adapter_type()` at startup)

The setting emits `setting_changed("graphics", "resolution_scale", value)` on change. Outline Pipeline's `CompositorEffect` reads this uniform and scales the kernel widths accordingly (Formula 2 in Section D).

#### Event bus

Outline Pipeline does NOT publish or subscribe to any Signal Bus event. It is a per-frame rendering service, not an event-driven system. All interactions are via direct API (`OutlineTier.set_tier`) and shader uniforms.

#### Verification gates (from ADR-0001, pending before Accepted)

The following 4 gates must pass before this GDD reaches Approved status and before any gameplay system GDD can implement its stencil-writing:

| Gate | What must be verified | Owner |
|---|---|---|
| Gate 1 | `BaseMaterial3D` stencil write value property exposure (or confirmed need for custom `ShaderMaterial`) | technical-artist + godot-shader-specialist, 5-min editor test |
| Gate 2 | `CompositorEffect` stencil buffer read on Vulkan (Linux) | technical-artist, 30-min shader prototype |
| Gate 3 | Same on D3D12 (Windows 4.6 default) | technical-artist, cross-platform test |
| Gate 4 | Performance: outline pass ≤2.0 ms on Iris Xe at 75% scale | performance-analyst, benchmark run |

## Formulas

### Formula 1 — Per-tier kernel width selection

`kernel_px = tier_weights[stencil_value]` where `tier_weights = [0.0, 4.0, 2.5, 1.5]` (indexed by stencil tier).

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `stencil_value` | s | int | 0 to 3 | Stencil tier read per pixel from depth-stencil buffer |
| `kernel_px` | k | float | 0.0, 1.5, 2.5, 4.0 | Edge-detect kernel radius in reference pixels at 1080p |

**Output range:** `0.0` (tier 0 — discard pixel, no outline), `1.5` (tier 3), `2.5` (tier 2), `4.0` (tier 1). No fractional tiers.

**Example:** A pixel covering a PHANTOM guard's helmet reads stencil value 2; kernel_px = 2.5. A pixel covering the Plaza floor reads stencil value 3; kernel_px = 1.5. A pixel covering the transparent HUD panel reads stencil value 0; kernel_px = 0.0 → discard (no outline).

### Formula 2 — Resolution-adjusted kernel

`kernel_actual = kernel_px * resolution_scale * (current_height / 1080.0)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `kernel_px` | k | float | 1.5 / 2.5 / 4.0 | Reference kernel from Formula 1 |
| `resolution_scale` | s | float | 0.5 to 1.0 | From Settings `graphics.resolution_scale`; 0.75 default on integrated graphics, 1.0 on desktop GPU |
| `current_height` | h | int | 720 to 2160 | Actual render target height in pixels |
| `kernel_actual` | k' | float | 0.5 to 8.0 | Kernel radius applied by the shader in current-resolution pixels |

**Output range:** at 1080p native (scale=1.0, height=1080), `kernel_actual = kernel_px` (4.0 / 2.5 / 1.5). At 1080p with scale=0.75, `kernel_actual = 3.0 / 1.875 / 1.125` in internal pixels. At 1440p native, `kernel_actual = 5.33 / 3.33 / 2.0`.

**Example:** Player on Iris Xe, set to `resolution_scale = 0.75`, game runs at 1080p output (internal 810p). Tier 1 kernel = `4.0 * 0.75 * (810 / 1080.0) = 4.0 * 0.75 * 0.75 = 2.25 px`. The shader samples a 2.25-px radius at internal resolution, which upscales visually to approximately 3 px at the 1080p output.

**Edge case:** Minimum 0.5 px (below which the outline is invisible). If `kernel_actual < 0.5`, clamp to 0.5. This can occur at aggressive resolution-scale settings (<0.4) or unusual render targets below 540p.

### Formula 3 — Edge detection threshold

The outline shader uses a Sobel or Laplacian edge-detect kernel on the depth buffer. A pixel is considered "on an edge" if the depth gradient magnitude exceeds a threshold.

`is_edge = length(sobel_depth_gradient(uv)) > edge_threshold`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `sobel_depth_gradient(uv)` | g | vec2 | 0.0 to ~∞ per axis | Horizontal + vertical depth derivatives at the UV |
| `edge_threshold` | t | float | 0.001 to 0.1 | Tuning knob; lower = more outlines drawn, higher = only sharper edges |

**Output:** boolean. Pixels failing the edge test are discarded (no outline drawn). Pixels passing are drawn with `outline_color = vec4(0.10, 0.10, 0.10, 1.0)` (`#1A1A1A`).

**Example:** `edge_threshold = 0.02` typical. A guard silhouette against a wall: sharp depth change → gradient magnitude ~0.5 → edge drawn. A subtle ridge on the Eiffel ironwork: small depth change → gradient magnitude ~0.01 → edge NOT drawn (threshold filters out noise). A future ADR (*Outline Shader Implementation*) will finalize the threshold value after visual testing.

### Formula 4 — Budget check

`budget_remaining_ms = 2.0 - measured_pass_ms`

The shader's actual cost is measured via `Performance.RENDER_SHADER_COMPILES` and profiling. If `measured_pass_ms > 2.0` for 5 consecutive frames, a warning logs and `/perf-profile` audit flags it.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `measured_pass_ms` | m | float | 0.0 to ∞ | Measured outline pass duration |
| `budget_remaining_ms` | r | float | -∞ to 2.0 | If negative, over budget |

**Output:** diagnostic only — does not affect runtime behavior. Positive = within budget; negative = over. Used by performance profiling, not gameplay logic.

## Edge Cases

- **If a `MeshInstance3D` spawns without a stencil-tier assignment** → it renders with stencil 0, producing no outline. Visible bug: the object has no outline in a scene where everything else does. **Resolution**: forbidden_pattern `unmarked_visible_mesh` catches in code review. `/perf-profile` + QA checklist scan for meshes without paired `OutlineTier.set_tier` calls.
- **If a mesh has multiple surfaces / material slots with different stencil values** → the outline shader samples stencil per pixel, so different faces of the same mesh can have different tiers. **Resolution**: intended. Useful for characters with multi-slot materials (e.g., Eve's jacket = Tier 1 body, face = Tier 1 head) — all typically the same tier, but the mechanism supports per-face variation if a future design needs it.
- **If a transparent surface (e.g., window glass) renders over tier-marked geometry** → stencil is written by opaque pass only; transparent pixels render AFTER outlines but don't modify stencil. The outlines "shine through" transparent glass. **Resolution**: intended. The ironwork behind a window is still outlined; the glass itself is tier 0 (transparent surfaces don't write stencil) so no outline on glass edges.
- **If the camera is looking at a geometry-free direction** (pure sky dome or cleared framebuffer) → stencil is all 0; the shader discards every pixel; no outlines rendered. **Resolution**: intended. No cost, no visual artifact.
- **If the player rapidly rotates the camera** → outline updates per frame; no temporal smoothing applied. Possible frame-to-frame flicker on sharp edges if the edge crosses a subpixel. **Resolution**: acceptable at MVP. SMAA anti-aliasing (Godot 4.5+) is the mitigation if flicker proves visible; set in Project Settings as a polish-phase decision.
- **If the outline post-process exceeds 2.0 ms on the min-spec target** → performance-analyst audit fails; resolution scale drops to 0.75 (already default on integrated graphics) or 0.6 (emergency fallback for slower hardware). **Resolution**: Formula 2 + tuning knob `resolution_scale` handles gracefully. If 0.6 scale is insufficient, a uniform-weight outline fallback (single outline thickness, no tier branching) is documented in ADR-0001 as Alternative 2.
- **If a gameplay system calls `OutlineTier.set_tier(mesh, 5)`** (an invalid value outside 0–3) → the `OutlineTier` helper asserts or clamps to range. **Resolution**: `OutlineTier.set_tier` validates input; values outside [0, 3] trigger an `assert(tier >= 0 and tier <= 3, "Invalid outline tier")` in debug builds; release builds clamp silently to Tier 3 to preserve visibility.
- **If a mesh is reassigned tier mid-frame via the escape-hatch (e.g., swinging lamp promotion)** → the stencil value changes on next frame render. There is no animation or transition — the outline snaps from Tier 3 to Tier 1 instantly. **Resolution**: intended. The escape-hatch is designed for scripted focal moments where a sharp visual shift is the intent, not gradual attention-drawing.
- **If the render target resizes (windowed mode, fullscreen toggle)** → the `CompositorEffect` automatically adjusts; `current_height` in Formula 2 is read per frame. Kernel widths scale. **Resolution**: intended. No manual reset required.
- **If the outline pass runs before stencil buffer is populated** (execution ordering bug) → all pixels read stencil 0 and discard. No outlines visible. **Resolution**: `CompositorEffect` effect ordering is set to run AFTER opaque pass by default in Godot 4.3+. Verify during implementation; no design decision needed.
- **If a post-process after the outline pass (e.g., bloom, glow) mutates the outline color** → unintended. **Resolution**: ADR-0004 (UI Framework) + Art Bible 8J item 7 specify glow is DISABLED in this project. Document Overlay sepia-dim (Post-Process Stack) runs AFTER outline and is composition-only, not per-color-channel mutation. No outline color corruption expected.
- **If a cutscene wants a different outline style** (e.g., all-tier-1 for cinematic emphasis) → Cutscenes & Mission Cards can call `OutlineTier.set_tier` on specific meshes at cutscene start, restore on end. Or a cutscene-specific `CompositorEffect` can swap in. **Resolution**: supported via escape-hatch. Cutscene-specific outline handling lives in the Cutscenes GDD; Outline Pipeline provides the API.
- **If the player's save is loaded while in-scene** → Level Streaming swaps scene → all new mesh instances spawn → each spawning system re-runs its `OutlineTier.set_tier` calls. **Resolution**: intended. Outlines re-establish as part of normal scene instantiation. No outline state persists across a load.

## Dependencies

### Upstream dependencies

| System | Nature |
|---|---|
| **ADR-0001 (Stencil ID Contract)** | Hard architectural dependency — the contract this system implements. |
| Godot 4.6 `CompositorEffect` + `Compositor` node (4.3+) | Hard engine dependency. Stencil buffer access (4.5+) is required for per-pixel tier branching. |
| Godot 4.5+ Shader Baker | Soft dependency — eliminates first-frame compile stutter. Project pinned to 4.6 so this is available. |

### Downstream dependents

| System | Nature |
|---|---|
| **Post-Process Stack** (5) | Sepia-dim composition order depends on outline pass running first. Outline writes to color buffer; sepia-dim multiplies over it. |
| **All 11 stencil-writing systems** | Player Character, Stealth AI, Combat & Damage, Inventory & Gadgets, Document Collection, Civilian AI, Mission & Level Scripting, Level Streaming, plus any future system that spawns a MeshInstance3D. Each must call `OutlineTier.set_tier()` per ADR-0001. |
| **Settings & Accessibility** (23) | Owns `graphics.resolution_scale` setting that Outline Pipeline reads. Detects hardware at startup (Iris Xe = 0.75 default; RTX 2060+ = 1.0 default). |
| **Scene authors / level designers** | Set stencil tier on static environment geometry via scene editor (bake at design time, not runtime). |

### No direct interaction

- **Signal Bus (ADR-0002)**: Outline Pipeline neither publishes nor subscribes. Per-frame shader, not event-driven.
- **Audio**: no interaction.
- **Save/Load (ADR-0003)**: stencil values are ephemeral per-frame state, not saved.
- **Input**: no interaction (except via Settings' debug keys if added in dev builds).
- **UI Framework (ADR-0004)**: UI is `CanvasLayer`, drawn AFTER outline pass. No interaction with the outline buffer.

## Tuning Knobs

### Tier weights (1080p reference)

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| `tier_1_weight_px` | 4.0 | 3.0–6.0 | Eve and key-interactive outline thickness. Larger = more comic-book assertive; smaller = more subtle |
| `tier_2_weight_px` | 2.5 | 1.5–4.0 | PHANTOM guard outline. Must be visibly thinner than Tier 1, thicker than Tier 3 |
| `tier_3_weight_px` | 1.5 | 0.75–2.5 | Environment + civilian outline. Should read as texture, not foreground |

### Outline color

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| `outline_color` | `#1A1A1A` (near-black, R=26 G=26 B=26) | Near-black shades only | Art Bible 4.4 locks near-black. Changing to pure black `#000000` risks muddy shadows; lighter shades lose comic-panel identity |

### Performance

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| `resolution_scale` | 1.0 on desktop GPU, 0.75 on integrated graphics | 0.5–1.0 | Lower = cheaper shader pass at cost of visual quality. Emergency fallback 0.5 available. Set in Settings. |
| `edge_threshold` | 0.02 (tentative) | 0.005–0.1 | Sobel depth-gradient threshold. Lower = more outlines (noisier); higher = only sharp silhouette edges |
| `budget_warning_threshold_ms` | 2.0 | 1.0–3.0 | Logs warning when outline pass exceeds this duration for 5+ consecutive frames. Debug-only. |

### Integration

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| `outline_pass_order` | After opaque, before transparent (fixed) | Locked | ADR-0001 + Art Bible 8F specify this order. Changing breaks Post-Process Stack's sepia-dim composition. |
| `shader_baker_enabled` | true | Boolean | Pre-compile shader at build. Disabling risks first-frame stutter on first scene load. |

### Reserved / not owned by this GDD

- Stencil values 4–255 — reserved for future use; not tunable in this system
- Object-to-tier assignments — owned by each spawning system's GDD
- Material slot count / texture resolutions — owned by Art Bible 8D Asset Standards
- Post-process effect ordering within the Compositor chain — owned by Post-Process Stack GDD (system 5)

## Visual/Audio Requirements

**Visual**: Outline Pipeline IS a visual feature — the bulk of its requirements are documented in the Art Bible (Section 1 Principle 2, Section 3.4, Section 4.4 color, Section 8C pixel weights, Section 8F architecture). This GDD's Formulas and Detailed Design sections translate those visual requirements into implementation contracts. No additional per-asset visual spec authored here — that's the future `/asset-spec system:outline-pipeline` run's job.

**Audio**: none. Outline Pipeline is a silent rendering pass; no SFX fire based on outline state changes. The escape-hatch runtime tier reassignment (e.g., swinging lamp promotion) may be paired with an audio cue by the triggering system (e.g., Mission Scripting plays a subtle stinger), but the outline system does not emit audio itself.

> 📌 **Asset Spec** — Visual requirements are defined. After the art bible is approved, run `/asset-spec system:outline-pipeline` to generate per-asset visual references (example scene screenshots at each tier, comparison renders with/without outline, pseudo-localization stress tests) — these become QA reference images.

## UI Requirements

**None owned by Outline Pipeline.** Settings & Accessibility (system 23) may expose a `resolution_scale` slider (discrete values: 0.5 / 0.6 / 0.75 / 1.0) in its graphics options — this is owned by Settings' GDD, not here. Outline Pipeline provides only the API: read `graphics.resolution_scale` from `user://settings.cfg`, apply as shader uniform.

No in-game UI displays outline state, tier hierarchy, or stencil values. Those are implementation details the player never sees.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Stencil ID Contract | `docs/architecture/adr-0001-stencil-id-contract.md` | 4 stencil values, tier→weight mapping, `OutlineTier.set_tier` API, 4 verification gates | Implementation contract — this GDD inherits all decisions |
| Visual identity principles | `design/art/art-bible.md` Section 1 | *"Silhouette Owns Readability"* (Principle 2), *"Comedy Is a Visual Category"* (Principle 3) | Visual direction |
| Outline weight hierarchy | `design/art/art-bible.md` Section 3.4 | Tier 1 = heaviest, Tier 2 = medium, Tier 3 = light | Rule dependency |
| Pixel weight values | `design/art/art-bible.md` Section 8C | 4 / 2.5 / 1.5 px at 1080p | Numeric source of truth |
| Pipeline architecture | `design/art/art-bible.md` Section 8F | `CompositorEffect` pattern, render order, ≤2 ms budget | Architectural source |
| Engine verification flags | `design/art/art-bible.md` Section 8J | 4 post-cutoff Godot features flagged | Risk dependency |
| Outline color | `design/art/art-bible.md` Section 4.4 | `#1A1A1A` near-black | Color palette dependency |
| Forbidden patterns | `docs/registry/architecture.yaml` | `unmarked_visible_mesh` | Rule dependency |
| Interface contract | `docs/registry/architecture.yaml` | `outline_tier_assignment` — `OutlineTier.set_tier(mesh, tier)` | API dependency |
| Performance budget | `docs/registry/architecture.yaml` | `outline-pipeline: 2.0 ms` | Constraint source |

## Acceptance Criteria

### Verification gates (from ADR-0001 — must pass before Accepted)

1. **GIVEN** a `MeshInstance3D` with a `ShaderMaterial` in Godot 4.6 editor, **WHEN** stencil write is configured, **THEN** `RenderingDevice` writes the specified stencil value to the depth-stencil attachment. *(Gate 1 — ADR-0001)*
2. **GIVEN** a `CompositorEffect` shader on Linux/Vulkan, **WHEN** it samples the depth-stencil buffer, **THEN** stencil values 0–3 are readable per pixel. *(Gate 2 — ADR-0001)*
3. **GIVEN** the same shader on Windows/D3D12, **WHEN** it runs, **THEN** stencil reads produce visually identical output to Vulkan. *(Gate 3 — ADR-0001 cross-platform)*
4. **GIVEN** the outline pass running on Intel Iris Xe integrated graphics at 1080p, resolution_scale = 0.75, **WHEN** measured with `Performance` API, **THEN** the pass completes in ≤2.0 ms for 95% of frames across a 60-second sample. *(Gate 4 — ADR-0001)*

### Tier behavior

5. **GIVEN** Eve's FPS hands mesh (Tier 1), **WHEN** rendered, **THEN** the outline around her silhouette is exactly 4 px thick at 1080p native resolution.
6. **GIVEN** a PHANTOM guard (Tier 2), **WHEN** rendered, **THEN** the outline is exactly 2.5 px thick at 1080p native.
7. **GIVEN** Eiffel ironwork (Tier 3), **WHEN** rendered, **THEN** the outline is exactly 1.5 px thick at 1080p native.
8. **GIVEN** a comedic signage prop with stencil tier 1 (heaviest local tier), **WHEN** rendered in the Plaza (surrounded by tier-3 environment), **THEN** the signage's outline is 4 px (heaviest) while the surrounding environment's is 1.5 px.
9. **GIVEN** the document overlay's sepia-dim `ColorRect` (Tier 0 — no outline), **WHEN** rendered, **THEN** no outline appears on the dim overlay's edges.

### Outline color and uniformity

10. **GIVEN** any tier (1, 2, or 3), **WHEN** the outline is drawn, **THEN** the color is exactly `#1A1A1A` (RGB 26, 26, 26). No tier produces a different outline color.
11. **GIVEN** bright Restaurant lighting (amber pendant chandeliers) and dim Upper Structure (moonlight), **WHEN** a guard is visible in either section, **THEN** the guard's outline thickness is identical (lighting does not weaken outlines).

### Resolution scaling

12. **GIVEN** `graphics.resolution_scale = 0.75` in Settings, **WHEN** the outline pass runs at 1080p output, **THEN** the internal kernel applied is `kernel_px * 0.75` per Formula 2.
13. **GIVEN** the game is launched on Intel Iris Xe integrated graphics, **WHEN** `Settings & Accessibility._ready()` runs, **THEN** `resolution_scale` defaults to 0.75. On RTX 2060+, defaults to 1.0.

### Anti-pattern enforcement

14. **GIVEN** any system that spawns a `MeshInstance3D`, **WHEN** code-reviewed, **THEN** every `instantiate()` call (or `add_child(mesh_instance)`) is paired with a `OutlineTier.set_tier(mesh, tier)` call within the same function or `_ready()`. *Classification: code-review checkpoint + lint check.*
15. **GIVEN** any project source file, **WHEN** grepped for `stencil` modifications outside ADR-0001-approved APIs (`OutlineTier.set_tier` or scene-baked `ShaderMaterial`), **THEN** zero matches. *Classification: lint check.*
16. **GIVEN** the outline shader source, **WHEN** inspected, **THEN** it defines exactly 4 branches (tier 0 discard, tier 1 kernel, tier 2 kernel, tier 3 kernel). No branch uses a different outline color. No branch uses a hardcoded pixel weight (all read from uniforms).

### Runtime reassignment (escape hatch)

17. **GIVEN** the Lower Scaffolds swinging lamp mesh (normally Tier 3), **WHEN** Mission Scripting calls `OutlineTier.set_tier(lamp_mesh, 1)`, **THEN** on the next rendered frame the lamp's outline is 4 px. On `OutlineTier.set_tier(lamp_mesh, 3)`, the outline reverts to 1.5 px.
18. **GIVEN** an invalid tier value (e.g., `OutlineTier.set_tier(mesh, 5)`), **WHEN** called in debug build, **THEN** an assertion fails. In release build, the value is clamped to Tier 3 silently.

### Integration with Post-Process Stack

19. **GIVEN** a document overlay is open (Post-Process Stack sepia-dim active), **WHEN** the world renders, **THEN** the sepia darkens BOTH the world geometry AND the outlines uniformly — outlines do not render on top of the dim (they are inside it).
20. **GIVEN** no document overlay is active, **WHEN** rendered, **THEN** outlines are drawn with full `#1A1A1A` color, no sepia influence.

### Performance

21. **GIVEN** a dense Restaurant scene (4 civilians + 3 guards + chandeliers + tables), **WHEN** the outline pass runs on RTX 2060 at 1080p native, **THEN** the pass completes in ≤1.5 ms.
22. **GIVEN** Godot's Shader Baker is enabled, **WHEN** the game loads a scene for the first time, **THEN** the outline shader does not cause a measurable first-frame stutter (≤16 ms frame on first load post-bake).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Sobel vs Laplacian vs custom edge-detect kernel? | godot-shader-specialist + technical-artist | During shader implementation (future ADR *Outline Shader Implementation*) | Sobel is the default recommendation (classic, well-tuned, ~9 texture samples per pixel). Laplacian is cheaper (5 samples) but noisier. Custom kernel may be needed for specific visual targets. Resolve via playtest comparison. |
| Edge threshold value (Formula 3)? | technical-artist | After initial shader prototype | Recommendation: `0.02`. Final value via visual testing — too low = noisy outlines on subtle geometry; too high = missing outlines on gentle ridges. Document final value in the future `Outline Shader Implementation` ADR. |
| Should outline have an anti-aliasing pass applied to itself? | technical-artist | Polish phase | Current design: no — hard-edged outlines match comic-panel aesthetic. SMAA (4.5+) may be applied AFTER outline to smooth screen-level aliasing. If pixel-sharp outlines look too harsh in playtest, consider a 1px feather on the outline edge. |
| How are environment meshes tagged with stencil tier at scene design time? | level-designer + technical-artist | Before first section authoring | Recommendation: scene editor plugin that adds "Outline Tier" dropdown to MeshInstance3D inspector, saved as metadata. Alternative: per-scene script that iterates children in `_ready()` and applies tier based on naming convention. Pick one before section authoring begins. |
| Does Windows/D3D12 stencil read work identically to Vulkan/Linux? | technical-artist | Gate 3 verification | ADR-0001 Risk flagged as MEDIUM probability, HIGH impact. Test on both platforms in Week 1 of prototyping. If divergent, platform-specific shader paths required. |
| Should a uniform-weight fallback be implemented at MVP for hardware that can't handle tiered branching? | technical-artist + performance-analyst | After Gate 4 perf testing | ADR-0001 Alternative 2 documented this fallback. Currently NOT in scope at MVP; only implement if Gate 4 fails on min-spec target. |
