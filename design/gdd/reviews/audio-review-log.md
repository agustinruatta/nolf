# Audio GDD — Review Log

Revision history for `design/gdd/audio.md`.

---

## Review — 2026-04-20 — Verdict: NEEDS REVISION

- **Scope signal**: M
- **Mode**: lean (no specialist agents; leveraged findings from `/review-all-gdds` 2026-04-20)
- **Blocking items**: 8 | **Recommended**: 8 | **Nice-to-Have**: 4
- **Prior verdict resolved**: First review — no prior verdict. This review was triggered by the `/review-all-gdds` 2026-04-20 FAIL verdict, which enumerated B2 (Footstep Surface Map missing + Player-domain subs), B6 (save-chime mismatch), W1 (unqualified StealthAI enum values), W7 (Formula 4 self-contradicting) for Audio specifically.

**Summary**: GDD is architecturally sound (anti-pattern fences, dominant-guard rule, dual-layer music model, 5-bus structure all well-specified and Pillar-3-consistent). All 8 blockers were propagation failures from ADR-0002's 2026-04-19 Player-domain amendment OR internal ambiguities never resolved. No re-design needed. Footstep Surface Map (B2) was the largest single addition — 21 asset rows × 2–4 variants each; unblocks audio asset production.

---

## Revision — 2026-04-20 — Session 1 (blocker-cleanup pass)

- **All 8 blockers resolved** in single focused session.
- **Load-bearing design decisions** (user-confirmed before drafting):
  - **B8 VO publisher role**: Dialogue & Subtitles GDD (VS-tier, unwritten) emits both `dialogue_line_started` and `dialogue_line_finished` using VO-metadata duration fields. Audio stays strictly subscriber-only (preserves Overview architectural promise).
  - **B7 Save-chime**: Added Persistence-domain subscription (`game_saved`, `game_loaded`, `save_failed`). Save-Load cross-reference preserved; Audio now reciprocates.
  - **B6 Formula 4 tempo**: Fixed 90 bpm (matches locked Tuning Knob). Health-scaling formula stripped. Open Question closed.
  - **B1 Footstep Surface Map loudness thresholds**: soft ≤3.5 m / normal 3.5–6.5 m / loud >6.5 m. Maps Crouch→soft, Walk/Takeoff/Soft-land→normal, Sprint/Hard-land→loud.
- **Key edits (audio.md, ~13 targeted edits)**:
  - Overview: 8-domain subscription list (was 5-domain); VO-publisher clarification note
  - Detailed Design Rule 3: complete 27-signal enumeration (was 22); `AudioManager` as scene-tree Node settled (closed OQ)
  - State / Trigger tables: qualified `StealthAI.AlertState.*` enum references (B5); dominant-guard dict `Dictionary[Node, StealthAI.AlertState]`; respawn-triggered dict clear (R7)
  - Formula 4: rewrote as start/stop trigger pseudocode; fixed 90 bpm; health-scaling removed; `int` health + explicit `float()` cast
  - Interactions table: new "Player domain" + "Documents" + "Persistence" subsections; Stealth-AI-must-not-subscribe enforcement on `player_footstep` (3 places); `player_health_changed` routed to Formula 4 instead of `player_damaged`
  - VO timing contract (§Dialogue): rewrote to clarify Dialogue & Subtitles owns both signal emissions; Audio subscriber-only
  - §Footstep Surface Map: authored 7 surfaces × 3 variants table + loudness-threshold table + playback behavior + cross-ref enforcement (~60 asset rows implied)
  - SFX event catalog: +7 rows (`player_footstep` × 3 variants, `player_interacted`, `game_saved`, `save_failed`, clock-tick note); fixed-90-bpm annotation
  - ACs: +6 new (AC-23 through AC-28) covering surface variants, `player_health_changed` threshold, save-chime, Stealth-AI-must-not-subscribe enforcement, subscriber-only invariant
  - Open Questions: closed B6 (tempo) + R1 (Node), marked with ~~strikethrough~~; 4 OQs remain (all VS-tier or asset-production scope)
  - Dependencies + Cross-References: signal count 22→27, domain count 5→8
- **Registry/ADR touches**: None. ADR-0002 Player-domain amendment (2026-04-19) is already in place — this revision was propagation-only.
- **Audio GDD re-classified**: scope signal stays M; scope of blockers all within a single file.

**Pending**: Re-review in fresh session recommended before final APPROVED mark. Cross-review 2026-04-20 flagged 5 other GDDs for revision (signal-bus.md, outline-pipeline.md, save-load.md, player-character.md, systems-index.md); Audio's revisions interlock with Signal Bus's "32→34 signals" fix (B3) and Save-Load's save-chime reconciliation (B6).

---

## Review — 2026-04-21 — Verdict: NEEDS REVISION (resolved in-session → APPROVED)

- **Scope signal**: M
- **Mode**: full (6 specialists + creative-director synthesis in parallel)
- **Specialists**: audio-director, sound-designer, game-designer, systems-designer, qa-lead, godot-specialist; senior synthesis by creative-director
- **Blocking items**: 15 | **Recommended**: 19 | **Nice-to-Have**: 7
- **Prior verdict resolved**: Yes — all 8 blockers from 2026-04-20 remained resolved; this review was triggered by the Stealth AI GDD approval (2026-04-21) which enumerated 6 new Audio pre-implementation-gate items as a downstream dependency shift.

**Summary**: Architecture and engine claims were clean (godot-specialist: 0 blockers; all 4.6 API references verified). All 15 blockers were either (a) contract drift from the Stealth AI GDD's post-amendment signal signatures that Audio GDD had not yet propagated, (b) previously-unresolved concurrency-policy gaps (stinger per-beat-window debounce, same-state idempotence, SCRIPTED-cause suppression, dominant-guard dict cleanup on section transition), (c) three formula-correctness defects (Formula 1 missing −80 dB clamp, Formula 2 no absolute ceiling with clipping risk, Formula 4 unguarded max_health=0 divide-by-zero), or (d) AC testability failures (ALL 28 ACs lacked test-evidence paths per project standard; AC-12/13 not executable). 4-way specialist consensus flagged the severity-filter gap on the stinger as Pillar 1 death.

Creative-director verdict: "The architecture is sound, engine claims are clean, and the blocker set is targeted. This is one focused revision session — the same shape as the prior 8-blocker pass that closed in one sitting."

---

## Revision — 2026-04-21 — Session 2 (15-blocker cleanup + 4 design decisions)

- **All 15 blockers resolved** in single focused session; user elected to accept revisions without fresh re-review.
- **4 load-bearing design decisions locked** (user multi-tab AskUserQuestion before drafting — all recommended options chosen):
  - **D1 Bedlam formula direction**: diegetic recedes (−1 dB/civ, cap −3 dB), non-diegetic holds (+0.5 dB/civ, cap +2 dB). Pillar 1 fix — the quartet recoils from the chaos; the stealth cool doesn't cheer it on. Replaced prior +2 dB/civ / +6 dB cap on non-diegetic (game-designer + creative-director concurred: prior formula made score the punchline).
  - **D2 SCRIPTED-cause stinger**: SUPPRESS. Audio's `actor_became_alerted` handler gates on `severity == MAJOR AND cause != SCRIPTED`. Cutscene composers own their composed audio; Audio never surprises them with brass stabs.
  - **D3 Respawn fade**: 200 ms silence then 2.0 s ease-in to `*_calm` (was 0.5 s linear). Pillar 3 theatre-not-punishment read — the longer fade is the house lights coming up between scenes, not a cinema hard-cut "nothing happened."
  - **D4 VO duck**: state-keyed per-layer table (was flat −8 dB music / −6 dB ambient). `MusicDiegetic` ducks deeper during calm (−14 dB — comedy priority when jazz is loud); `MusicNonDiegetic` ducks lighter during combat (−4 dB — signal preservation when score IS the alert cue). Audio-director + game-designer merge.
- **Key edits (audio.md, 575 → 693 lines; +118 lines across ~25 targeted edits)**:
  - Rule 3: 30-signal enumeration across 9 gameplay domains + Settings; post-amendment 4-param/3-param signatures for AI/Stealth; `section_exited` added; ADR-0002 amendment prerequisite flagged
  - Trigger table row 104 (`actor_became_alerted`): condition now `severity == MAJOR AND cause != SCRIPTED`
  - §Interactions AI/Stealth: post-amendment signatures for all 4 signals; severity gate + SCRIPTED suppression documented; takedown_type branching rule
  - §Interactions Mission: `section_exited` row added; `AudioEffectReverb` reverb swap clarified as in-place property mutation (glitch-free during crossfades)
  - §Interactions Failure/Respawn: new subsection (moved from Mission per ADR-0002:183)
  - **New §Concurrency Policies subsection** (5 rules): stinger per-beat-window debounce, same-state idempotence, SCRIPTED-cause suppression, dominant-guard dict clear on section_exited, bedlam tween mid-decrement
  - Formula 1 rewritten: state-keyed per-layer duck table; `max(..., -80.0)` clamp; short-VO tween-interrupt edge case
  - Formula 2 rewritten per D1: diegetic attenuation + non-diegetic boost + `min(..., 0.0)` ceiling
  - Formula 4: `max_health <= 0.0` early-return guard; `int`→`float` alignment with signal signature per ADR-0002:151; `tick_last_stopped_age_s = INF` initial-value documentation
  - SFX event catalog row for `takedown_performed`: split into MELEE_NONLETHAL (chloroform whoosh + cloth-drape + body-slump) and SILENCED_PISTOL (muffled thud + fabric rustle)
  - Tuning Knobs: state-keyed per-layer duck knobs (8 new constants for Formula 1); civilian bedlam section rewritten for Formula 2; new `respawn_fade_in_s` + `respawn_silence_s` transition knobs
  - Acceptance Criteria: clean-renumbered 1–40 (was 1–22 + 23–28 with a 24/24a collision); story-type tags + `tests/unit/audio/...` evidence paths on every AC; new ACs for severity filter (AC-9), SCRIPTED suppression (AC-10), stinger debounce (AC-11), same-state idempotence (AC-12), section-exit cleanup (AC-13), state-keyed VO duck in calm + combat (AC-14, AC-15), VO duck clamp (AC-16), tween-interrupt (AC-17), pool slot-steal inspector API (AC-19), attenuation-config white-box (AC-20), Plaza radio analytical attenuation (AC-21), max_health=0 guard (AC-27), clock-tick-stops-on-death (AC-28), bedlam diegetic-recedes (AC-30), bedlam non-diegetic ceiling (AC-31), respawn 2 s ease-in (AC-33), takedown_type branching (AC-38); AC-7 beat-quantization extracted to pure function for deterministic unit test
  - Overview + Quick Reference + Dependencies + Cross-References: all updated to match new signal count (30/9 gameplay domains) and new handler signatures
  - Open Questions: 4 OQs closed this session (bedlam direction, SCRIPTED-cause, respawn crossfade, VO duck); 3 new OQs added (ADR-0002 amendment pre-impl gate, stairs surface deferral, 50 Hz Paris grid asset correction, civilian gasp VO ownership)
- **Registry/ADR touches**: None in this session. ADR-0002 amendment is a separate `/architecture-decision` session owned by technical-director (Stealth AI pre-impl gate #1). Audio GDD is now aligned with post-amendment signatures.
- **Pre-implementation gates that remain OPEN** (owned by other systems, not blocking Audio GDD approval): (a) ADR-0002 amendment (AI/Stealth severity + takedown_type in Events.gd code block) — owned by technical-director; (b) Signal Bus GDD enum-ownership touch-up (add `StealthAI.Severity` + `StealthAI.TakedownType`) — owned by Stealth AI pre-impl gate #3.

**Status**: Audio GDD APPROVED 2026-04-21 after in-session revision. Ready for downstream authoring (Settings & Accessibility, Cutscenes & Mission Cards, Dialogue & Subtitles when their GDDs land) and for asset production after the art bible is approved (`/asset-spec system:audio`).
