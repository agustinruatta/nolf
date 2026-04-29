# Dialogue & Subtitles

> **Status**: In Design (v0.3 — post re-review surgical patches; sibling-doc propagation pending)
> **Author**: solo (Agustin Ruatta) + agents
> **Last Updated**: 2026-04-28 (post-re-review)
> **Implements Pillar**: 1 (Comedy Without Punchlines) — Primary load-bearing; 5 (Period Authenticity) — Primary supporting; 3 (Stealth is Theatre) — Supporting
> **System #**: 18 | **Tier**: Vertical Slice | **Category**: Narrative
> **Effort**: M

## Revision Notes — 2026-04-28 Re-Review (v0.3)

**Origin:** `/design-review` re-review (fresh session) with 9 specialists + creative-director senior synthesis identified that v0.2's bidirectional amendments were **never propagated to sibling docs** (Audio L214/L217/L394 unchanged; Settings GDD knobs unregistered; MLS/LSS GDDs silent on D&S; `dialogue-writer-brief.md` non-existent; ADR-0008 places D&S in Slot 8 not Slot 7 as the GDD body claimed). Verdict: MAJOR REVISION NEEDED on process grounds, not content. v0.3 applies surgical in-doc patches; sibling-doc propagation cycle is Phase 2.

**Design decisions adjudicated by user (2026-04-28 re-review widget):**

| # | Decision | Outcome |
|---|---|---|
| D1 | CR-DS-6 grace window sizing | **Full-bark protection** — only SCRIPTED interrupts CURIOSITY_BAIT (v0.2's 2.0 s grace replaced with full-vocal carve-out matching original Stealth AI L91 spirit) |
| D2 | CR-DS-17 Voice duck depth during `document_opened` | **−12 dB** (was −6 dB; broadcast intelligibility floor) |
| D3 | ADR-0008 slot assignment | **GDD body updated to Slot 8 pooled** (matches ADR-0008 §85 + §239; GDD's prior Slot 7 claim was factually wrong) |
| D4 | Speaker labels MVP policy | **Default ON + emergency Settings UI toggle at MVP** (preserves WCAG SC 1.2.2 + restores player agency; updates §F.6 #6 coord to register knob as MVP-active) |

**v0.3 surgical patches applied (in-doc only):**

| # | Item | Patch |
|---|---|---|
| 1 | CR-DS-6 grace window | Reverted v0.2 2.0 s grace; full-bark CURIOSITY_BAIT protection. CR-DS-7 interrupt rules updated. |
| 2 | CR-DS-17 + §A.1 + §F.6 #5 + AC-DS-10.3 | `voice_overlay_duck_db = -12.0` (was -6.0). |
| 3 | ADR-0008 Slot 7 → Slot 8 | §A Overview, §F.4 cap formula + sub-claim text, §C.15 row 15, §G.4 ADR-Locked Constants, AC-DS-9.1, §F.6 #2 — all updated to "Slot 8 pooled (0.8 ms shared with CAI / MLS / DC / F&R / Signal-Bus dispatch)". |
| 4 | CR-DS-15 + §C.10 Settings table + §F.6 #6 + §B.3 #5 | Default ON kept; Settings UI toggle promoted from VS to **MVP-Day-1**; §B.3 #5 phrasing updated to acknowledge labels are MVP-default for multi-speaker scenes (PATROL_AMBIENT lines remain unlabeled). |
| 5 | AC-DS-13.2 stale category | `PATROL_AMBIENT` → `SCRIPTED_SCENE 7b` (matches v0.2 §C.7 MVP-2 re-categorization). |
| 6 | §G.2 stale knob table | Updated presets `S=0.8 / M=1.0 / L=1.25` → `S=0.8 / M=1.0 / L=1.5 / XL=2.0` matching §C.10. Added `subtitle_line_spacing_scale` + `subtitle_letter_spacing_em` rows. `subtitle_speaker_labels` default ON, MVP phase. |
| 7 | §C.12 AccessKit composition SR-equity bug | `accessibility_name = tr(speaker_label_key) + tr(delimiter) + tr(_current_text_key)` (was `+ _label.text` which holds the raw key string under `auto_translate_mode = ALWAYS`, causing SR users to hear "vo.banter.guard_radiator_a" key path instead of the resolved sentence). Manual `tr(_current_text_key)` is the correct read since `accessibility_name` is not a Label-bound assignment subject to FP-DS-18. Recompose on `NOTIFICATION_TRANSLATION_CHANGED` updated to refresh `accessibility_name` AND `_label.text`. |
| 8 | F.3 null-guard polarity | F.3 prose explicitly states: "At boot (`_player_ready = false`), this predicate is **overridden by CR-DS-9 to fail CLOSED**. The fail-OPEN fallback applies only after `_player_ready = true`." Eliminates polarity ambiguity for programmers reading F.3 alone. |
| 9 | F.1 `audio_duration_s` range | Range split: banter `audio_duration_s ≤ 15.0 s`; SCRIPTED carve-out `≤ 30.0 s`. Aligned with CR-DS-20 12-word ceiling. |
| 10 | CR-DS-21 watchdog | Floor reduced from 30.0 s to 5.0 s (`wait_time = max(audio_duration_s, duration_metadata_s, 5.0) + 1.0`). Watchdog handler now calls `_audio_player.stop()` BEFORE emitting force-finished signal. §C.3 scene tree updated to include `WatchdogTimer`. |
| 11 | F.5 reclassification | Re-titled "F.5 — Per-Section Banter Density (Advisory Heuristic, Non-Binding)". Added "fired-density" approximation note. Removed implicit constraint framing. |
| 12 | AC-DS-2.3 / AC-DS-5.1 determinism | Added "Implementation note: tests inject mock clock seam; assertion target is frame-count, not wall-clock. Wall-clock tolerance is playtest-target only." |
| 13 | §H.12 ACs severity upgrade | All H.12 visual/layout ACs upgraded to BLOCKING (was ADVISORY). Added new AC-DS-12.5 (per-section opaque QA gate, referenced in §V.1 but previously dangling). |
| 14 | Missing ACs for v0.2 CRs | Added AC-DS-2.6 (CR-DS-21 watchdog force-finished), AC-DS-7.5 (CR-DS-22 mid-bark locale defer), AC-DS-7.6 (CR-DS-23 production missing-key gate), AC-DS-1.5 (FP-DS-21 zero-length audio reject). All directly automatable. |
| 15 | §B.5 V.2 reactive-comedy acknowledgement | V.2 explicitly classified as **"complicit eavesdrop"** sub-type — Eve is causal (the player's noise triggers the guard's self-reassurance). Asymmetry with V.1 (pure ambient) and V.3 (broadcast intercept) is now named. |
| 16 | DialogueLine schema | Added `performance_notes: String` (V.2 pause-timing spec field; QA-readable target). |
| 17 | Grep ACs cleanup | AC-DS-3.4 `_suppressed` → `_caption_suppressed` (renamed for unambiguous grep); AC-DS-7.4 tautological `src/save` grep removed; AC-DS-11.1–11.5 `--exclude-dir=tests` added; AC-DS-1.1 indirect-emission pattern noted. |
| 18 | AC-DS-9.1 severity correction | BLOCKING → **ADVISORY** (v0.2 reframe made it grep + manual lead sign-off, which is the ADVISORY definition per coding-standards.md). |
| 19 | VG-DS-2 + CR-DS-22 verification gates | Both re-flagged as **load-bearing BLOCKING** for VS sprint planning (not just advisory). VG-DS-2: confirm `accessibility_live` value type — string `"polite"` vs enum `Control.AccessibilityLive.POLITE`. CR-DS-22: confirm `TranslationServer.locale_changed` signal exists in 4.6 (or rewrite via `NOTIFICATION_TRANSLATION_CHANGED`). |
| 20 | `vo.*` vs `dialogue.*` namespace | TEMP: D&S retains `vo.*` for v0.3; cross-doc reconciliation deferred to Localization Scaffold amendment in Phase 2 propagation. Flagged in §F.6 RECOMMENDED items. |

**Phase 2 sibling-doc propagation (BLOCKING for VS sprint planning, NOT in-doc):**

> **STATUS UPDATE 2026-04-28 night**: Phase 2 propagation cycle **executed** in this session. 7 of 8 items CLOSED inline; 1 (P7 ADR-0004 Gates) remains open as engine-verification gate that requires Godot editor inspection (cannot be cleared by doc edits alone). Status table per item:

| # | Sibling | Required amendment | Status |
|---|---|---|---|
| P1 | `design/gdd/audio.md` | (a) Replace L214 row `Load and play vo_[speaker]_[line].ogg` with subscriber-only ducking text; (b) update L67-68, L217, L394 prose to remove "Audio plays VO" claim; (c) register `voice_overlay_duck_db = -12.0` in Tuning Knobs; (d) add Voice-bus duck-exception table for `document_opened`; (e) remove conflicting `vo_[speaker]_[line].ogg` naming (D&S §A.1 canonical). | **✅ CLOSED 2026-04-28 night** — verified at audio.md L31, L67-68, L220-229 (Dialogue domain table updated with v0.3 entries), L406, L459 (`voice_overlay_duck_db = -12.0` registered with safe range [−18.0, 0.0]). Conflicting `vo_[speaker]_[line].ogg` references explicitly retired at L229. |
| P2 | `design/gdd/settings-accessibility.md` | Register knobs: `subtitles_enabled` (MVP default true), `subtitle_size_scale` (S=0.8 / M=1.0 / L=1.5 / XL=2.0, MVP), `subtitle_background` (none/scrim/opaque, MVP), `subtitle_speaker_labels` (default true, **MVP UI toggle** per D4), `subtitle_line_spacing_scale` ([1.0, 1.5], MVP), `subtitle_letter_spacing_em` ([0.0, 0.12], MVP). Plus `setting_changed` emit-site contract. | **✅ CLOSED 2026-04-28 night** — added 6 new rows to §G.3 Accessibility category knobs table (subtitle_size_scale + subtitle_background + subtitle_speaker_labels MVP UI toggle + subtitle_line_spacing_scale + subtitle_letter_spacing_em + audio.voice_overlay_duck_db forward-dep reference). C.2 Categories table updated with new key list. |
| P3 | `design/gdd/mission-level-scripting.md` | Declare authoring contract for `scripted_dialogue_trigger(scene_id: StringName)` MLS-publish signal + per-section scene_id roster. | **✅ CLOSED 2026-04-28 night** — added §C.4.1 NEW subsection: full authoring contract (sole-publisher discipline + 13-entry per-section scene_id roster: 1 MVP-Day-1 + 12 VS = 31 lines total + 6 lint rules joining MLS section-validation CI). |
| P4 | `design/gdd/level-streaming.md` | (a) Guarantee `_exit_tree` (and `dialogue_line_finished()`) fires before scene swap on quick-load (EC-DS-2); (b) document Audio init before D&S init at section load (EC-DS-3); (c) guarantee single `DialogueAndSubtitles` instance at any time (no overlapping section-load lifetimes). | **✅ CLOSED 2026-04-28 night** — added §Edge Cases new subsection "Per-Section Subscriber Lifecycle Guarantees" with EC-DS-2 + EC-DS-3 + EC-DS-singleton entries explicitly documented. Generalised pattern applies to HSS / DOV / DC and any future per-section subscriber. |
| P5 | `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | Amend to add `scripted_dialogue_trigger(scene_id: StringName)` to MLS domain (or whichever domain MLS owns). | **✅ CLOSED 2026-04-28 night** — added new "Mission domain (additions)" section between Dialogue and Persistence with full signal declaration + cadence + atomic-commit risk row. Signal count grown 40 → 41. Revision History entry appended. |
| P6 | `docs/architecture/adr-0008-performance-budget-distribution.md` | Register D&S Slot 8 sub-claim 0.10 ms peak event-frame (informative). Optional: clarify ADR-0008 §85 to enumerate D&S explicitly in Slot 8 with a sub-claim line. | **✅ CLOSED 2026-04-28 night** — §Negative pool enumeration updated to register D&S 0.10 ms peak event-frame alongside CAI / MLS / DC / F&R. Steady-state pool sum updated 0.45 → 0.55 ms (within 0.8 ms cap with 0.25 ms residual margin). Status header + Last Verified + Revision History all reflect amendment. |
| P7 | `docs/architecture/adr-0004-ui-framework.md` | Resolve Gates 1 (`accessibility_live` property name + value type) and 2 (Theme inheritance prop name) — 20-min in-editor verifications each. | **❌ STILL OPEN — engine-verification gate** — cannot be cleared by doc edits alone. Requires opening Godot 4.6 editor and inspecting actual property names on Control nodes. Inherits from ADR-0004 Proposed→Accepted blockers; tracked separately as engine-verification gates. Re-flagged BLOCKING for VS sprint per cross-review B4 carryforward. |
| P8 | `design/narrative/dialogue-writer-brief.md` (NEW FILE) | Author per-section line roster + per-speaker voice profile + 2-3 sample lines per category + VT-3..VT-8 enforcement guidance + per-state minimum-line-count + V.2 pause-timing spec + `[STERLING.]` Eve register convention + locale-equivalent-humor planning for Margaux Bit. | **✅ CLOSED 2026-04-28 night** — `design/narrative/dialogue-writer-brief.md` authored as NEW file (~10 sections, mirrors `document-writer-brief.md` structure). Includes player fantasy anchor, 7 speaker categories with caption format examples, VT-1..VT-8 hard constraints with compliant/forbidden authorings, 40-line per-section roster, Plaza MVP-Day-1 5-line tutorial set with drafted sample lines, 1960s teleprinter caption punctuation discipline, localization considerations, 7 CI lint contract rules joining MLS section-validation pipeline, common-mistakes editor checklist, 3 OQs for writer (civilian banter scope / Lt Moreau depth / French translation cadence). |

**Items deferred to VS playtest / future amendments (RECOMMENDED, non-blocking):**

- CIVILIAN_REACTION re-bucketing playtest validation against V.1 Margaux Bit interruption (Restaurant section).
- CJK/RTL font coverage plan (post-MVP localization concern).
- HoH replay buffer ADR (Pillar 5 rationale documented; revisit if accessibility advocacy escalates).
- AccessKit polite-vs-assertive for SPOTTED bucket (defer to VS playtest with SR users).
- WCAG SC 1.4.12 word-spacing (≥0.16em) — currently unaddressed; post-MVP if Godot exposes the property on Label.
- F.5 density safety margin re-calibration vs NOLF1 reference (defer to first VS playtest).

## Revision Notes — 2026-04-28 Design Review (v0.2)

**Origin:** `/design-review` adversarial pass with 9 specialists + creative-director synthesis identified 26 BLOCKING items (10 author-flagged in §F.6/§Q.1 + 16 specialist-found). Verdict: MAJOR REVISION NEEDED. This v0.2 resolves all 16 specialist-found items inline and tightens the 10 author-flagged coord items. See `design/gdd/reviews/dialogue-subtitles-review-log.md` for the review log.

**Cross-cutting amendments applied (read alongside CR-DS-* below):**

| # | Item | Resolution |
|---|---|---|
| 1 | Restaurant range gate gives zero filtering in 25×25 m room | CR-DS-9 amended: `dialogue_bark_range_m` is now per-section overridable via `DialogueAndSubtitles.section_range_override_m` Resource property; Restaurant default = 12.0 m. |
| 2 | Depth-1 queue priority-inversion (CURIOSITY_BAIT dropped behind queued IDLE) | CR-DS-7 amended: queue is now priority-aware. Incoming higher-comedy-priority bucket REPLACES a lower-priority queued entry (CURIOSITY_BAIT replaces queued IDLE; ESCALATION replaces queued CURIOSITY_AMBIENT). Equal-priority retains "drop newer" rule. |
| 3 | SAW_PLAYER kills V.2 Radiator vignette mid-bark | CR-DS-6 amended: 2-second post-CURIOSITY_BAIT-trigger grace window during which COMBAT_DISCOVERY (bucket 2) cannot interrupt. After grace window expires, normal CR-DS-7 priority rules apply. |
| 4 | V.2 Radiator vignette structure ambiguous | CR-DS-6 + §C.7 MVP-1 amended: MVP-1 ships as ONE DialogueLine with one audio_stream containing the full two-part vocal performance and an internal pause. CURIOSITY_BAIT protection covers the whole bark. |
| 5 | AudioStreamPlayer ownership conflict with Audio GDD | §F.6 BLOCKING item 5 strengthened: D&S owns the AudioStreamPlayer (per CR-DS-2 + §C.3). Audio GDD §F.1 Dialogue domain table row "`dialogue_line_started(speaker, line) \| Load and play vo_[speaker]_[line].ogg`" must be replaced with "Apply VO duck per Formula 1; Audio is subscriber-only and does NOT play VO files." |
| 6 | Timbral shaping per speaker as AudioEffect chain on single player is technically incorrect | §C.11 amended: speaker-category timbral shaping is **pre-baked into VO files** at recording/mastering time (radio crackle, room reverb, telephone EQ baked into the asset). Single clean Voice bus. AudioEffect chain mutation is rejected. Authoring overhead lives in Audio Director's VO production pipeline. |
| 7 | VO file naming convention mismatch with Audio GDD | §F.6 BLOCKING item 5 (combined): D&S §A.1 naming `assets/audio/vo/[speaker_category]/[line_id]_[locale].ogg` is canonical. Audio GDD must remove its conflicting `vo_[speaker]_[line].ogg` reference. |
| 8 | WCAG SC 1.4.4: L=1.25 ≠ 200% scaling | §V.1 + §C.10 amended: subtitle_size_scale presets are now S=0.8 / M=1.0 / L=1.5 / **XL=2.0** (4 presets). Settings GDD coord (§F.6 #6) updated to register XL preset. |
| 9 | WCAG SC 1.2.2: speaker labels suppressed at MVP breaks multi-speaker disambiguation | CR-DS-15 REPLACED by new CR-DS-15 (v0.2): speaker labels DEFAULT ON at MVP for all multi-speaker scenes (MVP-2, MVP-3). The Settings UI toggle remains deferred to VS, but the runtime default is `true` at MVP, not `false`. |
| 10 | WCAG SC 1.4.12 (Text Spacing) absent | §C.10 amended: two new Settings knobs registered: `subtitle_line_spacing_scale` (default 1.0, range [1.0, 1.5]) and `subtitle_letter_spacing_em` (default 0.0, range [0.0, 0.12]). Settings GDD coord §F.6 #6 expanded to register both. |
| 11 | AccessKit accessibility_name decoupled from visual label setting | §C.12 amended: `accessibility_name` ALWAYS includes `speaker_id` (resolved via `speaker_label_key`) when speaker is non-anonymous, regardless of `subtitle_speaker_labels` visual setting. Visual presentation and AT semantic content are independent channels. |
| 12 | Null player ref fails OPEN at boot → all-actor bark burst | CR-DS-9 amended: D&S adds `_player_ready: bool = false` flag; `_ready()` resolves player ref via canonical scene path with deferred call; `_player_ready` is set true only after player ref is `is_instance_valid`. `select_line()` returns `null` for non-SCRIPTED triggers while `_player_ready = false`. SCRIPTED triggers still bypass range gate. |
| 13 | Interrupt path doesn't clean up `_caption_timer` and completion flags | CR-DS-7 amended: interrupt path now explicitly: (a) `_caption_timer.stop()`; (b) reset `_audio_finished_flag = false` + `_caption_timer_flag = false`; (c) emit `dialogue_line_finished()` for outgoing line; (d) call `_audio_player.stop()`; (e) start incoming line. |
| 14 | `play()` failure leaves Voice ducked indefinitely | New CR-DS-21: `_audio_player.finished` watchdog. After step 4 of CR-DS-2, start a watchdog timer of `max(audio_duration_s, duration_metadata_s, 30.0) + 1.0 s`. If neither `_audio_player.finished` nor `_caption_timer.timeout` has fired by watchdog expiry, force-emit `dialogue_line_finished()` with `push_error("D&S watchdog: line " + line_id + " never completed")`. Releases Audio ducking unconditionally. |
| 15 | State machine §C.2 missing row for `dialogue_line_started` while `_suppressed = true` | §C.2 amended: explicit row added. SUPPRESSED + `dialogue_line_started` → SUPPRESSED (audio plays, caption deferred; re-shows on `document_closed` if still in flight per existing SUPPRESSED → VISIBLE row). |
| 16 | SCRIPTED-vs-SCRIPTED queue collision silently drops MLS lines | CR-DS-7 amended: SCRIPTED + queued-SCRIPTED collision REPLACES the queued entry (not "drop newer") and emits `push_warning("D&S: SCRIPTED queue collision — replaced queued line " + queued_id + " with " + new_id)`. Always-play guarantee is honored for the most-recent SCRIPTED. |
| 17 | Zero-length / corrupt audio passes FP-DS-2 null guard | New FP-DS-21 (was discussed as new content rule): `select_line()` rejects DialogueLines with `audio_stream.get_length() < 0.1 s` with `push_error("D&S: rejected line " + id + " — audio_duration_s < 0.1 s")`. Strengthens FP-DS-2. |
| 18 | Dialogue Writer Brief forward dep | F.4 row 3 + §F.6 BLOCKING item 10 expanded: a separate `design/narrative/dialogue-writer-brief.md` is required (existing `document-writer-brief.md` covers documents only). The brief MUST contain: (a) per-section line roster with SAI state distribution; (b) per-speaker-category voice profile with 2–3 sample lines each; (c) VT-5 domain-differentiation rule (banter must span ≥3 distinct domains: domestic, professional, interpersonal, institutional); (d) VT-6 implicit-navigation-hint heuristics beyond keyword grep (named-locations test, imperative-mood test, motion-verb-plus-spatial-reference test); (e) per-state-per-section minimum line count to prevent recycling. |
| 19 | Mid-bark locale switch produces audio/caption language mismatch | §E Cluster D.1 amended: `TranslationServer.set_locale()` is captured by D&S as a deferred change. Caption locale re-resolution is deferred until `dialogue_line_finished()` fires (or immediately if no line in flight). Mid-bark mismatch is eliminated. Implementation: `_pending_locale: StringName` flag; on locale-change signal, store new locale; on `dialogue_line_finished()`, call `TranslationServer.set_locale(_pending_locale)` if set. |
| 20 | Missing-key `MISSING:` production-build policy undefined | New §I.1 (Edge Cluster I): production builds: any `MISSING:` key rendering is a P0 release blocker. The `/localize` audit must be GREEN before any external build is cut. QA / dev builds: `MISSING:` keys remain visible in caption (current D.3 behavior preserved) so localization gaps are surfaced during playtest. |
| 21 | Hardcoded `: ` delimiter in CR-DS-16 breaks CJK / RTL | CR-DS-16 amended: speaker label rendering format is governed by a localizable key `vo.speaker.delimiter` (default English value: `": "`; default Eve value: `vo.speaker.delimiter.eve` = `"."`). The `[STERLING.]` typographic-comedy convention becomes a per-locale translator decision. CR-DS-16 no longer concatenates `": "` literally. |
| 22 | `accessibility_name` composition pattern unspecified | §C.12 amended: composition pattern documented. `accessibility_name = tr(line.speaker_label_key) + tr(&"vo.speaker.delimiter") + _label.text`. The `tr()` calls here are NOT assigned to a Label — `auto_translate_mode` does not double-resolve them (FP-DS-18 applies only to Label-bound assignments). |
| 23 | VG-DS-2 `accessibility_live` property name is unverified | §C.12 unchanged — VG-DS-2 remains BLOCKING for VS. Reinforced note: do NOT implement placeholder code with a guessed property name; verify in-editor first (~20 min). If property name differs, revise CR-DS-12 with verified name before any AccessKit code lands. |
| 24 | VG-DS-4 interrupt-flag guard implementation timing | CR-DS-7 (interrupt path) amended: interrupt-flag guard `_stopping_for_interrupt: bool` is implemented UNCONDITIONALLY, not conditionally on VG-DS-4 verification. Cost ≈ 0.001 ms; eliminates a class of duplicate `dialogue_line_finished` emit bugs regardless of engine behavior. EC-DS-4 conditional re-sign is replaced by an unconditional 0.001 ms cost roll-up into the F.4 calculation; ADR-0008 sub-claim ceiling unchanged at 0.10 ms peak event-frame. |
| 25 | AC-DS-2.3 missing upper bound permits indefinite delay | §H.2 AC-DS-2.3 amended: bounds are now `t = 104.5 s ± 0.1 s` (Example A) and `t = 105.0 s ± 0.1 s` (Example B). Tolerance = 100 ms (~6 frames at 60 fps). Catches timer drift regressions. |
| 26 | AC-DS-2.5 collapses 5 assertions into one PASS/FAIL | §H.2 AC-DS-2.5 split into AC-DS-2.5a (lifecycle cleanup: `stop()` called, `finished` emitted, `label.text` cleared, state HIDDEN) and AC-DS-2.5b (signal disconnection: all `Events.*` subscriptions disconnected with `is_connected()` guards). Both BLOCKING. |

**Additional non-blocking RECOMMENDED items applied:**

- §C.5 banter taxonomy: **CIVILIAN_REACTION (Cat 5) re-bucketed** from CURIOSITY_AMBIENT (4) to ESCALATION (3) — affronted-Parisian register is a Pillar-1 primary vector and should outrank IDLE patrol.
- §C.7 MVP-2 PATROL_AMBIENT scope clarified: the two-line GuardA→GuardB exchange ("You take the brochure stand." / "Someone has to.") is a SCRIPTED_SCENE Cat 7b sub-register variant for MVP, NOT generic Cat 6 patrol-cycle infrastructure (which is VS-only). Re-categorized as `banter_category = SCRIPTED_SCENE` with `priority_bucket = SCRIPTED` for MVP-Day-1.
- §C.11 timbral shaping pre-baked architecture documented (see Cross-cutting #6 above).
- CR-DS-14 amended: `_actor_last_bark_time` Dictionary purge pass added at every `dialogue_line_finished` emission — iterate keys and remove any where `not is_instance_valid(key)`. Prevents dictionary growth across long sessions with NPC turnover.
- CR-DS-8 amended: explicit note that `Time.get_ticks_msec()` is wall-clock monotonic and NOT affected by `Engine.time_scale` or `SceneTree.paused`. Cooldown timers continue counting during in-game pause; this is intentional (player away from gameplay should see fresh barks on return).
- F.4 amended: per-operation cost estimates marked as pre-profiler estimates; the 0.10 ms peak event-frame sub-claim is provisional pending `tools-programmer`-led profiler measurement on minimum-spec hardware. ADR-0008 amendment (§F.6 #2) carries this provisional flag.
- §C.12 reinforced: J.3 mitigation (`_label.visible = false` alongside `SubtitleCanvasLayer.visible = false`) implemented preemptively rather than waiting for VG-DS-3 verification (zero cost, eliminates AT-leak risk).
- New §F coord item: LSS must guarantee only ONE `DialogueAndSubtitles` instance exists at any time (no overlapping section-load lifetimes). Added to §F.6 BLOCKING items.
- AC-DS-9.1 amended: 0.10 ms profiler claim replaced by structural-grep (`grep -L "_process\|_physics_process" dialogue_and_subtitles.gd` returns the file = no per-frame callback) plus advisory profiler spot-check on minimum-spec hardware (lead sign-off, not CI gate).
- §V.1 scrim contrast claim amended: `~8.4:1 at 0.55 alpha` is now annotated "**best-case dark-field measurement**; worst-case effective contrast over a fully-lit scene drops to ~1.6:1." Per-section opaque QA gate AC added.

**Items deliberately deferred (RECOMMENDED, not BLOCKING for v0.2):**

- HoH replay-buffer omission: keep Pillar 5 stance, document explicit decision record post-MVP if accessibility advocacy escalates.
- AccessKit polite-vs-assertive for SPOTTED-bucket lines: defer to VS playtest with SR users.
- F.5 density safety margin re-calibration: defer to first VS playtest.
- Hurt-sound / exertion-grunt Voice-bus interaction: defer to Audio Director coordination during VS.
- German character-budget for translators: defer to localization-lead's translator brief (post-MVP).

## Overview

**Dialogue & Subtitles** is the Narrative-layer Vertical-Slice system that owns the scheduling, playback orchestration, and on-screen captioning of every spoken line in the game — from absurd guard banter and incidental civilian mutters to scripted radio chatter and BQA briefings. As infrastructure, this system is the **sole publisher** of the ADR-0002 Dialogue domain signals `dialogue_line_started(speaker: StringName, line_id: StringName)` and `dialogue_line_finished()` (ADR-0002 L304, frozen — Audio is subscriber-only and owns ducking via Audio §F.1). Subtitle is a scene-tree-rooted Control node (NOT autoload — ADR-0007 slots are full and the project posture forbids further autoloads), claiming a sub-slot of **ADR-0008 Slot 8 pooled residual (0.8 ms shared cap with Civilian AI, Mission & Level Scripting, Document Collection, Failure & Respawn, and Signal Bus dispatch overhead — per ADR-0008 §85 + §239)**. *(v0.3 correction: prior versions referenced "Slot 7 / UI / 0.3 ms" — that was the ADR-0008 slot for HUD Core / HSS / DOV / Menu, not D&S. D&S is logic-tier dispatch + audio orchestration, not per-frame UI render.)* Subtitle owns its own visibility suppression by subscribing to `Events.document_opened`, `Events.document_closed`, and `Events.ui_context_changed` — it is forbidden for Document Overlay UI to push suppression onto Subtitle (ADR-0004 §IG5 + Document Overlay FP-OV-6).

As player-facing surface, Dialogue & Subtitles is **the entire comedic delivery vector** for Pillar 1 (Comedy Without Punchlines): the patrolling guard who mutters about his pension, the clerk arguing with a vending machine, the PHANTOM lieutenant's deadpan pep talk over the intercom. Captions render at the bottom-center of the screen with period-authentic typographic restraint (Pillar 5: no modern AAA chyron); they default ON at first launch per Settings & Accessibility CR-23 (WCAG SC 1.2.2). Subtitles auto-suppress when the player is reading a Document Overlay (because that surface is itself textual and silent), and a stealth-CURIOSITY_BAIT bark plays through to its full vocal completion even if the guard's alert state changes mid-line — the comedy beat owns its own duration (Stealth AI L91 vocal-scheduling carve-out).

**Scope**: this GDD covers (1) the **Dialogue scheduler/orchestrator** that selects + plays VO lines and emits the frozen Dialogue-domain signals; (2) the **Subtitle renderer** that consumes those signals + Localization Scaffold `tr()` keys to draw captions; (3) the **banter trigger taxonomy** that subscribes to Stealth AI / Civilian AI / Combat / Mission Scripting events to schedule contextual barks; (4) **suppression rules** that gate visibility against InputContext and modal overlays; (5) **performance + accessibility budgets**. This GDD does NOT cover: VO bus mixing or ducking (Audio GDD), CSV string-table mechanics or locale switching internals (Localization Scaffold), the alert-state machine itself (Stealth AI), the actual writer-authored line content (Writer brief), or scripted cutscene cinematography (Cutscenes & Mission Cards #22, Not Started). VO asset production (recording, mastering, file naming) is delegated to the Audio Director's pipeline; this system consumes finished `AudioStream` resources via metadata-bound `DialogueLine.tres` resources.

**Per-section phasing**: this GDD ships as a **single document** with per-section [MVP]/[VS] tags. MVP scope = `dialogue_line_started`/`finished` signal contract + minimal subtitle renderer + 1 banter trigger (CURIOSITY_BAIT) + suppression-during-overlay + locale-safe key pipeline + Plaza tutorial 3–5 lines. VS scope = full banter taxonomy across SAI / CAI / Combat / MLS event sources + speaker-label policy + Settings-driven subtitle styling + 30–50 VO lines per the game-concept MVP definition + AccessKit live-region announcement.

## Player Fantasy

> **"The Eavesdrop"** — Creative Director Candidate 1 of 3, recommended.

### B.1 The fantasy

You are Eve Sterling crouched behind a filing cabinet on the third floor of the Eiffel Tower, listening. Two PHANTOM clerks pass; their conversation continues without you in it. *"—and Margaux says the cat won't eat the new brand—" "Margaux's cat is a saboteur."* The transcript clicks across the bottom of your screen in a 1960s teleprinter face, as if intercepted on a wire. You do not react. **You are the listener.** The world is the comedian. Your tradecraft is patience, and the joke is its reward.

The player verb of Dialogue & Subtitles is **the keyhole posture** — leaning toward something not meant for you. Eve is silent in free play; the world fills her silence with its own absurdity, its own bureaucratic drudgery, its own escalating panic. Captions render as if **already typed** — they do not pop, they do not animate in, they appear the way a transcript appears on a radio operator's strip: line by line, monospace, the carriage clicking forward. Reading the subtitle is itself part of the spy fantasy. Listening is the skill.

### B.2 Pillar mapping

| Pillar | Role | How D&S serves it |
|---|---|---|
| **Pillar 1 — Comedy Without Punchlines** | **Primary load-bearing** | The Eavesdrop IS the comedy vector. *"Humor lives in characters, signage, documents, and overheard guard banter — not in the protagonist quipping at the camera."* (game-concept L121–125) The system that delivers banter delivers the entire comedic register of the game. Eve does not quip; the world quips around her, and the player overhears. |
| **Pillar 5 — Period Authenticity** | **Primary supporting** | Teleprinter typography is 1960s SIGINT vernacular, not 2024 Netflix sans-serif. The visual register of captions is itself part of the period anchor. Caption styling refuses every modern AAA convention (chyron bars, speaker portraits, dynamic font weight). |
| **Pillar 3 — Stealth is Theatre, Not Punishment** | **Supporting** | Banter is the diegetic alert-state readout. A guard muttering *"Could've sworn I heard something..."* tells the player the SAI state without a HUD bar. Detection escalation reads as comedy, not punishment, because the line plays through to completion even if the state changes mid-vocalization (Stealth AI L91 carve-out). |

### B.3 Five explicit refusals

What this fantasy is NOT — and what we will refuse to ship:

1. **Not a notification.** Captions never pop, never animate in, never demand attention. They appear as if already typed, line by line, the way a transcript appears on a radio operator's paper strip. No bounce, no slide, no scale.
2. **Not karaoke.** No synced word-by-word highlighting, no bouncing ball, no per-word color shift. Each line renders whole and is dismissed whole.
3. **Not a drama.** No theatrical typography, no italics-for-feelings, no dynamic font weight on emphasis. The caption is a transcript, not a performance. Emphasis lives in the VO itself, in the writer's choice of words — never in the rendering.
4. **Not Eve's voice in free play.** Eve does not narrate, quip, react, or comment in caption space during moment-to-moment gameplay. She is the listener. *(Carve-out: scripted BQA radio briefings between sections may render Eve's voice — these are framed as transmissions Eve is participating in, not interior monologue. Subtitles for Eve's lines obey the same teleprinter register.)*
5. **Not a chyron.** No lower-third Netflix-style background bars, no speaker portraits, no avatar headshots, no modern AAA cinematic frame. Speaker attribution **renders inline** as `[CLERK-1]:` bracket-tag register — the way an operator would log it. *(v0.3 — per D4 design decision: speaker labels default ON for multi-speaker scenes at MVP for WCAG SC 1.2.2; PATROL_AMBIENT lines remain unlabeled to preserve the "overheard" register; player can disable via Settings UI toggle that ships at MVP-Day-1.)*

### B.4 The tonal-anchor question

When any future writer, designer, or programmer adds dialogue or modifies caption styling, they answer this single question:

> ***Does this respect The Eavesdrop?***
>
> *(Is the player overhearing, or is the game performing AT them?)*

If the answer is "performing AT," redesign. The player is always the keyhole, never the audience.

### B.5 Three anchor vignettes

These are the moments the fantasy was authored to deliver. They become the design test for any banter content added during the VS sprint.

**V.1 — The Margaux Bit (Restaurant level, ambient banter).** Eve crouches behind a service counter. Two PHANTOM clerks pass on a coffee break. *"—and Margaux says the cat won't eat the new brand—" "Margaux's cat is a saboteur."* The transcript clicks across the bottom margin. They do not see her; they were never speaking to her. Eve files past once they round the corner. The player smiles. Pillar 1, untouched.

**V.2 — The Radiator (alert escalation, Lower Scaffolds) — *Complicit Eavesdrop sub-type (v0.3)*.** Eve knocks over an umbrella stand crossing a darkened landing. SAI escalates UNAWARE → SUSPICIOUS for the nearest guard. The same patrol guard, now circling, mutters: *"Could've sworn I heard— probably the radiator."* No tutorial popup. No audio sting beyond the guard's voice. **The line IS the alert state.** Player reads it, hides, waits — the line completes on its own clock per Stealth AI L91 (and v0.3 CR-DS-6 full-bark protection), even if the guard de-escalates back to UNAWARE before the bark finishes. Pillar 3, delivered diegetically.

> **Sub-type acknowledgement (v0.3):** V.2 is structurally distinct from V.1 (Margaux Bit, pure ambient overheard) and V.3 (Guard Room Cable, broadcast intercept) — Eve is **causal**: the player's noise triggers the guard's self-reassurance. The audience for the line is simultaneously the guard (reassuring himself), Eve (eavesdropping), and the player (whose action caused the trigger). This is a **richer Pillar 1 sub-fantasy** — comedy-of-cause-and-effect on top of comedy-of-overhearing — but the asymmetry must be named. The §B.4 fantasy test ("is the player overhearing, or is the game performing AT them?") resolves: the guard is performing FOR himself, not AT the player; the player's complicity is what makes the joke land. V.2 is the **single load-bearing tutorial vignette** for the Eavesdrop fantasy and ships as one DialogueLine with baked internal pause (§C.7 MVP-1; pause spec lives in DialogueLine `performance_notes` field per v0.3 schema).

**V.3 — The Guard Room Cable (Upper Structure, scripted radio).** A radio crackles in an unmanned guard room. PHANTOM dispatch reads the day's lost-and-found in the same dry register as enemy-threat bulletins: *"...one umbrella, ladies', monogrammed M.B., second-floor lavatory. Item Five: increased BQA activity in arrondissement seven, advise vigilance. Item Six: cafeteria — bread."* Eve files past without breaking stride. The transcript prints. The comedy is structural, not performed — bureaucratic dread delivered in inventory format. Pillar 1 + 5 + 3 simultaneously.

### B.6 Fantasy test for future additions

Before any new VO line, banter trigger, or subtitle-styling change is shipped, it must pass three checks:

1. **Listening check** — Does the line reward the player for being in earshot, or does it announce itself? If announced, redesign.
2. **Eve-silence check** — Is the player asked to *listen*, or asked to *react*? Eve does not react in caption space. If a line implies Eve responding, redesign or move to scripted radio carve-out.
3. **Register check** — Does the typography read 1960s teleprinter, or does it read modern AAA? If modern, redesign — even if the words are right.

A line that fails any of these is not a Dialogue & Subtitles line; it belongs to a different system (HUD prompt, Document Overlay, Cutscene), or it should not ship.

## Detailed Design

### C.1 Core Rules

**[MVP] CR-DS-1 — Sole-publisher discipline.** D&S is the **only** system permitted to emit `Events.dialogue_line_started(speaker: StringName, line_id: StringName)` and `Events.dialogue_line_finished()` (ADR-0002 L304, frozen). No other system — Stealth AI, MLS, Civilian AI, Combat, HUD, Cutscenes — may emit these signals. D&S itself MUST NOT subscribe to its own published signals (loop avoidance — FP-DS-1).

**[MVP] CR-DS-2 — Per-line playback lifecycle.** Every spoken line follows this exact sequence with no steps reordered:

1. `select_line(trigger_context)` — pick a `DialogueLine.tres` matching trigger + priority + rate-gate + range conditions.
2. `_audio_player.stream = line.audio_stream`.
3. **Emit `dialogue_line_started(line.speaker_id, line.id)` BEFORE `play()`** — gives Audio's 0.3 s ducking attack a 0–1 frame head start so VO doesn't bleed at full mix.
4. `_audio_player.play()`.
5. Render subtitle: assign **raw key** `_label.text = String(line.text_key)` (with `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`) — only if `Settings.subtitles_enabled = true` AND visibility state = VISIBLE.
6. Start `_caption_timer` (one-shot) with `wait_time = line.duration_metadata_s` (caption floor for slow readers per WCAG ~1 s/word).
7. **Both** `_audio_player.finished` AND `_caption_timer.timeout` must fire before completion → emit `dialogue_line_finished()` → clear `_label.text` → reset internal state. (Caption clock = `max(audio_finished_t, metadata_duration_s)`.)

**[MVP] CR-DS-3 — Subtitle visibility state machine.** Three states: `HIDDEN`, `VISIBLE`, `SUPPRESSED`. Default at scene entry: HIDDEN. Full transition table in §C.2.

**[MVP] CR-DS-4 — Self-suppression.** D&S subscribes to `Events.document_opened`, `Events.document_closed`, and `Events.ui_context_changed(new_ctx, old_ctx)`. On `document_opened` OR `ui_context_changed` where `new_ctx != GAMEPLAY`: set `_suppressed = true` → `SubtitleCanvasLayer.visible = false` (hides AccessKit announcement too — VG-DS-3). On `document_closed` AND back to GAMEPLAY: set `_suppressed = false` → `SubtitleCanvasLayer.visible = true`. Document Overlay UI does NOT call any method on D&S (ADR-0004 §IG5 + Document Overlay FP-OV-6).

**[MVP] CR-DS-5 — `tr()` discipline via `auto_translate_mode = ALWAYS`.** `DialogueLine.text_key` stores a Localization Scaffold key (e.g., `&"vo.banter.guard_radiator_a"`). At render step 5 of CR-DS-2, the **raw key string** is assigned to `_label.text` — the engine's `auto_translate_mode = ALWAYS` resolves it via `tr()` automatically and re-resolves on `NOTIFICATION_TRANSLATION_CHANGED` automatically. **NEVER** assign `tr(line.text_key)` to `_label.text` (double-translation trap — see VG-DS-1, FP-DS-18). Translated strings are never persisted (FP-DS-12).

**[MVP] CR-DS-6 — CURIOSITY_BAIT vocal-completion protection (v0.3 — full-bark protection).** When SAI emits `actor_became_alerted(actor, cause=CURIOSITY_BAIT, ...)` and D&S begins a CURIOSITY_BAIT bark, that line plays to AudioStreamPlayer.finished **regardless of subsequent SAI state changes OR subsequent COMBAT_DISCOVERY events on the same actor**. The comedy beat owns its full duration. Only SCRIPTED (bucket 1) may interrupt — mission-critical content always wins.

**v0.3 design decision (D1):** the v0.2 2.0 s grace window is **replaced with full-bark protection**. Rationale: V.2 Radiator vignette is the named Pillar 1 anchor (§B.5); a 2.0 s window protected only 28-40% of typical 5-7 s barks. game-designer + creative-director adjudication: full-bark protection matches the original Stealth AI L91 spirit ("the comedy beat owns its own duration"). Trade-off accepted: a 6 s delay between SAW_PLAYER trigger and SPOTTED bark feels slow for the duration of any in-flight CURIOSITY_BAIT — this is acceptable because (a) CURIOSITY_BAIT triggers are themselves rate-gated per CR-DS-8, and (b) the alternative (mid-bark cuts at exactly 2.0 s) produces predictable mechanical artifacts the player cannot control or predict.

The MVP-1 Radiator vignette (§C.7) ships as **a single DialogueLine resource** with one `audio_stream` containing the full two-part vocal performance ("Could've sworn I heard something." [internal pause] "Probably the radiator.") and an internal silent pause baked into the asset by the Audio Director. CURIOSITY_BAIT protection covers the whole authored unit; no paired-line continuation logic is needed.

**[MVP] CR-DS-7 — Preemption / queueing: priority-resolver with depth-1 queue.** Five priority buckets (highest first):

1. **SCRIPTED** — MLS-authored lines (always play).
2. **COMBAT_DISCOVERY** — `SAW_PLAYER` / `SAW_BODY` / `HEARD_GUNFIRE` barks.
3. **ESCALATION** — `ALERTED_BY_OTHER` / `HEARD_NOISE` barks.
4. **CURIOSITY_AMBIENT** — `CURIOSITY_BAIT` / `civilian_panicked` barks.
5. **IDLE** — UNAWARE proximity-triggered patrol ambient (VS only).

Resolution rules (v0.2 — priority-aware queue + explicit interrupt cleanup):

- **Higher priority interrupts in-flight lower**: interrupt path executes, in this exact order: (1) `_caption_timer.stop()`; (2) reset `_audio_finished_flag = false` AND `_caption_timer_flag = false`; (3) set `_stopping_for_interrupt = true` (VG-DS-4 unconditional guard, see below); (4) emit `dialogue_line_finished()` for outgoing line (Audio ducking release fires correctly); (5) `_audio_player.stop()`; (6) clear `_label.text`; (7) reset `_stopping_for_interrupt = false`; (8) start incoming line via the normal CR-DS-2 lifecycle.
- **Equal-priority queue collision**: place in depth-1 queue. If queue occupied with an entry of equal or lower priority bucket: **the new trigger REPLACES the queued entry** (priority-aware queue, v0.2 fix). If queue occupied with an entry of HIGHER priority bucket: drop the new trigger silently. The queue holds the highest-comedy-priority pending entry, not merely the most recent.
- **SCRIPTED queue collision**: SCRIPTED + queued-SCRIPTED collision REPLACES the queued entry (always-play guarantee for most-recent SCRIPTED) and emits `push_warning("D&S: SCRIPTED queue collision — replaced queued line " + queued_id + " with " + new_id)` so MLS authors can audit collisions.
- **CURIOSITY_BAIT exception (CR-DS-6 v0.3)**: bucket-4 CURIOSITY_BAIT lines cannot be interrupted by **bucket-2 (COMBAT_DISCOVERY), bucket-3 (ESCALATION), bucket-4 (CURIOSITY_AMBIENT), or bucket-5 (IDLE) incoming triggers** for the full duration of the bark. Only bucket-1 (SCRIPTED) may interrupt. Incoming bucket-2 / bucket-3 triggers during a CURIOSITY_BAIT in-flight are queued (subject to depth-1 queue rules below) and re-evaluated when the in-flight bark completes.
- **VG-DS-4 unconditional guard**: the `_stopping_for_interrupt: bool` flag is set true BEFORE every `_audio_player.stop()` call and reset false AFTER the new line starts. The `_on_audio_finished` handler short-circuits to no-op when this flag is true. This prevents a duplicate `dialogue_line_finished()` emit if Godot 4.6 fires `.finished` on `.stop()` (engine-version-dependent; guard implemented unconditionally per godot-specialist recommendation regardless of VG-DS-4 verification outcome).
- **Queued line re-evaluated at fire time**: when in-flight finishes, re-check rate-gate (CR-DS-8), range (CR-DS-9), `is_instance_valid(actor)`, and SAI-state validity. If the queued bark has gone stale (actor incapacitated, player out of range, situation changed), drop it silently for buckets 3–5; for bucket-1/2 (SCRIPTED / COMBAT_DISCOVERY), emit `push_warning("D&S: stale queue drop on bucket " + bucket + " line " + line_id)`.

**[MVP] CR-DS-8 — Per-actor rate-gate (v0.2 — wall-clock + purge note).** Each actor has independent cooldown. After any bark completes, that actor's cooldown timer starts at `dialogue_per_actor_cooldown_s = 8.0` s (safe range [3.0, 30.0]). During cooldown, `select_line()` returns null for that actor and no line is queued or played. Cooldown is per-actor (Node ref keyed in `_actor_last_bark_time: Dictionary[Node, float]`), not global. Use `is_instance_valid(actor)` guard on each lookup to skip freed actors. Rationale: NOLF1 NPC banter cadence empirically lands near 8–12 s before fatigue.

**Wall-clock note (v0.2):** `_actor_last_bark_time` uses `Time.get_ticks_msec() / 1000.0`. `Time.get_ticks_msec()` is wall-clock monotonic and is NOT affected by `Engine.time_scale` or `SceneTree.paused`. Cooldowns continue counting during in-game pause. This is intentional — a player away from gameplay (settings menu, document overlay) should see fresh barks on return. Programmers MUST NOT replace this with engine-time that pauses with the scene tree.

**Dictionary purge (v0.2):** at every `dialogue_line_finished()` emission, iterate `_actor_last_bark_time.keys()` and remove any key where `not is_instance_valid(key)`. Prevents Dictionary growth across long sessions with NPC turnover (incapacitation, scene reload). Cost ≈ negligible at typical 10–20 actor-keys per section.

**[MVP] CR-DS-9 — Range gating (v0.2 — per-section override + boot-window guard).** D&S only schedules barks for actors within an effective range of the player. Effective range = `_section_range_override_m if set else dialogue_bark_range_m`. Default `dialogue_bark_range_m = 25.0` m (safe range [10.0, 50.0]). Per-section override is set on the section's `DialogueAndSubtitles` node via the `section_range_override_m: float = -1.0` exported property (negative value means "no override, use default"). Per-section recommended overrides: Plaza = 25.0 (default); Lower Scaffolds = 18.0; **Restaurant = 12.0** (dense 25×25 m room); Upper Structure = 20.0; Bomb Chamber = 15.0. Level-designer + game-designer co-own these values; tune during VS playtest.

Range check: `actor.global_position.distance_to(player.global_position) <= effective_range_m`. **SCRIPTED triggers (priority bucket 1) bypass range gating** — MLS-authored lines always play.

**Boot-window guard (v0.2):** D&S maintains `_player_ready: bool = false`. In `_ready()`, the canonical-scene-path lookup for the player node is performed via `call_deferred("_resolve_player_ref")`. `_resolve_player_ref` walks the scene path; only when the resolved node is `is_instance_valid` AND has the expected `Player` class is `_player_ready = true`. While `_player_ready = false`, `select_line()` returns `null` for ALL non-SCRIPTED triggers (range gate fails CLOSED at boot — eliminates the documented all-actor-bark burst risk). SCRIPTED triggers still bypass range gate and may play during the boot window. After section-load completes (typically <100 ms post-`_ready()`), `_player_ready` becomes true and normal flow resumes.

**Mid-session null guard:** if `player` ref ever becomes null AFTER `_player_ready = true` (e.g., player node freed by an unanticipated event), range gate fails OPEN for that frame to preserve Pillar 1 comedy until the next `_player_ready` re-evaluation. This mid-session case is distinct from the boot-window case: boot fails CLOSED; runtime fails OPEN.

**[MVP] CR-DS-10 — Eve-silence rule.** Eve emits zero ambient barks during free-play gameplay. `speaker_id = "EVE"` is permitted ONLY in `DialogueLine` resources with `banter_category = SCRIPTED_SCENE`. Any `DialogueLine` with `speaker_id = "EVE"` and a different category is rejected by `select_line()` with a `push_warning` and no playback. Carve-out: scripted BQA radio briefings between sections.

**[MVP] CR-DS-11 — Subtitles-disabled-via-Settings path.** When `Settings.subtitles_enabled = false` (CR-23 default is ON): D&S still executes the full CR-DS-2 lifecycle (signal emit, AudioStreamPlayer.play, finished, signal emit). Only step 5 (subtitle render) is skipped — `_label.text` is never set. Audio receives and ducks correctly. The Voice bus continues to play VO (the user disabled captions, not voices).

**[MVP] CR-DS-12 — `DialogueLine` Resource schema.** See §C.4.

**[MVP] CR-DS-13 — Save/load behavior: no serialization of in-flight lines.** D&S holds zero `SaveGame` sub-resource. On save: any in-flight line silently abandoned. On load: D&S starts at HIDDEN with empty rate-gate dictionaries and empty queue. On next trigger, normal flow resumes. Mid-bark restoration is unrestorable at the audio layer.

**[MVP] CR-DS-14 — Section unload (LSS): teardown.** On `_exit_tree`:

- If line in flight: `_audio_player.stop()` (no fade); emit `dialogue_line_finished()` (Audio ducking release).
- Clear `_label.text`, set state HIDDEN.
- Clear `_actor_last_bark_time`, depth-1 queue, `_caption_timer`.
- Disconnect all `Events.*` subscriptions per ADR-0002 IG3 with `is_connected()` guards.

**[MVP] CR-DS-15 — Speaker label rendering at MVP (v0.3 — DEFAULT ON + MVP UI toggle).** Speaker labels render at MVP for all multi-speaker scenes (MVP-2 GuardA/GuardB exchange + MVP-3 Handler/Eve briefing). Runtime default: `subtitle_speaker_labels = true` at MVP. **v0.3 (D4 decision):** the Settings UI toggle is **promoted from VS to MVP-Day-1** — a single checkbox in the existing accessibility settings panel restores player agency at MVP without requiring the full Settings UI revision deferred to VS. Required by WCAG SC 1.2.2 — captions must identify the speaker, and the toggle preserves player agency to disable for those who find labels visually noisy. Anonymous-context lines (`banter_category = PATROL_AMBIENT`) still render without speaker prefix regardless of the toggle, to preserve the "overheard" quality.

**[MVP / VS] CR-DS-16 — Speaker label rendering format (v0.2 — localizable delimiter).** When `subtitle_speaker_labels = true` AND the active line has a non-anonymous `speaker_id`: caption renders as the concatenation of three resolved values:

1. `tr(line.speaker_label_key)` — e.g., `"[CLERK]"` (English) / `"[ÉCRIVAIN]"` (French) / `"[クラーク]"` (Japanese)
2. `tr(&"vo.speaker.delimiter")` — default English `": "`; per-locale translator decision (CJK locales typically use `"："` fullwidth colon; some prefer `"「"` / `"」"` brackets)
3. `tr(line.text_key)` — the body of the line

For Eve's scripted radio lines (`speaker_id = "EVE"` AND `banter_category = SCRIPTED_SCENE`), the delimiter key is `&"vo.speaker.delimiter.eve"` instead of the default — English value `". "` (period + space) preserves the 1960s telex end-of-transmission convention. Translators substitute their locale's equivalent transmission convention or accept the period if no equivalent exists.

**Implementation pattern (FP-DS-18-safe):** the three `tr()` calls above are NOT assigned to a Label individually. The composed string is computed in GDScript and assigned ONCE to `_label.text` with `auto_translate_mode = ALWAYS` re-resolving on locale switch via the captured raw keys. To preserve the raw-key contract: store `_current_speaker_key`, `_current_delimiter_key`, `_current_text_key` as `StringName` members; on `NOTIFICATION_TRANSLATION_CHANGED`, recompose `_label.text` from the raw keys via `tr()` calls. This is the documented exception to FP-DS-18 (manual `tr()` is permitted when composing multi-key strings; the prohibition only applies to direct Label-bound assignments).

Speaker label rendering does NOT occur for `banter_category = PATROL_AMBIENT` lines (those play anonymously to preserve the "overheard" quality).

**[VS] CR-DS-17 — Voice bus ducks during Document Overlay (v0.3 — −12 dB).** New Audio coordination item: when `document_opened` fires, the Audio system additionally ducks the Voice bus by `voice_overlay_duck_db = -12 dB` (0.3 s attack / 0.5 s release). **v0.3 (D2 decision):** depth doubled from v0.2 −6 dB to −12 dB after audio-director adversarial review — −6 dB is below the broadcast speech-vs-speech intelligibility separation floor (industry standard −18 to −20 dB), and on fast localized BQA briefings (German/French) at native speed the player would be unable to read the document while VO continues at near-foreground level. −12 dB is the agreed playtest-tunable starting target; if VS playtest finds VO still competes for cognitive bandwidth, escalate toward −18 dB. VO continues playing (audio-director's recommendation: stopping VO mid-line breaks Pillar 3 stealth-as-theatre and destroys comedy beats), but recedes substantially so the reading task can complete. D&S emits no new signal; Audio reads the existing `Events.document_opened`/`Events.document_closed`. **BLOCKING coord: Audio GDD §F amendment (Phase 2 propagation cycle).**

**[VS] CR-DS-18 — BQA acronym never expanded by enemy speakers.** Mirrors Document Collection CR-19. No PHANTOM guard, PHANTOM clerk, or civilian actor's `DialogueLine` may include the spelled-out expansion of "BQA" in either `text_key` content OR audio. PHANTOM characters reference "the British" / "their people" / "London" / "the woman" — never "B.Q.A." Carve-out: BQA briefing register (Category 7, sub-register c) may use the acronym in print-register subtitles because those are Eve's own intercepts. Writer Brief enforces this rule.

**[VS] CR-DS-19 — Banter NEVER tells the player what to do next.** No banter line may function as a navigation hint, objective reminder, or tutorial prompt. Lines that read as "go here" or "do this" are cut or rewritten. Diegetic objective delivery is MLS + scripted radio (Category 7, sub-register a); banter is atmosphere.

**[VS] CR-DS-20 — 12-word per-line ceiling; SPOTTED 4-word ceiling.** No banter line exceeds 12 words. SPOTTED-bucket lines (priority 2, COMBAT_DISCOVERY with `cause=SAW_PLAYER`) carry a 4-word hard cap. Pillar 1 operates at 6–10 words; the teleprinter register is laconic. Writer Brief enforces both ceilings.

**Locale note (v0.2):** the 12-word ceiling is enforced on **English source strings only** at authoring time. For non-Latin locales (Japanese, Chinese, Arabic), word-counting is undefined; the 2-line × 896 px display cap is the binding constraint at render time. CI lint AC-DS-8.3 / AC-DS-8.4 are scoped to English-locale `text_key` values only. Translators are instructed (via dialogue-writer-brief.md) to respect the display line cap in their target locale, not the English word count.

**[MVP] CR-DS-21 — Watchdog escape hatch for orphaned ducking (v0.3 — floor reduced + stop() added).** After CR-DS-2 step 4 (`_audio_player.play()`), D&S starts a `_watchdog_timer` (one-shot, child Timer node — see §C.3 scene tree) with `wait_time = max(audio_duration_s, duration_metadata_s, 5.0) + 1.0` s. *(v0.3 floor reduced from 30.0 s to 5.0 s — systems-designer + audio-director agreement: the 30 s floor produced 31 s of degraded mix on sub-second-line failures because Voice bus duck from `dialogue_line_started` is held until watchdog releases. FP-DS-21 already rejects `audio_duration_s < 0.1 s` so a 5.0 s floor is a sufficient guard against late-decode failures while bounding worst-case duck-hold to 6 s.)*

If neither `_audio_player.finished` nor `_caption_timer.timeout` has fired by watchdog expiry, the watchdog handler executes in this exact order: (1) **`_audio_player.stop()`** — eliminates the v0.3-flagged risk of audio continuing into a "silent" D&S state where the next bark trigger calls `stop()` on a still-running unrelated stream; (2) force-emit `dialogue_line_finished()` with `push_error("D&S watchdog: line " + line_id + " never completed; forced finished emit")`; (3) clear `_label.text`; (4) reset state to HIDDEN. Audio ducking is released unconditionally. Guards against the documented `_audio_player.play()` failure mode (asset corrupt at decode, OS-level audio error, zero-length stream that passed FP-DS-2 null guard but slipped FP-DS-21).

**[MVP] FP-DS-21 — Reject zero-length / sub-100-ms audio at select_line() (v0.2).** `select_line()` rejects DialogueLines with `audio_stream.get_length() < 0.1` s with `push_error("D&S: rejected line " + id + " — audio_duration_s < 0.1 s")` and returns `null`. Strengthens FP-DS-2 (which only guarded null streams). Prevents caption orphan from a 1-byte OGG file that loads successfully but plays for ~0 ms.

**[MVP] CR-DS-22 — Mid-bark locale switch deferral (v0.2).** D&S subscribes to `TranslationServer.locale_changed` (or equivalent settings signal). On locale-change while a line is in flight: store the new locale in `_pending_locale: StringName`; do NOT call `TranslationServer.set_locale()` yet. On `dialogue_line_finished()`, if `_pending_locale != &""`, call `TranslationServer.set_locale(_pending_locale)` and clear `_pending_locale`. If no line in flight at the moment of locale-change signal, apply immediately. Eliminates the audio/caption language mismatch documented in v0.1 §E Cluster D.1.

**[VS] CR-DS-23 — Missing-key production policy (v0.2).** Production builds: any `MISSING:` key rendering in subtitle output is a P0 release blocker. The `/localize` audit must be GREEN before any external build is cut. Dev / QA builds: `MISSING:` keys remain visible in caption (preserves D.3 surfacing behavior so playtest reveals localization gaps). The decision rule is: shipped builds NEVER show keys; non-shipped builds ALWAYS show keys.

### C.2 Subtitle Visibility State Machine

| From → To | Trigger | Effect |
|---|---|---|
| HIDDEN → VISIBLE | `dialogue_line_started` AND `_suppressed = false` AND `Settings.subtitles_enabled = true` | Render `_label.text = line.text_key`; layer visible |
| HIDDEN → HIDDEN (v0.2) | `dialogue_line_started` AND `Settings.subtitles_enabled = false` | Audio plays per CR-DS-11; label is never set; state stays HIDDEN |
| HIDDEN → SUPPRESSED | `document_opened` / `ui_context_changed != GAMEPLAY` (no line in flight) | `SubtitleCanvasLayer.visible = false`; `_suppressed = true` |
| SUPPRESSED → SUPPRESSED (v0.2) | `dialogue_line_started` while `_suppressed = true` | Audio plays per CR-DS-2; caption is deferred (`_label.text` is set but layer remains hidden); on `document_closed` → SUPPRESSED → VISIBLE if line still in flight |
| VISIBLE → HIDDEN | `dialogue_line_finished` (both audio finished + metadata floor elapsed) | Clear `_label.text`; reset state |
| VISIBLE → SUPPRESSED | `document_opened` / `ui_context_changed != GAMEPLAY` mid-line | Hide layer; audio continues; `_suppressed = true` |
| SUPPRESSED → VISIBLE | `document_closed` / context back to GAMEPLAY AND line still in flight | Re-show layer; caption persists for remainder |
| SUPPRESSED → HIDDEN | `document_closed` / context back to GAMEPLAY AND no line in flight | Re-show layer (it's empty); reset to HIDDEN resting state |
| Any → HIDDEN | `_exit_tree` (LSS section unload) | Full teardown per CR-DS-14 |

### C.3 Scene Structure

```
Section/Systems/DialogueAndSubtitles    (Node, class_name DialogueAndSubtitles)
  ├── SubtitleCanvasLayer               (CanvasLayer, layer = 2)
  │     └── SubtitleLabel               (Label, anchor = PRESET_BOTTOM_CENTER,
  │                                      auto_translate_mode = ALWAYS,
  │                                      autowrap_mode = AUTOWRAP_WORD_SMART)
  ├── AudioLinePlayer                   (AudioStreamPlayer, bus = "Voice")
  ├── CaptionTimer                      (Timer, one_shot = true, autostart = false)
  └── WatchdogTimer                     (Timer, one_shot = true, autostart = false)  # v0.3 — CR-DS-21
```

**Instantiation**: per-section root, mirroring HSS canonical path `Section/Systems/...`. NOT autoload. Lifetime = section lifetime.

**CanvasLayer index = 2** (godot-specialist): HUD Core = 1, Document Overlay = 5, Menu = 20. Layer 2 sits above HUD Core (always readable over health/ammo) but below Document Overlay (Overlay's z-order naturally occludes — no visibility hack needed for visual suppression; we still set `visible = false` for AccessKit suppression per CR-DS-4).

**Single AudioStreamPlayer** (audio-director + game-designer + godot-specialist converge): dialogue is serial; the priority-resolver + depth-1 queue handles ordering. A 2-player pool buys nothing useful; interrupt model is canonical.

**Plain `Label`, NOT `RichTextLabel`** (godot-specialist): §B.3 forbids per-word markup ("Not karaoke", "Not a drama"); RichTextLabel adds BBCode parse overhead with no benefit. Use `Label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`.

### C.4 `DialogueLine` Resource Schema

```gdscript
class_name DialogueLine
extends Resource

@export var id: StringName                       # unique line identifier — emitted in dialogue_line_started
@export var text_key: StringName                 # Localization Scaffold key — assigned raw to _label.text
@export var audio_stream: AudioStream            # bound VO asset; null = validation error per FP-DS-2
@export var speaker_id: StringName               # actor role: "GUARD_PHANTOM_ANON", "EVE", "BQA_HANDLER", etc.
@export var speaker_label_key: StringName        # localized speaker prefix (e.g., &"vo.speaker.clerk")
@export var banter_category: BanterCategory      # NARRATIVE_CATEGORY (see §C.5) — drives priority + writer brief
@export var priority_bucket: PriorityBucket      # SCRIPTED / COMBAT_DISCOVERY / ESCALATION / CURIOSITY_AMBIENT / IDLE
@export var priority_within_bucket: int = 0      # tiebreaker when multiple lines match
@export var duration_metadata_s: float = 0.0     # caption-floor in seconds; 0.0 = use audio length only
@export var section_scope: StringName            # &"plaza" / &"lower" / &"restaurant" / &"upper" / &"bomb" / &"any"
@export_multiline var performance_notes: String  # v0.3 — QA-readable timing/pacing spec (e.g., "Internal pause 1.0–1.5 s — beats of self-reassurance, not dismissal" for V.2 Radiator). Empty for typical lines; load-bearing for V.2 MVP-1.
```

### C.5 Banter Trigger Taxonomy (7 narrative categories → 5 priority buckets)

| # | Narrative Category | Tier | Trigger Source | Priority Bucket | Pillar Load |
|---|---|---|---|---|---|
| 1 | **CURIOSITY_BAIT** | [MVP] | `actor_became_alerted(cause=CURIOSITY_BAIT)` | CURIOSITY_AMBIENT (4) | P1 load-bearing + P3 primary diegetic |
| 2 | **ALERT_ESCALATION** / **DE-ESCALATION** | [VS] | `alert_state_changed(prev, new)` | ESCALATION (3) | P1 load-bearing on de-escalation; P3 primary diegetic |
| 3 | **BODY_DISCOVERY** | [VS] | `guard_incapacitated(guard, cause)` | COMBAT_DISCOVERY (2) | P1 (procedural-deadpan); P3 immediate alert |
| 4 | **SPOTTED** | [VS] | `actor_became_alerted(cause=SAW_PLAYER)` | COMBAT_DISCOVERY (2) | P3 only — Pillar 1 served by absence-of-wit (4-word cap CR-DS-20) |
| 5 | **CIVILIAN_REACTION** | [VS] | `civilian_panicked` + `weapon_fired_in_public` | **ESCALATION (3)** *(v0.2 — re-bucketed from 4)* | P1 PRIMARY (affronted-Parisian register is a Pillar 1 primary vector and now outranks IDLE patrol); P3 stealth-failure read |
| 6 | **PATROL_AMBIENT** | [VS] | Proximity + patrol-cycle timer (UNAWARE only) | IDLE (5) | **P1 PRIMARY load-bearing** (NOLF1 bread-and-butter) |
| 7 | **SCRIPTED_SCENE** | [MVP partial] / [VS full] | `scripted_dialogue_trigger(scene_id)` from MLS | SCRIPTED (1) | P1 + P5 + P3 simultaneously |

Sub-registers within SCRIPTED_SCENE (Category 7):

- **7a Radio/Intercom** — dry bureaucratic broadcast (PHANTOM dispatch lost-and-found)
- **7b Guard Room Ambient** — multi-voice with dramatic irony (V.3 Guard Room Cable)
- **7c BQA Briefings** — Eve participates (CR-DS-10 carve-out; `[STERLING.]` register)

### C.6 Per-Section Banter Arc

| # | Section | Tonal Direction | Line Count | MVP/VS | Categories Active |
|---|---|---|---|---|---|
| 1 | **Plaza** | *Surface Legitimacy* — guards perform normalcy, tourist-adjacent | **5** | 3 MVP + 2 VS | 1, 2, 5, 6 (limited), 7c |
| 2 | **Lower Scaffolds** | *Workplace Revealed* — workmanlike grumbling, the canteen kettle | **8** | VS | 1, 2, 6 (heavy), 7a |
| 3 | **Restaurant** | *Social Cover* — dinner-party deadpan, civilian/staff/PHANTOM social collision | **12** | VS | 1, 2, 3, 5, 6, 7b |
| 4 | **Upper Structure** | *Command Paperwork* — military command + bureaucratic absurdity | **10** | VS | 2, 3, 4, 6 (sparse), 7a, 7c |
| 5 | **Bomb Chamber** | *Final — Deadly Serious and Still Absurd* — residual proceduralism | **5** | VS | 2, 4, 6 (minimal), 7a |
| **TOTAL** |  |  | **40** lines | within 30–50 game-concept target |  |

### C.7 Plaza MVP-Day-1 Tutorial Set (5 lines: 3 core + 2 stretch)

| # | Tier | Category | Line (working) | Teaches |
|---|---|---|---|---|
| MVP-1 | **CORE** | CURIOSITY_BAIT | Guard: *"Could've sworn I heard something."* [pause] *"Probably the radiator."* | The Eavesdrop fantasy + CR-DS-6 carve-out |
| MVP-2 | **CORE** | SCRIPTED_SCENE 7b *(v0.2 — re-categorized from PATROL_AMBIENT)* | Guard A→B: *"You take the brochure stand."* / *"Someone has to."* | Ambient register; guards have own conversations. **v0.2 fix:** PATROL_AMBIENT (Cat 6) requires patrol-cycle infrastructure that is VS-only per §C.5 — incompatible with MVP scope. The two-line GuardA→GuardB exchange is recategorized as a SCRIPTED_SCENE Cat 7b sub-register variant for MVP, triggered by the player entering a scripted volume in Plaza. Ships at MVP without VS infrastructure dependency. |
| MVP-3 | **CORE** | SCRIPTED_SCENE (7c BQA) | Handler: *"Sterling. You're in. Confirm."* / Eve: *"[Confirmed.]"* | BQA briefing carve-out; `[STERLING.]` typographic format |
| MVP-4 | stretch | ALERT_DE-ESCALATION | Guard: *"False alarm. Maintenance bucket."* | Self-correcting bureaucrat register |
| MVP-5 | stretch | CIVILIAN_REACTION | Civilian: *"Monsieur — really."* | Affronted-Parisian register |

MVP-Day-1 ships at minimum MVP-1 + MVP-2 + MVP-3. MVP-4 + MVP-5 ship if Writer Brief delivers + Audio Director records by Day-1 deadline; otherwise they slip to next sprint without blocking the signal contract validation.

### C.8 Speaker Categories (7)

| # | speaker_id | Caption Prefix Format | Notes |
|---|---|---|---|
| 1 | `GUARD_PHANTOM_ANON` | `[GUARD]:` | Unranked PHANTOM security; majority of patrol banter (Cat 1, 2, 4, 6) |
| 2 | `CLERK_PHANTOM_ANON` | `[CLERK]:` | PHANTOM administrative; intercom/clerical banter (Cat 6, 7) |
| 3 | `LIEUTENANT_PHANTOM_NAMED` | `[LT. MOREAU]:` (per-name) | 1–2 named individuals; rank attribution (Cat 2, 7a) |
| 4 | `CIVILIAN_TOURIST_ANON` | `[VISITOR]:` | Bourgeois-affronted-Parisian register (Cat 5, Plaza/Restaurant) |
| 5 | `CIVILIAN_STAFF_ANON` | `[STAFF]:` | Restaurant/Tower civilian employees; complicit-worker register (Cat 5, 6) |
| 6 | `BQA_HANDLER_NAMED` | `[HANDLER]:` (or codename) | Eve's BQA radio contact; consistent voice across mission (Cat 7c) |
| 7 | `EVE` | `[STERLING.]` (period, NOT colon) | Eve in scripted radio only (CR-DS-10); telex end-of-transmission convention |

**The `[STERLING.]` period is deliberate** — 1960s telex notation for end-of-transmission. Period vs colon is the typographic differentiator that makes Eve's captions visually distinct. Pillar 5 typographic comedy.

### C.9 Voice / Tone Rules (Writer Brief enforcement)

| # | Rule | Carve-outs |
|---|---|---|
| **VT-1** | Eve does not speak in ambient banter during free play | SCRIPTED_SCENE 7c BQA briefings only |
| **VT-2** | No fourth-wall breaks; no acknowledgment of game-systemic states | None |
| **VT-3** | No in-game-meta references (achievements, quest log language, "objective" phrasing, save points, mechanic-naming, SAI state names spoken aloud) | None |
| **VT-4** | BQA acronym never spelled by enemy speakers | BQA briefing register may use it (Eve's own intercepts) |
| **VT-5** | PHANTOM operatives know absurd minor personal details, never their own organization's master plan | Named LIEUTENANT may know more than ANON guards |
| **VT-6** | Banter never tells the player what to do next | Diegetic objective via SCRIPTED Cat 7a only |
| **VT-7** | SPOTTED-bucket lines: 4-word hard cap, no wit | None |
| **VT-8** | All banter lines: 12-word ceiling | SCRIPTED_SCENE radio/cable lines may go longer (full broadcast format) |

### C.10 Subtitle Layout & Settings

**Layout (1080p reference; scale by `viewport_height / 1080.0`):**

- Anchor: `Control.PRESET_BOTTOM_CENTER`
- Vertical offset: 96 px above screen bottom (clears HUD corner widgets)
- Max width: 62% of viewport_width, capped at 896 px (eliminates ultra-wide stretch on 21:9 / 32:9)
- Max line count: 2; overflow truncates with `…` and logs localization warning
- Padding: 12 px top/bottom, 16 px left/right
- Horizontal align: CENTER

**Settings knobs (consumed — owned by Settings & Accessibility):**

| Knob | Default | Phase | Notes |
|---|---|---|---|
| `subtitles_enabled` | `true` | MVP | Settings CR-23, WCAG SC 1.2.2 |
| `subtitle_size_scale` *(v0.2 — XL added)* | `1.0` (S=0.8 / M=1.0 / L=1.5 / **XL=2.0**) | MVP | WCAG SC 1.4.4 — XL preset satisfies the 200% scaling requirement; L raised from 1.25 to 1.5 for smoother progression |
| `subtitle_background` | `scrim` (~0.55 alpha) | MVP | WCAG SC 1.4.3 contrast precondition |
| `subtitle_speaker_labels` *(v0.3 — UI toggle promoted to MVP)* | `true` | **MVP** | WCAG SC 1.2.2 — multi-speaker scenes (MVP-2, MVP-3) require speaker disambiguation. **v0.3 (D4 decision): Settings UI toggle ships at MVP-Day-1** as a single accessibility-panel checkbox. Player agency restored at MVP without requiring full Settings UI revision. |
| `subtitle_line_spacing_scale` *(v0.2 — NEW)* | `1.0` (range [1.0, 1.5]) | MVP | WCAG SC 1.4.12 — user-overridable line height (≤1.5× per WCAG AA floor) |
| `subtitle_letter_spacing_em` *(v0.2 — NEW)* | `0.0` (range [0.0, 0.12]) | MVP | WCAG SC 1.4.12 — user-overridable letter spacing (≤0.12em per WCAG AA floor); applied to Courier monospace via theme override |

**Caption appear/disappear timing (ux-designer):** Instant appear, instant disappear (no tween, no fade-in, no type-on). §B.3 refusal #1 absolute; type-on conflicts with refusal #2. The teleprinter is a *result state*, not a mechanical animation.

### C.11 Audio Integration & VO Pipeline

**Bus routing (v0.2 — pre-baked timbral architecture)**: All dialogue routes through the single `Voice` bus with NO `AudioEffect` chain on the bus or the player node. Speaker-category timbral shaping (radio crackle, room reverb, telephone EQ for BQA HANDLER, distance lo-fi for intercom) is **pre-baked into the VO files at recording / mastering time** by the Audio Director's pipeline. The clean Voice bus carries the already-processed audio. Single ducking ruleset stays correct regardless of speaker (Audio §F.1: Music −14 calm / −18 combat / Ambient −6 / Voice −6 during overlay per CR-DS-17).

Rejected alternatives (audio-director adversarial review, 2026-04-28): (a) sub-buses per timbral category (Voice_Radio, Voice_Room, Voice_Dry) — adds 2-3 buses, complicates ducking; (b) runtime AudioEffect chain mutation via `AudioServer.add_bus_effect`/`remove_bus_effect` per line — DSP graph rebuild cost at every bark trigger, fragile. Pre-baked is the chosen architecture: simplest runtime, authoring overhead lives in the VO production pipeline (Audio Director responsibility, not D&S concern). Trade-off accepted: timbral profiles cannot be tuned at runtime without re-recording / re-mastering the affected lines.

**VO file naming**: `assets/audio/vo/[speaker_category]/[line_id]_[locale].ogg`
Example: `assets/audio/vo/guard_phantom/guard_banter_radiator_a_en.ogg`. `line_id` matches `DialogueLine.id` 1:1; locale suffix swapped at runtime.

**Signal emit order (CR-DS-2 step 3 vs 4)**: emit `dialogue_line_started` BEFORE calling `play()`. Gives Audio's 0.3 s ducking attack a 0–1 frame head start so VO doesn't bleed at full mix. Emit `dialogue_line_finished` AFTER both `_audio_player.finished` AND `_caption_timer.timeout` have fired (CR-DS-2 step 7).

### C.12 Localization & AccessKit Pattern

**Localization** (godot-specialist VG-DS-1 pending):

- `SubtitleLabel.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`
- Assign `_label.text = String(line.text_key)` (raw key as String) — engine resolves via `tr()` automatically
- Engine re-resolves on `NOTIFICATION_TRANSLATION_CHANGED` automatically (no manual `_notification` override needed)
- **NEVER** assign `tr(line.text_key)` (double-translation trap)

**AccessKit live-region** (godot-specialist VG-DS-2 pending; ADR-0004 Gate 1 OPEN):

- Set `accessibility_live = "polite"` on `SubtitleLabel` (matches HSS sibling pattern: "AccessKit polite NEVER assertive"). **VG-DS-2 reinforced (v0.2):** do NOT implement placeholder code with a guessed property name; verify in-editor in Godot 4.6 first (~20 min). String value `"polite"` is atypical for Godot's API (typically integer enums); confirmed property name + value type before any AccessKit code lands. If property name differs, revise CR-DS-12 with verified name.
- **AccessKit speaker disambiguation is independent of visual rendering (v0.2 — WCAG / SR equity fix).** `accessibility_name` ALWAYS includes the speaker identifier when `speaker_id` is non-anonymous, regardless of `subtitle_speaker_labels` visual setting. Visual presentation (the `[GUARD]:` bracket-tag prefix the player sees) and AT semantic content (what the screen reader announces) are independent channels. SR users always hear "Guard says: Could've sworn I heard something" even when sighted users have visual labels turned off.
- **Composition pattern (v0.3 — SR-equity bug fixed):** `accessibility_name = tr(line.speaker_label_key) + tr(&"vo.speaker.delimiter") + tr(_current_text_key)` for non-anonymous speakers. For anonymous (PATROL_AMBIENT) lines: `accessibility_name = tr(_current_text_key)` only (matches the "overheard" intent). **v0.3 fix:** previous v0.2 composition used `+ _label.text` as the body component — but under `auto_translate_mode = ALWAYS`, `_label.text` retains the **raw key string** (e.g., `"vo.banter.guard_radiator_a"`); the engine resolves it at render time via the AT translation pipeline but does NOT rewrite the property value. Result: SR users heard "[GUARD] : vo.banter.guard_radiator_a" — the literal key path — instead of the resolved sentence. The fix uses `tr(_current_text_key)` directly (a single `tr()` call). The `tr()` calls in this composition are NOT assigned to a Label; FP-DS-18 prohibition (no manual `tr()` with `auto_translate_mode = ALWAYS`) applies only to direct Label assignments. Composing strings via `tr()` for non-Label use is permitted. **On `NOTIFICATION_TRANSLATION_CHANGED`, recompose BOTH `_label.text` (for visual) AND `accessibility_name` (for SR)** from the captured raw keys — v0.2 only refreshed the body which left `accessibility_name` stale on locale switch.
- **J.3 mitigation implemented preemptively (v0.2):** alongside `SubtitleCanvasLayer.visible = false` in CR-DS-4 suppression path, also call `_label.visible = false`. Belt-and-suspenders against any Godot 4.6 AccessKit-vs-CanvasLayer-visibility inconsistency. Cost ≈ zero; eliminates AT-leak risk during overlay.

**Verification gates (engine knowledge gaps requiring 5-min in-editor checks):**

| Gate | Check | Blocks |
|---|---|---|
| **VG-DS-1** | `auto_translate_mode = ALWAYS` + raw key auto-resolves on locale switch via 4.5+ live preview | §C.5 final |
| **VG-DS-2** | Exact `accessibility_live` property name + polite enum value on Label in 4.6 | §C.12 final |
| **VG-DS-3** | `CanvasLayer.visible = false` suppresses AccessKit announcements from child Labels in 4.6 | CR-DS-4 final |
| **VG-DS-4** | `AudioStreamPlayer.finished` does NOT fire on `.stop()` in 4.6 | CR-DS-7 (interrupt path) |

### C.13 Forbidden Patterns

| FP-ID | Rule |
|---|---|
| **FP-DS-1** | D&S MUST NOT subscribe to its own `dialogue_line_started` / `dialogue_line_finished` (loop) |
| **FP-DS-2** | NEVER emit `dialogue_line_started` without an AudioStreamPlayer actually playing (orphan emit; ducks Audio with no release path) |
| **FP-DS-3** | NEVER render captions while DOCUMENT_OVERLAY is active or `ui_context_changed != GAMEPLAY` |
| **FP-DS-4** | NEVER drive caption visibility from Audio playback callbacks (Audio is downstream subscriber, not driver) |
| **FP-DS-5** | NO per-word highlighting / karaoke / bouncing ball / per-word color shift |
| **FP-DS-6** | NO chyrons / speaker portraits / lower-third bars / avatar headshots |
| **FP-DS-7** | NO animated subtitle entry or exit (instant or no-op only; no tween, fade, slide, scale, type-on) |
| **FP-DS-8** | NO Eve VO in ambient barks; SCRIPTED_SCENE carve-out only |
| **FP-DS-9** | NEVER preempt CURIOSITY_BAIT mid-flight except by SCRIPTED or COMBAT_DISCOVERY (CR-DS-6) |
| **FP-DS-10** | NEVER leak caption text outside `InputContext.GAMEPLAY` |
| **FP-DS-11** | NO `AcceptDialog` / `Window` / `Popup` for captions — `Label` on `CanvasLayer` only |
| **FP-DS-12** | NEVER store translated strings in save data — keys (StringName) only |
| **FP-DS-13** | D&S MUST NOT route VO to any bus other than `Voice` (never SFX, Music, Master) |
| **FP-DS-14** | D&S MUST NOT modify ducking values (Audio's exclusive responsibility) |
| **FP-DS-15** | NEVER use `RichTextLabel` for caption surface (BBCode parse overhead, autowrap drift, no benefit) |
| **FP-DS-16** | NEVER use `await get_tree().create_timer()` inside signal handlers (lambda capture lifetime hazard); use child `Timer` node only |
| **FP-DS-17** | NEVER `connect()` in `_process()` or `_physics_process()` (compounding duplicate connections) |
| **FP-DS-18** | NEVER set `_label.text = tr(line.text_key)` with `auto_translate_mode = ALWAYS` (double-translation) |
| **FP-DS-19** | NO proximity-based opacity or scale on caption region (rejected C3 framing — accessibility regression / WCAG SC 1.4.3) |
| **FP-DS-20** | Caption region MUST NOT overlap Health (bottom-left) or Weapon (bottom-right) HUD widgets at any supported resolution |

### C.14 Interactions Matrix

| # | System | Direction | What flows | Tier |
|---|---|---|---|---|
| 1 | Stealth AI | Subscribe | `actor_became_alerted` (cause: CURIOSITY_BAIT, SAW_PLAYER, SAW_BODY, HEARD_NOISE, HEARD_GUNFIRE, ALERTED_BY_OTHER, SCRIPTED), `alert_state_changed`, `guard_incapacitated`, `guard_woke_up` | MVP (CURIOSITY_BAIT only) / VS (full) |
| 2 | Civilian AI | Subscribe | `civilian_panicked(actor, cause)` | VS |
| 3 | Combat & Damage | Subscribe | `weapon_fired_in_public` | VS |
| 4 | Mission & Level Scripting | Subscribe | `scripted_dialogue_trigger(scene_id)` (NEW signal — BLOCKING coord) | MVP (BQA briefing) / VS (full) |
| 5 | Document Collection | Subscribe | `document_opened`, `document_closed` (self-suppression) | MVP |
| 6 | InputContext (ADR-0004) | Subscribe | `ui_context_changed(new_ctx, old_ctx)` (self-suppression) | MVP |
| 7 | Audio | Publish | `dialogue_line_started(speaker, line_id)`, `dialogue_line_finished()` (sole publisher) | MVP |
| 8 | Localization Scaffold | Consume | `tr()` via `auto_translate_mode = ALWAYS`; `NOTIFICATION_TRANSLATION_CHANGED` re-resolve | MVP |
| 9 | Settings & Accessibility | Consume | `subtitles_enabled` (MVP), `subtitle_size_scale` (MVP, S/M/L/XL), `subtitle_background` (MVP), `subtitle_speaker_labels` (**MVP** v0.3 — UI toggle promoted), `subtitle_line_spacing_scale` (MVP), `subtitle_letter_spacing_em` (MVP); `setting_changed(key, value)` | MVP full |
| 10 | Save / Load | (none) | D&S holds zero SaveGame state (CR-DS-13) | MVP |
| 11 | Level Streaming Service | Lifecycle | `_exit_tree` teardown on section unload (CR-DS-14) | MVP |
| 12 | HUD Core | (none) | D&S does NOT extend HUD Core; sibling system on different CanvasLayer | MVP |
| 13 | HUD State Signaling | (none) | HSS does NOT manage banter chips; explicit non-dependency | MVP |
| 14 | Document Overlay UI | Indirect | Document Overlay's `document_opened`/`document_closed` emit consumed by D&S; Overlay does NOT call D&S | MVP |
| 15 | Cutscenes & Mission Cards (#22) | (forward dep) | When designed, may publish via SCRIPTED_SCENE Category 7; signal contract TBD | VS+ |
| 16 | Writer Brief (`design/narrative/dialogue-writer-brief.md`) | Authoring contract | VT rules + line-count distribution + speaker categories enforced | VS BLOCKING |

### C.15 Bidirectional Consistency Check

| # | Sibling GDD / ADR | Claim in this GDD | Sibling-side confirmation needed |
|---|---|---|---|
| 1 | Audio §F.1 | D&S emits `dialogue_line_started/finished`; Audio subscribes + ducks | ✅ Already in Audio §F.1 |
| 2 | Audio (NEW) | Voice bus ducks **−12 dB** during `document_opened` (CR-DS-17 v0.3) | ❌ **BLOCKING** — Audio GDD §F amendment needed (Phase 2 propagation) |
| 3 | Stealth AI L91 | CURIOSITY_BAIT vocal plays through state changes (CR-DS-6) | ✅ Already in SAI L91 |
| 4 | Stealth AI ADR-0002 | D&S subscribes to 4 SAI signals | ✅ Already frozen |
| 5 | Civilian AI | D&S subscribes to `civilian_panicked` for VS Category 5 | ✅ Already in CAI |
| 6 | Document Overlay UI ADR-0004 §IG5 | D&S owns its own suppression via `document_opened`/`document_closed`/`ui_context_changed` | ✅ Already in DOV FP-OV-6 |
| 7 | Localization Scaffold | `auto_translate_mode = ALWAYS` + raw key assignment pattern | ✅ Compatible with `tr()` discipline |
| 8 | Settings & Accessibility CR-23 | `subtitles_enabled` default ON at MVP | ✅ Already locked |
| 9 | Settings (NEW) | `subtitle_size_scale` (XL=2.0), `subtitle_background`, `subtitle_speaker_labels` (default ON + **MVP UI toggle**), `subtitle_line_spacing_scale`, `subtitle_letter_spacing_em` knobs | ❌ **BLOCKING** — Settings GDD knob registration (Phase 2 propagation; v0.3 — UI toggle promoted to MVP) |
| 10 | MLS (NEW) | `scripted_dialogue_trigger(scene_id)` signal | ❌ **BLOCKING** — MLS GDD signal contract + ADR-0002 amendment |
| 11 | ADR-0002 | D&S sole-publisher of Dialogue domain | ✅ Already at L304 |
| 12 | ADR-0002 (NEW) | `scripted_dialogue_trigger(scene_id)` MLS-domain signal | ❌ **BLOCKING** — ADR-0002 amendment with MLS owner |
| 13 | ADR-0004 §IG5 | Subtitle owns own suppression (D&S not Overlay) | ✅ Already in §IG5 |
| 14 | ADR-0007 | D&S NOT autoload | ✅ Compatible (per-section instantiation) |
| 15 | **ADR-0008 Slot 8 pooled** *(v0.3 corrected — was Slot 7)* | D&S sub-claim 0.10 ms peak event-frame within 0.8 ms pooled cap | ❌ **BLOCKING** — ADR-0008 amendment registers sub-claim (Phase 2 propagation) |
| 16 | HUD State Signaling | D&S is sibling system; HSS does not own banter | ✅ Already implicit |
| 17 | Document Collection writer brief | BQA acronym never expanded — ported to D&S CR-DS-18 | ✅ Same rule |
| 18 | Engine Reference Godot 4.6 | 4 verification gates VG-DS-1..4 OPEN | ❌ **ADVISORY** — 5-min editor checks |

### C.16 MVP-Day-1 vs VS Slice Boundary

| Component | MVP-Day-1 | VS |
|---|---|---|
| Signal contract `dialogue_line_started/finished` | ✅ Sole-publisher implemented | Same |
| Subtitle renderer (Label, layer 2, layout per §C.10) | ✅ Minimal, instant appear/disappear | Same + `subtitle_speaker_labels` rendering |
| Banter triggers | CURIOSITY_BAIT only (Category 1) | Categories 1–7 (full) |
| Plaza tutorial lines | 3 core (MVP-1, MVP-2, MVP-3) | + 2 stretch (MVP-4, MVP-5) + Plaza VS lines |
| Total VO line count | 3–5 (Plaza tutorial) | 30–50 (game-concept target; design midpoint 40) |
| Suppression: `document_opened`/`document_closed` | ✅ CR-DS-4 | Same + `ui_context_changed` full resolution |
| Self-suppression: `ui_context_changed` | ✅ CR-DS-4 (basic GAMEPLAY check) | Full context resolution |
| Per-actor rate-gate (CR-DS-8) | ✅ 8.0 s default | Same |
| Range gate (CR-DS-9) | ✅ 25 m default | Same |
| Eve-silence (CR-DS-10) | ✅ Enforced | Same |
| Priority resolver | 2 levels: SCRIPTED + CURIOSITY_AMBIENT | Full 5-tier (CR-DS-7) |
| Depth-1 queue | Skipped at MVP (single-bucket trigger surface) | ✅ Active |
| Speaker label rendering | **ON by default + MVP UI toggle** *(v0.3 — D4)* | ON by default (CR-DS-15 v0.3 / CR-DS-16) |
| `subtitles_enabled` path | ✅ CR-DS-11 | Same |
| Section unload (CR-DS-14) | ✅ Full teardown | Same |
| BQA-never-expanded rule (CR-DS-18) | Applied to 3–5 Plaza lines | Full Writer Brief enforcement |
| Word-count ceilings (CR-DS-20) | Applied to 3–5 Plaza lines | Full Writer Brief enforcement |
| 4 Engine verification gates (VG-DS-1..4) | At least VG-DS-1 + VG-DS-3 verified before MVP ship | All 4 verified |
| AccessKit live-region (CR-DS-12 / VG-DS-2) | Property name TBD; placeholder pending Gate 1 | Verified + active |
| New Audio coord (CR-DS-17 Voice ducking during overlay) | Skipped at MVP (overlay is VS feature anyway) | ✅ Active |
| Writer Brief (`design/narrative/dialogue-writer-brief.md`) | Plaza tutorial subset only | Full per-section authoring contract |
| MLS `scripted_dialogue_trigger` signal | Hardcoded MVP-3 BQA briefing trigger acceptable | Full signal contract via ADR-0002 amendment |

## Formulas

### D.1 Scope Statement

D&S has minimal balance math. Most system behaviour is governed by timing predicates and a priority comparator, not gameplay arithmetic. Where formulas appear below, they are constraint expressions — timing floors, eligibility guards, and frame-cost compositions. Comedy quality is qualitative: it is enforced by the Writer Brief and the §B.3 refusals, not by any formula. F.1–F.4 are engine constraints; F.5 is an advisory density check against content-spam.

### F.1 — Caption Clear Time

The caption-clear formula is defined as:

`caption_clear_time = max(audio_play_start + audio_duration_s, line_start_time + duration_metadata_s)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Audio playback start timestamp | `audio_play_start` | float | [0.0, unbounded) s | `Time.get_ticks_msec()` converted to seconds at the moment `_audio_player.play()` is called (step 4 of CR-DS-2 lifecycle) |
| Audio clip duration | `audio_duration_s` | float | (0.1, 15.0] s for banter; (0.1, 30.0] s for SCRIPTED_SCENE *(v0.3 — split per CR-DS-20)* | Duration in seconds of the bound `AudioStream` resource. Banter cap (15 s) aligns with the CR-DS-20 12-word ceiling at slow delivery (~1 s/word + pause). SCRIPTED carve-out keeps 30 s for radio/cable broadcasts (VT-8). Lower bound 0.1 s enforced by FP-DS-21. |
| Line scheduling timestamp | `line_start_time` | float | [0.0, unbounded) s | Timestamp at which `select_line()` resolved and the lifecycle began (step 1); in practice equals `audio_play_start` ± one frame |
| Caption floor from metadata | `duration_metadata_s` | float | [0.0, 30.0] s | Author-set slow-reader floor on the `DialogueLine` resource; 0.0 means "use audio length only" |
| Caption clear timestamp | `caption_clear_time` | float | (0.0, unbounded) s | The absolute time at which `dialogue_line_finished()` may fire and `_label.text` may be cleared |

**Output Range:** `[audio_play_start + audio_duration_s, +inf)` in degenerate cases; under normal play always in the range `[audio_duration_s, max(audio_duration_s, duration_metadata_s)]` seconds after line start. The result is clamped below by audio length — a caption can never clear before the clip finishes. It is bounded above by the longer of the two durations; no open-ended timer is created.

**Implementation note:** `duration_metadata_s = 0.0` on a `DialogueLine` resource collapses to `max(audio_end, line_start + 0.0)`, which equals the audio end exactly. This is the correct fallback per CR-DS-2 step 6.

**Example A (slow-reader floor active):** VO clip = 3.2 s; `duration_metadata_s = 4.5` s; `line_start_time = audio_play_start = 100.0` s.
`caption_clear_time = max(100.0 + 3.2, 100.0 + 4.5) = max(103.2, 104.5) = 104.5 s`
Caption stays 4.5 s — 1.3 s of silent reading time after audio ends.

**Example B (audio longer than metadata):** VO clip = 5.0 s; `duration_metadata_s = 4.5` s; `line_start_time = audio_play_start = 100.0` s.
`caption_clear_time = max(100.0 + 5.0, 100.0 + 4.5) = max(105.0, 104.5) = 105.0 s`
Caption clears with the audio. Metadata floor is irrelevant.

### F.2 — Per-Actor Rate-Gate Predicate

The per-actor eligibility predicate is defined as:

`is_eligible(actor) = (now_s - last_bark_time[actor] >= dialogue_per_actor_cooldown_s) AND is_instance_valid(actor) AND in_range(actor)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current engine time | `now_s` | float | [0.0, unbounded) s | `Time.get_ticks_msec() / 1000.0` at the moment `select_line()` evaluates |
| Last bark timestamp for actor | `last_bark_time[actor]` | float | [0.0, unbounded) s | Stored in `_actor_last_bark_time: Dictionary[Node, float]`; absent key treated as `0.0` (never barked → always eligible on first evaluation) |
| Per-actor cooldown duration | `dialogue_per_actor_cooldown_s` | float | [3.0, 30.0] s | Tunable default 8.0 s; safe range per CR-DS-8 |
| Instance validity check | `is_instance_valid(actor)` | bool | {true, false} | Guards freed-node lookup; false short-circuits remaining checks |
| Range gate | `in_range(actor)` | bool | {true, false} | Defined by F.3 below |
| Eligibility result | `is_eligible` | bool | {true, false} | true = `select_line()` may return a line for this actor |

**Output Range:** Boolean. `true` only when all three clauses hold. Short-circuit evaluation left-to-right: `is_instance_valid` check first (cheapest guard against GDScript null-deref on freed nodes), cooldown arithmetic second, range check third.

**Edge — first bark:** absent key in `_actor_last_bark_time` is treated as `0.0`. `now_s - 0.0 = now_s` which is always `>= dialogue_per_actor_cooldown_s` after any non-trivial session time. Actor is eligible on first evaluation.

**Edge — SCRIPTED bypass:** `priority_bucket = SCRIPTED` lines skip this predicate entirely. `select_line()` does not evaluate F.2 for SCRIPTED triggers per CR-DS-9.

**Example:** `now_s = 142.3`, `last_bark_time[guardA] = 135.0`, `dialogue_per_actor_cooldown_s = 8.0`.
`142.3 - 135.0 = 7.3 < 8.0` → cooldown clause is `false` → `is_eligible = false`. Guard A cannot bark yet.

### F.3 — Range Gate Predicate

The range gate predicate is defined as:

`in_range(actor, player) = actor.global_position.distance_to(player.global_position) <= dialogue_bark_range_m`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Actor world position | `actor.global_position` | Vector3 | scene bounds | World-space position of the NPC Node3D at evaluation time |
| Player world position | `player.global_position` | Vector3 | scene bounds | World-space position of the player Node3D; retrieved at `_ready()` via canonical path |
| Bark range threshold | `dialogue_bark_range_m` | float | [10.0, 50.0] m | Tunable default 25.0 m per CR-DS-9 |
| Range gate result | `in_range` | bool | {true, false} | true = actor is within hearing range of the player |

**Output Range:** Boolean. Euclidean (straight-line) distance, not path distance or navmesh distance. Path/navmesh distance is rejected: (a) it costs nav-query overhead on every `select_line()` call, violating the ADR-0008 budget; (b) through-wall bark detection would undermine Pillar 3 stealth-as-theatre by giving the player audio cues from actors they cannot physically overhear.

**SCRIPTED bypass:** `priority_bucket = SCRIPTED` lines skip this predicate per CR-DS-9. MLS-authored lines always play regardless of distance.

**Null guard (v0.3 — explicit polarity):** if `player` ref is null, the polarity is **bimodal** depending on lifecycle phase:
- **At boot (`_player_ready = false`):** this predicate is **overridden by CR-DS-9 to fail CLOSED** — `select_line()` returns null for all non-SCRIPTED triggers. Eliminates the all-actor-bark burst risk during section load. SCRIPTED triggers still bypass.
- **At runtime (`_player_ready = true` then ref becomes null):** range gate fails **OPEN** (returns `true`) — a missing ref must not silently drop Pillar 1 comedy lines. This case only triggers if the player node is freed by an unanticipated event after section-load completion.

The two cases are intentionally asymmetric: boot-time silence > unexpected bark burst; runtime safety-net > silent drop. A programmer reading F.3 without §C.9's CR-DS-9 must NOT collapse this to a single "fails OPEN" rule.

**Example:** actor at `(12.0, 0.0, 5.0)`, player at `(0.0, 0.0, 0.0)`, `dialogue_bark_range_m = 25.0`.
Distance = `sqrt(144 + 0 + 25)` = `sqrt(169)` = `13.0 m`. `13.0 <= 25.0` → `in_range = true`.

### F.4 — Frame-Cost Composition (Signal-Emit Event Frame)

Methodology follows Document Collection §F.1 and HUD Core §F.5: worst-case per-operation estimates summed to a peak event-frame cost, compared against the **ADR-0008 Slot 8 pooled residual 0.8 ms shared cap** *(v0.3 correction: prior versions referenced "Slot 7 / UI / 0.3 ms" — that was wrong; ADR-0008 §85 places D&S in Slot 8 alongside CAI / MLS / DC / F&R / Signal-Bus dispatch; ADR-0008 §239 explicitly enumerates D&S there as "unspecified" pending this sub-claim)*. These are empirical estimates for GDScript on the project's minimum target hardware — not profiler measurements. Validate against actual profiler output before finalising the sub-claim.

The per-event-frame cost formula is defined as:

`t_dialogue_event = t_select_line + t_audio_play + (t_signal_emit × N_sub) + t_label_assign + t_timer_start`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Line selection cost | `t_select_line` | float | [0.005, 0.015] ms | Dictionary lookup + F.2 rate-gate eval + F.3 range check + priority comparator |
| Audio play cost | `t_audio_play` | float | [0.010, 0.030] ms | `AudioStreamPlayer.play()` with stream already assigned; no decode cost at trigger |
| Signal emit cost per subscriber | `t_signal_emit` | float | [0.003, 0.007] ms | One GDScript `emit_signal` dispatch × `N_sub` subscribers; primary subscribers are Audio (ducking) + Subtitle internal handler |
| Number of signal subscribers | `N_sub` | int | [1, 8] | Subscriber count at emit time; 2 typical (Audio + Subtitle); max 4–8 if mission scripting and achievement systems also subscribe |
| Label text assignment | `t_label_assign` | float | [0.003, 0.007] ms | `Label.text = key` with `auto_translate_mode = ALWAYS`; triggers `tr()` lookup through Localization Scaffold |
| Timer start | `t_timer_start` | float | [0.001, 0.003] ms | `Timer.start(duration)` one-shot |
| Total event-frame cost | `t_dialogue_event` | float | [0.0, ~0.13] ms | Peak per-event-frame; 0.0 ms steady-state (no `_process` loop) |

**Output Range:** Typical (N_sub = 2): `0.010 + 0.020 + 0.010 + 0.005 + 0.002 = 0.047 ms`. Worst-case (N_sub = 8, all upper bounds): `0.015 + 0.030 + 0.056 + 0.007 + 0.003 = 0.111 ms`. **Steady-state: 0.0 ms** — D&S uses no `_process` callback; all cost is event-driven and occurs only in the frame a new line is triggered.

**ADR-0008 Slot 8 sub-claim (v0.3):** D&S claims **0.10 ms peak event-frame** out of the 0.8 ms pooled Slot 8 cap shared with CAI (registered 0.30 ms p95), MLS (0.1 ms steady-state + 0.3 ms peak), DC (0.05 ms peak event-frame), F&R (~0 ms outside flow), and Signal Bus dispatch overhead. Sum across registered systems: 0.30 + 0.30 + 0.05 + 0 + 0.10 = 0.75 ms steady-state — within 0.8 ms cap with 0.05 ms residual margin. Panic-onset frame governance lives under the Slot 8 reserve carve-out (ADR-0008 §Risks 2026-04-28 amendment). The rare three-way priority-resolver eviction (in-flight line interrupted, queue evicted, new line started) may momentarily burst to ~0.13 ms; this is an acceptable brief exceedance on a non-recurring frame, not a steady-state violation. **Phase 2 propagation:** ADR-0008 amendment registers this 0.10 ms sub-claim line.

**Example (N_sub = 2 typical):**
`t_dialogue_event = 0.010 + 0.020 + (0.005 × 2) + 0.005 + 0.002 = 0.047 ms`
Well within the 0.10 ms sub-claim. Peak exceedance scenario (N_sub = 4, priority eviction): `~0.075 ms` — still within claim.

### F.5 — Per-Section Banter Density (Advisory Heuristic, Non-Binding) *(v0.3 — reclassified)*

> **v0.3 reclassification note:** F.5 is NOT a runtime engine formula and does not constrain dispatch behavior. It is an **authoring-time heuristic** that estimates *authored* line density per section against an empirically ungrounded NOLF1 reference band. **Actual fired density** is bounded by `min(authored_density, N_actors_in_range / dialogue_per_actor_cooldown_s × 60)` and can only be measured during VS playtest (GAP-DS-5). The "safe band" thresholds below are content-planning targets, not validation gates — playtest data supersedes them.

The per-section density formula is defined as:

`lines_per_minute_section = section_line_count / typical_section_duration_minutes`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Section line count | `section_line_count` | int | [1, 20] | Total authored `DialogueLine` resources scoped to the section (§C.6 distribution) |
| Typical section duration | `typical_section_duration_minutes` | float | (0.0, 30.0] min | Expected median playthrough time for the section, based on playtesting estimates |
| Banter density | `lines_per_minute_section` | float | [0.0, unbounded) lines/min | Rate of potential barks per minute; advisory only — actual rate is lower due to rate-gate + range gate suppression |

**Output Range:** Advisory float. Hard thresholds: below 0.3 lines/min = sparse-fail risk (section feels silent, Pillar 1 unserved); above 1.5 lines/min = chatter-spam risk (Eavesdrop fantasy undermined, player cannot process lines). Safe design band: [0.5, 1.0] lines/min. Note that this is the density of authored lines, not fired lines — rate-gate and range gate reduce actual fired density further.

**Per-section results (§C.6 distribution):**

| Section | Lines | Duration (est.) | Density | Status |
|---|---|---|---|---|
| Plaza (tutorial) | 5 | 8 min | 0.6 lines/min | Safe — intentionally sparse; player learning |
| Lower Scaffolds | 8 | 12 min | 0.7 lines/min | Safe |
| Restaurant | 12 | 18 min | 0.7 lines/min | Safe — peak comedy density, not spam |
| Upper Structure | 10 | 15 min | 0.7 lines/min | Safe |
| Bomb Sequence | 5 | 7 min | 0.7 lines/min | Safe — deliberately sparse; drama register |

All five sections sit in the [0.5, 1.0] safe band. The distribution validates that neither the tutorial nor the climax drifts into chatter territory. This formula is a content-audit tool for the Writer Brief review cycle, not a runtime engine formula.

## Edge Cases

### Cluster A — Same-Frame Trigger Storms

**A.1** If two CURIOSITY_BAIT triggers fire on different actors in the same frame: the first to arrive (signal dispatch order) wins the in-flight slot; the second is evaluated against the depth-1 queue. If the queue is empty, it is enqueued. If the queue is occupied, it is dropped silently. No coin-flip; arrival order is deterministic within a single `_process` cycle.

**A.2** If `SAW_PLAYER` (bucket 2) and CURIOSITY_BAIT (bucket 4) arrive the same frame on the same actor: `SAW_PLAYER` wins unconditionally; CURIOSITY_BAIT is dropped (lower priority, not queued — buckets 3–5 are not queued behind a bucket-1/2 interrupt; queue is reserved for near-equal priority hold).

**A.3** If SCRIPTED (bucket 1) and COMBAT_DISCOVERY (bucket 2) arrive same frame: SCRIPTED wins; COMBAT_DISCOVERY is dropped. If a line is already in flight, SCRIPTED interrupts it per CR-DS-7, emits `dialogue_line_finished()` first, then starts the SCRIPTED line.

**A.4** If two bucket-2 (COMBAT_DISCOVERY) triggers arrive same frame from different actors: the first by signal dispatch order claims in-flight; the second is dropped (bucket-2 triggers are acute urgency events — stacking them undermines the 4-word-cap discipline of CR-DS-20 and creates double-duck artifacts on the Voice bus).

**A.5** If a trigger arrives in the same frame as `_exit_tree` (section unload): `_exit_tree` takes priority; the trigger is discarded. `_exit_tree` sets internal state to HIDDEN and disconnects all subscriptions before any queued signal dispatch can act on the instance.

**A.6** If a trigger fires while a line is between step 3 (`dialogue_line_started` emitted) and step 4 (`_audio_player.play()` — same frame, different execution order): treat as in-flight. The priority-resolver evaluates normally; a higher-priority interrupt calls `_audio_player.stop()` on a stream that hasn't started yet. This is safe: `stop()` on an unstarted player is a no-op; `dialogue_line_finished()` is still emitted to release Audio ducking.

**A.7** If five or more banter triggers arrive in a single frame: only one enters in-flight, at most one enters the depth-1 queue. All others are dropped silently. No warning is logged; banter drop is an expected steady-state outcome of the density model, not an error condition.

### Cluster B — Caption-Clock Degenerate Cases

**B.1** If `duration_metadata_s = 0.0` on a DialogueLine: F.1 collapses to `max(audio_end, line_start + 0.0) = audio_end`. The caption timer starts with `wait_time = 0.0`; a zero-duration Timer fires immediately on the next frame. Because both conditions must satisfy CR-DS-2 step 7, the caption clears only when `_audio_player.finished` also fires — the timer fires first, waits for audio. This is the documented correct fallback per F.1.

**B.2** If `audio_duration_s` exceeds `duration_metadata_s` by more than 5 s: the caption clock follows the audio (F.1 `max()` selects audio end). This is not an error; the metadata floor is simply irrelevant. However, this pattern indicates a DialogueLine resource authoring inconsistency — authoring lint should warn when `audio_duration_s - duration_metadata_s > 5.0 s`. **NEW ADVISORY coord (EC-DS-1):** authoring validator in Writer Brief pipeline should flag this gap.

**B.3** If `AudioStreamPlayer.finished` never fires (corrupt or zero-length stream): the caption stays visible indefinitely because CR-DS-2 step 7 requires both signals. Mitigation: `_caption_timer` fires after `duration_metadata_s`; if `duration_metadata_s = 0.0`, the timer fires immediately (next frame). If `duration_metadata_s > 0.0`, the caption clears at metadata floor even without audio finished. If both `duration_metadata_s = 0.0` AND audio never finishes: the caption is orphaned. Guard: `select_line()` enforces FP-DS-2 (null audio_stream rejected before play) — a corrupt stream is an asset-pipeline failure, not a runtime branch D&S must handle gracefully. Push_error and halt line.

**B.4** If `_caption_timer.timeout` fires before `_audio_player.finished`: caption remains visible (state stays VISIBLE), timer flag is set, line waits for audio completion. When `_audio_player.finished` fires, both flags are satisfied, `dialogue_line_finished()` emits, caption clears. This is the normal slow-reader-floor path (Example A in F.1).

**B.5** If `_audio_player.finished` fires before `_caption_timer.timeout`: audio flag is set, caption remains visible, timer continues running. When `_caption_timer.timeout` fires, both flags satisfied, line completes. This is the normal fast-speaker path (Example B in F.1 inverted — short audio, long metadata floor).

### Cluster C — Suppression + Overlay Lifecycle

**C.1** If `document_opened` fires mid-bark and `document_closed` fires before the bark ends: on `document_opened`, set `_suppressed = true`, hide CanvasLayer — audio continues. On `document_closed` (back to GAMEPLAY), set `_suppressed = false`, re-show CanvasLayer — caption resumes for remaining line duration (SUPPRESSED → VISIBLE per §C.2 state machine). No line is dropped or re-started.

**C.2** If `ui_context_changed` fires to MENU mid-bark: set `_suppressed = true`, hide CanvasLayer per CR-DS-4. Audio continues to play and `dialogue_line_finished()` fires at natural completion — Audio ducking is released correctly even while caption is suppressed. When context returns to GAMEPLAY, if the line has already finished, transition SUPPRESSED → HIDDEN (empty). If the line is still in flight (unlikely given typical menu-open duration vs bark length), transition SUPPRESSED → VISIBLE.

**C.3** If `document_opened` is immediately followed by `document_closed` within the same frame: both signals arrive in the same `_process` dispatch cycle. Apply in signal-arrival order: `_suppressed = true` then `_suppressed = false` — net result is no suppression. Caption visibility unchanged. This edge is harmless; the rapid toggle is an authoring error in the Document Overlay system, not a D&S fault.

**C.4** If `document_opened` fires while a SCRIPTED line is in flight: D&S suppresses the caption (CanvasLayer hidden) per CR-DS-4 — SCRIPTED does NOT bypass suppression. The SCRIPTED bypass applies only to rate-gate (CR-DS-8) and range gate (CR-DS-9). Audio continues. Caption re-appears on `document_closed` if the SCRIPTED line is still in flight.

**C.5** If a suppression event (`document_opened`) fires while a line is in the depth-1 queue: the queued line's metadata is preserved. On `document_closed`, if the in-flight line has finished, the queue is evaluated normally (re-check rate-gate, range, `is_instance_valid`). The queue does not auto-discard due to suppression alone.

### Cluster D — Locale + tr() Edge Cases

**D.1** If `NOTIFICATION_TRANSLATION_CHANGED` fires mid-bark with caption visible: `auto_translate_mode = ALWAYS` re-resolves `_label.text` automatically to the new locale's string for the same key. No manual `_notification` override needed (VG-DS-1 design intent). The caption updates in place — same key, new locale string. Audio continues in original locale (VO asset is locale-specific at the file level; mid-bark locale switch produces mixed-language output, which is an edge case accepted as known; no special handling).

**D.2** If `line.text_key` resolves to an empty string `""` via `auto_translate_mode`: Label renders visibly empty. Audio continues and finishes normally. `dialogue_line_started` / `dialogue_line_finished` emit correctly. This is a localization authoring error — the key exists but maps to an empty translation. Push_warning with the line_id. The empty caption is functionally equivalent to `subtitles_enabled = false` for that line.

**D.3** If `line.text_key` resolves to a missing-key pattern such as `"MISSING:vo.banter.foo"` (Godot's default missing-translation fallback): the Label renders the raw fallback string, which is visible but unintelligible in a subtitle context. Push_warning with key name at render time. This surfaces localization gaps during playtesting. Do NOT attempt to hide the label — the missing key must be visible in QA.

**D.4** If a locale change fires while a line is in the depth-1 queue: the queued line's `text_key` is a raw `StringName`. When the queued line eventually plays, `auto_translate_mode` resolves it in the then-current locale. No stale translation is possible; the key is never resolved until render step 5 of CR-DS-2.

### Cluster E — SAI Signal Interaction Edge Cases

**E.1** If `guard_incapacitated` fires for the same guard whose CURIOSITY_BAIT bark is in flight: the in-flight bark completes (CR-DS-6 CURIOSITY_BAIT protection — only buckets 1–2 may interrupt). After completion, `dialogue_line_finished()` emits, rate-gate timer starts. The incapacitated guard's entry in `_actor_last_bark_time` persists; `is_instance_valid` guard on future lookups will skip it cleanly if the node is freed.

**E.2** If `actor_became_alerted(cause=SAW_PLAYER)` arrives while the same actor's CURIOSITY_BAIT bark is in flight: `SAW_PLAYER` is bucket 2 (COMBAT_DISCOVERY) and is one of the two permitted interruptors per CR-DS-6. D&S emits `dialogue_line_finished()`, calls `_audio_player.stop()`, clears caption, and starts the SPOTTED bark. The CURIOSITY_BAIT comedy beat is sacrificed for the stealth-alarm read — correct pillar priority (P3 beats P1 in crisis).

**E.3** If `alert_state_changed` fires UNAWARE → SUSPICIOUS while a CURIOSITY_BAIT bark is in flight: no interrupt. CR-DS-6 explicitly protects CURIOSITY_BAIT from bucket-3 and lower triggers. The bark completes on its own clock. This is the Stealth AI L91 carve-out: alert-state change does not own the VO clock.

**E.4** If `guard_woke_up` fires for a guard who was incapacitated 60 s ago and has a stale rate-gate entry: `_actor_last_bark_time[guard]` records the pre-incapacitation bark time. `now_s - last_bark_time` will be >> 8.0 s, so the guard is immediately eligible. This is correct behavior — waking up resets the comedy opportunity. No special wake-up clearing needed.

**E.5** If the actor Node is freed from the tree mid-bark (e.g., guard removed by scripted event): `_audio_player.finished` fires normally (audio is on D&S's own node, not the actor). `dialogue_line_finished()` emits normally. On next `select_line()` call or queue re-evaluation, `is_instance_valid(actor)` returns false and the stale entry is skipped. D&S does not hold a strong reference that would prevent freeing.

### Cluster F — Save/Load + Section Unload

**F.1** If save is invoked mid-bark: per CR-DS-13, no `SaveGame` sub-resource exists. The bark continues playing (audio and caption proceed normally). The saved game snapshot contains no D&S state. On load, D&S starts in HIDDEN state with empty dictionaries. This is correct and intentional; mid-bark restoration is impossible at the audio layer and unnecessary for gameplay.

**F.2** If load is invoked while D&S has empty state (no line in flight, no queue): `_actor_last_bark_time` and depth-1 queue are already empty. Load produces no observable change in D&S. Normal trigger flow resumes on next SAI/MLS event.

**F.3** If LSS fires `_exit_tree` (section unload) mid-bark: per CR-DS-14, `_audio_player.stop()` is called (no fade), `dialogue_line_finished()` is emitted (Audio ducking released), `_label.text` cleared, state set HIDDEN, all Event subscriptions disconnected. The teardown is synchronous within `_exit_tree` — no deferred callbacks survive.

**F.4** If quick-load is invoked immediately after quick-save with a bark in flight: the save snapshot contains no bark state (F.1). The load tears down the current scene, reinstantiates D&S clean, bark is silently abandoned. Audio ducking may be orphaned for one frame if `dialogue_line_finished()` was not emitted before scene teardown. Guard: LSS section unload must call `_exit_tree` teardown path before scene swap — this is an LSS responsibility. **NEW BLOCKING coord (EC-DS-2):** LSS must guarantee `_exit_tree` (and therefore `dialogue_line_finished()`) fires before scene swap on quick-load.

### Cluster G — Subscriber Lifecycle / Signal Hygiene

**G.1** If the Audio system has not yet initialized when D&S emits `dialogue_line_started` (early-boot signal ordering): the signal emits into an empty subscriber list. Audio ducking does not occur, VO plays at full mix. This is a boot-order authoring error; per-section instantiation (NOT autoload) means both systems initialize at section load — LSS must guarantee Audio initializes before D&S's `_ready()` runs. **NEW BLOCKING coord (EC-DS-3):** LSS initialization order must document Audio before D&S.

**G.2** If a subscriber connects, disconnects, and reconnects to `dialogue_line_started`: CR-DS-14 disconnects all subscriptions in `_exit_tree` using `is_connected()` guards. Reconnect on next section instantiation is normal. The `is_connected()` guard in teardown prevents double-disconnect errors; the subscriber's `_ready()` guard prevents double-connect errors. Both sides are responsible for their own connection lifecycle per ADR-0002 IG3.

**G.3** If D&S's `_exit_tree` fires while a signal is mid-emit (e.g., `dialogue_line_started` is being dispatched to subscribers when the node is freed): Godot 4 defers node freeing until after the current signal dispatch chain completes. The emit finishes cleanly; subscribers receive the signal. `_exit_tree` teardown runs after dispatch. No partial-emit corruption.

### Cluster H — Settings + Accessibility

**H.1** If `subtitles_enabled` is toggled false mid-bark: caption clears immediately (`_label.text = ""`), CanvasLayer visibility set to match suppressed state. Audio continues and completes normally. `dialogue_line_finished()` emits at natural audio+timer completion. Per CR-DS-11, the full lifecycle runs — only step 5 (label render) is skipped going forward.

**H.2** If `subtitle_size_scale` is changed while caption is visible: the Label's theme font-size override is updated immediately on `setting_changed("subtitle_size_scale", value)`. Godot's Label reflows text automatically; no caption re-emit or lifecycle restart needed. Position anchoring (PRESET_BOTTOM_CENTER) maintains placement. Verify at 1.25× scale that caption still clears HUD widgets per FP-DS-20.

**H.3** If `subtitle_speaker_labels` is toggled mid-bark: the in-flight caption is NOT retroactively re-rendered. The new setting applies to the next line that renders. Mid-line caption re-render would cause a visible text jump that violates §B.3 refusal #1 (no pop/no announce). Accept the single-line lag; it is unobservable in normal play.

### Cluster I — Pillar / Forbidden Pattern Enforcement

**I.1** If `DialogueLine.audio_stream` is null at `select_line()` invocation: `select_line()` returns null, emits push_error with line_id, no lifecycle begins. This enforces FP-DS-2: D&S must never emit `dialogue_line_started` without a stream actually playing. The null check is the first guard in `select_line()`, before any signal emission.

**I.2** If a `DialogueLine` resource has `speaker_id = "EVE"` and `banter_category` is not `SCRIPTED_SCENE`: `select_line()` rejects it with `push_warning` and returns null per CR-DS-10. No playback occurs. This is a Writer Brief / asset-pipeline enforcement gate — the warning surfaces during QA playtesting, not silently at runtime.

**I.3** If `line.text_key` content (when resolved) contains BBCode markup such as `[b]word[/b]`: `Label` renders BBCode tags as literal text (`[b]word[/b]` appears verbatim). This is the correct behavior — §C.3 mandates plain `Label` (not `RichTextLabel`) per FP-DS-15. The visual output is wrong but not a crash. BBCode in VO subtitles is a Writer Brief authoring error; authoring lint should flag text keys containing `[` characters. **NEW ADVISORY coord (EC-DS-5):** text-key content validator should reject keys containing `[` to catch misrouted markup.

### Cluster J — Engine Knowledge Gap (Verification Gates)

**J.1** If VG-DS-1 fails (i.e., `auto_translate_mode = ALWAYS` does NOT auto-re-resolve on locale change in Godot 4.6): add a manual `_notification(what)` override that calls `_label.text = String(line.text_key)` when `what == NOTIFICATION_TRANSLATION_CHANGED`. This is a fallback only; do not add preemptively (it would re-introduce the risk of double-translation if `auto_translate_mode` also fires).

**J.2** If VG-DS-2 fails (i.e., the exact property name for AccessKit live-region on `Label` in Godot 4.6 differs from `accessibility_live`): revise CR-DS-12 with the verified property name and update the scene spec in §C.3. The spec is not implemented until the verified name is confirmed. Do not guess property names — use the in-editor Inspector to confirm.

**J.3** If VG-DS-3 fails (i.e., `CanvasLayer.visible = false` does NOT suppress AccessKit announcements from child Labels in Godot 4.6): add an explicit `_label.visible = false` call in CR-DS-4's suppression path alongside `SubtitleCanvasLayer.visible = false`. Both must be set to guarantee AccessKit silence during overlay.

**J.4** If VG-DS-4 fails (i.e., `AudioStreamPlayer.finished` DOES fire on `.stop()` in Godot 4.6): rework the CR-DS-7 interrupt path to set a boolean flag `_stopping_for_interrupt = true` immediately before `_audio_player.stop()`, and gate the `_on_audio_finished` handler to no-op when that flag is true. Reset the flag after the interrupt's new line starts. This prevents a duplicate `dialogue_line_finished()` emit that would release Audio ducking prematurely. **NEW conditional BLOCKING coord (EC-DS-4):** if VG-DS-4 confirms this behavior, ADR-0008 **Slot 8 pooled** sub-claim cost estimate must add one Dictionary write + bool check per interrupt (~0.001 ms — negligible, but sub-claim must be re-signed). *(v0.3 — Slot 7 was wrong; corrected to Slot 8.)*

### Summary of NEW coord items emerging from §E

| ID | Item | Owner | Type |
|----|------|-------|------|
| **EC-DS-1** | Authoring lint: warn when `audio_duration_s - duration_metadata_s > 5.0 s` | Writer Brief pipeline | ADVISORY |
| **EC-DS-2** | LSS must guarantee `_exit_tree` (and `dialogue_line_finished()`) fires before scene swap on quick-load | LSS GDD | BLOCKING |
| **EC-DS-3** | LSS initialization order must document Audio before D&S at section load | LSS / Audio GDD | BLOCKING |
| **EC-DS-4** | If VG-DS-4 confirms `.stop()` fires `.finished`: ADR-0008 **Slot 8** sub-claim re-sign after adding interrupt-flag guard *(v0.3 — Slot 7 corrected to Slot 8)* | ADR-0008 | BLOCKING (conditional) |
| **EC-DS-5** | Advisory lint: text-key content validator should reject keys containing `[` (BBCode misroute) | Writer Brief pipeline | ADVISORY |

## Dependencies

### F.1 Hard Upstream Dependencies (system cannot function without)

| # | System | Status | Interface |
|---|---|---|---|
| 1 | **Audio** | ✅ Approved | Subscribes to `dialogue_line_started`/`finished` for ducking (Audio §F.1). New: subscribes to `document_opened`/`document_closed` for Voice bus −6 dB ducking per CR-DS-17 (BLOCKING coord). |
| 2 | **Localization Scaffold** | ✅ Designed | Provides `tr()` + `auto_translate_mode = ALWAYS` + `NOTIFICATION_TRANSLATION_CHANGED` re-resolve. CSV string-table for `vo.banter.*` / `vo.scripted.*` / `vo.speaker.*` keys. |
| 3 | **Stealth AI** | ✅ Approved 2026-04-22 | Publishes 4 frozen signals D&S subscribes to: `actor_became_alerted(actor, cause, source_position, severity)` (cause enum: HEARD_NOISE, SAW_PLAYER, SAW_BODY, HEARD_GUNFIRE, ALERTED_BY_OTHER, SCRIPTED, CURIOSITY_BAIT), `alert_state_changed(actor, prev, new, severity)`, `guard_incapacitated(guard, cause)`, `guard_woke_up(guard)`. CR-DS-6 honors SAI L91 vocal-completion carve-out. |
| 4 | **Signal Bus** (ADR-0002) | Needs Revision | Provides `Events` autoload for signal dispatch. D&S sole-publisher of Dialogue domain (L304). NEW signal `scripted_dialogue_trigger(scene_id: StringName)` MLS-domain BLOCKING amendment. |

### F.2 Soft Upstream / Mediated Dependencies

| # | System | Status | Interface | Tier |
|---|---|---|---|---|
| 5 | **Civilian AI** | Needs Revision | Publishes `civilian_panicked(actor, cause)` for VS Category 5 (CIVILIAN_REACTION) banter trigger | VS |
| 6 | **Combat & Damage** | Needs Revision | Publishes `weapon_fired_in_public` for VS Category 5 banter trigger | VS |
| 7 | **Mission & Level Scripting** | Needs Revision | Publishes `scripted_dialogue_trigger(scene_id)` for SCRIPTED Category 7 (NEW BLOCKING signal) | MVP partial / VS full |
| 8 | **Document Collection** | Needs Revision | Publishes `document_opened`/`document_closed` (existing frozen signals) — D&S subscribes for self-suppression per CR-DS-4 | MVP |
| 9 | **InputContext** (ADR-0004) | Proposed | Publishes `ui_context_changed(new_ctx, old_ctx)` — D&S subscribes for self-suppression per CR-DS-4 | MVP |
| 10 | **Settings & Accessibility** | Needs Revision | Provides `subtitles_enabled`, `subtitle_size_scale` (S/M/L/XL), `subtitle_background`, `subtitle_speaker_labels` (**MVP** UI toggle — v0.3), `subtitle_line_spacing_scale`, `subtitle_letter_spacing_em` — all MVP. Publishes `setting_changed(key, value)` | MVP full |
| 11 | **Save / Load** | Needs Revision | **No interface** — D&S holds zero SaveGame state (CR-DS-13) | (none) |
| 12 | **Level Streaming Service** | ✅ Approved 2026-04-21 | Lifecycle: `_exit_tree` teardown on section unload (CR-DS-14). NEW coord: LSS must guarantee Audio init before D&S init at section load (EC-DS-3) AND `_exit_tree` fires before scene swap on quick-load (EC-DS-2) | MVP |

### F.3 ADR Dependencies

| # | ADR | Constraint | Status |
|---|---|---|---|
| **ADR-0002** | Signal Bus event taxonomy: D&S sole-publisher of Dialogue domain (L304); subscribes to SAI/CAI/Combat/UI domain signals | ✅ Frozen at L304 + ❌ **BLOCKING amendment** for `scripted_dialogue_trigger(scene_id)` MLS-domain signal |
| **ADR-0004** | UI Framework: §IG5 Subtitle owns own suppression via `document_opened`/`document_closed`/`ui_context_changed`; Gate 1 `accessibility_live` property name OPEN; Gate 2 Theme inheritance prop name OPEN | ✅ §IG5 frozen + ❌ Gates 1+2 OPEN (BLOCKING for VS AccessKit) |
| **ADR-0007** | Autoload load-order registry: D&S NOT autoload (per-section instantiation) | ✅ Compatible |
| **ADR-0008** | Performance budget distribution: D&S sub-claims 0.10 ms peak event-frame of **Slot 8 pooled (0.8 ms shared with CAI / MLS / DC / F&R / Signal-Bus dispatch)** *(v0.3 corrected — was Slot 7 / UI / 0.3 ms)* | ❌ **BLOCKING amendment** for Slot 8 sub-claim formal registration (Phase 2 propagation) |

### F.4 Forward Dependents (systems that consume D&S)

| # | System | Status | Interface |
|---|---|---|---|
| 1 | **Audio** | ✅ Approved | Subscribes to D&S's `dialogue_line_started`/`finished` for ducking (Audio §F.1). New: subscribes to overlay signals for Voice ducking per CR-DS-17. |
| 2 | **Cutscenes & Mission Cards (#22)** | Not Started | Forward dep: when designed, may trigger SCRIPTED Category 7 lines via MLS `scripted_dialogue_trigger`. No D&S contract surface yet. |
| 3 | **Writer Brief** (`design/narrative/dialogue-writer-brief.md`) | NOT YET AUTHORED | VS BLOCKING authoring contract — defines per-section line content + 7 speaker categories (§C.8) + 8 voice/tone rules (§C.9) + word-count ceilings (CR-DS-20) + BQA-never-expanded (CR-DS-18) |
| 4 | **MLS** | Needs Revision | When MLS adopts `scripted_dialogue_trigger(scene_id)` signal: MLS becomes upstream publisher AND D&S validates that scene_id maps to a known DialogueLine roster |

### F.5 Forbidden Non-Dependencies (explicit non-couplings)

| # | System | Why D&S MUST NOT depend on it |
|---|---|---|
| 1 | **HUD Core** | D&S is sibling system on different CanvasLayer; D&S does NOT extend HUD Core (HUD Core's prompt-strip is a different surface) |
| 2 | **HUD State Signaling** | HSS does NOT manage banter chips, captions, or speaker labels (FP-DS-6, §C precedent) |
| 3 | **Document Overlay UI** | Document Overlay does NOT call any method on D&S; D&S subscribes to `document_opened`/`document_closed` independently (ADR-0004 §IG5 + DOV FP-OV-6) |
| 4 | **Outline Pipeline** | Captions are 2D UI; do NOT participate in outline post-process (Pillar 5) |
| 5 | **Post-Process Stack** | Captions are NOT subject to sepia dim or any post-process effect; CanvasLayer 2 sits above PPS for caption rendering |
| 6 | **Player Character** | D&S does NOT couple to PC state machine; player position read once at `_ready()` for range gate, no per-frame coupling |
| 7 | **Failure & Respawn** | F&R does NOT trigger banter; respawn is silent at MVP (banter resumes on next SAI/MLS event after respawn) |
| 8 | **Inventory & Gadgets** | Gadget use does NOT trigger banter (no "she's reaching for something" banter — Pillar 1 forbids guards announcing player tactical state, VT-3) |

### F.6 Coordination Items Consolidated (BLOCKING + ADVISORY)

**BLOCKING coord items (must resolve before VS sprint planning):**

| # | Item | Owner | Source |
|---|---|---|---|
| 1 | ADR-0002 amendment: add `scripted_dialogue_trigger(scene_id: StringName)` MLS-domain signal | ADR-0002 | §C.15 row 12 |
| 2 | ADR-0008 amendment: register D&S **Slot 8 pooled** sub-claim 0.10 ms peak event-frame *(v0.3 — Slot 7 was wrong; corrected to Slot 8 per ADR-0008 §85 + §239)* | ADR-0008 | §C.15 row 15 |
| 3 | ADR-0004 Gate 1 verification: confirm `accessibility_live` property name + polite enum value on Label in 4.6 | ADR-0004 / godot-specialist | §C.12 / VG-DS-2 |
| 4 | ADR-0004 Gate 2 verification: confirm Theme inheritance property name (`base_theme` vs `fallback_theme`) | ADR-0004 / godot-specialist | inherited from sibling GDDs |
| 5 | Audio GDD §F amendment (v0.3 — depth deepened to −12 dB; v0.2 strengthening text retained): (a) Voice bus ducks **−12 dB** during `document_opened` (CR-DS-17 v0.3, `voice_overlay_duck_db = -12.0` knob); (b) **Audio GDD Dialogue domain table row** `dialogue_line_started(speaker, line) \| Load and play vo_[speaker]_[line].ogg` **MUST be replaced with** `dialogue_line_started(speaker, line) \| Apply VO duck per Formula 1 — Audio is subscriber-only and does NOT play VO files; D&S owns the AudioStreamPlayer per dialogue-subtitles.md §C.3`; (c) remove the conflicting `vo_[speaker]_[line].ogg` naming reference (canonical naming lives in dialogue-subtitles.md §A.1); (d) add Voice-bus duck-exception table listing CR-DS-17 v0.3 (`document_opened` → **−12 dB**) as the first registered exception to "Voice bus is never ducked." | Audio GDD | CR-DS-17 v0.3 + audio-director adversarial re-review (2026-04-28) |
| 6 | Settings GDD: register knobs (v0.3 expanded list): `subtitle_size_scale` (S=0.8 / M=1.0 / L=1.5 / XL=2.0), `subtitle_background` (none/scrim/opaque), `subtitle_speaker_labels` (default true, **MVP UI toggle** per D4), `subtitle_line_spacing_scale` ([1.0, 1.5]), `subtitle_letter_spacing_em` ([0.0, 0.12]) + boot-time burst + `setting_changed` emit-site contract | Settings GDD | §C.10 |
| 7 | MLS GDD: amend §C to declare authoring contract for `scripted_dialogue_trigger(scene_id)` signal + per-section scene_id roster | MLS GDD | §C.14 row 4 |
| 8 | LSS GDD: guarantee `_exit_tree` (and therefore `dialogue_line_finished()`) fires before scene swap on quick-load | LSS GDD | EC-DS-2 |
| 9 | LSS GDD: document Audio init before D&S init at section load (boot-order amendment) | LSS / Audio GDD | EC-DS-3 |
| 10 | Writer Brief authoring (`design/narrative/dialogue-writer-brief.md`): VS BLOCKING — 40-line per-section roster + 7 speaker categories + 8 voice/tone rules + word-count ceilings + BQA-never-expanded | Writer Brief / narrative-director | F.4 row 3 |

**ADVISORY coord items:**

| # | Item | Owner | Source |
|---|---|---|---|
| 1 | Authoring lint: warn when `audio_duration_s - duration_metadata_s > 5.0 s` on a DialogueLine | Writer Brief pipeline / Tools-Programmer | EC-DS-1 |
| 2 | Authoring lint: text-key content validator should reject keys containing `[` (BBCode misroute) | Writer Brief pipeline / Tools-Programmer | EC-DS-5 |
| 3 | Engine VG-DS-1: `auto_translate_mode = ALWAYS` + raw key auto-resolves on locale switch via 4.5+ live preview | godot-specialist | §C.12 |
| 4 | Engine VG-DS-3: `CanvasLayer.visible = false` suppresses AccessKit announcements from child Labels in 4.6 | godot-specialist | §C.12 |
| 5 | Engine VG-DS-4: `AudioStreamPlayer.finished` does NOT fire on `.stop()` in 4.6 | godot-specialist | §C.12; may upgrade to BLOCKING per EC-DS-4 |
| 6 | EC-DS-4 conditional: if VG-DS-4 confirms `.stop()` fires `.finished`, ADR-0008 sub-claim re-sign with interrupt-flag guard cost (~0.001 ms — negligible) | ADR-0008 | EC-DS-4 |

### F.7 Bidirectional Consistency Check

The 18-row bidirectional consistency check is consolidated in §C.15. Rows marked ❌ are the BLOCKING coord items in §F.6 above; rows marked ✅ are confirmed consistent with sibling-side text already in place.

## Tuning Knobs

### G.1 D&S-Owned Tuning Knobs

| Knob | Default | Safe Range | Type | Authority | What it affects |
|---|---|---|---|---|---|
| `dialogue_per_actor_cooldown_s` | 8.0 | [3.0, 30.0] | float (seconds) | game-designer | Per-actor bark cooldown (CR-DS-8). Below 3.0 = chatter-claustrophobic; above 30.0 = sparse-fail. NOLF1 empirical band. |
| `dialogue_bark_range_m` | 25.0 | [10.0, 50.0] | float (meters) | level-designer + game-designer | Player-to-actor distance for non-SCRIPTED bark eligibility (CR-DS-9). Tuned to Plaza interior corridor spans. |
| `dialogue_priority_queue_depth` | 1 | [0, 1] | int | game-designer | Depth of pre-emption queue (CR-DS-7). 0 = drop-only; 1 = current spec; values >1 risk stale-bark playback. **Pillar 1 absolute floor: do NOT exceed 1.** |
| `dialogue_curiosity_bait_protection` | true | {true, false} | bool | game-designer + creative-director | CR-DS-6 / SAI L91 carve-out. **Pillar 1 + 3 absolute** — disabling this kills the Radiator vignette and breaks the Eavesdrop fantasy. Knob exists for QA debug only; production lock = true. |
| `dialogue_caption_metadata_floor_s_default` | 0.0 | [0.0, 8.0] | float (seconds) | writer + audio-director | Default `duration_metadata_s` value when DialogueLine resource leaves it unset. 0.0 = caption follows audio. WCAG suggests ~1 s/word floor for slow readers. |

### G.2 Knobs Inherited from Settings & Accessibility (consumed) *(v0.3 — table updated to match §C.10)*

| Knob | Default | Phase | Owner | What it affects |
|---|---|---|---|---|
| `accessibility.subtitles_enabled` | `true` | MVP | Settings (CR-23) | Master caption visibility (CR-DS-11). Locked default per WCAG SC 1.2.2. |
| `accessibility.subtitle_size_scale` | `1.0` (S=0.8 / M=1.0 / **L=1.5 / XL=2.0**) | MVP | Settings | Theme font-size override on `SubtitleLabel`. WCAG SC 1.4.4 (XL preset = 200% scaling). |
| `accessibility.subtitle_background` | `scrim` (~0.55 alpha) | MVP | Settings | StyleBox behind caption. Options: `none` / `scrim` / `opaque`. WCAG SC 1.4.3 contrast precondition. |
| `accessibility.subtitle_speaker_labels` | `true` | **MVP** *(v0.3 — UI toggle promoted from VS)* | Settings | Whether `[SPEAKER]:` bracket prefix renders (CR-DS-16). Default ON at MVP per WCAG SC 1.2.2; UI toggle ships at MVP-Day-1 per D4 decision. |
| `accessibility.subtitle_line_spacing_scale` *(v0.3 — NEW row)* | `1.0` ([1.0, 1.5]) | MVP | Settings | Line-height multiplier on caption Label. WCAG SC 1.4.12. |
| `accessibility.subtitle_letter_spacing_em` *(v0.3 — NEW row)* | `0.0` ([0.0, 0.12]) | MVP | Settings | Letter-spacing override (em) on caption Label theme. WCAG SC 1.4.12. |

### G.3 Knobs Owned by Audio (consumed via signal contract)

| Knob | Default | Range | Owner | What D&S relies on |
|---|---|---|---|---|
| `voice_bus_db` | 0.0 | [-12.0, +6.0] dB | Audio | Voice bus mix level; affects perceived VO loudness during ducking |
| `music_diegetic_duck_calm_db` | -14.0 | [-24.0, -6.0] dB | Audio §F.1 | MusicDiegetic duck during VO (calm states) |
| `music_diegetic_duck_combat_db` | -18.0 | [-30.0, -10.0] dB | Audio §F.1 | MusicDiegetic duck during VO (combat states) |
| `music_nondiegetic_duck_db` | -4.0 | [-12.0, 0.0] dB | Audio §F.1 | MusicNonDiegetic duck during VO |
| `ambient_duck_db` | -6.0 | [-18.0, -3.0] dB | Audio §F.1 | Ambient bus duck during VO |
| `ducking_attack_s` | 0.3 | [0.1, 1.0] s | Audio §F.1 | Tween attack on ducking |
| `ducking_release_s` | 0.5 | [0.2, 2.0] s | Audio §F.1 | Tween release on ducking |
| `voice_overlay_duck_db` *(v0.3 — depth deepened)* | **-12.0** | [-18.0, 0.0] dB | Audio (BLOCKING coord CR-DS-17) | Voice bus duck during Document Overlay; v0.3 starting target deepened from -6 to -12 dB per audio-director adversarial review (broadcast intelligibility floor) |

### G.4 ADR-Locked Constants (cannot tune at runtime)

| Constant | Locked Value | ADR | Why locked |
|---|---|---|---|
| `subtitle_canvas_layer` | 2 | godot-specialist §C.3 | Above HUD Core (1), below Document Overlay (5); changing breaks z-order suppression model |
| `dialogue_slot_8_subclaim_ms` *(v0.3 — renamed from `_slot_7_`)* | 0.10 | ADR-0008 §85 + §239 (Slot 8 pooled) | Frame budget contract; runtime exceedance is a performance regression. v0.3 corrected from prior Slot 7 misattribution. |
| `dialogue_signal_emit_order` | started_BEFORE_play | CR-DS-2 step 3 vs 4 | Audio ducking attack head-start; reordering breaks F.1 ducking attack timing |
| `subtitle_canvas_visible_on_suppression` | false | CR-DS-4 + VG-DS-3 | AccessKit announcement suppression; alternative `modulate.a = 0` does NOT silence SR |
| `subtitle_label_class` | `Label` (NOT `RichTextLabel`) | FP-DS-15 | §B.3 refusals "Not karaoke" / "Not a drama"; BBCode parse overhead |
| `subtitle_auto_translate_mode` | `AUTO_TRANSLATE_MODE_ALWAYS` | CR-DS-5 | Locale-change auto-resolution; FP-DS-18 forbids manual `tr()` with this setting |

### G.5 Pillar 1 / Pillar 5 Absolutes (NEVER tunable — content of design)

| Absolute | Source | Rationale |
|---|---|---|
| Eve emits zero ambient barks (only SCRIPTED carve-out) | CR-DS-10, §B.3 #4 | Pillar 1: the world quips, Eve listens |
| No chyron / portraits / lower-third bars | FP-DS-6, §B.3 #5 | Pillar 5: 1960s teleprinter register, not modern AAA |
| No karaoke / per-word highlighting | FP-DS-5, §B.3 #2 | Pillar 5: transcript not performance |
| No animated subtitle entry/exit | FP-DS-7, §B.3 #1 | Pillar 5: "appear as if already typed" |
| No proximity-based opacity on captions | FP-DS-19, ux-designer | WCAG SC 1.4.3; rejected C3 framing |
| BQA acronym never spelled by enemy speakers | CR-DS-18 | Pillar 1 typographic comedy (port from DC) |
| Banter never tells the player what to do next | CR-DS-19 / VT-6 | Pillar 1: comedy is structural, not didactic |
| 12-word per-line ceiling; SPOTTED 4-word ceiling | CR-DS-20 / VT-7-8 | Pillar 1: laconic register; SPOTTED comedy = absence of wit |

### G.6 Tuning Ownership Matrix

| Knob category | Authority | Change Process |
|---|---|---|
| D&S-owned timing/range/queue (G.1) | game-designer | Direct edit `assets/data/dialogue_config.tres` |
| Settings-consumed (G.2) | Settings & Accessibility GDD owner | Settings GDD amendment + `setting_changed` re-emit |
| Audio-consumed (G.3) | Audio GDD owner / audio-director | Audio GDD amendment + ducking re-test |
| ADR-locked (G.4) | ADR amendment + technical-director sign-off | Cannot tune at runtime |
| Pillar absolutes (G.5) | creative-director sign-off + Pillar review | Cannot tune; constitute the design |

## Visual/Audio Requirements

### V.1 — Caption Typography Spec

**Typeface:** Courier (system fallback acceptable for prototype) or a web-licensed Courier Prime for final ship. Rationale: Courier is the canonical IBM Selectric / USAF intercept register — the exact monospace fixed-width face a 1960s radio operator would see on paper strip. This matches the Document Overlay UI precedent (American Typewriter Bold/Regular), extending the same typewriter register into caption space without duplicating the header-weight font. Letter Gothic is a narrower alternative if Courier reads too wide at the 2-line cap; recommend Courier as primary.

| Property | Value |
|---|---|
| Font family | Courier Prime (final) / Courier (prototype) |
| Weight | Regular (400) — no bold, no italic per §B.3 refusals #3 |
| Size at 1.0 scale | 28 px at 1080p reference |
| Letter-spacing | 0 (monospace default — do not kern) |
| Size at 0.8 scale | 22 px |
| Size at 1.25 scale | 35 px |

**Color:** Off-white `#F2EFE6` on `scrim`/`opaque` background; Ink Black `#1A1A1A` is reserved for the outline pipeline and `opaque` background fill. Off-white achieves WCAG ≥7:1 contrast against `#1A1A1A` at 0.55 alpha scrim (**best-case dark-field measurement: ~8.4:1**; v0.2 reviewer-flagged worst-case over a fully lit scene drops to ~1.6:1 — a WCAG failure by ~3×). On `none` background, WCAG SC 1.4.3 cannot be guaranteed — see V.2 below. **v0.2 mitigation:** per-section opaque QA gate (see new AC-DS-12.5 below) requires QA to verify scrim-mode contrast on every authored scene; sections that fail get `subtitle_background = opaque` per-section override OR a level-design intervention (dark surface element behind caption zone).

**Outline / drop shadow:** No drop shadow (Pillar 5 — FP-V-DS-1). No text outline. The `scrim` backplate provides the contrast layer; adding a text outline behind the backplate is redundant and introduces the "modern theater subtitle" glyph softness the teleprinter register rejects. On `none` mode (opt-out), no outline is added — contrast responsibility transfers to the scene designer.

### V.2 — Background Spec (3 modes)

| Mode | StyleBox | Fill | Alpha | Corner Radius | WCAG SC 1.4.3 |
|---|---|---|---|---|---|
| `none` | None | — | — | — | NOT GUARANTEED |
| `scrim` (MVP default) | StyleBoxFlat | `#1A1A1A` | 0.55 | **0 px — hard edges** | Conditional (see note) |
| `opaque` | StyleBoxFlat | `#1A1A1A` | 0.95 | 0 px — hard edges | Guaranteed |

**Hard edges rationale:** rounded corners (8 px) read as a modern notification card — the exact register §B.3 refusal #1 ("Not a notification") forbids. Hard-edged rectangular scrim matches 1960s teleprinter paper-strip cropping. No corner radius on either mode.

**`none` mode policy:** Available as a Settings opt-out only (`subtitle_background = none`). NOT the default. Help text in Settings must state: "Subtitles may be difficult to read against bright scenes." WCAG responsibility is user-acknowledged.

**`scrim` contrast note:** At 0.55 alpha on a scene with a fully white surface directly behind the caption region, the effective background lightens. If QA identifies a section where scrim-over-white fails 4.5:1, the level designer must add a dark surface element behind the caption zone, OR the `subtitle_background` default for that section may escalate to `opaque` via a per-section override (coordinate with Level Design).

**Padding:** 8 px horizontal, 6 px vertical inside the StyleBoxFlat. This sets the visual border of the backplate — tight enough to read as a transcript strip, not a full-width banner.

### V.3 — Speaker Label Visual Treatment (VS only)

Speaker labels render as inline monospace text, same font family and size as body caption text. Same off-white `#F2EFE6` color. No separate StyleBox, no separate node.

**Treatment:**
- Ongoing speakers (guards, clerks, civilians): `[GUARD-1]: caption body here`
- Eve's scripted radio lines: `[STERLING.] caption body here`

The bracket characters `[` and `]` are literal rendered glyphs — no markup, no `RichTextLabel`. The colon (`:`) or period (`.`) is the end-of-attribution delimiter; period = 1960s telex end-of-transmission convention per §C.8 locked spec. No tonal variation, no opacity reduction on the label portion — the teleprinter transcript renders the whole line as a single type run. Differentiating speaker label opacity (e.g., 80%) introduces a "secondary text" visual hierarchy that edges toward the "drama" register §B.3 refusal #3 forbids.

### V.4 — Caption Region Position + Anchoring

| Property | Value |
|---|---|
| Anchor preset | `PRESET_BOTTOM_CENTER` |
| Offset from screen bottom | 96 px at 1080p; scales as `96 × (viewport_height / 1080.0)` |
| Max width | 62% of viewport width, capped at 896 px |
| Line cap | 2 lines maximum (CR-DS-20) |
| CanvasLayer | 2 (above HUD Core at Layer 1; below Document Overlay at Layer 5) |

**Z-rule:** Caption MUST render above the contextual prompt strip (HUD Core, CanvasLayer 1) and MUST render below Document Overlay (CanvasLayer 5). CanvasLayer 2 satisfies both constraints per the locked ADR-0008 constant `subtitle_canvas_layer = 2` (G.4).

**HUD widget clearance:** The caption region at default scale (1.0) must not overlap the Health widget (bottom-left) or Weapon widget (bottom-right) at 1920×1080, 1280×720, or 2560×1440. The 62%/896 px width constraint and bottom-center anchor enforce this at 16:9 aspect ratios. At ultra-wide (21:9), the 896 px hard cap prevents caption from expanding into widget zones. **Verification gate VG-DS-5 (NEW):** confirm no overlap at 1.25× scale on 1280×720 before VS ship.

### V.5 — Forbidden Visual Patterns

| ID | Pattern | Rationale |
|---|---|---|
| **FP-V-DS-1** | No drop shadow, glow, or bloom on caption text | Pillar 5 — modern AAA cinematic frame; scrim provides contrast |
| **FP-V-DS-2** | No chyron bar, lower-third bar, or news-ticker strip | §B.3 refusal #5 — 1960s teleprinter register, not broadcast TV |
| **FP-V-DS-3** | No avatar, portrait, or headshot adjacent to caption | §B.3 refusal #5 — speaker attribution is inline bracket-tag only |
| **FP-V-DS-4** | No per-word color shift, italics-for-emphasis, or bold-for-emphasis | §B.3 refusals #2 and #3 — transcript, not performance |
| **FP-V-DS-5** | No motion graphics behind caption (animated wipes, parallax, looping VFX) | Pillar 5 — teleprinter paper strip does not animate |
| **FP-V-DS-6** | No proximity-based opacity or scale modulation | WCAG SC 1.4.3 — caption contrast must be constant regardless of player position |
| **FP-V-DS-7** | No emoji or Unicode pictographs in caption text | Pillar 5 — period authenticity; teleprinter character set is ASCII-range only |

### A.1 — Audio Integration Reference

All VO routes through the single **Voice** AudioBus. Timbral shaping per speaker category (guard gravel, civilian register, intercom lo-fi, BQA telephone) is implemented as an `AudioEffect` chain on the single `AudioStreamPlayer` node — NOT via sub-buses (one-bus-per-category would violate the ADR-0008 mixing budget and duplicate the Ambient bus architecture). Interrupt model: `AudioStreamPlayer.stop()` → assign new stream → `play()` — single player, no crossfade, no blend.

D&S emits exactly two signals: `dialogue_line_started(speaker, line_id)` and `dialogue_line_finished()`. Audio GDD §F.1 owns all ducking logic as subscriber; D&S does not call any Audio method directly.

**Voice bus ducking during Document Overlay:** Voice bus ducks **−12 dB** when `document_opened` fires, restores when `document_closed` fires. *(v0.3 (D2) — depth deepened from v0.2 −6 dB per audio-director re-review; broadcast intelligibility floor.)* Owned by Audio GDD §F.1 amendment (CR-DS-17 v0.3, BLOCKING coord item 5 in §F.6). D&S emits the overlay signals; Audio subscribes.

**VO file naming contract:** `assets/audio/vo/[speaker_category]/[line_id]_[locale].ogg`

Example: `assets/audio/vo/guard/vo.banter.guard.pension_en.ogg`

### A.2 — VO Asset Production Pipeline (Contract Summary)

D&S consumes finished `AudioStream` resources. Recording standards (sample rate: 48 kHz, bit depth: 24-bit WAV master, delivery format: OGG Vorbis at Q7) are the Audio Director's pipeline responsibility — not specified here. This GDD's contract:

- 30–50 total lines distributed per §C.6 section breakdown (F.5 density table)
- Locale: English MVP; additional locale tracks post-launch via locale-suffixed file per A.1 naming contract
- AI-generated VO is acceptable for prototype / internal playtesting (game-concept L233); a small commissioned VO cast (minimum 4 actors for 7 speaker categories) is required before final ship

### A.3 — Asset Spec Flag

> **📌 Asset Spec Flag** — After this GDD is approved and Art Bible §typography is finalized, run `/asset-spec system:dialogue-subtitles` to produce per-asset visual descriptions (caption StyleBox specs, font metrics, all 5 Settings-driven variants). VO assets covered by Audio Director's pipeline.

## UI Requirements

### UI-1 Boundaries — what D&S owns vs does NOT own

**D&S owns** (single rendered surface):

- One Control region: bottom-center caption strip (CanvasLayer 2, anchored `PRESET_BOTTOM_CENTER`)
- The Subtitle Label node + its StyleBox backplate (StyleBoxFlat, scrim/opaque/none modes per V.2)
- Three internal visibility states (HIDDEN / VISIBLE / SUPPRESSED) with the §C.2 transition table
- AccessKit live-region announcement of caption text

**D&S does NOT own** (boundary statement — these surfaces belong elsewhere):

| Surface | Owner |
|---|---|
| HUD widgets (health, ammo, gadget readout) | HUD Core |
| Banter chips, alert cues, save-failed banners | HUD State Signaling (HSS) |
| Document modal card (header / body / scroll) | Document Overlay UI |
| Pause / settings / main menu | Menu System |
| Cinematic letterboxing or cutscene captions | Cutscenes & Mission Cards (#22) |
| Mission card / dossier between sections | Cutscenes & Mission Cards (#22) |
| Locale switcher UI | Settings & Accessibility |

### UI-2 Accessibility Floor (Day-1 MVP vs VS vs Polish vs forward-dep)

| Item | Day-1 MVP | VS | Polish | Owner |
|---|---|---|---|---|
| Subtitles default ON (WCAG SC 1.2.2) | ✅ | ✅ | ✅ | Settings CR-23 |
| Caption WCAG SC 1.4.3 contrast (≥4.5:1) | ✅ via `scrim` default | ✅ | ✅ | D&S V.1+V.2 |
| Caption WCAG SC 1.4.4 size scale (S/M/L) | ✅ | ✅ | ✅ | Settings G.2 + D&S V.1 |
| Speaker labels for off-screen disambiguation | — (off) | ✅ default ON | ✅ | Settings G.2 + D&S CR-DS-16 |
| AccessKit live-region (polite) for screen reader | placeholder pending Gate 1 | ✅ verified | ✅ | D&S §C.12 + ADR-0004 Gate 1 |
| WCAG SC 2.3.3 (no animation entry/exit) | ✅ FP-DS-7 | ✅ | ✅ | D&S |
| `subtitle_background = none` opt-out | — | ✅ | ✅ | Settings G.2 |
| Per-section override for `subtitle_background = opaque` | — | ✅ if QA flags | ✅ | Level Design + D&S V.2 |
| Caption MUST NOT overlap HUD corner widgets | ✅ | ✅ | ✅ verified | D&S V.4 + VG-DS-5 |
| Mid-bark setting changes apply correctly | ✅ subtitles_enabled (H.1) + size_scale (H.2); ✅ speaker_labels next-line (H.3) | Same | Same | D&S §E |
| Locale switch mid-bark re-resolves | ✅ via `auto_translate_mode` (D.1) | ✅ verified VG-DS-1 | ✅ | D&S §C.12 |

### UI-3 UX Spec Flag for `/ux-design` Phase 4

> **📌 UX Flag — Dialogue & Subtitles**: This system has UI requirements (caption renderer + 3 settings-driven variants). In Phase 4 (Pre-Production), run `/ux-design dialogue-subtitles` to create a UX spec for the caption surface — covering all 5 Settings variants (S/M/L size × {none, scrim, opaque} background × {labels off, labels on}), the suppression-during-overlay UX, the WCAG audit checklist, and the accessibility flow for SR users. Stories that reference subtitle UI should cite `design/ux/dialogue-subtitles.md`, not this GDD directly.

Note this in the systems index for system #18 when updated.

### UI-4 Pillar 5 Absolutes (re-stated for UI scope)

These are restated from §G.5 because they apply specifically to the UI surface:

- **No chyron / portrait / lower-third bar** — speaker attribution is inline bracket-tag only (FP-DS-6, FP-V-DS-2, FP-V-DS-3)
- **No animated entry/exit** — instant appear/disappear, no tween, no fade-in, no type-on (FP-DS-7)
- **No per-word highlighting / karaoke** — caption renders whole as single Label.text assignment (FP-DS-5)
- **No drop shadow / glow / bloom** — scrim backplate provides contrast; modern AAA cinematic frame forbidden (FP-V-DS-1)
- **No emoji / Unicode pictographs** — teleprinter character set is ASCII-range only (FP-V-DS-7)
- **No motion graphics behind caption** — teleprinter paper strip does not animate (FP-V-DS-5)

## Acceptance Criteria

### H.1 Signal Contract

**AC-DS-1.1** GIVEN the full `src/` tree, WHEN CI runs `grep -r "emit_signal.*dialogue_line_started\|emit_signal.*dialogue_line_finished\|dialogue_line_started\.emit\|dialogue_line_finished\.emit" src/`, THEN the only matching file is the D&S implementation file (`dialogue_and_subtitles.gd`). (verifies CR-DS-1) — **BLOCKING**

**AC-DS-1.2** GIVEN D&S is initialized in a section, WHEN any dialogue lifecycle completes (all 7 steps of CR-DS-2), THEN exactly one `dialogue_line_started` and exactly one `dialogue_line_finished` are emitted per line; no `dialogue_line_finished` fires without a preceding `dialogue_line_started` in the same lifecycle. (verifies CR-DS-2) — **BLOCKING**

**AC-DS-1.3** GIVEN the D&S source file, WHEN CI runs `grep -n "connect.*dialogue_line_started\|connect.*dialogue_line_finished" dialogue_and_subtitles.gd`, THEN zero matches are returned. (verifies FP-DS-1) — **BLOCKING**

**AC-DS-1.4** GIVEN a DialogueLine with a valid audio stream, WHEN `select_line()` resolves and the lifecycle begins, THEN spy on `Events.dialogue_line_started` records the emit BEFORE spy on `_audio_player.play()` records the call (same `await process_frame()` cycle assertion); `dialogue_line_started` is emitted in step 3 and `_audio_player.play()` is called in step 4 of the same frame or the next frame — never before step 3 emits. (verifies CR-DS-2 step 3 vs 4) — **BLOCKING**

**AC-DS-1.5** *(v0.3 — NEW for FP-DS-21 v0.2)* GIVEN a DialogueLine resource where `audio_stream.get_length() < 0.1` s (mock AudioStream injected with `get_length() = 0.05`), WHEN `select_line(trigger_context)` is called with this resource matching the trigger filters, THEN `select_line()` returns `null`, emits `push_error("D&S: rejected line " + id + " — audio_duration_s < 0.1 s")`, and `dialogue_line_started` is NOT emitted. (verifies FP-DS-21 v0.2 zero-length reject) — **BLOCKING**

### H.2 Lifecycle / State Machine

**AC-DS-2.1** GIVEN D&S is in HIDDEN state with a valid DialogueLine queued, WHEN `select_line()` fires, THEN the sequence proceeds: stream assigned → `dialogue_line_started` emitted → `_audio_player.play()` called → `_label.text` set to raw key (if subtitles enabled) → `_caption_timer` started → state becomes VISIBLE. No step is skipped or reordered. (verifies CR-DS-2) — **BLOCKING**

**AC-DS-2.2** GIVEN the §C.2 state transition table, WHEN each trigger is replayed in a GUT test (HIDDEN + `dialogue_line_started`, VISIBLE + `document_opened`, SUPPRESSED + `document_closed` while in-flight, SUPPRESSED + `document_closed` with no line in flight), THEN the resulting state matches the §C.2 table for every row. (verifies CR-DS-3) — **BLOCKING**

**AC-DS-2.3** *(v0.3 — determinism note added)* GIVEN DialogueLine Example A (`audio_duration_s = 3.2`, `duration_metadata_s = 4.5`, `line_start_time = 100.0`), WHEN the caption timer is started, THEN `_caption_timer.wait_time = 4.5` s and `dialogue_line_finished` emits **270 frames after line start ± 6 frames at 60 fps** (frame-count assertion). GIVEN Example B (`audio_duration_s = 5.0`, `duration_metadata_s = 4.5`), THEN `dialogue_line_finished` emits **300 frames after line start ± 6 frames**. **Implementation note:** tests inject a mock clock seam (replace `Time.get_ticks_msec()` with a controllable test double) and step the scene tree via `await process_frame()` for deterministic assertion. Wall-clock tolerance `t = 104.5 s ± 0.1 s` / `t = 105.0 s ± 0.1 s` is a playtest-target only — wall-clock CI assertion violates the project determinism rule. (verifies F.1) — **BLOCKING**

**AC-DS-2.4** GIVEN a line in flight with both `_audio_player.finished` pending and `_caption_timer` pending, WHEN only one of the two fires, THEN `dialogue_line_finished` is NOT emitted and `_label.text` is NOT cleared. WHEN both have fired, THEN `dialogue_line_finished` emits and `_label.text` clears. (verifies CR-DS-2 step 7) — **BLOCKING**

**AC-DS-2.5a** *(v0.2 — split for granular PASS/FAIL)* GIVEN a line in flight, WHEN `_exit_tree` is called (simulating section unload), THEN `_audio_player.stop()` is called, `dialogue_line_finished` is emitted, `_label.text` is cleared, AND state is set to HIDDEN before the function returns. (verifies CR-DS-14 lifecycle cleanup) — **BLOCKING**

**AC-DS-2.5b** *(v0.2 — split)* GIVEN a line in flight with all `Events.*` subscriptions connected, WHEN `_exit_tree` is called, THEN every `Events.*.connect()` made by D&S during `_ready()` is disconnected with `is_connected()` guards before the function returns. Asserted via `is_connected()` returning `false` for each documented subscription (`document_opened`, `document_closed`, `ui_context_changed`, `actor_became_alerted`, `alert_state_changed`, `guard_incapacitated`, `guard_woke_up`, `civilian_panicked`, `weapon_fired_in_public`, `scripted_dialogue_trigger`, `setting_changed`). For locale-change subscription: assert disconnection target is whichever object D&S subscribed to (`TranslationServer.locale_changed` if the signal exists in 4.6 per CR-DS-22 / VG; OR via `_notification(NOTIFICATION_TRANSLATION_CHANGED)` override if not — assertion target depends on VG-DS-2's locale-signal verification result). (verifies CR-DS-14 signal disconnection) — **BLOCKING**

**AC-DS-2.6** *(v0.3 — NEW for CR-DS-21 v0.2 watchdog)* GIVEN a bark in flight with mock `_audio_player.finished` signal suppressed (simulates stuck audio), AND `audio_duration_s = 1.0`, `duration_metadata_s = 0.0`, watchdog `wait_time = max(1.0, 0.0, 5.0) + 1.0 = 6.0` s, WHEN 6 s elapse via mock-clock advancement, THEN the watchdog handler executes IN ORDER: (1) `_audio_player.stop()` is called; (2) `dialogue_line_finished` is force-emitted with `push_error` containing the line_id; (3) `_label.text` is cleared; (4) state transitions to HIDDEN. (verifies CR-DS-21 v0.3 watchdog floor + stop-before-emit ordering) — **BLOCKING**

### H.3 Suppression / Overlay

**AC-DS-3.1** GIVEN a CURIOSITY_BAIT bark in flight with caption visible, WHEN `Events.document_opened` fires, THEN `SubtitleCanvasLayer.visible = false` and `_suppressed = true` are set, audio continues playing, and `dialogue_line_finished` fires at natural completion. (verifies CR-DS-4, §E Cluster C.1) — **BLOCKING**

**AC-DS-3.2** GIVEN the state from AC-DS-3.1 (SUPPRESSED, line still in flight), WHEN `Events.document_closed` fires before the line ends, THEN `SubtitleCanvasLayer.visible = true`, `_suppressed = false`, and the caption re-renders for the remaining duration. Caption text is the same key as before suppression. (verifies §C.2 SUPPRESSED → VISIBLE) — **BLOCKING**

**AC-DS-3.3** GIVEN D&S in VISIBLE state, WHEN `Events.ui_context_changed(MENU, GAMEPLAY)` fires, THEN `_suppressed = true` and `SubtitleCanvasLayer.visible = false`. Audio continues and `dialogue_line_finished` fires at natural completion. When context returns to GAMEPLAY with no line in flight, state is HIDDEN. (verifies CR-DS-4) — **BLOCKING**

**AC-DS-3.4** *(v0.3 — grep tightened for false-positive resilience)* GIVEN the full `src/` tree, WHEN CI runs `grep -rn --exclude-dir=tests "\bDialogueAndSubtitles\b\|\bSubtitleCanvasLayer\b\|\b_caption_suppressed\b" src/` excluding `src/.../dialogue_and_subtitles.gd` and its test file, THEN zero matches are returned. *(v0.3: previous v0.2 grep used `_suppressed` which over-matches HSS / DOV / Menu generic suppression flags. Internal D&S flag renamed `_caption_suppressed` for unambiguous grep.)* (verifies FP-OV-6 reverse — Document Overlay calls nothing on D&S) — **BLOCKING**

### H.4 Priority Resolver / Queue

**AC-DS-4.1** GIVEN a CURIOSITY_BAIT (bucket 4) bark in flight, WHEN a SCRIPTED (bucket 1) trigger fires, THEN `dialogue_line_finished` emits for the interrupted line, `_audio_player.stop()` is called, caption clears, and the SCRIPTED line begins within the same frame. (verifies CR-DS-7 "higher priority interrupts lower") — **BLOCKING**

**AC-DS-4.2** GIVEN a CURIOSITY_BAIT (bucket 4) bark in flight, WHEN `alert_state_changed` (bucket 3 ESCALATION trigger) fires on the same actor, THEN the in-flight bark is NOT interrupted; it continues to `_audio_player.finished`. (verifies CR-DS-6 CURIOSITY_BAIT protection) — **BLOCKING**

**AC-DS-4.3** GIVEN a line in flight and an empty depth-1 queue, WHEN a second trigger of equal or lower priority arrives in the same frame, THEN the queue holds exactly one entry and no playback begins until the in-flight line finishes. (verifies CR-DS-7 depth-1 queue) — **BLOCKING**

**AC-DS-4.4** GIVEN a line in flight and a queue already holding one entry, WHEN a third trigger arrives, THEN the third trigger is dropped silently (no push_error, no queue resize). Queue depth remains 1. (verifies CR-DS-7 "drop the newer trigger") — **BLOCKING**

**AC-DS-4.5** GIVEN a queued line whose actor has been freed before the in-flight line ends, WHEN the in-flight line completes and the queue is evaluated, THEN `is_instance_valid(actor)` returns false, the queued line is dropped silently, and no bark begins. (verifies CR-DS-7 stale-check on fire-time re-evaluation) — **BLOCKING**

### H.5 Rate-Gate + Range Gate

**AC-DS-5.1** *(v0.3 — determinism note added)* GIVEN actor GuardA's `_actor_last_bark_time[GuardA] = 135.0` s injected via mock-clock seam, AND `dialogue_per_actor_cooldown_s = 8.0`, WHEN `select_line()` is called with mock-clock `now_s = 142.3` (7.3 s elapsed), THEN `is_eligible(GuardA) = false` and no line is returned. WHEN mock-clock advanced to `now_s = 143.1` (8.1 s elapsed), THEN `is_eligible(GuardA) = true`. **Implementation note:** test injects a mock clock seam; assertion target is the boolean predicate result, not a wall-clock measurement. Wall-clock CI assertion violates determinism rule. (verifies F.2 / CR-DS-8) — **BLOCKING**

**AC-DS-5.2** GIVEN actor GuardA is within cooldown (ineligible per F.2), WHEN a SCRIPTED trigger fires for GuardA, THEN the SCRIPTED line plays; rate-gate predicate is NOT evaluated for SCRIPTED triggers. (verifies CR-DS-8 + F.2 SCRIPTED bypass) — **BLOCKING**

**AC-DS-5.3** GIVEN actor at `(12.0, 0.0, 5.0)` and player at `(0.0, 0.0, 0.0)` with `dialogue_bark_range_m = 25.0`, WHEN `select_line()` evaluates `in_range`, THEN `in_range = true` (distance = 13.0 m). GIVEN actor at `(30.0, 0.0, 0.0)`, THEN `in_range = false` (distance = 30.0 m > 25.0). (verifies F.3 / CR-DS-9) — **BLOCKING**

**AC-DS-5.4** GIVEN the player ref is null at `select_line()` evaluation, WHEN a non-SCRIPTED trigger fires, THEN range gate returns `true` (fails OPEN) and the line may play. GIVEN a SCRIPTED trigger fires with any actor position, THEN the line plays regardless of distance. (verifies CR-DS-9 null-guard + SCRIPTED bypass) — **BLOCKING**

### H.6 Settings Integration

**AC-DS-6.1** GIVEN `Settings.subtitles_enabled = false`, WHEN a bark lifecycle runs to completion, THEN `dialogue_line_started` fires, `_audio_player.play()` is called, audio completes, `dialogue_line_finished` fires, AND `_label.text` is never assigned (remains `""`). (verifies CR-DS-11) — **BLOCKING**

**AC-DS-6.2** GIVEN a caption is actively visible, WHEN `setting_changed("subtitle_size_scale", 1.25)` fires, THEN `SubtitleLabel`'s font-size override updates immediately without lifecycle restart and caption remains readable. (verifies §E Cluster H.2) — **ADVISORY**

**AC-DS-6.3** GIVEN `subtitle_background` cycles through `none`, `scrim`, `opaque`, WHEN each value is applied, THEN the StyleBox behind the caption renders: (none) no backplate; (scrim) `#1A1A1A` at alpha ≈ 0.55; (opaque) `#1A1A1A` at alpha ≈ 0.95. All modes use `corner_radius = 0`. (verifies V.2) — **ADVISORY**

**AC-DS-6.4** GIVEN `subtitle_speaker_labels` is toggled mid-bark, WHEN the in-flight caption is examined, THEN it is NOT retroactively re-rendered. WHEN the next bark begins, THEN the new label state applies. (verifies §E Cluster H.3 / CR-DS-16 next-line rule) — **ADVISORY**

### H.7 Localization / tr()

**AC-DS-7.1** GIVEN a DialogueLine with `text_key = &"vo.banter.guard_radiator_a"`, WHEN step 5 of CR-DS-2 executes, THEN `_label.text` is assigned the raw string `"vo.banter.guard_radiator_a"` — not the translated string and not `tr("vo.banter.guard_radiator_a")`. `auto_translate_mode = ALWAYS` performs the resolution. (verifies CR-DS-5) — **BLOCKING**

**AC-DS-7.2** GIVEN a caption is visible with `_label.text = raw_key`, WHEN `NOTIFICATION_TRANSLATION_CHANGED` fires (locale switch), THEN the rendered caption text updates to the new locale's string for the same key without any manual code intervention. (verifies CR-DS-5 + §E Cluster D.1, pending VG-DS-1) — **BLOCKING** (BLOCKED-on VG-DS-1 editor verification)

**AC-DS-7.3** GIVEN a DialogueLine whose `text_key` has no entry in the active locale's CSV, WHEN the caption renders, THEN the Label displays Godot's missing-key fallback string (e.g., `"MISSING:vo.banter.foo"`) visibly — the label is NOT hidden. A `push_warning` with `line_id` is emitted. (verifies §E Cluster D.3) — **ADVISORY**

**AC-DS-7.4** *(v0.3 — reframed; tautological grep replaced with schema check)* GIVEN the SaveGame schema definition file (`src/save/save_game_schema.gd` or equivalent), WHEN CI runs `grep -n "DialogueLine\|dialogue\|subtitle\|text_key" src/save/`, THEN zero matches are returned (D&S holds zero SaveGame state per CR-DS-13). Additionally: `grep -r "translated\|tr(" src/save/` returns zero — no resolved translated string is ever serialized; only raw `StringName` keys would be permitted by FP-DS-12 if D&S ever needed save state. (verifies FP-DS-12 / CR-DS-13 — strengthened from v0.2 tautological grep that would pass even if D&S was absent from save/.) — **BLOCKING**

**AC-DS-7.5** *(v0.3 — NEW for CR-DS-22 v0.2 mid-bark locale defer)* GIVEN a bark in flight with `_pending_locale = &""`, AND a spy on `TranslationServer.set_locale()`, WHEN `TranslationServer.locale_changed` (or equivalent settings signal — VG-required) fires with new locale `&"fr"`, THEN within the in-flight window, `TranslationServer.set_locale()` is NOT called (spy records zero invocations) and `_pending_locale = &"fr"` is recorded. WHEN the in-flight line completes (`dialogue_line_finished` emits), THEN `TranslationServer.set_locale(&"fr")` is called exactly once and `_pending_locale` is cleared to `&""`. GIVEN no line in flight at locale-change time, THEN `TranslationServer.set_locale()` is called immediately (within 1 frame). (verifies CR-DS-22 v0.2 deferral) — **BLOCKING** (BLOCKED-on VG-DS-2-locale verification: confirm `TranslationServer.locale_changed` signal exists in Godot 4.6, OR rewrite via `NOTIFICATION_TRANSLATION_CHANGED` interception)

**AC-DS-7.6** *(v0.3 — NEW for CR-DS-23 v0.2 production missing-key gate)* GIVEN a production-build export configuration (export feature flag `production` set, NOT `editor` and NOT `dev`), AND a `text_key` referencing a key absent from the active locale's CSV, WHEN the build pipeline runs the `/localize` audit prior to export, THEN the audit returns RED (non-zero exit code) with a list of missing keys, AND the build pipeline fails the export step. GIVEN a dev/QA-build configuration (`editor` or `dev` feature flag set) with the same missing key, THEN at runtime the Label renders Godot's `MISSING:vo.banter.foo` fallback string visibly AND a `push_warning` with line_id is logged (v0.2 D.3 behavior preserved). (verifies CR-DS-23 v0.2 production-vs-dev policy) — **ADVISORY** (release-gate, not unit-test)

### H.8 Eve-Silence + Voice/Tone

**AC-DS-8.1** GIVEN a DialogueLine with `speaker_id = "EVE"` and `banter_category = PATROL_AMBIENT`, WHEN `select_line()` evaluates this resource, THEN the line is rejected (`push_warning` emitted with line_id), no lifecycle begins, and `dialogue_line_started` is NOT emitted. (verifies CR-DS-10) — **BLOCKING**

**AC-DS-8.2** GIVEN the full `assets/` tree of DialogueLine `.tres` resources, WHEN CI runs `grep -r "B\.Q\.A\.\|Bureau.*Quorum\|Quorum.*Affairs" assets/` filtering only resources with non-EVE, non-BQA_HANDLER speaker IDs, THEN zero matches are returned. (verifies CR-DS-18) — **BLOCKING**

**AC-DS-8.3** GIVEN all authored DialogueLine resources with `priority_bucket != SCRIPTED`, WHEN CI counts words in each resolved `text_key` value, THEN no line exceeds 12 words. (verifies CR-DS-20 / VT-8) — **ADVISORY** (enforced at Writer Brief; CI lint advisory gate)

**AC-DS-8.4** GIVEN all DialogueLine resources with `priority_bucket = COMBAT_DISCOVERY` and `banter_category` matching SPOTTED, WHEN CI counts words, THEN no line exceeds 4 words. (verifies CR-DS-20 / VT-7) — **ADVISORY** (enforced at Writer Brief; CI lint advisory gate)

**AC-DS-8.5** GIVEN all authored banter DialogueLine resources, WHEN a content reviewer reads each `text_key` resolution, THEN no line contains navigation direction, objective instruction, mechanic-naming (e.g., "go upstairs", "find the exit", "use the gadget"), or SAI state names spoken aloud. Verdict recorded in `production/qa/evidence/`. (verifies CR-DS-19 / VT-6) — **ADVISORY** (requires human playtest review; not automatable)

### H.9 Performance Budget

**AC-DS-9.1** *(v0.3 — severity corrected to ADVISORY; Slot 8 corrected)* GIVEN the D&S source file `dialogue_and_subtitles.gd`, WHEN CI runs `grep -L "_process\|_physics_process" dialogue_and_subtitles.gd` (returns the file = no per-frame callback), AND a profiler spot-check is performed on minimum-spec hardware on a non-debug export, THEN the D&S event-frame cost is ≤ 0.10 ms peak (within ADR-0008 **Slot 8 pooled 0.8 ms cap** alongside CAI / MLS / DC / F&R / Signal-Bus dispatch). Lead sign-off, not CI gate. (verifies F.4 / ADR-0008 §85 + §239 Slot 8 sub-claim) — **ADVISORY** *(was BLOCKING in v0.2; downgraded because v0.2's reframe to grep + manual lead sign-off matches the ADVISORY definition per coding-standards.md)* (BLOCKED-on ADR-0008 amendment registration — Phase 2 propagation)

**AC-DS-9.2** GIVEN no bark in flight and no trigger pending, WHEN the profiler samples for 60 consecutive frames, THEN D&S contributes 0.0 ms (no `_process` callback; zero steady-state cost). (verifies F.4 steady-state claim) — **BLOCKING**

**AC-DS-9.3** GIVEN a priority-eviction scenario (in-flight line interrupted by SCRIPTED, queued line evicted, new line started in same frame), WHEN profiled on minimum-spec hardware, THEN the burst frame cost does not exceed 0.15 ms (acceptable brief exceedance per F.4 rationale). (verifies F.4 worst-case bound) — **ADVISORY**

### H.10 Audio Integration

**AC-DS-10.1** GIVEN the D&S scene tree (`DialogueAndSubtitles.tscn`), WHEN the `AudioLinePlayer` bus property is inspected, THEN `bus = "Voice"`. CI grep: `grep -r "bus.*=.*SFX\|bus.*=.*Music\|bus.*=.*Master" dialogue_and_subtitles.tscn` returns zero matches. (verifies FP-DS-13) — **BLOCKING**

**AC-DS-10.2** GIVEN a spy on `Events.dialogue_line_started` and a spy on `_audio_player.play()`, WHEN a bark lifecycle begins, THEN the `dialogue_line_started` spy records a call before the `play()` spy records a call (within the same frame or `dialogue_line_started` in frame N, `play()` in frame N+1 at most). (verifies CR-DS-2 step 3 vs 4 / CR-DS-11) — **BLOCKING**

**AC-DS-10.3** *(v0.3 — depth corrected to −12 dB per D2)* GIVEN a bark in flight, WHEN `Events.document_opened` fires, THEN the Voice bus volume decreases by **−12 dB** (within 0.3 s attack window) and audio continues playing. WHEN `Events.document_closed` fires, THEN the Voice bus restores to baseline within 0.5 s release window. (verifies CR-DS-17 v0.3) — **ADVISORY** (BLOCKED-on Audio GDD §F amendment for `voice_overlay_duck_db = -12.0` knob — Phase 2 propagation)

### H.11 Forbidden Pattern Grep Gates

**AC-DS-11.1** *(v0.3 — test-dir excluded)* GIVEN `src/`, WHEN CI runs `grep -rn --exclude-dir=tests "RichTextLabel" src/ | grep -i "subtitle\|caption\|dialogue"`, THEN zero matches are returned. (verifies FP-DS-15) — **BLOCKING**

**AC-DS-11.2** GIVEN `dialogue_and_subtitles.gd`, WHEN CI runs `grep -n "= tr(" dialogue_and_subtitles.gd`, THEN zero matches are returned (raw key assigned, not `tr()` result). (verifies FP-DS-18 / CR-DS-5) — **BLOCKING**

**AC-DS-11.3** GIVEN `dialogue_and_subtitles.gd`, WHEN CI runs `grep -n "\.connect(" dialogue_and_subtitles.gd` and cross-references with `grep -n "_process\|_physics_process"`, THEN no `.connect()` call appears inside a `_process` or `_physics_process` body. (verifies FP-DS-17) — **BLOCKING**

**AC-DS-11.4** GIVEN `dialogue_and_subtitles.gd`, WHEN CI runs `grep -n "await get_tree().create_timer"`, THEN zero matches are returned. All timing uses child `Timer` nodes. (verifies FP-DS-16) — **BLOCKING**

**AC-DS-11.5** *(v0.3 — test-dir excluded)* GIVEN `src/`, WHEN CI runs `grep -rn --exclude-dir=tests "modulate.a\|\.scale" src/ | grep -i "subtitle\|caption"`, THEN zero matches are returned (no proximity-based opacity or scale on caption region). (verifies FP-DS-19 / FP-V-DS-6) — **BLOCKING**

### H.12 Visual / Layout

**AC-DS-12.1** *(v0.3 — upgraded to BLOCKING; XL coverage added)* GIVEN the game running at 1280×720 AND 1920×1080 at each of `subtitle_size_scale = 1.0 / 1.5 / 2.0` (M / L / XL), WHEN a two-line caption renders, THEN the caption region does not overlap the Health widget (bottom-left) or Weapon widget (bottom-right) at any combination. Screenshots filed in `production/qa/evidence/vg-ds-5-[res]-[scale].png`. (verifies VG-DS-5 / V.4 / FP-DS-20) — **BLOCKING** (lead sign-off; BLOCKED-on HUD Core widget positions confirmed)

**AC-DS-12.2** *(v0.3 — upgraded to BLOCKING)* GIVEN the StyleBox applied to the caption, WHEN its properties are inspected in-editor, THEN `corner_radius_top_left`, `corner_radius_top_right`, `corner_radius_bottom_left`, `corner_radius_bottom_right` are all `0` for both `scrim` and `opaque` modes. (verifies V.2) — **BLOCKING**

**AC-DS-12.3** *(v0.3 — upgraded to BLOCKING)* GIVEN the caption rendering on screen, WHEN a visual reviewer inspects it across three different scene backgrounds, THEN there is no drop shadow, glow, bloom, or text outline on caption text in any mode. Screenshot filed in `production/qa/evidence/`. (verifies FP-V-DS-1) — **BLOCKING** (lead sign-off required)

**AC-DS-12.4** *(v0.3 — upgraded to BLOCKING)* GIVEN `subtitle_speaker_labels = true` and an active non-anonymous speaker, WHEN the caption renders, THEN the text begins with `[SPEAKER_LABEL]:` (colon) for all non-EVE speakers, and `[STERLING.]` (period) for `speaker_id = "EVE"` in SCRIPTED_SCENE lines. No portrait, no separate node, no extra StyleBox wraps the label text. (verifies V.3 / CR-DS-16 / FP-DS-6) — **BLOCKING**

**AC-DS-12.5** *(v0.3 — NEW; resolves V.1 dangling reference)* GIVEN every section's authored scenes, WHEN QA inspects the caption-region visual contrast against the section's worst-case lit background using a contrast measurement tool (Stark, Contrast Ratio Checker, or equivalent), THEN the rendered caption-on-scrim contrast meets WCAG SC 1.4.3 ≥ 4.5:1. Sections that fail at default `subtitle_background = scrim` either (a) escalate to `subtitle_background = opaque` per-section override OR (b) receive a level-design intervention (dark surface element behind caption zone). QA verdict recorded per section in `production/qa/evidence/contrast-[section]-[date].md`. (verifies V.1 worst-case mitigation / WCAG SC 1.4.3) — **BLOCKING** (lead sign-off; per-section gate)

**AC-DS-12.6** *(v0.3 — NEW; XL truncation gate)* GIVEN `subtitle_size_scale = 2.0` (XL preset) and the longest authored English `text_key` value (currently no line exceeds 12 words per CR-DS-20), WHEN the caption renders at 1920×1080 / 1280×720 / 2560×1440, THEN the resolved caption fits within the 2-line × 896 px display cap WITHOUT truncation (no `…` appended) AND no characters are clipped. If truncation occurs, either (a) the offending line is rewritten under a tighter character cap (Writer Brief deliverable), OR (b) the 2-line cap is raised to 3 for XL preset only. (verifies WCAG SC 1.4.4 fit at 200% scaling) — **BLOCKING**

### H.13 Plaza MVP Smoke

**AC-DS-13.1** GIVEN the Plaza tutorial section loaded, WHEN a CURIOSITY_BAIT trigger fires for MVP-1 ("Could've sworn I heard something.") and SAI de-escalates mid-bark back to UNAWARE, THEN the bark plays to `_audio_player.finished` without interruption, caption remains visible for the full F.1 duration, and `dialogue_line_finished` fires only after both audio and timer complete. (verifies CR-DS-6 / §B.5 V.2 Radiator vignette) — **BLOCKING**

**AC-DS-13.2** *(v0.3 — stale category corrected)* GIVEN the Plaza tutorial section, WHEN MVP-2 **SCRIPTED_SCENE 7b** exchange triggers (two lines: GuardA "You take the brochure stand." / GuardB "Someone has to."), THEN both lines play sequentially, each with its own `dialogue_line_started`/`finished` pair, each caption renders and clears per F.1, and `priority_bucket = SCRIPTED` is recorded for both. (verifies CR-DS-7 sequential dispatch / §C.7 MVP-2 v0.2 re-categorization) — **BLOCKING**

**AC-DS-13.3** GIVEN the Plaza tutorial BQA briefing (MVP-3 SCRIPTED_SCENE 7c), WHEN the Handler line fires then Eve's `[STERLING.]` line fires, THEN Eve's caption renders with `[STERLING.]` (period, not colon), `speaker_id = "EVE"` is accepted because `banter_category = SCRIPTED_SCENE`, and `dialogue_line_started(speaker="EVE", line_id=...)` emits correctly. (verifies CR-DS-10 SCRIPTED carve-out / §C.8 speaker format) — **BLOCKING**

### H.14 GAP Cluster — Untestable Rules

The following rules from §B–§G cannot be framed as a deterministic Given-When-Then test. They are flagged here for explicit disposition so no AC is authored that gives a false sense of coverage.

**GAP-DS-1 — "The world quips, Eve listens" (G.5 Pillar 1 absolute).** There is no automatable assertion for whether the overall comedic register of the game satisfies Pillar 1. This must be a playtest verdict: "Does the player feel like an eavesdropper, not an audience?" Recommended evidence: playtest session notes in `production/qa/evidence/` signed off by creative-director. Not a CI gate.

**GAP-DS-2 — "1960s teleprinter register" tonal quality (B.1, V.1).** Caption typography matching the Courier Prime / IBM Selectric vernacular is a visual design judgment, not a pixel-exact assertion. Required evidence: Art Bible §typography sign-off from ux-designer + screenshot review. Not a CI gate.

**GAP-DS-3 — "Comedy lands" for any individual banter line (B.5 anchor vignettes).** Whether V.1 (Margaux Bit), V.2 (Radiator), and V.3 (Guard Room Cable) "feel right" is a playtest quality verdict. Recommended evidence: minimum 3 external playtester reactions per vignette, documented in `production/qa/evidence/playtest-banter-[date].md`.

**GAP-DS-4 — "Banter is atmosphere, not announcement" (VT-6 / CR-DS-19).** AC-DS-8.5 above covers keyword-detectable navigation hints, but the line between atmosphere and implicit guidance is a judgment call that requires a human reviewer reading every authored banter line in context. The keyword grep is a necessary but not sufficient gate.

**GAP-DS-5 — Banter density advisory in practice (F.5).** F.5 is verified at authoring time against section-line-count targets, but actual fired-bark density (after rate-gate + range-gate suppression) can only be measured during a full playthrough on each section. Recommended: one timed playtest per section, recording bark count. This is not a CI gate.

### Summary

**57 ACs across 14 clusters** — **44 BLOCKING + 13 ADVISORY** (v0.3 added 6 ACs: AC-DS-1.5 / 2.6 / 7.5 / 7.6 / 12.5 / 12.6 — see Revision Notes table; v0.3 also corrected AC-DS-9.1 BLOCKING→ADVISORY and upgraded AC-DS-12.1–12.4 ADVISORY→BLOCKING). Net: 51→57 ACs; 40→44 BLOCKING. + 5 GAP entries.

| Cluster | ACs | BLOCKING | ADVISORY |
|---|---|---|---|
| H.1 Signal Contract | 4 | 4 | 0 |
| H.2 Lifecycle / State Machine | 5 | 5 | 0 |
| H.3 Suppression / Overlay | 4 | 4 | 0 |
| H.4 Priority Resolver / Queue | 5 | 5 | 0 |
| H.5 Rate-Gate + Range Gate | 4 | 4 | 0 |
| H.6 Settings Integration | 4 | 1 | 3 |
| H.7 Localization / tr() | 4 | 3 | 1 |
| H.8 Eve-Silence + Voice/Tone | 5 | 2 | 3 |
| H.9 Performance Budget | 3 | 2 | 1 |
| H.10 Audio Integration | 3 | 2 | 1 |
| H.11 Forbidden Pattern Greps | 5 | 5 | 0 |
| H.12 Visual / Layout | 4 | 0 | 4 |
| H.13 Plaza MVP Smoke | 3 | 3 | 0 |
| H.14 GAP Cluster | 5 gaps | — | — |
| **Total** | **51 ACs + 5 gaps** | **40** | **13** |

**Forward dependencies requiring BLOCKED-on resolution before their AC can be verified:**

- AC-DS-7.2 — VG-DS-1 editor check
- AC-DS-9.1 — ADR-0008 Slot 7 sub-claim amendment
- AC-DS-10.3 — Audio GDD §F amendment (`voice_overlay_duck_db`)
- AC-DS-12.1 — HUD Core widget positions confirmed (for VG-DS-5 overlap check)

## Open Questions

### Q.1 BLOCKING for MVP / VS sprint planning (10 items)

| # | OQ | Owner | Source | Resolution Path |
|---|---|---|---|---|
| **OQ-DS-1** | ADR-0002 amendment: add `scripted_dialogue_trigger(scene_id: StringName)` MLS-domain signal | ADR-0002 / technical-director | §C.15 row 12, §F.6 #1 | `/architecture-decision` amendment + producer-tracked gate |
| **OQ-DS-2** | ADR-0008 amendment: register D&S **Slot 8 pooled** sub-claim 0.10 ms peak event-frame *(v0.3 — Slot 7 was wrong; corrected to Slot 8 per ADR-0008 §85 + §239)* (or 0.15 ms with EC-DS-4 conditional re-sign) | ADR-0008 / technical-director | §C.15 row 15, §F.6 #2 | `/architecture-decision` amendment |
| **OQ-DS-3** | ADR-0004 Gate 1: confirm exact `accessibility_live` property name + polite enum value on Label in Godot 4.6 (pending VG-DS-2) | ADR-0004 / godot-specialist | §C.12, §F.6 #3 | 5-min in-editor inspection; then update CR-DS-12 |
| **OQ-DS-4** | ADR-0004 Gate 2: confirm Theme inheritance prop name (`base_theme` vs `fallback_theme`) | ADR-0004 / godot-specialist | inherited from sibling GDDs, §F.6 #4 | 5-min in-editor inspection |
| **OQ-DS-5** | Audio GDD §F amendment (v0.3): Voice bus ducks **−12 dB** during `document_opened` (CR-DS-17 v0.3, `voice_overlay_duck_db = -12.0` knob) + L214 row replacement + L67/L217/L394 prose corrections | Audio GDD / audio-director | CR-DS-17 v0.3, §F.6 #5 | Audio GDD revision pass |
| **OQ-DS-6** | Settings GDD: register knobs (v0.3 expanded list): `subtitles_enabled`, `subtitle_size_scale` (S/M/L/XL=2.0), `subtitle_background`, `subtitle_speaker_labels` (**MVP UI toggle** per D4), `subtitle_line_spacing_scale`, `subtitle_letter_spacing_em` + boot-time burst + `setting_changed` emit-site contract | Settings GDD / accessibility-specialist | §C.10, §F.6 #6 | Settings GDD revision pass |
| **OQ-DS-7** | MLS GDD: amend §C to declare authoring contract for `scripted_dialogue_trigger(scene_id)` signal + per-section scene_id roster | MLS GDD | §C.14 row 4, §F.6 #7 | MLS GDD revision pass |
| **OQ-DS-8** | LSS GDD: guarantee `_exit_tree` (and `dialogue_line_finished()`) fires before scene swap on quick-load (EC-DS-2) | LSS GDD | §E F.4, §F.6 #8 | LSS GDD revision pass |
| **OQ-DS-9** | LSS GDD: document Audio init before D&S init at section load (boot-order amendment) (EC-DS-3) | LSS / Audio GDD | §E G.1, §F.6 #9 | LSS GDD revision pass |
| **OQ-DS-10** | Writer Brief authoring (`design/narrative/dialogue-writer-brief.md`): VS BLOCKING — 40-line per-section roster + 7 speaker categories + 8 voice/tone rules + word-count ceilings + BQA-never-expanded | Writer Brief / narrative-director | §F.4 row 3, §F.6 #10 | New brief authoring sprint |

### Q.2 ADVISORY (engine VGs + lints + conditional)

| # | OQ | Source | Type |
|---|---|---|---|
| **OQ-DS-11** | VG-DS-1: confirm `auto_translate_mode = ALWAYS` + raw key auto-resolves on locale switch via 4.5+ live preview (engine knowledge gap) | §C.12, §F.6 advisory 3 | 5-min in-editor verification |
| **OQ-DS-12** | VG-DS-3: confirm `CanvasLayer.visible = false` suppresses AccessKit announcements from child Labels in Godot 4.6 | §C.12, §F.6 advisory 4 | 5-min in-editor verification; if fails, add explicit `_label.visible = false` to CR-DS-4 |
| **OQ-DS-13** | VG-DS-4: confirm `AudioStreamPlayer.finished` does NOT fire on `.stop()` in Godot 4.6 (load-bearing for CR-DS-7 interrupt path) | §C.12, §F.6 advisory 5 | 5-min in-editor verification; if fails, EC-DS-4 conditional applies |
| **OQ-DS-14** | VG-DS-5: confirm caption region does not overlap HUD corner widgets at 1.25× scale on 1280×720 (V.4) | §V.4, AC-DS-12.1 | Editor screenshot review; lead sign-off |
| **OQ-DS-15** | EC-DS-1 advisory lint: warn when `audio_duration_s - duration_metadata_s > 5.0 s` on a DialogueLine | §E B.2 | Tools-Programmer authoring lint |
| **OQ-DS-16** | EC-DS-5 advisory lint: text-key content validator should reject keys containing `[` (BBCode misroute) | §E I.3 | Tools-Programmer authoring lint |
| **OQ-DS-17** | EC-DS-4 conditional: if VG-DS-4 confirms `.stop()` fires `.finished`, ADR-0008 Slot 7 sub-claim re-sign with interrupt-flag guard cost (~0.001 ms — negligible, but contract change) | §E J.4, §F.6 advisory 6 | Conditional amendment; bundle with OQ-DS-2 |

### Q.3 GAP — Untestable rules (playtest / SME judgment, not CI)

These 5 GAPs are NOT bugs in the spec — they are explicit acknowledgments that some Pillar 1 / Pillar 5 design qualities cannot be reduced to a Given-When-Then test. Each requires human/playtest verdict:

| # | GAP | Source | Evidence Required |
|---|---|---|---|
| **GAP-DS-1** | "The world quips, Eve listens" — does the comedic register feel like eavesdropping? | §H.14 GAP-DS-1 | Playtest session notes signed by creative-director |
| **GAP-DS-2** | 1960s teleprinter register — does Courier Prime + scrim read as period? | §H.14 GAP-DS-2 | Art Bible §typography sign-off + ux-designer review |
| **GAP-DS-3** | Comedy lands — do the Margaux Bit / Radiator / Guard Room Cable vignettes feel right? | §H.14 GAP-DS-3 | Min 3 external playtester reactions per vignette |
| **GAP-DS-4** | Banter is atmosphere, not announcement — is implicit guidance present? | §H.14 GAP-DS-4 | Human reviewer of every banter line in context |
| **GAP-DS-5** | Actual fired-bark density per section after rate/range gate suppression | §H.14 GAP-DS-5 | One timed playtest per section, bark-count log |

### Q.4 Deliberately Omitted from MVP / VS scope

These are decisions explicitly NOT made by this GDD — recorded so future contributors understand the boundary:

1. **Branching dialogue trees** — D&S supports linear barks only; multi-choice player-driven dialogue is out of scope (no NOLF1 dialogue tree analog; no Mass-Effect-style wheel)
2. **Lip-sync** — Not in MVP/VS; characters speak "behind the camera" or with simple jaw animation. Pillar 5: 1960s spy comedy did not require AAA lip-sync
3. **Multi-language VO recordings** — English MVP only; localized VO post-launch via locale-suffixed files (A.1)
4. **Subtitle log / replay buffer** — Players cannot scroll back to re-read missed banter. Pillar 5: 1960s telex strips were ephemeral
5. **Director-mode commentary track** — Not in scope
6. **Banter recording / "guard mode"** — No emergent NPC chatter capture system; banter is authored not generative
7. **Voice modulation effects** (whispers, echoes) at runtime — Static AudioEffect chains only (A.1); no dynamic per-line modulation
8. **Captions during cutscenes** — Cutscenes & Mission Cards (#22) own their own captioning; D&S does NOT render during cutscene
9. **Sign-language captions / pictographic cues** — Out of MVP/VS; FP-V-DS-7 forbids emoji
10. **Per-actor "favorite phrases" for NPC personality** — Generic guard banter only; named NPCs (LIEUTENANT_PHANTOM_NAMED, BQA_HANDLER_NAMED) get individual lines but no procedural personality system
11. **Banter "memory" across sections** — Each section starts with empty rate-gate; cross-section guard recall not modeled
12. **Player-bark / radio-talkback** — Eve's player-driven radio choices not modeled (out of scope; no MMORPG /say chat)
