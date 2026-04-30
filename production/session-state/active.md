# Session State

**Last updated:** 2026-04-30 — Sprint 02 pre-work **complete**. 21 epics with 130 stories ready, scope broadened beyond original session-state plan to "test all systems in VS" per user direction. Test harness (GdUnit4) verified working with one local patch. Next step: **`/sprint-plan`** to generate Sprint 02 (Vertical Slice production sprint).

## Next Action — START HERE

Run **`/sprint-plan`** — it should:
- Read `production/epics/index.md` (21 epics, 130 stories) for full backlog visibility
- Pull dependency information from each epic's `Stories` table
- Surface the cross-epic open questions (see "Known Cross-Epic Open Questions" below)
- Propose a Sprint 02 scope and ordering based on dependency-safe layer order: Foundation → Core → Feature → Presentation → Polish
- Solo mode is configured (`production/review-mode.txt`) — gates that require team-of-3 sign-off are skipped

After `/sprint-plan` lands, the natural next step is `/dev-story production/epics/signal-bus/story-001-events-autoload-structural.md` (the dependency-lowest story).

## Current Stage

**Pre-Production** (per `production/stage.txt`). Gate to Production still requires the Vertical Slice build + ≥3 playtests + playtest report. Sprint 02 is the vehicle that closes those.

## What's Ready (the asset base for Sprint 02)

### Epics + Stories — 21 epics, 130 stories total

See `production/epics/index.md` for the full table. Per-layer summary:

- **Foundation (7 epics, 47 stories)**: signal-bus (6) + save-load (9) + localization-scaffold (5) + level-streaming (10) + audio (5) + outline-pipeline (5) + post-process-stack (7).
- **Core (3 epics, 19 stories)**: input (7) + player-character (8) + footstep-component (4).
- **Feature (5 epics, 31 stories)**: stealth-ai (10) + document-collection (5) + mission-level-scripting (5) + failure-respawn (6) + dialogue-subtitles (5).
- **Presentation (5 epics, 27 stories)**: hud-core (6) + hud-state-signaling (3) + document-overlay-ui (5) + menu-system (8) + cutscenes-and-mission-cards (5).
- **Polish (1 epic, 6 stories)**: settings-accessibility (Day-1 HARD MVP slice + VS expansion).

**Deferred post-VS** (do not include in Sprint 02): combat-damage, inventory-gadgets, civilian-ai. Plaza-opening scene doesn't justify these without harming the design fit.

### ADR Status
- ✅ Accepted: ADR-0001, 0002, 0003, 0005 (flipped 2026-05-01 via fps_hands_demo sign-off), 0006, 0007.
- ⏸️ Proposed (with documented deferrals — won't auto-block stories citing them): ADR-0004 (G3/G4/G5 deferred to runtime AT testing post-MVP); ADR-0008 (Restaurant + Iris Xe hardware measurement deferred to first Production sprint shipping outline-bearing scene).

### Test Harness
- GdUnit4 v6.0.0 installed at `addons/gdUnit4/`, plugin enabled in `project.godot`.
- 1-line compatibility patch applied at `addons/gdUnit4/src/core/GdUnitFileAccess.gd:199` (Godot 4.6.2 dropped the `skip_cr` arg from `FileAccess.get_as_text`). Documented in `tests/README.md`.
- Verified: `godot -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/unit -a tests/integration` runs the Sprint 01 signal_bus_smoke_test, 6/6 PASS, exit 0.
- Stub `tests/gdunit4_runner.gd` removed — official CLI is the canonical entry point.
- `reports/` (GdUnit4 local artefact dir) added to `.gitignore`.

### Visual / Asset Direction
- NOLF 1 alignment brief at `production/notes/nolf1-style-alignment-brief.md` — synthesises existing references, surfaces 5 gaps that `/asset-spec` will need to resolve.
- Visual reference scene at `prototypes/visual_reference/plaza_visual_reference.tscn` (placeholder primitives, NOLF1 palette + outline shader). Scene is **parked** — user defers visual iteration to post-VS / specialist agents (per memory `feedback_artistic_decisions`).

### Architecture Artefacts (unchanged from Sprint 01 close)
- `docs/architecture/architecture.md` — master architecture
- `docs/architecture/control-manifest.md` — Manifest Version 2026-04-30 (Foundation + Core layer rules)
- `docs/architecture/tr-registry.yaml` — TR-ID → ADR coverage map
- `docs/registry/architecture.yaml` — forbidden-pattern registry

## Known Cross-Epic Open Questions (`/sprint-plan` should surface these)

Story breakdown agents flagged these dependencies as needing pre-Sprint-02 resolution OR ordered into Sprint 02 with the dependency-receiver story marked BLOCKED until upstream lands:

1. **HUD Core ↔ HSS handshake**: HSS Story 001 needs HUD Core's `register_resolver_extension` / `unregister_resolver_extension` APIs. Order HUD Core 001-002 before HSS 001.
2. **Settings ↔ HSS Day-1**: HSS Day-1 alert-cue needs `hud_alert_cue_enabled` toggle in Settings. Settings story 001 may need amendment, OR HSS 002 falls back to default-true.
3. **Document Collection ↔ MLS**: DC Story 005 (Plaza tutorial integration) depends on MLS GDD §C.5 amendment (Plaza `&"critical_path"` spline + `Section/Systems/DocumentCollection` node placement) and Localization Scaffold registering `ui.interact.pocket_document` key. Sequence: localization-scaffold story → MLS story 003 (Plaza section authoring) → DC 005.
4. **MLS ↔ F&R**: OQ-MLS-2 — F&R dying-state save must capture `MissionState.triggers_fired`. Coordinate the F&R 002 + MLS 004 implementations.
5. **ADR-0004 Proposed Gates**: Settings Story 005 (panel UI) is BLOCKED on ADR-0004 G1 + G5 (AccessKit Label live-region, BBCode body). Defer Story 005 implementation to post-VS unless the gates close mid-sprint. D&S Story 004 has a related `accessibility_live` open question (VG-DS-2).
6. **ADR-0006 Triggers-layer amendment**: MLS Story 005 currently uses `MASK_PLAYER` placeholder pending the amendment. Either resolve the ADR amendment now or accept the placeholder and revisit.
7. **Outline Pipeline `RenderingServer.get_video_adapter_type()`**: Story 004 (resolution-scale kernel) needs API verification against `docs/engine-reference/godot/modules/rendering.md` before pickup.
8. **Post-Process Stack — 4.6 glow rework + tonemapper constant**: Stories 002 + 005 have OQ items pending the 4.6 glow path verification. Likely first thing to address in Sprint 02.

`/sprint-plan` should treat these as ordering constraints (most are dependency edges, not blockers).

## Recently Completed (this session, 2026-04-30)

- 17 epics created across Feature, Presentation, Foundation top-up, and Polish layers (`/create-epics`)
- 99 stories authored across those 17 epics (`/create-stories`) — 5 incomplete batches finished via continuation agents
- `production/project-stage-report.md` written (Pre-Production → Production gap analysis)
- `production/notes/nolf1-style-alignment-brief.md` written (NOLF 1 reference synthesis + 5 asset-spec gaps)
- `prototypes/visual_reference/plaza_visual_reference.tscn` built (NOLF 1 palette + outline shader, parked for post-VS iteration)
- GdUnit4 install verified, 1-line patch applied, stub runner deleted, `reports/` gitignored
- Memory: `feedback_artistic_decisions` saved (user defers art-direction to specialists)

## Files Modified This Session (2026-04-30)

- `production/project-stage-report.md` (created)
- `production/notes/nolf1-style-alignment-brief.md` (created)
- `production/epics/index.md` (Feature, Presentation, Polish, Foundation top-up entries added; story counts populated)
- `production/epics/{audio,outline-pipeline,post-process-stack,input,player-character,footstep-component,stealth-ai,document-collection,mission-level-scripting,failure-respawn,dialogue-subtitles,hud-core,hud-state-signaling,document-overlay-ui,menu-system,cutscenes-and-mission-cards,settings-accessibility}/EPIC.md` (created with VS scope guidance) — 17 new epic files
- `production/epics/[same 17]/story-NNN-*.md` — 99 new story files
- `addons/gdUnit4/src/core/GdUnitFileAccess.gd` (1-line 4.6.2 compat patch at line 199)
- `tests/README.md` (CLI form updated, patch documented, stub-removed note)
- `tests/gdunit4_runner.gd` + `.uid` (deleted)
- `.gitignore` (added `reports/`)
- `prototypes/visual_reference/{README.md, plaza_visual_reference.gd, plaza_visual_reference.tscn}` (created)
- `production/session-state/active.md` (this file)

## How to Resume

1. New session reads this file (auto-loaded by `session-start.sh` hook)
2. Run `/sprint-plan` — pulls epic + story metadata to propose Sprint 02 scope
3. Discuss ordering with the planning skill, especially the 8 cross-epic open questions above
4. Approve plan, then begin `/dev-story` loop on signal-bus story-001
