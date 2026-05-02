# tests/integration/core/input/input_rebind_persistence_test.gd
#
# InputRebindPersistenceTest — Story IN-006 AC-INPUT-4.3.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-006)
#   AC-4.3 (BLOCKING): persistence — a rebinding written to a ConfigFile and
#   re-applied to the InputMap reproduces the binding correctly. Verifies the
#   wire-format round-trip (Settings GDD owns the canonical implementation;
#   this test uses a simplified manual-serialization helper).
#
# TEARDOWN
#   Tests delete `user://test_settings.cfg` in after_test() to avoid polluting
#   downstream tests (coding-standards.md isolation rule).
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name InputRebindPersistenceTest
extends GdUnitTestSuite

const _ACTION: StringName = &"move_forward"
const _DEFAULT_KEYCODE: Key = KEY_W
const _NEW_KEYCODE: Key = KEY_T
const _CFG_PATH: String = "user://test_settings.cfg"


# ── Helpers (test-only manual ConfigFile serialization) ─────────────────────

## Writes a single keycode rebinding to user://test_settings.cfg.
static func _write_rebinding(path: String, action: StringName, keycode: Key) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", String(action) + ".type", "key")
	cfg.set_value("controls", String(action) + ".keycode", int(keycode))
	return cfg.save(path)


## Reads a keycode rebinding from user://test_settings.cfg into a fresh
## InputEventKey. Returns null if the file or values are missing.
static func _load_rebinding_event(path: String, action: StringName) -> InputEventKey:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return null
	var stored_keycode: int = int(cfg.get_value("controls", String(action) + ".keycode", -1))
	if stored_keycode < 0:
		return null
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = stored_keycode as Key
	return ev


func _make_key_event(keycode: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


## Original move_forward events captured at first run; preserved across tests.
static var _saved_events: Array[InputEvent] = []


func _capture_default_binding() -> void:
	if _saved_events.is_empty() and InputMap.has_action(_ACTION):
		_saved_events = InputMap.action_get_events(_ACTION).duplicate() as Array[InputEvent]


func _restore_default_binding() -> void:
	if InputMap.has_action(_ACTION):
		InputMap.action_erase_events(_ACTION)
		for ev: InputEvent in _saved_events:
			InputMap.action_add_event(_ACTION, ev)


func _delete_test_cfg() -> void:
	if FileAccess.file_exists(_CFG_PATH):
		var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(_CFG_PATH))
		# silent failure in cleanup is acceptable
		var _ignored: Error = err


func before_test() -> void:
	_capture_default_binding()
	Input.action_release(_ACTION)
	_delete_test_cfg()


func after_test() -> void:
	Input.action_release(_ACTION)
	_delete_test_cfg()
	_restore_default_binding()


# ── AC-4.3: write + load round-trip ─────────────────────────────────────────

func test_write_then_load_reproduces_keycode() -> void:
	# Act — write a rebinding (move_forward → T) to the cfg
	var write_err: Error = _write_rebinding(_CFG_PATH, _ACTION, _NEW_KEYCODE)
	assert_int(write_err).override_failure_message(
		"AC-4.3 write: ConfigFile.save must succeed. Got error %d." % write_err
	).is_equal(OK)

	# File should exist after write
	assert_bool(FileAccess.file_exists(_CFG_PATH)).override_failure_message(
		"AC-4.3: cfg file must exist after write."
	).is_true()

	# Act — load
	var loaded_event: InputEventKey = _load_rebinding_event(_CFG_PATH, _ACTION)

	# Assert — loaded event has the new keycode
	assert_object(loaded_event).is_not_null()
	assert_int(loaded_event.physical_keycode).override_failure_message(
		"AC-4.3 load: loaded keycode must equal what was written. Got %d." % loaded_event.physical_keycode
	).is_equal(int(_NEW_KEYCODE))


# ── AC-4.3: load + apply integrates into InputMap ───────────────────────────

func test_load_and_apply_to_input_map_makes_new_key_active() -> void:
	# Arrange — write rebinding to cfg
	var write_err: Error = _write_rebinding(_CFG_PATH, _ACTION, _NEW_KEYCODE)
	assert_int(write_err).is_equal(OK)

	# Act — load and apply to InputMap (mimicking Settings's load step)
	var loaded_event: InputEventKey = _load_rebinding_event(_CFG_PATH, _ACTION)
	assert_object(loaded_event).is_not_null()

	InputMap.action_erase_events(_ACTION)
	if InputMap.has_action(_ACTION):
		InputMap.action_add_event(_ACTION, loaded_event)

	# Assert — new key triggers the action
	assert_bool(InputMap.event_is_action(_make_key_event(_NEW_KEYCODE), _ACTION)).override_failure_message(
		"AC-4.3 apply: T key must trigger move_forward after cfg load and apply."
	).is_true()
	# Old key no longer triggers
	assert_bool(InputMap.event_is_action(_make_key_event(_DEFAULT_KEYCODE), _ACTION)).is_false()


# ── AC-4.3: missing cfg returns null gracefully (no crash) ──────────────────

func test_load_from_missing_cfg_returns_null() -> void:
	# Ensure cfg does not exist
	_delete_test_cfg()
	assert_bool(FileAccess.file_exists(_CFG_PATH)).is_false()

	# Act
	var loaded: InputEventKey = _load_rebinding_event(_CFG_PATH, _ACTION)

	# Assert — graceful null, no crash
	assert_object(loaded).override_failure_message(
		"AC-4.3 robustness: missing cfg must return null gracefully."
	).is_null()


# ── AC-4.3: missing key in cfg returns null ─────────────────────────────────

func test_load_with_missing_action_in_cfg_returns_null() -> void:
	# Write a cfg WITHOUT the move_forward entry
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "some_other_action.keycode", int(KEY_X))
	assert_int(cfg.save(_CFG_PATH)).is_equal(OK)

	var loaded: InputEventKey = _load_rebinding_event(_CFG_PATH, _ACTION)
	assert_object(loaded).override_failure_message(
		"AC-4.3 robustness: missing action key in cfg must return null."
	).is_null()
