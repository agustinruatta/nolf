# Multi-Sprint Roadmap — Pre-Art Integration

**Created:** 2026-05-02
**Goal:** drive the project from Sprint 03 close-out (visual signature on proxy geometry) to **art-integration-ready state** — every system implemented, tested, and proven against placeholder/proxy assets, so that when final `.glb` art lands the integration is a swap, not new code.
**Stop gate:** art assets become the critical-path blocker. After this roadmap completes the project is *waiting on Eve / PHANTOM grunt / Eiffel bay modules / period props* and a "first slice with final look" sprint becomes feasible.

---

## Inventory (as of 2026-05-02)

- **62 code-ready stories** (no art dependency) across 21 epics
- **62 art-blocked stories** — defer to post-art sprints
- **9 ADR-0004 blocked stories** (4 Document-Overlay-UI, 4 Menu-System, 1 Settings-Accessibility) — not art-blocked but blocked on accessibility ADR closure; surfaces as a stop in this roadmap
- **Sprint 03 close-out items pending user**: OUT-005 visual sign-off screenshot, "looks like the game" reel screenshot

---

## Sprint Roadmap

### Sprint 04 — Stealth AI Foundation
**Theme:** *the level becomes alive — guards perceive, suspect, search, alert, and reset.*

**Story load:**
- Stealth AI: 10 stories (perception cone + cache, suspicion meter, state machine, patrol routes, alert propagation, reset, NPC factory, signal wiring, perf budget, save/load hooks)
- Input remaining ready: INP-001, 002, 004, 005, 006 (5 stories) — needed to actually drive a player past the AI for testing
- Player Character PC-006: health system (logic-only — pairs with stealth alert + damage)

**Deliverable:** a placeholder capsule guard patrols the Plaza VS scene, perceives the player capsule, escalates suspicion through documented tiers, and resets. Save-load round-trips guard state.

**Stop conditions:**
- Stealth AI signal-architecture decision required (escalate to godot-specialist if ambiguity)
- Visual signoff if alert-state debug UI is added

**Estimated effort:** ~4–5 days agent-time (16 stories, mostly logic)

---

### Sprint 05 — Mission Loop & Persistence
**Theme:** *failure has consequences and progress survives.*

**Story load:**
- Save/Load remaining ready: SL-002, SL-003, SL-006, SL-007, SL-009 (5 stories — quicksave/quickload, autosave triggers, slot rotation, error recovery, manifest forward-compat)
- Failure & Respawn: 6 stories (death detection, respawn point selection, state restore, scripted failure conditions, queue interaction with save, level-streaming integration)
- Mission & Level Scripting: 5 stories (objective state machine, trigger volumes, objective signals, mission-card hooks, save/load integration)

**Deliverable:** death → respawn → objective state preserved → quicksave/quickload round-trips through a level transition. Mission objective triggers fire via scripted volumes.

**Stop conditions:**
- ADR-0007 amendment if mission-vs-failure ordering becomes ambiguous (already amended once — re-check)
- Manifest-version bump decision for save format

**Estimated effort:** ~4 days agent-time (16 stories, all logic)

---

### Sprint 06 — UI Shell (HUD + Settings)
**Theme:** *the screen reads as final on placeholder geometry — health, ammo, alert cue, settings menu, photosensitivity gate.*

**Story load:**
- HUD Core: 6 stories (root canvas, health/ammo readouts, interaction prompt, alert cue slot, contextual strip, save/load hook)
- HUD State Signaling: 3 stories (alert-cue logic, transition rules, signal subscriber)
- Settings & Accessibility: **5 ready stories only** (1 blocked on ADR-0004) — Day-1 HARD MVP slice (photosensitivity opt-out + captions-on default + master volume + remap surface + persistence)
- Localization-scaffold remaining ready: LOC-001, 003, 004, 005 (4 stories)

**Deliverable:** running the Plaza VS demo shows real HUD with placeholder numerals, alert cue responds to Sprint-04 stealth state, settings menu round-trips photosensitivity + master volume.

**Stop conditions (HARD):**
- **ADR-0004 closure required for Document-Overlay-UI, Menu-System, and the 6th Settings story.** This roadmap explicitly defers those 9 stories to a later sprint. **Surface ADR-0004 status to user at sprint close.**
- Visual sign-off on HUD field opacity (85% per art bible §7E open question — Restaurant + Bomb Chamber contrast unverified)

**Estimated effort:** ~4 days agent-time (18 stories)

---

### Sprint 07 — Audio Body & Document Logic
**Theme:** *audio carries the alert state, documents are collectible (logic only — overlay UI deferred).*

**Story load:**
- Audio remaining ready: AUD-003, AUD-004, AUD-005 (3 stories — alert-tier music ducking, stinger system, mix-bus routing) — **VO-dependent stories deferred to post-VO**
- Document Collection: 5 stories (interactable document body, pickup state machine, manifest persistence, signal wiring, save/load hook) — **overlay UI is its own epic and ADR-0004-blocked**
- Player Character PC-006 if not landed in Sprint 04: pull forward
- Post-Process Stack remaining ready: PPS-003, PPS-005, PPS-006, PPS-007 (4 stories — composition order, glow chain, sepia-dim handshake stub, environment chain)

**Deliverable:** alert music tier shifts on Sprint-04 stealth-state transitions, documents pick up and persist to save, post-process chain composes correctly with the outline pipeline.

**Stop conditions:**
- Audio asset dependency: alert-tier music stems may not exist — surface to user (deferral acceptable; logic ships with placeholder one-shot)
- Glow rework verification gate (ADR-0008 has a 4.6 glow compatibility note — re-verify against engine reference if PPS-005 surfaces issues)

**Estimated effort:** ~3.5 days agent-time (12 stories)

---

### Sprint 08 — Level Streaming Body & Integration Hardening
**Theme:** *seamless section transitions across the full pipeline — close out every code-ready epic.*

**Story load:**
- Level Streaming remaining ready: LS-001, LS-004, LS-005, LS-006, LS-009, LS-010 (6 stories — performance budget P90 measurement, error fallback, anti-pattern lint guards, focus-loss cache mode, queue-during-transition, registry failure recovery)
- Footstep Component: already 4/4 complete — verify integration
- Outline Pipeline: already 5/5 complete — re-verify against any new geometry produced during sprints 04–07
- Smoke check + regression suite expansion across all sprints 04–07 outputs
- Scope buffer for spillover from Sprint 04–07

**Deliverable:** the Plaza VS demo plays the full mission loop on proxy art — patrol, perceive, evade, collect document, alert, fail, respawn, save/load — with no smoke-check regressions. **Project is now art-integration-ready.**

**Stop conditions (HARD — sprint complete = roadmap complete):**
- All 62 code-ready stories implemented and tested
- Smoke check passes
- Regression suite green
- **Surface to user: art-asset commission package needed** — list of `.glb` deliverables required for hero-asset sprint (Eve FPS hands, Eve full body, PHANTOM grunt + variants, Eiffel bay modules, Plaza props)

**Estimated effort:** ~3 days agent-time (6 stories + integration)

---

## Stop Conditions Across All Sprints

The autonomous executor MUST stop and surface to user on any of the following:

1. **ADR ambiguity or amendment required** — do not amend ADRs without user review
2. **Scope drift** — `/scope-check` flags creep beyond the sprint's listed story IDs
3. **Visual sign-off needed** — any task where the acceptance criterion includes "user visual confirmation" or "screenshot diff sign-off"
4. **Art asset surfaces as a hard blocker** — story cannot ship without a `.glb` mesh, animation rig, VO line, or final texture
5. **ADR-0004 status requires action** — at Sprint 06 close, surface ADR-0004 closure status to unblock Document-Overlay-UI / Menu-System / 1 Settings story
6. **Test failure or regression** — smoke check fails, suite regresses; do not patch by skipping tests
7. **Cross-sprint dependency emerges** — if a Sprint 04 decision invalidates Sprint 06 plan, stop and re-plan the affected sprint
8. **Tech-debt register grows beyond 12 items** — current TD-001..TD-007; if a sprint pushes the register past 12, pause for triage

## Hand-off Protocol Between Sprints

After each sprint, the executor (whether scheduled remote agent or live session) must:

1. Run `/story-done` for every implemented story
2. Run `/smoke-check` and confirm pass
3. Run `/sprint-plan` for the next sprint (refining this roadmap into the formal sprint file at `production/sprints/sprint-NN-*.md`)
4. Update `production/session-state/active.md` with sprint close-out summary
5. Update `production/sprint-status.yaml`
6. **Do NOT auto-commit.** All commits remain user-driven per project collaboration protocol.

## Post-Roadmap Sprint Preview (out of scope, for context only)

After Sprint 08 closes:
- **Sprint 09** — Asset spec authoring (`/asset-spec` for hero set), pause for art commission
- **Sprint 10+** — Art integration as `.glb` files arrive: Eve FPS hands first (unblocks ADR-0005 G4), then PHANTOM grunt, then Plaza environment kit
- **Sprint ~12** — "First slice with final look" — Plaza section playable end-to-end with final art, lighting, and HUD. This is the milestone the user's question targeted.
