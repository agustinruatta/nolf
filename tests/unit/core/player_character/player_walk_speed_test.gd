# tests/unit/core/player_character/player_walk_speed_test.gd
#
# PlayerWalkSpeedTest — GdUnit4 suite for Story PC-003 AC-1.1.
#
# PURPOSE
#   Proves that walking on flat terrain with input_magnitude == 1.0 reaches
#   walk_speed ± 0.1 m/s within 9 physics frames (0.15 s @ 60 Hz).
#   Default walk_speed = 3.5 m/s.
#
# GATE STATUS
#   Story PC-003 | Logic type → BLOCKING gate.

class_name PlayerWalkSpeedTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0
const _WALK_FRAMES: int = 9
const _SPEED_TOLERANCE: float = 0.1

var _inst: PlayerCharacter = null
var _floor: StaticBody3D = null


func before_test() -> void:
	# Build a minimal flat floor so is_on_floor() can return true.
	_floor = _build_floor()
	add_child(_floor)

	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)

	# Place player standing on the floor (floor surface at Y=0, capsule half-height ≈ 0.85).
	_inst.global_position = Vector3(0.0, 0.85, 0.0)

	# Simulate one tick to settle on floor before the test.
	_inst._physics_process(_PHYSICS_DELTA)


func after_test() -> void:
	if is_instance_valid(_floor):
		_floor.queue_free()
	Input.action_release(InputActions.MOVE_FORWARD)


## AC-1.1: velocity.length() reaches walk_speed ± 0.1 within 9 physics frames
## when moving forward with full input and no sprint held.
func test_walk_speed_reaches_target_within_nine_frames() -> void:
	# Arrange — press forward, no sprint.
	Input.action_press(InputActions.MOVE_FORWARD)

	# Act — run 9 physics frames.
	for _i: int in range(_WALK_FRAMES):
		_inst._physics_process(_PHYSICS_DELTA)

	Input.action_release(InputActions.MOVE_FORWARD)

	# Assert — planar speed within tolerance.
	var planar_speed: float = Vector2(_inst.velocity.x, _inst.velocity.z).length()
	assert_bool(
		absf(planar_speed - _inst.walk_speed) <= _SPEED_TOLERANCE
	).override_failure_message(
		"Walk speed after %d frames: expected %.3f ± %.3f m/s, got %.3f m/s" % [
			_WALK_FRAMES, _inst.walk_speed, _SPEED_TOLERANCE, planar_speed
		]
	).is_true()


## AC-1.1: Default walk_speed must be 3.5 m/s.
func test_walk_speed_default_is_3p5() -> void:
	# Arrange + Act — read default export.
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	var fresh: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(fresh)

	# Assert.
	assert_float(fresh.walk_speed).override_failure_message(
		"Default walk_speed must be 3.5 m/s per GDD Tuning Knobs."
	).is_equal_approx(3.5, 0.001)


# ── Helpers ────────────────────────────────────────────────────────────────

## Builds a flat StaticBody3D floor at Y=0 the player can stand on.
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
