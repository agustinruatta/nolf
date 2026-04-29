# UX Spec: Return-to-Registry Confirm Modal

> **Status**: In Design
> **Author**: ux-designer + user
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: P3 In-Mission → P3.5 Mission-Pause (player has paused mid-mission and is considering exit) → on Confirm: P1 Main Menu (returning-player branch); on Cancel: P3.5 Mission-Pause restored
> **Template**: UX Spec
> **Sprint Scope**: **[VS]** (Vertical Slice — NOT MVP per menu-system.md CR-14). Pause Menu and its full button stack ship at VS, alongside this confirm modal.
> **Register**: **Pure Case File register** — Ink Black `#1A1A1A` header band (NOT PHANTOM Red destructive register). Sibling of `quit-confirm.md` and `re-brief-operation.md` per the 4-modal [CANONICAL] inheritance from `quit-confirm.md` Section C.3 + the `case-file-destructive-button` pattern in `interaction-patterns.md`.
> **Pattern Inheritance**: `quit-confirm.md` (CANONICAL Case File modal-scaffold reference) — return-to-registry inherits the modal scaffold + button chrome + focus contract + accessibility patterns + Ink Black header band verbatim; this spec only documents what differs (trigger context is Pause Menu rather than Main Menu; destructive payload is `change_scene_to_file("res://scenes/MainMenu.tscn")` rather than `quit()`; body copy and Confirm label differ).

---

## Purpose & Player Need

The Return-to-Registry Confirm Modal is a destructive-action guard that prevents a paused player from accidentally losing their in-memory mission progress when they activate the "Return to Registry" button on the Pause Menu. It is the deliberate friction layer between *intent to return to the Main Menu* and *destruction of unsaved gameplay progress in the current section*.

The player's goal at this surface is one of two:
1. **Confirm intent to return to the Main Menu** — they have read the warning, accept that any progress since their last save (autosave or manual) will be lost, and want to proceed (Confirm path → pop `Context.PAUSE` → push `Context.LOADING` → `get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")` per CR-14).
2. **Recover from a misclick** — they pressed Return to Registry without realizing it would discard their in-memory progress; they need a clean way back to the Pause Menu (Cancel path → `ModalScaffold.hide_modal()` → focus restored to the originating button on Pause Menu).

**Why this screen exists** (the failure mode it prevents): without this guard, a paused player who clicks "Return to Registry" — perhaps thinking it would simply return to the Pause sub-menu, or because they have just looked at "Operations Archive" and want to go back to a familiar shell — would silently destroy the current section's in-memory state. Per pause-menu.md L484, "in-memory unsaved progress lost" is the specific destructive consequence: the player's exact position, ammo state, completed objectives this session, dialogue beats since last save, alert states, and pickup states all reset on the next section load. They will respawn at the most recent autosave or manual save (which may be many gameplay minutes ago).

The destructive nature here is **volatile**, not persistent: no save data is destroyed (slot 0's prior contents are intact, manual saves to slots 1–7 are intact), but everything since the most recent save is lost. This distinguishes return-to-registry from `new-game-overwrite.md` (which destroys persistent slot 0 data) and aligns it with `quit-confirm.md` (which also destroys volatile in-memory state via `quit()` but not save files).

The player arrives at this modal wanting to **decide**, not to read or browse. The screen's job is to make the decision unambiguous (what will be lost, which button does which) and instant (one keypress to confirm, one to cancel, default focus on the safe action).

---

## Player Context on Arrival

**When does a player first encounter this screen?**

The Player encounters the Return-to-Registry modal in exactly one context: while the **Pause Menu is open mid-mission** and the player has activated the "Return to Registry" button. Cold boot, Main Menu, and gameplay-time (without Pause) cannot reach this modal.

The Pause Menu itself is reached from:
- Mid-section gameplay → `ui_cancel` (Esc / Gamepad B) at top level → Pause Menu mounts at `Context.PAUSE`
- The player must already have made it past the photosensitivity boot warning (P0), navigated the Main Menu (P1), started or loaded a section (P2), and entered active gameplay (P3) before reaching this modal.

**Two emotional-state contexts on arrival**:

1. **Deliberate exit** (most common): The player has played through a portion of the current section, may have completed objectives or made significant progress, and is now choosing to step away. They may want to play a different mission via Operations Archive, replay the briefing via Re-Brief Operation, or simply return to the safety of the Main Menu shell. Emotional state: **calm, settled, considering tradeoffs** — the modal's body copy ("Unsaved progress lost.") helps them decide whether the cost is acceptable.

2. **Misclick recovery** (less common but high-stakes): The player has accidentally activated Return to Registry — possibly because they pressed Tab one too many times in the Pause Menu's button stack, or because they thought "Return to Registry" was a sub-menu rather than the exit. Emotional state: **mild alarm, hopeful for an undo** — the modal's Cancel-default-focus is what saves them.

In either case, the player is NOT in a time-pressured context. The mission is paused; nothing burns down. The modal can afford considered input.

**What were they just doing?**

- Active mid-section gameplay (in P3 — pursuing a stealth objective, observing patrols, reading a document at a lectern, navigating geometry).
- Pressed Esc → Pause Menu opened, mission state frozen.
- Navigated Pause Menu's button stack (Resume Surveillance / File Dispatch / Operations Archive / Personnel File / [Re-Brief Operation, if checkpoint state] / **Return to Registry** / Close File).
- Activated Return to Registry button.

**Voluntary or involuntary arrival?**

Always **voluntary** — the player explicitly activated a button. The modal is a deliberate friction layer, not a redirect. The player can always cancel and restore their original Pause Menu state with no side effects.

---

## Navigation Position

This screen lives at:

```
[In-Mission Gameplay] → [Pause Menu] → [Return-to-Registry Modal]
                                       ↳ on Confirm: pop Context.PAUSE → push Context.LOADING
                                                     → change_scene_to_file(MainMenu.tscn)
                                                     → [Main Menu] (fresh load)
                                       ↳ on Cancel:  → [Pause Menu] (focus restored to Return to Registry button)
```

The modal is a **non-replacing overlay** mounted by `ModalScaffold` as a child of the Pause Menu (per menu-system.md L125: "ModalScaffold child of PauseMenu"). It sits at CanvasLayer 1024 (per ADR-0004 IG7 — modals layer above Pause Menu's CanvasLayer). The Pause Menu remains visible underneath the 52% Ink Black backdrop dim, but its input is gated by `Context.MODAL` push.

**Alternate entry paths**: NONE. The modal is **only** reachable from the Pause Menu's "Return to Registry" button. It cannot be reached from:
- Main Menu (Main Menu uses `quit-confirm` for "Close File" exits, not return-to-registry)
- Mid-gameplay without Pause (no in-section path opens this modal)
- Any other Pause Menu button (each Pause button has its own destructive confirm: Re-Brief Operation has `re-brief-operation.md`; Close File has `quit-confirm.md`; Save Game / Load Game / Settings / Operations Archive / Personnel File are non-destructive and use no confirm)

**Context dependency**: this screen is **always** context-dependent — it requires both `Context.PAUSE` to be active (i.e., a section is mid-play and Pause Menu is open) and the Pause Menu's "Return to Registry" button to have been activated.

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Pause Menu — `ReturnToRegistryButton.pressed` | Player activates "Return to Registry" button while Pause Menu is open at `Context.PAUSE` | Section is mid-play; Pause Menu is mounted; in-memory section state (player position, AI states, objective progress, etc.) is frozen but intact; section's last save (autosave or manual) is the most recent recoverable state. The originating button reference is passed to `ModalScaffold.show_modal()` as `return_focus_node`. |

**No other entry path exists.** The modal cannot be summoned from:
- Main Menu (uses `quit-confirm.md` for desktop exit; uses `new-game-overwrite.md` for new-game starts)
- Mid-gameplay without Pause Menu
- Save Game Screen, Load Game Screen, Operations Archive, Personnel File, or any other sub-screen
- Quicksave / Quickload triggers

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Main Menu (fresh load)** | Confirm button pressed (Enter / Space / `ui_accept` while focused, OR mouse click on "Return to Registry" button) | **Destructive — irreversible from Pause's perspective.** Sequence per CR-14 + edge-case L900: (1) `set_input_as_handled()`; (2) pop `Context.MODAL`; (3) pop `Context.PAUSE`; (4) push `Context.LOADING`; (5) `call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")`. Audio fades on `section_exited` automatically (free per Audio § Mission domain — no Menu-level music fade call needed). The destructive scene change destroys the section trees AND Pause Menu AND ModalScaffold AND this modal as descendants. MainMenu loads fresh; `_boot_warning_pending` is false (already dismissed earlier this session per Settings CR-18), so no boot warning re-mounts. The player lands on the Main Menu's Continue button (label per CR-5: "Resume Surveillance" if slot 0 OCCUPIED, "Begin Operation" if EMPTY/CORRUPT). |
| **Pause Menu (focus restored)** | Cancel button pressed (Enter / Space / `ui_accept` while focused, OR mouse click on "Continue Mission" button) | Non-destructive. `set_input_as_handled()` → `ModalScaffold.hide_modal()` pops `Context.MODAL` → Pause Menu input restored (button container `process_input = true`) → focus returned to the originating "Return to Registry" button on Pause Menu via `is_instance_valid()` + `call_deferred("grab_focus")` (per menu-system.md Cluster F edge-case L901 — modal MUST validate before focusing). Pause Menu's prior state (which button last held focus) is preserved — only the modal layer dismisses. |
| **Pause Menu (focus restored)** | `ui_cancel` (Esc / Gamepad B) from anywhere within the modal | Equivalent to Cancel button press. Non-destructive. Same exit path. |
| **Pause Menu (focus restored)** | Mouse click on backdrop (outside modal card) | Equivalent to Cancel button press per `dual-focus-dismiss` pattern. Non-destructive. Same exit path. |

**Irreversibility note**: the Confirm path is **one-way from this modal's perspective**. Once `change_scene_to_file()` is called, the section tree is destroyed and the Pause Menu is destroyed; the player cannot return to their prior in-mission state. The modal's Cancel-default-focus is the project's commitment to motor-accessibility safety: a player who accidentally presses Enter on modal mount triggers Cancel, not Confirm.

**Save data is NOT destroyed** by this confirm path. Slot 0 (autosave) and slots 1–7 (manual saves) all survive untouched. The destructive consequence is in-memory state only. After landing on Main Menu, the player can press Continue ("Resume Surveillance") to load slot 0 and resume from their most recent autosave checkpoint.

---

## Layout Specification

### Information Hierarchy

The modal must communicate four pieces of information in a deliberate order, identical to its quit-confirm sibling:

1. **Most critical** (eye lands here first within the first 200 ms of modal mount): **Modal identity / what is at stake** — communicated by the Ink Black `#1A1A1A` header band with the stamp text "RETURN TO REGISTRY" rotated -5° in Parchment per the Case File register (art-bible §7D). The Ink Black band signals "Case File destructive register" (consistent with quit-confirm); the stamp text identifies the modal scope.
2. **Second**: **What will happen if Confirm is pressed** — the body text "Unsaved progress lost." in American Typewriter Bold 18 px Ink Black, center-aligned. Single declarative sentence. No technical jargon, no error code.
3. **Third**: **The two action choices** — Confirm (Ink Black destructive register, "Return to Registry") and Cancel (BQA Blue safe register, "Continue Mission"). Default focus on Cancel. Buttons are right-aligned at the card bottom, with 16 px gap and a 1 px ruled divider above.
4. **Discoverable / not visible at rest**: the Pause Menu underneath remains visible through the 52% Ink Black backdrop dim — the player can see the broader Pause context (their button stack, the section name, any Re-Brief Operation visibility state) but cannot interact until the modal is dismissed.

### Layout Zones

The modal card uses a five-zone vertical stack, inheriting the `880 × 200 px` baseline geometry from `quit-confirm.md` Section C.3 [CANONICAL]:

```
┌─────────────────────────────────────────────────────────────┐
│  Z1 — Ink Black header band (50 px tall, full card width)   │  ← Case File destructive identity
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Z2 — Body text region (~80 px tall, centered vertically)   │  ← consequence statement
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Z3 — Divider (1 px Ink Black 70%, full card width − 64 px) │  ← visual rest
├─────────────────────────────────────────────────────────────┤
│  Z4 — Button row (~70 px tall, buttons right-aligned)       │  ← player decision
└─────────────────────────────────────────────────────────────┘
                    Z5 — Backdrop (full-screen Ink Black 52% dim, behind card, over Pause Menu)
```

| Zone | Purpose | Approx Dimensions | Padding |
|---|---|---|---|
| **Z1 — Header band** | Ink Black identity strip with rotated stamp text | `880 × 50 px` | Inside card top edge, full width |
| **Z2 — Body text region** | Single-line declarative sentence about consequence | `880 × ~80 px` (height grows for localized variants — see Localization Considerations) | 32 px H pad inside card edges; vertical center between header and divider |
| **Z3 — Divider** | 1 px Ink Black 70% rule, full card width minus 32 px H pad each side | `816 × 1 px` | Centered horizontally; 8 px above button row |
| **Z4 — Button row** | Two buttons right-aligned with 16 px gap | `880 × ~70 px` | 32 px H pad inside card right edge; 32 px bottom pad |
| **Z5 — Backdrop** | Full-screen Ink Black 52% dim behind modal card, over Pause Menu | `1920 × 1080 px` (full-screen) | n/a — covers entire viewport including Pause Menu folder |

**Card position on screen**: Centered horizontally and vertically on the viewport at native 1920×1080. At other resolutions, the card maintains its 880×200 px size (no scaling) and remains centered. (The card does NOT grow at higher resolutions; it grows only when localized body text exceeds one line.)

### Component Inventory

| Zone | Component | Type | Properties | Interactive | Pattern Reference |
|---|---|---|---|---|---|
| Z5 | `ModalBackdrop` | `ColorRect` (full-screen) | Ink Black `#1A1A1A` at 52% alpha (matches `desk_overlay_alpha = 0.52` from `menu-system.md` §A.2) | **Yes** — mouse-click-anywhere-on-backdrop dismisses modal with Cancel semantics (`dual-focus-dismiss` pattern) | `modal-scaffold` (backdrop contract) |
| — | `ModalCard` | `PanelContainer` w/ `StyleBoxFlat` | `880 × 200 px` baseline; Parchment `#E8DCC4` fill; 2 px Ink Black `#1A1A1A` hard-edge border; 0 px corner radius; no drop shadow (Pillar 5 refusal) | No (root container) | `modal-scaffold` (card contract) |
| Z1 | `HeaderBand` | `ColorRect` (or `PanelContainer` w/ `StyleBoxFlat`) | **Ink Black `#1A1A1A` fill**; full card width × 50 px; no border; 0 px corner radius | No | inherited from `quit-confirm.md` C.3 |
| Z1 | `HeaderStamp` | `Label` | Futura/DIN Bold 24 px Parchment `#E8DCC4`; left-aligned, 16 px left margin within band; vertically centered in band; **rotated -5°** per art-bible §7D Case File register; text = `tr("menu.return_registry.stamp")` → `RETURN TO REGISTRY` | No (text-only label) | `case-file-stamp-rotation` (inherited from quit-confirm.md C.3) |
| Z2 | `BodyText` | `Label` | American Typewriter Bold 18 px Ink Black `#1A1A1A`; **center-aligned for single-line**, left-aligned for multi-line localized variants ([CANONICAL alignment rule from quit-confirm]); text = `tr("menu.return_registry.body_alt")` → `Unsaved progress lost.` | No (text-only) | `auto-translate-always` + `accessibility-name-re-resolve` |
| Z3 | `Divider` | `ColorRect` (1 px tall) | Ink Black `#1A1A1A` at 70% alpha; full card width minus 32 px H pad each side (= 816 px wide); centered horizontally; 8 px above button row | No | inherited from quit-confirm.md C.3 |
| Z4 | `ConfirmButton` (destructive) | `Button` w/ `StyleBoxFlat` | **Ink Black `#1A1A1A` fill + Parchment text** per `case-file-destructive-button` pattern; `280 × 56 px` minimum hit target (WCAG SC 2.5.5); DIN 1451 Bold 18 px Parchment `#E8DCC4` text; 0 px corner radius; positioned **left of Cancel** in button row right-anchor; label = `tr("menu.return_registry.confirm")` → `Return to Registry` | **Yes** — `ui_accept` activates destructive path | `case-file-destructive-button` + `modal-scaffold` button contract |
| Z4 | `CancelButton` (safe, default focus) | `Button` w/ `StyleBoxFlat` | **BQA Blue `#1B3A6B` fill + Parchment text** per `modal-scaffold` safe-action contract; `280 × 56 px` minimum hit target; DIN 1451 Bold 18 px Parchment `#E8DCC4` text; 0 px corner radius; positioned **right of Confirm** at card right edge minus 32 px pad; label = `tr("menu.return_registry.cancel")` → `Continue Mission`; **default focus on mount** with 4 px BQA Blue brightened border on focus | **Yes** — `ui_accept` activates safe path; `ui_cancel` from anywhere also triggers this path | `modal-scaffold` (default-focus-on-safe-action) |

**Component count**: 8 nodes (1 backdrop + 1 card + 2 in header + 1 body + 1 divider + 2 buttons). Identical structure to quit-confirm and new-game-overwrite siblings. Pillar 5 minimum-chrome.

### ASCII Wireframe

#### Default state (modal mounted, default focus on Cancel)

```
╔═══════════════════════════════════════════════════════════════════════╗
║ █████████████████████████████████████████████████████████████████████ ║  ← Z1: Ink Black header band (50 px)
║ █  RETURN TO REGISTRY  ◆──── (rotated -5° stamp) ────────────────── █ ║     Stamp: DIN Bold 24 px Parchment, rotated -5°
║ █████████████████████████████████████████████████████████████████████ ║
║                                                                       ║
║                                                                       ║
║                     Unsaved progress lost.                            ║  ← Z2: body text, AT Bold 18 px, center-aligned
║                                                                       ║
║                                                                       ║
║       ─────────────────────────────────────────────────────           ║  ← Z3: 1 px divider, 70% Ink Black
║                                                                       ║
║                          ┌─────────────────────┐ ┌──────────────────┐ ║  ← Z4: button row, right-anchored
║                          │ Return to Registry  │ │ Continue Mission ⬛│ ║     Confirm: Ink Black fill, Parchment text
║                          └─────────────────────┘ └──────────────────┘ ║     Cancel: BQA Blue fill, Parchment text + 4 px border (focused)
║                                                                       ║     16 px gap, 32 px right pad
╚═══════════════════════════════════════════════════════════════════════╝
                                ↑ 880 × 200 px card, centered on viewport
                                ↑ Backdrop: full-screen Ink Black 52% dim over Pause Menu
                                ↑ Pause Menu folder visible underneath dim (button stack, section breadcrumb)
```

#### Focus shifted to Confirm (Tab pressed once from default)

```
╔═══════════════════════════════════════════════════════════════════════╗
║ █████████████████████████████████████████████████████████████████████ ║
║ █  RETURN TO REGISTRY  ◆──── (rotated -5° stamp) ────────────────── █ ║
║ █████████████████████████████████████████████████████████████████████ ║
║                                                                       ║
║                                                                       ║
║                     Unsaved progress lost.                            ║
║                                                                       ║
║                                                                       ║
║       ─────────────────────────────────────────────────────           ║
║                                                                       ║
║                          ┌═════════════════════┐ ┌──────────────────┐ ║  ← Confirm: 4 px BQA Blue border = focus indicator
║                          ║ Return to Registry  ║ │ Continue Mission │ ║     Cancel: no border = unfocused
║                          └═════════════════════┘ └──────────────────┘ ║     Tab cycle: Cancel → Confirm → Cancel (focus trap)
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
                                ↑ Tab from Cancel cycles to Confirm; Shift+Tab cycles back
                                ↑ Focus never escapes modal (CR-24 strict focus trap)
```

**Wireframe notes**:
- The card outline `╔═╗ ║ ╚═╝` represents the 2 px Ink Black hard-edge border.
- The Ink Black header band is full card width (no inset) — IDENTICAL to quit-confirm; distinct from new-game-overwrite which uses PHANTOM Red.
- The stamp text "RETURN TO REGISTRY" is rotated -5° per Case File register inheritance.
- Buttons are right-anchored: their right edge sits at `card_right − 32 px outer pad`; their left edges are determined by their fixed widths + 16 px gap. The Confirm button is wider than new-game-overwrite's "Begin Operation" button (because "Return to Registry" is a longer label string at 18 chars vs "Begin Operation" at 15 chars; the Confirm hit-target may grow to ~340 px to accommodate, but the minimum 280 px floor remains for shorter localized labels).
- Default focus on Cancel is indicated by the 4 px BQA Blue brightened border.
- When focus moves to Confirm, the 4 px BQA Blue border applies to Confirm; Cancel's border returns to its unfocused state.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default** | `ModalScaffold.show_modal(ReturnToRegistryContent)` called from Pause Menu after `ReturnToRegistryButton.pressed` | Modal appears at full position (hard cut at MVP — see Transitions); Cancel button has default focus with 4 px BQA Blue brightened border; `accessibility_live = LIVE_ASSERTIVE` one-shot fires; A1 typewriter clack sfx plays on UI bus. |
| **Focus on Confirm** | Tab pressed once from default (or Shift+Tab from Cancel — same result via focus trap) | Confirm button gains 4 px BQA Blue brightened border; Cancel border returns to unfocused state. No sfx. No body or header changes. |
| **Confirm-in-flight** | Confirm button pressed; `change_scene_to_file()` is being called this frame | Confirm button `disabled = true` for 1 frame (prevents double-activation); A1 clack + A6 rubber-stamp thud both fire on the same frame; modal does NOT call `hide_modal()` directly — sequence proceeds: pop `Context.MODAL` → pop `Context.PAUSE` → push `Context.LOADING` → `call_deferred("change_scene_to_file", MainMenu.tscn)`. The modal vanishes with its parents (Pause Menu + section trees) within 1–2 frames as Godot frees the destroyed scene. |
| **Cancel-in-flight** | Cancel button pressed OR `ui_cancel` pressed OR mouse click on backdrop | A1 clack sfx (cancel-feel, no thud); `set_input_as_handled()` → `ModalScaffold.hide_modal()` → pop `Context.MODAL` → Pause Menu button container `process_input = true` restored → focus returned to "Return to Registry" button via `is_instance_valid()` + `call_deferred("grab_focus")` (per menu-system.md Cluster F edge-case L901). |
| **Reduced-motion variant** | `Settings.accessibility.reduced_motion_enabled == true` at `_ready()` | Any appearance tween (header band slide-in, card scale-in) is suppressed; modal appears at full position via hard cut. A1 clack sfx still plays at full duration. The `accessibility_live = LIVE_ASSERTIVE` one-shot still fires. (At MVP, the modal is already hard-cut — this state is identical to default at MVP, but the conditional is wired for future tween additions per CR-23.) |
| **Localized variant — long body text** | Body text exceeds `880 − 64 = 816 px` width at given font size in given locale (e.g., FR/DE expansion of "Unsaved progress lost.") | Body region grows vertically to accommodate wrapped multi-line text; alignment switches from center to **left** per [CANONICAL alignment rule]. Card height grows from 200 px baseline to whatever is needed. Header band height stays at 50 px; button row stays at 70 px. Card remains centered on viewport. |
| **Loading state** | N/A — justified absence | The modal does not fetch async data; all data resolved at mount via `tr()` and Theme inheritance. No loading state needed. |
| **Error state** | N/A — justified absence | The modal cannot fail independently. `change_scene_to_file()` failures (e.g., MainMenu.tscn file missing) are engine-level fatal errors handled outside this modal's scope. The modal has no error variant. |
| **Re-Brief Operation visible variant** | Pause Menu's checkpoint state is `true` (per pause-menu.md CR — Re-Brief Operation button is visible between Personnel File and Return to Registry in the Pause Menu's button stack) | Modal appearance is identical (Re-Brief visibility on Pause Menu does NOT affect this modal). The Pause Menu underneath the backdrop dim shows the longer 7-button stack; on Cancel, focus returns to Return to Registry button (position differs depending on Re-Brief visibility but same button identity). |
| **Locale-change-triggered re-resolve** | `NOTIFICATION_TRANSLATION_CHANGED` fires while modal is open (e.g., player changed locale via Settings — but Settings is not reachable from this modal, so this requires an external trigger like a dev hotkey or live-edit) | Header stamp text, body text, both button labels, and AccessKit `accessibility_name` + `accessibility_description` re-resolve via `_update_accessibility_names()` helper (per `accessibility-name-re-resolve` pattern). Card geometry recomputes (body region may grow or shrink). Focus is preserved (no re-focus needed). |
| **Backdrop fade-in** (post-MVP, currently MVP hard-cut) | If the project later adds a 200 ms backdrop fade-in (per pause-menu.md L565 stamp-slam precedent), this state covers the in-flight tween | Backdrop opacity ramps 0 → 52% over 200 ms (linear or ease-out per `motion-curves` table); card appears at full position immediately; button input disabled until backdrop reaches 52%. **Reduced-motion variant suppresses this tween** — backdrop appears at 52% instantly. |
| **OS window focus loss** (edge case) | OS window loses focus while modal is open (e.g., player Alt-Tabs to another app) | Modal stays visible and non-responsive to OS-level events. On `NOTIFICATION_WM_FOCUS_IN`, `Input.flush_buffered_events()` clears any stale input state before the first `_unhandled_input` of the refocused frame (per menu-system.md Cluster G L915). Prevents phantom `ui_cancel` from dismissing modal on refocus. |

**No "in-progress" indicator state**: there is no spinner, no progress bar, no "Returning to Main Menu..." copy. The Confirm button's `disabled = true` is the only in-flight signal, and it is gone within 1–2 frames as `change_scene_to_file()` destroys the scene tree. (Pillar 5 forbids modern progress chrome.)

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse + Gamepad** (per `technical-preferences.md` §Input & Platform — Primary: Keyboard/Mouse; Gamepad: Partial coverage for menu navigation).

| Player Action | Input — Keyboard | Input — Mouse | Input — Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **Activate default-focused button (Cancel "Continue Mission")** | Enter / Space | Click on "Continue Mission" button | A button (`ui_accept`) | A1 typewriter clack (60–80 ms, UI bus); button visual press-state (1 frame) | `set_input_as_handled()` → `ModalScaffold.hide_modal()` → pop `Context.MODAL` → Pause Menu input restored → focus to originating button. **Non-destructive.** |
| **Cycle focus to Confirm** | Tab | n/a (mouse uses hover, not focus cycle) | D-pad Right OR D-pad Down (focus_neighbor) | 4 px BQA Blue brightened border moves from Cancel to Confirm; A1 typewriter clack at low volume (40–60 ms — focus-shift register, not activation) | Focus indicator on Confirm; Cancel returns to unfocused state. No state change beyond focus. |
| **Cycle focus back to Cancel** | Shift+Tab | n/a | D-pad Left OR D-pad Up | Same as above (border moves back to Cancel) | Focus indicator returns to Cancel; Confirm returns to unfocused state. |
| **Activate Confirm "Return to Registry" (destructive)** | Enter / Space (when Confirm focused) | Click on "Return to Registry" button | A button (`ui_accept`, when Confirm focused) | A1 typewriter clack + A6 rubber-stamp thud (90–110 ms — destructive register, both on UI bus, fired same frame); Confirm button `disabled = true` for 1 frame | `set_input_as_handled()` → pop `Context.MODAL` → pop `Context.PAUSE` → push `Context.LOADING` → `call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")`. Audio fades on `section_exited` automatically. Modal + Pause Menu + section trees destroyed within 1–2 frames as Godot frees them. **DESTRUCTIVE — IRREVERSIBLE in-memory progress.** |
| **Dismiss with Esc / Cancel** | Escape | Click on backdrop (anywhere outside modal card) | B button (`ui_cancel`) | A1 typewriter clack (cancel-feel, 60–80 ms, UI bus); no thud | Equivalent to Cancel button activation. `set_input_as_handled()` → `ModalScaffold.hide_modal()` → pop `Context.MODAL` → focus to originating button. **Non-destructive.** |
| **Hover Confirm (mouse only)** | n/a | Move mouse over "Return to Registry" button | n/a | Hover state: 1 px brightened Ink Black fill (or 5% opacity Parchment overlay); cursor changes to pointer | No state change; pure visual affordance. |
| **Hover Cancel (mouse only)** | n/a | Move mouse over "Continue Mission" button | n/a | Hover state: 5% brightened BQA Blue fill; cursor changes to pointer | No state change; pure visual affordance. |
| **Mouse click outside backdrop / off-screen** | n/a | Click outside the backdrop's render rect (not possible at full-screen 1920×1080) | n/a | n/a | Not applicable; backdrop is full-screen. Any click on backdrop is "outside modal card" → Cancel semantics. |

**Focus trap contract** (CR-24 — strict, mandatory at VS sprint scope):
- Tab from Cancel → cycles to Confirm
- Tab from Confirm → cycles back to Cancel
- Shift+Tab from Cancel → cycles to Confirm
- Shift+Tab from Confirm → cycles back to Cancel
- D-pad Up/Down/Left/Right on gamepad mirror Tab/Shift+Tab cycle behavior via `focus_neighbor_*` properties
- **No Tab/D-pad input can ever reach the underlying Pause Menu while the modal is open.** (FP-15 — keyboard trap forbidden outside modals; modals are the exception per CR-24.)

**Input gating during modal open**:
- Pause Menu button container: `process_input = false` (set when modal mounted; restored when modal dismissed via Cancel)
- `Context.MODAL` is at `peek()` of `InputContext` stack; all non-modal input handlers gate on this
- Quicksave (F5) / Quickload (F9): blocked by `Context.MODAL` (no save mid-modal); even though Pause Menu has saving paths, they are gated behind their own buttons which require `Context.PAUSE` to peek — modal blocks them
- Pause toggle (Esc / Start): cannot toggle Pause from `Context.MODAL`; Esc routes to `ui_cancel` → Cancel exit instead
- All gameplay input (movement, interaction, shoot): blocked by both `Context.PAUSE` (gameplay frozen) AND `Context.MODAL` (additional layer)

**`set_input_as_handled()` discipline** (per `set-handled-before-pop` pattern): both Confirm and Cancel exit paths MUST call `set_input_as_handled()` BEFORE the first `InputContext.pop()` to prevent silent-swallow propagation to the Pause Menu's `_unhandled_input`. This is a [CANONICAL] rule from `interaction-patterns.md` §`set-handled-before-pop`.

---

## Events Fired

This modal is a **consumer**, not a publisher. It does NOT emit `Events.*` signals. It calls service APIs and engine calls directly (`change_scene_to_file`, `ModalScaffold.hide_modal`).

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Modal mounted (entry) | none — modal mount is internal to ModalScaffold | (Modal mount is observable via `ModalScaffold.modal_shown` if the scaffold publishes it; this is not a Menu-level event.) |
| Confirm pressed | `get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")` (an engine call, not a signal) — and downstream, **LS itself emits** `Events.section_exited(current_section_id, RETURN_TO_REGISTRY)` (or equivalent reason enum) before scene destruction; **Audio subscribes** to `section_exited` to fade gameplay music (free per Audio § Mission domain) | `section_id: StringName` (downstream from LS) |
| Cancel pressed | `ModalScaffold.hide_modal()` (a method call, not a signal) | n/a |
| `ui_cancel` pressed (Esc / B) | Same as Cancel pressed | n/a |
| Mouse click on backdrop | Same as Cancel pressed | n/a |
| Tab / Shift+Tab focus cycle | none | n/a — Godot's focus system handles this without a custom event |

**Analytics events** (none at MVP — analytics is post-MVP per `design/gdd/systems-index.md`):

| Player Action | Analytics Event (post-MVP) | Payload |
|---|---|---|
| Confirm pressed | `menu.return_registry.confirmed` | `{ section_id: StringName, elapsed_in_section_ms: int, last_save_age_ms: int, elapsed_in_modal_ms: int }` |
| Cancel pressed | `menu.return_registry.cancelled` | `{ section_id: StringName, cancel_method: "button" | "ui_cancel" | "backdrop_click", elapsed_in_modal_ms: int }` |
| Modal mounted | `menu.return_registry.shown` | `{ section_id: StringName }` |

**Persistent-state-modifying actions flagged for architecture team**:
- **Confirm path**: triggers a `change_scene_to_file()` that destroys the section tree. **No save data is destroyed** by the modal directly; all persistence is in-memory section state (player position, AI states, objective progress, dialogue beats, alert states, pickup states, fired triggers since last save). However, this is still an **architectural concern** because the section tree's `_exit_tree()` callbacks fire as the scene destructs — any system that owns in-memory state MUST flush or discard that state in `_exit_tree()`. Failure to do so would leak state into the next section instance (post-MainMenu → New Game / Load Game cycle). This is LS's responsibility per LS step-9 callback machinery.
- **Audio fade**: Audio subscribes to `section_exited` per Audio § Mission domain. The Confirm path expects this fade to happen automatically as a side-effect of `change_scene_to_file()` triggering `section_exited`. **OQ-RTR-1**: verify that `change_scene_to_file()` does NOT bypass the `section_exited` signal — i.e., that LS or some equivalent explicitly emits the signal in the section's `_exit_tree()` callback before the scene destructs. If `change_scene_to_file()` destroys the tree before the signal fires, the audio fade does not happen and the music cuts hard. Coord with audio-director + technical-director.

**No event for the originating button reference**: the modal does not publish a "modal-mounted" event with the originating button as payload. The `return_focus_node` is passed as a parameter to `ModalScaffold.show_modal()` and stored in the scaffold's local state; not a project-wide signal.

---

## Transitions & Animations

| Phase | Transition | Duration | Easing | Reduced-Motion Variant |
|---|---|---|---|---|
| **Modal enter (appear)** | Hard cut (MVP) — modal appears at full position with backdrop at 52% dim and card fully rendered, on the same frame as `show_modal()` is called | 0 ms (1 frame) | n/a | Identical (already hard cut) |
| **Modal enter (post-MVP candidate)** | Backdrop fade-in 0% → 52% opacity; card slide-up 32 px → 0 px or scale 0.95 → 1.0 | 200 ms | ease-out (`Tween.EASE_OUT, Tween.TRANS_QUAD`) | Suppressed — backdrop snaps to 52%, card snaps to position. CR-23 conditional. |
| **Focus shift (Tab)** | 4 px BQA Blue brightened border slides from one button to the other (or appears/disappears at the destination/origin) | ~80 ms | ease-out | Suppressed — border instantly appears/disappears. CR-23 conditional. |
| **Button hover (mouse only)** | Background fill brightens 5% on `mouse_entered`; reverses on `mouse_exited` | ~120 ms | linear | Suppressed — instant brightness change. CR-23 conditional. |
| **Button press (visual)** | Background fill darkens 10% on `button_down`; reverses on `button_up` | 1 frame (instant) | n/a | Identical (already instant) |
| **Confirm-in-flight (stamp slam)** | Per pause-menu.md L565 "Stamp slam (destructive confirm — Close File / Return to Registry / Re-Brief / Save-Failed Abandon)" — the rubber-stamp visual animates a 1-frame downward slam on Confirm press | ~80 ms (3–5 frames) | ease-in (lands hard) | Suppressed — instant state change to "stamped" appearance; A6 thud audio still plays. CR-23 conditional. |
| **Modal exit (Cancel path)** | Hard cut (MVP) — modal hides on the same frame as `hide_modal()` is called; backdrop and card vanish; focus returns to originating button on next frame via `call_deferred("grab_focus")` | 0–16 ms (1–2 frames) | n/a | Identical (already hard cut) |
| **Modal exit (post-MVP candidate)** | Backdrop fade-out 52% → 0%; card slide-down 0 → 32 px or scale 1.0 → 0.95 | 200 ms | ease-in (`Tween.EASE_IN, Tween.TRANS_QUAD`) | Suppressed — backdrop snaps to 0%, card snaps away. CR-23 conditional. |
| **Modal exit (Confirm path)** | Modal does NOT explicitly exit — `change_scene_to_file()` destroys the entire scene tree (including Pause Menu and modal as descendants) within 1–2 frames | ~16–32 ms (engine's pace) | n/a (engine-level destruction) | n/a — Godot owns the scene-change transition; subsequent transition to MainMenu is Godot's default cut |

**Photosensitivity audit** (per `design/accessibility-requirements.md` and Cutscenes audit):
- No flashing — all transitions are monotonic opacity ramps or instant state changes
- No color-rapid-change — Ink Black header band appears at full opacity, does not pulse, flicker, or strobe
- No high-contrast strobe — backdrop dim is a single 52% value, no oscillation
- All transitions safe for photosensitivity tier per WCAG SC 2.3.1 (≤3 flashes per second)

**Motion-sickness audit**:
- No camera motion (this is a 2D UI overlay)
- No parallax shift
- No high-velocity slide-ins (max 200 ms slide is post-MVP polish, well under fatigue thresholds)
- Reduced-motion variant suppresses all tweens; suitable for vestibular-sensitivity players

**Audio-paired transitions** (locked per menu-system.md §A.1–A.2 + pause-menu.md §A):
- A1 typewriter clack — fires on modal mount AND on every button press (60–80 ms, UI bus)
- A6 rubber-stamp thud — fires on Confirm press only (90–110 ms, UI bus; destructive register; matches "Stamp slam" group per pause-menu.md L565)
- A8 paper-drop modal-appear — fires on modal mount (per pause-menu.md L408 "show_modal(ReturnToRegistryContent); A8 modal-appear")
- Gameplay music fade — fires automatically via Audio's `section_exited` subscription on Confirm path; no Menu-level call needed

**No animation owns the destructive moment**: the irreversible action (Confirm pressed) is communicated by audio (A6 thud + music fade) + visual (button press-state + disabled flash + stamp slam) + the immediate scene change. There is no "Are you sure???" delay tween or hold-to-confirm gesture. The friction is the modal itself, not animation.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| `current_section_id` (StringName) | LS / MissionLevelScripting (mid-section, available via `LS.current_section_id` or equivalent) | **Indirect read** — modal does not read; the data is implicitly preserved in scene tree state until `change_scene_to_file()` destroys it | Modal does not display section ID directly. The data is implicit in the analytics payload (post-MVP) and in the audio system's `section_exited` emission. |
| `tr("menu.return_registry.stamp")` → `RETURN TO REGISTRY` | `translations/menu.csv` via Godot's `tr()` function | **Read** (resolved at `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED`) | Already in string table per menu-system.md §C.8 L343 |
| `tr("menu.return_registry.body_alt")` → `Unsaved progress lost.` | `translations/menu.csv` | **Read** | Already in string table per menu-system.md §C.8 L344 (22 chars — under L212 25-char cap) |
| `tr("menu.return_registry.confirm")` → `Return to Registry` | `translations/menu.csv` | **Read** | Already in string table per menu-system.md §C.8 L345 |
| `tr("menu.return_registry.cancel")` → `Continue Mission` | `translations/menu.csv` | **Read** | Already in string table per menu-system.md §C.8 L346. Note: matches quit-confirm's Cancel label for in-fiction safe-action consistency. |
| `tr("menu.return_registry.confirm.desc")` → AccessKit description for Confirm button | `translations/menu.csv` | **Read** (resolved on `NOTIFICATION_TRANSLATION_CHANGED`) | **NEW STRING** — this spec adds it. Suggested English: "Return to the main menu. Unsaved progress in this section is lost." (Mirrors the Pause Menu button's `accessibility_description` per pause-menu.md L671 — same plain-language safety-net text propagates to the modal Confirm.) |
| `tr("menu.return_registry.cancel.desc")` → AccessKit description for Cancel button | `translations/menu.csv` | **Read** | **NEW STRING** — this spec adds it. Suggested English: "Resume the operation. Pause Menu remains open." |
| `Settings.accessibility.reduced_motion_enabled` | `SettingsService` autoload (per ADR-0007 canonical registration) | **Read** (resolved at modal `_ready()`; not re-read on settings change while modal is open) | Suppresses appearance tweens (currently no-op at MVP since modal is hard-cut; wired for VS+) |
| `Theme.modal_scaffold` (StyleBoxFlat colors, font sizes, button styles) | Project-wide Theme resource (per ADR-0004 IG6) | **Read** | Inherited from ModalScaffold; modal does not author Theme overrides |
| `originating_button: Control` (Pause Menu's "Return to Registry" button reference) | Passed in by Pause Menu when calling `ModalScaffold.show_modal()` | **Read + Write** (write = the reference is stored for `return_focus_node` on hide) | Per `menu-system.md` Cluster F edge-case L901, modal MUST validate `is_instance_valid(originating_button)` before `call_deferred("grab_focus")` on dismiss. If invalid (e.g., locale-change-triggered button rebuild), fall back to Pause Menu's `_default_focus_target` (= "Resume Surveillance" button per menu-system.md). |

**Architectural concerns flagged**:
- The modal does not own any persistent state of its own. All persistent state changes initiated by Confirm flow through Godot's `change_scene_to_file()` engine call. The modal's data flow is **strictly read-only with one engine call on Confirm**.
- No autoload registration needed for the modal — it is a `ModalScaffold` content node, not a long-lived singleton.
- The 2 NEW localization strings (Confirm/Cancel `accessibility_description`) need to be added to `translations/menu.csv` before this modal can ship — coord with localization-lead.

**No real-time data**: the modal does not display playtime, section timestamps, or any real-time-updating values. The body copy is static at "Unsaved progress lost." regardless of how long the player has been in the section.

---

## Accessibility

**Committed tier**: **Standard** (per `design/accessibility-requirements.md`).

The modal inherits all accessibility commitments from `modal-scaffold` and `case-file-destructive-button` patterns. The contract below is the consolidated checklist for QA verification.

### Keyboard-only navigation path

| Step | Action | Expected Result |
|---|---|---|
| 1 | Modal mounts | Focus moves to "Continue Mission" Cancel button (default focus per `modal-scaffold` safe-action contract) |
| 2 | Tab | Focus moves to "Return to Registry" Confirm button (focus trap cycles within modal) |
| 3 | Tab again | Focus cycles back to Cancel (no escape from modal) |
| 4 | Shift+Tab | Focus moves backwards through cycle (Cancel → Confirm → Cancel) |
| 5 | Enter / Space (on Cancel) | Activates Cancel; modal dismisses; focus returns to "Return to Registry" button on Pause Menu |
| 6 | Enter / Space (on Confirm) | Activates Confirm; scene change to MainMenu (modal vanishes with parent) |
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
| **Start / Select** | NOT USED in modal context | n/a — Pause cannot toggle from `Context.MODAL` |

### Text contrast and minimum readable font sizes

| Element | Foreground | Background | Contrast Ratio | WCAG AA / AAA | Font Size |
|---|---|---|---|---|---|
| Header stamp ("RETURN TO REGISTRY") | Parchment `#E8DCC4` | Ink Black `#1A1A1A` | ~14.2:1 | AAA Pass (≥7:1) | DIN Bold 24 px |
| Body text ("Unsaved progress lost.") | Ink Black `#1A1A1A` | Parchment `#E8DCC4` | ~14.2:1 | AAA Pass | American Typewriter Bold 18 px |
| Confirm button label ("Return to Registry") | Parchment `#E8DCC4` | Ink Black `#1A1A1A` | ~14.2:1 | AAA Pass | DIN Bold 18 px |
| Cancel button label ("Continue Mission") | Parchment `#E8DCC4` | BQA Blue `#1B3A6B` | ~10.8:1 | AAA Pass | DIN Bold 18 px |
| Focus indicator border (4 px brightened BQA Blue) | n/a | Card Parchment `#E8DCC4` | ≥3:1 (focus indicator non-text contrast per WCAG SC 1.4.11) | AA Pass | n/a |

**All ratios meet WCAG AAA (≥7:1).** No text element relies on contrast below AA threshold. **Better contrast than new-game-overwrite** because the header band is Ink Black (Parchment text on Ink Black = 14.2:1) instead of PHANTOM Red (Parchment on PHANTOM Red = 5.4:1 — still AA but lower).

### Color-independent communication

The modal communicates destructive-vs-safe action through **4 redundant signals** (`case-file-destructive-button` pattern):

1. **Color**: Ink Black header band + Ink Black Confirm button + BQA Blue Cancel button
2. **Position**: Confirm is left of Cancel (LTR locales); Cancel is right (default focus, safe-action position)
3. **Label text**: "Return to Registry" (action verb + bureaucratic register implies finality) + "Continue Mission" (universally understood safe-action with mission-fiction framing)
4. **Focus indicator**: 4 px BQA Blue brightened border on focused button (initially Cancel)

A color-blind player (deuteranopia, protanopia, tritanopia, or full achromatopsia) can identify the destructive button via position + label + focus state alone — no information is conveyed by color alone. **WCAG SC 1.4.1 Pass** (color-independence).

### Screen reader support

The modal complies with the AccessKit contract per ADR-0004 IG10 [CANONICAL]:

| Node | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| ModalCard root | `ROLE_DIALOG` | `tr("menu.return_registry.stamp")` → "RETURN TO REGISTRY" | (empty — name suffices) | `LIVE_ASSERTIVE` (one-shot on mount, cleared to `LIVE_OFF` next frame via `call_deferred`) per CR-21 |
| HeaderStamp Label | `ROLE_STATIC_TEXT` (or default) | (empty — covered by ModalCard's name) | (empty) | `LIVE_OFF` |
| BodyText Label | `ROLE_STATIC_TEXT` (or default) | `tr("menu.return_registry.body_alt")` → "Unsaved progress lost." | (empty) | `LIVE_OFF` |
| Divider ColorRect | n/a (decorative) | (none) | (none) | n/a |
| ConfirmButton | `ROLE_BUTTON` | `tr("menu.return_registry.confirm")` → "Return to Registry" | `tr("menu.return_registry.confirm.desc")` → "Return to the main menu. Unsaved progress in this section is lost." (NEW STRING) | `LIVE_OFF` |
| CancelButton | `ROLE_BUTTON` | `tr("menu.return_registry.cancel")` → "Continue Mission" | `tr("menu.return_registry.cancel.desc")` → "Resume the operation. Pause Menu remains open." (NEW STRING) | `LIVE_OFF` |
| ModalBackdrop ColorRect | n/a (decorative) | (none) | (none) | n/a |

**Assertive announce on mount**: when modal mounts, the screen reader announces (in scripted order): "Dialog. RETURN TO REGISTRY. Unsaved progress lost. Continue Mission button. Resume the operation. Pause Menu remains open." (or locale-equivalent). The one-shot LIVE_ASSERTIVE is cleared to LIVE_OFF on the next frame via `call_deferred("set", "accessibility_live", AccessibilityLive.LIVE_OFF)` to prevent re-announcement on subsequent state changes within the same modal session.

**Locale-change re-resolve**: on `NOTIFICATION_TRANSLATION_CHANGED`, all `accessibility_name` and `accessibility_description` strings are re-resolved via `_update_accessibility_names()` helper (per `accessibility-name-re-resolve` pattern). Focus is preserved; no re-announcement fires (LIVE_OFF post-mount).

### Motion and animation

**At MVP**: modal appears via hard cut. No tweens. Reduced-motion variant is identical to default. **(NB: this modal ships at VS, not MVP, but the same hard-cut approach is preserved at VS for consistency with siblings.)**

**Post-VS polish candidates** (200 ms backdrop fade-in, focus-shift border slide, hover-fill ramp, stamp slam): all suppressed when `Settings.accessibility.reduced_motion_enabled == true` per CR-23. No animation conveys information that is not redundantly available via static state.

### Photosensitivity

- No flashing colors
- No high-contrast strobe
- No flicker
- No rapid color changes
- All state changes are monotonic opacity ramps (post-VS) or instant cuts (VS baseline)
- WCAG SC 2.3.1 Pass (≤3 flashes per second — modal exhibits 0)

### Cognitive accessibility

- Body copy is **plain language**: "Unsaved progress lost." — declarative, no jargon, no error code
- AccessKit `accessibility_description` for both buttons provides plain-language clarification of the action and consequence (mandatory per `case-file-destructive-button` rule 6)
- Default focus on Cancel (safe action) prevents accidental destructive activation
- Single-press activation — no hold-to-confirm gesture or timed input
- No time pressure — modal stays open indefinitely until player decides
- No multi-step flow within the modal — one decision, two buttons, done
- Cancel label "Continue Mission" is fiction-aware but clear (the bureaucratic register is recognizable; the Cancel semantics are unambiguous via position + focus)

### Motor accessibility

- All hit targets ≥ 280 × 56 px (WCAG SC 2.5.5 — 44×44 minimum, project commits 280×56 for menu buttons; Confirm button may be wider to accommodate longer "Return to Registry" label, ~340 px — well above floor)
- 16 px gap between Confirm and Cancel reduces mis-click risk
- Single-press activation (no chording, no hold)
- No time-limited input (no countdown, no auto-dismiss)
- Backdrop click is a generous Cancel target (full-screen except modal card area = ~1.7 million px²)

### Open accessibility questions

- See **Open Questions** section for unresolved items relating to localization length cap, audio-fade reliability on `change_scene_to_file()`, and the `current_section_id` data flow.

---

## Localization Considerations

### String table (already in `translations/menu.csv` per menu-system.md §C.8)

| String Key | English | Char Count | Estimated FR/DE Expansion (40%) | L212 Cap (25 chars) | Status |
|---|---|---|---|---|---|
| `menu.return_registry.stamp` | RETURN TO REGISTRY | 18 | ~25–30 chars | ≤ 21 | ⚠ Likely fits FR/DE; tight margin (matches "OPEN NEW OPERATION" 18 chars precedent) |
| `menu.return_registry.body_alt` | Unsaved progress lost. | 22 | ~31–35 chars | ≤ 25 | ✓ English under cap; FR/DE may exceed cap → triggers multi-line wrap (alignment switches center → left per [CANONICAL]) |
| `menu.return_registry.confirm` | Return to Registry | 18 | ~25–30 chars | ≤ 21 | ⚠ Confirm button may grow; coord with localization-lead |
| `menu.return_registry.cancel` | Continue Mission | 16 | ~22–26 chars | ≤ 21 | ⚠ Tight margin in FR/DE; may need locale override |

### NEW strings to add (this spec adds these to the string table)

| String Key | English | Notes |
|---|---|---|
| `menu.return_registry.confirm.desc` | Return to the main menu. Unsaved progress in this section is lost. | AccessKit `accessibility_description` for Confirm button. Mirrors the Pause Menu's `Return to Registry` button description (pause-menu.md L671) for consistency; AT users get the same plain-language safety net at both surfaces. ~64 chars; FR/DE expansion ~90 chars. No layout impact (description is screen-reader-only, not rendered visually). |
| `menu.return_registry.cancel.desc` | Resume the operation. Pause Menu remains open. | AccessKit `accessibility_description` for Cancel button. ~46 chars; FR/DE expansion ~64 chars. No layout impact. |

### Layout-critical text constraints

| Element | Width Budget | Behavior on overflow |
|---|---|---|
| **Header stamp** ("RETURN TO REGISTRY" rotated -5°) | ~700 px effective width within 880 px header band (after rotation footprint) | If localized stamp text exceeds this width: **fall back to a smaller font size (DIN Bold 20 px)** rather than truncate. Stamp must remain readable per Pillar 5 dossier register. (Same fallback as new-game-overwrite OQ-NGOM-5.) |
| **Body text** ("Unsaved progress lost.") | ~816 px (card width − 32 px H pad each side) | If localized body exceeds 816 px on a single line: **wrap to 2 lines, switch alignment from center to left** per [CANONICAL alignment rule from quit-confirm.md]. Card height grows to accommodate. No truncation. |
| **Confirm button label** ("Return to Registry") | 280 px button width minimum (button may grow to ~340 px to fit English; minimum 280 px floor for short locales) | If localized label exceeds the grown width: **wrap to 2 lines or use abbreviation per locale-specific override**. Button height grows. **HIGH PRIORITY** for localization-lead — coord during string review. |
| **Cancel button label** ("Continue Mission") | 280 px button width minimum (button may grow to ~310 px to fit English) | Tight margin in FR/DE; may need locale-specific override (e.g., FR "Reprendre la mission" 21 chars / DE "Mission fortsetzen" 18 chars — both fit). |

### Numbers, dates, currencies

None on this modal — body copy is static text only.

### Bidirectional (RTL) support

Not committed at MVP/VS per `design/accessibility-requirements.md`. Post-VS RTL support would mirror button order (Cancel left, Confirm right) per `modal-scaffold` rule 4. Header band would not mirror (full-width band; stamp rotation -5° would mirror to +5°).

### Coordinate with localization-lead

**HIGH PRIORITY items**:
1. **Confirm button width** for "Return to Registry" — at 18 chars in English, may need a button width of ~340 px to fit comfortably. FR/DE expansion (25–30 chars) may push this to ~400 px. Coord on per-locale button-width override or label abbreviation strategy.
2. **2 NEW AccessKit description strings** must be added to `translations/menu.csv` before VS sprint kickoff.
3. **Cancel button label "Continue Mission"** matches quit-confirm's Cancel label. If localization-lead approves a single shared `tr-key` for "Continue Mission" across both modals (instead of two separate keys `menu.quit_confirm.cancel` + `menu.return_registry.cancel`), this could reduce string-table duplication. Currently duplicated for namespacing per CR-4. **Recommendation: keep separate keys** (matches CR-4 namespacing pattern); flag for review only.

---

## Acceptance Criteria

The following criteria are testable by a QA tester without reading any other design document. They form the pass/fail gates for `/story-done`. Each criterion is tagged with story type per `.claude/docs/coding-standards.md` Testing Standards table.

- **AC-RTR-1.1 [Logic] [BLOCKING]** GIVEN Pause Menu is mounted at `Context.PAUSE` AND a section is mid-play, WHEN player activates `ReturnToRegistryButton`, THEN `ModalScaffold.show_modal(ReturnToRegistryContent)` is called within 1 frame, the modal title resolves to `"RETURN TO REGISTRY"` (en-US), default focus lands on the "Continue Mission" Cancel button, and `peek() == Context.MODAL`. Verifies CR-14 modal mount.

- **AC-RTR-1.2 [Logic] [BLOCKING]** GIVEN modal is open, WHEN inspected, THEN modal renders with **Ink Black header band** (NOT PHANTOM Red — distinct from save-failed-dialog and new-game-overwrite). Verifies menu-system.md §C.8 L343 + L1263 register assignment.

- **AC-RTR-2.1 [Integration] [BLOCKING — VS sprint]** GIVEN modal is open with default focus on Cancel, WHEN player presses Tab once, THEN focus moves to Confirm button and the 4 px BQA Blue brightened border renders on Confirm (not Cancel). WHEN player presses Tab again, focus cycles back to Cancel. Verifies CR-24 strict focus trap (note: CR-24 is [VS] sprint scope per menu-system.md L104; this AC is gated to VS sprint, NOT MVP).

- **AC-RTR-2.2 [Integration] [BLOCKING — VS sprint]** GIVEN modal is open, WHEN player presses any combination of Tab + Shift+Tab + D-pad in any sequence, THEN focus NEVER reaches the underlying Pause Menu's buttons. Verifies CR-24 + FP-15 (focus trap is the only allowed exception to "no keyboard traps outside modals").

- **AC-RTR-3.1 [Logic] [BLOCKING]** GIVEN modal is open with default focus on Cancel, WHEN player presses Enter / Space, THEN: (a) A1 typewriter clack sfx fires on UI bus; (b) `set_input_as_handled()` is called; (c) `ModalScaffold.hide_modal()` is called; (d) `Context.MODAL` is popped (`peek() == Context.PAUSE`); (e) Pause Menu button container has `process_input = true`; (f) focus returns to "Return to Registry" button within 1 frame via `call_deferred`. All six within 2 frames of the press. Verifies modal-scaffold dismiss contract + `set-handled-before-pop` discipline.

- **AC-RTR-3.2 [Logic] [BLOCKING]** GIVEN modal is open with default focus on Cancel, WHEN player presses Escape (`ui_cancel`), THEN the same exit path as AC-RTR-3.1 fires (Cancel-equivalent semantics). Verifies `dual-focus-dismiss` pattern.

- **AC-RTR-3.3 [UI] [ADVISORY]** GIVEN modal is open, WHEN player clicks anywhere on the backdrop (outside the 880×200 card), THEN the same Cancel-equivalent exit path fires. Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-RTR-4.1 [Logic] [BLOCKING]** GIVEN modal is open with focus on Confirm, WHEN player presses Enter / Space, THEN in order: (a) A1 typewriter clack + A6 rubber-stamp thud + A8 paper-drop fire on UI bus on the same frame; (b) Confirm button enters `disabled = true` state for at least 1 frame; (c) `set_input_as_handled()` is called; (d) `Context.MODAL` is popped; (e) `Context.PAUSE` is popped; (f) `Context.LOADING` is pushed; (g) `get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")` is called via `call_deferred`. Verifies CR-14 confirm path.

- **AC-RTR-4.2 [Logic] [BLOCKING]** GIVEN AC-RTR-4.1 sequence has executed, WHEN engine completes the scene change, THEN: (a) MainMenu.tscn is loaded fresh; (b) Pause Menu and section trees are destroyed; (c) `peek() == Context.MENU` (LOADING was popped on MainMenu mount); (d) `_boot_warning_pending` is false (already dismissed earlier this session) and no boot warning re-mounts; (e) MainMenu's Continue button has default focus per CR-5. Verifies post-Confirm state.

- **AC-RTR-4.3 [Integration] [ADVISORY]** GIVEN AC-RTR-4.1 sequence has executed, WHEN measured, THEN gameplay music has faded out (Audio's `section_exited` subscription fired during scene destruction). If music cuts hard instead of fading, file as bug; resolution requires verifying `change_scene_to_file()` does not bypass `section_exited` signal emission. (See OQ-RTR-1.)

- **AC-RTR-4.4 [Logic] [BLOCKING]** GIVEN Confirm button is in `disabled = true` state (post-press), WHEN player presses Enter or clicks Confirm again, THEN no second `change_scene_to_file()` call fires (re-entrant guard). Engine-level: even if the call were re-issued, Godot's engine would queue/ignore the second call once the first scene change is in flight, but the modal's button state is the first line of defense.

- **AC-RTR-5.1 [UI] [BLOCKING]** GIVEN modal mounts with screen reader active (e.g., NVDA, JAWS, Orca), WHEN modal appears, THEN screen reader announces (en-US): "Dialog. RETURN TO REGISTRY. Unsaved progress lost. Continue Mission button. Resume the operation. Pause Menu remains open." within 500 ms of mount. Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-RTR-5.2 [UI] [BLOCKING]** GIVEN modal is open with screen reader active and focus on Confirm, WHEN focus lands on Confirm, THEN screen reader announces "Return to Registry, button. Return to the main menu. Unsaved progress in this section is lost." Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-RTR-5.3 [Logic] [BLOCKING]** GIVEN modal mounted with `accessibility_live = LIVE_ASSERTIVE`, WHEN one frame has elapsed, THEN `accessibility_live == LIVE_OFF` (one-shot cleared via `call_deferred`). Verifies CR-21 one-shot assertive contract.

- **AC-RTR-6.1 [Visual] [ADVISORY]** GIVEN modal is rendered at 1920×1080 with English locale, WHEN inspected by eye, THEN: (a) Ink Black header band fills full card width × 50 px; (b) "RETURN TO REGISTRY" stamp text is rotated -5° in DIN Bold 24 px Parchment, left-anchored at 16 px from card left edge; (c) body text "Unsaved progress lost." is center-aligned in American Typewriter Bold 18 px Ink Black; (d) divider is 1 px Ink Black 70%, 816 px wide, centered; (e) Confirm and Cancel buttons are right-anchored with 16 px gap, 32 px right pad. Screenshot evidence filed at `production/qa/evidence/`.

- **AC-RTR-6.2 [Visual] [ADVISORY]** GIVEN modal is rendered with FR locale (longest expected expansion), WHEN inspected, THEN: (a) header stamp does not overflow the band (or falls back to DIN Bold 20 px gracefully per OQ-RTR-2 resolution); (b) body text wraps to at most 2 lines, alignment switches from center to left; (c) button labels do not overflow their per-locale-overridden widths; (d) card height grows to accommodate (no clipping). Screenshot evidence filed at `production/qa/evidence/`.

- **AC-RTR-7.1 [Integration] [BLOCKING — VS sprint]** GIVEN `Settings.accessibility.reduced_motion_enabled == true`, WHEN modal mounts and dismisses, THEN: (a) no appearance tween plays; (b) no focus-shift tween plays; (c) no hover tween plays; (d) no stamp-slam tween plays on Confirm (instant state change); (e) audio cues (A1 clack, A6 thud, A8 modal-appear, music fade) all play at full duration. Verifies CR-23 reduced-motion conditional.

- **AC-RTR-8.1 [Logic] [BLOCKING]** GIVEN locale change occurs (`NOTIFICATION_TRANSLATION_CHANGED` fires) while modal is open, WHEN one frame passes, THEN: (a) HeaderStamp Label text re-resolves to new locale's `menu.return_registry.stamp`; (b) BodyText Label re-resolves; (c) both button labels re-resolve; (d) ConfirmButton.accessibility_name + ConfirmButton.accessibility_description re-resolve; (e) CancelButton.accessibility_name + CancelButton.accessibility_description re-resolve; (f) focus is preserved on whichever button held focus. Verifies `accessibility-name-re-resolve` pattern compliance.

- **AC-RTR-9.1 [Performance] [ADVISORY]** GIVEN modal mount is requested, WHEN measured from `show_modal()` call to first frame fully rendered, THEN ≤ 33 ms (2 frames at 60 fps). Smoke check.

- **AC-RTR-9.2 [Performance] [ADVISORY]** GIVEN Confirm pressed, WHEN measured from press to `change_scene_to_file()` call, THEN ≤ 33 ms (2 frames). Subsequent scene change is engine-controlled; not part of modal scope.

- **AC-RTR-10.1 [Config] [ADVISORY]** GIVEN `translations/menu.csv` on disk, WHEN inspected, THEN every English value for `menu.return_registry.*` matches §C.8 string table exactly, AND the 2 NEW description strings (`menu.return_registry.confirm.desc` + `menu.return_registry.cancel.desc`) are present. Smoke check via `diff` against §C.8 + this spec.

- **AC-RTR-11.1 [Logic] [BLOCKING]** GIVEN modal is open AND OS window loses focus mid-modal, WHEN OS window regains focus (`NOTIFICATION_WM_FOCUS_IN`), THEN `Input.flush_buffered_events()` is called before the first `_unhandled_input` of the refocused frame. Verifies edge-case Cluster G L915 — prevents phantom `ui_cancel` on refocus.

**Minimum 5 criteria categories satisfied**:
- ✓ Performance criterion: AC-RTR-9.1, AC-RTR-9.2
- ✓ Navigation criterion: AC-RTR-3.1, AC-RTR-4.1, AC-RTR-4.2
- ✓ Error/empty/edge state criterion: AC-RTR-11.1 (OS focus loss), AC-RTR-4.4 (re-entrant guard)
- ✓ Accessibility criterion: AC-RTR-2.1, AC-RTR-5.1, AC-RTR-5.2, AC-RTR-7.1
- ✓ Core-purpose criterion: AC-RTR-4.1, AC-RTR-4.2 (the destructive Confirm path is the modal's reason for existing)

**Total**: 21 acceptance criteria across 5 story types (Logic: 13 BLOCKING; Integration: 4 BLOCKING + 1 ADVISORY; UI: 3 mixed; Visual: 2 ADVISORY; Performance: 2 ADVISORY; Config: 1 ADVISORY).

---

## Open Questions

| # | Question | Affects Section | Owner | Recommendation | Resolution Deadline |
|---|---|---|---|---|---|
| **OQ-RTR-1** | **Audio fade reliability on `change_scene_to_file()`.** Per CR-14 + Audio § Mission domain, audio fades on `section_exited` automatically — but `change_scene_to_file()` destroys the scene tree, and the timing of `section_exited` emission relative to scene destruction is unverified. If LS or the section's `_exit_tree()` callback emits `section_exited` BEFORE the engine frees the scene, the audio fade fires correctly. If the engine frees the scene before the signal emission, the music cuts hard. **Coord with audio-director + technical-director.** Verify by adding an `await get_tree().process_frame` between Context.LOADING push and `change_scene_to_file()` call (gives `_exit_tree()` callbacks a frame to fire), or by explicitly emitting `Events.section_exited(...)` in the modal's Confirm path before `change_scene_to_file()`. | Events Fired (architectural concern); Transitions & Animations (audio-paired transitions); Acceptance Criteria (AC-RTR-4.3) | audio-director + technical-director + level-streaming-owner | **Recommended: explicit pre-emit.** The modal's Confirm path emits `Events.section_exited(current_section_id, RETURN_TO_REGISTRY)` BEFORE `change_scene_to_file()`, ensuring Audio's subscriber fires deterministically. Add `RETURN_TO_REGISTRY` to ADR-0002's TransitionReason enum or equivalent if not already present. | Before VS sprint kickoff |
| **OQ-RTR-2** | **Stamp rotation overflow for FR/DE.** "RETURN TO REGISTRY" is 18 chars; FR/DE expansion may produce 25–30 chars. Same risk as new-game-overwrite OQ-NGOM-5. Should the implementation: (a) fall back to DIN Bold 20 px on overflow detection, (b) use a per-locale shorter override, or (c) accept truncation (NOT acceptable per Pillar 5)? | Layout Specification (HeaderStamp); Localization Considerations | art-director + localization-lead | **Recommended: (a) auto-shrink to 20 px on overflow** — same fallback as new-game-overwrite. Truncation is a Pillar 5 refusal. | During localization review |
| **OQ-RTR-3** | **Confirm button width for "Return to Registry" 18-char label.** The button minimum is 280 px (per modal-scaffold spec); to fit "Return to Registry" comfortably at DIN Bold 18 px, the button likely needs ~340 px. FR/DE expansion may push to ~400 px. Should the implementation: (a) auto-grow per locale (preferred), (b) use a fixed wider button (e.g., 380 px) for both Confirm and Cancel for visual consistency, or (c) require a locale-specific abbreviation? | Layout Specification (Confirm button); Localization Considerations | ux-designer + localization-lead | **Recommended: (a) auto-grow per locale.** Modal-scaffold pattern already supports button width as `max(min_width, label_width + 2 * padding)`. Cancel button stays at its natural width (~310 px for "Continue Mission"); Confirm grows to fit. 16 px gap between buttons preserved. | During VS sprint authoring |
| **OQ-RTR-4** | **`current_section_id` data flow for analytics.** Post-MVP analytics events (`menu.return_registry.confirmed` / `.cancelled` / `.shown`) include `section_id` in payload. Where does the modal read `current_section_id` from? Candidates: (a) `LS.current_section_id` (if exposed); (b) `MissionLevelScripting.current_section_id`; (c) Pause Menu's section breadcrumb (the value displayed in Pause's section header label). | Events Fired (analytics payload); Data Requirements | technical-director + level-streaming-owner | **Recommended: read from LS.** Post-MVP scope; not blocking VS sprint. | Defer to post-VS analytics integration |
| **OQ-RTR-5** | **Reduced-motion conditional scope at VS.** Same as new-game-overwrite OQ-NGOM-4: is the conditional **wired but no-op at VS hard-cut baseline** (so post-VS polish tweens can be added without touching the conditional path), or **omitted entirely at VS** (with a TODO to add the conditional when tweens are introduced)? | Transitions & Animations; Accessibility | ux-designer + lead-programmer | **Recommended: WIRED but no-op at VS** — same precedent as new-game-overwrite. Avoids regression risk. | Defer to lead-programmer style guide |
| **OQ-RTR-6** | **Background save during modal verification.** Same as new-game-overwrite OQ-NGOM-3: can a Quicksave (F5) or any background save fire while return-to-registry modal is open? Expected answer: NO (Context.MODAL blocks input + Pause Menu underneath cannot trigger saves while peek is MODAL). Verify via grep gate. | Interaction Map (input gating); States & Variants | engine-programmer + ui-programmer | **Recommended: NO background saves during modal.** Confirm via grep gate: search for any `Events.save_requested` emit-points that don't gate on `peek() in [GAMEPLAY, PAUSE]`. (Note: PAUSE is allowed because manual save from Pause Menu is a legitimate path; modal blocks via `Context.MODAL` push above PAUSE.) | Before VS sprint kickoff |

**No CRITICAL blockers** at the time of this spec — all open questions are scoped to audio-fade reliability (architectural verification), localization timing, polish-phase animation wiring, or post-VS analytics integration. The modal's core canonical decisions (Ink Black header + Case File destructive button + modal-scaffold focus contract + 880×200 baseline + Cancel-default-focus + accessibility tier) are all locked per [CANONICAL] inheritance from `quit-confirm.md` + `interaction-patterns.md` + `menu-system.md` §C.8.

---

## Cross-Reference Summary

**Files this spec depends on** (must remain consistent with these):

- `design/ux/quit-confirm.md` Section C.3 — CANONICAL modal-scaffold reference; this spec inherits scaffold + button contract verbatim (Ink Black header band, 880×200, default focus, button order, audio cues)
- `design/ux/pause-menu.md` §C (Component Inventory L233 — Return to Registry button), §B3 (Entry & Exit), §G (Accessibility AccessKit table L671), §A (Audio cues), §I (Events Fired L453)
- `design/ux/main-menu.md` (post-Confirm landing destination — verify Continue button focus per CR-5)
- `design/ux/interaction-patterns.md` `modal-scaffold`, `case-file-destructive-button`, `dual-focus-dismiss`, `set-handled-before-pop`, `accessibility-name-re-resolve`, `auto-translate-always`
- `design/gdd/menu-system.md` CR-2 (InputContext push/pop), **CR-14** (Return to Registry confirm modal — primary source), CR-21 (one-shot assertive), CR-23 (reduced-motion conditional), CR-24 (modal focus trap [VS]), §C.8 (string table L343-346), §A.1–A.2 (audio cues), Cluster F edge-case L901 (focus restore validity), Cluster G edge-case L915 (OS focus loss flush)
- `design/gdd/level-streaming.md` CR-7 (MainMenu is not a section — `change_scene_to_file` for return path)
- `design/art/art-bible.md` §3.3 (palette), §4 (Parchment fills), §7B (typography), §7D (Case File register stamp rotation)
- `design/accessibility-requirements.md` Standard tier commitment
- `docs/architecture/ADR-0004-ui-framework.md` IG6 (Theme), IG7 (CanvasLayer 1024 modals), IG10 (AccessKit Day-1)
- `docs/architecture/ADR-0007-autoload-registry.md` (Settings autoload position)

**Files that should later cross-link to this spec**:
- `design/ux/pause-menu.md` — should add a "see `return-to-registry.md`" link in §C (Component Inventory L233 Return to Registry row), §B3 (Entry & Exit L119), §I (Events Fired L453). **Action: edit on /ux-review approval.**
- `design/gdd/menu-system.md` CR-14 — should add a "UX spec: `design/ux/return-to-registry.md`" cross-reference. **Action: edit on /ux-review approval.**
- `design/ux/main-menu.md` — should note that the Continue button is the focus target on post-Confirm MainMenu landing. **Action: verify on /ux-review.**
- `design/ux/interaction-patterns.md` — `modal-scaffold` and `case-file-destructive-button` "Used In" lists already include "Return-to-Registry" — verify on /ux-review.
- `design/gdd/level-streaming.md` — verify that CR-7 + the section's `_exit_tree()` callback chain emits `section_exited` reliably before scene destruction (per OQ-RTR-1).
- `design/gdd/audio.md` § Mission domain — verify that `section_exited` subscription handles RETURN_TO_REGISTRY reason correctly (per OQ-RTR-1).

---

## Verdict

**COMPLETE** — UX spec written and section-by-section content authored per `quit-confirm.md` [CANONICAL] sibling inheritance + menu-system.md CR-14 + §C.8 string table + `case-file-destructive-button` pattern + `modal-scaffold` pattern. Spec is ready for `/ux-review`.

---

## Recommended Next Steps

1. **Run `/ux-review return-to-registry`** — validate this spec before it enters the implementation pipeline. The Pre-Production gate requires all key screen specs to have a review verdict.
2. **Resolve OQ-RTR-1 (audio fade reliability)** before VS sprint kickoff — this is the only OQ with architectural implications.
3. **Add 2 NEW localization strings** to `translations/menu.csv`: `menu.return_registry.confirm.desc` + `menu.return_registry.cancel.desc`. Coord with localization-lead.
4. **Cross-link** pause-menu.md, menu-system.md (CR-14), and audio.md to this spec on /ux-review approval.
5. **`/ux-design re-brief-operation`** — final Case File destructive sibling modal in the family. Same canonical inheritance stack; Pause-Menu-mounted; estimated ~50% faster authoring given the precedent.
6. **`/gate-check pre-production`** once all 5 modal-scaffold sibling specs are reviewed (quit-confirm DONE, save-failed-dialog DONE, new-game-overwrite COMPLETE pending review, return-to-registry COMPLETE pending review, re-brief-operation pending authoring).
