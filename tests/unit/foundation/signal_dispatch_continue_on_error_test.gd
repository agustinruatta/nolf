# tests/unit/foundation/signal_dispatch_continue_on_error_test.gd
#
# SignalDispatchContinueOnErrorTest — GdUnit4 suite for Story SB-006 AC-16.
#
# PURPOSE
#   Verifies Godot's signal dispatch continues invoking subscribers even when
#   an upstream subscriber raises an error. ADR-0002 §Edge Cases row 5: a
#   crashing subscriber MUST NOT block downstream subscribers.
#
# IMPLEMENTATION NOTE
#   Godot's `assert(false, ...)` is fatal in tools mode but in headless test
#   mode it's typically caught and logged via push_error(), letting dispatch
#   continue. We use `push_error` directly to avoid framework variance — the
#   semantics under test are "subscriber A's handler completes with an error
#   logged, then subscriber B's handler runs."
#
# GATE STATUS
#   Story SB-006 | Logic type → BLOCKING gate. ADR-0002 Edge Cases.

class_name SignalDispatchContinueOnErrorTest
extends GdUnitTestSuite


## Subscriber that raises a non-fatal error (push_error) on every emit.
class CrashingSubscriber extends Node:
	var invocation_count: int = 0

	func _ready() -> void:
		Events.weapon_fired.connect(_on_weapon_fired)

	func _exit_tree() -> void:
		if Events.weapon_fired.is_connected(_on_weapon_fired):
			Events.weapon_fired.disconnect(_on_weapon_fired)

	func _on_weapon_fired(_weapon: Resource, _position: Vector3, _direction: Vector3) -> void:
		invocation_count += 1
		# Log an error and return. ADR-0002 row 5 spec: subsequent subscribers
		# must still receive the emit despite this error being logged.
		push_error("CrashingSubscriber: intentional error for SB-006 AC-16 test")


## Normal subscriber that records each invocation.
class NormalSubscriber extends Node:
	var invocations: Array[Dictionary] = []

	func _ready() -> void:
		Events.weapon_fired.connect(_on_weapon_fired)

	func _exit_tree() -> void:
		if Events.weapon_fired.is_connected(_on_weapon_fired):
			Events.weapon_fired.disconnect(_on_weapon_fired)

	func _on_weapon_fired(weapon: Resource, position: Vector3, direction: Vector3) -> void:
		invocations.append({"weapon": weapon, "position": position, "direction": direction})


## AC-16: CrashingSubscriber connects FIRST, NormalSubscriber connects SECOND.
## After emit, NormalSubscriber must still receive the invocation.
func test_normal_subscriber_runs_after_crashing_subscriber() -> void:
	var crash: CrashingSubscriber = CrashingSubscriber.new()
	var normal: NormalSubscriber = NormalSubscriber.new()
	# Order matters: crashing connects first.
	add_child(crash)
	add_child(normal)

	Events.weapon_fired.emit(null, Vector3.ZERO, Vector3.FORWARD)

	assert_int(crash.invocation_count).override_failure_message(
		"CrashingSubscriber must have been invoked exactly once."
	).is_equal(1)
	assert_int(normal.invocations.size()).override_failure_message(
		"NormalSubscriber must STILL receive the emit despite the upstream error. Got: %d invocations." % normal.invocations.size()
	).is_equal(1)
	assert_bool(normal.invocations[0]["position"].is_equal_approx(Vector3.ZERO)).override_failure_message(
		"NormalSubscriber's payload must be the original emit args."
	).is_true()

	remove_child(crash)
	remove_child(normal)
	crash.free()
	normal.free()


## AC-16 reverse order: NormalSubscriber first, CrashingSubscriber second.
## Both still get invoked — confirms continue-on-error works in both directions.
func test_crashing_subscriber_runs_after_normal_subscriber() -> void:
	var normal: NormalSubscriber = NormalSubscriber.new()
	var crash: CrashingSubscriber = CrashingSubscriber.new()
	add_child(normal)
	add_child(crash)

	Events.weapon_fired.emit(null, Vector3.ZERO, Vector3.FORWARD)

	assert_int(normal.invocations.size()).override_failure_message(
		"NormalSubscriber must receive the emit (registered first)."
	).is_equal(1)
	assert_int(crash.invocation_count).override_failure_message(
		"CrashingSubscriber must STILL be invoked even when registered after a normal subscriber."
	).is_equal(1)

	remove_child(normal)
	remove_child(crash)
	normal.free()
	crash.free()


## AC-16: Both subscribers crashing → both still invoked, both errors logged.
func test_two_crashing_subscribers_both_invoked() -> void:
	var crash_a: CrashingSubscriber = CrashingSubscriber.new()
	var crash_b: CrashingSubscriber = CrashingSubscriber.new()
	add_child(crash_a)
	add_child(crash_b)

	Events.weapon_fired.emit(null, Vector3.ZERO, Vector3.FORWARD)

	assert_int(crash_a.invocation_count).override_failure_message(
		"First crashing subscriber must be invoked."
	).is_equal(1)
	assert_int(crash_b.invocation_count).override_failure_message(
		"Second crashing subscriber must STILL be invoked despite first subscriber's error."
	).is_equal(1)

	remove_child(crash_a)
	remove_child(crash_b)
	crash_a.free()
	crash_b.free()
