# tests/integration/core/input/rebind_round_trip_test.gd
#
# RebindRoundTripTest — Story IN-006 AC-INPUT-4.4.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-006)
#   AC-4.4 (BLOCKING): full round-trip — rebind → write to cfg → clear runtime
#   InputMap → reload from cfg → verify new key triggers action.
#
# DESIGN
#   Builds on AC-4.1 (rebind primitive) + AC-4.3 (persistence) and verifies
#   the complete Settings-driven flow as a single sequence.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name RebindRoundTripTest
extends GdUnitTestSuite

const _ACTION: StringName = &"move_forward"
const _DEFAULT_KEYCODE: Key = KEY_W
const _NEW_KEYCODE: Key = KEY_T
const _CFG_PATH: String = "user://test_round_trip_settings.cfg"


func _make_key_event(keycode: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


func _write_rebinding(path: String, action: StringName, keycode: Key) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", String(action) + ".keycode", int(keycode))
	cfg.save(path)


func _load_rebinding_event(path: String, action: StringName) -> InputEventKey:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return null
	var keycode: int = int(cfg.get_value("controls", String(action) + ".keycode", -1))
	if keycode < 0:
		return null
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode as Key
	return ev


## Original move_forward events captured at first run; preserved across tests.
static var _saved_events: Array[InputEvent] = []


func _capture_default_binding() -> void:
	if _saved_events.is_empty() and InputMap.has_action(_ACTION):
		_saved_events = InputMap.action_get_events(_ACTION).duplicate() as Array[InputEvent]


func _restore_default() -> void:
	if InputMap.has_action(_ACTION):
		InputMap.action_erase_events(_ACTION)
		for ev: InputEvent in _saved_events:
			InputMap.action_add_event(_ACTION, ev)


func _delete_cfg() -> void:
	if FileAccess.file_exists(_CFG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_CFG_PATH))


func before_test() -> void:
	_capture_default_binding()
	Input.action_release(_ACTION)
	_delete_cfg()


func after_test() -> void:
	Input.action_release(_ACTION)
	_delete_cfg()
	_restore_default()


# ── AC-4.4: full round-trip ─────────────────────────────────────────────────

## AC-4.4: rebind → write → clear → reload → verify new key active.
func test_full_round_trip_rebind_persist_clear_reload_verify() -> void:
	# Step (a): rebind move_forward → T via InputMap (Settings would call this)
	InputMap.action_erase_events(_ACTION)
	if InputMap.has_action(_ACTION):
		InputMap.action_add_event(_ACTION, _make_key_event(_NEW_KEYCODE))

	# Sanity: T triggers, W does not (post-rebind, pre-persist)
	assert_bool(InputMap.event_is_action(_make_key_event(_NEW_KEYCODE), _ACTION)).is_true()
	assert_bool(InputMap.event_is_action(_make_key_event(_DEFAULT_KEYCODE), _ACTION)).is_false()

	# Step (b): write the rebinding to cfg
	_write_rebinding(_CFG_PATH, _ACTION, _NEW_KEYCODE)
	assert_bool(FileAccess.file_exists(_CFG_PATH)).is_true()

	# Step (c): clear the runtime InputMap binding (simulating "fresh launch")
	InputMap.action_erase_events(_ACTION)
	# Confirm action is now unbound
	assert_bool(InputMap.event_is_action(_make_key_event(_NEW_KEYCODE), _ACTION)).is_false()
	assert_bool(InputMap.event_is_action(_make_key_event(_DEFAULT_KEYCODE), _ACTION)).is_false()

	# Step (d): reload from cfg and apply (Settings's load-on-startup path)
	var loaded_event: InputEventKey = _load_rebinding_event(_CFG_PATH, _ACTION)
	assert_object(loaded_event).is_not_null()
	if InputMap.has_action(_ACTION):
		InputMap.action_add_event(_ACTION, loaded_event)

	# Step (e): verify new key (T) is active and old key (W) is not
	assert_bool(InputMap.event_is_action(_make_key_event(_NEW_KEYCODE), _ACTION)).override_failure_message(
		"AC-4.4 step (e): T key must trigger move_forward after full round-trip."
	).is_true()
	assert_bool(InputMap.event_is_action(_make_key_event(_DEFAULT_KEYCODE), _ACTION)).override_failure_message(
		"AC-4.4 step (e): W key must NOT trigger move_forward after the rebind round-trip."
	).is_false()


# ── AC-4.4: round-trip preserves the keycode value exactly ──────────────────

func test_round_trip_preserves_exact_keycode_value() -> void:
	# Write + reload
	_write_rebinding(_CFG_PATH, _ACTION, _NEW_KEYCODE)
	var loaded: InputEventKey = _load_rebinding_event(_CFG_PATH, _ACTION)

	assert_int(loaded.physical_keycode).override_failure_message(
		"AC-4.4: round-trip must preserve exact keycode value (no float-to-int drift)."
	).is_equal(int(_NEW_KEYCODE))
