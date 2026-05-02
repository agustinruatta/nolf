# tests/unit/feature/stealth_ai/stealth_ai_force_alert_state_test.gd
#
# StealthAIForceAlertStateTest — Story SAI-005 AC-6 + AC-7 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-005)
#   AC-6 (AC-SAI-3.5): force_alert_state lattice escalation; terminal rejection;
#                      de-escalation rejection; SCRIPTED cause behavior.
#   AC-7:              F.5 threshold exports exist with correct defaults and ranges.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIForceAlertStateTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"
const _GUARD_SCRIPT_PATH: String = "res://src/gameplay/stealth/guard.gd"
const _TOLERANCE: float = 0.0001


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


# ── AC-6: Lattice escalation ──────────────────────────────────────────────────

## AC-6: UNAWARE → SUSPICIOUS escalation returns true and transitions.
func test_force_alert_state_unaware_to_suspicious_succeeds() -> void:
	var guard: Guard = _make_guard()
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	assert_bool(result).override_failure_message(
		"AC-6: force_alert_state(SUSPICIOUS) from UNAWARE must return true."
	).is_true()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-6: state must be SUSPICIOUS after escalation."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-6: UNAWARE → SEARCHING escalation returns true (skip intermediate).
func test_force_alert_state_unaware_to_searching_succeeds() -> void:
	var guard: Guard = _make_guard()
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.HEARD_NOISE
	)
	assert_bool(result).is_true()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SEARCHING)


## AC-6: SUSPICIOUS → COMBAT escalation (multi-step skip) returns true.
func test_force_alert_state_suspicious_to_combat_succeeds() -> void:
	var guard: Guard = _make_guard()
	var _ok1: bool = guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER
	)
	assert_bool(result).is_true()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.COMBAT)


## AC-6: De-escalation rejected — force_alert_state(UNAWARE) from SUSPICIOUS returns false.
func test_force_alert_state_de_escalation_rejected() -> void:
	var guard: Guard = _make_guard()
	var _ok: bool = guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)

	var count: Array[int] = [0]
	var on_changed: Callable = func(_a, _o, _n, _s): count[0] += 1
	Events.alert_state_changed.connect(on_changed)

	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.UNAWARE, StealthAI.AlertCause.SAW_PLAYER
	)

	Events.alert_state_changed.disconnect(on_changed)

	assert_bool(result).override_failure_message(
		"AC-6: force_alert_state de-escalation must return false."
	).is_false()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-6: state must remain SUSPICIOUS after rejected de-escalation."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(count[0]).override_failure_message(
		"AC-6: no signal emitted on rejected de-escalation."
	).is_equal(0)


## AC-6: Same-state force returns false (idempotent rejection).
func test_force_alert_state_same_state_rejected() -> void:
	var guard: Guard = _make_guard()
	var _ok: bool = guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)

	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	assert_bool(result).override_failure_message(
		"AC-6: force_alert_state to same state must return false."
	).is_false()


# ── AC-6: Terminal state rejection ────────────────────────────────────────────

## AC-6: force_alert_state(UNCONSCIOUS, _) always returns false (terminal).
func test_force_alert_state_unconscious_always_rejected() -> void:
	var guard: Guard = _make_guard()
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.UNCONSCIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	assert_bool(result).override_failure_message(
		"AC-6: force_alert_state(UNCONSCIOUS) must always return false (terminal state)."
	).is_false()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.UNAWARE)


## AC-6: force_alert_state(DEAD, _) always returns false (terminal).
func test_force_alert_state_dead_always_rejected() -> void:
	var guard: Guard = _make_guard()
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.DEAD, StealthAI.AlertCause.SCRIPTED
	)
	assert_bool(result).override_failure_message(
		"AC-6: force_alert_state(DEAD) must always return false (terminal state)."
	).is_false()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.UNAWARE)


## AC-6: DEAD rejected even from a high state (COMBAT → DEAD via force is still rejected).
func test_force_alert_state_dead_rejected_from_combat() -> void:
	var guard: Guard = _make_guard()
	var _ok1: bool = guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	var _ok2: bool = guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)
	var _ok3: bool = guard.force_alert_state(StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER)

	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.DEAD, StealthAI.AlertCause.SAW_PLAYER
	)
	assert_bool(result).override_failure_message(
		"AC-6: force_alert_state(DEAD) from COMBAT must return false."
	).is_false()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.COMBAT)


# ── AC-6: SCRIPTED cause behavior ─────────────────────────────────────────────

## AC-6: force_alert_state(SEARCHING, SCRIPTED) on UNAWARE guard transitions
## AND emits actor_became_alerted with cause=SCRIPTED, severity=MAJOR,
## position=guard.global_position. Propagation NOT fired (post-VS).
func test_force_alert_state_scripted_cause_emits_became_alerted() -> void:
	# Arrange
	var guard: Guard = _make_guard()

	var became_alerted_calls: Array[Dictionary] = []
	var on_alerted: Callable = func(actor, cause, pos, sev):
		became_alerted_calls.append({
			"actor": actor, "cause": cause, "pos": pos, "sev": sev
		})
	Events.actor_became_alerted.connect(on_alerted)

	# Act
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SCRIPTED
	)

	Events.actor_became_alerted.disconnect(on_alerted)

	# Assert — transition occurred
	assert_bool(result).override_failure_message(
		"AC-6 SCRIPTED: force_alert_state(SEARCHING, SCRIPTED) must return true."
	).is_true()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-6 SCRIPTED: guard must be in SEARCHING after scripted force."
	).is_equal(StealthAI.AlertState.SEARCHING)

	# Assert — actor_became_alerted emitted once with SCRIPTED cause
	assert_int(became_alerted_calls.size()).override_failure_message(
		"AC-6 SCRIPTED: actor_became_alerted must emit once."
	).is_equal(1)
	assert_int(int(became_alerted_calls[0]["cause"])).override_failure_message(
		"AC-6 SCRIPTED: cause must be SCRIPTED."
	).is_equal(StealthAI.AlertCause.SCRIPTED)

	# Assert — severity is MAJOR (SEARCHING transition per _compute_severity rule)
	assert_int(int(became_alerted_calls[0]["sev"])).override_failure_message(
		"AC-6 SCRIPTED: severity must be MAJOR (SEARCHING entry)."
	).is_equal(StealthAI.Severity.MAJOR)

	# Assert — stimulus_position == guard.global_position (SCRIPTED uses guard pos)
	var expected_pos: Vector3 = guard.global_position
	assert_bool(
		(became_alerted_calls[0]["pos"] as Vector3).is_equal_approx(expected_pos)
	).override_failure_message(
		"AC-6 SCRIPTED: stimulus_position must equal guard.global_position. "
		+ "Got: %s Expected: %s" % [str(became_alerted_calls[0]["pos"]), str(expected_pos)]
	).is_true()


## AC-6: ALERTED_BY_OTHER cause suppresses actor_became_alerted (one-hop invariant).
func test_force_alert_state_alerted_by_other_suppresses_became_alerted() -> void:
	# Arrange
	var guard: Guard = _make_guard()

	var became_alerted_count: Array[int] = [0]
	var on_alerted: Callable = func(_a, _c, _p, _s): became_alerted_count[0] += 1
	Events.actor_became_alerted.connect(on_alerted)

	# Act
	var _result: bool = guard.force_alert_state(
		StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.ALERTED_BY_OTHER
	)

	Events.actor_became_alerted.disconnect(on_alerted)

	# Assert — actor_became_alerted suppressed (one-hop invariant)
	assert_int(became_alerted_count[0]).override_failure_message(
		"AC-6 one-hop: actor_became_alerted must NOT emit when cause=ALERTED_BY_OTHER."
	).is_equal(0)

	# alert_state_changed still fired
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-6 one-hop: state must still transition to SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-6: force_alert_state emits alert_state_changed before actor_became_alerted.
## Signal order is deterministic: alert_state_changed first.
func test_force_alert_state_signal_emission_order() -> void:
	var guard: Guard = _make_guard()

	var emission_order: Array[String] = []
	var on_changed: Callable = func(_a, _o, _n, _s): emission_order.append("changed")
	var on_alerted: Callable = func(_a, _c, _p, _s): emission_order.append("alerted")
	Events.alert_state_changed.connect(on_changed)
	Events.actor_became_alerted.connect(on_alerted)

	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)

	Events.alert_state_changed.disconnect(on_changed)
	Events.actor_became_alerted.disconnect(on_alerted)

	assert_int(emission_order.size()).override_failure_message(
		"AC-6 order: must emit exactly 2 signals."
	).is_equal(2)
	assert_str(emission_order[0]).override_failure_message(
		"AC-6 order: alert_state_changed must fire FIRST."
	).is_equal("changed")
	assert_str(emission_order[1]).override_failure_message(
		"AC-6 order: actor_became_alerted must fire SECOND."
	).is_equal("alerted")


# ── AC-7: F.5 threshold exports ───────────────────────────────────────────────

## AC-7: t_suspicious default == 0.3 (safe range [0.2, 0.4]).
func test_threshold_t_suspicious_default() -> void:
	var guard: Guard = _make_guard()
	assert_float(guard.t_suspicious).override_failure_message(
		"AC-7: t_suspicious default must be 0.3."
	).is_equal_approx(0.3, _TOLERANCE)


## AC-7: t_searching default == 0.6 (safe range [0.5, 0.75]).
func test_threshold_t_searching_default() -> void:
	var guard: Guard = _make_guard()
	assert_float(guard.t_searching).override_failure_message(
		"AC-7: t_searching default must be 0.6."
	).is_equal_approx(0.6, _TOLERANCE)


## AC-7: t_combat default == 0.95 (safe range [0.9, 1.0]).
func test_threshold_t_combat_default() -> void:
	var guard: Guard = _make_guard()
	assert_float(guard.t_combat).override_failure_message(
		"AC-7: t_combat default must be 0.95."
	).is_equal_approx(0.95, _TOLERANCE)


## AC-7: t_decay_unaware default == 0.1 (safe range [0.05, 0.2]).
func test_threshold_t_decay_unaware_default() -> void:
	var guard: Guard = _make_guard()
	assert_float(guard.t_decay_unaware).override_failure_message(
		"AC-7: t_decay_unaware default must be 0.1."
	).is_equal_approx(0.1, _TOLERANCE)


## AC-7: t_decay_searching default == 0.35 (safe range [0.25, 0.45]).
func test_threshold_t_decay_searching_default() -> void:
	var guard: Guard = _make_guard()
	assert_float(guard.t_decay_searching).override_failure_message(
		"AC-7: t_decay_searching default must be 0.35."
	).is_equal_approx(0.35, _TOLERANCE)


## AC-7: Timer exports have correct defaults.
func test_timer_exports_have_correct_defaults() -> void:
	var guard: Guard = _make_guard()
	assert_float(guard.suspicion_timeout_sec).override_failure_message(
		"AC-7: suspicion_timeout_sec default must be 4.0."
	).is_equal_approx(4.0, _TOLERANCE)
	assert_float(guard.search_timeout_sec).override_failure_message(
		"AC-7: search_timeout_sec default must be 12.0."
	).is_equal_approx(12.0, _TOLERANCE)
	assert_float(guard.combat_lost_target_sec).override_failure_message(
		"AC-7: combat_lost_target_sec default must be 8.0."
	).is_equal_approx(8.0, _TOLERANCE)


## AC-7: Thresholds are declared as @export_range in source (grep check).
## Verifies the data-driven constraint from coding-standards.md.
func test_threshold_exports_are_export_range_in_source() -> void:
	var source: String = FileAccess.get_file_as_string(_GUARD_SCRIPT_PATH)
	assert_str(source).override_failure_message(
		"AC-7: could not read guard.gd source."
	).is_not_empty()

	# Verify each threshold has @export_range annotation
	var threshold_names: Array[String] = [
		"t_suspicious", "t_searching", "t_combat", "t_decay_unaware", "t_decay_searching"
	]
	var missing: Array[String] = []
	for name: String in threshold_names:
		var pattern: RegEx = RegEx.create_from_string(
			"@export_range\\([^)]+\\)\\s+var\\s+" + name + "\\s*:"
		)
		var lines: PackedStringArray = source.split("\n")
		var found: bool = false
		for line: String in lines:
			if pattern.search(line) != null:
				found = true
				break
		if not found:
			missing.append(name)

	assert_int(missing.size()).override_failure_message(
		"AC-7: these thresholds must use @export_range annotation: %s"
		% ", ".join(missing)
	).is_equal(0)


## AC-7: Thresholds are tunable — changing t_suspicious changes escalation behavior.
func test_threshold_t_suspicious_is_tunable() -> void:
	# Arrange — lower t_suspicious so 0.2 triggers a transition
	var guard: Guard = _make_guard()
	guard.t_suspicious = 0.2  # designer-tuned lower threshold

	guard._perception.sight_accumulator = 0.21
	guard._perception.sound_accumulator = 0.0

	# Act
	guard._evaluate_transitions()

	# Assert — 0.21 now crosses the lowered 0.2 threshold
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-7 tunable: t_suspicious=0.2, sight=0.21 → must transition to SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
