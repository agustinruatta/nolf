# Epic: HUD State Signaling

> **Layer**: Presentation
> **GDD**: `design/gdd/hud-state-signaling.md`
> **Architecture Module**: HUD State Signaling (sibling Control under HUD Core `CanvasLayer`; NOT autoload)
> **Engine Risk**: LOW–MEDIUM (ADR-0004 Proposed pending G3/G4/G5)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories hud-state-signaling`
> **Manifest Version**: 2026-04-30

## Overview

HUD State Signaling (HSS) is the layer of feedback that reads gameplay state and translates it into screen-space cues — alert-state indicator, suspicion meter, document pickup toast, takedown availability prompt — without modifying the HUD Core widgets themselves. HSS reads HUD Core's `get_prompt_label()` extension hook and renders supplementary signals as transient overlays. It subscribes to Stealth AI domain signals (`alert_state_changed`, `actor_became_alerted`, `actor_lost_target`), Document Collection signals (`document_collected`), and Combat takedown signals.

Per HUD Core REV-2026-04-26 D3, HSS is split as a HARD MVP-Day-1 minimal slice = **ALERT_CUE only** (the suspicion meter + alert-state pulse). The full VS surface (toast queue, takedown prompt, propagation indicator) lands in the VS production sprint after the Day-1 minimum proves the integration pattern.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Subscriber to SAI + Combat + Document Collection domain signals; never publishes (read-side only) | LOW |
| ADR-0004: UI Framework | Theme resource consumed; rendering uses HUD Core `get_prompt_label()` hook; never pushes visibility into HUD Core or Subtitle | LOW–MEDIUM (Proposed) |
| ADR-0008: Performance Budget Distribution | Sub-slot of Slot 7 (shared with HUD Core, Document Overlay, Menu) | LOW (Proposed) |

## GDD Requirements

**13 TR-IDs** in `tr-registry.yaml` (`TR-HSS-001` .. `TR-HSS-013`) cover:

- Alert-cue render contract (Day-1 minimum slice — ALERT_CUE only)
- Document pickup toast (VS scope)
- Takedown availability prompt (VS scope, post-VS for actual takedown UX)
- Subscriber-only posture (no signal publishing)
- HUD Core extension via `get_prompt_label()` hook
- Forbidden patterns (`hss_pushing_visibility_to_hud_core`, `hss_publishing_signals`)

Full requirement text: `docs/architecture/tr-registry.yaml` HUD State Signaling section.

## VS Scope Guidance

- **Include (HARD MVP-Day-1 minimal slice)**: Alert-state pulse on `alert_state_changed(SUSPICIOUS)` and on COMBAT transition; subscriber wiring; sibling Control under HUD Core.
- **Include (VS scope)**: Document pickup toast on `document_collected`.
- **Defer post-VS**: Takedown availability prompt (no takedown gadget in VS); alert propagation indicator (one guard in VS); full toast queue (single-toast acceptable).

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- ALERT_CUE pulses visibly during Plaza VS when guard transitions to SUSPICIOUS.
- Document pickup toast renders briefly on `document_collected`.
- HSS is sibling Control under HUD Core CanvasLayer; never an autoload.
- Forbidden-pattern fences registered.
- Logic stories have unit tests in `tests/unit/presentation/hud_state_signaling/`; UI stories have evidence docs.

## Stories

Not yet created. Run `/create-stories hud-state-signaling` (with VS-narrowed scope flag) to break this epic into implementable stories.
