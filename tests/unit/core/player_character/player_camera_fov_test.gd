# tests/unit/core/player_character/player_camera_fov_test.gd
#
# PlayerCameraFovTest — GdUnit4 suite for Story PC-002 AC-7.1 + AC-7.5.
#
# PURPOSE
#   Proves that Camera3D FOV is set to 75° at _ready() and remains constant
#   across all movement state transitions (no FOV punch on sprint, walk, etc.).
#
# WHAT IS TESTED
#   AC-7.1: _ready() sets Camera3D.fov = 75.0 ± 0.1.
#   AC-7.1: @export var camera_fov: float is present in source (designer-tunable).
#   AC-7.5: camera_fov is constant across IDLE → WALK → SPRINT → CROUCH states.
#
# GATE STATUS
#   Story PC-002 | Logic type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name PlayerCameraFovTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _SCRIPT_PATH: String = "res://src/gameplay/player/player_character.gd"
const _FOV_TOLERANCE: float = 0.1
const _EXPECTED_FOV: float = 75.0


# ---------------------------------------------------------------------------
# AC-7.1: Camera3D.fov defaults to 75° after _ready()
# ---------------------------------------------------------------------------

## At _ready(), Camera3D.fov must equal 75.0 within tolerance 0.1°.
## Implements: PC-002 AC-7.1.
func test_player_camera_fov_defaults_to_75() -> void:
	# Arrange
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	assert_object(packed).override_failure_message(
		"PlayerCharacter.tscn could not be loaded."
	).is_not_null()

	var inst: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(inst)
	add_child(inst)  # triggers _ready()

	# Act
	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D
	assert_object(cam).override_failure_message(
		"Camera3D child not found — scene hierarchy incomplete."
	).is_not_null()

	# Assert — FOV within tolerance
	assert_bool(absf(cam.fov - _EXPECTED_FOV) <= _FOV_TOLERANCE).override_failure_message(
		"Camera3D.fov must be 75.0 ± 0.1 after _ready() (got %f)." % cam.fov
	).is_true()


# ---------------------------------------------------------------------------
# AC-7.1: @export var camera_fov: float present in source (designer-tunable)
# ---------------------------------------------------------------------------

## player_character.gd must declare `@export var camera_fov: float` so
## designers can override FOV per scene instance without touching code.
## Implements: PC-002 AC-7.1 (Tuning Knobs §Camera).
func test_player_camera_fov_export_var_present() -> void:
	# Arrange
	var source: String = FileAccess.get_file_as_string(_SCRIPT_PATH)
	assert_bool(source.length() > 0).override_failure_message(
		"player_character.gd could not be read — file missing or empty."
	).is_true()

	# Act + Assert
	assert_bool(source.find("@export var camera_fov: float") != -1).override_failure_message(
		"player_character.gd must declare '@export var camera_fov: float' (designer-tunable per GDD Tuning Knobs §Camera)."
	).is_true()


# ---------------------------------------------------------------------------
# AC-7.5: camera_fov constant across IDLE → WALK → SPRINT → CROUCH
# ---------------------------------------------------------------------------

## FOV must not change when movement state is forced through all states.
## No walk head-bob, no sprint FOV punch, no damage vignette per GDD Forbidden Patterns.
## Implements: PC-002 AC-7.5.
func test_player_camera_fov_unchanged_across_movement_states() -> void:
	# Arrange
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	var inst: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(inst)
	add_child(inst)  # triggers _ready()

	var cam: Camera3D = inst.get_node(^"Camera3D") as Camera3D
	assert_object(cam).override_failure_message(
		"Camera3D child not found."
	).is_not_null()

	var expected_fov: float = inst.camera_fov

	# Act + Assert — cycle through all movement states and verify FOV unchanged
	var states: Array[PlayerEnums.MovementState] = [
		PlayerEnums.MovementState.IDLE,
		PlayerEnums.MovementState.WALK,
		PlayerEnums.MovementState.SPRINT,
		PlayerEnums.MovementState.CROUCH,
	]

	for state: PlayerEnums.MovementState in states:
		inst.current_state = state
		await get_tree().physics_frame

		assert_bool(absf(cam.fov - expected_fov) <= _FOV_TOLERANCE).override_failure_message(
			"Camera3D.fov changed to %f in state %d — FOV punch is forbidden (GDD Forbidden Patterns)." % [cam.fov, state]
		).is_true()
