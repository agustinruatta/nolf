# res://src/gameplay/interactables/interact_priority.gd
#
# InteractPriority — Pure-data priority enum for the context-sensitive interact
# resolver (GDD §Detailed Design §Context-sensitive interact, F.5 iterative
# raycast). Lower numeric value = higher priority.
#
# The numeric values ARE the contract — interactable implementors return the
# value from get_interact_priority(). Adding a new interactable type = append
# to Kind and implement get_interact_priority() on the new class. Never
# reorder or change existing values.
#
# Implements: Story PC-005 (interact raycast + query API)
# Requirements: TR-PC-008
# GDD: design/gdd/player-character.md §Detailed Design §Context-sensitive interact

class_name InteractPriority
extends RefCounted

## Priority levels for the F.5 iterative interact raycast resolver.
## Lower value = resolved first when two interactables are in the ray.
## DOCUMENT (0) < TERMINAL (1) < PICKUP (2) < DOOR (3).
## TR-PC-008 — GDD §Detailed Design §Context-sensitive interact.
enum Kind {
	DOCUMENT = 0,
	TERMINAL = 1,
	PICKUP   = 2,
	DOOR     = 3,
}
