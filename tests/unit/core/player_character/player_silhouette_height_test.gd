# tests/unit/core/player_character/player_silhouette_height_test.gd
#
# PlayerSilhouetteHeightTest — GdUnit4 suite for Story PC-004 AC-6bis.1.
#
# PURPOSE
#   Verifies get_silhouette_height() returns the correct metres value for every
#   combination of (state, _crouch_transition_progress):
#     • Standing  (IDLE/WALK/SPRINT, progress 0.0) → 1.7 ± 0.001 m
#     • Crouched  (CROUCH, progress 1.0)            → 1.1 ± 0.001 m
#     • Mid       (any non-DEAD, progress 0.5)      → 1.4 ± 0.001 m
#     • Dead      (DEAD, any progress)              → 0.4 ± 0.001 m
#
#   The DEAD branch must short-circuit BEFORE the lerp — `_crouch_transition_progress`
#   is irrelevant when the player is dead. This is defense-in-depth: a respawn
#   reset (Story 007) MAY leave _crouch_transition_progress at a non-zero value
#   transiently; the silhouette height must still report 0.4 m for AI visibility.
#
# METHOD
#   Pure read tests. Sets `current_state` directly via _set_state() and writes
#   `_crouch_transition_progress` directly. No physics ticks needed.
#
# GATE STATUS
#   Story PC-004 | Logic type → BLOCKING gate. TR-PC-018.

class_name PlayerSilhouetteHeightTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0
const _TOLERANCE: float = 0.001

var _inst: PlayerCharacter = null


func before_test() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)
	_inst._physics_process(_PHYSICS_DELTA)  # run _ready()


## AC-6bis.1: Standing IDLE + progress 0.0 → 1.7 m.
func test_silhouette_height_standing_idle_returns_1p7() -> void:
	_inst._set_state(PlayerEnums.MovementState.IDLE)
	_inst._crouch_transition_progress = 0.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"IDLE + progress 0.0 must return silhouette_height_standing (1.7 m)."
	).is_equal_approx(1.7, _TOLERANCE)


## AC-6bis.1: Standing WALK + progress 0.0 → 1.7 m.
func test_silhouette_height_walking_returns_1p7() -> void:
	_inst._set_state(PlayerEnums.MovementState.WALK)
	_inst._crouch_transition_progress = 0.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"WALK + progress 0.0 must return 1.7 m."
	).is_equal_approx(1.7, _TOLERANCE)


## AC-6bis.1: Standing SPRINT + progress 0.0 → 1.7 m.
func test_silhouette_height_sprinting_returns_1p7() -> void:
	_inst._set_state(PlayerEnums.MovementState.SPRINT)
	_inst._crouch_transition_progress = 0.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"SPRINT + progress 0.0 must return 1.7 m."
	).is_equal_approx(1.7, _TOLERANCE)


## AC-6bis.1: Crouched (CROUCH state, progress 1.0) → 1.1 m.
func test_silhouette_height_crouched_returns_1p1() -> void:
	_inst._set_state(PlayerEnums.MovementState.CROUCH)
	_inst._crouch_transition_progress = 1.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"CROUCH + progress 1.0 must return silhouette_height_crouched (1.1 m)."
	).is_equal_approx(1.1, _TOLERANCE)


## AC-6bis.1: Mid-transition (progress 0.5) → 1.4 m (lerp midpoint of 1.7 and 1.1).
func test_silhouette_height_mid_transition_returns_1p4() -> void:
	_inst._set_state(PlayerEnums.MovementState.WALK)
	_inst._crouch_transition_progress = 0.5

	# 1.7 + (1.1 - 1.7) * 0.5 = 1.7 - 0.3 = 1.4
	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"progress 0.5 must return lerp midpoint 1.4 m (between 1.7 and 1.1)."
	).is_equal_approx(1.4, _TOLERANCE)


## AC-6bis.1: Mid-transition CROUCH state (progress 0.5) → 1.4 m.
## State alone does not change the height — progress is the source of truth.
func test_silhouette_height_mid_transition_crouch_state_returns_1p4() -> void:
	_inst._set_state(PlayerEnums.MovementState.CROUCH)
	_inst._crouch_transition_progress = 0.5

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"CROUCH state + progress 0.5 must return 1.4 m (state ignored when computing height)."
	).is_equal_approx(1.4, _TOLERANCE)


## AC-6bis.1: DEAD (any progress) → 0.4 m. DEAD short-circuits the lerp.
func test_silhouette_height_dead_returns_0p4_at_progress_zero() -> void:
	_inst._set_state(PlayerEnums.MovementState.DEAD)
	_inst._crouch_transition_progress = 0.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"DEAD + progress 0.0 must return silhouette_height_dead (0.4 m), not 1.7."
	).is_equal_approx(0.4, _TOLERANCE)


## AC-6bis.1: DEAD with progress 1.0 still returns 0.4 m (DEAD takes priority).
func test_silhouette_height_dead_returns_0p4_at_progress_one() -> void:
	_inst._set_state(PlayerEnums.MovementState.DEAD)
	_inst._crouch_transition_progress = 1.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"DEAD + progress 1.0 must still return 0.4 m (DEAD short-circuits lerp)."
	).is_equal_approx(0.4, _TOLERANCE)


## AC-6bis.1: DEAD with mid-transition progress still returns 0.4 m.
## Defense-in-depth: respawn reset may leave progress mid-flight; visibility
## must still report the prone height.
func test_silhouette_height_dead_returns_0p4_at_mid_progress() -> void:
	_inst._set_state(PlayerEnums.MovementState.DEAD)
	_inst._crouch_transition_progress = 0.5

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"DEAD + progress 0.5 must still return 0.4 m (DEAD short-circuits)."
	).is_equal_approx(0.4, _TOLERANCE)


## Sanity: standing height export knob change is reflected in the return.
## Proves the function reads `silhouette_height_standing` rather than a hardcoded 1.7.
func test_silhouette_height_respects_standing_export_knob() -> void:
	_inst.silhouette_height_standing = 1.85
	_inst._set_state(PlayerEnums.MovementState.IDLE)
	_inst._crouch_transition_progress = 0.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"After setting silhouette_height_standing = 1.85, returned height must follow."
	).is_equal_approx(1.85, _TOLERANCE)


## Sanity: crouched export knob change is reflected.
func test_silhouette_height_respects_crouched_export_knob() -> void:
	_inst.silhouette_height_crouched = 0.95
	_inst._set_state(PlayerEnums.MovementState.CROUCH)
	_inst._crouch_transition_progress = 1.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"After setting silhouette_height_crouched = 0.95, returned height must follow."
	).is_equal_approx(0.95, _TOLERANCE)


## Sanity: dead export knob change is reflected.
func test_silhouette_height_respects_dead_export_knob() -> void:
	_inst.silhouette_height_dead = 0.5
	_inst._set_state(PlayerEnums.MovementState.DEAD)
	_inst._crouch_transition_progress = 0.0

	assert_float(_inst.get_silhouette_height()).override_failure_message(
		"After setting silhouette_height_dead = 0.5, returned height must follow."
	).is_equal_approx(0.5, _TOLERANCE)
