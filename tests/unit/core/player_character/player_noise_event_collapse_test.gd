# tests/unit/core/player_character/player_noise_event_collapse_test.gd
#
# PlayerNoiseEventCollapseTest — GdUnit4 suite for Story PC-004 AC-3.3.
#
# PURPOSE
#   Verifies highest-radius-wins collision policy in _latch_noise_spike():
#   • 4 m → 5 m: 5 m wins (higher replaces lower)
#   • 5 m → 4 m: 5 m retained (lower does NOT overwrite)
#   • 4 m → 4 m: first-recorded wins (equal does NOT overwrite)
#
# METHOD
#   Calls _latch_noise_spike() directly with controlled radii and origins,
#   then reads get_noise_event() to verify the winning latch. No physics ticks
#   are advanced between spikes (spikes arrive within the same latch window).
#
# GATE STATUS
#   Story PC-004 | Logic type → BLOCKING gate. TR-PC-014.

class_name PlayerNoiseEventCollapseTest
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
	_inst._physics_process(_PHYSICS_DELTA)


## AC-3.3: Lower radius first (4 m), then higher (5 m) → higher wins.
func test_noise_collapse_lower_then_higher_higher_wins() -> void:
	# Arrange — first spike: 4 m JUMP_TAKEOFF.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3(0.0, 0.0, 0.0)
	)

	# Act — second spike: 5 m LANDING_SOFT (arrives within window, no tick).
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		Vector3(1.0, 0.0, 0.0)
	)

	# Assert — 5 m spike must win.
	var event: NoiseEvent = _inst.get_noise_event()
	assert_object(event).override_failure_message(
		"get_noise_event() must be non-null after collision."
	).is_not_null()
	assert_int(event.type).override_failure_message(
		"Higher-radius spike (LANDING_SOFT) must overwrite lower (JUMP_TAKEOFF)."
	).is_equal(PlayerEnums.NoiseType.LANDING_SOFT)
	assert_float(event.radius_m).override_failure_message(
		"Winning radius must be 5.0."
	).is_equal_approx(5.0, _TOLERANCE)


## AC-3.3: Higher radius first (5 m), then lower (4 m) → original retained.
func test_noise_collapse_higher_then_lower_original_retained() -> void:
	# Arrange — first spike: 5 m LANDING_SOFT.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		Vector3(0.0, 0.0, 0.0)
	)

	# Act — second spike: 4 m JUMP_TAKEOFF (lower radius, must lose).
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3(1.0, 0.0, 0.0)
	)

	# Assert — original 5 m latch must be retained.
	var event: NoiseEvent = _inst.get_noise_event()
	assert_object(event).override_failure_message(
		"get_noise_event() must be non-null."
	).is_not_null()
	assert_int(event.type).override_failure_message(
		"Lower-radius second spike must NOT overwrite the 5 m latch."
	).is_equal(PlayerEnums.NoiseType.LANDING_SOFT)
	assert_float(event.radius_m).override_failure_message(
		"Retained radius must still be 5.0."
	).is_equal_approx(5.0, _TOLERANCE)


## AC-3.3: Equal radii — first-recorded wins (tie does NOT overwrite).
func test_noise_collapse_equal_radii_first_recorded_wins() -> void:
	# Arrange — first spike: 4 m JUMP_TAKEOFF.
	var first_origin: Vector3 = Vector3(10.0, 0.0, 0.0)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		first_origin
	)

	# Act — second spike: 4 m LANDING_SOFT (same radius = tie).
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		4.0,
		Vector3(20.0, 0.0, 0.0)
	)

	# Assert — first-recorded (JUMP_TAKEOFF) must be retained.
	var event: NoiseEvent = _inst.get_noise_event()
	assert_object(event).override_failure_message(
		"get_noise_event() must be non-null after tie."
	).is_not_null()
	assert_int(event.type).override_failure_message(
		"On equal radii, first-recorded (JUMP_TAKEOFF) must win."
	).is_equal(PlayerEnums.NoiseType.JUMP_TAKEOFF)
	assert_float(event.radius_m).override_failure_message(
		"Tied radius must still be 4.0."
	).is_equal_approx(4.0, _TOLERANCE)
	assert_bool(event.origin.is_equal_approx(first_origin)).override_failure_message(
		"Origin must be the first spike's origin on a tie."
	).is_true()


## AC-3.3: Three spikes in ascending order — highest overall wins.
func test_noise_collapse_three_ascending_highest_wins() -> void:
	# Arrange: 3 m → 5 m → 7 m.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.FOOTSTEP_SOFT,
		3.0,
		Vector3(1.0, 0.0, 0.0)
	)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		Vector3(2.0, 0.0, 0.0)
	)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_HARD,
		7.0,
		Vector3(3.0, 0.0, 0.0)
	)

	var event: NoiseEvent = _inst.get_noise_event()
	assert_float(event.radius_m).override_failure_message(
		"After 3 m → 5 m → 7 m spikes, radius must be 7.0."
	).is_equal_approx(7.0, _TOLERANCE)
	assert_int(event.type).override_failure_message(
		"After 3 m → 5 m → 7 m spikes, type must be LANDING_HARD."
	).is_equal(PlayerEnums.NoiseType.LANDING_HARD)


## AC-3.3: Three spikes in descending order — first retains.
func test_noise_collapse_three_descending_first_wins() -> void:
	# Arrange: 7 m → 5 m → 3 m.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_HARD,
		7.0,
		Vector3(1.0, 0.0, 0.0)
	)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		Vector3(2.0, 0.0, 0.0)
	)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.FOOTSTEP_SOFT,
		3.0,
		Vector3(3.0, 0.0, 0.0)
	)

	var event: NoiseEvent = _inst.get_noise_event()
	assert_float(event.radius_m).override_failure_message(
		"After 7 m → 5 m → 3 m, first (7 m) must be retained."
	).is_equal_approx(7.0, _TOLERANCE)
	assert_int(event.type).override_failure_message(
		"After 7 m → 5 m → 3 m, type must remain LANDING_HARD."
	).is_equal(PlayerEnums.NoiseType.LANDING_HARD)
