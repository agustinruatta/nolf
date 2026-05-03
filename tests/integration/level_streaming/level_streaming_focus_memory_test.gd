# tests/integration/level_streaming/level_streaming_focus_memory_test.gd
#
# LevelStreamingFocusMemoryTest — GdUnit4 integration suite for Story LS-006.
#
# Covers:
#   AC-8  NOTIFICATION_APPLICATION_FOCUS_IN while _transitioning == true and
#         _state == FADING_OUT snaps _fade_rect.color.a = 1.0; coroutine
#         resumes normally; final state IDLE.
#   AC-9  DEFERRED — pending Story LS-008 (stub plaza + stub_b scenes).
#         The test framework exists with the memory-invariant test stubbed out.
#         See TODO below.
#
# GATE STATUS
#   Story LS-006 | Integration type → BLOCKING gate.
#   TR-LS-014 (AC-8). AC-9 deferred (LS-008 dependency).
#
# ── AC-8 test design ─────────────────────────────────────────────────────────
# Godot's NOTIFICATION_APPLICATION_FOCUS_IN is dispatched by the engine when the
# OS window regains focus. In headless CI mode, OS-level focus events do not fire.
# We test the _notification handler directly by calling:
#   LevelStreamingService._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
# while a transition is in flight at a known intermediate state. This is the
# standard Godot pattern for testing notification handlers in integration tests
# (confirmed against GDD §QA Test Cases AC-8).
#
# The handler is:
#   func _notification(what: int) -> void:
#       if what == NOTIFICATION_APPLICATION_FOCUS_IN and _transitioning:
#           match _state:
#               FADING_OUT, SWAPPING → _fade_rect.color.a = 1.0
#               FADING_IN            → _fade_rect.color.a = 0.0
#               IDLE                 → _fade_rect.color.a = 0.0
#
# Test strategy for AC-8 FADING_OUT state:
#   1. Start a transition to a valid section (launches the FADING_OUT ramp).
#   2. On the FIRST frame-await (between alpha 0.0 and 0.5), the state is still
#      FADING_OUT and _transitioning == true, but alpha is at 0.5 (mid-ramp).
#   3. Manually call _notification(NOTIFICATION_APPLICATION_FOCUS_IN) from the
#      test to simulate focus regain at that partial-alpha moment.
#   4. Assert that _fade_rect.color.a == 1.0 immediately (snapped).
#   5. Let the coroutine continue to completion (IDLE).
#   6. Assert final state == IDLE, _transitioning == false.
#
# ── AC-9 dependency note ─────────────────────────────────────────────────────
# AC-9 requires stub plaza and stub_b scenes with controlled resource sizes
# to measure OS.get_static_memory_usage() deltas reliably. These scenes are
# produced by Story LS-008. Until LS-008 is complete, the test is a no-op stub
# that skips with a documented TODO. The integration test framework (file,
# class, before_test/after_test, helper) is fully in place.

class_name LevelStreamingFocusMemoryTest
extends GdUnitTestSuite


# ── Shared state ──────────────────────────────────────────────────────────────

## Signal-spy for section_entered.
var _entered_events: Array = []

## Signal-spy for section_exited.
var _exited_events: Array = []

## Whether signal spies are currently connected.
var _signals_connected: bool = false

## Helper: reference to the FadeRect ColorRect (cached once in before_test).
var _fade_rect: ColorRect = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	_entered_events.clear()
	_exited_events.clear()

	if not _signals_connected:
		Events.section_entered.connect(_on_section_entered)
		Events.section_exited.connect(_on_section_exited)
		_signals_connected = true

	# Cache FadeRect reference.
	_fade_rect = null
	var overlay: CanvasLayer = LevelStreamingService.get_fade_overlay()
	if overlay != null:
		_fade_rect = overlay.get_node_or_null("FadeRect") as ColorRect

	await _wait_for_idle(3.0)

	# LS-006 same-section guard normalization: ensure _current_section_id is
	# plaza (not stub_b) at the start of each test, so the test's
	# `transition_to_section(&"stub_b", FORWARD)` is not silently dropped.
	if LevelStreamingService.has_valid_registry():
		var current: StringName = LevelStreamingService.get_current_section_id()
		if current == &"stub_b":
			LevelStreamingService.transition_to_section(
				&"plaza", null, LevelStreamingService.TransitionReason.FORWARD
			)
			await _wait_for_idle(3.0)
		_entered_events.clear()
		_exited_events.clear()


func after_test() -> void:
	if _signals_connected:
		if Events.section_entered.is_connected(_on_section_entered):
			Events.section_entered.disconnect(_on_section_entered)
		if Events.section_exited.is_connected(_on_section_exited):
			Events.section_exited.disconnect(_on_section_exited)
		_signals_connected = false

	await _wait_for_idle(2.0)

	var current: Node = get_tree().current_scene
	if current != null and current.name in ["Plaza", "StubB"]:
		current.queue_free()
		await get_tree().process_frame


# ── Signal spies ──────────────────────────────────────────────────────────────

func _on_section_entered(section_id: StringName, reason: int) -> void:
	_entered_events.append({"section_id": section_id, "reason": reason})


func _on_section_exited(section_id: StringName, reason: int) -> void:
	_exited_events.append({"section_id": section_id, "reason": reason})


# ── AC-8: Focus regain snaps overlay alpha ────────────────────────────────────

## AC-8a: GIVEN a transition is in FADING_OUT with _fade_rect.color.a at an
## intermediate value (mid-ramp),
## WHEN _notification(NOTIFICATION_APPLICATION_FOCUS_IN) is called (focus regain),
## THEN _fade_rect.color.a is snapped to 1.0 immediately (FADING_OUT target alpha).
##
## After the snap, the coroutine resumes from its next await naturally (the
## SceneTree was not actually paused in this test context — we call _notification
## directly). Final state must be IDLE with _transitioning == false.
func test_focus_regain_during_fading_out_snaps_alpha_to_one() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	assert_object(_fade_rect).override_failure_message(
		"AC-8: FadeRect must be accessible via LevelStreamingService.get_fade_overlay()."
	).is_not_null()

	# Arrange: ensure we start from a known section so the transition launches.
	await _wait_for_idle(2.0)
	if LevelStreamingService.get_current_section_id() == &"":
		LevelStreamingService.transition_to_section(
			&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
		)
		await _wait_for_idle(3.0)

	_entered_events.clear()
	_exited_events.clear()

	# Act: start a transition. The FADING_OUT phase sets alpha 0→0.5 on first frame.
	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
	)

	# Confirm transition is in flight.
	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"AC-8: LSS must be transitioning immediately after transition_to_section."
	).is_true()

	# Wait exactly ONE frame — the coroutine has executed:
	#   _fade_rect.color.a = 0.0    (synchronous, pre-first-await)
	#   await get_tree().process_frame  ← we are here after one frame
	#   _fade_rect.color.a = 0.5    ← NOT yet executed; will execute next frame
	# So after one frame, alpha is 0.0 (reset at coroutine start) and state is FADING_OUT.
	await get_tree().process_frame

	# At this point the coroutine is suspended at its first await inside step 2.
	# State is FADING_OUT, _transitioning == true.
	assert_int(LevelStreamingService.get_state() as int).override_failure_message(
		"AC-8: after one frame, LSS must still be in FADING_OUT state."
	).is_equal(LevelStreamingService.State.FADING_OUT as int)

	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"AC-8: _transitioning must be true while coroutine is at first await."
	).is_true()

	# Simulate focus regain: set alpha to a mid-value first to confirm the snap works.
	_fade_rect.color.a = 0.5

	# Call _notification directly (standard headless notification-handler test pattern).
	LevelStreamingService._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	# Assert: snap to 1.0 because state is FADING_OUT.
	assert_float(_fade_rect.color.a).override_failure_message(
		"AC-8: focus regain during FADING_OUT must snap _fade_rect.color.a to 1.0. Got: %f"
		% _fade_rect.color.a
	).is_equal_approx(1.0, 0.001)

	# Let the coroutine complete normally.
	await _wait_for_idle(5.0)

	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"AC-8: coroutine must resume and reach IDLE after focus-regain snap."
	).is_false()

	assert_int(LevelStreamingService.get_state() as int).override_failure_message(
		"AC-8: final state must be IDLE after coroutine completes."
	).is_equal(LevelStreamingService.State.IDLE as int)


## AC-8b: GIVEN _state == SWAPPING and _transitioning == true,
## WHEN _notification(NOTIFICATION_APPLICATION_FOCUS_IN) is called,
## THEN _fade_rect.color.a is snapped to 1.0 (SWAPPING is included in the
## FADING_OUT branch — both are "transition-dark" states).
func test_focus_regain_during_swapping_snaps_alpha_to_one() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	assert_object(_fade_rect).override_failure_message(
		"AC-8b: FadeRect must be accessible."
	).is_not_null()

	await _wait_for_idle(2.0)
	if LevelStreamingService.get_current_section_id() == &"":
		LevelStreamingService.transition_to_section(
			&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
		)
		await _wait_for_idle(3.0)

	_entered_events.clear()

	# Start a transition and wait for SWAPPING state.
	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
	)

	# Poll until state reaches SWAPPING (after 2 frames of fade-out).
	var timeout: float = 5.0
	var elapsed: float = 0.0
	while elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if LevelStreamingService.get_state() == LevelStreamingService.State.SWAPPING:
			break

	assert_int(LevelStreamingService.get_state() as int).override_failure_message(
		"AC-8b: must reach SWAPPING state before testing notification handler."
	).is_equal(LevelStreamingService.State.SWAPPING as int)

	# Set alpha to an intermediate value, then simulate focus regain.
	_fade_rect.color.a = 0.7
	LevelStreamingService._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	# SWAPPING state → snap to 1.0.
	assert_float(_fade_rect.color.a).override_failure_message(
		"AC-8b: focus regain during SWAPPING must snap alpha to 1.0. Got: %f" % _fade_rect.color.a
	).is_equal_approx(1.0, 0.001)

	await _wait_for_idle(5.0)

	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"AC-8b: coroutine must complete after focus-regain snap during SWAPPING."
	).is_false()


## AC-8c: GIVEN _transitioning == false (IDLE state),
## WHEN _notification(NOTIFICATION_APPLICATION_FOCUS_IN) is called,
## THEN _fade_rect.color.a is NOT modified (guard: `if not _transitioning: return`).
func test_focus_regain_during_idle_does_not_modify_alpha() -> void:
	assert_object(_fade_rect).override_failure_message(
		"AC-8c: FadeRect must be accessible."
	).is_not_null()

	await _wait_for_idle(2.0)

	# Ensure IDLE state.
	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"AC-8c: LSS must be IDLE before testing IDLE notification path."
	).is_false()

	# Set alpha to a known value.
	_fade_rect.color.a = 0.0

	# Call notification with _transitioning == false.
	LevelStreamingService._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	# Alpha must be unchanged (0.0).
	assert_float(_fade_rect.color.a).override_failure_message(
		"AC-8c: focus regain during IDLE must not modify fade alpha. Got: %f" % _fade_rect.color.a
	).is_equal_approx(0.0, 0.001)


## AC-8d: GIVEN _state == FADING_IN and _transitioning == true,
## WHEN _notification(NOTIFICATION_APPLICATION_FOCUS_IN) is called,
## THEN _fade_rect.color.a is snapped to 0.0 (the FADING_IN target: transparent).
## The coroutine will immediately overwrite this value as the fade-in ramp
## resumes, so the net effect is a seamless continuation.
func test_focus_regain_during_fading_in_snaps_alpha_to_zero() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	assert_object(_fade_rect).override_failure_message(
		"AC-8d: FadeRect must be accessible."
	).is_not_null()

	await _wait_for_idle(2.0)
	if LevelStreamingService.get_current_section_id() == &"":
		LevelStreamingService.transition_to_section(
			&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
		)
		await _wait_for_idle(3.0)

	_entered_events.clear()

	# Start a transition and wait for FADING_IN state.
	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
	)

	var timeout: float = 5.0
	var elapsed: float = 0.0
	while elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if LevelStreamingService.get_state() == LevelStreamingService.State.FADING_IN:
			break

	assert_int(LevelStreamingService.get_state() as int).override_failure_message(
		"AC-8d: must reach FADING_IN state before testing notification handler."
	).is_equal(LevelStreamingService.State.FADING_IN as int)

	# Set alpha to 1.0 (start of fade-in ramp), then simulate focus regain.
	_fade_rect.color.a = 1.0
	LevelStreamingService._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	# FADING_IN → snap to 0.0.
	assert_float(_fade_rect.color.a).override_failure_message(
		"AC-8d: focus regain during FADING_IN must snap alpha to 0.0. Got: %f" % _fade_rect.color.a
	).is_equal_approx(0.0, 0.001)

	await _wait_for_idle(3.0)

	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"AC-8d: coroutine must complete after focus-regain snap during FADING_IN."
	).is_false()


# ── AC-9: Memory invariant — DEFERRED pending Story LS-008 ───────────────────

## AC-9: OS.get_static_memory_usage() peak after second plaza transition ≤110%
## of peak after first plaza transition (plaza → stub_b → plaza round-trip).
##
## TODO: LS-008 dependency — stub plaza + stub_b scenes required.
## This test requires Story LS-008's controlled-size stub scenes. The stub scenes
## provide a deterministic memory baseline (approx. 30 nodes, ~1-2 MB) so that
## OS.get_static_memory_usage() deltas are meaningful. Without LS-008:
##   - The real plaza.tscn scene size is undefined at this story boundary.
##   - Memory measurement with the full scene would be unreliable and
##     non-deterministic across CI runs.
##   - The 10% headroom assertion could produce false failures or false passes.
##
## When LS-008 is complete:
##   1. Remove the "return" stub below.
##   2. Replace the transition target IDs with the LS-008 stub scene IDs.
##   3. Verify the test passes with real stub scenes.
##   4. Update this docstring to remove the DEFERRED note.
##
## AC-9. AC-LS-6.3. Story LS-006 (deferred), Story LS-008 (implements stubs).
func test_no_unbounded_memory_growth_round_trip_plaza_stub_b_plaza() -> void:
	# TODO: LS-008 dependency — remove this stub return when stub scenes exist.
	# stub plaza and stub_b scenes from Story LS-008 are required for reliable
	# memory delta measurements. Until then, this test is a documented no-op.
	push_warning(
		"[AC-9] test_no_unbounded_memory_growth is DEFERRED pending Story LS-008 stub scenes. Skipping."
	)
	return

	# ── Implementation (active after LS-008) ─────────────────────────────────
	# The code below will be activated when LS-008 delivers stub scenes.
	# It is left in place (after the early return) as an implementation skeleton
	# so LS-008 implementors have a complete template to work from.

	# Ensure registry is valid.
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	# ── First round: arrive at plaza (cold load baseline) ───────────────────
	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	var baseline_peak: int = OS.get_static_memory_usage()

	# ── Transition to stub_b ─────────────────────────────────────────────────
	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
	)
	await _wait_for_idle(3.0)

	# ── Second transition to plaza (cached) ──────────────────────────────────
	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.FORWARD
	)
	await _wait_for_idle(3.0)

	var second_peak: int = OS.get_static_memory_usage()

	# Log for CI diagnostics.
	push_warning(
		"[AC-9] Memory — baseline after first plaza: %d bytes; second plaza: %d bytes; ratio: %.3f"
		% [baseline_peak, second_peak, float(second_peak) / float(baseline_peak)]
	)

	# AC-9 assertion: peak after second plaza ≤ 110% of baseline.
	# CI tolerance per story: 10% headroom for misc. allocations.
	var limit: int = int(float(baseline_peak) * 1.1)
	assert_int(second_peak).override_failure_message(
		"AC-9: peak memory after second plaza (%d bytes) must be ≤110%% of first plaza (%d bytes). Limit: %d bytes."
		% [second_peak, baseline_peak, limit]
	).is_less_equal(limit)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Polls the SceneTree until LSS reaches IDLE (or timeout elapses).
func _wait_for_idle(timeout_sec: float) -> void:
	var elapsed: float = 0.0
	while LevelStreamingService.is_transitioning() and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
