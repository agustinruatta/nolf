# res://src/gameplay/stealth/patrol_controller.gd
#
# PatrolController — Child Node of Guard that samples a Path3D curve and writes
# successive waypoint positions to NavigationAgent3D.target_position when the
# navigation_finished signal fires.
#
# Wiring contract:
#   Guard._ready() has an @onready var pointing to this node.
#   Guard calls start_patrol() on UNAWARE entry and stop_patrol() on any
#   escalation away from UNAWARE.
#
# Nav-mesh note (Godot 4.6):
#   NavigationAgent3D.target_position writes dispatch an async path query on the
#   nav server background thread. navigation_finished fires on the main thread
#   when the agent reports the destination as reached (is_navigation_finished()
#   returns true on the NEXT physics frame after the query resolves).
#   FORBIDDEN: NavigationServer3D.map_get_path() synchronous calls (ADR-0006).
#
# Implements: Story SAI-006 AC-1
# GDD: design/gdd/stealth-ai.md §Detailed Rules (Guard node architecture)
# ADR: ADR-0006 (Collision Layer Contract — nav async dispatch only)

class_name PatrolController extends Node


# ── Public API ────────────────────────────────────────────────────────────────

## The Path3D resource defining the patrol route. Assigned in the scene editor.
## If null, the controller idles (no waypoints advanced, E.12 fallback applies).
@export var path: Path3D

## Baked-distance offsets (metres along the curve) of each waypoint.
## If left empty in the editor, _ready() samples 5 evenly-spaced points.
## Scene designers can override with a hand-authored array for precise waypoints.
@export var waypoint_offsets_m: Array[float] = []


# ── Private state ─────────────────────────────────────────────────────────────

## Cached NavigationAgent3D from the parent Guard node. Resolved in _ready().
var _nav_agent: NavigationAgent3D = null

## Index of the NEXT waypoint to dispatch (advanced after each dispatch).
var _next_waypoint_index: int = 0

## True while the guard is in UNAWARE state and actively patrolling.
## Set to false on stop_patrol(); guards against advancing waypoints while
## the guard is SUSPICIOUS or higher.
var _is_patrolling: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Resolve NavigationAgent3D from parent (Guard scene hierarchy).
	var parent: Node = get_parent()
	if parent != null and parent.has_node(^"NavigationAgent3D"):
		_nav_agent = parent.get_node(^"NavigationAgent3D") as NavigationAgent3D

	# Build default evenly-spaced waypoints if designer left the array empty.
	if path != null and waypoint_offsets_m.is_empty():
		var curve_length: float = path.curve.get_baked_length()
		for i: int in range(5):
			waypoint_offsets_m.append((curve_length / 5.0) * i)


# ── Public API ────────────────────────────────────────────────────────────────

## Start patrolling. Called by Guard when entering (or re-entering) UNAWARE state.
##
## Connects to NavigationAgent3D.navigation_finished (idempotent — safe to call
## repeatedly) and dispatches the first waypoint.
##
## No-ops gracefully when path or NavigationAgent3D is null, or when waypoints
## are empty — E.12 nav-fail fallback is owned by the stuck-recovery timer.
func start_patrol() -> void:
	if _nav_agent == null or path == null or waypoint_offsets_m.is_empty():
		_is_patrolling = false
		return
	_is_patrolling = true
	if not _nav_agent.navigation_finished.is_connected(_on_navigation_finished):
		_nav_agent.navigation_finished.connect(_on_navigation_finished)
	_dispatch_next_waypoint()


## Stop patrolling. Called by Guard when leaving UNAWARE state (e.g., to SUSPICIOUS).
##
## Disconnects the navigation_finished callback so waypoint advancement is frozen
## while the guard is investigating or in combat.
func stop_patrol() -> void:
	_is_patrolling = false
	if _nav_agent != null and _nav_agent.navigation_finished.is_connected(_on_navigation_finished):
		_nav_agent.navigation_finished.disconnect(_on_navigation_finished)


## Returns the world-space position of the waypoint most recently dispatched to
## NavigationAgent3D. Used by unit tests to verify dispatch correctness without
## running a real nav mesh.
##
## Returns Vector3.ZERO when no dispatch has occurred (path null or empty).
func get_current_waypoint_position() -> Vector3:
	if path == null or waypoint_offsets_m.is_empty():
		return Vector3.ZERO
	# _next_waypoint_index was already advanced after the last dispatch; the
	# dispatched waypoint is at index (_next_waypoint_index - 1) modulo size.
	var dispatched_idx: int = (_next_waypoint_index - 1 + waypoint_offsets_m.size()) \
			% waypoint_offsets_m.size()
	var local_pos: Vector3 = path.curve.sample_baked(waypoint_offsets_m[dispatched_idx], false)
	return path.global_transform * local_pos


## Returns true when the controller is actively advancing waypoints.
## False means patrol is paused (guard is SUSPICIOUS+ or has no path).
func is_patrolling() -> bool:
	return _is_patrolling


# ── Private helpers ───────────────────────────────────────────────────────────

## Dispatch the waypoint at _next_waypoint_index to NavigationAgent3D, then
## advance the index (wrapping to 0 at path end).
func _dispatch_next_waypoint() -> void:
	if _nav_agent == null or path == null or waypoint_offsets_m.is_empty():
		return
	var local_pos: Vector3 = path.curve.sample_baked(
			waypoint_offsets_m[_next_waypoint_index], false
	)
	var world_pos: Vector3 = path.global_transform * local_pos
	_nav_agent.target_position = world_pos
	_next_waypoint_index = (_next_waypoint_index + 1) % waypoint_offsets_m.size()


## navigation_finished callback. Advances to the next waypoint while patrolling.
## Safe no-op when _is_patrolling == false (called after stop_patrol races a
## queued callback before disconnect takes effect).
func _on_navigation_finished() -> void:
	if _is_patrolling:
		_dispatch_next_waypoint()
