# tests/unit/core/player_character/player_crouch_speed_test.gd
#
# PlayerCrouchSpeedTest — GdUnit4 suite for Story PC-003 AC-1.3.
#
# PURPOSE
#   Proves that:
#   (a) Crouch-walk reaches crouch_speed ± 0.1 m/s within 9 physics frames.
#   (b) CapsuleShape3D.height == 1.1 m when fully crouched
#       (tests _on_crouch_progress(1.0) directly — tween time-advancement
#       is not reliable in headless mode).
#   Default crouch_speed = 1.8 m/s.
#
# NOTE ON HEADLESS TESTING
#   Input.is_action_just_pressed() is not dispatched in headless mode.
#   Crouch is entered by calling _handle_crouch_toggle() directly.
#   Tween advancement is not reliable when _physics_process is called manually
#   outside the real engine main loop; the capsule height test calls
#   _on_crouch_progress(1.0) directly to verify the fully-crouched height.
#
# GATE STATUS
#   Story PC-003 | Logic type → BLOCKING gate.

class_name PlayerCrouchSpeedTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0
const _CROUCH_FRAMES: int = 9
const _SPEED_TOLERANCE: float = 0.1
## Tolerance for capsule height check (m).
const _HEIGHT_TOLERANCE: float = 0.05

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
	Input.action_release(InputActions.CROUCH)


## AC-1.3a: Crouch-walk speed reaches crouch_speed ± 0.1 within 9 frames.
func test_crouch_walk_speed_reaches_target_within_nine_frames() -> void:
	# Arrange — enter crouch directly (bypasses headless input limitation).
	_inst._handle_crouch_toggle()
	_inst._physics_process(_PHYSICS_DELTA)

	Input.action_press(InputActions.MOVE_FORWARD)

	# Act — run 9 physics frames while crouched.
	for _i: int in range(_CROUCH_FRAMES):
		_inst._physics_process(_PHYSICS_DELTA)

	Input.action_release(InputActions.MOVE_FORWARD)

	# Assert — state is CROUCH and planar speed within tolerance.
	assert_int(_inst.current_state).override_failure_message(
		"State must be CROUCH when crouching with forward input."
	).is_equal(PlayerEnums.MovementState.CROUCH)

	var planar_speed: float = Vector2(_inst.velocity.x, _inst.velocity.z).length()
	assert_bool(
		absf(planar_speed - _inst.crouch_speed) <= _SPEED_TOLERANCE
	).override_failure_message(
		"Crouch-walk speed after %d frames: expected %.3f ± %.3f m/s, got %.3f m/s" % [
			_CROUCH_FRAMES, _inst.crouch_speed, _SPEED_TOLERANCE, planar_speed
		]
	).is_true()


## AC-1.3b: CapsuleShape3D.height == 1.1 m when fully crouched.
## Calls _on_crouch_progress(1.0) directly — tween is not reliably advanced
## in headless mode when _physics_process is called manually.
func test_crouch_capsule_height_is_1p1_when_fully_crouched() -> void:
	# Act — drive the crouch progress callback to full (1.0 = fully crouched).
	_inst._on_crouch_progress(1.0)

	# Assert — capsule height should be _CROUCH_HEIGHT = 1.1 m.
	var col_shape: CollisionShape3D = _inst.get_node(^"CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = col_shape.shape as CapsuleShape3D
	assert_bool(
		absf(capsule.height - 1.1) <= _HEIGHT_TOLERANCE
	).override_failure_message(
		"CapsuleShape3D.height at full crouch: expected 1.1 ± %.2f m, got %.4f m" % [
			_HEIGHT_TOLERANCE, capsule.height
		]
	).is_true()

	# Also verify _crouch_transition_progress was updated.
	assert_float(_inst._crouch_transition_progress).override_failure_message(
		"_crouch_transition_progress must be 1.0 after _on_crouch_progress(1.0)."
	).is_equal_approx(1.0, 0.001)


## AC-1.3b: CapsuleShape3D.height == 1.7 m when fully standing (progress = 0.0).
func test_crouch_capsule_height_is_1p7_when_fully_standing() -> void:
	# Act — drive progress to 0.0 (fully standing).
	_inst._on_crouch_progress(0.0)

	var col_shape: CollisionShape3D = _inst.get_node(^"CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = col_shape.shape as CapsuleShape3D
	assert_bool(
		absf(capsule.height - 1.7) <= _HEIGHT_TOLERANCE
	).override_failure_message(
		"CapsuleShape3D.height at full stand: expected 1.7 ± %.2f m, got %.4f m" % [
			_HEIGHT_TOLERANCE, capsule.height
		]
	).is_true()


## AC-1.3: Default crouch_speed must be 1.8 m/s.
func test_crouch_speed_default_is_1p8() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	var fresh: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(fresh)

	assert_float(fresh.crouch_speed).override_failure_message(
		"Default crouch_speed must be 1.8 m/s per GDD Tuning Knobs."
	).is_equal_approx(1.8, 0.001)


# ── Helpers ────────────────────────────────────────────────────────────────

func _build_floor() -> StaticBody3D:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	col.shape = box
	floor_body.add_child(col)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	floor_body.set_collision_layer_value(PhysicsLayers.LAYER_WORLD, true)
	return floor_body
