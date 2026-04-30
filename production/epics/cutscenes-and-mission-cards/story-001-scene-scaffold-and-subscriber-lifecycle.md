# Story 001: Scene scaffold + subscriber lifecycle

> **Epic**: Cutscenes & Mission Cards
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 3-4 hours (M — new scene file + 2 GDScript files + subscriber lifecycle test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/cutscenes-and-mission-cards.md`
**Requirements**: TR-CMC-001, TR-CMC-002, TR-CMC-003
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-CMC-001**: `InputContext.CUTSCENE` enum value (added 2026-04-28 Amendment A7) with push at start, pop at end per ADR-0004.
- **TR-CMC-002**: `CanvasLayer` index 10 mutually exclusive with Settings via lazy-instance discipline + InputContext gate per ADR-0004 §253.
- **TR-CMC-003**: Cutscenes is subscriber-only to Mission domain (`mission_started`, `mission_completed`, `objective_started`, `objective_completed`, `section_entered`) per ADR-0002.

**ADR Governing Implementation**: ADR-0007 (Autoload Load Order Registry) + ADR-0004 (UI Framework) + ADR-0002 (Signal Bus)
**ADR Decision Summary**: Cutscenes is NOT an autoload — autoload registry is full at 10 slots per ADR-0007. The system is a per-section `CanvasLayer` (index 10) instantiated by MLS as a child of the section root scene. `InputContext.CUTSCENE` is declared in the `InputContext.Context` enum (ADR-0004 Amendment A7). The system subscribes to Mission-domain signals in `_ready()` and disconnects in `_exit_tree()` per ADR-0002 IG 3.

**Engine**: Godot 4.6 | **Risk**: LOW-MEDIUM (ADR-0004 status Proposed; Gate 5 BBCode/AccessKit deferred; `InputContext.CUTSCENE` enum value introduced post-cutoff via Amendment A7)
**Engine Notes**: `CanvasLayer` as scene root is stable Godot 4.0+ pattern. `InputContext.push/pop/is_active` are project-defined methods on the `InputContextStack` autoload (not engine API). `MOUSE_FILTER_IGNORE` and `FOCUS_NONE` on card sub-nodes are critical for Godot 4.6 dual-focus split (VG-CMC-2 BLOCKING) — focusable Controls in the card tree capture `Esc` before `_unhandled_input` fires on the root. `AUTO_TRANSLATE_MODE_DISABLED` constant verified in 4.5+ per ADR-0004 Gate 4 closure.

> "This API was introduced in Godot 4.5 (`AUTO_TRANSLATE_MODE_DISABLED`) — verified against engine-reference docs per ADR-0004 Gate 4 closure 2026-04-27."

**Control Manifest Rules (Presentation Layer)**:
- Required: subscribers MUST connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards before each disconnect — ADR-0002 IG 3
- Required: every Node-typed signal payload MUST be checked with `is_instance_valid(node)` before dereferencing — ADR-0002 IG 4
- Required: use direct emit (`Events.<signal>.emit(args)`) not wrapper methods — ADR-0002 §Risks
- Forbidden: `cmc_publishing_mission_signals` — `Events.mission_started.emit(...)` or any Mission-domain emit from Cutscenes source files (CR-CMC-1, FP-CMC-10)
- Forbidden: `cmc_pushing_subtitle_visibility` — any direct call to HUD Core, D&S, or AudioManager from Cutscenes (CR-CMC-13, FP-CMC-11)
- Forbidden: `CutscenesAndMissionCards.new()` — instantiation MUST go through `PackedScene.instantiate()` (GDD §C.8 FP-CMC-13)
- Forbidden: any `Button`, `LinkButton`, `TextEdit`, or focusable Control within the card scene tree; `mouse_filter = MOUSE_FILTER_STOP` on any card sub-node (GDD §C.8 VG-CMC-2 BLOCKING)
- Guardrail: CanvasLayer index 10 is ADR-0004-locked; must not be changed without an ADR-0004 amendment

---

## Acceptance Criteria

*From GDD `design/gdd/cutscenes-and-mission-cards.md` §C.8 + AC-CMC-1.2 + AC-CMC-2.1:*

- [ ] **AC-1**: `res://src/gameplay/cutscenes/cutscenes_and_mission_cards.gd` declares `class_name CutscenesAndMissionCards extends CanvasLayer` with `layer = 10` set in `_ready()`. The file contains `@onready` references to `$BriefingCard`, `$ClosingCard`, `$ObjectiveCard`, `$LetterboxTop`, `$LetterboxBottom`. Member vars `_dismiss_gate_active: bool`, `_context_pushed: bool`, `_current_scene_id: StringName`, `_current_title_key: StringName`, `_current_body_key: StringName` are declared with correct types.
- [ ] **AC-2**: `res://src/gameplay/cutscenes/CutscenesAndMissionCards.tscn` exists with `CutscenesAndMissionCards` as root node. Every `Control` child node (BriefingCard, ClosingCard, ObjectiveCard and all their sub-nodes) has `mouse_filter = MOUSE_FILTER_IGNORE` and `focus_mode = FOCUS_NONE`. No `Button`, `LinkButton`, or `TextEdit` node exists anywhere in the scene tree.
- [ ] **AC-3**: GIVEN `CutscenesAndMissionCards._ready()` executes, WHEN `Events.mission_started.is_connected(_on_mission_started)` is queried, THEN `true`. Repeat for `mission_completed`, `objective_started`, `section_entered`, `game_loaded` (all 5 subscriptions). GIVEN `_exit_tree()` fires, THEN all five `is_connected()` checks return `false`. (AC-CMC-1.2)
- [ ] **AC-4**: GIVEN `_context_pushed == false` and `InputContext.current() == GAMEPLAY`, WHEN `_open_card(&"mc_briefing_paris_affair", CardType.MISSION_BRIEFING)` is called, THEN `InputContext.is_active(InputContext.Context.CUTSCENE) == true` AND `_context_pushed == true`. GIVEN `_dismiss()` subsequently called, THEN `InputContext.is_active(CUTSCENE) == false` AND `_context_pushed == false`. (AC-CMC-2.1) — BLOCKED on OQ-CMC-1 (Context.CUTSCENE enum value)
- [ ] **AC-5**: GIVEN `InputContext.CUTSCENE` is on the stack with `_context_pushed == true`, WHEN `_exit_tree()` fires, THEN `_cleanup()` calls `InputContext.pop()` and clears `_context_pushed = false`. GIVEN `_exit_tree()` fires with `_context_pushed == false`, THEN `InputContext.pop()` is NOT called (no underflow). (AC-CMC-2.2)
- [ ] **AC-6**: GIVEN the `src/gameplay/cutscenes/` source tree, WHEN `grep -rn "Events\.mission_started\.emit\|Events\.mission_completed\.emit\|Events\.objective_started\.emit\|Events\.objective_completed\.emit"` runs excluding the sole-publisher file, THEN zero matches in any Cutscenes file. (AC-CMC-1.1) — BLOCKED on OQ-CMC-2 (signal names declared)

---

## Implementation Notes

*Derived from ADR-0007, ADR-0004, ADR-0002 Implementation Guidelines + GDD §C.8:*

**File structure to create:**

```
src/gameplay/cutscenes/
├── cutscenes_and_mission_cards.gd   (class_name CutscenesAndMissionCards extends CanvasLayer)
└── CutscenesAndMissionCards.tscn    (CanvasLayer root; pre-baked card sub-scenes as children)
```

**Critical lifecycle pattern** (ADR-0002 IG 3 — connect in `_ready`, disconnect in `_exit_tree`):

```gdscript
func _ready() -> void:
    layer = 10
    Events.mission_started.connect(_on_mission_started)
    Events.mission_completed.connect(_on_mission_completed)
    Events.objective_started.connect(_on_objective_started)
    Events.section_entered.connect(_on_section_entered)
    Events.game_loaded.connect(_on_game_loaded)

func _exit_tree() -> void:
    if Events.mission_started.is_connected(_on_mission_started):
        Events.mission_started.disconnect(_on_mission_started)
    # ... repeat for all 5 subscriptions ...
    if _context_pushed:
        InputContext.pop()
        _context_pushed = false
```

**`_context_pushed` boolean guard** is the sole enforcement of the 1:1 push/pop pairing (CR-CMC-5). Push sets `true`; `_cleanup()` pops and asserts it was `true` before clearing. The `_cleanup()` function is called from all exit paths: normal dismiss, dismiss-gate timer path, `_exit_tree` abort.

**NOT autoload**: this scene is instantiated by MLS per-section via `PackedScene.instantiate()`, parented to the section root. It lives for the section's lifetime. `queue_free()` is triggered only by section root teardown (CR-CMC-16).

**ADR-0004 lazy-instance invariant**: Settings panel uses CanvasLayer index 10 as well. The InputContext gate prevents simultaneous instantiation — CUTSCENE blocks Settings entry (FP-CMC-7), and SETTINGS blocks CUTSCENE launch. However, the lazy-instance discipline is the structural defense. This story does not implement Settings interaction; it establishes the CanvasLayer foundation.

**Scene-tree input invariants** (GDD §C.8 VG-CMC-2 BLOCKING — Godot 4.6 dual-focus): all `Control` nodes in the card tree must be:
- `mouse_filter = Control.MOUSE_FILTER_IGNORE`
- `focus_mode = Control.FOCUS_NONE`

A focusable Button in the card tree captures `Esc` via `_gui_input` before the CanvasLayer root's `_unhandled_input` fires. This would silently break the dismiss-gate. Enforce in `.tscn` and verify in test.

**Stub card sub-scenes**: `$BriefingCard`, `$ClosingCard`, `$ObjectiveCard` must be pre-baked as children in the `.tscn` file. The `@onready` vars reference them at scene instantiation; dynamic-attach post-`_ready()` leaves them `null`. At this story's scope, these may be empty `Control` nodes with placeholder Labels — visual spec is implemented in Story 004.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `cutscene_started` / `cutscene_ended` signal emissions and Cutscenes-domain signal publishing
- Story 003: Replay suppression logic (`_try_fire_card`, `triggers_fired` read, one-active invariant)
- Story 004: Mission briefing card + closing card visual implementation (typography, colors, dismiss-gate timer, localization)
- Story 005: Forbidden-pattern CI shell scripts; performance budget verification; audio stinger integration
- PPS sepia-dim + fade-to-black lifecycle (CR-CMC-22) — Story 004
- Outline tier escape-hatch (CR-CMC-14) — Story 004
- Objective opt-in cards (deferred post-VS scope in VS1 — VS-narrowing per epic)
- Section-transition cinematics CT-03/CT-04 (deferred post-VS per epic VS-narrowing)
- CT-05 letterbox + op-art CanvasLayer 11 (deferred post-VS per epic VS-narrowing)

---

## QA Test Cases

*Solo mode — QA lead gate skipped. Test cases derived from GDD ACs and ADR rules.*

**AC-3: Subscriber lifecycle — connect on ready, disconnect on exit**
- Given: A `CutscenesAndMissionCards` node added to a test scene tree with an `Events` autoload present
- When: `_ready()` completes
- Then: `Events.mission_started.is_connected(_on_mission_started) == true`; same for `mission_completed`, `objective_started`, `section_entered`, `game_loaded`
- When: `queue_free()` called and `_exit_tree()` fires
- Then: all five `is_connected()` checks return `false`
- Edge cases: double-queue_free in same frame must not cause double-disconnect (is_connected guard prevents this)

**AC-4: InputContext push/pop 1:1 pairing**
- Given: `_context_pushed == false`, `InputContext.current() == GAMEPLAY`, a mock `InputContext` that tracks push/pop calls
- When: `_open_card(&"mc_briefing_paris_affair", CardType.MISSION_BRIEFING)` called
- Then: `InputContext.push(Context.CUTSCENE)` called once; `_context_pushed == true`
- When: `_dismiss()` called
- Then: `InputContext.pop()` called once; `_context_pushed == false`
- Edge cases: calling `_dismiss()` when `_context_pushed == false` must not call `InputContext.pop()` (no underflow)

**AC-5: Exit-tree cleanup with pushed context**
- Given: `_context_pushed == true` (CUTSCENE on stack)
- When: `_exit_tree()` fires (simulated via `queue_free()` on the node)
- Then: `InputContext.pop()` called exactly once; `_context_pushed == false` after cleanup
- Given: `_context_pushed == false` at exit
- When: `_exit_tree()` fires
- Then: `InputContext.pop()` NOT called; no error raised

**AC-6: No Mission-domain emit in Cutscenes source (code-review)**
- Setup: Run `grep -rn "Events\.mission_started\.emit\|Events\.mission_completed\.emit" src/gameplay/cutscenes/` in CI
- Verify: Zero matches
- Pass condition: Exit code 0 from grep returning empty output

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/presentation/cutscenes_and_mission_cards/subscriber_lifecycle_test.gd` — must exist and pass (AC-3)
- `tests/unit/presentation/cutscenes_and_mission_cards/input_context_lifecycle_test.gd` — must exist and pass (AC-4, AC-5)
- `production/qa/evidence/story-001-cutscenes-scaffold-evidence.md` — walkthrough confirming scene tree structure, MOUSE_FILTER_IGNORE on all card Controls, no focusable nodes (AC-2)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ADR-0002 (Accepted — signal subscriptions), ADR-0007 (Accepted — NOT autoload rule), ADR-0004 (Proposed, Gates 1-4 closed — InputContext.CUTSCENE enum via Amendment A7 required before AC-4 can pass)
- BLOCKED on: OQ-CMC-1 (ADR-0004 Amendment A7 adding `Context.CUTSCENE`) for AC-4 full verification; OQ-CMC-2 (ADR-0002 amendment adding `cutscene_started`/`cutscene_ended`) for AC-6 grep
- Unlocks: Story 002 (signal domain), Story 003 (replay suppression — needs scene scaffold), Story 004 (card visuals — needs scaffold + InputContext lifecycle)
