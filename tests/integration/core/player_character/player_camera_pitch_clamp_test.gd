# tests/integration/core/player_character/player_camera_pitch_clamp_test.gd
#
# PlayerCameraPitchClampTest — GdUnit4 integration suite for Story PC-002 AC-7.2.
#
# PURPOSE
#   Proves that Camera3D pitch is clamped to ±85° when synthetic mouse motion
#   events far exceeding the clamp limit are injected.
#
# SIGN CONVENTION
#   Camera3D +X rotation pitches the nose DOWN (Godot 4 convention).
#   Mouse down (positive relative.y) → _unhandled_input adds positive rotation.x
#   → clamped at +85° (deg_to_rad(85.0) ≈ 1.4835 rad).
#   Mouse up (negative relative.y) → rotation.x decreases → clamped at -85°.
#
# WHAT IS TESTED
#   AC-7.2: Large downward mouse push clamps camera.rotation.x at +85°.
#   AC-7.2: Large upward mouse push clamps camera.rotation.x at -85°.
#
# INTEGRATION NOTE
#   Input.parse_input_event() routes through the scene tree's _unhandled_input.
#   The PlayerCharacter must be added to the tree (add_child) for events to reach it.
#   One physics frame is awaited between injection and assertion.
#
# GATE STATUS
#   Story PC-002 | Integration type → BLOCKING gate.

class_name PlayerCameraPitchClampTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _CLAMP_DEG: float = 85.0
const _TOLERANCE_RAD: float = 0.001


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
	add_child(inst)  # triggers _ready() and makes the node receive input
	return inst


# ---------------------------------------------------------------------------
# AC-7.2: Downward pitch clamp at +85°
# ---------------------------------------------------------------------------

## Injecting a large downward mouse push (relative.y = 1,000,000) must clamp
## camera.rotation.x to +85° (looking down). The clamp must be tight: the
## result must be within ±tolerance of deg_to_rad(85.0), not just "below it".
## Implements: PC-002 AC-7.2.
func test_player_camera_pitch_clamps_at_positive_85_degrees_when_looking_down() -> void:
	# Arrange
	var inst: PlayerCharacter = _instantiate_player()
	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D
	assert_object(cam).override_failure_message(
		"Camera3D child not found."
	).is_not_null()

	# Act — inject enormous downward mouse motion to drive past the +85° clamp
	var ev: InputEventMouseMotion = _make_mouse_motion(Vector2(0.0, 1_000_000.0))
	Input.parse_input_event(ev)
	await get_tree().physics_frame

	# Assert — rotation.x must be exactly at the +85° clamp (within tolerance)
	var clamp_rad: float = deg_to_rad(_CLAMP_DEG)
	assert_bool(cam.rotation.x <= clamp_rad + _TOLERANCE_RAD).override_failure_message(
		"camera.rotation.x exceeded +85° clamp (got %f rad, limit %f rad)." % [cam.rotation.x, clamp_rad]
	).is_true()
	assert_bool(cam.rotation.x >= clamp_rad - _TOLERANCE_RAD).override_failure_message(
		"camera.rotation.x did not reach +85° clamp — clamp not applied or wrong sign convention (got %f rad)." % cam.rotation.x
	).is_true()


# ---------------------------------------------------------------------------
# AC-7.2: Upward pitch clamp at -85°
# ---------------------------------------------------------------------------

## Injecting a large upward mouse push (relative.y = -1,000,000) must clamp
## camera.rotation.x to -85° (looking up).
## Implements: PC-002 AC-7.2.
func test_player_camera_pitch_clamps_at_negative_85_degrees_when_looking_up() -> void:
	# Arrange
	var inst: PlayerCharacter = _instantiate_player()
	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D
	assert_object(cam).override_failure_message(
		"Camera3D child not found."
	).is_not_null()

	# Act — inject enormous upward mouse motion to drive past the -85° clamp
	var ev: InputEventMouseMotion = _make_mouse_motion(Vector2(0.0, -1_000_000.0))
	Input.parse_input_event(ev)
	await get_tree().physics_frame

	# Assert — rotation.x must be exactly at the -85° clamp (within tolerance)
	var clamp_rad: float = deg_to_rad(_CLAMP_DEG)
	assert_bool(cam.rotation.x >= -clamp_rad - _TOLERANCE_RAD).override_failure_message(
		"camera.rotation.x exceeded -85° clamp (got %f rad, limit %f rad)." % [cam.rotation.x, -clamp_rad]
	).is_true()
	assert_bool(cam.rotation.x <= -clamp_rad + _TOLERANCE_RAD).override_failure_message(
		"camera.rotation.x did not reach -85° clamp — clamp not applied or wrong sign convention (got %f rad)." % cam.rotation.x
	).is_true()
