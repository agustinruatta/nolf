# tests/unit/feature/hud_state_signaling/hss_alert_cue_test.gd
#
# HSSAlertCueTest — GdUnit4 suite for Story HSS-002.
#
# PURPOSE
#   AC-HSS-2.1..2.9 — ALERT_CUE state entry, rate-gate, upward-severity
#   bypass, freed-actor cleanup, context-leave dismissal, no _process.

class_name HSSAlertCueTest
extends GdUnitTestSuite

const _HUD_CORE_SCRIPT: String = "res://src/ui/hud_core/hud_core.gd"
const _HSS_SCRIPT: String = "res://src/ui/hud_state_signaling.gd"


# Helper to wire up a fresh HUD Core + HSS pair in the test scene.
func _spawn_hss() -> Node:
	var HUDCoreScript = load(_HUD_CORE_SCRIPT)
	var hud: CanvasLayer = HUDCoreScript.new()
	add_child(hud)
	auto_free(hud)

	var HSSScript = load(_HSS_SCRIPT)
	var hss: Node = HSSScript.new()
	add_child(hss)
	auto_free(hss)
	return hss


# ── AC-HSS-2.1: First alert event enters ALERT_CUE state ────────────────────

func test_first_alert_event_enters_alert_cue_state() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame

	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)

	# Act: emit a SUSPICIOUS transition.
	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)

	# Assert: Timer running, state is ALERT_CUE, last_fired set.
	assert_bool(hss._alert_cue_timer.is_stopped()).is_false()
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.ALERT_CUE))
	assert_bool(hss._alert_cue_last_fired_per_actor.has(actor)).is_true()


# ── AC-HSS-2.2: Same-severity event within cooldown is suppressed ───────────

func test_same_severity_event_within_cooldown_is_suppressed() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)

	# First event sets the rate-gate.
	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	var first_fired: float = hss._alert_cue_last_fired_per_actor[actor]

	# Immediately re-emit (well within 1.0s cooldown).
	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)

	# Assert: timestamp unchanged (suppressed).
	assert_float(hss._alert_cue_last_fired_per_actor[actor]).is_equal(first_fired)


# ── AC-HSS-2.4: Different actor bypasses other actor's cooldown ─────────────

func test_different_actor_alert_passes_per_actor_gate() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	var g1: Node = Node.new()
	var g2: Node = Node.new()
	add_child(g1)
	add_child(g2)
	auto_free(g1)
	auto_free(g2)

	hss._on_alert_state_changed(
		g1,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	hss._on_alert_state_changed(
		g2,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)

	assert_bool(hss._alert_cue_last_fired_per_actor.has(g1)).is_true()
	assert_bool(hss._alert_cue_last_fired_per_actor.has(g2)).is_true()


# ── AC-HSS-2.5: Timer timeout clears state ──────────────────────────────────

func test_alert_cue_timer_timeout_clears_state() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)

	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.ALERT_CUE))

	# Simulate the timer timeout.
	hss._on_alert_cue_dismissed()

	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))
	assert_str(hss._current_text).is_equal("")


# ── AC-HSS-2.6: UNAWARE new_state never triggers ALERT_CUE ──────────────────

func test_unaware_new_state_never_triggers_alert_cue() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)

	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.AlertState.UNAWARE),  # downgrade — must NOT fire cue
		int(StealthAI.Severity.MINOR)
	)

	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))
	assert_bool(hss._alert_cue_last_fired_per_actor.has(actor)).is_false()


# ── AC-HSS-2.7: Freed actor refs are erased ──────────────────────────────────

func test_freed_actor_refs_are_erased_from_rate_gate_dicts() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	var g1: Node = Node.new()
	add_child(g1)

	hss._on_alert_state_changed(
		g1,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	assert_bool(hss._alert_cue_last_fired_per_actor.has(g1)).is_true()

	# Free g1 + emit a different actor's event to trigger _clean_freed_actor_refs.
	g1.free()
	var g2: Node = Node.new()
	add_child(g2)
	auto_free(g2)
	hss._on_alert_state_changed(
		g2,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)

	# Assert: g1's stale entry erased; g2's entry present.
	# We can't check `.has(g1)` directly (g1 freed). Instead, count keys.
	assert_int(hss._alert_cue_last_fired_per_actor.size()).is_equal(1)
	assert_bool(hss._alert_cue_last_fired_per_actor.has(g2)).is_true()


# ── AC-HSS-2.8: Upward severity bypasses cooldown ───────────────────────────

func test_upward_severity_bypasses_cooldown_and_re_fires_alert_cue() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)

	# First event: UNAWARE → SUSPICIOUS (last_state = SUSPICIOUS).
	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	var first_fired: float = hss._alert_cue_last_fired_per_actor[actor]

	# Immediately escalate to COMBAT (within cooldown, but UPWARD severity).
	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.AlertState.COMBAT),
		int(StealthAI.Severity.MAJOR)
	)

	# Assert: cooldown bypassed → timestamp updated; last_state advanced.
	assert_float(hss._alert_cue_last_fired_per_actor[actor]).is_greater_equal(first_fired)
	assert_int(int(hss._alert_cue_last_state_per_actor[actor])).is_equal(int(StealthAI.AlertState.COMBAT))


# ── AC-HSS-6.1: ui_context leave kills active state ─────────────────────────

func test_ui_context_leave_kills_alert_cue() -> void:
	var hss: Node = _spawn_hss()
	await get_tree().process_frame
	var actor: Node = Node.new()
	add_child(actor)
	auto_free(actor)

	hss._on_alert_state_changed(
		actor,
		int(StealthAI.AlertState.UNAWARE),
		int(StealthAI.AlertState.SUSPICIOUS),
		int(StealthAI.Severity.MINOR)
	)
	assert_bool(hss._alert_cue_timer.is_stopped()).is_false()

	# Leave gameplay.
	hss._on_ui_context_changed(int(InputContext.Context.MENU), int(InputContext.Context.GAMEPLAY))

	assert_bool(hss._alert_cue_timer.is_stopped()).is_true()
	assert_int(int(hss._current_state)).is_equal(int(hss.HSSState.HIDDEN))


# ── AC-HSS-8.2: HSS source has no _process / _physics_process ───────────────

func test_hss_source_has_no_process_or_physics_process() -> void:
	var f: FileAccess = FileAccess.open(_HSS_SCRIPT, FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	var pattern: RegEx = RegEx.new()
	pattern.compile("(?m)^func\\s+_(physics_)?process\\(")
	var m: RegExMatch = pattern.search(content)
	assert_object(m).override_failure_message(
		"FP-HSS-4: HSS must NOT define _process or _physics_process."
	).is_null()


# ── AC-HSS-5.3: HSS source has no accessibility_live = "assertive" ──────────

func test_hss_source_has_no_assertive_live_region() -> void:
	var f: FileAccess = FileAccess.open(_HSS_SCRIPT, FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	var pattern: RegEx = RegEx.new()
	pattern.compile("accessibility_live\\s*=\\s*\"assertive\"")
	var m: RegExMatch = pattern.search(content)
	assert_object(m).override_failure_message(
		"FP-HSS-5: HSS must use 'polite' AccessKit live region, not 'assertive'."
	).is_null()
