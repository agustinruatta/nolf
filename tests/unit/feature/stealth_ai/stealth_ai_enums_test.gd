# tests/unit/feature/stealth_ai/stealth_ai_enums_test.gd
#
# StealthAI enum presence test — Story SAI-002 AC-1.
#
# PURPOSE
#   Proves that src/gameplay/stealth/stealth_ai.gd declares the four SAI-domain
#   enum types (AlertState, AlertCause, Severity, TakedownType) on the
#   StealthAI class, with the exact value counts specified by Story AC-1, and
#   that specific named members resolve at parse time.
#
# WHAT IS TESTED
#   AC-1-A: All 4 enums exist on StealthAI and resolve at runtime.
#   AC-1-B: AlertState has exactly 6 values (UNAWARE..DEAD).
#   AC-1-C: AlertCause has exactly 7 values (HEARD_NOISE..CURIOSITY_BAIT).
#   AC-1-D: Severity has exactly 2 values (MINOR, MAJOR).
#   AC-1-E: TakedownType has exactly 2 values (MELEE_NONLETHAL, STEALTH_BLADE).
#   AC-1-F: AlertState.UNAWARE is the zero / initial value (GDScript enum order).
#   AC-1-G: Severity.MINOR is the zero value (default for un-set Severity).
#
# WHAT IS NOT TESTED HERE
#   - _compute_severity 6×7 matrix — see stealth_ai_severity_rule_test.gd.
#   - Signal declarations using these enums — see events_sai_signals_test.gd.
#   - events.gd purity — see events_purity_test.gd.

class_name StealthAIEnumsTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Tests — Enum presence + value counts (AC-1)
# ---------------------------------------------------------------------------

## AC-1-B: AlertState declares exactly 6 values.
func test_alert_state_enum_has_six_values() -> void:
	# Arrange — no fixture; enum is parse-time data on StealthAI.

	# Act
	var values: Array = StealthAI.AlertState.values()

	# Assert
	assert_int(values.size()).override_failure_message(
			"AlertState must declare exactly 6 values per Story SAI-002 AC-1."
	).is_equal(6)


## AC-1-B: AlertState members resolve to expected names.
func test_alert_state_members_resolve_by_name() -> void:
	# Act + Assert — each named member must resolve without error.
	assert_int(StealthAI.AlertState.UNAWARE).is_greater_equal(0)
	assert_int(StealthAI.AlertState.SUSPICIOUS).is_greater_equal(0)
	assert_int(StealthAI.AlertState.SEARCHING).is_greater_equal(0)
	assert_int(StealthAI.AlertState.COMBAT).is_greater_equal(0)
	assert_int(StealthAI.AlertState.UNCONSCIOUS).is_greater_equal(0)
	assert_int(StealthAI.AlertState.DEAD).is_greater_equal(0)


## AC-1-F: UNAWARE is the zero / initial value.
## GDScript enums assign sequential ints starting at 0 in declaration order.
## Ordering matters: a Guard's `current_alert_state: int = 0` (Story 001 stub)
## must equal AlertState.UNAWARE for the SAI-001 → SAI-002 transition to be
## semantically safe.
func test_alert_state_unaware_is_zero() -> void:
	assert_int(StealthAI.AlertState.UNAWARE).override_failure_message(
			"AlertState.UNAWARE must be 0 — Story SAI-001 stub `current_alert_state: int = 0` " +
			"depends on UNAWARE being the zero / first declared value."
	).is_equal(0)


## AC-1-C: AlertCause declares exactly 7 values (story-spec authoritative form).
## Note: TR-SAI-005 lists 5 values; story AC-1 lists 7. Story spec wins per
## the implementation guidance in stealth_ai.gd header.
func test_alert_cause_enum_has_seven_values() -> void:
	var values: Array = StealthAI.AlertCause.values()

	assert_int(values.size()).override_failure_message(
			"AlertCause must declare exactly 7 values per Story SAI-002 AC-1 " +
			"(TR-SAI-005 lists 5; story spec is authoritative)."
	).is_equal(7)


## AC-1-C: AlertCause members resolve to expected names.
func test_alert_cause_members_resolve_by_name() -> void:
	assert_int(StealthAI.AlertCause.HEARD_NOISE).is_greater_equal(0)
	assert_int(StealthAI.AlertCause.SAW_PLAYER).is_greater_equal(0)
	assert_int(StealthAI.AlertCause.SAW_BODY).is_greater_equal(0)
	assert_int(StealthAI.AlertCause.HEARD_GUNFIRE).is_greater_equal(0)
	assert_int(StealthAI.AlertCause.ALERTED_BY_OTHER).is_greater_equal(0)
	assert_int(StealthAI.AlertCause.SCRIPTED).is_greater_equal(0)
	assert_int(StealthAI.AlertCause.CURIOSITY_BAIT).is_greater_equal(0)


## AC-1-D: Severity declares exactly 2 values (MINOR, MAJOR).
func test_severity_enum_has_two_values() -> void:
	var values: Array = StealthAI.Severity.values()

	assert_int(values.size()).override_failure_message(
			"Severity must declare exactly 2 values (MINOR, MAJOR) per TR-SAI-004."
	).is_equal(2)


## AC-1-G: Severity.MINOR is the zero value.
## Default-initialised Severity vars default to MINOR (no stinger emitted),
## which is the safer fallback per Pillar 1 (comedy preservation).
func test_severity_minor_is_zero() -> void:
	assert_int(StealthAI.Severity.MINOR).override_failure_message(
			"Severity.MINOR must be 0 so default-initialised Severity vars do not " +
			"accidentally emit the brass-punch stinger (Pillar 1 comedy preservation)."
	).is_equal(0)


## AC-1-E: TakedownType declares exactly 2 values.
func test_takedown_type_enum_has_two_values() -> void:
	var values: Array = StealthAI.TakedownType.values()

	assert_int(values.size()).override_failure_message(
			"TakedownType must declare exactly 2 values per TR-SAI-006."
	).is_equal(2)


## AC-1-E: TakedownType members resolve to expected names.
func test_takedown_type_members_resolve_by_name() -> void:
	assert_int(StealthAI.TakedownType.MELEE_NONLETHAL).is_greater_equal(0)
	assert_int(StealthAI.TakedownType.STEALTH_BLADE).is_greater_equal(0)


## AC-1-A: All 4 enum types resolve as Dictionary at runtime (sanity check).
## A missing or misspelled enum would surface here as a parse-time error in
## the test loader, but this functional check confirms the 4 types are all
## populated and distinct.
func test_all_four_enums_are_populated() -> void:
	var alert_state_count: int = StealthAI.AlertState.values().size()
	var alert_cause_count: int = StealthAI.AlertCause.values().size()
	var severity_count: int = StealthAI.Severity.values().size()
	var takedown_count: int = StealthAI.TakedownType.values().size()

	assert_int(alert_state_count + alert_cause_count + severity_count + takedown_count) \
			.override_failure_message(
					"Expected 6 + 7 + 2 + 2 = 17 enum values across the 4 SAI enums."
			).is_equal(17)
