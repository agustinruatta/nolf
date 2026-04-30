# Epics Index

Last Updated: 2026-04-30
Engine: Godot 4.6
Manifest Version: 2026-04-30 (PARTIAL — Foundation + Core layer rules; Feature layer epics added 2026-04-30 with VS-narrowed scope guidance pending Feature/Presentation manifest expansion)

## Foundation Layer (7 epics — 4 with stories, 3 newly added 2026-04-30)

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [signal-bus](signal-bus/EPIC.md) | Signal Bus (system 1) | `design/gdd/signal-bus.md` | Signal Bus (Events + EventLogger autoloads) | 7 stories created | Ready |
| [save-load](save-load/EPIC.md) | Save / Load (system 6) | `design/gdd/save-load.md` | Save / Load (SaveLoadService autoload) | 9 stories created 2026-04-30 | Ready |
| [localization-scaffold](localization-scaffold/EPIC.md) | Localization Scaffold (system 7) | `design/gdd/localization-scaffold.md` | Localization Scaffold (CSV convention; no autoload) | 5 stories created 2026-04-30 | Ready (governing ADR-0004 Proposed pending G5; G5 affects formatted body, not localization mechanism) |
| [level-streaming](level-streaming/EPIC.md) | Level Streaming (system 9 — Foundation per `architecture.md` §122) | `design/gdd/level-streaming.md` | Level Streaming (LevelStreamingService autoload) | 10 stories created 2026-04-30 | Ready |
| [audio](audio/EPIC.md) | Audio (system 3) | `design/gdd/audio.md` | Audio (Audio autoload — subscriber-side mix-bus orchestrator) | Not yet created — run `/create-stories audio` | Ready (ADR-0008 Proposed pending hardware measure) |
| [outline-pipeline](outline-pipeline/EPIC.md) | Outline Pipeline (system 4) | `design/gdd/outline-pipeline.md` | Outline Pipeline (CompositorEffect on Forward+; integrated into Post-Process Stack) | Not yet created — run `/create-stories outline-pipeline` | Ready (ADR-0005 Accepted via Sprint 01; ADR-0008 Restaurant + Iris Xe deferred) |
| [post-process-stack](post-process-stack/EPIC.md) | Post-Process Stack (system 5) | `design/gdd/post-process-stack.md` | Post-Process Stack (CompositorEffect chain + Environment chain on Forward+) | Not yet created — run `/create-stories post-process-stack` | Ready (4.6 glow rework compatibility verification required) |

## Core Layer (3 epics — created 2026-04-30)

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [input](input/EPIC.md) | Input (system 2) | `design/gdd/input.md` | Input (InputContext autoload + InputActions static class) | Not yet created — run `/create-stories input` | Ready (governing ADR-0004 Proposed pending G5 unrelated scope) |
| [player-character](player-character/EPIC.md) | Player Character (system 8) | `design/gdd/player-character.md` | Player Character (PlayerCharacter scene root = CharacterBody3D) | Not yet created — run `/create-stories player-character` | Ready (governing ADR-0005 + ADR-0008 Proposed; gates 3-5 close via this epic's hands rendering production story — chicken-and-egg by design) |
| [footstep-component](footstep-component/EPIC.md) | FootstepComponent (system 8b) | `design/gdd/footstep-component.md` | FootstepComponent (child node of PlayerCharacter) | Not yet created — run `/create-stories footstep-component` | Ready |

## Feature Layer (5 epics — created 2026-04-30, VS-narrowed scope)

Per VS scope philosophy (`production/project-stage-report.md`), the Feature
layer is split: VS-needed epics created now; combat-damage, civilian-ai, and
inventory-gadgets deferred to post-VS sprints (chosen Plaza opening doesn't
support those systems without harming design fit).

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [stealth-ai](stealth-ai/EPIC.md) | Stealth AI (system 10) | `design/gdd/stealth-ai.md` | Stealth AI (per-section scene-tree NPCs; NOT autoload) | Not yet created — run `/create-stories stealth-ai` | Ready (ADR-0008 Proposed pending hardware measure; verified via Sprint 01 perception-cache prototype) |
| [document-collection](document-collection/EPIC.md) | Document Collection (system 17) | `design/gdd/document-collection.md` | Document Collection (per-section StaticBody3D + Document Resource; NOT autoload) | Not yet created — run `/create-stories document-collection` | Ready (ADR-0004 + ADR-0008 Proposed pending unrelated G5 / hardware measure) |
| [mission-level-scripting](mission-level-scripting/EPIC.md) | Mission & Level Scripting (system 13) | `design/gdd/mission-level-scripting.md` | Mission & Level Scripting (MissionLevelScripting autoload — after FailureRespawn per ADR-0007 amendment) | Not yet created — run `/create-stories mission-level-scripting` | Ready |
| [failure-respawn](failure-respawn/EPIC.md) | Failure & Respawn (system 14) | `design/gdd/failure-respawn.md` | Failure & Respawn (FailureRespawn autoload — after Combat per ADR-0007 amendment) | Not yet created — run `/create-stories failure-respawn` | Ready |
| [dialogue-subtitles](dialogue-subtitles/EPIC.md) | Dialogue & Subtitles (system 18) | `design/gdd/dialogue-subtitles.md` | Dialogue & Subtitles (Subtitle = scene-tree Control node; NOT autoload — slots full per ADR-0007) | Not yet created — run `/create-stories dialogue-subtitles` | Ready (ADR-0004 Proposed pending G5 BBCode/AccessKit — affects post-VS formatted body, not VS plain text) |

**Deferred to post-VS sprints** (do not create epics until needed):
- Combat & Damage (system 11) — no combat in stealth-toned VS
- Inventory & Gadgets (system 12) — gadgets introduced after baseline stealth proven
- Civilian AI (system 15) — Plaza opening is quiet infiltration; civilians dilute the read

## Presentation Layer (5 epics — created 2026-04-30, VS-narrowed scope)

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [hud-core](hud-core/EPIC.md) | HUD Core (system 16) | `design/gdd/hud-core.md` | HUD Core (CanvasLayer scene under root; HARD MVP-Day-1 dep on HSS + Settings) | Not yet created — run `/create-stories hud-core` | Ready (ADR-0004 Proposed pending G3/G4/G5) |
| [hud-state-signaling](hud-state-signaling/EPIC.md) | HUD State Signaling (system 19) | `design/gdd/hud-state-signaling.md` | HUD State Signaling (sibling Control under HUD Core; HARD MVP-Day-1 = ALERT_CUE only) | Not yet created — run `/create-stories hud-state-signaling` | Ready |
| [document-overlay-ui](document-overlay-ui/EPIC.md) | Document Overlay UI (system 20) | `design/gdd/document-overlay-ui.md` | Document Overlay UI (CanvasLayer modal; sepia-dim handshake with PPS) | Not yet created — run `/create-stories document-overlay-ui` | Ready |
| [menu-system](menu-system/EPIC.md) | Menu System (system 21) | `design/gdd/menu-system.md` | Menu System (CanvasLayer state-swap; one of 3 reload_current_section callers) | Not yet created — run `/create-stories menu-system` | Ready |
| [cutscenes-and-mission-cards](cutscenes-and-mission-cards/EPIC.md) | Cutscenes & Mission Cards (system 22) | `design/gdd/cutscenes-and-mission-cards.md` | Cutscenes & Mission Cards (CanvasLayer modal — pure VS, no MVP slice) | Not yet created — run `/create-stories cutscenes-and-mission-cards` | Ready |

## Polish Layer (1 epic — Day-1 HARD MVP slice promoted, created 2026-04-30)

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [settings-accessibility](settings-accessibility/EPIC.md) | Settings & Accessibility (system 23) | `design/gdd/settings-accessibility.md` | Settings & Accessibility (SettingsService; user://settings.cfg; Day-1 = photosensitivity + captions-on + Master volume) | Not yet created — run `/create-stories settings-accessibility` | Ready (Day-1 HARD MVP DEP per HUD Core REV-2026-04-26 D2) |

## Status Summary

- **7 Foundation epics**: 4 with stories created (signal-bus 7, save-load 9, localization-scaffold 5, level-streaming 10 = 31 Foundation stories ready); 3 newly added 2026-04-30 (audio, outline-pipeline, post-process-stack — stories pending).
- **3 Core epics** created (2026-04-30); stories not yet broken down — run `/create-stories input` / `/create-stories player-character` / `/create-stories footstep-component` next.
- **5 Feature epics** created (2026-04-30) with VS-narrowed scope. 3 Feature systems deferred post-VS (combat-damage, inventory-gadgets, civilian-ai).
- **5 Presentation epics** created (2026-04-30) with VS-narrowed scope.
- **1 Polish epic** created (2026-04-30) — Day-1 HARD MVP DEP slice in scope; full Polish slice deferred.

**Total: 21 epics covering 21 of 24 systems (87.5%) for Vertical Slice. 3 systems deferred post-VS.**

## Related

- `docs/architecture/control-manifest.md` — programmer rules sheet (Manifest Version 2026-04-30; PARTIAL — Foundation + Core only)
- `docs/architecture/architecture.md` — module ownership table (§3.1 Foundation Layer + §3.2 Core Layer)
- `docs/architecture/tr-registry.yaml` — TR-ID → ADR coverage map
- `production/sprints/sprint-01-technical-verification-spike.md` — verification spike that promoted 4 of 8 ADRs to Accepted, unblocking Foundation epics
- `prototypes/verification-spike/verification-log.md` — per-ADR-per-gate evidence log
