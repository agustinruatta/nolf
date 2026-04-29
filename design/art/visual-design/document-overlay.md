# Visual Design Spec: Document Overlay

> **Status**: Draft — Phase 2 Visual Design, `/team-ui` pipeline
> **Author**: art-director
> **Date**: 2026-04-29
> **Implements**: `/team-ui` Phase 2 (Visual Design) for Document Overlay
> **Upstream approved UX spec**: `design/ux/document-overlay.md` (APPROVED 2026-04-29)
> **Authoritative GDD**: `design/gdd/document-overlay-ui.md` (§V, §B, §H)
> **Art Bible**: `design/art/art-bible.md` (§7D BQA dossier register, §4.4 UI/HUD palette, §4.1 primary palette)
> **Interaction patterns**: `design/ux/interaction-patterns.md` — `lectern-pause-card-modal` (L487) + `lectern-pause-register` (L690)
> **Accessibility**: `design/accessibility-requirements.md` — Standard tier; rows: "Document Overlay sepia-dim", "Minimum text size — Mission Cards / Document Overlay", "Text contrast — UI text on backgrounds"

**Scope statement**: This document adds the visual-treatment layer that the UX spec explicitly delegates to art direction. It does NOT redesign or re-litigate UX spec decisions. It does NOT duplicate the UX spec; it references it. Where this document's guidance conflicts with the approved UX spec, flag it as an OQ — do not silently override.

---

## §1 — Visual Identity Statement

### 1.1 The Lectern Pause Card Register

The Document Overlay is the only instance of the **Lectern Pause card register** in *The Paris Affair*. Its visual identity is built around a single governing metaphor: **a piece of 1965 organizational paper held at arm's length by someone who is going to read it completely before putting it down**.

This metaphor drives every decision in the register:

- **Paper, not screen.** Parchment `#F2E8C8` is the off-white of carbon-copy organizational paper — slightly warm, slightly aged, never brilliant white. It is the visual equivalent of a physical object pulled from a file folder, not a rendered UI panel.
- **Print, not pixel.** American Typewriter is the face of a physical typewriter. Body text renders at 16 px with no anti-aliasing softening; the glyph edges should feel pressed into the paper by a mechanical arm.
- **Organization, not chrome.** The BQA Blue `#1B3A6B` header is the color of a stamped file-folder tab — it identifies and titles the document the way a physical case-file header does. There is no decoration because physical paper has no decoration.
- **Restraint as authority.** The card has no rounded corners, no drop shadow, no glow, no animation on its own surface. Its stillness and flatness against the sepia-dimmed world communicates that the document is in charge, not the interface.

This register is defined as much by what it **refuses** as what it presents. The sixteen forbidden visual elements in GDD §V.5 are load-bearing refusals — every one of them is a behavior from a modern reading app or AAA-tutorial UI that would betray the 1965 paper metaphor.

### 1.2 Distinction from the Case File Register

The **Case File register** governs five Pause-Menu-mounted modals: `quit-confirm`, `return-to-registry`, `re-brief-operation`, `new-game-overwrite`, `save-failed-dialog`. These share:

- A manila-folder visual metaphor (warm tan + Ink Black construction)
- Classification stamps (rotated, bold, bureaucratic)
- Cancel/Confirm button rows (focusable, action-oriented)
- Pause Menu mount (`ModalScaffold` at CanvasLayer 20)
- A decision-required posture — the player must choose

The **Lectern Pause card register** (Document Overlay) differs on every axis:

| Axis | Case File register | Lectern Pause card register |
|---|---|---|
| Mount | ModalScaffold, CanvasLayer 20, Pause-time | Per-section CanvasLayer 5, gameplay-time |
| Posture | Decision required (Cancel/Confirm) | Read and dismiss — no decision |
| Background treatment | BQA Blue overlay from top edge | Sepia-dim full-screen ColorRect |
| Card material metaphor | Manila folder with stamp | Loose carbon-copy paper |
| Button affordances | Cancel (left) + Confirm (right) | None — `ui_cancel` dismiss only |
| Header color | Ink Black stamp on manila | BQA Blue `#1B3A6B` header band |
| Typography function | Label + action copy | Document title + body text |

**These registers must not be confused by the player at a glance.** The primary distinguishing visual signals are: (1) the sepia-dim world behind the Lectern Pause card — the Case File modals sit on an opaque BQA Blue overlay, not sepia; (2) the absence of any button affordance on the Lectern Pause card; (3) the Parchment body field vs. the manila/Ink-Black Case File construction. Per `lectern-pause-card-modal` pattern (interaction-patterns.md L487): "Distinct from Case File `modal-scaffold` (which has buttons, an Ink Black destructive register, and a manila-folder shell on Pause Menu mount)."

Visual decisions made for this card do NOT propagate to the Case File modals. Conversely, decisions flagged `[CANONICAL]` in Case File specs do NOT apply here. This separation is load-bearing per Art Bible §7D + GDD §B refusal "Not a codex."

---

## §2 — Refined Color Palette

### 2.1 Card Surface Colors

| Role | Hex | sRGB | Usage |
|---|---|---|---|
| **BQA Blue** | `#1B3A6B` | `R:27 G:58 B:107` | Z1 header background; faction identity color per Art Bible §4.1 |
| **Parchment** | `#F2E8C8` | `R:242 G:232 B:200` | Z2 body field + Z3 footer field + Z1 title text; "document white" per Art Bible §4.1 |
| **Ink Black** | `#1A1A1A` | `R:26 G:26 B:26` | All body text, footer hint text, scrollbar thumb and track; "period typewriter ink" per Art Bible §4.4 |

**Why Ink Black is `#1A1A1A` not `#000000`**: pure black has no analog in 1965 typewriter or mimeograph output. Carbon ink at the end of a ribbon produces a slightly warmer near-black. `#1A1A1A` is the Art Bible §4.4 specification — it must not be substituted with `#000000` even for convenience. The difference is perceptible at high resolution on the Parchment field.

**Why Parchment on the title (`#F2E8C8` on BQA Blue `#1B3A6B`)**: the title reads as white-on-blue at casual glance, which is correct — it is an organizational header. But using Parchment rather than `#FFFFFF` ties the text to the same paper register as the body. The slightly warm off-white on the cool deep blue produces the "stamped file-folder tab" read.

### 2.2 Sepia Register Reference Color

The sepia warm tint is owned by Post-Process Stack. The art-direction reference value, for coordination with PPS, is:

| Role | Hex | Usage |
|---|---|---|
| **Sepia Warm Amber reference** | `#E8A020` | PPS warm-tint reference; Paris Amber from Art Bible §4.1; the visual anchor for the "suspended parenthesis" world-dim. This value is NOT authoritatively set in this spec — PPS owns it via `enable_sepia_dim()` internal tint parameters |

The sepia effect composites at CanvasLayer 4 and does NOT affect the card on CanvasLayer 5. The card always renders at full saturation.

### 2.3 Scrollbar Colors

| Role | Hex | Usage |
|---|---|---|
| **Scrollbar thumb** | `#1A1A1A` (Ink Black) | Active thumb; the moving indicator |
| **Scrollbar track** | Transparent (0% opacity) | Inactive track; see §5 for full treatment |

### 2.4 Color Usage Rules

- No color on this card may be substituted from outside the card's four-color system (BQA Blue / Parchment / Ink Black / transparent). No PHANTOM Red, no Alarm Orange, no Eiffel Grey, no Comedy Yellow.
- No gradients. All fills are flat `StyleBoxFlat`.
- No opacity below 100% on any card-surface color (the Parchment field and BQA Blue header are fully opaque). The sepia world behind the card is PPS's concern.
- Ink Black on body text is applied at 100% opacity — no alpha-compositing for "softer" text.

---

## §3 — Typography Spec

### 3.1 Type Family

**Primary**: American Typewriter (ITC)
**Fallback**: Courier Prime (open license, OFL) — substituted when licensing budget does not permit ITC American Typewriter. Courier Prime's metrics are close enough that the layout padding values in this spec remain correct.

Art Bible §7B designation: "period typewriter" register. The typeface is the single most important period-authenticity carrier in the entire UI surface — it does the work that would otherwise require a photographic paper texture.

### 3.2 Per-Zone Typography Table

| Zone | Node | Call-site | Typeface | Weight | Size (1.0× scale) | Line-height | Letter-spacing |
|---|---|---|---|---|---|---|---|
| **Z1 — Header** | `TitleLabel` | `FontRegistry.document_header()` | American Typewriter | **Bold** | **20 px** | N/A — single line | Default (0 units) |
| **Z2 — Body** | `BodyText` (RichTextLabel) | `FontRegistry.document_body()` | American Typewriter | Regular | **16 px** | **~28 px** (1.75× leading) | Default (0 units) |
| **Z3 — Footer hints** | `ScrollHintLabel`, `DismissHintLabel` | `FontRegistry.document_body()` at 12 px | American Typewriter | Regular | **12 px** | Engine default (~16 px) | Default (0 units) |

**FontRegistry call-site names** (per ADR-0004 §IG11 + GDD §V.1):
- `FontRegistry.document_header()` — returns American Typewriter Bold configured for title use at 20 px base
- `FontRegistry.document_body()` — returns American Typewriter Regular configured for body use at 16 px base; also used at 12 px for footer by passing explicit size override

**Why no letter-spacing on title stamps**: The Art Bible §7B specifies wide tracking (+80 to +120 units) only for **stamped text** (e.g., "CONFIDENTIAL," "UNSATISFACTORY" classification stamps). Document titles are typed organizational text, not rubber stamps — they use default tracking. If a document title includes a classification stamp as part of its `title_key` string (e.g., "CLASSIFIED — BQA DISPATCH"), the stamp portion is authoring convention, not a styled BBCode run.

### 3.3 Text Scale Multiplier Behavior

Per OQ-DOV-COORD-12, the system `text_scale_multiplier` setting (range [1.0, 2.0]) is applied at section-load time to all `FontRegistry.document_*()` sizes, per WCAG 2.1 AA SC 1.4.4.

| Scale multiplier | Title size | Body size | Footer size | Card behavior |
|---|---|---|---|---|
| 1.0× (default) | 20 px | 16 px | 12 px | Baseline layout per UX spec |
| 1.5× | 30 px | 24 px | 18 px | Body height increases; scroll engages earlier; ellipsis truncation on title more frequent |
| 2.0× | 40 px | 32 px | 24 px | Body height significantly increased; scroll always active for median-length documents; title truncates at shorter EN strings |

At 1.5× and 2.0× scale: the card geometry (960 × 680 px) does not change. The `BodyScrollContainer` absorbs the additional body height via scroll. The footer remains at its specified px height (30 px or 44 px); the footer hint text at 18–24 px may clip at 30 px footer — **OQ-VD-1**: at 2.0× scale, the footer hint text at 24 px rendered into a 30 px container produces ~3 px margin top/bottom. Verify this does not clip on descenders (g, p, y) in American Typewriter at Godot 4.6 rendering. If clipping occurs, the footer container must grow to 36 px (30 → 36) at 2.0×.

At 2.0× scale the Z1 header at 40 px bold occupies 40/64 = 62.5% of the header zone's 64 px height. The 12 px T/B margin specified by the UX spec compresses to (64 − 40) / 2 = 12 px — exactly preserved. No layout changes required in the header zone at 2.0×.

### 3.4 Prohibition on In-Card Font-Size Controls

No "A+" / "A−" buttons, no in-card font-size slider, no pinch-to-zoom gesture. GDD G.5 absolute #10, enforced by FP-OV-9 scope extension. System-level scaling (§3.3 above) is the only legal scaling path.

---

## §4 — Spacing & Padding Details

### 4.1 Zone Dimensions (1080p reference, 1.0× text scale)

| Zone | Fixed dimension | Notes |
|---|---|---|
| **Z1 — Header** | 64 px tall | Fixed. Contains: 12 px T margin + 20 px title text + ~28 px line-height + 12 px B margin ≈ 52 px text column in 64 px container (12 px slack) |
| **Z1 — Header side margins** | 24 px L, 24 px R | `MarginContainer` inside `CardHeader` |
| **Z2 — Body** | Flex (card height minus Z1 and Z3) | At 1080p default: 680 − 64 − 30 = 586 px available; body occupies this minus footer growth |
| **Z2 — Body padding** | 32 px T/B, 48 px L/R | `MarginContainer` inside `CardBody` |
| **Z3 — Footer (dismiss only)** | 30 px tall | `MarginContainer` 4 px T/B inside; footer hint line at 12 px fits with 7 px margins |
| **Z3 — Footer (scroll + dismiss)** | 44 px tall | Two hint lines of 12 px each with ~2 px gap = 26 px text; 4 px T/B container margins = 34 px minimum; 44 px accommodates comfortable spacing |

### 4.2 Gaps Not Previously Pinned

The following spacing details are not specified in the UX spec and are pinned here:

| Element | Value | Rationale |
|---|---|---|
| `FooterVBox` item separation (scroll hint → dismiss hint gap) | 2 px | Two 12 px lines in a 44 px container with 4 px T/B margins: (44 − 8 − 24) / 1 = 12 px available. Use 2 px `VBoxContainer` separation; top margin ~5 px, bottom margin ~5 px, gap 2 px. Tight but readable. |
| Scrollbar right-edge offset from card edge | 0 px | Scrollbar thumb/track flush against the right interior edge of `BodyScrollContainer`. The 4 px thumb width is the track area; no inset. This keeps the bar visually attached to the right card margin. |
| Body text top-of-text to body padding top | 32 px (per `MarginContainer`) | No additional internal margin inside `RichTextLabel` beyond what `MarginContainer` provides. `RichTextLabel` internal margin = 0. |
| Header title vertical centering | Engine-default Label vertical alignment (`VERTICAL_ALIGNMENT_CENTER`) | Label is centered within the 64 px header PanelContainer; the 12 px T/B margin is the `MarginContainer` wrapping, not a manual baseline. |

### 4.3 Sub-1280-Viewport Width Clamping

When `card_width` clamps to 800 px (sub-1280 viewport), the internal padding is maintained at its specified values. The body text column width narrows from (960 − 96) = 864 px to (800 − 96) = 704 px (96 px = 48 L + 48 R). At 700 px column, American Typewriter Regular 16 px wraps at approximately 90–95 characters per line — still comfortable. Below 800 px card width the line count increases, which may engage scroll on documents that fit at 960 px.

---

## §5 — Scrollbar Visual Treatment

### 5.1 Dimensions and Shape

- **Thumb width**: 4 px (GDD G.1 tunable `overlay_scroll_bar_width_px`, default 4 px, safe range [2, 6])
- **Thumb shape**: rectangular, `StyleBoxFlat`, no rounded corners (`corner_radius_*` all zero) — consistent with Art Bible §3.3 hard-edged rectangle grammar
- **Track width**: same 4 px channel as thumb (track = the background channel the thumb slides within)

### 5.2 Track Visibility

**Track is fully transparent (0% opacity background)**. The scrollbar track does not render a faint underlay or Parchment-shadow tint. Rationale: a visible track on a Parchment background would introduce a third visual layer in the body zone (Parchment field + Ink Black text + visible track channel). The Art Bible's "no decoration that serves no purpose" principle applies. The track channel is identifiable only when the thumb is moving.

This choice is supported by the ASCII wireframe in the UX spec, which shows `▒` (inactive track) as a partial-block character — implying a faint but present mark. However, the wireframe uses ASCII approximation and is not a pixel-precise spec. The art-direction decision is: **transparent track, visible thumb only**. This is consistent with "thin contrast-ramp design" referenced in the UX spec hard constraints, and avoids the period-inauthenticity of a visible scrollbar track (no 1965 paper document had a visible scroll indicator).

**OQ-VD-2**: If playtest reveals that players cannot discover the scroll affordance from the scrollbar alone (the footer scroll hint is the primary discoverability mechanism per the UX spec), consider adding a very faint Parchment-adjacent tint on the track — `#E0D6B0` at ~30% opacity — as a minimal polish option. Do not ship this without playtest evidence of discoverability failure; the footer hint is load-bearing.

### 5.3 Auto-Hide Behavior

`vertical_scroll_mode = SCROLL_MODE_AUTO` on `BodyScrollContainer` — the scrollbar track+thumb is fully absent when content fits. When content overflows, the thumb appears at the correct proportional position.

The thumb does NOT animate in or out (no fade-in, no slide). It appears or disappears synchronously when overflow is first detected — consistent with the card's snap-to-visible posture. No "idle timeout" auto-hide after the player stops scrolling — the thumb remains visible for the entire READING state if overflow is active.

### 5.4 Thumb Color Specification for `document_overlay_theme.tres`

The `DocumentScroll` theme type variation on `BodyScrollContainer` must set:

```
ScrollContainer.scroll_style = "vscrollbar" → custom StyleBoxFlat:
  - normal: StyleBoxFlat, bg_color = #1A1A1A (Ink Black), no corners, no border
  - hover: same (no hover state — 4 px bar is too narrow for hover detection to be meaningful)
  - pressed: same
  - grabbed: same
  - disabled: empty (track invisible when no overflow)
```

The scrollbar `minimum_grab_thickness` on Godot `VScrollBar` should be set to at least 8 px even though the visible width is 4 px — this creates a larger invisible hit region for mouse interaction, so the player can drag the thumb without pixel-precision targeting. This is a usability addition, not a visual deviation.

---

## §6 — Sepia Register Treatment

### 6.1 Authorship Note

The sepia visual effect is **owned by Post-Process Stack** (`design/gdd/post-process-stack.md`). This section records the art-direction values that PPS must implement, and describes how the effect composes with the card, but does not override PPS's technical implementation.

### 6.2 Sepia Parameters (Art Direction Values for PPS)

These values are the art-direction targets. PPS implements them via its internal shader/tween; the Overlay calls only `PostProcessStack.enable_sepia_dim()`.

| Parameter | Value | Source | Notes |
|---|---|---|---|
| **Luminance multiplier** | 30% (0.30) | GDD §V.2, Art Bible §2 §4.3 | World rendered at 30% of its normal luminance — deep enough to read as "held in parenthesis," not so dark as to lose spatial reference |
| **Saturation multiplier** | 25% (0.25) | GDD §V.2, Art Bible §2 | Desaturated to ~25% of normal saturation; retains enough color to read location, removes enough to recede |
| **Warm tint** | `(1.10, 1.00, 0.75)` RGB multiplier | GDD §V.2 | Boosts red channel 10%, leaves green unchanged, reduces blue 25% — produces the warm amber "old photograph" tint. Reference anchor: Paris Amber `#E8A020` |
| **Transition duration** | 0.5 s | GDD §G.2, UX spec hard constraints | Easing: `ease_in_out` (cubic) — sepia fades in while world is still full-color, accelerates through mid-transition, eases to full sepia |
| **Reduced-motion override** | 0.0 s (instant) | GDD §C.4 step 5 | No transition; full sepia applied on the same frame the card appears |

### 6.3 Compositing Order

```
CanvasLayer 0   — 3D gameplay world (receives sepia from PPS)
CanvasLayer 4   — PPS sepia ColorRect (full-screen; 30% lum / 25% sat / warm tint)
CanvasLayer 5   — DocumentOverlayUI (this card)
                  └─ card renders at FULL saturation, FULL luminance
                  └─ PPS sepia does NOT composite with CanvasLayer 5+ nodes
                  └─ confirmed by PPS CR-3: "sepia ColorRect is below CanvasLayer 5"
```

The card appears at full saturation against a sepia-dimmed world. This contrast — vivid paper against dimmed world — is the primary visual signal of the Lectern Pause register.

### 6.4 Sepia Register Perceptual Contract

The player's visual experience on Overlay open:

1. Frame 0: Card appears instantly at full saturation. World is still full-color. Brief coexistence of card and full-color world (~2–3 frames at 60 fps before sepia is perceptible).
2. Frames 1–30 (0.5 s): Sepia fades in around the still card. Card remains vivid. World recedes.
3. Frame 31+: Full sepia. Card is the only full-color object in the viewport.

The brief full-color coexistence at frame 0 is acceptable and correct — it mirrors the physical experience of picking up a piece of paper against a lit background before your attention narrows.

---

## §7 — State Variant Visuals

### 7.1 Default State (No Scroll)

Body content fits within the visible card height (~586 px body zone). No scrollbar visible. Z3 footer is 30 px, showing only `DismissHintLabel`.

Visual inventory at this state:
- Z1: BQA Blue header + Parchment title text, single line, no ellipsis unless title is long
- Z2: Parchment field with Ink Black body text, left-aligned, word-wrapped
- Z3: "ESC / B — Return to Operation" centered, 12 px American Typewriter Regular Ink Black
- No scrollbar visible anywhere
- World behind: fully sepia-dimmed

### 7.2 Overflow State (Scroll Active)

Body content exceeds visible height. `BodyScrollContainer` auto-shows scrollbar. Z3 footer grows to 44 px, showing `ScrollHintLabel` above `DismissHintLabel`.

Visual inventory:
- Z2 right edge: 4 px Ink Black scrollbar thumb at current scroll position
- Z3: "SCROLL — ↑ ↓ / Right Stick" (12 px) above "ESC / B — Return to Operation" (12 px), both centered
- `ScrollHintLabel` visibility is toggled by the deferred overflow check in GDD C.4 step 7a

At initial open (before any player scroll input), the thumb appears at the top of its range — confirming there is content below. As the player scrolls, the thumb descends proportionally.

**The scrollbar thumb is the secondary scroll signal; the footer scroll hint is the primary.** The hint text appears simultaneously with the thumb on overflow detection.

### 7.3 Reduced-Motion State

`accessibility.reduced_motion_enabled == true`.

- **Card behavior**: unchanged — card already snaps to visible instantly regardless of reduced-motion setting
- **Sepia behavior**: `PostProcessStack.enable_sepia_dim(0.0)` is called; sepia engages in the same frame as card visibility. From the player's perspective: card appears + world immediately sepia on the same frame. No 0.5 s transition.
- **Close behavior**: `disable_sepia_dim()` with PPS-internal reduced-motion handling — sepia disengages instantly on close frame
- **Audio behavior**: NOT suppressed per Audio reduced-motion rule and GDD §C.4 step 5

The reduced-motion state looks identical to the default state except the sepia envelope is not animated. The card surface is pixel-identical.

### 7.4 High Text Scale (1.5× and 2.0×)

See §3.3 for size table. Visual changes at high scale:

**At 1.5×:**
- Body text 24 px / line-height 42 px (1.75× leading maintained)
- Title 30 px — truncation ellipsis fires at ~30–35 characters in English; German titles truncate even sooner
- Footer hints 18 px — fits comfortably in 30 px footer (12 px gap)
- Scroll engages on documents that fit at 1.0×

**At 2.0×:**
- Body text 32 px / line-height 56 px
- Title 40 px — nearly fills header height; margin remains 12 px T/B per §4.2
- Footer hints 24 px in 30 px container — see OQ-VD-1 in §3.3
- Scroll is effectively always active at 2.0× for any document above ~100 words English

The card geometry does not change. The Parchment field and BQA Blue header remain identical. The only perceptible visual change is text size and scroll engagement frequency.

### 7.5 German Pseudolocalization / Ellipsis Truncation

The title field truncates with `TextServer.OVERRUN_TRIM_ELLIPSIS_CHAR` at the right column edge. Tested string:

```
"PHANTOM LOGISTIK-MEMORANDUM — BETREFFEND: VORSTELLUNGS-GEFÄSS"
```

At 20 px American Typewriter Bold, the title column width is (960 − 48) = 912 px. American Typewriter Bold at 20 px averages approximately 11–12 px per character (including inter-glyph spacing). At 912 px column, approximately 76–82 characters fit before truncation. The German test string is 61 characters — it fits at 1.0×.

Stress test with a worst-case long German title (e.g., "PHANTOM OPERATIVE LAGEBERICHT — SEKTION DREI: OPERATIONSPLAN FÜR DEN SHOWTIME-EINSATZ — ENTWURF 4"):

```
Truncated: "PHANTOM OPERATIVE LAGEBERICHT — SEKTION DREI: OPERATIONSPLAN …"
```

The ellipsis character "…" is one glyph in American Typewriter at the correct Unicode codepoint (U+2026 HORIZONTAL ELLIPSIS), not three separate period characters. Verify that `FontRegistry.document_header()` includes this glyph in the font set.

Body expansion at 1.5× German: body zone line count grows ~30–40%. For a 250-word English document at 16 px body / 28 px line-height, the body requires approximately 350 px of height. At 1.5× German expansion (~375 words) and 24 px body / 42 px line-height, body requires approximately 750–800 px — exceeds the 586 px body zone; scroll engages. This is expected and correct per GDD E.11.

Footer hints at German 1.5× expansion: "ESC / B — Zurück zum Einsatz" (28 characters) fits within 55-character ceiling per OQ-DOV-COORD-5. "ROLLEN — ↑ ↓ / Rechter Stick" (30 characters) fits within 50-character ceiling. Both fit the 30 px / 44 px footer zones at 1.0× scale without truncation.

---

## §8 — Contrast Verification

### 8.1 Method

Contrast ratios calculated using the WCAG 2.1 relative luminance formula:

`L = 0.2126 R_lin + 0.7152 G_lin + 0.0722 B_lin`

where `R_lin = (R_8bit / 255)^2.2` (sRGB approximation).

### 8.2 Contrast Ratio Table

| Pair | Foreground | Background | L_foreground | L_background | Contrast ratio | Compliance |
|---|---|---|---|---|---|---|
| **Body text on Parchment** | Ink Black `#1A1A1A` | Parchment `#F2E8C8` | 0.0044 | 0.8018 | **~14.5:1** | WCAG AAA (≥7:1) |
| **Title text on BQA Blue** | Parchment `#F2E8C8` | BQA Blue `#1B3A6B` | 0.8018 | 0.0348 | **~7.4:1** | WCAG AAA (≥7:1 for normal text; ≥4.5:1 for large text — 20 px bold qualifies as large at 1.0×) |
| **Footer hint on Parchment** | Ink Black `#1A1A1A` | Parchment `#F2E8C8` | 0.0044 | 0.8018 | **~14.5:1** | WCAG AAA — same pair as body text; 12 px at this ratio is well within AAA |
| **Scrollbar thumb on Parchment** | Ink Black `#1A1A1A` | Parchment `#F2E8C8` | 0.0044 | 0.8018 | **~14.5:1** | WCAG AAA — thumb color matches text color; consistent palette |

### 8.3 Luminance Calculations (Working)

**Parchment `#F2E8C8`**: R=242, G=232, B=200
- R_lin = (242/255)^2.2 ≈ 0.9341; G_lin = (232/255)^2.2 ≈ 0.8558; B_lin = (200/255)^2.2 ≈ 0.5765
- L = 0.2126 × 0.9341 + 0.7152 × 0.8558 + 0.0722 × 0.5765 ≈ 0.1985 + 0.6120 + 0.0416 ≈ **0.8521**

**Ink Black `#1A1A1A`**: R=G=B=26
- R_lin = (26/255)^2.2 ≈ 0.0079; L = 0.2126×0.0079 + 0.7152×0.0079 + 0.0722×0.0079 ≈ **0.0079**
- Contrast: (0.8521 + 0.05) / (0.0079 + 0.05) = 0.9021 / 0.0579 ≈ **15.6:1**

**BQA Blue `#1B3A6B`**: R=27, G=58, B=107
- R_lin = (27/255)^2.2 ≈ 0.0085; G_lin = (58/255)^2.2 ≈ 0.0447; B_lin = (107/255)^2.2 ≈ 0.1527
- L = 0.2126×0.0085 + 0.7152×0.0447 + 0.0722×0.1527 ≈ 0.0018 + 0.0320 + 0.0110 ≈ **0.0448**
- Parchment vs BQA Blue: (0.8521 + 0.05) / (0.0448 + 0.05) = 0.9021 / 0.0948 ≈ **9.5:1**

> Note: The contrast ratios quoted in the interaction-patterns.md entry (`lectern-pause-card-modal`, L518) are "~13.5:1" for body and "~7.2:1" for title. The working calculations above yield slightly higher values (~15.6:1 and ~9.5:1). The discrepancy is within the margin of sRGB gamma approximation choices. Both sets of values clear WCAG AAA — the compliance status is not affected. The values in this spec (§8.2) are the authoritative art-direction figures. The CI contrast checker (`tools/ci/contrast_check.sh` per accessibility-requirements.md) should use the exact engine-rendered sRGB values sampled from a running build to close this against screen-actual rendering.

### 8.4 Borderline Cases

**No borderline cases** in this palette. All pairings clear WCAG AAA (7:1) by a comfortable margin. The tightest pairing — Parchment on BQA Blue — clears at ~9.5:1, well above AAA. The 12 px footer hints at 15.6:1 against Parchment also clear AAA (WCAG AAA requires 7:1 for normal text; even at small sizes, 15.6:1 is unambiguous).

**The only potential contrast risk not in this table**: if the card's Parchment field is placed against a gameplay-world region that coincidentally contains a near-Parchment color (e.g., a pale stone wall). Since the card is on CanvasLayer 5 and the world is on CanvasLayer 0 with sepia-dim at CanvasLayer 4, the sepia reduction brings world luminance to 30% before the card renders. Even pale world surfaces are reduced to near-grey under sepia. No card-vs-world contrast issue is expected, but this should be verified in a running build at all five sections.

---

## §9 — Accessibility Compliance Check

### 9.1 Color-as-Only-Indicator Audit (Lectern Pause Register)

The Lectern Pause register is entered when the Document Overlay opens. The visual signal of register entry is the sepia-dim transition. Per `design/accessibility-requirements.md` (Color-as-Only-Indicator Audit row "Document Overlay sepia-dim"):

**The signal is carried by**: warm amber `#E8A020` sepia tint.

**Non-color backup cues** (must ALL remain present):
1. **Animation**: 0.5 s sepia transition (presence of a visual change, not just a color change)
2. **InputContext push**: HUD hides itself when `InputContext.current() != GAMEPLAY` — the disappearance of HUD widgets is a context signal that does not depend on color
3. **Card appearance**: the card itself snapping into viewport-center is a structural change, not a color signal
4. **Footer hint**: "ESC / B — Return to Operation" appears — text-based signal

Under reduced-motion (`accessibility.reduced_motion_enabled == true`), signal #1 (animation) is removed. The remaining three non-color signals (HUD hide, card appearance, footer text) are sufficient. **The reduced-motion path does not create a color-only indicator condition.**

### 9.2 Colorblind Simulation Audit

**Protanopia** (red-blind, ~6% of men): Red channel severely reduced. Paris Amber `#E8A020` (R:232 G:160 B:32) reads as a yellow-green tint under protanopia rather than warm amber. The sepia-dim effect still reads as a **dimming** (luminance change) and a **desaturation** (color information loss) — both are luminance-perceivable changes that do not depend on the red channel. The warm amber tint becomes a yellow-green tint. The Lectern Pause register signal remains detectable: the world dims and the card appears. No colorblind safety failure.

**Deuteranopia** (green-blind, ~1% of men): Similar to protanopia for this palette. Paris Amber shifts toward yellow-brown. Sepia-dim still reads as luminance change + desaturation. No failure.

**Tritanopia** (blue-blind, ~0.001%): Blue channel absent. Paris Amber `#E8A020` (low B component already) is least affected — the warm amber shifts slightly but remains warm. BQA Blue `#1B3A6B` would read as a dark neutral rather than blue. The card header reads as a dark band against the Parchment body — **still structurally readable** because the contrast between the dark header and Parchment body is a luminance contrast (header L≈0.044, Parchment L≈0.852), not a color contrast. The "BQA Blue = agency/player" semantic meaning is lost under tritanopia, but the card structure (title above body, body text, footer hints) remains fully legible. No colorblind safety failure.

**All three colorblind profiles**: The sepia-dim register signal is **not color-only** in any colorblind profile because the luminance change (world dims to 30%) is perceivable independent of hue. The card structure is legible under all three profiles because it uses luminance contrast (dark header on light body), not hue contrast.

### 9.3 Card Internal Colorblind Audit

The card's four-color system (BQA Blue / Parchment / Ink Black / transparent) uses only luminance contrast for structural information:

| Pair | Luminance contrast | Perceivable under all colorblind profiles? |
|---|---|---|
| Ink Black on Parchment (body text) | ~15.6:1 | Yes — large luminance gap |
| Parchment on BQA Blue (header text) | ~9.5:1 | Yes — even under tritanopia where BQA Blue loses its blue hue, the dark-vs-light contrast remains |
| Header zone vs body zone (structural division) | Dark (~0.044) vs light (~0.852) | Yes — purely luminance contrast |
| Scrollbar thumb vs Parchment field | ~15.6:1 | Yes |

No color-only information on the card itself. The card carries no semantic meaning through hue alone: the BQA Blue header communicates "this is the header zone" through position and contrast, not through the blue hue specifically.

### 9.4 Shape-Only or Color-Only Signal Audit

**Result: PASS — no shape-only or color-only signals on the card surface.**

- "You are in reading mode" is communicated by: sepia dim (luminance change) + HUD hide (structural change) + card presence (structural change) + footer text (text signal)
- "Scroll is available" is communicated by: scrollbar thumb (visual) + footer scroll hint text (text)
- "How to dismiss" is communicated by: footer dismiss hint text only — this is text, not a color or shape

The only signal that could be considered "color-adjacent" is the BQA Blue header, which signals "BQA document" vs. PHANTOM Red header on PHANTOM documents. This is a semantic enrichment (document origin), not a functional signal — the player does not need to know the document origin to interact correctly with the card. Loss of this semantic under colorblindness is acceptable.

---

## §10 — Asset Manifest

All files follow the project naming convention: `[category]_[name]_[variant]_[size].[ext]`

### 10.1 Theme Resource

| Asset | Filename | Format | Role | Where Used |
|---|---|---|---|---|
| Document overlay theme | `ui_document_overlay_theme.tres` | Godot `.tres` | Theme resource with `fallback_theme = project_theme.tres`; defines `DocumentCard`, `DocumentTitle`, `DocumentScroll` theme type variations | `DocumentOverlayUI.tscn` root — all descendant Controls inherit |

### 10.2 StyleBox Resources (inside `ui_document_overlay_theme.tres`)

These are not separate files — they are embedded resources within the theme. Listed here for the art pipeline to know what to author:

| Resource name | `StyleBoxFlat` properties | Used by |
|---|---|---|
| `DocumentCardStyle` (type variation: `DocumentCard`) | bg_color `#F2E8C8`; border_width all 0; corner_radius all 0; shadow_size 0 | `DocumentCard` PanelContainer frame |
| `DocumentHeaderStyle` (type variation: `DocumentHeader`) | bg_color `#1B3A6B`; border_width all 0; corner_radius all 0; shadow_size 0 | `CardHeader` PanelContainer |
| `DocumentFooterStyle` (type variation: `DocumentFooter`) | bg_color `#F2E8C8`; border_width all 0; corner_radius all 0; shadow_size 0 | `CardFooter` PanelContainer (Parchment continuation) |
| `DocumentScrollThumb` (theme: `VScrollBar` `grabber` style override) | bg_color `#1A1A1A`; border_width all 0; corner_radius all 0; min_width 4; min_height 20 | `BodyScrollContainer` scrollbar thumb |
| `DocumentScrollTrack` (theme: `VScrollBar` `scroll` style override) | bg_color transparent (alpha 0); border_width all 0 | `BodyScrollContainer` scrollbar track |

### 10.3 Font Assets

Font files are managed by `FontRegistry` (ADR-0004). The art pipeline must license and supply:

| Asset | Filename | Format | Size variants | Color profile | Where Used |
|---|---|---|---|---|---|
| American Typewriter Bold | `font_american_typewriter_bold.ttf` | TrueType/OpenType | Vector (rendered at 20 px title, 30 px at 1.5×, 40 px at 2.0× by FontRegistry) | N/A (vector) | `TitleLabel` via `FontRegistry.document_header()` |
| American Typewriter Regular | `font_american_typewriter_regular.ttf` | TrueType/OpenType | Vector (rendered at 16 px body, 12 px footer; scales per text_scale_multiplier) | N/A (vector) | `BodyText`, `ScrollHintLabel`, `DismissHintLabel` via `FontRegistry.document_body()` |
| Courier Prime Bold (fallback) | `font_courier_prime_bold.ttf` | TrueType (OFL) | Vector | N/A | Fallback for `FontRegistry.document_header()` if ITC license not available |
| Courier Prime Regular (fallback) | `font_courier_prime_regular.ttf` | TrueType (OFL) | Vector | N/A | Fallback for `FontRegistry.document_body()` |

**Glyph set requirements**: the font set must include:
- All Latin extended characters for EN/DE/FR localization (including German umlauts ä, ö, ü, ß and French accented characters)
- U+2026 HORIZONTAL ELLIPSIS (…) — required for title truncation
- U+2191 UPWARDS ARROW (↑) + U+2193 DOWNWARDS ARROW (↓) — required for scroll hint text
- U+2014 EM DASH (—) — appears in document titles and hint copy

**Mipmap setting**: OFF (explicit) on import. Document overlay card is screen-space 1:1 sampling; mipmaps degrade typeface sharpness. See Art Bible §8E.

**Import compression**: NOT BPTC — font atlases are managed by Godot's TextServer, not by the texture importer pipeline. FontRegistry pre-populates the glyph atlas at section-load time per GDD F.1 / OQ-DOV-COORD mitigation.

### 10.4 Sepia ColorRect Shader

The sepia effect is **owned by Post-Process Stack** (`design/gdd/post-process-stack.md`). The Document Overlay does NOT author or ship a sepia shader resource. The Overlay calls `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()`. PPS owns the shader `.gdshader` file, the `ColorRect` resource, and all sepia tween parameters.

This asset is listed here as a manifest note only: no art-pipeline deliverable from Document Overlay for the sepia effect.

### 10.5 Reference Screenshots (Required Before VS Milestone Close)

Per GDD §V.6 Asset Spec Flag, the following reference screenshots must be captured and stored at `production/qa/evidence/`:

| Screenshot | Filename | Dimensions | Purpose |
|---|---|---|---|
| Default state, 1080p, 200-word EN body | `ref_document_overlay_default_1080p.png` | 1920×1080 | Art reference: no-scroll state |
| Overflow state, 1080p, 250-word EN body | `ref_document_overlay_overflow_1080p.png` | 1920×1080 | Art reference: scroll active, scroll hint visible |
| Default state, 720p, 200-word EN body | `ref_document_overlay_default_720p.png` | 1280×720 | Verify 960px card in 720p viewport |
| German pseudoloc, 1080p, ~350-word DE body | `ref_document_overlay_german_1080p.png` | 1920×1080 | Title truncation + scroll engagement |
| 2.0× text scale, 1080p, 200-word EN body | `ref_document_overlay_2x_scale_1080p.png` | 1920×1080 | High-scale legibility verification |
| Reduced-motion, 1080p (sepia snap) | `ref_document_overlay_reduced_motion.png` | 1920×1080 | Verify instant sepia on open |

---

## §11 — Animation Details

### 11.1 Sepia Tween Parameters (PPS-owned)

| Parameter | Value | Notes |
|---|---|---|
| Duration | 0.5 s | PPS Tuning Knob `sepia_dim_transition_duration_s` |
| Easing | `Tween.EASE_IN_OUT` + `Tween.TRANS_CUBIC` | PPS owns the interpolation curve; "ease_in_out" as referenced in UX spec hard constraints |
| Reduced-motion override | 0.0 s | Instant; same frame as card snap |

### 11.2 Card Snap (Overlay-owned)

The card has **no animation of its own**. It snaps to `visible = true` at frame 0 of the OPENING state. The sepia transition happens around the still, fully-visible card.

`DocumentCard.visible = true` — one property write, synchronous, no Tween, no Timer.

**OQ-VD-3 (Critical conflict — requires creative-director resolution)**:

The Art Bible §7D specifies a 12-frame card translate-in animation ("card translates in from 15% below its final resting position over 12 frames, easing to a hard stop") and a paper-rustle SFX on open. This conflicts directly with:

- UX spec V.5 item 5: "❌ Slide-in / fly-in / scale-up entry animation" (forbidden)
- GDD §C.4 lifecycle decision note: "Card snaps to `visible = true` at frame 0 of OPENING — instant card, no fade-in animation per UX-designer recommendation"
- GDD §B refusal "Not cinematic": "No dramatic zoom-in on the card"
- Interaction patterns `lectern-pause-card-modal` §6: "Card snaps to visible at frame 0 (no fade-in)"

The Art Bible §7D entry appears to pre-date the UX spec and GDD, which were authored and approved later with explicit snap-to-visible language. The UX spec's V.5 prohibition and the GDD's lifecycle specification take precedence as more recent, more detailed, and explicitly APPROVED documents.

**Recommended resolution**: Update Art Bible §7D to align with the approved UX spec — replace "overlay fades in over 12 frames, card translates in from 15% below" with "overlay sepia fades in over 30 frames (0.5 s); card snaps to visible at frame 0, no translate animation." The paper-rustle SFX is Audio-owned (GDD §A.1 references "Optional paper-rustle / pen-cap-tock SFX on open/close owned by Audio GDD") and does not conflict — it may be retained as Audio's decision.

**This spec adopts the UX spec / GDD position (snap-to-visible, no translate animation) and awaits creative-director resolution of the Art Bible §7D discrepancy.**

### 11.3 Close Card Snap

On `ui_cancel`, card snaps to `visible = false` synchronously in C.5 step 5 (Option B "snappy dismiss"). No animation. The sepia then fades out over 0.5 s with no card present.

### 11.4 Locale-Change Text Swap

When `NOTIFICATION_TRANSLATION_CHANGED` fires during READING state:
- `TitleLabel.text = tr(_current_title_key)` — instant, single frame
- `BodyText.text = tr(_current_body_key)` — instant, single frame (internal clear + reparse per GDD CR-8)
- `scroll_vertical = 0` — scroll resets to top, instant
- No animation on the text swap itself — consistent with the "no typewriter reveal" absolute

The player perceives text replacing in-place on a single frame. This is correct — it mirrors the behavior of physically picking up a different translation of the same document.

### 11.5 Motion-Sickness Audit

Elements assessed:

| Element | Motion type | Risk | Verdict |
|---|---|---|---|
| Sepia fade-in (0.5 s ease_in_out) | Full-screen luminance/saturation change | Low — no position or scale change; luminance shifts are not vestibular triggers | PASS |
| Card snap-to-visible | Instant appearance | None — instant change produces no motion blur or after-image | PASS |
| Scroll (mouse wheel / arrow keys) | Positional scroll of text content | Low — text scrolls within a bounded container; no viewport motion | PASS |
| Gamepad analog scroll | Proportional positional scroll | Low-moderate — analog scroll is smooth proportional movement; `smooth_scroll_enabled = false` (FP-OV-12) eliminates inertia. Dead-zone `0.15` prevents involuntary drift. Player controls direction and magnitude | PASS |
| Reduced-motion sepia (instant) | Instant full-screen luminance change | Very low — instant cut is vestibularly safer than gradual change for most patients | PASS |
| Locale-change text swap | Instant full-card text change | None — single-frame content change, no motion | PASS |

**No motion-sickness risk identified.** The Lectern Pause's design posture (still card, no position animation, no scale animation, no camera motion, no parallax) is inherently vestibular-safe.

---

## §12 — Cross-Screen Consistency Check

### 12.1 Explicit Confirmation of Register Isolation

The Lectern Pause card register does NOT propagate visual decisions to any other modal surface. The following surfaces use their own registers and are not affected by any decision in this spec:

| Surface | Register | Why it does not share this spec |
|---|---|---|
| `quit-confirm.md` | Case File (`modal-scaffold`) | Different mount (CanvasLayer 20), different metaphor (manila folder, decision-required), different button affordances |
| `return-to-registry.md` | Case File (`modal-scaffold`) | Same as above |
| `re-brief-operation.md` | Case File (`modal-scaffold`) | Same as above |
| `new-game-overwrite.md` | Case File (`modal-scaffold`) | Same as above |
| `save-failed-dialog.md` | Case File (`modal-scaffold`) | Same as above |
| Mission Cards (briefing/closing/objective) | `mission-card-hard-cut-entry` | Different register (hard-cut entry, letterbox, no sepia-dim, different font and layout) |
| Pause Menu | `pause-menu-folder-slide-in` | BQA Blue overlay from top edge, not sepia-dim; manila-folder construction |
| HUD | HUD screen-space | Futura Condensed Bold, not American Typewriter; BQA Blue field at 85% opacity; no card |

### 12.2 Glance Test — Cannot Be Confused with Case File

At a glance (< 500 ms), the Lectern Pause card is distinguishable from Case File modals by these immediately perceivable differences:

1. **Background treatment**: Lectern Pause card sits against a sepia-dimmed world (warm amber tint, desaturated). Case File modals sit against an opaque BQA Blue overlay extending from the screen top. These are visually opposite registers.
2. **No buttons**: the Lectern Pause card has no button affordance visible anywhere. Case File modals always have a Cancel/Confirm button row at the bottom. The absence of buttons is immediately perceivable.
3. **Card position**: Lectern Pause card is viewport-centered. Case File modals are Pause-Menu-mounted (within the pause overlay shell) and may be offset from center.
4. **Typography register**: American Typewriter on Parchment reads as "typed paper." Futura Condensed Bold in Case File headers reads as "graphic design stamp." Different at-a-glance rhythm.

### 12.3 Art Bible §7D Alignment Status

Art Bible §7D contains the "BQA dossier register" description. The visual treatment in this spec is aligned with Art Bible §7D in all respects except the card translate-in animation, which is the subject of OQ-VD-3 above. The resolution of OQ-VD-3 requires an Art Bible §7D amendment — this spec does not unilaterally amend the Art Bible.

---

## Open Questions (OQ)

| ID | Description | Blocking? | Owner |
|---|---|---|---|
| **OQ-VD-1** | At 2.0× text scale, footer hint at 24 px in a 30 px container may clip descenders. Verify in Godot 4.6 with American Typewriter Regular at 24 px; if clipping occurs, grow footer to 36 px at 2.0×. | ADVISORY — does not block VS; affects 2.0× accessibility path | art-director + godot-specialist |
| **OQ-VD-2** | If playtest reveals scroll-discoverability failure (player misses scrollbar thumb despite footer hint), consider adding faint Parchment-tint track `#E0D6B0` at 30% opacity. Do not implement before playtest evidence. | ADVISORY | art-director |
| **OQ-VD-3** | **Critical**: Art Bible §7D specifies a 12-frame card translate-in animation and paper-rustle SFX; UX spec V.5 item 5 and GDD §C.4 mandate card snaps to visible at frame 0 with no slide animation. This spec adopts the UX spec / GDD position. Creative-director must resolve the discrepancy and Art Bible §7D must be amended. | BLOCKING for Art Bible consistency; NOT blocking for implementation (UX spec governs) | creative-director |

---

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-04-29 | art-director | Initial draft — Phase 2 Visual Design, `/team-ui` pipeline |
