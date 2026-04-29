# UX Spec: Document Overlay

> **Status**: In Design — `/ux-review` APPROVED 2026-04-29 (5 advisories applied: Platform Target header line, slug-style pattern IDs, `lectern-pause-card-modal` rename, OQ-UX-DOV-10 added, Pillar-5 absolute count cross-checked → §G.5 has 10 items; GDD UI-4 amended to match).
> **Author**: user (agustin.ruatta@vdx.tv) + ux-designer
> **Last Updated**: 2026-04-29 (post-`/ux-review` advisories pass)
> **Platform Target**: PC (Linux + Windows, Steam) — KB+M primary; Gamepad partial parity per `technical-preferences.md` (rebinding parity post-MVP).
> **Journey Phase(s)**: Mid-Mission Discovery — fires whenever Eve picks up a document during a Section (Plaza tutorial, Lower Hall, Restaurant, Upper Hall, Bomb Disarm). Single most frequent narrative-pause beat in the game (21 documents distributed 86% off-path per `document-collection.md` §C.5; expected ~10–15 reads per playthrough at full collection).
> **Implements Pillar**: **Primary 2** (Discovery Rewards Patience — load-bearing: the *reading is the reward*, not a stat-bar increment) + **Primary 3** (Stealth as Theatre — load-bearing: sepia-dim "suspended parenthesis" register *is* the theatrical cue change); Supporting 1 (Comedy Without Punchlines — typographic register carries dry BQA voice); Supporting 5 (Period Authenticity Over Modernization — what the Overlay *refuses* to render is load-bearing).
> **Phasing**: Vertical Slice — full implementation from sprint start (no MVP/VS phasing; Document Collection ships pickup-only at MVP per DC §A; Overlay is pure VS scope per `document-overlay-ui.md` §A).
> **Template**: UX Spec
> **Authoritative GDD**: `design/gdd/document-overlay-ui.md` (1274 lines — full design contract; this spec defers to GDD §C/F/G/V/H for rules/dependencies/tunables/visuals/ACs and concentrates on player-facing UX surface, layout, and ASCII wireframe).
> **Companion specs**:
>
> - `design/ux/hud.md` — HUD Core hides itself when `InputContext.current() != GAMEPLAY` (HUD's own visibility gate per HUD CR; Overlay does NOT manipulate HUD per FP-OV-5).
> - `design/ux/pause-menu.md` — Pause is **sequential, never nested** with reading: Overlay's `_unhandled_input` consumes `ui_cancel` first; player must dismiss the Overlay then press Esc again to reach Pause Menu (CR-10).
> - `design/ux/interaction-patterns.md` — references the modal-dismiss composite (`unhandled-input-dismiss` + `dual-focus-dismiss` + `set-handled-before-pop`, all Input Routing) + `input-context-stack` (Input Routing) + `lectern-pause-register` (HUD & Notification — composite world-state register). Adds **`lectern-pause-card-modal`** (Modal & Dialog) and **`tab-consume-non-focusable-modal`** (Input Routing) as NEW pattern entries 2026-04-29 per `/ux-review` (closes OQ-UX-DOV-1; see §Cross-Reference Check below).
>
> **Register clarification — NOT Case File / manila-folder pattern**: The four `modal-scaffold` siblings (`quit-confirm.md`, `return-to-registry.md`, `re-brief-operation.md`, `new-game-overwrite.md`, `save-failed-dialog.md`) all live in the **Case File register** (manila folder, classification stamp, Cancel/Confirm button row, Pause-Menu shell). Document Overlay is a **distinct register — Lectern Pause** (Parchment paper card on sepia-dim world, BQA Blue header bar, no buttons, gameplay-time modal). Structural decisions in this spec **do NOT propagate** to the Case File modals; conversely, decisions in `quit-confirm.md` flagged `[CANONICAL]` do NOT apply here. The two registers are deliberately separate per `document-overlay-ui.md` §B refusal "Not a codex" + Art Bible §7D BQA dossier register.

---

## Purpose & Player Need

**Purpose.** This overlay is the **Vertical-Slice reading surface** for in-world documents. It exists to satisfy a single player goal — **read what the page says, in the posture of a 1965 operative giving the document her full attention** — and the behavior that surrounds it (sepia-dim, music duck, HUD hide, mouse visible) exists to support that posture without interrupting the world. The Overlay is not a tooltip, not a codex, not a cinematic, not a tutorial gate. It is a piece of paper that the player reads.

**Player need on arrival.** The player has just pressed `interact` near a document prop. They want to **read it**. They expect (per the **Lectern Pause** fantasy from `document-overlay-ui.md` §B):

- The world to recede so the page is the only thing that matters
- The page itself to be high-contrast, legible, period-authentic, and unhurried
- Their input to be unambiguous: scroll if it's longer than the card, dismiss when done, that's it
- Eve to be still — no narration, no commentary, no cinematic flourish; the player and Eve share the silence

**Failure mode if the screen is missing or hard to use** (per GDD §B refusals "Five specific shapes the Overlay could otherwise take and would be wrong"):

1. **Tooltip register.** A small in-world floating panel that vanishes after 2 seconds → players miss content; Pillar 2 violated (no posture, no patience). The card must persist until the player chooses to dismiss.
2. **Codex / archive register.** Library-shelf vibe with X-of-Y counters and cross-reference links → Pillar 5 (period authenticity) and Pillar 2 (Discovery Rewards Patience) both broken; the document becomes a checklist item rather than an object. The polished case-file archive (re-reading collected documents from Pause Menu) is **Polish-or-later** per DC §E.12 — explicitly NOT this spec.
3. **Cinematic register.** Dramatic zoom, music swell, page-flip animation → Lectern Pause anchor violated; the moment becomes performative rather than attentive. Sepia-dim does the entire dramaturgical job; nothing else is needed.
4. **Modern reading-app register.** Smooth-scroll inertia, swipe-to-next-page, tap-to-reveal, font-resize buttons, share/bookmark actions → Pillar 5 broken on multiple fronts. The body grammar must be: scroll, dismiss. Nothing else.
5. **Narration register.** Eve reads aloud / handler whispers translation / VO localization → the Overlay's silent-reading model is decisive (VO localization is ~10× the cost of text per Localization Scaffold OQ-2; the moment is composed for silence). AccessKit reads body text directly via screen-reader; recorded VO is forbidden.

**Single-sentence formulation.** *"The player arrives at this overlay wanting to read what the page says, in the posture of a 1965 operative who has stepped into an alcove and given the document her full attention; the screen must serve that posture and refuse every modern UI affordance that would betray it."*

**Pillar 5 register applies, AND the Lectern Pause anchor governs.** Per GDD §G.5, ten anchor-enforced absolutes (no zoom/pan, no auto-dismiss, no music swell, no swipe-to-next-page, no typewriter character-reveal, no inline glossary links, no progress percentage, no recorded VO, no smooth-scroll inertia, no in-overlay font-resize controls). Any future amendment that proposes relaxing any of these triggers a creative-director gate per the anchor test: *"Would a 1965 professional reader, doing her job, accept this from the page in front of her?"*

---

## Player Context on Arrival

**When the player first encounters this overlay**: Plaza section, **first document pickup**, ~3–5 minutes into a fresh playthrough. This is the player's first introduction to the Overlay; tutorial-gating is handled by the document-collection HUD prompt-strip ("INTERACT — F / Y") that fires when the player approaches the document, not by the Overlay itself (the Overlay has no first-time tutorial overlay text — its grammar must be discoverable from the footer hint and standard Esc-dismiss convention alone).

**Three arrival paths** (all variations of the same trigger — `Events.document_opened` from Document Collection):

| Arrival path | Frequency | Immediately before | Emotional register |
|---|---|---|---|
| **Auto-open on pickup (Option A — VS default)** | Most common; fires on every successful `interact` near a document prop | Player approached document prop; HUD prompt-strip showed "INTERACT — F / Y"; player pressed `interact`; DC's `_on_player_interacted` called `DC.collect()` then `DC.open_document(id)` in same frame; DC emitted `document_opened`; Overlay's subscriber fired (CR-2 + GDD §C.4) | **Curious-and-attentive.** The player chose to interact. They expect a payoff. The 12-frame sepia fade-in is the cue change; the card is full saturation against it. |
| **Auto-open delayed (Option A-delayed — fallback per CR-2-bis)** | Conditional — only if VS playtest reveals patrol-density issues (≥30% of deaths within 5 s of pickup, OR ≥50% of dismissals < 1 s after open). Configurable via `document_auto_open_delay_s` tuning knob (default 0.0). | Same as above, but with a 1.0–2.0 s delay window during which the player can move freely (sepia not yet engaged) before the Overlay mounts | **Same as auto-open**, but with breathing room for the player to clear an active patrol before being modal-locked |
| **Section-load mid-read (E.7 / E.19 — defensive only)** | Unreachable in normal play; only occurs if Mission & Level Scripting unloads a section while a document is open (e.g., dev-tool teleport, scripted catastrophe) | n/a | n/a — defensive close only; player does NOT see this path during normal play |

**Emotional state design assumes**. **Curious-and-attentive, not time-pressured.** The sepia-dim register signals "the world is held in place; you have time to read." The card is staged to reward attention: the player can take 8–30 seconds for a 200-word body and the design accepts that as correct. Players who dismiss in <1 s after open are flagged in analytics (Option A-delayed trip condition); the design assumes **most players read most of the body**. Patrol risk during reading is real but **deliberately not mitigated by the Overlay** — Pillar 3 ("the world doesn't actually freeze; sepia is dramaturgical, not literal") requires that AI continues ticking. The player is responsible for choosing a safe spot to read; the Overlay's job is to support the reading once the choice is made.

**Voluntary or sent-here**. **Always voluntary.** The player chose to interact with the document prop. The Overlay is a payoff, not an imposition. (Note: if Option A-delayed ships, the timing of mount becomes slightly less-voluntary — the player chose pickup, but the *modal mount* is delayed-sent; this is acceptable because the player still consents-by-pickup.)

**What the screen must NOT assume about player context**:

- The player **may be in active patrol-line-of-sight** when the Overlay mounts. Sepia does NOT freeze AI; if the player picks up a document while a guard is about to round the corner, they may take damage *while reading*. Combat itself is gated (`InputContext.DOCUMENT_OVERLAY` blocks combat input per Combat's own context gate), but enemy AI ticks normally and damage applies. The footer hint must remain the only on-card text; no "PRESS ESC TO DEFEND" mid-read panic affordance (would violate Lectern Pause).
- The player **may be on KB+M, gamepad, or switching mid-read**. The footer hint shows both glyphs simultaneously: "ESC / B — Return to Operation" (no glyph swap based on detected input — keeps the hint static and discoverable for both populations).
- The player **may be using assistive tech**. AccessKit dialog role + heading announce on `TitleLabel` + scroll-area role on `BodyScrollContainer` + assertive one-frame announce on mount (per GDD §C.8). Tab and Shift+Tab are consumed (CR-16) to prevent focus escape from the modal subtree.
- The player **may have changed locale mid-session**. `NOTIFICATION_TRANSLATION_CHANGED` re-resolves both title and body via `tr()` reassignment; scroll position resets to top (deliberate trade-off per CR-8 — RTL-correctness wins; LTR scroll-loss accepted at VS).
- The player **may NOT speak fluent English**. Body word-count ceiling 250 words English (375 words German rendered at 1.5× expansion ceiling per OQ-DOV-COORD-4); 4 strings owned by this Overlay (`overlay.dismiss_hint`, `overlay.scroll_hint`, `overlay.accessibility.dialog_name`, `overlay.accessibility.scroll_name`) translated per locale.
- The player **may NOT be in a position to read 30 seconds**. The Lectern Pause fantasy implies they *should* be (alcove off the patrol route), but the design accepts that they may pick up a document mid-chase and dismiss within 1 second to keep moving. That dismiss path is fully supported (Esc / B — single press). The fantasy is offered, not enforced.

---

## Navigation Position

**This overlay is a per-section gameplay-time modal mounted directly by Mission & Level Scripting**, not by `ModalScaffold` (the Case File modal host). It sits at `CanvasLayer` index 5 (locked by ADR-0004 §IG7), between the Post-Process Stack sepia ColorRect at index 4 and the Pause Menu at index 8. It has **no parent screen of its own** — it is a side-effect of a successful `interact` on a document prop in the 3D world.

**Position summary**:

```
[Section root scene tree]  (loaded by MLS at section-enter)
    │
    ├── Gameplay viewport (CanvasLayer 0 — 3D world)
    │
    ├── PPS sepia ColorRect (CanvasLayer 4 — engaged on Overlay open, faded over 0.5 s)
    │
    ├── DocumentOverlayUI (CanvasLayer 5)  ← (THIS OVERLAY)
    │       └── ModalBackdrop (Control, MOUSE_FILTER_STOP)
    │           └── CenterContainer
    │               └── DocumentCard (PanelContainer 960×680 px — Parchment + BQA Blue header)
    │                       │
    │                       ├── [Esc / B / ui_cancel] → C.5 close lifecycle (6 steps) → IDLE
    │                       │       Returns mouse mode, pops InputContext, fades sepia out, hides card,
    │                       │       calls DC.close_document(); HUD reappears via its own InputContext gate.
    │                       │
    │                       └── [section_unloading signal from MLS] → C.5 synchronous (skip sepia fade)
    │                               → IDLE before MLS frees the section. (Defensive; not normal play.)
    │
    ├── HUDCore (CanvasLayer 6 — hides itself when InputContext != GAMEPLAY)
    │
    ├── PauseMenu (CanvasLayer 8 — never simultaneously active with Overlay; sequential per CR-10)
    │
    └── SubtitleSystem (CanvasLayer 15 — suppressed during DOCUMENT_OVERLAY per ADR-0004 §IG5)
```

**Top-level vs context-dependent**: This overlay is **strictly context-dependent** — it can only mount as a child of a loaded Section's scene tree, in response to `Events.document_opened` from Document Collection. It cannot be reached from Main Menu, from Pause Menu, from Settings, or from any non-section context. It does NOT appear in any navigation menu; there is no list-of-collected-documents UI in this spec (that's Polish-or-later per DC §E.12).

**Sibling-of-which surface**: At the gameplay-time modal level, the Overlay has **no siblings** at MVP/VS. Cutscenes & Mission Cards (#22) is a separate gameplay-time UI surface but uses its own letterbox + card register on a different CanvasLayer. The Overlay is the **only** Parchment-on-sepia-dim modal in the game. Structural decisions here do NOT propagate to other surfaces.

**Per CR-3 single-document-open invariant**: The Overlay shows **exactly one document at a time**. If a second `document_opened` fires while one is already open, the second is discarded with `push_error` (defensive guard; unreachable in normal play because `InputContext.DOCUMENT_OVERLAY` blocks `player_interacted`). There is no document-list, no tab strip, no "next/previous document" navigation within the Overlay.

**No deep-link**: Cannot be triggered from console / debug at MVP. Triggering requires the player to physically interact with a document prop in the 3D world.

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context | MVP/VS |
|---|---|---|---|
| **Document prop pickup (Option A — VS default)** | Player presses `interact` while in pickup range of a `DocumentPickup` Area3D node. DC's `_on_player_interacted` calls `DC.collect()` (deduplicated; updates collected set) then `DC.open_document(id)` in same frame. DC emits `document_opened(id)` synchronously. Overlay's `_on_document_opened` runs C.4 8-step lifecycle. | `InputContext.GAMEPLAY` on stack; mouse mode = whatever gameplay uses (typically CAPTURED for FPS mouselook); HUD visible; sepia OFF. After mount: `InputContext.DOCUMENT_OVERLAY` pushed; mouse mode = VISIBLE; HUD hidden via own gate; sepia engaging. | VS |
| **Document prop pickup (Option A-delayed — fallback)** | Same `interact` press, but `DC.open_document(id)` deferred via Timer with `wait_time = document_auto_open_delay_s` (default 0.0; configurable via tuning knob). Player can move during delay window; sepia not engaged until window expires. | Same as above, but the *modal mount* delay window allows the player to clear an active patrol before being locked into the read | VS-conditional (only ships if playtest trip conditions per CR-2-bis fire) |
| **Section-load with document already collected** | NOT a real entry path. Per DC §E.12, Overlay state is ephemeral; on load-from-save no document is open by design. Listed here for completeness only. | n/a | n/a |

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| **Dismiss to gameplay (the only normal exit)** | Player presses `ui_cancel` (`Esc` on KB+M, `B/Circle` on gamepad) → Overlay's `_unhandled_input` consumes the event, runs C.5 6-step close lifecycle | (a) `set_input_as_handled()` FIRST (Input CR-7 — silent-swallow prevention; required to keep the same-frame Esc from leaking to Pause Menu); (b) `Input.mouse_mode = _prev_mouse_mode` (typically restores CAPTURED); (c) `InputContext.pop()`; (d) `PostProcessStack.disable_sepia_dim()` (0.5 s fade-out); (e) `Card.visible = false` + text cleared synchronously (Option B "snappy dismiss"); (f) `DocumentCollection.close_document()` → DC emits `document_closed` → Overlay's `_on_document_closed` callback fires → `_state = IDLE`. **No SFX owned by Overlay** — Audio's own `document_closed` subscription unducks music + ambient. **HUD reappears** via its own InputContext gate (no Overlay-side action). |
| **Section unload mid-read (defensive, non-player-initiated)** | MLS emits `section_unloading(section_id)` while `_state == READING` for a document in the unloading section | C.5 lifecycle runs synchronously **without waiting for `ui_cancel`**; sepia-out fade may be **skipped** if PPS is being torn down by section unload; `DC.close_document()` called BEFORE DC's `_exit_tree()` runs. Per CR-12. **Player perception**: the section transition occludes the read end; the player does not see a flicker. |
| **OS-level window close (Alt+F4 / Cmd+Q / kill signal)** | Player closes the application while Overlay is open | OS terminates the process; no `_close()` call runs; Save/Load doesn't persist Overlay state per DC §E.12 — on next launch, no document is open. Acceptable. No save is at risk because the document was never persisted in the read state. |

### Irreversible exit warnings

**None.** This Overlay's exits are all reversible — dismissing returns the player to gameplay with no state loss; the document is still in the collected set; the player can re-trigger the read by re-interacting with the prop (post-VS scope: re-reading from a Pause Menu archive, deferred to Polish per DC §E.12). The `document_collected` signal fires at pickup, NOT at read completion — so the collection state is captured even if the player dismisses mid-read.

---

## Layout Specification

### Information Hierarchy

The Overlay must communicate, in priority order:

1. **The document body** — the *reason the screen exists*. Largest visual region; full Parchment field; American Typewriter Regular at the FontRegistry base size (16 px at 1.0× `text_scale_multiplier`; scales to 18–24 px at 1.5×–2.0× per WCAG 2.1 SC 1.4.4 / OQ-DOV-COORD-12). **Single most prominent element** — everything else is framing.
2. **The document title** — establishes register and orientation ("you are reading a PHANTOM logistics memo / a BQA dispatch / a restaurant manager's note"). BQA Blue header bar, American Typewriter Bold 20 px in Parchment color, single line, ellipsis-truncates (`OVERRUN_TRIM_ELLIPSIS_CHAR`) — never wraps to a second line. **Second priority** — must be visible on first frame so the player knows what they're reading before the body register hits.
3. **The dismiss affordance** — "ESC / B — Return to Operation" footer hint, American Typewriter Regular 12 px, centered, Ink Black on Parchment. **Third priority** — discoverable on first read, ignorable thereafter; the hint is the *only* interaction surface visible on the card and replaces any explicit Close Button (which is forbidden by FP-OV-9).
4. **The scroll affordance** *(conditional)* — "SCROLL — ↑ ↓ / Right Stick" footer hint, shown ONLY when body overflows card height (`ScrollContainer.vertical_scroll_mode == SCROLL_MODE_AUTO` with overflow detected). Stacks above the dismiss hint when present. **Fourth priority** — solves the scroll-discoverability gap (ux-designer 2026-04-27 BLOCKING finding); silent when content fits.
5. **The scroll bar** *(conditional)* — 4 px thin Ink Black on Parchment, right edge of body region, auto-shows on overflow. **Lowest priority** — present only when needed, never claims real estate.

**What is explicitly NOT in the hierarchy** (per V.5 visual restraint compliance check):

- ❌ Document type icon / classification badge / PHANTOM/BQA logo
- ❌ Progress percentage / X-of-Y counter / "scroll progress 47%"
- ❌ Close / Done Button (FP-OV-9)
- ❌ "Mark as read" / "Add to favorites" / "Translate" secondary buttons (FP-OV-11)
- ❌ Search bar / filter / table-of-contents / chapter list
- ❌ Inline images, signatures, decorative ornaments, paper-edge curl
- ❌ Drop shadow / soft glow on the card

### Layout Zones

**Three vertical zones inside the card**, plus the modal backdrop:

| Zone | Height | Background | Contents |
|---|---|---|---|
| **Z0 — Modal Backdrop** | Full viewport | Transparent (sepia ColorRect at CanvasLayer 4 provides the dim) | `MOUSE_FILTER_STOP` Control — absorbs all mouse clicks behind the card so clicking outside the card area does NOT dismiss (CR-10) |
| **Z1 — Card Header** | 64 px (fixed) | BQA Blue `#1B3A6B` `StyleBoxFlat`, hard-edged top of card | `TitleLabel` (American Typewriter Bold 20 px, Parchment color, 24 px L/R margin, 12 px T/B margin, ellipsis-truncate) |
| **Z2 — Card Body** | Flex (~538 px at default 680 px card; shrinks if footer height grows) | Parchment `#F2E8C8` `StyleBoxFlat` (full card frame inherited from `DocumentCard` PanelContainer) | `BodyScrollContainer` wrapping `BodyText` (RichTextLabel; American Typewriter Regular 16 px Ink Black; bbcode-enabled; autowrap word; 32 px T/B padding + 48 px L/R padding); 4 px scrollbar on right edge when overflowing |
| **Z3 — Card Footer** | 30 px when only DismissHintLabel; 44 px when ScrollHintLabel also visible | Parchment `#F2E8C8` (continuation of card body StyleBox) | `FooterVBox`: `ScrollHintLabel` (conditional — overflow only) + `DismissHintLabel` (always visible). Both 12 px American Typewriter Regular Ink Black, centered horizontally |

**Card overall dimensions**: 960 × 680 px at 1080p reference. Clamps to `min_size.x = 800` at sub-1280 px viewports (American Typewriter at body size becomes illegible below 800 px wide per F.4 layout predicate).

**Card position**: `CenterContainer` — exact viewport center. No offset. Predictable across resolutions.

### Component Inventory

| Component | Type | Pattern | Content | Interactive? |
|---|---|---|---|---|
| `ModalBackdrop` | `Control` | **`unhandled-input-dismiss`** + **`dual-focus-dismiss`** + **`set-handled-before-pop`** + **`tab-consume-non-focusable-modal`** (Input Routing composite) — see `interaction-patterns.md` | Empty (no children of own); host for `_unhandled_input` + AccessKit dialog role | Indirect — consumes `ui_cancel`, `ui_focus_next`, `ui_focus_prev` (CR-16) |
| `CenterContainer` | `CenterContainer` | Standard layout | Wraps `DocumentCard` so card is exact viewport center regardless of resolution | No |
| `DocumentCard` | `PanelContainer` | **`lectern-pause-card-modal`** (Modal & Dialog — NEW; Parchment + BQA Blue + American Typewriter; per V.1) | The card frame; theme variation `"DocumentCard"`; size 960×680 px clamped to min 800 wide | No |
| `CardHeader` | `PanelContainer` | `lectern-pause-card-modal` sub-component | BQA Blue `#1B3A6B` `StyleBoxFlat` background, 64 px tall | No |
| `TitleLabel` | `Label` | Heading announce target | `tr(_current_title_key)` value at C.4 step 6; e.g., "PHANTOM LOGISTICS MEMO — RE: SHOWTIME"; ellipsis-truncates | Focus-receiver on open (C.4 step 7b); accessibility role `heading` |
| `CardBody` | `MarginContainer` | Standard padding | 32 px T/B + 48 px L/R inside Parchment field | No |
| `BodyScrollContainer` | `ScrollContainer` | Scroll grammar (mouse wheel + arrow keys + Page Up/Dn + gamepad analog) — per-screen specification (see Interaction Map); not promoted to a formal pattern entry at VS | Wraps `BodyText`; `vertical_scroll_mode = SCROLL_MODE_AUTO` (auto-hide bar); `smooth_scroll_enabled = false` (FP-OV-12); custom 4 px Ink Black bar via theme variation `"DocumentScroll"` | Yes — receives mouse wheel + keyboard scroll; gamepad analog handled by Overlay's manual `_unhandled_input` branch (CR-9 + Gate F) |
| `BodyText` | `RichTextLabel` | `lectern-pause-card-modal` body sub-component (American Typewriter Regular; bbcode-enabled; autowrap word; `text = tr(...)` reassignment idempotent re-render — never `append_text` per FP-OV-16) | `tr(_current_body_key)` value at C.4 step 6; e.g., 200-word BQA dispatch | Indirect — pure display; mouse_filter PASS so wheel reaches ScrollContainer |
| `CardFooter` | `PanelContainer` | `lectern-pause-card-modal` sub-component | Parchment continuation; height grows from 30→44 px when ScrollHintLabel visible | No |
| `ScrollHintLabel` | `Label` | Conditional hint | `tr("overlay.scroll_hint")` value: "SCROLL — ↑ ↓ / Right Stick"; visibility toggled by overflow detection in C.4 step 7a (deferred one frame for layout settle) | No |
| `DismissHintLabel` | `Label` | Always-visible hint | `tr("overlay.dismiss_hint")` value: "ESC / B — Return to Operation"; static; no glyph swap | No |

**Existing patterns referenced** (from `design/ux/interaction-patterns.md`):

- **`unhandled-input-dismiss`** + **`dual-focus-dismiss`** + **`set-handled-before-pop`** (Input Routing) — composite "modal-dismiss `_unhandled_input` + `ui_cancel`" contract used by `ModalBackdrop`.
- **`input-context-stack`** (Input Routing) — InputContext push/pop. Used by C.4 step 3 + C.5 step 3.
- **`lectern-pause-register`** (HUD & Notification) — composite world-state register (sepia-dim + ducked music + suppressed banter + suppressed HUD + suspended alert-music transitions) entered when this Overlay opens. The card-UI sister of this register is the new `lectern-pause-card-modal` pattern (see below).
- Scroll grammar (mouse wheel + keyboard + gamepad analog right-stick) used by `BodyScrollContainer` — no formal pattern entry; documented as per-screen specification in this spec's Interaction Map. (Single consumer at VS; revisit promotion to a pattern entry if a future spec needs the same grammar.)

**New patterns appended to `interaction-patterns.md` 2026-04-29 (post-`/ux-review`)**:

- **`lectern-pause-card-modal`** (Modal & Dialog category) — Parchment-on-sepia-dim gameplay-time modal *card*; the card-UI sister of the existing `lectern-pause-register` (HUD & Notification — composite world-state register). Distinct from Case File `modal-scaffold` register; no buttons; dismissed only via `ui_cancel`; hosts a `RichTextLabel` body with optional scroll. **Single-screen instance** (Document Overlay only).
- **`tab-consume-non-focusable-modal`** (Input Routing category) — when a modal subtree contains zero secondary focusable Controls (no buttons, only one scroll region), `ui_focus_next` and `ui_focus_prev` actions are consumed and absorbed by the modal root (CR-16) to prevent focus escape. Optional polite AT announce on Tab consumption: "Document — use arrow keys to scroll, Escape to close" (post-VS enhancement).

### ASCII Wireframe

**Default state — body fits within card (no scroll)**:

```text
+--------------------------------------------------------------------------------+
|                                                                                |
|         (3D world dimmed to ~30% luminance, ~25% saturation, warm sepia        |
|          tint via Post-Process Stack ColorRect on CanvasLayer 4)               |
|                                                                                |
|                                                                                |
|         +------------------------------------------------------------+         |
|         |  PHANTOM LOGISTICS MEMO — RE: SHOWTIME VESSEL              |  ← Z1   |
|         |  (American Typewriter Bold 20px, Parchment on BQA Blue)    |  64px   |
|         +------------------------------------------------------------+         |
|         |                                                            |         |
|         |   Confirmed receipt of one (1) sample vessel for delivery  |         |
|         |   to the showtime venue. Vessel integrity must hold        |         |
|         |   through curtain. Recommend the courier verify the seal   |         |
|         |   in person; the previous shipment to Lyon was opened by   |  ← Z2   |
|         |   customs and we are not making that mistake again.        |  ~538px |
|         |                                                            |         |
|         |   On no account is the vessel to be exposed to direct      |         |
|         |   sunlight or temperature deviation greater than 4°C       |         |
|         |   from the agreed-upon range. The sample's vessel does     |         |
|         |   not leak before showtime. Repeat: it does not leak.      |         |
|         |                                                            |         |
|         |   — D.                                                     |         |
|         |                                                            |         |
|         |   (American Typewriter Regular 16px, Ink Black on          |         |
|         |    Parchment, 32px T/B + 48px L/R padding, line-height     |         |
|         |    ~28px, autowrap word; bbcode_enabled body)              |         |
|         |                                                            |         |
|         +------------------------------------------------------------+         |
|         |              ESC / B — Return to Operation                 |  ← Z3   |
|         |   (American Typewriter Regular 12px, Ink Black, centered)  |  30px   |
|         +------------------------------------------------------------+         |
|                                                                                |
|             960 px wide × 680 px tall at 1080p reference (BQA dossier card)    |
|                                                                                |
|         (HUD Core hidden via its own InputContext gate — not on screen)        |
|                                                                                |
+--------------------------------------------------------------------------------+
```

**Overflow state — body exceeds card height (scroll active)**:

```text
+--------------------------------------------------------------------------------+
|                                                                                |
|         (3D world dimmed; sepia register active)                               |
|                                                                                |
|         +------------------------------------------------------------+         |
|         |  BQA DISPATCH — ATTN: SECTION CHIEF, OPERATIONAL DIVISION  |  ← Z1   |
|         |  (Title ellipsis-truncates if longer than ~46 chars EN)    |  64px   |
|         +------------------------------------------------------------+         |
|         |                                                          ▒ |         |
|         |   Per the agreed protocol, this dispatch acknowledges    ▒ |         |
|         |   receipt of one (1) silenced sidearm, one (1) standard  ▒ |         |
|         |   issue lockpick set, and one (1) cigarette case fitted  ▒ |         |
|         |   for the audio device. All items are accounted for,     █ |  ← Z2   |
|         |   sealed, and en route to the operational handler at the █ |  ~524px |
|         |   designated drop. The handler will identify herself by  █ |  (less  |
|         |   the agreed-upon phrase ("the salt cellar is empty");   █ |   16px  |
|         |   any deviation from this phrase is to be treated as a   ▒ |   for   |
|         |   compromised contact and the package destroyed in       ▒ |  scroll |
|         |   place per the destruction protocol Section 3.2(b)(iv). ▒ |   hint) |
|         |                                                          ▒ |         |
|         |   (...continues — body overflows card height; player      ▒|         |
|         |    scrolls via mouse wheel / arrow keys / Page Up-Down /   ▒|         |
|         |    gamepad right stick / Home-End to read remaining text)  ▒|         |
|         |                                                          ▒ |         |
|         +------------------------------------------------------------+         |
|         |             SCROLL — ↑ ↓ / Right Stick                     |  ← Z3a  |
|         |              ESC / B — Return to Operation                 |  ← Z3b  |
|         |   (Both 12 px American Typewriter Regular, centered;       |  44px   |
|         |    scroll hint stacks above dismiss hint when visible)     |         |
|         +------------------------------------------------------------+         |
|                                                                                |
|             ▒ = inactive scrollbar track (auto-hide complementary)             |
|             █ = active scrollbar thumb (4px Ink Black on Parchment)            |
|                                                                                |
+--------------------------------------------------------------------------------+
```

**Reduced-motion variant** (per `accessibility.reduced_motion_enabled == true`): identical card geometry; **only the sepia transition changes** — sepia engages instantly (0 s fade) instead of 0.5 s ease_in_out. Card snap (already instant) is unaffected. Audio duck is NOT suppressed (per Audio's reduced-motion rule).

**Pseudolocalization variant** (German 1.4× expansion stress test per UI-3 + OQ-CMC-8 — required before VS milestone close per H.16):

- Title field: "PHANTOM LOGISTIK-MEMORANDUM — BETREFFEND: VORSTELLUNGS-GEFÄSS" → ellipsis-truncates at column edge → "PHANTOM LOGISTIK-MEMORANDUM — BETREFFEND…"
- Body field: 250 EN words → up to 350 DE words rendered; line count grows by ~30%; scroll engages on body content that fit in EN
- Dismiss hint: "ESC / B — Zurück zum Einsatz" (within 55-char ceiling raised from 40 per localization-lead 2026-04-27)
- Scroll hint: "ROLLEN — ↑ ↓ / Rechter Stick" (within 50-char ceiling)

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **IDLE** (default; no card visible) | Initial state on Overlay scene `_ready()`; CLOSING completes via `_on_document_closed` callback | `Card.visible = false`; `TitleLabel.text = ""`; `BodyText.text = ""`; no `InputContext.DOCUMENT_OVERLAY` on stack; sepia OFF; HUD visible; mouse mode = whatever gameplay uses; per-frame cost = 0 ms |
| **OPENING** (sepia fading in around still card) | `Events.document_opened(id)` received in IDLE | C.4 8-step lifecycle ran; `Card.visible = true` at frame 0 (instant card snap); PPS sepia Tween in progress (0–30 frames at 60 fps for 0.5 s); InputContext pushed; mouse mode VISIBLE; first-render spike (~1–3 ms) hidden behind fade. Player can read at frame 0; fade does NOT gate reading. |
| **READING** (steady-state read) | Sepia transition complete (Timer or PPS signal per OQ-DOV-COORD-2) | Sepia fully engaged (30% luminance); card fully readable; scroll active if body overflows; only accepted inputs: scroll verbs (CR-9) + `ui_cancel` (CR-6); all gameplay actions blocked by InputContext |
| **CLOSING** (post-`_close()`, awaiting DC callback) | `_unhandled_input` consumed `ui_cancel` in READING | C.5 6-step lifecycle ran; card already invisible (Option B synchronous teardown); PPS sepia Tween fading out (0.5 s); awaiting `document_closed` callback to finalize IDLE. Per-frame cost ~0 ms (card invisible; only PPS fade running) |
| **Section-unload mid-read** (defensive) | MLS emits `section_unloading(section_id)` while READING | C.5 lifecycle runs synchronously; sepia-out fade may be skipped if PPS being torn down; `DC.close_document()` called BEFORE DC's `_exit_tree()`. Player perception masked by section transition |
| **Error: invalid document id** (defensive) | `_on_document_opened(invalid_id)` — null/freed Document Resource OR malformed (empty `title_key` / `body_key`) | `push_error("document_opened with invalid/malformed id")`; `_state` unchanged; no InputContext push; no mouse mode write; `Card.visible == false`; player sees no overlay (defensive guard catches engine error before user sees broken card) |
| **Error: missing translation key** (graceful) | `_current_title_key` or `_current_body_key` not in CSV when `tr()` called at C.4 step 6 | `tr("doc.missing_key_xyz")` returns the key string verbatim (graceful fallback per Localization E.10); `TitleLabel.text == "doc.missing_key_xyz"`; **no Overlay-side crash or push_error** — player sees the key as text rather than a broken card. CSV gap is caught by Localization Scaffold pseudolocalization smoke (H.16) |
| **Locale change while READING** | `NOTIFICATION_TRANSLATION_CHANGED` fires while `_state == READING` | `TitleLabel.text = tr(_current_title_key)` (new locale); `BodyText.text = tr(_current_body_key)` (new locale; `text =` reassignment is idempotent re-render); scroll position resets to top; assertive AT re-announce fires on debounced trailing edge (300 ms debounce per C.8) |
| **Locale change while NOT READING** (defensive) | `NOTIFICATION_TRANSLATION_CHANGED` fires while `_state ∈ {IDLE, OPENING, CLOSING}` | Handler returns early; labels unchanged. (No effect; cached keys await next open.) |
| **Reduced-motion** | `accessibility.reduced_motion_enabled == true` at `_on_document_opened` time | C.4 step 5 calls `PostProcessStack.enable_sepia_dim(0.0)` instead of default 0.5 s — sepia engages instant. Card already instant. Audio duck NOT suppressed. (Per OQ-DOV-COORD-2 — pending PPS GDD amendment to expose duration override.) |
| **High text scale (system-level)** | `text_scale_multiplier` from Settings at section-load time = 1.5× or 2.0× | All `FontRegistry.document_*()` font sizes scale at section-load; persists across Overlay session. 16 px body → 24 px at 1.5×; 32 px at 2.0×. Card height may need to grow if body cannot fit (post-VS enhancement; at VS, scroll absorbs the overflow). Per OQ-DOV-COORD-12 / SC 1.4.4 |
| **Pseudolocalization smoke** (test variant only) | Pseudolocale enabled in dev build; 140% expansion + glyph torture | All translated strings render at expanded width; truncation behaviors verified; no clipping. Required before VS milestone close per H.16 |

---

## Interaction Map

Mapping interactions for: **Keyboard/Mouse (primary) + Gamepad (Partial parity per `technical-preferences.md`)** — gamepad rebinding is post-MVP per `technical-preferences.md`. KB+M is the primary input; gamepad parity is committed for in-overlay actions (dismiss + scroll); rebinding parity is post-MVP.

### Modal interactions (consumed by Overlay's `_unhandled_input`)

| Player Action | Input (KB+M) | Input (Gamepad) | Immediate Feedback | Outcome |
|---|---|---|---|---|
| **Dismiss the document** | `Esc` (action: `ui_cancel`) | `B` / `Circle` (action: `ui_cancel`) | (1) `set_input_as_handled()` consumes the event silently; (2) Card snaps to invisible (Option B — no fade); (3) PPS sepia begins 0.5 s ease_in_out fade-out; (4) HUD reappears via own InputContext gate; (5) Audio's own `document_closed` subscription unducks music + ambient | `_state` transitions to CLOSING then IDLE on `document_closed` callback. Player returns to gameplay with full mouse capture restored. |
| **Tab cycle (consumed)** | `Tab` (action: `ui_focus_next`) | n/a (gamepad has no Tab equivalent in Overlay) | Event consumed silently; **focus does NOT move**; OPTIONAL post-VS: polite AT announce "Document — use arrow keys to scroll, Escape to close" | No state change. Per CR-16 — prevents focus escape from modal subtree (FP-OV-9 forbids any second focusable Control). |
| **Shift+Tab cycle (consumed)** | `Shift+Tab` (action: `ui_focus_prev`) | n/a | Same as Tab — consumed silently; no focus move | No state change. CR-16. |

### Body scroll interactions (consumed by `BodyScrollContainer` natively + manual gamepad branch)

| Player Action | Input (KB+M) | Input (Gamepad) | Immediate Feedback | Outcome |
|---|---|---|---|---|
| **Scroll body down (1 line)** | Mouse wheel down OR `↓` arrow (action: `ui_down`) | `D-pad ↓` (mapped to `ui_down`) | Body scrolls ~28 px (1 line-height); scroll thumb advances proportionally on right edge | Permanent (until dismissed or scrolled back) |
| **Scroll body up (1 line)** | Mouse wheel up OR `↑` arrow (action: `ui_up`) | `D-pad ↑` (mapped to `ui_up`) | Body scrolls ~28 px up; thumb retreats | Permanent (until dismissed or scrolled forward) |
| **Page down (1 page minus 1 line)** | `Page Down` (action: `ui_page_down`) | n/a (no gamepad action mapped at MVP) | Body scrolls by `viewport_h − line_height` (preserves 1 line of context) | Permanent |
| **Page up (1 page minus 1 line)** | `Page Up` (action: `ui_page_up`) | n/a | Body scrolls 1 page up with 1-line context overlap | Permanent |
| **Jump to top** | `Home` | n/a (no gamepad mapping at MVP) | `BodyScrollContainer.scroll_vertical = 0` | Permanent |
| **Jump to bottom** | `End` | n/a | `scroll_vertical = max_scroll` | Permanent |
| **Analog scroll (continuous)** | n/a | **Right stick Y-axis** (raw axis or `ui_scroll_up`/`ui_scroll_down` actions) | Per-frame: `scroll_vertical += int(magnitude × right_stick_scroll_max_step_px_per_frame)` after dead-zone reject + clamp. Dead-zone `right_stick_scroll_deadzone = 0.15` rejects sub-threshold drift (the *paper should be still when the player is still*); max step 18 px/frame clamped | Per-frame continuous scroll while held |

### Forbidden interactions (explicit prohibition list per CR-10 + V.5)

| Player Action | Input | Why Forbidden | Pattern ID |
|---|---|---|---|
| Click outside card to dismiss | Mouse click on backdrop | `MOUSE_FILTER_STOP` on root absorbs clicks; only `ui_cancel` dismisses | CR-6 + CR-10 |
| Confirm via focused button | `Enter` / `A` / `Space` | No focused Button widget exists (FP-OV-9); `ui_accept` does nothing during DOCUMENT_OVERLAY | FP-OV-9 |
| Zoom or pan the card | Pinch / scroll-while-modifier / WASD on card | No post-render transform on card | FP-OV-3 |
| Auto-dismiss after timer | (no input — passive) | No Timer / Tween closes the card without explicit `ui_cancel` (except CR-12 section-unload) | FP-OV-2 |
| Swipe to next document | Touch / gamepad-left-stick-X | No "next document" verb; CR-3 single-document invariant; touch not supported per `technical-preferences.md` | FP-OV-13 + platform |
| Click inline glossary terms | Mouse click on body text | No `[url=...]` BBCode in body; mouse wheel passes through `BodyText` (`MOUSE_FILTER_PASS`) | FP-OV-13 |
| Open Pause Menu while reading | `Esc` from gameplay | `ui_cancel` consumed by Overlay first; player must dismiss Overlay then press Esc again | CR-10 |
| Open inventory / gadget menu | `Tab` / `I` / `Y` | InputContext blocks Inventory inputs during DOCUMENT_OVERLAY | CR-10 |
| Resize font in-overlay | Pinch / `+`/`−` keys / slider | No in-overlay font controls; system-level `text_scale_multiplier` from Settings is the only path (OQ-DOV-COORD-12) | G.5 absolute #10 + CR-10 |

### Same-frame double-press protection (the "rapid `Esc`" case)

If the player presses `Esc` twice in the same frame while READING:

- First press: consumed by Overlay; C.5 lifecycle begins; `set_input_as_handled()` called; `_state = CLOSING`.
- Second press: `_unhandled_input` early-returns because `InputContext.is_active(DOCUMENT_OVERLAY)` returns `false` after the pop in step 3 → not consumed. The second press propagates to whatever is now the active modal.
- **In practice**: the second press reaches gameplay's `_unhandled_input`, which has no `ui_cancel` consumer at top level → no-op. The **next frame**, if the player presses `Esc` again, it correctly opens Pause Menu (Pause is now the consumer for the GAMEPLAY context).

This is the **sequential-not-nested** behavior CR-10 specifies. Reading and pausing are deliberately serialized.

### Mouse-mode contract (Input GDD CR-8)

- On open (C.4 step 2 + 4): save `_prev_mouse_mode = Input.mouse_mode` (typically CAPTURED in gameplay), then set `Input.mouse_mode = MOUSE_MODE_VISIBLE` so the player can see the cursor + use mouse wheel for scroll.
- On close (C.5 step 2): restore `Input.mouse_mode = _prev_mouse_mode` (typically CAPTURED) **before** popping InputContext. Net change for normal gameplay → modal → gameplay flow = none.
- Edge case (E.13): if a prior modal had already set mouse mode VISIBLE (e.g., a hypothetical inspect-prop modal), `_prev_mouse_mode == VISIBLE`; open + close runs and mode stays VISIBLE throughout; net change = none.

### Held-input flush on mount

If the player is holding a gameplay action key when `interact` triggers pickup (e.g., player is moving forward + presses `interact` to grab a document on a table), the held movement key does NOT continue to drive movement during reading because `InputContext.DOCUMENT_OVERLAY` blocks `player_*` actions. On dismiss, the held-key resume rule from Input GDD §Edge Case L184 applies — held keys re-engage gameplay actions if still held.

---

## Events Fired

### Direct events fired by the Overlay

The Overlay fires **ZERO domain signals**. Per CR-1 + ADR-0002, Document Collection is sole publisher; the Overlay is subscriber-only. Any direct emission from the Overlay scene tree of `document_opened`, `document_closed`, or `document_collected` is FP-OV-1 violation, caught by CI lint `tools/ci/check_forbidden_patterns_overlay.sh` per AC-DOV-3.1.

### Events the Overlay subscribes to (consumes, does not publish)

| Event | Emitter | Handler | When |
|---|---|---|---|
| `Events.document_opened(id: StringName)` | Document Collection (sole publisher) | `_on_document_opened` runs C.4 8-step lifecycle | Player pressed `interact` near a document prop; DC's `_on_player_interacted` called `DC.collect()` then `DC.open_document(id)` in same frame |
| `Events.document_closed(id: StringName)` | Document Collection (sole publisher) | `_on_document_closed` finalizes CLOSING → IDLE | Overlay's C.5 step 6 called `DC.close_document()`; DC emits the signal back synchronously (per OQ-DOV-COORD-8 confirmation pending) |
| `NOTIFICATION_TRANSLATION_CHANGED` | Engine (locale change) | `_notification(what)` re-resolves `tr()` if `_state == READING`; debounced 300 ms | Player changed locale via Settings → `TranslationServer` reloaded → engine notifies all nodes |
| `section_unloading(section_id: StringName)` (NEW signal pending OQ-DOV-COORD-3 BLOCKING) | Mission & Level Scripting | `_on_section_unloading` runs C.5 synchronously if `_state == READING` AND id matches | MLS is about to unload the section the Overlay belongs to; Overlay must close BEFORE DC's `_exit_tree` |

### Audio cues fired (NOT owned by Overlay — listed for completeness)

Per FP-OV-7 + AFP-OV-1, the Overlay does NOT call any audio API. Audio's own subscriptions to `document_opened` / `document_closed` produce these cues:

| Cue | Bus | Trigger | Owner |
|---|---|---|---|
| Music duck to `document_overlay_music_db = -10 dB` | Music | Audio subscribes `document_opened` | `audio.md` §Tuning Knobs L446 |
| Ambient suppression to `document_overlay_ambient_db = -20 dB` | Ambient | Audio subscribes `document_opened` | `audio.md` §Tuning Knobs L447 |
| Optional paper-rustle SFX on open / pen-cap-tock SFX on close (per ADR-0004 §Risks) | UI/Foley | Audio subscribes `document_opened` / `document_closed` | `audio.md` (asset paths owned there, NOT here) |
| Music + ambient unduck (return to gameplay levels) | Music + Ambient | Audio subscribes `document_closed` | `audio.md` |

**Reduced-motion audio behavior**: cues are NOT suppressed (Audio's reduced-motion rule preserves spatial-awareness cues). Deliberate cross-system asymmetry: visual transitions respect reduced-motion; audio cues do not.

### Cross-cut events fired by other systems during read

Listed for awareness — NOT owned by Overlay:

| System | Action | Why during overlay |
|---|---|---|
| **Stealth AI / Civilian AI** | Continue ticking (alert state changes, patrol movement) | The world doesn't actually freeze (Pillar 3); sepia is dramaturgical, not literal |
| **Combat & Damage** | May fire `player_damaged` if AI engages Eve while reading | Combat runs but combat *input* is blocked by InputContext; Eve cannot fight back during read; damage applies |
| **Failure & Respawn** | Cannot trigger death during read (combat input blocked → no take-damage cascade reaching death threshold WITHOUT prior aggro) | InputContext blocks combat; AI can damage but Eve cannot defend; if HP reaches 0, F&R takes over |
| **HUD Core** | Hides itself via own InputContext gate | HUD CR pending OQ-HUD-3 — verifies HUD reads `InputContext.current() != GAMEPLAY` |
| **Subtitle System** | Suppresses ambient VO via own subscription | ADR-0004 §IG5; Subtitle subscribes `document_opened`/`document_closed` directly |
| **Mission & Level Scripting** | Continues running scripted events (NPC dialogue, patrol triggers) | Reading does not pause MLS scripts; scripted events fire and may complete during read |

### Persistent-state-modifying actions

**FLAG — architecture team attention:** None. The Overlay does NOT modify save state. `_open_document_id` is NOT persisted (per DC §E.12 confirmed); on load-from-save no document is open by design. The `document_collected` set IS persisted (DC owns), but that signal fires at pickup, BEFORE the Overlay mounts — the Overlay is purely ephemeral.

### Telemetry / analytics events

Listed as forward-deps for Analytics (system to be authored — not in this spec, but flagged for Option A-delayed trip-condition instrumentation):

| Event | Payload | Why |
|---|---|---|
| `analytics.document_opened` | `{document_id, time_since_pickup_ms}` | Trip condition for Option A-delayed: ≥50% dismissals < 1 s after open with body unread |
| `analytics.document_dismissed` | `{document_id, time_open_ms, scroll_max_fraction_reached, body_word_count}` | Body-unread detection (scroll_max_fraction_reached < 0.10 + time_open_ms < 1000 + body_word_count > 50 → "dismissed without reading") |
| `analytics.document_player_died_during_read` | `{document_id, time_since_open_ms, section_id}` | Trip condition for Option A-delayed: ≥30% deaths within 5 s of pickup |
| `analytics.locale_changed_during_read` | `{document_id, prev_locale, new_locale, scroll_position_lost}` | Validates CR-8 trade-off (RTL-correctness vs LTR-scroll-loss); informs whether to ship relative-position-preservation post-VS |

These events are **NOT owned by this spec**; they are listed as forward-dep flags for the Analytics GDD (when authored).

---

## Transitions & Animations

### Screen-enter (Overlay open)

**Trigger**: `Events.document_opened(id)` received in IDLE → C.4 8-step lifecycle.

**Visual choreography** (per V.4):

| Frame (60 fps) | Sepia (CanvasLayer 4) | Card (CanvasLayer 5) | HUD (own gate) | Audio (own subscription) |
|---|---|---|---|---|
| Frame 0 | Tween starts (0% → 100% over 30 frames; ease_in_out) | **Snap to `visible = true`** at full opacity, full saturation, full size — no fade-in animation | `InputContext.current() != GAMEPLAY` → HUD hides (HUD's own gate) | Music duck Tween starts (Audio's subscription); ambient suppression begins |
| Frame 5–10 | ~30% sepia engaged | Card stable; player can read at frame 0 (fade does NOT gate reading) | HUD hidden | Music down ~−5 dB |
| Frame 30 | Sepia fully engaged (30% lum, 25% sat, warm tint) | Card stable | HUD hidden | Music at −10 dB; ambient at −20 dB |

**Player perception**: card snaps into position against a still-full-saturation world at frame 0; sepia fades in *around* the still card. The card never moves; only the world's color recedes. This is the **Lectern Pause cue** — the dramaturgical equivalent of a stage darkening around a downstage spotlight.

**Why instant card, not fade-in card**: per ux-designer recommendation in GDD C.4 step 7 — "the card snapping into position against a still-full-saturation world at frame 0 is correct." Pillar 5 + Lectern Pause refusal "Not cinematic." A fade-in card would look like a modern UI popup; the snap-in matches the period-correct register of a pulled document held up to read.

**Reduced-motion variant**: sepia engages instantly (0 s fade). Card already instant. Audio NOT suppressed (per A.2 reduced-motion rule).

### Screen-exit (Overlay close)

**Trigger**: `_unhandled_input` consumed `ui_cancel` in READING → C.5 6-step lifecycle.

**Visual choreography**:

| Frame (60 fps) | Sepia | Card | HUD | Audio |
|---|---|---|---|---|
| Frame 0 | Tween starts (100% → 0% over 30 frames; ease_in_out) | **Synchronous snap to invisible** + text cleared (Option B "snappy dismiss") | `InputContext.current() == GAMEPLAY` → HUD reappears | Music unduck Tween starts |
| Frame 5–10 | ~70% sepia | Card invisible | HUD visible | Music up ~−5 dB |
| Frame 30 | Sepia fully off; world full saturation | Card invisible | HUD fully visible | Music + ambient at gameplay levels |

**Player perception**: the card disappears immediately on Esc/B; the world's color fades back in around where the card was; the operative "puts the document away briskly." Option B is deliberate per CR-5 — no lingering paper during fade.

**Reduced-motion exit variant**: sepia disengages instantly (0 s fade-out). Card already instant. Same outcome, no transition time.

### In-screen state-change animations

| State Change | Animation | Duration | Reduced-Motion |
|---|---|---|---|
| Locale change re-resolve (READING) | `TitleLabel.text` and `BodyText.text` reassigned in same frame; scroll resets to top; AccessKit assertive re-announce on debounced trailing edge (300 ms) | Instant text swap; 300 ms debounce window | No transition; instant respect |
| Scroll (mouse wheel / arrow / gamepad analog) | `BodyScrollContainer.scroll_vertical` advances/retreats; **no smooth-scroll inertia** (FP-OV-12); 4 px scrollbar thumb proportionally tracks | Instant per-input | Identical (no inertia regardless) |
| ScrollHintLabel visibility toggle on overflow detection | `visible = (max_scroll > 0)`; deferred 1 frame after `_ready` for layout settle | Instant | Identical |
| Section-unload close (defensive) | C.5 synchronous; sepia fade-out **may be skipped** if PPS being torn down by section unload | Instant | Identical |
| OPENING-state teardown branch (E.7 / E.19 — section unload mid-open) | Pop InputContext + restore mouse mode + `disable_sepia_dim()` + hide card + `_state = IDLE` (without `DC.close_document()` since DC may already be `_exit_tree`-ing) | Instant | Identical |

### Critical-state animations

**None on the Overlay itself.** No "low-time-remaining" pulse, no "dismiss-warning" flash, no critical-state escalation. The Overlay is a **calm read surface**; no in-card UI element ever animates beyond the scrollbar thumb tracking position. (V.5 forbids cursor blink, page-flip, slide-in, fly-in, scale-up, typewriter character-reveal animations.)

### Stamp-slam animation (Case File register only — explicitly NOT applied here)

The Case File modals (`quit-confirm.md`, `save-failed-dialog.md` Abandon path) use a "stamp slam" SFX + visual on destructive confirms. **Document Overlay does NOT use this animation**. The Overlay has no destructive action; dismiss is non-destructive (reading state is ephemeral; collected set persists regardless).

### Motion-sickness audit

| Animation | Risk | Mitigation |
|---|---|---|
| Sepia 0.5 s ease_in_out fade-in | Low — color shift only; no parallax, no camera move, no rotation | Reduced-motion replaces with instant (per OQ-DOV-COORD-2); 0.5 s is Coleman-and-Braun-compliant duration |
| Sepia 0.5 s ease_in_out fade-out | Low — same as fade-in | Same mitigation |
| Card snap-in / snap-out | Zero — card does not animate; instantaneous on/off | None needed |
| Scroll | Zero — no inertia (FP-OV-12 forbids `smooth_scroll_enabled = true`); user-driven only | None needed |
| AccessKit assertive announce | Zero — text-to-speech, not visual | None needed |

**No vestibular risk.** No camera shake, no parallax, no rotational motion, no flashing, no rapid color cycling. The sepia fade is a slow uniform luminance shift over 0.5 s (~12% per 100 ms); well within Harding FPA bounds.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| `document.title_key` (StringName) | Document Collection (#17) — `Document` Resource schema | Read | Cached at C.4 step 1 as `_current_title_key`; never resolved at cache time (Localization CR-9 + CR-7); resolved via `tr()` only at C.4 step 6 + C.7 re-resolve |
| `document.body_key` (StringName) | Document Collection (#17) — `Document` Resource schema | Read | Same as title_key — cached as key only, never as resolved value |
| `tr(_current_title_key)` resolved value | Localization Scaffold (#7) — `translations/doc.csv` (content owned by Writer) | Read | Resolved at C.4 step 6 + on `NOTIFICATION_TRANSLATION_CHANGED` while READING. Locale-aware. |
| `tr(_current_body_key)` resolved value | Localization Scaffold (#7) — `translations/doc.csv` | Read | Same as title resolution. May contain BBCode formatting (pending Gate G — see OQ list); body word-count ceiling 250 EN words / 375 DE words rendered per OQ-DOV-COORD-4 |
| `tr("overlay.dismiss_hint")` | Localization Scaffold (#7) — `translations/overlay.csv` (NEW file owned by this spec per OQ-DOV-COORD-5) | Read | Static at scene `_ready`; never re-resolved per-document. Engine handles re-translation via `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` |
| `tr("overlay.scroll_hint")` | Localization Scaffold (#7) — `translations/overlay.csv` | Read | Same as dismiss_hint; visibility toggled by overflow detection |
| `tr("overlay.accessibility.dialog_name")` | Localization Scaffold (#7) — `translations/overlay.csv` | Read | AccessKit modal dialog announce name; read on every overlay open |
| `tr("overlay.accessibility.scroll_name")` | Localization Scaffold (#7) — `translations/overlay.csv` | Read | AccessKit scroll-region announce name; fires on overflow |
| `accessibility.reduced_motion_enabled` (bool) | Settings & Accessibility (#23) — `SettingsService.get_value(...)` | Read | At C.4 step 5 to choose between `enable_sepia_dim()` (default 0.5 s fade) and `enable_sepia_dim(0.0)` (instant) |
| `accessibility.text_scale_multiplier` (float, [1.0, 2.0]) | Settings & Accessibility (#23) — pending OQ-DOV-COORD-12 | Read | At section-load time; applied to FontRegistry.document_*() font sizes; persists across overlay session. WCAG 2.1 SC 1.4.4 |
| `accessibility.tts_body_reading_enabled` (bool, default false; post-VS) | Settings & Accessibility (#23) — future addition | Read | Post-VS opt-in for `DisplayServer.tts_speak()` synthesized TTS of body content. NOT in this VS spec. |
| `Input.mouse_mode` (current value) | Engine — `Input` singleton | Read at C.4 step 2 (save); Write at C.4 step 4 (set VISIBLE) and C.5 step 2 (restore) | Per Input CR-8 push/pop discipline |
| `InputContext.current()` (enum) | InputContext autoload (ADR-0004) | Read at `_unhandled_input` to gate dismiss handler | Push/pop owned by C.4 step 3 + C.5 step 3 |
| `right_stick_scroll_deadzone` (float, default 0.15) | This GDD §G.1 — Overlay-owned tunable | Read at gamepad analog scroll branch in `_unhandled_input` | Rejects sub-threshold drift |
| `right_stick_scroll_max_step_px_per_frame` (int, default 18) | This GDD §G.1 — Overlay-owned tunable | Read at gamepad analog scroll branch | Clamps per-frame scroll velocity |
| `document_auto_open_delay_s` (float, default 0.0) | This GDD §G.1 — Overlay-owned tunable | Read by Document Collection (NOT by Overlay) | Per CR-2-bis Option A-delayed fallback |

### Architectural concerns

The Overlay does NOT own or manage game state. All state is read-only consumption. No write paths to save data, economy, progression, or persistent player profile. **No concerns flagged for architecture team.**

### Forbidden data reads

Per FP-OV-15 (`overlay_subscribes_gameplay_events`), the Overlay must NOT subscribe to:

- `Events.player_damaged` / `Events.player_died`
- `Events.alert_state_changed` / any Stealth AI signal
- `Events.enemy_killed` / `Events.combat_*`
- `Events.section_entered` (subscribe to `section_unloading` only, per OQ-DOV-COORD-3)
- Any Analytics-emitting signal (Analytics is a forward-dep; Overlay does not consume telemetry)

Enforced via CI grep `tools/ci/check_forbidden_patterns_overlay.sh`.

---

## Accessibility

This spec satisfies the **Standard tier** committed in `design/accessibility-requirements.md` and partially exceeds it (AccessKit menu + dialog support overlaps with Comprehensive-tier menu screen reader). Per-feature mapping:

### Keyboard-only navigation

- **Open**: triggered by gameplay `interact` (rebindable per Settings); not a menu navigation path
- **Read**: arrow keys (`↑` / `↓`) scroll body 1 line per press; `Page Up` / `Page Down` scroll 1 page minus 1 line; `Home` / `End` jump to top / bottom
- **Dismiss**: `Esc` (rebindable as `ui_cancel`) — single press, single action, no modifier required
- **Tab/Shift+Tab consumed and absorbed** (CR-16) — prevents focus escape from modal subtree (the only legal focused control inside the Overlay is `BodyScrollContainer` for keyboard scroll; there is no second focusable interactive node since FP-OV-9 forbids a Close Button)

### Gamepad navigation (Partial parity per `technical-preferences.md`)

- **Open**: `interact` button (typically `A` / `Cross`; rebindable post-MVP per Settings)
- **Read**: D-pad `↑` / `↓` for line scroll (mapped to `ui_up` / `ui_down`); right stick Y-axis for analog scroll (manual handler in `_unhandled_input` per CR-9 + Gate F; dead-zone 0.15)
- **Dismiss**: `B` / `Circle` (mapped to `ui_cancel`) — single press
- **No Tab equivalent on gamepad**; `Y` / `Triangle` and other face buttons are reserved for gameplay actions blocked by InputContext during DOCUMENT_OVERLAY

### AccessKit per-widget table

(Per GDD §C.8 — pseudocode pending Gate A verification; final property names may differ in Godot 4.6 actual API: likely `accessibility_description` instead of `accessibility_name`; `accessibility_role` may be inferred from node type rather than settable as a string property.)

| Node | `accessibility_role` | `accessibility_name` source | Notes |
|---|---|---|---|
| `ModalBackdrop` | `dialog` | `tr("overlay.accessibility.dialog_name")` → "Document" | Modal-dialog role; AT treats focus as trapped inside until dismissed |
| `TitleLabel` | `heading` (level 1 if available; else `label` with explicit `accessibility_name`) | `TitleLabel.text` (the resolved title) | First focus-announce target on open (C.4 step 7b) |
| `BodyText` | `text` / `document` | `BodyText.text` (full body content; **pending Gate G** — must be parsed plain text, NOT raw BBCode source) | AT reads full body content; if Gate G fails, parallel BBCode-stripped plain-text property required |
| `BodyScrollContainer` | `scroll_area` (or `scrollbar` container equivalent) | `tr("overlay.accessibility.scroll_name")` → "Document body" | AT announces as scrollable when content overflows |
| `DismissHintLabel` | `static_text` | `DismissHintLabel.text` | Low-priority static announcement; NOT in initial open-announce sequence |
| `ScrollHintLabel` | `static_text` | `ScrollHintLabel.text` (when visible) | Same priority as dismiss hint; conditional |

### Open-announce sequence

Per GDD §C.8 (revised 2026-04-27 per accessibility-specialist):

1. **C.4 step 7b** moves keyboard focus to `TitleLabel` via `grab_focus()`. AT (NVDA / Orca) reads the focused element automatically — `TitleLabel`'s `heading` role triggers a "heading level 1: [title]" announcement natively.
2. **C.4 step 8** sets `ModalBackdrop.accessibility_live = "assertive"` for ONE frame to announce the dialog-role context: "Document." — the modal-context cue, not a content dump.
3. The body is reachable via subsequent focus navigation: arrow keys scroll the body within the focused `TitleLabel` → `BodyScrollContainer` flow (per Godot 4.6 ScrollContainer focus chain). AT users either read the body via screen-reader virtual buffer (mode-dependent) OR via explicit `BodyText` focus on Tab — but Tab is consumed by CR-16, so the virtual-buffer / arrow-key-through-content path is the primary mechanism.

Implementation: focus + assertive together. `call_deferred` to set assertive back to `"off"` next frame (or two-deep deferral if Gate A reveals AT flush happens BEFORE deferred callbacks within the same frame).

### Locale-change announce

C.7 + debounce: re-grab_focus on TitleLabel (fires fresh focus event) and dialog-role assertive. **Debounce 300 ms**: if `NOTIFICATION_TRANSLATION_CHANGED` fires multiple times within 300 ms, the assertive re-announce fires only once at the trailing edge. Suppresses mid-sentence assertive interruption of AT readout.

### Close announce

**Silent.** AT context returns to gameplay. No close announcement.

### Visual accessibility

- **Text contrast**: Parchment `#F2E8C8` body field with Ink Black `#1A1A1A` text → contrast ratio ~13.5:1 (WCAG AAA for body text). BQA Blue `#1B3A6B` header with Parchment text → contrast ratio ~7.2:1 (WCAG AAA). Audited via `tools/ci/contrast_check.sh` (TBD per `accessibility-requirements.md`).
- **Color-as-only-indicator**: per `accessibility-requirements.md` row "Document Overlay sepia-dim" — the Lectern Pause register is signaled by **multiple non-color signals**: card animation (paper-translate-in NOT used; card snaps), InputContext push (HUD hides), sepia luminance shift (color-shift but accompanied by luminance change). Color is one of several signals, not the only one.
- **Text scaling**: per OQ-DOV-COORD-12 BLOCKING — `text_scale_multiplier` from Settings (range [1.0, 2.0], default 1.0; safe step 0.25) applies to FontRegistry.document_*() at section-load time. 16 px body → 24 px at 1.5× → 32 px at 2.0×. Card height does NOT grow at VS; scroll absorbs overflow. Required for SC 1.4.4 conformance.
- **No in-overlay font controls** (G.5 absolute #10) — system-level scaling only.

### Photosensitivity

- **No flashing, no rapid color cycling, no high-contrast strobe.** Sepia fade is a slow uniform luminance shift over 0.5 s (~12% per 100 ms). Well within Harding FPA bounds.
- **No typewriter character-reveal animation** (FP-OV-14 — explicit prohibition partly grounded in photosensitivity floor).

### Reduced-motion

- `accessibility.reduced_motion_enabled == true`: sepia fade duration → 0 s (instant engage / instant disengage); card already instant
- Audio duck NOT suppressed (per A.2 — Audio's reduced-motion rule preserves spatial-awareness cues)
- Scroll never has inertia (FP-OV-12 forbids `smooth_scroll_enabled = true` regardless of setting)

### Screen-reader walkthrough (manual verification path)

For **Linux Orca / Windows Narrator** verification (per `accessibility-requirements.md` test plan row "AccessKit screen reader (menu + HUD + Cutscenes)" — adds Document Overlay to the verification scope):

1. Launch game with screen reader enabled
2. Begin Plaza section
3. Walk to first document prop (HUD prompt-strip should announce "INTERACT — F" — covered by HUD Core spec)
4. Press `interact`
5. Verify: AT announces "Document. heading level 1, [title text]." within 1 second of mount
6. Press `↓` arrow key
7. Verify: body scrolls 1 line; AT may announce changed visible text (mode-dependent)
8. Press `Tab`
9. Verify: focus does NOT change; OPTIONAL polite announce "Document — use arrow keys to scroll, Escape to close" (post-VS enhancement)
10. Press `Esc`
11. Verify: card disappears; AT context returns to gameplay (no close announcement)

### Accessibility carve-outs

**None required.** The Overlay's design is fully compatible with Standard-tier accessibility commitments. Pillar 5 (Period Authenticity) absolutes are aligned with accessibility floor — no Stage-Manager carve-out needed. The one borderline — recorded VO is forbidden — has the synthesized-platform-TTS opt-in (`DisplayServer.tts_speak()` per G.5 absolute #8 narrowing; Settings-gated, default false; post-VS) as the assistive-tech bypass. AccessKit reading the body text directly is the VS-default accessibility path.

---

## Localization Considerations

### Strings owned by this spec (NEW — to be added to `translations/overlay.csv`)

Per OQ-DOV-COORD-5 BLOCKING — 4 keys in NEW file `translations/overlay.csv` (NOT `translations/doc.csv` which is content owned by Writer):

| Key | English value | Max chars | `# context` cell (translator brief) |
|---|---|---|---|
| `overlay.dismiss_hint` | "ESC / B — Return to Operation" | 55 (raised from 40 per localization-lead 2026-04-27 to fit German 1.5× expansion of "Operation" + glyph tokens) | Footer hint shown at bottom of every document card. Period dossier register; do NOT punch up. The "ESC" and "B" tokens are **literal device-label strings** (not translated); some locales may need to reorder them around the em-dash. Translator must preserve token positions or use a culturally-equivalent device-label convention. Pseudolocalization smoke-test required at 140% before VS milestone close (H.16). |
| `overlay.scroll_hint` | "SCROLL — ↑ ↓ / Right Stick" | 50 | NEW key per ux-designer 2026-04-27 BLOCKING finding (scroll-discoverability gap). Footer hint shown ONLY when body overflows card height (`SCROLL_MODE_AUTO` triggers visibility). Period register; arrow glyphs are literal Unicode (U+2191, U+2193). "Right Stick" refers to the gamepad right thumbstick — translate as the locale's standard term for this controller affordance. |
| `overlay.accessibility.dialog_name` | "Document" | 20 | AccessKit modal dialog announce name. Read on every overlay open before title + body. Translator: keep terse, single noun. |
| `overlay.accessibility.scroll_name` | "Document body" | 25 | AccessKit scroll-region announce name. Fired when body overflows + scroll is engaged. |

### Strings consumed but NOT owned (content owned by Writer)

| Key namespace | Source | Notes |
|---|---|---|
| `doc.<id>.title` | `translations/doc.csv` (Writer + Localization Scaffold) | Title text per document; up to 21 documents at full collection per DC §A. Title MUST ellipsis-truncate at card column edge — no wrap. |
| `doc.<id>.body` | `translations/doc.csv` (Writer + Localization Scaffold) | Body content per document; bbcode_enabled (pending Gate G — if BBCode is not safely exposed to AccessKit, body must be BBCode-free). 250 EN words / 375 DE words rendered max per OQ-DOV-COORD-4. |

### Expansion budget

| Element | EN baseline | DE 1.5× ceiling | FR 1.3× expected | Layout-critical? |
|---|---|---|---|---|
| Title | up to ~46 chars (ellipsis after) | up to ~46 chars (ellipsis after — same column constraint) | up to ~46 chars | **YES** — ellipsis truncates; no wrap allowed |
| Body | up to 250 words (~1500 chars) | up to 375 words (~2250 chars) — body grows, scroll absorbs overflow | up to 325 words | NO — scroll absorbs |
| `overlay.dismiss_hint` | 30 chars | 55 chars (within budget) | 40 chars | **YES** — must fit on single 12 px line at card width 800 px min |
| `overlay.scroll_hint` | 28 chars | 50 chars (within budget) | 36 chars | **YES** — same constraint as dismiss_hint |
| `overlay.accessibility.dialog_name` | 8 chars | 20 chars budget | 15 chars | NO — AT-only, never rendered visually |
| `overlay.accessibility.scroll_name` | 13 chars | 25 chars budget | 20 chars | NO — AT-only |

### Layout-critical strings (HIGH PRIORITY for localization-lead)

- **`overlay.dismiss_hint`** — single-line footer constraint at 12 px on 800 px min card width. German 1.5× expansion stress-test required. Pseudolocalization smoke at 140% must verify the line does not clip or wrap.
- **`overlay.scroll_hint`** — same constraint; only visible when overflow detected.
- **Document titles (`doc.<id>.title`)** — ellipsis-truncate at card column edge; if ALL locale variants exceed the column, the truncation register becomes the universal experience (which is period-correct — typed documents had column limits). Acceptable.

### Number / date / currency formatting

**None.** No numeric data, no dates, no currency rendered in the Overlay UI itself. Document body content (`doc.<id>.body`) may contain numbers/dates/currencies as in-world fictional document content (e.g., "Section 3.2(b)(iv)"); these are translator-controlled per Writer brief, not programmatically formatted.

### RTL (right-to-left) language support

Pseudolocale RTL placeholder per `accessibility-requirements.md` colorblind / locale tests. RTL locales (Arabic, Hebrew) are NOT v1.0 commitments; placeholder support means:

- Title `Label.horizontal_alignment` flips with locale direction (engine-default behavior)
- Body `RichTextLabel` autowrap respects locale direction (engine-default)
- Scroll position resets on locale change (CR-8 — RTL-correctness wins; LTR scroll-loss accepted at VS)
- Footer hints — translator may reorder "ESC / B —" tokens around the em-dash for RTL conventions

If RTL locales ship, post-VS verification required: card geometry (header/body/footer order) does NOT need to flip; only text-direction within fields.

### `auto_translate_mode` policy

Per GDD §C.2 scene tree:

| Node | `auto_translate_mode` | Why |
|---|---|---|
| `TitleLabel` | `AUTO_TRANSLATE_MODE_DISABLED` | CR-7 manual handling — Overlay reassigns `text = tr(_current_title_key)` on open + locale change |
| `BodyText` | `AUTO_TRANSLATE_MODE_DISABLED` | Same — manual handling per CR-7 |
| `DismissHintLabel` | `AUTO_TRANSLATE_MODE_ALWAYS` | Static `tr` key set in editor (`overlay.dismiss_hint`); engine handles re-translation on locale change |
| `ScrollHintLabel` | `AUTO_TRANSLATE_MODE_ALWAYS` | Same — engine handles |

### Translator brief inputs (for Writer + Localization-Lead before VS sprint)

- 4 `overlay.*` strings to be added to `translations/overlay.csv` with `# context` cells per OQ-DOV-COORD-5 (table above)
- Pseudolocalization smoke at 140% required before VS milestone close per H.16 — verifies no clipping in title (ellipsis truncation register), dismiss hint, scroll hint
- Body-content word-count ceiling 250 EN / 375 DE rendered per OQ-DOV-COORD-4 — Writer brief amendment
- BBCode policy pending Gate G — if BBCode is not safely exposed to AccessKit, Writer brief must forbid `[b]`, `[i]`, `[color]`, `[url]` in body content (heavy constraint; preferred resolution is parallel BBCode-stripped plain-text property)

### Coord items for localization-lead (before VS sprint)

- **OQ-DOV-COORD-5** (BLOCKING): author 4 keys in `translations/overlay.csv`; amend Localization Scaffold §Interactions ownership table to add `overlay.*` namespace row owned by this GDD
- **H.16 ADVISORY → BLOCKING-eligible**: pseudolocalization smoke at 140% expansion before VS milestone close

---

## Acceptance Criteria

> **Notation**: Acceptance criteria below are the **UX surface slice** of the GDD's full AC list (§H.1–H.16, ~75 ACs). The GDD ACs cover lifecycle / state machine / forbidden patterns / performance gates that are programmer-facing; this UX spec's ACs cover the player-facing experience that QA tests via manual walkthrough or visual verification. UX ACs reference GDD ACs by ID where relevant. All UX ACs are **BLOCKING for VS milestone** unless tagged ADVISORY. Story types: **[UI]** (manual walkthrough), **[Visual]** (screenshot + sign-off), **[Integration]** (multi-system manual test).

### Mount & Default State

- [ ] **AC-UX-DOV-1.1 [UI] BLOCKING** — Card mounts at viewport center within 1 second of `interact` press near a document prop. Card dimensions 960 × 680 px at 1080p; clamps to 800 px min wide at sub-1280 viewports. Header is BQA Blue 64 px; body is Parchment with 32 px T/B + 48 px L/R padding; footer is Parchment 30 px (or 44 px when scroll hint visible). [GDD AC-DOV-1.1 covers logic; this UX AC covers visual mount appearance.]
- [ ] **AC-UX-DOV-1.2 [Visual] BLOCKING** — On mount: TitleLabel renders American Typewriter Bold 20 px Parchment on BQA Blue; BodyText renders American Typewriter Regular 16 px Ink Black on Parchment with line-height ~28 px; DismissHintLabel renders American Typewriter Regular 12 px Ink Black centered. No drop shadow, no rounded corners, no inline icons, no decorative borders. Per V.1 + V.5.
- [ ] **AC-UX-DOV-1.3 [Visual] BLOCKING** — Sepia-dim register engages on the world (NOT on the card) over 0.5 s ease_in_out at default; card is full saturation throughout. Card snaps to visible at frame 0; sepia fades in around it. Per V.4.

### Open-Lifecycle UX

- [ ] **AC-UX-DOV-2.1 [Integration] BLOCKING** — On mount: HUD Core widgets disappear (HUD's own InputContext gate); music ducks audibly (Audio's own subscription); ambient suppression engages; mouse cursor becomes visible; gameplay input stops responding (player movement keys produce no movement). Per CR-11 + Audio §A.1 + CR-10.
- [ ] **AC-UX-DOV-2.2 [UI] BLOCKING (BLOCKED-pending OQ-DOV-COORD-2)** — When `accessibility.reduced_motion_enabled == true`, sepia engages instantly (0 s fade); card behavior unchanged; audio duck still fires (NOT suppressed by reduced-motion). Per V.4 + A.2.

### Read State

- [ ] **AC-UX-DOV-3.1 [UI] BLOCKING** — Body that fits within card height: no scrollbar visible; no scroll hint label visible. Footer is 30 px tall with only DismissHintLabel.
- [ ] **AC-UX-DOV-3.2 [UI] BLOCKING** — Body that overflows card height: 4 px Ink Black scrollbar appears on right edge; ScrollHintLabel ("SCROLL — ↑ ↓ / Right Stick") appears in footer above DismissHintLabel; footer height grows to 44 px. Per CR-9 + GDD §C.2 amendment 2026-04-27.
- [ ] **AC-UX-DOV-3.3 [UI] BLOCKING** — Mouse wheel scrolls body (~3 lines per click, engine default); arrow keys (`↑`/`↓`) scroll 1 line per press; `Page Up`/`Page Down` scroll 1 page minus 1 line; `Home`/`End` jump to top/bottom; gamepad right-stick Y-axis scrolls continuously while held (dead-zone 0.15; max 18 px/frame). No smooth-scroll inertia. Per CR-9 + C.6.
- [ ] **AC-UX-DOV-3.4 [Visual] BLOCKING** — Long titles (longer than column width at 800 px min card) ellipsis-truncate with "…" — no wrap to second line, no hard pixel-clip. Verified via German pseudolocalization at 140% (e.g., "PHANTOM LOGISTIK-MEMORANDUM — BETREFFEND…"). Per V.5 item #17.

### Dismiss

- [ ] **AC-UX-DOV-4.1 [Integration] BLOCKING** — Pressing `Esc` on KB+M dismisses the card immediately (Option B snappy dismiss); PPS sepia fades out over 0.5 s; HUD reappears within ~0.5 s; mouse mode restored to CAPTURED (or whatever gameplay used pre-mount); music + ambient unduck. Player resumes gameplay. Per C.5 + AC-DOV-2.1 / 4.1.
- [ ] **AC-UX-DOV-4.2 [Integration] BLOCKING** — Pressing `B` / `Circle` on gamepad dismisses identically to Esc. Same lifecycle, same fade timing, same final state. Per CR-6 + Gate C.
- [ ] **AC-UX-DOV-4.3 [UI] BLOCKING** — Mouse click outside the card area (on the modal backdrop) does NOT dismiss; only `ui_cancel` action dismisses. Per CR-10 + `MOUSE_FILTER_STOP` on backdrop.
- [ ] **AC-UX-DOV-4.4 [UI] BLOCKING** — No "Close" or "Done" Button is visible anywhere on the card (FP-OV-9 forbids). Confirm via screenshot review of card at all states (default, overflow, error). Per V.5 item #11.
- [ ] **AC-UX-DOV-4.5 [Integration] BLOCKING** — After dismiss, pressing `Esc` again opens Pause Menu (sequential, not nested). Reading and pausing are serialized; the second `Esc` reaches Pause Menu's consumer in the GAMEPLAY context. Per CR-10.

### Locale Change

- [ ] **AC-UX-DOV-5.1 [UI] BLOCKING (Gate E ADVISORY)** — While reading, opening Settings → changing locale → returning: TitleLabel and BodyText re-render in new locale; scroll position resets to top; AccessKit assertive re-announce fires (debounced 300 ms trailing edge). No doubled text; no programmatic-effect carryover. Per CR-7 + CR-8 + AC-DOV-6.2.
- [ ] **AC-UX-DOV-5.2 [Visual] BLOCKING** — German pseudolocalization at 140% expansion: dismiss hint fits within footer (no clip, no wrap); scroll hint fits within footer; title ellipsis-truncates correctly. Per H.16 + UI-3.

### Accessibility (UX-surface — full AT verification per GDD §H.11)

- [ ] **AC-UX-DOV-6.1 [UI] BLOCKING (BLOCKED-pending Gate A + Gate G)** — With Linux Orca / Windows Narrator enabled: opening a document produces "Document. heading level 1, [title]" announcement within 1 s of mount; arrow keys scroll without re-announcing; Tab/Shift+Tab consumed silently (no focus move); Esc dismisses with no close announcement (silent return to gameplay). Per C.8 + CR-16.
- [ ] **AC-UX-DOV-6.2 [UI] BLOCKING (BLOCKED-pending OQ-DOV-COORD-12)** — With `text_scale_multiplier = 2.0` in Settings: body text renders at 32 px; card geometry unchanged at VS (scroll absorbs overflow). All footer hints remain legible at scaled size. Per OQ-DOV-COORD-12 + WCAG 2.1 SC 1.4.4.
- [ ] **AC-UX-DOV-6.3 [Visual] ADVISORY** — Coblis colorblind simulator (Protanopia / Deuteranopia / Tritanopia) on screenshots of card at all states: title remains legible against BQA Blue header; body remains legible against Parchment; scrollbar remains visible. No information loss. Per `accessibility-requirements.md`.

### Reduced-Motion

- [ ] **AC-UX-DOV-7.1 [UI] BLOCKING (BLOCKED-pending OQ-DOV-COORD-2)** — With `accessibility.reduced_motion_enabled == true`: sepia engages instantly on open (no 0.5 s fade); sepia disengages instantly on close (no 0.5 s fade-out). Card snap behavior unchanged. Audio duck still fires (NOT suppressed). Per V.4 + A.2.

### Visual Compliance

- [ ] **AC-UX-DOV-8.1 [Visual] BLOCKING** — Screenshot review at 720p / 1080p / 1440p with worst-case 250-word body / median 200-word body / minimum 50-word body / German pseudolocalization (140%): card renders correctly at all combinations; no clip, no wrap, no missing scrollbar when expected; ellipsis truncation correct on long titles. Per V.6 reference screenshots requirement.
- [ ] **AC-UX-DOV-8.2 [Visual] BLOCKING** — V.5 forbidden visual elements verified absent via screenshot review of card at all states: no inline icons, no decorative borders, no drop shadows, no glow, no page-flip animation, no slide-in entry animation, no typewriter character-reveal, no inline images, no color-coded category labels, no progress bar, no Close Button, no secondary action buttons, no glossary tooltips, no search bar, no tab navigation. Per V.5 (16 forbidden items + 1 NEW required item: ellipsis truncation).

### Cross-Reference (this spec depends on)

- [ ] **AC-UX-DOV-9.1 [Integration] BLOCKING** — `design/ux/hud.md`: HUD Core hides on InputContext push to DOCUMENT_OVERLAY; reappears on pop. Verified by visual confirmation that HUD widgets vanish during overlay open.
- [ ] **AC-UX-DOV-9.2 [Integration] BLOCKING** — `design/ux/pause-menu.md`: Pause Menu does NOT mount during DOCUMENT_OVERLAY; sequential dismiss-then-pause works as designed. Verified by attempting Esc twice: first dismisses overlay, second opens pause.
- [ ] **AC-UX-DOV-9.3 [UI] BLOCKING** — `design/ux/interaction-patterns.md`: NEW Lectern Pause card pattern entry added to Modal & Dialog category (per Cross-Reference Check below). Pattern documents BQA Blue + Parchment + American Typewriter + sepia-dim + no-buttons + ui_cancel-dismiss as a single coherent register distinct from Case File `modal-scaffold`.

### Coverage

- [ ] **AC-UX-DOV-10.1 [Integration] ADVISORY** — Manual end-to-end walkthrough: launch Plaza section, navigate to first document prop, interact, read body, dismiss, verify HUD reappears, verify mouse capture restored, verify gameplay input resumes. Repeat with: KB+M only, gamepad only, screen reader on, reduced-motion on, German locale, 2.0× text scale. All 6 paths must complete cleanly.
- [ ] **AC-UX-DOV-10.2 [UI] ADVISORY** — Pseudolocalization smoke at 140% expansion: verify no string clipping in any visible UI element. Per H.16.

---

## Open Questions

| OQ ID | Question | Owner | Deadline | Status |
|---|---|---|---|---|
| **OQ-UX-DOV-1** ✅ **RESOLVED 2026-04-29 per `/ux-review`** | Should the Lectern Pause card pattern be added to `interaction-patterns.md` as a NEW entry in Modal & Dialog category, or merged into the existing modal-dismiss composite (`unhandled-input-dismiss` + `dual-focus-dismiss` + `set-handled-before-pop`) as a register variant? | ux-designer | Before `/ux-review` | **Resolved**: NEW entry — register is too distinct from Case File `modal-scaffold` to merge as a variant; the BQA Blue + Parchment + American Typewriter + sepia-dim composition is its own pattern. Renamed to slug-style `lectern-pause-card-modal` (Modal & Dialog) and cross-paired with the existing `lectern-pause-register` (HUD & Notification — composite world-state register). Both patterns appended to `interaction-patterns.md` 2026-04-29. Companion pattern `tab-consume-non-focusable-modal` (Input Routing) added in same pass per CR-16. |
| **OQ-UX-DOV-2** | Footer hint glyph swap (post-VS): when input device switches from KB+M to gamepad mid-read, should the dismiss hint dynamically swap "ESC / B" → "B" only? | ux-designer + ui-programmer | Post-VS | Default: NO at VS — static "ESC / B —" hint covers both populations and the dynamic swap is a forward-dep on Settings & Accessibility's input-device detection (post-VS). Locked as static for VS. |
| **OQ-UX-DOV-3** | Should the **Tab consumption polite AT announce** ("Document — use arrow keys to scroll, Escape to close") ship at VS or post-VS? | accessibility-specialist + ui-programmer | Before VS sprint kickoff | Default: post-VS enhancement — VS ships silent Tab consumption (CR-16); polite announce is an ADVISORY enhancement once Gate A confirms `accessibility_live` API surface. |
| **OQ-UX-DOV-4** | If Option A-delayed ships (CR-2-bis fallback), what is the visual signal during the 1.0–2.0 s delay window? Is there a HUD prompt-strip update ("READING IN [N]s") or silent? | ux-designer + game-designer | If/when Option A-delayed activates per playtest trip conditions | Default: silent — the delay is gameplay-blocking-cleared (player can move; sepia not engaged); a HUD prompt would defeat the purpose (player wants invisible breathing room, not a countdown). Locked as silent unless playtest reveals confusion. |
| **OQ-UX-DOV-5** | Should the **scroll position relative-preservation** strategy ship post-VS for LTR-to-LTR locale switches (German→English while reading)? | localization-lead + ux-designer | Post-VS playtest | Default: NO at VS — CR-8 trade-off (RTL-correctness wins; LTR scroll-loss accepted) is acceptable per localization-lead 2026-04-27. Revisit post-VS playtest if FR/DE players report jarring reset. |
| **OQ-UX-DOV-6** | At `text_scale_multiplier = 2.0`, the card may need to grow taller to fit minimum legible body content without scroll. Is the 680 px card height fixed at VS, or does it grow with text scale? | ux-designer + accessibility-specialist | Before VS sprint kickoff | Default: fixed at VS — scroll absorbs overflow; card height is a hard layout constant. Post-VS enhancement: card height grows with `text_scale_multiplier` so 50-word documents fit without scroll at 2.0× scale. |
| **OQ-UX-DOV-7** | The synthesized-platform-TTS opt-in (`tts_body_reading_enabled` per G.5 absolute #8) — is this a Document Overlay UX spec concern, or purely Settings & Accessibility? | accessibility-specialist | Post-VS | Default: Settings & Accessibility owns the toggle + the `DisplayServer.tts_speak()` call site; Overlay's only role is exposing `BodyText.text` (parsed plain text per Gate G) for Settings to read. Not in this spec's authoring scope at VS. |
| **OQ-UX-DOV-8** | Should the `analytics.document_*` event payloads (per Events Fired §) be specified in this spec or deferred to the Analytics GDD when authored? | analytics-engineer | Before VS sprint kickoff | Default: deferred — this spec lists event names + intended payload shape as forward-deps; Analytics GDD owns the schema + transport. Confirm at `/ux-review`. |
| **OQ-UX-DOV-9** | Hover preview / tooltip on body terms (forbidden per FP-OV-13) — is there ANY case where a per-body-term affordance might be acceptable (e.g., a glossary-link to a separate "definitions" pane in a Polish-or-later codex)? | creative-director | Polish-or-later | Default: NO at VS and Polish-or-later codex evaluation — Lectern Pause anchor "Not a codex" is load-bearing. The polished case-file archive (DC §E.12) re-reads collected documents but does NOT add inline links. Anchor test ("Would a 1965 reader accept this?") fails for inline glossary links in any register. |
| **OQ-UX-DOV-10** *(added 2026-04-29 per `/ux-review` advisory #5)* | `Page Up` / `Page Down` / `Home` / `End` scroll shortcuts have no gamepad equivalent at MVP (documented as `n/a` in the Interaction Map). Should they gain gamepad equivalents (e.g., `L1` / `R1` for page; long-press D-pad for top/bottom) before Steam Deck Verified evaluation, or is D-pad line-scroll + right-stick analog sufficient parity at VS? | ux-designer + accessibility-specialist | Post-VS (Steam Deck verification gate) | Default: post-VS — VS ships D-pad line + right-stick analog parity. Long-body documents on gamepad-only will be slower than KB+M but completable; right-stick analog at max 18 px/frame can traverse a full 250-word body in ~2 s of held-stick input. Revisit if Steam Deck playtest reveals long-body fatigue or gamepad-only completion-time outliers. |

---

## Cross-Reference Check Results

**1. GDD requirement coverage**:

- ✅ All UI Requirements from `document-overlay-ui.md` UI-1 through UI-5 covered
- ✅ All V.1 (Card visual register) elements documented in Layout Specification + ASCII Wireframe
- ✅ All V.5 forbidden visual elements verified absent in V.5 list + AC-UX-DOV-8.2
- ✅ AccessKit per-widget table (C.8) reproduced in Accessibility section
- ✅ All 4 localization keys (OQ-DOV-COORD-5) documented in Localization Considerations
- ✅ Reduced-motion path (V.4 + A.2) documented in States & Variants + Transitions

**2. Pattern library alignment**:

- ✅ References existing patterns: `unhandled-input-dismiss` + `dual-focus-dismiss` + `set-handled-before-pop` (Input Routing — composite modal-dismiss contract); `input-context-stack` (Input Routing — push/pop); `lectern-pause-register` (HUD & Notification — composite world-state register; the new `lectern-pause-card-modal` is its card-UI sister pattern, paired and always co-firing).
- ✅ **NEW patterns appended to `interaction-patterns.md` 2026-04-29 (post-`/ux-review`)** — closes OQ-UX-DOV-1:
  - **`lectern-pause-card-modal`** (Modal & Dialog) — Parchment-on-sepia-dim gameplay-time modal *card*; sister pattern to existing `lectern-pause-register` (HUD & Notification composite). Distinct from Case File `modal-scaffold`; no buttons; dismissed only via `ui_cancel`; hosts a `RichTextLabel` body with optional scroll. Single-screen instance (Document Overlay only). When-to-use: "Single-document gameplay-time read with no decision required from player; player needs posture to read, dismiss is the only verb." When-NOT-to-use: "Anything that requires a player decision — use Case File `modal-scaffold` instead."
  - **`tab-consume-non-focusable-modal`** (Input Routing) — when a modal subtree contains zero secondary focusable Controls, `ui_focus_next` and `ui_focus_prev` are consumed and absorbed by the modal root (CR-16) to prevent focus escape.
- 🟡 Scroll grammar (mouse wheel + keyboard + gamepad analog) used by `BodyScrollContainer` is documented as per-screen specification in this spec's Interaction Map; not promoted to a formal pattern entry at VS (single consumer; revisit if future spec needs the same grammar).

**3. Navigation consistency**:

- ✅ HUD Core (companion spec): hides on InputContext push to DOCUMENT_OVERLAY; reappears on pop. Verified at AC-UX-DOV-9.1.
- ✅ Pause Menu (companion spec): never co-occurs; sequential dismiss-then-pause behavior verified at AC-UX-DOV-4.5 + AC-UX-DOV-9.2.
- ✅ No cross-spec conflicts identified.

**4. Accessibility coverage**:

- ✅ Standard tier per `accessibility-requirements.md` row "20. Document Overlay UI" — Designed; addressed
- ✅ AccessKit dialog role + heading + scroll_area documented (pending Gate A)
- ✅ Reduced-motion path documented (pending OQ-DOV-COORD-2)
- ✅ Text scaling documented (pending OQ-DOV-COORD-12)
- ✅ Pseudolocalization smoke flagged (H.16)
- 🟡 **3 BLOCKED-pending dependencies** (Gate A, Gate E, Gate G) tracked in Open Questions and AC notes

**5. Empty states**:

- ✅ IDLE state documented (no card visible; default)
- ✅ Error: invalid document id documented (push_error; defensive guard)
- ✅ Error: missing translation key documented (graceful fallback per Localization E.10)
- ✅ Section-unload mid-read documented (defensive close)

---

## Recommended Next Steps

- Run `/ux-review design/ux/document-overlay.md` to validate this spec before it enters the implementation pipeline.
- Update `design/ux/interaction-patterns.md` to add the **Lectern Pause card** pattern (Modal & Dialog category) and **Tab consumption for non-focusable modals** pattern (Input Routing category) before VS sprint kickoff.
- Coordinate with localization-lead to author the 4 `overlay.*` strings in `translations/overlay.csv` (NEW file) per OQ-DOV-COORD-5 BLOCKING.
- Track Gate A (AccessKit API), Gate E (RichTextLabel idempotent re-render), Gate G (BBCode plain-text exposure to AccessKit) in `docs/architecture/adr-0004-ui-framework.md` verification log.
- Once `/ux-review` returns APPROVED, this spec joins the VS sprint backlog as part of the Document Overlay UI epic (per `production/sprints/` planning).
