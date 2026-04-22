---
name: Combat & Damage Section C Design Decisions
description: Key design recommendations for Section C (Core Rules, States/Transitions) of combat-damage.md, agreed during 2026-04-21 analysis session
type: project
---

Section C design analysis delivered 2026-04-21. Key positions:

- No ADS on pistol/fists (period-authentic). Rifle is the sole ADS exception (scoped).
- No crosshair in base form; center-dot option via Accessibility only.
- Sprint auto-lowers weapon; cannot fire while sprinting.
- Weapon switch: 0.4 s holster/draw pause (commitment signal, not instant).
- Reload interrupt threshold: matches `interact_damage_cancel_threshold` (≥10 HP aborts reload).
- Headshot: Option (b) — new `DamageType.HEADSHOT` enum variant. Do NOT amend ADR-0002 signal.
- Guard head hitbox: separate named `CollisionShape3D` child ("HeadHitbox") — needs systems-designer Jolt verification.
- Fists: no stun/stagger, 15 HP/hit, 0.8 m range, 1.2 s interval, ~7 hits to kill — genuinely dangerous.
- Ammo scarcity: pistol 24 reserve, darts 4 (exclusive placed pickups), rifle 0 at start (found mid-level).
- Dart gun produces 0 HP damage; guard sedation after 3–4 s delay; KO pose distinct from DEAD.
- Gunfire noise spike: silenced pistol ~3 m, rifle ~18 m (Audio subscribes to `weapon_fired`).

**Why:** Deadpan Witness framing + Pillar 2 (ammo scarcity enforces stealth preference) + Pillar 3 (combat de-escalates) + Pillar 5 (period UX, no hit markers).
**How to apply:** When Section D (Formulas) is authored, use these locked design positions as starting constraints. Flag any formula output that contradicts them.
