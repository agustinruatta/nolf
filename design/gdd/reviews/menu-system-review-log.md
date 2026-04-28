# Menu System — Review Log

Tracks `/design-review` and `/review-all-gdds` verdicts on `design/gdd/menu-system.md` for revision-history traceability.

---

## Review — 2026-04-27 — Verdict: APPROVED (with revisions applied in-session)
Scope signal: XL
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist, audio-director, performance-analyst, accessibility-specialist, localization-lead, creative-director (synthesis)
Blocking items: 12 | Recommended: 38 | Nice-to-have: 3
Summary: First review of the 1,715-line Menu System GDD authored solo-mode 2026-04-26 PM. Creative Director's initial verdict was MAJOR REVISION NEEDED — the GDD is exceptionally thorough (25 CRs, 8 formulas, 40 edge cases, 18 forbidden patterns, 61 ACs) and earned a precision rejection rather than dismissal. 9 specialists converged on a small set of structural problems: F.1 grid/folder geometry contradiction (726 px grid in 520 px folder), CR-5 destructive silent label-swap, CR-22/GATE-F8-B status incoherence, GATE-F7-A elevation needed for Day-1 boot-warning AT, photosensitivity body not announced by AT, F.6 dishonest "exact zero" budget claim, inconsistent `accessibility_description` coverage across Case File rebrands, ModalScaffold queue silently dropping non-idempotent destructive intent, AFP-5 violation in A.3 example, six untestable ACs, cursor hotspot (0,0) contradicting "top-right nib tip" art spec, OQ-MENU-17 cap-scope ambiguity. Per user decision, all 12 BLOCKING items were resolved in-session (1,715 → 1,748 lines). 38 RECOMMENDED items documented and deferred to fast-follow. Final verdict: APPROVED with revisions applied; no re-review session required pending sprint-time validation of the 14 inherited BLOCKING coord items.
Prior verdict resolved: First review.

### User-adjudicated decisions during revision (3)
1. **Folder geometry conflict**: Grow folder width to 760 px (rejected: ScrollContainer / 1×8 single-column / spillover). G.2 + V.1 + V.8 + §C.5 updated.
2. **CR-5 mitigation**: Always-fire New-Game-Overwrite confirm modal when activated from "Begin Operation" label (slot 0 corrupt/empty path), regardless of slots 1–7 state. CR-5 + CR-6 amended.
3. **ModalScaffold queue policy**: Differentiate by content idempotency. Save-failed (idempotent) = most-recent-wins. Destructive confirms (Quit-Confirm, Return-to-Registry, Re-Brief, New-Game-Overwrite) = preserved; new destructive request while another is active is rejected with `push_error`. §C.4 amended.

### Items resolved (12 BLOCKING)
1. F.1 grid (726 px) doesn't fit folder (520 px) → folder grown to 760×720 px
2. CR-5 silent label-swap = destructive UX → always-fire confirm on Begin-Operation activation
3. CR-22 / GATE-F8-B incoherence → resolution committed: defensive plumbing mandatory regardless of gate outcome
4. GATE-F7-A → elevated from VS-BLOCKING/MVP-ADVISORY to BLOCKING-MVP
5. Photosensitivity warning body not announced by AT → `accessibility_description` on modal root carries full body
6. F.6 `C_menu_idle = 0.0 (exact)` → corrected to `≤ 0.005 ms below-measurement-threshold`; Save grid spike bounded; "Pause not budget-critical" framing rescinded
7. accessibility_description coverage gap → 11 `menu.*.desc` keys added covering all Case File rebrands
8. Cursor hotspot (0,0) ≠ "top-right nib tip" → corrected to (30, 0)
9. AFP-5 violation in A.3 example → `await AudioManager.begin_main_menu_fade_out()` replaces direct `volume_db` write
10. ModalScaffold queue silently drops destructive intent → content-type-aware queue policy
11. Six untestable ACs (1.4, 13.1, 19.1, 22.1, 15.8, 15.9, 15.15, 16.1) → all rewritten per qa-lead's specific suggestions; AC-22.1 split into 22.1a (pre-sprint gate) + 22.1b (functional); AC-19.3 added for OS-level manual playtest
12. OQ-MENU-17 elevation → moved to BLOCKING list as OQ-MENU-25

### Items deferred to fast-follow (38 RECOMMENDED)
Documented in the review's Phase 4 output. Highest-priority among the deferred:
- Pillar 1 framing rewrite (§B claims "ambient comedy layer" without delivering)
- Pillar 5 over-policing reorganization (re-tag FP-14/15/16/17 as "Accessibility Floor" not Pillar 5)
- Stamp asset locale story (formal Pillar 5 EN-only carve-out preferred)
- §C.8 missing tr-keys (V.4 OPERATIONAL ADVISORY header; V.1 folder tab text)
- §C.8 / V.2 SAUVEGARDE AUTO vs Autosave inconsistency
- F.4 reduced-motion gate cross-reference
- F.5 missing arrow-key transition for CONFIRM_PENDING focus exit
- 5 different `ui_cancel` semantics consolidation
- Stamp text floor (8–9 px violates V.9 note 8's own 10 px floor)
- PHANTOM Red 45%-opacity contrast (≈ 2.5:1, fails SC 1.4.3)
- Settings-from-photosensitivity-modal return path
- Custom cursor OS-fallback toggle
- F.2 CJK / 200% pseudolocale branch
- Pseudolocale CI gate AC
- A.5 cue-type differentiation (confirmation vs motion-sync) under reduced-motion
- Save-failed sting bus reclassification (SFX → UI to avoid pool stealing)
- `setting_changed` Variant payload anti-pattern → typed signal
- `show_modal()` API signature String/PackedScene reconciliation
- ScrollContainer for photosensitivity body at OS text-scaling 200%

### Specialist disagreements
None — 9 specialists converged on overlapping issues. The closest to a disagreement was game-designer's Pillar 1 critique (other specialists didn't address Pillar 1; CD ruled in §B framing should be softened). godot-specialist + systems-designer agreed on closing GATE-F3-A immediately (same resolution path: skip the Tween, do not call `set_duration(0.0)`).

### Inherited BLOCKING coord items (14, unchanged by this review)
OQ-MENU-1 through OQ-MENU-14, plus OQ-MENU-25 (newly elevated from OQ-MENU-17). These remain sprint-blockers for Menu System implementation.
