# Epic: Mission & Level Scripting

> **Layer**: Feature
> **GDD**: `design/gdd/mission-level-scripting.md`
> **Architecture Module**: Mission & Level Scripting (`MissionLevelScripting` autoload per ADR-0007 amended 2026-04-27 — registered after `FailureRespawn`, both after `Combat`)
> **Engine Risk**: LOW–MEDIUM (`Area3D` trigger volumes; signal-driven choreography; SaveGame assembly synchronously from `section_entered`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories mission-level-scripting`
> **Manifest Version**: 2026-04-30

## Overview

Mission & Level Scripting (MLS) is the Gameplay-layer system that owns the mission lifecycle, drives the scripted moments where *The Paris Affair*'s comedy lands, and defines what every section scene must contain on disk. It has five responsibilities: (1) the **mission state machine**, publishing the four Mission-domain signals declared in ADR-0002 (`mission_started`, `mission_completed`, `objective_started`, `objective_completed`); (2) the **scripted-event trigger system** built from `Area3D` volumes and Signal Bus subscriptions (`section_entered(reason)`, `guard_woke_up`, `enemy_killed`, `alert_state_changed(severity)`) that fire comedic beats, guard choreography, and the bomb-disarm sequence; (3) the **section authoring contract** — every section scene must include `player_respawn_point: Marker3D` (consumed by Failure & Respawn), WorldItem pickup caches within Inventory budget, `peek_surface` / `placeable_surface` collision tags; (4) the **SaveGame assembler role** designated by ADR-0003 — on `section_entered(FORWARD)` MLS reads every owning system's `capture()` static, assembles a `SaveGame` synchronously, and hands it to `SaveLoadService` (autosave gated on `FORWARD` only — `RESPAWN` must never autosave); (5) the **objective/cutscene surface** consumed by HUD Core and Cutscenes & Mission Cards.

MLS is the one place in the codebase where Pillars 1 (Comedy Without Punchlines) and 4 (Iconic Locations as Co-Stars) are deliberately **authored** rather than emergent.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Four Mission-domain signals frozen — MLS is sole publisher of `mission_started`, `mission_completed`, `objective_started(id)`, `objective_completed(id)`; subscriber to `section_entered(reason)`, SAI signals, `enemy_killed` | LOW |
| ADR-0003: Save Format Contract | MLS is the **SaveGame assembler** — synchronously reads each owning system's `capture()` static on `section_entered(FORWARD)`; assembles `MissionState` sub-resource (`active_objective_ids: Array[StringName]`, `completed_objective_ids: Array[StringName]`, `mission_phase: StringName`); autosave gated on `FORWARD` only | LOW |
| ADR-0007: Autoload Load Order Registry | `MissionLevelScripting` registered as autoload **after** `FailureRespawn`, both after `Combat` (amended 2026-04-27) | LOW |
| ADR-0008: Performance Budget Distribution | MLS claims share of 0.8 ms residual pool (Slot 8) — signal dispatch + objective bookkeeping per ADR-0008 §85 + §239 | LOW (Proposed — pool sharing model already validated) |

## GDD Requirements

**19 TR-IDs** in `tr-registry.yaml` (`TR-MLS-001` .. `TR-MLS-019`) cover:

- Mission state machine + four Mission-domain signal contracts
- Scripted-event trigger system (`Area3D` volumes + Signal Bus subscriptions)
- Section authoring contract (`player_respawn_point: Marker3D`, WorldItem cache, surface tags)
- SaveGame assembler protocol — synchronous `capture()` chain on `section_entered(FORWARD)`
- Autosave gate — `FORWARD` allowed, `RESPAWN` forbidden
- `MissionState` sub-resource shape (per ADR-0003)
- Objective lifecycle (`objective_started` → `objective_completed`)
- Cutscene/Mission Card forward-dependency surface (consumed by Cutscenes & Mission Cards VS epic)
- Forbidden patterns (`autosave_on_respawn`, `mls_emitting_outside_mission_domain`)

Full requirement text: `docs/architecture/tr-registry.yaml` Mission & Level Scripting section.

## VS Scope Guidance (for `/create-stories`)

The Vertical Slice exercises this system at **minimum viable depth**:
- **Include**: Mission state machine (one mission with one objective: "Recover the Plaza document"); four Mission-domain signal declarations + emissions; one `Area3D` trigger volume in Plaza; section authoring contract for Plaza scene only (`player_respawn_point` + one WorldItem); SaveGame assembler chain wired to Player + Stealth AI + Document Collection + Failure & Respawn captures; `FORWARD` autosave gate.
- **Defer post-VS**: Multi-section trigger choreography; bomb-disarm sequence; comedic beat authoring (Restaurant caterer, etc.); Cutscenes & Mission Cards integration (deferred to that epic in VS-narrowed form); `peek_surface` / `placeable_surface` collision tags (no peek/placement in VS).

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- `MissionLevelScripting` autoload registered in `project.godot` per ADR-0007 amended order (after FailureRespawn).
- One Plaza objective demonstrably starts on `mission_started` and completes on `document_collected`.
- SaveGame assembler integration test: trigger `section_entered(FORWARD)` → MLS reads all `capture()` statics → SaveGame populated correctly → save_to_slot(0) succeeds.
- Forbidden-pattern fence registered (`autosave_on_respawn`).
- Logic stories (state machine, assembler chain) have passing unit tests in `tests/unit/feature/mission_level_scripting/`; integration stories in `tests/integration/feature/mission_level_scripting/`.
- Section authoring contract documented as a checklist in `docs/architecture/section-authoring-contract.md` for level designers.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [MissionLevelScripting autoload scaffold + load-order registration](story-001-mls-autoload-scaffold.md) | Logic | Ready | ADR-0007 |
| 002 | [Mission state machine + four Mission-domain signal declarations](story-002-mission-state-machine.md) | Logic | Ready | ADR-0002 |
| 003 | [Plaza section authoring contract — required nodes, CI validation, discovery surface](story-003-plaza-section-authoring-contract.md) | Logic | Ready | ADR-0006 |
| 004 | [SaveGame assembler chain — FORWARD autosave gate wired to all 6 capture() calls](story-004-savegame-assembler-chain.md) | Integration | Ready | ADR-0003 |
| 005 | [Plaza objective integration — Recover Plaza Document, NEW_GAME to COMPLETED](story-005-plaza-objective-integration.md) | Integration | Ready | ADR-0002 + ADR-0003 |
