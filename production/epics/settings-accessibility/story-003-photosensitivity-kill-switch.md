# Story 003: Photosensitivity kill-switch + PostProcessStack glow handshake

> **Epic**: Settings & Accessibility
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Polish (Day-1 HARD MVP DEP — WCAG SC 2.3.1 safety-critical)
> **Type**: Integration
> **Estimate**: 3-4 hours (M — PostProcessStack hook + HUD + Combat subscriber stubs + integration tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: TR-SET-007, TR-SET-008
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-SET-007**: `accessibility.damage_flash_cooldown_ms` slider has 333 ms hard floor (WCAG 2.3.1 ceiling, 3 Hz) per CR-17 — clamped both in UI widget AND on load.
- **TR-SET-008**: `accessibility.damage_flash_enabled` boolean toggle + `photosensitivity_warning_dismissed` persistent flag per ADR-0003 (settings.cfg, not SaveGame).

**ADR Governing Implementation**: ADR-0002 (Signal Bus) + ADR-0003 (settings.cfg separate from SaveGame) + ADR-0004 (UI Framework — Proposed pending G5; AccessKit widget properties unverified for Godot 4.6)

**ADR Decision Summary**: `accessibility.damage_flash_enabled` is the single kill-switch that gates BOTH the HUD Core damage-flash numeral effect (HUD Core CR-7) AND the Combat Enhanced Hit Feedback pulse (Combat V.6) AND glow intensity on the PostProcessStack (photosensitivity → PPS handshake). Per ADR-0002, SettingsService is the sole emitter; consumers (HUD Core, Combat, PostProcessStack) are subscribers that check `category == &"accessibility"` as their first guard. Per ADR-0003, the kill-switch value persists in `user://settings.cfg` — it survives new-game starts and is NOT in SaveGame (TR-SET-014).

**WCAG 2.3.1 invariant**: The 333 ms floor on `damage_flash_cooldown_ms` is a safety contract, not a tuning knob. It corresponds to the WCAG 2.3.1 ceiling of 3 Hz (1000 ms / 3 = 333.3 ms minimum interval between flashes). The floor is enforced at TWO levels: (a) load-time clamp on every `ConfigFile.load()` (Cluster B self-heal), and (b) HSlider `min_value = 333` in the Settings panel UI widget (Story 005). Neither enforcement replaces the other — if the UI clamp is absent, drag can emit sub-333 values to consumers during live-preview; if the load-time clamp is absent, a manually-edited cfg can inject sub-333 values.

**PostProcessStack handshake**: `PostProcessStack.set_glow_intensity(value: float)` is called at two points:
1. At boot — during the burst emit (Story 002), PostProcessStack's `_on_setting_changed` subscriber receives `setting_changed("accessibility", "damage_flash_enabled", v)` and calls `PostProcessStack.set_glow_intensity(v ? 1.0 : 0.0)`.
2. On toggle change — whenever the player changes `damage_flash_enabled` in the Settings panel, the same subscriber fires.

PostProcessStack owns the actual glow shader uniform. SettingsService owns the persisted value and the emit. This story verifies the handshake exists and fires correctly.

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM
**Engine Notes**: `PostProcessStack.set_glow_intensity()` is a project-defined public API (documented in `production/epics/post-process-stack/EPIC.md` §VS Scope). ADR-0004 Gate 1 (AccessKit property names on custom Controls) is OPEN — photosensitivity slider accessibility annotations (TR-SET-012) are deferred to Story 005 where the full panel UI is built. The HSlider `min_value` property is a standard Godot 4.0+ API — no verification risk.

> "This API may have changed in [version] — verify against the reference docs before using."
> `PostProcessStack.set_glow_intensity()` is a **project-defined method**, not a Godot engine API. Verify the signature matches `production/epics/post-process-stack/EPIC.md` before calling. The underlying `glow_enabled` Compositor or `WorldEnvironment.environment.glow_enabled` property may differ across Godot 4.4 / 4.5 / 4.6 — verify against `docs/engine-reference/godot/` before implementing.

**Control Manifest Rules (Foundation sub-rules apply)**:
- Required: every `_on_setting_changed` handler's first statement is `if category != &"accessibility": return` (CR-5, FP-5) — source: ADR-0002 IG
- Required: `match name:` block in `_on_setting_changed` must NOT have an `else:` branch (FP-6 forward-compat) — source: GDD CR-5
- Required: `if value is bool` type-guard before dereferencing `value` as bool in `_on_setting_changed` (CR-7) — source: GDD CR-7
- Forbidden: HUD Core or Combat emitting `setting_changed` for `damage_flash_enabled` — sole-publisher violation (FP-1); they only subscribe

---

## Acceptance Criteria

*From GDD `design/gdd/settings-accessibility.md` §H.2, §H.5, §H.8, scoped to this story:*

- [ ] **AC-1** (TR-SET-007, load-time clamp): GIVEN a manually-edited `settings.cfg` sets `accessibility.damage_flash_cooldown_ms = 100` (below the 333 ms WCAG safety floor), WHEN SettingsService loads the file, THEN the loaded value is clamped to `333`, written back to disk (self-heal), and the value emitted in `setting_changed` is `333` — no sub-333 value reaches any consumer. (GDD AC-SA-5.2)
- [ ] **AC-2** (TR-SET-007, UI clamp — deferred to Story 005): NOTE — the HSlider `min_value = 333` property check is deferred to Story 005 (Settings panel UI). This story covers only the load-time clamp. Documented as out of scope below.
- [ ] **AC-3** (TR-SET-008, kill-switch gate): GIVEN `accessibility.damage_flash_enabled` is set to `false` via `setting_changed`, WHEN (a) HUD Core receives the emit, THEN HUD Core's internal damage-flash-suppression flag is `true`; WHEN (b) Combat receives the emit, THEN Combat's EHF-suppression flag is `true`. Verified via consumer state-flag queries, not pixel inspection. (GDD AC-SA-5.1, AC-SA-8.2)
- [ ] **AC-4** (PostProcessStack handshake at boot): GIVEN `settings.cfg` persists `accessibility.damage_flash_enabled = false`, WHEN SettingsService's boot burst fires (Story 002), THEN PostProcessStack receives `setting_changed("accessibility", "damage_flash_enabled", false)` and calls `PostProcessStack.set_glow_intensity(0.0)` within the same synchronous burst frame. (GDD AC-SA-8.4 partial)
- [ ] **AC-5** (PostProcessStack handshake on toggle): GIVEN the Settings panel is open and the player toggles `damage_flash_enabled` to `false`, WHEN SettingsService writes and emits the change, THEN PostProcessStack receives the emit and calls `set_glow_intensity(0.0)` within the same frame — no restart required. Toggling back to `true` calls `set_glow_intensity(1.0)`. (GDD §VS Scope expansion — photosensitivity → PPS handshake)
- [ ] **AC-6** (TR-SET-007, self-heal round-trip): GIVEN a `settings.cfg` that previously stored `damage_flash_cooldown_ms = 100` and was self-healed to `333` on load, WHEN SettingsService writes the healed value back to disk and the file is reloaded in a fresh `ConfigFile`, THEN the retrieved value is `333` — the self-heal persists across restarts. (GDD AC-SA-2.2 applied to this specific key)
- [ ] **AC-7** (FP-5 / consumer guard): GIVEN PostProcessStack's `_on_setting_changed` function source, WHEN inspected, THEN the first statement is `if category != &"accessibility": return` — the category guard is the literal first executable statement. (GDD AC-SA-9.5)
- [ ] **AC-8** (FP-6 / forward-compat): GIVEN PostProcessStack's, HUD Core's, and Combat's `_on_setting_changed` function sources, WHEN inspected, THEN no `match name:` block within any of them contains an `else:` clause. (GDD AC-SA-9.6)

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines + GDD §C.1 CR-16, CR-17 + §C.7 Interactions Matrix:*

**PostProcessStack subscriber** — PostProcessStack is autoload slot 6, connects to `Events.setting_changed` in its own `_ready()` (before SettingsService fires the burst at slot 10):

```gdscript
# In PostProcessStack._ready():
Events.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category != &"accessibility": return
    match name:
        &"damage_flash_enabled":
            if value is bool:
                set_glow_intensity(1.0 if value else 0.0)
        # NO else: branch — forward-compat per FP-6
```

**HUD Core subscriber** — HUD Core is a scene-tree node (not an autoload). It connects to `setting_changed` in its own `_ready()`. Because HUD Core's `_ready()` runs AFTER all autoloads' `_ready()` (including SettingsService's burst), HUD Core must NOT rely on receiving the burst. Instead, it uses the Consumer Default Strategy:

```gdscript
# In HUDCore._ready():
const DEFAULT_DAMAGE_FLASH_ENABLED: bool = SettingsDefaults.DAMAGE_FLASH_ENABLED  # true

var _damage_flash_enabled: bool = DEFAULT_DAMAGE_FLASH_ENABLED  # fallback until setting_changed fires
Events.setting_changed.connect(_on_setting_changed)
# Note: burst has already fired before HUDCore._ready() runs.
# HUDCore queries current value via SettingsService.get_value() post-ready if needed.

func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category != &"accessibility": return
    match name:
        &"damage_flash_enabled":
            if value is bool:
                _damage_flash_enabled = value
        &"damage_flash_cooldown_ms":
            if value is int or value is float:
                _damage_flash_cooldown_ms = int(value)
```

**Combat subscriber** — same pattern as HUD Core. Combat is autoload slot 7, so it DOES receive the burst synchronously:

```gdscript
# In CombatSystemNode._ready():
Events.setting_changed.connect(_on_setting_changed)
# Combat IS at slot 7 — will receive burst synchronously from SettingsService at slot 10.

func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category != &"accessibility": return
    match name:
        &"damage_flash_enabled":
            if value is bool:
                _ehf_suppressed = not value  # true when damage_flash_enabled is false
```

**Load-time clamp for `damage_flash_cooldown_ms`** — in `SettingsService._load_settings()`:

```gdscript
const DAMAGE_FLASH_COOLDOWN_MS_FLOOR: int = 333  # WCAG 2.3.1 ceiling — non-negotiable

var cooldown: Variant = _cfg.get_value("accessibility", "damage_flash_cooldown_ms",
    SettingsDefaults.DAMAGE_FLASH_COOLDOWN_MS)
if cooldown is int or cooldown is float:
    var clamped := max(int(cooldown), DAMAGE_FLASH_COOLDOWN_MS_FLOOR)
    if clamped != int(cooldown):
        _cfg.set_value("accessibility", "damage_flash_cooldown_ms", clamped)
        push_warning("[Settings] WARN: damage_flash_cooldown_ms %d clamped to %d" % [int(cooldown), clamped])
else:
    _cfg.set_value("accessibility", "damage_flash_cooldown_ms", DAMAGE_FLASH_COOLDOWN_MS_FLOOR)
    push_warning("[Settings] WARN: damage_flash_cooldown_ms wrong type; defaulted to 333")
```

Write-back after clamp (self-heal) is a `ConfigFile.save()` call on the same path. Self-heal saves are bundled into the normal `_load_settings()` completion save to minimize I/O calls.

**`set_glow_intensity()` API note**: This is a project-defined method on `PostProcessStack`. Verify its signature against `production/epics/post-process-stack/EPIC.md` before calling. The underlying mechanism (setting `WorldEnvironment.environment.glow_enabled`, `glow_intensity`, or a Compositor uniform) is owned by the Post-Process Stack epic — this story only calls the public API.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: HSlider `min_value = 333` UI-level clamp on `damage_flash_cooldown_ms` widget (AC-SA-5.3 upgraded to BLOCKING — deferred to panel UI story)
- Story 005: AccessKit `accessibility_role`, `accessibility_name`, `accessibility_description` on the cooldown slider (TR-SET-012 — blocked on ADR-0004 Gate 1)
- Story 006: `subtitles_enabled` default-write enforcement and subtitle settings cluster
- Post-VS: muzzle flash / screen-shake / bloom-on-hit WCAG 2.3.1 gate per OQ-SA-9 (Combat GDD coord — max sustained RPM verification)

---

## QA Test Cases

*Solo mode — no QA-lead gate. Test cases written by story author per GDD ACs.*

**AC-1 — load-time clamp for damage_flash_cooldown_ms**
- Given: a ConfigFile fixture with `accessibility.damage_flash_cooldown_ms = 100` (sub-floor)
- When: `SettingsService._load_settings()` processes the fixture
- Then: the in-memory value is 333; the self-healed value written back to the fixture file is 333; the value emitted via `setting_changed` during burst is 333
- Edge cases: `damage_flash_cooldown_ms = 333` (exactly at floor) → no clamp needed, no write-back, no warning; `damage_flash_cooldown_ms = "quick"` (wrong type) → substituted with default 333, warning logged

**AC-3 — kill-switch gate on HUD + Combat subscriber state flags**
- Given: isolated test doubles for HUD Core and Combat that expose their suppression flags
- When: `Events.setting_changed.emit(&"accessibility", &"damage_flash_enabled", false)` fires
- Then: HUD Core's `_damage_flash_enabled` is `false`; Combat's `_ehf_suppressed` is `true`
- Edge cases: `value` is passed as `int(0)` instead of `bool(false)` (type mismatch per CR-7 type guard) → type guard catches; suppression flag NOT set; warning logged

**AC-4 — PostProcessStack handshake at boot (integration)**
- Given: PostProcessStack subscriber connected; `settings.cfg` fixture contains `accessibility.damage_flash_enabled = false`
- When: SettingsService boot burst fires
- Then: `set_glow_intensity` was called with `0.0` exactly once during the burst frame
- Edge cases: `settings.cfg` missing `damage_flash_enabled` key → burst emits no `damage_flash_enabled` event; PostProcessStack uses its Consumer Default Strategy (default `true` → `set_glow_intensity(1.0)` from its own `_ready()` initialization, not from the burst)

**AC-7 + AC-8 — consumer guard source inspection**
- Given: source files for `post_process_stack.gd`, `hud_core.gd`, `combat_system_node.gd`
- When: `_on_setting_changed` function body inspected
- Then: first statement in each is `if category != &"accessibility": return`; no `else:` in any `match name:` block
- Edge cases: IDE auto-formatter wraps `if` across two lines — grep must handle multi-line patterns

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/settings/photosensitivity_floor_test.gd` — must exist and pass (AC-1, AC-6)
- `tests/integration/settings/photosensitivity_kill_switch_test.gd` — must exist and pass (AC-3, AC-4, AC-5)
- Existing `tests/unit/settings/forbidden_patterns_ci_test.gd` updated for AC-7 + AC-8 consumer guard checks

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (SettingsService scaffold + `_write_key()` + load-time clamp infrastructure) must be DONE
- Depends on: Story 002 (boot burst fires `setting_changed` for accessibility keys) must be DONE
- Depends on: Post-Process Stack epic (must expose `PostProcessStack.set_glow_intensity()` public API with known signature)
- Unlocks: Story 004 (audio integration — same subscriber pattern, different category)
- Unlocks: Story 005 (panel UI — UI-level `min_value = 333` clamp on the cooldown slider widget; AC-SA-5.3 BLOCKING)
