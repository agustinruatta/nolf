# Post-Process Stack

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists (technical-artist, art-director, godot-shader-specialist per routing)
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Pillar 3 (Stealth is Theatre — sepia-dim "suspended parenthesis" during document reading); Pillar 5 (Period Authenticity — forbids glow, bloom, chromatic aberration, and other modern-game-look effects)

## Summary

Post-Process Stack owns the screen-space effects chain that sits AFTER opaque geometry and the outline pass: the sepia-dim effect applied when the Document Overlay is open, the project-wide glow/bloom disable (per Art Bible 8J), and the resolution-scale mechanism that lets the game target Intel Iris Xe integrated graphics at 0.75 internal scale. The system exposes a minimal lifecycle API (`enable_sepia_dim()` / `disable_sepia_dim()`) that the Document Overlay UI calls per ADR-0004. No glow, no bloom, no chromatic aberration, no modern-look effects — explicitly forbidden by period authenticity. The stack runs three Godot 4.6 `CompositorEffect`s: outline (owned by Outline Pipeline), sepia dim (owned here, conditional), and resolution-scale composition (always active).

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Effort: `M` · Key deps: `None (engine only)` · Key contracts: ADR-0004 (sepia-dim lifecycle API); Art Bible 8J (glow disabled)

## Overview

Post-Process Stack is the **screen-space effects boundary** between the 3D world render and the UI layer. Its job is small but precise:

1. Manage the sepia-dim that gives the Document Overlay its *"suspended parenthesis"* register (Art Bible Section 2).
2. Enforce the project's ban on modern post-process effects — no glow, no bloom, no chromatic aberration, no screen-space reflections.
3. Apply resolution scaling so the game stays within its 60fps / 16.6ms budget on Intel Iris Xe-class integrated graphics.

The stack consists of three `CompositorEffect` resources mounted on the active `Camera3D`'s `Compositor` node, in this fixed order (per ADR-0001 render order):

1. **Outline pass** — owned by Outline Pipeline (system 4), reads depth + stencil, draws near-black outlines. This GDD does NOT modify or re-specify the outline pass; it only commits to running it FIRST in the chain.
2. **Sepia-dim pass** — owned here. **Conditional**: active only when `enable_sepia_dim()` has been called (Document Overlay is open). When active, desaturates the rendered frame, applies a warm sepia tint, and reduces luminance to ~30% of original. When inactive, bypassed entirely (no cost). Lifecycle contract from ADR-0004.
3. **Resolution-scale composition** — the viewport renders at an internal resolution (100% on desktop GPU, 75% on integrated graphics) and this composition step upscales to the output resolution. Uses Godot's native viewport scaling; no custom shader required.

The `WorldEnvironment` node is configured project-wide with glow **disabled** (Art Bible 8J item 7 — Godot 4.6 changed glow to process before tonemapping, which would affect emissive materials like the bomb device indicator lamps unexpectedly). No `DirectionalLight3D` uses "Sky Contribution" that would invoke auto-exposure. Tonemapping is set to the engine default (neutral) because the Art Bible's Saturated Pop visual identity uses flat unlit shading that doesn't need HDR tonemapping.

**Non-goals of this GDD**: the outline shader itself (Outline Pipeline owns), the document overlay UI (Document Overlay UI owns), font rendering or typography (UI Framework / ADR-0004 owns), hardware-detection logic for resolution scale (Settings & Accessibility owns the detection; this GDD consumes the result as a shader uniform).

## Player Fantasy

**"A Photograph That Breathes."** The player feels two things from this system — one by arrival, one by absence.

**By arrival: the sepia dim during document reading.** When a document opens, the world softens into a sepia-warm photograph; the card alone keeps its color, and Eve's reading becomes the only event that matters. It is a **pause the player earns**, not a menu they escape to. (Pillar 3: *Stealth is Theatre* — the theatrical pause honors the act of patient observation the game rewards.)

**By absence: the quieter fantasy.** Nothing on screen ever feels like a 2020s game. No bloom halos on the pendant chandeliers. No lens flares from the Eiffel Tower's floodlights. No chromatic fringing at screen edges. The 1966 frame is preserved by what we refuse to render. (Pillar 5: *Period Authenticity Over Modernization* — forbidden modern effects are as important to the look as any chosen one.)

Players will not say *"the post-process stack is well-configured."* They will say *"reading a document feels like holding the page in your hands"* and *"this game looks like it was made in the 1960s."*

## Detailed Design

### Core Rules

1. **The post-process chain order is locked: Outline → Sepia Dim → Resolution Scale Composition.** Per ADR-0001 render order. Any future post-process addition MUST be inserted after Sepia Dim and before Resolution Scale, or it requires an ADR amendment. Inserting before Outline or between Outline and Sepia Dim is forbidden.

2. **Sepia Dim is off by default. It is enabled ONLY via `PostProcessStack.enable_sepia_dim()`.** When off, the pass is bypassed (zero shader cost). When on, the pass executes every frame with fixed parameters (Art Bible 2 Document Discovery):
   - Luminance multiplier: 0.30 (30% brightness of original)
   - Saturation multiplier: 0.25 (heavy desaturation)
   - Sepia tint: warm amber shift applied after desaturation
   - Transition duration on enable: 0.5 s (fade from original to sepia state)
   - Transition duration on disable: 0.5 s (fade from sepia back to original)
   Transitions use `Tween` on a `dim_intensity` uniform (0.0 = no effect, 1.0 = full sepia dim).

3. **The Sepia Dim effect does NOT dim the outline color.** The outline pass runs BEFORE sepia dim; the outlines are already drawn into the color buffer by the time sepia dim executes. The sepia dim multiplier affects the composite image including outlines, which darkens them proportionally — this is intended. The result: the document card (rendered after sepia dim on its own CanvasLayer) keeps full saturation, but the faintly-sepia world behind it retains its outline structure at reduced intensity.

4. **Glow is disabled project-wide in `WorldEnvironment`.** Every scene's `WorldEnvironment.glow_enabled = false`. Enforced by scene-load-time validation: if a scene loads with glow enabled, an assertion fails in debug, a log warning fires in release. Per Art Bible 8J item 7 — Godot 4.6 changed glow order to process before tonemapping, which would affect emissive materials (bomb device indicator lamps, Plaza street-lamp pools) unexpectedly.

5. **The `PostProcessStack` autoload owns the sepia dim state.** It exposes public methods `enable_sepia_dim()` and `disable_sepia_dim()`, holds the `is_sepia_active` boolean, and manages the `Tween` for transitions. It does NOT hold references to any other system. This matches the ADR-0004 `save-service-assembles-state` pattern — PostProcessStack is a service that owns its domain, not a service locator.

6. **Resolution scale is read from Settings & Accessibility at startup** and applied to the viewport via `Viewport.scaling_3d_scale`. Default: 1.0 on desktop GPU, 0.75 on Intel Iris Xe integrated graphics (detected via `RenderingServer.get_video_adapter_type()` or `get_video_adapter_name()` heuristic at startup). Setting is persisted in `user://settings.cfg` per ADR-0003 separation of settings from SaveGame. Changes at runtime apply immediately via `Viewport.scaling_3d_scale = new_value`.

7. **No additional post-process effects at MVP or Vertical Slice.** Explicitly forbidden (Art Bible anti-pillar, forbidden_pattern `modern_post_process_stack` to be registered): glow, bloom, chromatic aberration, screen-space reflections (SSR), motion blur, depth of field (DoF), vignette (except the sepia dim's natural luminance drop, which is not a vignette shader), film grain, color grading LUTs, tonemapping variants (keep default neutral).

8. **Tonemapping is set to the engine default** (neutral linear) on all `WorldEnvironment` nodes. The Saturated Pop visual identity uses flat unlit shading — no HDR values to map — so advanced tonemapping modes (AgX, Filmic, Reinhard) are not needed and would introduce color shifts that conflict with the art bible's explicit hex-value palette.

9. **Anti-pattern fences** (to be registered in `architecture.yaml`):
   - `modern_post_process_stack` — no glow/bloom/chromatic-aberration/SSR/motion-blur/DoF/vignette/grain effects added at any point. Exception requires ADR amendment.
   - `sepia_dim_as_default_on` — the sepia dim is NEVER active outside Document Overlay context. Never left on accidentally.
   - `direct_viewport_scaling_modification` — only Settings & Accessibility writes to the resolution_scale setting; PostProcessStack reads it via `setting_changed` signal subscription.

### States and Transitions

Post-Process Stack has one primary state dimension — sepia dim active/inactive — with transition states in between.

| State | Description | Conditions for entry | Cost |
|---|---|---|---|
| `IDLE` | Sepia Dim pass bypassed; only Outline + Resolution Scale run | Default; `is_sepia_active == false` | Zero shader cost for sepia pass |
| `FADING_IN` | Transitioning from IDLE to ACTIVE; `dim_intensity` tweens 0.0 → 1.0 over 0.5 s | Entered on `enable_sepia_dim()` call | Full sepia pass cost (~0.3 ms at 1080p) |
| `ACTIVE` | Sepia Dim fully applied; `dim_intensity = 1.0` | Entered when FADING_IN completes | Full sepia pass cost |
| `FADING_OUT` | Transitioning from ACTIVE to IDLE; `dim_intensity` tweens 1.0 → 0.0 over 0.5 s | Entered on `disable_sepia_dim()` call | Full sepia pass cost (still running until fully faded) |

**Transition rules:**
- Re-entry on partial transition: if `enable_sepia_dim()` is called during `FADING_OUT`, the Tween reverses toward ACTIVE from its current intermediate value (no teleport).
- Tween conflict: only one Tween instance manages `dim_intensity` at a time; previous Tweens are killed on state change.
- No skipping: states transition in strict order `IDLE ↔ FADING_IN ↔ ACTIVE ↔ FADING_OUT ↔ IDLE`. Cannot jump ACTIVE → IDLE without FADING_OUT.

### Interactions with Other Systems

| System | Direction | Interaction |
|---|---|---|
| **Outline Pipeline** (4) | upstream render-order | Outline Pipeline's `CompositorEffect` runs FIRST in the chain. Post-Process Stack's sepia-dim pass reads the post-outline color buffer. Must not modify the depth/stencil buffer. |
| **Document Overlay UI** (20) | direct API consumer | Calls `PostProcessStack.enable_sepia_dim()` on `open()`, `PostProcessStack.disable_sepia_dim()` on `close()`. Per ADR-0004 UI Framework lifecycle contract. |
| **Menu System** (21) | direct API consumer | May call `enable_sepia_dim()` during pause menu overlay if the Menu GDD specifies it (TBD — Menu GDD authoring decides). If used, same API. |
| **Cutscenes & Mission Cards** (22) | possible consumer | Cutscene-specific dim effects (e.g., fade-to-black at mission end) may use a separate mechanism; OR may call `enable_sepia_dim()` for narrative beats. Deferred to Cutscenes GDD. |
| **Settings & Accessibility** (23) | configuration source | Emits `setting_changed("graphics", "resolution_scale", value)`. PostProcessStack subscribes and applies via `Viewport.scaling_3d_scale`. Detection logic (hardware → default value) is owned by Settings, not here. |
| **Signal Bus** (1) | subscriber | PostProcessStack subscribes only to `setting_changed` for the resolution_scale key. Does NOT publish any signals of its own. |

**ADR-0004 lifecycle contract (hard requirement):**

```gdscript
# PostProcessStack autoload public API (owned by this GDD)
class_name PostProcessStackService extends Node

func enable_sepia_dim() -> void
func disable_sepia_dim() -> void
var is_sepia_active: bool  # read-only from outside

# Document Overlay calls:
func _on_document_opened(doc_id: StringName) -> void:
    PostProcessStack.enable_sepia_dim()
    _show_document_card(doc_id)

func _on_document_closed(doc_id: StringName) -> void:
    PostProcessStack.disable_sepia_dim()
    _hide_document_card()
```

**Hardware detection delegation:**
- Settings & Accessibility owns the detection: at startup, checks `RenderingServer.get_video_adapter_name()` against a known-integrated-graphics list (Intel Iris Xe, Intel UHD series, AMD Vega mobile, etc.) and sets `graphics.resolution_scale = 0.75` as the default for matched hardware, `1.0` otherwise.
- Settings then emits `setting_changed("graphics", "resolution_scale", value)`.
- PostProcessStack subscribes on startup, reads the initial value from Settings directly (one-shot), then responds to subsequent change signals.
- Player can override in Settings menu at any time.

## Formulas

### Formula 1 — Sepia dim color transformation

The sepia-dim shader applies three sequential operations per pixel: desaturation → sepia tint → luminance reduction. The `dim_intensity` uniform (0.0–1.0) controls the overall strength, allowing smooth fade-in/out.

`sepia_color = mix(original_color, apply_sepia_dim(original_color), dim_intensity)`

where `apply_sepia_dim(c) = luminance_mul * sepia_tint * desaturate(c)`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `original_color` | c | vec3 | [0.0, 1.0]³ | Input pixel color after outline pass |
| `dim_intensity` | d | float | 0.0 to 1.0 | 0 = no dim, 1 = full dim. Tweens during transition states |
| `luminance_mul` | L | float | 0.30 | Multiplier — 30% of original brightness |
| `sepia_tint` | T | vec3 | (1.10, 1.00, 0.75) | Warm amber shift — slight red/green boost, blue reduction |
| `saturation_mul` | S | float | 0.25 | Desaturation factor — 25% of original saturation |

**`desaturate()` helper:** `gray = dot(c, vec3(0.299, 0.587, 0.114)); c' = mix(vec3(gray), c, saturation_mul)` (standard luminance weights).

**Output range:** vec3 in [0.0, 1.0]³. At `dim_intensity = 0.0`, output equals input. At `dim_intensity = 1.0`, output is the full sepia-dim color.

**Example:** Input pixel color `(0.8, 0.5, 0.3)` (a warm amber from Restaurant pendant light). At full dim:
- `gray = 0.299*0.8 + 0.587*0.5 + 0.114*0.3 ≈ 0.568`
- After desaturate (S=0.25): `mix(0.568, 0.8, 0.25) = 0.626`, `mix(0.568, 0.5, 0.25) = 0.551`, `mix(0.568, 0.3, 0.25) = 0.501`
- After sepia tint × luminance: `(0.626 * 1.10 * 0.30, 0.551 * 1.00 * 0.30, 0.501 * 0.75 * 0.30) ≈ (0.207, 0.165, 0.113)`
- Result: a dark warm sepia value — substantially dimmer and warmer than original.

### Formula 2 — Dim intensity tween

`dim_intensity(t) = ease_in_out(t / transition_duration_s)` where `t` is elapsed time in the current state.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `t` | t | float | 0.0 to transition_duration_s | Elapsed time since state transition began |
| `transition_duration_s` | d | float | 0.5 | Locked at 0.5s (Tuning Knob) |
| `ease_in_out(x)` | — | float | 0.0 to 1.0 | Smoothstep easing: `x * x * (3 - 2 * x)` |

**Output:** `dim_intensity` value fed to Formula 1.

**Example:** At t=0.25s (halfway through), `x = 0.5`; `ease_in_out(0.5) = 0.5 * 0.5 * (3 - 1) = 0.5`. At t=0.5s, ease complete, `dim_intensity = 1.0` (entering ACTIVE).

### Formula 3 — Resolution-scaled pixel cost budget

`outline_effective_pixels = viewport_width * viewport_height * (resolution_scale ^ 2)`
`sepia_dim_effective_pixels = same` (applies to the scaled-down internal viewport)

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `viewport_width / height` | w, h | int | 1280–3840 | Output render target |
| `resolution_scale` | s | float | 0.5 to 1.0 | From Settings |
| `effective_pixels` | p | int | ~0.5M to 8.3M | Number of pixels the shader actually processes per frame |

**Output range:** at 1080p native (scale=1.0): ~2.07M pixels. At 1080p with scale=0.75: ~1.17M pixels (~43% reduction). At 4K native: ~8.3M pixels (unsupported target; out of scope).

**Example:** 1080p output with scale=0.75 → sepia dim pass processes 1440×810 = 1,166,400 pixels per frame. At ~0.3 ns/pixel on mid-range GPU, ~0.35 ms pass cost. Within budget.

### No balance values

Post-Process Stack has no XP curves, damage formulas, economic values, or tunable gameplay numbers. Formulas 1–3 are all rendering-internal.

## Edge Cases

- **If `enable_sepia_dim()` is called when already ACTIVE** → no-op. Internal state is already `ACTIVE`, dim_intensity is already 1.0. Returns silently. **Resolution**: intended idempotency.
- **If `disable_sepia_dim()` is called when already IDLE** → no-op. Same idempotency. **Resolution**: intended.
- **If `enable_sepia_dim()` is called during FADING_OUT** → the active Tween is killed; a new Tween starts from the current dim_intensity value back toward 1.0. No teleport. **Resolution**: intended. Reading a document immediately after closing a previous one never shows a jarring flash.
- **If `disable_sepia_dim()` is called during FADING_IN** → symmetric to above. Tween reverses from current value toward 0.0. **Resolution**: intended.
- **If a scene loads with `WorldEnvironment.glow_enabled = true`** → in debug build, assertion fails with a clear error message ("Glow is forbidden per Art Bible 8J / Post-Process Stack GDD"). In release build, a warning logs and glow is forcibly disabled at scene-ready time. **Resolution**: defense against accidental glow re-enablement during asset iteration.
- **If the Document Overlay is open during a scene transition (Mission Scripting `section_entered`)** → design question: does the sepia dim persist across the transition? Per ADR-0004 Document Overlay UI owns the lifecycle; if the overlay persists, sepia dim should persist. In practice the overlay should close before scene transitions. **Resolution**: document this expectation in Document Overlay UI GDD; this GDD's API is reentrant across scene loads (the autoload survives scene changes).
- **If the user changes resolution_scale setting mid-gameplay** → `setting_changed("graphics", "resolution_scale", new_value)` fires; `PostProcessStack` reads the new value and applies `Viewport.scaling_3d_scale = new_value` immediately. Next rendered frame uses the new scale. **Resolution**: intended; no transition blur (resolution-scale changes snap, consistent with other engine behaviors).
- **If the game launches on unrecognized integrated graphics hardware** → Settings & Accessibility's detection heuristic may miss a novel Intel/AMD integrated chip and default to `resolution_scale = 1.0`. **Resolution**: user can manually set via Settings menu. Warning logged in debug for telemetry purposes. Not a PostProcessStack concern — detection is Settings' responsibility.
- **If the sepia-dim shader fails to compile or load** → `PostProcessStack._ready()` logs an error and leaves `is_sepia_active` always-false (graceful degradation). Document Overlay still opens but without the dim effect. **Resolution**: document overlay remains usable; visual polish degrades but game does not crash. Shader compilation issues should be caught in Shader Baker (Godot 4.5+) at build time.
- **If the outline pass is somehow missing from the Compositor chain** (bug) → sepia dim still runs correctly, but outlines would be missing. The two passes are independent at the buffer level. **Resolution**: not a sepia-dim concern; Outline Pipeline GDD handles outline-missing edge cases.
- **If a future ADR amendment adds a new post-process effect** (e.g., a very specific narrative-driven fade-to-black) → it must be explicitly justified, ADR-approved, and inserted in the Compositor chain AFTER the sepia-dim pass and BEFORE the resolution-scale composition. **Resolution**: forbidden_pattern `modern_post_process_stack` is the gate; exceptions go through architecture review.
- **If a scene uses emissive materials (bomb device indicator lamps, Plaza street lamps)** → these materials glow visually (shader-side emissive), but with `WorldEnvironment.glow_enabled = false`, there is NO bloom halo around them. **Resolution**: intended. The Art Bible's flat unlit shading handles emissive-looking surfaces via hex color alone — no screen-space glow needed.
- **If tonemapping is changed in a future ADR** (e.g., AgX for a specific cutscene) → the current `WorldEnvironment.tonemap_mode = TONEMAP_LINEAR` default may be overridden per-scene via a scene-specific `WorldEnvironment`. Core Rule 8 explicitly forbids project-wide tonemap changes but doesn't preclude scene-specific. **Resolution**: documented as a possible cutscene mechanism; not in MVP scope.
- **If the engine upgrades post-MVP to a Godot version that changes `Viewport.scaling_3d_scale` API** → this would be a breaking change detected during engine upgrade. **Resolution**: covered by the `/setup-engine upgrade` workflow; no MVP concern.

## Dependencies

### Upstream dependencies

| System | Nature |
|---|---|
| Godot 4.6 `Compositor` + `CompositorEffect` (4.3+) | Hard engine dependency; stable, in training data |
| Godot 4.6 `WorldEnvironment` | Hard engine dependency; stable |
| Godot 4.6 `Viewport.scaling_3d_scale` | Hard engine dependency; stable |
| **Signal Bus** (system 1, ADR-0002) | Soft dependency — subscribes to `setting_changed` for resolution_scale only |

### Downstream dependents

| System | Nature |
|---|---|
| **Outline Pipeline** (4) | Render-order dependency — outline pass runs FIRST in the Compositor chain per ADR-0001. Post-Process Stack respects this ordering. |
| **Document Overlay UI** (20) | Direct API consumer — calls `enable_sepia_dim()` / `disable_sepia_dim()` per ADR-0004 lifecycle contract. |
| **Menu System** (21) | Potential API consumer — if pause-menu overlay uses sepia dim, same API. Deferred to Menu GDD. |
| **Cutscenes & Mission Cards** (22) | Potential API consumer — narrative dim beats may use same API. Deferred to Cutscenes GDD. |
| **Settings & Accessibility** (23) | Configuration source — owns `resolution_scale` detection and emits `setting_changed` on change. |

### No direct interaction

- **ADR-0001 Stencil ID Contract**: independent at the API level, but share the Compositor chain render order. No shared code.
- **Audio**: sepia-dim has no audio cue owned here. Audio GDD owns any audio-side reactions to `document_opened` / `document_closed` events.
- **Save/Load**: post-process state is ephemeral per-frame; not persisted.
- **Input**: no interaction.
- **Combat, Stealth AI, Mission Scripting, etc.**: no interaction. Post-process is strictly a rendering service.

## Tuning Knobs

### Sepia Dim parameters

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| `sepia_dim_luminance_mul` | 0.30 | 0.15–0.50 | Output brightness as fraction of input. Lower = darker; higher = less of a "pause" feel |
| `sepia_dim_saturation_mul` | 0.25 | 0.10–0.50 | Saturation retained. Lower = more grayscale; higher = less desaturated |
| `sepia_dim_tint` | `(1.10, 1.00, 0.75)` | R/G/B each 0.7–1.3 | Warm sepia tint. More red+green, less blue. Adjust for different period-tint mood |
| `sepia_dim_transition_duration_s` | 0.5 | 0.2–1.0 | Tween duration for fade-in and fade-out. Shorter = snappier; longer = more "theatrical pause" |
| `sepia_dim_transition_curve` | `ease_in_out` | `linear` / `ease_in` / `ease_in_out` / `ease_out` | Easing for the fade Tween. Locked to `ease_in_out` at MVP per Art Bible feel targets |

### Resolution scale

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| `resolution_scale_desktop` | 1.0 | 0.75–1.0 | Desktop GPU default. Lower trades quality for headroom |
| `resolution_scale_integrated` | 0.75 | 0.5–0.9 | Iris Xe / integrated graphics default. Locked to 0.75 per Art Bible 8J and Outline Pipeline alignment |
| `resolution_scale_user_override` | (inherits default) | 0.5–1.0 | Player-exposed override in Settings |

### Glow / ban enforcement

| Parameter | Default | Safe Range | Effect |
|---|---|---|---|
| `glow_enforcement_mode` | `assert_in_debug_warn_in_release` | `off` / `warn` / `assert` | Scene-load-time validation that `WorldEnvironment.glow_enabled == false`. Locked; changing requires ADR amendment |
| `tonemap_mode_enforcement` | locked neutral (default) | Locked | No per-project tonemap changes without ADR amendment |

### NOT owned by this GDD

- Hardware-detection heuristic (Intel Iris Xe / UHD / etc. → resolution_scale=0.75) → owned by Settings & Accessibility
- Document Overlay open/close lifecycle → owned by Document Overlay UI GDD
- Outline tier values or outline shader parameters → owned by Outline Pipeline + ADR-0001
- Per-scene `WorldEnvironment` ambient color / fog → owned by each scene author / Level Streaming

## Visual/Audio Requirements

**Visual:**
- **Sepia-dim shader** (one `CompositorEffect` with GLSL shader, ~40 lines). Authored per Formula 1. Uniforms: `dim_intensity` (float, 0.0–1.0), `luminance_mul` (float), `saturation_mul` (float), `sepia_tint` (vec3). Defaults per Tuning Knobs. The shader samples the current color buffer and writes the desaturated+tinted+dimmed result.
- **Reference screenshots** (for QA): rendered comparisons of the Restaurant section at `dim_intensity = 0.0` vs `0.5` vs `1.0` at 1080p native resolution. Generated during Tier 0 prototype.

**Audio:**
- **None owned here.** Document Overlay open/close SFX (paper rustle, pen-cap tock per Art Bible 7D) are owned by Audio GDD, triggered by subscribing to `Events.document_opened` / `Events.document_closed`.
- The sepia-dim transition has no audio cue — the Art Bible specifies visual register shift only.

> 📌 **Asset Spec** — Visual requirements are defined. After the art bible is approved, run `/asset-spec system:post-process-stack` to produce per-reference-screenshot specs (comparison renders at different dim intensities, at each of the 5 sections, at different resolution_scale values for QA regression testing).

## UI Requirements

**None owned by Post-Process Stack.** Settings & Accessibility exposes the user-facing `resolution_scale` slider in its graphics options menu (owned by Settings GDD, not here). Post-Process Stack provides only the API surface: subscribes to `Events.setting_changed("graphics", "resolution_scale", value)` and applies via `Viewport.scaling_3d_scale`.

No in-game UI displays sepia-dim state, post-process chain contents, or any internal rendering data. The player sees the sepia dim as a world effect (triggered by Document Overlay), never as a UI element.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| UI Framework lifecycle contract | `docs/architecture/adr-0004-ui-framework.md` | `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` API | Hard API contract — must be provided |
| Outline Pipeline render order | `docs/architecture/adr-0001-stencil-id-contract.md` | Outline pass runs BEFORE post-process | Rule dependency |
| Document Overlay sepia spec | `design/art/art-bible.md` Section 2 (Document Discovery) | ~30% opacity, desaturated sepia register | Visual direction — literal values drive Formula 1 |
| Glow disable mandate | `design/art/art-bible.md` Section 8J item 7 | Glow processes before tonemap in 4.6; disable in all WorldEnvironments | Rule dependency |
| Resolution scale rationale | `design/art/art-bible.md` Section 8F | 0.75 default on integrated graphics; outline pass budget ≤2ms | Performance budget source |
| Outline pipeline GDD | `design/gdd/outline-pipeline.md` | Compositor chain order + resolution_scale formula | Shared constraint |
| Signal Bus subscription | `design/gdd/signal-bus.md` + `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | `setting_changed` event subscription | Data dependency |
| Settings & Accessibility ownership | `design/gdd/systems-index.md` (system 23) | Hardware detection + resolution_scale persistence | Scope boundary |

## Acceptance Criteria

### API and lifecycle

1. **GIVEN** `PostProcessStack` autoload is loaded, **WHEN** `enable_sepia_dim()` is called, **THEN** state transitions to `FADING_IN`, Tween begins, and after 0.5s state is `ACTIVE` with `dim_intensity = 1.0`.
2. **GIVEN** state is `ACTIVE`, **WHEN** `disable_sepia_dim()` is called, **THEN** state transitions to `FADING_OUT`, and after 0.5s state is `IDLE` with `dim_intensity = 0.0`.
3. **GIVEN** state is `FADING_IN` at t=0.2s (intensity ≈ 0.35), **WHEN** `disable_sepia_dim()` is called, **THEN** the Tween reverses from the current intensity value toward 0.0 (no teleport to 1.0 first).
4. **GIVEN** state is `IDLE`, **WHEN** `disable_sepia_dim()` is called, **THEN** no-op; state remains `IDLE`; no Tween fires.
5. **GIVEN** state is `ACTIVE`, **WHEN** `enable_sepia_dim()` is called, **THEN** no-op; state remains `ACTIVE`.

### Document Overlay integration

6. **GIVEN** Document Overlay UI is closed (state: no overlay), **WHEN** the player triggers `interact` on a document, **THEN** `PostProcessStack.enable_sepia_dim()` is called (part of Document Overlay's open lifecycle).
7. **GIVEN** Document Overlay is open and sepia is ACTIVE, **WHEN** the player dismisses the overlay (Esc, B/Circle, etc.), **THEN** `PostProcessStack.disable_sepia_dim()` is called (part of Document Overlay's close lifecycle).
8. **GIVEN** sepia dim is ACTIVE, **WHEN** the Document Overlay card renders on its `CanvasLayer`, **THEN** the card displays at full saturation (sepia dim does NOT affect it) while the world behind is dimmed.

### Glow / post-process ban enforcement

9. **GIVEN** any scene loads, **WHEN** its `WorldEnvironment.glow_enabled` is inspected, **THEN** the value is `false`. In debug build, if true, an assertion fails at scene-ready time. In release, a warning logs and glow is forcibly disabled.
10. **GIVEN** the project's WorldEnvironment configs across all sections, **WHEN** audited, **THEN** no WorldEnvironment enables `bloom`, `chromatic_aberration`, `screen_space_reflections`, `motion_blur`, or any other forbidden post-process effect per Core Rule 7.
11. **GIVEN** any `WorldEnvironment` in the project, **WHEN** `tonemap_mode` is read, **THEN** it is the engine default (neutral linear). No AgX, Filmic, Reinhard variants.

### Resolution scale

12. **GIVEN** the game launches on RTX 2060-class hardware, **WHEN** initial resolution_scale is applied, **THEN** `Viewport.scaling_3d_scale = 1.0`.
13. **GIVEN** the game launches on Intel Iris Xe, **WHEN** initial resolution_scale is applied, **THEN** `Viewport.scaling_3d_scale = 0.75` (or whatever Settings detected).
14. **GIVEN** the player manually changes resolution_scale via Settings menu, **WHEN** the setting is applied, **THEN** `Events.setting_changed("graphics", "resolution_scale", new_value)` fires, PostProcessStack reads it, and `Viewport.scaling_3d_scale = new_value` immediately. Next frame uses the new scale.

### Visual correctness (playtest checks)

15. **GIVEN** the Restaurant section with chandeliers at full brightness, **WHEN** sepia dim is `ACTIVE`, **THEN** the scene appears warm-sepia at approximately 30% luminance, with outlines visible but dimmed proportionally — no outline artifacts, no banding, no color shift anomalies.
16. **GIVEN** the Bomb Chamber with cool fluorescent strip + red PHANTOM indicator lamps, **WHEN** sepia dim is `ACTIVE`, **THEN** the red lamps appear warm-amber under the sepia tint (they retain their emissive intensity relatively but colored per Formula 1).
17. **GIVEN** any scene and sepia `IDLE`, **WHEN** the player looks at an emissive material (bomb device lamp, Plaza street lamp), **THEN** NO bloom halo is visible around the emissive surface. The surface is bright per its albedo, but does not bleed into surrounding pixels.

### Performance

18. **GIVEN** the sepia-dim pass is `ACTIVE` on a RTX 2060 at 1080p native, **WHEN** profiled, **THEN** the pass completes in ≤0.5 ms (target: 0.2–0.4 ms).
19. **GIVEN** the sepia-dim pass is `IDLE`, **WHEN** profiled, **THEN** the pass contributes effectively 0 ms (bypassed; only a single no-op check).
20. **GIVEN** resolution_scale = 0.75 on Iris Xe, **WHEN** the full post-process chain (outline + sepia dim + resolution composition) runs at 1080p output, **THEN** total post-process cost is ≤2.5 ms (outline ≤2.0 ms + sepia dim ≤0.3 ms + composition ≤0.2 ms).

### Anti-pattern enforcement

21. **GIVEN** any GDScript file in the project, **WHEN** grepped for direct `Viewport.scaling_3d_scale` modifications outside of `PostProcessStack` and `Settings & Accessibility`, **THEN** zero matches. *Classification: lint check.*
22. **GIVEN** any GDScript file, **WHEN** grepped for `glow_enabled = true`, **THEN** zero matches in project source code (test files may enable glow for Godot-behavior tests only). *Classification: lint check.*
23. **GIVEN** any PR that modifies `PostProcessStack.gd`, **WHEN** code-reviewed, **THEN** no new public methods are added that query or act on other systems (service-locator anti-pattern). *Classification: code-review checkpoint.*

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Should Menu System's pause overlay use the same sepia dim as Document Overlay, or a different visual register? | Menu System GDD author + art-director | During Menu System GDD authoring | Recommendation: use sepia dim for consistency (same API call). Alternative would be a straight neutral dim without the sepia tint. Menu GDD decides. |
| Should Cutscenes use the sepia dim for any specific narrative beats (e.g., flashbacks)? | Cutscenes GDD author + narrative-director | During Cutscenes GDD authoring | If yes, use existing API; if a different cutscene-specific effect is needed, propose it via ADR. |
| What exactly is the WorldEnvironment tonemapping mode? (Linear vs None vs default) | technical-artist | Before implementation | Current draft says "engine default (neutral linear)." Verify exact Godot 4.6 default; may need per-section WorldEnvironment overrides if scenes have different lighting characters (though this GDD locks project-wide neutral). |
| Are there edge cases where resolution_scale = 0.5 is needed (very-low-end hardware beyond Iris Xe)? | performance-analyst | During Tier 0 prototype testing | Hardware below Iris Xe is out of MVP scope per technical-preferences.md (min-spec is Iris Xe). If sales data post-launch shows a hardware gap, consider adding 0.5 as an emergency fallback. |
| Does the sepia dim need per-section customization (e.g., brighter in the Bomb Chamber since it's already dark)? | art-director + technical-artist | After Tier 0 playtest | Current design uses project-wide fixed parameters. If playtest shows sepia dim in the Bomb Chamber feels too dark (since the chamber is already dim), consider exposing `sepia_dim_luminance_mul` as a per-section tuning value. Not in MVP scope. |
| Shader Baker (Godot 4.5+) — should sepia dim shader be baked? | technical-artist | Before release build | Recommendation: yes. Shader Baker pre-compiles `CompositorEffect` shaders to prevent first-use compile stutter. Sepia dim is used on every document pickup; first-use stutter would be visible. |
