# res://src/core/save_load/save_game.gd
#
# SaveGame — canonical persistence container per ADR-0003 (Save Format Contract).
# Aggregates 7 typed per-system *_State sub-resources.
#
# Per ADR-0003 IG 1: FORMAT_VERSION is the runtime-immutable schema sentinel
# (compared on load to refuse mismatched saves). save_format_version is the
# serialized field, defaulted from FORMAT_VERSION at construction.
#
# Per ADR-0003 IG 11: every typed-Resource @export field below references a
# top-level class_name-registered Resource declared in its own file under
# src/core/save_load/states/. Inner-class typed Resources are forbidden — they
# come back null after ResourceLoader.load (Sprint 01 verification finding F2).

class_name SaveGame
extends Resource

## Schema version sentinel — bumped when the SaveGame schema changes in any
## non-additive way (field removal, type change, semantic change).
const FORMAT_VERSION: int = 2

## Serialized schema version. Defaults to FORMAT_VERSION at construction;
## SaveLoadService compares this against FORMAT_VERSION on load and refuses
## mismatched saves (no migration path at MVP per TR-SAV-008).
@export var save_format_version: int = FORMAT_VERSION

## ISO-8601 timestamp set at save time (e.g., "2026-04-30T14:32:15").
@export var saved_at_iso8601: String = ""

## Section ID where the player was when the save was taken (e.g., &"plaza").
@export var section_id: StringName = &""

## Total elapsed gameplay seconds at save time. Drives the playtime display.
@export var elapsed_seconds: float = 0.0

## Per-system state sub-resources. Each is a top-level class_name Resource in
## src/core/save_load/states/ per ADR-0003 IG 11.
@export var player: PlayerState
@export var inventory: InventoryState
@export var stealth_ai: StealthAIState
@export var civilian_ai: CivilianAIState
@export var documents: DocumentCollectionState
@export var mission: MissionState
@export var failure_respawn: FailureRespawnState


func _init() -> void:
	# Default-initialise sub-resources so a freshly-constructed SaveGame is
	# round-trippable without explicit field assignment by the caller.
	if player == null:
		player = PlayerState.new()
	if inventory == null:
		inventory = InventoryState.new()
	if stealth_ai == null:
		stealth_ai = StealthAIState.new()
	if civilian_ai == null:
		civilian_ai = CivilianAIState.new()
	if documents == null:
		documents = DocumentCollectionState.new()
	if mission == null:
		mission = MissionState.new()
	if failure_respawn == null:
		failure_respawn = FailureRespawnState.new()
