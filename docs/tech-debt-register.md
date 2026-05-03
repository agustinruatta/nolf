# Tech Debt Register

Active tech-debt items logged from completed stories. Each entry lists the
debt, why it's deferred, who owns it, and the trigger that re-opens it.

Format: `- [TD-NNN]` (sequential) — debt — origin — owner — trigger.

---

## Active

### TD-001 — `query.exclude` mid-loop append unreliable on Godot 4.6.2

- **Origin**: PC-005 (Interact raycast). Production bug discovered 2026-05-01: `PhysicsRayQueryParameters3D.exclude.append()` between `intersect_ray()` calls does NOT propagate to the next query call on Godot 4.6.2 Linux Vulkan, despite the project's verified-engine-reference doc claiming it does.
- **Workaround in production code**: Re-assign the entire `excludes` array each iteration (`var excludes: Array[RID] = []` + `excludes.append(rid)` + `query.exclude = excludes`). Implemented in `src/gameplay/player/player_character.gd::_resolve_interact_target()`.
- **Documentation gap**:
  - `docs/engine-reference/godot/modules/physics.md` Raycasting section claims `query.exclude` backing array is exposed by reference in 4.6 — this is INCORRECT for 4.6.2 Linux Vulkan. Update the section with a 4.6.2 caveat.
  - `production/epics/player-character/story-005-interact-raycast.md` Engine Notes also asserts the in-place pattern — update or annotate with the production-code finding.
- **Owner**: technical-director / godot-specialist
- **Re-open trigger**: Engine upgrade (4.7+) — re-test mid-loop append; if fixed in upstream Godot, update the engine-reference and consider simplifying production code.

### TD-002 — ADR-0008 Iris Xe numerical verification deferred

- **Origin**: ADR-0008 promotion 2026-05-01. Architectural-Framework Verification (Gate 5) PASSED on dev hardware; Iris Xe Gen 12 numerical Gates 1, 2, 4 remain DEFERRED.
- **What's deferred**:
  - Gate 1: Iris Xe + Restaurant scene + 12 SAI guards + Combat + outline + sepia at 60 fps p99
  - Gate 2: RTX 2060 informative measurement
  - Gate 4: Per-autoload `_ready()` instrumentation; current dev-hw aggregate 110 ms exceeds the 50 ms target
- **Re-open trigger**: Restaurant scene authored AND Stealth AI implemented AND Combat implemented AND Iris Xe Gen 12 hardware available. Re-run all 3 deferred gates; failure returns ADR-0008 to Proposed.
- **Owner**: producer / technical-director (gate scheduling)

### TD-003 — Per-autoload boot instrumentation missing

- **Origin**: ADR-0008 Gate 4 verification spike 2026-05-01. Total cold-boot time aggregated to 110 ms on dev hw; per-autoload breakdown not measured.
- **Action needed**: Add `Time.get_ticks_msec()` start/end markers to each autoload's `_ready()` and log the deltas to identify the dominant contributor (PostProcessStack suspected per ADR-0008 §Risks).
- **Re-open trigger**: Sprint 03+ when an autoload-perf story is queued; or when Iris Xe verification work begins.
- **Owner**: engine-programmer

### TD-004 — Pseudolocalization export-preset filter (LOC-002 AC-5)

- **Origin**: LOC-002 (Pseudolocalization) 2026-05-01. AC-5 requires the `export_presets.cfg` `exclude_filter` to drop `_dev_pseudo.*` from shipped builds. Presets don't exist yet (no export-pipeline story has run).
- **Required filter** (per evidence doc):
  ```ini
  exclude_filter="*/_dev_pseudo.csv,*/_dev_pseudo.*.translation,*/_dev_pseudo.# context.translation,*/_dev_pseudo.csv.import"
  ```
- **Re-open trigger**: First export-pipeline story / first `gh release` build attempt.
- **Owner**: release-manager / devops-engineer
- **Reference**: `production/qa/evidence/localization_export_filter_evidence.md`

### TD-005 — `_latch_noise_spike()` zero/negative radius unguarded (PC-005)

- **Origin**: PC-005 (Interact raycast). The `_latch_noise_spike(type, radius, origin)` method does not validate radius; current call sites all pass positive `@export_range` knobs, but a future AI-side call site could pass a 0.0 or negative value with no early-return.
- **Risk level**: LOW — current call sites are safe; risk emerges if Stealth AI calls the latch directly (unlikely; SAI reads via `get_noise_event` accessor).
- **Re-open trigger**: When AI integration introduces new `_latch_noise_spike` callers, add a radius validity guard.
- **Owner**: gameplay-programmer

### TD-006 — AC-3.1 multiplier coverage testability ceiling (PC-004)

- **Origin**: PC-004 (Noise perception surface). AC-3.1 requires testing `noise_global_multiplier` at values `{0.7, 1.0, 1.3}`; the multiplier is a ship-locked `const` per game-designer B-2 closure. Tests proxy the formula by scaling `noise_walk` instead, which proves `knob × const` reaches output but doesn't directly verify the const is read (vs hardcoded `1.0`).
- **Acknowledgement**: Inherent testability ceiling per the const design decision; not a defect.
- **Re-open trigger**: If `noise_global_multiplier` ever becomes runtime-tunable (would require new ADR), update tests to exercise it directly.
- **Owner**: qa-lead / game-designer

### TD-007 — `_resolve_surface_tag()` uses `_warned_bodies` cache that survives mission-load (FS-003)

- **Origin**: FS-003 (Surface detection raycast). Story spec calls for `_warned_bodies` to clear on mission-load. Current implementation only clears on `_ready()` — sufficient for FootstepComponent's lifetime, but the same FC instance won't see a clear when LSS swaps sections (FC is parented to PlayerCharacter which persists across sections per Story PC-007).
- **Risk level**: LOW — only affects untagged-body warning suppression. Worst case: a tagged body across section boundaries is never re-warned (which is the desired behavior anyway).
- **Re-open trigger**: PC-007 (`reset_for_respawn`) integration — consider clearing `_warned_bodies` on respawn.
- **Owner**: gameplay-programmer

### TD-008 — GDD + ADR-0004 plural CSV format amendment

- **Origin**: LOC-003 (Plural Forms CSV) Sprint 06 close. Godot 4.6's actual plural CSV format is `?plural` marker + `?pluralrule` directive + row-repetition — NOT the `en_0` / `en_1` / `en_other` column scheme assumed by the GDD §Detailed Design Rule 5 and ADR-0004 §Engine Compatibility verification gate. Production code corrected during LOC-003 implementation; the docs still describe the old scheme.
- **Documentation gap**:
  - `design/gdd/localization.md` §Detailed Design Rule 5 — describe the actual `?plural` / `?pluralrule` CSV format
  - `docs/architecture/adr-0004-*.md` §Engine Compatibility — bump verification gate to reflect Godot 4.6 reality
- **Risk level**: LOW — production code is correct; this is doc/contract drift.
- **Re-open trigger**: Next `/architecture-review` pass; or any new LOC story that references the docs.
- **Owner**: localization-lead / technical-director

### TD-009 — `player_interact_cap_warning.gd` resolution logic bug (5 failing tests; cross-suite flake)

- **Status**: **ACTIVE** (downgraded MEDIUM → LOW after Sprint 08 PIC-FIX verification).
- **Origin**: Pre-Sprint-06 (logic predates HC-006). Sprint 06 close-out smoke flagged 3 failing tests in `player_interact_cap_warning_test.gd`; Sprint 07 close-out smoke confirmed 5 failing assertions across the same file.
- **Sprint 08 PIC-FIX verification (2026-05-03)**: confirmed Sprint 06's hypothesis — bug is test isolation, NOT resolver logic.
  - `tests/unit/core/player_character` run **alone**: 141/141 PASS (no resolver bug)
  - `tests/unit/level_streaming + tests/unit/core/player_character` run together: 5 player_interact_cap_warning failures + 9 player_noise_by_state failures + 4 player_noise_latch_expiry failures appear (cross-suite physics-space pollution from level_streaming tests that leave auto_free'd ShapeCast3D/StaticBody3D bodies queued)
  - Production resolver code in `src/gameplay/player/player_character.gd::_resolve_interact_target()` is correct — verified by inspection + isolated test pass
- **Failing tests (cross-suite only)**:
  - `test_resolve_cap_exceeded_returns_within_cap` (2 assertion failures)
  - `test_resolve_cap_one_returns_a_stub` (2 assertion failures)
  - `test_resolve_within_cap_returns_priority_winner`
- **Risk level**: LOW — production resolver is correct; failures are test-runner-environment pollution. No player-facing behavior bug.
- **Re-open trigger**: when isolated-suite test runner is feasible (per-suite sandbox or Godot --headless --restart between suites). Most pragmatic fix: split level_streaming integration tests into a separate gdunit4 session (CI matrix job) so they don't share a PhysicsServer3D space with player_character tests.
- **Owner**: qa-lead (test infrastructure scope); gameplay-programmer (verification consult)

### TD-010 — HC-006 debug F-keys use raw `KEY_*` input constants in `main.gd`

- **Origin**: HC-006 visual sign-off prep (Sprint 06). `src/core/main.gd:240..290` houses 8 debug hotkeys (KEY_F1, F2, F3, F4, F6, F7, F8, F10) using raw input constants. Sprint 07's DC-003 implementation removed the KEY_F4 hotkey (CR-7 sole-publisher violation on DocumentCollection), but the remaining 7 keys still violate `input_ci_lints::check_raw_input_constants_passes`.
- **Required fix**: Migrate each hotkey to a registered InputMap action per AC-INPUT-6.1; debug-build-gate via `OS.is_debug_build()`.
- **Risk level**: LOW — debug hotkeys only fire in dev builds; lint failure does not block runtime.
- **Re-open trigger**: Bundle with a focused cleanup story OR opportunistically fold into Sprint 08 if buffer permits.
- **Owner**: gameplay-programmer

### TD-011 — `hud_core.gd:528` hardcoded `"100"` health-numeral fallback

- **Origin**: HC-006 health widget visual fallback (Sprint 06). `src/ui/hud_core/hud_core.gd:528` sets `_health_label_numeral.text = "100"` as a static fallback before the first `health_changed` signal fires. Violates `localization_lint::lint_no_hardcoded_visible_string_in_src` and ADR-0004 (no hardcoded user-visible strings).
- **Required fix**: Replace with `tr("hud.health.default")` (key TBD) or use a non-text initial state (e.g. blank label until first signal).
- **Risk level**: LOW — string is a transient pre-signal placeholder; only visible for one frame on boot.
- **Re-open trigger**: Bundle with TD-010 cleanup OR pick up during Sprint 08 buffer.
- **Owner**: ui-programmer / localization-lead

---

## Closed / Promoted

(none yet)

---

**Last updated**: 2026-05-03 — Sprint 07 close. 11 active items / 12 hard-stop threshold. TD-008..TD-011 added: TD-008 + TD-009 carried forward from Sprint 06 sign-off (formal register entry; previously tracked only in sign-off prose); TD-010 + TD-011 surfaced from Sprint 07 smoke (Sprint 06 anti-pattern violations re-detected). Producer note: schedule TD-009 fix into Sprint 08 buffer to keep register below the 12-item hard stop.
