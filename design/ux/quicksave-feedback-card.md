# UX Spec: Quicksave / Quickload Feedback Card

> **Status**: In Design
> **Author**: agustin.ruatta@vdx.tv + ux-designer
> **Last Updated**: 2026-04-29
> **Pattern**: This surface implements the `diegetic-confirmation-toast` pattern from `design/ux/interaction-patterns.md` (governs Quicksave success and Quickload success notification cards).
> **Journey Phase(s)**: Cross-cutting — fires whenever `Events.game_saved` or `Events.game_loaded` is emitted while a Menu surface (Main Menu or Pause Menu) is mounted, OR when a quicksave / quickload (F5 / F9) is fired during active gameplay (`Context.GAMEPLAY`) with the result successful.
> **Template**: UX Spec
> **Scope**: VS (Vertical Slice) per Menu System §C.2 row 11 (Quicksave / Quickload feedback card) + Save/Load §C.5 (`Quicksave/Quickload UX sketch`) + HUD State Signaling §C (HSS notification surface alternative).
> **Governing GDDs**: `design/gdd/menu-system.md` (§C.2 row 11 + §A.1 cues-that-do-not-exist + §C.8 `menu.quicksave.feedback` / `menu.quickload.feedback` + §V.7 fade timing) + `design/gdd/save-load.md` (§C.5 quicksave/quickload UX sketch + §C.7 quickload-on-empty notification + §Tuning Knobs `QUICKSAVE_CONFIRMATION` HUD-notification non-blocking) + `design/gdd/hud-state-signaling.md` (§C resolver — when feedback renders during pure gameplay).
> **Pillar Constraint**: Pillar 5 absolute — this is the **only** in-game persistent-state confirmation surface. No "saving..." spinner. No "Game saved!" banner. The feedback is a 1965 BQA stamp landing on the dispatcher's desk; visible briefly; then gone.

---

## Purpose & Player Need

The Feedback Card is the **briefest possible acknowledgment** that a quicksave or quickload took effect. It exists because Quicksave/Quickload are *intentionally non-blocking* (no confirm dialog, no spinner — Save/Load Tuning Knobs `QUICKSAVE_CONFIRMATION = HUD notification, non-blocking`); the player needs *some* indication that the keypress was honored, but nothing that interrupts the flow.

> **Player goal**: *"Did F5 work? OK, I see it stamped. Back to the action."*

**What goes wrong if this surface is missing or wrong:**
- Player presses F5 → silence → presses F5 again → presses F5 a third time. Trust eroded; uncertainty is the worst Save/Load outcome.
- Feedback overlays the gameplay critical area (center-screen), interrupting the action — Pillar 5 violation.
- Feedback persists too long — covers a guard or a clue. Conversely, too-short feedback misses a peripheral glance.
- Feedback steals focus or pushes InputContext — breaks gameplay input. Save/Load §Tuning Knobs explicitly says non-blocking.

**Distinguishing constraints**:
- **No InputContext push.** This card is a transient overlay, not a modal (Menu System §C.2 row 11: "NO context push (transient overlay)").
- **Non-focusable.** `mouse_filter = MOUSE_FILTER_IGNORE` per Menu System §C.2 row 11. The card never receives focus; KB/gamepad never lands on it.
- **Auto-fade after `quicksave_feedback_duration_s`** (1.4 s default per Menu System §G.1 implied). No player action required to dismiss.
- **Renders concurrently with active gameplay or active Pause Menu** — the card must not occlude either surface's critical content area.

**Pillar fit:**
- **Primary 5 (Period Authenticity)**: a small Parchment card with `DISPATCH FILED` or `DISPATCH LOADED` stamp. Not a modern toast notification with rounded corners and an X-to-dismiss.
- **Primary 3 (Stealth as Theatre)**: stealth is interrupted as little as possible. The card is small, peripheral, and brief — Eve glances at the desk, sees the stamp, glances back at the corridor.
- **Anti-Pillar (NOT modern UX paternalism)**: no "Save successful! ✓" with a checkmark icon. No persistent toast queue. No achievement-style popup.

---

## Player Context on Arrival

The card arrives **involuntarily** — the game decides. Two arrival vectors:

| Vector | Trigger | Player state on arrival |
|---|---|---|
| Quicksave success | Player pressed F5; `SaveLoad.save_to_slot(0)` succeeded; `Events.game_saved.emit(0, section_id)` fires | Mid-gameplay (most common) — observing a guard, holding a movement key, perhaps mid-stealth. May also fire from Pause if F5 was pressed there (less common but valid per Save/Load CR-6 — quicksave allowed in `{GAMEPLAY, MENU, PAUSE}`). |
| Quickload success | Player pressed F9; `SaveLoad.load_from_slot(0)` succeeded; `Events.game_loaded.emit(0)` fires; subsequent scene transition starts | **Practically rare** — quickload triggers Level Streaming `LOAD_FROM_SAVE` which destroys the current section and the Menu surface (per Menu System §C.7). The feedback card may only render briefly before the LS fade-to-black takes over. Edge case: if quickload is a no-op (slot empty per Save/Load §C.5 sketch), the **HUD State Signaling MEMO_NOTIFICATION** state owns the "No quicksave available" message — NOT this card. |

**HSS coexistence rule**: this card is the **menu-context** quicksave feedback. During pure `Context.GAMEPLAY`, **HUD State Signaling owns** the quicksave feedback render (HSS L231 — "HUD toast for Quicksave/Quickload"). The card lives in two parallel surfaces:
- **Gameplay** → HSS prompt-strip with `MEMO_NOTIFICATION`-style render (HSS owns)
- **Menu open (Main Menu / Pause)** → this card mounted as a child of the active Menu (Menu System owns)

**This spec covers the Menu-context render only.** The HSS gameplay render is owned by HSS; cross-reference but not re-specced.

> **Edit, 2026-04-29**: Per accessibility-requirements.md Cognitive row L153 + Save/Load Tuning Knobs `QUICKSAVE_CONFIRMATION = HUD notification, non-blocking`, the **HUD-side feedback** is the load-bearing surface. The Menu-context card is a **mirror render** for cases where the HSS prompt-strip is hidden during Pause (HUD Core CR-22 — HUD tweens killed on context-leave from GAMEPLAY). Without this Menu-context card, F5 in Pause Menu would produce silent success (audible only via Audio's `game_saved` chime) — confusing.

**Emotional state assumptions** (in priority order):
1. **Reassurance-seeking** — "did F5 work?" — single-glance read of a small peripheral element. The card must be readable in < 200 ms peripheral vision.
2. **Brief acknowledgment** — player has already moved past the save event and the card is just confirming after the fact. Short fade-out.
3. **No expectation of interaction** — the card is information-only.

**Held inputs across the boundary**: the player is mid-gameplay or mid-Pause. The card never receives focus, never consumes input, never modifies InputContext. Held movement keys, button presses, and gameplay input route normally to the underlying surface.

---

## Navigation Position

The Feedback Card is **not a screen** the player navigates to — it is mounted by Menu System (or HSS for the gameplay-context render) in response to `Events.game_saved` / `Events.game_loaded` events.

**Mounting parents** (per Menu System §C.2 row 11: "Direct child of MainMenu/PauseMenu/active section root"):
- MainMenu shell (when Main Menu open and player presses F5 — uncommon but valid)
- PauseMenu shell (when Pause open and player presses F5 — common during stress-save)
- ~~Active section root (during gameplay)~~ — **HSS owns this case** per HSS L231

**InputContext push/pop**: NONE. This card is purely visual; it does not push or pop any context.

**Stack depth**: unaffected. The feedback card lives outside the InputContext stack entirely.

**Returning from feedback card**: not applicable — the card auto-fades and is not "returned from" by the player.

---

## Entry & Exit Points

### Entry Sources

**Slot filter rule**: The card subscribes to `Events.game_saved`; the handler filters on `slot == 0` and ignores all other slot values. Manual save success (slots 1–7) is presented by `save-game-screen.md`'s in-card confirmation, NOT by this surface.

| Entry Source | Trigger | Carries this context |
|---|---|---|
| `Events.game_saved(slot, section_id)` while Menu surface mounted | `SaveLoad.save_to_slot(0)` succeeded | `slot: int` — card fires **only for slot 0** (quicksave/autosave). `slot` values 1–7 are filtered out at the handler; manual-save feedback is owned by the Save Game screen. |
| `Events.game_loaded(slot)` while Menu surface mounted | `SaveLoad.load_from_slot(N)` succeeded | `slot: int` — but practically `LOAD_FROM_SAVE` triggers LS scene transition that destroys the Menu surface within ~140 ms; the card may not have time to fully render. Render the card defensively but do not block any LS path waiting for the card to fade. |

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Auto-fade** | After `quicksave_feedback_duration_s` (1.4 s default) elapses | Card fades over 200 ms then `queue_free()`s; only exit path |
| **Surface destroyed** (Menu unmount, scene transition) | Pause `queue_free()`, Main Menu `change_scene_to_file`, LS `LOAD_FROM_SAVE` transition | Card destroyed alongside its parent; no orphan |

### Irreversible exit warnings

**None.** The card is information-only. Auto-fading the card has no side effect on game state.

---

## Layout Specification

### Information Hierarchy

| Rank | What the player must see | Why it ranks here | How it is communicated |
|---|---|---|---|
| 1 | "**Save took effect.**" (or load) | Single-purpose feedback. Without this, the player does not know F5 worked. | The stamp text `DISPATCH FILED` or `DISPATCH LOADED` in DIN 1451 12 px Ink Black on a Parchment card — readable in peripheral vision |
| 2 | (optional) Slot identifier | Player may want to know "slot 0" vs "slot 3" — but quicksave is always slot 0; manual saves do not surface here per OQ. | Subtle text — DEFERRED: if implementation ships without slot ID, that is acceptable. Slot 0 is the only case at MVP+VS. |

**Categorically NOT shown** (per Pillar 5):
- Save thumbnail / screenshot
- Timestamp / elapsed-time
- Section name / location
- Achievement-style decoration
- Mission-progress indicator
- "X of Y" anything (Document Collection FP-DC-2)
- Slot count / save quota
- "Don't show this again" toggle
- Animation flourishes (no spin, glow, particle, etc.)

### Layout Zones

Two zones — minimal.

```
ZONE A — Card body (small Parchment card, anchored bottom-right OR top-right when Pause is open)
  └── A.1 — Stamp text label
```

**Anchor specification (1080p baseline):**

| Zone | Anchor (gameplay HSS render) | Anchor (Menu-context render) | Size | Z-order (`CanvasLayer.layer`) |
|---|---|---|---|---|
| A — Card body | (HSS-owned — not in this spec) | bottom-right of viewport when Pause Menu is **NOT mounting the folder there** — but the folder lives bottom-right per pause-menu.md V.1; therefore: **top-right of viewport when Pause is open** (resolves Pause OQ-PM-7) | `220 × 36 px` at 1080p baseline | 8 (within Menu surface) — below ModalScaffold (20) |

> **Position resolution for Pause OQ-PM-7**: Pause Menu folder occupies bottom-right 760 × 720 px. Quicksave feedback card cannot stack underneath without overlap. **Decision**: when Pause is the mounting parent, the card anchors to **top-right** of viewport (above the folder). When Main Menu is the mounting parent, the card anchors to **bottom-right** (Main Menu's button stack is left-leaning per main-menu.md). When gameplay is active (HSS render), HSS owns the position (typically center-bottom prompt strip per HSS §C).

**Aspect-ratio behavior**: 16:9 baseline. Card position is `ANCHOR_TOP_RIGHT` (Pause context) or `ANCHOR_BOTTOM_RIGHT` (Main Menu context) with 24 px viewport-edge margin. On ultrawide (21:9), card stays anchored to the chosen corner; the wider gameplay framebuffer behind doesn't affect placement.

### Component Inventory

| Zone | Component | Type | Asset / Theme | Interactive? | Pattern |
|---|---|---|---|---|---|
| A | Card body | `PanelContainer` w/ `StyleBoxFlat` | `bg_color = Parchment #F2E8C8`; hard 0 px corners; no shadow; `mouse_filter = MOUSE_FILTER_IGNORE` (non-focusable per CR-11) | No | n/a |
| A.1 | Stamp text Label | `Label` | DIN 1451 Engschrift 12 px Ink Black `#1A1A1A`; left-aligned with 12 px L margin; text = `tr("menu.quicksave.feedback")` → `DISPATCH FILED` or `tr("menu.quickload.feedback")` → `DISPATCH LOADED` | No (`mouse_filter = MOUSE_FILTER_IGNORE`) | n/a |

> No additional decoration. No icon. No stamp graphic. No paper-fibre noise (the small size doesn't benefit). The card is intentionally austere — it is the *minimum* acknowledgment.

### ASCII Wireframe

**1080p baseline; Pause Menu mounted (folder bottom-right); feedback card top-right.**

```
┌──────────────────────────────────────────────────────────────────────┐
│                                          ┌────────────────────┐  ←─ feedback card
│ [GAMEPLAY FRAMEBUFFER VISIBLE]           │ DISPATCH FILED     │      top-right (220 × 36 px)
│  behind 52% Ink Black                    └────────────────────┘
│  Pause overlay                                                       │
│                                                                      │
│                                                                      │
│                                                                      │
│                                                                      │
│                                                  ┌──┤TAB├─┐          │
│                                                  │ STERLING│          │
│                                          ┌───────┤ E. ─── ├─────────┐│
│                                          │       └─────────┘        ││
│                                          │                          ││
│                                          │   [PAUSE BUTTON STACK]   ││
│                                          │                          ││
│                                          └──────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

**Reading the wireframe:**
- Card `220 × 36 px` anchored top-right with 24 px viewport-edge margin (8 px clearance from the folder's tab if it overhangs upward; in practice top-right and tab top do not collide because the folder is bottom-right anchored).
- Single stamp text line, left-aligned 12 px L margin within the card.
- No backdrop overlay — the card sits directly on the gameplay framebuffer (or atop the 52% Ink Black Pause overlay, depending on context).
- Card auto-fades after 1.4 s.

**Reduced-motion variant**: card appears instantly (no fade-in tween); fades out instantly at duration end (no fade-out tween). The Audio's `game_saved` chime (200 ms tock, owned by Audio) still plays.

---

## States & Variants

| State / Variant | Trigger | What changes | Reachability |
|---|---|---|---|
| **Default — visible 1.4 s** | `Events.game_saved` or `Events.game_loaded` arrives while Menu surface mounted | Card fades in (200 ms); persists at full opacity (1.0 s); fades out (200 ms); `queue_free()`s | Always |
| **Stacked-event — replaced** | A second `Events.game_saved` fires while card is visible (e.g., autosave + quicksave within ~1 s) | Existing card `queue_free()`s; new card mounts fresh (no animation chaining) — most-recent-wins | Edge case |
| **Quicksave (DISPATCH FILED) variant** | `Events.game_saved` event | Stamp text = `DISPATCH FILED` | Most common |
| **Quickload (DISPATCH LOADED) variant** | `Events.game_loaded` event | Stamp text = `DISPATCH LOADED` | Rare (LS transition usually destroys the surface first) |
| **Reduced-motion variant** | `Settings.accessibility.reduced_motion_enabled == true` | No fade-in / fade-out tweens; appears + disappears instantly | Determined at `_ready()` |
| **Surface-destroyed-mid-render** | Mounting parent `queue_free()`s while card is mid-render (e.g., LS transition fires < 1.4 s after card mounts) | Card destroyed alongside parent; no orphan; no error | Edge case |

**Empty / loading / error states**:
- **Empty state**: not applicable. Card is event-driven; never renders without an event.
- **Loading state**: not applicable — saves are < 10 ms.
- **Error state**: failed saves do NOT render this card. Save-Failed dialog (`save-failed-dialog.md`) is the failure surface. This card is success-only.

---

## Interaction Map

This card is **non-interactive**. Listed here for completeness.

| Action | KB/M binding | Gamepad binding | Outcome |
|---|---|---|---|
| Card appears | n/a (event-driven mount) | n/a | `Events.game_saved` / `game_loaded` arrives → mount + fade-in tween starts |
| Card persists | n/a | n/a | 1.0 s at full opacity (per `quicksave_feedback_duration_s = 1.4 s` minus 200 ms fade-in minus 200 ms fade-out) |
| Card auto-fades | n/a | n/a | After persist phase, 200 ms fade-out → `queue_free()` |
| Player presses F5 again during render | F5 → fires `Events.game_saved` → triggers most-recent-wins | n/a | Existing card destroyed, new card mounts |
| Click on card | (no effect) | n/a | `mouse_filter = MOUSE_FILTER_IGNORE` — clicks pass through to whatever is underneath |
| Tab to card | (cannot — `focus_mode = FOCUS_NONE`) | n/a | Card is not in focus order |

### Mouse-mode contract

The card does NOT touch `Input.mouse_mode`. Inherits from mounting parent.

### Same-frame protection

Not applicable — card has no input handler.

---

## Events Fired

The card is a pure consumer of `Events.game_saved` / `Events.game_loaded`. It fires nothing.

### Events / signals consumed

| Event | Source | Card response |
|---|---|---|
| `Events.game_saved(slot: int, section_id: StringName)` | Save/Load (publisher) | If mounted Menu surface is the appropriate context, mount feedback card with `DISPATCH FILED` text |
| `Events.game_loaded(slot: int)` | Save/Load | Mount feedback card with `DISPATCH LOADED` text — but in practice LS transition destroys the surface before the card finishes |

### Audio cues fired

**NONE owned by this card.** Per Menu System §A.1 "Cues that DO NOT exist" → "Quicksave / Quickload feedback card appearance: NO additional Menu-owned cue. Audio's `game_saved` chime (~200 ms soft tock, SFX bus) already fires on the `Events.game_saved` signal in parallel; both reactions are to the same signal. Card and chime coexist without collision."

The card is **silent**. Audio is owned by Audio system.

### Cross-cut audio (NOT owned by this card — listed for completeness)

| Cue | Owned by | When fires |
|---|---|---|
| `game_saved` chime (~200 ms soft tock) | Audio (subscribed to `Events.game_saved`) | Same instant as card mount |
| `game_loaded` — none | Audio | Save/Load §No direct interaction L168 — "Audio plays no SFX on `game_loaded`" |

### Persistent-state-modifying actions

**NONE.** The card is read-only.

### Telemetry / analytics events

Deferred to post-MVP. No analytics layer at MVP+VS.

---

## Transitions & Animations

### Card-appear

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Card opacity | `modulate.a` 0 → 1 | `TRANS_LINEAR` | 200 ms | Fade-in on mount |
| Card position | (instant — no tween) | n/a | 0 ms | Card snaps to anchor; no slide |

### Card-persist

| Property | Value | Duration | Notes |
|---|---|---|---|
| Card opacity | `modulate.a = 1.0` | 1000 ms (1.0 s) | Full visible phase |

### Card-fade

| Property | Value | Curve | Duration | Notes |
|---|---|---|---|---|
| Card opacity | `modulate.a` 1 → 0 | `TRANS_LINEAR` | 200 ms | Fade-out before `queue_free()` |
| `queue_free()` | (deferred to fade end via `tween.finished`) | n/a | t = 1400 ms | Total lifetime 1.4 s |

**Total budget**: 200 ms fade-in + 1000 ms persist + 200 ms fade-out = 1400 ms = 1.4 s = `quicksave_feedback_duration_s` per Menu System §G.1 implied.

**Audio sync**: NONE. Audio's chime is owned by Audio and fires at the same instant as `Events.game_saved` (which is the same instant as card mount). The card itself is silent.

**Reduced-motion variant**:
- Fade-in suppressed — card visible at full opacity instantly
- Fade-out suppressed — card disappears instantly at 1.4 s
- Total visible duration unchanged at 1.4 s

### Motion-sickness audit

- No camera movement, no looping animation, no flashing, no parallax. Single fade-in + fade-out, both linear, both 200 ms.
- Card position is static during render.
- WCAG 2.3.1/2.3.2 compliant.

---

## Data Requirements

| Data | Source System | Read / Write | Cardinality | Notes |
|---|---|---|---|---|
| `Events.game_saved` payload (`slot: int`, `section_id: StringName`) | Events autoload | Read (event) | event-driven | Drives `DISPATCH FILED` text variant |
| `Events.game_loaded` payload (`slot: int`) | Events autoload | Read (event) | event-driven | Drives `DISPATCH LOADED` text variant |
| `Settings.accessibility.reduced_motion_enabled` | SettingsService | Read | 1 bool | Gates fade tweens |
| `Settings.ui_scale` | SettingsService | Read | 1 float | Inherited via `project_theme.tres` |
| `quicksave_feedback_duration_s` | Menu System §G.1 tuning knob | Read | 1 float | Default 1.4 s |
| Localized stamp strings | Localization Scaffold | Read | 2 strings | `menu.quicksave.feedback` + `menu.quickload.feedback` (already locked in Menu System §C.8) |

### Architectural concerns

- **No game-state polling.** Card is event-driven; no `_process()` loop.
- **No persistent writes.** Card is read-only.
- **Memory cost negligible.** Single `PanelContainer` + single `Label`. Auto-`queue_free()`s after 1.4 s.

### Forbidden data reads

| Data | Why forbidden |
|---|---|
| Save thumbnail / screenshot / metadata | Not surfaced — Pillar 5 register; the card is a stamp, not a preview |
| Section name / location / progress | Not surfaced — would clutter and exceed period-authentic register |
| Player name / character data | Not surfaced |
| Time-played / session-length | Not surfaced — Pillar 5 |

---

## Tuning Knobs

| Knob | Range | Default | Owner | Notes |
|---|---|---|---|---|
| `quicksave_feedback_duration_s` | 0.5 – 3.0 s | 1.4 s | ux-designer | Total card lifetime (200 ms fade-in + persist + 200 ms fade-out). Also referenced in Data Requirements and Menu System §G.1. Tune at first soak playtest per OQ-QSF-4. |

---

## Accessibility

**Tier**: Standard.

The Feedback Card is the lowest-stakes Menu surface. It is non-interactive, non-modal, brief, and inherits visual conventions from the Save card grid.

### Keyboard / Gamepad navigation

**Not applicable.** The card never receives focus (`focus_mode = FOCUS_NONE`). Players cannot Tab to it, gamepad-D-pad to it, or click it.

### AccessKit per-widget table

| Widget | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` |
|---|---|---|---|---|
| Card root | `statictext` (per Menu System §C.2 row 11 — non-focusable text) | `tr("menu.quicksave.feedback")` or `tr("menu.quickload.feedback")` per variant | (none) | `polite` (announces text via screen reader without interrupting current narration) |
| Card text Label | inherits — same as root | — | — | inherits |

**Polite live-region** is the correct register here: the card is informational, not urgent. Players using AT will hear "Dispatch filed" within ~500 ms of the save event without interrupting their current activity.

### Visual accessibility

- **Contrast**: Ink Black `#1A1A1A` on Parchment `#F2E8C8` ≈ 14.8:1 → passes WCAG AAA.
- **Color-as-only-indicator**: text is the entire signal. No color encoding. Compliant.
- **Text size**: 12 px DIN 1451 at 1080p baseline. At 75% scale → 9 px (passes V.9 #8 9 px DIN floor). At 150% → 18 px.
- **Colorblind**: card uses Parchment + Ink Black only; no chromatic information. Compliant in all three simulator modes.

### Photosensitivity

- **No flashing** — single fade-in / fade-out, both linear, both 200 ms. WCAG 2.3.1/2.3.2 do not apply to slow opacity ramps.
- Compliant by absence.

### Reduced-motion

Honored — fade tweens suppressed; card appears + disappears instantly. Total visible duration unchanged.

### Screen-reader walkthrough

1. Player presses F5 in Pause Menu → `Events.game_saved` → card mounts with text `DISPATCH FILED`
2. AccessKit polite live-region: AT announces "Dispatch filed" within 500 ms (NOT interrupting any current focus narration)
3. After 1.4 s, card `queue_free()`s. AT does not announce the disappearance (polite + non-modal).

Manual walkthrough at `production/qa/evidence/quicksave-feedback-card-screen-reader-[date].md`.

### Accessibility notes

- **Polite + non-modal** is the right register: this is a confirmation, not a warning. Players using AT during gameplay should not have their narration interrupted by save confirmations.
- **Coexistence with HSS**: when gameplay is active and HSS is rendering its own quicksave feedback, this Menu-context card does NOT mount (HSS owns the gameplay-context feedback). Only one feedback at a time per save event.

---

## Localization Considerations

### Strings (already locked in Menu System §C.8)

| tr-key | English | English chars |
|---|---|---|
| `menu.quicksave.feedback` | DISPATCH FILED | 14 |
| `menu.quickload.feedback` | DISPATCH LOADED | 15 |

### Expansion budget

Card body is 220 px wide × 36 px tall. DIN 1451 12 px advance ≈ 5.4 px per char → ~38 char ceiling per single line at 12 px (with 12 px L margin and 8 px R margin → 200 px usable).

| English | EN chars | At 40% expansion | At 60% expansion | Within 38-char limit? |
|---|---|---|---|---|
| DISPATCH FILED | 14 | 20 | 22 | ✅ |
| DISPATCH LOADED | 15 | 21 | 24 | ✅ |

**Conclusion**: large headroom. Localization risk is **VERY LOW**.

### Number / date / currency formatting

None used.

### RTL support

Not committed at MVP+VS. Post-launch RTL would mirror anchor (top-LEFT or bottom-LEFT) and right-align text.

### `auto_translate_mode`

`AUTO_TRANSLATE_MODE_ALWAYS` on the Label.

### Translator brief

- **Register**: 1965 BQA stamp register (all caps, period typewriter). The English `DISPATCH FILED` reads as a clerk's stamp on a paper record.
- **Tone**: terse, factual. Not "Saved!" or "Game saved."
- **Both keys are stamps** — should translate as paper-record-filing register, not modern "save" register.

---

## Acceptance Criteria

### Mount & Default State

- [ ] **AC-QSF-1.1 [Logic]** When `Events.game_saved.emit(0, "plaza")` fires while Pause Menu is active, a feedback card is mounted as a child of Pause Menu within 1 frame; card is anchored top-right of viewport with 24 px edge margin; text reads `DISPATCH FILED`; no InputContext push occurs. (Slot-0-only trigger per slot filter rule in Entry Sources.)
- [ ] **AC-QSF-1.2 [Logic]** Card has `mouse_filter == MOUSE_FILTER_IGNORE` and `focus_mode == FOCUS_NONE` (non-interactive per Menu System §C.2 row 11).
- [ ] **AC-QSF-1.3 [Visual]** Mount produces a screenshot showing: card 220 × 36 px Parchment fill at top-right; text `DISPATCH FILED` in DIN 1451 12 px Ink Black; no shadow, no corner radius, no gradient.
- [ ] **AC-QSF-1.4 [Logic]** Audio's `game_saved` chime fires at the same instant as card mount (Audio L168 contract — chime is on SFX bus, owned by Audio); card itself is silent (no Menu-owned UI cue per A.1).
- [ ] **AC-QSF-1.5 [Logic]** When mounting on Pause Menu (folder bottom-right), card anchors top-right (avoids folder collision per OQ-PM-7 resolution). When mounting on Main Menu (button stack left-center), card anchors bottom-right.

### Auto-Fade

- [ ] **AC-QSF-2.1 [Logic]** Card's total lifetime is `quicksave_feedback_duration_s` (default 1.4 s = 1400 ms): 200 ms fade-in + 1000 ms persist + 200 ms fade-out.
- [ ] **AC-QSF-2.2 [Logic]** After fade-out completes, `queue_free()` is called on the card; subsequent `is_instance_valid(card_node)` returns `false`.
- [ ] **AC-QSF-2.3 [Logic]** Fade-in tween is `TRANS_LINEAR` on `modulate.a` 0 → 1 over 200 ms.
- [ ] **AC-QSF-2.4 [Logic]** Fade-out tween is `TRANS_LINEAR` on `modulate.a` 1 → 0 over 200 ms.

### Stacked Events

- [ ] **AC-QSF-3.1 [Logic]** When `Events.game_saved` fires twice within 1.0 s, the existing card is `queue_free()`d and a new card mounts with the most recent event's text. Most-recent-wins; queue depth never exceeds 1.

### Quickload Variant

- [ ] **AC-QSF-4.1 [Logic]** When `Events.game_loaded.emit(0)` fires (rare — practically pre-empted by LS transition), card mounts with text `DISPATCH LOADED` instead of `DISPATCH FILED`.

### Surface Destruction

- [ ] **AC-QSF-5.1 [Logic]** When mounting parent `queue_free()`s mid-render (e.g., LS transition starts at t = 800 ms), card is destroyed without orphan or error; no `null` reference to detached card persists.

### HSS Coexistence

- [ ] **AC-QSF-6.1 [Integration]** When `Context.GAMEPLAY` is active (no Menu surface mounted), `Events.game_saved` does NOT mount this Menu-context card; HSS owns the feedback render. Verified by injecting `game_saved` while gameplay is active and confirming no node named `QuicksaveFeedbackCard` exists in tree.
- [ ] **AC-QSF-6.2 [Integration]** When Pause Menu is mounted, `Events.game_saved` mounts this Menu-context card AND HSS does NOT also render its quicksave feedback (HUD Core CR-22 — HSS prompt-strip is hidden during PAUSE context). Only one feedback at a time.

### Reduced-Motion

- [ ] **AC-QSF-7.1 [Integration]** With `accessibility.reduced_motion_enabled == true`, card appears at full opacity instantly (no 200 ms fade-in); disappears instantly at 1.4 s (no 200 ms fade-out); total visible duration unchanged at 1.4 s.

### AccessKit / Screen Reader

- [ ] **AC-QSF-8.1 [Logic]** Card root has `accessibility_role = "statictext"`, `accessibility_name = tr("menu.quicksave.feedback")` (or quickload variant), `accessibility_live = "polite"`.
- [ ] **AC-QSF-8.2 [UI]** Manual screen-reader walkthrough (Linux Orca / Windows Narrator): F5 in Pause → AT announces "Dispatch filed" via polite live-region within 500 ms; AT does NOT interrupt any current focus narration. Evidence: `production/qa/evidence/quicksave-feedback-card-screen-reader-[date].md`.

### Visual Compliance

- [ ] **AC-QSF-9.1 [Visual]** No corner radius, no drop shadow, no gradient, no flashing. Per V.9 #1, #2, #3, #4.
- [ ] **AC-QSF-9.2 [Visual]** Card text uses palette colors only (Parchment + Ink Black).

### State Invariants

- [ ] **AC-QSF-10.1 [Logic]** Card does NOT push `Context.MODAL` or any other context. `InputContextStack.peek()` is unchanged from before mount to during render to after `queue_free()`.
- [ ] **AC-QSF-10.2 [Logic]** Card does NOT modify any persistent file. Hashing `user://settings.cfg` and `user://saves/*.res` before-and-after a mount-fade cycle: hashes match.
- [ ] **AC-QSF-10.3 [Logic]** Card subscribes to `Events.game_saved` and `Events.game_loaded` in the mounting parent (Menu System), NOT autonomously. The subscription is owned by Menu System per CR-15.

### Cross-Reference

- [ ] **AC-QSF-11.1 [Spec-trace]** HSS §C resolver priority table includes the gameplay-context quicksave feedback case. This spec inherits and does not duplicate.

- [ ] **AC-QSF-12.1 [Logic]** Given `Events.game_saved.emit(N, section_id)` fires with `N in [1..7]`, the QuicksaveFeedbackCard does NOT mount. Verifiable by emitting the signal from the Save Game grid path with `N=3` and confirming no node named `QuicksaveFeedbackCard` exists in the scene tree.

### Coverage

- Performance: 1 (AC-QSF-2.1 — 1.4 s budget)
- Navigation: 1 (AC-QSF-1.2 — non-interactive)
- Error / coexistence: 1 (AC-QSF-5.1 + 6.1 — 6.2)
- Accessibility: 1 (AC-QSF-8.1 — 8.2)
- Card-purpose-specific: 1 (AC-QSF-1.5 — anchor selection per mounting context)

Total: 18 ACs across 11 groups. Proportionate to the very narrow scope.

---

## Open Questions

| # | Question | Owner | Resolution Path | Default if unresolved |
|---|---|---|---|---|
| **OQ-QSF-1** | ~~Does Menu-context card render for manual saves (slots 1–7), or only quicksave (slot 0)?~~ **RESOLVED** 2026-04-29 | ux-designer | Card fires ONLY when the saved slot index is 0 (autosave / quicksave slot). Manual saves (slots 1–7) do NOT fire the card; manual save success feedback is handled by the Save Game screen's own confirmation flow. Per `/ux-review` 2026-04-29. See AC-QSF-12.1 and slot filter rule in Entry Sources. | **RESOLVED — slot 0 only.** |
| **OQ-QSF-2** | **Quickload card lifecycle — does it ever fully render?** LS scene transition destroys mounting parent within ~140 ms of `game_loaded`. Card budget is 1400 ms. Practically the player sees a fraction of a second. | save-load + ux-designer | Empirical test during VS sprint integration. If card renders < 100 ms, drop the `DISPATCH LOADED` variant entirely. | **Keep both variants at MVP+VS.** Player may glimpse the load card during LS fade-out; partial render is better than no render. Re-evaluate at first soak playtest. |
| **OQ-QSF-3** | **Anchor when both Main Menu AND Pause are not the mounting parent.** Edge case: the Operations Archive sub-screen is open inside Pause; player F5s. Card mounts on the Operations Archive Control? Or on the Pause root? | ux-designer + Menu System owner | Mount on the active Menu **root** (Pause root) regardless of sub-screen. Sub-screen swaps don't change the mounting target. | **Mount on Menu root (Pause / MainMenu).** Sub-screens never own the card. |
| **OQ-QSF-4** | **`quicksave_feedback_duration_s` tuning at playtest.** 1.4 s default — too short / too long? | ux-designer + game-designer + playtest | Tune at first playtest based on player reports. Range 1.0–2.0 s. | **1.4 s default at MVP+VS.** |
| **OQ-QSF-5** | **Should manual save's confirm flow play A6 stamp thud + show this card in addition to the in-card visual return?** Could double-up but feels excessive. | ux-designer + audio-director | Decide at `/ux-review`. Most likely: A1 typewriter clack on the in-card `[CONFIRM]` press is sufficient. No card mount, no A6. | **No card on manual save confirm.** In-card A1 + visual return to OCCUPIED is the feedback. |
| **OQ-QSF-6** | ~~Polite vs assertive AccessKit live-region.~~ **RESOLVED** 2026-04-29 | ux-designer | Live-region politeness is `polite` (informational save success, not urgent state change). Assertive politeness is reserved for error-class events per the `save-failed-advisory` pattern. No post-launch promotion path; if save-success ever needs to interrupt (e.g., warning of imminent data loss), that surface would route through `save-failed-dialog` instead. Per `/ux-review` 2026-04-29. | **RESOLVED — polite.** |

---

## Recommended Next Steps

- OQ-QSF-1 and OQ-QSF-6 resolved per `/ux-review` 2026-04-29 — no further action needed on those items
- Continue authoring `load-game-screen.md` and `save-game-screen.md`

Verdict: **COMPLETE** — small, focused UX spec authored from scratch.
