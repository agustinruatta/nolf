# Session State

**Last updated:** 2026-04-23 (ADR-0008 Performance Budget Distribution **WRITTEN** — 9 Iris Xe slots summing 16.6 ms + non-frame budgets + 4 validation gates. Gap 2 from /architecture-review 2026-04-23 CLOSED. SAI Recommended Follow-up #5 CLOSED. combat-damage.md L233 cross-system reconciliation flag CLOSED. Registry gained 9 performance_budgets + 1 api_decision + 2 forbidden_patterns. All priority ADRs now written (0001–0008).)

## Current task (2026-04-23 — ADR-0008 performance budget distribution session)

✅ **ADR-0008 WRITTEN** (Proposed; 4 validation gates pending measurements). godot-specialist validation YELLOW with 3 prose constraints folded in before write: (a) directional shadow cascade cap = 1 named in Constraints + Risk row + forbidden pattern; (b) PostProcessStack cold-boot dominance (5–15 ms Vulkan + 5–10 ms D3D12) documented in non-frame budgets table + Risk row; (c) D3D12 post-stream warm-up 3-frame allowance added to non-frame budgets table + Validation Gate 3.

**Iris Xe allocation (normative, 16.6 ms total):** Rendering 3.8 · Guard systems (SAI+GuardFire) 6.5 · Post-Process chain 2.5 · Jolt physics 0.5 · Player/FC/Combat non-GF 0.3 · Audio dispatch 0.3 · UI refresh 0.3 · Pooled residual 0.8 · Reserve 1.6 = 16.6 ms.

**Files modified this session:**
- `docs/architecture/adr-0008-performance-budget-distribution.md` — **NEW** (~390 lines, 13 sections, 9-slot allocation table + non-frame budgets table + verification contract + 4 validation gates + alternatives A/B/C + 7 risks)
- `design/gdd/combat-damage.md` L233 — cross-system reconciliation flag marked CLOSED by ADR-0008 Slot #2
- `design/gdd/stealth-ai.md` L684 — Recommended Follow-up #5 marked CLOSED by ADR-0008
- `docs/registry/architecture.yaml` — **last_updated 2026-04-23** (comment extended); 9 NEW performance_budgets entries (rendering-pipeline 3.8, guard-systems 6.5, post-process-chain 2.5, jolt-physics-step 0.5, player-fc-combat-nonGF 0.3, audio-dispatch 0.3, ui-refresh 0.3, pooled-residual 0.8, reserve-unallocated 1.6); outline-pipeline referenced_by expanded to include ADR-0008 (revised 2026-04-23); 1 NEW api_decisions entry (performance_budget_enforcement — CI-time reference scene gate, not runtime BudgetRegistry); 2 NEW forbidden_patterns (unbudgeted_per_frame_ticking, directional_shadow_second_cascade).

**Engine specialist validation (Step 4.5):** godot-specialist returned **YELLOW** with 3 specific prose constraints + GREEN on Jolt 0.5 ms slot. Folded all 3 notes into ADR before write. Specialist observations NOT yet applied (logged for code-review phase): AudioServer bus graph rebuild on reverb swap is a 0.3–0.8 ms CPU stall on the game thread in the same frame as the swap — absorbed by reserve but worth reviewer attention when Audio's section_entered handler lands.

**Technical Director review (Step 4.6):** SKIPPED — solo review mode per `production/review-mode.txt`.

**Dependencies closed by this ADR:**
- /architecture-review 2026-04-23 **Coverage Gap 2** (Performance Budget Distribution ADR) — CLOSED (pending validation gates to move Proposed → Accepted)
- SAI GDD Recommended Follow-up #5 (line 684) — CLOSED
- combat-damage.md L233 cross-system reconciliation flag — CLOSED

**Downstream still open (producer-tracked, out of this ADR's scope):**
- 3 GDD-coordination items (unchanged): PC rename `CombatSystem.*` → `CombatSystemNode.*` (~10 sites); Audio GDD L188–189 §Mission handler table (LS-Gate-3); Input GDD L90 `use_gadget` → dedicated `takedown` action.
- All 8 ADRs (0001–0008) still **Proposed**. Total verification gates outstanding: **21** (prior 17 + 4 new from ADR-0008).
- ADR-0008 Gates 1–4 require measurement on (a) Iris Xe Gen 12 min-spec, (b) RTX 2060 informative, (c) Windows D3D12 post-stream warm-up, (d) autoload boot cold-start on both platforms. Reference scene `tests/reference_scenes/restaurant_dense_interior.tscn` does not yet exist — scoped to a separate tooling story (prototyper or qa-lead).
- CI `perf-gate` job configuration — scoped to a separate devops-engineer story.

**Next action** (user runs in a FRESH session, not here): `/architecture-review` to verify Gap 2 closure and re-assess verdict (expected: CONCERNS → PASS if no new conflicts surface; remaining blockers become verification gate pass on existing ADRs + 3 producer-tracked GDD touch-ups).

---

## Prior task (2026-04-22 — ADR-0002 4th-pass LS + SAI amendment session)

_Preserved below for context. See Session Extracts at end for /architecture-review 2026-04-23 runs and /architecture-decision autoload-load-order-registry 2026-04-23 session._

## Current task (2026-04-22 — ADR-0002 4th-pass LS + SAI amendment session)

✅ **ADR-0002 4th-pass amendment COMPLETE.** Bundles: (a) `section_entered(section_id: StringName, reason: LevelStreamingService.TransitionReason)` 2nd param added; (b) `section_exited` same; (c) NEW `signal guard_incapacitated(guard: Node)` AI/Stealth domain; (d) NEW `signal guard_woke_up(guard: Node)` AI/Stealth domain; (e) signal count 34 → 36; (f) enum-ownership list grows by `LevelStreamingService.TransitionReason { FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE }`; (g) new Risks row: atomic-commit required (GDScript parse failure on project load if Events.gd references qualified enum before owning script declares it).

**Files modified this session:**
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — 11 edit sites. Last Verified parenthetical; Summary count 34→36 + 4th-pass phrase; NEW Revision History entry (2026-04-22 4th-pass bundle) covering all 4 signal changes + cadence guarantees + atomic-commit Risks + downstream scope flags; Decision intro count + enum list grows; AI/Stealth domain block gains guard_incapacitated + guard_woke_up declarations with comment headers documenting one-shot-per-guard cadence; Mission domain section_entered/exited grow `reason: LevelStreamingService.TransitionReason` 2nd param with branching-subscribers comment; IG2 enum-ownership list inserts `LevelStreamingService.TransitionReason` (class_name + autoload-order-4 annotation); Risks table new row for atomic-commit hazard (godot-specialist wording "GDScript parse failure on project load" — not "autoload chain"; LOW×HIGH + single-PR mitigation + optional CI grep); Migration Plan step 2 stub-enum list grows; Validation Criteria item 2 count 34→36 + item 3 stub-class list grows; Related section gains level-streaming.md entry + stealth-ai.md entry expanded with 4th-pass signal references.
- `design/gdd/signal-bus.md` — 6 edit sites. §17 Overview count 34→36 + 4th-pass note; §54 AI/Stealth canonical signals list gains guard_incapacitated + guard_woke_up (with dated annotations); §59 Mission domain row notes TransitionReason + LS co-emitter; §117 Stealth AI dep row expanded (publishes guard_incapacitated + guard_woke_up in addition to existing 4 signals); AC-3 count 34→36 with new-signals + section-signal-2-param clauses; AC-13 enum list gains `LevelStreamingService.TransitionReason`.
- `docs/registry/architecture.yaml` — `gameplay_event_dispatch` signal_signature refreshed inline (36 signals, 4th-pass additions documented: guard_incapacitated + guard_woke_up semantics + section_entered/exited 2nd param + enum ownership gain). `revised: 2026-04-22` comment extended.

**Engine specialist validation (Step 4.5):** godot-specialist returned **YELLOW** pre-write; 2 text corrections folded in before applying: (1) Risks-row wording changed from "autoload chain at startup" to "GDScript parse failure on project load" + removed "or vice versa" symmetry claim (only Events-references-missing-enum direction is dangerous); (2) IG5 cadence note added in Revision History for both new signals (one-shot per guard per session, trivially within budget). Post-correction verdict treated as GREEN. Additional specialist observations NOT applied this session (logged for code-review phase): (a) signal re-entry from within guard_incapacitated handlers is safe via Godot 4.x internal dispatch queuing but warrants reviewer attention when subscribers are implemented; (b) use `Node` (not subtyped) for guard payloads — already matches drafted form.

**Technical Director review (Step 4.6):** SKIPPED — solo review mode per `production/review-mode.txt`.

**Dependencies closed by this amendment:**
- /architecture-review 2026-04-22 Coverage Gap 1 (ADR-0002 amendment completion) — CLOSED
- /architecture-review Conflict 2 (ADR-0002 Key Interfaces vs. LS GDD 2-param signatures) — CLOSED
- /architecture-review Conflict 3 (ADR-0002 missing SAI 4th-pass signals) — CLOSED
- LS GDD LS-Gate-1 (ADR-0002 section-signal amendment) — CLOSED
- SAI GDD pre-impl gate #1(c) + #1(d) (guard_incapacitated + guard_woke_up in ADR-0002) — CLOSED
- Signal Bus GDD touch-up (SAI enum ownership + new-signal domain-table row per session-state item #3) — CLOSED

**Downstream still open (producer-tracked; out of this amendment's scope):**
- /architecture-review Coverage Gap 2 — Performance Budget Distribution ADR (cross-cutting 7 systems).
- /architecture-review Coverage Gap 3 — Autoload registration contract (InputContext + LevelStreamingService load-order-4 collision — editorial hazard per Specialist §1).
- /architecture-review Conflict 1 — same autoload collision. Resolves via either a dedicated autoload-registry ADR or surgical ADR-0004 + LS GDD amendment.
- LS-Gate-3 — Audio GDD §Mission-domain handler table (currently 1-param at lines 188–189) must grow `reason: TransitionReason` + branching table per LS GDD CR-8. Audio-owned edit.
- Producer-tracked `CombatSystem.DeathCause` → `CombatSystemNode.DeathCause` rename in `design/gdd/player-character.md` lines 200, 457, 591 (carried from prior OQ-CD-1 pass).
- All 6 ADRs still `Proposed` — verification gates outstanding across the chain (16 gates tracked in architecture-review-2026-04-22.md).

**Next action** (user runs in a FRESH session, not here): either (a) `/architecture-review` to verify that Coverage Gap 1 + Conflicts 2+3 are closed by this amendment and surface any remaining gaps; (b) `/architecture-decision autoload-load-order-registry` or surgical ADR-0004 + LS GDD amendment for Coverage Gap 3; (c) `/architecture-decision performance-budget-distribution` for Coverage Gap 2.

---

## Prior task (2026-04-22 — ADR-0002 OQ-CD-1 amendment session)

✅ **ADR-0002 amendment COMPLETE.** Bundles: (a) 3 perception signals grow `severity: StealthAI.Severity`; (b) `takedown_performed` → 3-param form with `attacker` + `takedown_type: StealthAI.TakedownType`; (c) `player_died` payload rename `CombatSystem.DeathCause` → `CombatSystemNode.DeathCause`; (d) NEW `Accessor Conventions (SAI → Combat)` subsection declaring `has_los_to_player()` + `takedown_prompt_active(attacker)` as principled `direct_call` carve-out with 4 exemption criteria + no-new-accessors fence; (e) enum-ownership list grows by 2 owners + CombatSystemNode rename propagated; (f) Risks table row added for specialist MINOR note (inner-enum editor reimport).

**Files modified this session:**
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — 9 edit sites; 361 → 430 lines. Summary + Revision History + Decision intro + 4 signal declarations in Key Interfaces + NEW Accessor Conventions subsection + Implementation Guideline 2 enum-list + Risks (2 new rows) + Migration Plan step 2 + Validation Criteria (2 updated items) + Related section expanded (4 new GDD cross-refs) + Last Verified date bumped.
- `docs/registry/architecture.yaml` — `gameplay_event_dispatch` signal_signature refreshed (34 signals, OQ-CD-1 signature changes documented) with `revised: 2026-04-22`; NEW `sai_public_accessors` interface contract (pattern `direct_call`, producer `stealth-ai-system`, consumer `combat-and-damage-system`); `last_updated: 2026-04-22`.
- `design/gdd/signal-bus.md` — line 117-118 enum-ownership rows expanded (SAI gets Severity + TakedownType + 2 accessor-method declarations; Combat renamed to CombatSystemNode) + line 207 AC-13 enum-inventory list refreshed.

**Engine specialist validation (Step 4.5):** godot-specialist returned **GREEN** with 1 MINOR note (captured in Risks row).

**Downstream still out of scope (producer to sequence coordinated rename pass):**
- `design/gdd/player-character.md` — lines 200, 457, 591 reference `CombatSystem.DeathCause` (frozen Approved sig; rename needed).
- `design/gdd/audio.md` — actually AHEAD of ADR, already uses 4-param + takedown_type routing. No edit needed.

## Current task

✅ `design/gdd/stealth-ai.md` — **/design-system OQ-CD-1 revision COMPLETE (2026-04-22)**. 3rd-pass revision applied inline; file grew from 708 → ~800 lines. All 7 OQ-CD-1 items closed (6 scope items per combat-damage.md §OQ-CD-1 + 1 bundled §V.4 body-drop approach vector). Entity registry updated with 5 new phantom_guard attributes. Pre-implementation Combat gates AC-CD-7.1, 7.3, 6.1 unblocked.

**Next action** (user runs in a FRESH session, not here): `/design-review design/gdd/stealth-ai.md` — validate the 3rd-pass revision independently.

### OQ-CD-1 amendment closure (2026-04-22, this session)

7 amendment items applied via `/design-system stealth-ai` revision mode:

1. **AlertState.UNCONSCIOUS 6th state** — added to enum, perception-reachability note, severity rule, state diagram, transition table (split into 3 rows), per-state behaviour table, F.4 propagation filter (excludes UNCONSCIOUS like DEAD).
2. **`receive_damage(...) -> bool is_dead` return contract** — synchronous mutation guarantee (no `call_deferred`); documented on §C.3 Combat & Damage dep row + AC-SAI-1.7 + AC-SAI-1.11.
3. **Lethality routing via `Combat.is_lethal_damage_type()`** — lethal (BULLET / MELEE_BLADE / FALL_OUT_OF_BOUNDS) → DEAD; non-lethal (DART_TRANQUILISER / MELEE_FIST) → UNCONSCIOUS. Transitional model: UNCONSCIOUS + further lethal → DEAD; UNCONSCIOUS + further non-lethal → idempotent no-op. New edge cases E.19, E.20, E.21.
4. **TakedownType enum** — `STEALTH_BLADE` present, `SILENCED_PISTOL` already removed (prior /consistency-check pass). Verified.
5. **Public accessors** — `has_los_to_player() -> bool` (F.1 cache hit, 10 Hz stale-safe) + `takedown_prompt_active(attacker: Node) -> bool` (state ∈ {UNAWARE, SUSPICIOUS} + rear 180° half-cone + ≤1.5 m + no LOS). Documented on §C.3 Combat dep row + AC-SAI-3.9 + AC-SAI-3.10. `TAKEDOWN_RANGE_M = 1.5` registered on phantom_guard.
6. **Synchronicity guarantee** — `receive_damage` mutates `current_alert_state` before return (no `call_deferred`); AC-SAI-1.11 enforces via spy-proxy test.
7. **Body-drop approach vector** (bundled from §V.4 Combat) — captured at terminal-entry as `(attacker.origin - self.origin).with_y(0).normalized()` with degenerate-case fallback per E.23. Serialised in save format. §V animation spec updated.

### Key design decision (user-approved, 2026-04-22)

**MELEE_NONLETHAL (chloroform) takedown → UNCONSCIOUS** (not DEAD). Rationale: chloroform is fictionally non-lethal, symmetric with Combat CR-16's MELEE_FIST non-lethal damage routing. Splits takedown outcomes cleanly: MELEE_NONLETHAL → UNCONSCIOUS, STEALTH_BLADE → DEAD (via Combat CR-15 MELEE_BLADE lethal delegation). Previously both takedown types routed to DEAD; this created fictional inconsistency with CR-16 that the OQ-CD-1 closure resolved.

### Files modified in this session

- `design/gdd/stealth-ai.md` — Status header rewrite + Group A (§C structural + state machine + diagram + transition table + accessors + F.4 filter — 11 edit sites) + Group B (E.16 rewrite + new E.19-E.23) + Group C (AC-SAI-1.3 reversibility matrix + AC-SAI-1.4 chloroform routing + AC-SAI-3.4 6×7 severity matrix + AC-SAI-3.5 force forbid UNCONSCIOUS + AC-SAI-4.3 item 3 + 5 new ACs AC-SAI-1.7 through 1.11 + AC-SAI-3.9 + AC-SAI-3.10 + AC-SAI-5.3) + Group D (§V animation approach-vector spec + §F Combat dep row OQ-CD-1 closed). ~25 edit sites total; file grew 708 → ~800 lines.
- `design/registry/entities.yaml` — `phantom_guard` entry expanded with 5 new attributes (alert_states list updated with UNCONSCIOUS; new takedown_types, terminal_state_routing, public_accessors, receive_damage_contract, takedown_range_m). `last_updated` metadata updated.
- `design/gdd/systems-index.md` — running changelog updated (D.7 below).
- `production/session-state/active.md` — this file.

### Pre-implementation gates still OPEN (for Combat stories)

Not resolved by this session; require their own sessions:

1. **ADR-0002 amendment** — signal signatures in `Events.gd` code block MUST be revised to include `severity: StealthAI.Severity` on the 3 perception signals AND `takedown_performed(actor, attacker, takedown_type)` 3-param form. **Additional scope per OQ-CD-1 item 5**: ADR-0002's accessor-convention section must declare `has_los_to_player()` and `takedown_prompt_active(attacker)` as the SAI-owned public accessors consumed by Combat. Owner: `technical-director` via `/architecture-decision adr-0002-amendment` in a separate session.
2. **Audio GDD re-review** — Audio GDD must pass `/design-review design/gdd/audio.md` with prior gaps closed (trigger-table severity filter + 4-param handler + dual takedown SFX variants + stinger dedupe + dominant-guard idempotence + SCRIPTED-cause handling). Additional 2026-04-22 scope: new `alert_state_changed(_, prev, UNCONSCIOUS, MAJOR)` music cue routing.
3. **Signal Bus GDD touch-up** — enum ownership list must add `StealthAI.Severity` + `StealthAI.TakedownType` + accessor-method declarations. Minor edit; can land as part of ADR-0002 amendment session.

## Status

- ✅ Engine configured: Godot 4.6, GDScript
- ✅ Game concept: `design/gdd/game-concept.md` (The Paris Affair)
- ✅ Art bible complete (9 sections — amendments flagged by Combat GDD, not yet applied)
- ✅ Systems index: 23 + 1 (FootstepComponent) systems
- ✅ ADRs: 6 authored (0001–0006), all Proposed
- ⏳ System GDDs: **10/23 authored** — 5 Approved (PC, FC, SAI [3rd-pass pending re-review], Audio, Level Streaming), 5 Designed/Revised pending review (Signal Bus, Input, Outline, Post-Process, Save/Load, Localization, Combat & Damage 2nd-pass)
- ⏳ Architecture document: not started
- 🔶 **Downstream still blocked**: Inventory & Gadgets (12), Mission & Level Scripting (13), Failure & Respawn (14), Civilian AI (15), HUD Core (16), Document Collection (17), Dialogue & Subtitles (18) — some now unblocked by Combat & Damage + SAI OQ-CD-1 closure

## Next steps (fresh session)

1. **Primary**: `/clear` — this session is done. OQ-CD-1 amendment bundle closure is ~25 edit sites across §C/§D/§E/§H/§V + Status header + registry + session state + systems index.
2. **In fresh session**: Run `/design-review design/gdd/stealth-ai.md` to validate the 3rd-pass revision independently. Lean depth probably sufficient (the amendment scope was specifically gated by OQ-CD-1 spec + user-approved Option A for chloroform routing).
3. **Alternatives** (can happen in parallel with #2 or next):
   - `/design-review design/gdd/combat-damage.md` — Combat 2nd-pass revision still pending independent review.
   - `/consistency-check` — verify no new cross-GDD conflicts from the SAI 3rd-pass revision (particularly: Audio GDD UNCONSCIOUS music cue reference, Save/Load guard serialization schema expansion).
   - `/architecture-decision adr-0002-amendment` — now bundles (a) severity + 4-param takedown_performed; (b) SILENCED_PISTOL → STEALTH_BLADE enum rename; (c) NEW 2026-04-22: has_los_to_player + takedown_prompt_active accessor-convention declaration.
   - `/design-system inventory-gadgets` (system #12) — Combat + SAI both define interfaces Inventory will consume.
   - `/gate-check pre-production` — 10/16 MVP GDDs designed; not yet ready for gate (need 16/16 + ADRs Accepted).

## Open design questions (active)

SAI 3rd-pass revision introduces no new OQs beyond OQ-CD-1 closure. Combat & Damage's 10 OQs (OQ-CD-1 now CLOSED, OQ-CD-2 through OQ-CD-13 still active) remain tracked in combat-damage.md §Open Questions. Previously-tracked deferred items unchanged:
- OQ-SAI-1 through OQ-SAI-8 (SAI GDD §Open Questions) — none affected by OQ-CD-1 closure.
- OQ-2 Fall damage — deferred to VS
- OQ-3 Lean system — deferred, revisit after Stealth AI + first playtest
- OQ-4 Mirror full body mesh — deferred to VS
- OQ-6 Eve verbalizes — deferred, narrative dep
- OQ-FC-2 Noise level sampling timing — deferred, Audio playtest dep
- OQ-FC-3 FC execution order vs PC state — deferred, playtest dep
- OQ-FC-4 Non-player footstep sources — deferred, Stealth AI dep

## Session Extract — /architecture-review 2026-04-22

- **Verdict**: CONCERNS
- **Requirements**: 158 total TRs — ~145 covered, ~10 partial, ~3 hard gaps (all inside pending ADR-0002 amendment scope)
- **New TR-IDs registered**: 158 (initial registry population across 12 authored GDDs, 12 system-slug namespaces: SB/INP/AUD/OUT/PP/SAV/LOC/PC/FC/LS/SAI/CD)
- **GDD revision flags**: player-character.md (CombatSystem→CombatSystemNode rename, 3 sites — already producer-tracked)
- **Top ADR gaps**:
  1. ADR-0002 amendment completion (TransitionReason on section signals + guard_incapacitated/guard_woke_up + enum-ownership list entry; atomic-commit hazard per Specialist §2)
  2. Performance Budget Distribution ADR (SAI pre-impl gate #5; affects 7 systems)
  3. Autoload registration contract (InputContext vs LevelStreamingService load-order-4 collision; editorial hazard per Specialist §1)
- **Cross-ADR conflicts**: 3 🔴 (Conflict 1 autoload collision; Conflict 2 ADR-0002 section signals outdated; Conflict 3 ADR-0002 missing SAI 4th-pass signals)
- **Engine specialist**: godot-specialist YELLOW — 7 targeted spot-checks; 4 additional Risks-row recommendations (ADR-0002 atomicity, ADR-0005 Shader Baker × material_overlay gap elevated, ADR-0006 Jolt Area3D tunneling, ADR-0004 InputContextStack/InputContext discoverability trap)
- **All 6 ADRs still Proposed** — 16 verification gates outstanding across the chain
- **Report**: docs/architecture/architecture-review-2026-04-22.md
- **Traceability index**: docs/architecture/requirements-traceability.md
- **TR registry populated**: docs/architecture/tr-registry.yaml (version 2)

## Session Extract — /architecture-decision amendments A3–A6 2026-04-23

All 4 specialist-recommended amendments from 2026-04-22 applied in-place:

- **A3 — ADR-0003 Gate 3 refined** (L347): scope extended to explicitly exercise `Dictionary[StringName, GuardRecord]` duplicate_deep isolation — outer Dictionary cloned, inner GuardRecord Resources cloned, StringName keys intentionally NOT cloned (identity-preservation per interning is correct). Last Verified bumped to 2026-04-23.
- **A4 — ADR-0004 Implementation Guideline 2 grew addendum**: call sites MUST use autoload key `InputContext.*`; MUST NOT use `class_name InputContextStack.*` (discoverability trap). Mirrors ADR-0002 `CombatSystemNode`/`Combat` split pattern. Last Verified bumped to 2026-04-23.
- **A5 — ADR-0005 Gate 5 added** (after Gate 4): Shader Baker × `material_overlay` compatibility verification in 4.6 export build; moved from Polish to Prototype phase to avoid cascading refactor through every hands-holding weapon pose if baking excludes `material_overlay` slots. Last Verified bumped to 2026-04-23.
- **A6 — ADR-0006 Risks row added**: Jolt `Area3D.body_entered` broadphase tunneling of fast-moving bodies (Combat darts at 20 m/s on LAYER_PROJECTILES); MEDIUM probability / LOW impact; mitigation folded into Combat GDD OQ-CD-2 Jolt prototype scope. Last Verified bumped to 2026-04-23.

**Engine specialist consultation**: no new consultation this pass — all four amendments land verbatim from the 2026-04-22 godot-specialist findings (already GREEN in their original detail). Documented per-amendment references in each Last Verified parenthetical.

**TD-ADR (step 4.6)**: SKIPPED — Solo mode.

**Remaining downstream from 2026-04-23 architecture-review**:
- ❌ Gap 2 (Performance Budget Distribution ADR — still open, cross-cutting 7 systems)
- ❌ Producer-tracked PC GDD `CombatSystem.*` → `CombatSystemNode.*` rename (~10 sites)
- ❌ Audio GDD L188–189 Mission handler table (LS-Gate-3) — 1-param → 2-param branching
- ❌ Input GDD L90 `use_gadget` → dedicated `takedown` action (Combat CR-3 coordination)
- All 6 prior ADRs (0001–0006) and ADR-0007 still Proposed — 17 verification gates outstanding total (now +Gate 5 on ADR-0005)

**Next action (fresh session)**: `/architecture-review` to verify A3–A6 closure and re-assess verdict (expected move: Gap 3 closed by ADR-0007 today, 4 specialist amendments closed today → only Gap 2 + producer-tracked GDD edits remain before PASS becomes achievable).

## Session Extract — /architecture-decision autoload-load-order-registry 2026-04-23

- **ADR written**: `docs/architecture/adr-0007-autoload-load-order-registry.md` (300 lines, Proposed status)
- **Canonical order**: Events (1) → EventLogger (2) → SaveLoad (3) → InputContext (4) → LevelStreamingService (5) → PostProcessStack (6) — all with `*res://` scene-mode prefix
- **Resolves**: /architecture-review Conflict 1 (InputContext vs LSS load-order-4 collision) and Gap 3 (autoload registration contract). PostProcessStack previously-unstated position now explicit at line 6.
- **Specialist validation (step 4.5)**: godot-specialist GREEN/YELLOW/YELLOW across 3 claims. Framing correction for Claim 2 (instantiation vs `_ready()` ordering distinction + `_init()` cross-reference restriction) folded into ADR §Cross-Autoload Reference Safety and §Implementation Guidelines 3–5. Claim 3 hazards (@tool scripts, add_autoload_singleton, Engine.register_singleton) fenced via 2 new forbidden patterns.
- **TD-ADR (step 4.6)**: SKIPPED — Solo mode per `production/review-mode.txt`.
- **Bulk downstream edits (same-PR atomicity per fence design)**: 20+ sites updated across
  - `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — 10 edit sites (Revision History parenthetical, 2 diagrams, header comment, Impl. Guidelines 1+2, Migration Plan, 2 Validation Criteria rows, Related section)
  - `docs/architecture/adr-0003-save-format-contract.md` — 3 edit sites (diagram, comment, Validation Criteria)
  - `docs/architecture/adr-0004-ui-framework.md` — 5 edit sites (Impl. Guideline 2, diagram, comment, Migration Plan, Validation Criteria)
  - `design/gdd/signal-bus.md` — 4 edit sites (Stateless infra, Edge cases, Tuning Knobs row, AC-1)
  - `design/gdd/level-streaming.md` — 1 edit site (CR-1 — includes InputContext→4 / LSS→5 order flip + cross-autoload reference safety note)
- **Registry updates** (`docs/registry/architecture.yaml`): `last_updated: 2026-04-23`; NEW `api_decisions.autoload_registration_order` (pattern: declarative_registry, 7 referenced_by sites); NEW `forbidden_patterns.unregistered_autoload`; NEW `forbidden_patterns.autoload_init_cross_reference`
- **Gate status**: ADR-0007 Proposed → Accepted once (a) project.godot [autoload] block generated matching §Key Interfaces verbatim, (b) ADR-0002 Gate 1 smoke test passes (incidentally validates cross-autoload reference safety)
- **Remaining open from 2026-04-23 review**: Gap 2 (Performance Budget Distribution ADR), A3/A4/A5/A6 (specialist-recommended amendments to ADR-0003/0004/0005/0006), all 6 prior ADRs still Proposed, producer-tracked PC rename (~10 sites), Audio LS-Gate-3 (handler table), Input↔Combat takedown coordination

## Session Extract — /architecture-review 2026-04-23

- **Verdict**: CONCERNS (same as 2026-04-22; scope reduced)
- **Requirements**: 158 total TRs — ~147 covered (+2), ~10 partial, ~1 hard gap (−2: TR-LS-007 + TR-SAI-003 closed by 2026-04-22 4th-pass amendment, verified 2026-04-23)
- **New TR-IDs registered**: None (delta run; no new GDD authorship since prior review)
- **TRs revised**: TR-SB-002 text updated (dropped "pending amendment" qualifier — 4th-pass bundle landed; now reads "36 typed signals..."); revised: 2026-04-23
- **GDD revision flags (carried from 2026-04-22, unchanged)**: player-character.md (CombatSystem→CombatSystemNode rename, 10 sites); audio.md L188–189 §Mission handler table (LS-Gate-3); input.md L90 `use_gadget` split for dedicated takedown action (Combat CR-3)
- **Coverage Gap 1**: ✅ CLOSED — ADR-0002 4th-pass amendment verified in-place (36 signals, section_entered/exited 2-param TransitionReason, guard_incapacitated + guard_woke_up declared, enum-ownership grew, atomic-commit Risks row added)
- **Conflict 2**: ✅ CLOSED (ADR-0002 Key Interfaces now match LS GDD)
- **Conflict 3**: ✅ CLOSED (ADR-0002 Key Interfaces now include SAI 4th-pass signals)
- **Still open**: Conflict 1 (autoload collision), Gap 2 (Performance Budget ADR), Gap 3 (Autoload registration contract), 4 specialist-recommended amendments A3–A6 (ADR-0003 Gate 3 refinement, ADR-0004 addendum, ADR-0005 Gate 5, ADR-0006 Jolt tunneling Risks row), all 6 ADRs still Proposed
- **Cross-ADR conflicts**: 1 🔴 (Conflict 1 autoload collision — editorial, unchanged)
- **Engine specialist**: SKIPPED this run — prior consultation covered the 4th-pass amendment (step 4.5 GREEN post-correction); no new ADRs since. 4 recommendations from 2026-04-22 carry forward unchanged.
- **Priority action list (unchanged ordering)**: Session A resolve Conflict 1/Gap 3; Session B /architecture-decision performance-budget-distribution (Gap 2); Session C apply A3–A6 amendments
- **Report**: docs/architecture/architecture-review-2026-04-23.md
- **Traceability index refreshed**: docs/architecture/requirements-traceability.md (2026-04-23 history entry; TR-LS-007 + TR-SAI-003 + TR-SB-002 status refreshed; Known Gaps section restructured into cross-cutting + coordination + specialist-amendment buckets)
- **TR registry updated**: docs/architecture/tr-registry.yaml (last_updated 2026-04-23; TR-SB-002 revised)

## Session Extract — /architecture-review 2026-04-23 (third run, post-ADR-0008)

- **Verdict**: **PASS** (upgraded from CONCERNS — Gap 2 CLOSED; zero remaining ADR-level architectural gaps)
- **Requirements**: 158 total TRs — ~154 covered (+6), ~3 partial (−6), **0 hard gaps** (−1)
- **New TR-IDs registered**: None (delta run; ADR-0008 consolidates existing per-system claims rather than introducing requirements)
- **TRs revised**: None (all per-system numeric claims preserved verbatim by ADR-0008)
- **GDD revision flags (carried, all unchanged, 4th consecutive review)**: player-character.md (10 sites, CombatSystem→CombatSystemNode rename); audio.md L188–189 §Mission handler table (LS-Gate-3); input.md L90 `use_gadget` → dedicated `takedown` action split
- **Gap 2 (Performance Budget Distribution ADR)**: ✅ CLOSED — ADR-0008 allocates full 16.6 ms across 9 named slots (Rendering 3.8 · Guard systems 6.5 · Post-Process chain 2.5 · Jolt 0.5 · Player/FC/Combat non-GF 0.3 · Audio dispatch 0.3 · UI 0.3 · Pooled residual 0.8 · Reserve 1.6 = 16.6); non-frame budgets consolidated; 4 validation gates pending measurements; 2 new forbidden patterns (unbudgeted_per_frame_ticking, directional_shadow_second_cascade); 1 new api_decision (performance_budget_enforcement)
- **SAI Recommended Follow-up #5** (line 684): ✅ CLOSED by ADR-0008 Slot #2 6.5 ms guard-systems envelope
- **combat-damage.md L233 cross-system reconciliation flag**: ✅ CLOSED by ADR-0008 Slot #2
- **Cross-ADR conflicts**: 0 (no new conflicts from ADR-0008; it is a consolidator — every numeric input matches existing claims verbatim)
- **Engine specialist**: SKIPPED this run — ADR-0008 received its own pre-authoring consultation 2026-04-23 (YELLOW with 3 prose constraints folded in: shadow cascade cap = 1, PostProcessStack cold-boot dominance, D3D12 post-stream 3-frame warm-up; GREEN on Jolt 0.5 ms slot)
- **All 8 ADRs still Proposed** — 21 verification gates outstanding (+4 from ADR-0008 Gates 1–4: Iris Xe reference scene measurement, RTX 2060 informative, D3D12 post-stream warm-up, autoload boot cold-start)
- **Priority action list (updated)**: Session A begin ADR verification gate passes (ADR-0001 Gates 1–3, ADR-0002 Gate 1, ADR-0007 Gate 1); Session B author reference scene + configure CI perf-gate (2 separate tooling stories — prerequisite for ADR-0008 Gates 1–4); Session C parallel producer-owned GDD touch-ups (PC rename + Audio LS-Gate-3 + Input takedown split)
- **`/create-architecture` now eligible** — all 8 ADRs provide stable inputs; recommended after Session A's foundational ADR gates pass
- **Report**: docs/architecture/architecture-review-2026-04-23.md (overwrites second-run 2026-04-23 snapshot)
- **Traceability index refreshed**: docs/architecture/requirements-traceability.md (third-run 2026-04-23 history entry; coverage ~94% → ~99%; Known Gaps section: Gap 2 CLOSED; 0 hard ADR gaps)
- **TR registry**: no edit needed (`last_updated: 2026-04-23` already current; no new TRs, no revisions this run)

## Session Extract — /architecture-review 2026-04-23 (second run, post-ADR-0007 + A3–A6)

- **Verdict**: CONCERNS (scope further reduced — 6 of 7 action items from prior 2026-04-23 run closed)
- **Requirements**: 158 total TRs — ~148 covered (+1), ~9 partial (−1), ~1 hard gap (unchanged — Combat↔Input `takedown` coord)
- **New TR-IDs registered**: None (delta run; ADR-0007 closes scattered infra statements rather than introducing requirements)
- **TRs revised**: None (TR-SB-003 text remains accurate post-ADR-0007; autoload order still "Events=1, EventLogger=2 per project.godot line order" — ADR-0007 codifies the rest of the chain rather than revising TR-SB-003)
- **GDD revision flags (carried, all unchanged)**: player-character.md (10 sites, CombatSystem→CombatSystemNode rename); audio.md L188–189 §Mission handler table (LS-Gate-3); input.md L90 `use_gadget` → dedicated `takedown` action split
- **Conflict 1 (autoload collision)**: ✅ CLOSED — ADR-0007 §Canonical Registration Table pins InputContext=4, LevelStreamingService=5; 20+ downstream "load order N" statements collapsed to "per ADR-0007"
- **Gap 3 (Autoload registration contract)**: ✅ CLOSED — ADR-0007 authored; 2 forbidden patterns registered (unregistered_autoload, autoload_init_cross_reference); Cross-Autoload Reference Safety section codified
- **A3 (ADR-0003 Gate 3 refinement)**: ✅ CLOSED — explicit Dictionary[StringName, GuardRecord] duplicate_deep isolation sub-gates (a/b/c: outer cloned, inner GuardRecord cloned, StringName keys intentionally NOT cloned per interning)
- **A4 (ADR-0004 IG2 addendum)**: ✅ CLOSED — InputContextStack/InputContext split rule with discoverability-trap framing; mirrors CombatSystemNode/Combat pattern
- **A5 (ADR-0005 Gate 5)**: ✅ CLOSED — Shader Baker × material_overlay 4.6 export-build verification, moved Polish → Prototype
- **A6 (ADR-0006 Risks row)**: ✅ CLOSED — Jolt Area3D.body_entered broadphase tunneling for fast bodies (Combat darts 20 m/s on LAYER_PROJECTILES); MEDIUM × LOW; dovetails with Combat OQ-CD-2
- **Still open**: Gap 2 (Performance Budget ADR), 3 GDD-coordination items, all 7 ADRs still Proposed (17 verification gates total — now includes ADR-0007 Gate 1 byte-match + ADR-0005 Gate 5 added by A5)
- **Cross-ADR conflicts**: 0 (was 1 — Conflict 1 resolved)
- **Engine specialist**: SKIPPED this run — ADR-0007 got its own pre-authoring consultation 2026-04-23 (Claims 1/2/3 GREEN/YELLOW/YELLOW, framing corrections + 3 hazards folded in before write); A3–A6 land verbatim from prior specialist findings
- **Priority action list (updated)**: Session A `/architecture-decision performance-budget-distribution` (Gap 2, only remaining ADR-level gap); Session B parallel producer-owned GDD touch-ups (PC rename + Audio LS-Gate-3 + Input takedown split); Session C begin ADR verification gate passes in editor
- **Report**: docs/architecture/architecture-review-2026-04-23.md (overwrites earlier 2026-04-23 snapshot per user Option B)
- **Traceability index refreshed**: docs/architecture/requirements-traceability.md (second-run 2026-04-23 history entry; Known Gaps section: Gap 3 + A3–A6 marked CLOSED; coverage bumped ~93% → ~94%)
- **TR registry**: no edit needed (`last_updated: 2026-04-23` already current; no new TRs, no revisions this run)
