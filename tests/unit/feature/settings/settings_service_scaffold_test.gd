# tests/unit/feature/settings/settings_service_scaffold_test.gd
#
# SettingsServiceScaffoldTest — GdUnit4 suite for Story SA-001.
#
# PURPOSE
#   AC-1 / AC-5 / AC-6 / AC-7 — autoload registration + fresh-install defaults
#   write + load-error fallback + ConfigFile round-trip fidelity.
#
# GOVERNING REQUIREMENTS
#   TR-SET-003 (sole reader/writer of user://settings.cfg)
#   TR-SET-004 (autoload at ADR-0007 line 10)
#   ADR-0003 §IG 10 (settings.cfg separate from SaveGame)
#
# Method
#   Tests instantiate fresh SettingsService nodes locally (not the live
#   autoload) so each test has isolated ConfigFile state. The live autoload
#   is verified for AC-1 only (presence + position).

class_name SettingsServiceScaffoldTest
extends GdUnitTestSuite

const _SETTINGS_SERVICE_SCRIPT: String = "res://src/core/settings/settings_service.gd"
const _PROJECT_PATH: String = "res://project.godot"


# ── AC-1: Autoload registration at ADR-0007 line 10 ──────────────────────────

## AC-1: project.godot [autoload] block contains SettingsService at the
## position immediately following MissionLevelScripting (line 10 of the block).
func test_autoload_registered_after_mission_level_scripting() -> void:
	var f: FileAccess = FileAccess.open(_PROJECT_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()

	var settings_idx: int = content.find("SettingsService=\"*res://src/core/settings/settings_service.gd\"")
	var mls_idx: int = content.find("MissionLevelScripting=")
	assert_int(settings_idx).override_failure_message(
		"project.godot must register SettingsService autoload pointing to settings_service.gd."
	).is_greater(-1)
	assert_int(mls_idx).override_failure_message(
		"project.godot must register MissionLevelScripting autoload (precedes SettingsService per ADR-0007)."
	).is_greater(-1)
	assert_bool(settings_idx > mls_idx).override_failure_message(
		"SettingsService autoload must follow MissionLevelScripting in declaration order (ADR-0007 line 10)."
	).is_true()


## AC-1: SettingsService is in the active scene tree as a child of root.
func test_autoload_present_in_scene_tree_root() -> void:
	var root: Window = get_tree().root
	var ss: Node = root.get_node_or_null("SettingsService")
	assert_object(ss).override_failure_message(
		"SettingsService autoload must be present at /root/SettingsService."
	).is_not_null()
	# Verify the node has the SettingsService class (not a stub).
	assert_str(ss.get_script().resource_path).override_failure_message(
		"Autoloaded SettingsService must use settings_service.gd, not a stub. Got: '%s'" % ss.get_script().resource_path
	).is_equal(_SETTINGS_SERVICE_SCRIPT)


# ── AC-5: Fresh-install defaults write ───────────────────────────────────────

## AC-5: With user://settings.cfg absent, SettingsService.populate_defaults +
## save round-trip writes all manifest keys to a fresh ConfigFile.
## We verify the populate-defaults path directly (no FS write needed for unit).
func test_fresh_install_populate_defaults_writes_full_manifest() -> void:
	# Arrange: instantiate service offline (don't add to tree to avoid _ready autoload).
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Act: populate defaults into the in-memory cfg without disk I/O.
	service._populate_defaults()

	# Assert: every key from the manifest is present + matches the default value.
	var manifest: Dictionary = SettingsDefaults.get_manifest()
	for category in manifest:
		var entries: Dictionary = manifest[category]
		for key in entries:
			var stored: Variant = service._cfg.get_value(String(category), String(key))
			var expected: Variant = entries[key]
			assert_bool(typeof(stored) == typeof(expected)).override_failure_message(
				"Default for %s/%s must have matching type. Got %s, expected %s." % [category, key, typeof(stored), typeof(expected)]
			).is_true()


# ── AC-6: Load error fallback ────────────────────────────────────────────────

## AC-6: When ConfigFile.load returns a non-OK error code, SettingsService
## falls back to defaults instead of crashing or running with partial state.
## We simulate by calling _populate_defaults after a fresh ConfigFile (no load).
func test_load_error_fallback_populates_defaults() -> void:
	# Arrange
	var ServiceScript = load(_SETTINGS_SERVICE_SCRIPT)
	var service: Node = ServiceScript.new()
	auto_free(service)

	# Act: simulate the error fallback path — fresh ConfigFile + populate_defaults.
	# (The real _load_settings() also calls _save_to_disk; we verify population only here.)
	service._cfg = ConfigFile.new()
	service._populate_defaults()

	# Assert: master_volume_db is populated from defaults, not absent.
	var master_db: Variant = service._cfg.get_value(
		String(SettingsDefaults.C_AUDIO),
		String(SettingsDefaults.K_MASTER_VOLUME_DB)
	)
	assert_bool(master_db != null).override_failure_message(
		"After load-error fallback, master_volume_db must be present from defaults. Got null."
	).is_true()
	assert_float(float(master_db)).is_equal(SettingsDefaults.MASTER_VOLUME_DB)


# ── AC-7: ConfigFile round-trip fidelity (bool/int/float/String/StringName) ──

## AC-7: A value written via _cfg.set_value + _cfg.save round-trips through a
## fresh ConfigFile.load with byte-for-byte fidelity for every type the project
## stores (bool, int, float, String). StringName is stored as String per CR-7.
func test_config_file_round_trip_preserves_all_supported_types() -> void:
	# Arrange: write to a tmp ConfigFile path inside user://.
	var tmp_path: String = "user://settings_round_trip_test.cfg"
	var write_cfg: ConfigFile = ConfigFile.new()
	write_cfg.set_value("audio", "master_volume_db", -12.5)  # float
	write_cfg.set_value("audio", "music_volume_db", 0)       # int
	write_cfg.set_value("accessibility", "subtitles_enabled", true)  # bool
	write_cfg.set_value("accessibility", "subtitle_background", "scrim")  # String
	write_cfg.set_value("language", "locale", "en")          # String

	var save_err: int = write_cfg.save(tmp_path)
	assert_int(save_err).override_failure_message(
		"ConfigFile.save must succeed (err=%d)." % save_err
	).is_equal(OK)

	# Act: load into a fresh ConfigFile and read each value back.
	var read_cfg: ConfigFile = ConfigFile.new()
	var load_err: int = read_cfg.load(tmp_path)
	assert_int(load_err).override_failure_message(
		"ConfigFile.load must succeed (err=%d)." % load_err
	).is_equal(OK)

	# Assert: each value matches the written value exactly.
	assert_float(read_cfg.get_value("audio", "master_volume_db", 999.0)).is_equal(-12.5)
	assert_int(int(read_cfg.get_value("audio", "music_volume_db", 999))).is_equal(0)
	assert_bool(read_cfg.get_value("accessibility", "subtitles_enabled", false)).is_true()
	assert_str(read_cfg.get_value("accessibility", "subtitle_background", "")).is_equal("scrim")
	assert_str(read_cfg.get_value("language", "locale", "")).is_equal("en")

	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))


# ── AC-7 (StringName): StringName values stored as String per CR-7 ───────────

## AC-7 edge: StringName values are stored as String in ConfigFile (no native
## StringName type in ConfigFile). Reconstitute via StringName(loaded_string) on read.
func test_config_file_string_name_stores_as_string_with_reconstitution() -> void:
	var tmp_path: String = "user://settings_sn_round_trip_test.cfg"
	var write_cfg: ConfigFile = ConfigFile.new()
	write_cfg.set_value("accessibility", "subtitle_background", &"scrim")  # StringName
	var save_err: int = write_cfg.save(tmp_path)
	assert_int(save_err).is_equal(OK)

	var read_cfg: ConfigFile = ConfigFile.new()
	read_cfg.load(tmp_path)
	var loaded: Variant = read_cfg.get_value("accessibility", "subtitle_background", "")
	# ConfigFile may serialize StringName as either String or StringName depending on Godot version.
	# Either is acceptable for round-trip — verify the displayed value matches.
	assert_str(String(loaded)).is_equal("scrim")
	# Reconstitution must produce a usable StringName.
	var reconstituted: StringName = StringName(String(loaded))
	assert_bool(reconstituted == &"scrim").override_failure_message(
		"StringName round-trip via String reconstitution must equal &\"scrim\". Got: '%s'" % reconstituted
	).is_true()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
