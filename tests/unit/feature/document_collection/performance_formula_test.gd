# tests/unit/feature/document_collection/performance_formula_test.gd
#
# PerformanceFormulaTest — GdUnit4 unit suite for GDD §F.1 pickup-cost formula
#                          arithmetic (DC-004, AC-DC-9.1 / AC-DC-9.2).
#
# PURPOSE
#   Validates the F.1 pickup-cost formula components in pure arithmetic — no game
#   objects, no scene tree, no engine APIs. These tests document the ADR-0008
#   sub-slot claim in executable form and serve as a permanent record of the
#   budget analysis.
#
# F.1 FORMULA (GDD §F.1):
#   t_pickup = t_signal_dispatch + t_set_membership + t_array_append
#            + t_signal_emit + t_call_deferred
#   where t_signal_emit = t_per_subscriber * N_subscribers
#
# COMPONENT VALUES (GDD §F.1 example):
#   t_signal_dispatch  = 0.008 ms   (fixed — signal routing overhead)
#   t_set_membership   = 0.002 ms   (fixed — _collected.has() lookup)
#   t_array_append     = 0.001 ms   (fixed — append to Array[StringName])
#   t_per_subscriber   = 0.008 ms   (per subscriber — document_collected emit cost)
#   t_call_deferred    = 0.003 ms   (fixed — queue_free deferral overhead)
#
# AT N=4: t_signal_emit = 0.008 * 4 = 0.032 ms; total = 0.046 ms; headroom = 8%
# AT N=6: t_signal_emit = 0.008 * 6 = 0.048 ms; total = 0.062 ms; budget BREACH
#
# COVERED ACCEPTANCE CRITERIA
#   AC-8 (AC-DC-9.1) — N=4 formula yields 0.046 ms ± 0.0005 ms; within 0.05ms budget; >=8% headroom.
#   AC-9 (AC-DC-9.2) — N=6 formula exceeds 0.05 ms budget (triggers ADR-0008 review).
#
# GATE STATUS
#   Story DC-004 — Integration story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md + .claude/rules/test-standards.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name PerformanceFormulaTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Formula constants — GDD §F.1 component values
# (not gameplay tuning values; these ARE the literal point of these tests)
# ---------------------------------------------------------------------------

## Fixed per-call overhead of emitting a signal through the Event Bus.
## t_signal_dispatch in GDD §F.1.
const T_SIGNAL_DISPATCH_MS: float = 0.008

## Fixed cost of Array[StringName].has() — _collected membership check.
## t_set_membership in GDD §F.1.
const T_SET_MEMBERSHIP_MS: float = 0.002

## Fixed cost of Array[StringName].append() — appending one id to _collected.
## t_array_append in GDD §F.1.
const T_ARRAY_APPEND_MS: float = 0.001

## Per-subscriber cost factor for document_collected signal emission.
## t_per_subscriber in GDD §F.1; t_signal_emit = T_PER_SUBSCRIBER * N_subscribers.
const T_PER_SUBSCRIBER_MS: float = 0.008

## Fixed cost of call_deferred("queue_free") for body removal scheduling.
## t_call_deferred in GDD §F.1.
const T_CALL_DEFERRED_MS: float = 0.003

## Frame budget per GDD §F.1 / ADR-0008 sub-slot allocation.
## 0.05 ms is the allowable ceiling for one document pickup event.
const PICKUP_BUDGET_MS: float = 0.05

## Required minimum headroom fraction (8%) per ADR-0008 sub-slot claim.
const REQUIRED_HEADROOM_FRACTION: float = 0.08

## Tolerance for floating-point equality checks (±0.0005 ms).
const FLOAT_TOLERANCE_MS: float = 0.0005


# ---------------------------------------------------------------------------
# Helper — compute F.1 pickup cost given subscriber count
# ---------------------------------------------------------------------------

## Evaluates GDD §F.1 pickup cost formula for N_subscribers.
## Returns total cost in milliseconds.
## This is pure arithmetic — no engine API calls, no scene tree interaction.
func _compute_f1_cost(n_subscribers: int) -> float:
	var t_signal_emit: float = T_PER_SUBSCRIBER_MS * float(n_subscribers)
	return (
		T_SIGNAL_DISPATCH_MS
		+ T_SET_MEMBERSHIP_MS
		+ T_ARRAY_APPEND_MS
		+ t_signal_emit
		+ T_CALL_DEFERRED_MS
	)


# ---------------------------------------------------------------------------
# AC-8 (AC-DC-9.1) — N=4 within budget with >=8% headroom
# ---------------------------------------------------------------------------

## GIVEN N_subscribers = 4 and the GDD §F.1 component values
## WHEN the F.1 formula is evaluated
## THEN result == 0.046 ms ± 0.0005 ms
## AND result < 0.05 ms (within pickup budget)
## AND (0.05 - result) / 0.05 >= 0.08 (at least 8% headroom).
func test_f1_pickup_cost_at_n4_within_budget() -> void:
	# Arrange
	const N_SUBSCRIBERS: int = 4
	const EXPECTED_MS: float = 0.046  # GDD §F.1 example sum

	# Act
	var cost_ms: float = _compute_f1_cost(N_SUBSCRIBERS)

	# Assert — result equals expected within tolerance.
	assert_float(cost_ms).override_failure_message(
		"AC-8: F.1 at N=4 must equal 0.046 ms ± 0.0005 ms. "
		+ "Got: %.6f ms (components: dispatch=%.3f, membership=%.3f, append=%.3f, "
		+ "emit=%.3f, deferred=%.3f)" % [
			cost_ms,
			T_SIGNAL_DISPATCH_MS, T_SET_MEMBERSHIP_MS, T_ARRAY_APPEND_MS,
			T_PER_SUBSCRIBER_MS * N_SUBSCRIBERS, T_CALL_DEFERRED_MS
		]
	).is_between(EXPECTED_MS - FLOAT_TOLERANCE_MS, EXPECTED_MS + FLOAT_TOLERANCE_MS)

	# Assert — result is within the pickup budget.
	assert_bool(cost_ms < PICKUP_BUDGET_MS).override_failure_message(
		"AC-8: F.1 at N=4 must be < %.3f ms (pickup budget). Got: %.6f ms." % [
			PICKUP_BUDGET_MS, cost_ms
		]
	).is_true()

	# Assert — headroom >= 8%.
	var headroom_fraction: float = (PICKUP_BUDGET_MS - cost_ms) / PICKUP_BUDGET_MS
	assert_bool(headroom_fraction >= REQUIRED_HEADROOM_FRACTION).override_failure_message(
		"AC-8: F.1 at N=4 must have >= %.0f%% headroom. "
		+ "Got %.1f%% headroom (cost=%.6f ms, budget=%.3f ms)." % [
			REQUIRED_HEADROOM_FRACTION * 100.0,
			headroom_fraction * 100.0,
			cost_ms, PICKUP_BUDGET_MS
		]
	).is_true()


# ---------------------------------------------------------------------------
# AC-9 (AC-DC-9.2) — N=6 breaches budget, triggers ADR-0008 review
# ---------------------------------------------------------------------------

## GIVEN N_subscribers = 6 and worst-case GDD §F.1 component values
## WHEN the F.1 formula is evaluated
## THEN result > 0.05 ms (budget breach confirmed)
## Confirms that a 6th document_collected subscriber triggers an ADR-0008
## sub-slot amendment review. This test MUST pass (budget breach expected).
func test_f1_at_n6_breaches_budget_and_triggers_review() -> void:
	# Arrange
	const N_SUBSCRIBERS: int = 6
	const EXPECTED_EMIT_MS: float = T_PER_SUBSCRIBER_MS * N_SUBSCRIBERS  # 0.048 ms
	const EXPECTED_TOTAL_MS: float = 0.062  # GDD §F.1 N=6 example

	# Act
	var cost_ms: float = _compute_f1_cost(N_SUBSCRIBERS)

	# Assert — t_signal_emit at N=6 equals 0.048 ms.
	assert_float(EXPECTED_EMIT_MS).override_failure_message(
		"AC-9: t_signal_emit at N=6 must equal 0.008 * 6 = 0.048 ms."
	).is_between(0.048 - FLOAT_TOLERANCE_MS, 0.048 + FLOAT_TOLERANCE_MS)

	# Assert — total cost equals expected 0.062 ms (within tolerance).
	assert_float(cost_ms).override_failure_message(
		"AC-9: F.1 at N=6 must equal 0.062 ms ± 0.0005 ms. Got: %.6f ms." % cost_ms
	).is_between(EXPECTED_TOTAL_MS - FLOAT_TOLERANCE_MS, EXPECTED_TOTAL_MS + FLOAT_TOLERANCE_MS)

	# Assert — budget is breached (result > 0.05 ms).
	# This is the EXPECTED outcome; a PASS here means the budget analysis is correct.
	assert_bool(cost_ms > PICKUP_BUDGET_MS).override_failure_message(
		"AC-9: F.1 at N=6 MUST exceed the %.3f ms budget (%.6f ms). "
		+ "If this fails, the formula components have changed — update ADR-0008." % [
			PICKUP_BUDGET_MS, cost_ms
		]
	).is_true()
