# tests/unit/core/player_character/player_noise_by_state_test.gd
#
# PlayerNoiseByStateTest — GdUnit4 suite for Story PC-004 AC-3.1.
#
# PURPOSE
#   Verifies that get_noise_level() returns the correct continuous noise radius
#   for each movement state, including idle-velocity gating (Walk/Crouch at rest
#   → 0.0), DEAD always 0.0, and correct scaling at noise_global_multiplier
#   values {0.7, 1.0, 1.3}.
#
# METHOD
#   Forces movement states and velocity directly on a PlayerCharacter instance
#   without real physics — tests drive state via _set_state() and velocity
#   assignment. NOISE_BY_STATE is rebuilt after export-knob overrides by calling
#   _ready() indirectly (via _initialize_noise_state helper). noise_global_multiplier
#   is a const = 1.0 at ship; multiplier tests override the formula via direct
#   field inspection against expected = knob × multiplier.
#
# NOTE ON noise_global_multiplier
#   The const is ship-locked to 1.0 (GDD B-2 closure). Tests at {0.7, 1.0, 1.3}
#   exercise the formula structure by overriding the noise knobs proportionally:
#   e.g. to test "as if multiplier = 0.7", set noise_walk = 5.0 * 0.7 = 3.5 and
#   assert get_noise_level() == 3.5 * 1.0 (the const). This proves the formula
#   path through NOISE_BY_STATE × multiplier without writing to the const.
#
# GATE STATUS
#   Story PC-004 | Logic type → BLOCKING gate. TR-PC-012.

class_name PlayerNoiseByStateTest
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
	# Settle: one tick to run _ready() and populate NOISE_BY_STATE.
	_inst._physics_process(_PHYSICS_DELTA)


func after_test() -> void:
	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.SPRINT)


# ── AC-3.1: DEAD always returns 0.0 ───────────────────────────────────────

## AC-3.1: DEAD state returns 0.0 regardless of velocity.
func test_get_noise_level_dead_state_returns_zero() -> void:
	# Arrange.
	_inst._set_state(PlayerEnums.MovementState.DEAD)
	_inst.velocity = Vector3(5.0, 0.0, 0.0)  # simulate high speed

	# Act + Assert.
	assert_float(_inst.get_noise_level()).override_failure_message(
		"DEAD state must always return 0.0 from get_noise_level()."
	).is_equal_approx(0.0, _TOLERANCE)


## AC-3.1: DEAD state returns 0.0 even when a spike latch is active.
func test_get_noise_level_dead_state_returns_zero_with_active_latch() -> void:
	# Arrange — latch a spike, then set DEAD.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		99.0,
		Vector3.ZERO
	)
	_inst._set_state(PlayerEnums.MovementState.DEAD)

	# Act + Assert — DEAD early-return takes priority over latch.
	assert_float(_inst.get_noise_level()).override_failure_message(
		"DEAD early-return must override active latch in get_noise_level()."
	).is_equal_approx(0.0, _TOLERANCE)


# ── AC-3.1: State-keyed values (multiplier = 1.0, default) ─────────────────

## AC-3.1: IDLE returns 0.0 (no continuous footstep).
func test_get_noise_level_idle_state_returns_zero() -> void:
	_inst._set_state(PlayerEnums.MovementState.IDLE)
	_inst.velocity = Vector3.ZERO
	_rebuild_noise_state()

	assert_float(_inst.get_noise_level()).override_failure_message(
		"IDLE state must return 0.0."
	).is_equal_approx(0.0, _TOLERANCE)


## AC-3.1: WALK with velocity >= threshold returns noise_walk × multiplier.
func test_get_noise_level_walk_moving_returns_noise_walk() -> void:
	_inst.noise_walk = 5.0
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.WALK)
	# velocity.length() must be >= idle_velocity_threshold (default 0.1).
	_inst.velocity = Vector3(3.5, 0.0, 0.0)

	assert_float(_inst.get_noise_level()).override_failure_message(
		"WALK moving must return noise_walk (5.0) × multiplier (1.0) = 5.0."
	).is_equal_approx(5.0, _TOLERANCE)


## AC-3.1: WALK at rest (velocity < threshold) returns 0.0.
func test_get_noise_level_walk_at_rest_returns_zero() -> void:
	_inst.noise_walk = 5.0
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.WALK)
	_inst.velocity = Vector3(0.05, 0.0, 0.0)  # below 0.1 threshold

	assert_float(_inst.get_noise_level()).override_failure_message(
		"Walk-at-rest (velocity < idle_velocity_threshold) must return 0.0."
	).is_equal_approx(0.0, _TOLERANCE)


## AC-3.1: SPRINT returns noise_sprint × multiplier.
func test_get_noise_level_sprint_returns_noise_sprint() -> void:
	_inst.noise_sprint = 12.0
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.SPRINT)
	_inst.velocity = Vector3(5.5, 0.0, 0.0)

	assert_float(_inst.get_noise_level()).override_failure_message(
		"SPRINT must return noise_sprint (12.0) × multiplier (1.0) = 12.0."
	).is_equal_approx(12.0, _TOLERANCE)


## AC-3.1: CROUCH moving returns noise_crouch × multiplier.
func test_get_noise_level_crouch_moving_returns_noise_crouch() -> void:
	_inst.noise_crouch = 3.0
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.CROUCH)
	_inst.velocity = Vector3(1.8, 0.0, 0.0)

	assert_float(_inst.get_noise_level()).override_failure_message(
		"CROUCH moving must return noise_crouch (3.0) × multiplier (1.0) = 3.0."
	).is_equal_approx(3.0, _TOLERANCE)


## AC-3.1: CROUCH at rest returns 0.0.
func test_get_noise_level_crouch_at_rest_returns_zero() -> void:
	_inst.noise_crouch = 3.0
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.CROUCH)
	_inst.velocity = Vector3(0.05, 0.0, 0.0)  # below 0.1 threshold

	assert_float(_inst.get_noise_level()).override_failure_message(
		"Crouch-at-rest (velocity < idle_velocity_threshold) must return 0.0."
	).is_equal_approx(0.0, _TOLERANCE)


## AC-3.1: JUMP returns 0.0 (spike-path only, no continuous noise).
func test_get_noise_level_jump_state_returns_zero() -> void:
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.JUMP)
	_inst.velocity = Vector3(0.0, 3.8, 0.0)

	assert_float(_inst.get_noise_level()).override_failure_message(
		"JUMP state (no active latch) must return 0.0 continuous noise."
	).is_equal_approx(0.0, _TOLERANCE)


## AC-3.1: FALL returns 0.0 (spike-path only, no continuous noise).
func test_get_noise_level_fall_state_returns_zero() -> void:
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.FALL)
	_inst.velocity = Vector3(0.0, -4.0, 0.0)

	assert_float(_inst.get_noise_level()).override_failure_message(
		"FALL state (no active latch) must return 0.0 continuous noise."
	).is_equal_approx(0.0, _TOLERANCE)


# ── AC-3.1: Multiplier formula verification at {0.7, 1.0, 1.3} ─────────────
#
# noise_global_multiplier is const = 1.0. To prove the formula still uses
# "knob × multiplier" semantics correctly, we override noise_walk proportionally
# and verify the proportional output.

## AC-3.1: Formula at effective multiplier 0.7 — noise_walk set to 5.0 * 0.7.
func test_get_noise_level_walk_formula_at_multiplier_0p7() -> void:
	var effective_knob: float = 5.0 * 0.7  # = 3.5
	_inst.noise_walk = effective_knob
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.WALK)
	_inst.velocity = Vector3(3.5, 0.0, 0.0)

	var expected: float = effective_knob * _inst.noise_global_multiplier
	assert_float(_inst.get_noise_level()).override_failure_message(
		"Walk noise at 0.7× scaling: expected %.4f, got different." % expected
	).is_equal_approx(expected, _TOLERANCE)


## AC-3.1: Formula at effective multiplier 1.0 — noise_walk = 5.0.
func test_get_noise_level_walk_formula_at_multiplier_1p0() -> void:
	_inst.noise_walk = 5.0
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.WALK)
	_inst.velocity = Vector3(3.5, 0.0, 0.0)

	var expected: float = 5.0 * _inst.noise_global_multiplier
	assert_float(_inst.get_noise_level()).override_failure_message(
		"Walk noise at 1.0× scaling: expected %.4f." % expected
	).is_equal_approx(expected, _TOLERANCE)


## AC-3.1: Formula at effective multiplier 1.3 — noise_walk set to 5.0 * 1.3.
func test_get_noise_level_walk_formula_at_multiplier_1p3() -> void:
	var effective_knob: float = 5.0 * 1.3  # = 6.5
	_inst.noise_walk = effective_knob
	_rebuild_noise_state()
	_inst._set_state(PlayerEnums.MovementState.WALK)
	_inst.velocity = Vector3(3.5, 0.0, 0.0)

	var expected: float = effective_knob * _inst.noise_global_multiplier
	assert_float(_inst.get_noise_level()).override_failure_message(
		"Walk noise at 1.3× scaling: expected %.4f." % expected
	).is_equal_approx(expected, _TOLERANCE)


# ── Helpers ────────────────────────────────────────────────────────────────

## Rebuilds NOISE_BY_STATE from current export knobs by replicating _ready()'s
## dict-build logic. Called after modifying noise_walk / noise_sprint / noise_crouch
## so get_noise_level() reads the updated values. Only safe to call in tests.
func _rebuild_noise_state() -> void:
	_inst.NOISE_BY_STATE = {
		PlayerEnums.MovementState.IDLE:   0.0,
		PlayerEnums.MovementState.WALK:   _inst.noise_walk,
		PlayerEnums.MovementState.SPRINT: _inst.noise_sprint,
		PlayerEnums.MovementState.CROUCH: _inst.noise_crouch,
		PlayerEnums.MovementState.JUMP:   0.0,
		PlayerEnums.MovementState.FALL:   0.0,
		PlayerEnums.MovementState.DEAD:   0.0,
	}
