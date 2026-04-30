# Epic: Level Streaming

> **Layer**: Foundation (per `architecture.md` §122 deviation from systems-index — scene management belongs in Foundation in the project's authoritative model)
> **GDD**: `design/gdd/level-streaming.md`
> **Architecture Module**: Level Streaming (LevelStreamingService autoload — `architecture.md` §3.1)
> **Engine Risk**: MEDIUM (`PackedScene.instantiate()` 4.0+; `await get_tree().process_frame` swap orchestration; `CanvasLayer` z-order edges at 126/127)
> **Status**: Ready
> **Stories**: 10 created 2026-04-30 — see Stories table below
> **Manifest Version**: 2026-04-30

## Overview

Level Streaming owns the section-to-section swap contract for *The Paris
Affair*'s NOLF1-style sectional structure. It is the autoload that loads,
unloads, and transitions between section scenes, providing a deterministic
13-step swap sequence that every consumer can synchronize against. It owns
the `SectionRegistry` Resource (mapping `section_id → PackedScene`), the
queued-respawn state, the CanvasLayer 127 fade overlay (autoload-parented
so it survives section unload), and the CanvasLayer 126 ErrorFallback for
load-failure recovery. It emits `Events.section_entered(id, reason)` /
`Events.section_exited(id, reason)` with a `TransitionReason` enum payload
(FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE) that downstream subscribers
branch on (Audio music handoff, Cutscenes first-arrival suppression, MLS
SaveGame assembly gate on FORWARD only).

This epic implements the autoload, the 13-step swap sequence, the
`register_restore_callback` chain (synchronous restore at step 9 from
loaded `SaveGame` sub-resources), the queued-respawn drain at step 13,
and the CanvasLayer fade overlay lifecycle.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0007: Autoload Load Order Registry | `LevelStreamingService` at autoload line 5 (after `InputContext` at 4); cross-autoload reference safety; `*res://` scene-mode prefix; `LevelStreamingService.TransitionReason` enum owned by this class per ADR-0002 enum ownership rule | LOW |
| ADR-0003: Save Format Contract | `LevelStreamingService` consumes `SaveGame` via the `register_restore_callback` chain at step 9 of the swap sequence; restore is synchronous (callbacks run before the section is "entered"); `Events.section_entered(FORWARD)` triggers MLS's SaveGame assembler for autosave | MEDIUM (`Resource.duplicate_deep()` mandatory on load — discipline applied by callbacks) |

## GDD Requirements

The `level-streaming.md` GDD specifies the 13-step swap contract and the
TransitionReason taxonomy. Implementation requirements include:

- `SectionRegistry` Resource: `Dictionary[StringName, PackedScene]` keyed by `section_id`
- `transition_to_section(id, reason)`: 13-step orchestration with `await get_tree().process_frame` between phases
- `reload_current_section(reason)`: 3 authorized callers only — Failure & Respawn, Mission & Level Scripting, Cutscenes (per F&R coord item #1, MLS CR-17, Cutscenes CR-21)
- `register_restore_callback(callable)`: subscriber registration for step-9 synchronous restore (consumed by Player Character, Stealth AI, Civilian AI, Inventory, Document Collection, Mission, F&R)
- CanvasLayer 127 fade overlay: ColorRect modulated 0→1 alpha during steps 2–4, 1→0 during steps 11–12; autoload-parented so it survives section unload
- CanvasLayer 126 ErrorFallback: shown if `PackedScene.instantiate()` returns null at step 5 (corrupt scene asset)
- `InputContext.LOADING` push at step 1 / pop at step 11 (after `section_entered` fires)
- Queued-respawn state: if a respawn fires while a transition is in flight, queue it and drain at step 13
- 4 forbidden patterns (per LS GDD): unauthorized `reload_current_section` callers; cross-section NodePath references; missing `register_restore_callback` registration; bypassing the 13-step protocol

Specific requirement IDs `TR-LSS-*` are in `docs/architecture/tr-registry.yaml`
under Level Streaming ownership.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`.
- All acceptance criteria from `design/gdd/level-streaming.md` are verified.
- `LevelStreamingService` autoload registered at line 5 of `project.godot [autoload]` per ADR-0007.
- 13-step swap sequence implemented; integration test demonstrates a forward transition (NEW_GAME → section_1 → section_2 with FORWARD reason) end-to-end with no leaked nodes, no orphan signals, and correct CanvasLayer fade lifecycle.
- `RESPAWN` path tested: simulated `player_died` → `Failure & Respawn` calls `reload_current_section(RESPAWN)` → restore callbacks reapply slot-0 autosave state → `respawn_triggered(section_id)` emitted.
- `LOAD_FROM_SAVE` path tested: simulated load from manual slot → restore callbacks reapply per-system state from each `SaveGame` sub-resource → `section_entered(LOAD_FROM_SAVE)` fires.
- ErrorFallback CanvasLayer 126 tested: corrupt scene path → fallback shows → user can return to main menu without crash.
- 4 forbidden patterns registered in the architecture registry; CI guard verifies authorized callers of `reload_current_section`.
- Logic stories have passing unit tests; integration tests cover all 4 TransitionReason flows.

## Verification Spike Status (Sprint 01, 2026-04-29)

ADR-0007 is **Accepted** (G(a) byte-match + G(b) cross-autoload reference
safety verified). ADR-0003 is **Accepted** (3/3 gates including
`duplicate_deep` deep-isolation). The `LevelStreamingService` autoload
script stub exists at `src/core/level_streaming/level_streaming_service.gd`
(extends `Node`, `_ready()` pass-through) — production implementation
replaces this stub. No additional spike work is needed before story
implementation can begin.

## Stories

| # | Story | Type | Status | ADRs |
|---|-------|------|--------|------|
| 001 | [SectionRegistry Resource + autoload boot + CanvasLayer fade overlay scaffold](story-001-section-registry-autoload-fade-overlay.md) | Logic | Ready | ADR-0007 + ADR-0003 |
| 002 | [State machine + 13-step swap happy path + signal emission](story-002-state-machine-13-step-swap-signals.md) | Logic | Ready | ADR-0007 + ADR-0002 |
| 003 | [register_restore_callback chain + step 9 sync invocation](story-003-register-restore-callback-step9-sync-invocation.md) | Logic | Ready | ADR-0007 + ADR-0003 |
| 004 | [Concurrency control: forward-drop, respawn-queue, abort recovery](story-004-concurrency-control-respawn-queue-abort.md) | Logic | Ready | ADR-0007 |
| 005 | [Registry failure paths + ErrorFallback CanvasLayer recovery](story-005-registry-failure-error-fallback-recovery.md) | Integration | Ready | ADR-0007 |
| 006 | [Same-section guard + focus-loss handling + cache mode](story-006-same-section-guard-focus-loss-cache-mode.md) | Logic | Ready | ADR-0007 |
| 007 | [F5/F9 quicksave/quickload queue during transition](story-007-quicksave-quickload-queue-during-transition.md) | Integration | Ready | ADR-0007 + ADR-0003 |
| 008 | [Section authoring contract + stub scenes + Environment assignment](story-008-section-authoring-contract-stub-scenes.md) | Config/Data | Ready | ADR-0007 |
| 009 | [Anti-pattern fences + lint guards + CR-13 sync-subscriber detection](story-009-anti-pattern-fences-lint-guards.md) | Config/Data | Ready | ADR-0007 + ADR-0003 |
| 010 | [Performance budget measurement — p90 verification](story-010-performance-budget-p90-measurement.md) | Logic | Ready | ADR-0007 + ADR-0001 |

**Dependency chain**: 001 → 002 → {003, 004, 008}; 002 + 004 → 005; 002 → 006; {002, 004, Save/Load 007} → 007; {002, 003, 008} → 009; {002, 003, 008, 006} → 010.

**LS-Gates closure**: LS-Gate-1 (ADR-0002 `reason` 2nd param) closed via ADR-0002 4th-pass amendment 2026-04-22 (Accepted). LS-Gate-2 (`InputContext.LOADING` enum value) closed via ADR-0002 2026-04-28 amendment. ADR-0007 + ADR-0003 both Accepted as of 2026-04-29 Sprint 01 verification.

**Out of scope (deferred to consumer epics)**:
- Production `_assemble_quicksave_payload` and step-9 restore callbacks → Mission Scripting epic, F&R epic, Menu System epic (each registers and provides its own callback)
- Visual/aesthetic content for plaza.tscn (geometry, lighting, props) → level-designer / Art Director epics
- ErrorFallback dossier-card visual treatment → Menu System / Art Director
- HUD toast rendering for `quicksave_unavailable` → HUD State Signaling epic
- Surface-tag tool plugin (CR-10) → Tools Programmer (referenced in CR-10; AC-LS-4.3 moved to FootstepComponent epic)

## Next Step

Run `/story-readiness production/epics/level-streaming/story-001-section-registry-autoload-fade-overlay.md` to validate the first story is implementation-ready, then `/dev-story` to begin implementation. Work through stories in the order above — each story's `Depends on:` field tells you what must be DONE before you can start it.
