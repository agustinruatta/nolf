# tests/unit/feature/stealth_ai/stealth_ai_severity_rule_test.gd
#
# StealthAI._compute_severity 42-cell matrix test — Story SAI-002 AC-4.
#
# PURPOSE
#   Verifies the _compute_severity rule across the full Cartesian product of
#   AlertState (6 values) × AlertCause (7 values) = 42 cells.
#
#   Authoritative rule (GDD §Detailed Rules):
#     1. cause == ALERTED_BY_OTHER → MINOR (peer-radio is low-drama).
#     2. new_state in {SEARCHING, COMBAT, DEAD, UNCONSCIOUS} → MAJOR.
#     3. else → MINOR.
#
# WHAT IS TESTED
#   AC-4-A: All 42 (state, cause) cells return the expected Severity.
#   AC-4-B: ALERTED_BY_OTHER cause overrides state-based MAJOR (uniform MINOR row).
#   AC-4-C: UNCONSCIOUS state row is uniformly MAJOR (except ALERTED_BY_OTHER).
#   AC-4-D: DEAD state row is uniformly MAJOR (except ALERTED_BY_OTHER).
#   AC-4-E: UNAWARE state row is uniformly MINOR (no state-based MAJOR trigger).
#   AC-4-F: SUSPICIOUS state row is uniformly MINOR (no state-based MAJOR trigger).

class_name StealthAISeverityRuleTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the expected Severity for a (state, cause) pair, encoding the GDD
## rule. Used as the test oracle for the 42-cell matrix.
func _expected_severity(state: StealthAI.AlertState, cause: StealthAI.AlertCause) -> StealthAI.Severity:
	if cause == StealthAI.AlertCause.ALERTED_BY_OTHER:
		return StealthAI.Severity.MINOR
	if state == StealthAI.AlertState.SEARCHING \
			or state == StealthAI.AlertState.COMBAT \
			or state == StealthAI.AlertState.DEAD \
			or state == StealthAI.AlertState.UNCONSCIOUS:
		return StealthAI.Severity.MAJOR
	return StealthAI.Severity.MINOR


## Returns a human-readable name for an AlertState (for failure messages).
func _state_name(state: StealthAI.AlertState) -> String:
	match state:
		StealthAI.AlertState.UNAWARE: return "UNAWARE"
		StealthAI.AlertState.SUSPICIOUS: return "SUSPICIOUS"
		StealthAI.AlertState.SEARCHING: return "SEARCHING"
		StealthAI.AlertState.COMBAT: return "COMBAT"
		StealthAI.AlertState.UNCONSCIOUS: return "UNCONSCIOUS"
		StealthAI.AlertState.DEAD: return "DEAD"
	return "UNKNOWN_STATE_%d" % state


## Returns a human-readable name for an AlertCause (for failure messages).
func _cause_name(cause: StealthAI.AlertCause) -> String:
	match cause:
		StealthAI.AlertCause.HEARD_NOISE: return "HEARD_NOISE"
		StealthAI.AlertCause.SAW_PLAYER: return "SAW_PLAYER"
		StealthAI.AlertCause.SAW_BODY: return "SAW_BODY"
		StealthAI.AlertCause.HEARD_GUNFIRE: return "HEARD_GUNFIRE"
		StealthAI.AlertCause.ALERTED_BY_OTHER: return "ALERTED_BY_OTHER"
		StealthAI.AlertCause.SCRIPTED: return "SCRIPTED"
		StealthAI.AlertCause.CURIOSITY_BAIT: return "CURIOSITY_BAIT"
	return "UNKNOWN_CAUSE_%d" % cause


# ---------------------------------------------------------------------------
# Tests — Full 42-cell matrix (AC-4-A)
# ---------------------------------------------------------------------------

## AC-4-A: All 42 (state, cause) combinations produce the expected Severity.
## Rather than 42 individual functions, this single batched test covers every
## cell with a per-cell failure message identifying the offending pair.
func test_compute_severity_full_42_cell_matrix() -> void:
	var failures: Array[String] = []

	for state: StealthAI.AlertState in StealthAI.AlertState.values():
		for cause: StealthAI.AlertCause in StealthAI.AlertCause.values():
			var expected: StealthAI.Severity = _expected_severity(state, cause)
			var actual: StealthAI.Severity = StealthAI._compute_severity(state, cause)
			if actual != expected:
				failures.append(
						"Cell (%s, %s): expected %d, got %d" % [
								_state_name(state), _cause_name(cause), expected, actual
						]
				)

	assert_int(failures.size()).override_failure_message(
			"42-cell severity matrix had %d mismatched cells: %s" % [
					failures.size(), ", ".join(failures)
			]
	).is_equal(0)


# ---------------------------------------------------------------------------
# Tests — Row-level invariants (AC-4-B..F)
# ---------------------------------------------------------------------------

## AC-4-B: ALERTED_BY_OTHER cause is uniformly MINOR across all 6 states.
## This rule overrides the state-based MAJOR check for SEARCHING / COMBAT /
## DEAD / UNCONSCIOUS — peer-radio alerts are low-drama by design.
func test_alerted_by_other_cause_is_uniformly_minor() -> void:
	var cause: StealthAI.AlertCause = StealthAI.AlertCause.ALERTED_BY_OTHER

	for state: StealthAI.AlertState in StealthAI.AlertState.values():
		var actual: StealthAI.Severity = StealthAI._compute_severity(state, cause)
		assert_int(actual).override_failure_message(
				"ALERTED_BY_OTHER cause must be MINOR for state %s — peer-radio is low-drama" % _state_name(state)
		).is_equal(StealthAI.Severity.MINOR)


## AC-4-C: UNCONSCIOUS state is uniformly MAJOR (except ALERTED_BY_OTHER).
## A guard's removal from play is high-salience for Mission Scripting + Audio.
func test_unconscious_state_is_uniformly_major_except_alerted_by_other() -> void:
	var state: StealthAI.AlertState = StealthAI.AlertState.UNCONSCIOUS

	for cause: StealthAI.AlertCause in StealthAI.AlertCause.values():
		var expected: StealthAI.Severity = StealthAI.Severity.MINOR \
				if cause == StealthAI.AlertCause.ALERTED_BY_OTHER \
				else StealthAI.Severity.MAJOR
		var actual: StealthAI.Severity = StealthAI._compute_severity(state, cause)
		assert_int(actual).override_failure_message(
				"UNCONSCIOUS / %s expected %d, got %d" % [
						_cause_name(cause), expected, actual
				]
		).is_equal(expected)


## AC-4-D: DEAD state is uniformly MAJOR (except ALERTED_BY_OTHER).
func test_dead_state_is_uniformly_major_except_alerted_by_other() -> void:
	var state: StealthAI.AlertState = StealthAI.AlertState.DEAD

	for cause: StealthAI.AlertCause in StealthAI.AlertCause.values():
		var expected: StealthAI.Severity = StealthAI.Severity.MINOR \
				if cause == StealthAI.AlertCause.ALERTED_BY_OTHER \
				else StealthAI.Severity.MAJOR
		var actual: StealthAI.Severity = StealthAI._compute_severity(state, cause)
		assert_int(actual).override_failure_message(
				"DEAD / %s expected %d, got %d" % [
						_cause_name(cause), expected, actual
				]
		).is_equal(expected)


## AC-4-E: UNAWARE state is uniformly MINOR (no state-based MAJOR trigger).
func test_unaware_state_is_uniformly_minor() -> void:
	var state: StealthAI.AlertState = StealthAI.AlertState.UNAWARE

	for cause: StealthAI.AlertCause in StealthAI.AlertCause.values():
		var actual: StealthAI.Severity = StealthAI._compute_severity(state, cause)
		assert_int(actual).override_failure_message(
				"UNAWARE / %s must be MINOR (no state-based MAJOR trigger)" % _cause_name(cause)
		).is_equal(StealthAI.Severity.MINOR)


## AC-4-F: SUSPICIOUS state is uniformly MINOR (no state-based MAJOR trigger).
## A guard becoming SUSPICIOUS does not warrant the brass-punch stinger —
## that is reserved for the SUSPICIOUS → SEARCHING transition (which produces
## a MAJOR result via the SEARCHING branch).
func test_suspicious_state_is_uniformly_minor() -> void:
	var state: StealthAI.AlertState = StealthAI.AlertState.SUSPICIOUS

	for cause: StealthAI.AlertCause in StealthAI.AlertCause.values():
		var actual: StealthAI.Severity = StealthAI._compute_severity(state, cause)
		assert_int(actual).override_failure_message(
				"SUSPICIOUS / %s must be MINOR (no state-based MAJOR trigger)" % _cause_name(cause)
		).is_equal(StealthAI.Severity.MINOR)


## Sanity: SEARCHING / SAW_PLAYER → MAJOR (canonical example from GDD).
func test_searching_with_saw_player_is_major() -> void:
	var result: StealthAI.Severity = StealthAI._compute_severity(
			StealthAI.AlertState.SEARCHING,
			StealthAI.AlertCause.SAW_PLAYER
	)
	assert_int(result).is_equal(StealthAI.Severity.MAJOR)


## Sanity: COMBAT / SAW_PLAYER → MAJOR (canonical example from GDD).
func test_combat_with_saw_player_is_major() -> void:
	var result: StealthAI.Severity = StealthAI._compute_severity(
			StealthAI.AlertState.COMBAT,
			StealthAI.AlertCause.SAW_PLAYER
	)
	assert_int(result).is_equal(StealthAI.Severity.MAJOR)
