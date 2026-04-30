# Epic: Dialogue & Subtitles

> **Layer**: Feature
> **GDD**: `design/gdd/dialogue-subtitles.md`
> **Architecture Module**: Dialogue & Subtitles (Subtitle = scene-tree-rooted `Control` node — NOT autoload per ADR-0007 since slots are full; Dialogue scheduler = sibling node)
> **Engine Risk**: LOW–MEDIUM (`AudioStreamPlayer` orchestration + `Label` text rendering; ADR-0004 G5 BBCode/AccessKit deferred)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories dialogue-subtitles`
> **Manifest Version**: 2026-04-30

## Overview

**Dialogue & Subtitles** is the Narrative-layer Vertical-Slice system that owns the scheduling, playback orchestration, and on-screen captioning of every spoken line in the game — from absurd guard banter and incidental civilian mutters to scripted radio chatter and BQA briefings. As infrastructure, it is the **sole publisher** of the ADR-0002 Dialogue domain signals `dialogue_line_started(speaker, line_id)` and `dialogue_line_finished()` (ADR-0002 L304, frozen — Audio is subscriber-only and owns ducking via Audio §F.1). Subtitle is a scene-tree-rooted Control node (NOT autoload per ADR-0007 — slots are full and project posture forbids further autoloads), claiming a sub-slot of ADR-0008 Slot 8 pooled residual.

Subtitle owns its **own visibility suppression** by subscribing to `Events.document_opened`, `Events.document_closed`, and `Events.ui_context_changed` — Document Overlay UI is forbidden from pushing suppression onto Subtitle (ADR-0004 §IG5 + Document Overlay FP-OV-6). As player-facing surface, Dialogue & Subtitles is **the entire comedic delivery vector** for Pillar 1 (Comedy Without Punchlines): the patrolling guard who mutters about his pension, the clerk arguing with a vending machine, the PHANTOM lieutenant's deadpan pep talk over the intercom. Captions render at the bottom-center with period-authentic typographic restraint (Pillar 5: no modern AAA chyron); they default ON at first launch per Settings & Accessibility CR-23 (WCAG SC 1.2.2). A stealth `CURIOSITY_BAIT` bark plays through to its full vocal completion even if alert state changes mid-line — the comedy beat owns its own duration.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Sole publisher of `dialogue_line_started(speaker: StringName, line_id: StringName)` and `dialogue_line_finished()` (ADR-0002 L304, frozen) | LOW |
| ADR-0004: UI Framework | Subtitle uses Theme resource + period typography (Futura/DIN/American Typewriter); IG5 self-suppression rule (subscribers manage own visibility, never pushed by other UI) | LOW–MEDIUM (Proposed — G5 BBCode/AccessKit deferred to runtime AT testing post-MVP; affects formatted body parsing, not VS plain-text rendering) |
| ADR-0007: Autoload Load Order Registry | NOT autoload — scene-tree Control node; slot pressure is at the cap | LOW |
| ADR-0008: Performance Budget Distribution | Sub-slot of Slot 8 pooled residual (0.8 ms shared cap with Civilian AI, MLS, Document Collection, F&R, Signal Bus dispatch overhead — per ADR-0008 §85 + §239) | LOW (Proposed — non-blocking; logic-tier dispatch + audio orchestration, not per-frame UI render) |

## GDD Requirements

**15 TR-IDs** in `tr-registry.yaml` (`TR-DLG-001` .. `TR-DLG-015`) cover:

- Two Dialogue-domain signal declarations (`dialogue_line_started`, `dialogue_line_finished`) with frozen payloads
- Subtitle Control node placement (bottom-center, period typography, restraint constraint)
- Default-ON captions at first launch (Settings & Accessibility CR-23 / WCAG SC 1.2.2)
- Self-suppression on `document_opened` / `document_closed` / `ui_context_changed`
- Vocal-scheduling carve-out: `CURIOSITY_BAIT` bark plays to completion across alert state change (Stealth AI L91)
- Audio-ducking handshake (Audio is subscriber-only; D&S never reaches into Audio mix bus directly)
- Translation key flow (`tr("dlg.[line_id]")` per ADR-0004; no literal content in code)
- Forbidden patterns (`subtitle_visibility_pushed_externally`, `audio_ducking_in_dialogue_subtitles`, `dialogue_signal_emitted_outside_d&s`)

Full requirement text: `docs/architecture/tr-registry.yaml` Dialogue & Subtitles section.

## VS Scope Guidance (for `/create-stories`)

The Vertical Slice exercises this system at **minimum viable depth**:
- **Include**: One scripted VO line at mission start (e.g., BQA briefing: "Sterling — the Plaza opening. Try not to draw attention."); subtitle Control node renders the line bottom-center; default-ON captions; both Dialogue-domain signal emissions; one `document_opened` → suppress → `document_closed` → restore flow; period typography from Theme resource.
- **Defer post-VS**: Guard banter library + idle-mutter scheduler (no civilian guards beyond the one stealth guard; banter is comedy beat 2+); `CURIOSITY_BAIT` vocal carve-out (no SUSPICIOUS-state bark in VS unless guard subsystem ships SUSPICIOUS); ADR-0004 G5 BBCode formatting (plain text only in VS); intercom radio chatter; multi-line conversation queue.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- One VO line plays at mission start with subtitle rendered bottom-center, default ON.
- Both Dialogue-domain signals (`dialogue_line_started`, `dialogue_line_finished`) declared on `Events.gd` per ADR-0002 with frozen payloads.
- Self-suppression flow demonstrably works: open Plaza document → subtitle hides → close document → subtitle restores (if line still playing).
- Theme resource registers Futura/DIN/American Typewriter; subtitle text uses period-authentic font.
- Forbidden-pattern fences registered (`subtitle_visibility_pushed_externally`, `audio_ducking_in_dialogue_subtitles`).
- Logic stories (signal contracts, suppression state machine) have passing unit tests in `tests/unit/feature/dialogue_subtitles/`; integration stories in `tests/integration/feature/dialogue_subtitles/`.
- Translation key (`dlg.bqa.briefing.opening`) registered in localization CSV.
- Evidence doc with screenshot of subtitle rendering during Plaza intro in `production/qa/evidence/`.

## Stories

Not yet created. Run `/create-stories dialogue-subtitles` (with VS-narrowed scope flag) to break this epic into implementable stories.
