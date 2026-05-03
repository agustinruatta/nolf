# Sprint 05 — Mission Loop & Persistence

**Dates**: 2026-05-02 to 2026-05-09 (7 calendar days; autonomous-execution sprint)
**Generated**: 2026-05-02
**Mode**: solo review (per `production/review-mode.txt`)
**Source roadmap**: `production/sprints/multi-sprint-roadmap-pre-art.md` Sprint 05 section

## Sprint Goal

**Failure has consequences and progress survives.**

Sprint 04 made the level *alive* (perception → suspicion → patrol → audio cue
→ reset). Sprint 05 makes the level *durable*: the player who dies returns to
their checkpoint within 2 s with mission state intact, every section transition
gated `FORWARD` writes a slot-0 autosave assembled from each owning system's
`capture()` static, and quicksave (F5) / quickload (F9) round-trip through a
section transition with no data loss. By close, the Plaza VS demo plays the
full **mission loop**: NEW_GAME → mission_started → objective_started("Recover
Plaza Document") → caught-by-guard → player_died(SCRIPTED) → respawn_triggered
→ reload_current_section → step-9 restore → reset_for_respawn → mission_state
identical to pre-death snapshot → document_collected → objective_completed →
mission_completed. Save-load is the persistent backbone; F&R + MLS are the two
gameplay-layer orchestrators that author the loop.

This sprint brings us closer to the **art-integration-ready milestone** (end
of Sprint 08): every code-ready system implemented and proven on placeholder
geometry. After Sprint 05, two systems remain (HUD shell + Audio body +
Document logic + Level Streaming hardening) before the project is waiting on
art alone.

## Capacity

- Total agent-time: ~4 days work-equivalent
- Buffer (20%): 1 day reserved for ADR-0007 mission-vs-failure ordering
  edge cases, save-format manifest-version decisions, MLS capture() chain
  integration friction
- Available: 3 days for committed work
- Total committed estimate: **~30–42 hours of agent work** (14 stories,
  mostly Logic with 4 Integration; lower count than Sprint 04's 16 because 3
  Save/Load stories from the roadmap are already DONE)

## Roadmap Reconciliation

The multi-sprint roadmap §Sprint 05 (lines 38–53) lists "Save/Load remaining
ready: SL-002, SL-003, SL-006, SL-007, SL-009 (5 stories)". This is stale —
**SL-002, SL-003, SL-005, SL-006 were closed** in Sprints 02 (SL-001..005) +
Sprint 04 carry-in (SL-006). The **actual remaining Save/Load stories** at
Sprint 05 start are:

- **SL-007** — Quicksave (F5) / Quickload (F9) + InputContext gating
- **SL-008** — Sequential save queueing (IDLE / SAVING / LOADING state machine)
- **SL-009** — Anti-pattern fences + registry entries + lint guards

= **3 Save/Load stories**, not 5.

Total Sprint 05 story count therefore lands at **14**, not the roadmap's 16
(the 2-story shortfall is purely "already done" — no scope reduction).

> **Note**: This is the *opposite* of scope creep — the sprint is delivering
> the same epic outcomes with 2 fewer stories because earlier sprints overshot
> on the Save/Load front. Document for `/scope-check` at sprint close: 0
> additions, 2 subtractions (already-DONE).

## Tasks

### Must Have — Save/Load tail (3)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| SL-007 | Quicksave (F5) / Quickload (F9) + InputContext gating | godot-gdscript-specialist | 2-3h | Logic | SL-002 ✅, SL-003 ✅, IN-003 ✅, IN-007 ✅ | F5 routes through InputContext.GAMEPLAY only → save_to_slot(QUICKSAVE_SLOT); F9 routes → load_from_slot(QUICKSAVE_SLOT); MENU/LOADING/CUTSCENE contexts swallow the action; unit + integration tests verify gating |
| SL-008 | Sequential save queueing (IDLE / SAVING / LOADING state machine) | godot-gdscript-specialist | 3-4h | Logic | SL-002 ✅, SL-007 | State machine: IDLE → SAVING → IDLE; IDLE → LOADING → IDLE; concurrent save/load attempts queue or refuse per ADR-0003; unit tests cover all 9 state-edge transitions; no double-write race |
| SL-009 | Anti-pattern fences + registry entries + lint guards | godot-gdscript-specialist | 1-2h | Logic | SL-007, SL-008 | CI shell scripts + 1 unit test; `save_during_load` / `load_during_save` / `direct_save_resource_call` / `bypass_atomic_rename` patterns blocked; tr-registry entries for SL forbidden patterns; grep-tested |

### Must Have — Failure & Respawn (6)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| FR-001 | FailureRespawn autoload scaffold — state machine + signal subscriptions + restore callback registration | gameplay-programmer | 2-3h | Logic | ADR-0007 ✅, ADR-0002 ✅, LS-003 ✅ | FailureRespawn autoload registered in `project.godot` after Combat, before MissionLevelScripting; subscribes to `Events.player_died`; registers LS step-9 restore callback at `_ready`; unit test verifies registration + state-machine init |
| FR-002 | Slot-0 autosave assembly via MLS-owned capture() chain + in-memory SaveGame handoff to LS | gameplay-programmer | 3-4h | Logic | FR-001, MLS-001, MLS-002 | On `player_died`: F&R calls MLS.assemble_savegame() (the FORWARD-gated capture chain inverted for in-memory mode); receives `SaveGame`; hands to `LevelStreamingService.reload_current_section(savegame)`; unit test mocks LS + asserts handoff payload |
| FR-003 | respawn_triggered signal emission — ordering contract + subscriber re-entrancy fence + sting suppression | gameplay-programmer | 2-3h | Logic | FR-001, FR-002 | F&R emits `Events.respawn_triggered(section_id)` AFTER autosave assembly, BEFORE LS reload; re-entrancy fence prevents recursive death-during-respawn; alert-stinger suppression flag set; unit tests cover all 3 cases |
| FR-004 | Plaza checkpoint assembly — section_entered handler + CR-7 IDLE guard + floor flag state machine (VS path) | gameplay-programmer | 2-3h | Logic | FR-001 | F&R subscribes to `Events.section_entered`; updates `last_checkpoint_id` only when LS state == IDLE (Core Rule 7); `respawn_floor_used` flag false on FORWARD, true on RESPAWN; unit tests cover state-machine transitions |
| FR-005 | LS step-9 restore callback + PlayerCharacter.reset_for_respawn + InputContext push/pop — VS end-to-end respawn beat | gameplay-programmer + godot-gdscript-specialist | 4-6h | Integration | FR-002, FR-003, FR-004, PC-006 ✅ | F&R's step-9 callback restores FailureRespawnState + calls `PlayerCharacter.reset_for_respawn(checkpoint_marker)`; reset_for_respawn() implementation: clear velocity, restore full HP, teleport to marker; InputContext.LOADING pushed at reload start, popped at step-9 complete; integration test exercises full beat with stub Plaza scene |
| FR-006 | Anti-pattern fences — fr_autosaving_on_respawn forbidden pattern + RESPAWN-not-FORWARD autosave distinction + CI lint guards | godot-gdscript-specialist | 1-2h | Logic | FR-005 | CI shell scripts + 1 unit test; `fr_autosaving_on_respawn` (RESPAWN reason must NEVER trigger save_to_slot) + `fr_emitting_outside_failure_domain` patterns blocked; tr-registry entries; grep-tested |

### Must Have — Mission & Level Scripting (5)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| MLS-001 | MissionLevelScripting autoload scaffold + load-order registration | gameplay-programmer | 2-3h | Logic | ADR-0007 ✅ | MissionLevelScripting autoload registered in `project.godot` after FailureRespawn; init order verified by integration test; unit test verifies autoload presence + state-machine init |
| MLS-002 | Mission state machine + four Mission-domain signal declarations | godot-gdscript-specialist | 2-3h | Logic | MLS-001, ADR-0002 ✅ | 4 signals declared on `Events.gd` per ADR-0002 (`mission_started`, `mission_completed`, `objective_started(id)`, `objective_completed(id)`); MLS state machine: NEW_GAME → IN_PROGRESS → COMPLETED; signal-purity test; never-emit-outside-mission-domain proof |
| MLS-003 | Plaza section authoring contract — required nodes, CI validation, discovery surface | godot-gdscript-specialist | 2-3h | Logic | MLS-001 | Documented contract in `docs/architecture/section-authoring-contract.md`: every section scene must include `player_respawn_point: Marker3D`, `WorldItem` nodes within Inventory budget; CI grep gate validates Plaza VS scene file for required nodes; unit test parses scene and asserts contract |
| MLS-004 | SaveGame assembler chain — FORWARD autosave gate wired to all 6 capture() calls | gameplay-programmer | 3-4h | Integration | MLS-002, FR-001, SL-002 ✅ | On `section_entered(FORWARD)`: MLS calls Player.capture() + StealthAI.capture() + Document.capture() + Mission.capture() + FailureRespawn.capture() + Inventory.capture() (stub for VS); assembles `SaveGame`; calls `SaveLoadService.save_to_slot(0, savegame)`; RESPAWN reason must skip; integration test exercises both reasons |
| MLS-005 | Plaza objective integration — Recover Plaza Document, NEW_GAME to COMPLETED | gameplay-programmer | 3-4h | Integration | MLS-002, MLS-003, MLS-004, FR-005, document-collection (stub) | Plaza mission emits `mission_started` on NEW_GAME → `objective_started("recover_plaza_document")` → on `Events.document_collected` → `objective_completed` → `mission_completed`; integration test runs the full state-machine traversal with stub document trigger |

### Should Have
*(Empty — buffer reserved for ADR-0007 mission-vs-failure ordering edge cases, save-format manifest-version decisions, MLS capture() chain integration friction. If Must-Have closes early, pull the next Sprint 06 candidate forward — recommended: HUD-CORE-001 root canvas scaffold.)*

### Nice to Have
*(Empty — keep buffer.)*

## Carryover from Sprint 04
*Implementation-side: none — Sprint 04 closed all 16 Must-Have stories.*

**User-side carryover (informational, not Sprint 05 blockers):**
- Plaza VS scene with baked NavigationMesh (unblocks SAI-006 real-movement playtest, SAI-008 Plaza-VS audio playtest, SAI-010 nav perf measurement)
- Iris Xe Gen 12 hardware perf verification (re-opens ADR-0008 Gates 1+2)
- Manual Pillar 3 playtest sign-off (`production/qa/evidence/stealth-ai-pillar3-feel-[YYYY-MM-DD].md`)
- F.2 sound fill (post-VS, TR-SAI-008)
- F.4 alert propagation (post-VS, TR-SAI-010)
- SAW_BODY mechanic (post-VS — no dead bodies in VS)
- 4 `/architecture-review` queued items (TR-SAI-005 registry drift, `@abstract func` body-less form, `_compute_severity` underscore, `stealth_alert_audio_subscriber.gd` location)

These do not gate Sprint 05 work. They gate Sprint 04 → Sprint 05+ stage
advancement only at the user's discretion.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| **ADR-0007 mission-vs-failure ordering ambiguity** (already amended once 2026-04-27 — F&R now before MLS) | LOW-MED | **HARD STOP CONDITION per task brief.** | If FR-002's MLS-owned capture() chain or MLS-004's autoload ordering surfaces a contradiction with ADR-0007, surface to user before any amendment. The amendment chain so far: original (MLS before F&R) → 2026-04-27 (F&R before MLS, both after Combat). Re-amendment requires user review. |
| Save-format **manifest-version bump decision** (SL-007 quicksave changes save flow; SL-008 state machine introduces queueing semantics) | MED | **HARD STOP CONDITION per task brief.** | If SL-007 or SL-008 implementation requires changing the `SAVE_FORMAT_VERSION` constant or adding a new field to `SaveGame`, surface to user before bumping. Current manifest version: 2026-04-30. |
| MLS capture() chain wiring (MLS-004) discovers a missing `capture()` static on Inventory or another epic that hasn't shipped yet | MED | Could blow MLS-004 estimate by 50%; may force VS-stub of one capture | Stub the missing capture as `static func capture() -> Resource: return null` with TR-ID + tech-debt entry; document in `production/registry/tech-debt.yaml`; surface to user only if more than 1 epic is missing. |
| FR-005's `PlayerCharacter.reset_for_respawn(checkpoint)` implementation surfaces a missing PC-007 dependency | LOW | FR-005 carries the implementation in-scope per its title | reset_for_respawn() is in FR-005's scope (per story title). PC-007 (deferred from Sprint 04 close-out notes) is the same function; do NOT create a parallel PC-007 — let FR-005 land it. |
| Tech-debt register grows past 12 items | LOW | **HARD STOP CONDITION per task brief.** | Currently 7 items (TD-001..TD-007); 5-item buffer. Triage if new debt exceeds it. SL-009 + FR-006 + MLS forbidden-pattern fences add registry entries, NOT debt. |
| 14-story marathon causes context exhaustion | MED | Mid-sprint context drop | Pattern from Sprint 02/03/04 marathons: write to `active.md` after each story; rely on file-backed state per `.claude/docs/context-management.md`. |

## Dependencies on External Factors
- **None.** All ADRs the sprint depends on are Accepted (ADR-0002, ADR-0003, ADR-0006, ADR-0007, ADR-0008).
- All upstream stories (PC-001..006, IN-001..007 Sprint-04 tail, SB-001..006, SL-001..006, AUD-001..002, LS-001..003, SAI-001..010) Complete.
- **No art assets required.** Plaza VS scene (already a deferred Sprint 04 carryover) is required for MLS-005 integration; F&R + MLS will use a stub Plaza scene if the real one is not yet baked. Surface to user if MLS-005 requires real Plaza geometry.

## Stop Conditions (per task brief, MUST stop and surface to user)

1. **ADR-0007 mission-vs-failure ordering ambiguity or amendment required** — already amended once; re-amendment is a hard stop
2. **Scope drift** — `/scope-check` flags creep beyond the 14 listed story IDs (SL-007/008/009, FR-001..006, MLS-001..005)
3. **Visual sign-off needed** — F&R respawn beat or MLS objective HUD surface (not in Sprint 05 scope; HUD is Sprint 06) requires sign-off
4. **Art asset surfaces as a hard blocker** — should not happen this sprint; Plaza VS scene stubbed if needed
5. **Test failure or regression** — smoke check fails or suite regresses; do NOT patch by skipping tests
6. **Cross-sprint dependency emerges** — if a Sprint 05 decision invalidates Sprint 06+ plan
7. **Tech-debt register grows beyond 12 items** — currently 7; pause at 13 for triage
8. **Manifest-version bump decision for save format** — `SAVE_FORMAT_VERSION` change or new `SaveGame` field requires user review

## Definition of Done for Sprint 05
- [ ] All 14 Must-Have stories closed via `/story-done`
- [ ] Test suite ≥ 725 + Sprint-05 additions, zero regressions
- [ ] All Logic stories have passing unit tests (`tests/unit/foundation/save_load/`, `tests/unit/feature/failure_respawn/`, `tests/unit/feature/mission_level_scripting/`)
- [ ] All Integration stories have integration tests (`tests/integration/feature/failure_respawn/`, `tests/integration/feature/mission_level_scripting/`)
- [ ] 4 Mission-domain signals declared on `Events.gd`: `mission_started`, `mission_completed`, `objective_started(id)`, `objective_completed(id)`; signal-purity test passes
- [ ] 1 F&R-domain signal declared: `respawn_triggered(section_id)`; ordering contract enforced by test
- [ ] FailureRespawn + MissionLevelScripting autoloads registered in `project.godot` per ADR-0007 amended order (after Combat: F&R first, MLS second)
- [ ] Forbidden patterns registered: `save_during_load`, `load_during_save`, `direct_save_resource_call`, `bypass_atomic_rename` (SL); `fr_autosaving_on_respawn`, `fr_emitting_outside_failure_domain` (FR); `autosave_on_respawn`, `mls_emitting_outside_mission_domain` (MLS)
- [ ] Plaza VS demo plays full mission loop: NEW_GAME → mission_started → objective_started → caught-by-guard → player_died → respawn_triggered → reload → step-9 restore → reset_for_respawn → state restored → document_collected → objective_completed → mission_completed (manual evidence doc — `production/qa/evidence/sprint-05-mission-loop-evidence.md`)
- [ ] Section authoring contract documented (`docs/architecture/section-authoring-contract.md`)
- [ ] QA plan exists (`production/qa/qa-plan-sprint-05-2026-05-02.md`)
- [ ] Smoke check passes (`production/qa/smoke-2026-05-XX-sprint-05.md`)
- [ ] `/scope-check sprint-05-mission-loop-and-persistence` clean — no IDs added beyond the 14 listed
- [ ] `production/sprint-status.yaml` updated by `/story-done` invocations
- [ ] `production/session-state/active.md` close-out section appended

## QA Plan Status
**Not yet written.** Run `/qa-plan sprint` immediately after this plan is written, before any `/dev-story` invocation.

## Implementation Order (intra-epic + cross-epic dependency-respecting)

**Phase A — Save/Load tail** (independent of FR/MLS; can land first):
1. SL-007 (quicksave/quickload + context gating)
2. SL-008 (sequential save queueing state machine)
3. SL-009 (SL anti-pattern fences)

**Phase B — Foundation autoloads + state machines** (parallel-safe):
4. FR-001 (FailureRespawn autoload scaffold)
5. MLS-001 (MissionLevelScripting autoload scaffold)
6. MLS-002 (Mission state machine + 4 signals)
7. MLS-003 (Plaza section authoring contract)

**Phase C — F&R chain** (FR-002 needs MLS state machine + assemble surface; MLS-004 needs FR-001 capture):
8. FR-002 (slot-0 autosave assembly via MLS chain)
9. FR-003 (respawn_triggered ordering contract)
10. FR-004 (Plaza checkpoint assembly)
11. MLS-004 (SaveGame assembler chain — FORWARD gate)

**Phase D — Integration + final polish**:
12. FR-005 (LS step-9 restore + reset_for_respawn + InputContext push/pop) — the integration centerpiece
13. FR-006 (F&R anti-pattern fences)
14. MLS-005 (Plaza objective integration — full mission loop)

> **Cross-epic note**: FR-002 implements F&R's call to MLS's assemble surface
> (the FORWARD-gated capture chain, which MLS-004 wires). Land MLS-001/002 to
> establish the state machine and signal contracts FIRST, then FR-002 + FR-003
> + FR-004 in parallel, then MLS-004 to finalize the assembler chain before
> FR-005 closes the integration loop.

## Reference Documents
- `production/sprints/multi-sprint-roadmap-pre-art.md` — Sprint 05 source
- `production/sprints/sprint-04-stealth-ai-foundation.md` — predecessor (closed 2026-05-02)
- `production/qa/smoke-2026-05-02-sprint-04.md` — Sprint 04 smoke check (PASS WITH WARNINGS)
- `production/epics/save-load/EPIC.md` — epic governance
- `production/epics/failure-respawn/EPIC.md` — epic governance
- `production/epics/mission-level-scripting/EPIC.md` — epic governance
- `design/gdd/save-load.md` — atomic write protocol, slot scheme, manifest version
- `design/gdd/failure-respawn.md` — DeathCause taxonomy, respawn beat timing
- `design/gdd/mission-level-scripting.md` — mission lifecycle, section authoring contract
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — Mission-domain + F&R-domain signal ownership
- `docs/architecture/adr-0003-save-format-contract.md` — SaveGame shape, atomic rename, manifest version
- `docs/architecture/adr-0007-autoload-load-order-registry.md` — F&R before MLS, both after Combat (amended 2026-04-27)
- `docs/architecture/adr-0008-performance-budget-distribution.md` — Slot 8 residual pool sharing
- `production/registry/tech-debt.yaml` — TD-001..TD-007 register

> **Scope check note**: This sprint adds zero stories beyond the roadmap's
> commitment AND removes 2 stories (already-DONE: SL-002, SL-003 implicitly +
> SL-006 explicitly). Run `/scope-check sprint-05-mission-loop-and-persistence`
> at sprint close to confirm no creep occurred during execution.
