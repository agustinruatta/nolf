# Epic: Document Overlay UI

> **Layer**: Presentation
> **GDD**: `design/gdd/document-overlay-ui.md`
> **Architecture Module**: Document Overlay UI (`CanvasLayer`-rooted modal scene; NOT autoload per ADR-0007)
> **Engine Risk**: LOW–MEDIUM (ADR-0004 Proposed; ADR-0005 sepia-dim composition)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories document-overlay-ui`
> **Manifest Version**: 2026-04-30

## Overview

Document Overlay UI is the **full-screen reading modal** that renders a collected Document's body text in period-authentic typography against a sepia-dimmed game world. When the player triggers a read action on a pocketed document, this system: (1) acquires the modal `ui_context` via the input-context stack (ADR-0004); (2) calls `PostProcessStack.enable_sepia_dim()` to dim the world layer behind the modal; (3) emits `Events.document_opened(id)`; (4) renders the document body via `tr("doc.[id].body")` into a typographically restrained Control; (5) returns input + emits `Events.document_closed(id)` on dismiss.

It is the sole consumer of the `document_opened` / `document_closed` signal pair from Document Collection (Document Collection is sole publisher per ADR-0002). Per ADR-0004 §IG5, Document Overlay UI **never pushes visibility suppression** onto Subtitle or HUD State Signaling — those subscribers manage their own visibility by listening to `document_opened` / `document_closed` directly.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Subscriber to `document_opened(id)` / `document_closed(id)` from Document Collection domain | LOW |
| ADR-0004: UI Framework | Theme resource (period typography); input-context stack acquires modal context; IG5 — never pushes visibility into other UI surfaces | LOW–MEDIUM (Proposed) |
| ADR-0007: Autoload Load Order Registry | NOT autoload — modal `CanvasLayer` scene under root | LOW |
| ADR-0008: Performance Budget Distribution | Sub-slot of Slot 7 | LOW (Proposed) |

## GDD Requirements

**19 TR-IDs** in `tr-registry.yaml` (`TR-DOV-001` .. `TR-DOV-019`) cover:

- Modal `CanvasLayer` scene structure
- Input-context stack acquisition (modal context per ADR-0004)
- `PostProcessStack.enable_sepia_dim()` integration handshake
- `tr("doc.[id].body")` body rendering (translation key, never literal)
- Period typography (Theme resource)
- Open / close lifecycle synchronised with Document Collection signals
- Input-routing on close (re-acquire gameplay context)
- Forbidden patterns (`overlay_pushing_subtitle_visibility`, `overlay_publishing_document_signals`)
- FP-OV-6 — never push visibility into Subtitle (per ADR-0004 §IG5)

Full requirement text: `docs/architecture/tr-registry.yaml` Document Overlay UI section.

## VS Scope Guidance

- **Include**: Modal `CanvasLayer` opens on read-document action; sepia-dim composition handshake with Post-Process Stack; body text renders via `tr()`; close action emits `document_closed(id)`; input-context handover both directions; period typography from Theme resource.
- **Defer post-VS**: Multi-page document scrolling (one-page documents in VS); image/inline-asset embedding (text-only VS); BBCode formatted body (ADR-0004 G5 deferred); gamepad navigation polish.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- Plaza VS document opens to full-screen modal; world dims sepia; body text renders in period font; close returns input cleanly.
- Modal acquires + releases `ui_context` correctly via input-context stack.
- `document_opened` / `document_closed` signal handshake verified end-to-end (Subtitle + HSS suppress correctly via own subscriptions).
- Forbidden-pattern fences registered (`overlay_pushing_subtitle_visibility`).
- Logic stories have unit tests in `tests/unit/presentation/document_overlay_ui/`; UI stories have evidence docs with screenshot of opened document.

## Stories

Not yet created. Run `/create-stories document-overlay-ui` (with VS-narrowed scope flag) to break this epic into implementable stories.
