# ADR-0007: Autoload Load Order Registry

## Status

**Accepted** — promoted 2026-04-29 after Sprint 01 Technical Verification Spike:
(a) `project.godot` `[autoload]` block generated with the 10-entry line order
specified in §Key Interfaces (Group 1.4 — verbatim match including `*res://`
prefix on every entry), and (b) ADR-0002 Gate 1 smoke test passed
(`prototypes/verification-spike/signal_bus_smoke.tscn` headless run on
Godot 4.6.2 stable; EventLogger at autoload line 2 successfully connected to
`Events.smoke_test_pulse` declared on the line-1 autoload from its `_ready()`,
proving the engine's line-order-based cross-autoload reference safety discipline
specified in §Cross-Autoload Reference Safety holds in practice). All 9
non-skeleton autoload paths resolve to stub scripts (`extends Node` pass-through)
created in Sprint 01 Group 1 follow-up; production implementations land in their
respective system stories. Verification log: `prototypes/verification-spike/verification-log.md`.

## Date

2026-04-23

## Last Verified

2026-04-29 (Sprint 01 Technical Verification Spike — both gates passed; Status flipped Proposed → Accepted; see Revision History entry below). Prior: 2026-04-27 (Amendment — F&R + MLS + SettingsService autoload inclusion; resolves `/review-all-gdds 2026-04-27` Blocker B2 (3-way slot-#8 conflict). See Revision History below.)

## Decision Makers

User (project owner) · godot-specialist (validation 2026-04-22 §1 + 2026-04-23
pre-authoring Claims 1/2/3) · `/architecture-decision` skill

## Summary

*The Paris Affair* registers **10 autoloads** (6 original + 1 via the 2026-04-23 amendment + 3 via the 2026-04-27 amendment — see Revision History below) in a single canonical order that this ADR defines and owns:

**Events (1) → EventLogger (2) → SaveLoad (3) → InputContext (4) → LevelStreamingService (5) → PostProcessStack (6) → Combat (7) → FailureRespawn (8) → MissionLevelScripting (9) → SettingsService (10)**

The engine only honours line order within the `project.godot [autoload]` block —
"load order N" labels in ADRs and GDDs are team-documentation and drift-prone. This
ADR supersedes every "load order N" statement in existing ADRs/GDDs with a pointer
to this registry. Adding a new autoload, removing one, or changing the order
requires an amendment to this ADR in the same PR that edits `project.godot`. A
forbidden pattern (`unregistered_autoload`) fences against ad-hoc registration via
editor plugins, `@tool` scripts, or `add_autoload_singleton()` runtime calls.

### Revision History

- **2026-04-29 (Verification — Sprint 01 Gates G(a) + G(b) PASS; Status: Proposed → Accepted)**: Sprint 01 Technical Verification Spike closed both verification gates.
  - **Gate (a)** — `project.godot [autoload]` block byte-match against §Key Interfaces: ✅ PASS. Group 1.4 wrote the 10-entry block with the exact line order + `*res://` prefix specified in §Key Interfaces; the user opened the project in Godot 4.6.2 editor (which preserved the autoload entries verbatim through its rewrite pass); the 9 non-skeleton autoload paths now resolve to stub scripts (`extends Node` pass-through) created in the Group 1 follow-up so the editor no longer logs "Script not found" for them.
  - **Gate (b)** — ADR-0002 G1 smoke test (incidentally validates Cross-Autoload Reference Safety): ✅ PASS. `prototypes/verification-spike/signal_bus_smoke.tscn` ran headless on Godot 4.6.2 stable (Linux Vulkan); EventLogger at autoload line 2 successfully connected to `Events.smoke_test_pulse` (declared on the line-1 autoload) from its `_ready()`, proving §Cross-Autoload Reference Safety rule 2 ("an autoload's `_ready()` MAY reference any earlier autoload by name") holds in practice. The smoke test scene's Check 3 explicitly verifies that EventLogger is registered as a subscriber on `Events.smoke_test_pulse` — if the line-order discipline had failed, the connection would have null-derefed and Check 3 would have failed.
  - **Specialist Claims 1/2/3 status**: godot-specialist 2026-04-23 pre-authoring consultation rated the three claims GREEN/YELLOW/YELLOW. The verification result confirms Claim 1 (line-order authority — GREEN remains GREEN) and Claim 2 (cross-autoload `_ready` reference safety — YELLOW upgraded toward GREEN by empirical confirmation; the framing-correction language about `_init()` vs `_ready()` distinction in §Cross-Autoload Reference Safety remains correct as written). Claim 3 (tooling stability — `@tool` scripts and runtime singleton registration) was not exercised by the spike because no plugins or `@tool` scripts exist; the fence (Implementation Guideline 6 + `unregistered_autoload` forbidden pattern) remains in force as a forward defense.
  - **Cross-document closure**: closes ADR-0007 verification gates (Validation Criteria items 1 + 2). ADR-0002 G1 closes via the same evidence and is also Accepted as of 2026-04-29.
  - **Status flipped**: Proposed → Accepted. Together with ADR-0002 (Accepted same day) and ADR-0003 (Accepted same day per A5), the foundational signal-bus + save + autoload triplet is now Accepted.

- **2026-04-27 (F&R + MLS + SettingsService autoload inclusion — `/review-all-gdds 2026-04-27` B2 resolution)**: Canonical autoload count grows **7 → 10**. `FailureRespawn` (`class_name FailureRespawnService`, autoload key `FailureRespawn`) is added at line 8 after `Combat`; `MissionLevelScripting` (autoload key `MissionLevelScripting`) is added at line 9 after `FailureRespawn`; `SettingsService` (autoload key `SettingsService`) is added at line 10 after `MissionLevelScripting`. Trigger: three independent forward-claims on slot #8 across `failure-respawn.md:271/:309/:494`, `settings-accessibility.md:60` (CR-3), and `document-collection.md` (parenthetical) surfaced as Blocker B2 in the cross-GDD review at `design/gdd/gdd-cross-review-2026-04-27.md`. **MLS-after-F&R is the hard edge** (MLS subscribes to `Events.respawn_triggered` per F&R coord item #1; if MLS's `_ready()` connects before F&R is in the tree the reference is `null` per Cross-Autoload Reference Safety rule 3). Settings has no autoload-init-time dependency on F&R/MLS (consumers use the `settings_loaded` one-shot pattern per `settings-accessibility.md` CR-9, not direct `_ready()` reads), so Settings goes last at line 10. The `settings-accessibility.md:60` slot-#8 misclaim is corrected to "per ADR-0007 line 10" in the paired sweep. The `document-collection.md` 6-site "F&R = #8, MLS = #9" parenthetical (W7) is stripped to "per ADR-0007" in the same sweep — DC remains non-autoload regardless of slot ordering downstream.

  Changes landing in this amendment: Summary paragraph ("7 autoloads" → "10 autoloads"; chain grows `... → Combat (7) → FailureRespawn (8) → MissionLevelScripting (9) → SettingsService (10)`); Canonical Registration Table (rows 8/9/10 added); Rationale for line order (bullets 8/9/10 added); Key Interfaces GDScript block (three lines appended); Alternatives Considered (Amendment Alternative Paths 2026-04-27 subsection added); Consequences → Positive (bullet added); Performance Implications (7→10 node counts); Validation Criteria Gate 1 (7→10 entry count); GDD Requirements Addressed → Direct GDD drivers (failure-respawn.md / mission-level-scripting.md / settings-accessibility.md rows added); Downstream sites requiring paired text edits (4 GDDs added: F&R, MLS, Settings, DC); Related (3 entries added).

  **Registry impact**: `docs/registry/architecture.yaml` → `autoload_registration_order` api_decisions row `api:` field updated from 7-autoload enumeration to 10-autoload enumeration; `revised: 2026-04-27`. No new forbidden patterns; the existing `unregistered_autoload` and `autoload_init_cross_reference` fences apply to the three new entries identically.

  **Rules unchanged**: §Cross-Autoload Reference Safety (rules 1–5), §Implementation Guidelines (1–7), §Risks, §Engine Compatibility, and §ADR Dependencies (top-line "Depends On: None — foundational" unchanged; ADR-0002 + ADR-0003 + ADR-0004 remain *referenced but not Acceptance-blocking* dependencies).

  **Status unchanged**: this ADR remains **Proposed**. Amendment does not retire Gate 1 (`project.godot [autoload]` byte-match gate) or Gate 2 (ADR-0002 Gate 1 smoke test) — both apply to the updated 10-entry table.

  **Cross-document closure**: this amendment closes `/review-all-gdds 2026-04-27` Blocker B2. The 4 paired GDD sweeps close W7 (DC parenthetical) and contribute to closing the related propagation Warnings. Re-running `/review-all-gdds` after this amendment + its paired sweeps + the B1/B3/B6 sweeps in their own PRs is the path back to PASS.

- **2026-04-23 (Combat autoload inclusion — Phase 5 §6.3 cross-session conflict resolution)**: Canonical autoload count grows **6 → 7**. `Combat` (`class_name CombatSystemNode`, autoload key `Combat`) is added at line 7 after `PostProcessStack`. Trigger: the Combat autoload claim declared by ADR-0002 OQ-CD-1 bundle (2026-04-22) and combat-damage.md §350 (TR-CD-022) was not reflected in this ADR's original 6-autoload canonical registration table — a scope omission surfaced during `/create-architecture` Phase 4 API-Boundaries authoring (2026-04-23) and tracked as architecture.md §6.3 + §7.2.1 + §9.2. **Path A** endorsed by godot-specialist consultation 2026-04-23: amend this ADR rather than downgrade Combat from autoload to scene-tree singleton (Path B, fan-out anti-pattern) or defer (Path C, leaves TR-CD-022 + ADR-0002 in false conflict state). No downstream "load order N" text edits required — ADR-0002 and combat-damage.md already correctly assert the Combat autoload claim; this amendment brings the canonical registry into alignment.

  Changes landing in this amendment: Summary paragraph ("6 autoloads" → "7 autoloads"; chain grows `... → PostProcessStack (6) → Combat (7)`); Canonical Registration Table (row 7 added); Rationale for line order (bullet 7 added); Key Interfaces GDScript block (one line appended); Alternatives Considered (Amendment Alternative Paths subsection added); Consequences → Positive (bullet added); Performance Implications (6→7 node counts); Validation Criteria Gate 1 (6→7 entry count); GDD Requirements Addressed → Direct GDD drivers (combat-damage.md row added); Related (3 entries added).

  **Registry impact**: `docs/registry/architecture.yaml` → `autoload_registration_order` api_decisions row `api:` field updated from 6-autoload enumeration to 7-autoload enumeration; `revised: 2026-04-23`. No new forbidden patterns; the existing `unregistered_autoload` and `autoload_init_cross_reference` fences apply to Combat at line 7 identically.

  **Rules unchanged**: §Cross-Autoload Reference Safety (rules 1–5), §Implementation Guidelines (1–7), §Risks, §Engine Compatibility, and §ADR Dependencies (top-line "Depends On: None — foundational" unchanged; ADR-0002 remains a *referenced but not Acceptance-blocking* dependency, same framing as original).

  **Status unchanged**: this ADR remains **Proposed**. Amendment does not retire Gate 1 (`project.godot [autoload]` byte-match gate) or Gate 2 (ADR-0002 Gate 1 smoke test) — both apply to the updated 7-entry table.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (autoload infrastructure) |
| **Knowledge Risk** | LOW — `[autoload]` block semantics stable since Godot 4.0; no changes in 4.4 / 4.5 / 4.6 per `breaking-changes.md`. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, godot-specialist validation 2026-04-22 §1 (line-order authority) and 2026-04-23 pre-authoring consultation (Claims 1/2/3 GREEN/YELLOW/YELLOW). |
| **Post-Cutoff APIs Used** | None. `project.godot` `[autoload]` block syntax is stable since 4.0. `*res://` path-prefix-star syntax confirmed correct for "scene-mode" autoloads (Node added to root; `_ready()` fires; tree lifecycle active). |
| **Verification Required** | None new. ADR-0002 Gate 1 (smoke test: emit one signal → EventLogger prints it → subscriber receives it) incidentally validates line-order-based cross-autoload reference safety — EventLogger is at line 2 and must successfully subscribe to Events signals declared by the line-1 autoload. |

> **Note**: LOW Knowledge Risk. The specialist consultation confirmed the `[autoload]`
> block line order is the engine's sole authoritative declaration across 4.3 → 4.6.
> No behaviour change in this area.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — foundational infrastructure ADR. The registry table *references* but does not *require Acceptance* of ADR-0002 (Events + EventLogger), ADR-0003 (SaveLoad), ADR-0004 (InputContext + PostProcessStack). |
| **Enables** | `project.godot` scaffolding at Technical Setup phase; resolves the autoload-ordering coordination that was blocking `/gate-check pre-production`. |
| **Blocks** | `project.godot [autoload]` block generation; `/architecture-review pass` verdict (Gap 3 closure). |
| **Ordering Note** | Can be Accepted in parallel with ADR-0002 through ADR-0006 — this ADR documents and disambiguates what those already say, it does not redefine behaviour. Downstream ADR/GDD edits are in-place text amendments, not re-decisions. |

## Context

### Problem Statement

Six autoloads across four existing ADRs and three GDDs specify load orders
independently:

- `Events` at "load order 1" (ADR-0002)
- `EventLogger` at "load order 2" (ADR-0002)
- `SaveLoad` at "load order 3" (ADR-0003)
- `InputContext` at "load order 4" (ADR-0004)
- **`LevelStreamingService` at "load order 4"** (LS GDD CR-1) — **collision with `InputContext`**
- `PostProcessStack` — autoload per ADR-0004 Implementation Guideline 7 + PP GDD §5, but **order unstated**

The `/architecture-review 2026-04-22` flagged the collision as Conflict 1 and the
editorial hazard as Gap 3. A godot-specialist consultation on 2026-04-22 §1
established that "load order N" labels in ADRs and GDDs are team-documentation —
the engine only honours line order within the `project.godot [autoload]` block. A
future developer reading both "load order 4" statements could write wire-up
assuming simultaneous init; whichever autoload initialises second would be
observed as `null`.

A 2026-04-23 targeted specialist consultation against the draft of this ADR
confirmed three engine realities:

1. **Line-order authority** (GREEN) — re-confirmed across 4.3 → 4.6.
2. **Cross-autoload reference safety in `_ready()`** (YELLOW) — correct in substance
   but requires framing correction (instantiation order vs `_ready()` order
   distinction) and an explicit `_init()` restriction.
3. **Tooling stability** (YELLOW) — stable in normal operation, but `@tool` scripts
   calling `add_autoload_singleton()` and runtime `Engine.register_singleton()` can
   silently mutate the block.

All three findings are incorporated below.

### Current State

Pre-production. `project.godot` does not yet exist. No source code. No autoload
registration has been attempted. This ADR is the source of truth from which the
`[autoload]` block will be generated at Technical Setup.

### Constraints

- Engine: Godot 4.6; GDScript primary.
- "load order N" labels are team-documentation, not engine-enforced (specialist §1).
- The `[autoload]` block is the single authoritative declaration.
- No project plugins or `@tool` scripts exist yet; the stability assumption holds for current state but is fenced for future plugin additions.
- All 10 autoloads (6 original + Combat added 2026-04-23 + F&R / MLS / SettingsService added 2026-04-27) use `*res://` "scene-mode" (Node added to root; `_ready()` fires; tree lifecycle active) — confirmed correct syntax by specialist.

### Requirements

- Single canonical registration order for all 10 project autoloads (6 original + Combat added 2026-04-23 + F&R / MLS / SettingsService added 2026-04-27).
- Order MUST satisfy every forward-dependency edge (a consumer-autoload initialises after every producer-autoload it references in `_ready()`).
- Fence against ad-hoc registration drift (`@tool` scripts, `add_autoload_singleton()`, editor plugins).
- Downstream ADRs/GDDs reference this ADR for order; do NOT re-state order numbers.
- Amendment bar for new autoloads: (a) justification that the new system cannot be a static class / scene Node / RefCounted; (b) row added to this registry; (c) `project.godot` edit in the same PR.

## Decision

**Establish a single canonical autoload registration order, locked in the table
below. Generate the `project.godot [autoload]` block from this table. Downstream
ADRs/GDDs reference this ADR for the authoritative order; they do NOT re-state
specific line numbers.** A forbidden pattern (`unregistered_autoload`) prevents
ad-hoc registration.

### Canonical Registration Table

| Line | Autoload Key | Script Path | Source ADR / GDD | Consumes (autoloads only) |
|------|--------------|-------------|------------------|---------------------------|
| 1 | `Events` | `*res://src/core/signal_bus/events.gd` | ADR-0002 | — (foundational hub; no autoload dependencies) |
| 2 | `EventLogger` | `*res://src/core/signal_bus/event_logger.gd` | ADR-0002 | `Events` (subscribes to all signals at `_ready()`) |
| 3 | `SaveLoad` | `*res://src/core/save_load/save_load_service.gd` | ADR-0003 | `Events` (emits `game_saved` / `game_loaded` / `save_failed`) |
| 4 | `InputContext` | `*res://src/core/ui/input_context.gd` | ADR-0004 | — (no signals; no autoload references in `_ready()`) |
| 5 | `LevelStreamingService` | `*res://src/core/level_streaming/level_streaming_service.gd` | LS GDD CR-1 | `InputContext` (pushes `LOADING` at 13-step swap step 1), `Events` (emits `section_entered` / `section_exited`), `SaveLoad` (consumes `SaveGame` via `register_restore_callback` chain at step 9) |
| 6 | `PostProcessStack` | `*res://src/core/rendering/post_process_stack.gd` | ADR-0004 IG7 + PP GDD §5 | `Events` (subscribes to `setting_changed` for `resolution_scale`) |
| 7 | `Combat` | `*res://src/gameplay/combat/combat_system.gd` | ADR-0002 OQ-CD-1 bundle 2026-04-22 + `design/gdd/combat-damage.md` §350 (TR-CD-022) | `Events` (emits `enemy_damaged` / `enemy_killed` / `weapon_fired` / `ammo_changed`) |
| 8 | `FailureRespawn` | `*res://src/gameplay/failure_respawn/failure_respawn_service.gd` | `design/gdd/failure-respawn.md` (CR-1) | `Events` (subscribes to `player_died`; emits `respawn_triggered`), `SaveLoad` (assembles slot-0 autosave on `player_died` per F&R CR-3), `LevelStreamingService` (one of three authorized callers of `reload_current_section` per LS CR-4) |
| 9 | `MissionLevelScripting` | `*res://src/gameplay/mission_level_scripting/mission_level_scripting.gd` | `design/gdd/mission-level-scripting.md` (CR-17) | `Events` (subscribes to `section_entered` / `respawn_triggered` / `guard_woke_up` / `enemy_killed` / `alert_state_changed`; emits `mission_started` / `mission_completed` / `objective_started` / `objective_completed`), `SaveLoad` (SaveGame assembler on `section_entered(FORWARD)` per ADR-0003), `FailureRespawn` (subscribes to `respawn_triggered` per F&R coord item #1 — line-after-F&R is load-bearing) |
| 10 | `SettingsService` | `*res://src/core/settings/settings_service.gd` | `design/gdd/settings-accessibility.md` (CR-3 + CR-9) | `Events` (sole publisher of `setting_changed` per ADR-0002 Settings domain; emits `settings_loaded` one-shot per CR-9 once boot-load completes — pending ADR-0002 amendment per `/review-all-gdds 2026-04-27` Warning W4). No dependency on F&R / MLS at `_ready()` time; consumers use the `settings_loaded` one-shot pattern not direct `_ready()` reads. |

### Rationale for line order

- **(1) Events first** — foundational typed-signal hub; every other autoload either subscribes to Events signals or emits through them. Must precede every autoload that touches the bus.
- **(2) EventLogger** — debug-only; connects to every Events signal at `_ready()` then self-removes in non-debug builds via `OS.is_debug_build()`. Load-bearing dependency on line 1.
- **(3) SaveLoad** — foundational persistence. Consumed by LSS at step 9 of the swap contract. No dependency on InputContext / LSS / PostProcessStack.
- **(4) InputContext** — consumed by LSS (`InputContext.push(LOADING)` at step 1 of the 13-step swap). Must load BEFORE LSS.
- **(5) LevelStreamingService** — consumer of InputContext + Events + SaveLoad. Position IS load-bearing per specialist Claim 2: LSS's `_ready()` safely references autoloads 1–4 because they are all earlier in the block.
- **(6) PostProcessStack** — consumes only `Events.setting_changed` (valid at any position ≥ 2). Placed before Combat because nothing else depends on it at `_ready()` time.
- **(7) Combat** — stateless-ish damage-routing hub (`class_name CombatSystemNode`, autoload key `Combat` — intentional split per TR-CD-022, mirroring the `SignalBusEvents`/`Events` pattern on line 1). Invoked from arbitrary scene-tree positions — SAI guard nodes, Player controller, and per-dart projectile nodes — without a common ancestor. Consumes `Events` only for emit-site ownership (`enemy_damaged`, `enemy_killed`, `weapon_fired`, `ammo_changed` per combat-damage.md CR-1/CR-2); no dependency on EventLogger, SaveLoad, InputContext, LSS, or PostProcessStack at `_ready()` time. Position at line 7 is safe: per-dart and per-GuardFireController `Events.respawn_triggered` subscriptions (TR-CD-016) happen in scene-node `_ready()` instances that always run after the full autoload chain has initialised — not on `CombatSystemNode` itself, which has no cross-autoload `_init()` or `_ready()` references (godot-specialist 2026-04-23 consultation).
- **(8) FailureRespawn** — gameplay-layer orchestrator that catches `Events.player_died`, assembles a slot-0 autosave via `SaveLoad`, applies the Combat-owned ammo respawn floor (Combat at line 7 already in tree), emits `Events.respawn_triggered(section_id)` for downstream cue (Audio cut-to-silence; MLS subscribes for objective state). Sole publisher of the Failure/Respawn signal domain per ADR-0002:183. Consumes only earlier autoloads (`Events`, `SaveLoad`, `LevelStreamingService`, `Combat`); MLS subscribes to F&R's `respawn_triggered` from line 9, so F&R MUST precede MLS. No dependency on `SettingsService` at `_ready()` time (F&R doesn't read settings on init).
- **(9) MissionLevelScripting** — gameplay-layer mission state machine + scripted-event trigger system + section authoring contract owner + ADR-0003 SaveGame assembler on `section_entered(FORWARD)`. Subscribes to `Events.respawn_triggered` (emitted from `FailureRespawn` at line 8), `Events.section_entered`, `Events.guard_woke_up`, `Events.enemy_killed`, `Events.alert_state_changed`. **Position at line 9 (after F&R at 8) is load-bearing**: per Cross-Autoload Reference Safety rule 3, MLS's `_ready()` may reference autoloads at lines 1–8 only; line-before-F&R would null-dereference F&R when MLS connects to `respawn_triggered` at startup. No dependency on `SettingsService` at `_ready()` time.
- **(10) SettingsService** — sole publisher of `Events.setting_changed` (only `Variant`-payload signal in the ADR-0002 taxonomy) and `Events.settings_loaded` one-shot (pending ADR-0002 amendment per `/review-all-gdds 2026-04-27` W4). Owns `user://settings.cfg` (per ADR-0003). Position at line 10 (end of block) is safe and intentional: consumers of `setting_changed` (Audio bus volumes, HUD visibility, PostProcessStack `resolution_scale`, etc.) use the **`settings_loaded` one-shot pattern** per `settings-accessibility.md` CR-9 — they connect at their own `_ready()` and either receive the deferred `settings_loaded` if it has not fired yet, or treat the signal-already-fired case via the `_settings_applied` boot-flag query. No autoload at lines 1–9 references `SettingsService` from its own `_ready()`. F&R + MLS at lines 8–9 do not read settings on init (settings concerns are scene-node-level, applied by their consumers in their own `_ready()` or in their `setting_changed` handlers).

### Key Interfaces

```gdscript
# project.godot — [autoload] block MUST match this exact line order.
# Each entry uses the `*res://` path-prefix-star syntax to declare scene-mode
# (Node added to root at startup; _ready() fires; tree lifecycle active).
#
# The `*` prefix is REQUIRED. Without it, the entry is script-mode (script
# loaded, name available, but no Node in the tree, no _ready(), no signal
# lifecycle) — which breaks every autoload in this registry, all of which
# extend Node and rely on _ready() and/or tree membership.

[autoload]

Events="*res://src/core/signal_bus/events.gd"
EventLogger="*res://src/core/signal_bus/event_logger.gd"
SaveLoad="*res://src/core/save_load/save_load_service.gd"
InputContext="*res://src/core/ui/input_context.gd"
LevelStreamingService="*res://src/core/level_streaming/level_streaming_service.gd"
PostProcessStack="*res://src/core/rendering/post_process_stack.gd"
Combat="*res://src/gameplay/combat/combat_system.gd"
FailureRespawn="*res://src/gameplay/failure_respawn/failure_respawn_service.gd"
MissionLevelScripting="*res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
SettingsService="*res://src/core/settings/settings_service.gd"
```

### Cross-Autoload Reference Safety

*Authoritative specification — supersedes any equivalent statement in existing
ADRs/GDDs. Derived from godot-specialist 2026-04-23 Claim 2 YELLOW verdict with
framing corrections folded in.*

1. **By the time autoload N's `_ready()` fires, autoloads 1 through N−1 are all in the scene tree** (instantiated and added via `add_child()` on the root). Their `_ready()` calls may or may not have completed but their variables are initialized and they are reachable by autoload key.
2. **An autoload's `_ready()` MAY reference any earlier autoload by name.** Example: `EventLogger._ready()` may call `Events.signal_name.connect(...)` because `Events` is at line 1 and `EventLogger` is at line 2.
3. **An autoload's `_ready()` MUST NOT reference a later autoload by name.** The later autoload is not yet in the tree when the earlier one's `_ready()` runs; the reference would resolve to `null`.
4. **No autoload's `_init()` may reference any other autoload.** `_init()` fires during object construction, before the node is added to the tree. Other autoloads are unreachable via the tree from `_init()`. Registered as forbidden pattern `autoload_init_cross_reference`.
5. **GDScript parse-time class references (e.g., `LevelStreamingService.TransitionReason` as a signal payload type on `Events.gd`) are resolved across the project at parse time regardless of autoload order** — so a parse failure here is NOT a load-order issue; it is a commit-atomicity issue handled by the ADR-0002 2026-04-22 Risks row. Autoload order does not fix or cause that class of failure.

### Implementation Guidelines

1. **The `project.godot [autoload]` block MUST be generated from §Key Interfaces verbatim.** No reordering by the Godot editor UI, no alphabetisation, no rewrites by `@tool` scripts.
2. **All 10 entries use `*res://` path-prefix-star syntax.** Script-mode (no `*` prefix) is not supported by this registry — every autoload in the table extends `Node` and requires tree lifecycle.
3. **`_init()` MUST NOT reference any other autoload by name.** Registered as forbidden pattern `autoload_init_cross_reference`. Cross-autoload setup belongs in `_ready()`.
4. **`_ready()` MAY reference autoloads at earlier line numbers only.** Referencing a later autoload from `_ready()` is undefined (the later autoload is not yet in the tree).
5. **Game code MUST NOT call `Engine.register_singleton()` at runtime.** Registered as optional forbidden pattern `runtime_singleton_registration`. Test doubles that need named-instance registration use dependency injection (per the existing project test pattern), not runtime singleton registration.
6. **`@tool` scripts and editor plugins MUST NOT call `ProjectSettings.set_setting()` / `add_autoload_singleton()` on autoload paths.** Registered under the `unregistered_autoload` forbidden pattern. Any future plugin addition requires a paired ADR-0007 amendment documenting the resulting `[autoload]` block order.
7. **Downstream ADRs/GDDs MUST NOT restate specific line numbers.** Reference this ADR instead: e.g., *"`LevelStreamingService` is an autoload (per ADR-0007)"* rather than *"`LevelStreamingService` is an autoload at load order 5"*. Line numbers in *this ADR* (§Canonical Registration Table) are the sole authoritative statement.

## Alternatives Considered

### Alternative 1: Surgical in-place fix across ADR-0004 + LS GDD + `project.godot` (no new ADR)

- **Description**: Amend ADR-0004 to confirm `InputContext` at order 4; amend LS GDD CR-1 to move `LevelStreamingService` to order 5; establish the `project.godot [autoload]` block line order directly without a separate ADR.
- **Pros**: Minimum-viable fix; no new ADR to maintain; fewer documents to update.
- **Cons**: Does not address `PostProcessStack`'s unstated order. Does not prevent future recurrence — the same collision hazard could re-emerge when Inventory / Civilian AI / Mission Scripting systems propose autoloads. Scattered authority — no single place to see "what autoloads does the project register, and why?".
- **Rejection reason**: The scale of the original problem at authoring time (6 autoloads, 1 collision, 1 unstated — subsequently grown to 7 via the 2026-04-23 Combat amendment) and the projected scale as more systems are authored (Inventory, Civilian AI, Mission Scripting may each propose an autoload) justify a dedicated registry. Fence design requires a single authoritative artifact.

### Alternative 2: Rely on `project.godot` alone as documentation

- **Description**: Delete every "load order N" statement from ADRs and GDDs. Treat `project.godot` as the single source of truth. No ADR-level documentation of order or rationale.
- **Pros**: Zero documentation drift by construction; matches engine reality (only `project.godot` matters).
- **Cons**: Loses design-time rationale ("why is LSS after InputContext?"). Reviewers cannot validate ordering in code review without opening `project.godot` and reconstructing intent. The dependency graph becomes tribal knowledge.
- **Rejection reason**: The sequencing rationale (which consumer depends on which producer) is load-bearing design knowledge that belongs in an ADR. `project.godot` shows the WHAT; the ADR shows the WHY.

### Alternative 3: Multiple per-domain registries

- **Description**: Split the registry into foundational (Events, EventLogger, SaveLoad), UI (InputContext, PostProcessStack), and level-system (LevelStreamingService) sub-registries, each documented in the owning domain's ADR.
- **Pros**: Each registry smaller; domain-owned.
- **Cons**: No single cross-cutting view; re-introduces the exact problem this ADR solves (multiple sources of truth for order). The `[autoload]` block is inherently global.
- **Rejection reason**: The block is a single global ordering; splitting documentation across sub-registries defeats the purpose.

### Amendment Alternative Paths (2026-04-23 — Combat autoload inclusion)

Evaluated before this amendment was drafted. Documented here per ADR-0007's own amendment bar: "justification that the new system cannot be a static class / scene Node / RefCounted".

#### Path A — Amend ADR-0007 to register Combat at line 7 (CHOSEN)

- **Description**: This amendment. Canonical registration table grows to 7 entries; `project.godot [autoload]` block grows to 7 lines; no runtime behaviour change (ADR-0002 and combat-damage.md already assert the Combat autoload claim — this aligns the registry).
- **Pros**: Closes the Phase 5 §6.3 editorial conflict; brings the registry into alignment with the ADR-0002 OQ-CD-1 bundle + combat-damage.md §350 + TR-CD-022; preserves Combat's scene-tree fan-out access pattern which autoloads were designed for; fences Combat under the same `unregistered_autoload` + `autoload_init_cross_reference` patterns as the other 6.
- **Cons**: Grows the canonical registry from 6 to 7; one more autoload to hold in the code-review mental model.
- **Selection reason**: godot-specialist consultation 2026-04-23 (architecture.md §6.3): Combat's method-call fan-out from arbitrary scene-tree positions is exactly what Godot's autoload system exists for; line-7 placement is safe because `CombatSystemNode` has no cross-autoload `_init()` or `_ready()` references.

#### Path B — Downgrade Combat from autoload to scene-tree singleton

- **Description**: Remove the Combat autoload. Declare Combat as a regular scene node (e.g., child of a per-section root or a Mission Scripting owner). Callers reach Combat via group lookup (`get_tree().get_first_node_in_group("combat")`) or hardcoded `get_node()` paths from their scene context.
- **Pros**: Keeps the canonical autoload count at 6; avoids growing ADR-0007.
- **Cons**: Requires retracting ADR-0002's `class_name CombatSystemNode` / autoload-key `Combat` split (TR-CD-022). Requires editing combat-damage.md §350 + §297 and every caller site (SAI guard nodes, PC damage path, projectile scripts) to replace `Combat.apply_damage_to_actor(...)` with group-lookup or `get_node()` boilerplate. Group lookups are fragile (no compile-time name check; silent failure when the node is renamed or moved); hardcoded `get_node()` paths break the "decoupled from scene structure" invariant. Opens the door to `autoload_singleton_coupling`-adjacent anti-patterns by making Combat reachable via a scene-tree convention that `unregistered_autoload` was designed to prevent.
- **Rejection reason**: ADR-0007 implicitly forbids this class of scene-tree singleton via the same rationale that justifies `unregistered_autoload`: a service-locator-via-scene-graph is a drift hazard indistinguishable in symptoms from an ad-hoc autoload. Paying that cost to avoid growing the autoload count by 1 is a worse trade.

#### Path C — Defer the decision

- **Description**: Neither amend ADR-0007 nor downgrade Combat. Continue with ADR-0002 and combat-damage.md asserting Combat as an autoload while ADR-0007's canonical table lists only 6.
- **Pros**: Zero work now.
- **Cons**: Leaves TR-CD-022 + ADR-0002 OQ-CD-1 bundle in a false conflict state against this ADR's canonical table. The first PR to add Combat to `project.godot` would trip the `unregistered_autoload` code-review fence with no paired amendment available — blocking the Technical Setup phase or inviting a lapsed-fence bypass. Editorial debt with no payoff.
- **Rejection reason**: The issue is low technical risk but high editorial correctness risk — exactly the drift class this ADR exists to prevent. Deferring would normalise the exception.

### Amendment Alternative Paths (2026-04-27 — F&R + MLS + SettingsService autoload inclusion)

Evaluated before this amendment was drafted. Documented per ADR-0007's amendment bar: "justification that the new system cannot be a static class / scene Node / RefCounted".

#### Path A — Amend ADR-0007 to register F&R(8), MLS(9), SettingsService(10) (CHOSEN)

- **Description**: This amendment. Canonical registration table grows to 10 entries; `project.godot [autoload]` block grows to 10 lines. Slot order honors the MLS-after-F&R hard edge (MLS subscribes to F&R's `respawn_triggered` from `_ready()`) and places SettingsService last because it has no autoload-init-time dependents (consumers use `settings_loaded` one-shot signal pattern, not `_ready()` reads of `SettingsService`).
- **Pros**: Closes `/review-all-gdds 2026-04-27` Blocker B2 (3-way slot-#8 conflict between F&R, Settings, and DC parenthetical). Preserves each system's autoload-required design rationale: F&R as the orchestrator of `player_died → SaveGame assembly → reload_current_section → respawn_triggered`; MLS as the SaveGame assembler + scripted-event trigger system; SettingsService as the sole `setting_changed` publisher + `user://settings.cfg` owner. Single ADR amendment + 4 paired GDD sweeps (F&R, MLS, Settings, DC) is editorially smaller than 3 separate amendments.
- **Cons**: Grows the canonical registry from 7 to 10; three more autoloads to hold in the code-review mental model.
- **Selection reason**: All three systems' autoload-versus-scene-tree justifications match the same Path-A pattern that established Combat at line 7: cross-cutting orchestrators that consume signals from across the project and emit signals consumed by per-section scene nodes. F&R + MLS specifically need stable load-order vs each other (F&R must precede MLS); ADR-0007 is the only place to enforce that. SettingsService is an autoload because `user://settings.cfg` boot-load + `setting_changed` publication is project-global by design. Bundling all three into one amendment with one slot-order adjudication avoids the same conflict re-emerging if they were filed separately.

#### Path B — Three separate amendments staged in dependency order

- **Description**: File ADR-0007 amendment 2026-04-27a (F&R at 8), then 2026-04-27b (MLS at 9), then 2026-04-27c (SettingsService at 10).
- **Pros**: Each amendment smaller in isolation.
- **Cons**: Three amendments share a single underlying decision (the slot-order adjudication). Splitting them creates three review burdens for what is one decision; intermediate states (registry at 8 entries with F&R, then 9 with F&R+MLS, then 10) have no production payoff and add editorial friction.
- **Rejection reason**: The three systems' slot claims are interdependent (F&R + MLS hard edge; Settings's misclaim of slot #8 is what creates the conflict). Adjudicating them together is structurally simpler than serially.

#### Path C — Demote one of the three from autoload to scene-tree singleton

- **Description**: For example, demote `SettingsService` to a scene-rooted singleton on `MainMenu.tscn` and the per-section scene root, with explicit propagation between scenes.
- **Pros**: Keeps the canonical autoload count at 9 instead of 10.
- **Cons**: SettingsService is **the sole publisher** of `setting_changed` per ADR-0002. Demoting it to a scene-tree node would force every consumer (Audio, PC, PostProcessStack, HUD, Inventory, Combat) to look it up via group / `get_node()` / DI, exactly the `autoload_singleton_coupling`-adjacent anti-pattern that `unregistered_autoload` was designed to prevent. Settings persists between sections (settings.cfg load is project-startup-once); a scene-rooted singleton would either re-load settings on every section transition (wasteful) or duplicate state across instances (incoherent).
- **Rejection reason**: Same rationale that rejected Path B for Combat in 2026-04-23: paying the scene-tree-singleton cost to avoid growing the autoload count by 1 is a worse trade.

## Consequences

### Positive

- Conflict 1 from `/architecture-review 2026-04-22` resolved (`InputContext`→4, `LevelStreamingService`→5).
- Gap 3 from `/architecture-review 2026-04-22` resolved (`PostProcessStack` explicit at 6).
- Single authoritative source for autoload order; future developers have one document to consult.
- Fence (`unregistered_autoload` forbidden pattern) prevents the four drift hazards identified by specialist: (a) plugin-added autoloads, (b) `@tool` `add_autoload_singleton()` calls, (c) runtime `Engine.register_singleton()` calls, (d) manual `project.godot` reshuffling without ADR amendment.
- Cross-autoload reference safety (`_ready()` vs `_init()`) finally specified authoritatively. Previously scattered across ADR-0002, LS GDD, and implicit developer knowledge.
- Amendment 2026-04-23 closes the Phase 5 §6.3 cross-session editorial conflict (Combat autoload claim in ADR-0002 + combat-damage.md §350 + TR-CD-022 vs. this ADR's original 6-autoload canonical table). The canonical registry now matches the downstream assertions; the `/architecture-review` verdict inherits a clean state.
- Amendment 2026-04-27 closes `/review-all-gdds 2026-04-27` Blocker B2 (3-way slot-#8 collision across F&R, SettingsService, and DC parenthetical). Adjudicates the MLS-after-F&R hard edge into the canonical registry. Eliminates the latent failure mode where MLS's `_ready()` could subscribe to F&R's `respawn_triggered` before F&R is in the tree (silent null deref). Consolidates F&R, MLS, and Settings autoload claims into the single source of truth — all four affected GDDs (F&R, MLS, Settings, DC) sweep to "per ADR-0007" in the paired PR, eliminating the forward-claim drift class.

### Negative

- Bulk downstream text edits required across ADR-0002, ADR-0003, ADR-0004, `signal-bus.md`, `level-streaming.md` (20+ sites) to redirect "load order N" statements to "per ADR-0007". Scheduled to land in the same PR as this ADR.
- One more ADR to maintain. Amendment required on every new autoload — bars entry but adds friction. Justified by the cost of the collision-class bug.

### Neutral

- This ADR only documents and fences what already exists implicitly. It does not change any runtime behaviour beyond making the `project.godot` line order explicit.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| A future developer adds an autoload via the Godot Project Settings GUI without an ADR amendment | MEDIUM | HIGH | `unregistered_autoload` forbidden pattern in `architecture.yaml`; code review checklist item: "if this PR edits `project.godot [autoload]` block, is there a paired ADR-0007 amendment?"; optional CI guard: a script diffs the `[autoload]` block against this ADR's §Key Interfaces table. |
| An editor plugin or `@tool` script calls `ProjectSettings.set_setting()` / `add_autoload_singleton()` and silently mutates the block | LOW (no plugins in current project state) | HIGH | Explicit fence in Implementation Guideline 6: no `@tool` scripts or editor plugins may call these APIs on autoload paths without a paired ADR-0007 amendment documenting the resulting block order. Re-verify at every plugin addition. |
| Game code calls `Engine.register_singleton()` at runtime, shadowing an autoload name | LOW | HIGH | Forbidden pattern `runtime_singleton_registration` (optional). No production use case. Test doubles use dependency injection, not runtime singleton registration. |
| An autoload's `_init()` references another autoload by name and silently null-derefs (or an earlier autoload references a later autoload from `_ready()`) | MEDIUM | MEDIUM | §Cross-Autoload Reference Safety is authoritative. Implementation Guidelines 3 + 4. Forbidden pattern `autoload_init_cross_reference`. Code review every new autoload `_init()` / `_ready()` edit. |
| GDScript parse-time class reference failure (e.g., `Events.gd` references `LevelStreamingService.TransitionReason` before the owning script declares the enum) | LOW | HIGH | NOT a load-order issue — GDScript resolves class references at parse time across the project regardless of autoload order. Handled by ADR-0002's 2026-04-22 atomic-commit Risks row (same-PR enum + signal + consumer changes). Noted here for clarity so that reviewers do not try to "fix" it by reshuffling autoload order. |
| Order drifts over time as ADR text + `project.godot` diverge | LOW | MEDIUM | Optional CI script parses the `project.godot [autoload]` block and compares to §Key Interfaces. Drift = CI failure. Implementation of the script is post-MVP. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (autoload instantiation at startup) | N/A (no project.godot yet) | ~10 × <1 ms ≈ <10 ms total startup autoload cost | <50 ms total project startup budget |
| Memory (static autoload cost) | N/A | 10 nodes in tree, <100 KB combined; SaveLoadService + LevelStreamingService + SettingsService hold the most state (Resources, fade overlay, ConfigFile dictionary respectively); FailureRespawn holds slot-0 autosave staging buffer + checkpoint metadata; MissionLevelScripting holds the mission state machine + the in-flight section's MissionState + the SaveGame assembler scratch buffer; CombatSystemNode holds only enum definitions + stateless helper methods | <1 MB steady-state autoload footprint |
| Runtime | N/A | Zero runtime impact — this ADR is a registration/documentation contract | — |

## Migration Plan

No existing code. Implementation order:

1. **This ADR lands** with a paired bulk text edit across the 20+ downstream "load order N" sites (see §Downstream sites requiring paired text edits below) replacing each with "per ADR-0007" references. Single atomic PR.
2. When Technical Setup phase creates `project.godot`, the `[autoload]` block is generated from §Key Interfaces verbatim.
3. ADR-0002 Gate 1 (smoke test) incidentally validates the `_ready()`-ordering discipline: `EventLogger`'s `_ready()` successfully subscribes to `Events` signals declared in `events.gd`. If Gate 1 passes, line-order authority (specialist Claim 1) and cross-autoload reference safety (specialist Claim 2) are both confirmed empirically.
4. No rollback scenario. The registration order is derived from dependency edges in §Decision. If a new dependency edge is discovered that conflicts with this order, the ADR amendment fixes it; the same PR edits `project.godot`.

## Validation Criteria

- [ ] **Gate 1**: `project.godot [autoload]` block contains exactly 10 entries in the §Key Interfaces order (as amended 2026-04-23 + 2026-04-27), using `*res://` prefix on every entry, matching the §Key Interfaces block byte-for-byte (modulo whitespace).
- [ ] **Gate 2**: ADR-0002 Gate 1 smoke test (emit → EventLogger prints → subscriber receives) passes. Incidentally validates Cross-Autoload Reference Safety.
- [ ] All "load order N" statements in ADR-0002, ADR-0003, ADR-0004, `signal-bus.md`, `level-streaming.md` are replaced with "per ADR-0007" references (see §Downstream sites).
- [ ] 2 forbidden patterns registered in `docs/registry/architecture.yaml`: `unregistered_autoload`, `autoload_init_cross_reference`. Optional third: `runtime_singleton_registration`.
- [ ] 1 `api_decisions` row registered: `autoload_registration_order` → pattern `declarative_registry`, owner `adr-0007`.

## GDD Requirements Addressed

### Direct GDD drivers

| GDD Document | Requirement | How This ADR Satisfies It |
|--------------|-------------|---------------------------|
| `design/gdd/signal-bus.md` | "The `Events.gd` autoload is registered at game start. The optional `EventLogger.gd` debug autoload self-removes in non-debug builds" (§Stateless infrastructure) | `Events` at line 1, `EventLogger` at line 2. |
| `design/gdd/save-load.md` | "SaveLoadService autoload writes/reads only" | `SaveLoad` at line 3. |
| `design/gdd/level-streaming.md` | CR-1: "`LevelStreamingService` is an autoload. Load order 4 (after Events at 1, EventLogger at 2, SaveLoad at 3)." | **Supersedes** CR-1's "Load order 4" → line 5 (after `InputContext` at 4). LS GDD CR-1 text updated in the paired edit. |
| `design/gdd/post-process-stack.md` | §5: "The PostProcessStack autoload owns the sepia dim state." | `PostProcessStack` at line 6 (now explicit). |
| `design/gdd/input.md` | (via ADR-0004) `InputContext` autoload for modal input routing. | `InputContext` at line 4. |
| `design/gdd/combat-damage.md` | §350 + TR-CD-022: "Autoload convention: class_name=CombatSystemNode, autoload key=Combat (intentional split mirroring SignalBusEvents/Events); enum paths use class_name, method calls use autoload key." | `Combat` at line 7 (autoload key matches combat-damage.md's expectation; script path `*res://src/gameplay/combat/combat_system.gd` matches architecture.md §4 Module Ownership pseudocode). TR-CD-022 is the authoritative rationale for the `class_name` / autoload-key split. |
| `design/gdd/failure-respawn.md` | CR-1 + Coord item #1: "F&R autoload registered as one of three authorized callers of `LevelStreamingService.reload_current_section`; sole publisher of Failure/Respawn signal domain (ADR-0002:183); MLS subscribes to `respawn_triggered` so F&R must precede MLS in load order." | `FailureRespawn` at line 8 (after `Combat` at 7, before `MissionLevelScripting` at 9). |
| `design/gdd/mission-level-scripting.md` | CR-17 + ADR-0003 SaveGame assembler role: "MLS subscribes to `Events.respawn_triggered` (from FailureRespawn) at autoload `_ready()`; line-after-F&R is load-bearing per Cross-Autoload Reference Safety rule 3." | `MissionLevelScripting` at line 9 (immediately after `FailureRespawn` at 8). |
| `design/gdd/settings-accessibility.md` | CR-3 + CR-9: "SettingsService is sole publisher of `setting_changed`; owns `user://settings.cfg`; emits `settings_loaded` one-shot once boot-load completes (pending ADR-0002 amendment per W4)." | `SettingsService` at line 10 (end of block; consumers use the `settings_loaded` one-shot pattern, not `_ready()` reads of `SettingsService`, so end-of-block is safe). **Supersedes** `settings-accessibility.md:60` (CR-3) "autoload slot #8" misclaim → "per ADR-0007 line 10". |

### Downstream sites requiring paired text edits

The following sites restate "load order N" and are updated in the paired PR to
reference "per ADR-0007":

- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — L56 (Revision History parenthetical), L141 (diagram), L163 (diagram), L174 (header comment), L328–329 (Implementation Guideline 1), L330 (Implementation Guideline 2 parenthetical for LSS), L428–429 (Migration Plan), L438 + L442 (Validation Criteria), L466 (Related)
- `docs/architecture/adr-0003-save-format-contract.md` — L99 (diagram), L156 (comment), L348 (Validation Criteria)
- `docs/architecture/adr-0004-ui-framework.md` — L90 (Implementation Guideline 2), L132 (diagram), L184 (comment), L365 (Migration Plan), L381 (Validation Criteria)
- `design/gdd/signal-bus.md` — L44 (Stateless infra), L106 (Edge cases), L149 (Tuning Knobs row), L177 (AC-1)
- `design/gdd/level-streaming.md` — L36 (CR-1 — includes the `InputContext`→4 / `LevelStreamingService`→5 order flip)
- `design/gdd/failure-respawn.md` — L271, L309, L494 (slot #8 claim → "per ADR-0007 line 8"; landed in 2026-04-27 amendment paired sweep)
- `design/gdd/mission-level-scripting.md` — L60 (CR-17), L527, L542, L825 (slot #9 claim → "per ADR-0007 line 9"; landed in 2026-04-27 amendment paired sweep)
- `design/gdd/settings-accessibility.md` — L60 (CR-3 slot #8 misclaim → "per ADR-0007 line 10"; landed in 2026-04-27 amendment paired sweep)
- `design/gdd/document-collection.md` — L18, L115, L463, L653, L733, L812 (parenthetical "F&R = #8, MLS = #9" → "per ADR-0007"; landed in 2026-04-27 amendment paired sweep, also closing /review-all-gdds 2026-04-27 Warning W7)

## Related

- **ADR-0002** (Signal Bus + Event Taxonomy) — declares `Events` + `EventLogger` autoloads; this ADR pins their line-order and supersedes their individual "load order 1/2" statements.
- **ADR-0003** (Save Format Contract) — declares `SaveLoad` autoload; this ADR pins its line-order and supersedes its "load order 3" statements.
- **ADR-0004** (UI Framework) — declares `InputContext` + `PostProcessStack` autoloads; this ADR pins their line-order, resolves the ADR-0004 `InputContext`-vs-LS GDD collision, and makes `PostProcessStack` position explicit.
- **`design/gdd/level-streaming.md`** CR-1 — declares `LevelStreamingService` autoload; this ADR supersedes the CR-1 "Load order 4" statement and moves LSS to line 5.
- **`docs/registry/architecture.yaml`** — 2 forbidden patterns (`unregistered_autoload`, `autoload_init_cross_reference`) and 1 `api_decisions` row (`autoload_registration_order` → `declarative_registry`) registered by this ADR. Optional 3rd forbidden pattern: `runtime_singleton_registration`.
- **godot-specialist validation** — 2026-04-22 §1 (line-order authority) + 2026-04-23 pre-authoring consultation (Claims 1/2/3 GREEN/YELLOW/YELLOW; framing correction for Claim 2 incorporated into §Cross-Autoload Reference Safety; hazards #1/#2/#3 incorporated into Risks table).
- **`docs/architecture/architecture-review-2026-04-23.md`** — identifies Gap 3 + Conflict 1 that this ADR resolves; recommends "dedicated registry ADR" over the surgical alternative.
- **ADR-0002 (Signal Bus + Event Taxonomy) — 2026-04-22 OQ-CD-1 bundle** — introduced `class_name CombatSystemNode` / autoload key `Combat` split (Revision History entry 2026-04-22). This amendment (2026-04-23) pins Combat's canonical line position at 7; the two documents agree after the amendment lands.
- **`design/gdd/combat-damage.md` §350 + TR-CD-022** — declares Combat as autoload with the `class_name CombatSystemNode` / autoload-key `Combat` split; this amendment aligns ADR-0007's canonical registration table with that declaration.
- **`docs/architecture/architecture.md` §6.3 + §7.2.1 + §9.2** — surfaced the Combat-autoload omission during `/create-architecture` Phase 4 API-Boundaries authoring (2026-04-23); tracks Path A follow-up that this amendment delivers.
- **`design/gdd/gdd-cross-review-2026-04-27.md` Blocker B2** — surfaced the 3-way slot-#8 conflict (F&R + Settings + DC parenthetical); closed by the 2026-04-27 amendment to this ADR.
- **`design/gdd/failure-respawn.md` (CR-1 + Coord item #1)** — declares F&R autoload + MLS-after-F&R load-order dependency; this amendment pins F&R at line 8 and supersedes the slot-#8 specific claim with a "per ADR-0007" reference.
- **`design/gdd/mission-level-scripting.md` (CR-17)** — declares MLS autoload + load-order dependency on F&R's `respawn_triggered`; this amendment pins MLS at line 9 and supersedes the slot-#9 specific claim.
- **`design/gdd/settings-accessibility.md` (CR-3 + CR-9)** — declares SettingsService autoload + `settings_loaded` one-shot consumer pattern; this amendment pins SettingsService at line 10 and supersedes the CR-3 slot-#8 misclaim.
