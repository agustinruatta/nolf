# Epic: Outline Pipeline

> **Layer**: Foundation
> **GDD**: `design/gdd/outline-pipeline.md`
> **Architecture Module**: Outline Pipeline (`CompositorEffect` chain on Forward+ render path; integrated into `PostProcessStack`)
> **Engine Risk**: HIGH (CompositorEffect + jump-flood algorithm; Vulkan-Linux + Vulkan-Windows targets per ADR-0001 Engine Compatibility; D3D12 explicitly disabled per technical-preferences)
> **Status**: Ready (Sprint 01 prototyped — `prototypes/verification-spike/` validated via user visual sign-off 2026-05-01)
> **Stories**: Not yet created — run `/create-stories outline-pipeline`
> **Manifest Version**: 2026-04-30

## Overview

Outline Pipeline is the **comic-book cel-outline post-process** that gives *The Paris Affair* its signature visual identity. It implements a stencil-buffer-driven outline pass via `CompositorEffect` on the Forward+ render path, consuming the per-mesh stencil tier values written per ADR-0001 (Eve = Tier 0 heaviest; documents = Tier 1; guards = Tier 2; environment = Tier 3 lightest). The outline thickness scales with stencil tier and uses a jump-flood algorithm for screen-space silhouette detection. Output is a screen-space outline composited onto the colour buffer before the Post-Process Stack's tone-mapping + glow chain.

Sprint 01 verification spike validated the CompositorEffect approach + jump-flood implementation against Godot 4.6 stable on Vulkan-Linux. ADR-0005 (FPS Hands Outline Rendering) was promoted from Proposed → Accepted via user visual sign-off on `fps_hands_demo.tscn` (2026-05-01). This epic productionises the prototype: integrates it into the main render path, formalises the stencil tier writes across Eve / guards / documents / environment, and validates draw-call cost against the ADR-0008 Slot 1 budget.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Stencil ID Contract | Per-mesh stencil tier values: Eve = 0 (heaviest 5 px); Doc = 1 (4 px); Guards = 2 (3 px); Env = 3 (lightest 2 px). Tier governs jump-flood radius. | LOW |
| ADR-0005: FPS Hands Outline Rendering | Native stencil_mode = Outline is world-space (Sprint 01 finding F4); FPS hands use dedicated subviewport composition; outline pipeline integrates with PC hands rendering | MEDIUM (Accepted; F1–F6 verified) |
| ADR-0008: Performance Budget Distribution | Outline Pipeline claims Slot 1 in the 16.6 ms frame budget; per-pixel shader cost; jump-flood radius affects cost | HIGH (Proposed — restaurant scene + Iris Xe hardware measurement deferred to first Production sprint that ships outline-bearing scene) |

## GDD Requirements

**10 TR-IDs** in `tr-registry.yaml` (`TR-OUT-001` .. `TR-OUT-010`) cover:

- `CompositorEffect` integration on Forward+ pipeline
- Jump-flood algorithm implementation (Sprint 01 F3 finding — algorithm constraint resolved)
- Per-tier outline thickness rendering (5 / 4 / 3 / 2 px @ 1080p)
- Stencil-buffer reads + screen-space silhouette
- Composition order (outline before glow + tone-mapping)
- Vulkan-Linux + Vulkan-Windows compatibility (D3D12 explicitly disabled — see technical-preferences + Sprint 01 F6)
- Slot 1 performance budget compliance
- ADR-0005 FPS hands integration handshake

Full requirement text: `docs/architecture/tr-registry.yaml` Outline Pipeline section.

## VS Scope Guidance

- **Include**: Productionised CompositorEffect on main render path; per-tier outline rendering for Eve hands (Tier 0), Plaza document (Tier 1), Plaza guard (Tier 2), Plaza environment (Tier 3); composition order verified; Slot 1 cost measured against ADR-0008 budget.
- **Defer post-VS**: Restaurant-scene reference cost measurement (planned for first Production sprint that ships outline-bearing complex scene); Iris Xe hardware measurement; per-tier outline-colour customisation beyond default; LOD-based thickness scaling.

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`.
- Outline visible on Eve hands + Plaza guard + Plaza document + Plaza environment, with correct per-tier thickness (visible at 10 m).
- CompositorEffect integrated into main render path; Sprint 01 prototype findings F1–F6 fully reflected in production code.
- Slot 1 cost measured ≤ ADR-0008 budget on minimum target hardware (Vulkan-Linux + Vulkan-Windows).
- Visual sign-off on production Plaza scene in `production/qa/evidence/` (replaces / augments the Sprint 01 sign-off on `fps_hands_demo.tscn`).
- Logic stories have unit tests where unit-testable (e.g., stencil tier value tables); shader stories have visual evidence + perf measurement.
- ADR-0008 Restaurant + Iris Xe deferral note updated with measurement schedule.

## Stories

| # | Story | Type | Status | TR-IDs | ADR |
|---|-------|------|--------|--------|-----|
| 001 | OutlineTier class scaffold — constants, set_tier(), validation | Logic | Ready | TR-OUT-001, TR-OUT-010 | ADR-0001 |
| 002 | CompositorEffect stencil-test pipeline — per-tier graphics passes + intermediate tier-mask texture | Integration | Ready | TR-OUT-005, TR-OUT-002, TR-OUT-009 | ADR-0001, ADR-0008 |
| 003 | Jump-flood outline compute shader — Stage 2 algorithm + outline color composition | Visual/Feel | Ready | TR-OUT-003, TR-OUT-006, TR-OUT-008 | ADR-0001, ADR-0008 |
| 004 | Resolution-scale kernel formula — Formula 2 implementation + Settings wiring | Logic | Ready | TR-OUT-004, TR-OUT-007 | ADR-0001, ADR-0005 |
| 005 | Plaza per-tier visual validation — composition order, Slot 1 perf measurement, sign-off | Visual/Feel | Ready | TR-OUT-002, TR-OUT-003, TR-OUT-005, TR-OUT-006, TR-OUT-009 | ADR-0001, ADR-0005, ADR-0008 |
