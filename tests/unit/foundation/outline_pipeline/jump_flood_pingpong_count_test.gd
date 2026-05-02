# tests/unit/foundation/outline_pipeline/jump_flood_pingpong_count_test.gd
#
# JumpFloodPingpongCountTest — GdUnit4 unit tests for OUT-003 AC-2 Logic facet.
#
# PURPOSE
#   Verifies the pure-math helper `OutlineCompositorEffect.pingpong_pass_count()`
#   that determines how many ping-pong compute passes the jump-flood algorithm
#   needs for a given maximum outline radius. This is the ONE testable Logic
#   facet of OUT-003 — the rest of the story is GPU rendered output, captured
#   in OUT-005 visual sign-off.
#
# FORMULA (per ADR-0001 Stage 2 + GDD §Formulas Formula 1)
#   passes = max(1, ceil(log2(max_radius_px)))
#   max_radius_px ≤ 0 → defensive clamp to 1
#
# WHAT IS TESTED
#   AC-2 (Logic facet): returns expected pass counts for the four production
#   tier radii (4.0, 2.5, 1.5, 8.0 — synthetic stretch case) plus boundary
#   inputs (1.0, 0.0, negative).
#
# WHAT IS NOT TESTED HERE
#   - GPU compute shader correctness — captured in OUT-005 visual sign-off
#   - Per-pass step_size sequence — derivable from pingpong_pass_count + index
#   - Outline color / thickness / lighting invariance — visual evidence
#
# GATE STATUS
#   Story OUT-003 | Visual/Feel + Logic facets — Logic facet is BLOCKING for
#   the formula correctness; visual ACs are ADVISORY (sign-off in OUT-005).
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name JumpFloodPingpongCountTest
extends GdUnitTestSuite


# ── Fixture ────────────────────────────────────────────────────────────────

var _effect: OutlineCompositorEffect = null


func before_test() -> void:
	# OutlineCompositorEffect extends Resource (RefCounted) — no add_child needed.
	# pingpong_pass_count is a pure-math member function, no GPU state required.
	_effect = OutlineCompositorEffect.new()


func after_test() -> void:
	_effect = null


# ── AC-2 Logic facet: production tier radii ────────────────────────────────

## Tier 1 (HEAVIEST, 4.0 px @ 1080p) → 2 passes (ceil(log2(4)) = 2).
func test_pingpong_pass_count_tier1_4px_returns_2() -> void:
	assert_int(_effect.pingpong_pass_count(4.0)).override_failure_message(
		"Tier 1 (4 px) must require 2 ping-pong passes (ceil(log2(4)) = 2)."
	).is_equal(2)


## Tier 2 (MEDIUM, 2.5 px @ 1080p) → 2 passes (ceil(log2(2.5)) ≈ ceil(1.32) = 2).
func test_pingpong_pass_count_tier2_2_5px_returns_2() -> void:
	assert_int(_effect.pingpong_pass_count(2.5)).override_failure_message(
		"Tier 2 (2.5 px) must require 2 ping-pong passes (ceil(log2(2.5)) = ceil(1.32) = 2)."
	).is_equal(2)


## Tier 3 (LIGHT, 1.5 px @ 1080p) → 1 pass (ceil(log2(1.5)) ≈ ceil(0.58) = 1).
func test_pingpong_pass_count_tier3_1_5px_returns_1() -> void:
	assert_int(_effect.pingpong_pass_count(1.5)).override_failure_message(
		"Tier 3 (1.5 px) must require 1 ping-pong pass (ceil(log2(1.5)) = ceil(0.58) = 1)."
	).is_equal(1)


## Stretch case: 8.0 px (hypothetical wider tier) → 3 passes (ceil(log2(8)) = 3).
func test_pingpong_pass_count_8px_returns_3() -> void:
	assert_int(_effect.pingpong_pass_count(8.0)).override_failure_message(
		"8 px outline must require 3 ping-pong passes (ceil(log2(8)) = 3)."
	).is_equal(3)


# ── Boundary cases ────────────────────────────────────────────────────────

## 1.0 px (log2(1) = 0; clamped to minimum 1 pass so the seed → output pipeline
## still runs at least one seed-propagation iteration).
func test_pingpong_pass_count_1px_clamps_to_min_1() -> void:
	assert_int(_effect.pingpong_pass_count(1.0)).override_failure_message(
		"1 px outline must clamp to minimum 1 pass (log2(1) = 0; we still need ≥1 pass)."
	).is_equal(1)


## 0.0 px (defensive: log2 undefined for zero — clamp to 1 to avoid arithmetic fault).
func test_pingpong_pass_count_zero_clamps_to_1() -> void:
	assert_int(_effect.pingpong_pass_count(0.0)).override_failure_message(
		"max_radius_px = 0 must clamp to 1 pass (defensive guard against log2(0))."
	).is_equal(1)


## Negative input (defensive: never call log on a negative value — clamp to 1).
func test_pingpong_pass_count_negative_clamps_to_1() -> void:
	assert_int(_effect.pingpong_pass_count(-5.0)).override_failure_message(
		"Negative max_radius_px must clamp to 1 pass (defensive guard)."
	).is_equal(1)


# ── Sanity check on log2 derivation ───────────────────────────────────────

## Power-of-two input — verify the GDScript log2 derivation (log(x) / log(2))
## produces the same integer result as a hand-computed log2 for round inputs.
func test_pingpong_pass_count_16px_returns_4() -> void:
	# log2(16) = 4 exactly.
	assert_int(_effect.pingpong_pass_count(16.0)).override_failure_message(
		"16 px must require 4 passes (log2(16) = 4 exactly)."
	).is_equal(4)
