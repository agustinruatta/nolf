# res://src/gameplay/player/player_character.gd
#
# PlayerCharacter — Eve's CharacterBody3D root script.
#
# PC-001 (scaffold): node hierarchy, collision layer setup per ADR-0006,
#   class-scope state vars typed by PlayerEnums.
# PC-002 (camera + look input): Camera3D FOV, mouse/gamepad look processing
#   in _unhandled_input, pitch clamp, yaw-body split, turn-overshoot Tween.
# PC-003 (movement state machine + locomotion): 7-state machine, F.1/F.2/F.3
#   formulas, coyote-time, crouch transition with ceiling check, noise-spike stub.
# PC-004 (noise perception surface): full F.4 spike-latch policy — highest-
#   radius-wins collision, 9-frame auto-expiry @ 60 Hz, zero-allocation
#   in-place mutation, idle-velocity gate, DEAD early-return; plus
#   get_noise_level(), get_noise_event(), get_silhouette_height() pull API.
# PC-005 (interact raycast + query API): F.5 iterative interact raycast using
#   camera forward, priority resolver (Document 0 < Terminal 1 < Pickup 2 < Door 3),
#   E-press flow with pre-reach pause + reach Tween, player_interacted signal emit
#   via Events autoload, is_hand_busy() / get_current_interact_target() query API.
#
# Collision layer setup per ADR-0006 IG 1 + IG 6: this body sets its OWN
# layer (LAYER_PLAYER) and masks the layers it COLLIDES AGAINST (WORLD + AI).
# Zero bare integer literals — all references go through PhysicsLayers.*.
#
# Camera/look input consumed in _unhandled_input (NOT _physics_process) per
# GDD §Input processing location: avoids mouse-delta accumulation lump on
# high-refresh-rate displays. Body rotates on Y (yaw); camera rotates on X
# (pitch); roll always 0 outside sprint-sway window.
#
# Sign convention: Camera3D +X rotation pitches nose DOWN (Godot convention).
# Mouse down (positive relative.y) → look down → rotation.x increases → +85°
# clamp. Mouse up (negative relative.y) → look up → rotation.x decreases → -85°.
#
# F.1 Horizontal velocity blend: planar Vector2 move_toward, NaN-guarded, delta-clamped.
# F.2 Gravity + jump: delta-clamped, coyote-time guarded.
# F.3 Hard-landing noise: sqrt(2×g×h) threshold, 8m×clamp(|vy|/threshold, 1, 2) radius.
# F.4 Noise spike latch: highest-radius-wins, auto-expiry, zero-alloc in-place mutation.
# F.8 Silhouette height: lerp(1.7, 1.1, _crouch_transition_progress); DEAD → 0.4.
#
# Mid-air crouch buffering (GDD E.2) is DEFERRED — crouch pressed mid-air is a no-op.
#
# Implements: Story PC-001 (scene root scaffold)
#             Story PC-002 (first-person camera + look input)
#             Story PC-003 (movement state machine + locomotion)
#             Story PC-004 (noise perception surface)
#             Story PC-005 (interact raycast + query API)
# GDD: design/gdd/player-character.md §Detailed Design Core Rules

class_name PlayerCharacter
extends CharacterBody3D

# ── Constants ──────────────────────────────────────────────────────────────

## Maximum physics delta we feed into F.1 / F.2 calculations (hitch guard).
## Prevents physics tunnelling and NaN after a stall frame.
const _DELTA_CAP: float = 1.0 / 30.0

## Standing capsule height; matches CollisionShape3D in scene.
const _STAND_HEIGHT: float = 1.7
## Standing camera eye height; matches Camera3D.position.y in scene.
const _STAND_EYE_Y: float = 1.6
## Crouched capsule height; defined by GDD §Detailed Design.
const _CROUCH_HEIGHT: float = 1.1
## Crouched camera eye height; defined by GDD §Detailed Design.
const _CROUCH_EYE_Y: float = 1.0

## Ship-locked noise global multiplier. NOT a designer export.
## GDD game-designer B-2 closure: locked to 1.0 at ship. A new ADR is required
## to change this value. Forbidden pattern: any system writing to this field.
## PC-004 (Story 004). TR-PC-012.
const noise_global_multiplier: float = 1.0

# ── Signals ────────────────────────────────────────────────────────────────

## Emitted whenever current_state transitions to a new value.
signal state_changed(new_state: PlayerEnums.MovementState)

# ── @export — Camera tuning (designer-tunable) ─────────────────────────────

## Horizontal FOV in degrees. Designer-tunable per GDD Tuning Knobs §Camera.
@export var camera_fov: float = 75.0

## Mouse sensitivity X (yaw). Eventually consumed from Settings.get_mouse_sensitivity_x().
@export var mouse_sensitivity_x: float = 0.003

## Mouse sensitivity Y (pitch). Eventually consumed from Settings.get_mouse_sensitivity_y().
@export var mouse_sensitivity_y: float = 0.003

## Gamepad look sensitivity. Eventually consumed from Settings.gamepad_look_sensitivity.
@export var gamepad_look_sensitivity: float = 2.0

## Pitch clamp in degrees. ±85° prevents gimbal lock at the poles.
@export var pitch_clamp_deg: float = 85.0

## Turn overshoot amplitude in degrees (camera.rotation.y, not body.rotation.y).
@export var turn_overshoot_deg: float = 4.0

## Turn overshoot return time in milliseconds (settle to zero).
@export var turn_overshoot_return_ms: float = 90.0

## Yaw delta threshold per frame to trigger overshoot. >180°/s @ 60Hz = >3°/frame.
@export var turn_overshoot_threshold_deg_per_frame: float = 3.0

# ── @export — Movement (designer-tunable per GDD Tuning Knobs) ─────────────

## Base walking speed in m/s. GDD default 3.5 m/s. AC-1.1.
@export_range(2.8, 4.2, 0.01) var walk_speed: float = 3.5

## Sprinting speed in m/s. GDD default 5.5 m/s. AC-1.2.
@export_range(4.5, 6.5, 0.01) var sprint_speed: float = 5.5

## Crouched movement speed in m/s. GDD default 1.8 m/s. AC-1.3.
@export_range(1.4, 2.2, 0.01) var crouch_speed: float = 1.8

# ── @export — Vertical (designer-tunable per GDD Tuning Knobs) ─────────────

## Gravity acceleration in m/s². Applied when not on floor. GDD default 12.0.
@export_range(11.0, 13.0, 0.01) var gravity: float = 12.0

## Upward velocity applied at jump start in m/s. GDD default 3.8.
## Safe range 3.5 – 4.2 per GDD §Tuning Knobs §Vertical cross-knob constraint table.
## Worst-case kinematic apex: (v=4.2, g=11) → v²/(2g) = 0.8018 m, which the GDD
## rounds to 0.80 m in the cross-knob constraint table (§Pillar 5 — no parkour).
@export_range(3.5, 4.2, 0.01) var jump_velocity: float = 3.8

## Fall distance threshold triggering LANDING_HARD noise (m). GDD default 1.5.
@export_range(1.2, 3.0, 0.01) var hard_land_height: float = 1.5

# ── @export — Noise radii (designer-tunable per GDD F.3) ───────────────────

## Noise radius for jump-takeoff spike in metres. GDD default 4.0.
@export_range(3.0, 6.0, 0.01) var noise_jump_takeoff: float = 4.0

## Noise radius for soft landing in metres. GDD default 5.0.
@export_range(4.0, 7.0, 0.01) var noise_landing_soft: float = 5.0

## Base noise radius for hard landing in metres. GDD default 8.0.
@export_range(7.0, 10.0, 0.01) var noise_landing_hard_base: float = 8.0

# ── @export — Noise perception (designer-tunable per GDD F.4) ──────────────

## Continuous walking noise radius in metres. Consumed by NOISE_BY_STATE.
## Default 5.0 m per GDD §Tuning Knobs. TR-PC-012.
@export_range(3.0, 8.0, 0.1) var noise_walk: float = 5.0

## Continuous sprinting noise radius in metres. Consumed by NOISE_BY_STATE.
## Default 12.0 m per GDD §Tuning Knobs. TR-PC-012.
@export_range(8.0, 16.0, 0.1) var noise_sprint: float = 12.0

## Continuous crouched-movement noise radius in metres. Consumed by NOISE_BY_STATE.
## Default 3.0 m per GDD §Tuning Knobs. TR-PC-012.
@export_range(1.0, 5.0, 0.1) var noise_crouch: float = 3.0

## Minimum planar speed (m/s) to count as moving. Below this threshold Walk and
## Crouch return 0.0 from get_noise_level() (idle-velocity gate). GDD F.4.
@export_range(0.01, 0.5, 0.01) var idle_velocity_threshold: float = 0.1

## Duration (seconds) the spike latch persists before auto-expiry.
## Converted to frames in _ready(). 0.15 s → 9 frames @ 60 Hz per ai-programmer
## B-2 fix (2026-04-21): covers every 10 Hz guard poll phase offset. TR-PC-014.
@export_range(0.05, 0.5, 0.01) var spike_latch_duration_sec: float = 0.15

# ── @export — Silhouette heights (designer-tunable per GDD F.8) ─────────────

## Silhouette height (m) when fully standing. GDD F.8. TR-PC-018.
@export_range(1.5, 2.0, 0.01) var silhouette_height_standing: float = 1.7

## Silhouette height (m) when fully crouched. GDD F.8. TR-PC-018.
@export_range(0.8, 1.3, 0.01) var silhouette_height_crouched: float = 1.1

## Silhouette height (m) in DEAD state. GDD F.8. TR-PC-018.
@export_range(0.2, 0.8, 0.01) var silhouette_height_dead: float = 0.4

# ── @export — Interact raycast (designer-tunable per GDD F.5, TR-PC-008, TR-PC-009) ──

## Length of the interact raycast from the camera forward in metres. GDD F.5.
## TR-PC-008. ADR-0006 IG 7 — raycast uses MASK_INTERACT_RAYCAST, no layer.
@export_range(1.0, 4.0, 0.1) var interact_ray_length: float = 2.0

## Maximum ray-iteration cap for the F.5 iterative resolver. Controls how many
## overlapping interactables the resolver steps through before emitting a
## push_warning and returning the best candidate found so far. TR-PC-008.
@export_range(1, 8) var raycast_max_iterations: int = 4

## Duration in milliseconds of the pre-reach pause (hand-raise visual cue)
## before the reach animation begins. TR-PC-009.
@export_range(50, 400) var interact_pre_reach_ms: int = 150

## Duration in milliseconds of the reach animation Tween.
## player_interacted fires at the end of this window. TR-PC-009.
@export_range(100, 500) var interact_reach_duration_ms: int = 225

# ── @export — Correctness parameters (engine-side) ─────────────────────────

## Time (s) to accelerate to walk target speed. GDD default 0.12.
@export_range(0.05, 0.30, 0.01) var walk_accel_time: float = 0.12

## Time (s) to decelerate from walk speed to zero. GDD default 0.18.
@export_range(0.05, 0.30, 0.01) var walk_decel_time: float = 0.18

## Time (s) to accelerate to sprint target speed. GDD default 0.15.
@export_range(0.05, 0.30, 0.01) var sprint_accel_time: float = 0.15

## Duration of crouch camera/capsule transition in seconds. GDD default 0.12.
@export_range(0.05, 0.30, 0.01) var crouch_transition_time: float = 0.12

## Physics frames of coyote-time after leaving the floor. GDD default 3.
@export_range(0, 10) var coyote_time_frames: int = 3

# ── Public state ───────────────────────────────────────────────────────────

## Current movement state. Transitions owned by PC-003 _update_movement_state().
var current_state: PlayerEnums.MovementState = PlayerEnums.MovementState.IDLE

# ── Private state ──────────────────────────────────────────────────────────

var _overshoot_tween: Tween = null
var _crouch_tween: Tween = null

## Progress of crouch transition: 0.0 = fully standing, 1.0 = fully crouched.
## Exposed for Story PC-004 get_silhouette_height() calculation.
var _crouch_transition_progress: float = 0.0

## Whether the player is currently in (or transitioning into) crouch.
var _is_crouching: bool = false

## Coyote-time frames remaining before jump is no longer permitted after
## leaving the floor. Reset to coyote_time_frames when on floor.
var _coyote_frames_remaining: int = 0

## Whether the player was on the floor at the START of the current physics tick
## (before move_and_slide). Used to detect the floor→air and air→floor transitions.
var _was_on_floor: bool = false

## velocity.y cached BEFORE move_and_slide, used in post-step landing detection.
var _pre_slide_velocity_y: float = 0.0

## Whether a JUMP_TAKEOFF was initiated this tick (used to gate takeoff spike).
var _jump_fired_this_tick: bool = false

## Whether a head-bump SFX has been requested during this frame.
## Story PC-004 / Audio epic consumes this flag. AC-ceiling-check.
var _pending_head_bump: bool = false

## Reused NoiseEvent instance — in-place mutation per GDD F.4 (zero-allocation).
## null when no spike is latched; allocated once on first spike and reused.
## Callers MUST copy fields before the next physics frame (see noise_event.gd).
## PC-004 (Story 004). TR-PC-013.
var _latched_event: NoiseEvent = null

## Physics frames remaining in the current spike latch. 0 = no active latch.
## Auto-expiry is the SOLE clear mechanism during normal play. TR-PC-014.
var _latch_frames_remaining: int = 0

## NOISE_BY_STATE maps MovementState → continuous noise radius (float).
## Built once in _ready() from export knobs; never allocated per-frame. TR-PC-012.
var NOISE_BY_STATE: Dictionary[PlayerEnums.MovementState, float] = {}

## Spike latch duration in physics frames. Computed once in _ready() from
## spike_latch_duration_sec × Engine.physics_ticks_per_second. TR-PC-014.
var _spike_latch_duration_frames: int = 9

# ── PC-005 private state ───────────────────────────────────────────────────

## The best interactable resolved by _resolve_interact_target() on the most
## recent _physics_process tick. null when nothing is in range.
## Cached once per tick and consumed by both the HUD query (get_current_interact_target)
## and the E-press handler (_start_interact). Ensures HUD-coherence: both code
## paths see the same resolver result for the same frame. TR-PC-008.
var _current_interact_target: Node3D = null

## True while the pre-reach-pause or reach-animation Tween is in flight.
## E.4: a second E-press while this is true is swallowed.
## Sprint-disabled-during-interact: _apply_horizontal_velocity reads this flag
## to cap speed to walk_speed when in SPRINT state. TR-PC-009.
var _is_hand_busy: bool = false

## Tween for the pre-reach pause delay (interact_pre_reach_ms).
## Killed and recreated on each new E-press. null when idle.
var _interact_pre_reach_tween: Tween = null

## Tween for the reach animation (interact_reach_duration_ms).
## The player_interacted signal fires in this tween's finished callback.
## null when idle. TODO PC-006: damage cancel kills this tween in apply_damage().
var _interact_reach_tween: Tween = null

# ── @onready — Cached node refs ────────────────────────────────────────────

@onready var _camera: Camera3D = $Camera3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _shape_cast: ShapeCast3D = $ShapeCast3D


# ── Built-in virtual methods ───────────────────────────────────────────────

func _ready() -> void:
	# Per ADR-0006 IG 1 + IG 6: set OWN layer (LAYER_PLAYER), mask the
	# layers we COLLIDE AGAINST (WORLD + AI). Use index-based helpers
	# with LAYER_* constants per IG 3. Zero bare integer literals.
	#
	# Clear default scene-editor layer bits before setting PLAYER. Godot
	# defaults a fresh CharacterBody3D to layer 1 (= LAYER_WORLD), which
	# would otherwise leave Eve falsely on the world-geometry layer. AC-4
	# mandates "clears all other layer bits" — done explicitly here so a
	# future scene-editor change cannot silently drift away from the spec.
	set_collision_layer_value(PhysicsLayers.LAYER_WORLD, false)
	set_collision_layer_value(PhysicsLayers.LAYER_AI, false)
	set_collision_layer_value(PhysicsLayers.LAYER_INTERACTABLES, false)
	set_collision_layer_value(PhysicsLayers.LAYER_PROJECTILES, false)
	set_collision_layer_value(PhysicsLayers.LAYER_PLAYER, true)
	set_collision_mask_value(PhysicsLayers.LAYER_WORLD, true)
	set_collision_mask_value(PhysicsLayers.LAYER_AI, true)

	# Apply configured FOV at boot (designer can override via @export).
	# PC-002 AC-7.1: abs(Camera3D.fov - 75.0) <= 0.1
	if _camera != null:
		_camera.fov = camera_fov

	# Configure ShapeCast3D collision mask to use the world layer via the
	# PhysicsLayers constant (ADR-0006 IG 1). Zero bare integer literals.
	if _shape_cast != null:
		_shape_cast.collision_mask = PhysicsLayers.MASK_WORLD

	# PC-004 — Build the NOISE_BY_STATE lookup once from export knobs.
	# One-time allocation; never created per-frame. States not in this map
	# (JUMP, FALL, DEAD) are handled by the latched spike path or DEAD
	# early-return in get_noise_level(). TR-PC-012, GDD F.4.
	NOISE_BY_STATE = {
		PlayerEnums.MovementState.IDLE:   0.0,
		PlayerEnums.MovementState.WALK:   noise_walk,
		PlayerEnums.MovementState.SPRINT: noise_sprint,
		PlayerEnums.MovementState.CROUCH: noise_crouch,
		PlayerEnums.MovementState.JUMP:   0.0,
		PlayerEnums.MovementState.FALL:   0.0,
		PlayerEnums.MovementState.DEAD:   0.0,
	}

	# PC-004 — Compute latch duration in frames from the exported seconds value.
	# 0.15 s × 60 Hz = 9 frames (ai-programmer B-2 fix 2026-04-21). TR-PC-014.
	_spike_latch_duration_frames = int(spike_latch_duration_sec * Engine.physics_ticks_per_second)


## Look input consumed in _unhandled_input per GDD §Input processing location.
## Mouse motion: yaw delta → body.rotation.y; pitch delta → camera.rotation.x.
##
## Sign convention (Godot 4 Camera3D, default forward = -Z):
##   Rotation around +X axis follows the right-hand rule, so +rotation.x
##   tilts the forward vector toward +Y — i.e. the camera looks UP.
##   Therefore mouse-down (positive relative.y, "want to look down") must
##   SUBTRACT from rotation.x. The pitch clamp uses ±pitch_clamp_deg with
##   negative = looking down past horizon, positive = looking up past horizon.
##
## PC-002 AC-7.2, AC-7.3.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_yaw_delta(-motion.relative.x * mouse_sensitivity_x)
		# +relative.y (mouse down) → −rotation.x (look down). Without the
		# sign flip the axis is inverted (mouse-down would tilt camera up).
		_camera.rotation.x -= motion.relative.y * mouse_sensitivity_y
		_camera.rotation.x = clampf(
			_camera.rotation.x,
			-deg_to_rad(pitch_clamp_deg),
			deg_to_rad(pitch_clamp_deg)
		)


func _physics_process(delta: float) -> void:
	# PC-003 full movement sequence (GDD §State-machine implementation requirements).
	# Order is mandatory — see story brief Step 1–10.

	# PC-004 — Spike-latch auto-expiry tick. Runs BEFORE all state reads so
	# the latch state is consistent for any system querying this frame.
	# Sole clear mechanism during normal play (Story 007 owns respawn clear).
	# TR-PC-014, GDD F.4.
	if _latch_frames_remaining > 0:
		_latch_frames_remaining -= 1
		if _latch_frames_remaining == 0:
			_latched_event = null

	# Step 1: Clear per-tick flags.
	_pending_head_bump = false
	_jump_fired_this_tick = false

	# Step 2: Tick coyote-time counter.
	if is_on_floor():
		_coyote_frames_remaining = coyote_time_frames
	elif _coyote_frames_remaining > 0:
		_coyote_frames_remaining -= 1

	# Step 3: Resolve crouch toggle (CROUCH ↔ ground state, with ceiling check).
	if Input.is_action_just_pressed(InputActions.CROUCH):
		_handle_crouch_toggle()

	# Step 4: Derive current_state from input + flags.
	_update_movement_state()

	# PC-005 — Resolve interact target once per tick (cached as _current_interact_target).
	# Called AFTER state derivation so current_state is current for the sprint-cap below.
	# The raycast runs unconditionally regardless of _is_hand_busy (forbidden pattern:
	# do NOT gate the raycast on hand-busy; HUD always needs a fresh target).
	# TR-PC-008, GDD F.5, ADR-0006 IG 7.
	_current_interact_target = _resolve_interact_target()

	# PC-005 — E-press handling. Input consumed in _physics_process (not
	# _unhandled_input) because the interact action must be evaluated in the same
	# step as the resolved target cache update. ADR-0004 locked: action = "interact".
	if Input.is_action_just_pressed(InputActions.INTERACT):
		if _is_hand_busy:
			# E.4: second E-press during in-flight interaction — swallow silently.
			pass
		else:
			_start_interact()

	# Step 5: Compute per-state locomotion parameters.
	var max_speed: float = _get_max_speed()
	var accel_time: float = _get_accel_time()
	var decel_time: float = _get_decel_time()

	# Step 6: Build v_target for ground states only.
	# JUMP/FALL preserve takeoff planar velocity — no air control (GDD Forbidden Patterns).
	# Cache input vector once and pass through — _ground_state_from_input below
	# also consumes it (avoids a per-tick double Input.get_vector read).
	var input_xy: Vector2 = _read_movement_input()
	var input_magnitude: float = input_xy.length()

	if _is_ground_state(current_state):
		var direction: Vector3 = (
			transform.basis * Vector3(input_xy.x, 0.0, input_xy.y)
		).normalized()
		var v_target: Vector3 = direction * max_speed
		_apply_horizontal_velocity(delta, v_target, input_magnitude, max_speed, accel_time, decel_time)

	# Step 7: Apply vertical velocity (gravity + jump).
	_apply_vertical_velocity(delta)

	# Step 8: Cache pre-slide values for post-step landing detection.
	_was_on_floor = is_on_floor()
	_pre_slide_velocity_y = velocity.y

	# Step 9: Collision-resolved movement.
	move_and_slide()

	# Step 10: Post-step landing detection and noise spikes.
	_post_step_landing_detection()


# ── Public methods ─────────────────────────────────────────────────────────

## Returns the player's current continuous noise radius in metres.
## Implements GDD §F.4 pull interface for Stealth AI perception polling.
## Pull method — NOT a signal (ADR-0002 IG 5; ~80 Hz aggregate polling rate).
## TR-PC-012.
##
## Rules (in priority order):
##   1. DEAD state always returns 0.0 (defense-in-depth even if latch is non-null).
##   2. Active spike latch → returns latch radius × noise_global_multiplier.
##   3. Idle-velocity gate: WALK or CROUCH with velocity below idle_velocity_threshold
##      returns 0.0 (standing still makes no continuous noise).
##   4. Otherwise returns NOISE_BY_STATE[current_state] × noise_global_multiplier.
func get_noise_level() -> float:
	if current_state == PlayerEnums.MovementState.DEAD:
		return 0.0
	if _latched_event != null:
		return _latched_event.radius_m * noise_global_multiplier
	var moving: bool = velocity.length() >= idle_velocity_threshold
	if (current_state == PlayerEnums.MovementState.WALK
			or current_state == PlayerEnums.MovementState.CROUCH) and not moving:
		return 0.0
	return NOISE_BY_STATE.get(current_state, 0.0) * noise_global_multiplier


## Returns the active latched NoiseEvent, or null if no spike is active.
## Implements GDD §F.4 polling contract for Stealth AI perception.
## Pull method — NOT a signal (ADR-0002 IG 5). Idempotent: does NOT clear
## the latch. Auto-expiry (sole clear mechanism) runs in _physics_process.
## The event object is reused (in-place mutation) — callers MUST copy fields
## before the next physics frame. TR-PC-012, TR-PC-013, TR-PC-014.
func get_noise_event() -> NoiseEvent:
	return _latched_event


## Returns Eve's current silhouette height in metres for Stealth AI visibility.
## GDD §F.8. Lerps from standing (1.7 m) to crouched (1.1 m) based on
## _crouch_transition_progress (written by PC-003 tween; read here).
## DEAD state returns 0.4 m (prone/slumped). TR-PC-018.
func get_silhouette_height() -> float:
	if current_state == PlayerEnums.MovementState.DEAD:
		return silhouette_height_dead
	return lerpf(silhouette_height_standing, silhouette_height_crouched, _crouch_transition_progress)


## Returns the best interactable node currently in the interact raycast, or null
## if nothing is in range. Cached from the most recent _physics_process tick by
## _resolve_interact_target(). This value is the HUD-coherence guarantee — both
## the HUD prompt and the E-press handler see the same resolver result.
##
## Story PC-005 (interact raycast + query API).
## GDD §Detailed Design §Context-sensitive interact.
## TR-PC-008.
##
## Usage example (HUD script):
##   var target: Node3D = player.get_current_interact_target()
##   if target != null:
##       _show_interact_prompt(target)
func get_current_interact_target() -> Node3D:
	return _current_interact_target


## Returns true while the pre-reach-pause or reach-animation Tween is in flight.
## False before E is pressed and after player_interacted fires.
##
## Consumers:
##   - HUD: suppress interact prompt while hand is busy.
##   - Sprint: _get_max_speed() caps sprint to walk_speed during this window.
##   - PC-006 (damage-cancel): apply_damage() kills the reach tween if amount
##     exceeds interact_damage_cancel_threshold (Story 006 TODO).
##
## Story PC-005 (interact raycast + query API). TR-PC-009.
##
## Usage example:
##   if player.is_hand_busy():
##       _hide_interact_prompt()
func is_hand_busy() -> bool:
	return _is_hand_busy


# ── Private methods ────────────────────────────────────────────────────────

## Returns whether the player can jump right now.
## True if on floor OR coyote-time remains AND not currently crouching.
func _can_jump() -> bool:
	return (is_on_floor() or _coyote_frames_remaining > 0) \
		and current_state != PlayerEnums.MovementState.CROUCH

## Determines if a state is a ground locomotion state (horizontal velocity applies).
func _is_ground_state(state: PlayerEnums.MovementState) -> bool:
	return state == PlayerEnums.MovementState.IDLE \
		or state == PlayerEnums.MovementState.WALK \
		or state == PlayerEnums.MovementState.SPRINT \
		or state == PlayerEnums.MovementState.CROUCH


## Derives and sets current_state from input flags and physics state.
## Called each tick AFTER coyote-time update and crouch toggle handling.
func _update_movement_state() -> void:
	var new_state: PlayerEnums.MovementState = current_state

	match current_state:
		PlayerEnums.MovementState.DEAD:
			# Story PC-006 owns the Any → Dead transition. No-op here.
			return

		PlayerEnums.MovementState.JUMP:
			if velocity.y <= 0.0:
				new_state = PlayerEnums.MovementState.FALL

		PlayerEnums.MovementState.FALL:
			if is_on_floor():
				new_state = _ground_state_from_input()

		_:
			# Ground states (IDLE, WALK, SPRINT, CROUCH) + air transition to JUMP.
			if not is_on_floor() and not _is_crouching:
				# Already left floor (no coyote consumed yet) — transition to FALL.
				if not _can_jump():
					new_state = PlayerEnums.MovementState.FALL
			elif _is_crouching:
				new_state = PlayerEnums.MovementState.CROUCH
			else:
				new_state = _ground_state_from_input()

	_set_state(new_state)


## Returns the appropriate ground state (IDLE/WALK/SPRINT) based on current input.
## Reads movement input via _read_movement_input() if no cached vector is supplied.
func _ground_state_from_input() -> PlayerEnums.MovementState:
	var input_xy: Vector2 = _read_movement_input()
	if input_xy.length() < 0.05:
		return PlayerEnums.MovementState.IDLE

	if Input.is_action_pressed(InputActions.SPRINT):
		return PlayerEnums.MovementState.SPRINT

	return PlayerEnums.MovementState.WALK


## Returns the current frame's movement input vector. Single source for the
## InputAction names so callers cannot drift from the canonical four-action
## set declared in `InputActions`.
func _read_movement_input() -> Vector2:
	return Input.get_vector(
		InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT,
		InputActions.MOVE_FORWARD, InputActions.MOVE_BACKWARD
	)


## Sets state and emits state_changed if it differs from current.
func _set_state(new_state: PlayerEnums.MovementState) -> void:
	if new_state != current_state:
		current_state = new_state
		state_changed.emit(current_state)


## Returns the target horizontal speed for the current state in m/s.
## PC-005: sprint is capped to walk_speed while _is_hand_busy (interact window).
## This does not change the state machine — SPRINT state is preserved; only the
## velocity target is clamped. Story PC-003 coordination per story brief.
## TR-PC-009, GDD §Sprint disabled during interact window.
func _get_max_speed() -> float:
	match current_state:
		PlayerEnums.MovementState.WALK:
			return walk_speed
		PlayerEnums.MovementState.SPRINT:
			# PC-005: sprint disabled during interact window — cap to walk_speed.
			if _is_hand_busy:
				return walk_speed
			return sprint_speed
		PlayerEnums.MovementState.CROUCH:
			return crouch_speed
		_:
			return walk_speed  # IDLE still needs a reference for decel step


## Returns the acceleration time constant for the current state in seconds.
func _get_accel_time() -> float:
	match current_state:
		PlayerEnums.MovementState.SPRINT:
			return sprint_accel_time
		_:
			return walk_accel_time


## Returns the deceleration time constant for the current state in seconds.
func _get_decel_time() -> float:
	return walk_decel_time


## F.1 Horizontal velocity blend — ground states only.
## Blends planar velocity toward v_target using move_toward with a
## per-frame step derived from the accel/decel time constant. Delta-clamped.
func _apply_horizontal_velocity(
	delta: float,
	v_target: Vector3,
	input_magnitude: float,
	max_speed: float,
	accel_time: float,
	decel_time: float
) -> void:
	var planar_velocity: Vector2 = Vector2(velocity.x, velocity.z)
	var planar_target: Vector2 = Vector2(v_target.x, v_target.z)
	var rate_time: float
	if input_magnitude > 0.0:
		rate_time = max(accel_time, 0.001)  # NaN guard
	else:
		rate_time = max(decel_time, 0.001)
	var delta_clamped: float = min(delta, _DELTA_CAP)
	var step: float = (1.0 / rate_time) * max_speed * delta_clamped
	planar_velocity = planar_velocity.move_toward(planar_target, step)
	velocity.x = planar_velocity.x
	velocity.z = planar_velocity.y  # Vector2.y maps to world Z


## F.2 Gravity and jump — applied every tick.
## Gravity accumulates when not on floor. Jump fires when JUMP pressed and
## _can_jump() is true.
func _apply_vertical_velocity(delta: float) -> void:
	var delta_clamped: float = min(delta, _DELTA_CAP)
	if not is_on_floor():
		velocity.y -= gravity * delta_clamped
	if Input.is_action_just_pressed(InputActions.JUMP) and _can_jump():
		velocity.y = jump_velocity
		_jump_fired_this_tick = true
		_coyote_frames_remaining = 0  # consume coyote on jump
		_set_state(PlayerEnums.MovementState.JUMP)
		# JUMP_TAKEOFF noise spike (GDD F.3)
		_latch_noise_spike(
			PlayerEnums.NoiseType.JUMP_TAKEOFF,
			noise_jump_takeoff,
			global_position
		)


## Post-step: detect landing and latch appropriate noise spike.
## Impact velocity is read from _pre_slide_velocity_y (cached before move_and_slide).
func _post_step_landing_detection() -> void:
	var just_landed: bool = (not _was_on_floor) and is_on_floor()
	if not just_landed:
		return

	# Compute v_land_hard from F.3: sqrt(2 × gravity × hard_land_height).
	var v_land_hard: float = sqrt(2.0 * gravity * hard_land_height)
	var impact_speed: float = absf(_pre_slide_velocity_y)

	# Transition back to a ground state.
	_set_state(_ground_state_from_input())

	if impact_speed > v_land_hard:
		var radius: float = noise_landing_hard_base * clampf(impact_speed / v_land_hard, 1.0, 2.0)
		_latch_noise_spike(PlayerEnums.NoiseType.LANDING_HARD, radius, global_position)
	else:
		_latch_noise_spike(PlayerEnums.NoiseType.LANDING_SOFT, noise_landing_soft, global_position)


## Handles the crouch toggle (CROUCH key just-pressed).
## Entering CROUCH: allowed from any ground state (not JUMP/FALL — deferred per GDD E.2).
## Exiting CROUCH: blocked if ShapeCast3D detects a ceiling.
func _handle_crouch_toggle() -> void:
	# Mid-air crouch is OUT OF SCOPE for PC-003 (GDD E.2 deferred).
	if current_state == PlayerEnums.MovementState.JUMP \
		or current_state == PlayerEnums.MovementState.FALL:
		return

	if _is_crouching:
		# Attempt to uncrouch — check ceiling first.
		_shape_cast.force_shapecast_update()
		if _shape_cast.is_colliding():
			# Ceiling blocks uncrouch — stay crouched, request SFX.
			_request_head_bump_sfx()
			return
		_set_crouching(false)
	else:
		_set_crouching(true)


## Starts or reverses the crouch transition tween.
## progress_target 1.0 = fully crouched, 0.0 = fully standing.
func _set_crouching(crouching: bool) -> void:
	_is_crouching = crouching
	var progress_target: float = 1.0 if crouching else 0.0

	if _crouch_tween != null and _crouch_tween.is_valid():
		_crouch_tween.kill()

	_crouch_tween = create_tween()
	_crouch_tween.set_parallel(true)

	# Tween _crouch_transition_progress 0↔1 via a method so Story PC-004 can read it.
	_crouch_tween.tween_method(
		_on_crouch_progress,
		_crouch_transition_progress,
		progress_target,
		crouch_transition_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Tween camera eye height 1.6↔1.0.
	var eye_target: float = _CROUCH_EYE_Y if crouching else _STAND_EYE_Y
	_crouch_tween.tween_property(
		_camera, "position:y",
		eye_target,
		crouch_transition_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Tween callback updating capsule height and progress field simultaneously.
func _on_crouch_progress(progress: float) -> void:
	_crouch_transition_progress = progress
	var capsule: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
	if capsule != null:
		capsule.height = lerpf(_STAND_HEIGHT, _CROUCH_HEIGHT, progress)


## Latches a noise spike using the full F.4 policy.
## Highest-radius-wins collision: if a latch is already active with radius ≥
## the new spike's radius, the existing latch is preserved (first-recorded wins
## on ties). Only strictly larger radii overwrite.
## Single reused NoiseEvent instance (allocated once on first spike, then
## mutated in-place) — zero heap allocation on subsequent calls. TR-PC-013.
## Auto-expiry is set to _spike_latch_duration_frames each time a spike wins.
## PC-004 (Story 004). GDD F.4. TR-PC-014.
func _latch_noise_spike(
	type: PlayerEnums.NoiseType,
	radius: float,
	origin: Vector3
) -> void:
	# Highest-radius-wins: equal-or-lower new radius does NOT overwrite.
	if _latched_event != null and _latched_event.radius_m >= radius:
		return
	# Allocate once on the very first spike; reuse the instance thereafter.
	if _latched_event == null:
		_latched_event = NoiseEvent.new()
	# In-place mutation — intentional per GDD F.4. Callers that stored a
	# reference MUST copy fields before the next physics frame (AC-3.5).
	_latched_event.type = type
	_latched_event.radius_m = radius
	_latched_event.origin = origin
	_latch_frames_remaining = _spike_latch_duration_frames


## Requests a soft head-bump SFX when uncrouch is blocked by ceiling.
## Sets _pending_head_bump flag which the Audio epic will consume.
## Full SFX wiring deferred to Audio epic per PC-003 scope.
func _request_head_bump_sfx() -> void:
	_pending_head_bump = true


## F.5 Iterative interact raycast resolver.
##
## Fires up to raycast_max_iterations raycasts along the camera forward axis,
## each time excluding already-hit RIDs so the ray steps through overlapping
## interactables. Selects the best candidate by lowest get_interact_priority()
## value; ties broken by squared distance (closer wins). Objects that do not
## implement get_interact_priority() are skipped (excluded) but count against
## the iteration cap.
##
## If the iteration cap is reached, emits push_warning exactly once and returns
## the best candidate found within the cap (AC-4.2).
##
## Collision contract: query.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST
## (interactables-only layer). NO bare integer literals (ADR-0006 IG 7).
## query.exclude mutation between intersect_ray calls is live in Godot 4.6
## (confirmed per engine notes in story-005 brief).
##
## Called each _physics_process tick. Result cached as _current_interact_target.
## Story PC-005. GDD §Detailed Design F.5. TR-PC-008.
func _resolve_interact_target() -> Node3D:
	var space_state := get_world_3d().direct_space_state
	var ray_origin: Vector3 = _camera.global_position
	var ray_end: Vector3 = ray_origin + (-_camera.global_transform.basis.z * interact_ray_length)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST
	# Re-assign the exclude array each iteration. In-place .append() on the
	# property accessor was observed not to propagate to the next intersect_ray()
	# call in Godot 4.6.2 (Linux Vulkan); explicit re-assignment is reliable.
	var excludes: Array[RID] = []
	query.exclude = excludes
	var best_node: Node3D = null
	var best_priority: int = 2147483647  # INT32_MAX sentinel — GDScript has no INT_MAX constant
	var best_distance_sq: float = INF
	var hit_count: int = 0
	for _i: int in raycast_max_iterations:
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			break
		hit_count += 1
		var collider: Node3D = hit.collider
		if collider.has_method(&"get_interact_priority"):
			var priority: int = collider.get_interact_priority()
			var distance_sq: float = ray_origin.distance_squared_to(hit.position)
			if priority < best_priority or (priority == best_priority and distance_sq < best_distance_sq):
				best_priority = priority
				best_distance_sq = distance_sq
				best_node = collider
		excludes.append(hit.rid)
		query.exclude = excludes
	if hit_count == raycast_max_iterations:
		push_warning(
			"interact raycast hit iteration cap (%d); a higher-priority interactable may be beyond the cap"
			% raycast_max_iterations
		)
	return best_node


## Starts the E-press interact flow: pre-reach pause Tween → reach Tween →
## Events.player_interacted emit.
##
## Flow (per GDD §E-press handling, TR-PC-009):
##   1. Set _is_hand_busy = true.
##   2. Pre-reach-pause Tween (interact_pre_reach_ms ms) — visual hand-raise cue.
##      On complete → start reach Tween.
##   3. Reach Tween (interact_reach_duration_ms ms).
##      On complete → check is_instance_valid(_current_interact_target):
##        - Valid → emit Events.player_interacted.emit(_current_interact_target)
##        - Invalid (E.11: target freed mid-reach) → emit Events.player_interacted.emit(null)
##      Set _is_hand_busy = false in the same stack frame as the emit.
##
## Sprint-disabled-during-interact is enforced via _get_max_speed() reading
## _is_hand_busy (no state-machine change required).
##
## TODO PC-006: apply_damage() damage-cancel hook kills _interact_reach_tween and
## sets _is_hand_busy = false when amount >= interact_damage_cancel_threshold.
## See story-006-damage-cancel.md for the E.6 integration spec.
##
## Story PC-005. GDD F.5, E.4, E.11. TR-PC-009.
func _start_interact() -> void:
	_is_hand_busy = true

	# Kill any stale tweens (defensive — should not happen when not hand-busy).
	if _interact_pre_reach_tween != null and _interact_pre_reach_tween.is_valid():
		_interact_pre_reach_tween.kill()
	if _interact_reach_tween != null and _interact_reach_tween.is_valid():
		_interact_reach_tween.kill()

	var pre_reach_sec: float = interact_pre_reach_ms / 1000.0
	_interact_pre_reach_tween = create_tween()
	# Tween a dummy value (the pre-reach is a timing pause, not a property change).
	# tween_interval is the idiomatic zero-property delay in Godot 4 Tweens.
	_interact_pre_reach_tween.tween_interval(pre_reach_sec)
	_interact_pre_reach_tween.tween_callback(_on_pre_reach_complete)


## Called when the pre-reach-pause Tween completes. Starts the reach Tween.
## Story PC-005. TR-PC-009.
func _on_pre_reach_complete() -> void:
	# Guard: if hand became un-busy (damage cancel from PC-006) during the
	# pre-reach window, do not start the reach phase.
	if not _is_hand_busy:
		return

	var reach_sec: float = interact_reach_duration_ms / 1000.0
	_interact_reach_tween = create_tween()
	_interact_reach_tween.tween_interval(reach_sec)
	_interact_reach_tween.tween_callback(_on_reach_complete)


## Called when the reach Tween completes. Emits player_interacted and clears
## the hand-busy flag.
##
## E.11 (target destroyed mid-reach): is_instance_valid() is checked HERE, not
## at E-press time. If the target was freed during the reach window, emits null
## instead of an invalid reference. _is_hand_busy is set to false in this same
## stack frame as the emit (story spec requirement).
##
## Story PC-005. GDD E.11. TR-PC-009.
func _on_reach_complete() -> void:
	var target: Node3D = null
	if is_instance_valid(_current_interact_target):
		target = _current_interact_target
	# E.11: target freed mid-reach → emit null (not an invalid node reference).
	Events.player_interacted.emit(target)
	_is_hand_busy = false


## Applies a single yaw delta to body.rotation.y and detects rapid-yaw to
## trigger the camera overshoot Tween. Detached from input handler so it can
## be exercised by the gamepad path without duplicating the rapid-yaw heuristic.
## PC-002 AC-7.3, AC-7.4.
func _apply_yaw_delta(delta_radians: float) -> void:
	rotation.y += delta_radians  # CharacterBody3D body yaw

	# Rapid-yaw detection: > turn_overshoot_threshold_deg_per_frame triggers
	# a camera-only overshoot Tween that settles within turn_overshoot_return_ms.
	var delta_deg: float = abs(rad_to_deg(delta_radians))
	if delta_deg > turn_overshoot_threshold_deg_per_frame:
		_play_turn_overshoot(sign(delta_radians))


## Plays a camera-only overshoot tween (camera.rotation.y, NOT body.rotation.y).
## Single permitted camera-feel deviation from "no sway" per GDD §60. Settle
## eases out monotonically; no spring oscillation. PC-002 AC-7.4.
func _play_turn_overshoot(direction: float) -> void:
	if _overshoot_tween != null and _overshoot_tween.is_valid():
		_overshoot_tween.kill()

	var overshoot_radians: float = deg_to_rad(turn_overshoot_deg) * direction
	var settle_seconds: float = turn_overshoot_return_ms / 1000.0

	_camera.rotation.y = overshoot_radians
	_overshoot_tween = create_tween()
	_overshoot_tween.tween_property(
		_camera, "rotation:y", 0.0, settle_seconds
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
