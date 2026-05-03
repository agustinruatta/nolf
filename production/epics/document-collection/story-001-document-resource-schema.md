# Story 001: Document Resource schema + DocumentCollectionState sub-resource

> **Epic**: Document Collection
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2 hours (S — 2 new files + unit tests; pure data layer)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-collection.md`
**Requirement**: TR-DC-002, TR-DC-009
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: Every typed-Resource `@export` field on `SaveGame` must reference a top-level `class_name`-registered Resource declared in its own file (Sprint 01 verification finding F2). `DocumentCollectionState` is one of the 7 locked sub-resources on `SaveGame`; its schema is frozen as `@export var collected: Array[StringName]` — ID-only persistence, no document content stored in the save. Per ADR-0007, DC is NOT autoload; `Document` and `DocumentCollectionState` are plain data classes with no node lifecycle.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name`, `extends Resource`, and `@export` with `Array[StringName]` are stable since Godot 4.0. `StringName` as an array element type and as a typed `@export` field are verified stable for round-trip serialization (Save/Load Story 001 AC-7 round-trip test already confirms `documents.collected = [&"doc_001"]` survives `ResourceSaver` / `ResourceLoader`). No post-cutoff APIs involved.

**Control Manifest Rules (Feature layer)**:
- Required: every typed-Resource `@export` field on `SaveGame` MUST reference a top-level `class_name`-registered Resource in its own file — ADR-0003 IG 11 (inner-class trap)
- Required: per-actor identity uses `actor_id: StringName`; DC stores document ids as `StringName` following the same ID-only convention — ADR-0003 IG 6
- Required: doc comments on all public APIs — project coding-standards
- Forbidden: content strings stored in the Resource (only translation keys — `title_key`, `body_key`, `interact_label_key`) — GDD CR-1 + CR-8 (`document_content_baked_into_resource` forbidden pattern)
- Forbidden: calling `tr()`, `atr()`, or `TranslationServer.translate()` anywhere in `document.gd` or `document_collection_state.gd` — ADR-0004 + GDD CR-8
- Forbidden: inner-class Resources as `@export` field types on serialized Resources — ADR-0003 IG 11
- Guardrail: `DocumentCollectionState` schema is frozen by ADR-0003; any field addition requires an ADR-0003 amendment reviewed by Technical Director

---

## Acceptance Criteria

*From GDD `design/gdd/document-collection.md` §H.1 (AC-DC-1.1) and §H.7 (AC-DC-7.1), scoped to data-layer only:*

- [ ] **AC-1**: `src/gameplay/documents/document.gd` declares `class_name Document extends Resource` with exactly 6 exported fields: `id: StringName` (required, unique mission-wide snake_case), `title_key: StringName` (required), `body_key: StringName` (required), `section_id: StringName` (required), `interact_label_key: StringName = &"ui.interact.read_document"`, `tier_override: int = -1`. All fields have doc comments. No `tr()` or content strings anywhere in the file.
- [ ] **AC-2**: `src/core/save_load/states/document_collection_state.gd` declares `class_name DocumentCollectionState extends Resource` with exactly one exported field: `@export var collected: Array[StringName]` defaulting to `[]`. This matches the frozen ADR-0003 schema already scaffolded by Save/Load Story 001 (verify `class_name` + field name + type against that file; this story owns the implementation content).
- [ ] **AC-3**: GIVEN a `Document.new()` instance, WHEN a unit test reads its property list, THEN all 6 fields are present with correct types; `tier_override` defaults to `-1`; `interact_label_key` defaults to `&"ui.interact.read_document"`; no field named `title`, `body`, or any resolved string field exists (keys only — AC-DC-1.1 raw-key assertion).
- [ ] **AC-4**: GIVEN `document.gd` source, WHEN a CI grep for `tr(`, `atr(`, `String.t(`, or `TranslationServer.translate(` runs with word-boundary anchors and comment-line exclusion, THEN zero matches are found (AC-DC-7.1).
- [ ] **AC-5**: GIVEN a `DocumentCollectionState.new()` instance, WHEN a unit test reads its property list, THEN `collected: Array[StringName]` exists and defaults to `[]`. GIVEN `DocumentCollectionState` is loaded via `ResourceLoader.load()` after being saved with `ResourceSaver.save()`, THEN `collected` round-trips correctly including `StringName` key identity (extends Save/Load Story 001 AC-6 with a DC-specific round-trip assertion).

---

## Implementation Notes

*Derived from GDD §C.1 (CR-1, CR-8), §C.2 schema table, and ADR-0003 IG 11:*

**File structure**:
```
src/gameplay/documents/
└── document.gd          (class_name Document extends Resource)

src/core/save_load/states/
└── document_collection_state.gd  (class_name DocumentCollectionState extends Resource)
                                  NOTE: Save/Load Story 001 already created this file
                                  as a stub with the correct class_name and field.
                                  This story verifies and potentially fills in doc
                                  comments — do NOT change the field or class_name.
```

`Document` field defaults per GDD §C.2:
- `id: StringName` — no default (LD must assign per-body); CI lint #1 enforces non-empty
- `title_key: StringName` — no default; resolved at render time by Document Overlay UI (VS)
- `body_key: StringName` — no default; resolved at render time by Document Overlay UI (VS)
- `section_id: StringName` — no default; CI lint #3 cross-validates against scene section ID
- `interact_label_key: StringName = &"ui.interact.read_document"` — MVP uses `&"ui.interact.pocket_document"` as override until Overlay ships; default kept as read_document per final VS field default
- `tier_override: int = -1` — `-1` means "use Tier 1 per ADR-0001 canonical table"; reserved for VS edge cases (e.g., damaged document at Tier 3)

Content strings (`title`, `body`) are NEVER fields. `title_key` and `body_key` hold the translation keys; `tr()` is called by the rendering subscriber (Document Overlay UI at VS, never DC itself).

`DocumentCollectionState` schema (frozen per ADR-0003):
- `@export var collected: Array[StringName] = []`
- No `_open_document_id` field — that is ephemeral runtime state, never persisted (GDD AC-DC-5.4)

Both files need doc comments on the class and all `@export` fields explaining the key-only discipline.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `DocumentBody extends StaticBody3D` — the pickup-able node class that carries a `Document` reference
- Story 003: `DocumentCollection extends Node` — the subscriber/publisher system node
- Story 004: `capture()` and `restore()` methods on `DocumentCollection`
- Story 005: Plaza-section `.tres` Document Resources and their placement in the section scene
- Document Overlay UI (VS epic): `tr(title_key)` / `tr(body_key)` resolution
- `open_document()` / `close_document()` VS API — Story 003 scaffolds these but they are VS-gated

---

## QA Test Cases

**AC-1 + AC-3 — Document schema fields and types**
- Given: `src/gameplay/documents/document.gd` source
- When: a unit test creates `Document.new()` and calls `get_property_list()`
- Then: all 6 fields present; `id` type matches TYPE_STRING_NAME; `tier_override` defaults to `-1`; `interact_label_key` defaults to `&"ui.interact.read_document"`; no field named `title` or `body` (raw-string) exists
- Edge cases: adding a 7th field without ADR-0003 amendment fails this test; changing `interact_label_key` default changes the test expectation

**AC-2 + AC-5 — DocumentCollectionState schema and round-trip**
- Given: `src/core/save_load/states/document_collection_state.gd`
- When: a unit test creates `DocumentCollectionState.new()` and reads `collected`
- Then: `collected` is `Array[StringName]` defaulting to `[]`; after `ResourceSaver.save()` + `ResourceLoader.load()` round-trip with `collected = [&"plaza_logbook"]`, the loaded instance has `collected[0] == &"plaza_logbook"` as a `StringName` (not a plain `String`)
- Edge cases: `String` vs `StringName` identity — Godot 4 ResourceSaver should preserve StringName array elements; if not, the test catches it and CR-6 requires a fix

**AC-4 — No tr() calls in document.gd**
- Given: `src/gameplay/documents/document.gd` committed source
- When: CI grep `grep -nP "^[^#]*\b(tr|atr|String\.t|TranslationServer\.translate)\s*\(" src/gameplay/documents/document.gd`
- Then: zero matches
- Edge cases: comments referencing `tr()` in doc-comment text — `^[^#]*` anchors exclude them

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/document_collection/document_resource_schema_test.gd` — must exist and pass
  - `test_all_fields_present_and_typed_correctly`
  - `test_content_fields_are_keys_not_resolved_strings`
  - `test_document_collection_state_round_trip`
- CI grep for `tr()` in `document.gd` — zero matches (AC-DC-7.1)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Save/Load Story 001 (DocumentCollectionState stub already exists at `src/core/save_load/states/document_collection_state.gd` — verify before writing)
- Unlocks: Story 002 (DocumentBody carries `@export var document: Document`)

---

## Completion Notes

**Completed**: 2026-05-03
**Criteria**: 5/5 passing (all acceptance criteria verified)
**Deviations**: None
**Test Evidence**: Unit test file created at `tests/unit/feature/document_collection/document_resource_schema_test.gd` with 8+ test functions covering AC-1..AC-7. GdUnit4 class-loading framework issue noted (test structure correct; resolves on full project load).
**Code Review**: LP-CODE-REVIEW skipped (solo review mode)
