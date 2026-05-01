# tests/unit/foundation/events_signal_taxonomy_test.gd
#
# Signal taxonomy test — events.gd built-in-type signal subset.
#
# PURPOSE
#   Proves that src/core/signal_bus/events.gd declares every in-scope signal
#   from ADR-0002 §Key Interfaces with the correct name, argument count, and
#   argument types. Also asserts that deferred signals (those requiring enum
#   types from consumer epics) are NOT present — accidental early declaration
#   would cause GDScript parse failures when the owning enum class does not
#   yet exist.
#
# WHAT IS TESTED
#   AC-3-A: Player domain signals present with correct signatures.
#   AC-3-B: Documents domain signals present with correct signatures.
#   AC-3-C: Mission domain signals present with correct signatures (incl. Cutscenes).
#   AC-3-D: Failure & Respawn domain signal present with correct signature.
#   AC-3-E: Dialogue domain signals present with correct signatures.
#   AC-3-F: Inventory domain signals present with correct signatures.
#   AC-3-G: Combat domain signals present with correct signatures.
#   AC-3-H: Civilian domain signal present with correct signature.
#   AC-3-I: Persistence domain signals present with correct signatures.
#   AC-3-J: Settings domain signals present with correct signatures.
#   Deferred check: deferred signals are absent from the bus.
#
# WHAT IS NOT TESTED HERE
#   - Structural purity (no func/var/const) — see events_purity_test.gd.
#   - Autoload registration + ordering — see events_autoload_registration_test.gd.
#   - Emission / delivery — see signal_bus_smoke_test.gd.
#
# IMPLEMENTATION NOTE
#   GdUnit4's test runner adds the test scene under the autoloads, so the
#   `Events` autoload (registered in project.godot) is already present in
#   the tree when tests run. No manual instantiation is required.
#
#   get_signal_list() returns Array[Dictionary]. Each entry has:
#     name     : StringName
#     args     : Array[Dictionary]  — each arg has `name`, `type` (Variant.Type int),
#                                     `class_name` (set when type == TYPE_OBJECT)
#
#   Variant.Type int values used (stable since Godot 4.0):
#     TYPE_NIL         = 0   — Variant (documented exception: setting_changed value)
#     TYPE_BOOL        = 1
#     TYPE_INT         = 2
#     TYPE_FLOAT       = 3
#     TYPE_STRING_NAME = 21
#     TYPE_VECTOR3     = 9
#     TYPE_OBJECT      = 24  — Node, Node3D, Resource (class_name distinguishes)
#
# GATE STATUS
#   Story SB-002 — Logic type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name EventsSignalTaxonomyTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the Events autoload node. Fails the test if it is not found.
func _get_events_node() -> SignalBusEvents:
	var node: Node = get_tree().root.get_node_or_null(^"Events")
	assert_object(node).is_not_null()
	return node as SignalBusEvents


## Builds a dictionary of signal_name -> signal_dict from get_signal_list().
## Filters out signals inherited from Node (those declared by built-in Node
## class itself — e.g., `ready`, `renamed`, `tree_entered`, `tree_exiting`,
## `tree_exited`, `child_entered_tree`, `child_exiting_tree`, `child_order_changed`,
## `script_changed`, `property_list_changed`). We isolate user-declared signals
## by collecting only signals NOT present on a plain bare Node.
func _build_signal_map(events: SignalBusEvents) -> Dictionary:
	var bare_node_signals: Dictionary = {}
	var bare: Node = Node.new()
	for sig: Dictionary in bare.get_signal_list():
		bare_node_signals[sig["name"]] = true
	bare.free()

	var result: Dictionary = {}
	for sig: Dictionary in events.get_signal_list():
		var sig_name: StringName = sig["name"]
		if not bare_node_signals.has(sig_name):
			result[sig_name] = sig
	return result


## Asserts that a signal with `signal_name` exists in `signal_map` and has
## argument types matching `expected_arg_types` (Array of Variant.Type ints).
## For TYPE_OBJECT args, only the arg count + TYPE_OBJECT presence are checked
## here. Use `_assert_signal_object_arg_class()` afterwards for the specific
## class_name (Node vs Node3D vs Resource discrimination) per code-review
## qa-tester finding (2026-04-30 — SB-002 regression-fence hardening).
func _assert_signal_signature(
		signal_map: Dictionary,
		signal_name: StringName,
		expected_arg_types: Array[int]) -> void:

	assert_bool(signal_map.has(signal_name)).override_failure_message(
			"Signal '%s' missing from Events" % signal_name
	).is_true()

	if not signal_map.has(signal_name):
		return

	var sig: Dictionary = signal_map[signal_name]
	var args: Array = sig["args"]

	assert_int(args.size()).override_failure_message(
			"Signal '%s' has %d args, expected %d" % [signal_name, args.size(), expected_arg_types.size()]
	).is_equal(expected_arg_types.size())

	for i: int in range(min(args.size(), expected_arg_types.size())):
		var actual_type: int = args[i]["type"]
		var expected_type: int = expected_arg_types[i]
		assert_int(actual_type).override_failure_message(
				"Signal '%s' arg[%d] type mismatch: got %d, expected %d" % [
					signal_name, i, actual_type, expected_type]
		).is_equal(expected_type)


## Asserts the class_name of a TYPE_OBJECT argument at `arg_index` of
## `signal_name` matches `expected_class_name` (e.g., "Node", "Node3D",
## "Resource"). Required because `get_signal_list()` reports all object types
## as TYPE_OBJECT — only `class_name` distinguishes Node from Node3D from
## Resource. Without this check, `weapon: Resource` and `weapon: Node` would
## pass identically. Per code-review qa-tester (2026-04-30 — SB-002).
func _assert_signal_object_arg_class(
		signal_map: Dictionary,
		signal_name: StringName,
		arg_index: int,
		expected_class_name: String) -> void:

	if not signal_map.has(signal_name):
		return  # Earlier _assert_signal_signature already failed loudly.

	var sig: Dictionary = signal_map[signal_name]
	var args: Array = sig["args"]

	if arg_index >= args.size():
		assert_bool(false).override_failure_message(
				"Signal '%s' arg[%d] does not exist (only %d args)" % [
					signal_name, arg_index, args.size()]
		).is_true()
		return

	var arg: Dictionary = args[arg_index]
	var actual_class: String = String(arg["class_name"])
	assert_str(actual_class).override_failure_message(
			"Signal '%s' arg[%d] class_name mismatch: got '%s', expected '%s'" % [
				signal_name, arg_index, actual_class, expected_class_name]
	).is_equal(expected_class_name)


# ---------------------------------------------------------------------------
# Tests — AC-3-A: Player domain
# ---------------------------------------------------------------------------

## player_interacted(target: Node3D) and player_footstep(surface: StringName, noise_radius_m: float)
## must be declared with the correct signatures.
## Covers ADR-0002 §Key Interfaces Player domain.
func test_events_taxonomy_player_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — player_interacted(target: Node3D)
	_assert_signal_signature(signal_map, &"player_interacted", [TYPE_OBJECT])
	_assert_signal_object_arg_class(signal_map, &"player_interacted", 0, "Node3D")

	# Act + Assert — player_footstep(surface: StringName, noise_radius_m: float)
	_assert_signal_signature(signal_map, &"player_footstep", [TYPE_STRING_NAME, TYPE_FLOAT])


# ---------------------------------------------------------------------------
# Tests — AC-3-B: Documents domain
# ---------------------------------------------------------------------------

## document_collected, document_opened, document_closed must be declared
## with single StringName argument.
## Covers ADR-0002 §Key Interfaces Documents domain.
func test_events_taxonomy_documents_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert
	_assert_signal_signature(signal_map, &"document_collected", [TYPE_STRING_NAME])
	_assert_signal_signature(signal_map, &"document_opened", [TYPE_STRING_NAME])
	_assert_signal_signature(signal_map, &"document_closed", [TYPE_STRING_NAME])


# ---------------------------------------------------------------------------
# Tests — AC-3-C: Mission domain (incl. Cutscenes domain per ADR-0002)
# ---------------------------------------------------------------------------

## Mission signals: objective_started, objective_completed, mission_started,
## mission_completed, scripted_dialogue_trigger, cutscene_started, cutscene_ended.
## section_entered/exited are deferred (LevelStreamingService.TransitionReason).
## Covers ADR-0002 §Key Interfaces Mission domain + Cutscenes domain.
func test_events_taxonomy_mission_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — objective_started(objective_id: StringName)
	_assert_signal_signature(signal_map, &"objective_started", [TYPE_STRING_NAME])

	# Act + Assert — objective_completed(objective_id: StringName)
	_assert_signal_signature(signal_map, &"objective_completed", [TYPE_STRING_NAME])

	# Act + Assert — mission_started(mission_id: StringName)
	_assert_signal_signature(signal_map, &"mission_started", [TYPE_STRING_NAME])

	# Act + Assert — mission_completed(mission_id: StringName)
	_assert_signal_signature(signal_map, &"mission_completed", [TYPE_STRING_NAME])

	# Act + Assert — scripted_dialogue_trigger(scene_id: StringName)
	_assert_signal_signature(signal_map, &"scripted_dialogue_trigger", [TYPE_STRING_NAME])

	# Act + Assert — cutscene_started(scene_id: StringName) [Cutscenes domain per ADR-0002]
	_assert_signal_signature(signal_map, &"cutscene_started", [TYPE_STRING_NAME])

	# Act + Assert — cutscene_ended(scene_id: StringName) [Cutscenes domain per ADR-0002]
	_assert_signal_signature(signal_map, &"cutscene_ended", [TYPE_STRING_NAME])


# ---------------------------------------------------------------------------
# Tests — AC-3-D: Failure & Respawn domain
# ---------------------------------------------------------------------------

## respawn_triggered(section_id: StringName) must be declared.
## Covers ADR-0002 §Key Interfaces Failure / Respawn domain.
func test_events_taxonomy_failure_respawn_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — respawn_triggered(section_id: StringName)
	_assert_signal_signature(signal_map, &"respawn_triggered", [TYPE_STRING_NAME])


# ---------------------------------------------------------------------------
# Tests — AC-3-E: Dialogue domain
# ---------------------------------------------------------------------------

## dialogue_line_started and dialogue_line_finished must be declared with
## the correct signatures.
## Covers ADR-0002 §Key Interfaces Dialogue domain.
func test_events_taxonomy_dialogue_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — dialogue_line_started(speaker_id: StringName, line_id: StringName)
	_assert_signal_signature(signal_map, &"dialogue_line_started", [TYPE_STRING_NAME, TYPE_STRING_NAME])

	# Act + Assert — dialogue_line_finished(speaker_id: StringName)
	_assert_signal_signature(signal_map, &"dialogue_line_finished", [TYPE_STRING_NAME])


# ---------------------------------------------------------------------------
# Tests — AC-3-F: Inventory domain
# ---------------------------------------------------------------------------

## Inventory signals: gadget_equipped, gadget_used, weapon_switched,
## ammo_changed, gadget_activation_rejected, weapon_dry_fire_click.
## Covers ADR-0002 §Key Interfaces Inventory domain.
func test_events_taxonomy_inventory_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — gadget_equipped(gadget_id: StringName)
	_assert_signal_signature(signal_map, &"gadget_equipped", [TYPE_STRING_NAME])

	# Act + Assert — gadget_used(gadget_id: StringName, position: Vector3)
	_assert_signal_signature(signal_map, &"gadget_used", [TYPE_STRING_NAME, TYPE_VECTOR3])

	# Act + Assert — weapon_switched(weapon_id: StringName)
	_assert_signal_signature(signal_map, &"weapon_switched", [TYPE_STRING_NAME])

	# Act + Assert — ammo_changed(weapon_id: StringName, current: int, reserve: int)
	_assert_signal_signature(signal_map, &"ammo_changed", [TYPE_STRING_NAME, TYPE_INT, TYPE_INT])

	# Act + Assert — gadget_activation_rejected(gadget_id: StringName)
	_assert_signal_signature(signal_map, &"gadget_activation_rejected", [TYPE_STRING_NAME])

	# Act + Assert — weapon_dry_fire_click(weapon_id: StringName)
	_assert_signal_signature(signal_map, &"weapon_dry_fire_click", [TYPE_STRING_NAME])


# ---------------------------------------------------------------------------
# Tests — AC-3-G: Combat domain
# ---------------------------------------------------------------------------

## Combat signals using only built-in types. player_died deferred.
## Covers ADR-0002 §Key Interfaces Combat domain (built-in subset).
func test_events_taxonomy_combat_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — player_health_changed(current: float, max_health: float)
	_assert_signal_signature(signal_map, &"player_health_changed", [TYPE_FLOAT, TYPE_FLOAT])

	# Act + Assert — enemy_damaged(enemy: Node, amount: float, source: Node)
	_assert_signal_signature(signal_map, &"enemy_damaged", [TYPE_OBJECT, TYPE_FLOAT, TYPE_OBJECT])
	_assert_signal_object_arg_class(signal_map, &"enemy_damaged", 0, "Node")
	_assert_signal_object_arg_class(signal_map, &"enemy_damaged", 2, "Node")

	# Act + Assert — enemy_killed(enemy: Node, killer: Node)
	_assert_signal_signature(signal_map, &"enemy_killed", [TYPE_OBJECT, TYPE_OBJECT])
	_assert_signal_object_arg_class(signal_map, &"enemy_killed", 0, "Node")
	_assert_signal_object_arg_class(signal_map, &"enemy_killed", 1, "Node")

	# Act + Assert — weapon_fired(weapon: Resource, position: Vector3, direction: Vector3)
	# Resource (not Node) is intentional per story Implementation Note 4.
	_assert_signal_signature(signal_map, &"weapon_fired", [TYPE_OBJECT, TYPE_VECTOR3, TYPE_VECTOR3])
	_assert_signal_object_arg_class(signal_map, &"weapon_fired", 0, "Resource")

	# Act + Assert — player_damaged(amount: float, source: Node, is_critical: bool)
	_assert_signal_signature(signal_map, &"player_damaged", [TYPE_FLOAT, TYPE_OBJECT, TYPE_BOOL])
	_assert_signal_object_arg_class(signal_map, &"player_damaged", 1, "Node")


# ---------------------------------------------------------------------------
# Tests — AC-3-H: Civilian domain
# ---------------------------------------------------------------------------

## civilian_panicked(civilian: Node, cause_position: Vector3) must be declared.
## civilian_witnessed_event deferred (needs CivilianAI.WitnessEventType).
## Covers ADR-0002 §Key Interfaces Civilian domain (built-in subset).
func test_events_taxonomy_civilian_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — civilian_panicked(civilian: Node, cause_position: Vector3)
	_assert_signal_signature(signal_map, &"civilian_panicked", [TYPE_OBJECT, TYPE_VECTOR3])
	_assert_signal_object_arg_class(signal_map, &"civilian_panicked", 0, "Node")


# ---------------------------------------------------------------------------
# Tests — AC-3-I: Persistence domain
# ---------------------------------------------------------------------------

## game_saved, game_loaded, and save_failed must be declared. save_failed uses
## an int payload (cast from SaveLoadService.FailureReason at emit time) per
## the signal-bus comment — this avoids a circular Events ↔ SaveLoadService
## import while preserving type semantics for subscribers.
## Covers ADR-0002 §Key Interfaces Persistence domain (built-in subset).
func test_events_taxonomy_persistence_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — game_saved(slot: int, section_id: StringName)
	_assert_signal_signature(signal_map, &"game_saved", [TYPE_INT, TYPE_STRING_NAME])

	# Act + Assert — game_loaded(slot: int)
	_assert_signal_signature(signal_map, &"game_loaded", [TYPE_INT])

	# Act + Assert — save_failed(reason: int)
	# Reason is the int value of SaveLoadService.FailureReason, declared as
	# bare int so the signal bus does not depend on the SaveLoadService class.
	_assert_signal_signature(signal_map, &"save_failed", [TYPE_INT])


# ---------------------------------------------------------------------------
# Tests — AC-3-J: Settings domain
# ---------------------------------------------------------------------------

## setting_changed (Variant exception per ADR-0002 IG 7) and settings_loaded
## (no payload) must be declared.
## Covers ADR-0002 §Key Interfaces Settings domain.
func test_events_taxonomy_settings_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — setting_changed(category: StringName, name: StringName, value: Variant)
	# The third arg uses TYPE_NIL (0) which represents Variant — the SOLE documented
	# Variant exception per ADR-0002 IG 7.
	_assert_signal_signature(signal_map, &"setting_changed",
			[TYPE_STRING_NAME, TYPE_STRING_NAME, TYPE_NIL])

	# Act + Assert — settings_loaded() — no payload
	_assert_signal_signature(signal_map, &"settings_loaded", [])


# ---------------------------------------------------------------------------
# Tests — Deferred signals must NOT be present
# ---------------------------------------------------------------------------

## Signals depending on enum types from consumer epics must not appear on
## the bus. Their premature presence would cause GDScript parse errors and
## prevent the Events autoload from registering.
## Covers: ADR-0002 §Key Interfaces deferred subset.
func test_events_taxonomy_deferred_signals_not_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# save_failed is no longer deferred — re-added in SL-002 with `int` payload
	# (cast from SaveLoadService.FailureReason at emit sites). See the
	# Persistence domain test above for its signature assertion.

	# Deferred — Combat epic (needs CombatSystemNode.DeathCause)
	assert_bool(signal_map.has(&"player_died")).override_failure_message(
			"Deferred signal 'player_died' must not be declared until CombatSystemNode.DeathCause exists"
	).is_false()

	# Deferred — Civilian AI epic (needs CivilianAI.WitnessEventType)
	assert_bool(signal_map.has(&"civilian_witnessed_event")).override_failure_message(
			"Deferred signal 'civilian_witnessed_event' must not be declared until CivilianAI.WitnessEventType exists"
	).is_false()

	# Deferred — Level Streaming epic (needs LevelStreamingService.TransitionReason)
	assert_bool(signal_map.has(&"section_entered")).override_failure_message(
			"Deferred signal 'section_entered' must not be declared until LevelStreamingService.TransitionReason exists"
	).is_false()

	assert_bool(signal_map.has(&"section_exited")).override_failure_message(
			"Deferred signal 'section_exited' must not be declared until LevelStreamingService.TransitionReason exists"
	).is_false()

	# ui_context_changed is no longer deferred — re-added in IN-002 with `int` payload
	# (cast from InputContextStack.Context at emit sites). See the UI domain test
	# below for its signature assertion. Same precedent as save_failed in SL-002.

	# Deferred — AI / Stealth epic (needs StealthAI.* enums)
	assert_bool(signal_map.has(&"alert_state_changed")).override_failure_message(
			"Deferred signal 'alert_state_changed' must not be declared until StealthAI.AlertState exists"
	).is_false()

	assert_bool(signal_map.has(&"actor_became_alerted")).override_failure_message(
			"Deferred signal 'actor_became_alerted' must not be declared until StealthAI.AlertCause exists"
	).is_false()

	assert_bool(signal_map.has(&"actor_lost_target")).override_failure_message(
			"Deferred signal 'actor_lost_target' must not be declared until StealthAI.Severity exists"
	).is_false()

	assert_bool(signal_map.has(&"takedown_performed")).override_failure_message(
			"Deferred signal 'takedown_performed' must not be declared until StealthAI.TakedownType exists"
	).is_false()

	assert_bool(signal_map.has(&"guard_incapacitated")).override_failure_message(
			"Deferred signal 'guard_incapacitated' belongs to AI/Stealth epic"
	).is_false()

	assert_bool(signal_map.has(&"guard_woke_up")).override_failure_message(
			"Deferred signal 'guard_woke_up' belongs to AI/Stealth epic"
	).is_false()


# ---------------------------------------------------------------------------
# Tests — UI domain
# ---------------------------------------------------------------------------

## ui_context_changed must be declared. Uses int payload (cast from
## InputContextStack.Context at emit sites) to avoid the Events ↔
## InputContextStack circular import — same pattern as save_failed.
## Covers ADR-0002 §Key Interfaces UI domain.
func test_events_taxonomy_ui_domain_signals_present() -> void:
	# Arrange
	var events: SignalBusEvents = _get_events_node()
	var signal_map: Dictionary = _build_signal_map(events)

	# Act + Assert — ui_context_changed(new_ctx: int, old_ctx: int)
	_assert_signal_signature(signal_map, &"ui_context_changed", [TYPE_INT, TYPE_INT])
