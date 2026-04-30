# Epic: HUD Core

> **Layer**: Presentation
> **GDD**: `design/gdd/hud-core.md`
> **Architecture Module**: HUD Core (`CanvasLayer`-rooted scene under root; NOT autoload per ADR-0007)
> **Engine Risk**: LOW–MEDIUM (ADR-0004 UI Framework Proposed — gates G3/G4/G5 deferred to runtime AT testing post-MVP)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories hud-core`
> **Manifest Version**: 2026-04-30

## Overview

HUD Core is the screen-space reading surface that lets the player track every gameplay state without ever leaving Eve Sterling's first-person frame. It is simultaneously (a) the **subscriber layer** — a `CanvasLayer`-rooted scene listening to 8 frozen `Events` signals (`player_health_changed`, `player_damaged`, `player_died`, `player_interacted`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected`) and reading two PC-owned per-frame queries (`get_current_interact_target()`, `is_hand_busy()`) to drive the interact prompt — and (b) the **player-facing chrome** — three corner widgets and a contextual prompt strip rendered in NOLF1 (2000) typographic register: bottom-left numeric health, bottom-right weapon name + `current/reserve` ammo, top-right active-gadget tile, and a center-lower transient prompt strip (interaction prompts, pickup memos, "TAKEDOWN AVAILABLE"). The crosshair widget is the fourth and only center-screen element — opt-out by default-on.

HUD Core has HARD MVP-Day-1 dependencies on **HUD State Signaling** (alert-cue minimal slice — REV-B) and **Settings & Accessibility** (photosensitivity-toggle minimal UI — REV-B). It claims **Slot 7 = 0.3 ms cap** in the ADR-0008 frame budget.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Subscriber to 8 frozen signals from PC + Inventory + Combat domains; reads PC queries `get_current_interact_target()` + `is_hand_busy()` directly (read-side allowed) | LOW |
| ADR-0004: UI Framework | Theme resource (Futura/DIN/American Typewriter); period typographic restraint per Pillar 5; key-glyph rebinding contract via Input integration | LOW–MEDIUM (Proposed — G3/G4/G5 deferred to runtime AT testing post-MVP) |
| ADR-0008: Performance Budget Distribution | Slot 7 = 0.3 ms cap per frame for HUD Core + HSS + Document Overlay + Menu | LOW (Proposed — non-blocking; UI cost validated via Sprint 01 hands prototype) |

## GDD Requirements

**15 TR-IDs** in `tr-registry.yaml` (`TR-HUD-001` .. `TR-HUD-015`) cover:

- `CanvasLayer`-rooted scene placement (NOT autoload)
- Eight signal subscriptions (PC + Combat + Inventory domains)
- Two per-frame PC queries (`get_current_interact_target()`, `is_hand_busy()`)
- Three corner widgets (health bottom-left, ammo bottom-right, gadget top-right) + crosshair + prompt strip
- NOLF1-register typography (period-authentic, no modern AAA chyron)
- Resolution-independent crosshair (0.19% × viewport_v dot + tri-band halo)
- Slot 7 0.3 ms cap compliance
- HARD MVP-Day-1 dependencies (HSS alert-cue minimal slice, Settings photosensitivity-toggle minimal UI)
- `get_prompt_label()` extension hook (consumed by HSS)
- Forbidden patterns (`hud_subscribing_to_internal_state`, `hud_pushing_visibility_to_other_ui`)

Full requirement text: `docs/architecture/tr-registry.yaml` HUD Core section.

## VS Scope Guidance

VS exercises this system at **Day-1 HARD MVP slice** depth:
- **Include**: `CanvasLayer` scene root; health widget (numeric, bottom-left); interact prompt strip (subscriber to `get_current_interact_target()` query); pickup memo (subscriber to `document_collected`); Theme resource with NOLF1 typography; `get_prompt_label()` hook for HSS consumption.
- **Defer post-VS**: Ammo widget (no Combat in VS); gadget tile (no Inventory in VS); takedown prompt (no Stealth AI takedown in VS); damage flash (no Combat); crosshair (no aim-down-sights in VS); full prompt-strip rebind contract.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- HUD Core `CanvasLayer` scene exists and renders during Plaza VS gameplay.
- Interact-prompt strip subscribes to PC `get_current_interact_target()` and shows "Press E to read" near a Plaza document.
- Pickup memo briefly displays on `document_collected`.
- Theme resource registered with period-authentic font; visual sign-off in `production/qa/evidence/`.
- Slot 7 budget verified ≤0.3 ms via `/perf-profile`.
- Forbidden-pattern fences registered.
- Logic stories have unit tests in `tests/unit/presentation/hud_core/`; UI stories have evidence docs.

## Stories

Not yet created. Run `/create-stories hud-core` (with VS-narrowed scope flag) to break this epic into implementable stories.
