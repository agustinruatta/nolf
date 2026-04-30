# Story 004: Body rendering — tr(), Theme, FontRegistry, locale re-resolution

> **Epic**: Document Overlay UI
> **Status**: Blocked — BLOCKED: ADR-0004 is Proposed — run `/architecture-decision` to advance it (Gate 5 deferred to runtime AT testing). Unblock when ADR-0004 reaches Accepted.
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-overlay-ui.md`
**Requirement**: TR-DOU-008, TR-DOU-009, TR-DOU-010
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework)
**ADR Decision Summary**: ADR-0004 §Decision item 1 (Proposed) mandates Theme inheritance via `document_overlay_theme.tres` with `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")` (verified Gate 2 — `fallback_theme` is the correct Godot 4.x property). ADR-0004 §FontRegistry specifies `FontRegistry.document_header()` (American Typewriter Bold) and `FontRegistry.document_body()` (American Typewriter Regular) as the font retrieval path. ADR-0004 §IG11 specifies `RichTextLabel.append_text(tr(body_key))` as the initial render path — however GDD §C.8 / CR-8 OVERRIDES this: direct `.text = tr(body_key)` assignment is correct for both initial render AND re-resolution (to avoid `append_text` accumulation on re-resolve). See FP-OV-16.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (ADR-0004 Proposed; `Theme.fallback_theme` verified Gate 2; `RichTextLabel.text` vs `append_text` re-render behavior verified Gate E BLOCKING)
**Engine Notes**: `Theme.fallback_theme` confirmed as the correct property (Gate 2 closed 2026-04-27). `Node.AUTO_TRANSLATE_MODE_DISABLED` confirmed Godot 4.5+ (Gate D closed 2026-04-27). `NOTIFICATION_TRANSLATION_CHANGED` is stable Godot 4.0+. **Gate E (BLOCKING — promoted 2026-04-27)**: confirm in Godot 4.6 editor that `RichTextLabel.text = tr(body_key)` reassignment after locale change produces no doubled text, no BBCode leakage. Gate E must close before this story can be marked Done.

> **Post-cutoff risk**: `FontRegistry` is a project-defined static class (not a Godot builtin). Verify its `document_header()` and `document_body()` return types against the FontRegistry GDD/implementation, not training data.

**Control Manifest Rules (Presentation)**:
- Required: Theme inheritance uses `Theme.fallback_theme` (NOT `base_theme` — does not exist in Godot 4.x; verified Gate 2) — ADR-0004 Decision item 1
- Required: `tr(key)` called at render time and on `NOTIFICATION_TRANSLATION_CHANGED`; NEVER in `_ready()` or cached as resolved String (Localization Scaffold CR-9 + GDD CR-7 + FP-OV-4)
- Required: `RichTextLabel.text = tr(body_key)` for initial render AND re-resolve; NEVER `append_text(tr(body_key))` — FP-OV-16 (direct `.text` assignment with `bbcode_enabled=true` calls internal `clear()` + re-parse; `append_text` accumulates on re-resolve)
- Required: `NOTIFICATION_TRANSLATION_CHANGED` handler guards `_state == READING` before re-resolving; ignores notification in all other states (GDD CR-8)
- Forbidden: `var _body: String = tr(body_key)` or equivalent cached-resolved-value member (FP-OV-4)
- Forbidden: `BodyText.append_text(tr(body_key))` for initial render or re-resolve (FP-OV-16)
- Guardrail: first-render T_open ≤ 5 ms soft ceiling (Gate E target — requires FontRegistry.preload_font_atlas() at section-load per OQ-DOV-COORD-2 amendment)

---

## Acceptance Criteria

*From GDD `design/gdd/document-overlay-ui.md` §H.6 + §C.7 + §C.2, scoped to this story:*

- [ ] **AC-1** (TR-DOU-008): `document_overlay_theme.tres` at `src/ui/document_overlay/document_overlay_theme.tres` has `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")`. `DocumentCard`, `DocumentTitle`, `DocumentScroll` theme_type_variations are declared in `document_overlay_theme.tres` (StyleBoxFlat content deferred to art-director via OQ-DOV-COORD-7). The theme file is referenced by `DocumentOverlayUI.tscn`'s root CanvasLayer `theme` property.
- [ ] **AC-2** (TR-DOU-009): `FontRegistry.document_header()` is assigned to `TitleLabel`'s font (via Theme or direct node property) and `FontRegistry.document_body()` is assigned to `BodyText`'s font. Both calls occur at section-load time (or `_ready()`), NOT at every open — fonts do not change per-document.
- [ ] **AC-3** (TR-DOU-010 + FP-OV-4): GIVEN `document_overlay_ui.gd`, WHEN CI grep `fp_ov_4` runs (`grep -nE '\bvar\b\s+\w+(\s*:\s*String)?\s*:?=\s*tr\(' src/ui/document_overlay/document_overlay_ui.gd`), THEN zero matches. `_current_title_key` and `_current_body_key` are `StringName` variables (key-only; NOT resolved String values).
- [ ] **AC-4** (TR-DOU-010 + FP-OV-16): GIVEN `document_overlay_ui.gd`, WHEN CI grep `fp_ov_16` runs (`grep -n "BodyText\.append_text\|append_text(tr(" src/ui/document_overlay/`), THEN zero matches. Only `%BodyText.text = tr(_current_body_key)` is used for both initial render (open lifecycle step 6) and re-resolve (C.7 handler).
- [ ] **AC-5** (TR-DOU-010): GIVEN Overlay READING with cached keys, WHEN `_notification(NOTIFICATION_TRANSLATION_CHANGED)` fires, THEN `%TitleLabel.text == tr(_current_title_key)` in the new locale; `%BodyText.text == tr(_current_body_key)` (new locale, **no doubled text** — Gate E verification required); `%BodyScrollContainer.scroll_vertical == 0` (deliberate scroll reset per CR-8 RTL trade-off); focus returned to `%TitleLabel` via `grab_focus()`.
- [ ] **AC-6** (TR-DOU-010): GIVEN Overlay `_state == OPENING` (not READING), WHEN `NOTIFICATION_TRANSLATION_CHANGED` fires, THEN handler returns early (`_state != READING`); labels NOT updated (they will be set correctly at step 6 of open lifecycle using current locale at execution time).
- [ ] **AC-7** (TR-DOU-010): GIVEN document with `title_key = "doc.missing_key_xyz"` absent from CSV, WHEN open lifecycle step 6 calls `tr("doc.missing_key_xyz")`, THEN `TitleLabel.text == "doc.missing_key_xyz"` (key returned verbatim — graceful Godot TranslationServer fallback per GDD E.10); no push_error from Overlay.
- [ ] **AC-8** (TR-DOU-010): GIVEN `DismissHintLabel.auto_translate_mode == AUTO_TRANSLATE_MODE_ALWAYS`, WHEN the node is in-tree and locale changes, THEN engine auto-translates the label without Overlay intervention. CI verifies `TitleLabel` and `BodyText` have `AUTO_TRANSLATE_MODE_DISABLED`; `DismissHintLabel` has `AUTO_TRANSLATE_MODE_ALWAYS` (AC-DOV-6.6 from GDD).

---

## Implementation Notes

*Derived from ADR-0004 §Decision item 1, §FontRegistry, §IG11 (with FP-OV-16 override) + GDD §C.2, CR-7, CR-8:*

**Theme inheritance** (adds to Story 001's theme stub):

```gdscript
# document_overlay_theme.tres
# [ext_resource type="Theme" path="res://src/core/ui_framework/project_theme.tres" id="1"]
# [resource]
# fallback_theme = ExtResource("1")
# [theme_item_overrides]
# ... (art-director fills DocumentCard, DocumentTitle, DocumentScroll StyleBoxFlats)
```

**FontRegistry assignment in `_ready()`** (after group-registration and signal-connection):

```gdscript
func _ready() -> void:
    # ... (Stories 001-003 content) ...

    # ADR-0004 §FontRegistry — fonts are static for the session
    %TitleLabel.add_theme_font_override(&"font", FontRegistry.document_header())
    %BodyText.add_theme_font_override(&"font", FontRegistry.document_body())
    # FontRegistry.preload_font_atlas(["DocumentTitle", "DocumentBody", "DocumentFooter"])
    # ^ Coord OQ-DOV-COORD-2 amendment: required for open-frame T_open ≤ 5ms on Iris Xe
    # Add when FontRegistry.preload_font_atlas() API is confirmed by the FontRegistry epic
```

**`NOTIFICATION_TRANSLATION_CHANGED` handler** (GDD §C.7):

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _state == State.READING:
        # CR-8: re-resolve from cached keys; NOT from cached resolved strings (FP-OV-4)
        %TitleLabel.text = tr(_current_title_key)
        # Direct .text assignment with bbcode_enabled=true calls internal clear() + reparse
        # This is the idempotent re-render path — do NOT use append_text() here (FP-OV-16)
        %BodyText.text = tr(_current_body_key)
        # Scroll position resets to top — deliberate trade-off (CR-8 RTL trade-off)
        %BodyScrollContainer.scroll_vertical = 0
        # Re-grab focus so AT re-reads the heading (accessibility-specialist requirement)
        %TitleLabel.grab_focus()
        # Debounced AT re-announce (300ms trailing edge per §C.8 E.24 requirement)
        _restart_locale_announce_debounce()
```

**Why FP-OV-16 overrides ADR-0004 §IG11**: ADR-0004 §IG11 shows `append_text(tr(body_key))` in its illustrative code. GDD §C.7 + GDD CR-8 are explicit that `append_text` accumulates on re-resolve — calling it during `NOTIFICATION_TRANSLATION_CHANGED` would concatenate new-locale text to the old-locale text. The prose in GDD §C.7 is authoritative; ADR-0004 §IG11 illustrative code needs an annotation (analogous to the OQ-DOV-COORD-6 fix for §IG3). This is noted in the ADR dependency section above.

**Locale-announce debounce** (300ms trailing-edge per GDD §C.8 E.24): implement with a `Timer` node in the scene tree (`LocaleAnnounceDebounce`: `wait_time = 0.3`, `one_shot = true`). `_restart_locale_announce_debounce()` calls `.stop()` then `.start()`. On `timeout`, execute the assertive AT re-announce. Prevents mid-sentence AT interruption on burst `NOTIFICATION_TRANSLATION_CHANGED` (rare: reachable via debug locale switcher if its own debouncer is absent).

**`auto_translate_mode` scene file values** (Gate D closed — `Node.AUTO_TRANSLATE_MODE_*` verified Godot 4.5+):
- `TitleLabel`: `auto_translate_mode = 0` (`AUTO_TRANSLATE_MODE_DISABLED`) — text set programmatically in step 6
- `BodyText (RichTextLabel)`: `auto_translate_mode = 0` (`AUTO_TRANSLATE_MODE_DISABLED`) — text set programmatically in step 6
- `DismissHintLabel`: `auto_translate_mode = 1` (`AUTO_TRANSLATE_MODE_ALWAYS`) — static key, engine handles
- `ScrollHintLabel`: `auto_translate_mode = 1` (`AUTO_TRANSLATE_MODE_ALWAYS`) — static key, engine handles

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: scene node creation and `DocumentOverlayUI.tscn` structural layout
- Story 002: CI script that catches FP-OV-4 and FP-OV-16 violations (script exists already from Story 002; this story's ACs verify it fires correctly on the real implementation)
- Story 003: `tr()` calls at step 6 of the open lifecycle (they live in Story 003's `_on_document_opened`); this story adds only the `_notification` handler and Theme/FontRegistry wiring
- Story 005: dismiss lifecycle, `_close()` text-clear step
- Story 007: AccessKit `accessibility_description` full verification; NVDA/Orca screen-reader walkthroughs; Gate G (BBCode → plain text AT serialization)
- Post-VS: BBCode formatted body content in CSV (Gate G must close first); RTL scroll-position preservation on locale change (deferred per CR-8 prose)

---

## QA Test Cases

**AC-5 (NOTIFICATION_TRANSLATION_CHANGED re-resolution)**
- Given: Overlay READING; `_current_title_key = &"doc.test.title"`, `_current_body_key = &"doc.test.body"`; mock TranslationServer returns `"Title EN"` / `"Body EN"` for locale A, `"Titel DE"` / `"Text DE"` for locale B.
- When: switch mock locale to B, then fire `_notification(NOTIFICATION_TRANSLATION_CHANGED)`.
- Then: `TitleLabel.text == "Titel DE"`; `BodyText.text == "Text DE"` (Gate E: no doubled text — "Text DEBody EN" would be a FP-OV-16 violation via append); `BodyScrollContainer.scroll_vertical == 0`; `TitleLabel` received `grab_focus()`.
- Edge cases: locale fires twice in 300ms (debounce test): AT re-announce fires once at trailing edge, not twice.

**AC-6 (NOTIFICATION_TRANSLATION_CHANGED guard — non-READING state)**
- Given: Overlay `_state == OPENING` (or IDLE, CLOSING).
- When: `_notification(NOTIFICATION_TRANSLATION_CHANGED)`.
- Then: `TitleLabel.text` and `BodyText.text` unchanged from their values before the notification.

**AC-7 (missing translation key — graceful fallback)**
- Given: `_current_title_key = &"doc.missing_key_xyz"`; TranslationServer has no entry for this key.
- When: open lifecycle step 6 executes `tr(_current_title_key)`.
- Then: `TitleLabel.text == "doc.missing_key_xyz"` (Godot returns key verbatim); no push_error from Overlay.

**AC-3 + AC-4 (CI grep assertions)**
- Given: `tools/ci/check_forbidden_patterns_overlay.sh` (Story 002).
- When: run against `src/ui/document_overlay/document_overlay_ui.gd`.
- Then: FP-OV-4 grep (cached translation value) → zero matches; FP-OV-16 grep (append_text) → zero matches.
- Edge cases: confirm grep pattern catches `var _title: String = tr(key)` (typed) AND `var _title = tr(key)` (inferred String) — both are violations.

**AC-1 (Theme fallback)**
- Given: `document_overlay_theme.tres` loaded in GUT.
- When: `document_overlay_theme.fallback_theme` read.
- Then: returns the same `Theme` resource as `project_theme.tres` (identity check or path check).
- Edge cases: `base_theme` property does NOT exist (Godot 4.x); test must not reference it.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/document_overlay/body_rendering_test.gd` — must exist and pass (AC-5, AC-6, AC-7)
- `tools/ci/check_forbidden_patterns_overlay.sh` exit 0 on clean implementation (AC-3, AC-4)
- Gate E verification (BLOCKING): screenshot or profiler evidence that `RichTextLabel.text = tr(body_key)` produces no doubled text after locale change in Godot 4.6 editor — `production/qa/evidence/gate-e-richtext-rerender.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene scaffold with `TitleLabel`, `BodyText`, `DismissHintLabel` nodes), Story 002 (CI script for FP-OV-4 and FP-OV-16 checks), Story 003 (open lifecycle populates `_current_title_key` / `_current_body_key` which this story's `_notification` handler re-resolves)
- Unlocks: Story 007 (AccessKit announcement re-uses the re-resolve sequence; `_restart_locale_announce_debounce` is the hook)

## Open Questions

- **OQ-DOV-COORD-5 (BLOCKING)**: `translations/overlay.csv` must contain `overlay.dismiss_hint`, `overlay.scroll_hint`, `overlay.accessibility.dialog_name`, `overlay.accessibility.scroll_name` keys before Story 004 tests pass with real localized text (without it, labels show raw key strings). Localization Scaffold author must create this file.
- **Gate E (BLOCKING)**: Confirm in Godot 4.6 editor that `RichTextLabel.text = tr(body_key)` after locale change produces zero doubled text, zero BBCode leakage. This is required before this story can be marked Done.
- **Gate G (BLOCKING — NEW 2026-04-27)**: Confirm `RichTextLabel` with `bbcode_enabled = true` exposes parsed plain text (not raw BBCode) to AccessKit. If raw BBCode is exposed, body content using formatting tags (`[b]`, `[i]`, `[color]`) fails SC 1.3.1. This gate does not block this story's implementation but blocks shipping BBCode-formatted body content; document as known limitation until Gate G closes.
- **ADR-0004 §IG11 annotation needed**: ADR-0004 §IG11 illustrative code shows `append_text(tr(body_key))`. GDD §C.7 / FP-OV-16 override this. ADR-0004 §IG11 should be annotated "for re-resolve, use `text = tr(body_key)` not `append_text`" to prevent future regressions.
