# Stealth AI

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists
> **Last Updated**: 2026-04-21
> **Implements Pillar**: 3 primary (Stealth is Theatre — graduated, reversible), 1 supporting (guard banter as comedy), 5 supporting (audio-only alert signaling)

## Overview

Stealth AI is simultaneously the **graduated-suspicion engine** that makes *The Paris Affair*'s stealth feel theatrical (Pillar 3) AND the **NPC guards** patrolling the Eiffel Tower whom the player outwits. The engine consumes Player Character's published perception surface — `get_noise_level()`, `get_noise_event()`, `get_silhouette_height()`, `global_transform.origin` (F.4 + F.8) — runs its own dual-channel perception (vision cones + hearing polls) with occlusion and distance modifiers, and drives each guard through a four-state alert lattice: **Unaware → Suspicious → Searching → Combat**. All three non-combat transitions are fully reversible — a guard who was briefly suspicious but lost the cue returns to Unaware (Pillar 3: *"Stealth is Theatre, Not Punishment"*).

Guards are `CharacterBody3D` NPCs with `NavigationAgent3D` patrol routes, a vision `Area3D` approximating their FOV cone, and a hearing poller running at 10 Hz on the player's noise surface. They publish four signals through the `Events` bus per ADR-0002: `alert_state_changed`, `actor_became_alerted`, `actor_lost_target`, `takedown_performed`. Audio subscribes for music ducking and stingers; Mission Scripting subscribes for objective triggers; Civilian AI subscribes for secondary-observer behaviour; Dialogue & Subtitles subscribes for contextual guard banter.

This is the **gating technical-risk system** per the game concept (line 223): graduated suspicion is the longest implementation pole. Perception-balance tuning happens against PC's published noise values (Walk 5 m / Sprint 12 m / Crouch 3 m per F.4; hard-landing spikes 8–16 m per F.3 scaled), locked to ship-value 1.0 multiplier. Takedowns at MVP: **melee non-lethal** (chloroform-style knockout from behind) + **silenced pistol** (lethal) — Inventory & Gadgets owns the verb implementations; Stealth AI owns the target-side effect (guard drops, state transitions to `Dead`, patrol route vacated).

**This GDD defines**: the 4-state alert lattice, perception math (sight + sound), patrol + investigate + flee behaviors, takedown target-side effects, signal contract. **This GDD does NOT define**: takedown weapon specs (Inventory & Gadgets), guard dialogue (Dialogue & Subtitles), patrol route authoring (Mission & Level Scripting), guard models/outline tiers (Art Bible + ADR-0001), save format (Save/Load consumes state via ADR-0003).

## Player Fantasy

**"Theatre, Not Punishment."** Guards in *The Paris Affair* are the **co-stars** of the player's stealth comedy, not obstacles to be optimized around. When a guard walks past Eve's hiding spot, the player feels the shape of a *scene*: the guard's footfalls crescendo, the player holds their breath, the guard arrives, glances, shrugs, walks on. The fantasy is **outwitting a competent opponent who takes themselves seriously** — not evading a video-game robot. The comedy lives in the space between the guard's self-importance and the absurdity of the situation.

**The graduated-suspicion model is the fantasy** — not a mechanic supporting one. Each state reads as a recognisable human reaction:

- **Unaware** — The guard is doing their job. Patrolling, smoking, muttering about dinner. Period-authentic dialogue. You can walk by (quietly), wait for them to turn the corner, or slip past.
- **Suspicious** — *"What was that?"* The guard has heard or glimpsed something; they haven't localised it. They stop. They look around. They call out ("Ça va?" or equivalent per future localisation). If nothing confirms the cue within ~4 seconds, they shrug and return to Unaware. This state is **diegetically legible** — the player hears the stop, hears the breath, sees the head turn.
- **Searching** — *"Something is definitely off."* The guard leaves their patrol and walks toward the last known position. They sweep the area, peer behind crates, open closets. They don't see Eve yet, but they're committed. If they find her, Combat. If they don't, Suspicious again (briefly), then Unaware. **This is the NOLF1 comedy moment** — the player hides, the guard investigates right past them, mutters *"Hmph, nothing"*, and goes back to patrol. The player feels smart; the guard feels stupid; nobody dies.
- **Combat** — *"Got you."* Guard has positively identified Eve. Engages — draws weapon, moves to cover, fires. This is the fail-forward state: the game continues, escape routes are open, other guards may be alerted via `actor_became_alerted` propagation, but the player isn't dead and isn't kicked to a load screen. **Combat is reversible only via distance + time** (the guard loses sight for > 8 seconds AND Eve is out of vision cone → back to Searching).

**References:** Emma Peel and Steed cat-burgling a villain's estate while the guards bumble around them (*The Avengers*). Cate Archer evading patrols in NOLF1's intro museum level. Garrett in *Thief* crouched in a shadow while the guard sweeps the room. Guards in *Hitman: Blood Money* with the extra comedy beat on false alarms.

**Pillars served:**
- **Pillar 3** (Stealth is Theatre, Not Punishment) — this system IS Pillar 3 kinesthetically. Reversibility is the load-bearing design choice. Detection opens a scene, it doesn't close the game.
- **Pillar 1** (Comedy Without Punchlines) — guard banter during Unaware + Suspicious is the primary comedy vector. Eve doesn't quip; the guards do, obliviously.
- **Pillar 5** (Period Authenticity) — no modern UX: no alert icon above the guard's head, no "!" meter, no minimap, no last-known-position marker on the HUD. Alert state is signaled through **audio + body language only** (Game Concept: *"Guard alert state shown via subtle audio cues + body language, not UI HUD bars"*).

**Design test:** *If the player ever says "that guard is bugged" instead of "that guard is funny/dangerous/suspicious" — we've failed the fantasy.* Guards must read as characters with lives, not as state machines with bugs.

**Kinesthetic specifics:**
- Footstep audio from guards is the primary "incoming guard" cue at distance (authored as guard-side audio parallel to PC's FootstepComponent — not in this GDD, but Stealth AI emits position for 3D audio).
- Alert state transitions are announced via **music shifts** (Audio GDD owns this: `alert_state_changed` → music stinger or bed change).
- Each guard has a **unique voice line pool** per section; repetition kills the comedy.
- When a guard enters Searching mode, they have a **characteristic investigate walk** (slower than patrol, slightly hunched, weapon drawn but not raised) — readable silhouette at distance.

## Detailed Design

### Core Rules

**Guard node architecture.** Each guard is a `CharacterBody3D` named after its type (e.g., `GuardPatrol`, `GuardStationary`) with the following children:

- `NavigationAgent3D` — pathfinding. Navigation mesh is authored per-section by Mission & Level Scripting (outside this GDD's scope).
- `VisionCone: Area3D` — approximates the guard's FOV as a cone-shaped `CollisionShape3D`. `layer = 0`, `mask = PhysicsLayers.MASK_PLAYER | MASK_AI_VISION_OCCLUDERS`. Detects entry via `body_entered`; the perception module then runs a line-of-sight raycast before counting it as sight.
- `HearingPoller: Node` — non-physics child that runs `_physics_process` at 10 Hz via internal tick counter, calling `player.get_noise_level()` + `player.get_noise_event()` and accumulating sound-suspicion.
- `Perception: Node` — suspicion accumulators (one per channel) + decay timers + last-known-position storage.
- `Weapon: MeshInstance3D` — holstered at Unaware/Suspicious; drawn at Searching; raised at Combat. Actual weapon mechanics (fire rate, damage) owned by Combat & Damage GDD.
- `DialogueAnchor: Node3D` — position for Dialogue & Subtitles to attach voice-line playback.
- `OutlineTier: ...` — guards are tier MEDIUM per ADR-0001.

Guards sit on `PhysicsLayers.LAYER_AI` per ADR-0006. `CharacterBody3D._ready()` sets `layer = MASK_AI`, `mask = MASK_WORLD | MASK_PLAYER` (guards cannot walk through Eve; collide with world geometry).

**Alert state ownership.** Each guard holds a single `current_alert_state: StealthAI.AlertState`. The enum lives on `StealthAI` per ADR-0002 Implementation Guideline 2 — NOT on `Events.gd`:

```gdscript
# res://src/gameplay/stealth/stealth_ai.gd
class_name StealthAI
extends Node

enum AlertState { UNAWARE, SUSPICIOUS, SEARCHING, COMBAT, DEAD }
enum AlertCause { HEARD_NOISE, SAW_PLAYER, SAW_BODY, HEARD_GUNFIRE, ALERTED_BY_OTHER, SCRIPTED }
```

`DEAD` is NOT a reachable alert state through suspicion; it is set only on takedown or lethal-damage resolution. The 4 graduated-suspicion states (`UNAWARE`, `SUSPICIOUS`, `SEARCHING`, `COMBAT`) are all reachable through perception.

**Dual-channel perception model.** Each guard runs two independent suspicion accumulators, each with its own threshold for triggering state escalation:

- **Sight suspicion** (`_sight_accumulator: float`, 0.0–1.0) — filled when Eve is inside the vision cone AND the LOS raycast succeeds AND her silhouette clears the relevant height band. Fill rate depends on range + silhouette height + Eve's movement state. Decays when LOS breaks.
- **Sound suspicion** (`_sound_accumulator: float`, 0.0–1.0) — filled when `player.get_noise_level()` exceeds a distance-occlusion-adjusted audibility threshold OR when `player.get_noise_event()` returns a non-null spike whose effective radius reaches the guard after propagation. Fill rate depends on how far noise exceeds threshold + event type. Decays over time when no audible source.

**Channel independence rationale**: NOLF1-style legibility. A player hears a guard react to *what they did* — "I heard something" vs "I saw something" produces different animations, different banter, and different investigate behaviors. A unified score collapses this distinction.

**State escalation rule.** When either accumulator reaches its state-escalation threshold, the guard transitions up one state:

- `accumulator >= T_SUSPICIOUS` → transition to SUSPICIOUS (if currently UNAWARE)
- `accumulator >= T_SEARCHING` → transition to SEARCHING (if currently UNAWARE or SUSPICIOUS)
- `accumulator >= T_COMBAT` → transition to COMBAT (if currently any non-combat, non-dead state)

Thresholds are per-state, not per-channel — both sight and sound accumulators check against the same threshold set. A guard in UNAWARE with `_sight = 0.8` AND `_sound = 0.2` escalates via the sight channel because 0.8 > threshold.

**State de-escalation rule.** When BOTH accumulators fall below a *lower* de-escalate threshold AND a cooldown timer expires, the guard transitions down one state:

- SEARCHING → SUSPICIOUS after `SEARCH_TIMEOUT_SEC` if no new stimulus
- SUSPICIOUS → UNAWARE after `SUSPICION_TIMEOUT_SEC` if both accumulators < T_DECAY_UNAWARE
- COMBAT → SEARCHING after `COMBAT_LOST_TARGET_SEC` of no sight AND no direct hit

This preserves reversibility — Pillar 3's load-bearing invariant.

**Accumulator decay.** When no stimulus is present, each accumulator decays exponentially:

`accumulator -= DECAY_RATE * delta`

Where `DECAY_RATE` varies per state (faster decay in UNAWARE, slower in COMBAT — the guard "remembers" recent alarm longer when hostile). Decay never goes below 0.

**Last-known-position (LKP).** When any accumulator crosses `T_SEARCHING` or higher, the perception module stores the world-space position that produced the stimulus:

- For hearing: `origin` field from the latched `NoiseEvent`, OR `player.global_transform.origin` for continuous-locomotion noise.
- For sight: the position of the first LOS-confirmed cell in the vision cone.

LKP is a single `Vector3` per guard, overwritten by newer stimuli. When the guard enters SEARCHING, `NavigationAgent3D.target_position = LKP` drives them toward it.

**Investigate behavior (SEARCHING).** Guard navigates to LKP. On arrival (within `INVESTIGATE_ARRIVAL_EPSILON_M` of LKP), plays a sweep animation (look left, look right, open a nearby closet/crate if authored). Stops for `INVESTIGATE_SWEEP_SEC`. If stimulus returns during sweep → extends the timer. If no new stimulus → decays both accumulators rapidly and transitions back to SUSPICIOUS → UNAWARE through the normal de-escalate path.

**Combat behavior (COMBAT).** Guard draws weapon if not already drawn. Navigates to cover (uses tactical pathfinding — beyond MVP, accepts hand-authored cover nodes). Fires at last-known-sight position (not LKP — sight is the confirm-channel for combat). If sight re-confirms, tracks target. If sight lost for > `COMBAT_LOST_TARGET_SEC`, de-escalates.

**Takedown target-side effect.** When Eve performs a takedown (melee non-lethal OR silenced pistol, per Inventory & Gadgets), the guard's `receive_takedown(takedown_type: TakedownType, attacker: Node) -> void` method is called. `TakedownType` enum is defined on `StealthAI` (owned here because the receiver owns the consequence):

```gdscript
enum TakedownType { MELEE_NONLETHAL, SILENCED_PISTOL }
```

- For both types: guard transitions to `AlertState.DEAD`, body slumps via ragdoll (or pre-baked "down" pose at MVP if ragdoll is scope-creep), `NavigationAgent3D` stops, suspicion accumulators reset to 0, `Events.takedown_performed.emit(self, attacker)` fires.
- `MELEE_NONLETHAL` additionally plays a chloroform SFX + animation.
- `SILENCED_PISTOL` additionally applies damage via the guard's own health (delegated to Combat & Damage GDD's `apply_damage_to_actor` — forward dependency).
- Takedown may only be attempted on UNAWARE or SUSPICIOUS guards (SEARCHING and COMBAT guards resist — the attempt fails and triggers `actor_became_alerted(guard, SAW_PLAYER, eve.position)`).

**Dead-body visibility.** A dead guard is an observable stimulus for OTHER guards. Any live guard whose vision cone encompasses a dead body with LOS confirms **sight suspicion at 2×-fill-rate** (seeing a corpse is faster-escalating than seeing a moving Eve). The alert cause is `SAW_BODY`. This is the "guard trips over his buddy" comedy/tension beat.

**Propagation (alert-spreading).** When any guard transitions from UNAWARE → SUSPICIOUS or higher, `Events.actor_became_alerted(self, cause, source_position)` fires. Other guards within `ALERT_PROPAGATION_RADIUS_M` receive this signal and bump their own sound accumulator by a fixed amount, partially alerting nearby patrol groups. This models "the guard called out and his friend across the hall heard him." The propagation is one-hop only — alerted-by-other does NOT chain further.

**Death and save-state.** A `DEAD` guard is serialised as `{position, rotation, alert_state: DEAD, takedown_type}` per ADR-0003. Patrol route and suspicion state are NOT serialised for dead guards — they don't patrol. Live guards serialise `{position, rotation, alert_state, patrol_index, sight_accumulator, sound_accumulator, last_known_position}`. On section reload, guards restore to these values.

**Perception ownership boundary.** PlayerCharacter publishes **source** (origin, radius, type). Stealth AI owns **propagation** (occlusion via raycast, elevation attenuation — NOLF1 precedent: noise does not penetrate floors; cross-floor audibility is zero — surface absorption modifier per ground material read from the same `surface_tag` metadata that FootstepComponent reads, distance falloff). This boundary is documented per-dependency below.

### States and Transitions

**State lattice** (5 states, 4 reachable via perception):

```
             ┌──────────┐
             │ UNAWARE  │◄──┐
             └────┬─────┘   │ de-escalate (both accumulators decay
                  │         │  below T_DECAY_UNAWARE + timeout)
        escalate  │         │
                  ▼         │
             ┌───────────┐  │
          ┌─►│SUSPICIOUS │──┘
          │  └────┬──────┘
          │       │ escalate
          │       │
          │       ▼
          │  ┌───────────┐
          └──│ SEARCHING │◄─────┐ COMBAT_LOST_TARGET_SEC w/o
  de-esc after  └────┬──────┘   │  sight contact
  SEARCH_TIMEOUT     │ escalate │
  (no new stimulus)  │          │
                     ▼          │
                ┌────────┐      │
                │ COMBAT │──────┘
                └────┬───┘
                     │ takedown / lethal damage
                     ▼
                ┌────────┐
                │  DEAD  │ (terminal)
                └────────┘
```

**Transition rules (exhaustive):**

| From | To | Trigger | Side effects |
|---|---|---|---|
| UNAWARE | SUSPICIOUS | `max(_sight, _sound) >= T_SUSPICIOUS` | Play "huh?" vocal (Dialogue event); stop patrol; face stimulus direction; emit `alert_state_changed` + `actor_became_alerted(self, cause, stimulus_position)` |
| UNAWARE | SEARCHING | `max(_sight, _sound) >= T_SEARCHING` (direct jump on strong stimulus) | Same as above + navigate to LKP; emit `alert_state_changed` (cause includes old_state transition intent) |
| UNAWARE / SUSPICIOUS | COMBAT | `max(_sight, _sound) >= T_COMBAT` (typically only sight clears this — sound alone should not → combat at MVP balance) | Draw weapon; navigate to cover; emit `alert_state_changed`. No separate `actor_became_alerted` signal (the state change carries the info). |
| SUSPICIOUS | SEARCHING | `max(_sight, _sound) >= T_SEARCHING` | Navigate to LKP; play "I'll check it out" vocal; weapon drawn but not raised; emit `alert_state_changed` |
| SUSPICIOUS | UNAWARE | Both accumulators < T_DECAY_UNAWARE for ≥ SUSPICION_TIMEOUT_SEC | Play "must be nothing" vocal; resume patrol from nearest patrol node; emit `alert_state_changed` + `actor_lost_target(self)` |
| SEARCHING | SUSPICIOUS | Arrived at LKP + completed sweep + no new stimulus ≥ SEARCH_TIMEOUT_SEC | Play "hmph, nothing" vocal; weapon holstered; accumulators set to half T_SUSPICIOUS (not zero — guard is still on edge briefly); emit `alert_state_changed` |
| SEARCHING | COMBAT | Sight accumulator reaches T_COMBAT | Standard combat enter; emit `alert_state_changed` |
| COMBAT | SEARCHING | No sight confirmation for ≥ COMBAT_LOST_TARGET_SEC AND no damage taken in that window | Drop sight accumulator to `T_SEARCHING - epsilon`; weapon remains drawn; investigate last sight position; emit `alert_state_changed` + `actor_lost_target(self)` |
| Any live state | DEAD | Takedown received OR health ≤ 0 from Combat & Damage | Body slumps; accumulators cleared; `NavigationAgent3D` stopped; emit `takedown_performed(self, attacker)` (if takedown) OR allow Combat & Damage to emit its own `actor_killed` (forward dep) |

**Notes on transition edges:**
- There is NO direct SUSPICIOUS → UNAWARE transition without the timeout — a brief cue doesn't get forgotten instantly; guards stay twitchy for a few seconds. This is the NOLF1 fidelity the player reads as "the guard is almost certain they heard something."
- SEARCHING → UNAWARE passes through SUSPICIOUS; there is no direct skip. Reinforces the "wait, now what was that, never mind" comedy.
- COMBAT → UNAWARE does NOT exist. A guard in combat cannot forget the fight; they de-escalate only to SEARCHING. If the player escapes and leaves the section, the section transition resets guard state.

**Per-state behaviour spec** (summary — full specifics in Tuning Knobs + Formulas):

| State | Movement | Weapon | Perception rate | Vocal cadence |
|---|---|---|---|---|
| UNAWARE | Patrol route at `PATROL_SPEED` (~1.2 m/s) | Holstered | Normal (baseline fill rates) | Idle banter every 8–15 s (Dialogue owns) |
| SUSPICIOUS | Stop + face stimulus; may take 1–2 steps | Holstered | Heightened (1.5× fill rate — the guard is *looking*) | Investigate-callout vocal on entry |
| SEARCHING | Navigate to LKP at `INVESTIGATE_SPEED` (~1.6 m/s, between patrol and sprint) | Drawn, not raised | Heightened (1.5× fill rate) | Sweep vocal on arrival; "hmph" on de-escalate |
| COMBAT | Navigate to cover at `COMBAT_SPRINT_SPEED` (~3.0 m/s); fire from cover | Drawn + raised | Maximum (2× fill rate — guard is actively looking) | Combat shouts; call-for-backup on entry (propagation signal) |
| DEAD | None | Dropped | None | None |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Player Character** | consumes (pull) | `get_noise_level() -> float` (hot path, 10 Hz per guard); `get_noise_event() -> NoiseEvent` (idempotent-read, 0.15 s auto-expiry window); `get_silhouette_height() -> float` for LOS gating; `global_transform.origin` for continuous-locomotion noise localisation. **MUST NOT subscribe to `player_footstep`** (Forbidden Pattern — PC GDD + FC GDD). **MUST copy NoiseEvent fields** (`{type, radius_m, origin}`) into guard-local state if needed after current physics frame. |
| **Signal Bus** | publishes | `alert_state_changed(actor, old_state, new_state)`, `actor_became_alerted(actor, cause, source_position)`, `actor_lost_target(actor)`, `takedown_performed(actor, target)`. All 4 via `Events` autoload per ADR-0002. Owns enums `StealthAI.AlertState`, `StealthAI.AlertCause`, `StealthAI.TakedownType`. |
| **Audio** | via signals | Audio subscribes to `alert_state_changed` for music state transitions; to `actor_became_alerted` for brass-punch stingers (Audio GDD §combat-state dict). Guard footstep audio is owned by guard-side audio component (parallel to PC's FootstepComponent, authored later — placeholder hook: guards emit their own `ai_footstep` signal out of scope for this GDD). |
| **Combat & Damage** | receives damage | Each guard has a `receive_damage(amount, source, damage_type)` method that mirrors PC's `apply_damage` contract. Dying transitions to DEAD. Combat & Damage GDD (forward dep) owns damage balance; this GDD owns the state-transition consequence. |
| **Inventory & Gadgets** | receives takedown | `receive_takedown(takedown_type: StealthAI.TakedownType, attacker: Node) -> void` on the guard. Inventory & Gadgets (forward dep) owns the player-side verb + animation + prerequisite check (must be behind target); this GDD owns target-side consequence (state → DEAD, body drop, signal). |
| **Civilian AI** | propagation | Civilian AI publishes `civilian_witnessed_event(civilian, event_type, position)`; Stealth AI subscribes and treats nearby events as `AlertCause.ALERTED_BY_OTHER` with high source-position credibility. Civilian panicking near a guard → bumps sound accumulator. |
| **Mission & Level Scripting** | authors + forces | Patrol routes authored as `Path3D` curves referenced by `NavigationAgent3D`. Mission Scripting may call `force_alert_state(new_state, cause)` for scripted beats (e.g., "at mission objective X, all guards in section Y alert to SEARCHING"). This is a documented escape hatch, not general gameplay. |
| **Dialogue & Subtitles** | via signals | Dialogue subscribes to `alert_state_changed` + `actor_became_alerted` + `actor_lost_target` to trigger contextual voice lines on the guard's `DialogueAnchor`. Guard's voice-line pool is an exported `Array[DialogueLine]` per guard type; Dialogue GDD owns playback logic. |
| **Save / Load** | serializes | Per ADR-0003: live guard state `{position, rotation, alert_state, patrol_index, sight_accumulator, sound_accumulator, last_known_position}`; dead guard state `{position, rotation, alert_state: DEAD, takedown_type}`. Section restart restores. |
| **HUD State Signaling** (VS) | subscribes (optional VS) | `alert_state_changed` drives VS-tier subtle HUD hint (a faint music-state indicator, per HUD State Signaling GDD forward dep). MVP HUD shows nothing — Pillar 5. |
| **Level Streaming** | reads | When a section unloads, all its guards despawn (or pause if the section supports re-entry). When a section loads, guards spawn at serialised state. No cross-section guard memory at MVP. |

**Forward dependencies** (systems referenced here that do not yet have GDDs):

| Forward reference | Owner GDD | Gate |
|---|---|---|
| `Combat & Damage`'s `apply_damage_to_actor` | combat-damage.md (Not Started) | Stealth AI guard health + lethal takedown gated on Combat & Damage shipping. MVP stub: guards have 100 HP like Eve; silenced pistol deals 100 HP; melee takedown deals 100 HP; no armor. |
| `Inventory & Gadgets`'s takedown verb | inventory-gadgets.md (Not Started) | Takedown target-side is defined here; player-side verb + animation + prereq check is forward-gated. Placeholder: test stub calls `guard.receive_takedown(MELEE_NONLETHAL, eve)` directly. |
| `Civilian AI`'s `civilian_witnessed_event` | civilian-ai.md (Not Started) | Propagation-from-civilians gate: at MVP, guards react only to guard-to-guard propagation + PC perception until Civilian AI lands. |
| `Mission & Level Scripting`'s patrol-route authoring schema | mission-scripting.md (Not Started) | Patrol routes at MVP stub: a scene-authored `Path3D` referenced by each guard's `NavigationAgent3D`. Full schema defined later. |
| `Dialogue & Subtitles`'s voice-line pool | dialogue-subtitles.md (Not Started, VS) | Vocal callouts at MVP ship with placeholder lines; Dialogue GDD refines. |
| `HUD State Signaling` | hud-state-signaling.md (Not Started, VS) | No MVP dependency (Pillar 5 — no visual alert indicators). |

**Boundary — this GDD does NOT own**: guard models, animations (beyond pose-state callouts), or weapon mechanics (Combat & Damage); dialogue text or VO authoring (Dialogue & Subtitles); patrol route authoring tool (Mission Scripting); civilian behaviour (Civilian AI).

## Formulas

**Variables used throughout:**
- `Δt` — physics frame delta (s, nominal 1/60 at 60 Hz)
- `Δt_clamped = min(Δt, 1.0 / 30.0)` — hitch guard, mirroring PC's pattern
- `d(a, b)` — Euclidean distance between two `Vector3` positions (m)
- `occlusion(a, b)` — returns 1.0 if unobstructed; 0.0 if fully blocked; per-obstacle partial values in (0, 1) via raycast result
- `floor_delta(a, b)` — absolute difference in floor-level between two positions (whole integers; NOLF1 rule: noise does not penetrate floors)

### F.1 Sight fill rate

Runs per vision-cone physics frame while Eve's `CharacterBody3D` is inside the guard's `VisionCone` Area3D AND a LOS raycast from the guard's eye position to Eve's head position succeeds.

```
sight_fill_rate = BASE_SIGHT_RATE × range_factor × silhouette_factor × movement_factor × state_multiplier
_sight_accumulator += sight_fill_rate × Δt_clamped
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `BASE_SIGHT_RATE` | `B_s` | float | 1.0 (tuning knob) | Baseline full-accumulator-fill rate per second at range 0 with standing silhouette on a walking Eve in UNAWARE |
| `range_factor` | `r` | float | [0.0, 1.0] | `1.0 - clamp(d(guard.eye, eve.head) / VISION_MAX_RANGE_M, 0.0, 1.0)` — linear falloff from guard to `VISION_MAX_RANGE_M` (default 18 m) |
| `silhouette_factor` | `h` | float | [0.2, 1.0] | `clamp(eve.get_silhouette_height() / 1.7, 0.5, 1.0)` at standing; crouched ≈ 0.65 proportionally. Below-waist silhouette reduces sight fill rate |
| `movement_factor` | `m` | float | [0.3, 1.5] | State-keyed: IDLE/Walk-still/Crouch-still = 0.3, Walk = 1.0, Crouch = 0.5, Sprint = 1.5, Jump/Fall = 0.8 |
| `state_multiplier` | `s` | float | {1.0, 1.5, 1.5, 2.0} | Guard's own alert state: UNAWARE = 1.0, SUSPICIOUS = 1.5, SEARCHING = 1.5, COMBAT = 2.0 |

**Output range:** 0.0 (Eve at max range with minimum silhouette + still) to ~2.7 (Eve close + Sprint + guard in Combat). At 60 Hz, `_sight_accumulator` can rise from 0 → 1 in (1/2.7) ≈ 0.37 s under worst-case.

**Example** (crouching Eve at 6 m from a SUSPICIOUS guard's eye):
- `range_factor = 1.0 - (6/18) = 0.667`
- `silhouette_factor = clamp(1.1/1.7, 0.5, 1.0) = 0.647`
- `movement_factor = 0.5` (Crouch)
- `state_multiplier = 1.5` (SUSPICIOUS)
- `sight_fill_rate = 1.0 × 0.667 × 0.647 × 0.5 × 1.5 = 0.324` per second
- Accumulator fills 0 → 1 in ~3.1 s — Eve has 3 seconds to break LOS before guard escalates (SEARCHING threshold) or sees positively (COMBAT threshold).

**LOS gate:** fill rate is 0 if the LOS raycast (from guard's eye position to Eve's head position) hits anything on `MASK_AI_VISION_OCCLUDERS`. Eve's silhouette height is used so a crouching Eve behind a desk is occluded even if her head would otherwise be in cone.

**Decay** (when LOS breaks OR Eve leaves vision cone):
```
_sight_accumulator -= SIGHT_DECAY_RATE × Δt_clamped
```
Where `SIGHT_DECAY_RATE` is state-keyed per F.3. Never below 0.

### F.2 Sound fill rate

Runs on the guard's `HearingPoller` at 10 Hz (every 6 physics frames at 60 Hz). Two sub-cases:

#### F.2a Continuous locomotion sound (polled 10 Hz)

```
noise_at_source = player.get_noise_level()  # returns 0 if Eve is still/dead
effective_radius = noise_at_source × occlusion_factor × elevation_factor × surface_factor
audibility = max(0.0, effective_radius - d(guard, eve.global_transform.origin))
sound_fill_rate = audibility / AUDIBILITY_DIVISOR × state_multiplier
_sound_accumulator += sound_fill_rate × 0.1  # 10 Hz tick: Δt_poll = 0.1 s
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `noise_at_source` | `n₀` | float | [0.0, 12.0] m | From PC's `get_noise_level()` (ship-multiplier 1.0 — Walk 5, Sprint 12, Crouch 3, 0 when still/dead) |
| `occlusion_factor` | `o` | float | [0.0, 1.0] | From a raycast between guard and Eve on `MASK_AI_VISION_OCCLUDERS` — 1.0 unobstructed; 0.25 through one wall (3 dB attenuation equivalent); 0.0 through two walls |
| `elevation_factor` | `e` | float | {1.0, 0.0} | `1.0` if `floor_delta(guard, eve) == 0`; **`0.0` otherwise** (NOLF1 precedent: noise does not penetrate floors). Cross-floor audibility is zero |
| `surface_factor` | `f` | float | [0.5, 1.5] | Read from Eve's ground-surface `surface_tag` (same meta FootstepComponent reads): `marble` = 1.2, `tile` = 1.1, `wood_stage` = 1.3, `carpet` = 0.5, `metal_grate` = 1.5, `gravel` = 0.9, `default` = 1.0. Wood_stage amplifies; carpet attenuates |
| `effective_radius` | `r_eff` | float | [0.0, ~24] m | After modifiers. Max: Sprint 12 × 1.5 (metal_grate) × 1.0 (unobstructed) × 1.0 (same floor) = 18 m. Hard-landing cap 16 × 1.5 = 24 m on extreme surfaces |
| `audibility` | `a` | float | [0.0, ~24] m | How far effective_radius exceeds guard-Eve distance. 0 when Eve is out of audible range |
| `AUDIBILITY_DIVISOR` | `D` | float | 10.0 (knob) | Normaliser: at 10 m audibility excess AND state_multiplier=1, fill rate = 1.0 / s (accumulator reaches T_SUSPICIOUS ≈ 0.3 in ~0.3 s) |
| `state_multiplier` | `s` | float | {1.0, 1.5, 1.5, 2.0} | Same as F.1 — guard alerts faster when already on edge |

**Output range:** 0.0 (Eve inaudible) to ~4.8 per second (Eve sprinting through a metal grate 2 m from a combat guard). Typical Walk-within-range gives 0.3–0.6 per second.

**Example** (Eve walking on carpet 4 m from an UNAWARE guard, unobstructed, same floor):
- `n₀ = 5.0` (Walk); `o = 1.0`, `e = 1.0`, `f = 0.5` (carpet)
- `r_eff = 5.0 × 1.0 × 1.0 × 0.5 = 2.5 m`
- `audibility = max(0, 2.5 - 4.0) = 0` — inaudible. Walk on carpet at 4 m is safe.

**Example** (Eve sprinting on marble 8 m from the same guard, unobstructed, same floor):
- `n₀ = 12.0` (Sprint), `f = 1.2` (marble)
- `r_eff = 12.0 × 1.0 × 1.0 × 1.2 = 14.4 m`
- `audibility = max(0, 14.4 - 8.0) = 6.4 m`
- `sound_fill_rate = 6.4 / 10.0 × 1.0 = 0.64 per second`
- Per 10 Hz tick: accumulator gains 0.064. To reach `T_SUSPICIOUS` (default 0.3) takes 5 ticks = 0.5 s.

#### F.2b Discrete spike sound (polled every frame; spikes can expire in 0.15 s window)

```
event = player.get_noise_event()
if event != null and _last_handled_event_id != event_identity(event):
    # Idempotent-read per PC F.4: every guard in the 0.15 s window sees this same event
    effective_radius = event.radius_m × occlusion_factor × elevation_factor × surface_factor
    audibility = max(0.0, effective_radius - d(guard, event.origin))  # NOTE: event.origin, not player position
    sound_fill_rate = audibility / AUDIBILITY_DIVISOR × state_multiplier × EVENT_WEIGHT[event.type]
    _sound_accumulator += sound_fill_rate  # one-shot, not per-delta (spike is instantaneous)
    _last_handled_event_id = event_identity(event)  # local dedupe across polls within same latch window
    _last_known_position = event.origin  # update LKP for investigate
```

**Per ADR-0002 IG4**: `event` payload is a `NoiseEvent` reference; the guard MUST copy `{type, radius_m, origin}` into guard-local state IF it needs any of those values across physics frames (PC GDD's reference-retention footgun). `event_identity(event)` is the tuple `(event.type, event.origin)` — stable within the latch window — used as a local dedupe key so the same spike doesn't fire the one-shot add twice if the guard polls twice during the 9-frame latch.

**EVENT_WEIGHT table:**

| Event type | Weight | Notes |
|---|---|---|
| `JUMP_TAKEOFF` (4 m) | 0.5 | Minor — a footfall-level blip |
| `LANDING_SOFT` (5 m) | 0.7 | Audible landing cue |
| `LANDING_HARD` (8–16 m scaled) | 1.5 | Loud — contains explicit intent signal |
| `FOOTSTEP_*` | — | These are continuous-channel values already counted in F.2a; NOT treated as spike events. Present in the enum for completeness but the latch only fires for the jump/landing subset per PC F.4 |

**Example** (Eve hard-lands from a 3 m drop near a guard at 5 m distance, same floor, marble surface):
- `|v.y|` at landing ≈ `sqrt(2 × 12 × 3) ≈ 7.75 m/s`
- `v_land_hard = 6 m/s`
- Ratio = 7.75 / 6 = 1.29; clamped 1.0–2.0 → 1.29
- PC emits `NoiseEvent{type=LANDING_HARD, radius_m=8 × 1.29 = 10.33, origin=landing}`
- Guard sees: `effective_radius = 10.33 × 1.0 × 1.0 × 1.2 = 12.4 m`; `audibility = 12.4 - 5 = 7.4 m`
- `sound_fill_rate = 7.4 / 10 × 1.0 × 1.5 = 1.11` (one-shot)
- Accumulator jumps by 1.11 — blowing past T_SEARCHING in a single event. Guard transitions UNAWARE → SEARCHING directly. LKP = landing position.

### F.3 Accumulator decay

Runs per physics frame regardless of stimulus presence:

```
if sight_not_refreshed_this_frame:
    _sight_accumulator = max(0.0, _sight_accumulator - SIGHT_DECAY[state] × Δt_clamped)
if sound_not_refreshed_this_poll:
    _sound_accumulator = max(0.0, _sound_accumulator - SOUND_DECAY[state] × Δt_clamped)
```

**Decay rate table** (units: per second, tuning knobs):

| Guard state | SIGHT_DECAY | SOUND_DECAY |
|---|---|---|
| UNAWARE | 0.5 | 0.4 |
| SUSPICIOUS | 0.3 | 0.25 |
| SEARCHING | 0.15 | 0.12 |
| COMBAT | 0.05 | 0.05 |

Rationale: Combat-state guards retain alarm far longer (they've committed). UNAWARE decays fastest (false alarms evaporate).

**Output range:** 0.0 (floor) to current-accumulator-value (starting point). Decay never goes negative.

**Example** (guard loses sight at `_sight = 0.8` in SEARCHING state):
- Decay = 0.15 per second
- Time to reach T_DECAY_UNAWARE (0.1): (0.8 - 0.1) / 0.15 = 4.67 s
- Guard must then wait SEARCH_TIMEOUT_SEC additionally before de-escalating to SUSPICIOUS.

### F.4 Alert-propagation (guard-to-guard)

When any guard fires `Events.actor_became_alerted(self, cause, source_position)`, every live guard within `ALERT_PROPAGATION_RADIUS_M` receives an accumulator bump:

```
if d(self, other_guard) <= ALERT_PROPAGATION_RADIUS_M and self != other_guard:
    other_guard._sound_accumulator += PROPAGATION_BUMP × floor_delta_factor(self, other_guard)
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `ALERT_PROPAGATION_RADIUS_M` | float | 25.0 (knob) | Guard's callout carries ~25 m in a straight line |
| `PROPAGATION_BUMP` | float | 0.4 (knob) | Brings UNAWARE guard to SUSPICIOUS threshold on one hop (T_SUSPICIOUS = 0.3) |
| `floor_delta_factor` | float | {1.0, 0.0} | 1.0 if same floor; 0.0 otherwise (NOLF1 rule) |

**One-hop only.** The receiving guard does NOT re-fire `actor_became_alerted` from being bumped — that would chain-alert an entire section. Only direct stimulus detection (sight, sound, SAW_BODY) fires the propagation signal. Formal invariant: propagation graph is a tree of depth 1, rooted at the originally-stimulated guard.

**Output range:** one-shot bump of 0.4 per callout received. A guard receiving two callouts in quick succession can reach SEARCHING directly.

### F.5 State-transition thresholds

Single source of truth for the 5 thresholds:

| Threshold | Default | Safe range | Purpose |
|---|---|---|---|
| `T_SUSPICIOUS` | 0.3 | 0.2 – 0.4 | Accumulator value above which UNAWARE → SUSPICIOUS |
| `T_SEARCHING` | 0.6 | 0.5 – 0.75 | Above which → SEARCHING |
| `T_COMBAT` | 0.95 | 0.9 – 1.0 | Above which → COMBAT (sight-only in practice; sound alone should not cross this) |
| `T_DECAY_UNAWARE` | 0.1 | 0.05 – 0.2 | BOTH accumulators must fall below this for SUSPICIOUS → UNAWARE de-escalate (with timeout) |
| `T_DECAY_SEARCHING` | 0.35 | 0.25 – 0.45 | Resting-point set on SEARCHING → SUSPICIOUS de-escalate (guard remains edgy briefly) |

Escalation uses `max(_sight, _sound) >= threshold`. De-escalation uses `max(_sight, _sound) < threshold` AND the state's timeout.

**Output range:** each threshold is a scalar in [0.0, 1.0]; accumulators cap at 1.0 (any overflow is clamped on the same frame it would occur).

## Edge Cases

- **E.1 Eve crouching on carpet behind cover with broken LOS**: `_sight_accumulator = 0` (no LOS), `_sound_accumulator` → 0 (carpet attenuation × no visible = inaudible at normal Walk). Guard remains UNAWARE. Correct Pillar 3 reward for patience.
- **E.2 Simultaneous sight + sound on same frame**: sight fills `_sight`, sound fills `_sound` independently. `max(_sight, _sound)` still applies for escalation. If both channels cross threshold on the same frame, one state transition fires (the higher of the two); AlertCause is the one that crossed first (tie-break: sight).
- **E.3 LKP overwrite race**: two stimuli arriving in the same physics frame write to LKP sequentially; second write wins. This is intentional (most recent stimulus is the best investigation target).
- **E.4 Guard in SEARCHING arrives at LKP that is now stale** (Eve has moved 8 m away): guard completes sweep, finds nothing, de-escalates per F.3 normal path. Eve is safe at her new position UNLESS her continuous-locomotion noise refills the sound channel during the sweep. This is the "I hear the guard searching and I'm holding perfectly still" tension beat.
- **E.5 Guard spawned mid-alert**: on section load from save, restored accumulators drive the correct entry state. If restored to COMBAT but Eve isn't in the scene yet, guard enters SEARCHING (no sight target) after 1 physics frame and proceeds from LKP.
- **E.6 Takedown attempted on SEARCHING/COMBAT guard**: the attempt returns false; `receive_takedown` does NOT transition state; instead fires `actor_became_alerted(self, SAW_PLAYER, attacker.global_transform.origin)` and triggers propagation. Emits one "you tried" vocal.
- **E.7 Two guards simultaneously discover the same body**: each guard independently crosses `SAW_BODY` sight threshold, transitions to SEARCHING, fires `actor_became_alerted` with the same `source_position`. Propagation bumps are still applied to both guards by each other — they're already at SEARCHING so the bump is harmless. No double-propagation race since each guard tracks its own alert state.
- **E.8 Patrol path cut by level geometry change** (e.g., mission script opens/closes a door): `NavigationAgent3D` re-paths automatically. If no valid path exists, guard falls back to idle-sway animation at current position for `PATROL_STUCK_RECOVERY_SEC`, then attempts the next patrol node.
- **E.9 Civilian panics mid-sweep**: `civilian_witnessed_event` propagates to nearby guards; each receiving guard treats it as a `+0.5` bump to `_sound_accumulator` (bigger than guard-to-guard because civilians are usually more reliable reporters — they're reacting to what they saw, not what they heard). Cause logged as `ALERTED_BY_OTHER`.
- **E.10 Eve dies mid-pursuit**: guards in COMBAT observing Eve's death decelerate to SEARCHING (lost target). LKP = death position. Guards then sweep the death site as usual. After `SEARCH_TIMEOUT_SEC`, de-escalate per normal. Failure & Respawn owns what happens next for the player.
- **E.11 Section transition during COMBAT**: Level Streaming pauses (or despawns) all guards in the old section. Serialized state: `{alert_state=COMBAT, position, rotation, patrol_index, accumulators, LKP}`. On return, guards resume at COMBAT with accumulators slightly decayed (we subtract `COMBAT_SEC_ON_RELOAD × SOUND_DECAY[COMBAT]` from each accumulator to avoid "guard frozen in time" feel — default 2 s of implicit decay). If accumulators decay below `T_DECAY_UNAWARE`, guard resumes at SUSPICIOUS; else at COMBAT (but LKP stale, falls to F.3 normal decay path).
- **E.12 NavigationMesh missing or outdated**: `NavigationAgent3D.target_position` call returns no path; guard emits `push_warning("no navigation path to LKP %s")` and idles at current position for `INVESTIGATE_SWEEP_SEC`, then de-escalates. Fails gracefully — no freeze, no crash.
- **E.13 Takedown attacker becomes invalid (freed) during the takedown animation**: `attacker` in `receive_takedown(takedown_type, attacker)` is stored as a `Node` reference. If freed (unlikely but possible if player disconnects / mission script despawns Eve), `Events.takedown_performed.emit(self, null)` — subscribers MUST call `is_instance_valid(attacker)` per ADR-0002 IG4. Documented in Signal Bus bidirectional dep statement.
- **E.14 Guard's `VisionCone` Area3D receives `body_entered(body)` for a non-player body** (Civilian, another guard, a physics prop): guard ignores the entry — only `body.is_in_group("player")` triggers sight perception. No false-positive on AI-vs-AI sight.
- **E.15 Spike latch arrives during guard's 10 Hz polling gap**: per PC F.4, the 0.15 s (9-frame) latch window is wider than the 100 ms AI-tick period even with 1-frame jitter. Guard polls within the window; spike is seen. This was the explicit fix for the prior 0.1 s latch (ai-programmer B-2, PC GDD 2026-04-21).
- **E.16 Guard killed (health=0) from COMBAT by silenced pistol**: Combat & Damage GDD's `receive_damage` transitions state to DEAD; `takedown_performed` does NOT fire (this path is a kill, not a takedown). Instead, a forward-dep Combat signal (`actor_killed` or similar) fires — TBD when Combat & Damage GDD lands. At MVP stub, just set state to DEAD and emit `actor_lost_target(self)` so subscribers clean up references.

## Dependencies

### Upstream (must exist first)

| System | GDD | Why |
|---|---|---|
| Player Character | `design/gdd/player-character.md` ✅ | Publishes noise/silhouette/position; this GDD is the primary consumer |
| FootstepComponent | `design/gdd/footstep-component.md` ✅ | Surface-tag `meta` contract shared (F.2a reads same `surface_tag` metadata); but Stealth AI does NOT subscribe to `player_footstep` (Forbidden Pattern) |
| Signal Bus | `design/gdd/signal-bus.md` ✅ | 4 AI/Stealth signals declared in `Events.gd` per ADR-0002 |
| Audio | `design/gdd/audio.md` ✅ | Consumer of `alert_state_changed` + `actor_became_alerted` (music transitions + stingers). Audio's 4-bucket stem scheme is orthogonal to this GDD. |
| ADR-0001 | Stencil ID Contract ✅ | Guards = outline tier MEDIUM |
| ADR-0002 | Signal Bus + Event Taxonomy ✅ | Signal signatures + enum ownership for `AlertState`/`AlertCause` |
| ADR-0003 | Save Format Contract ✅ | Per-guard state serialisation schema |
| ADR-0006 | Collision Layer Contract ✅ | `LAYER_AI`, `MASK_AI_VISION_OCCLUDERS`, `MASK_PLAYER` |

### Downstream (consumers of this GDD's interfaces)

| System | Planned GDD | What they consume |
|---|---|---|
| Audio | `audio.md` ✅ | `alert_state_changed` → music state machine; `actor_became_alerted` → brass-punch stinger; `actor_lost_target` → woodwind decay; `takedown_performed` → muffled thud |
| Dialogue & Subtitles | `dialogue-subtitles.md` ⏳ (VS) | All 4 AI signals → trigger contextual guard voice lines via guard's `DialogueAnchor` |
| HUD State Signaling | `hud-state-signaling.md` ⏳ (VS) | `alert_state_changed` drives subtle music-state indicator (MVP: no visual indicator; VS only) |
| Save / Load | `save-load.md` ✅ | Per-guard state sub-resources (live + dead variants); section restart restores |
| Mission & Level Scripting | `mission-scripting.md` ⏳ | Subscribes to all 4 signals for objective triggers; may call `force_alert_state` on guards for scripted beats |
| Civilian AI | `civilian-ai.md` ⏳ (stub MVP) | At MVP: no direct consumption. Civilian AI publishes `civilian_witnessed_event` that THIS GDD subscribes to — inverted direction from table |

### Bidirectional dependency statements

- **Player Character** must document (already does in F.4 + Interactions): "Stealth AI reads `get_noise_level()`, `get_noise_event()`, `get_silhouette_height()`, `global_transform.origin` per perception tick; Stealth AI owns occlusion + elevation + surface propagation math; MUST NOT subscribe to `player_footstep`; callers MUST copy NoiseEvent fields before next physics frame." ✓ Already present in PC GDD Dependencies.
- **Audio** must document: "Subscribes to `alert_state_changed` / `actor_became_alerted` / `actor_lost_target` / `takedown_performed` for music state transitions + stingers + muffled takedown SFX. Respects `is_instance_valid(actor)` guard on all Node-typed payloads per ADR-0002 IG4." Partial in Audio GDD §AI signals table; confirm on next Audio review.
- **Save / Load** must document: "Serialises per-guard state sub-resources — live: `{position, rotation, alert_state, patrol_index, sight_accumulator, sound_accumulator, last_known_position}`; dead: `{position, rotation, alert_state: DEAD, takedown_type}`. Section restart restores." Currently Save/Load GDD does not mention guards — add on next Save/Load review.
- **Mission & Level Scripting** must document: "Authors per-guard patrol routes via `Path3D` referenced by `NavigationAgent3D`. May call `force_alert_state(new_state, cause)` as a scripted escape hatch — do not use for general gameplay. Subscribes to all 4 AI signals for objective triggers." Future GDD.
- **Civilian AI** must document: "Publishes `civilian_witnessed_event(civilian, event_type, position)` on visual/audio detection of alarming events (gunfire, dead body, Eve in public); Stealth AI subscribes and treats it as a high-credibility `ALERTED_BY_OTHER` cue." Future GDD.

### Dependency risk notes

- **Navigation mesh authoring** is a mission-scripting-owned content pipeline. Stealth AI fails gracefully if a path doesn't exist (E.12), but mission authoring MUST bake navigation meshes for every section that contains guards. Content-review gate before section ships.
- **Surface-tag metadata coverage** — F.2a's `surface_factor` reads `surface_tag` meta from the same mesh bodies FootstepComponent reads. If a mesh is missing the meta, both systems fall back to `default` (1.0 factor). Risk is shared with FootstepComponent; enforcement is a single content-review pass, not two.
- **Combat & Damage forward dep** — Stealth AI guard health + silenced-pistol lethal takedown are gated on Combat & Damage shipping. MVP stub: guards are 100 HP + die in one silenced-pistol hit. When Combat & Damage GDD lands, verify its `apply_damage_to_actor` signature matches the forward-stubbed call site here.
- **Propagation topology** — F.4 is one-hop only. If future gameplay requires multi-hop alert chains (e.g., "the whole floor goes on alert"), that's an ADR-worthy change to the propagation invariant, not a tuning tweak.
- **Behavior-tree addon adoption** — current design assumes hand-rolled state machine (user's Phase 2 decision 2026-04-21). If a future revision adopts LimboAI or similar, the state-transition table here remains authoritative; the addon just implements it. No ADR needed unless the addon adoption requires changing ship dependencies.

## Tuning Knobs

Designer-facing (13). Correctness parameters in sidebar.

### Perception ranges (2)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `VISION_MAX_RANGE_M` | 18.0 m | 12.0 – 24.0 | Guard FOV cone length. Below 12 m Eve can stroll past at range; above 24 m guards become 270° omniscient. |
| `VISION_FOV_DEG` | 90° | 60 – 120 | Guard FOV cone angle. 90° is realistic human foveal+peripheral. |

### Fill rates (3)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `BASE_SIGHT_RATE` | 1.0 /s | 0.6 – 1.8 | F.1 baseline sight accumulator fill rate |
| `AUDIBILITY_DIVISOR` | 10.0 m | 6.0 – 15.0 | F.2a/b sound-audibility → fill-rate normaliser. Lower = more sensitive guards. |
| `PROPAGATION_BUMP` | 0.4 | 0.2 – 0.6 | F.4 guard-to-guard alert bump on callout |

### Thresholds (5 — defaults from F.5)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `T_SUSPICIOUS` | 0.3 | 0.2 – 0.4 | UNAWARE → SUSPICIOUS escalation threshold |
| `T_SEARCHING` | 0.6 | 0.5 – 0.75 | → SEARCHING escalation threshold |
| `T_COMBAT` | 0.95 | 0.9 – 1.0 | → COMBAT escalation threshold |
| `T_DECAY_UNAWARE` | 0.1 | 0.05 – 0.2 | Both channels must drop below this for SUSPICIOUS → UNAWARE |
| `T_DECAY_SEARCHING` | 0.35 | 0.25 – 0.45 | Resting value on SEARCHING → SUSPICIOUS de-escalate |

### Timers (3)

| Knob | Default | Safe range | Affects |
|---|---|---|---|
| `SUSPICION_TIMEOUT_SEC` | 4.0 s | 2.5 – 6.0 | Minimum dwell time in SUSPICIOUS before de-escalate is allowed |
| `SEARCH_TIMEOUT_SEC` | 12.0 s | 8.0 – 20.0 | Minimum dwell time in SEARCHING before de-escalate |
| `COMBAT_LOST_TARGET_SEC` | 8.0 s | 5.0 – 15.0 | No-sight + no-damage interval before COMBAT → SEARCHING |

### Correctness parameters (not designer-tunable)

| Parameter | Default | Why |
|---|---|---|
| `ALERT_PROPAGATION_RADIUS_M` | 25.0 m | Callout distance; tuning changes require pillar review |
| `INVESTIGATE_ARRIVAL_EPSILON_M` | 0.5 m | NavAgent arrival tolerance |
| `INVESTIGATE_SWEEP_SEC` | 3.0 s | Fixed animation duration |
| `PATROL_STUCK_RECOVERY_SEC` | 5.0 s | Navigation-fail recovery |
| `SIGHT_DECAY` / `SOUND_DECAY` | Per F.3 state-keyed table | Per-state decay schedule — tuning-balance coupled |
| `EVENT_WEIGHT` | Per F.2b table | Spike-event impact schedule |
| `PATROL_SPEED` / `INVESTIGATE_SPEED` / `COMBAT_SPRINT_SPEED` | 1.2 / 1.6 / 3.0 m/s | Guard locomotion speeds (NavigationAgent3D) |
| `VISION_CONE_DOWNWARD_ANGLE_DEG` | 15° | Cone tilts slightly down so a guard at 1.8 m eye height sees a crouching Eve at 5 m |
| `COMBAT_SEC_ON_RELOAD` | 2.0 s | Virtual decay applied on section reload per E.11 |

### Tuning authority

- **Game Designer** owns: perception ranges, thresholds, timers, propagation bump (the encounter feel).
- **Gameplay Programmer** owns: all Correctness Parameters (the engine-correctness surface).
- **AI Programmer** owns: EVENT_WEIGHT and per-state decay tables (the graduated-suspicion calibration).

## Visual/Audio Requirements

### Visual

- **Guard model**: 3D humanoid, ~3k tris, rigged with full biped skeleton + left/right hand attach points for weapons. Period-appropriate PHANTOM uniform (black/red palette per Art Bible §4.4); Eiffel-Tower-specific guards may wear variant uniforms (caterer, custodian) per level design.
- **Outline tier**: MEDIUM per ADR-0001 (guards are mid-priority, less heavy than Eve's hands).
- **Animation state layer**: must support smooth blending between {patrol_walk, patrol_idle, investigate_walk, investigate_sweep, combat_run_to_cover, combat_fire, dead_slump, chloroformed_slump}. Per-state transitions documented above; animation blend graph is Art / Animation-team-owned.
- **Weapon draw animation**: visible on SUSPICIOUS → SEARCHING transition (weapon moves from holster to ready-at-hip); on SEARCHING → COMBAT transition (weapon raises to aim).
- **Eye / head turn**: in SUSPICIOUS, head turns toward stimulus position (IK from `Node3D` look-at target matching `LKP`). Visual legibility cue for the player.
- **Dead-body visibility**: dead guards remain on-scene as readable sight stimuli for other guards (F.1 dead-body 2× fill). Art Director should ensure body pose reads clearly from 15 m away (guard silhouette is load-bearing for this mechanic).

### Audio

- **Alert-state audio transitions**: Audio subscribes to `alert_state_changed` and plays music-state stingers + bed changes per Audio GDD §music-state machine.
- **`actor_became_alerted` stinger**: brass-punch 2-note accent (Audio GDD already specifies). Played 3D at guard position.
- **`actor_lost_target` tail**: soft woodwind decay (~800 ms). 3D at guard position.
- **Guard footstep audio**: OUT OF SCOPE for this GDD. Guards will use a guard-side footstep component (parallel to PC's FootstepComponent) to be authored later. Placeholder: each guard's `NavigationAgent3D` movement emits a footstep signal; exact implementation deferred.
- **Guard vocal pool**: owned by Dialogue & Subtitles GDD (forward dep). This GDD specifies *when* a vocal should fire (per-state + on transition); Dialogue GDD owns *what* is said and *by whom*.
- **Combat shouts**: loud vocal callouts on UNAWARE/SUSPICIOUS → COMBAT transition ("She's here!", "Open fire!") — triggers alert propagation.

> **Asset Spec**: Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:stealth-ai` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

**MVP**: No HUD UI for stealth state. Per Pillar 5 (Period Authenticity — no modern UX conveniences like objective markers, alert icons, or "!" meters), the player reads alert state through:

1. **Guard body language** (animation-driven)
2. **Guard vocal callouts** (Dialogue & Subtitles, forward)
3. **Music state** (Audio)
4. **Environmental cues** (civilians panicking, doors opening)

**VS tier**: A faint music-state HUD indicator may land in `HUD State Signaling` GDD (forward dep). This GDD does NOT specify it — the VS-tier decision is whether Pillar 5 allows *any* visual indicator.

## Acceptance Criteria

Each AC is binary, labeled, measurement-explicit, with a test-evidence path. GWT format per skill spec.

### AC-SAI-1 State machine correctness

- **AC-SAI-1.1 [Logic]** GIVEN a guard in UNAWARE with both accumulators at 0.0, WHEN `_sight_accumulator` rises to 0.35 (above T_SUSPICIOUS=0.3) in a single physics frame via simulated fill, THEN `alert_state_changed(guard, UNAWARE, SUSPICIOUS)` emits exactly once AND `actor_became_alerted(guard, SAW_PLAYER, stimulus_position)` emits exactly once, in that order. Evidence: `tests/unit/stealth/stealth_ai_unaware_to_suspicious_test.gd`.
- **AC-SAI-1.2 [Logic]** GIVEN a guard in SUSPICIOUS, WHEN both accumulators remain below T_DECAY_UNAWARE (0.1) for SUSPICION_TIMEOUT_SEC (4.0 s), THEN the guard transitions to UNAWARE AND emits `alert_state_changed(guard, SUSPICIOUS, UNAWARE)` + `actor_lost_target(guard)`. Evidence: `tests/unit/stealth/stealth_ai_suspicious_to_unaware_test.gd`.
- **AC-SAI-1.3 [Logic]** Reversibility matrix: parametrized test covering all 12 state-pair transitions (including the forbidden ones — assert COMBAT → UNAWARE is NOT reachable directly; guards in COMBAT always pass through SEARCHING before de-escalating further). Evidence: `tests/unit/stealth/stealth_ai_reversibility_matrix_test.gd`.
- **AC-SAI-1.4 [Logic]** GIVEN a guard receives `receive_takedown(MELEE_NONLETHAL, attacker)` while in UNAWARE, WHEN the call returns, THEN state is DEAD, `NavigationAgent3D.is_navigation_finished()` is true, both accumulators are 0.0, `takedown_performed(guard, attacker)` emits exactly once. Evidence: `tests/unit/stealth/stealth_ai_takedown_unaware_test.gd`.
- **AC-SAI-1.5 [Logic]** GIVEN a guard receives `receive_takedown(MELEE_NONLETHAL, attacker)` while in SEARCHING, WHEN the call returns, THEN state is NOT DEAD (takedown resisted), AND `actor_became_alerted(guard, SAW_PLAYER, attacker.position)` emits exactly once. Evidence: `tests/unit/stealth/stealth_ai_takedown_resisted_test.gd`.

### AC-SAI-2 Perception formulas

- **AC-SAI-2.1 [Logic]** F.1 sight fill rate: parametrized test at 9 combinations of (range ∈ {2, 6, 12}, movement ∈ {Walk, Crouch, Sprint}) asserts computed `sight_fill_rate` matches the formula within 0.01 tolerance. Evidence: `tests/unit/stealth/stealth_ai_sight_fill_rate_test.gd`.
- **AC-SAI-2.2 [Logic]** F.2a sound fill rate: deterministic test with stub PC returning fixed `noise_level = 5.0`, guard at 6 m on same floor with `occlusion=1.0, elevation=1.0, surface_factor=1.0` → asserts `sound_fill_rate == (5.0 × 1.0 × 1.0 × 1.0 - 6.0) / 10.0 × 1.0` — but since `r_eff < distance`, audibility = 0 and fill_rate = 0. Extended with all 4 surface_factor values + 3 elevation/occlusion combinations. Evidence: `tests/unit/stealth/stealth_ai_sound_fill_rate_test.gd`.
- **AC-SAI-2.3 [Logic]** F.2b spike handling (idempotent-read): a stub PC latches a `LANDING_HARD` NoiseEvent (radius 10 m, origin at known position). The guard's `HearingPoller` polls twice within the 0.15 s latch window; assert `_sound_accumulator` is incremented exactly once (dedupe via `_last_handled_event_id`). Evidence: `tests/unit/stealth/stealth_ai_spike_dedupe_test.gd`.
- **AC-SAI-2.4 [Logic]** F.3 decay: parametrized test for each state ({UNAWARE, SUSPICIOUS, SEARCHING, COMBAT}) starting at `_sight = 1.0` with no stimulus; after 1 second simulated with fixed-delta 60 ticks, assert `_sight_accumulator` equals `1.0 - SIGHT_DECAY[state] × 1.0` within 0.01 tolerance. Evidence: `tests/unit/stealth/stealth_ai_decay_test.gd`.
- **AC-SAI-2.5 [Logic]** F.4 propagation (one-hop only): three guards G1/G2/G3 in a line, all UNAWARE. G1 fires `actor_became_alerted`. Assert G2 `_sound_accumulator` gains PROPAGATION_BUMP; assert G3 does NOT re-fire `actor_became_alerted` from being bumped (lint assert that `actor_became_alerted` signal count == 1, not 2+). Evidence: `tests/unit/stealth/stealth_ai_propagation_one_hop_test.gd`.
- **AC-SAI-2.6 [Logic]** F.2a cross-floor audibility: guard on floor 2 (y≈6m), Eve on floor 1 (y≈0m) directly below with `_noise_level = 12` (Sprint), no occluders. `elevation_factor = 0.0` → `effective_radius = 0` → `audibility = 0` → no fill. Assert `_sound_accumulator` unchanged after 10 seconds simulated. Evidence: `tests/unit/stealth/stealth_ai_cross_floor_silence_test.gd`.

### AC-SAI-3 Signals taxonomy

- **AC-SAI-3.1 [Logic]** All 4 stealth signals fire through `Events` autoload (not node-to-node). Verified by signal spy over 300 scripted physics ticks exercising all state transitions. Evidence: `tests/unit/stealth/stealth_ai_signal_taxonomy_test.gd`.
- **AC-SAI-3.2 [Logic]** Signal frequency guard: no stealth signal fires at > 30 Hz over any 1-second window during a 10-second scripted sequence (600 ticks at delta=1/60). Evidence: same file.
- **AC-SAI-3.3 [Logic]** `actor_became_alerted` payload is typed `(Node, StealthAI.AlertCause, Vector3)` — matches ADR-0002 declaration; assert via signal-arg-type inspection. Evidence: `tests/unit/stealth/stealth_ai_signal_payload_types_test.gd`.

### AC-SAI-4 Integration + Visual/Feel

- **AC-SAI-4.1 [Integration]** Full perception loop end-to-end: spawn PC + one guard in a test scene. Eve walks in front of the guard at 5 m, unobstructed. Over 3 simulated seconds (180 ticks at delta=1/60), assert guard's state progresses UNAWARE → SUSPICIOUS → SEARCHING → COMBAT. Evidence: `tests/integration/stealth/stealth_ai_full_perception_loop_test.gd`.
- **AC-SAI-4.2 [Integration]** Pillar 3 reversibility: same setup; Eve walks into LOS then immediately hides behind a concrete barrier (mask occluder). Assert guard escalates to SUSPICIOUS, then 10 seconds of hidden+silent play → returns to UNAWARE. No state history retained after timeout. Evidence: `tests/integration/stealth/stealth_ai_pillar3_reversibility_test.gd`.
- **AC-SAI-4.3 [Visual/Feel]** Playtest sign-off: in a test level with 3 guards on a Plaza-like layout, a competent player (the designer) completes 5 sneak-past encounters, 3 takedown encounters, and 2 intentional-detection-then-hide encounters. Game-designer sign-off that "guards feel theatrical, not buggy" per Pillar 3 design test. Evidence: `production/qa/evidence/stealth-ai-pillar3-feel-[date].md` with game-designer sign-off paragraph.

### AC-SAI-5 Save/load

- **AC-SAI-5.1 [Integration]** Live-guard serialisation: guard in SEARCHING with `_sight=0.4, _sound=0.2, LKP=<known>`. Save → reload → assert all fields restored within 0.001 tolerance, state still SEARCHING, patrol_index unchanged. Evidence: `tests/integration/stealth/stealth_ai_save_restore_live_test.gd`.
- **AC-SAI-5.2 [Integration]** Dead-guard serialisation: guard takedowned as `MELEE_NONLETHAL`. Save → reload → assert state is DEAD, takedown_type preserved, body position preserved within 0.001 m. Evidence: `tests/integration/stealth/stealth_ai_save_restore_dead_test.gd`.

## Open Questions

- **OQ-SAI-1**: Guard-to-civilian propagation bidirectional? (Does a panicking civilian cascade-alert multiple guards?) Deferred to Civilian AI GDD + playtest.
- **OQ-SAI-2**: Cover-to-cover pathfinding in COMBAT — hand-authored `CoverNode` markers vs Jolt-assisted tactical eval? Deferred to Gameplay programmer + playtest.
- **OQ-SAI-3**: Guard memory persistence across section transitions (currently: no cross-section memory). Thief-style memory graphs considered and deferred to post-MVP.
- **OQ-SAI-4**: Silenced-pistol *hearing* by other guards — does a silenced shot produce a NoiseEvent that alerts nearby guards? Currently not in F.2b EVENT_WEIGHT table. Forward-gated on Combat & Damage GDD authoring; likely resolution: add `GUNSHOT_SILENCED` with weight ~0.3 (audible at close range only).
- **OQ-SAI-5**: Behaviour-tree adoption post-MVP? Hand-rolled state machine was the MVP choice (2026-04-21). If gameplay complexity grows (multiple civilian types, boss AI, etc.), a BT library may warrant an ADR.
- **OQ-SAI-6**: Ragdoll physics on takedown vs pre-baked slump poses? Scope-creep risk; current spec defaults to pre-baked pose with ragdoll as polish-phase upgrade.
