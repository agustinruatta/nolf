# res://src/gameplay/documents/document.gd
#
# Document — lore-document Resource schema per Document Collection GDD CR-1 + §C.2.
# Implements: design/gdd/document-collection.md CR-1, CR-8, §C.2
# ADR refs: ADR-0002 (signals), ADR-0003 (persistence), ADR-0004 (tr() discipline)
# Story: DC-001 (schema)
#
# KEY INVARIANTS (enforced by CI lint §C.5.6):
#   - `id` must be a non-empty StringName in snake_case and unique mission-wide.
#   - `title_key` / `body_key` / `interact_label_key` are Localization keys ONLY —
#     this Resource NEVER calls tr(); resolution is the subscriber's responsibility
#     per ADR-0004 + CR-8.
#   - Content strings are NEVER stored here; only translation keys are.
#   - `tier_override` defaults to -1 (= use ADR-0001 Tier 1; -1 means "no override").

## Document — lore-document Resource that carries the schema for one in-world
## collectable document (memo, dossier, telex, etc.) in *The Paris Affair*.
##
## This Resource is the **data contract** only. It holds no resolved content
## strings — only Localization keys. The DocumentBody scene node carries an
## `@export var document: Document` reference, which DocumentCollection reads
## at pickup time. Document Overlay UI #20 (VS) reads `title_key` + `body_key`
## and resolves them via `tr()` at render time.
##
## Field summary (per §C.2):
##   - `id`                — unique mission-wide snake_case identifier
##   - `title_key`         — localization key resolved by Overlay / HUD at render
##   - `body_key`          — localization key resolved by Overlay at render (VS)
##   - `section_id`        — owning section; CI-validated (§C.5.6 lint #3)
##   - `interact_label_key`— HUD prompt key; defaults to pocket (MVP fallback)
##   - `tier_override`     — stencil tier override; -1 = Tier 1 per ADR-0001
##
## Usage example:
##   var doc := Document.new()
##   doc.id = &"plaza_security_logbook_001"
##   doc.title_key = &"doc.plaza_security_logbook_001.title"
##   doc.body_key  = &"doc.plaza_security_logbook_001.body"
##   doc.section_id = &"plaza"
class_name Document
extends Resource

# ---------------------------------------------------------------------------
# Fields — per §C.2 schema table (all are MVP unless tagged [VS])
# ---------------------------------------------------------------------------

## Unique mission-wide document identifier (snake_case StringName).
## Saved to DocumentCollectionState.collected; must be non-empty.
## Example: &"plaza_security_logbook_001"
@export var id: StringName = &""

## Localization key for the document title.
## Convention: `doc.[id].title`
## Resolution is performed by Document Overlay UI or HUD — NEVER by this Resource.
@export var title_key: StringName = &""

## Localization key for the document body text. [VS]
## Convention: `doc.[id].body`
## Not rendered at MVP (Document Overlay UI #20 ships at VS).
@export var body_key: StringName = &""

## Owning section identifier — must match the scene's section id.
## CI lint §C.5.6 lint #3 validates this at build time.
## Example: &"plaza"
@export var section_id: StringName = &""

## HUD prompt label Localization key.
## Default: &"ui.interact.read_document" per VS field spec (AC-1).
## Level-designers may override per-document for narrative flavor.
@export var interact_label_key: StringName = &"ui.interact.read_document"

## Stencil outline tier override.
## -1 = use ADR-0001 Tier 1 (heaviest, 4 px @ 1080p) — the correct value for
## all uncollected documents. Reserved for VS edge cases (e.g., a visually
## damaged document that should read at Tier 3). Do not set non-(-1) values
## without an explicit art-director sign-off and ADR-0001 amendment.
@export var tier_override: int = -1
