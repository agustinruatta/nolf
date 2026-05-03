# Story 001: SettingsService autoload scaffold + ConfigFile persistence layer

> **Epic**: Settings & Accessibility
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Polish (Day-1 HARD MVP DEP — promoted per HUD Core REV-2026-04-26 D2)
> **Type**: Logic
> **Estimate**: 3-4 hours (M — new autoload + ConfigFile round-trip + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: TR-SET-001, TR-SET-003, TR-SET-004, TR-SET-014
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-SET-001**: SettingsService is sole publisher of `Events.setting_changed(category, name, value)` per CR-1.
- **TR-SET-003**: SettingsService is sole reader/writer of `user://settings.cfg` (ConfigFile, separate from SaveGame per ADR-0003).
- **TR-SET-004**: SettingsService registered as autoload at ADR-0007 line 10 (consumers use `settings_loaded` one-shot pattern, not `_ready()` reads — 2026-04-27 amendment).
- **TR-SET-014**: Settings do NOT reset on new-game (saved to separate `user://settings.cfg`, not SaveGame per ADR-0003 separation).

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0007 (Autoload Load Order Registry) + ADR-0002 (Signal Bus + Event Taxonomy)

**ADR Decision Summary**: Per ADR-0003 §IG 10, `user://settings.cfg` (ConfigFile) is strictly separate from the SaveGame Resource — never part of it, never wiped by new-game actions. Per ADR-0007 (2026-04-27 amendment), SettingsService is autoload slot 10 (end-of-block after MissionLevelScripting at slot 9), which guarantees every consumer autoload has connected its `setting_changed` subscriber before the boot burst fires. Per ADR-0002, `setting_changed` is the ONLY signal SettingsService may emit for setting values — no wrapper methods, no per-system pub variants.

**SettingsService: autoload vs scene-tree singleton — DECISION**: SettingsService MUST be an autoload. Rationale: the boot-time burst (CR-9, TR-SET-005) must fire before any scene tree node's `_ready()` runs, specifically before HUD Core, Audio, and PostProcessStack read their initial state. A scene-tree singleton cannot guarantee this ordering without explicit signal-waiting boilerplate on every consumer. ADR-0007 slot 10 (end of autoload block) is the correct mechanism: Godot processes autoloads in declaration order, so SettingsService's `_ready()` fires after all 9 preceding consumer autoloads have connected their `setting_changed` subscribers. This is the ADR-0007 §Cross-Autoload Reference Safety guarantee. No ADR-0007 slot pressure issue: slot 10 is already the assigned slot per the 2026-04-27 amendment resolving Blocker B2.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ConfigFile` API is stable since Godot 4.0. `ConfigFile.load()`, `ConfigFile.save()`, `get_value()`, `set_value()`, `has_section()`, `has_section_key()`, `get_sections()`, `get_section_keys()` are all verified stable — no changes in 4.4, 4.5, or 4.6 per `docs/engine-reference/godot/VERSION.md`. ADR-0003 §Gate 1 verified `ConfigFile` round-trip for ConfigFile metadata sidecar writes on Godot 4.6.2 stable (Linux Vulkan, 2026-04-29 Sprint 01 verification run).

**Control Manifest Rules (Polish — Foundation sub-rules apply)**:
- Required: SettingsService autoload key `SettingsService`, path `*res://src/core/settings/settings_service.gd`, registered at line 10 of `project.godot [autoload]` block per ADR-0007 §Key Interfaces — source: ADR-0007 IG 1
- Required: Every autoload's `_ready()` MAY reference autoloads at earlier line numbers only — SettingsService at slot 10 may reference Events (slot 1) — source: ADR-0007 IG 4
- Required: `setting_changed` is emitted as `Events.setting_changed.emit(category, name, value)` directly, no wrapper emit methods — source: ADR-0002 IG (forbidden pattern `event_bus_wrapper_emit`)
- Forbidden: `ConfigFile.load("user://settings.cfg")` or `ConfigFile.save("user://settings.cfg")` anywhere outside `settings_service.gd` — pattern `settings_in_save_slot` and sole-reader/writer violation (TR-SET-003, FP-2)
- Forbidden: Any setting key written to or read from `SaveGame` capture/restore callbacks — pattern `settings_in_save_slot` (FP-4, ADR-0003 IG 10)
- Forbidden: `SettingsService.get_value()` called from any consumer's `_ready()` — pattern causes load-order race (FP-3); consumers must use Consumer Default Strategy + `setting_changed` subscriber

---

## Acceptance Criteria

*From GDD `design/gdd/settings-accessibility.md` §H.1, §H.2, §H.9, scoped to this story:*

- [ ] **AC-1** (TR-SET-004): GIVEN the project launches, WHEN `get_tree().root.get_children()` is inspected, THEN `SettingsService` is present at the position declared by ADR-0007 (line 10, after `MissionLevelScripting` at line 9), confirmed by `project.godot [autoload]` block byte-match.
- [ ] **AC-2** (TR-SET-001): GIVEN the full GDScript source tree under `src/`, WHEN CI runs grep for `Events.setting_changed.emit(` anywhere outside `src/core/settings/settings_service.gd`, THEN zero matches are found — any match is a build-blocking defect (FP-1 sole-publisher violation).
- [ ] **AC-3** (TR-SET-003): GIVEN the full GDScript source tree, WHEN CI runs grep for `ConfigFile.load("user://settings.cfg")` OR `ConfigFile.save("user://settings.cfg")` outside `settings_service.gd`, THEN zero matches are found (FP-2 sole-reader/writer violation). (GDD AC-SA-9.2)
- [ ] **AC-4** (TR-SET-014 + ADR-0003 IG 10): GIVEN `user://settings.cfg` exists and a new-game action is triggered (SaveGame wiped), WHEN the new-game flow completes, THEN `user://settings.cfg` is untouched — no settings key is present in any `SaveGame.capture()` / `SaveGame.restore()` path. (GDD AC-SA-2.7)
- [ ] **AC-5** (TR-SET-003): GIVEN `user://settings.cfg` is absent on disk, WHEN `SettingsService._ready()` executes, THEN SettingsService populates all keys from `res://src/core/settings/settings_defaults.gd`, writes `settings.cfg` synchronously (via `ConfigFile.save()`), and completes without emitting a player-visible error. (GDD AC-SA-1.1)
- [ ] **AC-6** (TR-SET-003): GIVEN `settings.cfg` is present and `ConfigFile.load()` returns a non-OK error code, WHEN `SettingsService._ready()` executes, THEN SettingsService logs exactly one `[Settings] ERR:` line, falls back to `settings_defaults.gd`, overwrites the file, and the burst phase fires using default values. (GDD AC-SA-1.2)
- [ ] **AC-7** (TR-SET-003): GIVEN a key-value pair has been committed (write-through on commit event per CR-8), WHEN the file is reloaded in a fresh `ConfigFile` instance, THEN the retrieved value is byte-for-byte identical to the value that was written (round-trip fidelity for bool, int, float, String, and StringName types). (GDD AC-SA-2.2)
- [ ] **AC-8** (TR-SET-001 / FP-5 + FP-6): GIVEN the full GDScript source tree, WHEN CI runs static-analysis for every `_on_setting_changed` function body, THEN (a) every function's first statement is `if category != &"<category>": return`, and (b) no `match name:` block in any `_on_setting_changed` contains an `else:` clause. (GDD AC-SA-9.5, AC-SA-9.6)

---

## Implementation Notes

*Derived from ADR-0003 §IG 10 + ADR-0007 §Key Interfaces + GDD §C.1 CR-1..CR-10:*

**File structure to create:**

```
src/core/settings/
├── settings_service.gd          (class_name SettingsService extends Node)
└── settings_defaults.gd         (class_name SettingsDefaults extends RefCounted — const-only)
```

**`settings_defaults.gd`** — pure `const` declarations, no runtime logic per CR-10. All MVP keys from GDD §C.2 must be represented. Key naming convention: `const KEY_MASTER_VOLUME_DB := &"master_volume_db"` (shared constants avoid the inline-string-literal typo risk documented in Cluster I). Defaults:

```
# audio category
const MASTER_VOLUME_DB := 0.0       # tentative — see OQ-SA-14 coord with Audio GDD
const MUSIC_VOLUME_DB  := 0.0
const SFX_VOLUME_DB    := 0.0
const AMBIENT_VOLUME_DB := 0.0
const VOICE_VOLUME_DB  := 0.0
const UI_VOLUME_DB     := 0.0

# graphics category
# resolution_scale: hardware-detected at first launch via CR-11; no const default

# accessibility category
const DAMAGE_FLASH_ENABLED := true
const DAMAGE_FLASH_COOLDOWN_MS := 333     # WCAG 2.3.1 safety floor — CR-17
const CROSSHAIR_ENABLED := true
# photosensitivity_warning_dismissed: absent on first launch (absence = needs warning)
const SUBTITLES_ENABLED := true           # WCAG SC 1.2.2 opt-OUT default — CR-23
const SUBTITLE_SIZE_SCALE := 1.0
const SUBTITLE_BACKGROUND := &"scrim"
const SUBTITLE_SPEAKER_LABELS := true
const SUBTITLE_LINE_SPACING_SCALE := 1.0
const SUBTITLE_LETTER_SPACING_EM := 0.0
const CLOCK_TICK_ENABLED := true          # accessibility category per CR-10 / OQ-SA-13

# controls category
const SPRINT_IS_TOGGLE := false
const CROUCH_IS_TOGGLE := false
const ADS_IS_TOGGLE    := false
const MOUSE_SENSITIVITY_X := 1.0
const MOUSE_SENSITIVITY_Y := 1.0
const GAMEPAD_LOOK_SENSITIVITY := 1.0
const INVERT_Y_AXIS := false

# language category
const LOCALE := "en"
```

**`settings_service.gd`** — autoload `class_name SettingsService extends Node`. Core responsibilities this story:

1. `_load_settings()` — load `user://settings.cfg` via `ConfigFile.load()`; on error or absence, populate from `settings_defaults.gd` and call `ConfigFile.save()`. Per-key type-guard: `if not (loaded_val is float): substitute default, write back, log warn` (CR-7 pattern). Range clamp per Cluster B self-heal.
2. `_write_key(category: StringName, name: StringName, value: Variant)` — internal write-through: `_cfg.set_value(category, name, value)` + `_cfg.save(_SETTINGS_PATH)`. Called on each commit event (slider `drag_ended`, toggle `toggled`, dropdown `item_selected`). This story implements the ConfigFile write path only — the UI commit events are wired in Story 005.
3. `get_value(category: StringName, name: StringName) -> Variant` — synchronous read from the in-memory `_cfg` dict. For runtime queries and tests only; NOT for consumer `_ready()` calls (FP-3).

The `_emit_burst()` and `Events.settings_loaded` one-shot are deferred to Story 002. This story's `_ready()` ends after `_load_settings()` returns (no burst yet, no `settings_loaded` emit yet).

**Autoload registration** — `project.godot [autoload]` line 10 MUST read exactly:
```
SettingsService="*res://src/core/settings/settings_service.gd"
```
per ADR-0007 IG 1 + IG 2 (`*` prefix = scene-mode: Node added to root, `_ready()` fires, tree lifecycle active). Verify byte-match against ADR-0007 §Key Interfaces before marking AC-1 done.

**ADR-0003 separation invariant (TR-SET-014)**: Settings NEVER touches `SaveGame.gd` or any `*_State.gd` file. A comment block at the top of `settings_service.gd` must state: `## Sole owner of user://settings.cfg (ADR-0003 IG 10). NEVER write settings keys into SaveGame — settings and save slots are independent persistence domains.`

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `_emit_burst()` loop + `Events.settings_loaded` one-shot emission + photosensitivity `_boot_warning_pending` flag
- Story 003: Photosensitivity kill-switch integration with HUD Core + Combat + PostProcessStack
- Story 004: dB formula (F.1) implementation + audio bus apply integration
- Story 005: Settings panel UI shell + `InputContext.SETTINGS` lifecycle + AccessKit widget semantics + Tab order
- Story 006: Subtitle defaults write enforcement CI gate

---

## QA Test Cases

*Solo mode — no QA-lead gate. Test cases written by story author per GDD ACs.*

**AC-1 — Autoload registration at slot 10**
- Given: `project.godot` `[autoload]` block as committed
- When: a unit test scene's `_ready()` inspects `get_tree().root.get_children()`
- Then: a Node named `SettingsService` is present; `MissionLevelScripting` precedes it; no autoload follows it at a higher index
- Edge cases: missing entry (Godot logs "Script not found" — test asserts presence, not absence of warning); slot order drift (test asserts `SettingsService` follows `MissionLevelScripting` by name, not by index constant)

**AC-2 — sole-publisher CI gate (FP-1)**
- Given: `src/` GDScript source tree at commit time
- When: CI grep runs `Events.setting_changed.emit(` across all `.gd` files
- Then: exactly 1 match — the one inside `settings_service.gd`; any second match fails CI
- Edge cases: commented-out emit (acceptable — grep by default catches comments; test must filter `#`-prefixed lines)

**AC-3 — sole-reader/writer CI gate (FP-2)**
- Given: `src/` GDScript source tree at commit time
- When: CI grep runs `ConfigFile.*"user://settings.cfg"` across all `.gd` files
- Then: all matches are inside `settings_service.gd`; any match outside fails CI
- Edge cases: test code in `tests/` that directly touches `settings.cfg` for fixture setup — permissible only if the test itself is named `settings_service*` and is a unit test (fixture isolation rule)

**AC-4 — settings survive new-game (FP-4 / ADR-0003 IG 10)**
- Given: `save_game.gd` and all `*_state.gd` files in `src/core/save_load/`
- When: CI grep runs for any settings key literal (e.g., `"master_volume_db"`, `"damage_flash_enabled"`) inside any SaveGame-related file
- Then: zero matches — no settings key name appears in the save domain
- Edge cases: future developer adding a "game volume at save point" feature — CI gate blocks the pattern before it merges

**AC-5 — fresh-install defaults write**
- Given: `user://settings.cfg` absent
- When: a headless unit test instantiates SettingsService and calls its `_ready()`-equivalent setup method with a mock ConfigFile path
- Then: all keys from `settings_defaults.gd` are present in the written cfg; `ConfigFile.load()` on the written file returns `OK` and all values round-trip correctly
- Edge cases: read-only filesystem (mock returns `ERR_FILE_CANT_WRITE`) — SettingsService logs error, continues with in-memory defaults (session functional, changes non-persistent)

**AC-7 — round-trip fidelity**
- Given: a freshly constructed ConfigFile with one key per type (bool, int, float, String, StringName)
- When: `_write_key()` writes each value then a fresh `ConfigFile.load()` reads them back
- Then: each loaded value `==` the written value with no type coercion loss
- Edge cases: `StringName` key stored as `String` (ConfigFile has no native StringName type — store as `String`, reconstitute via `StringName(loaded_string)` on read)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/settings/settings_service_scaffold_test.gd` — must exist and pass (AC-1, AC-5, AC-6, AC-7)
- `tests/unit/settings/forbidden_patterns_ci_test.gd` — must exist and pass (AC-2, AC-3, AC-4, AC-8) — static-analysis / grep gate, not runtime GUT test; structured as a GUT test that reads source files via `FileAccess`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Signal Bus epic (Story 001 — Events autoload with `setting_changed` signal declared) must be DONE
- Depends on: ADR-0007 autoload slot 10 assignment (2026-04-27 amendment — already landed; confirmed in ADR-0007 §Canonical Registration Table)
- Unlocks: Story 002 (boot burst + `settings_loaded` — reads from the ConfigFile layer this story creates)
