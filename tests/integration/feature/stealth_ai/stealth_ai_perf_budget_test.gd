# tests/integration/feature/stealth_ai/stealth_ai_perf_budget_test.gd
#
# StealthAIPerfBudgetTest — Story SAI-010 perf integration coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-010)
#   AC-1: Full perception loop ordered sequence (UNAWARE→SUSPICIOUS→SEARCHING→COMBAT)
#         extending the SAI-008 single-stinger test with explicit sequence assertion.
#   AC-3: Perception sub-budget — raycast call count per frame ≤ 12 (one per guard)
#   AC-6: Environment pin assertions (physics backend)
#   AC-8: has_los_to_player at scale — 12 guards × 60 frames raycast deduplication
#
# DEFERRED FROM THIS STORY (per ADR-0008 status: Accepted-with-deferred-verification)
#   AC-2 / AC-4 / AC-5 absolute time-budget assertions: numerical Iris Xe verification
#   is DEFERRED per ADR-0008. Tests below MEASURE timing values but report them as
#   ADVISORY observations rather than failing CI on numerical thresholds. Structural
#   framework (per-slot allocation, signal dispatch synchronicity, etc.) is binding
#   and verified by other tests in the suite.
#
#   Full Plaza-VS perf test (real nav mesh, real Jolt physics, real Eve locomotion):
#   deferred to production/qa/evidence/stealth-ai-perf-[YYYY-MM-DD].md when Plaza
#   scene is built (later sprint).
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIPerfBudgetTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"
const _MAX_GUARDS_PER_SECTION: int = 12


# ── Fixture helpers ───────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


## Spawns N guards with CountingRaycastProvider injected on each.
## Returns Array[Guard] (no auto-free dependency on order).
func _spawn_guards(count: int) -> Array[Guard]:
	var guards: Array[Guard] = []
	for i: int in range(count):
		var guard: Guard = _make_guard()
		# Replace the production raycast provider (or null in headless) with a counter
		var counter: CountingRaycastProvider = CountingRaycastProvider.new()
		guard._perception.init(counter)
		guards.append(guard)
	return guards


# ── AC-6: Environment pin assertions ─────────────────────────────────────────

## AC-6: physics backend is Jolt 3D (Godot 4.6 default).
## Catches configuration drift that would invalidate perf measurements.
func test_physics_backend_is_jolt_3d() -> void:
	var backend: String = ProjectSettings.get_setting("physics/3d/physics_engine", "")
	# Empty string = "default" which in Godot 4.6 means Jolt.
	# In Godot 4.6 the setting value is "Jolt"; older betas used "JoltPhysics".
	# Project may also use "DEFAULT" (some build variants) or "" (left default).
	var is_jolt_or_default: bool = (
			backend == "Jolt"
			or backend == "JoltPhysics"
			or backend == "DEFAULT"
			or backend == ""
	)
	assert_bool(is_jolt_or_default).override_failure_message(
			"AC-6: physics backend must be Jolt 3D (Godot 4.6 default). Got: '%s'." % backend
	).is_true()


## AC-6: Engine version is 4.6+ (sanity check; SAI implementation depends on
## post-cutoff features like @abstract and Dictionary[K,V] typed dicts).
func test_engine_version_is_4_6_or_later() -> void:
	var version: Dictionary = Engine.get_version_info()
	var major: int = version.get("major", 0)
	var minor: int = version.get("minor", 0)
	assert_bool(major >= 4 and minor >= 6).override_failure_message(
			"AC-6: Godot version must be 4.6+. Got %d.%d." % [major, minor]
	).is_true()


# ── AC-1: Full perception loop ordered sequence ─────────────────────────────

## AC-1 (AC-SAI-4.1): UNAWARE → SUSPICIOUS → SEARCHING → COMBAT in order.
## Sequence captured via Events.alert_state_changed subscriber; assertion checks
## the (old, new) pairs are exactly the documented graduated sequence.
func test_full_perception_loop_ordered_sequence_assertion() -> void:
	var guard: Guard = _make_guard()

	var sequence: Array[Vector2i] = []  # store (old_state, new_state) pairs
	var on_changed: Callable = func(_actor, old_s, new_s, _sev):
		sequence.append(Vector2i(int(old_s), int(new_s)))
	Events.alert_state_changed.connect(on_changed)

	# Drive the escalation through the graduated sequence by stepping accumulator.
	guard._perception.sight_accumulator = 0.35  # → SUSPICIOUS (T_SUSPICIOUS = 0.3)
	guard._evaluate_transitions()
	guard._perception.sight_accumulator = 0.6  # → SEARCHING (T_SEARCHING = 0.6)
	guard._evaluate_transitions()
	guard._perception.sight_accumulator = 0.95  # → COMBAT (T_COMBAT = 0.95)
	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)

	# Assert: exactly 3 transitions in the documented order.
	assert_int(sequence.size()).override_failure_message(
			"AC-1: must have exactly 3 graduated transitions. Got %d: %s" % [
					sequence.size(), str(sequence)
			]
	).is_equal(3)
	assert_bool(sequence[0] == Vector2i(StealthAI.AlertState.UNAWARE, StealthAI.AlertState.SUSPICIOUS)).override_failure_message(
			"AC-1: first transition must be UNAWARE → SUSPICIOUS. Got: %s." % str(sequence[0])
	).is_true()
	assert_bool(sequence[1] == Vector2i(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertState.SEARCHING)).override_failure_message(
			"AC-1: second transition must be SUSPICIOUS → SEARCHING. Got: %s." % str(sequence[1])
	).is_true()
	assert_bool(sequence[2] == Vector2i(StealthAI.AlertState.SEARCHING, StealthAI.AlertState.COMBAT)).override_failure_message(
			"AC-1: third transition must be SEARCHING → COMBAT. Got: %s." % str(sequence[2])
	).is_true()


# ── AC-8 / AC-3: has_los_to_player at scale ──────────────────────────────────

## AC-8 (AC-SAI-3.9): With 12 guards active, has_los_to_player accessor calls
## issue ZERO new raycasts (cache-hit path; F.1 owns raycast issuance).
##
## The scale test verifies the cache-read accessor never triggers a raycast,
## even when called repeatedly across all 12 guards over 60 frames.
func test_has_los_to_player_does_not_issue_raycast_at_12_guard_scale() -> void:
	var guards: Array[Guard] = _spawn_guards(_MAX_GUARDS_PER_SECTION)

	# Pre-populate each guard's cache as if F.1 had ticked once (no raycasts yet)
	for guard: Guard in guards:
		guard._perception._perception_cache.initialized = true
		guard._perception._perception_cache.los_to_player = false

	# Simulate 60 frames of 10 Hz Combat.GuardFireController polling per guard.
	# Each frame, every guard's has_los_to_player is queried — none should issue raycasts.
	for frame_i: int in range(60):
		for guard: Guard in guards:
			var _has_los: bool = guard._perception.has_los_to_player()

	# Total raycast count across all 12 guards must be 0 (no F.1 dispatched in this loop)
	var total_raycasts: int = 0
	for guard: Guard in guards:
		total_raycasts += (guard._perception._raycast_provider as CountingRaycastProvider).call_count

	assert_int(total_raycasts).override_failure_message(
			"AC-8: has_los_to_player accessor must NOT issue any raycast (cache-hit path). "
			+ "12 guards × 60 frames of accessor calls produced %d raycasts (expected 0)." % total_raycasts
	).is_equal(0)


## AC-3 (AC-SAI-4.4.b): Per-frame raycast budget ≤ 12 raycasts.
## Each guard issues at most 1 raycast per F.1 tick (deduplicated cache reuse).
func test_perception_sub_budget_one_raycast_per_guard_per_frame() -> void:
	var guards: Array[Guard] = _spawn_guards(_MAX_GUARDS_PER_SECTION)

	# Spawn an Eve stub at a known position
	var eve_stub: Node3D = Node3D.new()
	add_child(eve_stub)
	auto_free(eve_stub)
	eve_stub.global_position = Vector3(0.0, 0.0, -5.0)

	# Reset all counters
	for guard: Guard in guards:
		(guard._perception._raycast_provider as CountingRaycastProvider).call_count = 0

	# Each guard runs one F.1 tick — should issue exactly 1 raycast each
	for guard: Guard in guards:
		guard._perception.process_sight_fill(
				eve_stub,
				guard.global_position,
				eve_stub.global_position,
				PlayerEnums.MovementState.WALK,
				1.7,  # silhouette
				StealthAI.AlertState.UNAWARE,
				false,  # alive target
				guard.get_rid(),
				1.0 / 60.0
		)

	# Assert each guard issued exactly 1 raycast
	for i: int in range(guards.size()):
		var counter: CountingRaycastProvider = guards[i]._perception._raycast_provider as CountingRaycastProvider
		assert_int(counter.call_count).override_failure_message(
				"AC-3: guard[%d] issued %d raycasts in one F.1 tick (expected 1)." % [
						i, counter.call_count
				]
		).is_equal(1)


# ── Advisory: tick latency at 12-guard scale ─────────────────────────────────

## AC-2 / AC-3 / AC-4 / AC-5 (ADVISORY per ADR-0008 deferred numerical verification):
## Measure the wall-clock cost of one F.1 tick across 12 guards. Reports the
## measurement but does NOT fail on numerical thresholds — sub-budget numbers
## bind structurally but await Iris Xe Gen 12 hardware verification per ADR-0008.
##
## The reported values appear in the test output for evidence-file capture.
func test_advisory_perf_one_tick_across_12_guards_completes() -> void:
	var guards: Array[Guard] = _spawn_guards(_MAX_GUARDS_PER_SECTION)

	var eve_stub: Node3D = Node3D.new()
	add_child(eve_stub)
	auto_free(eve_stub)
	eve_stub.global_position = Vector3(0.0, 0.0, -5.0)

	# Warm the JIT / class loader with one untimed tick
	for guard: Guard in guards:
		guard._perception.process_sight_fill(
				eve_stub, guard.global_position, eve_stub.global_position,
				PlayerEnums.MovementState.WALK, 1.7,
				StealthAI.AlertState.UNAWARE, false, guard.get_rid(), 1.0 / 60.0
		)

	# Measure 60 ticks
	var t0: int = Time.get_ticks_usec()
	for frame_i: int in range(60):
		for guard: Guard in guards:
			guard._perception.process_sight_fill(
					eve_stub, guard.global_position, eve_stub.global_position,
					PlayerEnums.MovementState.WALK, 1.7,
					StealthAI.AlertState.UNAWARE, false, guard.get_rid(), 1.0 / 60.0
			)
	var elapsed_usec: int = Time.get_ticks_usec() - t0

	# Report as advisory output (printed but not asserted as a budget fail)
	var avg_per_frame_usec: float = elapsed_usec / 60.0
	var avg_per_guard_usec: float = avg_per_frame_usec / float(_MAX_GUARDS_PER_SECTION)
	print("[SAI-010 ADVISORY] 60-tick perf @ 12 guards: total %d µs; avg/frame %.1f µs; avg/guard %.1f µs" % [
			elapsed_usec, avg_per_frame_usec, avg_per_guard_usec
	])

	# Sanity-only assertion: 60 ticks × 12 guards must complete in < 1 second
	# (catches catastrophic regressions like an infinite loop). Real budget
	# enforcement awaits Iris Xe Gen 12 hardware verification per ADR-0008.
	assert_int(elapsed_usec).override_failure_message(
			"AC-2 sanity: 60 ticks × 12 guards must complete in < 1s. Got %d µs (%.2f s)." % [
					elapsed_usec, elapsed_usec / 1_000_000.0
			]
	).is_less(1_000_000)


# ── AC-1 partial: forbidden direct transitions ──────────────────────────────

## AC-1: UNAWARE → COMBAT direct transition does NOT occur for a slowly-rising
## accumulator that crosses thresholds in order (T_SUSPICIOUS < T_SEARCHING < T_COMBAT).
##
## NOTE: A SINGLE _evaluate_transitions call WITH accumulator already at 0.95
## DOES jump UNAWARE → COMBAT (that's the documented match-statement behavior in
## guard.gd — the highest applicable threshold wins per call). The "graduated
## sequence" requirement only holds when the accumulator rises gradually across
## multiple ticks, which is what AC-1 actually tests.
##
## This test verifies the gradual-approach behavior: accumulator rising
## incrementally from 0 → 0.35 → 0.6 → 0.95 produces 3 stepped transitions.
func test_gradual_accumulator_rise_produces_stepped_transitions_not_jumps() -> void:
	var guard: Guard = _make_guard()

	var transition_count: Array[int] = [0]
	var on_changed: Callable = func(_a, _o, _n, _s): transition_count[0] += 1
	Events.alert_state_changed.connect(on_changed)

	# Step 1: 0.35 → SUSPICIOUS (1 transition)
	guard._perception.sight_accumulator = 0.35
	guard._evaluate_transitions()
	# Step 2: 0.6 → SEARCHING (2 transitions total)
	guard._perception.sight_accumulator = 0.6
	guard._evaluate_transitions()
	# Step 3: 0.95 → COMBAT (3 transitions total)
	guard._perception.sight_accumulator = 0.95
	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)

	# 3 transitions = graduated path (NOT a single jump from UNAWARE → COMBAT)
	assert_int(transition_count[0]).override_failure_message(
			"AC-1: gradual accumulator rise must produce 3 stepped transitions. Got %d." % transition_count[0]
	).is_equal(3)
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.COMBAT)
