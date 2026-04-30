# Project Stage Analysis

**Date**: 2026-04-30
**Stage**: Pre-Production (per `production/stage.txt`)
**Stage Confidence**: PASS — clearly detected
**Reviewer**: `/project-stage-detect`

---

## Summary

Sprint 01 (Technical Verification Spike) closed 2026-05-01 with all groups Done.
Pre-Production → Production gate-check returned **FAIL** as expected — no
Vertical Slice exists yet. Project is positioned to begin Sprint 02 (Vertical
Slice production sprint).

User direction set in this report: VS must exercise **all/almost all** systems
in the GDD library. Only systems that would harm the chosen scene's design fit
may be deferred (see Risks).

---

## Completeness Overview

| Domain | Status | Detail |
|---|---|---|
| Design | 95% | 30 GDDs (all MVP systems) + 15 UX specs + Art Bible + game concept + accessibility requirements |
| Architecture | 90% | 8 ADRs (6 Accepted, 2 Proposed with deferrals) + master architecture + control manifest + TR registry |
| Production | 85% | 7 epics, 31 stories ready (Foundation), session state actively maintained |
| Code | 15% | 11 GDScript scaffolds from Sprint 01 prototypes |
| Tests | 5% | 2 test files; GUT framework not scaffolded |

---

## What's Ready

### Design
- 30 GDDs in `design/gdd/` — all MVP systems specified
- Art Bible at `design/art/art-bible.md` — 9 sections; explicitly references NOLF 1 lighting and color philosophy
- 15 UX specs in `design/ux/`
- Game concept with 5 pillars + anti-pillars; NOLF 1 named as spiritual reference
- Accessibility requirements committed

### Architecture
- `docs/architecture/architecture.md` — master architecture
- 8 ADRs: 6 Accepted (0001, 0002, 0003, 0005, 0006, 0007); 2 Proposed with documented deferrals (0004, 0008)
- `docs/architecture/control-manifest.md` — Manifest Version 2026-04-30
- `docs/architecture/tr-registry.yaml` — TR-ID → ADR coverage map
- 4 architecture review sessions logged (04-22, 04-23, 04-29, 04-30)

### Production
- 7 epics across Foundation + Core layers
- **Foundation (4 epics, 31 stories ready)**: signal-bus (7), save-load (9), localization-scaffold (5), level-streaming (10)
- **Core (3 epics, no stories yet)**: input, player-character, footstep-component
- Sprint 01 closed; Sprint 02 staged

### Verification Spike Outcome
- Verification log at `prototypes/verification-spike/verification-log.md`
- Findings F1–F6 folded into ADR amendments
- ADR-0005 promoted to Accepted via user visual sign-off (2026-05-01)

---

## Gaps Identified

### Production-Gate Blockers (deliberate — Sprint 02 closes these)

1. **No Vertical Slice build** — only Sprint 01 prototypes exist
2. **No playtest data** — Production gate requires ≥3 sessions; impossible without playable VS
3. **Character visual profiles** missing in `design/art/visual-design/` (Eve, Plaza guard, etc.)
4. **AD-ART-BIBLE sign-off** skipped in lean mode — should run `/design-review design/art/art-bible.md` if Production gate is contested

### Sprint 02 Pre-Work Gaps (must address before `/dev-story` loop)

5. **Test infrastructure** — only 2 test files; GUT framework not scaffolded.
   First scheduled dev-story is `signal-bus/story-001-events-autoload-structural` (Logic type) — automated unit test is BLOCKING gate per coding standards.
   **Action: `/test-setup` BEFORE first `/dev-story`.**

6. **Feature Layer epics not created** — VS needs:
   - `stealth-ai` (one guard, basic patrol + alert)
   - `document-collection` (one document)
   - `mission-level-scripting` (mission start/win/end logic)
   - `failure-respawn` (caught-by-guard outcome)

7. **Presentation Layer epics not created** — VS needs:
   - `hud-core` (interaction prompts)
   - `hud-state-signaling` (suspicion/detection feedback)
   - `document-overlay-ui` (read picked-up document)
   - `menu-system` (pause/quit/save mid-mission)
   - `outline-pipeline` + `post-process-stack` (integration of Sprint 01 prototype)
   - `audio` (basic SFX/ambient — validates pipeline)
   - `cutscenes-and-mission-cards` (opening mission card)
   - `dialogue-subtitles` (one VO line at intro to validate pipeline)
   - `settings-accessibility` (stubs validate the system without polish)

8. **Stories not yet broken down** for Core epics + all new Feature/Presentation epics

9. **Character visual profiles** — Eve (FPS hands; ADR-0005 Accepted) + Plaza guard (silhouette critical for stealth readability) need design before/during Sprint 02. Discussion pending on NOLF 1 style alignment check.

---

## Vertical Slice Scope — Revised

The session state's narrowed scope (Feature: stealth-ai + document-collection only) **undershoots** the VS goal of "100% systems depth." Per user direction (2026-04-30), VS must validate **all/almost all** systems; exclude only when a system would harm the chosen scene's design fit.

### VS-Included (validates the system at minimum depth)

- **Foundation (4)**: signal-bus, save-load, localization-scaffold, level-streaming
- **Core (3)**: input, player-character, footstep-component
- **Feature (4)**: stealth-ai, document-collection, mission-level-scripting, failure-respawn
- **Presentation (10)**: hud-core, hud-state-signaling, document-overlay-ui, menu-system, outline-pipeline, post-process-stack, audio (basic), cutscenes-and-mission-cards, dialogue-subtitles (1 VO line), settings-accessibility (stubs)

**Total: 21 of 24 systems** exercised at minimum depth.

### VS-Deferred (would harm Plaza-opening design fit)

- **civilian-ai** — Plaza opening is a quiet infiltration; civilians clutter the read and dilute stealth tension. Re-evaluate for second mission section.
- **combat-damage** — stealth tone; failure-respawn covers caught-by-guard without combat. Combat introduction belongs to a later mission beat.
- **inventory-gadgets** — gadgets are typically introduced after the player demonstrates baseline stealth competence. Adding gadgets to opening dilutes tutorialization.

These three are deferred to post-VS sprints. **Open to user override** if the chosen Plaza scenario justifies any of them.

---

## Recommended Next Steps (in order)

1. ✅ This report
2. **`/test-setup`** — scaffold GUT framework + CI config (BLOCKING for first dev-story)
3. **`/create-epics layer: feature`** — VS-needed: stealth-ai, document-collection, mission-level-scripting, failure-respawn
4. **`/create-epics layer: presentation`** — VS-needed: hud-core, hud-state-signaling, document-overlay-ui, menu-system, outline-pipeline integration, post-process-stack integration, audio, cutscenes-and-mission-cards, dialogue-subtitles, settings-accessibility
5. **`/create-stories`** for: input, player-character, footstep-component, then all new Feature + Presentation epics (VS-narrowed scope)
6. **Asset / character design discussion** — verify NOLF 1 style alignment against existing art-bible references, then `/asset-spec` for Eve + Plaza guard (parallel workstream)
7. **`/sprint-plan`** — Sprint 02 with full backlog visibility
8. **`/dev-story production/epics/signal-bus/story-001-events-autoload-structural.md`** — first story, lowest dependency

---

## Risks

- **Sprint 02 capacity**: broadened VS scope grows backlog from ~31 to likely 80–120 stories. The 3–4 week estimate from session state was based on the narrower scope and is now optimistic. Sprint 02 may need a split (02a Foundation+Core, 02b Feature+Presentation+Polish) or further VS scope trim. Surface in `/sprint-plan`.
- **Architecture re-review**: ADR-0005 freshly Accepted; ADR-0004 + ADR-0008 still Proposed. `/architecture-review` should re-run before VS code touches outline rendering or runtime accessibility paths.
- **Art Bible sign-off**: skipped in lean mode. Worth a `/design-review design/art/art-bible.md` pass before character profiles are authored, to formally confirm NOLF 1 reference is captured for asset producers.

---

*Generated by `/project-stage-detect` — supersedes any earlier stage analysis.*
