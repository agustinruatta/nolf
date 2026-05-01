# tests/unit/core/player_character/player_ceiling_check_test.gd
#
# PlayerCeilingCheckTest — GdUnit4 suite for Story PC-003 AC-ceiling-check.
#
# PURPOSE
#   Uncrouch blocked by ceiling:
#   • After crouching below 1.4 m ceiling, pressing Ctrl to uncrouch triggers
#     ShapeCast3D.force_shapecast_update() then reads is_colliding().
#   • If blocked: state stays CROUCH, soft head-bump SFX is requested
#     (_pending_head_bump == true), no visual UI feedback.
#   Also verifies: uncrouch succeeds when ceiling is not present.
#
# NOTE ON HEADLESS TESTING
#   Input.is_action_just_pressed() is not dispatched in headless mode.
#   Tests call _handle_crouch_toggle() directly to trigger the crouch logic
#   without routing through _physics_process + Input events.
#   Floor nodes use .position (local) instead of .global_position to avoid
#   the "not in tree" error when setting position before add_child().
#
# GATE STATUS
#   Story PC-003 | Logic type → BLOCKING gate.

class_name PlayerCeilingCheckTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0

var _inst: PlayerCharacter = null
var _floor: StaticBody3D = null
var _ceiling: StaticBody3D = null


func before_test() -> void:
	_floor = _build_floor()
	add_child(_floor)

	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)

	_inst.global_position = Vector3(0.0, 0.85, 0.0)

	# Settle on floor.
	for _i: int in range(3):
		_inst._physics_process(_PHYSICS_DELTA)


func after_test() -> void:
	if is_instance_valid(_floor):
		_floor.queue_free()
	if is_instance_valid(_ceiling):
		_ceiling.queue_free()
		_ceiling = null
	Input.action_release(InputActions.CROUCH)


## AC-ceiling-check: Uncrouch is blocked when ceiling at 1.4 m overhead.
## State stays CROUCH and _pending_head_bump is set.
func test_ceiling_check_blocks_uncrouch_and_requests_sfx() -> void:
	# Arrange — place low ceiling at 1.4 m above floor (player centre at ~0.85,
	# ceiling bottom at 0.85 + 1.4 = 2.25 — but we want it to block the
	# standing capsule (1.7 m), so place ceiling so that it intersects the
	# standing capsule's top: player centre 0.85 + capsule_half_height 0.85 = 1.7 top.
	# Ceiling at Y=1.65 (0.05 m gap — blocked for standing height 1.7, clear for crouched 1.1).
	_ceiling = _build_ceiling(1.65)
	add_child(_ceiling)

	# Enter crouch by calling the toggle directly.
	_inst._handle_crouch_toggle()
	_inst._physics_process(_PHYSICS_DELTA)

	assert_int(_inst.current_state).override_failure_message(
		"Player must be CROUCH before attempting uncrouch test."
	).is_equal(PlayerEnums.MovementState.CROUCH)

	# Attempt to uncrouch — _handle_crouch_toggle() checks ShapeCast3D.
	_inst._handle_crouch_toggle()

	# Assert head-bump BEFORE the next physics tick clears _pending_head_bump.
	# _physics_process() resets the flag at its first step (Step 1: per-tick clear).
	assert_bool(_inst._pending_head_bump).override_failure_message(
		"_pending_head_bump must be true immediately after _handle_crouch_toggle() " +
		"when ceiling blocks uncrouching (checked before physics tick clears it)."
	).is_true()

	# One physics tick to confirm state remains CROUCH after the blocked uncrouch.
	_inst._physics_process(_PHYSICS_DELTA)

	# Assert — state must remain CROUCH.
	assert_int(_inst.current_state).override_failure_message(
		"State must remain CROUCH when ceiling blocks uncrouching."
	).is_equal(PlayerEnums.MovementState.CROUCH)


## AC-ceiling-check: Uncrouch succeeds when no ceiling is present.
## State leaves CROUCH and _pending_head_bump stays false.
func test_ceiling_check_allows_uncrouch_without_ceiling() -> void:
	# Arrange — enter crouch directly (no ceiling added).
	_inst._handle_crouch_toggle()
	_inst._physics_process(_PHYSICS_DELTA)

	assert_int(_inst.current_state).override_failure_message(
		"Player must be CROUCH before uncrouch test."
	).is_equal(PlayerEnums.MovementState.CROUCH)

	# Act — attempt uncrouch.
	_inst._handle_crouch_toggle()
	_inst._physics_process(_PHYSICS_DELTA)

	# Assert — state has left CROUCH.
	assert_int(_inst.current_state).override_failure_message(
		"State must leave CROUCH when no ceiling is present."
	).is_not_equal(PlayerEnums.MovementState.CROUCH)

	# Assert — no head-bump SFX.
	assert_bool(_inst._pending_head_bump).override_failure_message(
		"_pending_head_bump must be false when uncrouch succeeds."
	).is_false()


## AC-ceiling-check: _pending_head_bump flag resets each physics tick.
## Verifies the flag is fresh at the start of each frame.
func test_ceiling_check_pending_head_bump_resets_each_tick() -> void:
	# Arrange — force the flag true directly.
	_inst._pending_head_bump = true

	# Act — run one tick (no ceiling, no crouch toggle).
	_inst._physics_process(_PHYSICS_DELTA)

	# Assert — flag is cleared at tick start.
	assert_bool(_inst._pending_head_bump).override_failure_message(
		"_pending_head_bump must be reset to false at the start of each physics tick."
	).is_false()


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


## Builds a flat ceiling at the given Y position (floor surface of the ceiling slab).
func _build_ceiling(y_position: float) -> StaticBody3D:
	var ceil_body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 20.0)
	col.shape = box
	ceil_body.add_child(col)
	# Centre the slab above the player — the floor surface of the slab is at y_position.
	ceil_body.position = Vector3(0.0, y_position + 0.1, 0.0)
	ceil_body.set_collision_layer_value(PhysicsLayers.LAYER_WORLD, true)
	return ceil_body
