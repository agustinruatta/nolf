# res://src/gameplay/stealth/perception.gd
#
# Perception — Node child of Guard that owns the perception cache, the public
# LOS accessor, and the F.1 sight fill computation.
#
# Wiring contract:
#   Guard._ready() calls:
#     var space_state := get_world_3d().direct_space_state
#     var provider := RealRaycastProvider.new(space_state)
#     $Perception.init(provider)
#
# In unit tests the harness calls:
#     var counter := CountingRaycastProvider.new()
#     perception.init(counter)
#
# F.1 sight fill (Story 004): process_sight_fill(...) is the testable formula
# entry point. Callers (Story 005's _physics_process orchestration) iterate
# targets in the VisionCone and call this method per physics frame.
#
# F.5 thresholds (Story 005), F.3 decay (Story 007), F.2 sound fill (post-VS),
# and the _physics_process VisionCone-driven orchestration are NOT in this story.
# This file exposes process_sight_fill(...) as a pure formula method; orchestration
# integrates it later.
#
# Implements: Story SAI-003 (TR-SAI-016, TR-SAI-017), Story SAI-004 (TR-SAI-007)
# GDD: design/gdd/stealth-ai.md §F.1 — Sight fill formula + Perception cache struct
# ADR: ADR-0002 Accessor Conventions (SAI → Combat) carve-out
#      ADR-0006 Collision Layer Contract — MASK_AI_VISION_OCCLUDERS for LOS

class_name Perception extends Node


# ── F.1 sight fill exports (data-driven gameplay values per coding-standards) ──

## Base sight fill rate per second, before the 6-factor multiplier chain.
## Story SAI-004 / GDD §F.1.
@export var base_sight_rate: float = 1.0

## Maximum vision range in metres — range_factor falls linearly to 0 at this distance.
## Story SAI-004 AC-1 default 18.0 m (mirrors Guard.vision_max_range_m).
@export var vision_max_range_m: float = 18.0

## Hitch guard for the per-frame accumulator increment.
## Δt_clamped = min(delta, max_delta_clamp_sec). Default = 1/30s (≈33 ms).
@export var max_delta_clamp_sec: float = 1.0 / 30.0

## Reference silhouette height for the silhouette_factor numerator (1.7 m standing Eve).
## silhouette_factor = clamp(target.silhouette_height / silhouette_reference_m, 0.5, 1.0).
@export var silhouette_reference_m: float = 1.7

## Lower clamp on silhouette_factor — even very-low silhouettes are at least 50% visible.
@export var silhouette_min_factor: float = 0.5

## Body factor for an alive target (Eve in the "player" group).
@export var body_factor_alive: float = 1.0

## Body factor for a dead target (Guard in the "dead_guard" group).
## Dead bodies are 2× as easy to spot per GDD §F.1.
@export var body_factor_dead: float = 2.0

## Zero-distance edge threshold. If |target_position - guard_eye_position| < this
## value, the formula short-circuits (range_factor = 1.0; no Vector3.normalized() call
## on a near-zero vector — Godot 4.6 returns Vector3.ZERO for a zero magnitude vector).
@export var zero_distance_epsilon_m: float = 0.1


# ── Lookup tables (built in _ready from exports below) ────────────────────────

## Movement-state → multiplier. Built once in _ready from the @export defaults.
## GDD §F.1: DEAD=0.0, IDLE=0.3, WALK=1.0, SPRINT=1.5, CROUCH=0.5, JUMP=0.8, FALL=0.8.
##
## Note on "Crouch-still" GDD intent: the GDD distinguishes "Crouch-still" (0.3)
## from "Crouch-moving" (0.5), but PlayerCharacter does not expose a velocity-zero
## bool. In VS, CROUCH always returns 0.5 — documented deviation, sufficient for
## the stealth gameplay loop.
var _movement_table: Dictionary[PlayerEnums.MovementState, float] = {}

## StealthAI.AlertState → multiplier. Built once in _ready.
## GDD §F.1: UNAWARE=1.0, SUSPICIOUS=1.5, SEARCHING=1.5, COMBAT=2.0.
## Defensive: UNCONSCIOUS / DEAD return 0.0 (a KO'd or dead guard does not run F.1).
var _state_table: Dictionary[StealthAI.AlertState, float] = {}


# ── F.3 decay rate exports (data-driven per coding-standards — designers tune without touching code) ──
# GDD §Accumulator decay: decay rate varies per alert state.
# Faster in UNAWARE (guard forgets quickly), slower in COMBAT (guard "remembers" recent alarm longer).

## Sight decay rate per second when guard is UNAWARE. GDD §F.3 default 0.5 /s.
@export var sight_decay_unaware: float = 0.5

## Sight decay rate per second when guard is SUSPICIOUS. GDD §F.3 default 0.3 /s.
@export var sight_decay_suspicious: float = 0.3

## Sight decay rate per second when guard is SEARCHING. GDD §F.3 default 0.15 /s.
@export var sight_decay_searching: float = 0.15

## Sight decay rate per second when guard is COMBAT. GDD §F.3 default 0.05 /s.
@export var sight_decay_combat: float = 0.05

## Sound decay rate per second when guard is UNAWARE. GDD §F.3 default 0.4 /s.
@export var sound_decay_unaware: float = 0.4

## Sound decay rate per second when guard is SUSPICIOUS. GDD §F.3 default 0.25 /s.
@export var sound_decay_suspicious: float = 0.25

## Sound decay rate per second when guard is SEARCHING. GDD §F.3 default 0.12 /s.
@export var sound_decay_searching: float = 0.12

## Sound decay rate per second when guard is COMBAT. GDD §F.3 default 0.05 /s.
@export var sound_decay_combat: float = 0.05


# ── Per-frame state ───────────────────────────────────────────────────────────

var _raycast_provider: IRaycastProvider
var _perception_cache: PerceptionCache = PerceptionCache.new()

## Sight accumulator clamped to [0.0, 1.0]. F.1 (this story) writes; F.5 reads
## (Story 005); F.3 decays (Story 007). Resets to 0.0 on de-escalation completion.
var sight_accumulator: float = 0.0

## Sound accumulator clamped to [0.0, 1.0]. F.2 sound fill (post-VS) writes;
## F.5 thresholds (Story 005) reads. Stub default 0.0 — no hearing in VS.
var sound_accumulator: float = 0.0

## Set to true by process_sight_fill when a real fill happens (LOS confirmed, target
## not DEAD). Prevents F.3 decay from counteracting a fill within the same frame.
## Reset to false at the end of apply_decay. Story SAI-007 / GDD §F.3.
var _sight_refreshed_this_frame: bool = false

## Set to true by F.2 sound fill (post-VS) when sound accumulator is written.
## Prevents F.3 decay from counteracting a sound fill within the same poll.
## Reset to false at the end of apply_decay. Story SAI-007 / GDD §F.3.
var _sound_refreshed_this_poll: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_movement_table = {
			PlayerEnums.MovementState.DEAD: 0.0,
			PlayerEnums.MovementState.IDLE: 0.3,
			PlayerEnums.MovementState.WALK: 1.0,
			PlayerEnums.MovementState.SPRINT: 1.5,
			PlayerEnums.MovementState.CROUCH: 0.5,
			PlayerEnums.MovementState.JUMP: 0.8,
			PlayerEnums.MovementState.FALL: 0.8,
	}
	_state_table = {
			StealthAI.AlertState.UNAWARE: 1.0,
			StealthAI.AlertState.SUSPICIOUS: 1.5,
			StealthAI.AlertState.SEARCHING: 1.5,
			StealthAI.AlertState.COMBAT: 2.0,
			StealthAI.AlertState.UNCONSCIOUS: 0.0,
			StealthAI.AlertState.DEAD: 0.0,
	}


# ── Public API ────────────────────────────────────────────────────────────────

## Injects the raycast provider. Must be called before the first physics frame
## where F.1 runs (i.e., from Guard._ready()).
##
## [param raycast_provider] The IRaycastProvider implementation to use.
## In production, pass RealRaycastProvider.new(get_world_3d().direct_space_state).
## In tests, pass CountingRaycastProvider.new().
func init(raycast_provider: IRaycastProvider) -> void:
	_raycast_provider = raycast_provider


## Returns true if the player is in line-of-sight per the most recent F.1 cache.
##
## Cold-start safe: returns false if init() has not been called or F.1 has not
## yet ticked (_perception_cache.initialized == false).
## Cache-read only — does NOT issue a new raycast.
## F.1 (this story) is the sole writer of _perception_cache; this accessor only reads.
## At most 1-physics-frame stale when polled between ticks (e.g., Combat 10 Hz idle).
func has_los_to_player() -> bool:
	if not _perception_cache.initialized:
		return false
	return _perception_cache.los_to_player


## Computes the F.1 sight fill rate for one frame and applies it to the
## sight_accumulator. Writes the perception cache.
##
## Formula (GDD §F.1, authoritative):
##   range_factor      = 1.0 - clamp(distance / vision_max_range_m, 0, 1)
##   silhouette_factor = clamp(target.silhouette_height / 1.7, 0.5, 1.0)
##   movement_factor   = MOVEMENT_TABLE[target_movement_state]
##   state_multiplier  = STATE_TABLE[guard_alert_state]
##   body_factor       = body_factor_dead if target_is_dead_body else body_factor_alive
##
##   sight_fill_rate   = base_sight_rate * range * silhouette * movement * state * body
##
## Special cases (return 0.0 fill rate, but still write the cache):
##   - LOS blocked (raycast hit world geometry between guard_eye and target_head)
##   - target_movement_state == DEAD (Eve is dead; no fill regardless of body)
##
## Edge cases:
##   - Zero-distance: |target_position - guard_eye_position| < zero_distance_epsilon_m
##     → range_factor = 1.0 (no normalized() call on near-zero vector)
##
## [param target_body] The Node3D being observed (Eve or a dead Guard).
## [param guard_eye_position] World-space position of the guard's eye.
## [param target_head_position] World-space position of the target's head (LOS endpoint).
## [param target_movement_state] Eve's MovementState; for dead-guard targets, pass IDLE.
## [param target_silhouette_height] target.get_silhouette_height() in metres.
## [param guard_alert_state] StealthAI.AlertState — looks up state_multiplier.
## [param target_is_dead_body] true → body_factor=2.0; false → body_factor=1.0.
## [param guard_rid] The guard's RID (for raycast self-exclusion).
## [param delta] Frame physics delta in seconds.
##
## Returns the computed sight_fill_rate (per second) for assertion in tests.
func process_sight_fill(
		target_body: Node3D,
		guard_eye_position: Vector3,
		target_head_position: Vector3,
		target_movement_state: PlayerEnums.MovementState,
		target_silhouette_height: float,
		guard_alert_state: StealthAI.AlertState,
		target_is_dead_body: bool,
		guard_rid: RID,
		delta: float
) -> float:
	# ── LOS raycast (cache-write source of truth) ────────────────────────────
	var has_los: bool = _check_line_of_sight(
			guard_eye_position, target_head_position, target_body, guard_rid
	)

	# ── Compute the 6-factor formula ────────────────────────────────────────
	var sight_fill_rate: float = 0.0
	if has_los and target_movement_state != PlayerEnums.MovementState.DEAD:
		sight_fill_rate = _compute_sight_fill_rate(
				guard_eye_position,
				target_head_position,
				target_movement_state,
				target_silhouette_height,
				guard_alert_state,
				target_is_dead_body
		)

	# ── Accumulator with delta-clamp + [0, 1] clamp (AC-5) ──────────────────
	var delta_clamped: float = minf(delta, max_delta_clamp_sec)
	sight_accumulator = clampf(
			sight_accumulator + sight_fill_rate * delta_clamped,
			0.0,
			1.0
	)

	# ── F.3 refresh flag (Story SAI-007): mark sight channel as filled this frame
	# so apply_decay skips decay for this channel (avoids same-frame fill+decay).
	# Only flagged when a real fill happened (LOS clear AND target not DEAD).
	if has_los and target_movement_state != PlayerEnums.MovementState.DEAD:
		_sight_refreshed_this_frame = true

	# ── Cache write per AC-3 ────────────────────────────────────────────────
	_perception_cache.initialized = true
	_perception_cache.frame_stamp = Engine.get_physics_frames()
	_perception_cache.los_to_player = has_los and not target_is_dead_body
	if has_los:
		_perception_cache.los_to_player_position = target_body.global_position
		_perception_cache.last_sight_position = target_body.global_position
	_perception_cache.last_sight_stimulus_cause = (
			StealthAI.AlertCause.SAW_BODY if target_is_dead_body
			else StealthAI.AlertCause.SAW_PLAYER
	)

	return sight_fill_rate


# ── F.3 decay (Story SAI-007) ────────────────────────────────────────────────

## Applies F.3 decay to sight_accumulator and sound_accumulator based on the
## guard's current alert state. Accumulators are floored at 0.0 and never go
## negative. Skips decay for a channel if it was refreshed this frame (i.e.,
## process_sight_fill reported a real fill this physics frame).
##
## The hitch guard clamps delta to 1.0/30.0 so runaway decay during frame spikes
## (e.g. a 200 ms frame) cannot overshoot the accumulator floor.
##
## Resets _sight_refreshed_this_frame and _sound_refreshed_this_poll to false
## at the end of each call (these flags are per-frame/per-poll).
##
## [param current_alert_state] The guard's current AlertState — selects decay rate.
## [param delta] Frame physics delta in seconds.
##
## Implements: Story SAI-007 (TR-SAI-009 §F.3)
## GDD: design/gdd/stealth-ai.md §Accumulator decay
func apply_decay(current_alert_state: StealthAI.AlertState, delta: float) -> void:
	var delta_clamped: float = minf(delta, 1.0 / 30.0)
	if not _sight_refreshed_this_frame:
		sight_accumulator = maxf(
				0.0,
				sight_accumulator - _sight_decay_for_state(current_alert_state) * delta_clamped
		)
	if not _sound_refreshed_this_poll:
		sound_accumulator = maxf(
				0.0,
				sound_accumulator - _sound_decay_for_state(current_alert_state) * delta_clamped
		)
	_sight_refreshed_this_frame = false
	_sound_refreshed_this_poll = false


# ── Private helpers ───────────────────────────────────────────────────────────

## Returns the sight decay rate per second for the given alert state.
## Defensive default: 0.5 (UNAWARE rate) for any unexpected state.
func _sight_decay_for_state(state: StealthAI.AlertState) -> float:
	match state:
		StealthAI.AlertState.UNAWARE:
			return sight_decay_unaware
		StealthAI.AlertState.SUSPICIOUS:
			return sight_decay_suspicious
		StealthAI.AlertState.SEARCHING:
			return sight_decay_searching
		StealthAI.AlertState.COMBAT:
			return sight_decay_combat
		_:
			return sight_decay_unaware  # UNCONSCIOUS/DEAD: use fastest rate defensively


## Returns the sound decay rate per second for the given alert state.
## Defensive default: 0.4 (UNAWARE rate) for any unexpected state.
func _sound_decay_for_state(state: StealthAI.AlertState) -> float:
	match state:
		StealthAI.AlertState.UNAWARE:
			return sound_decay_unaware
		StealthAI.AlertState.SUSPICIOUS:
			return sound_decay_suspicious
		StealthAI.AlertState.SEARCHING:
			return sound_decay_searching
		StealthAI.AlertState.COMBAT:
			return sound_decay_combat
		_:
			return sound_decay_unaware  # UNCONSCIOUS/DEAD: use fastest rate defensively

## Issues an LOS raycast and returns true if the path from guard_eye to
## target_head is clear OR if the first hit is target_body itself.
##
## MASK_AI_VISION_OCCLUDERS includes MASK_WORLD | MASK_PLAYER (per ADR-0006 +
## src/core/physics_layers.gd line 34). The ray will hit the player if she is at
## the endpoint; the `result.collider == target_body` check accounts for that.
## World geometry between guard and target produces a non-empty result with
## collider != target_body → LOS blocked.
func _check_line_of_sight(
		from_pos: Vector3,
		to_pos: Vector3,
		target_body: Node3D,
		guard_rid: RID
) -> bool:
	if _raycast_provider == null:
		return false  # cold-start safety; cache will be written with los=false

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from_pos,
			to_pos,
			PhysicsLayers.MASK_AI_VISION_OCCLUDERS,
			[guard_rid]
	)
	var result: Dictionary = _raycast_provider.cast(query)
	if result.is_empty():
		return true
	# Non-empty: ray hit something. LOS clear iff that something IS the target.
	return result.get("collider") == target_body  # action-literal-ok: Dictionary key from intersect_ray, not an InputMap action.


## The pure 6-factor formula. No side effects; safely callable from tests.
func _compute_sight_fill_rate(
		guard_eye_position: Vector3,
		target_head_position: Vector3,
		target_movement_state: PlayerEnums.MovementState,
		target_silhouette_height: float,
		guard_alert_state: StealthAI.AlertState,
		target_is_dead_body: bool
) -> float:
	# Zero-distance short-circuit (AC-2-f, GDD E.18)
	var distance: float = (target_head_position - guard_eye_position).length()
	var range_factor: float
	if distance < zero_distance_epsilon_m:
		range_factor = 1.0
	else:
		range_factor = 1.0 - clampf(distance / vision_max_range_m, 0.0, 1.0)

	var silhouette_factor: float = clampf(
			target_silhouette_height / silhouette_reference_m,
			silhouette_min_factor,
			1.0
	)

	# Movement / state lookups; defensive default 0.0 if key missing.
	var movement_factor: float = _movement_table.get(target_movement_state, 0.0)
	var state_multiplier: float = _state_table.get(guard_alert_state, 0.0)
	var body_factor: float = body_factor_dead if target_is_dead_body else body_factor_alive

	return (
			base_sight_rate
			* range_factor
			* silhouette_factor
			* movement_factor
			* state_multiplier
			* body_factor
	)
