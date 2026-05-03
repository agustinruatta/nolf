# HUD Core VS Smoke Evidence — Skeleton

> Status: SKELETON — visual sign-off + Slot 7 perf measurement DEFERRED to a
> developer-driven Plaza VS playtest session per HC-006 Story spec.
>
> The architectural smoke surface (HUDCore + HUDStateSignaling end-to-end
> signal path) is automated in
> `tests/integration/feature/hud_core/hud_core_vs_smoke_test.gd` and PASSES
> 7/7 as of 2026-05-03. Visual checks below require human eyes.

Date: 2026-05-03 (skeleton)
Developer: TBD
Hardware: TBD
OS: Linux (per project pin)
Godot version: 4.6.2.stable.arch_linux
Resolution: 1080p (target)
Scene: Plaza VS — TBD (Plaza scene authoring deferred per Sprint 05 close-out
filesystem permission constraint on `scenes/sections/plaza.tscn`).

## Sprint 06 Stories Completed

- [x] HC-001 — CanvasLayer scene root scaffold + Theme + FontRegistry (12/12 tests PASS)
- [x] HC-002 — Signal subscription lifecycle + forbidden-pattern fences (12/12 PASS)
- [x] HC-003 — Health widget logic (damage flash, critical-state edge trigger) (9/9 PASS)
- [x] HC-004 — Interact prompt strip + PC query resolver + get_prompt_label() (8/8 PASS)
- [x] HC-005 — Settings live-update + pickup memo + full context-hide (10/10 PASS)
- [x] HC-006 — This story (architectural smoke automated; visual sign-off pending)
- [x] HSS-001 — HUD State Signaling structural scaffold (7/7 PASS)
- [x] HSS-002 — ALERT_CUE Day-1 minimal slice (10/10 PASS)
- [x] HSS-003 — MEMO_NOTIFICATION VS toast (9/9 PASS)

## Architectural smoke (automated — AC-1 / AC-7 / AC-8 surface)

`tests/integration/feature/hud_core/hud_core_vs_smoke_test.gd` exercises:

- HUD + HSS coexist without errors at scene boot
- HUD scene tree contains no minimap / waypoint / radar / objective_marker
  tokens (Pillar 5 absolute exclusion)
- damage event opens the rate-gate Timer + critical-state edge trigger sets
  Alarm Orange override
- alert_state_changed → ALERT_CUE state activated; document_collected during
  ALERT_CUE → MEMO queued single-deep; ALERT timer expiry → MEMO promoted
- ui_context_changed(MENU, GAMEPLAY) → HUD hidden + set_process(false) +
  Timer.stop on every Timer + HSS state cleared + queued MEMO discarded
- HUDCore is NOT registered in project.godot [autoload]
- HSS emits zero Events signals (subscriber-only posture preserved across
  all three HSS stories)

7/7 PASS as of 2026-05-03.

## Slot 7 Perf Measurement (AC-5) — DEFERRED

**Pending**: Plaza VS scene + Godot profiler session on the dev machine.

Procedure (from HC-006 Implementation Notes):

1. Open Plaza VS scene in Godot 4.6 editor.
2. Run the scene (F5).
3. Open Debugger → Profiler → Script panel; start profiling.
4. Worst-case sequence: walk near document prop (5s prompt), Esc menu open+close,
   take damage event, collect document.
5. Stop profiling; record HUDCore._process worst-case + mean from call tree.

Cap: 0.300 ms worst-case.

Result: TBD.

## Visual Sign-Off Items (AC-2 / AC-3 / AC-4 / AC-6) — DEFERRED

The following require user playtest on the Plaza VS scene:

- AC-2: Health numeral flashes white for 1 frame on damage; reverts to
  Parchment (`#F2E8C8`) above 25% HP, Alarm Orange (`#E85D2A`) below.
- AC-3: Interact prompt at CB position renders document `interact_label_key`
  text + `[E]` key glyph when in range; hides when target null.
- AC-4: Pickup memo briefly displays document title for ~3s then hides.
- AC-6: HUD opacity 85% per art bible §7E; no rounded corners, no drop
  shadows, Futura Condensed Bold @ 1080p (DIN 1451 Engschrift below 18 px).

**Sprint 06 HARD STOP per roadmap line 67**: visual sign-off on HUD field
opacity is required before the sprint can close. The 4 StyleBoxFlat
backgrounds in `src/core/ui_framework/themes/hud_theme.tres` use BQA Blue
`Color(0.106, 0.227, 0.420, 0.85)` — alpha = 0.85 matches the §7E spec at
the data-resource level. Playtest verification confirms this on the
final reference scenes (Restaurant, Bomb Chamber).

## Screenshots (DEFERRED)

- `screenshot_001_health_parchment.png` — TBD
- `screenshot_002_health_alarm_orange.png` — TBD
- `screenshot_003_interact_prompt.png` — TBD
- `screenshot_004_pickup_memo.png` — TBD
- `screenshot_005_context_hidden.png` — TBD

## Open Defects

None identified during architectural smoke. Visual review may surface defects
that this skeleton does not anticipate.

## Sign-Off

[ ] Solo developer visual sign-off on AC-2 / AC-3 / AC-4 / AC-6 pending
    Plaza VS scene authoring (currently blocked by `scenes/sections/`
    filesystem permission constraint per Sprint 05 close-out).

[ ] Slot 7 perf measurement pending dev machine session.
