# Story 002: Boot lifecycle — burst emit, settings_loaded signal, photosensitivity warning flag

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Polish (Day-1 HARD MVP DEP — promoted per HUD Core REV-2026-04-26 D2)
> **Type**: Logic
> **Estimate**: 3-4 hours (M — burst loop + one-shot signal + warning flag + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: TR-SET-002, TR-SET-005, TR-SET-008, TR-SET-015
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-SET-002**: `settings_loaded()` signal added to Settings domain (no payload; one-shot per session per CR-9; ADR-0002 amendment 2026-04-28).
- **TR-SET-005**: Boot-time burst (CR-9): SettingsService emits `setting_changed` synchronously for all stored triples, then emits `settings_loaded` one-shot.
- **TR-SET-008**: `accessibility.damage_flash_enabled` boolean toggle + `photosensitivity_warning_dismissed` persistent flag per ADR-0003 (settings.cfg, not SaveGame).
- **TR-SET-015**: Photosensitivity cluster (3 keys: `photosensitivity_warning_dismissed`, `damage_flash_enabled`, `damage_flash_cooldown_ms`) survives Restore Defaults; only `settings.cfg` deletion triggers re-warning (safety invariant).

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy — 2026-04-28 amendment adds `settings_loaded`) + ADR-0007 (slot 10 end-of-block placement) + ADR-0003 (settings.cfg separation)

**ADR Decision Summary**: Per ADR-0002 (2026-04-28 amendment), `Events.settings_loaded()` is a one-shot no-payload signal in the Settings domain, emitted exactly once per session by SettingsService after the burst completes. It fires at autoload slot 10's `_ready()` end — all consumer autoloads at slots 1–9 have already connected their `setting_changed` subscribers by that point, so every consumer receives the burst synchronously. The `settings_loaded` one-shot is how consumers (HUD Core, Audio, PostProcessStack) know they can safely render their initial state. Consumers MUST use the Consumer Default Strategy (hardcoded fallback constants from `settings_defaults.gd`) for the window before `settings_loaded` fires — they must NOT call `SettingsService.get_value()` in their own `_ready()` (FP-3, load-order race).

The boot order per GDD §C.3:
```
Autoload slot 6: PostProcessStack._ready()  → Events.setting_changed.connect(_on_set)
Autoload slot 7: Combat._ready()            → Events.setting_changed.connect(_on_set)
...
Autoload slot 10: SettingsService._ready():
    1. _load_settings()       (Story 001)
    2. _apply_rebinds()       (Story 007)
    3. _emit_burst()          ← THIS STORY
    4. Events.settings_loaded.emit()  ← THIS STORY
```

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Signal.emit()` synchronous dispatch (callee runs inline, return comes after all subscribers complete) is stable Godot 4.0+. No post-cutoff API concerns. Confirmed by ADR-0002 §Sprint 01 verification (2026-04-29): EventLogger at autoload slot 2 connected to Events slot 1 signal from `_ready()` — cross-autoload synchronous signal dispatch confirmed on Godot 4.6.2 stable (Linux Vulkan).

**Forbidden pattern — `settings_published_per_key_without_loaded_event`**: Publishing individual `setting_changed` signals without the subsequent `settings_loaded` one-shot is a forbidden pattern. The one-shot is what consumers wait for to know the burst is complete. Omitting it means HUD Core / Audio / PostProcessStack have no reliable signal that all settings are hydrated.

**Control Manifest Rules (Foundation sub-rules apply)**:
- Required: `Events.settings_loaded.emit()` called exactly once per session, synchronously after `_emit_burst()` completes — source: ADR-0002 2026-04-28 amendment
- Required: `_emit_burst()` must NOT emit `setting_changed` for the `[controls]` section (rebind keys handled separately via `_apply_rebinds()` per CR-19) — source: GDD C.3 step 3
- Required: `settings_loaded` is one-shot — SettingsService must guard against re-emission on Settings panel open/close or subsequent `setting_changed` emits — source: GDD AC-SA-1.5 + AC-SA-8.5
- Forbidden: `await` keyword or `call_deferred(` inside any `_on_setting_changed` handler — burst-emit re-entrancy violation (FP-9); synchronous burst requires all handlers complete inline
- Forbidden: `settings_published_per_key_without_loaded_event` — any path that calls `Events.setting_changed.emit()` at boot without the subsequent `Events.settings_loaded.emit()` is a defect

---

## Acceptance Criteria

*From GDD `design/gdd/settings-accessibility.md` §H.1, §H.5, §H.11, scoped to this story:*

- [ ] **AC-1** (TR-SET-005): GIVEN a valid `settings.cfg` with N non-controls key-value pairs, WHEN `_emit_burst()` runs, THEN exactly N `setting_changed` signals are emitted — one per `(category, name, value)` triple — and zero emits are made for the `[controls]` section. (GDD AC-SA-1.4)
- [ ] **AC-2** (TR-SET-005 / load order): GIVEN a valid `settings.cfg`, WHEN `SettingsService._ready()` executes, THEN rebinds are applied to `InputMap` before the first `setting_changed` burst emit fires (i.e., `_apply_rebinds()` stub completes before the first `Events.setting_changed.emit()` call). (GDD AC-SA-1.3)
- [ ] **AC-3** (TR-SET-002): GIVEN the burst emit has completed, WHEN `SettingsService._ready()` reaches its final step, THEN `Events.settings_loaded` is emitted exactly once with no payload, and it is not emitted again during the same session (panel open/close, subsequent `setting_changed`, Restore Defaults burst). (GDD AC-SA-1.5, AC-SA-8.5)
- [ ] **AC-4** (TR-SET-008): GIVEN `user://settings.cfg` is present but the `accessibility.photosensitivity_warning_dismissed` key is absent, WHEN `SettingsService._ready()` completes, THEN `SettingsService._boot_warning_pending` is `true`. (GDD AC-SA-1.6)
- [ ] **AC-5** (TR-SET-008): GIVEN `user://settings.cfg` is present and `accessibility.photosensitivity_warning_dismissed` is `true`, WHEN `SettingsService._ready()` completes, THEN `SettingsService._boot_warning_pending` is `false`. (GDD AC-SA-1.7)
- [ ] **AC-6** (TR-SET-008): GIVEN `user://settings.cfg` has no `accessibility.photosensitivity_warning_dismissed` key (first launch), WHEN Menu System's `_ready()` runs after SettingsService, THEN the photosensitivity warning modal is displayed BEFORE the main menu becomes interactive (main menu input is blocked until modal is dismissed). (GDD AC-SA-5.4 — Menu System scaffold integration; this story owns the flag, Menu System story owns the modal scaffold)
- [ ] **AC-7** (TR-SET-008 + photosensitivity warning dismiss): GIVEN the photosensitivity warning modal is visible, WHEN the player presses "Continue", THEN `accessibility.photosensitivity_warning_dismissed = true` is written to `settings.cfg` synchronously and the modal dismisses — on the next launch, `_boot_warning_pending` is `false`. (GDD AC-SA-5.5)
- [ ] **AC-8** (TR-SET-008): GIVEN the warning modal is visible, WHEN the player presses "Go to Settings", THEN (a) `accessibility.photosensitivity_warning_dismissed = true` is written BEFORE the Settings panel opens, and (b) the Settings panel opens pre-navigated to Accessibility with focus on `damage_flash_enabled` toggle. (GDD AC-SA-5.6)
- [ ] **AC-9** (TR-SET-015): GIVEN the player has set the photosensitivity safety cluster (`photosensitivity_warning_dismissed = true`, `damage_flash_enabled = false`, `damage_flash_cooldown_ms = 1000`) before Restore Defaults is invoked, WHEN the reset completes, THEN all three cluster keys retain their pre-reset values; `Events.settings_loaded` is NOT re-emitted (one-shot per session). (GDD AC-SA-11.1, AC-SA-11.2, AC-SA-11.3)
- [ ] **AC-10** (FP-9): GIVEN the full GDScript source tree, WHEN CI scans every function named `_on_setting_changed`, THEN zero `await` keywords or `call_deferred(` calls are found in any function body — burst-emit synchronicity preserved. (GDD AC-SA-11.14)

---

## Implementation Notes

*Derived from ADR-0002 2026-04-28 amendment + GDD §C.3 + §C.1 CR-9:*

**`_emit_burst()` implementation** — called from `SettingsService._ready()` after `_load_settings()` and `_apply_rebinds()` complete:

```gdscript
func _emit_burst() -> void:
    for category in _cfg.get_sections():
        if category == &"controls":
            continue  # controls handled by _apply_rebinds(), never emitted
        for key in _cfg.get_section_keys(category):
            var value: Variant = _cfg.get_value(category, key)
            Events.setting_changed.emit(StringName(category), StringName(key), value)
    Events.settings_loaded.emit()
    _settings_loaded_emitted = true  # guard for one-shot enforcement
```

The `_settings_loaded_emitted: bool` guard prevents re-emission on Restore Defaults burst. Restore Defaults re-runs `_emit_burst()` BUT checks the guard first — if already emitted this session, skip `Events.settings_loaded.emit()` (GDD CR-25 step 2 + AC-SA-11.3).

**`_boot_warning_pending` flag** — read-only after `_ready()` completes per GDD §UI-5 public API:

```gdscript
var _boot_warning_pending: bool = false

func _check_boot_warning() -> void:
    if not _cfg.has_section_key("accessibility", "photosensitivity_warning_dismissed"):
        _boot_warning_pending = true
```

Called during `_load_settings()` after the cfg is loaded/written. The absence of the key (not `false`) is the signal for first-launch. This is why `settings_defaults.gd` does NOT list `photosensitivity_warning_dismissed` — it must be absent on first launch.

**`dismiss_warning()` public method** — called by Menu System's photosensitivity modal buttons:

```gdscript
func dismiss_warning() -> bool:
    _boot_warning_pending = false
    _cfg.set_value("accessibility", "photosensitivity_warning_dismissed", true)
    var err := _cfg.save(_SETTINGS_PATH)
    return err == OK
```

Returns `bool` per GDD §UI-5 (`false` on disk-full or I/O failure, per Menu System AC-MENU-6.4).

**Photosensitivity safety cluster preservation** — stored as a `const` array in `settings_service.gd`:

```gdscript
const PHOTOSENSITIVITY_CLUSTER_KEYS: Array[String] = [
    "photosensitivity_warning_dismissed",
    "damage_flash_enabled",
    "damage_flash_cooldown_ms",
]
```

`_restore_defaults()` (called by Restore Defaults button in Story 005) reads each key from `PHOTOSENSITIVITY_CLUSTER_KEYS`, caches the current value, performs the full reset, then re-writes the cached values. This is the CR-25 invariant: the cluster is never reset by a convenience action.

**Consumer Default Strategy reminder** — every consumer autoload that subscribes to `setting_changed` MUST define fallback constants matching `settings_defaults.gd`. The burst arrives synchronously at end of slot 10's `_ready()`, so by the time any Main Scene node's `_ready()` runs, all autoload consumers have already received the burst. Non-autoload consumers (HUD scene, inventory panel) initialized after boot receive no retroactive burst and must rely on their hardcoded constants until they call `SettingsService.get_value()` at runtime.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: ConfigFile load/write infrastructure (`_load_settings()`, `_write_key()`, `settings_defaults.gd`)
- Story 003: Photosensitivity kill-switch integration with HUD Core / Combat / PostProcessStack
- Story 004: dB formula and audio bus apply
- Story 005: Settings panel UI, `open_panel()` method, `InputContext.SETTINGS` push/pop
- Story 007: `_apply_rebinds()` full implementation (this story uses a no-op stub that logs "rebinds not yet implemented")
- Menu System story: photosensitivity warning modal scaffold (Control hierarchy, button rendering, focus management) — owned by Menu System epic; this story owns only the `_boot_warning_pending` flag and `dismiss_warning()` method

---

## QA Test Cases

*Solo mode — no QA-lead gate. Test cases written by story author per GDD ACs.*

**AC-1 — burst emits exactly N non-controls triples**
- Given: a mock ConfigFile fixture with 3 audio keys + 1 graphics key + 2 accessibility keys + 1 `[controls]` key (total 7 entries)
- When: `_emit_burst()` runs
- Then: `Events.setting_changed` fires exactly 6 times (controls section skipped); emitted tuples match the fixture key-value pairs exactly
- Edge cases: empty `settings.cfg` (no sections) → 0 `setting_changed` emits, `settings_loaded` still fires; `[controls]` section only → 0 `setting_changed` emits

**AC-3 — settings_loaded one-shot**
- Given: SettingsService `_ready()` has run once in the current session
- When: (a) Settings panel opens and closes, (b) Restore Defaults burst fires, (c) any subsequent `setting_changed` emits
- Then: a subscriber that counted `settings_loaded` emissions observes exactly 1 emission total for the full session
- Edge cases: hot-reload (dev only) — documented exception, not tested in CI

**AC-4 + AC-5 — _boot_warning_pending flag**
- Given: two fixtures: (A) cfg absent `photosensitivity_warning_dismissed` key, (B) cfg has `photosensitivity_warning_dismissed = true`
- When: `_load_settings()` processes each fixture
- Then: (A) `_boot_warning_pending == true`, (B) `_boot_warning_pending == false`
- Edge cases: cfg has `photosensitivity_warning_dismissed = false` (explicitly false, not absent) → treated as absent per AC-4 (key must be absent, not false, to trigger warning — but `false` IS a valid stored value; only ABSENCE triggers the warning per GDD C.6 step 1)

**AC-9 — photosensitivity cluster survives Restore Defaults**
- Given: photosensitivity safety cluster set to `{dismissed: true, flash_enabled: false, cooldown_ms: 1000}`
- When: `_restore_defaults()` is called
- Then: (1) all three cluster keys unchanged in the written cfg; (2) `settings_loaded` emission count remains at 1; (3) all other keys match `settings_defaults.gd` values
- Edge cases: cluster key missing before Restore Defaults (e.g., corrupted cfg) → restore proceeds normally; the missing cluster key is NOT written during restore (absence preserved); `settings_defaults.gd` does not contain the dismissed flag

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/settings/boot_lifecycle_test.gd` — must exist and pass (AC-1 through AC-5, AC-7, AC-9)
- `tests/unit/settings/photosensitivity_warning_test.gd` — must exist and pass (AC-7, AC-8)
- `tests/unit/settings/forbidden_patterns_ci_test.gd` — updated for AC-10 (FP-9 await gate; same test file as Story 001)
- `tests/integration/settings/boot_warning_test.gd` — must exist and pass (AC-6 — Menu System integration; may be marked pending until Menu System epic ships modal scaffold)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (SettingsService scaffold + ConfigFile `_load_settings()` / `_write_key()`) must be DONE
- Depends on: Signal Bus epic having `Events.settings_loaded()` declared (ADR-0002 2026-04-28 amendment landed — confirmed in ADR-0002 Revision History 2026-04-28)
- Unlocks: Story 003 (photosensitivity integration — requires `_boot_warning_pending` flag and `damage_flash_enabled` burst emit)
- Unlocks: Story 004 (audio bus apply — requires burst emitting audio keys so AudioServer applies them at boot)
- Unlocks: Menu System epic (boot-warning modal scaffold reads `_boot_warning_pending` from this story's `dismiss_warning()` public API)
