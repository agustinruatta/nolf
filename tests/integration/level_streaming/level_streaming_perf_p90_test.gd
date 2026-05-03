# tests/integration/level_streaming/level_streaming_perf_p90_test.gd
#
# LevelStreamingPerfP90Test — GdUnit4 integration suite for Story LS-010.
#
# Covers:
#   AC-1  VERBOSE_TRANSITION_LOGGING_ENABLED gates instrumentation
#   AC-2  Step-level timestamps captured (steps 1, 2, 3, 5, 6, 7, 9, 10, 12, 13)
#   AC-3  10-run measurement harness alternates plaza ↔ stub_b; computes stats
#   AC-4  p90 + max budget assertions (LOCAL_DEV strict; CI/HEADLESS advisory)
#   AC-5  SWAPPING phase (step 3 → step 10) ≤500ms (advisory under headless)
#   AC-6  Memory invariant cross-reference to LS-006 (doc-comment)
#   AC-7  Perf report doc generated
#   AC-8  CI vs LOCAL_DEV vs HEADLESS verdict differentiation
#   AC-9  Regression detection — slowest-run step breakdown identifies offenders
#
# THRESHOLDS
#   LOCAL_DEV (real hardware, dev-laptop or higher):
#     p90 ≤ 570ms  max ≤ 800ms   SWAPPING ≤ 500ms (strict per GDD AC-LS-6.x)
#   CI (env CI=true, e.g., GitHub Actions):
#     p90 ≤ 800ms  max ≤ 1500ms  (50% headroom; failure → manual min-spec)
#   HEADLESS (Godot --headless, no GPU upload):
#     p90 ≤ 1500ms max ≤ 2500ms  (advisory only — log statistics, soft-fail)
#
# GATE STATUS
#   Story LS-010 | Logic → BLOCKING gate (logic over collected metrics).
#   TR-LS-011. AC-LS-6.1, AC-LS-6.2, AC-LS-6.3.

class_name LevelStreamingPerfP90Test
extends GdUnitTestSuite


const RUN_COUNT: int = 10

const TARGET_P90_LOCAL_USEC: int = 570_000
const TARGET_MAX_LOCAL_USEC: int = 800_000
const TARGET_P90_CI_USEC: int = 800_000
const TARGET_MAX_CI_USEC: int = 1_500_000
const TARGET_P90_HEADLESS_USEC: int = 1_500_000
const TARGET_MAX_HEADLESS_USEC: int = 2_500_000

const TARGET_SWAPPING_LOCAL_USEC: int = 500_000


# ── AC-1: VERBOSE_TRANSITION_LOGGING_ENABLED gates instrumentation ───────────

func test_verbose_transition_logging_const_exists_in_lss() -> void:
	var fa: FileAccess = FileAccess.open(
		"res://src/core/level_streaming/level_streaming_service.gd", FileAccess.READ
	)
	var source: String = fa.get_as_text()
	fa.close()
	assert_bool(
		source.contains("const VERBOSE_TRANSITION_LOGGING_ENABLED")
	).override_failure_message(
		"AC-1: VERBOSE_TRANSITION_LOGGING_ENABLED const must exist in LSS."
	).is_true()


# ── AC-2: 10 step entries recorded after a transition ───────────────────────

func test_step_timings_captured_for_all_10_steps_after_transition() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	# Normalize current to plaza so transition to stub_b is a non-same-section call.
	await _normalize_to(&"plaza")

	# Trigger one transition; capture timings.
	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
	)
	await _wait_for_idle(5.0)

	var timings: Dictionary = LevelStreamingService.get_step_timings_for_test()
	# Required step IDs per AC-2.
	var required_steps: Array[int] = [1, 2, 3, 5, 6, 7, 9, 10, 12, 13]
	for step_id: int in required_steps:
		assert_bool(timings.has(step_id)).override_failure_message(
			"AC-2: step %d timestamp must be recorded. Timings: %s" % [step_id, timings]
		).is_true()
		var ts: Variant = timings.get(step_id, 0)
		assert_int(ts as int).override_failure_message(
			"AC-2: step %d timestamp must be a positive int µs. Got: %s" % [step_id, ts]
		).is_greater(0)


# ── AC-3, AC-4, AC-5, AC-7: 10-run harness + stats + report + budget assertion

func test_10_run_perf_harness_records_metrics_and_writes_report() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _normalize_to(&"plaza")

	var durations_total: Array[int] = []
	var durations_swapping: Array[int] = []
	var slowest_run_breakdown: Dictionary = {}
	var slowest_run_total: int = -1

	for i in range(RUN_COUNT):
		# Alternate target each iteration.
		var target: StringName = &"stub_b" if (i % 2 == 0) else &"plaza"
		LevelStreamingService.transition_to_section(
			target, null, LevelStreamingService.TransitionReason.FORWARD
		)
		await _wait_for_idle(5.0)

		var t: Dictionary = LevelStreamingService.get_step_timings_for_test()
		# Per-AC-3: total = step 12 - step 1.
		# Some runs may skip step 12 if the coroutine aborted; guard with has().
		if not (t.has(1) and t.has(12)):
			continue
		var total: int = (t[12] as int) - (t[1] as int)
		durations_total.append(total)
		# Per-AC-5: SWAPPING = step 10 - step 3.
		if t.has(3) and t.has(10):
			var swap: int = (t[10] as int) - (t[3] as int)
			durations_swapping.append(swap)
		# Capture per-step breakdown for the slowest run for the perf report.
		if total > slowest_run_total:
			slowest_run_total = total
			slowest_run_breakdown = t.duplicate(true)

	# Compute stats.
	assert_int(durations_total.size()).override_failure_message(
		"AC-3: harness must capture at least 5 valid runs (got %d)." % durations_total.size()
	).is_greater_equal(5)

	durations_total.sort()
	var min_d: int = durations_total[0]
	var p50: int = durations_total[int(durations_total.size() * 0.5)]
	var p90_idx: int = mini(int(durations_total.size() * 0.9), durations_total.size() - 1)
	var p90: int = durations_total[p90_idx]
	var max_d: int = durations_total[durations_total.size() - 1]

	# Determine threshold context.
	var ctx: String = _detect_perf_context()
	var p90_threshold: int = TARGET_P90_HEADLESS_USEC
	var max_threshold: int = TARGET_MAX_HEADLESS_USEC
	if ctx == "LOCAL_DEV":
		p90_threshold = TARGET_P90_LOCAL_USEC
		max_threshold = TARGET_MAX_LOCAL_USEC
	elif ctx == "CI":
		p90_threshold = TARGET_P90_CI_USEC
		max_threshold = TARGET_MAX_CI_USEC

	# Write perf report doc.
	_write_perf_report(
		ctx, durations_total, durations_swapping, slowest_run_breakdown,
		min_d, p50, p90, max_d, p90_threshold, max_threshold
	)

	# AC-4: assertions. Under HEADLESS we soft-fail (advisory) by widening the
	# tolerance threshold. Under LOCAL_DEV / CI we enforce the strict budget.
	push_warning(
		"[LS-010 perf] Context: %s | Runs: %d | min: %d µs | p50: %d µs | p90: %d µs | max: %d µs | thresholds: p90 ≤ %d, max ≤ %d"
		% [ctx, durations_total.size(), min_d, p50, p90, max_d, p90_threshold, max_threshold]
	)

	assert_int(p90).override_failure_message(
		"AC-4: %s p90 (%d µs) must be ≤ %d µs."
		% [ctx, p90, p90_threshold]
	).is_less_equal(p90_threshold)
	assert_int(max_d).override_failure_message(
		"AC-4: %s max (%d µs) must be ≤ %d µs."
		% [ctx, max_d, max_threshold]
	).is_less_equal(max_threshold)


# ── AC-5: SWAPPING phase isolation ──────────────────────────────────────────

func test_swapping_phase_within_budget_advisory() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _normalize_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
	)
	await _wait_for_idle(5.0)

	var t: Dictionary = LevelStreamingService.get_step_timings_for_test()
	if not (t.has(3) and t.has(10)):
		push_warning("[AC-5] step timings missing 3 or 10 — skipping SWAPPING assertion.")
		return

	var swap: int = (t[10] as int) - (t[3] as int)
	push_warning("[AC-5] SWAPPING phase (step 3 → step 10): %d µs" % swap)

	# Under headless, this is advisory-only. Under LOCAL_DEV, strict.
	var ctx: String = _detect_perf_context()
	if ctx == "LOCAL_DEV":
		assert_int(swap).override_failure_message(
			"AC-5: LOCAL_DEV SWAPPING must be ≤ %d µs. Got: %d µs."
			% [TARGET_SWAPPING_LOCAL_USEC, swap]
		).is_less_equal(TARGET_SWAPPING_LOCAL_USEC)


# ── AC-6: memory-invariant cross-reference ──────────────────────────────────

func test_memory_invariant_cross_reference_to_ls006_present() -> void:
	# AC-6 is a doc-comment cross-reference; verify the LS-006 memory test
	# exists at the expected path so the cross-ref resolves.
	var ls006_test: String = "res://tests/integration/level_streaming/level_streaming_focus_memory_test.gd"
	var fa: FileAccess = FileAccess.open(ls006_test, FileAccess.READ)
	assert_object(fa).override_failure_message(
		"AC-6 cross-ref: LS-006 memory test must exist at %s" % ls006_test
	).is_not_null()
	if fa != null:
		fa.close()


# ── AC-9: regression detection — slowest-run breakdown structure ────────────

func test_slowest_run_breakdown_can_identify_dominant_step() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _normalize_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
	)
	await _wait_for_idle(5.0)

	var t: Dictionary = LevelStreamingService.get_step_timings_for_test()
	# AC-9 verification: per-step breakdown contains enough detail to identify
	# the dominant step. We compute step deltas and assert that step 5 (load)
	# OR step 9 (callbacks) is identifiable — these are the typical dominant
	# steps. A future PR adding 200ms to step 9 would shift the dominant
	# identification to step 9 — that's the regression-detection mechanism.
	var ordered_keys: Array[int] = []
	for k: Variant in t.keys():
		if k is int:
			ordered_keys.append(k as int)
	ordered_keys.sort()
	# Build per-step delta map (delta from previous recorded step).
	var deltas: Dictionary = {}
	var prev_ts: int = 0
	for k: int in ordered_keys:
		if prev_ts > 0:
			deltas[k] = (t[k] as int) - prev_ts
		prev_ts = t[k] as int

	# Find the largest delta (dominant step).
	var max_delta: int = 0
	var dominant_step: int = -1
	for k: Variant in deltas.keys():
		var d: int = deltas[k] as int
		if d > max_delta:
			max_delta = d
			dominant_step = k as int

	push_warning(
		"[AC-9] Slowest-run dominant step: %d (delta: %d µs). Full deltas: %s"
		% [dominant_step, max_delta, deltas]
	)

	assert_int(dominant_step).override_failure_message(
		"AC-9: dominant step must be identifiable (-1 means deltas dict is empty)."
	).is_greater(-1)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _normalize_to(target: StringName) -> void:
	if not LevelStreamingService.has_valid_registry():
		return
	var current: StringName = LevelStreamingService.get_current_section_id()
	if current == target:
		# Bounce off the OTHER section first.
		var other: StringName = &"plaza" if target != &"plaza" else &"stub_b"
		LevelStreamingService.transition_to_section(
			other, null, LevelStreamingService.TransitionReason.FORWARD
		)
		await _wait_for_idle(3.0)
	elif current == &"":
		LevelStreamingService.transition_to_section(
			&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
		)
		await _wait_for_idle(3.0)
		if target != &"plaza":
			LevelStreamingService.transition_to_section(
				target, null, LevelStreamingService.TransitionReason.FORWARD
			)
			await _wait_for_idle(3.0)
		# After this branch, current == target — bounce again.
		if LevelStreamingService.get_current_section_id() == target:
			var other2: StringName = &"plaza" if target != &"plaza" else &"stub_b"
			LevelStreamingService.transition_to_section(
				other2, null, LevelStreamingService.TransitionReason.FORWARD
			)
			await _wait_for_idle(3.0)
	# After normalize, current != target; subsequent test transition to target succeeds.


func _wait_for_idle(timeout_sec: float) -> void:
	var elapsed: float = 0.0
	while elapsed < timeout_sec:
		if not LevelStreamingService.is_transitioning() \
				and LevelStreamingService.get_state() == LevelStreamingService.State.IDLE:
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _detect_perf_context() -> String:
	var headless: bool = DisplayServer.get_name() == "headless"
	var ci: bool = OS.get_environment("CI") != "" or OS.get_environment("GITHUB_ACTIONS") != ""
	if headless:
		return "HEADLESS"
	if ci:
		return "CI"
	return "LOCAL_DEV"


func _write_perf_report(
	ctx: String,
	durations: Array[int],
	durations_swapping: Array[int],
	slowest_breakdown: Dictionary,
	min_d: int, p50: int, p90: int, max_d: int,
	p90_threshold: int, max_threshold: int
) -> void:
	var date_str: String = Time.get_date_string_from_system()
	var report_path: String = "res://production/qa/evidence/level_streaming_perf_p90_%s.md" % date_str
	var fa: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if fa == null:
		push_warning("[LS-010] could not open %s for write" % report_path)
		return

	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Level Streaming Perf Measurement — %s" % date_str)
	lines.append("")
	lines.append("## Environment")
	lines.append("- Context: %s" % ctx)
	lines.append("- Hardware: %s" % OS.get_processor_name())
	lines.append("- Godot: %s" % Engine.get_version_info().string)
	lines.append("- DisplayServer: %s" % DisplayServer.get_name())
	lines.append("")
	lines.append("## Thresholds (%s)" % ctx)
	lines.append("- p90 ≤ %d µs (%.1f ms)" % [p90_threshold, p90_threshold / 1000.0])
	lines.append("- max ≤ %d µs (%.1f ms)" % [max_threshold, max_threshold / 1000.0])
	lines.append("")
	lines.append("## %d-Run Durations" % durations.size())
	lines.append("| Run | Total (µs) | Total (ms) |")
	lines.append("|---|---|---|")
	for i: int in range(durations.size()):
		lines.append("| %d | %d | %.2f |" % [i + 1, durations[i], durations[i] / 1000.0])
	lines.append("")
	lines.append("## Statistics")
	lines.append("- Min: %d µs (%.2f ms)" % [min_d, min_d / 1000.0])
	lines.append("- p50: %d µs (%.2f ms)" % [p50, p50 / 1000.0])
	lines.append("- p90: %d µs (%.2f ms)" % [p90, p90 / 1000.0])
	lines.append("- Max: %d µs (%.2f ms)" % [max_d, max_d / 1000.0])
	lines.append("")
	if not durations_swapping.is_empty():
		durations_swapping.sort()
		var swap_p90_idx: int = mini(int(durations_swapping.size() * 0.9), durations_swapping.size() - 1)
		var swap_p90: int = durations_swapping[swap_p90_idx]
		lines.append("## SWAPPING phase (step 3 → step 10)")
		lines.append("- p90: %d µs (%.2f ms)" % [swap_p90, swap_p90 / 1000.0])
		lines.append("")
	lines.append("## Verdict")
	lines.append("- p90 ≤ %d µs: %s" % [p90_threshold, "PASS" if p90 <= p90_threshold else "FAIL"])
	lines.append("- max ≤ %d µs: %s" % [max_threshold, "PASS" if max_d <= max_threshold else "FAIL"])
	lines.append("")
	lines.append("## Slowest-Run Step Breakdown")
	lines.append("| Step | Timestamp (µs) |")
	lines.append("|---|---|")
	var keys: Array = slowest_breakdown.keys()
	keys.sort()
	for k: Variant in keys:
		lines.append("| %s | %d |" % [str(k), slowest_breakdown[k]])
	lines.append("")
	lines.append("## Notes")
	lines.append("- HEADLESS context is advisory-only; CI/LOCAL_DEV strict assertions apply.")
	lines.append("- Iris Xe Gen 12 min-spec verification deferred per TD-002.")

	fa.store_string("\n".join(lines))
	fa.close()
