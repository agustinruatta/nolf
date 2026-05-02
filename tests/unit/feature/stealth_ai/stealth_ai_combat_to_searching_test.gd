# tests/unit/feature/stealth_ai/stealth_ai_combat_to_searching_test.gd
#
# StealthAICombatToSearchingTest — Story SAI-007 AC-4 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-007)
#   AC-4 (AC-SAI-1.6): COMBAT → SEARCHING via timer expiry.
#       - Sight accumulator set to t_searching - 0.01 (0.59) before transition.
#       - alert_state_changed(guard, COMBAT, SEARCHING, MAJOR) emitted once.
#       - actor_lost_target(guard, MAJOR) emitted once.
#       - COMBAT → UNAWARE direct transition does NOT occur.
#   AC-7 (combat timer reset on LOS confirm): timer resets when
#       _perception_cache.los_to_player is true; guard stays COMBAT.
#   Timer default: _combat_lost_target_remaining initialised to combat_lost_target_sec
#       on state entry (via _initialize_timer_for_state).
#
# TEST APPROACH
#   Guard.tscn instantiation. Force to COMBAT via lattice. Manipulate
#   _perception_cache.initialized / los_to_player to simulate LOS blocked.
#   Call guard.tick_de_escalation_timers() in a loop to simulate time.
#   Assert state, accumulator values, and signal payloads.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.
#
# Implements: Story SAI-007 (TR-SAI-009 §F.3 AC-4)
# GDD: design/gdd/stealth-ai.md §COMBAT recovery pacing + §Detailed Rules AC-4

class_name StealthAICombatToSearchingTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"
const _TOLERANCE: float = 0.001


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard_in_combat() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	# Climb lattice to COMBAT
	var _ok1: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok2: bool = guard.force_alert_state(
			StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok3: bool = guard.force_alert_state(
			StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER
	)
	return guard


# ── AC-4: COMBAT → SEARCHING timer expiry ────────────────────────────────────

## AC-4: After combat_lost_target_sec (8.0 s) with LOS blocked,
## guard transitions to SEARCHING (not UNAWARE).
func test_combat_to_searching_fires_after_combat_lost_target_sec() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_combat()
	guard._perception.sight_accumulator = 0.9
	# LOS blocked: cache initialized but los_to_player = false
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.los_to_player = false

	# Act: 8.5 simulated seconds (just past 8.0 s timeout)
	# 17 ticks × 0.5 s = 8.5 s
	for _i: int in range(17):
		guard.tick_de_escalation_timers(0.5)

	# Assert: transitioned to SEARCHING (not UNAWARE, not COMBAT)
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-4: guard must be SEARCHING after combat_lost_target_sec with no sight."
	).is_equal(StealthAI.AlertState.SEARCHING)


## AC-4: COMBAT → UNAWARE direct transition must NOT occur (forbidden by GDD transition table).
func test_combat_never_transitions_directly_to_unaware() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_combat()
	guard._perception.sight_accumulator = 0.9
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.los_to_player = false

	# Act: simulate far more than full timeout to ensure only SEARCHING is reachable
	for _i: int in range(20):
		guard.tick_de_escalation_timers(0.5)

	# Assert: state is SEARCHING (timer fired once to SEARCHING; further
	# SEARCHING→SUSPICIOUS needs search_timeout_sec which is 12 s).
	assert_bool(guard.current_alert_state != StealthAI.AlertState.UNAWARE).override_failure_message(
		"AC-4: COMBAT must NEVER transition directly to UNAWARE (forbidden path)."
	).is_true()


## AC-4: sight_accumulator is set to t_searching - 0.01 (0.59) exactly before transition.
func test_combat_to_searching_sets_sight_to_t_searching_minus_epsilon() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_combat()
	guard._perception.sight_accumulator = 0.9
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.los_to_player = false

	# Act: tick past combat_lost_target_sec (default 8.0 s)
	for _i: int in range(17):
		guard.tick_de_escalation_timers(0.5)

	# Assert: sight = t_searching - 0.01 = 0.6 - 0.01 = 0.59
	var expected_sight: float = guard.t_searching - 0.01
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-4: sight_accumulator must be t_searching - 0.01 (%.4f) after COMBAT → SEARCHING."
		% expected_sight
	).is_equal_approx(expected_sight, _TOLERANCE)


## AC-4: alert_state_changed(guard, COMBAT, SEARCHING, MAJOR) emitted exactly once.
func test_combat_to_searching_emits_alert_state_changed_major() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_combat()
	guard._perception.sight_accumulator = 0.9
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.los_to_player = false

	var changed_calls: Array[Dictionary] = []
	var on_changed: Callable = func(actor, old_s, new_s, sev):
		changed_calls.append({"actor": actor, "old": old_s, "new": new_s, "sev": sev})
	Events.alert_state_changed.connect(on_changed)

	# Act
	for _i: int in range(17):
		guard.tick_de_escalation_timers(0.5)

	Events.alert_state_changed.disconnect(on_changed)

	# Assert: one emission with correct parameters
	assert_int(changed_calls.size()).override_failure_message(
		"AC-4: alert_state_changed must emit exactly once on COMBAT → SEARCHING."
	).is_equal(1)
	assert_int(int(changed_calls[0]["old"])).override_failure_message(
		"AC-4: prev_state must be COMBAT."
	).is_equal(StealthAI.AlertState.COMBAT)
	assert_int(int(changed_calls[0]["new"])).override_failure_message(
		"AC-4: new_state must be SEARCHING."
	).is_equal(StealthAI.AlertState.SEARCHING)
	assert_int(int(changed_calls[0]["sev"])).override_failure_message(
		"AC-4: severity must be MAJOR (SEARCHING entry per _compute_severity)."
	).is_equal(StealthAI.Severity.MAJOR)


## AC-4: actor_lost_target(guard, MAJOR) emitted exactly once on COMBAT → SEARCHING.
func test_combat_to_searching_emits_actor_lost_target_major() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_combat()
	guard._perception.sight_accumulator = 0.9
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.los_to_player = false

	var lost_calls: Array[int] = [0]
	var lost_sev_calls: Array[int] = []
	var on_lost: Callable = func(_a, sev):
		lost_calls[0] += 1
		lost_sev_calls.append(int(sev))
	Events.actor_lost_target.connect(on_lost)

	# Act
	for _i: int in range(17):
		guard.tick_de_escalation_timers(0.5)

	Events.actor_lost_target.disconnect(on_lost)

	# Assert: emitted once with MAJOR severity
	assert_int(lost_calls[0]).override_failure_message(
		"AC-4: actor_lost_target must emit exactly once on COMBAT → SEARCHING."
	).is_equal(1)
	assert_int(lost_sev_calls[0]).override_failure_message(
		"AC-4: actor_lost_target severity must be MAJOR."
	).is_equal(StealthAI.Severity.MAJOR)


## AC-7 (combat): timer resets when LOS is confirmed — guard stays COMBAT.
func test_combat_timer_resets_when_los_is_confirmed() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_combat()
	guard._perception.sight_accumulator = 0.9
	# LOS initially blocked
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.los_to_player = false

	# Tick down 7 s (close to timeout)
	for _i: int in range(14):
		guard.tick_de_escalation_timers(0.5)

	# Guard still COMBAT at this point (< 8 s elapsed)
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.COMBAT)

	# LOS confirmed: guard re-sights Eve — timer resets
	guard._perception._perception_cache.los_to_player = true
	guard.tick_de_escalation_timers(0.5)

	# Now LOS blocked again, tick 8 s — timer was reset so 8 more seconds needed
	guard._perception._perception_cache.los_to_player = false
	for _i: int in range(15):
		guard.tick_de_escalation_timers(0.5)

	# Assert: still COMBAT — timer was reset by the LOS confirmation
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-7 combat: guard must remain COMBAT until the full 8 s elapses again after LOS reset."
	).is_equal(StealthAI.AlertState.COMBAT)


## Timer initialises to combat_lost_target_sec on entering COMBAT via force_alert_state.
func test_combat_timer_initialised_on_entry_via_force_alert_state() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_combat()

	# Assert: timer should equal combat_lost_target_sec (8.0 s) after entering COMBAT
	assert_float(guard._combat_lost_target_remaining).override_failure_message(
		"Timer init: _combat_lost_target_remaining must equal combat_lost_target_sec on COMBAT entry."
	).is_equal_approx(guard.combat_lost_target_sec, _TOLERANCE)
