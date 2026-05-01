# tests/unit/core/player_character/player_noise_event_retention_test.gd
#
# PlayerNoiseEventRetentionTest — GdUnit4 suite for Story PC-004 AC-3.5.
#
# PURPOSE
#   Documents and verifies the reference-retention footgun: a consumer that
#   stores the NoiseEvent reference returned by get_noise_event() will see
#   MUTATED field values after a subsequent spike overwrites the latch in-place.
#
#   This test PASSES when the footgun is confirmed — i.e. stored.origin returns
#   the NEW spike's origin, proving the in-place mutation contract is real.
#
#   If this test FAILS, it means the latch was NOT mutated in-place (e.g. a new
#   NoiseEvent was allocated per spike), which would break the zero-allocation
#   invariant at 80 Hz aggregate polling (ADR-0008, GDD F.4, TR-PC-013).
#
# METHOD
#   1. Latch spike A; store the returned reference as `saved`.
#   2. Record saved.origin (should equal spike A's origin at this point).
#   3. Latch spike B (higher radius so it wins) with a DIFFERENT origin.
#   4. Read saved.origin again — it MUST equal spike B's origin (in-place mutation).
#
# GATE STATUS
#   Story PC-004 | Logic type → BLOCKING gate. TR-PC-013.

class_name PlayerNoiseEventRetentionTest
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/gameplay/player/PlayerCharacter.tscn"
const _PHYSICS_DELTA: float = 1.0 / 60.0

var _inst: PlayerCharacter = null


func before_test() -> void:
	var packed: PackedScene = load(_SCENE_PATH) as PackedScene
	_inst = packed.instantiate() as PlayerCharacter
	auto_free(_inst)
	add_child(_inst)
	_inst._physics_process(_PHYSICS_DELTA)  # run _ready()


## AC-3.5: Stored reference reflects new spike origin after in-place overwrite.
## This test PASSES when the footgun is confirmed (origin changes under the ref).
func test_noise_event_stored_ref_reflects_overwritten_origin() -> void:
	# Arrange — spike A: radius 4 m, origin at (1, 0, 0).
	var origin_a: Vector3 = Vector3(1.0, 0.0, 0.0)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		origin_a
	)

	# Consumer stores the reference — simulates a guard caching the event.
	var saved: NoiseEvent = _inst.get_noise_event()

	# Verify saved.origin equals spike A's origin at this point (sanity check).
	assert_bool(
		saved.origin.is_equal_approx(origin_a)
	).override_failure_message(
		"Before overwrite: saved.origin must equal spike A origin (1,0,0)."
	).is_true()

	# Act — spike B: radius 5 m (wins) with a different origin.
	var origin_b: Vector3 = Vector3(99.0, 0.0, 0.0)
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		origin_b
	)

	# Assert — FOOTGUN CONFIRMED: saved.origin now reflects spike B's origin.
	# This proves the NoiseEvent was mutated in-place (zero-allocation contract).
	assert_bool(
		saved.origin.is_equal_approx(origin_b)
	).override_failure_message(
		"After overwrite: stored ref origin must reflect spike B (99,0,0), not spike A (1,0,0). "
		+ "If this fails, allocation is happening per-spike (breaks zero-alloc contract)."
	).is_true()


## AC-3.5: Stored reference also reflects overwritten type field.
func test_noise_event_stored_ref_reflects_overwritten_type() -> void:
	# Arrange — spike A.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3(1.0, 0.0, 0.0)
	)
	var saved: NoiseEvent = _inst.get_noise_event()

	# Act — spike B overwrites.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		Vector3(99.0, 0.0, 0.0)
	)

	# Assert — FOOTGUN: type also mutated.
	assert_int(saved.type).override_failure_message(
		"After overwrite: stored ref type must be LANDING_SOFT (proves in-place mutation)."
	).is_equal(PlayerEnums.NoiseType.LANDING_SOFT)


## AC-3.5: Stored reference also reflects overwritten radius_m field.
func test_noise_event_stored_ref_reflects_overwritten_radius() -> void:
	# Arrange — spike A.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3.ZERO
	)
	var saved: NoiseEvent = _inst.get_noise_event()

	# Act — spike B overwrites.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		Vector3.ZERO
	)

	# Assert — FOOTGUN: radius_m also mutated.
	assert_float(saved.radius_m).override_failure_message(
		"After overwrite: stored ref radius_m must be 5.0 (proves in-place mutation)."
	).is_equal_approx(5.0, 0.001)


## AC-3.5: The in-place mutation is the SAME object identity across spikes.
## get_noise_event() always returns the singleton instance, never a new allocation
## (once the initial allocation has occurred on the first spike).
func test_noise_event_same_object_identity_across_spikes() -> void:
	# Arrange — spike A.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.JUMP_TAKEOFF,
		4.0,
		Vector3.ZERO
	)
	var ref_a: NoiseEvent = _inst.get_noise_event()

	# Act — spike B overwrites.
	_inst._latch_noise_spike(
		PlayerEnums.NoiseType.LANDING_SOFT,
		5.0,
		Vector3(1.0, 0.0, 0.0)
	)
	var ref_b: NoiseEvent = _inst.get_noise_event()

	# Assert — same object (identical GDScript reference == same instance in memory).
	# In GDScript, RefCounted identity is compared via `is_same()`.
	assert_bool(is_same(ref_a, ref_b)).override_failure_message(
		"get_noise_event() must return the same instance before and after overwrite "
		+ "(zero-allocation singleton per GDD F.4 / TR-PC-013)."
	).is_true()
