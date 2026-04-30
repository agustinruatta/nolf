# Story 003: DocumentCollection node — subscribe/publish lifecycle + pickup handler

> **Epic**: Document Collection
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3 hours (M — 1 system script + 5 unit test files; signal lifecycle + 3-guard handler)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-collection.md`
**Requirement**: TR-DC-001, TR-DC-005, TR-DC-012, TR-DC-013, TR-DC-015
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary (ADR-0002)**: The signal bus (`events.gd`) carries ONLY signal declarations — no state, no methods. Subscribers connect in `_ready()` with `signal.connect(callable)` syntax and disconnect in `_exit_tree()` with `is_connected()` guards before every `disconnect()` call (IG 3, mandatory for memory-leak prevention). Every Node-typed signal payload must be checked with `is_instance_valid(node)` before dereferencing — signals can be queued and the source freed before the subscriber runs (IG 4). DC is the **sole publisher** of all 3 Document-domain signals (`document_collected(id: StringName)`, `document_opened(id: StringName)`, `document_closed(id: StringName)`); these are frozen in the ADR-0002 3-signal contract and must not be emitted from any other file.

**ADR Decision Summary (ADR-0007)**: DC is NOT autoload. `DocumentCollection extends Node` is instantiated as a child of the section scene at canonical path `Section/Systems/DocumentCollection`. Lifetime equals section lifetime; freed when Level Streaming Service unloads the section. `DocumentCollectionState` is the persistent data object on `SaveGame`; DC itself is ephemeral.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Signal.connect(callable)` / `Signal.disconnect(callable)` / `Signal.is_connected(callable)` are stable Godot 4.0+ typed-signal APIs. Typed-signal `emit()` syntax (`Events.document_collected.emit(id)`) is the project-mandated pattern. The `is DocumentBody` type-check is a standard GDScript 4.0 pattern. `call_deferred("queue_free")` on a `StaticBody3D` during a signal handler is an advisory engine-verification item (OQ-DC-VG-1 — Jolt 4.6 deferred-body-removal safety); implementation follows the GDD pseudocode in §C.6 which uses `call_deferred("queue_free")` per VG-DC-1 design intent. If VG-DC-1 returns negative during integration testing, the fix is to switch to immediate `queue_free()` with manual Jolt physics-body deferral (tracked in OQ-DC-VG-1).

**Control Manifest Rules (Feature layer)**:
- Required: subscribers connect in `_ready()` and disconnect in `_exit_tree()` with `is_connected()` guards — ADR-0002 IG 3
- Required: every Node-typed signal payload checked with `is_instance_valid(node)` before dereference — ADR-0002 IG 4
- Required: direct emit syntax `Events.<signal>.emit(args)` — no wrapper methods — ADR-0002 §Risks (forbidden pattern `event_bus_wrapper_emit`)
- Required: DC at canonical scene path `Section/Systems/DocumentCollection` — ADR-0007 (NOT autoload)
- Forbidden: adding methods, state, or query helpers to `events.gd` — `event_bus_with_methods` — ADR-0002 §Risks
- Forbidden: `document_signal_emitted_outside_dc` — any file other than `document_collection.gd` emitting `Events.document_collected`, `Events.document_opened`, or `Events.document_closed` is a sole-publisher violation (CR-7); caught by CI lint per AC-DC-3.2
- Forbidden: DC registering its own LSS step-9 callback — per GDD CR-5 revision 2026-04-27, MLS orchestrates DC.restore() within MLS's LS callback (DC does NOT use `LevelStreamingService.register_restore_callback` directly)
- Forbidden: `_process()` or `_physics_process()` overrides in `document_collection.gd` — zero steady-state per-frame cost per CR-15 / AC-DC-9.3
- Forbidden: `get_collected_count()`, `get_total_count()`, `is_complete()`, `get_completion_percent()` methods — CR-13 no-quest-counter absolute; `_collected.size()` is DC-internal only

---

## Acceptance Criteria

*From GDD §H.2 (AC-DC-2.x), §H.3 (AC-DC-3.x partial), §H.6 (AC-DC-6.5), §H.8 (AC-DC-8.1 / AC-DC-9.3):*

- [ ] **AC-1 (connect/disconnect lifecycle — AC-DC-2.4)**: GIVEN DC's `_ready()` fires, THEN `Events.player_interacted.is_connected(_on_player_interacted)` is `true`. GIVEN DC's `_exit_tree()` fires, THEN `Events.player_interacted.is_connected(_on_player_interacted)` is `false` and no error is raised.
- [ ] **AC-2 (pickup appends, emits, defers — AC-DC-2.1)**: GIVEN DC subscribed and a `DocumentBody` with id `&"plaza_logbook"` in the section, WHEN `Events.player_interacted.emit(that_body)` fires, THEN: (a) `_collected` contains `&"plaza_logbook"`; (b) `Events.document_collected` fires exactly once with that id; (c) `body.call_deferred("queue_free")` is scheduled.
- [ ] **AC-3 (idempotency net — AC-DC-2.2)**: GIVEN `&"plaza_logbook"` already in `_collected`, WHEN `Events.player_interacted.emit(same_body)` fires again, THEN `document_collected` does NOT fire a second time and `_collected.size()` is unchanged.
- [ ] **AC-4 (handler guards — AC-DC-6.5)**: GIVEN the signal fires with `target = null`, THEN handler returns immediately without error and `_collected` unchanged. GIVEN the signal fires with a valid `Node3D` that is NOT a `DocumentBody`, THEN handler returns immediately and `_collected` unchanged. GIVEN the signal fires with a `DocumentBody` whose `.document` export is null, THEN `push_warning()` is called and handler returns immediately; `_collected` unchanged.
- [ ] **AC-5 (no per-frame overrides — AC-DC-9.3)**: GIVEN `src/gameplay/documents/document_collection.gd`, WHEN CI grep `grep -nE '^func\s+_(process|physics_process)\b'` runs, THEN zero matches.
- [ ] **AC-6 (no aggregate query methods — AC-DC-8.1)**: GIVEN the full codebase, WHEN CI grep for `get_collected_count`, `get_total_count`, `is_complete`, `get_completion_percent` runs, THEN zero matches.
- [ ] **AC-7 (sole-publisher CI lint — AC-DC-3.2)**: GIVEN the full `src/` codebase, WHEN `grep -rnE "^[^#]*Events\.document_(collected|opened|closed)\.emit\(" src/` is run and the output filtered to exclude `/document_collection.gd:`, THEN zero lines remain.
- [ ] **AC-8 (not autoload — AC-DC-11.1)**: GIVEN `project.godot`, WHEN `grep "DocumentCollection" project.godot` runs, THEN zero matches in the `[autoload]` section.

---

## Implementation Notes

*Derived from GDD §C.6 pseudocode (canonical), §C.1 (CR-3, CR-7, CR-13, CR-14, CR-15, CR-16, CR-17), and ADR-0002 IG 3/4:*

Full implementation matches the §C.6 pseudocode verbatim. Key design choices:

**Signal connect/disconnect** — typed callable syntax only:
```gdscript
Events.player_interacted.connect(_on_player_interacted)
# in _exit_tree:
if Events.player_interacted.is_connected(_on_player_interacted):
    Events.player_interacted.disconnect(_on_player_interacted)
```

**Handler guard sequence (CR-17, mandatory order)**:
1. `if not is_instance_valid(target): return` — ADR-0002 IG 4 first-line guard
2. `if not target is DocumentBody: return` — filters non-document interactables
3. `if target.document == null: push_warning(...); return` — E.15 null-guard
4. Idempotency check: `if _collected.has(doc_id): target.call_deferred("queue_free"); return`
5. Happy-path: append → emit → deferred free

**`call_deferred("queue_free")` rationale**: aligns Jolt 4.6 deferred-body removal with Godot's scene-tree reaping (OQ-DC-VG-1). The deferred call ensures the body is not freed mid-signal dispatch, which is not a concern in single-threaded GDScript but is mentioned in the advisory for Jolt's internal body-removal queue.

**VS API scaffolding** (`open_document` / `close_document`): this story scaffolds the method stubs per GDD §C.1 CR-11/CR-12 to make the API available for DC-internal unit testing (AC-DC-6.1 through AC-DC-6.4 are not BLOCKED on Document Overlay UI #20 per design-review qa-lead Finding 6). Full VS activation waits for Document Overlay UI epic.

The `_collected: Array[StringName]` and `_open_document_id: StringName` state variables are DC-internal — never exposed via public getters.

**NOT implemented in this story**: `capture()`, `restore()` — those are Story 004. DC in this story has only `_ready()`, `_exit_tree()`, `_on_player_interacted()`, `open_document()`, and `close_document()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `Document` Resource schema
- Story 002: `DocumentBody` node class
- Story 004: `capture()` and `restore()` — the save/restore contract and spawn-gate logic
- Story 005: Plaza-section placement and end-to-end integration
- Document Overlay UI epic (VS): calling `open_document()` / `close_document()` from an actual UI node
- HUD State Signaling epic (VS): pickup-toast subscriber to `document_collected`

---

## QA Test Cases

**AC-1 — Connect/disconnect lifecycle (AC-DC-2.4)**
- Given: DC node added to a test scene containing `Events` autoload
- When: a test reads `Events.player_interacted.is_connected(dc._on_player_interacted)` after `_ready()`
- Then: `true`
- When: `dc._exit_tree()` is called manually (or the node is removed from tree)
- Then: `Events.player_interacted.is_connected(dc._on_player_interacted)` is `false`; no ERR output
- Edge cases: double `_exit_tree()` call — `is_connected()` guard prevents double-disconnect crash

**AC-2 — Happy-path pickup (AC-DC-2.1)**
- Given: a `DocumentCollection` node; a `DocumentBody` mock with id `&"plaza_logbook"`; a signal spy on `Events.document_collected`
- When: `Events.player_interacted.emit(body)` fires
- Then: `dc._collected.has(&"plaza_logbook")` is `true`; spy received exactly 1 call with `&"plaza_logbook"`; body's `queue_free` was deferred (verify via mock or call_deferred count)
- Edge cases: body freed before handler runs — `is_instance_valid` returns false → handler early-returns; `_collected` unchanged

**AC-3 — Idempotency net (AC-DC-2.2)**
- Given: `_collected` contains `&"plaza_logbook"`; a signal spy on `Events.document_collected`
- When: `Events.player_interacted.emit(same_body)` fires
- Then: spy received 0 new calls; `_collected.size()` unchanged
- Edge cases: body already freed (`is_instance_valid` false) → early-return before idempotency check

**AC-4 — Handler guard sequence (AC-DC-6.5)**
- Given: DC node; signal spy on `Events.document_collected`
- When: `Events.player_interacted.emit(null)` fires
- Then: no error; spy 0 calls; `_collected` empty
- When: `Events.player_interacted.emit(non_document_node)` fires (a plain Node3D)
- Then: same — filtered at `is DocumentBody` check; 0 spy calls
- When: `Events.player_interacted.emit(body_with_null_document)` fires
- Then: `push_warning` logged; 0 spy calls; `_collected` unchanged

**AC-5 — No per-frame overrides (AC-DC-9.3)**
- Given: `src/gameplay/documents/document_collection.gd`
- When: `grep -nE '^func\s+_(process|physics_process)\b' src/gameplay/documents/document_collection.gd`
- Then: zero lines
- Edge cases: accidentally overriding `_physics_process` even as a stub → grep catches it

**AC-6 — No aggregate query methods (AC-DC-8.1)**
- Given: `src/` codebase
- When: `grep -rn "get_collected_count\|get_total_count\|is_complete\|get_completion_percent" src/`
- Then: zero matches
- Edge cases: added in a comment → `^[^#]*` anchors; grep must exclude comment lines

**AC-7 — Sole-publisher lint (AC-DC-3.2)**
- Given: `src/` codebase
- When: `grep -rnE "^[^#]*Events\.document_(collected|opened|closed)\.emit\(" src/ | grep -v "/document_collection.gd:"`
- Then: zero lines
- Edge cases: signal-spy helpers in test files that call `.emit()` for testing — test files live under `tests/`, not `src/`; grep target is `src/` only

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/document_collection/subscriber_lifecycle_test.gd` — `test_connect_on_ready_disconnect_on_exit_tree`
- `tests/unit/feature/document_collection/idempotency_test.gd` — `test_duplicate_pickup_does_not_re_emit`, `test_duplicate_id_bodies_emit_once`
- `tests/unit/feature/document_collection/signal_handler_guards_test.gd` — `test_null_target_is_rejected`, `test_non_document_body_target_is_filtered`, `test_null_document_export_is_warned_and_filtered`
- CI grep for `_process` / `_physics_process` in `document_collection.gd` — zero matches (AC-DC-9.3)
- CI grep for aggregate query method names — zero matches (AC-DC-8.1)
- CI grep for sole-publisher violations — zero matches (AC-DC-3.2)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Document class registered), Story 002 (DocumentBody class registered for `target is DocumentBody` check)
- Unlocks: Story 004 (capture/restore methods on the same node), Story 005 (integration test requires the full node to be present in the Plaza scene)
