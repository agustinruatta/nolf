# tests/unit/feature/stealth_ai/stealth_ai_sight_fill_rate_test.gd
#
# StealthAISightFillRateTest — Story SAI-004 AC-2 (25-row parametrized matrix)
# + AC-3 (cache write) + AC-5 (accumulator clamps) + AC-1 zero-distance edge.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-004)
#   AC-1: 6-factor formula (range × silhouette × movement × state × body) — exercised by AC-2
#   AC-2: 25-row parametrized matrix (15 range×movement + 3 silhouette + 4 state + 1 body + 1 DEAD + 1 zero-distance)
#   AC-3: cache write after F.1 tick (initialized, frame_stamp, los_to_player, last_sight_position, last_sight_stimulus_cause)
#   AC-5: sight_accumulator clamped to [0.0, 1.0]
#   AC-1-edge: zero-distance short-circuit (range_factor = 1.0 without normalized() call)
#
# DEFERRED FROM THIS STORY (per Out of Scope):
#   AC-4 raycast deduplication: F.2 sound fill is post-VS; with F.1 alone, each
#   process_sight_fill() call always issues exactly 1 raycast. Documented degenerate
#   coverage rather than full deduplication test.
#   AC-6 downward tilt: handled via the explicit guard_eye_position parameter at
#   the call site (not internally derived). Test passes pre-tilted positions.
#
# DEPENDENCIES
#   Stories SAI-002 (StealthAI enums) + SAI-003 (Perception node + IRaycastProvider DI)
#   PlayerCharacter (PlayerEnums.MovementState) — production code; tests use enum directly.
#
# TEST FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAISightFillRateTest
extends GdUnitTestSuite

const _BASE_RATE: float = 1.0
const _VISION_MAX_RANGE: float = 18.0
const _SILHOUETTE_REF: float = 1.7
const _SILHOUETTE_STANDING: float = 1.7
const _SILHOUETTE_CROUCHED: float = 1.1
const _TOLERANCE: float = 0.01


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh Perception with a CountingRaycastProvider injected and a
## Node3D target stub. Returns [perception, counter, target_stub].
func _make_perception_setup(scripted_clear_los: bool = true) -> Array[Object]:
	var perception: Perception = Perception.new()
	add_child(perception)
	auto_free(perception)

	var counter: CountingRaycastProvider = CountingRaycastProvider.new()
	# scripted_result = {} → result.is_empty() → has_los = true (LOS clear).
	# scripted_result = {"collider": <some other node>} → LOS blocked.
	if not scripted_clear_los:
		var blocker: Node3D = Node3D.new()
		add_child(blocker)
		auto_free(blocker)
		counter.scripted_result = {"collider": blocker}
	perception.init(counter)

	var target_stub: Node3D = Node3D.new()
	add_child(target_stub)
	auto_free(target_stub)

	return [perception, counter, target_stub]


## Returns the analytical expected sight_fill_rate for the given inputs.
## Mirrors the GDD §F.1 formula exactly (test oracle, independent derivation).
func _oracle_rate(
		distance_m: float,
		silhouette_height: float,
		movement_factor: float,
		state_multiplier: float,
		body_factor: float
) -> float:
	var range_factor: float = 1.0 - clampf(distance_m / _VISION_MAX_RANGE, 0.0, 1.0)
	var silhouette_factor: float = clampf(silhouette_height / _SILHOUETTE_REF, 0.5, 1.0)
	return _BASE_RATE * range_factor * silhouette_factor * movement_factor * state_multiplier * body_factor


## Movement factor lookup matching Perception's _movement_table.
func _movement_factor(state: PlayerEnums.MovementState) -> float:
	match state:
		PlayerEnums.MovementState.DEAD: return 0.0
		PlayerEnums.MovementState.IDLE: return 0.3
		PlayerEnums.MovementState.WALK: return 1.0
		PlayerEnums.MovementState.SPRINT: return 1.5
		PlayerEnums.MovementState.CROUCH: return 0.5
		PlayerEnums.MovementState.JUMP: return 0.8
		PlayerEnums.MovementState.FALL: return 0.8
	return 0.0


## State multiplier lookup matching Perception's _state_table.
func _state_multiplier(state: StealthAI.AlertState) -> float:
	match state:
		StealthAI.AlertState.UNAWARE: return 1.0
		StealthAI.AlertState.SUSPICIOUS: return 1.5
		StealthAI.AlertState.SEARCHING: return 1.5
		StealthAI.AlertState.COMBAT: return 2.0
	return 0.0


# ── AC-2 (a): 15-row range × movement matrix ──────────────────────────────────

## AC-2-a: range × movement grid: 5 ranges × 3 movement states = 15 rows.
## Eve standing (silhouette 1.7), state UNAWARE, alive body.
func test_sight_fill_rate_range_movement_15_cell_matrix() -> void:
	# Arrange — fixed: silhouette=1.7, state=UNAWARE, body=alive
	var ranges: Array[float] = [0.5, 2.0, 6.0, 12.0, 17.9]
	var movements: Array[PlayerEnums.MovementState] = [
			PlayerEnums.MovementState.WALK,
			PlayerEnums.MovementState.CROUCH,
			PlayerEnums.MovementState.SPRINT,
	]
	var failures: Array[String] = []

	for distance: float in ranges:
		for movement: PlayerEnums.MovementState in movements:
			var setup: Array[Object] = _make_perception_setup(true)
			var perception: Perception = setup[0] as Perception
			var target: Node3D = setup[2] as Node3D

			var guard_eye: Vector3 = Vector3.ZERO
			var target_head: Vector3 = Vector3(0.0, 0.0, -distance)
			target.global_position = target_head

			# Act
			var actual: float = perception.process_sight_fill(
					target, guard_eye, target_head, movement,
					_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, false,
					RID(), 0.0  # delta=0 for rate-only assertion (no accumulator side effect)
			)

			var expected: float = _oracle_rate(
					distance, _SILHOUETTE_STANDING,
					_movement_factor(movement),
					_state_multiplier(StealthAI.AlertState.UNAWARE),
					1.0
			)
			if absf(actual - expected) > _TOLERANCE:
				failures.append("range=%.1f, movement=%d: expected %.4f, got %.4f" % [
						distance, movement, expected, actual
				])

	assert_int(failures.size()).override_failure_message(
			"AC-2-a: %d range×movement cells diverged: %s" % [failures.size(), ", ".join(failures)]
	).is_equal(0)


# ── AC-2 (b): 3-row silhouette ────────────────────────────────────────────────

## AC-2-b: silhouette factors at 3 heights — standing 1.7→1.0; crouched 1.1→0.647;
## hypothetical-prone 0.6 → clamps to 0.5 minimum.
func test_sight_fill_rate_silhouette_3_rows() -> void:
	var rows: Array[Dictionary] = [
			{"height": 1.7, "expected_factor": 1.0},
			{"height": 1.1, "expected_factor": 1.1 / 1.7},
			{"height": 0.6, "expected_factor": 0.5},  # clamped
	]
	var failures: Array[String] = []

	for row: Dictionary in rows:
		var setup: Array[Object] = _make_perception_setup(true)
		var perception: Perception = setup[0] as Perception
		var target: Node3D = setup[2] as Node3D

		var distance: float = 6.0
		var guard_eye: Vector3 = Vector3.ZERO
		var target_head: Vector3 = Vector3(0.0, 0.0, -distance)
		target.global_position = target_head

		var actual: float = perception.process_sight_fill(
				target, guard_eye, target_head, PlayerEnums.MovementState.WALK,
				row["height"] as float, StealthAI.AlertState.UNAWARE, false,
				RID(), 0.0
		)

		var expected: float = _oracle_rate(
				distance, row["height"] as float,
				_movement_factor(PlayerEnums.MovementState.WALK),
				_state_multiplier(StealthAI.AlertState.UNAWARE),
				1.0
		)
		if absf(actual - expected) > _TOLERANCE:
			failures.append("silhouette=%.2f: expected %.4f, got %.4f" % [
					row["height"], expected, actual
			])

	assert_int(failures.size()).override_failure_message(
			"AC-2-b: %d silhouette rows diverged: %s" % [failures.size(), ", ".join(failures)]
	).is_equal(0)


# ── AC-2 (c): 4-row state_multiplier ──────────────────────────────────────────

## AC-2-c: state multipliers for the 4 active alert states.
func test_sight_fill_rate_state_multiplier_4_rows() -> void:
	var states: Array[StealthAI.AlertState] = [
			StealthAI.AlertState.UNAWARE,
			StealthAI.AlertState.SUSPICIOUS,
			StealthAI.AlertState.SEARCHING,
			StealthAI.AlertState.COMBAT,
	]
	var failures: Array[String] = []

	for state: StealthAI.AlertState in states:
		var setup: Array[Object] = _make_perception_setup(true)
		var perception: Perception = setup[0] as Perception
		var target: Node3D = setup[2] as Node3D

		var distance: float = 6.0
		var guard_eye: Vector3 = Vector3.ZERO
		var target_head: Vector3 = Vector3(0.0, 0.0, -distance)
		target.global_position = target_head

		var actual: float = perception.process_sight_fill(
				target, guard_eye, target_head, PlayerEnums.MovementState.WALK,
				_SILHOUETTE_STANDING, state, false, RID(), 0.0
		)

		var expected: float = _oracle_rate(
				distance, _SILHOUETTE_STANDING,
				_movement_factor(PlayerEnums.MovementState.WALK),
				_state_multiplier(state),
				1.0
		)
		if absf(actual - expected) > _TOLERANCE:
			failures.append("state=%d: expected %.4f, got %.4f" % [state, expected, actual])

	assert_int(failures.size()).override_failure_message(
			"AC-2-c: %d state rows diverged: %s" % [failures.size(), ", ".join(failures)]
	).is_equal(0)


# ── AC-2 (d): body_factor row ─────────────────────────────────────────────────

## AC-2-d: dead-body target at range 6m WALK has fill rate exactly 2× the
## equivalent alive-player row (body_factor 2.0 vs 1.0).
func test_sight_fill_rate_dead_body_is_double_alive_at_same_range() -> void:
	# Arrange — alive case
	var setup_alive: Array[Object] = _make_perception_setup(true)
	var perception_alive: Perception = setup_alive[0] as Perception
	var target_alive: Node3D = setup_alive[2] as Node3D
	var guard_eye: Vector3 = Vector3.ZERO
	var target_head: Vector3 = Vector3(0.0, 0.0, -6.0)
	target_alive.global_position = target_head

	# Act — alive
	var rate_alive: float = perception_alive.process_sight_fill(
			target_alive, guard_eye, target_head, PlayerEnums.MovementState.WALK,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, false, RID(), 0.0
	)

	# Arrange — dead body case
	var setup_dead: Array[Object] = _make_perception_setup(true)
	var perception_dead: Perception = setup_dead[0] as Perception
	var target_dead: Node3D = setup_dead[2] as Node3D
	target_dead.global_position = target_head

	# Act — dead
	var rate_dead: float = perception_dead.process_sight_fill(
			target_dead, guard_eye, target_head, PlayerEnums.MovementState.WALK,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, true, RID(), 0.0
	)

	# Assert: dead is exactly 2× alive (body_factor 2.0 vs 1.0)
	assert_float(rate_dead).override_failure_message(
			"AC-2-d: dead body fill rate (%.4f) must be exactly 2× alive (%.4f)." % [rate_dead, rate_alive]
	).is_equal_approx(rate_alive * 2.0, _TOLERANCE)


# ── AC-2 (e): DEAD movement_factor ────────────────────────────────────────────

## AC-2-e: target with MovementState.DEAD → fill rate is 0.0 regardless of
## any other factor (range, silhouette, state, body).
func test_sight_fill_rate_dead_movement_state_yields_zero() -> void:
	var setup: Array[Object] = _make_perception_setup(true)
	var perception: Perception = setup[0] as Perception
	var target: Node3D = setup[2] as Node3D

	var guard_eye: Vector3 = Vector3.ZERO
	var target_head: Vector3 = Vector3(0.0, 0.0, -2.0)  # close range
	target.global_position = target_head

	# All other factors maxed (close range, standing, COMBAT, dead body)
	# but movement DEAD must zero the result.
	var actual: float = perception.process_sight_fill(
			target, guard_eye, target_head, PlayerEnums.MovementState.DEAD,
			_SILHOUETTE_STANDING, StealthAI.AlertState.COMBAT, true, RID(), 0.0
	)

	assert_float(actual).override_failure_message(
			"AC-2-e: MovementState.DEAD must yield sight_fill_rate=0.0 regardless of other factors. Got %.4f." % actual
	).is_equal_approx(0.0, _TOLERANCE)


# ── AC-2 (f): zero-distance short-circuit ─────────────────────────────────────

## AC-2-f: target at guard_eye + Vector3(0, 0, 0.01) — accepted; range_factor=1.0;
## fill rate > 0 (no normalized() call on near-zero vector).
func test_sight_fill_rate_zero_distance_short_circuit() -> void:
	var setup: Array[Object] = _make_perception_setup(true)
	var perception: Perception = setup[0] as Perception
	var target: Node3D = setup[2] as Node3D

	var guard_eye: Vector3 = Vector3.ZERO
	var target_head: Vector3 = Vector3(0.0, 0.0, 0.01)  # 1 cm away (within epsilon 0.1)
	target.global_position = target_head

	var actual: float = perception.process_sight_fill(
			target, guard_eye, target_head, PlayerEnums.MovementState.WALK,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, false, RID(), 0.0
	)

	# Expected with range_factor=1.0: 1.0 × 1.0 × 1.0 × 1.0 × 1.0 × 1.0 = 1.0
	assert_float(actual).override_failure_message(
			"AC-2-f: zero-distance must short-circuit to range_factor=1.0 (rate ≈ 1.0). Got %.4f." % actual
	).is_equal_approx(1.0, _TOLERANCE)


# ── AC-3: cache write ─────────────────────────────────────────────────────────

## AC-3: After process_sight_fill with LOS clear, _perception_cache reflects
## initialized=true, los_to_player=true, frame_stamp=Engine.get_physics_frames(),
## last_sight_stimulus_cause=SAW_PLAYER, last_sight_position=target.global_position.
func test_perception_cache_written_after_los_clear_tick() -> void:
	var setup: Array[Object] = _make_perception_setup(true)
	var perception: Perception = setup[0] as Perception
	var target: Node3D = setup[2] as Node3D

	var target_pos: Vector3 = Vector3(1.0, 2.0, -6.0)
	target.global_position = target_pos
	var guard_eye: Vector3 = Vector3.ZERO

	perception.process_sight_fill(
			target, guard_eye, target_pos, PlayerEnums.MovementState.WALK,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, false, RID(), 0.016
	)

	assert_bool(perception._perception_cache.initialized).override_failure_message(
			"AC-3: cache.initialized must be true after F.1 tick."
	).is_true()
	assert_bool(perception._perception_cache.los_to_player).override_failure_message(
			"AC-3: cache.los_to_player must be true on a clear-LOS tick."
	).is_true()
	assert_int(perception._perception_cache.last_sight_stimulus_cause).override_failure_message(
			"AC-3: alive target → last_sight_stimulus_cause must be SAW_PLAYER."
	).is_equal(StealthAI.AlertCause.SAW_PLAYER)
	assert_bool(perception._perception_cache.last_sight_position == target_pos).override_failure_message(
			"AC-3: last_sight_position must equal target.global_position."
	).is_true()


## AC-3: dead-body target → last_sight_stimulus_cause = SAW_BODY.
func test_perception_cache_records_saw_body_for_dead_target() -> void:
	var setup: Array[Object] = _make_perception_setup(true)
	var perception: Perception = setup[0] as Perception
	var target: Node3D = setup[2] as Node3D

	var target_pos: Vector3 = Vector3(0.0, 0.0, -3.0)
	target.global_position = target_pos
	var guard_eye: Vector3 = Vector3.ZERO

	perception.process_sight_fill(
			target, guard_eye, target_pos, PlayerEnums.MovementState.IDLE,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, true, RID(), 0.016
	)

	assert_int(perception._perception_cache.last_sight_stimulus_cause).override_failure_message(
			"AC-3: dead target → last_sight_stimulus_cause must be SAW_BODY."
	).is_equal(StealthAI.AlertCause.SAW_BODY)
	# los_to_player should be false for a dead-body target (it's los_to_DEAD_body)
	assert_bool(perception._perception_cache.los_to_player).override_failure_message(
			"AC-3: cache.los_to_player must be false when target is a dead body (it's a body, not the player)."
	).is_false()


## AC-3: blocked LOS → cache.los_to_player == false.
func test_perception_cache_records_los_blocked() -> void:
	var setup: Array[Object] = _make_perception_setup(false)  # LOS blocked
	var perception: Perception = setup[0] as Perception
	var target: Node3D = setup[2] as Node3D

	var target_pos: Vector3 = Vector3(0.0, 0.0, -6.0)
	target.global_position = target_pos
	var guard_eye: Vector3 = Vector3.ZERO

	perception.process_sight_fill(
			target, guard_eye, target_pos, PlayerEnums.MovementState.WALK,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, false, RID(), 0.016
	)

	assert_bool(perception._perception_cache.initialized).is_true()
	assert_bool(perception._perception_cache.los_to_player).override_failure_message(
			"AC-3: cache.los_to_player must be false when LOS is blocked."
	).is_false()


# ── AC-5: accumulator [0, 1] clamp ────────────────────────────────────────────

## AC-5: sight_accumulator never exceeds 1.0 even when fill rate is high and
## delta is large. Accumulator is clamped post-add.
func test_sight_accumulator_clamps_to_one_upper_bound() -> void:
	var setup: Array[Object] = _make_perception_setup(true)
	var perception: Perception = setup[0] as Perception
	var target: Node3D = setup[2] as Node3D

	var target_pos: Vector3 = Vector3(0.0, 0.0, -1.0)  # very close
	target.global_position = target_pos
	var guard_eye: Vector3 = Vector3.ZERO

	# Run 100 ticks at large delta — would produce an absurd accumulator without clamp.
	for i: int in range(100):
		perception.process_sight_fill(
				target, guard_eye, target_pos, PlayerEnums.MovementState.SPRINT,
				_SILHOUETTE_STANDING, StealthAI.AlertState.COMBAT, true, RID(), 1.0
		)

	assert_float(perception.sight_accumulator).override_failure_message(
			"AC-5: sight_accumulator must clamp at 1.0 upper bound. Got %.4f." % perception.sight_accumulator
	).is_less_equal(1.0)


## AC-5: sight_accumulator increases monotonically when fill rate is positive,
## starting from 0.0 (initial state).
func test_sight_accumulator_starts_at_zero_and_increases() -> void:
	var setup: Array[Object] = _make_perception_setup(true)
	var perception: Perception = setup[0] as Perception
	var target: Node3D = setup[2] as Node3D

	assert_float(perception.sight_accumulator).override_failure_message(
			"AC-5: sight_accumulator must start at 0.0."
	).is_equal_approx(0.0, _TOLERANCE)

	var target_pos: Vector3 = Vector3(0.0, 0.0, -2.0)
	target.global_position = target_pos
	var guard_eye: Vector3 = Vector3.ZERO

	perception.process_sight_fill(
			target, guard_eye, target_pos, PlayerEnums.MovementState.WALK,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, false, RID(), 0.016
	)

	assert_float(perception.sight_accumulator).override_failure_message(
			"AC-5: sight_accumulator must increase after a clear-LOS tick. Got %.4f." % perception.sight_accumulator
	).is_greater(0.0)


# ── AC-4 (degenerate): single F.1 tick issues exactly 1 raycast ───────────────

## AC-4 (degenerate): With F.2 sound fill deferred to post-VS, F.1 alone issues
## exactly 1 raycast per process_sight_fill call. This documents the contract
## for when F.2 lands and the deduplication assertion becomes meaningful.
func test_single_sight_fill_tick_issues_exactly_one_raycast() -> void:
	var setup: Array[Object] = _make_perception_setup(true)
	var perception: Perception = setup[0] as Perception
	var counter: CountingRaycastProvider = setup[1] as CountingRaycastProvider
	var target: Node3D = setup[2] as Node3D

	var target_pos: Vector3 = Vector3(0.0, 0.0, -6.0)
	target.global_position = target_pos
	var guard_eye: Vector3 = Vector3.ZERO

	perception.process_sight_fill(
			target, guard_eye, target_pos, PlayerEnums.MovementState.WALK,
			_SILHOUETTE_STANDING, StealthAI.AlertState.UNAWARE, false, RID(), 0.016
	)

	assert_int(counter.call_count).override_failure_message(
			"AC-4 (degenerate): one F.1 tick must issue exactly 1 raycast. Got %d." % counter.call_count
	).is_equal(1)
