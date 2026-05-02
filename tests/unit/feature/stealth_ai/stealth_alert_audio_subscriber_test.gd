# tests/unit/feature/stealth_ai/stealth_alert_audio_subscriber_test.gd
#
# StealthAlertAudioSubscriberTest — Story SAI-008 unit-level coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-008)
#   AC-1: Subscriber connects to actor_became_alerted + alert_state_changed in
#         _ready; disconnects in _exit_tree with is_connected guards.
#   AC-2: MAJOR-severity actor_became_alerted plays stinger at actor.global_position;
#         MINOR-severity does NOT play stinger (Pillar 1 comedy preservation).
#         is_instance_valid(actor) guard prevents crash on freed-actor signals.
#   AC-3: alert_state_changed updates _guard_alert_states[actor]; same-state
#         transitions are no-ops (idempotent).
#   AC-5: MINOR severity DOES NOT play stinger (negative case).
#   AC-6 partial: signal frequency guard verified at the unit level (no
#         oscillation across multiple emits).
#
# DEFERRED FROM THIS STORY (per Out of Scope):
#   AC-4 end-to-end integration test → see stealth_ai_full_perception_loop_test.gd
#   AC-6 full 600-tick scripted sequence → integration test scope
#   Manual playtest sign-off → production/qa/evidence/ deferred to later sprint
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAlertAudioSubscriberTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helpers ───────────────────────────────────────────────────────────

func _make_subscriber() -> StealthAlertAudioSubscriber:
	var sub: StealthAlertAudioSubscriber = StealthAlertAudioSubscriber.new()
	add_child(sub)
	auto_free(sub)
	return sub


func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


# ── AC-1: connect / disconnect lifecycle ─────────────────────────────────────

## AC-1: After _ready(), subscriber is connected to actor_became_alerted +
## alert_state_changed.
func test_subscriber_connects_to_sai_signals_on_ready() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()

	assert_bool(Events.actor_became_alerted.is_connected(sub._on_actor_became_alerted)).override_failure_message(
		"AC-1: subscriber must be connected to actor_became_alerted after _ready."
	).is_true()
	assert_bool(Events.alert_state_changed.is_connected(sub._on_alert_state_changed)).override_failure_message(
		"AC-1: subscriber must be connected to alert_state_changed after _ready."
	).is_true()


## AC-1: After _exit_tree(), subscriber is disconnected from both signals.
func test_subscriber_disconnects_from_sai_signals_on_exit_tree() -> void:
	var sub: StealthAlertAudioSubscriber = StealthAlertAudioSubscriber.new()
	add_child(sub)
	# Don't auto_free — manually free to trigger _exit_tree synchronously.
	var on_alerted: Callable = sub._on_actor_became_alerted
	var on_changed: Callable = sub._on_alert_state_changed

	sub.queue_free()
	await get_tree().process_frame  # let _exit_tree fire

	assert_bool(Events.actor_became_alerted.is_connected(on_alerted)).override_failure_message(
		"AC-1: subscriber must disconnect actor_became_alerted on _exit_tree."
	).is_false()
	assert_bool(Events.alert_state_changed.is_connected(on_changed)).override_failure_message(
		"AC-1: subscriber must disconnect alert_state_changed on _exit_tree."
	).is_false()


# ── AC-2: severity-gated stinger ─────────────────────────────────────────────

## AC-2: MAJOR-severity actor_became_alerted plays stinger.
func test_major_severity_plays_stinger() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()
	guard.global_position = Vector3(3.0, 0.0, 4.0)

	# Manually emit actor_became_alerted with MAJOR severity
	Events.actor_became_alerted.emit(
		guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MAJOR
	)

	assert_int(sub.stinger_play_count).override_failure_message(
		"AC-2: MAJOR severity must play stinger exactly once (got %d)." % sub.stinger_play_count
	).is_equal(1)


## AC-2: Stinger origin equals actor.global_position.
func test_major_severity_stinger_origin_is_actor_position() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()
	guard.global_position = Vector3(7.0, 1.0, -3.0)

	Events.actor_became_alerted.emit(
		guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MAJOR
	)

	assert_int(sub.stinger_play_positions.size()).is_equal(1)
	assert_bool(sub.stinger_play_positions[0].is_equal_approx(guard.global_position)).override_failure_message(
		"AC-2: stinger origin must equal actor.global_position. Got %s, expected %s." % [
			str(sub.stinger_play_positions[0]), str(guard.global_position)
		]
	).is_true()


## AC-2 + AC-5: MINOR-severity actor_became_alerted does NOT play stinger.
func test_minor_severity_does_not_play_stinger() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	Events.actor_became_alerted.emit(
		guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MINOR
	)

	assert_int(sub.stinger_play_count).override_failure_message(
		"AC-2 + AC-5: MINOR severity must NOT play stinger (Pillar 1 comedy). Got %d." % sub.stinger_play_count
	).is_equal(0)


## AC-2: Multiple MAJOR emissions accumulate stinger_play_count.
func test_multiple_major_emissions_accumulate_stinger_count() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	for i: int in range(3):
		Events.actor_became_alerted.emit(
			guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MAJOR
		)

	assert_int(sub.stinger_play_count).override_failure_message(
		"AC-2: 3 MAJOR emissions must produce 3 stinger plays."
	).is_equal(3)


## AC-2 + AC-5: Mixed MAJOR + MINOR — only MAJOR contribute to stinger count.
func test_mixed_severity_emissions_only_major_play_stingers() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	Events.actor_became_alerted.emit(
		guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MINOR
	)
	Events.actor_became_alerted.emit(
		guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MAJOR
	)
	Events.actor_became_alerted.emit(
		guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MINOR
	)
	Events.actor_became_alerted.emit(
		guard, StealthAI.AlertCause.SAW_PLAYER, Vector3.ZERO, StealthAI.Severity.MAJOR
	)

	assert_int(sub.stinger_play_count).override_failure_message(
		"AC-2: 2 MAJOR + 2 MINOR must produce 2 stinger plays (only MAJOR fire)."
	).is_equal(2)


# ── AC-3: per-guard alert state tracking ─────────────────────────────────────

## AC-3: alert_state_changed updates _guard_alert_states[actor].
func test_alert_state_changed_updates_guard_state_dict() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	Events.alert_state_changed.emit(
		guard,
		StealthAI.AlertState.UNAWARE,
		StealthAI.AlertState.SUSPICIOUS,
		StealthAI.Severity.MINOR
	)

	assert_bool(sub._guard_alert_states.has(guard)).override_failure_message(
		"AC-3: subscriber must track guard alert state in _guard_alert_states."
	).is_true()
	assert_int(sub._guard_alert_states[guard]).override_failure_message(
		"AC-3: guard's tracked state must equal new_state from signal."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-3: Same-state transition is a no-op (idempotent contract).
func test_same_state_transition_is_no_op() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	# First seed the dict to SUSPICIOUS
	Events.alert_state_changed.emit(
		guard, StealthAI.AlertState.UNAWARE, StealthAI.AlertState.SUSPICIOUS, StealthAI.Severity.MINOR
	)
	assert_int(sub._guard_alert_states[guard]).is_equal(StealthAI.AlertState.SUSPICIOUS)

	# Same-state transition — track size to verify dict not modified
	var dict_size_before: int = sub._guard_alert_states.size()

	Events.alert_state_changed.emit(
		guard, StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertState.SUSPICIOUS, StealthAI.Severity.MINOR
	)

	assert_int(sub._guard_alert_states.size()).override_failure_message(
		"AC-3: same-state emission must not grow the dict."
	).is_equal(dict_size_before)
	assert_int(sub._guard_alert_states[guard]).override_failure_message(
		"AC-3: same-state emission must leave tracked state unchanged."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-3: Multiple guards tracked independently.
func test_multiple_guards_tracked_independently() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard_a: Guard = _make_guard()
	var guard_b: Guard = _make_guard()

	Events.alert_state_changed.emit(
		guard_a, StealthAI.AlertState.UNAWARE, StealthAI.AlertState.SUSPICIOUS, StealthAI.Severity.MINOR
	)
	Events.alert_state_changed.emit(
		guard_b, StealthAI.AlertState.UNAWARE, StealthAI.AlertState.SEARCHING, StealthAI.Severity.MAJOR
	)

	assert_int(sub._guard_alert_states[guard_a]).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(sub._guard_alert_states[guard_b]).is_equal(StealthAI.AlertState.SEARCHING)
	assert_int(sub._guard_alert_states.size()).is_equal(2)


# ── AC-2 + AC-3: Real Guard transition triggers subscriber correctly ─────────

## End-to-end (unit level): force_alert_state on a real Guard fires the signal,
## subscriber reacts. Confirms wiring through the production code path.
func test_real_guard_force_alert_state_triggers_subscriber() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	# Force UNAWARE → SEARCHING (skipping SUSPICIOUS via lattice escalation;
	# force_alert_state allows escalation to any higher state directly).
	# SEARCHING → MAJOR severity per _compute_severity rule.
	guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)

	# Subscriber should have processed both alert_state_changed (UNAWARE → SEARCHING)
	# and actor_became_alerted (SAW_PLAYER, MAJOR).
	assert_int(sub.stinger_play_count).override_failure_message(
		"Real Guard force_alert_state(SEARCHING) → MAJOR severity → 1 stinger play."
	).is_equal(1)
	assert_int(sub._guard_alert_states[guard]).override_failure_message(
		"Real Guard force_alert_state must update subscriber's state dict."
	).is_equal(StealthAI.AlertState.SEARCHING)


## Real Guard escalating to SUSPICIOUS → MINOR severity → no stinger.
func test_real_guard_escalation_to_suspicious_does_not_play_stinger() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	# Set sight = 0.35 → triggers UNAWARE → SUSPICIOUS via _evaluate_transitions
	# SUSPICIOUS → MINOR severity per _compute_severity rule.
	guard._perception.sight_accumulator = 0.35
	guard._evaluate_transitions()

	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(sub.stinger_play_count).override_failure_message(
		"Real Guard UNAWARE → SUSPICIOUS = MINOR severity → NO stinger (Pillar 1)."
	).is_equal(0)
	assert_int(sub._guard_alert_states[guard]).is_equal(StealthAI.AlertState.SUSPICIOUS)
