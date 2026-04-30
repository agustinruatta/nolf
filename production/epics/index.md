# Epics Index

Last Updated: 2026-04-30
Engine: Godot 4.6
Manifest Version: 2026-04-30 (PARTIAL — Foundation + Core layer rules only; `docs/architecture/control-manifest.md`)

## Foundation Layer (4 epics — stories created)

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [signal-bus](signal-bus/EPIC.md) | Signal Bus (system 1) | `design/gdd/signal-bus.md` | Signal Bus (Events + EventLogger autoloads) | 7 stories created | Ready |
| [save-load](save-load/EPIC.md) | Save / Load (system 6) | `design/gdd/save-load.md` | Save / Load (SaveLoadService autoload) | 9 stories created 2026-04-30 | Ready |
| [localization-scaffold](localization-scaffold/EPIC.md) | Localization Scaffold (system 7) | `design/gdd/localization-scaffold.md` | Localization Scaffold (CSV convention; no autoload) | 5 stories created 2026-04-30 | Ready (governing ADR-0004 Proposed pending G5; G5 affects formatted body, not localization mechanism) |
| [level-streaming](level-streaming/EPIC.md) | Level Streaming (system 9 — Foundation per `architecture.md` §122) | `design/gdd/level-streaming.md` | Level Streaming (LevelStreamingService autoload) | 10 stories created 2026-04-30 | Ready |

## Core Layer (3 epics — created 2026-04-30)

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [input](input/EPIC.md) | Input (system 2) | `design/gdd/input.md` | Input (InputContext autoload + InputActions static class) | Not yet created — run `/create-stories input` | Ready (governing ADR-0004 Proposed pending G5 unrelated scope) |
| [player-character](player-character/EPIC.md) | Player Character (system 8) | `design/gdd/player-character.md` | Player Character (PlayerCharacter scene root = CharacterBody3D) | Not yet created — run `/create-stories player-character` | Ready (governing ADR-0005 + ADR-0008 Proposed; gates 3-5 close via this epic's hands rendering production story — chicken-and-egg by design) |
| [footstep-component](footstep-component/EPIC.md) | FootstepComponent (system 8b) | `design/gdd/footstep-component.md` | FootstepComponent (child node of PlayerCharacter) | Not yet created — run `/create-stories footstep-component` | Ready |

## Feature Layer (pending)

Run `/create-epics layer: feature` after Core epics + their stories are
defined. Feature systems include Stealth AI, Combat & Damage, Inventory &
Gadgets, Civilian AI, Document Collection, Mission & Level Scripting,
Failure & Respawn.

## Presentation Layer (pending)

Run `/create-epics layer: presentation` after Feature epics + their stories
are defined. Presentation systems include Audio, Outline Pipeline,
Post-Process Stack, HUD Core, HUD State Signaling, Document Overlay UI,
Menu System, Cutscenes & Mission Cards, Settings & Accessibility, Dialogue
& Subtitles. Most Presentation epics are gated on the rendering ADRs
(ADR-0001, ADR-0005) reaching Accepted via the post-Sprint-01 CompositorEffect
verification spike.

## Status Summary

- **4 Foundation epics** created (2026-04-29) + stories complete (2026-04-30): signal-bus (7), save-load (9), localization-scaffold (5), level-streaming (10) = **31 Foundation stories ready**.
- **3 Core epics** created (2026-04-30); stories not yet broken down — run `/create-stories input` / `/create-stories player-character` / `/create-stories footstep-component` next.
- **0 Feature / Presentation epics** — created on demand as Core epics complete.

## Related

- `docs/architecture/control-manifest.md` — programmer rules sheet (Manifest Version 2026-04-30; PARTIAL — Foundation + Core only)
- `docs/architecture/architecture.md` — module ownership table (§3.1 Foundation Layer + §3.2 Core Layer)
- `docs/architecture/tr-registry.yaml` — TR-ID → ADR coverage map
- `production/sprints/sprint-01-technical-verification-spike.md` — verification spike that promoted 4 of 8 ADRs to Accepted, unblocking Foundation epics
- `prototypes/verification-spike/verification-log.md` — per-ADR-per-gate evidence log
