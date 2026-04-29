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
# This file is a Sprint 01 verification-spike stub — pass-through so the
# autoload entry resolves. Real implementation lands in the Combat & Damage
# production story under the feature layer epic.

extends Node


func _ready() -> void:
	pass
