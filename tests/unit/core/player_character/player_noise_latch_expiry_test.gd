# tests/unit/core/player_character/player_noise_latch_expiry_test.gd
#
# PlayerNoiseLatchExpiryTest — GdUnit4 suite for Story PC-004 AC-3.4.
#
# PURPOSE
#   Verifies spike-latch auto-expiry: after _spike_latch_duration_frames + 1
#   physics ticks, get_noise_event() returns null and get_noise_level() returns
#   the continuous state-keyed value (not the spike value).
#
# METHOD
#   Latch a spike, then call _physics_process() manually to simulate physics
#   ticks. The expiry tick runs at the start of each _physics_process() call
#   (before state reads). _spike_latch_duration_frames is manually set to a
#   small test value (3) to keep the test fast without depending on real 60 Hz
#   timing.
#
# NOTE ON _physics_process in headless mode
#   In headless mode, Input.is_action_just_pressed() never fires, so jumping
#   won't happen via _physics_process. The test latches spikes directly via
#   _latch_noise_spike() and simulates ticks safely.
#
# GATE STATUS
#   Story PC-004 | Logic type → BLOCKING gate. TR-PC-014.

class_name PlayerNoiseLatchExpiryTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0
const _TOLERANCE: float = 0.001
const _TEST_LATCH_FRAMES: int = 3  # small value for fast test; proves the math

var _inst: PlayerCharacter = null


func before_test() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)
	_inst._physics_process(_PHYSICS_DELTA)  # run _ready()

	# Override latch duration to a small deterministic value for test speed.
	_inst._spike_latch_duration_frames = _TEST_LATCH_FRAMES


## Smoke test: production-default _spike_latch_duration_frames == 9 @ 60 Hz.
## Catches any regression in the int(_spike_latch_duration_sec × physics_ticks_per_second)
## computation in _ready(). All other tests override this value to a small number
## for speed; this test exercises the default path. (qa-tester rec, 2026-05-01.)
func test_default_latch_duration_frames_equals_nine_at_sixty_hz() -> void:
	# Re-instantiate with the EXPORT default (don't override).
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	var fresh: PlayerCharacter = packed.instantiate() as PlayerCharacter
	auto_free(fresh)
	add_child(fresh)
	fresh._physics_process(_PHYSICS_DELTA)  # run _ready()

	# Default _spike_latch_duration_sec = 0.15 s × 60 Hz = 9 frames.
	# AI-programmer B-2 fix 2026-04-21 raised this from 6 to 9 frames so every
	# 10 Hz guard poll phase offset is covered.
	assert_int(fresh._spike_latch_duration_frames).override_failure_message(
		"Default _spike_latch_duration_frames must be 9 (= 0.15 s × 60 Hz). "
		+ "If this fails, _spike_latch_duration_sec or Engine.physics_ticks_per_second "
		+ "has drifted from the expected production values."
	).is_equal(9)


## AC-3.4: Latch is non-null immediately after spiking (frame 0).
func test_latch_expiry_non_null_immediately_after_spike() -> void:
	# Arrange.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3.ZERO
	)

	# Assert — no ticks advanced; latch must be active.
	assert_object(_inst.get_noise_event()).override_failure_message(
		"Latch must be non-null immediately after spiking (before any tick)."
	).is_not_null()
	assert_int(_inst._latch_frames_remaining).override_failure_message(
		"_latch_frames_remaining must equal _spike_latch_duration_frames immediately after spike."
	).is_equal(_TEST_LATCH_FRAMES)


## AC-3.4: Latch survives through tick N = _spike_latch_duration_frames (not yet expired).
## The expiry sequence: frame 3 → counter ticks to 2; frame 2 → 1; frame 1 → 0 (clears).
## On tick #1 after spike: _latch_frames_remaining decrements from 3 → 2 → ... stays alive
## until it hits 0.
func test_latch_expiry_still_active_at_duration_minus_one_tick() -> void:
	# Arrange.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3.ZERO
	)

	# Advance _spike_latch_duration_frames - 1 ticks (latch should still be alive).
	for _i: int in range(_TEST_LATCH_FRAMES - 1):
		_inst._physics_process(_PHYSICS_DELTA)

	# Assert — latch must still be active.
	assert_object(_inst.get_noise_event()).override_failure_message(
		"Latch must still be active after %d ticks (duration = %d)." % [
			_TEST_LATCH_FRAMES - 1, _TEST_LATCH_FRAMES
		]
	).is_not_null()
	assert_int(_inst._latch_frames_remaining).override_failure_message(
		"_latch_frames_remaining must be 1 after %d ticks." % [_TEST_LATCH_FRAMES - 1]
	).is_equal(1)


## AC-3.4: Latch expires after exactly _spike_latch_duration_frames ticks.
## At tick N, counter decrements to 0 and _latched_event is set to null.
func test_latch_expiry_null_after_duration_frames() -> void:
	# Arrange.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3.ZERO
	)

	# Act — advance exactly _spike_latch_duration_frames ticks.
	for _i: int in range(_TEST_LATCH_FRAMES):
		_inst._physics_process(_PHYSICS_DELTA)

	# Assert — latch must now be null.
	assert_object(_inst.get_noise_event()).override_failure_message(
		"Latch must expire after %d ticks." % _TEST_LATCH_FRAMES
	).is_null()
	assert_int(_inst._latch_frames_remaining).override_failure_message(
		"_latch_frames_remaining must be 0 after expiry."
	).is_equal(0)


## AC-3.4: After expiry, get_noise_level() returns continuous state-keyed value.
## This proves the spike value does NOT bleed into the continuous path.
func test_latch_expiry_noise_level_returns_continuous_after_expiry() -> void:
	# Arrange — latch a spike with deliberately large radius.
	_inst.noise_walk = 5.0
	_inst.NOISE_BY_STATE[PlayerEnums.MovementState.WALK] = 5.0
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_HARD,
		99.0,  # deliberately large so it's obviously the latch if it bleeds
		Vector3.ZERO
	)

	# Act — expire the latch via physics_process ticks. The full _physics_process
	# may transition state (e.g. → FALL in headless without a floor), so AFTER
	# expiry we re-pin WALK state + walking velocity to test the continuous path.
	for _i: int in range(_TEST_LATCH_FRAMES):
		_inst._physics_process(_PHYSICS_DELTA)
	_inst._set_state(PlayerEnums.MovementState.WALK)
	_inst.velocity = Vector3(3.5, 0.0, 0.0)

	# Assert — must return continuous walk noise, not the 99 m spike.
	var level: float = _inst.get_noise_level()
	assert_float(level).override_failure_message(
		"After expiry, get_noise_level() must return continuous walk noise (5.0), not spike (99.0). Got: %.4f" % level
	).is_equal_approx(5.0, _TOLERANCE)


## AC-3.4: get_noise_event() null after expiry is the SOLE clear mechanism
## (no manual read can expire the latch early).
func test_latch_expiry_reads_alone_do_not_clear() -> void:
	# Arrange — latch, then do many reads but no ticks.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3.ZERO
	)
	for _i: int in range(100):
		var _unused: NoiseEvent = _inst.get_noise_event()

	# Assert — latch is still alive (auto-expiry not triggered by reads).
	assert_object(_inst.get_noise_event()).override_failure_message(
		"100 reads must NOT clear the latch (auto-expiry is tick-only)."
	).is_not_null()
