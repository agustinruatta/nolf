# Story 005: Plaza tutorial document set — placement, locale keys, end-to-end integration

> **Epic**: Document Collection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 hours (M-L — 3 .tres resources + section scene authoring + round-trip integration test + CI lint smoke check)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-collection.md`
**Requirement**: TR-DC-010 (partial — 3 Plaza documents from 21-doc roster), TR-DC-011 (partial — Plaza off-path ratio and placement rules from full-roster rules)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus), ADR-0003 (Save Format Contract), ADR-0004 (UI Framework), ADR-0006 (Collision Layer Contract), ADR-0007 (Autoload Registry)
**ADR Decision Summary (ADR-0004)**: All visible doc strings flow through `tr("doc.[id].title")` / `tr("doc.[id].body")` at render time — content is NEVER baked into Document Resources, only translation keys are. DC stores keys; subscribers call `tr()`. The MVP interact-label uses `&"ui.interact.pocket_document"` (fallback until Document Overlay UI ships) and `&"ui.interact.read_document"` (default field value — Localization Scaffold must register both keys per §F.5 coord item #3).

**ADR Decision Summary (ADR-0003)**: The round-trip integration test (`place → collect → save → reload → verify collected`) demonstrates the `DocumentCollectionState` sub-resource persists correctly. `ResourceSaver.FLAG_COMPRESS` is used; `ResourceLoader.load()` returns a typed `SaveGame`; `collected.has(doc_id)` must return `true` after reload.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ResourceSaver.save()` + `ResourceLoader.load()` round-trip for `SaveGame` with a populated `DocumentCollectionState.collected` array is verified by Save/Load Story 001 AC-7. No novel post-cutoff APIs. The Plaza section scene authoring and `.tres` resource creation are standard Godot 4.x workflows. Localization CSV is managed by the Localization Scaffold system; this story only adds keys — it does not modify the Scaffold code.

**Control Manifest Rules (Feature layer)**:
- Required: all visible document strings via `tr("doc.[id].title")` / `tr("doc.[id].body")` — translation keys, never literal content — ADR-0004
- Required: `DocumentBody` instances in the section MUST be instantiated from `res://src/gameplay/documents/document_body.tscn` template (not hand-authored) — GDD §C.5.8 / AC-DC-1.5 CI lint #10
- Required: all `DocumentBody` nodes in group `&"section_documents"` — GDD §C.3
- Required: `Section/Systems/DocumentCollection` node present when `section_documents` group is non-empty — GDD §E.17 / AC-DC-1.3 CI lint #7
- Forbidden: `document_content_baked_into_resource` — content strings as field values on `Document.tres` resources; only keys allowed — GDD CR-1 / CR-8
- Forbidden: document id containing non-snake_case characters — GDD CR-1 id convention
- Guardrail: body collision center Y must be in `[0.4, 1.5] m` — GDD §C.5.4 / AC-DC-1.2 CI lint #6 build failure

---

## Acceptance Criteria

*From GDD §H.12 (AC-DC-12.1 / AC-DC-12.2), §H.1 (AC-DC-1.2 / AC-DC-1.3 lint smoke), §H.5 (AC-DC-5.3 save-during-reach), §H.11 (AC-DC-11.2 section-transition edge case):*

- [ ] **AC-1 (3 Document resources exist with correct keys — AC-DC-1.1 extended to Plaza set)**: Three `Document.tres` resources exist:
  - `res://assets/data/documents/plaza_security_logbook_001.tres` — `id = &"plaza_security_logbook_001"`, `section_id = &"plaza"`, `interact_label_key = &"ui.interact.pocket_document"` (MVP fallback), `title_key = &"doc.plaza_security_logbook_001.title"`, `body_key = &"doc.plaza_security_logbook_001.body"`, `tier_override = -1`. No literal content in any field.
  - `res://assets/data/documents/plaza_tourist_register_001.tres` — analogous fields with id `&"plaza_tourist_register_001"`.
  - `res://assets/data/documents/plaza_maintenance_clipboard_001.tres` — analogous fields with id `&"plaza_maintenance_clipboard_001"`.
- [ ] **AC-2 (Localization CSV keys registered)**: The localization CSV at `assets/localization/` contains entries for `doc.plaza_security_logbook_001.title`, `doc.plaza_tourist_register_001.title`, `doc.plaza_maintenance_clipboard_001.title`, `ui.interact.pocket_document`, and `ui.interact.read_document` in the default (English) locale. Body keys (`doc.[id].body`) are deferred to VS (Document Overlay UI is VS-scope). No key resolves to an empty string. CI locale-key completeness check for title keys passes.
- [ ] **AC-3 (Plaza section authoring)**: The Plaza section scene contains: a `DocumentCollection` node at `Section/Systems/DocumentCollection`; a `&"critical_path"` spline node; a `documents/` Node3D group (group `&"section_documents"`) with 3 `DocumentBody` instances (each instantiated from `document_body.tscn` template, assigned their respective `.tres` resource, positioned per §C.5.3 furniture taxonomy). CI lint rules AC-DC-1.2 (body-authoring lints 1–6), AC-DC-1.3 (system node + spline presence), and AC-DC-1.5 (template-instance check) all pass on the Plaza scene.
- [ ] **AC-4 (Plaza off-path placement)**: The tourist-register and maintenance-clipboard documents are positioned ≥ 10.0 m from the Plaza critical-path spline (F.2 `is_off_path = true`). The security-logbook is on-path (explicit structural anchor per §C.5.1 / §C.5.3). Bodies are separated ≥ 0.15 m from each other (lint #4) and from any PICKUP/DOOR interaction volumes per §C.5.5.
- [ ] **AC-5 (round-trip integration — GDD §Epic DoD)**: GIVEN the Plaza section loaded with DC and the 3 documents present, WHEN the player collects the security logbook body (simulated via `Events.player_interacted.emit(logbook_body)`), THEN `Events.document_collected` fires once with `&"plaza_security_logbook_001"`, the body is freed, AND `dc.capture().collected.has(&"plaza_security_logbook_001")` is `true`. WHEN the `SaveGame` is saved to `user://slot_0.res` and reloaded, THEN `loaded_save.documents.collected.has(&"plaza_security_logbook_001")` is `true`. WHEN `dc.restore(loaded_save.documents)` is called with the logbook id present, THEN no `DocumentBody` for that id appears in the section (spawn-gate ran correctly).
- [ ] **AC-6 (save-during-reach body re-spawns — AC-DC-5.3)**: GIVEN a save taken before `player_interacted` fires for the logbook body (simulated by calling `capture()` before emitting `player_interacted`), WHEN the captured state is restored via `dc.restore()`, THEN the logbook body is NOT freed by the spawn-gate (id absent from `_collected`) and the player must re-collect it.
- [ ] **AC-7 (snap-clear pickup, no UI counter — AC-DC-12.1 smoke check basis)**: GIVEN the Plaza section in a built project, WHEN a QA smoke check confirms the security-logbook body disappears snap-clear on the same frame as `document_collected` emission (no tween, no animation), AND no UI counter element increments, AND no achievement popup fires, THEN the smoke check passes.

---

## Implementation Notes

*Derived from GDD §C.5.3 (Plaza MVP tutorial set), §C.5.6 (lint rules), §C.5.7 (furniture-surface taxonomy), §C.5.8 (template usage), ADR-0004 (tr() discipline), and §Epic Definition of Done:*

**Document Resource paths**: Assets data files live under `assets/data/documents/`. Naming matches `id` field:
```
assets/data/documents/
├── plaza_security_logbook_001.tres
├── plaza_tourist_register_001.tres
└── plaza_maintenance_clipboard_001.tres
```

**Document id convention** (GDD CR-1): `&"[section]_[furniture_surface_short]_[zero_padded_index]"` — e.g., `&"plaza_security_logbook_001"`. Snake_case, globally unique, matches the `.tres` filename without extension.

**Localization keys** (GDD CR-8, ADR-0004):
- Title keys follow pattern `doc.[id].title` — e.g., `doc.plaza_security_logbook_001.title`
- Body keys follow pattern `doc.[id].body` — deferred to VS; CSV entry may be a placeholder at MVP
- Interact-label keys: `ui.interact.pocket_document` (MVP fallback) and `ui.interact.read_document` (VS default) must be registered per §F.5 coord item #3 (Localization Scaffold amendment)

**Plaza section scene authoring** (GDD §C.5.3 + §C.5.7 furniture taxonomy):
- Security logbook: placed at `&"plaza_security_post"` surface (fold-out checkpoint table, height ~0.75 m on-path) — this is the tutorial on-path anchor
- Tourist register: placed at `&"plaza_tourist_register_desk"` surface (recessed counter, height ~1.05 m, 12–15 m lateral detour from path)
- Maintenance clipboard: placed at `&"plaza_maintenance_alcove_crate"` surface (wood crate behind parked van, height ~0.85 m, ≥ 10 m off-path)

Each `DocumentBody` instance must be added to the `&"section_documents"` group in the scene (group assignment confirmed in template per Story 002 AC-3, but LD must verify in the instanced scene's scene-tree).

**Round-trip integration test**: This test exercises the full Epic DoD loop:
1. Load Plaza section scene into a test tree
2. Verify 3 bodies present in `&"section_documents"` group
3. Emit `Events.player_interacted(logbook_body)` — verify signal + body freed
4. Call `dc.capture()` — verify `collected.has(id)`
5. `ResourceSaver.save(save_game, "user://test_dc_round_trip.res")`
6. `ResourceLoader.load("user://test_dc_round_trip.res") as SaveGame`
7. Assert `loaded.documents.collected.has(&"plaza_security_logbook_001")`
8. Call `dc.restore(loaded.documents)` on a fresh DC instance in a fresh section
9. Assert logbook body absent in `section_documents` group (spawn-gate ran)
10. Cleanup: delete `user://test_dc_round_trip.res` in test teardown

---

## Out of Scope

*Handled by other epics or future stories — do not implement here:*

- Full 21-document roster across all 5 sections (21 documents total: Plaza 3, Lower 4, Restaurant 6, Upper 5, Bomb 3) — deferred to VS scope; this story delivers only the 3 Plaza documents required for MVP validation
- Pickup-toast handoff to HUD State Signaling #19 — VS epic, not started
- Full-screen reading modal via Document Overlay UI #20 — VS epic, not started; `interact_label_key = &"ui.interact.pocket_document"` MVP fallback is the correct value until VS ships
- `document_opened` / `close_document()` VS API activation in a real UI — VS scope; Story 003 scaffolds the methods but no caller exists at MVP
- CI lint rules AC-DC-1.4 (cross-constraint invariants) and AC-DC-1.5 (template-instance check) — Tools-Programmer CI ticket (§F.5 coord item #4); this story confirms the Plaza scene passes those lints, but does not implement the lints themselves
- Section-validation CI lint implementation — Tools-Programmer ticket; this story authors content that must pass those lints when they ship
- Writer Brief (`design/narrative/document-writer-brief.md`) final content — Narrative Director + Writer deliverable; this story uses placeholder key values in the Localization CSV that will be filled at VS content authoring time

---

## QA Test Cases

**AC-1 — Three Document.tres files with correct keys and no content**
- Given: the three `.tres` files loaded via `ResourceLoader.load()`
- When: a unit test reads all fields on each `Document` instance
- Then: `id` is non-empty snake_case; `section_id == &"plaza"`; `interact_label_key == &"ui.interact.pocket_document"`; `title_key` matches `doc.[id].title` pattern; no field contains a resolved string (no content baked in — check that neither `title_key` nor `body_key` resolves to a human-readable sentence)
- Edge cases: title_key value containing a space (invalid key format) → CI locale-key check catches; id containing uppercase → GDD CR-1 violation

**AC-2 — Localization CSV has required keys**
- Given: the default-locale CSV in `assets/localization/`
- When: grep for `doc.plaza_security_logbook_001.title`, `doc.plaza_tourist_register_001.title`, `doc.plaza_maintenance_clipboard_001.title`, `ui.interact.pocket_document`, `ui.interact.read_document`
- Then: all 5 keys present; no key resolves to empty string
- Edge cases: key exists but maps to empty value → CI locale-key completeness check fires

**AC-3 — Plaza scene lint compliance**
- Given: the Plaza section scene
- When: CI section-validation lints run (AC-DC-1.2 + AC-DC-1.3 + AC-DC-1.5)
- Then: lint #1 (non-null document export) passes; lint #3 (section_id matches) passes; lint #5 (LAYER_INTERACTABLES only) passes; lint #6 (body Y in [0.4, 1.5] m) passes; lint #7 (DocumentCollection node present) passes; lint #10 (template-instance only) passes
- Edge cases: a body hand-authored outside the template → lint #10 fires

**AC-4 — Off-path placement verified**
- Given: Plaza section scene with `&"critical_path"` spline present (lint #8 prerequisite)
- When: F.2 off-path CI lint runs (requires path-distance computation against the spline)
- Then: tourist-register body distance >= 10.0 m from path; maintenance-clipboard body distance >= 10.0 m from path; security-logbook body distance < 10.0 m (correctly on-path)
- Edge cases: bodies exactly at 10.0 m → qualifies as off-path (`>=` not `>`)

**AC-5 — Round-trip integration (GDD Epic DoD)**
- Given: Plaza section loaded in a test tree with DC, 3 DocumentBody nodes in `section_documents` group
- When: `Events.player_interacted.emit(logbook_body)` fires; `dc.capture()` called; save/load round-trip; `dc.restore(loaded.documents)` on fresh DC
- Then: (a) `document_collected` fired once with `&"plaza_security_logbook_001"`; (b) `dc.capture().collected.has(&"plaza_security_logbook_001")` true; (c) `loaded_save.documents.collected.has(&"plaza_security_logbook_001")` true; (d) logbook body absent after spawn-gate; (e) tourist and clipboard bodies still present
- Edge cases: `ResourceSaver.save()` fails → test must assert `OK` return before asserting load; `StringName` key identity after load (must be StringName, not String)

**AC-6 — Save-during-reach body re-spawns (AC-DC-5.3)**
- Given: Plaza section with logbook body; `_collected` empty (no prior pickup)
- When: `capture()` called (before any `player_interacted` for logbook); state saved; `dc.restore(loaded_state)` called
- Then: logbook body still present in `section_documents` group (spawn-gate found no match — id not in `_collected`); player must re-collect

**AC-7 — Smoke check pass (manual — AC-DC-12.1)**
- Setup: Boot MVP build; load Plaza section; walk to security-logbook body
- Verify: Tier 1 Ink Black (4 px) outline visible on body; HUD prompt shows `tr("ui.interact.pocket_document")` text; pressing E causes body to disappear snap-clear (same frame); no UI counter appears; no achievement popup fires; paper-slide SFX audible within 100 ms
- Pass condition: all of the above confirmed by QA observer; no tween/animation exit; no stencil outline remains after pickup
- Evidence path: `production/qa/smoke-[date].md`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/feature/document_collection/pickup_lifecycle_test.gd` — must exist and pass
  - `test_pickup_appends_id_emits_signal_and_defers_free` (AC-DC-2.1 from Story 003 — extended here with real .tres resources)
  - `test_fr_cancel_leaves_body_uncollected` (AC-DC-2.3)
- `tests/integration/feature/document_collection/save_contract_test.gd` — must exist and pass
  - `test_save_during_reach_restores_body_as_uncollected` (AC-DC-5.3)
- `tests/integration/feature/document_collection/signal_one_shot_test.gd` — must exist and pass
  - `test_document_collected_fires_once_per_id_per_session` (AC-DC-3.1)
- `tests/integration/feature/document_collection/edge_cases_test.gd` — must exist and pass
  - `test_pickup_plus_section_transition_same_frame` (AC-DC-11.2)
  - `test_rapid_sequential_pickups_emit_twice_with_distinct_ids` (AC-DC-6.6)
- Plaza round-trip test (new): `tests/integration/feature/document_collection/plaza_round_trip_test.gd`
  - `test_plaza_three_documents_full_round_trip`
- Smoke check pass log: `production/qa/smoke-[date].md` (manual — AC-DC-12.1)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Document schema), Story 002 (DocumentBody template), Story 003 (DocumentCollection node with pickup handler), Story 004 (capture/restore + spawn-gate)
- Depends on (coordination): §F.5 coord item #3 (Localization Scaffold must register `ui.interact.pocket_document` and `ui.interact.read_document` keys before this story's AC-2 can pass)
- Depends on (coordination): §F.5 coord item #1 partial (Plaza section scene must have the `&"critical_path"` spline and `Section/Systems/DocumentCollection` node path — MLS GDD §C.5 amendment)
- Unlocks: Full DC epic Definition of Done (all story-Done criteria met = epic DoD met); Document Overlay UI epic (VS) can begin once DC data layer is stable
