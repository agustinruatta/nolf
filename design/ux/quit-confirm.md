# UX Spec: Quit-Confirm Modal

> **Status**: In Design
> **Author**: user (agustin.ruatta@vdx.tv) + ux-designer
> **Last Updated**: 2026-04-29
> **Journey Phase(s)**: End-of-Session Decision Point (player just pressed Close File on Main Menu OR Quit Desktop on Pause Menu and is being asked to confirm before the application exits)
> **Implements Pillar**: Primary 5 (Period Authenticity Over Modernization — Case File register applies); Supporting 1 (Comedy Without Punchlines — bureaucratic stamp deadpan)
> **Phasing**: Day-1 MVP — required by `menu-system.md` CR-9 + AC-MENU-7.1 / 7.2 / 7.3
> **Template**: UX Spec
> **Authoritative GDD**: `design/gdd/menu-system.md` CR-9 (Quit-Confirm flow + locked string table lines 339–342) + AC-MENU-7.1 / 7.2 / 7.3 (modal lifecycle ACs)
> **Hosting Specs**: `design/ux/main-menu.md` (Z5 Modal layer mounts this via Close File button — Exit table row "`get_tree().quit()`") + `design/ux/pause-menu.md` (planned VS — Pause Menu's Quit-Desktop entry mounts the same scaffold)
> **Canonical Scaffold**: This spec is the **first concrete instance of the `modal-scaffold` pattern in the Case File register**. Three sibling modals inherit the structural decisions made here (visual frame, header band layout, button row layout, audio register, focus restoration pattern) verbatim — only their content differs:
> - `design/ux/return-to-registry.md` (CR-14, VS) — "RETURN TO REGISTRY" stamp + "Unsaved progress lost." body
> - `design/ux/re-brief-operation.md` (CR-13, VS) — "RE-BRIEF OPERATION" stamp + "Reload last checkpoint?" body
> - `design/ux/new-game-overwrite.md` (CR-6, MVP) — "OPEN NEW OPERATION" stamp + body per menu-system.md §C.8 `body_alt`
>
> Decisions in this spec that propagate 4× by inheritance are flagged in-line with **[CANONICAL]**. Any future revision to a [CANONICAL] decision requires updating all 4 modal specs.

---

## Purpose & Player Need

**Purpose**. This modal is the **destructive-action confirm gate** for application exit. It exists to satisfy a single player goal — **catch accidental quits** before the application terminates and the player loses any unsaved progress. The modal is not a barrier — it's a check. A player who definitely meant to quit completes the action in two presses (Close File → Close File) in roughly one second; a player who pressed Close File by accident (or on second thought wants to keep playing) presses Cancel (or Esc) and is back where they started.

**Player need on arrival**. The player arrives at this modal wanting to **be sure they actually mean to quit**. They have two distinct mental states:

- **The deliberate quitter** — done with the session, ready to close the application. Wants to confirm fast and exit. ~80% of arrivals (estimate per typical destructive-confirm modal usage).
- **The accidental quitter** — pressed Close File by reflex / mis-click / mistaken assumption. Wants to back out and continue. ~20% of arrivals.

The modal must serve both populations: fast for deliberate confirmation (default focus is on Cancel by safety convention, but Close File is one Tab away), zero-friction for accidental backout (Esc / Cancel / mouse-click-outside all return the player to Main Menu without state change).

**Failure mode if the modal is missing or hard to use**:

1. **Accidental quit lost progress**. Without a confirm modal, a single mis-press of Close File terminates the application immediately. Players who haven't manually saved lose mid-section progress between autosaves. This is the floor risk — the modal exists primarily to prevent it.
2. **Default focus on destructive button**. If default focus were on Close File (instead of Cancel), a player who pressed Close File on Main Menu and then pressed Enter (continuing the muscle-memory pattern) would immediately quit without reading the prompt. Default focus on Cancel ("Continue Mission") is a safety convention — explicit destructive action requires intent.
3. **Esc dismisses to wrong state**. If `ui_cancel` (Esc / B) on this modal accidentally triggered Close File instead of Cancel, players using Esc to back out (as they do everywhere else in the menu system) would quit unintentionally. Esc must always behave as Cancel here.
4. **Modal blocks the player who definitely wants to quit**. If the modal is too friction-laden (e.g., 5-second cooldown, "are you SURE? type the word YES") players who legitimately want to quit will resent it. The modal should be one-press-fast for the deliberate quitter — Tab → Enter (or click directly on Close File).

**Single-sentence formulation**. *"The player arrives at this modal wanting confirmation that pressing Close File will actually quit, OR a fast backout if the press was accidental — both paths must be obvious within one second of the modal appearing."*

**Pillar 5 register applies** (unlike `photosensitivity-boot-warning.md` which carves out). The modal is staged in the 1965 BQA Case File aesthetic per `menu-system.md` Player Fantasy: "the quit-confirm is not a modal popup; it is a stamped form: ***CLOSE FILE — Y/N***." The destructive action gets a rubber-stamp thud SFX; the Cancel path gets a paper-shuffle. Header band reads as a stamped classification on a manila folder, not as a system dialog. The bureaucratic-neutral voice ("Operation abandoned." not "Are you sure you want to quit?") is the joke — *Get Smart* CONTROL files rendered with absolute seriousness.

---

## Player Context on Arrival

**When the player first encounters this modal**: This modal mounts immediately upon the player activating the Close File button on Main Menu (CR-9) OR — at VS scope — the Quit Desktop button on Pause Menu. There is no boot-time entry path; this modal is **always player-initiated**, never sent-here by the game.

**Three arrival paths**:

| Arrival path | Frequency | Immediately before | Emotional register |
|---|---|---|---|
| **Main Menu → Close File** | Most common quit path; fires every time the player decides to quit from the Main Menu | Player navigated to Close File button (Tab + Enter, or click); button activated → `ModalScaffold.show_modal(QuitConfirmContent)` | **Deliberate** for ~80% of arrivals (player just decided to end the session); **accidental** for ~20% (mis-click, muscle memory, "did I really mean to press that?") |
| **Pause Menu → Quit Desktop** [VS] | Less common; player paused mid-mission and chose to quit-to-desktop instead of return-to-registry-then-quit | Player paused gameplay; navigated Pause Menu → Quit Desktop button | **Mid-mission deliberate** — usually because something external pulled them away (work, sleep, real-world interruption). Slight time pressure (player wants to be done with the modal quickly). Mid-mission progress at risk if not saved. |
| **Game-time quit (no Pause Menu intermediate)** [N/A] | Not supported in MVP — there is no `Esc → Quit Desktop` shortcut from gameplay. Player must Pause first. | n/a | n/a — not a real arrival path |

**Emotional state design assumes**. **Deliberate-but-cautious**. The player just made a decision and is now being asked to confirm it. The modal should NOT punish them for the decision (no friction-laden interactions, no scolding copy) but should give them an unambiguous reversibility option. The Pillar 5 Case File register reframes the friction as *bureaucratic seriousness* rather than *paranoia* — the modal stamps "CASE CLOSED" with theatrical gravity, but the action itself is one-press-fast.

**Voluntary or sent-here**. **Always voluntary.** The player chose to press Close File / Quit Desktop. The modal is a confirmation, not an imposition. This distinguishes it from `photosensitivity-boot-warning.md` (sent-here by boot poll) and from `save-failed-advisory` (sent-here by signal-driven failure event). Voluntary modals can default-Cancel safely because the player initiated the action and Cancel restores the prior state without loss.

**Decision: no explicit unsaved-progress warning**. CR-9's locked "Operation abandoned." body copy is sufficient — the bureaucratic-neutral phrase carries the consequence implicitly without modern-game-launcher chrome ("Are you sure? Unsaved changes will be lost!"). Pillar 5 forbids the latter register; the locked CR-9 text is the resolution. Players who don't want to lose progress are expected to use the explicit save mechanism (Pause Menu → File Dispatch in VS scope) before quitting — the modal does not duplicate that responsibility.

**What the screen must NOT assume about player context**:

- The player **may have unsaved gameplay progress** (especially in Pause Menu arrival path). The modal does NOT auto-save on confirm per CR-9 ("No save is triggered automatically on quit — the player is responsible for explicit saves"). The body copy "Operation abandoned." carries the consequence in Pillar 5 register.
- The player **may be using assistive tech** — `accessibility_role = "dialog"` + `accessibility_live = "assertive"` ensure AT announces the modal on mount.
- The player **may have pressed Close File from muscle memory** — the modal must not auto-confirm on a held Enter from the prior context. Held-key flush applies on mount per `held-key-flush-after-rebind` pattern (same as Main Menu / photosensitivity).
- The player **may want to quit AND lose all progress** (e.g., resetting a botched run). The modal does not prevent this; it only confirms intent. Saved state is preserved regardless of confirm — the modal does not delete saves.
- The player **may not be a fluent English reader** — body copy is short (20 chars in EN: "Operation abandoned.") and locale-translated.

---

## Navigation Position

**This modal is a transient overlay child of either `MainMenu` or `PauseMenu`** mounted via `ModalScaffold.show_modal(QuitConfirmContent)` per CR-9. It has no parent screen of its own — it is a side-effect of a specific button activation. It has two exit destinations: dismiss-back-to-host-menu (Cancel path) or terminate-application (Confirm path).

**Position summary**:

```
[MainMenu.tscn]  ──[Close File button]──►  ModalScaffold (CanvasLayer)
    OR                                          │
[PauseMenu (CanvasLayer overlay)] [VS]          └── QuitConfirmContent  ← (this modal)
                                                         │
                                                         ├── [Continue Mission] (Cancel) ──►  hide_modal() → focus restored to Close File / Quit Desktop button on host menu
                                                         │
                                                         └── [Close File] (Confirm) ──►  pop(Context.MENU or Context.PAUSE) → get_tree().quit() → application terminates
```

**Top-level vs context-dependent**: This modal is **strictly context-dependent** — it can only mount as a child of MainMenu or PauseMenu, in response to a player-initiated button press. It cannot be reached from Settings, from Operations Archive, from gameplay, or from any other screen.

**Sibling-of-which surface**: At the modal-scaffold level, this modal is a sibling of `PhotosensitivityWarningContent` (different register but same `ModalScaffold` host), `NewGameOverwriteContent`, and `SaveFailedContent`. Per `menu-system.md` C.4 depth-1-queue rule (most-recent-wins, never depth-2), the Quit-Confirm modal **never co-occurs** with another modal. If the player triggers Close File while a Save-Failed modal is already open, the Save-Failed dismisses first and Quit-Confirm opens after (per AC-MENU-8.3 most-recent-wins).

**Scaffold-pattern lineage**: This modal is the **first concrete instance of the Case File register applied to `modal-scaffold`**. Three sibling modals inherit this spec's structural decisions when they're authored:

- `return-to-registry.md` (CR-14) — same scaffold, different content
- `re-brief-operation.md` (CR-13) — same scaffold, different content
- `new-game-overwrite.md` (CR-6) — same scaffold, different content

Future modal additions in the Case File register MUST follow this spec's structural decisions (header band layout, button row pattern, audio register, focus restoration) verbatim. Modals NOT in the Case File register (Photosensitivity, hypothetical analytics-prompts) use their own structure per their own carve-outs.

**No deep-link**: Cannot be triggered from console / debug at MVP. Re-firing requires the player to navigate to Close File and press it again.

---

## Entry & Exit Points

**Entry Sources**:

| Entry Source | Trigger | Player carries this context | MVP/VS |
|---|---|---|---|
| **Main Menu → Close File button** | Player activates Close File button on Main Menu (CR-9) → `ModalScaffold.show_modal(QuitConfirmContent)` called by Main Menu | `Context.MENU` on stack from Main Menu mount; modal mount pushes `Context.MODAL` (depth-1 from MENU); host = Main Menu | MVP |
| **Pause Menu → Quit Desktop button** [VS] | Player activates Quit Desktop button on Pause Menu → same `ModalScaffold.show_modal(QuitConfirmContent)` call from Pause Menu | `Context.PAUSE` on stack from Pause Menu mount; modal mount pushes `Context.MODAL` (depth-1 from PAUSE); host = Pause Menu | VS (Pause Menu Quit Desktop is VS scope per menu-system.md C.2) |

**Exit Destinations**:

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Cancel — dismiss to host menu** (default focus path) | `[Continue Mission]` activated, OR `ui_cancel` (Esc / B), OR mouse-click outside modal rect | (a) `ModalScaffold.hide_modal()` called; (b) `Context.MODAL` pops; (c) host menu becomes interactive again; (d) focus restored to the originating button on host (Close File on Main Menu, Quit Desktop on Pause Menu); (e) **no SFX on Cancel** — see Section E3 audio register; (f) no state change persisted. Per AC-MENU-7.2. |
| **Confirm — terminate application** | `[Close File]` activated | (a) `pop(Context.MENU)` OR `pop(Context.PAUSE)` per host; (b) `get_tree().quit()` called; (c) application process exits; (d) **rubber-stamp thud SFX** plays on activation per Pillar 5 destructive-action audio convention; (e) **no save** triggered automatically per CR-9; (f) modal scene tree is destroyed by application exit, not by `hide_modal()` (one-way). Per AC-MENU-7.3. |
| **OS-level window close (Alt+F4 / Cmd+Q)** | Player closes window while modal is open | OS-level signal forces application exit. Modal does not get a chance to call `hide_modal()`. Equivalent outcome to Confirm path: application terminates, no save. The pre-quit modal acknowledgment was effectively bypassed — but the OS close is a stronger user signal than the modal's confirm gate. Acceptable. |

**Irreversible exits**: Confirm path (`get_tree().quit()`) is **irreversible at the application level** — once called, the OS process exits. The player can re-launch the game (which is a fresh cold boot, taking them back to Main Menu) but they cannot un-quit. The save state is whatever was persisted to `settings.cfg` and `slot_*.res` BEFORE the quit; nothing this modal does writes additional state.

**Cancel path is fully reversible**: state is unchanged. The player returns to the originating button (Close File on Main Menu / Quit Desktop on Pause Menu) with focus, and can either re-attempt the quit or do something else. No saves are touched, no settings change.

**State transitions on dismiss**:

```
    [Player presses Close File / Quit Desktop on host menu]
                 │
                 ▼
    [ModalScaffold.show_modal(QuitConfirmContent)]
    [Context.MODAL pushed; modal mounted; default focus → Continue Mission]
                 │
                 ├──[Continue Mission activated / ui_cancel / outside-click]
                 │       │
                 │       ▼
                 │   [hide_modal(); Context.MODAL pops; focus restored to host]
                 │   [No save written, no state change]
                 │
                 └──[Close File activated]
                         │
                         ▼
                    [Rubber-stamp thud SFX]
                    [pop(Context.MENU or Context.PAUSE); get_tree().quit()]
                    [Application terminates]
```

---

## Layout Specification

### Information Hierarchy

**Information items the modal must communicate** (full inventory):

| # | Item | Source | MVP/VS |
|---|---|---|---|
| 1 | Header stamp — `tr("menu.quit_confirm.stamp")` ("CASE CLOSED") in Ink Black band rendered as stamp graphic, rotated -5° per art-bible §7D Mission Card classification stamp convention | menu-system.md CR-9 + locked string table line 339 | MVP — **[CANONICAL]** scaffold-pattern decision (sibling modals will use the same band layout with their own stamp text) |
| 2 | Body copy — `tr("menu.quit_confirm.body_alt")` ("Operation abandoned.") | CR-9 + locked string table line 340 | MVP |
| 3 | Confirm button — `tr("menu.quit_confirm.confirm")` ("Close File"), Ink Black fill + Parchment text (destructive styling) | CR-9 + locked string table line 341 | MVP — **[CANONICAL]** destructive button styling rule for all Case File register modals |
| 4 | Cancel button — `tr("menu.quit_confirm.cancel")` ("Continue Mission"), BQA Blue fill + Parchment text (default focus, safe styling) | CR-9 + locked string table line 342 | MVP — **[CANONICAL]** safe-action button styling rule for all Case File register modals |
| 5 | Backdrop dim — Ink Black 52% opacity over host menu (Main Menu OR Pause Menu underneath) | `modal-scaffold` pattern + photosensitivity-boot-warning.md precedent | MVP — inherited from `modal-scaffold` |
| 6 | Modal card frame — Parchment fill with 2 px Ink Black border, hard-edged corners | photosensitivity-boot-warning.md precedent + art-bible §3.3 hard-edged-rectangle grammar | MVP — **[CANONICAL]** modal frame baseline for all 4 Case File modals |

**Ranking — what does the player need to see first?**

1. **Most critical**: **The header stamp ("CASE CLOSED")** — it's the visual anchor that reads as "destructive bureaucratic form" before the body is even read. A glance tells the player what kind of modal this is.
2. **Second**: **The body copy ("Operation abandoned.")** — confirms what's about to happen in plain bureaucratic-neutral prose. Short, factual, non-alarming.
3. **Third**: **The Cancel button (Continue Mission)** — default focus; reads as "I can back out of this". Visual weight (BQA Blue fill) draws the eye.
4. **Fourth**: **The Confirm button (Close File)** — visible but not the focus target; Ink Black destructive styling reinforces "this is the final action". Visually subordinate to Cancel by focus state.
5. **Discoverable, not visible at glance**: Backdrop dim and modal frame (composition primitives, not information).

**Conflict check — Pillar 5 stamp aesthetic vs functional clarity**:

The Pillar 5 register prioritizes **bureaucratic theatre** (stamped header, deadpan body, manila/dossier paper aesthetic). The functional UX prioritizes **fast confirm + obvious backout**. These align well in this case — the stamp IS the visual signal, the body IS the functional copy, the buttons ARE the interactive affordances. No conflict.

**The bureaucratic deadpan is the joke**: the stamp says "CASE CLOSED" with theatrical gravity for what is mechanically just `get_tree().quit()`. Per Player Fantasy: "The Case File never winks. Eve does not crack wise. The world quips around her."

### Layout Zones

**Selected arrangement**: **Option B — Same width as photosensitivity, shorter (880 × 200 px)**. Rationale: cross-modal width consistency with `photosensitivity-boot-warning.md` (880 px shared) preserves the "modal family" visual identity; shorter height (200 vs 280) reflects the shorter body content. **[CANONICAL]** for sibling modals: `return-to-registry.md`, `re-brief-operation.md`, `new-game-overwrite.md` all use 880 px width with body-length-driven height (200 px baseline; grow if body exceeds 1 line).

**Reference resolution**: 1920 × 1080 (technical-preferences.md target hardware floor). 16:9 only in MVP.

**Modal sizing** (1080p reference):

- **Modal card**: 880 × 200 px, centered horizontally and vertically. Height may grow per locale if body translation exceeds 1 line at 18 px (Open Question #1 below — same locale-overflow concern as photosensitivity-boot-warning.md OQ #7).
- **Backdrop dim**: full-screen `ColorRect` at Ink Black `#1A1A1A` 52% opacity (matches `desk_overlay_alpha = 0.52` from menu-system.md AC-MENU-2.5)
- **Outer modal padding**: 32 px from card edge to inner content (same as photosensitivity-boot-warning.md)

**Zone allocation** (within the 880 × 200 px modal card):

| Zone | Position | Allocation | Contents | MVP/VS |
|---|---|---|---|---|
| **Z1 — Header band** | Top, full-width within outer padding | 0–25% V (≈50 px) | Ink Black `#1A1A1A` solid band spanning the full inner width; "CASE CLOSED" stamp text rendered as Futura/DIN bold 24 px in Parchment `#E8DCC4`, **rotated -5°** per art-bible §7D Mission Card classification stamp convention; left-aligned within band with 16 px inset | MVP — **[CANONICAL]** Ink Black header band layout for all Case File register modals |
| **Z2 — Body content** | Center | 25–60% V (≈70 px) | "Operation abandoned." in American Typewriter 18 px, Ink Black on Parchment, **horizontally centered** within modal width (short single-line body benefits from center alignment; longer multi-line bodies in sibling modals would left-align — see Conflict Note below) | MVP |
| **Z3 — Button row** | Bottom | 60–100% V (≈80 px) | Two buttons right-aligned: `[Close File]` (left, destructive Ink Black fill) + `[Continue Mission]` (right, default focus, BQA Blue fill); 16 px gap between; thin 1 px Ink Black rule above the row | MVP — **[CANONICAL]** button order (destructive left, safe right with default focus) for all Case File register modals |
| **Backdrop** | Full-screen, behind modal card | 100% V × 100% H | `ColorRect` at Ink Black `#1A1A1A` 52% opacity over host menu | MVP — inherited from `modal-scaffold` |

**Conflict note — body alignment across modals**:

This modal's body ("Operation abandoned.") fits on one line, so center-alignment looks balanced. The sibling modals have similar single-line bodies (per locked string table: "Unsaved progress lost." 22 chars, "Reload last checkpoint?" 23 chars). All single-line bodies look balanced centered.

If a future locale's translation pushes a body to 2 lines (e.g., DE "Operation abgebrochen, alle ungesicherten Fortschritte verloren." would 2-wrap at 18 px), center-alignment of multi-line text reads awkward. **[CANONICAL] decision**: use **left-alignment** for multi-line bodies, **center-alignment** for single-line bodies. The modal renderer detects line count after layout and adjusts.

**Modal frame palette** [CANONICAL — applies to all 4 Case File modals]:

- Modal background fill: **Parchment** `#E8DCC4` (per art-bible §4)
- Modal border: 2 px Ink Black `#1A1A1A` solid line (no rounded corners — hard-edged per art-bible §3.3)
- No drop shadow (Pillar 5 Refusal — hard-edged rectangles, no shadows)
- **Header band styling**: Ink Black `#1A1A1A` solid band, 50 px tall, full-width within outer padding. Stamp text in Parchment with -5° rotation per art-bible §7D.

**Margins & safe zones**:

- Outer padding (modal card edge to content): 32 px on all 4 sides
- Header-to-body gap: 16 px below the Ink Black band
- Body-to-button-row gap: 16 px above the button row rule
- Inter-button gap: 16 px between `[Close File]` and `[Continue Mission]`
- Button hit-target: minimum 280 × 56 px per WCAG SC 2.5.5

**Resolution scaling**: same as photosensitivity-boot-warning.md (×2 at 4K; ui_scale 75–150% multiplies all dimensions; backdrop dim unaffected by ui_scale).

### Component Inventory

Per-zone component list. Pattern references point to `design/ux/interaction-patterns.md`. **[CANONICAL]** flags propagate to sibling Case File modals.

**Backdrop** [MVP infrastructure — inherited from `modal-scaffold`]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `BackdropDim` | `ColorRect` | Full-screen Ink Black `#1A1A1A` at 52% opacity, mounted by `ModalScaffold` parent CanvasLayer | Yes (intercepts clicks; mouse-click-outside dismisses with Cancel semantics per `dual-focus-dismiss`) | `modal-scaffold` |

**Modal card** [MVP frame — [CANONICAL] for all 4 Case File modals]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `ModalCardFrame` | `Panel` (or `PanelContainer`) | Parchment `#E8DCC4` fill, 2 px Ink Black border, hard-edged corners | No (decorative) | `modal-scaffold` |

**Z1 — Header band** [MVP — [CANONICAL] Ink Black band layout]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `HeaderBand` | `ColorRect` (or styled `Panel`) | Ink Black `#1A1A1A` solid fill, 50 px tall, full-width within 32 px outer padding | No | n/a (visual primitive) |
| `StampLabel` | `Label` (with `Transform2D` rotation) | `tr("menu.quit_confirm.stamp")` ("CASE CLOSED"); Futura/DIN bold 24 px, Parchment `#E8DCC4`, rotated -5° per art-bible §7D; left-aligned 16 px inset within band | No | `auto-translate-always` |

**Z2 — Body content** [MVP core]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `BodyLabel` | `Label` (with `autowrap_mode = AUTO_WRAP_WORD_SMART`, `horizontal_alignment` = CENTER if single-line / LEFT if multi-line per Section C.2 alignment rule) | `tr("menu.quit_confirm.body_alt")` ("Operation abandoned."); American Typewriter 18 px, Ink Black on Parchment | No (text only) | `auto-translate-always` + `accessibility-name-re-resolve` |

**Z3 — Button row** [MVP core — [CANONICAL] button order]:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `ButtonRowRule` | `HSeparator` (or `ColorRect`) | 1 px Ink Black line above the buttons, full-width within outer padding | No | n/a |
| `CloseFileButton` (destructive) | `Button` (with custom Theme override for Ink Black fill) | Label: `tr("menu.quit_confirm.confirm")` ("Close File"); Hit-target ≥ 280 × 56 px; **Ink Black fill `#1A1A1A` + Parchment `#E8DCC4` text** (destructive styling — distinct from default button styling) | Yes — confirm action: `pop(Context.MENU/PAUSE)` → `get_tree().quit()` | `auto-translate-always` + `accessibility-name-re-resolve` + **NEW pattern candidate**: `case-file-destructive-button` (Ink Black destructive button styling for Case File register modals; distinct from the default BQA Blue safe-action styling) |
| `ContinueMissionButton` (Cancel, default focus) | `Button` (standard ADR-0004 Theme styling) | Label: `tr("menu.quit_confirm.cancel")` ("Continue Mission"); Hit-target ≥ 280 × 56 px; **BQA Blue `#1B3A6B` fill + Parchment `#E8DCC4` text** (default safe-action styling) | Yes — cancel action: `hide_modal()` → focus restored to Close File / Quit Desktop button on host | `auto-translate-always` + `accessibility-name-re-resolve` + `dual-focus-dismiss` |

**Hidden / structural — not visible at rest**:

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| `FocusTrap` | (logical, owned by `ModalScaffold`) | Tab cycles within Z3 buttons only — escape blocked by ADR-0004 §97 `_unhandled_input` interception | n/a | `modal-scaffold` (focus trap) |
| `AssertiveAnnounceTimer` | (one-shot, `call_deferred`) | Sets modal root `accessibility_live = "assertive"` on mount, then `"off"` on next frame per CR-21 + AC-MENU-7.1 | n/a | `modal-scaffold` |

**NEW patterns flagged for library addition**:

1. **`case-file-destructive-button`** — Ink Black fill + Parchment text styling for destructive buttons in Case File register modals. Distinct from the default BQA Blue safe-action button. This pattern propagates to: `[Close File]` here, `[Return to Registry]` in return-to-registry.md, `[Re-Brief]` in re-brief-operation.md, `[Confirm]` in new-game-overwrite.md (4 consumers). **Recommended: add to library now** since 4 consumers are guaranteed.

Same is true for the inverse pattern (`case-file-safe-button` — BQA Blue fill, default styling for cancel/safe actions in Case File modals) but that's already implicit in the standard ADR-0004 Theme — no new pattern needed.

### ASCII Wireframe

**Default state** (post-mount, default focus on Continue Mission):

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← BackdropDim
│ ░░  Host menu visible underneath: Main Menu (BQA Blue field + Eiffel) OR          ░░ │     (52% Ink Black
│ ░░  Pause Menu (folder card on desk). Faded by the dim.                           ░░ │      over host)
│ ░░                                                                               ░░ │
│ ░░       ┌────────────────────────────────────────────────────────────────┐     ░░ │
│ ░░       │ ▓▓▓ CASE CLOSED ▓▓▓                                              │     ░░ │  ← Z1 HeaderBand
│ ░░       │   ↑ Ink Black band, Parchment text rotated -5° per art-bible 7D │     ░░ │     (Ink Black solid
│ ░░       │                                                                  │     ░░ │      with stamp text)
│ ░░       │                                                                  │     ░░ │
│ ░░       │                    Operation abandoned.                         │     ░░ │  ← Z2 BodyLabel
│ ░░       │                                                                  │     ░░ │     (centered 18 px)
│ ░░       │ ─────────────────────────────────────────────────────────────── │     ░░ │  ← ButtonRowRule
│ ░░       │                ┌──────────────┐  ┌──── ▶ ────────────────┐     │     ░░ │
│ ░░       │                │  Close File  │  │   Continue Mission     │     │     ░░ │  ← Z3 ButtonRow
│ ░░       │                │ (Ink Black,  │  │   (BQA Blue, default   │     │     ░░ │     (Close File left,
│ ░░       │                │  destructive)│  │    focus, inverted     │     │     ░░ │      Continue Mission
│ ░░       │                └──────────────┘  │    fill on focus)      │     │     ░░ │      right with focus)
│ ░░       │                                  └────────────────────────┘     │     ░░ │
│ ░░       └────────────────────────────────────────────────────────────────┘     ░░ │
│ ░░                                                                               ░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────────────────────────────────────────────────┘

  Modal: 880 × 200 px @ 1080p, centered horizontally + vertically
  Modal frame: Parchment fill, 2 px Ink Black border, no rounded corners, no drop shadow
  Header band: 50 px Ink Black solid fill spanning full inner width (within 32 px outer padding)
  Stamp text: -5° rotation per art-bible §7D classification stamp convention
```

**Focus state — Tab to Close File** (player has tabbed once from default focus):

```
    ...
│ ░░       │                ┌──── ▶ ──────┐  ┌────────────────────────┐     │     ░░ │
│ ░░       │                │  Close File │  │   Continue Mission     │     │     ░░ │  ← Close File now
│ ░░       │                │ (inverted:  │  │   (default Ink Black   │     │     ░░ │     focused; inverted
│ ░░       │                │  Parchment  │  │    on BQA Blue text)   │     │     ░░ │     fill (Parchment
│ ░░       │                │  fill, Ink  │  └────────────────────────┘     │     ░░ │     fill, Ink Black
│ ░░       │                │  Black text)│                                  │     ░░ │     text), 4 px BQA
│ ░░       │                └─────────────┘                                  │     ░░ │     Blue border
│ ░░       └────────────────────────────────────────────────────────────────┘     ░░ │
    ...
```

**Focus indicator**: Same as Main Menu's pattern (4 px BQA Blue solid border, inverted fill on focused button — Parchment fill, BQA Blue text on the focused button). Snap, no animation.

**Inverted-fill behavior on focus** (clarification — applies to both buttons):

| Button | Default fill | Focused fill (inverted) |
|---|---|---|
| `ContinueMissionButton` (default focus on mount) | BQA Blue fill, Parchment text | Parchment fill, BQA Blue text + 4 px BQA Blue border |
| `CloseFileButton` | **Ink Black** fill, Parchment text (destructive) | Parchment fill, Ink Black text + 4 px BQA Blue border (focus border still BQA Blue for consistency) |

**Default focus on mount**: `ContinueMissionButton` per CR-9 + AC-MENU-7.1.

**Tab order**: `ContinueMissionButton` ↔ `CloseFileButton` (only 2 focusable elements; Tab/Shift+Tab cycles between them; FocusTrap blocks escape).

---

## States & Variants

| State / Variant | Trigger | What Changes | MVP/VS |
|---|---|---|---|
| **Default — modal mounted** | `ModalScaffold.show_modal(QuitConfirmContent)` called by host menu | Standard layout (per C.4 default wireframe). Continue Mission button focused; Close File button visible but unfocused. FocusTrap active; AccessKit assertive announce on first frame; `Context.MODAL` on stack | MVP |
| **Pending confirm (transient)** | Between `[Close File]` button activation and `get_tree().quit()` returning | One frame: button visually inverts (Parchment fill, Ink Black text) for 1 frame; rubber-stamp thud SFX plays; then process exit terminates the scene tree. Buttons should NOT enter `disabled = true` here (the action is one-shot and synchronous; re-press during the same frame is harmless because the OS process is exiting) | MVP |
| **Pending cancel (transient)** | Between `[Continue Mission]` activation and `hide_modal()` returning | One frame: button visually inverts; no SFX (per Section E3 silence-on-Cancel decision); modal then dismisses | MVP |
| **Mounted from MainMenu** (CR-9 default path) | `Context.MENU` on stack when `show_modal()` called | Cancel restores focus to **Close File** button on Main Menu | MVP |
| **Mounted from PauseMenu** [VS] | `Context.PAUSE` on stack when `show_modal()` called | Cancel restores focus to **Quit Desktop** button on Pause Menu | VS |
| **Locale changed mid-modal** | `NOTIFICATION_TRANSLATION_CHANGED` received while modal is open (rare — Settings is a sibling overlay; ui_scale/locale changes happen after Settings dismissed which happens after Quit-Confirm dismissed in normal flow) | All Labels (StampLabel, BodyLabel, button labels) re-translate via `auto-translate-always`; AccessKit `accessibility_name` re-resolves. Layout reflows to accommodate new locale's body length (may grow modal height per locale) | MVP (plumbing) → VS (FR + DE locales ship) |
| **ui_scale changed mid-modal** | `setting_changed("graphics", "ui_scale", value)` received | Layout reflows on next layout pass; modal dimensions scale; backdrop dim unaffected | MVP (plumbing) |
| **Reduced-motion active** | `Settings.reduced_motion == true` | No effect — modal has no animations to gate (mount and dismiss are both snap-cuts per Section E3) | MVP (plumbing) |

**Note: no disk-full / failure state** — unlike photosensitivity-boot-warning.md, this modal does NOT write to disk on confirm. `get_tree().quit()` is a process-exit call, not a disk write. There is no async I/O failure path to handle.

**Platform variants**: None. Linux + Windows render identically.

**Combined-state matrix**: similar topology to photosensitivity-boot-warning.md Section D. Default + Pending transitions are one-frame; Locale/ui_scale changed apply on receipt; mounted-from variants are mutually exclusive at entry-time.

**State-transition invariants**:

1. `Context.MODAL` is on the stack from `show_modal()` return until `hide_modal()` returns (Cancel path) OR until process exit (Confirm path).
2. `Continue Mission` retains default focus throughout the modal's lifetime unless the player Tab-switches.
3. `ui_cancel` ALWAYS dismisses with Cancel semantics — never with Confirm semantics. This is non-negotiable: Esc must not trigger destructive action.
4. AccessKit assertive announce is one-shot per modal mount.
5. Mouse-click outside modal rect ALWAYS dismisses with Cancel semantics (per `dual-focus-dismiss` pattern — this modal honors the pattern fully, unlike photosensitivity which carved out for boot-path safety).

---

## Interaction Map

**Input methods**: KB/Mouse primary + Gamepad partial. All interactions consumed via `_unhandled_input(event)` per ADR-0004 §97.

| Component | Action | KB/Mouse | Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **`ContinueMissionButton`** (default focus) | Activate (Cancel) | LMB / Enter / Space | A button | Button fill snap-inverts (Parchment / BQA Blue) for 1 frame; **paper-shuffle one-shot SFX** on UI bus (Audio §UI bus — Pillar 5 Case File register applies) | `hide_modal()` → `Context.MODAL` pops → focus restored to host button (Close File on Main Menu / Quit Desktop on Pause Menu) |
| **`ContinueMissionButton`** | Focus | Tab / ↑↓ / mouse hover | ↑↓ D-pad | Focus indicator (4 px BQA Blue border, inverted fill); paper-shuffle on focus change | None — focus only |
| **`CloseFileButton`** | Activate (Confirm — destructive) | LMB / Enter / Space | A button | Button fill snap-inverts; **rubber-stamp thud one-shot SFX** on UI bus (Pillar 5 destructive-action audio convention per Player Fantasy: "rubber-stamp thud on destructive actions"); 1-frame visual stamp before process exit | `pop(Context.MENU/PAUSE)` → `get_tree().quit()` → application terminates |
| **`CloseFileButton`** | Focus | Tab / ↑↓ / mouse hover | ↑↓ D-pad | Focus indicator (4 px BQA Blue border, inverted fill on the destructive button — Parchment fill, Ink Black text) | None — focus only |
| **Esc / `ui_cancel`** | Press | `Esc` | `JOY_BUTTON_B` | Same as Continue Mission activation (paper-shuffle SFX) | Equivalent to `[Continue Mission]` activation per CR-9 + AC-MENU-7.2. Modal dismisses with Cancel semantics. **NEVER** triggers Close File. |
| **Mouse-click-outside** (on `BackdropDim`) | Click | LMB on coordinates outside modal rect | n/a | Same as Continue Mission activation | Modal dismisses with Cancel semantics per `dual-focus-dismiss` pattern. NEVER triggers Close File. |
| **Tab / Shift+Tab** | Focus cycle | Tab / Shift+Tab while modal focused | n/a (gamepad uses ↑↓) | Focus indicator moves between Continue Mission and Close File | Cycles 2-button focus; FocusTrap blocks escape |
| **Mouse hover** | Hover | Mouse motion entering button rect | n/a | Same as focus | None |

**No long-press / no hold-to-confirm** [CANONICAL — applies to all 4 Case File modals]: Single-press activation only. Pillar 5 register stamps decisions immediately.

**No double-click**: Single-press is sufficient. Mouse-click on a non-focused button focuses AND activates in a single press (Godot Button default behavior).

**Held-key flush on entry**: When the modal mounts, held actions from the prior context (Main Menu Close File button being held when activated) are flushed via `held-key-flush-after-rebind` pattern — prevents the modal's Continue Mission default focus from auto-activating on a held Enter.

**Cross-references**: `unhandled-input-dismiss`, `set-handled-before-pop`, `dual-focus-dismiss` (fully honored — this modal is the canonical instance), `modal-scaffold` (focus trap), `input-context-stack`.

---

## Events Fired

Per ADR-0002, this modal is **subscribe-only** in MVP — it emits no Signal Bus signals. Confirm action calls `get_tree().quit()` directly (OS-level), not via Signal Bus.

| Player Action | Event Fired | Payload | Owner |
|---|---|---|---|
| `[Continue Mission]` activated | None — `hide_modal()` is a local Menu System operation; no Signal Bus event. AT announces focus restoration on next focus change | n/a | n/a |
| `[Close File]` activated | None directly — `get_tree().quit()` is a Godot OS-level call, not a Signal Bus event. Process exit precludes any post-emit listener anyway | n/a | n/a |
| `ui_cancel` / mouse-click-outside | None — same as Continue Mission activation | n/a | n/a |

**Subscriptions** (this modal is a receiver, not emitter):

- `NOTIFICATION_TRANSLATION_CHANGED` — handled by Label children for re-translate; modal root re-resolves AccessKit `accessibility_name` via `accessibility-name-re-resolve` pattern.

**Analytics events**: OUT OF SCOPE for MVP. If analytics ship in Polish, instrumentation candidates: Confirm activate (count session-end events), Cancel activate (count "I almost quit by accident" events — UX optimization signal), modal-open-but-no-action duration (timing signal). No PII.

---

## Transitions & Animations

**Pillar 5 register applies** [CANONICAL — propagates to all 4 Case File modals]: this modal's interactions fire the Case File audio palette, NOT the photosensitivity silence:

- Paper-shuffle: focus change, modal mount, modal dismiss (Cancel path)
- Typewriter-clack: NOT used here (Quit-Confirm doesn't have a generic "click" — every button has a specific cue)
- **Rubber-stamp thud**: destructive action confirm (Close File only) — per menu-system.md Player Fantasy: "rubber-stamp thud on destructive actions (Quit, Delete Save, Restart Checkpoint)". This SFX is the load-bearing audio cue for the destructive path.
- Drawer-slide: NOT used here (drawer-slide is reserved for Pause Menu mount/dismiss — see `pause-menu-folder-slide-in` pattern)

**Modal enter**:

| Trigger | Animation | Reduced-motion variant |
|---|---|---|
| `ModalScaffold.show_modal(QuitConfirmContent)` | None — modal snaps in instantly. Paper-shuffle SFX cues the appearance. AccessKit assertive announce fires within 1 frame. Backdrop dim appears in same frame as modal card. | Identical (already snap) |

**Modal exit**:

| Trigger | Animation |
|---|---|
| `[Continue Mission]` / `ui_cancel` / outside-click (Cancel path) | Modal snaps out. Paper-shuffle SFX. `Context.MODAL` pops; backdrop dim removed in same frame; focus restored to host button |
| `[Close File]` (Confirm path) | Modal does NOT snap out — instead: button visual inverts for 1 frame; **rubber-stamp thud SFX**; `pop()` + `get_tree().quit()` terminate the scene tree. The modal disappears because the application exits, not because of `hide_modal()`. |

**In-modal state-change animations**:

| State change | Animation | Reduced-motion variant |
|---|---|---|
| Button focus change | Hard snap; paper-shuffle SFX | Identical |
| Button activate (either button) | Hard snap fill-invert for 1 frame | Identical |
| Locale change re-render | All Labels re-translate same frame | Identical |
| ui_scale change reflow | Layout reflows on next layout pass | Identical |

**Vestibular-safety claim**: All animations are hard cuts. No tween, no parallax, no flicker. ✓ Vestibular-safe by design. `reduced_motion` setting does not need to alter rendering.

---

## Data Requirements

This modal is **read-only and stateless** — it owns no persistent state, performs no writes, calls only `get_tree().quit()` (OS-level) and `hide_modal()` (local Menu System operation) on its action paths.

| Data | Source System | Read / Write | Real-time? | Notes |
|---|---|---|---|---|
| Locale (current `TranslationServer.get_locale()`) | `TranslationServer` (Godot built-in) | Read | Push via `NOTIFICATION_TRANSLATION_CHANGED` | Triggers re-render of all 4 Labels (StampLabel, BodyLabel, both buttons) + AccessKit `accessibility_name` re-resolve |
| `ui_scale` (75–150%) | `SettingsService` (Settings G.3) → applied to `Window.content_scale_factor` | Read | Push via `setting_changed` (rare for this modal) | Layout reflows on next layout pass |
| Active language string table | `TranslationServer` + `*.po` files in `assets/locale/[locale]/` | Read | Push via `NOTIFICATION_TRANSLATION_CHANGED` | All Labels use `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`. The 4 string keys per CR-9 + locked string table: `menu.quit_confirm.stamp`, `menu.quit_confirm.body_alt`, `menu.quit_confirm.confirm`, `menu.quit_confirm.cancel` |
| Host context (Main Menu vs Pause Menu) | `InputContext.current()` query | Read | Synchronous read at Cancel-path execution | Determines focus restoration target (Close File button vs Quit Desktop button) |

**Writes performed by this modal**: NONE. `get_tree().quit()` is an OS-level call, not a write. The modal does not call SaveLoad, does not modify SettingsService state, does not delete saves. **No automatic save on quit per CR-9** — the player is responsible for explicit saves before quitting.

**Architectural concerns flagged**:

1. **`get_tree().quit()` is synchronous and process-terminating**. Once called, no further frames render. This means: (a) the rubber-stamp thud SFX must play BEFORE `get_tree().quit()` (or at least be queued on the audio bus before the call); (b) any `await` on the SFX completion is a defect — process exit may interrupt mid-await; (c) the modal scene tree is destroyed by OS process exit, not by `hide_modal()`.
2. **No `await` allowed on the Confirm path**. Per Settings GDD CR-9 invariant (synchronous emit) and `_on_setting_changed` Forbidden Pattern FP-9, the Confirm path is fully synchronous. This is consistent.
3. **Cancel path focus restoration depends on `InputContext.current()`**. The modal queries `Context.MENU` vs `Context.PAUSE` to determine which host button to refocus. If the InputContext stack is corrupted or the host menu was destroyed mid-modal (impossible in MVP — modals are mutually exclusive with scene changes — but flag for defensive coding in implementation review), focus restoration may fail silently.

**No PII / no secret data**: All data is local-only. No network calls.

---

## Accessibility

**Committed tier**: **Standard** per `design/accessibility-requirements.md` (NOT safety-critical Basic+ like photosensitivity-boot-warning — this is a destructive-action confirm, not a medical advisory).

**Keyboard-only navigation path** [Day-1 MVP]:

```
  Modal mounted → focus lands on [Continue Mission]  ← default focus per CR-9 + AC-MENU-7.1
    ↓ Tab
  [Close File]
    ↓ Tab → wraps to [Continue Mission]
  (Shift+Tab cycles backward; FocusTrap blocks escape from modal)
```

100% of interactive elements reachable via Tab + Enter. No mouse-only interactions.

**Modal focus trap** [Day-1 MVP, BLOCKING]: Same contract as photosensitivity — focus cannot escape the modal via Tab. `ui_cancel` IS allowed (unlike photosensitivity boot path) — Esc dismisses with Cancel semantics per CR-9 + AC-MENU-7.2.

**AccessKit per-Control table** [Day-1 MVP per ADR-0004 IG10] — [CANONICAL] structure for sibling Case File modals:

| Component | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| Modal root (`QuitConfirmContent`) | `"dialog"` per AC-MENU-7.1 | `tr("menu.quit_confirm.stamp")` ("CASE CLOSED") | (none — dialog name carries the title via stamp) | `"assertive"` one-shot on mount, then `"off"` next frame via `call_deferred` per CR-21 |
| `StampLabel` (Z1) | `"text"` (default Label role; rotation is decorative — does not affect AT) | (none — content of dialog name; AT-announced via parent dialog) | (none) | `"off"` |
| `BodyLabel` (Z2) | `"text"` | (none — content) | (none) | `"off"` |
| `CloseFileButton` (Z3, destructive) | `"button"` | "Close File" (per `tr("menu.quit_confirm.confirm")`) | `tr("menu.quit_confirm.confirm.desc")` ("Quit the application without saving.") — explicit description because "Close File" is bureaucratic-register and AT users benefit from the plain-language clarification | `"off"` |
| `ContinueMissionButton` (Z3, default focus) | `"button"` | "Continue Mission" (per `tr("menu.quit_confirm.cancel")`) | `tr("menu.quit_confirm.cancel.desc")` ("Cancel the quit and return to the main menu.") — same rationale | `"off"` |

**Live regions**:

| Trigger | Live region behavior | AT outcome |
|---|---|---|
| Modal mount | Modal root `accessibility_live = "assertive"` for one frame | AT announces dialog title + body content immediately |
| `[Close File]` activated | (none — process exits before announce can fire) | AT announces nothing on confirm; the rubber-stamp thud SFX is the audio cue |
| `[Continue Mission]` activated | (none — focus restoration on host menu button triggers AT focus announce automatically) | AT announces "Close File button" on host (or "Quit Desktop" on Pause Menu) |

**Text contrast** [Standard tier — WCAG 2.1 AA]:

| Element | Foreground | Background | Contrast ratio |
|---|---|---|---|
| StampLabel ("CASE CLOSED") | Parchment `#E8DCC4` | Ink Black `#1A1A1A` band | ≥ 12:1 |
| BodyLabel | Ink Black `#1A1A1A` | Parchment `#E8DCC4` | ≥ 12:1 |
| ContinueMissionButton (default fill) | Parchment | BQA Blue `#1B3A6B` | ≥ 7:1 |
| ContinueMissionButton (focused fill — inverted) | BQA Blue | Parchment | ≥ 7:1 |
| CloseFileButton (default fill — destructive) | Parchment | Ink Black `#1A1A1A` | ≥ 12:1 |
| CloseFileButton (focused fill — inverted) | Ink Black | Parchment | ≥ 12:1 |

All ratios meet or exceed WCAG AA minimum (4.5:1) and most meet AAA (7:1). Verified with `tools/ci/contrast_check.sh` once available.

**Minimum text sizes** [per `accessibility-requirements.md`]:

- StampLabel: 24 px (matches the menu UI floor; Futura/DIN bold; rotation does not affect readability per art-bible §7D convention)
- BodyLabel: 18 px (matches HUD floor; reading-oriented prose; OK per cognitive accessibility rationale)
- Button labels: 24 px (at the menu UI floor)

**Color-independent communication**:

Destructive vs Cancel distinction is conveyed by:

- **Position** (Cancel right with default focus = primary action; Close File left = secondary/destructive)
- **Fill color** (Ink Black destructive vs BQA Blue safe)
- **Label text** ("Close File" implies finality; "Continue Mission" implies continuation)
- **Focus indicator** (4 px BQA Blue border on focused button)

Color is one of four signals — players who don't perceive Ink Black vs BQA Blue still see position + label + focus. ✓ Color-blind safe.

**Screen flash / strobe / photosensitivity**: Modal contains no flashing content. ✓ Photosensitivity-safe.

**Motion / vestibular accessibility**: All animations are hard cuts. ✓ Vestibular-safe by design.

**Motor accessibility**:

- No timed inputs (modal does NOT auto-dismiss).
- Single-press activation.
- Hit-target floor: 280 × 56 px buttons (above WCAG SC 2.5.5 44 × 44 floor).
- Default focus on Cancel reduces accidental destructive activation under motor impairment.

**Cognitive accessibility**:

- 2 buttons (well below cognitive-load thresholds).
- 20-char body copy ("Operation abandoned.") — calibrated for fast scanning.
- Bureaucratic-register labels carry implicit clarification via `accessibility_description`.
- No time pressure.
- Stamp visual ("CASE CLOSED") provides at-a-glance signal of modal type for cognitive-accessibility users who don't read body copy first.

---

## Localization Considerations

**Locale targets**: English (MVP), French + German at VS. Per CR-9 the body copy and button labels are **locked content** — translators must sign off on the final wording per locale.

**String inventory**:

| Key | English source | EN char count | Layout budget | 40% expansion target | Status |
|---|---|---|---|---|---|
| `menu.quit_confirm.stamp` | "CASE CLOSED" | 11 | ~50 chars (Z1 band, Futura/DIN bold 24 px) | ≤ 16 | ✓ FR "DOSSIER FERMÉ" 13 chars / DE "AKTE GESCHLOSSEN" 16 chars — both fit |
| `menu.quit_confirm.body_alt` | "Operation abandoned." | 20 | ≤ 1 line @ 18 px in 880 px modal (~80 chars per line) | ≤ 28 | ✓ FR "Opération abandonnée." ~22 chars / DE "Operation abgebrochen." ~22 chars — both fit |
| `menu.quit_confirm.confirm` | "Close File" | 10 | ~25 chars (button label) | ≤ 14 | ✓ FR "Fermer" 6 chars (per main-menu.md OQ #7 — short form preferred) / DE "Schließen" 9 chars |
| `menu.quit_confirm.cancel` | "Continue Mission" | 16 | ~25 chars | ≤ 23 | ⚠ FR "Continuer la mission" ~20 chars / DE "Mission fortsetzen" ~18 chars — both fit but FR is at budget |
| `menu.quit_confirm.confirm.desc` | "Quit the application without saving." | 36 | unbounded (AccessKit, AT-only) | unbounded | ✓ |
| `menu.quit_confirm.cancel.desc` | "Cancel the quit and return to the main menu." | 44 | unbounded (AccessKit) | unbounded | ✓ |

**Layout-critical elements**:

| Element | Why critical | Mitigation |
|---|---|---|
| Stamp text in Z1 band | Must fit within band height (50 px) at 24 px Futura/DIN bold AND read clearly at -5° rotation. Long localized stamps may overflow the band horizontally. | Per locale: shorten if needed (e.g., DE "AKTE ZU" instead of "AKTE GESCHLOSSEN" — but verify with narrative-director that "AKTE ZU" preserves register). FR "DOSSIER FERMÉ" preserves register and fits. |
| Body single-line cap | Z2 is sized for 1 line at 18 px in 880 px modal width (~80 chars). All current locales fit. | If a locale exceeds 1 line, modal height grows per the [CANONICAL] rule from C.2 (default 200 px → up to ~260 px); body alignment switches from CENTER to LEFT for multi-line. |
| Button parity | Both buttons should be visually similar width. | Width = max of the two labels' rendered width per locale. Hit-target floor 280 × 56 px ensures both have room. |

**Locale-specific formatting**: None — no numerical values, no dates, no currency in this modal.

**What this modal does NOT localize**:

- Modal frame palette (Parchment, Ink Black, BQA Blue — locale-invariant brand)
- Audio cues (paper-shuffle, rubber-stamp thud — locale-invariant)
- Stamp rotation -5° (locale-invariant; matches art-bible §7D)

**RTL (right-to-left) support**: OUT OF SCOPE for MVP and VS. Post-launch evaluation. Button row would mirror — `[Continue Mission]` leftmost, `[Close File]` rightmost. Stamp band layout would mirror — stamp text on the right with -5° rotation flipped to +5° (or kept at -5° for register continuity — flag for post-launch decision).

**Translator brief priority items** [CANONICAL — applies to all 4 Case File modals]:

1. **Stamp text** must read as a 1965 BQA bureaucratic stamp — not a system status. "DOSSIER FERMÉ" preserves register; "FERMETURE" or "QUITTER" do not.
2. **Body copy** uses bureaucratic-neutral declarative voice. Not "Are you sure?" — that's modern game-launcher chrome, forbidden by Pillar 5.
3. **Cancel button** can shorten significantly per locale ("Fermer", "Schließen") since the meaning is unambiguous in destructive-confirm context.
4. **AccessKit descriptions** carry plain-language clarification — translate as informational, not bureaucratic. AT users benefit from the register break.

---

## Acceptance Criteria

ACs verify UX-specific outcomes; cross-reference `menu-system.md` H.7 (AC-MENU-7.1 through 7.3).

**Format**: GIVEN/WHEN/THEN with story type tags + gate level.

### Modal Mount & Default State

- **AC-QC-1.1 [Visual] [BLOCKING]** GIVEN modal mounted from Main Menu Close File button, WHEN screenshot taken, THEN: (a) modal centered at 1920 × 1080; (b) dimensions 880 × 200 px ± 10 px; (c) backdrop dim covers full screen at 52% Ink Black; (d) Main Menu visible underneath; (e) Z1 Ink Black header band 50 px tall with "CASE CLOSED" stamp text at -5°; (f) Z2 body "Operation abandoned." centered; (g) Z3 buttons right-aligned with Close File (Ink Black fill) left of Continue Mission (BQA Blue fill, focused). Evidence: `production/qa/evidence/quit-confirm-mount-[date].png` + art-director sign-off.
- **AC-QC-1.2 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN inspected within same `_ready()` frame, THEN: (a) `ContinueMissionButton.has_focus() == true`; (b) `Context.MODAL` on top of stack; (c) modal root `accessibility_role == "dialog"` (per AC-MENU-7.1); (d) `accessibility_live == "assertive"`; (e) FocusTrap blocks Tab escape.
- **AC-QC-1.3 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN one frame elapses, THEN modal root `accessibility_live == "off"` (one-shot).

### Locked Content Integrity

- **AC-QC-2.1 [Logic] [BLOCKING]** GIVEN modal mounted in EN locale, WHEN `StampLabel.text`, `BodyLabel.text`, `CloseFileButton.text`, `ContinueMissionButton.text` are read, THEN they equal exactly "CASE CLOSED", "Operation abandoned.", "Close File", "Continue Mission" respectively per CR-9 + locked string table.
- **AC-QC-2.2 [Visual] [ADVISORY]** GIVEN modal rendered with screenshot, WHEN inspected, THEN `StampLabel` rendered at -5° rotation per art-bible §7D (visible angular offset on the stamp text within the Ink Black band).

### Confirm Path (Destructive)

- **AC-QC-3.1 [Logic] [BLOCKING]** GIVEN modal mounted from Main Menu, WHEN `[Close File]` activated, THEN within one frame: (a) rubber-stamp thud SFX queued on UI bus; (b) `pop(Context.MENU)` called; (c) `get_tree().quit()` called. Per AC-MENU-7.3.
- **AC-QC-3.2 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN `[Close File]` activated, THEN NO `SaveLoad.save_to_slot(...)` call is made — the application exits without auto-save per CR-9.
- **AC-QC-3.3 [Logic] [BLOCKING]** GIVEN modal mounted from Pause Menu (VS), WHEN `[Close File]` activated, THEN `pop(Context.PAUSE)` called (NOT `Context.MENU`) before `get_tree().quit()`.
- **AC-QC-3.4 [Visual] [ADVISORY]** GIVEN `[Close File]` activated, WHEN screenshot taken at 1-frame post-activation (immediately before process exit), THEN button shows inverted fill (Parchment fill, Ink Black text) — destructive button's focus-state visual.

### Cancel Path (Default)

- **AC-QC-4.1 [Logic] [BLOCKING]** GIVEN modal mounted from Main Menu, WHEN `[Continue Mission]` activated, THEN: (a) paper-shuffle SFX on UI bus; (b) `hide_modal()` called; (c) `Context.MODAL` pops; (d) focus restored to `CloseFileButton` on Main Menu (NOT `QuitDesktopButton`); (e) no save written, no state change persisted. Per AC-MENU-7.2.
- **AC-QC-4.2 [Logic] [BLOCKING]** GIVEN modal mounted from Pause Menu (VS), WHEN `[Continue Mission]` activated, THEN focus restored to `QuitDesktopButton` on Pause Menu (NOT `CloseFileButton`).
- **AC-QC-4.3 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN `ui_cancel` (Esc / B) pressed, THEN behavior is identical to `[Continue Mission]` activation per AC-MENU-7.2 — modal dismisses with Cancel semantics, NEVER triggers Close File.
- **AC-QC-4.4 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN mouse-click occurs on `BackdropDim` outside modal rect, THEN behavior is identical to `[Continue Mission]` activation per `dual-focus-dismiss` pattern.

### Focus & Tab Order

- **AC-QC-5.1 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN Tab pressed twice, THEN focus moves Continue Mission → Close File → Continue Mission (wraps; FocusTrap holds).
- **AC-QC-5.2 [Logic] [BLOCKING]** GIVEN modal mounted with focus on Close File (after Tab), WHEN Enter pressed, THEN destructive Confirm path fires per AC-QC-3.1 (NOT Cancel path).

### Performance

- **AC-QC-6.1 [Integration] [BLOCKING]** GIVEN modal mounted, WHEN measured from `[Continue Mission]` button-press to `hide_modal()` return, THEN elapsed time ≤ 50 ms.
- **AC-QC-6.2 [Integration] [BLOCKING]** GIVEN modal mounted, WHEN measured from `[Close File]` button-press to `get_tree().quit()` invocation, THEN elapsed time ≤ 50 ms (rubber-stamp SFX queued before this).

### Accessibility

- **AC-QC-7.1 [Integration] [BLOCKING]** GIVEN modal mounted, WHEN AccessKit tree queried, THEN every interactive Control has non-empty `accessibility_role`, `accessibility_name`, AND `accessibility_description`. Modal root `accessibility_role == "dialog"`.
- **AC-QC-7.2 [Integration] [BLOCKING]** GIVEN modal mounted with screen reader active, WHEN modal first appears, THEN AT announces dialog title (stamp) + body content within 1 second of mount.
- **AC-QC-7.3 [Logic] [BLOCKING]** GIVEN modal at 100% ui_scale, WHEN button rect inspected, THEN width × height ≥ 280 × 56 px.
- **AC-QC-7.4 [Logic] [BLOCKING]** GIVEN body label rendered with WCAG contrast formula, WHEN sampled, THEN ratio ≥ 7:1 (Ink Black on Parchment).
- **AC-QC-7.5 [Logic] [BLOCKING]** GIVEN `Settings.reduced_motion == true`, WHEN modal mounts and dismisses, THEN no animation behaves differently than `reduced_motion == false`.

### Localization

- **AC-QC-8.1 [Integration] [BLOCKING — before any non-EN locale ships]** GIVEN modal mounted in any locale, WHEN locale changes mid-modal via `NOTIFICATION_TRANSLATION_CHANGED`, THEN all 4 Labels re-translate within 1 frame; AccessKit re-resolves.
- **AC-QC-8.2 [UI] [ADVISORY]** GIVEN modal mounted in FR locale at 100% ui_scale, WHEN button rects inspected, THEN no button label clips outside its rect.
- **AC-QC-8.3 [Visual] [ADVISORY]** GIVEN modal mounted in any locale, WHEN stamp band rendered, THEN stamp text fits within the 50 px Ink Black band height at 24 px font with -5° rotation, no clipping.

### State Invariants

- **AC-QC-9.1 [Logic] [BLOCKING]** GIVEN modal mounted from any host, WHEN `Context.MODAL` is on top of stack throughout modal's lifetime, popped only on `hide_modal()` (Cancel) or implicit on process-exit (Confirm).
- **AC-QC-9.2 [Logic] [BLOCKING]** GIVEN modal mounted, WHEN `[Close File]` activated, THEN no `await` is used between button activation and `get_tree().quit()` — fully synchronous path per Section F architectural concern #1.

**Total**: 24 UX-specific ACs (3 Mount/Default + 2 Locked Content + 4 Confirm + 4 Cancel + 2 Focus + 2 Performance + 5 Accessibility + 3 Localization + 2 State Invariants). Cross-references to GDD ACs noted.

---

## Open Questions

| # | Question | Where raised | Owner | Recommended resolution | Decision needed by |
|---|---|---|---|---|---|
| **1** | Modal height grows for non-EN locales whose body translation exceeds 1 line at 18 px in 880 px width. Default 200 px → up to ~260 px per [CANONICAL] rule. Same conflict-with-AC-MENU-6.6-font-scale-down as photosensitivity-boot-warning OQ #7. | Section C.2 + H | accessibility-specialist + game-designer (menu-system.md owner) | **Recommended: same resolution as photosensitivity-boot-warning OQ #7** — amend AC-MENU-6.6 to keep 18 px and grow modal height instead of font scale-down. **BLOCKING** before any non-EN locale ships. (Resolves bundle of OQs; one amendment closes the issue across the modal family.) | Before any non-EN locale ships |
| **2** | CR-9 prose says cancel button is "Return to File"; locked string table says "Continue Mission". This UX spec uses "Continue Mission" (string table is authoritative; AC-MENU-7.1 confirms). | Header context summary | game-designer (menu-system.md owner) | **Recommended: amend menu-system.md CR-9 prose to "Continue Mission"** — match the locked string table. The "Return to File" wording is stale. | Before MVP sprint kickoff |
| **3** | `case-file-destructive-button` NEW pattern candidate — add to `interaction-patterns.md` library now or defer? 4 known consumers (Quit-Confirm + Return-to-Registry + Re-Brief + New-Game-Overwrite). | Section C.3 | ux-designer | **Recommended: add to library now** since 4 consumers are guaranteed. The pattern is structural (button styling), not speculative. | Before MVP sprint kickoff |
| **4** | Stamp band overflow for long localized stamps — DE "AKTE GESCHLOSSEN" 16 chars fits at 24 px in 880 px width, but a hypothetical longer locale (e.g., Japanese gloss) might overflow. What's the fallback? | Section H | ux-designer + localization-lead | **Recommended: amend translator brief to enforce ≤ 16-char stamp limit per locale**. If a locale's natural translation exceeds 16 chars, translator must shorten. Preserves the band's visual proportions across all locales. | Before any non-EN locale ships |
| **5** | AccessKit description strings (`menu.quit_confirm.confirm.desc` and `.cancel.desc`) are invented in this spec; not in CR-9 or locked string table. Should they be locked text (translator sign-off) or translator-discretionary? | Section G + H | accessibility-specialist + localization-lead + narrative-director | **Recommended: translator-discretionary** — descriptions are AT-only plain-language clarification, not bureaucratic register. Translators have leeway to phrase naturally per locale. Add to translator brief as informational context, NOT locked content. | Before VS sprint (FR/DE locale work) |
| **6** | RTL (Arabic / Hebrew) — would the -5° stamp rotation flip to +5° to match RTL reading direction, or stay at -5° for register continuity? | Section H | art-director + ux-designer | **Recommended: defer post-launch decision** until RTL is in scope. Both options have trade-offs; needs RTL-fluent design review. | Post-launch evaluation |
| **7** | Audio register — rubber-stamp thud SFX on Confirm + paper-shuffle on Cancel/focus. These are [CANONICAL] for all 4 Case File modals. Confirm or any change? | Section E3 | sound-designer + creative-director | **Recommended: lock as-is** — the audio palette is already documented in menu-system.md Player Fantasy. This UX spec restates it; no new decisions. | Confirmed by menu-system.md Player Fantasy |

**Cross-references**:

- OQ #1 bundles with photosensitivity-boot-warning OQ #7 (single AC-MENU-6.6 amendment closes both)
- OQ #2 + OQ #3 + OQ #4 require menu-system.md / interaction-patterns.md / translator-brief amendments before MVP
- OQ #5 + OQ #6 are deferred / VS+ scope
