# res://src/core/settings/settings_service.gd
#
# SettingsService — sole owner of user://settings.cfg (ADR-0003 IG 10) and
# sole publisher of Events.setting_changed per CR-1.
#
# NEVER write settings keys into SaveGame — settings and save slots are
# independent persistence domains. Settings survive new-game; SaveGame is
# wiped by new-game actions.
#
# Autoload registration: line 10 of project.godot [autoload], after
# MissionLevelScripting at line 9 (ADR-0007 §Canonical Registration Table,
# 2026-04-27 amendment). This guarantees every consumer autoload (Events,
# EventLogger, SaveLoad, InputContext, LSS, PostProcessStack, Combat,
# FailureRespawn, MLS) has connected its setting_changed subscriber before
# the boot burst fires from this service's _ready().
#
# Story scope:
#   • SA-001 (this story): ConfigFile load/save round-trip + defaults
#     + sole-publisher infrastructure. No burst yet.
#   • SA-002: _emit_burst() + Events.settings_loaded one-shot + photosensitivity
#     warning flag.
#   • SA-003..006: domain integrations (photosensitivity, audio dB, subtitles).
#
# Forbidden patterns enforced via tests/unit/feature/settings/forbidden_patterns_ci_test.gd:
#   • FP-1: Events.setting_changed.emit(...) outside this file
#   • FP-2: ConfigFile.{load,save}("user://settings.cfg") outside this file
#   • FP-3: SettingsService.get_value() in any consumer's _ready()
#   • FP-4: Any settings key name in SaveGame capture/restore paths

# NOTE: no `class_name SettingsService` — that identifier is reserved by the
# autoload registration in project.godot at line 10. Declaring it here would
# trigger "Class hides an autoload singleton". Consumers reference the live
# autoload as `SettingsService` (the autoload name), not via class lookup.
extends Node

const _SETTINGS_PATH: String = "user://settings.cfg"

## SA-003 / TR-SET-007: WCAG 2.3.1 ceiling is 3 Hz → minimum 333 ms between
## flashes. This floor is non-negotiable safety, not a tuning knob — clamped
## both at load-time (this service) and at the UI widget (Story 005 HSlider
## min_value). Defense in depth: a manually-edited cfg with a sub-333 value
## is healed silently; a UI drag is constrained at the widget.
const DAMAGE_FLASH_COOLDOWN_MS_FLOOR: int = 333

## SA-006 / TR-SET-009: subtitle cluster validation constants. Discrete
## preset set for size scale; enum set for background; WCAG SC 1.4.12 floors
## and ceilings for line + letter spacing.
const SUBTITLE_SIZE_VALID_PRESETS: Array[float] = [0.8, 1.0, 1.5, 2.0]
const SUBTITLE_BG_VALID: Array[String] = ["none", "scrim", "opaque"]
const SUBTITLE_LINE_SPACING_FLOOR: float = 1.0
const SUBTITLE_LINE_SPACING_CEILING: float = 1.5
const SUBTITLE_LETTER_SPACING_FLOOR: float = 0.0
const SUBTITLE_LETTER_SPACING_CEILING: float = 0.12

## SA-006: keys that are stored as String in ConfigFile but consumed as
## StringName by subscribers. Reconstituted to StringName in _emit_burst().
const _STRINGNAME_KEYS: Array[String] = ["subtitle_background"]

## Photosensitivity safety cluster (TR-SET-015) — these three keys NEVER reset
## via Restore Defaults; only deletion of settings.cfg triggers re-warning.
const PHOTOSENSITIVITY_CLUSTER_KEYS: Array[String] = [
	"photosensitivity_warning_dismissed",
	"damage_flash_enabled",
	"damage_flash_cooldown_ms",
]

## In-memory ConfigFile mirror of the on-disk settings.cfg. Read via get_value;
## written via _write_key (write-through to disk on every commit).
var _cfg: ConfigFile = ConfigFile.new()

## True iff settings.cfg lacks accessibility/photosensitivity_warning_dismissed
## (absence — not `false` — signals first launch). Read by Menu System's
## boot-warning modal logic.
var _boot_warning_pending: bool = false

## One-shot guard for Events.settings_loaded — fires exactly once per session.
var _settings_loaded_emitted: bool = false


func _ready() -> void:
	_load_settings()
	_apply_rebinds()
	_emit_burst()


## Load user://settings.cfg if present; otherwise populate from defaults and
## write the file. On load error (corrupted, partial), log one [Settings] ERR
## line, fall back to defaults, and overwrite. AC-5 + AC-6 contract.
func _load_settings() -> void:
	var load_err: int = _cfg.load(_SETTINGS_PATH)
	if load_err == OK:
		_validate_and_heal()
		_check_boot_warning()
		return
	if load_err == ERR_FILE_NOT_FOUND:
		_populate_defaults()
		_save_to_disk()
		_check_boot_warning()
		return
	push_error("[Settings] ERR: failed to load %s (err=%d) — falling back to defaults." % [_SETTINGS_PATH, load_err])
	_cfg = ConfigFile.new()
	_populate_defaults()
	_save_to_disk()
	_check_boot_warning()


## SA-002 / TR-SET-008 / AC-4 + AC-5: photosensitivity warning needs to display
## on first launch. The _signal is the ABSENCE of the key, not the value `false`.
## Why absence: a player who explicitly disables the warning by setting `false`
## still wants the warning suppressed; only a fresh user://settings.cfg (no key
## at all) means they have not seen the disclosure yet.
func _check_boot_warning() -> void:
	_boot_warning_pending = not _cfg.has_section_key(
		String(SettingsDefaults.C_ACCESSIBILITY),
		String(SettingsDefaults.K_PHOTOSENSITIVITY_WARNING_DISMISSED)
	)


## SA-002 / TR-SET-005: emit one Events.setting_changed per stored triple
## (skipping the [controls] section, which is handled by _apply_rebinds), then
## emit Events.settings_loaded once per session. Synchronous dispatch — every
## subscriber must complete inline before settings_loaded fires.
##
## SA-006: keys listed in _STRINGNAME_KEYS are stored as String in ConfigFile
## but reconstituted to StringName before emit, so subscribers receive a
## consistent type. Currently only subtitle_background.
func _emit_burst() -> void:
	for category in _cfg.get_sections():
		if category == String(SettingsDefaults.C_CONTROLS) or category == "controls":
			continue
		for key in _cfg.get_section_keys(category):
			var value: Variant = _cfg.get_value(category, key)
			# SA-006 reconstitution: String → StringName for known StringName keys.
			if key in _STRINGNAME_KEYS and value is String:
				value = StringName(value)
			Events.setting_changed.emit(StringName(category), StringName(key), value)
	if not _settings_loaded_emitted:
		Events.settings_loaded.emit()
		_settings_loaded_emitted = true


## SA-007 stub — full implementation lands in Story 007 (key rebind apply).
## Called between _load_settings() and _emit_burst() per GDD §C.3 boot order.
## The stub is silent at MVP; Story 007 logs a single line + applies InputMap.
func _apply_rebinds() -> void:
	# Intentionally empty — Story 007 owns the InputMap apply path.
	pass


## SA-002 public API for Menu System's photosensitivity warning modal.
## Sets the dismissed flag + persists synchronously. Returns true on disk
## write success, false on I/O failure (Menu System AC-MENU-6.4 contract).
func dismiss_warning() -> bool:
	_boot_warning_pending = false
	_cfg.set_value(
		String(SettingsDefaults.C_ACCESSIBILITY),
		String(SettingsDefaults.K_PHOTOSENSITIVITY_WARNING_DISMISSED),
		true
	)
	var err: int = _cfg.save(_SETTINGS_PATH)
	return err == OK


## SA-002 / TR-SET-015: Restore Defaults preserves the photosensitivity safety
## cluster (3 keys). The cluster MUST survive the reset — only deleting
## user://settings.cfg can re-trigger the warning. Restore re-runs _emit_burst()
## but does NOT re-emit settings_loaded (one-shot per session enforced).
func restore_defaults() -> void:
	# Cache the cluster values before reset.
	var cached_cluster: Dictionary = {}
	for key in PHOTOSENSITIVITY_CLUSTER_KEYS:
		if _cfg.has_section_key(String(SettingsDefaults.C_ACCESSIBILITY), key):
			cached_cluster[key] = _cfg.get_value(String(SettingsDefaults.C_ACCESSIBILITY), key)
	# Reset to defaults.
	_cfg = ConfigFile.new()
	_populate_defaults()
	# Restore cached cluster values (preserves user's photosensitivity choice).
	for key in cached_cluster:
		_cfg.set_value(String(SettingsDefaults.C_ACCESSIBILITY), key, cached_cluster[key])
	_save_to_disk()
	# Re-emit burst (consumers reset to defaults), but settings_loaded stays at
	# its single emission for the session per AC-3 + AC-9 + GDD AC-SA-11.3.
	_emit_burst()


## Populate the in-memory ConfigFile from SettingsDefaults.get_manifest().
## Does not write to disk — caller invokes _save_to_disk() if needed.
func _populate_defaults() -> void:
	var manifest: Dictionary = SettingsDefaults.get_manifest()
	for category: StringName in manifest:
		var entries: Dictionary = manifest[category]
		for key: StringName in entries:
			_cfg.set_value(String(category), String(key), entries[key])


## Per-key type guard (CR-7 pattern): if a loaded value's type doesn't match
## the default's type, substitute the default + write back + log a warning.
## Skips graphics/resolution_scale (no const default; hardware-detected).
func _validate_and_heal() -> void:
	var manifest: Dictionary = SettingsDefaults.get_manifest()
	var healed: bool = false
	for category: StringName in manifest:
		var entries: Dictionary = manifest[category]
		var category_str: String = String(category)
		for key: StringName in entries:
			var key_str: String = String(key)
			var default_value: Variant = entries[key]
			if not _cfg.has_section_key(category_str, key_str):
				_cfg.set_value(category_str, key_str, default_value)
				healed = true
				continue
			var loaded_value: Variant = _cfg.get_value(category_str, key_str)
			if typeof(loaded_value) != typeof(default_value):
				push_warning(
					(
						"[Settings] WARN: type mismatch for %s/%s (got %s, expected %s) — "
						+ "substituting default."
					)
					% [category_str, key_str, type_string(typeof(loaded_value)), type_string(typeof(default_value))]
				)
				_cfg.set_value(category_str, key_str, default_value)
				healed = true
	# SA-003: photosensitivity 333 ms WCAG safety floor — clamp + heal.
	if _heal_damage_flash_cooldown():
		healed = true
	# SA-006: subtitle cluster validation (preset + range + enum healing).
	if _heal_subtitle_cluster():
		healed = true
	if healed:
		_save_to_disk()


## SA-006 / TR-SET-009: validate the subtitle cluster on load. Returns true
## iff any key was healed (caller saves).
##   • subtitle_size_scale → snapped to nearest valid preset {0.8, 1.0, 1.5, 2.0}
##   • subtitle_background → defaulted to "scrim" if not in {"none", "scrim", "opaque"}
##   • subtitle_line_spacing_scale → clamped to [1.0, 1.5] (WCAG SC 1.4.12)
##   • subtitle_letter_spacing_em → clamped to [0.0, 0.12] (WCAG SC 1.4.12)
func _heal_subtitle_cluster() -> bool:
	var section: String = String(SettingsDefaults.C_ACCESSIBILITY)
	var healed: bool = false

	# subtitle_size_scale — discrete preset validation.
	var size_key: String = String(SettingsDefaults.K_SUBTITLE_SIZE_SCALE)
	if _cfg.has_section_key(section, size_key):
		var size_raw: Variant = _cfg.get_value(section, size_key)
		if not (size_raw is float or size_raw is int):
			_cfg.set_value(section, size_key, SettingsDefaults.SUBTITLE_SIZE_SCALE)
			push_warning("[Settings] WARN: subtitle_size_scale wrong type — defaulted to %f." % SettingsDefaults.SUBTITLE_SIZE_SCALE)
			healed = true
		elif not (float(size_raw) in SUBTITLE_SIZE_VALID_PRESETS):
			_cfg.set_value(section, size_key, SettingsDefaults.SUBTITLE_SIZE_SCALE)
			push_warning("[Settings] WARN: subtitle_size_scale %f not a valid preset — defaulted to %f." % [float(size_raw), SettingsDefaults.SUBTITLE_SIZE_SCALE])
			healed = true

	# subtitle_background — enum validation.
	var bg_key: String = String(SettingsDefaults.K_SUBTITLE_BACKGROUND)
	if _cfg.has_section_key(section, bg_key):
		var bg_raw: Variant = _cfg.get_value(section, bg_key)
		var bg_str: String = String(bg_raw) if bg_raw != null else ""
		if not (bg_str in SUBTITLE_BG_VALID):
			_cfg.set_value(section, bg_key, String(SettingsDefaults.SUBTITLE_BACKGROUND))
			push_warning("[Settings] WARN: subtitle_background '%s' not a valid enum — defaulted to scrim." % bg_str)
			healed = true

	# subtitle_line_spacing_scale — [1.0, 1.5] clamp (WCAG SC 1.4.12).
	var lss_key: String = String(SettingsDefaults.K_SUBTITLE_LINE_SPACING_SCALE)
	if _cfg.has_section_key(section, lss_key):
		var lss_raw: Variant = _cfg.get_value(section, lss_key)
		if not (lss_raw is float or lss_raw is int):
			_cfg.set_value(section, lss_key, SettingsDefaults.SUBTITLE_LINE_SPACING_SCALE)
			push_warning("[Settings] WARN: subtitle_line_spacing_scale wrong type — defaulted.")
			healed = true
		else:
			var lss_clamped: float = clampf(float(lss_raw), SUBTITLE_LINE_SPACING_FLOOR, SUBTITLE_LINE_SPACING_CEILING)
			if not is_equal_approx(lss_clamped, float(lss_raw)):
				_cfg.set_value(section, lss_key, lss_clamped)
				push_warning("[Settings] WARN: subtitle_line_spacing_scale %f clamped to %f." % [float(lss_raw), lss_clamped])
				healed = true

	# subtitle_letter_spacing_em — [0.0, 0.12] clamp (WCAG SC 1.4.12).
	var lem_key: String = String(SettingsDefaults.K_SUBTITLE_LETTER_SPACING_EM)
	if _cfg.has_section_key(section, lem_key):
		var lem_raw: Variant = _cfg.get_value(section, lem_key)
		if not (lem_raw is float or lem_raw is int):
			_cfg.set_value(section, lem_key, SettingsDefaults.SUBTITLE_LETTER_SPACING_EM)
			push_warning("[Settings] WARN: subtitle_letter_spacing_em wrong type — defaulted.")
			healed = true
		else:
			var lem_clamped: float = clampf(float(lem_raw), SUBTITLE_LETTER_SPACING_FLOOR, SUBTITLE_LETTER_SPACING_CEILING)
			if not is_equal_approx(lem_clamped, float(lem_raw)):
				_cfg.set_value(section, lem_key, lem_clamped)
				push_warning("[Settings] WARN: subtitle_letter_spacing_em %f clamped to %f." % [float(lem_raw), lem_clamped])
				healed = true

	return healed


## SA-003 / TR-SET-007: enforce the 333 ms WCAG 2.3.1 floor on
## accessibility.damage_flash_cooldown_ms regardless of how the value got
## persisted (manual cfg edit, prior version drift, etc.). Returns true iff
## a clamp was applied (caller will save to disk).
func _heal_damage_flash_cooldown() -> bool:
	var section: String = String(SettingsDefaults.C_ACCESSIBILITY)
	var key: String = String(SettingsDefaults.K_DAMAGE_FLASH_COOLDOWN_MS)
	if not _cfg.has_section_key(section, key):
		return false
	var raw: Variant = _cfg.get_value(section, key)
	if not (raw is int or raw is float):
		_cfg.set_value(section, key, DAMAGE_FLASH_COOLDOWN_MS_FLOOR)
		push_warning("[Settings] WARN: damage_flash_cooldown_ms wrong type — defaulted to %d." % DAMAGE_FLASH_COOLDOWN_MS_FLOOR)
		return true
	var current: int = int(raw)
	var clamped: int = max(current, DAMAGE_FLASH_COOLDOWN_MS_FLOOR)
	if clamped != current:
		_cfg.set_value(section, key, clamped)
		push_warning("[Settings] WARN: damage_flash_cooldown_ms %d clamped to %d (WCAG 2.3.1 floor)." % [current, clamped])
		return true
	return false


## Write the current in-memory ConfigFile to disk. Logs (but does not crash)
## on read-only filesystem or other ERR_FILE_CANT_WRITE — the session keeps
## running with in-memory defaults; settings just don't persist.
func _save_to_disk() -> void:
	var save_err: int = _cfg.save(_SETTINGS_PATH)
	if save_err != OK:
		push_error("[Settings] ERR: failed to save %s (err=%d) — settings will not persist this session." % [_SETTINGS_PATH, save_err])


## Public read API — synchronous in-memory lookup. AC-7 contract.
## CONSUMERS MUST NOT call this from their _ready() (FP-3 — load-order race).
## Use Consumer Default Strategy + setting_changed subscriber instead.
func get_value(category: StringName, name: StringName, default_value: Variant = null) -> Variant:
	return _cfg.get_value(String(category), String(name), default_value)


## Public write API — write-through commit. Updates the in-memory ConfigFile,
## persists to disk, and emits Events.setting_changed (the SOLE publisher per
## TR-SET-001 / FP-1). Called by UI commit handlers (slider drag_ended,
## toggle toggled, dropdown item_selected) — wired in Story 005.
func commit_value(category: StringName, name: StringName, value: Variant) -> void:
	_cfg.set_value(String(category), String(name), value)
	_save_to_disk()
	Events.setting_changed.emit(category, name, value)
