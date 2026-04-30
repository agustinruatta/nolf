# Story 004: Subtitle renderer — period typography, layout, localization plumbing

> **Epic**: Dialogue & Subtitles
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 2-3 hours (M — Label config + Theme resource + layout spec + manual evidence screenshot)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/dialogue-subtitles.md`
**Requirement**: TR-DLG-003, TR-DLG-010, TR-DLG-011
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + typography + IG5 self-suppression + `auto_translate_mode`), ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**:
- ADR-0004: Subtitle consumes `project_theme.tres` with period typography (Courier Prime / Futura / DIN / American Typewriter per Art Bible 7B/8C and GDD §V.1). The `FontRegistry` static class provides typed getters for font substitution. `SubtitleLabel.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` is the mandatory localization pattern — raw `StringName` keys are assigned to `_label.text` and the engine resolves them automatically. NEVER assign `tr(key)` to a Label with this mode set (FP-DS-18 double-translation trap). ADR-0004 §IG5 self-suppression rule is already implemented in Story 003 — this story configures the visual renderer that Story 003's suppression controls.
- ADR-0007: `FontRegistry` is a **static class, not an autoload** (per ADR-0004 Summary — eliminates anti-pattern concern). D&S calls `FontRegistry.get_caption_font(size_px)` at layout time; no autoload slot consumed.

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM
**Engine Notes**: `Label.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` is a Godot 4.5+ API (post-LLM-cutoff) — verified closed per ADR-0004 Gate 4 (Node.AUTO_TRANSLATE_MODE_* enum identifiers confirmed). `Label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` is stable 4.0+. `CanvasLayer` layer property and `PRESET_BOTTOM_CENTER` anchor are stable 4.0+. VG-DS-2 (`accessibility_live` property name on Label in 4.6 for AccessKit live-region) is OPEN — the AccessKit `accessibility_name` composition is implemented in this story but uses the verified `accessibility_description` property name per ADR-0004 Gate 1 CLOSED. The `accessibility_live` polite announcement is deferred pending VG-DS-2 in-editor verification (GDD §C.12, J.2 fallback documented). VG-DS-1 (`auto_translate_mode = ALWAYS` re-resolves on locale switch) is ADVISORY and should be verified during this story's implementation (~5 min in-editor check).

**ADR-0004 (Proposed — G5 deferred)**: This story uses plain `Label`, not `RichTextLabel` (FP-DS-15). BBCode formatting is explicitly forbidden for captions. G5 (BBCode→AccessKit) is irrelevant to this story. The plain Label approach is not affected by the G5 deferral.

**Control Manifest Rules (Feature layer + Presentation)**:
- Required: `Label.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` — raw key assignment to `_label.text` only (ADR-0004 / CR-DS-5)
- Required: `SubtitleCanvasLayer` at layer = 2 (ADR-locked constant from GDD §G.4)
- Required: `Label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` (GDD §C.3)
- Required: Anchor `PRESET_BOTTOM_CENTER`, 96 px vertical offset, max-width 62% / 896 px (GDD §V.4)
- Required: `corner_radius = 0` for all StyleBoxFlat modes — hard-edge rect per §B.3 refusal #1 (GDD §V.2)
- Forbidden: `RichTextLabel` for captions — pattern `RichTextLabel_for_subtitle` (FP-DS-15)
- Forbidden: `_label.text = tr(key)` with `auto_translate_mode = ALWAYS` — double-translation trap (FP-DS-18)
- Forbidden: drop shadow, glow, bloom, text outline on caption text (FP-V-DS-1)
- Forbidden: karaoke / per-word highlighting / animated entry or exit (FP-DS-5, FP-DS-7)
- Forbidden: chyron bar, avatar portrait, speaker headshot (FP-DS-6, FP-V-DS-2, FP-V-DS-3)
- Forbidden: proximity-based opacity or scale on caption region (FP-DS-19, FP-V-DS-6)

---

## Acceptance Criteria

*From GDD `design/gdd/dialogue-subtitles.md` §H.6 Settings Integration, §H.7 Localization, §H.11 Forbidden Patterns, §H.12 Visual/Layout, scoped to VS:*

- [ ] **AC-1** (from AC-DS-7.1): GIVEN a `DialogueLine` with `text_key = &"vo.bqa.briefing.opening"`, WHEN step 5 of CR-DS-2 executes, THEN `_label.text` is assigned the raw string `"vo.bqa.briefing.opening"` — NOT `tr("vo.bqa.briefing.opening")` — with `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` performing the resolution. Verified by `grep -n "= tr(" dialogue_and_subtitles.gd` returning zero matches (AC-DS-11.2).
- [ ] **AC-2** (from AC-DS-12.1): GIVEN the game running at 1280×720 and 1920×1080 at `subtitle_size_scale = 1.0`, WHEN a two-line caption renders, THEN the caption region does not overlap the Health widget (bottom-left) or Weapon widget (bottom-right). Screenshot evidence filed at `production/qa/evidence/subtitle-layout-[res]-[date].png`.
- [ ] **AC-3** (from AC-DS-12.2): GIVEN the StyleBox applied to the caption in `scrim` and `opaque` modes, WHEN properties inspected in-editor, THEN `corner_radius_top_left / top_right / bottom_left / bottom_right` are all `0` for both modes.
- [ ] **AC-4** (from AC-DS-12.3): GIVEN the caption rendering on three different scene backgrounds, WHEN a visual reviewer inspects, THEN no drop shadow, glow, bloom, or text outline appears on caption text in any mode. Screenshot evidence filed at `production/qa/evidence/subtitle-visual-[date].png`.
- [ ] **AC-5** (from AC-DS-6.1): GIVEN `Settings.subtitles_enabled = false`, WHEN a bark lifecycle runs, THEN `dialogue_line_started` fires, `_audio_player.play()` is called, audio completes, `dialogue_line_finished` fires, AND `_label.text` is never assigned (remains `""`).
- [ ] **AC-6** (from AC-DS-11.1): GIVEN `src/`, WHEN CI runs `grep -rn --exclude-dir=tests "RichTextLabel" src/ | grep -i "subtitle\|caption\|dialogue"`, THEN zero matches.
- [ ] **AC-7** (from AC-DS-11.2): GIVEN `dialogue_and_subtitles.gd`, WHEN CI runs `grep -n "= tr(" dialogue_and_subtitles.gd`, THEN zero matches (raw key assignment only, FP-DS-18).
- [ ] **AC-8** (from AC-DS-11.5): GIVEN `src/`, WHEN CI runs `grep -rn --exclude-dir=tests "modulate.a\|\.scale" src/ | grep -i "subtitle\|caption"`, THEN zero matches (no proximity-based opacity or scale).
- [ ] **AC-9**: `SubtitleCanvasLayer.layer` property equals `2` (ADR-locked — above HUD Core layer 1, below Document Overlay layer 5).
- [ ] **AC-10**: Translation key `dlg.bqa.briefing.opening` (VS line scope) is registered in the localization CSV at `assets/data/localization/vo_strings.en.csv` (or equivalent project CSV path). The key resolves to a non-empty English string. This is the minimum viable localization registration per VS scope guidance.

---

## Implementation Notes

*Derived from ADR-0004 §Implementation Guidelines + GDD §C.3, §C.10, §C.12, §V.1–V.4:*

`SubtitleLabel` configuration (GDD §C.3 + §V.1 + §V.4):

```gdscript
# In the .tscn scene file or _ready():
_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
# Anchor: PRESET_BOTTOM_CENTER
# Offset from bottom: 96 px at 1080p (scaled: 96 * viewport_height / 1080.0)
# Max width: min(viewport_width * 0.62, 896.0) px
```

Label assignment pattern (CR-DS-5 / FP-DS-18):

```gdscript
# CORRECT — raw key; engine resolves via auto_translate_mode:
_label.text = String(line.text_key)

# FORBIDDEN — double-translation trap:
# _label.text = tr(line.text_key)  <- NEVER DO THIS
```

Theme resource: Subtitle inherits from `project_theme.tres`. A dedicated `subtitle_theme.tres` override registers:
- Font: Courier Prime Regular 28px at 1.0 scale (substitute system Courier for prototype; Courier Prime for final ship per §V.1)
- `DIN 1451 Engschrift` fallback if Courier < 18px per ADR-0004 FontRegistry floor rule (Art Bible 7B/8C)
- Color: Off-white `#F2EFE6` (caption text)
- StyleBoxFlat `scrim`: fill `#1A1A1A`, alpha 0.55, corner_radius all 0, padding 8px/6px
- StyleBoxFlat `opaque`: fill `#1A1A1A`, alpha 0.95, corner_radius all 0, padding 8px/6px

Settings integration (`setting_changed` signal from Story 002's orchestrator context):
- `subtitles_enabled`: CR-DS-11 already handled in Story 002 (label assignment gated)
- `subtitle_size_scale`: updates `SubtitleLabel` theme font-size override immediately on `setting_changed("subtitle_size_scale", value)` — GDD §E Cluster H.2 (no lifecycle restart needed; Label reflows automatically)
- `subtitle_background`: toggles the active StyleBox between `none` (no backplate), `scrim`, `opaque` modes
- VS scope: `subtitle_speaker_labels` setting consumption deferred to post-VS (plain label body only in VS)

AccessKit (§C.12 — partial implementation):
- `accessibility_description` is the verified property name per ADR-0004 Gate 1 CLOSED (NOT `accessibility_role` — role is inferred from node type)
- `accessibility_live` property name is UNVERIFIED (VG-DS-2 OPEN) — implement J.3 mitigation only: no placeholder `accessibility_live` assignment with guessed string value; add a TODO comment noting VG-DS-2 must be resolved before AccessKit live-region ships
- `accessibility_description` can be set to the resolved speaker+text composition for SR equity without VG-DS-2: `accessibility_description = tr(line.speaker_label_key) + tr(&"vo.speaker.delimiter") + tr(line.text_key)` for non-anonymous speakers

Localization CSV registration: `dlg.bqa.briefing.opening = "Sterling. The Plaza opening. Try not to draw attention."` added to the VS localization CSV. Additional VS line keys (`dlg.plaza.guard.curiosity_bait_radiator_a`, `dlg.plaza.guard_b.brochure_stand`, etc.) registered here to validate the `tr()` pipeline end-to-end.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Signal declarations, `DialogueLine` schema (must be DONE)
- Story 002: Orchestrator lifecycle — label assignment (`_label.text = String(line.text_key)`) lives in Story 002's CR-DS-2 step 5, which this story only configures the Label mode for
- Story 003: `_caption_suppressed` flag, suppression handlers — already done; this story extends the label configuration only
- Story 005: End-to-end integration smoke (uses the fully configured renderer)
- Post-VS: Speaker label rendering (`subtitle_speaker_labels` full implementation with CR-DS-16 formatted composition); AccessKit `accessibility_live` polite live-region (pending VG-DS-2); `NOTIFICATION_TRANSLATION_CHANGED` manual fallback (pending VG-DS-1 outcome); XL=2.0 scale preset verification at all resolutions (AC-DS-12.6 full coverage); per-section `subtitle_background = opaque` overrides (AC-DS-12.5 QA gate); WCAG SC 1.4.12 word-spacing (unaddressed post-MVP)

---

## QA Test Cases

**AC-1 — Raw key assignment + forbidden tr() pattern**
- **Setup**: Loaded Plaza section; BQA briefing `DialogueLine` with `text_key = &"dlg.bqa.briefing.opening"` triggers
- **Verify**: In-game caption shows resolved English string "Sterling. The Plaza opening. Try not to draw attention." (engine resolved via `auto_translate_mode = ALWAYS`); source-grep confirms no `= tr(` on `_label` assignment in `dialogue_and_subtitles.gd`
- **Pass condition**: Caption renders correct English text; grep returns zero matches

**AC-2 — Layout clearance (no HUD overlap)**
- **Setup**: Game running at 1280×720 with default settings; trigger a two-line caption
- **Verify**: Caption region (62% width, 96px bottom offset) does not overlap Health widget (bottom-left, HUD Core) or Weapon widget (bottom-right, HUD Core)
- **Pass condition**: No pixel overlap visible in screenshot; screenshot filed at `production/qa/evidence/subtitle-layout-720p-[date].png`. Repeat at 1920×1080. Screenshots filed.

**AC-3 — Hard-edge StyleBox (no rounded corners)**
- **Setup**: Caption visible in both `scrim` and `opaque` modes
- **Verify**: In-editor Inspector on StyleBoxFlat shows `corner_radius_*` all equal 0 for both modes; visually confirms rectangular backplate (no rounded corners)
- **Pass condition**: Inspector values confirmed 0; no visual rounding visible

**AC-4 — No drop shadow / glow / outline**
- **Setup**: Caption rendering on a bright-field scene background (worst-case contrast)
- **Verify**: Caption text has no glow, no drop shadow, no text outline on any background — scrim backplate is the only contrast element
- **Pass condition**: Visual inspection + screenshot filed at `production/qa/evidence/subtitle-visual-[date].png`

**AC-5 — subtitles_enabled = false path**
- **Setup**: Set `Settings.subtitles_enabled = false` in test double; trigger full bark lifecycle
- **Verify**: `Events.dialogue_line_started` spy fires; `AudioLinePlayer.play()` spy fires; audio completes; `Events.dialogue_line_finished` fires; `_label.text` remains `""` throughout
- **Pass condition**: All signal spies fire in correct order; label never assigned

**AC-6 — No RichTextLabel grep**
- **Setup**: Full `src/` tree
- **Verify**: `grep -rn --exclude-dir=tests "RichTextLabel" src/ | grep -i "subtitle\|caption\|dialogue"` returns zero matches
- **Pass condition**: Zero output

**AC-7 — No tr() grep**
- **Setup**: `dialogue_and_subtitles.gd`
- **Verify**: `grep -n "= tr(" dialogue_and_subtitles.gd` returns zero matches
- **Pass condition**: Zero output

**AC-10 — Localization key registration**
- **Setup**: `assets/data/localization/vo_strings.en.csv` (or equivalent) loaded in Godot
- **Verify**: `TranslationServer.translate("dlg.bqa.briefing.opening")` returns `"Sterling. The Plaza opening. Try not to draw attention."` (not a MISSING: key)
- **Pass condition**: Non-empty string returned without MISSING: prefix

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/subtitle-layout-720p-[date].png` — two-line caption at 1280×720, no HUD overlap
- `production/qa/evidence/subtitle-layout-1080p-[date].png` — same at 1920×1080
- `production/qa/evidence/subtitle-visual-[date].png` — caption on bright background, no shadow/glow/outline
- `production/qa/evidence/subtitle-ui-evidence-[date].md` — lead sign-off checklist (AC-2, AC-3, AC-4)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 DONE (suppression visibility state machine must be in place before renderer is configured, to avoid testing label visibility in isolation from suppression)
- Unlocks: Story 005 (Plaza smoke requires renderer to be complete for visual subtitle verification)
