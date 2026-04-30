# res://src/core/signal_bus/events.gd
#
# Signal Bus — typed-signal hub. Per ADR-0002 (Signal Bus + Event Taxonomy).
# Registered as autoload key `Events` at line 1 of project.godot per ADR-0007
# §Key Interfaces.
#
# class_name / autoload-key split (per ADR-0002 OQ-CD-1 amendment):
#   class_name = SignalBusEvents  (used for parse-time references like
#                                  SignalBusEvents.SomeEnum if added)
#   autoload key = Events         (used for emit/connect call sites:
#                                  Events.player_damaged.emit(...))
#
# Subscribers connect via Events.<signal>.connect(<callable>) at their own
# _ready(). Per ADR-0007 §Cross-Autoload Reference Safety, only autoloads at
# earlier line numbers may be referenced from this script's _ready().
#
# ─── SKELETON STATUS ──────────────────────────────────────────────────────
# SB-002 (2026-04-30): Full built-in-type taxonomy declared. Deferred signals
# (those requiring enum types from StealthAI, CombatSystemNode, LevelStreamingService,
# CivilianAI, SaveLoad, InputContext) land in paired commits with their
# consumer epics. See ADR-0002 §Key Interfaces for the full intended 43-signal list.

class_name SignalBusEvents extends Node

# ─── Player domain ────────────────────────────────────────────────────────
signal player_interacted(target: Node3D)
signal player_footstep(surface: StringName, noise_radius_m: float)

# ─── Documents domain ─────────────────────────────────────────────────────
signal document_collected(document_id: StringName)
signal document_opened(document_id: StringName)
signal document_closed(document_id: StringName)

# ─── Mission domain ───────────────────────────────────────────────────────
# section_entered/exited deferred to Level Streaming epic (needs LevelStreamingService.TransitionReason)
signal objective_started(objective_id: StringName)
signal objective_completed(objective_id: StringName)
signal mission_started(mission_id: StringName)
signal mission_completed(mission_id: StringName)
signal scripted_dialogue_trigger(scene_id: StringName)

# ─── Cutscenes domain ─────────────────────────────────────────────────────
signal cutscene_started(scene_id: StringName)
signal cutscene_ended(scene_id: StringName)

# ─── Failure & Respawn domain ─────────────────────────────────────────────
signal respawn_triggered(section_id: StringName)

# ─── Dialogue domain ──────────────────────────────────────────────────────
signal dialogue_line_started(speaker_id: StringName, line_id: StringName)
signal dialogue_line_finished(speaker_id: StringName)

# ─── Inventory domain ─────────────────────────────────────────────────────
signal gadget_equipped(gadget_id: StringName)
signal gadget_used(gadget_id: StringName, position: Vector3)
signal weapon_switched(weapon_id: StringName)
signal ammo_changed(weapon_id: StringName, current: int, reserve: int)
signal gadget_activation_rejected(gadget_id: StringName)
signal weapon_dry_fire_click(weapon_id: StringName)

# ─── Combat domain ────────────────────────────────────────────────────────
# player_died(cause: CombatSystemNode.DeathCause) deferred — needs Combat epic enum
signal player_health_changed(current: float, max_health: float)
signal enemy_damaged(enemy: Node, amount: float, source: Node)
signal enemy_killed(enemy: Node, killer: Node)
signal weapon_fired(weapon: Resource, position: Vector3, direction: Vector3)
signal player_damaged(amount: float, source: Node, is_critical: bool)

# ─── Civilian domain ──────────────────────────────────────────────────────
# civilian_witnessed_event deferred — needs CivilianAI.WitnessEventType
signal civilian_panicked(civilian: Node, cause_position: Vector3)

# ─── Persistence domain ───────────────────────────────────────────────────
# save_failed(reason: SaveLoad.FailureReason) deferred to Save/Load epic
signal game_saved(slot: int, section_id: StringName)
signal game_loaded(slot: int)

# ─── Settings domain ──────────────────────────────────────────────────────
signal setting_changed(category: StringName, name: StringName, value: Variant)
signal settings_loaded()

# ─── UI domain (deferred — ui_context_changed needs InputContext.Context) ──
# ─── AI / Stealth domain (deferred — all signals reference StealthAI.* enums) ──
