# Epic: Post-Process Stack

> **Layer**: Foundation
> **GDD**: `design/gdd/post-process-stack.md`
> **Architecture Module**: Post-Process Stack (`CompositorEffect` chain + Environment chain on Forward+ render path; integrates Outline Pipeline)
> **Engine Risk**: MEDIUM (Godot 4.6 glow rework; CompositorEffect chain ordering; sepia-dim composition pass)
> **Status**: Ready (Sprint 01 prototyped via verification spike)
> **Stories**: Not yet created — run `/create-stories post-process-stack`
> **Manifest Version**: 2026-04-30

## Overview

Post-Process Stack is the **rendering pipeline composition layer** that orchestrates Outline Pipeline + tone-mapping + glow + sepia-dim into a deterministic chain on Forward+. It exposes a small public API consumed by other systems: `enable_sepia_dim()` / `disable_sepia_dim()` (called by Document Overlay UI when reading documents), `set_glow_intensity(value)` (driven by Settings & Accessibility photosensitivity slider), and `set_render_scale(value)` (driven by Settings performance options). Internally it owns the CompositorEffect chain ordering: world render → outline pass (ADR-0005 + ADR-0001 stencil tiers) → tone mapping → glow → sepia-dim overlay → final colour buffer.

Godot 4.6 changed glow significantly (rework noted in `docs/engine-reference/godot/VERSION.md`); this epic must verify that ADR-0005 + ADR-0001 still compose correctly under the 4.6 glow path. Sprint 01 prototyped the basic stack on Vulkan-Linux; this epic productionises it.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: FPS Hands Outline Rendering | Outline composes correctly under 4.6 glow rework; FPS hands subviewport composition integrated; Sprint 01 findings F1–F6 fully reflected | MEDIUM (Accepted) |
| ADR-0008: Performance Budget Distribution | Post-Process Stack claims Slot 2 in the 16.6 ms frame budget; chain cost (outline + glow + tone + sepia) | HIGH (Proposed — same hardware measurement deferral as Outline Pipeline) |

## GDD Requirements

**10 TR-IDs** in `tr-registry.yaml` (`TR-PPS-001` .. `TR-PPS-010`) cover:

- CompositorEffect chain ordering (world → outline → tone → glow → sepia → final)
- `enable_sepia_dim()` / `disable_sepia_dim()` public API
- `set_glow_intensity()` public API (Settings photosensitivity-driven)
- `set_render_scale()` public API (Settings performance-driven)
- Godot 4.6 glow rework compatibility verification
- Vulkan-Linux + Vulkan-Windows render-path validation
- Slot 2 performance budget compliance
- Forbidden patterns (`pps_publishing_signals`, `pps_modifying_outline_directly`)

Full requirement text: `docs/architecture/tr-registry.yaml` Post-Process Stack section.

## VS Scope Guidance

- **Include**: Production CompositorEffect chain (world → outline → tone → glow → sepia → final); `enable_sepia_dim()` / `disable_sepia_dim()` API working with Document Overlay UI; default glow intensity; default render scale; verification that 4.6 glow rework + ADR-0005 outline still compose.
- **Defer post-VS**: `set_glow_intensity()` / `set_render_scale()` Settings hookups (Settings UI is Day-1 minimum slice — full slider/option polish deferred); render-pipeline alternative paths (no Mobile-pipeline VS support).

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- Plaza VS renders through full Post-Process Stack with outline + tone + glow + (when triggered) sepia-dim.
- Document Overlay UI calls `enable_sepia_dim()` cleanly on `document_opened`; `disable_sepia_dim()` on `document_closed`.
- 4.6 glow rework + outline compose correctly (no shader compilation failures, no Z-order glitches) on Vulkan-Linux + Vulkan-Windows.
- Slot 2 cost measured ≤ ADR-0008 budget on minimum target hardware.
- Forbidden-pattern fences registered.
- Logic stories have unit tests where unit-testable (e.g., chain order const tables); shader stories have visual evidence + perf measurement.

## Stories

| # | Story | Type | Status | TR-IDs | ADR |
|---|-------|------|--------|--------|-----|
| 001 | PostProcessStack autoload scaffold + chain-order const table | Logic | Ready | TR-PP-001, TR-PP-007 | ADR-0007, ADR-0008 |
| 002 | Sepia dim CompositorEffect shader + Compositor wiring | Visual/Feel | Ready | TR-PP-003 | ADR-0005, ADR-0008 |
| 003 | Sepia dim tween state machine (IDLE/FADING_IN/ACTIVE/FADING_OUT) | Logic | Ready | TR-PP-002, TR-PP-003 | ADR-0005, ADR-0008 |
| 004 | Document Overlay API integration handshake | Integration | Ready | TR-PP-002, TR-PP-007 | ADR-0002, ADR-0008 |
| 005 | WorldEnvironment glow ban + forbidden post-process enforcement | Logic | Ready | TR-PP-004, TR-PP-005, TR-PP-006 | ADR-0005, ADR-0008 |
| 006 | Resolution scale subscription + Viewport.scaling_3d_scale wiring | Logic | Ready | TR-PP-008, TR-PP-010 | ADR-0002, ADR-0007 |
| 007 | Full-stack visual + performance verification (4.6 glow rework + Slot 3 budget) | Visual/Feel | Ready | TR-PP-009 | ADR-0005, ADR-0008 |
