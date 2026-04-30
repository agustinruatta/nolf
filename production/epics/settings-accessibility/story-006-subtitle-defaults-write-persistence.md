# Story 006: Subtitle defaults write + subtitle settings persistence

> **Epic**: Settings & Accessibility
> **Status**: Ready
> **Layer**: Polish (Day-1 HARD MVP DEP — captions-default-on per WCAG SC 1.2.2 / CR-23; subtitle cluster keys written at MVP, consumed by D&S at VS)
> **Type**: Logic
> **Estimate**: 2-3 hours (S-M — `settings_defaults.gd` const additions + SettingsService load-time validation + CI gate + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/settings-accessibility.md`
**Requirement**: TR-SET-009
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-SET-009**: `accessibility.subtitles_enabled`, `subtitle_size_scale`, `subtitle_background`, `subtitle_speaker_labels`, `subtitle_line_spacing_scale`, `subtitle_letter_spacing_em` all persist via `user://settings.cfg` per ADR-0003.

**ADR Governing Implementation**: ADR-0002 (Signal Bus — burst emits subtitle keys at boot via `setting_changed`), ADR-0003 (settings.cfg separate from SaveGame), ADR-0004 (UI Framework — subtitle cluster visible in `AccessibilitySubScreen.tscn` built in Story 005; full styling UI is post-VS), ADR-0007 (SettingsService autoload slot 10 — burst fires subtitle keys before D&S consumer `_ready()` runs)

**ADR Decision Summary**: Per GDD CR-23 (revised 2026-04-26 PM), the subtitle cluster is a two-contract system:

1. **MVP-write contract (this story)**: SettingsService writes all six subtitle keys to `settings.cfg` at first launch using defaults from `settings_defaults.gd`. `accessibility.subtitles_enabled` MUST default to `true` — this is an opt-OUT default per WCAG SC 1.2.2, an explicit Creative Director adjudication, and the second exception to the "modern accommodations opt-IN" rule (alongside `crosshair_enabled`). This default-write is enforced at the source level via CI gate so no future revision can accidentally flip it to `false`. The write happens whether or not the Dialogue & Subtitles consumer has shipped.

2. **VS-consume contract (D&S Story 004)**: Dialogue & Subtitles's subtitle renderer subscribes to `setting_changed("accessibility", "subtitles_enabled", v)` and `setting_changed("accessibility", "subtitle_size_scale", v)` / `subtitle_background`. D&S consumes these values when its stories ship at VS; this story only guarantees they are present in `settings.cfg` and in the boot burst by then.

**D&S consumer bootstrap**: `DialogueAndSubtitles` is a scene-tree node (not autoload per ADR-0007 — slots full). It cannot receive the boot burst from SettingsService at slot 10. D&S uses the Consumer Default Strategy: `_subtitles_enabled` initializes to `SettingsDefaults.SUBTITLES_ENABLED` (hardcoded `true`) and then updates on `setting_changed`. This means even without the burst, D&S defaults correctly on first launch. The burst arriving at slot 10 cannot reach non-autoload scene nodes — confirmed by Story 002 Implementation Notes ("Non-autoload consumers initialized after boot receive no retroactive burst and must rely on their hardcoded constants"). D&S queries `SettingsService.get_value(&"accessibility", &"subtitles_enabled")` at its own `_ready()` post-boot for the authoritative value. This story must ensure `get_value()` returns the correct persisted value before D&S calls it.

**Subtitle cluster keys — full list per GDD §G.9 table row 3–8**:

| Key | Default | Type | WCAG Reference |
|-----|---------|------|----------------|
| `subtitles_enabled` | `true` | bool | SC 1.2.2 — opt-OUT (captions-default-on) |
| `subtitle_size_scale` | `1.0` | float (enum: 0.8 S / 1.0 M / 1.5 L / 2.0 XL) | SC 1.4.4 — reflow/text resize |
| `subtitle_background` | `"scrim"` | StringName (enum: `"none"` / `"scrim"` / `"opaque"`) | contrast / readability |
| `subtitle_speaker_labels` | `true` | bool | SC 1.2.2 — speaker identification |
| `subtitle_line_spacing_scale` | `1.0` | float [1.0, 1.5] | SC 1.4.12 — text spacing |
| `subtitle_letter_spacing_em` | `0.0` | float [0.0, 0.12] | SC 1.4.12 — text spacing |

Note: `subtitle_size_scale` and `subtitle_line_spacing_scale` are stored as float in `settings.cfg` despite the UI presenting a discrete enum picker (four presets for size, continuous slider for spacing). The stored float is the authoritative value; the UI widget maps to it. `subtitle_background` is stored as a StringName but ConfigFile stores it as a String — on read, reconstitute via `StringName(loaded_string)`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ConfigFile` type storage for StringName: ConfigFile has no native StringName type — it stores String. On `_write_key()`, `StringName` values are stored as `String`. On `_load_settings()`, String values that correspond to StringName keys are reconstituted via `StringName(str_value)`. This is the same pattern documented in Story 001 AC-7 round-trip fidelity notes. The existing `SettingsService._write_key()` and `_load_settings()` infrastructure handles this correctly per Story 001's type-guard pattern — no new engine API needed.

**Control Manifest Rules (Polish — Foundation sub-rules apply)**:
- Required: `accessibility.subtitles_enabled = true` is the only valid first-launch write — CI gate blocks any path that writes `false` (AC-SA-5.7b, GDD CR-23) — source: GDD CR-23 revised 2026-04-26 PM
- Required: All six subtitle keys present in `settings_defaults.gd` as `const` (CR-10 pure-const file) — source: GDD §G.9 + Story 001 Implementation Notes
- Required: `subtitle_background` stored as `String`, read back via `StringName(loaded_string)` — source: Story 001 AC-7 / TR-SET-009 + GDD type notes
- Required: `subtitle_size_scale` clamped to {0.8, 1.0, 1.5, 2.0} discrete set on load (Cluster B self-heal — invalid stored float → nearest valid preset or default `1.0`) — source: GDD §C.1 CR-7 + Cluster B
- Required: `subtitle_line_spacing_scale` clamped to [1.0, 1.5] on load (Cluster B self-heal) — source: GDD §C.1 CR-7 + WCAG SC 1.4.12 floor
- Required: `subtitle_letter_spacing_em` clamped to [0.0, 0.12] on load (Cluster B self-heal) — source: GDD §C.1 CR-7 + WCAG SC 1.4.12 floor
- Forbidden: `accessibility.subtitles_enabled = false` in `settings_defaults.gd` or any first-launch write path (AC-SA-5.7b CI gate) — pattern `subtitles_default_off` (FP extension per GDD CR-23)
- Forbidden: subtitle cluster keys written into `SaveGame` or any `*_state.gd` file — pattern `settings_in_save_slot` (FP-4, ADR-0003 IG 10, TR-SET-014)

---

## Acceptance Criteria

*From GDD `design/gdd/settings-accessibility.md` §H.1, §H.5, §H.9 + AC-SA-5.7a/b, scoped to this story:*

- [ ] **AC-1** (TR-SET-009, first-launch defaults write): GIVEN `user://settings.cfg` is absent on first launch, WHEN SettingsService writes defaults at `_ready()`, THEN all six subtitle cluster keys (`subtitles_enabled`, `subtitle_size_scale`, `subtitle_background`, `subtitle_speaker_labels`, `subtitle_line_spacing_scale`, `subtitle_letter_spacing_em`) are present in the written `settings.cfg` with their correct default values as listed in the GDD §G.9 table. (GDD AC-SA-1.1 extended to subtitle cluster)

- [ ] **AC-2** (TR-SET-009 + AC-SA-5.7a — captions-default-on BLOCKING WCAG SC 1.2.2): GIVEN `accessibility.subtitles_enabled` key is absent from `settings.cfg` on first launch, WHEN SettingsService writes defaults, THEN `accessibility.subtitles_enabled` is written as `true` — it is NEVER written as `false` on first launch regardless of whether the Dialogue & Subtitles consumer has shipped. (GDD CR-23 revised 2026-04-26 PM — Day-1 HARD MVP DEP)

- [ ] **AC-3** (TR-SET-009 + AC-SA-5.7b — CI gate BLOCKING): GIVEN the full GDScript source tree, WHEN CI runs grep for any literal `subtitles_enabled = false` or `SUBTITLES_ENABLED := false` in `settings_defaults.gd` or any file under `src/core/settings/`, THEN zero matches are found — the default-write of `true` is locked at the source level. (GDD AC-SA-5.7b)

- [ ] **AC-4** (TR-SET-009, persistence round-trip): GIVEN `settings.cfg` contains the six subtitle cluster keys with non-default values (`subtitles_enabled = false`, `subtitle_size_scale = 1.5`, `subtitle_background = "opaque"`, `subtitle_speaker_labels = false`, `subtitle_line_spacing_scale = 1.2`, `subtitle_letter_spacing_em = 0.08`), WHEN SettingsService loads the file and the in-memory cfg is inspected, THEN each loaded value matches the stored value with correct types — `subtitles_enabled` is `bool`, `subtitle_size_scale` is `float`, `subtitle_background` is `StringName`, `subtitle_speaker_labels` is `bool`, `subtitle_line_spacing_scale` is `float`, `subtitle_letter_spacing_em` is `float`. (GDD AC-SA-2.2 extended to subtitle cluster / TR-SET-009)

- [ ] **AC-5** (TR-SET-009, burst emit): GIVEN a valid `settings.cfg` containing the subtitle cluster keys, WHEN SettingsService's `_emit_burst()` runs (Story 002), THEN exactly six `setting_changed("accessibility", key, value)` signals are emitted for the subtitle cluster keys, one per key, as part of the normal accessibility-category burst. Each emitted value matches the persisted value. (GDD AC-SA-1.4 + Story 002 AC-1)

- [ ] **AC-6** (Cluster B self-heal — `subtitle_size_scale`): GIVEN a manually-edited `settings.cfg` sets `accessibility.subtitle_size_scale = 0.5` (outside the valid discrete preset set {0.8, 1.0, 1.5, 2.0}), WHEN SettingsService loads the file, THEN the loaded value is replaced with the default `1.0`, written back to disk (self-heal), and the value emitted in `setting_changed` is `1.0`. A `[Settings] WARN:` line is logged. (GDD CR-7 Cluster B self-heal pattern)

- [ ] **AC-7** (Cluster B self-heal — `subtitle_line_spacing_scale`): GIVEN a manually-edited `settings.cfg` sets `accessibility.subtitle_line_spacing_scale = 2.5` (above WCAG SC 1.4.12 ceiling of 1.5), WHEN SettingsService loads the file, THEN the value is clamped to `1.5` (ceiling, not default), written back to disk, and the clamped value is emitted. `subtitle_letter_spacing_em = 0.15` (above 0.12 em ceiling) is similarly clamped to `0.12`. (GDD CR-7 Cluster B + WCAG SC 1.4.12 invariant)

- [ ] **AC-8** (TR-SET-009, `subtitle_background` StringName reconstitution): GIVEN a `settings.cfg` stores `accessibility.subtitle_background = "opaque"` (stored as String), WHEN SettingsService loads the key via `_load_settings()`, THEN the in-memory value is `StringName("opaque")` (reconstituted as StringName, not raw String), and the value emitted via `setting_changed` is also `StringName("opaque")`. (Story 001 AC-7 pattern / TR-SET-009 type contract)

- [ ] **AC-9** (TR-SET-009, Restore Defaults — subtitle cluster NOT preserved): GIVEN the player invokes Restore Defaults (Story 002 / Story 005), WHEN `_restore_defaults()` completes, THEN all six subtitle cluster keys are reset to their `settings_defaults.gd` values — unlike the photosensitivity safety cluster (Story 002 AC-9), the subtitle cluster is NOT preserved across Restore Defaults. `subtitles_enabled` is reset to `true` (the default, not to whatever the player had set). (GDD CR-25 — only photosensitivity cluster is preserved; subtitle cluster resets to defaults)

- [ ] **AC-10** (TR-SET-014 + ADR-0003, subtitle keys not in SaveGame): GIVEN the full GDScript source tree under `src/`, WHEN CI runs grep for any subtitle cluster key literal (`"subtitles_enabled"`, `"subtitle_size_scale"`, `"subtitle_background"`, `"subtitle_speaker_labels"`, `"subtitle_line_spacing_scale"`, `"subtitle_letter_spacing_em"`) inside any file matching `*save_game*` or `*_state.gd`, THEN zero matches are found. (FP-4 / ADR-0003 IG 10 / TR-SET-014)

---

## Implementation Notes

*Derived from GDD §C.2 key catalogue + §G.9 table rows 3–8 + Story 001 Implementation Notes + ADR-0003 §IG 10:*

**`settings_defaults.gd` additions** — add to the `# accessibility category` block (per Story 001 Implementation Notes, the file already contains photosensitivity and crosshair constants; append subtitle cluster below `CLOCK_TICK_ENABLED`):

```gdscript
# subtitle cluster — all keys MVP-write, VS-consume (GDD CR-23 revised 2026-04-26 PM)
# WCAG SC 1.2.2: captions-default-on (opt-OUT). NEVER change SUBTITLES_ENABLED to false.
const SUBTITLES_ENABLED := true                     # Day-1 HARD MVP DEP — WCAG SC 1.2.2
const SUBTITLE_SIZE_SCALE := 1.0                    # M preset — WCAG SC 1.4.4
const SUBTITLE_BACKGROUND := &"scrim"               # StringName — stored as String in ConfigFile
const SUBTITLE_SPEAKER_LABELS := true               # AC-DS-12.4 / CR-DS-16 identity cue
const SUBTITLE_LINE_SPACING_SCALE := 1.0            # WCAG SC 1.4.12 — range [1.0, 1.5]
const SUBTITLE_LETTER_SPACING_EM := 0.0             # WCAG SC 1.4.12 — range [0.0, 0.12] em
```

The comment on `SUBTITLES_ENABLED` is load-bearing: it documents the CI-gate intent in-source so future developers cannot remove the `true` default without also finding and removing the CI gate.

**`SettingsService._load_settings()` additions** — extend the existing accessibility-category load path (Story 003 already handles `damage_flash_cooldown_ms` clamp) with subtitle cluster validation:

```gdscript
# Subtitle cluster validation (TR-SET-009 + Cluster B self-heal)
# --- subtitles_enabled: no clamp needed (bool); type-guard only
var subs_en: Variant = _cfg.get_value(&"accessibility", &"subtitles_enabled",
    SettingsDefaults.SUBTITLES_ENABLED)
if not (subs_en is bool):
    _cfg.set_value(&"accessibility", &"subtitles_enabled", SettingsDefaults.SUBTITLES_ENABLED)
    push_warning("[Settings] WARN: subtitles_enabled wrong type; defaulted to true")

# --- subtitle_size_scale: discrete preset validation {0.8, 1.0, 1.5, 2.0}
const SUBTITLE_SIZE_VALID: Array[float] = [0.8, 1.0, 1.5, 2.0]
var size_scale: Variant = _cfg.get_value(&"accessibility", &"subtitle_size_scale",
    SettingsDefaults.SUBTITLE_SIZE_SCALE)
if not (size_scale is float or size_scale is int):
    size_scale = SettingsDefaults.SUBTITLE_SIZE_SCALE
    push_warning("[Settings] WARN: subtitle_size_scale wrong type; defaulted to 1.0")
elif not (float(size_scale) in SUBTITLE_SIZE_VALID):
    size_scale = SettingsDefaults.SUBTITLE_SIZE_SCALE
    push_warning("[Settings] WARN: subtitle_size_scale %s not valid preset; defaulted to 1.0"
        % str(size_scale))
_cfg.set_value(&"accessibility", &"subtitle_size_scale", float(size_scale))

# --- subtitle_background: enum validation {"none", "scrim", "opaque"}
const SUBTITLE_BG_VALID: Array[String] = ["none", "scrim", "opaque"]
var bg: Variant = _cfg.get_value(&"accessibility", &"subtitle_background",
    String(SettingsDefaults.SUBTITLE_BACKGROUND))
if not (bg is String) or not (str(bg) in SUBTITLE_BG_VALID):
    bg = String(SettingsDefaults.SUBTITLE_BACKGROUND)
    push_warning("[Settings] WARN: subtitle_background invalid; defaulted to scrim")
_cfg.set_value(&"accessibility", &"subtitle_background", str(bg))
# Reconstitute as StringName when emitting in burst (see _emit_burst note below)

# --- subtitle_line_spacing_scale: clamp [1.0, 1.5] per WCAG SC 1.4.12
var lss: Variant = _cfg.get_value(&"accessibility", &"subtitle_line_spacing_scale",
    SettingsDefaults.SUBTITLE_LINE_SPACING_SCALE)
if not (lss is float or lss is int):
    lss = SettingsDefaults.SUBTITLE_LINE_SPACING_SCALE
    push_warning("[Settings] WARN: subtitle_line_spacing_scale wrong type; defaulted to 1.0")
else:
    var clamped_lss := clamp(float(lss), 1.0, 1.5)
    if clamped_lss != float(lss):
        push_warning("[Settings] WARN: subtitle_line_spacing_scale %f clamped to %f"
            % [float(lss), clamped_lss])
    lss = clamped_lss
_cfg.set_value(&"accessibility", &"subtitle_line_spacing_scale", float(lss))

# --- subtitle_letter_spacing_em: clamp [0.0, 0.12] per WCAG SC 1.4.12
var lem: Variant = _cfg.get_value(&"accessibility", &"subtitle_letter_spacing_em",
    SettingsDefaults.SUBTITLE_LETTER_SPACING_EM)
if not (lem is float or lem is int):
    lem = SettingsDefaults.SUBTITLE_LETTER_SPACING_EM
    push_warning("[Settings] WARN: subtitle_letter_spacing_em wrong type; defaulted to 0.0")
else:
    var clamped_lem := clamp(float(lem), 0.0, 0.12)
    if clamped_lem != float(lem):
        push_warning("[Settings] WARN: subtitle_letter_spacing_em %f clamped to %f"
            % [float(lem), clamped_lem])
    lem = clamped_lem
_cfg.set_value(&"accessibility", &"subtitle_letter_spacing_em", float(lem))
```

**`subtitle_background` StringName reconstitution in burst** — `_emit_burst()` reads raw cfg values via `_cfg.get_value(category, key)`. Because `subtitle_background` is stored as `String` in ConfigFile, the burst emits a `String`. D&S's `_on_setting_changed` handler must tolerate both `String` and `StringName` inputs (or the burst emits should reconstitute). Preferred: reconstitute in `_emit_burst()` with a targeted override for this key:

```gdscript
# In _emit_burst(), after retrieving the value but before emitting:
# subtitle_background stored as String; reconstitute to StringName for type consistency
if category == &"accessibility" and key == "subtitle_background" and value is String:
    value = StringName(value)
```

This is the only subtitle-cluster key requiring special reconstitution; all others have native-matching types.

Alternatively, add a `_STRINGNAME_KEYS: Array[String]` const to `SettingsService` listing all keys stored as String but consumed as StringName, and apply reconstitution generically in `_emit_burst()`. This is the more maintainable pattern if additional StringName keys are added in the future (e.g., `subtitle_background` is currently the only one but post-VS styling options may add more). Decision for implementor — document the chosen pattern in a code comment.

**`subtitle_speaker_labels` bool type-guard** — same pattern as `subtitles_enabled`: validate type is `bool`, substitute default on mismatch. No range clamp needed.

**Restore Defaults behaviour** — `_restore_defaults()` (Story 002) resets all non-photosensitivity-cluster keys to `settings_defaults.gd` values. The subtitle cluster IS reset (it is not safety-critical like photosensitivity). After restore, `subtitles_enabled` returns to `true` (the default). The burst re-emits the defaults for all six subtitle keys via the existing Restore Defaults re-burst path (Story 002 — without re-emitting `settings_loaded` per the one-shot guard).

**D&S subscribe-and-query pattern** (informational — not implemented here, D&S Story 004 owns this):

```gdscript
# In DialogueAndSubtitles._ready():
# Consumer Default Strategy: initialize from SettingsDefaults, not from get_value() in _ready()
var _subtitles_enabled: bool = SettingsDefaults.SUBTITLES_ENABLED  # true — safe before burst
# D&S is NOT an autoload so it misses the boot burst from SettingsService at slot 10.
# Query authoritative post-boot value immediately:
if SettingsService != null:
    var v = SettingsService.get_value(&"accessibility", &"subtitles_enabled")
    if v is bool:
        _subtitles_enabled = v
Events.setting_changed.connect(_on_setting_changed)
```

This is the correct D&S bootstrap. It does NOT call `SettingsService.get_value()` for initial state in `_ready()` prior to the burst (which would be FP-3 if called before autoloads are ready) — instead it calls it after SettingsService's `_ready()` has completed (SettingsService is autoload slot 10; by the time any scene-tree node's `_ready()` fires, all autoloads including SettingsService have completed). This is safe. Document this pattern in D&S Story 004 at implementation time.

**Files to modify** (no new files required — all additions extend Story 001's scaffold):

```
src/core/settings/settings_defaults.gd    — add 6 subtitle const declarations
src/core/settings/settings_service.gd     — extend _load_settings() + _emit_burst() reconstitution
tests/unit/settings/                      — new test file (see Test Evidence section)
```

---

## Out of Scope

*Post-VS deferrals and neighbouring story boundaries — do not implement here:*

- D&S Story 004: Subtitle renderer consuming `subtitles_enabled` / `subtitle_size_scale` / `subtitle_background` from `setting_changed` — the VS-consume contract; this story only guarantees the keys are written and burst-emitted correctly
- D&S Story 004: `subtitle_speaker_labels` full rendering (anonymous-context PATROL_AMBIENT lines render unlabeled regardless per D&S CR-DS-15; speaker labels are a VS-consume D&S concern)
- Story 005: Subtitle cluster UI widgets in `AccessibilitySubScreen.tscn` — the four scale-preset picker, background radio group, spacing slider wiring (post-VS per GDD §VS Scope "subtitles styling options" deferral); Story 005 out-of-scope note already references this
- Post-VS: Full subtitle styling options — per-section `subtitle_background = opaque` overrides (AC-DS-12.5), `subtitle_size_scale = XL` accessibility preset, WCAG SC 1.4.12 word-spacing (unaddressed post-MVP), colorblind mode caption palette
- Post-VS: `subtitle_line_spacing_scale` and `subtitle_letter_spacing_em` UI surface in Settings panel — keys are written and persisted at MVP; UI sliders are post-VS per GDD §VS Scope deferral

---

## QA Test Cases

*Solo mode — no QA-lead gate. Test cases written by story author per GDD ACs.*

**AC-1 — first-launch subtitle cluster defaults write**
- Given: `user://settings.cfg` absent; `SettingsService._ready()` mock setup via headless unit test with mock ConfigFile path
- When: `_load_settings()` executes
- Then: all six subtitle cluster keys present in the written cfg; values match `settings_defaults.gd` constants exactly; `subtitles_enabled == true`, `subtitle_size_scale == 1.0`, `subtitle_background == "scrim"` (String), `subtitle_speaker_labels == true`, `subtitle_line_spacing_scale == 1.0`, `subtitle_letter_spacing_em == 0.0`
- Edge cases: cfg absent but filesystem read-only → SettingsService uses in-memory defaults, logs error, no crash; `subtitles_enabled` in-memory value is still `true`

**AC-2 + AC-3 — captions-default-on CI gate**
- Given: `settings_defaults.gd` source file
- When: CI grep runs `SUBTITLES_ENABLED.*false\|subtitles_enabled.*=.*false` across all files in `src/core/settings/`
- Then: zero matches — `SUBTITLES_ENABLED` is `true` in `settings_defaults.gd` and no first-launch path overwrites it with `false`
- Edge cases: a developer adds `subtitles_enabled` to a SaveGame restore callback — caught by AC-10 gate; a developer renames the constant — grep gate must match the pattern not the constant name (test must grep both `settings_defaults.gd` content and `_load_settings()` flow for any `false` assignment to the key)

**AC-4 — persistence round-trip for all six keys**
- Given: a ConfigFile fixture with non-default subtitle cluster values (`subtitles_enabled = false`, `subtitle_size_scale = 1.5`, `subtitle_background = "opaque"`, `subtitle_speaker_labels = false`, `subtitle_line_spacing_scale = 1.3`, `subtitle_letter_spacing_em = 0.08`)
- When: `SettingsService._load_settings()` processes the fixture
- Then: `get_value(&"accessibility", &"subtitles_enabled") == false` (bool); `get_value(&"accessibility", &"subtitle_size_scale") == 1.5` (float); `get_value(&"accessibility", &"subtitle_background") == "opaque"` (String in cfg; StringName when emitted); `get_value(&"accessibility", &"subtitle_speaker_labels") == false` (bool); `get_value(&"accessibility", &"subtitle_line_spacing_scale") == 1.3` (float); `get_value(&"accessibility", &"subtitle_letter_spacing_em") == 0.08` (float)
- Edge cases: each key present with correct type but no validation violation → no self-heal write-back; all six values returned verbatim

**AC-5 — subtitle cluster keys in burst emit**
- Given: a ConfigFile fixture with all six subtitle keys at non-default values (same as AC-4)
- When: `_emit_burst()` runs
- Then: six `setting_changed(&"accessibility", key, value)` emits occur for the subtitle cluster keys; emitted `subtitle_background` value is `StringName("opaque")` (reconstituted); all other emitted values match the fixture exactly
- Edge cases: `subtitle_background` stored as String in cfg → burst emits StringName (reconstitution applied); subscriber receiving the emit gets StringName, not String

**AC-6 — `subtitle_size_scale` Cluster B self-heal**
- Given: cfg fixture with `accessibility.subtitle_size_scale = 0.5` (not in valid preset set)
- When: `_load_settings()` processes the fixture
- Then: in-memory value is `1.0` (default); written-back value in cfg is `1.0`; one `[Settings] WARN:` logged; emitted burst value is `1.0`
- Edge cases: `subtitle_size_scale = 0.8` (valid preset) → no self-heal; `subtitle_size_scale = 1.5` (valid preset) → no self-heal; `subtitle_size_scale = "medium"` (wrong type) → same self-heal path, default substituted

**AC-7 — `subtitle_line_spacing_scale` + `subtitle_letter_spacing_em` WCAG SC 1.4.12 clamps**
- Given: cfg fixture with `subtitle_line_spacing_scale = 2.5` (above 1.5 ceiling) and `subtitle_letter_spacing_em = 0.15` (above 0.12 ceiling)
- When: `_load_settings()` processes the fixture
- Then: `subtitle_line_spacing_scale` in-memory and written-back is `1.5` (ceiling, not default `1.0`); `subtitle_letter_spacing_em` in-memory and written-back is `0.12` (ceiling); one `[Settings] WARN:` logged per clamped key; burst emits clamped values
- Edge cases: `subtitle_line_spacing_scale = 0.5` (below 1.0 floor) → clamped to `1.0`; `subtitle_letter_spacing_em = -0.01` (negative, below 0.0 floor) → clamped to `0.0`

**AC-9 — Restore Defaults resets subtitle cluster**
- Given: subtitle cluster set to non-defaults (`subtitles_enabled = false`, `subtitle_size_scale = 2.0`, etc.) before Restore Defaults
- When: `_restore_defaults()` is called
- Then: all six subtitle cluster keys reset to `settings_defaults.gd` values; `subtitles_enabled` is `true` after reset; photosensitivity cluster is unchanged (Story 002 AC-9 invariant unaffected)
- Edge cases: Restore Defaults triggers a Restore burst; subtitle keys emitted with default values; `settings_loaded` NOT re-emitted (one-shot guard per Story 002)

**AC-10 — subtitle keys not in SaveGame (CI gate)**
- Given: all `*save_game*` and `*_state.gd` files in `src/`
- When: CI grep runs for each subtitle key literal string
- Then: zero matches in any SaveGame-domain file
- Edge cases: test code in `tests/` that directly touches subtitle key literals for fixture setup — permissible only if the test is a `settings_*` unit test (fixture isolation rule per Story 001 AC-3 pattern)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/settings/subtitle_defaults_test.gd` — must exist and pass (AC-1, AC-4, AC-5, AC-6, AC-7, AC-9)
- `tests/unit/settings/forbidden_patterns_ci_test.gd` — updated to add AC-2 / AC-3 (captions-default-on grep gate) and AC-10 (subtitle keys not in SaveGame); same test file as Stories 001 and 003 (cumulative CI gate file)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (SettingsService scaffold + `settings_defaults.gd` const pattern + `_load_settings()` infrastructure + `_write_key()` + type-guard self-heal pattern) must be DONE
- Depends on: Story 002 (boot burst `_emit_burst()` loop + Restore Defaults `_restore_defaults()` implementation — subtitle cluster keys ride the existing burst, no new emit path needed) must be DONE
- Unlocks: D&S Story 004 (subtitle renderer — `setting_changed("accessibility", "subtitles_enabled", v)` burst is now guaranteed present; `SettingsService.get_value()` returns correct value at D&S `_ready()` time)
- Unlocks: D&S Story 005 (Plaza VS integration smoke — `Settings.subtitles_enabled = true` default is verified to be present; captions render on first run without player configuration action)
- Unlocks: Story 005 Accessibility sub-screen (subtitle cluster widget wiring — `AccessibilitySubScreen.tscn` can connect `drag_ended` / `toggled` to the subtitle keys; the logic layer is complete before the UI story builds on it; however Story 005 is BLOCKED on ADR-0004 Gate 1)

---

## Open Questions

**OQ-006-1 [ADVISORY — post-VS]**: `subtitle_size_scale` discrete preset vs. continuous float. The GDD §G.9 specifies four discrete presets (0.8 S / 1.0 M / 1.5 L / 2.0 XL) but the key is stored as `float`. The Cluster B self-heal in this story validates against the four known presets. If a future post-VS design decision allows a continuous slider (beyond the four presets), the self-heal validation must be relaxed to a range clamp `[0.5, 2.5]` instead. This story implements the restrictive preset-validation per current GDD spec; document the decision in `settings_defaults.gd` comments at implementation time.

**OQ-006-2 [ADVISORY — D&S coord]**: D&S Story 004 shows `subtitle_size_scale` and `subtitle_background` consumed immediately on `setting_changed` (live preview during Settings panel interaction). This story only guarantees the keys are written and burst-emitted. D&S Story 004 must verify that `setting_changed("accessibility", "subtitle_size_scale", 1.5)` (a float) is handled correctly by the renderer's font-size override — no type mismatch between stored float and the enum-picker UI's int index. Coordinate at D&S Story 004 implementation time.

**OQ-006-3 [ADVISORY]**: `subtitle_letter_spacing_em` is stored as a float in `settings.cfg` but represents em units applied via a `Label` theme override. Godot 4.6's `LabelSettings.letter_spacing` property is in pixels, not em. D&S Story 004 must implement the em-to-pixels conversion using the active font size (`font_size_px * subtitle_letter_spacing_em`). This story does not implement the conversion — it only ensures the em value persists correctly in [0.0, 0.12]. No action required here; noted for D&S implementor.
