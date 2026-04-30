# Story 004: auto_translate_mode + NOTIFICATION_TRANSLATION_CHANGED re-resolution discipline

> **Epic**: Localization Scaffold
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 hours (M — pattern documentation + custom Control example + locale-switch smoke test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/localization-scaffold.md`
**Requirement**: TR-LOC-006 (`Control.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` for automatic UI re-render on locale change), TR-LOC-007 (`NOTIFICATION_TRANSLATION_CHANGED` re-resolves; no caching at `_ready`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry)
**ADR Decision Summary**: ADR-0004 G4 (verified 2026-04-29) confirms `Node.AUTO_TRANSLATE_MODE_*` enum identifiers (`AUTO_TRANSLATE_MODE_INHERIT`, `AUTO_TRANSLATE_MODE_ALWAYS`, `AUTO_TRANSLATE_MODE_DISABLED`) exist in Godot 4.6 as documented. Per GDD §Detailed Design "Re-render rule": HUD values that update via `Events` signals re-resolve per event (no extra work). Static labels (menu titles, settings labels) MUST either use Godot's `auto_translate_mode = ALWAYS` OR implement `_notification(NOTIFICATION_TRANSLATION_CHANGED)` to re-resolve. **No string resolved in `_ready()` may be treated as final** — caching is the `cached_translation_at_ready` forbidden pattern.

**Engine**: Godot 4.6 | **Risk**: LOW (post-Sprint-01)
**Engine Notes**: `Control.auto_translate_mode` is Godot 4.5+ (post-cutoff for LLM training data, Sprint 01 G4 verified 2026-04-27). `NOTIFICATION_TRANSLATION_CHANGED` is the canonical engine notification fired on every Node when `TranslationServer.set_locale()` is called — stable since Godot 4.0. The pairing is: declarative bindings (Label.text = "key") use `auto_translate_mode = ALWAYS`; programmatic compositions (e.g., `label.text = tr("key.a") + ": " + tr("key.b")`) need `_notification(NOTIFICATION_TRANSLATION_CHANGED)` to re-compose.

**Control Manifest Rules (Foundation)**:
- Required: `Control` nodes with declarative text bindings use `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` (TR-LOC-006)
- Required: custom Controls that programmatically compose strings re-resolve in `_notification(NOTIFICATION_TRANSLATION_CHANGED)` (TR-LOC-007)
- Forbidden: storing `tr()` result in a `var` at `_ready()` without re-resolution mechanism — pattern `cached_translation_at_ready` (formal registration in Story 005)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria 9 + §Detailed Design "Re-render rule":*

- [ ] **AC-1**: An example scene demonstrates the `auto_translate_mode = ALWAYS` declarative pattern: a `Label` node with `text = "menu.main.start_mission"` and `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` (set in scene file or via inspector). When the scene loads with locale `en`, the label displays `"Start Mission"` (the resolved tr() value).
- [ ] **AC-2**: GIVEN the example Label from AC-1 is in the scene tree, WHEN `TranslationServer.set_locale("_pseudo")` is called (using the pseudolocale from Story 002), THEN the Label's displayed text updates AUTOMATICALLY (without scene reload) to the pseudo-translated value.
- [ ] **AC-3**: An example custom Control demonstrates programmatic composition with `NOTIFICATION_TRANSLATION_CHANGED` re-resolution. Example pattern: a `HBoxContainer` subclass that composes `tr("hud.section.label") + ": " + tr("hud.section.current_value")`. The Control overrides `_notification(what)` to handle `NOTIFICATION_TRANSLATION_CHANGED` and re-build the composed string.
- [ ] **AC-4**: GIVEN the example custom Control from AC-3 is in the scene tree with locale `en`, WHEN locale switches to `_pseudo`, THEN the composed string updates to the pseudo-translated parts (both segments re-resolve, not just one).
- [ ] **AC-5**: A code-style example (`docs/coding-standards.md` snippet OR a comment in the example custom Control) documents the canonical patterns — `auto_translate_mode` for declarative, `_notification` for programmatic — so future contributors have a reference.
- [ ] **AC-6**: GIVEN any GDScript file under `src/`, WHEN grepped for `var \w+ = tr(` inside `_ready()` function bodies (with no corresponding `_notification(NOTIFICATION_TRANSLATION_CHANGED)` handler in the same script), THEN zero matches in production code (per `cached_translation_at_ready` rule; lint is registered formally in Story 005, but this story sets up the discipline by avoiding the pattern in its own example code).
- [ ] **AC-7**: Smoke test verifies `Node.AUTO_TRANSLATE_MODE_ALWAYS` enum constant is `1` (Godot 4.5+ stable; Sprint 01 G4 verified). If the enum value differs in this Godot installation, fail with a clear "engine version mismatch — verify ADR-0004 G4 against pinned Godot version" message.

---

## Implementation Notes

*Derived from GDD §Detailed Design "Re-render rule" + ADR-0004 §Engine Compatibility G4:*

**Pattern A: Declarative `auto_translate_mode` (preferred)**

Use this pattern for static labels whose text is a single `tr()` key with no runtime composition.

```gdscript
# In a scene file or programmatically:
@onready var _start_button: Button = $StartButton

func _ready() -> void:
    _start_button.text = "menu.main.start_mission"
    _start_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
    # Godot resolves tr("menu.main.start_mission") at render time, re-resolves on locale change automatically
```

(Or set `auto_translate_mode = 1` directly in the .tscn file's property block for the Button node.)

**Pattern B: `_notification(NOTIFICATION_TRANSLATION_CHANGED)` (programmatic composition)**

Use this pattern when the text is a runtime composition (concatenation, format substitution with dynamic values, conditional branches).

```gdscript
# src/core/ui/translatable_section_label.gd (example)
class_name TranslatableSectionLabel extends Label

@export var section_id: StringName = &""
var _current_value: String = ""

func _ready() -> void:
    _refresh_text()
    Events.section_value_changed.connect(_on_value_changed)

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED:
        _refresh_text()

func _refresh_text() -> void:
    text = tr("hud.section.label").format({"section": section_id}) + ": " + _current_value

func _on_value_changed(new_value: String) -> void:
    _current_value = new_value
    _refresh_text()
```

**Why two patterns**: Pattern A is zero-boilerplate for the common case; Pattern B handles cases where Godot's auto-translate doesn't know how to re-compose (because the composition logic lives in script). Most UI work uses Pattern A; ~10–20% of UI work needs Pattern B for parameterized or conditional text.

**Forbidden pattern: `cached_translation_at_ready`** (per Rule 9 + Edge Cases):

```gdscript
# WRONG: cached at _ready, not refreshed on locale change
@onready var _start_label_text: String = tr("menu.main.start_mission")

func _ready() -> void:
    $Label.text = _start_label_text   # Frozen as English forever
```

Either move to Pattern A (use `auto_translate_mode`) or move to Pattern B (re-resolve in `_notification`). Story 005 lints for this pattern.

**`auto_translate_mode` values per `Node` enum** (Godot 4.5+, G4-verified):
- `AUTO_TRANSLATE_MODE_INHERIT = 0` — inherit from parent (default)
- `AUTO_TRANSLATE_MODE_ALWAYS = 1` — always run `tr()` on text properties
- `AUTO_TRANSLATE_MODE_DISABLED = 2` — never run `tr()` (use raw string)

For Localization Scaffold compliance: every `Control` with player-visible text uses either `ALWAYS` (Pattern A) or `DISABLED` + manual `_notification` handling (Pattern B). `INHERIT` is acceptable when the parent is configured deliberately; avoid relying on default inheritance for top-level UI roots.

**Example file locations** (suggested):
- Pattern A: a small `.tscn` at `tests/fixtures/localization/auto_translate_label_example.tscn` with a Button + `auto_translate_mode = ALWAYS`
- Pattern B: a script at `src/core/ui/translatable_composed_label.gd` (or a similar location consistent with project conventions)

**Smoke test** — exercises both patterns:
1. Load Pattern A fixture scene; assert displayed text matches `tr("menu.main.start_mission")` for locale `en`
2. Switch locale to `_pseudo`; assert displayed text changes (no scene reload)
3. Load Pattern B example with a composed string; switch locale; assert composition re-runs

**Locale-switch trigger for tests**: `TranslationServer.set_locale("_pseudo")` directly; alternatively, use Godot's editor Translation Preview at dev time. The custom Control's `_notification(NOTIFICATION_TRANSLATION_CHANGED)` should fire automatically on the locale change.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: base CSV registration (already done; this story uses keys from those CSVs)
- Story 002: pseudolocalization (already done; this story uses `_pseudo` locale for AC-2 / AC-4 testing)
- Story 003: plural forms (orthogonal — both patterns work the same with or without plurals)
- Story 005: lint registration of `cached_translation_at_ready` forbidden pattern (this story uses the rule; Story 005 enforces it via CI)
- Per-screen UI implementation (Menu, HUD, Settings) — owned by their respective epics; this story provides the patterns those epics will consume
- Locale picker UI + persistence — Settings & Accessibility epic

---

## QA Test Cases

**AC-1 — Pattern A example renders correctly at default locale**
- **Given**: example fixture scene with Button (`text = "menu.main.start_mission"`, `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`); locale = `en`
- **When**: scene loads
- **Then**: Button's displayed text equals `"Start Mission"` (the tr() resolved value); not the raw key
- **Edge cases**: `auto_translate_mode` not set (default INHERIT) with parent set to DISABLED → label shows raw key; this AC verifies the explicit ALWAYS setting

**AC-2 — Pattern A re-renders on locale switch**
- **Given**: scene from AC-1 mounted in scene tree; signal-spy on the Label's `text` property OR observed via `get_tree().get_root().<...>` rendering
- **When**: `TranslationServer.set_locale("_pseudo")` is called
- **Then**: the Label's displayed text changes to the `_pseudo` value (e.g., starts with `[•`); no scene reload, no manual refresh call needed
- **Edge cases**: locale switch triggers a frame delay → test awaits `process_frame` signal then asserts; `auto_translate_mode = INHERIT` with parent ALWAYS also works (test the explicit ALWAYS to be deterministic)

**AC-3 — Pattern B custom Control composes correctly at default locale**
- **Given**: `TranslatableComposedLabel` (or equivalent) instantiated with locale = `en`
- **When**: `_ready()` runs
- **Then**: composed text matches the format `<resolved("hud.section.label").format(...)>: <current_value>` (verifying the `_refresh_text()` ran at least once and the composition logic is correct)
- **Edge cases**: `_current_value` is empty string → composition returns `"<label>: "` (no error); test verifies trailing-colon edge

**AC-4 — Pattern B re-resolves on locale switch**
- **Given**: custom Control from AC-3 mounted in scene tree; locale = `en`
- **When**: `TranslationServer.set_locale("_pseudo")` is called
- **Then**: `_notification(NOTIFICATION_TRANSLATION_CHANGED)` fires on the custom Control; `_refresh_text()` runs again; both `tr("hud.section.label")` and any other tr-calls in the composition re-resolve to the new locale
- **Edge cases**: signal-spy on Events bus is irrelevant here — this is engine notification; test relies on observable text change after locale switch

**AC-5 — Documentation snippet exists**
- **Given**: project documentation (coding standards or example file's docstring)
- **When**: a developer searches for "auto_translate_mode" or "NOTIFICATION_TRANSLATION_CHANGED"
- **Then**: at least one location documents the two-pattern decision rule (declarative vs programmatic) with code examples
- **Edge cases**: documentation in a comment block at top of `translatable_composed_label.gd` is acceptable as a minimal MVP; a more thorough doc page can follow

**AC-6 — No `cached_translation_at_ready` in production code**
- **Given**: all GDScript files under `src/`
- **When**: a regex grep searches for `var\s+\w+\s*[:=]\s*tr\(` inside `_ready()` function bodies AND the same file does NOT contain `NOTIFICATION_TRANSLATION_CHANGED`
- **Then**: zero matches
- **Edge cases**: `var x: String = tr("key")` outside `_ready()` (e.g., in a dedicated `_refresh_text` helper that's called from `_notification`) is acceptable; the lint targets the `_ready` body specifically

**AC-7 — AUTO_TRANSLATE_MODE_ALWAYS enum value sanity check**
- **Given**: Godot 4.6.x runtime
- **When**: a test reads `Node.AUTO_TRANSLATE_MODE_ALWAYS`
- **Then**: returns `1` (matches G4 verification finding)
- **Edge cases**: future Godot upgrades may change enum values — test produces a clear diagnostic referencing ADR-0004 §Engine Compatibility for re-verification

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/localization_locale_switch_test.gd` — must exist and pass (covers all 7 ACs; includes both Pattern A fixture scene and Pattern B custom Control)
- Naming follows Foundation-layer convention
- Determinism: `TranslationServer.set_locale` saved/restored in setup/teardown; tests await frame processing before asserting locale-switch effects

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (base CSV registration; `menu.csv` and `hud.csv` must have the keys this story references), Story 002 (`_dev_pseudo.csv` and `_pseudo` locale must exist for locale-switch tests)
- Unlocks: Menu System epic, HUD Core epic, Settings & Accessibility epic, Document Overlay epic — every UI epic uses one of these two patterns; this story is the canonical reference
