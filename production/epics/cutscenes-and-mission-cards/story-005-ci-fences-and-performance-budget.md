# Story 005: CI fences + performance budget compliance

> **Epic**: Cutscenes & Mission Cards
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Config/Data + Integration
> **Estimate**: 3-4 hours (M — two shell scripts + one GUT test file + EC-CMC-B.4 CI integration test + localization smoke check)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/cutscenes-and-mission-cards.md`
**Requirements**: TR-CMC-011, TR-CMC-012
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-CMC-011**: Cutscenes claims the Slot 7 sub-slot of ADR-0008 (UI 0.3 ms shared): peak CPU-side Control processing ≤ 0.20 ms when a card or letterbox is rendering; **zero per-frame cost** (no `_process`, no `_physics_process`) when the surface is dismissed and the CanvasLayer is not in tree.
- **TR-CMC-012**: Cutscenes claims no named Slot 8 pool entry; trigger-evaluation path (`dict.has()` + `InputContext.push()` + `create_timer()` + `create_tween()`) is absorbed within the existing 0.25 ms Slot 8 residual margin at ≤ 0.011 ms peak event-frame. Zero steady-state Slot 8 cost.

**Indirect GDD coverage this story closes** (previously deferred to Story 005 in the Out-of-Scope sections of Stories 001-004):

| GDD Section | ACs addressed |
|-------------|---------------|
| H.9 — Forbidden Pattern Enforcement | AC-CMC-9.1 through AC-CMC-9.5 |
| H.10 — Performance Budget | AC-CMC-10.1, AC-CMC-10.2 (BLOCKING), AC-CMC-10.4 |
| H.8 — Localization smoke check | AC-CMC-8.4 (ADVISORY) |
| H.2 / Save-Load CR-6 | AC-CMC-2.4 (F5 gate-location invariant) |
| EC-CMC-B.4 — slot contamination CI | Final CI-verifiable proxy for EC-CMC-B.4 |

**ADR Governing Implementation**: ADR-0008 (Performance Budget Distribution) + ADR-0002 (Signal Bus — forbidden-emit fences) + ADR-0004 (UI Framework — forbidden `ui_cancel`, `AUTO_TRANSLATE_MODE_ALWAYS` fences)
**ADR Decision Summary**: ADR-0008 §D registers the Cutscenes Slot 7 sub-claim (0.00–0.20 ms peak event-frame, steady-state 0.00 ms) and the Slot 8 trigger-evaluation cost absorbed in the 0.25 ms residual margin. No runtime BudgetRegistry is introduced — enforcement is entirely CI-time via shell script greps and a GUT test that asserts `is_processing() == false` when no card is active. The `check_forbidden_patterns_cutscenes.sh` script is the single CI fence artifact that runs all GDD §H.9 greps plus the `_process` sweep (§H.10 AC-CMC-10.2) in one exit-code-bearing pass. A second script, `check_save_input_gate.sh`, verifies the F5-gate invariant without touching SaveManager implementation (Story 005 verifies the gate exists; Save/Load epic implements it).

**Engine**: Godot 4.6 | **Risk**: LOW (shell scripts + GUT zero-process test; no new scene nodes or GDScript APIs)
**Engine Notes**: `Node.is_processing()` and `Node.is_physics_processing()` are stable Godot 4.0+ API. `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` is used in AC-CMC-10.1 — this constant name is stable Godot 4.0+; no post-cutoff risk. `SceneTree.paused = false` assertion in the no-process test is safe because the test scene tree is unpaused by default in headless GUT runs.

> This story introduces **no new GDScript at runtime**. Every deliverable is either a CI shell script under `tools/ci/` or a GUT test under `tests/unit/presentation/cutscenes_and_mission_cards/`. No `.tscn` files are created or modified.

**Control Manifest Rules enforced by this story (Presentation Layer)**:

- Forbidden: `cmc_publishing_mission_signals` — `Events.mission_started.emit(...)` or any Mission-domain emit from `src/gameplay/cutscenes/` (CR-CMC-1, FP-CMC-10). CI fence enforced by AC-1.
- Forbidden: `cmc_pushing_subtitle_visibility` — any `get_node` call in `src/gameplay/cutscenes/` that targets a path other than `Events`, `MissionLevelScripting.get_mission_state()`, `OutlinePipeline`, or `PostProcessStack` (CR-CMC-13, FP-CMC-11). CI fence enforced by AC-2.
- Forbidden: `ui_cancel` in `_unhandled_input` dismiss handler — sole dismiss action is `cutscene_dismiss` (GDD §C.2.4). CI fence enforced by AC-3.
- Forbidden: `func _process` or `func _physics_process` in any `.gd` or `.tscn` file under `src/gameplay/cutscenes/**` (F.1, F.2). CI fence enforced by AC-7.
- Forbidden: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on any card Label (CR-CMC-15, ADR-0004). CI fence enforced by AC-4.
- Forbidden: `corner_radius_*`, `shadow_*`, `glow_*` non-zero on card StyleBoxFlat resources (FP-V-CMC-5/6/3). CI fence enforced by AC-5.
- Guardrail: Slot 7 CPU peak ≤ 0.20 ms with card active; **zero per-frame cost when dismissed** (zero `_process` / `_physics_process` overrides in any Cutscenes file — this is the GUT-testable proxy per ADR-0008 §D F.1).

---

## Acceptance Criteria

*From GDD `design/gdd/cutscenes-and-mission-cards.md` §H.9, §H.10, §H.8 partial (AC-CMC-8.4), §H.2 (AC-CMC-2.4), EC-CMC-B.4:*

### Forbidden-pattern CI fence (`check_forbidden_patterns_cutscenes.sh`)

- [ ] **AC-1** [BLOCKING]: GIVEN the full `src/gameplay/cutscenes/` tree, WHEN `tools/ci/check_forbidden_patterns_cutscenes.sh` runs, THEN its first check (`grep -rn "Events\.mission_started\.emit\|Events\.mission_completed\.emit\|Events\.objective_started\.emit\|Events\.objective_completed\.emit" src/gameplay/cutscenes/`) exits 1 (no matches found = `grep` returns 1 for no-match, checked via negation in the script). Zero matching lines = PASS. Any match = BLOCKING defect, script exits non-zero. (AC-CMC-9.1 partial + AC-CMC-1.1 — FP-CMC-10, CR-CMC-1)
- [ ] **AC-2** [BLOCKING]: GIVEN `src/gameplay/cutscenes/cutscenes_and_mission_cards.gd`, WHEN the script's second check runs (`grep -n "get_node\|get_parent\|get_node_or_null"` excluding `@onready` self-referential declarations and the four ADR-0004-permitted autoload paths `Events`, `MissionLevelScripting`, `OutlinePipeline`, `PostProcessStack`), THEN zero matches remain outside those permitted sites. (AC-CMC-13.1 — FP-CMC-11, CR-CMC-13)
- [ ] **AC-3** [BLOCKING]: GIVEN `cutscenes_and_mission_cards.gd`, WHEN the script's third check runs (`grep -n "ui_cancel"`), THEN zero matches. Sole dismiss action is `cutscene_dismiss`. (AC-CMC-4.5 — GDD §C.2.4)
- [ ] **AC-4** [BLOCKING]: GIVEN all `.tscn` and `.gd` files under `src/gameplay/cutscenes/`, WHEN the script's fourth check runs (`grep -rnE "auto_translate_mode\s*=\s*(ALWAYS|AUTO_TRANSLATE_MODE_ALWAYS)"`), THEN zero matches. All card Labels must declare `AUTO_TRANSLATE_MODE_DISABLED`. (AC-CMC-8.2 proxy — CR-CMC-15, ADR-0004)
- [ ] **AC-5** [BLOCKING]: GIVEN all `.tres` StyleBoxFlat resources and `.tscn` files under `src/gameplay/cutscenes/`, WHEN the script's fifth check runs (`grep -rn "corner_radius\|shadow\|glow\|drop_shadow\|rounded"`), THEN zero matches. (AC-CMC-9.5 — FP-V-CMC-5/6/3)
- [ ] **AC-6** [BLOCKING]: GIVEN `translations/cutscenes.csv` and all `.tscn`/`.gd` files under `src/gameplay/cutscenes/`, WHEN the script's sixth check runs (`grep -irE "MISSION ACCOMPLISHED|OBJECTIVE COMPLETE|^SUCCESS$|MISSION SUCCESS"` across both paths), THEN zero matches. Terminal closing-card status is `STATUS: CLOSED` only per §C.4.2 + TR-6. (AC-CMC-9.2 — TR-6, FC-1)
- [ ] **AC-7** [BLOCKING]: GIVEN ALL `.gd` and `.tscn` files under `src/gameplay/cutscenes/**`, WHEN the script's seventh check runs (`grep -rnE "func _process|func _physics_process|set_process\(true\)|set_physics_process\(true\)"`), THEN zero matches. This catches child-node `_process` callbacks in any cinematic subscene scripts as well as the root `CutscenesAndMissionCards` script. (AC-CMC-10.2 BLOCKING — F.1, F.2, ADR-0008 Slot 7 + 8)
- [ ] **AC-8** [BLOCKING]: GIVEN DialogueLine `.tres` resources under `assets/dialogue/cutscenes/`, WHEN the script's eighth check runs (`grep -rn "speaker.*=.*\"PROTAGONIST\"\|speaker.*=.*&\"PROTAGONIST\""` on that path), THEN zero matches. (AC-CMC-9.1 full — CR-CMC-20, FP-CMC-1, AFP-CMC-5)
- [ ] **AC-9** [BLOCKING]: GIVEN `tools/ci/check_forbidden_patterns_cutscenes.sh`, WHEN run with exit code 0, THEN all eight checks above passed atomically. WHEN any check finds a violation, script exits non-zero with a human-readable message identifying the failing check number and the matched line(s). CI pipeline treats non-zero exit as a build failure.

### F5 save-gate invariant (`check_save_input_gate.sh`)

- [ ] **AC-10** [BLOCKING]: GIVEN `src/gameplay/save_load/save_manager.gd` (or the canonical Save/Load epic path per that epic's implementation), WHEN `tools/ci/check_save_input_gate.sh` runs (`grep -n "InputContext.is_active.*CUTSCENE\|is_active(InputContext.Context.CUTSCENE)" src/gameplay/save_load/save_manager.gd`), THEN at least one match exists inside `_unhandled_input` body. Script exits non-zero if no match is found. This verifies the gate-location invariant that Story 005 is responsible for fencing: the F5 silent-drop behavior requires `SaveManager._unhandled_input` to check `InputContext.is_active(CUTSCENE)` before calling `quicksave()`. Story 005 registers the CI fence; Save/Load epic implements the gate. (AC-CMC-2.4 — Save/Load CR-6, ADR-0003, ADR-0004)

### Zero per-frame cost when dismissed (GUT test)

- [ ] **AC-11** [BLOCKING]: GIVEN a `CutscenesAndMissionCards` node added to a headless GUT scene tree with no card or cinematic active (default post-`_ready()` state), WHEN `is_processing()` is queried, THEN `false`. WHEN `is_physics_processing()` is queried, THEN `false`. (AC-CMC-10.1 — F.1, F.2, ADR-0008 Slot 7)
- [ ] **AC-12** [BLOCKING]: GIVEN the same node with no card active, WHEN `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` is sampled over 60 frames, THEN delta draw calls vs baseline == 0. Implementation: GUT double-frame advance loop; compare draw-call counter before and after node enters tree. (AC-CMC-10.1 partial — F.1)

### Trigger-evaluation event-frame cost proxy (ADVISORY)

- [ ] **AC-13** [ADVISORY]: GIVEN `_try_fire_card()` hot-path executes in a single GUT test frame (4 operations: `dict.has()` on a 20-entry `triggers_fired` array + `InputContext.push()` mock + `get_tree().create_timer(4.0, true)` + `create_tween()`), WHEN total elapsed frame time is measured via mock clock injected as a dependency, THEN reported cost ≤ 0.011 ms. This is a design-doc honesty check, not a CI gate — test is ADVISORY and should be marked `skip` if the mock clock approach is not available in the headless GUT runner at VS scope. (AC-CMC-10.4 — F.2)

### EC-CMC-B.4 — load-from-slot during cutscene CI integration check

- [ ] **AC-14** [BLOCKING]: GIVEN `CutscenesAndMissionCards` in a headless GUT scene tree with `_context_pushed == true` (CUTSCENE on stack, simulating a card mid-display) and `MissionLevelScripting.get_mission_state()` returning a live stub `MissionState` with `triggers_fired = [&"mc_briefing_paris_affair"]` (slot 5 state), WHEN `Events.game_loaded.emit()` fires, THEN: (a) `_on_game_loaded()` executes without calling `_open_card()` (spy records zero calls); (b) `InputContext.is_active(InputContext.Context.CUTSCENE) == false` after handler returns (`_cleanup()` must have popped context if `_context_pushed` was true); (c) a subsequent `Events.mission_started.emit(...)` is suppressed — `_try_fire_card` reads live slot 5 `triggers_fired` and finds `&"mc_briefing_paris_affair"` present, so `_open_card` is NOT called. This is the EC-CMC-B.4 full CI verification: safe teardown on game_loaded + no slot contamination in subsequent suppression gate. (EC-CMC-B.4 BLOCKING — CR-CMC-21, CR-CMC-2, CR-CMC-6)

  > **Note on EC-CMC-B.4 across stories**: Story 002 (AC-5) and Story 003 (AC-5, AC-10) each contain partial EC-CMC-B.4 coverage scoped to their respective domains (signal domain and replay-suppression logic). Story 005 AC-14 provides the final integrated verification: `game_loaded` + active context + slot swap + subsequent suppression gate — all in one test. This AC must pass before the epic Definition of Done can be signed.

### Localization key roster smoke check (ADVISORY)

- [ ] **AC-15** [ADVISORY] — BLOCKED on OQ-CMC-8: GIVEN `translations/cutscenes.csv` exists and is populated per Localization Scaffold epic (OQ-CMC-8 resolution), WHEN `tools/ci/check_localization_key_roster.sh` runs (count entries matching `cutscenes.<surface>.<scope>.<beat>` naming pattern), THEN the CSV contains a minimum of 16 keys (5 briefing + 5 closing + 4 objective × 2 + 1 ct_04 VO + 1 ct_05 caption per GDD §C.6). Script exits non-zero if count < 16. This AC is ADVISORY at VS DOD and BLOCKING for Polish phase gate. (AC-CMC-8.4 — CR-CMC-15, C.6)

---

## Implementation Notes

*Derived from ADR-0008 §D (F.1, F.2, F.6), GDD §H.9, §H.10, ADR-0002, ADR-0004:*

### `tools/ci/check_forbidden_patterns_cutscenes.sh`

This is a single Bash script that runs eight sequential grep checks against the `src/gameplay/cutscenes/` tree and exits 0 only if all eight return no matches (or, for AC-8, the `assets/dialogue/cutscenes/` path). Each failing check prints a human-readable error to stdout with check number, description, and the offending matched line before setting exit code to 1.

Skeleton structure:

```bash
#!/usr/bin/env bash
# check_forbidden_patterns_cutscenes.sh
# Enforces GDD §H.9 + §H.10 forbidden patterns for cutscenes-and-mission-cards.
# Exit 0 = all checks pass. Exit 1 = one or more violations found.
set -euo pipefail
FAIL=0

check() {
    local id="$1" desc="$2"
    shift 2
    local result
    result=$(eval "$@" 2>/dev/null || true)
    if [ -n "$result" ]; then
        echo "[FAIL] Check $id: $desc"
        echo "$result"
        FAIL=1
    fi
}

# AC-1 — No Mission-domain emits in Cutscenes source (FP-CMC-10, CR-CMC-1)
check "1" "No Mission-domain emit in src/gameplay/cutscenes/" \
    "grep -rn 'Events\\.mission_started\\.emit\\|Events\\.mission_completed\\.emit\\|Events\\.objective_started\\.emit\\|Events\\.objective_completed\\.emit' src/gameplay/cutscenes/"

# AC-2 — No unauthorized get_node calls (FP-CMC-11, CR-CMC-13)
# Exclude @onready self-references; permitted paths: Events, MissionLevelScripting, OutlinePipeline, PostProcessStack
check "2" "No unauthorized get_node in cutscenes_and_mission_cards.gd" \
    "grep -n 'get_node\\|get_parent\\|get_node_or_null' src/gameplay/cutscenes/cutscenes_and_mission_cards.gd \
     | grep -v '@onready' | grep -v 'Events\\|MissionLevelScripting\\|OutlinePipeline\\|PostProcessStack'"

# AC-3 — No ui_cancel in dismiss handler (GDD §C.2.4)
check "3" "No ui_cancel in cutscenes_and_mission_cards.gd" \
    "grep -n 'ui_cancel' src/gameplay/cutscenes/cutscenes_and_mission_cards.gd"

# AC-4 — No AUTO_TRANSLATE_MODE_ALWAYS on card Labels (CR-CMC-15, ADR-0004)
check "4" "No AUTO_TRANSLATE_MODE_ALWAYS in cutscenes src/**" \
    "grep -rnE 'auto_translate_mode\\s*=\\s*(ALWAYS|AUTO_TRANSLATE_MODE_ALWAYS)' src/gameplay/cutscenes/"

# AC-5 — No corner_radius / shadow / glow in card StyleBoxFlat (FP-V-CMC-5/6/3)
check "5" "No corner_radius/shadow/glow in cutscenes src/**" \
    "grep -rn 'corner_radius\\|shadow\\|glow\\|drop_shadow\\|rounded' src/gameplay/cutscenes/"

# AC-6 — No forbidden terminal status strings (TR-6, FC-1)
check "6" "No MISSION ACCOMPLISHED / OBJECTIVE COMPLETE in cutscenes src + CSV" \
    "grep -irE 'MISSION ACCOMPLISHED|OBJECTIVE COMPLETE|^SUCCESS\$|MISSION SUCCESS' \
       src/gameplay/cutscenes/ translations/cutscenes.csv 2>/dev/null"

# AC-7 — No _process / _physics_process anywhere in cutscenes/** (F.1, F.2, ADR-0008 Slot 7+8)
check "7" "No _process/_physics_process in src/gameplay/cutscenes/**" \
    "grep -rnE 'func _process|func _physics_process|set_process\\(true\\)|set_physics_process\\(true\\)' src/gameplay/cutscenes/"

# AC-8 — No PROTAGONIST speaker in Cutscenes-triggered dialogue assets (CR-CMC-20, FP-CMC-1)
check "8" "No PROTAGONIST speaker in assets/dialogue/cutscenes/" \
    "grep -rn 'speaker.*=.*\"PROTAGONIST\"\\|speaker.*=.*&\"PROTAGONIST\"' assets/dialogue/cutscenes/ 2>/dev/null"

exit \$FAIL
```

**CI wiring**: the script must be registered in the GitHub Actions workflow (or equivalent) as a blocking step on every push to `main` and every PR touching any file under `src/gameplay/cutscenes/`, `assets/dialogue/cutscenes/`, or `translations/cutscenes.csv`. It runs headlessly — no Godot engine invocation needed.

**Check 2 pipe-filter note**: The `grep -v` pipe approach for the `get_node` check is intentionally coarse. A false-positive can occur if a comment in the file mentions a permitted autoload path alongside a forbidden one. Code review must verify the grep logic matches the actual file contents after Stories 001-004 are implemented.

### `tools/ci/check_save_input_gate.sh`

A minimal single-grep script verifying the F5 gate location invariant:

```bash
#!/usr/bin/env bash
# check_save_input_gate.sh
# Verifies SaveManager._unhandled_input contains InputContext.is_active(CUTSCENE) guard.
# Exit 0 = gate present. Exit 1 = gate missing.
SAVE_MANAGER="src/gameplay/save_load/save_manager.gd"
if ! grep -qn "is_active.*CUTSCENE\|is_active(InputContext\.Context\.CUTSCENE)" "$SAVE_MANAGER" 2>/dev/null; then
    echo "[FAIL] check_save_input_gate: InputContext.is_active(CUTSCENE) gate NOT found in $SAVE_MANAGER"
    echo "  Save/Load CR-6 requires SaveManager._unhandled_input to check CUTSCENE context before quicksave()."
    exit 1
fi
echo "[PASS] check_save_input_gate: CUTSCENE gate found in $SAVE_MANAGER"
```

This script does NOT implement the gate — it only verifies its presence. The Save/Load epic owns the implementation. Story 005 registers the CI fence.

### GUT performance test (`performance_test.gd`)

Two test functions in `tests/unit/presentation/cutscenes_and_mission_cards/performance_test.gd`:

**`test_zero_steady_state_cost_no_card_active`** (AC-11, AC-12):
- Instantiates `CutscenesAndMissionCards` via `PackedScene.instantiate()` (never `.new()` per FP-CMC-13)
- Adds to test scene tree, calls `_ready()`; no card opened
- Asserts `subject.is_processing() == false`
- Asserts `subject.is_physics_processing() == false`
- Records `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` baseline, advances 60 frames, records delta; asserts delta == 0

**`test_trigger_evaluation_event_frame_cost`** (AC-13, ADVISORY):
- Dependency-injected mock for `MissionLevelScripting.get_mission_state()` returning a stub `MissionState` with `triggers_fired = []` and an empty `InputContext` mock
- Calls `_try_fire_card(&"smoke_test_scene", CardType.MISSION_BRIEFING, LevelStreamingService.TransitionReason.FORWARD)` once, records elapsed time via `Time.get_ticks_usec()`
- Asserts result ≤ 11 µs (0.011 ms per GDD §D F.2 formula)
- Test is marked `@warning_ignore("skip_advisory")` if mock injection is not available in the headless GUT runner at VS scope — the AC itself is ADVISORY

### EC-CMC-B.4 integration test (`slot_contamination_final_test.gd`)

New test function in `tests/integration/presentation/cutscenes_and_mission_cards/slot_contamination_final_test.gd` (separate from the partial EC-CMC-B.4 tests in Stories 002 and 003):

```gdscript
func test_ec_cmc_b4_game_loaded_teardown_then_subsequent_suppression() -> void:
    # Setup: card mid-display (context pushed)
    var subject := _instantiate_cmc()
    var mock_state_slot5 := _make_mission_state([&"mc_briefing_paris_affair"])
    _mock_mls_get_mission_state(mock_state_slot5)
    subject._context_pushed = true
    InputContextMock.push(InputContext.Context.CUTSCENE)

    # Trigger: load from slot 5
    Events.game_loaded.emit()
    await get_tree().process_frame  # let deferred handlers settle if any

    # Assert teardown
    assert_false(InputContext.is_active(InputContext.Context.CUTSCENE),
        "CUTSCENE must be off stack after game_loaded — EC-CMC-B.4")
    assert_eq(_open_card_spy_count, 0,
        "game_loaded must not trigger _open_card — EC-CMC-B.4")

    # Assert subsequent suppression reads slot 5 state (not slot 1 contamination)
    Events.mission_started.emit(&"plaza_section", &"mc_briefing_paris_affair")
    await get_tree().process_frame

    assert_eq(_open_card_spy_count, 0,
        "Subsequent mission_started must be suppressed by slot 5 triggers_fired — EC-CMC-B.4")
```

**Why this is separate from Story 002 AC-5 and Story 003 AC-10**: those tests isolate specific subsystems (signal domain handler isolation in Story 002; `_try_fire_card` replay-suppression logic in Story 003). Story 005 AC-14 is the end-to-end integration: game_loaded fires, context is popped, `_on_mission_started` subsequently arrives, and the suppression gate reads the newly-active slot's `triggers_fired`. It requires both signal domain and replay suppression to be in place, which is why it belongs to this final story.

**Live-reference dependency**: this test requires `MissionLevelScripting.get_mission_state()` to return the live stub instance injected in setup — not a `duplicate()`. If the mock returns a duplicate, the subsequent suppression check would incorrectly fire the card (slot 1's empty `triggers_fired` persisting). The test is therefore also a passive regression guard for OQ-CMC-6 (live-reference contract).

### What `check_forbidden_patterns_cutscenes.sh` does NOT check (Out of scope for this story)

- AFP-CMC-7 (stereo-pan automation) — no programmatic grep equivalent; verified by audio-director review
- EC-CMC-H.3 (letterbox on CT-03/CT-04) — deferred to when cinematic scene files exist (post-VS)
- `force_alert_state` cause argument — deferred to when StealthAI integration is implemented (post-VS)
- Localization key roster (AC-CMC-8.4 / AC-15) — deferred pending OQ-CMC-8 Localization Scaffold resolution; covered by separate `check_localization_key_roster.sh` when `translations/cutscenes.csv` exists

---

## Out of Scope

*Handled by other epics or deferred post-VS — do not implement here:*

- Stories 001-004: all GDScript implementation, scene authoring, localization key registration, visual spec — this story only fences what those stories produced
- Save/Load epic: `SaveManager._unhandled_input` CUTSCENE gate implementation (AC-10 only verifies the gate exists, not its correctness)
- Audio epic: AudioManager subscription to `cutscene_started`/`cutscene_ended` (TR-CMC-007 — verified in Story 002 via signal contract; AC-3 of this story greps for `ui_cancel` only, not audio patterns)
- MLS epic: `triggers_fired` write path on `cutscene_ended` (TR-CMC-008 — MLS owns; only indirectly tested in EC-CMC-B.4 via live-reference contract)
- AC-CMC-10.3 (CT-05 profiler screenshot at Polish — `production/qa/evidence/ac-cmc-10-3-ct05-slot7-profile.png`) — ADVISORY, Polish milestone, requires CT-05 cinematic implementation
- AC-CMC-9.4 (letterbox grep on CT-03/CT-04 scenes) — deferred until cinematic scene files exist post-VS
- StealthAI `force_alert_state` pattern grep — deferred to StealthAI epic integration
- Objective opt-in card visual forbidden patterns — deferred post-VS per epic VS-narrowing
- `check_localization_key_roster.sh` implementation and AC-CMC-8.4 closure — BLOCKED on OQ-CMC-8 (Localization Scaffold); ADVISORY at VS DOD

---

## QA Test Cases

*Solo mode — Config/Data + Integration story. Test cases derived from GDD ACs.*

**AC-9 (Integration): Shell script exits 0 on clean VS tree**
- Setup: Stories 001-004 implemented; `src/gameplay/cutscenes/` contains only permitted patterns; no `assets/dialogue/cutscenes/` yet (directory may not exist — script must handle gracefully with `2>/dev/null`)
- When: `bash tools/ci/check_forbidden_patterns_cutscenes.sh` run from project root
- Then: exit code 0; all eight check lines print `[PASS]` or (for checks 1/6/8 on absent directories) produce no output
- Edge cases: check 8 (`assets/dialogue/cutscenes/`) does not exist at VS — `grep` on a nonexistent path must not cause script to exit non-zero (guarded by `2>/dev/null || true`)

**AC-9 (negative path): Script catches a planted defect**
- Setup: temporarily add `Events.mission_started.emit(&"injected")` to a Cutscenes source file
- When: script runs
- Then: exit code 1; output includes `[FAIL] Check 1` and the offending line
- Teardown: remove planted defect

**AC-11: GUT `test_zero_steady_state_cost_no_card_active`**
- Given: `CutscenesAndMissionCards` instantiated in headless GUT scene tree; no card opened
- When: `is_processing()` queried
- Then: `false`
- When: `is_physics_processing()` queried
- Then: `false`

**AC-14 (Integration): EC-CMC-B.4 full teardown + suppression**
- Given: `CutscenesAndMissionCards` with `_context_pushed = true`; mock `MissionState` for slot 5 with `triggers_fired = [&"mc_briefing_paris_affair"]`; `InputContext.CUTSCENE` on stack
- When: `Events.game_loaded.emit()` fires
- Then: `InputContext.is_active(CUTSCENE) == false`; `_open_card` spy == 0 calls
- When: `Events.mission_started.emit(...)` fires subsequently
- Then: `_open_card` spy still == 0 (suppressed by slot 5's `triggers_fired`)
- Edge case: if mock returns a `duplicate()` instead of the live reference, subsequent `mission_started` incorrectly fires the card — test catches this as a false-positive spy call, surfacing the OQ-CMC-6 violation

**AC-10 (Code-review): Save gate invariant**
- Setup: Save/Load epic has implemented `SaveManager._unhandled_input` with CUTSCENE guard (Story 005 registers the CI fence; implementation is Save/Load epic scope)
- When: `bash tools/ci/check_save_input_gate.sh` run
- Then: exit code 0; `[PASS]` message printed

---

## Test Evidence

**Story Type**: Config/Data + Integration
**Required evidence**:
- `tools/ci/check_forbidden_patterns_cutscenes.sh` — must exist and exit 0 on VS clean tree (AC-1 through AC-9, AC-7)
- `tools/ci/check_save_input_gate.sh` — must exist and exit 0 once Save/Load epic implements the CUTSCENE gate (AC-10)
- `tests/unit/presentation/cutscenes_and_mission_cards/performance_test.gd` — must exist and pass `test_zero_steady_state_cost_no_card_active` (AC-11, AC-12) and contain `test_trigger_evaluation_event_frame_cost` (AC-13 ADVISORY)
- `tests/integration/presentation/cutscenes_and_mission_cards/slot_contamination_final_test.gd` — must exist and pass `test_ec_cmc_b4_game_loaded_teardown_then_subsequent_suppression` (AC-14 BLOCKING)
- `production/qa/evidence/story-005-ci-fences-evidence.md` — manual walkthrough confirming: script runs headlessly from CI, script exits non-zero when a planted defect is introduced and removed, GUT performance test passes in headless Godot run, EC-CMC-B.4 integration test passes

**Status**: [ ] Not yet created

---

## Definition of Done

This story is Done when:

- [ ] `tools/ci/check_forbidden_patterns_cutscenes.sh` exists, is executable, and exits 0 on the VS tree (after Stories 001-004 are implemented)
- [ ] `tools/ci/check_save_input_gate.sh` exists and its gate-location assertion is correct (may show exit 1 until Save/Load epic implements the guard — documented expectation, not a blocker for Story 005 DOD if the script itself is authored correctly)
- [ ] `tests/unit/presentation/cutscenes_and_mission_cards/performance_test.gd` exists; `test_zero_steady_state_cost_no_card_active` passes in headless GUT run
- [ ] `tests/integration/presentation/cutscenes_and_mission_cards/slot_contamination_final_test.gd` exists; `test_ec_cmc_b4_game_loaded_teardown_then_subsequent_suppression` passes — EC-CMC-B.4 BLOCKING
- [ ] `production/qa/evidence/story-005-ci-fences-evidence.md` written confirming scripts run, negative-path test (planted defect) returns exit 1, GUT test passes
- [ ] TR-CMC-011 and TR-CMC-012 are satisfied: TR-CMC-011 by AC-7 (no `_process`) + AC-11/AC-12 (GUT zero-cost proof); TR-CMC-012 by AC-7 (no steady-state Slot 8 ticking) + AC-13 (event-frame cost proxy)
- [ ] EC-CMC-B.4 BLOCKING: AC-14 passes; epic Definition of Done condition "EC-CMC-B.4 verified: load-from-slot during cutscene safely tears down (no slot contamination)" is satisfied

---

## Dependencies

- **Depends on**: Story 001 (scene scaffold DONE — `check_forbidden_patterns_cutscenes.sh` greps files that must exist); Story 002 (cutscene signal domain DONE — AC-1 greps `Events.mission_started.emit` absence); Story 003 (replay suppression DONE — EC-CMC-B.4 AC-14 requires `_try_fire_card` and `_on_game_loaded` to be implemented); Story 004 (card visuals DONE — AC-4 greps `auto_translate_mode`, AC-5 greps StyleBoxFlat, AC-3 greps `ui_cancel`)
- **BLOCKED on**: Save/Load epic (for AC-10 to exit 0 — `check_save_input_gate.sh` is authored here but its pass depends on SaveManager implementation); OQ-CMC-8 (Localization Scaffold, for AC-15 / AC-CMC-8.4 ADVISORY)
- **Unlocks**: Epic Definition of Done — this is the final story; after AC-14 passes and all AC-1 through AC-9 pass on the VS tree, the cutscenes-and-mission-cards epic can be closed via `/story-done`

---

## Open Questions

- **OQ-Story005-1**: Check 2 of `check_forbidden_patterns_cutscenes.sh` (unauthorized `get_node` calls) uses a pipe-filter approach to exclude permitted autoload paths. If `cutscenes_and_mission_cards.gd` uses a self-referential `@onready` variable that happens to reference a sibling node not matching the four permitted paths, the check will produce a false positive. Clarification needed at Story 001 implementation review: are there any `@onready get_node(...)` calls for internal sub-nodes (e.g., `$BriefingCard`, `$ClosingCard`) that would be caught by the grep? If so, the grep pattern should be narrowed to `get_node("/root/` paths only (absolute paths = the anti-pattern).

- **OQ-Story005-2**: AC-12 uses `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` in a headless GUT run. The rendering subsystem may not be active in headless mode, causing this monitor to return 0 unconditionally — making the test vacuously pass. If the GUT headless runner cannot exercise this monitor, AC-12 should be marked ADVISORY and deferred to a manual editor-mode smoke check in `production/qa/evidence/`. Clarify with tools-programmer before implementing.

- **OQ-Story005-3**: `check_save_input_gate.sh` targets `src/gameplay/save_load/save_manager.gd` by convention. If the Save/Load epic uses a different file path or class name for the SaveManager, the script path must be updated. Coordination point with Save/Load epic lead at implementation time.
