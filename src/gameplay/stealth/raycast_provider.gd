# res://src/gameplay/stealth/raycast_provider.gd
#
# IRaycastProvider — Abstract DI seam for physics raycasts in the Stealth AI
# perception system.
#
# DESIGN RATIONALE: PhysicsDirectSpaceState3D.intersect_ray is an engine built-in
# that cannot be monkey-patched for testability. Exposing this interface allows
# unit tests to inject a CountingRaycastProvider double without touching the
# physics engine (per coding-standards: DI over singletons).
#
# ABSTRACT CHOICE: This class uses the @abstract annotation (GDScript 4.5+,
# available in Godot 4.6) at the CLASS level to prevent direct instantiation of
# IRaycastProvider. Subclasses must override cast(). Using class-level @abstract
# is stricter than a push_error body — IRaycastProvider.new() causes a GDScript
# error at runtime rather than at call time.
#
# Implements: Story SAI-003 (TR-SAI-016)
# GDD: design/gdd/stealth-ai.md §F.1 — RaycastProvider DI interface

@abstract
class_name IRaycastProvider extends RefCounted


## Casts a ray using the provided query parameters and returns the result dict.
##
## Result dict schema (from PhysicsDirectSpaceState3D.intersect_ray):
##   {position: Vector3, normal: Vector3, collider: Object, rid: RID,
##    collider_id: int, shape: int, metadata: Variant}
## Returns {} if no collision was detected.
##
## Subclasses MUST override this method.
@abstract
func cast(query: PhysicsRayQueryParameters3D) -> Dictionary
