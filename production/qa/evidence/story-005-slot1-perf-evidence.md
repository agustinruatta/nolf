# OUT-005 Slot 1 Performance Evidence — Plaza Outline Pipeline

**Story**: `production/epics/outline-pipeline/story-005-plaza-per-tier-visual-validation.md`
**Reference scene**: `tests/reference_scenes/outline_pipeline_plaza_demo.tscn`
**Status**: ⏸️ **PENDING USER MEASUREMENT** — capture procedure documented; values awaiting playtest run.

---

## Procedure

1. Open `tests/reference_scenes/outline_pipeline_plaza_demo.tscn` in Godot 4.6
2. Press **F6** (Run Current Scene)
3. Open the **Remote** debugger panel → **Profiler** → **Visual** tab
4. Start profiling; capture **300 frames** of steady-state running
5. Filter to category **GPU** → slot **PostProcess**
6. Record p50, p95, p99 of the per-frame CompositorEffect cost in ms
7. Repeat at `resolution_scale = 0.75` (set via Remote Inspector)
8. Repeat at `resolution_scale = 0.5` (lowest-quality preset)

---

## AC-7 — Per-frame outline pass cost (300-frame window)

Pass thresholds (per ADR-0001 + ADR-0008 Slot 3 sub-budget):

- **PASS**: p95 ≤ 2.0 ms
- **WARNING**: 2.0 ms < p95 ≤ 2.5 ms (within Slot 3 cap, over outline sub-budget)
- **FAIL**: p95 > 2.5 ms — investigate before sign-off

| Resolution scale | p50 (ms) | p95 (ms) | p99 (ms) | Verdict |
|------------------|----------|----------|----------|---------|
| 1.0 (native) | _____ | _____ | _____ | ⏳ |
| 0.75 | _____ | _____ | _____ | ⏳ |
| 0.5 | _____ | _____ | _____ | ⏳ |

---

## AC-8 — First-frame load time (Shader Baker active)

Expected: ≤16 ms (no first-frame stutter from shader compilation).

| Run | First-frame time (ms) | Pass / Fail |
|-----|----------------------|-------------|
| 1 | _____ | ⏳ |
| 2 | _____ | ⏳ |
| 3 (cold cache) | _____ | ⏳ |

---

## Hardware capture context (filled in at measurement time)

- **CPU model**: _____
- **GPU model**: _____
- **GPU driver version**: _____
- **OS**: _____
- **Godot version**: 4.6.2 stable (as of 2026-05-01)
- **Render resolution**: _____
- **Shadow cascade count**: 1 (locked per ADR-0008)

---

## Implementation status (2026-05-01 — Sprint 03 close-out)

- ✅ **OUT-003 GPU dispatch LANDED** — Stage 2 jump-flood compute pipeline
  is now actually dispatched. Measurement here will reflect the full Stage 1
  + Stage 2 cost, not just Stage 1 stencil passes (earlier caveat resolved).
- **ADR-0008 Slot 3 budget gate** (Iris Xe target hardware) is explicitly
  deferred post-VS per `production/epics/outline-pipeline/EPIC.md` VS Scope
  Guidance. The dev-hardware measurement here is an **interim** gate close
  for VS purposes; ADR-0008 Gate 1 (Iris Xe Restaurant scene) remains open.
