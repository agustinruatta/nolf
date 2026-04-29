# UX Spec: Save-Failed Dialog (DISPATCH NOT FILED)

> **Status**: In Design
> **Author**: agustin.ruatta@vdx.tv + ux-designer
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: Cross-cutting — fires whenever `Events.save_failed` is emitted by Save/Load while a Menu surface (Main Menu or Pause Menu) is mounted. Most common during Pause Menu manual save and Quicksave (F5).
> **Template**: UX Spec
> **Scope**: VS (Vertical Slice) per Menu System §C.2 row 9 + Save/Load §UI Requirements L240.
> **Governing GDDs**: `design/gdd/menu-system.md` (§C.2 row 9 + §C.4 ModalScaffold + §V.5 + §A.1 cue inventory + §C.8 locked strings + §H.8 ACs) + `design/gdd/save-load.md` (§Edge Cases — IO_ERROR / VERSION_MISMATCH / CORRUPT_FILE + §States `SAVING` lifecycle + §UI Requirements L240).
> **Pattern Inheritance**: `quit-confirm.md` (CANONICAL Case File register modal) — save-failed inherits the modal scaffold + button chrome + focus + accessibility patterns; this spec only documents what differs (PHANTOM Red destructive register vs. Ink Black deliberative; default focus Retry vs. Cancel; retry-target tracking; no `VU PAR` stamp).

---

## Purpose & Player Need

The Save-Failed Dialog is the **only player-facing surface** that surfaces a Save/Load error. It exists so that a save failure — disk full, version mismatch, file corruption, OS write rejection — is **never silent**. Save/Load is the system the player relies on most invisibly; an unreported failure is a game-breaking trust violation.

> **Player goal**: *"My save just failed. Tell me clearly, let me retry without re-doing my work, and don't lose my place in the world."*

**What goes wrong if this surface is missing or unclear:**
- Player believes a save succeeded when it did not — comes back tomorrow to a slot from yesterday morning. Catastrophic.
- Player retries blindly without knowing why the failure happened — thrash that produces more failures.
- Player abandons the save without learning that *the previous good slot is preserved* (Save/Load atomicity guarantee per save-load.md L126).
- Modal blocks gameplay continuation — Pause cannot resume; player force-quits with unsaved progress lost.

**Distinguishing constraint** — Save-Failed is a **non-blocking** modal: the Pause Menu underneath remains visible and partially-interactive. The player can dismiss the modal without performing a recovery action and continue the operation in progress (Menu System CR-10 — "non-blocking modal: underlying PauseMenu buttons remain visible without disabling `process_input`"). The dialog is an *advisory*, not a forced choice.

**Pillar fit:**
- **Primary 5 (Period Authenticity)**: PHANTOM Red header band with `DISPATCH NOT FILED` typeset is a 1965 BQA rejection slip — the bureaucracy refusing to file a document. Not a modern "Error 0x80070005" dialog.
- **Primary 3 (Stealth as Theatre)**: a save failure during a tense stealth moment must not break the scene; the dialog is a folder slid onto the desk, not a screen-replacement.
- **Anti-Pillar (NOT modern UX paternalism)**: no spinner, no progress bar, no nested error code, no "send report to developer" button. The body copy is 1–2 lines; the cause hint comes from the `FailureReason` enum mapping (table in §Layout).

---

## Player Context on Arrival

The player arrives at this dialog **involuntarily** — the game decides the modal appears, in response to a Save/Load failure event. Three arrival vectors:

| Vector | Trigger | Player state on arrival |
|---|---|---|
| Manual save attempt failed | Player just pressed Confirm on Save grid `[CONFIRM]` button (in-card overwrite-confirm flow, save-game-screen.md) → `SaveLoad.save_to_slot(N)` returned non-OK error → `Events.save_failed.emit(reason)` | Active intent (just authorized a save). Frustrated; the action did not complete. The Save grid is still mounted underneath. |
| Quicksave (F5) failed | Player pressed F5 from gameplay or menu → `SaveLoad.save_to_slot(0, ...)` returned non-OK → `Events.save_failed` fires | Brief intent (one-keypress). Possibly mid-action; player may not be looking at the screen at the moment of failure. |
| Autosave failed (Mission Scripting `section_entered` autosave fired) | Mission/Failure&Respawn triggered an autosave the player did not request → `save_to_slot(0)` failed → `Events.save_failed` fires | **Player did NOT request the save** — the dialog is a surprise. Most demanding case for clarity. Must explain "the autosave failed" not just "save failed". |
| Load attempt failed (version mismatch / corrupt file) | Player just selected a slot in Operations Archive (Load grid) → `SaveLoad.load_from_slot(N)` returned null → `Events.save_failed.emit(VERSION_MISMATCH or CORRUPT_FILE)` fires | Active intent (just clicked Load). Frustrated; no scene transition is happening. |

**Emotional state assumptions** (in design priority order):
1. **Frustrated + recovery-seeking** — failure interrupts what the player wanted. Retry must be one keypress (default focus on Retry per V.5 — saves a click).
2. **Confused** — "wait, was that an autosave? what happened?". Body copy must explain *which save failed* (slot number / autosave) and *why* in plain language.
3. **Worried** — "did I lose my previous save too?". The dialog must reassure: previous slot file is **preserved** (atomic write guarantee per Save/Load Edge Case L126).
4. **Resigned + abandon-seeking** — "fine, give up the save and move on". The Abandon path must close cleanly without further nag.

**Held inputs across the boundary**: the `Events.save_failed` event arrives asynchronously. The player may be holding `move_forward` (if it was an autosave during gameplay → but Pause is not open → in this case the dialog routes to **HUD State Signaling SAVE_FAILED state** instead of this modal per HSS); or pressing Tab in the Save grid (if it was a manual save). The dialog `_ready()` calls `set_input_as_handled()` on the next input frame to avoid same-frame button activation collision.

---

## Navigation Position

Save-Failed is **not a screen the player navigates to** — it is mounted by `ModalScaffold` in response to `Events.save_failed`. It lives at:

```
[any Menu surface] → ModalScaffold (CanvasLayer 20) → SaveFailedContent
```

**Mounting parents** (per Menu System §C.2 row 9):
- MainMenu shell (`Context.MENU`)
- PauseMenu shell (`Context.PAUSE`)
- Operations Archive sub-screen of either (inherits parent's context)
- File Dispatch sub-screen of PauseMenu (inherits PAUSE)

**NOT mounted from**:
- Active gameplay (`Context.GAMEPLAY`) — autosave failures during raw gameplay route to **HUD State Signaling SAVE_FAILED state** (per HSS §C state table + accessibility-requirements.md Auditory row L177). HSS owns the gameplay-time non-modal indicator; this dialog is reserved for menu-context failures.
- Document Overlay UI (`Context.DOCUMENT_OVERLAY`) — Save/Load CR-6 forbids saves during DOCUMENT_OVERLAY; no `save_failed` should fire from this context.
- Cutscene / Loading — same — saves are gated; no failures route to a modal.

**InputContext push/pop**:
- `ModalScaffold.show_modal(SaveFailedContent)` pushes `Context.MODAL` on top of MENU or PAUSE per Menu System C.4.
- `ModalScaffold.hide_modal()` pops back to MENU or PAUSE.

**Stack depth**: maximum 3 — `[GAMEPLAY, PAUSE, MODAL]` or `[MENU, MODAL]`. Save-Failed never stacks on top of another modal (queued instead per C.4 most-recent-wins for save-failed-on-save-failed; rejected with `push_error` for save-failed-during-destructive-confirm — the player must dismiss the destructive confirm first).

**Returning from Save-Failed**: focus restores to the triggering UI — the Confirm button on the Save card (if manual save), the Pause root (if autosave during Pause), the Main Menu root (if load attempt from Main Menu). Per ModalScaffold `return_focus_node` parameter.

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Carries this context |
|---|---|---|
| `Events.save_failed(reason: FailureReason, slot: int)` | Save/Load emits when `ResourceSaver.save()` returns non-OK, version mismatch, or corrupt file detected | `reason` ∈ {`IO_ERROR`, `VERSION_MISMATCH`, `CORRUPT_FILE`, `DISK_FULL` (if differentiated post-MVP)}; `slot: int` (0 for autosave/quicksave; 1–7 for manual) |
| Most-recent-wins queue (C.4) | A save-failed fires while another save-failed modal is already active | Replaces the queued `_pending_modal_content`; on dismiss of current save-failed, the most recent queued one shows |
| Queue-after-destructive (C.4) | A save-failed fires while a Quit-Confirm / Return-to-Registry / Re-Brief / New-Game-Overwrite modal is active | Queued in `_pending_modal_content`; shows after the destructive modal dismisses |

> **Save-Failed never fires from gameplay context.** Per Save/Load CR-6 (extended 2026-04-28), save-eligible contexts are `{GAMEPLAY, MENU, PAUSE}`. A failed gameplay-time save (autosave during section transition) emits `save_failed` but the **HSS SAVE_FAILED state** owns the player-facing surface in that case (HSS §C resolver priority table — SAVE_FAILED ranks below ALARM_STINGER but above MEMO_NOTIFICATION). This dialog is **menu-context only**.

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Retry path** (default — re-attempt save) | `Retry` button activated **OR** `ui_accept` on default focus | Calls `SaveLoad.save_to_slot(slot)` for the same `slot` that originally triggered save_failed (most-recent target tracked in modal state per Menu System CR-10 + AC-MENU-8.4). Modal closes; if retry succeeds, returns to mounting parent. If retry also fails, modal re-mounts via fresh `Events.save_failed` event (queue handles the chain). |
| **Abandon path** (cancel — accept the failure) | `Abandon` button activated **OR** `ui_cancel` (`Esc` / `JOY_BUTTON_B`) | Modal closes via `hide_modal()`; pop `Context.MODAL`; return to mounting parent. Save target is **NOT** retried. Previous good slot file (if any) is preserved per Save/Load atomicity. |
| **Auto-dismiss on slot fix** | Player closes the modal and addresses the underlying cause (e.g., frees disk space) — no programmatic auto-dismiss | n/a — dialog only dismisses on explicit player action |

### Irreversible exit warnings

There are **none** — both Retry and Abandon are reversible from the player's perspective:
- Retry can fail again, returning the same dialog. No state lost.
- Abandon does not destroy any pre-existing save data. The previous good slot is intact (atomic write — failed save NEVER overwrites the previous slot file per Save/Load Edge Case L126).
- The current in-memory game state is unchanged in either path. Player can continue operating, save again later to the same or different slot.

This makes Save-Failed a **low-stakes** modal in terms of player state, even though the *cause* (disk full, etc.) may be high-stakes. The dialog's job is to inform + offer retry; it must not amplify alarm.

---

## Layout Specification

### Information Hierarchy

| Rank | What the player must see | Why it ranks here | How it is communicated |
|---|---|---|---|
| 1 | "**A save failed.**" (modal-anchor identity) | Without this, the player does not know the dialog is about a save event | PHANTOM Red header band with `DISPATCH NOT FILED` (V.5 §C.8 `menu.save_failed.title`); A8 paper-drop modal-appear cue at 50–70 ms; Audio's descending-minor-two-note save-failed sting fires in parallel (Audio L181) |
| 2 | **Which save failed?** (autosave / slot N / quicksave) | Player must know *which* of their saves is in trouble — this affects retry decision (e.g., "the autosave failed but I just manually saved slot 3 — I'm fine") | Body line 1 includes slot identifier: `Quicksave (Dispatch 0)` / `Dispatch {n}` / `Autosave (Dispatch 0)` (template strings — see Localization Considerations) |
| 3 | **Why did it fail?** (failure reason hint) | Drives the player's recovery decision (free disk space vs. game version mismatch) | Body line 1 includes a brief reason cue per `FailureReason`: see mapping table below. NOT a stack trace; NOT an OS error code. 1–6 word hint. |
| 4 | "**You can try again.**" (Retry as default) | Reassures the player that retry is available and one-keypress | `Retry` button is the default focus, PHANTOM Red fill (attention color, not destructive) per V.5 |
| 5 | "**Or you can move on without saving.**" (Abandon as alternative) | Player may know retry will fail (e.g., disk genuinely full and they can't address it now); they need a non-frustrating exit | `Abandon` button alongside Retry, BQA Blue fill (de-prioritized but available) |

**Categorically NOT shown** (per Pillar 5 + Pillar register):
- OS error codes (`Error 0x80070005`, `errno -28`, etc.)
- Stack traces or technical debug strings
- "Send error report to developer" button (single-player game; no telemetry layer at MVP+VS)
- Spinner / loading indicator (saves are < 10 ms per ADR-0003; nothing to spin for)
- "Don't show this again" toggle (the dialog is per-event, not session-spanning)
- Multi-page elaborate explanation
- The previous slot's metadata, screenshot, or "preserved" indicator (the atomicity guarantee is reassured via *body copy text*, not a separate UI element)

### Layout Zones

Three zones, anchored to the 400 × 200 px modal card from Menu System §V.5.

```
ZONE A — Modal scaffold backdrop (52% Ink Black ColorRect, full viewport, behind card)
ZONE B — Card body (400 × 200 px, centered)
  ├── B.1 — Header band (PHANTOM Red, 28 px tall, full card width)
  ├── B.2 — Body text area (American Typewriter 10 px, Ink Black, 2 lines centered)
  ├── B.3 — Divider (1 px ruled line, 70% Ink Black)
  └── B.4 — Button row (Retry left, Abandon right, 16 px gap, 16 px from card bottom)
```

**Anchor specification (1080p baseline):**

| Zone | Anchor | Size | Position | Z-order (`CanvasLayer.layer`) |
|---|---|---|---|---|
| A — Modal backdrop | Full viewport | `1920 × 1080 px` | `(0, 0)` | 20 (ModalScaffold per C.4) |
| B — Card body | Centered | `400 × 200 px` | `(760, 440)` | 20 |
| B.1 — Header band | Card top edge | `400 × 28 px` | inside card top | 20 |
| B.2 — Body text | Card center | `380 × ~80 px` | 10 px H margin; vertical centered between header + button row | 20 |
| B.3 — Divider | Below body text | `380 × 1 px` | 8 px above button row | 20 |
| B.4 — Button row | Card bottom edge | each button `140 × 28 px`; row width = 140 + 16 + 140 = 296 px | horizontally centered (52 px L/R margin); 16 px from card bottom | 20 |

**Aspect-ratio / scaling behavior**: Card is fixed-pixel; UI scaling (`Settings.ui_scale` 75–150% per accessibility-requirements.md G.3) re-sizes the entire card proportionally via `project_theme.tres` font scale + a parent `Control.scale` on ModalScaffold. At 75% the card renders at 300 × 150 px; at 150% it renders at 600 × 300 px. Centering anchor remains unchanged.

**B.2 BodyLabel font scale floor**: BodyLabel `minimum_font_scale` is clamped at 1.0; the label ignores `Settings.ui_scale` values below 1.0. Above 1.0, the label scales linearly with `Settings.ui_scale` up to the menu UI maximum. This preserves the 10 px source size as a hard floor per V.9 #8 (safety-critical error copy must remain readable at all supported UI scale settings).

### Component Inventory

| Zone | Component | Type | Asset / Theme | Interactive? | Pattern |
|---|---|---|---|---|---|
| A | Modal backdrop | `ColorRect` | `Color8(26, 26, 26, 132)` (52% alpha) | No (`MOUSE_FILTER_STOP` to absorb stray clicks per Menu System C.4) | n/a |
| B | Card panel | `PanelContainer` w/ `StyleBoxFlat` | `bg_color = Parchment #F2E8C8`; hard 0 px corners; no shadow; no gradient | No | n/a |
| B.1 | Header band | `ColorRect` (or `PanelContainer` with `StyleBoxFlat`) | PHANTOM Red `#C8102E` fill; full card width × 28 px | No | n/a |
| B.1 | Header label | `Label` | DIN 1451 12 px Parchment `#F2E8C8`; left-aligned with 10 px left margin; text = `tr("menu.save_failed.title")` → `DISPATCH NOT FILED` | No | n/a |
| B.2 | Body line 1 (failure reason + slot id) | `Label` | American Typewriter 10 px Ink Black `#1A1A1A`; left-aligned; text per `FailureReason` mapping below | No (text only) | n/a |
| B.2 | Body line 2 (reassurance) | `Label` | American Typewriter 10 px Ink Black 70% opacity (visually deprioritized); left-aligned; text = `tr("menu.save_failed.reassurance")` → `Previous dispatch on file is intact.` | No | n/a |
| B.3 | Divider | `ColorRect` 1 px tall | 70% Ink Black opacity | No | n/a |
| B.4 | Retry button | `Button` w/ `StyleBoxFlat` per V.5 | PHANTOM Red `#C8102E` fill; Parchment text; DIN 1451 12 px; hard 0 px corners; **default focus on mount** with 2 px Parchment border | Yes — `ui_accept` activates retry path | Retry button uses the attention-color register from `save-failed-advisory` pattern (PHANTOM Red `#C8102E` fill, Parchment text). NOT a destructive button — the destructive action in this modal is Abandon. |
| B.4 | Abandon button | `Button` | BQA Blue `#1B3A6B` fill; Parchment text; DIN 1451 12 px; hard 0 px corners | Yes — `ui_accept` activates abandon path; `ui_cancel` from anywhere triggers Abandon | n/a |

> **NEW STRING REQUIRED**: `menu.save_failed.reassurance` is not in Menu System §C.8. Proposed: `Previous dispatch on file is intact.` (35 chars) — fits L212 cap; conveys atomicity guarantee. Coord with localization-lead.

### `FailureReason` → body-text mapping

| `FailureReason` enum value | Trigger | Body line 1 (English) | Body line 1 tr-key | Button variant |
|---|---|---|---|---|
| `IO_ERROR` | `ResourceSaver.save()` returned non-OK; `ResourceLoader.load()` returned null on an existing path | `Write error — Dispatch {n} could not be filed.` | `menu.save_failed.body.io_error` | Two buttons: Retry (PHANTOM Red, default focus) + Abandon (BQA Blue) |
| `DISK_FULL` (if Save/Load differentiates post-MVP) | OS write error specifically due to free space | `Filing cabinet full — Dispatch {n} could not be filed.` | `menu.save_failed.body.disk_full` | Two buttons: Retry (PHANTOM Red, default focus) + Abandon (BQA Blue) |
| `VERSION_MISMATCH` | Save's `save_format_version` < current `FORMAT_VERSION` | `Dispatch {n} was filed in an earlier edition. Cannot be opened.` | `menu.save_failed.body.version_mismatch` | **Single `[Acknowledge]` button only** (BQA Blue, primary). Retry is hidden — re-attempting a version-mismatched load is a no-op. |
| `CORRUPT_FILE` | `ResourceLoader.load()` returns null/wrong type on a present `.res` | `Dispatch {n} is damaged. Cannot be opened.` | `menu.save_failed.body.corrupt` | **Single `[Acknowledge]` button only** (BQA Blue, primary). Retry is hidden — re-attempting a corrupt-file load is a no-op. |
| Unknown / fallback | Defensive — any unhandled `FailureReason` | `Dispatch {n} could not be filed.` | `menu.save_failed.body.fallback` | Two buttons: Retry (PHANTOM Red, default focus) + Abandon (BQA Blue) |

`{n}` template substitution: `0` renders as the locale-appropriate `Autosave` (per Menu System §C.8 `menu.save.card_slot_zero`); `1`–`7` render as `Dispatch {n}`. Quicksave is treated as slot 0.

**For LOAD failures** (`VERSION_MISMATCH` / `CORRUPT_FILE` from `load_from_slot`): the dialog renders a **single `[Acknowledge]` button** (BQA Blue, primary — NOT PHANTOM Red destructive). Retry is hidden entirely; there is nothing to retry when a file is version-mismatched or corrupt. On Acknowledge, the modal dismisses and focus returns to the originating Save/Load card. Esc also maps to Acknowledge in this variant.

### ASCII Wireframe

**1080p baseline; modal centered on viewport, 52% Ink Black backdrop above the mounting parent (Pause Menu / Main Menu).**

```
┌──────────────────────────────────────────────────────────────────────┐
│ [MOUNTING PARENT VISIBLE BEHIND 52% INK BLACK BACKDROP]              │
│                                                                      │
│              ┌────────────────────────────────────────┐              │
│              │██ DISPATCH NOT FILED ████████████████ ██│ ← B.1 header
│              ├────────────────────────────────────────┤              │
│              │                                        │              │
│              │ Write error — Dispatch 3 could not be  │ ← B.2 line 1
│              │ filed.                                 │              │
│              │                                        │              │
│              │ Previous dispatch on file is intact.   │ ← B.2 line 2 (70% opacity)
│              │                                        │              │
│              ├────────────────────────────────────────┤ ← B.3 divider
│              │                                        │              │
│              │     ┌─────────────┐  ┌─────────────┐  │              │
│              │     │  ▌ Retry  ▐ │  │   Abandon   │  │ ← B.4 buttons
│              │     └─────────────┘  └─────────────┘  │              │
│              │      ↑ default focus                  │              │
│              │      (2 px Parchment border)          │              │
│              └────────────────────────────────────────┘              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                  ↑                                  ↑
                  card left edge @ x=760        card right edge @ x=1160
```

**Reading the wireframe:**
- Card `400 × 200 px` centered at viewport `(960, 540)`.
- PHANTOM Red header band `400 × 28 px` at top.
- Body text 2 lines, American Typewriter 10 px; line 1 is the failure-reason; line 2 is the reassurance.
- 1 px ruled divider between body and buttons.
- Two buttons centered horizontally at the bottom; Retry (PHANTOM Red, default focus) on the left; Abandon (BQA Blue) on the right.
- The mounting parent (Pause Menu folder, Main Menu shell, Save grid sub-screen) remains visible behind the backdrop — the modal is non-replacing.
- No `VU PAR` stamp (per V.5 — "rejection slips are bureaucratic rejections, not sealed intelligence"). No BQA seal. No paper-fibre noise outside the existing Parchment texture.

**Reduced-motion variant** (`Settings.accessibility.reduced_motion_enabled == true`): the 80 ms PHANTOM Red header band slide-in (V.7 row 5) is suppressed — the band appears at full position instantly. A8 paper-drop modal-appear cue still plays at full duration. The modal's appearance is a hard cut, not an animated reveal.

---

## States & Variants

| State / Variant | Trigger | What changes vs. Default | Reachability |
|---|---|---|---|
| **Default — modal mounted, post-appear-tween** | `ModalScaffold.show_modal(SaveFailedContent)` completes | Card visible; default focus on Retry; assertive AccessKit one-shot announcement fires once | Always (every mount) |
| **Appear-tween in-flight** | `show_modal()` called, 80 ms header slide-in tweening | Header band sliding down from card top; `process_input` on buttons disabled until tween completes (prevents same-frame button activation race) | First 80 ms of every mount |
| **Reduced-motion variant** | `Settings.accessibility.reduced_motion_enabled == true` | No 80 ms header tween; hard cut to default state | Determined at `_ready()` |
| **Retry in-flight** | Player activated Retry; `SaveLoad.save_to_slot(slot)` is running | Retry button `disabled = true` to prevent double-activation; visual: opacity 0.45; Abandon button remains enabled | First < 10 ms after Retry press (per ADR-0003 budget) |
| **Retry succeeded** | `Events.game_saved` fires for the same `slot` while modal is visible | Modal `hide_modal()`s automatically; pop `Context.MODAL`; focus returns to original mounting parent | After successful retry |
| **Retry failed** | A second `Events.save_failed` fires within retry window | Current modal `hide_modal()`s, then immediately re-mounts with the new failure reason (queue most-recent-wins) | After failed retry |
| **Queue-pending behind destructive confirm** | Save-failed fires while Quit-Confirm / Return-to-Registry / Re-Brief / New-Game-Overwrite modal is active (per C.4 queue policy) | Save-failed is queued in `_pending_modal_content`; the active destructive modal continues; on its dismiss, save-failed shows | Cluster B case 4 |
| **Save-failed-after-save-failed (most-recent-wins)** | Two `Events.save_failed` fire while a save-failed modal is already visible (e.g., autosave fails at the same moment as a manual save) | Current modal stays visible; the second event replaces `_pending_modal_content` (most-recent-wins per C.4); on Retry/Abandon dismiss, the second one shows | Cluster D case 2 |
| **AccessKit polite live-region update on body change** | `Events.save_failed` re-fires while modal is already visible AND the failure reason changed | The body Label text updates in-place (within the same modal instance); AccessKit `accessibility_live = "polite"` on the body Label announces the new text. The header `assertive` does NOT re-fire | Only if implementation chooses live-region-update over modal-replace; flagged in Open Questions |
| **Window focus lost during modal** | OS `NOTIFICATION_APPLICATION_FOCUS_OUT` while modal visible | Modal remains; cursor returns to OS default; on focus return, fountain-pen cursor restored per CR-17 | n/a (no special handling) |

**Empty / loading / error states**:
- **Empty state**: not applicable. The modal has no data-driven empty body — the body text is always populated from the `FailureReason`.
- **Loading state**: not applicable. Saves are < 10 ms per ADR-0003; loads include scene transitions which destroy this modal anyway.
- **Error state**: this dialog IS the error surface. There is no meta-level error state.

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse (Primary), Gamepad (Partial — full nav, rebind post-MVP)**.

### Modal interactions

| Action | KB/M binding | Gamepad binding | Immediate feedback | Outcome |
|---|---|---|---|---|
| Modal appears | n/a (event-driven mount) | n/a | A8 paper-drop modal-appear cue 50–70 ms (UI bus) + Audio's save-failed sting (~400 ms descending minor, SFX bus, owned by Audio per Audio L181) — both fire in parallel; assertive AccessKit one-shot announcement of header text | `show_modal()` called; `Context.MODAL` pushed; default focus on Retry after 80 ms tween |
| Activate focused button | `Enter` / `Space` | `JOY_BUTTON_A` | A1 typewriter clack 60–80 ms (UI bus); pressed-state visual: opacity 0.85 for 30 ms | Button-specific outcome (see below) |
| Move focus between buttons | `Tab` / `Shift+Tab` / `Right` / `Left` | `JOY_BUTTON_DPAD_RIGHT` / `_LEFT` / left-stick | (No audio cue on focus change in modal) | Focus alternates Retry ↔ Abandon; `focus_neighbor_*` wiring per ModalScaffold focus trap (CR-24) |
| Cancel / dismiss | `Esc` | `JOY_BUTTON_B` (`ui_cancel`) | A1 clack | Triggers Abandon path (regardless of focused button per Menu System §C.6 row "PauseMenu → ModalScaffold (any of: Quit-Confirm / Return-to-Registry / Re-Brief / Save-Failed)"); `set_input_as_handled()` BEFORE `pop()` |
| Mouse hover on button | Mouse over | n/a | No visual change (Pillar 5 V.9 #4) | Mouse hover does NOT change focus |
| Mouse click on button | Left mouse button down on button bounds | n/a | A1 clack + button outcome | Sets focus + activates button in one press |

### Per-button activation outcomes

| Button | Outcome on activate |
|---|---|
| **Retry** (PHANTOM Red, default focus) | A1 clack; Retry button `disabled = true`; calls `SaveLoad.save_to_slot(slot)` for the originally-failing slot; awaits next `Events.game_saved` (success → modal `hide_modal()`s) or `Events.save_failed` (failure → modal updates body or re-mounts per queue policy). |
| **Abandon** (BQA Blue) | A1 clack; A6 rubber-stamp thud (90–110 ms — destructive register matches the abandonment of the save attempt per Menu System §A.1 row A6); `ModalScaffold.hide_modal()`; pop `Context.MODAL`; return focus to mounting parent's last-focused element |

### Same-frame double-press protection

Per Menu System §C.6 + Input §Core Rule 7: every dismiss handler MUST call `get_viewport().set_input_as_handled()` BEFORE `InputContextStack.pop()`. Save-Failed `_unhandled_input()` follows this order. Pattern: `set-handled-before-pop`.

### Mouse-mode contract

The modal inherits `MOUSE_MODE_VISIBLE` from its mounting parent (Pause / MainMenu sets this). The modal does NOT toggle mouse-mode itself. On dismiss, the mounting parent's mode persists.

### Focus trap

**Two-button variant** (`IO_ERROR` / `DISK_FULL` / fallback): `focus_neighbor_left` on Retry → Abandon; `focus_neighbor_right` on Retry → Abandon; reciprocal on Abandon. Tab cycles between the two buttons only; cannot escape to the mounting parent's controls underneath (CR-24).

**Single-button variant** (`VERSION_MISMATCH` / `CORRUPT_FILE`): focus is on `[Acknowledge]` on mount. Tab and Shift-Tab have no other button to cycle to — focus stays on `[Acknowledge]`. Esc maps to `[Acknowledge]` (dismiss). Gamepad D-pad directional inputs (Left/Right/Up/Down) are consumed and ignored — no wrap, no AT announcement, no visual change (mirrors single-button OS dialog convention). There is no Cancel/Confirm pair; `dual-focus-dismiss` pattern does not apply.

---

## Events Fired

The Save-Failed dialog is a pure consumer of `Events.save_failed` and a caller of `SaveLoad` retry/dismiss APIs. It does NOT emit gameplay events.

### Direct events fired

| Player Action | Event / Signal Fired | Payload | Bus / Owner | Notes |
|---|---|---|---|---|
| Modal mounts | `InputContextStack.push(Context.MODAL)` (direct call, not a signal) | n/a | InputContext autoload | Per Menu System CR-2 + C.4 |
| Modal dismisses (Abandon) | `InputContextStack.pop()` | n/a | InputContext autoload | Same |
| Modal dismisses (auto on retry success) | `InputContextStack.pop()` | n/a | InputContext autoload | Triggered by `Events.game_saved` subscription within modal |
| Retry activated | `SaveLoad.save_to_slot(slot, save_game)` (direct API call) | `slot: int`, `save_game: SaveGame` (re-uses the most-recent assembled SaveGame from the original failure) | SaveLoad autoload | Per Menu System AC-MENU-8.4 — same slot N as original failure |

### Audio cues fired (UI bus per Menu System A.2)

| Player Action | Audio cue | Bus | When fires |
|---|---|---|---|
| Modal appears | A8 modal-appear paper-drop (50–70 ms) | UI | At `show_modal()` |
| Retry / Abandon button activate | A1 typewriter clack (60–80 ms) | UI | On `pressed` |
| Abandon confirm (destructive — abandoning the save) | A6 rubber-stamp thud (90–110 ms) | UI | At Abandon press, frame 1 of stamp animation |

### Cross-cut audio (NOT owned by this dialog — listed for completeness)

| Cue | Owned by | When fires |
|---|---|---|
| Save-failed sting (~400 ms, descending minor two-note) | Audio (subscribed to `Events.save_failed`) | At the same instant as `show_modal()` — paired with A8 visually, but Audio's sting is on SFX bus and the dialog's A8 is on UI bus. Two cues coexist without collision. |
| `game_saved` chime (~200 ms soft tock) | Audio (subscribed to `Events.game_saved`) | If retry succeeds, fires alongside the modal's auto-dismiss |

### Persistent-state-modifying actions

| Action | What it writes | Coord with |
|---|---|---|
| Retry | Re-attempts `SaveLoad.save_to_slot(slot)` — writes `slot_N.res` + `slot_N_meta.cfg` + `slot_N_thumb.png` per ADR-0003 atomic write pattern; previous good slot file is preserved if retry also fails | Save/Load |

> **Architecture note**: Save-Failed dialog does NOT write directly to disk. Retry delegates to `SaveLoad.save_to_slot()` — the same API path as the original save attempt. This guarantees atomicity is consistent (no special "retry path" with different correctness properties).

### Telemetry / analytics events

Not yet authored. Future analytics candidates (deferred to post-MVP):
- `save_failed.shown` (with `failure_reason`, `slot`)
- `save_failed.dismissed` (with `route` ∈ {retry, abandon})
- `save_failed.retry_succeeded` / `save_failed.retry_failed`

These would be invaluable for catching systemic Save/Load issues in the wild but are NOT in scope for MVP+VS.

---

## Transitions & Animations

All animation timings reference Menu System §V.7 row 5 (header-band slide-in) + §V.7 row 4 (stamp slam-down). This spec adds reduced-motion variants and modal-specific rules.

### Modal-appear

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Header band slide-in | `position.y` from `-28 px` (above card top) to `0` | `TRANS_LINEAR` | 80 ms | Per V.7 row 5 — PHANTOM Red header slides down from top of card |
| Card body fade-in | `modulate.a` 0 → 1 | `TRANS_LINEAR` | 80 ms | Concurrent with header slide |
| Backdrop alpha | (instant — no tween) | n/a | 0 ms | ModalScaffold's 52% Ink Black backdrop appears immediately when `show_modal()` mounts (per Menu System C.4 — backdrop is not separately tweened) |
| `process_input` on buttons | `false` → `true` | (state flip) | 80 ms (after tween) | Prevents same-frame button race |

**Audio sync**: A8 paper-drop modal-appear cue (50–70 ms) fires at `show_modal()` start (frame 0). Audio's save-failed sting (~400 ms) fires at the same instant on a separate bus (SFX). Both audible together; no collision.

**Reduced-motion variant**:
- Header band slide tween suppressed — band appears at final position instantly
- Card body fade tween suppressed — visible at `modulate.a = 1` instantly
- A8 audio cue still plays at full duration
- `process_input = true` immediately

### Modal-dismiss

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Card body fade-out | `modulate.a` 1 → 0 | `TRANS_LINEAR` | 60 ms | Faster than appear (matches modal-family convention from `quit-confirm.md`) |
| ModalScaffold backdrop fade | (instant — no tween) | n/a | 0 ms | Backdrop disappears with `hide_modal()` |
| `queue_free()` content | (deferred to fade end via `tween.finished`) | n/a | t = 60 ms | After fade |
| Pop `Context.MODAL` | (deferred to AFTER `queue_free()`) | n/a | t = 60 ms + 1 frame | Per Input Core Rule 7 |
| Mounting parent focus restore | `call_deferred("grab_focus")` on `return_focus_node` | n/a | t = 60 ms + 1-2 frames | Per ModalScaffold C.4 |

**Audio sync**: A1 typewriter clack on the dismiss button press (frame 0). If Abandon path: A6 rubber-stamp thud also at frame 0 (destructive register — abandoning the save IS destructive intent). Both on UI bus; no collision.

**Reduced-motion variant**: card body disappears instantly; `queue_free()` + pop fire same frame; A1 + A6 cues still fire at full duration.

### Retry-in-flight (button disable visual)

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Retry button opacity | `modulate.a` 1.0 → 0.45 | (instant — state flip) | 0 ms | On Retry press, button immediately reads as disabled |
| Retry button `disabled` | `false` → `true` | (state flip) | 0 ms | Prevents double-activation |
| Resolution | (waits for `Events.game_saved` or `Events.save_failed`) | n/a | typically < 10 ms (ADR-0003 budget) | If success: modal auto-dismisses. If failure: modal updates body or re-mounts per queue. |

### Stamp-slam (Abandon confirm)

CANONICAL via `quit-confirm.md` + Menu System §V.7 row 4. 100 ms scale 0% → 120% → 100%; A6 rubber-stamp thud at frame 1. Reduced-motion suppresses scale tween but A6 plays.

### Motion-sickness audit

- **No camera movement** during modal — modal is decoupled from gameplay camera.
- **No looping animations** on the modal — header band slides once, card fades once, stamp slams once.
- **No flashing / strobe** on the modal — PHANTOM Red header band is a static color fill, not a flash.
- **80 ms slide-in** is below WCAG 2.3 photosensitivity threshold and well within motion-safe range.

Save-Failed is therefore safe under Game Accessibility Guidelines "Motion (Vestibular Disorders)" Standard tier without further mitigation.

---

## Data Requirements

The Save-Failed dialog is **read-only** for game state. It re-uses the SaveGame payload from the original failed attempt for retry; it does not assemble fresh state.

| Data | Source System | Read / Write | Cardinality | Notes |
|---|---|---|---|---|
| `FailureReason` enum value | `Events.save_failed` payload | Read (event) | 1 enum | Drives body-text mapping |
| `slot: int` | `Events.save_failed` payload | Read (event) | 1 int | Identifies which save failed; used for retry target + body-text substitution |
| Cached `SaveGame` payload (for retry) | Tracked by ModalScaffold or save-failed content | Read | 1 SaveGame | The most-recent assembled SaveGame that the original `save_to_slot` was given. NOT re-assembled fresh per Menu System CR-10 — retry uses the same payload. |
| Localized body strings | Localization Scaffold | Read | 1 string per `FailureReason` (5 strings) | Per Menu System §C.8 + this spec's NEW STRINGS |
| `Settings.accessibility.reduced_motion_enabled` | SettingsService | Read | 1 bool | At `_ready()`; gates the header tween |
| `Settings.ui_scale` | SettingsService | Read | 1 float | Inherited via `project_theme.tres` |

### Architectural concerns

**No game-state mutation by Save-Failed dialog itself** — Retry delegates to `SaveLoad.save_to_slot()`. The dialog never touches `SaveGame` fields directly.

**No game-state polling** — there is no `_process()` loop. The dialog reacts to `Events.game_saved` / `Events.save_failed` subscriptions only, and to button activation.

**SaveGame payload caching**: Menu System CR-10 + AC-MENU-8.4 specify "most recent target tracked". The cache is held in the Save-Failed content node's instance variable: `var _retry_slot: int` and `var _retry_payload: SaveGame`. Both are populated by the modal's `setup(reason, slot, payload)` method called by the mounting parent. Cache lifetime = modal lifetime; on `_exit_tree()`, both are cleared.

**Memory cost**: a SaveGame is ≤ 10 KB per ADR-0003. Holding one in modal memory for the < 10 ms retry window is negligible. No leak risk if `_exit_tree()` cleanup runs.

### Forbidden data reads

To preserve Pillar 5 + the dialog's narrow purpose:

| Data | Why forbidden |
|---|---|
| `Player.health_current` / inventory / mission state | Save-Failed is about the I/O event, not the in-game state. The body never references gameplay context. |
| `FailureReason` raw OS error code (`errno`) | The body translates to player-readable register; raw OS codes are debugging noise. Save/Load may *log* the OS code internally but the dialog never displays it. |
| Save thumbnail / metadata of the failing slot | Not relevant to recovery; would clutter a 400 × 200 px card. |
| Time-of-failure timestamp | Not surfaced. The player knows it just happened. |
| Free disk space / OS-reported quota | Not surfaced (would require platform API queries — out of scope at MVP+VS; the body hint "Filing cabinet full" is sufficient). |

---

## Accessibility

**Tier**: Standard.

Save-Failed inherits most accessibility patterns from `quit-confirm.md` (CANONICAL Case File register modal). This section enumerates only what differs.

### Keyboard-only navigation

- **Default focus on mount: Retry** (PHANTOM Red, attention color).
- **Tab / Shift-Tab cycles between Retry and Abandon** only — focus trap (CR-24).
- **Esc triggers Abandon** regardless of focused button (per Menu System §C.6 row for ModalScaffold).
- **Enter on Retry** = retry path; **Enter on Abandon** = abandon path.

### Gamepad navigation

- **A button** = `ui_accept` activates focused button.
- **B button** = `ui_cancel` triggers Abandon (same as Esc).
- **D-pad / left-stick left/right** = focus alternation.

### AccessKit per-widget table

Inherits Menu System §C.9 conventions. Save-Failed shell adds:

| Widget | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| Save-Failed modal root (ModalScaffold + SaveFailedContent) | `dialog` | `tr("menu.save_failed.title")` → "DISPATCH NOT FILED" | `tr("menu.save_failed.body.<reason>")` (full body line 1 for the current `FailureReason`) — per Menu System CR-21 + photosensitivity-warning precedent (modal root description = body text so AT announces with the dialog) | `assertive` one-shot on appearance (CR-21 + F.7); cleared to `"off"` next frame via `call_deferred` |
| Header band Label | `text` | `tr("menu.save_failed.title")` | (none — already announced via root) | `off` |
| Body line 1 Label | `text` | `tr("menu.save_failed.body.<reason>")` | (none) | `polite` (live-region update if body changes during retry chain — flagged in Open Questions) |
| Body line 2 Label (reassurance) | `text` | `tr("menu.save_failed.reassurance")` | (none) | `off` |
| Retry button | `button` | `tr("menu.save_failed.retry")` → "Retry" | `tr("menu.save_failed.retry.desc")` → "Try filing the dispatch again." (NEW STRING) | `off` |
| Abandon button | `button` | `tr("menu.save_failed.dismiss")` → "Abandon" | `tr("menu.save_failed.dismiss.desc")` → "Close this advisory without filing. Previous dispatch on file is intact." (NEW STRING) | `off` |

> **2 NEW STRINGS REQUIRED** for AccessKit descriptions. Coord with localization-lead. Both are advisory-tier descriptions; both are well within Localization L212 cap (Retry desc ≈ 32 chars; Abandon desc ≈ 76 chars — over 25-char cap but desc strings have no cap per the Menu System §C.8 convention).

### Visual accessibility

- **Contrast**:
  - Header band Parchment `#F2E8C8` on PHANTOM Red `#C8102E` ≈ 4.7:1 → passes WCAG AA.
  - Body Ink Black `#1A1A1A` on Parchment `#F2E8C8` ≈ 14.8:1 → passes AAA.
  - Retry button Parchment text on PHANTOM Red ≈ 4.7:1 → passes AA.
  - Abandon button Parchment text on BQA Blue `#1B3A6B` ≈ 8.4:1 → passes AAA.
- **Color-as-only-indicator**: PHANTOM Red header is reinforced by typed text `DISPATCH NOT FILED` (textual signal). Retry button is distinguished from Abandon by **label** + **default focus border** + **horizontal position** (left vs right) in addition to color. No information is color-only.
- **Text size**: Header 12 px DIN 1451; body 10 px American Typewriter; button labels 12 px DIN 1451. BodyLabel font scale is floor-clamped at 1.0 per the B.2 layout rule (see Layout Specification → B.2 BodyLabel font scale floor), so `Settings.ui_scale` values below 1.0 have no effect on the body — it renders at its source 10 px regardless. This satisfies V.9 #8 and SC 1.4.4. Above 1.0, body scales linearly with ui_scale.
- **Colorblind**:
  - PHANTOM Red header on Parchment: protanopia/deuteranopia render the red as desaturated brown — still distinguishable from BQA Blue header (used in photosensitivity-warning) and Ink Black header (used in quit-confirm). Tritanopia: red shifts to dark brown — distinguishable.
  - Retry vs Abandon button colors (PHANTOM Red vs BQA Blue): in colorblind modes, the buttons remain visually distinct via labels + focus border + position. Compliant.

### Photosensitivity

- **No flashing on this modal.** PHANTOM Red header is a static color fill, not a flash.
- **80 ms header band slide is a 2D translation**, not a brightness change. WCAG 2.3.1/2.3.2 do not apply.
- The 52% Ink Black backdrop appears instantly (no fade tween) — single luminance step, not flashing.

Compliant by absence.

### Reduced-motion

Honored via `Settings.accessibility.reduced_motion_enabled`:
- Header band slide tween suppressed (hard cut to final position).
- Card body fade-in tween suppressed (visible at full opacity instantly).
- Stamp-slam scale tween (Abandon confirm) suppressed.
- **Audio cues unchanged** per Menu System §A.5 (audio is NOT reduced-motion-gated).

### Screen-reader walkthrough

1. `Events.save_failed` fires while Pause is open → modal mounts → **assertive** announcement: "DISPATCH NOT FILED, dialog. Write error — Dispatch 3 could not be filed."
2. Focus on Retry → "Retry, button. Try filing the dispatch again."
3. Player presses Tab → focus on Abandon → "Abandon, button. Close this advisory without filing. Previous dispatch on file is intact."
4. Player presses Tab again → cycles back to Retry (focus trap).
5. Player presses Esc → Abandon path executes; modal closes; focus returns to mounting parent.

Manual walkthrough captured at `production/qa/evidence/save-failed-dialog-screen-reader-walkthrough-[date].md` per accessibility-requirements.md AccessKit test plan row.

### Accessibility carve-outs

None required. Save-Failed has no Pillar 5 conflict with WCAG.

---

## Localization Considerations

### Strings owned by this spec (NEW — to be added to Menu System §C.8)

| tr-key | English | English chars | Layout-critical? | Notes |
|---|---|---|---|---|
| `menu.save_failed.body.io_error` | Write error — Dispatch {n} could not be filed. | 47 + slot id | YES — must fit body line 1 area (~ 380 px wide × 1 line at 10 px) | Body template; substitutes `{n}` |
| `menu.save_failed.body.disk_full` | Filing cabinet full — Dispatch {n} could not be filed. | 53 + slot id | YES | Body template (post-MVP — only if `DISK_FULL` enum is differentiated) |
| `menu.save_failed.body.version_mismatch` | Dispatch {n} was filed in an earlier edition. Cannot be opened. | 60 + slot id | YES — may overflow at 40% expansion in DE/FR | Body template for load failures |
| `menu.save_failed.body.corrupt` | Dispatch {n} is damaged. Cannot be opened. | 41 + slot id | YES | Body template for load failures |
| `menu.save_failed.body.fallback` | Dispatch {n} could not be filed. | 30 + slot id | YES | Defensive fallback |
| `menu.save_failed.reassurance` | Previous dispatch on file is intact. | 35 | YES — body line 2 | Reassurance line; conveys atomicity guarantee |
| `menu.save_failed.retry.desc` | Try filing the dispatch again. | 30 | No (AccessKit desc) | Retry button accessibility_description |
| `menu.save_failed.dismiss.desc` | Close this advisory without filing. Previous dispatch on file is intact. | 76 | No (AccessKit desc) | Abandon button accessibility_description |

### Strings already locked (Menu System §C.8) — referenced but not re-declared

| tr-key | English | English chars |
|---|---|---|
| `menu.save_failed.title` | DISPATCH NOT FILED | 18 |
| `menu.save_failed.body_alt` | Write error. Retry? | 19 (legacy) |
| `menu.save_failed.retry` | Retry | 5 |
| `menu.save_failed.dismiss` | Abandon | 7 |

> **Conflict resolution note**: Menu System §C.8 has `menu.save_failed.body_alt` ("Write error. Retry?", 19 chars) as the legacy single-line body. This spec proposes a richer body with reason-specific templates (`io_error` / `disk_full` / `version_mismatch` / `corrupt` / `fallback`) PLUS a separate reassurance line. Coord with localization-lead at review: deprecate `body_alt`, replace with the new mapping. The new mapping is more accessible (clearer cause hint) without sacrificing brevity.

### Expansion budget

Body text area is ~ 380 px wide at 1080p, rendered in American Typewriter 10 px (advance width ≈ 5.4 px per char average → ~70 char fits one line). Two-line body wrap is permitted.

| English | EN chars | At 40% expansion | At 60% expansion | Within 70-char single line? |
|---|---|---|---|---|
| Write error — Dispatch 3 could not be filed. | 47 | 66 | 75 | At 40% — fits. At 60% — wraps to 2 lines (acceptable). |
| Filing cabinet full — Dispatch 3 could not be filed. | 53 | 74 | 85 | At 40% — wraps. At 60% — wraps. |
| Dispatch 3 was filed in an earlier edition. Cannot be opened. | 60 | 84 | 96 | Wraps at 40%; may need 3 lines at 60% — **risk** flagged. |
| Dispatch 3 is damaged. Cannot be opened. | 41 | 57 | 66 | Fits. |

**Conclusion**: Body strings have moderate expansion risk for German/French. The card height (200 px) accommodates up to ~3 lines of body text (10 px line + 4 px leading × 3 = 42 px); current layout assumes 2 lines. If a locale exceeds 3 lines, **the card height grows from 200 px to ~240 px** (matching the photosensitivity-warning modal pattern per AC-MENU-6.6). Coord with localization-lead.

### Layout-critical strings (HIGH PRIORITY for localization-lead)

All five `body.*` keys are layout-critical. They must:
- Fit within 380 px width at 10 px American Typewriter
- Wrap cleanly at 1–3 lines maximum
- Reference `Dispatch {n}` template substitution correctly (where `{n}` is a number 0–7)
- **Slot 0 special case**: when `{n} == 0`, the body should read `Autosave` instead of `Dispatch 0` per Menu System §C.8 `card_slot_zero` precedent. Translator brief MUST flag this conditional substitution.

### Number / date / currency formatting

Slot number `{n}` is rendered locale-appropriately by Localization (e.g., German uses `Dispatch 3` with no separator; French uses `Dispatch 3` — both Arabic numerals; no Roman numeral fallback). No date / currency on this modal.

### RTL support

Not committed at MVP+VS. Post-launch RTL would mirror:
- Retry button to the right; Abandon to the left
- Header text right-aligned with 10 px right margin
- Body text right-aligned

### `auto_translate_mode`

All static `Label`s use `AUTO_TRANSLATE_MODE_ALWAYS`. Dynamic body strings (with `{n}` substitution) use explicit `tr()` + `format()` and re-resolve on `NOTIFICATION_TRANSLATION_CHANGED`.

### Translator brief inputs

1. **Register**: 1965 BQA bureaucratic-rejection slip. The header `DISPATCH NOT FILED` is a stamp typeset (all caps, period typewriter register).
2. **Tone**: factual, brief, no apology, no exclamation points. The dispatcher is not sorry; the file simply did not get filed.
3. **{n} substitution**: must handle 0 → `Autosave` / 1–7 → `Dispatch {n}` conditional. NOT a simple printf — translator brief includes example renderings.
4. **Character cap**: prefer ≤ 70 chars per body line; ≤ 35 chars for reassurance.
5. **Atomicity reassurance**: the line `Previous dispatch on file is intact.` MUST translate to convey "your previous saved file is safe, this failure did not destroy it". Translator brief includes context.

### Coord items for localization-lead (before VS sprint)

- [ ] Add 8 NEW strings to Menu System §C.8 locked strings table.
- [ ] Confirm `body.*` template strings handle `{n} == 0 → Autosave` substitution in all locales.
- [ ] Confirm body-text wrapping fits at 40% expansion (German); evaluate 60% expansion fallback (card height grows from 200 → 240 px).
- [ ] Deprecate legacy `menu.save_failed.body_alt` in favor of new reason-specific mapping.

---

## Acceptance Criteria

### Mount & Default State

- [ ] **AC-SF-1.1 [Logic]** When `Events.save_failed.emit(IO_ERROR, 3)` fires while Pause Menu is active, `ModalScaffold.show_modal(SaveFailedContent)` is called within 1 frame, `InputContextStack.peek() == Context.MODAL`, and the underlying Pause Menu's button container retains `process_input == true` (non-blocking modal per CR-10).
- [ ] **AC-SF-1.2 [Visual]** Modal mount produces a screenshot showing: (a) PHANTOM Red header band 28 px tall full card width, (b) header text `DISPATCH NOT FILED` in DIN 1451 12 px Parchment, (c) body line 1 reads the failure reason with slot substitution, (d) body line 2 reads `Previous dispatch on file is intact.` at 70% opacity, (e) divider 1 px ruled line, (f) Retry button (PHANTOM Red fill) on the left with 2 px Parchment focus border, (g) Abandon button (BQA Blue fill) on the right.
- [ ] **AC-SF-1.3 [Logic]** After 80 ms header slide-in tween completes, `Retry` button has focus (`button.has_focus() == true`).
- [ ] **AC-SF-1.4 [Logic]** During the 80 ms tween, both buttons have `process_input == false`.
- [ ] **AC-SF-1.5 [Logic]** Modal mount fires A8 paper-drop audio cue (UI bus) at frame 0 of mount; Audio's separate save-failed sting (SFX bus, owned by Audio) fires at the same instant.

### Retry Path

- [ ] **AC-SF-2.1 [Logic]** Activating Retry calls `SaveLoad.save_to_slot(slot, payload)` with the SAME `slot` and SAME `SaveGame` payload that originally triggered the failure (verified by mocking SaveLoad and asserting argument identity).
- [ ] **AC-SF-2.2 [Logic]** During retry-in-flight, Retry button has `disabled == true` and `modulate.a == 0.45`.
- [ ] **AC-SF-2.3 [Logic]** If retry succeeds (`Events.game_saved` fires for `slot`), modal `hide_modal()`s within 1 frame, `Context.MODAL` is popped, and focus returns to the mounting parent's `return_focus_node`.
- [ ] **AC-SF-2.4 [Logic]** If retry fails (`Events.save_failed` fires again), the queue policy applies: most-recent body replaces the existing modal's body Label text in-place (no full re-mount); AccessKit polite live-region announces the new body.
- [ ] **AC-SF-2.5 [Integration]** Pressing Retry repeatedly with continuous failures does not leak modal nodes — `get_tree().get_node_count()` returns to baseline ±5 nodes after 10 retry-fail cycles + final dismiss.

### Abandon Path

- [ ] **AC-SF-3.1 [Logic]** Activating Abandon calls `ModalScaffold.hide_modal()` within 1 frame; pops `Context.MODAL`; does NOT call `SaveLoad.save_to_slot()`.
- [ ] **AC-SF-3.2 [Logic]** Pressing `Esc` (or `JOY_BUTTON_B`) while modal is open triggers Abandon path regardless of focused button.
- [ ] **AC-SF-3.3 [Logic]** Abandon press fires A1 typewriter clack + A6 rubber-stamp thud (both UI bus).
- [ ] **AC-SF-3.4 [Logic]** After Abandon, focus returns to the mounting parent's `return_focus_node` (e.g., the Save card slot N's `[CONFIRM]` button if save was triggered from Save grid).

### Queue Policy (per Menu System C.4)

- [ ] **AC-SF-4.1 [Integration]** Save-failed-then-save-failed (most-recent-wins): if a second `Events.save_failed` fires while modal is already visible, the body text updates to the most-recent failure; `_pending_modal_content` is consumed; queue depth never exceeds 1.
- [ ] **AC-SF-4.2 [Integration]** Destructive-then-save-failed: if `Events.save_failed` fires while a Quit-Confirm modal is active, save-failed is queued in `_pending_modal_content`; on Quit-Confirm dismiss (Cancel), save-failed shows immediately.
- [ ] **AC-SF-4.3 [Integration]** Save-failed-active-then-destructive: if a destructive modal request arrives while save-failed is the active modal, the destructive request is rejected with `push_error("ModalScaffold: rejected non-idempotent modal request while modal already active")`; player must dismiss save-failed first.

### Failure-Reason Mapping

- [ ] **AC-SF-5.1 [Logic]** `IO_ERROR` → body line 1 = `tr("menu.save_failed.body.io_error", {n=3})` → "Write error — Dispatch 3 could not be filed."
- [ ] **AC-SF-5.2 [Logic]** Given `FailureReason` is `VERSION_MISMATCH` or `CORRUPT_FILE`, the dialog renders a single `[Acknowledge]` button (BQA Blue, primary — no Retry). On Acknowledge, the modal dismisses and focus returns to the originating Save card. Esc maps to Acknowledge in this variant.
- [ ] **AC-SF-5.3 [Logic]** Given `FailureReason` is `VERSION_MISMATCH` or `CORRUPT_FILE`, no Retry button is present in the scene tree (`find_child("RetryButton")` returns null); `SaveLoad.save_to_slot()` is never called; focus trap contains only the single `[Acknowledge]` button.
- [ ] **AC-SF-5.4 [Logic]** Unknown / fallback `FailureReason` → body = `Dispatch 3 could not be filed.`
- [ ] **AC-SF-5.5 [Logic]** Slot 0 → body substitutes `Autosave` for `Dispatch 0`.
- [ ] **AC-SF-5.6 [Logic]** Given `FailureReason` is `IO_ERROR` or `DISK_FULL`, the dialog retains the two-button layout: Retry (PHANTOM Red, default focus) on the left and Abandon (BQA Blue) on the right. Focus trap cycles between both buttons; Esc triggers Abandon.

### AccessKit / Screen Reader

- [ ] **AC-SF-6.1 [UI]** Modal root has `accessibility_role = "dialog"`, `accessibility_name = tr("menu.save_failed.title")`, `accessibility_description = tr("menu.save_failed.body.<current-reason>")`, `accessibility_live = "assertive"` set BEFORE `show_modal()` returns; cleared to `"off"` next frame via `call_deferred`.
- [ ] **AC-SF-6.2 [UI]** Manual screen-reader walkthrough (Linux Orca / Windows Narrator): on mount, AT announces "DISPATCH NOT FILED, dialog. {body line 1}." within 500 ms. Each button announces name + description on focus. Tab cycles between Retry and Abandon only. Evidence: `production/qa/evidence/save-failed-screen-reader-[date].md`.
- [ ] **AC-SF-6.3 [Logic]** On `NOTIFICATION_TRANSLATION_CHANGED`, all `accessibility_name` and `accessibility_description` re-resolve via `tr()`.

### Reduced-Motion

- [ ] **AC-SF-7.1 [Integration]** With `accessibility.reduced_motion_enabled == true`, header band appears at final position instantly (no 80 ms tween); card body opacity is 1 instantly; A8 audio cue still plays at full duration.
- [ ] **AC-SF-7.2 [Integration]** Stamp-slam scale tween on Abandon confirm is suppressed under reduced-motion; A6 audio cue still plays.

### Visual Compliance

- [ ] **AC-SF-8.1 [Visual]** No corner radius on card or buttons. No drop shadow. No gradient. Per V.9 #1, #2, #3.
- [ ] **AC-SF-8.2 [Visual]** No `VU PAR` stamp on Save-Failed card (per V.5 — rejection slips are unsealed).
- [ ] **AC-SF-8.3 [Visual]** Retry button uses PHANTOM Red `#C8102E` fill — verify `bg_color` matches palette constant.
- [ ] **AC-SF-8.4 [Visual]** No flashing or strobing. The PHANTOM Red header is a static fill.
- [ ] **AC-SF-8.5 [Logic]** Given `Settings.ui_scale = 0.75`, the BodyLabel renders at its source font size (10 px American Typewriter), not 7.5 px; verifiable by inspecting `Label.get_theme_font_size()` after applying ui_scale — result must equal 10 (not 7 or 8).

### State Invariants

- [ ] **AC-SF-9.1 [Logic]** During modal lifetime, `InputContextStack.peek() == Context.MODAL`.
- [ ] **AC-SF-9.2 [Logic]** Modal `_exit_tree()` calls `disconnect()` on every `Events.game_saved` / `Events.save_failed` subscription it added in `_ready()` (`is_connected()` returns `false` post-exit).
- [ ] **AC-SF-9.3 [Logic]** Modal does NOT modify any persistent file directly. Hashing `user://saves/*.res` before-and-after a Retry-fail cycle: hashes match (the failed retry did not write).
- [ ] **AC-SF-9.4 [Logic]** Modal's `_retry_slot` and `_retry_payload` instance variables are cleared (`null`) on `_exit_tree()`.

### Cross-Reference

- [ ] **AC-SF-10.1 [Spec-trace]** `quit-confirm.md` is APPROVED at the time of Save-Failed implementation start (CANONICAL pattern inheritance).
- [ ] **AC-SF-10.2 [Spec-trace]** Menu System §C.8 has 8 NEW strings added (per Localization Considerations); Save-Failed implementation does not start until strings are locked.

### Coverage

- Performance: 1 (AC-SF-1.5 audio timing; mount-to-visible < 80 ms verified by AC-SF-1.3)
- Navigation: 1 (AC-SF-3.2 cancel routing)
- Error / queue: 1 (AC-SF-4.1 — 4.3)
- Accessibility: 1 (AC-SF-6.1 — 6.3)
- Save-Failed-purpose-specific: 1 (AC-SF-2.1 — 2.5 retry path)

Total: 30 ACs across 10 groups. Proportionate to Menu System §H.8 4-AC scope (this spec elaborates the 4 to per-state coverage).

---

## Open Questions

| # | Question | Owner | Resolution Path | Default if unresolved |
|---|---|---|---|---|
| **OQ-SF-1** | **`DISK_FULL` differentiated from `IO_ERROR`?** Save/Load Edge Case L126 lumps disk-full into `IO_ERROR`; this spec proposes a differentiated `DISK_FULL` string for clearer player guidance. Is the differentiation worth the platform-API complexity? | Save/Load owner + lead-programmer | Defer to post-MVP. At MVP+VS, ship only `IO_ERROR` body; if disk-full is a common support case, add `DISK_FULL` later. | **MVP: single `IO_ERROR` body.** No `DISK_FULL` differentiation. |
| **OQ-SF-2** | **Body update vs full re-mount on retry-fail.** Spec proposes updating body Label in-place (with polite AccessKit live-region) when retry fails and `save_failed` re-fires; alternative is to fully `hide_modal()` + `show_modal()` (cleaner state but jarring AT announcement). | ux-designer + accessibility-specialist | Decide at `/ux-review`. In-place update is more usable but harder to implement safely (live-region update timing). | **In-place body update with polite live-region.** Validate AT behavior at first soak playtest. |
| **OQ-SF-3** | ~~**Body text 75% UI scale floor.**~~ **RESOLVED** | ux-designer | **RESOLVED 2026-04-29 via `/ux-review`**: Body text font scale clamped to 1.0 minimum; `ui_scale` below 1.0 has no effect on BodyLabel. Above 1.0, scales linearly. Rule lives in Layout Specification → B.2 BodyLabel font scale floor. AC-SF-8.5 covers the logic test. Per V.9 #8 — safety-critical error copy must remain readable. | — |
| **OQ-SF-4** | **Locale body line 3+ overflow.** German `version_mismatch` body at 60% expansion may exceed 3 lines. Card height grow from 200 → 240 px? | localization-lead + art-director | Resolve during VS locale pass. Card-height-grow pattern matches AC-MENU-6.6. | **Card height grows to 240 px** at 4-line body if a locale exceeds 3 lines. |
| **OQ-SF-5** | ~~**Retry-from-load-failure semantics.**~~ **RESOLVED** | ux-designer | **RESOLVED 2026-04-29 via `/ux-review`**: Single-button `[Acknowledge]` variant for `VERSION_MISMATCH` and `CORRUPT_FILE`; Retry hidden. `[Acknowledge]` is BQA Blue (primary), not PHANTOM Red destructive. Esc maps to `[Acknowledge]`. `IO_ERROR` and `DISK_FULL` retain the two-button (Retry / Abandon) layout unchanged. AC-SF-5.2, AC-SF-5.3, and AC-SF-5.6 codify the split. | — |
| **OQ-SF-6** | **Pause-cycle persistence.** If save-failed fires while Pause is closed (gameplay-time autosave fail), HSS handles it. But if the player then opens Pause and the failure is unresolved (e.g., disk still full), should this dialog re-mount on Pause open? | save-load + ux-designer | Per Pause OQ-PM-11 default: NO. Save-Failed does not persist across Pause unmount-remount. HSS owns the persistent display while Pause is closed. | **Save-Failed modal does not re-mount on Pause-open.** The HSS SAVE_FAILED state remains active until the next save attempt clears it. |
| **OQ-SF-7** | **Retry button keyboard shortcut?** Should Retry be activatable by `R` key in addition to Enter? Common in OS dialogs, but inconsistent with Pause Menu pattern (no shortcuts). | ux-designer | Decide at `/ux-review`. Inconsistency risk says no. | **No `R` shortcut.** Enter / Space / mouse click only. |
| **OQ-SF-8** | **Telemetry event scope.** Should `save_failed.shown` events fire for analytics? Critical for catching systemic Save/Load issues. | analytics-engineer + producer | Defer to post-MVP analytics scope decision. | **No telemetry at MVP+VS.** Hooks left as `// TODO(analytics)` comments. |

---

## Recommended Next Steps

- Run `/ux-review save-failed-dialog` to validate this spec
- Continue authoring remaining pending specs (`quicksave-feedback-card.md`, `load-game-screen.md`, `save-game-screen.md`)
- Resolve OQ-SF-5 (Retry-on-load-failure semantics) before VS implementation start
- Add 8 NEW strings to Menu System §C.8 lock table

Verdict: **COMPLETE** — UX spec authored from scratch in single Write per auto-mode efficiency.
