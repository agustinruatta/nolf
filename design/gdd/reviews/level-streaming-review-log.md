# Level Streaming — Review Log

Revision history for `design/gdd/level-streaming.md`. Mirrors the pattern used for `audio-review-log.md` and `stealth-ai-review-log.md`.

---

## Review — 2026-04-21 — Verdict: MAJOR REVISION NEEDED (accepted with inline revision)

**Scope signal**: L (Foundation-layer system with 12+ dependencies, ADR-0002 amendment required, cross-cutting impact across Signal Bus / Save-Load / Audio / Input / Mission / Failure-Respawn / Menu / Cutscenes / FootstepComponent)

**Specialists consulted (8 + 1 senior synthesis)**:
- game-designer (Player Fantasy delivery)
- systems-designer (cross-system contracts)
- godot-specialist (Godot 4.6 API validity)
- level-designer (scene-authoring workflow)
- qa-lead (22 ACs across 6 test-type groups)
- performance-analyst (≤1.3 s budget + ≤4 GB memory ceiling)
- ux-designer (Pillar 5 discipline, accessibility, tone)
- audio-director (cross-GDD contract drift)
- creative-director (senior synthesis)

**Blocking items surfaced**: 23 (across 5 tiers: design-defects, systems-level, authoring-workflow, AC defects, UX/tone)
**Recommended (advisory)**: 18
**Specialist disagreements**: 3 (fade-timing severity, respawn-race fix approach, plugin-validator ownership — all resolved by creative-director adjudication)

**Senior verdict (creative-director)**:
> "MAJOR REVISION NEEDED. Not because the system is unsalvageable — because the player fantasy is misidentified, which has cascaded into eight specialist reports finding downstream damage. When game-designer, UX, and audio independently circle back to 'this doesn't feel like what it says it feels like,' that's a pillar-level failure, not a polish pass. The 300 ms respawn race alone would justify a block; combined with the Audio GDD contract drift and the unverified Godot API claims, this document is not ready to hand to implementers."

**Top 5 blockers identified**:
1. 300 ms respawn race violates Pillar 3 (ship-blocking bug; state-divergence)
2. Audio GDD contract drift (Mission handler table 1-param signatures; silent bundle-scope risk)
3. `is_respawn: bool` wrong information shape (4 distinct caller intents, boolean flattens them)
4. Unverified Godot 4.6 API claims (CanvasLayer 128 range; current_scene direct assignment; queue_free ordering)
5. ErrorFallback "FILE NOT FOUND" tone-break (DOS error inside BQA letterhead)

**Pre-implementation gates declared (LS-owned)**:
- LS-Gate-1: ADR-0002 amendment — `section_entered`/`section_exited` gain `reason: TransitionReason` enum parameter
- LS-Gate-2: Input GDD — add `InputContext.Context.LOADING` enum value
- LS-Gate-3: Audio GDD — amend §Mission domain handler table (lines 188–189) for 2-param signatures + branching table
- LS-Gate-4: Save/Load GDD — revise §Visual/Audio fade-timing annotation for hard-cut grammar (documentation-only)

**User-approved design decisions during inline revision pass**:
1. **Fade timing**: hard-cut snap, 2 frames out + 2 frames in (replaces 0.3/0.5 s dissolve) — CD adjudication accepted
2. **Enum**: `TransitionReason { FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE }` — minimal 4-value set
3. **Respawn race**: CD's "queue respawn; fire at step 13; resolve to checkpoint if death mid-cut" (beats game-designer's "interrupt in-flight transition" alternative)
4. **Step 9 coordination**: `register_restore_callback(Callable)` API surface (beats Callable-param and documented-deferred alternatives)
5. **Defensible defaults applied** (not asked, taken to keep within 4-question AskUserQuestion limit):
   - CR-11 kill_plane_y validation: DELETED entirely (per level-designer "semantically vacuous" critique)
   - ErrorFallback copy: "TRANSMISSION LOST — RETURNING TO BASE" (period-authentic alternative from CD's suggestion)
   - F5/F9 handling: queue during transition, fire on FADING_IN → IDLE (replaces silent drop)

**Revision output**:
- GDD: 455 → 591 lines (+136 lines of added rigor)
- Core Rules: 12 → 16 (CR-13 sync-subscribers, CR-14 same-section no-op, CR-15 focus-loss, CR-16 F5/F9 queue, plus registry of CR-1–CR-12 renumbered)
- Swap-sequence steps: 12 → 13 (step 3a: disconnect LS-owned signals BEFORE queue_free)
- Total transition budget: ≤1.3 s → ≤0.57 s
- ACs: 22 → 29 (7 new; AC-LS-3.1 split into 3.1a/b/c; AC-LS-5.3 rewritten; AC-LS-4.3 moved to FC scope)
- Open Questions: 7 → 10 active + 2 CLOSED (OQ-LS-3 respawn-race resolved; OQ-LS-5 easing curves obsoleted by hard-cut)

**Prior verdict resolved**: Yes — MAJOR REVISION NEEDED verdict closed same session via 23-blocker + 18-advisory inline revision. User accepted revisions and marked Approved 2026-04-21 without a fresh re-review. The revision introduced substantial new surface area (registered-callback API, queued-respawn logic, CR-13/14/15/16) that has NOT been specialist-re-reviewed; this is flagged as a known risk in the post-revision closing widget and may warrant a fresh-session re-review if implementation surfaces gaps.

**Downstream implications**:
- Audio GDD requires amendment pass (LS-Gate-3) — not blocking LS implementation but required for Audio to match post-amendment signatures
- Input GDD requires LOADING enum addition (LS-Gate-2) — blocks Input GDD's path to Approved
- Save/Load GDD requires documentation revision (LS-Gate-4) — cosmetic
- ADR-0002 amendment session (LS-Gate-1) scoped separately from Stealth AI's amendment to prevent silent-bundle-scope risk (audio-director flagged)
- Systems-index: Effort revised M → L; Approved count 4 → 5; row #9 Dependencies now lists Tools Programmer as an owner
- FootstepComponent OQ-FC-1 CLOSED (CR-10 resolution)
- `kill_plane_y` entity-registry row `referenced_by` list to drop `design/gdd/level-streaming.md` (CR-11 deleted)
