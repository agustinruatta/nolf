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
