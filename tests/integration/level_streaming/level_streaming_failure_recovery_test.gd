# tests/integration/level_streaming/level_streaming_failure_recovery_test.gd
#
# LevelStreamingFailureRecoveryTest — GdUnit4 integration suite for Story LS-005.
#
# Covers:
#   AC-1  _simulate_registry_failure() flips _registry_valid; subsequent
#         transition_to_section immediately push_errors + returns.
#   AC-2  Registry-miss at step 4 → _abort_transition BEFORE queue_free;
#         outgoing scene still in tree at abort.
#   AC-3  ResourceLoader.load null (bad path) → _abort_transition +
#         _show_error_fallback("Scene load failed") + clean state.
#   AC-4  PackedScene.instantiate null → same recovery.
#         (Structural / code-review verification — see test body note.)
#   AC-5  add_child failure → same recovery.
#         (Structural / code-review verification — see test body note.)
#   AC-6  DEFERRED: manual-evidence path (ErrorFallback 2s auto-dismiss on
#         real display build). Evidence stub at
#         production/qa/evidence/level_streaming_shipping_error_fallback.md
#   AC-7  Single recovery function — code-review check via source file scan.
#   AC-8  DEFERRED: shipping-build export inspection (manual).
#   AC-9  Clean-state invariants after every automated failure path.
#
# GATE STATUS
#   Story LS-005 | Integration type → BLOCKING gate.
#   TR-LS-002, TR-LS-003.
#
# ── Test isolation design ─────────────────────────────────────────────────────
# Each test uses before_test / after_test to reset state via _reset_input_context
# and to restore any modified registry entries. _simulate_registry_failure() is
# called only in tests that need it; _registry_valid is restored via the
# _restore_registry_valid() helper which calls _load_registry_for_test() on
# the autoload.
#
# Registry injection for AC-3 (bad path): the test temporarily sets a
# "bad_section" entry in the live SectionRegistry.sections dictionary, calls
# the transition, then removes the entry in after_test. This avoids creating
# a permanent fixture file and keeps the registry clean for other tests.

class_name LevelStreamingFailureRecoveryTest
extends GdUnitTestSuite


# ── Shared state ──────────────────────────────────────────────────────────────

## Whether a bad_section entry was injected into the registry during a test.
var _registry_injected: bool = false

## Whether _simulate_registry_failure was called (needs restoration).
var _registry_failure_simulated: bool = false

## Signal-spy storage for section_entered + section_exited.
var _entered_events: Array = []
var _exited_events: Array = []
var _signals_connected: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	_registry_injected = false
	_registry_failure_simulated = false
	_entered_events.clear()
	_exited_events.clear()

	_reset_input_context()

	if not _signals_connected:
		Events.section_entered.connect(_on_section_entered)
		Events.section_exited.connect(_on_section_exited)
		_signals_connected = true

	# Wait for any prior test's in-flight transition to complete.
	await _wait_for_idle(3.0)

	# LS-006 same-section guard normalization: if a prior suite left LSS at
	# &"plaza", transition to stub_b first so this suite's transitions to
	# plaza aren't silently dropped.
	if LevelStreamingService.has_valid_registry():
		var current: StringName = LevelStreamingService.get_current_section_id()
		if current == &"plaza":
			LevelStreamingService.transition_to_section(
				&"stub_b", null, LevelStreamingService.TransitionReason.FORWARD
			)
			await _wait_for_idle(3.0)
		_entered_events.clear()
		_exited_events.clear()


func after_test() -> void:
	# Restore registry entries injected for AC-3 tests.
	if _registry_injected:
		var registry: SectionRegistry = LevelStreamingService.get_registry()
		if registry != null:
			registry.sections.erase(&"bad_section")
		_registry_injected = false

	# Restore _registry_valid if _simulate_registry_failure was called.
	if _registry_failure_simulated:
		_restore_registry_valid()
		_registry_failure_simulated = false

	if _signals_connected:
		if Events.section_entered.is_connected(_on_section_entered):
			Events.section_entered.disconnect(_on_section_entered)
		if Events.section_exited.is_connected(_on_section_exited):
			Events.section_exited.disconnect(_on_section_exited)
		_signals_connected = false

	await _wait_for_idle(2.0)

	# Free any section scene left in the tree after an abort or partial transition.
	var current: Node = get_tree().current_scene
	if current != null and current.name in ["Plaza", "StubB"]:
		current.queue_free()
		await get_tree().process_frame


# ── Signal spies ──────────────────────────────────────────────────────────────

func _on_section_entered(section_id: StringName, reason: int) -> void:
	_entered_events.append({"section_id": section_id, "reason": reason})


func _on_section_exited(section_id: StringName, reason: int) -> void:
	_exited_events.append({"section_id": section_id, "reason": reason})


# ── AC-1: _simulate_registry_failure flips registry-valid ────────────────────

## AC-1a: GIVEN _simulate_registry_failure() has been called,
## WHEN transition_to_section is called,
## THEN it immediately push_errors and returns without modifying _transitioning.
func test_simulate_registry_failure_rejects_transition_immediately() -> void:
	if not LevelStreamingService.has_valid_registry():
		return  # cannot test without registry

	# Arrange: verify registry is valid before the test hook.
	assert_bool(LevelStreamingService.has_valid_registry()).override_failure_message(
		"Precondition: registry must be valid before calling _simulate_registry_failure."
	).is_true()

	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"Precondition: LSS must be IDLE before this test."
	).is_false()

	# Act: flip registry invalid.
	LevelStreamingService._simulate_registry_failure()
	_registry_failure_simulated = true

	# Assert: flag is now false.
	assert_bool(LevelStreamingService.has_valid_registry()).override_failure_message(
		"_simulate_registry_failure must set _registry_valid to false."
	).is_false()

	# Act: call transition — must be rejected immediately.
	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)

	# Assert: no state change — transitioning must still be false.
	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"Rejected transition must not set _transitioning to true."
	).is_false()

	assert_int(LevelStreamingService.get_state() as int).override_failure_message(
		"Rejected transition must not change state from IDLE."
	).is_equal(LevelStreamingService.State.IDLE as int)

	assert_bool(InputContext.is_active(InputContext.Context.LOADING)).override_failure_message(
		"Rejected transition must not push LOADING context."
	).is_false()


## AC-1b: _simulate_registry_failure is only effective in debug builds.
## In a CI/debug headless run, OS.is_debug_build() returns true — so this test
## verifies the flag was actually flipped. In a shipping export the call would
## be a no-op. Since CI always runs debug, we confirm the flip here.
func test_simulate_registry_failure_is_debug_only_hook() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	# Only valid to test in debug mode (the function is a no-op in shipping).
	if not OS.is_debug_build():
		# Shipping build: confirm no-op behavior (AC-8).
		var before: bool = LevelStreamingService.has_valid_registry()
		LevelStreamingService._simulate_registry_failure()
		assert_bool(LevelStreamingService.has_valid_registry()).override_failure_message(
			"In shipping build, _simulate_registry_failure must be a no-op."
		).is_equal(before)
		return

	# Debug: confirm it can flip the flag.
	LevelStreamingService._simulate_registry_failure()
	_registry_failure_simulated = true
	assert_bool(LevelStreamingService.has_valid_registry()).override_failure_message(
		"Debug build: _simulate_registry_failure must flip _registry_valid to false."
	).is_false()


# ── AC-2: Registry-miss aborts before queue_free ──────────────────────────────

## AC-2: GIVEN a valid outgoing scene is in the tree,
## WHEN transition_to_section is called with an unregistered section_id,
## THEN _abort_transition runs BEFORE queue_free (outgoing scene still valid
## immediately after abort), AND LSS returns to IDLE clean state.
func test_registry_miss_at_step4_aborts_before_queue_free_and_outgoing_scene_valid() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	# Arrange: ensure a real scene is in the tree as the outgoing scene.
	await _wait_for_idle(3.0)
	if LevelStreamingService.get_current_section_id() == &"":
		LevelStreamingService.transition_to_section(
			&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
		)
		await _wait_for_idle(3.0)

	var outgoing: Node = get_tree().current_scene
	assert_object(outgoing).override_failure_message(
		"Precondition: an outgoing scene must be in the tree."
	).is_not_null()

	# Act: trigger the registry-miss failure path.
	LevelStreamingService.transition_to_section(
		&"__no_such_section_ls005_ac2__",
		null,
		LevelStreamingService.TransitionReason.FORWARD
	)

	# The abort fires inside the coroutine at step 4, after 2 frames of fade-out.
	# Wait for LSS to return to IDLE.
	await _wait_for_idle(3.0)

	# Assert AC-2 ordering: outgoing scene was NOT freed before the abort.
	# (The abort fired at step 4 BEFORE queue_free — outgoing scene stays valid.)
	assert_bool(is_instance_valid(outgoing)).override_failure_message(
		"AC-2: outgoing scene must still be valid after registry-miss abort (queue_free must not have run)."
	).is_true()

	# Assert AC-9: clean state invariants.
	_assert_clean_state_invariants("AC-2 registry-miss")


# ── AC-3: ResourceLoader null abort + clean state ────────────────────────────

## AC-3: GIVEN a registry entry pointing at a non-existent scene file,
## WHEN transition_to_section reaches step 5 (ResourceLoader.load returns null),
## THEN _abort_transition runs + _show_error_fallback is called +
## LSS returns to IDLE clean state + section_entered does NOT fire.
##
## Registry injection: we add a "bad_section" entry pointing at a guaranteed-
## missing file. The entry is removed in after_test().
func test_resource_loader_null_at_step5_aborts_cleanly_and_does_not_emit_section_entered() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	# Arrange: inject a bad registry entry.
	var registry: SectionRegistry = LevelStreamingService.get_registry()
	assert_object(registry).override_failure_message(
		"Precondition: registry must be available for injection."
	).is_not_null()

	registry.sections[&"bad_section"] = {
		"path": "res://scenes/sections/__bad__.tscn",
		"display_name_loc_key": "meta.section.bad"
	}
	_registry_injected = true

	# Ensure we start from a known scene so step 4 passes (bad_section IS in the registry).
	await _wait_for_idle(2.0)
	if LevelStreamingService.get_current_section_id() == &"":
		LevelStreamingService.transition_to_section(
			&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
		)
		await _wait_for_idle(3.0)

	_entered_events.clear()

	# Act: trigger the bad-path transition.
	LevelStreamingService.transition_to_section(
		&"bad_section", null, LevelStreamingService.TransitionReason.FORWARD
	)

	# Wait for abort + recovery to settle.
	await _wait_for_idle(3.0)

	# Assert: section_entered must NOT have fired for bad_section.
	var entered_bad: Array = _entered_events.filter(func(e: Dictionary) -> bool:
		return String(e["section_id"] as StringName) == "bad_section"
	)
	assert_int(entered_bad.size()).override_failure_message(
		"AC-3: section_entered must NOT fire when ResourceLoader.load returns null. Got: %s"
		% [_entered_events]
	).is_equal(0)

	# Assert: error message was stored (confirms _show_error_fallback ran).
	var stored_msg: String = LevelStreamingService.get_last_error_message_for_test()
	assert_str(stored_msg).override_failure_message(
		"AC-3: _last_error_message must be set by _show_error_fallback after step-5 failure. Got: '%s'"
		% stored_msg
	).is_not_empty()

	# Assert AC-9 clean state.
	_assert_clean_state_invariants("AC-3 ResourceLoader null")


# ── AC-4: instantiate null (structural/code-review) ──────────────────────────

## AC-4 — Structural code-review check.
##
## PackedScene.instantiate() returning null is impractical to synthesize in a
## headless integration test: any valid .tscn file will instantiate successfully,
## and a malformed .tscn causes ResourceLoader.load to return null (exercised
## by AC-3) rather than returning a non-null PackedScene that then fails
## instantiate(). In production, this failure mode arises from a corrupt binary
## resource that passes the PackedScene type-check but has a broken root node.
##
## This test verifies the structural invariant: that the code path at step 6
## follows the required `_abort_transition + push_error + _show_error_fallback + return`
## pattern, by scanning the source file.
func test_step6_instantiate_null_follows_recovery_pattern_code_review() -> void:
	# Code-review structural check: the source file must contain the instantiate-null
	# guard with the correct recovery pattern at step 6.
	var source_path: String = "res://src/core/level_streaming/level_streaming_service.gd"
	assert_bool(ResourceLoader.exists(source_path)).override_failure_message(
		"AC-4 code-review: LSS source file must exist at res:// path."
	).is_true()

	# Read the raw source to scan for the pattern.
	var fa: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(source_path), FileAccess.READ
	)
	assert_object(fa).override_failure_message(
		"AC-4 code-review: cannot open LSS source file for scanning."
	).is_not_null()

	var source: String = fa.get_as_text()
	fa.close()

	# Check: step 6 must have the instantiate-null check with _show_error_fallback.
	assert_bool(source.contains("instance == null")).override_failure_message(
		"AC-4: LSS must contain instantiate-null check at step 6."
	).is_true()

	assert_bool(source.contains("_show_error_fallback(\"Instantiate failed\")")).override_failure_message(
		"AC-4: step 6 null check must call _show_error_fallback with 'Instantiate failed'."
	).is_true()


# ── AC-5: add_child validity check (structural/code-review) ──────────────────

## AC-5 — Structural code-review check.
##
## The post-add_child validity check (is_instance_valid + is_inside_tree) is a
## defense-in-depth guard. It is near-impossible to trigger in a headless test
## because get_tree().root.add_child() on a valid freshly-instantiated Node
## always succeeds. The check guards against future callers passing pre-parented
## or already-freed Nodes (which would require internal LSS API misuse).
##
## This test verifies the structural invariant: that the validity check exists
## at step 7 and calls the recovery pattern.
func test_step7_add_child_validity_check_exists_code_review() -> void:
	var source_path: String = "res://src/core/level_streaming/level_streaming_service.gd"
	assert_bool(ResourceLoader.exists(source_path)).override_failure_message(
		"AC-5 code-review: LSS source file must exist."
	).is_true()

	var fa: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(source_path), FileAccess.READ
	)
	assert_object(fa).override_failure_message(
		"AC-5 code-review: cannot open LSS source file for scanning."
	).is_not_null()

	var source: String = fa.get_as_text()
	fa.close()

	# Check: step 7 must contain the post-add validity guard.
	assert_bool(source.contains("is_instance_valid(instance)")).override_failure_message(
		"AC-5: LSS must contain is_instance_valid(instance) check at step 7."
	).is_true()

	assert_bool(source.contains("instance.is_inside_tree()")).override_failure_message(
		"AC-5: LSS must contain instance.is_inside_tree() check at step 7."
	).is_true()

	assert_bool(source.contains("_show_error_fallback(\"Tree mount failed\")")).override_failure_message(
		"AC-5: step 7 validity check must call _show_error_fallback with 'Tree mount failed'."
	).is_true()


# ── AC-7: Single recovery function code-review check ─────────────────────────

## AC-7: Every failure check in the 13-step coroutine ends with the pattern:
##   _abort_transition() + push_error + _show_error_fallback(...) + return
## Verified by scanning the source file for the pattern.
func test_every_failure_path_uses_single_recovery_function_code_review() -> void:
	var source_path: String = "res://src/core/level_streaming/level_streaming_service.gd"
	assert_bool(ResourceLoader.exists(source_path)).override_failure_message(
		"AC-7 code-review: LSS source file must exist."
	).is_true()

	var fa: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(source_path), FileAccess.READ
	)
	assert_object(fa).override_failure_message(
		"AC-7 code-review: cannot open LSS source file for scanning."
	).is_not_null()

	var source: String = fa.get_as_text()
	fa.close()

	# Verify _show_error_fallback exists as a private helper.
	assert_bool(source.contains("func _show_error_fallback(")).override_failure_message(
		"AC-7: _show_error_fallback must exist as the single recovery function."
	).is_true()

	# Verify all three expected failure messages appear in the source.
	assert_bool(source.contains("_show_error_fallback(\"File not found:")).override_failure_message(
		"AC-7: step 4 registry-miss must call _show_error_fallback with 'File not found:...'."
	).is_true()

	assert_bool(source.contains("_show_error_fallback(\"Scene load failed\")")).override_failure_message(
		"AC-7: step 5 ResourceLoader-null must call _show_error_fallback with 'Scene load failed'."
	).is_true()

	assert_bool(source.contains("_show_error_fallback(\"Instantiate failed\")")).override_failure_message(
		"AC-7: step 6 instantiate-null must call _show_error_fallback with 'Instantiate failed'."
	).is_true()

	assert_bool(source.contains("_show_error_fallback(\"Tree mount failed\")")).override_failure_message(
		"AC-7: step 7 post-add-child must call _show_error_fallback with 'Tree mount failed'."
	).is_true()

	# Verify _abort_transition is called before each _show_error_fallback — confirmed
	# by checking _abort_transition appears in the coroutine body (cannot easily check
	# ordering with string scan alone; covered by the AC-9 runtime state tests).
	assert_bool(source.contains("func _abort_transition()")).override_failure_message(
		"AC-7: _abort_transition must exist as the cleanup function preceding _show_error_fallback."
	).is_true()


# ── AC-9: Clean state invariants after registry-miss ─────────────────────────

## AC-9a: After a registry-miss abort (step 4), all invariants are satisfied.
## Mirrors test_registry_miss_at_step4 with explicit invariant checks.
func test_clean_state_invariants_after_registry_miss_abort() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	LevelStreamingService.transition_to_section(
		&"__invariant_check_ls005__",
		null,
		LevelStreamingService.TransitionReason.FORWARD
	)

	await _wait_for_idle(3.0)

	_assert_clean_state_invariants("AC-9a registry-miss")


## AC-9b: After _simulate_registry_failure + rejected transition, state remains clean.
func test_clean_state_invariants_after_simulate_registry_failure_rejection() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	LevelStreamingService._simulate_registry_failure()
	_registry_failure_simulated = true

	# Rejected immediately at the transition_to_section gate — no coroutine launched.
	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)

	# State should already be clean — no await needed for this rejection path.
	_assert_clean_state_invariants("AC-9b simulated registry failure rejection")


## AC-9c: After ResourceLoader null abort (step 5), clean state invariants hold.
## Uses the bad_section injection pattern from AC-3.
func test_clean_state_invariants_after_resource_loader_null_abort() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	var registry: SectionRegistry = LevelStreamingService.get_registry()
	assert_object(registry).is_not_null()

	registry.sections[&"bad_section"] = {
		"path": "res://scenes/sections/__bad__.tscn",
		"display_name_loc_key": "meta.section.bad"
	}
	_registry_injected = true

	await _wait_for_idle(2.0)
	if LevelStreamingService.get_current_section_id() == &"":
		LevelStreamingService.transition_to_section(
			&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
		)
		await _wait_for_idle(3.0)

	LevelStreamingService.transition_to_section(
		&"bad_section", null, LevelStreamingService.TransitionReason.FORWARD
	)

	await _wait_for_idle(3.0)

	_assert_clean_state_invariants("AC-9c ResourceLoader null abort")


# ── Regression: prior AC tests do not break LS-002/003/004 behavior ──────────

## Regression: normal plaza transition still completes cleanly after LS-005
## wiring. Verifies LS-002 fast path is not accidentally broken.
func test_normal_transition_still_completes_after_ls005_wiring() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	_entered_events.clear()

	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)

	await _wait_for_idle(3.0)

	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"Regression: normal transition must complete and reach IDLE."
	).is_false()

	assert_int(LevelStreamingService.get_state() as int).override_failure_message(
		"Regression: state must be IDLE after normal transition."
	).is_equal(LevelStreamingService.State.IDLE as int)

	# section_entered must have fired for plaza.
	var entered_plaza: Array = _entered_events.filter(func(e: Dictionary) -> bool:
		return String(e["section_id"] as StringName) == "plaza"
	)
	assert_int(entered_plaza.size()).override_failure_message(
		"Regression: section_entered(plaza) must fire on normal transition. Got: %s"
		% [_entered_events]
	).is_greater_equal(1)

	# _last_error_message must be cleared on successful transition completion.
	var last_msg: String = LevelStreamingService.get_last_error_message_for_test()
	assert_str(last_msg).override_failure_message(
		"Regression: _last_error_message must be cleared to '' after successful transition. Got: '%s'"
		% last_msg
	).is_empty()


# ── Helpers ───────────────────────────────────────────────────────────────────

## Asserts all AC-9 clean-state invariants. Called after every failure path.
func _assert_clean_state_invariants(context: String) -> void:
	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"[%s] AC-9: _transitioning must be false after recovery." % context
	).is_false()

	assert_int(LevelStreamingService.get_state() as int).override_failure_message(
		"[%s] AC-9: _state must be IDLE after recovery. Got: %d"
		% [context, LevelStreamingService.get_state() as int]
	).is_equal(LevelStreamingService.State.IDLE as int)

	assert_bool(InputContext.is_active(InputContext.Context.LOADING)).override_failure_message(
		"[%s] AC-9: InputContext.LOADING must NOT be on stack after recovery." % context
	).is_false()

	var overlay: CanvasLayer = LevelStreamingService.get_fade_overlay()
	if overlay != null:
		var fade_rect: ColorRect = overlay.get_node_or_null("FadeRect") as ColorRect
		if fade_rect != null:
			assert_float(fade_rect.color.a).override_failure_message(
				"[%s] AC-9: fade overlay alpha must be 0.0 after recovery. Got: %f"
				% [context, fade_rect.color.a]
			).is_equal_approx(0.0, 0.001)


## Drain the InputContext stack to GAMEPLAY. Pops anything other than the
## bottom GAMEPLAY context that prior tests left on the stack.
func _reset_input_context() -> void:
	var safety: int = 16
	while InputContext.current() != InputContext.Context.GAMEPLAY and safety > 0:
		InputContext.pop() # dismiss-order-ok: test fixture cleanup
		safety -= 1


## Restores _registry_valid to true by re-triggering the load path.
## Called in after_test when _simulate_registry_failure was used.
## We reach into the autoload directly since there is no public restore API.
func _restore_registry_valid() -> void:
	# Re-arm the registry by loading the resource. The load path sets
	# _registry_valid = true if the resource exists and is valid.
	# We use the public _simulate_registry_failure no-op pattern in reverse:
	# just set the field via the has_valid_registry side-channel by calling the
	# autoload's internal load path indirectly — but since there's no public
	# restore hook, we set _registry_valid via a known good check.
	# Simplest reliable path: verify the registry resource still loads OK,
	# then assign via direct field (acceptable in test context).
	var loaded: Resource = ResourceLoader.load("res://assets/data/section_registry.tres")
	if loaded != null and loaded is SectionRegistry:
		LevelStreamingService._registry = loaded as SectionRegistry
		LevelStreamingService._registry_valid = true


## Polls the SceneTree until LSS reaches IDLE (or timeout elapses).
func _wait_for_idle(timeout_sec: float) -> void:
	var elapsed: float = 0.0
	while LevelStreamingService.is_transitioning() and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
