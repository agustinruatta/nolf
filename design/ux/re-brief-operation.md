# UX Spec: Re-Brief Operation Confirm Modal

> **Status**: In Design
> **Author**: ux-designer + user
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: P3 In-Mission → P3.5 Mission-Pause (mid-mission, post-checkpoint, player has paused and is considering a checkpoint reload — typically after a botched stealth attempt or a hard combat failure they want to retry from a known-good state) → on Confirm: P3 In-Mission resumes from checkpoint snapshot; on Cancel: P3.5 Mission-Pause restored
> **Template**: UX Spec
> **Sprint Scope**: **[VS conditional]** (Vertical Slice — NOT MVP per menu-system.md CR-13). At MVP the trigger button is HIDDEN because mid-section checkpoints are not implemented. At VS, trigger button visibility depends on `FailureRespawn.has_checkpoint() == true` (per CR-13). Whether the modal ships at VS at all is conditional on Tier 0 Plaza playtest evidence per `pause-menu.md` OQ-PM-1 + F&R OQ-FR-11 (>30% quit-to-Load frequency required to ship Re-Brief at VS; otherwise deferred to Polish).
> **Register**: **Pure Case File register** — Ink Black `#1A1A1A` header band (NOT PHANTOM Red destructive register). Sibling of `quit-confirm.md` and `return-to-registry.md` per the 4-modal [CANONICAL] inheritance from `quit-confirm.md` Section C.3 + the `case-file-destructive-button` pattern in `interaction-patterns.md`.
> **Pattern Inheritance**: `quit-confirm.md` (CANONICAL Case File modal-scaffold reference) — re-brief-operation inherits the modal scaffold + button chrome + focus contract + accessibility patterns + Ink Black header band verbatim; this spec only documents what differs (trigger context is Pause Menu's conditional Re-Brief button rather than Main Menu Quit; destructive payload is `FailureRespawn.restart_from_checkpoint()` rather than `quit()`; body copy is **interrogative** rather than declarative — see Section A; Confirm label "Re-Brief" is 8 chars, far shorter than siblings).

---

## Purpose & Player Need

The Re-Brief Operation Confirm Modal is a destructive-action guard that prevents a paused player from accidentally reloading their checkpoint when they activate the "Re-Brief Operation" button on the Pause Menu. It is the deliberate friction layer between *intent to reload from the last checkpoint* and *destruction of in-memory progress made since that checkpoint*.

The player's goal at this surface is one of two:
1. **Confirm intent to reload from checkpoint** — they have just made a recoverable mistake (botched a stealth approach, walked into a guard's cone, missed an objective trigger) and want to retry from a known-good state without the friction of a manual save/load round-trip. Confirm path → `FailureRespawn.restart_from_checkpoint()`.
2. **Recover from a misclick** — they pressed Re-Brief Operation without realizing it would erase their progress since the last checkpoint; they need a clean way back to the Pause Menu (Cancel path → `ModalScaffold.hide_modal()` → focus restored to the originating button on Pause Menu).

**Why this screen exists** (the failure mode it prevents): without this guard, a paused player who clicks "Re-Brief Operation" — perhaps thinking it would simply re-display the mission briefing card (the verb "re-brief" is genuinely ambiguous in player vocabulary, especially for first-time players who may not realize this is the project's bureaucratic-register name for "Restart from Checkpoint") — would silently destroy their progress since the last checkpoint. Per F&R + pause-menu.md L483, `restart_from_checkpoint()` "reverts in-memory section state to last checkpoint snapshot" — the player's exact position, ammo state, completed objectives this checkpoint, dialogue beats since checkpoint, alert states, and pickup states all reset to the checkpoint's recorded state.

The destructive nature is **volatile and partial**: no save data is destroyed (slot 0 autosave is intact, manual saves are intact), AND the checkpoint state itself is preserved (the player can re-brief again later from the same checkpoint). The destructive consequence is in-memory state since the most recent checkpoint only — typically a small slice of gameplay (~1–5 minutes for a tight stealth section).

The player arrives at this modal wanting to **decide**, not to read or browse. The screen's job is to make the decision unambiguous (what will be lost — the in-memory progress since the checkpoint; what will be preserved — the checkpoint snapshot) and instant (one keypress to confirm, one to cancel, default focus on the safe action).

**Note on body copy register**: this modal is the only one in the modal-scaffold sibling family that uses an **interrogative** body ("Reload last checkpoint?") rather than a declarative consequence statement (siblings use "Operation abandoned." / "Unsaved progress lost." / "Autosave will be overwritten."). The interrogative form is intentional: re-brief is the only modal where the destructive action is also a *recovery* action — the player is actively choosing to undo their recent gameplay to recover from a mistake, not committing to a loss. The question form mirrors the player's framing ("do I want to reload?") rather than warning them of damage. This is locked in menu-system.md §C.8 L348.

---

## Player Context on Arrival

**When does a player first encounter this screen?**

The Player encounters the Re-Brief Operation modal in exactly one context: while the **Pause Menu is open mid-mission**, the player has reached at least one in-section checkpoint (so `FailureRespawn.has_checkpoint() == true` and the Re-Brief button is visible), AND the player has activated the "Re-Brief Operation" button. Cold boot, Main Menu, gameplay-time without Pause, and pre-first-checkpoint Pause Menu states cannot reach this modal.

The Pause Menu reaches this modal via:
- Mid-section gameplay → `ui_cancel` (Esc / Gamepad B) at top level → Pause Menu mounts at `Context.PAUSE`
- Pause Menu queries `FailureRespawn.has_checkpoint()` (synchronous, at `_ready()`) — if `true`, Re-Brief Operation button is visible in the button stack; if `false`, the button is **absent** (not disabled — fully removed from focus order per `pause-menu.md` AC-PAUSE-10.1)
- Player navigates to the Re-Brief button (Tab cycle in the Pause button stack: Resume → File Dispatch → Operations Archive → Personnel File → **Re-Brief** → Return to Registry → Close File)
- Player activates Re-Brief → this modal opens

**Two emotional-state contexts on arrival**:

1. **Recovery from failure** (the primary use case): The player has just botched something — got spotted during a stealth approach, walked into a guard's vision cone, fell off a ledge, fired a wasted dart, missed a critical interaction. They are paused, frustrated, and want a clean retry without the mental tax of a manual save/load round-trip. Emotional state: **mildly frustrated, decisive, wanting to get back to gameplay quickly** — the modal's body copy ("Reload last checkpoint?") meets them where they are with a question that mirrors their framing.

2. **Misclick recovery / vocabulary confusion** (less common but high-stakes): The player has accidentally activated Re-Brief Operation, possibly because they read "Re-Brief" as "review the mission briefing" rather than "restart from checkpoint" (this is a real period-authenticity tension — the bureaucratic register is correct but the verb is ambiguous to first-time players). Emotional state: **uncertain, hopeful for clarification** — the modal's body copy + Confirm-button-label + Cancel-default-focus together communicate "this is a destructive reload, not a briefing re-display," and the player can back out.

In either case, the player is NOT in a time-pressured context. The mission is paused; nothing burns down. The modal can afford considered input.

**What were they just doing?**

- Active mid-section gameplay (in P3 — pursuing a stealth objective, observing patrols, navigating geometry, attempting a tricky interaction).
- Encountered a setback or made a deliberate decision to retry (botched stealth, missed objective, failed timing, etc.).
- Pressed Esc → Pause Menu opened, mission state frozen.
- Tabbed to the Re-Brief Operation button (visible because at least one checkpoint has fired in this section).
- Activated Re-Brief.

**Voluntary or involuntary arrival?**

Always **voluntary** — the player explicitly activated a button. The modal is a deliberate friction layer, not a redirect. The player can always cancel and restore their original Pause Menu state with no side effects.

---

## Navigation Position

This screen lives at:

```
[In-Mission Gameplay (post-checkpoint)] → [Pause Menu (Re-Brief visible)] → [Re-Brief Operation Modal]
                                                                            ↳ on Confirm: FailureRespawn.restart_from_checkpoint()
                                                                                          → [In-Mission Gameplay (reset to checkpoint)]
                                                                            ↳ on Cancel:  → [Pause Menu] (focus restored)
```

The modal is a **non-replacing overlay** mounted by `ModalScaffold` as a child of the Pause Menu (per menu-system.md L126: "ModalScaffold child of PauseMenu"). It sits at CanvasLayer 1024 (per ADR-0004 IG7 — modals layer above Pause Menu's CanvasLayer). The Pause Menu remains visible underneath the 52% Ink Black backdrop dim, but its input is gated by `Context.MODAL` push.

**Alternate entry paths**: NONE. The modal is **only** reachable from the Pause Menu's "Re-Brief Operation" button, AND only when that button is visible (i.e., post-first-checkpoint in the current section). It cannot be reached from:
- Main Menu (Re-Brief is a Pause-only concept; no checkpoint state on Main Menu)
- Mid-gameplay without Pause (no in-section path opens this modal)
- Any other Pause Menu button (each Pause button has its own destructive confirm or no confirm)
- Pre-first-checkpoint Pause sessions (the Re-Brief button does not exist in the button stack; it is removed from focus order entirely per AC-PAUSE-10.1)

**Context dependency**: this screen is **doubly context-dependent** — it requires both `Context.PAUSE` to be active (i.e., a section is mid-play and Pause Menu is open) AND `FailureRespawn.has_checkpoint() == true` (i.e., at least one in-section checkpoint has fired).

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Pause Menu — `ReBriefButton.pressed` | Player activates "Re-Brief Operation" button while Pause Menu is open at `Context.PAUSE` AND the button is visible (i.e., `FailureRespawn.has_checkpoint() == true` at Pause `_ready()` time) | Section is mid-play; Pause Menu is mounted; in-memory section state is frozen but intact; at least one checkpoint has fired in this section; the checkpoint snapshot exists in F&R's authoritative state. The originating button reference is passed to `ModalScaffold.show_modal()` as `return_focus_node`. |

**No other entry path exists.** The modal cannot be summoned from:
- Main Menu (uses `quit-confirm.md` and `new-game-overwrite.md`)
- Mid-gameplay without Pause Menu
- Pause Menu when `FailureRespawn.has_checkpoint() == false` (button is absent from focus order entirely)
- Save Game Screen, Load Game Screen, Operations Archive, Personnel File, or any other sub-screen
- Quicksave / Quickload triggers
- Any auto-failure scripted path (those route through F&R's death pipeline directly, not through this modal)

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| **In-Mission Gameplay (reset to checkpoint)** | Confirm button pressed (Enter / Space / `ui_accept` while focused, OR mouse click on "Re-Brief" button) | **Destructive — irreversible from this modal's perspective.** Sequence: (1) `set_input_as_handled()`; (2) pop `Context.MODAL`; (3) call `FailureRespawn.restart_from_checkpoint()` directly (an autoload API call, not a signal emission). F&R owns the subsequent flow: it calls `LS.reload_current_section(save)` with the checkpoint snapshot; LS step-9 callback restores section state; F&R applies anti-farm respawn floor logic per CR-5/CR-6/CR-7 (the floor is NOT applied on a player-initiated re-brief because no death occurred — see OQ-RBO-2). Pause Menu is destroyed by LS reload; section trees are reloaded; player resumes at the checkpoint's `player_respawn_point` Marker3D. |
| **Pause Menu (focus restored)** | Cancel button pressed (Enter / Space / `ui_accept` while focused, OR mouse click on "Continue Mission" button) | Non-destructive. `set_input_as_handled()` → `ModalScaffold.hide_modal()` pops `Context.MODAL` → Pause Menu input restored (button container `process_input = true`) → focus returned to the originating "Re-Brief Operation" button on Pause Menu via `is_instance_valid()` + `call_deferred("grab_focus")` (per menu-system.md Cluster F edge-case L901 — modal MUST validate before focusing). Pause Menu's prior state (which button last held focus, the section breadcrumb, the visible button stack including Re-Brief) is preserved. |
| **Pause Menu (focus restored)** | `ui_cancel` (Esc / Gamepad B) from anywhere within the modal | Equivalent to Cancel button press. Non-destructive. Same exit path. |
| **Pause Menu (focus restored)** | Mouse click on backdrop (outside modal card) | Equivalent to Cancel button press per `dual-focus-dismiss` pattern. Non-destructive. Same exit path. |

**Irreversibility note**: the Confirm path is **one-way from this modal's perspective**. Once `FailureRespawn.restart_from_checkpoint()` is called, the in-memory section state since the checkpoint is gone — the player cannot return to their pre-confirm state. The modal's Cancel-default-focus is the project's commitment to motor-accessibility safety.

**Save data is NOT destroyed** by this confirm path. **Checkpoint state itself is also preserved** — the player can re-brief again later from the same checkpoint if they fail again. This is a key distinction from `return-to-registry.md` (which destroys ALL in-section progress) and `new-game-overwrite.md` (which destroys persistent slot 0 data). Re-brief is a **partial volatile reset** — the smallest destructive scope of any modal in the family.

**Anti-farm interaction**: per F&R CR-5/CR-7, the respawn ammo floor (which applies on the first death per checkpoint) is gated on `_floor_applied_this_checkpoint`. A player-initiated re-brief is NOT a death — it does NOT trigger the floor (per CR-5: floor applies "first death of this checkpoint"). However, F&R's CR-7 IDLE-guard logic for `section_entered` may need verification on the re-brief path. **OQ-RBO-2** flags this for F&R coord.

---

## Layout Specification

### Information Hierarchy

The modal must communicate four pieces of information in a deliberate order, identical to its quit-confirm + return-to-registry siblings (with body copy register difference):

1. **Most critical** (eye lands here first within the first 200 ms of modal mount): **Modal identity / what is at stake** — communicated by the Ink Black `#1A1A1A` header band with the stamp text "RE-BRIEF OPERATION" rotated -5° in Parchment per the Case File register (art-bible §7D). The Ink Black band signals "Case File destructive register."
2. **Second**: **The decision question** — the body text "Reload last checkpoint?" in American Typewriter Bold 18 px Ink Black, center-aligned. **Interrogative**, not declarative — see Section A note. Single short question.
3. **Third**: **The two action choices** — Confirm (Ink Black destructive register, "Re-Brief") and Cancel (BQA Blue safe register, "Continue Mission"). Default focus on Cancel. Buttons are right-aligned at the card bottom, with 16 px gap and a 1 px ruled divider above.
4. **Discoverable / not visible at rest**: the Pause Menu underneath remains visible through the 52% Ink Black backdrop dim — the player can see the broader Pause context (their button stack with Re-Brief Operation visible, the section name) but cannot interact until the modal is dismissed.

### Layout Zones

The modal card uses a five-zone vertical stack, inheriting the `880 × 200 px` baseline geometry from `quit-confirm.md` Section C.3 [CANONICAL]:

```
┌─────────────────────────────────────────────────────────────┐
│  Z1 — Ink Black header band (50 px tall, full card width)   │  ← Case File destructive identity
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Z2 — Body text region (~80 px tall, centered vertically)   │  ← decision question
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
| **Z2 — Body text region** | Single-line interrogative question | `880 × ~80 px` (height grows for localized variants — see Localization Considerations) | 32 px H pad inside card edges; vertical center between header and divider |
| **Z3 — Divider** | 1 px Ink Black 70% rule, full card width minus 32 px H pad each side | `816 × 1 px` | Centered horizontally; 8 px above button row |
| **Z4 — Button row** | Two buttons right-aligned with 16 px gap | `880 × ~70 px` | 32 px H pad inside card right edge; 32 px bottom pad |
| **Z5 — Backdrop** | Full-screen Ink Black 52% dim behind modal card, over Pause Menu | `1920 × 1080 px` (full-screen) | n/a — covers entire viewport including Pause Menu folder |

**Card position on screen**: Centered horizontally and vertically on the viewport at native 1920×1080. At other resolutions, the card maintains its 880×200 px size (no scaling) and remains centered.

### Component Inventory

| Zone | Component | Type | Properties | Interactive | Pattern Reference |
|---|---|---|---|---|---|
| Z5 | `ModalBackdrop` | `ColorRect` (full-screen) | Ink Black `#1A1A1A` at 52% alpha | **Yes** — mouse-click-anywhere-on-backdrop dismisses modal with Cancel semantics (`dual-focus-dismiss` pattern) | `modal-scaffold` (backdrop contract) |
| — | `ModalCard` | `PanelContainer` w/ `StyleBoxFlat` | `880 × 200 px` baseline; Parchment `#E8DCC4` fill; 2 px Ink Black `#1A1A1A` hard-edge border; 0 px corner radius; no drop shadow (Pillar 5 refusal) | No (root container) | `modal-scaffold` (card contract) |
| Z1 | `HeaderBand` | `ColorRect` (or `PanelContainer` w/ `StyleBoxFlat`) | **Ink Black `#1A1A1A` fill**; full card width × 50 px; no border; 0 px corner radius | No | inherited from `quit-confirm.md` C.3 |
| Z1 | `HeaderStamp` | `Label` | Futura/DIN Bold 24 px Parchment `#E8DCC4`; left-aligned, 16 px left margin within band; vertically centered in band; **rotated -5°** per art-bible §7D Case File register; text = `tr("menu.rebrief.stamp")` → `RE-BRIEF OPERATION` | No (text-only label) | `case-file-stamp-rotation` (inherited from quit-confirm.md C.3) |
| Z2 | `BodyText` | `Label` | American Typewriter Bold 18 px Ink Black `#1A1A1A`; **center-aligned for single-line**, left-aligned for multi-line localized variants ([CANONICAL alignment rule from quit-confirm]); text = `tr("menu.rebrief.body_alt")` → `Reload last checkpoint?` (**interrogative** — see Section A) | No (text-only) | `auto-translate-always` + `accessibility-name-re-resolve` |
| Z3 | `Divider` | `ColorRect` (1 px tall) | Ink Black `#1A1A1A` at 70% alpha; full card width minus 32 px H pad each side (= 816 px wide); centered horizontally; 8 px above button row | No | inherited from quit-confirm.md C.3 |
| Z4 | `ConfirmButton` (destructive) | `Button` w/ `StyleBoxFlat` | **Ink Black `#1A1A1A` fill + Parchment text** per `case-file-destructive-button` pattern; `280 × 56 px` minimum hit target (WCAG SC 2.5.5); DIN 1451 Bold 18 px Parchment `#E8DCC4` text; 0 px corner radius; positioned **left of Cancel** in button row right-anchor; label = `tr("menu.rebrief.confirm")` → `Re-Brief` (8 chars — shortest Confirm label of the family; button stays at 280 px floor, no auto-grow) | **Yes** — `ui_accept` activates destructive path | `case-file-destructive-button` + `modal-scaffold` button contract |
| Z4 | `CancelButton` (safe, default focus) | `Button` w/ `StyleBoxFlat` | **BQA Blue `#1B3A6B` fill + Parchment text** per `modal-scaffold` safe-action contract; `280 × 56 px` minimum hit target (auto-grows to ~310 px to fit "Continue Mission"); DIN 1451 Bold 18 px Parchment `#E8DCC4` text; 0 px corner radius; positioned **right of Confirm** at card right edge minus 32 px pad; label = `tr("menu.rebrief.cancel")` → `Continue Mission`; **default focus on mount** with 4 px BQA Blue brightened border on focus | **Yes** — `ui_accept` activates safe path; `ui_cancel` from anywhere also triggers this path | `modal-scaffold` (default-focus-on-safe-action) |

**Component count**: 8 nodes (1 backdrop + 1 card + 2 in header + 1 body + 1 divider + 2 buttons). Identical structure to all sibling modals.

### ASCII Wireframe

#### Default state (modal mounted, default focus on Cancel)

```
╔═══════════════════════════════════════════════════════════════════════╗
║ █████████████████████████████████████████████████████████████████████ ║  ← Z1: Ink Black header band (50 px)
║ █  RE-BRIEF OPERATION  ◆──── (rotated -5° stamp) ────────────────── █ ║     Stamp: DIN Bold 24 px Parchment, rotated -5°
║ █████████████████████████████████████████████████████████████████████ ║
║                                                                       ║
║                                                                       ║
║                    Reload last checkpoint?                            ║  ← Z2: body text, AT Bold 18 px, center-aligned, INTERROGATIVE
║                                                                       ║
║                                                                       ║
║       ─────────────────────────────────────────────────────           ║  ← Z3: 1 px divider, 70% Ink Black
║                                                                       ║
║                                  ┌──────────┐ ┌──────────────────┐    ║  ← Z4: button row, right-anchored
║                                  │ Re-Brief │ │ Continue Mission ⬛│    ║     Confirm: Ink Black fill, Parchment text (compact 280 px)
║                                  └──────────┘ └──────────────────┘    ║     Cancel: BQA Blue fill, Parchment text + 4 px border (focused)
║                                                                       ║     16 px gap, 32 px right pad
╚═══════════════════════════════════════════════════════════════════════╝
                                ↑ 880 × 200 px card, centered on viewport
                                ↑ Backdrop: full-screen Ink Black 52% dim over Pause Menu
                                ↑ Pause Menu folder visible underneath dim (button stack with Re-Brief, section breadcrumb)
```

#### Focus shifted to Confirm (Tab pressed once from default)

```
╔═══════════════════════════════════════════════════════════════════════╗
║ █████████████████████████████████████████████████████████████████████ ║
║ █  RE-BRIEF OPERATION  ◆──── (rotated -5° stamp) ────────────────── █ ║
║ █████████████████████████████████████████████████████████████████████ ║
║                                                                       ║
║                                                                       ║
║                    Reload last checkpoint?                            ║
║                                                                       ║
║                                                                       ║
║       ─────────────────────────────────────────────────────           ║
║                                                                       ║
║                                  ┌══════════┐ ┌──────────────────┐    ║  ← Confirm: 4 px BQA Blue border = focus indicator
║                                  ║ Re-Brief ║ │ Continue Mission │    ║     Cancel: no border = unfocused
║                                  └══════════┘ └──────────────────┘    ║     Tab cycle: Cancel → Confirm → Cancel (focus trap)
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
                                ↑ Tab from Cancel cycles to Confirm; Shift+Tab cycles back
                                ↑ Focus never escapes modal (CR-24 strict focus trap)
```

**Wireframe notes**:
- Card outline `╔═╗ ║ ╚═╝` represents the 2 px Ink Black hard-edge border.
- Ink Black header band is full card width (no inset) — IDENTICAL to quit-confirm + return-to-registry; distinct from new-game-overwrite which uses PHANTOM Red.
- Stamp text "RE-BRIEF OPERATION" is rotated -5° per Case File register inheritance.
- Button widths: Confirm "Re-Brief" stays at 280 px floor (compact); Cancel "Continue Mission" auto-grows to ~310 px. Asymmetric widths are intentional and visually distinctive — the destructive action being shorter signals it as the more focused, intentional choice.
- Default focus on Cancel via 4 px BQA Blue brightened border.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default** | `ModalScaffold.show_modal(ReBriefContent)` called from Pause Menu after `ReBriefButton.pressed` | Modal appears at full position (hard cut at MVP — see Transitions); Cancel button has default focus with 4 px BQA Blue brightened border; `accessibility_live = LIVE_ASSERTIVE` one-shot fires; A1 typewriter clack sfx + A8 paper-drop sfx play on UI bus per pause-menu.md L407. |
| **Focus on Confirm** | Tab pressed once from default (or Shift+Tab from Cancel) | Confirm button gains 4 px BQA Blue brightened border; Cancel border returns to unfocused state. No sfx. |
| **Confirm-in-flight** | Confirm button pressed; `FailureRespawn.restart_from_checkpoint()` is being called this frame | Confirm button `disabled = true` for 1 frame (prevents double-activation); A1 clack + A6 rubber-stamp thud both fire on the same frame; modal does NOT call `hide_modal()` directly — sequence: `set_input_as_handled()` → pop `Context.MODAL` → call `FailureRespawn.restart_from_checkpoint()`. F&R owns the subsequent transition (LS reload current section per F&R CR-1 step 6); modal vanishes with Pause Menu and section trees as F&R's reload destroys them. |
| **Cancel-in-flight** | Cancel button pressed OR `ui_cancel` pressed OR mouse click on backdrop | A1 clack sfx (cancel-feel, no thud); `set_input_as_handled()` → `ModalScaffold.hide_modal()` → pop `Context.MODAL` → Pause Menu button container `process_input = true` restored → focus returned to "Re-Brief Operation" button via `is_instance_valid()` + `call_deferred("grab_focus")`. |
| **Reduced-motion variant** | `Settings.accessibility.reduced_motion_enabled == true` at `_ready()` | Any appearance tween is suppressed; modal appears at full position via hard cut. A1 clack + A8 paper-drop sfx still play at full duration. The `accessibility_live = LIVE_ASSERTIVE` one-shot still fires. (At MVP, the modal is already hard-cut — this state is identical to default at MVP, but the conditional is wired for VS+ tweens per CR-23.) |
| **Localized variant — long body text** | Body text exceeds `880 − 64 = 816 px` width at given font size in given locale (FR/DE expansion of "Reload last checkpoint?") | Body region grows vertically; alignment switches from center to left per [CANONICAL alignment rule]. Card height grows from 200 px baseline to whatever is needed. Header band height stays at 50 px; button row stays at 70 px. Card remains centered on viewport. |
| **Loading state** | N/A — justified absence | The modal does not fetch async data; all data resolved at mount via `tr()` and Theme inheritance. No loading state needed. |
| **Error state** | N/A — justified absence | The modal cannot fail independently. `FailureRespawn.restart_from_checkpoint()` failures (e.g., `_current_checkpoint == null` somehow despite the upstream `has_checkpoint()` query returning `true`) are F&R's responsibility — F&R should treat this as an internal invariant failure and either no-op gracefully or push_error per F&R's edge-case handling. The modal has no error variant. |
| **Locale-change-triggered re-resolve** | `NOTIFICATION_TRANSLATION_CHANGED` fires while modal is open | Header stamp text, body text, both button labels, and AccessKit `accessibility_name` + `accessibility_description` re-resolve via `_update_accessibility_names()` helper. Card geometry recomputes. Focus is preserved. |
| **Backdrop fade-in** (post-MVP, currently MVP hard-cut) | If the project later adds a 200 ms backdrop fade-in (per pause-menu.md L555 modal-appear precedent), this state covers the in-flight tween | Backdrop opacity ramps 0 → 52% over 200 ms; card appears at full position immediately; button input disabled until backdrop reaches 52%. **Reduced-motion variant suppresses** — backdrop appears at 52% instantly. |
| **Stamp slam variant** (post-VS polish) | Confirm pressed; pause-menu.md L565 specifies a "Stamp slam" animation for destructive confirms | The rubber-stamp visual animates a 1-frame downward slam on Confirm press (~80 ms); A6 thud audio plays in sync. **Reduced-motion variant suppresses** the slam animation; A6 thud still plays. |
| **OS window focus loss** (edge case) | OS window loses focus while modal is open (e.g., player Alt-Tabs to another app) | Modal stays visible and non-responsive to OS-level events. On `NOTIFICATION_WM_FOCUS_IN`, `Input.flush_buffered_events()` is called before the first `_unhandled_input` of the refocused frame (per menu-system.md Cluster G L915). Prevents phantom `ui_cancel` on refocus. |

**No "in-progress" indicator state**: there is no spinner, no progress bar, no "Reloading checkpoint..." copy. The Confirm button's `disabled = true` is the only in-flight signal, and it is gone within 1–2 frames as F&R's reload pipeline takes over.

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse + Gamepad** (per `technical-preferences.md` §Input & Platform — Primary: Keyboard/Mouse; Gamepad: Partial coverage for menu navigation).

| Player Action | Input — Keyboard | Input — Mouse | Input — Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **Activate default-focused button (Cancel "Continue Mission")** | Enter / Space | Click on "Continue Mission" button | A button (`ui_accept`) | A1 typewriter clack (60–80 ms, UI bus); button visual press-state (1 frame) | `set_input_as_handled()` → `ModalScaffold.hide_modal()` → pop `Context.MODAL` → Pause Menu input restored → focus to originating button. **Non-destructive.** |
| **Cycle focus to Confirm** | Tab | n/a (mouse uses hover) | D-pad Right OR D-pad Down (focus_neighbor) | 4 px BQA Blue brightened border moves from Cancel to Confirm; A1 typewriter clack at low volume (40–60 ms) | Focus indicator on Confirm; Cancel returns to unfocused state. |
| **Cycle focus back to Cancel** | Shift+Tab | n/a | D-pad Left OR D-pad Up | Same as above (border moves back to Cancel) | Focus indicator returns to Cancel. |
| **Activate Confirm "Re-Brief" (destructive)** | Enter / Space (when Confirm focused) | Click on "Re-Brief" button | A button (`ui_accept`, when Confirm focused) | A1 typewriter clack + A6 rubber-stamp thud (90–110 ms — destructive register, both on UI bus, fired same frame); Confirm button `disabled = true` for 1 frame | `set_input_as_handled()` → pop `Context.MODAL` → call `FailureRespawn.restart_from_checkpoint()` directly. F&R owns the subsequent flow (LS.reload_current_section + step-9 callback). Modal + Pause Menu + section trees destroyed by LS reload within 1–2 frames. **DESTRUCTIVE — IRREVERSIBLE in-memory progress since checkpoint.** |
| **Dismiss with Esc / Cancel** | Escape | Click on backdrop (anywhere outside modal card) | B button (`ui_cancel`) | A1 typewriter clack (cancel-feel, 60–80 ms, UI bus); no thud | Equivalent to Cancel button activation. |
| **Hover Confirm (mouse only)** | n/a | Move mouse over "Re-Brief" button | n/a | Hover state: 1 px brightened Ink Black fill (or 5% opacity Parchment overlay); cursor changes to pointer | No state change; pure visual affordance. |
| **Hover Cancel (mouse only)** | n/a | Move mouse over "Continue Mission" button | n/a | Hover state: 5% brightened BQA Blue fill; cursor changes to pointer | No state change; pure visual affordance. |

**Focus trap contract** (CR-24 — strict, mandatory at VS sprint scope):
- Tab from Cancel → cycles to Confirm
- Tab from Confirm → cycles back to Cancel
- Shift+Tab cycle behavior mirrored
- D-pad Up/Down/Left/Right on gamepad mirror Tab/Shift+Tab cycle via `focus_neighbor_*` properties
- **No Tab/D-pad input can ever reach the underlying Pause Menu while the modal is open.** (FP-15 + CR-24.)

**Input gating during modal open**:
- Pause Menu button container: `process_input = false` (set when modal mounted; restored when modal dismissed via Cancel)
- `Context.MODAL` is at `peek()` of `InputContext` stack; all non-modal input handlers gate on this
- Quicksave (F5) / Quickload (F9): blocked by `Context.MODAL`
- Pause toggle (Esc / Start): cannot toggle Pause from `Context.MODAL`; Esc routes to `ui_cancel` → Cancel exit instead
- All gameplay input: blocked by both `Context.PAUSE` AND `Context.MODAL`

**`set_input_as_handled()` discipline** (per `set-handled-before-pop` pattern): both Confirm and Cancel exit paths MUST call `set_input_as_handled()` BEFORE the first `InputContext.pop()`.

---

## Events Fired

This modal is a **consumer**, not a publisher. It does NOT emit `Events.*` signals. It calls service APIs directly (`FailureRespawn.restart_from_checkpoint()`, `ModalScaffold.hide_modal()`).

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Modal mounted (entry) | none — modal mount is internal to ModalScaffold | (Modal mount is observable via `ModalScaffold.modal_shown` if the scaffold publishes it; this is not a Menu-level event.) |
| Confirm pressed | `FailureRespawn.restart_from_checkpoint()` (an autoload method call, not a signal) — and downstream, **F&R itself emits** `Events.respawn_triggered(section_id)` as part of its reload flow (per F&R GDD L11 — F&R is the sole publisher of the Failure/Respawn signal domain per ADR-0002:183). LS subsequently emits `Events.section_entered(section_id, RESPAWN)` via the F&R reload pipeline. | Downstream from F&R: `section_id: StringName`, `reason: TransitionReason.RESPAWN` |
| Cancel pressed | `ModalScaffold.hide_modal()` (a method call, not a signal) | n/a |
| `ui_cancel` pressed (Esc / B) | Same as Cancel pressed | n/a |
| Mouse click on backdrop | Same as Cancel pressed | n/a |
| Tab / Shift+Tab focus cycle | none | n/a — Godot's focus system handles this without a custom event |

**Important caveat — re-brief vs death-triggered respawn**: the F&R `restart_from_checkpoint()` API is also called internally by F&R's own death-handling pipeline (when the player's death triggers a respawn). The PLAYER-INITIATED re-brief from this modal is **NOT a death** — no `player_died` event fires. F&R's internal logic must distinguish player-initiated re-brief from death-triggered respawn for anti-farm floor logic per CR-5 ("respawn floor applies on first death of this checkpoint"). **OQ-RBO-2** flags this: the F&R API `restart_from_checkpoint()` may or may not need a parameter to distinguish initiator (e.g., `restart_from_checkpoint(initiator: Initiator.PLAYER_INITIATED | Initiator.DEATH)`).

**Analytics events** (none at MVP/VS — analytics is post-MVP per `design/gdd/systems-index.md`):

| Player Action | Analytics Event (post-VS) | Payload |
|---|---|---|
| Confirm pressed | `menu.rebrief.confirmed` | `{ section_id: StringName, checkpoint_id: StringName (post-MVP — checkpoint IDs are a Mission Scripting extension), elapsed_since_checkpoint_ms: int, elapsed_in_modal_ms: int }` |
| Cancel pressed | `menu.rebrief.cancelled` | `{ section_id: StringName, cancel_method: "button" | "ui_cancel" | "backdrop_click", elapsed_in_modal_ms: int }` |
| Modal mounted | `menu.rebrief.shown` | `{ section_id: StringName, time_since_checkpoint_ms: int }` |

**Persistent-state-modifying actions flagged for architecture team**:
- **Confirm path**: triggers `FailureRespawn.restart_from_checkpoint()` which destroys the in-memory section state since the last checkpoint. **No save data is destroyed** by the modal directly; F&R's reload pipeline writes a fresh slot 0 autosave at step 4 of the F&R flow per CR-1 (or may not — it depends on whether re-brief uses the death-flow or a separate path; OQ-RBO-3). **Architecture concern**: ensure F&R's `restart_from_checkpoint()` API handles the player-initiated case correctly: (a) does it write a fresh slot 0 autosave at re-brief time, or does it just reload the existing slot 0?; (b) does it apply the anti-farm respawn floor, or does it skip floor logic on player-initiated re-brief?; (c) does it set `_floor_applied_this_checkpoint = false` (allowing the next death to apply the floor) or `true` (preventing farm via re-brief loops)? See OQ-RBO-2 and OQ-RBO-3.

---

## Transitions & Animations

| Phase | Transition | Duration | Easing | Reduced-Motion Variant |
|---|---|---|---|---|
| **Modal enter (appear)** | Hard cut (VS baseline) — modal appears at full position with backdrop at 52% dim and card fully rendered, on the same frame as `show_modal()` is called | 0 ms (1 frame) | n/a | Identical (already hard cut) |
| **Modal enter (post-VS candidate)** | Backdrop fade-in 0% → 52% opacity; card slide-up 32 px → 0 px or scale 0.95 → 1.0 | 200 ms | ease-out | Suppressed — backdrop snaps to 52%, card snaps to position. CR-23 conditional. |
| **Focus shift (Tab)** | 4 px BQA Blue brightened border slides from one button to the other | ~80 ms | ease-out | Suppressed — border instantly appears/disappears. CR-23 conditional. |
| **Button hover (mouse only)** | Background fill brightens 5% on `mouse_entered`; reverses on `mouse_exited` | ~120 ms | linear | Suppressed — instant brightness change. CR-23 conditional. |
| **Button press (visual)** | Background fill darkens 10% on `button_down`; reverses on `button_up` | 1 frame (instant) | n/a | Identical (already instant) |
| **Confirm-in-flight (stamp slam)** | Per pause-menu.md L565 "Stamp slam (destructive confirm — Close File / Return to Registry / Re-Brief / Save-Failed Abandon)" — the rubber-stamp visual animates a 1-frame downward slam on Confirm press | ~80 ms | ease-in (lands hard) | Suppressed — instant state change to "stamped" appearance; A6 thud audio still plays. CR-23 conditional. |
| **Modal exit (Cancel path)** | Hard cut (VS baseline) — modal hides on the same frame as `hide_modal()` is called | 0–16 ms (1–2 frames) | n/a | Identical (already hard cut) |
| **Modal exit (post-VS candidate)** | Backdrop fade-out 52% → 0%; card slide-down or scale | 200 ms | ease-in | Suppressed. CR-23 conditional. |
| **Modal exit (Confirm path)** | Modal does NOT explicitly exit — F&R's `restart_from_checkpoint()` triggers LS reload which destroys the section + Pause Menu + modal as descendants within 1–2 frames | ~16–32 ms (F&R's pace) | n/a (F&R + LS own) | n/a — F&R + LS control subsequent transition |

**Photosensitivity audit**: same as siblings — no flashing, no strobe, no rapid color change. WCAG SC 2.3.1 Pass.

**Motion-sickness audit**: same as siblings — no camera motion, no parallax, no high-velocity slide-ins.

**Audio-paired transitions** (locked per menu-system.md §A.1–A.2 + pause-menu.md §A):
- A1 typewriter clack — fires on modal mount AND on every button press (60–80 ms, UI bus)
- A6 rubber-stamp thud — fires on Confirm press only (90–110 ms, UI bus; destructive register; matches "Stamp slam" group per pause-menu.md L565)
- A8 paper-drop modal-appear — fires on modal mount (per pause-menu.md L407 "show_modal(ReBriefContent); A8 modal-appear")
- **No music fade** on Confirm — re-brief stays in the same section; gameplay music continues. (Distinct from return-to-registry which fades music on `section_exited`.)
- **F&R's own respawn audio** — F&R's reload pipeline emits `Events.respawn_triggered` per F&R GDD; Audio domain subscribes to this for its 2.0 s fade-in on respawn (per F&R L23 "respawn beat is ~2–3 seconds of silent fade, scene-reset, and return to the last checkpoint"). This audio is owned by F&R + Audio, not by this modal.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| `has_checkpoint: bool` | `FailureRespawn.has_checkpoint()` (per CR-13) OR `MissionLevelScripting.has_checkpoint_in_current_section()` (per pause-menu.md L592) | **Indirect read** — the modal does not read this; the upstream Pause Menu queries it at `_ready()` to determine button visibility | **OQ-RBO-1**: API name discrepancy between menu-system.md (F&R-owned) and pause-menu.md (MLS-owned). Coord with technical-director + F&R-owner + MLS-owner. |
| `current_section_id` (StringName) | LS / MissionLevelScripting (mid-section) | **Indirect read** — modal does not read; data is implicit in scene tree state | Used post-VS for analytics payload |
| `tr("menu.rebrief.stamp")` → `RE-BRIEF OPERATION` | `translations/menu.csv` via Godot's `tr()` function | **Read** (resolved at `_ready()` and on `NOTIFICATION_TRANSLATION_CHANGED`) | Already in string table per menu-system.md §C.8 L347 |
| `tr("menu.rebrief.body_alt")` → `Reload last checkpoint?` | `translations/menu.csv` | **Read** | Already in string table per menu-system.md §C.8 L348 (23 chars — under L212 25-char cap). **Interrogative form** (see Section A note). |
| `tr("menu.rebrief.confirm")` → `Re-Brief` | `translations/menu.csv` | **Read** | Already in string table per menu-system.md §C.8 L349 (8 chars — shortest Confirm label of the family) |
| `tr("menu.rebrief.cancel")` → `Continue Mission` | `translations/menu.csv` | **Read** | Already in string table per menu-system.md §C.8 L350 (matches quit-confirm + return-to-registry siblings for cross-modal Cancel-label consistency) |
| `tr("menu.rebrief.confirm.desc")` → AccessKit description for Confirm button | `translations/menu.csv` | **Read** (resolved on `NOTIFICATION_TRANSLATION_CHANGED`) | **NEW STRING** — this spec adds it. Suggested English: "Reload the last checkpoint. Recent progress since checkpoint is lost." (Mirrors the Pause Menu button's `accessibility_description` per pause-menu.md L670 — same plain-language safety-net text propagates to the modal Confirm.) |
| `tr("menu.rebrief.cancel.desc")` → AccessKit description for Cancel button | `translations/menu.csv` | **Read** | **NEW STRING** — this spec adds it. Suggested English: "Resume the operation from the current state. Pause Menu remains open." |
| `Settings.accessibility.reduced_motion_enabled` | `SettingsService` autoload | **Read** (resolved at modal `_ready()`; not re-read while modal is open) | Suppresses appearance tweens (no-op at VS hard-cut baseline; wired for post-VS) |
| `Theme.modal_scaffold` (StyleBoxFlat colors, font sizes, button styles) | Project-wide Theme resource (per ADR-0004 IG6) | **Read** | Inherited from ModalScaffold |
| `originating_button: Control` (Pause Menu's "Re-Brief Operation" button reference) | Passed in by Pause Menu when calling `ModalScaffold.show_modal()` | **Read + Write** (write = the reference is stored for `return_focus_node` on hide) | Per `menu-system.md` Cluster F edge-case L901, modal MUST validate `is_instance_valid(originating_button)` before `call_deferred("grab_focus")` on dismiss. If invalid, fall back to Pause Menu's `_default_focus_target` ("Resume Surveillance" button). |

**Architectural concerns flagged**:
- The modal does not own any persistent state of its own. All persistent state changes initiated by Confirm flow through F&R's `restart_from_checkpoint()` API.
- No autoload registration needed for the modal.
- The 2 NEW localization strings (Confirm/Cancel `accessibility_description`) need to be added to `translations/menu.csv` before this modal can ship — coord with localization-lead.

**No real-time data**: the modal does not display elapsed-since-checkpoint time, checkpoint identifier, or any real-time-updating values. The body copy is static at "Reload last checkpoint?" regardless of how long since the player reached the checkpoint.

---

## Accessibility

**Committed tier**: **Standard** (per `design/accessibility-requirements.md`).

The modal inherits all accessibility commitments from `modal-scaffold` and `case-file-destructive-button` patterns. The contract below is the consolidated checklist for QA verification.

### Keyboard-only navigation path

| Step | Action | Expected Result |
|---|---|---|
| 1 | Modal mounts | Focus moves to "Continue Mission" Cancel button (default focus per `modal-scaffold` safe-action contract) |
| 2 | Tab | Focus moves to "Re-Brief" Confirm button (focus trap cycles within modal) |
| 3 | Tab again | Focus cycles back to Cancel (no escape from modal) |
| 4 | Shift+Tab | Focus moves backwards through cycle |
| 5 | Enter / Space (on Cancel) | Activates Cancel; modal dismisses; focus returns to "Re-Brief Operation" button on Pause Menu |
| 6 | Enter / Space (on Confirm) | Activates Confirm; F&R reloads from checkpoint (modal vanishes with parent) |
| 7 | Escape (from anywhere within modal) | Activates Cancel-equivalent path |

### Gamepad navigation order (Partial coverage per technical-preferences.md)

Identical to sibling specs. A button → activate focused; B button → ui_cancel; D-pad cycle → focus neighbor; analog stick → not used; Start/Select → not used.

### Text contrast and minimum readable font sizes

| Element | Foreground | Background | Contrast Ratio | WCAG AA / AAA | Font Size |
|---|---|---|---|---|---|
| Header stamp ("RE-BRIEF OPERATION") | Parchment `#E8DCC4` | Ink Black `#1A1A1A` | ~14.2:1 | AAA Pass (≥7:1) | DIN Bold 24 px |
| Body text ("Reload last checkpoint?") | Ink Black `#1A1A1A` | Parchment `#E8DCC4` | ~14.2:1 | AAA Pass | American Typewriter Bold 18 px |
| Confirm button label ("Re-Brief") | Parchment `#E8DCC4` | Ink Black `#1A1A1A` | ~14.2:1 | AAA Pass | DIN Bold 18 px |
| Cancel button label ("Continue Mission") | Parchment `#E8DCC4` | BQA Blue `#1B3A6B` | ~10.8:1 | AAA Pass | DIN Bold 18 px |
| Focus indicator border (4 px brightened BQA Blue) | n/a | Card Parchment `#E8DCC4` | ≥3:1 (focus indicator non-text contrast per WCAG SC 1.4.11) | AA Pass | n/a |

**All ratios meet WCAG AAA (≥7:1).** Identical contrast profile to return-to-registry; no color element relies on contrast below AAA threshold.

### Color-independent communication

The modal communicates destructive-vs-safe action through **4 redundant signals** (`case-file-destructive-button` pattern):

1. **Color**: Ink Black header band + Ink Black Confirm button + BQA Blue Cancel button
2. **Position**: Confirm is left of Cancel (LTR locales); Cancel is right (default focus, safe-action position)
3. **Label text**: "Re-Brief" (action verb implies decisive action) + "Continue Mission" (universally understood safe-action with mission-fiction framing)
4. **Focus indicator**: 4 px BQA Blue brightened border on focused button (initially Cancel)

A color-blind player can identify the destructive button via position + label + focus state alone. **WCAG SC 1.4.1 Pass**.

**Note on Confirm label ambiguity**: as called out in Section A, "Re-Brief" is a register departure from common destructive verbs (Quit / Return / Begin) and may be ambiguous to first-time players who read it as "review the briefing again." The modal's body copy ("Reload last checkpoint?") + Confirm-button-label-in-context (the position + Ink Black register + Cancel-default-focus pairing) together resolve this ambiguity; the AccessKit description ("Reload the last checkpoint. Recent progress since checkpoint is lost.") provides the plain-language safety net. **OQ-RBO-4** flags whether playtest evidence supports this resolution or whether a clarifying icon (NOT permitted by Pillar 5 modal chrome rules) or additional copy is needed.

### Screen reader support

| Node | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| ModalCard root | `ROLE_DIALOG` | `tr("menu.rebrief.stamp")` → "RE-BRIEF OPERATION" | (empty — name suffices) | `LIVE_ASSERTIVE` (one-shot on mount, cleared to `LIVE_OFF` next frame via `call_deferred`) per CR-21 |
| HeaderStamp Label | `ROLE_STATIC_TEXT` (or default) | (empty — covered by ModalCard's name) | (empty) | `LIVE_OFF` |
| BodyText Label | `ROLE_STATIC_TEXT` (or default) | `tr("menu.rebrief.body_alt")` → "Reload last checkpoint?" | (empty) | `LIVE_OFF` |
| Divider ColorRect | n/a (decorative) | (none) | (none) | n/a |
| ConfirmButton | `ROLE_BUTTON` | `tr("menu.rebrief.confirm")` → "Re-Brief" | `tr("menu.rebrief.confirm.desc")` → "Reload the last checkpoint. Recent progress since checkpoint is lost." (NEW STRING) | `LIVE_OFF` |
| CancelButton | `ROLE_BUTTON` | `tr("menu.rebrief.cancel")` → "Continue Mission" | `tr("menu.rebrief.cancel.desc")` → "Resume the operation from the current state. Pause Menu remains open." (NEW STRING) | `LIVE_OFF` |
| ModalBackdrop ColorRect | n/a (decorative) | (none) | (none) | n/a |

**Assertive announce on mount**: when modal mounts, the screen reader announces (en-US): "Dialog. RE-BRIEF OPERATION. Reload last checkpoint? Continue Mission button. Resume the operation from the current state. Pause Menu remains open." The interrogative body copy is well-served by the `ROLE_DIALOG` + question framing — AT users get a clear "system is asking a question" cue.

**Locale-change re-resolve**: on `NOTIFICATION_TRANSLATION_CHANGED`, all `accessibility_name` and `accessibility_description` strings re-resolve via `_update_accessibility_names()` helper.

### Motion and animation

**At VS baseline**: modal appears via hard cut. No tweens. Reduced-motion variant is identical to default.

**Post-VS polish candidates** (200 ms backdrop fade-in, focus-shift border slide, hover-fill ramp, stamp slam): all suppressed when `Settings.accessibility.reduced_motion_enabled == true` per CR-23.

### Photosensitivity

Same as siblings — no flash, no strobe, no rapid color change. WCAG SC 2.3.1 Pass.

### Cognitive accessibility

- Body copy is **plain language** as a question: "Reload last checkpoint?" — declarative-question, no jargon, no error code
- AccessKit `accessibility_description` for both buttons provides plain-language clarification (mandatory per `case-file-destructive-button` rule 6)
- Default focus on Cancel (safe action) prevents accidental destructive activation
- Single-press activation — no hold-to-confirm gesture or timed input
- No time pressure — modal stays open indefinitely until player decides
- Cancel label "Continue Mission" is fiction-aware but clear
- **Confirm label "Re-Brief" is potentially ambiguous** — see OQ-RBO-4 + Section A note. The plain-language `accessibility_description` is the cognitive-accessibility safety net for AT users; for non-AT users, the modal's body + position + register together carry the meaning.

### Motor accessibility

- All hit targets ≥ 280 × 56 px (Confirm at 280 px floor due to short "Re-Brief" label; Cancel auto-grows to ~310 px)
- 16 px gap between Confirm and Cancel reduces mis-click risk
- Single-press activation
- No time-limited input
- Backdrop click is a generous Cancel target

### Open accessibility questions

- See **Open Questions** section for unresolved items.

---

## Localization Considerations

### String table (already in `translations/menu.csv` per menu-system.md §C.8)

| String Key | English | Char Count | Estimated FR/DE Expansion (40%) | L212 Cap (25 chars) | Status |
|---|---|---|---|---|---|
| `menu.rebrief.stamp` | RE-BRIEF OPERATION | 18 | ~25–30 chars | ≤ 21 | ⚠ Likely fits FR/DE; tight margin (matches sibling stamp char-count precedent) |
| `menu.rebrief.body_alt` | Reload last checkpoint? | 23 | ~32–35 chars | ≤ 25 | ✓ English under cap; FR/DE may exceed cap → triggers multi-line wrap (alignment switches center → left per [CANONICAL]) |
| `menu.rebrief.confirm` | Re-Brief | 8 | ~12–15 chars | ≤ 21 | ✓ Comfortably fits all locales. Note: translator must preserve "redo the operation" register, NOT "review the briefing" register (see Localization coord below). |
| `menu.rebrief.cancel` | Continue Mission | 16 | ~22–26 chars | ≤ 21 | ⚠ Tight margin in FR/DE; may need locale override (matches return-to-registry sibling concern) |

### NEW strings to add (this spec adds these to the string table)

| String Key | English | Notes |
|---|---|---|
| `menu.rebrief.confirm.desc` | Reload the last checkpoint. Recent progress since checkpoint is lost. | AccessKit `accessibility_description` for Confirm button. Mirrors the Pause Menu's `Re-Brief Operation` button description (pause-menu.md L670) for consistency. ~64 chars; FR/DE expansion ~90 chars. No layout impact. |
| `menu.rebrief.cancel.desc` | Resume the operation from the current state. Pause Menu remains open. | AccessKit `accessibility_description` for Cancel button. ~67 chars; FR/DE expansion ~94 chars. No layout impact. |

### Layout-critical text constraints

| Element | Width Budget | Behavior on overflow |
|---|---|---|
| **Header stamp** ("RE-BRIEF OPERATION" rotated -5°) | ~700 px effective width within 880 px header band | If localized stamp text exceeds: **fall back to DIN Bold 20 px** (same as siblings). Truncation forbidden. |
| **Body text** ("Reload last checkpoint?") | ~816 px (card width − 32 px H pad each side) | If localized body exceeds 816 px on a single line: **wrap to 2 lines, switch alignment from center to left** per [CANONICAL]. Card height grows. **Special consideration**: the question mark must remain visible at the end of the wrapped text — translator must not split mid-question. |
| **Confirm button label** ("Re-Brief") | 280 px button width minimum | Comfortably fits all locales. No auto-grow likely needed. If a locale produces a label longer than 248 px (text width = 280 − 32 padding): button auto-grows. |
| **Cancel button label** ("Continue Mission") | 280 px button width minimum (auto-grows to ~310 px in English) | Tight margin in FR/DE; may need locale-specific override. |

### Numbers, dates, currencies

None on this modal — body copy is static text only.

### Bidirectional (RTL) support

Not committed at MVP/VS per `design/accessibility-requirements.md`. Post-VS RTL support would mirror button order (Cancel left, Confirm right) per `modal-scaffold` rule 4. The interrogative body copy's question mark would mirror per locale-appropriate punctuation.

### Coordinate with localization-lead

**HIGH PRIORITY items**:
1. **Confirm label "Re-Brief" register clarity** — per pause-menu.md L792 ("Re-Brief Operation is destructive — the translation should clearly imply *redoing* the operation, not 'briefing again' (some languages would naturally translate 're-brief' as 'briefing once more' which loses the 'you're losing checkpoint progress' weight). Translator must understand the destructive register."). This applies to `menu.rebrief.confirm` (the Confirm button label) AND `menu.rebrief.stamp` (the header stamp) AND `menu.pause.restart` (the Pause Menu button label). Translator briefing required.
2. **Interrogative body copy** — "Reload last checkpoint?" must remain a question in translation, not a declarative ("The last checkpoint will be reloaded.") — the question form is intentional per Section A. Translator briefing required.
3. **2 NEW AccessKit description strings** must be added to `translations/menu.csv` before VS sprint kickoff.

---

## Acceptance Criteria

The following criteria are testable by a QA tester without reading any other design document. They form the pass/fail gates for `/story-done`.

- **AC-RBO-1.1 [Logic] [BLOCKING — VS sprint, conditional on OQ-PM-1]** GIVEN Pause Menu is mounted at `Context.PAUSE` AND `FailureRespawn.has_checkpoint() == true` (so Re-Brief Operation button is visible), WHEN player activates `ReBriefButton`, THEN `ModalScaffold.show_modal(ReBriefContent)` is called within 1 frame, the modal title resolves to `"RE-BRIEF OPERATION"` (en-US), the body resolves to `"Reload last checkpoint?"` (en-US), default focus lands on the "Continue Mission" Cancel button, and `peek() == Context.MODAL`. Verifies CR-13 modal mount.

- **AC-RBO-1.2 [Logic] [BLOCKING — VS sprint]** GIVEN modal is open, WHEN inspected, THEN modal renders with **Ink Black header band** (NOT PHANTOM Red — distinct from save-failed-dialog and new-game-overwrite). Verifies menu-system.md §C.8 L347 register assignment.

- **AC-RBO-1.3 [Logic] [BLOCKING — VS sprint]** GIVEN Pause Menu is mounted AND `FailureRespawn.has_checkpoint() == false`, WHEN inspected, THEN the Re-Brief Operation button is NOT in the Pause button stack (per pause-menu.md AC-PAUSE-10.1: not just disabled — fully removed from focus order via `queue_free()` or `visible = false` AND removed from focus order). The modal cannot be reached via any UI path. Verifies CR-13 conditional visibility.

- **AC-RBO-2.1 [Integration] [BLOCKING — VS sprint]** GIVEN modal is open with default focus on Cancel, WHEN player presses Tab once, THEN focus moves to Confirm button and the 4 px BQA Blue brightened border renders on Confirm (not Cancel). WHEN player presses Tab again, focus cycles back to Cancel. Verifies CR-24 strict focus trap.

- **AC-RBO-2.2 [Integration] [BLOCKING — VS sprint]** GIVEN modal is open, WHEN player presses any combination of Tab + Shift+Tab + D-pad in any sequence, THEN focus NEVER reaches the underlying Pause Menu's buttons. Verifies CR-24 + FP-15.

- **AC-RBO-3.1 [Logic] [BLOCKING — VS sprint]** GIVEN modal is open with default focus on Cancel, WHEN player presses Enter / Space, THEN: (a) A1 typewriter clack sfx fires on UI bus; (b) `set_input_as_handled()` is called; (c) `ModalScaffold.hide_modal()` is called; (d) `Context.MODAL` is popped (`peek() == Context.PAUSE`); (e) Pause Menu button container has `process_input = true`; (f) focus returns to "Re-Brief Operation" button within 1 frame via `call_deferred`. All six within 2 frames of the press. Verifies modal-scaffold dismiss contract + `set-handled-before-pop` discipline.

- **AC-RBO-3.2 [Logic] [BLOCKING — VS sprint]** GIVEN modal is open, WHEN player presses Escape (`ui_cancel`), THEN the same exit path as AC-RBO-3.1 fires (Cancel-equivalent semantics). Verifies `dual-focus-dismiss` pattern.

- **AC-RBO-3.3 [UI] [ADVISORY]** GIVEN modal is open, WHEN player clicks anywhere on the backdrop (outside the 880×200 card), THEN the same Cancel-equivalent exit path fires. Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-RBO-4.1 [Logic] [BLOCKING — VS sprint]** GIVEN modal is open with focus on Confirm, WHEN player presses Enter / Space, THEN in order: (a) A1 typewriter clack + A6 rubber-stamp thud + A8 paper-drop fire on UI bus on the same frame; (b) Confirm button enters `disabled = true` state for at least 1 frame; (c) `set_input_as_handled()` is called; (d) `Context.MODAL` is popped; (e) `FailureRespawn.restart_from_checkpoint()` is called via `call_deferred`. Verifies CR-13 confirm path.

- **AC-RBO-4.2 [Integration] [BLOCKING — VS sprint]** GIVEN AC-RBO-4.1 sequence has executed, WHEN F&R's reload pipeline completes, THEN: (a) the section is reloaded with the checkpoint snapshot's state; (b) the player is positioned at the section's `player_respawn_point` Marker3D; (c) Pause Menu is destroyed; (d) modal is destroyed (as descendant of Pause); (e) `peek() == Context.GAMEPLAY` (LOADING was popped on section reload completion); (f) `Events.respawn_triggered(section_id)` was emitted by F&R during the pipeline. Verifies F&R + LS reload integration.

- **AC-RBO-4.3 [Logic] [BLOCKING — VS sprint, conditional on OQ-RBO-2]** GIVEN AC-RBO-4.2 has completed, WHEN measured, THEN the anti-farm respawn floor is **NOT** applied (player retains their pre-confirm ammo state, not the floor-clamped state). This verifies that `restart_from_checkpoint()` distinguishes player-initiated re-brief from death-triggered respawn (per OQ-RBO-2 resolution). If OQ-RBO-2 resolves to "floor IS applied on player-initiated re-brief," update this AC accordingly.

- **AC-RBO-4.4 [Logic] [BLOCKING — VS sprint]** GIVEN Confirm button is in `disabled = true` state (post-press), WHEN player presses Enter or clicks Confirm again, THEN no second `restart_from_checkpoint()` call fires (re-entrant guard).

- **AC-RBO-5.1 [UI] [BLOCKING — VS sprint]** GIVEN modal mounts with screen reader active (e.g., NVDA, JAWS, Orca), WHEN modal appears, THEN screen reader announces (en-US): "Dialog. RE-BRIEF OPERATION. Reload last checkpoint? Continue Mission button. Resume the operation from the current state. Pause Menu remains open." within 500 ms of mount. Manual walkthrough doc filed at `production/qa/evidence/`.

- **AC-RBO-5.2 [UI] [BLOCKING — VS sprint]** GIVEN modal is open with screen reader active and focus on Confirm, WHEN focus lands on Confirm, THEN screen reader announces "Re-Brief, button. Reload the last checkpoint. Recent progress since checkpoint is lost." Manual walkthrough doc filed at `production/qa/evidence/`. **Cognitive-accessibility note**: this AC is the primary mitigation for the Confirm-label-ambiguity concern (OQ-RBO-4) — AT users get plain-language clarification of what "Re-Brief" actually does.

- **AC-RBO-5.3 [Logic] [BLOCKING — VS sprint]** GIVEN modal mounted with `accessibility_live = LIVE_ASSERTIVE`, WHEN one frame has elapsed, THEN `accessibility_live == LIVE_OFF` (one-shot cleared via `call_deferred`). Verifies CR-21 one-shot assertive contract.

- **AC-RBO-6.1 [Visual] [ADVISORY]** GIVEN modal is rendered at 1920×1080 with English locale, WHEN inspected by eye, THEN: (a) Ink Black header band fills full card width × 50 px; (b) "RE-BRIEF OPERATION" stamp text is rotated -5° in DIN Bold 24 px Parchment, left-anchored at 16 px from card left edge; (c) body text "Reload last checkpoint?" is center-aligned in American Typewriter Bold 18 px Ink Black; (d) divider is 1 px Ink Black 70%, 816 px wide, centered; (e) Confirm and Cancel buttons are right-anchored with 16 px gap, 32 px right pad; (f) Confirm button is 280 px wide ("Re-Brief" fits comfortably); Cancel button auto-grows to ~310 px ("Continue Mission" fits). Screenshot evidence filed at `production/qa/evidence/`.

- **AC-RBO-6.2 [Visual] [ADVISORY]** GIVEN modal is rendered with FR locale (longest expected expansion), WHEN inspected, THEN: (a) header stamp does not overflow (or falls back to DIN Bold 20 px gracefully per OQ-RBO-5 resolution); (b) body text wraps to at most 2 lines, alignment switches from center to left, question mark visible at end; (c) button labels do not overflow their per-locale widths; (d) card height grows to accommodate. Screenshot evidence filed at `production/qa/evidence/`.

- **AC-RBO-7.1 [Integration] [BLOCKING — VS sprint]** GIVEN `Settings.accessibility.reduced_motion_enabled == true`, WHEN modal mounts and dismisses, THEN: (a) no appearance tween plays; (b) no focus-shift tween plays; (c) no hover tween plays; (d) no stamp-slam tween plays on Confirm; (e) audio cues (A1 clack, A6 thud, A8 paper-drop) all play at full duration. Verifies CR-23 reduced-motion conditional.

- **AC-RBO-8.1 [Logic] [BLOCKING — VS sprint]** GIVEN locale change occurs (`NOTIFICATION_TRANSLATION_CHANGED` fires) while modal is open, WHEN one frame passes, THEN: (a) HeaderStamp Label text re-resolves; (b) BodyText Label re-resolves (question mark preserved); (c) both button labels re-resolve; (d) ConfirmButton.accessibility_name + ConfirmButton.accessibility_description re-resolve; (e) CancelButton.accessibility_name + CancelButton.accessibility_description re-resolve; (f) focus is preserved on whichever button held focus. Verifies `accessibility-name-re-resolve` pattern compliance.

- **AC-RBO-9.1 [Performance] [ADVISORY]** GIVEN modal mount is requested, WHEN measured from `show_modal()` call to first frame fully rendered, THEN ≤ 33 ms (2 frames at 60 fps). Smoke check.

- **AC-RBO-9.2 [Performance] [ADVISORY]** GIVEN Confirm pressed, WHEN measured from press to `restart_from_checkpoint()` call, THEN ≤ 33 ms (2 frames). Subsequent reload is F&R's pace (per F&R performance budget — 2–3 seconds total respawn).

- **AC-RBO-10.1 [Config] [ADVISORY]** GIVEN `translations/menu.csv` on disk, WHEN inspected, THEN every English value for `menu.rebrief.*` matches §C.8 string table exactly, AND the 2 NEW description strings (`menu.rebrief.confirm.desc` + `menu.rebrief.cancel.desc`) are present.

- **AC-RBO-11.1 [Logic] [BLOCKING — VS sprint]** GIVEN modal is open AND OS window loses focus mid-modal, WHEN OS window regains focus (`NOTIFICATION_WM_FOCUS_IN`), THEN `Input.flush_buffered_events()` is called before the first `_unhandled_input` of the refocused frame. Verifies edge-case Cluster G L915.

- **AC-RBO-12.1 [Playtest] [ADVISORY]** GIVEN Tier 0 Plaza playtest is in progress (per F&R OQ-FR-11 + pause-menu.md OQ-PM-1), WHEN observers log player behavior on failed-stealth events, THEN the percentage of failed-stealth events that result in quit-to-Load is measured. **If > 30%**: ship Re-Brief at VS (this modal becomes BLOCKING for VS gate). **If ≤ 30%**: defer Re-Brief to Polish; this spec stays draft-frozen until Polish phase.

**Minimum 5 criteria categories satisfied**:
- ✓ Performance criterion: AC-RBO-9.1, AC-RBO-9.2
- ✓ Navigation criterion: AC-RBO-3.1, AC-RBO-4.1, AC-RBO-4.2
- ✓ Error/empty/edge state criterion: AC-RBO-1.3 (no-checkpoint state — button absent), AC-RBO-11.1 (OS focus loss)
- ✓ Accessibility criterion: AC-RBO-2.1, AC-RBO-5.1, AC-RBO-5.2, AC-RBO-7.1
- ✓ Core-purpose criterion: AC-RBO-4.1, AC-RBO-4.2 (the destructive Confirm path is the modal's reason for existing)

**Total**: 23 acceptance criteria across 5 story types (Logic: 12 BLOCKING; Integration: 4 BLOCKING; UI: 3 mixed; Visual: 2 ADVISORY; Performance: 2 ADVISORY; Config: 1 ADVISORY; Playtest: 1 ADVISORY).

---

## Open Questions

| # | Question | Affects Section | Owner | Recommendation | Resolution Deadline |
|---|---|---|---|---|---|
| **OQ-RBO-1** | **F&R API name discrepancy.** menu-system.md CR-13 specifies `FailureRespawn.has_checkpoint() -> bool` (F&R-owned API). pause-menu.md L592 specifies `MissionLevelScripting.has_checkpoint_in_current_section() -> bool` (MLS-owned API). Both are proposed; only one will exist. Affects which autoload Pause Menu queries on `_ready()` to determine button visibility. | Data Requirements (button visibility query); States & Variants (Re-Brief hidden state); Acceptance Criteria (AC-RBO-1.3) | technical-director + F&R-owner + MLS-owner | **Recommended: F&R-owned `FailureRespawn.has_checkpoint()`** (per CR-13 [BLOCKING coord] explicit assignment). MLS owns the *placement* of checkpoints (level authoring), but F&R owns the *runtime state* (has-fired query). MLS-side query would be a level-authoring metadata query, not a runtime-state query. F&R is the right owner. | Before VS sprint kickoff |
| **OQ-RBO-2** | **Anti-farm respawn floor on player-initiated re-brief.** Per F&R CR-5/CR-7, the respawn ammo floor applies on "first death of this checkpoint." A player-initiated re-brief is NOT a death — does it trigger the floor or not? **Two policy options**: (a) **NO floor** (player keeps current ammo) — re-brief is a pure recovery action, not a death; rewards player skill over farm; or (b) **YES floor** (clamp ammo to floor) — prevents farm where a player saves ammo by re-briefing instead of dying. **Anti-farm consideration**: option (a) opens a farm where a player can intentionally fail-then-rebrief to keep current high-ammo state; option (b) penalizes legitimate retries with a floor reset. | Entry & Exit Points (irreversibility note); Events Fired (architectural concern); Acceptance Criteria (AC-RBO-4.3) | game-designer + F&R-owner + creative-director | **Recommended: option (a) — NO floor on player-initiated re-brief.** Rationale: re-brief is a Pillar-3 recovery affordance ("stealth is theatre, not punishment"); penalizing legitimate retries with floor-clamp violates pillar. The farm risk is mitigated by the fact that re-brief reloads the checkpoint snapshot (which has the player's pre-checkpoint ammo state) — the player DOES lose ammo gained between checkpoint and re-brief, just not via the floor mechanism. F&R's `restart_from_checkpoint()` should accept an `initiator: Initiator.PLAYER_INITIATED \| Initiator.DEATH` parameter to distinguish, OR be split into two APIs (`restart_from_checkpoint_player_initiated()` vs `restart_from_checkpoint_death_triggered()`). | Before VS sprint kickoff |
| **OQ-RBO-3** | **Slot 0 autosave behavior on player-initiated re-brief.** F&R's death pipeline writes a fresh slot 0 autosave at step 4 (per F&R CR-1) — capturing the dying state for analytics or recovery. For a player-initiated re-brief, does F&R write a fresh slot 0 (capturing the pre-rebrief state — useful for "undo my undo" on next launch)? Or does it skip the save and just reload the existing slot 0? | Data Requirements (architectural concern); Events Fired | F&R-owner + technical-director | **Recommended: SKIP fresh save on player-initiated re-brief.** Rationale: player explicitly chose to discard recent progress; saving the discarded state is counter-intuitive ("why does my autosave show the failed attempt I just abandoned?"). Re-brief should reload the existing slot 0 (which represents the checkpoint snapshot). | Before VS sprint kickoff |
| **OQ-RBO-4** | **Confirm-label-ambiguity playtest evidence.** "Re-Brief" is intentionally bureaucratic-register but may be misread by first-time players as "review the briefing" rather than "reload the checkpoint." The modal's body copy + Cancel-default-focus + AccessKit description together resolve ambiguity, but does playtest evidence support this? Should the spec add a clarifying sub-line ("Reloads from last checkpoint") inside the modal body, OR is the question form ("Reload last checkpoint?") sufficient? | Layout Specification (BodyText); Accessibility (cognitive note); Acceptance Criteria (AC-RBO-5.2) | game-designer + creative-director + playtest-lead | **Recommended: Tier 0 Plaza playtest** — observe whether players misclick Re-Brief expecting a briefing re-display. If misclick rate >5% on re-brief activations, add a sub-line. If ≤5%, ship as-is. | During Tier 0 Plaza playtest (parallel with OQ-PM-1) |
| **OQ-RBO-5** | **Stamp rotation overflow for FR/DE.** "RE-BRIEF OPERATION" is 18 chars — same as "RETURN TO REGISTRY" and "OPEN NEW OPERATION". Same risk as siblings: FR/DE may push 25–30 chars. | Layout Specification (HeaderStamp); Localization Considerations | art-director + localization-lead | **Recommended: (a) auto-shrink to DIN Bold 20 px on overflow** — same fallback as siblings. Truncation forbidden per Pillar 5. | During localization review |
| **OQ-RBO-6** | **Reduced-motion conditional scope at VS baseline.** Same as sibling OQs: is the conditional **wired but no-op at VS** (so post-VS polish tweens can be added without touching the conditional path), or **omitted entirely** (with a TODO)? | Transitions & Animations; Accessibility | ux-designer + lead-programmer | **Recommended: WIRED but no-op** — same precedent as new-game-overwrite + return-to-registry. | Defer to lead-programmer style guide |
| **OQ-RBO-7** | **Background save during modal verification.** Same as siblings: can a Quicksave (F5) or any background save fire while re-brief modal is open? Expected NO (Context.MODAL blocks). Verify via grep gate. | Interaction Map (input gating); States & Variants | engine-programmer + ui-programmer | **Recommended: NO background saves during modal.** Confirm via grep gate. | Before VS sprint kickoff |
| **OQ-RBO-8** | **VS ship gate dependency on playtest.** Per pause-menu.md OQ-PM-1 + F&R OQ-FR-11, Re-Brief at VS is conditional on Tier 0 Plaza playtest showing >30% quit-to-Load frequency on failed-stealth events. If frequency ≤ 30%, this modal defers to Polish, and this spec stays draft-frozen at VS gate. | Sprint scope (header); Acceptance Criteria (AC-RBO-12.1) | game-designer + producer + creative-director | **Recommended: track playtest data closely.** If the gate evaluation lands in the gray zone (25–30%), bring decision to creative-director for binding ruling. | Tier 0 Plaza playtest completion (per F&R OQ-FR-11 schedule) |

**No CRITICAL blockers** at the time of this spec. The most architecturally significant OQs are OQ-RBO-1 (API ownership), OQ-RBO-2 (floor policy), and OQ-RBO-3 (autosave behavior) — all 3 are F&R-coord items that should be resolved before VS sprint kickoff. OQ-RBO-8 is a scope gate that may defer this entire spec's implementation to Polish.

---

## Cross-Reference Summary

**Files this spec depends on** (must remain consistent with these):

- `design/ux/quit-confirm.md` Section C.3 — CANONICAL modal-scaffold reference
- `design/ux/pause-menu.md` §C (Component Inventory L232 — Re-Brief Operation button), §B3 (Entry & Exit L120), §G (Accessibility AccessKit table L670), §A (Audio cues L407, L464, L465), §I (Events Fired L452, L483), §F (Data Requirements L592), §K (Open Questions L919 OQ-PM-1 — playtest gate)
- `design/ux/return-to-registry.md` (sibling spec — same Pause-Menu mount pattern, same Cancel label, same audio family)
- `design/ux/interaction-patterns.md` `modal-scaffold`, `case-file-destructive-button`, `dual-focus-dismiss`, `set-handled-before-pop`, `accessibility-name-re-resolve`, `auto-translate-always`
- `design/gdd/menu-system.md` CR-2 (InputContext push/pop), **CR-13** (Re-Brief Operation modal — primary source), CR-21 (one-shot assertive), CR-23 (reduced-motion conditional), CR-24 (modal focus trap [VS]), §C.8 (string table L347-350), §A.1–A.2 (audio cues), Cluster F edge-case L901 (focus restore validity), Cluster G edge-case L915 (OS focus loss flush)
- `design/gdd/failure-respawn.md` CR-1 (death pipeline that `restart_from_checkpoint()` may share), CR-5/CR-6/CR-7 (anti-farm floor logic — affected by re-brief per OQ-RBO-2), CR-11 (Checkpoint resource — checkpoint snapshot data), L11 (sole publisher of Failure/Respawn signal domain), OQ-FR-11 (Re-Brief playtest gate)
- `design/gdd/mission-level-scripting.md` (checkpoint placement at section authoring; not yet authored — see PROVISIONAL note in F&R CR-11)
- `design/art/art-bible.md` §3.3, §4, §7B, §7D
- `design/accessibility-requirements.md` Standard tier
- `docs/architecture/ADR-0002-signal-bus-event-taxonomy.md` L183 (F&R sole publisher of Failure/Respawn domain)
- `docs/architecture/ADR-0004-ui-framework.md` IG6, IG7, IG10
- `docs/architecture/ADR-0007-autoload-registry.md` (F&R + Settings + LS autoload positions)

**Files that should later cross-link to this spec**:
- `design/ux/pause-menu.md` — should add "see `re-brief-operation.md`" links in §C.232, §B3.120, §I.452/483.
- `design/gdd/menu-system.md` CR-13 — should add "UX spec: `design/ux/re-brief-operation.md`" cross-reference.
- `design/gdd/failure-respawn.md` — should add "UX consumer: `design/ux/re-brief-operation.md`" cross-reference. The OQ-RBO-2/3 resolutions may also touch CR-5/CR-6/CR-7 with a new "player-initiated re-brief" branch.
- `design/ux/interaction-patterns.md` — `modal-scaffold` and `case-file-destructive-button` "Used In" lists already include "Re-Brief" — verify on /ux-review.
- `design/gdd/mission-level-scripting.md` (when authored) — should reference this modal as a checkpoint consumer.

---

## Verdict

**COMPLETE** — UX spec written and section-by-section content authored per `quit-confirm.md` [CANONICAL] sibling inheritance + menu-system.md CR-13 + §C.8 string table + `case-file-destructive-button` pattern + `modal-scaffold` pattern + F&R checkpoint integration. Spec is ready for `/ux-review`.

This completes the **4-modal Case File destructive sibling family**: `quit-confirm.md`, `return-to-registry.md`, `re-brief-operation.md` (this spec), and the hybrid-register `new-game-overwrite.md`. All four share the [CANONICAL] modal-scaffold geometry + button contract + focus contract + accessibility patterns; each varies in trigger, body copy, destructive payload, and (for new-game-overwrite) header band color.

---

## Recommended Next Steps

1. **Run `/ux-review re-brief-operation`** — validate this spec before it enters the implementation pipeline.
2. **Resolve the 3 F&R-coord OQs (OQ-RBO-1, OQ-RBO-2, OQ-RBO-3)** before VS sprint kickoff — these are the architectural items.
3. **Track Tier 0 Plaza playtest results** for OQ-RBO-8 (VS ship gate) and OQ-RBO-4 (Confirm-label-ambiguity check). If playtest doesn't land before VS planning, default to deferring to Polish per the conservative recommendation.
4. **Add 2 NEW localization strings** to `translations/menu.csv`: `menu.rebrief.confirm.desc` + `menu.rebrief.cancel.desc`. Coord with localization-lead — and include the translator briefing items (interrogative body form preservation; "Re-Brief" register clarity per pause-menu.md L792).
5. **Cross-link** pause-menu.md, menu-system.md (CR-13), and failure-respawn.md to this spec on /ux-review approval.
6. **`/gate-check pre-production`** once all 5 modal-scaffold sibling specs are reviewed (quit-confirm DONE, save-failed-dialog DONE, new-game-overwrite COMPLETE pending review, return-to-registry COMPLETE pending review, re-brief-operation COMPLETE pending review). With this spec authored, the modal family is feature-complete.
