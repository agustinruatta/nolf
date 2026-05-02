# res://src/gameplay/player/footstep_component.gd
#
# FootstepComponent — child Node of PlayerCharacter that emits Events.player_footstep
# at the player's current locomotion cadence. Sole publisher of `player_footstep`
# per ADR-0002 §Implementation Guideline 5; pure publisher (no signal subscriptions
# per ADR-0002 IG 3 consumer-side rule).
#
# This file is the scaffold (Story FS-001):
#   • Class declaration + parent-type assertion in `_ready`
#   • Exported cadence knobs + ray-depth knob
#   • Private state for the step-cadence loop (Story FS-002 lands the loop)
#   • CADENCE_BY_STATE precomputed dictionary built once in `_ready`
#   • _is_disabled fallback when parent is wrong type (no null-deref cascade)
#
# Implements: Story FS-001 (scaffold + parent assertion)
# Requirements: TR-FC-001 (partial — emission infrastructure), TR-FC-008 (parent-attachment validation)
# GDD: design/gdd/footstep-component.md §Acceptance Criteria AC-FC-6.1
# ADRs: ADR-0002 (Signal Bus), ADR-0006 (Collision Layer Contract — MASK_FOOTSTEP_SURFACE)

class_name FootstepComponent
extends Node

# ── @export — Cadence (designer-tunable per GDD §Tuning Knobs) ─────────────

## Walk cadence in Hz. Safe range: 1.8–2.8 (GDD). Default 2.2 Hz.
## Owned by Audio Director per GDD Tuning Knobs table.
@export_range(1.8, 2.8, 0.05) var cadence_walk_hz: float = 2.2

## Sprint cadence in Hz. Safe range: 2.5–3.6 (GDD). Default 3.0 Hz.
## Owned by Audio Director.
@export_range(2.5, 3.6, 0.05) var cadence_sprint_hz: float = 3.0

## Crouch cadence in Hz. Safe range: 1.2–2.0 (GDD). Default 1.6 Hz.
## Owned by Audio Director.
@export_range(1.2, 2.0, 0.05) var cadence_crouch_hz: float = 1.6

## Downward-ray depth in metres. Safe range: 1.0–4.0. Default 2.0 m.
## Owned by Gameplay Programmer; Story FS-003 consumes for surface-tag resolution.
@export_range(1.0, 4.0, 0.1) var surface_raycast_depth_m: float = 2.0

# ── Private state ──────────────────────────────────────────────────────────

## True when parent-type assertion fails. All `_physics_process` ticks become
## no-ops to prevent null-deref cascades downstream.
var _is_disabled: bool = false

## Seconds accumulated since the last footstep emission. Story FS-002 uses
## this for phase-preserving cadence integration.
var _step_accumulator: float = 0.0

## Story FS-003: tracks bodies that have already emitted a missing-surface_tag
## warning. Maps body instance_id (int) → bool. Prevents log spam from a
## untagged mesh Eve crosses repeatedly. Cleared on `_ready()`.
var _warned_bodies: Dictionary = {}

## Typed reference to the parent PlayerCharacter, set in `_ready` after the
## parent assertion. Stays null when `_is_disabled == true`.
var _player: PlayerCharacter = null

## Precomputed dictionary mapping each ground-locomotion movement state to
## the seconds-per-step interval (1 / cadence_hz). Built once in `_ready` from
## the exported cadence knobs. Idle / Jump / Fall / Dead are not present —
## the cadence loop suppresses emission for those states (Story FS-002).
var CADENCE_BY_STATE: Dictionary[PlayerEnums.MovementState, float] = {}


# ── Lifecycle ──────────────────────────────────────────────────────────────

## Asserts FootstepComponent is a direct child of PlayerCharacter, then
## precomputes CADENCE_BY_STATE from the exported knobs.
##
## On assertion failure: pushes an error and sets `_is_disabled = true`. All
## subsequent `_physics_process` ticks are no-ops. Prevents a misconfigured
## scene from cascading null-derefs.
##
## Story FS-001 AC-1 + AC-2.
func _ready() -> void:
	var parent: Node = get_parent()
	if parent == null or not (parent is PlayerCharacter):
		push_error(
			"FootstepComponent must be a direct child of PlayerCharacter."
			+ " Parent type: %s" % [parent.get_class() if parent != null else "<null>"]
		)
		_is_disabled = true
		return

	_player = parent as PlayerCharacter

	CADENCE_BY_STATE = {
		PlayerEnums.MovementState.WALK:   1.0 / cadence_walk_hz,
		PlayerEnums.MovementState.SPRINT: 1.0 / cadence_sprint_hz,
		PlayerEnums.MovementState.CROUCH: 1.0 / cadence_crouch_hz,
	}


## Story FS-002 cadence loop. GDD §Formulas FC.1 — phase-preserving
## accumulator; suppression for non-emitting states; idle-velocity gate;
## coyote-window-aware floor guard; delta-clamp hitch guard.
##
## Order of guards (matters):
##   1. _is_disabled — bail (scaffold contract)
##   2. _is_emitting_state(state) → false → reset accumulator + bail
##   3. is_on_floor() → false → bail WITHOUT reset (preserves cadence across
##      coyote-window false-floor blips per GDD FC.E.4)
##   4. velocity.length() < idle_velocity_threshold → bail (walk-still guard)
##   5. accumulate clamped delta; if ≥ interval, emit + carry-over (-= interval)
##
## Phase-preservation (`-= interval`, NOT `= 0`) matters when state changes
## mid-interval — the carried-over fraction means the next step fires sooner,
## avoiding perceptible drift on rapid Walk→Sprint→Walk sequences.
##
## TR-FC-002, TR-FC-006. ADR-0008 Slot 5 governs combined ≤0.3 ms cost.
func _physics_process(delta: float) -> void:
	if _is_disabled:
		return
	if not _is_emitting_state(_player.current_state):
		_step_accumulator = 0.0
		return
	if not _player.is_on_floor():
		# Coyote-window or genuine fall — preserve accumulator (FC.E.4).
		return
	if _player.velocity.length() < _player.idle_velocity_threshold:
		# Walk-still / Crouch-still — accumulator does NOT advance.
		return
	var interval: float = CADENCE_BY_STATE[_player.current_state]
	var delta_clamped: float = min(delta, 1.0 / 30.0)
	_step_accumulator += delta_clamped
	if _step_accumulator >= interval:
		_step_accumulator -= interval  # phase-preservation, NOT = 0
		_emit_footstep()


## Returns true when the given movement state should emit footsteps (Walk,
## Sprint, Crouch). Idle / Jump / Fall / Dead are silent.
## Story FS-002 helper.
func _is_emitting_state(state: PlayerEnums.MovementState) -> bool:
	return (state == PlayerEnums.MovementState.WALK
			or state == PlayerEnums.MovementState.SPRINT
			or state == PlayerEnums.MovementState.CROUCH)


## Emits a footstep through the Events autoload, with the resolved surface tag
## from the downward raycast and `noise_radius_m = _player.get_noise_level()`
## at emission time.
##
## Per GDD FC.3 + TR-FC-005: noise_radius_m MIRRORS the PC-owned
## `get_noise_level()` — FootstepComponent never computes a duplicate noise
## formula. If the PC's noise_walk/sprint/crouch knobs change, both Stealth
## AI's perception scalar AND Audio's stem selection move together
## automatically.
##
## Per ADR-0002 IG: emit via `Events.<signal>.emit(...)` directly — no
## wrapper methods, no node-to-node connections.
##
## Story FS-004. TR-FC-001, TR-FC-005, TR-FC-007.
func _emit_footstep() -> void:
	var surface: StringName = _resolve_surface_tag()
	var noise_radius: float = _player.get_noise_level()
	Events.player_footstep.emit(surface, noise_radius)


## Resolves the surface tag for the ground body directly below the player.
## Casts one downward ray from 0.05 m below the player origin to
## `surface_raycast_depth_m` deep. Called once per step (not per frame) by
## _emit_footstep(). Returns &"default" if no hit OR no surface_tag metadata.
##
## Per ADR-0006 IG 1: uses PhysicsLayers.MASK_FOOTSTEP_SURFACE (= MASK_WORLD).
## No bare integer literals on `query.collision_mask`.
##
## Warning throttle (GDD FC.E.5): a body with no `surface_tag` meta produces
## ONE push_warning per (body, mission-load) pair. Subsequent calls against
## the same body suppress the warning to prevent log spam.
##
## Story FS-003. TR-FC-003, TR-FC-004, TR-FC-008.
func _resolve_surface_tag() -> StringName:
	var space_state: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var origin: Vector3 = _player.global_transform.origin - Vector3(0.0, 0.05, 0.0)
	var target: Vector3 = _player.global_transform.origin - Vector3(0.0, surface_raycast_depth_m, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = PhysicsLayers.MASK_FOOTSTEP_SURFACE
	query.exclude = [_player.get_rid()]
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		# No body below player at all. Don't warn (would spam in mid-air).
		return &"default"
	var body: Object = hit["collider"]
	if body.has_meta("surface_tag"):  # action-literal-ok: Node metadata key, not an InputMap action.
		return body.get_meta("surface_tag") as StringName  # action-literal-ok: Node metadata key.
	# Body present but missing tag — log once per body.
	_warn_missing_surface_tag(body)
	return &"default"


## Logs a single push_warning per offending body, recording it in
## _warned_bodies to suppress duplicates. Per GDD FC.E.5.
func _warn_missing_surface_tag(body: Object) -> void:
	var key: int = body.get_instance_id()
	if _warned_bodies.has(key):
		return
	_warned_bodies[key] = true
	push_warning(
		"FootstepComponent: body '%s' (id=%d) is missing meta 'surface_tag'; using &\"default\"."
		% [body.name if "name" in body else "<unnamed>", key]
	)
