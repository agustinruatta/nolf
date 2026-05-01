# res://src/gameplay/player/player_enums.gd
#
# PlayerEnums — pure enum host for the PlayerCharacter system. No runtime
# logic; just enum types. Per ADR-0002 IG 2: enums live on the consumer
# class that owns the concept (here, PlayerCharacter), NOT on events.gd.
# Per Player Character GDD §Detailed Design Core Rules.
#
# Why a separate enum host file (not inner classes on PlayerCharacter):
# the enums are referenced from NoiseEvent and from save_load PlayerState's
# current_state field. Inner-class enums on PlayerCharacter would create a
# circular parse dependency (NoiseEvent → PlayerCharacter → NoiseEvent).
# Hosting them on a separate RefCounted breaks the cycle.
#
# Implements: Story PC-001 (scene root scaffold)

class_name PlayerEnums
extends RefCounted

## Movement state machine — the player's locomotion mode at a given frame.
## Story PC-003 owns the transition rules; this scaffold just declares the
## enum and PlayerCharacter holds an instance variable typed by it.
enum MovementState {
	IDLE,
	WALK,
	SPRINT,
	CROUCH,
	JUMP,
	FALL,
	DEAD,
}

## NoiseType — the kind of player-generated noise spike used by Stealth AI
## perception polling. Different types have different default radii (Story
## PC-004 owns the radius mapping). Six values cover the MVP scope per GDD
## §Detailed Design Core Rules.
enum NoiseType {
	FOOTSTEP_SOFT,
	FOOTSTEP_NORMAL,
	FOOTSTEP_LOUD,
	JUMP_TAKEOFF,
	LANDING_SOFT,
	LANDING_HARD,
}
