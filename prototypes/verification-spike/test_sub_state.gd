# prototypes/verification-spike/test_sub_state.gd
#
# Top-level typed Resource used as a nested @export field on TestSaveGame.
# Mirrors how production SaveGame declares per-system state Resources
# (PlayerState, InventoryState, etc. — each in its own file with class_name).
#
# FINDING (Sprint 01 verification): inner-class Resources used as @export
# types do NOT round-trip through ResourceSaver/ResourceLoader correctly —
# the @export field comes back null after load. Production save Resources
# MUST be top-level class_name'd in their own file. This finding will be
# folded into ADR-0003 §Implementation Guidelines on amendment.

class_name TestSubState extends Resource

@export var actor_id: StringName = &""
# Dictionary[K,V] typed-dict — 4.4+ syntax; round-trip exercised by Gate 1.
@export var ammo_magazine: Dictionary[StringName, int] = {}
@export var fired_beats: Dictionary[StringName, bool] = {}
