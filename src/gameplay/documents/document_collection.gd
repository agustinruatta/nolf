# res://src/gameplay/documents/document_collection.gd
#
# DocumentCollection — subscribe/publish lifecycle + pickup handler + save/restore contract.
#
# Implements: design/gdd/document-collection.md §C.6 (pseudocode), §C.1
#             TR-DC-001, TR-DC-005, TR-DC-006, TR-DC-007, TR-DC-008,
#             TR-DC-012, TR-DC-013, TR-DC-014, TR-DC-015
# ADR refs:   ADR-0002 (Signal Bus + Event Taxonomy) — IG 3, IG 4
#             ADR-0003 (Save Format Contract) — IG 3, CR-6 duplicate discipline
#             ADR-0007 (Autoload Load Order Registry) — NOT autoload
# Story:      DC-003 (subscribe/publish lifecycle + pickup handler)
#             DC-004 (save/restore contract — capture(), restore(), spawn-gate)
#
# PLACEMENT (ADR-0007)
#   Instantiated as Section/Systems/DocumentCollection in the section scene.
#   Lifetime equals section lifetime; freed when LevelStreamingService unloads
#   the section. DocumentCollectionState is the persistent data object on
#   SaveGame. This node is ephemeral.
#
# SIGNAL CONTRACT (ADR-0002 §Key Interfaces — 3-signal Document domain)
#   Sole publisher of:
#     Events.document_collected(document_id: StringName)
#     Events.document_opened(document_id: StringName)
#     Events.document_closed(document_id: StringName)
#   No other file may emit these signals (CR-7 sole-publisher invariant).
#
# PERFORMANCE (CR-15 zero-steady-state budget)
#   No _process or _physics_process override.
#   Purely event-driven; zero per-frame cost.
#
# FORBIDDEN METHODS (CR-13 no-quest-counter absolute)
#   Aggregate query helpers are forbidden by CR-13. They are not defined here.
#   _collected.size() is DC-internal only.

## DocumentCollection — event-driven document pickup handler for one section.
##
## Subscribes to Events.player_interacted in _ready() and disconnects in
## _exit_tree(). Validates payloads via a mandatory 4-step guard sequence
## (ADR-0002 IG 4 + GDD AC-DC-6.5). Appends collected ids to _collected,
## emits Events.document_collected exactly once per unique id, and defers
## body removal via call_deferred("queue_free").
##
## open_document() / close_document() are VS API scaffolding stubs (CR-11/CR-12);
## they emit the matching Document-domain signals so unit tests can verify the
## signal contract without a Document Overlay UI implementation.
##
## capture() / restore() / _gate_collected_bodies_in_section() implement the
## save/restore contract (DC-004, ADR-0003, GDD §H.4–§H.5):
##   - capture() returns a defensive copy for SaveGame assembly by MLS.
##   - restore() is called by MLS within its LS step-9 callback BEFORE
##     section_entered is emitted; applies state and runs the spawn-gate.
##   - _gate_collected_bodies_in_section() synchronously frees bodies whose
##     id is already in _collected so they never appear to the player.
##
## Canonical scene path: Section/Systems/DocumentCollection
## NOT registered as autoload (ADR-0007).
class_name DocumentCollection
extends Node


# Explicit preloads to ensure Document + DocumentBody scripts are resolved at
# parse time, in dependency order (Document first — DocumentBody depends on it).
# Without this, scenes that load document_collection.gd before the global class
# registry has scanned src/gameplay/documents/ trigger "Could not find type
# DocumentBody/Document" parse errors (observed in level_streaming_swap_test).
const _DOCUMENT_SCRIPT: Script = preload("res://src/gameplay/documents/document.gd")
const _DOCUMENT_BODY_SCRIPT: Script = preload("res://src/gameplay/documents/document_body.gd")


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Scene group that all DocumentBody nodes in a section must belong to.
## Centralises the group name used by the spawn-gate and any future
## scene-query callers (advisory finding from DC-003 code-review).
const SECTION_DOCUMENTS_GROUP: StringName = &"section_documents"


# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

## Ordered list of document ids collected this section visit.
## Internal only — never exposed via public getters (CR-13).
var _collected: Array[StringName] = []

## Id of the currently open document, or &"" when none is open.
## Used by VS API stubs (open_document / close_document).
var _open_document_id: StringName = &""


# ---------------------------------------------------------------------------
# Lifecycle — signal connect / disconnect (ADR-0002 IG 3)
# ---------------------------------------------------------------------------

## Subscribes to Events.player_interacted.
## Per ADR-0002 IG 3: connect in _ready(), disconnect in _exit_tree().
func _ready() -> void:
	Events.player_interacted.connect(_on_player_interacted)


## Disconnects from Events.player_interacted with is_connected() guard
## to prevent double-disconnect errors and memory leaks.
## Per ADR-0002 IG 3 + AC-DC-2.4.
func _exit_tree() -> void:
	if Events.player_interacted.is_connected(_on_player_interacted):
		Events.player_interacted.disconnect(_on_player_interacted)


# ---------------------------------------------------------------------------
# Signal handler — mandatory guard sequence (AC-DC-6.5, CR-17)
# ---------------------------------------------------------------------------

## Handles the player_interacted signal. Applies a mandatory 4-step guard
## sequence in order (GDD §C.6 pseudocode, CR-17):
##   Guard 1 — is_instance_valid(target) — ADR-0002 IG 4 (null/freed-node check)
##   Guard 2 — target is DocumentBody    — filter non-document interactables
##   Guard 3 — target.document != null   — GDD E.15 null-export guard
##   Idempotency — _collected.has(id)    — AC-DC-2.2 (no re-emit)
##   Happy path  — append → emit → deferred free
##
## Parameters:
##   target — Node3D payload from Events.player_interacted; may be null or
##             any interactable (ADR-0002 IG 4: signals can be queued and the
##             source freed before the subscriber runs).
func _on_player_interacted(target: Node3D) -> void:
	# Guard 1 — null / freed-node check (ADR-0002 IG 4, mandatory first).
	if not is_instance_valid(target):
		return

	# Guard 2 — filter non-document interactables.
	# Use script-identity check via the explicit preload reference rather than
	# `is DocumentBody` to avoid global-class-registry parse-order issues
	# (level_streaming_swap_test load path triggers script-reload before the
	# class registry has scanned src/gameplay/documents/).
	if target.get_script() != _DOCUMENT_BODY_SCRIPT:
		return

	# Guard 3 — null-export guard (GDD E.15).
	if target.document == null:
		push_warning(
			"DocumentCollection: DocumentBody '%s' has a null .document export. "
			% target.name +
			"Assign a Document Resource in the inspector. Pickup skipped."
		)
		return

	var doc_id: StringName = target.document.id

	# Idempotency check (AC-DC-2.2) — duplicate pickup on already-collected id.
	# Defers queue_free so the body is cleaned up even on a re-trigger, but does
	# NOT re-emit document_collected.
	if _collected.has(doc_id):
		target.queue_free.call_deferred()
		return

	# Happy path — append, emit, defer free (GDD §C.6).
	_collected.append(doc_id)
	Events.document_collected.emit(doc_id)
	target.queue_free.call_deferred()


# ---------------------------------------------------------------------------
# Save/restore contract — capture(), restore(), spawn-gate (DC-004)
# ADR-0003 IG 3 + CR-6 duplicate discipline + GDD §H.4–§H.5
# ---------------------------------------------------------------------------

## Returns a snapshot of collected document IDs for save assembly by MLS.
## Called by MLS during SaveGame assembly.
## Aliasing break: _collected.duplicate() ensures returned state's Array
## is independent of DC's live _collected (CR-6 + ADR-0003 IG 3).
## StringName is value-typed so shallow Array.duplicate() is sufficient
## at this nesting depth.
##
## Returns: DocumentCollectionState with a defensive copy of _collected.
func capture() -> DocumentCollectionState:
	var state := DocumentCollectionState.new()
	state.collected = _collected.duplicate()
	return state


## Called by MLS during MLS's LS step-9 callback BEFORE section_entered emits.
## Applies state and immediately runs spawn-gate so collected bodies never appear.
## CR-5 revision 2026-04-27: DC does NOT register its own LSS callback;
## MLS orchestrates this within MLS's LS callback.
## Aliasing break: state.collected.duplicate() ensures _collected is independent
## of caller-supplied state (CR-6 + ADR-0003 IG 3).
## _open_document_id is NOT auto-restored (AC-DC-5.4 — Document Overlay UI manages this).
##
## Parameters:
##   state — DocumentCollectionState from the loaded SaveGame, or null to clear
##           all collected ids (null-guard per GDD §C.6 AC-3).
func restore(state: DocumentCollectionState) -> void:
	if state == null:
		_collected = []
	else:
		_collected = state.collected.duplicate()
	_gate_collected_bodies_in_section()


## Iterates section_documents group; synchronously frees previously-collected bodies.
## SYNCHRONOUS queue_free() (NOT call_deferred) — runs before section visible
## to player, so immediate removal is correct (CR-3(i)).
## Contrast with pickup handler (DC-003) which uses call_deferred to align with
## Jolt's deferred-body removal queue — the spawn-gate runs before section_entered.
##
## Null-guard on body.document is applied BEFORE reading body.document.id
## (GDD E.15). Stale ids in _collected that match no body are benign (AC-DC-4.2).
func _gate_collected_bodies_in_section() -> void:
	for body in get_tree().get_nodes_in_group(SECTION_DOCUMENTS_GROUP):
		# Script-identity check (see _on_player_interacted comment for rationale).
		if body.get_script() != _DOCUMENT_BODY_SCRIPT:
			continue
		if body.document == null:
			push_warning(
				"DocumentCollection: DocumentBody at %s has null document export."
				% body.get_path()
			)
			continue
		if _collected.has(body.document.id):
			body.queue_free()


# ---------------------------------------------------------------------------
# VS API scaffolding — Document lifecycle stubs (CR-11 / CR-12)
# ---------------------------------------------------------------------------

## Opens the document with the given id.
##
## VS STUB — Full implementation ships with Document Overlay UI epic.
## Emits Events.document_opened(id) so the signal contract is testable
## independently of the UI (AC-DC-6.1 through AC-DC-6.4 per design-review
## qa-lead Finding 6).
##
## Parameters:
##   id — the document id to open (must be non-empty; caller's responsibility).
##
## Returns: true if document opened successfully (always true in stub; full guard
## for collection validity + single-open invariant lands with Document Overlay UI).
func open_document(id: StringName) -> bool:
	_open_document_id = id
	Events.document_opened.emit(id)
	return true


## Closes the currently open document.
##
## VS STUB — Full implementation ships with Document Overlay UI epic.
## Emits Events.document_closed(_open_document_id) and clears the
## tracking variable. Returns false when no document is open.
##
## Returns: false if no document was open (CR-12 invariant guard stub);
## true if a document was closed and the signal was emitted.
func close_document() -> bool:
	if _open_document_id == &"":
		return false
	var closed_id: StringName = _open_document_id
	_open_document_id = &""
	Events.document_closed.emit(closed_id)
	return true
