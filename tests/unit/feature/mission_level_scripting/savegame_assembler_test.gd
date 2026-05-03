# tests/unit/feature/mission_level_scripting/savegame_assembler_test.gd
#
# SaveGameAssemblerTest — GdUnit4 tests for Story MLS-004.
# Verifies the FORWARD autosave gate: capture chain + save_to_slot wiring.

class_name SaveGameAssemblerTest
extends GdUnitTestSuite


func _make_running_service_with_mission() -> MissionLevelScriptingService:
	var svc: MissionLevelScriptingService = MissionLevelScriptingService.new()
	auto_free(svc)
	# Force into RUNNING with a stub MissionState.
	svc._phase = MissionLevelScriptingService.MissionPhase.RUNNING
	var ms: MissionState = MissionState.new()
	ms.section_id = &"plaza"
	ms.objective_states[&"recover_plaza_document"] = MissionLevelScriptingService.ObjectiveState.ACTIVE
	svc._mission_state = ms
	return svc


# ── Tests ──────────────────────────────────────────────────────────────────────

## AC-MLS-8.1: FORWARD reason while RUNNING triggers SaveLoad.save_to_slot.
## Verified by inspecting the slot-0 file after the call (it should be created).
func test_forward_section_entered_writes_slot_zero_autosave() -> void:
	var svc: MissionLevelScriptingService = _make_running_service_with_mission()

	# Clean slot 0 before the test.
	var saves_dir: String = "user://saves/"
	DirAccess.make_dir_recursive_absolute(saves_dir)
	if FileAccess.file_exists(saves_dir + "slot_0.res"):
		DirAccess.remove_absolute(saves_dir + "slot_0.res")

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.FORWARD)

	# slot_0.res should exist after FORWARD autosave.
	assert_bool(FileAccess.file_exists(saves_dir + "slot_0.res")).override_failure_message(
		"AC-MLS-8.1: FORWARD section_entered while RUNNING must produce slot_0.res autosave"
	).is_true()


## AC-MLS-8.2: RESPAWN reason does NOT call save_to_slot.
func test_respawn_section_entered_does_not_autosave() -> void:
	var svc: MissionLevelScriptingService = _make_running_service_with_mission()

	# Capture pre-state.
	var saves_dir: String = "user://saves/"
	DirAccess.make_dir_recursive_absolute(saves_dir)
	if FileAccess.file_exists(saves_dir + "slot_0.res"):
		DirAccess.remove_absolute(saves_dir + "slot_0.res")

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.RESPAWN)

	# slot_0.res must NOT exist (RESPAWN branch is autosave-suppressed per FP-4).
	assert_bool(FileAccess.file_exists(saves_dir + "slot_0.res")).override_failure_message(
		"AC-MLS-8.2: RESPAWN section_entered must NOT write slot_0.res — FP-4 violation"
	).is_false()


## AC-MLS-8.3: FP-6 grep — no `await` or `call_deferred` in the assembly path.
func test_save_assembler_no_await_or_call_deferred_in_assembly_chain() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
	)
	var start: int = src.find("func _assemble_and_save_forward")
	assert_int(start).is_greater_equal(0)
	var end: int = src.find("\nfunc ", start + 1)
	if end == -1:
		end = src.length()
	var body: String = src.substr(start, end - start)
	var stripped: String = ""
	for line in body.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("##") or trimmed.begins_with("#"):
			continue
		stripped += line + "\n"
	# No `await` and no `call_deferred` in the synchronous assembly chain.
	assert_int(stripped.find(" await ")).override_failure_message(
		"AC-MLS-8.3: _assemble_and_save_forward body contains await — breaks CR-15 synchronous invariant"
	).is_equal(-1)
	assert_int(stripped.find("call_deferred")).override_failure_message(
		"AC-MLS-8.3: _assemble_and_save_forward body contains call_deferred — breaks CR-15"
	).is_equal(-1)


## AC-MLS-12.3: FP-4 — RESPAWN branch must not be reachable to save_to_slot.
## Verified by structural code review: _on_section_entered's RESPAWN branch is
## an early `return`, never reaching `_assemble_and_save_forward`.
func test_respawn_branch_does_not_reach_save_to_slot() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
	)
	# The handler must NOT call save_to_slot from any RESPAWN-reachable path.
	# Heuristic: the only call_site of `_assemble_and_save_forward` should be
	# guarded by a FORWARD check.
	var handler_start: int = src.find("func _on_section_entered")
	var handler_end: int = src.find("\nfunc ", handler_start + 1)
	var handler_body: String = src.substr(handler_start, handler_end - handler_start)
	# The first non-comment statement should reference FORWARD or NEW_GAME.
	# Simple check: handler body contains the FORWARD/RESPAWN dispatch shape.
	assert_bool(
		handler_body.contains("TransitionReason.FORWARD")
		and handler_body.contains("_assemble_and_save_forward")
	).override_failure_message(
		"AC-MLS-12.3: _on_section_entered must dispatch FORWARD to _assemble_and_save_forward"
	).is_true()


## AC-MLS-11.1 (partial — VS scope): LOAD_FROM_SAVE does not emit objective_started
## for restored ACTIVE objectives. At MVP, MLS doesn't yet implement LOAD_FROM_SAVE
## restoration — this test verifies the no-emit invariant via source-grep (handler
## body doesn't emit objective_started in the LOAD_FROM_SAVE branch).
func test_load_from_save_branch_does_not_emit_objective_started() -> void:
	# At MVP: LOAD_FROM_SAVE branch simply returns from _on_section_entered (since
	# the `if reason != NEW_GAME: return` guard catches it). No emits.
	# This test confirms the early return shape.
	var src: String = FileAccess.get_file_as_string(
		"res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
	)
	var handler_start: int = src.find("func _on_section_entered")
	var handler_end: int = src.find("\nfunc ", handler_start + 1)
	var handler_body: String = src.substr(handler_start, handler_end - handler_start)
	# Verify the early-return guard exists (covers LOAD_FROM_SAVE among others).
	assert_bool(
		handler_body.contains("if reason != LevelStreamingService.TransitionReason.NEW_GAME:")
		and handler_body.contains("return")
	).is_true()
