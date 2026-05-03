# tests/unit/feature/failure_respawn/autoload_scaffold_test.gd
#
# AutoloadScaffoldTest — GdUnit4 test suite for Story FR-001.
#
# PURPOSE
#   Verifies the FailureRespawnService autoload scaffold initialises correctly,
#   connects/disconnects signals per ADR-0002 IG 3, registers the LS restore
#   callback, and enforces CR-2 idempotency in all FlowState combinations.
#
# COVERED ACCEPTANCE CRITERIA (Story FR-001)
#   AC-1 — class_name FailureRespawnService extends Node; FlowState enum has
#           IDLE / CAPTURING / RESTORING; default state is IDLE; _current_checkpoint null.
#   AC-2 — _ready() subscribes to Events.player_died and Events.section_entered;
#           _exit_tree() disconnects both.
#   AC-3 — _ready() calls LevelStreamingService.register_restore_callback once
#           with a Callable pointing to _on_ls_restore.
#   AC-4 — Boot initial state: _flow_state == IDLE, _current_checkpoint == null.
#   AC-5 — IDLE → CAPTURING on player_died (any cause).
#   AC-6 — CAPTURING idempotency: second player_died does not change state.
#   AC-7 — RESTORING idempotency: player_died while RESTORING does not change state.
#   AC-8 — project.godot [autoload] contains FailureRespawn entry between
#           Combat and MissionLevelScripting.
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#   DI doubles are plain Node subclasses that record calls without side-effects.
#
# DESIGN NOTES — signal isolation
#   The live Events autoload persists across tests. To avoid signal subscriber
#   accumulation, each test that adds a FailureRespawnService to the tree uses
#   auto_free() so _exit_tree() fires and disconnects the service cleanly.
#   Tests that need to confirm _ready() connections (AC-2) assert immediately
#   after add_child, then rely on auto_free / remove_child for cleanup.
#
# DESIGN NOTES — DI test orchestration (AC-3)
#   Inject the LevelStreamingService double BEFORE add_child so _ready() uses
#   the double rather than the live autoload.
#   Pattern: `var svc = FailureRespawnService.new(); svc._inject_level_streaming(double); add_child(svc)`.

class_name AutoloadScaffoldTest
extends GdUnitTestSuite


# ── Inner doubles ─────────────────────────────────────────────────────────────

## Minimal LevelStreamingService double that records register_restore_callback calls.
## Also stubs transition_to_section and get_current_section_id so that the FR-002
## CAPTURING body (now live in _on_player_died) does not crash when AC-5/6/7 tests
## trigger Events.player_died via the live signal.
class LevelStreamingDouble extends Node:
	var register_call_count: int = 0
	var last_registered_callable: Callable = Callable()

	func register_restore_callback(callback: Callable) -> void:
		register_call_count += 1
		last_registered_callable = callback

	func transition_to_section(
		_section_id: StringName,
		_save_game: SaveGame = null,
		_reason: int = 0
	) -> void:
		pass  # no-op — FR-001 tests do not assert on transition behaviour

	func get_current_section_id() -> StringName:
		return &""  # neutral fallback — FR-001 tests do not inspect section routing


## Minimal SaveLoadService double — stubs save_to_slot so that the FR-002
## CAPTURING body (now live) does not crash on AC-5/6/7 signal-based tests.
class SaveLoadDouble extends Node:
	func save_to_slot(_slot: int, _sg: SaveGame) -> bool:
		return true  # always-ok stub — FR-001 tests do not assert on save behaviour


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a FailureRespawnService with injected doubles and adds it to the tree
## so _ready() fires. Returns the service; caller does not need to free manually
## (auto_free handles it).
func _make_service_with_doubles() -> FailureRespawnService:
	var ls_double: LevelStreamingDouble = LevelStreamingDouble.new()
	auto_free(ls_double)
	var sl_double: SaveLoadDouble = SaveLoadDouble.new()
	auto_free(sl_double)

	var svc: FailureRespawnService = FailureRespawnService.new()
	svc._inject_level_streaming(ls_double)
	svc._inject_save_load(sl_double)
	add_child(svc)
	auto_free(svc)
	return svc


## Creates a FailureRespawnService without adding to the tree (no _ready()).
## Used for tests that inspect compile-time structure only.
func _make_bare_service() -> FailureRespawnService:
	var svc: FailureRespawnService = FailureRespawnService.new()
	auto_free(svc)
	return svc


# ── AC-1: class declaration, FlowState enum, default field values ─────────────

## AC-1 part A: FailureRespawnService is a class_name'd Node.
## Loads the script directly and confirms the class is accessible by name.
func test_failure_respawn_service_class_name_and_extends() -> void:
	# Arrange / Act — script is already available via class_name at parse time.
	var svc: FailureRespawnService = FailureRespawnService.new()
	auto_free(svc)

	# Assert: is_instance_of verifies both class_name and `extends Node`.
	assert_bool(svc is Node).override_failure_message(
		"AC-1: FailureRespawnService must extend Node."
	).is_true()

	assert_bool(svc is FailureRespawnService).override_failure_message(
		"AC-1: class_name FailureRespawnService must be resolvable."
	).is_true()


## AC-1 part B: FlowState enum exposes IDLE (0), CAPTURING (1), RESTORING (2).
func test_failure_respawn_flow_state_enum_has_three_members() -> void:
	# Assert enum values exist and match expected declaration order.
	assert_int(FailureRespawnService.FlowState.IDLE).override_failure_message(
		"AC-1: FlowState.IDLE must equal 0 (first declared member)."
	).is_equal(0)

	assert_int(FailureRespawnService.FlowState.CAPTURING).override_failure_message(
		"AC-1: FlowState.CAPTURING must equal 1 (second declared member)."
	).is_equal(1)

	assert_int(FailureRespawnService.FlowState.RESTORING).override_failure_message(
		"AC-1: FlowState.RESTORING must equal 2 (third declared member)."
	).is_equal(2)


## AC-1 / AC-4: Fresh instance (before _ready()) has IDLE state and null checkpoint.
func test_failure_respawn_default_state_is_idle() -> void:
	# Arrange — bare instance; _ready() has NOT fired.
	var svc: FailureRespawnService = _make_bare_service()

	# Assert _flow_state default.
	assert_int(svc._flow_state).override_failure_message(
		"AC-1/AC-4: _flow_state must default to FlowState.IDLE (0) before _ready()."
	).is_equal(FailureRespawnService.FlowState.IDLE)

	# Assert _current_checkpoint default.
	assert_object(svc._current_checkpoint).override_failure_message(
		"AC-1/AC-4: _current_checkpoint must default to null (no checkpoint recorded at boot)."
	).is_null()


# ── AC-2: _ready() connects signals; _exit_tree() disconnects them ────────────

## AC-2 part A: _ready() connects both Events signals.
func test_failure_respawn_ready_connects_to_events() -> void:
	# Arrange + Act — add_child fires _ready().
	var svc: FailureRespawnService = _make_service_with_doubles()

	# Assert both connections are active.
	assert_bool(Events.player_died.is_connected(svc._on_player_died)).override_failure_message(
		"AC-2: _ready() must connect Events.player_died → _on_player_died."
	).is_true()

	assert_bool(Events.section_entered.is_connected(svc._on_section_entered)).override_failure_message(
		"AC-2: _ready() must connect Events.section_entered → _on_section_entered."
	).is_true()


## AC-2 part B: _exit_tree() disconnects both Events signals.
func test_failure_respawn_exit_tree_disconnects() -> void:
	# Arrange — create and add to tree so _ready() fires and connects.
	var ls_double: LevelStreamingDouble = LevelStreamingDouble.new()
	auto_free(ls_double)
	var sl_double: SaveLoadDouble = SaveLoadDouble.new()
	auto_free(sl_double)

	var svc: FailureRespawnService = FailureRespawnService.new()
	svc._inject_level_streaming(ls_double)
	svc._inject_save_load(sl_double)
	add_child(svc)
	# Do NOT auto_free here — we need to manually remove to trigger _exit_tree().

	# Confirm connected first.
	assert_bool(Events.player_died.is_connected(svc._on_player_died)).override_failure_message(
		"AC-2 pre-condition: player_died must be connected before removal."
	).is_true()

	# Act — remove from tree fires _exit_tree().
	remove_child(svc)
	svc.queue_free()

	# Assert both disconnected.
	assert_bool(Events.player_died.is_connected(svc._on_player_died)).override_failure_message(
		"AC-2: _exit_tree() must disconnect Events.player_died."
	).is_false()

	assert_bool(Events.section_entered.is_connected(svc._on_section_entered)).override_failure_message(
		"AC-2: _exit_tree() must disconnect Events.section_entered."
	).is_false()


# ── AC-3: _ready() registers the LS restore callback ─────────────────────────

## AC-3: register_restore_callback is called exactly once in _ready() with a
## Callable that wraps _on_ls_restore.
func test_failure_respawn_ready_registers_restore_callback() -> void:
	# Arrange — build double and inject BEFORE add_child.
	var ls_double: LevelStreamingDouble = LevelStreamingDouble.new()
	auto_free(ls_double)
	var sl_double: SaveLoadDouble = SaveLoadDouble.new()
	auto_free(sl_double)

	var svc: FailureRespawnService = FailureRespawnService.new()
	svc._inject_level_streaming(ls_double)
	svc._inject_save_load(sl_double)

	# Act — add to tree fires _ready().
	add_child(svc)
	auto_free(svc)

	# Assert: called exactly once.
	assert_int(ls_double.register_call_count).override_failure_message(
		"AC-3: register_restore_callback must be called exactly once in _ready()."
	).is_equal(1)

	# Assert: the registered callable points to _on_ls_restore.
	assert_bool(ls_double.last_registered_callable.is_valid()).override_failure_message(
		"AC-3: the registered Callable must be valid."
	).is_true()

	# Verify the callable target is this service instance and method is _on_ls_restore.
	assert_object(ls_double.last_registered_callable.get_object()).override_failure_message(
		"AC-3: registered Callable's object must be the FailureRespawnService instance."
	).is_equal(svc)

	assert_str(ls_double.last_registered_callable.get_method()).override_failure_message(
		"AC-3: registered Callable's method must be '_on_ls_restore'."
	).is_equal("_on_ls_restore")


# ── AC-5 / AC-6 / AC-7: FlowState transitions and CR-2 idempotency ───────────

## Restore InputContext to GAMEPLAY after each test. _on_player_died pushes
## LOADING; without explicit cleanup it leaks into subsequent suites.
func after_test() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


## AC-5: IDLE → CAPTURING (and onward to RESTORING) when player_died fires from IDLE.
## Post-FR-002: the CAPTURING body completes synchronously to RESTORING within the
## same call stack. Test asserts state moved out of IDLE — exact final state depends
## on which story has landed (FR-001 stub: CAPTURING; FR-002+: RESTORING).
func test_failure_respawn_player_died_idle_transitions_out_of_idle() -> void:
	# Arrange — service must be in tree for signal connection.
	var svc: FailureRespawnService = _make_service_with_doubles()

	# Confirm precondition.
	assert_int(svc._flow_state).override_failure_message(
		"AC-5 pre-condition: _flow_state must start IDLE."
	).is_equal(FailureRespawnService.FlowState.IDLE)

	# Act — emit player_died with UNKNOWN cause (0).
	# Direct invocation — Events.player_died.emit would also trigger the LIVE
	# FailureRespawn autoload, which calls real LevelStreamingService and pollutes
	# subsequent tests' physics/InputContext state.
	svc._on_player_died(CombatSystemNode.DeathCause.UNKNOWN)

	# Assert — flow advanced beyond IDLE in the same call stack.
	# Per FR-002, the CAPTURING body runs to completion synchronously and ends at
	# RESTORING (waiting for FR-005's LS step-9 callback). Both CAPTURING and
	# RESTORING are valid end-states for this assertion.
	assert_int(svc._flow_state).override_failure_message(
		"AC-5: player_died from IDLE must transition _flow_state out of IDLE."
	).is_not_equal(FailureRespawnService.FlowState.IDLE)


## AC-6: CAPTURING → stays CAPTURING on second player_died (idempotency drop).
func test_failure_respawn_player_died_capturing_idempotency_drop() -> void:
	# Arrange — service in tree, then force CAPTURING state.
	var svc: FailureRespawnService = _make_service_with_doubles()
	svc._flow_state = FailureRespawnService.FlowState.CAPTURING

	# Act — emit player_died again.
	# Direct invocation — Events.player_died.emit would also trigger the LIVE
	# FailureRespawn autoload, which calls real LevelStreamingService and pollutes
	# subsequent tests' physics/InputContext state.
	svc._on_player_died(CombatSystemNode.DeathCause.UNKNOWN)

	# Assert — state unchanged.
	assert_int(svc._flow_state).override_failure_message(
		"AC-6: player_died while CAPTURING must NOT change _flow_state (idempotency drop)."
	).is_equal(FailureRespawnService.FlowState.CAPTURING)


## AC-7: RESTORING → stays RESTORING on player_died (idempotency drop).
func test_failure_respawn_player_died_restoring_idempotency_drop() -> void:
	# Arrange — service in tree, then force RESTORING state.
	var svc: FailureRespawnService = _make_service_with_doubles()
	svc._flow_state = FailureRespawnService.FlowState.RESTORING

	# Act — emit player_died.
	# Direct invocation — Events.player_died.emit would also trigger the LIVE
	# FailureRespawn autoload, which calls real LevelStreamingService and pollutes
	# subsequent tests' physics/InputContext state.
	svc._on_player_died(CombatSystemNode.DeathCause.UNKNOWN)

	# Assert — state unchanged.
	assert_int(svc._flow_state).override_failure_message(
		"AC-7: player_died while RESTORING must NOT change _flow_state (idempotency drop)."
	).is_equal(FailureRespawnService.FlowState.RESTORING)


# ── AC-8: project.godot [autoload] entry ordering ────────────────────────────

## AC-8: project.godot has FailureRespawn entry between Combat and MissionLevelScripting.
func test_failure_respawn_project_godot_autoload_entry_at_line_8() -> void:
	# Arrange — read project.godot as plain text.
	var content: String = FileAccess.get_file_as_string("res://project.godot")
	assert_str(content).override_failure_message(
		"AC-8 pre-condition: could not read res://project.godot."
	).is_not_empty()

	# Find the [autoload] section.
	var autoload_start: int = content.find("[autoload]")
	assert_int(autoload_start).override_failure_message(
		"AC-8: res://project.godot must contain a [autoload] section."
	).is_not_equal(-1)

	# Locate the next section header after [autoload] so we can scope the search.
	var next_section: int = content.find("\n[", autoload_start + 1)
	var autoload_block: String = content.substr(
		autoload_start,
		(next_section - autoload_start) if next_section != -1 else content.length()
	)

	# Verify the exact entry value.
	var expected_entry: String = 'FailureRespawn="*res://src/gameplay/failure_respawn/failure_respawn_service.gd"'
	assert_bool(autoload_block.contains(expected_entry)).override_failure_message(
		"AC-8: [autoload] block must contain: %s" % expected_entry
	).is_true()

	# Verify ordering: Combat appears before FailureRespawn.
	var pos_combat: int = autoload_block.find("Combat=")
	var pos_fr: int = autoload_block.find("FailureRespawn=")
	var pos_mls: int = autoload_block.find("MissionLevelScripting=")

	assert_int(pos_combat).override_failure_message(
		"AC-8: [autoload] block must contain a Combat= entry."
	).is_not_equal(-1)

	assert_int(pos_mls).override_failure_message(
		"AC-8: [autoload] block must contain a MissionLevelScripting= entry."
	).is_not_equal(-1)

	assert_bool(pos_combat < pos_fr).override_failure_message(
		"AC-8: Combat= entry must appear before FailureRespawn= in [autoload]."
	).is_true()

	assert_bool(pos_fr < pos_mls).override_failure_message(
		"AC-8: FailureRespawn= entry must appear before MissionLevelScripting= in [autoload]."
	).is_true()
