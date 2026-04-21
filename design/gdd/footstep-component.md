# Footstep Component

> **Status**: In Design — Session F sibling doc + /design-review revision pass (2026-04-21)
> **Author**: User + `/design-system` skill + specialists (audio-director, gameplay-programmer, game-designer)
> **Last Updated**: 2026-04-21
> **Last Verified**: 2026-04-21
> **Implements Pillar**: 5 (Period Authenticity — surface-specific footstep audio anchors the 1965 setting); 3 (Stealth is Theatre — supports, does NOT duplicate, the Stealth AI perception lane)
> **Parent system**: [Player Character](player-character.md)

## Summary

FootstepComponent is a child node of PlayerCharacter that emits the `player_footstep(surface: StringName, noise_radius_m: float)` signal each step, drives the Audio system's surface-aware SFX selection, and updates Eve's visible-foot footfall timing. **This component does NOT mutate PlayerCharacter's `_latched_event` or influence `get_noise_level()` / `get_noise_event()`** — Stealth AI reads those PC-owned methods directly, never through this signal. The Audio lane and AI-perception lane are physically separated at the component boundary (Session F — resolves R-19 from 3rd `/design-review`).

> **Quick reference** — Layer: `Core` (sibling of PlayerCharacter) · Priority: `MVP` · Effort: `S` · Key deps: `PlayerCharacter, Audio, ADR-0002, ADR-0006`

## Overview

FootstepComponent exists because two consumers — Audio SFX and Stealth AI perception — would otherwise both reach into PlayerCharacter for footfall data, tangling their concerns. The 3rd `/design-review` flagged that the prior design (FootstepComponent owning BOTH `player_footstep` emission AND `get_noise_level()` scalar updates) creates a single failure point: a bug in the audio-cadence code silently breaks AI perception. Session F splits the two lanes:

- **PlayerCharacter owns `get_noise_level()` and `get_noise_event()`** — the Stealth AI perception contract. Computed purely from `current_state` + `velocity` + tunable noise knobs. FootstepComponent does not participate.
- **FootstepComponent owns `player_footstep` emission + step cadence** — the Audio lane. Reads `player.current_state` + `player.velocity` + a downward ground raycast. Does not mutate player state.

The `noise_radius_m` field in `player_footstep` is the Audio SFX-variant loudness cue (soft vs normal vs loud stem within a surface set), not an AI-perception channel. Stealth AI code subscribing to `player_footstep` would bypass the pull contract and create a duplicate perception path — explicitly forbidden (see Player Character GDD → Forbidden Patterns).

**This GDD defines**: step-cadence timing, surface detection, signal emission contract, surface tag set, cadence tuning knobs.
**This GDD does NOT define**: the surface→SFX file mapping (Audio GDD §Footstep Surface Map), surface-metadata authoring workflow (see Level Streaming GDD when authored, OQ-FC-1), Stealth AI perception math (Stealth AI GDD), or PlayerCharacter's noise-level interface (Player Character GDD §F.4).

## Player Fantasy

Footsteps are how **period authenticity** becomes audible. When Eve crosses from marble foyer to wood cabaret stage to metal grate, the sound shifts in a way that anchors *where* she is without any UI text or objective marker. 1965 espionage lives in the material detail: stiletto heels on marble ≠ stiletto heels on carpet. No modern game conveniences (zero-sound crouch, magic silent boots) — Eve's footsteps honestly expose her to the world, and the player learns to read surfaces as a tactical input.

**Feel:**
- Each footfall is a small diegetic moment — loud enough to register, quiet enough to never mask dialogue.
- Cadence scales with movement state: sprint steps are tighter, crouch steps are widely spaced.
- Crossing a threshold (marble → carpet) produces an audible texture change on the very next step — not a crossfade.
- No "swoosh" whiff SFX, no cartoonish thud. Every step is recorded Foley of actual 1965-era footwear on actual 1965-era surfaces.

**Pillar 3** (Stealth is Theatre) is served *kinesthetically* here: a player reading surface audio can make tactical choices ("the guard just walked off the marble onto carpet — I lost my audio cue on his position"). But note — in this GDD's scope, the player is Eve; the same mechanic applies to guards in Stealth AI's scope.

## Detailed Design

### Core Rules

**Node placement.** FootstepComponent is a Node child of `PlayerCharacter` (not attached to the hands SubViewport, not attached to the Camera). It is instantiated in the PlayerCharacter scene at `_ready()` and persists for the player's lifetime.

**What it reads** (all from the parent PlayerCharacter — no mutation):
- `player.current_state: PlayerEnums.MovementState`
- `player.velocity: Vector3`
- `player.global_transform.origin: Vector3` (for the ground raycast origin)
- `player.is_on_floor() -> bool` (suppresses footfalls during Jump/Fall)

**What it emits**: `Events.player_footstep(surface: StringName, noise_radius_m: float)` per step.

**What it does NOT do** (enforced by Forbidden Patterns — see below):
- Does NOT mutate `player.health`, `player.current_state`, `player.velocity`, or `player._latched_event`.
- Does NOT call `player.apply_damage()` or any other PlayerCharacter mutation method.
- Does NOT participate in Stealth AI perception — `get_noise_level()` / `get_noise_event()` on PlayerCharacter are the authoritative AI channels.
- Does NOT subscribe to any Events signal — it is purely a publisher.

### Step Cadence

Cadence is state-keyed and constant per state (no velocity-scaled interpolation at MVP — keeps the contract testable and the audio author's stem count finite). Cadence is expressed in Hz; the per-step interval is `1 / cadence_hz`.

| State | Cadence (Hz) | Interval (s) | Rationale |
|---|---|---|---|
| Walk | 2.2 | 0.455 | Calm confident pace matches Eve's `walk_speed = 3.5 m/s` — stride ~1.6 m. |
| Sprint | 3.0 | 0.333 | Faster cadence; `sprint_speed = 5.5 m/s` → stride ~1.83 m. Slightly longer stride than Walk (realistic at accelerated pace). |
| Crouch | 1.6 | 0.625 | Slow deliberate steps; `crouch_speed = 1.8 m/s` → stride ~1.12 m. |
| Idle / Idle-still / Walk-still / Crouch-still | — | — | No footfalls emitted. |
| Jump / Fall | — | — | No footfalls emitted. Landing is handled by PlayerCharacter's latched-event path (F.3), not FootstepComponent. |
| Dead | — | — | Emission suppressed. |

"Still" means `player.velocity.length() < player.idle_velocity_threshold` — same threshold PlayerCharacter uses for the Idle-silent override in F.4.

The first step after entering a moving state fires one `interval` after the state transition (not on the transition frame itself — rationale: players learn the "Eve just started moving" audio pattern by the rhythm, and a transition-frame step reads as popcorn-y in rapid Walk→Sprint→Walk sequences).

### Surface Detection

**How**: a downward `PhysicsRayQueryParameters3D` from `player.global_transform.origin - Vector3(0, 0.05, 0)` (just below the capsule center to avoid the capsule's own hit) to `player.global_transform.origin - Vector3(0, 2.0, 0)` (2 m deep — covers stairs + slopes). Layer mask: `PhysicsLayers.MASK_FOOTSTEP_SURFACE` per ADR-0006 (which resolves to `LAYER_WORLD`).

**What it reads**: the hit body's `surface_tag` metadata. If the body exposes `surface_tag` as a `StringName` property (or `get_meta("surface_tag")`), that value is the surface tag. If no body is hit, the surface tag defaults to `&"default"` and Audio falls back to the generic footstep stem.

**When**: once per step interval — NOT every physics frame. The component tracks a `_step_accumulator` that increments by `Δt_clamped` each frame (using the same `min(Δt, 1/30)` clamp pattern as PlayerCharacter F.1/F.2 to prevent hitch-fabricated extra steps) and fires the signal when the accumulator exceeds `interval`. Accumulator resets to `accumulator - interval` (not zero) to preserve cadence phase across state changes.

**Caching**: the last-resolved surface tag is cached for the duration of that step. If the player crosses a surface boundary mid-step, the NEXT step picks up the new surface tag — no blending, no crossfade.

### Surface Tag Set (authoritative list)

| Tag | Level context | Audio notes (spec in Audio GDD) |
|---|---|---|
| `&"marble"` | Plaza floor | Crisp heel-clack, long reverb tail |
| `&"tile"` | Restaurant kitchen | Ceramic click; high-frequency content |
| `&"wood_stage"` | Cabaret floor | Hollow resonance, midrange thump |
| `&"carpet"` | Office Suite, cinema-floor corridors | Muffled, very short tail |
| `&"metal_grate"` | Observation Deck service ladders | Ring + rattle; distinctive |
| `&"gravel"` | Plaza outdoor, Tier 2 Rome | Crunch, noise-floor elevated |
| `&"water_puddle"` | Rare; mission-script spawned | Splash + squelch; one-shot (does not loop cadence) |
| `&"default"` | Fallback (missing surface_tag metadata) | Generic scuff; flagged in dev console |

Adding a new surface = append to this table + deliver the Foley stem set to the Audio GDD's Footstep Surface Map + set `surface_tag` metadata on the relevant mesh bodies. The tag is a `StringName` (not a raw `String`) for interning — 7 tags × ~1k footsteps per mission = 7k comparisons; interned StringName equality is O(1) pointer-compare vs String character-compare.

### Noise radius passed to Audio

`noise_radius_m` in the `player_footstep` signal is sourced from `player.get_noise_level()` at the moment of emission. This is **deliberate mirroring, not a coupling**: Audio uses the value to pick the SFX variant (soft / normal / loud stem) within the surface set. If a designer retunes `noise_walk` from 5.0 to 6.0, both Stealth AI's perception scalar AND Audio's stem selection move together — which is what a designer tuning "Eve's footsteps are too quiet for AI" actually means.

**Why this is not an AI channel violation**: FootstepComponent calls `player.get_noise_level()` (a PlayerCharacter-owned method) — it does NOT implement its own noise calculation. If the PC-side formula changes, FootstepComponent's emission automatically reflects it. No duplicate formula exists. Stealth AI still reads `get_noise_level()` / `get_noise_event()` directly — it does not subscribe to `player_footstep`.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **PlayerCharacter** | reads (no mutation) | `current_state`, `velocity`, `global_transform.origin`, `is_on_floor()`, `get_noise_level()`, `idle_velocity_threshold`. Never writes. |
| **Signal Bus** | publishes | `player_footstep(surface: StringName, noise_radius_m: float)` — Audio-only channel per ADR-0002 Player domain (added 2026-04-19). |
| **Audio** | consumer | Subscribes to `Events.player_footstep`, reads surface→SFX map, plays the appropriate stem variant based on `noise_radius_m`. Audio GDD §Footstep Surface Map owns the mapping. |
| **Level Streaming / World geometry** | reads metadata | `surface_tag` metadata on collision bodies; placed by level designers during content authoring. See OQ-FC-1 for the Level Streaming handoff. |
| **Stealth AI** | NOT a consumer | Stealth AI is EXPLICITLY forbidden from subscribing to `player_footstep` (see Player Character GDD → Forbidden Patterns). AI perception reads PlayerCharacter's `get_noise_level()` / `get_noise_event()` directly. |

## Formulas

### Variables

- `player.velocity` — current velocity vector (m/s, read from PlayerCharacter)
- `player.current_state` — `PlayerEnums.MovementState` enum
- `player.idle_velocity_threshold` — threshold for "still" (default 0.1 m/s)
- `Δt` — physics frame delta (s)
- `Δt_clamped` = `min(Δt, 1.0 / 30.0)` — hitch guard (matches PlayerCharacter pattern)
- `_step_accumulator` — seconds-since-last-step accumulator
- `CADENCE_BY_STATE` — `const` dictionary rebuilt once at `_ready()` from cadence knobs:
  `{ WALK: 1.0 / cadence_walk_hz, SPRINT: 1.0 / cadence_sprint_hz, CROUCH: 1.0 / cadence_crouch_hz }`

### FC.1 Step cadence (per-frame)

```gdscript
func _physics_process(delta: float) -> void:
    if not _is_emitting_state(player.current_state):
        _step_accumulator = 0.0
        return
    if not player.is_on_floor():
        return
    if player.velocity.length() < player.idle_velocity_threshold:
        return
    var interval: float = CADENCE_BY_STATE[player.current_state]
    var delta_clamped: float = min(delta, 1.0 / 30.0)
    _step_accumulator += delta_clamped
    if _step_accumulator >= interval:
        _step_accumulator -= interval   # preserve cadence phase
        _emit_footstep()

func _is_emitting_state(state: PlayerEnums.MovementState) -> bool:
    return (state == PlayerEnums.MovementState.WALK
            or state == PlayerEnums.MovementState.SPRINT
            or state == PlayerEnums.MovementState.CROUCH)
```

**Rationale for `_step_accumulator -= interval` (vs `= 0`)**: preserves sub-interval overshoot across state changes. If Walk accumulates 0.46 s (just past the 0.455 s interval) and the next frame is also Walk, the carry-over 0.005 s keeps cadence stable. Zeroing would cause perceptible drift in rapid direction changes.

**Why suppress on `is_on_floor() == false`**: mid-air footsteps are uncanny. PlayerCharacter's latched-event path (F.3) handles takeoff + landing audibility for AI; FootstepComponent handles the walked-on audibility for Audio. They do not overlap.

**Why reset on state-exit**: entering Idle / Jump / Fall / Dead clears the accumulator so the next entry into a moving state waits one full interval before firing. Prevents popcorn-y re-entry.

**Example** (Walk at default `cadence_walk_hz = 2.2`, `delta = 1/60`):
- Interval = `1 / 2.2 ≈ 0.4545 s`
- Frames per interval = `0.4545 × 60 ≈ 27 frames`
- First step fires ~27 frames after entering Walk state. ✓

### FC.2 Surface resolution (per-step)

```gdscript
func _resolve_surface_tag() -> StringName:
    var space_state := player.get_world_3d().direct_space_state
    var origin: Vector3 = player.global_transform.origin - Vector3(0.0, 0.05, 0.0)
    var target: Vector3 = player.global_transform.origin - Vector3(0.0, 2.0, 0.0)
    var query := PhysicsRayQueryParameters3D.create(origin, target)
    query.collision_mask = PhysicsLayers.MASK_FOOTSTEP_SURFACE
    # Exclude the player's own collider to guarantee we hit ground, not self
    query.exclude = [player.get_rid()]
    var hit: Dictionary = space_state.intersect_ray(query)
    if hit.is_empty():
        return &"default"
    var body: Object = hit.collider
    if body.has_meta("surface_tag"):
        return body.get_meta("surface_tag") as StringName
    return &"default"
```

Called once per footstep emission — NOT per physics frame. Cost: one ray query + one meta lookup per step = ~6 queries per second at Sprint cadence. Well under Jolt's spatial query budget.

### FC.3 Emission

```gdscript
func _emit_footstep() -> void:
    var surface: StringName = _resolve_surface_tag()
    var noise_radius: float = player.get_noise_level()   # mirrors AI perception channel
    Events.player_footstep.emit(surface, noise_radius)
```

The signal is emitted through the `Events` autoload (ADR-0002). No direct node-to-node connections.

## Edge Cases

### FC.E.1 State change mid-step

**Situation**: player presses Shift (Walk → Sprint) mid-interval.
**Handling**: the accumulator carries over, but the interval threshold is now Sprint's (0.333 s vs Walk's 0.455 s). If the accumulator already exceeds the new interval, a step fires on the next frame — which is the correct behaviour (Eve's leg was already lifting; the tempo shift catches up). If it does not, the next step fires when the accumulator reaches the new (shorter) interval.

### FC.E.2 State changes to Idle (player stops)

**Situation**: player releases movement input.
**Handling**: PlayerCharacter transitions to Idle → `_is_emitting_state` returns false → accumulator resets to 0.0. No trailing footstep fires after stop.

### FC.E.3 Walk-still / Crouch-still (input held but velocity below threshold)

**Situation**: player walks into a wall; `current_state == WALK` but `velocity.length() == 0`.
**Handling**: the `velocity.length() < idle_velocity_threshold` guard suppresses emission. Matches PlayerCharacter's F.4 Idle-silent override — the two systems agree that "not actually moving" means silent.

### FC.E.4 Jump takeoff mid-step

**Situation**: player presses Space just as `_step_accumulator` reaches `interval`.
**Handling**: the `_physics_process` check runs BEFORE PlayerCharacter's jump code in the same frame (child-before-parent node order). If the state is still WALK/SPRINT/CROUCH at this FC tick, one step may fire, then PC transitions to JUMP. On the next frame, `_is_emitting_state(JUMP) == false` and the accumulator resets. Acceptable — one extra Walk step at jump initiation is not a bug, it mirrors the real foot leaving the ground.

**Coyote-window interaction (godot-specialist nit N-2):** during the PC coyote window (`can_jump == true` for `coyote_time_frames` after `is_on_floor()` last returned true), `player.is_on_floor()` may briefly return false while `current_state` is still a ground state. FC.1's `not player.is_on_floor()` early-return skips emission without resetting the accumulator — accumulated time carries into the next on-floor frame. This is intentional: if the coyote window closes and Eve lands back on floor within a tick, the preserved accumulator keeps cadence phase correct. If coyote expires to FALL, the state-exit path resets the accumulator via `_is_emitting_state` returning false.

Alternative if the Walk-step-at-takeoff popcorn is perceptible in playtest: reorder to resolve PlayerCharacter state first and sample after — this is a polish-phase decision, not a correctness issue. Flagged as a candidate playtest-tuning item in OQ-FC-3.

### FC.E.5 Ground raycast hits nothing (no `surface_tag` metadata)

**Situation**: level geometry is authored without `surface_tag` metadata, or the raycast hits an edge case (e.g., Eve standing over a 2 m gap).
**Handling**: `_resolve_surface_tag()` returns `&"default"`. Audio plays the generic footstep stem. A one-time `push_warning("footstep surface not tagged at %s" % origin)` fires in dev builds to surface content gaps. Warning is throttled to once per (surface_tag, mission-load) pair so it does not spam the console.

Content review is responsible for eliminating `&"default"` hits before ship — level designers see the warning during playtest.

### FC.E.6 Player enters a SceneTree subtree without `PlayerCharacter` parent

**Situation**: someone attaches FootstepComponent to a node that isn't a PlayerCharacter (debug tool, prototype reuse, future extension).
**Handling**: `_ready()` asserts `get_parent() is PlayerCharacter`; if not, emits `push_error("FootstepComponent must be a direct child of PlayerCharacter")` and sets an `_is_disabled` flag that suppresses all emission. Fails loud at init, silent at runtime — no null-deref cascade.

### FC.E.7 `player_footstep` consumed by Stealth AI code (violation)

**Situation**: an AI engineer connects a guard's `_on_footstep_heard` handler to `Events.player_footstep`.
**Handling**: runtime behaviour is unchanged (the signal fires regardless of subscriber identity), but this is a Forbidden Pattern at code review — enforced by CI lint `AI.*Events\.player_footstep\.connect`. See Player Character GDD → Forbidden Patterns.

### FC.E.8 Water puddle one-shot (`water_puddle`)

**Situation**: Eve steps on a `water_puddle` trigger (one-shot surface).
**Handling**: emission fires normally; Audio GDD plays the splash one-shot. FootstepComponent does NOT track "puddle state" — if the puddle is gone on the next step (mission-script destroyed it), the surface raycast returns whatever is underneath. Idempotent and stateless at this layer.

## Dependencies

### Upstream (must exist first)

| System | GDD | Why |
|---|---|---|
| Player Character | `design/gdd/player-character.md` ✅ | Parent node; reads state + velocity + noise level from it |
| Signal Bus | `design/gdd/signal-bus.md` ✅ | `player_footstep` signal contract (ADR-0002 Player domain) |
| Audio | `design/gdd/audio.md` ✅ | Consumer of the signal; owns surface→SFX map |
| ADR-0002 | Signal Bus + Event Taxonomy | `player_footstep` signature; no-per-frame-signal rule (footsteps fire ≤ 3 Hz, well under the 30 Hz cap) |
| ADR-0006 | Collision Layer Contract | `MASK_FOOTSTEP_SURFACE` constant |

### Downstream (consumers)

| System | GDD | What they consume |
|---|---|---|
| Audio | `design/gdd/audio.md` ✅ | `Events.player_footstep(surface, noise_radius_m)`; plays surface-specific stem variant. |
| (Stealth AI — EXPLICITLY FORBIDDEN) | `stealth-ai.md` ⏳ | Must NOT subscribe. Reads PlayerCharacter's `get_noise_level()` / `get_noise_event()` instead. |

### Bidirectional dependency statements

- **Player Character** must document: "hosts FootstepComponent as a child node; FootstepComponent reads `current_state`, `velocity`, `global_transform.origin`, `is_on_floor()`, `get_noise_level()`, `idle_velocity_threshold` from it; does NOT mutate any player state; does NOT influence `get_noise_level()` return values (FootstepComponent is the caller, not the source)."
- **Audio** must document: "subscribes to `Events.player_footstep(surface: StringName, noise_radius_m: float)`; owns surface→SFX map in §Footstep Surface Map; uses `noise_radius_m` to pick soft/normal/loud stem variant."
- **Stealth AI** must document: "does NOT subscribe to `player_footstep`; reads `player.get_noise_level()` and `player.get_noise_event()` directly per PC GDD F.4 contract."

### Dependency risk notes

- **Surface metadata coverage** (content risk): every level mesh on `LAYER_WORLD` that Eve can stand on MUST carry a `surface_tag` meta key. A missing tag falls back to `&"default"` and trips a dev warning. Level-design QA must sweep before each level ships — tracked in OQ-FC-1 as the authoring workflow question.
- **Cadence stability under frame hitch**: the `Δt_clamped` guard prevents hitches from collapsing multiple steps into one frame. Matches PlayerCharacter's F.1/F.2 pattern for consistency.
- **Signal ordering vs get_noise_level()**: `_emit_footstep()` calls `player.get_noise_level()` BEFORE emitting the signal. If PlayerCharacter's noise level is mid-transition (e.g., Walk→Sprint on the same frame), the emission reflects the new state's noise. This is correct for Audio (new state = new SFX variant immediately). If it proves confusing, consider emitting `pre_transition_state` in a future iteration — deferred as OQ-FC-2.

## Tuning Knobs

Designer-facing knobs (4 total). Cadence values are sourced from the existing Audio GDD step-cadence table (preserved from PC v0.3).

| Knob | Default (Hz) | Safe range | Affects |
|---|---|---|---|
| `cadence_walk_hz` | 2.2 | 1.8 – 2.8 | Walk step rate. Below 1.8 reads as slog; above 2.8 reads as nervous. |
| `cadence_sprint_hz` | 3.0 | 2.5 – 3.6 | Sprint step rate. Below 2.5 reads as jog; above 3.6 reads as panic run. |
| `cadence_crouch_hz` | 1.6 | 1.2 – 2.0 | Crouch step rate. Below 1.2 reads as sneak-creep; above 2.0 matches walk too closely. |
| `surface_raycast_depth_m` | 2.0 | 1.0 – 4.0 | Downward ray depth for surface detection. Covers stairs and slopes; deeper = catches larger level geometry gaps. |

### Correctness Parameters (engine-side, not designer-tunable)

| Parameter | Default | Why |
|---|---|---|
| `surface_raycast_origin_offset_m` | -0.05 m | Slight downward offset from capsule center so the raycast does not self-hit. |
| `unknown_surface_warning_throttle` | once per (tag, mission-load) | Prevents log spam for a missing-metadata mesh that Eve crosses repeatedly. |

### Tuning authority

- **Audio Director** owns: cadence values (feel + stem-mix coordination).
- **Gameplay Programmer** owns: raycast depth, correctness parameters.
- **Level Designer** owns: `surface_tag` metadata on level meshes (content authoring, not a runtime knob).

## Visual/Audio Requirements

### Audio

- **Signal consumed by**: Audio GDD §Footstep Surface Map — **Audio GDD §Footstep Surface Map is the canonical owner of the surface→bucket→stem mapping.** FC GDD states the bucket thresholds here for cross-doc reference; if the two diverge, Audio GDD wins.
- **Mix bus routing**: all footstep SFX route to the canonical `SFX` bus (Audio GDD 5-bus model: Music, SFX, Ambient, Voice, UI).
- **Stem variants — 4-bucket scheme** (audio-director B1+B2 fix, 2026-04-21). Each surface has **four** loudness variants; FootstepComponent passes `noise_radius_m` and Audio picks the bucket:

  | Bucket | `noise_radius_m` range | Typical source |
  |---|---|---|
  | `soft` | `≤ 3.5 m` | Crouch locomotion (3 m), deep-knob `noise_walk` minimum |
  | `normal` | `3.5 < r ≤ 6.5 m` | Walk locomotion (5 m), soft landing (5 m), upper `noise_walk` tuning |
  | `loud` | `6.5 < r ≤ 10 m` | Lower-end Sprint locomotion after multiplier, hard landing at threshold (8 m) |
  | `extreme` | `> 10 m` | Sprint locomotion (12 m default), hard landing scaled above threshold (8–16 m) |

  The 4th bucket (`extreme`) is new in this revision — Session F raised Sprint to 12 m and hard-landing cap to 16 m, which both collapsed into a single "loud" bucket under the old 3-bucket scheme. The extreme bucket preserves dynamic-range differentiation between a brisk Sprint and a panic-drop. Thresholds align exactly with Audio GDD §Footstep Surface Map — the two documents must stay in lockstep.
- **Authoring rule**: never ship a surface with fewer than 4 random variants per loudness bucket (16 stems per surface, 7 surfaces = 112 stems at MVP). Prevents perceptible loop. **Stairs are NOT yet in the surface tag set** — they must be added before Observation Deck + Restaurant levels enter content production (audio-director R4 advisory, 2026-04-21; tracked as OQ-FC-5).
- **Water puddle special case**: one-shot, no soft/normal/loud/extreme variants — single splash + squelch stem; plays concurrent with the underlying surface's footstep stem if applicable. Pool-slot note: adds one extra concurrent source not in Audio GDD's default footstep pool hints — at Sprint cadence (3 Hz) × 2 concurrent (base + splash) = 6 Hz aggregate source rate, well under the 16-slot SFX pool ceiling; no pool-starvation risk at MVP.

### Visual

No visual output directly from this component. The player's visible feet (on the future 3rd-person body mesh — VS tier per PC OQ-4) would sync to emission events, but that mesh does not exist at MVP.

## Cross-References

### Upstream GDDs

[Player Character](player-character.md), [Signal Bus](signal-bus.md), [Audio](audio.md).

### Downstream GDDs

Audio (consumer).

### Required ADRs

- [ADR-0002 — Signal Bus + Event Taxonomy](../../docs/architecture/adr-0002-signal-bus-event-taxonomy.md) — `player_footstep` signature
- [ADR-0006 — Collision Layer Contract](../../docs/architecture/adr-0006-collision-layer-contract.md) — `MASK_FOOTSTEP_SURFACE`

### Forbidden Patterns (Control Manifest excerpt)

- Stealth AI code subscribing to `Events.player_footstep` (AI perception must use PC's `get_noise_level()` / `get_noise_event()`).
- FootstepComponent mutating `player.health`, `player.current_state`, `player.velocity`, or `player._latched_event`.
- Implementing a second noise-level formula inside FootstepComponent (it must call `player.get_noise_level()`, never compute its own).
- Attaching FootstepComponent to any node that is not a direct child of `PlayerCharacter`.
- Emitting `player_footstep` at a rate exceeding 4 Hz (ADR-0002 anti-pattern guard — real cadence max is 3 Hz at Sprint; 4 Hz is the ceiling).

## Acceptance Criteria

Each AC is binary (pass/fail), carries a story-type label, names its measurement method + threshold, and points at a test-evidence path.

### AC-FC-1 Cadence timing

- **AC-FC-1.1 [Logic]** With `cadence_walk_hz = 2.2` and a stubbed PlayerCharacter in Walk state with `velocity = Vector3(3.5, 0, 0)`, `Events.player_footstep` fires at 2.2 ± 0.1 Hz over a 5-second sample (expected: 11 ± 1 emissions). Evidence: `tests/unit/footstep/footstep_cadence_walk_test.gd`.
- **AC-FC-1.2 [Logic]** Same for Sprint (`cadence_sprint_hz = 3.0`, `velocity.length() = 5.5`, expect 15 ± 1 emissions in 5 s) and Crouch (`cadence_crouch_hz = 1.6`, `velocity.length() = 1.8`, expect 8 ± 1 emissions in 5 s). Evidence: `tests/unit/footstep/footstep_cadence_all_states_test.gd`.
- **AC-FC-1.3 [Logic]** Transitioning from Walk → Sprint mid-interval: the first Sprint step fires within `1 / cadence_sprint_hz` seconds of the transition (±1 physics frame). No double-fire on the transition frame. Evidence: `tests/unit/footstep/footstep_state_transition_test.gd`.
- **AC-FC-1.4 [Logic]** Idle / Jump / Fall / Dead states: no `player_footstep` signal fires. Verified by driving the stub through each of those states for 3 seconds each and asserting zero emissions. Evidence: `tests/unit/footstep/footstep_silent_states_test.gd`.

### AC-FC-2 Surface detection

- **AC-FC-2.1 [Logic]** With a stub ground body carrying `surface_tag = &"marble"` directly below the player, `_resolve_surface_tag()` returns `&"marble"`. Evidence: `tests/unit/footstep/footstep_surface_marble_test.gd`.
- **AC-FC-2.2 [Logic]** With no body below the player (or body missing `surface_tag` metadata), `_resolve_surface_tag()` returns `&"default"` AND a `push_warning` fires exactly once per (tag, test-run) pair. Evidence: `tests/unit/footstep/footstep_surface_default_fallback_test.gd`.
- **AC-FC-2.3 [Logic]** Crossing a surface boundary: after the player's `global_transform.origin` moves from above a `marble` body to above a `carpet` body, the NEXT `player_footstep` emission carries `surface == &"carpet"` (not marble). Evidence: `tests/unit/footstep/footstep_surface_crossing_test.gd`.
- **AC-FC-2.4 [Logic]** All 7 documented surface tags (`marble`, `tile`, `wood_stage`, `carpet`, `metal_grate`, `gravel`, `water_puddle`) plus `default` resolve correctly when placed under the player. Parametrized test. Evidence: `tests/unit/footstep/footstep_surface_tag_set_test.gd`.

### AC-FC-3 Isolation (AI lane MUST NOT be touched)

- **AC-FC-3.1 [Logic]** After running FootstepComponent for 100 emission events, `player.get_noise_level()` returns the same value it would have returned without FootstepComponent attached (verified by comparing two runs: one with FootstepComponent as a child, one without). FootstepComponent is proven pure-observer. Evidence: `tests/unit/footstep/footstep_isolation_test.gd`.
- **AC-FC-3.2 [Logic]** `player._latched_event` is `null` after FootstepComponent emits 100 footstep events in Walk/Sprint/Crouch states (no takeoff or landing events occurred). **Separate test file** (qa-lead #5 fix, 2026-04-21) so CI can isolate this assertion's failure from AC-FC-3.1's comparison-of-two-runs assertion. Evidence: `tests/unit/footstep/footstep_no_latch_mutation_test.gd`.
- **AC-FC-3.3 [Logic]** FootstepComponent code contains zero assignments to `player.health`, `player.current_state`, `player.velocity`, or `player._latched_event`. CI-lint rule `footstep.*\.(health|current_state|velocity|_latched_event)\s*=` enforces this. Evidence: `tests/ci/footstep_purity_lint.gd` (lint rule test).

### AC-FC-4 Signal taxonomy conformance

- **AC-FC-4.1 [Logic]** `player_footstep` is emitted through the `Events` autoload (ADR-0002), not via direct node-to-node connections. Evidence: `tests/unit/footstep/footstep_signal_taxonomy_test.gd`.
- **AC-FC-4.2 [Logic]** **Deterministic emission-rate guard** (qa-lead #6 fix, 2026-04-21). Drive a scripted sequence of 600 `_physics_process` ticks at `delta = 1.0 / 60.0` (10 seconds), transitioning through WALK → SPRINT → CROUCH → WALK (all emitting states). Count `player_footstep` emissions per 60-tick (1-second) window. Assert: max emissions in any window ≤ 4 (ADR-0002 anti-pattern guard; real max is 3 at Sprint cadence 3 Hz). Driven via fixed-delta ticks rather than real-time capture — eliminates non-determinism per project testing standards. Evidence: same test file.

### AC-FC-5 Audio integration

- **AC-FC-5.1 [Integration]** Subscribing a stub Audio handler to `Events.player_footstep` receives `(surface: StringName, noise_radius_m: float)` with the correct surface tag for the current ground body AND `abs(noise_radius_m - player.get_noise_level()) < 0.001` at emission time (epsilon = 0.001 m — product of two floats with no complex derivation; tighter than needed, generous against float drift). Evidence: `tests/integration/footstep/footstep_audio_handoff_test.gd`.
- **AC-FC-5.2 [Visual/Feel]** In a playtest level with all 7 surface types reachable, each surface produces a perceptibly distinct footstep SFX. **Audio-director sign-off criterion** (qa-lead R-4 + audio-director N1 fix, 2026-04-21): (a) each surface produces a recognisably different spectral character at the same loudness bucket (measured via reference listening at calibrated monitoring level, -14 LUFS target per Audio GDD authoring convention), (b) the 4 loudness buckets of the same surface produce clearly audible loudness differentiation without crossing into adjacent buckets' perceptual range, (c) no bucket is perceptually indistinguishable from the default fallback stem. Binary pass: 7 surfaces × 4 buckets = 28 cells all distinct AND bucket-progression monotonic within each surface. Evidence: `production/qa/evidence/footstep-surface-audio-[date].md` with audio-director sign-off paragraph covering (a/b/c).

### AC-FC-6 Parenting assertion

- **AC-FC-6.1 [Logic]** Attaching FootstepComponent to a non-PlayerCharacter parent (e.g., a bare Node3D) causes `_ready()` to emit `push_error` AND set `_is_disabled = true` such that subsequent `_physics_process` ticks emit no footsteps. Evidence: `tests/unit/footstep/footstep_parent_assertion_test.gd`.

## Open Questions

### OQ-FC-1 — Surface metadata authoring workflow

**Question**: How are `surface_tag` values authored on level meshes at scale?

**Current spec**: manual `set_meta("surface_tag", &"marble")` per body in the level scene. Works but does not scale to 7 levels × hundreds of meshes.

**Options**:
- **A**: Per-mesh metadata (current). Simple but every level artist must tag manually.
- **B**: `PhysicsMaterial` resource with an extended `surface_tag` script property. Godot-idiomatic but requires authoring a PhysicsMaterial tool.
- **C**: Per-area override zones (Area3D volumes with a tag). Flexible for mission scripting (e.g., carpet temporarily wet = `water_puddle` zone overlay).
- **D**: Combination of B (material-level default) + C (area override).

**Deferred to**: Level Streaming GDD + possible ADR on level-metadata schema. Revisit when the first real level mesh is authored.

**Authoring type note** (godot-specialist nit N-1): whichever option is chosen, the `surface_tag` metadata value MUST be authored as a `StringName` (`&"marble"`), not a plain `String` (`"marble"`). The Godot editor's metadata panel defaults to String — level designers must switch the type to StringName in the inspector dropdown. Mixing String and StringName values across meshes would defeat the interning optimization and introduce silent equality-mismatch risk in future code that uses `match` or dictionary lookups keyed on the tag.

### OQ-FC-2 — Noise level sampling timing

**Question**: Should `noise_radius_m` in `player_footstep` sample `get_noise_level()` at emission time or at the start of the step interval?

**Current spec**: at emission time (end of interval). Matches state at the moment the audible SFX plays.

**Alternative**: start-of-interval sampling. Would mean the signal reflects the state when the foot LIFTED, not when it lands. More physically accurate but requires buffering.

**Deferred to**: Audio GDD review + playtest. Current spec is simpler and likely sufficient.

### OQ-FC-3 — FootstepComponent execution order vs PlayerCharacter state transitions

**Question**: When Jump fires on the same frame a step interval completes, should the component step fire first (current — one trailing Walk step) or should the component skip emission if PC is about to transition?

**Current spec**: emission fires; the following frame's `_is_emitting_state(JUMP) == false` halts further emissions. One trailing step is considered acceptable.

**Deferred to**: playtest. If QA reports this as perceptible popcorn, re-order to defer emission to after PC state updates.

### OQ-FC-5 — Stair surface tags

**Question**: The surface tag set does not include stairs (`stairs_metal`, `stairs_wood`). The Eiffel Tower location has extensive metal scaffolding stair sections; the Restaurant may have service stairs.

**Current spec**: stairs fall through to `&"metal_grate"` or `&"wood_stage"` depending on level-authoring, which produces a flat walking-on-flat-surface SFX instead of the rhythmic riser-catch SFX a stair footfall has.

**Proposed fix**: add `&"stairs_metal"` and `&"stairs_wood"` to the surface tag set; deliver two stem sets (4 buckets × 4 variants × 2 surfaces = 32 new stems). Level-design QA sweeps metal grate + wood stage sections for stair override zones (per OQ-FC-1 Option C).

**Deferred to**: content-production scoping pass (before Observation Deck or Restaurant levels enter authoring). Tracked by audio-director advisory 2026-04-21.

### OQ-FC-4 — Non-player footstep sources

**Question**: Does `player_footstep` cover only Eve, or also AI guards for future stealth mechanics (the player hearing the guard)?

**Current spec**: Eve only. Guard footsteps are owned by Stealth AI + Audio directly (not through this signal), because the AI-hearing-player vs player-hearing-AI channels have inverted subscriber sets.

**Deferred to**: Stealth AI GDD authoring. If guard footstep audibility becomes a gameplay mechanic, a parallel `ai_footstep` signal may be introduced (separate signal, separate component on AI nodes).
