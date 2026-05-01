# res://src/core/signal_bus/event_logger.gd
#
# EventLogger — debug-only signal-tracing autoload. Per ADR-0002 §Implementation
# Guideline 8 + ADR-0007 §Cross-Autoload Reference Safety. Registered as autoload
# key `EventLogger` at line 2 of project.godot.
#
# In debug builds, every Events.* emission is printed as:
#   [NNNNN ms] [EventLogger] signal_name(arg1, arg2, ...)
#
# In non-debug (release) builds, _ready() calls queue_free() immediately and
# returns — no signals are connected and no log lines appear.
#
# Per ADR-0007 §Cross-Autoload Reference Safety rule 2: this _ready() may
# reference autoloads at earlier line numbers. Events is at line 1; this
# script is at line 2. Reference is safe.
#
# FORBIDDEN: production code must NOT call any EventLogger method. EventLogger
# is a pure debug subscriber with no public API beyond the Node lifecycle.
#
# class_name / autoload-key split (mirrors the Events/SignalBusEvents pattern
# per ADR-0002 OQ-CD-1 amendment):
#   class_name = SignalBusEventLogger  (used for parse-time references and
#                                       instanceof checks in tests)
#   autoload key = EventLogger         (used in scene tree: /root/EventLogger)
# This split prevents the "class hides an autoload singleton" parser error
# that occurs when class_name matches the autoload key exactly.

class_name SignalBusEventLogger
extends Node

## Prefix used in every log line.
const LOG_PREFIX: String = "[EventLogger]"

## Records each active connection for clean disconnect in _exit_tree.
## Each entry: { "signal_ref": Signal, "callable": Callable }
var _connections: Array[Dictionary] = []


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	_connect_all()


## Disconnects all connections registered in _ready().
## Called when the node exits the scene tree (e.g., at app shutdown or if
## queue_free() is called externally). Guards each disconnect with
## is_connected() per Control Manifest Foundation requirements.
func _exit_tree() -> void:
	# Dictionary values are untyped (no typed Dictionary in GDScript yet);
	# explicit `as Signal` / `as Callable` casts are required.
	for entry: Dictionary in _connections:
		var sig: Signal = entry["signal_ref"] as Signal
		var cb: Callable = entry["callable"] as Callable
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_connections.clear()


# ---------------------------------------------------------------------------
# Pure utility — exposed for unit testing only (not for production callers)
# ---------------------------------------------------------------------------

## Formats a log line string without printing it. Used by tests to assert
## format correctness without stdout capture.
##
## Example output: "[12345 ms] [EventLogger] player_health_changed(50.0, 100.0)"
func _format_log_line(signal_name: StringName, args: Array[Variant]) -> String:
	var timestamp_ms: int = Time.get_ticks_msec()
	var args_str: String = ", ".join(args.map(func(a: Variant) -> String: return str(a)))
	return "[%d ms] %s %s(%s)" % [timestamp_ms, LOG_PREFIX, signal_name, args_str]


# ---------------------------------------------------------------------------
# Private — connection bookkeeping
# ---------------------------------------------------------------------------

func _register(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_connections.append({"signal_ref": sig, "callable": cb})


func _connect_all() -> void:
	# Player domain
	_register(Events.player_interacted, _on_player_interacted)
	_register(Events.player_footstep, _on_player_footstep)
	# Documents domain
	_register(Events.document_collected, _on_document_collected)
	_register(Events.document_opened, _on_document_opened)
	_register(Events.document_closed, _on_document_closed)
	# Mission domain
	_register(Events.objective_started, _on_objective_started)
	_register(Events.objective_completed, _on_objective_completed)
	_register(Events.mission_started, _on_mission_started)
	_register(Events.mission_completed, _on_mission_completed)
	_register(Events.scripted_dialogue_trigger, _on_scripted_dialogue_trigger)
	# Cutscenes domain
	_register(Events.cutscene_started, _on_cutscene_started)
	_register(Events.cutscene_ended, _on_cutscene_ended)
	# Failure & Respawn domain
	_register(Events.respawn_triggered, _on_respawn_triggered)
	# Dialogue domain
	_register(Events.dialogue_line_started, _on_dialogue_line_started)
	_register(Events.dialogue_line_finished, _on_dialogue_line_finished)
	# Inventory domain
	_register(Events.gadget_equipped, _on_gadget_equipped)
	_register(Events.gadget_used, _on_gadget_used)
	_register(Events.weapon_switched, _on_weapon_switched)
	_register(Events.ammo_changed, _on_ammo_changed)
	_register(Events.gadget_activation_rejected, _on_gadget_activation_rejected)
	_register(Events.weapon_dry_fire_click, _on_weapon_dry_fire_click)
	# Combat domain
	_register(Events.player_health_changed, _on_player_health_changed)
	_register(Events.enemy_damaged, _on_enemy_damaged)
	_register(Events.enemy_killed, _on_enemy_killed)
	_register(Events.weapon_fired, _on_weapon_fired)
	_register(Events.player_damaged, _on_player_damaged)
	# Civilian domain
	_register(Events.civilian_panicked, _on_civilian_panicked)
	# Persistence domain
	_register(Events.save_failed, _on_save_failed)
	_register(Events.game_saved, _on_game_saved)
	_register(Events.game_loaded, _on_game_loaded)
	# Settings domain
	_register(Events.setting_changed, _on_setting_changed)
	_register(Events.settings_loaded, _on_settings_loaded)
	# UI domain
	_register(Events.ui_context_changed, _on_ui_context_changed)


# ---------------------------------------------------------------------------
# Signal callbacks — Player domain
# ---------------------------------------------------------------------------

func _on_player_interacted(target: Node3D) -> void:
	if not is_instance_valid(target):
		print(_format_log_line(&"player_interacted", ["<null/freed>"]))
		return
	print(_format_log_line(&"player_interacted", [target]))

func _on_player_footstep(surface: StringName, noise_radius_m: float) -> void:
	print(_format_log_line(&"player_footstep", [surface, noise_radius_m]))


# ---------------------------------------------------------------------------
# Signal callbacks — Documents domain
# ---------------------------------------------------------------------------

func _on_document_collected(document_id: StringName) -> void:
	print(_format_log_line(&"document_collected", [document_id]))

func _on_document_opened(document_id: StringName) -> void:
	print(_format_log_line(&"document_opened", [document_id]))

func _on_document_closed(document_id: StringName) -> void:
	print(_format_log_line(&"document_closed", [document_id]))


# ---------------------------------------------------------------------------
# Signal callbacks — Mission domain
# ---------------------------------------------------------------------------

func _on_objective_started(objective_id: StringName) -> void:
	print(_format_log_line(&"objective_started", [objective_id]))

func _on_objective_completed(objective_id: StringName) -> void:
	print(_format_log_line(&"objective_completed", [objective_id]))

func _on_mission_started(mission_id: StringName) -> void:
	print(_format_log_line(&"mission_started", [mission_id]))

func _on_mission_completed(mission_id: StringName) -> void:
	print(_format_log_line(&"mission_completed", [mission_id]))

func _on_scripted_dialogue_trigger(scene_id: StringName) -> void:
	print(_format_log_line(&"scripted_dialogue_trigger", [scene_id]))


# ---------------------------------------------------------------------------
# Signal callbacks — Cutscenes domain
# ---------------------------------------------------------------------------

func _on_cutscene_started(scene_id: StringName) -> void:
	print(_format_log_line(&"cutscene_started", [scene_id]))

func _on_cutscene_ended(scene_id: StringName) -> void:
	print(_format_log_line(&"cutscene_ended", [scene_id]))


# ---------------------------------------------------------------------------
# Signal callbacks — Failure & Respawn domain
# ---------------------------------------------------------------------------

func _on_respawn_triggered(section_id: StringName) -> void:
	print(_format_log_line(&"respawn_triggered", [section_id]))


# ---------------------------------------------------------------------------
# Signal callbacks — Dialogue domain
# ---------------------------------------------------------------------------

func _on_dialogue_line_started(speaker_id: StringName, line_id: StringName) -> void:
	print(_format_log_line(&"dialogue_line_started", [speaker_id, line_id]))

func _on_dialogue_line_finished(speaker_id: StringName) -> void:
	print(_format_log_line(&"dialogue_line_finished", [speaker_id]))


# ---------------------------------------------------------------------------
# Signal callbacks — Inventory domain
# ---------------------------------------------------------------------------

func _on_gadget_equipped(gadget_id: StringName) -> void:
	print(_format_log_line(&"gadget_equipped", [gadget_id]))

func _on_gadget_used(gadget_id: StringName, position: Vector3) -> void:
	print(_format_log_line(&"gadget_used", [gadget_id, position]))

func _on_weapon_switched(weapon_id: StringName) -> void:
	print(_format_log_line(&"weapon_switched", [weapon_id]))

func _on_ammo_changed(weapon_id: StringName, current: int, reserve: int) -> void:
	print(_format_log_line(&"ammo_changed", [weapon_id, current, reserve]))

func _on_gadget_activation_rejected(gadget_id: StringName) -> void:
	print(_format_log_line(&"gadget_activation_rejected", [gadget_id]))

func _on_weapon_dry_fire_click(weapon_id: StringName) -> void:
	print(_format_log_line(&"weapon_dry_fire_click", [weapon_id]))


# ---------------------------------------------------------------------------
# Signal callbacks — Combat domain
# ---------------------------------------------------------------------------

func _on_player_health_changed(current: float, max_health: float) -> void:
	print(_format_log_line(&"player_health_changed", [current, max_health]))

func _on_enemy_damaged(enemy: Node, amount: float, source: Node) -> void:
	var enemy_repr: Variant = enemy if is_instance_valid(enemy) else "<null/freed>"
	var source_repr: Variant = source if is_instance_valid(source) else "<null/freed>"
	print(_format_log_line(&"enemy_damaged", [enemy_repr, amount, source_repr]))

func _on_enemy_killed(enemy: Node, killer: Node) -> void:
	var enemy_repr: Variant = enemy if is_instance_valid(enemy) else "<null/freed>"
	var killer_repr: Variant = killer if is_instance_valid(killer) else "<null/freed>"
	print(_format_log_line(&"enemy_killed", [enemy_repr, killer_repr]))

func _on_weapon_fired(weapon: Resource, position: Vector3, direction: Vector3) -> void:
	print(_format_log_line(&"weapon_fired", [weapon, position, direction]))

func _on_player_damaged(amount: float, source: Node, is_critical: bool) -> void:
	print(_format_log_line(&"player_damaged", [amount, source, is_critical]))


# ---------------------------------------------------------------------------
# Signal callbacks — Civilian domain
# ---------------------------------------------------------------------------

func _on_civilian_panicked(civilian: Node, cause_position: Vector3) -> void:
	if not is_instance_valid(civilian):
		print(_format_log_line(&"civilian_panicked", ["<null/freed>", cause_position]))
		return
	print(_format_log_line(&"civilian_panicked", [civilian, cause_position]))


# ---------------------------------------------------------------------------
# Signal callbacks — Persistence domain
# ---------------------------------------------------------------------------

func _on_save_failed(reason: int) -> void:
	print(_format_log_line(&"save_failed", [reason]))

func _on_game_saved(slot: int, section_id: StringName) -> void:
	print(_format_log_line(&"game_saved", [slot, section_id]))

func _on_game_loaded(slot: int) -> void:
	print(_format_log_line(&"game_loaded", [slot]))


# ---------------------------------------------------------------------------
# Signal callbacks — Settings domain
# ---------------------------------------------------------------------------

func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
	print(_format_log_line(&"setting_changed", [category, name, value]))

func _on_settings_loaded() -> void:
	print(_format_log_line(&"settings_loaded", []))


# ---------------------------------------------------------------------------
# Signal callbacks — UI domain
# ---------------------------------------------------------------------------

func _on_ui_context_changed(new_ctx: int, old_ctx: int) -> void:
	print(_format_log_line(&"ui_context_changed", [new_ctx, old_ctx]))
