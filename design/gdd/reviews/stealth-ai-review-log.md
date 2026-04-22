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
