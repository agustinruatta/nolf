# Epic: Failure & Respawn

> **Layer**: Feature
> **GDD**: `design/gdd/failure-respawn.md`
> **Architecture Module**: Failure & Respawn (`FailureRespawn` autoload per ADR-0007 — registered after `Combat`, before `MissionLevelScripting`; sole publisher of Failure/Respawn signal domain per ADR-0002:183)
> **Engine Risk**: LOW (signal-dispatch + autosave assembly + delegation to `LevelStreamingService`; no novel engine usage)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories failure-respawn`
> **Manifest Version**: 2026-04-30

## Overview

Failure & Respawn is the **Gameplay-layer orchestrator** that catches the moment Eve dies and puts her back into the section in 2–3 seconds without breaking the theatre. When `Events.player_died` fires (bullet, blade, fall out of bounds, scripted mission-fail), F&R: (1) assembles a slot-0 autosave from current world state via the MLS-owned `capture()` chain; (2) applies the Combat-owned ammo respawn floor (first-death-per-checkpoint only — anti-farm); (3) emits `Events.respawn_triggered(section_id)` to cue Audio's cut-to-silence + 2.0 s fade-in; (4) hands the SaveGame to `LevelStreamingService.reload_current_section()`; (5) restores its own local state inside the LS step-9 restore callback; (6) calls `PlayerCharacter.reset_for_respawn(checkpoint)` to put Eve back on her feet.

F&R is one of three authorized callers of `LevelStreamingService.reload_current_section` (alongside Mission & Level Scripting and Menu System). The player never sees a "You Died" screen, never a full-mission reload, never a tutorial quip — Pillar 3 governs the beat (house lights up between scenes, not punishment). Death is rare by design (graduated-suspicion stealth + ammo-scarce combat + kill-plane as bug-recovery only); when it does land, the retry is invisible enough that the player's next thought is *"try a different route,"* not *"load a save."*

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | F&R is sole publisher of `respawn_triggered(section_id: StringName)` (ADR-0002:183); subscriber to `Events.player_died` | LOW |
| ADR-0003: Save Format Contract | F&R consumes the MLS-owned `capture()` chain to build slot-0 autosave; `FailureRespawnState` sub-resource (`last_checkpoint_id: StringName`, `respawn_floor_used: bool`) | LOW |
| ADR-0007: Autoload Load Order Registry | `FailureRespawn` registered as autoload **after** `Combat`, **before** `MissionLevelScripting` (amended 2026-04-27) | LOW |
| ADR-0008: Performance Budget Distribution | F&R claims share of 0.8 ms residual pool (Slot 8) — event-driven, no per-frame work outside the death event | LOW (Proposed — negligible per-frame cost; pool model already validated) |

## GDD Requirements

**14 TR-IDs** in `tr-registry.yaml` (`TR-FR-001` .. `TR-FR-014`) cover:

- `respawn_triggered(section_id)` signal contract
- Slot-0 autosave assembly chain (consumes MLS `capture()` chain)
- Ammo respawn floor application (Combat-owned data — `respawn_floor_*` constants)
- Three-call sequence: emit signal → hand SaveGame to LS → register step-9 restore callback
- `PlayerCharacter.reset_for_respawn(checkpoint)` integration
- Section checkpoint contract (consumed from MLS section authoring — `player_respawn_point: Marker3D`)
- Death cause taxonomy (`DeathCause` enum: bullet, blade, fall, scripted)
- 2.0 s audio fade-in handshake (Audio subscribes to `respawn_triggered`)
- `FailureRespawnState` sub-resource shape (per ADR-0003)
- Forbidden patterns (`fr_autosaving_on_respawn` — RESPAWN must NEVER trigger autosave; that's MLS's FORWARD-only contract)

Full requirement text: `docs/architecture/tr-registry.yaml` Failure & Respawn section.

## VS Scope Guidance (for `/create-stories`)

The Vertical Slice exercises this system at **minimum viable depth**:
- **Include**: `respawn_triggered` signal declaration + emission on `player_died`; slot-0 autosave assembly via MLS chain; LS step-9 restore callback registration; `PlayerCharacter.reset_for_respawn` call; one Plaza checkpoint at mission start; one `DeathCause = SCRIPTED` path (caught-by-guard → mission-fail → respawn); `RESPAWN`-must-not-autosave fence.
- **Defer post-VS**: Combat-driven death paths (no combat in VS — bullet/blade `DeathCause`); kill-plane fall-out-of-bounds detector (Plaza is bounded; deferred to first open section); ammo respawn floor (no ammo in VS — `respawn_floor_used` flag stays false); multi-checkpoint progression within a section.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- `FailureRespawn` autoload registered in `project.godot` per ADR-0007 amended order (after Combat, before MLS).
- Demonstrable beat: caught-by-Plaza-guard → `Events.player_died(SCRIPTED)` → 2.0 s fade-out → respawn at Plaza checkpoint → audio cut-to-silence + fade-in → Eve back on her feet, mission state intact.
- Round-trip integration test: trigger `player_died` → F&R assembles autosave → reload_current_section → step-9 callback fires → state matches pre-death snapshot.
- Forbidden-pattern fence registered (`fr_autosaving_on_respawn`).
- Logic stories have passing unit tests in `tests/unit/feature/failure_respawn/`; integration stories in `tests/integration/feature/failure_respawn/`.
- Evidence doc with screen-recording or annotated-screenshot of the respawn beat in `production/qa/evidence/`.

## Stories

Not yet created. Run `/create-stories failure-respawn` (with VS-narrowed scope flag) to break this epic into implementable stories.
