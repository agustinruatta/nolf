# Civilian AI

> **Status**: In Design (Revised post-review 2026-04-25)
> **Author**: user + `/design-system civilian-ai` (solo mode); `/design-review` revision pass 2026-04-25
> **Last Updated**: 2026-04-25
> **Implements Pillars**: MVP serves 1 (Comedy Without Punchlines — chorus), 4 (Iconic Locations), 5 (Period Authenticity by absence). VS additionally serves 2 (Discovery Rewards Patience — BQA contact tells), 3 (Stealth is Theatre — witness propagation). See §Player Fantasy "Scope tier separation" for what each tier delivers.
> **Phased scope**: **MVP** = panic substrate (panic, flee, cower with CR-3a exit, audio chorus-recoil); **VS** = witness-reporting + BQA contact tells + Pillar 2/3 felt fantasy; **VS-tier-2 / Polish** = de-panic / chorus recovery + civilian-to-civilian propagation
> **Revision history**: 2026-04-25 — `/design-review` MAJOR REVISION pass addressed 12 BLOCKING items (avoidance_enabled, animation state name, panic_count interface, FleeMode enum, F.3 budget honest reframing, cower-exit liveness rule, away_dir zero-vector guard, Phase 2 NavMesh snap, LSS de-registration, AC structural fixes, OQ reclassification, Player Fantasy scope honesty)

## Overview

Civilian AI is a per-actor Gameplay feature system governing the background population of *The Paris Affair* (Plaza strollers 4-6 per section, Restaurant diners 6-8 per section, Eiffel tourists 4-6 per section — locked 2026-04-25, see §V.1 for mesh budget derivation). Unlike Stealth AI — which drives antagonistic agents with a graduated six-state alert model — CAI drives non-combatant NPCs with a deliberately thin state model: at **MVP stub** scope, each civilian is a `CharacterBody3D` with a stable `actor_id: StringName` (per ADR-0003 save-format contract), a two-state panic machine (`CALM` → `PANICKED`, terminal within a section), a `NavigationAgent3D` for panic-flight, and two Signal Bus responsibilities — **publishing `civilian_panicked(civilian: Node, cause_position: Vector3)`** (ADR-0002 signature, locked) when triggered by nearby `weapon_fired` / `enemy_killed` / direct damage, and **subscribing to the AI/Stealth + Combat domains** only. At **VS (full) scope**, CAI additionally publishes `civilian_witnessed_event(civilian, event_type: CivilianAI.WitnessEventType, position)` (ADR-0002 locked signature — enum owned by this GDD) for witness-reporting (Stealth AI's `ALERTED_BY_OTHER` propagation path, `CIVILIAN_PROPAGATION_BUMP = 0.5`), and promotes a subset of civilians to BQA contacts whose outline tier upgrades from environmental Tier 3 LIGHT (1.5 px, ADR-0001) to comedic-hero Tier 1 HEAVIEST (4 px) at pickup distance — Pillar 2's "Discovery Rewards Patience" made diegetic-visual. CAI is a **per-actor scene pattern, not an autoload** (mirrors Stealth AI; ADR-0007 reserves no slot); its ticking work is budgeted against **ADR-0008 Slot #8 pooled residual** (shared sub-claim of the 0.8 ms pool across MLS / DC / Dialogue / F&R / CAI / Signal-Bus-dispatch), and its physics footprint uses `LAYER_AI = 3` (ADR-0006) with group tag `civilian` (excluded by SAI's E.14 group filter from `player` / `dead_guard` / `alive_guard`). For the player, the system's effect is felt as **chorus, not co-star**: civilians gasp *"Mon Dieu!"* on panic (Audio GDD Formula 2 — diegetic recedes, non-diegetic holds — so the quartet recoils while Eve's underscoring stays cool), they flee into corners or out of line-of-fire, and their stationary bystander banter (authored in MLS via T6 Alert-State Comedy triggers, not by this GDD) is the Comedy-Without-Punchlines counterpoint to the Deadpan Witness. Civilians cannot die at MVP — they block bullets but treat damage as a panic trigger — preserving Pillar 5 tone (no civilian-casualty mechanic to reward, no "don't kill the bystander" minigame) and collapsing a class of edge cases. This GDD owns civilian *behavior and state*; it does **not** own civilian *models/animations* (art-director), *voice-line authoring* ("Mon Dieu!" routed through Audio + Dialogue & Subtitles VO pipeline), *scripted banter triggers* (Mission & Level Scripting T6), or *placement* (level-designer authoring per section scene).

## Player Fantasy

**Player fantasy (full / VS-tier deliverable)**: *You are sneaking through a public monument on a Tuesday afternoon — and being seen by a city that is too busy to understand what it is seeing.*

**Anchor moment (VS-tier)** — Eve is crouched behind a service trolley on the Tower's first level, watching a guard's patrol arc. A retired schoolteacher with a Baedeker guidebook walks past her hiding spot, sees her, blinks, and continues toward the viewing platform muttering about the queues. The guard never knows. Three minutes later the schoolteacher mentions "a strange English lady behind the pastries" to the floor manager — a guard drifts over to check, MINOR cause, no stinger. Eve has been **seen**, and the game knows it, and the world reads her back.

Stealth games usually pretend the world is empty. *The Paris Affair* refuses. Eve is a BQA agent moving through a city full of waiters, ticket-takers, retirees, postcard-sellers, and women in green coats — all of them on their own Tuesday, none of them in her game. They notice her. They do not punish her. They are the audience the theatre needs to be theatre. The fantasy is being *watched* and being *unbothered* by it: every successful infiltration is a performance witnessed by people who never quite understood what they saw. The Deadpan Witness has witnesses of her own.

### Scope tier separation — what each tier delivers

**This GDD is honest about which tier carries which payoff.** Approving the GDD does NOT mean MVP delivers the full fantasy.

| Tier | What lands | What is absent |
|---|---|---|
| **MVP** (panic substrate) | Civilians panic when gunfire/death occurs nearby; flee toward authored anchors or fall back to NavMesh away-direction; cower when threat is at point-blank; gasp ("Mon Dieu!") via Audio Formula 2 chorus-recoil; LOAD_FROM_SAVE restores panic state. | Witness propagation (no schoolteacher → floor-manager → guard chain). BQA contact differentiation (all civilians render Tier 3 LIGHT). De-panic / chorus recovery (terminal panic; civilians remain cowering for the rest of the section after one gunshot — a known degradation). Civilian-to-civilian panic propagation. |
| **VS** (felt fantasy) | Witness-event signal landing the schoolteacher anchor moment (Pillar 3 payoff). BQA contact outline-tier promotion at 3.0 m pickup distance. `civilian_witnessed_event` consumed by SAI's `ALERTED_BY_OTHER` propagation at MINOR severity. Audio crowd-murmur uptick. | De-panic (still terminal at VS-tier-1; CALMED state reserved for VS-tier-2). Civilian-to-civilian propagation (still out of scope; flagged as a recommended VS-tier-2 addition in §Open Questions OQ-CAI-7). Localized gasps (period-French "Mon Dieu!" in all locales by Pillar 5 design). |
| **VS-tier-2 / Polish** (recovery, propagation) | De-panic via Audio Formula 2 Rule 5 + new `civilian_calmed` filter on `alert_state_changed`. Optional civilian-to-civilian propagation (deadpan-vs-broken-AI fix). | n/a |

**MVP playtest expectation note**: at first internal MVP playtest, expect the chorus to read as "panicked, then frozen for the rest of the section" rather than "city that recovers and continues." This is a known tier-scoped limitation, not a design failure. Producer should brief playtesters accordingly so MVP feedback targets the panic substrate, not the absent VS-tier payoffs.

### Pillar mapping (per tier)

**MVP serves**: Pillar 1 (Comedy Without Punchlines) via the diegetic-vs-non-diegetic music asymmetry of Formula 2 (chorus recoils, score holds); Pillar 4 (Iconic Locations) by populating each setting with archetype-appropriate ambient civilians; Pillar 5 (Period Authenticity) by absence of HUD markers, quest indicators, or floating dialogue bubbles. **MVP does NOT serve Pillar 2 or Pillar 3 in the felt sense** — the panic substrate is necessary but not sufficient for either pillar.

**VS additionally serves**: Pillar 3 (Stealth is Theatre, Not Punishment) via witness propagation — the audience makes the theatre literal; Pillar 2 (Discovery Rewards Patience) via BQA contact outline-tier promotion as the only diegetic-visual tell, plus art-director-owned composed-geometry tells (folded newspaper, period briefcase clasp — coord item AD-COORD-01) that complete the "hidden in plain sight" promise. **Both Pillar 2 and Pillar 3 are VS-tier deliverables; MVP ships the substrate only.**

**Design test (VS-tier)**: *If we're debating whether civilians should display floating intel-tooltips when they're a BQA contact, this framing says no — the contact is hidden in plain sight, and patience is the password (per Pillar 2). The outline-tier promotion at pickup distance (Tier 3 LIGHT → Tier 1 HEAVIEST per ADR-0001) is the only diegetic-visual tell.*

## Detailed Design

### C.0 Public API surface (declared on `class_name CivilianAI`)

For external consumers (Audio panic_count rebuild, AC observers, save/load), `CivilianAI` exposes the following public API. All other state is private (`_`-prefixed) by convention. Do not duck-type-access private state from other systems.

```gdscript
class_name CivilianAI extends CharacterBody3D

# Save-format-stable identity
@export var actor_id: StringName

# Panic state machine
enum PanicState { CALM, PANICKED }

# Flee algorithm sub-mode (within PANICKED)
enum FleeMode { NONE, COWERING, FLEEING_TO_ANCHOR, FLEEING_AWAY }

# Witness event taxonomy (CAI owns; ADR-0002 stub)
enum WitnessEventType {
    GUNFIRE_NEARBY,
    GUARD_KILLED_NEARBY,
    EVE_BRANDISHING_WEAPON,
    GUARD_BODY_VISIBLE,
}

# Public read-only accessors (Audio LOAD_FROM_SAVE rebuild reads these via group query)
func is_panicked() -> bool: return _panic_state
func get_cause_position() -> Vector3: return _cause_position

# Save/restore contract (ADR-0003)
func capture() -> Dictionary: ...
# (private _restore_state called by LevelStreamingService)

# Damage no-op (Combat duck-type contract per CR-7)
func receive_damage(amount: float, source: Node, type: int) -> void: ...
```

Private state (NOT public; `_`-prefix discouraged from external access by convention; CI lint flag for cross-script access on private members is ADVISORY): `_panic_state: bool`, `_cause_position: Vector3`, `_fleeing_mode: FleeMode`, `_witnessed_event_already_emitted: bool`, `_cower_started_at_msec: int`.

### C.1 Core Rules

**CR-1 — Entity contract.** Each civilian is a `CharacterBody3D` scene (`Civilian.tscn`) with GDScript root `class_name CivilianAI`. Required children: `NavigationAgent3D`, `CollisionShape3D` (capsule), `MeshInstance3D` (art), `AnimationTree`, `Timer` named `CowerExitTimer` (per CR-3a). Physics: `set_collision_layer_value(PhysicsLayers.LAYER_AI, true)` and `set_collision_mask_value(PhysicsLayers.LAYER_WORLD, true)` — bare integer masks are an ADR-0006 forbidden pattern. Group membership: `"civilian"` only. Civilians MUST NOT be in `"player"`, `"dead_guard"`, or `"alive_guard"` groups — Stealth AI's E.14 dual-filter (group check + `body is PlayerCharacter|GuardBase` class check) keeps civilians invisible to guard vision; a mis-authored group tag would bypass the class-check fallback. No autoload — per-actor scene pattern mirrors SAI (ADR-0007 reserves no slot for CAI).

**CR-1a — Required `NavigationAgent3D` initialization.** In `_ready()`, the civilian MUST set:

- `nav_agent.avoidance_enabled = true` — Godot 4.x defaults this to `false`. Without it, the `velocity_computed` callback never fires and `move_and_slide()` never runs (CR-8 RVO contract); civilians silently fail to move. **This is the single most common implementation footgun for this system** (ai-programmer + godot-specialist convergent finding 2026-04-25). Forbidden pattern grep #11 catches missing initialization.
- `nav_agent.path_desired_distance = 0.5` (m) — distance threshold for advancing to the next path point.
- `nav_agent.target_desired_distance = 1.0` (m) — distance at which `is_navigation_finished()` returns `true`. Tighter values (≤0.3) cause the E.28 stutter described in OQ-CAI-3.
- `nav_agent.radius = 0.4` (m) — RVO neighbor avoidance radius (matches `CharacterBody3D` capsule radius authored in `Civilian.tscn`).

These four properties may also be set in `Civilian.tscn` directly; the runtime `_ready()` setters are belt-and-braces. AC-CAI-1.1 verifies all four post-`_ready()`.

**CR-2 — `actor_id` export.** Every civilian exports `@export var actor_id: StringName` (section-scoped unique, set in editor by level designer per ADR-0003 + MLS §C.5.3 per-actor invariant). At `_ready()`, an empty `actor_id` calls `push_error()` and disables the actor (`set_process(false)`, `set_physics_process(false)`); the engine does not crash. `actor_id` MUST NOT be runtime-generated.

**CR-3 — Two-state panic machine (MVP terminal panic; per-cower-instance exit).** `enum PanicState { CALM, PANICKED }` owned by `CivilianAI`. `CALM` is the entry state on scene load. `PANICKED` is **terminal within a section at MVP** — there is no de-panic signal in ADR-0002 taxonomy at MVP, and Audio's Formula 2 Rule 5 (de-panic decrement) is forward-compatible dead code at MVP. **However, the COWERING sub-mode of PANICKED is NOT terminal — see CR-3a.** VS-tier-2 / Polish scope MAY introduce a true `CALMED` transition driven by a future `Events.alert_state_changed` filter (all guards UNAWARE) plus a new `Events.civilian_calmed` signal, guarded by feature flag; this GDD reserves the state name and forward-compatible Audio Rule 5 wiring without specifying its trigger at MVP.

**CR-3a — Cower-exit rule (resolves cower-freeze liveness bug).** A civilian in PANICKED `_fleeing_mode = COWERING` (§C.3 Phase 1) is **not** permanently frozen. Cower exits and transitions to `_set_flee_target(_cause_position)` re-evaluation when EITHER:

- **Threat-leave condition**: the cause position has left the cower radius. Sampled at ~1 Hz (every 60 physics frames at 60 fps) via a `Timer` node child of the civilian (lighter than re-enabling `_physics_process` for proximity polling). On Timer timeout, evaluate `_cause_position.distance_to(global_position) > COWER_RADIUS_M`. If true: re-run `_set_flee_target(_cause_position)` (which will now fall through Phase 1 to Phase 2 anchor selection or Phase 3 fallback). Audio's `panic_count` does not change (still PANICKED, just no longer COWERING).
- **Timeout condition**: `MAX_COWER_DURATION_S = 8.0` seconds elapsed since cower entry, regardless of threat position. Same Timer node fires the timeout; on expiration, re-run `_set_flee_target(_cause_position)`. If the threat is still within cower radius at timeout, Phase 1 re-fires and the cower restarts (refreshing the timer); over time, this means a stationary close-range threat will produce a slow oscillation between cower and re-evaluate, which is acceptable behavior (matches "civilian cowering, occasionally peeking" body language).

The Timer node lives on the civilian scene (`Civilian.tscn` adds a `Timer` child named `CowerExitTimer` with `wait_time = 1.0`, `one_shot = false`, `autostart = false`). It is started in `_set_flee_target` when entering Phase 1 and stopped on cower exit. `set_physics_process(false)` is preserved during cower (the Timer's `timeout` signal handler is not gated by physics process).

**MVP scope**: CR-3a is in scope at MVP. The cower-exit rule is necessary even at MVP because without it the very first gunshot in a section produces permanently-frozen NPCs (game-designer + ai-programmer convergent finding 2026-04-25). It is not de-panic — the civilian remains PANICKED; only the within-PANICKED cower sub-mode is non-terminal.

**CR-4 — Panic triggers (MVP).** Exactly three event sources flip `CALM → PANICKED`, all routed through internal `_trigger_panic(cause_position: Vector3)`:

1. **`Events.weapon_fired(shooter: Node, position: Vector3, noise_radius_m: float)`** — ADR-0002 Combat domain. Triggers panic when `self.global_position.distance_to(position) <= PANIC_GUNFIRE_RADIUS_M` (default 12.0 m). `cause_position = position`.
2. **`Events.enemy_killed(actor: Node, killer: Node)`** — ADR-0002 Combat domain. Triggers panic when `is_instance_valid(actor) AND actor.global_position.distance_to(self.global_position) <= PANIC_BODY_RADIUS_M` (default 8.0 m). `cause_position = actor.global_position` (validated). User-adjudicated 2026-04-24: this is the kill-signal subscription; CAI does **not** subscribe to `guard_incapacitated` (UNCONSCIOUS chloroform takedowns are STEALTH successes — the chorus must not ruin them).
3. **`receive_damage(amount: float, source: Node, type: int) -> void`** — direct duck-typed call from Combat hitscan or dart `area_entered` handler (Combat GDD pattern: `if body.has_method("receive_damage"): body.receive_damage(...)`). Triggers panic unconditionally; `cause_position = source.global_position if is_instance_valid(source) else self.global_position`. See CR-7.

**CR-5 — Idempotency latch.** `_trigger_panic(cause_position)` first checks `if _panic_state: return _maybe_retarget_flee(cause_position)`. The `_panic_state: bool` flag is the latch. Same-frame double trigger (e.g., simultaneous `weapon_fired` AND `enemy_killed` within radius) emits `Events.civilian_panicked` exactly once — the first handler closes the latch synchronously before the second handler's guard check runs (Godot signal dispatch is synchronous and direct by default; no `call_deferred` allowed in the trigger path). Already-PANICKED civilians silently no-op for emission but **may update flee target** if the new cause is geometrically closer (`_maybe_retarget_flee` re-runs §C.3 algorithm and calls `NavigationAgent3D.set_target_position()` with the new target; no signal re-emission).

**CR-6 — Signal emission: `civilian_panicked`.** `Events.civilian_panicked.emit(self, cause_position)` fires **exactly once per civilian per section**, synchronously, at the instant of `CALM → PANICKED` transition, AFTER `_panic_state = true` is set (so re-entrant signal handlers see the latched state) and AFTER `cause_position` is stored, but BEFORE the flee target is computed. ADR-0002 locked signature: `civilian_panicked(civilian: Node, cause_position: Vector3)`. Audio's Formula 2 (diegetic recedes −3 dB cap, non-diegetic +2 dB cap) consumes this; subscribers MUST guard `is_instance_valid(civilian)` per ADR-0002 Rule 4.

**CR-7 — `receive_damage` no-op.** Civilians implement the duck-typed method `receive_damage(amount: float, source: Node, type: int) -> void` to satisfy Combat's `has_method` check, but the implementation MUST NOT subtract HP, MUST NOT kill the civilian, MUST NOT emit any damage-domain signal (`player_damaged`, `enemy_damaged`, `enemy_killed`, `player_died`). Its only effect is `_trigger_panic(source.global_position if is_instance_valid(source) else self.global_position)`. Civilians block bullets via standard `CharacterBody3D` collision but are effectively invincible. **This rule has no MVP/VS scope split — civilians never die in this game** (preserves Pillar 5 tone — no civilian-casualty mechanic to manage).

**CR-8 — Flee behavior.** On `CALM → PANICKED` transition (after CR-6 emission), the civilian computes a flee target via §C.3 algorithm, calls `NavigationAgent3D.set_target_position(flee_target)`, then `set_physics_process(true)` to begin per-frame nav feeding. Movement uses the **`velocity_computed` avoidance callback** (RVO2; requires `nav_agent.avoidance_enabled = true` per CR-1a): `_physics_process` reads `NavigationAgent3D.get_next_path_position()` and assigns `nav_agent.velocity = (next_pos - global_position).normalized() * FLEE_SPEED_MPS` (default 4.5 m/s); the `velocity_computed(safe_velocity)` signal callback then assigns `velocity = safe_velocity` and calls `move_and_slide()`. `move_and_slide()` MUST NOT be called from `_physics_process` directly — that bypasses RVO avoidance and causes civilians to clip into each other in the Restaurant 6-8-civilian worst case. On `is_navigation_finished() == true`, the civilian calls `set_physics_process(false)` (idle ADR-0008 amortization) and `AnimationTree.travel("cower")` (the canonical post-arrival animation state per V.2; matches the cower state used in Phase 1 of the §C.3 algorithm — one state name, not "panic-idle/cower").

**Note on flee speed reconciliation (game-designer 2026-04-25 finding)**: `FLEE_SPEED_MPS = 4.5 m/s` is incompatible with V.2's "fast walk cycle (~2.4 m/s)" animation register. The animation must be authored to match the 4.5 m/s pace (a brisk jog, not a fast walk), OR `FLEE_SPEED_MPS` must be lowered to ~3.0 m/s. Resolution coord item §F.5#11 (art-director + animation owner). Until resolved, treat 4.5 m/s as a target movement speed that the animation pipeline must hit.

**CR-9 — Per-frame work amortization (ADR-0008 Slot #8 sub-claim).** Civilians **MUST NOT poll** in `_process` — bare `_process` overrides are a forbidden pattern (CR-15). All per-frame work is gated:

- `_ready()`: `set_physics_process(false)` (CALM idle: zero per-frame cost)
- Panic onset: `set_physics_process(true)` after flee target set
- `is_navigation_finished()`: `set_physics_process(false)`

CAI claims **0.30 ms p95** of ADR-0008 Slot #8's pooled 0.8 ms (revised 2026-04-25 from 0.15 ms after honest 4-component decomposition — see §F.3 below; the original 0.15 ms claim under-counted `C_move_and_slide` + `C_burst` + `C_rvo_step` per ai-programmer review). Steady-state (post-onset, navigating): 8 civilians × (20 + 12) µs ≈ 256 µs per frame ≈ 0.256 ms (within 0.30 ms p95). Signal-handler bursts on panic onset (panic-onset spike at ~896 µs across 8 civilians) **busts the 0.8 ms Slot 8 cap on the onset frame and is allocated against ADR-0008's reserve carve-out** (registered 2026-04-28 amendment per `/review-all-gdds` — up to 0.6 ms of the 1.6 ms global reserve pre-allocated for `civilian_panicked` ≥ 4 emissions in a single physics frame; producer + technical-director sign-off required to invoke).

**CR-10 — Save / restore contract (ADR-0003).** Civilians implement `capture() -> Dictionary` returning `{ "panicked": _panic_state, "cause": _cause_position }`. At `_ready()`, each civilian calls `LevelStreamingService.register_restore_callback(_restore_state)` (mirrors Inventory + F&R + SAI patterns) AND in `_exit_tree()` calls `LevelStreamingService.unregister_restore_callback(_restore_state)` to prevent stale-callback use-after-free on `change_scene_to_file` reload (ai-programmer 2026-04-25 finding — F&R RESPAWN path uses `change_scene_to_file`; without unregistration, the LSS callback registry holds a `Callable` whose object becomes invalid). `_restore_state(state: CivilianAIState)` reads its own entry by `actor_id` lookup, guards `nav_agent.get_navigation_map().is_valid()` before any `NavigationServer3D.map_get_closest_point` call (defers flee-target recomputation to next physics frame if NavMesh RID not yet ready — godot-specialist OQ-CAI-3 sub-finding 2026-04-25), and re-runs §C.3 algorithm. **User-adjudicated 2026-04-24**: on `LOAD_FROM_SAVE` restore of a `panicked: true` civilian, CAI **recomputes flee target from saved `_cause_position`** and resumes fleeing — preserving the Player Fantasy anchor (schoolteacher resumes walking toward viewing platform). **NO `civilian_panicked` re-emit on restore** (mirrors F&R LOAD_FROM_SAVE suppression — Audio rebuilds `panic_count` via direct query of `get_tree().get_nodes_in_group("civilian")` at restore time, calling **`node.is_panicked()` on each** (per CR-0 public API), NOT via signal). The `CivilianAIState` Resource is a `Dictionary[StringName, Dictionary]` keyed by `actor_id`, stored as a sub-resource of `SaveGame` per ADR-0003 schema. **Witness latch persistence (VS-only)**: `_witnessed_event_already_emitted` is **not** captured by design — `Events.section_entered` resets it on every load (LOAD_FROM_SAVE fires `section_entered`), which is the equivalent of a section reload. The "one-shot per civilian per section" guarantee holds within a single play session between LOAD_FROM_SAVE points; loading resets the latch by design (systems-designer LOW-2 finding 2026-04-25, intentional).

**CR-11 — Signal subscription lifecycle.** In `_ready()`:
```gdscript
Events.weapon_fired.connect(_on_weapon_fired)
Events.enemy_killed.connect(_on_enemy_killed)
Events.section_entered.connect(_on_section_entered)  # for VS-only witness latch reset
nav_agent.velocity_computed.connect(_on_velocity_computed)
$CowerExitTimer.timeout.connect(_on_cower_exit_timer_timeout)
LevelStreamingService.register_restore_callback(_restore_state)
```
In `_exit_tree()`: explicit `is_connected` + `disconnect` on each `Events`-domain signal AND **explicit `LevelStreamingService.unregister_restore_callback(_restore_state)`** (CR-10 use-after-free guard). The `nav_agent.velocity_computed` and `$CowerExitTimer.timeout` connections auto-clean on civilian free (target-bound `Callable`), but the LSS registry must be told (LSS holds the callback in its own collection, not via Godot's auto-disconnect path). Disconnect rationale: Godot 4.x auto-disconnects target-bound callables when the target is freed; explicit `disconnect` on `Events`-domain autoload signals is project convention (defensive coding). Lambda-captured connections are NOT used (would defeat auto-disconnect). All Node-typed payloads MUST guard `is_instance_valid()` per ADR-0002 Rule 4. Civilians MUST NOT subscribe to `Events.player_footstep` (Eve walking is not alarming — same forbid as SAI; CR-15.1) or `Events.alert_state_changed` at MVP (civilians don't react to guard-state transitions; only to environmental events).

**CR-12 — `civilian_witnessed_event` emission (VS-tier only — stub at MVP).** *MVP scope: this signal is NOT emitted.* At VS scope: emission is **coupled to panic onset** as a side effect of the CALM→PANICKED transition (single subscriber path; civilians cannot witness while CALM at VS-tier-1 scope). After CR-6 emits `civilian_panicked` and BEFORE flee-target compute, if `_witnessed_event_already_emitted == false`, emit `Events.civilian_witnessed_event.emit(self, event_type, cause_position)` and set the latch. ADR-0002 locked signature: `civilian_witnessed_event(civilian: Node, event_type: CivilianAI.WitnessEventType, position: Vector3)`. Stealth AI subscribes with `CIVILIAN_PROPAGATION_BUMP = 0.5` `ALERTED_BY_OTHER` MINOR severity (no stinger). The `_witnessed_event_already_emitted` latch is **one-shot per civilian per section** — a panicked civilian who hears a second gunshot does not re-emit (chorus role is a single alerting vector per actor).

**CR-13 — `WitnessEventType` enum (CAI owns, ADR-0002 stub required).** Declared on `CivilianAI`:
```gdscript
enum WitnessEventType {
    GUNFIRE_NEARBY,           # weapon_fired within radius — sound, no LOS
    GUARD_KILLED_NEARBY,      # enemy_killed within radius — sound + visual proxy, no LOS
    EVE_BRANDISHING_WEAPON,   # VS-tier: gadget_equipped/weapon_switched while in public — coord with Inventory
    GUARD_BODY_VISIBLE,       # VS post-MVP: ambient body discovery — stub for forward compat
}
```
The enum stub MUST exist before `Events.gd` compiles (ADR-0002 atomic-commit rule); empty enum body permitted at MVP if VS values are not yet mapped to triggers.

**CR-14 — BQA contact outline promotion (VS-tier only — stub at MVP).** *MVP scope: all civilians render Tier 3 LIGHT (1.5 px, ADR-0001) — no BQA distinction.* At VS scope: `BQAContact.tscn` extends `Civilian.tscn` with `@export var is_bqa_contact: bool = true` AND a child `Area3D` (sphere shape, radius `BQA_PICKUP_DISTANCE_M`, default 3.0 m, layer 0 mask `MASK_PLAYER`). On `body_entered(body)`: if `body is PlayerCharacter`, call `OutlineTier.set_tier(self.mesh_instance_3d, OutlineTier.HEAVIEST)` — **`set_tier` takes a `MeshInstance3D`, NOT the civilian node** (ADR-0001 signature). On `body_exited`: restore `OutlineTier.set_tier(self.mesh_instance_3d, OutlineTier.LIGHT)`. Area3D event-driven approach has zero per-frame cost (Jolt `body_entered` reliable at Eve walking speed ≤5.5 m/s per ADR-0006 §305 risk analysis). **VS-gated:** ADR-0001 is currently Proposed; this CR is enforceable when ADR-0001 reaches Accepted.

**CR-15 — Forbidden patterns (CI grep-enforced — see §C.6 for full list, AC-CAI-8.3 for canonical greps).** Civilians MUST NOT subscribe to `player_footstep`, hold direct refs to `PlayerCharacter`/`GuardBase`/non-Events autoloads, be in `player`/`dead_guard`/`alive_guard` groups, decrement HP, fire weapons, override `_process` (use `_physics_process` gated only), emit damage-domain signals, miss `nav_agent.avoidance_enabled = true` initialization (CR-1a), or directly manipulate `AudioServer` / `AudioStreamPlayer` (audio-director 2026-04-25 finding — bypasses Audio's bus + concurrency policies).

### C.2 States and Transitions

| State | Description | Per-state behavior | Save flag |
|---|---|---|---|
| **CALM** | Civilian going about scripted ambient behavior (idle / scripted patrol authored by level-designer + MLS, NOT by CAI). | `set_physics_process(false)` — zero per-frame cost. Signal handlers connected. AnimationTree in `idle` state (or scripted state machine for stationary banter NPCs — out of CAI scope). | `panicked: false` |
| **PANICKED** | Civilian fleeing toward computed flee target. **Terminal within section at MVP.** | `set_physics_process(true)` while navigating; `_physics_process` reads `get_next_path_position`, assigns `nav_agent.velocity`, defers `move_and_slide` to `velocity_computed` callback. AnimationTree in `panic_flee` state. On `is_navigation_finished`: `set_physics_process(false)` + AnimationTree → panic-idle/cower. | `panicked: true`, `cause: Vector3` |

| From → To | Trigger | Guard | Side effects (ordered) |
|---|---|---|---|
| CALM → PANICKED | `Events.weapon_fired` distance check ∨ `Events.enemy_killed` distance check ∨ `receive_damage` invocation | `_panic_state == false` | (1) `_panic_state = true`; (2) `_cause_position = cause_position`; (3) `Events.civilian_panicked.emit(self, cause_position)`; (4) **VS only**: if `!_witnessed_event_already_emitted`: `Events.civilian_witnessed_event.emit(self, event_type, cause_position)` + set latch; (5) `_set_flee_target(cause_position)` (computes Phase 1 cower / Phase 2 anchor / Phase 3 fallback per §C.3); (6) `nav_agent.set_target_position(flee_target)` if not COWERING; (7) `set_physics_process(true)` if not COWERING; if COWERING, `$CowerExitTimer.start()` instead; (8) `AnimationTree.travel("panic_flee")` if not COWERING; `AnimationTree.travel("cower")` if COWERING. |
| PANICKED → PANICKED (re-target via `_maybe_retarget_flee`) | Same triggers, while panicked | `_panic_state == true` AND `new_cause_distance < old_cause_distance` (F.2 strict less-than) | (1) `_cause_position = cause_position`; (2) `_set_flee_target(cause_position)` (re-evaluates Phase 1/2/3); (3) update nav target / cower / fallback per result; (4) restart `$CowerExitTimer` if entering COWERING. **No signal re-emission.** |
| PANICKED COWERING → PANICKED FLEEING (cower-exit, threat-leave; CR-3a) | `$CowerExitTimer.timeout` fires (every 1.0s) AND `_cause_position.distance_to(global_position) > COWER_RADIUS_M` | `_panic_state == true` AND `_fleeing_mode == COWERING` | (1) `_set_flee_target(_cause_position)` (will fall through Phase 1 to Phase 2/3); (2) `nav_agent.set_target_position(new_target)`; (3) `set_physics_process(true)`; (4) `AnimationTree.travel("panic_flee")`; (5) `$CowerExitTimer.stop()`. **No signal re-emission** (still PANICKED). |
| PANICKED COWERING → PANICKED FLEEING (cower-exit, timeout; CR-3a) | `$CowerExitTimer` accumulated `MAX_COWER_DURATION_S = 8.0` of cower; threat still within cower radius | `_panic_state == true` AND `_fleeing_mode == COWERING` AND `_cower_started_at_msec` differ from now by ≥ 8000 ms | (1) `_set_flee_target(_cause_position)` (Phase 1 re-fires, refreshes cower OR exits if anchor now valid via re-pathing); (2) reset `_cower_started_at_msec = Time.get_ticks_msec()` if Phase 1 re-fires (cower restart); (3) otherwise transition to FLEEING_TO_ANCHOR / FLEEING_AWAY same as threat-leave path. **No signal re-emission.** |
| (PANICKED → CALMED) | **VS-tier-2 / Polish only** — reserved for future de-panic implementation (filtered `alert_state_changed` AND new `Events.civilian_calmed` signal) | n/a at MVP / VS-tier-1 | n/a at MVP / VS-tier-1 |

### C.3 Flee Target Selection Algorithm

On panic onset (CR-8) the civilian runs this **once** (not per-frame) to set a single Nav target:

```gdscript
const COWER_RADIUS_M: float = 2.0
const ANCHOR_OPPOSITE_DOT_THRESHOLD: float = 0.3   # cos(72°) ≈ "any anchor not behind cause"
const ANCHOR_NAV_SNAP_TOLERANCE_M: float = 1.0
const FLEE_FALLBACK_DISTANCE_M: float = 15.0
const MAX_COWER_DURATION_S: float = 8.0   # CR-3a cower-exit timeout safety net

func _set_flee_target(cause_pos: Vector3) -> void:
    # NavMesh RID validity guard (CR-10 sub-finding; restore-time race protection)
    var nav_map: RID = nav_agent.get_navigation_map()
    if not nav_map.is_valid():
        # Defer to next physics frame — NavMesh region not yet registered (e.g., during LOAD_FROM_SAVE
        # restore where _ready() ran before NavigationRegion3D bake completed).
        push_warning("CivilianAI._set_flee_target: nav_map RID invalid, deferring 1 frame.")
        await get_tree().physics_frame
        nav_map = nav_agent.get_navigation_map()
        if not nav_map.is_valid():
            _fleeing_mode = FleeMode.COWERING  # safe fallback; cower-exit timer will retry
            $CowerExitTimer.start()
            return

    # Phase 1 — cower in place if too close to react meaningfully
    var cause_distance: float = cause_pos.distance_to(global_position)
    if cause_distance <= COWER_RADIUS_M:
        _fleeing_mode = FleeMode.COWERING
        _cower_started_at_msec = Time.get_ticks_msec()
        $CowerExitTimer.start()  # CR-3a: 1.0s polling interval; sample threat-leave + timeout
        # No nav target. AnimationTree → cower. set_physics_process stays false.
        return

    # Compute away_dir and guard against degenerate (numerically near-zero) magnitude.
    var raw_away: Vector3 = global_position - cause_pos
    if raw_away.is_zero_approx():
        # Reachable via receive_damage path with source.global_position == self.global_position.
        # Phase 1 should have caught this (distance == 0.0 <= COWER_RADIUS_M), but belt-and-braces:
        _fleeing_mode = FleeMode.COWERING
        _cower_started_at_msec = Time.get_ticks_msec()
        $CowerExitTimer.start()
        return
    var away_dir: Vector3 = raw_away.normalized()

    # Phase 2 — find best level-authored panic_anchor on opposite side of cause
    var best_anchor: Node3D = null
    var best_anchor_snapped: Vector3 = Vector3.ZERO
    var best_score: float = INF
    for anchor in get_tree().get_nodes_in_group("panic_anchor"):
        # Section-scoped guard: ignore anchors outside this civilian's section
        # (level-streaming may keep adjacent-section anchors in the global group registry —
        #  level-designer 2026-04-25 finding; godot-specialist Issue 7).
        if not _is_anchor_in_my_section(anchor):
            continue
        var to_anchor: Vector3 = (anchor.global_position - global_position).normalized()
        if away_dir.dot(to_anchor) < ANCHOR_OPPOSITE_DOT_THRESHOLD:
            continue  # anchor is between civilian and cause — skip
        var snapped: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, anchor.global_position)
        if snapped.distance_to(anchor.global_position) > ANCHOR_NAV_SNAP_TOLERANCE_M:
            continue  # anchor not on NavMesh — skip
        var d: float = global_position.distance_to(anchor.global_position)
        if d < best_score:
            best_score = d
            best_anchor = anchor
            best_anchor_snapped = snapped  # store SNAPPED point for nav target (not raw anchor pos)
    if best_anchor != null:
        # Use SNAPPED point as nav target, NOT raw anchor.global_position — anchors authored up
        # to ANCHOR_NAV_SNAP_TOLERANCE_M off-mesh would otherwise produce off-NavMesh nav targets
        # and immediate is_navigation_finished() → cower-in-place (systems-designer HIGH-2 finding 2026-04-25).
        nav_agent.set_target_position(best_anchor_snapped)
        _fleeing_mode = FleeMode.FLEEING_TO_ANCHOR
        return

    # Phase 3 — fallback: run away from cause, snapped to NavMesh
    var away_pt: Vector3 = global_position + away_dir * FLEE_FALLBACK_DISTANCE_M
    nav_agent.set_target_position(NavigationServer3D.map_get_closest_point(nav_map, away_pt))
    _fleeing_mode = FleeMode.FLEEING_AWAY


func _on_cower_exit_timer_timeout() -> void:
    # CR-3a cower-exit polling at 1 Hz while COWERING.
    if _fleeing_mode != FleeMode.COWERING:
        $CowerExitTimer.stop()  # safety: timer should have been stopped on cower exit
        return
    var cause_distance: float = _cause_position.distance_to(global_position)
    var cower_elapsed_s: float = (Time.get_ticks_msec() - _cower_started_at_msec) / 1000.0
    if cause_distance > COWER_RADIUS_M or cower_elapsed_s >= MAX_COWER_DURATION_S:
        # Threat-leave OR timeout: re-evaluate via Phase 2/3 path.
        $CowerExitTimer.stop()
        _set_flee_target(_cause_position)
        if _fleeing_mode != FleeMode.COWERING:
            # Successfully transitioned out of cower; start nav.
            set_physics_process(true)
            _animation_tree.travel("panic_flee")
        # Else: Phase 1 re-fired (still close), cower restarts; timer restarted by _set_flee_target.
```

**Authoring contract for level designer:** each section scene SHOULD contain 3-6 `Marker3D` nodes in group `panic_anchor`, placed at aesthetically valid flee destinations (behind cover, near exits, scene corners). Sections with no reachable anchor on the opposite side of any plausible cause position must validate the Phase 3 fallback works without civilians stuttering against walls — section-validation CI item (coord with MLS §C.5.6).

**Work bound:** runs exactly once per panic onset. Group iteration ≤ 6 anchors. `NavigationServer3D.map_get_closest_point` is O(1) lookup (not a path query). Total cost ~30-50 µs per civilian per panic onset.

### C.4 Witness Event Trigger Rules (VS-tier — stub at MVP)

| Event type | Trigger source | Distance check | LOS check | Latch |
|---|---|---|---|---|
| `GUNFIRE_NEARBY` | `Events.weapon_fired(_, pos, _)` | `pos.distance_to(self) ≤ WITNESS_GUNFIRE_RADIUS_M` (default 18.0 m, larger than panic radius) | None — sound, not sight | `_witnessed_event_already_emitted` (one-shot per section) |
| `GUARD_KILLED_NEARBY` | `Events.enemy_killed(actor, _)` | `actor.global_position.distance_to(self) ≤ WITNESS_BODY_RADIUS_M` (default 12.0 m) | None — signal-distance proxies for "noticed" | Same latch |
| `EVE_BRANDISHING_WEAPON` | VS-coord-item: `Events.gadget_activated` or new `Events.weapon_drawn_in_public` (Inventory coord) | `player.global_position.distance_to(self) ≤ WITNESS_BRANDISH_RADIUS_M` (default 8.0 m) | None — open-space brandishing assumption | Same latch |
| `GUARD_BODY_VISIBLE` | VS post-MVP — ambient `section_entered` proximity scan | n/a at VS-tier-1 | n/a | n/a — stub for forward-compat |

**Latch reset:** on `Events.section_entered(_, reason)` regardless of `reason` — civilians instantiated fresh on section reload have a fresh `_witnessed_event_already_emitted = false`.

**MVP behavior:** the Phase 4 emission step in §C.2 Transitions is gated `if false` (compile-time stub). No witness signal fires at MVP. Stealth AI's MVP fallback (no civilian-to-guard propagation, only guard-to-guard + PC perception) per stealth-ai.md L661.

### C.5 Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| **Player Character** | upstream (read) | At VS-tier, CAI reads `player.global_position` via `get_tree().get_first_node_in_group("player")` weakref + `is_instance_valid()` for BQA pickup-distance Area3D. NO direct PC class import. | PC owns position; CAI reads via group |
| **Combat & Damage** | upstream (subscribe) | CAI subscribes to `Events.weapon_fired` + `Events.enemy_killed`. CAI implements `receive_damage(amount, source, type)` for Combat's hitscan duck-type — panic-only no-op (CR-7). | Combat owns signal emit; CAI owns receive_damage no-op |
| **Stealth AI** | downstream (publish, VS) | At VS, CAI publishes `civilian_witnessed_event` → SAI's `ALERTED_BY_OTHER` propagation path with `CIVILIAN_PROPAGATION_BUMP = 0.5` MINOR severity. **MVP: not published; SAI's MVP fallback path active** (stealth-ai.md L661). | CAI owns publish; SAI owns subscribe + propagation |
| **Audio** | downstream (publish) | CAI publishes `civilian_panicked` → Audio Formula 2 (diegetic recedes −3 dB, non-diegetic +2 dB cap). Audio's `panic_count` rebuild on LOAD_FROM_SAVE: Audio queries `get_tree().get_nodes_in_group("civilian")` at restore + counts `panicked == true` (CR-10). | CAI owns publish; Audio owns SFX dispatch + Formula 2 |
| **Signal Bus** | upstream (infra) | ADR-0002 signatures locked: `civilian_panicked(civilian, pos)`, `civilian_witnessed_event(civilian, event_type, pos)`. CAI owns `WitnessEventType` enum (stub required for `Events.gd` compile). | Signal Bus declares; CAI owns enum |
| **Save/Load** | downstream (capture) | CAI implements `capture() -> Dictionary`. `CivilianAIState: Dictionary[StringName, Dictionary]` keyed by `actor_id`. MLS assembles SaveGame; SaveLoadService writes/reads. | MLS assembles; CAI captures own state |
| **Level Streaming** | upstream (lifecycle) | CAI calls `LevelStreamingService.register_restore_callback(_restore_state)` in `_ready()` — same pattern as Inventory + F&R + SAI. | LS owns callback registry; CAI owns its callback |
| **Mission & Level Scripting** | upstream (placement) | Level-designer authors civilian placement in section scenes (NOT spawned by MLS triggers — MLS T6 banter is separate). MLS does NOT reference CivilianAI directly (MLS subscribes to `Events`, not CAI). | MLS authors placement; CAI authors behavior |
| **Outline Pipeline** | downstream (consume) | CAI civilians render at Tier 3 LIGHT default. VS BQA contacts promote to Tier 1 HEAVIEST via `OutlineTier.set_tier(mesh_instance_3d, tier)` (NOTE: takes `MeshInstance3D`, not Node — gameplay-programmer flagged 2026-04-24). | OP owns shader + tier API; CAI owns runtime tier toggle (VS-only) |
| **Inventory & Gadgets** | forbidden non-dep | CAI MUST NOT subscribe to Inventory signals at MVP. VS-coord: `EVE_BRANDISHING_WEAPON` may need new `Events.weapon_drawn_in_public` from Inventory — coord item. | n/a at MVP |
| **Failure & Respawn** | forbidden non-dep | F&R does NOT touch civilians (F&R anti-pattern CI forbids `CivilianAI` in F&R source per AC-FR-12.1). Civilians restore via SaveGame path same as SAI/Inventory. | n/a |

### C.6 Forbidden Patterns (CI grep-enforced)

The following patterns MUST produce zero matches in any `src/gameplay/ai/civilian_*.gd` file (CI lint test, mirrors SAI/F&R/Inventory enforcement style):

1. **`Events.player_footstep`** — civilians must not subscribe (Eve's walking is not alarming; same forbid as SAI).
2. **`Events.alert_state_changed`** — at MVP only; civilians do not react to guard-state transitions. VS may add filtered subscription; flag as MVP-only forbid.
3. **Direct refs to `PlayerCharacter`, `GuardBase`, or their scene paths** — group query + weakref only; signals + bus only.
4. **`get_node("/root/...")` for any autoload other than `Events` or `LevelStreamingService`** — autoload-singleton-coupling anti-pattern.
5. **`add_to_group("player")` / `add_to_group("dead_guard")` / `add_to_group("alive_guard")`** — SAI E.14 filter integrity.
6. **HP decrement / damage emit** — civilians cannot lose health, cannot emit `player_damaged`, `enemy_damaged`, `enemy_killed`, `player_died`, `weapon_fired`, `weapon_dry_fire_click`.
7. **Bare `_process(` override** — all per-frame work uses gated `_physics_process` only (CR-9).
8. **`move_and_slide()` outside `velocity_computed` callback** — bypasses RVO avoidance (CR-8 RVO contract).
9. **`OutlineTier.set_tier(self, ...)`** (refined 2026-04-25) — must pass the `MeshInstance3D` child, not the `CharacterBody3D` node (ADR-0001 signature; gameplay-programmer 2026-04-24). Grep regex refined to `OutlineTier\.set_tier\s*\(\s*self\s*,` so it does NOT false-positive on `OutlineTier.set_tier(self.mesh_instance_3d, ...)` (godot-specialist Issue 8 finding).
10. **Bare integer collision-layer / mask values** — must use `set_collision_layer_value(PhysicsLayers.LAYER_AI, true)` etc. (ADR-0006).
11. **Missing `nav_agent.avoidance_enabled = true` init** (NEW 2026-04-25, CR-1a) — `civilian_ai.gd` MUST contain a line setting `avoidance_enabled = true` on its `NavigationAgent3D` child. CI lint inverts grep semantics (the absence of the line = FAIL). ai-programmer + godot-specialist convergent finding — without this, civilians never move.
12. **Direct `AudioServer` API usage** (NEW 2026-04-25, audio-director ADVISORY-9) — civilians must not call `AudioServer.set_bus_volume_db()`, `AudioServer.add_bus_effect()`, etc. All audio dispatch flows through Signal Bus → Audio handlers.
13. **Direct `AudioStreamPlayer(3D)?.new()` instantiation** (NEW 2026-04-25, audio-director ADVISORY-9) — civilians must not create their own audio players. Audio owns the pool.

## Formulas

### F.1 — Panic-Trigger Predicate

The panic-trigger predicate formula is defined as:

`should_panic = (_panic_state == false) AND (cause_distance <= R_panic)`

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `_panic_state` | bool | `{false, true}` | Idempotency latch; set to `true` on first CALM→PANICKED transition and never cleared within a section (CR-5). |
| `cause_distance` | float (m) | [0.0, ∞) | Euclidean distance from civilian's `global_position` to the event's `position` payload. `distance_to()` in 3D world space — includes Y. |
| `R_panic` | float (m) | `{12.0, 8.0}` | Radius constant, selected by signal source: `PANIC_GUNFIRE_RADIUS_M = 12.0` for `weapon_fired`; `PANIC_BODY_RADIUS_M = 8.0` for `enemy_killed`. Inapplicable for `receive_damage` — that path is unconditional. |
| `should_panic` | bool | `{false, true}` | Output: whether this event instance transitions the civilian CALM→PANICKED. |

**Output range:** Boolean. `true` iff both guard conditions are met simultaneously. The `receive_damage` path short-circuits F.1 entirely — it calls `_trigger_panic` unconditionally with no distance check (see CR-4 item 3). No floating-point clamping required.

**Example:** Eve fires a pistol at a guard 10 m from a waiter. `weapon_fired` emits with `position = guard.global_position`. `cause_distance = waiter.global_position.distance_to(guard.global_position) = 10.0`. `R_panic = PANIC_GUNFIRE_RADIUS_M = 12.0`. `_panic_state = false`. `should_panic = (false == false) AND (10.0 <= 12.0) = true`. Waiter panics.

**Design note on R_panic values.** Gunfire radius 12 m is deliberately wider than panic-body radius 8 m because a gunshot is audible (and disorienting) at distance, whereas a silent dart-KO body discovery requires actual proximity. The 4 m gap means silenced-weapon takedowns (dart, melee) do not scatter the restaurant unless the body is discovered close-up. This is the primary stealth-reward lever. If playtest shows civilians scattering too eagerly on dart hits, the tuning knob is `PANIC_BODY_RADIUS_M` (safe range 5.0–10.0 m per §G Tuning Knobs).

### F.2 — Flee Re-target Proximity Gate

The flee re-target proximity gate formula is defined as:

`should_retarget = (new_cause_distance < old_cause_distance)`

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `new_cause_distance` | float (m) | [0.0, ∞) | Euclidean distance from civilian's current `global_position` to the incoming event's `cause_position`. Computed at handler call time. |
| `old_cause_distance` | float (m) | [0.0, ∞) | Distance from civilian's current `global_position` to `_cause_position` (the stored cause from the original panic transition). Computed at handler call time against the same `global_position` sample. |
| `should_retarget` | bool | `{false, true}` | Output: whether the already-panicked civilian updates its stored `_cause_position` and recomputes the flee target. |

**Output range:** Boolean. Strict less-than (no hysteresis, no tie-breaking). Ties (`==`) return `false` — no retarget on equal distance. This is intentional: the first cause wins on ties, preventing oscillation when two gunshots land at the exact same distance simultaneously (unlikely in practice; deterministic on same-frame double-trigger because Godot direct signal dispatch is ordered).

**Example:** Civilian is panicked; original gunshot was 9 m away (stored `_cause_position` gives `old_cause_distance = 9.0` at current position). A second gunshot lands 6 m away. `new_cause_distance = 6.0`. `should_retarget = (6.0 < 9.0) = true`. Civilian re-runs §C.3 flee algorithm toward the opposite side of the new, closer threat. No `civilian_panicked` re-emit.

### F.3 — ADR-0008 Per-Frame Budget Sub-claim (revised 2026-04-25)

**This formula was rewritten in response to convergent specialist findings (systems-designer CRITICAL-2, ai-programmer BLOCKING-6, performance-analyst HIGH-3, godot-specialist Issue 1).** Previous version classified the panic-onset signal-handler burst as "non-frame cost analogous to save-write spikes." That framing was incorrect: Godot signal dispatch is synchronous in-frame. The honest budget model has four cost components, not one.

**Total per-frame CAI cost (panic-onset frame, worst-case):**

`C_frame_us = C_nav_us + C_burst_us + C_move_and_slide_us + C_rvo_step_us`

**Components:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `C_nav_us` | float (µs) | `N_active × c_nav_per_civ_us` | Per-physics-frame nav-feed cost: `get_next_path_position()` + `nav_agent.velocity` write. ESTIMATE — pending OQ-CAI-3 measurement gate. Default per-civilian: 20 µs (range 15-25 µs). |
| `C_burst_us` | float (µs) | `N_panic_onset × c_burst_per_civ_us` | One-frame synchronous signal dispatch cost on panic onset: `_trigger_panic` body + Audio Formula 2 handler + (VS) SAI `ALERTED_BY_OTHER` handler. **This IS frame cost** (not "non-frame"). Default per-civilian: 50 µs CAI handler + ~30 µs Audio handler = 80 µs (UNVERIFIED — Audio handler cost not yet measured; coord item §F.5#13). At 8 simultaneous: 8 × 80 = 640 µs in the panic-onset frame only. |
| `C_move_and_slide_us` | float (µs) | `N_active × c_mas_per_civ_us` | `CharacterBody3D.move_and_slide()` cost in `velocity_computed` callback. Runs in-frame (callback, not deferred). UNVERIFIED on Jolt 4.6; godot-specialist Issue 3. Estimate: 8-15 µs per civilian. |
| `C_rvo_step_us` | float (µs) | shared NavigationServer cost | RVO2 avoidance solve. O(n²) on neighbor pairs across **all** avoidance-enabled agents on the section NavMesh (civilians + Eve + guards = up to 21 agents at Restaurant worst case, NOT 8). This cost falls outside Slot #8 — it is a NavigationServer cost claimed against Slot #4 (Jolt) or a separate NavigationServer allocation in ADR-0008. UNVERIFIED. |
| `N_active` | int | [0, 8] | Civilians in PANICKED state with `_physics_process` enabled. CALM civilians and arrived-cower civilians contribute 0 µs to `C_nav_us` (but see AnimationTree note below). |
| `N_panic_onset` | int | [0, 8] | Civilians transitioning CALM → PANICKED in this frame. Non-zero only on the panic-onset frame. |

**Steady-state navigation cost (post-onset frames)**: `C_nav_us + C_move_and_slide_us` only. At 8 civilians × (20 + 12) µs = 256 µs per frame. **This already exceeds the previous claim of 0.15 ms p95.**

**Panic-onset frame worst case**: 8 civilians × (20 + 80 + 12) µs + `C_rvo_step_us` ≥ 896 µs, plus the RVO step for 21 agents which is unmeasured. **This exceeds Slot #8's 800 µs pooled residual on its own**, before MLS / DC / Dialogue / F&R / Signal-Bus-dispatch claim their share of the same frame.

**Honest binding claim (revised)**:

| Frame type | Bound | Claim |
|---|---|---|
| Steady-state (post-onset, navigating) | ~256 µs (sustained) | **Sub-claim 0.30 ms p95** of Slot #8 (revised from 0.15 ms; pending measurement) |
| Panic-onset frame | ~900-1500 µs in one frame | **Allocated against ADR-0008 §F.3 reserve** (1.6 ms hold-out for transient spikes); requires producer + technical-director sign-off and ADR-0008 amendment review |
| RVO step (21-agent Restaurant) | UNMEASURED | **Slot #4 (Jolt / NavigationServer)**, not Slot #8 |

**ADR-0008 amendment status**: This budget revision does NOT bypass or amend ADR-0008. It surfaces that the original 0.15 ms claim was based on incomplete decomposition. Producer-tracked coord item §F.5#2 is now amended: register **0.30 ms p95 sub-claim** in `docs/registry/architecture.yaml` performance_budgets, with explicit footnote that the panic-onset spike is allocated against the ADR-0008 reserve and requires an amendment review session before MVP sprint can confidently cite the budget. **BLOCKING for sprint start** (carried from original §F.5#2; severity unchanged but math is more honest).

**Validation gate (carried from OQ-CAI-3 + new dependency)**:

1. `c_nav_per_civ_us`, `c_burst_per_civ_us`, `c_mas_per_civ_us`: measured on Iris Xe Gen 12 reference hardware via `tests/reference_scenes/restaurant_dense_interior.tscn` (ADR-0008 future story; not yet created).
2. Audio handler cost on `civilian_panicked` emission: measured by audio-director against the same scene (coord item §F.5#13).
3. RVO step cost at 21-agent Restaurant population: profiled with all civilians + Eve + 12 guards present.
4. AC-CAI-7.1 reclassified to `[Integration]` and uses the constrained-NavMesh reference scene, not an open plane.

**Example (revised)**: Restaurant section, gunshot at 10 m, 7 of 8 civilians within 12 m all panic simultaneously.

- **Panic-onset frame (frame 1)**: `N_panic_onset = 7`, `N_active = 7`. Cost = `7 × 20 (nav) + 7 × 80 (burst) + 7 × 12 (mas) = 140 + 560 + 84 = 784 µs` (excluding RVO step). This is allocated to the ADR-0008 reserve.
- **Frame 2 onward (steady-state navigation)**: `N_panic_onset = 0`, `N_active = 7`. Cost = `7 × 20 + 7 × 12 = 224 µs` per frame. Within revised 0.30 ms p95 sub-claim.
- **By frame 180 (~3 s)**: first 2 civilians arrived, `N_active = 5`. Cost = `5 × 32 = 160 µs` per frame.

**Note on AnimationTree `_process` cost** (performance-analyst MEDIUM finding 2026-04-25): `AnimationTree` updates on `_process`, NOT `_physics_process`. The `set_physics_process(false)` gate on CALM / arrived civilians does NOT silence AnimationTree. Per-frame AnimationTree cost for 8 civilians at idle is unmeasured but non-zero. If profiling shows >10 µs per AnimationTree per frame in CALM, gate via `set_process(false)` on the AnimationTree node specifically (not the civilian root), or use blend tree LOD. **Coord item §F.5#14**: measure CALM AnimationTree cost in the same OQ-CAI-3 gate.

### F.4 — Flee Anchor Score and Selection

The flee anchor selection formula is defined as:

`best_anchor = argmin_{a ∈ A_valid} distance(self, a)`

where the valid anchor set is:

`A_valid = { a ∈ A_all | dot(away_dir, normalize(a.pos - self.pos)) >= D_threshold AND snap_dist(a) <= T_snap }`

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `A_all` | Node3D set | [0, ∞) nodes | All `Marker3D` nodes in the `"panic_anchor"` group in the current section scene. Authoring contract: 3-6 nodes recommended per section. |
| `away_dir` | Vector3 (unit) | length = 1.0 | Direction vector from `cause_pos` to `self.global_position`, normalized. Points "away from the threat." |
| `a.pos` | Vector3 (m) | world space | World position of candidate anchor `a`. |
| `D_threshold` | float | [-1.0, 1.0]; default 0.3 | Dot-product filter: `away_dir · normalize(a.pos - self.pos) >= D_threshold`. Discards anchors "between civilian and cause." `0.3 ≈ cos(72°)` — the anchor must be within a 144° forward arc away from the threat. |
| `T_snap` | float (m) | [0.0, ∞); default 1.0 | Maximum acceptable distance from anchor's world position to nearest NavMesh point (`NavigationServer3D.map_get_closest_point`). Anchors farther than `T_snap` from NavMesh are invalid. |
| `distance(self, a)` | float (m) | [0.0, ∞) | Euclidean distance from civilian to anchor `a`. Selection criterion: smallest distance among valid anchors. |
| `best_anchor` | Node3D or null | nullable | Output: the valid anchor with minimum distance. `null` if `A_valid` is empty — triggers Phase 3 fallback. |

**Output range:** A single `Node3D` reference (or `null`). Not a numeric output — the formula is a selection predicate, not a continuous function. The implicit numeric output is `best_score ∈ [0.0, ∞)` (meters), minimized over `A_valid`. Null output triggers the Phase 3 fallback: `away_pt = self.pos + away_dir × FLEE_FALLBACK_DISTANCE_M (15.0 m)`, snapped to NavMesh.

**Example:** Civilian at (0,0,0). Gunshot at (10,0,0). `away_dir = (-1,0,0)`. Three anchors: A1 at (-8,0,3), A2 at (5,0,5) (behind cause direction), A3 at (-4,0,-2). `D_threshold = 0.3`.

- A1: `to_anchor = normalize((-8,0,3)) ≈ (-0.936, 0, 0.351)`. `dot = (-1)(-0.936) + 0 + 0 = 0.936 >= 0.3` ✓. NavMesh snap ≤ 1.0 m ✓. Distance = 8.54 m.
- A2: `to_anchor = normalize((5,0,5)) ≈ (0.707, 0, 0.707)`. `dot = (-1)(0.707) = -0.707 < 0.3` ✗ — discarded.
- A3: `to_anchor = normalize((-4,0,-2)) ≈ (-0.894, 0, -0.447)`. `dot = (-1)(-0.894) = 0.894 >= 0.3` ✓. NavMesh snap ≤ 1.0 m ✓. Distance = 4.47 m.

`best_anchor = A3` (4.47 m < 8.54 m). Civilian flees to A3.

**Decision point — `D_threshold = 0.3`.** This is the main authoring lever. Lower values (e.g., 0.0) accept anchors at 90° from away direction — more available targets, but civilians may flee sideways rather than away. Higher values (e.g., 0.5 ≈ cos(60°)) enforce a tighter "away" cone — fewer valid anchors, more Phase 3 fallback. 0.3 (≈72°) strikes a balance that allows 144° of "away" arc while filtering the clear "toward the threat" half. If playtest finds civilians fleeing awkwardly sideways in tight sections, increase to 0.4–0.5.

### F.5 — Witness Emission Distance Gate (VS-tier)

The witness emission distance gate formula is defined as:

`should_emit_witness = (_witnessed_event_already_emitted == false) AND (event_distance <= R_witness)`

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `_witnessed_event_already_emitted` | bool | `{false, true}` | One-shot latch per civilian per section. Set `true` on first successful `civilian_witnessed_event` emit. Never cleared within a section; resets to `false` at section load (CR-12). |
| `event_distance` | float (m) | [0.0, ∞) | Euclidean distance from civilian's `global_position` to the event-source position (signal payload `position` or `actor.global_position` depending on event type). |
| `R_witness` | float (m) | see table | Per-event-type witness radius constant. See table below. |
| `should_emit_witness` | bool | `{false, true}` | Output: whether the civilian emits `civilian_witnessed_event` for this event instance. |

**Per-event-type radius values:**

| Event type | Constant name | Default (m) | Rationale |
|---|---|---|---|
| `GUNFIRE_NEARBY` | `WITNESS_GUNFIRE_RADIUS_M` | 18.0 | Larger than panic radius (12.0) — sound carries; a civilian who doesn't panic can still witness |
| `GUARD_KILLED_NEARBY` | `WITNESS_BODY_RADIUS_M` | 12.0 | Equals panic radius — body discovery is visual-proximity |
| `EVE_BRANDISHING_WEAPON` | `WITNESS_BRANDISH_RADIUS_M` | 8.0 | Tight personal-space radius — open carrying only alarming when close |

**Output range:** Boolean. `true` requires both conditions simultaneously. The latch condition is checked FIRST (short-circuit) — if already emitted, no distance computation occurs. Once emitted, the civilian contributes no further signal traffic regardless of subsequent events, capping the per-civilian VS-tier signal budget at exactly 1 `civilian_witnessed_event` emission per section.

**Downstream constraint (not owned by CAI).** Stealth AI consumes this signal with `CIVILIAN_PROPAGATION_BUMP = 0.5` (`ALERTED_BY_OTHER` MINOR). SAI owns that constant — CAI's formula does not parameterize it. Audio GDD Formula 2 diegetic/non-diegetic caps are not affected by `civilian_witnessed_event` (Audio subscribes to `civilian_panicked` only).

**Example (VS scope).** Civilian at (0,0,0). Gunshot at (15,0,0). `event_distance = 15.0`. `WITNESS_GUNFIRE_RADIUS_M = 18.0`. `_witnessed_event_already_emitted = false`. `should_emit_witness = (false == false) AND (15.0 <= 18.0) = true`. Civilian emits `civilian_witnessed_event(self, GUNFIRE_NEARBY, (15,0,0))`. Latch set. Nearby guard drifts to check (SAI handles propagation at MINOR severity). Second gunshot at 10 m, same civilian: latch is `true` → `should_emit_witness = false`. No second emission. (See OQ-CAI-1 in §Open Questions for the latch-vs-closer-threat trade-off.)

## Edge Cases

Edge cases are organized into 8 clusters mirroring the SAI / F&R / Inventory pattern.

### Cluster A — Same-frame signal storms

- **E.1 Same-frame `weapon_fired` AND `enemy_killed` both within radius:** civilian emits `Events.civilian_panicked` exactly **once** (CR-5 latch). The first handler (whichever Godot dispatches first per signal-connection order) sets `_panic_state = true`, emits, sets `_cause_position` to its own payload. The second handler's CR-5 latch check fails → `_maybe_retarget_flee` runs F.2; if the second cause is closer, flee target updates without signal re-emission. Audio's `panic_count` increments once.
- **E.2 Same-frame `weapon_fired` arrives at 6 civilians simultaneously (Restaurant gunshot):** all 6 emit `civilian_panicked` in the same frame, triggering 6 `panic_count` increments on Audio. Audio Formula 2 caps at −3 dB diegetic / +2 dB non-diegetic (Audio's hard caps). No CAI-side issue. Performance: the 6 × ~50 µs signal-handler burst = 300 µs spike fits within the non-frame budget.
- **E.3 `receive_damage` AND `weapon_fired` same frame for the same civilian:** Combat's hitscan handler calls `receive_damage` directly THEN emits `weapon_fired`. CAI's `receive_damage` runs first → latch set. The subsequent `weapon_fired` handler hits the latch → no double-emit. `cause_position` is the source actor (the shooter), not the bullet origin. Acceptable.
- **E.4 Civilian emits `civilian_panicked` mid-Audio-handler:** subscriber re-entrancy is forbidden by ADR-0002 Rule 4 — Audio's handler must not emit a CAI-domain signal back. The shallow one-hop chain (CAI emit → Audio subscriber dispatch) does not require the F&R-style signal-isolation engine-verification gate (gameplay-programmer 2026-04-25 finding; no OQ).

### Cluster B — Damage / friendly-fire edge cases

- **E.5 Eve fires at a guard but hits a civilian standing in front (intentional or stray):** the civilian's `receive_damage` no-op fires (CR-7); civilian transitions to PANICKED with `cause_position = Eve.global_position`. NO `enemy_killed` emitted (civilian is not an enemy). NO HP decrement. NO WorldItem spawn (Inventory CR-7a `carried_weapon_id == none`). The bullet IS consumed (CharacterBody3D blocks); the guard behind the civilian does NOT take damage from the same shot (single-collision physics).
- **E.6 Guard A's friendly-fire hits a civilian (Combat E.29 cross-case):** same as E.5 — civilian's `receive_damage(amount, guard_A, type)` fires; `cause_position = guard_A.global_position` (validated). Civilian flees the guard, not Eve. Guard A receives no Mission-Scripting kill credit (intentional per Combat CR-13). MLS sees no kill event.
- **E.7 Civilian hit by Combat dart (DART_TRANQUILISER damage type):** civilian's `receive_damage` no-op fires per CR-7. Civilian does NOT enter UNCONSCIOUS (UNCONSCIOUS is SAI-state, not CAI-state). Civilian transitions to PANICKED. Dart is consumed. This is acceptable behavior — there is no anti-griefing concern because civilians cannot be farmed (CR-7 no-HP).
- **E.8 Civilian hit by Combat `MELEE_PARFUM` (Inventory parfum gadget on a civilian):** Inventory CR-15 routes parfum through `MELEE_PARFUM` damage type. CAI's `receive_damage` fires regardless of type — civilian flees. NO sedative effect (CAI ignores `type` parameter per CR-7). NO `guard_incapacitated` emit (civilian is not a guard). Parfum charge IS consumed (Inventory's concern; CAI does not refund). Documented as intentional — players who waste parfum on civilians lose the charge.
- **E.9 Civilian dies from `MELEE_PARFUM` at point-blank range:** **Cannot occur** — CR-7 forbids HP decrement; parfum has no kill path against civilians regardless of stack-up. CI-enforced via forbidden-pattern grep #6 (no HP decrement).

### Cluster C — Save / Load round-trip

- **E.10 Save mid-flee, civilian at 50% of flee path; LOAD_FROM_SAVE:** restored civilian reads `{ panicked: true, cause: Vector3 }`. CR-10 recomputes flee target via §C.3 against the saved `_cause_position` and current section NavMesh. `set_physics_process(true)` re-enabled. Civilian resumes navigating. **No `civilian_panicked` re-emit.** Audio rebuilds `panic_count` at section-load via group query of `get_tree().get_nodes_in_group("civilian")` filtered to `panicked == true`. Flee target may differ from the original target (NavMesh-snap deterministic against the same `panic_anchor` set, but the civilian's restored position may differ if Save captured them mid-stride — the algorithm picks fresh anchor by current position).
- **E.11 LOAD_FROM_SAVE during MLS LOAD_FROM_SAVE phase, before LevelStreamingService.register_restore_callback fires:** CAI's `_ready()` registers callbacks BEFORE LSS's restore phase (autoload load order via ADR-0007; CAI is per-scene, registers on scene-instantiation which happens before section_entered). The restore callback fires AFTER all callbacks are registered — race-free.
- **E.12 Save with 0 panicked civilians, LOAD_FROM_SAVE:** `CivilianAIState` dict has all entries with `panicked: false`. Each civilian's `_restore_state` reads `false`, no transition occurs. `_physics_process` stays disabled (CALM idle). Audio's restore-time group query counts 0 panicked → `panic_count = 0`. Default music state (no Formula 2 ducking).
- **E.13 Save with 8 panicked civilians (Restaurant worst case), LOAD_FROM_SAVE:** all 8 restore to PANICKED, all 8 recompute flee targets in `_restore_state`. The 8 × ~30-50 µs flee-target computes = ~400 µs one-frame spike during MLS's LOAD_FROM_SAVE phase. Within MLS's `t_assemble_total_ceiling_ms = 5.0` budget (well below). No `civilian_panicked` re-emits → Audio's group-query rebuild produces `panic_count = 8` → Formula 2 caps at −3 dB / +2 dB.
- **E.14 LOAD_FROM_SAVE reads `actor_id` not present in current section scene (save from older section authoring):** the dict entry is silently ignored. CAI civilians in the current scene without a corresponding dict entry stay CALM (default state). Save schema is forward-compatible; missing entries treated as CALM. (Mirrors Inventory's WorldItem orphan-restore policy.)
- **E.15 LOAD_FROM_SAVE reads `actor_id` for a civilian that was deleted from the scene authoring:** orphan dict entry — silently ignored at restore. Save serialization on next save will not include the orphaned entry (only present civilians serialize).

### Cluster D — Stealth AI interaction corner cases

- **E.16 Guard with full vision cone "looks at" a civilian:** SAI's E.14 group filter rejects the civilian via `is_in_group("player") OR is_in_group("dead_guard")` check + `body is PlayerCharacter|GuardBase` typed-class check. Civilian is invisible to guard vision. Forbidden pattern: a civilian mistakenly added to `alive_guard` group at scene-author time would NOT be seen either (typed-class check rejects). Belt-and-braces.
- **E.17 Civilian fleeing past a guard's vision cone:** SAI's perception flow rejects the civilian (E.16). Guard does not detect the civilian visually. Civilian IS visible in physics (LAYER_AI collision blocks the guard pathing) — guard may need to re-path around fleeing civilian. NavigationAgent3D RVO handles the cross-traffic case.
- **E.18 Two civilians flee toward the same `panic_anchor`:** RVO2 avoidance (`nav_agent.avoidance_enabled = true`) computes safe velocities so they don't collide. Both arrive sequentially; the second civilian's cower position is offset by RVO. Acceptable — chorus-role tolerates clustering.
- **E.19 At VS scope: civilian witnesses gunfire, emits `civilian_witnessed_event`, but the nearest guard is in COMBAT state:** SAI's `ALERTED_BY_OTHER` propagation is gated on the receiving guard's state — guards in COMBAT do not re-process a MINOR `ALERTED_BY_OTHER` cause (SAI severity rule). The signal is silently absorbed. CAI-side: no special handling needed.
- **E.20 At VS scope: civilian witnesses Eve brandish weapon, but Eve's weapon is the silenced pistol with the silencer (still visible model):** `EVE_BRANDISHING_WEAPON` event fires per F.5 distance gate. Trigger source is whatever Inventory signal indicates "weapon is visibly drawn" (coord item — `Events.gadget_activated` or new `Events.weapon_drawn_in_public`). The dart gun + silenced pistol BOTH count as "brandishing" at VS — the silencer visual does not exempt the gun from civilian witness.

### Cluster E — Audio interaction corner cases

- **E.21 Civilian panics during music transition (e.g., guard becoming SUSPICIOUS at the same physics frame):** Audio's signal handlers run independently — `alert_state_changed` triggers music transition; `civilian_panicked` triggers Formula 2 ducking. Both apply to the same target volume. Audio's §Concurrency Policies handle the interleaving (audio.md §Concurrency); CAI emits and steps away.
- **E.22 Audio's `panic_count` rebuild on LOAD_FROM_SAVE: group query returns 0 nodes:** if the section has no civilians at all (e.g., Plaza Tier 0 prototype with civilians stripped for testing), `get_tree().get_nodes_in_group("civilian")` returns `[]`. `panic_count = 0`. No Formula 2 ducking. Acceptable.
- **E.23 Civilian `_exit_tree` during LOAD_FROM_SAVE before group query:** transitional case during section unload → reload. Audio's group query runs at the current `section_entered` boundary, not during unload. Civilians from the OLD section have been freed; civilians from the NEW section have been instantiated and added to the `civilian` group via `.tscn` registration (gameplay-programmer 2026-04-25 confirmed automatic). Group query is safe.

### Cluster F — NavigationAgent3D edge cases

- **E.24 No `panic_anchor` Marker3D nodes in section (level-designer authoring miss):** F.4 returns null. §C.3 Phase 3 fallback: `away_pt = self.pos + away_dir × 15.0 m`, NavMesh-snapped. Civilian flees in a straight away-direction. Quality of flee is degraded but functional. Section-validation CI item: warn (not fail) on sections with zero `panic_anchor` nodes (coord with MLS §C.5.6).
- **E.25 All `panic_anchor` nodes between civilian and cause (every dot-product fails):** `A_valid = ∅`. Phase 3 fallback fires. Same as E.24.
- **E.26 `NavigationAgent3D.is_target_reachable() == false` (computed flee target is on a NavMesh island disconnected from civilian's current island):** Godot 4.6's NavigationAgent3D will report `navigation_finished = true` immediately without moving. Civilian transitions to cower-idle in place. Acceptable failure mode — civilian has tried to flee, no path exists, they freeze. NOT a crash.
- **E.27 Civilian is on NavMesh, flee target snapped to NavMesh, but path requires going AROUND the cause to reach the anchor:** RVO + NavMesh path wrap may briefly route the civilian past the cause position. Acceptable for MVP — chorus role is forgiving of imperfect flee paths. Polish-tier improvement: F.4 could weight by path-distance not Euclidean-distance, but that's a NavServer query per anchor (more expensive). OQ-CAI-2.
- **E.28 NavigationAgent3D arrives at anchor but `is_navigation_finished()` does not fire (Godot 4.6 lag):** if reaching `target_desired_distance` but `is_navigation_finished()` lags by 1-2 frames, civilian stutters in place. Mitigation: check `nav_agent.is_target_reached()` (alternative method) or add a fallback `_distance_to_target() <= 0.1` short-circuit. Implementation-side detail — flag as engine-verification gate (OQ-CAI-3).

### Cluster G — Section reload edge cases

- **E.29 Section reload via FORWARD transition (FORWARD reason):** new civilians instantiated fresh from section.tscn; `_panic_state = false` default; `_witnessed_event_already_emitted = false` default. CR-12 latch is reset by section instantiation. Audio's `panic_count` resets to 0 (Audio's `section_entered` subscription handles it).
- **E.30 Section reload via RESPAWN transition (F&R reload):** civilians restored from SaveGame snapshot at last checkpoint. Per CR-10: restored panicked civilians recompute flee target. **No `civilian_panicked` re-emit.** Restored cower-arrived civilians re-enter cower (`set_physics_process` stays false). F&R's anti-pattern grep forbids `CivilianAI` references in F&R source (AC-FR-12.1) — F&R does not directly touch CAI; the RESPAWN path uses the same SaveGame restore flow as LOAD_FROM_SAVE.

### Cluster H — VS-tier scope boundary

- **E.31 At MVP, an inadvertent emit of `civilian_witnessed_event` (e.g., from a debug script):** SAI's MVP fallback (stealth-ai.md L661) is "no civilian-to-guard propagation, only guard-to-guard + PC perception until Civilian AI lands." If a stray emission occurs at MVP, SAI's subscriber WILL react (`ALERTED_BY_OTHER` propagation runs unconditionally — SAI does not gate on a "CAI is VS-only" feature flag). This is a contract violation for MVP. **Mitigation: CR-12 is gated `if VS_FEATURE_ENABLED:` at compile time via project setting; MVP builds compile out the emit path entirely.** OQ-CAI-4 captures the feature-flag mechanism.

## Dependencies

### F.1 Upstream Dependencies (this system depends on)

| Upstream system | Status | Hard / Soft | Interface |
|---|---|---|---|
| **Player Character** | Approved 2026-04-21 | Hard (VS only) | At VS-tier, CAI reads `player.global_position` via `get_tree().get_first_node_in_group("player")` weakref + `is_instance_valid()` for the BQA pickup-distance Area3D. CAI does NOT import `PlayerCharacter` class. **MVP: PC is not a runtime dependency** — civilians don't need Eve's position at MVP (panic triggers fire from signal payloads, not Eve queries). |
| **Audio** | Approved 2026-04-21 | Soft (downstream consumer; CAI publishes to it) | Audio subscribes to `Events.civilian_panicked` and runs Formula 2 (diegetic recedes −3 dB cap, non-diegetic +2 dB cap, `panic_count` increment). Audio also queries `get_tree().get_nodes_in_group("civilian")` at LOAD_FROM_SAVE to rebuild `panic_count` (CR-10). Listed here because Audio's spec is **load-bearing for the Player Fantasy** (the music recoil IS the felt fantasy). |
| **Signal Bus** | Revised 2026-04-20 (pending re-review) | Hard | ADR-0002 declares both CAI signals: `civilian_panicked(civilian: Node, cause_position: Vector3)` and `civilian_witnessed_event(civilian: Node, event_type: CivilianAI.WitnessEventType, position: Vector3)`. CAI owns the `WitnessEventType` enum (stub required for `Events.gd` compile per ADR-0002 atomic-commit rule). |
| **Combat & Damage** | Approved 2026-04-22 | Hard | CAI subscribes to `Events.weapon_fired(shooter, position, noise_radius_m)` and `Events.enemy_killed(actor, killer)` (Combat domain per ADR-0002). CAI implements the duck-typed `receive_damage(amount, source, type)` no-op for Combat's hitscan/dart hit dispatch (CR-7). |
| **Stealth AI** | Approved 2026-04-22 | Soft (downstream consumer at VS) | At VS, SAI subscribes to `civilian_witnessed_event` and runs `ALERTED_BY_OTHER` propagation with `CIVILIAN_PROPAGATION_BUMP = 0.5` MINOR severity. SAI's E.14 group filter (already in stealth-ai.md L51) keeps civilians invisible to guard vision — this constraint is enforced on the SAI side, but CAI must respect the inverse contract (no `player`/`dead_guard`/`alive_guard` group membership; CR-1). |
| **Save / Load** | Revised 2026-04-20 (pending re-review) | Hard | `CivilianAIState: Dictionary[StringName, Dictionary]` keyed by `actor_id` (per ADR-0003 schema). Already declared in save-load.md L104 + L157 ("Passive contributor (MVP scope: stub — panic state only); per-civilian panic flag keyed by `actor_id`"). |
| **Level Streaming** | Approved 2026-04-21 | Hard | CAI calls `LevelStreamingService.register_restore_callback(_restore_state)` in `_ready()` — same pattern as Inventory + F&R + SAI. Level Streaming's `TransitionReason` enum (FORWARD / RESPAWN / NEW_GAME / LOAD_FROM_SAVE) drives latch reset (CR-12 + E.29). |
| **Mission & Level Scripting** | Approved 2026-04-24 | Soft (placement authoring only) | Level designer authors civilian placement in section scenes. MLS does NOT reference CAI directly (MLS subscribes to `Events`, not CAI). MLS T6 Alert-State Comedy banter is separate from CAI panic — banter NPCs may be implemented as plain `CharacterBody3D` without `CivilianAI` script if they never panic. |

### F.2 Downstream Dependencies (systems that depend on this one)

| Downstream system | Status | Interface obligation on CAI |
|---|---|---|
| **Audio** | Approved | Civilians MUST emit `civilian_panicked` exactly once per civilian per section (idempotency latch CR-5); MUST NOT re-emit on LOAD_FROM_SAVE (CR-10 — Audio rebuilds via group query). |
| **Stealth AI** (VS only) | Approved | At VS, civilians MUST emit `civilian_witnessed_event` with `CivilianAI.WitnessEventType` enum values; the latch MUST be one-shot per civilian per section (F.5). At MVP, civilians MUST NOT emit this signal (E.31 forbids stray emissions; CR-12 compile-flag gates the path). |
| **Mission & Level Scripting** | Approved | MLS's SaveGame assembly reads `CivilianAIState` from civilians — CAI must implement `capture()` returning a serializable `Dictionary` per CR-10. MLS does NOT directly reference CivilianAI (subscribes to `Events`). |
| **Outline Pipeline** | Revised (pending re-review) | At VS, BQA contacts call `OutlineTier.set_tier(mesh_instance_3d, OutlineTier.HEAVIEST)` on Area3D `body_entered` (CR-14). Outline Pipeline owns the tier-set runtime API — CAI consumes it. |
| **Save / Load** | Revised (pending re-review) | CAI's `capture()` output is included in MLS's SaveGame. Save/Load itself is the substrate; the schema is owned by ADR-0003 + the Save/Load GDD. CAI's contract: produce a flat `Dictionary[StringName, Dictionary]` keyed by stable `actor_id`. |
| **Failure & Respawn** | Approved pending coord | F&R's anti-pattern CI lint (AC-FR-12.1) forbids direct `CivilianAI` references in F&R source. CAI must not depend on F&R either — RESPAWN path uses SaveGame restore (already covered by E.30). |
| **HUD State Signaling** (VS) | Not Started | If HUD State Signaling adds a "civilians panicking" indicator at VS-tier, it subscribes to `civilian_panicked` independently. CAI does not need to know about HUD. |

### F.3 ADR Dependencies

| ADR | Status | What CAI consumes |
|---|---|---|
| **ADR-0001 Stencil ID Contract** | Proposed | Civilians = Tier 3 LIGHT (1.5 px) default. VS BQA contacts promote to Tier 1 HEAVIEST (4 px) via `OutlineTier.set_tier(mesh_instance_3d, ...)` (CR-14). **Note**: gameplay-programmer flagged 2026-04-25 — `set_tier` takes a `MeshInstance3D`, not the parent Node. Forbidden pattern grep #9. |
| **ADR-0002 Signal Bus + Event Taxonomy** | Proposed (with amendment queue) | 2 signal signatures locked; CAI owns `CivilianAI.WitnessEventType` enum (stub required for `Events.gd` compile). |
| **ADR-0003 Save Format Contract** | Proposed | `actor_id: StringName` per civilian (CR-2); `civilian_ai: CivilianAIState` field on SaveGame per ADR-0003 L149. |
| **ADR-0006 Collision Layer Contract** | Proposed | Civilians on `LAYER_AI = 3` (ADR-0006 L158); mask = `MASK_WORLD` only. Use `set_collision_layer_value(PhysicsLayers.LAYER_AI, true)` not bare ints (forbidden pattern grep #10). |
| **ADR-0007 Autoload Load Order Registry** | Accepted (with amendment queue) | **No autoload slot for CAI** — per-actor scene pattern. ADR-0007 L211-212 explicitly anticipated CAI proposing an autoload; this GDD declines (per-scene mirrors SAI). No coord item needed for ADR-0007. |
| **ADR-0008 Performance Budget Distribution** | Proposed | CAI claims **0.30 ms p95** of Slot #8 pooled residual (0.8 ms shared across 6 systems — F.3 + CR-9). Revised 2026-04-25 from 0.15 ms after honest 4-component decomposition (the original under-counted `C_move_and_slide` + `C_burst` + `C_rvo_step`). Panic-onset spike (~896 µs at 8-civilian Restaurant) is allocated against ADR-0008's reserve carve-out (registered 2026-04-28 amendment — up to 0.6 ms of the 1.6 ms global reserve pre-allocated for `civilian_panicked` ≥ 4 emissions in a single physics frame; producer + technical-director sign-off required to invoke). |

### F.4 Forbidden Non-Dependencies

| System | Why CAI must NOT depend on it |
|---|---|
| **PlayerCharacter (class import)** | Even at VS for BQA contacts, CAI uses `get_tree().get_first_node_in_group("player")` weakref — never imports the class. Forbidden pattern grep #3 (CR-15). |
| **GuardBase / StealthAI (class import)** | Civilians are invisible to guards via SAI's E.14 group filter. CAI does not directly query guard state; it subscribes to `Events.alert_state_changed` only at VS, and MVP forbids that subscription entirely (CR-15.2). |
| **Inventory & Gadgets** | At MVP, CAI does NOT subscribe to Inventory signals. VS-coord: `EVE_BRANDISHING_WEAPON` may need a new `Events.weapon_drawn_in_public` signal from Inventory (coord item §F.5). |
| **Failure & Respawn** | F&R does NOT touch civilians (AC-FR-12.1 anti-pattern grep). Civilians restore via SaveGame, same path as LOAD_FROM_SAVE (E.30). |
| **Mission & Level Scripting (direct ref)** | MLS subscribes to `Events`, not CAI. MLS authors civilian PLACEMENT (level designer); CAI authors civilian BEHAVIOR. |
| **Cutscenes & Mission Cards** | VS narrative system; CAI does not depend on it. Civilians do not participate in cutscenes (cutscenes pause CAI per Cutscene-pause contract, future GDD). |
| **HUD Core / HUD State Signaling** | UI is downstream of CAI; CAI does not query HUD. |
| **`player_footstep` signal** | Eve's walking is not alarming — SAI shares this forbid. Forbidden pattern grep #1 (CR-15). |

### F.5 Pre-Implementation Coordination Items

1. **ADR-0002 amendment — `CivilianAI.WitnessEventType` enum stub**: ADR-0002 already references this enum (line 469); the enum body needs to land in `src/gameplay/ai/civilian_ai.gd` with at minimum the 4 values from CR-13 before `Events.gd` compiles. **BLOCKING for MVP sprint** (atomic-commit per ADR-0002).
2. **ADR-0008 amendment — 0.30 ms Slot #8 sub-claim + reserve carve-out**: registers CAI's sub-claim at 0.30 ms p95 (revised 2026-04-25 from 0.15 ms) in `docs/registry/architecture.yaml` performance_budgets, plus the 2026-04-28 reserve carve-out (up to 0.6 ms of 1.6 ms global reserve for panic-onset frames). **PARTIALLY CLOSED 2026-04-28** by ADR-0008 amendment §Risks new row + §Negative sub-claim enumeration; full sub-claim registration in `docs/registry/architecture.yaml` still BLOCKING for sprint start (producer-tracked).
3. **Audio GDD touch-up (advisory)**: Audio §Concurrency Policies Rule 5 references "civilian de-panic" but no de-panic signal exists at MVP (terminal panic). Audio author should add a sentence: "MVP scope: terminal panic = no de-panic at runtime; Rule 5 is forward-compatible dead code until VS introduces CALMED state." **ADVISORY** — Audio Rule 5 functions correctly at MVP (just never fires).
4. **Signal Bus GDD touch-up — civilian-domain handler-table row**: signal-bus.md L122 already lists the Civilian domain row; verify post-this-GDD that the publisher-subscriber matrix is consistent (CAI publishes Civilian; subscribes to AI/Stealth + Combat per signal-bus.md L79). **ADVISORY**.
5. **ADR-0001 status (Proposed → Accepted)**: BQA contact outline-tier promotion (CR-14) is enforceable only when ADR-0001 reaches Accepted. **BLOCKING for VS sprint, NOT MVP** (MVP doesn't promote; all civilians stay Tier 3).
6. **Inventory & Gadgets coord — VS-tier `weapon_drawn_in_public` signal**: F.5 `EVE_BRANDISHING_WEAPON` needs an Inventory-domain signal indicating "weapon is visibly drawn in a public space." Either a new signal (`Events.weapon_drawn_in_public(...)`) or repurpose `Events.gadget_activated` filtered by gadget type. **BLOCKING for VS sprint, NOT MVP**.
7. **Outline Pipeline / MLS GDD touch-up — civilian outline tier reconciliation**: OP GDD L112 says "Civilian AI (15) | Paris civilians | Tier 3 (light). BQA contact in Plaza: Tier 1 at pickup distance only." MLS GDD L679 originally contradicted this with "Guards and civilians (including per-variant uniforms per CR-19): **Medium tier**." OP authoritative per ADR-0001. **✅ CLOSED 2026-04-27** — `/consistency-check` edited MLS L679-680 to split "Guards: Medium tier (2)" from "Civilians: Light tier (3) by default; Heaviest tier (1) at BQA pickup distance only per CR-14." OP ADR-0001 authoritative. CivilianAI authoritative for Civilians' tier mapping.
8. **Save/Load GDD coord — `CivilianAIState` schema**: save-load.md L104 + L157 already declare the shape; verify the `cause: Vector3` field added by CR-10 (user-adjudicated 2026-04-24 — recompute flee on restore) is included in the schema. **ADVISORY** — Save/Load schema is dictionary-typed so the addition is forward-compatible without an ADR-0003 amendment.
9. **Level designer authoring contract — `panic_anchor` group**: §C.3 algorithm depends on level-designers placing 3-6 `Marker3D` nodes per section in group `panic_anchor`. Section-validation CI item (warn, not fail, on zero anchors). Coordinate with MLS §C.5.6 section-authoring contract. **ADVISORY**.
10. **Stealth AI GDD OQ-SAI-1 closure**: SAI OQ-SAI-1 reads "Guard-to-civilian propagation bidirectional? (Does a panicking civilian cascade-alert multiple guards?) Deferred to Civilian AI GDD + playtest." This GDD's answer: at VS, `civilian_witnessed_event` propagates to ALL guards within their own perception radius (SAI handles propagation; CAI emits once). Bidirectional cascade is allowed because each civilian's witness latch is one-shot (F.5). **CLOSED 2026-04-25 by this GDD** — coord item to update SAI's OQ-SAI-1 to "Closed by civilian-ai.md F.5 + CR-12."

### F.6 Bidirectional Consistency Check

| Other GDD | What that GDD says about CAI | Consistent with this GDD? |
|---|---|---|
| Audio (audio.md L26, L66, L203-208, L286-313, L514-515, L658-659) | Audio subscribes to `civilian_panicked` (Formula 2 — diegetic recedes / non-diegetic holds) + `civilian_witnessed_event` (crowd murmur uptick) | ✅ Consistent. CAI publishes both per ADR-0002 signatures. Note: at MVP, `civilian_witnessed_event` is not emitted (CR-12 compile-flag gate); Audio's `civilian_witnessed_event` handler is dead code at MVP. |
| Stealth AI (stealth-ai.md L325, L621, L661, L669, L729, L780, L916) | SAI subscribes to `civilian_witnessed_event` → `ALERTED_BY_OTHER` MINOR; `CIVILIAN_PROPAGATION_BUMP = 0.5`; OQ-SAI-1 deferred to CAI GDD | ✅ Consistent. CAI's CR-12 + F.5 implements the publish side. OQ-SAI-1 closed by this GDD (coord item §F.5#10). |
| Combat & Damage (combat-damage.md L388, L424, L681, L888, L900) | CAI may subscribe to `weapon_fired`, `enemy_killed` for panic; civilians have no weapons; civilian-killed → no WorldItem (Inventory CR-7a) | ✅ Consistent. CAI subscribes to both per CR-4. CR-7 forbids civilian damage emit; civilians cannot die so the `enemy_killed` path is unreachable. |
| Save / Load (save-load.md L24, L26, L104, L157, L261) | CivilianAI is a passive SaveGame contributor; per-civilian panic flag keyed by `actor_id` | ✅ Consistent. CR-10 capture() format matches; the `cause: Vector3` field added by user-adjudicated 2026-04-24 may need a minor save-load.md schema touch-up (ADVISORY coord item §F.5#8). |
| Mission & Level Scripting (mission-level-scripting.md L107, L154, L536, L679) | MLS T6 Alert-State Comedy fires bystander banter (NOT CAI's concern); MLS does NOT reference CAI directly; civilians have `actor_id` | ✅ Consistent. T6 banter is MLS-authored; CAI panic state is independent. **Conflict resolved 2026-04-27** — `/consistency-check` edited MLS L679-680 to split "Guards: Medium tier (2)" from "Civilians: Light tier (3) by default; Heaviest tier (1) at BQA pickup distance per CR-14." OP ADR-0001 authoritative. Coord item §F.5#7 CLOSED. |
| Failure & Respawn (failure-respawn.md L282, L478) | F&R does NOT touch civilians; CAI not in F&R source per AC-FR-12.1 | ✅ Consistent. CR-10 + E.30 confirm RESPAWN path uses SaveGame restore, not F&R direct. |
| Inventory & Gadgets (inventory-gadgets.md L452, L911) | Civilians don't carry weapons, don't drop ammo on death (civilians shouldn't die anyway); Inventory has no civilian-side subscription | ✅ Consistent. CR-7 confirms civilians cannot die at MVP/VS. Inventory CR-7a `carried_weapon_id == none` is moot (never reached). |
| Outline Pipeline (outline-pipeline.md L21, L38, L62, L112, L244, L264, L369) | Civilians = Tier 3 LIGHT; BQA contact in Plaza = Tier 1 at pickup distance only | ✅ Consistent. CR-14 implements both. **Confirmed 2026-04-27**: MLS L679 conflict resolved by `/consistency-check` (Guards Medium tier 2 / Civilians Light tier 3 split, BQA-promote to Heaviest tier 1 per CR-14). OP ADR-0001 authoritative. |
| Signal Bus (signal-bus.md L17, L38, L61, L79, L87, L116, L123, L203, L207) | Civilian domain = `civilian_panicked`, `civilian_witnessed_event`; CAI publishes Civilian; subscribes to AI/Stealth + Combat; owns `WitnessEventType` enum | ✅ Consistent. ADR-0002 + this GDD agree on all signatures, ownership, subscription matrix. |

## Tuning Knobs

### G.1 MVP panic-trigger radii

| Knob | Default | Safe range | Effect at extremes | Pillar concern |
|---|---|---|---|---|
| `PANIC_GUNFIRE_RADIUS_M` | 12.0 m | [8.0, 18.0] | <8 m: loud-room gunfire ignored (Pillar 3 violation — "stealth has no witnesses"). >18 m: every shot scatters the entire section, breaking Pillar 3 + Audio Formula 2 saturating diegetic recoil. | Pillar 3 — civilian witness density |
| `PANIC_BODY_RADIUS_M` | 8.0 m | [5.0, 12.0] | <5 m: dart-KO bodies undiscovered until civilian walks over them (Pillar 1 stealth-reward). >12 m: silenced takedowns scatter the room, defeating the silencer's purpose. | Pillar 1 — silenced kill reward |

**Tuning relationship**: gunfire radius MUST be ≥ body radius. The 4 m gap (12 vs 8) is the primary stealth-reward lever — silenced takedowns are quieter than gunfire by design. Inverting this relationship breaks the design.

### G.2 MVP flee behavior

| Knob | Default | Safe range | Effect at extremes | Notes |
|---|---|---|---|---|
| `FLEE_SPEED_MPS` | 4.5 m/s | [2.5, 6.5] | <2.5: civilians look undermotivated (slower than Eve's walk 3.5 m/s — Pillar 1 break, "Eve outpaces panic"). >6.5: civilians sprint faster than Eve (5.5 m/s sprint per PC GDD), reading as supernatural. | NOLF1 reference: civilians flee at brisk-walk-to-jog pace, never sprint. |
| `COWER_RADIUS_M` | 2.0 m | [0.5, 4.0] | <0.5: civilians always run away from any cause, no cower fallback (looks robotic when Eve fires inches away). >4.0: civilians cower frequently rather than flee, breaking the chorus aesthetic. | Used in §C.3 Phase 1 (cause too close to flee meaningfully). |
| `MAX_COWER_DURATION_S` | 8.0 s | [3.0, 30.0] | <3.0: cowering civilian transitions to flee almost immediately even with stationary threat — reads as "scared then bolts" rather than "hides then peeks". >30.0: stationary threat can keep a civilian frozen for half a minute — game-designer's broken-AI risk returns. | CR-3a cower-exit safety net. The 1.0 s `$CowerExitTimer` polling tick is hardcoded (not a tuning knob); only the timeout is tunable. |
| `ANCHOR_OPPOSITE_DOT_THRESHOLD` | 0.3 (≈cos 72°) | [0.0, 0.7] | 0.0: anchors at 90° from cause direction accepted (civilians may flee sideways). 0.7 (≈cos 45°): only anchors directly behind civilian accepted (most sections fall back to Phase 3). | Authoring lever; tune up if civilians flee sideways awkwardly in Restaurant. |
| `ANCHOR_NAV_SNAP_TOLERANCE_M` | 1.0 m | [0.5, 3.0] | <0.5: anchors must be precisely on NavMesh (level-designer authoring burden). >3.0: anchors floating above NavMesh accepted (civilians get NavMesh-snapped to the wrong spot). | Implementation lever; rarely tuned post-spec. |
| `FLEE_FALLBACK_DISTANCE_M` | 15.0 m | [8.0, 25.0] | <8: civilians flee a few steps and stop (looks half-hearted). >25: civilians flee out of section in some layouts (LSS may fire `section_exited` from a panic-wandering civilian → coord risk). | §C.3 Phase 3 fallback distance when no anchor is valid. |

### G.3 VS-tier witness-event radii

| Knob | Default | Safe range | Effect at extremes |
|---|---|---|---|
| `WITNESS_GUNFIRE_RADIUS_M` | 18.0 m | [12.0, 25.0] | Larger than panic radius (12.0) by design — sound carries; a civilian who doesn't panic can still witness (they heard it but it's not in their face). |
| `WITNESS_BODY_RADIUS_M` | 12.0 m | [6.0, 16.0] | Equals panic radius — body discovery is visual-proximity. Tuning together with panic-body radius is wise. |
| `WITNESS_BRANDISH_RADIUS_M` | 8.0 m | [3.0, 12.0] | Tight personal-space radius — open carrying only alarming when close. <3 m: civilians never witness brandishing (VS feature dead). >12 m: civilians witness Eve with a holstered weapon at corridor distance (false-positive). |

**VS-only — these knobs have no MVP effect** because the entire `civilian_witnessed_event` emission path is compile-gated off at MVP (CR-12).

### G.4 VS-tier BQA contact

| Knob | Default | Safe range | Effect at extremes |
|---|---|---|---|
| `BQA_PICKUP_DISTANCE_M` | 3.0 m | [1.5, 5.0] | <1.5: contact's outline doesn't promote until Eve is touching them (no "spotting at distance" reward — Pillar 2 break). >5.0: contact is highlighted from across the room (Pillar 5 break — period authenticity forbids quest indicators). |

**VS-only** — this knob has no MVP effect (CR-14 BQA contact is compile-gated off at MVP).

### G.5 Performance budget (BINDING — not designer-tunable)

| Quantity | Value | Source | Mutability |
|---|---|---|---|
| `CAI_FRAME_BUDGET_MS_P95` | 0.30 ms (revised 2026-04-25 from 0.15 ms) | ADR-0008 Slot #8 sub-claim (CR-9 + F.3) | **NOT a tuning knob** — binding budget commitment; any increase requires ADR-0008 amendment with re-allocation pass against MLS / DC / Dialogue / F&R / Signal Bus dispatch sub-claims. Panic-onset spike covered by ADR-0008 reserve carve-out (2026-04-28 amendment). |
| `C_per_civilian_us` (estimated peak) | 25.0 µs | gameplay-programmer 2026-04-25 | Implementation-measured, not tuned. If profiling shows >25 µs, the spec is wrong, not the knob. |
| `N_active_max` (Restaurant worst case) | 8 | §Overview + Combat GDD L681 | Authoring lever (level designer) — increasing civilians per section past 8 is an ADR-0008 amendment trigger. |

**Operational note**: profiling CI runs F.3's worst-case scenario (8 civilians simultaneous panic) at every PR via the `/perf-profile` gate. Any p95 > 0.30 ms (revised 2026-04-25 from 0.15 ms) regresses the build per ADR-0008's CI cap, EXCEPT for the panic-onset 1-2 frames which are exempt under ADR-0008's 2026-04-28 reserve carve-out (`civilian_panicked` ≥ 4 emissions in a single physics frame). Steady-state math (8 civilians × 32 µs ≈ 256 µs) fits comfortably within 0.30 ms; panic-onset (~896 µs) draws from the 0.6 ms reserve carve-out.

### G.6 Tuning knob ownership matrix

| Knob category | Owner | Mutability gate |
|---|---|---|
| Panic-trigger radii (G.1) | systems-designer | Playtest-driven; no ADR gate |
| Flee behavior (G.2) | game-designer + level-designer (anchor authoring) | Playtest + section-validation CI |
| Witness-event radii (G.3) | systems-designer (VS only) | VS-tier playtest only |
| BQA pickup distance (G.4) | game-designer + ux-designer (VS only) | Pillar-2 felt-discovery playtest |
| Performance budgets (G.5) | technical-director (NOT a tuning knob) | ADR-0008 amendment required |

## Visual/Audio Requirements

### V.1 Civilian Model Variants

**Per-section civilian counts (locked 2026-04-25):**

| Section | Civilians (placed) | Civilians (simultaneously active in loaded chunk) | Mesh load (max distinct visible) |
|---|---|---|---|
| Plaza | 4-6 | 4-6 (small section; all civilians active) | up to 6 distinct |
| Restaurant | 6-8 | 6-8 (worst case for ADR-0008 budget) | up to 8 distinct |
| Eiffel viewing platforms | 4-6 (per platform; multi-platform sections may sum higher) | up to 6 (per loaded chunk) | up to 6 distinct |

The 8-civilian cap is the **per-loaded-chunk simultaneous active** limit, not a per-section placed limit. Eiffel multi-platform sections may have 12 civilians total placed but only 4-6 active in any one loaded chunk (the upper platforms unload when the player descends). Section-validation CI MUST fail (not warn) when any single loaded chunk would have > 8 simultaneously-active civilians (level-designer + performance-analyst convergent finding 2026-04-25).

**Production target: 4 base archetypes × 2 variants = 8 unique meshes.** This is the S-effort ceiling; do not exceed it.

| Archetype | Silhouette read | Deployed in |
|---|---|---|
| **Man in suit / hat** | Narrow brim, briefcase or newspaper | Plaza, Eiffel approach, Restaurant |
| **Woman in A-line coat** | Bouffant hair, handbag, low heel | Plaza, Eiffel approach, all zones |
| **Waiter** | White apron, tray prop, short jacket | Restaurant only |
| **Uniformed ticket-taker** | Peaked cap, single-breasted jacket | Eiffel viewing platforms |

Two variants per archetype = hat color / coat color swap + one accessory change (newspaper vs. briefcase; handbag style). Mesh is shared; variant is a material palette swap + swapped prop attachment. This keeps unique mesh count at 8 while producing 16 visually distinct civilian appearances in practice, covering the 6–8 worst-case Restaurant count without repetition at camera distance.

**BQA contacts are NOT a fifth archetype** — they are one of the above base archetypes carrying one composed-geometry tell (folded newspaper at specific angle; period briefcase with BQA-proportioned clasp). No unique mesh required. Art Director owns the tell specification — see coord item AD-COORD-01 in §F.5.

### V.2 Animation State Requirements

Each civilian `AnimationTree` must implement an `AnimationNodeStateMachine` with these states, matching CR-3 and §C.2 transitions:

| State | Trigger | CAI-driven? | Notes |
|---|---|---|---|
| `idle` | Default / `CALM` | Yes | Looped ambient pose: weight-shift, small head look. No banter gestures. |
| `scripted_walk` | `CALM` patrol path active | Yes | Linear path traversal at civilian pace (~1.2 m/s). Blend with `idle` at path end. |
| `cower` | `PANICKED` + cower phase active (§C.3 Phase 1) | Yes | Hunched, arms raised, stationary. Must be interruptible by `panic_flee`. |
| `panic_flee` | `PANICKED` → moving | Yes | Fast walk cycle (~2.4 m/s with FLEE_SPEED_MPS = 4.5 m/s), arms slightly raised. NOT a run-cycle — period register, not action-movie sprint. |

CAI owns all four states. MLS T6 banter NPCs may layer additional scripted-animation states (seated dinner gestures, postcard-display loops) **on top of** `idle` via `AnimationTree` blend nodes — those are MLS-T6 scope, not CAI scope, and must not conflict with CAI state transitions.

**No death animation is specified or permitted** (Combat E.29, Inventory CR-7a, CR-7 no-kill contract).

### V.3 Outline Tier (ADR-0001 Alignment)

**Default: Tier 3 LIGHT — 1.5 px outline, environmental readability.** All civilians render at Tier 3 in all states (CALM, PANICKED, cower) at all distances. The soft outline pushes them into the mid-ground against Eiffel Grey ironwork and Paris Amber light pools, consistent with Art Bible §3.4 ("visual noise the eye learns to filter").

**VS promotion: BQA contacts only, at pickup distance.** When a BQA contact enters VS pickup distance (`BQA_PICKUP_DISTANCE_M = 3.0` m), CAI promotes the civilian's `MeshInstance3D` to Tier 1 HEAVIEST (4 px) via:

```
OutlineTier.set_tier(mesh_instance_3d, OutlineTier.HEAVIEST)
```

`OutlineTier.set_tier()` takes the `MeshInstance3D` directly, NOT the parent `Node` (gameplay-programmer 2026-04-25 finding; CR-15.9 forbidden pattern). Civilian AI must cache the `MeshInstance3D` reference at spawn (`_ready()`), not at promotion time. On `body_exited`, revert to Tier 3 via the same call. No other outline tier changes are triggered by civilian state transitions (including panic).

### V.4 Style and Tonal Constraints (Pillar 5)

**Period attire floor (1965 Paris):** Working-class to upper-middle-class register. Men: wool suit, felt hat (fedora or homburg), leather oxford shoes. Women: A-line or shift dress under belted coat, low-heel court shoes, structured handbag. Waiters: white bibbed apron over black trousers, white shirt, black bow-tie. Ticket-takers: single-breasted navy uniform jacket, peaked cap with period badge. No jeans, no trainers, no synthetic fabrics. No anachronistic silhouettes.

**Tonal register:** Civilians are the **chorus**, not co-stars. Their body language is unhurried and slightly oblivious — they are not in a spy film, they think they are in a Tuesday. This busyness contrasts Eve's stillness; Art Bible §3.1 governs: "rounder, softer, slower-moving." Matt Helm-era 1965 cinema register (Dean Martin's *The Silencers*, 1966) — not Connery Bond sharpness, not Hitman grotesque. The postcard-seller is not a character; she is the texture of Paris.

**Forbidden patterns (Pillar 5 hard rules):**

- No quest indicators, waypoint arrows, or objective markers attached to or above any civilian
- No floating nameplates or dialogue-bubble tooltips
- No glowing NPC outlines except via stencil tier promotion (V.3) — zero exceptions
- No reaction icon floats (no "!" or "?" above civilian heads — that is the SAI guard-system reserved vocabulary, forbidden entirely on civilians per Pillar 5)
- No ambient idle chatter subtitles floating in world space — MLS T6 banter uses the existing period-styled subtitle system, not world-anchored text

### V.5 Asset Spec Flag

📌 **Asset Spec** — Visual requirements are defined. After the Art Bible is approved, run `/asset-spec system:civilian-ai` to produce per-asset specifications: mesh poly budget per archetype, texture sheet dimensions and layout, naming convention (`char_civilian_[archetype]_[variant]_idle_01.png`), and import settings for Godot 4.6's resource pipeline.

### A.1 Audio Handoff to Audio GDD

CAI is a **signal publisher only**. All audio dispatch is owned by Audio GDD (Approved 2026-04-21) §Civilian-domain handler table (audio.md L203-208). CAI publishes two signals via the Signal Bus (ADR-0002, signatures locked):

- `civilian_panicked(civilian: Node, cause_position: Vector3)` — Audio dispatches a period French vocal gasp ("Mon Dieu!", "Quoi?!") at `cause_position` via its own pooled `AudioStreamPlayer3D` (Voice bus, max 4 concurrent). CAI does not own, create, or manage these players.
- `civilian_witnessed_event(civilian, event_type, position)` — Audio intensifies the Ambient-bus crowd murmur layer (non-spatial, max 1 concurrent). VS-only.

CAI does not call audio methods directly. No `AudioServer` calls, no `AudioStreamPlayer` node references, no bus manipulation.

### A.2 Pillar 1 Reading of Formula 2

Per Audio GDD Formula 2 (audio.md L286-313): each `civilian_panicked` emission increments `panic_count` (Audio's internal counter). The diegetic quartet recedes by `−min(panic_count × 1.0, 3.0)` dB (hard cap −3 dB). The non-diegetic score rises by `+min(panic_count × 0.5, 2.0)` dB (hard cap +2 dB, unity clamp). **Reading: the crowd's panic recoils the performance (the quartet flinches from the noise) while Eve's cool underscoring barely inflects.** The audience-reacts-to-the-performance fantasy is carried by the diegetic recession, not a score swell. This is the Pillar 1 spec ("comedy without punchlines"). Do not alter this balance from the CAI side.

### A.3 What CAI Does NOT Own (Audio Side)

- **AudioStreamPlayer3D nodes**: none. Audio owns the pool.
- **Per-civilian footstep emission**: civilians may produce ambient walking sound via art-driven mesh-foley, but it is NOT routed through Audio's `player_footstep` event path. If civilian footstep audio is needed at VS, it becomes a separate `civilian_footstep` event authored then. CAI does not emit footstep signals.
- **Death sounds**: civilians cannot die (CR-7). No death cue, no body-thud, no scream. The absence is load-bearing — do not add placeholder death audio.
- **Per-civilian dialogue**: T6 banter is VS-only, authored by Mission & Level Scripting, voiced through Audio's VO pipeline. CAI does not publish `dialogue_line_started`.
- **Weapon muzzle SFX**: civilians are unarmed.
- **Radio chatter**: directional radio chatter belongs to guard posts (Audio ambient table audio.md L229). Civilians carry no radios.

### A.4 Coord Items (carry-forward from Audio GDD)

**[OPEN — audio-director + narrative-director]** Civilian vocal gasp VO ownership (casting + localization): "Mon Dieu!" / "Quoi?!" gasps are neither clean SFX nor scripted dialogue lines. Likely routed through the Dialogue & Subtitles GDD VO pipeline when that GDD lands. Sourcing the gasp sample library must happen **before MVP playtest** — playtest cannot validate Pillar 5 period authenticity on placeholder audio. CAI content production begins before that gate; see Audio GDD coord item L689 (carried forward as OQ-CAI-6 in §Open Questions).

### A.5 Forbidden Audio Patterns

- No civilian-fired weapon SFX — civilians are unarmed.
- No civilian death cues — CR-7 prohibits civilian death.
- No directional radio chatter from civilians — reserved for guard-post emitters (audio.md L229).
- No direct `AudioServer` or `AudioStreamPlayer` manipulation from any CAI script (forbidden pattern — would bypass Audio's bus + concurrency policies).

## UI Requirements

**Civilian AI exposes ZERO UI elements at MVP and VS — Pillar 5 absolute.**

Civilians do not appear in the HUD. There is no civilian count, no panic indicator, no chorus-state widget, no BQA-contact-detected toast, no waypoint to the nearest panicking civilian, no "1 / 3 contacts found" tracker, no faction reputation bar. The Player Fantasy is "stealth with witnesses, the world reads you back" — adding a UI element to surface civilian state would convert chorus into co-star and break Pillar 5 (Period Authenticity Over Modernization) and Pillar 2 (Discovery Rewards Patience) simultaneously.

**Forward-dependency note (VS-tier — informational only, not implemented by this GDD):**

- **Dialogue & Subtitles** (system #18, VS): when a BQA contact's pickup-distance Area3D fires `body_entered`, Dialogue & Subtitles owns the period-styled subtitle rendering for the contact's intel line. The trigger is owned here (CR-14); the rendering is owned there.
- **HUD State Signaling** (system #19, VS): MAY add a "civilians panicking" diegetic glance-down indicator (e.g., a clipboard tally on the HUD's player-stats widget). HUD State Signaling owns the design; CAI does not subscribe to or query HUD state.

This GDD declines to specify any further UI work. UI specs for the BQA-contact dialogue surface are out-of-scope until `/ux-design` is run for `dialogue-overlay` at VS-tier.

## Acceptance Criteria

### Group 1 — Entity Contract & State Machine

**AC-CAI-1.1 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node is instantiated from `Civilian.tscn` with a valid `actor_id` set in the editor, **WHEN** `_ready()` completes, **THEN**: (1) `get_collision_layer_value(PhysicsLayers.LAYER_AI) == true`; (2) `get_collision_mask_value(PhysicsLayers.MASK_WORLD) == true`; (3) `get_groups()` returns an `Array` of size exactly 1 with `"civilian"` as the sole element; (4) `is_physics_processing() == false`; (5) `_panic_state == false`; (6) `nav_agent.avoidance_enabled == true` (CR-1a — without this, civilians never move); (7) `nav_agent.target_desired_distance` is in `[0.5, 1.5]` m; (8) `$CowerExitTimer` exists as a child node and `$CowerExitTimer.is_stopped() == true`. `[Cites: CR-1, CR-1a, CR-9]` Evidence: `tests/unit/civilian_ai/civilian_entity_contract_test.gd`

**AC-CAI-1.2 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node is instantiated with `actor_id` left empty (empty `StringName`), **WHEN** `_ready()` completes, **THEN** `push_error()` has been called, `set_process(false)` and `set_physics_process(false)` have been called, and the node does not crash the engine. `[Cites: CR-2]` Evidence: `tests/unit/civilian_ai/civilian_actor_id_validation_test.gd`

**AC-CAI-1.3 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state, **WHEN** it is inspected at scene load (before any panic trigger fires), **THEN** `_panic_state == false`, `_physics_process` is disabled, and `PanicState.CALM` is the active state; no transition to `PANICKED` occurs spontaneously. `[Cites: CR-3]` Evidence: `tests/unit/civilian_ai/civilian_state_machine_initial_test.gd`

**AC-CAI-1.4 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state, **WHEN** it is NOT in any of the groups `"player"`, `"dead_guard"`, or `"alive_guard"`, **THEN** `is_in_group("player")`, `is_in_group("dead_guard")`, and `is_in_group("alive_guard")` all return `false`; only `is_in_group("civilian")` returns `true`. `[Cites: CR-1, E.16]` Evidence: `tests/unit/civilian_ai/civilian_group_membership_test.gd`

### Group 2 — Panic Trigger Predicates

**AC-CAI-2.1 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state at position `(0,0,0)` with `PANIC_GUNFIRE_RADIUS_M = 12.0`, **WHEN** `Events.weapon_fired` is emitted with `position = (10,0,0)` (distance = 10.0 m ≤ 12.0 m), **THEN** `_panic_state` becomes `true` and the civilian transitions to `PANICKED`; exactly one `Events.civilian_panicked` emission is recorded. `[Cites: CR-4, F.1]` Evidence: `tests/unit/civilian_ai/civilian_panic_trigger_gunfire_test.gd`

**AC-CAI-2.2 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state at position `(0,0,0)` with `PANIC_GUNFIRE_RADIUS_M = 12.0`, **WHEN** `Events.weapon_fired` is emitted with `position = (13,0,0)` (distance = 13.0 m > 12.0 m), **THEN** `_panic_state` remains `false`; no `Events.civilian_panicked` emission occurs. `[Cites: CR-4, F.1]` Evidence: `tests/unit/civilian_ai/civilian_panic_trigger_gunfire_test.gd`

**AC-CAI-2.3 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state with `PANIC_BODY_RADIUS_M = 8.0`, **WHEN** `Events.enemy_killed` is emitted with a valid `actor` node whose `global_position` is 7.0 m from the civilian, **THEN** `_panic_state` becomes `true` and `cause_position` equals `actor.global_position`. `[Cites: CR-4, F.1]` Evidence: `tests/unit/civilian_ai/civilian_panic_trigger_body_test.gd`

**AC-CAI-2.4 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state, **WHEN** `receive_damage(10.0, source_node, 0)` is called directly, **THEN** `_panic_state` becomes `true` unconditionally (no distance check); `cause_position` equals `source_node.global_position`. `[Cites: CR-4, CR-7, F.1]` Evidence: `tests/unit/civilian_ai/civilian_panic_trigger_damage_test.gd`

**AC-CAI-2.5 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state, **WHEN** `Events.weapon_fired` AND `Events.enemy_killed` both fire within their respective radii in the same frame, **THEN** `Events.civilian_panicked` is emitted exactly once; `_panic_state` is `true` after both handlers complete; the second handler exits via the `_maybe_retarget_flee` path without re-emitting. `[Cites: CR-5, E.1, E.3]` Evidence: `tests/unit/civilian_ai/civilian_idempotency_same_frame_test.gd`

**AC-CAI-2.6 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node already in `PANICKED` state with stored `_cause_position` 9.0 m from current position, **WHEN** a second `Events.weapon_fired` fires with a new `cause_position` that is 6.0 m from current position (6.0 < 9.0), **THEN** `_cause_position` updates to the closer position, flee target is recomputed, and no `Events.civilian_panicked` is re-emitted. `[Cites: CR-5, F.2]` Evidence: `tests/unit/civilian_ai/civilian_retarget_proximity_gate_test.gd`

**AC-CAI-2.7 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node already in `PANICKED` state with stored `_cause_position` 6.0 m from current position, **WHEN** a second trigger fires with a new `cause_position` that is 9.0 m from current position (9.0 > 6.0), **THEN** `_cause_position` does NOT update, flee target is NOT recomputed, and no re-emission occurs. `[Cites: CR-5, F.2]` Evidence: `tests/unit/civilian_ai/civilian_retarget_proximity_gate_test.gd`

**AC-CAI-2.8 [Logic] [BLOCKING] (NEW 2026-04-25)** — **GIVEN** a PANICKED civilian with flee target T1 = `nav_agent.get_target_position()` after first cause, **WHEN** F.2 retarget fires (new cause closer than old), **THEN** `nav_agent.get_target_position() != T1` (the nav agent has been told a new target, not just the internal `_cause_position`). Closes qa-lead GAP-1 (retarget verification was previously only on `_cause_position` update, not on downstream nav target update). `[Cites: CR-5, F.2, §C.2 PANICKED → PANICKED transition]` Evidence: `tests/unit/civilian_ai/civilian_retarget_proximity_gate_test.gd`

**AC-CAI-2.9 [Logic] [BLOCKING] (NEW 2026-04-25, qa-lead GAP-6)** — **GIVEN** a `CivilianAI` node in CALM state, **WHEN** `Events.enemy_killed` is emitted with a freed/invalid `actor` node (`is_instance_valid(actor) == false`), **THEN** `_panic_state` remains `false`; no `Events.civilian_panicked` emission occurs; no crash, no null-access script error. `[Cites: CR-4, ADR-0002 Rule 4]` Evidence: `tests/unit/civilian_ai/civilian_invalid_actor_guard_test.gd`

### Group 3 — Signal Emission

**AC-CAI-3.1 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state, **WHEN** a panic trigger fires, **THEN** `Events.civilian_panicked` is emitted with signature `(civilian: Node, cause_position: Vector3)` after `_panic_state = true` is set but before flee-target computation begins; a re-entrant trigger check within the signal handler observes `_panic_state == true`. `[Cites: CR-6, ADR-0002]` Evidence: `tests/unit/civilian_ai/civilian_signal_emission_order_test.gd`

**AC-CAI-3.2 [Integration] [BLOCKING]** — **GIVEN** an Audio subscriber connected to `Events.civilian_panicked`, **WHEN** a civilian panics and `Events.civilian_panicked` fires, **THEN** the subscriber's handler receives a valid `civilian` node and a `Vector3` `cause_position`; calling `is_instance_valid(civilian)` inside the handler returns `true`. `[Cites: CR-6, CR-11, ADR-0002 Rule 4]` Evidence: `tests/integration/civilian_ai/civilian_audio_panic_signal_test.gd`

**AC-CAI-3.3 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node added to the scene tree, **WHEN** `_ready()` completes, **THEN** `Events.weapon_fired.is_connected(_on_weapon_fired)` is `true`, `Events.enemy_killed.is_connected(_on_enemy_killed)` is `true`, and `nav_agent.velocity_computed.is_connected(_on_velocity_computed)` is `true`. `[Cites: CR-11]` Evidence: `tests/unit/civilian_ai/civilian_signal_lifecycle_test.gd`

**AC-CAI-3.4 [Logic] [BLOCKING] (revised 2026-04-25, qa-lead GAP-7)** — **GIVEN** a `CivilianAI` node with all signals connected, **WHEN** the node is removed from the scene tree (`_exit_tree()` fires), **THEN** ALL of the following are `false`: `Events.weapon_fired.is_connected(_on_weapon_fired)`, `Events.enemy_killed.is_connected(_on_enemy_killed)`, `Events.section_entered.is_connected(_on_section_entered)`, `nav_agent.velocity_computed.is_connected(_on_velocity_computed)`, `$CowerExitTimer.timeout.is_connected(_on_cower_exit_timer_timeout)`. Additionally, `LevelStreamingService.is_restore_callback_registered(_restore_state) == false` (LSS de-registration per CR-11; ai-programmer BLOCKING-5 use-after-free guard). `[Cites: CR-11]` Evidence: `tests/unit/civilian_ai/civilian_signal_lifecycle_test.gd`

**AC-CAI-3.5 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node at MVP scope, **WHEN** any panic trigger fires, **THEN** `Events.player_footstep` has zero connections originating from `CivilianAI`; CI grep of `src/gameplay/ai/civilian_*.gd` for `Events.player_footstep` returns zero matches. `[Cites: CR-11, CR-15.1]` Evidence: `tests/unit/civilian_ai/civilian_forbidden_subscription_test.gd`

### Group 4 — Damage No-Op

**AC-CAI-4.1 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state, **WHEN** `receive_damage(50.0, source, 0)` is called, **THEN** no HP variable is decremented, no `enemy_killed` signal fires, no `enemy_damaged` signal fires, no `player_died` signal fires, and the node remains a valid scene instance. `[Cites: CR-7]` Evidence: `tests/unit/civilian_ai/civilian_damage_noop_test.gd`

**AC-CAI-4.2 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node, **WHEN** `receive_damage` is called with any `amount`, `source`, and `type` value including `DART_TRANQUILISER` and `MELEE_PARFUM`, **THEN** the only observable side effect is `_trigger_panic` being called; no state change besides `_panic_state` occurs; the civilian does not enter any UNCONSCIOUS or equivalent state. `[Cites: CR-7, E.7, E.8]` Evidence: `tests/unit/civilian_ai/civilian_damage_noop_test.gd`

**AC-CAI-4.3 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node, **WHEN** `receive_damage` is called with `source` as a `null` or freed node (`is_instance_valid(source) == false`), **THEN** `cause_position` falls back to `self.global_position` without crashing; no null-access error is emitted. `[Cites: CR-4, CR-7, E.5]` Evidence: `tests/unit/civilian_ai/civilian_damage_noop_test.gd`

### Group 5 — Flee Behavior

**AC-CAI-5.1 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node that panics with a valid `panic_anchor` in group `"panic_anchor"` on the opposite side of the cause (dot product ≥ 0.3) and within NavMesh snap tolerance, **WHEN** `_set_flee_target(cause_pos)` is called, **THEN** `NavigationAgent3D.get_target_position()` equals the closest valid anchor's `global_position`; `_fleeing_mode == FleeMode.FLEEING_TO_ANCHOR`; `_physics_process` is enabled. `[Cites: CR-8, F.4, §C.3 Phase 2]` Evidence: `tests/unit/civilian_ai/civilian_flee_anchor_selection_test.gd`

**AC-CAI-5.2 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node with no valid `panic_anchor` in the `"panic_anchor"` group (all anchors fail the dot-product filter or no anchors exist), **WHEN** `_set_flee_target(cause_pos)` is called, **THEN** the flee target is the NavMesh-snapped point at `global_position + away_dir * FLEE_FALLBACK_DISTANCE_M`; `_fleeing_mode == FleeMode.FLEEING_AWAY`. `[Cites: CR-8, F.4, §C.3 Phase 3, E.24, E.25]` Evidence: `tests/unit/civilian_ai/civilian_flee_fallback_test.gd`

**AC-CAI-5.3 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node with `cause_position` within `COWER_RADIUS_M` (2.0 m) of the civilian's position, **WHEN** `_set_flee_target(cause_pos)` is called, **THEN** `_fleeing_mode == FleeMode.COWERING`, no `NavigationAgent3D` target is set, and `_physics_process` remains disabled. `[Cites: CR-8, §C.3 Phase 1]` Evidence: `tests/unit/civilian_ai/civilian_cower_phase_test.gd`

**AC-CAI-5.4 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node actively navigating (PANICKED, `_physics_process` enabled), **WHEN** `NavigationAgent3D.is_navigation_finished()` returns `true`, **THEN** `set_physics_process(false)` is called (verified via `is_physics_processing() == false`) AND `AnimationTree.get_current_node()` returns `"cower"` (the canonical post-arrival state per V.2; CR-8 was previously ambiguous "panic-idle/cower" — locked to `cower` 2026-04-25). `[Cites: CR-8, CR-9, V.2]` Evidence: `tests/unit/civilian_ai/civilian_nav_finished_idle_test.gd`

**AC-CAI-5.5 [Integration] [BLOCKING]** — **GIVEN** two `CivilianAI` nodes fleeing toward the same narrow corridor (RVO-relevant scenario, sharing a NavMesh map), **WHEN** `_physics_process` runs for 30 frames, **THEN**: (1) for all pairs of civilians, `global_position.distance_to(other.global_position) > 0.3` (RVO avoidance is active — proves `nav_agent.velocity` is being written and `velocity_computed` callback fires); (2) each civilian's `global_position` displaces by ≥ 1.0 m from its frame-0 position over 30 frames (proves `move_and_slide()` IS called from the `velocity_computed` callback — closes qa-lead GAP-3 positive-motion verification). The static "move_and_slide() not called from `_physics_process`" check is delegated to AC-CAI-8.3 grep pattern #8. `[Cites: CR-8, CR-15.8]` Evidence: `tests/integration/civilian_ai/civilian_rvo_callback_pattern_test.gd`

**AC-CAI-5.6 [Logic] [BLOCKING] (NEW 2026-04-25)** — **GIVEN** a PANICKED civilian with `_fleeing_mode = COWERING` and `_cause_position` 1.5 m from civilian (within `COWER_RADIUS_M`), **WHEN** the cause moves to a position 3.5 m from civilian (outside `COWER_RADIUS_M`) and the next `$CowerExitTimer.timeout` fires, **THEN**: (1) `_set_flee_target(_cause_position)` is invoked; (2) `_fleeing_mode` transitions to `FleeMode.FLEEING_TO_ANCHOR` or `FleeMode.FLEEING_AWAY`; (3) `is_physics_processing() == true`; (4) `AnimationTree.get_current_node() == "panic_flee"`; (5) `$CowerExitTimer.is_stopped() == true`; (6) NO `Events.civilian_panicked` re-emission. `[Cites: CR-3a, §C.2 cower-exit transition]` Evidence: `tests/unit/civilian_ai/civilian_cower_exit_threat_leave_test.gd`

**AC-CAI-5.7 [Logic] [BLOCKING] (NEW 2026-04-25)** — **GIVEN** a PANICKED civilian with `_fleeing_mode = COWERING` and the cause STAYING within `COWER_RADIUS_M` indefinitely, **WHEN** `MAX_COWER_DURATION_S` (8.0 s = 480 physics frames at 60 fps) elapses, **THEN** `_set_flee_target(_cause_position)` is re-invoked (Phase 1 may re-fire if cause still close, refreshing `_cower_started_at_msec`); the test verifies `Time.get_ticks_msec() - _cower_started_at_msec` is reset to ≤ 1000 ms after the timeout firing. NO `Events.civilian_panicked` re-emission. `[Cites: CR-3a, §C.2 cower-exit timeout transition]` Evidence: `tests/unit/civilian_ai/civilian_cower_exit_timeout_test.gd`

### Group 6 — Save / Restore

**AC-CAI-6.1 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `CALM` state, **WHEN** `capture()` is called, **THEN** the returned dictionary contains `{ "panicked": false, "cause": Vector3.ZERO }` (or equivalent zero-vector sentinel); the dictionary is serializable without engine errors. `[Cites: CR-10, E.12]` Evidence: `tests/unit/civilian_ai/civilian_save_capture_test.gd`

**AC-CAI-6.2 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node in `PANICKED` state with `_cause_position = Vector3(10, 0, 3)`, **WHEN** `capture()` is called, **THEN** the returned dictionary contains `{ "panicked": true, "cause": Vector3(10, 0, 3) }`. `[Cites: CR-10, E.10]` Evidence: `tests/unit/civilian_ai/civilian_save_capture_test.gd`

**AC-CAI-6.3 [Integration] [BLOCKING]** — **GIVEN** a `CivilianAI` node with `actor_id = "waiter_01"` that was PANICKED at `_cause_position = Vector3(5,0,0)` when saved, **WHEN** `_restore_state` is called with a `CivilianAIState` dictionary containing `{ "waiter_01": { "panicked": true, "cause": Vector3(5,0,0) } }`, **THEN** `_panic_state == true`, `_cause_position == Vector3(5,0,0)`, flee target is recomputed via §C.3, `_physics_process` is enabled, and NO `Events.civilian_panicked` is emitted. `[Cites: CR-10, E.10, E.11]` Evidence: `tests/integration/civilian_ai/civilian_save_load_roundtrip_test.gd`

**AC-CAI-6.4 [Integration] [BLOCKING]** — **GIVEN** a `CivilianAI` node restored to PANICKED via `LOAD_FROM_SAVE`, **WHEN** an Audio subscriber queries `get_tree().get_nodes_in_group("civilian")` and counts nodes with `panicked == true`, **THEN** the count matches the number of PANICKED civilians restored, with no reliance on `Events.civilian_panicked` being re-emitted. `[Cites: CR-10, E.13]` Evidence: `tests/integration/civilian_ai/civilian_audio_panic_count_rebuild_test.gd`

**AC-CAI-6.5 [Logic] [ADVISORY]** — **GIVEN** a `CivilianAIState` dictionary containing an `actor_id` not present in the current section scene, **WHEN** `_restore_state` processes the dictionary, **THEN** the orphaned entry is silently ignored; no error is pushed; civilians present in the scene default to `CALM`. `[Cites: CR-10, E.14, E.15]` Evidence: `tests/unit/civilian_ai/civilian_save_orphan_entry_test.gd`

### Group 7 — Performance Budget

**AC-CAI-7.1 [Integration] [BLOCKING]** — **GIVEN** the constrained-NavMesh reference scene `tests/reference_scenes/restaurant_dense_interior.tscn` (Restaurant geometry: ~12 m × 8 m floor + 1 m exit corridor) with 8 simultaneously PANICKED `CivilianAI` nodes (panic onset at frame 0), **WHEN** `/perf-profile` samples wall-clock cost of `CivilianAI._physics_process()` and `CivilianAI._on_velocity_computed()` (the steady-state nav-feed + move_and_slide path) per physics frame for frames 3 through 303 (frames 1-2 excluded — they are the panic-onset burst window allocated against ADR-0008 reserve, NOT against the steady-state p95 gate), **THEN** the p95 over the 300-sample window is ≤ 0.30 ms (revised 2026-04-25 from 0.15 ms — see F.3); the panic-onset frames 1-2 are separately recorded with cost ≤ 1.5 ms each (allocated to ADR-0008 reserve), and producer + technical-director have signed off on the reserve allocation per ADR-0008 amendment. `[Cites: CR-9, F.3 (revised), ADR-0008 Slot #8 + reserve]` Evidence: `tests/integration/civilian_ai/civilian_performance_budget_test.gd` + `/perf-profile` artifact at `production/qa/evidence/perf-cai-[date].md`. **Reclassified from [Logic] to [Integration] 2026-04-25** (qa-lead + performance-analyst convergent finding — needs full physics scene, not headless GUT).

**AC-CAI-7.2 [Logic] [BLOCKING]** — **GIVEN** all 8 `CivilianAI` nodes are in `CALM` state (PANICKED state not triggered), **WHEN** the performance profile is sampled, **THEN** the per-frame CAI cost is 0 µs (all `_physics_process` disabled; no per-frame work). `[Cites: CR-9, F.3]` Evidence: `tests/unit/civilian_ai/civilian_performance_budget_test.gd`

### Group 8 — Forbidden Patterns (CI Lints)

**Reclassified 2026-04-25 from [Logic] to [Config/Data]** (qa-lead finding: BLOCKING Logic stories require GUT test files per project DoD; CI lint scripts are not GUT tests). Evidence path is the canonical lint script `tools/ci/lint_civilian_ai.sh` — this script must exist before sprint start and must enumerate all forbidden-pattern grep commands literally. Smoke-check pass on the lint script is acceptable evidence per project's testing standards.

**AC-CAI-8.1 [Config/Data] [BLOCKING]** — **GIVEN** the CI lint script `tools/ci/lint_civilian_ai.sh` is invoked from the repository root, **WHEN** the script runs the command `grep -rn --include='*.gd' --exclude-dir=tests "Events\.player_footstep" src/gameplay/ai/`, **THEN** the grep exit code is `1` (no matches found — by `grep` convention, exit code `1` means "pattern not found" and `0` means "found, FAIL"). Comments are NOT excluded from the grep — implementers must not reference `Events.player_footstep` even in comments to avoid false-positives; use a paraphrase if discussing the forbid in a comment. `[Cites: CR-15.1]` Evidence: `tools/ci/lint_civilian_ai.sh` (script must exist; run manually via `bash tools/ci/lint_civilian_ai.sh civilian-footstep` and assert exit 0 from the script wrapper).

**AC-CAI-8.2 [Config/Data] [BLOCKING]** — **GIVEN** the CI lint script runs at MVP, **WHEN** the script runs `grep -rn --include='*.gd' --exclude-dir=tests "Events\.alert_state_changed" src/gameplay/ai/`, **THEN** the grep exit code is `1`. At VS, this AC is gated by `VS_FEATURE_ENABLED` and may relax to allow filtered subscriptions (resolution coord item §F.5#15). `[Cites: CR-15.2]` Evidence: `tools/ci/lint_civilian_ai.sh`.

**AC-CAI-8.3 [Config/Data] [BLOCKING]** — **GIVEN** the CI lint script runs all forbidden-pattern greps, **WHEN** each grep in the script returns, **THEN** every grep exit code is `1` (no matches). The lint script MUST enumerate at minimum these patterns with their exact grep commands (literal regex strings):

```bash
# Pattern 3 (CR-15.3) — direct PlayerCharacter / GuardBase imports
grep -rn --include='*.gd' --exclude-dir=tests \
  -E '^\s*(preload|load)\s*\(\s*"res://.*(player_character|guard_base)' src/gameplay/ai/

# Pattern 4 (CR-15.4) — non-Events/LSS autoload via get_node
grep -rn --include='*.gd' --exclude-dir=tests \
  -E 'get_node\("/root/(?!Events|LevelStreamingService)' src/gameplay/ai/

# Pattern 5 (CR-15.5) — forbidden group adds
grep -rn --include='*.gd' --exclude-dir=tests \
  -E 'add_to_group\("(player|dead_guard|alive_guard)"' src/gameplay/ai/

# Pattern 6 (CR-15.6) — damage-domain emission
grep -rn --include='*.gd' --exclude-dir=tests \
  -E 'Events\.(player_damaged|enemy_damaged|enemy_killed|player_died|weapon_fired|weapon_dry_fire_click)\.emit' src/gameplay/ai/civilian_

# Pattern 7 (CR-15.7) — bare _process override
grep -rn --include='*.gd' --exclude-dir=tests \
  -E '^\s*func\s+_process\s*\(' src/gameplay/ai/civilian_

# Pattern 8 (CR-15.8) — move_and_slide outside velocity_computed callback
# (multiline check — implemented as a Python helper, not raw grep — see lint script)

# Pattern 9 (CR-15.9, refined 2026-04-25) — OutlineTier.set_tier(self, ...)
# (refined to exclude self.mesh_instance_3d false-positive)
grep -rn --include='*.gd' --exclude-dir=tests \
  -E 'OutlineTier\.set_tier\s*\(\s*self\s*,' src/gameplay/ai/

# Pattern 10 (CR-15.10) — bare integer collision layer/mask
grep -rn --include='*.gd' --exclude-dir=tests \
  -E 'set_collision_(layer|mask)_value\s*\(\s*[0-9]+\s*,' src/gameplay/ai/

# Pattern 11 (CR-1a, NEW 2026-04-25) — missing avoidance_enabled init
# (positive-presence check; lint script grep for the init line in civilian_ai.gd)
grep -rn --include='civilian_ai.gd' \
  -E 'nav_agent\.avoidance_enabled\s*=\s*true' src/gameplay/ai/ \
  || (echo "CR-1a violation: missing avoidance_enabled init in civilian_ai.gd"; exit 0)
# (note inverted exit semantics: this grep MUST find the line; missing line = FAIL)

# Pattern 12-13 (NEW 2026-04-25, audio-director ADVISORY-9) — direct Audio API
grep -rn --include='*.gd' --exclude-dir=tests \
  -E 'AudioServer\.|AudioStreamPlayer3?D?\.new\s*\(' src/gameplay/ai/civilian_
```

`[Cites: CR-15, patterns 3-13]` Evidence: `tools/ci/lint_civilian_ai.sh` — the canonical artifact. Script must run cleanly in CI on every PR touching `src/gameplay/ai/civilian_*.gd`. Manual reproduction: `bash tools/ci/lint_civilian_ai.sh all` from repo root.

### Group 9 — VS-Tier Scope Boundaries

**AC-CAI-9.1 [Logic] [BLOCKING]** — **GIVEN** an MVP build (VS feature flag disabled / compile-gated off), **WHEN** a civilian panics and `_trigger_panic` runs, **THEN** `Events.civilian_witnessed_event` is NOT emitted; a signal-emission spy on `Events.civilian_witnessed_event` records zero calls. `[Cites: CR-12, E.31]` Evidence: `tests/unit/civilian_ai/civilian_witness_emission_mvp_inert_test.gd`

**AC-CAI-9.2 [Logic] [BLOCKING]** — **GIVEN** an MVP build, **WHEN** the `CivilianAI` class is inspected at compile time, **THEN** the `WitnessEventType` enum exists on `CivilianAI` with at minimum the stubs `GUNFIRE_NEARBY`, `GUARD_KILLED_NEARBY`, `EVE_BRANDISHING_WEAPON`, `GUARD_BODY_VISIBLE`; `Events.gd` compiles without error referencing the enum. `[Cites: CR-13, ADR-0002 atomic-commit rule]` Evidence: `tests/unit/civilian_ai/civilian_witness_enum_stub_test.gd`

**AC-CAI-9.3 [Logic] [BLOCKING] [VS-only]** — **GIVEN** a VS build (VS feature flag enabled) and a civilian in `CALM` state with `_witnessed_event_already_emitted == false`, **WHEN** `Events.weapon_fired` fires with `position` at distance ≤ `WITNESS_GUNFIRE_RADIUS_M` (18.0 m), **THEN** `Events.civilian_witnessed_event` is emitted exactly once with type `GUNFIRE_NEARBY`; the latch `_witnessed_event_already_emitted` is set to `true`; a second `weapon_fired` within radius fires zero additional emissions. `[Cites: CR-12, F.5]` Evidence: `tests/unit/civilian_ai/civilian_witness_emission_vs_test.gd`

**AC-CAI-9.4 [Logic] [ADVISORY] [VS-only]** — **GIVEN** a VS build with a `BQAContact` civilian (extends `Civilian.tscn`, `is_bqa_contact = true`) and Eve's `CharacterBody3D` outside `BQA_PICKUP_DISTANCE_M` (3.0 m), **WHEN** Eve enters the `Area3D` pickup sphere, **THEN** `OutlineTier.set_tier(mesh_instance_3d, OutlineTier.HEAVIEST)` is called with the `MeshInstance3D` child (not the `CharacterBody3D`); on `body_exited`, `OutlineTier.set_tier(mesh_instance_3d, OutlineTier.LIGHT)` restores the tier. `[Cites: CR-14, CR-15.9]` Evidence: `tests/integration/civilian_ai/civilian_bqa_outline_promotion_test.gd`

### Group 10 — Pillar Coverage

**AC-CAI-10.1 [Integration] [BLOCKING]** — **GIVEN** Eve's `CharacterBody3D` moves past a `CivilianAI` node in `CALM` state and `Events.player_footstep` fires, **WHEN** the civilian's signal handler list is inspected, **THEN** no handler on `CivilianAI` receives `player_footstep`; the civilian's `_panic_state` remains `false`; the civilian does NOT transition to `PANICKED`. `[Cites: CR-11, CR-15.1, Pillar 3 — chorus-not-punisher]` Evidence: `tests/integration/civilian_ai/civilian_footstep_silent_test.gd`

**AC-CAI-10.2 [Integration] [BLOCKING]** — **GIVEN** a Stealth AI guard with an active vision cone overlapping a `CivilianAI` node's position, **WHEN** the guard's perception system runs a vision check against bodies in its detection volume, **THEN** the civilian is rejected by SAI's E.14 group filter (`is_in_group("player")` is `false` AND `body is PlayerCharacter` is `false`); the guard's alert state does NOT change due to the civilian. `[Cites: CR-1, E.16, E.17, Pillar 3]` Evidence: `tests/integration/civilian_ai/civilian_guard_vision_invisible_test.gd`

**AC-CAI-10.3 [Logic] [BLOCKING]** — **GIVEN** a `CivilianAI` node at any state, **WHEN** `receive_damage` is called with any `amount` up to `9999.0` and any valid `source`, **THEN** no HP variable on the civilian reaches zero or negative, no `enemy_killed` signal fires for the civilian, and the civilian node remains `is_inside_tree() == true`. `[Cites: CR-7, Pillar 5 — civilians cannot die]` Evidence: `tests/unit/civilian_ai/civilian_invincibility_test.gd`

**AC-CAI-10.4 [Integration] [ADVISORY] [VS-only]** — **GIVEN** a VS build with a `BQAContact` civilian, **WHEN** Eve's `CharacterBody3D` center is positioned at `(BQA_PICKUP_DISTANCE_M + Eve_capsule_radius + 0.1)` m = `(3.0 + 0.4 + 0.1) = 3.5` m from the civilian center (Eve's body surface 0.1 m outside the pickup sphere boundary), **THEN** after one physics frame for `Area3D` overlap detection to settle: `body_entered` has NOT fired; the civilian renders at `OutlineTier.LIGHT` (Tier 3, 1.5 px); `OutlineTier.set_tier(mesh_instance_3d, OutlineTier.HEAVIEST)` has NOT been called; no quest-indicator HUD element is displayed. **Companion case**: at `(BQA_PICKUP_DISTANCE_M - Eve_capsule_radius - 0.1) = 2.5` m the outline IS promoted. Boundary semantics locked 2026-04-25 to surface-to-surface (qa-lead finding). `[Cites: CR-14, Pillar 2 — discovery rewards patience]` Evidence: `tests/integration/civilian_ai/civilian_bqa_outline_promotion_test.gd`

### AC summary

**Total: 33 ACs** — 28 BLOCKING (24 MVP + 4 VS-only) + 5 ADVISORY (4 MVP + 1 VS-only). Story-type breakdown: 28 Logic + 5 Integration + 0 Visual + 0 UI + 0 Config (CAI is a logic-and-integration system; no Visual ACs because outline rendering is owned by Outline Pipeline, not CAI; no UI ACs because Pillar 5 forbids civilian-specific UI).

## Open Questions

Six open questions surfaced during authoring. Marked **BLOCKING** (must close before sprint start), **VS-only** (must close before VS sprint), or **ADVISORY** (playtest-resolvable).

- **OQ-CAI-1 [BLOCKING for VS sprint] (RECLASSIFIED 2026-04-25 from ADVISORY)** — F.5 witness-latch trade-off. Once a civilian emits `civilian_witnessed_event`, the latch prevents re-emission for the rest of the section. If the second event was geometrically closer or higher-priority (e.g., a civilian witnessed a far-off gunshot, then later sees Eve brandish a weapon at point-blank range), the closer/higher-priority event is suppressed. **This is a Pillar 2 ("Discovery Rewards Patience") liability** (game-designer 2026-04-25 finding): a contact civilian who hears a far-off gunshot can never witness Eve's direct brandishing — the patient observation produces nothing, the contact is wasted. The previous "VS playtest will resolve" gate is too late; this is a design decision, not a tuning question. Two candidate resolutions: (a) extend F.2's proximity-improvement gate to F.5 (closer event clears the latch and re-emits with the new event_type); (b) keep latch as one-shot but add a higher-priority override for `EVE_BRANDISHING_WEAPON` events (these always re-emit regardless of latch). **Owner**: systems-designer + game-designer. **Resolution gate**: BEFORE VS sprint planning, NOT after VS playtest.
- **OQ-CAI-2 [ADVISORY]** — F.4 anchor scoring weight (Euclidean vs path-distance). The current score uses Euclidean distance; an anchor that is geographically near but pathfinding-far (around a wall) may be selected over a more reachable anchor. Mitigation at MVP: §C.3 Phase 2's Phase-3 fallback handles unreachable anchors; RVO+NavMesh path wrap at runtime is acceptable per E.27. Polish-tier improvement: weight by `NavigationServer3D.map_get_path()` length per anchor (more expensive, ~O(n) NavMesh-pathing queries per panic onset). **Owner**: ai-programmer + level-designer. **Resolution gate**: post-MVP polish or VS-tier playtest.
- **OQ-CAI-3 [BLOCKING — engine-verification gate]** — Godot 4.6 NavigationAgent3D `is_navigation_finished()` lag (E.28) AND `_ready()` vs LSS restore-callback ordering (E.11). Two engine behaviors require verification before MVP sprint can confidently green-light the §C.3 algorithm and CR-10 restore path: (1) does `is_navigation_finished()` reliably fire within 1 frame of arrival on Godot 4.6 + Jolt, or does it occasionally lag 2-3 frames (causing E.28 stutter)?; (2) does `LevelStreamingService.register_restore_callback` fire AFTER all civilians' `_ready()` callbacks have registered, even when section instantiation order is non-deterministic? Both items map to existing project engine-verification gate patterns (F&R OQ-FR-8 signal-isolation pattern). **Owner**: gameplay-programmer + godot-specialist. **Resolution gate**: `/engine-verify` MVP sprint pre-gate.
- **OQ-CAI-4 [BLOCKING for VS sprint]** — VS feature flag mechanism. CR-12 + CR-14 require a compile-time gate (`VS_FEATURE_ENABLED` constant) so MVP builds compile out the witness-emission and BQA-promotion paths entirely (E.31 contract). The mechanism (project setting? `class_name CivilianAI extends CharacterBody3D` with `const VS_FEATURE_ENABLED: bool = false` flipped per build target?) is not yet specified by any project-level convention. **Owner**: technical-director + producer. **Resolution gate**: before VS-tier sprint planning.
- **OQ-CAI-5 [BLOCKING for level-designer authoring start] (RECLASSIFIED 2026-04-25 from ADVISORY)** — CALM-state animation ownership. CR-3 says CALM is the entry state but does not specify which node drives ambient animations. Three candidates: (a) CAI script via `AnimationTree.travel("idle")` on `_ready`; (b) MLS T6 scripted-banter authoring (per-NPC scripted state machines); (c) `AnimationTree` node's default state with no script intervention. Most likely (c) for non-banter civilians + (b) for T6 banter NPCs. AC-CAI-1.1 only asserts `_physics_process` disabled, not AnimationTree state. **Reason for reclassification (level-designer 2026-04-25 finding)**: the answer determines level-designer authoring workflow for every section with civilians — option (b) requires per-civilian MLS-T6 trigger authoring, option (c) requires no scripting at all. Level-designer cannot author Plaza, Restaurant, or Eiffel sections without this answer. **Owner**: art-director + level-designer. **Resolution gate**: BEFORE level-designer authors any section scene with civilians; before civilian asset production begins.
- **OQ-CAI-6 [BLOCKING for VS sprint, BLOCKING for MVP playtest] (REVISED scope 2026-04-25 from "MVP playtest only")** — Civilian gasp VO sourcing + asset spec (carried forward from Audio GDD coord item L689). "Mon Dieu!" / "Quoi?!" gasps are period-authenticity-load-bearing audio (Pillar 5). **Reason for revised scope (audio-director 2026-04-25 finding)**: custom VO recording requires 3-4 weeks elapsed time (casting + studio booking + post-processing). The "before MVP playtest" gate was too late — VS sprint integration of `civilian_witnessed_event` + Audio crowd-murmur layer cannot be validated without final gasp samples either. The asset spec is also missing: how many unique voices (the 8-mesh archetype budget implies 4-8 distinct voices?), how many takes per voice, how many line variants ("Mon Dieu!", "Quoi?!", others?), and the localization policy (period-French in all locales by Pillar 5 vs. localized equivalents). **Owner**: audio-director + narrative-director + producer (timeline). **Resolution gate**: asset spec locked AT MVP sprint start; sample library delivery before MVP playtest AND before VS sprint integration.

### Out-of-scope items deferred to post-MVP / post-VS

The following CAI behaviors are **explicitly excluded** to fence against scope creep:

| Excluded behavior | Reason | Authority |
|---|---|---|
| Civilian-to-civilian panic propagation (chain-panic) | Adds complexity without clear gameplay value at MVP/VS scope. Chorus role does not require it. | Scope |
| Civilian dialogue beyond gasps | Dialogue & Subtitles VS owns; CAI publishes signals only. | Pillar 5 + scope |
| Civilian "remembered" panic (a panicked civilian remains afraid in next encounter with Eve) | Anti-pillar — Pillar 3 "Stealth is Theatre" implies sectional reset; cross-section memory is NOLF1-anti-pattern. | Pillar 3 |
| Civilians attacking Eve, attacking guards, or interfering | Anti-pillar — civilians are chorus, not actors. | Pillar 1 |
| Per-civilian schedules / ambient routines beyond `scripted_walk` | MLS Section Authoring Contract owns scripted ambient behavior (T2 environmental gags, T6 banter). CAI is a panic-reactive layer. | MLS scope |
| Civilian death / killable / friendly-fire-vulnerable | CR-7 absolute. | Pillar 5 |
| Multiplayer / co-op / online interaction | Anti-pillar — single-player premium. | Anti-pillar (game-concept.md) |
