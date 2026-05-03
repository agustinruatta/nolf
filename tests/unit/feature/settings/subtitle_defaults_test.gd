# tests/unit/feature/settings/subtitle_defaults_test.gd
#
# SubtitleDefaultsTest — GdUnit4 suite for Story SA-006.
#
# PURPOSE
#   AC-1 / AC-2 / AC-3 / AC-4 / AC-5 / AC-6 / AC-7 / AC-8 / AC-9 — subtitle
#   cluster defaults are written, captions-default-on locked at source,
#   round-trip preserves types, Cluster B self-heals invalid values, burst
#   reconstitutes subtitle_background as StringName, Restore Defaults resets.
#
# GOVERNING REQUIREMENTS
#   TR-SET-009 (subtitle cluster persistence)
#   TR-SET-014 (no settings keys in SaveGame)
#   GDD CR-23 (captions-default-on opt-OUT — WCAG SC 1.2.2)
#   GDD §G.9 (subtitle cluster spec)

class_name SubtitleDefaultsTest
extends GdUnitTestSuite

const _SETTINGS_SERVICE_SCRIPT: String = "res://src/core/settings/settings_service.gd"
const _SETTINGS_DEFAULTS_PATH: String = "res://src/core/settings/settings_defaults.gd"

var _setting_changed_emissions: Array = []


func before_test() -> void:
	_setting_changed_emissions = []
	Events.setting_changed.connect(_on_setting_changed_test_spy)


func after_test() -> void:
	if Events.setting_changed.is_connected(_on_setting_changed_test_spy):
		Events.setting_changed.disconnect(_on_setting_changed_test_spy)


func _on_setting_changed_test_spy(category: StringName, name: StringName, value: Variant) -> void:
	_setting_changed_emissions.append([category, name, value])


# ── AC-1: First-launch subtitle cluster defaults are written ────────────────

func test_first_launch_writes_all_six_subtitle_cluster_defaults() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Act: simulate fresh-install populate.
	service._cfg = ConfigFile.new()
	service._populate_defaults()

	# Assert: all six subtitle keys present with correct defaults.
	assert_bool(service._cfg.get_value("accessibility", "subtitles_enabled", null)).is_true()
	assert_float(float(service._cfg.get_value("accessibility", "subtitle_size_scale", 0.0))).is_equal(1.0)
	assert_str(String(service._cfg.get_value("accessibility", "subtitle_background", ""))).is_equal("scrim")
	assert_bool(service._cfg.get_value("accessibility", "subtitle_speaker_labels", null)).is_true()
	assert_float(float(service._cfg.get_value("accessibility", "subtitle_line_spacing_scale", 0.0))).is_equal(1.0)
	assert_float(float(service._cfg.get_value("accessibility", "subtitle_letter_spacing_em", -1.0))).is_equal(0.0)


# ── AC-2 + AC-3: captions-default-on locked at source (BLOCKING WCAG SC 1.2.2) ─

func test_settings_defaults_subtitles_enabled_const_is_true() -> void:
	# Static check via the constant itself.
	assert_bool(SettingsDefaults.SUBTITLES_ENABLED).override_failure_message(
		"SettingsDefaults.SUBTITLES_ENABLED MUST be true (WCAG SC 1.2.2 opt-OUT). "
		+ "If this fails, GDD CR-23 was violated — investigate before flipping the bit."
	).is_true()


func test_no_subtitles_enabled_false_in_settings_defaults_source() -> void:
	# Source-level grep: no `SUBTITLES_ENABLED.*false` literal in defaults file.
	var f: FileAccess = FileAccess.open(_SETTINGS_DEFAULTS_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()
	# Build a regex that matches a non-comment line declaring SUBTITLES_ENABLED with `false`.
	var pattern: RegEx = RegEx.new()
	pattern.compile("(?m)^\\s*const\\s+SUBTITLES_ENABLED.*=\\s*false")
	var m: RegExMatch = pattern.search(content)
	assert_object(m).override_failure_message(
		"settings_defaults.gd MUST NOT declare SUBTITLES_ENABLED = false (WCAG SC 1.2.2 / GDD CR-23 / AC-SA-5.7b CI gate)."
	).is_null()


# ── AC-4: Persistence round-trip for all six subtitle keys ──────────────────

func test_persistence_round_trip_preserves_subtitle_cluster_types() -> void:
	var tmp_path: String = "user://subtitle_round_trip.cfg"
	var write_cfg: ConfigFile = ConfigFile.new()
	write_cfg.set_value("accessibility", "subtitles_enabled", false)
	write_cfg.set_value("accessibility", "subtitle_size_scale", 1.5)
	write_cfg.set_value("accessibility", "subtitle_background", "opaque")
	write_cfg.set_value("accessibility", "subtitle_speaker_labels", false)
	write_cfg.set_value("accessibility", "subtitle_line_spacing_scale", 1.2)
	write_cfg.set_value("accessibility", "subtitle_letter_spacing_em", 0.08)
	write_cfg.save(tmp_path)

	var read_cfg: ConfigFile = ConfigFile.new()
	read_cfg.load(tmp_path)

	assert_bool(read_cfg.get_value("accessibility", "subtitles_enabled", true)).is_false()
	assert_float(read_cfg.get_value("accessibility", "subtitle_size_scale", 0.0)).is_equal(1.5)
	assert_str(read_cfg.get_value("accessibility", "subtitle_background", "")).is_equal("opaque")
	assert_bool(read_cfg.get_value("accessibility", "subtitle_speaker_labels", true)).is_false()
	assert_float(read_cfg.get_value("accessibility", "subtitle_line_spacing_scale", 0.0)).is_equal_approx(1.2, 0.001)
	assert_float(read_cfg.get_value("accessibility", "subtitle_letter_spacing_em", 0.0)).is_equal_approx(0.08, 0.001)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))


# ── AC-5: Burst emits all six subtitle keys + reconstitutes background as StringName ─

func test_burst_emits_subtitle_cluster_with_background_as_stringname() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitles_enabled", true)
	service._cfg.set_value("accessibility", "subtitle_size_scale", 1.5)
	service._cfg.set_value("accessibility", "subtitle_background", "opaque")  # String in cfg
	service._cfg.set_value("accessibility", "subtitle_speaker_labels", true)
	service._cfg.set_value("accessibility", "subtitle_line_spacing_scale", 1.2)
	service._cfg.set_value("accessibility", "subtitle_letter_spacing_em", 0.08)

	_setting_changed_emissions.clear()
	service._emit_burst()

	# Find the subtitle_background emission and verify type is StringName.
	var bg_emission: Array = []
	for triple in _setting_changed_emissions:
		if triple[1] == &"subtitle_background":
			bg_emission = triple
			break
	assert_int(bg_emission.size()).override_failure_message(
		"subtitle_background must be emitted by burst."
	).is_greater(0)
	assert_int(typeof(bg_emission[2])).override_failure_message(
		"subtitle_background must be reconstituted to StringName before emit (was %s)." % type_string(typeof(bg_emission[2]))
	).is_equal(TYPE_STRING_NAME)
	assert_str(String(bg_emission[2])).is_equal("opaque")

	# All six subtitle keys are emitted.
	var subtitle_keys_emitted: int = 0
	for triple in _setting_changed_emissions:
		if String(triple[0]) == "accessibility" and String(triple[1]).begins_with("subtitle"):
			subtitle_keys_emitted += 1
	# +1 for subtitles_enabled which doesn't have "subtitle" prefix... actually it does (subtitle_enabled? no, subtitles_enabled).
	# Let me count by checking all keys explicitly.
	var subtitle_key_set: Array[String] = [
		"subtitles_enabled", "subtitle_size_scale", "subtitle_background",
		"subtitle_speaker_labels", "subtitle_line_spacing_scale", "subtitle_letter_spacing_em",
	]
	var count: int = 0
	for triple in _setting_changed_emissions:
		if String(triple[1]) in subtitle_key_set:
			count += 1
	assert_int(count).override_failure_message(
		"Burst must emit all 6 subtitle cluster keys. Got %d. Emissions: %s" % [count, _setting_changed_emissions]
	).is_equal(6)


# ── AC-6: subtitle_size_scale Cluster B self-heal (invalid preset → default) ─

func test_invalid_subtitle_size_scale_preset_is_healed_to_default() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitle_size_scale", 0.5)  # invalid

	var healed: bool = service._heal_subtitle_cluster()

	assert_bool(healed).is_true()
	assert_float(service._cfg.get_value("accessibility", "subtitle_size_scale", 0.0)).is_equal(1.0)


func test_valid_subtitle_size_scale_preset_is_not_healed() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitle_size_scale", 1.5)  # valid

	var healed: bool = service._heal_subtitle_cluster()

	assert_bool(healed).is_false()
	assert_float(service._cfg.get_value("accessibility", "subtitle_size_scale", 0.0)).is_equal(1.5)


# ── AC-7: WCAG SC 1.4.12 line + letter spacing clamps ───────────────────────

func test_subtitle_line_spacing_scale_above_ceiling_is_clamped_to_1_5() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitle_line_spacing_scale", 2.5)

	var healed: bool = service._heal_subtitle_cluster()

	assert_bool(healed).is_true()
	assert_float(service._cfg.get_value("accessibility", "subtitle_line_spacing_scale", 0.0)).is_equal(1.5)


func test_subtitle_letter_spacing_em_above_ceiling_is_clamped_to_0_12() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitle_letter_spacing_em", 0.15)

	var healed: bool = service._heal_subtitle_cluster()

	assert_bool(healed).is_true()
	assert_float(service._cfg.get_value("accessibility", "subtitle_letter_spacing_em", -1.0)).is_equal_approx(0.12, 0.001)


func test_subtitle_letter_spacing_em_negative_is_clamped_to_0() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitle_letter_spacing_em", -0.01)

	var healed: bool = service._heal_subtitle_cluster()

	assert_bool(healed).is_true()
	assert_float(service._cfg.get_value("accessibility", "subtitle_letter_spacing_em", -1.0)).is_equal(0.0)


# ── AC-8: subtitle_background invalid value defaults to scrim ───────────────

func test_invalid_subtitle_background_defaults_to_scrim() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitle_background", "neon_pink")  # not in valid enum

	var healed: bool = service._heal_subtitle_cluster()

	assert_bool(healed).is_true()
	assert_str(service._cfg.get_value("accessibility", "subtitle_background", "")).is_equal("scrim")


# ── AC-9: Restore Defaults RESETS the subtitle cluster (not preserved) ──────

func test_restore_defaults_resets_subtitle_cluster_unlike_photosensitivity() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Arrange: non-default subtitle values + non-default photosensitivity.
	service._cfg = ConfigFile.new()
	service._populate_defaults()
	service._cfg.set_value("accessibility", "subtitles_enabled", false)
	service._cfg.set_value("accessibility", "subtitle_size_scale", 2.0)
	service._cfg.set_value("accessibility", "photosensitivity_warning_dismissed", true)
	service._cfg.set_value("accessibility", "damage_flash_enabled", false)
	service._settings_loaded_emitted = true

	# Act
	service.restore_defaults()

	# Assert: subtitle cluster RESET to defaults.
	assert_bool(service._cfg.get_value("accessibility", "subtitles_enabled", false)).override_failure_message(
		"subtitles_enabled must reset to default true after Restore Defaults."
	).is_true()
	assert_float(service._cfg.get_value("accessibility", "subtitle_size_scale", 0.0)).override_failure_message(
		"subtitle_size_scale must reset to default 1.0 after Restore Defaults."
	).is_equal(1.0)
	# Assert: photosensitivity cluster PRESERVED (per Story 002 AC-9 invariant).
	assert_bool(service._cfg.get_value("accessibility", "photosensitivity_warning_dismissed", false)).is_true()
	assert_bool(service._cfg.get_value("accessibility", "damage_flash_enabled", true)).is_false()
