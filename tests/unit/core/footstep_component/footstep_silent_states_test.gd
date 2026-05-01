# tests/unit/core/footstep_component/footstep_silent_states_test.gd
#
# FootstepSilentStatesTest — GdUnit4 suite for Story FS-002 AC-4, AC-5, AC-6.

class_name FootstepSilentStatesTest
extends GdUnitTestSuite

const _PHYSICS_DELTA: float = 1.0 / 60.0

var _player: PlayerCharacter = null
var _floor: StaticBody3D = null
var _fc: FootstepComponent = null
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

	_emit_count = 0
	if not Events.player_footstep.is_connected(_on_footstep):
		Events.player_footstep.connect(_on_footstep)


func after_test() -> void:
	if Events.player_footstep.is_connected(_on_footstep):
		Events.player_footstep.disconnect(_on_footstep)
	if is_instance_valid(_floor):
		_floor.queue_free()


func _on_footstep(_surface: StringName, _radius: float) -> void:
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


## AC-4: Idle / Jump / Fall / Dead — zero emissions across 720 ticks (3 s each).
func test_silent_states_emit_zero_footsteps() -> void:
	if not _player.is_on_floor():
		return
	const TICKS_PER_STATE: int = 180
	var states: Array[PlayerEnums.MovementState] = [
		PlayerEnums.MovementState.IDLE,
		PlayerEnums.MovementState.JUMP,
		PlayerEnums.MovementState.FALL,
		PlayerEnums.MovementState.DEAD,
	]
	for state: PlayerEnums.MovementState in states:
		_player._set_state(state)
		_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)
		for _i: int in range(TICKS_PER_STATE):
			_fc._physics_process(_PHYSICS_DELTA)

	assert_int(_emit_count).override_failure_message(
		"Idle/Jump/Fall/Dead must emit ZERO footsteps over 720 ticks. Got: %d" % _emit_count
	).is_equal(0)


## AC-5 (FC.E.3): Walk-still — velocity below idle_velocity_threshold suppresses emission.
func test_walk_still_below_idle_threshold_emits_zero() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3.ZERO

	for _i: int in range(180):
		_fc._physics_process(_PHYSICS_DELTA)

	assert_int(_emit_count).override_failure_message(
		"Walk with velocity = ZERO must emit 0 footsteps. Got: %d" % _emit_count
	).is_equal(0)
	assert_float(_fc._step_accumulator).override_failure_message(
		"Accumulator must not advance while velocity is below threshold. Got: %.4f" % _fc._step_accumulator
	).is_equal_approx(0.0, 0.001)


## AC-5: Crouch-still also suppresses.
func test_crouch_still_emits_zero() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.CROUCH)
	_player.velocity = Vector3.ZERO

	for _i: int in range(180):
		_fc._physics_process(_PHYSICS_DELTA)

	assert_int(_emit_count).is_equal(0)


## AC-6: Accumulator resets to 0 when transitioning to a non-emitting state.
func test_accumulator_resets_on_transition_to_non_emitting_state() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)

	for _i: int in range(14):
		_fc._physics_process(_PHYSICS_DELTA)
	assert_float(_fc._step_accumulator).override_failure_message(
		"Accumulator after 14 Walk ticks must be > 0 (sanity)."
	).is_greater(0.0)

	_player._set_state(PlayerEnums.MovementState.IDLE)
	_fc._physics_process(_PHYSICS_DELTA)
	assert_float(_fc._step_accumulator).override_failure_message(
		"Accumulator must reset to 0.0 on transition to non-emitting state. Got: %.4f" % _fc._step_accumulator
	).is_equal_approx(0.0, 0.001)


## AC-6: After re-entry, first emission requires a FULL interval.
func test_accumulator_reentry_waits_full_interval() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)
	for _i: int in range(14):
		_fc._physics_process(_PHYSICS_DELTA)

	_player._set_state(PlayerEnums.MovementState.IDLE)
	_fc._physics_process(_PHYSICS_DELTA)
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)
	_emit_count = 0

	for _i: int in range(26):
		_fc._physics_process(_PHYSICS_DELTA)
	assert_int(_emit_count).override_failure_message(
		"After re-entry to Walk, no emission within 26 ticks (~0.433 s)."
	).is_equal(0)

	for _i: int in range(5):
		_fc._physics_process(_PHYSICS_DELTA)
	assert_int(_emit_count).override_failure_message(
		"After re-entry, first Walk emission must fire within 31 ticks total."
	).is_greater_equal(1)
