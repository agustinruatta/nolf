# tests/unit/core/footstep_component/footstep_state_transition_test.gd
#
# FootstepStateTransitionTest — GdUnit4 suite for Story FS-002 AC-3 (GDD
# AC-FC-1.3). Walk → Sprint mid-interval transition.

class_name FootstepStateTransitionTest
extends GdUnitTestSuite

const _PHYSICS_DELTA: float = 1.0 / 60.0

var _player: PlayerCharacter = null
var _floor: StaticBody3D = null
var _fc: FootstepComponent = null
var _emit_times: Array[int] = []
var _tick_index: int = 0


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

	_emit_times = []
	_tick_index = 0
	if not Events.player_footstep.is_connected(_on_footstep):
		Events.player_footstep.connect(_on_footstep)


func after_test() -> void:
	if Events.player_footstep.is_connected(_on_footstep):
		Events.player_footstep.disconnect(_on_footstep)
	if is_instance_valid(_floor):
		_floor.queue_free()


func _on_footstep(_surface: StringName, _radius: float) -> void:
	_emit_times.append(_tick_index)


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


## AC-3: Walk for 14 ticks → switch to Sprint → first Sprint step within
## 1 / cadence_sprint_hz seconds (≤ 0.333 s = 20 ticks @ 60 Hz).
func test_walk_to_sprint_first_step_within_sprint_interval() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.WALK)
	_player.velocity = Vector3(_player.walk_speed, 0.0, 0.0)

	for _i: int in range(14):
		_tick_index += 1
		_fc._physics_process(_PHYSICS_DELTA)
	assert_int(_emit_times.size()).override_failure_message(
		"Walk for 14 ticks should produce 0 emissions (interval not yet reached)."
	).is_equal(0)

	_player._set_state(PlayerEnums.MovementState.SPRINT)
	_player.velocity = Vector3(_player.sprint_speed, 0.0, 0.0)
	var transition_tick: int = _tick_index

	const MAX_LOOK_AHEAD: int = 25
	for _i: int in range(MAX_LOOK_AHEAD):
		_tick_index += 1
		_fc._physics_process(_PHYSICS_DELTA)
		if _emit_times.size() > 0:
			break

	assert_int(_emit_times.size()).override_failure_message(
		"After Walk→Sprint transition, first emission must occur within %d ticks." % MAX_LOOK_AHEAD
	).is_greater(0)
	var first_sprint_emit_tick: int = _emit_times[0]
	var ticks_since_transition: int = first_sprint_emit_tick - transition_tick
	assert_int(ticks_since_transition).override_failure_message(
		"First Sprint step must fire within ≤20 ticks of transition. Got: %d ticks." % ticks_since_transition
	).is_less_equal(20)
	assert_int(ticks_since_transition).override_failure_message(
		"First Sprint step must NOT fire on the same tick as the state transition (>0 ticks)."
	).is_greater(0)
