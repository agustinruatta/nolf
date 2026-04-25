# Failure & Respawn — Review Log

Revision history for `design/gdd/failure-respawn.md`. Each entry records the `/design-review` verdict, specialists consulted, blocking/recommended counts, and a summary of key findings and resolutions.

---

## Review — 2026-04-24 — Verdict: MAJOR REVISION NEEDED → Accepted (inline revision; fresh-session re-review SKIPPED)

**Scope signal**: L
**Specialists**: game-designer, systems-designer, godot-specialist, gameplay-programmer, qa-lead, performance-analyst, audio-director, + creative-director (senior synthesis)
**Blocking items**: 21 | **Recommended items**: ~30 | **Nice-to-have**: 2
**Prior verdict resolved**: N/A — first review

### Summary

First-pass review of the 513-line `/design-system failure-respawn` output (authored same session as `/consistency-check` 2026-04-24). Seven adversarial specialist reviews converged on **two structural defects that cannot be patched inline**, plus five live cross-GDD contradictions, plus a performance escalation (undeclared min-spec storage tier), plus an unresolved audio-contract policy. Creative-director synthesis delivered MAJOR REVISION NEEDED verdict and strongly recommended fresh-session re-review per the prior-flagged "accept-without-re-review" antipattern.

### Key structural defects identified

1. **S-4 / G-1 / G-2 — floor-flag split-brain (diagnostic finding)**: Three specialists independently converged on the same defect. CR-5/CR-6 specified F&R reads `floor_applied_this_checkpoint` from the *serialized* `FailureRespawnState` at step 9, but by step 3 the dying-state save already advanced the flag to `true` on first death. At step 9 `should_apply_floor` evaluates `false` → floor never applies on first death. **Behavior inverted from design intent.** The convergence of three specialists on identical reasoning was the diagnostic: solo-mode authoring had written the inversion past the author's own mental model.
2. **S-5 / G-3 — States-table ↔ CR-12 contradiction**: States table says RESTORING "blocks further section_entered handler work"; CR-12 step 11/12 requires section_entered(RESPAWN) handler to fire `reset_for_respawn` during RESTORING. Direct contradiction.
3. **G-7 — queued-respawn checkpoint-overwrite**: During RESTORING in a CR-10 queued-respawn, the in-flight forward-section's `section_entered(FORWARD)` fires; F&R's handler (with no `reason` guard) overwrites `_current_checkpoint` with the forward marker. Eve teleports to the wrong section.
4. **Five live cross-GDD contradictions**: save-load.md L100/L151 `load_from_slot(0)` stale text, save-load.md missing FailureRespawnState schema row, input.md zero LOADING mentions, inventory-gadgets.md L312 `restore_weapon_ammo` API mismatch, signal-bus.md L122 missing section_entered subscription.
5. **P-3 (ESCALATION)**: ADR-0001 does not declare min-spec storage tier. On HDD, F.2's t_swap would be 2–4 s — F.2 is a SSD-on-warm-cache budget masquerading as min-spec.
6. **A-1 + B-1 (experiential)**: Mission-failure sting (2–3 s trumpet on `player_died`) vs respawn silence-cut has no policy. Either sting is clipped at 15 ms or layers over 2.0 s calm fade. Creative-director ruled: suppress sting on respawn path; 2.0 s fade is too long + 200 ms silence is too short for "house lights up" feel → retune to ~0.4 s silence + ~1.2 s fade.

### Creative-director synthesis excerpt

> "The GDD is *thoughtful*, *well-structured*, and shows clear Pillar 3/5 awareness — it is not poorly authored. It is ambitious across many systems and the ambition exposed defects that would not have been caught by a solo-mode or lean review. This is exactly what the full review is for."

> "Strongly enforce the `/clear` + fresh-session re-review protocol. Do NOT accept inline revisions-and-move-on. My prior stance stands and is reinforced by this review: the GDD author touched this file in the same session as `/design-system` authoring AND `/consistency-check`. Context is polluted with the author's own justifications — which is precisely why the S-4/G-1/G-2 inversion was written past without the author catching it."

### Resolution path (inline revision applied in same session; user elected not to re-review in fresh session — CD recommendation overridden, continuing the accept-without-re-review pattern CD has flagged)

User-approved design decisions on the four adjudication points:
- (Q1) Flag split-brain fix: **live-member authoritative** — F&R holds `_floor_applied_this_checkpoint: bool` as the authoritative live copy; save mirrors live via `FailureRespawnState.capture(live_value)`; reads at step 9 come from live only; live advances synchronously after Inventory returns.
- (Q2) RESTORING rules: **allow dispatch-only; block all state-mutating section_entered work via `_flow_state == IDLE` guard in CR-7**. Resolves both the States-table contradiction AND the queued-respawn checkpoint-overwrite defect (G-7).
- (Q3) Cross-GDD scope: **file as coord items; edit failure-respawn.md only in this session** per CLAUDE.md collaborative-design principle.
- (Q4) Audio handshake: **full CD ruling accepted** — sting suppression + silence retune to 0.4 s + fade retune to 1.2 s as Audio GDD amendment requests.

### Resolutions applied (file grew 513 → 553 lines)

- **CR-5** rewritten for live-authoritative read at step 9; rationale expanded to document the split-brain defect that was being avoided.
- **CR-6** rewritten to describe FailureRespawnState as serialized *mirror*, not authoritative source; added explicit `_init()` constructor per ADR-0003; added read/write contract with 4 cases (capture, restore, step 9, section_entered); documented Resource additivity for forward-compat.
- **CR-7** rewritten with `_flow_state == IDLE` guard on state-mutating branches; covers both States-table contradiction AND CR-10 queued-respawn G-7 defect.
- **CR-8** rewritten with (a) subscriber re-entrancy fence, (b) sting-suppression rule per CD adjudication, (c) explicit policy for the <=100 ms player_died + respawn_triggered overlap.
- **CR-10** rewritten with single-emit guarantee + N-bound (depth-1 per LS CR-6) + 2.5 s debug watchdog.
- **CR-11** rewritten with explicit `find_child(recursive=true, owned=false)` lookup contract; `Checkpoint` relocated to `src/gameplay/shared/` to avoid PC → F&R load-order dep.
- **CR-12 step 9** annotated with live-authoritative read + synchronous advance; step 4 annotated with ADR-0003 await-forbid coord item; step 12 reconciled with CR-7 guard.
- **States table** rewritten with Blocks/Allows clarified + explicit disambiguation note covering queued-respawn case.
- **F.1** rewritten with 7 transition rows (from 4) + default arm for novel `TransitionReason` + explicit hydrate + null-fallback rows.
- **F.2** marked PROVISIONAL pending ADR-0001 storage-tier amendment; arithmetic corrected (0.15 → 0.167 s); SSD-cold vs HDD-cold rows separated; correlated-variable caveat added; perceived-beat target revised to ~1.6 s (pending Audio GDD amendment).
- **E.20** rationale flipped from "conservative" to explicit permissive-on-corruption tradeoff.
- **7 blocking ACs rewritten** (1.1 synchronous oracle; 2.1 isolated scenario + separate simultaneous-bullet test; 3.1 DI hook spec; 5.5 null-injection test-double subclass; 6.2 BLOCKED pending godot engine gate; 10.1 hardware pin per ADR-0001 + p90; 10.2 Playtest type).
- **2 new ACs**: AC-FR-12.4 (sole-publisher CI lint per ADR-0002:183) + AC-FR-12.5 (re-entrancy CI lint).
- **BLOCKING items table** expanded 5 → 12 items with explicit sub-bullet coord items.
- **Bidirectional consistency check** expanded to flag all 5 cross-GDD contradictions as coord items.
- **6 new OQs**: OQ-FR-7 (storage tier, BLOCKING, TD-escalated), OQ-FR-8 (signal isolation, BLOCKING, engine gate), OQ-FR-9 (Jolt body_exited, advisory), OQ-FR-10 (stealth-stuck-alive, playtest), OQ-FR-11 (Restart-from-Checkpoint, playtest), OQ-FR-12 (LOAD_FROM_SAVE farm-exploit), OQ-FR-13 (progressive-punishment), OQ-FR-14 (geometry-clip watchdog), OQ-FR-15 (dart-mid-sedation race).
- **3 new Design Gaps**: DG-FR-5 (signal-isolation engine gate), DG-FR-6 (schema forward-compat documented as conscious deferral), DG-FR-7 (unresolved GD recommendations logged as OQs).
- **AC Count Summary** updated 38 → 40 ACs (Group 12 grew from 3 to 5).
- **Header "Last Updated"** expanded to document the revision scope for traceability.

### Specialists' verbatim finding summaries preserved

For full specialist output (B-1..B-7, S-1..S-8, E-1..E-9, G-1..G-8, Q-1..Q-17, P-1..P-7, A-1..A-7) plus creative-director synthesis, see the `/design-review` session transcript. The review-log entries below condense the convergent findings only.

### Pre-implementation gates (OPEN — do NOT start sprint until closed)

1. **ADR-0007 amendment** (F&R autoload at line 8) — pre-existing
2. **Inventory GDD coordination** — rename `restore_weapon_ammo(floor_dict)` → `apply_respawn_floor_if_needed(snapshot, should_apply_floor)`
3. **Save/Load GDD + ADR-0003 schema coordination** — 4 sub-items: add FailureRespawnState schema; fix L100/L151 stale load_from_slot text; forbid internal `await` in save_to_slot; atomic-commit fence
4. **Input GDD coordination** — add `InputContext.LOADING` context spec
5. **Signal Bus GDD touch-up** — add F&R's section_entered subscription to L122 row
6. **Audio GDD amendment** — sting-suppression + silence/fade retune (coord items)
7. **ADR-0001 amendment (ESCALATED TO TD)** — declare min-spec storage tier
8. **LS GDD coordination** — document replace-semantics on `register_restore_callback`
9. **godot-specialist engine-verification gate** — Godot 4.6 signal-isolation on subscriber unhandled exception
10. **PC GDD null-checkpoint spec** (OQ-FR-5) — pre-existing BLOCKING
11. **Mission Scripting (PROVISIONAL)** — `player_respawn_point: Marker3D` authoring + non-deferred contract + section-validation CI
12. **Shared Checkpoint class location** — `src/gameplay/shared/checkpoint.gd`

### Re-review protocol note

Creative-director explicitly recommended `/clear` + fresh-session re-review. User elected to accept inline revisions and mark Approved pending coord items. This is the fourth consecutive GDD on which this pattern has been applied (SAI 4th-pass, Combat 2nd-pass, Inventory, now F&R). **The producer should track this pattern.** A fresh-session re-review remains available via `/design-review design/gdd/failure-respawn.md` at any point and is advisable before the F&R sprint begins.
