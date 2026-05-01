# tests/unit/core/player_character/player_sprint_speed_test.gd
#
# PlayerSprintSpeedTest — GdUnit4 suite for Story PC-003 AC-1.2.
#
# PURPOSE
#   Proves that sprinting from rest reaches sprint_speed ± 0.1 m/s within
#   12 physics frames (0.20 s @ 60 Hz). Default sprint_speed = 5.5 m/s.
#
# GATE STATUS
#   Story PC-003 | Logic type → BLOCKING gate.

class_name PlayerSprintSpeedTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0
const _SPRINT_FRAMES: int = 12
const _SPEED_TOLERANCE: float = 0.1

var _inst: PlayerCharacter = null
var _floor: StaticBody3D = null


func before_test() -> void:
	_floor = _build_floor()
	add_child(_floor)

	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)

	_inst.global_position = Vector3(0.0, 0.85, 0.0)
	_inst._physics_process(_PHYSICS_DELTA)


func after_test() -> void:
	if is_instance_valid(_floor):
		_floor.queue_free()
	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.SPRINT)


## AC-1.2: velocity.length() reaches sprint_speed ± 0.1 within 12 physics
## frames when forward input + sprint held from rest.
func test_sprint_speed_reaches_target_within_twelve_frames() -> void:
	# Arrange — press forward + sprint.
	Input.action_press(InputActions.MOVE_FORWARD)
	Input.action_press(InputActions.SPRINT)

	# Act — run 12 physics frames.
	for _i: int in range(_SPRINT_FRAMES):
		_inst._physics_process(_PHYSICS_DELTA)

	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.SPRINT)

	# Assert — planar speed within tolerance.
	var planar_speed: float = Vector2(_inst.velocity.x, _inst.velocity.z).length()
	assert_bool(
		absf(planar_speed - _inst.sprint_speed) <= _SPEED_TOLERANCE
	).override_failure_message(
		"Sprint speed after %d frames: expected %.3f ± %.3f m/s, got %.3f m/s" % [
			_SPRINT_FRAMES, _inst.sprint_speed, _SPEED_TOLERANCE, planar_speed
		]
	).is_true()


## AC-1.2: Default sprint_speed must be 5.5 m/s.
func test_sprint_speed_default_is_5p5() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	var fresh: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(fresh)

	assert_float(fresh.sprint_speed).override_failure_message(
		"Default sprint_speed must be 5.5 m/s per GDD Tuning Knobs."
	).is_equal_approx(5.5, 0.001)


# ── Helpers ────────────────────────────────────────────────────────────────

func _build_floor() -> StaticBody3D:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	col.shape = box
	floor_body.add_child(col)
	floor_body.global_position = Vector3(0.0, -0.1, 0.0)
	floor_body.set_collision_layer_value(PhysicsLayers.LAYER_WORLD, true)
	return floor_body
