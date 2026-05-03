# tests/unit/feature/failure_respawn/respawn_triggered_ordering_test.gd
#
# RespawnTriggeredOrderingTest — GdUnit4 tests for Story FR-003.
# Verifies signal-ordering contract: respawn_triggered fires BEFORE
# reload_current_section/transition_to_section per CR-8.

class_name RespawnTriggeredOrderingTest
extends GdUnitTestSuite


# ── Inner doubles ─────────────────────────────────────────────────────────────

class _TestLSDouble extends Node:
	var transition_call_count: int = 0
	var ordering_log: Array[String] = []

	func transition_to_section(
		_section_id: StringName,
		_save_game: SaveGame = null,
		_reason: int = 0
	) -> void:
		transition_call_count += 1
		ordering_log.append("transition_to_section")

	func register_restore_callback(_callback: Callable) -> void:
		pass

	func get_current_section_id() -> StringName:
		return &"plaza"


class _TestSLDouble extends Node:
	var save_call_count: int = 0
	func save_to_slot(_slot: int, _sg: SaveGame) -> bool:
		save_call_count += 1
		return true


# ── Setup / teardown ──────────────────────────────────────────────────────────

var _emit_log: Array[StringName] = []
var _ordering_log: Array[String] = []


func before_test() -> void:
	_emit_log = []
	_ordering_log = []


func after_test() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_service() -> FailureRespawnService:
	var svc: FailureRespawnService = FailureRespawnService.new()
	auto_free(svc)
	return svc


func _ordering_handler(section_id: StringName) -> void:
	_emit_log.append(section_id)
	_ordering_log.append("respawn_triggered")


# ── Tests ──────────────────────────────────────────────────────────────────────

## AC-1: respawn_triggered emits BEFORE transition_to_section.
func test_respawn_triggered_emits_before_transition_to_section() -> void:
	# Arrange — service with doubles + ordering subscriber.
	var ls: _TestLSDouble = _TestLSDouble.new()
	auto_free(ls)
	var sl: _TestSLDouble = _TestSLDouble.new()
	auto_free(sl)
	var svc: FailureRespawnService = _make_service()
	svc._inject_level_streaming(ls)
	svc._inject_save_load(sl)
	svc._current_section_id = &"plaza"

	# Wrap the LS double so it logs ordering when transition_to_section runs.
	# We share _ordering_log between the double and the signal handler.
	ls.ordering_log = _ordering_log
	Events.respawn_triggered.connect(_ordering_handler)

	# Act — direct invocation of CAPTURING body (avoids polluting other tests).
	svc._on_player_died(0)

	# Cleanup signal connection.
	if Events.respawn_triggered.is_connected(_ordering_handler):
		Events.respawn_triggered.disconnect(_ordering_handler)

	# Assert — respawn_triggered logged BEFORE transition_to_section.
	assert_int(_ordering_log.size()).override_failure_message(
		"AC-1: ordering_log must contain at least 2 entries (respawn_triggered + transition_to_section)."
	).is_greater_equal(2)
	assert_str(_ordering_log[0]).override_failure_message(
		"AC-1: respawn_triggered must fire BEFORE transition_to_section. ordering_log: %s" % [_ordering_log]
	).is_equal("respawn_triggered")
	assert_str(_ordering_log[1]).is_equal("transition_to_section")


## AC-2: No-subscriber case completes cleanly.
func test_respawn_triggered_no_subscriber_completes_without_error() -> void:
	var ls: _TestLSDouble = _TestLSDouble.new()
	auto_free(ls)
	var sl: _TestSLDouble = _TestSLDouble.new()
	auto_free(sl)
	var svc: FailureRespawnService = _make_service()
	svc._inject_level_streaming(ls)
	svc._inject_save_load(sl)
	svc._current_section_id = &"plaza"

	# Act — fire CAPTURING with no subscriber connected.
	svc._on_player_died(0)

	# Assert — flow completed normally.
	assert_int(svc._flow_state).is_equal(FailureRespawnService.FlowState.RESTORING)
	assert_int(ls.transition_call_count).is_equal(1)


## AC-3: Soft-error subscriber does not abort the flow.
func test_respawn_triggered_soft_error_subscriber_continues() -> void:
	var ls: _TestLSDouble = _TestLSDouble.new()
	auto_free(ls)
	var sl: _TestSLDouble = _TestSLDouble.new()
	auto_free(sl)
	var svc: FailureRespawnService = _make_service()
	svc._inject_level_streaming(ls)
	svc._inject_save_load(sl)
	svc._current_section_id = &"plaza"

	# Subscriber that calls push_error.
	var soft_error_handler: Callable = func(_section_id: StringName) -> void:
		push_error("test-error: simulated soft error in respawn_triggered subscriber")
	Events.respawn_triggered.connect(soft_error_handler)

	# Act.
	svc._on_player_died(0)

	# Cleanup.
	if Events.respawn_triggered.is_connected(soft_error_handler):
		Events.respawn_triggered.disconnect(soft_error_handler)

	# Assert — flow proceeded despite the soft error.
	assert_int(svc._flow_state).is_equal(FailureRespawnService.FlowState.RESTORING)
	assert_int(ls.transition_call_count).is_equal(1)


## AC-4: Sole publisher — only failure_respawn_service.gd contains
## `respawn_triggered.emit`.
func test_respawn_triggered_sole_publisher_invariant() -> void:
	var src_dir: String = "res://src/"
	var emitters: Array[String] = []
	_collect_emitters(src_dir, "respawn_triggered.emit", emitters)

	# AC-4: zero or one match — the only allowed emitter is failure_respawn_service.gd.
	for path in emitters:
		assert_bool(path.ends_with("failure_respawn_service.gd")).override_failure_message(
			"AC-4: respawn_triggered.emit found outside failure_respawn_service.gd: %s. Sole-publisher invariant per ADR-0002:183 violated." % path
		).is_true()


## AC-5: section_id passed to respawn_triggered is the current section StringName.
func test_respawn_triggered_section_id_matches_current_section() -> void:
	var ls: _TestLSDouble = _TestLSDouble.new()
	auto_free(ls)
	var sl: _TestSLDouble = _TestSLDouble.new()
	auto_free(sl)
	var svc: FailureRespawnService = _make_service()
	svc._inject_level_streaming(ls)
	svc._inject_save_load(sl)
	svc._current_section_id = &"plaza"

	Events.respawn_triggered.connect(_ordering_handler)

	# Act.
	svc._on_player_died(0)

	# Cleanup.
	if Events.respawn_triggered.is_connected(_ordering_handler):
		Events.respawn_triggered.disconnect(_ordering_handler)

	# Assert — emitted section_id matches.
	assert_int(_emit_log.size()).is_equal(1)
	assert_str(String(_emit_log[0])).is_equal("plaza")


## AC-6: section_id is non-empty StringName at emit time.
func test_respawn_triggered_section_id_non_empty() -> void:
	var ls: _TestLSDouble = _TestLSDouble.new()
	auto_free(ls)
	var sl: _TestSLDouble = _TestSLDouble.new()
	auto_free(sl)
	var svc: FailureRespawnService = _make_service()
	svc._inject_level_streaming(ls)
	svc._inject_save_load(sl)
	# Note: _current_section_id starts &""; falls back to ls.get_current_section_id()
	# which the double returns as &"plaza".

	Events.respawn_triggered.connect(_ordering_handler)
	svc._on_player_died(0)
	if Events.respawn_triggered.is_connected(_ordering_handler):
		Events.respawn_triggered.disconnect(_ordering_handler)

	assert_int(_emit_log.size()).is_equal(1)
	assert_str(String(_emit_log[0])).is_not_empty()


# ── Source-grep helper ────────────────────────────────────────────────────────

func _collect_emitters(dir_path: String, needle: String, results: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path + entry
		if dir.current_is_dir():
			_collect_emitters(full_path + "/", needle, results)
		elif full_path.ends_with(".gd"):
			var content: String = FileAccess.get_file_as_string(full_path)
			if content.contains(needle):
				results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
