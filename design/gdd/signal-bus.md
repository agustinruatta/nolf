# Signal Bus

> **Status**: In Design
> **Author**: User + `/design-system` skill + godot-gdscript-specialist (via ADR-0002)
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Foundation infrastructure — indirectly serves all 5 pillars

## Summary

Signal Bus is the project's typed event hub — a single autoload (`Events.gd`) where every cross-system event in *The Paris Affair* is declared and dispatched. Publishers emit typed signals directly; subscribers connect via the standard `_ready`/`_exit_tree` lifecycle. Implementation contract is locked in **ADR-0002 (Signal Bus + Event Taxonomy)**; this GDD captures the design-level rationale and acceptance criteria.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None (foundational)` · Implementation contract: ADR-0002

## Overview

The Signal Bus is a Foundation-layer infrastructure system. Players never engage with it directly — they engage with its consequences: alert-state music transitions that fire reliably when guards spot Eve, HUD values that update the moment Eve takes damage, document-pickup notifications that appear without delay or duplication. Without a Signal Bus, every system that needs to react to another system's events would either hold direct references to those systems (tight coupling that breaks reorganization), reach into autoload singletons by name to call methods (the autoload-singleton-coupling anti-pattern), or wire signals at scene level (fragile against scene structure changes). Signal Bus replaces all three failure modes with one rule: cross-system events go through `Events.gd`, declared once, consumed by anyone. The full event taxonomy (**34 typed signals across 9 gameplay domains — AI/Stealth, Combat, Player, Inventory, Documents, Mission, Failure & Respawn, Civilian, Dialogue — plus 2 infrastructure domains, Persistence and Settings**; revised 2026-04-20 after ADR-0002 Player-domain amendment of 2026-04-19), the autoload registration order, the subscriber lifecycle pattern, the enum ownership rule, and the 5 forbidden patterns that fence Signal Bus against drift are all specified in ADR-0002. This GDD describes the design-level *why* and the acceptance criteria; ADR-0002 is the implementation contract.

## Player Fantasy

Signal Bus is judged by what the player *doesn't* notice. Specifically, it must prevent these five failure modes:

1. **Music never lags behind alert state** — the moment Eve is spotted, the music shifts. (Serves Pillar 3: *Stealth is Theatre, Not Punishment* — stealth theatre dies the instant audio falls out of sync with AI state.)
2. **The HUD never lies** — health, ammo, gadget readout, and document collection always match reality. The player never takes damage and only sees the health number drop a beat later. (Serves Pillar 5: *Period Authenticity Over Modernization* — the period HUD's authority depends on it being trustworthy.)
3. **Comic beats never miss their cue** — when an environmental gag fires (a champagne flute breaks, a guard double-takes at an absurd document), the visual gesture, the audio sting, and any subsequent dialogue land together as one beat. (Serves Pillar 1: *Comedy Without Punchlines* — comic timing dies on a half-second audio lag.)
4. **Save/load never desynchronises** — reloading a sectional save restores the world to exactly the state shown on screen at save time. The player never sees a guard "remember" they had spotted Eve before the save. (Serves Pillar 3 again — failure must feel fair.)
5. **Systems never race** — the player never sees Audio reacting to one event while AI reacts to a different one in the same frame. Cross-system event ordering is consistent. (Foundational to all 5 pillars.)

These are invisible wins. Players will never praise Signal Bus by name. They will praise the game feeling **solid** — and that solidity is what this system delivers.

## Detailed Design

### Core Rules

1. **Cross-system events flow ONLY through Signal Bus.** Every system that needs to react to another system's events does so by subscribing to a signal on `Events.gd`. No system holds direct references to another system; no system reaches into autoloads to call methods on other systems. This is a **design obligation** for every GDD author, not just an implementation detail.
2. **Every event is in `Events.gd` or it doesn't exist.** A new event signal added to one GDD must be reflected in `Events.gd` BEFORE that GDD ships. The bus is the single source of truth for the event taxonomy.
3. **Publishers emit; subscribers react.** Signal Bus is fire-and-forget. There is no return value, no synchronous callback, no "did anyone hear me?" query. Publishers do not get confirmation that subscribers ran. Subscribers do not get a guarantee that the publisher is still alive.
4. **Subscribers MUST validate Node-typed payloads.** When a signal carries a `Node` (or subclass) parameter, the subscriber MUST call `is_instance_valid(node)` before dereferencing it. Signals can be queued, and the source node may be freed before the subscriber runs. This applies to ~6 of the 12 subscriber systems (any that handle `actor`, `source`, `enemy`, `civilian`, `weapon` parameters). Document this validity guard in every subscriber GDD's interaction notes.
5. **GDD-level enum ownership obligation.** When a GDD introduces a new signal whose payload uses an enum (e.g., `StealthAI.AlertState`), the GDD must declare in its **Dependencies** section which system owns that enum. The bus does not own enums; the system that owns the concept does.
6. **Per-frame-per-multiple-entities events require GDD-level performance notes.** The current 34-signal taxonomy was analyzed in ADR-0002 and confirmed within budget. Any *future* signal that fires per-physics-frame (60/sec) for 3+ entities simultaneously must repeat that analysis in the publishing system's GDD before shipping. No event in the current taxonomy crosses this threshold. Note: `player_footstep` (Player domain, added 2026-04-19) peaks at ~3.5 Hz during Sprint — well within budget.

### States and Transitions

**Stateless infrastructure.** Signal Bus has no states of its own. The `Events.gd` autoload is registered at game start (load order 1) and lives until application exit. The optional `EventLogger.gd` debug autoload (load order 2) self-removes in non-debug builds via `OS.is_debug_build()` check. No transitions, no per-frame lifecycle to track.

### Interactions with Other Systems

The full 34-signal taxonomy is documented in **ADR-0002 Key Interfaces**. The GDD-level summary follows in two parts: a domain summary (orientation) and a consumer matrix (subscriber map). Both updated 2026-04-20 after the ADR-0002 Player-domain amendment.

#### Domain summary

| Domain | Canonical signals | Primary publisher | Has Node payloads? |
|---|---|---|---|
| **AI / Stealth** | `alert_state_changed`, `actor_became_alerted`, `actor_lost_target`, `takedown_performed` | Stealth AI | **Yes** |
| **Combat** | `player_damaged`, `player_health_changed`, `enemy_damaged`, `enemy_killed`, `weapon_fired`, `player_died` | Combat & Damage (player_*) / Stealth AI (enemy_*) / Inventory (weapon_fired) | **Yes** |
| **Player** *(added 2026-04-19)* | `player_interacted`, `player_footstep` | Player Character | `player_interacted` has Node3D payload; `player_footstep` = StringName + float (no Node) |
| **Inventory** | `gadget_equipped`, `gadget_used`, `weapon_switched`, `ammo_changed` | Inventory & Gadgets | No (StringName + ints + Vector3) |
| **Documents** | `document_collected`, `document_opened`, `document_closed` | Document Collection | No (StringName) |
| **Mission** | `objective_started`/`completed`, `section_entered`/`exited`, `mission_started`/`completed` | Mission & Level Scripting | No (StringName) |
| **Failure & Respawn** | `respawn_triggered` | Failure & Respawn | No (StringName) |
| **Civilian** | `civilian_panicked`, `civilian_witnessed_event` | Civilian AI | **Yes** |
| **Dialogue** | `dialogue_line_started`, `dialogue_line_finished` | Dialogue & Subtitles | No (StringName) |
| **Persistence** | `game_saved`, `game_loaded`, `save_failed` | Save / Load | No (int + StringName + enum) |
| **Settings** | `setting_changed` | Settings & Accessibility | No (StringName + Variant) |

#### Consumer matrix

Which systems subscribe to which event domains (✓ = subscribes). Derived from `architecture.yaml` `gameplay_event_dispatch` consumer list and per-system dependency annotations in `systems-index.md`.

| System ↓ \ Domain → | AI | Combat | Player | Inv | Docs | Mission | Fail | Civ | Dlg | Persist | Settings |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Audio | ✓ | ✓ | ✓ | | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ |
| Stealth AI | | ✓ | | | | ✓ | | ✓ | | | |
| Combat & Damage | ✓ | | | | | ✓ | | | | | |
| Inventory & Gadgets | | ✓ | | | | | | | | | |
| Document Collection | | | ✓ | | | ✓ | | | | | |
| Mission & Level Scripting | ✓ | ✓ | | | ✓ | | ✓ | | | | |
| Failure & Respawn | | ✓ | | | | ✓ | | | | | |
| Civilian AI | ✓ | ✓ | | | | | | | | | |
| Dialogue & Subtitles | ✓ | | | | ✓ | | | | | | |
| HUD Core | | ✓ | ✓ | ✓ | | | ✓ | | | | |
| HUD State Signaling | ✓ | ✓ | | | ✓ | ✓ | ✓ | | | | |
| Cutscenes & Mission Cards | | | | | | ✓ | | | | | |
| Save / Load | | | | | | ✓ | | | | | |
| Settings & Accessibility | | | | | | | | | | | |

> Subscribers of any domain marked **"Has Node payloads? Yes"** (AI/Stealth, Combat, Civilian) MUST implement the Rule 4 validity guard for every Node-typed handler. The Player domain's `player_interacted(target: Node3D)` also carries a Node payload (target may be null per PC GDD E.5) and is subject to the same validity guard.

> **Player domain subscribers (added 2026-04-20)**: Audio → `player_footstep` (surface-mapped footstep SFX) + `player_interacted` (interact-confirm chime). HUD Core → `player_interacted` (clear interact-prompt highlight). Document Collection → `player_interacted` (trigger pickup flow on matching target). **Stealth AI MUST NOT subscribe to `player_footstep`** (per ADR-0002 Player-domain delineation + PC GDD F.4) — AI perception reads audibility through PC's `get_noise_level()` / `get_noise_event()` pull methods exclusively.

## Formulas

**None.** Signal Bus is pure infrastructure with no balance values, no scaling curves, no calculations. Per-event signal dispatch cost (~1–5 µs per connected callable per emit) is documented in ADR-0002 Performance Implications as an engine characteristic, not a formula this GDD owns. There are no tunable mathematical relationships within Signal Bus's domain.

Future signals added to the bus may introduce formulas in their owning system's GDD (e.g., a future damage-calculation signal would carry a `damage` value computed by Combat & Damage's formulas). Those formulas live in the publishing system's GDD, not here.

## Edge Cases

- **If a subscriber forgets to disconnect in `_exit_tree`** → the signal connection persists after the node is freed. Next emit may target a freed callable, triggering a Godot error or silent no-op depending on how Godot resolves freed Callables. **Resolution**: every subscriber GDD MUST document the disconnect pattern; code review catches violations. The `is_connected` guard in the disconnect call is mandatory to handle re-entrant `_exit_tree` calls safely.
- **If a subscriber receives a `Node` payload after the source node is freed** → dereferencing the Node will crash or return garbage. **Resolution**: Rule 4 (validate `is_instance_valid(node)` before dereference). Subscribers that fail to validate are bugs, not legitimate edge cases — flag in code review.
- **If two publishers emit the same signal in the same frame** → both calls dispatch to all subscribers in emit order. There is no merging, deduplication, or "latest wins" behaviour. **Resolution**: intended. Signals carry the publisher's intent; if two publishers really did both fire, both dispatches should run. Publishers that should NOT double-fire (e.g., `mission_completed`) must implement publisher-side guards (e.g., a `var _completed: bool` flag).
- **If `EventLogger` is registered but the build is non-debug** → `EventLogger._ready()` calls `queue_free()` and the autoload self-removes. Until that runs (one frame), it may receive events. **Resolution**: `EventLogger`'s self-removal in `_ready()` runs before any user code emits signals (autoload lifecycle order); the one-frame window is empty in practice.
- **If a subscriber's handler raises an error** → Godot prints the error and continues dispatching to remaining subscribers. **Resolution**: intended Godot behaviour. Subscribers MUST handle their own errors (try/except equivalent or defensive coding). A crashing subscriber MUST NOT block other subscribers from receiving the same event.
- **If a new signal is added to `Events.gd` but no subscriber has connected yet** → emitting the signal succeeds with zero dispatches. No error. **Resolution**: intended. Publishers fire-and-forget; lack of subscribers is normal during incremental development.
- **If a subscriber attempts to connect to a signal that doesn't exist on `Events.gd`** → Godot raises a parse-time error (typed signals are checked at parse). **Resolution**: intended. The contract is enforced at parse, not runtime. A subscriber referring to a renamed/removed signal will fail to load — visible immediately, not in production.
- **If `Events.gd` autoload registration order changes** → if `EventLogger` (load order 2) loads before `Events` (load order 1), `EventLogger`'s connect calls fail. **Resolution**: load order is locked in `project.godot` per ADR-0002. Changing autoload order requires an ADR amendment.

## Dependencies

Signal Bus has **no upstream dependencies** — it is a Foundation-layer system that depends only on the Godot engine's autoload + signal mechanism. It does NOT depend on any other game system.

### Downstream dependents (14 systems)

| System | Direction | Nature of Dependency |
|---|---|---|
| Audio (system 3) | Audio → Signal Bus | Subscribes to AI/Stealth + Combat + Mission + Civilian + Dialogue domains. Carries the alert-state-via-music rule. |
| Stealth AI (system 10) | Stealth AI → Signal Bus | **Publishes** AI/Stealth domain (`alert_state_changed`, `actor_became_alerted`, `takedown_performed`). Subscribes to Combat + Mission. **Owns** `StealthAI.AlertState` and `StealthAI.AlertCause` enums. |
| Combat & Damage (system 11) | Combat → Signal Bus | **Publishes** Combat domain. Subscribes to AI + Mission. **Owns** `CombatSystem.DeathCause` enum. |
| Inventory & Gadgets (system 12) | Inventory → Signal Bus | **Publishes** Inventory domain. |
| Document Collection (system 17) | Documents → Signal Bus | **Publishes** Documents domain. Subscribes to Mission. |
| Mission & Level Scripting (system 13) | Mission → Signal Bus | **Publishes** Mission domain. Subscribes to AI + Combat + Documents + Failure. The orchestrator. |
| Failure & Respawn (system 14) | F&R → Signal Bus | **Publishes** `respawn_triggered`. Subscribes to Combat (`player_died`). |
| Civilian AI (system 15) | Civilian → Signal Bus | **Publishes** Civilian domain. Subscribes to AI + Combat. **Owns** `CivilianAI.WitnessEventType` enum. |
| Dialogue & Subtitles (system 18) | Dialogue → Signal Bus | **Publishes** Dialogue domain. Subscribes to AI + Documents (suppression rule from ADR-0004). |
| HUD Core (system 16) | HUD Core → Signal Bus | Subscribes to Combat + Inventory + Failure (read-only listener). Never publishes. |
| HUD State Signaling (system 19) | HUD State Signaling → Signal Bus | Subscribes to AI + Combat + Documents + Mission + Failure (read-only listener). Never publishes. |
| Cutscenes & Mission Cards (system 22) | Cutscenes → Signal Bus | Subscribes to Mission. Never publishes. |
| Save / Load (system 6) | Save/Load → Signal Bus | **Publishes** Persistence domain (`game_saved`, `game_loaded`, `save_failed`). Subscribes to Mission. **Owns** `SaveLoad.FailureReason` enum. |
| Settings & Accessibility (system 23) | Settings → Signal Bus | **Publishes** `setting_changed` (only Variant payload in the entire taxonomy — intentional exception). |

### Engine dependency

Godot 4.6 autoload system + typed signal declarations + callable-based connections (`signal.connect(callable)`). All 4.0+ stable. Script backtracing (4.5+) is leveraged for debug builds but not required.

### ADR contracts

- **ADR-0002**: implementation contract for Signal Bus (autoload structure, 34 signal declarations, naming, lifecycle, anti-patterns).
- **ADR-0001**: independent — no interaction.
- **ADR-0003**: uses 3 Persistence signals defined here.
- **ADR-0004**: UI surfaces subscribe to many signals here; if `ui_context_changed` is ever needed, it must be added to ADR-0002's taxonomy (not implemented as a local InputContext signal — per ADR-0004).

## Tuning Knobs

Signal Bus has **no balance/tuning values** — all design decisions are binary contracts (autoload registered or not, signal exists or not, subscriber connected or not). However, two **operational toggles** exist:

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `EventLogger` enabled | `true` in debug builds, `false` in release (per `OS.is_debug_build()`) | Boolean | Logs every signal emit to the Godot output console — useful for debugging signal flow; verbose in production. | Silences all signal logging; production default. |
| Autoload load order | `Events` = 1, `EventLogger` = 2 | Locked — change requires ADR amendment | Higher numbers load later. Changing breaks `EventLogger`'s ability to subscribe to `Events` signals (it must load AFTER `Events`). | Lower numbers load earlier. If `Events` loads later than systems that subscribe in their own `_ready`, those subscriptions fail at startup. |

Future signals added to the bus may introduce tuning knobs in their owning system's GDD (e.g., a `weapon_fire_rate_hz` value would tune how often `weapon_fired` emits). Those knobs live in the publishing system's GDD, not here.

## Visual/Audio Requirements

**None.** Signal Bus has no visual or audio output. Subscribers may produce visual/audio reactions (Audio plays SFX in response to `weapon_fired`; HUD updates Label text in response to `player_health_changed`), but those reactions are owned by the subscribing systems' GDDs, not by Signal Bus.

## UI Requirements

**None.** Signal Bus is not visible to the player.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| ADR-0002 implementation contract | `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | Full 34-signal taxonomy across 9 gameplay domains + Persistence + Settings, autoload structure, naming, anti-patterns | Implementation contract — this GDD inherits all decisions |
| ADR-0001 stencil tier markers | `docs/architecture/adr-0001-stencil-id-contract.md` | None — independent contracts | No interaction |
| ADR-0003 save signals | `docs/architecture/adr-0003-save-format-contract.md` | `Events.game_saved`, `Events.game_loaded`, `Events.save_failed` defined here | Data dependency (Save/Load publishes these signals) |
| ADR-0004 UI signal subscriptions | `docs/architecture/adr-0004-ui-framework.md` | UI surfaces subscribe to Documents, Combat, Inventory, Mission, Failure, Settings domains | Data dependency (UI consumes these signals) |
| Architecture registry | `docs/registry/architecture.yaml` | `gameplay_event_dispatch` interface contract (event_bus pattern); 5 forbidden patterns | Rule dependency |

## Acceptance Criteria

> *Note: Section C Rule 6 (per-frame performance analysis obligation for future signals) is a process obligation, not a runtime behaviour. It is intentionally out of scope for runtime acceptance testing — enforced via GDD review rather than automated test.*

### Autoload + structural

1. **GIVEN** the project is launched, **WHEN** the autoload list is inspected via `get_tree().root.get_children()`, **THEN** `Events` (load order 1) is present, and `EventLogger` (load order 2) is present in debug builds and absent in release builds.
2. **GIVEN** `Events.gd` source file, **WHEN** linted/grepped for `func `, `var `, or `const ` declarations (excluding the `class_name` and `extends` header), **THEN** zero matches (per ADR-0002 forbidden_pattern `events_with_state_or_methods`).
3. **GIVEN** the 34 signals defined in ADR-0002, **WHEN** `Events.gd` is parsed, **THEN** every signal in ADR-0002's Key Interfaces is declared with the exact signature (name, parameter types, parameter order). The Player domain (`player_interacted`, `player_footstep`) is included in this count per the 2026-04-19 ADR-0002 amendment.

### Dispatch behavior

4. **GIVEN** a subscriber connected to `Events.player_damaged` via `_ready()`, **WHEN** another node calls `Events.player_damaged.emit(10.0, source_node, false)`, **THEN** the subscriber's handler is invoked exactly once with the correct arguments.
5. **GIVEN** two subscribers connected to the same signal, **WHEN** the signal is emitted once, **THEN** both subscribers' handlers are invoked exactly once each, in connection order.
6. **GIVEN** no subscribers connected to `Events.weapon_fired`, **WHEN** `emit` is called, **THEN** no error is raised and no handler runs.

### Subscriber lifecycle

7. **GIVEN** a Node that connects to `Events.player_damaged` in `_ready()` and disconnects with `is_connected` guard in `_exit_tree()`, **WHEN** the Node is freed, **THEN** subsequent emits of `player_damaged` do not target the freed Node and produce no errors.
8. **GIVEN** a Node that forgets to disconnect on `_exit_tree`, **WHEN** the Node is freed and `player_damaged` is emitted, **THEN** Godot prints an error to stderr referencing the freed callable (verifies the failure mode is loud, not silent).

### Anti-pattern enforcement

9. **GIVEN** any system source file, **WHEN** code-reviewed for cross-system communication patterns, **THEN** all cross-system event dispatch is via `Events.signal_name.emit(...)` or `Events.signal_name.connect(...)` — no system holds direct references to or calls methods on another system's autoload (per forbidden_pattern `autoload_singleton_coupling`). *Classification: code-review checkpoint — not automated test; reviewer responsibility.*
10. **GIVEN** any system source file, **WHEN** grepped for `Events\.emit_`, **THEN** zero matches (no wrapper emit methods, per forbidden_pattern `wrapper_emit_methods` — emit is direct via `Events.signal_name.emit(args)`).

### EventLogger debug

11. **GIVEN** the project is launched in debug mode, **WHEN** any `Events` signal is emitted, **THEN** `EventLogger` prints a timestamped line to the Godot output console with the signal name. **AND** in non-debug release export, no such line is printed (`EventLogger` self-removed in `_ready()` via `OS.is_debug_build()` check).

### Subscriber-side correctness (Rule 4 + freed-Node edge case)

12. **GIVEN** any subscriber handler for a signal with a `Node`-typed parameter (e.g., `player_damaged`, `alert_state_changed`, `civilian_panicked`, `actor_became_alerted`), **WHEN** that handler's source is inspected, **THEN** `is_instance_valid(node)` is called before any property or method access on the Node-typed parameter.

### Schema integrity (Rule 5 + taxonomy fence)

13. **GIVEN** `Events.gd` source file, **WHEN** grepped for `enum `, **THEN** zero matches (enums are owned by the system that owns the concept — `StealthAI.AlertState`, `CombatSystem.DeathCause`, `CivilianAI.WitnessEventType`, `SaveLoad.FailureReason` — not by the bus).
14. **GIVEN** all signal declarations in `Events.gd`, **WHEN** grepped for `: Variant`, **THEN** exactly one match exists (`setting_changed` value parameter — the sole intentional Variant exception per ADR-0002).

### Edge case behavior

15. **GIVEN** two publishers emit `mission_completed` in the same frame, **WHEN** the signal is emitted twice, **THEN** subscribers receive two invocations in emit order with no merging or deduplication (validates documented "no deduplication" behaviour from Section E).
16. **GIVEN** subscriber A raises an unhandled error in its handler, **WHEN** the signal is emitted to [A, B] in that order, **THEN** subscriber B's handler is still invoked (validates Godot's continue-on-error dispatch behaviour from Section E).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Should `ui_context_changed` be added to the taxonomy when InputContext (ADR-0004) needs cross-system reactions? | UI Framework GDD authors | Resolved during Document Overlay UI / Menu System GDD authoring | Per ADR-0004: add to ADR-0002 + this GDD's Section C.3 if any non-UI system needs to react to context shifts. Currently no such consumer is identified. |
| What's the canonical workflow to add a new signal to the taxonomy post-MVP? | Lead-programmer | Before first signal addition post-MVP | **Settled 2026-04-19/2026-04-20** via the ADR-0002 Player-domain amendment + Signal Bus GDD 2026-04-20 propagation fix: (1) author a Revision History block in ADR-0002 with the new signals' signatures; (2) update this GDD's Section C.3 domain table + consumer matrix + count in Overview; (3) update AC-3 (current count, now 34); (4) update every subscribing system GDD's subscription list + registry. All four updates MUST land in the same PR as the new signal's first use. |
| Should the lint-style Acceptance Criteria (#2, #10, #13, #14) be wired into CI as automated grep checks? | QA Lead + DevOps | Tier 0 prototype phase | Recommend: yes — these are cheap to automate and catch regressions in seconds. Add to `/test-setup` work. |
