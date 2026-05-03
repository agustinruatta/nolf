# tests/unit/feature/mission_level_scripting/autoload_order_test.gd
#
# AutoloadOrderTest — GdUnit4 test suite for Story MLS-001.
#
# PURPOSE
#   Verifies the MissionLevelScriptingService autoload scaffold initialises
#   correctly, connects/disconnects signals per ADR-0002 IG 3, and enforces
#   the ADR-0007 load-order invariant (line 9, after FailureRespawn).
#
# COVERED ACCEPTANCE CRITERIA (Story MLS-001)
#   AC-1 — class_name MissionLevelScriptingService extends Node; doc comment on
#           class; no gameplay fields exported in this story (scaffold only).
#   AC-2 — project.godot [autoload] block contains MissionLevelScripting entry
#           at position 9, immediately after FailureRespawn (position 8) and
#           before SettingsService (position 10).
#   AC-3 — _init() contains zero references to Events, FailureRespawn, SaveLoad,
#           get_node(). Absent _init() auto-passes.
#   AC-4 — _ready() connects to Events.section_entered and Events.respawn_triggered
#           using typed callable syntax.
#   AC-5 — _exit_tree() disconnects both signals (is_connected guard present).
#   AC-6 — At runtime, MissionLevelScripting node tree index > FailureRespawn
#           tree index (load-order invariant AC-MLS-12.1).
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#
# DESIGN NOTES — signal isolation
#   The live Events autoload persists across tests. To avoid signal subscriber
#   accumulation, each test that adds a MissionLevelScriptingService to the
#   tree uses auto_free() so _exit_tree() fires and disconnects cleanly.
#   Tests that confirm _ready() connections (AC-4) assert immediately after
#   add_child, then rely on auto_free / remove_child for cleanup.
#
# DESIGN NOTES — AC-3 source inspection
#   The _init() body (or its absence) is verified by loading the script source
#   as text and scanning for prohibited cross-autoload patterns within the
#   _init() function body. Absent _init() → auto-pass per story spec.

class_name AutoloadOrderTest
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh MissionLevelScriptingService, adds it to the scene tree so
## _ready() fires, and registers it with auto_free() for cleanup.
func _make_service() -> MissionLevelScriptingService:
	var svc: MissionLevelScriptingService = MissionLevelScriptingService.new()
	add_child(svc)
	auto_free(svc)
	return svc


# ── AC-1: class declaration ───────────────────────────────────────────────────

## AC-1: MissionLevelScriptingService is a class_name'd Node.
## Loads via class_name and verifies the extends chain.
func test_mission_level_scripting_service_class_name_and_extends() -> void:
	# Arrange / Act — class_name is resolvable at parse time.
	var svc: MissionLevelScriptingService = MissionLevelScriptingService.new()
	auto_free(svc)

	# Assert: extends Node.
	assert_bool(svc is Node).override_failure_message(
		"AC-1: MissionLevelScriptingService must extend Node."
	).is_true()

	# Assert: class_name is resolvable.
	assert_bool(svc is MissionLevelScriptingService).override_failure_message(
		"AC-1: class_name MissionLevelScriptingService must be resolvable."
	).is_true()


# ── AC-2: project.godot [autoload] entry ordering ────────────────────────────

## AC-2: project.godot [autoload] block contains MissionLevelScripting between
## FailureRespawn (position 8) and SettingsService (position 10).
func test_mission_level_scripting_project_godot_autoload_at_line_9() -> void:
	# Arrange — read project.godot as plain text.
	var content: String = FileAccess.get_file_as_string("res://project.godot")
	assert_str(content).override_failure_message(
		"AC-2 pre-condition: could not read res://project.godot."
	).is_not_empty()

	# Find the [autoload] section.
	var autoload_start: int = content.find("[autoload]")
	assert_int(autoload_start).override_failure_message(
		"AC-2: res://project.godot must contain a [autoload] section."
	).is_not_equal(-1)

	# Scope to the [autoload] block only (up to the next section header).
	var next_section: int = content.find("\n[", autoload_start + 1)
	var autoload_block: String = content.substr(
		autoload_start,
		(next_section - autoload_start) if next_section != -1 else content.length()
	)

	# Verify exact MissionLevelScripting entry value.
	var expected_entry: String = 'MissionLevelScripting="*res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"'
	assert_bool(autoload_block.contains(expected_entry)).override_failure_message(
		"AC-2: [autoload] block must contain: %s" % expected_entry
	).is_true()

	# Verify ordering: FailureRespawn before MissionLevelScripting.
	var pos_fr: int = autoload_block.find("FailureRespawn=")
	var pos_mls: int = autoload_block.find("MissionLevelScripting=")
	var pos_settings: int = autoload_block.find("SettingsService=")

	assert_int(pos_fr).override_failure_message(
		"AC-2: [autoload] block must contain a FailureRespawn= entry."
	).is_not_equal(-1)

	assert_int(pos_settings).override_failure_message(
		"AC-2: [autoload] block must contain a SettingsService= entry."
	).is_not_equal(-1)

	assert_bool(pos_fr < pos_mls).override_failure_message(
		"AC-2: FailureRespawn= entry must appear before MissionLevelScripting= in [autoload]."
	).is_true()

	assert_bool(pos_mls < pos_settings).override_failure_message(
		"AC-2: MissionLevelScripting= entry must appear before SettingsService= in [autoload]."
	).is_true()


# ── AC-3: _init() has no cross-autoload references ────────────────────────────

## AC-3: _init() body (if present) must contain zero references to Events,
## FailureRespawn, SaveLoad, or any get_node() call.
## If _init() is absent, the test auto-passes (compliant by omission).
func test_mission_level_scripting_init_has_no_cross_autoload_references() -> void:
	# Arrange — read source as text for static analysis.
	var source: String = FileAccess.get_file_as_string(
		"res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
	)
	assert_str(source).override_failure_message(
		"AC-3 pre-condition: could not read mission_level_scripting.gd source."
	).is_not_empty()

	# Locate the _init() function body (if present).
	var init_start: int = source.find("func _init(")
	if init_start == -1:
		# _init() is absent — auto-pass: no cross-autoload references possible.
		assert_bool(true).override_failure_message(
			"AC-3: _init() is absent — compliant by omission (ADR-0007 IG 3)."
		).is_true()
		return

	# Scope to _init() body: from "func _init(" up to next "func " or end.
	var next_func: int = source.find("\nfunc ", init_start + 1)
	var init_body: String = source.substr(
		init_start,
		(next_func - init_start) if next_func != -1 else source.length()
	)

	# Assert no prohibited cross-autoload references in _init() body.
	assert_bool(init_body.contains("Events.")).override_failure_message(
		"AC-3: _init() must not reference Events.* (ADR-0007 IG 3 violation)."
	).is_false()

	assert_bool(init_body.contains("FailureRespawn.")).override_failure_message(
		"AC-3: _init() must not reference FailureRespawn.* (ADR-0007 IG 3 violation)."
	).is_false()

	assert_bool(init_body.contains("SaveLoad.")).override_failure_message(
		"AC-3: _init() must not reference SaveLoad.* (ADR-0007 IG 3 violation)."
	).is_false()

	assert_bool(init_body.contains("get_node(")).override_failure_message(
		"AC-3: _init() must not call get_node() (ADR-0007 IG 3 violation)."
	).is_false()


# ── AC-4: _ready() connects typed callable signals ───────────────────────────

## AC-4: _ready() connects to Events.section_entered and Events.respawn_triggered
## using typed callable syntax (not legacy string-based connect).
func test_mission_level_scripting_ready_connects_typed_callable_signals() -> void:
	# Arrange + Act — add_child fires _ready().
	var svc: MissionLevelScriptingService = _make_service()

	# Assert both signal connections are active after _ready().
	assert_bool(Events.section_entered.is_connected(svc._on_section_entered)).override_failure_message(
		"AC-4: _ready() must connect Events.section_entered → _on_section_entered."
	).is_true()

	assert_bool(Events.respawn_triggered.is_connected(svc._on_respawn_triggered)).override_failure_message(
		"AC-4: _ready() must connect Events.respawn_triggered → _on_respawn_triggered."
	).is_true()


# ── AC-5: _exit_tree() disconnects with is_connected guards ──────────────────

## AC-5: _exit_tree() disconnects both signals; connections are absent after
## the node is removed from the scene tree.
func test_mission_level_scripting_exit_tree_disconnects_with_guards() -> void:
	# Arrange — create and add to tree so _ready() fires and connects.
	var svc: MissionLevelScriptingService = MissionLevelScriptingService.new()
	add_child(svc)
	# Do NOT auto_free here — we need manual remove_child to trigger _exit_tree().

	# Pre-condition: connections must be active before removal.
	assert_bool(Events.section_entered.is_connected(svc._on_section_entered)).override_failure_message(
		"AC-5 pre-condition: section_entered must be connected before removal."
	).is_true()

	assert_bool(Events.respawn_triggered.is_connected(svc._on_respawn_triggered)).override_failure_message(
		"AC-5 pre-condition: respawn_triggered must be connected before removal."
	).is_true()

	# Act — remove from tree fires _exit_tree().
	remove_child(svc)
	svc.queue_free()

	# Assert both disconnected after _exit_tree().
	assert_bool(Events.section_entered.is_connected(svc._on_section_entered)).override_failure_message(
		"AC-5: _exit_tree() must disconnect Events.section_entered."
	).is_false()

	assert_bool(Events.respawn_triggered.is_connected(svc._on_respawn_triggered)).override_failure_message(
		"AC-5: _exit_tree() must disconnect Events.respawn_triggered."
	).is_false()


# ── AC-6: load-order invariant at runtime ────────────────────────────────────

## AC-6: At runtime, the live MissionLevelScripting autoload node's tree index
## is greater than FailureRespawn's tree index, confirming the ADR-0007 line-9
## load-order invariant (AC-MLS-12.1).
func test_mission_level_scripting_load_order_after_failure_respawn() -> void:
	# Arrange — retrieve both live autoloads from the scene tree.
	var mls_node: Node = get_tree().root.get_node("MissionLevelScripting")
	var fr_node: Node = get_tree().root.get_node("FailureRespawn")
	var events_node: Node = get_tree().root.get_node("Events")

	# Assert Events is present (pre-condition: autoload order not corrupted).
	assert_object(events_node).override_failure_message(
		"AC-6 pre-condition: Events autoload must be in the tree (order not corrupted)."
	).is_not_null()

	# Assert FailureRespawn is present.
	assert_object(fr_node).override_failure_message(
		"AC-6: FailureRespawn autoload must be in the tree before MissionLevelScripting."
	).is_not_null()

	# Assert MissionLevelScripting is present.
	assert_object(mls_node).override_failure_message(
		"AC-6: MissionLevelScripting autoload must be in the scene tree."
	).is_not_null()

	# Assert load order: MissionLevelScripting tree index > FailureRespawn tree index.
	var mls_index: int = mls_node.get_index()
	var fr_index: int = fr_node.get_index()

	assert_bool(mls_index > fr_index).override_failure_message(
		"AC-6: MissionLevelScripting tree index (%d) must be > FailureRespawn index (%d) — ADR-0007 line-9 load-order invariant." % [mls_index, fr_index]
	).is_true()
