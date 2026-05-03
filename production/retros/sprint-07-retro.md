# Sprint 07 Retrospective — Audio Body & Document Logic

**Sprint**: 07
**Window**: 2026-05-03 → 2026-05-09 (delivered same-day, 2026-05-03, autonomous-execution)
**Mode**: solo review (per `production/review-mode.txt`)
**Author**: producer synthesis on autonomous executor's session-state + smoke-check + scope-check + QA sign-off
**Date**: 2026-05-03

---

## TL;DR

12/12 Must-Have stories Complete. Scope verdict PASS (0 additions / 0 removals). 18 new test files / 127 new test functions. All 8 sprint-caused regressions fixed in-loop. The interesting issues this sprint were not the planned work — they were the surfacing of Sprint 06 anti-pattern leftovers (TD-010 + TD-011) and the formalising of TD-009 from prose into the register. The autonomous executor flagged one BLOCKING code-review defect (DC-004 AC-7 logic inversion) and self-corrected mid-loop. Tech-debt register sits at 11/12 — one slot from the hard stop.

---

## What went well

1. **Scope discipline held perfectly.** Plan said 12 stories; delivered exactly 12. No additions, no surprise spillover. The pre-sprint roadmap reconciliation (sprint-07.md lines 65–86) calling out exactly which AUD/DC/PPS stories were in vs. out paid for itself — every "is this in scope?" question was already answered before the executor reached it.

2. **Stub-driven decoupling for ADR-0004-blocked surfaces worked.** PPS-003 shipped against a stubbed `SepiaDimEffect.set_dim_intensity()` interface rather than blocking on PPS-002 (which is overlay-UI tied and ADR-0004 G5-blocked). This is the pattern we want for any story whose ideal upstream is gated — define a 1-method interface contract, ship logic against it, file the contract in architecture.md.

3. **The Visual/Feel ADVISORY gate did its job.** PPS-007 (8 ACs, all visual) was correctly classified as ADVISORY rather than BLOCKING and deferred behind MVP build availability. Evidence template files were authored at `production/qa/evidence/post-process-stack-{perf,visual}-evidence.md` — when the build is available, populating them is a fill-in-the-blanks task, not new authoring. Same for DC-005 AC-7.

4. **Mid-loop code review caught a real defect before sprint close.** DC-004 AC-7 had a test-logic inversion (`assert_that(restored_state.collected).is_empty()` after a save round-trip that should have populated it). Fixed via a sentinel-value approach. The story was NOT marked Complete until this was resolved — exactly the gate behaviour the workflow intends.

5. **Cross-suite regression hunt was thorough.** Eight Sprint-07-caused failures surfaced across audio + post-process + localization + level-streaming suites. All eight were diagnosed and fixed in-session; final smoke check zero-failures-from-sprint-07. The diff-against-`81035c7` audit cleanly separated Sprint 07 regressions from Sprint 06 leftovers.

---

## What hurt

1. **Pre-existing Sprint 06 anti-pattern violations surfaced as Sprint 07 "noise".** Five test failures in the final smoke (raw `KEY_*` constants in `main.gd`, hardcoded `"100"` in `hud_core.gd`, three `player_interact_cap_warning` resolution-logic failures) were inherited from Sprint 06 but only formally tracked in prose, not in `docs/tech-debt-register.md`. Sprint 07 had to do the bookkeeping work of promoting them to TD-008..TD-011. **Lesson: when a sprint sign-off identifies a tech-debt item, it must land in the register file the same session — not "queued" in the sign-off doc.**

2. **CR-7 sole-publisher violation (KEY_F4 → DocumentCollection mutation in `main.gd`) lurked from Sprint 06 into Sprint 07.** The DC-003 implementation discovered it because it directly conflicted with the `document_*` signal sole-publisher contract. Removed during DC-003 — but it should have been caught by the architecture-review pass at Sprint 06 close. **Lesson: every debug-key block needs an explicit "what does this signal/mutate" review at sprint close, not just an architecture review of the production paths.**

3. **DC-004 AC-7 test logic inversion almost shipped.** The original test asserted `is_empty()` on a state that should have been populated. The autonomous executor caught it on the second code-review pass — not the first. Logic-inversion is the single most-dangerous bug class in tests because the test passes for the wrong reason; both author and reviewer can miss it. **Lesson: any save-round-trip / capture-restore test pair should have a paired sentinel — distinct values populated before save, asserted distinct after restore — not a generic `is_empty()` / `is_not_empty()` check.**

4. **Tech-debt register at 11/12 is uncomfortably close to the hard stop.** Sprint 08 has buffer for "regression-suite expansion" — that should explicitly include resolving TD-009 (`player_interact_cap_warning` resolver bug) to bring the register back below 10. If Sprint 08 surfaces 2+ more TD entries without payoff, global stop condition #8 will fire mid-sprint.

5. **DC-005 vs `scenes/sections/` filesystem permission was a false alarm.** The sprint plan called out the permission constraint as a HIGH-impact / MEDIUM-probability risk. In practice `scenes/sections/plaza.tscn` was modifiable and DC-005 placed the live document body without issue. **Lesson: re-verify the constraint at sprint plan time, not just propagate the risk forward from the prior sprint's close-out.** The constraint may have lifted between Sprint 06 close and Sprint 07 plan authoring.

---

## What we'd change

1. **Sprint sign-off must update `docs/tech-debt-register.md` atomically with the sign-off prose.** Don't allow "TD-008 logged in QA-signoff prose" to substitute for a register entry. Add a check to `/team-qa` or `/sprint-status` that diff's sign-off TD references against the register file.

2. **At sprint close, `/code-review src/core/main.gd` for any debug-key block.** A 5-minute review at sprint close on debug-only entry points would have caught the KEY_F4 sole-publisher violation in Sprint 06.

3. **Any save-round-trip Logic story gets a sentinel-value test pattern by default.** Document this in the test-evidence section of `coding-standards.md` so future Save/Load / Capture/Restore work uses it as the standard.

4. **Sprint plans should re-probe carryforward constraints, not just propagate them.** A 30-second `touch scenes/sections/.permission_probe` at plan time prevents propagating stale risks.

5. **Visual/Feel ADVISORY evidence templates should be authored at story-readiness time, not story-done time.** PPS-007's evidence templates were authored at story-done. Having them ready at story-readiness means QA can populate as the implementation progresses, not retroactively after.

---

## Action items (assigned to Sprint 08 or beyond)

| # | Action | Owner | Where |
|---|--------|-------|-------|
| 1 | Resolve TD-009 (`player_interact_cap_warning` resolver bug) | gameplay-programmer | Sprint 08 buffer slot |
| 2 | Resolve TD-010 + TD-011 (HC-006 leftover anti-pattern violations) — opportunistic if Sprint 08 buffer permits, else queue for cleanup sprint | gameplay-programmer / ui-programmer | Sprint 08 OR backlog |
| 3 | Add atomicity check: sign-off mentions TD-NNN ⇒ register MUST contain TD-NNN | qa-lead / producer | `/team-qa` skill update OR producer checklist |
| 4 | Document sentinel-value test pattern in coding-standards | qa-lead | `.claude/docs/coding-standards.md` Testing Standards section |
| 5 | Re-probe `scenes/sections/` filesystem permission at Sprint 08 plan time (carryforward HC-006 visual checks if it's lifted) | producer | Sprint 08 plan authoring |
| 6 | Populate PPS-007 + DC-005 AC-7 visual evidence when MVP build available | qa-tester | `production/qa/evidence/post-process-stack-*.md` |

---

## Stats

- **Stories planned**: 12
- **Stories delivered**: 12 (100%)
- **Scope additions**: 0
- **Scope removals**: 0
- **Sprint-caused regressions**: 8 (all fixed in-loop)
- **Pre-existing failures surfaced**: 5 (formalised as TD-009..TD-011)
- **New test files**: 18
- **New test functions**: 127
- **Code-review BLOCKING defects caught mid-loop**: 1 (DC-004 AC-7 logic inversion)
- **CR-7 sole-publisher violations removed**: 1 (`main.gd` KEY_F4 → DC mutation)
- **Tech-debt register**: 7 → 11 (4 added, 0 closed)
- **Forbidden-pattern fences registered**: 5
- **Visual/Feel ADVISORY evidence deferred**: 2 stories (DC-005 AC-7 + PPS-007 all 8 ACs)

---

## Recommendation for Sprint 08

Roadmap places Sprint 08 as the **final pre-art-integration sprint**: Level Streaming hardening (LS-001, LS-004, LS-005, LS-006, LS-009, LS-010 — 6 stories) + regression-suite expansion + smoke-check across all Sprint 04–07 outputs. Estimated 3 agent-days.

**Recommended buffer use**:
- **TD-009 fix** (`player_interact_cap_warning` resolver) — promote to a small bug-fix story
- **TD-010 + TD-011 cleanup** — opportunistic, fold into LS work where possible
- Re-probe filesystem permission for HC-006 visual deferral
- Populate PPS-007 + DC-005 AC-7 visual evidence IF an MVP build is producible at sprint close

Sprint 08 close = roadmap close = `/asset-spec` package authoring + art commission ask.
