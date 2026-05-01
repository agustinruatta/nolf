# tests/unit/core/player_character/player_noise_event_idempotent_test.gd
#
# PlayerNoiseEventIdempotentTest — GdUnit4 suite for Story PC-004 AC-3.2.
#
# PURPOSE
#   Verifies that 10 consecutive get_noise_event() calls within _spike_latch_duration_frames
#   all return non-null and have identical type, radius_m, and origin field values.
#   The latch is never cleared by reading — only by auto-expiry or respawn.
#
# METHOD
#   Latch a JUMP_TAKEOFF spike via _latch_noise_spike(). Call get_noise_event()
#   10 times without advancing physics ticks. Assert each call returns a non-null
#   reference with stable field values.
#
# GATE STATUS
#   Story PC-004 | Logic type → BLOCKING gate. TR-PC-012, TR-PC-013.

class_name PlayerNoiseEventIdempotentTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0
const _TOLERANCE: float = 0.001
const _READ_COUNT: int = 10

var _inst: PlayerCharacter = null


func before_test() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)
	_inst._physics_process(_PHYSICS_DELTA)  # run _ready()


## AC-3.2: 10 get_noise_event() calls within latch window all return non-null.
func test_get_noise_event_ten_calls_all_return_non_null() -> void:
	# Arrange — latch a spike; _spike_latch_duration_frames = 9 by default.
	var spike_origin: Vector3 = Vector3(1.0, 0.0, 2.0)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		spike_origin
	)

	# Act + Assert — 10 reads without advancing any physics tick.
	for i: int in range(_READ_COUNT):
		var event: NoiseEvent = _inst.get_noise_event()
		assert_object(event).override_failure_message(
			"get_noise_event() call %d of %d must return non-null within latch window." % [i + 1, _READ_COUNT]
		).is_not_null()


## AC-3.2: All 10 calls return the same type field value.
func test_get_noise_event_ten_calls_same_type() -> void:
	# Arrange.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3(1.0, 0.0, 2.0)
	)

	# Act + Assert — collect all types.
	for i: int in range(_READ_COUNT):
		var event: NoiseEvent = _inst.get_noise_event()
		assert_int(event.type).override_failure_message(
			"get_noise_event() call %d: type must be JUMP_TAKEOFF." % [i + 1]
		).is_equal(PlayerEnums.NoiseType.JUMP_TAKEOFF)


## AC-3.2: All 10 calls return the same radius_m field value.
func test_get_noise_event_ten_calls_same_radius_m() -> void:
	# Arrange.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3(1.0, 0.0, 2.0)
	)

	# Act + Assert.
	for i: int in range(_READ_COUNT):
		var event: NoiseEvent = _inst.get_noise_event()
		assert_float(event.radius_m).override_failure_message(
			"get_noise_event() call %d: radius_m must be 4.0." % [i + 1]
		).is_equal_approx(4.0, _TOLERANCE)


## AC-3.2: All 10 calls return the same origin field value.
func test_get_noise_event_ten_calls_same_origin() -> void:
	# Arrange.
	var spike_origin: Vector3 = Vector3(1.0, 0.0, 2.0)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		spike_origin
	)

	# Act + Assert — origin is a value type (Vector3), stable across reads.
	for i: int in range(_READ_COUNT):
		var event: NoiseEvent = _inst.get_noise_event()
		assert_bool(
			event.origin.is_equal_approx(spike_origin)
		).override_failure_message(
			"get_noise_event() call %d: origin must equal spike origin." % [i + 1]
		).is_true()


## AC-3.2: Reads do NOT decrement the latch counter (auto-expiry is tick-only).
func test_get_noise_event_reads_do_not_expire_latch() -> void:
	# Arrange.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3.ZERO
	)
	var frames_before: int = _inst._latch_frames_remaining

	# Act — 10 reads.
	for _i: int in range(_READ_COUNT):
		var _unused: NoiseEvent = _inst.get_noise_event()

	# Assert — counter must not have changed.
	assert_int(_inst._latch_frames_remaining).override_failure_message(
		"get_noise_event() reads must NOT decrement _latch_frames_remaining."
	).is_equal(frames_before)
