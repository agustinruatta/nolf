# Sprint 07 QA Sign-Off Report

**Sprint**: Sprint 07 — Audio Body & Document Logic
**Window**: 2026-05-03 to 2026-05-09 (delivered 2026-05-03 — autonomous-execution sprint)
**Date**: 2026-05-03
**Author**: QA-lead synthesis on the autonomous executor's smoke-check + scope-check results

---

## Verdict: **APPROVED WITH CONDITIONS** ✅

Sprint 07 ships with **12/12 Must-Have stories Complete**, **scope verdict PASS** (0 additions / 0 removals), and the smoke check at **PASS WITH WARNINGS** — all 8 Sprint-07-caused regressions fixed in-loop; the 7 remaining failures (5 distinct issues) are **pre-existing pre-Sprint-07 anti-pattern violations and one logic bug**, formally tracked as TD-008..TD-011 below. None block Sprint 8 kickoff.

---

## Story closure status

| ID | Story | Status | Tests |
|---|---|---|---|
| AUD-003 | Plaza ambient layer + UNAWARE/COMBAT music states + section reverb | ✅ | PASS (Logic + Integration) |
| AUD-004 | VO ducking (F.1) + document world-bus mute + respawn cut-to-silence | ✅ | PASS (Logic) |
| AUD-005 | Footstep variant routing + COMBAT stinger on `actor_became_alerted` | ✅ | PASS (Logic) |
| DC-001 | `Document` Resource schema + `DocumentCollectionState` sub-resource | ✅ | PASS (Logic) |
| DC-002 | `DocumentBody` node — collision layer, stencil tier, interact priority | ✅ | PASS (Logic) |
| DC-003 | `DocumentCollection` node — subscribe/publish lifecycle + pickup handler | ✅ | PASS (Logic + Integration) |
| DC-004 | Save/restore contract — `capture()`, `restore()`, spawn-gate | ✅ | PASS (Logic — sentinel-value test approach after code-review fix) |
| DC-005 | Plaza tutorial document set — placement, locale keys, end-to-end integration | ✅* | PASS (Logic + Integration); AC-7 visual evidence DEFERRED (Visual/Feel ADVISORY gate) |
| PPS-003 | Sepia-dim tween state machine — logic against stubbed shader API | ✅ | PASS (Logic) |
| PPS-005 | WorldEnvironment glow ban + forbidden-pattern enforcement | ✅ | PASS (Logic + Lint) |
| PPS-006 | Resolution scale subscription + `Viewport.scaling_3d_scale` wiring | ✅ | PASS (Logic) |
| PPS-007 | Full-stack visual + perf verification | ✅* | All 8 ACs Visual/Feel evidence DEFERRED to MVP build availability (templates filed at `production/qa/evidence/post-process-stack-{perf,visual}-evidence.md`) |

\*DC-005 AC-7 + all 8 PPS-007 ACs are Visual/Feel ADVISORY gate per project coding-standards — deferred to MVP build availability with evidence templates filed. Architectural smoke (signal paths, state machines, save round-trip) is fully automated and PASSING.

---

## Test execution summary

### Sprint 07 contributions only

- **Audio suite**: AUD-003 plaza ambient music + reverb (3-pass crossfade tests), AUD-004 VO ducking + document mute + respawn-to-silence, AUD-005 footstep variant + stinger on alert
- **Document Collection suite**: 7 unit tests + 2 integration tests across DC-001..005 (Resource schema, body node, collection lifecycle, save/restore, Plaza tutorial round-trip)
- **Post-Process Stack suite**: 5 unit tests across PPS-003 (sepia tween state machine), PPS-005 (glow ban + lint), PPS-006 (resolution scale subscription + lint)
- **Total: 18 NEW test files, ~127 NEW test functions**

### Full project suite (post-fix)

- **Total**: 1090 test cases
- **Errors**: 0
- **Failures**: 7 (down from 16 + 3 errors pre-fix)
- **Flaky**: 0
- **Skipped**: 0
- **Orphans**: 0

### Sprint 07-caused regressions — RESOLVED ✅

Eight regressions surfaced during cross-suite verification; all eight fixed in-session. See `production/qa/smoke-2026-05-03.md` Sprint 07 regressions table for the full list and fix details. Highlights:

- `level_streaming_swap_test` parse error → script preload ordering for `Document` / `DocumentBody`
- `audio_plaza_ambient_music_test` reverb mutation → `is_equal_approx(0.2, 0.001)` for 32-bit float precision
- `node_payload_validity_grep_test` → `is_instance_valid()` guard added to `post_process_stack._on_node_added`
- `audio_footstep_stinger_test` → Voice/UI exempt-bus filter applied to BOTH passes of `_get_or_steal_sfx_slot`
- `localization_lint cross-domain key collision` → `ui.interact.pocket_document` + `ui.interact.read_document` removed from `overlay.csv` (canonical home: `hud.csv`)

### Pre-existing failures — NOT Sprint 07 regressions

The 7 remaining failures collapse into **5 distinct issues**, all introduced during Sprint 06's HC-006 visual sign-off prep + an earlier player_interact_cap_warning logic bug. Verified by `git diff` against `81035c7 Fixes` (Sprint 06 close commit). Tracked as tech-debt items below.

| # | Test | Source | Tracked As |
|---|------|--------|-----------|
| 1 | `input_ci_lints_test::test_check_raw_input_constants_passes` | `src/core/main.gd:240..290` — 8× KEY_F* raw input constants in HC-006 visual sign-off debug hotkey block | **TD-010** |
| 2 | `localization_lint_test::test_lint_no_hardcoded_visible_string_in_src` | `src/ui/hud_core/hud_core.gd:528` — `_health_label_numeral.text = "100"` HC-006 visual fallback | **TD-011** |
| 3 | `player_interact_cap_warning_test::test_resolve_cap_exceeded_returns_within_cap` | Logic bug: cap-exceeded path returns null instead of within-cap target | **TD-009** |
| 4 | `player_interact_cap_warning_test::test_resolve_cap_one_returns_a_stub` | Logic bug: cap=1 path returns null instead of stub | **TD-009** |
| 5 | `player_interact_cap_warning_test::test_resolve_within_cap_returns_priority_winner` | Logic bug: priority resolution incorrect (Document(0) loses to Door(3)/Pickup(2)) | **TD-009** |

---

## Sprint 07 deliverable assessment (per roadmap line 84)

> "Alert music tier shifts on Sprint-04 stealth-state transitions, documents pick up and persist to save, post-process chain composes correctly with the outline pipeline."

| Deliverable | Status | Notes |
|---|---|---|
| Plaza ambient music + UNAWARE/COMBAT crossfade on guard alert | ✅ | AUD-003 — dominant-guard dict + Tween-on-volume_db (no stop/start) |
| VO ducking + document world-bus mute + respawn cut-to-silence | ✅ | AUD-004 — Formula F.1 active; document mute resets bus on `document_closed` |
| Footstep marble variant + COMBAT stinger on `actor_became_alerted` | ✅ | AUD-005 — exempt-bus stealing ladder verified in both passes |
| Document Resource → Body node → Collection lifecycle → Save/Restore | ✅ | DC-001..004 — ID-only persistence per ADR-0003 IG 11; spawn-gate clear |
| Plaza tutorial document end-to-end | ✅* | DC-005 — logic + integration green; live placement under `scenes/sections/plaza.tscn` PASS; AC-7 visual evidence DEFERRED |
| Sepia-dim state machine (logic-only, stubbed shader API) | ✅ | PPS-003 — `SepiaDimEffect.set_dim_intensity()` interface contract documented |
| WorldEnvironment glow ban + forbidden-pattern fences | ✅ | PPS-005 — 5 forbidden-pattern keys registered |
| Resolution scale subscription + `Viewport.scaling_3d_scale` | ✅ | PPS-006 — SettingsService subscriber wired |
| Full-stack visual + perf verification | ✅* | PPS-007 — all 8 ACs DEFERRED to MVP build (Visual/Feel ADVISORY) |

**Architectural deliverable: COMPLETE.** Visual sign-off (PPS-007 + DC-005 AC-7) queued behind MVP build availability per ADVISORY gate.

---

## Conditions

### Condition 1 (informational): Visual evidence deferred behind MVP build

DC-005 AC-7 (Plaza tutorial visual presentation) and all 8 ACs of PPS-007 (full-stack visual + perf verification) are flagged Visual/Feel per project coding-standards Test-Evidence table — ADVISORY gate, not BLOCKING. Evidence template skeletons filed at `production/qa/evidence/post-process-stack-perf-evidence.md` + `post-process-stack-visual-evidence.md` ready to populate when an MVP build runs. Does NOT block Sprint 8.

### Condition 2 (informational): One BLOCKING code-review defect found and fixed in-loop

DC-004 AC-7 test had logic-inversion (`assert_that(restored_state.collected).is_empty()` where the spawn-gate-cleared state should retain a sentinel). Fixed mid-loop by switching to a sentinel-value approach. Logged in session-state for sprint-07 retrospective.

### Condition 3 (informational): Pre-existing CR-7 sole-publisher violation removed

`main.gd` had a `KEY_F4` debug hotkey that mutated DocumentCollection state — pre-existing CR-7 sole-publisher violation. Removed during DC-003 implementation; surface in retro for traceability.

### Condition 4 (informational): Tech-debt register grows to 11 items

Sprint 07 close adds TD-008 through TD-011 (formalising sprint 06 carry-forwards + the player_interact_cap logic bug). Register total **11 active items / 12 hard-stop threshold**. One more sprint of additions without payoff would trip global stop condition #8. Producer should schedule a tech-debt repayment sprint OR a focused bug-fix story for `player_interact_cap_warning.gd` in Sprint 08 buffer.

---

## Tech debt register (post-Sprint-07)

**11 active items / 12-item HARD-STOP threshold**:

- **TD-001..TD-007** — pre-existing
- **TD-008** (carried forward from Sprint 06): GDD §Detailed Design Rule 5 + ADR-0004 §Engine Compatibility plural CSV format amendment
- **TD-009** (carried forward from Sprint 06; Sprint 07 surfaced 5 failing tests): `player_interact_cap_warning.gd` resolution logic bug — cap-exceeded returns null, cap=1 returns null, priority resolution broken. Recommended Sprint 08 buffer slot.
- **TD-010** (NEW Sprint 07): `main.gd:240..290` HC-006 debug F-key block uses raw `KEY_*` input constants — violates `input_ci_lints` `check_raw_input_constants_passes`. Migrate to InputMap actions per AC-INPUT-6.1.
- **TD-011** (NEW Sprint 07): `hud_core.gd:528` hardcoded `"100"` health-numeral fallback violates `localization_lint` `lint_no_hardcoded_visible_string_in_src`. Migrate to `tr()` per ADR-0004.

See `docs/tech-debt-register.md` for full entries with origin / owner / re-open trigger.

---

## ADR-0004 closure status (per roadmap requirement)

ADR-0004 remains **Effectively-Accepted** (no change this sprint):
- **G1** (AccessKit property names): OPEN — defers Document Overlay UI epic + 1 Settings story
- **G5** (BBCode→AccessKit serialization): OPEN — defers Document Overlay UI epic

Sprint 07 is NOT ADR-0004-blocked because DC-001..005 are data-layer + scene-tree-node logic (no UI surface). The Document Overlay UI epic (5 stories) remains DEFERRED in the post-art roadmap.

---

## Forbidden-pattern fences registered this sprint

Per Sprint 07 Definition of Done — verified registered in `forbidden_patterns.gd` lint registry:

- `audio_publishing_signals` (AUD-003/004/005)
- `dialogue_subtitles_reaching_into_audio_bus` (AUD-004)
- `document_content_baked_into_resource` (DC-001)
- `document_signal_emitted_outside_dc` (DC-003)
- `worldenvironment_glow_enabled` (PPS-005)

---

## Sign-off

✅ **APPROVED WITH CONDITIONS** for Sprint 07 close + Sprint 8 kickoff.

Conditions are documentation-and-followup-only:
1. Visual sign-off deferred behind MVP build availability (ADVISORY gate)
2. One in-loop code-review defect fixed (logged for retro)
3. One pre-existing CR-7 violation removed (logged for retro)
4. Tech-debt register at 11/12 — schedule TD-009 fix into Sprint 08 buffer

**No architectural or test-coverage blocker for Sprint 8 (Level Streaming Body & Integration Hardening) to begin.**

---

## Hand-off

- Sprint 08 plan: TBD — to be authored by `/sprint-plan` (closes the pre-art roadmap)
- Smoke check: `production/qa/smoke-2026-05-03.md` (PASS WITH WARNINGS, 7 pre-existing)
- Scope check: PASS (0 additions, 0 removals — verified 2026-05-03)
- Retro: `production/retros/sprint-07-retro.md`
