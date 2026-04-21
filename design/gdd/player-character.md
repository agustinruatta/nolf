# Player Character (Eve Sterling)

> **Status**: In Design — Session F pillar-compliance re-draft + /design-review revision pass (2026-04-21)
> **Author**: User + `/design-system` skill + specialists
> **Last Updated**: 2026-04-21
> **Last Verified**: 2026-04-21
> **Implements Pillar**: 1 (Comedy Without Punchlines — Deadpan Witness), 3 (Stealth is Theatre — cinematic movement, generous interact), 5 (Period Authenticity — no modern movement verbs)
> **Supersedes**: `player-character-v0.3-frozen.md` (frozen baseline preserved for review log — do not edit)

## Summary

Player Character is **Eve Sterling** — the first-person avatar the game is named around. This GDD owns Eve's ground locomotion, jump/fall physics, FPS camera, context-sensitive `interact`, health state, and the visible FPS hands mesh. She wears one outfit the whole mission (Courrèges navy per Art Bible §5.1); this GDD specifies how she *moves* and *feels*, never what she looks like. Implementation: Godot 4.6 `CharacterBody3D` + Jolt physics (4.6 default). Publishes to `Events` bus per ADR-0002 (`player_damaged`, `player_died`, `player_health_changed`, `player_interacted`). State serialized via ADR-0003 `PlayerState` sub-resource. Stamina has been removed (Pillar 5). FootstepComponent — previously nested here — is now a sibling GDD: `design/gdd/footstep-component.md`.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Effort: `M` · Key deps: `Input, Outline Pipeline, FootstepComponent` · Character: **Eve Sterling** (BQA field agent, 1965)

## Overview

Player Character is simultaneously the technical FPS movement system AND the embodiment of Eve Sterling. Input flows in; her state radiates out. Stealth AI reads her position + noise footprint through two pull methods (`get_noise_level`, `get_noise_event`). Combat & Damage applies damage. Inventory & Gadgets attaches held items to her visible hands. Document Collection triggers on her `interact` raycast. Mission & Level Scripting listens for position-based triggers.

Movement is deliberately **cinematic, not twitch**. Eve walks at a confident pace; sprint is modestly faster and much louder; crouch is slower and quieter; jump is a controlled hop for low-obstacle mantling, not a leap across gaps. Pillars 3 and 5 make this kinesthetic — she does not wall-run, slide, air-dash, carry a stamina meter, or acquire a sprint cooldown.

Context-sensitive `interact` is the second pillar of player-facing behavior: a raycast from the camera returns the nearest interactable and resolves via priority order (document > terminal > pickup > door). One button, unambiguous behavior — NOLF1's diegetic interaction model, not a modern hold-E-to-charge meter.

Hands render in a `SubViewport` at FOV 55° with an inverted-hull outline per **ADR-0005** — the single documented exception to ADR-0001's stencil outline contract. Full body mesh is used for mirror reflections only; gameplay is first-person exclusively at MVP. Health is a 0–100 integer with no regeneration (OQ-1 closed 2026-04-20: diegetic medkits only).

**This GDD defines**: Eve's movement, state, and interfaces.
**This GDD does NOT define**: her appearance (Art Bible §5.1), her AI (she is the player), enemy reactions (Stealth AI), footstep audio (FootstepComponent sibling doc), respawn sequence (Failure & Respawn), HUD visuals (HUD Core).

## Player Fantasy

**"The Deadpan Witness."** You are Eve Sterling, and the joke is never you. Every movement is a **noticing** — you enter rooms, you cross thresholds, you descend staircases, and the absurdity of 1965 espionage unfurls *around* you. Your crouch is not a combat stance, it's a considered lean. Your sprint is not an action-hero dash, it's a walk slightly accelerated, as if you'd rather not. The fantasy is **being the eye of the storm**: the world is ridiculous; you are not.

**References:** Emma Peel (Diana Rigg, *The Avengers*) — the arched eyebrow rendered as a camera tilt. Modesty Blaise — competence so total it reads as indifference. Cate Archer (NOLF1) — *"oh, this again"* as a gait, but without the quips.

**Pillars served:**
- **Pillar 1** (Comedy Without Punchlines) — the player IS the straight man, kinesthetically. Eve's deadpan gait becomes the straight line that lets the world's absurdity land.
- **Pillar 3** (Stealth is Theatre) — every movement is framed, posed, *watched*. Theatrical hesitation replaces twitch-shooter instantaneity.
- **Pillar 5** (Period Authenticity) — no modern verbs. Eve doesn't slide, she *steps past*. She doesn't dodge-roll, she sidesteps. She doesn't parkour, she walks with purpose.

**Kinesthetic feel:**
- Camera settles with a tiny overshoot-and-return on rapid turns (~4° overshoot, ~90 ms settle).
- A ~120 ms decision beat before crouch drops — Eve is deciding to crouch, not reflexively dropping.
- `interact` has a ~150 ms pause before the hand reaches — as if Eve noticed the object before bothering to pick it up.
- Sprint feels like a walk accelerated, not a dash. No whoosh, no motion blur, no FOV punch.
- **Sprint carries a subtle lateral pace-sway** (~0.5° amplitude, ~0.8 s period) — Eve's legs swinging wider at pace. This is the single permitted Deadpan Witness exception to "no camera sway": it reads as a *faster walk*, not as a *head-wobble*. Walk has zero sway.
- No walk head-bob, no breath-tied camera sway, no damage-edge vignette.

**Design test:** *If we're debating whether Eve should have a combat-roll dodge, this framing says no — she doesn't roll, she steps aside. The deadpan witness doesn't tumble.*

Players will never say *"Eve's movement feels like X."* They will say *"I feel like I'm playing a competent person who has seen all of this before."*

## Detailed Design

### Core Rules

**Physical body.** Eve is a `CharacterBody3D` with a child `CapsuleShape3D` collider.

| Pose | `CapsuleShape3D.height` | `CapsuleShape3D.radius` | Camera Y (local) |
|---|---|---|---|
| Standing | 1.7 m | 0.3 m | 1.6 m |
| Crouched | 1.1 m | 0.3 m | 1.0 m |

Per Godot 4.6 `CapsuleShape3D` documentation: `height` is the **total** capsule height including both hemispherical caps, with `height >= 2 * radius` enforced by the engine (a capsule with height == 2 * radius is a sphere). The 1.7 m standing value IS Eve's full collider height; the 1.1 m crouched value IS her full crouched height. The central cylinder portion is `height - 2 * radius` — derived, not authored. (godot-specialist verification 2026-04-20; closes 3rd-re-review "engine-reality drift" blocker as a false positive.)

Physics ticks at 60 Hz via `_physics_process`. Movement uses `velocity` + `move_and_slide()`. Jolt physics engine (Godot 4.6 default).

**Node hierarchy + camera rotation.** Camera is a child of the body, not a sibling. Rotation splits cleanly: **body rotates on Y** (yaw from look-left/right input); **camera rotates on X** (pitch from look-up/down, clamped ±85°). This is the standard FPS decomposition — body yaw means Eve's collider faces her look direction, so collisions and AI line-of-sight tests agree with the rendered camera. Closes R-15 deferred from prior sessions. `HandAnchor` is a child of the Camera (so held items follow the view); the visible hands `SubViewport` is also parented off the Camera.

**Input processing location.** Look input (mouse + gamepad right-stick) is consumed in `_unhandled_input(event)` via `InputEventMouseMotion` + `InputEventJoypadMotion`, NOT in `_physics_process`. Rotation deltas are applied immediately to `body.rotation.y` and `camera.rotation.x`. Consuming look input in `_physics_process` would accumulate mouse deltas between the 60 Hz physics ticks and apply them in a lump, producing "notchy" feel on high-refresh-rate displays (gameplay-programmer advisory 2026-04-21). Movement input (WASD / left-stick) is read in `_physics_process` via `Input.get_action_strength()` — it is state-polled, not event-driven, so no accumulation problem.

**Collision layers.** Per **ADR-0006 (Collision Layer Contract)** — single source of truth at `res://src/core/physics_layers.gd`. This GDD consumes the contract; it does not redefine layer numbers.

| Constant | Role for Eve |
|---|---|
| `PhysicsLayers.LAYER_WORLD` | World geometry Eve collides against; footstep raycast reads material metadata |
| `PhysicsLayers.LAYER_PLAYER` | Eve's `CharacterBody3D` sits on this layer; AI vision raycasts treat it as a target |
| `PhysicsLayers.LAYER_AI` | AI bodies Eve cannot walk through |
| `PhysicsLayers.LAYER_INTERACTABLES` | Interact raycast scans ONLY this layer (non-blocking to movement) |
| `PhysicsLayers.LAYER_PROJECTILES` | Projectile bodies that damage Eve |

`CharacterBody3D._ready()` sets `layer = MASK_PLAYER`, `mask = MASK_WORLD | MASK_AI` via `set_collision_layer_value` / `set_collision_mask_value` (ADR-0006 Implementation Guideline 3).

**Rejected features (Pillar 5).**
- **No stamina system.** A hidden stamina counter was considered and rejected — its effects (mid-sprint auto-drop, heavy-breathing audio) manifest as modern-verb feedback in period costume. Sprint is unlimited; its cost is noise (12 m vs Walk 5 m — see Movement speeds), not breath.
- **No CrouchSprint state.** Strictly slower than Walk, matched Sprint's noise — served no tactical niche.
- **No air control.** OQ-8 closed 2026-04-20 (Option A). Jump/Fall preserve the takeoff planar velocity; mid-air input has no effect. Deadpan Witness does not steer mid-air.
- **No fall damage at MVP.** Hard landings produce camera dip + scaled noise spike only. Fall damage remains OQ-2 (VS tier).

**Enums — `PlayerEnums`.** Both movement state and noise type live on a shared enum host to break the circular parse dependency that would otherwise exist if `NoiseEvent.type` were typed `PlayerCharacter.NoiseType` (NoiseEvent → PlayerCharacter → NoiseEvent).

```gdscript
# res://src/gameplay/player/player_enums.gd
class_name PlayerEnums
extends RefCounted

enum MovementState { IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, DEAD }
enum NoiseType { FOOTSTEP_SOFT, FOOTSTEP_NORMAL, FOOTSTEP_LOUD, JUMP_TAKEOFF, LANDING_SOFT, LANDING_HARD }
```

The file carries no runtime logic — it is a pure enum host. Neither enum is published on `Events.gd` (ADR-0002 Implementation Guideline 2 forbids non-signal types there) nor on a shared `Types.gd` (project does not have one). All `PlayerState` serialization fields (ADR-0003) and save-load contracts use `PlayerEnums.MovementState` enum ints.

**NoiseEvent** — lightweight typed holder returned by `get_noise_event()` (F.4). Declared as `class_name NoiseEvent` in `res://src/gameplay/player/noise_event.gd`. Not a `Resource` subclass (ref-counted allocator overhead at 80 Hz aggregate AI polling is unacceptable). Fields:

```gdscript
class_name NoiseEvent
extends RefCounted

var type: PlayerEnums.NoiseType
var radius_m: float
var origin: Vector3   # world-space Eve position at the frame the spike was recorded
```

PlayerCharacter reuses a single `NoiseEvent` instance for the latch — fields are overwritten in place. **Implementation note at the mutation site must read**: `# In-place mutation is intentional (zero-allocation at 80 Hz aggregate AI polling). Callers MUST copy fields before the next physics frame. DO NOT "fix" this by allocating a new NoiseEvent per spike — see F.4 and AC-3.5.` Callers that need to remember a spike (e.g., Stealth AI parking an investigate marker) MUST copy `{type, radius_m, origin}` into their own state before the next physics frame — see F.4 reference-retention footgun note.

**Movement speeds and noise.**

| State | Speed (m/s) | Noise radius (m) | Speed-per-noise (m/m) |
|---|---|---|---|
| Idle / Walk-still / Crouch-still | 0 | 0 | — |
| Walk | 3.5 | 5 | 0.70 |
| Sprint | 5.5 | **12** | 0.46 |
| Crouch | 1.8 | 3 | 0.60 |
| Jump takeoff (spike) | — | 4 | — |
| Landing soft (spike) | — | 5 | — |
| Landing hard (spike, scaled) | — | 8–16 (F.3) | — |

**Sprint noise raised to 12 m (from 9 m) per GD-B3 close 2026-04-20.** At 12 m, Sprint is strictly worse than Walk AND Crouch in the speed-per-noise ratio — restoring Sneak/Crouch as the dominant stealth strategy (Pillar 3). Sprint remains valuable as a traversal verb in areas the player knows are AI-free; it ceases to be a stealth verb.

"Still" means `velocity.length() < idle_velocity_threshold` (default 0.1 m/s). Walk-still and Crouch-still resolve to 0.0 noise — standing-in-place Eve is silent.

**State → NoiseType mapping**: Walk → `FOOTSTEP_NORMAL`, Sprint → `FOOTSTEP_LOUD`, Crouch → `FOOTSTEP_SOFT`, takeoff → `JUMP_TAKEOFF`, soft landing → `LANDING_SOFT`, hard landing → `LANDING_HARD`. Idle + Jump + Fall + Dead are silent in the scalar channel (spikes deliver via the latched-event path).

**Vertical motion.**
- `gravity` = 12.0 m/s² (heavier than Earth for tighter feel).
- `jump_velocity` = 3.8 m/s.
- **Apex height** (kinematic): `H = v² / (2g) = 14.44 / 24 = 0.60 m`.
- **Airtime** (flat ground): `t_total = 2v / g = 0.63 s`.
- **Landing velocity** (flat ground): 3.8 m/s < `v_land_hard = 6.0 m/s` → flat-ground jumps at defaults do NOT trigger hard landing.

Cross-knob constraints live in Tuning Knobs → Vertical; safe ranges are chosen so that every (gravity, jump_velocity) combination preserves three pillar-critical invariants: max apex ≤ 0.80 m, min apex ≥ 0.45 m, flat-ground jump never triggers hard landing.

No double-jump. No air control.

**Camera.**
- First-person only. Horizontal FOV 75°. Pitch clamp ±85°. Yaw unconstrained.
- Mouse and gamepad look sensitivities are **consumed** from `Settings` (forward dependency — Settings & Accessibility GDD), not owned by this GDD. Defaults ship from `res://src/core/settings_defaults.gd` until that GDD lands.
- Roll is always 0 (no lean system at MVP).
- Turn overshoot: ~4° on rapid yaw (> 180°/s), 90 ms ease-out settle. Deadpan Witness feel.
- Crouch drop: 120 ms ease-in-out, camera Y from 1.6 → 1.0 m.
- Hard-landing dip: 4–6° downward pitch over 150 ms.
- Dead state: pitch down 60° over 800 ms, translate Y to 0.4 m, sepia fade 1.5 s.
- No head-bob, no sprint FOV punch, no damage vignette.

**Context-sensitive `interact`** (bound to E per Input GDD).
- Raycast from camera origin along forward vector, length `interact_ray_length` (default 2.0 m), `mask = PhysicsLayers.MASK_INTERACT_RAYCAST`.
- Each frame, the HUD highlight query calls the same `_resolve_interact_target()` the E-press uses — the outlined object is always the object E-press would activate (HUD-coherence guarantee).
- Priority order (lowest wins even if another is geometrically closer): **Document (0) < Terminal (1) < Pickup (2) < Door (3)**.
- Timing: 150 ms pre-reach pause (Deadpan Witness "noticing"), then 200–250 ms reach animation. During the full window, movement input is accepted but sprint is disabled. Subsequent E presses within the window are swallowed.

**Health.**
- Single integer 0–100 (`max_health = 100`). Starts at `max_health` on mission load.
- `apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType) -> void` — only caller permitted to mutate health. See F.6.
- `apply_heal(amount: float, source: Node) -> void` — restores HP; called by Inventory & Gadgets medkit pickups (once that GDD lands). See F.7.
- No regeneration at MVP (OQ-1 closed 2026-04-20 — diegetic medkits only).

**Respawn contract.** Failure & Respawn calls `reset_for_respawn(checkpoint: Checkpoint) -> void` on PlayerCharacter to put Eve back into a safe state. The method:
- Clears `_latched_event` (noise latch) to `null`.
- Sets `current_state = PlayerEnums.MovementState.IDLE`.
- Sets `_is_hand_busy = false` **before** calling `Tween.kill()` on any in-flight interact tween (flag-first ordering — godot-specialist note: `_is_hand_busy` must be cleared in the same stack frame that calls `kill()`, never in a `tween_finished` callback, since `kill()` suppresses that callback).
- Sets `health = max_health`.
- Sets `global_transform.origin = checkpoint.respawn_position`; `rotation = checkpoint.respawn_rotation`.
- Emits `player_health_changed(max_health, max_health)` exactly once so HUD restores the readout.

Failure & Respawn owns the respawn sequence (fade, camera reposition, AI reset); PlayerCharacter only owns the state reset.

### States and Transitions

| From | To | Trigger | Block condition |
|---|---|---|---|
| Idle | Walk | Movement input, no Shift | — |
| Idle | Sprint | Movement input + Shift | — |
| Idle / Walk / Sprint | Crouch | Ctrl pressed (toggle) | Ceiling blocked on uncrouch: stay crouched |
| Ground state | Jump | Space + `is_on_floor` + coyote latch | In Crouch: jump ignored |
| Ground state | Fall | `not is_on_floor()` AND `not jump_pressed` AND coyote expired | Crouch preserved through Fall, restored on landing if Ctrl still held |
| Jump | Fall | `velocity.y ≤ 0` | — |
| Fall | Idle / Walk / Sprint / Crouch | `is_on_floor()` | Previous crouch restored if Ctrl still held |
| Any | Dead | `health <= 0` | — |

**Coyote-time**: `can_jump == true` for `coyote_time_frames` (default 3 @ 60 Hz ≈ 50 ms) after the last frame `is_on_floor()` was true. The Ground → Fall transition respects the same latch — Eve does not fall-state for the grace window, preserving late-jump intent at ledge edges.

**120 ms crouch decision beat.** When Ctrl is pressed, the transition to Crouch plays a 120 ms ease-in-out (camera drop, collider shrink). Movement input during the transition is accepted but capped at Crouch speed from frame 1 (no speed snap mid-drop).

**Ceiling check.** Uncrouching uses a persistent `ShapeCast3D` node — a direct child of `CharacterBody3D` with `position = Vector3.ZERO` (local, so it inherits the body's world origin automatically on every frame — no manual repositioning needed). `ShapeCast3D.shape` is a `CapsuleShape3D` with standing dimensions (`height=1.7 m, radius=0.3 m`). `target_position = Vector3(0, 0.1, 0)` (a tiny upward sweep — we only need to detect contact at the current origin, not a full swept-volume overlap; the capsule extends upward from origin by its own half-height regardless of `target_position`). `collision_mask = PhysicsLayers.MASK_WORLD` (ceilings are world geometry). On Ctrl-release, call `shape_cast.force_shapecast_update()` THEN read `is_colliding()` — the force-update call is mandatory because Godot 4.x `ShapeCast3D` only updates during its own `_physics_process` tick otherwise, and we need a same-frame query result. Blocked → Eve stays crouched, soft head-bump SFX plays. No visual UI feedback (Pillar 5).

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Input** | consumes | 26-action catalog via `Input.get_action_strength()` and `Input.is_action_just_pressed()` (Input GDD). |
| **Signal Bus** | publishes | `player_damaged(amount: float, source: Node, is_critical: bool)`, `player_died(cause: CombatSystem.DeathCause)`, `player_health_changed(current: float, max_health: float)`, `player_interacted(target: Node3D)`. ADR-0002 taxonomy. |
| **Stealth AI** | provides state | `get_noise_level() -> float`, `get_noise_event() -> NoiseEvent` (idempotent-read per F.4), `get_silhouette_height() -> float` (1.7 standing / 1.1 crouched), `global_transform.origin`, `PhysicsLayers.LAYER_PLAYER` membership. Stealth AI owns occlusion + propagation — this GDD publishes source radius only. |
| **Combat & Damage** | receives | `apply_damage(amount, source, damage_type)` — only caller permitted to mutate health. |
| **Inventory & Gadgets** | queries + displays + heals | Reads `is_hand_busy()`; attaches held gadget mesh to `HandAnchor`; calls `apply_heal(amount, source)` on medkit pickup. |
| **Outline Pipeline** | exception | Hands are the ADR-0005 exception — inverted-hull via `material_overlay` (NOT `OutlineTier.set_tier`). |
| **Save / Load** | serializes | `PlayerState` sub-resource per ADR-0003: `position: Vector3, rotation: Vector3, health: int, current_state: int` (enum value). Stamina field removed. |
| **HUD Core** | provides | `player_health_changed` signal + `get_current_interact_target()` poll + `is_hand_busy()`. |
| **Mission Scripting** | listens | Position queries (`global_transform.origin`) + `player_interacted` signal. |
| **Audio** | publishes (indirect) | No direct signals from this system — all footstep emission lives on FootstepComponent (sibling doc). `player_died` drives mix ducking. |
| **Failure & Respawn** | subscribes + calls | Subscribes to `player_died`; calls `reset_for_respawn(checkpoint)`. |
| **FootstepComponent** | sibling | Owns `player_footstep(surface, noise_radius_m)` emission for Audio. PlayerCharacter does NOT depend on it for `get_noise_level` — see `footstep-component.md` split contract. |

**FootstepComponent split** (Session F — resolves R-19). FootstepComponent is now its own sibling GDD. Split contract at a glance:
- **PlayerCharacter** owns `get_noise_level()` and `get_noise_event()` — AI perception lane. Computed from its own `current_state` + `velocity` + noise knobs. Does NOT depend on FootstepComponent.
- **FootstepComponent** (child node of PlayerCharacter) owns `player_footstep(surface, noise_radius_m)` emission — Audio SFX lane. Reads `player.current_state` + `player.velocity` + ground surface raycast. Does NOT mutate `_latched_event`.
- These are two independent perception channels. A Stealth AI implementation that subscribed to `player_footstep` would bypass the pull contract and create a duplicate perception path — explicitly forbidden (see Forbidden Patterns).

**Boundary — this GDD does NOT own**: respawn flow (Failure & Respawn), HUD rendering (HUD Core), gadget behavior/weapon firing (Inventory & Gadgets), AI perception math (Stealth AI), cutscene camera overrides (Mission Scripting), footstep audio (FootstepComponent sibling doc).

### Forward dependencies

Systems referenced here that do not yet have GDDs. Implementation of the corresponding PlayerCharacter feature is gated on these:

| Forward reference | Owner GDD (not yet authored) | Gate |
|---|---|---|
| `Settings.get_resolution_scale()` (hands outline) | Settings & Accessibility | AC-9.2 — blocks hands-outline release build on Settings GDD. Test marked skip-if-not-implemented until then. |
| Mouse/gamepad look sensitivities | Settings & Accessibility | PC ships defaults from `res://src/core/settings_defaults.gd`; runtime-override wiring is placeholder. |
| `Checkpoint` type for `reset_for_respawn` | Failure & Respawn | PC uses a placeholder `Resource` subclass pre-F&R; signature stable. |
| `CombatSystem.DamageType` / `damage_type_to_death_cause` | Combat & Damage | `apply_damage` signature gated; AC-5.x tests use a stub `DamageType.TEST` value. |
| `InteractPriority.Kind` enum | Inventory & Gadgets + Document Collection | `_resolve_interact_target()` gated on the enum; placeholder file `res://src/gameplay/interactables/interact_priority.gd` acceptable pre-Inventory. |

## Formulas

### Variables

- `v` — current velocity vector (m/s)
- `v_target` — desired velocity for current state
- `input_magnitude` — scalar ∈ [0, 1], from `Input.get_vector("move_left", "move_right", "move_forward", "move_back").length()`. Gamepad analog delivers fractional values; keyboard delivers {0.0, 1.0}.
- `Δt` — physics frame delta (s, nominal 1/60)
- `Δt_clamped` = `min(Δt, 1.0 / 30.0)` — hitch-guarded delta. Applies to F.1 and F.2 to prevent hitches (loading spikes, Alt+Tab resume) from fabricating motion that would falsely trigger F.3's hard-landing noise spike.
- `g` — gravity (m/s²)
- `H` — jump apex height (m)
- `NOISE_BY_STATE` — `const` dictionary rebuilt once at `_ready()` from per-state noise knobs:
  `{ IDLE: 0.0, WALK: noise_walk, SPRINT: noise_sprint, CROUCH: noise_crouch, JUMP: 0.0, FALL: 0.0, DEAD: 0.0 }`.
  IDLE / JUMP / FALL / DEAD are silent in the scalar channel because those states emit via the latched spike path.

### F.1 Horizontal velocity blend (ground states only)

Runs ONLY in ground states (Idle, Walk, Sprint, Crouch). Jump and Fall preserve the takeoff planar velocity (no air control — OQ-8 closed).

```gdscript
func _apply_horizontal_velocity(delta: float) -> void:
    var planar_velocity := Vector2(velocity.x, velocity.z)   # GDScript has no .xz swizzle
    var planar_target := Vector2(v_target.x, v_target.z)
    var rate_time: float
    if input_magnitude > 0.0:
        rate_time = max(accel_time, 0.001)   # divide-by-zero NaN guard
    else:
        rate_time = max(decel_time, 0.001)
    var delta_clamped: float = min(delta, 1.0 / 30.0)
    var step: float = (1.0 / rate_time) * max_speed * delta_clamped
    planar_velocity = planar_velocity.move_toward(planar_target, step)
    velocity.x = planar_velocity.x
    velocity.z = planar_velocity.y   # Vector2.y maps to world Z
```

Uses `Vector2(velocity.x, velocity.z)` as an intermediate — GDScript does not support `.xz` swizzle assignment (Session F fix from 3rd re-review).

**Example** (Walk from rest at 60 fps, `max_speed=3.5, accel_time=0.12, delta=0.01667`):
- `step = (1 / 0.12) × 3.5 × 0.01667 ≈ 0.486 m/s per frame`
- Frames to full speed: `3.5 / 0.486 ≈ 7.2 ≈ 0.12 s` ✓

**Inspector validation.** Each rate knob carries `@export_range(safe_min, safe_max, 0.01)` so the editor constrains designer input to the Safe Range. The `max(..., 0.001)` guard is defense-in-depth against deserialized or out-of-band zero values.

### F.2 Gravity and Jump

```gdscript
func _apply_vertical_velocity(delta: float) -> void:
    var delta_clamped: float = min(delta, 1.0 / 30.0)
    if not is_on_floor():
        velocity.y -= gravity * delta_clamped
    if Input.is_action_just_pressed("jump") and _can_jump():
        velocity.y = jump_velocity
```

Where `_can_jump()` returns true when (`is_on_floor()` OR coyote-latch active) AND `current_state != PlayerEnums.MovementState.CROUCH`.

At defaults (`g=12, jump_velocity=3.8`):
- Apex height: `H = v² / (2g) = 14.44 / 24 = 0.60 m`
- Airtime to apex: `t_up = v / g = 0.317 s`
- Total airtime (flat ground): `2 × t_up = 0.63 s`
- Landing velocity (flat ground): 3.8 m/s

### F.3 Hard-Landing Noise (scaled — OQ-7 closed)

The hard-landing threshold is expressed as a **drop height** (`hard_land_height`), not a velocity, so changing gravity automatically rescales the trigger point:

```
v_land_hard = sqrt(2 × gravity × hard_land_height)
```

Any landing where `|velocity.y| > v_land_hard` is a "hard" landing. Noise radius **scales** with how fast Eve is falling at impact (Session F — OQ-7 resolved):

```
noise_radius = 8.0 × clamp(|velocity.y| / v_land_hard, 1.0, 2.0)
```

| Impact speed | `noise_radius` (m) |
|---|---|
| = `v_land_hard` | 8.0 |
| 1.5 × `v_land_hard` | 12.0 |
| ≥ 2.0 × `v_land_hard` | 16.0 (cap) |

Cap at 2× prevents pathological values. Controlled drops (just over threshold) emit 8 m; panic drops from 2×+ emit 16 m — rewards the player who watches where Eve lands (Deadpan Witness rewarded; Pillar 3 enforcement).

**Threshold discontinuity — intentional** (systems-designer B2, 2026-04-21). At exactly `|velocity.y| == v_land_hard`, the `>` comparison fails → `LANDING_SOFT` fires at 5 m radius. One physics tick above, `LANDING_HARD` fires at 8 m. The 5 → 8 m jump (37.5% step) is a deliberate design cliff, not a bug: it makes the hard-landing threshold *audibly legible* to the player (they can feel where the punish line is) and to AI (the noise spike crosses a clear bucket boundary). Ramping continuously between 5 and 8 would blur the threshold and remove the teaching moment. Any future change to a continuous ramp requires a pillar-compliance review.

No fall damage at MVP — noise only (OQ-2 deferred to VS).

**Worked v_land_hard at safe-range extremes** (cross-knob validation):
- `g=11, hld=1.2`: `v_land_hard = sqrt(26.4) ≈ 5.14 m/s`
- `g=12, hld=1.5` (defaults): `v_land_hard = sqrt(36) = 6.00 m/s`
- `g=13, hld=3.0`: `v_land_hard = sqrt(78) ≈ 8.83 m/s`

Flat-ground jump landing velocity at safe extremes (`jump_velocity` 3.5–4.2 m/s) is strictly less than the lowest `v_land_hard` (5.14 m/s) — flat-ground jumps never trigger hard landing at any safe combination. Closes the cross-formula blocker from the 3rd re-review.

### F.4 Noise interface (Stealth AI reads)

Two per-frame pull methods on `PlayerCharacter`. NOT signals (ADR-0002 forbids per-frame signals).

```gdscript
func get_noise_level() -> float:
    # DEAD early-return: a dead Eve emits no noise. Defense-in-depth against
    # stale _latched_event between death and reset_for_respawn (ai-programmer B-1, 2026-04-21).
    if current_state == PlayerEnums.MovementState.DEAD:
        return 0.0
    if _latched_event != null:
        return _latched_event.radius_m * noise_global_multiplier
    # Walk-at-rest / Crouch-at-rest treated as Idle-silent (below idle_velocity_threshold).
    var moving: bool = velocity.length() >= idle_velocity_threshold
    if (current_state == PlayerEnums.MovementState.CROUCH
            or current_state == PlayerEnums.MovementState.WALK) and not moving:
        return 0.0
    return NOISE_BY_STATE[current_state] * noise_global_multiplier

func get_noise_event() -> NoiseEvent:
    # DEAD early-return — see get_noise_level() rationale.
    if current_state == PlayerEnums.MovementState.DEAD:
        return null
    return _latched_event   # may be null; idempotent-read; auto-expiry is sole clear
```

**Latching rules.**
- Jump takeoff and every landing variant (F.3) record a `NoiseEvent` to `_latched_event` immediately on state transition — not deferred to the next frame. `origin` is set to Eve's world-space position at the frame of recording.
- **Collision policy**: highest `radius_m` wins. A new spike overwrites only if strictly greater; equal-or-lower preserves the existing latch (first-wins on ties). Rationale: the louder event is what AI should investigate.
- **Auto-expiry**: `spike_latch_duration_frames = int(spike_latch_duration_sec × Engine.physics_ticks_per_second)`. **Default raised 0.1 → 0.15 s (9 frames @ 60 Hz = 1.5× AI-tick window at 10 Hz) per ai-programmer B-2 fix, 2026-04-21** — 6-frame window did NOT cover every guard at 10 Hz with staggered phase offsets (a guard whose 10 Hz tick lands on frame N+7 would read null). 9 frames covers any phase offset within a single AI-tick window with 1-frame jitter headroom. Physics-tick-rate-independent via the runtime conversion.
- **Auto-expiry is the SOLE clear mechanism.** `get_noise_event()` never clears the latch.
- Continuous locomotion state transitions (Idle → Walk, etc.) do NOT touch the latch.

**Multi-guard parity.** Every AI consumer polling within the 9-frame (0.15 s) latch window sees the SAME `NoiseEvent` reference (same field values) regardless of phase offset within the window. 9 frames @ 60 Hz ≥ 1 full AI-tick period at 10 Hz + jitter — so every guard's 10 Hz tick lands at least once inside the latch. Replaces the prior single-consumption contract (race-to-first-poll asymmetry) AND the Session F 6-frame latch which failed for guards polling on phase N+7 (ai-programmer B-2 closure).

**Reference retention footgun.** Callers MUST copy `{type, radius_m, origin}` into their own state if they need the event after the current physics frame. The returned reference is the reused latch instance; on the next spike, fields are overwritten in place. A caller that stores `var last = player.get_noise_event()` and reads `last.origin` on the next frame reads the subsequent spike's origin. See AC-3 retention test.

**Sequencing note** (intentional loss). Highest-radius-wins collapse discards the ordering between a takeoff spike (4 m) and a soft landing spike (5 m) recorded within the same latch window. If Stealth AI needs sequencing, it can infer the preceding event from `_latched_event.type` + `velocity.y` sign + time-in-air. This is a deliberate tradeoff — keeps the interface stateless and the latch a single-instance (zero steady-state allocation).

**Performance.** Single reused `NoiseEvent` instance — no per-call allocation. At the 80 Hz aggregate polling rate (10 Hz × ~8 guards), steady-state zero-allocation.

### F.5 Interact Raycast Resolution

Iterative raycast with an exclusion list walks up to `raycast_max_iterations` stacked interactables along the camera forward ray. Godot's `intersect_ray` returns a single hit per call, so the exclusion list is how F.5 achieves multi-hit traversal without a volumetric shape query (which would off-axis false-positive).

```gdscript
## Returns the highest-priority Interactable within `interact_ray_length`, or null.
## Priority: Document(0) < Terminal(1) < Pickup(2) < Door(3). Lower wins.
## Same-priority ties broken by shortest ray-distance (game-designer B-3, 2026-04-21).
func _resolve_interact_target() -> Node3D:
    var space_state := get_world_3d().direct_space_state
    var ray_origin: Vector3 = _camera.global_position
    var ray_end: Vector3 = ray_origin + (-_camera.global_transform.basis.z
                              * interact_ray_length)
    var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    query.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST
    query.exclude = []

    var best_node: Node3D = null
    var best_priority: int = 2147483647   # INT32_MAX sentinel; GDScript has no INT_MAX
    var best_distance_sq: float = INF     # Same-priority tie-breaker

    var hit_count: int = 0
    for _i in raycast_max_iterations:
        var hit: Dictionary = space_state.intersect_ray(query)
        if hit.is_empty():
            break
        hit_count += 1
        var collider: Node3D = hit.collider
        if not collider.has_method("get_interact_priority"):
            query.exclude.append(hit.rid)   # content-authoring safety
            continue
        var priority: int = collider.get_interact_priority()
        var distance_sq: float = ray_origin.distance_squared_to(hit.position)
        # Lower priority wins outright; on same priority, nearer hit wins (deterministic tie-break).
        if priority < best_priority or (priority == best_priority and distance_sq < best_distance_sq):
            best_priority = priority
            best_distance_sq = distance_sq
            best_node = collider
        query.exclude.append(hit.rid)

    # Cap-exceeded diagnostic — surfaces silent priority inversion at runtime.
    # Session F: closes 3rd-re-review blocker.
    if hit_count == raycast_max_iterations:
        push_warning("interact raycast hit iteration cap (%d); a higher-priority interactable may be beyond the cap — re-space the stack or raise raycast_max_iterations" % raycast_max_iterations)

    return best_node
```

**Contract notes.**
- Priority is delegated via `get_interact_priority() -> int` on each Interactable. Constants live in `res://src/gameplay/interactables/interact_priority.gd` as `class_name InteractPriority` with `enum Kind { DOCUMENT = 0, TERMINAL = 1, PICKUP = 2, DOOR = 3 }`. Adding a new interactable type = append to the enum + implement `get_interact_priority()` on the new class. PlayerCharacter never changes.
- F.5 does NOT assume Jolt returns hits in nearest-first order — priority resolution is correct regardless of broad-phase traversal order. Same-priority ties are broken by squared ray-distance from camera origin (2026-04-21 fix, game-designer B-3): two Documents in range always resolve to the nearer one deterministically, regardless of Jolt's traversal order. Ties at identical distance (level-author bug) resolve to the first-encountered — documented as an undefined-but-stable outcome.
- **`query.exclude` mutation after `create()` is live**: in Godot 4.6, `PhysicsRayQueryParameters3D.exclude` is a property whose backing `Array[RID]` is exposed by reference — appending to it between `intersect_ray` calls IS reflected in the next query. Verified against `docs/engine-reference/godot/modules/physics.md` (Raycasting section, pattern `query.exclude = [...]` followed by `intersect_ray(query)`) and idiomatic for 4.6. `create()` does NOT snapshot the array. The loop's behavior is correct.
- `raycast_max_iterations` default 4 covers the realistic worst case (document on desk on terminal near door). Cap exceeded: `push_warning` fires (closes silent priority inversion blocker) and best-so-far is returned — no null, no crash.
- Same resolver powers both the E-press action and the continuous HUD-highlight query (HUD-coherence guarantee).
- Godot 4.6 + Jolt: `query.exclude` is processed as a broad-phase RID filter — excluded bodies skip narrow-phase entirely. Iteration cost ≈ 0.05 ms per extra iteration measured on mission-scale scenes.

### F.6 Damage Application

```gdscript
func apply_damage(amount: float, source: Node, damage_type: CombatSystem.DamageType) -> void:
    if current_state == PlayerEnums.MovementState.DEAD:
        return
    if amount <= 0.0:
        push_warning("apply_damage called with non-positive amount %f — ignored" % amount)
        return
    var rounded: int = int(round(amount))
    # Post-rounding guard (Session F): amount > 0 but rounds to 0 should not emit.
    # Prevents spurious player_damaged / HUD flash from DoT tick accumulators that
    # might deliver sub-0.5 amounts per tick.
    #
    # Boundary clarification (systems-designer B1, 2026-04-21): Godot 4.6 `round()`
    # uses round-half-away-from-zero for positive floats (round(0.5) == 1, round(0.49) == 0).
    # Therefore:
    #   amount = 0.49  → rounded = 0 → guarded out (no signal, no health change)
    #   amount = 0.50  → rounded = 1 → 1 HP damage, full signal path
    #   amount = 1.50  → rounded = 2 → 2 HP damage
    # This IS the intended design: DoT tick accumulators delivering < 0.5 HP per tick
    # are silenced; ticks at 0.5 HP or above land as 1 HP minimum. AC-5.2 verifies
    # {0.3, 0.49, 0.5, 1.5} to lock the boundary.
    if rounded <= 0:
        return
    health = max(0, health - rounded)
    Events.player_damaged.emit(amount, source, false)   # is_critical false at MVP
    Events.player_health_changed.emit(float(health), float(max_health))
    if health == 0:
        current_state = PlayerEnums.MovementState.DEAD
        # Clear latched noise event on death (ai-programmer B-1, 2026-04-21) — prevents
        # Stealth AI from polling a stale spike during the 800 ms death animation before
        # reset_for_respawn() runs.
        _latched_event = null
        var cause: CombatSystem.DeathCause = CombatSystem.damage_type_to_death_cause(damage_type)
        Events.player_died.emit(cause)
```

**Contract.**
- `amount` is rounded to int at assignment (HUD renders integer health per Art Bible §7B); the signal payload retains the caller's float for analytics fidelity.
- Post-rounding guard prevents sub-0.5 DoT tick spam (Session F — closes F.6 blocker from 3rd re-review).
- `is_critical = false` at MVP — Combat & Damage GDD will replace the literal without touching this interface.
- `source: Node` reference — subscribers MUST call `is_instance_valid(source)` per ADR-0002 Implementation Guideline 4.
- `CombatSystem.damage_type_to_death_cause()` is a pure helper owned by the Combat & Damage GDD. Default `DeathCause.UNKNOWN` for unmapped types.

No damage multipliers, armor, or resistance at MVP.

### F.8 Silhouette Height Query (for Stealth AI line-of-sight)

```gdscript
## Returns Eve's current silhouette height in meters for AI line-of-sight tests.
## Standing: 1.7 m. Crouched: 1.1 m. Transition: interpolated with the crouch drop.
## (ai-programmer B-3 fix, 2026-04-21 — previously referenced but never defined.)
func get_silhouette_height() -> float:
    if current_state == PlayerEnums.MovementState.DEAD:
        return 0.4   # head on floor per dead-state camera spec
    # During the 120 ms crouch drop/rise, interpolate linearly between the two values.
    # `_crouch_transition_progress` is a float in [0.0, 1.0] managed by the crouch
    # animation: 0.0 = fully standing, 1.0 = fully crouched.
    return lerp(1.7, 1.1, _crouch_transition_progress)
```

**Contract notes.**
- Return value is Eve's **full collider height** (matching `CapsuleShape3D.height` — total, including caps, per Godot 4.6 semantics).
- During the crouch transition (120 ms ease-in-out), the value is linearly interpolated. Stealth AI's line-of-sight tests receive a gradual silhouette change, not a step — so a guard checking sightlines mid-transition sees Eve drop below cover smoothly as her collider + camera drop smoothly.
- Dead state returns 0.4 m (head on floor per dead-state camera spec); AI should use this for post-death line-of-sight only if it needs to, e.g., corpse-detection which is post-MVP.
- This is a pull method, not a signal — same pattern as `get_noise_level()` / `get_noise_event()`.

### F.7 Heal Application (OQ-1 closure)

```gdscript
func apply_heal(amount: float, source: Node) -> void:
    if current_state == PlayerEnums.MovementState.DEAD:
        return
    if amount <= 0.0:
        push_warning("apply_heal called with non-positive amount %f — ignored" % amount)
        return
    var rounded: int = int(round(amount))
    if rounded <= 0:
        return
    health = min(max_health, health + rounded)
    Events.player_health_changed.emit(float(health), float(max_health))
```

Called by Inventory & Gadgets medkit pickups (forward dependency). No dedicated `player_healed` signal at MVP — HUD listens to `player_health_changed` for both damage and heal paths. Matches the `apply_damage` reject-on-non-positive pattern; `apply_damage` and `apply_heal` are separated so callers cannot smuggle heals through a negative-damage call.

## Edge Cases

### E.1 Uncrouch blocked by low ceiling

Shapecast (standing `CapsuleShape3D` dimensions, `height=1.7, radius=0.3`) from current origin detects ceiling. If blocked, Eve stays in Crouch, the Ctrl toggle is ignored that frame, and a soft head-bump SFX plays. Toggle remains ON — player must move to a clear area and press Ctrl again. No visual UI feedback (Pillar 5).

### E.2 Crouch pressed mid-jump

Crouch toggle deferred until landing. On `is_on_floor()` transition, if Ctrl was pressed during airtime, Eve enters Crouch immediately. No air-crouch silhouette changes (Pillar 5 — no modern verbs).

### E.3 Jump pressed while crouched

Jump input ignored. No sound, no feedback. Eve must uncrouch first. Rejects "bunny-hop crouch" modern verb.

### E.4 Interact during interact animation

Subsequent E presses within the `is_hand_busy()` window are swallowed. The in-flight interaction resolves first. Prevents double-pickup glitches and keeps animation state deterministic.

### E.5 Stacked interactables

F.5's priority resolver handles stacks up to `raycast_max_iterations` (default 4). Level-design QA constraint: interactable bodies on `LAYER_INTERACTABLES` must be placed at least `interact_min_separation` (default 0.15 m) apart along any plausible camera ray from Eve's standing or crouched eye height. Not runtime-enforced — verified at content review.

**Cap-exceeded behavior** (Session F): `push_warning` fires from F.5 at runtime (so content authors see the problem in the console) AND the lowest-priority items beyond the cap are silently skipped — no crash, but the skipped items are unreachable without the player repositioning. Warning is the mechanism that makes silent priority inversion loud.

### E.6 Damage during Interact

Damage applies normally (`apply_damage` is state-agnostic). If a single call's `amount` ≥ `interact_damage_cancel_threshold` (default 10 HP), the interact animation cancels: `_is_hand_busy = false` is set in the SAME method call that calls `Tween.kill()` on the interact tween — no `animation_finished` callback race. `player_interacted` does NOT fire for a cancelled interact. Below-threshold damage lets the interact complete.

Cancellation uses `Tween.kill()` rather than `AnimationPlayer.stop()` — both achieve the same synchronous-clear, but the Tween contract is more deterministic for a one-shot property interpolation. `_is_hand_busy` is cleared in the same stack frame as the kill.

### E.7 Simultaneous damage on same frame

Each `apply_damage()` call processes sequentially. Two `player_damaged` signals fire; `player_health_changed` fires twice (intermediate + final); `player_died` fires at most once (guarded by the DEAD-state early return).

### E.8 Spawn inside geometry

On `_ready()`, a depenetration shapecast runs: if the standing capsule overlaps static geometry, Eve is pushed upward 1 m and tested again; up to 5 attempts before logging a fatal error and teleporting to the last checkpoint's fallback spawn. Safety net, not a feature.

### E.9 Movement input before first physics frame

Input accumulates in Godot's `InputEvent` buffer. On first `_physics_process`, current action strengths are read normally — no input dropped, none reprocessed. Fade-in does not disable input (Pillar 1 no curtains; Pillar 5 no modern onboarding lockout).

### E.10 Ctrl held through scene transition

Crouch state persists across Level Streaming loads (part of `PlayerState` per ADR-0003). On load completion, if Ctrl is still held, Eve loads in Crouch. If the new spawn has a ceiling, E.1 applies.

### E.11 Interact target destroyed mid-reach

The reach animation completes, then `player_interacted` fires with `target = null`. Downstream systems MUST tolerate null target (documented in Signal Bus GDD). In practice, script-driven destruction during reach is disallowed at Mission Scripting level.

### E.12 Out-of-bounds fall

A kill-plane `Area3D` at world Y = `kill_plane_y` (default -50 m) triggers `apply_damage(999.0, kill_plane_node, CombatSystem.DamageType.OUT_OF_BOUNDS)` on crossing, killing Eve and routing to the respawn system. Bug-recovery path, not a gameplay feature.

### E.13 Dead state entered with interact in-flight

Interact animation hard-cancels (same path as E.6). Hand mesh snaps to "down" pose. `player_interacted` does NOT fire. `reset_for_respawn` clears `_is_hand_busy`, `_latched_event`, and state per the respawn contract.

## Dependencies

### Upstream (must exist first)

| System | GDD | Why |
|---|---|---|
| Input | `design/gdd/input.md` ✅ | 26-action catalog |
| Signal Bus | `design/gdd/signal-bus.md` ✅ | `player_*` signal contracts |
| Outline Pipeline | `design/gdd/outline-pipeline.md` ✅ | Stencil contract (hands exempted per ADR-0005) |
| FootstepComponent | `design/gdd/footstep-component.md` ⏳ (Session F sibling) | Owns `player_footstep` emission |
| ADR-0001 | Stencil ID Contract | Outline for every non-hands mesh |
| ADR-0002 | Signal Bus + Event Taxonomy | Signal signatures, no per-frame signals |
| ADR-0003 | Save Format Contract | `PlayerState` schema |
| ADR-0005 | FPS Hands Outline Rendering | Inverted-hull exception |
| ADR-0006 | Collision Layer Contract | `PhysicsLayers` constants |

### Downstream (consumers of this GDD's interfaces)

| System | Planned GDD | What they consume |
|---|---|---|
| Stealth AI | `stealth-ai.md` ⏳ | `get_noise_level`, `get_noise_event` (idempotent-read), `get_silhouette_height`, `global_transform.origin`. Owns occlusion + propagation. Must NOT subscribe to `player_footstep`. |
| Combat & Damage | `combat-damage.md` ⏳ | `apply_damage` method; owns `DamageType → DeathCause` mapping. |
| Inventory & Gadgets | `inventory-gadgets.md` ⏳ | `HandAnchor`, `is_hand_busy`, `apply_heal` (medkit). |
| HUD Core | `hud-core.md` ⏳ | `player_health_changed` signal + `get_current_interact_target` poll + `is_hand_busy`. |
| Audio | `audio.md` ✅ | FootstepComponent's `player_footstep`; `player_died` for mix ducking. |
| Failure & Respawn | `failure-respawn.md` ⏳ | `player_died` signal; calls `reset_for_respawn(checkpoint)`. |
| Mission Scripting | `mission-scripting.md` ⏳ | Position queries + `player_interacted`. |
| Save / Load | `save-load.md` ✅ | `PlayerState` sub-resource. |
| Document Collection | `document-collection.md` ⏳ (VS) | `player_interacted` with `Document` target. |
| Settings & Accessibility | TBD ⏳ | Provides look-sensitivity overrides + `get_resolution_scale` consumed by hands outline (AC-9.2). |

### Bidirectional dependency statements (cross-GDD consistency)

- **Stealth AI** must document: "reads `player.get_noise_level()`, `player.get_noise_event()` (idempotent-read; auto-expiry is the sole clear), `player.get_silhouette_height()` per perception tick; queries `global_transform.origin` for continuous-locomotion noise localisation; owns occlusion + elevation + surface propagation math; does not subscribe to `player_footstep`; callers needing to remember a spike must copy `{type, radius_m, origin}` into their own state before the next physics frame."
- **Combat & Damage** must document: "delivers damage via `player.apply_damage(amount, source, damage_type)`; owns `DamageType → DeathCause` mapping used by `player_died`; subscribes to `player_damaged` only for logging/analytics."
- **Inventory & Gadgets** must document: "attaches held items to `player.HandAnchor`; queries `player.is_hand_busy()` before showing interact prompts; calls `player.apply_heal(amount, source)` on medkit pickup."
- **Failure & Respawn** must document: "subscribes to `player_died`; calls `player.reset_for_respawn(checkpoint)` to reset Eve; owns the fade + sequence."
- **Save / Load** must document: "serializes `PlayerState` sub-resource (position, rotation, health: int, current_state: int); deserializes on checkpoint load."
- **FootstepComponent** (sibling) must document: "attaches as child of PlayerCharacter; reads `player.current_state` + `player.velocity` + ground surface raycast; emits `player_footstep` for Audio; does NOT mutate player state or `_latched_event`."

### Dependency risk notes

- **Stealth AI** is the gating technical-risk system. Session F scaled the hard-landing noise (OQ-7) and raised Sprint noise (GD-B3). If Stealth AI discovers it needs per-surface audibility weighting or wall-occlusion inputs PC doesn't publish, `NoiseEvent` can be extended with new fields without breaking the pull-method contract.
- **Noise propagation split** (load-bearing): PC publishes source (origin, radius, type). Stealth AI owns propagation (occlusion raycasts, elevation attenuation, surface absorption, per-guard distance/LOS modifiers). If this blurs, PC will accrete per-guard fields that violate its single-responsibility boundary. Enforce at code review via Forbidden Patterns.
- **Latch tick-boundary risk**: a spike recorded immediately before an AI tick boundary is reliably seen by that tick (latch_duration_frames = 6 ≥ 1 AI-tick frame at 10 Hz). A spike recorded immediately AFTER a tick is seen by the NEXT tick. No spike is lost within the auto-expiry window. Monitored at Stealth AI integration — if AI tick rate ever drops below 10 Hz, raise `spike_latch_duration_sec` proportionally.
- **FootstepComponent split risk**: the R-19 promotion (Session F) removes the dual-ownership seam. If a future change re-couples footstep audio emission to noise-level scalar updates, the single failure point returns — enforce at code review.
- **Inventory heal dependency**: `apply_heal` is defined but has no caller until Inventory & Gadgets GDD + Mission & Level Scripting medkit placement land. F.7 compiles and is unit-testable today.

## Tuning Knobs

Designer-facing knobs only (15 total). Each serves a pillar or is balance-critical. Engine-correctness parameters live in the **Correctness Parameters** sidebar below, separated so they don't clutter the designer-tuning surface.

### Movement (3)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `walk_speed` | 3.5 m/s | 2.8 – 4.2 | Baseline pace. Below 2.8 sluggish; above 4.2 reads as jog (breaks Deadpan Witness). |
| `sprint_speed` | 5.5 m/s | 4.5 – 6.5 | Traversal burst. Below 4.5 makes sprint pointless; above 6.5 reads as parkour. |
| `crouch_speed` | 1.8 m/s | 1.4 – 2.2 | Stealth. Below 1.4 frustrates; above 2.2 makes crouch the default movement. |

### Vertical (3) — with cross-knob constraints

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `gravity` | 12.0 m/s² | **11 – 13** | Fall speed. Tightened from 9.8–15.0 because prior bounds produced 1.28 m apex at one extreme (Pillar 5 violation: clears desks) and 0.30 m apex at the other (unplayable mantle). Session F — closes 3rd re-review jump-apex blockers. |
| `jump_velocity` | 3.8 m/s | **3.5 – 4.2** | Apex height. Tightened from 3.0–5.0 for the same reason. |
| `hard_land_height` | 1.5 m | **1.2 – 3.0** | Drop height that triggers scaled hard-landing noise (F.3). Min tightened from 1.0 m so flat-ground jump at any safe combination does NOT trigger hard landing. |

**Cross-knob constraints (REQUIRED to preserve pillars, verified numerically in this table):**
- **Max apex ≤ 0.80 m** at every safe combination. Worst case: `(v=4.2, g=11) → H = 17.64 / 22 = 0.80 m`. Pillar 5 — no parkour.
- **Min apex ≥ 0.45 m** at every safe combination. Worst case: `(v=3.5, g=13) → H = 12.25 / 26 = 0.47 m`. Playable low-obstacle mantle.
- **Flat-ground jump never triggers hard landing** at every safe combination. Worst case: `v_flat_land = 4.2 m/s` vs `v_land_hard_min = sqrt(2 × 11 × 1.2) ≈ 5.14 m/s`. `4.2 < 5.14` ✓.

Changing any vertical knob outside these safe ranges requires a design review — it breaks pillar alignment, not just feel. Verified by AC-2.2.

### Noise (6 per-state + 1 scalar)

| Knob | Default (m) | Safe range | Affects |
|---|---|---|---|
| `noise_walk` | 5.0 | 3.5 – 7.0 | Walk locomotion noise (`FOOTSTEP_NORMAL`). |
| `noise_sprint` | **12.0** | 10.0 – 14.0 | Sprint locomotion noise (`FOOTSTEP_LOUD`). **Raised from 9.0 to 12.0 in Session F (GD-B3 close)**: Sprint's speed-per-noise was 0.61 m/m at 9 m (Walk 0.70, Crouch 0.60) — making Sprint a viable stealth strategy. At 12 m it's 0.46 — strictly worse than Walk and Crouch, restoring Sneak/Crouch as the dominant stealth strategy (Pillar 3). |
| `noise_crouch` | 3.0 | 2.0 – 4.5 | Crouch locomotion noise (`FOOTSTEP_SOFT`). |
| `noise_jump_takeoff` | 4.0 | 3.0 – 6.0 | Takeoff spike radius (`JUMP_TAKEOFF`). |
| `noise_landing_soft` | 5.0 | 4.0 – 7.0 | Soft landing spike radius (`LANDING_SOFT`). |
| `noise_landing_hard_base` | 8.0 | 7.0 – 10.0 | Base hard-landing radius; scaled up to 2× per F.3. |

**`noise_global_multiplier` — SHIP VALUE LOCKED TO 1.0** (game-designer B-2, 2026-04-21). This knob was previously tunable in 0.7–1.3 range as a designer balance-pass tool. It has been removed from the designer-facing tuning surface and locked to `1.0` in the shipping build. Rationale: the game ships with NO difficulty selector by design mandate. A runtime-tunable global noise multiplier is a difficulty-selector backdoor that Mission Scripting, Accessibility, or a future modding interface could set. Internal constant only; NOT accessible from any system other than this GDD's own balance-pass tooling. Any change to the ship value requires a new ADR. Forbidden Patterns CI lint enforces: no write to `noise_global_multiplier` from Mission Scripting, Accessibility, Save/Load, or network code.

### Interact (3)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `interact_ray_length` | 2.0 m | 1.5 – 3.0 | Reach. Below 1.5 forces nose-to-object; above 3.0 ghost-interacts. |
| `interact_pre_reach_ms` | 150 | 100 – 250 | Deadpan Witness pause before hand moves. Zero kills fantasy. |
| `interact_damage_cancel_threshold` | 10 HP | 5 – 20 | Single-call damage that cancels an in-flight interact (E.6). |

### Camera (2)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `camera_fov` | 75° | 70 – 90 | Horizontal FOV. Lower = claustrophobic + period-correct (1965 film lenses); higher = modern. |
| `turn_overshoot_deg` | 4.0° | 2.5 – 4.5 | Deadpan Witness settle amplitude. Zero kills the fantasy; above 4.5 reads as drunk/motion-sick. |

### Health (1)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `max_health` | 100 | 50 – 200 | Health ceiling. Changing requires Combat & Damage rebalancing. `starting_health` is always equal to `max_health` on mission start — not a designer knob. |

### Tuning authority

- **Game Designer** owns: speeds, noise (all per-state + multiplier), health.
- **Art Director** owns: camera FOV, turn overshoot, interact pre-reach (Player Fantasy feel).
- **Gameplay Programmer** owns: all Correctness Parameters (sidebar below).

### Correctness Parameters (engine-side, not designer-tunable)

These values ship as internal constants or `@export` properties hidden from the designer-tuning surface. They exist so the engine/gameplay programmer can adjust for platform/physics-engine specifics without touching designer balance.

| Parameter | Default | Why here, not above |
|---|---|---|
| `walk_accel_time` / `walk_decel_time` / `sprint_accel_time` / `crouch_transition_time` | 0.12 / 0.18 / 0.15 / 0.12 s | Advanced feel — lives in `PlayerFeel.tres` resource, adjusted by art-director + programmer together, not per-designer balance pass. Validated by `@export_range` + F.1 NaN guard. |
| `raycast_max_iterations` | 4 | Cap on F.5 iteration loop. Trade-off is Jolt query cost per iteration (~0.05 ms), not design feel. |
| `interact_min_separation` | 0.15 m | Level-design QA constraint — verified at content review, not runtime-enforced. |
| `interact_reach_duration_ms` | 225 | Animation duration owned by hand animation author. |
| `camera_y_standing` / `camera_y_crouched` | 1.6 / 1.0 m | Derived from body collider — changing collider without adjusting these breaks eye-height sightlines. |
| `pitch_clamp_deg` | 85° | Avoids gimbal flip at ±90°. |
| `turn_overshoot_return_ms` | 90 | Settle duration partner to the designer-owned amplitude knob. |
| `idle_velocity_threshold` | 0.1 m/s | Speed below which Walk/Crouch treats Eve as silent. |
| `spike_latch_duration_sec` | **0.15 s** | AI-tick synchronization window. **Raised from 0.1 → 0.15 s on 2026-04-21** (ai-programmer B-2): 0.1 s = 6 frames @ 60 Hz did NOT cover every 10 Hz guard poll phase; 0.15 s = 9 frames @ 60 Hz = 1.5× AI-tick window = every phase offset within a single AI tick (+ 1-frame jitter headroom) sees the latch. Physics-tick-rate-independent via runtime frame conversion. |
| `noise_global_multiplier` | 1.0 (locked) | Ship value is 1.0 — see Tuning Knobs → Noise for the governance rule. Internal-only; not designer-tunable per game-designer B-2 closure. |
| `coyote_time_frames` | 3 | Jolt stair-edge transient tolerance. |
| `kill_plane_y` | -50 m | Out-of-bounds safety net. |

**Input-derived (external ownership)**: `mouse_sensitivity_x`, `mouse_sensitivity_y`, `gamepad_look_sensitivity` are owned by the Settings & Accessibility GDD (forward dependency). PC consumes them from `Settings` at runtime; ship-defaults live in `res://src/core/settings_defaults.gd` until that GDD lands.

## Visual/Audio Requirements

### Visual — FPS Hands Mesh

- **Geometry**: one skinned mesh, ~5k tris, minimal arm + hand skeleton (shoulder, elbow, wrist, 5 finger chains; 18 bones).
- **Material**: Courrèges navy glove/sleeve palette (Art Bible §5.1). Matte, no specular. Single 1024² albedo.
- **Outline**: visually matches tier HEAVIEST (4 px at 1080p, `#1A1A1A`) via inverted-hull shader per **ADR-0005**. The `HandsOutlineMaterial` shader's `resolution_scale` uniform is wired to `Settings.get_resolution_scale()` (forward dependency — see Settings & Accessibility). Outline always visible in gameplay — hands are diegetic UI.
- **Default pose**: arms down, slightly forward, hands relaxed. "Idle FPS rest" when no gadget is equipped.
- **Attach points**: `HandAnchor` (child of `Camera3D`); `LeftHandIK`, `RightHandIK` for gadget-specific two-handed poses.

**SubViewport compositing (corrected in Session F).** Hands render inside a `SubViewport` at FOV 55° (narrower than world FOV 75°) to prevent stretched-gorilla-arms and world-clipping. The SubViewport texture is drawn over the main view via a dedicated `CanvasLayer` (layer 10). **The outline is baked INSIDE the SubViewport** — `HandsOutlineMaterial`'s inverted-hull pass renders in the SubViewport's own render target, not composited atop the final frame with a shared stencil buffer. The world's stencil-based `CompositorEffect` runs independently on the main viewport; the two outline systems do not share stencil state (ADR-0005 depth + stencil isolation). The prior wording "composited AFTER the world's outline CompositorEffect completes" conflated SubViewport-to-main-viewport blit with a shared-stencil pipeline; that wording is withdrawn.

### Visual — Camera Feel

| Behavior | Spec |
|---|---|
| Walk head-bob | **None** — Deadpan Witness. |
| Sprint sway | Shallow lateral, ~0.8 s period, ~0.5° amplitude. |
| Turn overshoot | 4.0° (default; safe 2.5–4.5), 90 ms ease-out on rapid yaw (> 180°/s). |
| Crouch drop | 120 ms ease-in-out, camera Y 1.6 → 1.0 m. |
| Soft landing | No visible dip. |
| Hard landing | 4–6° downward pitch dip, 150 ms ease-out (threshold per F.3; noise scales per F.3). |
| Interact pre-reach | 150 ms pause — camera static, hand static. Eve is *noticing*. |
| Interact reach | 200–250 ms hand animation; camera unaffected. |

### Visual — Dead State

Camera pitches down 60° over 800 ms, translates to Y = 0.4 m (head on floor). No slow-motion. No red vignette (Pillar 5). Sepia fade over 1.5 s, then hard-cut to the Failure & Respawn screen.

### Visual — Mirror Reflection (MVP deferral)

No full body mesh at MVP. Mirrors reflect environment + silhouette decal. Full body mesh for mirror reflection is VS-tier (OQ-4).

### Audio

PlayerCharacter itself emits only vocal/breathing and the dead-state exhale. All footstep + surface SFX live in the FootstepComponent sibling doc — see `design/gdd/footstep-component.md`.

- **Idle breathing**: quiet continuous breath loop, volume −24 dB relative to footsteps. Subtle enough to never mask ambient or dialogue; absence would read as dead silence. Hitman/NOLF1 precedent.
- **Walk breathing**: same quiet loop continues — not stride-tied.
- **Sprint breathing**: subtle loop layered under footsteps, −12 dB relative to footsteps. Replaces the idle loop while Sprint is active (single breath bed, not a stack).
- **Hard landing**: single "huf" vocal (no pain, no grunt — Deadpan Witness).
- **Dead**: single controlled exhale (150 ms), then silence.
- **Interact reach**: subtle fabric-rustle SFX (Courrèges glove sliding). Pre-reach pause is silent.
- **Pickup/activation SFX**: owned by the downstream system (Document Collection, Inventory, Mission Scripting). PC does not emit an interact-complete sound.

**Mix bus routing**: all PC body sound routes to the canonical `SFX` bus (Audio GDD 5-bus model: Music, SFX, Ambient, Voice, UI). Breathing on `SFX` ducks under VO per Audio GDD Rule 7. `Voice` bus is reserved for dialogue.

**Vocal talent constraint**: Eve's voice actress (TBD per future narrative GDD) records all breathing + vocalization lines. No library-pack "ughs".

## UI Requirements

Ownership split: **PC provides signals + state queries; HUD Core GDD owns widget rendering.**

### Signals published (for HUD consumption)

| Signal | Payload | HUD behavior |
|---|---|---|
| `player_health_changed` | `(current: float, max_health: float)` | Numeric readout (NOLF1-style, not segmented). Art Bible §7B. |
| `player_damaged` | `(amount: float, source: Node, is_critical: bool)` | Optional ~150 ms flash on the number. No damage direction indicator (Pillar 5). `is_critical` always `false` at MVP. |
| `player_died` | `(cause: CombatSystem.DeathCause)` | Transitions HUD to Failure & Respawn pathway. |
| `player_interacted` | `(target: Node3D)` (may be null per E.11) | Clears interact highlight on receipt. |

### Queries (for HUD polling)

| Query | Return | Use |
|---|---|---|
| `get_current_interact_target()` | `Node3D` or `null` | Drives interact prompt + outline tier 2 highlight. |
| `is_hand_busy()` | `bool` | Suppresses interact prompt during pre-reach + reach window. |

### HUD renders (spec in HUD Core GDD)

Numeric health readout (3-digit space: `100`, `099`, `008`); critical-health color shift to Alarm Orange below 25 (Art Bible §4.4), paired with the numeric value (colorblind-safe — not color-only); interact prompt (short dry text, e.g. "Read note"); gadget slot indicator (Inventory-owned).

### HUD must NOT render

Stamina bar; crouch indicator icon; damage direction indicator; sprint cooldown meter; hit marker; hold-E progress ring. (See Forbidden Patterns.)

### Accessibility

- Interact prompt text respects the UI scaling setting (ADR-0004 Theme inheritance).
- Critical-health Alarm Orange is paired with a number — colorblind players read the value, not just the hue.
- Interact highlight outline is always shown (tier 2) — not a color-only affordance.

### Input responsiveness promise

Health numeric update fires within one physics frame (< 16.7 ms) of damage resolution. Interact prompt appears within one physics frame of target entering the 2.0 m ray. Crouch state change triggers no UI element — only the camera + collider change.

## Cross-References

### Upstream GDDs

[Input](input.md), [Signal Bus](signal-bus.md), [Outline Pipeline](outline-pipeline.md), [Post-Process Stack](post-process-stack.md), [Audio](audio.md), [FootstepComponent](footstep-component.md) (Session F sibling).

### Downstream GDDs (this GDD defines their contracts)

Stealth AI, Combat & Damage, Inventory & Gadgets, HUD Core, Failure & Respawn, Mission & Level Scripting, Save / Load, Document Collection, Settings & Accessibility.

### Required ADRs

- [ADR-0001 — Stencil ID Contract](../../docs/architecture/adr-0001-stencil-id-contract.md)
- [ADR-0002 — Signal Bus + Event Taxonomy](../../docs/architecture/adr-0002-signal-bus-event-taxonomy.md)
- [ADR-0003 — Save Format Contract](../../docs/architecture/adr-0003-save-format-contract.md)
- [ADR-0004 — UI Framework](../../docs/architecture/adr-0004-ui-framework.md)
- [ADR-0005 — FPS Hands Outline Rendering](../../docs/architecture/adr-0005-fps-hands-outline-rendering.md)
- [ADR-0006 — Collision Layer Contract](../../docs/architecture/adr-0006-collision-layer-contract.md)

### Art Bible

- §5.1 — Character Art Direction (Eve's outfit, silhouette)
- §4.4 — Color Palette (Alarm Orange for critical health)
- §7B — HUD Direction (NOLF1-style numeric readout)

### Game Concept

- Pillar 1, Pillar 3, Pillar 5, Visual Identity Anchor

### Forbidden Patterns (Control Manifest excerpt)

The following patterns must be flagged at code review. They are NOT AC-gated because they are *policy* rather than *behavior* — see `docs/architecture/control-manifest.md` for the authoritative project-wide list.

- Stamina counter of any kind (visible or hidden).
- Head-bob on walk, sprint whoosh, sprint motion blur, sprint FOV punch.
- **Camera sway on Walk state.** Sprint carries a deliberate ~0.5° lateral pace-sway (legs swinging wider at pace — see Visual/Audio Camera Feel + Player Fantasy). Sprint sway at amplitudes > 0.5° OR on Walk/Crouch/Idle states is forbidden — the Sprint-only sway is the single documented Deadpan Witness exception. Art Director owns the amplitude tuning.
- Damage-edge red vignette; hit-marker crosshair.
- Hold-E interact progress ring or context menu.
- Bunny-hop crouch-jump.
- `OutlineTier.set_tier` called on the hands mesh (hands use inverted-hull per ADR-0005).
- Stealth AI code subscribing to `player_footstep` (AI reads `get_noise_level` / `get_noise_event` only).
- Retention of the `NoiseEvent` reference across physics frames (copy fields instead).
- Reading `_latched_event` directly from outside PlayerCharacter (only via the getter).
- Mutating `player.health` from any system other than `apply_damage` or `apply_heal`.
- **Writing to `noise_global_multiplier` from Mission Scripting, Accessibility, Save/Load, or network code.** Ship-locked to 1.0 per game-designer B-2 close (2026-04-21). Changing the ship value requires a new ADR — it is a difficulty-selector equivalent and the game ships without difficulty selection by mandate.
- Reallocating the latched `NoiseEvent` per spike instead of in-place field mutation (breaks the zero-allocation-at-80-Hz invariant documented at F.4).

### External references (NOLF1 fidelity targets)

- *No One Lives Forever* (2000) — single-button interact, no quip-on-pickup, no stamina UI.
- *Thief: The Dark Project* (1998) — noise radius as core stealth mechanic.
- *The Avengers* (1960s TV) — Emma Peel's camera-tilt-as-eyebrow (Deadpan Witness).

## Acceptance Criteria

Each AC is binary (pass/fail), carries a story-type label, names its measurement method + threshold, and points at a test-evidence path.

### AC-1 Movement speed

- **AC-1.1 [Logic]** Walking forward on flat terrain with `input_magnitude == 1.0`: `velocity.length()` reaches `walk_speed ± 0.1 m/s` within 9 physics frames (0.15 s @ 60 Hz) of key-press. Measured by per-frame velocity log. Evidence: `tests/unit/player/player_walk_speed_test.gd`.
- **AC-1.2 [Logic]** Sprint from rest reaches `sprint_speed ± 0.1 m/s` within 12 physics frames (0.20 s). Evidence: `tests/unit/player/player_sprint_speed_test.gd`.
- **AC-1.3 [Logic]** Crouch-walk reaches `crouch_speed ± 0.1 m/s` within 9 physics frames (0.15 s); `CapsuleShape3D.height == 1.1 m` at the end of the crouch transition. Evidence: `tests/unit/player/player_crouch_speed_test.gd`.

### AC-2 Jump and landing

- **AC-2.1 [Logic]** At defaults (`gravity=12.0, jump_velocity=3.8`), flat-ground jump apex ∈ [0.55, 0.65] m. Apex measured as `max(global_position.y) - global_position.y_at_takeoff` sampled every physics frame. Tolerance widened from ±0.02 m to ±0.05 m per game-designer advisory note on Jolt's stochastic `is_on_floor()` edge behavior. Evidence: `tests/unit/player/player_jump_apex_test.gd`.
- **AC-2.2 [Logic]** **Safe-range invariants** (parametrized test sweeping `gravity ∈ {11, 12, 13}` × `jump_velocity ∈ {3.5, 3.8, 4.2}` — 9 combinations, explicitly including the four corners `(11, 3.5)`, `(11, 4.2)`, `(13, 3.5)`, `(13, 4.2)` where the apex invariants are most likely to break):
  - For all 9 combinations: `0.45 m ≤ apex ≤ 0.80 m` (corner-worst-cases: `(11, 4.2) → 0.80 m` ceiling; `(13, 3.5) → 0.47 m` floor — both verified by the sweep).
  - For all 9 combinations: a flat-ground jump's landing frame does NOT latch `PlayerEnums.NoiseType.LANDING_HARD` (assert `get_noise_event() == null` OR `get_noise_event().type != LANDING_HARD` at the first `is_on_floor()` frame after Jump).
  - Evidence: `tests/unit/player/player_jump_safe_range_test.gd`.
- **AC-2.3 [Logic]** Hard landing with `|velocity.y| > v_land_hard`: `get_noise_event().type == LANDING_HARD` AND `radius_m == 8.0 × clamp(|velocity.y| / v_land_hard, 1.0, 2.0)` within ±0.1 m tolerance. Verified at three impact speeds (1.0×, 1.5×, 2.0× `v_land_hard`) with expected radii (8.0, 12.0, 16.0). Evidence: `tests/unit/player/player_hard_landing_scaled_test.gd`.

### AC-3 Noise interface

- **AC-3.1 [Logic]** `get_noise_level()` returns `{WALK: 5.0, SPRINT: 12.0, CROUCH: 3.0}` × `noise_global_multiplier` when `velocity.length() >= idle_velocity_threshold` and no spike is latched. Separately, Walk-at-rest and Crouch-at-rest (`velocity.length() < idle_velocity_threshold`) return `0.0` regardless of multiplier. Verified at multipliers `{0.7, 1.0, 1.3}`. Evidence: `tests/unit/player/player_noise_by_state_test.gd`.
- **AC-3.2 [Logic]** **Idempotent-read**: after recording a JUMP_TAKEOFF spike, 10 consecutive `get_noise_event()` calls within `spike_latch_duration_frames` return the same non-null reference with identical `type`, `radius_m`, `origin` fields. Evidence: `tests/unit/player/player_noise_event_idempotent_test.gd`.
- **AC-3.3 [Logic]** **Highest-radius-wins collapse**: recording JUMP_TAKEOFF (4 m) then LANDING_SOFT (5 m) within 2 physics frames results in `get_noise_event().type == LANDING_SOFT` for the remainder of the latch window. Reverse order (5 m first, then 4 m) retains the 5 m event (equal-or-lower new radius does not overwrite). Evidence: `tests/unit/player/player_noise_event_collapse_test.gd`.
- **AC-3.4 [Logic]** **Latch auto-expiry**: after recording a spike, advancing `spike_latch_duration_frames + 1` physics frames causes `get_noise_event()` to return `null`. `get_noise_level()` during the expired window returns the continuous state-keyed value, not the spike value. Evidence: `tests/unit/player/player_noise_latch_expiry_test.gd`.
- **AC-3.5 [Logic]** **Reference retention footgun** (documents the "must copy" contract via a test that FAILS if violated): a stub consumer stores the reference returned by `get_noise_event()`; after a subsequent spike overwrites the latch, reading `stored.origin` returns the NEW spike's origin — not the one the consumer stored. Test passes by asserting the footgun behaviour, proving the contract is real. Evidence: `tests/unit/player/player_noise_event_retention_test.gd`.

### AC-4 Interact resolution

- **AC-4.1 [Logic]** With a stub Document (priority 0) and a stub Door (priority 3) both on `LAYER_INTERACTABLES` within 2.0 m of the camera, `_resolve_interact_target()` returns the Document regardless of their order along the ray. Evidence: `tests/unit/player/player_interact_priority_test.gd`.
- **AC-4.2 [Logic]** **Cap-exceeded warning**: with `raycast_max_iterations + 1` stacked interactables, `_resolve_interact_target()` emits `push_warning` exactly once (captured via GUT's `assert_warned` helper) AND returns the lowest-priority-within-cap. Evidence: `tests/unit/player/player_interact_cap_warning_test.gd`.
- **AC-4.3 [Integration]** E-press flow: HUD-highlighted object each frame matches `_resolve_interact_target()` (HUD-coherence); `is_hand_busy()` is true for `interact_pre_reach_ms + interact_reach_duration_ms ± 10 ms`; `player_interacted` fires exactly once on reach complete. Evidence: `tests/integration/player/player_interact_flow_test.gd`.

### AC-5 Damage application

- **AC-5.1 [Logic]** `apply_damage(25.0, stub_source, CombatSystem.DamageType.TEST)` from `health=100`: `health == 75` afterwards; emits `player_damaged(25.0, stub_source, false)` THEN `player_health_changed(75.0, 100.0)` in order (verified via signal-order spy). Evidence: `tests/unit/player/player_damage_basic_test.gd`.
- **AC-5.2 [Logic]** **Rounding boundary — parametrized test over {0.3, 0.49, 0.5, 1.5}** (systems-designer B1 fix, 2026-04-21):
  - `apply_damage(0.3, stub_source, DamageType.TEST)`: `health` unchanged, zero signals emitted.
  - `apply_damage(0.49, stub_source, DamageType.TEST)`: `health` unchanged, zero signals emitted.
  - `apply_damage(0.5, stub_source, DamageType.TEST)`: `health` decreased by exactly 1, `player_damaged(0.5, ...)` and `player_health_changed(99, 100)` both emit.
  - `apply_damage(1.5, stub_source, DamageType.TEST)`: `health` decreased by exactly 2, both signals emit with the raw `1.5` in the damage signal's `amount` payload.
  Locks the round-half-away-from-zero boundary behavior documented in F.6. Evidence: `tests/unit/player/player_damage_rounding_guard_test.gd`.
- **AC-5.3 [Logic]** `apply_damage(999.0, stub_source, DamageType.TEST)` from full health: `health == 0`, emits `player_died` exactly once with `cause == CombatSystem.damage_type_to_death_cause(DamageType.TEST)`, state transitions to `PlayerEnums.MovementState.DEAD`. Subsequent `apply_damage` calls emit no additional signals. Evidence: `tests/unit/player/player_damage_lethal_test.gd`.

### AC-6 Respawn contract

- **AC-6.1 [Logic]** **Same-frame reset invariants** (ai-programmer B-4 fix, 2026-04-21). Within the SAME physics frame in which `reset_for_respawn(stub_checkpoint)` is called from DEAD state, ALL of the following must hold BEFORE any subsequent `_physics_process` tick:
  - `health == max_health`.
  - `current_state == PlayerEnums.MovementState.IDLE`.
  - `is_hand_busy() == false`.
  - `get_noise_event() == null` (latch is cleared synchronously; a stub AI guard polling on the same frame as respawn reads null, not a stale spike).
  - `global_transform.origin.distance_to(stub_checkpoint.respawn_position) < 0.001 m`.
  - `player_health_changed(max_health, max_health)` has emitted exactly once.
  Test procedure: call `reset_for_respawn(stub)`, assert all of the above on the same stack frame (before yielding to the next physics tick). Evidence: `tests/unit/player/player_reset_for_respawn_test.gd`.
- **AC-6.2 [Logic]** **DEAD-state latch clearance** (ai-programmer B-1 fix, 2026-04-21). After `apply_damage` lethally damages Eve (state transitions to DEAD), `get_noise_event()` returns `null` AND `get_noise_level()` returns `0.0` on the SAME physics frame, even if `_latched_event` was non-null immediately before the damage application. Verified by: (1) latching a `JUMP_TAKEOFF` spike, (2) calling `apply_damage(999.0, ...)` in the next physics tick, (3) asserting `get_noise_event() == null` on the post-damage same-frame read. Evidence: `tests/unit/player/player_dead_state_latch_clear_test.gd`.

### AC-7 Camera

- **AC-7.1 [Logic]** **FOV configuration** (qa-lead label split, 2026-04-21): at `_ready()`, `abs(Camera3D.fov - 75.0) <= 0.1`. Property-only assertion, no scene-tree integration required. Evidence: `tests/unit/player/player_camera_fov_test.gd`.
- **AC-7.2 [Integration]** **Pitch clamp** (qa-lead 1+3 fix, 2026-04-21). Inject synthetic pitch input via `Input.parse_input_event(ev)` where `ev = InputEventMouseMotion.new()` with `ev.relative = Vector2(0, 1_000_000)` (pushes pitch far past its clamp in a single frame); after one `_physics_process` tick, assert `abs(camera.rotation.x) <= deg_to_rad(85.0) + 0.001` (tolerance of 0.001 rad ≈ 0.057° for float epsilon). Reverse sign check: `ev.relative = Vector2(0, -1_000_000)` clamps to `-deg_to_rad(85.0) - 0.001 <= camera.rotation.x`. Previous wording using the truncated literal `1.484 rad` was wrong: `deg_to_rad(85.0) = 1.4835298...`, so a perfectly-clamped camera would have FAILED that bound. Evidence: `tests/integration/player/player_camera_pitch_clamp_test.gd`.
- **AC-7.3 [Integration]** **Body-yaw + camera-pitch split**: look-left/right input rotates `body.rotation.y`; look-up/down input rotates `camera.rotation.x`. Injection via `Input.parse_input_event(InputEventMouseMotion)` as in AC-7.2. A test that rotates the body by +π/2 asserts the forward raycast originates from the camera but points along the body's new forward basis. Evidence: `tests/integration/player/player_camera_rotation_split_test.gd`.
- **AC-7.4 [Visual/Feel]** Rapid yaw (> 180°/s) produces perceptible overshoot ∈ [`turn_overshoot_deg - 0.5°`, `turn_overshoot_deg + 0.5°`] and settles within 90 ± 10 ms. Verified via 60-fps capture of `camera.basis.get_euler().y`. **Art-director sign-off criterion**: (a) overshoot amplitude is within stated tolerance on frame-by-frame measurement, (b) settle returns monotonically (no secondary oscillation), (c) the sway reads as "deliberate camera settle" and not "drunk". Evidence: `production/qa/evidence/player-camera-overshoot-[date].md` with art-director sign-off paragraph addressing a/b/c.

### AC-8 Serialization

- **AC-8.1 [Logic]** Saving writes a `PlayerState` resource with `position: Vector3, rotation: Vector3, health: int, current_state: int` (enum value — NOT a string). Stamina field is NOT present in the serialized output. Loading restores all four fields: `position.distance_to(loaded.position) < 0.001 m`, `rotation == loaded.rotation` (component-wise ±0.001 rad), `health == loaded.health`, `current_state == loaded.current_state`. Evidence: `tests/unit/player/player_serialization_test.gd`.

### AC-9 Outline pipeline conformance

- **AC-9.1 [Logic]** On `_ready()`: the hands `MeshInstance3D` has `HandsOutlineMaterial` applied via `material_overlay` (NOT `material_override` — overlay preserves the mesh's per-surface PBR materials for the fill pass; override clobbers them). The hands mesh does NOT appear in any `OutlineTier.set_tier` call. CI-lint rule `hands.*OutlineTier\.set_tier` enforces this at the file level. Evidence: `tests/unit/player/player_hands_outline_setup_test.gd`.
- **AC-9.2 [Logic — blocked]** `HandsOutlineMaterial.resolution_scale` uniform equals `Settings.get_resolution_scale()` on `_ready()` AND updates within one frame when `Events.setting_changed` fires for key `"resolution_scale"`. **This AC is BLOCKED on the Settings & Accessibility GDD landing** — not a conditional runtime skip. Until then: the test file `tests/unit/player/player_hands_resolution_scale_test.gd` exists as a stub calling GUT's `pending("blocked on Settings & Accessibility GDD — story ID TBD")`, and the PC hands outline story cannot reach DONE status until this dependency is authored. Tracked as a separate forward-dependency story, not an in-file annotation (qa-lead note — the `@if_settings_gdd_exists` pattern was non-standard and hid the dependency; replaced here with an explicit BLOCKED status + pending stub).
- **AC-9.3 [Visual/Feel]** Hands outline is visible in all gameplay lighting conditions AND during the sepia-dim death sequence. Outline visually matches tier HEAVIEST (4 px at 1080p, `#1A1A1A`) within perceptual tolerance of adjacent stencil-outlined world geometry. **Art-director sign-off criterion**: the reviewer views the test scene `tests/scenes/hands_outline_review.tscn` which contains the 7 reference lighting scenarios defined in Art Bible §lighting-QA (daylight interior, daylight exterior, night interior with warm practicals, night interior dim, night exterior, sepia death-state, plaza overcast) and confirms each scenario renders the hands outline as visible-and-black at perceptual-parity with world stencil outlines. Binary pass/fail: all 7 scenarios pass OR document which scenarios require outline tuning. Evidence: `production/qa/evidence/player-hands-outline-[date].md` with art-director sign-off paragraph enumerating all 7 scenarios.

### AC-6bis Silhouette height (F.8)

- **AC-6bis.1 [Logic]** In standing state (`current_state == IDLE/WALK/SPRINT`, `_crouch_transition_progress == 0.0`): `get_silhouette_height() == 1.7 ± 0.001 m`. In crouched state (`current_state == CROUCH`, `_crouch_transition_progress == 1.0`): `get_silhouette_height() == 1.1 ± 0.001 m`. Mid-transition at `_crouch_transition_progress == 0.5`: `get_silhouette_height() == 1.4 ± 0.001 m` (linear interpolation). DEAD state returns `0.4 ± 0.001 m`. Evidence: `tests/unit/player/player_silhouette_height_test.gd`.

### AC-10 Signal taxonomy conformance

- **AC-10.1 [Logic]** All player signals (`player_damaged`, `player_died`, `player_health_changed`, `player_interacted`) are emitted through the `Events` autoload (ADR-0002), not via direct node-to-node connections. Verified by spying on the `Events` autoload's signal emissions during a full `apply_damage` + interact sequence. Evidence: `tests/unit/player/player_signal_taxonomy_test.gd`.
- **AC-10.2 [Logic]** **Deterministic signal-rate guard** (qa-lead #4 fix, 2026-04-21). Drive a scripted sequence of 300 `_physics_process` ticks at `delta = 1.0 / 60.0`, exercising all state transitions (Idle → Walk → Sprint → Crouch → Jump → Fall → Landing → Interact → Damage → Respawn). Count total emissions of each player signal. Assert: `player_damaged_count ≤ 150`, `player_health_changed_count ≤ 150`, `player_interacted_count ≤ 150`, `player_died_count ≤ 5` — i.e., no signal exceeds the 30 Hz equivalent over the 5-second (300-tick) window (ADR-0002 anti-pattern guard). `get_noise_level()` and `get_noise_event()` are method calls, not signals. Driven via fixed-delta ticks rather than real-time capture — eliminates non-determinism per project testing standards. Evidence: same test file.

## Open Questions

### OQ-1 — Health regeneration: RESOLVED 2026-04-20

No regen. HP restored only by diegetic medkit pickups (placed by Mission & Level Scripting) + save reloads. `apply_heal` defined as F.7. Closes cross-review GD-B2.

### OQ-7 — Hard-landing noise severity: RESOLVED 2026-04-20 (Session F)

Scaled formula adopted: `noise_radius = 8.0 × clamp(|velocity.y| / v_land_hard, 1.0, 2.0)`. See F.3.

### OQ-8 — Air control: RESOLVED 2026-04-20 (Session F)

Option A (no air control). Jump/Fall preserve takeoff planar velocity. See Core Rules → Rejected features and F.1 scope gate.

### OQ-2 — Fall damage (deferred to VS)

Remain damage-free at MVP. Revisit when Observation Deck service-ladder drops are designed.

### OQ-3 — Lean system (deferred)

Forever-skip vs VS-tier add. Revisit when Stealth AI + first real level playtest reveals "peek out and back" play patterns.

### OQ-4 — Mirror reflection full body (deferred to VS)

Silhouette decal at MVP. Full body mesh at VS. Revisit with Narrative Director + Art Bible §5.1 revision.

### OQ-5 — FootstepComponent surface detection method (moved to sibling)

Moved out of this GDD as part of Session F split. Owned by `design/gdd/footstep-component.md`.

### OQ-6 — Eve verbalizes during gameplay (deferred)

Silent at MVP. Revisit with Narrative Director + Document Collection GDD.
