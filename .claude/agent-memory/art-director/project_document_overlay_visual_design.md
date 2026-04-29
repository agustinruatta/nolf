---
name: Document Overlay Visual Design Spec
description: Visual design spec authored for Document Overlay (Lectern Pause register) — key decisions, palette, conflicts flagged
type: project
---

Visual design spec written 2026-04-29 at `design/art/visual-design/document-overlay.md` as Phase 2 of the `/team-ui` pipeline.

**Key decisions locked:**
- Parchment `#F2E8C8` body / BQA Blue `#1B3A6B` header / Ink Black `#1A1A1A` text + scrollbar
- Scrollbar track: fully transparent; thumb: 4 px Ink Black only
- All contrast ratios clear WCAG AAA (~15.6:1 body, ~9.5:1 title)
- Card snap-to-visible at frame 0 (no translate animation) — adopted from UX spec / GDD position
- Sepia: 30% luminance, 25% saturation, warm tint (1.10, 1.00, 0.75), 0.5 s ease_in_out

**Why:** This register is the Lectern Pause card (CanvasLayer 5, gameplay-time, no buttons) — distinct from the Case File register (ModalScaffold, Pause-Menu-time, Cancel/Confirm buttons). The two must not visually bleed into each other.

**How to apply:** When reviewing any modal or card design, check which register it belongs to before applying visual rules. Lectern Pause ≠ Case File.

**OQ-VD-3 (Critical — unresolved):** Art Bible §7D specifies a 12-frame card translate-in animation that directly contradicts the UX spec V.5 item 5 ("No slide-in / fly-in / scale-up entry animation") and GDD §C.4. Needs creative-director resolution + Art Bible §7D amendment. Implementation follows UX spec / GDD (snap-to-visible, no animation).
