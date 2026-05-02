# tests/unit/foundation/outline_pipeline/outline_tier_kernel_formula_test.gd
#
# OutlineTierKernelFormulaTest — GdUnit4 unit tests for OUT-004.
#
# PURPOSE
#   Verifies the static helper `OutlineCompositorEffect._compute_kernel_actual()`
#   that implements GDD §Formulas Formula 2:
#       kernel_actual = max(0.5, kernel_px × res_scale × (render_height / 1080))
#
#   Also verifies the Events.setting_changed handler updates `resolution_scale`
#   only for the correct category/name pair, and rejects malformed payloads.
#
# WHAT IS TESTED (Logic facets)
#   AC-3: tier 1/2/3 production radii at 0.75 scale → expected outputs
#   AC-4: identity (resolution_scale=1.0, height=1080) → unchanged kernel
#   AC-5: 0.5 px clamp triggers when raw value goes below threshold
#   AC-7: signal-driven dynamic update — resolution_scale member responds to
#         Events.setting_changed broadcasts
#   AC-8: pure-math correctness across boundary inputs
#
# WHAT IS NOT TESTED HERE
#   AC-1: SettingsService startup read — cross-epic dependency on the Settings
#         & Accessibility GDD landing; pending until that epic exposes the API
#   AC-6: Iris Xe vs RTX 2060+ default branch — also Settings & Accessibility
#         epic scope; this story only consumes the value
#
# GATE STATUS
#   Story OUT-004 | Logic type → BLOCKING gate.
#
# NAMING CONVENTION
#   File  : outline_tier_kernel_formula_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name OutlineTierKernelFormulaTest
extends GdUnitTestSuite


# ── Fixture ────────────────────────────────────────────────────────────────

const _TOL: float = 0.001

var _effect: OutlineCompositorEffect = null


func before_test() -> void:
	# OutlineCompositorEffect extends Resource — no add_child required.
	_effect = OutlineCompositorEffect.new()


func after_test() -> void:
	# Disconnect setting_changed handler if it was connected during the test.
	if _effect != null and Events.setting_changed.is_connected(_effect._on_setting_changed):
		Events.setting_changed.disconnect(_effect._on_setting_changed)
	_effect = null


# ── AC-4: identity case — full resolution, no scaling ─────────────────────

## Tier 1 at native 1080p with resolution_scale = 1.0 → 4.0 px exactly (AC-4).
func test_compute_kernel_actual_tier1_native_1080p_returns_4_0() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(4.0, 1.0, 1080)
	assert_float(actual).override_failure_message(
		"Tier 1 at resolution_scale=1.0, height=1080 must equal base 4.0 px."
	).is_equal_approx(4.0, _TOL)


## Tier 2 native → 2.5 px exactly.
func test_compute_kernel_actual_tier2_native_1080p_returns_2_5() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(2.5, 1.0, 1080)
	assert_float(actual).is_equal_approx(2.5, _TOL)


## Tier 3 native → 1.5 px exactly.
func test_compute_kernel_actual_tier3_native_1080p_returns_1_5() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(1.5, 1.0, 1080)
	assert_float(actual).is_equal_approx(1.5, _TOL)


# ── AC-3: production tier radii at 0.75 scale ─────────────────────────────

## Tier 1 at 0.75 scale → 4.0 × 0.75 = 3.0 px (AC-3).
func test_compute_kernel_actual_tier1_75pct_scale_returns_3_0() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(4.0, 0.75, 1080)
	assert_float(actual).override_failure_message(
		"Tier 1 at resolution_scale=0.75, height=1080 must equal 3.0 px."
	).is_equal_approx(3.0, _TOL)


## Tier 2 at 0.75 scale → 2.5 × 0.75 = 1.875 px.
func test_compute_kernel_actual_tier2_75pct_scale_returns_1_875() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(2.5, 0.75, 1080)
	assert_float(actual).is_equal_approx(1.875, _TOL)


## Tier 3 at 0.75 scale → 1.5 × 0.75 = 1.125 px.
func test_compute_kernel_actual_tier3_75pct_scale_returns_1_125() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(1.5, 0.75, 1080)
	assert_float(actual).is_equal_approx(1.125, _TOL)


# ── AC-5: minimum 0.5 px clamp ────────────────────────────────────────────

## Tier 3 at 0.4 scale and 540p → raw 0.3 → clamps to 0.5 (AC-5).
func test_compute_kernel_actual_tier3_540p_40pct_clamps_to_0_5() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(1.5, 0.4, 540)
	assert_float(actual).override_failure_message(
		"Tier 3 at scale=0.4, height=540 should clamp from raw 0.3 to minimum 0.5 px."
	).is_equal_approx(0.5, _TOL)


## Zero base radius clamps to 0.5 (defensive — never produce sub-pixel).
func test_compute_kernel_actual_zero_kernel_clamps_to_0_5() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(0.0, 1.0, 1080)
	assert_float(actual).is_equal_approx(0.5, _TOL)


## Zero resolution_scale clamps all kernels to 0.5.
func test_compute_kernel_actual_zero_scale_clamps_to_0_5() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(4.0, 0.0, 1080)
	assert_float(actual).is_equal_approx(0.5, _TOL)


# ── Boundary: divide-by-zero guard ────────────────────────────────────────

## render_height = 0 must NOT divide-by-zero — internal clamp to 1 minimum.
## At height=1, raw = kernel × scale × (1/1080), which is far below 0.5,
## so the output clamp produces 0.5.
func test_compute_kernel_actual_zero_height_does_not_crash() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(4.0, 1.0, 0)
	assert_float(actual).override_failure_message(
		"Zero render_height must not produce NaN or division fault — clamp to ≥0.5."
	).is_equal_approx(0.5, _TOL)


# ── 1440p scale-up case ──────────────────────────────────────────────────

## Tier 1 at native 1440p → 4.0 × 1.0 × (1440/1080) = 5.333... px.
func test_compute_kernel_actual_tier1_1440p_native_returns_5_333() -> void:
	var actual: float = OutlineCompositorEffect._compute_kernel_actual(4.0, 1.0, 1440)
	assert_float(actual).is_equal_approx(5.333333, _TOL)


# ── AC-7: dynamic signal-driven update ───────────────────────────────────

## Emit Events.setting_changed for graphics/resolution_scale → resolution_scale
## member updates within one frame (deferred connect path is exercised first).
func test_setting_changed_graphics_resolution_scale_updates_member() -> void:
	# Arrange — connect the handler explicitly (real lazy-connect happens in
	# _render_callback, but for unit-test isolation we bypass that).
	Events.setting_changed.connect(_effect._on_setting_changed)
	assert_float(_effect.resolution_scale).is_equal_approx(1.0, _TOL)

	# Act
	Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.75)

	# Assert
	assert_float(_effect.resolution_scale).override_failure_message(
		"resolution_scale must update to 0.75 after Events.setting_changed broadcast."
	).is_equal_approx(0.75, _TOL)


## Wrong category (audio) is silently ignored — resolution_scale unchanged.
func test_setting_changed_wrong_category_ignored() -> void:
	Events.setting_changed.connect(_effect._on_setting_changed)
	_effect.resolution_scale = 1.0

	Events.setting_changed.emit(&"audio", &"resolution_scale", 0.5)

	assert_float(_effect.resolution_scale).override_failure_message(
		"audio category must not affect graphics/resolution_scale."
	).is_equal_approx(1.0, _TOL)


## Wrong name (vsync_enabled) is silently ignored.
func test_setting_changed_wrong_name_ignored() -> void:
	Events.setting_changed.connect(_effect._on_setting_changed)
	_effect.resolution_scale = 1.0

	Events.setting_changed.emit(&"graphics", &"vsync_enabled", 0.5)

	assert_float(_effect.resolution_scale).is_equal_approx(1.0, _TOL)


## Non-float payload (string) is rejected by the `value is float` guard.
func test_setting_changed_non_float_payload_rejected() -> void:
	Events.setting_changed.connect(_effect._on_setting_changed)
	_effect.resolution_scale = 1.0

	Events.setting_changed.emit(&"graphics", &"resolution_scale", "not_a_float")

	assert_float(_effect.resolution_scale).override_failure_message(
		"Non-float payload must be rejected by the type guard — resolution_scale unchanged."
	).is_equal_approx(1.0, _TOL)


# ── Idempotency: lazy-connect helper is callable repeatedly ──────────────

## Calling _ensure_settings_signal_connected() twice does not double-connect.
## Verified by counting connections via Events.setting_changed.get_connections().
func test_ensure_settings_signal_connected_is_idempotent() -> void:
	_effect._ensure_settings_signal_connected()
	var first_count: int = Events.setting_changed.get_connections().size()
	_effect._ensure_settings_signal_connected()
	var second_count: int = Events.setting_changed.get_connections().size()
	assert_int(second_count).override_failure_message(
		"Calling _ensure_settings_signal_connected() twice must not double-connect. "
		+ "First: %d, second: %d." % [first_count, second_count]
	).is_equal(first_count)
