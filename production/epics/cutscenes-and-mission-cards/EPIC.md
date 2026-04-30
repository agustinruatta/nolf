# Epic: Cutscenes & Mission Cards

> **Layer**: Presentation
> **GDD**: `design/gdd/cutscenes-and-mission-cards.md`
> **Architecture Module**: Cutscenes & Mission Cards (`CanvasLayer` modal scene; NOT autoload per ADR-0007)
> **Engine Risk**: LOW (subscriber to mission signals + simple modal render)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories cutscenes-and-mission-cards`
> **Manifest Version**: 2026-04-30

## Overview

Cutscenes & Mission Cards (CMC) is the **between-scene narrative surface** that renders mission opening cards (BQA briefings: "Operation: Plaza Sweep — recover the Restaurant access papers"), section transitions, and the final mission-completion card. It subscribes to MLS-published Mission-domain signals (`mission_started`, `mission_completed`, `objective_started`, `objective_completed`) and consumes the input-context stack (ADR-0004) for modal acquisition. CMC is **pure VS scope** per systems-index — no MVP slice; MVP ships silent on `mission_started` per user Q2 decision 2026-04-28 night.

CMC owns its own period-authentic mission-card visual treatment (typography, BQA letterhead chrome) and audio handshake (Audio subscribes to `mission_card_shown` for diegetic mission-brief SFX). It is the comedic-tone delivery vector for mission framing — the deadpan BQA register that establishes the absurd stakes.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Subscriber to Mission domain signals from MLS; publishes `mission_card_shown` / `mission_card_dismissed` | LOW |
| ADR-0004: UI Framework | Theme resource (period typography); input-context stack acquires modal context | LOW–MEDIUM (Proposed) |
| ADR-0007: Autoload Load Order Registry | NOT autoload — modal `CanvasLayer` under root | LOW |
| ADR-0008: Performance Budget Distribution | Sub-slot of Slot 7 (only active during card display — zero per-frame cost when dismissed) | LOW (Proposed) |

## GDD Requirements

**15 TR-IDs** in `tr-registry.yaml` (`TR-CMC-001` .. `TR-CMC-015`) cover:

- Mission opening card render contract (BQA letterhead; period typography)
- Mission completion card render contract
- Section transition card (VS scope)
- Mission domain signal subscription (`mission_started` etc.)
- Input-context stack handover for modal display
- Audio handshake (`mission_card_shown` → Audio briefing SFX)
- Body text via `tr("mc.[id].body")` translation key
- EC-CMC-B.4 — load-from-slot during cutscene must safely tear down the cutscene (no contamination)
- Forbidden patterns (`cmc_publishing_mission_signals`, `cmc_pushing_subtitle_visibility`)

Full requirement text: `docs/architecture/tr-registry.yaml` Cutscenes & Mission Cards section.

## VS Scope Guidance

- **Include**: Opening mission card on `mission_started` ("Operation: Plaza Sweep"); mission completion card on `mission_completed`; period typography from Theme resource; input-context modal acquisition; translation keys for both card bodies.
- **Defer post-VS**: Section transition cards (one section in VS); cinematic cutscene timeline / scripted camera moves (no cutscenes in VS); skippable beat handling beyond simple dismiss; full BQA letterhead chrome (minimal placeholder OK in VS).

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- Plaza mission opening card displays on `mission_started`; dismissable; transitions input back to gameplay context.
- Mission completion card displays on `mission_completed`; dismissable to main menu.
- EC-CMC-B.4 verified: load-from-slot during cutscene safely tears down (no slot contamination).
- Forbidden-pattern fences registered.
- Logic stories have unit tests in `tests/unit/presentation/cutscenes_and_mission_cards/`; UI stories have evidence docs.
- Translation keys (`mc.plaza.opening.body`, `mc.plaza.completion.body`) registered in localization CSV.

## Stories

Not yet created. Run `/create-stories cutscenes-and-mission-cards` (with VS-narrowed scope flag) to break this epic into implementable stories.
