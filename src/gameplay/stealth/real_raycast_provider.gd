# res://src/gameplay/stealth/real_raycast_provider.gd
#
# RealRaycastProvider — Production IRaycastProvider that delegates to
# PhysicsDirectSpaceState3D.intersect_ray.
#
# USAGE: Instantiate in Guard._ready() ONLY (NOT in _init()):
#   var space_state := get_world_3d().direct_space_state
#   var provider := RealRaycastProvider.new(space_state)
#   $Perception.init(provider)
#
# PhysicsDirectSpaceState3D is only valid inside the scene tree. NEVER obtain
# it from _init() of a node script — the space state is unavailable before the
# node enters the tree. Always call get_world_3d().direct_space_state in _ready().
#
# Implements: Story SAI-003 (TR-SAI-016)
# GDD: design/gdd/stealth-ai.md §F.1 — RaycastProvider DI interface

class_name RealRaycastProvider extends IRaycastProvider

var _space_state: PhysicsDirectSpaceState3D


## Initialises the provider with a valid PhysicsDirectSpaceState3D.
##
## [param space_state] must be non-null. Obtain via
## `get_world_3d().direct_space_state` in `_ready()`, never from `_init()`.
func _init(space_state: PhysicsDirectSpaceState3D) -> void:
	assert(space_state != null,
			"RealRaycastProvider: space_state must not be null. " +
			"Obtain via get_world_3d().direct_space_state in _ready().")
	_space_state = space_state


## Delegates to PhysicsDirectSpaceState3D.intersect_ray and returns the result.
## Returns {} if no collision is detected.
func cast(query: PhysicsRayQueryParameters3D) -> Dictionary:
	return _space_state.intersect_ray(query)
