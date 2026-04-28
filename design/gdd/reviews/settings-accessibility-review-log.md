# Review Log — `settings-accessibility.md`

This file tracks the revision history of `design/gdd/settings-accessibility.md`. Append-only log; newest entries at top.

---

## Review — 2026-04-27 — Verdict: NEEDS REVISION → REVISIONS APPLIED → APPROVED (user-accepted, skipped re-re-review)
Scope signal: XL
Specialists: game-designer, systems-designer, ux-designer, accessibility-specialist, audio-director, godot-specialist, performance-analyst, qa-lead, localization-lead, creative-director (synthesis)
Blocking items: 9 | Recommended: 12 ADVISORY clusters | AC reclassifications: 3
Prior verdict resolved: Yes (post-revision verification of 2026-04-26 PM MAJOR REVISION → 17 BLOCKING resolved → user accepted, skipped re-review). This re-review surfaced that 11 of 17 prior items were genuinely resolved, 4 cosmetically patched (concentrated in Theme 1 close-as-confirm propagation), 2 still open (AccessKit Gates carry forward).

### Summary

`/design-review` ran in full mode against the 1302-line post-2026-04-26-PM-revision GDD. Nine adversarial specialist reviews + creative-director synthesis converged on **NEEDS REVISION** (not MAJOR REVISION NEEDED — the bones were sound but the prior revision pass had propagation gaps). The CD synthesis identified Theme 1 (F.3 ↔ CR-15 close-as-confirm contradiction) as the load-bearing defect: the same defect family that drove the prior MAJOR REVISION verdict had been patched at CR-15 + new ACs but not propagated to F.3, Cluster D, AC-SA-4.6 — 8 of 9 specialists independently flagged this, and CD ruled "approving a recurrence erodes the gate's meaning." 9 BLOCKING items + 12 ADVISORY clusters surfaced; user chose to revise in same session.

User adjudicated 4 design decisions via AskUserQuestion: (Q1) CR-25 preserve all 3 photosensitivity safety cluster keys (was dismissed-flag-only); (Q2) Settings amends `clock_tick_enabled` to `accessibility` category to match Audio GDD's existing handler; (Q3) use existing `tr("INPUT_ACTION_NAME_<ACTION>")` pattern as primary (drop invented `Input.get_action_display_name()`); (Q4) escalate 0 dB six-bus clipping as BLOCKING-coord with Audio GDD.

### Specialist verdicts (raw)

| Specialist | Verdict |
|---|---|
| game-designer | NEEDS REVISION (5 BLOCKING / 6 ADVISORY) — Theme 1 (F.3) load-bearing; Cluster I stale; CR-25 misleading copy; KEY_Q conflict risk |
| systems-designer | CONDITIONAL PASS (3 BLOCKING / 5 ADVISORY) — F.3 contradiction, F.1 inverse default branch, F.1 NaN claim mathematically wrong |
| ux-designer | CONDITIONAL PASS (2 BLOCKING / 7 ADVISORY) — F.3 propagation; CR-25 photosensitivity safety copy gap |
| accessibility-specialist | CONDITIONAL READY (2 BLOCKING / 12 ADVISORY) — F.3 propagation; AC-SA-5.3 reclassification; 4 prior safety-critical items genuinely resolved (S-1/S-2/S-3/S-4) |
| audio-director | CONDITIONAL PASS (4 BLOCKING / 7 ADVISORY) — 0 dB clipping (was incorrectly demoted to ADVISORY in 2026-04-26 PM); F.3 propagation; F.1 silence-sentinel mute gap; clock_tick category mismatch |
| godot-specialist | CONDITIONAL READY (2 NEW BLOCKING + 2 prior STILL OPEN / 4 ADVISORY) — F.3 propagation; invented `Input.get_action_display_name` API; AccessKit Gates 1+2 carry forward |
| performance-analyst | CONDITIONAL PASS (1 NEW BLOCKING + 1 prior COSMETIC / 4 ADVISORY) — F.3 propagation; CR-8 drag_ended GENUINELY RESOLVED; AC-SA-2.6 SIGKILL still cosmetic |
| qa-lead | CONDITIONAL PASS (4 BLOCKING / 5 ADVISORY + 4 coverage gaps) — F.3 propagation; Cluster I; AC-SA-5.3/10.4/11.7 reclassifications; AC-SA-6.4 InputMap isolation infeasible |
| localization-lead | CONDITIONAL READY (3 NEW BLOCKING + BLK-3 + BLK-4 still defective / 5 ADVISORY) — invented Input API; OptionButton item label tr-keys; SETTINGS_NAV_DEAD_END untranslatable single-key; accessibility description briefing category |
| creative-director (synthesis) | **NEEDS REVISION** (token CD-GDD-ALIGN: REJECT) — "the bones are sound; the scrub was incomplete" — 4 cosmetic patches concentrated in Theme 1; recommended half-day revision pass |

### Convergent themes (multiple specialists independently flagged)
- **Theme 1 — F.3 ↔ CR-15 ↔ AC-SA-11.10 ↔ Cluster D ↔ AC-SA-4.6 close-as-confirm contradiction** (8 of 9 specialists) — the load-bearing recurrence
- **Theme 2 — Cluster I dual-discovery stale text** contradicts single-canonical-home (3 specialists)
- **Theme 3 — CR-25 photosensitivity safety modal copy is misleading** (ux-designer + accessibility-specialist)
- **Theme 6 — `clock_tick_enabled` cross-GDD category mismatch** (audio-director) — silent runtime failure pre-revision
- **Theme 7 — `Input.get_action_display_name()` invented API** (godot-specialist + localization-lead independently)
- **Theme 8 — AC-SA-5.3 misclassification** (accessibility-specialist + qa-lead)
- **F.1 inverse default branch + NaN claim + silence sentinel mute** (systems-designer + audio-director)
- **0 dB six-bus clipping** (audio-director — was demoted incorrectly in 2026-04-26 PM)

### Creative-director adjudications (binding)
- F.3 close-as-confirm propagation → **BLOCKING-1** — load-bearing; 4 sites must align with CR-15 + AC-SA-11.10
- 0 dB clipping ownership → BLOCKING-coord with Audio GDD (not BLOCKING-fix-in-Settings)
- AC-SA-2.6 SIGKILL durability → godot-specialist correct on engine fact (Godot 4.6 ConfigFile.save() doesn't fsync); claim must add `OS.execute("sync")` OR be reworded as best-effort
- "Approved 2026-04-26 PM" status not defensible → roll back to "In Revision" (recommended; user chose to revise in-session and re-Approve)

### Revisions applied (9 BLOCKING + 12 ADVISORY clusters)

Doc grew 1302 → 1339 lines (+37). New section structure: 89 → 91 H2/H3 headers. 65 ACs across 11 groups (49 BLOCKING / 16 ADVISORY → 52 BLOCKING / 13 ADVISORY via 3 reclassifications). 12 → 14 BLOCKING coord items.

**Theme 1 close-as-confirm propagation (4 sites)**:
- F.3 panel-close behavior block (lines 567-570) — rewrote to close-as-confirm
- F.3 variable table `T_revert_timeout` default — 10.0 → 7.0
- F.3 mid-timer rule + example — replaced hardcoded "10-second window" with variable reference
- Cluster D first bullet — rewrote to match close-as-confirm
- AC-SA-4.6 — rewrote test from close-as-revert to close-as-confirm; evidence file rename

**Theme 2 Cluster I dual-discovery stale text**:
- Lines 720-721 rewritten to single-canonical-home description with cross-references to AC-SA-5.8/8.1/9.1

**Theme 3 CR-25 photosensitivity safety cluster**:
- CR-25 step 2 expanded EXCEPT clause to preserve all 3 keys (`photosensitivity_warning_dismissed`, `damage_flash_enabled`, `damage_flash_cooldown_ms`)
- Modal copy "preferences" plural (was singular)
- AC-SA-11.1 revised to test cluster preservation
- AC-SA-11.2 revised to verify all 3 keys (was dismissed-flag-only)
- AC-SA-11.4 modal copy text updated

**Theme 4 `clock_tick_enabled` category move**:
- C.2 line 178: removed from `audio` category
- C.2 line 180: added to `accessibility` category with rationale
- G.1: removed `clock_tick_enabled` row (now 6 knobs, was 7)
- G.3: added `clock_tick_enabled` row with cross-GDD coord note
- AC-SA-3.4: updated to listen on `accessibility` category

**Theme 5 0 dB clipping coord**:
- §F coord items rolled up — added OQ-SA-14 BLOCKING (was ADVISORY in prior revision)
- G.1: warning at top of section that defaults are TENTATIVE pending Audio GDD coord
- All six bus default rows annotated with "(tentative — see coord #17)" — corrected to "see coord #14" upon final numbering

**Theme 6 F.1 inverse default branch**:
- Default branch return value 0 → 1 (sub-Segment-A audible-but-quiet hand-edited cfg now maps to minimum audible, not silence sentinel + bus mute)
- AC-SA-11.13 expanded with sub-AC verifying dB = -50.0 returns p = 1

**Theme 7 F.1 NaN handling**:
- F.1 forward formula: explicit `is_nan()` precondition added before clamp
- F.1 inverse formula: explicit `is_nan()` precondition added before clamp
- AC-SA-11.13: revised to verify both `is_nan()` AND clamp behaviors (clamp alone insufficient per IEEE 754)

**Theme 8 F.1 silence sentinel mute**:
- F.1 forward formula: `AudioServer.set_bus_mute(bus_idx, true)` at p=0; symmetric unmute on p=0 → p>0 transition
- AC-SA-3.2: revised to verify both volume emit AND mute call

**Theme 9 invented API**:
- C.5 line 306 (formerly fallback): pattern `tr("INPUT_ACTION_NAME_<ACTION>")` promoted to primary
- C.5 modifier feedback row updated with `{key_label}` typing clarification
- §F coord item #7: removed `Input.get_action_display_name()` reference
- OQ-SA-11: revised to specify `tr()` pattern; lookup at point-of-use
- C.5 modifier feedback copy: "yet" removed per Stage Manager register; copy is now "Modifier keys ignored. Bound as: {key_label}."

**AC reclassifications**:
- AC-SA-5.3: [UI] ADVISORY → BLOCKING (in-session UI WCAG 2.3.1 floor — load-time clamp at AC-SA-5.2 does not cover live-preview drag emits)
- AC-SA-10.4: [UI] ADVISORY → [Integration] BLOCKING (modal non-auto-dismiss safety — WCAG 2.3.1 chain)
- AC-SA-11.7: [Logic] ADVISORY → BLOCKING (Tab order Day-1 keyboard nav per ADR-0004 IG10)

**Localization fixes**:
- C.4 line 258: `SETTINGS_NAV_DEAD_END` split into `SETTINGS_NAV_DEAD_END_TOP` + `SETTINGS_NAV_DEAD_END_BOTTOM` (single key + "respectively" untranslatable)
- AC-SA-11.8: revised to reference both new keys
- C.5 modifier feedback copy: "aren't supported yet" → "ignored" (Stage Manager register fix)

**New OQs**:
- OQ-SA-13 [BLOCKING for sprint]: Audio GDD `clock_tick_enabled` category alignment validation (5-min cross-check)
- OQ-SA-14 [BLOCKING for sprint]: Audio GDD six-bus 0 dB clipping risk resolution (Master limiter OR sub-bus defaults at -3/-6 dB)

**§F coord items expanded**: 12 → 14 BLOCKING + 4 ADVISORY (with #16 localization expanded to cover new VS-readiness gaps; #18 added to flag CR-22 KEY_Q tentative pending Input GDD authoring)

### Items NOT addressed in this revision (deferred / known gaps)

- **Prior BLOCKING-3 still open**: AccessKit Gates 1+2 (OQ-SA-4) — `accessibility_*` property names + Theme `base_theme` vs `fallback_theme` need real Godot 4.6 editor inspector verification. Carries forward.
- **AC-SA-2.6 SIGKILL durability claim**: cosmetically softened in 2026-04-26 PM revision; godot-specialist re-flagged that Godot 4.6 ConfigFile.save() doesn't fsync. Not addressed in this revision pass — needs separate decision (add `OS.execute("sync")` or rephrase as best-effort).
- **AC-SA-6.4 InputMap isolation infeasibility**: F.4 has no injectable signature; isolation in unit test requires global InputMap snapshot/restore (failing project's test-isolation rules). Flagged as ADVISORY by qa-lead; not BLOCKING.
- **Stage Manager copy concerns** (CR-18 "This notice can be reviewed again" instructional UX, 7s revert timeout for accessibility-impacted users): flagged ADVISORY by game-designer; deferred for separate copy polish pass.
- **Coverage gaps** (qa-lead GAP-1 through GAP-4): corrupted [controls] InputEvent recovery, keyboard-only modal dismissal, Restore Defaults read-only fs, non-empty non-matching GPU adapter — all ADVISORY new ACs to be added in separate AC expansion pass.

### Outcome

User accepted revisions and skipped post-revision re-re-review per AskUserQuestion. systems-index.md row 23 status updated from "Approved 2026-04-26 PM" to "Approved 2026-04-27" with full re-review notes; prior 2026-04-26 PM entry preserved beneath. **14 BLOCKING coord items remain OPEN and BLOCK sprint planning regardless of GDD review status.**

### Next steps (forward dependencies awaiting closure)

- Audio GDD revision (NEW): close OQ-SA-13 (`clock_tick_enabled` category cross-check) + OQ-SA-14 (define Master limiter or lower sub-bus defaults to -3/-6 dB)
- Combat GDD revision: weapon-roster max RPM declaration + screen-shake/bloom gating + EHF subscription + acknowledge CR-22 (KEY_Q tentative pending Input GDD)
- HUD Core GDD revision: rewire `_on_setting_changed` filter to `accessibility` for `crosshair_enabled`; render cross-reference label
- ADR-0007 amendment: register slot #8
- ADR-0002 amendment: register `settings_loaded` signal + `settings` domain
- ADR-0004 Gates 1 + 2 verification: real Godot 4.6 editor inspector check (PRIOR BLOCKING — carries forward)
- Outline Pipeline GDD: expose `get_hardware_default_resolution_scale()` query API
- Input GDD revision: register separate `use_gadget` + `takedown` actions (with Q tentative); register `tr("INPUT_ACTION_NAME_<ACTION>")` per user-facing action; document rebind boot pattern
- Menu System GDD authoring: `_boot_warning_pending` poll + modal scaffold (CR-18 + CR-24)
- `design/ux/accessibility-requirements.md` authoring: `/ux-design settings-accessibility`
- Localization Scaffold: tr-key splitting (`SETTINGS_NAV_DEAD_END_TOP/BOTTOM`); accessibility description briefing category; OptionButton resolution-scale item label tr() wrapping; `tr_n()` plural rule for revert banner countdown
- Inventory GDD touch-up: CR-4 differentiated default + acknowledge OQ-INV-5/6 closure

---

## Review — 2026-04-26 PM — Verdict: MAJOR REVISION NEEDED → REVISIONS APPLIED → APPROVED (user-accepted)
Scope signal: XL
Specialists: game-designer, systems-designer, ux-designer, accessibility-specialist, audio-director, godot-specialist, performance-analyst, qa-lead, localization-lead, creative-director (synthesis)
Blocking items: 17 | Recommended: 12+ (advisory)
Prior verdict resolved: First review

### Summary

`/design-review` ran in full mode against the freshly-authored 1,146-line GDD (designed earlier 2026-04-26 via `/design-system`). Nine adversarial specialist reviews + creative-director synthesis converged on **MAJOR REVISION NEEDED**. Five issues drove the verdict per CD synthesis: (1) photosensitivity safety floor incomplete (S-1 muzzle-flash WCAG 2.3.1 reframing, S-2 screen-shake/bloom ungated, S-3 modal copy promises non-existent feature, S-4 medically-insufficient re-show condition); (2) F.3 ↔ C.4 internal contradiction ("Keep This Resolution" button referenced in formula, absent from layout); (3) Godot 4.6 dual-focus model unaddressed throughout C.4 + C.5 + C.6 — broken on the project's primary input device; (4) CR-8 write-through hammer (~100 sync disk writes/s during slider drag, AC-SA-2.1 certifying the broken behavior); (5) CR-15 panel-close auto-revert violates the Stage Manager fantasy the GDD self-binds to.

User chose to revise blocking items in the same session. Four design-decision questions adjudicated via AskUserQuestion: (Q1) review-again path → add `[Show Photosensitivity Notice]` button, keep locked copy; (Q2) Restore Defaults → keep at MVP with full behavior + dismissed-flag preservation; (Q3) AccessKit contract → inline summary table + author full spec at `design/ux/accessibility-requirements.md`; (Q4) CR-22 differentiated defaults → `use_gadget = KEY_F`, `takedown = KEY_Q`.

### Specialist verdicts (raw)

| Specialist | Verdict |
|---|---|
| game-designer | NEEDS REVISION (3 BLOCKING / 5 ADVISORY) — fantasy contradictions in CR-15, CR-22, dual-discovery |
| systems-designer | DEFECTS in 3 of 4 formulas + 1 contradiction (5 BLOCKING / 5 ADVISORY) |
| ux-designer | NEEDS REVISION (4 BLOCKING / 7 ADVISORY) — F.3↔C.4 contradiction, Esc-aliasing trap, modifier silent loss |
| accessibility-specialist | NOT READY (4 SAFETY-CRITICAL + 6 FLOOR GAPS / 5 ADVISORY) — WCAG 2.3.1 + 2.1.1 FAIL |
| audio-director | CONDITIONAL PASS (2 BLOCKING / 5 ADVISORY) — F.1 fader math correct; p_knee false knob |
| godot-specialist | 3 BLOCKING + 6 ADVISORY — Godot 4.6 dual-focus, CR-8 hammer, AccessKit Gate 1 |
| performance-analyst | 2 BLOCKING + 4 ADVISORY — CR-8 hammer (≤6 dropped frames/drag), AC-SA-2.6 fsync claim |
| qa-lead | CONDITIONAL PASS (4 BLOCKING AC defects / 3 ADVISORY GAPS) |
| localization-lead | NOT loc-ready for VS (4 BLOCKING / 5 ADVISORY) |
| creative-director (synthesis) | **REJECT — MAJOR REVISION NEEDED** — XL scope; fresh session recommended |

### Convergent themes (multiple specialists independently flagged)
- F.3 "Keep This Resolution" contradiction — systems-designer + ux-designer
- CR-8 write-through hammer — godot-specialist + performance-analyst
- AccessKit Gate 1 unclosable from local docs — godot-specialist + accessibility-specialist + localization-lead
- Modal copy promise vs missing feature — game-designer + ux-designer + accessibility-specialist
- Tab order / focus model gaps — ux-designer + accessibility-specialist + godot-specialist
- AC tag inconsistency on subtitles — 5 specialists flagged
- CR-15 auto-revert UX problem — game-designer + ux-designer

### Creative-director adjudications (binding)
- Dual-discovery `crosshair_enabled` → **BLOCKING — one canonical home (Accessibility)**
- Subtitles default ON → **write-MVP / consume-VS** + CI gate against `false`
- CR-22 shared `F` default → **BLOCKING — defaults must differ**
- CR-15 panel-close-as-revert → **invert to close-as-confirm**

### Revisions applied (17 BLOCKING + 12+ ADVISORY)

Doc grew 1146 → 1302 lines (+156). New section structure: 89 H2/H3 headers (was 84). 65 ACs across 11 groups (was 47 / 10). 12 BLOCKING coord items (was 8). 18 NEW ACs.

**Core Rule changes:**
- CR-8 — write-through replaced with drag_ended commit semantics (eliminates 100 writes/s)
- CR-15 — close-as-confirm + explicit Keep button + revert button + countdown legend
- CR-16 — muzzle flash WCAG 2.3.1 reframed; Combat must declare max RPM
- CR-22 — differentiated defaults (`use_gadget = KEY_F`, `takedown = KEY_Q`)
- CR-23 — split into MVP-write + VS-consume + CI gate
- NEW CR-24 — Show Photosensitivity Notice button
- NEW CR-25 — Restore Defaults full behavior + dismissed-flag preservation
- NEW CR-26 — Locale-format rule for value interpolation
- NEW FP-9 — await forbidden inside `_on_setting_changed`

**Formula fixes:**
- F.1 forward — explicit `clamp(round(p), 0, 100)` precondition
- F.1 inverse — explicit `clamp(dB, -80.0, 0.0)` precondition
- F.2 — discrete-step clamp formula `clamp_to_valid_step()`
- F.4 — alphabetical sort promoted to MVP

**Architecture changes:**
- Single canonical home for `crosshair_enabled` (was dual-discovery) — HUD shows cross-reference label only
- C.4 — Tab order, ui_down/up dead-end with AccessKit announce, dual-focus 4.6 audit, Restore Defaults flow
- C.5 — Esc-cancel disclosure, modifier silent-data-loss feedback, AccessKit per-widget summary table
- C.6 — Player-initiated review path (CR-24), 300-char modal translation ceiling

**AC changes:**
- AC-SA-2.1 — rewritten for drag_ended pattern
- AC-SA-5.7 — split into 5.7a (MVP-write) / 5.7b (CI gate) / 5.7c (VS-consume)
- AC-SA-5.8 + AC-SA-8.1 — consolidated under single-canonical-home model
- AC-SA-6.4 — deterministic with isolated InputMap fixture
- 18 NEW ACs (5.9, 5.10, 11.1-11.14)

**Coord items:**
- 8 → 12 BLOCKING (+ OQ-SA-9 Combat muzzle-flash, OQ-SA-10 dual-focus, OQ-SA-11 action tr-keys, OQ-SA-12 accessibility-requirements.md)
- +1 NEW BLOCKING for HUD Core revision (rewire crosshair filter to accessibility)
- 3 → 4 ADVISORY (added Audio GDD 0 dB headroom confirmation)

**Adjustments:**
- `RESOLUTION_REVERT_TIMEOUT_SEC` default 10 → 7 (per anchor moment)
- `p_knee` locked as structural constant (was misleading tuning knob)
- V.2 modal min_size 240 → 300 (translation slack)
- V.1 Alarm Orange contrast verification ADVISORY added

### Outcome

User accepted revisions and skipped re-review per AskUserQuestion. systems-index.md row 23 status updated from "Designed 2026-04-26" to "Approved 2026-04-26 PM". 12 BLOCKING coord items remain OPEN and BLOCK sprint planning regardless of GDD review status.

### Next steps (forward dependencies awaiting closure)
- Combat GDD revision: weapon-roster max RPM declaration + screen-shake/bloom gating + EHF subscription + acknowledge CR-22
- HUD Core GDD revision: rewire `_on_setting_changed` filter to `accessibility` for `crosshair_enabled`; render cross-reference label
- ADR-0007 amendment: register slot #8
- ADR-0002 amendment: register `settings_loaded` signal + `settings` domain
- ADR-0004 Gates 1 + 2 verification: real Godot 4.6 editor inspector check
- Outline Pipeline GDD: expose `get_hardware_default_resolution_scale()` query API
- Input GDD revision: register separate `use_gadget` + `takedown` actions; tr-key per action; document rebind boot pattern
- Menu System GDD authoring: `_boot_warning_pending` poll + modal scaffold (CR-18 + CR-24)
- `design/ux/accessibility-requirements.md` authoring: `/ux-design settings-accessibility`
- Inventory GDD touch-up: CR-4 differentiated default + acknowledge OQ-INV-5/6 closure

---
