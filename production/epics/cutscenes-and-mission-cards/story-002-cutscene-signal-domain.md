# Story 002: Cutscene signal domain — cutscene_started and cutscene_ended

> **Epic**: Cutscenes & Mission Cards
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 2-3 hours (S — ADR-0002 amendment to events.gd + subscription in AudioManager stub + integration test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/cutscenes-and-mission-cards.md`
**Requirements**: TR-CMC-004, TR-CMC-005, TR-CMC-007, TR-CMC-008
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-CMC-004**: NEW signal `cutscene_started(scene_id: StringName)` added to Cutscenes domain in `events.gd` (ADR-0002 amendment 2026-04-29 — uncommitted, pending atomic-PR landing).
- **TR-CMC-005**: NEW signal `cutscene_ended(scene_id: StringName)` added to Cutscenes domain (same amendment).
- **TR-CMC-007**: Audio subscribes to `cutscene_started`/`cutscene_ended` for silence-cut + 2.0 s crossfade restore (Audio Crossfade Rule 6 per CR-CMC-11). This story adds the subscription contract; full audio behavior implemented in the Audio epic.
- **TR-CMC-008**: MLS subscribes to `cutscene_ended` to write `scene_id` into `MissionState.triggers_fired` (CR-CMC-21 — sole writer; closes Save/Load L107 + L162 forward-dep). This story verifies the signal fires correctly; MLS write-path is MLS epic scope.

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: All cross-system events flow through `Events.gd` (the signal bus autoload). New signals are added atomically with their enum declarations and consumer wiring in a single PR (ADR-0002 amendment risk note: partial PR where `events.gd` references an undeclared type causes project-load failure). `CutscenesAndMissionCards` is the **sole emitter** of `cutscene_started` and `cutscene_ended`. Audio and MLS are subscribers. Enum types live on the owning class, not on `events.gd`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `signal` keyword + `StringName` typed signal parameters are stable Godot 4.0+. The ADR-0002 amendment constraint (atomic PR with owning enum + signal + consumer changes) is a project process rule, not an engine constraint. `is_connected` guard before `disconnect` in `_exit_tree` is required per ADR-0002 IG 3 to prevent double-disconnect errors in headless test runs.

**Control Manifest Rules (Foundation — Signal Bus)**:
- Required: direct emit `Events.cutscene_started.emit(scene_id)` — never wrapper methods (ADR-0002 §Risks)
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guard (ADR-0002 IG 3)
- Required: enum types on the owning system class, not on `events.gd` (ADR-0002 IG 2)
- Forbidden: `event_bus_with_methods` — never add methods, state, or helpers to `events.gd`
- Forbidden: `event_bus_enum_definition` — no enum definitions on `events.gd`
- Forbidden: `cmc_publishing_mission_signals` — `cutscene_started`/`cutscene_ended` are Cutscenes-domain signals; Cutscenes emits them; they must never be emitted from MLS, Audio, or any other system
- Guardrail: signal emit cost bounded by `cutscene_started/ended` cadence ≤ 7 first-watch pairs per play-through (ADR-0002 IG 5 — already validated in control manifest)

---

## Acceptance Criteria

*From GDD `design/gdd/cutscenes-and-mission-cards.md` AC-CMC-7.1 + CR-CMC-11:*

- [ ] **AC-1**: `src/core/signal_bus/events.gd` declares `signal cutscene_started(scene_id: StringName)` and `signal cutscene_ended(scene_id: StringName)` in a clearly labeled `# --- Cutscenes domain ---` block. No new methods, vars, or consts are added alongside them. Signal count comment in the file header is updated to reflect the new total (43 signals per ADR-0002 revision history 2026-04-29). — BLOCKED on OQ-CMC-2
- [ ] **AC-2**: GIVEN cinematic CT-03 triggered and `_start_cinematic(&"ct_03_kitchen_egress")` executes, WHEN spy monitors `Events`, THEN `Events.cutscene_started` fires with `scene_id == &"ct_03_kitchen_egress"` before any `AnimationPlayer` track advances. WHEN cinematic ends, `Events.cutscene_ended` fires with the same `scene_id`. Spy: emit counts each == 1, in the correct order. (AC-CMC-7.1)
- [ ] **AC-3**: GIVEN `Events.cutscene_started` declared in `events.gd`, WHEN `grep -rn "cutscene_started\|cutscene_ended" src/` is run, THEN: (a) the only emit sites are in `src/gameplay/cutscenes/cutscenes_and_mission_cards.gd`; (b) Audio epic stub and MLS autoload appear as subscriber-side connections only (no `.emit` calls at those sites).
- [ ] **AC-4**: GIVEN the `src/core/signal_bus/events.gd` source, WHEN linted for `func `, `var `, or `const ` declarations (excluding `class_name` and `extends` header), THEN zero matches remain (structural purity maintained after adding the two new signals).
- [ ] **AC-5** (EC-CMC-B.4 related — slot contamination check): GIVEN `CutscenesAndMissionCards` in a section scene tree with `_context_pushed == true` (cutscene active), WHEN a different save slot is loaded via `SaveLoadService.load_from_slot(5)` (simulated via `Events.game_loaded.emit()`), THEN: (a) `_on_game_loaded()` executes without pushing CUTSCENE; (b) `InputContext.is_active(CUTSCENE) == false` after handler returns; (c) no `cutscene_started` emit occurs. MissionState from slot 5 is the authoritative state; slot 1 context does not contaminate slot 5. (EC-CMC-B.4)

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines + GDD §C.11 + CR-CMC-11:*

**The ADR-0002 atomic-PR rule**: the two new signals, any enum types they reference, and the initial subscriber wiring must land in a single commit. `events.gd` must not reference `scene_id: StringName` without the type being resolvable — `StringName` is a Godot built-in, so no enum risk, but verify `events.gd` imports are stable.

**events.gd change** (ADR-0002 IG 2 — signals-only file):

```gdscript
# --- Cutscenes domain (added 2026-04-29 per cutscenes-and-mission-cards.md CR-CMC-11) ---
signal cutscene_started(scene_id: StringName)  ## CutscenesAndMissionCards sole emitter; Audio + MLS subscribe
signal cutscene_ended(scene_id: StringName)    ## CutscenesAndMissionCards sole emitter; MLS writes triggers_fired on receipt
```

No wrapper methods. No enum definitions. No state. Structural purity test (Signal Bus Story 001 `events_purity_test.gd`) must still pass after this addition.

**Emit sites in `cutscenes_and_mission_cards.gd`** (CutscenesAndMissionCards sole emitter):

```gdscript
func _start_cinematic(scene_id: StringName) -> void:
    InputContext.push(InputContext.Context.CUTSCENE)
    _context_pushed = true
    _current_scene_id = scene_id
    Events.cutscene_started.emit(scene_id)   # fires before AnimationPlayer advances
    # ... start AnimationPlayer ...

func _on_cinematic_finished() -> void:
    Events.cutscene_ended.emit(_current_scene_id)  # fires before _cleanup()
    _cleanup()
```

**`cutscene_started` fires BEFORE AnimationPlayer.play()** — ordering constraint per AC-CMC-7.1. AudioManager's silence-cut handler must execute before the first cinematic frame renders.

**Mission Cards do NOT emit `cutscene_started`/`cutscene_ended`** (EC-CMC-E.5): briefing and closing cards push `InputContext.CUTSCENE` and display text, but do not trigger Audio track-swap state. Audio crossfade signals are reserved for cinematics CT-03/04/05 only. If a card handler calls `cutscene_started`, it is a defect — AC-3 verifies this at code-review.

**EC-CMC-B.4 — load-from-slot during cutscene (BLOCKING for VS DOD)**:
- Cutscenes subscribes to `Events.game_loaded` in `_ready()` (already wired in Story 001)
- `_on_game_loaded()` must NOT push `InputContext.CUTSCENE` — it only validates `triggers_fired` consistency (CR-CMC-21)
- If `_context_pushed == true` when `game_loaded` fires (cutscene was active at save time, which CR-CMC-6 makes structurally impossible — but defensive coding required): `_cleanup()` must safely pop the context before the new save state is applied
- The slot contamination risk is: slot 1 `MissionState.triggers_fired` cached in a local variable during an active cutscene is replaced when slot 5 loads. Cutscenes reads `MissionState` via `MissionLevelScripting.get_mission_state()` live reference (per EC-CMC-B.8 OQ-CMC-6 contract) — NOT a cached copy — so the new slot's state is read fresh on the next `_try_fire_card` call. No contamination is structurally possible given the live-reference contract. AC-5 verifies this boundary.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: Replay suppression logic (`_try_fire_card`, `triggers_fired` read, one-active invariant)
- Story 004: Full cinematic start/end lifecycle for CT-03/04/05 at Visual/Feel level (AnimationPlayer tracks, letterbox, visual spec)
- Story 005: AudioManager subscription implementation and stinger suppression test (TR-CMC-007 Audio side — Audio epic)
- MLS `cutscene_ended` subscription and `triggers_fired` write path (TR-CMC-008 MLS side — MLS epic)
- Full Audio Crossfade Rule 6 silence-cut behavior (Audio epic Story — Audio subscribes to these signals)

---

## QA Test Cases

*Solo mode — test cases derived from GDD ACs and ADR rules.*

**AC-2: cutscene_started/ended emit ordering for cinematic**
- Given: `CutscenesAndMissionCards` in scene tree; `watch_signals(Events)` active in GUT; a mock `AnimationPlayer` stub
- When: `_start_cinematic(&"ct_03_kitchen_egress")` called
- Then: `assert_signal_emitted(Events, "cutscene_started")` passes; `cutscene_started` payload `scene_id == &"ct_03_kitchen_egress"`; emitted before `AnimationPlayer.play()` call (verify via call-order spy on `AnimationPlayer` stub)
- When: cinematic finishes and `_on_cinematic_finished()` called
- Then: `assert_signal_emitted(Events, "cutscene_ended")`; payload `scene_id == &"ct_03_kitchen_egress"`; emit count == 1 for each
- Edge cases: `_current_scene_id` must be set before emit (empty `&""` scene_id in `cutscene_started` is a defect)

**AC-4: events.gd structural purity after amendment**
- Given: `src/core/signal_bus/events.gd` with two new Cutscenes signals added
- When: purity test `events_purity_test.gd` runs (Signal Bus Story 001)
- Then: zero `func `, `var `, `const ` matches outside header — file remains signals-only
- Edge cases: signal declaration with `=` default value would appear as `var` to naive grep — ensure test uses proper GDScript-aware parse

**AC-5: EC-CMC-B.4 load-from-slot during cutscene — no slot contamination**
- Given: `CutscenesAndMissionCards` with `_context_pushed == true` (CUTSCENE on stack); slot 1 `MissionState.triggers_fired = []`
- When: `Events.game_loaded.emit()` fires (simulating slot 5 load — `MissionLevelScripting.get_mission_state()` now returns slot 5's state with `triggers_fired = [&"mc_briefing_paris_affair"]`)
- Then: `InputContext.is_active(CUTSCENE) == false` after `_on_game_loaded()` returns; no `cutscene_started` emitted; subsequent `Events.mission_started.emit(...)` is suppressed by CR-CMC-2 reading slot 5's `triggers_fired` (briefing card already fired on slot 5)
- Edge cases: `_on_game_loaded()` must not call `_open_card()` (game_loaded is not a card trigger); verify spy on `_open_card` records zero calls

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/presentation/cutscenes_and_mission_cards/cutscene_signal_domain_test.gd` — must exist and pass (AC-2, AC-4)
- `tests/integration/presentation/cutscenes_and_mission_cards/slot_contamination_test.gd` — must exist and pass (AC-5, EC-CMC-B.4 BLOCKING)
- `production/qa/evidence/story-002-cutscene-signal-domain-evidence.md` — walkthrough confirming `events.gd` purity after amendment, emit sites limited to `cutscenes_and_mission_cards.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene scaffold + subscriber lifecycle must be DONE — this story adds signal emissions to the scaffold); ADR-0002 (Accepted — signal bus mechanism verified); OQ-CMC-2 (ADR-0002 amendment adding `cutscene_started`/`cutscene_ended` to Cutscenes domain — BLOCKING for AC-1)
- BLOCKED on: OQ-CMC-2 (the two new signals must be declared in `events.gd` before this story ships)
- Unlocks: Story 003 (replay suppression — needs `cutscene_started` signal in place for audio-handshake verification); Story 005 (forbidden-pattern CI — needs signal emit sites established); Audio epic story that implements AudioManager subscription to `cutscene_started`/`cutscene_ended`; MLS story that implements `triggers_fired` write on `cutscene_ended`
