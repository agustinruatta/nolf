---
name: Project Context — The Paris Affair
description: Core concept, pillars, HUD philosophy, and locked upstream contracts for HUD Core (#16) and Settings & Accessibility (#23)
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

System #16 HUD Core — APPROVED 2026-04-26. GDD at `design/gdd/hud-core.md`. 7 BLOCKING coord items remain open before sprint planning.

System #23 Settings & Accessibility — §C UX flow scope authored 2026-04-26. Player Fantasy: "The Stage Manager" (quiet, professional, brisk, non-diegetic, restrained). Six categories locked: Audio, Graphics, Accessibility, HUD, Controls, Language.

## Settings Panel UX — Locked Decisions (2026-04-26)

- Architecture: sidebar-with-detail-pane (`HSplitContainer`; left category list ~200 px; right `ScrollContainer` field pane)
- Navigation: column-first focus model; `ui_right` crosses left→right; `ui_left` crosses right→left; no horizontal wrap; vertical wrap only in category list
- Hover: highlights only; right pane swaps on click/accept, not hover
- Rebind capture: uses `_input` + `set_input_as_handled()` (NOT `_unhandled_input`) to swallow all keys including `ui_cancel`; `ui_cancel` during CAPTURING cancels (does not bind Escape); conflict → inline banner with Replace/Cancel options (not a separate modal)
- Multi-bind: one keyboard binding + one gamepad binding per action stored separately; no two-keyboard-key multi-bind
- Boot warning: minimal centered modal before studio logo on first launch only; default focus = "Disable Effects Now"; persistence key `accessibility.photosensitivity_warning_dismissed`; does NOT re-show on New Game if settings.cfg intact
- Sliders: safety-floor sliders set `min_value` = floor (no rubber-band); discrete options use `OptionButton` not snap-slider; volume displayed 0-100% (not dB); readout `Label` right of slider, same baseline
- Apply pattern: immediate apply on change (no Apply button); resolution scale only gets 10s revert-timer inline banner; settings written to cfg on panel dismiss
- Forbidden: animated category transitions, toasts on change, slider-drag sounds, moralizing tooltip copy, forced settings onboarding, color-only toggle state, visible locale switcher when only one locale exists

## Open Questions (Settings)

- OQ-UX-1 (BLOCKING, Controls sprint): Gamepad rebind layout — second column vs sub-tab for VS; ui-programmer must decide row structure at MVP
- OQ-UX-2 (ADVISORY, playtest): Resolution revert timer — 10s default, tuning knob `RESOLUTION_REVERT_TIMEOUT_SEC` [5,30]
- OQ-UX-3 (BLOCKING, Accessibility sprint): ADR-0004 Gate 1+2 must resolve before any AccessKit property names are implemented
