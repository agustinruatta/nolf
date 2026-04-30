# Epic: Document Collection

> **Layer**: Feature
> **GDD**: `design/gdd/document-collection.md`
> **Architecture Module**: Document Collection (per-section `StaticBody3D` pickup nodes + `Document` Resource schema; NOT autoload per ADR-0007 — analogous to `WorldItem` pattern)
> **Engine Risk**: LOW (pure architecture compliance — Resource + StaticBody3D + tr() lookups; no novel engine usage)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories document-collection`
> **Manifest Version**: 2026-04-30

## Overview

Document Collection is *The Paris Affair*'s **Pillar-2 reward loop layer plus the cross-system data contract** for in-world readable lore. As a data layer it owns the `Document` Resource schema (`class_name Document extends Resource` with `id: StringName`, `title_key: StringName`, `body_key: StringName`, `section_id: StringName`, optional `tier_override: int`, `interact_label_key: StringName`), the uncollected-document body (`StaticBody3D` on `LAYER_INTERACTABLES` per ADR-0006, stencil **Tier 1 (heaviest, 4 px @ 1080p)** per ADR-0001 so off-path documents read against 1960s interior chrome at ten metres), the three frozen Document-domain signals declared in ADR-0002 (`document_collected`, `document_opened`, `document_closed`), and the `DocumentCollectionState` sub-resource on `SaveGame` per ADR-0003 (ID-only persistence — never content).

As player-facing surface it is the **patient observer's reward** — every document is a 1965 BQA file, PHANTOM memo, Restaurant menu, telex transcript, or hand-typed dossier that Eve pockets without comment. Comedy lives in the typography (Pillar 1: requisition-memo register inherited from Inventory). All visible strings flow through `tr("doc.[id].title")` / `tr("doc.[id].body")` per ADR-0004 — content is NEVER baked into Document Resources, only translation keys are. Document Collection claims **≤0.05 ms steady-state from the ADR-0008 Slot 7/8 residual pool** — pure subscriber-of-`player_interacted` + emitter-of-3-signals with no per-frame work outside the pickup event.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Stencil ID Contract | Documents = **Tier 1 (heaviest, 4 px @ 1080p)** outline; stencil mode set on document mesh | LOW |
| ADR-0002: Signal Bus + Event Taxonomy | Three Document-domain signals frozen: `document_collected(id)`, `document_opened(id)`, `document_closed(id)` — Document Collection is sole publisher | LOW |
| ADR-0003: Save Format Contract | `DocumentCollectionState` sub-resource — `@export var collected: Array[StringName]`, ID-only schema, locked | LOW |
| ADR-0004: UI Framework | All visible doc strings via `tr("doc.[id].title")` / `tr("doc.[id].body")` — translation keys, never literal content | LOW (Proposed — G5 BBCode/AccessKit deferred to runtime AT testing post-MVP; does not block VS doc keys) |
| ADR-0006: Collision Layer Contract | Document `StaticBody3D` on `LAYER_INTERACTABLES`; raycast from PlayerCharacter on the same mask | LOW |
| ADR-0007: Autoload Load Order Registry | NOT autoload — per-section scene-tree node tree, analogous to `WorldItem` (Inventory CR-7 + MLS section authoring contract) | LOW |
| ADR-0008: Performance Budget Distribution | ≤0.05 ms steady-state from Slot 7/8 residual pool | LOW (Proposed — non-blocking for the negligible per-frame cost) |

## GDD Requirements

**15 TR-IDs** in `tr-registry.yaml` (`TR-DC-001` .. `TR-DC-015`) cover:

- `Document` Resource schema (6 fields, `class_name`-registered)
- Uncollected `StaticBody3D` body + stencil tier + collision layer
- Three Document-domain signal declarations + payload contracts
- `DocumentCollectionState` sub-resource shape (`Array[StringName]` of collected IDs)
- Locale-safe string flow (`tr("doc.[id].*")` — no content baking)
- Per-section node tree (NOT autoload) — section authoring contract
- Pickup → pocket → `document_collected` lifecycle
- Save persistence + restore behaviour
- Forbidden patterns (`document_content_baked_into_resource`, `document_signal_emitted_outside_dc`)

Full requirement text: `docs/architecture/tr-registry.yaml` Document Collection section.

## VS Scope Guidance (for `/create-stories`)

The Vertical Slice exercises this system at **minimum viable depth**:
- **Include (MVP scope per GDD)**: `Document` Resource schema, pickup → pocket → `document_collected` lifecycle, save persistence, locale-safe content keys, **one** Plaza tutorial document (validate the loop end-to-end).
- **Defer post-VS (VS scope per GDD — full roster phase)**: 15–25-document roster across all 5 Tower sections; `document_opened` / `document_closed` handoff to Document Overlay UI (handled in `document-overlay-ui` epic); pickup-toast handoff to HUD State Signaling.

The `document-overlay-ui` Presentation epic owns the full-screen reading modal and `PostProcessStack.enable_sepia_dim()` call — keep this epic focused on the data-layer + pickup loop only.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- `Document` Resource exists at `src/gameplay/document_collection/document.gd` with `class_name Document extends Resource` registered.
- One Plaza tutorial document is placeable in a section scene, raycast-interactable, fires `document_collected(id)` on pickup, persists in `SaveGame.documents.collected`.
- Round-trip integration test: place doc → collect → save → reload → verify `collected.has(doc_id)`.
- Forbidden-pattern fences registered (`document_content_baked_into_resource`, `document_signal_emitted_outside_dc`).
- Logic stories have unit tests in `tests/unit/feature/document_collection/`; integration stories in `tests/integration/feature/document_collection/`.
- Translation keys (`doc.plaza.welcome.title` / `doc.plaza.welcome.body`) registered in localization CSV; `tr()` calls verified.

## Stories

| # | Story | Type | Status | TR-IDs | ADR |
|---|-------|------|--------|--------|-----|
| 001 | [Document Resource schema + DocumentCollectionState sub-resource](story-001-document-resource-schema.md) | Logic | Ready | TR-DC-002, TR-DC-009 | ADR-0003 |
| 002 | [DocumentBody node — collision layer, stencil tier, interact priority](story-002-document-body-node.md) | Logic | Ready | TR-DC-003, TR-DC-004 | ADR-0006, ADR-0001 |
| 003 | [DocumentCollection node — subscribe/publish lifecycle + pickup handler](story-003-document-collection-node.md) | Logic | Ready | TR-DC-001, TR-DC-005, TR-DC-012, TR-DC-013, TR-DC-015 | ADR-0002, ADR-0007 |
| 004 | [Save/restore contract — capture(), restore(), spawn-gate](story-004-save-restore-contract.md) | Integration | Ready | TR-DC-006, TR-DC-007, TR-DC-008, TR-DC-014 | ADR-0003, ADR-0002 |
| 005 | [Plaza tutorial document set — placement, locale keys, end-to-end integration](story-005-plaza-tutorial-integration.md) | Integration | Ready | TR-DC-010 (partial), TR-DC-011 (partial) | ADR-0002, ADR-0003, ADR-0004, ADR-0006, ADR-0007 |
