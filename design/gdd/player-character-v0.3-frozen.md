# Player Character (Eve Sterling)

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists (game-designer, art-director, gameplay-programmer per routing)
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Pillar 3 (Stealth is Theatre, Not Punishment — cinematic movement, generous interact); Pillar 5 (Period Authenticity — no modern movement conveniences); Pillar 2 (Discovery Rewards Patience — interact context resolution)

## Summary

Player Character is the **Eve Sterling** system — the first-person player avatar the game is named around. It owns Eve's movement (walk/run/crouch/sprint), FPS camera, context-sensitive `interact` behavior, health state, and the visible FPS hands mesh. Eve wears one outfit the entire mission (Courrèges navy per Art Bible 5.1); this GDD specifies how she *moves* and *feels*, not what she looks like. Implementation uses Godot 4.6 `CharacterBody3D` with Jolt physics (4.6 default). Publishes to Events bus per ADR-0002: `player_damaged(amount, source, is_critical)`, `player_died(cause)`, `player_health_changed(current, max_health)` — full signatures in Interactions table. State serialized via ADR-0003 `PlayerState` sub-resource (position, rotation, health, current_state as `PlayerCharacter.MovementState` enum int). Stamina has been **removed** as a system (see Detailed Design → Rejected features for the Pillar 5 rationale).

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Effort: `M` · Key deps: `Input, Outline Pipeline` · Player character: **Eve Sterling** (BQA field agent, 1965, one outfit per Art Bible 5.1)

## Overview

Player Character is both the technical FPS movement system and the embodiment of Eve Sterling herself. The player's input flows into this system first (via the Input GDD's 26-action catalog), is translated into character movement, and radiates out to every downstream system that cares about Eve's state: Stealth AI reads her position and noise footprint to drive guard perception; Combat & Damage applies damage to her health; Inventory & Gadgets displays her equipped item on her visible FPS hands; Document Collection triggers on her `interact` raycast; Mission & Level Scripting listens for position-based triggers.

Movement is deliberately **cinematic, not twitch**. Eve walks at a confident pace (not Quake-speed). Sprint increases that pace modestly — it does not turn her into a parkour athlete. Crouch lowers her silhouette AND footstep noise. Jump is a small, controlled hop (mantling over low obstacles), not a leap over gaps. This is **Pillar 3 (Stealth is Theatre)** made kinesthetic: the player feels they are playing a secret agent, not a superhero. **Pillar 5 (Period Authenticity)** forbids modern movement vocabulary — no wall-running, no sliding, no air-dash, no stamina bar, no sprint cooldown UI.

Context-sensitive `interact` is the single most important player-facing behavior after movement. A raycast from the camera at ~2m range returns the nearest interactable and executes via a locked priority order (documented in Detailed Design): document > terminal > item pickup > door/lever. This is NOLF1's diegetic interaction model — **one button, unambiguous behavior**, no modern "hold E to interact" meter.

Eve's FPS hands (visible mesh for weapons, gadgets, and manipulation animations) render in a `SubViewport` at FOV 55° and carry a heavy outline visually matching stencil tier HEAVIEST, achieved via the inverted-hull shader technique per **ADR-0005** — hands are the project's single documented exception to ADR-0001's stencil-based outline contract. Her full body model is used for mirror reflections and third-person cutscenes only; gameplay is first-person exclusively at MVP. Health uses a numeric value (0–100) displayed in the HUD per Art Bible 7B (NOLF1-style HUD, not a segmented bar). **Sprint is unlimited but loud** — an audible mode, not a time-gated resource. There is no stamina system (see Detailed Design → Rejected features).

**This GDD covers Eve's behavior, state, and interfaces.** It does NOT cover: her visual appearance (owned by Art Bible 5.1 + future character modeling asset spec), her AI (she is the player, not an NPC), her dialogue (owned by future narrative GDDs), or enemy AI's reactions to her (owned by Stealth AI GDD).

## Player Fantasy

**"The Deadpan Witness."** You are Eve Sterling, and the joke is never you. Every movement is a **noticing** — you enter rooms, you cross thresholds, you descend staircases, and the absurdity of 1965 espionage unfurls *around* you. Your crouch is not a combat stance, it's a considered lean. Your sprint is not an action-hero dash, it's a walk slightly accelerated, as if you'd rather not. The fantasy is **being the eye of the storm**: the world is ridiculous; you are not.

**References:** Emma Peel (Diana Rigg in *The Avengers*) — the arched eyebrow rendered as a camera tilt. Modesty Blaise — competence so total it reads as indifference. Cate Archer (NOLF1) — *"oh, this again"* as a gait, but without the quips.

**Pillars served:**
- **Pillar 1 (Comedy Without Punchlines)** — the player IS the straight man, kinesthetically. Eve's deadpan gait becomes the straight line that lets the world's absurdity land.
- **Pillar 3 (Stealth is Theatre)** — every movement is framed, posed, *watched*. Theatrical hesitation replaces twitch-shooter instantaneity.
- **Pillar 5 (Period Authenticity)** — no modern verbs. Eve doesn't slide, she *steps past*. She doesn't dodge-roll, she sidesteps. She doesn't parkour, she walks with purpose.

**Kinesthetic feel in first-person gameplay:**
- Camera settles with a tiny overshoot-and-return when turning (a beat of consideration, not a snap).
- A brief ~100 ms decision beat before crouch drops — Eve is deciding to crouch, not reflexively dropping.
- `interact` has a small ~150 ms pause before the hand reaches — as if Eve noticed the object before bothering to pick it up.
- Sprint feels like a walk accelerated, not a dash. No whoosh, no motion blur.
- Movement has **punctuation**. You feel like you're always entering a scene.

**Design test for this framing:** *If we're debating whether Eve should have a combat-roll dodge, this framing says no — she doesn't roll, she steps aside. The deadpan witness doesn't tumble.*

Players will never say *"Eve's movement feels like X."* They will say *"I feel like I'm playing a competent person who has seen all of this before."*

## Detailed Design

### Core Rules

**Physical body.** Eve is a `CharacterBody3D` with a `CapsuleShape3D` collider. Standing: 1.7 m height, 0.3 m radius. Crouched: 1.1 m height, 0.3 m radius. Camera (`Camera3D`) is a child node at local Y = 1.6 m standing, 1.0 m crouched. Physics ticks at 60 Hz via `_physics_process`. Movement uses `velocity` + `move_and_slide()`. Jolt physics (Godot 4.6 default).

**Collision layers.** Per **ADR-0006 (Collision Layer Contract)** — single source of truth at `res://src/core/physics_layers.gd`. This GDD consumes the contract; it does NOT redefine layer numbers. Layers relevant to PlayerCharacter:

| Constant | Bitmask | Role for Eve |
|---|---|---|
| `PhysicsLayers.LAYER_WORLD` | `MASK_WORLD` | Eve's body collides against world geometry; footstep raycast reads material metadata from this layer |
| `PhysicsLayers.LAYER_PLAYER` | `MASK_PLAYER` | Eve's `CharacterBody3D` is ON this layer. AI vision raycasts treat this as a target (via `MASK_AI_VISION_OCCLUDERS`) |
| `PhysicsLayers.LAYER_AI` | `MASK_AI` | Eve's body collides against AI bodies (cannot walk through guards) |
| `PhysicsLayers.LAYER_INTERACTABLES` | `MASK_INTERACTABLES` | Interact raycast scans ONLY this layer (non-blocking to movement) |
| `PhysicsLayers.LAYER_PROJECTILES` | `MASK_PROJECTILES` | Projectile bodies collide with Eve (receives damage) |

Eve's `CharacterBody3D` at `_ready()` sets: `layer = MASK_PLAYER`, `mask = MASK_WORLD | MASK_AI` (via `set_collision_layer_value` / `set_collision_mask_value` with `LAYER_*` constants per ADR-0006 Implementation Guideline 3). All further layer references in this GDD cite `PhysicsLayers.*` constants, never bare integers.

**Rejected features (Pillar 5 — resolved per Session A review, 2026-04-19).**

- **No stamina system.** A hidden stamina counter was considered and rejected (review item B-14). Although invisible, its effects — mid-sprint auto-drop to Walk, heavier-breathing audio — manifest as modern-verb feedback in period costume. The Deadpan Witness does not run out of breath mid-clutch. Sprint is therefore unlimited; its cost is purely diegetic (noise radius 9.0 m vs Walk 5.0 m — see F.4 noise table).
- **No CrouchSprint state.** Previously speced at 2.4 m/s with 9.0 m noise (review item R-4). Strictly slower than Walk (3.5 m/s) and matched Sprint's noise, so served no tactical niche. Removed. Silhouette-lowering cover traversal is handled by Crouch alone.

**Movement state enum.** Defined as an inner enum on `PlayerCharacter`:

```gdscript
enum MovementState { IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, DEAD }
```

**Noise type enum.** Defined as an inner enum on `PlayerCharacter` alongside `MovementState` (same ADR-0002 Implementation Guideline 2 rationale — NOT on `Events.gd`, NOT on a shared `Types.gd`). Used by Stealth AI to type-switch on noise origin rather than relying on scalar radius alone. Session D B-12:

```gdscript
enum NoiseType { FOOTSTEP_SOFT, FOOTSTEP_NORMAL, FOOTSTEP_LOUD, JUMP_TAKEOFF, LANDING_SOFT, LANDING_HARD }
```

Mapping from state/event to `NoiseType`:
- Crouch locomotion → `FOOTSTEP_SOFT` (radius 3.0 m)
- Walk locomotion → `FOOTSTEP_NORMAL` (radius 5.0 m)
- Sprint locomotion → `FOOTSTEP_LOUD` (radius 9.0 m)
- Jump takeoff spike → `JUMP_TAKEOFF` (radius 4.0 m)
- Soft landing spike → `LANDING_SOFT` (radius 5.0 m)
- Hard landing spike (|v.y| > v_land_hard per F.3) → `LANDING_HARD` (radius 8.0 m)
- Idle / Crouch-idle → silent (no `NoiseType` emitted; `get_noise_level()` returns 0.0)

**NoiseEvent inner class.** Lightweight typed struct returned by `get_noise_event()` (F.4). Declared as `class_name NoiseEvent` in its own file `res://src/gameplay/player/noise_event.gd` to make it globally visible to Stealth AI without importing PlayerCharacter. No `Resource` subclass (ref-counted allocator overhead at 80 Hz aggregate AI polling is unacceptable — see F.4 performance note). Fields:

```gdscript
class_name NoiseEvent
var type: PlayerCharacter.NoiseType
var radius_m: float
var origin: Vector3   # world-space position of Eve at the frame the spike was recorded
```

PlayerCharacter reuses a single `NoiseEvent` instance for the latch (see F.4) — callers must not retain the reference across frames. If a caller needs to remember a spike (e.g., Stealth AI parking an investigate-marker), copy the fields into its own state, do not store the reference.

All internal `current_state` references, the `PlayerState` serialization field (ADR-0003), and save-load contracts use this enum. Per ADR-0002 Implementation Guideline 2 the enum is owned by `PlayerCharacter` — **not** on `Events.gd`, **not** on a shared `Types.gd`. Prose in this GDD continues to use TitleCase state names (`Idle`, `Walk`…) for readability; those map one-to-one to the UPPER_SNAKE_CASE enum values.

**Movement states** (mutually exclusive; one active at all times): `Idle`, `Walk`, `Sprint`, `Crouch`, `Jump`, `Fall`, `Dead`.

**Movement speeds** (all m/s, Tuning Knobs for designer tweaking):

| State | Speed | Acceleration | Deceleration |
|---|---|---|---|
| Walk | 3.5 | 0.12 s to full | 0.18 s to stop |
| Sprint | 5.5 | 0.15 s to full | 0.18 s to stop |
| Crouch | 1.8 | 0.12 s to full | 0.15 s to stop |

**Vertical motion.** Gravity = 12.0 m/s² (heavier than Earth for tighter feel). Jump initial velocity = 3.8 m/s (apex ≈ 0.60 m, total airtime ≈ 0.63 s). No double-jump. No air control acceleration (preserves lateral velocity at takeoff; no mid-air steering). Landing at fall speed `> v_land_hard` (see F.3 — runtime-derived, 6.0 m/s at shipped defaults) triggers a camera dip but no damage (no fall damage at MVP — per Pillar 5, no twitch-shooter verbs).

**Camera.** First-person only. FOV 75° (horizontal). Mouse and gamepad look sensitivity are **owned by this GDD** per Input GDD §Formulas: Input captures raw `InputEventMouseMotion` and gamepad axis deltas; PC GDD applies the `mouse_sensitivity_x`, `mouse_sensitivity_y`, and `gamepad_look_sensitivity` tuning knobs (see Tuning Knobs → Camera). Settings & Accessibility autoload provides runtime overrides persisted to `user://settings.cfg`; defaults ship from this GDD (reconciled Session C R-16, 2026-04-19). Pitch clamp: −85° to +85°. Yaw unconstrained. Camera attaches directly to character root (no spring-arm at MVP). Roll is always 0 (no lean system at MVP per Input GDD decision).

**Noise footprint** (read by Stealth AI each perception tick via `get_noise_level() -> float` for continuous radius and `get_noise_event() -> NoiseEvent` for discrete spikes; see F.4 for the two-method contract):

| State | Noise radius (m) | Notes |
|---|---|---|
| Idle / Crouch idle | 0.0 | Silent |
| Walk | 5.0 | Standard footfalls |
| Sprint | 9.0 | Loud footfalls + breathing |
| Crouch | 3.0 | Soft footfalls |
| Jump takeoff | 4.0 | Latched NoiseEvent (see F.4) |
| Landing (soft) | 5.0 | Latched NoiseEvent (see F.4) |
| Landing (hard, `> v_land_hard`) | 8.0 | Latched NoiseEvent (see F.4). Threshold runtime-derived per F.3 — at shipped defaults `v_land_hard = 6.0 m/s`; rescales if `gravity` or `hard_land_height` are retuned. |

Interface is **two per-frame pull methods** on the PlayerCharacter node, both called by Stealth AI each perception tick (Session D B-12/B-13; latch semantics revised Session E-Prime AI-1):
- `get_noise_level() -> float` — radius in meters (continuous locomotion state OR latched spike value). Cheap radius-threshold check for the hot path.
- `get_noise_event() -> NoiseEvent` — returns the latched event for discrete spikes (JUMP_TAKEOFF, LANDING_SOFT, LANDING_HARD); returns null when no spike is latched. **Idempotent-read**: repeated calls within the latch window return the same event; the latch is cleared only by auto-expiry (`spike_latch_duration_sec`), never by a consumer. This ensures every guard polling within the window receives the same event — see F.4 "Multi-guard parity" note. Continuous locomotion footsteps do NOT produce latched events — those are exposed through `get_noise_level()` only.

Neither method is emitted via Signal Bus (ADR-0002 prohibits per-frame signals). The latched event is an implementation detail of `get_noise_event()`, not a new signal — no ADR-0002 amendment required.

**Context-sensitive `interact`** (bound to E per Input GDD):
- A raycast from camera origin along forward vector, length **2.0 m**, `mask = PhysicsLayers.MASK_INTERACT_RAYCAST` (per ADR-0006).
- Each frame, the HUD highlight query calls the same resolver that E-press uses — `_resolve_interact_target()` per F.5. This guarantees the outlined object (outline tier 2 per ADR-0001) is always the object E-press would activate, even when interactables are stacked (Session D B-11 HUD-coherence guarantee).
- On E-press, the resolver returns the highest-priority Interactable on the ray by **priority order**:
  1. Document (Document Collection system)
  2. Terminal (Mission Scripting trigger)
  3. Item pickup (Inventory)
  4. Door / lever (world interaction)
- Priority order resolves ambiguity when multiple interactables overlap in the ray path — lowest priority number wins even if another is geometrically closer. This is **NOLF1 single-button interact** — no "hold E" meter, no context menu, no prompt selector.
- A **150 ms pre-reach pause** plays before the hand animation begins (Player Fantasy: Eve *noticing* the object before reaching). The reach animation itself is 200–250 ms. During the full pause+reach window, movement input is accepted but sprint is disabled.

**Health.** Single integer 0–100 (`max_health = 100`). Starts at `max_health` on mission load. Damage applied via `apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType)` method. `amount` is rounded to integer at assignment (stored `health` remains `int` — see F.6); the signal payload retains the caller's float value for analytics fidelity. Reaching 0 emits `player_died(cause: CombatSystem.DeathCause)` on the `Events` bus (ADR-0002); `cause` is derived from the killing blow's `damage_type` via Combat & Damage's `DamageType → DeathCause` mapping (default `DeathCause.UNKNOWN` if unmapped — Combat & Damage GDD owns the mapping). State transitions to `MovementState.DEAD`. No regeneration at MVP (per Pillar 5 — no modern regen verb; see Open Questions). `is_critical` on `player_damaged` is always `false` at MVP — Combat & Damage GDD will define crit rules in its own pass. `source` is a `Node` reference; subscribers MUST call `is_instance_valid(source)` per ADR-0002 Implementation Guideline 4.

### States and Transitions

```
             ┌──────────┐
             │   Idle   │◄────────────────────┐
             └────┬─────┘                     │
       input      │                           │
     ┌────────────┼────────────┐              │
     ▼            ▼            ▼              │
 ┌────────┐  ┌─────────┐  ┌─────────┐         │
 │  Walk  │◄─┤ Sprint  │  │ Crouch  │         │
 └───┬────┘  └────┬────┘  └────┬────┘         │
     │            │            │              │
       Space  ▼                │              │
          ┌────────┐   landing │              │
          │  Jump  │──┐        │              │
          └────────┘  │        │              │
              │       │        │              │
       apex   ▼       ▼        │              │
          ┌────────┐           │              │
          │  Fall  │───────────┘              │
          └────────┘                          │
                                              │
          Any state ──health=0──► ┌────────┐  │
                                  │  Dead  │──┘ (respawn via Failure system)
                                  └────────┘
```

**Transition rules (exhaustive):**

| From | To | Trigger | Block condition |
|---|---|---|---|
| Idle | Walk | Movement input + no Shift | — |
| Idle | Sprint | Movement input + Shift held | — |
| Idle/Walk/Sprint | Crouch | Ctrl pressed (toggle) | Ceiling check fails if uncrouching (stay crouched) |
| Any ground state | Jump | Space pressed + `is_on_floor` + coyote-time latch | In Crouch (jump ignored — must uncrouch first) |
| Any ground state | Fall | `not is_on_floor()` AND `not jump_pressed` AND coyote-time expired | Ledge walk-off path (Session E-Prime GD-1). Applies to Idle/Walk/Sprint/Crouch. Crouch state is preserved through Fall and restored on landing if Ctrl still held. |
| Jump | Fall | `velocity.y ≤ 0` | — |
| Fall | Idle/Walk/Sprint/Crouch | `is_on_floor()` | Previous crouch state restored if Ctrl still held |
| Any | Dead | `health ≤ 0` | — |

**Coyote-time (placeholder — to finalize in R-13 Session E batch 2).** The Jump trigger uses a coyote-time latch to tolerate Jolt's transient `is_on_floor() == false` on stair/step edges: `can_jump == true` for `coyote_time_frames` (default 3 frames ≈ 50 ms at 60 Hz) after the last frame `is_on_floor()` was true. The Ground → Fall transition respects the same latch — Eve does not fall-state for the same 3-frame grace window, preserving late-Jump intent at ledge edges. Exact frame count + analog-vs-frame parameterization pending R-13 decision; this placeholder ensures the state machine is closed in the interim.

**120 ms crouch decision beat.** When Ctrl is pressed, the transition to Crouch has a 120 ms ease-in-out animation (camera drop from 1.6 m to 1.0 m, collider shrinks). Movement input during the transition is accepted but capped at Crouch speed from frame 1 (no speed snap mid-drop).

**Ceiling check.** Uncrouching requires a shapecast (capsule, standing dimensions) from current position to detect ceiling clearance. If blocked, Eve stays crouched and a subtle audio cue (bump on the ceiling) plays. No visual UI feedback — Pillar 5.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Input** | consumes | Reads 26-action catalog via `Input.get_action_strength()` and `Input.is_action_just_pressed()`. Input GDD §Core Rules. |
| **Signal Bus** | publishes | `player_damaged(amount: float, source: Node, is_critical: bool)`, `player_died(cause: CombatSystem.DeathCause)`, `player_health_changed(current: float, max_health: float)`, `player_interacted(target: Node3D)`. Per ADR-0002 taxonomy. |
| **Stealth AI** | provides state | Exposes `get_noise_level() -> float` (radius scalar, hot path) and `get_noise_event() -> NoiseEvent` (latched discrete spike, **idempotent-read** per Session E-Prime AI-1 — repeated calls within the latch window return the same event; auto-expiry is the sole clear) — per-frame pull methods, per F.4. Exposes `get_silhouette_height() -> float` for line-of-sight tests (1.7 standing / 1.1 crouched). |
| **Combat & Damage** | receives | `apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType)` method — only caller permitted to mutate health. |
| **Inventory & Gadgets** | queries + displays | Reads `is_hand_busy()` during interact pauses. Attaches held gadget mesh to `HandAnchor` node (child of camera). |
| **Outline Pipeline** | exception | Hands are the explicit ADR-0005 exception to ADR-0001 — outlined via inverted-hull shader on `HandsOutlineMaterial`, NOT via `OutlineTier.set_tier`. Full body mesh is inactive at MVP. Any other `MeshInstance3D` PlayerCharacter ever spawns must call `OutlineTier.set_tier` per ADR-0001. |
| **Save / Load** | serializes | Exports `PlayerState` sub-resource per ADR-0003: `position: Vector3, rotation: Vector3, health: int, current_state: int` (a `PlayerCharacter.MovementState` enum value — NOT a string). Stamina field removed per Session A (2026-04-19). `current_state` type changed String → int enum in Session C (2026-04-19); `save-load.md` row aligned in the same pass (also reconciled `health` `float` → `int`). |
| **HUD Core** | provides | `player_health_changed` signal drives the health readout. No direct coupling — HUD subscribes to bus. |
| **Mission Scripting** | listens | Trigger volumes query `global_transform.origin` per frame; `player_interacted` signal fires scripted beats (terminals, pickup-to-advance objectives). |
| **Audio** | publishes + queries | `player_footstep(surface: StringName, noise_radius_m: float)` signal per step (see FootstepComponent below). Reads mix bus for ducking on `player_died`. **Stealth AI MUST NOT subscribe to `player_footstep`** — AI perception uses `get_noise_level()` / `get_noise_event()` exclusively. The `noise_radius_m` field here is Audio's SFX-variant loudness cue, not an AI-perception channel (Session D B-12). |
| **Failure & Respawn** | subscribes | Listens for `player_died` to initiate respawn sequence. Player Character does NOT own respawn logic — it only dies. |

**FootstepComponent (child node of PlayerCharacter).** A dedicated component responsible for emitting footstep events. It reads the movement state + velocity + ground material (via downward raycast using `PhysicsLayers.MASK_FOOTSTEP_SURFACE` to read material metadata) and emits `player_footstep(surface, loudness)` on each step. This isolates footfall logic from core movement code and lets Audio own the surface→SFX mapping (see Audio GDD §Footstep Surface Map). FootstepComponent also updates the noise level reported by `get_noise_level()`.

**Boundary — this GDD does NOT own:**
- Respawn flow (owned by Failure & Respawn)
- HUD rendering (owned by HUD Core)
- Gadget behavior, weapon firing (owned by Inventory & Gadgets)
- AI perception math (owned by Stealth AI — this GDD only publishes state they read)
- Cutscene camera overrides (owned by Mission Scripting at VS tier)

## Formulas

**Variables used throughout:**
- `v` = current velocity vector (m/s)
- `v_target` = desired velocity for current state (m/s)
- `input_magnitude` = scalar ∈ [0.0, 1.0], source = `Input.get_vector("move_left", "move_right", "move_forward", "move_back").length()` (or equivalent analog-normalized magnitude per Input GDD). Gamepad analog sticks deliver fractional values; keyboard delivers {0.0, 1.0}. Used in F.1 to branch accel vs decel and to scale `v_target`. Session E-Prime SD-1.
- `Δt` = physics frame delta (s, nominal 1/60)
- `Δt_clamped` = hitch-guarded frame delta (see preamble below)
- `accel_time`, `decel_time` = state-specific acceleration curves (s)
- `g` = gravity constant (m/s²)
- `H` = jump height (m)
- `NOISE_BY_STATE` = constant dictionary `{MovementState.IDLE: 0.0, MovementState.WALK: 5.0, MovementState.SPRINT: 9.0, MovementState.CROUCH: 3.0, MovementState.JUMP: 0.0, MovementState.FALL: 0.0, MovementState.DEAD: 0.0}` declared as `const` on `PlayerCharacter`. Values for IDLE/JUMP/FALL/DEAD are silent because those states emit their noise via the latched `NoiseEvent` path (takeoff / landings), not via the continuous scalar. Each value is sourced from a Tuning Knob (Core Rules Noise Footprint table) — the dict is rebuilt once at `_ready()` from the knob values. Session E-Prime AI-2.

**Δt clamp (applies to F.1 and F.2 — Session D B-9).** Frame hitches (loading spikes, Alt+Tab resume) can give `Δt` values of 100 ms+, which would overshoot F.1's velocity blend and fabricate excess `v.y` in F.2 — the latter would falsely trigger F.3's hard-landing noise spike from a physics artifact, alerting AI. Clamp before use in the physics formulas:

```
Δt_clamped = min(Δt, 1.0 / 30.0)   # floor: 30 fps = 33.3 ms
```

Existing F.1/F.2 examples use `Δt = 0.01667` (60 fps), well within the 33 ms ceiling — no example recalculations required.

### F.1 Horizontal Acceleration (planar velocity blend)

**Runs only in ground states** (Idle, Walk, Sprint, Crouch). Jump and Fall preserve horizontal momentum from the last ground frame; air control is not yet specified — see OQ-8 (Session D R-5).

Each frame, blend current planar velocity toward the target:

```
# NaN guards: max(..., 0.001) prevents divide-by-zero if accel_time or
# decel_time is accidentally set to 0 (e.g., malformed resource). Inspector
# additionally enforces Safe Range per Tuning Knobs via
# @export_range(<safe_min>, <safe_max>, 0.01). Session D B-7.
if input_magnitude > 0:
    rate = 1.0 / max(accel_time, 0.001)
else:
    rate = 1.0 / max(decel_time, 0.001)
v.xz = v.xz.move_toward(v_target.xz, rate * max_speed * Δt_clamped)
```

**Example** (Walk from rest):
- `max_speed = 3.5`, `accel_time = 0.12`, `Δt = 0.01667`
- Per-frame step = `(1/0.12) × 3.5 × 0.01667` = **0.486 m/s per frame**
- Frames to full walk speed = `3.5 / 0.486` ≈ **7.2 frames ≈ 0.12 s** ✓

**Example** (Sprint → stop):
- `max_speed = 5.5`, `decel_time = 0.18`
- Per-frame step = `(1/0.18) × 5.5 × 0.01667` ≈ **0.509 m/s per frame**
- Frames to stop = `5.5 / 0.509` ≈ **10.8 frames ≈ 0.18 s** ✓

### F.2 Gravity and Jump

```
if not is_on_floor():
    v.y -= g * Δt_clamped

on jump_pressed and is_on_floor():
    v.y = jump_velocity
```

Where `g = 12.0`, `jump_velocity = 3.8`.

- **Apex height** (kinematic): `H = v_y² / (2g) = 3.8² / 24 = 0.602 m`
- **Airtime to apex**: `t_up = v_y / g = 3.8 / 12 = 0.317 s`
- **Total airtime (flat ground)**: `t_total = 2 × t_up = 0.633 s`
- **Landing velocity**: `v_land = g × t_up = 3.80 m/s` (equal to takeoff — no air drag)

### F.3 Hard-Landing Threshold

Drop height at which a landing triggers the hard-landing camera dip + 8 m noise spike. The threshold is expressed as a **height** (`hard_land_height` tuning knob), not a velocity — velocity is computed at runtime so that changing `gravity` automatically rescales (Session D B-8, prevents silent coupling bug where a gravity tweak would leave the trigger point at a fabricated drop height):

```
v_land_hard = sqrt(2 × gravity × hard_land_height)
```

With `hard_land_height = 1.5 m` (≈ one floor drop):
- At `gravity = 12.0` (shipped default): `v_land_hard = sqrt(36) = 6.0 m/s`
- At `gravity = 9.8`:  `v_land_hard = sqrt(29.4) ≈ 5.42 m/s` (auto-rescaled)
- At `gravity = 15.0`: `v_land_hard = sqrt(45)  ≈ 6.71 m/s` (auto-rescaled)

Any landing where `|v.y| > v_land_hard` is considered hard. No damage is applied at MVP (fall damage is Open Question OQ-2). Noise radius at trigger is a binary 8 m spike regardless of drop severity — scaled-noise alternative captured as OQ-7 (Session D added).

### F.4 Noise Level and Noise Events (read by Stealth AI)

Two interfaces, both per-frame pull methods:

```gdscript
# Fast radius scalar — returns the current audibility radius (meters).
# During a latched spike, returns the spike's radius × noise_global_multiplier.
# Otherwise returns the state-keyed constant from NOISE_BY_STATE × noise_global_multiplier,
# with Idle-override when velocity is near zero (Crouch-still and Walk-still resolve to 0.0).
# Cheap: intended for the hot path (80 Hz aggregate AI polling — 10 Hz × ~8 guards).
func get_noise_level() -> float:
    if _latched_event != null:
        return _latched_event.radius_m * noise_global_multiplier
    # Crouch-at-rest / Walk-at-rest treated as Idle-silent. Session E-Prime R-10.
    # idle_velocity_threshold defaults to 0.1 m/s — see Tuning Knobs → Noise.
    var moving: bool = velocity.length() >= idle_velocity_threshold
    if (current_state == MovementState.CROUCH or current_state == MovementState.WALK) and not moving:
        return 0.0
    return NOISE_BY_STATE[current_state] * noise_global_multiplier

# Discrete-spike delivery — IDEMPOTENT READ (Session E-Prime AI-1).
# Returns the latched NoiseEvent (or null when no spike is latched). The latch
# is NOT cleared on read — the sole clear mechanism is auto-expiry after
# spike_latch_duration_sec. Every guard polling within the latch window sees
# the same event, closing the race-to-first-poll asymmetry of the prior
# single-consumption contract. Continuous locomotion (Walk/Sprint/Crouch) does
# NOT produce a latched event; those are exposed through get_noise_level() only.
func get_noise_event() -> NoiseEvent:
    return _latched_event
```

**Spike latching rules (Session D B-13, revised Session E-Prime AI-1):**
- Jump takeoff and all landing variants (F.3) record a `NoiseEvent` to `_latched_event` immediately on state transition — not deferred to the next frame. `origin` is set to Eve's world-space position at the frame of recording, so a landing's investigate-marker points to the landing site, not to Eve's current position several frames later.
- If a spike arrives while `_latched_event` is occupied (e.g., landing spike within 2 frames of takeoff spike on a metal grate), **highest `radius_m` wins** — the new event overwrites only if strictly greater. Equal radius preserves the existing latch (first-wins on ties). Rationale: the louder event is what the AI should investigate. Note: `get_noise_level()` may therefore step up mid-latch (from 4.0 m to 5.0 m when a landing overwrites a takeoff); this is expected and does not indicate a new event cycle — Stealth AI should react to the sustained high value.
- The latch auto-expires after `spike_latch_duration_sec` (Tuning Knobs → Noise, default 0.1 s = 6 physics frames at 60 Hz = one AI tick window at 10 Hz). Converted to frame count at runtime: `spike_latch_duration_frames = int(spike_latch_duration_sec × Engine.physics_ticks_per_second)`. This makes correctness physics-tick-rate-independent (Session E-Prime R-17).
- A continuous-locomotion state transition (e.g., Idle → Walk) does NOT touch `_latched_event`.

**Multi-guard parity (Session E-Prime AI-1):** `get_noise_event()` is idempotent within the latch window — every caller receives the same `NoiseEvent` reference until auto-expiry. This replaces the Session D single-consumption contract, which produced race-to-first-poll asymmetry where only the first of ~8 guards polling the latch window received type+origin data. Under the idempotent-read model, all guards polling within the window see the same event and can arbitrate their response via Stealth AI's own investigate-marker logic (e.g., first-to-reach-the-origin wins; other guards downgrade).

**Caller contract — reference retention:** `get_noise_event()` returns the single reused `NoiseEvent` instance. Callers MUST NOT retain the reference across frames; on the next spike, fields are overwritten in place. Callers that need to remember a spike (e.g., Stealth AI parking an investigate marker) MUST copy `{type, radius_m, origin}` into their own state before the next physics frame. This is a documented footgun — if a guard stores `var last = player.get_noise_event()` and reads `last.origin` next frame, it reads the subsequent spike's origin, not the remembered one.

**Performance:** the latch is a single `NoiseEvent` instance reused across frames — no per-call allocation. At the 80 Hz aggregate polling rate (scales linearly if guard count exceeds ~8) this is steady-state zero-allocation.

**Why not a 1-frame spike + probability argument (superseded):** the previous spec said spikes last one physics frame and relied on the ~1-in-6 AI-tick alignment probability as acceptable. That made the interface's detection rate non-deterministic and untestable. The latched-event model makes each spike guaranteed-discoverable by every AI tick within the auto-expiry window.

### F.5 Interact Raycast Resolution

Iterative raycast with an exclusion list walks up to `raycast_max_iterations` stacked interactables along the camera forward ray. Each hit is tested against the best so far; the lowest priority number wins. Godot's `intersect_ray` returns a single hit per call, so the exclusion list is how F.5 gets a "multi-hit" traversal without a volumetric shape query (which would off-axis false-positive — see E.5 rationale). Session D B-11.

```gdscript
## F.5 Interact Raycast Resolution
## Returns the highest-priority Interactable within `interact_ray_length`, or null.
## Priority: Document(0) < Terminal(1) < Pickup(2) < Door(3). Lower wins.
func _resolve_interact_target() -> Node3D:
    var space_state := get_world_3d().direct_space_state
    var ray_origin: Vector3 = _camera.global_position
    var ray_end: Vector3 = ray_origin + (-_camera.global_transform.basis.z
                              * interact_ray_length)
    var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    query.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST
    query.exclude = []

    var best_node: Node3D = null
    var best_priority: int = 2147483647  # INT32_MAX sentinel — GDScript has no INT_MAX. Session E-Prime GP-2.

    for _i in raycast_max_iterations:
        var hit: Dictionary = space_state.intersect_ray(query)
        if hit.is_empty():
            break
        var collider: Node3D = hit.collider
        # Content-authoring safety: if a non-Interactable node is accidentally on
        # Layer 4 (LAYER_INTERACTABLES), skip it rather than crash. Session E-Prime GP-3.
        if not collider.has_method("get_interact_priority"):
            query.exclude.append(hit.rid)
            continue
        var priority: int = collider.get_interact_priority()
        if priority < best_priority:
            best_priority = priority
            best_node = collider
        query.exclude.append(hit.rid)

    return best_node
```

**Contract notes:**
- Priority is delegated to a method on each interactable: `get_interact_priority() -> int`. Constants are declared in `res://src/gameplay/interactables/interact_priority.gd` as `class_name InteractPriority` with an inner enum `InteractPriority.Kind { DOCUMENT = 0, TERMINAL = 1, PICKUP = 2, DOOR = 3 }`. Each interactable class imports this and returns the enum int from `get_interact_priority()`. Adding a new interactable type = append a new enum value in this single file + implement `get_interact_priority()` on the new class; PlayerCharacter never changes. Session E-Prime R-11. Testability: priority resolution can be unit-tested with mock nodes returning specific values, no concrete collider required.
- F.5 does NOT assume Jolt returns hits in nearest-first order — the exhaustion loop samples all hits within the iteration cap and keeps the lowest priority seen. Priority resolution is correct regardless of Jolt's broad-phase traversal order.
- `raycast_max_iterations` default 4 covers the realistic worst case (document on desk on a terminal near a door). Cap exceeded: best-so-far is returned; no null, no crash — graceful degradation. See E.5 for the companion minimum-separation rule that keeps the cap valid in practice.
- Same resolver is used by the continuous HUD-highlight query (see Core Rules rule 5) to guarantee the outlined object always matches the E-press target.
- Godot 4.6 + Jolt: `PhysicsRayQueryParameters3D.create()` is stable since 4.0; `query.exclude` as typed `Array[RID]` since 4.4. Jolt processes `exclude` as a broad-phase RID filter — excluded bodies skip narrow-phase entirely, so iteration cost scales sub-linearly (~0.05 ms per extra iteration measured on Jolt in typical mission-scale scenes).

### F.6 Damage Application

```gdscript
func apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType) -> void:
    if current_state == MovementState.DEAD: return
    # Session E-Prime R-12: reject non-positive amounts. apply_damage is not a
    # heal path — a separate apply_heal() method will be defined if/when healing
    # lands in Combat & Damage GDD. Silently returning avoids the silent-heal bug
    # where negative amount flipped health = max(0, health - (-X)) = health + X.
    if amount <= 0.0:
        push_warning("apply_damage called with non-positive amount %f — ignored" % amount)
        return
    var rounded: int = int(round(amount))
    health = max(0, health - rounded)
    # is_critical is always false at MVP — Combat & Damage GDD will define crit rules.
    Events.player_damaged.emit(amount, source, false)
    Events.player_health_changed.emit(float(health), float(max_health))
    if health == 0:
        current_state = MovementState.DEAD
        var cause: CombatSystem.DeathCause = CombatSystem.damage_type_to_death_cause(damage_type)
        Events.player_died.emit(cause)
```

**Notes on the contract:**
- `amount` is rounded to integer at assignment (HUD renders integer health per Art Bible 7B); the signal payload retains the caller's float value for analytics fidelity.
- `is_critical = false` is an MVP stub; Combat & Damage GDD will replace the literal with a rule-driven value without changing this GDD's interface.
- `CombatSystem.damage_type_to_death_cause(damage_type)` is a pure helper owned by the Combat & Damage GDD. Default `DeathCause.UNKNOWN` is returned for unmapped types. This GDD does not enumerate causes.
- `max_health` is read from the tuning-knob property (100 by default; see Tuning Knobs → Health), not a literal — resolving review item R-9.

No damage multipliers, no armor, no resistance at MVP. Combat & Damage GDD owns balance of damage values per weapon/source — this system only applies them.

## Edge Cases

### E.1 Uncrouch blocked by low ceiling
**Situation**: Eve is crouched under a desk or pipe; player releases Ctrl (toggle) to stand.
**Handling**: Shapecast (standing capsule dimensions) from current position detects ceiling. If blocked, Eve stays in Crouch state, Ctrl toggle is ignored that frame, and a soft "head bump" SFX plays. The toggle remains ON — player must move to a clear area and press Ctrl again. No visual indicator is shown (Pillar 5).

### E.2 Crouch pressed mid-jump
**Situation**: Player presses Ctrl while in Jump or Fall state.
**Handling**: Crouch toggle is deferred until landing. On `is_on_floor()` transition, if Ctrl was pressed during airtime, Eve enters Crouch immediately. No air-crouch silhouette changes (would be a modern verb — Pillar 5).

### E.3 Jump pressed while crouched
**Situation**: Player presses Space while in Crouch.
**Handling**: Jump input is ignored. No sound, no feedback. Eve must uncrouch first. Rationale: mantling small obstacles is a deliberate choice, not a panic reflex; letting crouch-jump work would create the "bunny-hop crouch" modern verb we explicitly reject.

### E.4 Interact during interact animation
**Situation**: Player holds E or presses E again during the 150 ms pause + 200–250 ms reach animation.
**Handling**: Subsequent E presses within the `is_hand_busy()` window are swallowed. The in-flight interaction resolves first. This prevents double-pickup glitches and keeps animation state deterministic.

### E.5 Interact ray hits two stacked interactables
**Situation**: A document rests on a desk with a terminal; the ray passes through both within 2.0 m.
**Handling**: F.5's iterative raycast collects up to `raycast_max_iterations` hits (default 4) and selects the one with the lowest priority value. Document (0) always beats Terminal (1), Terminal beats Pickup (2), Pickup beats Door (3) — regardless of geometric proximity along the ray. **Priority resolution is a code guarantee**; no level-design arrangement can defeat it within the iteration cap (Session D B-11).

**Minimum-separation rule (Session D B-15).** Interactable bodies on Layer 4 must be placed at least `interact_min_separation` apart (default 0.15 m, tunable) along any camera-ray axis originating from Eve's standing or crouched eye height. This rule is not enforced at runtime — it is a level-design QA constraint verified at content-review milestones. Its purpose is to keep the count of interactables along any plausible camera ray below `raycast_max_iterations` in practice. If violated AND more than `raycast_max_iterations` interactables overlap a single ray, the lowest-priority items beyond the cap are silently skipped — no crash, but the skipped items are unreachable without the player repositioning.

### E.6 Health damage while in Interact
**Situation**: Eve takes damage mid-interact-animation (guard shoots while reading a document).
**Handling**: Damage applies normally (`apply_damage` is state-agnostic). Interact animation is cancelled if damage crosses a threshold (≥ `interact_damage_cancel_threshold` in a single call, default 10 HP); otherwise it completes. If health reaches 0, animation cancels and `player_died` fires on the same frame. **`is_hand_busy()` clears synchronously on the same physics frame the cancel is applied** — the flag is reset in the same method call that stops the Tween/AnimationPlayer, not via an `animation_finished` callback (Session E-Prime R-8). This prevents a one-frame window where HUD suppresses the interact prompt for an animation that no longer exists.

### E.7 Simultaneous damage sources on same frame
**Situation**: Two bullets hit in one physics tick.
**Handling**: Each `apply_damage()` call processes sequentially. Two `player_damaged` signals fire (one per source); `player_health_changed` fires twice (with intermediate and final values); `player_died` fires at most once. HUD is tolerant of this ordering (per HUD Core GDD — uses final `player_health_changed` value).

### E.8 Spawn / respawn inside geometry
**Situation**: Save file places Eve inside a wall (edited save, engine rounding, mission script bug).
**Handling**: On `_ready()`, a depenetration shapecast runs: if the standing capsule overlaps static geometry, Eve is pushed upward by 1 m and tested again; up to 5 attempts before logging a fatal error and teleporting to the last checkpoint's fallback spawn. This is a safety net, not a gameplay feature.

### E.9 Movement input arrives before first physics frame
**Situation**: Player hammers movement keys during the mission fade-in, before `_physics_process` starts.
**Handling**: Input is accumulated in Godot's `InputEvent` buffer. On first `_physics_process`, the current action strengths are read normally — no input is dropped, no input is reprocessed. Fade-in does not disable input (per Pillar 1, no curtains; per Pillar 5, no modern onboarding lockout).

### E.10 Player holds Ctrl (crouch toggle) through scene transition
**Situation**: Eve crouches, then a mission trigger loads a new area.
**Handling**: Crouch state persists across Level Streaming loads (it's part of `PlayerState` per ADR-0003). On load completion, Eve is placed at the target position in Crouch state if Ctrl is still held. If the new area has a ceiling collision at the spawn, E.1 applies.

### E.11 Interact target destroyed mid-reach
**Situation**: The object being reached for is destroyed by a mission script or physics event during the 200–250 ms reach animation.
**Handling**: The reach animation completes, then `player_interacted` fires with `target = null`. Downstream systems must tolerate null target (documented in Signal Bus GDD). In practice, this is a rare edge case — script-driven destruction during reach is explicitly disallowed at Mission Scripting level.

### E.12 Character falls off navmesh (out-of-bounds)
**Situation**: Physics bug or level geometry gap lets Eve fall indefinitely.
**Handling**: A kill-plane trigger volume is placed below every level (at -50 m world Y). Crossing it calls `apply_damage(999.0, kill_plane_node, CombatSystem.DamageType.OUT_OF_BOUNDS)` (where `kill_plane_node` is the `Area3D` node owning the trigger volume, satisfying the `source: Node` contract), killing Eve and routing to the respawn system. No permadeath punishment — this is a bug recovery path, not a gameplay feature.

### E.13 Dead state entered with interact in-flight
**Situation**: `player_died` fires while `is_hand_busy()` is true.
**Handling**: Interact animation hard-cancels. Hand mesh snaps to "down" pose. `player_interacted` does NOT fire. Respawn will reset `current_state`, `is_hand_busy`, and cancel any queued interactions.

## Dependencies

### Upstream (this system depends on — these must exist first)

| System | GDD | Why needed |
|---|---|---|
| **Input** | `design/gdd/input.md` ✅ | Reads 26-action catalog (`move_forward/back/left/right`, `sprint`, `crouch`, `jump`, `interact`, `use_gadget`) |
| **Signal Bus** | `design/gdd/signal-bus.md` ✅ | Publishes `player_damaged`, `player_died`, `player_health_changed`, `player_interacted`, `player_footstep` |
| **Outline Pipeline** | `design/gdd/outline-pipeline.md` ✅ | Governs all non-hands outlined meshes (environment, civilians, guards — PlayerCharacter spawns none at MVP). Hands are exempted per ADR-0005. |
| **ADR-0001** (Stencil ID Contract) | `docs/architecture/adr-0001-stencil-id-contract.md` ✅ | Governs outline for every mesh class EXCEPT hands |
| **ADR-0005** (FPS Hands Outline Rendering) | `docs/architecture/adr-0005-fps-hands-outline-rendering.md` ✅ | Inverted-hull outline for hands mesh; single project-wide exception to ADR-0001 |
| **ADR-0002** (Signal Bus + Event Taxonomy) | `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` ✅ | Signal contracts (payload schemas, naming) |
| **ADR-0003** (Save Format Contract) | `docs/architecture/adr-0003-save-format-contract.md` ✅ | `PlayerState` sub-resource schema |

### Downstream (systems that depend on this one — interfaces they consume)

| System | Planned GDD | What they consume |
|---|---|---|
| **Stealth AI** | `design/gdd/stealth-ai.md` ⏳ | `get_noise_level()` (radius scalar, includes `noise_global_multiplier`), `get_noise_event() -> NoiseEvent` (discrete spike with NoiseType + origin, latched per F.4 — Session D B-12/B-13; **idempotent-read** per Session E-Prime AI-1: every guard polling within the latch window receives the same event), `get_silhouette_height()`, `global_transform.origin` (also used for continuous-locomotion noise localisation), `PhysicsLayers.LAYER_PLAYER` membership (per ADR-0006). Stealth AI owns noise propagation math (occlusion, elevation attenuation). Must NOT subscribe to `player_footstep` — that signal is an Audio-only channel. |
| **Combat & Damage** | `design/gdd/combat-damage.md` ⏳ | `apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType)` method; owns `DamageType → DeathCause` mapping consumed by F.6 on lethal blows |
| **Inventory & Gadgets** | `design/gdd/inventory-gadgets.md` ⏳ | `HandAnchor` node, `is_hand_busy()`, mesh attach point |
| **HUD Core** | `design/gdd/hud-core.md` ⏳ | `player_health_changed` signal; indirect (subscribes to bus, no direct coupling) |
| **Audio** | `design/gdd/audio.md` ✅ | `player_footstep(surface: StringName, noise_radius_m: float)` signal (FootstepComponent emits); `player_died` for mix ducking |
| **Failure & Respawn** | `design/gdd/failure-respawn.md` ⏳ | `player_died` signal subscription; sets `global_transform` + `health` on respawn |
| **Mission & Level Scripting** | `design/gdd/mission-scripting.md` ⏳ | Position queries (`global_transform.origin`); `player_interacted` signal |
| **Save / Load** | `design/gdd/save-load.md` ✅ | `PlayerState` sub-resource (position, rotation, health, state) — stamina field removed per Session A. |
| **Document Collection** | `design/gdd/document-collection.md` ⏳ (VS) | `player_interacted(target)` with `target.interact_type == Document` |

### Bidirectional dependency statements (for cross-GDD consistency checks)

- **Stealth AI** must document: "reads `player.get_noise_level()`, `player.get_noise_event()` (idempotent-read; never clears the latch — auto-expiry is the sole clear per F.4), and `player.get_silhouette_height()` per perception tick; queries `player.global_transform.origin` for continuous-locomotion noise localisation; owns propagation math (wall occlusion, elevation attenuation, surface modifiers); does not subscribe to `player_footstep`; does not mutate player state; callers needing to remember a spike must copy `{type, radius_m, origin}` into their own state — reference retention across frames reads subsequent-spike fields."
- **Combat & Damage** must document: "delivers damage via `player.apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType)`; owns the `DamageType → DeathCause` mapping used for `player_died`; subscribes to `player_damaged` only for logging / analytics."
- **Inventory & Gadgets** must document: "attaches held item mesh to `player.HandAnchor`; queries `player.is_hand_busy()` before showing interact prompts."
- **Failure & Respawn** must document: "subscribes to `player_died`; owns respawn sequence; resets player state via `reset_for_respawn(checkpoint)` method on PlayerCharacter."
- **Save / Load** must document: "serializes `PlayerState` sub-resource; deserializes on checkpoint load."

### Dependency risk notes

- **Stealth AI** is the gating technical-risk system (systems-index §Risk). Its perception model validates Player Character's noise interface. The Session D B-12/B-13 revision added `NoiseType` + `origin` + latched-event delivery; Session E-Prime AI-1 made the latch idempotent-read (all guards within the window see the same event). If Stealth AI discovers it needs additional data (e.g., velocity-weighted noise scaling per OQ-7, per-surface audibility weighting, noise propagation through walls), F.4's `NoiseEvent` fields will need extension without breaking the pull-method contract. A concrete risk to monitor: `player_footstep` signal and `get_noise_level()`/`get_noise_event()` pull methods are intentionally separate channels (signal → Audio only, pull → AI only) — any implementer that blurs this boundary creates duplicate perception paths. Enforce at code review.
- **Noise propagation responsibility (Session E-Prime AI-3 / AI-R1).** Player Character publishes the noise SOURCE: origin, radius, type. Stealth AI owns PROPAGATION: wall occlusion raycasts, elevation attenuation (NOLF1 precedent: noise does not penetrate floors; cross-floor audibility is zero), surface absorption, and all per-guard distance/LOS modifiers. PC's radius is a sphere of authorial intent; Stealth AI clips it against the world. This split is load-bearing — if it blurs, PC will accrete AI-specific fields (occluded_from_guard[N]) that violate its single-responsibility boundary.
- **Continuous footstep localisation (AI-R2).** For Walk / Sprint / Crouch, no `NoiseEvent` is produced and `NoiseEvent.origin` is therefore unavailable. Stealth AI localises continuous-locomotion noise by querying `player.global_transform.origin` directly each perception tick. This is part of the consumed interface, not a workaround — documented for cross-GDD consistency.
- **Combat & Damage** currently assumes integer HP and no armor. `damage_type` is already part of `apply_damage`; if armor, resistance, or damage-type-specific multipliers land later, `CombatSystem.damage_type_to_death_cause` and Combat & Damage's own balance logic absorb the change without touching this GDD's interface.
- **Inventory & Gadgets**' `HandAnchor` attach point must live on the camera (not the body) so held items follow the first-person view. This is a constraint on both GDDs.

## Tuning Knobs

All values exposed as `@export` properties on the `PlayerCharacter` resource (or via a dedicated `PlayerTuning.tres` resource referenced by the scene). Safe ranges are tested; values outside may compile but produce broken feel.

### Movement speeds (m/s)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `walk_speed` | 3.5 | 2.8 – 4.2 | Baseline exploration pace. Below 2.8 feels sluggish; above 4.2 reads as "jog" and breaks the Deadpan Witness fantasy. |
| `sprint_speed` | 5.5 | 4.5 – 6.5 | Tactical burst speed. Below 4.5 makes sprint feel pointless; above 6.5 reads as parkour. |
| `crouch_speed` | 1.8 | 1.4 – 2.2 | Stealth speed. Below 1.4 frustrates; above 2.2 makes crouch the default movement. |

### Acceleration times (seconds)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `walk_accel_time` | 0.12 | 0.08 – 0.18 | Input responsiveness at walk. Lower = twitchier (breaks fantasy); higher = sluggish. |
| `walk_decel_time` | 0.18 | 0.12 – 0.25 | Stop crispness. |
| `sprint_accel_time` | 0.15 | 0.10 – 0.22 | Sprint ramp-up feel. |
| `crouch_transition_time` | 0.12 | 0.08 – 0.18 | Duration of crouch camera drop + collider shrink. |

**Inspector validation (Session D B-7).** Each of the three acceleration knobs above is annotated `@export_range(<safe_min>, <safe_max>, 0.01)` in code so the Godot Inspector constrains designer input to the Safe Range column. F.1 additionally applies a `max(value, 0.001)` NaN guard inside the formula so deserialised or out-of-band zero values cannot produce Inf/NaN velocities. `crouch_transition_time` is an animation duration, not a rate divisor — it carries no divide-by-zero risk and is unaffected.

### Vertical (m, m/s, m/s²)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `gravity` | 12.0 | 9.8 – 15.0 | Fall speed. Lower = floaty; higher = weighty. Affects jump apex + airtime. |
| `jump_velocity` | 3.8 | 3.0 – 5.0 | Jump height. At 3.8 + g=12, apex is 0.60m. Changing affects mantle-ability. |
| `hard_land_height` | 1.5 | 1.0 – 3.0 m | Drop height that triggers camera dip + 8 m noise spike. Threshold velocity computed at runtime: `v_land_hard = sqrt(2 × gravity × hard_land_height)`. Changing `gravity` automatically rescales (Session D B-8). |
| `kill_plane_y` | -50.0 | -100 to -20 | World Y below which out-of-bounds kill fires. |

**`gravity` × `hard_land_height` interaction (Session D B-8).** Across full safe-range extremes, `v_land_hard` spans [sqrt(2×9.8×1.0) ≈ 4.43, sqrt(2×15.0×3.0) ≈ 9.49] m/s. If both knobs are pushed to opposite extremes simultaneously, landing feel may drift out-of-tune with other landing-sensitive systems (camera dip duration, noise spike, OQ-2 fall damage). Confirm landing feel after any change pair.

### Camera

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `camera_fov` | 75° | 70° – 90° | Horizontal FOV. Lower = claustrophobic + period-correct (1965 film lenses); higher = modern. |
| `camera_y_standing` | 1.6 | 1.5 – 1.7 | Eye height. Matches Eve's 1.70m body. |
| `camera_y_crouched` | 1.0 | 0.9 – 1.1 | Crouched eye height. |
| `pitch_clamp_deg` | 85 | 80 – 89 | Max look up/down. 85 avoids gimbal flip. |
| `turn_overshoot_deg` | 4.0 | 2.5 – 4.5 | Deadpan Witness camera settle. Raised from 2.5° in Session E-Prime R-1 — 2.5° was below perceptual threshold at 1080p (≈27 px at screen edge). 4° is clearly perceptible without reading as drunk. Zero kills the fantasy; above 4.5° reads as drunk/motion-sick. Playtest-validate with AC-7.2b. |
| `turn_overshoot_return_ms` | 90 | 60 – 120 | Settle duration. |
| `mouse_sensitivity_x` | 1.0 | 0.2 – 3.0 | Horizontal mouse yaw multiplier. Applied to raw `InputEventMouseMotion.relative.x` before camera yaw update. 1.0 = raw Godot delta (user-perceived "medium"). |
| `mouse_sensitivity_y` | 1.0 | 0.2 – 3.0 | Vertical mouse pitch multiplier. Independent X/Y allows asymmetric sensitivity (common accessibility preference). |
| `gamepad_look_sensitivity` | 2.4 | 1.0 – 4.5 | Gamepad right-stick look rate in rad/s at full deflection. Separate from mouse — gamepad uses continuous rate, mouse uses per-event delta. |

**Sensitivity ownership (reconciled with Input GDD §Formulas and §Open Questions, Session C R-16, 2026-04-19):** Input GDD owns raw event capture (`InputEventMouseMotion`, gamepad axis + deadzone per `Input.get_vector()`). PC GDD owns the transformation from raw event to camera rotation delta, including the three knobs above. Settings & Accessibility autoload persists runtime overrides to `user://settings.cfg`; PC GDD's defaults are the shipped values; per-player overrides win at runtime.

### Interact

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `interact_ray_length` | 2.0 | 1.5 – 3.0 | Reach distance. Below 1.5 requires players to nose into objects; above 3.0 causes ghost-interact at a distance. |
| `interact_pre_reach_ms` | 150 | 100 – 250 | Deadpan Witness pause before hand moves. Zero kills fantasy. |
| `interact_reach_duration_ms` | 225 | 180 – 300 | Hand reach animation duration. |
| `interact_damage_cancel_threshold` | 10 | 5 – 20 | HP damage that cancels in-flight interact (E.6). |
| `raycast_max_iterations` | 4 | 2 – 6 | Maximum stacked interactables sampled per interact-press (F.5). Higher = more robust to stacking, ≈0.05 ms per extra iteration on Jolt. Never below 2 (breaks Document-over-Terminal case). Session D B-11. |
| `interact_min_separation` | 0.15 | 0.0 – 0.5 m | Minimum distance between Layer 4 interactable bodies along any camera ray (E.5). Level-design QA constraint, not enforced at runtime. 0.0 disables the rule. Session D B-15. |

### Health

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `max_health` | 100 | 50 – 200 | Ceiling. Changing requires Combat & Damage rebalancing. |
| `starting_health` | 100 | — | Always equal to `max_health` at mission start. Not a designer-tuned knob per mission. |

### Noise (meters, state-keyed)

All noise values (F.4 table) are tuning knobs individually. Global multiplier:

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `noise_global_multiplier` | 1.0 | 0.7 – 1.3 | Uniform scaling of all noise radii (applied at `get_noise_level()` return, including both continuous state values and latched spike `radius_m` — Session E-Prime SD-2). **Designer-tuning scalar only — NOT a player-facing difficulty selector** (cross-review GD-B1, 2026-04-20). The game ships with no Difficulty Selection (see systems-index "Deliberately Omitted Systems"). This knob exists so the designer can globally dial guard perception during balance passes without editing each per-state noise value; any future accessibility-facing noise scaling would be a deliberate scope expansion requiring a new ADR. |
| `idle_velocity_threshold` | 0.1 | 0.05 – 0.3 m/s | Speed below which Walk or Crouch state returns `get_noise_level() == 0.0` (Idle-silent). Prevents still-crouching Eve from emitting 3.0 m noise. Session E-Prime R-10. |
| `spike_latch_duration_sec` | 0.1 | 0.1 – 0.2 s | Seconds a discrete `NoiseEvent` stays latched if auto-expiry is the only clear (Session E-Prime AI-1 — idempotent-read does not clear). Converted at runtime: `spike_latch_duration_frames = int(spike_latch_duration_sec × Engine.physics_ticks_per_second)`. Default 0.1 s = 6 frames @ 60 Hz = one 10 Hz AI tick window. Raising to 0.2 s gives jitter safety margin; below 0.1 s may re-introduce AI-tick miss. Physics-tick-rate-independent (Session E-Prime R-17 — matches Δt-clamp pattern). |
| `coyote_time_frames` | 3 | 2 – 6 | Physics frames the Jump trigger tolerates `is_on_floor() == false` after last true (Jolt stair-edge transient — R-13 placeholder; will re-parameterize in Session E batch 2). Also gates the Ground → Fall ledge walk-off to preserve late-jump intent. |

### Tuning authority

- **Game Designer** owns: speeds, acceleration times, health, noise
- **Art Director** owns: camera overshoot, crouch transition timing, interact pre-reach pause (Player Fantasy feel)
- **Gameplay Programmer** owns: `kill_plane_y`, collision-layer constants, ceiling shapecast dimensions (safety/correctness, not designer-tunable)

## Visual/Audio Requirements

### Visual — FPS Hands Mesh

- **Geometry**: One skinned mesh, low-poly (~5k tris target), rigged with a minimal arm + hand skeleton (shoulder, elbow, wrist, 5 finger chains; 18 bones total).
- **Material**: Courrèges navy glove/sleeve palette (Art Bible §5.1). Matte, no specular. Single 1024² albedo texture.
- **Outline**: Visually matches tier HEAVIEST (4 px at 1080p, color `#1A1A1A`) but achieved via inverted-hull shader per **ADR-0005**, NOT via ADR-0001 stencil. Hands are the project's single documented exception to the stencil contract. The `HandsOutlineMaterial` shader's `resolution_scale` uniform is wired to `Settings.get_resolution_scale()` so hands outline scales in lockstep with the world outline on Iris Xe (75%) and native (100%). Outline always visible in gameplay — hands are diegetic UI.
- **Default pose**: Arms down, slightly forward, hands relaxed. This is the "idle FPS rest" shown when no gadget is equipped.
- **Attach points**:
  - `HandAnchor` (child node of the Camera3D, not the body) — Inventory & Gadgets attaches the held gadget mesh here.
  - `LeftHandIK`, `RightHandIK` — used for gadget-specific two-handed poses (lockpick, camera).
- **Camera relationship**: Hands render inside a `SubViewport` at FOV 55° (narrower than world FOV 75°) to prevent "stretched gorilla arms" and avoid clipping through world geometry. The SubViewport is composited over the main view via a `CanvasLayer` (layer 10) AFTER the world's outline `CompositorEffect` completes. Outline is baked into the SubViewport via `HandsOutlineMaterial`'s inverted-hull pass per ADR-0005 — no stencil dependency, no call to `OutlineTier.set_tier` on the hands mesh.

### Visual — Camera Feel (per art-director spec)

| Behavior | Spec |
|---|---|
| Head-bob (walk) | **None** — Deadpan Witness requirement. Walking is steady. |
| Sway (sprint) | Shallow lateral sway, ~0.8 s period, ~0.5° amplitude. |
| Turn overshoot | 4.0° overshoot (default; safe 2.5–4.5° per Tuning Knob), 90 ms ease-out return on rapid mouse yaw deltas (> 180°/s). Raised from 2.5° in Session E-Prime R-1 — prior value was below perceptual threshold at 1080p. |
| Crouch drop | 120 ms ease-in-out, camera Y from 1.6 → 1.0 m. |
| Landing (soft) | No visible dip. |
| Landing (hard, `> v_land_hard`) | 4–6° downward pitch dip, 150 ms ease-out. Threshold runtime-derived per F.3 — 6.0 m/s at shipped defaults. |
| Interact pre-reach | 150 ms pause — camera does NOT move. Hand does not move. Eve is *noticing*. |
| Interact reach | 200–250 ms hand extension animation; camera unaffected. |

### Visual — Dead State

- Camera pitches down 60° over 800 ms, translates down to Y = 0.4 m (head on floor). No dramatic slow-motion. No red vignette (Pillar 5). Screen fades to sepia over 1.5 s then hard-cuts to the Failure & Respawn screen.

### Audio — Footstep Surfaces

Owned by **FootstepComponent** (child of PlayerCharacter). Emits `player_footstep(surface: StringName, noise_radius_m: float)` per step (per ADR-0002 Player domain, added 2026-04-19). Audio GDD §Footstep Surface Map owns the surface→SFX mapping. **This signal is an Audio-only channel** (Session D B-12 delineation). The `noise_radius_m` field is the SFX-variant loudness cue, not an AI-perception channel — Stealth AI reads footstep audibility through `get_noise_level()` / `get_noise_event()` exclusively (F.4 contract). A Stealth AI implementation that subscribed to `player_footstep` would bypass the pull contract and violate the single-perception-path rule. Player Character defines only the surface tag set that must exist:

- `marble` (Plaza)
- `tile` (Restaurant kitchen)
- `wood_stage` (Cabaret)
- `carpet` (Office Suite, cinema-floor corridors)
- `metal_grate` (Observation Deck service ladders)
- `gravel` (Plaza outdoor — Tier 2 Rome also)
- `water_puddle` (rare, mission-script spawned)

Step cadence (Hz per state):
- Walk: 2.2 Hz (0.45 s per step)
- Sprint: 3.0 Hz (0.33 s per step)
- Crouch: 1.6 Hz (0.63 s per step)

**Loudness** is the numeric output of `get_noise_level()` at the moment of the step — Audio uses this to pick the SFX variant (soft/normal/loud within a surface set).

### Audio — Vocal / Breathing

- **Idle**: quiet continuous breath loop, volume **−24 dB** relative to footsteps. Subtle enough to never mask ambient or dialogue; absence would read as dead silence. (Resolves review item R-22 — Hitman/NOLF1 precedent.)
- **Walk**: same quiet breath loop continues — not stride-tied.
- **Sprint**: subtle breathing loop layered under footsteps, volume **−12 dB** relative to footsteps. Replaces the idle loop while Sprint is active (single breath bed, not a stack).
- **Hard landing**: single "huf" vocal (no pain, no grunt — Deadpan Witness).
- **Dead**: single controlled exhale (150 ms), then silence. No cry, no scream (Pillars 1, 5).

**Vocal talent constraint**: Eve's voice actress (TBD per future narrative GDD) records all breathing + vocalization lines. No placeholder male "ughs" from library packs.

### Audio — Interact

- Pre-reach pause (150 ms): silent.
- Reach animation (200–250 ms): subtle fabric-rustle SFX (Courrèges glove sliding).
- On resolution (document pickup, terminal touch, etc.): the respective downstream system owns the pickup/activation SFX. Player Character does not emit an interact-complete sound.

### Audio — Mix Bus Routing

All PlayerCharacter body sound routes through the canonical `SFX` bus defined by the Audio GDD (5-bus model: `Music`, `SFX`, `Ambient`, `Voice`, `UI`). The previous `SFX_WORLD` / `SFX_FOLEY` split was incorrect — no such sub-buses exist. "Foley" survives as an asset-spec authoring convention (stem tagging for sound-designer variant management + loudness normalization), not as a bus.

- Footsteps → `SFX` bus
- Breathing → `SFX` bus (ducks under VO per Audio GDD Rule 7, as Foley should)
- Hard landing → `SFX` bus
- Dead-state exhale → `SFX` bus

**Why not the `Voice` bus for breathing?** `Voice` is reserved for dialogue per Audio GDD Rule 7 (it's the VO source that triggers Music/Ambient ducking and is itself never ducked). Breathing is body Foley, not vocal communication.

All bus names per Audio GDD §Mix Buses.

### Visual — Mirror Reflection Handling (MVP deferral)

- Eve has no full body mesh at MVP. Mirrors (bathroom in Office Suite, vanity in Cabaret) reflect only the environment + a silhouette decal. Full body mesh for mirror reflection is a VS-tier stretch (see Open Questions).

## UI Requirements

**Ownership**: Player Character provides signals and state; HUD Core GDD owns the actual on-screen widgets. This section specifies what Player Character promises to HUD, not what HUD looks like.

### Signals published (for HUD consumption)

| Signal | Payload | HUD behavior |
|---|---|---|
| `player_health_changed` | `(current: float, max_health: float)` | Updates numeric health readout. Art Bible 7B — NOLF1-style numeric display, not a segmented bar. |
| `player_damaged` | `(amount: float, source: Node, is_critical: bool)` | Optional: flash the health number briefly (~150 ms) to draw attention. Not a damage direction indicator — Pillar 5 rejects modern damage-edge vignettes. `is_critical` is always `false` at MVP (see Core Rules → Health). |
| `player_died` | `(cause: CombatSystem.DeathCause)` | Transitions HUD into the fail-screen pathway owned by Failure & Respawn. |
| `player_interacted` | `(target: Node3D or null)` | HUD can clear the interact highlight on receipt. |

### State queries (for HUD polling)

| Query | Return | HUD use |
|---|---|---|
| `get_current_interact_target() -> Node3D or null` | Current raycast hit (null if no target in 2.0 m) | HUD shows the interact prompt label + highlights the target's outline (tier 2 per ADR-0001). |
| `is_hand_busy() -> bool` | True during 150 ms pre-reach + 200–250 ms reach window | HUD suppresses the interact prompt while busy (avoids "press E" reappearing mid-animation). |

### Elements the HUD must render (spec lives in HUD Core GDD; listed here for cross-reference)

- Health readout — numeric, three-digit space (`100`, `099`, `008`).
- Critical-health state — when health < 25, color shifts to Alarm Orange (Art Bible 4.4). No pulsing, no flashing (Pillar 1 — no panic signaling).
- Interact prompt — brief text label near center-screen, e.g. "Read note", "Open door", "Take keycard". Localized per Localization Scaffold GDD.
- Gadget readout — the Inventory & Gadgets GDD's slot indicator (not this system's responsibility to define shape).

### Elements the HUD must NOT render (explicit negatives)

- ❌ Stamina bar (Pillar 5 — no stamina UI)
- ❌ Crouch indicator icon (Pillar 5 — no modern state indicators)
- ❌ Damage direction indicator (Pillar 5)
- ❌ Sprint cooldown meter (Pillar 5)
- ❌ Crosshair variants per weapon state (HUD owns crosshair, but no "hit marker" feedback — Pillar 1)
- ❌ "Press E" prompt with a circular hold-progress ring (NOLF1 fidelity — single tap only)

### Accessibility

- Interact prompt text respects the UI scaling setting (ADR-0004 Theme inheritance).
- Critical-health Alarm Orange is paired with a number (e.g., `008`) so colorblind players read the value, not just the hue (Art Bible 4.4 accessibility commitment).
- Interact highlight outline is always shown (tier 2) — not a color-only affordance.

### Input responsiveness promise

- Health numeric update fires within one physics frame of damage resolution (< 16.7 ms).
- Interact prompt appears within one physics frame of target entering the 2.0 m ray (< 16.7 ms).
- Crouch state change triggers no UI element — only the camera and collider change.

## Cross-References

### Upstream GDDs

- **[Input](input.md)** — 26-action catalog (Ctrl for crouch, Shift for sprint, Space for jump, E for interact, F for use_gadget)
- **[Signal Bus](signal-bus.md)** — event taxonomy (`player_*` signals in the Player domain)
- **[Outline Pipeline](outline-pipeline.md)** — tier registration on spawn for any non-hands meshes PlayerCharacter spawns (none at MVP; hands are the ADR-0005 exception)
- **[Post-Process Stack](post-process-stack.md)** — sepia dim on death sequence
- **[Audio](audio.md)** — footstep surface map, breathing SFX, mix buses

### Downstream GDDs (not yet written — this GDD defines their contracts)

- **Stealth AI** — reads `get_noise_level()` + `get_noise_event() -> NoiseEvent` (latched discrete-spike delivery per F.4, Session D B-12/B-13), `get_silhouette_height()`, position via `PhysicsLayers.LAYER_PLAYER` (per ADR-0006); must NOT subscribe to `player_footstep`
- **Combat & Damage** — calls `apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType)`; owns `DamageType → DeathCause` mapping
- **Inventory & Gadgets** — attaches to `HandAnchor`, queries `is_hand_busy()`
- **HUD Core** — subscribes to `player_health_changed`, polls `get_current_interact_target()`
- **Failure & Respawn** — subscribes to `player_died`, calls `reset_for_respawn(checkpoint)`
- **Mission & Level Scripting** — queries position, subscribes to `player_interacted`
- **Document Collection** (VS) — consumes `player_interacted` with `Document` target type

### Required ADRs

- **[ADR-0001 — Stencil ID Contract](../../docs/architecture/adr-0001-stencil-id-contract.md)** — outline tier contract (hands exempted per ADR-0005)
- **[ADR-0002 — Signal Bus + Event Taxonomy](../../docs/architecture/adr-0002-signal-bus-event-taxonomy.md)** — signal signatures, no per-frame signals rule
- **[ADR-0003 — Save Format Contract](../../docs/architecture/adr-0003-save-format-contract.md)** — `PlayerState` sub-resource schema
- **[ADR-0004 — UI Framework](../../docs/architecture/adr-0004-ui-framework.md)** — Theme inheritance for HUD elements driven by Player Character state
- **[ADR-0005 — FPS Hands Outline Rendering](../../docs/architecture/adr-0005-fps-hands-outline-rendering.md)** — inverted-hull technique for hands; project-wide exception to ADR-0001
- **[ADR-0006 — Collision Layer Contract](../../docs/architecture/adr-0006-collision-layer-contract.md)** — `PhysicsLayers` constants for all collision layer and mask references

### Art Bible references

- **Art Bible §5.1 — Character Art Direction** — Eve's outfit (Courrèges navy), silhouette, visible FPS mesh palette
- **Art Bible §7B — HUD Direction** — numeric health readout (NOLF1-style, not a bar)
- **Art Bible §4.4 — Color Palette** — Alarm Orange for critical health, Comedy Yellow restrictions

### Game Concept references

- **Game Concept §Pillar 1** — Comedy Without Punchlines (Deadpan Witness fantasy)
- **Game Concept §Pillar 3** — Stealth is Theatre (cinematic movement, generous interact)
- **Game Concept §Pillar 5** — Period Authenticity (no modern movement verbs, no stamina system — visible or hidden)
- **Game Concept §Visual Identity Anchor** — no state-color-signaling (reinforces "no damage vignette" rule)

### Systems Index

- **[Systems Index](systems-index.md)** — System 8, MVP Core, M effort, Layer 2

### External references (NOLF1 fidelity targets)

- *No One Lives Forever* (2000) — single-button interact, no quip-on-pickup, no stamina UI, tactical-but-not-twitch movement speed
- *Thief: The Dark Project* (1998) — noise radius as core stealth mechanic (Player Character's F.5 lookup table descends from this)
- *The Avengers* (1960s TV) — Emma Peel's camera-tilt-as-eyebrow reference (Deadpan Witness)

## Acceptance Criteria

Each criterion is binary (pass/fail). Story-type labels (`[Logic] / [Integration] / [Visual/Feel] / [UI]`) and test-evidence file paths are scheduled to be added progressively — full coverage is tracked as Session E batch 2 (R-26/R-27). Currently only AC-10.1/10.2 carry labels; the remaining ACs are implementable-as-worded, but the labeling pass is required before the implementation gate. Organized by subsystem.

### AC-1: Movement speeds

- **AC-1.1** Walking forward on flat `marble` at full input magnitude achieves 3.5 m/s steady-state within 0.15 s of key press. Verified by movement log + timestamp.
- **AC-1.2** Sprinting from rest reaches 5.5 m/s within 0.20 s. No time or resource cap — sprint is unlimited (see Rejected features).
- **AC-1.3** Crouch-walking reaches 1.8 m/s within 0.15 s. Collider height is 1.1 m; camera Y is 1.0 m.
- **AC-1.4** Releasing all movement input during sprint brings velocity to 0 within 0.20 s.

### AC-2: Crouch behavior

- **AC-2.1** Pressing Ctrl while standing under a clear ceiling transitions to Crouch within 0.12 s; camera Y animates smoothly from 1.6 to 1.0 m.
- **AC-2.2** Pressing Ctrl while under a low ceiling (clearance < 1.7 m from floor) leaves Eve in Crouch; a head-bump SFX plays. No visual UI indicator.
- **AC-2.3** Pressing Space in Crouch state: Eve does not jump, no sound plays, no visual feedback.

### AC-3: Jump and landing

- **AC-3.1** Jump from flat ground reaches ~0.60 m apex (measured: 0.58–0.62 m acceptable).
- **AC-3.2** Total airtime from flat-ground jump is 0.60–0.66 s.
- **AC-3.3** Landing from heights < 1.5 m produces no camera dip and no 8 m noise spike.
- **AC-3.4** Landing from heights ≥ `hard_land_height` (default 1.5 m) produces a 4–6° downward camera pitch dip over 150 ms, latches a `NoiseEvent` with `type == NoiseType.LANDING_HARD` and `radius_m == 8.0`, and `get_noise_level()` returns `8.0 × noise_global_multiplier` until the latch auto-expires after `spike_latch_duration_sec × Engine.physics_ticks_per_second` physics frames (default 0.1 s = 6 frames @ 60 Hz). The latch is idempotent-read per F.4 (Session E-Prime AI-1) — `get_noise_event()` returns the same event for all callers within the window and never clears it; auto-expiry is the sole clear mechanism. Session D B-13; revised Session E-Prime AI-1 + R-17.
- **AC-3.5** Crossing world Y = -50 m triggers `player_died` signal within one physics frame.

### AC-4: Interact behavior

- **AC-4.1** With an Interactable (`PhysicsLayers.LAYER_INTERACTABLES`) within 2.0 m of camera along forward vector, `get_current_interact_target()` returns that collider.
- **AC-4.2** Pressing E with a valid target starts a 150 ms pre-reach pause; hand mesh does not move during this window.
- **AC-4.3** After the 150 ms pause, the reach animation plays for 200–250 ms; `is_hand_busy()` returns true throughout.
- **AC-4.4** `player_interacted` signal fires exactly once on reach-complete.
- **AC-4.5** With two overlapping Interactables of types Document and Door within 2.0 m, pressing E resolves to the Document (priority 0 wins over 3).
- **AC-4.6** Additional E presses during `is_hand_busy()` are swallowed; only the first interaction resolves.
- **AC-4.7** Sprint input is ignored during the interact window; movement continues at walk speed if held.

### AC-5: Noise interface

- **AC-5.1** `get_noise_level()` returns the correct state-keyed value (0.0 / 5.0 / 9.0 / 3.0 for Idle/Walk/Sprint/Crouch while moving, `noise_global_multiplier == 1.0`) when no spike is latched. With `noise_global_multiplier == 0.7`, each returned value is multiplied by 0.7 (walk = 3.5 m, sprint = 6.3 m, crouch = 2.1 m). Walk-at-rest and Crouch-at-rest (`velocity.length() < idle_velocity_threshold`) return 0.0 regardless of multiplier. Session E-Prime R-10, SD-2.
- **AC-5.2** Jump takeoff latches a `NoiseEvent` such that `get_noise_level()` returns 4.0 (× multiplier) and `get_noise_event()` returns an event with `type == NoiseType.JUMP_TAKEOFF`, `radius_m == 4.0`, and `origin` equal to the player's world-space position at the frame the takeoff was recorded (within floating-point tolerance). **Repeated calls to `get_noise_event()` within the latch window return the same event** (idempotent-read — Session E-Prime AI-1); the latch clears only by auto-expiry.
- **AC-5.3** Hard landing (`|velocity.y| > v_land_hard`, where `v_land_hard = sqrt(2 × gravity × hard_land_height)`) latches a `NoiseEvent` such that `get_noise_level()` returns 8.0 (× multiplier) and `get_noise_event()` returns an event with `type == NoiseType.LANDING_HARD`, `radius_m == 8.0`, and `origin` at the landing site. Soft landings (`|velocity.y| ≤ v_land_hard`) emit `NoiseType.LANDING_SOFT` with `radius_m == 5.0` by the same contract. Idempotent-read applies.
- **AC-5.4** Multi-guard parity (Session E-Prime AI-1): eight stub AI consumers polling `get_noise_event()` at staggered 10 Hz intervals within a single latch window ALL receive the same non-null `NoiseEvent` (same reference, same field values). No consumer sees null during the window unless polled after auto-expiry.
- **AC-5.5** Highest-radius-wins collapse: recording a `JUMP_TAKEOFF` spike (4.0 m) followed by a `LANDING_SOFT` spike (5.0 m) within 2 physics frames causes `get_noise_event()` to return the `LANDING_SOFT` event (5.0 m wins) for the remainder of the latch window. `get_noise_level()` correspondingly steps up from 4.0 × multiplier to 5.0 × multiplier. The opposite order (soft landing then takeoff) preserves the 5.0 m landing event (equal-or-lower new radius does not overwrite).
- **AC-5.6** Latch auto-expiry: recording a spike and then advancing `int(spike_latch_duration_sec × Engine.physics_ticks_per_second) + 1` physics frames causes the next `get_noise_event()` call to return null (latch cleared by auto-expiry, the sole clear mechanism). `get_noise_level()` during the expired window returns the continuous state-keyed value, not the spike value. Session E-Prime R-17 physics-tick-rate independence.

### AC-6: Health and damage

- **AC-6.1** Calling `apply_damage(25.0, test_source_node, CombatSystem.DamageType.TEST)` reduces health from 100 to 75 and emits `player_damaged(25.0, test_source_node, false)` then `player_health_changed(75.0, 100.0)` in that order.
- **AC-6.2** Calling `apply_damage(999.0, test_source_node, CombatSystem.DamageType.TEST)` from full health reduces health to 0, emits `player_died(cause)` exactly once where `cause == CombatSystem.damage_type_to_death_cause(DamageType.TEST)` (`DeathCause.UNKNOWN` if TEST is unmapped), and transitions state to `MovementState.DEAD`.
- **AC-6.3** In `MovementState.DEAD`, subsequent `apply_damage` calls do not emit additional signals.
- **AC-6.4** Two `apply_damage(10.0, test_source_node, CombatSystem.DamageType.TEST)` calls on the same physics frame emit two `player_damaged` signals and two `player_health_changed` signals.
- **AC-6.5** `player_damaged` with `amount ≥ 10` during an interact-in-flight cancels the interact animation; `player_interacted` does NOT fire.

### AC-7: Camera

- **AC-7.1** Horizontal FOV is 75° by default; pitch is clamped to ±85°; yaw is unconstrained.
- **AC-7.2** Rapid mouse yaw (> 180°/s) produces a 4.0° overshoot (± 0.5° tolerance per Tuning Knob safe range 2.5–4.5°) and 90 ms settle. Session E-Prime R-1 raised default from 2.5°.
- **AC-7.3** Sprint produces lateral sway of ~0.5° amplitude with ~0.8 s period.
- **AC-7.4** Walk produces no head-bob.

### AC-8: Serialization

- **AC-8.1** Saving mid-mission writes a `PlayerState` resource containing `position: Vector3`, `rotation: Vector3`, `health: int`, and `current_state: int` (a `PlayerCharacter.MovementState` enum value — serialized as int, NOT as a string). Stamina field is NOT written (removed per Session A).
- **AC-8.2** Loading a save places Eve at the serialized position with serialized health restored exactly (no drift).
- **AC-8.3** If the saved state was Crouch, Eve loads in Crouch (assuming ceiling clearance).

### AC-9: Signal taxonomy conformance

- **AC-9.1** All player signals (`player_damaged`, `player_died`, `player_health_changed`, `player_interacted`, `player_footstep`) are emitted through the `Events` autoload (per ADR-0002), not via direct node-to-node connections.
- **AC-9.2** No signal fires at a rate exceeding 30 Hz during normal gameplay (ADR-0002 anti-pattern guard).
- **AC-9.3** `get_noise_level()` is a method call, not a signal (ADR-0002 compliance).

### AC-10: Outline pipeline conformance

- **AC-10.1** [Logic] On `_ready()`, the hands `MeshInstance3D` has `HandsOutlineMaterial` applied via `material_overlay` per ADR-0005 (NOT `material_override` — overlay compositing preserves the mesh's per-surface PBR materials for the fill pass; override clobbers them). The material's `resolution_scale` uniform equals `Settings.get_resolution_scale()` on `_ready()` AND updates within one frame when `Events.setting_changed` fires for the `"resolution_scale"` key (Session E-Prime GDT-R6 runtime-settings coherence). The hands mesh does NOT appear in any `OutlineTier.set_tier` call — enforced by a `forbidden_pattern` CI lint rule (`hands.*OutlineTier\.set_tier`), not by an AC-level grep.
- **AC-10.2** [Visual/Feel] Hands outline is visible in all gameplay lighting conditions and during the sepia-dim death sequence. Outline visually matches tier HEAVIEST (4 px at 1080p, `#1A1A1A`) within perceptual tolerance of adjacent stencil-outlined world geometry.

### AC-11: Pillar compliance (design audit)

- **AC-11.1** No head-bob, no sprint whoosh, no damage-edge vignette, no stamina bar, no hold-E interact meter, **no stamina system of any kind (visible or hidden)** exist in shipping build (Pillar 5).
- **AC-11.2** Damage feedback is numeric + audio only (no screen-blood, no red-tinted edges — Pillar 1).
- **AC-11.3** Interact prompt uses dry, short text (e.g., "Take note" — not "INTERACT!" or "PRESS E TO PICK UP THE CRITICAL INTEL"). Pillar 1.

## Open Questions

### OQ-1: Health regeneration policy — **RESOLVED 2026-04-20 (cross-review GD-B2)**

**Decision**: **Option A — No regen. HP restored only by diegetic medkit pickups in mission sections + save reloads.** Most NOLF1-faithful; fits all three relevant pillars (Pillar 1 no modern verbs, Pillar 3 no death-as-strategy trap because pickups exist, Pillar 5 period-authentic — medkits are diegetic 1965 props, not a regen meter).

**Downstream obligations** (flagged for authoring):
- **Mission & Level Scripting GDD** (Not Started): must place health pickups in mission sections — density tuning is its job, but each section must have at least 1 pickup reachable without backtracking past a point-of-no-return.
- **Inventory & Gadgets GDD** (Not Started): must define the medkit pickup as an interactable on `PhysicsLayers.LAYER_INTERACTABLES` with `get_interact_priority() == InteractPriority.Kind.PICKUP`. On interact, call `PlayerCharacter.apply_heal(amount)` — new method to add to PC GDD when Combat & Damage lands (currently `apply_damage` has a reject-on-negative guard, so heal must be a separate method).
- **Combat & Damage GDD** (Not Started): no regen formula needed; owns only damage-intake balance.
- **PC GDD addendum (this GDD)**: a future revision will add `apply_heal(amount: float, source: Node) -> void` alongside `apply_damage` once the Inventory contract is defined. Tentative semantics: `health = min(max_health, health + int(round(amount)))`; emit `player_health_changed`. No signal for heal events at MVP.

**Cross-review GD-B2 closure**: PC OQ-1 no longer blocks Combat & Damage GDD authoring; the decision is "no regen formula; pickups handle it." Combat & Damage can now be scoped around damage intake only.

### OQ-2: Fall damage for VS tier

**Question**: Should falls from > some height cause HP damage?

**Context**: MVP has no fall damage — hard landings produce a camera dip + noise spike only. The kill-plane at Y = -50 m is a bug-recovery safety net, not gameplay.

**Options**:
- **A**: Remain damage-free (current). Pillar 5 purist: "no modern verbs." NOLF1 was damage-free.
- **B**: Add fall damage above 4 m drop at VS tier. Small amount (e.g., 15 HP per meter above threshold). Encourages careful level traversal in the Tower's vertical sections.
- **C**: Fall damage only above hard-landing noise threshold (`> v_land_hard` per F.3 = 8 m noise + 20 HP damage). Couples mechanics cleanly. (At shipped defaults `v_land_hard = 6.0 m/s`; auto-rescales on gravity/hard_land_height retuning.)

**Deferred to**: VS-tier design pass. Revisit when Observation Deck level design stabilizes (Ballroom has no falls; Observation Deck has service-ladder drops that could warrant this).

### OQ-3: Lean system reconsideration

**Question**: Should a lean (peek left/right) system be added at VS or Full Vision tier?

**Context**: Input GDD excluded lean at MVP due to key conflict (Q/E were candidates; E was reserved for interact, Q for lean would have crowded the WASD cluster). NOLF1 had lean. Thief and System Shock had lean. Absence of lean is a compromise, not a decision.

**Options**:
- **A**: Forever-skip lean. Stealth relies on full-cover crouching behind geometry instead.
- **B**: Add lean at VS with dedicated keys (e.g., Q for lean-left, middle-mouse-forward for lean-right). Requires Input GDD revision and a lean-specific camera offset formula.
- **C**: Add "cover-snap" lean only (context-sensitive — approach a wall edge, press interact to lean around it). Modern Hitman / Splinter Cell pattern. Avoids a dedicated key binding.

**Deferred to**: Stealth AI + Level Design feedback. If VS playtesting reveals players "peeking" by stepping out and back rapidly, lean is worth adding.

### OQ-4: Mirror reflection — full body at VS tier

**Question**: Should Eve's full body mesh exist for mirror reflections?

**Context**: MVP uses a silhouette decal in mirrors — the bathroom in Office Suite and vanity in Cabaret. A full body Eve mesh would require a separate 3rd-person rig, animation set, and material work. Significant scope.

**Options**:
- **A**: Keep silhouette decals forever. Saves ~2 weeks of art work. Mirrors are a polish detail, not a gameplay element.
- **B**: Author full body mesh at VS tier. Unlocks 3rd-person cutscenes later. Ensures Eve's outfit is visible in pickups/loadouts. Aligns with the narrative weight of the character.
- **C**: Mirror-only body mesh (never seen in gameplay, cheap rig, fixed animation). Middle ground — one day of work for a decorative detail.

**Deferred to**: Narrative Director input + Art Bible 5.1 revision at VS tier.

### OQ-5: FootstepComponent surface detection method

**Question**: How does FootstepComponent know what surface Eve is walking on?

**Current spec**: Downward raycast using `PhysicsLayers.MASK_FOOTSTEP_SURFACE` (World layer per ADR-0006) reading `surface_tag` string metadata from the hit mesh. Requires every level mesh to carry the metadata key.

**Options (implementation-level, likely ADR material)**:
- **A**: Material metadata key on every mesh (current spec). Simple but every level artist must tag manually.
- **B**: PhysicsMaterial resource with an extended `surface_tag` script property. Godot-idiomatic but requires PhysicsMaterial authoring tool.
- **C**: Per-area override zones (Area3D volumes with a tag) with a material fallback. Balances artist workflow with flexibility.

**Deferred to**: Level Streaming GDD + a potential ADR. Revisit when the first real level mesh is authored.

### OQ-6: Eve's voice — does she ever verbalize?

**Question**: Does Eve speak during gameplay, or only in scripted dialogue?

**Current spec**: Only breathing and landing vocalizations. Silent during movement, silent on interact, silent on damage.

**Options**:
- **A**: Silent gameplay forever. All dialogue is scripted narrative beats. Most Deadpan Witness-faithful.
- **B**: Add internal monologue murmurs on document pickups ("Hmm." / "Interesting."). Small Pillar 1 risk (comedy-adjacent) but adds personality.
- **C**: Localization-gated reactions — silence in English, murmurs in localized languages if the VO pipeline cannot support all of them at MVP.

**Deferred to**: Narrative Director + Writer. Revisit when Document Collection GDD is authored.

### OQ-7: Hard-landing noise severity — binary or scaled? (Session D opened 2026-04-19)

**Current spec (F.3)**: Any landing above `hard_land_height` fires a binary 8 m noise spike, regardless of how much faster Eve is falling at impact. A 2 m drop and a 10 m drop emit identical spikes to Stealth AI.

**Alternative**: Scale noise radius with drop severity, e.g. `noise_radius = 8.0 × clamp(|v.y| / v_land_hard, 1.0, 2.0)`, so a fall twice as fast emits up to 16 m. Rewards controlled descent, punishes panic proportionally.

**Dependency**: Combat & Damage GDD may introduce fall damage at VS tier (OQ-2). Binary spike + fall damage cleanly separates AI-detection from player-punishment; scaled spike may overlap that separation.

**Owner**: game-designer. Target: before Stealth AI GDD enters noise-perception design. Session D B-12/13 defines the interface but not the scalar semantics — OQ-7 is the scalar-semantics question.

### OQ-8: Air control specification (Session D opened 2026-04-19)

**Current spec (F.1)**: F.1 runs only on ground states; Jump and Fall preserve ground-frame horizontal momentum. Mid-air input has no defined effect — player attempting to change direction while airborne gets no response.

**Options to specify**:
- **A — None (current implicit)**: preserved ground momentum only, no steering. Most period-authentic; hardest for new players.
- **B — Partial air control**: allow input to nudge `v.xz` at a reduced rate (e.g., 25% of ground acceleration via a `air_control_factor` tuning knob).
- **C — Full air control**: input fully steers `v.xz` mid-air (arcade-ish; breaks Pillar 5 weightiness).

**Owner**: game-designer. Target: before VS lock — any level design leveraging mid-air inputs is blocked until resolved. Surfaced by Session D R-5.
