# Story 003: respawn_triggered signal emission — ordering contract + subscriber re-entrancy fence + sting suppression

> **Epic**: Failure & Respawn
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (S-M — signal emission, ordering test, re-entrancy lint, sting suppression path)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/failure-respawn.md`
**Requirement**: TR-FR-002 (sole publisher of `respawn_triggered`), TR-FR-008 (emitted BEFORE `reload_current_section`; re-entrancy forbidden), TR-FR-014 (sting suppression: Audio `player_died` handler checks no-op condition when `respawn_triggered` fires within ≤100 ms)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: `Events.respawn_triggered(section_id: StringName)` is the sole signal in the Failure/Respawn domain per ADR-0002:183. F&R is the **sole publisher** — no other class may call `Events.respawn_triggered.emit(...)`. Publishers use direct emit (`Events.respawn_triggered.emit(args)`) — no wrapper methods. Signal ordering is load-bearing: `respawn_triggered` fires BEFORE `reload_current_section` so Audio, in-flight darts, and `GuardFireController` receive the notification before LS begins freeing scene nodes. Subscriber re-entrancy is forbidden: no `respawn_triggered` subscriber may call any `LevelStreamingService` method or emit further `Events.*` signals from within its handler (CR-8 fence).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot 4.6 synchronous signal delivery is per-callable: one subscriber's handler completing does not block others. Signal delivery order among subscribers of the same signal follows connection order (determined by `connect()` call sequence at `_ready()`). The re-entrancy fence is a design contract enforced by CI lint (Story 006), not a runtime guard in F&R's code. `Events.respawn_triggered` is already declared on `events.gd` (Signal Bus epic story-002); this story implements the emit call and confirms sole-publisher invariant.

**Control Manifest Rules (Feature)**:
- Required (Foundation/Signal Bus): use direct emit `Events.respawn_triggered.emit(args)` — no wrapper methods — ADR-0002 §Risks
- Required (Foundation/Signal Bus): enum types in signal signatures defined on the system class that owns the concept — ADR-0002 IG 2 (section_id is `StringName`, no enum needed)
- Forbidden: adding methods, state, or query helpers to `events.gd` — pattern `event_bus_with_methods`
- Forbidden: subscriber re-entrancy from `respawn_triggered` handlers (no LS method calls, no further `Events.*` emits) — CR-8; enforced by CI lint in Story 006

---

## Acceptance Criteria

*From GDD `design/gdd/failure-respawn.md` CR-8, CR-12 Steps 5-6, E.25, E.26, AC-FR-6.1–6.3; TR-FR-002, TR-FR-008, TR-FR-014:*

- [ ] **AC-1**: GIVEN a test subscriber connected to `Events.respawn_triggered` that records call order with the `LevelStreamingService` double, WHEN `Events.player_died` fires and CAPTURING runs, THEN `Events.respawn_triggered(section_id)` is emitted BEFORE `LevelStreamingService.reload_current_section` is called (verified by ordering sequence: step 5 emit precedes step 6 call in the CAPTURING body).
- [ ] **AC-2**: GIVEN no subscriber is connected to `Events.respawn_triggered`, WHEN `Events.player_died` fires, THEN the respawn flow completes to `FlowState.RESTORING` without error and without `push_error` (GDD E.25 — absent subscribers simply miss the signal).
- [ ] **AC-3**: GIVEN a mock subscriber to `respawn_triggered` that calls `push_error("test-error")` (soft error, not an unhandled exception), WHEN F&R emits `respawn_triggered`, THEN F&R continues to call `reload_current_section` after the handler returns AND `_flow_state` progresses to `RESTORING` (soft-error path; see GDD E.26 + AC-FR-6.2 note — hard unhandled-exception branch is deferred pending OQ-FR-8 engine verification gate).
- [ ] **AC-4**: GIVEN a grep lint across `src/**/*.gd`, WHEN searching for `respawn_triggered\.emit\b`, THEN the only matching file is `src/gameplay/failure_respawn/failure_respawn_service.gd` (sole-publisher invariant per ADR-0002:183 + AC-FR-12.4).
- [ ] **AC-5**: GIVEN the `section_id` passed to `respawn_triggered`, WHEN F&R emits it at step 5, THEN `section_id` is the `StringName` of the current active section at the moment of death (the section Eve was in when `player_died` fired — not a future or past section).
- [ ] **AC-6**: GIVEN `Events.player_died` fires within the VS `DeathCause.SCRIPTED` path (caught-by-guard → mission-fail), WHEN CAPTURING runs, THEN `Events.respawn_triggered` is emitted with a valid non-empty `StringName` section_id (no empty-string emission).

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines, GDD CR-8, CR-12 Step 5:*

**Emit placement in CAPTURING body** — `Events.respawn_triggered.emit(_current_section_id)` is step 5, between step 4 (`save_to_slot`) and step 6 (`reload_current_section`). This ordering is non-negotiable per CR-8: Audio must start its silence gap BEFORE LS begins its own fade tween; in-flight darts must receive the signal before LS frees scene nodes.

**`_current_section_id` tracking** — F&R needs the current section's `StringName`. The `section_entered` handler (Story 004) captures this: `_current_section_id = section_id` when `reason in [FORWARD, NEW_GAME, LOAD_FROM_SAVE]` and `_flow_state == IDLE`. This is a `StringName` member on `FailureRespawnService`. At boot it is `&""` (valid — the `respawn_triggered` AC-6 check guards against this with a VS-scoped section pre-load path).

**Subscriber re-entrancy fence** — F&R itself does NOT need runtime re-entrancy guards on the emit side; the subscribers are responsible for not calling LS/emitting Events from their handlers. The fence is enforced by the CI grep lint in Story 006 (`lint_respawn_triggered_no_reentrancy.sh`). F&R's CAPTURING body runs synchronously; after `emit()` returns (all subscribers have run their handlers), F&R calls `reload_current_section`. If a subscriber crashes (unhandled exception in GDScript), Godot 4.6's per-callable delivery means subsequent subscribers still receive the signal — F&R observes the `emit()` call as returned and calls `reload_current_section` regardless (GDD E.26; the hard-exception isolation behavior is pending OQ-FR-8 engine gate).

**Sting suppression contract** — at step 5, `respawn_triggered` fires within ≤100 ms of `player_died` (the save at step 4 is ≤15 ms; steps 1–3 are sub-millisecond). Audio's `player_died` handler must check a no-op condition: if `respawn_triggered` fires within ≤100 ms of the same `player_died`, the mission-failure sting is suppressed. This is an Audio GDD coordination item — F&R does not implement the suppression itself. F&R's responsibility is to emit `respawn_triggered` within the ≤100 ms window, which the synchronous CAPTURING body guarantees. This story verifies the timing by confirming no `await` appears between `player_died` receipt and `respawn_triggered` emission (the AC-FR-12.3 lint covers this for `save_to_slot` → `reload_current_section`; this story extends the scope to the emit call placement).

**VS SCRIPTED path** — in the Vertical Slice, the only tested death path is `DeathCause.SCRIPTED` (caught-by-guard → mission-fail → respawn). The signal emission is cause-agnostic (same code path regardless of `DeathCause`), but the VS integration test in Story 005 uses `SCRIPTED` as the trigger.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload scaffold, signal subscription wiring
- Story 002: CAPTURING body — SaveGame assembly, `save_to_slot` call, in-memory handoff
- Story 004: `_current_section_id` capture in the `section_entered` handler
- Story 005: full end-to-end VS beat integration test (signal + reload + restore callback + reset_for_respawn)
- Story 006: CI grep lint for sole-publisher (`lint_respawn_triggered_sole_publisher.sh`) and re-entrancy fence (`lint_respawn_triggered_no_reentrancy.sh`)
- AC-FR-6.2 hard branch (unhandled-exception isolation) — deferred pending OQ-FR-8 godot-specialist engine-verification gate

---

## QA Test Cases

**AC-1 — respawn_triggered emitted before reload_current_section**
- Given: F&R with doubles; an ordering spy connected to both `Events.respawn_triggered` and the LS double's `reload_current_section` method
- When: `Events.player_died.emit(CombatSystemNode.DeathCause.SCRIPTED)`
- Then: ordering spy records `respawn_triggered` call at index N, `reload_current_section` call at index N+1 (respawn_triggered is earlier in the sequence)
- Edge cases: if CAPTURING interleaves the two calls in wrong order — test must FAIL with clear ordering assertion message

**AC-2 — No-subscriber case completes without error**
- Given: no subscriber connected to `Events.respawn_triggered`; all other doubles no-op
- When: `player_died` fires
- Then: `_flow_state == FlowState.RESTORING`; no `push_error` was called; `reload_current_section` was called once

**AC-3 — Soft-error subscriber does not abort the flow**
- Given: a subscriber connected to `Events.respawn_triggered` whose handler calls `push_error("test-error")`
- When: `player_died` fires
- Then: F&R calls `reload_current_section` exactly once; `_flow_state == FlowState.RESTORING`
- Edge cases: subscriber throws `push_error` multiple times — `reload_current_section` still called exactly once

**AC-4 — Sole-publisher grep lint**
- Given: `src/**/*.gd` source tree
- When: grep for `respawn_triggered\.emit\b`
- Then: exactly one match in `src/gameplay/failure_respawn/failure_respawn_service.gd`; zero matches in any other file

**AC-5 — section_id is the current active section**
- Given: `_current_section_id` set to `&"plaza"` via `section_entered` handler pre-test setup
- When: `player_died` fires; `Events.respawn_triggered` subscriber captures the `section_id` argument
- Then: subscriber receives `&"plaza"` as the section_id argument

**AC-6 — Non-empty section_id on VS scripted path**
- Given: VS Plaza scenario with `_current_section_id = &"plaza"` (section entered before death)
- When: `DeathCause.SCRIPTED` player_died fires
- Then: the `section_id` argument of `respawn_triggered` is `&"plaza"` (non-empty StringName)
- Edge cases: `_current_section_id == &""` at boot (no section entered yet) — this is an authoring error; `push_warning` from F&R; test documents the expected warning

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/failure_respawn/signal_ordering_test.gd` — must exist and pass (AC-1 through AC-6)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload scaffold) MUST be Done; Story 002 (CAPTURING body places the emit call) MUST be Done; Signal Bus story-002 (`Events.respawn_triggered` signal declared on `events.gd`) MUST be Done
- Unlocks: Story 006 (CI lint for sole-publisher and re-entrancy fence depends on the emit call existing)

---

## Completion Notes

**Completed**: 2026-05-02. **Criteria**: 6/6 PASSING (6 tests). **Tests**: `tests/unit/feature/failure_respawn/respawn_triggered_ordering_test.gd`.

Files: `src/gameplay/failure_respawn/failure_respawn_service.gd` modified — replaced FR-002's `# TODO FR-003` marker with `Events.respawn_triggered.emit(_resolve_current_section_id())` at step 5, BEFORE step 6's `transition_to_section`. Doc comment explains CR-8 ordering contract + sting suppression timing window (≤100 ms guarantee via synchronous capture body).

ACs: AC-1 ordering verified by inner _TestLSDouble + ordering_log; AC-2 no-subscriber clean completion; AC-3 soft-error subscriber path; AC-4 sole-publisher source-grep across `src/**/*.gd` (only `failure_respawn_service.gd` contains `respawn_triggered.emit`); AC-5 section_id matches `_current_section_id`; AC-6 non-empty StringName via fallback to `_ls_service.get_current_section_id()`.

Tech debt: NONE. Code Review: APPROVED (sole publisher invariant clean; no await between emit and transition; ADR-0002:183 satisfied).
