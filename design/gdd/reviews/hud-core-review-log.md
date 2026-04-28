# HUD Core — Design Review Log

This file tracks all `/design-review` passes against `design/gdd/hud-core.md`.
Future re-reviews append entries here so reviewers can track what was raised, what was resolved, and what carried forward.

---

## Review — 2026-04-25 — Verdict: MAJOR REVISION NEEDED → REV-2026-04-25 partial pass in-session → status NEEDS REVISION (re-review pending)

**Scope signal**: **XL** (escalated from L by creative-director synthesis — 8 hard upstream + 8 ADR dependencies + 5 formulas + multi-system integration + 4 pre-existing BLOCKING coord items + 24 newly surfaced BLOCKING items + likely ADR-0008 amendment depending on F.5 measurement)

**Specialists consulted (7 + creative-director)**: game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, performance-analyst, godot-specialist + creative-director (senior synthesis)

**Review depth**: full (default; user invoked `/design-review design/gdd/hud-core.md` without `--depth` flag)

**Blocking items raised**: 24 (across all 7 specialists, plus 3 specialist disagreements requiring user adjudication)
**Recommended items raised**: ~30
**Nice-to-have items raised**: ~6
**Disagreements**: 3 (TAKEDOWN_CUE legitimacy; photosensitivity opt-out timing; alert-state HoH/deaf accessibility severity) — all adjudicated by creative-director and confirmed by user

### Senior verdict (creative-director)

> "**MAJOR REVISION NEEDED.** The HUD Core GDD is ambitious and largely well-conceived in its pillar alignment, but it is **not implementation-ready**. Across 7 specialist reviews, **24 BLOCKING items** were surfaced — and the convergence pattern (3 specialists independently flagging the same F.5 perf-budget breach; 2 specialists flagging the FontRegistry/viewport interaction; 2 flagging the coroutine re-entry guard) indicates the issues are real, not noise. A HUD spec that ships with unmeasured perf constants, an actual budget breach in the worst case, an unresolved accessibility floor, and a contradicted core-fantasy element should not be greenlit for sprint."

> "Re-review required after: (a) F.5 re-derived against measured Godot 4.6 constants and reconciled with ADR-0008; (b) TAKEDOWN_CUE resolved (demote-to-OQ recommended); (c) Day-1 photosensitivity opt-out and HoH alert substitute added; (d) FontRegistry × viewport scaling fixed; (e) all 9 qa-lead AC defects rewritten; (f) 6 ui-programmer/godot-specialist coord items resolved with verified Godot 4.6 API names. Until then, this spec is unsafe to sprint."

### Summary of findings

**Critical defects (multi-specialist convergence)**:
1. **F.5 perf-budget breach** — systems-designer + performance-analyst independently calculated worst-case at 0.309 ms vs the 0.3 ms ADR-0008 Slot 7 cap (prompt-strip Label was missing from N=5 count; true N=6). Compounded by `C_label = 0.05 ms` being an unmeasured estimate from training data predating Godot 4.6 TextServer rework, and the `_draw()` crosshair cost having no `C_draw` term.
2. **`await` coroutine re-entry / freed-self guard missing** — ui-programmer + godot-specialist both flagged the damage-flash `await get_tree().process_frame` as having no re-entry guard (concurrent flashes could race) and no `is_instance_valid(self)` check after await (crash on freed node).
3. **F.3 × FontRegistry interaction** — systems-designer + ux-designer both flagged that `FontRegistry.hud_numeral()` was called once at `_ready()` with the static design-pixel size (22), ignoring F.3's scale_factor; at 720p the effective rendered size is 14.7 px but FontRegistry was told "22" so the 18 px floor substitution never fires — health numerals render below Art Bible §7B floor.

**Single-specialist BLOCKING items (highest-priority)**:
4. [game-designer] **TAKEDOWN_CUE text contradicts cockpit-dial fantasy** — the HUD is supposed to confirm what Eve already feels, not invite a tactical action; "TAKEDOWN AVAILABLE" is an instruction, not a confirmation. Pillar 5 violation hiding as settled design.
5. [ui-programmer] **PC reference acquisition path missing** — CR-3 authorises 2 PC accessor calls but FP-14 forbids singleton/tree-walk lookups; no `@export` or group lookup specified. Implementer cannot acquire `pc`.
6. [ui-programmer] **Two undeclared Timer signal connections** — `_flash_timer.timeout` and `_gadget_reject_timer.timeout` are required for CR-7b and CR-9 but absent from CR-1's signal inventory.
7. [ui-programmer] **`_compose_prompt_text()` undefined + FP-8 conflict** — `tr(target.interact_label_key)` is dynamic, can't be cached at `_ready()`, and per-frame call violates FP-8.
8. [ui-programmer] **CR-8 dry-fire detection initial-state sentinel missing** — first `ammo_changed` after save replay can false-positive.
9. [ui-programmer] **CR-10 `InputContextStack.Context.GAMEPLAY` form forbidden** — ADR-0004 mandates the autoload-key form `InputContext.Context.GAMEPLAY`.
10. [godot-specialist] **`base_theme` vs `fallback_theme` unverified** — likely the actual property is `fallback_theme`; wrong name silently breaks theme inheritance.
11. [godot-specialist] **`accessibility_live` property name unconfirmed** in Godot 4.6.
12. [systems-designer] **F.2 vs Audio §F4 hysteresis asymmetry** — "pattern match" claim is false: Audio has 1s tick-restart debounce; HUD has zero hysteresis.
13. [ux-designer] **Photosensitivity opt-out is Day-1 required, not deferred** — industry/Sony/Microsoft cert + EU GAAD norms.
14. [ux-designer] **Alert-state audio-only with no HoH/deaf substitute** — likely WCAG 1.1.1 / 1.3.3 violation.
15-23. [qa-lead] **9 BLOCKING AC defects**: AC-HUD-1.5 wrong arg order; AC-HUD-2.7 not testable (no contrast threshold); AC-HUD-3.1 timer mechanism unspecified; AC-HUD-3.2 boundary `≤` ambiguous; AC-HUD-6.7 contradicts CR-3; AC-HUD-9.1 `Performance.TIME_PROCESS` measures whole frame not HUD; AC-HUD-9.4 multi-line grep not implementable; AC-HUD-10.x grep scope doesn't exclude `tests/`; AC-HUD-11.3 regex malformed; missing AC for sustained dry-fire (WCAG concern); missing AC for OQ-HUD-4 race coverage.
24. [godot-specialist] **`anchors_preset = ANCHOR_PRESET_*` not settable as property** — silent no-op; must use `set_anchors_preset(Control.PRESET_*)`.

### User-adjudicated decisions (4)

| # | Question | Decision | Recommended? |
|---|---|---|---|
| 1 | TAKEDOWN_CUE fantasy contradiction | Demote to OQ-HUD-7 (HIDDEN at MVP until first-playtest closes) | Yes |
| 2 | Photosensitivity opt-out timing | Promote `hud_damage_flash_enabled` to Day-1 MVP | Yes |
| 3 | HoH/deaf alert-state cue | Add brief text-only cue to HUD State Signaling forward-dep scope | Yes |
| 4 | F.5 perf-budget breach approach | Consolidate weapon+ammo Labels in V.3 (3 → 1) | Yes |

### REV-2026-04-25 partial revision pass — what was changed in-session

**User-adjudicated changes (4)**:
- **CR-12 / OQ-HUD-7**: TAKEDOWN_CUE resolver returns HIDDEN at MVP (latch + signal subscription remain implementation-ready). New OQ-HUD-7 BLOCKING-for-VS deferring visible behaviour to first playtest with explicit Path A/B/C resolution paths.
- **§UI-2 / §G.4 / OQ-HUD-5**: `hud_damage_flash_enabled` promoted to Day-1 MVP via stub `Settings.get_setting()` accessor; UI-2 row promoted; G.4 forward-dep table updated; new AC-HUD-3.8 added; reduced-motion row corrected (was claiming "no motion to reduce" — incorrect).
- **§UI-2 / §V.7 / §C.5**: HoH/deaf alert-state cue added to HUD State Signaling forward-dep scope as Day-1 surface owned by HSS; new UI-2 row; coord item flagged BLOCKING for VS.
- **§C.2 / §V.3 / §H.4**: Weapon+ammo widget consolidated from 3 Labels (current/slash/reserve) to 1 Label with formatted string `"%d / %d"`. Updated AC-HUD-4.2/4.3/4.4/4.5/4.6. Art Director coord item added for slash typography review.

**Technical fixes (additional, applied directly per industry convention)**:
- **F.5**: Formula expanded with `C_draw`, `C_resize`, `C_theme_override` terms; prompt-strip Label included; constants flagged UNMEASURED pending Iris Xe Gen 12 / Godot 4.6 measurement (OQ-HUD-5 escalated to BLOCKING).
- **CR-3**: PC reference acquisition specified via `@export var pc: PlayerCharacter`; `is_instance_valid()` requirement added to match AC-HUD-6.7.
- **CR-10**: `InputContextStack.Context.GAMEPLAY` → `InputContext.Context.GAMEPLAY` (autoload-key form per ADR-0004).
- **CR-1**: Signal inventory expanded from 10 → 16 connections (added Timer.timeout × 2, viewport.size_changed, locale, settings × 2).
- **§V.4 / §C.4**: Coroutine re-entry guard `_flashing: bool` and `is_instance_valid(self)` post-await guard added to damage-flash pseudocode.
- **CR-19**: FontRegistry call now passes `int(round(design_size_px * scale_factor))` — 18 px floor now fires correctly at 720p.
- **F.2**: Audio §F4 hysteresis asymmetry documented as intentional divergence (Audio has 1s debounce; HUD has none).
- **AC defects rewritten** (9): AC-HUD-1.5 (arg order); AC-HUD-2.7 (deterministic contrast threshold); AC-HUD-3.1 (timer mechanism specified); AC-HUD-3.2 (boundary disambiguated); AC-HUD-9.1 (Time.get_ticks_usec() bracketing); AC-HUD-9.4 (AST static analysis or stricter rule); AC-HUD-10.x (scope exclusion + word-boundary anchors); AC-HUD-11.3 (regex corrected).
- **New ACs (3)**: AC-HUD-3.7 (sustained dry-fire WCAG); AC-HUD-3.8 (photosensitivity opt-out behaviour); AC-HUD-12.5 (OQ-HUD-4 race coverage).
- **§C.5 BLOCKING coord items** expanded 4 → 6: added Godot 4.6 API verification batch (`Color(hex,alpha)`, `TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL`, `set_anchors_preset()`, `Performance.TIME_PROCESS`, `process_frame` signal, `font_color` theme key, `focus_mode = FOCUS_NONE`, `corner_radius_*`); F.5 measurement gate.

### What was NOT changed in this pass — deferred to next-session re-review

**Recommended items (~30) deferred** — these were flagged by specialists as RECOMMENDED (not BLOCKING) and remain open for the next revision pass:
- ux-designer: gadget empty-tile alpha 0.4 contrast check (likely WCAG 3:1 fail); RTL prompt-strip layout direction; prompt-strip key glyph input-rebinding integration; colorblind palette test evidence missing; `accessibility_live` Day-1 default behaviour confirmation; prompt/subtitle vertical-band collision at 21:9 ultrawide.
- game-designer: alert-state discoverability AC; kill-confirmation experiential AC; critical-state oscillation experiential AC; MEMO_NOTIFICATION risk reframing; FP-6 grep blind spots (HSS extension path); 1-frame flash perceptual detection AC; `get_prompt_label()` extension write-race resolution.
- systems-designer: F.4 default 0.19% silently hits floor at 1080p (slider-feel issue); §C.4 reset table semantic ambiguity vs CR-14; F.1 `t = 333.0 ms` boundary documentation; `_player_died` mid-await coroutine cancellation AC nuance; LOAD_FROM_SAVE × section_entered interaction note.
- ui-programmer: CR-1 boilerplate scalability (data-driven SUBSCRIPTIONS array); `Label.text` getter cost in change-guard (`_last_prompt_text` mirror); HSS extension API resolver-hook design; F.5 thin-headroom raised as Tier-1 risk if measurements come in unfavourable.
- godot-specialist: dual-focus split exemption requires `focus_mode = FOCUS_NONE` (added to coord item batch but not per-widget annotated yet); signal connection idiom (Callable construction in tests); `draw_arc` parameter order verified correct; `is_connected()` guard pattern + Cluster I ordering verified correct.
- performance-analyst: `viewport.size_changed` layout invalidation cascade analysis (added to F.5 but not measured); AccessKit overhead contingency in F.5; CI runner hardware fallback profile detail.
- qa-lead: AC-HUD-11.5 "deferred to Polish" is open issue masquerading as AC; AC-HUD-9.x hardware fallback (added to AC-HUD-9.1 but not all perf ACs); evidence-path consistency review.

### Coord items status (post-REV)

**BLOCKING (6+, was 4)**:
1. ADR-0002 amendment: `ui_context_changed` signal (UI domain).
2. ADR-0002 amendment: `takedown_availability_changed` signal (SAI domain).
3. ADR-0004 Gate 2: Theme inheritance property name (`base_theme` vs `fallback_theme`).
4. ADR-0004 Gate 1: `accessibility_live` property name on Godot 4.6 Label/Control (REV-2026-04-25 promoted from "deferrable to Polish").
5. **NEW REV-2026-04-25**: Godot 4.6 API verification batch (8 sub-items — see §C.5 Coord item #5 in HUD GDD).
6. **NEW REV-2026-04-25 (escalated from advisory contingency)**: F.5 constant measurements (`C_label`, `C_draw`, `C_poll`, `C_theme_override`) on Iris Xe Gen 12 / Godot 4.6 / 810p Restaurant — OQ-HUD-5 escalated.

**ADVISORY (3, unchanged)**:
- Settings & Accessibility GDD #23 forward-dep contract.
- HUD-scale slider Settings forward-dep (OQ-HUD-1).
- Combat §UI-6 dual-discovery path requires Settings GDD.

### Why re-review is required (creative-director directive)

The REV-2026-04-25 in-session pass addressed the highest-priority blockers but: (a) did not measure F.5 constants — the cap-breach risk is real until measured; (b) accumulated ~30 RECOMMENDED items that need a second specialist pass to confirm none are mis-classified blockers; (c) the partial pass introduced new content (OQ-HUD-7, AC-HUD-3.7/3.8/12.5, expanded coord items) that itself should be specialist-reviewed for internal consistency. A fresh-session `/design-review design/gdd/hud-core.md` is the appropriate next gate.

### Files modified in REV-2026-04-25

- `design/gdd/hud-core.md` — primary revision target (~80 line diff distributed across 18 sections; doc grew from 1,182 → ~1,260 lines).
- `design/gdd/systems-index.md` — row 16 status updated NEEDS REVISION; Last Updated header updated; Progress Tracker row reflects post-review state; Design docs reviewed count 10 → 11.
- `design/gdd/reviews/hud-core-review-log.md` — this file (NEW).

### Next session

Run `/clear` then `/design-review design/gdd/hud-core.md` to re-review the post-REV state with a clean context. Expected outcome: most BLOCKING items closed if implementer-side measurements (F.5 constants + Godot 4.6 API names) have been done before re-review; otherwise, the verdict will likely remain NEEDS REVISION pending those measurements.

---

## Review — 2026-04-25 (re-review) — Verdict: MAJOR REVISION NEEDED → REV-2026-04-26 second-pass applied 2026-04-26 → status NEEDS REVISION (third re-review pending)

**Scope signal**: **L** (creative-director synthesis: was XL on first pass; concentrated structural debt with clear boundaries, ~4-6h focused re-author)

**Specialists consulted (7 + creative-director)**: game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, performance-analyst, godot-specialist + creative-director (senior synthesis)

**Review depth**: full (default)

**Blocking items raised**: 15 themes (some carrying multiple sub-items)
**Recommended items raised**: ~12
**Nice-to-have items raised**: ~4
**Disagreements**: 0 — all 7 specialists converged on MAJOR REVISION

### Senior verdict (creative-director)

> "The 24+ specialist findings collapse into **five structural failures**: (1) the performance budget math is structurally untrustworthy, (2) REV-2026-04-25 introduced contradictions while closing prior ones, (3) accessibility commitments were promoted to 'Day-1' without delivery paths, (4) spec-body did not absorb the coord-item and coroutine fixes, (5) the AC suite is not a test plan. **The defect-injection rate during REV-2026-04-25 exceeded the closure rate.** Recoverable, but only with a constrained third pass — process must change, not just content. Production risk: this is a process problem, not a content problem; do not put HUD Core back in queue for a fourth review until a single uninterrupted re-author session has occurred."

### Summary of 15 BLOCKING themes

1. F.5 worst-case math: three irreconcilable figures (0.259/0.279/0.309 ms); AC-HUD-9.2 omits `C_draw`; gadget-slot phantom Label inflated N by 1; maxed scenario produced 0.339 ms over cap.
2. AC-HUD-3.7 vs AC-HUD-4.5 dry-fire rate-gate contradiction (NEW + existing AC mandate opposite implementations).
3. `_compose_prompt_text()` undefined; FP-8 violated (per-frame `tr()`).
4. §C.4 vs §V.4 coroutine pseudocode disagree on entry conditions.
5. Coord-item fixes (§V.3 enum prefix, §C.2 method form) flagged in changelog but not propagated to spec body.
6. Photosensitivity opt-out has no Day-1 player-accessible UI path; stub returns `true`; Settings #23 + boot-warning #22 both Not Started.
7. HoH/deaf "formal exception with named owner + timeline" mechanism does not exist; HSS #19 Not Started.
8. Gadget empty-tile alpha 0.4 likely fails WCAG 3:1 non-text contrast; AC-HUD-5.2 has no contrast gate.
9. Prompt-strip key glyph rebinding mechanism missing; `[E]`/`[F]` static literals exclude gamepad players Day-1.
10. OQ-HUD-7 latch creates Path-C gravity well: latch + signal + AC-HUD-6.3 in MVP code biases toward Path C restoration.
11. Dual-focus split exemption unverified vs Godot 4.6 HIGH-RISK change; no per-widget `focus_mode = FOCUS_NONE`.
12. CR-1 connection count incorrect (claimed 16; actually 14); AC-HUD-1.1 verifies only 10 of those.
13. CR-3 PC injection contract not implementable (no pre-`add_child` mandate; no LSS re-injection path; no null guard in §C.3).
14. Multiple AC defects (AC-HUD-2.7 not deterministic; AC-HUD-3.1 disjunction; AC-HUD-9.4 disjunction; AC-HUD-9.1 references nonexistent ADR-0008 normalization table; AC-HUD-3.2 float literal; AC-HUD-6.7 same-frame `queue_free()`; AC-HUD-3.8 stub; AC-HUD-11.5 deferred-OQ-as-AC; no smoke vs full-suite gate designation).
15. REV-2026-04-25 internal contradictions (reduced-motion claim self-contradicts; CR-8 prose still un-gated; HoH auto-dismiss timer collides with §C.3).

### User-adjudicated decisions (4)

| # | Question | Decision | Recommended? |
|---|---|---|---|
| D1 | Dry-fire rate-gate contradiction | Gate dry-fire at 3 Hz via dedicated `_dry_fire_timer`; rewrite CR-8; update AC-HUD-4.5; remove "Why NOT rate-gated" footnote | Yes |
| D2 | Photosensitivity opt-out Day-1 delivery path | Promote Settings #23 minimal photosensitivity-toggle UI to HARD MVP dep | Yes |
| D3 | HoH/deaf alert-state cue path | Promote HSS #19 minimal alert-cue slice to HARD MVP dep | Yes |
| D4 | TAKEDOWN_CUE latch scope | Remove latch + signal + AC-HUD-6.3 from MVP entirely; close OQ-HUD-7 (Path A finalised) | Yes |

### REV-2026-04-26 second-pass — what was changed in-session

**User-adjudicated changes (4 — D1/D2/D3/D4)**: applied per the table above.

**Technical fixes (additional, applied per specialist findings)**:
- F.5 rebuilt with single canonical formula; gadget-slot phantom Label removed (N = 4, was 5); `C_a11y` term added (REV-2026-04-26); `theme_override_writes` corrected from 4→2; pessimistic worst case now 0.289 ms (~11 µs headroom — measurement still BLOCKING per OQ-HUD-5).
- `_compose_prompt_text()` defined with `_last_interact_label_key` mirror cache (FP-8 compliant; was undefined).
- §C.4 vs §V.4 coroutine pseudocode aligned (caller does gate check; `_execute_flash` does only the re-entry guard).
- §V.3 enum prefix `TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL` propagated; §V.3 stretch_mode prefix added.
- §C.2 scale rule rewritten: `set_anchors_preset(Control.PRESET_FULL_RECT)` method form; crosshair un-parented from scaled root (closes F.4×F.3 sub-pixel risk); explicit per-widget `focus_mode = FOCUS_NONE` annotation under 4.6 dual-focus split (BLOCKING-for-sprint verification still required).
- CR-3 PC injection: pre-`add_child` ordering MANDATED; LSS re-injection path documented; explicit null guard `if pc == null: state = HIDDEN; return` shown in §C.3 pseudocode.
- CR-1 recounted to 14 (was claimed 16); `setting_changed` shown as single connection with handler dispatch; `_dry_fire_timer.timeout` connection added.
- CR-8 rewritten with rate-gate + dedicated `_dry_fire_timer`; first-emission false-positive sentinel guard added.
- CR-17 cache list updated (removed `_takedown_eligible`, added new caches and sentinels).
- CR-21 NEW: prompt-strip key glyph runtime-rebound from Input system; Input GDD listed as new HARD upstream forward-dep.
- AC defects rewritten: AC-HUD-1.1/1.2 (14 connections), AC-HUD-2.7 (named tool + sampling), AC-HUD-3.1 (single mechanism), AC-HUD-3.2 (no float literal), AC-HUD-3.7 (single mandated implementation), AC-HUD-4.5 (rate-gated), AC-HUD-6.7 (`await` after `queue_free()`), AC-HUD-9.1 (no nonexistent table reference), AC-HUD-9.2 (formula corrected: N=4 + `C_draw` + `C_a11y`), AC-HUD-9.4 (single rule, no disjunction).
- AC-HUD-6.3 + 6.4 deleted (TAKEDOWN_CUE removed).
- AC-HUD-11.5 moved to OQ-HUD-8.
- AC-HUD-5.7 NEW (gadget empty-tile WCAG 3:1 contrast gate).
- §H.0 NEW: smoke-check vs full-suite gate designation.
- §UI-2 reduced-motion row disambiguated (toggle is the accommodation; rate-gate is the harm-prevention safety floor).
- §UI-2 photosensitivity row updated: Settings #23 minimal-UI HARD MVP dep; stub no longer cert-compliant.
- §UI-2 HoH/deaf row updated: HSS #19 minimal slice HARD MVP dep; "formal exception" path WITHDRAWN.
- §C.3 prompt-strip state machine collapsed from 3→2 states (HIDDEN, INTERACT_PROMPT); resolver pseudocode shows null guard + simplified branching.
- §C.5 Coord items: removed item #2 (TAKEDOWN_CUE amendment WITHDRAWN); added items #2b (Settings #23 dep), #2c (HSS #19 dep), #7 (Input GDD CR-21 contract); rolled-up summary updated.
- Stealth AI removed from §C.5 Interactions matrix (was inbound; now forbidden non-dep at MVP).
- Bidirectional consistency check updated.
- Cluster D edge cases pruned (removed TAKEDOWN_CUE-related cases).
- Cluster F LOAD_FROM_SAVE init list updated.
- §V.4 coroutine pseudocode aligned with §C.4 (caller responsibility for gate check).
- F.5 footnote "Why dry-fire flash is NOT rate-gated" REMOVED.
- OQ-HUD-7 closed (Path A finalised, no MVP implementation surface).
- OQ-HUD-8 NEW (AccessKit Day-1 default behaviour + screen-reader regression for consolidated ammo Label).

### Coord items status (post-REV-2026-04-26)

**BLOCKING (7)**: ADR-0002 amendment for `ui_context_changed`; Settings #23 Day-1 minimal UI; HSS #19 Day-1 alert-cue minimal slice; ADR-0004 Gate 1 (`accessibility_live`) + Gate 2 (Theme inheritance); Godot 4.6 API verification batch (with focus_mode dual-focus item); OQ-HUD-5 F.5 measurement (`C_label`, `C_draw`, `C_poll`, `C_theme_override`, `C_a11y`); Input GDD CR-21 rebinding contract.

### Why third re-review is required

The REV-2026-04-26 in-session pass addressed all 15 BLOCKING themes from the re-review, applied all 4 user-adjudicated decisions, and propagated coord-item fixes into the spec body. **However**, the creative-director's senior verdict explicitly warned that patch-iteration in this state risks introducing new defects. A fresh-session `/design-review design/gdd/hud-core.md` is required to verify the REV-2026-04-26 pass did not itself introduce new contradictions (the same pattern as REV-2026-04-25). The OQ-HUD-5 measurement gate remains a BLOCKING sprint gate independently of GDD review status.

### Files modified in REV-2026-04-26

- `design/gdd/hud-core.md` — primary revision target (~30 distinct edits across 22 sections; doc grew from 1,234 to ~1,350 lines).
- `design/gdd/reviews/hud-core-review-log.md` — this entry.
- `design/gdd/systems-index.md` — pending update (status remains NEEDS REVISION; comment refreshed).

### Next session

Run `/clear` then `/design-review design/gdd/hud-core.md` to re-review REV-2026-04-26 with clean context. Expected outcome: if no new contradictions were introduced and OQ-HUD-5 measurements have been performed, verdict should be APPROVED or NEEDS MINOR REVISION. If the pattern repeats (review introduces new defects faster than they close), escalate per producer to pair-authoring per creative-director directive.

---

## Closure decision — 2026-04-26 — Status: APPROVED (without third re-review)

**Decision**: User explicitly chose "Accept revisions and mark Approved, skip re-review" at the close of the REV-2026-04-26 second-pass session. This was the **non-recommended option** in the closing widget — the recommended option was "Re-review in a new session" per the creative-director's senior verdict.

**Recorded for audit trail (per creative-director directive in the senior verdict)**:

> "Two consecutive MAJOR REVISION verdicts is the team's early warning that solo patch-iteration on this document has stalled... do not put HUD Core back in queue for a fourth review until the author confirms a single uninterrupted re-author session (not patch-to-checklist) has occurred. If a third pass also lands at MAJOR REVISION, escalate to pair-authoring."

The user's decision overrides this recommendation. The HUD Core GDD ships with **APPROVED** status from this session, but with the following caveats encoded in the GDD header and the systems-index:

1. **7 BLOCKING coord items remain open** (ADR-0002 amendment for `ui_context_changed`; Settings #23 + HSS #19 minimal-UI MVP deps; ADR-0004 Gate 1 + Gate 2; Godot 4.6 API verification batch; OQ-HUD-5 F.5 measurement; Input GDD CR-21 contract) — these are independent of GDD review status and must close before sprint planning.
2. **Producer is instructed (per creative-director directive)** to schedule a smoke `/design-review` on the spec at the start of HUD Core sprint planning, to catch any contradictions the REV-2026-04-26 pass introduced but did not surface (the documented pattern from REV-2026-04-25).
3. **Production-risk signal**: REV-2026-04-25 introduced new BLOCKING items while closing prior ones; the same risk applies to REV-2026-04-26. The audit trail preserves this signal so future sessions can honestly evaluate whether HUD Core sprint-time defects originated in the GDD or in implementation.

**Signed off**: User (decision authority); recorded by `/design-review` skill on 2026-04-26.

---
