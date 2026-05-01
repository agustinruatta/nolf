# res://src/gameplay/player/player_character.gd
#
# PlayerCharacter — Eve's CharacterBody3D root script.
#
# PC-001 (scaffold): node hierarchy, collision layer setup per ADR-0006,
#   class-scope state vars typed by PlayerEnums.
# PC-002 (camera + look input): Camera3D FOV, mouse/gamepad look processing
#   in _unhandled_input, pitch clamp, yaw-body split, turn-overshoot Tween.
#
# Collision layer setup per ADR-0006 IG 1 + IG 6: this body sets its OWN
# layer (LAYER_PLAYER) and masks the layers it COLLIDES AGAINST (WORLD + AI).
# Zero bare integer literals — all references go through PhysicsLayers.*.
#
# Camera/look input consumed in _unhandled_input (NOT _physics_process) per
# GDD §Input processing location: avoids mouse-delta accumulation lump on
# high-refresh-rate displays. Body rotates on Y (yaw); camera rotates on X
# (pitch); roll always 0 outside sprint-sway window (Story PC-003).
#
# Sign convention: Camera3D +X rotation pitches nose DOWN (Godot convention).
# Mouse down (positive relative.y) → look down → rotation.x increases → +85°
# clamp. Mouse up (negative relative.y) → look up → rotation.x decreases → -85°.
#
# Implements: Story PC-001 (scene root scaffold)
#             Story PC-002 (first-person camera + look input)
# GDD: design/gdd/player-character.md §Detailed Design Core Rules

class_name PlayerCharacter
extends CharacterBody3D

## Current movement state. Story PC-003 owns the transition logic; here we
## declare it at IDLE so the static typing contract holds at scaffold scope.
var current_state: PlayerEnums.MovementState = PlayerEnums.MovementState.IDLE

## CharacterBody3D already provides `velocity: Vector3` as a native built-in
## property used by move_and_slide(). GDScript 4.x forbids redeclaring built-in
## parent properties (parse error). Story PC-003 reads/writes `velocity` directly
## (the inherited property) for move_and_slide integration. No redeclaration
## needed — the built-in property is already typed Vector3 and initialised to
## Vector3.ZERO by the engine. Documented here per AC-6 static-typing contract.

# ── Camera tuning (designer-tunable; settings will override at runtime) ────

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

# ── Cached node refs (no $NodePath lookups in input/process loops) ─────────

@onready var _camera: Camera3D = $Camera3D

# ── Internal state ─────────────────────────────────────────────────────────

var _overshoot_tween: Tween = null


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


## Look input consumed in _unhandled_input per GDD §Input processing location.
## Mouse motion: yaw delta → body.rotation.y; pitch delta → camera.rotation.x.
## Sign convention: positive relative.y (mouse down) → positive rotation.x (look down).
## PC-002 AC-7.2, AC-7.3.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_yaw_delta(-motion.relative.x * mouse_sensitivity_x)
		# +relative.y (mouse down) → +rotation.x (look down) → clamped at +85°.
		_camera.rotation.x += motion.relative.y * mouse_sensitivity_y
		_camera.rotation.x = clampf(
			_camera.rotation.x,
			-deg_to_rad(pitch_clamp_deg),
			deg_to_rad(pitch_clamp_deg)
		)


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


func _physics_process(_delta: float) -> void:
	# SCAFFOLD: the movement state machine + locomotion + jump/fall/coyote
	# logic is owned by Story PC-003. This empty body keeps the lifecycle
	# hook installed so PC-003 can extend without altering the scaffold.
	pass
