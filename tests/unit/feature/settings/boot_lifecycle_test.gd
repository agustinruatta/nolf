# tests/unit/feature/settings/boot_lifecycle_test.gd
#
# SettingsBootLifecycleTest — GdUnit4 suite for Story SA-002.
#
# PURPOSE
#   AC-1 / AC-3 / AC-4 / AC-5 / AC-9 — burst-emit count + settings_loaded
#   one-shot + photosensitivity boot-warning flag + Restore Defaults cluster
#   preservation.
#
# GOVERNING REQUIREMENTS
#   TR-SET-002 (settings_loaded one-shot, no payload)
#   TR-SET-005 (boot burst skips [controls])
#   TR-SET-008 (photosensitivity_warning_dismissed presence/absence semantics)
#   TR-SET-015 (photosensitivity safety cluster survives Restore Defaults)
#   ADR-0002 2026-04-28 amendment

class_name SettingsBootLifecycleTest
extends GdUnitTestSuite

const _SETTINGS_SERVICE_SCRIPT: String = "res://src/core/settings/settings_service.gd"

var _setting_changed_emissions: Array = []
var _settings_loaded_count: int = 0


func before_test() -> void:
	_setting_changed_emissions = []
	_settings_loaded_count = 0
	Events.setting_changed.connect(_on_setting_changed_test_spy)
	Events.settings_loaded.connect(_on_settings_loaded_test_spy)


func after_test() -> void:
	if Events.setting_changed.is_connected(_on_setting_changed_test_spy):
		Events.setting_changed.disconnect(_on_setting_changed_test_spy)
	if Events.settings_loaded.is_connected(_on_settings_loaded_test_spy):
		Events.settings_loaded.disconnect(_on_settings_loaded_test_spy)


func _on_setting_changed_test_spy(category: StringName, name: StringName, value: Variant) -> void:
	_setting_changed_emissions.append([category, name, value])


func _on_settings_loaded_test_spy() -> void:
	_settings_loaded_count += 1


# ── AC-1: Burst emits one setting_changed per non-controls triple ───────────

## AC-1: With a fixture cfg containing 6 non-controls + 1 controls keys,
## _emit_burst fires exactly 6 setting_changed signals (controls skipped).
func test_burst_emits_one_signal_per_non_controls_triple() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Build a fixture cfg with explicit known content.
	service._cfg = ConfigFile.new()
	service._cfg.set_value("audio", "master_volume_db", 0.0)
	service._cfg.set_value("audio", "music_volume_db", -3.0)
	service._cfg.set_value("audio", "sfx_volume_db", -1.0)
	service._cfg.set_value("graphics", "resolution_scale", 1.0)
	service._cfg.set_value("accessibility", "subtitles_enabled", true)
	service._cfg.set_value("accessibility", "damage_flash_enabled", true)
	service._cfg.set_value("controls", "sprint_is_toggle", false)  # MUST be skipped

	_setting_changed_emissions.clear()
	_settings_loaded_count = 0

	# Act
	service._emit_burst()

	# Assert: 6 emissions (3 audio + 1 graphics + 2 accessibility, controls skipped).
	assert_int(_setting_changed_emissions.size()).override_failure_message(
		"Expected 6 setting_changed emissions (controls skipped). Got %d. Emissions: %s"
		% [_setting_changed_emissions.size(), _setting_changed_emissions]
	).is_equal(6)
	# No emission carries a controls-section category.
	for triple in _setting_changed_emissions:
		assert_str(String(triple[0])).override_failure_message(
			"controls section must be skipped during burst. Got triple: %s" % [triple]
		).is_not_equal("controls")


# ── AC-3: settings_loaded fires exactly once per session ─────────────────────

## AC-3: Multiple _emit_burst calls (e.g., for Restore Defaults) emit
## settings_loaded exactly once total.
func test_settings_loaded_one_shot_across_multiple_burst_calls() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("audio", "master_volume_db", 0.0)
	_setting_changed_emissions.clear()
	_settings_loaded_count = 0

	# Act: invoke burst 3 times (initial + 2 Restore Defaults equivalents).
	service._emit_burst()
	service._emit_burst()
	service._emit_burst()

	# Assert: settings_loaded fired exactly once.
	assert_int(_settings_loaded_count).override_failure_message(
		"settings_loaded must be one-shot per session. Got %d emissions." % _settings_loaded_count
	).is_equal(1)
	# setting_changed fired 3 × 1 = 3 times (once per burst per stored triple).
	assert_int(_setting_changed_emissions.size()).is_equal(3)


# ── AC-4: _boot_warning_pending true when key absent ─────────────────────────

## AC-4: cfg without accessibility/photosensitivity_warning_dismissed key →
## _boot_warning_pending == true.
func test_boot_warning_pending_true_when_key_absent() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Arrange: cfg with accessibility section but no photosensitivity_warning_dismissed.
	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "subtitles_enabled", true)

	# Act
	service._check_boot_warning()

	# Assert
	assert_bool(service._boot_warning_pending).override_failure_message(
		"Without photosensitivity_warning_dismissed key, _boot_warning_pending must be true."
	).is_true()


# ── AC-5: _boot_warning_pending false when key present ───────────────────────

## AC-5: cfg with accessibility/photosensitivity_warning_dismissed = true →
## _boot_warning_pending == false.
func test_boot_warning_pending_false_when_key_present_and_true() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "photosensitivity_warning_dismissed", true)

	service._check_boot_warning()

	assert_bool(service._boot_warning_pending).override_failure_message(
		"With photosensitivity_warning_dismissed = true, _boot_warning_pending must be false."
	).is_false()


## AC-5 edge: explicit `false` (not absent) is also "warning already shown".
## Per GDD C.6: only ABSENCE triggers the warning; `false` is a valid stored value.
func test_boot_warning_pending_false_even_when_key_value_is_false() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "photosensitivity_warning_dismissed", false)

	service._check_boot_warning()

	assert_bool(service._boot_warning_pending).override_failure_message(
		"With photosensitivity_warning_dismissed = false (key PRESENT), _boot_warning_pending must still be false. Only absence triggers the warning."
	).is_false()


# ── AC-7 partial: dismiss_warning persists + flips flag ──────────────────────

func test_dismiss_warning_persists_flag_and_returns_true_on_success() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._boot_warning_pending = true

	# Act
	var ok: bool = service.dismiss_warning()

	# Assert: flag flipped + cfg has the dismissed key set.
	assert_bool(service._boot_warning_pending).is_false()
	assert_bool(ok).is_true()
	assert_bool(service._cfg.has_section_key("accessibility", "photosensitivity_warning_dismissed")).is_true()
	assert_bool(service._cfg.get_value("accessibility", "photosensitivity_warning_dismissed", false)).is_true()


# ── AC-9: Photosensitivity cluster survives Restore Defaults ────────────────

func test_restore_defaults_preserves_photosensitivity_cluster() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Arrange: set the full safety cluster + a non-cluster key that should reset.
	service._cfg = ConfigFile.new()
	service._populate_defaults()
	service._cfg.set_value("accessibility", "photosensitivity_warning_dismissed", true)
	service._cfg.set_value("accessibility", "damage_flash_enabled", false)
	service._cfg.set_value("accessibility", "damage_flash_cooldown_ms", 1000)
	service._cfg.set_value("audio", "master_volume_db", -20.0)  # non-cluster, must reset
	# Pre-mark settings_loaded as already emitted (prior session burst happened).
	service._settings_loaded_emitted = true

	_setting_changed_emissions.clear()
	_settings_loaded_count = 0

	# Act
	service.restore_defaults()

	# Assert: cluster keys retained.
	assert_bool(service._cfg.get_value("accessibility", "photosensitivity_warning_dismissed", false)).override_failure_message(
		"photosensitivity_warning_dismissed must survive Restore Defaults."
	).is_true()
	assert_bool(service._cfg.get_value("accessibility", "damage_flash_enabled", true)).override_failure_message(
		"damage_flash_enabled must survive Restore Defaults (was false)."
	).is_false()
	assert_int(int(service._cfg.get_value("accessibility", "damage_flash_cooldown_ms", 333))).override_failure_message(
		"damage_flash_cooldown_ms must survive Restore Defaults (was 1000)."
	).is_equal(1000)
	# Non-cluster key reset to default.
	assert_float(float(service._cfg.get_value("audio", "master_volume_db", 999.0))).override_failure_message(
		"Non-cluster keys must reset to defaults during Restore Defaults."
	).is_equal(SettingsDefaults.MASTER_VOLUME_DB)
	# settings_loaded NOT re-emitted (one-shot per session).
	assert_int(_settings_loaded_count).override_failure_message(
		"settings_loaded must NOT be re-emitted by restore_defaults — one-shot per session per AC-3 + AC-9."
	).is_equal(0)
