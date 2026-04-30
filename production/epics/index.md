# Epics Index

Last Updated: 2026-04-29
Engine: Godot 4.6
Manifest Version: 2026-04-29 (PARTIAL — Foundation + Core layer rules only; `docs/architecture/control-manifest.md`)

## Foundation Layer (4 epics)

| Epic | System | GDD | Module | Stories | Status |
|------|--------|-----|--------|---------|--------|
| [signal-bus](signal-bus/EPIC.md) | Signal Bus (system 1) | `design/gdd/signal-bus.md` | Signal Bus (Events + EventLogger autoloads) | Not yet created — run `/create-stories signal-bus` | Ready |
| [save-load](save-load/EPIC.md) | Save / Load (system 6) | `design/gdd/save-load.md` | Save / Load (SaveLoadService autoload) | Not yet created — run `/create-stories save-load` | Ready |
| [localization-scaffold](localization-scaffold/EPIC.md) | Localization Scaffold (system 7) | `design/gdd/localization-scaffold.md` | Localization Scaffold (CSV convention; no autoload) | Not yet created — run `/create-stories localization-scaffold` | Ready (governing ADR-0004 Proposed pending G5; G5 affects formatted body, not localization mechanism) |
| [level-streaming](level-streaming/EPIC.md) | Level Streaming (system 9 — Foundation per `architecture.md` §122) | `design/gdd/level-streaming.md` | Level Streaming (LevelStreamingService autoload) | Not yet created — run `/create-stories level-streaming` | Ready |

## Core Layer (pending)

Run `/create-epics layer: core` to create Core-layer epics. Core systems per
`architecture.md` §3.2: Input (system 2), Player Character (system 8),
FootstepComponent (system 8b). Governing ADRs include ADR-0004 (UI Framework —
Proposed; G5 deferred), ADR-0006 (Collision Layer Contract — Accepted), and
ADR-0008 (Performance Budget Distribution — Proposed).

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

- **4 Foundation epics created** (2026-04-29). All have governing ADRs that
  are Accepted or have closed gates relevant to the system's scope.
- **0 Core / Feature / Presentation epics** — created on demand as the project
  advances.
- **Stories**: none yet — run `/create-stories [epic-slug]` per Foundation epic
  to begin breaking work into implementable units.

## Related

- `docs/architecture/control-manifest.md` — programmer rules sheet (Manifest Version 2026-04-29; PARTIAL — Foundation + Core only)
- `docs/architecture/architecture.md` — module ownership table (§3.1 Foundation Layer)
- `docs/architecture/tr-registry.yaml` — TR-ID → ADR coverage map
- `production/sprints/sprint-01-technical-verification-spike.md` — verification spike that promoted 4 of 8 ADRs to Accepted, unblocking Foundation epics
- `prototypes/verification-spike/verification-log.md` — per-ADR-per-gate evidence log
