# ADR-0002: Signal Bus + Event Taxonomy

## Status

**Proposed** — moves to Accepted once the `Events` autoload skeleton is registered in `project.godot` and at least one publisher/subscriber pair is implemented and verified end-to-end.

## Date

2026-04-19

## Last Verified

2026-04-22 (OQ-CD-1 SAI amendment bundle + 4th-pass LS + SAI amendment bundle — two Revision History entries dated 2026-04-22)

## Decision Makers

User (project owner) · godot-gdscript-specialist (technical validation) · `/architecture-decision` skill

## Summary

All cross-system events in *The Paris Affair* flow through a single typed-signal autoload (`Events.gd`, flat namespace, `subject_verb_past` naming) — **36 events organized in 9 domains** (a Player domain was added 2026-04-19 during Session B of the Player Character GDD revision; 5 signal signatures were revised 2026-04-22 for the OQ-CD-1 Stealth AI amendment bundle; a 4th-pass 2026-04-22 amendment grew `section_entered` / `section_exited` with a `reason: LevelStreamingService.TransitionReason` 2nd param and added 2 new AI/Stealth signals (`guard_incapacitated`, `guard_woke_up`); see Revision History below). Publishers emit directly (`Events.player_damaged.emit(args)`), subscribers connect/disconnect via the `_ready`/`_exit_tree` lifecycle pattern, and enum types live on the system that owns the concept (not on the bus). The bus contains only signal declarations — no methods, no state, no node references — to prevent the autoload-singleton-coupling anti-pattern.

A companion **Accessor Conventions (SAI → Combat)** subsection (added 2026-04-22) carves out a narrow, principled exception for read-only cross-system state queries that the fire-and-forget bus cannot satisfy. The carve-out is fenced by four exemption criteria and a no-new-accessors-without-amendment rule.

### Revision History

- **2026-04-19 (Session B of Player Character GDD revision, resolving review finding B-2)**: Added **Player** domain with two signals:
  - `player_interacted(target: Node3D)` — fires on reach-complete of a context-sensitive interact. `target` may be `null` (PC GDD edge case E.5: target destroyed during reach animation). Subscribers MUST call `is_instance_valid(target)` before dereferencing, per Implementation Guideline 4.
  - `player_footstep(surface: StringName, noise_radius_m: float)` — fires once per footstep from PlayerCharacter's FootstepComponent. `surface` is a tag from the surface set defined in the Player Character GDD (e.g., `&"marble"`, `&"tile"`). `noise_radius_m` is the noise radius in meters (0–9 m per PC GDD noise table), used by Stealth AI and by Audio to pick SFX variant.

  Neither signal is per-physics-frame: `player_interacted` fires rarely (once per interact); `player_footstep` peaks at ~3.5 Hz during Sprint. Both are safe per Implementation Guideline 5's cadence analysis.

  Rationale for new Player domain (instead of folding into Combat alongside existing `player_damaged/died/health_changed`): the existing Combat-domain `player_*` signals are combat *outcomes* (damage events, death triggered by damage), whereas `player_interacted` and `player_footstep` are player *verbs* (actions the player takes). They belong in a separate domain by publisher intent. The existing Combat `player_*` signals are not moved by this amendment to avoid touching signatures that Session C of the PC GDD revision (B-1) will update independently.

- **2026-04-22 (OQ-CD-1 Stealth AI amendment bundle — resolves Combat & Damage → Stealth AI interface gap)**: Five coordinated signature changes land together. Signal count remains **34**; no signals are added or removed. Enum-ownership list grows by two owners. A new `Accessor Conventions (SAI → Combat)` subsection is introduced as a principled exemption from the autoload / service-locator fences this ADR establishes.

  1. **`alert_state_changed` grows a `severity: StealthAI.Severity` 4th parameter** (was 3 params). `Severity { MINOR, MAJOR }` is owned by `StealthAI` and computed by `compute_severity(new_state, cause)` per stealth-ai.md §C. Consumers (Audio music-cue router, HUD stinger dedupe, Mission triggers) filter on severity without re-deriving from `(new_state, cause)` on every handler.
  2. **`actor_became_alerted` grows a `severity: StealthAI.Severity` 4th parameter** (was 3 params). Same enum; emitted from the same SAI state-transition resolution path.
  3. **`actor_lost_target` grows a `severity: StealthAI.Severity` 2nd parameter** (was 1 param). `DEAD`/`UNCONSCIOUS` terminal-effect emissions fire this as `MAJOR` (decisive outcome — guard removed from play); `SEARCHING`-timeout emissions fire as `MINOR`.
  4. **`takedown_performed` grows from 2 to 3 parameters**: `(actor: Node, target: Node)` → `(actor: Node, attacker: Node, takedown_type: StealthAI.TakedownType)`. `target` is renamed to `attacker` for symmetry with existing damage-domain signals (`player_damaged(source: Node, …)`, `enemy_damaged(source: Node)` — the non-publisher Node is the causer/attacker in every other signal). `takedown_type: StealthAI.TakedownType { MELEE_NONLETHAL, STEALTH_BLADE }` lets Audio route dual SFX variants (chloroform-whoosh vs blade-stroke) without re-querying SAI state.
  5. **`player_died(cause: CombatSystem.DeathCause)` → `player_died(cause: CombatSystemNode.DeathCause)`** — qualified-enum type-name rename. Combat GDD (§317, §350) establishes `class_name CombatSystemNode` registered as autoload key `Combat` — intentionally split, mirroring this ADR's own `class_name SignalBusEvents` / autoload key `Events` pattern. External callers use the autoload name (`Combat.apply_damage_to_actor(...)`); qualified-enum paths use the class name (`CombatSystemNode.DeathCause`). PC GDD and Audio GDD carry frozen signatures referencing the old `CombatSystem` identifier; a coordinated rename pass across those GDDs is flagged for the producer and is **out of scope for this ADR amendment**.

  **Enum-ownership list grows** (Implementation Guideline 2): `StealthAI.Severity { MINOR, MAJOR }` and `StealthAI.TakedownType { MELEE_NONLETHAL, STEALTH_BLADE }` are now owned by the `StealthAI` class. Migration Plan step 2 and Validation Criteria item 3 extended accordingly. `CombatSystem.DeathCause` references in this ADR updated to `CombatSystemNode.DeathCause`; `CombatSystemNode.DamageType` added to the stub-enum list (newly referenced by Combat's public API surface, per combat-damage.md §C.3).

  **New `Accessor Conventions (SAI → Combat)` subsection** is inserted between Key Interfaces and Implementation Guidelines. It declares two SAI-owned public read accessors that Combat polls: `has_los_to_player() -> bool` and `takedown_prompt_active(attacker: Node) -> bool`. Both are read-only, owner-published, stale-safe (SAI's F.1 10 Hz perception cache), and invoked as per-instance method calls on specific guard nodes — NOT via autoload shortcuts. The four exemption criteria and the no-new-accessors-without-amendment fence are documented in the subsection. This carve-out does NOT weaken the `autoload_singleton_coupling`, `events_with_state_or_methods`, `wrapper_emit_methods`, or `synchronous_request_response_through_bus` forbidden patterns; those remain in force.

  **Registry impact**: `docs/registry/architecture.yaml` updated in the same pass. `gameplay_event_dispatch` signal_signature refreshed (34 signals, current sigs); new `sai_public_accessors` interface contract registered (`direct_call` pattern, producer `stealth-ai-system`, consumers `[combat-and-damage-system]`).

- **2026-04-22 (4th-pass LS + SAI amendment bundle — resolves /architecture-review 2026-04-22 Coverage Gap 1 + Conflicts 2 and 3)**: Four coordinated changes land atomically. Signal count grows **34 → 36** (2 new AI/Stealth signals); 2 existing Mission-domain signatures gain a 2nd parameter; enum-ownership list grows by 1.

  1. **`section_entered` grows a `reason: LevelStreamingService.TransitionReason` 2nd parameter** (was 1 param). Subscribers (Audio music-handoff router, Cutscenes first-arrival suppression, Mission Scripting autosave gate on `FORWARD` only) branch on reason without inferring caller intent. `LevelStreamingService` is the sole emitter per level-streaming.md CR-2.
  2. **`section_exited` grows the same `reason: LevelStreamingService.TransitionReason` 2nd parameter** (was 1 param). Same emitter, same consumer set.
  3. **NEW signal `guard_incapacitated(guard: Node)`** added to AI/Stealth domain. Fires from a StealthAI guard node the instant it enters UNCONSCIOUS or DEAD, AFTER perception/navigation cleanup but BEFORE the paired `alert_state_changed(…, UNCONSCIOUS|DEAD, MAJOR)`. Every live guard's VisionCone and dead-body-tracking dictionaries subscribe to explicitly remove the incapacitated body from their tracked-bodies sets. Without this, a dead/unconscious guard lying in another guard's cone (but whose `monitoring = false` prevents natural `body_exited`) would accumulate stale SAW_BODY state indefinitely on reload. Source: stealth-ai.md §Detailed Rules step 5 (UNCONSCIOUS + DEAD terminal entry) + §E.16 (gunfight-kill signal interleaving).
  4. **NEW signal `guard_woke_up(guard: Node)`** added to AI/Stealth domain. Fires once from a StealthAI guard node when the UNCONSCIOUS → SUSPICIOUS wake-up timer expires (`WAKE_UP_SEC = 45 s` default per stealth-ai.md §Detailed Rules UNCONSCIOUS wake-up). Audio subscribes for the wake-sting + ambient-breathing-loop termination; Mission Scripting may subscribe for "Eve killed / woke all guards" objective triggers.

  **Enum-ownership list grows** (Implementation Guideline 2): `LevelStreamingService.TransitionReason { FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE }` is now owned by the `LevelStreamingService` class (autoload load-order 4, `class_name LevelStreamingService` per level-streaming.md CR-1). Migration Plan step 2 and Validation Criteria items 2 and 3 extended accordingly.

  **Cadence guarantees** (Implementation Guideline 5): both new signals are one-shot per guard per session. `guard_incapacitated` fires at most once per guard — terminal-effect transitions are irreversible from the bus's perspective; `UNCONSCIOUS → DEAD` does NOT re-emit `guard_incapacitated` (the guard was already removed from tracked-bodies sets on UNCONSCIOUS entry per stealth-ai.md §E.20). `guard_woke_up` fires at most once per guard — only UNCONSCIOUS guards wake, and wake moves them permanently to SUSPICIOUS. Both are trivially within IG5 budget; no per-physics-frame emission.

  **New Risks row** (added 2026-04-22 via godot-specialist validation of this bundle): enum + signal changes MUST commit atomically. A partial PR where `Events.gd` references `LevelStreamingService.TransitionReason` before the owning script declares the enum causes a GDScript parse failure on project load — the script fails to compile, the `Events` autoload is not registered, and every subscriber that references `Events.*` also fails to parse. The inverse direction (owning script adds the enum first, `Events.gd` not yet updated) is harmless — the enum simply goes unreferenced. Mitigation: single-PR bundling of enum + signal + consumer changes. Optional CI guard: static grep / AST check that every `signal ...(...: X.Y)` token in `events.gd` resolves to a declared enum on class X in the same commit.

  **Registry impact**: `docs/registry/architecture.yaml` updated in the same pass. `gameplay_event_dispatch` signal_signature refreshed (**36 signals**, 4th-pass additions documented inline) with `revised: 2026-04-22`.

  **Downstream scope flagged but out of this amendment** (producer-tracked):
  - `design/gdd/audio.md` §Mission domain handler table (LS GDD line 201; LS-Gate-3): 1-param `section_entered` / `section_exited` handlers must grow the `reason: TransitionReason` 2nd param plus the FORWARD / RESPAWN / NEW_GAME / LOAD_FROM_SAVE branching table from level-streaming.md CR-8. Audio-owned edit, not ADR scope.
  - `design/gdd/player-character.md` lines 200, 457, 591 still reference the frozen `CombatSystem.DeathCause` qualifier (carried over from the prior OQ-CD-1 pass; producer-tracked rename to `CombatSystemNode.DeathCause`).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (signals, autoloads, GDScript types) |
| **Knowledge Risk** | MEDIUM — Callable-based signal connections (4.0+) are in training data; 4.5 added GDScript variadic args, `@abstract`, and script backtracing (post-cutoff but orthogonal to this design); 4.6 is the pinned version. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (Core/Scripting), `deprecated-apis.md` (signal connection patterns) |
| **Post-Cutoff APIs Used** | None as load-bearing dependencies. Script backtracing (4.5) is leveraged for debug only (helpful but not required). |
| **Verification Required** | (1) Confirm typed signal declarations with qualified enum-type parameters (e.g., `signal alert_state_changed(actor: Node, old_state: StealthAI.AlertState, new_state: StealthAI.AlertState)`) compile and dispatch correctly in Godot 4.6 — this is standard 4.0+ syntax but warrants a smoke test. (2) Confirm `EventLogger` debug autoload removes itself in non-debug builds via `OS.is_debug_build()` check. |

> **Note**: MEDIUM Knowledge Risk. The signal/autoload pattern is stable across 4.0–4.6; no breaking changes anticipated for this contract.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — foundational |
| **Enables** | Audio system GDD, Stealth AI GDD, Mission & Level Scripting GDD, all GDDs that reference cross-system events |
| **Blocks** | Audio (system 3), Stealth AI (system 10), Combat & Damage (11), Inventory & Gadgets (12), Mission & Level Scripting (13), Failure & Respawn (14), Civilian AI (15), HUD Core (16), Document Collection (17), Dialogue & Subtitles (18), HUD State Signaling (19), Cutscenes & Mission Cards (22) — 12 system GDDs cannot specify clean event interfaces until this ADR reaches Accepted |
| **Ordering Note** | Sibling to ADR-0001 (Stencil ID Contract); both can be Accepted in parallel. ADRs 3 and 4 (Save Format, UI Framework) may reference signals defined here. |

## Context

### Problem Statement

Without a centralized signal hub, every cross-system communication in *The Paris Affair* would default to one of three failure modes:

1. **Direct system-to-system references** — Stealth AI holds a `Node` reference to Audio; Audio holds a reference to Mission Scripting. Tight coupling that breaks when systems are reorganized, makes systems untestable in isolation, and produces a spaghetti dependency graph.
2. **Autoload service-locator coupling** — every system reaches into autoload singletons by name to call methods. Recognized Godot anti-pattern; breaks when autoload load order changes; hides dependencies; makes unit testing impossible.
3. **Scene-tree signal wiring** — connect signals visually in the editor or via fragile `get_node()` paths. Breaks when scene structure changes; not discoverable from code.

The TD review of `systems-index.md` flagged this gap explicitly: "Audio's GDD cannot specify a clean contract and the 'Audio doesn't depend on AI' claim is only rhetorically true" without a Signal Bus. This ADR establishes the contract before any of the 12 dependent system GDDs is authored.

### Current State

Project is in pre-production. No source code exists. No existing event-dispatch architecture to migrate from.

### Constraints

- **Engine: Godot 4.6, GDScript primary.** Signal/callable connection API is stable since 4.0 (`signal.connect(callable)`); string-based `connect("signal", obj, "method")` is deprecated.
- **Single autoload, flat namespace** — locked design decision (user choice, ADR-0002 Phase 3).
- **Naming convention: `subject_verb_past`** — locked design decision (matches Godot's idiomatic signal style).
- **First-time solo Godot dev** — design must be debuggable, discoverable, and resistant to common Godot pitfalls.
- **Must not become an autoload service-locator anti-pattern.**
- **Must coexist with the direct-call `outline_tier_assignment` contract from ADR-0001** without conflict (different purposes: events vs. API contracts).

### Requirements

- All cross-system events route through one autoload (`Events.gd`).
- Signal declarations are typed; enum parameters use qualified types from the system that owns the concept (no shared `Types.gd`).
- Publishers emit directly via `Events.signal_name.emit(args)`; no wrapper methods on the bus.
- Subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards.
- The bus must support a debug-only event logger (`EventLogger` autoload) without polluting the production code path.
- Engine-built-in signals (e.g., `SceneTree` events) are NOT re-emitted through the bus.

## Decision

**Establish a single autoload `Events.gd` containing only typed signal declarations**, organized in a flat namespace using `subject_verb_past` naming. Define **36 events across 9 gameplay domains** (Player domain added 2026-04-19 via revision B-2; 5 signal signatures revised + 2 new AI/Stealth signals added + 2 Mission-domain signatures grew via two coordinated 2026-04-22 amendments — the OQ-CD-1 Stealth AI bundle and the 4th-pass LS + SAI bundle — see Revision History). Enum types used in signal payloads are defined as inner enums on the **system that owns the concept** (e.g., `StealthAI.AlertState`, `StealthAI.Severity`, `CombatSystemNode.DeathCause`, `LevelStreamingService.TransitionReason`), not on the bus. A narrow `Accessor Conventions` carve-out (added 2026-04-22) governs the read-only method-accessor pattern for state queries the fire-and-forget bus cannot satisfy.

### Architecture

```
                   ┌────────────────────────────────────────┐
                   │  PUBLISHERS (any system that emits)    │
                   │  Stealth AI, Combat, Inventory,        │
                   │  Documents, Mission, Civilian AI,      │
                   │  Save/Load, Settings, Dialogue,        │
                   │  Failure & Respawn                     │
                   └────────────────────┬───────────────────┘
                                        │ Events.signal_name.emit(args)
                                        ▼
        ┌──────────────────────────────────────────────────────────┐
        │  Events.gd  (autoload, load order 1)                     │
        │  ─────────────────────────────────────────────────────── │
        │  ONLY contains typed signal declarations.                │
        │  No methods. No state. No node refs. No wrapper emits.   │
        │  No re-emitting of built-in Godot signals.               │
        │                                                          │
        │  signal player_damaged(amount: float, source: Node, ...) │
        │  signal alert_state_changed(actor: Node, old: ..., ...)  │
        │  signal document_collected(document_id: StringName)      │
        │  ...                                                     │
        └────────────────────┬─────────────────────────────────────┘
                             │ Events.signal_name.connect(callable)
                             ▼
                   ┌────────────────────────────────────────┐
                   │  SUBSCRIBERS (any system that listens) │
                   │  HUD, Audio, Mission, Save/Load,       │
                   │  Cutscenes, Civilian AI, ...           │
                   │                                        │
                   │  _ready():    connect(_handler)        │
                   │  _exit_tree(): if is_connected: disc.  │
                   └────────────────────────────────────────┘

        Optional debug autoload (load order 2):
        ┌──────────────────────────────────────────────────────────┐
        │  EventLogger.gd  — connects to all signals at startup,   │
        │  prints emit timestamps. Self-removes if not is_debug_build│
        └──────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# res://src/core/signal_bus/events.gd
# Autoload registered as `Events` (load order 1) in project.godot

class_name SignalBusEvents extends Node

# ─── AI / Stealth domain ─────────────────────────────────────────────
# Perception signals carry severity (added 2026-04-22 per OQ-CD-1 SAI amendment)
# so consumers can filter without re-deriving severity from (new_state, cause).
# Severity is computed by StealthAI.compute_severity(new_state, cause) per stealth-ai.md §C.
signal alert_state_changed(actor: Node, old_state: StealthAI.AlertState, new_state: StealthAI.AlertState, severity: StealthAI.Severity)
signal actor_became_alerted(actor: Node, cause: StealthAI.AlertCause, source_position: Vector3, severity: StealthAI.Severity)
signal actor_lost_target(actor: Node, severity: StealthAI.Severity)
# takedown_performed: `actor` is the guard taken down; `attacker` is Eve (renamed from
# `target` 2026-04-22 for symmetry with damage-domain `source: Node` payloads);
# `takedown_type` lets Audio route dual SFX variants without re-querying SAI state.
signal takedown_performed(actor: Node, attacker: Node, takedown_type: StealthAI.TakedownType)
# NEW 4th-pass amendment (2026-04-22, bundled with LS TransitionReason below):
# guard_incapacitated fires the instant a guard enters UNCONSCIOUS or DEAD, AFTER
# perception/navigation cleanup but BEFORE the paired alert_state_changed. Every
# live guard's VisionCone + dead-body-tracking dictionaries subscribe to explicitly
# remove the incapacitated body from tracked-bodies sets (see stealth-ai.md step 5
# + §E.16). Cadence: one-shot per guard per session (UNCONSCIOUS → DEAD does NOT
# re-emit; already removed on UNCONSCIOUS entry).
signal guard_incapacitated(guard: Node)
# guard_woke_up fires once when an UNCONSCIOUS guard's wake-up timer (WAKE_UP_SEC =
# 45 s) expires and the guard transitions to SUSPICIOUS. Audio subscribes for the
# wake-sting + ambient-breathing termination; Mission Scripting may subscribe for
# "Eve killed / woke all guards" objective triggers. Cadence: one-shot per guard
# per session (wake moves the guard permanently out of UNCONSCIOUS).
signal guard_woke_up(guard: Node)

# ─── Combat domain ───────────────────────────────────────────────────
signal player_damaged(amount: float, source: Node, is_critical: bool)
signal player_health_changed(current: float, max_health: float)
signal enemy_damaged(enemy: Node, amount: float, source: Node)
signal enemy_killed(enemy: Node, killer: Node)
signal weapon_fired(weapon: Resource, position: Vector3, direction: Vector3)
signal player_died(cause: CombatSystemNode.DeathCause)  # type-name updated 2026-04-22 per combat-damage.md §350 (class_name/autoload split)

# ─── Player domain ───────────────────────────────────────────────────
# Player verbs (actions the player takes). Combat outcomes (damage/death)
# remain in the Combat domain above. Added 2026-04-19 (amendment B-2).
signal player_interacted(target: Node3D)  # target may be null — see Implementation Guideline 4
signal player_footstep(surface: StringName, noise_radius_m: float)

# ─── Inventory domain ────────────────────────────────────────────────
signal gadget_equipped(gadget_id: StringName)
signal gadget_used(gadget_id: StringName, position: Vector3)
signal weapon_switched(weapon_id: StringName)
signal ammo_changed(weapon_id: StringName, current: int, reserve: int)

# ─── Documents domain ────────────────────────────────────────────────
signal document_collected(document_id: StringName)
signal document_opened(document_id: StringName)
signal document_closed(document_id: StringName)

# ─── Mission domain ──────────────────────────────────────────────────
signal objective_started(objective_id: StringName)
signal objective_completed(objective_id: StringName)
# section_entered / section_exited grew a `reason: LevelStreamingService.TransitionReason`
# 2nd param via the 4th-pass amendment (2026-04-22). Subscribers branch on reason
# (FORWARD / RESPAWN / NEW_GAME / LOAD_FROM_SAVE) per level-streaming.md CR-8 —
# Audio music handoff, Cutscenes first-arrival suppression, Mission Scripting
# autosave gate on FORWARD only. LevelStreamingService is the sole emitter of both
# signals per level-streaming.md CR-2.
signal section_entered(section_id: StringName, reason: LevelStreamingService.TransitionReason)
signal section_exited(section_id: StringName, reason: LevelStreamingService.TransitionReason)
signal mission_started(mission_id: StringName)
signal mission_completed(mission_id: StringName)

# ─── Failure / Respawn domain ────────────────────────────────────────
signal respawn_triggered(section_id: StringName)

# ─── Civilian domain ─────────────────────────────────────────────────
signal civilian_panicked(civilian: Node, cause_position: Vector3)
signal civilian_witnessed_event(civilian: Node, event_type: CivilianAI.WitnessEventType, position: Vector3)

# ─── Dialogue domain ─────────────────────────────────────────────────
signal dialogue_line_started(speaker_id: StringName, line_id: StringName)
signal dialogue_line_finished(speaker_id: StringName)

# ─── Persistence domain ──────────────────────────────────────────────
signal game_saved(slot: int, section_id: StringName)
signal game_loaded(slot: int)
signal save_failed(reason: SaveLoad.FailureReason)

# ─── Settings domain ─────────────────────────────────────────────────
# Variant payload is the SOLE intentional Variant in the entire taxonomy —
# settings values are genuinely heterogeneous (bool, int, float, String).
signal setting_changed(category: StringName, name: StringName, value: Variant)
```

```gdscript
# Subscriber pattern — mandatory for every system connecting to Events:

extends Node

func _ready() -> void:
    Events.player_damaged.connect(_on_player_damaged)

func _exit_tree() -> void:
    if Events.player_damaged.is_connected(_on_player_damaged):
        Events.player_damaged.disconnect(_on_player_damaged)

func _on_player_damaged(amount: float, source: Node, is_critical: bool) -> void:
    # Validate node-typed payloads if there's any chance of freed-node delivery:
    if not is_instance_valid(source):
        return
    # ... handle event
```

### Accessor Conventions (SAI → Combat)

*Added 2026-04-22 (OQ-CD-1 Stealth AI amendment bundle).*

The Events bus is fire-and-forget: a publisher emits, subscribers handle later. There is no return value, no single "response", and no synchronous ordering guarantee across subscribers. The `synchronous_request_response_through_bus` forbidden pattern explicitly bans bending the bus into an RPC-like channel.

This leaves a real need unmet. Some gameplay contracts require one system to **read current state from another, synchronously, at call time** — e.g., Combat's per-guard fire controller needs to know "does this specific guard have line-of-sight on the player *right now*?" to decide whether to enter SUPPRESSION fire or direct fire. The natural alternative — reaching into an autoload by name to ask — is the `autoload_singleton_coupling` forbidden pattern, also banned by this ADR.

The OQ-CD-1 amendment introduces the project's first and only sanctioned carve-out: **per-instance read-only accessor methods published by the owning system**.

**Accessors published by StealthAI** (not on `Events.gd`; called on specific guard node instances):

```gdscript
# Methods on class StealthAI extends Node — invoked as guard.has_los_to_player(), etc.

## Returns the current result of SAI's F.1 perception cache for LOS to the player.
## Cache-hit path: no new raycast per call. 10 Hz cache invalidation cadence.
## Stale-safe guarantee: at most 1 physics-frame lag vs. ground truth — acceptable
## for idle-tick consumers (e.g., GuardFireController LOS⇄SUPPRESSION transition).
func has_los_to_player() -> bool

## Returns whether `attacker` is eligible to invoke receive_takedown() on this
## guard right now: alert_state ∈ {UNAWARE, SUSPICIOUS} AND `attacker` is within
## the rear 180° half-cone (dot ≤ 0 convention) AND within TAKEDOWN_RANGE_M (1.5 m)
## AND SAI holds no LOS on the attacker. Read-only; no side effects.
func takedown_prompt_active(attacker: Node) -> bool
```

**Exemption criteria** — all four MUST hold for a method to qualify as an accessor under this convention:

1. **Read-only.** The method MUST NOT mutate state, emit signals, schedule deferred work, or produce side effects of any kind. It returns a value derived from state the owner already holds.
2. **Owner-published.** The method is defined on the owning system's class (`class_name StealthAI`) and invoked on specific node instances via normal reference-holding (ray-hit result, group lookup, scene-tree traversal, parameter passing). It MUST NOT be exposed via autoload shortcut or a static-equivalent accessor on an autoload.
3. **Stale-safe.** Callers MUST be explicitly tolerant of the owner's documented staleness window. For `has_los_to_player`, the window is SAI's F.1 10 Hz cache cadence (≤ 1 physics-frame lag). Every accessor added under this convention MUST document its staleness window and justify caller tolerance.
4. **No request-response over the bus.** The accessor is a direct method call on the owning node, not a signal-query-callback dance through `Events.gd`. The `synchronous_request_response_through_bus` forbidden pattern remains fully in force.

**Fence — no new accessors without an ADR amendment.** "Just adding one more getter" is the service-locator creep path. Any future cross-system read accessor MUST be added to this subsection via an ADR amendment that documents: owner system, consumer system(s), staleness window, and read-only justification. A PR adding a public cross-system read method on a system class without a corresponding entry here MUST be rejected at code review.

**Relationship to `autoload_singleton_coupling`.** This convention does NOT weaken the forbidden pattern. The key distinction is that accessors are called on **specific node instances** a caller already has a reference to — not on autoloads by name. `guard.has_los_to_player()` is a method call on a `Node` the caller holds; `StealthAI.has_los_to_player()` as a static-equivalent on a hypothetical autoload would be service-locator coupling and remains forbidden. The `autoload_singleton_coupling`, `events_with_state_or_methods`, and `wrapper_emit_methods` patterns stay in full force.

**Relationship to Events bus.** Signals and accessors are complementary: signals broadcast *events* (things that happened); accessors answer *questions about current state*. Use signals for any cross-system contract where the producer side has new information to publish; use accessors only where the consumer needs to ask a read-only question the bus cannot answer in time.

### Implementation Guidelines

1. **Autoload registration in `project.godot`**:
   - `Events` — load order 1, path `res://src/core/signal_bus/events.gd`
   - `EventLogger` — load order 2, path `res://src/core/signal_bus/event_logger.gd` (self-removes in non-debug builds via `OS.is_debug_build()`)
2. **Enum ownership**: every enum used in a signal payload is defined as an inner enum on the system class that owns the concept. The signal declaration uses the qualified name (`StealthAI.AlertState`). Do NOT define enums on `Events.gd`. Do NOT create a shared `Types.gd` autoload. **Current owners** (as of 2026-04-22): `StealthAI.AlertState`, `StealthAI.AlertCause`, `StealthAI.Severity` (added 2026-04-22), `StealthAI.TakedownType` (added 2026-04-22), `LevelStreamingService.TransitionReason` (added 2026-04-22 via 4th-pass LS + SAI amendment; class_name `LevelStreamingService`, autoload load order 4 per level-streaming.md CR-1), `CombatSystemNode.DamageType`, `CombatSystemNode.DeathCause` (note: class_name `CombatSystemNode`, autoload key `Combat` — intentional split per combat-damage.md §350), `CivilianAI.WitnessEventType`, `SaveLoad.FailureReason`.
3. **Subscriber lifecycle**: every subscriber MUST connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards. This is non-negotiable for memory-leak prevention and Godot signal hygiene.
4. **Node payload validity**: any subscriber receiving a `Node`-typed parameter MUST call `is_instance_valid(node)` before dereferencing it. Signals can be queued and the source node may be freed before the subscriber runs.
5. **High-frequency events**: all 34 events in this taxonomy are safe to route through the bus at their expected frequencies (per godot-gdscript-specialist analysis: weapon_fired at full-auto rate × 4 subscribers ≈ 0.02 ms/frame; `player_footstep` peaks at ~3.5 Hz during Sprint × typical 2–3 subscribers ≈ negligible). No event in this taxonomy is per-physics-frame.
6. **Engine signals**: do NOT re-emit built-in Godot signals (`SceneTree.node_added`, etc.) through the bus. Systems that need engine signals connect to them directly via `get_tree()`.
7. **`setting_changed` Variant exception**: this is the only Variant payload in the taxonomy. Settings values are genuinely heterogeneous. Future ADRs introducing new signals MUST use explicit types unless they can document an equivalently strong justification.
8. **Debug logger pattern**: `EventLogger.gd` connects to every signal at startup and prints emit timestamps via `print()`. It removes itself in non-debug builds. Do not let production code call `EventLogger` methods.

## Alternatives Considered

### Alternative 1: Distributed signal connections (no bus)

- **Description**: Systems wire signals directly to each other via dependency injection or scene-tree lookup. No central bus.
- **Pros**: More decoupled in theory — each connection is explicit.
- **Cons**: Fragile in practice — every system must know how to find every other system at wire-up time. Order-of-instantiation bugs. Scene reorganizations break wiring. No central place to debug "who's listening to what?". For a first-time solo dev, the cognitive overhead is severe.
- **Estimated Effort**: Higher than chosen approach (every system needs wire-up boilerplate).
- **Rejection Reason**: Pragmatically worse for this team size and skill level. The "more decoupled" theoretical advantage doesn't materialize when the alternative requires every system to participate in a hand-rolled service-discovery scheme.

### Alternative 2: Group-broadcast mediator (Godot `add_to_group` pattern)

- **Description**: Use Godot's group system. Publishers call `get_tree().call_group("audio_listeners", "on_alert_state_changed", ...)`. No autoload, no signals.
- **Pros**: No autoload required; uses an engine-native broadcast mechanism.
- **Cons**: Not typed (group method calls use string names, no compile-time check). No discoverability — you can't see what events exist by reading one file. `call_group` has higher per-call cost than typed signals (string lookup, dispatch on every group member). Doesn't compose with the editor signal connection UI.
- **Estimated Effort**: Comparable to chosen approach.
- **Rejection Reason**: Loses type safety and discoverability — both critical for a maintainable codebase.

### Alternative 3: Typed Event-object dispatch (Java-like event objects)

- **Description**: Define `RefCounted` Event subclasses (`PlayerDamagedEvent`, `AlertStateChangedEvent`, etc.). Publishers emit instances; receivers use `match` to dispatch on type.
- **Pros**: Events are first-class objects; carry rich metadata; can be queued and replayed for debug.
- **Cons**: Significantly more boilerplate per event (one class per event, plus payload fields). Receivers need pattern-matching boilerplate. GDScript's `match` is workable but verbose for this. Over-engineered for a single-player game with ~30 events.
- **Estimated Effort**: 3–4× the chosen approach.
- **Rejection Reason**: Standard Java-pattern overkill for a project this size. Typed signals already provide type safety + discoverability without the class explosion.

### Alternative 4: Multiple per-domain autoloads (`CombatEvents`, `MissionEvents`, etc.)

- **Description**: Same pattern as chosen, but split across multiple autoloads — one per domain.
- **Pros**: Cleaner separation; each autoload is smaller; loading order can be controlled per domain.
- **Cons**: More autoloads to manage; cross-domain events become awkward (which autoload owns `setting_changed`?); discoverability suffers (no single place to see all events).
- **Estimated Effort**: Slightly higher than chosen approach.
- **Rejection Reason**: User explicitly chose flat namespace. The 32-signal flat list is manageable for this project's scope.

## Consequences

### Positive

- One source of truth for cross-system events; new GDDs can reference existing signals or add new ones with a single file edit.
- Type safety from declaration to subscriber callback (qualified enum types prevent passing the wrong enum).
- Discoverability: a developer reading `Events.gd` sees the entire game's event surface in one file.
- Zero coupling between publishers and subscribers — Stealth AI can be implemented and tested without Audio existing yet (as long as Audio's signature contract is honored when it lands).
- Script backtracing (Godot 4.5+) gives meaningful call stacks for signal-driven flows even in Release builds — concrete debugging benefit for a first-time solo dev.
- The autoload service-locator anti-pattern is fenced by 5 explicit forbidden patterns (see Risks → Mitigation).
- `EventLogger` debug pattern lets the developer trace event flow at runtime without modifying production code.

### Negative

- One file (`Events.gd`) is touched by every system that introduces a new event — minor merge-conflict risk for solo dev (acceptable; not a team).
- Subscriber lifecycle (`_ready` connect / `_exit_tree` disconnect) is boilerplate that must be repeated per subscription. Easy to forget; will require code review discipline or a project lint rule.
- Node-typed payloads can deliver freed nodes to subscribers; mitigated by mandating `is_instance_valid()` checks but adds boilerplate.
- Tests cannot rely on autoload load order; tests of subscriber logic must instantiate a local `Events` mock or run in integration mode with the full autoload set.

### Neutral

- The Events autoload is itself a singleton-ish entity — but it does not hold state or expose methods, so it does not exhibit the autoload-singleton-coupling anti-pattern. It IS a global, but a typed one with a single responsibility (signal hub).
- `setting_changed` uses `Variant` payload; this is justified and singled out as the sole exception.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| `Events.gd` drifts toward becoming a service locator (methods, state, query helpers added over time) | MEDIUM | HIGH | Register 5 forbidden patterns in `architecture.yaml` (see Step 6 of `/architecture-decision`). Code review every PR that touches `events.gd`. |
| Subscribers forget to disconnect in `_exit_tree`, causing memory leaks and zombie callbacks | MEDIUM | MEDIUM | Document the subscriber lifecycle pattern in code samples; project-wide lint rule (where feasible) flagging `Events.signal.connect(` without paired `_exit_tree` disconnect. |
| Subscribers receive freed nodes and crash | MEDIUM | MEDIUM | Mandate `is_instance_valid()` check on every Node-typed payload before dereferencing. Document in subscriber pattern template. |
| Engine signals get re-emitted through bus by mistake (creates double-dispatch and ambiguity) | LOW | LOW | Forbidden pattern registered; reviewer responsibility. |
| Wrapper emit methods get added "for convenience" (e.g., `Events.emit_player_damaged(amount, source)`) | MEDIUM | MEDIUM | Forbidden pattern registered. The marginal convenience does not justify weakening the bus's "signals only" rule. |
| Synchronous request-response patterns get implemented through the bus (e.g., a "query" signal expecting a callback to be set on the payload) | LOW | HIGH | Forbidden pattern registered. Use direct method calls for request-response; the bus is fire-and-forget only. |
| Future ADR adds an enum directly on `Events.gd` instead of on its owning system | MEDIUM | LOW | Documented in Implementation Guidelines item 2; reviewer responsibility. |
| Inner enums added to an existing owning class (e.g., new `StealthAI.*` enum) after `Events.gd` is first compiled may require a manual editor reimport / full-project recompile cycle to resolve correctly (godot-specialist validation 2026-04-22). | LOW | LOW | Editor workflow nuance, not a runtime defect. Mitigation: after adding a new inner enum that a signal declaration references, reimport the project (Project → Tools → Reload Current Project, or close/reopen) before relying on the signal dispatch. Headless CI does a clean recompile and is unaffected. |
| Accessor Conventions subsection drifts toward service-locator (methods accumulate via "just one more getter" PRs) | MEDIUM | HIGH | Fence clause: no new accessors without an ADR amendment. Code review every PR adding a public cross-system read method on any system class. Current list (2026-04-22): 2 accessors on `StealthAI` for `combat-and-damage-system` consumption. |
| Inner-enum additions + new signal declarations MUST commit atomically across SAI, LS, and `Events.gd`. A partial PR where `Events.gd` references a qualified enum type (e.g., `LevelStreamingService.TransitionReason`) before the owning script declares it produces a **GDScript parse failure on project load** — the script fails to compile, the `Events` autoload is not registered, and every subscriber that references `Events.*` also fails to parse. The inverse direction (owning script adds enum first, `Events.gd` not yet updated) is harmless — the enum simply goes unreferenced. (godot-specialist validation 2026-04-22 during 4th-pass LS + SAI amendment bundle.) | LOW | HIGH | Bundle all enum declarations and signal references in a single PR. Optional CI guard: static grep / AST check that every `signal ...(...: X.Y)` token in `events.gd` resolves to a declared enum on class X in the same commit. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (signal dispatch overhead) | N/A | 1–5 µs per connected callable per emit | No specific budget — sub-millisecond aggregate even at full-auto weapon_fired (≈0.02 ms/frame for 15 emits/sec × 4 subscribers) |
| Memory (Events autoload static cost) | N/A | <10 KB (signal declarations + autoload node) | N/A |
| Memory (per active subscription) | N/A | ~100 bytes per `Callable` connection | N/A |
| Load Time | N/A | <1 ms autoload registration | N/A |

> No event in the proposed taxonomy is per-physics-frame. Per-frame budget impact is negligible for this game's scope.

## Migration Plan

This is the project's second ADR. No existing code to migrate. Implementation order:

1. Create `res://src/core/signal_bus/events.gd` with the 34 typed signal declarations.
2. Define stub enum classes for the systems that own them (`StealthAI.AlertState`, `StealthAI.AlertCause`, `StealthAI.Severity`, `StealthAI.TakedownType`, `LevelStreamingService.TransitionReason`, `CombatSystemNode.DamageType`, `CombatSystemNode.DeathCause`, `CivilianAI.WitnessEventType`, `SaveLoad.FailureReason`) so the signal declarations compile. Stubs may be empty enum bodies until the owning system's GDD is authored — they serve as type placeholders. **Post-amendment note (2026-04-22)**: adding a new inner enum to an already-compiled owner class may require an editor reimport cycle for the signal dispatch to resolve correctly (see Risks).
3. Register `Events` as autoload in `project.godot`, load order 1.
4. Create `res://src/core/signal_bus/event_logger.gd` with self-removal logic. Register as autoload, load order 2.
5. Smoke test: emit one signal from a debug script, confirm `EventLogger` prints it, confirm a subscriber receives it.
6. Set ADR-0002 status Proposed → Accepted.
7. Begin authoring system GDDs that reference these signals.

**Rollback plan**: If the typed-signal pattern proves problematic in practice (e.g., enum forward-reference issues compiling Events.gd before the system scripts), fall back to using `int` for enum payloads with constants declared on Events.gd as a temporary measure. This is a small revision, not a fundamental rethink.

## Validation Criteria

- [ ] `Events.gd` autoload registered in `project.godot`, load order 1.
- [ ] All 36 typed signals declared with qualified enum-type parameters (where applicable).
- [ ] Stub enum classes exist for `StealthAI.AlertState`, `StealthAI.AlertCause`, `StealthAI.Severity`, `StealthAI.TakedownType`, `LevelStreamingService.TransitionReason`, `CombatSystemNode.DamageType`, `CombatSystemNode.DeathCause`, `CivilianAI.WitnessEventType`, `SaveLoad.FailureReason` — they may be empty enum bodies until the owning system is designed.
- [ ] `Accessor Conventions (SAI → Combat)` subsection's two accessors are implemented on `StealthAI`: `has_los_to_player() -> bool` (F.1 cache-hit path, 10 Hz stale-safe) and `takedown_prompt_active(attacker: Node) -> bool` (state + rear-arc + range + no-LOS predicate, read-only).
- [ ] `EventLogger.gd` autoload registered, load order 2; self-removes in non-debug build (verify with a release export).
- [ ] One smoke test: emit one signal, confirm subscriber receives it AND `EventLogger` prints it.
- [ ] Subscriber lifecycle pattern documented in `docs/architecture/control-manifest.md` (when that file is authored).
- [ ] 5 forbidden patterns registered in `docs/registry/architecture.yaml`.
- [ ] No methods, state, or node references added to `Events.gd` (verified by code review on every PR touching that file).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/systems-index.md` | Audio (system 3) | "Carries alert-state signaling (NOLF1 rule) — load-bearing from frame one" | `alert_state_changed` and `actor_became_alerted` signals let Audio subscribe to AI state without coupling. Audio reacts to events; Audio's design does not depend on AI's existence at design time. |
| `design/gdd/systems-index.md` | Stealth AI (system 10) | "Graduated, reversible alert states" | AI publishes `alert_state_changed` on every state transition; subscribers receive the full transition (old + new state). Reversibility is a publisher concern; the bus carries the events. |
| `design/gdd/systems-index.md` | Mission & Level Scripting (system 13) | "Trigger system, scripted events, mission state, objective tracking" | `objective_started`, `objective_completed`, `section_entered/exited`, `mission_started/completed` give scripts a clean publish path; subscribers (HUD, Cutscenes, Save/Load) react. |
| `design/gdd/systems-index.md` | HUD Core / HUD State Signaling | "Health/ammo readout; alert indicator; pickup notifications" | `player_health_changed`, `ammo_changed`, `alert_state_changed`, `document_collected` give the HUD all data via the bus — no HUD-side polling, no direct system queries. |
| `design/gdd/systems-index.md` | Failure & Respawn (system 14) | "Failure trigger; sectional restart contract" | `player_died` triggers; `respawn_triggered` notifies Mission Scripting and Save/Load to restore section state. |
| `design/art/art-bible.md` | Audio direction (Section 2 mood arc + alert-state-via-music rule) | "Alert state changes signaled through music and audio, NOT visuals" | The `alert_state_changed` signal IS the contract Audio uses to swap music. Without this, the user-locked rule (`feedback_visual_state_signaling` memory) cannot be implemented cleanly. |

## Related

- **ADR-0001** (Stencil ID Contract) — sibling foundational ADR; establishes the `direct_call` pattern for one specific contract. ADR-0002 establishes the `event_bus` pattern for everything else, plus a narrow `direct_call` carve-out for SAI → Combat read accessors (2026-04-22). They coexist without conflict.
- **ADR-0003** (Save Format Contract — pending) — will reference `game_saved`, `game_loaded`, `save_failed` signals defined here.
- **ADR-0004** (UI Framework — pending) — will reference `document_opened`, `document_closed`, `setting_changed` signals defined here. Must NOT redefine these.
- **`docs/registry/architecture.yaml`** — 5 forbidden patterns and 2 interface contracts registered from this ADR: `gameplay_event_dispatch` (event_bus) and `sai_public_accessors` (direct_call, added 2026-04-22).
- **`design/gdd/stealth-ai.md`** — owner of `AlertState`, `AlertCause`, `Severity`, `TakedownType` enums and the two public accessors this ADR codifies. 3rd-pass revision (2026-04-22) authored the source-of-truth specification for OQ-CD-1. 4th-pass revision (2026-04-22) added the `guard_incapacitated` signal (§Detailed Rules step 5 UNCONSCIOUS/DEAD terminal entry + §E.16) and `guard_woke_up` signal (§Detailed Rules UNCONSCIOUS wake-up; `WAKE_UP_SEC = 45`), both declared in Key Interfaces above.
- **`design/gdd/level-streaming.md`** — owner of the `TransitionReason` enum on `class_name LevelStreamingService` (autoload load-order 4). LS-Gate-1 (per LS GDD §Pre-Implementation Gates) — amend `section_entered`/`section_exited` with the `reason` 2nd param — is resolved by this 4th-pass amendment. LS-Gate-3 (Audio GDD handler-table amendment for the 2-param form + branching) is producer-tracked and out of ADR scope.
- **`design/gdd/combat-damage.md`** — owner of `DamageType`, `DeathCause` enums (class_name `CombatSystemNode`, autoload key `Combat`). §C.3 documents the dependency on SAI's public accessors; §317 + §350 document the class_name/autoload split this amendment aligns.
- **`design/gdd/audio.md`** — consumer of the 4-param `alert_state_changed` and `actor_became_alerted` severity-filter rules + `takedown_performed` dual-SFX routing. Audio GDD already specifies the post-amendment signatures (§61, §143–146); this ADR amendment formalizes them.
- **`design/gdd/signal-bus.md`** — enum-ownership index mirrors Implementation Guideline 2. Updated in the same 2026-04-22 pass to add `Severity` + `TakedownType` and rename `CombatSystem` → `CombatSystemNode`.
- **Future system GDDs** (remaining dependents) — will consume the signal taxonomy and may add new signals to `Events.gd` following the locked conventions.
- **`feedback_visual_state_signaling` memory** — the NOLF1 fidelity rule that alert state is signaled through music/audio depends on this ADR existing.
