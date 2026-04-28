# Change Impact Report — Document Overlay UI revisions

**Trigger:** `/design-review design/gdd/document-overlay-ui.md` 2026-04-27 evening (verdict MAJOR REVISION NEEDED → 46 items resolved in-session) followed by `/propagate-design-change design/gdd/document-overlay-ui.md`

**Mode:** solo (TD-CHANGE-IMPACT director gate skipped per skill Phase 6b)

**Git baseline:** None — `design/gdd/document-overlay-ui.md` was untracked in git at the time of the design-review (newly authored same day; revisions applied pre-commit). Per skill Phase 3, the no-git-history condition was met. This report documents the propagation work nonetheless because the revisions interacted with already-committed ADRs.

---

## Change Summary

The Document Overlay UI GDD (1,160 lines, system #20, pure Vertical-Slice scope) underwent a substantive revision pass on 2026-04-27 evening following a 9-specialist design review. The pass resolved 23 BLOCKING + 19 RECOMMENDED + 4 NICE-TO-HAVE findings.

### Changes affecting architecture

The revisions that propagated to ADRs:

1. **Gate B (Theme inheritance property)**: closed by godot-specialist as "`Theme.fallback_theme` is the verified Godot 4.x property; `base_theme` does NOT exist on `Theme` in any 4.x release." Affects ADR-0004's Implementation Guidelines item 6 + 9 locations using `base_theme`.
2. **Gate D (`auto_translate_mode` enum names)**: closed by godot-specialist as "`Node.AUTO_TRANSLATE_MODE_*` exists in Godot 4.5+ with constants ALWAYS / DISABLED / INHERIT." Affects ADR-0004's Verification Required surface (this gate was added as Gate 4 in the GDD; ADR-0004 had not previously listed it).
3. **Gate E (RichTextLabel re-render)**: promoted ADVISORY → BLOCKING. Affects ADR-0004 indirectly (re-render path is GDD-owned; ADR-0004 establishes the rendering contract). No ADR change required.
4. **Gate G NEW (BBCode → AccessKit plain-text serialization)**: added by accessibility-specialist as BLOCKING for SC 1.3.1 conformance on formatted document bodies. Affects ADR-0004's Verification Required surface (this is a new architectural-level gate; ADR-0004 must list it).

### Changes NOT affecting architecture (GDD-to-GDD only)

- 3 NEW BLOCKING GDD-coordination items: OQ-DOV-COORD-12 (Settings text_scale_multiplier), COORD-13 (call-order recorder helper), COORD-14 (HUD Tween-on-InputContext-change)
- Writer brief amended with 250-word ceiling (`design/narrative/document-writer-brief.md` §7.5)
- Localization Scaffold §Interactions ownership table requires `overlay.*` row addition (owned by Localization Scaffold author)
- MLS GDD requires section-teardown order convention (E.21 amendment)

---

## Impact Analysis

ADRs referencing this GDD: 1 (ADR-0004 UI Framework). Plus `architecture.md` (umbrella architecture doc, no `base_theme` references — clean).

### ADR-0001 (Stencil ID Contract)

**Status:** ✅ Still Valid

**Assessment:** Does not reference Document Overlay UI by name. The GDD acknowledges PPS sepia ColorRect is stencil-0 exception per existing ADR-0001 §103. No ADR change needed.

### ADR-0002 (Signal Bus Event Taxonomy)

**Status:** ✅ Still Valid

**Assessment:** Document domain (`document_opened` / `document_closed`) sole-publisher discipline unchanged by revision; CR-1 sole-subscriber unchanged. No new signals added by the revision. No ADR change needed.

### ADR-0003 (Save Format Contract)

**Status:** ✅ Still Valid

**Assessment:** Overlay state is ephemeral; no save interaction. Revisions did not change this. No ADR change needed.

### ADR-0004 (UI Framework)

**Status:** ⚠️ Needs Review → **RESOLVED 2026-04-27 evening (Amendment A5 applied in-place)**

**What the ADR assumed about this GDD:**
> "(Gate 2) confirm Theme inheritance property name (`base_theme` vs `fallback_theme` vs other) in Godot 4.6 — `ui.md` confirms inheritance exists but does not enumerate the property."

**What the GDD now says:**
> "`document_overlay_theme.tres` sets `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")` — `fallback_theme` is the verified Godot 4.x property for `Theme` parent-chaining (`base_theme` does NOT exist on `Theme` in any 4.x release; reviewer fix per godot-specialist 2026-04-27). Gate B closed 2026-04-27."

**Assessment:** The architectural decision (single `project_theme.tres` base + per-surface inherited Themes) is **still architecturally valid** — Theme inheritance via parent-chaining works in Godot 4.x. However, the **property name used to express that inheritance** was wrong throughout the ADR. The decision survives; the implementation guidance was stale. Update-in-place was the correct treatment, not Superseded.

**Resolution applied (Amendment A5):**

Edits to `docs/architecture/adr-0004-ui-framework.md`:

1. **Status line (§5)**: revised to state Gate 2 + Gate 4 CLOSED; remaining BLOCKING gates: Gate 1 (AccessKit property names) + Gate 3 (modal dismiss) + new Gate 5 (BBCode → AccessKit plain-text)
2. **Last Verified (§13)**: Amendment A5 entry added
3. **Engine Compatibility / Verification Required (§32)**: revised from 3 gates to 5 gates with explicit OPEN/CLOSED status per gate
4. **Decision item 1 (§91)**: `base_theme = preload(project_theme.tres)` → `fallback_theme = preload(project_theme.tres)` with property-correction note
5. **Architecture diagram (§118)**: `base_theme` → `fallback_theme`
6. **Theme inheritance pattern code comment (§236)**: corrected
7. **Implementation Guidelines item 6 (§247)**: `base_theme` → `fallback_theme`; Gate 2 hedge removed
8. **Risks table (§332)**: `base_theme` row marked CLOSED; new Gate 5 BBCode-to-AT row added
9. **Migration Plan §1 verification gates (§360)**: 3 gates → 5 gates with OPEN/CLOSED annotations
10. **Migration Plan step 6 (§368)**: `base_theme` → `fallback_theme`
11. **Validation Criteria checklist (§378)**: 3 entries → 5 entries with check marks for closed Gates 2 + 4

Architecture decision unchanged. Implementation guidance now accurate against Godot 4.6.

### ADR-0007 (Autoload Order Registry)

**Status:** ✅ Still Valid

**Assessment:** Overlay is NOT autoload (CR-13 unchanged). No ADR change needed.

### ADR-0008 (Performance Budget Distribution)

**Status:** ✅ Still Valid

**Assessment:** Slot 7 0.3 ms cap unchanged. The revisions added documented exceptions for cold-atlas first-open spike (F.1) and locale-change frame spike (F.2), but these are characterizations of the spike behavior — the underlying budget envelope is unchanged. ADR-0008 makes no specific claim about the absence of one-time spikes. The new OQ-DOV-COORD-14 (HUD Tween-on-InputContext-change) is a HUD Core GDD amendment, not an ADR-0008 amendment.

---

## Resolution Decisions

| ADR | Status | Action Taken | Owner | Date |
|---|---|---|---|---|
| ADR-0001 | ✅ Still Valid | None | — | — |
| ADR-0002 | ✅ Still Valid | None | — | — |
| ADR-0003 | ✅ Still Valid | None | — | — |
| ADR-0004 | ⚠️ Needs Review | **Update in place — Amendment A5 applied** | godot-specialist + accessibility-specialist (verifications); /propagate-design-change author | 2026-04-27 evening |
| ADR-0007 | ✅ Still Valid | None | — | — |
| ADR-0008 | ✅ Still Valid | None | — | — |

---

## ADRs to be Written or Updated as Follow-Up

None at the ADR level. The revision is fully absorbed by ADR-0004 Amendment A5.

The 3 NEW BLOCKING GDD-coordination items emerging from the revision (COORD-12 / 13 / 14) require **GDD amendments**, not new ADRs:

- **OQ-DOV-COORD-12**: `design/gdd/settings-accessibility.md` must add `text_scale_multiplier` setting (range [1.0, 2.0], default 1.0, step 0.25). FontRegistry consumes via `document_*()` getters at section-load. Required for WCAG SC 1.4.4 conformance.
- **OQ-DOV-COORD-13**: `tests/unit/helpers/call_order_recorder.gd` shared helper to be authored by tools-programmer + qa-lead pre-sprint; required for AC-DOV-1.1 / 2.1 / 4.1 / 5.2 verification.
- **OQ-DOV-COORD-14**: `design/gdd/hud-core.md` (or its OQ-HUD-3) must require HUD Tween kill/pause on `InputContext` change to non-GAMEPLAY. Otherwise Overlay's CR-14 "holds full Slot 7 cap alone" claim is invalidated.

---

## Cross-System Coordination Items (out of /propagate-design-change scope but documented for follow-up)

These are GDD-to-GDD coord items added by the revision; they do not affect ADRs but require amendments to other GDDs:

1. **Settings & Accessibility GDD** must add `text_scale_multiplier` knob (COORD-12).
2. **HUD Core GDD** / OQ-HUD-3 must require Tween-kill on InputContext change to non-GAMEPLAY (COORD-14).
3. **Localization Scaffold §Interactions** must add `overlay.*` namespace ownership row (COORD-5 amendment) and accept the new `translations/overlay.csv` file path.
4. **MLS GDD** must specify section-teardown order convention (Overlay's `_exit_tree()` runs before DC's, OR `InputContext.pop()` is idempotent on freed scenes — per E.21 amendment to OQ-DOV-COORD-3).
5. **`design/narrative/document-writer-brief.md`** §7.5 — already amended in same session (250-word ceiling).

---

## Verification

- [x] ADR-0004 Amendment A5 applied in-place (verified via `grep -n "base_theme" docs/architecture/adr-0004-ui-framework.md` — all remaining occurrences are in annotation/correction/struck-through contexts only)
- [x] Traceability index sixth review run appended (verdict PASS re-affirmed)
- [x] Design review log created at `design/gdd/reviews/document-overlay-ui-review-log.md`
- [x] Systems-index row 75 status updated to NEEDS REVISION
- [x] Writer brief §7.5 added (closes OQ-DOV-COORD-4)
- [ ] Document Overlay UI re-review — **DEFERRED** to fresh session per user decision (skip /design-review re-run; mark Approved later if revisions hold)
- [ ] Settings & Accessibility GDD amendment for `text_scale_multiplier` (COORD-12) — **OPEN, blocks WCAG SC 1.4.4 conformance**
- [ ] HUD Core GDD / OQ-HUD-3 amendment for Tween-on-InputContext-change (COORD-14) — **OPEN, blocks AC-DOV-9.2 / 9.2-bis verification**
- [ ] Godot 4.6 in-engine spike for ADR-0004 Gates 1 + 3 + 5 — **OPEN, blocks ADR-0004 Proposed → Accepted promotion**
- [ ] `tools/ci/check_forbidden_patterns_overlay.sh` + `tests/unit/helpers/call_order_recorder.gd` (COORD-11 + COORD-13) — **OPEN, sprint-day-1 tasks**

## Verdict

**COMPLETE** — change impact report saved. ADR-0004 Amendment A5 applied in-place. Architecture remains coherent. Re-running `/architecture-review` at next major architectural pass would re-affirm PASS verdict (the gate-list refinement does not regress any TR coverage).
