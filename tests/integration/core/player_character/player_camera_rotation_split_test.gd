# tests/integration/core/player_character/player_camera_rotation_split_test.gd
#
# PlayerCameraRotationSplitTest — GdUnit4 integration suite for Story PC-002 AC-7.3.
#
# PURPOSE
#   Proves that yaw (horizontal mouse) rotates body.rotation.y only, and pitch
#   (vertical mouse) rotates camera.rotation.x only — with no cross-contamination.
#
# WHAT IS TESTED
#   AC-7.3: Yaw input (relative.x != 0) → body.rotation.y changes; camera.rotation.x
#           and camera.rotation.z remain 0.
#   AC-7.3: Pitch input (relative.y != 0) → camera.rotation.x changes; body.rotation.y
#           remains 0.
#   AC-7.3: Pure yaw input does NOT modify camera.rotation.x (no pitch contamination).
#
# INTEGRATION NOTE
#   Tests use Input.parse_input_event() + await physics_frame.
#   PlayerCharacter must be added to the scene tree for _unhandled_input to fire.
#   Each test instantiates a fresh PlayerCharacter to avoid shared rotation state.
#
# GATE STATUS
#   Story PC-002 | Integration type → BLOCKING gate.

class_name PlayerCameraRotationSplitTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _FLOAT_TOLERANCE: float = 0.0001


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_mouse_motion(relative: Vector2) -> InputEventMouseMotion:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.relative = relative
	return ev


func _instantiate_player() -> PlayerCharacter:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	var inst: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(inst)
	add_child(inst)
	return inst


# ---------------------------------------------------------------------------
# AC-7.3: Yaw input rotates body.rotation.y, not camera.rotation.x
# ---------------------------------------------------------------------------

## Pure horizontal mouse motion must rotate body.rotation.y only.
## camera.rotation.x (pitch) and camera.rotation.z (roll) must stay at 0.
## Implements: PC-002 AC-7.3.
func test_player_yaw_input_rotates_body_not_camera() -> void:
	# Arrange
	var inst: PlayerCharacter = _instantiate_player()
	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D

	var initial_body_y: float = inst.rotation.y  # should be 0 at spawn

	# Act — inject horizontal (yaw-only) mouse motion
	var ev: InputEventMouseMotion = _make_mouse_motion(Vector2(100.0, 0.0))
	Input.parse_input_event(ev)
	await get_tree().physics_frame

	# Assert — body.rotation.y changed (not still at initial)
	assert_bool(absf(inst.rotation.y - initial_body_y) > _FLOAT_TOLERANCE).override_failure_message(
		"body.rotation.y did not change after yaw input — look-left/right is broken."
	).is_true()

	# Assert — camera pitch and roll unchanged (no cross-contamination)
	assert_bool(absf(cam.rotation.x) <= _FLOAT_TOLERANCE).override_failure_message(
		"camera.rotation.x changed during yaw-only input (got %f) — yaw/pitch cross-contamination." % cam.rotation.x
	).is_true()
	assert_bool(absf(cam.rotation.z) <= _FLOAT_TOLERANCE).override_failure_message(
		"camera.rotation.z changed during yaw-only input (got %f) — unexpected roll." % cam.rotation.z
	).is_true()


# ---------------------------------------------------------------------------
# AC-7.3: Pitch input rotates camera.rotation.x, not body.rotation.y
# ---------------------------------------------------------------------------

## Pure vertical mouse motion must rotate camera.rotation.x only.
## body.rotation.y must remain unchanged.
## Implements: PC-002 AC-7.3.
func test_player_pitch_input_rotates_camera_not_body() -> void:
	# Arrange
	var inst: PlayerCharacter = _instantiate_player()
	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D

	var initial_body_y: float = inst.rotation.y  # should be 0 at spawn
	var initial_cam_x: float = cam.rotation.x    # should be 0 at spawn

	# Act — inject vertical (pitch-only) mouse motion
	var ev: InputEventMouseMotion = _make_mouse_motion(Vector2(0.0, 100.0))
	Input.parse_input_event(ev)
	await get_tree().physics_frame

	# Assert — camera.rotation.x changed
	assert_bool(absf(cam.rotation.x - initial_cam_x) > _FLOAT_TOLERANCE).override_failure_message(
		"camera.rotation.x did not change after pitch input — look-up/down is broken."
	).is_true()

	# Assert — body.rotation.y unchanged (no cross-contamination)
	assert_bool(absf(inst.rotation.y - initial_body_y) <= _FLOAT_TOLERANCE).override_failure_message(
		"body.rotation.y changed during pitch-only input (got %f) — pitch/yaw cross-contamination." % inst.rotation.y
	).is_true()


# ---------------------------------------------------------------------------
# AC-7.3: Yaw input does not modify camera.rotation.x (no pitch contamination)
# ---------------------------------------------------------------------------

## A large yaw motion must not bleed into camera.rotation.x.
## This is the regression guard for the body-yaw vs camera-pitch split contract.
## Implements: PC-002 AC-7.3.
func test_player_yaw_input_does_not_modify_camera_pitch() -> void:
	# Arrange
	var inst: PlayerCharacter = _instantiate_player()
	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D

	# Act — inject a large horizontal motion to amplify any contamination
	var ev: InputEventMouseMotion = _make_mouse_motion(Vector2(500.0, 0.0))
	Input.parse_input_event(ev)
	await get_tree().physics_frame

	# Assert — camera pitch axis remains zero
	assert_bool(absf(cam.rotation.x) <= _FLOAT_TOLERANCE).override_failure_message(
		"camera.rotation.x is %f after pure yaw input — must be 0 (no cross-contamination)." % cam.rotation.x
	).is_true()
