# tests/unit/foundation/signal_dispatch_no_dedup_test.gd
#
# SignalDispatchNoDedupTest — GdUnit4 suite for Story SB-006 AC-15.
#
# PURPOSE
#   Verifies Godot's signal dispatch does NOT deduplicate same-frame double
#   emits. Two emits = two handler invocations in emit order, even when the
#   payload is identical. This is documented Godot behavior (ADR-0002 §Edge
#   Cases row 3) that downstream subscribers rely on.
#
# GATE STATUS
#   Story SB-006 | Logic type → BLOCKING gate. ADR-0002 Edge Cases.

class_name SignalDispatchNoDedupTest
extends GdUnitTestSuite


## Test recorder that logs every mission_completed invocation.
class TestRecorder extends Node:
	var invocations: Array[StringName] = []

	func _ready() -> void:
		Events.mission_completed.connect(_on_mission_completed)

	func _exit_tree() -> void:
		if Events.mission_completed.is_connected(_on_mission_completed):
			Events.mission_completed.disconnect(_on_mission_completed)

	func _on_mission_completed(mission_id: StringName) -> void:
		invocations.append(mission_id)


## AC-15: Two emits with different payloads → two invocations in emit order.
func test_two_distinct_emits_produce_two_ordered_invocations() -> void:
	var rec: TestRecorder = TestRecorder.new()
	add_child(rec)

	Events.mission_completed.emit(&"mission_a")
	Events.mission_completed.emit(&"mission_b")

	assert_int(rec.invocations.size()).override_failure_message(
		"Two emits must produce 2 invocations. Got: %d" % rec.invocations.size()
	).is_equal(2)
	assert_str(String(rec.invocations[0])).override_failure_message(
		"First invocation must carry 'mission_a'."
	).is_equal("mission_a")
	assert_str(String(rec.invocations[1])).override_failure_message(
		"Second invocation must carry 'mission_b'."
	).is_equal("mission_b")

	remove_child(rec)
	rec.free()


## AC-15: Two emits with IDENTICAL payloads → still two invocations (no dedup).
func test_two_identical_emits_produce_two_invocations_no_dedup() -> void:
	var rec: TestRecorder = TestRecorder.new()
	add_child(rec)

	Events.mission_completed.emit(&"mission_a")
	Events.mission_completed.emit(&"mission_a")

	assert_int(rec.invocations.size()).override_failure_message(
		"Identical-payload emits must NOT be deduplicated. Got: %d" % rec.invocations.size()
	).is_equal(2)
	assert_str(String(rec.invocations[0])).is_equal("mission_a")
	assert_str(String(rec.invocations[1])).is_equal("mission_a")

	remove_child(rec)
	rec.free()


## AC-15 edge case: many emits in succession all dispatch.
func test_many_successive_emits_all_dispatch() -> void:
	var rec: TestRecorder = TestRecorder.new()
	add_child(rec)

	const N: int = 7
	for i: int in range(N):
		Events.mission_completed.emit(StringName("mission_%d" % i))

	assert_int(rec.invocations.size()).override_failure_message(
		"%d emits must produce %d invocations. Got: %d" % [N, N, rec.invocations.size()]
	).is_equal(N)
	for i: int in range(N):
		assert_str(String(rec.invocations[i])).is_equal("mission_%d" % i)

	remove_child(rec)
	rec.free()


## AC-15 cross-product: two recorders + two emits → each recorder gets 2 invocations.
func test_two_recorders_each_get_two_invocations_on_two_emits() -> void:
	var rec_a: TestRecorder = TestRecorder.new()
	var rec_b: TestRecorder = TestRecorder.new()
	add_child(rec_a)
	add_child(rec_b)

	Events.mission_completed.emit(&"mission_a")
	Events.mission_completed.emit(&"mission_b")

	assert_int(rec_a.invocations.size()).override_failure_message(
		"Recorder A must get both emits."
	).is_equal(2)
	assert_int(rec_b.invocations.size()).override_failure_message(
		"Recorder B must get both emits."
	).is_equal(2)

	remove_child(rec_a)
	remove_child(rec_b)
	rec_a.free()
	rec_b.free()
