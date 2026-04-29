# UX Spec: New-Game-Overwrite Confirm Modal

> **Status**: In Design
> **Author**: ux-designer + user
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: P0 Boot → P1 Main Menu (returning-player branch when slot 0 is OCCUPIED, OR slot 0 is EMPTY/CORRUPT and Continue label-swapped to "Begin Operation")
> **Template**: UX Spec
> **Register**: HYBRID — Case File scaffold (modal-scaffold + case-file-destructive-button) + destructive header band (PHANTOM Red `#C8102E`, sibling of save-failed)
> **Pattern Inheritance**: `quit-confirm.md` (CANONICAL Case File modal-scaffold reference) — new-game-overwrite inherits the modal scaffold + button chrome + focus contract + accessibility patterns; this spec only documents what differs (PHANTOM Red header band vs. Ink Black; destructive payload is `LS.transition_to_section(NEW_GAME)` rather than `quit()`; trigger is `MainMenu.NewGameButton.pressed` OR `ContinueButton.pressed` when slot 0 EMPTY/CORRUPT per CR-5/CR-6).

---

## Purpose & Player Need

The New-Game-Overwrite Confirm Modal is a destructive-action guard that prevents a returning player from accidentally erasing their autosave (slot 0) when they activate "New Game" or the label-swapped "Begin Operation" Continue button on the Main Menu. It is the deliberate friction layer between *intent to start fresh* and *destruction of save state*.

The player's goal at this surface is one of two:
1. **Confirm intent to begin a new operation** — they have read the warning, accept that their autosave will be overwritten, and want to proceed (Confirm path → `LS.transition_to_section(first_section_id, null, NEW_GAME)`).
2. **Recover from a misclick** — they pressed New Game without realizing it would destroy their progress; they need a clean way back to the Main Menu without losing anything (Cancel path → `ModalScaffold.hide_modal()` → focus restored to the originating button).

**Why this screen exists** (the failure mode it prevents): without this guard, a returning player whose slot 0 is OCCUPIED who clicks "New Game" — perhaps to read the briefing intro again, or because they thought "New Game" meant "Load most recent" in another game's vocabulary — would silently destroy their autosave on the next section transition. This is an irreversible operation; CR-5 and CR-6 (`design/gdd/menu-system.md`) explicitly mandate the confirm-modal guard after design-review 2026-04-27 rejected silent fall-through as a destructive UX risk.

The modal also serves the **slot 0 EMPTY/CORRUPT** path (CR-5 destructive guard amendment): when the Continue button has label-swapped to "Begin Operation" because no valid autosave exists, *every* activation of that button still routes through this modal — closing the destructive-silent-swap risk for returning players whose slot 0 corrupted between sessions.

The player arrives at this screen wanting to **decide**, not to read or browse. The screen's job is to make the decision unambiguous (which slot is at risk, what will be lost, which button does which) and instant (one keypress to confirm, one to cancel, default focus on the safe action).

---

## Player Context on Arrival

**When does a player first encounter this screen?**

The Player encounters the New-Game-Overwrite modal in two distinct contexts on the Main Menu:

1. **OCCUPIED slot 0 + activated New Game button** (most common returning-player path): The player has played at least one section, returned to the Main Menu (either via Pause Menu → Return to Registry, or by relaunching the game), and activated the secondary "New Game" button (label: "Open New Operation") to deliberately start fresh. They expect a destructive confirm. Emotional state: **deliberate, calm, ready to commit** OR **uncertain, second-guessing** — the modal's job is to support both.

2. **EMPTY/CORRUPT slot 0 + activated Continue button** (CR-5 fall-through path): The player has launched the game; the Continue button label has swapped to "Begin Operation" because their previous autosave is missing or corrupt. They activate it expecting to begin the game. The modal warns them that their (corrupt) autosave will be overwritten. Emotional state: **confused, possibly concerned** — they may not realize their previous save existed but is corrupted; the modal's body copy must not panic them.

In either case, the player has just emerged from the photosensitivity boot warning (if first launch) or from a calm Main Menu state. They are NOT in a time-pressured or stressed context — this modal can afford to ask for considered input. There is no in-flight gameplay; nothing burns down while the modal is open.

**What were they just doing?**

- Likely just paused, navigated the Main Menu's button stack with Tab/D-pad, and activated New Game or Continue.
- May have been reading the Continue button's slot-0 metadata snippet (e.g., "Section 3 — The Approach, 2:47 played") and decided they wanted to start over instead of resume.
- May be a first-time player who clicked New Game out of habit and is encountering the modal as confirmation of "yes, this game has an explicit New Game flow — good".

**Emotional state assumed by the design**: **calm with mild caution**. The modal is a quiet bureaucratic prompt, not an alarm. It uses period-typewriter copy, deadpan tone, and the BQA dossier voice — the bureaucracy is the joke. Pillar 1 (Period Authenticity) forbids any "Are you sure???" paternalism; the body simply states the consequence ("Autosave will be overwritten.") and offers two clear actions.

**Voluntary or involuntary arrival?**

The arrival is always **voluntary** — the player explicitly activated a button. The modal is a deliberate friction layer, not a redirect. The player can always cancel and restore their original Main Menu state with no side effects.

---

## Navigation Position

This screen lives at:

```
[Boot] → [Main Menu] → [New-Game-Overwrite Modal]
                       ↳ on Confirm: → [Section Scene NEW_GAME]
                       ↳ on Cancel:  → [Main Menu] (focus restored)
```

The modal is a **non-replacing overlay** mounted by `ModalScaffold` at CanvasLayer 1024 (per `design/gdd/menu-system.md` ADR-0004 IG7 — modals layer above Main Menu's CanvasLayer 0). The Main Menu remains visible underneath the 52% Ink Black backdrop dim, but its input is gated by `Context.MODAL` push.

**Alternate entry paths**:
- The modal is **only** reachable from the Main Menu (CR-5 / CR-6 scope). It is NOT reachable from:
  - Pause Menu (Pause uses `return-to-registry` confirm modal, not this one)
  - Save Game Screen (overwrite-on-save uses a different modal — see Open Question #2)
  - Mid-gameplay (no in-section path opens this modal)
- The originating button is one of:
  - `MainMenu.NewGameButton` (when slot 0 OCCUPIED — label "Open New Operation")
  - `MainMenu.ContinueButton` when its label has swapped to "Begin Operation" (slot 0 EMPTY/CORRUPT per CR-5)

**Context dependency**: this screen is **always** context-dependent — it cannot be reached without an upstream button press, and the upstream button's availability depends on slot 0 metadata + the photosensitivity boot warning having been dismissed.

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Main Menu — `NewGameButton.pressed` | Player activates "Open New Operation" button (only visible when slot 0 OCCUPIED — see Open Question #1 from `main-menu.md`) | Slot 0 metadata is OCCUPIED with valid section_id, elapsed_time, etc. The player is intentionally choosing to overwrite. |
| Main Menu — `ContinueButton.pressed` (label-swapped to "Begin Operation") | Player activates Continue button when slot 0 is EMPTY or CORRUPT (CR-5 destructive guard) | Slot 0 metadata is null, empty Dictionary, or `state == CORRUPT`. The player may believe they are resuming; the modal corrects this. |

**No other entry path exists.** The modal cannot be summoned from:
- Pause Menu (Pause uses `return-to-registry.md`)
- Save Game Screen (a different overwrite modal — Open Question #2)
- Quicksave / Quickload
- Cheat menu / debug tools

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Section Scene (NEW_GAME)** | Confirm button pressed (Enter / Space / `ui_accept` while focused, OR mouse click on "Begin Operation" button) | **Destructive — irreversible.** Calls `LS.transition_to_section(first_section_id, null, NEW_GAME)`. Slot 0's prior contents are overwritten by LS's first-autosave trigger on section entry (per `save-load.md` CR-1, CR-3). Main Menu is destroyed. No `await` between Confirm press and LS call. |
| **Main Menu (focus restored)** | Cancel button pressed (Enter / Space / `ui_accept` while focused, OR mouse click on "Cancel" button) | Non-destructive. `ModalScaffold.hide_modal()` pops `Context.MODAL`, restores `process_input = true` on Main Menu button container, returns focus to the originating button (NewGameButton OR ContinueButton). |
| **Main Menu (focus restored)** | `ui_cancel` (Esc / Gamepad B) from anywhere within the modal | Equivalent to Cancel button press. Non-destructive. Same exit path. |
| **Main Menu (focus restored)** | Mouse click on backdrop (outside modal card) | Equivalent to Cancel button press per `dual-focus-dismiss` pattern. Non-destructive. Same exit path. |

**Irreversibility note**: the Confirm path is **one-way**. Once `LS.transition_to_section(..., NEW_GAME)` is called, the player cannot return to the previous Main Menu state — the next autosave write (LS step 9 on first section entry) destroys the prior slot 0 contents. The modal's Cancel-default-focus is the project's commitment to motor-accessibility safety: a player who accidentally presses Enter on modal mount triggers Cancel, not Confirm.

---

## Layout Specification

### Information Hierarchy

The modal must communicate four pieces of information in a deliberate order:

1. **Most critical** (eye lands here first, within the first 200 ms of modal mount): **Modal identity / what is at stake** — communicated by the PHANTOM Red header band with the stamp label "OPEN NEW OPERATION" rotated -5° in Parchment text. The red band signals "destructive register"; the stamp text identifies the modal scope.
2. **Second**: **What will happen if Confirm is pressed** — the body text "Autosave will be overwritten." in American Typewriter Bold 18 px Ink Black, center-aligned. Single declarative sentence. No technical jargon, no error code, no spinner.
3. **Third**: **The two action choices** — Confirm (Ink Black destructive register, "Begin Operation") and Cancel (BQA Blue safe register, "Cancel"). Default focus on Cancel. Buttons are right-aligned at the card bottom, with 16 px gap and a 1 px ruled divider above.
4. **Discoverable / not visible at rest**: the Main Menu underneath remains visible through the 52% Ink Black backdrop dim — the player can see the broader context (Continue button still showing its slot-0 metadata, the Personnel File button, the Close File button) but cannot interact until the modal is dismissed.

**This hierarchy is intentionally inverted from save-failed-dialog**: where save-failed leads with the cause ("Disk full"), new-game-overwrite leads with the **identity of the action** ("OPEN NEW OPERATION") because the player just initiated the action and needs to confirm scope, not diagnose a failure.

### Layout Zones

The modal card uses a five-zone vertical stack, inheriting the `880 × 200 px` baseline geometry from `quit-confirm.md` Section C.3 [CANONICAL]:

```
┌─────────────────────────────────────────────────────────────┐
│  Z1 — PHANTOM Red header band (50 px tall, full card width) │  ← destructive identity
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Z2 — Body text region (~80 px tall, centered vertically)   │  ← consequence statement
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Z3 — Divider (1 px Ink Black 70%, full card width − 64 px) │  ← visual rest
├─────────────────────────────────────────────────────────────┤
│  Z4 — Button row (~70 px tall, buttons right-aligned)       │  ← player decision
└─────────────────────────────────────────────────────────────┘
                    Z5 — Backdrop (full-screen Ink Black 52% dim, behind card)
```

| Zone | Purpose | Approx Dimensions | Padding |
|---|---|---|---|
| **Z1 — Header band** | PHANTOM Red identity strip with rotated stamp text | `880 × 50 px` | Inside card top edge, full width |
| **Z2 — Body text region** | Single-line declarative sentence about consequence | `880 × ~80 px` (height grows for localized variants — see Localization Considerations) | 32 px H pad inside card edges; vertical center between header and divider |
| **Z3 — Divider** | 1 px Ink Black 70% rule, full card width minus 32 px H pad each side | `816 × 1 px` | Centered horizontally; 8 px above button row |
| **Z4 — Button row** | Two buttons right-aligned with 16 px gap | `880 × ~70 px` | 32 px H pad inside card right edge; 32 px bottom pad |
| **Z5 — Backdrop** | Full-screen Ink Black 52% dim behind modal card | `1920 × 1080 px` (full-screen) | n/a — covers entire viewport |

**Card position on screen**: Centered horizontally and vertically on the viewport at native 1920×1080. At other resolutions, the card maintains its 880×200 px size (no scaling) and remains centered. (The card does NOT grow at higher resolutions; it grows only when localized body text exceeds one line — see Localization Considerations.)

### Component Inventory

| Zone | Component | Type | Properties | Interactive | Pattern Reference |
|---|---|---|---|---|---|
| Z5 | `ModalBackdrop` | `ColorRect` (full-screen) | Ink Black `#1A1A1A` at 52% alpha (matches `desk_overlay_alpha = 0.52` from `menu-system.md` §A.2) | **Yes** — mouse-click-anywhere-on-backdrop dismisses modal with Cancel semantics (`dual-focus-dismiss` pattern) | `modal-scaffold` (backdrop contract) |
| — | `ModalCard` | `PanelContainer` w/ `StyleBoxFlat` | `880 × 200 px` baseline; Parchment `#E8DCC4` fill; 2 px Ink Black `#1A1A1A` hard-edge border; 0 px corner radius; no drop shadow (Pillar 5 refusal) | No (root container) | `modal-scaffold` (card contract) |
| Z1 | `HeaderBand` | `ColorRect` (or `PanelContainer` w/ `StyleBoxFlat`) | PHANTOM Red `#C8102E` fill; full card width × 50 px; no border; 0 px corner radius | No | `save-failed-advisory` (header band color) + `modal-scaffold` (geometry) |
| Z1 | `HeaderStamp` | `Label` | Futura/DIN Bold 24 px Parchment `#E8DCC4`; left-aligned, 16 px left margin within band; vertically centered in band; **rotated -5°** per art-bible §7D Case File register; text = `tr("menu.new_game_confirm.title")` → `OPEN NEW OPERATION` | No (text-only label) | `case-file-stamp-rotation` (inherited from quit-confirm.md C.3) |
| Z2 | `BodyText` | `Label` | American Typewriter Bold 18 px Ink Black `#1A1A1A`; **center-aligned for single-line**, left-aligned for multi-line localized variants ([CANONICAL alignment rule from quit-confirm]); text = `tr("menu.new_game_confirm.body_alt")` → `Autosave will be overwritten.` | No (text-only) | `auto-translate-always` + `accessibility-name-re-resolve` |
| Z3 | `Divider` | `ColorRect` (1 px tall) | Ink Black `#1A1A1A` at 70% alpha; full card width minus 32 px H pad each side (= 816 px wide); centered horizontally; 8 px above button row | No | inherited from quit-confirm.md C.3 |
| Z4 | `ConfirmButton` (destructive) | `Button` w/ `StyleBoxFlat` | **Ink Black `#1A1A1A` fill + Parchment text** per `case-file-destructive-button` pattern; `280 × 56 px` minimum hit target (WCAG SC 2.5.5); DIN 1451 Bold 18 px Parchment `#E8DCC4` text; 0 px corner radius; positioned **left of Cancel** in button row right-anchor; label = `tr("menu.new_game_confirm.confirm")` → `Begin Operation` | **Yes** — `ui_accept` activates destructive path | `case-file-destructive-button` + `modal-scaffold` button contract |
| Z4 | `CancelButton` (safe, default focus) | `Button` w/ `StyleBoxFlat` | **BQA Blue `#1B3A6B` fill + Parchment text** per `modal-scaffold` safe-action contract; `280 × 56 px` minimum hit target; DIN 1451 Bold 18 px Parchment `#E8DCC4` text; 0 px corner radius; positioned **right of Confirm** at card right edge minus 32 px pad; label = `tr("menu.new_game_confirm.cancel")` → `Cancel`; **default focus on mount** with 4 px BQA Blue brightened border on focus | **Yes** — `ui_accept` activates safe path; `ui_cancel` from anywhere also triggers this path | `modal-scaffold` (default-focus-on-safe-action) |

**Component count**: 8 nodes (1 backdrop + 1 card + 2 in header + 1 body + 1 divider + 2 buttons). No icons, no progress indicators, no spinner, no nested layouts. Pillar 5 minimum-chrome.

### ASCII Wireframe

#### Default state (modal mounted, default focus on Cancel)

```
╔═══════════════════════════════════════════════════════════════════════╗
║ █████████████████████████████████████████████████████████████████████ ║  ← Z1: PHANTOM Red header band (50 px)
║ █  OPEN NEW OPERATION  ◆──── (rotated -5° stamp) ────────────────── █ ║     Stamp: DIN Bold 24 px Parchment, rotated -5°
║ █████████████████████████████████████████████████████████████████████ ║
║                                                                       ║
║                                                                       ║
║                  Autosave will be overwritten.                        ║  ← Z2: body text, AT Bold 18 px, center-aligned
║                                                                       ║
║                                                                       ║
║       ─────────────────────────────────────────────────────           ║  ← Z3: 1 px divider, 70% Ink Black
║                                                                       ║
║                              ┌─────────────────┐ ┌──────────────┐    ║  ← Z4: button row, right-anchored
║                              │ Begin Operation │ │   Cancel ⬛   │    ║     Confirm: Ink Black fill, Parchment text
║                              └─────────────────┘ └──────────────┘    ║     Cancel: BQA Blue fill, Parchment text + 4 px border (focused)
║                                                                       ║     16 px gap, 32 px right pad
╚═══════════════════════════════════════════════════════════════════════╝
                                ↑ 880 × 200 px card, centered on viewport
                                ↑ Backdrop: full-screen Ink Black 52% dim
```

#### Focus shifted to Confirm (Tab pressed once from default)

```
╔═══════════════════════════════════════════════════════════════════════╗
║ █████████████████████████████████████████████████████████████████████ ║
║ █  OPEN NEW OPERATION  ◆──── (rotated -5° stamp) ────────────────── █ ║
║ █████████████████████████████████████████████████████████████████████ ║
║                                                                       ║
║                                                                       ║
║                  Autosave will be overwritten.                        ║
║                                                                       ║
║                                                                       ║
║       ─────────────────────────────────────────────────────           ║
║                                                                       ║
║                              ┌═════════════════┐ ┌──────────────┐    ║  ← Confirm: 4 px BQA Blue border = focus indicator
║                              ║ Begin Operation ║ │    Cancel    │    ║     Cancel: no border = unfocused
║                              └═════════════════┘ └──────────────┘    ║     Tab cycle: Cancel → Confirm → Cancel (focus trap)
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
                                ↑ Tab from Cancel cycles to Confirm; Shift+Tab cycles back
                                ↑ Focus never escapes modal (CR-24 strict focus trap)
```

**Wireframe notes**:
- The card outline `╔═╗ ║ ╚═╝` represents the 2 px Ink Black hard-edge border.
- The PHANTOM Red header band is full card width (no inset).
- The stamp text "OPEN NEW OPERATION" is rotated -5° per Case File register inheritance — the `◆` glyph in the wireframe represents the rotation tilt indicator (not literal rendering chrome).
- Buttons are right-anchored: their right edge sits at `card_right − 32 px outer pad`; their left edges are determined by their fixed 280 px width + 16 px gap.
- Default focus on Cancel is indicated by the 4 px BQA Blue brightened border (not a fill change — the underlying BQA Blue fill stays constant; the border thickens/brightens).
- When focus moves to Confirm, the 4 px BQA Blue border applies to Confirm; Cancel's border returns to its unfocused state (1 px border or no border per Theme).

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default** | `ModalScaffold.show_modal(NewGameOverwriteContent)` called from Main Menu after `NewGameButton.pressed` (slot 0 OCCUPIED) OR `ContinueButton.pressed` (slot 0 EMPTY/CORRUPT, label "Begin Operation") | Modal appears at full position (hard cut at MVP — see Transitions); Cancel button has default focus with 4 px BQA Blue brightened border; `accessibility_live = LIVE_ASSERTIVE` one-shot fires; A1 typewriter clack sfx plays on UI bus. |
| **Focus on Confirm** | Tab pressed once from default (or Shift+Tab from Cancel — same result via focus trap) | Confirm button gains 4 px BQA Blue brightened border; Cancel border returns to unfocused state. No sfx. No body or header changes. |
| **Confirm-in-flight** | Confirm button pressed; `LS.transition_to_section(first_section_id, null, NEW_GAME)` is being called this frame | Confirm button `disabled = true` (prevents double-activation per `re-entrant-button-guard` from main-menu.md CR-6 amendment); A1 clack + A6 rubber-stamp thud both fire on the same frame; modal does NOT call `hide_modal()` directly — LS owns the next transition. The modal's parent (Main Menu) is destroyed by LS within 1–2 frames. |
| **Cancel-in-flight** | Cancel button pressed OR `ui_cancel` pressed OR mouse click on backdrop | A1 clack sfx (cancel-feel, no thud); `ModalScaffold.hide_modal()` called; `Context.MODAL` popped; Main Menu button container `process_input = true` restored; focus returned to originating button (NewGameButton or ContinueButton) via `call_deferred("grab_focus")` after `is_instance_valid()` check (per `menu-system.md` Cluster F edge-case L901). |
| **Reduced-motion variant** | `Settings.accessibility.reduced_motion_enabled == true` at `_ready()` | Any appearance tween (header band slide-in, card scale-in) is suppressed; modal appears at full position via hard cut. A1 clack sfx still plays at full duration. The `accessibility_live = LIVE_ASSERTIVE` one-shot still fires. (At MVP, the modal is already hard-cut — this state is identical to default at MVP, but the conditional is wired for future tween additions per CR-23.) |
| **Localized variant — long body text** | Body text exceeds `880 − 64 = 816 px` width at given font size in given locale (e.g., FR/DE expansion of "Autosave will be overwritten.") | Body region grows vertically to accommodate wrapped multi-line text; alignment switches from center to **left** per [CANONICAL alignment rule]. Card height grows from 200 px baseline to whatever is needed (no max — Parchment fill scales with the card). Header band height stays at 50 px; button row stays at 70 px. Card remains centered on viewport. |
| **Slot 0 EMPTY/CORRUPT entry path** | Player activated `ContinueButton` when its label was "Begin Operation" per CR-5 | Modal appearance is identical to OCCUPIED-slot-0 path (same body text, same buttons, same focus). The modal does NOT vary its copy based on entry reason — it states "Autosave will be overwritten." in both cases (even though for CORRUPT slot 0, the autosave is already non-functional). Rationale: the player initiated a destructive action; the modal's job is to confirm intent, not to explain slot 0's exact state (that's the Continue button's slot card's job upstream). |
| **Backdrop fade-in** (post-MVP, currently MVP hard-cut) | If the project later adds a 200 ms backdrop fade-in (per `pause-menu.md` precedent), this state covers the in-flight tween | Backdrop opacity ramps 0 → 52% over 200 ms (linear or ease-out per `motion-curves` table); card appears at full position immediately; button input disabled until backdrop reaches 52%. **Reduced-motion variant suppresses this tween** — backdrop appears at 52% instantly. |
| **Locale-change-triggered re-resolve** | `NOTIFICATION_TRANSLATION_CHANGED` fires while modal is open (e.g., player changed locale via Settings — though Settings is not reachable from this modal, this could happen via a future cheat menu or live-edit) | Header stamp text, body text, both button labels, and AccessKit `accessibility_name` + `accessibility_description` re-resolve via `_update_accessibility_names()` helper (per `accessibility-name-re-resolve` pattern). Card geometry recomputes (body region may grow or shrink). Focus is preserved (no re-focus needed). |

**No "in-progress" indicator state**: there is no spinner, no progress bar, no "saving..." copy. The Confirm button's `disabled = true` is the only in-flight signal, and it is gone by the next frame as LS takes over. (Pillar 5 forbids modern progress chrome.)

**No error state on this modal**: errors during `LS.transition_to_section()` are LS's responsibility, not the modal's. If LS fails to transition, that becomes a save-failed-or-equivalent flow handled by the level streaming GDD's error pathway. The modal itself has no error variant.

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse + Gamepad** (per `technical-preferences.md` §Input & Platform — Primary: Keyboard/Mouse; Gamepad: Partial coverage for menu navigation).

| Player Action | Input — Keyboard | Input — Mouse | Input — Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **Activate default-focused button (Cancel)** | Enter / Space | Click on Cancel button | A button (`ui_accept`) | A1 typewriter clack (60–80 ms, UI bus); button visual press-state (1 frame) | `ModalScaffold.hide_modal()` → pop `Context.MODAL` → Main Menu input restored → focus to originating button. **Non-destructive.** |
| **Cycle focus to Confirm** | Tab | n/a (mouse uses hover, not focus cycle) | D-pad Right OR D-pad Down (focus_neighbor) | 4 px BQA Blue brightened border moves from Cancel to Confirm; A1 typewriter clack at low volume (40–60 ms — focus-shift register, not activation) | Focus indicator on Confirm; Cancel returns to unfocused state. No state change beyond focus. |
| **Cycle focus back to Cancel** | Shift+Tab | n/a | D-pad Left OR D-pad Up | Same as above (border moves back to Cancel) | Focus indicator returns to Cancel; Confirm returns to unfocused state. |
| **Activate Confirm (destructive)** | Enter / Space (when Confirm focused) | Click on "Begin Operation" button | A button (`ui_accept`, when Confirm focused) | A1 typewriter clack + A6 rubber-stamp thud (90–110 ms — destructive register, both on UI bus, fired same frame); Confirm button `disabled = true` for 1 frame to prevent double-activation | `LS.transition_to_section(first_section_id, null, NEW_GAME)` called immediately. Modal does NOT explicitly hide — LS destroys Main Menu (and the modal as its child) within 1–2 frames. **DESTRUCTIVE — IRREVERSIBLE.** |
| **Dismiss with Esc / Cancel** | Escape | Click on backdrop (anywhere outside modal card) | B button (`ui_cancel`) | A1 typewriter clack (cancel-feel, 60–80 ms, UI bus); no thud | Equivalent to Cancel button activation. `ModalScaffold.hide_modal()` → pop `Context.MODAL` → focus to originating button. **Non-destructive.** |
| **Hover Confirm (mouse only)** | n/a | Move mouse over Confirm button | n/a | Hover state: 1 px brightened Ink Black fill (or 5% opacity Parchment overlay); cursor changes to pointer | No state change; pure visual affordance. |
| **Hover Cancel (mouse only)** | n/a | Move mouse over Cancel button | n/a | Hover state: 5% brightened BQA Blue fill; cursor changes to pointer | No state change; pure visual affordance. |
| **Mouse click outside backdrop / off-screen** | n/a | Click outside the backdrop's render rect (not possible at full-screen 1920×1080) | n/a | n/a | Not applicable; backdrop is full-screen. Any click on backdrop is "outside modal card" → Cancel semantics. |

**Focus trap contract** (CR-24 — strict, mandatory):
- Tab from Cancel → cycles to Confirm
- Tab from Confirm → cycles back to Cancel
- Shift+Tab from Cancel → cycles to Confirm
- Shift+Tab from Confirm → cycles back to Cancel
- D-pad Up/Down/Left/Right on gamepad mirror Tab/Shift+Tab cycle behavior via `focus_neighbor_*` properties
- **No Tab/D-pad input can ever reach the underlying Main Menu while the modal is open.** (FP-15 — keyboard trap forbidden outside modals; modals are the exception per CR-24.)

**Input gating during modal open**:
- Main Menu button container: `process_input = false` (set when modal mounted; restored when modal dismissed)
- `Context.MODAL` is at `peek()` of `InputContext` stack; all non-modal input handlers gate on this
- Quicksave (F5) / Quickload (F9): blocked by `Context.MODAL` (no save mid-modal); also irrelevant since Main Menu has no Quicksave hotkey
- Pause toggle (Esc / Start): cannot open Pause Menu while in `Context.MODAL` (Pause requires `Context.GAMEPLAY`); Esc routes to `ui_cancel` → Cancel exit instead

**`set_input_as_handled()` discipline** (per `set-handled-before-pop` pattern): both Confirm and Cancel exit paths MUST call `set_input_as_handled()` BEFORE `InputContext.pop()` to prevent silent-swallow propagation to the Main Menu's `_unhandled_input`. This is a [CANONICAL] rule from `interaction-patterns.md` §`set-handled-before-pop`.

---

## Events Fired

This modal is a **consumer**, not a publisher. It does NOT emit `Events.*` signals. It calls service APIs directly (`LS.transition_to_section`, `ModalScaffold.hide_modal`).

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Modal mounted (entry) | none — modal mount is internal to ModalScaffold | (Modal mount is observable via `ModalScaffold.modal_shown` if the scaffold publishes it; this is not a Menu-level event.) |
| Confirm pressed | `LS.transition_to_section(first_section_id, null, NEW_GAME)` (a method call, not a signal) — and downstream, **LS itself emits** `Events.section_entered(first_section_id, NEW_GAME)` after transition completes (per `main-menu.md` §I L400) | `section_id: StringName`, `reason: TransitionReason.NEW_GAME` (downstream) |
| Cancel pressed | `ModalScaffold.hide_modal()` (a method call, not a signal) | n/a |
| `ui_cancel` pressed (Esc / B) | Same as Cancel pressed | n/a |
| Mouse click on backdrop | Same as Cancel pressed | n/a |
| Tab / Shift+Tab focus cycle | none | n/a — Godot's focus system handles this without a custom event |

**Analytics events** (none at MVP — analytics is post-MVP per `design/gdd/systems-index.md`):

| Player Action | Analytics Event (post-MVP) | Payload |
|---|---|---|
| Confirm pressed | `menu.new_game_confirm.confirmed` | `{ slot_0_state: "OCCUPIED" | "EMPTY" | "CORRUPT", entry_button: "new_game" | "continue_label_swap", elapsed_in_modal_ms: int }` |
| Cancel pressed | `menu.new_game_confirm.cancelled` | `{ slot_0_state: ..., entry_button: ..., cancel_method: "button" | "ui_cancel" | "backdrop_click", elapsed_in_modal_ms: int }` |
| Modal mounted | `menu.new_game_confirm.shown` | `{ slot_0_state: ..., entry_button: ... }` |

**Persistent-state-modifying actions flagged for architecture team**:
- **Confirm path**: triggers an irreversible `LS.transition_to_section(NEW_GAME)`. The downstream effect is that LS will overwrite slot 0 on first section entry (per save-load.md CR-3). This is the only persistent state change initiated by the modal, and it is initiated **indirectly** (the modal does not call `SaveLoad` directly — LS owns the save discipline). **Architecture concern**: ensure that the Confirm button's click handler does not race with Main Menu music fade-out. Per main-menu.md Cluster H L932, the Begin Operation button must be `disabled = true` after first press to prevent re-entrant coroutines. The modal's Confirm button MUST inherit this guard.

**No event for slot 0 metadata read**: the modal does not read slot 0 metadata directly — that read happens upstream in `MainMenu._ready()` for label-swap logic (CR-5). The modal trusts the upstream button's invocation context.

---

## Transitions & Animations

| Phase | Transition | Duration | Easing | Reduced-Motion Variant |
|---|---|---|---|---|
| **Modal enter (appear)** | Hard cut (MVP) — modal appears at full position with backdrop at 52% dim and card fully rendered, on the same frame as `show_modal()` is called | 0 ms (1 frame) | n/a | Identical (already hard cut) |
| **Modal enter (post-MVP candidate)** | Backdrop fade-in 0% → 52% opacity; card slide-up 32 px → 0 px or scale 0.95 → 1.0 | 200 ms | ease-out (`Tween.EASE_OUT, Tween.TRANS_QUAD`) | Suppressed — backdrop snaps to 52%, card snaps to position. CR-23 conditional. |
| **Focus shift (Tab)** | 4 px BQA Blue brightened border slides from one button to the other (or appears/disappears at the destination/origin) | ~80 ms | ease-out | Suppressed — border instantly appears/disappears at the destination/origin. CR-23 conditional. (At MVP, focus shift is already instant — this is wired for future polish.) |
| **Button hover (mouse only)** | Background fill brightens 5% on `mouse_entered`; reverses on `mouse_exited` | ~120 ms | linear | Suppressed — instant brightness change. CR-23 conditional. |
| **Button press (visual)** | Background fill darkens 10% on `button_down`; reverses on `button_up` | 1 frame (instant) | n/a | Identical (already instant) |
| **Confirm-in-flight** | Confirm button `disabled = true` for 1 frame; visual state shifts to `disabled` style (50% opacity per Theme); LS takes over within 1–2 frames | ~16–32 ms | n/a | Identical |
| **Modal exit (Cancel path)** | Hard cut (MVP) — modal hides on the same frame as `hide_modal()` is called; backdrop and card vanish; focus returns to originating button on next frame via `call_deferred("grab_focus")` | 0–16 ms (1–2 frames) | n/a | Identical (already hard cut) |
| **Modal exit (post-MVP candidate)** | Backdrop fade-out 52% → 0%; card slide-down 0 → 32 px or scale 1.0 → 0.95 | 200 ms | ease-in (`Tween.EASE_IN, Tween.TRANS_QUAD`) | Suppressed — backdrop snaps to 0%, card snaps away. CR-23 conditional. |
| **Modal exit (Confirm path)** | Modal does NOT explicitly exit — LS destroys Main Menu (modal's parent) within 1–2 frames; the modal vanishes with its parent | ~16–32 ms (LS's pace) | n/a (LS owns) | n/a — LS controls subsequent transition (e.g., its 2-frame hard cut between sections per Failure & Respawn ruling 2026-04-21) |

**Photosensitivity audit** (per `design/accessibility-requirements.md` and Cutscenes audit):
- No flashing — all transitions are monotonic opacity ramps or instant state changes
- No color-rapid-change — PHANTOM Red header band appears at full opacity, does not pulse, flicker, or strobe
- No high-contrast strobe — backdrop dim is a single 52% value, no oscillation
- All transitions safe for photosensitivity tier per WCAG SC 2.3.1 (≤3 flashes per second)

**Motion-sickness audit**:
- No camera motion (this is a 2D UI overlay)
- No parallax shift
- No high-velocity slide-ins (max 200 ms slide is post-MVP polish, well under fatigue thresholds)
- Reduced-motion variant suppresses all tweens; suitable for vestibular-sensitivity players

**Audio-paired transitions** (locked per menu-system.md §A.1–A.2):
- A1 typewriter clack — fires on modal mount AND on every button press (60–80 ms, UI bus)
- A6 rubber-stamp thud — fires on Confirm press only (90–110 ms, UI bus; destructive register)
- No audio for focus shift at MVP (post-MVP candidate: A1 clack at lower volume for tab cycle)

**No animation owns the destructive moment**: the irreversible action (Confirm pressed) is communicated by audio (A6 thud) + visual (button press-state + disabled flash) + the immediate transition to LS. There is no "Are you sure???" delay tween or hold-to-confirm gesture. The friction is the modal itself, not animation.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| `slot_0_state` (OCCUPIED / EMPTY / CORRUPT) | `SaveLoad.slot_metadata(0)` (read upstream by Main Menu, NOT by this modal) | **Indirect read** (the modal trusts the upstream button's invocation context) | Modal does not call SaveLoad. Upstream `MainMenu._ready()` reads slot 0 to determine ContinueButton label-swap (CR-5); the modal is invoked only after this read. |
| `first_section_id` (StringName, e.g., `&"plaza"`) | Hardcoded in Main Menu code or read from a level-design config Resource | **Read** (passed to `LS.transition_to_section()` on Confirm) | **Open Question #2**: Is this hardcoded in Menu code, or does it come from a config Resource (e.g., `res://campaign_config.tres`)? Architecture decision needed. |
| `tr("menu.new_game_confirm.title")` → `OPEN NEW OPERATION` | `translations/menu.csv` via Godot's `tr()` function | **Read** (resolved at `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED`) | Already in string table per menu-system.md §C.8 |
| `tr("menu.new_game_confirm.body_alt")` → `Autosave will be overwritten.` | `translations/menu.csv` | **Read** | Already in string table; flagged "over" L212 cap (28 chars vs 25 char cap) — coord with localization-lead |
| `tr("menu.new_game_confirm.confirm")` → `Begin Operation` | `translations/menu.csv` | **Read** | Already in string table |
| `tr("menu.new_game_confirm.cancel")` → `Cancel` | `translations/menu.csv` | **Read** | Already in string table |
| `tr("menu.new_game_confirm.confirm.desc")` → AccessKit description for Confirm button | `translations/menu.csv` | **Read** (resolved on `NOTIFICATION_TRANSLATION_CHANGED`) | **NEW STRING** — this spec adds it. Suggested English: "Begin a new operation. The autosave will be overwritten and cannot be recovered." |
| `tr("menu.new_game_confirm.cancel.desc")` → AccessKit description for Cancel button | `translations/menu.csv` | **Read** | **NEW STRING** — this spec adds it. Suggested English: "Return to the main menu. The autosave is preserved." |
| `Settings.accessibility.reduced_motion_enabled` | `SettingsService` autoload (per ADR-0007 canonical registration) | **Read** (resolved at modal `_ready()`; not re-read on settings change while modal is open) | Suppresses appearance tweens (currently no-op at MVP since modal is hard-cut) |
| `Theme.modal_scaffold` (StyleBoxFlat colors, font sizes, button styles) | Project-wide Theme resource (per ADR-0004 IG6) | **Read** | Inherited from ModalScaffold; modal does not author Theme overrides |
| `originating_button: Control` (NewGameButton or ContinueButton reference) | Passed in by Main Menu when calling `ModalScaffold.show_modal()` | **Read + Write** (write = the reference is stored for `return_focus_node` on hide) | Per `menu-system.md` Cluster F edge-case L901, modal MUST validate `is_instance_valid(originating_button)` before `call_deferred("grab_focus")` on dismiss |

**Architectural concerns flagged**:
- The modal does not own any persistent state of its own. All persistent state changes initiated by Confirm flow through LS → SaveLoad. The modal's data flow is **strictly read-only with one method call (`LS.transition_to_section`) on Confirm**.
- No autoload registration needed for the modal — it is a `ModalScaffold` content node, not a long-lived singleton.
- The 2 NEW localization strings (Confirm/Cancel `accessibility_description`) need to be added to `translations/menu.csv` before this modal can ship — coord with localization-lead.

**No real-time data**: the modal does not display playtime, slot timestamps, or any real-time-updating values. The body copy is static at "Autosave will be overwritten." regardless of slot 0 contents.

---

## Accessibility

**Committed tier**: **Standard** (per `design/accessibility-requirements.md`).

The modal inherits all accessibility commitments from `modal-scaffold` and `case-file-destructive-button` patterns. The contract below is the consolidated checklist for QA verification.

### Keyboard-only navigation path

| Step | Action | Expected Result |
|---|---|---|
| 1 | Modal mounts | Focus moves to Cancel button (default focus per `modal-scaffold` safe-action contract) |
| 2 | Tab | Focus moves to Confirm button (focus trap cycles within modal) |
| 3 | Tab again | Focus cycles back to Cancel (no escape from modal) |
| 4 | Shift+Tab | Focus moves backwards through cycle (Cancel → Confirm → Cancel) |
| 5 | Enter / Space (on Cancel) | Activates Cancel; modal dismisses; focus returns to originating button on Main Menu |
| 6 | Enter / Space (on Confirm) | Activates Confirm; LS transitions; Main Menu destroyed (modal vanishes with parent) |
| 7 | Escape (from anywhere within modal) | Activates Cancel-equivalent path; modal dismisses; focus returns to originating button |

### Gamepad navigation order (Partial coverage per technical-preferences.md)

| Input | Action | Expected Result |
|---|---|---|
| **A button (`ui_accept`)** on Cancel | Activate Cancel | Same as keyboard Enter on Cancel |
| **A button (`ui_accept`)** on Confirm | Activate Confirm | Same as keyboard Enter on Confirm |
| **B button (`ui_cancel`)** | Dismiss modal | Same as keyboard Escape — Cancel-equivalent path |
| **D-pad Right / Down** | Cycle focus to Confirm | Same as keyboard Tab |
| **D-pad Left / Up** | Cycle focus back to Cancel | Same as keyboard Shift+Tab |
| **Analog stick** | NOT USED for focus cycle (per project gamepad convention — d-pad only for menu navigation) | n/a |
| **Start / Select** | NOT USED in modal context | n/a — Pause cannot open from `Context.MODAL` |

### Text contrast and minimum readable font sizes

| Element | Foreground | Background | Contrast Ratio | WCAG AA / AAA | Font Size |
|---|---|---|---|---|---|
| Header stamp ("OPEN NEW OPERATION") | Parchment `#E8DCC4` | PHANTOM Red `#C8102E` | ~5.4:1 | AA Pass (≥4.5:1 for large text) | DIN Bold 24 px |
| Body text ("Autosave will be overwritten.") | Ink Black `#1A1A1A` | Parchment `#E8DCC4` | ~14.2:1 | AAA Pass (≥7:1) | American Typewriter Bold 18 px |
| Confirm button label ("Begin Operation") | Parchment `#E8DCC4` | Ink Black `#1A1A1A` | ~14.2:1 | AAA Pass | DIN Bold 18 px |
| Cancel button label ("Cancel") | Parchment `#E8DCC4` | BQA Blue `#1B3A6B` | ~10.8:1 | AAA Pass | DIN Bold 18 px |
| Focus indicator border (4 px brightened BQA Blue) | n/a | Card Parchment `#E8DCC4` | ≥3:1 (focus indicator non-text contrast per WCAG SC 1.4.11) | AA Pass | n/a |

**All ratios meet WCAG AA (4.5:1) at minimum; most meet AAA (7:1).** No text element relies on contrast below AA threshold.

### Color-independent communication

The modal communicates destructive-vs-safe action through **4 redundant signals** (`case-file-destructive-button` pattern):

1. **Color**: PHANTOM Red header band (destructive register) + Ink Black Confirm button + BQA Blue Cancel button
2. **Position**: Confirm is left of Cancel (LTR locales); Cancel is right (default focus, safe-action position)
3. **Label text**: "Begin Operation" (action verb implies finality) + "Cancel" (universally understood safe action)
4. **Focus indicator**: 4 px BQA Blue brightened border on focused button (initially Cancel)

A color-blind player (deuteranopia, protanopia, tritanopia, or full achromatopsia) can identify the destructive button via position + label + focus state alone — no information is conveyed by color alone. **WCAG SC 1.4.1 Pass** (color-independence).

### Screen reader support

The modal complies with the AccessKit contract per ADR-0004 IG10 [CANONICAL]:

| Node | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| ModalCard root | `ROLE_DIALOG` | `tr("menu.new_game_confirm.title")` → "OPEN NEW OPERATION" | (empty — name suffices) | `LIVE_ASSERTIVE` (one-shot on mount, cleared to `LIVE_OFF` next frame via `call_deferred`) per CR-21 |
| HeaderStamp Label | `ROLE_STATIC_TEXT` (or default) | (empty — covered by ModalCard's name) | (empty) | `LIVE_OFF` |
| BodyText Label | `ROLE_STATIC_TEXT` (or default) | `tr("menu.new_game_confirm.body_alt")` → "Autosave will be overwritten." | (empty) | `LIVE_OFF` |
| Divider ColorRect | n/a (decorative) | (none) | (none) | n/a |
| ConfirmButton | `ROLE_BUTTON` | `tr("menu.new_game_confirm.confirm")` → "Begin Operation" | `tr("menu.new_game_confirm.confirm.desc")` → "Begin a new operation. The autosave will be overwritten and cannot be recovered." (NEW STRING) | `LIVE_OFF` |
| CancelButton | `ROLE_BUTTON` | `tr("menu.new_game_confirm.cancel")` → "Cancel" | `tr("menu.new_game_confirm.cancel.desc")` → "Return to the main menu. The autosave is preserved." (NEW STRING) | `LIVE_OFF` |
| ModalBackdrop ColorRect | n/a (decorative) | (none) | (none) | n/a |

**Assertive announce on mount**: when modal mounts, the screen reader announces (in scripted order): "Dialog. OPEN NEW OPERATION. Autosave will be overwritten. Cancel button. Return to the main menu. The autosave is preserved." (or locale-equivalent). The one-shot LIVE_ASSERTIVE is cleared to LIVE_OFF on the next frame via `call_deferred("set", "accessibility_live", AccessibilityLive.LIVE_OFF)` to prevent re-announcement on subsequent state changes within the same modal session.

**Locale-change re-resolve**: on `NOTIFICATION_TRANSLATION_CHANGED`, all `accessibility_name` and `accessibility_description` strings are re-resolved via `_update_accessibility_names()` helper (per `accessibility-name-re-resolve` pattern). Focus is preserved; no re-announcement fires (LIVE_OFF post-mount).

### Motion and animation

**At MVP**: modal appears via hard cut. No tweens. Reduced-motion variant is identical to default.

**Post-MVP polish candidates** (200 ms backdrop fade-in, focus-shift border slide, hover-fill ramp): all suppressed when `Settings.accessibility.reduced_motion_enabled == true` per CR-23. No animation conveys information that is not redundantly available via static state.

### Photosensitivity

- No flashing colors
- No high-contrast strobe
- No flicker
- No rapid color changes
- All state changes are monotonic opacity ramps (post-MVP) or instant cuts (MVP)
- WCAG SC 2.3.1 Pass (≤3 flashes per second — modal exhibits 0)

### Cognitive accessibility

- Body copy is **plain language**: "Autosave will be overwritten." — declarative, no jargon, no error code
- AccessKit `accessibility_description` for both buttons provides plain-language clarification of the action and consequence (mandatory per `case-file-destructive-button` rule 6: "the description is mandatory because Case File register button labels are bureaucratic-register and AT users benefit from the plain-language safety net")
- Default focus on Cancel (safe action) prevents accidental destructive activation
- Single-press activation — no hold-to-confirm gesture or timed input
- No time pressure — modal stays open indefinitely until player decides
- No multi-step flow within the modal — one decision, two buttons, done

### Motor accessibility

- All hit targets ≥ 280 × 56 px (WCAG SC 2.5.5 — 44×44 minimum, project commits 280×56 for menu buttons)
- 16 px gap between Confirm and Cancel reduces mis-click risk
- Single-press activation (no chording, no hold)
- No time-limited input (no countdown, no auto-dismiss)
- Backdrop click is a generous Cancel target (full-screen except modal card area = ~1.7 million px²)

### Open accessibility questions

- See **Open Questions** section §13 for unresolved items relating to localization length cap, reduced-motion conditional scope, and stamp rotation overflow.

---

## Localization Considerations

### String table (already in `translations/menu.csv` per menu-system.md §C.8)

| String Key | English | Char Count | Estimated FR/DE Expansion (40%) | L212 Cap (25 chars) | Status |
|---|---|---|---|---|---|
| `menu.new_game_confirm.title` | OPEN NEW OPERATION | 18 | ~25–30 chars | ≤ 21 | ⚠ Likely fits FR/DE; tight margin |
| `menu.new_game_confirm.body_alt` | Autosave will be overwritten. | 28 (over) | ~39–45 chars | ≤ 25 | ❌ Over cap — see Open Question #6 |
| `menu.new_game_confirm.confirm` | Begin Operation | 15 | ~21–25 chars | ≤ 21 | ✓ Likely fits |
| `menu.new_game_confirm.cancel` | Cancel | 6 | ~9–12 chars | ≤ 21 | ✓ Comfortably fits |

### NEW strings to add (this spec adds these to the string table)

| String Key | English | Notes |
|---|---|---|
| `menu.new_game_confirm.confirm.desc` | Begin a new operation. The autosave will be overwritten and cannot be recovered. | AccessKit `accessibility_description` for Confirm button. Plain-language clarification of the destructive action. ~78 chars; FR/DE expansion likely ~110 chars. No layout impact (description is screen-reader-only, not rendered visually). |
| `menu.new_game_confirm.cancel.desc` | Return to the main menu. The autosave is preserved. | AccessKit `accessibility_description` for Cancel button. ~52 chars; FR/DE expansion likely ~73 chars. No layout impact. |

### Layout-critical text constraints

| Element | Width Budget | Behavior on overflow |
|---|---|---|
| **Header stamp** ("OPEN NEW OPERATION" rotated -5°) | ~700 px effective width within 880 px header band (after rotation footprint) | If localized stamp text exceeds this width: **fall back to a smaller font size (DIN Bold 20 px)** rather than truncate. Stamp must remain readable per Pillar 5 dossier register. Coord with art-director if FR/DE locale exceeds this — see Open Question #5. |
| **Body text** ("Autosave will be overwritten.") | ~816 px (card width − 32 px H pad each side) | If localized body exceeds 816 px on a single line: **wrap to 2 lines, switch alignment from center to left** per [CANONICAL alignment rule from quit-confirm.md]. Card height grows to accommodate. No truncation. |
| **Confirm button label** ("Begin Operation") | 280 px button width (− 16 px H padding each side = 248 px text width) | If localized label exceeds 248 px: **wrap to 2 lines or use abbreviation per locale-specific override**. Button height grows. **HIGH PRIORITY** for localization-lead — coord during string review. |
| **Cancel button label** ("Cancel") | 280 px button width | Cancel is short in most locales; no expected overflow. |

### Numbers, dates, currencies

None on this modal — body copy is static text only.

### Bidirectional (RTL) support

Not committed at MVP per `design/accessibility-requirements.md`. Post-MVP RTL support would mirror button order (Cancel left, Confirm right) per `modal-scaffold` rule 4. Header band would not mirror (full-width band; stamp rotation -5° would mirror to +5°).

### Coordinate with localization-lead

**HIGH PRIORITY items**:
1. **L212 body cap** (28 chars vs 25 char cap) — see Open Question #6. Decision needed before sprint kickoff: shorten English source ("Autosave overwritten.") OR raise the cap.
2. **Stamp rotation overflow** for FR/DE long-form translations — see Open Question #5. Decision needed: fixed-width stamp OR locale-specific abbreviation OR auto-shrink font.
3. **2 NEW AccessKit description strings** must be added to `translations/menu.csv` before sprint kickoff.

---

## Acceptance Criteria

The following criteria are testable by a QA tester without reading any other design document. They form the pass/fail gates for `/story-done`. Each criterion is tagged with story type per `.claude/docs/coding-standards.md` Testing Standards table.

- **AC-NGOM-1.1 [Logic] [BLOCKING]** GIVEN slot 0 is OCCUPIED with valid metadata AND Main Menu is interactive, WHEN player activates `NewGameButton`, THEN `ModalScaffold.show_modal(NewGameOverwriteContent)` is called within 1 frame, the modal title resolves to `"OPEN NEW OPERATION"` (en-US), default focus lands on the Cancel button, and `peek() == Context.MODAL`.

- **AC-NGOM-1.2 [Logic] [BLOCKING]** GIVEN slot 0 is EMPTY (`slot_metadata(0) == null` OR `state == EMPTY`) AND ContinueButton's label has swapped to "Begin Operation" (CR-5), WHEN player activates the ContinueButton, THEN the same `ModalScaffold.show_modal(NewGameOverwriteContent)` is called and the modal renders identically to AC-NGOM-1.1 (same title, same body copy, same default focus). Verifies CR-5 destructive guard.

- **AC-NGOM-1.3 [Logic] [BLOCKING]** GIVEN slot 0 is CORRUPT (`state == CORRUPT`) AND ContinueButton's label has swapped to "Begin Operation" (CR-5), WHEN player activates the ContinueButton, THEN the same modal opens with the same body copy `"Autosave will be overwritten."` (modal does NOT vary copy based on entry reason). Verifies CR-5 corrupt-slot fall-through.

- **AC-NGOM-2.1 [Integration] [BLOCKING]** GIVEN modal is open with default focus on Cancel, WHEN player presses Tab once, THEN focus moves to Confirm button and the 4 px BQA Blue brightened border renders on Confirm (not Cancel). WHEN player presses Tab again, focus cycles back to Cancel. Verifies CR-24 strict focus trap.

- **AC-NGOM-2.2 [Integration] [BLOCKING]** GIVEN modal is open, WHEN player presses any combination of Tab + Shift+Tab + D-pad in any sequence, THEN focus NEVER reaches the underlying Main Menu's buttons. Verifies CR-24 + FP-15 (focus trap is the only allowed exception to "no keyboard traps outside modals").

- **AC-NGOM-3.1 [Logic] [BLOCKING]** GIVEN modal is open with default focus on Cancel, WHEN player presses Enter / Space, THEN: (a) A1 typewriter clack sfx fires on UI bus; (b) `ModalScaffold.hide_modal()` is called; (c) `Context.MODAL` is popped (`peek() == Context.MENU`); (d) Main Menu button container has `process_input = true`; (e) focus returns to the originating button (NewGameButton or ContinueButton) within 1 frame. All five within 2 frames of the press. Verifies modal-scaffold dismiss contract.

- **AC-NGOM-3.2 [Logic] [BLOCKING]** GIVEN modal is open with default focus on Cancel, WHEN player presses Escape (`ui_cancel`), THEN the same exit path as AC-NGOM-3.1 fires (Cancel-equivalent semantics). Verifies `dual-focus-dismiss` pattern.

- **AC-NGOM-3.3 [UI] [ADVISORY]** GIVEN modal is open, WHEN player clicks anywhere on the backdrop (outside the 880×200 card), THEN the same Cancel-equivalent exit path fires. Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-NGOM-4.1 [Logic] [BLOCKING]** GIVEN modal is open with focus on Confirm, WHEN player presses Enter / Space, THEN: (a) A1 typewriter clack + A6 rubber-stamp thud both fire on UI bus on the same frame; (b) Confirm button enters `disabled = true` state for at least 1 frame; (c) `LS.transition_to_section(first_section_id, null, NEW_GAME)` is called within 1 frame of the press (no `await`); (d) Main Menu (and modal as its child) is destroyed by LS within 5 frames. Verifies CR-6 confirm path + re-entrant-coroutine guard.

- **AC-NGOM-4.2 [Logic] [BLOCKING]** GIVEN Confirm button is in `disabled = true` state (post-press), WHEN player presses Enter or clicks Confirm again, THEN no second `LS.transition_to_section()` call fires (re-entrant guard). Verifies main-menu.md Cluster H L932 amendment inheritance.

- **AC-NGOM-5.1 [UI] [BLOCKING]** GIVEN modal mounts with screen reader active (e.g., NVDA, JAWS, Orca), WHEN modal appears, THEN screen reader announces (en-US): "Dialog. OPEN NEW OPERATION. Autosave will be overwritten. Cancel button. Return to the main menu. The autosave is preserved." within 500 ms of mount. Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-NGOM-5.2 [UI] [BLOCKING]** GIVEN modal is open with screen reader active and focus on Confirm, WHEN focus lands on Confirm, THEN screen reader announces "Begin Operation, button. Begin a new operation. The autosave will be overwritten and cannot be recovered." Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-NGOM-5.3 [Logic] [BLOCKING]** GIVEN modal mounted with `accessibility_live = LIVE_ASSERTIVE`, WHEN one frame has elapsed, THEN `accessibility_live == LIVE_OFF` (one-shot cleared via `call_deferred`). Verifies CR-21 one-shot assertive contract.

- **AC-NGOM-6.1 [Visual] [ADVISORY]** GIVEN modal is rendered at 1920×1080 with English locale, WHEN inspected by eye, THEN: (a) PHANTOM Red header band fills full card width × 50 px; (b) "OPEN NEW OPERATION" stamp text is rotated -5° in DIN Bold 24 px Parchment, left-anchored at 16 px from card left edge; (c) body text "Autosave will be overwritten." is center-aligned in American Typewriter Bold 18 px Ink Black; (d) divider is 1 px Ink Black 70%, 816 px wide, centered; (e) Confirm and Cancel buttons are right-anchored with 16 px gap, 32 px right pad. Screenshot evidence filed at `production/qa/evidence/`.

- **AC-NGOM-6.2 [Visual] [ADVISORY]** GIVEN modal is rendered with FR locale (longest expected expansion), WHEN inspected, THEN: (a) header stamp does not overflow the band (or falls back to DIN Bold 20 px gracefully per Open Question #5 resolution); (b) body text wraps to at most 2 lines, alignment switches from center to left; (c) button labels do not overflow their 280 px width buttons; (d) card height grows to accommodate (no clipping). Screenshot evidence filed at `production/qa/evidence/`.

- **AC-NGOM-7.1 [Integration] [BLOCKING]** GIVEN `Settings.accessibility.reduced_motion_enabled == true`, WHEN modal mounts and dismisses, THEN: (a) no appearance tween plays; (b) no focus-shift tween plays; (c) no hover tween plays; (d) audio cues (A1 clack, A6 thud) all play at full duration. Verifies CR-23 reduced-motion conditional.

- **AC-NGOM-8.1 [Logic] [BLOCKING]** GIVEN locale change occurs (`NOTIFICATION_TRANSLATION_CHANGED` fires) while modal is open, WHEN one frame passes, THEN: (a) HeaderStamp Label text re-resolves to new locale's `menu.new_game_confirm.title`; (b) BodyText Label re-resolves; (c) both button labels re-resolve; (d) ConfirmButton.accessibility_name + ConfirmButton.accessibility_description re-resolve; (e) CancelButton.accessibility_name + CancelButton.accessibility_description re-resolve; (f) focus is preserved on whichever button held focus. Verifies `accessibility-name-re-resolve` pattern compliance.

- **AC-NGOM-9.1 [Performance] [ADVISORY]** GIVEN modal mount is requested, WHEN measured from `show_modal()` call to first frame fully rendered, THEN ≤ 33 ms (2 frames at 60 fps). Smoke check.

- **AC-NGOM-10.1 [Config] [ADVISORY]** GIVEN `translations/menu.csv` on disk, WHEN inspected, THEN every English value for `menu.new_game_confirm.*` matches §C.8 string table exactly, AND the 2 NEW description strings (`menu.new_game_confirm.confirm.desc` + `menu.new_game_confirm.cancel.desc`) are present. Smoke check via `diff` against §C.8 + this spec.

**Minimum 5 criteria categories satisfied**:
- ✓ Performance criterion: AC-NGOM-9.1
- ✓ Navigation criterion: AC-NGOM-3.1, AC-NGOM-4.1
- ✓ Error/empty/edge state criterion: AC-NGOM-1.2, AC-NGOM-1.3 (slot 0 EMPTY/CORRUPT paths)
- ✓ Accessibility criterion: AC-NGOM-2.1, AC-NGOM-5.1, AC-NGOM-5.2, AC-NGOM-7.1
- ✓ Core-purpose criterion: AC-NGOM-4.1 (the destructive Confirm path is the modal's reason for existing)

**Total**: 18 acceptance criteria across 5 story types (Logic: 10 BLOCKING; Integration: 4 BLOCKING; UI: 3 mixed; Visual: 2 ADVISORY; Performance: 1 ADVISORY; Config: 1 ADVISORY).

---

## Open Questions

| # | Question | Affects Section | Owner | Recommendation | Resolution Deadline |
|---|---|---|---|---|---|
| **OQ-NGOM-1** | **NewGameButton visibility when slot 0 is EMPTY/CORRUPT.** When ContinueButton has label-swapped to "Begin Operation" (CR-5), does the secondary "New Game" button (label "Open New Operation") **hide** (so "Begin Operation" is the sole start-fresh path), or **remain visible** as a redundant entry? This is `main-menu.md` Open Question #1 — recommendation pending; this modal must support whichever resolution is chosen. | Entry & Exit Points (table); States & Variants | game-designer + ux-designer (joint with main-menu.md OQ #1) | **Defer to main-menu.md OQ #1 resolution.** Modal supports both paths identically — the entry source does not affect modal copy or behavior. | Before MVP sprint kickoff |
| **OQ-NGOM-2** | **`first_section_id` source.** The modal's Confirm path calls `LS.transition_to_section(first_section_id, null, NEW_GAME)`. Is `first_section_id` hardcoded in Menu code (e.g., `&"plaza"` for The Paris Affair Act 1), or does it come from a level-design config Resource (e.g., `res://config/campaign.tres`)? Architecture decision needed for engine-programmer hand-off. | Data Requirements (table); Events Fired | technical-director + game-designer | **Recommended: read from a level-design config Resource** (e.g., `CampaignConfig.first_section_id`) to keep level-design data-driven (per coding-standards.md "gameplay values must be data-driven"). Hardcoded `&"plaza"` is acceptable as an interim if the campaign config doesn't exist yet, but flag as tech debt. | Before sprint kickoff |
| **OQ-NGOM-3** | **Background input gating during modal open.** Can a Quicksave (F5) or Pause Menu File Dispatch save fire while new-game-overwrite modal is open? The expected answer is NO (because `Context.MODAL` blocks input, and Pause cannot open from `Context.MENU`/`Context.MODAL`), but verify the input-gating chain end-to-end. Specifically: confirm that `MainMenu.NewGameButton.pressed` does NOT happen to also trigger any background `Events.save_requested` listener. | Interaction Map (input gating); States & Variants | engine-programmer + ui-programmer | **Recommended: NO background saves during modal.** Confirm via grep gate: search for any `Events.save_requested` emit-points that don't gate on `peek() in [GAMEPLAY, PAUSE]`. | Before sprint kickoff |
| **OQ-NGOM-4** | **Reduced-motion conditional scope at MVP.** CR-23 wraps "paper-movement tweens" in the conditional. At MVP, the modal is hard-cut, so the conditional is effectively a no-op. Is the conditional **wired but no-op at MVP** (so post-MVP polish tweens can be added without touching the conditional path), or **omitted entirely at MVP** (with a TODO to add the conditional when tweens are introduced)? | Transitions & Animations (Reduced-Motion column); Accessibility | ux-designer + lead-programmer | **Recommended: WIRED but no-op at MVP** — the conditional should exist as `if not Settings.accessibility.reduced_motion_enabled: ...` even though the body is a no-op at MVP. This avoids a regression risk when polish tweens are added post-MVP. | Defer to lead-programmer style guide |
| **OQ-NGOM-5** | **Stamp rotation overflow for long localized titles.** "OPEN NEW OPERATION" is 18 chars; FR/DE expansion may produce 25–30 chars. The -5° rotation reduces effective horizontal space within the band. Should the implementation: (a) fall back to a smaller font size (DIN Bold 20 px) if overflow detected, (b) use a fixed-width stamp area with truncation/ellipsis (NOT acceptable per Pillar 5), or (c) require localization-lead to provide a per-locale shorter version? | Layout Specification (HeaderStamp); Localization Considerations | art-director + localization-lead | **Recommended: (a) auto-shrink to 20 px on overflow** — this matches the menu-system.md L207 stamp-fallback pattern (if it exists; otherwise propose). Truncation is a Pillar 5 refusal. | During localization review |
| **OQ-NGOM-6** | **L212 body-text cap (25-char) scope.** menu-system.md OQ-MENU-25 flags that `menu.new_game_confirm.body_alt` (28 chars) exceeds the L212 25-char cap. Is the cap applied to **labels only** (body text exempt), or **all visible strings**? If the cap applies to body, the English source must be shortened (proposed: "Autosave overwritten." at 21 chars) OR the cap raised. | Localization Considerations (string table); Acceptance Criteria | localization-lead (cap scope clarification owner) | **Defer to localization-lead L212 clarification.** Modal supports either resolution — a shorter English source ("Autosave overwritten.") would also fit; the longer version ("Autosave will be overwritten.") is preferred for clarity but accepts shortening. | Before localization GDD finalization |

**No CRITICAL blockers** at the time of this spec — all open questions are scoped to localization timing, level-design config source, or polish-phase animation wiring. The modal's core canonical decisions (PHANTOM Red header + Case File destructive button + modal-scaffold focus contract + 880×200 baseline + Cancel-default-focus + accessibility tier) are all locked per [CANONICAL] inheritance from `quit-confirm.md` + `interaction-patterns.md` + `menu-system.md` §C.8.

---

## Cross-Reference Summary

**Files this spec depends on** (must remain consistent with these):

- `design/ux/quit-confirm.md` Section C.3 — CANONICAL modal-scaffold reference; this spec inherits scaffold + button contract verbatim
- `design/ux/main-menu.md` §I (Events Fired), §C (Information Hierarchy), §B3 (Entry & Exit Points), CR-5 / CR-6 invocations
- `design/ux/interaction-patterns.md` `modal-scaffold`, `case-file-destructive-button`, `dual-focus-dismiss`, `set-handled-before-pop`, `accessibility-name-re-resolve`, `auto-translate-always`
- `design/gdd/menu-system.md` CR-2 (InputContext push/pop), CR-5 (Continue label-swap), CR-6 (New Game flow), CR-21 (one-shot assertive), CR-23 (reduced-motion conditional), CR-24 (modal focus trap), §C.8 (string table), §A.1–A.2 (audio cues)
- `design/gdd/save-load.md` slot 0 schema, autosave-on-section-entry semantics (CR-1, CR-3), 8-slot total
- `design/gdd/level-streaming.md` `transition_to_section()` API contract
- `design/art/art-bible.md` §3.3 (palette), §4 (Parchment fills), §7B (typography), §7D (Case File register stamp rotation)
- `design/accessibility-requirements.md` Standard tier commitment
- `docs/architecture/ADR-0004-ui-framework.md` IG6 (Theme), IG7 (CanvasLayer 1024 modals), IG10 (AccessKit Day-1)
- `docs/architecture/ADR-0007-autoload-registry.md` (Settings autoload position)

**Files that should later cross-link to this spec**:
- `design/ux/main-menu.md` — should add a "see `new-game-overwrite.md`" link in §I (Events Fired) and §B3 (Entry & Exit) where CR-5/CR-6 modal paths are described. **Action: edit on /ux-review approval.**
- `design/gdd/menu-system.md` CR-5 + CR-6 — should add a "UX spec: `design/ux/new-game-overwrite.md`" cross-reference. **Action: edit on /ux-review approval.**
- `design/gdd/save-load.md` §UI Requirements — should cite new-game-overwrite as a consumer of slot 0 metadata semantics. **Action: edit on /ux-review approval.**
- `design/ux/interaction-patterns.md` — `modal-scaffold` and `case-file-destructive-button` "Used In" lists already include "New-Game-Overwrite"; verify on /ux-review.
- `design/gdd/level-streaming.md` — verify that `transition_to_section()` API signature matches the modal's call site.

---

## Verdict

**COMPLETE** — UX spec written and section-by-section content authored per `quit-confirm.md` [CANONICAL] sibling inheritance + menu-system.md §C.8 string table + `case-file-destructive-button` pattern + `modal-scaffold` pattern. Spec is ready for `/ux-review`.

---

## Recommended Next Steps

1. **Run `/ux-review new-game-overwrite`** — validate this spec before it enters the implementation pipeline. The Pre-Production gate requires all key screen specs to have a review verdict.
2. **Resolve OQ-NGOM-1, OQ-NGOM-2, OQ-NGOM-6** before sprint kickoff (these have hard blockers).
3. **Add 2 NEW localization strings** to `translations/menu.csv`: `menu.new_game_confirm.confirm.desc` + `menu.new_game_confirm.cancel.desc`. Coord with localization-lead.
4. **Cross-link** main-menu.md, menu-system.md, and save-load.md to this spec on /ux-review approval.
5. **`/gate-check pre-production`** once all 5 modal-scaffold sibling specs are reviewed (quit-confirm DONE, save-failed-dialog DONE, return-to-registry pending, re-brief-operation pending, new-game-overwrite NOW DRAFTED — pending review).
