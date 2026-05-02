# Sprint 04 — Stealth AI Foundation

**Dates**: 2026-05-02 to 2026-05-09 (7 calendar days; autonomous-execution sprint)
**Generated**: 2026-05-02
**Mode**: solo review (per `production/review-mode.txt`)
**Source roadmap**: `production/sprints/multi-sprint-roadmap-pre-art.md` Sprint 04 section

## Sprint Goal

The level becomes alive — guards perceive, suspect, search, alert, and reset.

Sprint 02 proved the foundation infrastructure works end-to-end. Sprint 03
overlaid the comic-book visual signature. Sprint 04 brings the **first NPC** to
life: one Plaza guard with `CharacterBody3D` + `NavigationAgent3D` patrol, dual-
channel perception (vision cone + 10 Hz hearing), and the six-state
graduated-suspicion lattice from `design/gdd/stealth-ai.md`. By close, the Plaza
VS demo features a placeholder capsule guard who sees Eve, escalates through
SUSPICIOUS → SEARCHING → COMBAT, then de-escalates per Pillar 3 ("Stealth is
Theatre, Not Punishment"). Save-load round-trips guard state. Input is fully
context-routed so opening menus / overlays / pause / loading screens never
fires through to gameplay handlers. PC-006 closes the player health system so
guards have a damage target.

This sprint brings us closer to the **art-integration-ready milestone** (end
of Sprint 08): every code-ready system implemented and proven on placeholder
geometry. After that, Sprint 09 produces asset-spec briefs so AI generative
tools or marketplace assets can drop in for Eve / PHANTOM grunts / Eiffel bay
modules / Plaza props, and Sprint ~12 hits "first slice with final look".

## Capacity

- Total agent-time: ~5 days work-equivalent
- Buffer (20%): 1 day reserved for shader / NavigationAgent3D 4.6 quirks,
  ADR-0008 perf-budget pushback, integration-test flakiness
- Available: 4 days for committed work
- Total committed estimate: **~38–52 hours of agent work** (16 stories,
  mostly Logic/Integration; sized comparably to Sprint 02's 31-story marathon)

## Roadmap Reconciliation

The multi-sprint roadmap §Sprint 04 lists "Input remaining ready: INP-001,
002, 004, 005, 006 (5 stories)". This is a typo — IN-001 (InputActions
catalog) and IN-002 (InputContextStack autoload) are already **Complete**
(closed in Sprint 02 per `active.md`). The roadmap text "5 stories needed to
drive a player past the AI for testing" maps to the 5 actually-Ready Input
stories: **IN-003, IN-004, IN-005, IN-006, IN-007**. This sprint plan uses
those 5. Total story count (16) matches the roadmap's commitment.

## Tasks

### Must Have — Stealth AI critical path (10)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| SAI-001 | Guard node scaffold — CharacterBody3D + NavigationAgent3D + ADR-0006 layer assignment | gameplay-programmer | 2-3h | Logic | ADR-0006 ✅, ADR-0007 ✅ | 8 new files; node hierarchy compiles; layer/mask correct (LAYER_NPCS, mask covers WORLD+PLAYER); unit test verifies scene structure |
| SAI-002 | StealthAI enums + signals — AlertState/Severity/AlertCause/TakedownType + 6 SAI-domain signals | godot-gdscript-specialist | 2-3h | Logic | SB-002 ✅ | 6 signals declared on `Events.gd` per ADR-0002 (`alert_state_changed`, `actor_became_alerted`, `actor_lost_target`, `takedown_performed`, `guard_incapacitated`, `guard_woke_up`); 4 enums on `StealthAI` class (NEVER on `Events.gd`); signal-purity test |
| SAI-003 | RaycastProvider DI + perception cache — `IRaycastProvider` interface + 10 Hz cache | gameplay-programmer | 2-3h | Logic | SAI-001, SAI-002 | DI accepts `IRaycastProvider` at init; cold-start cache test; 10 Hz tick produces deterministic samples |
| SAI-004 | F.1 sight fill formula — range linear falloff (18 m), state multipliers, body factor | godot-gdscript-specialist | 3-4h | Logic | SAI-003 | F.1 implementation + 25-row parametrized test; cache write path verified |
| SAI-005 | F.5 thresholds + state escalation — 19-edge transition matrix, combined score | godot-gdscript-specialist | 3-4h | Logic | SAI-002, SAI-004 | T_SUSPICIOUS=0.3, T_SEARCHING=0.6, T_COMBAT=0.95; 19-edge transition + reversibility matrix tests |
| SAI-006 | Patrol + investigate behavior — PatrolController, state-driven movement | ai-programmer | 3-4h | Integration | SAI-001, SAI-005 | Plaza guard walks patrol spline; investigates on SUSPICIOUS; integration test guard moves between waypoints + reaches investigate target |
| SAI-007 | F.3 accumulator decay + de-escalation timers | godot-gdscript-specialist | 2-3h | Logic | SAI-005 | Per-state decay table; Pillar 3 reversibility matrix proven (loss-of-cue returns to UNAWARE) |
| SAI-008 | alert_state_changed audio subscriber — severity-gated stinger | godot-gdscript-specialist | 2-3h | Integration | SAI-002, SAI-005, AUD-002 ✅ | AudioManager subscribes; integration test asserts stinger fires on COMBAT, music duck on SUSPICIOUS+ |
| SAI-009 | Forbidden pattern fences — CI grep guards | godot-gdscript-specialist | 1-2h | Logic | SAI-002 | `sai_subscribing_to_player_footstep` + `events_with_state_or_methods` (SAI enum coupling) registered + grep-tested |
| SAI-010 | Performance budget + integration — perf harness, sub-budget measurement | performance-analyst | 3-4h | Integration | All SAI-001..009 + PC-005 ✅ | Perf harness exercises 1 guard at full perception poll; ADR-0008 stealth-AI sub-budget measured + recorded; manual evidence artifact |

### Must Have — Input critical path (5)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| IN-003 | Context routing + dual-focus dismiss integration | ui-programmer | 3-4h | Integration | IN-002 ✅ | 2 integration test files; GAMEPLAY → MENU → pop → GAMEPLAY round-trip; ui_cancel dismisses topmost context |
| IN-004 | Anti-pattern CI enforcement + debug action gating | godot-gdscript-specialist | 2-3h | Logic | IN-001 ✅, IN-002 ✅ | CI shell scripts + 1 unit test; `direct_input_global_query` / `unregistered_action` / `cross_context_event_consumption` patterns blocked |
| IN-005 | Edge-case discipline — order-of-ops, mouse mode, held-key | ui-programmer | 3-4h | Integration | IN-002 ✅, IN-003 | 4 integration test files; mouse-capture lifecycle correct on push/pop; held keys release on context pop |
| IN-006 | Runtime rebinding API — VS scope | godot-gdscript-specialist | 3-4h | Integration | IN-001 ✅, ADR-0003 ✅ | `InputMap.action_erase_events` + `action_add_event` flow; persists to `user://settings.cfg [input]`; restored on launch |
| IN-007 | LOADING context gate integration | ui-programmer | 2-3h | Integration | IN-002 ✅, LS-002 ✅ | LSS push(LOADING) on transition start; pop on transition end; integration test asserts gameplay events drop during LOADING |

### Must Have — Player Character damage target (1)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| PC-006 | Health system — apply_damage / apply_heal / DEAD guard | gameplay-programmer | 2-3h | Logic | PC-005 ✅, SB-002 ✅ | apply_damage with rounding; death transition; signal emission order; apply_heal; DEAD-state guards on movement/interact |

### Should Have
*(Empty — buffer reserved for ADR-0008 stealth-AI sub-budget pushback or NavigationAgent3D 4.6 quirks. If Must-Have closes early, pull the next Sprint 05 candidate forward — recommended: SL-002 quicksave/quickload polish.)*

### Nice to Have
*(Empty — keep buffer.)*

## Carryover from Sprint 03
*Implementation-side: none — Sprint 03 closed all 6 stories.*

**User-side carryover (informational, not Sprint 04 blockers):**
- OUT-005 user visual sign-off — fill in `production/qa/evidence/story-005-visual-signoff.md` and `story-005-slot1-perf-evidence.md` after a playtest run.
- "Looks like the game" reel screenshot for the studio reel.

These do not gate Sprint 04 work. They gate the Sprint 03 → Sprint 04 stage
advancement only at the user's discretion.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| `NavigationAgent3D` 4.6 API drift (pinned engine is post-LLM-cutoff) | MED | Could blow SAI-006 estimate by 50–100% | Cross-reference `docs/engine-reference/godot/modules/navigation.md` BEFORE pickup. Spawn godot-specialist for any API ambiguity. |
| Stealth AI signal-architecture decision required mid-sprint (ADR-0002 amendment for combat-only `damaged` payload) | LOW-MED | ADR amendment pause | **STOP CONDITION per roadmap.** If ambiguous, escalate to godot-specialist + surface to user before amending ADR-0002. |
| ADR-0008 stealth-AI sub-budget over-runs on Iris Xe (still Deferred per Sprint 02 close-out) | MED | SAI-010 evidence doc records measured value but cannot validate against missing hardware target | Document measurement, defer pass/fail until first Restaurant scene + Iris Xe hardware (ADR-0008 G1/G2/G4 deferred status preserved). |
| Visual sign-off requested for alert-state debug UI | LOW | **STOP CONDITION per roadmap.** | If a debug UI gets added during SAI-005/006/008, surface to user for sign-off before merging. |
| Tech-debt register grows past 12 items | LOW | **STOP CONDITION per roadmap §8.** | Currently 7 items (TD-001..TD-007); 5-item buffer. Triage if new debt exceeds it. |
| 16-story marathon causes context exhaustion | MED | Mid-sprint context drop | Pattern from Sprint 02 + 03 marathons: write to `active.md` after each story; rely on file-backed state per `.claude/docs/context-management.md`. |

## Dependencies on External Factors
- **None.** All ADRs the sprint depends on are Accepted (ADR-0001, ADR-0002, ADR-0003, ADR-0006, ADR-0007, ADR-0008).
- All upstream stories (PC-001..005, IN-001..002, SB-001..006, SL-001..006, AUD-001..002, LS-001..003) Complete.
- **No art assets required.** Guard is a placeholder capsule per VS scope.

## Stop Conditions (per roadmap, MUST stop and surface to user)

1. **ADR ambiguity or amendment required** — do not amend ADRs autonomously
2. **Scope drift** — `/scope-check` flags creep beyond the 16 listed story IDs
3. **Visual sign-off needed** — alert-state debug UI or other "user must see this" task surfaces
4. **Art asset surfaces as a hard blocker** — should not happen this sprint (placeholder capsule guard only)
5. **Test failure or regression** — smoke check fails or suite regresses; do NOT patch by skipping tests
6. **Cross-sprint dependency emerges** — if a Sprint 04 decision invalidates Sprint 06 plan
7. **Tech-debt register grows beyond 12 items** — currently 7; pause at 13 for triage

## Definition of Done for Sprint 04
- [ ] All 16 Must-Have stories closed via `/story-done`
- [ ] Test suite ≥ 423 + Sprint-04 additions, zero regressions
- [ ] All Logic stories have passing unit tests (`tests/unit/feature/stealth_ai/` + `tests/unit/core/input/` + `tests/unit/core/player_character/`)
- [ ] All Integration stories have integration tests (`tests/integration/feature/stealth_ai/` + `tests/integration/core/input/`)
- [ ] 6 SAI-domain signals declared on `Events.gd`; signal-purity test passes
- [ ] 4 forbidden patterns registered: `sai_subscribing_to_player_footstep`, `events_with_state_or_methods` (SAI), 3 input forbidden patterns
- [ ] Plaza VS demo features one capsule guard demonstrably patrolling, perceiving, escalating UNAWARE → SUSPICIOUS → COMBAT (manual evidence doc — `production/qa/evidence/sai-plaza-guard-evidence.md`)
- [ ] Save-load round-trips guard state (`actor_id` + patrol position) — covered by SL-001 round-trip test extension
- [ ] PC-006 health system unit tests pass
- [ ] QA plan exists (`production/qa/qa-plan-sprint-04-2026-05-02.md`)
- [ ] Smoke check passes (`production/qa/smoke-2026-05-XX-sprint-04.md`)
- [ ] `/scope-check` clean — no IDs added beyond the 16 listed
- [ ] `production/sprint-status.yaml` updated by `/story-done` invocations
- [ ] `production/session-state/active.md` close-out section appended

## QA Plan Status
**Not yet written.** Run `/qa-plan sprint` immediately after this plan is written, before any `/dev-story` invocation.

## Implementation Order (intra-epic dependency-respecting)

Stealth AI chain (must be sequential — each builds on the previous):
1. SAI-001 (scaffold) → 2. SAI-002 (enums + signals) → 3. SAI-003 (DI + cache)
→ 4. SAI-004 (F.1 sight) → 5. SAI-005 (F.5 thresholds + escalation)
→ 6. SAI-007 (F.3 decay — moved before SAI-006 since patrol consumes decay)
→ 7. SAI-006 (patrol + investigate) → 8. SAI-008 (audio subscriber)
→ 9. SAI-009 (forbidden fences) → 10. SAI-010 (perf + integration)

Input chain (mostly independent of SAI; can run in parallel sub-loops):
11. IN-003 (context routing) → 12. IN-005 (edge-case — depends on IN-003)
→ 13. IN-004 (anti-pattern CI — independent)
→ 14. IN-006 (runtime rebinding — independent)
→ 15. IN-007 (LOADING gate — depends on IN-005's mouse-mode restore behavior)

Player Character (independent):
16. PC-006 (health) — can run any time after PC-005 ✅

## Reference Documents
- `production/sprints/multi-sprint-roadmap-pre-art.md` — Sprint 04 source
- `production/sprints/sprint-03-visual-signature.md` — predecessor (closed)
- `production/qa/qa-signoff-sprint-03-2026-05-01.md` — Sprint 03 sign-off (APPROVED WITH CONDITIONS)
- `production/epics/stealth-ai/EPIC.md` — epic governance
- `production/epics/input/EPIC.md` — epic governance
- `design/gdd/stealth-ai.md` — F.1/F.2/F.3/F.4/F.5 formulas authoritative
- `design/gdd/input.md` — context-stack discipline
- `design/gdd/player-character.md` — health system spec
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — signal/enum ownership
- `docs/architecture/adr-0006-collision-layer-contract.md` — LAYER_NPCS / LAYER_PERCEPTION
- `docs/architecture/adr-0007-autoload-load-order-registry.md` — InputContext line 4
- `docs/architecture/adr-0008-performance-budget-distribution.md` — stealth-AI sub-budget
- `production/registry/tech-debt.yaml` — TD-001..TD-007 register

> **Scope check note**: This sprint adds zero stories beyond the roadmap's
> commitment. Run `/scope-check sprint-04` at sprint close to confirm no
> creep occurred during execution.
