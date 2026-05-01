# tests/unit/core/footstep_component/footstep_cadence_all_states_test.gd
#
# FootstepCadenceAllStatesTest — GdUnit4 suite for Story FS-002 AC-2 (GDD
# AC-FC-1.2). Parametrized cadence checks for SPRINT and CROUCH.

class_name FootstepCadenceAllStatesTest
extends GdUnitTestSuite

const _PHYSICS_DELTA: float = 1.0 / 60.0
const _TICK_COUNT: int = 300

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


## AC-2: Sprint @ 3.0 Hz over 5 s → 15 ± 1 emissions.
func test_sprint_cadence_5s_yields_15_plus_minus_1_emissions() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.SPRINT)
	_player.velocity = Vector3(_player.sprint_speed, 0.0, 0.0)

	for _i: int in range(_TICK_COUNT):
		_fc._physics_process(_PHYSICS_DELTA)

	assert_int(_emit_count).override_failure_message(
		"Sprint cadence over 300 ticks should emit 14–16 times. Got: %d" % _emit_count
	).is_between(14, 16)


## AC-2: Crouch @ 1.6 Hz over 5 s → 8 ± 1 emissions.
func test_crouch_cadence_5s_yields_8_plus_minus_1_emissions() -> void:
	if not _player.is_on_floor():
		return
	_player._set_state(PlayerEnums.MovementState.CROUCH)
	_player.velocity = Vector3(_player.crouch_speed, 0.0, 0.0)

	for _i: int in range(_TICK_COUNT):
		_fc._physics_process(_PHYSICS_DELTA)

	assert_int(_emit_count).override_failure_message(
		"Crouch cadence over 300 ticks should emit 7–9 times. Got: %d" % _emit_count
	).is_between(7, 9)
