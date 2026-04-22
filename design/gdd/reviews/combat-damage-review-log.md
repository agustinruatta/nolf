# Combat & Damage — Design Review Log

Revision history for `design/gdd/combat-damage.md`. Newest entries at the top.

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
