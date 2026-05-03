# tests/unit/feature/failure_respawn/checkpoint_assembly_test.gd
#
# CheckpointAssemblyTest — GdUnit4 tests for Story FR-004.
# Verifies section_entered handler: checkpoint assembly + CR-7 IDLE guard
# + floor flag state machine.

class_name CheckpointAssemblyTest
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_service() -> FailureRespawnService:
	var svc: FailureRespawnService = FailureRespawnService.new()
	auto_free(svc)
	return svc


## Builds a fixture scene with a player_respawn_point Marker3D at the given pos.
func _make_scene_with_marker(marker_pos: Vector3) -> Node3D:
	var scene: Node3D = Node3D.new()
	auto_free(scene)
	add_child(scene)
	var marker: Marker3D = Marker3D.new()
	marker.name = "player_respawn_point"
	marker.position = marker_pos
	scene.add_child(marker)
	return scene


## Builds a fixture scene with NO player_respawn_point.
func _make_scene_without_marker() -> Node3D:
	var scene: Node3D = Node3D.new()
	auto_free(scene)
	add_child(scene)
	return scene


# ── Tests ──────────────────────────────────────────────────────────────────────

## AC-1: Marker found at world (10, 0.5, -5) → checkpoint position matches.
func test_section_entered_forward_assembles_checkpoint_from_marker() -> void:
	var svc: FailureRespawnService = _make_service()
	var scene: Node3D = _make_scene_with_marker(Vector3(10.0, 0.5, -5.0))
	svc._inject_current_scene(scene)

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.FORWARD)

	assert_object(svc._current_checkpoint).is_not_null()
	var dist: float = svc._current_checkpoint.respawn_position.distance_to(Vector3(10.0, 0.5, -5.0))
	assert_float(dist).is_less(0.01)


## AC-2: Missing marker → push_error, _current_checkpoint preserved.
func test_section_entered_missing_marker_logs_error_preserves_checkpoint() -> void:
	var svc: FailureRespawnService = _make_service()
	# Pre-set checkpoint to a stub so we can verify it's preserved.
	var stub_cp: Checkpoint = Checkpoint.new()
	stub_cp.respawn_position = Vector3(99.0, 99.0, 99.0)
	svc._current_checkpoint = stub_cp
	var scene: Node3D = _make_scene_without_marker()
	svc._inject_current_scene(scene)

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.FORWARD)

	# Stub preserved (not overwritten with null).
	assert_object(svc._current_checkpoint).is_same(stub_cp)


## AC-3: FORWARD reason resets _floor_applied_this_checkpoint to false.
func test_section_entered_forward_resets_floor_flag() -> void:
	var svc: FailureRespawnService = _make_service()
	svc._floor_applied_this_checkpoint = true  # simulate flag set from prior section
	var scene: Node3D = _make_scene_with_marker(Vector3.ZERO)
	svc._inject_current_scene(scene)

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.FORWARD)

	assert_bool(svc._floor_applied_this_checkpoint).is_false()


## AC-4: RESPAWN reason while RESTORING does NOT reset _floor_applied_this_checkpoint.
## Note: per CR-7, RESTORING state gates state-mutating work, so RESPAWN-while-RESTORING
## leaves the flag untouched (handler returns early).
func test_section_entered_respawn_while_restoring_preserves_floor_flag() -> void:
	var svc: FailureRespawnService = _make_service()
	svc._floor_applied_this_checkpoint = true
	svc._flow_state = FailureRespawnService.FlowState.RESTORING

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.RESPAWN)

	assert_bool(svc._floor_applied_this_checkpoint).is_true()


## AC-5: RESTORING state guard — FORWARD section_entered does not overwrite checkpoint.
func test_section_entered_forward_while_restoring_does_not_mutate_state() -> void:
	var svc: FailureRespawnService = _make_service()
	var stub_cp: Checkpoint = Checkpoint.new()
	stub_cp.respawn_position = Vector3(1.0, 2.0, 3.0)
	svc._current_checkpoint = stub_cp
	svc._floor_applied_this_checkpoint = true
	svc._flow_state = FailureRespawnService.FlowState.RESTORING
	var scene: Node3D = _make_scene_with_marker(Vector3(99.0, 99.0, 99.0))
	svc._inject_current_scene(scene)

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.FORWARD)

	# Checkpoint NOT overwritten (CR-7 IDLE guard).
	assert_object(svc._current_checkpoint).is_same(stub_cp)
	# Floor flag NOT reset.
	assert_bool(svc._floor_applied_this_checkpoint).is_true()


## AC-7: NEW_GAME reason has same effect as FORWARD (assemble + reset flag).
func test_section_entered_new_game_resets_floor_flag_and_assembles() -> void:
	var svc: FailureRespawnService = _make_service()
	svc._floor_applied_this_checkpoint = true
	var scene: Node3D = _make_scene_with_marker(Vector3(5.0, 0.0, 0.0))
	svc._inject_current_scene(scene)

	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	assert_bool(svc._floor_applied_this_checkpoint).is_false()
	assert_object(svc._current_checkpoint).is_not_null()


## AC-8: _current_section_id is updated on FORWARD/NEW_GAME/LOAD_FROM_SAVE while IDLE.
func test_section_entered_updates_current_section_id() -> void:
	var svc: FailureRespawnService = _make_service()
	var scene: Node3D = _make_scene_with_marker(Vector3.ZERO)
	svc._inject_current_scene(scene)

	svc._on_section_entered(&"restaurant", LevelStreamingService.TransitionReason.FORWARD)

	assert_str(String(svc._current_section_id)).is_equal("restaurant")
