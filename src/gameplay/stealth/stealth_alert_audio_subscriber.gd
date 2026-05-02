# res://src/gameplay/stealth/stealth_alert_audio_subscriber.gd
#
# StealthAlertAudioSubscriber — Subscribes to SAI-domain Events signals
# (alert_state_changed + actor_became_alerted) and dispatches the brass-punch
# stinger SFX on MAJOR-severity transitions.
#
# Architectural note: This file is the VS-tier subscriber node per Story SAI-008
# Implementation Notes ("a minimal stub. A full AudioManager autoload is out of
# scope for VS — use a scene-local subscriber node"). It is co-located with
# stealth-ai source files because it consumes SAI-domain signals exclusively
# (TR-SAI-003 / TR-SAI-004). When the full audio rewrite lands post-VS, this
# subscriber's logic will migrate into AudioManager's _on_actor_became_alerted
# handler (currently a stub) and this file may be removed.
#
# SUBSCRIBER-ONLY INVARIANT (GDD Rule 9 + ADR-0002):
#   This node NEVER emits Events signals — it only subscribes.
#
# RESPONSIBILITIES (SAI-008 ACs):
#   AC-1: Connect to actor_became_alerted + alert_state_changed in _ready;
#         disconnect in _exit_tree with is_connected guards (ADR-0002 IG 3).
#   AC-2: Severity-gated stinger — MAJOR fires brass-punch SFX at actor.global_position;
#         MINOR is silent (Pillar 1 comedy preservation).
#   AC-3: Per-guard alert state dictionary; same-state transitions are no-ops.
#   AC-2/AC-3: is_instance_valid(actor) guards before any property access (ADR-0002 IG 4).
#
# Implements: Story SAI-008 (TR-SAI-003, TR-SAI-004)
# GDD: design/gdd/stealth-ai.md §Interactions (Audio row) + §Detailed Rules (Severity rule)
# ADR: ADR-0002 (Signal Bus + Event Taxonomy — IG 3 connect/disconnect, IG 4 validity guard)

class_name StealthAlertAudioSubscriber
extends Node


# ── Test seam: stinger play counter ───────────────────────────────────────────

## Number of times the brass-punch stinger has been dispatched.
## Used by integration tests to verify the severity-gated stinger contract
## (AC-2 + AC-5). Not observed by gameplay code.
var stinger_play_count: int = 0

## World-space positions where the stinger was fired, in dispatch order.
## Tests assert that the dispatched position equals the alerted actor's position.
var stinger_play_positions: Array[Vector3] = []


# ── Per-guard alert state tracking (AC-3) ────────────────────────────────────

## Maps guard Node → its current StealthAI.AlertState.
## Updated on alert_state_changed; same-state transitions are no-ops (idempotent).
## Post-VS Audio scope: a dominant-guard aggregation will read from this dict
## to drive the music-state machine.
var _guard_alert_states: Dictionary[Node, StealthAI.AlertState] = {}


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not Events.actor_became_alerted.is_connected(_on_actor_became_alerted):
		Events.actor_became_alerted.connect(_on_actor_became_alerted)
	if not Events.alert_state_changed.is_connected(_on_alert_state_changed):
		Events.alert_state_changed.connect(_on_alert_state_changed)


func _exit_tree() -> void:
	if Events.actor_became_alerted.is_connected(_on_actor_became_alerted):
		Events.actor_became_alerted.disconnect(_on_actor_became_alerted)
	if Events.alert_state_changed.is_connected(_on_alert_state_changed):
		Events.alert_state_changed.disconnect(_on_alert_state_changed)


# ── Signal callbacks ──────────────────────────────────────────────────────────

## AC-2: actor_became_alerted handler — severity-gated brass-punch stinger.
##
## MAJOR severity → play stinger at actor.global_position.
## MINOR severity → no stinger (Pillar 1 comedy preservation).
##
## ADR-0002 IG 4: is_instance_valid(actor) guard before any property access.
func _on_actor_became_alerted(
		actor: Node,
		_cause: StealthAI.AlertCause,
		_source_position: Vector3,
		severity: StealthAI.Severity
) -> void:
	# ADR-0002 IG 4 — validity guard
	if not is_instance_valid(actor):
		return

	if severity == StealthAI.Severity.MAJOR:
		# AC-2: stinger origin is the alerted actor's world position.
		var origin: Vector3 = Vector3.ZERO
		if actor is Node3D:
			origin = (actor as Node3D).global_position
		_play_stinger_at(origin)
	# MINOR severity: no stinger (Pillar 1 comedy preservation).


## AC-3: alert_state_changed handler — per-guard state tracking.
##
## Idempotence contract (AC-3): same-state transitions (old_state == new_state)
## are no-ops. They can occur from F.4 propagation bumps (post-VS) when a
## neighbouring guard's signal triggers a re-emission with the same state.
##
## ADR-0002 IG 4: is_instance_valid(actor) guard before any property access.
func _on_alert_state_changed(
		actor: Node,
		old_state: StealthAI.AlertState,
		new_state: StealthAI.AlertState,
		_severity: StealthAI.Severity
) -> void:
	if not is_instance_valid(actor):
		return

	# AC-3 idempotence: same-state transition is a no-op
	if old_state == new_state:
		return

	_guard_alert_states[actor] = new_state


# ── Private helpers ───────────────────────────────────────────────────────────

## Dispatches the brass-punch stinger at the given world position.
## In VS, this is a logical dispatch (counter + position log) — the actual
## AudioStreamPlayer3D pool playback is a post-VS Audio integration.
##
## Test seam: stinger_play_count + stinger_play_positions are read by
## integration tests to verify the severity-gated dispatch contract.
func _play_stinger_at(position: Vector3) -> void:
	stinger_play_count += 1
	stinger_play_positions.append(position)
