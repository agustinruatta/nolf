# tests/unit/foundation/audio/audiomanager_bus_structure_test.gd
#
# AudioManagerBusStructureTest — GdUnit4 suite for Story AUD-001.
#
# PURPOSE
#   Verifies that AudioManager correctly establishes the 5-bus AudioServer
#   structure (AC-1), declares the correct class_name/extends (AC-2), pre-
#   allocates 16 SFX pool nodes routed to the SFX bus (AC-3), ensures no pool
#   nodes are routed to Master (AC-4), and that pool nodes are freed with the
#   manager (AC-5).
#
# ENGINE NOTES
#   Headless Godot starts with only the Master bus (index 0). AudioManager's
#   _setup_buses() adds the 5 named buses when bus_count == 1. The
#   _setup_buses() implementation is idempotent, so running the suite multiple
#   times in one session is safe.
#
# GATE STATUS
#   Story AUD-001 | Logic type → BLOCKING gate.
#   All 5 ACs covered; suite must produce >= 5 passing tests.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name AudioManagerBusStructureTest
extends GdUnitTestSuite


# ── Fixtures ───────────────────────────────────────────────────────────────

## Root node that owns the AudioManager under test. Freed in after_test so
## the AudioManager (and its SFX pool children) are cleaned up after each test.
var _root: Node = null

## The AudioManager instance under test.
var _audio_manager: AudioManager = null


func before_test() -> void:
	_root = Node.new()
	add_child(_root)
	_audio_manager = AudioManager.new()
	_root.add_child(_audio_manager)
	# _ready() fires synchronously when the node enters the tree via add_child.


func after_test() -> void:
	if is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_audio_manager = null


# ── AC-1: 5 named buses present after _ready() ────────────────────────────

## AC-1: AudioServer.bus_count >= 6 (Master + 5 named) after _ready() completes.
func test_audiomanager_ready_bus_count_is_at_least_six() -> void:
	# Arrange + Act: done in before_test().
	# Assert
	assert_int(AudioServer.bus_count).override_failure_message(
		"AC-1: After AudioManager._ready(), AudioServer.bus_count must be >= 6 (Master + 5 named buses)."
	).is_greater_equal(6)


## AC-1: Music bus is registered at a non-negative index (not Master, i.e. > 0).
func test_audiomanager_ready_music_bus_registered() -> void:
	var idx: int = AudioServer.get_bus_index(&"Music")
	assert_int(idx).override_failure_message(
		"AC-1: Music bus must exist at index >= 1 after AudioManager._ready()."
	).is_greater_equal(1)


## AC-1: SFX bus is registered at a non-negative index.
func test_audiomanager_ready_sfx_bus_registered() -> void:
	var idx: int = AudioServer.get_bus_index(&"SFX")
	assert_int(idx).override_failure_message(
		"AC-1: SFX bus must exist at index >= 1 after AudioManager._ready()."
	).is_greater_equal(1)


## AC-1: Ambient bus is registered at a non-negative index.
func test_audiomanager_ready_ambient_bus_registered() -> void:
	var idx: int = AudioServer.get_bus_index(&"Ambient")
	assert_int(idx).override_failure_message(
		"AC-1: Ambient bus must exist at index >= 1 after AudioManager._ready()."
	).is_greater_equal(1)


## AC-1: Voice bus is registered at a non-negative index.
func test_audiomanager_ready_voice_bus_registered() -> void:
	var idx: int = AudioServer.get_bus_index(&"Voice")
	assert_int(idx).override_failure_message(
		"AC-1: Voice bus must exist at index >= 1 after AudioManager._ready()."
	).is_greater_equal(1)


## AC-1: UI bus is registered at a non-negative index.
func test_audiomanager_ready_ui_bus_registered() -> void:
	var idx: int = AudioServer.get_bus_index(&"UI")
	assert_int(idx).override_failure_message(
		"AC-1: UI bus must exist at index >= 1 after AudioManager._ready()."
	).is_greater_equal(1)


## AC-1: _setup_buses() is idempotent — calling it a second time does not add
## duplicate buses (bus_count does not grow past 6 when all buses exist).
func test_audiomanager_setup_buses_is_idempotent() -> void:
	var count_before: int = AudioServer.bus_count
	# Call _setup_buses() directly a second time.
	_audio_manager._setup_buses()
	var count_after: int = AudioServer.bus_count
	assert_int(count_after).override_failure_message(
		"AC-1 (idempotency): Calling _setup_buses() twice must not add duplicate buses. "
		+ "bus_count before=%d, after=%d." % [count_before, count_after]
	).is_equal(count_before)


# ── AC-2: class_name + extends declaration ────────────────────────────────

## AC-2: The script's global name (class_name) is AudioManager.
func test_audiomanager_script_global_name_is_audio_manager() -> void:
	# Arrange
	var script: GDScript = load("res://src/audio/audio_manager.gd") as GDScript
	# Assert
	assert_object(script).override_failure_message(
		"AC-2: src/audio/audio_manager.gd must be loadable as GDScript."
	).is_not_null()
	assert_str(String(script.get_global_name())).override_failure_message(
		"AC-2: class_name must be AudioManager."
	).is_equal("AudioManager")


## AC-2: AudioManager extends Node (not an autoload, not RefCounted).
## Verifies the base class by checking that the instance is a Node and that its
## native class chain does NOT include RefCounted (Node and RefCounted are
## mutually exclusive base hierarchies in Godot).
func test_audiomanager_extends_node() -> void:
	# Instance must be a Node — this is the positive static-type assertion.
	assert_bool(_audio_manager is Node).override_failure_message(
		"AC-2: AudioManager must extend Node."
	).is_true()
	# Verify it is NOT in the RefCounted hierarchy. Because AudioManager is
	# statically typed, GDScript refuses `is RefCounted` at parse time (type
	# incompatibility). We use Object.get_class() to walk the class chain at
	# runtime instead, which works regardless of static type.
	var native_class: String = _audio_manager.get_class()
	# Node's native chain never contains "RefCounted" — RefCounted is a peer
	# root hierarchy. Confirm by asserting the class string is not RefCounted.
	assert_str(native_class).override_failure_message(
		"AC-2: AudioManager's native class must not be RefCounted (it extends Node, a different hierarchy)."
	).is_not_equal("RefCounted")


# ── AC-3: SFX pool pre-allocated, routed to SFX bus ──────────────────────

## AC-3: SFX pool contains exactly SFX_POOL_SIZE (16) entries after _ready().
func test_audiomanager_sfx_pool_size_is_sixteen() -> void:
	assert_int(_audio_manager._sfx_pool.size()).override_failure_message(
		"AC-3: _sfx_pool must contain exactly 16 AudioStreamPlayer3D nodes after _ready()."
	).is_equal(AudioManager.SFX_POOL_SIZE)


## AC-3: Every SFX pool entry has bus == &"SFX" (never &"Master").
func test_audiomanager_sfx_pool_all_entries_routed_to_sfx_bus() -> void:
	for i: int in _audio_manager._sfx_pool.size():
		var player: AudioStreamPlayer3D = _audio_manager._sfx_pool[i]
		assert_str(String(player.bus)).override_failure_message(
			"AC-3: Pool entry [%d] must have bus == &\"SFX\". Got: %s." % [i, player.bus]
		).is_equal("SFX")


## AC-3: Every SFX pool entry is a direct child of AudioManager.
func test_audiomanager_sfx_pool_entries_are_children_of_audio_manager() -> void:
	for i: int in _audio_manager._sfx_pool.size():
		var player: AudioStreamPlayer3D = _audio_manager._sfx_pool[i]
		assert_object(player.get_parent()).override_failure_message(
			"AC-3: Pool entry [%d] must be a direct child of AudioManager. "
			+ "Parent: %s." % [i, str(player.get_parent())]
		).is_equal(_audio_manager)


# ── AC-4: No AudioStreamPlayer routes to Master bus ───────────────────────

## AC-4: Recursive scene-tree walk under _root finds zero AudioStreamPlayer /
## AudioStreamPlayer3D nodes with bus == &"Master".
func test_audiomanager_no_audio_players_routed_to_master_bus() -> void:
	var offenders: Array[String] = []
	_collect_master_bus_players(_root, offenders)
	assert_int(offenders.size()).override_failure_message(
		"AC-4: Found AudioStreamPlayer(3D) nodes routed to Master bus — forbidden (GDD Rule 1). "
		+ "Offenders:\n  %s" % "\n  ".join(offenders)
	).is_equal(0)


## Recursively walks [node] and appends debug strings for any AudioStreamPlayer
## or AudioStreamPlayer3D whose bus property equals &"Master".
func _collect_master_bus_players(node: Node, out: Array[String]) -> void:
	if node is AudioStreamPlayer3D:
		var p3d: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		if p3d.bus == &"Master":
			out.append("%s (AudioStreamPlayer3D) bus=Master" % p3d.get_path())
	elif node is AudioStreamPlayer:
		var p2d: AudioStreamPlayer = node as AudioStreamPlayer
		if p2d.bus == &"Master":
			out.append("%s (AudioStreamPlayer) bus=Master" % p2d.get_path())
	for child: Node in node.get_children():
		_collect_master_bus_players(child, out)


# ── AC-5: Pool nodes freed when AudioManager is freed ─────────────────────

## AC-5: All pool AudioStreamPlayer3D refs become invalid after the parent root
## is freed (simulating game quit via queue_free on AudioManager's parent).
func test_audiomanager_pool_nodes_freed_with_audio_manager() -> void:
	# Arrange: capture pool references before free.
	var captured_players: Array[AudioStreamPlayer3D] = []
	for player: AudioStreamPlayer3D in _audio_manager._sfx_pool:
		captured_players.append(player)
	assert_int(captured_players.size()).override_failure_message(
		"AC-5 precondition: pool must contain 16 entries before free."
	).is_equal(AudioManager.SFX_POOL_SIZE)

	# Act: free the root (AudioManager and its children are freed with it).
	# queue_free() is processed at the end of the current frame; we await one
	# physics frame so the deferred free has been processed.
	_root.queue_free()
	await get_tree().process_frame

	# Assert: every captured player is now invalid (freed with the manager).
	var still_valid_count: int = 0
	for player: AudioStreamPlayer3D in captured_players:
		if is_instance_valid(player):
			still_valid_count += 1

	assert_int(still_valid_count).override_failure_message(
		"AC-5: All SFX pool nodes must be freed when AudioManager's parent is freed. "
		+ "%d / %d pool players are still valid (they must have been added as children of a different node)."
		% [still_valid_count, captured_players.size()]
	).is_equal(0)

	# Null out the fixture references — after_test's queue_free would double-free.
	_root = null
	_audio_manager = null
