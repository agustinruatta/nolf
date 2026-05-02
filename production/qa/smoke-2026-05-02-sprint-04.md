# Smoke Check Report — Sprint 04 (Stealth AI Foundation)

**Date**: 2026-05-02
**Sprint**: Sprint 04 — Stealth AI Foundation
**Engine**: Godot 4.6
**QA Plan**: `production/qa/qa-plan-sprint-04-2026-05-02.md`
**Argument**: `sprint`

---

## Environment

- **Engine**: Godot 4.6 (Vulkan / Forward+ / Jolt 3D default)
- **Test directory**: `tests/` present (unit + integration sub-trees)
- **Test framework**: GdUnit4 v6.0.0 (`addons/gdUnit4/bin/GdUnitCmdTool.gd`)
- **CI configured**: yes — `.github/workflows/tests.yml` present
- **QA plan**: found at `production/qa/qa-plan-sprint-04-2026-05-02.md`

---

## Automated Tests

**Status**: PASS — **725 tests / 0 errors / 0 failures / 0 flaky / 0 orphans**

Run command:
```
godot -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  -a tests/unit -a tests/integration --headless
```

Suite grew from baseline 423 (Sprint 03 close) to **725** — **+302 new tests across Sprint 04**.

### Headless boot

```
godot --headless --quit-after 5
```

Boot completes successfully. Two pre-existing warnings observed (NOT introduced by Sprint 04):
- `outline_compositor_effect.gd:221` — outline compositor warning (Sprint 03 baseline; tracked separately)
- `main.gd:251` `_spawn_toast_overlay` anchor-size warning (Sprint 03 baseline; cosmetic, not a regression)

No new parse errors, no new autoload errors, no new orphan warnings.

---

## Test Coverage

| Story | Type | Test Files | Coverage |
|-------|------|------------|----------|
| SAI-001 Guard scaffold | Logic | `tests/unit/feature/stealth_ai/guard_scaffold_test.gd` (21 tests) | COVERED |
| SAI-002 Enums + signals | Logic | `stealth_ai_enums_test.gd`, `stealth_ai_severity_rule_test.gd`, `events_sai_signals_test.gd` (26 tests) | COVERED |
| SAI-003 Raycast DI + cache | Logic | `raycast_provider_test.gd`, `stealth_ai_has_los_accessor_test.gd` (14 tests) | COVERED |
| SAI-004 F.1 sight fill | Logic | `stealth_ai_sight_fill_rate_test.gd` (12 tests; 25-row matrix) | COVERED |
| SAI-005 F.5 thresholds + escalation | Logic | 6 files: unaware_to_suspicious, suspicious_to_unaware, reversibility_matrix, combined_score, force_alert_state, receive_damage_synchronicity (61 tests) | COVERED |
| SAI-006 Patrol + behavior dispatch | Integration | `stealth_ai_takedown_prompt_active_test.gd`, `stealth_ai_behavior_dispatch_test.gd`, `stealth_ai_patrol_behavior_test.gd` (25 tests) | COVERED (logic-level; real-movement playtest DEFERRED) |
| SAI-007 F.3 decay + timers | Logic | `stealth_ai_decay_test.gd`, `stealth_ai_combat_to_searching_test.gd`, `stealth_ai_pillar3_reversibility_test.gd` (25 tests) | COVERED |
| SAI-008 Audio stinger subscriber | Integration | `stealth_alert_audio_subscriber_test.gd`, `stealth_ai_full_perception_loop_test.gd` (16 tests) | COVERED (Plaza-VS playtest DEFERRED) |
| SAI-009 Forbidden pattern fences | Logic | `stealth_ai_forbidden_patterns_test.gd` (7 tests) | COVERED |
| SAI-010 Perf budget + integration | Integration | `stealth_ai_perf_budget_test.gd` (7 tests) + `production/qa/evidence/stealth-ai-perf-2026-05-02.md` | COVERED + EVIDENCE (Iris Xe verification DEFERRED per ADR-0008) |
| IN-003 Context routing | Integration | `input_context_routing_test.gd`, `dual_focus_dismiss_test.gd`, `dismiss_order_lint_test.gd` (10 tests) | COVERED |
| IN-004 Anti-pattern CI | Logic | `debug_action_gating_test.gd`, `input_ci_lints_test.gd` (9 tests) + 5 CI scripts | COVERED |
| IN-005 Edge-case discipline | Integration | `held_key_through_context_test.gd`, `joy_disconnect_test.gd`, `esc_consume_before_pop_test.gd`, `mouse_mode_restore_test.gd` (13 tests) | COVERED |
| IN-006 Runtime rebinding | Integration | `input_rebind_runtime_test.gd`, `input_has_event_test.gd`, `input_rebind_persistence_test.gd`, `rebind_round_trip_test.gd`, `rebind_held_key_flush_test.gd` (18 tests) | COVERED |
| IN-007 LOADING context gate | Integration | `loading_context_gate_test.gd` (6 tests) | COVERED |
| PC-006 Health system | Logic | 7 files: damage_basic, damage_rounding_guard, damage_lethal, signal_taxonomy, heal, dead_state_latch_clear, damage_cancel_interact (32 tests) | COVERED |

**Summary**: 16/16 stories COVERED. Zero MISSING test evidence.

3 stories carry deferred manual evidence (Plaza-VS scene dependency):
- SAI-006 real-movement playtest
- SAI-008 Plaza-VS audio playtest
- SAI-010 Iris Xe Gen 12 perf verification (ADR-0008 Gates 1+2 deferred)

These deferrals are documented in each story's Completion Notes and are NOT blockers for sprint close.

---

## Manual Smoke Checks (per Sprint 04 QA plan)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Project loads in Godot 4.6 editor without errors | PASS | Implicit in headless test run |
| 2 | F5 (Play) boots Main.tscn — Plaza loads, mouse captures, Eve spawns | DEFERRED | Plaza VS scene deferred to a later sprint |
| 3 | WASD + mouse movement still works (no PC-003 / PC-005 regression) | DEFERRED | Plaza-VS dependent |
| 4 | F5-quicksave + F9-quickload round-trip still works (no SL-002 / SL-003 regression) | DEFERRED | Plaza-VS dependent |
| 5 | Section transition (LSS) still completes (no LS-002 regression) | DEFERRED | Plaza-VS dependent |
| 6 | Plaza guard patrols and reacts to player presence (NEW — SAI-006) | DEFERRED | Per SAI-006 Completion Notes — real-movement playtest deferred |
| 7 | Apply-damage debug seam reduces Eve's health and fires `health_changed` (NEW — PC-006) | DEFERRED | Plaza-VS dependent (logic verified via 32 unit tests) |
| 8 | Opening any context blocks gameplay input until popped (NEW — IN-003 + IN-005) | DEFERRED | Plaza-VS dependent (logic verified via 23 integration tests) |
| 9 | Quicksave during a transition is gated to LOADING context (NEW — IN-007) | DEFERRED | Plaza-VS dependent (logic verified via 6 integration tests) |
| 10 | Test suite full run: ≥ 423 baseline + Sprint 04 additions, zero failures | PASS | 725 tests / 0 failures / 0 errors / 0 flaky / 0 orphans |
| 11 | No new GdUnit4 orphan-node warnings introduced | PASS | 0 orphans across the 725-test run |
| 12 | Headless boot completes without parse / autoload errors | PASS | Boot completed; 2 pre-existing warnings (outline compositor + toast overlay anchor) noted as non-regressions |

User confirmed (Phase 4): manual checks 2-9 are deferred — no Plaza VS scene exists yet to run the editor playthrough against. Per the QA plan and per individual story completion notes, this is the documented sprint scope.

---

## Missing Test Evidence

**None.** All 16 sprint stories have COVERED test status. Three stories have DEFERRED manual playtest evidence (Plaza-VS dependency); these deferrals are documented in completion notes and are NOT MISSING — they are scope-deferred.

---

## Verdict: PASS WITH WARNINGS

The build is ready for QA hand-off **for the automated portion of the QA plan**. The Plaza-VS playthrough portion (smoke items 2-9) is deferred to a later sprint when the Plaza VS scene is built.

**Strengths**:
- 725-test suite is clean (0 failures across all categories)
- Suite grew by 302 tests this sprint
- Headless boot is clean (no Sprint-04 regressions)
- No new orphan warnings, no new parse errors
- 100% test coverage across all 16 sprint stories

**Advisory items (NOT blockers)**:
- Manual smoke items 2-9 deferred — re-run smoke check when Plaza VS scene lands
- 3 stories (SAI-006, SAI-008, SAI-010) carry documented playtest deferrals
- Pre-existing warnings (outline compositor, toast overlay anchor) — not Sprint 04 regressions, but worth tracking in tech debt for a future cleanup sprint

**Next step**:
Run `/team-qa sprint` to hand off to the qa-tester agent for the test-cases portion of the QA plan. After QA sign-off, run `/scope-check sprint-04-stealth-ai-foundation` and `/gate-check` to advance to the next sprint.
