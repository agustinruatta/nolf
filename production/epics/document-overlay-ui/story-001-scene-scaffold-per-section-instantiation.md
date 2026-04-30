# Story 001: Scene scaffold + per-section instantiation guard

> **Epic**: Document Overlay UI
> **Status**: Blocked — BLOCKED: ADR-0004 is Proposed — run `/architecture-decision` to advance it (Gate 5 deferred to runtime AT testing). ADR-0008 is Proposed — same rule. Unblock when both reach Accepted.
> **Layer**: Presentation
> **Type**: Integration
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/document-overlay-ui.md`
**Requirement**: TR-DOU-001, TR-DOU-011, TR-DOU-013
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Autoload Load Order Registry) + ADR-0004 (UI Framework)
**ADR Decision Summary**: ADR-0007 §Accepted confirms the autoload registry is full at slot 9 (MLS); Document Overlay UI is therefore NOT autoload — it is a per-section `CanvasLayer` scene instantiated by Mission & Level Scripting. ADR-0004 §IG7 (Proposed) locks the CanvasLayer index at 5, between Post-Process Stack sepia at 4 and Pause Menu at 8.

**Engine**: Godot 4.6 | **Risk**: LOW (ADR-0007 Accepted; ADR-0004 CanvasLayer index registry LOW-risk)
**Engine Notes**: `CanvasLayer.layer` is stable Godot 4.0+. `PROCESS_MODE_ALWAYS` on a Control node is stable. `get_tree().get_nodes_in_group()` / `add_to_group()` are stable. No post-cutoff API surface in this story. ADR-0004 is Proposed; the CanvasLayer-index clause (§IG7) is the only ADR-0004 dependency here — the scene scaffold itself does not yet wire signals or InputContext (those are Stories 003–005).

**Control Manifest Rules (Presentation)**:
- Required: Presentation layer — scene must be a CanvasLayer node, NOT autoload (ADR-0007 IG 1 + ADR-0004 §IG7)
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3) — applies to the group-registration pattern here; signal connections come in later stories
- Required: static typing on all GDScript; doc comments on public APIs (coding-standards.md)
- Forbidden: `Engine.register_singleton()` at runtime (ADR-0007 IG 5); `add_autoload_singleton()` without ADR-0007 amendment (IG 6)
- Forbidden: `_process` / `_physics_process` active in IDLE state — set `set_process(false)` / `set_physics_process(false)` in `_ready()` (GDD CR-15)
- Guardrail: CanvasLayer index 5 is locked; DO NOT change without ADR-0004 amendment (GDD §G.4)

---

## Acceptance Criteria

*From GDD `design/gdd/document-overlay-ui.md`, scoped to this story:*

- [ ] **AC-1** (TR-DOU-001): `DocumentOverlayUI.tscn` exists at `src/ui/document_overlay/DocumentOverlayUI.tscn`. Root node is `CanvasLayer` with `layer = 5`. Scene tree matches GDD §C.2 hierarchy: `DocumentOverlayUI (CanvasLayer)` → `ModalBackdrop (Control)` → `CenterContainer` → `DocumentCard (PanelContainer)` → `VBoxContainer` → `CardHeader`, `CardBody`, `CardFooter`. No Button nodes present anywhere in the scene (FP-OV-9).
- [ ] **AC-2** (TR-DOU-011): `document_overlay_ui.gd` script attaches to `ModalBackdrop`. On `_ready()`, the node registers itself in group `&"document_overlay_instances"`. If `get_tree().get_nodes_in_group(&"document_overlay_instances").size() > 1` at that point, `push_error("Multiple DocumentOverlayUI instances in section — only one allowed.")` is emitted, `_disabled` is set to `true`, and `_ready()` returns early without connecting any signals.
- [ ] **AC-3** (TR-DOU-011): On `_exit_tree()`, the node removes itself from the `&"document_overlay_instances"` group via `remove_from_group()` with an `is_in_group()` guard.
- [ ] **AC-4** (TR-DOU-013): `_ready()` calls `set_process(false)` and `set_physics_process(false)`. `ModalBackdrop.process_mode` is set to `PROCESS_MODE_ALWAYS` in the scene file (or confirmed in `_ready()`) so `_unhandled_input` fires even if SceneTree is paused by a future system.
- [ ] **AC-5** (TR-DOU-001): `DocumentCard.visible` is `false` by default in the scene file. `RichTextLabel` (`BodyText`) has `bbcode_enabled = true`, `fit_content = true`, `scroll_active = false`, `autowrap_mode = TextServer.AUTOWRAP_WORD`, `auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`, `mouse_filter = MOUSE_FILTER_PASS`. `BodyScrollContainer` has `horizontal_scroll_mode = SCROLL_MODE_DISABLED`, `vertical_scroll_mode = SCROLL_MODE_AUTO`, `smooth_scroll_enabled = false` (FP-OV-12). `TitleLabel` has `auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`, `clip_contents = true`, `text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_CHAR`.
- [ ] **AC-6** (TR-DOU-011): A unit test asserts: (a) a fresh scene instance registers exactly one entry in `&"document_overlay_instances"`; (b) if a second instance is added to the same tree, `_disabled == true` on the second instance and `Events.document_opened` is NOT connected on the second instance.

---

## Implementation Notes

*Derived from ADR-0007 §Implementation Guidelines + GDD §C.2 + GDD CR-13 + GDD CR-15:*

File structure for this story:

```
src/ui/document_overlay/
├── DocumentOverlayUI.tscn        # CanvasLayer root, layer = 5 per ADR-0004 §IG7
├── document_overlay_ui.gd        # Script on ModalBackdrop
└── document_overlay_theme.tres   # Theme stub; fallback_theme = project_theme.tres
                                  # (Coords OQ-DOV-COORD-7 — art-director fills StyleBoxFlat later)
```

GDD §C.2 scene tree (abridged to this story's structural requirements):
- `DocumentOverlayUI (CanvasLayer, layer = 5)` — root
  - `ModalBackdrop (Control)`: `mouse_filter = MOUSE_FILTER_STOP`, `anchors = PRESET_FULL_RECT`, `process_mode = PROCESS_MODE_ALWAYS`. Script: `document_overlay_ui.gd`.
    - `CenterContainer`
      - `DocumentCard (PanelContainer)`: `custom_minimum_size = Vector2(800, 0)`, `visible = false`, `theme_type_variation = "DocumentCard"`
        - `VBoxContainer`
          - `CardHeader (PanelContainer)`: h = 64 px via `custom_minimum_size`
            - `MarginContainer` (12 px v, 24 px h)
              - `TitleLabel (Label)`: `theme_type_variation = "DocumentTitle"`, `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`, `clip_contents = true`, `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS_CHAR`
          - `CardBody (MarginContainer)`: 32 px v, 48 px h padding
            - `BodyScrollContainer (ScrollContainer)`: `horizontal_scroll_mode = SCROLL_MODE_DISABLED`, `vertical_scroll_mode = SCROLL_MODE_AUTO`, `smooth_scroll_enabled = false`, `theme_type_variation = "DocumentScroll"`, `mouse_filter = MOUSE_FILTER_STOP`
              - `BodyText (RichTextLabel)`: `bbcode_enabled = true`, `fit_content = true`, `scroll_active = false`, `autowrap_mode = AUTOWRAP_WORD`, `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED`, `mouse_filter = MOUSE_FILTER_PASS`
          - `CardFooter (PanelContainer)`: `custom_minimum_size = Vector2(0, 30)`
            - `MarginContainer`
              - `FooterVBox (VBoxContainer)`
                - `ScrollHintLabel (Label)`: `visible = false`, `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`, `horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER`
                - `DismissHintLabel (Label)`: `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS`, `horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER`

`document_overlay_ui.gd` skeleton for this story only:

```gdscript
class_name DocumentOverlayUI
extends Control

## Document Overlay UI — per-section reading modal.
## NOT autoload (ADR-0007; registry full at slot 9 = MLS).
## CanvasLayer index 5 locked by ADR-0004 §IG7.
## Lifecycle signals wired in Story 003.

enum State { IDLE, OPENING, READING, CLOSING }

var _state: State = State.IDLE
var _disabled: bool = false

func _ready() -> void:
    set_process(false)
    set_physics_process(false)
    # CR-15: no per-frame GDScript while open; all transitions are signal/input-driven
    # PROCESS_MODE_ALWAYS set in scene file on ModalBackdrop root

    add_to_group(&"document_overlay_instances")
    if get_tree().get_nodes_in_group(&"document_overlay_instances").size() > 1:
        push_error("Multiple DocumentOverlayUI instances in section — only one allowed.")
        _disabled = true
        return  # skip all signal subscriptions
    # Signal connections added in Story 003

func _exit_tree() -> void:
    if is_in_group(&"document_overlay_instances"):
        remove_from_group(&"document_overlay_instances")
    # Safety-net for abnormal queue_free: Stories 003-005 add full _exit_tree teardown
```

`document_overlay_theme.tres` is a stub `Theme` resource with `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")`. Art-director fills StyleBoxFlat entries for `DocumentCard`, `DocumentTitle`, `DocumentScroll` theme_type_variations (Coord OQ-DOV-COORD-7 ADVISORY).

The `DismissHintLabel` node sets `text = "overlay.dismiss_hint"` in the scene file — the `AUTO_TRANSLATE_MODE_ALWAYS` on this node causes the engine to call `tr()` automatically. The `ScrollHintLabel` sets `text = "overlay.scroll_hint"` similarly.

Both `overlay.*` translation keys require `translations/overlay.csv` to exist (Coord OQ-DOV-COORD-5 BLOCKING). The scene will compile and run without the file (Godot returns keys verbatim if CSV absent); the AC for localization keys belongs to Story 004.

**Note on ADR-0004 §IG7 Proposed status**: the CanvasLayer index `5` is derived from ADR-0004 §IG7 which is Proposed. The index is unlikely to change (it is a z-order registry entry, not an API surface). Implement with the documented index. If ADR-0004 promotions shift this value, the scene file requires a one-line amendment.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: CI forbidden-patterns script (`tools/ci/check_forbidden_patterns_overlay.sh`) and call-order test helper (`tests/unit/helpers/call_order_recorder.gd`)
- Story 003: `Events.document_opened` / `document_closed` signal subscriptions; InputContext push/pop; PostProcessStack.enable_sepia_dim() handshake
- Story 004: `tr()` body rendering; FontRegistry font assignment; `NOTIFICATION_TRANSLATION_CHANGED` handler; Theme StyleBoxFlat values
- Story 005: `_unhandled_input` dismiss handler; `get_viewport().set_input_as_handled()` + `InputContext.pop()` call-order; mouse mode save/restore
- Story 006: Scroll grammar; gamepad right-stick `_unhandled_input` branch; Tab/focus consumption
- Story 007: AccessKit `accessibility_description` + assertive live-region announce; NVDA/Orca walkthroughs
- Story 008: ADR-0008 Slot 7 performance evidence; draw-call proxy test; open-frame profiling

---

## QA Test Cases

**AC-1**: Scene structure matches GDD §C.2

- Setup: Load `DocumentOverlayUI.tscn` in headless GUT scene.
- Verify: `$DocumentOverlayUI` is a `CanvasLayer`; `.layer == 5`; `$DocumentOverlayUI/ModalBackdrop/CenterContainer/DocumentCard.visible == false`; `BodyScrollContainer.smooth_scroll_enabled == false`; `BodyText.bbcode_enabled == true`; no `Button` node anywhere in the tree (`get_tree().get_nodes_in_group(&"")` search for `Button` class returns empty).
- Pass condition: all assertions pass; no push_error in log; scene loads without errors.

**AC-2 + AC-3**: Single-instance guard — first instance

- Setup: Add one `DocumentOverlayUI` instance to a test tree; call `_ready()`.
- Verify: `get_tree().get_nodes_in_group(&"document_overlay_instances").size() == 1`; `instance._disabled == false`.
- Pass condition: no push_error; `_disabled` false on first instance.

**AC-6**: Single-instance guard — second instance blocked

- Setup: Add two `DocumentOverlayUI` instances to the same test tree; call both `_ready()`.
- Verify: second instance: `push_error` contains "Multiple DocumentOverlayUI"; `_disabled == true`; `Events.document_opened.is_connected(second_instance._on_document_opened) == false`.
- Pass condition: only the first instance has signal connections; second is inert.
- Edge cases: `_exit_tree()` called on second instance — `remove_from_group` guard fires cleanly with no error.

**AC-4**: No per-frame processing

- Setup: Instantiate scene; advance 10 frames.
- Verify: `is_processing() == false`; `is_physics_processing() == false`.
- Pass condition: zero GDScript processing overhead.

**AC-5**: Scene property validation

- Setup: Static analysis of `.tscn` file or property reads on instantiated scene.
- Verify: `TitleLabel.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED`; `BodyText.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED`; `DismissHintLabel.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_ALWAYS`; `BodyScrollContainer.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED`; `BodyText.mouse_filter == Control.MOUSE_FILTER_PASS`.
- Pass condition: all property assertions pass.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/document_overlay/scene_scaffold_test.gd` — must exist and pass (AC-1, AC-2, AC-3, AC-4, AC-5, AC-6)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — foundational scene scaffold (ADR-0007 Accepted; CanvasLayer index from ADR-0004 §IG7 Proposed but index value is stable)
- Unlocks: Story 003 (signal wiring requires scene to exist), Story 004 (Theme + FontRegistry require scene nodes), Story 005 (dismiss handler requires ModalBackdrop script)
- Note: this story is marked **Blocked** because ADR-0004 and ADR-0008 are Proposed. The scene scaffold itself only consumes ADR-0004 §IG7 (z-order registry — LOW risk, index unlikely to change). Pragmatic unblock path: advance ADR-0004 to Accepted after Gate 5 closes.

## Open Questions

- **OQ-DOV-COORD-7 (ADVISORY)**: art-director has not yet defined `StyleBoxFlat` values for `DocumentCard`, `DocumentTitle`, `DocumentScroll` theme_type_variations. The stub theme will display with default Godot styling until this is filled.
- **OQ-DOV-COORD-5 (BLOCKING)**: `translations/overlay.csv` must exist with 4 `overlay.*` keys before the `DismissHintLabel` and `ScrollHintLabel` render correct text. Without it, labels show raw key strings. This is acceptable during scaffold development; must close before VS milestone.
