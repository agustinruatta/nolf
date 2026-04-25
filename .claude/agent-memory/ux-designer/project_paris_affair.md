---
name: Project Context — The Paris Affair
description: Core concept, pillars, HUD philosophy, and locked upstream contracts relevant to UX design work on system #16 (HUD Core)
type: project
---

Single-player stealth-FPS spiritual successor to NOLF1 (2000). Eve Sterling, 1960s BQA agent, Eiffel Tower mission. Tone: dry comedy via Get Smart / Our Man Flint. Engine: Godot 4.6, GDScript, Forward+ Mobile at 1080p × 0.75 effective on Iris Xe Gen 12.

**Why:** Pillar 5 (Period Authenticity Over Modernization) is the load-bearing UX pillar. Every HUD rule descends from NOLF1's register and the 1965 spy-comedy fiction. Modern UX conveniences (waypoints, minimap, kill cams, objective markers, ping systems) are categorically forbidden.

**How to apply:** When designing any screen-space element, check it against the "cockpit dial" model — glanceable peripherally, never the thing the player looks at. Corner-anchored only. Instant updates, no count-up, no progress bars. NOLF1 typographic register.

## Game Pillars

1. Comedy Without Punchlines (humour in world, not protagonist)
2. Discovery Rewards Patience (HUD must NOT have waypoints/minimap/markers)
3. Stealth is Theatre, Not Punishment
4. Iconic Locations as Co-Stars
5. Period Authenticity Over Modernization — HUD's load-bearing pillar

## HUD Player Fantasy (locked)

"I read my tools the way Eve does — peripherally, without ceremony, because I already know."
The HUD is Eve's cockpit dial. Competent player and competent character converge through the HUD's restraint.

## HUD Widgets (locked Art Bible §7A-D)

- Bottom-left: Health (BQA Blue strip, Parchment numeral, "HP" label)
- Bottom-right: Weapon name + ammo current/reserve
- Top-right: Gadget tile 56×56 px (PHANTOM Red tint for captured equipment)
- Center-lower: Contextual prompt strip 18% up from bottom-center
- Center: Crosshair (dot + tri-band halo, opt-out)

## Key UX Constants

- `hud_damage_flash_cooldown_ms = 333` (3 Hz WCAG 2.3.1 ceiling)
- `crosshair_dot_size_pct_v = 0.19%` × viewport_v, clamped [3, 12] px
- Critical health threshold: < 25% HP → Alarm Orange `#E85D2A`
- HUD CanvasLayer indices: 1 = corner widgets, 2 = prompt strip, 3 = crosshair
- ADR-0008 Slot 7 = 0.3 ms per-frame cap; signal-driven only (no _process polling)

## Forbidden HUD Surfaces (absolute)

Stamina bar, crouch indicator, damage direction indicator, sprint cooldown, hit marker, hold-E ring, minimap, waypoints, objective markers, alert-state visual, kill cam, damage numbers, floating text, radial weapon wheel, civilian readout.

## System Status

System #16 HUD Core — In Design as of 2026-04-25. GDD skeleton at `design/gdd/hud-core.md`. §Overview and §Player Fantasy written. §Detailed Design in progress.
