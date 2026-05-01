# prototypes/verification-spike/stub_player_character.gd
#
# StubPlayerCharacter — synthetic proxy for the future PlayerCharacter node.
# Lives in prototypes/ only — never merged to src/.
#
# Proxies the two methods guards poll per PC-004 spec:
#   get_noise_level() -> float      (returns constant 5.0)
#   get_noise_event() -> NoiseEvent (single reused instance, in-place mutated)
#
# In-place mutation is intentional per NoiseEvent GDD §F.4: zero-alloc at 80 Hz.

extends Node3D

var _noise_event: NoiseEvent = NoiseEvent.new()
var _call_count: int = 0


## Stub: constant noise level proxying PlayerCharacter.get_noise_level().
func get_noise_level() -> float:
	return 5.0


## Stub: returns the single in-place-mutated NoiseEvent.
## Callers must copy fields before the next frame.
func get_noise_event() -> NoiseEvent:
	_call_count += 1
	_noise_event.type = PlayerEnums.NoiseType.FOOTSTEP_NORMAL
	_noise_event.radius_m = 4.5 + fmod(float(_call_count), 0.5)
	_noise_event.origin = Vector3(0.0, 0.0, float(_call_count) * 0.001)
	return _noise_event
