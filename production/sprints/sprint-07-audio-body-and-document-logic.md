# Sprint 07 — Audio Body & Document Logic

**Dates**: 2026-05-03 to 2026-05-09 (7 calendar days; autonomous-execution sprint)
**Generated**: 2026-05-03
**Mode**: solo review (per `production/review-mode.txt`)
**Source roadmap**: `production/sprints/multi-sprint-roadmap-pre-art.md` Sprint 07 section (lines 75–90)
**Roadmap status**: `production/sprint-roadmap-status.yaml` sprint #7

## Sprint Goal

**Audio carries the alert state, documents are collectible (logic only — overlay UI deferred), post-process chain composes correctly under the outline pipeline.**

Sprint 04 made the level alive (perception → suspicion). Sprint 05 made it durable
(death → respawn → save). Sprint 06 dressed it (HUD + Settings + LOC). Sprint 07
**writes the systemic body** behind those surfaces:

- **Audio body** — AUD-001/002 scaffolded the `AudioManager` autoload and signal
  subscription registry in earlier sprints. Sprint 07 lands the *behaviour*:
  Plaza ambient layer + UNAWARE/COMBAT music states + section reverb (AUD-003);
  VO ducking via Formula F.1 + document world-bus mute + respawn cut-to-silence
  (AUD-004); footstep variant routing + COMBAT stinger on `actor_became_alerted`
  (AUD-005).
- **Document Collection (logic only)** — `Document` Resource schema (DC-001),
  `DocumentBody` `StaticBody3D` interactable + Tier 1 outline (DC-002),
  `DocumentCollection` per-section node tree + pickup → pocket → emit lifecycle
  (DC-003), save/restore contract via `DocumentCollectionState` sub-resource
  (DC-004), Plaza tutorial document end-to-end integration (DC-005). The
  **Document Overlay UI** (full-screen reading modal + sepia-dim handshake) is
  **intentionally excluded** — it lives in the `document-overlay-ui` epic which
  is **ADR-0004-blocked** (G1 + G5 OPEN per Sprint 06 close-out).
- **Post-Process Stack tail** — Sepia-dim tween state machine logic-only
  (PPS-003 ships against a stubbed `SepiaDimEffect.set_dim_intensity()` API
  since PPS-002 compositor shader is overlay-UI tied); WorldEnvironment glow
  ban + forbidden-pattern enforcement (PPS-005); resolution-scale subscription
  + `Viewport.scaling_3d_scale` wiring (PPS-006); full-stack visual + perf
  verification gating ADR-0008 G3 (PPS-007).

By close, running the Plaza VS demo plays ambient music that crossfades to
COMBAT on guard alert, ducks for VO lines, mutes during document pickup, and
cuts to silence on player death; documents place into the scene, pick up via
raycast, persist through save/load, and the post-process chain composes
correctly with the outline pipeline. **No story in this sprint authors final
art** — Audio ships with placeholder `.ogg` stems where alert-tier music does
not yet exist; documents use placeholder typography per Sprint-06 HUD pattern.

This sprint brings us within **one sprint** of the **art-integration-ready
milestone** (end of Sprint 08). After Sprint 07, only Level Streaming hardening
+ regression-suite expansion remain (Sprint 08).

## Capacity

- Total agent-time: ~3.5 days work-equivalent (per roadmap `estimated_agent_days: 3.5`)
- Buffer (20%): 0.7 day reserved for alert-music asset gap escalation, ADR-0008
  G3 glow-rework re-verification (PPS-005/007), DC-005 Plaza section authoring
  permission re-check (filesystem permission constraint on `scenes/sections/`
  per Sprint 06 close-out), and Audio body integration friction with Sprint-04
  Stealth alert signals.
- Available: ~2.8 days for committed work
- Total committed estimate: **~28–34 hours of agent work** (12 stories,
  3 Logic + 3 Logic-DC + 1 Integration-DC + 1 Integration-Plaza + 1
  Logic-PPS + 1 Logic-PPS + 1 Logic-PPS + 1 Visual/Feel-PPS)

## Roadmap Reconciliation

The multi-sprint roadmap §Sprint 07 (lines 75–90) lists exactly the 12 stories
captured here:

- Audio: **AUD-003, AUD-004, AUD-005** (3 stories) — AUD-001/002 closed in
  earlier sprints; **VO-dependent stories deferred to post-VO** per roadmap
  line 79 (no VO assets in scope; DAS / dialogue-and-subtitles is a separate
  epic that has not yet shipped).
- Document Collection: **DC-001..DC-005** (5 stories) — overlay UI is its own
  epic and **ADR-0004-blocked** per roadmap line 80 (`document-overlay-ui`
  epic = 5 stories, all deferred until G1 + G5 close).
- Post-Process Stack: **PPS-003, PPS-005, PPS-006, PPS-007** (4 stories) per
  roadmap line 82. PPS-001 closed in earlier sprint. PPS-002 (sepia-dim
  compositor effect shader) and PPS-004 (document-overlay API integration)
  are **excluded** because they are overlay-UI tied (ADR-0004-blocked).
- **PC-006 NOT pulled forward** — already complete from Sprint 04 per roadmap
  line 81 and confirmed in `sprint-status.yaml` history. User instruction in
  bootstrap: "PC-006 is already Complete from Sprint 04 — do not pull forward."

Total Sprint 07 story count: **12**, matching the roadmap line 90 estimate.

> **Note**: This sprint contains 0 scope additions and 0 scope subtractions
> versus the original roadmap. Document for `/scope-check` at sprint close.

## Tasks

### Must Have — Audio Body (3)

| ID | Task | Agent/Owner | Est. (h) | Dependencies | Acceptance Criteria |
|----|------|-------------|----------|--------------|---------------------|
| AUD-003 | Plaza ambient layer + UNAWARE/COMBAT music states + section reverb | godot-gdscript-specialist + audio-director consult | 3–4 | AUD-001/002 ✅; Sprint-04 SAI alert signals ✅; placeholder `.ogg` stems acceptable | Per `production/epics/audio/story-003-plaza-ambient-music-states.md` ACs (TR-AUD-004/005/006/008/009/010) |
| AUD-004 | VO ducking (F.1) + document world-bus mute + respawn cut-to-silence | godot-gdscript-specialist | 2–3 | AUD-003; DC-003 (`document_opened/closed` signals must be defined — DC-003 lands them); F&R `respawn_triggered` ✅ | Per `production/epics/audio/story-004-vo-ducking-document-mute-respawn.md` ACs (TR-AUD-004/006/010) |
| AUD-005 | Footstep variant routing (marble) + COMBAT stinger on `actor_became_alerted` | godot-gdscript-specialist | 2–3 | AUD-003; FootstepComponent `footstep_emitted` ✅; SAI `actor_became_alerted` ✅ | Per `production/epics/audio/story-005-footstep-routing-combat-stinger.md` ACs (TR-AUD-007/011) |

### Must Have — Document Collection logic (5)

| ID | Task | Agent/Owner | Est. (h) | Dependencies | Acceptance Criteria |
|----|------|-------------|----------|--------------|---------------------|
| DC-001 | `Document` Resource schema + `DocumentCollectionState` sub-resource | godot-gdscript-specialist | 1–2 | ADR-0003 ✅; SaveGame umbrella ✅ | Per `production/epics/document-collection/story-001-document-resource-schema.md` ACs (TR-DC-002/009) |
| DC-002 | `DocumentBody` node — collision layer, stencil tier, interact priority | godot-gdscript-specialist | 2 | DC-001; ADR-0006 collision layers ✅; ADR-0001 stencil contract ✅; OUT-* outline pipeline ✅ | Per `production/epics/document-collection/story-002-document-body-node.md` ACs (TR-DC-003/004) |
| DC-003 | `DocumentCollection` node — subscribe/publish lifecycle + pickup handler | godot-gdscript-specialist | 2–3 | DC-001/002; ADR-0002 `document_*` signals freeze ✅; ADR-0007 NOT-autoload pattern ✅ | Per `production/epics/document-collection/story-003-document-collection-node.md` ACs (TR-DC-001/005/012/013/015) |
| DC-004 | Save/restore contract — `capture()`, `restore()`, spawn-gate | godot-gdscript-specialist | 2–3 | DC-001/003; SaveLoadService ✅; LSS register_restore_callback ✅ | Per `production/epics/document-collection/story-004-save-restore-contract.md` ACs (TR-DC-006/007/008/014) |
| DC-005 | Plaza tutorial document set — placement, locale keys, end-to-end integration | godot-gdscript-specialist | 2–3 | DC-001..004; LOC scaffold ✅; MLS Plaza section ✅; **`scenes/sections/` filesystem permission verified before pickup** | Per `production/epics/document-collection/story-005-plaza-tutorial-integration.md` ACs (TR-DC-010/011 partial) |

### Must Have — Post-Process Stack tail (4)

| ID | Task | Agent/Owner | Est. (h) | Dependencies | Acceptance Criteria |
|----|------|-------------|----------|--------------|---------------------|
| PPS-003 | Sepia-dim tween state machine (IDLE/FADING_IN/ACTIVE/FADING_OUT) — **logic against stubbed shader API** | godot-gdscript-specialist | 2–3 | PPS-001 ✅; **PPS-002 NOT in scope (overlay-UI tied)** — story-003 ships against a stubbed `SepiaDimEffect.set_dim_intensity()` interface, real shader lands in PPS-002 post-ADR-0004 | Per `production/epics/post-process-stack/story-003-sepia-dim-tween-state-machine.md` ACs minus shader-output assertions (TR-PP-002 fully; TR-PP-003 stubbed) |
| PPS-005 | WorldEnvironment glow ban + forbidden post-process enforcement | godot-gdscript-specialist | 2 | PPS-001 ✅; ADR-0005/0008 glow rework note re-verified against `docs/engine-reference/godot/` 4.6 docs | Per `production/epics/post-process-stack/story-005-glow-ban-enforcement.md` ACs (TR-PP-004/005/006) |
| PPS-006 | Resolution scale subscription + `Viewport.scaling_3d_scale` wiring | godot-gdscript-specialist | 2 | PPS-001 ✅; SettingsService ✅ (Sprint 06 SA-001..006 closed) | Per `production/epics/post-process-stack/story-006-resolution-scale-subscription.md` ACs (TR-PP-008/010) |
| PPS-007 | Full-stack visual + perf verification (4.6 glow rework + Slot 3 budget) | godot-gdscript-specialist + technical-artist consult | 2–3 | PPS-003/005/006; outline pipeline ✅; ADR-0008 G3 verification gate | Per `production/epics/post-process-stack/story-007-visual-perf-verification.md` ACs (TR-PP-009) — automated portions; **screenshot-diff visual sign-off DEFERRED to user** if PPS-007 surfaces it (per global stop condition #3) |

### Should Have

*None — sprint is 12 Must-Have stories per roadmap; no Should-Have or Nice-to-Have.*

### Nice to Have

*None.*

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| HC-006 visual checks (AC-2/3/4/6) + Slot 7 perf | `scenes/sections/` filesystem permission constraint blocked Plaza VS scene authoring during Sprint 06; deferred to user-driven Plaza VS playtest. **Not pulled into Sprint 07** — surfaces only if permission is lifted mid-sprint and user requests integration verification. | – |
| SA-005 Settings panel UI shell | ADR-0004 G1 + G5 OPEN per Sprint 06 close-out (`Effectively-Accepted` not `Accepted`). Defers until ADR-0004 fully closes. **Not pulled into Sprint 07.** | – |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Alert-tier music asset gap (no `.ogg` stems for COMBAT music) | HIGH | LOW (logic ships with placeholder one-shot per roadmap stop condition) | AUD-003 implements the *state grid* + crossfade machinery against a `placeholder_combat.ogg` 4-second loop generator (or silent stub); audio-director surfaces commission ask in close-out section. Acceptable per roadmap line 87. |
| ADR-0008 G3 glow rework — 4.6 compatibility re-verification | MEDIUM | MEDIUM (PPS-005/007 may surface drift in `Environment.glow_*` API or `tonemapper` constants between 4.5→4.6) | PPS-005 implementation cross-checks against `docs/engine-reference/godot/` 4.6 entries before authoring. If drift surfaces, escalate to godot-shader-specialist + amend ADR-0008 if needed (counts as ADR ambiguity → STOP per global condition #1). |
| `scenes/sections/` filesystem permission constraint blocks DC-005 Plaza tutorial integration | MEDIUM | HIGH (DC-005 cannot place a real document body into a Plaza scene without writing under `scenes/sections/`) | At DC-005 pickup time, run a write-probe to `scenes/sections/`. If blocked, ship DC-005 as a unit-test-only round-trip integration test (no live scene) and surface to user as "Plaza tutorial integration is logic-verified only; live placement deferred until permission lifts" — same pattern as HC-006 deferral in Sprint 06. |
| PPS-003 logic-only against stubbed shader API may miss interface drift when PPS-002 lands | LOW | MEDIUM | Define the `SepiaDimEffect` interface contract in PPS-003 explicitly (a 1-method abstract base or a NodePath-resolved stub); PPS-002 will conform when it lands. Document the contract in `docs/architecture/architecture.md` PPS section. |
| Audio body integration friction with Sprint-04 Stealth alert signals (`alert_state_changed`, `actor_became_alerted`) | LOW | LOW (signals are stable since Sprint 04 close) | AUD-003/005 use the same subscriber pattern HSS-002 used; if signal payload semantics drift, escalate to godot-specialist. |
| Tech-debt register grows past 12 items (currently 8: TD-001..TD-008) | LOW | HIGH (global stop condition #8 — autonomous executor must stop) | Each story's `/code-review` round captures only **non-architectural** debt as TD-009+; architectural debt forces an ADR amendment (which is its own stop condition). Conservative budget: ≤4 new TD entries across Sprint 07 keeps total at 12. |
| DC-005 Plaza tutorial requires `ui.interact.pocket_document` localization key | LOW | LOW | LOC scaffold + LOC-005 anti-pattern fences shipped in Sprint 06; key is a routine CSV addition in DC-005 implementation. |

## Dependencies on External Factors

- **Audio assets** — alert-tier music stems may not exist (roadmap stop condition acknowledged). Logic ships with placeholder one-shot or silent stub; commission ask surfaces in close-out.
- **No other external dependencies** — all upstream code (SAI signals, F&R respawn, FootstepComponent, SaveLoadService, LSS, SettingsService, ADR-0006 collision layers, OUT-* outline pipeline, ADR-0002 signal freeze) is shipped and tested.

## ADR-0004 Status (carryforward from Sprint 06)

ADR-0004 is **Effectively-Accepted** per Sprint 06 close-out:
- G1 (AccessKit property names on custom Controls): OPEN
- G5 (BBCode → AccessKit serialization): OPEN

Sprint 07 stories DC-001..DC-005 are **NOT** ADR-0004-blocked because:
- DC-001..DC-004 are **data-layer + scene-tree-node logic** (no UI surface)
- DC-005 uses `tr()` for the interact prompt (already proven Sprint 06 LOC-004 pattern; no AccessKit dependency)

The `document-overlay-ui` epic (5 stories) remains deferred. Surface ADR-0004 status in Sprint 07 close-out only if it becomes a blocker mid-sprint.

## Definition of Done for this Sprint

- [ ] All 12 Must-Have stories `Status: Complete`
- [ ] All stories pass acceptance criteria (auto-verified for Logic/Integration; visual sign-off **deferred to user** for PPS-007 if surfaced)
- [ ] QA plan exists at `production/qa/qa-plan-sprint-07-2026-05-03.md`
- [ ] All Logic/Integration stories have passing unit/integration tests in `tests/unit/foundation/audio/`, `tests/unit/feature/document_collection/`, `tests/integration/feature/document_collection/`, `tests/unit/foundation/post_process_stack/`
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] `/scope-check sprint-07-audio-body-and-document-logic` confirms 0 additions
- [ ] No S1 or S2 bugs in delivered features
- [ ] Tech-debt register ≤12 items (currently 8)
- [ ] Forbidden-pattern fences registered: `audio_publishing_signals`, `dialogue_subtitles_reaching_into_audio_bus`, `document_content_baked_into_resource`, `document_signal_emitted_outside_dc`, `worldenvironment_glow_enabled`
- [ ] Cumulative test suite green (Sprint 06 baseline ~1033 with 12 known pre-existing flakies; Sprint 07 must add 0 new failures)

## Stop Conditions (per bootstrap; do NOT work around)

1. ADR ambiguity or amendment required (especially ADR-0004 G1/G5 — Document Collection ships logic only because Document Overlay UI is ADR-0004-blocked; surface any DC story that requires the overlay surface)
2. Scope drift (`/scope-check` flags additions beyond the planned story IDs)
3. Visual sign-off needed (PPS-007 most likely)
4. Art asset hard blocker (alert-tier music stems — deferral acceptable per roadmap)
5. Test failure or regression
6. Cross-sprint dependency emerges
7. Tech-debt register grows past 12 items (currently 8)
8. Manifest-version bump decision for save format (DC-004 has a save/load hook)
9. Glow rework verification gate (ADR-0008 4.6 glow note — re-verify against engine reference if PPS-005 surfaces issues)

> **Scope check**: This sprint contains 0 stories added beyond the original roadmap scope. Run `/scope-check sprint-07-audio-body-and-document-logic` at sprint close to confirm.

## Next Steps

- `/qa-plan sprint` — produces `production/qa/qa-plan-sprint-07-2026-05-03.md`
- `/story-readiness production/epics/document-collection/story-001-document-resource-schema.md` — start the DC chain (DC-001 has no upstream Sprint-07 deps)
- `/dev-story` → `/code-review` → `/story-done` per story
- `/sprint-status` mid-sprint
- `/smoke-check sprint` + `/scope-check sprint-07-audio-body-and-document-logic` at close

## QA Plan

Pending — `/qa-plan sprint` runs next per Phase 5 Step [A].
