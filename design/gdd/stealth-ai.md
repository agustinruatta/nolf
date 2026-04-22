# Stealth AI

> **Status**: Revised (2nd pass) — pending re-review in fresh session
> **Author**: User + `/design-system` skill + specialists
> **Last Updated**: 2026-04-21 (2nd `/design-review` revision pass — 21 new blockers + 23 advisories resolved inline after 7-specialist adversarial re-review + creative-director synthesis. Prior verdict was MAJOR REVISION NEEDED; this revision addresses: SAW_BODY mask (LAYER_AI added), `combined` escalation unification, CURIOSITY_BAIT dwell moved to vocal scheduling, Godot 4.6 API corrections (forward axis, Area3D typing, downward-tilt spec), severity-rule DEAD-path fix, F.1 dead-body + DEAD movement_factor, AC-SAI severity-matrix + force_alert_state coverage, performance budget split into sub-budgets with P99. **Pre-implementation gates remain OPEN**: ADR-0002 signal signatures must be amended; Audio GDD must be re-reviewed for stinger severity filter + `takedown_type` SFX routing.)
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
- `VisionCone: Area3D` — Godot 4.6 has no `ConeShape3D`, so FOV is approximated by a **`SphereShape3D`** of radius `VISION_MAX_RANGE_M` with angle filtering performed in the `body_entered(body: Node3D)` callback via dot-product. **Forward axis:** Godot 3D uses `-basis.z` as the forward vector; the guard's world-forward is `-guard.global_transform.basis.z` (NOT `guard.basis * Vector3.FORWARD`, which is +X and points to the guard's right). **Downward tilt:** the reference forward vector is rotated about the guard's local X axis by `-VISION_CONE_DOWNWARD_ANGLE_DEG` degrees before the dot-product check: `eye_forward = (-guard.global_transform.basis.z).rotated(guard.global_transform.basis.x, -deg_to_rad(VISION_CONE_DOWNWARD_ANGLE_DEG))`. Accept iff `eye_forward.dot((body.global_position - guard.eye_position).normalized()) >= cos(deg_to_rad(VISION_FOV_DEG / 2.0))`. **Zero-distance edge**: if `(body.global_position - guard.eye_position).length() < 0.1` (Eve inside the eye point), the dot-product would be computed against a zero vector — short-circuit and ACCEPT unconditionally (Eve touching the guard's face is tautologically seen). Area3D fields: `layer = 0`, `mask = PhysicsLayers.MASK_PLAYER | PhysicsLayers.MASK_AI` (player-body perception + dead-guard-body perception for SAW_BODY; live guards and civilians on LAYER_AI are filtered out by the group check below). **Occluders MUST NOT be in the Area3D mask** — that would cause `body_entered` to fire on every piece of world geometry. Occluder detection happens exclusively via the F.1 LOS raycast against `MASK_AI_VISION_OCCLUDERS`. Perception flow: `body_entered(body: Node3D)` → reject unless `body.is_in_group("player")` OR `body.is_in_group("dead_guard")` (live guards on LAYER_AI that are in `alive_guard` group are rejected here → NO false-positive AI-vs-AI sight; civilians if/when added must NOT be in either group) → belt-and-braces: also reject unless `body is PlayerCharacter` or `body is GuardBase` (typed class check guards against group-tag misuse during scene authoring) → dot-product angle filter (with zero-distance short-circuit above) → if accepted, begin feeding the sight accumulator per F.1 (which additionally gates each physics frame on its own LOS raycast).
- `HearingPoller: Node` — non-physics child that runs `_physics_process` at 10 Hz via internal tick counter, calling `player.get_noise_level()` + `player.get_noise_event()` and accumulating sound-suspicion. **Poll-phase stagger**: the tick counter initial value is `get_instance_id() % 6` (so 12 co-spawned guards are spread across the 6-frame period instead of all firing on the same physics frame). Stagger prevents a 12-guard burst every 100 ms; it does not change aggregate 10 Hz per-guard rate.
- `Perception: Node` — suspicion accumulators (one per channel) + decay timers + last-known-position storage.
- `Weapon: MeshInstance3D` — holstered at Unaware/Suspicious; drawn at Searching; raised at Combat. Actual weapon mechanics (fire rate, damage) owned by Combat & Damage GDD.
- `DialogueAnchor: Node3D` — position for Dialogue & Subtitles to attach voice-line playback.
- `OutlineTier: ...` — guards are tier MEDIUM per ADR-0001. **Implementation constraint**: the outline is applied via `material_overlay` on the guard's `MeshInstance3D` child (not `material_override`, which would replace the base material and break albedo). Guard scene authoring must not set `material_override` on the mesh.

Guards sit on `PhysicsLayers.LAYER_AI` per ADR-0006. `CharacterBody3D._ready()` sets `layer = MASK_AI`, `mask = MASK_WORLD | MASK_PLAYER` (guards cannot walk through Eve; collide with world geometry).

**Alert state ownership.** Each guard holds a single `current_alert_state: StealthAI.AlertState`. The enum lives on `StealthAI` per ADR-0002 Implementation Guideline 2 — NOT on `Events.gd`:

```gdscript
# res://src/gameplay/stealth/stealth_ai.gd
class_name StealthAI
extends Node

enum AlertState { UNAWARE, SUSPICIOUS, SEARCHING, COMBAT, DEAD }
enum AlertCause { HEARD_NOISE, SAW_PLAYER, SAW_BODY, HEARD_GUNFIRE, ALERTED_BY_OTHER, SCRIPTED, CURIOSITY_BAIT }
enum Severity { MINOR, MAJOR }
```

`DEAD` is NOT a reachable alert state through suspicion; it is set only on takedown or lethal-damage resolution. The 4 graduated-suspicion states (`UNAWARE`, `SUSPICIOUS`, `SEARCHING`, `COMBAT`) are all reachable through perception.

**Severity rule** (applied to every emission of `alert_state_changed`, `actor_became_alerted`, `actor_lost_target`):

```gdscript
func _compute_severity(new_state: AlertState, cause: AlertCause) -> Severity:
    if cause == AlertCause.ALERTED_BY_OTHER:
        return Severity.MINOR  # Propagation bump never produces MAJOR
    if new_state == AlertState.SEARCHING or new_state == AlertState.COMBAT or new_state == AlertState.DEAD:
        return Severity.MAJOR
    return Severity.MINOR
```

Rationale for DEAD → MAJOR: a guard's death is a state-transition consumers must treat as high-salience (Mission Scripting triggers, Audio clean-up, Dialogue barks). The `actor_lost_target` emission on the lethal-damage DEAD path is uniformly MAJOR because the event surfaces a decisive gameplay outcome (guard removed from play). Takedown emissions fire `takedown_performed` (separate signal, no severity field — always treated as MAJOR-equivalent by Audio's takedown SFX routing per `takedown_type`).

Consumer contract: **Audio plays the brass-punch stinger ONLY on `severity == MAJOR`.** MINOR transitions cause subtle music-bed shifts but no dramatic stingers. This preserves Pillar 1 comedy (a guard's casual "Ça va?" investigation remains a quiet scene, not a siren) and Pillar 3 reversibility (propagation waves do not cascade dramatic audio).

**`CURIOSITY_BAIT` AlertCause** — reserved for player-initiated comedy triggers (e.g., knocking over a vase, whistling). Creates a SUSPICIOUS-only investigation using the ordinary state-machine semantics: accumulator fills per F.2b (bait-emitter supplies a NoiseEvent), decays per F.3, de-escalates per the SUSPICIOUS → UNAWARE timeout. **No state-machine dwell floor.** The comedy-beat timing guarantee (mutter vocal plays to completion regardless of state) is OWNED BY DIALOGUE & SUBTITLES via vocal scheduling: Dialogue schedules the mutter vocal non-preemptively — once started it plays through to end, even if the guard has already de-escalated to UNAWARE by then (the player hears the guard finish the mutter mid-walk-off, which *is* the comedy). Emitters (Inventory & Gadgets forward-gated verbs) set `cause = CURIOSITY_BAIT` explicitly; propagation from `CURIOSITY_BAIT` does NOT fire (it is a self-contained comedy beat, not an alarm; see F.4 suppression list). **Design rationale for moving the dwell out of the state machine**: a dwell floor in the state machine creates exploitability (player freezes guards via vase-throw) and traps (player cannot de-escalate during their own bait's dwell window). Vocal-scheduling guarantees deliver the comedy without interfering with perceptual state. Reference: game-designer B-1 adversarial finding, 2026-04-21 re-review.

**Dual-channel perception model.** Each guard runs two independent suspicion accumulators, each with its own threshold for triggering state escalation:

- **Sight suspicion** (`_sight_accumulator: float`, 0.0–1.0) — filled when Eve is inside the vision cone AND the LOS raycast succeeds AND her silhouette clears the relevant height band. Fill rate depends on range + silhouette height + Eve's movement state. Decays when LOS breaks.
- **Sound suspicion** (`_sound_accumulator: float`, 0.0–1.0) — filled when `player.get_noise_level()` exceeds a distance-occlusion-adjusted audibility threshold OR when `player.get_noise_event()` returns a non-null spike whose effective radius reaches the guard after propagation. Fill rate depends on how far noise exceeds threshold + event type. Decays over time when no audible source.

**Channel independence rationale**: NOLF1-style legibility. A player hears a guard react to *what they did* — "I heard something" vs "I saw something" produces different AlertCause values, different vocal callout pools, and (Dialogue GDD forward dep) different banter. Keeping the accumulators independent preserves decay semantics and diagnosis, while escalation still responds to combined cues via the score below.

**Channel combination score.** Escalation is gated on a **weighted combined score**:

```
combined = max(_sight, _sound) + 0.5 × min(_sight, _sound)
```

Rationale: a guard who partially hears AND partially sees Eve (e.g., `_sight = 0.25`, `_sound = 0.25`) should notice something (combined = 0.375, crosses `T_SUSPICIOUS = 0.3`), rather than ignore both because neither channel alone crossed threshold. The dominant channel carries full weight; the secondary channel contributes half. This preserves the NOLF1 sight-dominance feel (sight is usually the escalating channel) while closing the combinatorial blindspot. Both accumulators remain independently decayed per F.3; `combined` is a derived value, not a stored accumulator.

**State escalation rule.** When `combined` reaches a threshold, the guard transitions up one state:

- `combined >= T_SUSPICIOUS` → transition to SUSPICIOUS (if currently UNAWARE)
- `combined >= T_SEARCHING` → transition to SEARCHING (if currently UNAWARE or SUSPICIOUS)
- `combined >= T_COMBAT` → transition to COMBAT (if currently any non-combat, non-dead state)

The AlertCause of the escalation is tie-broken by whichever accumulator contributed the larger term: if `_sight >= _sound` the cause derives from the last sight stimulus (`SAW_PLAYER` or `SAW_BODY`); otherwise from the last sound stimulus (`HEARD_NOISE`, `HEARD_GUNFIRE`, `ALERTED_BY_OTHER`). If the guard was bumped via `PROPAGATION_BUMP` this physics frame, cause is always `ALERTED_BY_OTHER`.

**State de-escalation rule.** When `combined` falls below a *lower* de-escalate threshold AND a cooldown timer expires, the guard transitions down one state:

- SEARCHING → SUSPICIOUS after `SEARCH_TIMEOUT_SEC` if `combined < T_DECAY_SEARCHING` and no new stimulus
- SUSPICIOUS → UNAWARE after `SUSPICION_TIMEOUT_SEC` if `combined < T_DECAY_UNAWARE`
- COMBAT → SEARCHING after `COMBAT_LOST_TARGET_SEC` of no sight AND no direct hit

**No state-machine dwell floor** (including for `CURIOSITY_BAIT`): the state machine is purely perceptual and uses only the `SUSPICION_TIMEOUT_SEC` floor. Comedy-vocal timing is owned by Dialogue & Subtitles via non-preemptive vocal scheduling (see CURIOSITY_BAIT note above). This preserves reversibility — Pillar 3's load-bearing invariant — and prevents the vase-throw exploit / self-trap pattern identified by game-designer B-1 (2026-04-21 adversarial re-review).

**Accumulator decay.** When no stimulus is present, each accumulator decays exponentially:

`accumulator -= DECAY_RATE * delta`

Where `DECAY_RATE` varies per state (faster decay in UNAWARE, slower in COMBAT — the guard "remembers" recent alarm longer when hostile). Decay never goes below 0.

**Last-known-position (LKP).** When any accumulator crosses `T_SEARCHING` or higher, the perception module stores the world-space position that produced the stimulus:

- For hearing: `origin` field from the latched `NoiseEvent`, OR `player.global_transform.origin` for continuous-locomotion noise.
- For sight: the position of the first LOS-confirmed cell in the vision cone.

LKP is a single `Vector3` per guard, overwritten by newer stimuli. When the guard enters SEARCHING, `NavigationAgent3D.target_position = LKP` drives them toward it.

**Investigate behavior (SEARCHING).** Guard navigates to LKP. On arrival (within `INVESTIGATE_ARRIVAL_EPSILON_M` of LKP), plays a sweep animation (look left, look right, open a nearby closet/crate if authored). Stops for `INVESTIGATE_SWEEP_SEC`. If stimulus returns during sweep → extends the timer. If no new stimulus → decays both accumulators rapidly and transitions back to SUSPICIOUS → UNAWARE through the normal de-escalate path.

**Combat behavior (COMBAT).** Guard draws weapon if not already drawn. Navigates to cover (uses tactical pathfinding — beyond MVP, accepts hand-authored cover nodes). Fires at last-known-sight position (not LKP — sight is the confirm-channel for combat). If sight re-confirms, tracks target. If sight lost for > `COMBAT_LOST_TARGET_SEC`, de-escalates.

**COMBAT → UNAWARE recovery pacing spec** (Pillar 3 theatre contract). The full recovery arc is COMBAT → SEARCHING → SUSPICIOUS → UNAWARE, with a theoretical minimum of `COMBAT_LOST_TARGET_SEC (8s) + SEARCH_TIMEOUT_SEC (12s, if SEARCHING proceeds from accumulator reset) + SUSPICION_TIMEOUT_SEC (4s) ≈ 20 s+` total. This long arc risks reading as punishment rather than theatre (game-designer B-2 concern). The design response is that the arc must be **kinesthetically legible as tension-releasing**, not just a timer crawl:
- **t+0 to t+8s (COMBAT, no-sight-no-damage)**: guard continues cover-fire at last-sight position, then gradually stops firing, weapon still raised. Audio: combat music persists (dominant-guard rule). Vocal: agitated shout cadence every 2–3 s ("Where did she go?!"). This is the "guard is hunting" beat.
- **t+8s (COMBAT → SEARCHING transition, MAJOR)**: weapon lowers from aim to ready-at-hip; `actor_lost_target(MAJOR)` fires → Audio plays woodwind decay tail (defeated-hunter cue); vocal: frustrated mutter ("Lost her..."). Music begins transition toward `*_searching` bed. This is the "tension releasing" beat.
- **t+8 to t+20s (SEARCHING sweep)**: guard navigates back toward patrol-adjacent area or LKP; vocal cadence shifts to uncertain mutters every 2.5–4 s. Music at `*_searching` bed (lower intensity than `*_combat`). Guard is on-edge but no longer hunting.
- **t+20s+ (SEARCHING → SUSPICIOUS, MINOR)**: weapon holsters; vocal "Hmph, nothing." Music transitions toward `*_suspicious`.
- **t+24s+ (SUSPICIOUS → UNAWARE, MINOR)**: vocal "Must be nothing." Music returns to `*_calm`. Guard resumes patrol route.

Ownership: vocal cadence authoring belongs to **Dialogue & Subtitles** (forward-dep); music transitions belong to **Audio GDD** (already covers via `alert_state_changed` severity-gated transitions); Stealth AI's role is firing the state transitions on schedule. If playtest reveals the arc reads as punishment, the fix is vocal/music pacing, not shortening the timers (which would break reversibility determinism).

**Takedown target-side effect.** When Eve performs a takedown (melee non-lethal OR stealth blade, per Inventory & Gadgets), the guard's `receive_takedown(takedown_type: TakedownType, attacker: Node) -> void` method is called. `TakedownType` enum is defined on `StealthAI` (owned here because the receiver owns the consequence):

```gdscript
enum TakedownType { MELEE_NONLETHAL, STEALTH_BLADE }
```

- For both types: guard transitions to `AlertState.DEAD`; body slumps via ragdoll (or pre-baked "down" pose at MVP if ragdoll is scope-creep); `NavigationAgent3D.target_position = global_position` (stops agent; `is_navigation_finished()` becomes true on the NEXT physics frame after nav server sync — callers within the same frame must check `target_position ==` current position for synchronous verification, not `is_navigation_finished()` directly); both suspicion accumulators reset to 0; `VisionCone.monitoring = false` — **important Godot 4.6 behavior**: setting `monitoring = false` immediately fires `body_exited` for every body currently inside the Area3D, so the guard's `body_exited` handler MUST early-return when `current_alert_state == AlertState.DEAD` to prevent spurious perception-update logic on a dead guard; `HearingPoller.set_physics_process(false)` (note: this stops `_physics_process` on just the `HearingPoller` child node, not the whole guard — Godot per-node physics processing is isolated in 4.6); guard is added to group `dead_guard` and removed from group `alive_guard`; `Events.takedown_performed.emit(self, attacker, takedown_type)` fires.
- `MELEE_NONLETHAL` additionally plays a chloroform SFX + animation (routed by Audio from the `takedown_type` payload).
- `STEALTH_BLADE` additionally applies damage via the guard's own health (delegated to Combat & Damage GDD's `apply_damage_to_actor` with `DamageType.MELEE_BLADE` and `blade_takedown_damage = 100` — Combat & Damage GDD CR-15).
- Takedown may only be attempted on UNAWARE or SUSPICIOUS guards (SEARCHING and COMBAT guards resist — the attempt fails and triggers `actor_became_alerted(guard, SAW_PLAYER, eve.position, MAJOR)`).

**Dead-body visibility.** A dead guard is an observable stimulus for OTHER guards. Dead guards are in group `dead_guard` (live guards are in group `alive_guard`). The VisionCone's `body_entered` filter accepts both groups (see Core Rules). Any live guard whose vision cone encompasses a dead body with LOS confirms **sight suspicion at 2×-fill-rate** (seeing a corpse is faster-escalating than seeing a moving Eve). The alert cause is `SAW_BODY`. This is the "guard trips over his buddy" comedy/tension beat. Because dead guards themselves have `VisionCone.monitoring = false`, they do not create false-positive SAW_BODY chains by "seeing each other"; only live guards perceive.

**Propagation (alert-spreading).** When any guard transitions from UNAWARE → SUSPICIOUS or higher **and the cause is NOT `ALERTED_BY_OTHER` or `CURIOSITY_BAIT`**, `Events.actor_became_alerted(self, cause, source_position, severity)` fires (severity per the rule above). Other live guards within `ALERT_PROPAGATION_RADIUS_M` receive this signal and bump their own sound accumulator by a fixed amount (see F.4), partially alerting nearby patrol groups. This models "the guard called out and his friend across the hall heard him." The propagation is **one-hop only** — a guard whose transition is caused by `ALERTED_BY_OTHER` does NOT re-emit `actor_became_alerted` (the transition row in the table above suppresses emission when `cause == ALERTED_BY_OTHER`). Formal invariant: the propagation graph is a tree of depth 1, rooted at the originally-stimulated guard.

**Death and save-state.** A `DEAD` guard is serialised as `{position, rotation, alert_state: DEAD, takedown_type}` per ADR-0003. Patrol route and suspicion state are NOT serialised for dead guards — they don't patrol. Live guards serialise `{position, rotation, alert_state, patrol_index, sight_accumulator, sound_accumulator, last_known_position, search_timeout_remaining, combat_lost_target_remaining, _lkp_has_sight_confirm}`. Fields NOT serialised (regenerated on load): `_last_handled_event_id` (idempotent-read dedupe key is per-physics-frame latch; section-reload always fresh), any cached raycast results, HearingPoller tick counter (re-initialised with the `get_instance_id() % 6` stagger). On section reload, guards restore serialised values then apply the E.11 implicit-decay rule (`_sight -= COMBAT_SEC_ON_RELOAD × SIGHT_DECAY[alert_state]`, same for `_sound`).

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

All `alert_state_changed` and `actor_became_alerted` emissions include the `severity` field computed per the Severity rule above. Where a row below says "emit `actor_became_alerted`", the severity is derived automatically — callers do not pick it. `actor_became_alerted` is suppressed entirely when `cause == ALERTED_BY_OTHER` (propagation-induced transitions do NOT re-fire the alert signal — one-hop invariant, F.4); `alert_state_changed` always fires so Audio's dominant-guard aggregation stays correct.

| From | To | Trigger | Side effects |
|---|---|---|---|
| UNAWARE | SUSPICIOUS | `combined >= T_SUSPICIOUS` | Play "huh?" vocal (Dialogue event); stop patrol; face stimulus direction; emit `alert_state_changed(self, UNAWARE, SUSPICIOUS, MINOR)` + (iff `cause != ALERTED_BY_OTHER`) `actor_became_alerted(self, cause, stimulus_position, MINOR)` |
| UNAWARE | SEARCHING | `combined >= T_SEARCHING` (direct jump on strong stimulus) | Same emissions as above but severity = MAJOR (unless `cause == ALERTED_BY_OTHER`, which downgrades to MINOR); navigate to LKP |
| UNAWARE / SUSPICIOUS | COMBAT | `combined >= T_COMBAT` (sight-dominant in typical play; F.2b spike cap prevents a single acoustic event from reaching COMBAT, but sustained F.2a continuous sound at close range can saturate `_sound` and cross `T_COMBAT` via the combined score — this is the intended "Eve sprints on metal grate next to a COMBAT-prone guard" edge case) | Draw weapon; navigate to cover; emit `alert_state_changed(self, prev, COMBAT, MAJOR)`. Emit `actor_became_alerted(self, cause, stimulus_position, MAJOR)` iff `cause != ALERTED_BY_OTHER`. |
| SUSPICIOUS | SEARCHING | `combined >= T_SEARCHING` | Navigate to LKP; play "I'll check it out" vocal; weapon drawn but not raised; emit `alert_state_changed(self, SUSPICIOUS, SEARCHING, MAJOR)` + (iff `cause != ALERTED_BY_OTHER`) `actor_became_alerted(..., MAJOR)` |
| SUSPICIOUS | UNAWARE | `combined < T_DECAY_UNAWARE` for ≥ `SUSPICION_TIMEOUT_SEC` | Play "must be nothing" vocal; resume patrol from nearest patrol node; emit `alert_state_changed(self, SUSPICIOUS, UNAWARE, MINOR)` + `actor_lost_target(self, MINOR)`. **Note**: if a CURIOSITY_BAIT mutter vocal is still playing when this transition fires, Dialogue & Subtitles lets it play through to end (non-preemptive) — the guard may already be walking back to patrol while still muttering, which is the intended comedy. |
| SEARCHING | SUSPICIOUS | Arrived at LKP + completed sweep + no new stimulus ≥ `SEARCH_TIMEOUT_SEC` | Play "hmph, nothing" vocal; weapon holstered; both `_sight` and `_sound` set to `T_DECAY_SEARCHING` (not zero — guard is still on edge briefly); emit `alert_state_changed(self, SEARCHING, SUSPICIOUS, MINOR)` |
| SEARCHING | COMBAT | `combined >= T_COMBAT` (tie-break per §State escalation rule: if `_sight >= _sound` cause is `SAW_PLAYER` / `SAW_BODY`, else the relevant sound cause) | Standard combat enter; emit `alert_state_changed(self, SEARCHING, COMBAT, MAJOR)` + `actor_became_alerted(self, cause, stimulus_position, MAJOR)` iff `cause != ALERTED_BY_OTHER` |
| COMBAT | SEARCHING | No sight confirmation for ≥ `COMBAT_LOST_TARGET_SEC` AND no damage taken in that window | Drop `_sight` to `T_SEARCHING - 0.01`; weapon remains drawn; investigate last sight position; emit `alert_state_changed(self, COMBAT, SEARCHING, MAJOR)` + `actor_lost_target(self, MAJOR)` |
| Any live state | DEAD | Takedown received OR `receive_damage()` reduces health ≤ 0 | Body slumps; both accumulators cleared to 0; `NavigationAgent3D.target_position = global_position` (stops agent; guarantees `is_navigation_finished() == true`); `VisionCone.monitoring = false`; `HearingPoller.set_physics_process(false)`; guard moves to `dead_guard` group (see Dead-body visibility); emit `takedown_performed(self, attacker, takedown_type)` (if takedown) OR emit `actor_lost_target(self, MAJOR)` for subscriber cleanup (lethal-damage path — Combat & Damage owns its own `actor_killed` signal when that GDD lands) |

**Notes on transition edges:**
- There is NO direct SUSPICIOUS → UNAWARE transition without the timeout — a brief cue doesn't get forgotten instantly; guards stay twitchy for a few seconds. This is the NOLF1 fidelity the player reads as "the guard is almost certain they heard something."
- SEARCHING → UNAWARE passes through SUSPICIOUS; there is no direct skip. Reinforces the "wait, now what was that, never mind" comedy.
- COMBAT → UNAWARE does NOT exist. A guard in combat cannot forget the fight; they de-escalate only to SEARCHING. If the player escapes and leaves the section, the section transition resets guard state.

**Per-state behaviour spec** (summary — full specifics in Tuning Knobs + Formulas):

| State | Movement | Weapon | Perception rate | Vocal cadence |
|---|---|---|---|---|
| UNAWARE | Patrol route at `PATROL_SPEED` (~1.2 m/s) | Holstered | Normal (baseline fill rates) | Idle banter every 8–15 s (Dialogue owns) |
| SUSPICIOUS | Stop + face stimulus; may take 1–2 steps | Holstered | Heightened (1.5× fill rate — the guard is *looking*) | Investigate-callout vocal on entry; **mutter vocal every 1.5–2.5 s during dwell** (Pillar 1 comedy — sustained nervous muttering, not one-shot silence) |
| SEARCHING | Navigate to LKP at `INVESTIGATE_SPEED` (~1.6 m/s, between patrol and sprint) | Drawn, not raised | Heightened (1.5× fill rate) | Sweep vocal on arrival; ongoing mutter vocal every 2.5–4 s while searching; "hmph" on de-escalate |
| COMBAT | Navigate to cover at `COMBAT_SPRINT_SPEED` (~3.0 m/s); fire from cover | Drawn + raised | Maximum (2× fill rate — guard is actively looking) | Combat shouts; call-for-backup on entry (propagation signal) |
| DEAD | None | Dropped | None | None |

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Player Character** | consumes (pull) | `get_noise_level() -> float` (hot path, 10 Hz per guard); `get_noise_event() -> NoiseEvent` (idempotent-read, 0.15 s auto-expiry window); `get_silhouette_height() -> float` for LOS gating; `global_transform.origin` for continuous-locomotion noise localisation. **MUST NOT subscribe to `player_footstep`** (Forbidden Pattern — PC GDD + FC GDD). **MUST copy NoiseEvent fields** (`{type, radius_m, origin}`) into guard-local state if needed after current physics frame. |
| **Signal Bus** | publishes | `alert_state_changed(actor: Node, old_state: StealthAI.AlertState, new_state: StealthAI.AlertState, severity: StealthAI.Severity)`, `actor_became_alerted(actor: Node, cause: StealthAI.AlertCause, source_position: Vector3, severity: StealthAI.Severity)`, `actor_lost_target(actor: Node, severity: StealthAI.Severity)`, `takedown_performed(actor: Node, attacker: Node, takedown_type: StealthAI.TakedownType)`. All 4 via `Events` autoload per ADR-0002. Owns enums `StealthAI.AlertState`, `StealthAI.AlertCause`, `StealthAI.TakedownType`, `StealthAI.Severity`. **🚨 PRE-IMPLEMENTATION BLOCKER**: ADR-0002 signal signatures in its `Events.gd` code block currently omit `severity` on the 3 perception signals and use the old `takedown_performed(actor, target)` 2-param form. **No Stealth AI story may be played until ADR-0002 is amended** to match the 4-signal signatures above and the Signal Bus GDD's enum ownership list includes `StealthAI.Severity` and `StealthAI.TakedownType`. AC-SAI-3.3 statically greps `Events.gd` for the new signatures — the test is currently guaranteed to fail until ADR-0002 lands. Owner: `technical-director` via `/architecture-decision adr-0002-amendment` in a SEPARATE session. |
| **Audio** | via signals | Audio subscribes to `alert_state_changed` for music state transitions (aggregates per-guard states into one global music state via the **dominant-guard rule** — Audio GDD §States is authoritative; Stealth AI does NOT own aggregation). Audio plays the brass-punch stinger **only on `actor_became_alerted` where `severity == MAJOR`** (MINOR propagation bumps and MINOR casual SUSPICIOUS investigations get no stinger — Pillar 1). Audio routes `takedown_performed` SFX by `takedown_type` (MELEE_NONLETHAL → chloroform SFX; STEALTH_BLADE → blade stroke + muffled body-drop — Audio GDD SFX catalog must include BOTH variants, currently only one takedown SFX is catalogued). **Burst-rate contract**: Stealth AI may emit up to N simultaneous `actor_became_alerted` signals where N ≤ guards-actually-sensing (note: propagation does NOT re-emit `actor_became_alerted`, so the real burst source is N independent first-hand detections of Eve, not propagation waves); Audio is responsible for per-beat-window stinger deduplication (Audio GDD owns the debounce policy). **Same-state idempotence contract**: Audio dominant-guard dict must treat `alert_state_changed(_, s, s, MINOR)` no-op at music-state level (a propagation wave bumps N guards to SUSPICIOUS, each fires the signal, only ONE `*_suspicious` tween should start — subsequent same-state transitions are no-ops). **🚨 PRE-IMPLEMENTATION BLOCKER**: Audio GDD line 104 trigger table currently says stinger plays on "any" `actor_became_alerted` (must be `severity == MAJOR`); line 123 handler still reflects old 3-param signature; SFX catalog has only one takedown entry (must branch on `takedown_type`); no stinger debounce policy is declared. **No Stealth AI story may be played until Audio GDD is re-reviewed via `/design-review design/gdd/audio.md`** in a separate session with these gaps closed. Guard footstep audio is owned by a guard-side audio component (parallel to PC's FootstepComponent, authored later — placeholder hook: guards emit their own `ai_footstep` signal, out of scope for this GDD). |
| **Combat & Damage** | receives damage | Each guard has a `receive_damage(amount, source, damage_type)` method that mirrors PC's `apply_damage` contract. Dying transitions to DEAD. Combat & Damage GDD (forward dep) owns damage balance; this GDD owns the state-transition consequence. |
| **Inventory & Gadgets** | receives takedown | `receive_takedown(takedown_type: StealthAI.TakedownType, attacker: Node) -> void` on the guard. Inventory & Gadgets (forward dep) owns the player-side verb + animation + prerequisite check (must be behind target); this GDD owns target-side consequence (state → DEAD, body drop, signal). |
| **Civilian AI** | propagation | Civilian AI publishes `civilian_witnessed_event(civilian, event_type, position)`; Stealth AI subscribes and treats nearby events as `AlertCause.ALERTED_BY_OTHER` with high source-position credibility. Civilian panicking near a guard → bumps sound accumulator. |
| **Mission & Level Scripting** | authors + forces | Patrol routes authored as `Path3D` curves referenced by `NavigationAgent3D` (a sibling **PatrolController** sub-component samples the curve and writes `NavigationAgent3D.target_position` to successive waypoints on `is_navigation_finished()`; `NavigationAgent3D` itself has no `Path3D` input). Mission Scripting may call `force_alert_state(new_state: AlertState, cause: AlertCause) -> void` for scripted beats (e.g., "at objective X, all guards in section Y alert to SEARCHING"). **Restrictions**: (1) may only force escalation (new_state > current); cannot force DEAD or force de-escalation. For cutscene-driven stand-down beats (boss monologue, staged comedy de-escalation), Mission Scripting must use scene-level despawn/respawn of guards or section-reload — there is no per-guard soft-de-escalate primitive. (2) Always emits `alert_state_changed(self, old, new, MAJOR if new ∈ {SEARCHING, COMBAT} else MINOR)` and `actor_became_alerted(self, SCRIPTED, guard.global_transform.origin, severity)` — Audio treats `cause == SCRIPTED` identically to organic (scripted combat deserves the stinger; Audio GDD must document this to prevent cutscene composers from getting surprise-stingers on scripted escalation beats). (3) Does NOT fire propagation bumps — formally enforced by F.4 exclusion of `cause == SCRIPTED` (scripted beats target specific guards; chain-alerting is Mission Scripting's responsibility to express explicitly). |
| **Dialogue & Subtitles** | via signals | Dialogue subscribes to `alert_state_changed` + `actor_became_alerted` + `actor_lost_target` to trigger contextual voice lines on the guard's `DialogueAnchor`. Guard's voice-line pool is an exported `Array[DialogueLine]` per guard type; Dialogue GDD owns playback logic. |
| **Save / Load** | serializes | Per ADR-0003: live guard state `{position, rotation, alert_state, patrol_index, sight_accumulator, sound_accumulator, last_known_position, search_timeout_remaining, combat_lost_target_remaining, _lkp_has_sight_confirm}`; dead guard state `{position, rotation, alert_state: DEAD, takedown_type}`. Section restart restores then applies E.11 implicit-decay. Regenerated on load (not serialised): `_last_handled_event_id`, cached raycasts, HearingPoller tick counter. |
| **HUD State Signaling** (VS) | subscribes (optional VS) | `alert_state_changed` drives VS-tier subtle HUD hint (a faint music-state indicator, per HUD State Signaling GDD forward dep). MVP HUD shows nothing — Pillar 5. |
| **Level Streaming** | reads | When a section unloads, all its guards despawn (or pause if the section supports re-entry). When a section loads, guards spawn at serialised state. No cross-section guard memory at MVP. |

**Forward dependencies** (systems referenced here that do not yet have GDDs):

| Forward reference | Owner GDD | Gate |
|---|---|---|
| `Combat & Damage`'s `apply_damage_to_actor` | combat-damage.md (Designed 2026-04-21) | Stealth AI guard health + lethal takedown resolved by Combat & Damage GDD CR-15. Contract: guards have 100 HP; blade takedown via `apply_damage_to_actor(guard, blade_takedown_damage=100, eve, DamageType.MELEE_BLADE)` → 1-shot lethal; silenced-pistol gunfight via 3 body shots × 34 HP → 3-shot kill. MVP stub no longer required — Combat & Damage is authoritative. |
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
sight_fill_rate = BASE_SIGHT_RATE × range_factor × silhouette_factor × movement_factor × state_multiplier × body_factor
_sight_accumulator += sight_fill_rate × Δt_clamped
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `BASE_SIGHT_RATE` | `B_s` | float | 1.0 (tuning knob) | Baseline full-accumulator-fill rate per second at range 0 with standing silhouette on a walking Eve in UNAWARE |
| `range_factor` | `r` | float | [0.0, 1.0] | `1.0 - clamp(d(guard.eye, eve.head) / VISION_MAX_RANGE_M, 0.0, 1.0)` — linear falloff from guard to `VISION_MAX_RANGE_M` (default 18 m) |
| `silhouette_factor` | `h` | float | [0.5, 1.0] | `clamp(eve.get_silhouette_height() / 1.7, 0.5, 1.0)` — floor 0.5 matches the minimum of Eve's standing (1.7 m) and crouching (1.1 m) silhouettes. Below-waist silhouette (i.e. fully obscured by cover) is handled by LOS failing, not by this factor. Post-MVP note: if a prone posture is added, silhouette_factor saturates at 0.5 (identical to crouch) — any additional prone-stealth benefit must come from LOS geometry, not this formula |
| `movement_factor` | `m` | float | [0.0, 1.5] | State-keyed: **DEAD = 0.0** (dead Eve produces no posthumous sight fill — see E.10), IDLE/Walk-still/Crouch-still = 0.3, Walk = 1.0, Crouch = 0.5, Sprint = 1.5, Jump/Fall = 0.8 |
| `state_multiplier` | `s` | float | {1.0, 1.5, 1.5, 2.0} | Guard's own alert state: UNAWARE = 1.0, SUSPICIOUS = 1.5, SEARCHING = 1.5, COMBAT = 2.0 |
| `body_factor` | `b` | float | {1.0, 2.0} | 1.0 when target is alive Eve (in `player` group); **2.0 when target is a dead guard (in `dead_guard` group)** — "seeing a corpse is faster-escalating than seeing a moving Eve." Dead-body sight always uses `AlertCause.SAW_BODY` |

**Output range:** 0.0 (Eve DEAD / at max range with minimum silhouette + still) to ~5.4 (dead body at close range with Combat-state guard). At 60 Hz, `_sight_accumulator` can rise from 0 → 1 in (1/2.7) ≈ 0.37 s under worst-case alive-Eve input; half that time under worst-case dead-body input.

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

**Implementation note — raycast caching.** F.1 (sight LOS) and F.2a (occlusion factor) both raycast the pair `guard → Eve` on mask `MASK_AI_VISION_OCCLUDERS`. On any physics frame where both are invoked, the implementation MUST cache the F.1 result and reuse it for F.2a (and vice-versa) — the query is identical. Reduces 2 raycasts per guard per active frame to 1. With 12 guards × 60 Hz this halves raycast budget from 1440/sec worst-case to 720/sec. Cache lifetime is single physics frame; stale-check via frame counter.

### F.2 Sound fill rate

Runs on the guard's `HearingPoller` at 10 Hz (every 6 physics frames at 60 Hz). Two sub-cases:

#### F.2a Continuous locomotion sound (polled 10 Hz)

```
noise_at_source = player.get_noise_level()  # returns 0 if Eve is still/dead
effective_radius = noise_at_source × occlusion_factor × elevation_factor × surface_factor
audibility = max(0.0, effective_radius - d(guard, eve.global_transform.origin))
sound_fill_rate = audibility / AUDIBILITY_DIVISOR × state_multiplier
_sound_accumulator = clamp(_sound_accumulator + sound_fill_rate × 0.1, 0.0, 1.0)  # 10 Hz tick: Δt_poll = 0.1 s; hard cap 1.0
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `noise_at_source` | `n₀` | float | [0.0, 12.0] m | From PC's `get_noise_level()` (ship-multiplier 1.0 — Walk 5, Sprint 12, Crouch 3, 0 when still/dead) |
| `occlusion_factor` | `o` | float | [0.0, 1.0] | From a raycast between guard and Eve on `MASK_AI_VISION_OCCLUDERS` — 1.0 unobstructed; 0.25 through one wall (3 dB attenuation equivalent); 0.0 through two walls |
| `elevation_factor` | `e` | float | {1.0, 0.0} | `1.0` if `floor_delta(guard, eve) == 0`; **`0.0` otherwise** (NOLF1 precedent: noise does not penetrate floors). Cross-floor audibility is zero |
| `surface_factor` | `f` | float | [0.5, 1.5] | Read from Eve's ground-surface `surface_tag` (same meta FootstepComponent reads): `marble` = 1.2, `tile` = 1.1, `wood_stage` = 1.3, `carpet` = 0.5, `metal_grate` = 1.5, `gravel` = 0.9, `default` = 1.0. Wood_stage amplifies; carpet attenuates |
| `effective_radius` | `r_eff` | float | [0.0, ~18] m | F.2a continuous channel only. Max: Sprint 12 × 1.5 (metal_grate) × 1.0 (unobstructed) × 1.0 (same floor) = 18 m. (Spike channel F.2b has its own higher max up to ~24 m — see F.2b variable table.) |
| `audibility` | `a` | float | [0.0, ~18] m | How far `effective_radius` exceeds guard-Eve distance. 0 when Eve is out of audible range |
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
    # Spike cap: a single spike event may raise the accumulator to AT MOST (T_SEARCHING - 0.01).
    # This preserves graduated-suspicion (Pillar 3): no single acoustic SPIKE event — not even the loudest
    # hard landing on metal grate — can put a guard directly into COMBAT. Combat from a single spike
    # requires a second confirmation (continuous sight, another spike, or sustained sound).
    # NOTE: the F.2a continuous channel is NOT capped; sustained audible locomotion (e.g., Eve
    # sprinting on metal_grate adjacent to a guard) can saturate `_sound_accumulator` to 1.0 and
    # therefore cross T_COMBAT via the combined-score rule. This is the intended "close-adjacent
    # sustained exposure" edge — rare in practice, reachable by design.
    spike_ceiling = T_SEARCHING - 0.01  # = 0.59 at default tuning
    _sound_accumulator = min(max(_sound_accumulator, _sound_accumulator + sound_fill_rate), spike_ceiling) if _sound_accumulator < spike_ceiling else _sound_accumulator
    # Semantic: if accumulator already ≥ spike_ceiling (e.g. sustained sound has already pushed it
    # past 0.59), spikes cannot reduce it (take max). If below ceiling, spike may push up to ceiling
    # but not above. The continuous channel F.2a + the sight channel F.1 remain free to push higher.
    _sound_accumulator = clamp(_sound_accumulator, 0.0, 1.0)  # defence-in-depth hard cap
    _last_handled_event_id = event_identity(event)  # local dedupe across polls within same latch window
    _last_known_position = event.origin  # update LKP for investigate (sight LKPs have priority — see E.3)
```

**Per ADR-0002 IG4**: `event` is a reference to a `NoiseEvent` RefCounted/Resource owned by the Player Character. `Vector3` and scalar fields read from it are value-copied by GDScript assignment (so `var origin = event.origin` is safe on its own), BUT the guard MUST NOT retain the `NoiseEvent` reference across physics frames — the PC may reuse the object and mutate its fields. Always copy the scalar fields you need (`type`, `radius_m`, `origin`) into guard-local variables in the same frame you read them; never store `event` itself. `event_identity(event)` is the tuple `(event.type, event.origin)` — stable within the latch window — used as a local dedupe key so the same spike doesn't fire the one-shot add twice if the guard polls twice during the 9-frame latch.

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
- `sound_fill_rate = 7.4 / 10 × 1.0 × 1.5 = 1.11` (one-shot, uncapped)
- **After spike cap applied** (ceiling = `T_SEARCHING - 0.01 = 0.59`): accumulator rises from 0.0 to 0.59, NOT to 1.11. Guard transitions UNAWARE → SEARCHING (crosses `T_SEARCHING = 0.6`? No — 0.59 < 0.6, so guard transitions to SUSPICIOUS, not SEARCHING, in this isolated example. With the combined-score weighting, if `_sight > 0` this pushes over T_SEARCHING — a sight+sound confirmation reaches SEARCHING organically). **UNAWARE → COMBAT from a SINGLE hard landing is impossible by the spike cap** — Pillar 3 preserved for single acoustic events. (Sustained continuous noise via F.2a remains uncapped — see spike-cap commentary above.) LKP = landing position.

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

When any guard fires `Events.actor_became_alerted(self, cause, source_position, severity)`, every live guard within `ALERT_PROPAGATION_RADIUS_M` receives an accumulator bump (propagation does NOT fire when `cause == ALERTED_BY_OTHER`, `cause == CURIOSITY_BAIT`, or `cause == SCRIPTED` — see one-hop rule and §Interactions Mission Scripting row restriction 3. Scripted beats target specific guards by design; chain-alerting during a scripted moment is the level designer's responsibility to express explicitly):

```
if d(self, other_guard) <= ALERT_PROPAGATION_RADIUS_M and self != other_guard and other_guard.alert_state != DEAD:
    bump = PROPAGATION_BUMP × floor_delta_factor(self, other_guard)
    other_guard._sound_accumulator = clamp(other_guard._sound_accumulator + bump, 0.0, 1.0)
    # The resulting transition (if any) uses cause = ALERTED_BY_OTHER; per the Severity rule
    # such a transition is always MINOR, and the transition table suppresses the re-emission
    # of actor_became_alerted. alert_state_changed DOES still fire so Audio's dominant-guard
    # aggregation stays correct.
```

**Variables:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `ALERT_PROPAGATION_RADIUS_M` | float | 25.0 (knob) | Guard's callout carries ~25 m in a straight line |
| `PROPAGATION_BUMP` | float | 0.4 (knob) | Brings UNAWARE guard to SUSPICIOUS threshold on one hop (T_SUSPICIOUS = 0.3); combined with existing `_sight` a bumped guard may reach SEARCHING — this is intended "the friend's shout tips the second guard over an edge that was already building" |
| `floor_delta_factor` | float | {1.0, 0.0} | 1.0 if same floor; 0.0 otherwise (NOLF1 rule) |

**One-hop only (formal invariant).** A guard whose current transition `cause == ALERTED_BY_OTHER` does NOT re-emit `actor_became_alerted` (the transition table suppresses this). Only first-hand stimulus (sight, sound, SAW_BODY, HEARD_GUNFIRE) fires propagation. `CURIOSITY_BAIT` and `SCRIPTED` causes also do NOT propagate (excluded from F.4 above). Propagation graph is a tree of depth 1, rooted at the originally-stimulated guard. `alert_state_changed` still fires on the bumped guard's transition (so Audio's music-state dict remains consistent) — but with severity MINOR, so no brass-punch stinger plays.

**Same-state transition idempotence (consumer contract).** When propagation bumps multiple guards in the same physics frame, each emits its own `alert_state_changed(_, UNAWARE, SUSPICIOUS, MINOR)`. Audio's music state machine MUST treat a transition whose target equals the current music state as a no-op (no tween restart). Stealth AI cannot guard this — it publishes per-guard state changes honestly. Audio GDD §Edge Cases owns the dominant-guard dict idempotence rule (re-review gate flagged below).

**Tuning-coupling invariant — PROPAGATION_BUMP must exceed T_SUSPICIOUS.** One-hop propagation can only escalate a fresh UNAWARE guard to SUSPICIOUS if `PROPAGATION_BUMP > T_SUSPICIOUS`. Current defaults 0.4 > 0.3 ✓. If either knob is tuned (safe ranges overlap), verify this inequality holds at `_ready()` via assertion; otherwise one-hop propagation silently fails to trigger.

**Output range:** one-shot bump of 0.4 per callout received (clamped so accumulator never exceeds 1.0). A guard receiving two callouts in quick succession can reach SEARCHING directly via the combined-score path.

### F.5 State-transition thresholds

Single source of truth for the 5 thresholds:

| Threshold | Default | Safe range | Purpose |
|---|---|---|---|
| `T_SUSPICIOUS` | 0.3 | 0.2 – 0.4 | Accumulator value above which UNAWARE → SUSPICIOUS |
| `T_SEARCHING` | 0.6 | 0.5 – 0.75 | Above which → SEARCHING |
| `T_COMBAT` | 0.95 | 0.9 – 1.0 | Above which → COMBAT (sight-only in practice; sound alone should not cross this) |
| `T_DECAY_UNAWARE` | 0.1 | 0.05 – 0.2 | `combined` must fall below this for SUSPICIOUS → UNAWARE de-escalate (with timeout) |
| `T_DECAY_SEARCHING` | 0.35 | 0.25 – 0.45 | Resting-point set on SEARCHING → SUSPICIOUS de-escalate (guard remains edgy briefly) |

Escalation uses `combined >= threshold` where `combined = max(_sight, _sound) + 0.5 × min(_sight, _sound)`. De-escalation uses `combined < threshold` AND the state's timeout.

**Output range:** each threshold is a scalar in [0.0, 1.0]; each accumulator is clamped to `[0.0, 1.0]` at every add-step (F.2a/F.2b/F.4) and floored at 0.0 by decay (F.3). `combined` has range `[0.0, 1.5]` (when both accumulators saturate at 1.0: `combined = 1.0 + 0.5 × 1.0 = 1.5`) — this intentional over-1.0 ceiling gives the combined channel headroom above T_COMBAT so cross-channel confirmations feel decisive.

## Edge Cases

- **E.1 Eve crouching on carpet behind cover with broken LOS**: `_sight_accumulator = 0` (no LOS), `_sound_accumulator` → 0 (carpet attenuation × no visible = inaudible at normal Walk). Guard remains UNAWARE. Correct Pillar 3 reward for patience.
- **E.2 Simultaneous sight + sound on same frame**: sight fills `_sight`, sound fills `_sound` independently. Escalation uses the `combined` score. If `combined` crosses a threshold, one state transition fires; AlertCause is tie-broken by which accumulator contributed the larger term (sight if `_sight >= _sound`, otherwise sound).
- **E.3 LKP overwrite race**: Two stimuli in the same physics frame update LKP. **Sight LKPs always take priority over sound LKPs** (sight localisation is more reliable than sound). A flag `_lkp_has_sight_confirm: bool` is set true on sight-sourced writes; sound writes are ignored while it remains true for the current SEARCHING dwell. The flag clears on state transition out of SEARCHING or on successful sweep completion. Two sight writes or two sound writes in the same frame: second write wins.
- **E.4 Guard in SEARCHING arrives at LKP that is now stale** (Eve has moved 8 m away): guard completes sweep, finds nothing, de-escalates per F.3 normal path. Eve is safe at her new position UNLESS her continuous-locomotion noise refills the sound channel during the sweep. This is the "I hear the guard searching and I'm holding perfectly still" tension beat.
- **E.5 Guard spawned mid-alert**: on section load from save, restored accumulators drive the correct entry state. If restored to COMBAT but Eve isn't in the scene yet, guard enters SEARCHING (no sight target) after 1 physics frame and proceeds from LKP.
- **E.6 Takedown attempted on SEARCHING/COMBAT guard**: the attempt returns false; `receive_takedown` does NOT transition state; instead fires `actor_became_alerted(self, SAW_PLAYER, attacker.global_transform.origin, MAJOR)` and triggers propagation (failed takedown is a real first-hand detection). Emits one "you tried" vocal.
- **E.7 Two guards simultaneously discover the same body**: each guard independently crosses the `SAW_BODY` sight threshold via the combined-score rule, transitions to SEARCHING, fires `actor_became_alerted(self, SAW_BODY, body.position, MAJOR)`. Propagation bumps are still applied to both guards by each other — they're already at SEARCHING so the bump is harmless (accumulators already clamped near 1.0). Each guard tracks its own alert state independently.
- **E.8 Patrol path cut by level geometry change** (e.g., mission script opens/closes a door): `NavigationAgent3D` re-paths automatically. If no valid path exists, guard falls back to idle-sway animation at current position for `PATROL_STUCK_RECOVERY_SEC`, then attempts the next patrol node.
- **E.9 Civilian panics mid-sweep**: `civilian_witnessed_event` propagates to nearby guards; each receiving guard treats it as a `+CIVILIAN_PROPAGATION_BUMP` (default 0.5, correctness parameter — see Tuning Knobs) bump to `_sound_accumulator` (bigger than guard-to-guard `PROPAGATION_BUMP = 0.4` because civilians are usually more reliable reporters — they're reacting to what they saw, not what they heard). Cause logged as `ALERTED_BY_OTHER` (so severity is MINOR per the severity rule, no brass stinger on civilian propagation).
- **E.10 Eve dies mid-pursuit**: guards in COMBAT observing Eve's death decelerate to SEARCHING (lost target). LKP = death position. Guards then sweep the death site — but Eve's body is on `LAYER_PLAYER`, not in the `dead_guard` group, so it does NOT trigger SAW_BODY 2× fill (Eve's corpse is not an AI stimulus). Additionally, `PlayerCharacter.movement_state` transitions to DEAD and F.1's `movement_factor` for DEAD is `0.0` — so even though Eve's corpse is still inside the VisionCone Area3D on LAYER_PLAYER (group `player`, passes group filter), the sight fill rate evaluates to 0.0. Guards complete sweep on accumulator decay, play "hmph" vocal, de-escalate per normal. Failure & Respawn owns what happens next for the player. Designer note: scripted "special" scenes where guards should react dramatically to Eve's body must use `force_alert_state` on specific guards; default AI treats it as a normal sweep target, not a persistent threat.
- **E.11 Section transition during COMBAT**: Level Streaming pauses (or despawns) all guards in the old section. Serialized state: `{alert_state=COMBAT, position, rotation, patrol_index, accumulators, LKP, search_timeout_remaining, combat_lost_target_remaining}`. On return, guards resume at the serialized `alert_state` with accumulators slightly decayed (we subtract `COMBAT_SEC_ON_RELOAD × SOUND_DECAY[COMBAT]` from each accumulator to avoid "guard frozen in time" feel — default 2 s of implicit decay). **Guards ALWAYS resume at the serialized `alert_state`** — the lattice no-skip rule is preserved, COMBAT → SEARCHING → SUSPICIOUS → UNAWARE happens naturally via timers on re-entry. The GDD previously specified a direct COMBAT→SUSPICIOUS skip on reload; this has been removed for consistency with the rest of the lattice.
- **E.12 NavigationMesh missing or outdated**: `NavigationAgent3D.target_position` call returns no path; guard emits `push_warning("no navigation path to LKP %s")` and idles at current position for `INVESTIGATE_SWEEP_SEC`, then de-escalates. Fails gracefully — no freeze, no crash.
- **E.13 Takedown attacker becomes invalid (freed) during the takedown animation**: `attacker` in `receive_takedown(takedown_type, attacker)` is stored as a `Node` reference. If freed (unlikely but possible if player disconnects / mission script despawns Eve), `Events.takedown_performed.emit(self, null, takedown_type)` — subscribers MUST call `is_instance_valid(attacker)` per ADR-0002 IG4. The same guard applies to `actor_lost_target` subscribers (they read `actor.global_transform.origin` for 3D audio positioning — `is_instance_valid(actor)` required first). Documented in Signal Bus bidirectional dep statement.
- **E.14 Guard's `VisionCone` Area3D receives `body_entered(body)` for a non-player, non-dead-guard body** (Civilian, another live guard, a physics prop): guard ignores the entry — only `body.is_in_group("player")` OR `body.is_in_group("dead_guard")` triggers sight perception. No false-positive on AI-vs-AI sight.
- **E.15 Spike latch arrives during guard's 10 Hz polling gap**: per PC F.4, the 0.15 s (9-frame) latch window is wider than the 100 ms AI-tick period even with 1-frame jitter. Guard polls within the window; spike is seen. This was the explicit fix for the prior 0.1 s latch (ai-programmer B-2, PC GDD 2026-04-21).
- **E.16 Guard killed (health=0) from COMBAT by silenced pistol**: Combat & Damage GDD's `receive_damage` transitions state to DEAD; `takedown_performed` does NOT fire (this path is a kill, not a takedown). Instead, a forward-dep Combat signal (`actor_killed` or similar) fires — TBD when Combat & Damage GDD lands. At MVP stub, just set state to DEAD (applying the full DEAD cleanup per Takedown target-side effect: disable VisionCone, stop HearingPoller, zero accumulators, stop NavigationAgent3D, move to `dead_guard` group) and emit `actor_lost_target(self, MAJOR)` (severity MAJOR per the DEAD branch in `_compute_severity`) so subscribers clean up references.
- **E.17 SAW_BODY arrives mid-sweep**: guard is in SEARCHING, actively sweeping an LKP from sight/sound stimulus, when a dead-guard body enters the VisionCone (e.g., patrol route crosses a corpse the player dropped). SAW_BODY fills `_sight` at 2× (F.1 body_factor). New LKP = body position. If the displacement from current LKP exceeds `REPATH_MIN_DELTA_M` (1.0 m) AND `REPATH_INTERVAL_SEC` (1.0 s) has elapsed since last repath, `NavigationAgent3D.target_position` is re-assigned to the body position; otherwise the old path completes and the next tick reassigns. Sweep timer does NOT reset — the new SAW_BODY stimulus extends the sweep per §Investigate behavior "stimulus returns during sweep → extends the timer." Expected behavior: guard walks to body, 2× fill escalates faster, may cross T_COMBAT before body inspection completes.
- **E.18 Eve inside guard's eye (zero-distance)**: Eve touches the guard's face — vision-cone Area3D detects `body_entered` (Eve is within `VISION_MAX_RANGE_M`). Core Rules zero-distance short-circuit accepts her tautologically (dot-product bypass). F.1 fills at full rate (range_factor = 1.0 - 0/18 = 1.0). Expected behavior: guard transitions to COMBAT within ~0.4 s. Rationale: at zero distance, no reasonable player expectation of stealth applies.

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

- **Player Character** must document (already does in F.4 + Interactions): "Stealth AI reads `get_noise_level()`, `get_noise_event()`, `get_silhouette_height()`, `global_transform.origin` per perception tick; Stealth AI owns occlusion + elevation + surface propagation math; MUST NOT subscribe to `player_footstep`; callers MUST copy NoiseEvent fields before next physics frame." ✓ Already present in PC GDD Dependencies. **Additional contract** (to be added on next PC re-review): PC holds the canonical `NoiseEvent` reference for at least the full physics frame during which it was latched (no premature free); this guarantees that any guard polling within the same physics frame can safely copy fields before the RefCounted allocator reclaims the object.
- **Audio** must document: "Subscribes to `alert_state_changed` / `actor_became_alerted` / `actor_lost_target` / `takedown_performed` for music state transitions + stingers + muffled takedown SFX. Respects `is_instance_valid(actor)` guard on all Node-typed payloads per ADR-0002 IG4." Partial in Audio GDD §AI signals table; confirm on next Audio review.
- **Save / Load** must document: "Serialises per-guard state sub-resources — live: `{position, rotation, alert_state, patrol_index, sight_accumulator, sound_accumulator, last_known_position}`; dead: `{position, rotation, alert_state: DEAD, takedown_type}`. Section restart restores." Currently Save/Load GDD does not mention guards — add on next Save/Load review.
- **Mission & Level Scripting** must document: "Authors per-guard patrol routes via `Path3D` referenced by `NavigationAgent3D`. May call `force_alert_state(new_state, cause)` as a scripted escape hatch — do not use for general gameplay. Subscribes to all 4 AI signals for objective triggers." Future GDD.
- **Civilian AI** must document: "Publishes `civilian_witnessed_event(civilian, event_type, position)` on visual/audio detection of alarming events (gunfire, dead body, Eve in public); Stealth AI subscribes and treats it as a high-credibility `ALERTED_BY_OTHER` cue." Future GDD.

### Dependency risk notes

- **Navigation mesh authoring** is a mission-scripting-owned content pipeline. Stealth AI fails gracefully if a path doesn't exist (E.12), but mission authoring MUST bake navigation meshes for every section that contains guards. Content-review gate before section ships.
- **Surface-tag metadata coverage** — F.2a's `surface_factor` reads `surface_tag` meta from the same mesh bodies FootstepComponent reads. If a mesh is missing the meta, both systems fall back to `default` (1.0 factor). Risk is shared with FootstepComponent; enforcement is a single content-review pass, not two.
- **Combat & Damage forward dep (resolved 2026-04-21)** — Stealth AI guard health + blade lethal takedown are now specified by Combat & Damage GDD CR-15. Guards are 100 HP; blade takedowns deal `blade_takedown_damage = 100` via `DamageType.MELEE_BLADE`; silenced-pistol gunfights deal 34 HP per body shot (3-shot TTK). The `apply_damage_to_actor(actor, amount, source, damage_type)` signature is frozen. Pending dependency: OQ-CD-1 SAI amendment bundle (UNCONSCIOUS state + `receive_damage -> bool` return).
- **Propagation topology** — F.4 is one-hop only. If future gameplay requires multi-hop alert chains (e.g., "the whole floor goes on alert"), that's an ADR-worthy change to the propagation invariant, not a tuning tweak.
- **Behavior-tree addon adoption** — current design assumes hand-rolled state machine (user's Phase 2 decision 2026-04-21). If a future revision adopts LimboAI or similar, the state-transition table here remains authoritative; the addon just implements it. No ADR needed unless the addon adoption requires changing ship dependencies.

### Pre-implementation gates (must close BEFORE the first Stealth AI story is played)

1. **ADR-0002 amendment** — signal signatures in `Events.gd` code block MUST be revised to include `severity: StealthAI.Severity` on the 3 perception signals and the new `takedown_performed(actor, attacker, takedown_type)` signature. Owner: `technical-director` via `/architecture-decision adr-0002-amendment` in a separate session. Blocks: AC-SAI-3.3, and transitively every story that exercises AI signals.
2. **Audio GDD re-review** — Audio GDD must pass `/design-review design/gdd/audio.md` with the following gaps closed: (a) trigger table line 104 changed from "any" to `severity == MAJOR` for stinger dispatch; (b) handler signatures on lines 122–125 updated to the new 4-param / 3-param forms; (c) SFX catalog takedown entry branched into MELEE_NONLETHAL (chloroform) + STEALTH_BLADE (blade stroke + muffled body-drop) variants routed by `takedown_type`; (d) stinger per-beat-window deduplication policy declared; (e) dominant-guard dict idempotence on same-state transitions documented; (f) SCRIPTED-cause handling explicitly documented so cutscene composers know stingers fire on scripted escalation. Blocks: Stealth AI implementation (signal consumer contract is not complete until Audio consumes correctly).
3. **Signal Bus GDD touch-up** — enum ownership list must add `StealthAI.Severity` and `StealthAI.TakedownType`; domain table row must reflect the 4-param signatures. Minor edit; can land as part of ADR-0002 amendment session.
4. **Performance budget coordination** — AC-SAI-4.4 sub-budgets (perception 3 ms / navigation 2 ms / signals 1 ms = 6 ms total mean) represent Stealth AI's commitment. `technical-director` should verify this leaves compatible room for Outline Pipeline + Post-Process Stack + Combat + Civilian AI budgets across all systems. Recommended follow-up: `/architecture-decision performance-budget-distribution` as a cross-system ADR (not blocking, but the 6 ms number is a pre-agreement that can be re-negotiated only with TD sign-off).

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
| `SUSPICION_TIMEOUT_SEC` | 4.0 s | 2.5 – 6.0 | Minimum dwell time in SUSPICIOUS before de-escalate is allowed. Note: the former `SUSPICION_DWELL_FLOOR_SEC` (CURIOSITY_BAIT dwell guarantee) has been removed from the state machine — comedy-mutter timing is now owned by Dialogue & Subtitles via non-preemptive vocal scheduling, see §Detailed Rules CURIOSITY_BAIT note |
| `SEARCH_TIMEOUT_SEC` | 12.0 s | 8.0 – 20.0 | Minimum dwell time in SEARCHING before de-escalate |
| `COMBAT_LOST_TARGET_SEC` | 8.0 s | 5.0 – 15.0 | No-sight + no-damage interval before COMBAT → SEARCHING |

### Correctness parameters (not designer-tunable)

| Parameter | Default | Why |
|---|---|---|
| `CIVILIAN_PROPAGATION_BUMP` | 0.5 | E.9 civilian-to-guard propagation bump (larger than guard-to-guard because civilians are more reliable reporters). Tuning changes require ADR / pillar review |
| `ALERT_PROPAGATION_RADIUS_M` | 25.0 m | Callout distance; tuning changes require pillar review |
| `INVESTIGATE_ARRIVAL_EPSILON_M` | 0.5 m | NavAgent arrival tolerance |
| `INVESTIGATE_SWEEP_SEC` | 3.0 s | Fixed animation duration |
| `PATROL_STUCK_RECOVERY_SEC` | 5.0 s | Navigation-fail recovery |
| `REPATH_MIN_DELTA_M` | 1.0 m | Minimum LKP displacement before `NavigationAgent3D.target_position` is re-assigned (debounces re-path churn when Eve's continuous-locomotion noise polls at 10 Hz during SEARCHING). **Declare as `const`** in GDScript — runtime-clamp in `_ready()` with `assert(REPATH_MIN_DELTA_M >= 0.5)` to prevent designer accidentally driving repath-per-tick |
| `REPATH_INTERVAL_SEC` | 1.0 s | Hard floor on re-path frequency — `target_position` is not re-assigned more often than once per interval even if LKP changes by > `REPATH_MIN_DELTA_M`. **Declare as `const`** + `assert(REPATH_INTERVAL_SEC >= 0.5)` in `_ready()`; at 12 guards a 0.1 s interval gives 120 repaths/sec (ruinous for nav server) |
| `SIGHT_DECAY` / `SOUND_DECAY` | Per F.3 state-keyed table | Per-state decay schedule — tuning-balance coupled |
| `EVENT_WEIGHT` | Per F.2b table | Spike-event impact schedule |
| `PATROL_SPEED` / `INVESTIGATE_SPEED` / `COMBAT_SPRINT_SPEED` | 1.2 / 1.6 / 3.0 m/s | Guard locomotion speeds (NavigationAgent3D) |
| `VISION_CONE_DOWNWARD_ANGLE_DEG` | 15° | Cone tilts slightly down so a guard at 1.8 m eye height sees a crouching Eve at 5 m |
| `COMBAT_SEC_ON_RELOAD` | 2.0 s | Virtual decay applied on section reload per E.11 |
| `MAX_GUARDS_PER_SECTION` | 12 | Hard ceiling on simultaneously-active guards in a single section. Content-authoring constraint; perf budget assumes this ceiling (see performance AC). Restaurant section flagged as worst-case authoring. |

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

- **AC-SAI-1.1 [Logic]** GIVEN a guard in UNAWARE with both accumulators at 0.0, WHEN `_sight_accumulator` rises to 0.35 (above T_SUSPICIOUS=0.3, `combined = 0.35`) in a single physics frame via simulated fill, THEN `alert_state_changed(guard, UNAWARE, SUSPICIOUS, MINOR)` emits exactly once AND `actor_became_alerted(guard, SAW_PLAYER, stimulus_position, MINOR)` emits exactly once, in that order. Evidence: `tests/unit/stealth-ai/stealth_ai_unaware_to_suspicious_test.gd`.
- **AC-SAI-1.2 [Logic]** GIVEN a guard in SUSPICIOUS (not triggered by `CURIOSITY_BAIT`), WHEN `combined < T_DECAY_UNAWARE (0.1)` for `SUSPICION_TIMEOUT_SEC (4.0 s)`, THEN the guard transitions to UNAWARE AND emits `alert_state_changed(guard, SUSPICIOUS, UNAWARE, MINOR)` + `actor_lost_target(guard, MINOR)`. Evidence: `tests/unit/stealth-ai/stealth_ai_suspicious_to_unaware_test.gd`.
- **AC-SAI-1.3 [Logic]** Reversibility matrix: parametrized test covering **every directed edge** derived from the transition table in §States and Transitions — concretely: (UNAWARE→SUSPICIOUS), (UNAWARE→SEARCHING), (UNAWARE→COMBAT), (UNAWARE→DEAD), (SUSPICIOUS→SEARCHING), (SUSPICIOUS→UNAWARE), (SUSPICIOUS→COMBAT), (SUSPICIOUS→DEAD), (SEARCHING→SUSPICIOUS), (SEARCHING→COMBAT), (SEARCHING→DEAD), (COMBAT→SEARCHING), (COMBAT→DEAD) — 13 legal directed edges. PLUS assert the 6 forbidden direct paths each raise no transition or return false: (COMBAT→UNAWARE direct), (COMBAT→SUSPICIOUS direct), (SEARCHING→UNAWARE direct), (DEAD→any), and any transition attempting (any_state→DEAD via accumulator). Evidence: `tests/unit/stealth-ai/stealth_ai_reversibility_matrix_test.gd`.
- **AC-SAI-1.4 [Logic]** GIVEN a guard receives `receive_takedown(MELEE_NONLETHAL, attacker)` while in UNAWARE, WHEN the call returns, THEN state is DEAD, `NavigationAgent3D.target_position == guard.global_position` (agent stop mechanism — the `is_navigation_finished()` predicate becomes true on the next physics frame after path resolution; testing `target_position ==` the current position is deterministic and frame-synchronous), `VisionCone.monitoring == false`, `HearingPoller.is_physics_processing() == false`, both accumulators are 0.0, guard is in group `dead_guard` and not in group `alive_guard`, `takedown_performed(guard, attacker, MELEE_NONLETHAL)` emits exactly once. Supplementary assertion: on the FOLLOWING physics frame (after nav server sync), `is_navigation_finished() == true`. Evidence: `tests/unit/stealth-ai/stealth_ai_takedown_unaware_test.gd`.
- **AC-SAI-1.5 [Logic]** GIVEN a guard receives `receive_takedown(MELEE_NONLETHAL, attacker)` while in SEARCHING, WHEN the call returns, THEN state is NOT DEAD (takedown resisted), AND `actor_became_alerted(guard, SAW_PLAYER, attacker.position, MAJOR)` emits exactly once. Evidence: `tests/unit/stealth-ai/stealth_ai_takedown_resisted_test.gd`.
- **AC-SAI-1.6 [Logic]** COMBAT → SEARCHING de-escalation: GIVEN a guard in COMBAT with `_sight = 0.9`, WHEN sight is removed (Eve hidden) AND no damage taken for `COMBAT_LOST_TARGET_SEC (8.0 s)`, THEN guard transitions to SEARCHING, `_sight` is set to `T_SEARCHING - 0.01`, emits `alert_state_changed(guard, COMBAT, SEARCHING, MAJOR)` + `actor_lost_target(guard, MAJOR)`. Evidence: `tests/unit/stealth-ai/stealth_ai_combat_to_searching_test.gd`.

### AC-SAI-2 Perception formulas

- **AC-SAI-2.1 [Logic]** F.1 sight fill rate: parametrized test covering **all 6 factors** in the formula (`range`, `silhouette`, `movement`, `state_multiplier`, `body_factor`, plus the zero-distance short-circuit): (a) range × movement grid at 15 combinations — (range ∈ {0.5, 2, 6, 12, 17.9}, movement ∈ {Walk, Crouch, Sprint}); (b) silhouette ∈ {1.7 standing, 1.1 crouched, 0.6 hypothetical-prone → asserts clamp to 0.5}, held at range 6 m + movement Walk (3 rows); (c) state_multiplier ∈ {UNAWARE 1.0, SUSPICIOUS 1.5, SEARCHING 1.5, COMBAT 2.0}, held at range 6 m + movement Walk + silhouette 1.7 (4 rows); (d) body_factor: one row with body in `dead_guard` group at range 6 m Walk — asserts fill rate is exactly 2× the equivalent alive-player row (1 row); (e) DEAD movement_factor: one row with Eve's movement_state == DEAD at range 6 m — asserts `sight_fill_rate == 0.0` regardless of other factors (1 row); (f) zero-distance short-circuit: one row with Eve at `guard.eye_position + Vector3(0, 0, 0.01)` — asserts cone filter accepts AND `sight_fill_rate > 0` (1 row). Total: 25 rows. Asserts computed `sight_fill_rate` matches the formula within 0.01 tolerance. Evidence: `tests/unit/stealth-ai/stealth_ai_sight_fill_rate_test.gd`.
- **AC-SAI-2.2 [Logic]** F.2a sound fill rate literal formula check. Given `n = 5.0, o = 1.0, e = 1.0, f = 1.0, d = 6.0, D = 10.0, state_mult = 1.0`: expected result is `sound_fill_rate == max(0.0, n × o × e × f - d) / D × state_mult == max(0.0, -1.0) / 10.0 × 1.0 == 0.0`. The `max(0.0, ...)` wrapper is load-bearing and must be explicit in the test assertion. Extended with 4 surface_factor values × 3 elevation/occlusion combinations (12 additional rows) — assert formula matches within 0.001 tolerance. Evidence: `tests/unit/stealth-ai/stealth_ai_sound_fill_rate_test.gd`.
- **AC-SAI-2.3 [Logic]** F.2b spike handling (idempotent-read): a stub PC latches a `LANDING_HARD` NoiseEvent (radius 10 m, origin at known position). The guard's `HearingPoller` polls twice within the 0.15 s latch window; assert `_sound_accumulator` is incremented exactly once (dedupe via `_last_handled_event_id`). Additionally assert the spike cap: even with EVENT_WEIGHT = 1.5 + close-range audibility, `_sound_accumulator` never exceeds `T_SEARCHING - 0.01 = 0.59` in a single spike. Evidence: `tests/unit/stealth-ai/stealth_ai_spike_dedupe_test.gd`.
- **AC-SAI-2.4 [Logic]** F.3 decay: parametrized test for each state ({UNAWARE, SUSPICIOUS, SEARCHING, COMBAT}) starting at `_sight = 1.0` with no stimulus; after 1 second simulated with fixed-delta 60 ticks, assert `_sight_accumulator` equals `1.0 - SIGHT_DECAY[state] × 1.0` within 0.01 tolerance. Also assert accumulator never goes negative across 10 simulated seconds of decay-only input. Evidence: `tests/unit/stealth-ai/stealth_ai_decay_test.gd`.
- **AC-SAI-2.5 [Logic]** F.4 propagation (one-hop only): three guards G1/G2/G3 in a line, all UNAWARE, each within `ALERT_PROPAGATION_RADIUS_M` of its immediate neighbor. **Scenario A** (propagation suppression): G1 fires `actor_became_alerted(G1, HEARD_NOISE, pos, MAJOR)`. Assert G2 `_sound_accumulator` gains `PROPAGATION_BUMP (0.4)` clamped to ≤ 1.0; assert G2 transitions to SUSPICIOUS and fires `alert_state_changed(G2, UNAWARE, SUSPICIOUS, MINOR)` but does NOT fire `actor_became_alerted` (one-hop invariant: `cause == ALERTED_BY_OTHER` suppresses emission). Assert total `actor_became_alerted` emission count in Scenario A == 1 (only G1's original). Assert G3's `_sound_accumulator` is unchanged from baseline (no propagation from G2). **Scenario B** (non-propagation implementation would pass Scenario A trivially — close the loophole): reset accumulators, then fire a FRESH organic stimulus directly on G2 (`G2._on_heard_noise(...)` → `actor_became_alerted(G2, HEARD_NOISE, pos, MAJOR)`). Assert G3's `_sound_accumulator` DOES gain `PROPAGATION_BUMP` (0.4) this time — proves G2 is capable of propagating when its own cause is fresh, not a no-propagation implementation. Evidence: `tests/unit/stealth-ai/stealth_ai_propagation_one_hop_test.gd`.
- **AC-SAI-2.6 [Logic]** F.2a cross-floor audibility: guard on floor 2 (y≈6m), Eve on floor 1 (y≈0m) directly below with `_noise_level = 12` (Sprint), no occluders. `elevation_factor = 0.0` → `effective_radius = 0` → `audibility = 0` → no fill. Assert `_sound_accumulator` unchanged after 10 seconds simulated. Evidence: `tests/unit/stealth-ai/stealth_ai_cross_floor_silence_test.gd`.
- **AC-SAI-2.7 [Logic]** Combined score escalation: GIVEN `_sight = 0.25, _sound = 0.25`, assert `combined = max(0.25, 0.25) + 0.5 × min(0.25, 0.25) = 0.375`, which crosses `T_SUSPICIOUS = 0.3`, therefore guard transitions UNAWARE → SUSPICIOUS. Parameterized over 5 ordered pairs: {(0.25, 0.25), (0.3, 0.0), (0.0, 0.3), (0.15, 0.3), (0.6, 0.0)} — assert combined score formula and transition correctness. Evidence: `tests/unit/stealth-ai/stealth_ai_combined_score_test.gd`.

### AC-SAI-3 Signals taxonomy

- **AC-SAI-3.1 [Logic]** All 4 stealth signals fire through `Events` autoload (not node-to-node). Verified by signal spy over 300 scripted physics ticks exercising all state transitions. Evidence: `tests/unit/stealth-ai/stealth_ai_signal_taxonomy_test.gd` (function: `test_all_four_signals_fire_via_events_autoload`).
- **AC-SAI-3.2 [Logic]** Signal frequency guard: no stealth signal fires at > 30 Hz over any 1-second window during a 10-second scripted sequence (600 ticks at delta=1/60). Rationale: 30 Hz is an implementation-sanity ceiling (expected normal-play max is < 5 Hz); the AC guards against state-machine oscillation bugs, not gameplay rates. Evidence: `tests/unit/stealth-ai/stealth_ai_signal_taxonomy_test.gd` (function: `test_signal_frequency_ceiling_30hz`).
- **AC-SAI-3.3 [Logic]** Signal signatures match ADR-0002 declarations. Implemented as **static source-file grep**: assert `Events.gd` contains `signal actor_became_alerted(actor: Node, cause: StealthAI.AlertCause, source_position: Vector3, severity: StealthAI.Severity)` and similarly for the 3 other AI signals (including `takedown_performed(actor: Node, attacker: Node, takedown_type: StealthAI.TakedownType)`). **⚠️ GATE**: this AC is BLOCKED until ADR-0002 is amended and `Events.gd` is regenerated from the revised ADR. Until then, flag test as `skip("blocked on ADR-0002 amendment")` with the story's test-evidence pointer left open — do NOT merge a story that depends on this AC passing while the ADR is still on the old signatures. Secondary runtime check (lands after ADR + source update): emit with wrong-type argument in debug build and assert Godot raises an error. Evidence: `tests/unit/stealth-ai/stealth_ai_signal_payload_types_test.gd`.
- **AC-SAI-3.4 [Logic]** `_compute_severity(new_state, cause)` matrix correctness. Parametrized over the full 5×7 grid (5 AlertStates × 7 AlertCauses). Table is enumerated in the test with expected Severity value per cell. Critical cases: (a) any `cause == ALERTED_BY_OTHER` → MINOR regardless of new_state (propagation always MINOR); (b) `new_state ∈ {SEARCHING, COMBAT, DEAD}` with cause NOT ALERTED_BY_OTHER → MAJOR; (c) `new_state ∈ {UNAWARE, SUSPICIOUS}` with cause NOT ALERTED_BY_OTHER → MINOR. Evidence: `tests/unit/stealth-ai/stealth_ai_severity_rule_test.gd`.
- **AC-SAI-3.5 [Logic]** `force_alert_state(new_state, cause)` restrictions and signal emissions. Parametrized over 3 scenarios: (a) escalation allowed — `force_alert_state(SEARCHING, SCRIPTED)` on UNAWARE guard transitions to SEARCHING, emits `alert_state_changed(_, UNAWARE, SEARCHING, MAJOR)` + `actor_became_alerted(_, SCRIPTED, guard.global_transform.origin, MAJOR)`; (b) de-escalation rejected — `force_alert_state(UNAWARE, SCRIPTED)` on SEARCHING guard returns false / is a no-op AND no signal emits; (c) DEAD forbidden — `force_alert_state(DEAD, SCRIPTED)` returns false / is a no-op AND no signal emits; (d) propagation suppressed — after a successful escalation via `force_alert_state` on G1 with G2 within `ALERT_PROPAGATION_RADIUS_M`, assert G2's `_sound_accumulator` is unchanged from baseline (SCRIPTED is excluded from F.4 propagation). Evidence: `tests/unit/stealth-ai/stealth_ai_force_alert_state_test.gd`.
- **AC-SAI-3.6 [Logic]** Dead-body 2× sight fill rate (SAW_BODY path). A guard in UNAWARE with VisionCone mask including LAYER_AI spawns with a dead guard (in `dead_guard` group) at range 6 m, unobstructed. Given identical perception conditions (same range, same LOS, same state_multiplier), assert the per-frame `sight_fill_rate` is exactly 2× the equivalent alive-Eve rate at the same range. Also assert the resulting escalation fires `actor_became_alerted(_, SAW_BODY, body_position, MAJOR)` — the cause is `SAW_BODY`, not `SAW_PLAYER`. Evidence: `tests/unit/stealth-ai/stealth_ai_saw_body_fill_test.gd`.
- **AC-SAI-3.7 [Logic]** F.2b spike-cap boundary conditions. Parametrized over 4 cases: (a) `_sound = 0.0` + LANDING_HARD spike → accumulator rises to `spike_ceiling = T_SEARCHING - 0.01 = 0.59`, not higher; (b) `_sound = 0.58` + LANDING_HARD spike → accumulator rises to exactly 0.59 (to the ceiling, not above); (c) `_sound = 0.7` (already past ceiling via F.2a) + LANDING_HARD spike → accumulator UNCHANGED at 0.7 (spike cannot drop it, and cannot raise past what's already there via this path); (d) `_sound = 0.5` + small spike (fill_rate 0.05) → accumulator rises to 0.55 (additive within-cap behavior). Evidence: `tests/unit/stealth-ai/stealth_ai_spike_cap_boundary_test.gd`.
- **AC-SAI-3.8 [Logic]** Signal frequency — normal-play ceiling. In a scripted 10-second scenario with one guard and Eve performing typical stealth movement (walk + crouch + brief sight exposures + one takedown), assert total `alert_state_changed` emissions ≤ 8 AND `actor_became_alerted` emissions ≤ 5 over the 10 s window (normal-play ceiling of < 1.3 Hz combined). This complements AC-SAI-3.2 (30 Hz pathological-bug ceiling) with a normal-play sanity check — a state-machine oscillation bug at 5-15 Hz passes AC-SAI-3.2 but fails here. Evidence: `tests/unit/stealth-ai/stealth_ai_signal_taxonomy_test.gd` (function: `test_signal_frequency_normal_play_sanity`).

### AC-SAI-4 Integration + Visual/Feel

- **AC-SAI-4.1 [Integration]** Full perception loop end-to-end, **ordered signal sequence**: spawn PC + one guard in a test scene. Eve walks in front of the guard at 5 m, unobstructed. Over 3 simulated seconds (180 ticks at delta=1/60), capture all `alert_state_changed` emissions. Assert the captured sequence of `(old_state → new_state)` pairs is EXACTLY, in order: `(UNAWARE → SUSPICIOUS), (SUSPICIOUS → SEARCHING), (SEARCHING → COMBAT)` — no state may be skipped, no state may appear twice. Evidence: `tests/integration/stealth-ai/stealth_ai_full_perception_loop_test.gd`.
- **AC-SAI-4.2 [Integration]** Pillar 3 reversibility: same setup; Eve walks into LOS then immediately hides behind a concrete barrier (mask occluder). Assert guard escalates to SUSPICIOUS, then 10 seconds of hidden+silent play → returns to UNAWARE. No state history retained after timeout. Evidence: `tests/integration/stealth-ai/stealth_ai_pillar3_reversibility_test.gd`.
- **AC-SAI-4.3 [Visual/Feel]** Playtest sign-off: in a test level with 3 guards on a Plaza-like layout, the designer plays 5 sneak-past encounters, 3 takedown encounters, and 2 intentional-detection-then-hide encounters. The evidence file MUST contain an enumerated checklist and the designer MUST tick each item (a "signed off" file without ticks fails the AC):

  1. [ ] Guards verbalize callouts on each state transition; at least 3 out of 4 transitions observed per playtest (UNAWARE→SUSPICIOUS, SUSPICIOUS→SEARCHING, SEARCHING→SUSPICIOUS, etc.).
  2. [ ] No guard de-escalates from SUSPICIOUS to UNAWARE in under `SUSPICION_TIMEOUT_SEC` (4 s) of Eve being continuously invisible AND inaudible. (Escalation transitions triggered by new stimuli may occur faster than 4 s — that is by design. This item ONLY governs the SUSPICIOUS → UNAWARE de-escalation dwell.)
  3. [ ] Takedown animation completes fully before guard state changes to DEAD (no frame-0 state pop).
  4. [ ] After Eve hides and waits 10 s+, guard returns to patrol route — NOT to spawn point — and resumes patrol waypoint progression.
  5. [ ] During SUSPICIOUS dwell, at least one mutter vocal plays within the 1.5–2.5 s cadence window (Pillar 1 comedy landing).
  6. [ ] No brass-punch stinger fires on casual SUSPICIOUS-only investigations (severity MINOR); brass punch only on detection-to-SEARCHING or detection-to-COMBAT (severity MAJOR).
  7. [ ] In the 2 intentional-detection encounters, the guard's reaction progression (vocal + body language + music) reads as a coherent "scene" rather than a state-machine flicker.
  8. [ ] Designer attests, in paragraph form, that across all 10 encounters they never said or thought "that guard is bugged."

  Evidence: `production/qa/evidence/stealth-ai-pillar3-feel-[YYYY-MM-DD].md` with all 8 items checked and the paragraph attestation.
- **AC-SAI-4.4 [Integration]** Performance budget — split into overall + sub-budgets + P99. Spawn `MAX_GUARDS_PER_SECTION = 12` guards in a single test scene (NavigationMesh baked, all in `alive_guard` group, `DebugFlags.ai_debug == false` asserted at test start to prevent overlays from polluting the measurement) with Eve performing continuous-locomotion movement. Run headless for 600 physics frames (10 s at 60 Hz — longer window improves P95/P99 accuracy). Measurements target minimum-spec hardware (4C/8T x86-64, per `.claude/docs/technical-preferences.md` — record exact CPU in the evidence file).
  - **AC-4.4.a — Overall budget**: mean Stealth-AI frame time ≤ **6 ms** (36 % of 16.6 ms, leaving 10+ ms for rendering, outline pipeline, physics, audio, and future systems), P95 ≤ **8 ms**, P99 ≤ **12 ms**, max single-frame spike ≤ **15 ms** (no frame may exceed ~1 fps equivalent within the 60 Hz target).
  - **AC-4.4.b — Perception sub-budget**: sum of F.1 sight LOS (all guards) + F.2a occlusion raycast + F.2b spike read ≤ **3 ms mean / 4 ms P95** per frame.
  - **AC-4.4.c — Navigation sub-budget**: sum of NavigationAgent3D path resolution + move_and_slide + repath triggers ≤ **2 ms mean / 3 ms P95** per frame.
  - **AC-4.4.d — Signals + state-machine sub-budget**: signal emission + handler dispatch + state-transition logic ≤ **1 ms mean / 1.5 ms P95** per frame.
  - If AC-4.4.a passes but any of 4.4.b/c/d fails, the story is REJECTED regardless — sub-budgets protect against "optimized stealth at the expense of future combat." Raycast-caching per §F.1 implementation note must be in effect during the test (asserted via a frame-counter instrumentation — no sight-LOS + occlusion raycast fired on the same frame for the same guard).
  Evidence: `tests/integration/stealth-ai/stealth_ai_perf_budget_test.gd` (main) + `tests/integration/stealth-ai/stealth_ai_perf_subbudget_test.gd` (sub-budgets using `Performance.get_monitor()` samples or manual frame-time instrumentation). Evidence file includes: CPU model, frame-time histogram, per-subsystem timing table, P95/P99/max for each measurement.

### AC-SAI-5 Save/load

- **AC-SAI-5.1 [Integration]** Live-guard serialisation: guard in SEARCHING with `_sight=0.4, _sound=0.2, last_known_position=<known>, patrol_index=3, search_timeout_remaining=7.5, combat_lost_target_remaining=0.0`. Serialize to ADR-0003 save format, clear the scene, deserialize into a fresh scene — assert ALL fields restored within 0.001 tolerance (including `search_timeout_remaining` and `combat_lost_target_remaining`), state still SEARCHING, patrol_index unchanged. Evidence: `tests/integration/stealth-ai/stealth_ai_save_restore_live_test.gd`. Note: "reload" = deserialize from serialised bytes into a new scene instance (section re-entry simulation), NOT a full process restart.
- **AC-SAI-5.2 [Integration]** Dead-guard serialisation: guard takedowned as `MELEE_NONLETHAL`. Save → reload → assert state is DEAD, `takedown_type` preserved, body position preserved within 0.001 m, guard is in group `dead_guard`, `VisionCone.monitoring == false`, `HearingPoller.is_physics_processing() == false`. Evidence: `tests/integration/stealth-ai/stealth_ai_save_restore_dead_test.gd`.

## Open Questions

- **OQ-SAI-1**: Guard-to-civilian propagation bidirectional? (Does a panicking civilian cascade-alert multiple guards?) Deferred to Civilian AI GDD + playtest.
- **OQ-SAI-2**: Cover-to-cover pathfinding in COMBAT — hand-authored `CoverNode` markers vs Jolt-assisted tactical eval? Deferred to Gameplay programmer + playtest.
- **OQ-SAI-3**: Guard memory persistence across section transitions (currently: no cross-section memory). Thief-style memory graphs considered and deferred to post-MVP.
- **OQ-SAI-4**: Silenced-pistol *hearing* by other guards — does a silenced shot produce a NoiseEvent that alerts nearby guards? Currently not in F.2b EVENT_WEIGHT table. Forward-gated on Combat & Damage GDD authoring; likely resolution: add `GUNSHOT_SILENCED` with weight ~0.3 (audible at close range only).
- **OQ-SAI-5**: Behaviour-tree adoption post-MVP? Hand-rolled state machine was the MVP choice (2026-04-21). If gameplay complexity grows (multiple civilian types, boss AI, etc.), a BT library may warrant an ADR.
- **OQ-SAI-6**: Ragdoll physics on takedown vs pre-baked slump poses? Scope-creep risk; current spec defaults to pre-baked pose with ragdoll as polish-phase upgrade.
- **OQ-SAI-7**: Per-section tuning profiles? The MVP ships one global tuning profile (no difficulty selector — see systems-index Deliberately Omitted). Open question: should `VISION_MAX_RANGE_M`, `T_SUSPICIOUS`, and timers allow per-section overrides authored by Mission Scripting (e.g., Bomb Chamber guards more alert than Plaza guards), or must every guard use the global profile? **Resolution recommended BEFORE Mission & Level Scripting GDD** (game-designer N-3 2026-04-21 re-review): for a 5-section game where each section "adds one new variable" (Game Concept), single-global tuning likely forces all sections to feel the same difficulty. Straightforward implementation path: knobs become per-guard `@export` vars with a Resource-loaded default profile; per-section override = spawning guards with a different profile resource. Defer final decision to start of Mission Scripting GDD authoring.
- **OQ-SAI-8**: File decomposition under `res://src/gameplay/stealth/`. Recommended MVP structure (not ADR-worthy, refactorable later): `stealth_ai.gd` (enums + signal rule + base class, ≤150 LoC), `guard.gd` (CharacterBody3D subclass, ≤300 LoC), `perception.gd` (sight/sound accumulators + combined score, ≤200 LoC), `behavior_patrol.gd` / `behavior_investigate.gd` / `behavior_combat.gd` (one file per state behaviour, ≤150 LoC each), `patrol_controller.gd` (Path3D → NavigationAgent3D loop, ≤100 LoC). Total target: ~1000 LoC across 7 files vs 900 LoC in one file. Solo dev may consolidate during prototyping and split during the /prototype-review pass.
