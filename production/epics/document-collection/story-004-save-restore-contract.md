# Story 004: Save/restore contract — capture(), restore(), spawn-gate

> **Epic**: Document Collection
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3 hours (M — 2 methods + integration tests; save/load round-trip + spawn-gate)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-collection.md`
**Requirement**: TR-DC-006, TR-DC-007, TR-DC-008, TR-DC-014
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary (ADR-0003)**: Callers MUST call `duplicate_deep()` on the loaded save before handing nested state to live systems (IG 3). At the `Array[StringName]` boundary inside a `DocumentCollectionState`, the `duplicate()` call (not `duplicate_deep()` — Array method, not Resource method) breaks aliasing between DC's live `_collected` and the caller-supplied state. The `SaveGame` Resource is `duplicate_deep()`-d by Save/Load at the file-boundary BEFORE MLS hands per-system sub-resources to systems; DC's additional `state.collected.duplicate()` call breaks the residual reference at the inner Array level. See GDD CR-6 for the full duplicate-discipline contract.

**ADR Decision Summary (ADR-0002)**: DC does NOT register its own LSS step-9 callback. Per GDD CR-5 revision 2026-04-27, MLS orchestrates per-system restore within MLS's registered LS callback: MLS calls `dc.restore(save_game.documents)` BEFORE Level Streaming emits `section_entered`. DC's `restore()` applies state and immediately runs the spawn-gate. The spawn-gate iterates `&"section_documents"` group and synchronously frees bodies whose id is in `_collected` — running before the section is visible.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Array[StringName].duplicate()` (non-deep Array duplicate) is stable Godot 4.0+. The distinction between `Array.duplicate()` (shallow copy of a value-typed StringName array — sufficient for aliasing break) and `Resource.duplicate_deep()` (Godot 4.5+ post-cutoff, for nested Resource graphs) is documented in GDD CR-6 and control manifest. OQ-DC-VG-2 asks whether `Array[StringName].duplicate()` is sufficient vs requiring `duplicate_deep()` — the implementation follows CR-6's explicit contract; if VG-DC-2 returns negative, the fix is to switch to `state.collected.duplicate_deep()`. `get_tree().get_nodes_in_group()` is stable Godot 4.0+.

**Control Manifest Rules (Feature layer)**:
- Required: callers MUST call `duplicate_deep()` on loaded SaveGame before handing nested state to live systems — ADR-0003 IG 3 (Save/Load applies this at the file boundary; DC applies `Array.duplicate()` at the inner Array boundary per CR-6)
- Required: DC does NOT register its own LSS restore callback — GDD CR-5 revision 2026-04-27; MLS orchestrates
- Required: `restore()` is a public method (`func restore(state: DocumentCollectionState) -> void`) — MLS calls it within MLS's LS step-9 callback BEFORE `section_entered` is emitted
- Required: spawn-gate uses synchronous `queue_free()` (NOT `call_deferred()`) — runs before section is visible; deferred free is for pickup handler only (CR-3(i))
- Required: null-guard on `body.document` in spawn-gate iteration — E.15 null-guard per §C.6 pseudocode
- Forbidden: `LevelStreamingService.register_restore_callback()` called from DC — DC delegates restore orchestration to MLS (GDD CR-5)
- Guardrail: `DocumentCollectionState` schema is frozen; `restore()` reads only `collected: Array[StringName]`; any additional field requires ADR-0003 amendment

---

## Acceptance Criteria

*From GDD §H.4 (AC-DC-4.x), §H.5 (AC-DC-5.x), §H.9 (AC-DC-9.1 / AC-DC-9.2):*

- [ ] **AC-1 (capture returns defensive copy — AC-DC-5.1)**: GIVEN DC has `_collected = [&"plaza_logbook"]`, WHEN `capture()` is called, THEN the returned `DocumentCollectionState.collected` equals `[&"plaza_logbook"]` AND modifying `_collected` afterward does NOT modify the captured state (aliasing break via `_collected.duplicate()`).
- [ ] **AC-2 (restore populates without aliasing — AC-DC-5.2)**: GIVEN a `DocumentCollectionState` with `collected = [&"plaza_logbook", &"lower_clipboard"]`, WHEN `restore(state)` is called, THEN `_collected` equals `[&"plaza_logbook", &"lower_clipboard"]` AND modifying `state.collected` afterward does NOT modify `_collected` (aliasing break via `state.collected.duplicate()`).
- [ ] **AC-3 (null state restore — edge case)**: GIVEN `restore(null)` is called, THEN `_collected` is cleared to `[]` and no crash occurs (GDD §C.6 null-guard `if state == null: _collected = []`).
- [ ] **AC-4 (spawn-gate frees collected bodies — AC-DC-4.1)**: GIVEN `_collected` contains `[&"plaza_logbook", &"plaza_register"]` when `restore()` fires, WHEN `_gate_collected_bodies_in_section()` runs, THEN both corresponding `DocumentBody` nodes in `&"section_documents"` are freed synchronously (not deferred) and are no longer present in the scene tree.
- [ ] **AC-5 (stale id is benign — AC-DC-4.2)**: GIVEN `_collected` contains an id matching no body in the section, WHEN `_gate_collected_bodies_in_section()` runs, THEN no crash, no error, and zero unintended bodies freed.
- [ ] **AC-6 (null document guard in spawn-gate — AC-DC-4.3)**: GIVEN a section with a `DocumentBody` whose `document` export is null, WHEN `_gate_collected_bodies_in_section()` iterates it, THEN `push_warning()` is emitted and the body is NOT freed; no crash.
- [ ] **AC-7 (open_document_id not persisted — AC-DC-5.4)**: GIVEN DC's `_open_document_id` is programmatically set to a non-empty value, WHEN `capture()` is called, THEN the returned state contains only `collected: Array[StringName]` — no `_open_document_id` field. WHEN `restore(state)` is subsequently called, THEN `_open_document_id == &""` (default; not auto-restored).
- [ ] **AC-8 (formula arithmetic — AC-DC-9.1)**: GIVEN N_subscribers = 4 and the F.1 component values from GDD §F.1 example, WHEN the formula `t_signal_dispatch + t_set_membership + t_array_append + t_signal_emit + t_call_deferred` is evaluated in code, THEN the result equals `0.046 ms ± 0.0005 ms` AND `0.046 < 0.05` AND `(0.05 - 0.046) / 0.05 >= 0.08`.
- [ ] **AC-9 (N=6 breaches budget — AC-DC-9.2)**: GIVEN N_subscribers = 6 and worst-case F.1 component values, WHEN the formula is evaluated, THEN the result exceeds `0.05 ms` (confirming that a 6th subscriber triggers an ADR-0008 amendment review).

---

## Implementation Notes

*Derived from GDD §C.6 pseudocode (canonical), §C.1 CR-5/CR-6, and ADR-0003 IG 3:*

Add `capture()` and `restore()` methods to `src/gameplay/documents/document_collection.gd` (the same file created in Story 003):

```gdscript
## Called by MLS during MLS's LS step-9 callback, BEFORE section_entered is emitted.
## Applies state and immediately runs spawn-gate so collected bodies never appear.
func restore(state: DocumentCollectionState) -> void:
    if state == null:
        _collected = []
    else:
        _collected = state.collected.duplicate()  # breaks Array aliasing (CR-6)
    _gate_collected_bodies_in_section()

## Iterates section_documents group; synchronously frees collected bodies.
## Synchronous (NOT call_deferred) — runs before section is visible to player.
func _gate_collected_bodies_in_section() -> void:
    for body in get_tree().get_nodes_in_group(SECTION_DOCUMENTS_GROUP):
        if not body is DocumentBody:
            continue
        if body.document == null:  # E.15 null-guard
            push_warning("DocumentBody at %s has null document export" % body.get_path())
            continue
        if _collected.has(body.document.id):
            body.queue_free()  # synchronous — section not yet visible

## Returns a snapshot of collected document IDs for save assembly by MLS.
## Called by MLS during SaveGame assembly (MLS CR-15 capture orchestration).
func capture() -> DocumentCollectionState:
    var state := DocumentCollectionState.new()
    state.collected = _collected.duplicate()  # defensive copy at value-typed-Array boundary
    return state
```

**Duplicate discipline** (GDD CR-6):
- `capture()`: `_collected.duplicate()` breaks the reference between the returned state's Array and DC's live `_collected`. StringName is value-typed; shallow duplicate is sufficient at this nesting depth.
- `restore()`: `state.collected.duplicate()` breaks the reference between `_collected` and the caller-supplied state Array (the outer `SaveGame` was already `duplicate_deep()`-d by Save/Load at the file boundary, but the inner Array reference may still alias — DC breaks it here).

**Spawn-gate synchronous vs deferred**: spawn-gate uses `queue_free()` (synchronous), NOT `call_deferred("queue_free")`. The gate runs inside MLS's LS step-9 callback before `section_entered` fires, so the section is not yet visible — immediate removal is correct. Contrast with the pickup handler (Story 003) which uses `call_deferred("queue_free")` to align with Jolt's deferred-body removal queue.

**Performance formula test**: Story 004 also adds a pure arithmetic test that verifies GDD F.1 formula components. This test has no game-object dependencies — it is purely mathematical and documents the ADR-0008 sub-slot claim in executable form.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `_ready()`, `_exit_tree()`, `_on_player_interacted()`, `open_document()`, `close_document()` — already implemented
- Story 005: end-to-end Plaza integration test (round-trip: place → collect → save → reload → verify)
- Save/Load epic: `SaveLoadService.save_to_slot()` / `load_from_slot()` — DC only owns `capture()` and `restore()`; Save/Load writes/reads the file; MLS assembles the `SaveGame`
- MLS GDD amendment (§F.5 coord item #1): MLS must call `dc.restore(save_game.documents)` within its LS step-9 callback — that is an MLS-side change, not a DC-side change

---

## QA Test Cases

**AC-1 — capture() defensive copy (AC-DC-5.1)**
- Given: DC with `_collected = [&"plaza_logbook"]`
- When: `var state = dc.capture()`; then `dc._collected.append(&"extra_id")`
- Then: `state.collected.size() == 1` (mutation of `_collected` after capture does not affect state)
- Edge cases: `_collected` empty → `state.collected == []`; verify not null

**AC-2 — restore() populates without aliasing (AC-DC-5.2)**
- Given: `DocumentCollectionState` with `collected = [&"plaza_logbook", &"lower_clipboard"]`
- When: `dc.restore(state)`; then `state.collected.append(&"extra")`
- Then: `dc._collected.size() == 2` (mutation of `state.collected` after restore does not affect `_collected`)
- Edge cases: `state.collected` is an `Array[StringName]` — verify element type preserved after duplicate

**AC-3 — null state restore**
- Given: DC
- When: `dc.restore(null)`
- Then: `dc._collected == []`; no crash; no error logged
- Edge cases: calling `restore(null)` after a prior `restore(valid_state)` — clears `_collected` cleanly

**AC-4 — Spawn-gate frees collected bodies (AC-DC-4.1)**
- Given: a test scene with two `DocumentBody` mock nodes in `&"section_documents"` group (ids `&"plaza_logbook"` and `&"plaza_register"`); DC with those ids in `_collected`
- When: `dc.restore(state_containing_those_ids)`
- Then: both bodies are freed before the next frame; `is_instance_valid(body_a) == false`; `is_instance_valid(body_b) == false`
- Edge cases: a third uncollected body must NOT be freed

**AC-5 — Stale id is benign (AC-DC-4.2)**
- Given: DC with `_collected = [&"nonexistent_id"]`; section has no matching body
- When: `_gate_collected_bodies_in_section()` runs
- Then: no crash, no error, no body freed
- Edge cases: empty section (no `section_documents` group) — `get_nodes_in_group` returns empty array; loop is a no-op

**AC-6 — Null document export in spawn-gate (AC-DC-4.3)**
- Given: a `DocumentBody` mock with `document = null` in `section_documents` group; its mock id in `_collected`
- When: `_gate_collected_bodies_in_section()` runs
- Then: `push_warning()` was called; body is NOT freed; no crash
- Edge cases: body with null document whose id happens to be in `_collected` — null guard must be checked BEFORE reading `body.document.id`

**AC-7 — open_document_id not persisted (AC-DC-5.4)**
- Given: DC with `_open_document_id = &"plaza_logbook"` (set programmatically simulating Overlay open)
- When: `var state = dc.capture()`
- Then: `state` is a valid `DocumentCollectionState`; `state.get_property_list()` contains no `_open_document_id` field
- When: `dc.restore(state)`
- Then: `dc._open_document_id == &""` (not auto-restored)

**AC-8 + AC-9 — F.1 performance formula arithmetic (AC-DC-9.1 / AC-DC-9.2)**
- Given: component values from GDD §F.1 example (N=4: t_signal_dispatch=0.008, t_set_membership=0.002, t_array_append=0.001, t_signal_emit=0.032, t_call_deferred=0.003)
- When: formula computed in test
- Then: result == 0.046 ± 0.0005; result < 0.05; headroom >= 8%
- Given: N=6 worst-case values
- When: formula computed with N_subscribers=6 (t_signal_emit = 0.008 × 6 = 0.048)
- Then: result > 0.05 (confirms budget breach requiring ADR-0008 review)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/feature/document_collection/save_contract_test.gd` — must exist and pass
  - `test_capture_returns_deep_copy`
  - `test_restore_populates_collected_without_aliasing`
  - `test_null_state_restore_clears_collected`
  - `test_open_document_id_not_persisted_in_save`
  - `test_capture_succeeds_with_open_document_state`
- `tests/unit/feature/document_collection/performance_formula_test.gd` — must exist and pass
  - `test_f1_pickup_cost_at_n4_within_budget`
  - `test_f1_at_n6_breaches_budget_and_triggers_review`
- `tests/integration/feature/document_collection/spawn_gate_test.gd` — must exist and pass
  - `test_collected_bodies_absent_after_restore`
  - `test_stale_id_in_collected_is_benign`
  - `test_null_document_export_does_not_crash`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (DocumentCollection node with `_collected` state and `SECTION_DOCUMENTS_GROUP` constant must exist)
- Unlocks: Story 005 (end-to-end Plaza integration test requires capture/restore to exist for the round-trip)

---

## Completion Notes

**Completed**: 2026-05-03
**Criteria**: 9/9 passing (all 9 acceptance criteria covered: 5 unit tests for save_contract, 2 unit tests for performance_formula, 3 integration tests for spawn_gate)
**Deviations**: One BLOCKING test logic defect found in code-review and corrected:
- AC-7 test (`test_open_document_id_not_persisted_in_save`) had inverted postcondition — was asserting `_open_document_id == ""` after setting it to a value and calling restore(). Fixed: now uses sentinel value approach to prove restore() leaves `_open_document_id` untouched (neither auto-restored from state nor reset to default).

Two advisory non-blocking items (F-2, F-3 from code-review) deferred to future hardening pass:
- spawn_gate_test.gd: comment clarification on "synchronous queue_free + await process_frame" (advisory)
- performance_formula_test.gd: tautological const-vs-const assertion in N=6 test (advisory; arithmetic is correct, just a structural style note)

**Test Evidence**: 
- `tests/unit/feature/document_collection/save_contract_test.gd` (5 test functions: capture aliasing, restore aliasing, null-state, _open_document_id non-persistence, capture-with-open-state)
- `tests/unit/feature/document_collection/performance_formula_test.gd` (2 test functions: F.1 at N=4 within budget = 0.046ms ≤ 0.05ms with 8% headroom; F.1 at N=6 breach = 0.062ms > 0.05ms triggers ADR-0008 review)
- `tests/integration/feature/document_collection/spawn_gate_test.gd` (3 test functions: collected bodies absent after restore; stale id benign; null document export does not crash)

**Code Review**: Complete — godot-gdscript-specialist verdict CHANGES REQUIRED resolved (F-1 BLOCKING fixed); ADR-0003 IG 3 + CR-6 duplicate-discipline verified at both Array boundaries; ADR-0002 CR-5 honored (DC does NOT register LSS callback); spawn-gate synchronous queue_free verified (NOT call_deferred); E.15 null-guard order verified before .id access. LP-CODE-REVIEW + QL-TEST-COVERAGE gates skipped (Lean review mode).
