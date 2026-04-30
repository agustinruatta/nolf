# Story 002: CI forbidden-patterns script + call-order test helper

> **Epic**: Document Overlay UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-overlay-ui.md`
**Requirement**: TR-DOU-005, TR-DOU-018, TR-DOU-019
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: ADR-0002 §Accepted enforces sole-publisher discipline — `Events.document_opened/closed/collected` may only be emitted by Document Collection. Document Overlay UI is subscriber-only. CI grep enforcement of this rule, plus all 16 FP-OV-* forbidden patterns, is required before any implementation story ships (GDD OQ-DOV-COORD-11, sprint-day-1 task).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: This story authors shell scripts and a GDScript test helper — no engine API usage. `grep`, `bash`, and GUT `GutTest` APIs are all stable. The call-order recorder helper uses a plain `Array[StringName]` — no post-cutoff Godot API.

**Control Manifest Rules (Presentation + Foundation)**:
- Required: sole-publisher discipline — `Events.document_opened/closed/collected.emit()` must NEVER appear in `src/ui/document_overlay/` (ADR-0002 IG 1 + DC CR-7)
- Required: CI must block merge if any FP-OV-* violation is detected (coding-standards.md CI/CD rules)
- Required: test files named `[system]_[feature]_test.gd` (coding-standards.md test naming)
- Forbidden: `Events.document_opened.emit()` / `Events.document_closed.emit()` / `Events.document_collected.emit()` from any file under `src/ui/document_overlay/` — FP-OV-1

---

## Acceptance Criteria

*From GDD `design/gdd/document-overlay-ui.md` §H.10 + §H.NEW (OQ-DOV-COORD-11 + OQ-DOV-COORD-13):*

- [ ] **AC-1** (TR-DOU-005, TR-DOU-018): `tools/ci/check_forbidden_patterns_overlay.sh` exists and is executable. When run against a clean `src/ui/document_overlay/` implementation, exits with code 0. When run against synthetic fixtures in `tests/fixtures/overlay_violations/` (one file per pattern), exits with code 1 and reports each violation with file path and line number. Patterns covered: FP-OV-1 (document signal emit), FP-OV-2 (auto-dismiss timer), FP-OV-4 (cached translation value), FP-OV-5 (HUD visibility manipulation), FP-OV-7 (AudioServer call), FP-OV-9 (dismiss via focused button), FP-OV-11 (secondary action nodes in TSCN), FP-OV-12 (smooth_scroll_enabled=true), FP-OV-13 (inline glossary BBCode in CSV), FP-OV-14 (typewriter entry animation), FP-OV-15 (gameplay event subscription), FP-OV-16 (RichTextLabel.append_text on re-render).
- [ ] **AC-2** (OQ-DOV-COORD-11 meta-test): `tools/ci/check_forbidden_patterns_overlay_meta_test.sh` exists and passes CI. It: (a) invokes the main script against a clean directory → asserts exit 0; (b) invokes against each synthetic violation fixture → asserts exit 1 and that the fixture file path appears in stdout.
- [ ] **AC-3** (OQ-DOV-COORD-13): `tests/unit/helpers/call_order_recorder.gd` exists. It exports a `record(call_name: StringName) -> void` method that appends `call_name` to an internal `Array[StringName]`. It exports `assert_order(expected: Array[StringName], gut_test: GutTest) -> void` that asserts the recorded calls match `expected` in sequence, calling `gut_test.fail_test(...)` with a descriptive message on mismatch. It exports `reset() -> void` to clear the record.
- [ ] **AC-4** (OQ-DOV-COORD-13 — viewport mock seam): `tests/unit/helpers/viewport_mock.gd` exists. It provides a `set_input_as_handled_calls: int` counter that increments each time `set_input_as_handled()` is called on the mock. The Overlay's `_close()` method must accept an optional injected `viewport` parameter (or use a `_get_viewport()` virtual hook) so tests can substitute the mock. This seam is required for AC-DOV-2.1 (Story 005) and AC-DOV-4.1 (Story 005).
- [ ] **AC-5** (TR-DOU-019 + FP-OV-12): The CI script catches `smooth_scroll_enabled = true` in `.tscn` or `.gd` files under `src/ui/document_overlay/`. A synthetic fixture demonstrating this violation produces exit 1.
- [ ] **AC-6**: A unit test `tests/unit/presentation/document_overlay_ui/ci_script_self_test.gd` verifies that all synthetic violation fixtures in `tests/fixtures/overlay_violations/` are non-empty files (i.e., the CI script has real inputs to test against, not empty placeholder files). This prevents the meta-test from falsely passing against empty fixture files.

---

## Implementation Notes

*Derived from GDD §C.9 (16 forbidden patterns) + GDD §H.10 + GDD OQ-DOV-COORD-11 + OQ-DOV-COORD-13:*

**`tools/ci/check_forbidden_patterns_overlay.sh`** structure:

```bash
#!/usr/bin/env bash
# Forbidden-pattern CI enforcement for Document Overlay UI
# Exit 0 = clean. Exit 1 = one or more violations found.

set -euo pipefail

OVERLAY_SRC="${1:-src/ui/document_overlay}"
VIOLATIONS=0

check() {
    local id="$1"; local pattern="$2"; local target="$3"
    if grep -rn "$pattern" "$target" 2>/dev/null; then
        echo "VIOLATION $id: pattern '$pattern' found in $target"
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
}

# FP-OV-1: overlay emits document signals (sole-publisher ADR-0002 IG1)
check "FP-OV-1" "Events\.\(document_opened\|document_closed\|document_collected\)\.emit" "$OVERLAY_SRC"

# FP-OV-2: auto-dismiss timer/tween
check "FP-OV-2" "\(Timer\|Tween\).*_close\|auto_dismiss\|dismiss_timer" "$OVERLAY_SRC"

# FP-OV-4: cached translation value (both typed and inferred String locals)
check "FP-OV-4" 'var\s\+\w\+\(\s*:\s*String\)\?\s*:*=\s*tr(' "$OVERLAY_SRC"

# FP-OV-5: HUD visibility manipulation
check "FP-OV-5" "HUDCore\.visible\|hud_core.*visible\|set_hud_visible" "$OVERLAY_SRC"

# FP-OV-6 (FP-OV-6 = overlay manages subtitles — also enforce here)
check "FP-OV-6" "Subtitle.*visible\|subtitle.*suppress\|set_subtitle_visible" "$OVERLAY_SRC"

# FP-OV-7: audio API calls
check "FP-OV-7" "AudioServer\|AudioStreamPlayer\|set_bus_volume_db\|audio_bus" "$OVERLAY_SRC"

# FP-OV-9: dismiss via focused button
check "FP-OV-9" "Button\|ui_accept" "$OVERLAY_SRC/DocumentOverlayUI.tscn"

# FP-OV-11: interactive node types in scene
check "FP-OV-11" "LinkButton\|MenuButton\|OptionButton\|CheckBox\|CheckButton\|LineEdit\|TextEdit\|TabContainer\|Tree\|ItemList" "$OVERLAY_SRC/DocumentOverlayUI.tscn"

# FP-OV-12: smooth scroll
check "FP-OV-12" "smooth_scroll_enabled\s*=\s*true" "$OVERLAY_SRC"

# FP-OV-13: inline glossary BBCode in CSV body content
if [ -f "translations/doc.csv" ] || [ -f "translations/overlay.csv" ]; then
    check "FP-OV-13" '\[url=\|\[hint=' "translations/doc.csv translations/overlay.csv"
fi

# FP-OV-14: typewriter entry animation
check "FP-OV-14" "Tween.*text\|text.*Tween\|typewriter\|append_text.*await\|call_deferred.*append_text" "$OVERLAY_SRC"

# FP-OV-15: gameplay event subscription
check "FP-OV-15" "player_damaged\|alert_state_changed\|enemy_killed\|player_interacted\|document_collected" "$OVERLAY_SRC/document_overlay_ui.gd"

# FP-OV-16: append_text on re-render
check "FP-OV-16" "BodyText\.append_text\|append_text(tr(" "$OVERLAY_SRC"

[ $VIOLATIONS -eq 0 ] && exit 0 || exit 1
```

**`tests/unit/helpers/call_order_recorder.gd`** sketch:

```gdscript
class_name CallOrderRecorder
extends RefCounted

## Shared test helper for asserting call ORDER (not just count) in GUT.
## Used by lifecycle open/close tests (AC-DOV-1.1, 2.1, 4.1, 5.2).

var _calls: Array[StringName] = []

## Record a call by name.
func record(call_name: StringName) -> void:
    _calls.append(call_name)

## Assert recorded calls match expected sequence exactly.
func assert_order(expected: Array[StringName], gut_test: Object) -> void:
    if _calls != expected:
        gut_test.fail_test(
            "Call order mismatch.\nExpected: %s\nActual:   %s" % [expected, _calls]
        )

## Reset the recorder for a new test.
func reset() -> void:
    _calls.clear()

## Return a copy of recorded calls (for diagnostic assertions).
func get_calls() -> Array[StringName]:
    return _calls.duplicate()
```

**`tests/unit/helpers/viewport_mock.gd`** sketch:

```gdscript
class_name ViewportMock
extends RefCounted

## Mock for Viewport.set_input_as_handled().
## Injected into DocumentOverlayUI._close() via the _get_viewport() seam.

var set_input_as_handled_calls: int = 0

func set_input_as_handled() -> void:
    set_input_as_handled_calls += 1

func reset() -> void:
    set_input_as_handled_calls = 0
```

**Synthetic violation fixtures** directory structure:

```
tests/fixtures/overlay_violations/
├── fp_ov_1_emit.gd           # contains Events.document_opened.emit("x")
├── fp_ov_2_timer.gd          # contains Timer signal connected to _close
├── fp_ov_4_cached_tr.gd      # contains var _body: String = tr("doc.x.body")
├── fp_ov_5_hud.gd            # contains HUDCore.visible = false
├── fp_ov_7_audio.gd          # contains AudioServer.set_bus_volume_db(...)
├── fp_ov_9_button.tscn       # contains [node type="Button" ...]
├── fp_ov_12_smooth.gd        # contains smooth_scroll_enabled = true
├── fp_ov_14_typewriter.gd    # contains Tween.tween_property(BodyText, "text", ...)
├── fp_ov_15_gameplay.gd      # contains Events.player_damaged.connect(...)
└── fp_ov_16_append.gd        # contains BodyText.append_text(tr("doc.x.body"))
```

Each fixture is a minimal single-violation file. The meta-test script invokes `check_forbidden_patterns_overlay.sh` against each fixture's parent directory individually and asserts exit 1.

**Why this story is sprint-day-1 (OQ-DOV-COORD-11)**: thirteen acceptance criteria across Stories 003–008 cite this script (`AC-DOV-3.1`, `6.1`, `6.5`, `6.6`, `7.3`, `10.1–10.9`, `12.3`). Without it, those CI-grep ACs cannot return a meaningful result. The call-order recorder is cited by `AC-DOV-1.1`, `2.1`, `4.1`, `5.2` in Stories 003 and 005. Both must exist before any implementation story ships.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `DocumentOverlayUI.tscn` scene scaffold (the CI script validates against it; the scene is created separately)
- Story 003: actual `document_overlay_ui.gd` signal wiring (the CI script validates against it once it exists)
- Story 005: `_close()` implementation using the viewport-mock seam

---

## QA Test Cases

**AC-1 (meta-test — clean run)**
- Given: `tools/ci/check_forbidden_patterns_overlay.sh` + a clean `src/ui/document_overlay/` (no violations)
- When: script invoked with no arguments (defaults to `src/ui/document_overlay`)
- Then: exit code 0; no "VIOLATION" lines in stdout

**AC-1 (meta-test — violation detection)**
- Given: script + each synthetic fixture in `tests/fixtures/overlay_violations/`
- When: script invoked against each fixture directory individually
- Then: exit code 1 for every fixture; stdout contains the fixture file path and line number

**AC-3 (call-order recorder)**
- Given: `CallOrderRecorder.new()` instance in a GUT test
- When: `record(&"step_a")`, `record(&"step_b")` called in sequence
- Then: `assert_order([&"step_a", &"step_b"], gut_test)` passes; `assert_order([&"step_b", &"step_a"], gut_test)` triggers `fail_test`
- Edge cases: empty recorder + empty expected → pass; single element mismatch → fail with descriptive message

**AC-4 (viewport mock)**
- Given: `ViewportMock.new()` instance
- When: `set_input_as_handled()` called twice
- Then: `set_input_as_handled_calls == 2`; `reset()` brings it back to 0

**AC-6 (fixture non-empty assertion)**
- Given: all files in `tests/fixtures/overlay_violations/`
- When: GUT test reads each file's size
- Then: every fixture file has size > 0 bytes

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/document_overlay_ui/ci_script_self_test.gd` — must exist and pass (AC-2, AC-6)
- `tools/ci/check_forbidden_patterns_overlay_meta_test.sh` — must exist and pass on CI (AC-2)
- Manual: run `./tools/ci/check_forbidden_patterns_overlay.sh` against clean impl → exit 0 confirmed

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — purely tooling; no scene or engine dependencies
- Unlocks: Story 003 (open lifecycle CI ACs require the script), Story 004 (localization CI ACs require the script), Story 005 (close lifecycle CI ACs), Story 006 (scroll CI ACs)

## Open Questions

- The `FP-OV-6` pattern (`overlay_manages_subtitles`) is listed in GDD §C.9 but the task prompt groups it with `FP-OV-5` for enforcement. The CI script above includes it as a separate check for completeness. Confirm with lead-programmer whether to keep it or merge into `FP-OV-5`'s check block.
