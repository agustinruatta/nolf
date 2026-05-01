# Sprint 02 — Foundation + Core

> **Dates**: 2026-05-04 (Mon) → 2026-05-22 (Fri)
> **Duration**: 3 weeks / 15 working days
> **Status**: In Progress — Must-Have layer COMPLETE 2026-05-01 (24/24 done + LOC-002 Should-Have done; Should-Have/Nice-to-Have backlog remains: LS-003, SL-005, SL-006, AUD-001, OUT-001, PPS-001)
> **Review Mode**: solo (PR-SPRINT producer gate skipped)
> **Previous Sprint**: [Sprint 01 — Technical Verification Spike](sprint-01-technical-verification-spike.md) — Closed 2026-05-01

---

## Sprint Goal

Land **Foundation + Core** code so Eve can walk in a streaming Plaza scene, with signal bus / save-load / localization / input / camera / movement / footstep / interaction surfaces all live and unit-tested. No stealth AI, no documents, no HUD, no menu — those are Sprint 03+ scope.

**End-of-sprint demo target**: launch a stub Plaza scene, walk around it, save, quit, reload, resume mid-walk.

## Capacity

- Total: 15 working days × 5 productive hours/day ≈ 75 hours
- Buffer (20% solo reserve for unplanned + cross-story rework): 15 hours
- Available capacity: **60 hours**
- Story average: ~2.5 hours
- Realistic target throughput: **~24 stories**

## Tasks — Must Have (Critical Path)

| ID | Task | Owner | Est. h | Deps | Story file |
|----|------|-------|--------|------|------------|
| SB-001 | Events autoload — structural purity + registration | godot-gdscript-specialist | 3 | — | `production/epics/signal-bus/story-001-events-autoload-structural.md` |
| SB-002 | Built-in-type signal declarations on `events.gd` | godot-gdscript-specialist | 2 | SB-001 | `production/epics/signal-bus/story-002-builtin-type-signals.md` |
| SB-003 | EventLogger debug autoload — subscription + non-debug self-removal | godot-gdscript-specialist | 2 | SB-001 | `production/epics/signal-bus/story-003-event-logger-debug-autoload.md` |
| SB-004 | Subscriber lifecycle pattern + Node payload validity guard | godot-gdscript-specialist | 3 | SB-002 | `production/epics/signal-bus/story-004-subscriber-lifecycle-validity.md` |
| SB-005 | Anti-pattern enforcement — forbidden patterns + CI grep guards | godot-gdscript-specialist | 2 | SB-004 | `production/epics/signal-bus/story-005-anti-pattern-enforcement.md` |
| SB-006 | Edge case dispatch behavior — no-dedup + continue-on-error tests | godot-gdscript-specialist | 2 | SB-004 | `production/epics/signal-bus/story-006-edge-case-dispatch-behavior.md` |
| SL-001 | SaveGame Resource + 7 typed sub-resources scaffolding | godot-gdscript-specialist | 3 | SB-002 | `production/epics/save-load/story-001-save-game-resource-scaffold.md` |
| SL-002 | SaveLoadService autoload + save_to_slot atomic write | godot-gdscript-specialist | 3 | SL-001 | `production/epics/save-load/story-002-save-load-service-atomic-write.md` |
| SL-003 | load_from_slot + type-guard + version-mismatch refusal | godot-gdscript-specialist | 3 | SL-002 | `production/epics/save-load/story-003-load-from-slot-type-guard-version-mismatch.md` |
| SL-004 | duplicate_deep state-isolation discipline | godot-gdscript-specialist | 2 | SL-003 | `production/epics/save-load/story-004-duplicate-deep-state-isolation.md` |
| LOC-001 | CSV registration + tr() runtime + project.godot loc config | godot-gdscript-specialist | 2 | — | `production/epics/localization-scaffold/story-001-csv-registration-tr-runtime.md` |
| LS-001 | SectionRegistry + LSS autoload boot + fade overlay scaffold | godot-gdscript-specialist | 4 | SL-001 | `production/epics/level-streaming/story-001-section-registry-autoload-fade-overlay.md` |
| LS-002 | State machine + 13-step swap happy path + signal emission | godot-gdscript-specialist | 4 | LS-001, SB-002 | `production/epics/level-streaming/story-002-state-machine-13-step-swap-signals.md` |
| IN-001 | InputActions static class | godot-gdscript-specialist | 2 | — | `production/epics/input/story-001-input-actions-static-class.md` |
| IN-002 | InputContext stack autoload | godot-gdscript-specialist | 3 | IN-001 | `production/epics/input/story-002-input-context-stack-autoload.md` |
| PC-001 | PlayerCharacter scene root scaffold (CharacterBody3D) | gameplay-programmer | 2 | IN-002 | `production/epics/player-character/story-001-scene-root-scaffold.md` |
| PC-002 | First-person camera + look input | gameplay-programmer | 2 | PC-001, IN-002 | `production/epics/player-character/story-002-camera-look-input.md` |
| PC-003 | Movement state machine + locomotion | gameplay-programmer | 3 | PC-002 | `production/epics/player-character/story-003-movement-state-machine.md` |
| PC-004 | Noise perception surface (`get_noise_level()`, etc.) | gameplay-programmer | 2 | PC-003 | `production/epics/player-character/story-004-noise-perception-surface.md` |
| PC-005 | Interact raycast + query API | gameplay-programmer | 3 | PC-002 | `production/epics/player-character/story-005-interact-raycast.md` |
| FS-001 | FootstepComponent scaffold | godot-gdscript-specialist | 1.5 | PC-003 | `production/epics/footstep-component/story-001-footstep-component-scaffold.md` |
| FS-002 | Step cadence state machine | godot-gdscript-specialist | 2 | FS-001 | `production/epics/footstep-component/story-002-step-cadence-state-machine.md` |
| FS-003 | Surface detection raycast | godot-gdscript-specialist | 2 | FS-001 | `production/epics/footstep-component/story-003-surface-detection-raycast.md` |
| FS-004 | Signal emission + integration (`footstep_emitted`) | godot-gdscript-specialist | 2 | FS-002, FS-003, SB-002 | `production/epics/footstep-component/story-004-signal-emission-and-integration.md` |

**Total: 24 stories, ~58 h estimated** — fits within 60 h available with 2 h cushion before the 20 % buffer.

## Tasks — Should Have (if Must Have wraps early)

| ID | Task | Est. h | Deps | Story file |
|----|------|--------|------|------------|
| SL-005 | Metadata sidecar (`slot_N_meta.cfg`) + slot_metadata API | 3 | SL-002 | `production/epics/save-load/story-005-metadata-sidecar-slot-metadata-api.md` |
| SL-006 | 8-slot scheme + slot 0 mirror on manual save (CR-4) | 2 | SL-002 | `production/epics/save-load/story-006-eight-slot-scheme-slot-zero-mirror.md` |
| LS-003 | register_restore_callback chain + step 9 sync invocation | 3 | LS-002 | `production/epics/level-streaming/story-003-register-restore-callback-step9-sync-invocation.md` |
| AUD-001 | AudioManager node scaffold + 5-bus structure | 3 | SB-002 | `production/epics/audio/story-001-audiomanager-node-scaffold.md` |
| LOC-002 | Pseudolocalization CSV + dev workflow + export filter | 2 | LOC-001 | `production/epics/localization-scaffold/story-002-pseudolocalization-csv-export-filter.md` |

## Tasks — Nice to Have (stretch)

| ID | Task | Est. h | Deps | Story file |
|----|------|--------|------|------------|
| OUT-001 | OutlineTier class scaffold — constants, set_tier(), validation | 3 | — | `production/epics/outline-pipeline/story-001-outline-tier-class-scaffold.md` |
| PPS-001 | PostProcessStack autoload scaffold + chain-order const | 3 | SB-002 | `production/epics/post-process-stack/story-001-autoload-scaffold-chain-order.md` |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| ADR-0004 G3/G4/G5 closure | Deferred to runtime AT testing post-MVP | n/a — not Sprint 02 work |
| ADR-0008 Iris Xe + Restaurant scene perf measurement | Deferred to first Production sprint shipping outline-bearing scene | n/a — Sprint 03+ |
| `/architecture-review` re-run after rendering ADRs Accepted | Pending; ADR-0005 now Accepted, others still Proposed by design | Optional Sprint 02 housekeeping (~2 h) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Story estimates optimistic for first-time implementation | Medium | Medium | 20 % buffer; defer Should-Have to Sprint 03 if wave 4 (Player Character) bleeds into week 3 |
| GdUnit4 4.6.2 patch breaks on addon update | Low | Low | Pin via documented `PATCH 2026-04-30` comment; `tests/README.md` instructs re-application |
| Solo dev availability variance | Medium | High | Sprint plan has Foundation as Must-Have so a slip still leaves Foundation done; Core slips to Sprint 03 if needed |
| Cross-epic dependencies surprise the sprint | Low | Medium | All 8 cross-epic OQs documented in `production/session-state/active.md` — none hit Sprint 02 Must-Have selection |
| Scope creep ("just one more thing") | Medium | Medium | `/scope-check` before each addition; Should-Have list is the only legal place to grow |

## External Dependencies

None for Sprint 02. (Asset specs, audio assets, art finals are all post-Sprint-02 work.)

## Definition of Done for Sprint 02

- [ ] All 24 Must-Have tasks moved to `Done` via `/story-done`
- [ ] All Logic / Integration stories have passing tests in `tests/unit/foundation/`, `tests/unit/core/`, `tests/integration/foundation/`, `tests/integration/core/`
- [ ] Test suite runs green: `godot -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit -a tests/integration` exits 0
- [ ] QA plan exists at `production/qa/qa-plan-sprint-02.md` (run `/qa-plan sprint` before implementation)
- [ ] Smoke check passes (`/smoke-check`)
- [ ] No S1 / S2 bugs filed against Sprint 02 deliverables
- [ ] **Demo gate**: stub Plaza scene loads via `LevelStreamingService.transition_to_section("plaza_stub")`, Eve walks, footsteps fire `footstep_emitted`, F5 save → quit → relaunch → F9 load → resume mid-walk works
- [ ] `production/session-state/active.md` updated with Sprint 03 hand-off summary

## Sprint 02 in the Bigger Picture (calibration only)

| Sprint | Scope target | Approx. weeks |
|---|---|---|
| **02 (this one)** | Foundation + Core | 3 |
| 03 | Stealth AI + Document Collection + Failure & Respawn + Mission scaffold + minimum HUD | ~4 |
| 04 | Document Overlay + Menu + Settings Day-1 + Cutscenes/Mission Cards + Audio + Outline/PPS productionisation + Dialogue & Subtitles | ~4 |
| 05 | VS integration + 3 playtests + Polish | ~2 |

**Total path to VS gate-check: ~13 weeks of solo work** — longer than the original 3-4 week estimate, because VS scope was broadened to test all 21 systems per the user's "test almost all" directive.

## Related

- `production/epics/index.md` — full backlog (21 epics, 130 stories)
- `production/project-stage-report.md` — Pre-Production → Production gap analysis
- `production/session-state/active.md` — current state + 8 cross-epic open questions
- `production/sprint-status.yaml` — machine-readable story status (auto-updated by `/story-done`)
- `production/notes/nolf1-style-alignment-brief.md` — NOLF 1 visual reference (post-VS asset work)

> **Scope check**: This sprint is scoped tightly to the existing 24 Must-Have story files. If new work is added, run `/scope-check` to detect creep before implementation begins.
