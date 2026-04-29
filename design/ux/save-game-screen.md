# UX Spec: File Dispatch (Save Game Screen)

> **Status**: In Design
> **Author**: agustin.ruatta@vdx.tv + ux-designer
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: Pause-Menu-only. Reachable mid-section to file a manual save.
> **Template**: UX Spec
> **Scope**: VS (Vertical Slice) per Menu System §C.2 row 8 + Save/Load §UI Requirements L239.
> **Governing GDDs**: `design/gdd/menu-system.md` (§C.2 row 8 + §C.5 Save Card Grid + in-card overwrite-confirm + §V.2 + §V.3 + §C.8 + §H.9 ACs) + `design/gdd/save-load.md` (§C `OCCUPIED/EMPTY/CORRUPT` slot states, slot 0 NOT selectable + §UI Requirements L239 + `save_to_slot()` API L249).
> **Pattern Inheritance**: `save-load-grid` from interaction-patterns.md (CANONICAL — shared with `load-game-screen.md`). This spec adds the **in-card overwrite-confirm** flow (Menu System CR-12 + F.5) — unique to the save grid.
> **Sibling**: `load-game-screen.md` — same grid chrome, different semantics (load vs. save) and slot-count (8 vs. 7) and confirm flow (none vs. in-card).

---

## Purpose & Player Need

The File Dispatch is the **player's manual-save surface** — the 7-slot grid where the player picks a slot to file (save) the current dispatch. It is the save-game surface, distinguishable from Operations Archive by:
1. **7 slots, not 8** — slot 0 (autosave) is NOT user-selectable here (Save/Load CR-4 + AC-14).
2. **In-card overwrite-confirm flow** — saving to an OCCUPIED slot triggers an inline confirm step, not a load.
3. **Pause-only** — File Dispatch is never reached from Main Menu (no save-during-cold-boot use case).

> **Player goal**: *"Stamp my current operation onto a numbered dispatch — manually, with control over which slot, with a chance to confirm before overwriting."*

**What goes wrong if this surface is missing or hard to use:**
- Player cannot manually save at all — only autosave (slot 0) exists; no recoverable points across multi-session play. **Critical break.**
- Player accidentally overwrites a treasured slot (e.g., end of section 3) by hitting Confirm too fast — overwrite-confirm is the safety check (CR-12).
- Player cannot tell which slot is OCCUPIED with which section before saving — visual differentiation (per V.2) tells the story.
- Player's screen reader announces the OCCUPIED slot's metadata but does not warn that activating it will overwrite — accessibility break.

**Distinguishing constraints**:
- **7 slots: 1–7 manual; slot 0 absent** (per Save/Load CR-4: slot 0 is autosave-only, NOT in the Save picker).
- **Write-only screen**: this surface only saves. Loads go to Operations Archive (`load-game-screen.md`). The File Dispatch does NOT offer load semantics; activating an OCCUPIED slot triggers in-card overwrite-confirm.
- **Pause-only** (Menu System §C.2 row 8: "Child of PauseMenu only"). The interaction is not available from Main Menu.
- **Save-also-writes-to-slot-0** (Save/Load CR-4 + AC-2): a manual save to slot N also writes to slot 0 (the autosave), so Continue / quickload always reflects the most-recent player intent.

**Pillar fit:**
- **Primary 5 (Period Authenticity)**: same dispatch-card register as Load grid; the in-card overwrite-confirm is "the dispatcher writes over the existing form, not a fresh sheet" — paper consistency.
- **Pillar 3 (Stealth as Theatre)**: save-during-stress is the most common use case (player about to be detected → Pause → File Dispatch → slot 3 → Confirm). Must be FAST (≤4 keypresses from Pause root: `File Dispatch` → Tab to slot 3 → Enter → Confirm).
- **Anti-Pillar (NOT modern UX paternalism)**: no "Are you SURE you want to overwrite?" multi-page modal. The in-card confirm is in-place; pressed Cancel by default; one extra keypress to commit.

---

## Player Context on Arrival

The player arrives **voluntarily**, after explicitly choosing the File Dispatch option from Pause Menu:

| Vector | Trigger | Player state on arrival |
|---|---|---|
| From Pause Menu — mid-section | Player clicked `File Dispatch` button on Pause Menu (`menu.pause.save`) | Stressed-recovery (most common — about to die / be detected → save first) OR procedural (mission milestone reached → save out of habit) |
| Returning from in-card confirm | Player just cancelled an overwrite-confirm | Slight friction recovery — no harm done; back to the same slot's NORMAL OCCUPIED state |

**Emotional state assumptions** (priority order):
1. **Stressed + save-fast** — about to die / get detected. Wants to save NOW. Default focus on slot 1 (or last-used in-session) makes one Tab + Enter + Confirm enough. Total keypress count from gameplay → save-confirmed: 5 keys (Esc → File Dispatch → Tab to slot → Enter → Enter on Confirm).
2. **Procedural** — section transitioned successfully; saving out of habit. Calm; can afford to navigate to a specific slot.
3. **Mistake-aware** — pressed Confirm too fast on the wrong slot? In-card confirm provides Cancel default focus (CR-12); player must affirmatively press Confirm — overwrite is two-step, not one-step.
4. **Curious** — checking which slots are occupied / empty before saving. Like Operations Archive, the grid tells the story via card states.

**Held inputs**: typically none — player navigated through Pause to get here. KB+M cursor `MOUSE_MODE_VISIBLE`. Gamepad in menu-nav mode.

---

## Navigation Position

File Dispatch is a **sub-screen swap** within Pause Menu — does NOT push a new InputContext (per Menu System §C.2 row 8).

```
[Pause Menu (Context.PAUSE)]
    └── File Dispatch sub-screen swap (still Context.PAUSE)
        ├── Slot focused, NORMAL OCCUPIED state
        │     └── ui_accept on OCCUPIED slot → in-card CONFIRM_PENDING (still PAUSE; no MODAL push)
        │           ├── ui_cancel → returns to NORMAL OCCUPIED
        │           └── activate Confirm button → SaveLoad.save_to_slot(N) → success → A1+A6 → return to OCCUPIED state with updated metadata
        └── ui_accept on EMPTY slot → SaveLoad.save_to_slot(N) immediately (no confirm) → A1+A6 → return to OCCUPIED state
```

**Stack depth UNCHANGED across entire flow**: `[GAMEPLAY, PAUSE]`. The in-card confirm does NOT push `Context.MODAL` — it is a pure visual swap within the card. This is paper-consistent (the dispatcher marks up the same form, not a separate stamp pad) and minimizes context churn.

**Returning to Pause root**: `ui_cancel` from grid top-level (no card in CONFIRM_PENDING) returns to Pause Menu root with focus on `File Dispatch` button. **Two-press rule** (per CR-12): if a card is in CONFIRM_PENDING when `ui_cancel` is pressed, the FIRST press cancels the confirm (back to NORMAL OCCUPIED); the SECOND press exits the grid. This prevents accidental grid-exit while in confirm.

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Pause Menu → File Dispatch button | `menu.pause.save` activated | `Context.PAUSE`; live section state in memory; SaveGame must be assembled by Mission Scripting at the moment of save (per Save/Load `save_service_assembles_state` forbidden-pattern: Save/Load does NOT assemble — Menu+Mission do) |
| Returning from in-card cancel | First `ui_cancel` press while card in CONFIRM_PENDING | Slot state reverts to NORMAL OCCUPIED; focus restores to slot |

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| Back to Pause Menu root | `ui_cancel` at grid top level (no card in CONFIRM_PENDING) | Reversible; returns to Pause root with focus on `File Dispatch` button |
| **Save fired → slot updated, stay on grid** | `ui_accept` on Confirm in CONFIRM_PENDING (OCCUPIED slot) OR `ui_accept` on EMPTY slot | Slot transitions to/remains in NORMAL OCCUPIED; grid stays open; player can save to another slot or cancel out. **NOT a destructive exit — it's a write that stays on the screen.** |
| **Save failed → Save-Failed modal mounts** | `Events.save_failed` fires after a save attempt | ModalScaffold mounts SaveFailedContent on top; `Context.MODAL` pushed; grid stays visible; player retries via the modal |
| Cancel-on-CORRUPT slot | `ui_accept` on CORRUPT slot | No-op — `disabled = true`; no save. (CORRUPT slots are still overwriteable per Save/Load §States L93 — but at MVP+VS the spec treats CORRUPT as `disabled` to avoid implicit overwrite. Coord with save-load owner; flag in OQ.) |

### Irreversible exit warnings

- **Saving to a slot is destructive in one direction only**: it overwrites the previous OCCUPIED state of that slot. The atomic-write contract (ADR-0003) guarantees the previous good slot is preserved if the save fails — but a successful save replaces the slot's content.
- **Overwriting is gated by in-card CONFIRM_PENDING** for OCCUPIED slots — two-press required (slot Enter → Confirm Enter).
- **EMPTY slot save is one-press** — no confirm — because there is nothing to overwrite.
- **Slot 0 (autosave) is NEVER selectable** from this grid — even if the player wanted to manually save to slot 0, they cannot; the autosave path is system-driven only.

---

## Layout Specification

### Information Hierarchy

| Rank | What the player must see | Why it ranks here | How it is communicated |
|---|---|---|---|
| 1 | "**These are your save slots.**" (grid identity) | Without this, the player can't tell save-grid from load-grid | Title bar text `File Dispatch` (`menu.save.title`) at top of folder/page interior |
| 2 | Each slot's **state** (OCCUPIED / EMPTY / CORRUPT) | Drives the player's pick — they may want to overwrite an old save, fill an empty slot, or avoid a corrupt one | Per-card visual differentiation per Menu System §C.5 — same chrome as Load grid but **no AUTOSAVE state** (slot 0 absent) |
| 3 | Each slot's **section + timestamp** | Distinguishes saves; helps player find a specific one to overwrite | Card line 1 = `DISPATCH 03`; line 2 = `TOUR EIFFEL — NIVEAU 2 — 14:23 GMT` |
| 4 | **In-card overwrite-confirm** (when active) | Safety checkpoint for destructive overwrite | Card transforms in-place: top text swaps to `Overwrite Dispatch?`; body collapses; two buttons appear `[CANCEL]` (default focus) + `[CONFIRM]` |
| 5 | **Default focus** on grid mount | Drives save-fast path | Per CR-12: last-used slot in-session, else slot 1 |

**Categorically NOT shown** (per Pillar 5 + load-grid inheritance):
- Slot 0 / autosave — explicitly absent from this grid (Save/Load CR-4 + AC-14)
- Document collection state, mission progress, etc. (FP-DC-2 + Pillar 5)
- "Delete slot" button, "rename slot" button
- Cloud-sync icons
- Achievement / unlock state
- Auto-save timer / countdown indicator

### Layout Zones

Same as Load grid but with 7-slot 2×3+1 layout instead of 8-slot 2×4.

```
ZONE A — (Pause Menu's overlay + folder visible)
ZONE B — Page interior (760 × 720 minus margins)
  ├── B.1 — Title bar (`File Dispatch`)
  ├── B.2 — 7-slot 2×3+1 GridContainer (726 × 396 px footprint per V.3)
  └── B.3 — (no buttons — grid is the entire interactive surface)
```

**Grid layout** per Menu System F.1 + V.3:
- Slots 1–6 in cells `(0,0)` through `(1,2)` — fill 2 columns × 3 rows
- Slot 7 alone in cell `(0,3)` — bottom-left
- Cell `(1,3)` is absent (no Control); GridContainer has 7 children, not 8, per occupancy predicate `(row < 3) OR (row == 3 AND col == 0)`
- Inter-card gap: 6 H × 6 V

**Anchor specification (1080p baseline)**:

| Zone | Anchor | Size | Position | Z-order |
|---|---|---|---|---|
| B.1 — Title bar | Top of page interior | ~720 × 36 px | centered top | inherits Pause (CanvasLayer 8) |
| B.2 — Grid | Centered in page interior | 726 × 396 px (2×360 + 6 H × 3×96 + 12 + 96 V) | inter-card 6 H × 6 V; vertically centered below title | inherits |

### Component Inventory

Same as Load grid:
- Title bar Label (`File Dispatch`)
- GridContainer (7 children)
- 7 × Save Card (Button or PanelContainer with Button child)

Per-state rendering inherits Menu System §C.5 + V.2:

| State | Card body | Stamp | Color | Focus / activation |
|---|---|---|---|---|
| **OCCUPIED** | `DISPATCH 03` line 1 + `TOUR EIFFEL — NIVEAU 2 — 14:23 GMT` line 2 + 3 ruled body lines (40% opacity) | `FILED` Ink Black 45% | Standard Parchment `#F2E8C8` | Focus enabled; activation triggers in-card overwrite-confirm |
| **EMPTY** | Centered `— Slot Unoccupied —` (per `menu.save.slot_empty`) | `VACANT` Ink Black 25% | 30% dimmed Parchment | Focus enabled; activation triggers immediate save (no confirm) |
| **CORRUPT** | `████ ████ ████` redacted body lines + 2 px tear-marks | `DOSSIER CORROMPU` PHANTOM Red diagonal | Cooler off-white `#E8E0D0` | Focus enabled; `disabled = true` at MVP+VS; OQ to consider whether CORRUPT can be overwritten directly |
| **CONFIRM_PENDING** (transient) | Top text = `Overwrite Dispatch?` (`menu.save.confirm_overwrite`); body collapsed; `[CANCEL]` + `[CONFIRM]` buttons inline within the card | (no stamp) | Standard Parchment | Focus moves automatically to `[CANCEL]`; Tab cycles between `[CANCEL]` and `[CONFIRM]` only — does NOT escape to other slots |

### CONFIRM_PENDING component detail

Per Menu System §C.5 step 3 + V.2:
- Top text: `Overwrite Dispatch {n}?` — DIN 1451 11 px Ink Black, left-aligned (replaces `DISPATCH {n}` line)
- Body: collapsed to 0 lines — the 3 ruled body lines are hidden during confirm
- Two buttons inline:
  - `[CANCEL]` — left, default focus on entry, BQA Blue `#1B3A6B` fill, Parchment text, 100 × 24 px (smaller than modal buttons; in-card scale)
  - `[CONFIRM]` — right, PHANTOM Red `#C8102E` fill (attention color), Parchment text, 100 × 24 px
  - Inter-button gap 12 px; centered horizontally within card
- 2 px Parchment focus border on focused button (CANCEL by default)

This in-card confirm REPLACES the slot's normal OCCUPIED rendering for the duration. Other slots in the grid are unaffected — they remain in their normal states with `process_input = true`.

### ASCII Wireframe

**1080p baseline; entered from Pause Menu (folder bottom-right). Grid replaces button stack inside folder.**

```
┌──────────────────────────────────────────────────────────────────────┐
│ [GAMEPLAY FRAMEBUFFER VISIBLE BEHIND 52% INK BLACK OVERLAY]          │
│                                                                      │
│                                                  ┌──┤TAB├─┐          │
│                                                  │ STERLING│          │
│                                          ┌───────┤ E. ─── ├─────────┐│
│                                          │       └─────────┘        ││
│                                          │                          ││
│                                          │  File Dispatch           ││ ← B.1 title
│                                          │  ────────────────────    ││
│                                          │                          ││
│                                          │  ┌──────────┐ ┌────────┐ ││ ← row 0
│                                          │  │ Disp 1   │ │ Disp 2 │ ││  slot 1    slot 2
│                                          │  │ Plaza    │ │ Lower  │ ││
│                                          │  │ 14:23    │ │ 13:55  │ ││
│                                          │  │   FILED  │ │ FILED  │ ││
│                                          │  └──────────┘ └────────┘ ││
│                                          │  ┌──────────┐ ┌────────┐ ││ ← row 1
│                                          │  │ Disp 3   │ │ VACANT │ ││  slot 3    slot 4
│                                          │  │ Restau.  │ │ Disp 4 │ ││
│                                          │  │ 12:08    │ │ ----   │ ││
│                                          │  │   FILED  │ │ VACANT │ ││
│                                          │  └──────────┘ └────────┘ ││
│                                          │  ┌──────────┐ ┌────────┐ ││ ← row 2
│                                          │  │ DOSSIER  │ │ VACANT │ ││  slot 5    slot 6
│                                          │  │ CORRO.   │ │ Disp 6 │ ││
│                                          │  │ Disp 5   │ │ ----   │ ││
│                                          │  └──────────┘ └────────┘ ││
│                                          │  ┌──────────┐             ││ ← row 3 (slot 7 alone)
│                                          │  │ VACANT   │             ││  slot 7
│                                          │  │ Disp 7   │             ││
│                                          │  │ ----     │             ││
│                                          │  └──────────┘             ││
│                                          │                          ││
│                                          └──────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

**With slot 3 in CONFIRM_PENDING:**

```
                                          │  ┌──────────┐ ┌────────┐ ││
                                          │  │ Overwrite│ │ VACANT │ ││  slot 3    slot 4
                                          │  │ Dispatch?│ │ Disp 4 │ ││  (in CONFIRM_PENDING)
                                          │  │ ┌──┐ ┌──┐│ │ ----   │ ││
                                          │  │ │CN│ │CF││ │ VACANT │ ││  CN = Cancel (focus)
                                          │  │ └──┘ └──┘│ │        │ ││  CF = Confirm
                                          │  └──────────┘ └────────┘ ││
```

**Reading the wireframe:**
- 3 rows × 2 columns + 1 single-column row (slot 7 alone) = 7 cards.
- Slot 7's row has only column-0; cell (1,3) is empty (no Control rendered).
- In CONFIRM_PENDING, slot 3's body collapses; two buttons appear; focus moves to `[CANCEL]`.
- All other slots remain in their normal states during CONFIRM_PENDING — only slot 3 changes.

**Reduced-motion variant**: A7 paper-shuffle on screen-swap suppressed; cards visible instantly. CONFIRM_PENDING transition (slot's content swap) is also instant (no card-internal tween). A1 + A5 + A6 cues still play.

---

## States & Variants

| State / Variant | Trigger | What changes | Reachability |
|---|---|---|---|
| **Default — grid mounted, post-swap** | Player activated `File Dispatch` button on Pause | 7 cards rendered per `slot_metadata(1..7)`; default focus on last-used slot in-session, else slot 1; grid stays in `Context.PAUSE` | Always (every entry) |
| **Sub-screen swap-in tween** | A7 paper-shuffle 100 ms playing | Outgoing button stack fading; incoming grid fading in; `process_input = false` on cards | First 100 ms |
| **All slots empty** | Mid-section save with no manual saves yet | All 7 cards render in EMPTY state; default focus slot 1; activation triggers immediate save | Cold (first manual save in playthrough) |
| **In-card CONFIRM_PENDING** (per CR-12) | `ui_accept` on an OCCUPIED slot | Slot's content swaps inline; `[CANCEL]` (default focus) + `[CONFIRM]` buttons appear; Tab confined to these two; other slots unaffected | From Default with OCCUPIED slot focused |
| **Saving-in-flight** | Player activated EMPTY slot OR pressed Confirm in CONFIRM_PENDING; SaveLoad.save_to_slot is processing (≤ 10 ms per ADR-0003) | Card briefly disabled visually (opacity 0.85); on success, slot transitions to OCCUPIED with updated metadata; on failure, Save-Failed modal mounts | Sub-frame transient |
| **Save-Failed modal active** | `Events.save_failed` after save attempt | `ModalScaffold.show_modal(SaveFailedContent)`; `Context.MODAL` pushed; grid stays visible underneath but `process_input = false`; player retries / abandons via modal | After failed save |
| **Two-press exit guard** | First `ui_cancel` while card in CONFIRM_PENDING | Card returns to NORMAL OCCUPIED; grid stays open; second `ui_cancel` exits grid | From CONFIRM_PENDING |
| **Reduced-motion variant** | `Settings.accessibility.reduced_motion_enabled == true` | A7 swap visual suppressed; CONFIRM_PENDING transition instant; audio cues still play | Determined at `_ready()` |

**Empty / loading / error states**:
- **Empty state**: covered by individual EMPTY slot cards.
- **Loading state**: not surfaced — saves are < 10 ms.
- **Error state**: Save-Failed modal handles it.

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse (Primary), Gamepad (Partial — full nav, rebind post-MVP)**.

### Grid-level interactions (when no card in CONFIRM_PENDING)

| Action | KB/M binding | Gamepad binding | Immediate feedback | Outcome |
|---|---|---|---|---|
| Move focus between slots | `Right/Left/Up/Down` / `Tab/Shift+Tab` | `JOY_BUTTON_DPAD_*` / left-stick | A4 single-card draw audio | Focus moves per `GridContainer` neighbors. Edge of grid does NOT wrap (matches load-grid OQ-LG-3 default). |
| Activate focused slot — OCCUPIED | `Enter` / `Space` / left-mouse-click | `JOY_BUTTON_A` (`ui_accept`) | A1 typewriter clack 60–80 ms (UI bus) on press; A5 in-card overwrite-confirm enter cue (50–70 ms — single index card turned face-up per Menu System §A.1 row A5) | Card transitions to CONFIRM_PENDING; focus moves to `[CANCEL]` |
| Activate focused slot — EMPTY | Same | Same | A1 clack + A6 stamp thud (no confirm) | `SaveLoad.save_to_slot(N, save_game)` called immediately; slot transitions to OCCUPIED on success |
| Activate focused slot — CORRUPT | Same | Same | (silent — disabled per OQ-LG-4 alignment) | No-op — `disabled = true` |
| Cancel back to Pause | `Esc` | `JOY_BUTTON_B` (`ui_cancel`) | A7 paper-shuffle | Grid swaps back to button stack; focus restores to `File Dispatch` button on Pause root |
| Mouse hover on slot | mouse over | n/a | No visual change (Pillar 5 V.9 #4) | Mouse hover does NOT change focus |

### CONFIRM_PENDING in-card interactions

| Action | KB/M binding | Gamepad binding | Immediate feedback | Outcome |
|---|---|---|---|---|
| Tab between `[CANCEL]` and `[CONFIRM]` | `Tab` / `Shift+Tab` / `Right` / `Left` | `JOY_BUTTON_DPAD_RIGHT` / `_LEFT` / left-stick | (No audio on focus change within in-card) | Focus alternates; **does NOT escape to other slots** (per CR-12 step 4) |
| Activate `[CANCEL]` | `Enter` / `Space` / left-mouse-click | `JOY_BUTTON_A` | A1 clack | Card returns to NORMAL OCCUPIED; focus returns to the card itself |
| Activate `[CONFIRM]` | Same | Same | A1 clack + A6 rubber-stamp thud (UI bus, 90–110 ms — destructive register because overwrite IS destructive intent) | `SaveLoad.save_to_slot(N, save_game)` called; on success, card returns to OCCUPIED with updated metadata |
| Press `Esc` (first press) | `Esc` | `JOY_BUTTON_B` | A1 clack (cancel-feel) | Triggers `[CANCEL]` path — card returns to NORMAL OCCUPIED; grid stays open. **First `ui_cancel` press cancels the in-card confirm; does NOT exit the grid** (per CR-12 step 6) |
| Press `Esc` (second press, with no card in CONFIRM) | `Esc` | `JOY_BUTTON_B` | A7 paper-shuffle | Grid exits; returns to Pause root |

### Two-press exit predicate (per CR-12 + F.5)

```
should_close_save_grid_on_ui_cancel() :=
    NOT (any_card_in_state(CONFIRM_PENDING))
```

If any card is currently in CONFIRM_PENDING, the first `ui_cancel` cancels that card; the grid does NOT exit. The player can press `ui_cancel` again immediately after the cancel to exit, but it is two-press from CONFIRM_PENDING (one to cancel, one to exit).

### Same-frame protection

`set-handled-before-pop` pattern applies at every level — the grid's `_unhandled_input` calls `set_input_as_handled()` BEFORE any state mutation.

### Mouse-mode contract

Inherits `MOUSE_MODE_VISIBLE` from Pause. Sub-screen swap and in-card transitions do not toggle mode.

### Save button "in-flight" guard

Once Confirm is activated, the `[CONFIRM]` button immediately gets `disabled = true` to prevent double-activation. After save resolves (success or failure), card state updates accordingly.

---

## Events Fired

The File Dispatch is a save-trigger surface. It calls Save/Load APIs and consumes Save/Load failure events.

### Direct events fired

| Player Action | Event / Signal Fired | Payload | Bus / Owner | Notes |
|---|---|---|---|---|
| Sub-screen swap-in | (no global signal) | n/a | n/a | Local to Pause Menu |
| Slot focus change | (no signal) | n/a | n/a | A4 audio only |
| Slot activate (OCCUPIED → CONFIRM_PENDING) | (no signal — in-card state change) | n/a | n/a | A5 audio only; no SaveLoad call |
| Confirm activate (CONFIRM_PENDING → save) | `SaveLoad.save_to_slot(N, save_game)` (direct API; Mission Scripting assembles the SaveGame just before this call per Save/Load forbidden-pattern `save_service_assembles_state`) | `slot: int`, `save_game: SaveGame` | SaveLoad autoload | Returns `bool`; emits `Events.game_saved` on success or `Events.save_failed` on failure |
| EMPTY slot activate → save | Same | Same | Same | No CONFIRM_PENDING step |
| Cancel out of grid | (no signal) | n/a | n/a | Sub-screen swap-back |
| Cancel out of CONFIRM_PENDING | (no signal — in-card state revert) | n/a | n/a | A1 clack |

### Audio cues fired (UI bus per Menu System A.2)

| Player Action | Audio cue | Bus | When fires |
|---|---|---|---|
| Sub-screen swap-in / swap-out | A7 paper-shuffle (90–110 ms) | UI | On tween start |
| Slot focus change | A4 single-card draw (30–40 ms) | UI | On focus change |
| Slot activate (any state) | A1 typewriter clack (60–80 ms) | UI | On press |
| OCCUPIED → CONFIRM_PENDING transition | A5 in-card overwrite-confirm enter (50–70 ms) | UI | At state transition |
| Confirm save (overwrite or empty-fill) | A6 rubber-stamp thud (90–110 ms) | UI | At Confirm press, frame 1 of stamp animation |

Per Menu System A.1 row "Save grid CONFIRM (slot save-confirm via in-card `[CONFIRM]`)": A1 typewriter clack covers it — saving to a slot is non-destructive in the "writing to an existing slot is a save, not a destruction" sense per A.1. **However**, the act of overwriting an OCCUPIED slot is destructive intent; A6 stamp thud is the appropriate companion cue. Both A1 and A6 fire on Confirm press (A1 first, A6 layered on at frame 1 of the stamp animation — same frame, both UI bus, no collision).

### Cross-cut audio

| Cue | Owned by | When fires |
|---|---|---|
| `game_saved` chime (~200 ms soft tock) | Audio (subscribed to `Events.game_saved`) | After successful save |
| `save_failed` sting (~400 ms descending minor) | Audio | After failed save |

### Persistent-state-modifying actions

| Action | What it writes | Coord with |
|---|---|---|
| Save (Confirm or EMPTY-direct) | Atomically writes `slot_N.res` + `slot_N_meta.cfg` + `slot_N_thumb.png` per ADR-0003. Also writes to slot 0 (autosave) per Save/Load CR-4. | Save/Load + Mission Scripting (assembles SaveGame) |

> Save/Load is the disk-writer; Menu is the dispatcher of intent. The grid never opens `.res` files directly.

### Telemetry / analytics events

Deferred to post-MVP.

---

## Transitions & Animations

### Sub-screen swap-in / swap-out

Inherited from `load-game-screen.md`. 100 ms paper-shuffle. A7 audio.

### CONFIRM_PENDING in-card transition

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Card content swap | Top text + body lines fade out; `[CANCEL]` + `[CONFIRM]` buttons fade in | `TRANS_LINEAR` | 80 ms | Inline within card; other slots unaffected |
| Focus jump to `[CANCEL]` | (instant — `call_deferred("grab_focus")`) | n/a | 0 ms (next frame) | Focus border 2 px Parchment hard-edge |

**Audio**: A5 in-card overwrite-confirm enter at transition start.

**Reduced-motion**: card content swap suppressed (instant); A5 still plays.

### CONFIRM_PENDING revert (Cancel)

Reverse of above. 80 ms fade. A1 audio.

### Save-confirm stamp slam

Per Menu System §V.7 row 4 — 100 ms scale 0% → 120% → 100% on a virtual stamp graphic that briefly appears over the card on Confirm. Per V.7 row 4: "Rubber-stamp thud audio fires on **frame 1** (the instant the stamp begins moving)."

The stamp slam is a **destructive-confirm-only** animation — it fires on the Confirm press, then dissipates (300 ms total including the slam + fade). The card returns to OCCUPIED state with updated metadata.

**Reduced-motion**: stamp scale tween suppressed; A6 still plays at full duration.

### Motion-sickness audit

Same as Load grid — compliant.

---

## Data Requirements

| Data | Source System | Read / Write | Cardinality | Notes |
|---|---|---|---|---|
| `SaveLoad.slot_metadata(N)` for N ∈ 1..7 | SaveLoad autoload | Read | 7 dictionaries | Sidecar-only |
| `slot_metadata.state` | per slot | Read | 1 enum | Drives card variant |
| `slot_metadata.section_display_name` | Localization | Read | 1 localized string | Same as Load grid |
| `slot_metadata.saved_at_iso8601` | per slot | Read | 1 ISO timestamp | Display formatting |
| Live SaveGame (from Mission Scripting at the moment of save) | Mission Scripting (assembler per Save/Load forbidden-pattern) | Read (one-time) | 1 SaveGame | Mission Scripting builds this just before `SaveLoad.save_to_slot()` |
| Localized title | Localization | Read | 1 string | `menu.save.title` already locked |
| Localized confirm strings | Localization | Read | 4 strings | `menu.save.confirm_overwrite`, `menu.save.overwrite_yes`, `menu.save.overwrite_no`, `menu.save.slot_empty` already locked |
| `Settings.accessibility.reduced_motion_enabled` | SettingsService | Read | 1 bool | Gates A7 + A5 visual tweens |
| `Settings.ui_scale` | SettingsService | Read | 1 float | Inherited via `project_theme.tres` |

### Architectural concerns

- **SaveGame assembly**: per Save/Load forbidden-pattern `save_service_assembles_state`, the SaveGame must be assembled by Mission Scripting (or Failure & Respawn for slot 0 autosave). The save grid does NOT assemble. Implementation note: the `File Dispatch` button's activation handler calls `MissionLevelScripting.assemble_save_game()` (proposed API — see OQ) and passes the result to `SaveLoad.save_to_slot()`.
- **Save target is the focused slot at the moment of Confirm press**, not the slot at CONFIRM_PENDING entry. (These are usually the same — focus stays on the same slot through the in-card flow — but the implementation must read the slot ID at Confirm-press time, not cache it.)
- **In-session "last-used slot" memory** for default focus on grid mount — held in Pause Menu's parent scope, NOT persisted to disk. Lost on Pause `_exit_tree()`. Acceptable per Menu System §C.2 row 8 default focus rule.

### Forbidden data reads

| Data | Why forbidden |
|---|---|
| Full `.res` content of any slot | ADR-0003 — Menu reads sidecar only |
| Slot 0 metadata | Slot 0 is NOT in the Save grid — but the grid never queries slot 0 anyway since it iterates 1–7 |
| Document collection / mission progress | Pillar 5 |

---

## Accessibility

**Tier**: Standard.

Inherits Load grid accessibility. Adds CONFIRM_PENDING-specific patterns.

### Keyboard / Gamepad navigation

- All 7 cards reachable via D-pad / arrow keys / Tab; row-first order.
- CONFIRM_PENDING focus trap: Tab cycles between `[CANCEL]` and `[CONFIRM]` ONLY; cannot escape to other slots until Cancel or Confirm.
- Default focus on grid mount: last-used slot in-session, else slot 1. After Cancel from CONFIRM_PENDING, focus returns to the slot itself.
- Two-press exit rule: ui_cancel from CONFIRM_PENDING cancels the confirm; second ui_cancel exits the grid.

### AccessKit per-widget table

Inherits Menu System §C.9 + adds CONFIRM_PENDING-specific entries:

| Widget | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| Grid root | `grid` | `tr("menu.save.title")` → "File Dispatch" | (none) | `polite` |
| Save card OCCUPIED (NORMAL state) | `button` | `tr("menu.save_card.occupied.name", {...})` → "Dispatch 3. Tour Eiffel niveau 2. 14:23 GMT." | `tr("menu.save_card.occupied.desc")` → "Press to overwrite this dispatch with your current progress." | `off` |
| Save card EMPTY | `button` | `tr("menu.save_card.empty.name", {n})` → "Dispatch 3. Empty — press to file here." | (none — short name is sufficient) | `off` |
| Save card CORRUPT | `button` (`disabled = true`) | per Menu System §C.9 | `tr("menu.save_card.corrupt.desc")` | `off` |
| Save card CONFIRM_PENDING root | `region` | `tr("menu.save.confirm_overwrite", {n})` → "Overwrite Dispatch 3?" | (none) | `polite` (announces transition into confirm state) |
| `[CANCEL]` button (in CONFIRM_PENDING) | `button` | `tr("menu.save.overwrite_no")` → "Cancel" | `tr("menu.save.cancel.desc")` → "Keep the existing dispatch on file." (NEW STRING) | `off` |
| `[CONFIRM]` button | `button` | `tr("menu.save.overwrite_yes")` → "Re-File" | `tr("menu.save.confirm.desc")` → "Replace the existing dispatch with your current progress." (NEW STRING) | `off` |

> **2 NEW STRINGS REQUIRED**: `menu.save.cancel.desc` + `menu.save.confirm.desc`. AccessKit descriptions for the in-card confirm buttons. Both well within Localization L212 cap. Coord with localization-lead.

### CONFIRM_PENDING screen-reader behavior

When player activates an OCCUPIED slot:
1. Card transitions to CONFIRM_PENDING; AT polite live-region announces "Overwrite Dispatch 3?, region"
2. Focus jumps to Cancel button; AT announces "Cancel, button. Keep the existing dispatch on file."
3. Player presses Tab; AT announces "Re-File, button. Replace the existing dispatch with your current progress."
4. Player presses Enter on Cancel; AT announces card returning to OCCUPIED state's name (just the slot identity).

### Visual accessibility

Same as Load grid — inherits Menu System V.9 compliance, contrast pass, color-as-only-indicator pass via shape+stamp differentiation, text-size 75% UI scale floor concerns same as Load grid.

CONFIRM_PENDING-specific:
- `[CANCEL]` BQA Blue and `[CONFIRM]` PHANTOM Red are differentiable in colorblind modes (luminance + position + label). Compliant.
- Default focus on Cancel ensures accidental Confirm-on-Enter doesn't fire — the player must affirmatively navigate to Confirm before pressing Enter.

### Photosensitivity

No flashing. Stamp slam is a 100 ms scale animation, not a brightness flash. WCAG 2.3.1/2.3.2 do not apply.

### Reduced-motion

A7 swap + A5 in-card transition + A6 stamp slam visual tweens all suppressed. Audio cues unchanged.

### Screen-reader walkthrough

1. Player activates File Dispatch button → grid mounts → AT: "File Dispatch, grid"
2. Default focus slot 1 (or last-used) → AT: "Dispatch 1. Plaza. 14:23 GMT. Button. Press to overwrite this dispatch with your current progress."
3. Player Tabs to slot 4 (EMPTY) → AT: "Dispatch 4. Empty — press to file here. Button."
4. Player presses Enter on slot 4 → save fires immediately → A1 + A6 → on success: AT: "Dispatch 4. Restaurant Jules Verne. 14:30 GMT. Button. Press to overwrite this dispatch with your current progress."
5. Player Tabs to slot 3 (OCCUPIED), presses Enter → CONFIRM_PENDING → AT: "Overwrite Dispatch 3?, region. Cancel, button. Keep the existing dispatch on file."
6. Player presses Enter on Cancel → returns to OCCUPIED state → AT: "Dispatch 3. Restaurant. 12:08 GMT. Button. Press to overwrite this dispatch with your current progress."
7. Player presses Esc → grid swap-back to Pause root.

Manual walkthrough at `production/qa/evidence/file-dispatch-screen-reader-[date].md`.

### Accessibility carve-outs

None required.

---

## Localization Considerations

### Strings already locked (Menu System §C.8)

| tr-key | English |
|---|---|
| `menu.save.title` | File Dispatch |
| `menu.save.slot_empty` | — Slot Unoccupied — |
| `menu.save.confirm_overwrite` | Overwrite Dispatch? |
| `menu.save.overwrite_yes` | Re-File |
| `menu.save.overwrite_no` | Cancel |
| `menu.save.card_label` | Dispatch {n} |
| `menu.save.card_location` | {section} — {time} GMT |

### Strings owned by this spec (NEW)

| tr-key | English | English chars | Layout-critical? |
|---|---|---|---|
| `menu.save.cancel.desc` | Keep the existing dispatch on file. | 35 | No (AccessKit desc) |
| `menu.save.confirm.desc` | Replace the existing dispatch with your current progress. | 56 | No (AccessKit desc) |

### Expansion budget

CONFIRM_PENDING in-card buttons are 100 × 24 px. DIN 1451 11 px advance ≈ 5 px per char → ~16 char ceiling per button at 11 px (with 8 px L/R padding → 84 px usable).

| English | EN chars | At 40% expansion | At 60% expansion | Within 16-char limit? |
|---|---|---|---|---|
| `Cancel` | 6 | 8 | 10 | ✅ |
| `Re-File` | 7 | 10 | 11 | ✅ |

Both fit comfortably.

`Overwrite Dispatch?` is the in-card title — 19 chars + slot number; at 40% expansion → ~27 chars. Card width 360 px at 11 px DIN 1451 ≈ 65 char ceiling — generous headroom.

### Number / date / currency formatting

Same as Load grid.

### RTL support

Not committed at MVP+VS.

### Translator brief

- **`Re-File`** is a 1965 BQA bureaucratic register — refiling a dispatch over the existing one. Translator should preserve the "filing-action verb" register, not modern "Save" / "Overwrite".
- **CONFIRM_PENDING title `Overwrite Dispatch?`** is a question — translator preserves question form.

---

## Acceptance Criteria

### Mount & Default State

- [ ] **AC-SG-1.1 [Logic]** Activating `File Dispatch` button on Pause swaps button stack out and 7-slot grid in within 100 ms; `InputContextStack.peek() == Context.PAUSE` (no MODAL push).
- [ ] **AC-SG-1.2 [Logic]** Grid renders 7 cards via `slot_metadata(1..7)`; `GridContainer.columns == 2`; cell `(0,3)` = slot 7; cell `(1,3)` is absent (no Control); slot 0 is NOT present.
- [ ] **AC-SG-1.3 [Logic]** Default focus = last-used slot in-session, else slot 1.
- [ ] **AC-SG-1.4 [Visual]** Title bar reads `File Dispatch`; grid body shows slots 1–7 with appropriate states.
- [ ] **AC-SG-1.5 [Visual]** EMPTY slot text reads `— Slot Unoccupied —` (per `menu.save.slot_empty`), distinct from Load grid's `— No Dispatch On File —`.

### CONFIRM_PENDING Flow

- [ ] **AC-SG-2.1 [Logic]** Activating an OCCUPIED slot transitions only that slot to CONFIRM_PENDING within 1 frame; other slots remain in their normal states; `InputContextStack.peek()` remains `Context.PAUSE` (no MODAL push).
- [ ] **AC-SG-2.2 [Logic]** CONFIRM_PENDING card body shows `Overwrite Dispatch {n}?` title text; the 3 ruled body lines are hidden; `[CANCEL]` (BQA Blue) and `[CONFIRM]` (PHANTOM Red) buttons appear inline.
- [ ] **AC-SG-2.3 [Logic]** Default focus moves to `[CANCEL]` after CONFIRM_PENDING transition completes.
- [ ] **AC-SG-2.4 [Logic]** Tab in CONFIRM_PENDING cycles between `[CANCEL]` and `[CONFIRM]` only — focus does NOT escape to other slots.
- [ ] **AC-SG-2.5 [Logic]** A5 in-card overwrite-confirm enter audio fires at transition start (UI bus, 50–70 ms).
- [ ] **AC-SG-2.6 [Logic]** Pressing `[CANCEL]` (or `ui_cancel` first press while CONFIRM_PENDING) returns the slot to NORMAL OCCUPIED state; focus returns to the slot card; grid stays open.
- [ ] **AC-SG-2.7 [Logic]** Two-press exit: with no card in CONFIRM_PENDING, ONE `ui_cancel` exits the grid. With a card in CONFIRM_PENDING, TWO presses required (first cancels confirm, second exits grid). Verified by F.5 predicate `should_close_save_grid_on_ui_cancel`.

### Save Path

- [ ] **AC-SG-3.1 [Logic]** Activating `[CONFIRM]` in CONFIRM_PENDING calls `SaveLoad.save_to_slot(N, save_game)` for the correct slot N within 1 frame; the SaveGame is assembled by Mission Scripting just before the call (per Save/Load `save_service_assembles_state`).
- [ ] **AC-SG-3.2 [Logic]** Activating an EMPTY slot calls `SaveLoad.save_to_slot(N, save_game)` immediately — no CONFIRM_PENDING transition.
- [ ] **AC-SG-3.3 [Logic]** On save success (`Events.game_saved` fires), the slot transitions to OCCUPIED state with updated metadata (new `section_display_name`, `saved_at_iso8601`); grid stays open.
- [ ] **AC-SG-3.4 [Logic]** On save failure (`Events.save_failed` fires), Save-Failed modal mounts on top of grid; grid `process_input = false`; player retries / abandons via modal.
- [ ] **AC-SG-3.5 [Logic]** Save also writes to slot 0 (autosave) per Save/Load CR-4 — verifiable by inspecting `slot_0.res` mtime after a manual save.
- [ ] **AC-SG-3.6 [Logic]** A1 typewriter clack + A6 rubber-stamp thud both fire on Confirm press; A1 first, A6 layered at frame 1 of stamp animation.
- [ ] **AC-SG-3.7 [Logic]** During save-in-flight (sub-frame), Confirm button has `disabled = true` to prevent double-activation.

### State Variants

- [ ] **AC-SG-4.1 [Logic]** When all 7 slots are EMPTY (first manual save), grid renders 7 EMPTY cards; default focus on slot 1; activation triggers immediate save.
- [ ] **AC-SG-4.2 [Logic]** CORRUPT slot has `disabled = true`; activation produces no effect.

### Navigation & Focus

- [ ] **AC-SG-5.1 [Logic]** D-pad / arrow keys cycle focus through 7 cards in row-first left-to-right order. Edge of grid does NOT wrap.
- [ ] **AC-SG-5.2 [Logic]** Each focus change fires A4 single-card draw audio.
- [ ] **AC-SG-5.3 [Logic]** Tab cycles through 7 cards (NOT just CONFIRM_PENDING buttons; that's a sub-state) in same order as D-pad.
- [ ] **AC-SG-5.4 [Logic]** Pressing Esc from grid top-level (no card in CONFIRM_PENDING) closes the grid; focus restores to `File Dispatch` button on Pause root.

### Audio Invariants

- [ ] **AC-SG-6.1 [Logic]** Sub-screen swap fires A7 paper-shuffle.
- [ ] **AC-SG-6.2 [Logic]** Slot focus change fires A4.
- [ ] **AC-SG-6.3 [Logic]** Slot activation fires A1; OCCUPIED → CONFIRM_PENDING transition adds A5; Confirm press adds A6.
- [ ] **AC-SG-6.4 [Logic]** All save-grid audio cues route to UI bus.
- [ ] **AC-SG-6.5 [Logic]** Audio's `game_saved` chime fires on `Events.game_saved` (~200 ms soft tock, SFX bus, owned by Audio).

### Reduced-Motion

- [ ] **AC-SG-7.1 [Integration]** With reduced-motion enabled, A7 swap visual + A5 CONFIRM_PENDING transition + A6 stamp scale tween all suppressed. Audio cues unchanged.

### AccessKit / Screen Reader

- [ ] **AC-SG-8.1 [Logic]** Grid root has `accessibility_role = "grid"`, `accessibility_name = tr("menu.save.title")`, `accessibility_live = "polite"`.
- [ ] **AC-SG-8.2 [Logic]** Each card has appropriate role + name + description per state mapping.
- [ ] **AC-SG-8.3 [Logic]** CONFIRM_PENDING card root has `accessibility_role = "region"`; AT polite live-region announces transition.
- [ ] **AC-SG-8.4 [Logic]** `[CANCEL]` and `[CONFIRM]` buttons have appropriate AccessKit name + description per NEW STRINGS.
- [ ] **AC-SG-8.5 [UI]** Manual screen-reader walkthrough captured at `production/qa/evidence/file-dispatch-screen-reader-[date].md`.

### Visual Compliance

- [ ] **AC-SG-9.1 [Visual]** No corner radius, no drop shadow, no gradient.
- [ ] **AC-SG-9.2 [Visual]** CONFIRM_PENDING `[CANCEL]` BQA Blue + `[CONFIRM]` PHANTOM Red colors match palette.
- [ ] **AC-SG-9.3 [Visual]** No flashing.

### State Invariants

- [ ] **AC-SG-10.1 [Logic]** During grid lifetime (including CONFIRM_PENDING), `InputContextStack.peek() == Context.PAUSE`. No MODAL push.
- [ ] **AC-SG-10.2 [Logic]** Stack depth never exceeds `[GAMEPLAY, PAUSE]` during the entire save flow (per Menu System §C.5 — "no third Modal context layer is pushed for the overwrite confirm").
- [ ] **AC-SG-10.3 [Logic]** Grid `_exit_tree()` cleans up subscriptions; no orphan signal connections.

### Cross-Reference

- [ ] **AC-SG-11.1 [Spec-trace]** `save-failed-dialog.md` is APPROVED.
- [ ] **AC-SG-11.2 [Spec-trace]** Save/Load AC-2 (manual save also writes to slot 0) is verified by AC-SG-3.5.
- [ ] **AC-SG-11.3 [Spec-trace]** Save/Load AC-14 (slot 0 NOT in Save grid) is verified by AC-SG-1.2.
- [ ] **AC-SG-11.4 [Spec-trace]** Menu System CR-12 + F.5 (in-card overwrite-confirm + two-press exit) is fully implemented.

### Coverage

- Performance: 1 (AC-SG-1.1)
- Navigation: 1 (AC-SG-5.1 — 5.4)
- Error: 1 (AC-SG-3.4 + 4.2)
- Accessibility: 1 (AC-SG-8.1 — 8.5)
- Save-purpose-specific: 1 (AC-SG-2.1 — 3.7)

Total: 36 ACs across 11 groups.

---

## Open Questions

| # | Question | Owner | Resolution Path | Default if unresolved |
|---|---|---|---|---|
| **OQ-SG-1** | **`MissionLevelScripting.assemble_save_game()` API contract.** This spec assumes a synchronous API that returns a SaveGame. Save/Load forbidden-pattern says SaveLoad does NOT assemble. Mission Scripting must — but the API is not specced in Mission GDD yet. | mission-level-scripting GDD owner + lead-programmer | Add API row to Mission Scripting GDD §B before VS sprint kickoff. Sync; cached SaveGame OK if section-stable. | Synchronous API; Mission Scripting holds a cached SaveGame in memory and updates it on relevant in-section signals; save grid pulls the cached value. |
| **OQ-SG-2** | **CORRUPT slot overwriteable?** Save/Load §States L93 says "overwriteable by new save"; this spec treats CORRUPT as `disabled` to avoid implicit overwrite. Should CORRUPT slots be activatable for overwrite (with confirm)? | save-load owner + ux-designer | Decide at `/ux-review`. Overwriting a corrupt slot fixes the problem — but disabling sends "this slot is inert" register. | **MVP+VS: CORRUPT is `disabled` in Save grid.** Player must wait for slot 0 to overwrite via autosave naturally, or use a different slot. Re-evaluate post-launch. |
| **OQ-SG-3** | **In-session "last-used slot" memory across grid open-cancel-reopen cycles.** Should the grid remember the last-touched slot even if the player cancels out and re-enters? | ux-designer | Decide at `/ux-review`. Yes is more usable. | **Yes — last-used slot is in-session memory, held in Pause Menu's parent scope, lost on Pause `_exit_tree()`.** |
| **OQ-SG-4** | **Sub-screen swap audio when entering Save grid is the same A7 as Load grid — is that a problem?** Both surfaces use the same paper-shuffle cue. Could differentiate (paper-shuffle for Load, paper-stamp for Save) — but adds audio complexity. | audio-director + ux-designer | Decide at `/ux-review`. A7 is generic enough for both. | **Same A7 for both grids.** Not a usability problem since the screen content + title disambiguates. |
| **OQ-SG-5** | **CONFIRM_PENDING auto-cancel on focus-loss?** If a sub-modal (e.g., Save-Failed from a previous attempt) mounts while a card is in CONFIRM_PENDING, what happens? | ux-designer + Menu System owner | Most likely: CONFIRM_PENDING state persists; modal renders on top; on modal dismiss, focus restores into the still-active CONFIRM_PENDING. | **CONFIRM_PENDING persists across modal mount-dismiss.** Verify at `/ux-review`. |
| **OQ-SG-6** | **Stamp-slam visual asset.** V.7 row 4 says 100 ms scale 0% → 120% → 100% on a stamp graphic. Where does the stamp graphic appear during the save-confirm? Over the card? Off-card? | art-director + ux-designer | Decide at `/ux-review` + asset-spec. | **Stamp graphic appears centered over the card body** (overlapping the slot's content briefly), then dissipates as card returns to OCCUPIED state. |
| **OQ-SG-7** | **`File Dispatch` button conditional disable when Mission Scripting cannot assemble a SaveGame.** If section is in a save-prohibited state (e.g., mid-cinematic transition that hasn't fully settled), should the Save grid be reachable from Pause but render an error, or should `File Dispatch` button itself be disabled? | mission-level-scripting + ux-designer | Most likely: `File Dispatch` button stays enabled; if assemble fails, save fires `Events.save_failed` and Save-Failed modal mounts. Defensive; consistent with normal save-failure path. | **Button always enabled in Pause; failure routes to Save-Failed modal.** |

---

## Recommended Next Steps

- Run `/ux-review save-game-screen` to validate this spec
- Run `/ux-review` on remaining batch (`save-failed-dialog`, `quicksave-feedback-card`, `load-game-screen`)
- Resolve OQ-SG-1 (Mission Scripting `assemble_save_game()` API) before VS sprint
- Run `/gate-check pre-production` once all UX specs are reviewed

Verdict: **COMPLETE** — save-game-screen UX spec authored from scratch.
