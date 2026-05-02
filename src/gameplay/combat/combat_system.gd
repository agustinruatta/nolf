# res://src/gameplay/combat/combat_system.gd
#
# CombatSystemNode — damage routing hub. Per `design/gdd/combat-damage.md`
# §350 + TR-CD-022. Registered as autoload key `Combat` at line 7 of
# project.godot per ADR-0007 §Key Interfaces.
#
# class_name / autoload-key split (intentional, mirrors SignalBusEvents/Events
# on line 1): class_name `CombatSystemNode` is the parse-time anchor for
# enum references (DamageType, DeathCause); the autoload key `Combat` is the
# call-site name (Combat.apply_damage_to_actor(...)).
#
# Real behaviour: stateless damage-routing hub invoked from arbitrary
# scene-tree positions (SAI guards, Player controller, projectile nodes);
# emits Events.enemy_damaged / enemy_killed / weapon_fired / ammo_changed.
#
# This file is a Sprint 04 PC-006 stub — provides the parse-time enum anchors
# so PlayerCharacter.apply_damage(amount, source, damage_type) can typecheck.
# Real damage-routing implementation lands in the Combat & Damage production
# story under the feature layer epic.

class_name CombatSystemNode extends Node


# ── DamageType enum (PC-006 stub — replaced when Combat & Damage GDD lands) ──

## DamageType classifies the cause of a damage event so subscribers can route
## to the correct VFX / audio / death-cause mapping. PC-006 minimum: TEST is
## the placeholder used by unit tests. OUT_OF_BOUNDS is reserved for falling
## off the map. Full taxonomy lands with the Combat & Damage GDD.
enum DamageType {
	TEST,
	OUT_OF_BOUNDS,
}


# ── DeathCause enum (PC-006 stub — replaced when Combat & Damage GDD lands) ──

## DeathCause classifies the death event for Failure & Respawn / save logging.
## PC-006 minimum: UNKNOWN is the catch-all sentinel. Full taxonomy
## (e.g., GUNSHOT, EXPLOSION, FALL) lands with the Combat & Damage GDD.
enum DeathCause {
	UNKNOWN,
}


# ── Static helpers ────────────────────────────────────────────────────────────

## Maps a DamageType to the corresponding DeathCause for `Events.player_died`.
## PC-006 stub returns UNKNOWN for all DamageType values; the real mapping
## table lands with the Combat & Damage GDD.
static func damage_type_to_death_cause(_damage_type: DamageType) -> DeathCause:
	return DeathCause.UNKNOWN


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	pass
