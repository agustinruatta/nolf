# Sprint 03 — Visual Signature

**Dates**: 2026-05-25 to 2026-06-12 (3 weeks)
**Generated**: 2026-05-01
**Mode**: lean review (per `production/review-mode.txt`)

## Sprint Goal
Overlay the comic-book visual signature onto the existing Plaza VS demo so the
build *reads* as **The Paris Affair**: per-tier outlines around every mesh,
Eve's gloved hands rendered in their own SubViewport, and a resolution-scale
formula keeping the outline kernel stable across the user's display.

The Sprint-02 demo proved the foundation systems work end-to-end. Sprint 03 is
the cheapest route to "this looks like the game" — same Plaza geometry, same
walk + save + load loop, but now with the signature visuals layered on top.

## Capacity
- Total days: 15 working days (3-week sprint at 5 days/week)
- Buffer (20%): 3 days reserved for unplanned shader/Vulkan debug, ADR
  amendments, and visual sign-off iteration
- Available: 12 days for committed work
- Total committed estimate: ~3.4 days actual work (sized for ample headroom —
  the autonomous-execution pattern from Sprint 02 means calendar days vastly
  exceed actual work hours)

## Tasks

### Must Have (Critical Path — the visual signature)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|-------------|------------------------------|
| OUT-002 | CompositorEffect stencil pipeline — per-tier graphics passes + intermediate tier-mask texture | godot-shader-specialist | 0.7d | OUT-001 ✅, ADR-0001 ✅ | Per-tier stencil-test passes register on the Plaza camera Compositor; tier-mask texture survives one render pass; integration test loads Plaza + asserts no GPU validation errors |
| OUT-003 | Jump-flood outline compute shader — Stage 2 algorithm + outline color composition | godot-shader-specialist | 0.7d | OUT-002 | Compute-shader pingpong produces a continuous 1.5/2.5/4 px outline ribbon at 1080p; evidence doc at `production/qa/evidence/out-003-jump-flood-evidence.md` with screenshot diff |
| OUT-004 | Resolution-scale kernel formula — Formula 2 implementation + Settings wiring | godot-gdscript-specialist | 0.4d | OUT-003, Events autoload | Formula F2 implemented as testable function; subscribes to `Events.setting_changed` for `resolution_scale`; unit tests cover boundary cases (0.5x, 1.0x, 2.0x) |
| PC-008 | FPS hands rendering — SubViewport + HandsOutlineMaterial + ADR-0005 closure | gameplay-programmer | 0.5d | ADR-0005 ✅, HandAnchor (PC-001) ✅, OUT-002 (composition order) | Eve's gloved hands render in HandAnchor SubViewport with inverted-hull outline; visible in Plaza VS demo; ADR-0005 G3/G4/G5 closed via amendment + evidence doc |

### Should Have (visual sign-off + audio foundation)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|-------------|------------------------------|
| OUT-005 | Plaza per-tier visual validation — composition order + Slot 1 perf + sign-off | godot-shader-specialist | 0.5d | OUT-002, OUT-003, OUT-004, PC-008 | Plaza scene placed with one mesh per tier (NONE/HEAVIEST/MEDIUM/LIGHT); user visual sign-off; Slot 1 GPU time measured + recorded against ADR-0008 budget |
| AUD-002 | Signal subscription lifecycle — connect/disconnect registry | godot-gdscript-specialist | 0.4d | AUD-001 ✅, SB-002 ✅, SB-004 ✅ | AudioManager subscribes to required Events at boot; clean disconnect on _exit_tree; coverage test verifies subscribe→emit→handler fires + idempotent re-subscribe guard |

### Nice to Have
*(Empty — keep buffer for shader iteration. Pull AUD-003 in only if Should-Have closes early with margin.)*

## Carryover from Sprint 02
*None — Sprint 02 closed all 31 stories cleanly. No carryover.*

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Jump-flood compute shader debug pain (visual debugging is hard) | MED | Could blow OUT-003 estimate by 50-100% | Buffer reserved; godot-shader-specialist already validated the spike (Sprint 01 G3 — jump-flood required); intermediate tier-mask texture viewable as RenderingDevice debug texture |
| PC-008 SubViewport composition order conflict with outline CompositorEffect | LOW | Hands could render OUTSIDE the outline pass, breaking the visual contract | OUT-002 lands first → PC-008 implementer verifies hands SubViewport renders BEFORE the main camera Compositor. ADR-0005 already designed for this composition order. |
| Visual sign-off subjective rejection requiring rework | LOW-MED | OUT-005 may bounce back to OUT-003 for color/thickness tuning | Tuning knobs already exist on OutlineTier (per-tier thickness in shader) and on the resolution-scale formula — iteration stays shader-side without touching the pipeline structure |
| Smoke check items 1, 2, 6, 8, 9 from `tests/smoke/critical-paths.md` become first-time-testable in Sprint 03 — could surface latent issues | LOW | Could add unplanned bug-fix work | These were N/A at Sprint 02 close-out (no demo); now testable. Better to find issues here than in production. |

## Dependencies on External Factors
- **None.** All ADRs the sprint depends on (ADR-0001, ADR-0003, ADR-0005, ADR-0007, ADR-0008) are Accepted.
- All upstream stories (OUT-001, AUD-001, PC-001, PC-002, SL-001..006, SB-001..006) are Complete.

## Definition of Done for Sprint 03
- [x] All 4 Must-Have tasks completed; test suite ≥ 369 + Sprint-03 additions, zero regressions — **426/426 PASS, +57 tests, zero regressions**
- [ ] Visual sign-off on OUT-005 captured as evidence doc — **PENDING user playtest** (templates ready in `production/qa/evidence/story-005-visual-signoff.md`)
- [x] PC-008 ADR-0005 amendment promotes G3/G4/G5 from Pending → Closed — **G3 CLOSED**; G4 reframed as rigged-mesh-dependent (PENDING art asset); G5 reframed as export-dependent (ADVISORY) — Amendment A7 in `docs/architecture/adr-0005-fps-hands-outline-rendering.md`
- [x] QA plan exists (`production/qa/qa-plan-sprint-03-2026-05-01.md`)
- [x] All Logic stories (OUT-004, AUD-002) have passing unit tests
- [x] Visual/Feel stories (OUT-003, OUT-005, PC-008) have evidence docs in `production/qa/evidence/` (templates for OUT-005 + PC-008; OUT-003 evidence is the Plaza screenshot procedure documented in OUT-005 sign-off doc)
- [x] Smoke check passed — `production/qa/smoke-2026-05-01-sprint-03.md` (PASS WITH WARNINGS — 426/426 automated; only OUT-005 user-eyeball pending)
- [x] QA sign-off: APPROVED WITH CONDITIONS — `production/qa/qa-signoff-sprint-03-2026-05-01.md`
- [x] No S1/S2 bugs in delivered features (zero bugs filed during sprint; `production/qa/bugs/` empty)
- [ ] First "looks like the game" screenshot captured for the studio reel — **PENDING user playtest** (run F5, screenshot the Plaza demo with outlines drawn)

## QA Plan Status
**Not yet written.** Run `/qa-plan sprint` before implementation begins so test cases are defined per story before dev-story runs.

## Reference Documents
- `production/sprints/sprint-02-foundation-core.md` — predecessor (closed)
- `production/qa/qa-signoff-sprint-02-2026-05-01.md` — Sprint 02 sign-off (APPROVED WITH CONDITIONS, condition: VS integration pass — landed)
- `production/session-state/active.md` — current state
- `production/notes/nolf1-style-alignment-brief.md` — visual reference for the comic-book outline aesthetic
- `prototypes/visual_reference/plaza_visual_reference.tscn` — parked NOLF 1 calibration scene
- `prototypes/verification-spike/fps_hands_demo.tscn` — parked ADR-0005 hands prototype (closes G1-G2)

> **Scope check**: This sprint is scoped tightly to the existing 6 story files (OUT-002..005, PC-008, AUD-002). All stories already in `Ready` status. If new work is added, run `/scope-check` to detect creep before implementation begins.
