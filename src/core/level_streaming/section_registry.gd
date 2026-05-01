# res://src/core/level_streaming/section_registry.gd
#
# SectionRegistry — Resource mapping section_id → {scene path + display_name_loc_key}.
#
# Used by LevelStreamingService.transition_to_section to look up the destination
# scene and the localized display name. The registry resource is stored at
# `res://assets/data/section_registry.tres` and loaded once at LSS autoload
# `_ready()`.
#
# Untyped Dictionary (per Inventory CR-11 — TypedDictionary stability is
# unverified post-cutoff for the Resource serialization path); inner-shape is
# documented in the @export comment.
#
# Implements: Story LS-001 (registry scaffold)
# Requirements: TR-LS-004
# GDD: design/gdd/level-streaming.md §Detailed Design CR-3

class_name SectionRegistry
extends Resource

## Section dictionary mapping `StringName` section_id to a sub-dictionary:
##   `{"path": "res://scenes/sections/<id>.tscn", "display_name_loc_key": "meta.section.<id>"}`
##
## Authored via the Godot Inspector OR hand-edited in the .tres file. Adding
## a new section: append a new key to this dictionary; no code changes required.
@export var sections: Dictionary = {}


## Returns true if the given section_id is registered.
func has_section(section_id: StringName) -> bool:
	return sections.has(section_id)


## Returns the scene path for the given section, or empty string if missing.
func path(section_id: StringName) -> String:
	var entry: Dictionary = sections.get(section_id, {})
	return entry.get("path", "")


## Returns the localization key for the section's display name, or empty if missing.
func display_name_loc_key(section_id: StringName) -> String:
	var entry: Dictionary = sections.get(section_id, {})
	return entry.get("display_name_loc_key", "")


## Returns the list of registered section_ids.
func section_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in sections.keys():
		out.append(k as StringName)
	return out
