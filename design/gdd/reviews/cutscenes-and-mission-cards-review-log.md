# Cutscenes & Mission Cards — Review Log

System #22 (Narrative / Presentation layer, Pure VS scope). Pillar 5 (Period Authenticity) load-bearing primary; Pillar 1 (Comedy Without Punchlines) + Pillar 4 (Iconic Locations as Co-Stars) supporting.

GDD: `design/gdd/cutscenes-and-mission-cards.md`

---

## Review — 2026-04-28 — Verdict: MAJOR REVISION NEEDED → revisions applied inline → APPROVED (user-accepted, no fresh re-review)

**Scope signal:** L (XL risk if Writer Brief slips)
**Specialists:** game-designer / systems-designer / narrative-director / audio-director / performance-analyst / qa-lead / godot-specialist / ux-designer / accessibility-specialist + creative-director (senior synthesis)
**Mode:** `--depth full` default; auto mode active; solo review-mode globally (CD-GDD-ALIGN gate skipped at Phase 5a-bis per `/design-system` authoring; this `/design-review` was the first independent senior pass)
**Blocking items at first verdict:** 16
**Recommended items:** ~25
**Nice-to-have items:** 6
**Prior verdict resolved:** First review

---

### Summary of key findings

**Highest-confidence defect (4-way convergent — game-designer / narrative-director / qa-lead / ux-designer):** §V.1 L1088 mandated closing-card title `OBJECTIVE COMPLETE` while §C.5 TR-6, §C.4.2 L213, and §H.9 AC-CMC-9.2 all forbade it. Direct self-contradiction across 4 sections. AC-CMC-9.2's CI grep targeted `translations/cutscenes.csv` only, so a hardcoded English string in `.tscn` could have shipped undetected. **Resolution:** §V.1 L1088 was a copy-paste residue from an earlier draft; replaced with §C.4.2-aligned `OPERATION: PARIS AFFAIR — STATUS: CLOSED` + explicit prohibition note. AC-CMC-9.2 grep widened to `src/gameplay/cutscenes/**` recursive.

**Pillar 5 vs WCAG 2.1 collision (3-way convergent — accessibility / ux / game):** FP-CMC-2 absolute "no first-watch skip" violated WCAG 2.1 SC 2.2.1 / 2.2.2 / 2.1.1. CT-05 = 25–30 s of inescapable content. Specialists disagreed on remedy (skip toggle vs text summary vs structural carve-out). **Creative-director adjudicated:** Settings-gated `accessibility_allow_cinematic_skip` carve-out (default `false` — Pillar 5 preserved as shipping default), anchored to the Combat §B Stage-Manager precedent. Companion: `text_summary_of_cinematic` (OQ-CMC-11) promoted from Polish-spike to BLOCKING (VS-recommended MVP).

**Performance accounting:** Cutscene-start transition frame had unanalyzed Slot 7 overlap with HUD Core + HSS peak (~0.306 ms). Resolution: CR-CMC-9 expanded with boundary-frame ordering rule (HUD's synchronous `_on_ui_context_changed` handler completes before Cutscenes' first AnimationPlayer/Tween advance; no `CONNECT_DEFERRED`). Plus `_unhandled_input` cost (60–120 events/s polling during card display) added as new term in F.1 formula.

**Audio:** Hammond chord voicing contradiction caught — "F minor 2nd inversion (C-F-Ab), root F2 (87 Hz)" misled sound-designer handoff (2nd inversion bass note is C2, not F2). Clarified. Same-frame priority guard for `cutscene_ended` + `mission_completed` (CT-05 path) required explicit `Tween.kill()` mechanism — added as new audio.md Concurrency Policy 4 forward-coord. HANDLER VO baked transceiver EQ exception flagged in Writer Brief (Voice bus has no runtime EQ insert).

**Godot 4.6:** VG-CMC-2 dual-focus split risk concrete: a focusable Control in card tree could consume `Esc` via `_gui_input` before CanvasLayer root's `_unhandled_input` runs. Added §C.8 scene-tree invariant: every Control is `MOUSE_FILTER_IGNORE` + `FOCUS_NONE`. Plus `MissionLevelScripting.get_mission_state()` live-vs-copy ambiguity — Godot 4.5 added `duplicate_deep()`; OQ-CMC-6 now explicitly requires "live reference, never duplicate." VG-CMC-1/3/5 downgraded (answerable from engine docs).

**QA-Lead AC defects:** 9 ACs rewritten with concrete spy patterns (GUT `watch_signals` vs mock `Events`), explicit GIVEN clauses (gate-location preconditions, first-watch precondition assertions), and replacement of untestable "no warning" assertions with positive context/handler-call assertions. 2 missing ACs added: AC-CMC-16.1 (CanvasLayer free-on-section-unload, covers CR-CMC-16 lifecycle gap) + AC-CMC-19.1 (Mission Briefing hard-cut entry verified by zero-Tween spy).

**Closed captions (accessibility BLOCKING):** CT-05's wire-cut + device-tick cessation are narrative-critical SFX with no caption equivalent — deaf players miss the climactic confirmation. Resolution: extended D&S boundary (CR-CMC-10) to include new SCRIPTED Category 8 (non-dialogue narrative captions). Triggered via MLS `scripted_caption_trigger(scene_id, caption_key)`. New OQ-CMC-18 D&S coord item.

---

### User-adjudicated decisions during revision (2026-04-28 night)

| # | Question | Choice | Rationale |
|---|---|---|---|
| 1 | FP-CMC-2 carve-out shape | [A] Settings toggle, default off | Pillar 5 preserved as shipping default; accessibility opt-in pattern matches Combat §B Stage-Manager precedent |
| 2 | `text_summary_of_cinematic` classification | [A] VS-recommended (CD adjudicated) | Move from Polish-spike to OQ-CMC-11 BLOCKING; complementary to skip carve-out |
| 3 | Slot 7 transition-frame fix | [A] Document HUD-hide-before-tick ordering | Cleanest if implementable; ADR-0008 unchanged; CR-CMC-9 + HUD CR-10 coord |
| 4 | Closed-caption SFX delivery path | [A] D&S SCRIPTED Category 8 | Consistent with existing boundary; Cutscenes specifies trigger points only |

---

### Specialist disagreements adjudicated

- **No-first-watch-skip:** accessibility-specialist + ux-designer + game-designer all flagged BLOCKING but proposed different remedies. Narrative-director did not call BLOCKING. **CD adjudicated** Settings-gated carve-out (default off); anchored to Stage-Manager precedent.
- **`text_summary_of_cinematic` classification:** accessibility + ux flagged BLOCKING; narrative + game silent. **CD adjudicated** promotion from ADVISORY/Polish to BLOCKING/VS.
- **CR-CMC-17 drop-not-queue:** game-designer flagged the "30 s stale" rationale as fictitious (real drop window is 4–9 s); other specialists silent. **Held the rule** but elevated EC-CMC-H.1 authoring lint to BLOCKING priority for runtime safety.
- **VG-CMC-1/3/5:** godot-specialist: documented behavior, not Godot 4.6 unknowns. **Downgraded** per recommendation. VG-CMC-2 (dual-focus) and VG-CMC-4 (`AUTO_TRANSLATE_MODE_DISABLED` constant verification) remain BLOCKING.

---

### Revision artifacts

- GDD line count: 1,667 → 1,701 (+34 net; many one-line clarifications + 2 new ACs + 1 new EC + 4 new OQs)
- BLOCKING coord items: 10 → 14 (4 added: OQ-CMC-11 [promoted], OQ-CMC-17 [Settings carve-out], OQ-CMC-18 [D&S Category 8], OQ-CMC-19 [HUD ordering + Godot 4.6 verification])
- ACs: 49 → 51 (43 BLOCKING + 8 ADVISORY)
- EC count: 35 → 36 (Cluster B grew to 8 with new EC-CMC-B.8 null-safety)
- New forbidden patterns: FP-CMC-13 (no `.new()` direct instantiation) + FP-CMC-14 (no focusable Control / `MOUSE_FILTER_STOP` in card tree)

---

### Outstanding work for VS sprint kickoff (14 BLOCKING coord items)

OQ-CMC-1 through OQ-CMC-10 (original) + OQ-CMC-11 (promoted) + OQ-CMC-17 + OQ-CMC-18 + OQ-CMC-19 (new). Cross-system amendments needed in: ADR-0002 (Cutscenes domain signals), ADR-0004 (Context.CUTSCENE + amendments), ADR-0008 (Slot 7 sub-claim + HUD CR-10 ordering), MLS GDD (multiple), LSS GDD (touch-ups + section validation), Audio GDD (Concurrency Policy 4 + 5 new tuning knobs + cutscene_track_dict pattern), PPS GDD (new fade-to-black API + idempotency contract), Localization Scaffold (cutscenes.csv 16-key roster), Input GDD (cutscene_dismiss action + blocked-actions), Settings & Accessibility GDD (new `accessibility_allow_cinematic_skip` toggle), Dialogue & Subtitles GDD (new SCRIPTED Category 8), HUD Core GDD (CR-10 ordering rule echoed), Writer Brief authoring (`design/narrative/cutscenes-writer-brief.md`).

---

### Producer note

The 5th consecutive Accept-without-re-review pattern (after Settings, CAI, HUD Core, Document Collection, Input). User has consistently chosen to fold revision feedback inline rather than spawn a fresh re-review pass. This carries elevated risk that revision-introduced contradictions slip undetected — the 1,701-line GDD now has 34 lines of new material that have not been independently reviewed by any specialist. Recommend producer schedule a smoke `/design-review` on the final GDD at the start of the VS sprint planning phase, after the 14 BLOCKING coord items close, as a final gate before implementation. Alternatively, run `/consistency-check` and `/review-all-gdds` post-coord-closure to detect any new cross-system drift introduced by the revision.
