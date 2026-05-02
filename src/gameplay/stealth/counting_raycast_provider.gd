# res://src/gameplay/stealth/counting_raycast_provider.gd
#
# CountingRaycastProvider — TEST-ONLY IRaycastProvider double.
#
# TEST-ONLY TYPE. Do not reference from production .tscn files or @export vars.
# The control manifest forbids this type from production scenes (Feature Layer
# Guardrail: CountingRaycastProvider must not appear in production scene files
# or exported vars — Story SAI-003 §Control Manifest Rules).
#
# Tracks how many times cast() is called and returns a scripted result,
# enabling deterministic unit tests of the Perception system without touching
# the physics engine.
#
# Implements: Story SAI-003 (TR-SAI-016)
# GDD: design/gdd/stealth-ai.md §F.1 — RaycastProvider DI interface (test double)

class_name CountingRaycastProvider extends IRaycastProvider

## Number of times cast() has been called. Starts at 0.
## Asserted in tests to verify the accessor never issues a new raycast
## on cache-hit or cold-start paths.
var call_count: int = 0

## The result dict returned verbatim by every cast() call.
## Set this before calling code under test to simulate a hit or miss.
## Default {} simulates no-hit (empty result).
var scripted_result: Dictionary = {}


## Increments call_count and returns scripted_result.
## Never touches the physics engine.
func cast(_query: PhysicsRayQueryParameters3D) -> Dictionary:
	call_count += 1
	return scripted_result
