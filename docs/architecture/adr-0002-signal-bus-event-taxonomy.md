# ADR-0002: Signal Bus + Event Taxonomy

## Status

**Proposed** — moves to Accepted once the `Events` autoload skeleton is registered in `project.godot` and at least one publisher/subscriber pair is implemented and verified end-to-end.

## Date

2026-04-19

## Last Verified

2026-04-19

## Decision Makers

User (project owner) · godot-gdscript-specialist (technical validation) · `/architecture-decision` skill

## Summary

All cross-system events in *The Paris Affair* flow through a single typed-signal autoload (`Events.gd`, flat namespace, `subject_verb_past` naming) — **34 events organized in 9 domains** (a Player domain was added 2026-04-19 during Session B of the Player Character GDD revision; see Revision History below). Publishers emit directly (`Events.player_damaged.emit(args)`), subscribers connect/disconnect via the `_ready`/`_exit_tree` lifecycle pattern, and enum types live on the system that owns the concept (not on the bus). The bus contains only signal declarations — no methods, no state, no node references — to prevent the autoload-singleton-coupling anti-pattern.

### Revision History

- **2026-04-19 (Session B of Player Character GDD revision, resolving review finding B-2)**: Added **Player** domain with two signals:
  - `player_interacted(target: Node3D)` — fires on reach-complete of a context-sensitive interact. `target` may be `null` (PC GDD edge case E.5: target destroyed during reach animation). Subscribers MUST call `is_instance_valid(target)` before dereferencing, per Implementation Guideline 4.
  - `player_footstep(surface: StringName, noise_radius_m: float)` — fires once per footstep from PlayerCharacter's FootstepComponent. `surface` is a tag from the surface set defined in the Player Character GDD (e.g., `&"marble"`, `&"tile"`). `noise_radius_m` is the noise radius in meters (0–9 m per PC GDD noise table), used by Stealth AI and by Audio to pick SFX variant.

  Neither signal is per-physics-frame: `player_interacted` fires rarely (once per interact); `player_footstep` peaks at ~3.5 Hz during Sprint. Both are safe per Implementation Guideline 5's cadence analysis.

  Rationale for new Player domain (instead of folding into Combat alongside existing `player_damaged/died/health_changed`): the existing Combat-domain `player_*` signals are combat *outcomes* (damage events, death triggered by damage), whereas `player_interacted` and `player_footstep` are player *verbs* (actions the player takes). They belong in a separate domain by publisher intent. The existing Combat `player_*` signals are not moved by this amendment to avoid touching signatures that Session C of the PC GDD revision (B-1) will update independently.

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

**Establish a single autoload `Events.gd` containing only typed signal declarations**, organized in a flat namespace using `subject_verb_past` naming. Define **34 events across 9 gameplay domains** (Player domain added 2026-04-19 via revision B-2 — see Revision History). Enum types used in signal payloads are defined as inner enums on the **system that owns the concept** (e.g., `StealthAI.AlertState`), not on the bus.

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
signal alert_state_changed(actor: Node, old_state: StealthAI.AlertState, new_state: StealthAI.AlertState)
signal actor_became_alerted(actor: Node, cause: StealthAI.AlertCause, source_position: Vector3)
signal actor_lost_target(actor: Node)
signal takedown_performed(actor: Node, target: Node)

# ─── Combat domain ───────────────────────────────────────────────────
signal player_damaged(amount: float, source: Node, is_critical: bool)
signal player_health_changed(current: float, max_health: float)
signal enemy_damaged(enemy: Node, amount: float, source: Node)
signal enemy_killed(enemy: Node, killer: Node)
signal weapon_fired(weapon: Resource, position: Vector3, direction: Vector3)
signal player_died(cause: CombatSystem.DeathCause)

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
signal section_entered(section_id: StringName)
signal section_exited(section_id: StringName)
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

### Implementation Guidelines

1. **Autoload registration in `project.godot`**:
   - `Events` — load order 1, path `res://src/core/signal_bus/events.gd`
   - `EventLogger` — load order 2, path `res://src/core/signal_bus/event_logger.gd` (self-removes in non-debug builds via `OS.is_debug_build()`)
2. **Enum ownership**: every enum used in a signal payload is defined as an inner enum on the system class that owns the concept. The signal declaration uses the qualified name (`StealthAI.AlertState`). Do NOT define enums on `Events.gd`. Do NOT create a shared `Types.gd` autoload.
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
2. Define stub enum classes for the systems that own them (`StealthAI.AlertState`, etc.) so the signal declarations compile. Stubs may be empty enum bodies until the owning system's GDD is authored — they serve as type placeholders.
3. Register `Events` as autoload in `project.godot`, load order 1.
4. Create `res://src/core/signal_bus/event_logger.gd` with self-removal logic. Register as autoload, load order 2.
5. Smoke test: emit one signal from a debug script, confirm `EventLogger` prints it, confirm a subscriber receives it.
6. Set ADR-0002 status Proposed → Accepted.
7. Begin authoring system GDDs that reference these signals.

**Rollback plan**: If the typed-signal pattern proves problematic in practice (e.g., enum forward-reference issues compiling Events.gd before the system scripts), fall back to using `int` for enum payloads with constants declared on Events.gd as a temporary measure. This is a small revision, not a fundamental rethink.

## Validation Criteria

- [ ] `Events.gd` autoload registered in `project.godot`, load order 1.
- [ ] All 34 typed signals declared with qualified enum-type parameters (where applicable).
- [ ] Stub enum classes exist for `StealthAI.AlertState`, `StealthAI.AlertCause`, `CombatSystem.DeathCause`, `CivilianAI.WitnessEventType`, `SaveLoad.FailureReason` — they may be empty enum bodies until the owning system is designed.
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

- **ADR-0001** (Stencil ID Contract) — sibling foundational ADR; establishes the `direct_call` pattern for one specific contract. ADR-0002 establishes the `event_bus` pattern for everything else. They coexist without conflict.
- **ADR-0003** (Save Format Contract — pending) — will reference `game_saved`, `game_loaded`, `save_failed` signals defined here.
- **ADR-0004** (UI Framework — pending) — will reference `document_opened`, `document_closed`, `setting_changed` signals defined here. Must NOT redefine these.
- **`docs/registry/architecture.yaml`** — 5 new forbidden patterns and 1 interface contract registered from this ADR.
- **Future system GDDs** (12 systems blocked by this ADR) — will consume the signal taxonomy and may add new signals to `Events.gd` following the locked conventions.
- **`feedback_visual_state_signaling` memory** — the NOLF1 fidelity rule that alert state is signaled through music/audio depends on this ADR existing.
