# Sprint 08 — Level Streaming Body & Integration Hardening

**Dates**: 2026-05-10 to 2026-05-16 (7 calendar days; autonomous-execution sprint)
**Generated**: 2026-05-03
**Mode**: solo review (per `production/review-mode.txt`)
**Source roadmap**: `production/sprints/multi-sprint-roadmap-pre-art.md` Sprint 08 section (lines 94–112)
**Roadmap status**: `production/sprint-roadmap-status.yaml` sprint #8 (will bump `current_sprint: 7` → `8` at sprint open)

## Sprint Goal

**Seamless section transitions across the full pipeline; close every code-ready epic. By close, the project is art-integration-ready.**

Sprint 04 made the level alive (perception → suspicion). Sprint 05 made it
durable (death → respawn → save). Sprint 06 dressed it (HUD + Settings).
Sprint 07 wrote the systemic body (audio + documents + post-process). Sprint 08
**closes the streaming spine**: section-to-section transitions across the full
pipeline, with concurrency control, error recovery, focus-loss handling,
quicksave/quickload through transitions, performance verification, and
anti-pattern fencing.

By close, the Plaza VS demo plays the full mission loop on proxy art —
patrol, perceive, evade, collect document, alert, fail, respawn, save/load,
**section-transition** — with no smoke-check regressions. **Project is then
art-integration-ready**: every code-ready system implemented and proven on
placeholder geometry. The next sprint pauses for art commission (`/asset-spec`
hero-asset list).

This sprint also closes one carry-over tech-debt item (TD-009 —
`player_interact_cap_warning.gd` resolver bug, 5 failing tests) to bring the
register from 11/12 back below 10 before the art-integration milestone.

## Capacity

- Total agent-time: ~3 days work-equivalent (per roadmap `estimated_agent_days: 3`)
- Buffer (20%): 0.6 day reserved for:
  - Regression-suite expansion across Sprint 04–07 outputs
  - Sprint 06 anti-pattern leftover cleanup if buffer permits (TD-010 + TD-011)
  - PPS-007 + DC-005 AC-7 visual evidence population if MVP build is producible
  - HC-006 visual sign-off carryforward if `scenes/sections/` filesystem permission re-probe lifts the constraint
- Available: ~2.4 days for committed work
- Total committed estimate: **~24–32 hours of agent work** (8 stories: 7 Level
  Streaming + 1 player-interact bug-fix Should-Have)

## Roadmap Reconciliation

The multi-sprint roadmap §Sprint 08 (lines 94–112) lists "Level Streaming
remaining ready: LS-001, LS-004, LS-005, LS-006, LS-009, LS-010 (6 stories)".
This is **stale by 4 LS stories**:

- **LS-001, LS-002, LS-003 are Complete** (LS-001 + LS-002 closed during
  Sprint 02 push; LS-003 closed 2026-05-01).
- **LS-007, LS-008** were not mentioned in the roadmap but are Ready and
  belong inside the streaming hardening scope (LS-007 = quicksave/quickload
  queue-during-transition; LS-008 = section authoring contract + stub
  scenes — both required for the "full mission loop" deliverable).

The **actual remaining ready Level Streaming stories** at Sprint 08 start are
**LS-004, LS-005, LS-006, LS-007, LS-008, LS-009, LS-010 = 7 stories**. All
seven are pulled into Sprint 08 because the deliverable ("seamless section
transitions across the full pipeline") cannot be claimed with any of these
7 missing.

Plus **1 Should-Have**: a focused bug-fix story for TD-009
(`player_interact_cap_warning.gd` resolver). This is not in the roadmap but is
required to keep the tech-debt register below the 12-item hard stop before
art integration.

Total Sprint 08 story count: **8** (7 Must-Have + 1 Should-Have), versus the
roadmap's 6 Must-Have count (which was based on a stale Ready set).

> **Note**: This is the *opposite* of scope creep — the sprint is delivering
> the same epic outcome (Level Streaming epic 100% closed) with 1 more story
> than the roadmap counted, because the roadmap missed LS-007 + LS-008. No
> new design work; no scope addition outside the original epic.

## Tasks

### Must Have — Level Streaming hardening (7)

| ID | Task | Agent/Owner | Est. (h) | Dependencies | Acceptance Criteria |
|----|------|-------------|----------|--------------|---------------------|
| LS-004 | Concurrency control: forward-drop, respawn-queue, abort recovery | godot-gdscript-specialist | 2–3 | LS-002 ✅ | Per `production/epics/level-streaming/story-004-concurrency-control-respawn-queue-abort.md` ACs |
| LS-005 | Registry failure paths + ErrorFallback CanvasLayer recovery | godot-gdscript-specialist | 2–3 | LS-002 ✅ + LS-004 | Per `production/epics/level-streaming/story-005-registry-failure-error-fallback-recovery.md` ACs |
| LS-006 | Same-section guard + focus-loss handling + cache mode | godot-gdscript-specialist | 2 | LS-002 ✅ | Per `production/epics/level-streaming/story-006-same-section-guard-focus-loss-cache-mode.md` ACs |
| LS-007 | F5/F9 quicksave/quickload queue during transition | godot-gdscript-specialist | 2–3 | LS-002 ✅ + LS-004 + Save/Load 007 ✅ | Per `production/epics/level-streaming/story-007-quicksave-quickload-queue-during-transition.md` ACs |
| LS-008 | Section authoring contract + stub scenes + Environment assignment | godot-gdscript-specialist | 2 | LS-002 ✅ | Per `production/epics/level-streaming/story-008-section-authoring-contract-stub-scenes.md` ACs |
| LS-009 | Anti-pattern fences + lint guards + CR-13 sync-subscriber detection | godot-gdscript-specialist | 2 | LS-002 ✅ + LS-003 ✅ + LS-008 | Per `production/epics/level-streaming/story-009-anti-pattern-fences-lint-guards.md` ACs |
| LS-010 | Performance budget measurement — p90 verification | godot-gdscript-specialist + technical-artist consult | 2–3 | LS-002 ✅ + LS-003 ✅ + LS-006 + LS-008 | Per `production/epics/level-streaming/story-010-performance-budget-p90-measurement.md` ACs (advisory until ADR-0008 G1 lands) |

### Should Have — Tech-debt fix (1)

| ID | Task | Agent/Owner | Est. (h) | Dependencies | Acceptance Criteria |
|----|------|-------------|----------|--------------|---------------------|
| PIC-FIX | TD-009: `player_interact_cap_warning.gd` resolver bug — fix 5 failing tests | gameplay-programmer + qa-tester consult | 2–3 | none | (a) `test_resolve_cap_exceeded_returns_within_cap` PASSES; (b) `test_resolve_cap_one_returns_a_stub` PASSES; (c) `test_resolve_within_cap_returns_priority_winner` PASSES; (d) Document(0) wins priority over Door(3)/Pickup(2); (e) cap=1 returns stub not null; (f) cap-exceeded returns within-cap target not null |

### Nice to Have — buffer cleanup

*If buffer permits after committed work closes:*

| ID | Task | Notes |
|----|------|-------|
| TD-010 | Migrate `main.gd:240..290` HC-006 debug F-keys to InputMap actions | Closes `input_ci_lints::check_raw_input_constants_passes` |
| TD-011 | Replace `hud_core.gd:528` hardcoded `"100"` with `tr()` call | Closes `localization_lint::lint_no_hardcoded_visible_string_in_src` |
| HC-006 visual checks | Re-probe `scenes/sections/` filesystem permission; if lifted, populate AC-2/3/4/6 visual evidence + Slot 7 perf measurement | Closes carryforward from Sprint 06 |
| PPS-007 + DC-005 AC-7 visual evidence | Populate templates if MVP build is producible | Closes Sprint 07 ADVISORY-gate carryforward |

## Carryover from Previous Sprints

| Task | Reason | New Estimate |
|------|--------|--------------|
| HC-006 visual checks (AC-2/3/4/6) + Slot 7 perf | `scenes/sections/` filesystem permission constraint blocked Plaza VS scene authoring during Sprint 06; deferred to user-driven Plaza VS playtest. **Re-probe at sprint open.** Sprint 07 found the constraint may have lifted (DC-005 placed a live document body successfully). If re-probe confirms permission is open, fold into LS-008 stub-scenes work. | – |
| SA-005 Settings panel UI shell | ADR-0004 G1 + G5 still OPEN. **Not pulled into Sprint 08** — defers to ADR-0004 closure. | – |
| Document Overlay UI epic (5 stories) | ADR-0004 G5 still OPEN (BBCode → AccessKit serialization). **Not pulled into Sprint 08.** | – |
| Menu System epic (4 stories) | ADR-0004 G1 OPEN. **Not pulled into Sprint 08.** | – |
| TD-009 (`player_interact_cap_warning` resolver bug) | 5 failing tests; promoted to **Should-Have PIC-FIX** above. | 2–3h |
| PPS-007 + DC-005 AC-7 visual evidence | Visual/Feel ADVISORY gate, deferred to MVP build. **Buffer task** if MVP build producible. | – |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| LS-010 p90 measurement requires Iris Xe Gen 12 hardware that the dev environment lacks | HIGH | LOW (ADR-0008 G1 still deferred — measurement is advisory; record-and-file is the deliverable) | LS-010 ships with measurements taken on dev hardware; Iris Xe re-measurement is a TD entry tied to the existing TD-002 (ADR-0008 numerical verification deferred) |
| Section transition queue interaction with Save/Load 007's quicksave queue (LS-007) introduces deadlock | LOW | HIGH (deadlock would make quicksave un-recoverable mid-transition) | LS-007 acceptance criteria explicitly require no-deadlock under all 4 ordering permutations; integration test mandatory; if deadlock surfaces, escalate to godot-specialist for state-machine review |
| LS-005 ErrorFallback CanvasLayer interferes with HUD CanvasLayer (z-order edge at 126/127) | LOW | MEDIUM (visible overlap with HUD) | LS-005 acceptance criteria specify CanvasLayer 126 for ErrorFallback (below HUD at 100, above world at 0); HUD at 100; fade overlay at 127. Layer assignments verified at story-readiness time |
| LS-009 anti-pattern lint guards over-fire on legitimate cross-autoload reads | MEDIUM | LOW (lint failure blocks CI but is a code-style flag, not a runtime issue) | LS-009 acceptance criteria require an explicit allowlist for verified-safe reads; lint output gated to WARN in dev, FAIL in CI |
| Tech-debt register exceeds 12 items (currently 11) if Sprint 08 surfaces 2+ new TDs without closing existing ones | MEDIUM | HIGH (global stop condition #8 — autonomous executor must stop) | PIC-FIX closes TD-009 mid-sprint, returning register to 10. Each story's `/code-review` round captures only non-architectural debt; architectural debt forces an ADR amendment (its own stop condition). |
| `scenes/sections/` filesystem permission constraint resurfaces and blocks LS-008 stub-scenes work | LOW | MEDIUM (LS-008 ships as test-only stubs without live `.tscn` files) | Re-probe at sprint open. If blocked, ship LS-008 as a unit-test-only contract with deferred .tscn authoring (same pattern as DC-005's Plaza tutorial fallback option) |
| Regression-suite expansion surfaces hidden failures in Sprint 04–07 outputs | MEDIUM | MEDIUM (smoke check fails; sprint cannot close without resolution) | Each surfaced regression triages as: (a) Sprint 08-caused → fix in-loop; (b) pre-existing → log as TD entry. Hard stop at >2 sprint-caused regressions surfaced. |

## Dependencies on External Factors

- **No art assets required** — all 7 LS stories + PIC-FIX are logic / config. LS-008 stub scenes use procedural PackedScenes, no `.glb` mesh dependencies.
- **No VO assets required** — Audio epic body is sealed at Sprint 07 close.
- **MVP build availability** — if a producible MVP build exists, populate PPS-007 + DC-005 AC-7 visual evidence (buffer task). If not, evidence remains DEFERRED per ADVISORY gate.
- **Iris Xe Gen 12 hardware** — LS-010 p90 measurement on Iris Xe is deferred per TD-002. Dev-hardware measurement files as an advisory record.

## ADR-0004 Status (carryforward)

ADR-0004 remains **Effectively-Accepted** (no change since Sprint 07):
- G1 (AccessKit property names on custom Controls): OPEN
- G5 (BBCode → AccessKit serialization): OPEN

Sprint 08 stories are **NOT** ADR-0004-blocked because LS-001..010 are
Foundation autoload + state machine logic (no Control/UI surface). PIC-FIX
is a logic resolver fix (no UI surface). Surface ADR-0004 status in Sprint 08
close-out only if it becomes a blocker mid-sprint (it shouldn't).

## Definition of Done for this Sprint

- [ ] All 7 Must-Have stories `Status: Complete`
- [ ] PIC-FIX Should-Have closes TD-009 (5 player_interact_cap tests PASS)
- [ ] Tech-debt register ≤10 items (down from 11; TD-009 closed)
- [ ] All Logic/Integration stories have passing tests in `tests/unit/level_streaming/`, `tests/integration/level_streaming/`, and `tests/unit/core/player_character/`
- [ ] QA plan exists at `production/qa/qa-plan-sprint-08-2026-05-10.md`
- [ ] Smoke check passed (`/smoke-check sprint`) — full Sprint 04–07 regression check + LS coverage
- [ ] `/scope-check sprint-08-level-streaming-integration` confirms 0 additions beyond LS-004..010 + PIC-FIX
- [ ] No S1 or S2 bugs in delivered features
- [ ] Cumulative test suite green (Sprint 07 baseline 1090 with 7 known pre-existing failures; Sprint 08 must add 0 new failures, AND close 5 of the 7 pre-existing — leaving 2 from TD-010/TD-011 if those are not picked up in buffer)
- [ ] **Roadmap close artefact**: `/asset-spec` hero asset list authored — Eve FPS hands, Eve full body, PHANTOM grunt + variants, Eiffel bay modules x3, bomb device, Plaza props
- [ ] **Stage transition signal**: `production/stage.txt` updated from "pre-production" to "art-integration-ready" — surface to user for approval

## Stop Conditions (per bootstrap; do NOT work around)

1. ADR ambiguity or amendment required (especially ADR-0007 — LS is the autoload load-order critical path; surface any LS story that requires the autoload contract to change)
2. Scope drift (`/scope-check` flags additions beyond the planned story IDs)
3. Visual sign-off needed (LS-005 ErrorFallback may surface one; LS-008 stub scenes if Environment assignment is questioned)
4. Art asset hard blocker (none expected — all stories logic/config)
5. Test failure or regression (>2 sprint-caused regressions = hard stop)
6. Cross-sprint dependency emerges (Save/Load 007 ↔ LS-007 ordering; surface immediately if integration is unstable)
7. Tech-debt register grows past 12 items (currently 11; PIC-FIX brings it to 10 — buffer is tight)
8. Manifest-version bump decision for save format (LS-007 quicksave queue interaction with `_assemble_quicksave_payload` may surface this)
9. Roadmap-close artefact ambiguity (`/asset-spec` hero list — what is and isn't a "hero" asset; user decision required at sprint close)

> **Scope check**: This sprint contains 1 story added beyond the literal roadmap text (LS-007 + LS-008 added; PIC-FIX added; LS-001 dropped as Complete) — net +1 vs roadmap, all within the same Level-Streaming-closure outcome. Document for `/scope-check` at sprint close.

## Next Steps

- `/qa-plan sprint` — produces `production/qa/qa-plan-sprint-08-2026-05-10.md`
- `/story-readiness production/epics/level-streaming/story-004-concurrency-control-respawn-queue-abort.md` — start the LS chain (LS-004 has no upstream Sprint-08 deps)
- `/dev-story` → `/code-review` → `/story-done` per story
- `/sprint-status` mid-sprint
- `/smoke-check sprint` + `/scope-check sprint-08-level-streaming-integration` at close
- `/asset-spec hero-set` at close (roadmap-close artefact)
- `/retrospective` at close

## QA Plan

Pending — `/qa-plan sprint` runs next per Phase 5 Step [A].
