# Stealth AI — Review Log

Revision history for `design/gdd/stealth-ai.md`. Each `/design-review` run appends an entry.

---

## Review — 2026-04-21 — Verdict: MAJOR REVISION NEEDED → revised inline

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ai-programmer, audio-director, godot-specialist, performance-analyst, creative-director (senior synthesis)
Blocking items: 19 | Recommended: 25
Prior verdict resolved: First review

### Summary of key findings (creative-director verdict)

> Structural contradictions (propagation/signal contract, formula floors, perception `max()`-rule) must be resolved before this GDD can gate implementation — this is not polish, the system as specified cannot be built consistently. Pillar 3 (Theatre): fixable, not delivered today — single-landing-to-COMBAT and signal-blast both convert theatre into punishment. Pillar 1 (Comedy): at risk — forward-gating 100 % of comedy to Dialogue is legitimate, but Stealth AI owes Dialogue a minimum-viable-comedy surface. Bones are right; what's broken is the signal contract and formula edges.

### Blockers (all resolved inline in this session)

1. Propagation chain — F.4 one-hop invariant contradicts the state-transition table unconditional `actor_became_alerted` emission
2. `alert_state_changed` also leaks on propagation-induced transitions — Mission Scripting subscribes
3. Signal blast — every casual SUSPICIOUS investigation triggers brass-punch stinger → Pillar 1 comedy dies
4. F.2b single LANDING_HARD → instant COMBAT (adds 1.11 to accumulator, crosses T_COMBAT in one event)
5. F.5 declares "accumulators cap at 1.0" but F.2a/F.2b add-steps contain no clamp
6. F.1 `silhouette_factor` variable table [0.2, 1.0] contradicts formula floor clamp(..., 0.5, 1.0)
7. Perception `max(_sight, _sound) >= T` ignores combined sub-threshold cues (combinatorial blindspot)
8. Godot 4.6 has no `ConeShape3D` — VisionCone shape implementation path unspecified
9. Area3D `mask = MASK_PLAYER | MASK_AI_VISION_OCCLUDERS` fires `body_entered` on world geometry
10. DEAD state doesn't explicitly disable VisionCone `monitoring` or HearingPoller `_physics_process`
11. NavigationAgent3D.target_position has no debounce rule (10 Hz LKP → 10 re-paths/sec)
12. Global alert aggregation ownership unacknowledged in Stealth AI's Interactions table
13. Simultaneous multi-guard stinger salvo has no debounce owner
14. `takedown_performed(actor, target)` signal doesn't carry `TakedownType`
15. `force_alert_state` emission behavior unspecified
16. AC-SAI-1.3 "12 transitions" count wrong (5 states yield 16 directed non-terminal edges)
17. AC-SAI-4.1 "progresses" ambiguous (terminal-state-only test passes trivially)
18. AC-SAI-5.1 missing `search_timeout_remaining` field
19. AC-SAI-4.3 subjective sign-off with no checklist

### Resolution approach (Option C + user decisions)

User selected in AskUserQuestion multi-tab:
- **Signal contract**: Severity field `{MINOR, MAJOR}` on 3 AI signals + `takedown_type` on takedown_performed
- **Spike cap**: F.2b one-shot contribution ≤ `T_SEARCHING − 0.01 = 0.59`
- **Channel combine**: Weighted blend `combined = max(s,n) + 0.5 × min(s,n)`
- **VisionCone shape**: SphereShape3D + dot-product angle filter in `body_entered`

Creative-director addition accepted: `CURIOSITY_BAIT` AlertCause + `SUSPICION_DWELL_FLOOR_SEC = 3.0 s` for player-initiated comedy triggers (knock vase, whistle).

### Follow-up required

- **ADR-0002 signature update**: the 3 AI signals (`alert_state_changed`, `actor_became_alerted`, `actor_lost_target`) need a `severity: StealthAI.Severity` parameter appended; `takedown_performed` needs `takedown_type: StealthAI.TakedownType` appended. Must be reflected in ADR-0002 before implementation.
- **Audio GDD**: subscription filter `if severity == MAJOR: play_stinger` must be documented on re-review of audio.md.
- **Re-review**: user elected "Re-review in a new session" — run `/design-review design/gdd/stealth-ai.md` after `/clear` to verify the revision does not introduce new contradictions.

### File size

- Before revision: 606 lines
- After revision: 668 lines (+62, +10 %)

### Artifacts touched

- `design/gdd/stealth-ai.md` (this GDD)
- `design/gdd/systems-index.md` (status row updated to Revised)
- `design/gdd/reviews/stealth-ai-review-log.md` (this log — new file)

---

## Review — 2026-04-21 (2nd pass) — Verdict: MAJOR REVISION NEEDED → revised inline → user accepted without re-review

Scope signal: L
Specialists: ai-programmer, game-designer, systems-designer, qa-lead, audio-director, godot-specialist, performance-analyst, creative-director (senior synthesis)
Blocking items: 21 | Recommended: 23 | Nice-to-have: several
Prior verdict resolved: Yes — all 19 blockers from 1st review confirmed resolved. BUT the 1st-pass revision introduced 21 NEW blockers (revision-introduces-regressions antipattern — creative-director explicitly flagged this).

### Summary of key findings (creative-director verdict)

> The prior revision resolved the structural contradictions it was asked to resolve, but the fixes introduced a new generation of contradictions — signal-contract split-brain (GDD vs ADR-0002 vs Audio GDD), a literally-unreachable sight path for dead bodies, and a "sound can't reach COMBAT" claim that is arithmetically false. The bones remain sound (reversibility, graduated suspicion, channel independence with combined score); the connective tissue needs another pass.

### Convergent blockers (cited by ≥2 specialists — high confidence)

1. **ADR-0002 signal signatures stale** (ai-programmer B-5, qa-lead B-1, audio-director B1, godot-specialist B-5). AC-SAI-3.3 static-grep fails on day 1.
2. **SAW_BODY physically unreachable** (ai-programmer B-1, godot-specialist B-4). VisionCone `mask = MASK_PLAYER` excludes LAYER_AI dead guards.
3. **"Sound alone cannot cross T_COMBAT" arithmetically false** (ai-programmer B-3, systems-designer B-2). F.2a continuous uncapped; Sprint+metal_grate saturates `_sound` to 1.0.

### Blockers (all resolved inline in this 2nd revision pass)

See `design/gdd/stealth-ai.md` status-line header for full list. Summary of the 21:
- B1 ADR-0002 stale — escalated to pre-implementation gate; AC-SAI-3.3 marked BLOCKED until ADR amended.
- B2 SAW_BODY mask — `mask = MASK_PLAYER \| MASK_AI` + group + typed-class filter (user chose option a).
- B3 T_COMBAT claim — deleted; SEARCHING→COMBAT now uses `combined >= T_COMBAT` matching general rule (user chose option b).
- B4 `_compute_severity` DEAD — added to MAJOR branch.
- B5 F.1 movement_factor DEAD — added `DEAD = 0.0`.
- B6 F.1 at d=0 — zero-distance short-circuit + E.18.
- B7 Forward axis — `-global_transform.basis.z`.
- B8 Downward tilt — `.rotated(basis.x, -deg_to_rad(VISION_CONE_DOWNWARD_ANGLE_DEG))`.
- B9 `body: Node3D` typing.
- B10 `target_position = global_position` race — AC-SAI-1.4 checks `target_position ==` synchronously + next-frame `is_navigation_finished`.
- B11 AC-SAI-2.1 factor coverage — 15 combos → 25 rows covering all 6 F.1 factors.
- B12 AC-SAI-2.5 trivial — added Scenario B (fresh stimulus to G2 DOES propagate to G3).
- B13 AC-SAI-4.3 item 2 — narrowed to SUSPICIOUS→UNAWARE only.
- B14 AC-SAI-3.4 `_compute_severity` matrix — new AC.
- B15 AC-SAI-3.5 `force_alert_state` — new AC.
- B16 AC-SAI-3.6 SAW_BODY 2× — new AC.
- B17 CURIOSITY_BAIT gameable — `SUSPICION_DWELL_FLOOR_SEC` REMOVED from state machine; comedy-mutter timing moved to Dialogue non-preemptive vocal scheduling (user chose option a).
- B18 COMBAT recovery punishment cadence — added pacing-arc spec (t+0 to t+24s vocal/music beats).
- B19 Perf budget 72% mean-only — split into overall 6 ms + P95/P99/max + perception/nav/signals sub-budgets (user chose option a).
- B20 Raycast F.1+F.2a redundancy — implementation note: cache and reuse same-frame.
- B21 HearingPoller burst — `get_instance_id() % 6` tick-counter stagger.

### Advisories landed in the same pass (selected)

- F.4 propagation: SCRIPTED cause added to exclusion list (was prose-only; now formal).
- `CIVILIAN_PROPAGATION_BUMP` named constant replaces bare 0.5 in E.9.
- Repath knobs declared const + `assert()` at `_ready()`.
- New E.17 (SAW_BODY mid-sweep) + E.18 (Eve inside guard's eye) edge cases.
- `body_exited` handler early-return when `current_alert_state == DEAD` documented.
- `material_overlay` (not `material_override`) constraint for guard MeshInstance3D.
- OQ-SAI-7 per-section tuning elevated to pre-Mission-Scripting decision.
- PC-side NoiseEvent canonical-reference lifetime contract added to bidirectional deps.
- Save-format spec ↔ AC-SAI-5.1 field-list reconciled (serialised: `search_timeout_remaining`, `combat_lost_target_remaining`, `_lkp_has_sight_confirm` added; non-serialised list also documented).
- AC-SAI-3.7 spike-cap boundary at `_sound = 0.58` + spike (was missing).
- AC-SAI-3.8 normal-play 5-Hz signal-frequency sanity check (complements AC-SAI-3.2 30-Hz pathological ceiling).

### Follow-up required (pre-implementation gates — remain OPEN, outside this GDD)

- **ADR-0002 amendment** — signatures in `Events.gd` code block must add `severity: StealthAI.Severity` to the 3 perception signals and adopt `takedown_performed(actor, attacker, takedown_type)`. Owner: technical-director via `/architecture-decision adr-0002-amendment`.
- **Audio GDD re-review** — 6 gaps: stinger severity filter; handler signatures; `takedown_type` SFX branching; stinger debounce policy; dominant-guard dict idempotence on same-state transitions; SCRIPTED-cause stinger handling documented. Owner: audio-director via `/design-review design/gdd/audio.md`.
- **Signal Bus GDD touch-up** — enum ownership list adds `StealthAI.Severity` + `StealthAI.TakedownType`; domain table rows reflect 4-param signatures. Minor edit, can land with the ADR-0002 amendment.
- **Performance-budget-distribution ADR (recommended)** — the 6 ms Stealth-AI commitment implies constraints on Outline Pipeline, Rendering, Combat, Civilian AI, UI that need cross-system agreement via `/architecture-decision performance-budget-distribution`.

### Resolution approach — user accepted without re-review

User elected "Accept revisions and mark Approved — skip re-review" at the post-revision closing widget. Creative-director had recommended a fresh-session `/design-review` pass given the prior revision produced 21 fresh blockers. Risk acknowledged: if this 2nd-pass revision itself introduced regressions (pattern repeats), they will be caught during implementation or at `/story-readiness` gates rather than at design-review time. Mitigation: the 4 pre-implementation gates above act as a secondary correctness check before any story exercises stealth-AI code.

### File size

- Before 2nd revision: 668 lines
- After 2nd revision: 708 lines (+40, +6 %)

### Artifacts touched

- `design/gdd/stealth-ai.md` (this GDD — 21 blockers + 15+ advisories resolved)
- `design/gdd/systems-index.md` (System 10 row → Approved 2026-04-21; header status line updated)
- `design/gdd/reviews/stealth-ai-review-log.md` (this log — 2nd-pass entry)

---

## Review — 2026-04-22 (3rd pass, OQ-CD-1 amendment bundle + 4th-pass revision) — Verdict: MAJOR REVISION NEEDED → revised inline → user accepted without re-review

Scope signal: L
Specialists: ai-programmer, systems-designer, qa-lead, game-designer, godot-specialist, performance-analyst, audio-director, creative-director (senior synthesis)
Blocking items: 23 | Recommended: 22+ | Nice-to-have: several
Prior verdict resolved: Yes — 2nd-pass 21 blockers confirmed resolved. BUT the 3rd-pass OQ-CD-1 amendment bundle (UNCONSCIOUS state + receive_damage return contract + TakedownType enum + public accessors + synchronicity + approach-vector capture) introduced 23 NEW blockers (revision-introduces-regressions antipattern explicitly flagged by creative-director for the 2nd time).

### Summary of key findings (creative-director REJECT synthesis)

> **REJECT.** The 3rd pass was correctly scoped to OQ-CD-1 closure, but 23 blockers — including falsifiable math errors (F.1 max 5.4 vs 6.0, F.2b single-spike arithmetic), a tonally-incoherent player choice (UNCONSCIOUS false-choice + Transitional execution edge), a specialist contradiction (godot-specialist vs ai-programmer on `monitoring = false` behavior), and audio-gate scope gaps — does not meet the bar for any re-review. **The revision-introduces-regressions antipattern is continuing** with reduced blast radius but unchanged ratio per amendment. Two blockers (UNCONSCIOUS false-choice + Transitional edge) are pillar-level violations — no textual cleanup fixes a feature that lies to the player about its own tone. Procedural fix required: Pass 4 must add a mandatory "touch-map" step (trace every amendment through all 8 sections) and a formula re-verification checklist (inline worked boundary tables).

### Convergent blockers (cited by ≥2 specialists)

1. **`monitoring = false` factual claim** (godot-specialist B-1 vs ai-programmer B-1) — DIRECT SPECIALIST DISAGREEMENT. CD adjudication: godot-specialist correct (body_exited does NOT fire on toggle per Godot 4.x). Underlying ai-programmer concern resolved via new `guard_incapacitated(guard)` unregistration protocol.
2. **AC-SAI-4.4 + AC-SAI-3.9 unimplementable ACs** (godot-specialist B-2, qa-lead B-3 + B-5) — `PhysicsDirectSpaceState3D.intersect_ray` cannot be monkey-patched; GUT cannot isolate per-subsystem frame time. Resolved via RaycastProvider DI interface + custom profiling harness.
3. **UNCONSCIOUS false-choice** (game-designer B-1) — functionally identical to DEAD ship state. User-approved resolution: add wake-up clock mechanism (WAKE_UP_SEC = 45 s).

### Blockers (all resolved inline in this 4th-pass revision)

**Pillar-level (2):**
- B1 UNCONSCIOUS false-choice [game-designer] → wake-up mechanism added (user-approved option B).
- B2 Transitional UNCONSCIOUS → DEAD tonal incoherence [game-designer] → PRESERVED per user override ("Change so people can die. It's OK, it's just a game") — user accepted tonal cost; now load-bearing counterplay against wake-up.

**Factual / arithmetic (3):**
- B3 F.1 max 5.4 vs 6.0 [systems-designer] → corrected; worked math inlined; timing 0.37 s → 0.33 s.
- B4 F.2b single-spike impossibility claim [systems-designer] → scoped to "with zero prior sight" + combined-score edge case documented.
- B5 AC-SAI-1.3 edge count 18 vs 17 [ai-programmer R-3] → corrected to 19 with wake-up edge.

**Godot API / implementability (4):**
- B6 `monitoring = false` rationale wrong [godot-specialist] → corrected; new `guard_incapacitated` unregistration protocol.
- B7 `_perception_cache` undeclared [ai-programmer] → struct spec inline in F.1.
- B8 `takedown_prompt_active` boundary ambiguity [ai-programmer] → `dot ≤ 0 = rear` inclusive + zero-distance guard.
- B9 F.4 UNCONSCIOUS/DEAD as propagation source [ai-programmer] → formal invariant + debug assert.

**Spec gaps (2):**
- B10 Save-format split-brain [ai-programmer] → §Interactions row reconciled with §Death-and-save-state (+wake-up fields).
- B11 E.16 signal interleaving unspecified [ai-programmer] → explicit 9-step ordering + subscriber state-visibility guarantee.

**QA / testability (5):**
- B12 AC-SAI-1.7 missing FALL_OUT_OF_BOUNDS [qa-lead] → rows 5 → 7 (adds BULLET/MELEE_BLADE/FALL_OUT_OF_BOUNDS lethal + DART/FIST non-lethal).
- B13 AC-SAI-1.3 SCRIPTED-path coverage [qa-lead] → force_alert_state forbidden edges parametrized.
- B14 AC-SAI-1.11 spy-proxy implementability [qa-lead] → pre-connect-lambda pattern replaces spy-proxy.
- B15 AC-SAI-3.3 skip() no gate [qa-lead] → producer-tracked named sprint item "SAI-ADR-0002-Amendment" + `pending()` marker + merge gate.
- B16 AC-SAI-4.4 GUT cannot isolate sub-budgets [qa-lead] → custom profiling harness spec + 4 test env pins (Jolt physics backend, Plaza NavMesh baseline, 3 dead guards spawned, min-spec CPU).

**Raycast DI (1):**
- B17 AC-SAI-3.9 raycast monkey-patch [godot-specialist] → `IRaycastProvider` DI interface declared in F.1 + `CountingRaycastProvider` test double; AC rewritten.

**Performance budget (2):**
- B18 Dead-body raycasts unbudgeted [performance-analyst] → budget re-derived; worst case 4 raycasts/guard (Eve + 3 corpses) = 48 raycasts/frame documented.
- B19 Geometry complexity assumption [performance-analyst] → Plaza NavMesh pinned as perf baseline; test env pin in AC-SAI-4.4.

**Audio integration (4):**
- B20 UNCONSCIOUS music state routing [audio-director] → Audio gate item (g) added.
- B21 UNCONSCIOUS → DEAD transitional music + SFX conditional [audio-director] → Audio gate item (h) + prone-variant `enemy_killed` SFX.
- B22 Damage-path UNCONSCIOUS chloroform SFX suppression [audio-director] → Audio gate item (i).
- B23 Audio gate scope incomplete [audio-director] → expanded 6 → 10 items; new `guard_woke_up` signal + wake music cue + ambient breathing item (j).

### Recommended items resolved (selected — 15+ of 22)

- body_factor for UNCONSCIOUS vs DEAD [ai-programmer R-1] → body_factor decay 2.0→1.0 across wake window differentiates.
- E.20 approach_vector visual artifact [ai-programmer R-2] → flagged as known MVP compromise; upgrade deferred to VS.
- receive_damage on DEAD no-HP-mutation [ai-programmer R-4] → AC-SAI-1.7(e) asserts explicitly.
- `TAKEDOWN_RANGE_M` to Tuning Knobs [ai-programmer R-5] → added (+`WAKE_UP_SEC`, `CORPSE_MOVEMENT_FACTOR`).
- has_los_to_player cold-start 1-frame latency [ai-programmer R-6] → documented as accepted behaviour.
- movement_factor for dead guard target [systems-designer R-1] → `CORPSE_MOVEMENT_FACTOR = 0.3` declared.
- F.4 `PROPAGATION_BUMP` safe-range gap [systems-designer R-2] → narrowed to [0.41, 0.6] to enforce invariant.
- receive_damage negative/overkill contract [systems-designer R-3] — partially addressed in Combat dep row (amount type + routing is type-based).
- AC-SAI-3.9 mid-destruction case [qa-lead R-1] → scenario (e) added.
- AC-SAI-3.10 all-negative multi-dim [qa-lead R-2] → scenario (g) added.
- AC-SAI-5.3(c) takedown_type + terminal_cause schema distinctness [qa-lead R-3] → explicit assertion + load-bearing note.
- AC-SAI-4.3 Item 3 subjective measurement [qa-lead R-4] → objective video-capture + automated animation-player assertion.
- AC-SAI-4.3 Item 8 self-report hedge [qa-lead R-5] → 3-tier verdict with audit trail.
- Missing AC terminal_cause enum [qa-lead R-6] → AC-SAI-1.13 NEW.
- Missing AC approach_vector E.23 [qa-lead R-7] → AC-SAI-1.14 NEW.
- CURIOSITY_BAIT visual timing [game-designer R-1] → OQ-SAI-10 added.
- Takedown UX diegetic cue ownership [game-designer R-2] → Combat GDD forward-dep strengthened as gate item (4).
- 24 s COMBAT recovery foreclosed timer-shorten [game-designer R-3] → restored as secondary fix in `SEARCH_TIMEOUT_SEC` knob note.
- One-hop propagation 3+-guard rooms [game-designer R-4] → OQ-SAI-9 added.
- Jolt pinning in perf test [godot-specialist R-1] → test env pin in AC-SAI-4.4.
- NavigationServer3D async unspecified [performance-analyst R-1] → async asserted + forbidden-pattern grep in AC-SAI-3.12.
- Max-spike vsync-drop [performance-analyst R-2] → documented as accepted in AC-4.4.a.
- Signal dispatch boundary [performance-analyst R-3] → subscriber handler cost excluded from SAI sub-budget.

### Nice-to-have landed

- `dead_guard` group unification test — AC-SAI-3.11 NEW.
- Forbidden-pattern grep (`player_footstep`, `NavigationServer3D.map_get_path`, `call_deferred`) — AC-SAI-3.12 NEW.

### Resolution approach — user accepted without re-review (3rd consecutive acceptance-without-re-review)

User elected "Accept revisions and mark Approved — skip re-review" at the post-revision closing widget. CD had recommended fresh-session `/design-review` pass given the 3rd pass produced 23 fresh blockers and this is the 3rd consecutive GDD acceptance without a fresh re-review (pattern flagged at each prior pass). Risk acknowledged: if this 4th-pass revision itself introduced regressions (pattern repeats), they will be caught during implementation or at `/story-readiness` gates rather than at design-review time. Mitigation: the 5 pre-implementation gates above act as a secondary correctness check before any story exercises stealth-AI code.

### Key design decisions (user-approved)

1. **UNCONSCIOUS + wake-up clock** (not remove-chloroform) — keeps non-lethal gameplay option; adds mechanical consequence. `WAKE_UP_SEC = 45 s` safe range 30-60.
2. **Transitional UNCONSCIOUS → DEAD preserved** — user override on CD tonal concern; player-choice that "some people die" accepted as project tone.
3. **RaycastProvider DI interface** — coding-standards-compliant DI over singletons.
4. **Combat owns Takedown UX cue** — forward-dep strengthened; Combat GDD spec authoritative.

### File size

- Before 4th revision: 786 lines
- After 4th revision: 924 lines (+138, +17%)

### Artifacts touched

- `design/gdd/stealth-ai.md` (this GDD — 23 blockers + 15+ recommended resolved, 5 new ACs, 2 new OQs, wake-up mechanism added, RaycastProvider DI declared, signal catalog expanded by 2)
- `design/gdd/systems-index.md` (Row 10 rewritten → Approved 2026-04-22 4th pass; header status line updated with running changelog entry; orphaned 10-OLD row cleaned up)
- `design/gdd/reviews/stealth-ai-review-log.md` (this log — 4th-pass entry)
- `production/session-state/active.md` (to be updated on session close)
