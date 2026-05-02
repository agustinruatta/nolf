# Sprint Bootstrap Prompts — Pre-Art Roadmap

**Purpose:** start a fresh `claude` session per sprint and paste the matching bootstrap prompt below. Each prompt is self-contained — it tells the agent to read the roadmap, plan the sprint formally, and execute it autonomously until a stop condition is hit.

**How to use:**
1. `cd ~/Projects/Claude-Code-Game-Studios && claude` (start fresh session)
2. Confirm auto mode is active (you can paste the line `Auto mode: continuous, autonomous execution. Stop only on the explicit stop conditions in the roadmap.` to set tone)
3. Paste the bootstrap prompt for the sprint you want to run
4. Walk away; come back when the agent stops

The agent will stop at any condition listed in `production/sprints/multi-sprint-roadmap-pre-art.md` Section *"Stop Conditions Across All Sprints"*.

---

## Sprint 04 — Stealth AI Foundation

```
Execute Sprint 04 per the multi-sprint roadmap.

Read first (in order):
1. production/sprints/multi-sprint-roadmap-pre-art.md — Sprint 04 section + Stop Conditions section
2. production/session-state/active.md — recover context
3. production/epics/stealth-ai/EPIC.md and all 10 story files
4. production/epics/input/EPIC.md (focus on INP-001/002/004/005/006)
5. production/epics/player-character/story-006-health-system.md
6. design/gdd/stealth-ai.md, design/gdd/input.md, design/gdd/player-character.md

Then:
1. Run /sprint-plan to formalize Sprint 04 as production/sprints/sprint-04-stealth-ai-foundation.md (use the roadmap's story list verbatim — no scope additions)
2. Run /qa-plan sprint for Sprint 04
3. For each story in Ready status: run /story-readiness, /dev-story, /code-review, /story-done — in that order
4. After all stories complete: /smoke-check, then update production/session-state/active.md with the sprint close-out
5. Run /scope-check at sprint close — flag any drift

STOP IMMEDIATELY (do not work around) on any stop condition from the roadmap. Surface the blocker in active.md and end the session.

Do not commit anything — commits are user-driven per CLAUDE.md collaboration protocol.
```

---

## Sprint 05 — Mission Loop & Persistence

```
Execute Sprint 05 per the multi-sprint roadmap.

Pre-flight: confirm Sprint 04 is closed (active.md shows "Sprint 04 close-out"). If not, STOP and surface the gap.

Read first (in order):
1. production/sprints/multi-sprint-roadmap-pre-art.md — Sprint 05 section + Stop Conditions
2. production/session-state/active.md
3. production/epics/save-load/EPIC.md (focus SL-002, SL-003, SL-006, SL-007, SL-009)
4. production/epics/failure-respawn/EPIC.md (all 6 stories)
5. production/epics/mission-level-scripting/EPIC.md (all 5 stories)
6. design/gdd/save-load.md, design/gdd/failure-respawn.md, design/gdd/mission-level-scripting.md
7. docs/architecture/adr-0007-*.md (mission/failure ordering amendment)

Then:
1. /sprint-plan → production/sprints/sprint-05-mission-loop-persistence.md
2. /qa-plan sprint
3. Per-story loop: /story-readiness, /dev-story, /code-review, /story-done
4. /smoke-check, update active.md, /scope-check

STOP on any roadmap stop condition. No commits.
```

---

## Sprint 06 — UI Shell (HUD + Settings)

```
Execute Sprint 06 per the multi-sprint roadmap.

Pre-flight: confirm Sprint 05 closed. If not, STOP.

Read first (in order):
1. production/sprints/multi-sprint-roadmap-pre-art.md — Sprint 06 section + Stop Conditions (NOTE the HARD stop on ADR-0004)
2. production/session-state/active.md
3. production/epics/hud-core/EPIC.md (all 6)
4. production/epics/hud-state-signaling/EPIC.md (all 3)
5. production/epics/settings-accessibility/EPIC.md (5 ready, 1 ADR-0004-blocked — DO NOT attempt the blocked story)
6. production/epics/localization-scaffold/EPIC.md (LOC-001, LOC-003, LOC-004, LOC-005)
7. design/art/art-bible.md §7 (HUD specs) and §7E (open questions — surface visual sign-off requests for Restaurant + Bomb Chamber contrast)
8. design/gdd/hud-core.md, design/gdd/hud-state-signaling.md, design/gdd/settings-accessibility.md, design/gdd/localization-scaffold.md

Then:
1. /sprint-plan → production/sprints/sprint-06-ui-shell.md
2. /qa-plan sprint
3. Per-story loop
4. /smoke-check, update active.md, /scope-check
5. **Mandatory ADR-0004 status report at sprint close** — write to active.md the current state of ADR-0004 gates and which 9 stories remain blocked. This is a stop-and-surface.

STOP on any roadmap stop condition. No commits.
```

---

## Sprint 07 — Audio Body & Document Logic

```
Execute Sprint 07 per the multi-sprint roadmap.

Pre-flight: confirm Sprint 06 closed. If not, STOP.

Read first (in order):
1. production/sprints/multi-sprint-roadmap-pre-art.md — Sprint 07 section + Stop Conditions
2. production/session-state/active.md
3. production/epics/audio/EPIC.md (AUD-003, AUD-004, AUD-005 only — VO-dependent stories DEFERRED)
4. production/epics/document-collection/EPIC.md (all 5 stories — overlay UI is a separate epic, do NOT pull it)
5. production/epics/post-process-stack/EPIC.md (PPS-003, PPS-005, PPS-006, PPS-007)
6. design/gdd/audio.md, design/gdd/document-collection.md, design/gdd/post-process-stack.md
7. docs/architecture/adr-0008-*.md (perf budgets), Godot 4.6 glow rework note in docs/engine-reference/godot/VERSION.md

Then:
1. /sprint-plan → production/sprints/sprint-07-audio-document-logic.md
2. /qa-plan sprint
3. Per-story loop
4. /smoke-check, update active.md, /scope-check

STOP on any roadmap stop condition. Specifically: if alert-tier music stems are missing, ship logic with placeholder one-shots and surface the audio-asset commission request in active.md. No commits.
```

---

## Sprint 08 — Level Streaming Body & Integration Hardening

```
Execute Sprint 08 per the multi-sprint roadmap. THIS CLOSES THE PRE-ART ROADMAP.

Pre-flight: confirm Sprint 07 closed. If not, STOP.

Read first (in order):
1. production/sprints/multi-sprint-roadmap-pre-art.md — Sprint 08 section AND the "Post-Roadmap Sprint Preview" section
2. production/session-state/active.md
3. production/epics/level-streaming/EPIC.md (LS-001, LS-004, LS-005, LS-006, LS-009, LS-010)
4. tests/regression-suite.md (will run /regression-suite at sprint close)
5. design/gdd/level-streaming.md

Then:
1. /sprint-plan → production/sprints/sprint-08-level-streaming-integration.md
2. /qa-plan sprint
3. Per-story loop for the 6 LS stories
4. Spillover absorption: if any Sprint 04–07 story did not close, finish it here (within the buffer)
5. /smoke-check across the full pipeline (patrol → perceive → evade → collect doc → alert → fail → respawn → save/load → section transition)
6. /regression-suite — verify coverage of every GDD critical path
7. Update active.md with the **art-integration-ready** declaration: list every code-ready story closed, every art dependency surfaced, every ADR-0004-blocked story
8. **Mandatory hand-off package at sprint close**: write production/sprints/art-integration-handoff.md — list of `.glb` deliverables required for hero-asset sprint (Eve FPS hands, Eve full body, PHANTOM grunt + helmet variants, Eiffel bay modules at 3 altitude tiers, Plaza props per art bible §6, bomb device hero prop). Reference art bible §8B naming conventions and §8D triangle budgets. This is the user's commission spec.
9. Run /asset-spec for the hero asset list above (reference design/art/art-bible.md as source) — produces per-asset spec sheets for outsourcing/AI 3D pipelines.

STOP at sprint close — the next sprint requires user action (commission art OR start art-integration sprint with placeholder/AI-3D assets).
```

---

## Failure-Mode Recovery

If a sprint stops mid-execution due to a blocker, the user should:
1. Read `production/session-state/active.md` for the surfaced blocker
2. Resolve it (answer the question, run the test, decide the scope, etc.)
3. Start a new session and paste the *same* bootstrap prompt for that sprint — the agent will re-read state and resume from the next pending story

If a sprint surfaces an ADR amendment, do NOT auto-amend. Run `/architecture-decision` in a focused session, get user sign-off, then resume the sprint.
