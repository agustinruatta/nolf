# UX Spec: Pause Menu

> **Status**: In Design
> **Author**: agustin.ruatta@vdx.tv + ux-designer
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: Any in-section gameplay (Plaza / Lower / Restaurant / Upper / Bomb). NOT during cutscenes, document reading, loading transitions, or boot.
> **Template**: UX Spec
> **Scope**: VS (Vertical Slice) per Menu System §C.2 owned-surfaces table + §UI-3 L1468.
> **Governing GDD**: `design/gdd/menu-system.md` (primary) — this spec implements §C.2 PauseMenu shell + §C.6 Esc-Key Discipline + §C.7 InputContext Push/Pop + §V.1 Manila folder + §V.7 Animation choreography + §A.4 No-audio-on-pause-open + §H.2 Pause Menu Lifecycle.
> **Sibling Specs (CANONICAL inheritance)**: `quit-confirm.md` — the Quit-Confirm, Return-to-Registry, Re-Brief, and Save-Failed modal scaffolds rendered FROM Pause Menu inherit the Case File register + accessibility specs from quit-confirm.md without re-specification here.

---

## Purpose & Player Need

The Pause Menu is the player's **only sanctioned in-section interruption surface** that exposes save/load, settings, and abandon-the-mission paths. It exists so the player can step out of the action *without losing their bearing in the section* and re-enter exactly where they paused.

> **Player goal**: *"I need to file a dispatch / open the archive / change a setting / leave the desk — and then return to the moment I was in."*

**What goes wrong if this surface is missing or hard to use:**
- Player cannot save mid-section without abandoning to Main Menu (Save grid is Pause-only per Menu System §C.2).
- Player cannot reach Settings during gameplay (the Personnel File button is mounted on Pause, not the HUD — HUD Core Pillar 5 forbids settings entry on the gameplay frame).
- Player cannot quit cleanly to desktop or Main Menu without a confirm step (destructive flows must route through Case File modals per `quit-confirm.md`).
- Quicksave (F5) / Quickload (F9) are reachable from gameplay directly per Save/Load §C, but their *feedback card* (DISPATCH FILED / DISPATCH LOADED) renders without opening Pause. Pause is not the only persistence surface — but it is the only **manual-slot** surface during a section.

**Distinguishing constraint** — Pause is *attentional, not temporal*. Per AC-MENU-2.1, `get_tree().paused` remains `false` while the menu is open; the gameplay scene continues to tick (audio, AI, ambient). Only `InputContext.PAUSE` gates player input. The player is stepping back from the desk, not stopping time. Pillar 5 (Period Authenticity Over Modernization) — a 1965 BQA dispatcher consulting a folder; the operation continues in the background.

**Pillar fit:**
- **Primary 5 (Period Authenticity)**: the manila folder + tab + carbon-copy paper register replaces all modern menu chrome. No translucent blur, no animated glow, no progress crawl.
- **Primary 3 (Stealth as Theatre)**: pause does not reset the scene; it does not reload AI state; it does not silence music. The mission is *"in progress while the dispatcher consults the file"* — a theatrical pause, not a save-state.
- **Supporting 1 (Comedy Without Punchlines)**: button labels are all bureaucratic register (Resume Surveillance / File Dispatch / Operations Archive / Personnel File / Re-Brief Operation / Return to Registry / Close File). The comedy is the file-clerk register applied to a stealth mission — never a quip.

---

## Player Context on Arrival

The player arrives at Pause **mid-action**, with the section's gameplay state still live behind the manila folder. The arrival is voluntary in MVP+VS scope; there are no game-driven forced pauses (cutscenes use their own context per Cutscenes CR-CMC-7 and *block* the pause action).

| Arrival vector | Trigger | Player state on arrival |
|---|---|---|
| Voluntary mid-action | `Esc` (KB) / `JOY_BUTTON_START` (gamepad) → `pause` action fires while `InputContext.current() == GAMEPLAY` | Mid-stride, mid-stealth, mid-observation. May be holding a movement key (Input GDD §Edge Case L184 — held keys persist across context push); may have a gadget equipped; may be ducking. Section music continues; section ambient continues. |
| Voluntary post-engagement | Same trigger, fired after a guard takedown / document pickup / section objective completion | Slightly elevated — player is in a "successful action" emotional beat and pausing to save. The Pause Menu must not undermine the success feel — no flashing, no scolding-style modal copy. |
| Voluntary pre-failure | Same trigger, fired moments before being detected (player anticipating a stealth break) | Stressed, pause-to-save-and-retry flow — this is the dominant user need for the Save grid. Pause must come up *fast* (F.1 timing budget) and the Save grid must be reachable in ≤2 button presses from Pause root (Resume → File Dispatch → slot). |

**Held inputs across the boundary**: Player Character may be holding `move_forward` when Pause opens. Per Input GDD §Core Rule 8 + Edge Case L184, `MOUSE_MODE_VISIBLE` is pushed by Pause on `_ready()`; the held movement key state persists in the OS layer and re-applies when Pause closes (player resumes running on close — intentional, no smoothing required from this surface; PC GDD owns velocity restore).

**Emotional state assumptions** (in design priority order):
1. **Calm + procedural** — pausing to save / load / configure. Most common.
2. **Stressed + recovery-seeking** — about to be spotted; pausing to load. Save grid + Operations Archive must surface fast.
3. **Distracted + walk-away** — got up from the desk; pause is the "I'll be right back" surface. Closing the modal must restore exactly the input state on resume; no friction.
4. **Closing-out** — pausing to quit at the end of a session. Return-to-Registry / Close File flows must route through `quit-confirm.md` register modals, never one-press destructive.

**The pause is NOT a menu the player is "sent to"** — every arrival is a player-initiated `pause` press from gameplay. (Mission scripting has no path that opens Pause for the player. Cutscenes block pause. Loading transitions block pause.)

---

## Navigation Position

Pause Menu is a **mid-gameplay overlay**, not a screen in the boot navigation tree. It does not replace the gameplay scene — the section scene remains in the tree behind the 52% Ink Black overlay (FP-1 / V.1 / AC-MENU-2.5).

**Position in navigation hierarchy:**

```
[boot] → MainMenu.tscn (Context.MENU)
                ↓ "Begin Operation" / "Resume Surveillance" → LS NEW_GAME / LOAD_FROM_SAVE
[gameplay] → SectionN scene (Context.GAMEPLAY)
                ↓ pause action (Esc / Start)
        ▶ PauseMenu.tscn (Context.PAUSE) — this spec
                ├── Operations Archive sub-screen → load-game-screen.md (inherits PAUSE)
                ├── File Dispatch sub-screen → save-game-screen.md (inherits PAUSE)
                ├── Personnel File button → SettingsService.open_panel() (Context.SETTINGS)
                ├── ModalScaffold (Context.MODAL):
                │     ├── Quit-Confirm → quit-confirm.md (CANONICAL — re-used)
                │     ├── Return-to-Registry-Confirm → quit-confirm.md inheritance — full UX spec at `return-to-registry.md` (APPROVED 2026-04-29)
                │     ├── Re-Brief-Operation-Confirm → quit-confirm.md inheritance (VS+ conditional) — full UX spec at `re-brief-operation.md` (APPROVED 2026-04-29)
                │     └── Save-Failed → save-failed-dialog.md
                └── Resume Surveillance / ui_cancel → pop PAUSE → restore Context.GAMEPLAY
```

**Pause Menu lives at: `[gameplay-section] → Pause`** (single-step depth from any active section).

**Reachability constraints:**
- Pause is reachable **only** from `Context.GAMEPLAY`. Per Menu System CR-3 + AC-MENU-2.3, `PauseMenuController._unhandled_input()` silently consumes `pause` when `peek() != GAMEPLAY` and does NOT mount the menu.
- Pause is **blocked** from these contexts:
  - `Context.LOADING` (Failure & Respawn AC-FR-7.3 / E.13 / Level Streaming LS-Gate-2)
  - `Context.DOCUMENT_OVERLAY` (the Lectern Pause IS the pause for that surface — Document Overlay UI owns its own dismiss)
  - `Context.CUTSCENE` (Cutscenes CR-CMC-7 — cinematic block; Stage-Manager carve-out via `accessibility_allow_cinematic_skip` is the cinematic exit, not pause)
  - `Context.MENU` / `Context.MODAL` / `Context.SETTINGS` / `Context.PAUSE` itself (already in a non-gameplay context)
- Pause is **not** reachable from Main Menu — Main Menu uses `Context.MENU` and Esc at top level does nothing (Menu System §C.6 row 1).

**Sub-screen swap policy** (per Menu System §C.2 row 7+8):
The Operations Archive (Load grid) and File Dispatch (Save grid) sub-screens are **child swaps** within Pause — they do NOT push a new InputContext. The stack remains `[GAMEPLAY, PAUSE]` while the player browses save cards. Only modal confirms (Quit-Confirm, Save-Failed, etc.) push `Context.MODAL` on top of `PAUSE`.

This shallow stack matters: the player can always tell "how deep am I" by counting `Esc` presses — at most 3 from the deepest reachable state (in-card overwrite-confirm → Save grid → Pause root → resume).

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Active gameplay section (Plaza / Lower / Restaurant / Upper / Bomb) | `Esc` (KB) or `JOY_BUTTON_START` (gamepad) → `pause` action fires while `peek() == GAMEPLAY` (Input GDD §C.7 + Menu System CR-3) | Live section scene + Eve's transform + held-key OS state + ammo / health / equipped gadget; `MOUSE_MODE_CAPTURED` (Player Character owns; Pause flips to `MOUSE_MODE_VISIBLE` on `_ready()`) |
| Returning from a sub-screen / modal (not a fresh entry) | `ui_cancel` from Operations Archive / File Dispatch / any Modal child | The sub-screen's selection state is *not* preserved on return (last-used slot is in-session memory only per Menu System §C.2 row 7); focus returns to the triggering button on Pause root |
| Returning from Settings panel | Settings dismiss path (Settings owns `Context.SETTINGS` pop) | Settings was entered from Pause; `peek()` returns to `Context.PAUSE`; focus restores to Personnel File button (AC-MENU-5.2) |

> **Pause Menu has NO** "game-driven" or "scripted" entry. Mission scripting cannot open Pause for the player. Cutscenes block pause. Loading transitions block pause. The player is always the agent of pause arrival.

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Resume gameplay** (most common) | `Resume Surveillance` button activated **OR** `ui_cancel` (`Esc` / `JOY_BUTTON_B`) at Pause root | Reversible. `queue_free()` on PauseMenu instance; pop `Context.PAUSE`; PC re-applies `MOUSE_MODE_CAPTURED`; held movement keys resume action (Input §Edge Case L184). Section state is unchanged. |
| **Settings panel** | `Personnel File` button | Reversible. Settings pushes `Context.SETTINGS` itself (Menu does not push); on dismiss returns to Pause root with focus on Personnel File. |
| **Operations Archive (Load grid)** sub-screen | `Operations Archive` button | Reversible. Sub-screen swap; same `Context.PAUSE`. Selecting a slot triggers `LS LOAD_FROM_SAVE` flow → **destroys Pause + section trees** (irreversible from this surface). Cancel returns to Pause root. |
| **File Dispatch (Save grid)** sub-screen | `File Dispatch` button | Reversible (browse + cancel). Selecting a slot enters in-card overwrite-confirm (CR-12); confirming the save fires `SaveLoad.save_to_slot(N)` and stays on the grid. |
| **Quit-Confirm** modal | `Close File` button | Reversible — Cancel ("Continue Mission") returns; Confirm ("Close File") calls `get_tree().quit()` (irreversible — application exits). Inherits CANONICAL spec from `quit-confirm.md`. |
| **Return-to-Registry-Confirm** modal | `Return to Registry` button | Reversible — Cancel returns; Confirm calls `get_tree().change_scene_to_file(MainMenu.tscn)` after `LS push(LOADING)` per Menu System §C.7 (irreversible from Pause; player lands in Main Menu). **Full UX spec: `design/ux/return-to-registry.md` (APPROVED 2026-04-29).** |
| **Re-Brief-Operation-Confirm** modal | `Re-Brief Operation` button (VS+ scope, conditional visibility — see Open Questions) | Reversible — Cancel returns; Confirm calls `FailureRespawn.restart_from_checkpoint()` (irreversible — checkpoint reload). **Full UX spec: `design/ux/re-brief-operation.md` (APPROVED 2026-04-29).** |
| **Save-Failed** modal (event-driven, not player-initiated) | `Events.save_failed` arrives while Pause is mounted | Modal queued or shown immediately per ModalScaffold C.4 queue policy. Inherits spec from `save-failed-dialog.md`. |
| **Quicksave / Quickload feedback card** (cross-cuts) | `Events.game_saved` / `Events.game_loaded` arrives while Pause is open | Ephemeral overlay on the active surface (Menu System §C.2 row 11). Does NOT push InputContext; does NOT close Pause. |

### Irreversible exit warnings (player decisions that destroy current section state)

- **Operations Archive → load slot** → unsaved progress lost (Pause's `accessibility_description` for the Load button must announce this — Menu System C.8 `menu.pause.load.desc`).
- **Return to Registry → confirm** → unsaved progress lost (Pause's `accessibility_description` warns: "*Return to the main menu. Unsaved progress is lost.*").
- **Close File → confirm** → unsaved progress lost; application exits.
- **Re-Brief Operation → confirm** → progress since last checkpoint lost.

These four are the *only* one-press-and-confirm destructive actions on Pause. Each routes through a `quit-confirm.md`-CANONICAL modal with default focus on Cancel and rubber-stamp-thud audio on Confirm (A6 per Menu System §A.1).

---

## Layout Specification

### Information Hierarchy

The pause screen communicates exactly five things, in this priority order. Anything not on this list is a Pillar 5 violation and a candidate for removal.

| Rank | What the player must see | Why it ranks here | How it is communicated |
|---|---|---|---|
| 1 | "The mission is **paused** — the dispatcher has the file open" | Without this, the player cannot tell whether input is still routing to gameplay. **Modal anchor.** | Manila folder lands on the desk (180 ms slide-in from bottom-right); 52% Ink Black overlay drops; drawer-slide audio (A2) fires at tween start |
| 2 | The **7 actions available** to the player | This is *the* purpose of the surface. The button stack is the load-bearing UI. | Vertical stack of 7 (or 6 at MVP — see Re-Brief conditional) Case File buttons inside the folder interior; default focus on Resume |
| 3 | "What operation is open?" | Period authenticity — every BQA folder identifies the case. Reinforces continuity between sessions. | Tab text on folder edge: `STERLING, E. — OPÉRATION TOUR D'IVOIRE — BQA/65` (V.1) |
| 4 | "Where is Eve right now?" (implicit / diegetic) | Reassures the player they have not lost their bearing. Unmovable per Pillar 5 (no "you are here" map). | The gameplay framebuffer remains visible behind the 52% overlay (FP-1 / V.1 "upper-left of screen behind overlay remains visible") — Eve's frozen viewport shows the room she is in |
| 5 | "Is anything urgent?" (event-driven, conditional) | A failed save fired by Save/Load while Pause is open must surface, not be lost. | `ModalScaffold` queues `SaveFailedContent` per C.4 depth-1 queue; renders on top of folder when active |

**Categorically NOT shown on Pause** (per Pillar 5 + Document Collection FP-DC-2 + game-concept forbidden patterns):
- Document collection count ("3 of 21 collected")
- Mission objective text or current step indicator (lives in Cutscenes Mission Cards / Document Overlay only)
- Time-played counter, clock, real-world timestamp
- Difficulty level, kill count, alarm count, takedown count
- Mini-map, waypoint, location pin, "press X to continue" coach-mark
- Any progress bar, percentage, or countdown
- Achievement/unlock notifications
- Tutorial overlay or "did you know..." hints

If any of these surfaces creep in via future feature requests, the request must be rejected at design review or escalated to creative-director per CLAUDE.md coordination rules.

---

### Layout Zones

Five zones, anchored to the manila-folder geometry from Menu System §V.1.

```
ZONE A — Desk overlay (full-screen, 52% Ink Black `#1A1A1A`)
ZONE B — Gameplay framebuffer (visible behind A, upper-left preserved)
ZONE C — Folder body (760 × 720 px, anchored bottom-right)
ZONE D — Folder tab (140 × 28 px, 2/3 across folder width from left, top edge of folder)
ZONE E — Page interior (interior of folder; hosts the button stack)
[ZONE F — Modal layer (CanvasLayer 20), present only when ModalScaffold active]
```

**Anchor specification (1080p baseline):**

| Zone | Anchor | Size | Position | Z-order (`CanvasLayer.layer`) |
|---|---|---|---|---|
| A — Desk overlay | Full screen | `1920 × 1080 px` (viewport) | `(0, 0)` | 8 (Pause root layer) |
| B — Gameplay framebuffer | Behind layer 8 | viewport | `(0, 0)` | 0 (section root) |
| C — Folder body | Bottom-right | `760 × 720 px` | bottom-right of viewport with 0 px right/bottom margin (the asset includes its own visual margin via the 760 × 760 source asset's tab overhang at top); upper-left of asset at viewport `(1160, 360)` | 8 |
| D — Folder tab | Inside folder, top edge | `140 × 28 px` | tab x-offset = 2/3 × 760 = ~507 px from folder's left edge; tab extends 28 px above folder body | 8 |
| E — Page interior | Inside folder body | ~720 × 600 px (760 minus 20 px L/R margins; 720 minus 80 px tab area minus 40 px bottom margin) | centered inside folder body | 8 |
| F — Modal layer | Centered viewport | per `quit-confirm.md` (400 × 200 px) or `save-failed-dialog.md` (400 × 200 px) | centered | 20 (per Menu System C.4) |

**Why bottom-right and not center?** Per V.1 "Folder dimensions: bottom-right slide-in (lower-center-right quadrant), NOT full-center. Offset so the upper-left of the screen (Eiffel Tower ironwork) remains visible behind the 52% overlay." The pause is *attentional* — the player should still be able to see the room they are in. Centering the folder would make the pause feel terminal (like a death screen). Offsetting it preserves the diegetic register.

**Aspect-ratio behavior**: 16:9 only at MVP+VS. Folder anchor is `ANCHOR_BOTTOM_RIGHT` with size in CSS-style px; on ultrawide (21:9) the folder remains pinned to bottom-right and the visible-gameplay area widens — acceptable. On 4:3 / Steam Deck 16:10 (post-launch consideration) the folder must not exceed the viewport — clamp size at viewport-min instead of growing the folder. (Flagged in Open Questions for technical-artist coord on ultrawide testing.)

---

### Component Inventory

Components inside the Pause Menu scene, by zone. References interaction-patterns.md and Menu System asset list (V.8) where applicable.

#### Zone A — Desk overlay (1 component)

| Component | Type | Asset | Interactive? | Pattern |
|---|---|---|---|---|
| Desk overlay backdrop | `ColorRect` | None — `ColorRect` color = `Color8(26, 26, 26, 132)` (52% alpha) | No (`mouse_filter = MOUSE_FILTER_IGNORE`) | n/a |

#### Zone B — Gameplay framebuffer (1 component, NOT owned by Pause)

| Component | Type | Asset | Interactive? | Pattern |
|---|---|---|---|---|
| Section scene root | `Node3D` (gameplay) | n/a — owned by Section | No (Pause does NOT touch its `process_mode`; `get_tree().paused` remains `false` per AC-MENU-2.1; InputContext gates input only) | n/a |

#### Zone C — Folder body (2 components)

| Component | Type | Asset | Interactive? | Pattern |
|---|---|---|---|---|
| Folder background | `TextureRect` | `ui_folder_manila_base_large.png` (760 × 760 source, V.8) | No | n/a |
| BQA seal watermark (optional, V.1 doesn't mandate but Art Bible §7D supports) | `TextureRect` | `ui_seal_bqa_watermark_small.png` at 20% opacity, top-left of page interior | No | n/a |

#### Zone D — Folder tab (1 component)

| Component | Type | Asset | Interactive? | Pattern |
|---|---|---|---|---|
| Tab label | `Label` (American Typewriter 11 px, Parchment `#F2E8C8`) on `TextureRect` band (`ui_folder_tab_eyes_only_normal.png`) | Image asset for the PHANTOM Red band; Label child overlaid | No (label only — `mouse_filter = MOUSE_FILTER_IGNORE`); text content: `tr("menu.pause.tab_label")` → `STERLING, E. — OPÉRATION TOUR D'IVOIRE — BQA/65` | n/a |

> **NEW STRING REQUIRED**: `menu.pause.tab_label` is not yet locked in Menu System §C.8. Must be added during ux-review. Proposed: `STERLING, E. — OPÉRATION TOUR D'IVOIRE — BQA/65` (47 chars; over the 25-char L212 cap — but tab_label is a body-copy string per L212's "labels only" carve-out per Localization OQ; coord with localization-lead to confirm).

#### Zone E — Page interior (button stack — 7 buttons MVP+VS, conditional Re-Brief)

| # | Component | Label (English) | tr-key | AccessKit role | Interactive? | Pattern |
|---|---|---|---|---|---|---|
| 1 | Resume Surveillance button | `Resume Surveillance` | `menu.pause.resume` | `button` | Yes — **default focus on mount** | `case-file-destructive-button` ❌ (NON-destructive — uses standard Case File button chrome but NOT the destructive-confirm flow) |
| 2 | File Dispatch button | `File Dispatch` | `menu.pause.save` | `button` | Yes | (none — sub-screen swap) |
| 3 | Operations Archive button | `Operations Archive` | `menu.pause.load` | `button` | Yes | (none — sub-screen swap; opening triggers irreversible-on-confirm flow inside the swap) |
| 4 | Personnel File button | `Personnel File` | `menu.pause.settings` | `button` | Yes — `accessibility_description` mandatory per Menu System CR-7 | (none — calls SettingsService API, which opens the Personnel File panel; that panel hosts a read-only **Field Notes** tab for tutorial re-access — see Field Notes sub-panel spec below) |
| 5 | Re-Brief Operation button (**VS+ conditional**) | `Re-Brief Operation` | `menu.pause.restart` | `button` | Yes — visibility = `MissionLevelScripting.has_checkpoint_in_current_section()` (default `true` once any in-section checkpoint has fired); see Open Questions for MVP-vs-VS-vs-playtest gating | `case-file-destructive-button` (destructive — opens Re-Brief modal; rubber-stamp thud A6 on confirm) |
| 6 | Return to Registry button | `Return to Registry` | `menu.pause.main_menu` | `button` | Yes | `case-file-destructive-button` (destructive — opens Return-to-Registry modal) |
| 7 | Close File button | `Close File` | `menu.pause.quit` | `button` | Yes | `case-file-destructive-button` (destructive — opens Quit-Confirm modal; CANONICAL via `quit-confirm.md`) |

**Button chrome (per V.7 + Pillar 5 V.9 compliance)**:
- Width: 480 px; Height: 32 px; Hard 0 px corners; flat fill (no gradient, no shadow).
- Idle state: BQA Blue `#1B3A6B` fill, Parchment `#F2E8C8` text, DIN 1451 Engschrift 12 px.
- Focused state: 2 px Parchment outer border (Pillar 5 V.9 #2 — focus is hard-border, not glow).
- Hover state: same as idle (mouse hover does not change visual appearance — only focus changes do; this matches the period-authentic "no breathing affordance" rule V.9 #4).
- Pressed state: opacity reduced to 0.85 for 30 ms, then released — matches typewriter-clack confirm A1 timing.
- Disabled state: opacity 0.45 (no other change). Used only by Save-Failed Retry button when retry is in-flight (covered in `save-failed-dialog.md`).

**Vertical button stack geometry** (inside Zone E, 720 × 600 px page interior):
- 7 buttons × 32 px = 224 px stack height (or 6 × 32 = 192 px if Re-Brief hidden)
- 6 inter-button gaps × 8 px = 48 px (or 5 × 8 = 40 px)
- Total stack height: **272 px (7 buttons) or 232 px (6 buttons)**
- Stack vertically centered in page interior (top margin = (600 − 272) / 2 = 164 px; or 184 px for 6 buttons)
- Stack horizontally centered: each button is 480 px wide, page interior is 720 px wide → 120 px margin per side
- Visual separator (optional, advisory) between Personnel File and Re-Brief / Return / Close — a 1 px ruled Ink Black 30%-opacity line at 16 px gap to suggest the destructive group is "below the fold of the file." Not mandated; coord with art-director at ux-review.

#### Field Notes sub-panel (inside Personnel File / Settings panel — always available)

The Personnel File button opens the Settings panel via `SettingsService.open_panel()`. The Settings panel includes a **Field Notes** tab alongside the existing settings categories. This tab is a read-only sub-panel; it is not a settings category and writes nothing to `user://settings.cfg`.

| Property | Value |
|---|---|
| Location | Tab inside the Personnel File / Settings panel, grouped with settings categories |
| Label | "Field Notes" (`tr("menu.settings.field_notes.tab")` — **NEW STRING REQUIRED**, see Localization Considerations) |
| Content | The 5 Plaza tutorial dialogue lines verbatim, as static read-only body text |
| AccessKit role | `region` (read-only text container) |
| Interaction | Read-only — no editable fields, no activatable controls inside the panel |
| Availability | **Always available**: not gated on checkpoint state, Re-Brief button visibility, or MVP scope-lock (OQ-PM-1). Personnel File is always present in the button stack; Field Notes tab is always present inside that panel. |
| Reduced-motion | No transitions inside the tab — text appears instantly on tab selection. Safe by absence of motion. |
| Accessibility cross-reference | Satisfies `design/accessibility-requirements.md` "Tutorial persistence" row (Standard tier, Designed). Players who need to re-read the Plaza tutorial prompts at any point during the mission access this via `Pause → Personnel File → Field Notes`. |

This decouples tutorial re-access from Re-Brief Operation entirely. See AC-PAUSE-14 for verification criteria and OQ-PM-12 for the resolution rationale.

#### Zone F — Modal layer (when active, NOT owned by Pause shell)

| Component | Owned by | Reference spec |
|---|---|---|
| `ModalScaffold` (CanvasLayer 20, single shared instance) | Menu System §C.4 | n/a |
| Quit-Confirm content | Menu System §V.6 + `quit-confirm.md` | `quit-confirm.md` (CANONICAL) |
| Return-to-Registry content | Menu System §V.6 + inheritance from `quit-confirm.md` | `quit-confirm.md` |
| Re-Brief Operation content | Menu System §V.6 + inheritance | `quit-confirm.md` |
| Save-Failed content (event-driven) | Menu System §V.5 + `save-failed-dialog.md` | `save-failed-dialog.md` (TBD — Save/Load co-owned) |
| Quicksave / Quickload feedback card | Menu System §C.2 row 11 | `quicksave-feedback-card.md` (TBD) |

---

### ASCII Wireframe

**1080p baseline; 16:9 viewport. Folder slid into final position (post-tween).**

```
┌──────────────────────────────────────────────────────────────────────┐
│ [GAMEPLAY FRAMEBUFFER VISIBLE BEHIND 52% INK BLACK OVERLAY]          │
│  ┌─Eiffel ironwork─┐                                                 │
│  │ visible upper-  │                                                 │
│  │ left quadrant   │                                                 │
│  │ behind overlay  │                                                 │
│  └─────────────────┘                                                 │
│                                                                      │
│                                                                      │
│                                                                      │
│                                                                      │
│                                                                      │
│                                                  ┌──┤TAB├─┐          │
│                                                  │ STERLING│          │
│                                          ┌───────┤ E. ─── ├─────────┐│
│                                          │       │OPÉRATION │       ││
│                                          │       │ TOUR    │        ││
│                                          │       └─────────┘        ││
│                                          │                          ││
│                                          │   ┌─────────────────┐    ││
│                                          │   │ Resume          │ ◄──── default focus
│                                          │   │ Surveillance    │    ││
│                                          │   └─────────────────┘    ││
│                                          │   ┌─────────────────┐    ││
│                                          │   │ File Dispatch   │    ││
│                                          │   └─────────────────┘    ││
│                                          │   ┌─────────────────┐    ││
│                                          │   │ Operations      │    ││
│                                          │   │ Archive         │    ││
│                                          │   └─────────────────┘    ││
│                                          │   ┌─────────────────┐    ││
│                                          │   │ Personnel File  │    ││
│                                          │   └─────────────────┘    ││
│                                          │  · · · · · · · · · ·     ││ ← 1 px ruled separator
│                                          │   ┌─────────────────┐    ││   (advisory; "below the fold")
│                                          │   │ Re-Brief        │    ││ ← VS+ conditional
│                                          │   │ Operation       │    ││
│                                          │   └─────────────────┘    ││
│                                          │   ┌─────────────────┐    ││
│                                          │   │ Return to       │    ││
│                                          │   │ Registry        │    ││
│                                          │   └─────────────────┘    ││
│                                          │   ┌─────────────────┐    ││
│                                          │   │ Close File      │    ││
│                                          │   └─────────────────┘    ││
│                                          │                          ││
│                                          │ [BQA seal watermark 20%] ││
│                                          └──────────────────────────┘│
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                                          ↑                          ↑
                                          folder left edge       viewport right edge
                                          @ x = 1160 px          @ x = 1920 px
```

**Reading the wireframe:**
- Folder occupies bottom-right `760 × 720` (its visible body); tab projects ~28 px above the folder body's top edge.
- Button stack is `480 px` wide, vertically centered in folder interior with ~164 px top margin.
- Default focus is on **Resume Surveillance** (top button) — `grab_focus()` called via `call_deferred` after mount per Menu System C.4 focus-target convention.
- 1 px ruled separator between Personnel File and Re-Brief (advisory; coord with art-director).
- Quicksave / Quickload feedback card — when active — would render at `bottom-right` *adjacent to* the folder (not inside it). Z-order layer 8, no InputContext push, fades after 1.4 s.
- Modal scaffolds (Quit-Confirm / Return-to-Registry / Re-Brief / Save-Failed) render at **center of viewport on CanvasLayer 20**, on top of the folder. They do NOT replace the folder; the folder remains visible underneath their 52% overlay.

**Reduced-motion variant**: folder appears instantly (no slide-in tween); audio cue A2 still fires per A.5 (audio cues are NOT tied to reduced-motion). Overlay alpha jumps 0 → 0.52 instantly.

---

## States & Variants

| State / Variant | Trigger | What changes vs. Default | Reachability |
|---|---|---|---|
| **Default — Pause root, post-mount** | `pause` action fires from `Context.GAMEPLAY`; `_ready()` completes | Folder fully slid in; 7 (or 6) buttons visible; default focus on Resume Surveillance; mouse cursor = fountain-pen-nib (CR-17) | Always (every mount) |
| **Mounting / slide-in transition** | `_ready()` running; tween ticking through 180 ms slide | Folder is mid-translation; buttons exist but `process_input = false` until tween completes (debouncing same-frame double-press); overlay alpha tweening 0 → 0.52 | First 180 ms of every mount |
| **Re-Brief hidden (MVP / pre-checkpoint)** | `MissionLevelScripting.has_checkpoint_in_current_section() == false` OR MVP scope-lock active per F&R L345 | Re-Brief Operation button absent (NOT disabled — fully removed from focus order); button stack height drops from 272 px to 232 px; 1 px ruled separator still present (between Personnel File and Return-to-Registry) | Plaza pre-first-checkpoint; MVP scope per Open Questions |
| **Operations Archive sub-screen** | `Operations Archive` activated | Button stack hidden; 8-slot 2×4 Load grid renders inside same folder interior; tab text unchanged; default focus on slot 0 (Autosave) | From Pause root |
| **File Dispatch sub-screen** | `File Dispatch` activated | Button stack hidden; 7-slot 2×3+1 Save grid renders inside folder; default focus on last-used slot in-session, else slot 1 | From Pause root |
| **In-card overwrite-confirm** (Save grid only) | `ui_accept` on OCCUPIED save card | Card swaps to confirm state inline; focus moves to `[CANCEL]` inside card; tab still cycles between `[CANCEL]` / `[CONFIRM]` only | From File Dispatch sub-screen |
| **Modal active — Quit-Confirm / Return-to-Registry / Re-Brief** | One of the destructive buttons activated | `ModalScaffold.show_modal()` mounts the corresponding content; `Context.MODAL` pushed; folder remains visible behind modal's 52% overlay; modal default focus on Cancel (`Continue Mission`) | From Pause root |
| **Modal active — Save-Failed (event-driven)** | `Events.save_failed` fires while Pause mounted | `ModalScaffold.show_modal(SaveFailedContent)`; assertive AccessKit one-shot; Pause's button container does NOT disable `process_input` (non-blocking modal per CR-10) | From any Pause state — most-recent-wins queue policy if other modal active |
| **Quicksave feedback overlay** | `Events.game_saved` fires while Pause mounted | `quicksave-feedback-card.md` ephemeral overlay fades in for 1.4 s + 200 ms fade-out at bottom-right (NOT inside folder); does NOT push InputContext | From any Pause state |
| **Quickload feedback overlay** | `Events.game_loaded` fires (rare from Pause — quickload usually triggers LS LOAD_FROM_SAVE which destroys Pause) | Same as Quicksave feedback but `DISPATCH LOADED` text | From any Pause state, but practically only seen if quickload is no-op (slot empty) |
| **Window focus lost** | `NOTIFICATION_APPLICATION_FOCUS_OUT` (Alt+Tab, etc.) | Pause remains mounted; mouse cursor returns to OS default (Pause does not own OS cursor capture); on focus return, fountain-pen cursor restored per CR-17 + §E Cluster F | From any Pause state |
| **Gamepad disconnected** | `Input.joy_connection_changed` fires `connected = false` | Pause **does NOT auto-prompt** at MVP; KB+M remains usable. (Open Question: post-VS, surface a "reconnect controller" advisory per Input GDD §Edge Cases L180. Menu System §A.7 advisory coord exists.) | From any Pause state with gamepad in use |
| **Reduced-motion enabled** | `Settings.accessibility.reduced_motion_enabled == true` | Folder appears instantly (no 180 ms tween); overlay alpha jumps 0 → 0.52; audio cues unchanged (A.5) | Boot-time setting consumption; live-update propagation per Settings boot burst |
| **Closing / slide-out transition** | Resume Surveillance / `ui_cancel` at root | Folder tweens 140 ms `TRANS_CUBIC EASE_IN` back down off-screen; overlay alpha tweens 0.52 → 0; on tween end, `queue_free()` PauseMenu and pop `Context.PAUSE`; PC re-grabs `MOUSE_MODE_CAPTURED` | Final 140 ms before unmount |

**Empty / loading / error states** *(per UX-Spec template question pass)*:
- **Empty state**: not applicable. Pause has no data-driven empty body — the button stack is always populated. The Save grid sub-screen has its own empty-slot states per V.2 (handled in `save-game-screen.md`).
- **Loading state**: not applicable on the Pause shell itself. Sub-screens that load slot metadata may show an in-flight indicator — covered in `load-game-screen.md` / `save-game-screen.md`.
- **Error state**: the Save-Failed modal IS the error surface. No inline error text on the Pause shell. (Coord: if a future feature requests inline error text on Pause, escalate to creative-director — Pillar 5 forbids HUD-style error chrome.)

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse (Primary), Gamepad (Partial — full nav, rebind post-MVP)**. Per technical-preferences.md.

Bindings reference Input GDD §C action names (`ui_accept`, `ui_cancel`, `ui_up`, `ui_down`, `ui_left`, `ui_right`, `pause`).

### Pause-shell interactions

| Action | KB/M binding | Gamepad binding | Immediate feedback (visual / audio / haptic) | Outcome |
|---|---|---|---|---|
| Open Pause from gameplay | `Esc` (KB) | `JOY_BUTTON_START` | Drawer-slide A2 audio fires at tween start; folder slides in 180 ms; mouse cursor swaps to fountain-pen-nib (CR-17); overlay alpha tweens 0 → 0.52 | `pause` action; PC pushes `Context.PAUSE`; `_ready()` sets `MOUSE_MODE_VISIBLE`; default focus on Resume Surveillance after tween (`process_input` enabled post-tween) |
| Resume gameplay | `Esc` at Pause root **OR** `Resume Surveillance` button activate | `JOY_BUTTON_B` (`ui_cancel`) at root **OR** `JOY_BUTTON_A` (`ui_accept`) on Resume button | Drawer-slide-out A3 audio at tween start; 140 ms slide-out; overlay alpha tweens 0.52 → 0; if Resume button activated, A1 typewriter clack fires before A3 (button activation cue + close cue both play; not collision) | `queue_free()` Pause; pop `Context.PAUSE`; PC re-applies `MOUSE_MODE_CAPTURED`; held movement keys resume motion next frame |
| Move focus down (within button stack) | `Down arrow` / `Tab` | `JOY_BUTTON_DPAD_DOWN` / left-stick-down | (No audio cue on button-stack navigation — A4 is reserved for Save/Load grid only) | Focus moves to next button; `focus_neighbor_bottom` wiring per Pause's Theme; cycles from last back to first per CR-24 focus-trap rules |
| Move focus up (within button stack) | `Up arrow` / `Shift+Tab` | `JOY_BUTTON_DPAD_UP` / left-stick-up | (No audio) | Focus moves to previous button |
| Activate focused button | `Enter` / `Space` | `JOY_BUTTON_A` (`ui_accept`) | A1 typewriter clack 60–80 ms fires immediately on press (not release); pressed-state visual: opacity 0.85 for 30 ms then release | Button-specific outcome (see per-button rows below) |
| Cancel / dismiss at root | `Esc` | `JOY_BUTTON_B` (`ui_cancel`) | Drawer-slide-out A3; 140 ms close | Pop `Context.PAUSE`; resume gameplay (identical to Resume Surveillance) |
| Mouse hover over button | Mouse over | n/a (mouse is KB+M only) | No visual change (Pillar 5 V.9 #4 — no breathing affordance) | Mouse hover does NOT change focus on Pause; only `Tab` / arrow / D-pad moves focus. (Mouse click on a button DOES focus + activate it.) |
| Mouse click on button | Left mouse button down on button bounds | n/a | Same as `ui_accept` — A1 clack + button outcome | Sets focus + activates button in one press |

### Per-button activation outcomes

| Button | Outcome on activate |
|---|---|
| **Resume Surveillance** | Resume gameplay (see above) |
| **File Dispatch** | A1 clack; A7 paper-shuffle 100 ms; button stack fades out / Save grid swaps in; focus → last-used slot in-session else slot 1; tab text unchanged; same `Context.PAUSE` |
| **Operations Archive** | A1 clack; A7 paper-shuffle; button stack → Load grid; focus → slot 0 (Autosave); same `Context.PAUSE` |
| **Personnel File** | A1 clack; calls `SettingsService.open_panel()` synchronously; Settings pushes `Context.SETTINGS` itself; Pause stays mounted underneath but is no longer focused. On Settings dismiss, `peek()` returns to `Context.PAUSE` and focus restores to Personnel File button (AC-MENU-5.2) |
| **Re-Brief Operation** (VS+ conditional) | A1 clack; `ModalScaffold.show_modal(ReBriefContent)`; A8 paper-drop modal-appear cue; default focus on Cancel ("Continue Mission"); `Context.MODAL` pushed |
| **Return to Registry** | A1 clack; `show_modal(ReturnToRegistryContent)`; A8 modal-appear; default focus on Cancel; `Context.MODAL` pushed |
| **Close File** | A1 clack; `show_modal(QuitConfirmContent)`; A8 modal-appear; default focus on Cancel; `Context.MODAL` pushed; CANONICAL inheritance from `quit-confirm.md` for everything inside the modal |

### Sub-screen interactions (delegated to dedicated specs)

| Sub-screen | Owns its interaction map | Reference |
|---|---|---|
| Operations Archive (Load grid) | Yes | `load-game-screen.md` (TBD — Save/Load co-owned) |
| File Dispatch (Save grid) including in-card overwrite-confirm | Yes | `save-game-screen.md` (TBD — Save/Load co-owned) |
| Quit-Confirm / Return-to-Registry / Re-Brief modals | CANONICAL via `quit-confirm.md` (already specced) | `quit-confirm.md` |
| Save-Failed modal | Yes | `save-failed-dialog.md` (TBD) |
| Settings panel | Yes | `settings-and-accessibility.md` |
| Quicksave / Quickload feedback card | Yes | `quicksave-feedback-card.md` (TBD) |

### Mouse-mode contract (Input GDD §Core Rule 8)

- On `_ready()`: `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)` and store the previous mode (will always be `MOUSE_MODE_CAPTURED` if entered from `Context.GAMEPLAY`).
- On `_exit_tree()`: `Input.set_mouse_mode(stored_previous_mode)` — restores `MOUSE_MODE_CAPTURED` if the section is still active.
- Sub-screens (Save/Load grid) inherit `MOUSE_MODE_VISIBLE` — they do NOT toggle it.
- Modals push their own mouse-mode override only if needed; default is to inherit `MOUSE_MODE_VISIBLE` from Pause.

### Same-frame double-press protection (the "rapid `Esc`" case)

Per Menu System §C.6 + Input §Core Rule 7: every dismiss handler MUST call `get_viewport().set_input_as_handled()` BEFORE calling `InputContext.pop()`. Pause Menu's `_unhandled_input()` MUST follow this order. Reversing it lets the same `Esc` event fall through and double-pop. Pattern: `set-handled-before-pop` from interaction-patterns.md.

### Held-input resume (Input GDD §Edge Case L184)

When the player held `move_forward` while opening Pause, `Input.is_action_pressed(&"move_forward")` immediately returns `true` again on resume. Player Character GDD owns velocity restore. Pause does NOT clear input state; it does NOT inject synthetic releases. Tested via AC in §Acceptance Criteria.

---

## Events Fired

Per ADR-0002 (Events autoload as the single signal bus), Menu surfaces are **subscriber-only** for cross-system signals; they do NOT emit gameplay events. The Pause shell's emissions are limited to (a) `InputContextStack` lifecycle calls (which are not signals — they are direct stack operations), (b) the audio cues that fire as side-effects of player activations, and (c) optional analytics events under the project's eventual telemetry layer (not yet authored — flag in Open Questions).

### Direct events fired by the Pause shell

| Player Action | Event / Signal Fired | Payload | Bus / Owner | Notes |
|---|---|---|---|---|
| Pause opens (after slide-in completes) | `InputContextStack.push(Context.PAUSE)` (not a signal — direct call) | n/a | InputContext autoload | Per Menu System CR-3; AC-MENU-2.1 |
| Pause closes (Resume / `ui_cancel`) | `InputContextStack.pop()` | n/a | InputContext autoload | AC-MENU-2.2 |
| Personnel File button activated | `SettingsService.open_panel()` (direct API call — Settings pushes its own context) | n/a | Settings autoload | AC-MENU-5.1 — Menu does NOT push `SETTINGS` |
| Operations Archive button activated | `_swap_to_load_grid()` (internal Pause method — no global signal) | n/a | Pause shell | Local to Pause |
| File Dispatch button activated | `_swap_to_save_grid()` (internal) | n/a | Pause shell | Local to Pause |
| Re-Brief Operation modal Confirm | `FailureRespawn.restart_from_checkpoint()` (direct API call) | n/a | Failure & Respawn autoload | F&R owns its own emission of `respawn_started`/`respawn_completed` |
| Return to Registry modal Confirm | `LS push(LOADING)` then `LS.transition_to_section(MainMenu, ...)` per Menu System §C.7 | section_id, save_data, source | Level Streaming | LS emits `section_transition_started` |
| Close File modal Confirm | `pop()` Context.MENU/PAUSE then `get_tree().quit()` | n/a | Engine | OS-level — application exits; no in-engine signal |

### Audio cues fired (UI bus per A.2)

| Player Action | Audio cue | Bus | When fires |
|---|---|---|---|
| Pause open | A2 drawer-slide-in (170–190 ms) | UI | At tween start (before visual completes) |
| Pause close | A3 drawer-slide-out (130–150 ms) | UI | At tween start |
| Any non-destructive button activate (Resume / File Dispatch / Operations Archive / Personnel File) | A1 typewriter clack (60–80 ms) | UI | On `pressed` (not `released`) |
| Sub-screen swap | A7 paper-shuffle (90–110 ms) | UI | On the swap tween start |
| Modal appears (Quit-Confirm / Return-to-Registry / Re-Brief) | A8 modal-appear paper-drop (50–70 ms) | UI | On `show_modal()` call |
| Destructive confirm (Close File / Return to Registry / Re-Brief / Save-Failed Abandon) | A6 rubber-stamp thud (90–110 ms) | UI | On `show_modal()` confirm button press, frame 1 of stamp animation |

### Cross-cut audio that may fire during Pause (NOT owned by Pause — listed for completeness)

| Cue | Owned by | When fires during Pause |
|---|---|---|
| Section ambient music (continues uninterrupted per AFP-1) | Audio | Throughout Pause lifetime |
| `game_saved` chime (~200 ms soft tock, SFX bus) | Audio (subscribed to `Events.game_saved`) | When Save grid Confirm or Quicksave fires |
| `save_failed` descending-minor-two-note sting (~400 ms, SFX bus) | Audio (subscribed to `Events.save_failed`) | When `Events.save_failed` arrives — pairs with Save-Failed modal A8 cue (which Pause owns) |

### Persistent-state-modifying actions (FLAG — architecture team attention)

The following actions, fired from Pause, modify persistent player state:

| Action | What it writes | Coord with |
|---|---|---|
| File Dispatch → in-card Confirm | `SaveLoad.save_to_slot(N)` → writes `user://saves/slot_N.res` + sidecar metadata | Save/Load (ADR-0003 sidecar contract) |
| Operations Archive → load slot | `SaveLoad.load_from_slot(N)` → mutates in-memory `SaveGame` resource + triggers LS transition | Save/Load + Level Streaming |
| Re-Brief confirm | `FailureRespawn.restart_from_checkpoint()` → reverts in-memory section state to last checkpoint snapshot | Failure & Respawn |
| Return to Registry confirm | `LS.transition_to_section(MainMenu)` → destroys section trees; in-memory unsaved progress lost | Level Streaming |
| Close File confirm | `get_tree().quit()` → application exits; in-memory unsaved progress lost | Engine — irreversible |
| Personnel File → adjust setting → live-update | Settings writes `user://settings.cfg` per its own boot burst | Settings & Accessibility |

> **Architecture note**: Pause shell does NOT directly write to disk. Every persistent write goes through the owning autoload (SaveLoad / SettingsService / FailureRespawn). Pause is a dispatcher of intent, not a state-modifier. This boundary is enforced by ADR-0002 (Events bus) + ADR-0003 (sidecar) + the Menu System "Menu reads sidecar only; never opens .res" rule (§C.10 row 1).

### Telemetry / analytics events

Not yet authored. The project has no analytics layer at MVP+VS scope. If a future analytics layer is added, the following Pause events would be candidates for tracking (flagged in Open Questions for analytics-engineer coord):
- `pause.opened` (with `section_id`, `seconds_into_section`, `health`, `alarm_state`)
- `pause.closed` (with `time_in_pause_ms`, `dismiss_route` ∈ {resume / save / load / settings / quit / etc.})
- `pause.button_activated` (with `button_id`)
- `pause.modal_confirmed` (with `modal_id`, `confirm` ∈ {true, false})

These are NOT to be implemented at MVP+VS — they would be added behind a build flag once analytics scope is defined.

---

## Transitions & Animations

All animation timings reference Menu System §V.7 (the canonical animation choreography table). This spec adds reduced-motion variants and screen-specific transition rules.

### Screen-enter (open Pause)

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Folder slide-in | `position.y` from `viewport_height` to `bottom-right anchor` | `TRANS_CUBIC EASE_OUT` | 180 ms | Bottom-right of screen translating upward; folder origin is bottom-right anchor |
| Desk overlay alpha | `modulate.a` 0 → 0.52 | `TRANS_LINEAR` | 180 ms | Simultaneous with folder slide; identical duration |
| Button container `process_input` | `false` → `true` | (state flip, not tween) | 180 ms (after tween) | Prevents same-frame double-press during tween |

**Audio sync**: A2 drawer-slide-in fires at tween **start** (frame 0), not on completion. The audio precedes the visual landing intentionally — "you hear the drawer before paper fully lands" (Menu System §V.7 row 1). Total audio-to-visual lag: 0 ms (audio-leads-visual is the period-authentic register; do not invert).

**Reduced-motion variant** (per Settings G.3 `reduced_motion`):
- Folder appears instantly (no `position.y` tween) at final anchor
- Desk overlay alpha jumps 0 → 0.52 instantly (no `modulate.a` tween)
- A2 drawer-slide audio cue fires at full duration regardless (per Menu System §A.5 — audio is NOT tied to reduced-motion)
- Button container `process_input = true` immediately (no 180 ms gate)

### Screen-exit (close Pause)

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Folder slide-out | `position.y` reverse — folder translates back down off-screen | `TRANS_CUBIC EASE_IN` | 140 ms | Faster than slide-in to reduce friction on resume; per V.7 row 2 |
| Desk overlay alpha | `modulate.a` 0.52 → 0 | `TRANS_LINEAR` | 140 ms | Simultaneous with slide-out |
| `queue_free()` PauseMenu | (deferred to tween end via `tween.finished` signal) | n/a | t = 140 ms | After tween completes |
| Pop `Context.PAUSE` | (deferred to AFTER `queue_free()`) | n/a | t = 140 ms + 1 frame | Per Input Core Rule 7 — `set_input_as_handled()` BEFORE pop |
| PC `MOUSE_MODE_CAPTURED` re-grab | (PC's `_on_input_context_changed` handler subscribes to context changes) | n/a | t = 140 ms + 1-2 frames | PC owns the restoration; Pause does not directly call `set_mouse_mode` to capture |

**Audio sync**: A3 drawer-slide-out fires at tween start (t = 0). If close was triggered via Resume Surveillance button activation, A1 typewriter clack fires *first* (at button press, t = 0), then A3 layers on at tween start (also t = 0 effectively — both within frame 1). UI bus has no ducking, so both play without volume interference.

**Reduced-motion variant**:
- Folder disappears instantly
- Desk overlay alpha jumps to 0 instantly
- `queue_free()` + pop fire same frame (no 140 ms gate)
- A3 audio cue still fires at full 130–150 ms duration

### Sub-screen swap (Button stack ↔ Save grid / Load grid)

| Animation | Property | Curve | Duration | Notes |
|---|---|---|---|---|
| Outgoing surface slide-out | `position.x` of leaving surface translates 20 px to the **left** | `TRANS_LINEAR` | 100 ms | Per V.7 row 6 |
| Outgoing surface fade | `modulate.a` 1.0 → 0 | `TRANS_LINEAR` | 100 ms | Concurrent with translate |
| Incoming surface slide-in | `position.x` from 20 px right of rest → rest position | `TRANS_LINEAR` | 100 ms | Concurrent |
| Incoming surface fade | `modulate.a` 0 → 1.0 | `TRANS_LINEAR` | 100 ms | Concurrent |

**Audio**: A7 paper-shuffle fires at tween start.

**Focus**: focus is `release_focus()`-d on the outgoing surface at tween start; `grab_focus()` is `call_deferred`-ed on the incoming surface's default focus target at tween end. Avoids focus flashing during translate.

**Reduced-motion variant**: outgoing surface hides instantly, incoming surface shows instantly, focus moves immediately. A7 paper-shuffle still plays full duration.

### Modal-appear (Quit-Confirm / Return-to-Registry / Re-Brief / New-Game-Overwrite)

CANONICAL spec inherited from `quit-confirm.md`. Pause does NOT re-spec modal entry/exit animation.

Summary (for cross-reference):
- 80 ms header band slide-in (PHANTOM Red for save-failed, Ink Black for case-closed register, etc.) per V.7 row 5 / V.5 / V.6
- A8 modal-appear paper-drop on `show_modal()`
- ModalScaffold's 52% Ink Black backdrop appears instantly (no tween) on top of the existing 52% Pause overlay — visual stacking creates a darker effective blanket of ~77% over the gameplay framebuffer (`1 − (1 − 0.52)² ≈ 0.77`)
- Default focus on Cancel button via `call_deferred("grab_focus")` per ModalScaffold C.4

### Stamp slam (destructive confirm — Close File / Return to Registry / Re-Brief / Save-Failed Abandon)

CANONICAL via `quit-confirm.md` + Menu System §V.7 row 4. Summary: 100 ms scale 0% → 120% → 100%; rubber-stamp thud A6 fires on **frame 1** (the instant the stamp begins moving). Reduced-motion variant suppresses the scale tween but still plays A6 at full duration.

### Critical-state animations (NONE on Pause)

Per Pillar 5 V.9 #4 — there is no flashing, breathing, pulsing, or color-cycling on the Pause shell. The Pause Menu has no "urgent" affordance. If a future feature requests an attention-getting animation (e.g., a flashing Re-Brief button when player health is low pre-pause), reject — that is an HSS-style notification and does not belong on the Pause shell. (HUD State Signaling lives outside Pause; pre-pause notifications are HSS's domain, not Menu's.)

### Motion-sickness audit

- **No camera movement during pause** — Pause does not modify the gameplay camera (FP-1 + AC-MENU-2.5: section camera frozen during pause, framebuffer unchanged).
- **No screen shake / parallax / camera bob** on the Pause shell.
- **Folder slide-in is a 2D translation** confined to the bottom-right quadrant — the player's central viewing area (Eve's first-person frame, upper-left under overlay) is undisturbed.
- **Op-art / strobe / chromatic shift** — none on Pause. The op-art register is reserved for Cutscenes CT-05 (per Cutscenes V.4 + accessibility-requirements.md tritanopia row).
- **No looping animations on the Pause shell** (folder + buttons are static once mounted; no breathing, no waving, no shimmer).

Pause is therefore safe under Game Accessibility Guidelines "Motion (Vestibular Disorders)" Standard tier without further mitigation. The reduced-motion toggle is honored as an additional layer of player control, not a remediation requirement.

---

## Data Requirements

The Pause shell is **read-only** for game state. It does not own or write any persistent data. Sub-screens (Save grid / Load grid / Settings panel) have their own data requirements specced in their respective UX files.

| Data | Source System | Read / Write | Cardinality | Notes |
|---|---|---|---|---|
| Tab text — operation identifier (`STERLING, E. — OPÉRATION TOUR D'IVOIRE — BQA/65`) | Localization (static `tr()` lookup) | Read | 1 string | At MVP all sections share the single operation; future Tier 2 (Rome / Vatican) requires runtime swap by mission ID — flag in Open Questions |
| Re-Brief button visibility | `MissionLevelScripting.has_checkpoint_in_current_section() : bool` (proposed API — see Open Questions) | Read | 1 bool | Polled on Pause `_ready()`; not reactive (no signal subscription) — Pause does not need to update during open if checkpoint state changes mid-pause (it cannot, since `Context.PAUSE` blocks gameplay input) |
| Section music continuity | AudioManager (no Pause-side query — Pause does not touch the music bus per AFP-1) | Neither | n/a | Implicit invariant; AC-MENU-2.4 verifies |
| Mouse cursor asset | FontRegistry / AssetRegistry (`ui_cursor_fountain_pen_nib_normal.png`) | Read | 1 image | Set on `_ready()` per CR-17 |
| `Settings.accessibility.reduced_motion_enabled` | SettingsService (autoload) | Read | 1 bool | Read at `_ready()`; Settings boot burst guarantees value is hydrated before Pause mounts |
| `Settings.accessibility.subtitle_size_scale` | SettingsService | Read | 1 float | Not directly used by Pause's own surfaces (Pause has no subtitles); but inherited by sub-screens via `project_theme.tres` font scale |
| Fountain-pen mouse cursor — focus restoration after window focus loss | OS (NOTIFICATION_APPLICATION_FOCUS_IN) | Read (notification) | 1 event | Per CR-17 + §E Cluster F |
| Save slot metadata (for sub-screens only — NOT used on Pause shell) | `SaveLoad.slot_metadata(N)` | Read | up to 8 dictionaries | Owned by `load-game-screen.md` / `save-game-screen.md` — Pause shell never queries SaveLoad |
| `Events.save_failed` payload | Events autoload (Pause subscribes per CR-10) | Read (event) | event-driven | Triggers ModalScaffold mount; Pause does NOT hold the payload — `ModalScaffold` and `save-failed-dialog.md` own retry-target tracking |
| `Events.game_saved` / `Events.game_loaded` | Events autoload | Read (event) | event-driven | Triggers Quicksave / Quickload feedback card per CR-15 |
| Window focus state | OS via `NOTIFICATION_APPLICATION_FOCUS_OUT` / `_IN` | Read (notifications) | event-driven | Per §E Cluster F — handles cursor restoration |

### Architectural concerns

**No game-state mutation by Pause shell** — every persistent write goes through an owning autoload. The Pause shell is a *signal dispatcher*, not a state manager. This boundary aligns with:
- ADR-0002 (Events autoload — single signal bus; Menu is subscriber-only for save/load/settings events)
- ADR-0003 (Save sidecar — Menu reads sidecar metadata only via `SaveLoad.slot_metadata(N)`; never opens `.res` files directly)
- ADR-0004 (InputContext + Theme + FontRegistry — Pause depends on but does not own these)

**No game-state polling by Pause shell** — the `Re-Brief button visibility` query is the only game-state read on `_ready()`, and it is a single synchronous query with no per-frame cost. There is no `_process()` or `_physics_process()` loop on Pause. (Per ADR-0008 Slot 7 budget claim referenced by HUD Core CR-22 — Pause is a sibling consumer, not a per-frame consumer.)

**Data dependencies are fully discoverable at Pause `_ready()`** — there are no async waits except for the optional `MissionLevelScripting.has_checkpoint_in_current_section()` API call, which must be synchronous (returning a cached bool from the in-memory section state). If this method is async at the implementation layer, Pause's `_ready()` would have to `await` it before showing the button stack — flagged in Open Questions.

### Forbidden data reads from Pause

To preserve Pillar 5 the following data MUST NOT appear on the Pause shell, even though it is queryable:

| Data | Why forbidden |
|-------|--------------|
| `DocumentCollectionState.collected.size()` | Document Collection FP-DC-2 (Pause Menu archive shortcut deferred to Polish-or-later per DC OQ-Archive-1) |
| `Player.health_current` / `health_max` | HUD-only at MVP+VS (HUD Core §C); Pause does not display health |
| `Mission.current_objective_text` | Cutscenes Mission Cards / dossier register only — Pause does not show objective text |
| `Section.elapsed_time_seconds` | Pillar 5 — no time-played counter anywhere |
| `Stealth.alarm_state` | HSS only — no alarm indicator on Pause |
| `Inventory.gadgets_held` / weapon counts | HUD only — no inventory display on Pause |
| `Save.slot_count_used` / save-quota indicator | Not at MVP+VS; if added post-launch, it lives on the Save grid screen, not the Pause shell |

If a future feature pulls any of these into Pause, the request must be rejected at `/ux-review` or escalated.

---

## Accessibility

**Tier**: Standard (per `design/accessibility-requirements.md`).

This section enumerates Pause-shell-specific accessibility requirements. All sub-screens and modals launched from Pause own their own accessibility specs via their respective `design/ux/*.md` files; this spec inherits and does not re-enumerate those.

### Keyboard-only navigation

- **All 7 (or 6) buttons reachable via Tab / Shift-Tab in linear order.** Focus order = visual order top-to-bottom: Resume → File Dispatch → Operations Archive → Personnel File → [Re-Brief, if visible] → Return to Registry → Close File.
- **Focus cycles** (last → first; first → last on Shift-Tab) per CR-24 focus-trap convention. The Pause root traps focus inside the button stack — Tab does not escape to the gameplay scene behind the overlay.
- **Default focus on mount: Resume Surveillance.** Set via `call_deferred("grab_focus")` after the 180 ms slide-in completes (so focus is not stolen during the tween).
- **Focus restoration on sub-screen return**: when Operations Archive or File Dispatch closes via `ui_cancel`, focus returns to its triggering button — NOT back to Resume. (User-tested intuition: `Esc` should "back out" from where you came.)
- **Focus restoration on modal dismiss**: when a Quit-Confirm / Return-to-Registry / Re-Brief modal cancels, focus returns to the button that opened it — `ModalScaffold.show_modal(content, return_focus_node=button)` per C.4.
- **Focus restoration on Settings dismiss**: AC-MENU-5.2 — focus returns to Personnel File button.
- **No focus traps that exclude the cancel path**: at every level except the photosensitivity-warning modal (which is boot-only, not Pause), `ui_cancel` is reachable. Pause root: `Esc` resumes. Sub-screen: `Esc` returns to Pause. Modal: `Esc` triggers Cancel.

### Gamepad navigation (Partial parity per technical-preferences.md)

- **D-pad up/down** moves focus through button stack (mirrors keyboard arrow keys).
- **Left-stick up/down** also moves focus (with a deadzone — left-stick navigation is convenience, not the primary input).
- **A button** = `ui_accept` activates focused button.
- **B button** = `ui_cancel` resumes / backs out.
- **Start button** also fires `pause` from gameplay; on Pause it does NOT close the menu (Esc / B is the close path; Start is open-only). This matches NOLF1 + most stealth-genre conventions.
- **No analog-stick acceleration / inertia** in menu navigation — gamepad focus moves discretely on stick deflection past deadzone, like keyboard arrows. Per Settings input feel.
- **Gamepad rebinding**: full parity with KB+M is **post-MVP** per technical-preferences.md. At MVP+VS, gamepad uses fixed default bindings.

### AccessKit per-widget table (Pause-shell-specific additions to Menu System §C.9)

Inherits Menu System §C.9 conventions. Pause shell adds the following entries (assumes Godot 4.6 AccessKit per ADR-0004 Gates 1+2 verification — flagged in Open Questions if those gates are still open).

| Widget | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| PauseMenu root | `dialog` | `tr("menu.pause.label")` → "Pause Menu" *(NEW STRING — see Localization Considerations)* | (none) | `assertive` one-shot on appearance (CR-21 + F.7) |
| Folder tab Label | `text` | `tr("menu.pause.tab_label")` → operation identifier | (none) | `off` |
| Resume Surveillance button | `button` | `tr("menu.pause.resume")` | `tr("menu.pause.resume.desc")` → "Resume the operation in progress." | `off` |
| File Dispatch button | `button` | `tr("menu.pause.save")` | `tr("menu.pause.save.desc")` → "File the current dispatch — save your progress." | `off` |
| Operations Archive button | `button` | `tr("menu.pause.load")` | `tr("menu.pause.load.desc")` → "Load a previously filed dispatch. Current unsaved progress is lost." | `off` |
| Personnel File button | `button` | `tr("menu.pause.settings")` | `tr("menu.pause.settings.desc")` → (Menu System §C.8 — same desc as Main Menu Settings entry — verify with localization-lead) | `off` |
| Re-Brief Operation button (when visible) | `button` | `tr("menu.pause.restart")` | `tr("menu.pause.restart.desc")` → "Reload the last checkpoint. Recent progress since checkpoint is lost." | `off` |
| Return to Registry button | `button` | `tr("menu.pause.main_menu")` | `tr("menu.pause.main_menu.desc")` → "Return to the main menu. Unsaved progress is lost." | `off` |
| Close File button | `button` | `tr("menu.pause.quit")` | `tr("menu.pause.quit.desc")` → "Quit the application. Unsaved progress is lost." | `off` |

**Assertive one-shot pattern** (per F.7): on `_ready()` after slide-in completes, set `accessibility_live = "assertive"` on PauseMenu root, then `call_deferred` to clear back to `"off"` next frame. This makes the screen reader announce "Pause Menu" exactly once on appearance, not on every focus change. Sub-screen swaps within Pause do NOT re-trigger an assertive announcement (the player is still in Pause; an assertive on every swap is harassment).

**Locale change re-resolve**: every `accessibility_name` and `accessibility_description` re-resolves on `NOTIFICATION_TRANSLATION_CHANGED` per Menu System CR-22 + F.8.

### Visual accessibility

- **Contrast** — all label text (DIN 1451 Engschrift 12 px Parchment on BQA Blue button fill) must meet WCAG AA 4.5:1 minimum. Spot-verify Parchment `#F2E8C8` on BQA Blue `#1B3A6B`: luminance contrast ≈ 8.4:1 → passes AAA. Tab text (Parchment on PHANTOM Red `#C8102E`): contrast ≈ 4.7:1 → passes AA. (Coord: technical-artist runs `contrast_check.sh` on final asset values per accessibility-requirements.md.)
- **Color-as-only-indicator**: the only color signal on Pause is the destructive button group's **opacity-based separator and stamp register** — but every destructive action has a *labeled* button + a confirm modal + a stamp-register stamp. No information is color-only. Compliant.
- **Text size**: button labels 12 px DIN 1451 at 1080p baseline. UI scaling (75–150%) applies via `project_theme.tres` font scale (Settings G.3 `ui_scale`). At 75% the button label is 9 px — still above the 9 px floor (V.9 #8). At 150% it is 18 px. Tab text is 11 px American Typewriter; at 75% scale → 8.25 px which **violates** the 9 px DIN floor / 10 px American Typewriter floor — flag in Open Questions for confirmation that tab text follows Display register, not Body register, and is exempt.
- **Colorblind** — no protanopia / deuteranopia / tritanopia concerns on Pause: the BQA Blue button fill + PHANTOM Red tab band remain distinguishable in all three simulator modes (verified by similar Main Menu palette per main-menu.md accessibility section).

### Photosensitivity

- **No flashing on Pause shell.** No strobe, no animated background, no looping particle. Compliant by absence.
- **No screen flash** on open or close (folder slide is a 2D translation, not a brightness change). Compliant.
- The 52% Ink Black overlay alpha tween (0 → 0.52 over 180 ms) is a luminance reduction over 180 ms — well under the WCAG 2.3.1 / 2.3.2 thresholds (which target rapid full-screen flashing > 3 Hz). Single-event, slow ramp. Compliant.

### Reduced-motion

- Honored via `Settings.accessibility.reduced_motion_enabled`. When `true`:
  - Folder appears / disappears instantly (no slide tween).
  - Overlay alpha jumps (no fade tween).
  - Sub-screen swap: outgoing surface hides instantly, incoming shows instantly.
  - Modal stamp animation suppressed (CANONICAL via `quit-confirm.md`).
- **Audio cues remain at full duration** per Menu System §A.5 — reduced-motion suppresses visual movement, NOT audio confirmation. Critical for players who use reduced-motion AND screen reader (the audio cue is their tactile confirmation that the action took effect).

### Screen-reader walkthrough (manual verification path)

The Pause shell must produce the following announcement sequence for a screen-reader user (Linux Orca / Windows Narrator):

1. Player presses `Esc` from gameplay → **assertive** announcement: "Pause Menu, dialog."
2. Focus on Resume Surveillance → "Resume Surveillance, button. Resume the operation in progress."
3. Player presses Down → focus on File Dispatch → "File Dispatch, button. File the current dispatch — save your progress."
4. Player presses Down repeatedly through stack — each button announces name + description.
5. Player presses Tab from last button → focus cycles to first (Resume).
6. Player presses `Esc` → folder slides out, no announcement on close (the gameplay scene's HUD State Signaling polite live-region resumes, but Pause itself emits no farewell).

This walkthrough is captured as a manual test step in `production/qa/evidence/pause-menu-screen-reader-walkthrough-[date].md` per the accessibility-requirements.md AccessKit test plan row.

### Accessibility carve-outs (none required)

The Pause shell does not require a Pillar-5 carve-out for any accessibility feature at MVP+VS. The carve-out pattern (Cutscenes Stage-Manager) is reserved for Pillar-5 absolutes that conflict with WCAG (e.g., the no-first-watch-cinematic-skip rule). Pause has no such absolute — it is procedurally driven and accessible by default.

---

## Localization Considerations

### Strings owned by this spec (NEW — to be added to Menu System §C.8)

| tr-key | English | English chars | Layout-critical? | Notes |
|---|---|---|---|---|
| `menu.pause.label` | Pause Menu | 10 | No (AccessKit only) | Used for `accessibility_name` of PauseMenu root. Not visible on screen. |
| `menu.pause.tab_label` | STERLING, E. — OPÉRATION TOUR D'IVOIRE — BQA/65 | 47 | **YES — must fit 140 × 28 px tab at all locales** | Tab body text per V.1. Confirm with localization-lead whether tab is body-copy carve-out from L212 ≤ 25 char rule (already mixed-language English/French in source — French portion is intentional period flavor and remains constant across locales) |
| `menu.settings.field_notes.tab` | Field Notes | 11 | No (tab label within Settings panel) | **NEW STRING REQUIRED** — tab label for the read-only tutorial dialogue sub-panel inside Personnel File / Settings panel. Must be added to Menu System §C.8 locked strings table. Period register: "Field Notes" fits the 1965 spy-bureaucracy register (a BQA dispatcher's hand-written reminders on the case file). Short enough to fit a tab label at all locales even with 40% expansion (~15 chars). Coord with localization-lead to confirm locale-invariant proper-noun status is not needed here (unlike `menu.pause.tab_label`). |

### Strings already locked (Menu System §C.8) — referenced but not re-declared

| tr-key | English | English chars |
|---|---|---|
| `menu.pause.resume` | Resume Surveillance | 19 |
| `menu.pause.save` | File Dispatch | 13 |
| `menu.pause.load` | Operations Archive | 18 |
| `menu.pause.settings` | Personnel File | 14 |
| `menu.pause.restart` | Re-Brief Operation | 18 |
| `menu.pause.main_menu` | Return to Registry | 18 |
| `menu.pause.quit` | Close File | 10 |

All seven button labels are within the L212 25-char cap at English baseline. The longest is `Resume Surveillance` at 19 characters.

### Expansion budget per button

Buttons are **480 px wide × 32 px tall**. DIN 1451 Engschrift 12 px is the rendering register; advance width ≈ 5.4 px per character at 12 px (Engschrift is condensed). At 480 px width with 16 px L/R padding → 448 px usable → **~83 character ceiling per button at 12 px**. Buttons therefore have substantial expansion headroom — even a 40% expansion in German (typical) on `Resume Surveillance` (19 → ~27 chars) fits easily.

| English | EN chars | At 40% expansion | At 60% expansion | Within 83-char button limit? |
|---|---|---|---|---|
| Resume Surveillance | 19 | 27 | 30 | ✅ |
| File Dispatch | 13 | 18 | 21 | ✅ |
| Operations Archive | 18 | 25 | 29 | ✅ |
| Personnel File | 14 | 20 | 22 | ✅ |
| Re-Brief Operation | 18 | 25 | 29 | ✅ |
| Return to Registry | 18 | 25 | 29 | ✅ |
| Close File | 10 | 14 | 16 | ✅ |

**Conclusion**: button labels have generous overflow headroom. The 12 px Engschrift register can accept text expansion up to ~80 characters before breaking the layout. Localization risk for button labels is **LOW**.

### Layout-critical strings (HIGH PRIORITY for localization-lead)

The Pause shell has **one** layout-critical string:

- **`menu.pause.tab_label`** — must fit the 140 × 28 px tab. The English / French source string is 47 chars; at 11 px American Typewriter the tab is already at its visual capacity. Localized variants (German, Spanish, Italian, etc.) MUST not exceed the source character count, OR the tab must grow. Two resolution paths:
  1. **Treat tab_label as a non-localized "asset string"** (it is mixed English/French in source — STERLING is the agent's name, OPÉRATION TOUR D'IVOIRE is the case codename, BQA is an acronym). All three are proper nouns in-fiction and should NOT translate. **Recommended path** — tab text is locale-invariant.
  2. **Localize but cap at 47 chars** — translator brief includes a hard 47-char cap for this key.
  
  Coord with localization-lead before VS sprint to confirm path 1.

### Number / date / currency formatting

Pause has no numeric or date display. The tab text is the only string with numeric content (`BQA/65` — year reference, treated as proper noun). No locale-specific formatting needed on Pause shell. (Sub-screens — Save grid card metadata `14:23 GMT` — own their own date/time formatting.)

### RTL (right-to-left) language support

- **Not committed at MVP+VS.** Project locale roadmap is EN (MVP) → FR + DE (VS) → ES + IT (post-launch). Arabic / Hebrew RTL not committed for v1.0.
- If RTL is added post-launch, the layout requires:
  - Folder anchor mirrors to bottom-LEFT instead of bottom-right.
  - Button stack right-aligns text.
  - Tab anchor mirrors to 1/3 across folder width from left (so it remains "near the spine" of the file).
  - Icons (BQA seal watermark, fountain-pen cursor) — pen cursor hotspot stays top-right (fountain pens are right-handed in 1965 register; left-handed mirror is post-launch consideration).

### `auto_translate_mode` policy

Per Menu System UI-1 + Localization L129: every static `Label` uses `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. Dynamic strings (none on Pause shell) would use explicit `tr()` and a `NOTIFICATION_TRANSLATION_CHANGED` handler. AccessKit `accessibility_name` / `accessibility_description` re-resolve on locale change per CR-22 + F.8.

### Translator brief inputs (for `dialogue-writer-brief.md` extension)

When the localization pipeline kicks off, the translator brief MUST include:

1. **Register**: 1965 British civil-service / spy-bureaucracy. Avoid modern register ("Pause Menu" → never; "File Dispatch" / "Operations Archive" instead).
2. **Tab text is proper-noun bundle** — treat as locale-invariant (path 1 above).
3. **`Re-Brief Operation` is destructive** — the translation should clearly imply *redoing* the operation, not "briefing again" (some languages would naturally translate "re-brief" as "briefing once more" which loses the "you're losing checkpoint progress" weight). Translator must understand the destructive register.
4. **Character cap**: 80 char per button (well above any expected expansion); tab text 47 char max.
5. **Reference**: `dialogue-writer-brief.md` (Menu System inheritance) — same register and tone applies.

### Coord items for localization-lead (before VS sprint)

- [ ] Confirm `menu.pause.tab_label` is treated as locale-invariant (path 1) OR capped at 47 chars (path 2).
- [ ] Confirm `menu.pause.label` AccessKit string is brief and announced as "Pause Menu" register equivalent (not "Operations Pause" or other invented translation).
- [ ] Add `menu.pause.label` and `menu.pause.tab_label` keys to Menu System §C.8 locked strings table.
- [ ] No reading-speed test required for Pause shell — there is no auto-dismissing element. (GAP-4 reading-speed concerns apply to Cutscenes Mission Cards, not Pause.)

---

## Acceptance Criteria

QA-verifiable criteria for the Pause shell. Each criterion is testable without reference to other design docs. Sub-screen / modal criteria are owned by their respective UX specs (`load-game-screen.md`, `save-game-screen.md`, `quit-confirm.md`, `save-failed-dialog.md`, etc.) and not re-declared here.

### Mount & Default State

- [ ] **AC-PAUSE-1.1 [Logic]** Pressing `Esc` from `Context.GAMEPLAY` in Plaza section mounts a `PauseMenu.tscn` instance as a child of `get_tree().current_scene` within 1 frame, and `InputContextStack.peek() == Context.PAUSE` within the same frame.
- [ ] **AC-PAUSE-1.2 [Logic]** `get_tree().paused` remains `false` throughout Pause Menu lifetime — gameplay scene continues to tick (subscribers verify via `_process` counter on a test node embedded in the section).
- [ ] **AC-PAUSE-1.3 [Visual]** Pause Menu mount produces a screenshot showing: (a) gameplay framebuffer visible behind overlay, (b) 52% Ink Black `ColorRect` overlay between gameplay and folder, (c) folder anchored bottom-right at final position, (d) tab text reads `STERLING, E. — OPÉRATION TOUR D'IVOIRE — BQA/65`. Evidence: `production/qa/evidence/pause-mount-[date].png`.
- [ ] **AC-PAUSE-1.4 [Logic]** After 180 ms slide-in tween completes, `Resume Surveillance` button has focus (`button.has_focus() == true`).
- [ ] **AC-PAUSE-1.5 [Logic]** During the 180 ms slide-in tween, the Pause button container has `process_input == false` (prevents same-frame double-press race).

### Performance

- [ ] **AC-PAUSE-2.1 [Logic]** Pause `_ready()` completes in < 16 ms on minimum target hardware (Iris Xe per accessibility-requirements.md / engine reference). Profile via Godot profiler frame capture.
- [ ] **AC-PAUSE-2.2 [Logic]** Pause Menu has no `_process()` or `_physics_process()` overrides on root or button-stack Controls. Verify by grepping `pause_menu.gd` and child scripts for `func _process` / `func _physics_process` — no matches.
- [ ] **AC-PAUSE-2.3 [Logic]** Closing Pause and re-opening it 10 times in succession does not leak nodes — `get_tree().get_node_count()` returns to baseline ±5 nodes after the 10th close.

### Resume Path

- [ ] **AC-PAUSE-3.1 [Logic]** Activating `Resume Surveillance` (or pressing `Esc` at root) calls `set_input_as_handled()` BEFORE `InputContextStack.pop()`. Order verified by injecting a test handler that records the order of (a) input-handled marker and (b) context pop.
- [ ] **AC-PAUSE-3.2 [Logic]** After Resume, `Input.mouse_mode == MOUSE_MODE_CAPTURED` within 2 frames (PC's `_on_input_context_changed` handler restores capture).
- [ ] **AC-PAUSE-3.3 [Logic]** When `move_forward` was held during Pause open, after Resume `Input.is_action_pressed(&"move_forward") == true` immediately, and PC's velocity restores within 1 frame (PC GDD owns this — Pause does not interfere).
- [ ] **AC-PAUSE-3.4 [Visual]** Pause close animation: folder slides 140 ms `TRANS_CUBIC EASE_IN` back down off-screen; overlay alpha tweens 0.52 → 0 over 140 ms; A3 drawer-slide-out audio fires at tween start.

### Navigation & Focus

- [ ] **AC-PAUSE-4.1 [Logic]** Tab key cycles focus through 7 buttons (or 6 if Re-Brief hidden) in top-to-bottom order: Resume → File Dispatch → Operations Archive → Personnel File → [Re-Brief] → Return to Registry → Close File. Last button → Tab → cycles to Resume.
- [ ] **AC-PAUSE-4.2 [Logic]** Down-arrow has identical behavior to Tab in the button stack. Up-arrow / Shift-Tab are reverse.
- [ ] **AC-PAUSE-4.3 [Integration]** Gamepad D-pad-down moves focus to next button (mirrors Tab). Gamepad A activates focused button (mirrors Enter). Gamepad B at root resumes (mirrors Esc).
- [ ] **AC-PAUSE-4.4 [Logic]** Mouse hover on a button does NOT change focus (Pillar 5 V.9 #4). Mouse click DOES focus + activate.
- [ ] **AC-PAUSE-4.5 [Logic]** When sub-screen (Save / Load grid) closes via `ui_cancel`, focus returns to the triggering button (File Dispatch / Operations Archive) on Pause root — verified via `Control.has_focus()` immediately post-swap-back.

### Pause-Blocked Contexts

- [ ] **AC-PAUSE-5.1 [Integration]** Pressing `Esc` while `Context.LOADING` is active does NOT mount Pause (Failure & Respawn AC-FR-7.3 / Level Streaming LS-Gate-2). Pause's `_unhandled_input` silently consumes the event.
- [ ] **AC-PAUSE-5.2 [Integration]** Pressing `Esc` while `Context.DOCUMENT_OVERLAY` is active does NOT mount Pause; Document Overlay's dismiss handler runs instead.
- [ ] **AC-PAUSE-5.3 [Integration]** Pressing `Esc` (or Start) while `Context.CUTSCENE` is active does NOT mount Pause (per Cutscenes CR-CMC-7).
- [ ] **AC-PAUSE-5.4 [Logic]** Pressing `pause` action while `Context.PAUSE` is already active does NOT mount a second Pause instance — `_unhandled_input` silently consumes; `peek() == PAUSE` remains.

### Audio Invariants

- [ ] **AC-PAUSE-6.1 [Integration]** While Pause is mounted over an active gameplay section with music playing, the section's ambient music continues playing without volume change or interruption (Menu System AC-MENU-2.4, AFP-1).
- [ ] **AC-PAUSE-6.2 [Logic]** A2 drawer-slide-in audio fires at tween start (frame 0 of mount, BEFORE folder is fully visible). A3 drawer-slide-out fires at tween start of close.
- [ ] **AC-PAUSE-6.3 [Logic]** Activating any button fires A1 typewriter-clack on `pressed` (not `released`); cue duration 60–80 ms; UI bus.
- [ ] **AC-PAUSE-6.4 [Logic]** Sub-screen swap fires A7 paper-shuffle (90–110 ms); UI bus.
- [ ] **AC-PAUSE-6.5 [Logic]** All Pause-owned audio cues route to UI bus only — never SFX, Music, Voice, or Ambient (AFP-4). Verify by inspecting cue's `bus` property in `AudioStreamPlayer`.

### Reduced-Motion

- [ ] **AC-PAUSE-7.1 [Integration]** With `accessibility.reduced_motion_enabled == true`, opening Pause skips the slide-in tween — folder appears at final anchor instantly; overlay alpha jumps 0 → 0.52 instantly.
- [ ] **AC-PAUSE-7.2 [Integration]** With reduced-motion enabled, A2 drawer-slide audio cue STILL plays at full duration (Menu System §A.5 — audio is not reduced-motion-gated).

### Accessibility (AccessKit)

- [ ] **AC-PAUSE-8.1 [UI]** Manual screen-reader walkthrough (Linux Orca or Windows Narrator): Pause appears → assertive announcement "Pause Menu, dialog" within 500 ms of mount. Each button announces name + description on focus. Evidence: `production/qa/evidence/pause-screen-reader-[date].md` + ux-designer sign-off.
- [ ] **AC-PAUSE-8.2 [Logic]** PauseMenu root has `accessibility_role = "dialog"`, `accessibility_name = tr("menu.pause.label")`, and `accessibility_live = "assertive"` set immediately before `_ready()` completes. Cleared to `"off"` next frame via `call_deferred`.
- [ ] **AC-PAUSE-8.3 [Logic]** Each button has `accessibility_role = "button"` and a non-empty `accessibility_description` (`tr("menu.pause.[id].desc")` returns a string > 0 chars).
- [ ] **AC-PAUSE-8.4 [Logic]** On `NOTIFICATION_TRANSLATION_CHANGED`, all `accessibility_name` and `accessibility_description` values re-resolve via `tr()` calls — verified by switching locale at runtime (post-VS) and inspecting properties.
- [ ] **AC-PAUSE-8.5 [Logic]** Tab key cycles focus only within the button stack — Tab does NOT move focus to gameplay-scene Controls (focus trap CR-24). Verify by injecting Tab key inputs and checking `get_viewport().gui_get_focus_owner()` is always a Pause button.

### Visual Compliance

- [ ] **AC-PAUSE-9.1 [Visual]** No drop shadows / soft glows on any button at any state (idle / focused / hover / pressed / disabled). Inspect `StyleBoxFlat` properties: `shadow_size == 0` on every state (V.9 #2).
- [ ] **AC-PAUSE-9.2 [Visual]** No corner radius on any interactive element. `corner_radius_top_left/right` and `corner_radius_bottom_left/right` all `0` (V.9 #1).
- [ ] **AC-PAUSE-9.3 [Visual]** No gradient fills. Every `StyleBoxFlat` uses solid `bg_color` only — `bg_color` matches a locked palette value (BQA Blue / Parchment / Ink Black / PHANTOM Red / Alarm Orange / manila-buff).
- [ ] **AC-PAUSE-9.4 [Visual]** Pause does NOT render: document collection counter, mission objective text, time-played counter, alarm-state indicator, kill-count, mini-map, waypoint, progress bar, achievement notification. CI grep test: scan `pause_menu.tscn` and child scenes for any `Label` whose text contains `"of"` + `/` digits (the FP-DC-2 anti-pattern), or contains `"objective"`, or contains `:%s` time-formatter strings.
- [ ] **AC-PAUSE-9.5 [Visual]** Folder asset anchored bottom-right; tab visible top of folder body at ~2/3 across width from left edge. Visual diff against `production/qa/evidence/pause-mount-[date].png` ref capture.

### Re-Brief Conditional Visibility (VS+)

- [ ] **AC-PAUSE-10.1 [Logic]** When `MissionLevelScripting.has_checkpoint_in_current_section() == false`, the Re-Brief Operation button is NOT present in the Pause button stack (not just `disabled` — `queue_free()`d or `visible = false` AND removed from focus order). Verify: `get_tree().get_nodes_in_group("pause_buttons").size() == 6` and no node named `RebriefButton`.
- [ ] **AC-PAUSE-10.2 [Logic]** When checkpoint state is `true`, Re-Brief Operation button IS present, focus order includes it between Personnel File and Return to Registry. Tab Personnel File → Tab → Re-Brief.
- [ ] **AC-PAUSE-10.3 [Logic]** Activating Re-Brief opens the Re-Brief-Confirm modal (CANONICAL via `quit-confirm.md` register); default focus on Cancel; `Context.MODAL` pushed.

### State Invariants

- [ ] **AC-PAUSE-11.1 [Logic]** During Pause lifetime, `InputContextStack.peek() == Context.PAUSE` (or `Context.MODAL` / `Context.SETTINGS` if a child surface is open).
- [ ] **AC-PAUSE-11.2 [Logic]** Pause `_exit_tree()` calls `disconnect()` on every signal it subscribed to in `_ready()` — `Events.save_failed`, `Events.game_saved`, `Events.game_loaded`. Verified via `is_connected()` check post-`_exit_tree()` returns `false`.
- [ ] **AC-PAUSE-11.3 [Logic]** Pause does NOT modify `Settings.cfg`, `SaveGame.res`, or any other persistent file. Verify by hashing `user://settings.cfg` and `user://saves/*.res` before and after a Pause-open-then-close cycle — hashes match.
- [ ] **AC-PAUSE-11.4 [Logic]** Pause has no static / autoload registration — it is purely scene-tree-instantiated. Verify by grepping the autoload list in `project.godot` for "Pause" — no matches.

### Cross-Reference (this spec depends on)

- [ ] **AC-PAUSE-12.1 [Spec-trace]** `quit-confirm.md` is APPROVED at the time of Pause implementation start (Pause inherits the Quit-Confirm modal pattern; without that spec approved, Pause's destructive flow is incomplete).
- [ ] **AC-PAUSE-12.2 [Spec-trace]** `settings-and-accessibility.md` is APPROVED (Personnel File button calls `SettingsService.open_panel()`).
- [ ] **AC-PAUSE-12.3 [Spec-trace]** Save/Load co-owned UX specs (`load-game-screen.md`, `save-game-screen.md`, `save-failed-dialog.md`) are AT LEAST IN-DESIGN at the time of Pause implementation start — Pause sub-screen behavior depends on them.

### Advisory Resolutions (added 2026-04-29 per `/ux-review`)

- [ ] **AC-PAUSE-13 [Logic]** With `Settings.ui_scale = 0.75`, the tab text `Label` renders at 11 px source size — NOT the scaled-down 8.25 px. Verifiable via `Label.get_theme_font_size()` returning `11` when `ui_scale == 0.75`. Resolves OQ-PM-4.

### Tutorial Persistence (added 2026-04-29 per `/ux-review` — closes OQ-PM-12 accessibility commitment)

- [ ] **AC-PAUSE-14 [UI]** From `Pause → Personnel File → Field Notes` (always available, no checkpoint or scope gating), the sub-panel displays all 5 Plaza tutorial dialogue lines verbatim as readable, static text. Lines are present and legible at `ui_scale` 75–150%. Verifiable by opening Pause during Plaza section and confirming all 5 tutorial lines appear in the Field Notes view, regardless of checkpoint state or MVP scope-lock state. Cross-ref: `design/accessibility-requirements.md` "Tutorial persistence" row (Standard tier, Designed).

### Coverage

- [Performance: 1] AC-PAUSE-1.1 / 2.1 / 2.2
- [Navigation: 1] AC-PAUSE-3.1 / 4.1 — 4.5
- [Error / blocked-context: 1] AC-PAUSE-5.1 — 5.4
- [Accessibility: 1] AC-PAUSE-8.1 — 8.5
- [Pause-purpose-specific: 1] AC-PAUSE-1.3 / 6.1 / 9.4
- [Advisory resolutions: 1] AC-PAUSE-13
- [Tutorial persistence: 1] AC-PAUSE-14

Total: 38 ACs (within Menu System AC-budget norms — Menu System GDD has 61 ACs across 20 groups; Pause shell carving out ~38 is proportionate).

---

## Open Questions

| # | Question | Owner | Resolution Path | Default if unresolved |
|---|---|---|---|---|
| **OQ-PM-1** | **Re-Brief Operation visibility — MVP-vs-VS scope conflict.** F&R L345 scope-locks (2026-04-24) "no Pause-Menu restart button at MVP — player uses Load Game"; Menu System §C.2 row 12 + §C.8 lock the strings + modal for VS scope; F&R OQ-FR-11 has the playtest gate open. Outcome unclear: does Re-Brief land at VS regardless of playtest, or is it gated on Tier 0 Plaza playtest evidence? | game-designer + producer + creative-director | Tier 0 Plaza playtest (per F&R OQ-FR-11): observers log how often players quit-to-menu to Load after a botched stealth attempt. If frequency > 30% of failed-stealth events, ship Re-Brief at VS. If lower, defer to Polish. | Re-Brief is **hidden at MVP**, present at VS once `MissionLevelScripting.has_checkpoint_in_current_section() == true`. Default matches F&R scope-lock conservatively. |
| **OQ-PM-2** | **`MissionLevelScripting.has_checkpoint_in_current_section()` API contract.** This spec assumes a synchronous bool query. Is the actual API signature `bool` or `Promise<bool>`? Does it throw on unloaded section? Is there a `signal checkpoint_state_changed` Pause should subscribe to instead of polling on `_ready()`? | mission-level-scripting GDD owner + lead-programmer | Add API row to Mission & Level Scripting GDD §B (Detailed Rules) before Pause epic kickoff. Recommend synchronous bool with caching; signal subscription would over-engineer for a `_ready()`-only consumer. | Pause polls synchronously on `_ready()` only. If API is async, Pause's `_ready()` `await`s before showing button stack — adds 1-2 frame delay (acceptable since slide-in is 180 ms). |
| **OQ-PM-3** | **Tab text localization policy** — locale-invariant proper-noun bundle (path 1) or capped 47-char localized (path 2)? See Localization Considerations. | localization-lead | Translator brief discussion before VS sprint. Path 1 is recommended (period flavor + proper nouns); path 2 is the fallback if translator pushback comes. | **Path 1: locale-invariant.** Tab text reads the same in every locale. |
| **OQ-PM-4** | ~~**Tab text 11 px floor at 75% UI scale.**~~ **RESOLVED 2026-04-29 (per `/ux-review`)**: Tab text `font_size` clamped at source value (11 px) regardless of `Settings.ui_scale = 0.75`. Tab text is identification chrome; it does not scale down with body text. Per `/ux-review` 2026-04-29. See AC-PAUSE-13. | art-director + ux-designer | RESOLVED | **Clamp tab text scale at minimum 100%** — tab text is identification chrome, not body content; it does not benefit from down-scaling and the 11 px source already passes legibility at 1080p. |
| **OQ-PM-5** | **Visual separator between Personnel File and Re-Brief — required or advisory?** This spec proposes a 1 px ruled Ink Black 30% line separator suggesting "below the fold" register for destructive actions. Required by Pillar 5 grouping clarity, or is opacity differentiation alone enough? | art-director | `/ux-review` decision; coord with art-director per Section C component inventory note. | **Advisory** — implement it as a Theme override; if art-director rejects at review, remove. |
| **OQ-PM-6** | **Gamepad-disconnect-during-Pause** — should Pause auto-prompt "reconnect controller" advisory? Input GDD §Edge Cases L180 + Menu System advisory coord exist but are not closed. | input-system owner + ux-designer | Post-VS playtest with adaptive-controller users. Decision at first soak playtest. | **No auto-prompt at MVP+VS.** KB+M remains usable; gamepad can be re-plugged silently. Re-evaluate if accessibility playtest surfaces a need. |
| **OQ-PM-7** | **Quicksave / Quickload feedback card position — adjacent-to-folder vs over-folder?** When Pause is open and player presses F5, where does `DISPATCH FILED` render? This spec says "bottom-right adjacent to folder", but the folder itself occupies bottom-right. Risk of overlap. | ux-designer + technical-artist | Resolve while authoring `quicksave-feedback-card.md`. Likely candidate: shift feedback card to top-right of viewport when Pause is open (it lives below the folder when Pause is closed; moves out of the folder's path when open). | Defer to `quicksave-feedback-card.md` authoring. Pause shell does not constrain — flag the constraint in that spec. |
| **OQ-PM-8** | **Analytics events for Pause** — should `pause.opened` / `pause.closed` / `pause.button_activated` events fire at MVP+VS? | analytics-engineer + producer | Analytics layer scope decision is post-MVP — defer to that conversation. | **No analytics events at MVP+VS.** Hooks left in code as `// TODO(analytics)` comments only if the analytics layer is committed. |
| **OQ-PM-9** | **AccessKit `dialog` role on a non-modal overlay** — Godot 4.6 AccessKit may treat `dialog` role as implying modality (and announcing as such). The Pause shell is *modal-via-context-stack* but not OS-modal. Is `dialog` the right role, or should it be `landmark` (like Main Menu per Menu System §C.9)? | godot-specialist + ux-designer | ADR-0004 Gates 1+2 verification batch + AccessKit role taxonomy investigation (per accessibility-requirements.md OQ row "Does Godot 4.6 AccessKit support the full role taxonomy"). | **Default to `dialog`** matching Menu System §C.2 row 6 (PauseMenu shell row). **Fallback gate (per `/ux-review` 2026-04-29)**: if ADR-0004 AccessKit Gates 1+2 are NOT verified before Pause Menu epic kickoff, `accessibility_role` defaults to `landmark` — `dialog` role is adopted only after positive verification of screen-reader behavior in Godot 4.6. If verification shows the announcement is wrong-register, revise to `landmark` and update Menu System §C.9. |
| **OQ-PM-10** | **Pause behavior under ultrawide (21:9) and 16:10** — folder anchor is bottom-right at 16:9 baseline. On 21:9 the folder remains bottom-right and visible-gameplay area widens; on 16:10 / Steam Deck (1280×800) the folder may exceed viewport. | technical-artist + ux-designer | Aspect-ratio test pass during VS sprint. Steam Deck verification is post-launch (per accessibility-requirements.md). | **16:9 only at MVP+VS.** 21:9 is acceptable (folder stays anchored, gameplay area widens). 16:10 / Steam Deck deferred to post-launch — clamp folder size to viewport-min if it overflows. |
| **OQ-PM-11** | **Save-Failed modal queue policy when Pause is opened-then-closed-then-re-opened** — if `Events.save_failed` fires while Pause is closed, then Pause re-opens, does Save-Failed modal appear? Save/Load CR-9 + Menu System CR-10 imply yes (subscribers re-mount on re-mount); but the player may have already navigated past the failed-save context. | save-load + ux-designer | Coord at sprint kickoff. Likely answer: save-failed events are NOT queued across Pause-mount-cycles; only the most-recent-while-mounted save-failed wins. | **Save-Failed modal does NOT persist across Pause unmount-remount.** If save-failed fires while Pause is closed, the HUD State Signaling SAVE_FAILED visual handles it (HSS owns the persistent display). Pause Menu's modal is for "save attempted while in Pause" cases only. |
| **OQ-PM-12** | ~~**First-time Pause session — should there be a one-shot tutorial overlay?**~~ **RESOLVED 2026-04-29 (per `/ux-review`)**: Two distinct requirements were conflated here. (1) First-time tutorial overlay on Pause open: **forbidden** — Pillar 5, no modern hand-holding, no coach-marks (remains unchanged). (2) Persistent re-access to Plaza tutorial dialogue for cognitive-accessibility users: **required** under `design/accessibility-requirements.md` "Tutorial persistence" row (Standard tier, Designed). Resolution (revised 2026-04-29, Option A per `/ux-review` re-review): tutorial persistence routes through **Personnel File → Field Notes** tab. The Field Notes tab is a read-only sub-panel inside the Personnel File / Settings panel, always visible — not gated on checkpoint state, Re-Brief button visibility, or OQ-PM-1 scope-lock. Players access the 5 Plaza tutorial dialogue lines verbatim at any time during the mission via `Pause → Personnel File → Field Notes`. No first-time overlay; no coach-marks; player-initiated access only. See AC-PAUSE-14 for verification. Cross-ref: `design/accessibility-requirements.md` "Tutorial persistence" row. | game-designer + creative-director | RESOLVED | **No first-time tutorial overlay.** Tutorial dialogue re-access lives in the Field Notes tab inside the Personnel File / Settings panel — always available, no Re-Brief dependency, no checkpoint gating, not affected by OQ-PM-1 scope-lock. |

### Tracking

These OQs are cross-referenced into:
- F&R OQ-FR-11 (Re-Brief playtest gate)
- Mission & Level Scripting (new API row required)
- Menu System §C.8 (new strings to lock)
- accessibility-requirements.md (Godot 4.6 AccessKit role taxonomy verification batch)
- `quicksave-feedback-card.md` (TBD — Pause-coexistence rule)
- `save-failed-dialog.md` (TBD — cross-Pause-cycle queue policy)

OQs are tracked in `production/qa/evidence/ux-spec-pause-menu-oqs.md` after `/ux-review` (created during review).
