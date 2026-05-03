# tests/unit/feature/settings/photosensitivity_floor_test.gd
#
# PhotosensitivityFloorTest — GdUnit4 suite for Story SA-003.
#
# PURPOSE
#   AC-1 / AC-6 — load-time clamp for damage_flash_cooldown_ms 333 ms WCAG
#   2.3.1 safety floor + self-heal round-trip.
#
# GOVERNING REQUIREMENTS
#   TR-SET-007 (333 ms hard floor on damage_flash_cooldown_ms — WCAG 2.3.1)

class_name PhotosensitivityFloorTest
extends GdUnitTestSuite

const _SETTINGS_SERVICE_SCRIPT: String = "res://src/core/settings/settings_service.gd"


# ── AC-1: Load-time clamp for sub-floor cooldown values ──────────────────────

func test_sub_floor_cooldown_is_clamped_to_333_ms() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Arrange: cfg with a sub-floor value (100ms).
	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "damage_flash_cooldown_ms", 100)

	# Act
	var healed: bool = service._heal_damage_flash_cooldown()

	# Assert
	assert_bool(healed).is_true()
	assert_int(int(service._cfg.get_value("accessibility", "damage_flash_cooldown_ms", 0))).is_equal(333)


## AC-1 edge: exactly at floor — no clamp, no write-back.
func test_at_floor_cooldown_is_not_clamped() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "damage_flash_cooldown_ms", 333)

	var healed: bool = service._heal_damage_flash_cooldown()

	assert_bool(healed).override_failure_message(
		"At-floor value (333) must NOT trigger a clamp/write-back."
	).is_false()
	assert_int(int(service._cfg.get_value("accessibility", "damage_flash_cooldown_ms", 0))).is_equal(333)


## AC-1 edge: above floor — no clamp.
func test_above_floor_cooldown_is_not_clamped() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "damage_flash_cooldown_ms", 1000)

	var healed: bool = service._heal_damage_flash_cooldown()

	assert_bool(healed).is_false()
	assert_int(int(service._cfg.get_value("accessibility", "damage_flash_cooldown_ms", 0))).is_equal(1000)


## AC-1 edge: wrong type — defaulted to floor.
func test_wrong_type_cooldown_defaults_to_floor() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "damage_flash_cooldown_ms", "quick")

	var healed: bool = service._heal_damage_flash_cooldown()

	assert_bool(healed).is_true()
	assert_int(int(service._cfg.get_value("accessibility", "damage_flash_cooldown_ms", 0))).is_equal(333)


## AC-1 edge: float type ok and gets clamped.
func test_float_sub_floor_cooldown_is_clamped() -> void:
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	service._cfg = ConfigFile.new()
	service._cfg.set_value("accessibility", "damage_flash_cooldown_ms", 250.5)

	var healed: bool = service._heal_damage_flash_cooldown()

	assert_bool(healed).is_true()
	assert_int(int(service._cfg.get_value("accessibility", "damage_flash_cooldown_ms", 0))).is_equal(333)


# ── AC-6: Self-heal round-trip persists across save/reload ───────────────────

func test_self_heal_persists_across_save_and_reload() -> void:
	# Arrange: write a sub-floor value to a tmp cfg file, then load + heal + save.
	var tmp_path: String = "user://photosensitivity_floor_round_trip.cfg"
	var write_cfg: ConfigFile = ConfigFile.new()
	write_cfg.set_value("accessibility", "damage_flash_cooldown_ms", 100)
	write_cfg.save(tmp_path)

	# Simulate the heal step by loading in service and saving.
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)
	service._cfg = ConfigFile.new()
	service._cfg.load(tmp_path)
	service._heal_damage_flash_cooldown()
	service._cfg.save(tmp_path)

	# Act: reload from disk in a fresh ConfigFile.
	var reload_cfg: ConfigFile = ConfigFile.new()
	reload_cfg.load(tmp_path)

	# Assert: the persisted value is the clamped 333, not 100.
	assert_int(int(reload_cfg.get_value("accessibility", "damage_flash_cooldown_ms", 0))).override_failure_message(
		"Self-healed cooldown must persist across save/reload — must read back as 333, not 100."
	).is_equal(333)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
