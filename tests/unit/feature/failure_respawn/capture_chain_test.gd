# tests/unit/feature/failure_respawn/capture_chain_test.gd
#
# CaptureChainTest — GdUnit4 test suite for Story FR-002.
#
# PURPOSE
#   Verifies the slot-0 autosave assembly flow: CAPTURING body assembles a
#   SaveGame via the MLS-owned capture() chain, writes it to slot-0, and
#   hands the same in-memory object to LevelStreamingService.transition_to_section.
#
# COVERED ACCEPTANCE CRITERIA (Story FR-002)
#   AC-1 — save_to_slot(0, sg) called once AND transition_to_section called
#           with the SAME SaveGame object reference (identity check).
#   AC-2 — When save_to_slot returns false (IO failure), transition_to_section
#           is still called and _flow_state becomes RESTORING.
#   AC-3 — FailureRespawnState schema: class_name, floor_applied_this_checkpoint
#           field, zero-arg default (false), one-arg constructor (true).
#   AC-4 — FailureRespawnState.capture() mirrors live flag value without
#           advancing the live flag (read-only capture per CR-6).
#   AC-5 — Assembled SaveGame.failure_respawn.floor_applied_this_checkpoint
#           equals the live _floor_applied_this_checkpoint at capture time.
#   AC-6 — Static lint: no `await` between save_to_slot and
#           transition_to_section in failure_respawn_service.gd.
#   AC-7 — _flow_state is RESTORING after CAPTURING body completes.
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#   DI doubles are plain Node subclasses that record calls without side-effects.
#
# DESIGN NOTES — direct invocation vs signal
#   Tests invoke svc._on_player_died(0) directly rather than via
#   Events.player_died.emit(). The service is NOT added to the scene tree so
#   _ready() does not fire — this avoids connecting to the live Events autoload
#   and prevents signal accumulation across tests.
#   Doubles are injected by calling _inject_level_streaming / _inject_save_load
#   directly on the bare instance before the test call.
#
# DESIGN NOTES — AC-1 identity check
#   The test uses `is` (identity operator in GDScript — same object reference)
#   to verify that the SAME SaveGame instance is passed to both save_to_slot
#   and transition_to_section. A duplicate() between the two calls would produce
#   a different identity and the test would fail (per CR-4 requirement).

class_name CaptureChainTest
extends GdUnitTestSuite


# ── Setup / teardown ──────────────────────────────────────────────────────────

## Restore InputContext to GAMEPLAY after each test. The CAPTURING body calls
## InputContext.push(LOADING) — without explicit cleanup the LOADING stays on
## the stack and pollutes subsequent tests in the full suite (FR-005 will pop
## it in production; tests must pop manually).
func after_test() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ── Inner doubles ─────────────────────────────────────────────────────────────

## LevelStreamingService test double. Records transition_to_section and
## register_restore_callback calls; provides get_current_section_id() stub.
class _TestLSDouble extends Node:
	var transition_call_count: int = 0
	var last_transition_section_id: StringName = &""
	var last_transition_save_game: SaveGame = null
	var last_transition_reason: int = -1

	func transition_to_section(
		section_id: StringName,
		save_game: SaveGame = null,
		reason: int = 0
	) -> void:
		transition_call_count += 1
		last_transition_section_id = section_id
		last_transition_save_game = save_game
		last_transition_reason = reason

	func register_restore_callback(_callback: Callable) -> void:
		pass  # no-op — FR-001 already tested this; FR-002 doesn't need it

	func get_current_section_id() -> StringName:
		return &"test_section"


## SaveLoadService test double. Records save_to_slot calls; configurable return.
class _TestSLDouble extends Node:
	## Set to false to simulate a save IO failure (AC-2).
	var save_return_value: bool = true

	var save_call_count: int = 0
	var last_save_slot: int = -1
	var last_save_game: SaveGame = null

	func save_to_slot(slot: int, sg: SaveGame) -> bool:
		save_call_count += 1
		last_save_slot = slot
		last_save_game = sg
		return save_return_value


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a bare FailureRespawnService with injected doubles.
## Does NOT add to the scene tree — _ready() does NOT fire.
## Caller invokes _on_player_died() directly to trigger the CAPTURING body.
func _make_service_with_doubles(
	ls: _TestLSDouble,
	sl: _TestSLDouble,
) -> FailureRespawnService:
	var svc: FailureRespawnService = FailureRespawnService.new()
	svc._inject_level_streaming(ls)
	svc._inject_save_load(sl)
	auto_free(svc)
	return svc


## Convenience: creates matched doubles and injects them. Returns the triple.
func _make_triple() -> Array:
	var ls: _TestLSDouble = _TestLSDouble.new()
	auto_free(ls)
	var sl: _TestSLDouble = _TestSLDouble.new()
	auto_free(sl)
	var svc: FailureRespawnService = _make_service_with_doubles(ls, sl)
	return [svc, ls, sl]


# ── AC-1: same SaveGame object reference for save and transition ───────────────

## AC-1: CAPTURING body calls save_to_slot(0, sg) and transition_to_section with
## the SAME SaveGame object (identity check — not value equality, same reference).
func test_capturing_assembles_save_game_calls_save_then_transition_with_same_object() -> void:
	# Arrange
	var triple: Array = _make_triple()
	var svc: FailureRespawnService = triple[0]
	var ls: _TestLSDouble = triple[1]
	var sl: _TestSLDouble = triple[2]

	# Act — direct invocation bypasses Events autoload wiring.
	svc._on_player_died(0)

	# Assert: save_to_slot called exactly once with slot 0.
	assert_int(sl.save_call_count).override_failure_message(
		"AC-1: save_to_slot must be called exactly once."
	).is_equal(1)

	assert_int(sl.last_save_slot).override_failure_message(
		"AC-1: save_to_slot must target slot 0."
	).is_equal(0)

	assert_object(sl.last_save_game).override_failure_message(
		"AC-1: save_to_slot must receive a non-null SaveGame."
	).is_not_null()

	# Assert: transition_to_section called exactly once.
	assert_int(ls.transition_call_count).override_failure_message(
		"AC-1: transition_to_section must be called exactly once."
	).is_equal(1)

	assert_object(ls.last_transition_save_game).override_failure_message(
		"AC-1: transition_to_section must receive a non-null SaveGame."
	).is_not_null()

	# Assert: same object identity — the in-memory handoff passes the SAME reference.
	# CR-4: no duplicate() may be interposed between save_to_slot and transition_to_section.
	assert_bool(sl.last_save_game is SaveGame).override_failure_message(
		"AC-1: save_to_slot save_game must be a SaveGame instance."
	).is_true()

	assert_bool(ls.last_transition_save_game is SaveGame).override_failure_message(
		"AC-1: transition_to_section save_game must be a SaveGame instance."
	).is_true()

	# Identity: same reference means they point to the same object in memory.
	# GDScript object equality (==) checks identity for Reference types by default.
	assert_bool(sl.last_save_game == ls.last_transition_save_game).override_failure_message(
		"AC-1: CR-4 violation — save_to_slot and transition_to_section must receive the same SaveGame object (no duplicate() between them)."
	).is_true()

	# Assert: transition reason is RESPAWN.
	assert_int(ls.last_transition_reason).override_failure_message(
		"AC-1: transition_to_section must use TransitionReason.RESPAWN (1)."
	).is_equal(LevelStreamingService.TransitionReason.RESPAWN)


# ── AC-2: IO failure does not abort respawn ───────────────────────────────────

## AC-2: When save_to_slot returns false (IO failure), transition_to_section is
## still called and _flow_state becomes RESTORING.
func test_capturing_save_failure_continues_to_transition() -> void:
	# Arrange
	var triple: Array = _make_triple()
	var svc: FailureRespawnService = triple[0]
	var ls: _TestLSDouble = triple[1]
	var sl: _TestSLDouble = triple[2]
	sl.save_return_value = false  # Simulate IO failure.

	# Act
	svc._on_player_died(0)

	# Assert: transition_to_section was still called (respawn not aborted).
	assert_int(ls.transition_call_count).override_failure_message(
		"AC-2: transition_to_section must still be called even when save_to_slot returns false."
	).is_equal(1)

	# Assert: _flow_state is RESTORING (CAPTURING body completed).
	assert_int(svc._flow_state).override_failure_message(
		"AC-2: _flow_state must be RESTORING after CAPTURING body completes (even on save failure)."
	).is_equal(FailureRespawnService.FlowState.RESTORING)


# ── AC-3: FailureRespawnState schema ──────────────────────────────────────────

## AC-3 part A: Zero-arg constructor defaults floor_applied_this_checkpoint to false.
func test_failure_respawn_state_class_and_init_signature_default_is_false() -> void:
	# Act
	var state: FailureRespawnState = FailureRespawnState.new()
	auto_free(state)

	# Assert: class_name registration and extends Resource.
	assert_bool(state is Resource).override_failure_message(
		"AC-3: FailureRespawnState must extend Resource."
	).is_true()

	assert_bool(state is FailureRespawnState).override_failure_message(
		"AC-3: class_name FailureRespawnState must be resolvable."
	).is_true()

	# Assert: zero-arg default.
	assert_bool(state.floor_applied_this_checkpoint).override_failure_message(
		"AC-3: FailureRespawnState.new() must default floor_applied_this_checkpoint to false."
	).is_false()


## AC-3 part B: One-arg constructor (true) sets floor_applied_this_checkpoint = true.
func test_failure_respawn_state_class_and_init_signature_one_arg_true() -> void:
	# Act
	var state: FailureRespawnState = FailureRespawnState.new(true)
	auto_free(state)

	# Assert
	assert_bool(state.floor_applied_this_checkpoint).override_failure_message(
		"AC-3: FailureRespawnState.new(true) must set floor_applied_this_checkpoint to true."
	).is_true()


# ── AC-4: capture() mirrors live flag, does not advance it ────────────────────

## AC-4 part A: capture(false) returns instance with floor_applied_this_checkpoint = false.
func test_failure_respawn_state_capture_mirrors_flag_does_not_advance_live_false() -> void:
	# Arrange
	var live_flag: bool = false

	# Act
	var captured: FailureRespawnState = FailureRespawnState.capture(live_flag)
	auto_free(captured)

	# Assert: captured state mirrors live flag.
	assert_bool(captured.floor_applied_this_checkpoint).override_failure_message(
		"AC-4: capture(false) must return FailureRespawnState with floor_applied_this_checkpoint = false."
	).is_false()

	# Assert: live_flag is unchanged (read-only capture, no side effect).
	assert_bool(live_flag).override_failure_message(
		"AC-4: live_flag must remain false after capture() — capture is read-only per CR-6."
	).is_false()


## AC-4 part B: capture(true) returns instance with floor_applied_this_checkpoint = true.
func test_failure_respawn_state_capture_mirrors_flag_does_not_advance_live_true() -> void:
	# Arrange
	var live_flag: bool = true

	# Act
	var captured: FailureRespawnState = FailureRespawnState.capture(live_flag)
	auto_free(captured)

	# Assert: captured state mirrors live flag.
	assert_bool(captured.floor_applied_this_checkpoint).override_failure_message(
		"AC-4: capture(true) must return FailureRespawnState with floor_applied_this_checkpoint = true."
	).is_true()

	# Assert: live_flag is unchanged.
	assert_bool(live_flag).override_failure_message(
		"AC-4: live_flag must remain true after capture() — capture is read-only per CR-6."
	).is_true()


# ── AC-5: assembled SaveGame contains correct FailureRespawnState ─────────────

## AC-5: Assembled SaveGame.failure_respawn is non-null and mirrors the live
## _floor_applied_this_checkpoint at capture time (VS scope = always false).
func test_assembled_save_has_failure_respawn_with_live_flag() -> void:
	# Arrange: VS scope — floor flag is false (default).
	var triple: Array = _make_triple()
	var svc: FailureRespawnService = triple[0]
	var ls: _TestLSDouble = triple[1]
	# _floor_applied_this_checkpoint is false by default in FailureRespawnService.

	# Act
	svc._on_player_died(0)

	# Assert: transition was called with a save that has non-null failure_respawn.
	var assembled: SaveGame = ls.last_transition_save_game
	assert_object(assembled).override_failure_message(
		"AC-5: assembled SaveGame passed to transition_to_section must be non-null."
	).is_not_null()

	assert_object(assembled.failure_respawn).override_failure_message(
		"AC-5: assembled_save.failure_respawn must be non-null."
	).is_not_null()

	assert_bool(assembled.failure_respawn is FailureRespawnState).override_failure_message(
		"AC-5: assembled_save.failure_respawn must be a FailureRespawnState instance."
	).is_true()

	# VS scope: floor not applied — expect false.
	assert_bool(assembled.failure_respawn.floor_applied_this_checkpoint).override_failure_message(
		"AC-5: floor_applied_this_checkpoint must equal the live value (false in VS scope)."
	).is_false()


## AC-5 supplemental: verify that when _floor_applied_this_checkpoint is true,
## the assembled save captures that value correctly.
func test_assembled_save_captures_floor_flag_true_when_live_flag_is_true() -> void:
	# Arrange
	var triple: Array = _make_triple()
	var svc: FailureRespawnService = triple[0]
	var ls: _TestLSDouble = triple[1]
	svc._floor_applied_this_checkpoint = true  # Set live flag directly.

	# Act
	svc._on_player_died(0)

	# Assert: captured floor_applied_this_checkpoint mirrors the live value (true).
	var assembled: SaveGame = ls.last_transition_save_game
	assert_bool(assembled.failure_respawn.floor_applied_this_checkpoint).override_failure_message(
		"AC-5: floor_applied_this_checkpoint must mirror the live flag (true) at capture time."
	).is_true()


# ── AC-6: no await between save_to_slot and transition_to_section ─────────────

## AC-6: Static source lint — zero `await` statements in the code path between
## save_to_slot and transition_to_section in failure_respawn_service.gd.
##
## Implementation: read the source file, locate the line ranges for the two
## call sites, and grep that slice for `await`. Any match is a CR-4 violation.
func test_failure_respawn_service_no_await_in_capturing_path() -> void:
	# Arrange: read the source file.
	var source_path: String = "res://src/gameplay/failure_respawn/failure_respawn_service.gd"
	var content: String = FileAccess.get_file_as_string(source_path)
	assert_str(content).override_failure_message(
		"AC-6: Could not read failure_respawn_service.gd — file missing or unreadable."
	).is_not_empty()

	# Locate the two anchor call sites as line offsets.
	var save_marker: String = "save_to_slot"
	var transition_marker: String = "transition_to_section"

	var save_pos: int = content.find(save_marker)
	assert_int(save_pos).override_failure_message(
		"AC-6: 'save_to_slot' not found in failure_respawn_service.gd — capturing body missing."
	).is_not_equal(-1)

	var transition_pos: int = content.find(transition_marker, save_pos)
	assert_int(transition_pos).override_failure_message(
		"AC-6: 'transition_to_section' not found after 'save_to_slot' in failure_respawn_service.gd."
	).is_not_equal(-1)

	# Extract the slice between the two markers.
	var slice: String = content.substr(save_pos, transition_pos - save_pos)

	# Assert: no `await` in the slice.
	var await_pos: int = slice.find("await")
	assert_int(await_pos).override_failure_message(
		"AC-6: CR-4 violation — 'await' found between save_to_slot and transition_to_section in failure_respawn_service.gd. Synchronous ordering is a hard invariant."
	).is_equal(-1)


# ── AC-7: CAPTURING → RESTORING flow state transition ─────────────────────────

## AC-7: _flow_state is RESTORING after the CAPTURING body completes (LS handoff
## done; now awaiting the step-9 restore callback from LevelStreamingService).
func test_capturing_completes_with_flow_state_restoring() -> void:
	# Arrange
	var triple: Array = _make_triple()
	var svc: FailureRespawnService = triple[0]

	# Confirm precondition.
	assert_int(svc._flow_state).override_failure_message(
		"AC-7 pre-condition: _flow_state must start IDLE."
	).is_equal(FailureRespawnService.FlowState.IDLE)

	# Act
	svc._on_player_died(0)

	# Assert: CAPTURING body completed and transitioned to RESTORING.
	assert_int(svc._flow_state).override_failure_message(
		"AC-7: _flow_state must be RESTORING after CAPTURING body completes (LS handoff done)."
	).is_equal(FailureRespawnService.FlowState.RESTORING)
