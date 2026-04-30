# Story 001: CanvasLayer scene root scaffold + Theme resource + FontRegistry wiring

> **Epic**: HUD Core
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 2–3 hours (S — scene scaffold, .tres file, static-class calls, no logic)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-core.md`
**Requirement**: TR-HUD-001, TR-HUD-005, TR-HUD-006, TR-HUD-007, TR-HUD-008
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry)
**ADR Decision Summary**: HUD Core is a `CanvasLayer`-rooted scene (layer index 1, within the 0..3 HUD range reserved by ADR-0004 §IG7). It is NOT an autoload. It inherits `project_theme.tres` via `hud_theme.tres` (each surface Theme sets `fallback_theme = preload(project_theme.tres)` — property confirmed as `fallback_theme`, NOT `base_theme`, per ADR-0004 Gate 2 closure). All numeric Labels call `FontRegistry.hud_numeral(physical_size_px)` — static class, not an autoload — encapsulating the Futura Condensed Bold → DIN 1451 Engschrift substitution at the 18 px size floor (Art Bible §7B/§8C). All visible strings route through `tr()`. Every Control sets `mouse_filter = MOUSE_FILTER_IGNORE` and `focus_mode = FOCUS_NONE` (ADR-0004 §IG8 + Godot 4.6 dual-focus split exemption, GDD CR-2 §C.2 annotation).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: ADR-0004 status is Proposed — Gates G3, G4, G5 deferred to runtime AT post-MVP (G5 = BBCode→AccessKit serialization for Document Overlay; does NOT block plain-text HUD Labels). For this story, the following Godot 4.6 APIs require verification before implementation (OQ-HUD-6 batch from GDD §C.5 Coord item 5, flagged BLOCKING before sprint): `Theme.fallback_theme` property name (CLOSED — Gate 2 verified); `set_anchors_preset(Control.PRESET_FULL_RECT)` method form vs property assignment (property form is silent no-op in Godot 4.6 — use the method); `Control.focus_mode = Control.FOCUS_NONE` default for Label (must be set explicitly per godot-specialist Finding 8); `StyleBoxFlat.corner_radius_top_left / _top_right / _bottom_left / _bottom_right` (all four set individually; no wildcard shorthand). `TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL` enum prefix — used in Story 001 only for gadget tile (deferred post-VS, but the enum verification is needed for the defer documentation). AccessKit `accessibility_role` is inferred from node type in Godot 4.6 — NOT a settable property (ADR-0004 Gate 1 finding).

> "This API may have changed between Godot 4.3 and 4.6 — verify against the engine-reference docs before using `set_anchors_preset()` and `StyleBoxFlat` property names."

**Control Manifest Rules (Presentation)**:
- Required: every HUD `Control` sets `mouse_filter = MOUSE_FILTER_IGNORE` AND `focus_mode = Control.FOCUS_NONE` — HUD is exempt from Godot 4.6 dual-focus split (ADR-0004 §IG8)
- Required: surface Theme sets `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")` — verified property name (ADR-0004 Gate 2)
- Required: all visible strings via `tr()` from day one (ADR-0004 §IG9)
- Required: `FontRegistry.hud_numeral(physical_size_px)` called once per numeric Label at `_ready()` and on `viewport.size_changed` (CR-19)
- Required: `set_anchors_preset(Control.PRESET_FULL_RECT)` method form — NOT the `anchors_preset =` property assignment (silent no-op in Godot 4.6 per godot-specialist verification)
- Forbidden: `hud_subscribing_to_internal_state` — HUD polls no system state other than 2 authorised PC accessors (CR-3)
- Forbidden: `hud_pushing_visibility_to_other_ui` — HUD never pushes `visible` to sibling CanvasLayers or modal surfaces (ADR-0004 §IG5); subscribers manage own visibility via signal subscriptions
- Forbidden: HUD as autoload — FP-13 (ADR-0007 slot table is full; HUD is per-main-scene CanvasLayer)
- Guardrail: Slot 7 = 0.3 ms cap (ADR-0008) — this story has no `_process` cost; budget concern is deferred to Story 004

---

## Acceptance Criteria

*From GDD `design/gdd/hud-core.md` §C.1–§C.2, §V.1–§V.3, §H.0–§H.1, TR-HUD-001/005/006/007/008:*

- [ ] **AC-1** (TR-HUD-001): `src/ui/hud_core/hud_core.tscn` exists with a `CanvasLayer` root node, `layer = 1` (within ADR-0004 §IG7 range [0..3] for HUD). The root's GDScript file declares `class_name HUDCore extends CanvasLayer`. The scene is NOT registered as an autoload in `project.godot` (FP-13).

- [ ] **AC-2** (TR-HUD-005): `src/core/ui_framework/themes/hud_theme.tres` exists as a `Theme` resource with `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")`. It defines the four `StyleBoxFlat` backgrounds specified in GDD §V.1: `health_bg` (BQA Blue `#1B3A6B` 85% opacity, 6 px L/R + 4 px T/B margins, zero corner radius), `weapon_ammo_bg` (mirrored geometry), `prompt_bg` (8 px H + 3 px V margins), and `key_rect` (transparent fill, 1 px Parchment `#F2E8C8` border, 3 px L/R + 1 px T/B margins). All four `corner_radius_*` properties are set to `0` individually (no rounded corners — Art Bible §3.3).

- [ ] **AC-3** (TR-HUD-006): The HUD root scene's `_ready()` calls `FontRegistry.hud_numeral(int(round(design_size_px * scale_factor)))` for each numeric Label (health numeral at design 22 px, weapon-name label at 13 px, consolidated ammo label at 22 px, prompt-strip label at 14 px) and caches the result. The `scale_factor` is computed per F.3: `clamp(viewport.size.y / 1080.0, 0.667, 2.0)`. At 1080p with design 22 px: `FontRegistry.hud_numeral(22)` returns Futura Condensed Bold. At 720p: `FontRegistry.hud_numeral(int(round(22 * 0.667)))` = `FontRegistry.hud_numeral(15)` returns DIN 1451 Engschrift (below 18 px floor). This is verified by a unit test asserting the returned Font type at boundary sizes.

- [ ] **AC-4** (TR-HUD-007): Every visible Label in the scene that holds translatable text initialises its `.text` via `tr("KEY")` in `_ready()`. Static labels (e.g., `"HP"` abbreviation) are cached in `_ready()`. No raw GDScript string literal is assigned to any Label's `.text` property. Grep pattern `\.text\s*=\s*"` on `src/ui/hud_core/**/*.gd` returns zero matches (AC-HUD-11.3).

- [ ] **AC-5** (TR-HUD-008): Every `Control` node in the HUD scene tree (root `CanvasLayer`, widget `MarginContainer`s, `HBoxContainer`s, `VBoxContainer`s, `Label`s, `PanelContainer`s, crosshair `Control` subclass) has `mouse_filter = MOUSE_FILTER_IGNORE` AND `focus_mode = Control.FOCUS_NONE` set in `_ready()` (or in the scene file). The root `Control` child also sets `set_meta("focus_disabled_recursively", true)` per GDD §C.2 dual-focus exemption annotation (exact API name pending ADR-0004 Gate 1 closure — document as a placeholder comment if unverified).

- [ ] **AC-6** (TR-HUD-001 + structural): The widget tree structure matches GDD §V.3 for the four placeholder widgets: Health field (BL — `MarginContainer → HBoxContainer → Label "HP" + Label numeral`), Weapon+Ammo field (BR — `MarginContainer → VBoxContainer → Label weapon_name + Label ammo_combined`), Gadget tile (TR — placeholder `PanelContainer` with correct `ANCHOR_PRESET_TOP_RIGHT`), and Prompt-strip (CB — `CenterContainer → MarginContainer → HBoxContainer → Label prompt_text + PanelContainer key_rect`). Crosshair `Control` subclass is present but renders nothing until Story 003/004. All widgets use `set_anchors_preset(Control.PRESET_*)` method form (not property assignment).

- [ ] **AC-7** (all): Manual walkthrough: launch the Plaza VS scene with HUD Core instanced. The four corner regions show the correct BQA Blue `#1B3A6B` 85% panels with no rounded corners, no drop shadows, no floating damage numbers, no objective markers, no minimap. Screenshot captured to `production/qa/evidence/hud_core/screenshot_scaffold_<date>.png`.

---

## Implementation Notes

*Derived from ADR-0004 §Implementation Guidelines + GDD §C.1–§C.2 + §V.1–§V.3:*

**File structure for this story:**

```
src/ui/hud_core/
├── hud_core.gd           (class_name HUDCore extends CanvasLayer)
├── hud_core.tscn         (scene root: CanvasLayer layer=1; child: Control widget root)
└── crosshair_widget.gd   (class_name CrosshairWidget extends Control — stub only; _draw() deferred to Story 003)

src/core/ui_framework/themes/
└── hud_theme.tres        (Theme; fallback_theme = project_theme.tres; StyleBoxFlat entries)
```

**CanvasLayer setup**: `layer = 1`. The scene is instanced by the main game scene, not added to autoloads. Per GDD CR-10, initial visibility is set in `_ready()` via a single `InputContext.current()` read: `visible = (InputContext.current() == InputContext.Context.GAMEPLAY)`. This is the ONLY permitted read of `InputContext.current()` outside a signal handler.

**`hud_theme.tres` authoring (GDD §V.1)**: every `StyleBoxFlat` is a `.tres` sub-resource embedded in the Theme file. All four `corner_radius_*` properties must be set individually (`corner_radius_top_left`, `corner_radius_top_right`, `corner_radius_bottom_left`, `corner_radius_bottom_right`) — verified property names from Godot 4.6 inspector. The `Color("#1B3A6B", 0.85)` constructor form: if the 2-argument `Color(hex, alpha)` form is unverified on Godot 4.6 (OQ-HUD-6 item 1), use `Color(0x1B3A6B_packed).with_alpha(0.85)` or the 4-float form `Color(0.106, 0.227, 0.420, 0.85)` as the fallback.

**FontRegistry calls**: called in `_update_hud_scale()` method, which is invoked at `_ready()` and connected to `get_viewport().size_changed` signal (1 viewport connection per CR-1(D)). Method form: `FontRegistry.hud_numeral(int(round(design_size_px * scale_factor)))` per CR-19. This is the scale-aware form corrected in REV-2026-04-25 — the design size alone is NOT passed.

**`_process` is NOT implemented in this story.** The prompt-strip resolver (`_process`) is Story 004. The damage-flash logic is Story 003. This story delivers scene structure and theme resources only.

**Forbidden-pattern documentation**: the CI grep fences from AC-HUD-10.x are implemented in Story 002 (forbidden-pattern test file). This story produces only the scene and theme files that the fences will validate.

**ADR-0004 G3/G4/G5 non-blocking**: G3 (`_unhandled_input` + `ui_cancel`) and G4 (`AUTO_TRANSLATE_MODE_*`) are not relevant to HUD Core (HUD never dismisses via `ui_cancel`; HUD uses `tr()` but not `AUTO_TRANSLATE_MODE_*`). G5 (BBCode→AccessKit) applies to Document Overlay, not HUD Labels. All three gates are non-blocking for this story.

**Pillar 5 visual restraint (GDD §V.7)**: the theme file must not define any rounded corners, shadow properties, drop shadow colours, or expand margins. Art Bible §3.3 hard-edged rectangles throughout. A code-review checklist item: inspect `hud_theme.tres` for any `shadow_size > 0` or `corner_radius_* > 0` — both must be zero.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: Signal subscription lifecycle (all 14 `connect`/`disconnect` calls, forbidden-pattern grep fences)
- **Story 003**: Health widget logic (critical-state edge trigger, damage flash, Tween kill, `player_health_changed` handler)
- **Story 004**: Interact prompt strip state machine (`_process` resolver, PC query injection, `get_prompt_label()` extension hook)
- **Story 005**: Photosensitivity rate-gate, settings live-update wiring (`setting_changed` subscription and dispatch)
- Post-VS deferrals: ammo widget logic, gadget tile logic, crosshair `_draw()` implementation, context-hide Tween.kill() wiring

---

## QA Test Cases

**AC-1 — CanvasLayer scene root structural check**
- Setup: Open `src/ui/hud_core/hud_core.tscn` in Godot 4.6 editor; inspect root node properties
- Verify: Root node type is `CanvasLayer`; `layer` property is `1`; GDScript attached is `hud_core.gd` declaring `class_name HUDCore extends CanvasLayer`; no entry appears in `project.godot [autoload]` for HUD Core
- Pass condition: All four checks pass; CI `grep "hud_core" project.godot` returns zero matches in the `[autoload]` block

**AC-2 — hud_theme.tres StyleBoxFlat entries**
- Setup: Load `hud_theme.tres` in Godot 4.6 editor; inspect each StyleBoxFlat sub-resource
- Verify: `health_bg` StyleBoxFlat has `bg_color = Color(#1B3A6B, 0.85)`, `content_margin_left = 6`, `content_margin_right = 6`, `content_margin_top = 4`, `content_margin_bottom = 4`, all `corner_radius_* = 0`, all `border_width_* = 0`; `key_rect` has `bg_color = Color(0,0,0,0)`, `border_color = Color(#F2E8C8, 1.0)`, all `border_width_* = 1`, all `corner_radius_* = 0`
- Pass condition: All values match §V.1 exactly; no rounded corners; no shadow properties non-zero

**AC-3 — FontRegistry.hud_numeral boundary test**
- Setup: `tests/unit/presentation/hud_core/test_font_registry_scale.gd`
- Verify: At `scale_factor = 1.0`, `FontRegistry.hud_numeral(22)` returns the Futura Condensed Bold font object; at `scale_factor = 0.667`, `FontRegistry.hud_numeral(int(round(22 * 0.667)))` = `FontRegistry.hud_numeral(15)` returns DIN 1451 Engschrift (below 18 px floor)
- Pass condition: Both assertions pass; test is deterministic (no randomness; `scale_factor` fixed in test)
- Edge cases: Design size exactly `int(round(X * factor)) == 18` → returns Futura (boundary is `< 18`, not `<= 18`)

**AC-4 — No hardcoded string literals in Label.text assignments**
- Setup: `tests/unit/presentation/hud_core/test_forbidden_patterns.gd` grep gate
- Verify: Pattern `\.text\s*=\s*"` on `src/ui/hud_core/**/*.gd` (excluding `tests/`) returns zero matches
- Pass condition: Zero grep matches
- Edge cases: Comments containing `.text = "..."` must be excluded; the grep must skip comment lines (use `grep -v "^\s*#"` pre-filter)

**AC-5 — mouse_filter + focus_mode coverage**
- Setup: Manual scene inspection in Godot 4.6 editor; check every Control node in `hud_core.tscn`
- Verify: Each Control (root CanvasLayer child, all containers, all Labels, PanelContainers, CrosshairWidget) has `mouse_filter = MOUSE_FILTER_IGNORE` and `focus_mode = FOCUS_NONE`
- Pass condition: No Control in the HUD scene tree can receive mouse input or keyboard focus

**AC-6 — Widget tree structure**
- Setup: Open `hud_core.tscn` in Godot editor scene tree; compare to GDD §V.3 render tree diagrams
- Verify: BL widget = `MarginContainer → HBoxContainer → [Label "HP", Label numeral]` with `ANCHOR_PRESET_BOTTOM_LEFT`; BR widget = `MarginContainer → VBoxContainer → [Label weapon_name, Label ammo_combined]` with `ANCHOR_PRESET_BOTTOM_RIGHT`; CB widget = `CenterContainer → MarginContainer → HBoxContainer → [Label prompt_text, PanelContainer key_rect → Label key_str]` with `ANCHOR_PRESET_CENTER_BOTTOM`
- Pass condition: Tree structure matches §V.3; `set_anchors_preset()` method is used (not property assignment)

**AC-7 — Visual walkthrough screenshot**
- Setup: Launch Plaza VS scene with HUD Core instanced; set health=100, no weapon, no gadget
- Verify: Four BQA Blue `#1B3A6B` 85% strips visible at corners; no rounded corners; no shadows; no floating damage numbers, no minimap, no objective markers; crosshair placeholder not visible (disabled by default until Settings emits first value)
- Pass condition: Screenshot at `production/qa/evidence/hud_core/screenshot_scaffold_<date>.png` shows correct layout; Art Director (or solo developer) signs off via note in evidence file

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `tests/unit/presentation/hud_core/test_font_registry_scale.gd` — must exist and pass (AC-3)
- `tests/unit/presentation/hud_core/test_forbidden_patterns.gd` — grep gate for AC-4 (string literals); Story 002 expands this file with all other forbidden-pattern checks
- `production/qa/evidence/hud_core/screenshot_scaffold_<date>.png` — manual walkthrough evidence (AC-7)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `src/core/ui_framework/project_theme.tres` must exist (ADR-0004 Theme scaffold — part of the ui-framework epic or pre-existing); `src/core/ui_framework/font_registry.gd` (`FontRegistry` static class) must be accessible
- Unlocks: Story 002 (signal subscription lifecycle needs the scene node tree to connect signals to), Story 003 (health widget logic needs the scene scaffold), Story 004 (prompt-strip state machine needs the Label node from this story's tree)
