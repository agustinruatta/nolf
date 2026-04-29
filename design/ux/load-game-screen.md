# UX Spec: Operations Archive (Load Game Screen)

> **Status**: In Design
> **Author**: agustin.ruatta@vdx.tv + ux-designer
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: Reachable from Main Menu (cold-boot pre-game) AND Pause Menu (mid-section load → discards current section).
> **Template**: UX Spec
> **Scope**: VS (Vertical Slice) per Menu System §C.2 row 7 + Save/Load §UI Requirements L238.
> **Governing GDDs**: `design/gdd/menu-system.md` (§C.2 row 7 + §C.5 Save Card Grid + §V.2 + §V.3 + §C.8 + §H.9 ACs) + `design/gdd/save-load.md` (§C `OCCUPIED/EMPTY/CORRUPT/AUTOSAVE` slot states + §UI Requirements L238 + `slot_metadata()` API L248) + `design/gdd/level-streaming.md` (LS_FROM_SAVE transition contract).
> **Pattern Inheritance**: `save-load-grid` from interaction-patterns.md (CANONICAL) — this spec is the load-game-specific instantiation; the grid pattern is the shared chrome with `save-game-screen.md`.

---

## Purpose & Player Need

The Operations Archive is the **player's window into their saved progress** — the 8-slot grid where the player picks a previously-filed dispatch (save) to resume from. It is the load-game surface, distinguishable from the save-game surface by the presence of slot 0 (autosave) and the irreversibility-on-confirm contract.

> **Player goal**: *"Show me my saves; let me pick one; load me into that operation exactly where I left off."*

**What goes wrong if this surface is missing or hard to use:**
- Player cannot resume from an old session — Main Menu's Continue button only reaches slot 0; manual saves are unreachable. **Critical break.**
- Player accidentally loads a slot and loses their current section's progress without warning — Pillar 5 says no nag-modal but the destructive-warning-via-AccessKit-description must be unambiguous.
- Player cannot tell which slot is their most-recent / autosave / corrupt — visual differentiation is missing.
- Player's screen reader does not announce the slot's section + timestamp + state — accessibility break.

**Distinguishing constraints**:
- **8 slots: 0 = autosave + 1–7 manual** (Save/Load CR-3). Slot 0 is visible per Save/Load AC-13 — NOT hidden.
- **Read-only screen**: this surface only loads. Saves go to `save-game-screen.md`. The Operations Archive does NOT offer an "overwrite" path; selecting an OCCUPIED slot triggers load, not save.
- **Available from BOTH Main Menu and Pause Menu** (Menu System §C.2 row 7 — "Child of MainMenu OR child of PauseMenu"). The interaction is identical; only the dismiss path differs (back to Main Menu root vs. back to Pause root).

**Pillar fit:**
- **Primary 5 (Period Authenticity)**: each slot is a typed BQA dispatch card with carbon-copy register, classification stamps (`FILED` / `VACANT` / `DOSSIER CORROMPU` / `AUTO-FILED`), section name in French period typeset (`TOUR EIFFEL — NIVEAU 2 — 14:23 GMT`). Not modern thumbnails-with-progress-bars.
- **Anti-Pillar (NOT modern UX paternalism)**: no quick-load shortcuts on this screen. F9 still works at the gameplay layer but doesn't appear on this surface. No "delete slot" button — slots are overwriteable but not deletable (Pillar-5 BQA register: bureaucracies don't shred files).

---

## Player Context on Arrival

The player arrives **voluntarily**, after explicitly choosing the Load Game / Operations Archive option:

| Vector | Trigger | Player state on arrival |
|---|---|---|
| From Main Menu — pre-game | Player clicked `Operations Archive` button on Main Menu (`menu.main.load_game`) | Calm + procedural. No current operation in progress. Picking a slot has zero cost — they will simply enter the chosen save's section. |
| From Pause Menu — mid-section | Player clicked `Operations Archive` button on Pause Menu (`menu.pause.load`) | Frustrated + recovery-seeking (most common — failed stealth attempt → load earlier save) OR exploratory (curious about what other saves exist). Picking a slot has destructive cost — current section progress is lost. |
| Returning from a sub-tab — n/a | (Operations Archive has no sub-tabs) | n/a |

**Emotional state assumptions** (priority order):
1. **Recovery-seeking** — frustrated player after a stealth break wants to reload fastest. Default focus on slot 0 (most-recent / autosave) lets one keypress + `ui_accept` recover.
2. **Calm-procedural** — Main Menu cold-boot. Slot 0 default focus is acceptable; player may navigate to a manual slot via D-pad / arrow keys.
3. **Exploratory** — "what's in slot 5? when did I save that?". Card metadata (section + timestamp + thumbnail) tells the story.
4. **Cautious** — entered from Pause; aware that load destroys current progress. The accessibility_description warns "Current unsaved progress is lost" (per Menu System §C.8 `menu.pause.load.desc`).

**Held inputs**: typically none — the player navigated through Pause / Main Menu menu buttons to get here. KB+M cursor is `MOUSE_MODE_VISIBLE`. Gamepad is in menu-nav mode.

---

## Navigation Position

Operations Archive is a **sub-screen swap** within Main Menu or Pause Menu — it does NOT push a new InputContext (per Menu System §C.2 row 7).

```
[Main Menu (Context.MENU)]
    └── Operations Archive sub-screen swap (still Context.MENU)
        └── (slot pick) → LS push(LOADING) → transition_to_section(section_id, save_data, LOAD_FROM_SAVE)
                                              → MainMenu tree destroyed by LS

[Pause Menu (Context.PAUSE)]
    └── Operations Archive sub-screen swap (still Context.PAUSE)
        └── (slot pick) → LS push(LOADING) → transition_to_section(section_id, save_data, LOAD_FROM_SAVE)
                                              → PauseMenu + section trees destroyed by LS
```

**Stack depth unchanged from parent**: `[GAMEPLAY, PAUSE]` (when entered from Pause) or `[MENU]` (when entered from Main Menu). The grid is a child swap of the existing surface.

**Returning**: `ui_cancel` returns to parent menu root. Focus restores to the triggering button (`Operations Archive` button) per Menu System §C.2 row 7 dismiss path.

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Main Menu → Operations Archive button | `menu.main.load_game` activated | `Context.MENU`; cold-boot game state; `slot_metadata()` calls hydrate before render |
| Pause Menu → Operations Archive button | `menu.pause.load` activated | `Context.PAUSE`; live section state in memory; player aware of destructive-load implication via AccessKit description |
| Same context return after sub-modal cancel | (no sub-modals on this screen — Save-Failed could mount if `Events.save_failed` fires from a previous failed save attempt that surfaces here, but that's an edge case) | n/a |

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| Back to parent menu root | `ui_cancel` (`Esc` / `JOY_BUTTON_B`) at grid top level | Reversible; returns to Main Menu / Pause Menu root with focus on the triggering button |
| **Load slot → LS LOAD_FROM_SAVE** (irreversible) | `ui_accept` on an `OCCUPIED` or `AUTOSAVE` slot | A8 modal-appear (or A6 stamp thud — depending on no-confirm-modal decision per OQ); calls `SaveLoad.load_from_slot(N)` → `LS push(LOADING)` → `LS.transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)`. Mainly destroys current scene trees; player lands in the loaded section. **Irreversible from this UI** |
| Cancel-on-`CORRUPT` slot | `ui_accept` on a `CORRUPT` slot | No-op — slot is `disabled`; activation produces no effect (per Menu System §C.5 CORRUPT row). Focus stays on the slot. |
| Cancel-on-`EMPTY` slot | `ui_accept` on an `EMPTY` slot | No-op in the Operations Archive (Empty slots are NOT loadable). Per Menu System §C.5 EMPTY row in Load grid context — `disabled = true`. |

### Irreversible exit warnings

- **Slot pick → load**: destroys current section's unsaved progress (when entered from Pause). The destructive warning is communicated via:
  - The `Operations Archive` button's `accessibility_description` on Pause Menu: *"Load a previously filed dispatch. Current unsaved progress is lost."* (Menu System §C.8 `menu.pause.load.desc`)
  - The slot card's `accessibility_description` on activation: *"Press to load this dispatch."* (Menu System §C.9 — TBD whether destructive register is added; flag in OQ)
- **No load-confirm modal at MVP+VS** — Save/Load §C.5 sketch specifies "load immediately" (no confirmation). The same one-press semantic that applies to F9 quickload applies here. Coord with Pillar-5 register: confirmation modals on every load would add bureaucratic friction inconsistent with the rapid-recovery use case.

---

## Layout Specification

### Information Hierarchy

| Rank | What the player must see | Why it ranks here | How it is communicated |
|---|---|---|---|
| 1 | "**These are your saves.**" (grid identity) | Without this, the player doesn't know the screen is the load surface | Title bar text `Operations Archive` (`menu.load.title`) at top of folder/page interior; 8-slot grid populated with cards |
| 2 | Each slot's **state** (OCCUPIED / EMPTY / CORRUPT / AUTOSAVE) | Drives the player's pick — they want a non-empty, non-corrupt slot | Per-card visual differentiation per Menu System §C.5: OCCUPIED = full Parchment + `FILED` stamp; EMPTY = 30% dimmed + `VACANT` stamp; CORRUPT = cooler off-white + PHANTOM Red `DOSSIER CORROMPU` diagonal; AUTOSAVE = OCCUPIED + 2 px BQA Blue left border + `AUTO-FILED` stamp |
| 3 | Each slot's **section name + timestamp** | Distinguishes between similar-looking slots | Card line 1 = `DISPATCH 03`; card line 2 = `TOUR EIFFEL — NIVEAU 2 — 14:23 GMT` |
| 4 | (Optional) Each slot's **screenshot thumbnail** | Visual reinforcement of "where" the save is | Per Save/Load §Visual L232 — 320×180 PNG generated at save time. Rendering: card body or supplemental hover-preview. **DEFERRED to OQ** — V.2 spec doesn't include thumbnail render area on the 360×96 card; thumbnails are listed in Save/Load §UI but the integration is not visually specced. |
| 5 | (Implicit) **Default focus** on slot 0 | Drives recovery-fast path | Slot 0 (Autosave) gets focus on screen mount via `call_deferred("grab_focus")`; user-visible 2 px Parchment focus border |

**Categorically NOT shown** (per Pillar 5):
- "Last played" overall date / total play time
- Difficulty level / mode
- Player health / inventory at save time (lives in the loaded scene, not the metadata)
- Document collection counter (FP-DC-2)
- Achievement / progress markers
- Cloud-sync status icons
- "Delete this slot" button (Pillar 5 — bureaucracies file, they don't shred)
- "Rename slot" button (slots are numbered, not named — period register)

### Layout Zones

The grid renders inside the **same folder interior** as the parent menu (Pause folder bottom-right OR Main Menu shell layout). The button stack hides; the grid takes its place.

```
ZONE A — (parent menu's overlay + folder remain visible)
ZONE B — Page interior (760 × 720 minus margins per parent context)
  ├── B.1 — Title bar (`Operations Archive`)
  ├── B.2 — 8-slot 2×4 GridContainer (726 × 402 px footprint)
  └── B.3 — (no buttons — grid is the entire interactive surface)
```

**Anchor specification (1080p baseline)** — inherited from Pause Menu V.1 / Main Menu's equivalent layout:

| Zone | Anchor | Size | Position | Z-order |
|---|---|---|---|---|
| B.1 — Title bar | Top of page interior | ~720 × 36 px | centered at top | inherits parent (CanvasLayer 8) |
| B.2 — Grid | Centered in page interior | 726 × 402 px (2×360 + 6 H × 4×96 + 18 V) | inter-card gap 6 H × 6 V; vertically centered below title | inherits |

When entered from **Pause Menu** (folder bottom-right), the grid lives inside the folder. When entered from **Main Menu**, the grid replaces the Main Menu's button stack in the equivalent layout zone (Main Menu `main-menu.md` already specs its own layout).

### Component Inventory

| Component | Type | Asset / Theme | Interactive? | Pattern |
|---|---|---|---|---|
| Title bar Label | `Label` | DIN 1451 Engschrift 14 px Ink Black; centered horizontally; text = `tr("menu.load.title")` → `Operations Archive` | No | n/a |
| GridContainer | `GridContainer` | `columns = 2`; `h_separation = 6`; `v_separation = 6` | (container — focusable through children) | n/a |
| 8 × Save Card (one per slot) | `Button` (or `PanelContainer` w/ `Button` child for activation) | 360 × 96 px per V.2; state-specific assets per Menu System V.8 | Yes — `ui_accept` activates load (or no-op for EMPTY/CORRUPT) | `save-load-grid` |
| Slot 0 differentiator (AUTOSAVE state) | 2 px BQA Blue left-border accent + `AUTO-FILED` stamp asset | per V.2 | n/a (visual only) | n/a |

### Card variant rendering

Per Menu System §C.5 + V.2:

| State | Card body | Stamp | Color | Focus / activation |
|---|---|---|---|---|
| **OCCUPIED** | `DISPATCH 03` line 1 + `TOUR EIFFEL — NIVEAU 2 — 14:23 GMT` line 2 + 3 ruled body lines (40% opacity, suggesting redacted typed content) | `FILED` Ink Black 45% bottom-right | Parchment `#F2E8C8` | Focus enabled; activation = load |
| **EMPTY** | Centered `— No Dispatch On File —` (per `menu.load.slot_empty`) | `VACANT` Ink Black 25% | 30% dimmed Parchment via `modulate` | Focus enabled (announced as available); activation = no-op (`disabled = true` for Load grid) |
| **CORRUPT** | `████ ████ ████` redacted body lines with 2 px tear-marks | `DOSSIER CORROMPU` PHANTOM Red diagonal at −20° | Cooler off-white `#E8E0D0` | Focus enabled; `disabled = true`; AccessKit announces "*File damaged.*" |
| **AUTOSAVE** (slot 0 only) | `SAUVEGARDE AUTO — TOUR EIFFEL — NIVEAU 2 — 14:23 GMT` (header reads autosave register) | `AUTO-FILED` BQA Blue 45% | Parchment + 2 px BQA Blue left-border accent | Standard load behavior |

### ASCII Wireframe

**1080p baseline; entered from Pause Menu (folder bottom-right). Grid replaces the button stack inside the folder.**

```
┌──────────────────────────────────────────────────────────────────────┐
│ [GAMEPLAY FRAMEBUFFER VISIBLE BEHIND 52% INK BLACK OVERLAY]          │
│                                                                      │
│                                                                      │
│                                                  ┌──┤TAB├─┐          │
│                                                  │ STERLING│          │
│                                          ┌───────┤ E. ─── ├─────────┐│
│                                          │       │OPÉRATION │       ││
│                                          │       └─────────┘        ││
│                                          │                          ││
│                                          │  Operations Archive      ││ ← B.1 title
│                                          │  ────────────────────    ││
│                                          │                          ││
│                                          │  ┌──────────┐ ┌────────┐ ││ ← row 0
│                                          │  │AUTO-FILED│ │ Disp 1 │ ││
│                                          │  │ Plaza    │ │ Lower  │ ││  slot 0    slot 1
│                                          │  │ 14:23 GMT│ │ 13:55  │ ││
│                                          │  └──────────┘ └────────┘ ││
│                                          │  ┌──────────┐ ┌────────┐ ││ ← row 1
│                                          │  │ Disp 2   │ │ Disp 3 │ ││
│                                          │  │ Restaur. │ │ Upper  │ ││  slot 2    slot 3
│                                          │  │ 12:08    │ │ 18:45  │ ││
│                                          │  └──────────┘ └────────┘ ││
│                                          │  ┌──────────┐ ┌────────┐ ││ ← row 2
│                                          │  │ VACANT   │ │ DOSSIER│ ││
│                                          │  │ Disp 4   │ │ CORRO. │ ││  slot 4    slot 5
│                                          │  │ ----     │ │ Disp 5 │ ││
│                                          │  └──────────┘ └────────┘ ││
│                                          │  ┌──────────┐ ┌────────┐ ││ ← row 3
│                                          │  │ VACANT   │ │ VACANT │ ││
│                                          │  │ Disp 6   │ │ Disp 7 │ ││  slot 6    slot 7
│                                          │  │ ----     │ │ ----   │ ││
│                                          │  └──────────┘ └────────┘ ││
│                                          │      ↑                   ││
│                                          │   default focus          ││
│                                          │   (slot 0 AUTO-FILED     ││
│                                          │    with 2 px BQA Blue    ││
│                                          │    left border accent)   ││
│                                          └──────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

**Reading the wireframe:**
- Title `Operations Archive` at top of page interior in DIN 1451 14 px.
- 4 rows × 2 columns of save cards. Slot 0 (AUTOSAVE) at top-left with BQA Blue left-border accent. Slots 1–7 fill row-first.
- Each card shows section name + GMT timestamp on line 2. Card line 1 is `DISPATCH N` (or `SAUVEGARDE AUTO` for slot 0).
- Empty slots render `— No Dispatch On File —` centered, dimmed Parchment background.
- Corrupt slots render PHANTOM Red `DOSSIER CORROMPU` diagonal stamp + black bar redacted body lines.
- Default focus = slot 0 (with focus border).

**Reduced-motion variant**: card swap-in tween (A7 paper-shuffle 100 ms) suppressed when entering the screen; cards visible at full opacity instantly. Audio cue still plays.

---

## States & Variants

| State / Variant | Trigger | What changes | Reachability |
|---|---|---|---|
| **Default — grid mounted, post-swap** | Player activated `Operations Archive` button on parent menu | 8 cards rendered per `slot_metadata(N)` for each slot; default focus on slot 0 (AUTOSAVE state if present, else first OCCUPIED, else slot 0 EMPTY) | Always |
| **Sub-screen swap-in tween** | A7 paper-shuffle 100 ms playing | Outgoing button stack fading; incoming grid fading in; both `process_input = false` | First 100 ms |
| **All slots empty** | Cold boot, no saves yet | All 8 cards render in `EMPTY` state; activation no-op everywhere | Cold-boot edge case |
| **Slot 0 corrupt** | `slot_metadata(0)` returns `state == CORRUPT` | Slot 0 renders CORRUPT; Continue button on Main Menu falls through to `Begin Operation` per AC-MENU-3.3; **load grid still shows slot 0 as CORRUPT card with disabled activation** | F&R / autosave failure scenario |
| **Loading-in-flight** | Player activated an OCCUPIED slot; SaveLoad.load_from_slot is processing (≤ 2 ms I/O) | All cards `disabled = true` momentarily; LS push(LOADING) is imminent | Sub-frame transient |
| **LS transition starting** | `LS.transition_to_section()` called | Grid + parent menu trees about to be destroyed; LS fade-to-black (CanvasLayer 127) appearing | After load triggers |
| **`Events.save_failed` mid-render** (rare — could fire if a previous failed save's modal was queued and surfaces during this screen) | `save_failed` arrives | ModalScaffold mounts SaveFailedContent on top of grid; `Context.MODAL` pushed; grid stays visible underneath but `process_input = false` | Edge case |
| **Reduced-motion variant** | `Settings.accessibility.reduced_motion_enabled == true` | A7 paper-shuffle visual suppressed (audio still plays); card swap is instant | Determined at `_ready()` |

**Empty / loading / error states**:
- **Empty state**: covered by individual EMPTY slot cards. The grid as a whole is never empty (always renders 8 cards).
- **Loading state**: not surfaced — load is < 2 ms; no spinner.
- **Error state**: a load failure mounts the Save-Failed dialog modal (`save-failed-dialog.md`).

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse (Primary), Gamepad (Partial — full nav, rebind post-MVP)**.

### Grid interactions

| Action | KB/M binding | Gamepad binding | Immediate feedback | Outcome |
|---|---|---|---|---|
| Move focus to next slot horizontal | `Right` / `Tab` | `JOY_BUTTON_DPAD_RIGHT` / left-stick-right | A4 single-card draw audio (30–40 ms, UI bus, 8–10 dB below confirm cue) | Focus moves to next slot per `GridContainer` focus-neighbor wiring |
| Move focus to next slot vertical | `Down` | `JOY_BUTTON_DPAD_DOWN` / left-stick-down | A4 audio | Focus moves to slot directly below |
| Wrap-around / edge handling | (per `GridContainer.focus_mode = FOCUS_ALL`) | (same) | (no audio at boundary) | Edge of grid does NOT wrap to opposite edge by default — focus stays on edge slot until D-pad is pressed in the opposite direction. (Coord with art-director / ux-designer on whether wrap is desirable; flag in OQ) |
| Activate focused slot | `Enter` / `Space` / Left mouse button click | `JOY_BUTTON_A` (`ui_accept`) | A1 typewriter clack 60–80 ms (UI bus) on press; pressed-state visual: opacity 0.85 for 30 ms; A6 stamp thud + Audio's `game_loaded` cue (or no game_loaded cue per Audio L168) on confirm | OCCUPIED/AUTOSAVE: load fires; LS transition starts. EMPTY/CORRUPT: no-op. |
| Cancel back to parent menu | `Esc` | `JOY_BUTTON_B` (`ui_cancel`) | A7 paper-shuffle (90–110 ms, UI bus); button stack swap-back tween starts | Grid `_exit_tree()`s; button stack returns; focus restores to `Operations Archive` button on parent menu |
| Mouse hover over slot | mouse over | n/a | No visual change (Pillar 5 V.9 #4) | Mouse hover does NOT change focus |
| Mouse click on slot | left mouse button down on slot bounds | n/a | A1 clack + activation outcome | Focus + activate in one press |

### Per-slot activation outcomes

| Slot State | Outcome on activate |
|---|---|
| **OCCUPIED** | A1 clack + A6 stamp thud; `SaveLoad.load_from_slot(N)` called; on success, `LS push(LOADING)` + `LS.transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)`; on failure, `Events.save_failed` fires → Save-Failed modal mounts on top |
| **AUTOSAVE** (slot 0) | Same as OCCUPIED |
| **EMPTY** | A1 clack (cancel-feel) — but no load; per V.2 EMPTY row in Load grid context, the card has `disabled = true`; activation produces no effect (perhaps no audio either to avoid false-confirm; coord with audio-director — flag in OQ) |
| **CORRUPT** | `disabled = true`; activation produces no effect; AccessKit announces "*File damaged.*" |

### Mouse-mode contract

Operations Archive inherits `MOUSE_MODE_VISIBLE` from parent menu. No mode flip on entry or exit.

### Same-frame protection

Per Menu System §C.6: every dismiss handler calls `set_input_as_handled()` BEFORE pop / sub-screen swap. Pattern: `set-handled-before-pop`.

### Load button "in-flight" guard

Once `ui_accept` activates an OCCUPIED slot, the slot's `disabled = true` is set immediately to prevent double-activation. All other slots also disable to prevent rapid Tab-Enter spam from triggering multiple load attempts. This is a 1-2 frame transient before LS push(LOADING) takes over.

---

## Events Fired

The Operations Archive is a load-trigger surface. It calls Save/Load + Level Streaming APIs.

### Direct events fired

| Player Action | Event / Signal Fired | Payload | Bus / Owner | Notes |
|---|---|---|---|---|
| Sub-screen swap-in | (no global signal) | n/a | n/a | Local to parent menu |
| Slot focus change | (no global signal) | n/a | n/a | A4 audio cue only |
| Slot activate (OCCUPIED / AUTOSAVE) | `SaveLoad.load_from_slot(N)` (direct API) | `slot: int` | SaveLoad autoload | Returns `SaveGame` or null |
| Load success | `LS.push(LOADING)` then `LS.transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)` | section_id, save_data | Level Streaming | LS emits `section_transition_started` |
| Load failure | (Save/Load autonomously emits `Events.save_failed`) | reason, slot | Events autoload (Save/Load publishes) | Triggers Save-Failed modal mount |
| Cancel out | (no global signal) | n/a | n/a | Sub-screen swap-back animation |

### Audio cues fired (UI bus per Menu System A.2)

| Player Action | Audio cue | Bus | When fires |
|---|---|---|---|
| Sub-screen swap-in | A7 paper-shuffle (90–110 ms) | UI | On swap tween start |
| Sub-screen swap-out (cancel) | A7 paper-shuffle | UI | On swap-back tween start |
| Slot focus change | A4 single-card draw (30–40 ms) | UI | On focus change |
| Slot activate | A1 typewriter clack (60–80 ms) | UI | On press |
| Load confirm (irreversible) | A6 rubber-stamp thud (90–110 ms) | UI | At load activation |

### Cross-cut audio

| Cue | Owned by | When fires |
|---|---|---|
| `game_loaded` — none (per Save/Load §No direct interaction L168) | Audio | n/a |
| `save_failed` sting (~400 ms, descending minor) | Audio | If load fails |

### Persistent-state-modifying actions

| Action | What it writes | Coord with |
|---|---|---|
| Load slot | Mutates in-memory `SaveGame` resource; triggers LS scene transition that destroys current section trees and instantiates target section | Save/Load + Level Streaming |

> No disk writes from this screen. Load is read-only at the disk layer.

### Telemetry / analytics events

Deferred to post-MVP.

---

## Transitions & Animations

### Sub-screen swap-in (button stack → grid)

Per Menu System §V.7 row 6 (screen-shuffle paper transition):

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Outgoing button stack `position.x` | translates 20 px left | `TRANS_LINEAR` | 100 ms | per V.7 |
| Outgoing button stack `modulate.a` | 1 → 0 | `TRANS_LINEAR` | 100 ms | concurrent |
| Incoming grid `position.x` | from 20 px right of rest → rest | `TRANS_LINEAR` | 100 ms | concurrent |
| Incoming grid `modulate.a` | 0 → 1 | `TRANS_LINEAR` | 100 ms | concurrent |

**Audio**: A7 paper-shuffle at tween start.

**Reduced-motion**: outgoing hides instantly; incoming shows instantly. A7 still plays.

### Sub-screen swap-out (cancel → button stack)

Reverse of swap-in. 100 ms total. A7 plays.

### Card focus change

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Focus border `modulate.a` (or shader overlay) | 0 → 1 on focused card; 1 → 0 on previously focused | (instant) | 0 ms | V.9 #2 — focus is hard-edge 2 px Parchment border, not a glow tween |

A4 audio cue plays on every focus change.

### Card activation (no animation)

Activation triggers immediate state change (disable + load call). No card-level animation; A1 + A6 audio plus LS fade-to-black handles the visual.

### LS fade-to-black takeover

Once `LS.transition_to_section()` is called, Level Streaming's CanvasLayer 127 fade-to-black takes over. The grid + parent menu trees are destroyed during the fade. This is owned by Level Streaming, not Menu System.

### Motion-sickness audit

- No camera movement.
- 100 ms paper-shuffle is well below WCAG 2.3.1 thresholds.
- No flashing, no looping animation, no parallax.

Compliant.

---

## Data Requirements

| Data | Source System | Read / Write | Cardinality | Notes |
|---|---|---|---|---|
| `SaveLoad.slot_metadata(N: int)` for N ∈ 0..7 | SaveLoad autoload | Read | 8 dictionaries | Sidecar-only read per ADR-0003 — Menu does not open `.res` for grid render |
| `slot_metadata.state` ∈ {`OCCUPIED`, `EMPTY`, `CORRUPT`, `AUTOSAVE`} | per slot | Read | 1 enum | Drives card variant rendering |
| `slot_metadata.section_display_name` | Localization Scaffold | Read | 1 localized string | e.g., `Tour Eiffel — niv. 2` |
| `slot_metadata.saved_at_iso8601` | per slot | Read | 1 ISO timestamp | Formatted to `14:23 GMT` for display |
| `slot_metadata.elapsed_time_seconds` | per slot | Read | 1 int | Currently NOT displayed at MVP+VS (Pillar 5 — no time-played) — but available in metadata for post-launch consideration |
| `slot_metadata.thumbnail_path` | per slot | Read | 1 path | DEFERRED — V.2 doesn't render thumbnail; flag in OQ |
| Localized title bar | Localization | Read | 1 string | `menu.load.title` already locked |
| `Settings.accessibility.reduced_motion_enabled` | SettingsService | Read | 1 bool | Gates A7 swap tween |

### Architectural concerns

- **Sidecar-only metadata read** — Menu System §C.10 + ADR-0003 forbid Menu from opening `.res`. The grid render path uses only sidecar data.
- **Per-frame cost** — grid renders 8 cards on mount; no `_process()` per-frame work. Total mount time should be < 16 ms on minimum hardware (per Pause Menu AC-PAUSE-2.1 budget).
- **Re-mount on state change** — if a slot is overwritten while the grid is open (which can't happen at MVP+VS — Save grid is a different sub-screen), the grid would need to re-query. This is N/A because user can't have both grids open simultaneously.

### Forbidden data reads

| Data | Why forbidden |
|---|---|
| Full `.res` content of any slot | ADR-0003 absolute — Menu reads sidecar only |
| Document collection state | Pillar 5 — no progress counter on Load grid (FP-DC-2) |
| Player health / inventory snapshot at save time | Pillar 5 — no "save thumbnail with HUD overlay"; not surfaced on grid |
| Achievement / unlock state | Pillar 5 |

---

## Accessibility

**Tier**: Standard.

The Operations Archive uses the `save-load-grid` pattern from interaction-patterns.md. Most accessibility patterns are inherited.

### Keyboard / Gamepad navigation

- **All 8 cards reachable** via D-pad / arrow keys / Tab. Focus order: row-first, left-to-right, top-to-bottom (per `GridContainer` default).
- **Focus trap**: focus stays within grid; cannot escape to gameplay scene behind overlay. `ui_cancel` is the only escape route.
- **Default focus on mount**: slot 0 (AUTOSAVE if present, else first OCCUPIED, else slot 0 EMPTY).
- **Focus restoration on return**: focus returns to `Operations Archive` button on parent menu root via `ModalScaffold-style return_focus_node` semantics (here implemented at Menu System level, not ModalScaffold since this is a sub-screen swap not a modal).

### AccessKit per-widget table

Inherits Menu System §C.9 + adds per-card entries. Per Menu System §C.9 row "Save card OCCUPIED / EMPTY / CORRUPT":

| Widget | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| Grid root | `grid` | `tr("menu.load.title")` → "Operations Archive" | (none) | `polite` (for end-of-list announcements per accessibility-specialist guidance — Menu System §C.2 row 7 note) |
| Title bar Label | `text` | inherits from grid root | (none) | `off` |
| Save card OCCUPIED | `button` | `tr("menu.save_card.occupied.name", {slot, section, time})` → "Dispatch 3. Tour Eiffel niveau 2. 14:23 GMT." | `tr("menu.save_card.occupied.desc.load")` → "Press to load this dispatch." (NEW STRING — load-grid-specific desc, distinct from save-grid's "Press to overwrite") | `off` |
| Save card AUTOSAVE | `button` | `tr("menu.save_card.autosave.name", {section, time})` → "Autosave. Tour Eiffel niveau 2. 14:23 GMT." | `tr("menu.save_card.autosave.desc.load")` → "Press to load the autosave." (NEW STRING) | `off` |
| Save card EMPTY | `button` (`disabled = true`) | `tr("menu.save_card.empty.name", {slot})` → "Dispatch 3. No file on record." | (none) | `off` |
| Save card CORRUPT | `button` (`disabled = true`) | `tr("menu.save_card.corrupt.name", {slot})` → "Dispatch 3. File damaged. Cannot load." | `tr("menu.save_card.corrupt.desc")` → "This dispatch file is damaged and cannot be opened." | `off` |

> **2 NEW STRINGS REQUIRED**: `menu.save_card.occupied.desc.load` + `menu.save_card.autosave.desc.load`. Distinct from Menu System §C.9's existing `menu.save_card.occupied.desc` (which is save-grid-specific "Press to overwrite this dispatch with your current progress."). Coord with localization-lead.

**Polite live-region** announces when the player navigates to the last card in a row/column ("end of row" or "8 of 8 cards") — accessibility-specialist guidance per Menu System §C.2 row 7 note.

### Visual accessibility

- **Contrast**: per Menu System V.9 #1-#10 + accessibility-requirements.md visual table. Body text Ink Black on Parchment ≈ 14.8:1 (AAA). Stamp colors (PHANTOM Red `DOSSIER CORROMPU` on cooler off-white) audited per CR-25.
- **Color-as-only-indicator**: card states differ in **shape + label + stamp + opacity**, not color alone. CORRUPT card has the diagonal stamp + tear-marks + cooler-tone background — multiple non-color signals (per accessibility-requirements.md "Color-as-Only-Indicator Audit" table). Compliant.
- **Text size**: 11 px DIN 1451 + 10 px American Typewriter at 1080p baseline. At 75% UI scale → 8.25 px DIN / 7.5 px American Typewriter — **violates V.9 #8** floor. Mitigation: clamp grid text to minimum 100% scale (matches save-failed-dialog OQ-SF-3 + pause-menu OQ-PM-4 default resolution).
- **Colorblind**: AUTOSAVE BQA Blue left-border accent + PHANTOM Red CORRUPT diagonal differentiate via simulator-tested luminance + shape. Compliant per accessibility-requirements.md row "Document rarity (Document Collection)".

### Photosensitivity

No flashing on this screen. A7 paper-shuffle is a 100 ms 2D translation, not a brightness change. Compliant.

### Reduced-motion

A7 swap tween suppressed. Audio still plays. Card focus border is hard-edge (no fade), unaffected by reduced-motion.

### Screen-reader walkthrough

1. Player activates `Operations Archive` button on parent menu → grid mounts → AT announces "Operations Archive, grid"
2. Default focus on slot 0 → AT announces "Autosave. Tour Eiffel niveau 2. 14:23 GMT. Button. Press to load the autosave."
3. Player presses Tab → focus on slot 1 → AT announces "Dispatch 1. Lower Scaffolds. 13:55 GMT. Button. Press to load this dispatch."
4. Player navigates to slot 5 (CORRUPT) → AT announces "Dispatch 5. File damaged. Cannot load. Button. Disabled. This dispatch file is damaged and cannot be opened."
5. Player navigates to slot 6 (EMPTY) → AT announces "Dispatch 6. No file on record. Button. Disabled."
6. Player presses Esc → grid swap-back → AT does NOT re-announce parent menu root.

Manual walkthrough at `production/qa/evidence/operations-archive-screen-reader-[date].md`.

### Accessibility carve-outs

None required.

---

## Localization Considerations

### Strings already locked (Menu System §C.8)

| tr-key | English |
|---|---|
| `menu.load.title` | Operations Archive |
| `menu.load.slot_empty` | — No Dispatch On File — |
| `menu.save.card_label` | Dispatch {n} |
| `menu.save.card_location` | {section} — {time} GMT |
| `menu.save.card_slot_zero` | Autosave — {section} |

### Strings owned by this spec (NEW — to be added to Menu System §C.8)

| tr-key | English | English chars | Layout-critical? |
|---|---|---|---|
| `menu.save_card.occupied.desc.load` | Press to load this dispatch. | 28 | No (AccessKit desc) |
| `menu.save_card.autosave.desc.load` | Press to load the autosave. | 27 | No (AccessKit desc) |
| `menu.save_card.empty.name` | Dispatch {n}. No file on record. | 30 + slot id | No (AccessKit name; rendered visually too via slot_empty) |

### Expansion budget

Card body is 360 × 96 px. Card line 2 (`section + time`) at 10 px American Typewriter ≈ 60 char fits one line.

| English | EN chars | At 40% expansion | At 60% expansion |
|---|---|---|---|
| `Tour Eiffel — niveau 2 — 14:23 GMT` | 33 | 46 | 53 |
| `Restaurant Jules Verne — 12:08 GMT` | 33 | 46 | 53 |

Generous headroom.

### Number / date / currency formatting

Timestamp `14:23 GMT` is locale-aware via `slot_metadata.saved_at_iso8601` formatted by Localization. French / German render as `14:23 GMT` (24-hour); locales that prefer 12-hour can format differently.

### RTL support

Not committed at MVP+VS.

### Translator brief

- **Section names** (`Tour Eiffel niveau 2`, `Restaurant Jules Verne`, etc.) are proper nouns — coord with localization-lead on locale-invariance vs. translation.
- **Timestamps** are 24-hour GMT at MVP. Confirm cultural fit per locale.
- **Stamps** (`FILED`, `VACANT`, `DOSSIER CORROMPU`, `AUTO-FILED`) translate as period BQA register stamps.

---

## Acceptance Criteria

### Mount & Default State

- [ ] **AC-LG-1.1 [Logic]** When `Operations Archive` button is activated on parent menu, the button stack swaps out and the grid swaps in within 100 ms (sub-screen swap tween); `InputContextStack.peek()` is unchanged from parent context (`MENU` or `PAUSE`).
- [ ] **AC-LG-1.2 [Logic]** Grid renders 8 cards via `slot_metadata(0..7)`; `GridContainer.columns == 2`; cell `(0,0)` = slot 0; cell `(1,3)` = slot 7 (per Menu System F.1).
- [ ] **AC-LG-1.3 [Logic]** Default focus = slot 0 after the swap tween completes.
- [ ] **AC-LG-1.4 [Visual]** Slot 0 in AUTOSAVE state shows: BQA Blue left-border accent (2 px) + `AUTO-FILED` stamp + section/time line. Evidence: `production/qa/evidence/load-grid-autosave-[date].png`.
- [ ] **AC-LG-1.5 [Visual]** EMPTY slot shows centered `— No Dispatch On File —` text + `VACANT` stamp + 30% dimmed Parchment.
- [ ] **AC-LG-1.6 [Visual]** CORRUPT slot shows redacted `████ ████ ████` body + `DOSSIER CORROMPU` PHANTOM Red diagonal stamp + cooler off-white background `#E8E0D0`.

### Navigation & Focus

- [ ] **AC-LG-2.1 [Logic]** D-pad / arrow keys cycle focus through 8 cards in row-first left-to-right, top-to-bottom order. Edge of grid does NOT wrap (focus stays on edge slot).
- [ ] **AC-LG-2.2 [Logic]** Each focus change fires A4 single-card draw audio cue (UI bus, 30–40 ms).
- [ ] **AC-LG-2.3 [Logic]** Tab cycles focus through 8 cards in same order as D-pad.
- [ ] **AC-LG-2.4 [Logic]** Mouse hover on a card does NOT change focus. Mouse click DOES focus + activate.
- [ ] **AC-LG-2.5 [Logic]** Pressing Esc closes the grid and returns to parent menu's button stack within 100 ms; focus restores to `Operations Archive` button.

### Load Path

- [ ] **AC-LG-3.1 [Logic]** Activating an OCCUPIED slot calls `SaveLoad.load_from_slot(N)` for the correct N within 1 frame; A1 typewriter clack + A6 stamp thud both fire on the UI bus.
- [ ] **AC-LG-3.2 [Logic]** On load success, `LS.push(LOADING)` is called immediately before `LS.transition_to_section(loaded.section_id, loaded, LOAD_FROM_SAVE)`.
- [ ] **AC-LG-3.3 [Logic]** On load failure (`SaveLoad.load_from_slot` returns null AND `Events.save_failed` fires), the Save-Failed modal mounts on top of the grid; grid `process_input = false`; player can retry or abandon via the modal.
- [ ] **AC-LG-3.4 [Logic]** Activating an EMPTY slot produces no effect — `disabled = true`; no SaveLoad call.
- [ ] **AC-LG-3.5 [Logic]** Activating a CORRUPT slot produces no effect — `disabled = true`; AccessKit announces "*File damaged.*"
- [ ] **AC-LG-3.6 [Logic]** After a load activation but before LS transition completes, all 8 cards have `disabled = true` to prevent double-activation.

### State Variants

- [ ] **AC-LG-4.1 [Logic]** When all 8 slots are EMPTY (cold boot), grid renders 8 EMPTY cards; default focus on slot 0; activation no-op everywhere.
- [ ] **AC-LG-4.2 [Logic]** When slot 0 is CORRUPT, grid renders slot 0 as CORRUPT with `disabled = true`; Continue button on Main Menu falls back to "Begin Operation" per AC-MENU-3.3 (not duplicated here).

### Audio Invariants

- [ ] **AC-LG-5.1 [Logic]** Sub-screen swap-in fires A7 paper-shuffle on tween start.
- [ ] **AC-LG-5.2 [Logic]** Each focus change fires A4 single-card draw on focus change.
- [ ] **AC-LG-5.3 [Logic]** Slot activation fires A1 typewriter clack on press; if load fires, A6 stamp thud follows immediately.
- [ ] **AC-LG-5.4 [Logic]** No `game_loaded` audio cue fires (per Save/Load §No direct interaction L168 — Audio plays no SFX on `game_loaded`).
- [ ] **AC-LG-5.5 [Logic]** All Operations Archive audio cues route to UI bus.

### Reduced-Motion

- [ ] **AC-LG-6.1 [Integration]** With reduced-motion enabled, A7 paper-shuffle visual tween suppressed; cards swap instantly. Audio still plays.

### AccessKit / Screen Reader

- [ ] **AC-LG-7.1 [Logic]** Grid root has `accessibility_role = "grid"`, `accessibility_name = tr("menu.load.title")`, `accessibility_live = "polite"`.
- [ ] **AC-LG-7.2 [Logic]** Each save card has `accessibility_role = "button"`, name + description per per-state mapping (OCCUPIED / AUTOSAVE / EMPTY / CORRUPT).
- [ ] **AC-LG-7.3 [Logic]** EMPTY and CORRUPT cards have `disabled = true` reflected in AccessKit (AT announces "Disabled").
- [ ] **AC-LG-7.4 [UI]** Manual screen-reader walkthrough captured at `production/qa/evidence/operations-archive-screen-reader-[date].md`.
- [ ] **AC-LG-7.5 [Logic]** On `NOTIFICATION_TRANSLATION_CHANGED`, all card names and descriptions re-resolve via `tr()`.

### Visual Compliance

- [ ] **AC-LG-8.1 [Visual]** No corner radius, no drop shadow, no gradient on cards or grid container. Per V.9 #1, #2, #3.
- [ ] **AC-LG-8.2 [Visual]** Slot 0 AUTOSAVE state has 2 px BQA Blue `#1B3A6B` left-border accent (verify color palette compliance).
- [ ] **AC-LG-8.3 [Visual]** CORRUPT slot diagonal stamp at -20° with PHANTOM Red `#C8102E`; tear-mark mask asset present on body lines.
- [ ] **AC-LG-8.4 [Visual]** No flashing or strobing.
- [ ] **AC-LG-8.5 [Visual]** Focus border is 2 px Parchment hard-edge (no glow, no shadow, no breathing).

### State Invariants

- [ ] **AC-LG-9.1 [Logic]** During grid lifetime, `InputContextStack.peek()` is unchanged from parent context (no MODAL or other push).
- [ ] **AC-LG-9.2 [Logic]** Grid `_exit_tree()` cleans up subscriptions (none expected — grid is a sub-screen, not a modal — but verify no orphan signal connections).
- [ ] **AC-LG-9.3 [Logic]** Grid does NOT modify any persistent file. Hashing `user://saves/*.res` before-and-after a grid open-cancel cycle: hashes match.

### Cross-Reference

- [ ] **AC-LG-10.1 [Spec-trace]** `save-failed-dialog.md` is APPROVED (Operations Archive depends on it for load-failure surface).
- [ ] **AC-LG-10.2 [Spec-trace]** Save/Load AC-13 (slot 0 visible alongside 1–7 in Load grid) is satisfied.
- [ ] **AC-LG-10.3 [Spec-trace]** Menu System §C.5 (Save Card Grid states) is fully implemented.

### Coverage

- Performance: 1 (AC-LG-1.1 — sub-screen swap timing)
- Navigation: 1 (AC-LG-2.1 — 2.5)
- Error / state variants: 1 (AC-LG-3.4 — 3.5 + 4.1 — 4.2)
- Accessibility: 1 (AC-LG-7.1 — 7.5)
- Load-purpose-specific: 1 (AC-LG-3.1 — 3.6)

Total: 32 ACs across 10 groups.

---

## Open Questions

| # | Question | Owner | Resolution Path | Default if unresolved |
|---|---|---|---|---|
| **OQ-LG-1** | **Load-confirm modal — required or rejected?** Save/Load §C.5 sketch says "load immediately" but `menu.pause.load.desc` warns "Current unsaved progress is lost." Mid-section load is destructive; a confirm modal would prevent accidents. But Pillar 5 + speed-of-recovery says no. | game-designer + ux-designer + creative-director | Decide at `/ux-review`. Accessibility-requirements.md Cognitive row L153 ("Saved-game count + autosave") implies multiple save points reduce cognitive-load on retry — supporting no-confirm. | **No load-confirm modal at MVP+VS.** Destructive warning is communicated via `menu.pause.load.desc` AccessKit and the player's general game-knowledge. |
| **OQ-LG-2** | **Thumbnail rendering on cards.** Save/Load generates 320×180 PNG thumbnails per slot but V.2 doesn't include a thumbnail render area on the 360×96 card. Render thumbnail on hover/focus? Or drop entirely? | art-director + ux-designer | Decide at `/ux-review`. 360×96 card is too small for a 320×180 thumbnail without re-design. | **Drop thumbnail render at MVP+VS.** Re-evaluate post-launch with full Pause Menu redesign. |
| **OQ-LG-3** | **Grid wrap-around on edge navigation.** D-pad-right at the rightmost column — wrap to leftmost or stop? | ux-designer + game-designer | Decide at `/ux-review`. Most stealth-genre games stop at edge (predictable). | **Stop at edge.** No wrap. |
| **OQ-LG-4** | **EMPTY slot click — silent or A1 clack?** Activating EMPTY slot produces no effect; should A1 still play to acknowledge the press, or stay silent (cancel-feel)? | audio-director + ux-designer | Decide at `/ux-review`. Silent-on-disabled is more period-authentic. | **Silent on EMPTY/CORRUPT activation.** No A1 clack. |
| **OQ-LG-5** | **Default focus when slot 0 is CORRUPT.** Should focus move to first OCCUPIED slot, or stay on slot 0 (the "default-position" but disabled card)? | ux-designer + accessibility-specialist | Resolve at `/ux-review`. Most-recent-OCCUPIED slot is the recovery target. | **Default focus = first OCCUPIED slot if slot 0 is CORRUPT or EMPTY**, else slot 0. |
| **OQ-LG-6** | **Section name localization** — `Tour Eiffel — niveau 2` is mixed English/French. Stay locale-invariant or translate? | localization-lead | Translator brief discussion. | **Section names locale-invariant** (proper nouns + period flavor). |
| **OQ-LG-7** | **AccessKit "polite" end-of-row announcement.** When player navigates to last card in row, AT should announce "end of row" — implement as polite live-region update on the grid root, or per-card `accessibility_description` extension? | accessibility-specialist + ux-designer | Coord with accessibility-specialist. | **Polite live-region on grid root.** Updates with "row N of 4" or similar on row crossings. |

---

## Recommended Next Steps

- Run `/ux-review load-game-screen` to validate this spec
- Continue authoring `save-game-screen.md` (paired spec — same grid pattern, in-card overwrite-confirm flow)
- Resolve OQ-LG-1 (load-confirm modal) at `/ux-review`

Verdict: **COMPLETE** — load-game-screen UX spec authored from scratch.
