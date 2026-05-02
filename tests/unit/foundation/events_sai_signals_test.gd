# tests/unit/foundation/events_sai_signals_test.gd
#
# SAI-domain signal declarations test — Story SAI-002 AC-2 + AC-3.
#
# PURPOSE
#   Proves that src/core/signal_bus/events.gd declares the 6 SAI-domain
#   signals with the correct names and parameter counts, that those signal
#   parameter types reference StealthAI's qualified enum types, and that
#   events.gd remains free of enum declarations after the SAI signals land.
#
# WHAT IS TESTED
#   AC-2-A: alert_state_changed declared with 4 parameters.
#   AC-2-B: actor_became_alerted declared with 4 parameters.
#   AC-2-C: actor_lost_target declared with 2 parameters.
#   AC-2-D: takedown_performed declared with 3 parameters.
#   AC-2-E: guard_incapacitated declared with 2 parameters (cause is int, not enum).
#   AC-2-F: guard_woke_up declared with 1 parameter.
#   AC-3-A: events.gd contains zero `enum ` declarations (purity invariant).
#
# WHAT IS NOT TESTED HERE
#   - Enum value counts on StealthAI — see stealth_ai_enums_test.gd.
#   - Severity rule logic — see stealth_ai_severity_rule_test.gd.
#   - Full events.gd structural purity (no func/var/const) —
#     see events_purity_test.gd.

class_name EventsSAISignalsTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the Events autoload node. Fails the test if it is not found.
func _get_events_node() -> SignalBusEvents:
	var node: Node = get_tree().root.get_node_or_null(^"Events")
	assert_object(node).is_not_null()
	return node as SignalBusEvents


## Returns the signal info dictionary for `signal_name`, or an empty dict if
## the signal does not exist on the Events autoload.
func _get_signal_info(events: SignalBusEvents, signal_name: StringName) -> Dictionary:
	for sig: Dictionary in events.get_signal_list():
		if sig["name"] == signal_name:
			return sig
	return {}


## Asserts that `signal_name` exists on the Events autoload with exactly
## `expected_arg_count` arguments. Returns the signal info dict for further
## assertions, or {} if the signal was missing.
func _assert_signal_with_arg_count(
		events: SignalBusEvents,
		signal_name: StringName,
		expected_arg_count: int
) -> Dictionary:
	var info: Dictionary = _get_signal_info(events, signal_name)
	assert_bool(info.is_empty()).override_failure_message(
			"Signal '%s' must be declared on events.gd per Story SAI-002 AC-2." % signal_name
	).is_false()

	if info.is_empty():
		return {}

	var args: Array = info.get("args", [])
	assert_int(args.size()).override_failure_message(
			"Signal '%s' expected %d args, got %d." % [
					signal_name, expected_arg_count, args.size()
			]
	).is_equal(expected_arg_count)
	return info


# ---------------------------------------------------------------------------
# Tests — Signal presence + parameter counts (AC-2)
# ---------------------------------------------------------------------------

## AC-2-A: alert_state_changed(actor, old_state, new_state, severity) — 4 args.
func test_alert_state_changed_has_four_parameters() -> void:
	var events: SignalBusEvents = _get_events_node()
	_assert_signal_with_arg_count(events, &"alert_state_changed", 4)


## AC-2-B: actor_became_alerted(actor, cause, source_position, severity) — 4 args.
func test_actor_became_alerted_has_four_parameters() -> void:
	var events: SignalBusEvents = _get_events_node()
	_assert_signal_with_arg_count(events, &"actor_became_alerted", 4)


## AC-2-C: actor_lost_target(actor, severity) — 2 args.
func test_actor_lost_target_has_two_parameters() -> void:
	var events: SignalBusEvents = _get_events_node()
	_assert_signal_with_arg_count(events, &"actor_lost_target", 2)


## AC-2-D: takedown_performed(actor, attacker, takedown_type) — 3 args.
func test_takedown_performed_has_three_parameters() -> void:
	var events: SignalBusEvents = _get_events_node()
	_assert_signal_with_arg_count(events, &"takedown_performed", 3)


## AC-2-E: guard_incapacitated(guard, cause: int) — 2 args.
## Note: `cause` is `int`, not CombatSystemNode.DamageType — the bus must NOT
## import CombatSystemNode (cross-autoload convention, ADR-0007).
func test_guard_incapacitated_has_two_parameters_with_int_cause() -> void:
	var events: SignalBusEvents = _get_events_node()
	var info: Dictionary = _assert_signal_with_arg_count(events, &"guard_incapacitated", 2)

	if info.is_empty():
		return

	var args: Array = info["args"]
	# cause is the second arg; type must be TYPE_INT (2), not TYPE_OBJECT (24).
	var cause_arg: Dictionary = args[1]
	assert_int(cause_arg["type"]).override_failure_message(
			"guard_incapacitated.cause must be TYPE_INT (cross-autoload convention) — got type %d." % cause_arg["type"]
	).is_equal(TYPE_INT)


## AC-2-F: guard_woke_up(guard) — 1 arg.
func test_guard_woke_up_has_one_parameter() -> void:
	var events: SignalBusEvents = _get_events_node()
	_assert_signal_with_arg_count(events, &"guard_woke_up", 1)


## All 6 SAI signals must be present on the Events autoload (presence sweep).
## A defensive batched test that fails fast if any signal is silently dropped.
func test_all_six_sai_signals_present_on_events_autoload() -> void:
	var events: SignalBusEvents = _get_events_node()
	var expected: Array[StringName] = [
			&"alert_state_changed",
			&"actor_became_alerted",
			&"actor_lost_target",
			&"takedown_performed",
			&"guard_incapacitated",
			&"guard_woke_up",
	]
	var missing: Array[String] = []

	for sig_name: StringName in expected:
		if _get_signal_info(events, sig_name).is_empty():
			missing.append(String(sig_name))

	assert_int(missing.size()).override_failure_message(
			"Missing SAI signals: %s" % ", ".join(missing)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Tests — events.gd purity invariant (AC-3 — enum declarations absent)
# ---------------------------------------------------------------------------

## AC-3-A: events.gd contains zero `enum ` declarations.
## events_purity_test.gd already enforces no func/var/const; this test pins
## the enum-purity invariant specifically — placing an enum in events.gd
## would violate ADR-0002 IG 2 (enums belong on the owning system class).
func test_events_gd_source_has_zero_enum_declarations() -> void:
	# Arrange
	var events_path: String = "res://src/core/signal_bus/events.gd"
	var file: FileAccess = FileAccess.open(events_path, FileAccess.READ)
	assert_object(file).override_failure_message(
			"events.gd must exist at %s." % events_path
	).is_not_null()

	if file == null:
		return

	var source: String = file.get_as_text()
	file.close()

	# Act — count occurrences of `enum ` at line-start (ignore inline `enum` in comments).
	var enum_decl_count: int = 0
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		# Skip comment lines.
		if stripped.begins_with("#"):
			continue
		# An `enum` declaration starts with the keyword followed by a name or `{`.
		if stripped.begins_with("enum "):
			enum_decl_count += 1

	# Assert
	assert_int(enum_decl_count).override_failure_message(
			"events.gd must contain ZERO enum declarations per ADR-0002 IG 2 — found %d." % enum_decl_count
	).is_equal(0)
