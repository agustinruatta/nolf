# Document Overlay UI — Review Log

Tracks every `/design-review` and `/review-all-gdds` pass against `design/gdd/document-overlay-ui.md`.

---

## Review — 2026-04-27 evening — Verdict: MAJOR REVISION NEEDED → revisions applied in same session
Scope signal: L
Specialists: game-designer, systems-designer, ux-designer, godot-specialist, performance-analyst, accessibility-specialist, qa-lead, localization-lead, creative-director
Blocking items: 23 | Recommended: 19 | Nice-to-have: 4
Prior verdict resolved: First review

### Summary

The vision is exceptionally clear — "The Lectern Pause" is one of the strongest articulated player fantasies in the project. The reject is on **implementability gates**, not creative direction. Five of the BLOCKING items were active Lectern Pause violations (gamepad drift-scroll, scroll discoverability invisible, CR-2 Option A LOCKED-too-early). Five were architectural accessibility gaps (modal announce pattern wrong, BBCode→AT plain-text unverified, Tab/focus trap undefined, font-scaling absent, high-contrast/colorblind behavior undefined). The rest covered specific Godot 4.6 API risks (AccessKit property names, `base_theme` typo, `auto_translate_mode`), formula bound errors (F.1 ceiling computed for English warm-cache, missing 350-word German cold-atlas worst case), missing test infrastructure (12 ACs unverifiable until `tools/ci/check_forbidden_patterns_overlay.sh` and `tests/unit/helpers/call_order_recorder.gd` ship), and writer-brief propagation (250-word ceiling not yet in `design/narrative/document-writer-brief.md`).

### Specialist Disagreements Adjudicated by creative-director

1. **CR-2 Option A "premature lock"** — game-designer flagged BLOCKING; the GDD's deferred-question table named the dependency. **CD ruling**: game-designer wins. Deferral mechanism named the issue but did not preserve a *named fallback design*. Resolution: G.4 LOCKED entry removed; CR-2-bis Option A-delayed named fallback documented; `document_auto_open_delay_s` tunable added.
2. **Gate D AUTO_TRANSLATE_MODE BLOCKING vs verified PASS** — godot-specialist's own analysis verified the enum names exist. **CD ruling**: close Gate D. Resolved.
3. **CR-10 "cannot change font size" vs SC 1.4.4** — accessibility-specialist BLOCKING vs Pillar 5 / Lectern Pause "paper doesn't resize." **CD ruling**: both right at different layers. Solution = system-level scaling owned by Settings GDD; CR-10 wording clarifies prohibition is on in-overlay session-local controls. New OQ-DOV-COORD-12 added.
4. **Open-frame spike "masked by sepia fade" vs frame-budget reservation** — performance-analyst BLOCKING vs F.1's masking framing. **CD ruling**: performance-analyst wins. Perceptual masking ≠ frame-budget headroom. F.1 amended with 3D-headroom paragraph + FontRegistry.preload_font_atlas() requirement.

### Revisions Applied (46 items resolved in same session)

**Verification gates after revision**: 7 total — Gate A BLOCKING (highest implementation risk, AccessKit property names; pseudocode pending), Gate B CLOSED, Gate C BLOCKING, Gate D CLOSED, Gate E PROMOTED to BLOCKING, Gate F upgrade-for-gamepad-path, Gate G NEW BLOCKING (BBCode→AT plain-text).

**Coord items after revision**: 13 BLOCKING (was 11) + 1 ADVISORY. Three new BLOCKING items added — OQ-DOV-COORD-12 (Settings `text_scale_multiplier` for WCAG SC 1.4.4 conformance), COORD-13 (`tests/unit/helpers/call_order_recorder.gd` for AC verification), COORD-14 (HUD Core must kill/pause Tweens on InputContext change to non-GAMEPLAY).

**Cross-document amendments**: `design/narrative/document-writer-brief.md` §7.5 added — 250-word English hard ceiling, no minimum, propagating OQ-DOV-COORD-4 closure. Localization Scaffold §Interactions ownership table requires `overlay.*` namespace row addition (OQ-DOV-COORD-5 amendment); not yet applied here — owned by Localization Scaffold author.

### Status

- Revisions complete; system NOT yet re-reviewed.
- Re-review recommended in fresh session via `/clear → /design-review design/gdd/document-overlay-ui.md`.
- 11 BLOCKING items in `design/gdd/document-overlay-ui.md` §C.12 still require **upstream coord work** by other GDDs (DC, PPS, MLS, ADR-0004, Localization Scaffold, HUD Core, Settings & Accessibility) before any sprint story can be written.
- Three verification gates remain BLOCKING and require Godot 4.6 in-engine spike before implementation: Gate A (AccessKit), Gate C (modal dismiss), Gate G (BBCode plain-text).

### Key files modified

- `design/gdd/document-overlay-ui.md` — primary GDD revision (~46 edits across §C.1–§C.12, §F.1–§F.4, §E, §G.1–§G.5, §H.1–§H.16, §V.5, §Open Questions)
- `design/narrative/document-writer-brief.md` — new §7.5 (250-word ceiling) + §7 step 5 reference
- `design/gdd/systems-index.md` — row 75 status updated to NEEDS REVISION

### Recommended next steps (priority order)

1. `/clear` then `/design-review design/gdd/document-overlay-ui.md` to verify revisions hold.
2. Open coord-item conversations with: DC author (COORD-1, 8), PPS author (COORD-2), MLS author (COORD-3, 9), Settings author (COORD-12), HUD Core author (COORD-14), tools-programmer (COORD-11, 13), Localization Scaffold author (COORD-5).
3. Schedule Godot 4.6 in-engine spike for Gates A + C + G before any sprint story writes against ADR-0004.
4. `/consistency-check` to verify the 6 NEW registry entries (per pre-revision summary) are still consistent with revised tunables.
