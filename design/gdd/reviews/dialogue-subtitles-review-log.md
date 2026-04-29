# Dialogue & Subtitles — Design Review Log

## Review — 2026-04-28 — Verdict: MAJOR REVISION NEEDED → Revisions Applied → Approved (v0.2)

**Scope signal:** L (multi-system integration; 16 declared dependencies; 5 formulas; BLOCKING amendments to ADR-0002, ADR-0004, ADR-0008, Audio GDD, Settings GDD, MLS GDD, LSS GDD; new Writer Brief deliverable required.)

**Specialists:** game-designer, systems-designer, narrative-director, ux-designer, audio-director, godot-specialist, qa-lead, accessibility-specialist, localization-lead, creative-director (senior synthesis).

**Blocking items:** 26 (10 author-flagged in §F.6/§Q.1 + 16 specialist-found)
**Recommended items:** ~30 (high-value; ~20 applied in v0.2; 5 deliberately deferred)

**Summary:**

The author shipped a disciplined v0.1 (1,214 lines, 51 ACs, 10 self-flagged BLOCKING coord items + 17 OQs) but adversarial review surfaced 16 additional BLOCKING items concentrated in: (a) Pillar 1 structural risks in dense encounters and the V.2 Radiator vignette; (b) cross-system contract failures with the Audio GDD (AudioStreamPlayer ownership conflict, VO file naming mismatch, technically-incorrect AudioEffect-on-player timbral shaping); (c) WCAG falsified compliance claims (SC 1.4.4 1.25× ≠ 200%; SC 1.2.2 violated by MVP speaker-label suppression; SC 1.4.12 absent); (d) state-machine completeness gaps (boot-window null guard, interrupt cleanup, play() failure escape hatch, SUPPRESSED-while-line-started row); (e) localization defects that would manifest the day a 2nd locale ships (mid-bark mismatch, hardcoded delimiter, missing-key policy, accessibility_name composition).

User chose all four **Recommended packages** in the design-decision widget (Pillar 1 resolver hardening, single-audio-file Radiator structure, pre-baked timbral architecture, full WCAG compliance package). All 26 blockers were resolved inline as v0.2 amendments: 8 CR amendments, 4 new CRs (CR-DS-21 watchdog, CR-DS-22 locale deferral, CR-DS-23 missing-key policy), 1 new FP (FP-DS-21 zero-length audio reject), state-machine row addition, taxonomy re-bucketing, content-rule corrections (MVP-2 PATROL_AMBIENT → SCRIPTED_SCENE 7b), Settings knob registrations (XL=2.0, line/letter spacing), accessibility composition pattern, scrim worst-case annotation, Audio GDD amendment text strengthening, AC bounds and split.

**Specialist disagreements resolved:**
- VG-DS-2 implementation timing → godot-specialist correct (verify-first; no placeholder).
- VG-DS-4 interrupt-flag guard → godot-specialist correct (implement unconditionally; zero cost).
- CIVILIAN_REACTION priority bucket → narrative-director correct (re-bucketed to ESCALATION; affronted-Parisian register is Pillar-1 primary, outranks IDLE).

**Items deferred to post-MVP / VS playtest (RECOMMENDED, non-blocking for v0.2):**
- HoH replay-buffer omission (Pillar 5 stance retained pending advocacy escalation).
- AccessKit polite-vs-assertive for SPOTTED-bucket lines (defer to VS playtest with SR users).
- F.5 density safety margin re-calibration (defer to first VS playtest).
- Eve hurt-sound / exertion-grunt Voice-bus interaction (defer to Audio Director coordination during VS).
- German character-budget for translators (defer to localization-lead's translator brief, post-MVP).

**Forward-dependency status snapshot at v0.2 close:**
- **BLOCKING coord items remain open** (§F.6 unchanged in count; #5 strengthened): Audio GDD §F amendment (now with explicit replacement text) / Settings GDD knob registrations (now 4: XL preset + line spacing + letter spacing + speaker_labels-default-MVP) / MLS GDD scripted_dialogue_trigger contract / LSS GDD quick-load + Audio-init-order + new single-instance-guarantee / ADR-0002 amendment / ADR-0008 amendment / ADR-0004 Gates 1+2 / **dialogue-writer-brief.md** (new file, required separately from document-writer-brief.md, with explicit deliverables a–e).
- **Engine verification gates** (VG-DS-1..5) remain ADVISORY pending in-editor checks; VG-DS-2 reinforced as load-bearing for AccessKit ship.

**Prior verdict resolved:** First review (no prior log).

**Files modified:**
- `design/gdd/dialogue-subtitles.md` (added "Revision Notes — 2026-04-28 Design Review (v0.2)" section ~75 lines + ~10 in-place CR amendments + 4 new CRs + 1 new FP + 2 new ACs / 1 split AC = ~1.6 KB net additions to the 127 KB file)
- `design/gdd/systems-index.md` (row 18 status updated to APPROVED 2026-04-28 v0.2)
- `design/gdd/reviews/dialogue-subtitles-review-log.md` (this file, NEW)

**Recommended next step:**

User accepted v0.2 revisions and marked Approved without re-review. A re-review in a fresh session is still recommended before VS sprint planning to validate the v0.2 amendments with clean specialist context — especially the queue-rewrite (priority-aware replacement) and the new CR-DS-21 watchdog logic, which were not present at the original review and are large enough to warrant adversarial scrutiny on their own merits.

Triage order for re-review (creative-director recommended): (1) verify Audio GDD amendment is wired bidirectionally; (2) Pillar 1 fixes hold under specialist re-read; (3) WCAG claims now defensible; (4) state-machine completeness; (5) localization fallbacks; (6) AC fixes carry through to test plan.

---

## Review — 2026-04-28 (re-review, fresh session) — Verdict: MAJOR REVISION NEEDED → v0.3 surgical patches applied → NEEDS REVISION (Phase 2 propagation pending)

**Scope signal:** L (load-bearing structural process failure: v0.2 self-tracker amendments were never propagated to sibling docs; ~20 in-doc surgical patches applied + 8 sibling-doc amendments queued for Phase 2; net 51→57 ACs / 40→44 BLOCKING; estimated 1–1.5 working days for Phase 2 cycle).

**Specialists:** game-designer, systems-designer, narrative-director, ux-designer, audio-director, godot-specialist, qa-lead, accessibility-specialist, localization-lead, creative-director (senior synthesis). All 9 specialists + creative-director re-spawned in fresh session — none had v0.1 review context, ensuring adversarial independence.

**Blocking items:** 13 (highest-impact distilled from creative-director's triage of all specialist findings)
**Recommended items:** 15 (in-doc surgical patches; all applied in v0.3)
**Specialist disagreements adjudicated by user:** 4 (D1 grace window / D2 voice duck / D3 ADR-0008 slot / D4 speaker labels MVP)

**Summary:**

The v0.2 GDD's *internal content* was largely sound — the v0.2 26-item amendment table represented real, considered work. The reason this re-review failed is a process failure: **v0.2 was sealed as "Approved" before the bidirectional contracts it self-asserted were actually written into the sibling docs**. Pre-confirmed empirical findings via grep (NOT specialist claims): (a) Audio GDD L67-68/L214/L217/L394/L414 still contain v0.1 conflicting text — the row replacement v0.2 §F.6 #5 explicitly mandated was never written; zero occurrences of `voice_overlay_duck_db` anywhere in Audio GDD; (b) Settings GDD has zero occurrences of `subtitle_size_scale`, `subtitle_speaker_labels`, `subtitle_line_spacing_scale`, `subtitle_letter_spacing_em`, `XL`, or `S=0.8`; (c) MLS GDD has no `scripted_dialogue_trigger` mention; (d) LSS GDD has no D&S coordination entries at all; (e) `design/narrative/dialogue-writer-brief.md` does NOT exist (only `document-writer-brief.md` is present); (f) ADR-0008 §85 + §239 places D&S in **Slot 8 pooled (0.8 ms with CAI/MLS/DC/F&R/Signal-Bus)**, NOT Slot 7 — the GDD body in v0.2 made a factually wrong claim throughout; (g) ADR-0002 has no `scripted_dialogue_trigger` amendment.

**Specialist findings additional to the process failure:**

- **audio-director**: −6 dB Voice duck is below broadcast intelligibility floor (industry −18 to −20 dB); §C.11 pre-baked timbral architecture has unquantified production overhead (40 individually mastered stems); CR-DS-21 watchdog 30 s floor produces 31 s mix degradation on sub-second-line failures.
- **ux-designer**: WCAG SC 1.4.4 XL=2.0 truncates 12-word lines (54-char ceiling at 56 px Courier / 896 px / 2-line cap); AC-DS-12.5 referenced in §V.1 is a dangling pointer (does not exist); all H.12 ACs are ADVISORY despite covering core WCAG; §G.2 knob table contradicts §C.10 internally.
- **accessibility-specialist**: §C.12 AccessKit composition has **SR-equity-breaking bug introduced by v0.2 itself** — `accessibility_name = ... + _label.text` reads the raw KEY string under `auto_translate_mode = ALWAYS`, so SR users hear "vo.banter.guard_radiator_a" key path instead of the resolved sentence; HoH replay buffer omission is undocumented as accessibility regression; WCAG SC 1.4.12 covers only 2 of 4 criteria (word spacing absent).
- **godot-specialist**: VG-DS-2 string `"polite"` is almost certainly wrong type (Godot 4.x convention is integer enum `Control.AccessibilityLive.POLITE`); CR-DS-22 references `TranslationServer.locale_changed` signal that may not exist in 4.6; CR-DS-21 watchdog Timer missing from §C.3 scene tree; watchdog handler doesn't call `_audio_player.stop()`; ADR-0008 Slot 7 vs Slot 8 confirmed as factual contradiction.
- **systems-designer**: F.1 `audio_duration_s` 30 s ceiling incoherent with CR-DS-20 12-word cap (~12-15 s max for banter); F.3 null-guard polarity mismatch (CR-DS-9 fails CLOSED at boot, F.3 says fails OPEN); ADR-0008 slot misalignment confirmed; F.5 density formula non-binding; CR-DS-21 30 s floor over-conservative.
- **narrative-director**: `dialogue-writer-brief.md` confirmed missing — VS sprint is BLOCKED, not unblocked; V.2 Radiator is structurally distinct from V.1/V.3 (Eve is causal — reactive comedy, not pure ambient); pause spec for V.2 has no field on `DialogueLine.tres`; CIVILIAN_REACTION re-bucketing creates Restaurant Margaux Bit interruption risk (untested).
- **qa-lead**: 18+ AC defects identified; AC-DS-13.2 still says "PATROL_AMBIENT" after v0.2 re-categorization; 5 missing ACs for new v0.2 CRs (CR-DS-21 / 22 / 23 / FP-DS-21); AC-DS-2.3/5.1 wall-clock tolerance violates determinism rule; AC-DS-9.1 v0.2 reframe contradicts BLOCKING tag; AC-DS-3.4 grep over-broad; AC-DS-7.4 tautological; AC-DS-11.x missing test-dir exclusion.
- **localization-lead**: `vo.*` namespace inconsistent with Localization Scaffold's `dialogue.*` domain prefix; CR-DS-16 hardcoded LTR composition breaks BiDi for RTL locales; CR-DS-22 race conditions; §C.12 `accessibility_name` locale staleness on mid-bark switch; production-build detection mechanism unspecified.
- **game-designer**: 2-second grace window (v0.2) protects only 28-40% of typical 5-7 s CURIOSITY_BAIT bark; queue race conditions (silent ESCALATION drop + grace+queue interaction undefined); CIVILIAN_REACTION re-bucketing untested against V.1; speaker labels default ON contradicts §B.3 "if shown at all"; F.5 NOLF1 reference is empirically ungrounded.

**4 user-adjudicated design decisions:**
- **D1 — CR-DS-6 grace window:** **Full-bark protection** (only SCRIPTED interrupts CURIOSITY_BAIT). Closest to original Stealth AI L91 spirit; protects V.2 Radiator vignette absolutely.
- **D2 — CR-DS-17 Voice duck depth:** **−12 dB** (was −6 dB). Doubles depth toward broadcast intelligibility floor; playtest-tunable.
- **D3 — ADR-0008 slot assignment:** **GDD body updated to Slot 8 pooled** (matches ADR-0008 §85 + §239; cheaper than amending ADR-0008 to relocate D&S).
- **D4 — Speaker labels MVP policy:** **Default ON + emergency Settings UI toggle at MVP-Day-1** (preserves WCAG SC 1.2.2 + restores player agency; promotes Settings UI toggle from VS to MVP).

**v0.3 surgical patches applied (in-doc only):** ~20 patches per the Revision Notes table at the top of `dialogue-subtitles.md`. Highlights: full-bark grace; −12 dB Voice duck; Slot 7→Slot 8 throughout (§A Overview, F.4, §C.15 row 15, §G.4, AC-DS-9.1, §F.6 #2, F.3 ADR-Locked, EC-DS-4); CR-DS-15 MVP UI toggle; AC-DS-13.2 SCRIPTED_SCENE 7b correction; §G.2 stale knob table updated; §C.12 SR-equity composition bug fixed (`tr(_current_text_key)` not `_label.text`); F.3 null-guard polarity made explicit; F.1 banter cap 15 s vs SCRIPTED 30 s; CR-DS-21 watchdog floor 30s→5s + stop() added; §C.3 scene tree adds WatchdogTimer; DialogueLine schema gains `performance_notes` field; F.5 reclassified advisory heuristic; AC-DS-2.3/5.1 frame-count + mock-clock determinism note; §H.12 ACs upgraded ADVISORY→BLOCKING; AC-DS-9.1 BLOCKING→ADVISORY; new ACs AC-DS-1.5 (FP-DS-21) / 2.6 (CR-DS-21) / 7.5 (CR-DS-22) / 7.6 (CR-DS-23) / 12.5 (per-section opaque QA gate) / 12.6 (XL truncation gate); AC-DS-3.4 `_caption_suppressed` rename; AC-DS-7.4 schema-check reframe; AC-DS-11.1/11.5 `--exclude-dir=tests`; §B.3 #5 phrasing updated; §B.5 V.2 marked "complicit eavesdrop" sub-type. Net AC count: 51→57; BLOCKING: 40→44.

**Phase 2 sibling-doc propagation cycle (BLOCKING for VS sprint planning):**
- P1 — Audio GDD §F.1 amendment (L214 row replacement + L67-68/L217/L394 prose corrections + register `voice_overlay_duck_db = -12.0` + Voice-bus duck-exception table + remove `vo_[speaker]_[line].ogg` naming reference)
- P2 — Settings GDD: register 6 knobs (`subtitles_enabled` MVP, `subtitle_size_scale` MVP with XL=2.0, `subtitle_background` MVP, `subtitle_speaker_labels` **MVP UI toggle** per D4, `subtitle_line_spacing_scale` MVP, `subtitle_letter_spacing_em` MVP) + boot-time burst + `setting_changed` emit-site contract
- P3 — MLS GDD: declare authoring contract for `scripted_dialogue_trigger(scene_id: StringName)` MLS-publish signal + per-section scene_id roster
- P4 — LSS GDD: EC-DS-2 (quick-load `_exit_tree` fires before scene swap) + EC-DS-3 (Audio init before D&S init at section load) + new single-instance guarantee
- P5 — ADR-0002 amendment: add `scripted_dialogue_trigger(scene_id)` MLS-domain signal
- P6 — ADR-0008 amendment: register D&S Slot 8 sub-claim 0.10 ms peak event-frame
- P7 — ADR-0004 Gates 1 (`accessibility_live` property name + value type, 20-min in-editor verification — flagged BLOCKING by godot-specialist) + 2 (Theme inheritance prop name)
- P8 — `design/narrative/dialogue-writer-brief.md` (NEW FILE — VS BLOCKING; per-section line roster + per-speaker voice profile + 2-3 sample lines + VT-3..VT-8 enforcement guidance + per-state minimum-line-count + V.2 pause-timing spec + `[STERLING.]` Eve register convention + locale-equivalent humor for Margaux Bit)

**Items deferred to VS playtest / future amendments (RECOMMENDED, non-blocking):**
- CIVILIAN_REACTION re-bucketing playtest validation against V.1 Margaux Bit interruption
- CJK/RTL font coverage plan (post-MVP)
- HoH replay buffer ADR (Pillar 5 rationale documented; revisit if accessibility advocacy escalates)
- AccessKit polite-vs-assertive for SPOTTED bucket (defer to VS playtest with SR users)
- WCAG SC 1.4.12 word-spacing (≥0.16em) — currently unaddressed; post-MVP if Godot exposes the property
- F.5 density safety margin re-calibration vs NOLF1 reference (defer to first VS playtest)
- `vo.*` namespace reconciliation with Localization Scaffold `dialogue.*` domain prefix (Phase 2 propagation tail)

**Forward-dependency status snapshot at v0.3 close:**
- Phase 2 propagation cycle (8 sibling-doc amendments) is the gate to VS sprint planning. None of v0.2's BLOCKING coord items can be considered resolved until Phase 2 lands.
- Engine verification gates upgraded: VG-DS-2 (`accessibility_live` enum) + CR-DS-22 (`TranslationServer.locale_changed` signal existence) re-flagged from ADVISORY to **BLOCKING** for VS sprint.

**Prior verdict resolved:** v0.2 verdict (Approved) is **superseded** by v0.3 status (NEEDS REVISION pending Phase 2 propagation). v0.2 was prematurely sealed; the sealing did not catch the bidirectional propagation gap.

**Files modified (v0.3 session):**
- `design/gdd/dialogue-subtitles.md` (added "Revision Notes — 2026-04-28 Re-Review (v0.3)" section ~120 lines + ~22 in-place inline edits across §A Overview / §B.3 / §B.5 / CR-DS-6 / CR-DS-7 / CR-DS-15 / CR-DS-17 / CR-DS-21 / §C.3 scene tree / §C.4 schema / §C.10 / §C.12 / §C.14 / §C.15 / §C.16 / F.1 / F.3 / F.4 / F.5 / §F.6 / §G.2 / §G.4 / §H.1 / §H.2 / §H.3 / §H.5 / §H.7 / §H.9 / §H.10 / §H.11 / §H.12 / §H summary / §Q.1 / J.4 / EC-DS-4 / F.3 ADR Dependencies row / DC-WB row 16 — net ~6 KB additions)
- `design/gdd/systems-index.md` (row 18 status NEEDS REVISION + v0.3 patch summary)
- `design/gdd/reviews/dialogue-subtitles-review-log.md` (this entry)

**Recommended next step:**

User accepted Option A (Surgical v0.3 + propagation cycle) in re-review session 2026-04-28. v0.3 in-doc patches now complete. **Next**: execute Phase 2 sibling-doc propagation cycle in a fresh session (recommended `/clear` before starting; estimated 1–1.5 working days). Order: Audio GDD → Settings GDD → ADR-0008 amendment → ADR-0002 amendment → MLS/LSS GDD entries → ADR-0004 Gates 1+2 verification → `dialogue-writer-brief.md` authoring (largest single doc — own session). Then re-review in fresh session before VS sprint planning.
