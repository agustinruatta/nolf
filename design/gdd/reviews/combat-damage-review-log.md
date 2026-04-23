# Combat & Damage — Design Review Log

Revision history for `design/gdd/combat-damage.md`. Newest entries at the top.

---

## Review — 2026-04-22 — Verdict: MAJOR REVISION NEEDED → ACCEPTED after inline revision pass (second pass)

Scope signal: XL (creative-director assessment — multi-GDD coordination continues; structural rethinks to UNCONSCIOUS semantics, blade input, fists mechanic, economy model, accessibility pillar boundary)
Specialists: game-designer, systems-designer, ai-programmer, economy-designer, qa-lead, godot-specialist, ux-designer, creative-director (senior synthesis)
Blocking items: 34 | Recommended: 22 | NITs: ~10

### Summary

Second-pass /design-review produced MAJOR REVISION NEEDED after six specialists converged independently on structural failures the 2026-04-21 inline revision had introduced or left unresolved. CD senior synthesis collapsed 50+ surface defects into five structural root causes:

- **Root Cause A — Broken revision propagation**: 2026-04-21 numeric changes (reserves, crosshair px, DamageType enum, dart-wall prose) not propagated to downstream AC / edge-case sites. 4 specialists flagged AC-CD-12.1 alone.
- **Root Cause B — Phantom APIs**: `ProjectileManager`, `guard.has_los_to_player`, `tests/.blocked-tests.md` manifest, `SignalRecorder.gd`, `WarningCapture.gd`, and "cone-shaped ShapeCast3D" (no ConeShape3D in Godot 4.6) all referenced as if they existed.
- **Root Cause C — UNCONSCIOUS state underspecified**: CR-16 "identical to DEAD" contradicted AC-CD-7.1's `enemy_killed` suppression; E.1 and E.3 mutually contradictory on DEAD/UNCONSCIOUS gating.
- **Root Cause D — Pillar-boundary erosion via exception carve-outs**: Pillar 1 invocation for fists contradicted §V.8 Matt Helm anti-pattern; Design Test "Neither" row defeated its own discriminating logic; blade input ambiguity deferred to Inventory forward-dep.
- **Root Cause E — Economy narrative false**: "dry by Section 4–5" was actually mid-Section 3; guards net ammo-positive for Aggressive; Ghost margin claims contradicted by 80% pickup math.

### Resolution (inline revision pass, same session)

User elected Option [A] "Revise now." Four structural decisions gathered via multi-tab widget:
1. **UNCONSCIOUS semantics**: Transitional model — dart → UNCONSCIOUS (is_dead=false, no enemy_killed); lethal re-hit → DEAD + enemy_killed; re-dart on UNCONSCIOUS = no-op. `DamageType` now classified via `is_lethal_damage_type()` helper; `MELEE_FIST` reclassified non-lethal.
2. **Blade vs pistol input**: Dedicated `Takedown` input (kbd F / gamepad Y). Fire always pistol; Takedown always blade. No modal ambiguity at the takedown moment.
3. **Fists role**: Reworked per user direction — `fist_base_damage 16 → 40`, safe range `[34, 50]`, 3-swing / 2.1 s KO. Viable deliberate silent non-lethal KO AND ammo-dry fallback. No Pillar 1 carve-out; §V.8 Matt Helm anti-pattern primary.
4. **Economy**: NOLF1-authentic — `guard_drop_pistol_rounds 8 → 3` (break-even on paper, net-negative after real-play friction). Pillar 2 depletion restored.

Plus 30+ smaller fixes: revision-propagation stale values, phantom-API removals (ProjectileManager self-subscription; SAI LOS/prompt accessors added to OQ-CD-1), Godot API corrections (multi-RID self-exclusion, dart `area_entered` handler, wall-spawn pre-check, SphereShape3D sweep, CR-14 synchronous-in-handler reset), AC corrections (stale reserves, stale enum lists, pixel-sampling protocols for visual ACs), accessibility compliance (photosensitivity 3 Hz rate-gate, resolution-independent crosshair, tri-band halo for contrast, 4-quadrant Enhanced Hit Feedback model).

GDD grew 1,420 → 1,564 lines. User elected to Accept revisions without fresh re-review (context-heavy session; CD recommended fresh session but user proceeded).

### Pre-implementation gates OPEN

- **OQ-CD-1 — SAI amendment (expanded 2026-04-22)**: 6 items: UNCONSCIOUS state, `receive_damage -> bool`, `is_lethal_damage_type` helper consumption, takedown-type rename (STEALTH_BLADE), NEW public accessors (`has_los_to_player`, `takedown_prompt_active`), synchronicity guarantee on state mutation. Owner: user via `/design-system stealth-ai`. 1.5 session effort.
- **OQ-CD-2 — Jolt prototype (3 items)**: intersect_ray + bone-Area3D; BoneAttachment3D pose lag (mitigation path specified); RigidBody3D CCD under Jolt. Owner: godot-specialist via `prototypes/guard-combat-prototype/`. ~60 min.
- **OQ-CD-12 — Settings & Accessibility forward deps (9 contracts)**: expanded from 5.
- **OQ-CD-13 — Pillar 5 Boundary Clarification doc**: NOW BLOCKING for HUD State Signaling / Document Overlay / Menu / Settings & Accessibility GDD authoring. Does not block Combat approval. Owner: creative-director, 1 session.
- **ADR-0002 amendment coordination**: type rename `CombatSystem → CombatSystemNode` affects PC-Approved + Audio-Approved frozen signatures. Producer sequences the landing.
- **`/test-setup` sprint gate (AC-CD-19)**: SignalRecorder + WarningCapture + `.blocked-tests.md` manifest must exist before stories consuming AC-CD-1/2/4/6/7/9/11/12/13.3/15/18 enter sprints.

### Pre-implementation gates CLOSED (by this revision)

- UNCONSCIOUS semantics fully resolved (Transitional model; E.1/E.3/CR-16/AC-CD-7.1 aligned).
- Blade vs pistol input ambiguity closed (dedicated Takedown input).
- Fists Composed-Removal failure resolved (3-swing deliberate KO).
- §V.8 Matt Helm anti-pattern restored as primary Pillar 1 boundary.
- Design Test "Neither" escape hatch removed.
- Economy Pillar 2 depletion pressure restored via NOLF1 drop rates.
- All phantom APIs either specified (LOS + takedown-prompt accessors declared in OQ-CD-1) or removed (ProjectileManager → per-dart self-subscription).
- Guard self-headshot vector closed (multi-RID exclusion).
- Dart graze-headshot silent failure closed (dual-signal handler).
- Dart wall-spawn silent failure closed (pre-fire occlusion check).
- Photosensitivity WCAG 2.3.1 compliance landed (333 ms inter-flash cooldown).
- Crosshair resolution independence + tri-band halo contrast.
- F.1 output_range + F.3 median deviation + AC-CD-9.2 assertion math corrected.

Prior verdict resolved: 2026-04-21 MAJOR REVISION NEEDED → accepted-inline was premature; this second pass rebuilt the structural foundation that the first inline pass transposed rather than resolved.

---

## Review — 2026-04-21 — Verdict: MAJOR REVISION NEEDED → ACCEPTED after inline revision pass

Scope signal: XL (creative-director assessment — multi-GDD coordination, structural rethinks, Pillar 5 boundary clarification)
Specialists: game-designer, systems-designer, ai-programmer, economy-designer, qa-lead, godot-specialist, ux-designer, creative-director (senior synthesis)
Blocking items: 25+ | Recommended: 20+ | NITs: ~10

### Summary

First-pass /design-review produced a MAJOR REVISION NEEDED verdict. Six specialists converged independently on overlapping structural failures — strongest signal that the issues were real. Creative-director senior synthesis collapsed 25+ blockers into 5 structural failures:

- **Issue A** — Fists at 4.9s / 7 swings embody the anti-pillar (Matt Helm slapstick, GDD's own cautionary reference). No tuning in safe range fixes it.
- **Issue B** — Silenced pistol had two incompatible identities (1-shot takedown / 3-shot gunfight) with no diegetic signal — player mental model incoherent.
- **Issue C** — Cross-domain contracts silently imposed on Approved Stealth AI GDD (E.24 timer-stop, CR-12 state ownership, E.26 post-cap behavior) — violated Coordination Rule 5.
- **Issue D** — Dart economy had a fist-KO farm loop (cost 0 darts, yielded 1) + assumed 100% pickup rate.
- **Issue E** — Pillar 5 weaponized selectively creating an accessibility barrier for hearing-impaired players; also used as post-hoc rationalization for the crosshair.

### Resolution (inline revision pass, same session)

User elected option [A] "Revise now — address blockers together." Four structural decisions gathered via multi-tab widget:
1. **Fists**: keep mechanically as rare edge-case fallback, raise ammo generosity so fists seldom needed. Added §B weapon-register table + fists carve-out; Pillar 1 comedy alignment for when fists ARE used.
2. **Pistol**: split into silenced pistol (gunfight-only, 3-shot TTK) + NEW takedown blade (stealth 1-shot). Removed dual-identity entirely. Inventory forward dep authors blade Resource.
3. **Crosshair**: accessibility-first rationale + 1 px Parchment halo contrast ring. Dropped "period-scope reticle" rationalization. Dual discovery path (Accessibility + HUD menus).
4. **SAI contract**: Combat defensive internally via `GuardFireController` with its own state enum. OQ-CD-1 trimmed to only UNCONSCIOUS + `receive_damage -> bool`. Blade takedown-type enum addition bundled into minimal SAI amendment.

Creative-director ruled: **Pillar 5 governs diegetic period fiction, NOT accessibility scaffolding.** Precedent cited: Celeste's Assist Mode. Ruling applied as new Enhanced Hit Feedback opt-in toggle (UI-5 carve-out, V.6 5th register) + colorblind-safe secondary cue + configurable flash duration. Separate Pillar 5 Boundary Clarification doc flagged as OQ-CD-13 for follow-up.

Plus mechanical fixes: Godot API blockers (`collide_with_areas=true`, `respawn_triggered` replaces phantom `section_exited(reason)`, `class_name CombatSystemNode` resolves autoload collision, dart wall-hit filter), systems invariants (AC-CD-8.5 falloff invariant, AC-CD-14.1 reconciled with tightened safe range [14,20], F.1 output floor fix 13 not 16), AC testability (SignalRecorder + WarningCapture helpers, `gut.simulate()` time advancement, AC-CD-13.4 rewritten with fixture override, AC-CD-16.1/2 gained `@blocked` annotations, `.blocked-tests.md` manifest enforcement), UX accessibility (colorblind bold-weight secondary cue, flash duration knob, UI-2 fists transition shows `— / —`, ADS motion-sensitivity forward dep).

GDD grew 1,179 → 1,418 lines. User elected to Accept revisions without fresh re-review (context-heavy session).

### Pre-implementation gates OPEN

- **OQ-CD-1** — SAI amendment (UNCONSCIOUS AlertState + `receive_damage -> bool` return + STEALTH_BLADE takedown type enum). Owner: user via `/design-system stealth-ai` revision. 1 session.
- **OQ-CD-2** — Jolt physics prototype (EXPANDED SCOPE: Area3D + BoneAttachment3D + intersect_ray; pose-lag in _physics_process vs _process; RigidBody3D CCD under Jolt). Owner: godot-specialist via `prototypes/guard-combat-prototype/`. ~60 minutes.
- **OQ-CD-12** — Settings & Accessibility GDD forward deps (5 contracts: crosshair toggle dual-surface, Enhanced Hit Feedback toggle, Damage Flash Duration slider, potential ADS tween multiplier).
- **ADR-0002 amendment** — `CombatSystem` → `CombatSystemNode` in signal signatures + add `MELEE_BLADE` to `DamageType` enum.

### Pre-implementation gates CLOSED by this revision

- Fist-KO dart farm loop closed via `guard_drop_dart_on_fist_ko = 0`.
- SAI cross-domain contract violations removed (Combat defensive internally).
- Pillar 5 accessibility barrier resolved via opt-in Enhanced Hit Feedback + colorblind-safe secondary cues.
- Pistol dual-identity resolved via weapon split.
- Respawn floor scope ambiguity resolved (TOTAL, with per-checkpoint anti-farm flag).

Prior verdict resolved: First review (no prior).

---
