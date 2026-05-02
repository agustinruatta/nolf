# tests/unit/feature/stealth_ai/stealth_ai_reversibility_matrix_test.gd
#
# StealthAIReversibilityMatrixTest — Story SAI-005 AC-3 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-005)
#   AC-3 (AC-SAI-1.3): 19-edge reversibility matrix (9 live-to-live legal edges +
#   forbidden path assertions). Terminal-state edges (→UNCONSCIOUS, →DEAD) are
#   declared but marked post-VS pending per story spec.
#
# MATRIX
#   Legal escalation edges (via _evaluate_transitions or force_alert_state):
#     (UNAWARE→SUSPICIOUS), (UNAWARE→SEARCHING), (UNAWARE→COMBAT)
#     (SUSPICIOUS→SEARCHING), (SUSPICIOUS→COMBAT)
#     (SEARCHING→COMBAT)
#   Legal de-escalation edges (via _de_escalate_to):
#     (SUSPICIOUS→UNAWARE), (SEARCHING→SUSPICIOUS), (COMBAT→SEARCHING)
#   Forbidden direct paths (must not transition):
#     (COMBAT→UNAWARE direct), (COMBAT→SUSPICIOUS direct), (SEARCHING→UNAWARE direct)
#   Terminal-state edges (post-VS pending):
#     (ANY→UNCONSCIOUS), (ANY→DEAD) via takedown/damage routing (Story 010).
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIReversibilityMatrixTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helpers ───────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


## Sets guard to a given start state via force_alert_state chains.
func _set_guard_to_state(guard: Guard, target: StealthAI.AlertState) -> void:
	match target:
		StealthAI.AlertState.UNAWARE:
			pass  # default start state
		StealthAI.AlertState.SUSPICIOUS:
			var _ok: bool = guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
		StealthAI.AlertState.SEARCHING:
			var _ok1: bool = guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
			var _ok2: bool = guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)
		StealthAI.AlertState.COMBAT:
			var _ok1: bool = guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
			var _ok2: bool = guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)
			var _ok3: bool = guard.force_alert_state(StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER)


# ── Legal escalation edges ────────────────────────────────────────────────────

## Matrix row: UNAWARE → SUSPICIOUS via _evaluate_transitions (sight=0.35).
func test_matrix_unaware_to_suspicious_legal_edge() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0

	var changed: Array[bool] = [false]
	var on_changed: Callable = func(_a, old_s, new_s, _v):
		if int(old_s) == StealthAI.AlertState.UNAWARE and int(new_s) == StealthAI.AlertState.SUSPICIOUS:
			changed[0] = true
	Events.alert_state_changed.connect(on_changed)

	# Act
	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)

	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: UNAWARE→SUSPICIOUS legal edge failed."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_bool(changed[0]).override_failure_message(
		"Matrix: UNAWARE→SUSPICIOUS must emit alert_state_changed with correct states."
	).is_true()


## Matrix row: UNAWARE → SEARCHING via _evaluate_transitions (sight=0.6).
func test_matrix_unaware_to_searching_legal_edge() -> void:
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.6
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: UNAWARE→SEARCHING legal edge failed."
	).is_equal(StealthAI.AlertState.SEARCHING)


## Matrix row: UNAWARE → COMBAT via _evaluate_transitions (sight=0.95).
func test_matrix_unaware_to_combat_legal_edge() -> void:
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.95
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: UNAWARE→COMBAT legal edge failed."
	).is_equal(StealthAI.AlertState.COMBAT)


## Matrix row: SUSPICIOUS → SEARCHING via _evaluate_transitions.
func test_matrix_suspicious_to_searching_legal_edge() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.SUSPICIOUS)
	guard._perception.sight_accumulator = 0.6
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: SUSPICIOUS→SEARCHING legal edge failed."
	).is_equal(StealthAI.AlertState.SEARCHING)


## Matrix row: SUSPICIOUS → COMBAT via _evaluate_transitions.
func test_matrix_suspicious_to_combat_legal_edge() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.SUSPICIOUS)
	guard._perception.sight_accumulator = 0.95
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: SUSPICIOUS→COMBAT legal edge failed."
	).is_equal(StealthAI.AlertState.COMBAT)


## Matrix row: SEARCHING → COMBAT via _evaluate_transitions.
func test_matrix_searching_to_combat_legal_edge() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.SEARCHING)
	guard._perception.sight_accumulator = 0.95
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: SEARCHING→COMBAT legal edge failed."
	).is_equal(StealthAI.AlertState.COMBAT)


# ── Legal de-escalation edges ─────────────────────────────────────────────────

## Matrix row: SUSPICIOUS → UNAWARE via _de_escalate_to.
func test_matrix_suspicious_to_unaware_de_escalation_edge() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.SUSPICIOUS)
	guard._de_escalate_to(StealthAI.AlertState.UNAWARE)
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: SUSPICIOUS→UNAWARE de-escalation edge failed."
	).is_equal(StealthAI.AlertState.UNAWARE)


## Matrix row: SEARCHING → SUSPICIOUS via _de_escalate_to.
func test_matrix_searching_to_suspicious_de_escalation_edge() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.SEARCHING)
	guard._de_escalate_to(StealthAI.AlertState.SUSPICIOUS)
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: SEARCHING→SUSPICIOUS de-escalation edge failed."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## Matrix row: COMBAT → SEARCHING via _de_escalate_to.
func test_matrix_combat_to_searching_de_escalation_edge() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.COMBAT)
	guard._de_escalate_to(StealthAI.AlertState.SEARCHING)
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix: COMBAT→SEARCHING de-escalation edge failed."
	).is_equal(StealthAI.AlertState.SEARCHING)


# ── Forbidden direct paths ────────────────────────────────────────────────────

## Forbidden: COMBAT → UNAWARE direct via _evaluate_transitions.
## Even if combined score drops to zero, _evaluate_transitions does NOT jump
## directly from COMBAT to UNAWARE. The COMBAT match arm is a pass.
func test_matrix_combat_to_unaware_direct_forbidden() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.COMBAT)
	guard._perception.sight_accumulator = 0.0
	guard._perception.sound_accumulator = 0.0

	var changed_count: int = 0
	var on_changed: Callable = func(_a, _o, _n, _s): changed_count += 1
	Events.alert_state_changed.connect(on_changed)

	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)

	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix forbidden: COMBAT must not transition to UNAWARE directly via _evaluate_transitions."
	).is_equal(StealthAI.AlertState.COMBAT)
	assert_int(changed_count).override_failure_message(
		"Matrix forbidden: no signal must fire on forbidden COMBAT→UNAWARE path."
	).is_equal(0)


## Forbidden: COMBAT → SUSPICIOUS direct via _evaluate_transitions.
## Low combined score in COMBAT must not transition to SUSPICIOUS.
func test_matrix_combat_to_suspicious_direct_forbidden() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.COMBAT)
	guard._perception.sight_accumulator = 0.2  # below T_SEARCHING (0.6)
	guard._perception.sound_accumulator = 0.0

	guard._evaluate_transitions()

	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix forbidden: COMBAT must not transition to SUSPICIOUS directly via _evaluate_transitions."
	).is_equal(StealthAI.AlertState.COMBAT)


## Forbidden: SEARCHING → UNAWARE direct via _evaluate_transitions.
## Low combined score in SEARCHING must not jump to UNAWARE.
func test_matrix_searching_to_unaware_direct_forbidden() -> void:
	var guard: Guard = _make_guard()
	_set_guard_to_state(guard, StealthAI.AlertState.SEARCHING)
	guard._perception.sight_accumulator = 0.0
	guard._perception.sound_accumulator = 0.0

	guard._evaluate_transitions()

	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix forbidden: SEARCHING must not transition to UNAWARE directly via _evaluate_transitions."
	).is_equal(StealthAI.AlertState.SEARCHING)


# ── Terminal-state edges (post-VS pending) ────────────────────────────────────

## Post-VS pending: force_alert_state(UNCONSCIOUS) is always rejected.
## Declared here to document the post-VS contract; Story 010 implements takedown routing.
func test_matrix_terminal_state_force_alert_always_rejected_unconscious() -> void:
	var guard: Guard = _make_guard()
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.UNCONSCIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	assert_bool(result).override_failure_message(
		"Matrix post-VS: force_alert_state(UNCONSCIOUS) must always return false."
	).is_false()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix post-VS: guard state unchanged after rejected UNCONSCIOUS force."
	).is_equal(StealthAI.AlertState.UNAWARE)


## Post-VS pending: force_alert_state(DEAD) always rejected.
func test_matrix_terminal_state_force_alert_always_rejected_dead() -> void:
	var guard: Guard = _make_guard()
	var result: bool = guard.force_alert_state(
		StealthAI.AlertState.DEAD, StealthAI.AlertCause.SAW_PLAYER
	)
	assert_bool(result).override_failure_message(
		"Matrix post-VS: force_alert_state(DEAD) must always return false."
	).is_false()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"Matrix post-VS: guard state unchanged after rejected DEAD force."
	).is_equal(StealthAI.AlertState.UNAWARE)
