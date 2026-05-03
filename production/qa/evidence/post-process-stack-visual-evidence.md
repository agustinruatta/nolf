# PPS-007 Visual Verification Evidence — DEFERRED to MVP Build

**Story**: PPS-007 Full-stack visual + performance verification (4.6 glow rework + Slot 3 budget)
**Story Type**: Visual/Feel (ADVISORY gate per coding-standards.md)
**Status**: DEFERRED — pending MVP build + Vulkan-Linux + Vulkan-Windows hardware
**Date**: 2026-05-03

## Acceptance Criteria Coverage Status

| AC | Description | Status | Notes |
|----|------------|--------|-------|
| AC-1 | Full chain renders without shader errors / Z-glitches | DEFERRED | Requires running MVP build; verification scene authoring is a sub-task of this story |
| AC-2 | Glow disabled — no halos around emissive surfaces | DEFERRED | PPS-005 enforces `WorldEnvironment.glow_enabled = false` at runtime. Visual confirmation pending MVP build with emissive material in scene. |
| AC-3 | Document Overlay card unaffected by sepia at full sat | DEFERRED | Requires Document Overlay UI scaffold (VS scope, #20). Stub CanvasLayer+ColorRect can substitute, but full evidence awaits real overlay. |
| AC-4 | resolution_scale = 0.75 — passes scale correctly | DEFERRED | PPS-006 wires the property. Visual confirmation requires running MVP build with both 1.0 and 0.75 captured. |
| AC-8 | Vulkan-Windows platform parity | DEFERRED | Requires Windows hardware access — see ADR-0008 Gate 4 deferral (same dependency). |

## Implementation Status (Code Layer)

All 6 prior PPS stories Complete and unit-tested:
- PPS-001 (Sprint 02): autoload scaffold + Compositor structure
- PPS-002 (DEFERRED): sepia-dim shader (overlay-UI tied, ADR-0004 G5)
- PPS-003 ✅: sepia-dim tween state machine (IDLE/FADING_IN/ACTIVE/FADING_OUT)
- PPS-004 (DEFERRED): overlay API (overlay-UI tied)
- PPS-005 ✅: WorldEnvironment glow ban + forbidden post-process enforcement (runtime + lint)
- PPS-006 ✅: resolution_scale subscription + Viewport.scaling_3d_scale wiring (runtime + lint)

The runtime stack is in place. What's missing for AC-1..AC-4 is the **render evidence** — screenshots and shader-error log inspection — which requires:
1. A built/running Godot project with all 6 stories integrated
2. The PPS-002 sepia-dim shader (deferred to overlay-UI sprint per ADR-0004 G5)
3. A test scene with intentional emissive material + stub overlay

## Re-Test Trigger

Resume PPS-007 verification when:
1. PPS-002 sepia-dim shader ships (post Document Overlay UI completion)
2. Verification scene authored at `tests/reference_scenes/post_process_stack_verify.tscn` (per story §Implementation Notes step 1)
3. Vulkan-Linux + Vulkan-Windows machines available for cross-platform parity capture

At that point, this file will be expanded with:
- Screenshot set (dim 0.0/0.5/1.0 × scale 1.0/0.75 = 6 images)
- Glow halo confirmation screenshot (emissive surface, AC-2)
- Document Overlay card sat-preservation screenshot (AC-3)
- Buffer type finding (pre-tonemap vs post-tonemap, Story 002 open question)
- Vulkan-Windows screenshots
- Lead sign-off

## Owner

QA Lead — schedule manual visual verification at MVP gate with art-director + technical-director sign-off.
