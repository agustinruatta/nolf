# PPS-007 Performance Verification Evidence — DEFERRED to MVP Build + Hardware

**Story**: PPS-007 Full-stack visual + performance verification
**Story Type**: Visual/Feel (ADVISORY gate per coding-standards.md)
**Status**: DEFERRED — pending MVP build + Iris Xe + RTX 2060 hardware access
**Date**: 2026-05-03
**Related ADR**: ADR-0008 Slot 3 Performance Budget Distribution

## Performance Targets (from story AC + GDD §AC-18)

| AC | Target | Measurement |
|----|--------|-------------|
| AC-5 | Sepia dim pass alone ≤0.5 ms (target ≤0.3 ms) at 1080p RTX 2060 | DEFERRED |
| AC-6 | Full chain ≤2.5 ms at 0.75 scale on Iris Xe profile | DEFERRED — also blocked on ADR-0008 Gate 1 (Iris Xe hardware) |
| AC-7 | Sepia dim IDLE contributes ~0 ms vs outline-only frame | DEFERRED |

## ADR-0008 Linkage

ADR-0008 Slot 3 allocates 2.5 ms total post-process budget on Iris Xe at 0.75 scale (outline 2.0 ms + sepia + composite 0.5 ms). ADR-0008 itself has Gates 1 + 2 deferred behind Restaurant reference scene + Iris Xe hardware. PPS-007 measurements are intended to inform the ADR-0008 Gate 1 pre-work; both gates close together when:
1. Restaurant dense-interior reference scene ships (later production sprint artifact)
2. Iris Xe hardware available for measurement
3. RTX 2060 reference machine available for desktop target validation

## Implementation Status (Code Layer)

The runtime stack capable of being profiled is in place:
- PPS-003 sepia-dim state machine: IDLE state short-circuits before CompositorEffect dispatch (AC-7 design intent)
- PPS-006 resolution scale: viewport.scaling_3d_scale wired via Events.setting_changed
- PPS-005 glow ban: WorldEnvironment.glow_enabled = false enforced at scene-load (eliminates rogue glow cost)

The PPS-002 sepia-dim shader itself is deferred to overlay-UI sprint (ADR-0004 G5). Without the production shader, the IDLE-vs-ACTIVE measurement comparison is moot.

## Re-Test Trigger

Resume PPS-007 performance profiling when:
1. PPS-002 sepia-dim shader ships
2. Restaurant reference scene authored (ADR-0008 Gate 1 scene)
3. Iris Xe + RTX 2060 hardware available
4. Godot 4.6 native profiler or `RenderingServer.get_frame_profile_measurement()` integrated into a perf-capture rig

At that point, this file will be expanded with:
- Hardware specs (CPU model, GPU model, OS, Vulkan driver version)
- Per-pass GPU timings (sepia ACTIVE p95, sepia IDLE p95, full chain p95)
- Resolution: 1080p native + 1080p × 0.75 scale
- ADR-0008 Slot 3 budget pass/fail verdict

## Owner

Performance Analyst — schedule profiling pass at MVP gate, joint with ADR-0008 Gate 1 measurement run.
