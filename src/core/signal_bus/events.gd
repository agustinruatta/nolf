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
# SB-002 (2026-04-30): Full built-in-type taxonomy declared.
# SAI-002 (2026-05-02): SAI-domain signals added (StealthAI.* enums available).
# Remaining deferred signals (those requiring enum types from CombatSystemNode
# and CivilianAI) land in paired commits with their consumer epics. See
# ADR-0002 §Key Interfaces for the full intended 43-signal list.

class_name SignalBusEvents extends Node

# ─── Player domain ────────────────────────────────────────────────────────
signal player_interacted(target: Node3D)
signal player_footstep(surface: StringName, noise_radius_m: float)

# ─── Documents domain ─────────────────────────────────────────────────────
signal document_collected(document_id: StringName)
signal document_opened(document_id: StringName)
signal document_closed(document_id: StringName)

# ─── Mission domain ───────────────────────────────────────────────────────
# Section transition signals (Level Streaming epic LS-002).
# `reason` is LevelStreamingService.TransitionReason — declared here as int to
# avoid Events↔LSS circular import (same pattern as ui_context_changed below).
# Subscribers cast: `var r := reason as LevelStreamingService.TransitionReason`.
signal section_entered(section_id: StringName, reason: int)
signal section_exited(section_id: StringName, reason: int)
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
# player_died.cause is typed as `int` (not CombatSystemNode.DeathCause) per
# the cross-autoload convention (same precedent as save_failed.reason and
# ui_context_changed.new_ctx). Subscribers cast at the receive site:
#   var c := cause as CombatSystemNode.DeathCause
# Wired in PC-006 (TR-PC-010 + TR-PC-015).
signal player_health_changed(current: float, max_health: float)
signal enemy_damaged(enemy: Node, amount: float, source: Node)
signal enemy_killed(enemy: Node, killer: Node)
signal weapon_fired(weapon: Resource, position: Vector3, direction: Vector3)
signal player_damaged(amount: float, source: Node, is_critical: bool)
signal player_died(cause: int)

# ─── Civilian domain ──────────────────────────────────────────────────────
# civilian_witnessed_event deferred — needs CivilianAI.WitnessEventType
signal civilian_panicked(civilian: Node, cause_position: Vector3)

# ─── Persistence domain ───────────────────────────────────────────────────
# reason is SaveLoadService.FailureReason (int enum) — owned by SaveLoadService
# per ADR-0003 §ADR Dependencies + ADR-0002 enum-ownership rule. Declared here
# as int because the signal bus must not import SaveLoadService directly.
signal save_failed(reason: int)
signal game_saved(slot: int, section_id: StringName)
signal game_loaded(slot: int)

# ─── Settings domain ──────────────────────────────────────────────────────
signal setting_changed(category: StringName, name: StringName, value: Variant)
signal settings_loaded()

# ─── UI domain ────────────────────────────────────────────────────────────
# InputContextStack.Context enum value cast to int at emit sites — avoids the
# Events ↔ InputContextStack circular import (same pattern as save_failed).
signal ui_context_changed(new_ctx: int, old_ctx: int)

# ─── AI / Stealth domain — 6 SAI signals (TR-SAI-003) ──────────────────────
# Subscribers wired in SAI-008 (audio stinger). guard_incapacitated.cause is
# typed as `int` (not CombatSystemNode.DamageType) per the cross-autoload
# convention — SAI does not import CombatSystemNode (ADR-0007).
signal alert_state_changed(actor: Node, old_state: StealthAI.AlertState, new_state: StealthAI.AlertState, severity: StealthAI.Severity)
signal actor_became_alerted(actor: Node, cause: StealthAI.AlertCause, source_position: Vector3, severity: StealthAI.Severity)
signal actor_lost_target(actor: Node, severity: StealthAI.Severity)
signal takedown_performed(actor: Node, attacker: Node, takedown_type: StealthAI.TakedownType)
signal guard_incapacitated(guard: Node, cause: int)
signal guard_woke_up(guard: Node)
