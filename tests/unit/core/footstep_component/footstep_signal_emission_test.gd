# tests/unit/core/footstep_component/footstep_signal_emission_test.gd
#
# FootstepSignalEmissionTest — GdUnit4 suite for Story FS-004.
# Consolidates AC-1 (PC pure-observer), AC-2 (no _latched_event mutation),
# AC-3 (purity grep lint), AC-4 (Events autoload route), AC-5 (rate guard),
# AC-6 (Audio integration: surface + noise_radius_m payload).
#
# GATE STATUS
#   Story FS-004 | Integration type → BLOCKING gate.
#   TR-FC-001, TR-FC-005, TR-FC-007.

class_name FootstepSignalEmissionTest
extends GdUnitTestSuite

const _PHYSICS_DELTA: float = 1.0 / 60.0
const _SOURCE_PATH: String = "res://src/gameplay/player/footstep_component.gd"

var _player: PlayerCharacter = null
var _floor: StaticBody3D = null
var _surface_body: StaticBody3D = null  # tagged body for surface tests
var _fc: FootstepComponent = null
var _last_surface: StringName = &""
var _last_noise: float = -1.0
var _emit_count: int = 0


func before_test() -> void:
	_floor = _build_floor()
	add_child(_floor)

	var packed: PackedScene = load("res://src/gameplay/player/PlayerCharacter.tscn") as PackedScene
	_player = packed.instantiate() as PlayerCharacter
	auto_free(_player)
	add_child(_player)
	_player.global_position = Vector3(0.0, 0.85, 0.0)
	for _i: int in range(3):
		_player._physics_process(_PHYSICS_DELTA)

	_fc = FootstepComponent.new()
	auto_free(_fc)
	_player.add_child(_fc)

	_last_surface = &""
	_last_noise = -1.0
	_emit_count = 0
	if not Events.player_footstep.is_connected(_on_footstep):
		Events.player_footstep.connect(_on_footstep)


func after_test() -> void:
	if Events.player_footstep.is_connected(_on_footstep):
		Events.player_footstep.disconnect(_on_footstep)
	if is_instance_valid(_floor):
		_floor.queue_free()
	if _surface_body != null and is_instance_valid(_surface_body):
		_surface_body.queue_free()


func _on_footstep(surface: StringName, noise_radius_m: float) -> void:
	_last_surface = surface
	_last_noise = noise_radius_m
	_emit_count += 1


func _build_floor() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0.0, -0.1, 0.0)
	body.set_collision_layer_value(PhysicsLayers.LAYER_WORLD, true)
	return body


func _build_marble_pad() -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 0.1, 2.0)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0.0, 0.4, 0.0)
	body.set_collision_layer_value(PhysicsLayers.LAYER_WORLD, true)
	body.set_meta("surface_tag", &"marble")
	return body


# ── AC-1: PC pure-observer (FC presence doesn't affect get_noise_level()) ───

func test_fc_presence_does_not_change_player_noise_level() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)
	var noise_before: float = _player.get_noise_level()

	# Drive enough ticks for several emissions.
	for _i: int in range(120):
		_fc._physics_process(_PHYSICS_DELTA)

	var noise_after: float = _player.get_noise_level()
	assert_float(noise_after).override_failure_message(
		"FC presence must NOT mutate PC's get_noise_level() return. before=%.4f, after=%.4f" % [noise_before, noise_after]
	).is_equal_approx(noise_before, 0.0001)


# ── AC-2: _latched_event remains null after 100 emissions ────────────────────

func test_fc_emissions_do_not_mutate_player_latched_event() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)
	# Initial state — no spike.
	_player._latched_event = null
	_player._latch_frames_remaining = 0

	for _i: int in range(120):
		_fc._physics_process(_PHYSICS_DELTA)

	assert_object(_player._latched_event).override_failure_message(
		"FC emissions must NOT touch player._latched_event. Got: %s" % [_player._latched_event]
	).is_null()


# ── AC-3: Purity grep lint — no mutation assignments in source ───────────────

func test_footstep_component_source_has_no_mutation_assignments() -> void:
	var f: FileAccess = FileAccess.open(_SOURCE_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	var content: String = f.get_as_text()
	f.close()
	# Pattern: assignment to player.<forbidden>
	# Forbidden fields: health, current_state, velocity, _latched_event
	var re: RegEx = RegEx.new()
	re.compile("_player\\.(health|current_state|velocity|_latched_event)\\s*=")
	var match: RegExMatch = re.search(content)
	assert_object(match).override_failure_message(
		"footstep_component.gd MUST NOT assign to PC's health/current_state/velocity/_latched_event. Match: %s"
			% [match.get_string(0) if match != null else "<none>"]
	).is_null()


# ── AC-4: Signal route via Events autoload ───────────────────────────────────

func test_emission_routes_through_events_autoload_not_direct_signal() -> void:
	# The handler this test connects in before_test() is on Events.player_footstep.
	# If the FC used emit_signal("player_footstep", ...) on itself, the handler
	# wouldn't fire. So emission count > 0 proves the route.
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)

	# Drive enough ticks for ≥ 1 walk emission (~27 frames at 2.2 Hz).
	for _i: int in range(60):
		_fc._physics_process(_PHYSICS_DELTA)

	assert_int(_emit_count).override_failure_message(
		"Walk for 60 ticks should produce ≥1 emission via Events autoload route. Got: %d" % _emit_count
	).is_greater_equal(1)


## Static check: source must contain `Events.player_footstep.emit(` and NOT
## contain `emit_signal("player_footstep"` (the wrapper-emit anti-pattern).
func test_source_uses_events_autoload_emit_pattern() -> void:
	var f: FileAccess = FileAccess.open(_SOURCE_PATH, FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	assert_str(content).override_failure_message(
		"footstep_component.gd must emit via 'Events.player_footstep.emit(...)'."
	).contains("Events.player_footstep.emit(")
	assert_bool("emit_signal(\"player_footstep\"" in content).override_failure_message(
		"footstep_component.gd must NOT use emit_signal('player_footstep'); use Events autoload."
	).is_false()


# ── AC-5: Emission rate guard — no 60-tick window > 4 emissions ──────────────

func test_emission_rate_never_exceeds_four_per_second_window() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.SPRINT)
	_player.velocity = Vector3(_player.sprint_speed, 0.0, 0.0)

	var emit_per_tick: Array[int] = []
	emit_per_tick.resize(600)
	emit_per_tick.fill(0)
	# Custom counter that records per-tick emissions.
	var per_tick_count: int = 0
	var prev_count: int = 0
	for tick: int in range(600):
		_fc._physics_process(_PHYSICS_DELTA)
		emit_per_tick[tick] = _emit_count - prev_count
		prev_count = _emit_count

	# Sliding 60-tick window scan.
	var max_per_window: int = 0
	for start: int in range(0, 600 - 60):
		var window_sum: int = 0
		for offset: int in range(60):
			window_sum += emit_per_tick[start + offset]
		max_per_window = maxi(max_per_window, window_sum)

	assert_int(max_per_window).override_failure_message(
		"Sprint emission rate must stay ≤4 per 60-tick window. Got max: %d" % max_per_window
	).is_less_equal(4)


# ── AC-6: Audio handoff payload (surface + noise_radius_m) ──────────────────

func test_audio_handoff_receives_surface_and_noise_radius() -> void:
	if not _player.is_on_floor():
		return
	# Spawn marble pad below player.
	_surface_body = _build_marble_pad()
	add_child(_surface_body)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)

	# Drive enough ticks for ≥ 1 emission.
	for _i: int in range(60):
		_fc._physics_process(_PHYSICS_DELTA)

	assert_int(_emit_count).override_failure_message(
		"Audio handoff: at least 1 emission required. Got: %d" % _emit_count
	).is_greater_equal(1)
	assert_str(String(_last_surface)).override_failure_message(
		"Audio handoff: surface must be 'marble' (matches body's surface_tag meta). Got: %s" % [String(_last_surface)]
	).is_equal("marble")
	# noise_radius_m must equal player.get_noise_level() at emission time.
	# get_noise_level() in WALK with moving velocity returns noise_walk × multiplier = 5.0.
	var expected_noise: float = _player.get_noise_level()
	assert_float(_last_noise).override_failure_message(
		"Audio handoff: noise_radius_m must equal get_noise_level(). expected=%.4f, got=%.4f"
			% [expected_noise, _last_noise]
	).is_equal_approx(expected_noise, 0.001)
