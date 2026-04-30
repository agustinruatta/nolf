# ADR-0004: UI Framework (Theme + InputContext + FontRegistry)

## Status

**Proposed** — Gates 1, 2, 3, 4 all CLOSED as of 2026-04-29 Sprint 01 verification. Status remains Proposed pending **Gate 5** (`RichTextLabel` BBCode → AccessKit plain-text serialization), which cannot be closed headlessly and is DEFERRED to runtime AT testing.

**Gate status (2026-04-29 verified)**:
- **Gate 1** ✅ CLOSED 2026-04-29 — `Control.accessibility_description` exists as a String property, settable, round-trips correctly. `accessibility_role` is NOT a Control property — AT role is inferred from node type (matches the hypothesis stated when this gate was opened). Verified via `prototypes/verification-spike/ui_framework_check.gd` Checks 1 + 2; verification log in `prototypes/verification-spike/verification-log.md`.
- **Gate 2** ✅ CLOSED 2026-04-27 — `Theme.fallback_theme` confirmed (godot-specialist 2026-04-27 via Document Overlay UI design-review).
- **Gate 3** ✅ CLOSED 2026-04-29 — `ui_cancel` action grammar verified for both KB/M + gamepad. KB/M dismiss: `KEY_ESCAPE` is a built-in default; verified via `event.is_action_pressed("ui_cancel")` returns true on `InputEventKey(KEY_ESCAPE, pressed=true)`. Gamepad dismiss: required project-level binding (Finding F3, see below) — `JOY_BUTTON_B` (button_index=1, the "B / Circle" right-side button per Art Bible 7D) added to `project.godot [input]` block as `ui_cancel.events`. The `_unhandled_input()` lifecycle on a real Control hierarchy is engine-stable since Godot 4.0 and not a 4.6-specific risk; the dual-focus split concern from this ADR's Decision section is sidestepped by the design choice to dispatch via `_unhandled_input` + action-check rather than focused-widget input.
- **Gate 4** ✅ CLOSED 2026-04-27 — `Node.AUTO_TRANSLATE_MODE_*` enum identifiers verified.
- **Gate 5** ⏸️ DEFERRED — see §Verification Required item (5) for rationale. Closure path: Settings & Accessibility production story includes a runtime AT inspection task (NVDA on Windows or Orca on Linux reading the Document Overlay scene, asserting that BBCode-formatted body content is announced as plain text, not as raw `[b]bold[/b]` source). Until that runs, ADR-0004 stays Proposed but is otherwise verification-complete.

**Finding F3 (Sprint 01 Group 2.2)**: Godot 4.6.2's built-in default InputMap for `ui_cancel` includes ONLY `KEY_ESCAPE` — no gamepad binding. Art Bible 7D mandates "Gamepad = B / Circle" for cancel, requiring the project to explicitly add the `JOY_BUTTON_B` binding. Resolution: `project.godot [input]` block now declares `ui_cancel` with both `KEY_ESCAPE` (preserving the engine default) and `InputEventJoypadButton(button_index=1)`. New Implementation Guideline 14 (below) makes this rule explicit so future ui_* action additions follow the same KB/M + gamepad parity pattern.

## Date

2026-04-19

## Last Verified

2026-04-29 (Sprint 01 Technical Verification Spike — Gates 1 + 3 closed; Gate 5 deferred to runtime AT testing; Finding F3 amended into project.godot + new Implementation Guideline 14; Status remains Proposed pending G5). Prior: 2026-04-28 (Amendment A6: per `/review-all-gdds` 2026-04-28 — `InputContext.Context` enum extended with `MODAL` and `LOADING` values, closing B4 carryforward (Menu System / F&R / LS / Input GDDs were already using these literals); push/pop authority table added to Implementation Guidelines; bundled atomically with ADR-0002 amendment that introduces `ui_context_changed(new: InputContext.Context, old: InputContext.Context)` to a new UI domain. Architectural decision unchanged; enum surface grew by 2 values + emit-site for `ui_context_changed` codified.)

Prior amendments: 2026-04-27 evening (Amendment A5: per /propagate-design-change from Document Overlay UI design-review revisions — Gate 2 + Gate 4 closed inline with verified property/enum names; new Gate 5 added for BBCode→AccessKit plain-text serialization; `base_theme` corrected to `fallback_theme` in 9 locations throughout this ADR. Architectural decision unchanged; only implementation-guidance wording amended.); 2026-04-23 (Amendment A4: Implementation Guideline 2 grew addendum mandating call sites use autoload key `InputContext.*`, never `InputContextStack.*`, per godot-specialist 2026-04-22 additional-finding; also supersedes "load order 4" statements with "per ADR-0007" references)

## Decision Makers

User (project owner) · godot-specialist (UI specialist per technical-preferences routing) · `/architecture-decision` skill

## Summary

The project's UI surfaces (HUD, Document Overlay, Menu, Settings, Cutscenes, Subtitles) consume three shared contracts: a single `project_theme.tres` with per-surface inherited Themes; an `InputContext` autoload that maintains a push/pop stack (gameplay → menu → document-overlay → pause); and a `FontRegistry` **static class** (not an autoload — eliminates anti-pattern concern) with typed getters that handle the Futura-→DIN size-floor substitution from Art Bible 7B/8C. Document Overlay's sepia dim is a lifecycle call to `PostProcessStack` (system 5), not a UI-owned shader. Modal dismiss uses `_unhandled_input()` checking `ui_cancel` action — sidestepping Godot 4.6's dual-focus complexity. Subtitles are suppressed when InputContext is `DOCUMENT_OVERLAY`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI (Control nodes, Theme system, focus, input dispatch) |
| **Knowledge Risk** | HIGH — major UI changes in 4.5 (FoldableContainer, Recursive Control disable, AccessKit screen reader, Live translation preview, SDL3 gamepad) and 4.6 (dual-focus split between mouse/touch and keyboard/gamepad). All load-bearing for this contract. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/ui.md`, `modules/input.md`, Art Bible Sections 3.3, 4.4, 7 |
| **Post-Cutoff APIs Used** | Godot 4.5 AccessKit screen reader integration (Settings & Accessibility); 4.5 Recursive Control disable (`mouse_filter` propagation); 4.6 dual-focus system handling. None are blocking — the design uses standard 4.0+ patterns and adopts 4.5/4.6 features additively. |
| **Verification Required** | (1) **OPEN BLOCKING** — Confirm Godot 4.6 editor property names for custom Control accessibility (likely `accessibility_description` not `accessibility_name`; `accessibility_role` may not be settable as string property — inferred from node type instead; `accessibility_live` semantics + AT-flush timing require verification, potential two-deep deferral pattern) — needed for Settings & Accessibility + Document Overlay UI Day 1 support. (2) **CLOSED 2026-04-27** — Theme inheritance property is `Theme.fallback_theme` (not `base_theme` — confirmed does not exist in any 4.x release). (3) **OPEN BLOCKING** — Confirm `_unhandled_input()` correctly handles modal dismiss across both KB/M and gamepad given the 4.6 dual-focus split. (4) **CLOSED 2026-04-27** — `Node.AUTO_TRANSLATE_MODE_*` enum identifiers verified in Godot 4.5+ (constants ALWAYS / DISABLED / INHERIT). (5) **OPEN BLOCKING NEW 2026-04-27** — Confirm whether `RichTextLabel` with `bbcode_enabled = true` exposes parsed plain text to AccessKit (NOT raw BBCode source). If raw exposed, every formatted document body fails SC 1.3.1; resolution = parallel AT-only plain-text property OR forbid BBCode in body content. Affects Document Overlay UI body rendering specifically. |

> **Note**: HIGH Knowledge Risk. UI is the most-changed domain in 4.5/4.6. This ADR must be re-validated if the project ever upgrades engine versions (especially the dual-focus and AccessKit integration paths).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0002** (Signal Bus + Event Taxonomy) — UI surfaces subscribe to `document_opened`, `document_closed`, `setting_changed`, `player_health_changed`, `ammo_changed`, `gadget_equipped`, `weapon_switched`, `objective_started/completed`, `mission_started/completed`, etc. **ADR-0003** (Save Format Contract) — Menu System calls `SaveLoad.slot_metadata()` and `SaveLoad.load_from_slot()` for save dossier cards. |
| **Enables** | All UI system GDDs and any system that needs context-aware input handling. |
| **Blocks** | HUD Core (system 16), HUD State Signaling (system 19), Document Overlay UI (system 20), Menu System (system 21), Cutscenes & Mission Cards (system 22), Settings & Accessibility (system 23), Dialogue & Subtitles (system 18). 7 system GDDs cannot specify their UI implementation until this ADR reaches Accepted. |
| **Ordering Note** | Last of the 4 required ADRs from `systems-index.md`. Sibling to ADR-0001/0002/0003. After this ADR is Accepted, all MVP Foundation system GDD authoring can begin. |

## Context

### Problem Statement

Three UI surfaces (HUD, Document Overlay, Menu) plus Settings, Cutscenes, and a Dialogue/Subtitle layer share four cross-cutting concerns: typography, color palette, input-dismiss grammar, and localization plumbing. Without a project-wide UI Framework:

1. **Typography drift** — each surface re-implements Art Bible 7 typography, inevitably diverging on size-floor substitution (Futura → DIN below 18 px) and weight choices.
2. **Color/style drift** — each surface picks colors from Art Bible 4 individually; one surface accidentally uses `#1A1A1A` near-black for an outline while another picks `#000000`.
3. **Input-context anarchy** — three modal surfaces (Document Overlay, Menu, Pause) all compete for input. Without a stack contract, opening a document during the pause menu may produce undefined behavior. Godot 4.6's dual-focus split (mouse vs keyboard/gamepad focus) makes this worse without a coordinating layer.
4. **Localization scaffolding fragments** — each surface decides separately whether to call `tr()`. One missed surface leaks an English string to a French build.

This contract must be authored before HUD Core (system 16) and the other 6 UI system GDDs, so they can specify their implementation in terms of "use the FontRegistry, push the InputContext, inherit project_theme.tres."

### Current State

Project is in pre-production. No source code exists. No prior UI implementation to migrate from. Art Bible Section 7 specifies the visual direction in detail; this ADR translates that into a Godot 4.6 implementation contract.

### Constraints

- **Engine: Godot 4.6, GDScript primary.** Standard `Control` nodes are the only UI primitive. Theme system is stable since 4.0 with no breaking changes through 4.6.
- **NOLF1-style HUD present** (Art Bible 7) — health, ammo, weapon, gadget. Period-styled. Screen-corner anchors. No center-screen permanent chrome. No modern HUD conveniences (pillar 5).
- **Three typeface families**: Futura Condensed Bold (HUD numerals), DIN 1451 Engschrift (HUD numerals < 18 px floor), American Typewriter (documents), Futura Extra Bold Condensed (menu/headers). (Art Bible 7B/8C.)
- **Color palette** locked in Art Bible 4: BQA Blue field at 85% opacity, Parchment text, Alarm Orange critical health, etc.
- **Modal dismiss controls**: KB/M = `Esc` or `E`; Gamepad = `B / Circle` (Art Bible 7D).
- **Document Overlay world dim** to ~30% sepia (Art Bible 2 Document Discovery + 4.3) — implementation owned by Post-Process Stack (system 5 from `systems-index.md`), NOT this UI Framework.
- **Localization Scaffold dependency** (system 7) — every visible string MUST go through `tr()` from day one.
- **First-time solo Godot dev** — patterns must be debuggable and respect the 9 forbidden patterns from ADRs 1-3.

### Requirements

- One canonical Theme registers fonts, colors, styles per Art Bible 7. Per-surface Themes inherit and override only what's specific.
- A typed `FontRegistry` provides font getters and handles the Futura → DIN substitution at the size-floor.
- An `InputContext` stack governs which modal surface owns input at any moment, working correctly with Godot 4.6's dual-focus split.
- Modal dismiss is consistent across all surfaces and works with both KB/M and gamepad without requiring focused widgets.
- Document Overlay's sepia dim is requested via a clean lifecycle call to Post-Process Stack — UI Framework owns the timing, Post-Process Stack owns the shader.
- Subtitles never collide with the Document Overlay (Art Bible 7E open question — resolved here).
- Settings & Accessibility (system 23) can integrate AccessKit screen reader support per Godot 4.5+.
- All UI surfaces consume Events bus signals (per ADR-0002) — no polling, no direct system queries.
- Anti-patterns from ADRs 1-3 (especially `autoload_singleton_coupling` and `events_with_state_or_methods`) must not be re-introduced.

## Decision

**Three contracts:**

1. **Theme inheritance**: single `res://src/core/ui_framework/project_theme.tres` as base; per-surface child Themes set `fallback_theme = preload(project_theme.tres)` and override only the differences. Surface root Control nodes assign their surface Theme; descendants inherit automatically. (Property corrected from `base_theme` → `fallback_theme` 2026-04-27 per Gate 2 closure; `base_theme` does NOT exist on Godot's `Theme` in any 4.x release.)
2. **`InputContext` autoload** (line order per ADR-0007 — Autoload Load Order Registry): push/pop stack of input contexts. Surfaces call `InputContext.push(Context.DOCUMENT_OVERLAY)` on open and `InputContext.pop()` on close. Each surface checks `InputContext.current()` in `_unhandled_input()` before consuming input. **Emits no signals of its own** — if any cross-system reaction is needed, add a `ui_context_changed` signal to ADR-0002's `Events` taxonomy.
3. **`FontRegistry` static class** (NOT an autoload — see Risks): typed getters return preloaded `Font` resources; encapsulates the Futura → DIN size-floor substitution. Static methods, no node lifecycle, no service-locator concern.

**Plus three locked rules:**

4. **Modal dismiss via `_unhandled_input()` + `ui_cancel` action**: dismiss is NEVER a focused Button. Each modal surface's root node listens in `_unhandled_input()` for `event.is_action_pressed(&"ui_cancel")`. The InputMap binds `Esc` + `B/Circle` to `ui_cancel` and `E` to a custom `interact` action. Sidesteps the 4.6 dual-focus complexity.
5. **Document Overlay sepia dim is a Post-Process Stack lifecycle call**: Document Overlay UI calls `PostProcessStack.enable_sepia_dim()` on open and `disable_sepia_dim()` on close. The shader belongs to Post-Process Stack (system 5). UI Framework owns the timing only.
6. **Subtitle collision rule**: when `InputContext.current() == DOCUMENT_OVERLAY`, ambient VO subtitles are suppressed. Mission-critical scripted dialogue subtitles tied to the document reveal itself may still play. Resolves Art Bible 7E open question.

### Architecture

```
                              ┌────────────────────────────────────────┐
                              │  UI SURFACES (each is its own scene)   │
                              │  HUD, HUD State Signaling, Doc Overlay,│
                              │  Menu, Settings, Cutscenes, Subtitles  │
                              └─────┬────────────────┬──────────┬──────┘
                                    │ inherits       │ uses     │ subscribes
                                    ▼                ▼          ▼
       ┌──────────────────────┐  ┌──────────────┐  ┌────────────────────┐
       │  project_theme.tres  │  │ FontRegistry │  │  Events autoload   │
       │  (base Theme)        │  │ (static class)│  │  (ADR-0002)        │
       │  ───────────────     │  │  hud_numeral │  │  document_opened   │
       │  fonts: BQA Blue     │  │  hud_label   │  │  player_damaged    │
       │  colors per Art 4.4  │  │  doc_body    │  │  ammo_changed      │
       │  styles: hard-edged  │  │  doc_header  │  │  setting_changed   │
       │  no rounded corners  │  │  menu_title  │  │  ...               │
       └─────────┬────────────┘  └──────┬───────┘  └────────────────────┘
                 │ fallback_theme        │ static getters
                 ▼                       │
       ┌──────────────────────┐          │
       │  themes/             │          │
       │  ├── hud_theme.tres  │          │ called from each surface's _ready()
       │  ├── document_       │          │
       │  │   overlay_theme   │          │
       │  │   .tres           │          │
       │  ├── menu_theme.tres │          │
       │  └── settings_       │          │
       │      theme.tres      │          │
       └──────────────────────┘          │

       ┌──────────────────────────────────────────┐
       │  InputContext autoload (per ADR-0007)    │
       │  ────────────────────────────────────────│
       │  enum Context { GAMEPLAY, MENU,          │
       │                 DOCUMENT_OVERLAY,        │
       │                 PAUSE, SETTINGS,         │
       │                 MODAL, LOADING }         │
       │  push(ctx) / pop() / current() /         │
       │  is_active(ctx)                          │
       │  emits Events.ui_context_changed         │
       │   (new_ctx, old_ctx) on every push/pop   │
       │                                          │
       │  Holds NO node references.               │
       │  Emits NO signals (use Events.gd).       │
       │  No business logic.                      │
       └──────────────────────────────────────────┘

       ┌──────────────────────────────────────────────────────────────┐
       │  Document Overlay open() lifecycle:                          │
       │   1. InputContext.push(DOCUMENT_OVERLAY)                     │
       │   2. PostProcessStack.enable_sepia_dim()                     │
       │   3. CanvasLayer (layer 5) shows document card               │
       │   4. Subtitle system observes context → suppresses ambient   │
       │   5. Events.document_opened.emit(document_id)                │
       │                                                              │
       │  close() lifecycle: reverse + Events.document_closed.emit    │
       └──────────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# res://src/core/ui_framework/font_registry.gd
# STATIC CLASS — NOT an autoload, NOT in scene tree
class_name FontRegistry extends RefCounted

const _FUTURA_COND_BOLD := preload("res://assets/fonts/futura_condensed_bold.ttf")
const _DIN_ENGSCHRIFT   := preload("res://assets/fonts/din_1451_engschrift.ttf")
const _AMER_TW_REG      := preload("res://assets/fonts/american_typewriter_regular.ttf")
const _AMER_TW_BOLD     := preload("res://assets/fonts/american_typewriter_bold.ttf")
const _FUTURA_EXBOLD    := preload("res://assets/fonts/futura_extra_bold_condensed.ttf")

const HUD_SIZE_FLOOR_PX: int = 18  # per Art Bible 7B/8C

# HUD numerals: substitute DIN below the size floor (Futura's 1/4/7 degrade at small sizes)
static func hud_numeral(rendered_size_px: int) -> Font:
    return _DIN_ENGSCHRIFT if rendered_size_px < HUD_SIZE_FLOOR_PX else _FUTURA_COND_BOLD

static func hud_label() -> Font:        return _FUTURA_COND_BOLD
static func document_body() -> Font:    return _AMER_TW_REG
static func document_header() -> Font:  return _AMER_TW_BOLD
static func menu_title() -> Font:       return _FUTURA_EXBOLD
```

```gdscript
# res://src/core/ui_framework/input_context.gd
# Autoload: "InputContext" — line order per ADR-0007 (Autoload Load Order Registry)
class_name InputContextStack extends Node

enum Context {
    GAMEPLAY,           # default — gameplay input fully active
    MENU,               # main menu open; gameplay paused
    DOCUMENT_OVERLAY,   # reading a document; gameplay paused, subtitles suppressed
    PAUSE,              # pause menu; gameplay paused
    SETTINGS,           # settings panel open (within menu or pause)
    MODAL,              # added 2026-04-28 — modal dialog (Quit-Confirm, Save-overwrite,
                        # Resolution-revert countdown banner, Save-failed dialog) active
                        # over an existing UI surface; pushed by the modal opener (Menu /
                        # Settings / F&R), popped on confirm/cancel; gameplay input
                        # swallowed during MODAL exactly as during MENU/PAUSE
    LOADING,            # added 2026-04-28 — pushed by LevelStreamingService at
                        # transition step 1, popped at step 11 (section_entered fires);
                        # ALL gameplay input swallowed; UI overlays (Document Overlay,
                        # menus) MUST force-dismiss on push since the underlying scene
                        # is being torn down
}

var _stack: Array[Context] = [Context.GAMEPLAY]

func push(ctx: Context) -> void:
    var old_ctx: Context = current()
    _stack.push_back(ctx)
    # 2026-04-28 amendment: emit ui_context_changed for every push/pop.
    # Subscribers (HUD Core CR-10, Audio overlay/menu BGM duck, Cutscenes
    # letterbox suppression, Subtitles auto-suppress) branch on new_ctx.
    Events.ui_context_changed.emit(ctx, old_ctx)

func pop() -> void:
    assert(_stack.size() > 1, "InputContext stack underflow — never pop GAMEPLAY")
    var old_ctx: Context = _stack.pop_back()
    Events.ui_context_changed.emit(current(), old_ctx)

func current() -> Context:
    return _stack.back()

func is_active(ctx: Context) -> bool:
    return current() == ctx
```

```gdscript
# Modal surface dismiss pattern — use in every modal surface's root node:
extends Control

func _unhandled_input(event: InputEvent) -> void:
    if not InputContext.is_active(InputContext.Context.DOCUMENT_OVERLAY):
        return  # this surface is not the active modal; ignore input
    if event.is_action_pressed(&"ui_cancel"):  # Esc or B/Circle from InputMap
        close()
        get_viewport().set_input_as_handled()

func close() -> void:
    InputContext.pop()
    PostProcessStack.disable_sepia_dim()
    Events.document_closed.emit(_current_document_id)
    queue_free()  # or hide(), depending on lifecycle
```

```gdscript
# Theme inheritance pattern (in editor or via code):
# Each surface's root Control: theme = preload("res://src/core/ui_framework/themes/[surface]_theme.tres")
# Each surface theme's `fallback_theme` property points to project_theme.tres (verified 2026-04-27 — Gate 2 closed)
# All descendant Controls inherit automatically — do NOT set theme on individual children.
```

### Implementation Guidelines

1. **`FontRegistry` is a static class, NOT an autoload.** Reasoning: avoids the autoload-singleton-coupling boundary entirely. Static class with `preload` constants is testable in isolation, has no node lifecycle, and is not reachable via `get_tree()`. If hot-reloading fonts during development becomes useful later, add a thin dev-only autoload wrapper — do NOT change `FontRegistry`'s API.
2. **`InputContext` IS an autoload, but tightly fenced.** Same principled distinction as `SaveLoadService` (ADR-0003): it owns the input-routing domain, not a service-locator. It holds NO node references, calls NO methods on UI surfaces, emits NO signals (cross-system reactions must go through `Events`). Stack manipulation only. **Class-name/autoload-key split (added 2026-04-23 per godot-specialist 2026-04-22 additional-finding)**: the script declares `class_name InputContextStack extends Node`; it is registered as autoload key `InputContext` (per ADR-0007). This is an intentional split, mirroring ADR-0002's `CombatSystemNode` class / `Combat` autoload-key pattern. **Call sites MUST use the autoload key** (`InputContext.push(...)`, `InputContext.current()`); they **MUST NOT use the class name** (`InputContextStack.push(...)` would be a discoverability trap — `class_name` exists for type annotation in method signatures and test-double construction only). Identical enforcement rule to the `CombatSystemNode`/`Combat` split codified in ADR-0002 Implementation Guideline 2.
3. **Modal dismiss NEVER uses focused Buttons.** `_unhandled_input()` + `ui_cancel` action handles all modal close events. This sidesteps Godot 4.6's dual-focus split — dismiss does not depend on which control has keyboard or mouse focus.
4. **Document Overlay sepia dim is a lifecycle call to `PostProcessStack`** (system 5). Document Overlay calls `PostProcessStack.enable_sepia_dim()` on open and `disable_sepia_dim()` on close. The shader implementation belongs to Post-Process Stack — when its GDD is authored, it MUST expose this exact API surface.
5. **Subtitle collision rule (resolves Art Bible 7E)**: when `InputContext.is_active(DOCUMENT_OVERLAY)`, the Subtitle system suppresses ambient VO subtitles. Subtitle system subscribes to `Events.document_opened` / `Events.document_closed` to manage suppression. Mission-critical scripted dialogue subtitles tied to the document reveal itself may still play (case-by-case, scripted in Mission & Level Scripting).
6. **Theme inheritance via single base.** Every surface Theme sets `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")` (Gate 2 closed 2026-04-27 — `Theme.fallback_theme` is the verified Godot 4.x property). Surface Themes contain ONLY overrides. Do NOT set `Control.theme` on individual descendants — let inheritance walk down from the surface root.
7. **Per-surface CanvasLayer indices** (z-order):
   - Layer 0: gameplay viewport (3D + 2D world)
   - Layer 4: PostProcessStack sepia dim ColorRect (when active) — owned by system 5 but documented here for z-ordering clarity
   - Layer 5: Document Overlay card
   - Layer 8: Pause menu / Main menu
   - **Layer 10: Settings panel** (when `InputContext.SETTINGS` active) **OR Cutscene letterbox / Mission cards** (when a cutscene is active) — **mutually exclusive** by InputContext gate. **Annotation added 2026-04-27 (closes B7 from /review-all-gdds 2026-04-27 + closes Menu System OQ-MENU-15)**: layer 10 is shared between two surfaces that never coexist in the canonical state machine — Settings panel pushes `InputContext.SETTINGS` and is dismissable to the previous context; Cutscenes hold a context (currently undeclared, owned by Cutscenes & Mission Cards GDD #22 when authored) that is pushed at cutscene start and popped at cutscene end. The two contexts are not stackable: the Menu System cannot open Settings while a cutscene is playing (Settings entry-point is gated on `InputContext.is_active(MENU)` or `InputContext.is_active(PAUSE)`, neither of which a cutscene context permits), and a cutscene cannot fire while Settings is open (Mission Scripting cutscene triggers gate on `InputContext.current() == GAMEPLAY`). The layer collision is therefore safe by construction. Implementation rule: the per-surface `CanvasLayer` node must be instanced lazily (created at surface-open, freed at surface-close) so both surfaces never have a `CanvasLayer` instance at layer 10 simultaneously even if the InputContext gate is bypassed by a future bug. Cutscenes & Mission Cards GDD when authored must reflect this annotation in its own forbidden-pattern list.
   - Layer 15: Subtitle layer (always on top so subtitles never hide behind menus)
8. **HUD elements set `mouse_filter = MOUSE_FILTER_IGNORE`** — HUD never takes focus or consumes mouse input.
9. **All visible text via `tr()`** from day one. Localization Scaffold (system 7) provides the string-table mechanism; this ADR mandates its use.
10. **AccessKit screen reader integration**: standard Controls (Button, Label) get accessibility roles automatically. For custom Controls, set `accessibility_*` properties (exact names verified per Gate 1) at construction time. Day 1 for Menu System and Settings & Accessibility surfaces. Polish-phase deferral acceptable for HUD numerals (per-frame updates may flood accessibility tree — use `accessibility_live = "off"` or equivalent).
11. **Use `Label` for static/numeric text; reserve `RichTextLabel` for the Document Overlay body** where period-styled bold headers, inline spacing, and letter-tracking effects require rich formatting. `RichTextLabel` is significantly heavier due to BBCode parsing.
12. **InputContext stack starts with `GAMEPLAY`**. Never pop below this base. The `assert` in `pop()` enforces this.
13. **Push/pop authority** (added 2026-04-28 per `/review-all-gdds` amendment A6 — closes B4 carryforward). Each `Context` value has exactly one authorised pusher and one authorised popper. A system that calls `InputContext.push(ctx)` for a context it does not own MUST be rejected at code review.

    | Context | Pusher (sole authority) | Popper (sole authority) | Notes |
    |---|---|---|---|
    | `GAMEPLAY` | `_ready()` of the autoload | (never popped) | Stack base; assert prevents underflow |
    | `MENU` | Menu System | Menu System | Pause / main menu / mission dossier |
    | `DOCUMENT_OVERLAY` | Document Overlay UI (system 20) | Document Overlay UI | Per Overlay §C 8-step open + 6-step close lifecycle |
    | `PAUSE` | Menu System | Menu System | Subset of MENU per existing wording |
    | `SETTINGS` | Settings & Accessibility | Settings & Accessibility | Stage-Manager carve-out |
    | `MODAL` *(NEW 2026-04-28)* | The system that opens the modal (Menu / Settings / F&R / Save-failed dialog publisher) | Same system that pushed it | Quit-confirm, Save-overwrite, Resolution-revert countdown banner. Gameplay input swallowed identically to MENU |
    | `LOADING` *(NEW 2026-04-28)* | `LevelStreamingService` step 1 | `LevelStreamingService` step 11 (after `section_entered` fires) | All gameplay input swallowed; UI overlays MUST force-dismiss on push since the underlying scene is being torn down |

    **Forbidden cross-system push** (registered as a forbidden pattern adjacent to `autoload_singleton_coupling`): a system MUST NOT push or pop a Context value owned by another system. Example: HUD Core MUST NOT push `MENU` to "open the pause menu"; it must instead emit a player-action signal that Menu System subscribes to and Menu System performs the push.

    **`ui_context_changed` emission is automatic.** The bus signal `Events.ui_context_changed(new_ctx, old_ctx)` (declared in ADR-0002 2026-04-28 amendment) is emitted by the InputContext autoload itself on every push/pop. Pushers MUST NOT emit it manually; subscribers (HUD Core CR-10, Audio overlay/menu BGM duck, Cutscenes letterbox suppression, Subtitles auto-suppress) read it and branch on `new_ctx`.

    **Stacking rules**: `MODAL` may be pushed over any other context (`MENU`, `SETTINGS`, `PAUSE`, even `DOCUMENT_OVERLAY`) and pops back to whatever was beneath. `LOADING` is exclusive — when LevelStreamingService pushes `LOADING`, every UI surface above it (`MENU`, `DOCUMENT_OVERLAY`, etc.) MUST force-dismiss because the scene tree they live on is being unloaded. The `current_section` is being torn down; their roots will be freed.

14. **Every `ui_*` action MUST have both KB/M and gamepad bindings declared in `project.godot [input]`** (Sprint 01 verification finding F3, 2026-04-29). Godot 4.6.2's built-in default InputMap registers `ui_cancel` with only `KEY_ESCAPE` (no gamepad binding); the project-level binding must add the matching gamepad button. Specifically, per Art Bible 7D the gamepad bindings are: `ui_accept` ↔ `JOY_BUTTON_A` (button_index=0, "A / Cross"); `ui_cancel` ↔ `JOY_BUTTON_B` (button_index=1, "B / Circle"). Future `ui_*` actions added (e.g. for a project-specific `ui_interact`, `ui_inventory`, etc.) MUST follow the same KB/M + gamepad parity pattern. **Currently bound (post-spike)**: `ui_cancel` (KEY_ESCAPE + JOY_BUTTON_B). **Pending**: `ui_accept` (engine default KEY_ENTER/KEY_SPACE present; JOY_BUTTON_A must be added when Menu System story implements navigation) and the `ui_left/right/up/down` directional set (engine defaults include arrow keys + WASD; JOY_DPAD_* and JOY_AXIS_* analogue stick bindings are added during Menu System implementation per the technical-preferences "full menu/gameplay navigation" gamepad commitment).

## Alternatives Considered

### Alternative 1: Multiple themes per surface (no inheritance)

- **Description**: Each UI surface owns an independent Theme resource — `HUD.tres`, `Menu.tres`, `DocumentOverlay.tres` — with no shared parent. Each duplicates color/font/style assignments.
- **Pros**: Maximum flexibility; surfaces can diverge freely without inheritance constraints.
- **Cons**: Style drift inevitable — when the BQA Blue HUD field needs to shift opacity from 85% to 90%, every surface Theme must be edited individually. Hand-maintained consistency is fragile.
- **Estimated Effort**: Comparable to chosen approach; higher long-term maintenance.
- **Rejection Reason**: Drift risk too high for a project with locked Art Bible 7 specifications.

### Alternative 2: Data-driven UI (JSON/Resource defines UI)

- **Description**: UI structure defined in data files, instantiated at runtime by a UI loader.
- **Pros**: Maximum flexibility for content authors; theoretically supports modding.
- **Cons**: Massive engineering cost; bypasses Godot's editor-based UI authoring (which is a productivity strength); first-time solo dev would burn weeks.
- **Estimated Effort**: 5× chosen approach.
- **Rejection Reason**: Overkill for 7 surfaces in a single-player game.

### Alternative 3: CommonUI-style layered framework (Unreal-inspired)

- **Description**: Heavy framework with explicit z-order management classes, modal stack widgets, focus-router classes, etc.
- **Pros**: Used by AAA games; very capable.
- **Cons**: Massive abstraction overhead for our scope; bypasses Godot idioms in favor of imported patterns; first-time Godot dev would learn the framework instead of the engine.
- **Estimated Effort**: 4× chosen approach.
- **Rejection Reason**: The chosen Theme + InputContext + FontRegistry trio is the Godot-idiomatic equivalent at our scope.

### Alternative 4: `FontRegistry` as autoload (originally proposed)

- **Description**: `FontRegistry` registered as an autoload node with the same typed getter API.
- **Pros**: Symmetry with `InputContext` (also an autoload).
- **Cons**: Method calls on an autoload to retrieve fonts are right on the boundary of `autoload_singleton_coupling` (a forbidden pattern per ADR-0002). The principled distinction that justifies `InputContext` and `SaveLoadService` (each owns a domain that can't be cleanly delegated) does not apply: font lookup is a pure-function asset query.
- **Rejection Reason**: A static class achieves the identical API without the anti-pattern boundary. This is the godot-shader-specialist's specific recommendation; adopted as-is.

### Alternative 5: Modal dismiss via focused Button widgets

- **Description**: Each modal surface contains a "Close" Button widget that the player clicks/activates.
- **Pros**: Visually explicit; conventional.
- **Cons**: Requires a focused Button — but Godot 4.6's dual-focus split means a Button focused via gamepad may not receive mouse-click activation cleanly without explicit handling; also requires UI focus management for keyboard navigation.
- **Estimated Effort**: Higher than chosen approach (focus routing complexity).
- **Rejection Reason**: `_unhandled_input()` + `ui_cancel` action is simpler, works identically for all input methods, and is the godot-specialist's specific recommendation.

## Consequences

### Positive

- One Theme inheritance chain ensures Art Bible 7 typography and Art Bible 4.4 colors apply consistently across all 7 UI surfaces.
- `FontRegistry` static class encapsulates the Futura → DIN size-floor logic in one place — every HUD Label gets the substitution for free.
- `InputContext` stack makes modal stacking explicit; debuggable via `print(InputContext._stack)`.
- Modal dismiss pattern works identically for KB/M and gamepad without per-surface focus management — leverages Godot 4.6's dual-focus design correctly.
- Document Overlay's sepia dim is delegated to its rightful owner (Post-Process Stack), preserving separation of concerns.
- Subtitle collision rule resolved (Art Bible 7E open question closed) — Subtitle system subscribes to events bus, no direct UI coupling.
- `tr()` requirement from day one prevents English-string leaks at translation time.
- AccessKit screen reader support is straightforward for standard Controls; opt-in for custom ones; deferrable for HUD with no architectural cost.
- Anti-pattern fence respected: `FontRegistry` is static (not autoload); `InputContext` is fenced like `SaveLoadService`; surfaces use Events bus (not direct queries).

### Negative

- Two verification gates required before status moves to Accepted (accessibility property names, Theme inheritance property name) — minor delay, low risk.
- Modal dismiss requires every surface to implement the `_unhandled_input()` boilerplate. Easy to forget if not in a control manifest checklist.
- `RichTextLabel` for Document Overlay body is heavier than `Label`; must be performance-tested if document content grows large (mitigated by 15–25 short documents).
- Subtitle suppression rule means scripted-but-not-mission-critical VO during document reading is lost. Acceptable trade-off; documented.

### Neutral

- 5 Theme files (1 base + 4 surface) is a manageable count at this scope. Adding a new surface adds one Theme file and one CanvasLayer index assignment.
- `InputContext` enum has 7 contexts as of the 2026-04-28 amendment (`GAMEPLAY`, `MENU`, `DOCUMENT_OVERLAY`, `PAUSE`, `SETTINGS`, `MODAL`, `LOADING`). Adding a new context (e.g., `INVENTORY` if a future feature needs it) is a single enum addition + push/pop authority table row + ADR-0002 owner update.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| ~~`Control.base_theme` property name changed in 4.5/4.6~~ — **CLOSED 2026-04-27**: `Theme.fallback_theme` is the verified Godot 4.x property; `base_theme` does not exist on `Theme` in any 4.x release. Implementation Guidelines item 6 corrected. | — | — | Gate 2 closed |
| `RichTextLabel.bbcode_enabled = true` exposes raw BBCode source to AccessKit (NOT parsed plain text) | MEDIUM | HIGH | **Gate 5 (new 2026-04-27)**: editor + screen-reader test. If raw BBCode is exposed, every formatted document body fails SC 1.3.1 — resolution = parallel AT-only plain-text property OR forbid BBCode in body content (heavy Writer-brief constraint). Affects Document Overlay UI body specifically. |
| `Control.accessibility_*` property names not as expected for custom Controls | MEDIUM | MEDIUM | **Gate 1**: editor inspector check. May need to adopt different naming for the Settings & Accessibility surface; doesn't block the Menu System (uses standard Controls). |
| 4.6 dual-focus dismiss behavior differs from `_unhandled_input()` expectation | LOW | MEDIUM | **Gate 3 (validation criterion)**: smoke-test modal open + dismiss on KB/M and gamepad in Godot 4.6 before marking ADR Accepted. |
| `InputContext` autoload drifts toward becoming a service locator (gains methods that act on UI surfaces) | MEDIUM | HIGH | Forbidden pattern registered: `input_context_service_locator`. Code review on every PR touching `input_context.gd`. |
| `FontRegistry` becomes an autoload "for convenience" later | MEDIUM | LOW | Forbidden pattern registered: `font_registry_as_autoload`. Static class is the canonical form. |
| Surfaces forget to call `tr()`, leaking English strings to other locales | MEDIUM | MEDIUM | Forbidden pattern registered: `hardcoded_visible_string`. `/localize` skill scans for hardcoded strings as part of QA. |
| Surfaces forget to push/pop InputContext, breaking modal stacking | MEDIUM | HIGH | Each modal surface's `_ready()` / `_exit_tree()` (or `open()` / `close()` lifecycle) MUST push/pop. Document in control manifest when authored. |
| HUD AccessKit per-frame Label updates flood the accessibility tree | LOW | LOW | Defer HUD accessibility to Polish phase per Implementation Guidelines item 10. Use `accessibility_live = "off"` (or equivalent) on HUD numerals. |
| Document Overlay sepia dim depends on Post-Process Stack exposing the right API | MEDIUM | MEDIUM | Post-Process Stack GDD (system 5, separate authoring) MUST expose `enable_sepia_dim()` / `disable_sepia_dim()`. Documented as a hard requirement on system 5. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (Theme inheritance lookup per Control _ready) | N/A | <0.1 ms per surface load (one-time) | N/A |
| CPU (HUD Label update on health change) | N/A | <0.1 ms per Label per update; updates triggered by Events signals (a few times/sec in normal play) | Negligible |
| CPU (RichTextLabel render for Document Overlay body) | N/A | ~1–3 ms first render; cached thereafter | Per-document; one document at a time |
| Memory (project_theme.tres) | N/A | <50 KB | N/A |
| Memory (FontRegistry preloaded TTFs) | N/A | ~1–2 MB total (5 typefaces) | N/A |
| Memory (per CanvasLayer + surface scene) | N/A | <500 KB per surface | N/A |
| Load Time (initial UI Framework load) | N/A | <50 ms (autoload + theme + font preloads) | <500 ms project startup budget |

> No frame-budget concerns for the chosen scope (7 surfaces, max ~30 Controls per surface, 5 typefaces).

## Migration Plan

This is the project's fourth and final required ADR. No existing UI to migrate. Implementation order:

1. **Verification gates** (Godot 4.6 editor session):
   - Gate 1 [BLOCKING]: open inspector on a custom Control subclass; confirm AccessKit property surface — likely real names per godot-specialist 2026-04-27: `accessibility_description` (NOT `accessibility_name`); `accessibility_role` may be inferred from node type rather than settable as string property; `accessibility_live` semantics + AT-flush timing require verification (potential two-deep deferral pattern needed if AT flush precedes deferred callbacks within same frame)
   - Gate 2 [CLOSED 2026-04-27]: `Theme.fallback_theme` is the verified property (`base_theme` does not exist in Godot 4.x)
   - Gate 3 [BLOCKING]: smoke-test modal `_unhandled_input()` + `ui_cancel` action on both KB/M and gamepad
   - Gate 4 [CLOSED 2026-04-27]: `Node.AUTO_TRANSLATE_MODE_*` enum (ALWAYS / DISABLED / INHERIT) verified in Godot 4.5+
   - Gate 5 [BLOCKING NEW 2026-04-27]: confirm `RichTextLabel` with `bbcode_enabled = true` exposes parsed plain text to AccessKit, NOT raw BBCode source — required for SC 1.3.1 conformance on formatted Document Overlay UI bodies
2. Create `res://src/core/ui_framework/` directory tree.
3. Author `project_theme.tres` with fonts (paths only, FontRegistry resolves at runtime), colors (per Art Bible 4.4), and styles (per Art Bible 3.3 / 7).
4. Implement `FontRegistry` static class.
5. Implement `InputContext` autoload; register in `project.godot` at the line position declared by ADR-0007.
6. Author 4 surface themes (`hud_theme.tres`, `document_overlay_theme.tres`, `menu_theme.tres`, `settings_theme.tres`) — each sets `fallback_theme = preload("res://src/core/ui_framework/project_theme.tres")` and overrides only what's specific.
7. Configure InputMap actions: `ui_cancel` (Esc + B/Circle), `interact` (E + A/Cross), and any others surfaces need.
8. Smoke test: stub HUD scene that displays a Label, listens to `Events.player_health_changed`, and updates correctly. Stub Document Overlay that opens on a key press, pushes InputContext, calls PostProcessStack stub, dismisses on `ui_cancel`.
9. Set ADR-0004 status Proposed → Accepted.
10. Begin authoring UI system GDDs (HUD Core, Document Overlay UI, Menu System, etc.) — each GDD specifies its surface theme overrides, which Events signals it subscribes to, which InputContext it pushes.

**Rollback plan**: If `InputContext` autoload proves problematic (e.g., the principled distinction from `autoload_singleton_coupling` doesn't hold up in code review), refactor to a per-modal-surface input-handling chain. The dismiss pattern (`_unhandled_input()` + `ui_cancel`) survives unchanged. The Theme inheritance and FontRegistry static class survive unchanged. Only the modal stacking pattern changes.

## Validation Criteria

- [ ] **Gate 1 [BLOCKING]**: Godot 4.6 editor exposes AccessKit-related properties on custom Control nodes (verify actual property names — likely `accessibility_description`; `accessibility_role` settability uncertain; `accessibility_live` AT-flush timing).
- [x] **Gate 2 [CLOSED 2026-04-27]**: Theme inheritance property is `Theme.fallback_theme` — verified per godot-specialist sign-off via Document Overlay UI design-review.
- [ ] **Gate 3 [BLOCKING]**: Smoke test — modal open → KB/M dismiss + gamepad dismiss both succeed.
- [x] **Gate 4 [CLOSED 2026-04-27]**: `Node.AUTO_TRANSLATE_MODE_*` enum constants verified in Godot 4.5+.
- [ ] **Gate 5 [BLOCKING NEW 2026-04-27]**: `RichTextLabel` with `bbcode_enabled = true` exposes parsed plain text to AccessKit (NOT raw BBCode source) — required for SC 1.3.1 conformance.
- [ ] `project_theme.tres` registers all colors from Art Bible 4 and base font sizes.
- [ ] `FontRegistry` static class implements all 5 typed getters with the size-floor substitution working at 17 vs 18 px.
- [ ] `InputContext` autoload registered at the line position declared by ADR-0007; `assert` in `pop()` prevents stack underflow.
- [ ] InputMap configured: `ui_cancel` = Esc + B/Circle; `interact` = E + A/Cross.
- [ ] Smoke test HUD scene receives `Events.player_health_changed` and updates Label color from Parchment to Alarm Orange below 25%.
- [ ] Smoke test Document Overlay opens, pushes context, calls PostProcessStack stub, dismisses on `ui_cancel`, pops context, calls disable.
- [ ] Subtitle suppression rule: Subtitle stub observes `Events.document_opened` and stops rendering ambient subtitles.
- [ ] All visible strings in test stubs use `tr()`.
- [ ] 5 forbidden patterns registered: `input_context_service_locator`, `font_registry_as_autoload`, `hardcoded_visible_string`, `modal_dismiss_via_focused_button`, `ui_surface_polls_game_state`.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/art/art-bible.md` Section 3.3 | UI shape grammar | "NOLF1-styled HUD: hard-edged rectangles, condensed type, no rounded corners, no soft glows, no drop shadows; corner-anchored; no center-screen permanent chrome" | `project_theme.tres` registers hard-edged StyleBox; per-surface themes inherit. HUD elements set `mouse_filter = MOUSE_FILTER_IGNORE` and live in screen corners with consistent margins. |
| `design/art/art-bible.md` Section 4.4 | HUD palette | "BQA Blue 85% opacity field; Parchment numerals; Alarm Orange critical state" | Theme registers each color; HUD scenes consume via Theme; Alarm Orange swap on `Events.player_health_changed` below 25%. |
| `design/art/art-bible.md` Section 7B | Typography | "Futura Condensed Bold for HUD numerals; DIN 1451 Engschrift below 18 px floor; American Typewriter for documents; Futura Extra Bold Condensed for menu" | `FontRegistry` static class encapsulates this exactly: `hud_numeral(size_px)` does the substitution. |
| `design/art/art-bible.md` Section 7D | Dismiss controls | "KB/M = Esc or E; gamepad = B/Circle" | InputMap `ui_cancel` = Esc + B/Circle; `interact` = E + A/Cross. Modal surfaces handle via `_unhandled_input()`. |
| `design/art/art-bible.md` Section 7E | Open question: subtitle/document overlay collision | "Suppress ambient subtitles while document open OR position inside doc card — needs resolution" | **Resolved**: option (a) — InputContext.is_active(DOCUMENT_OVERLAY) → Subtitle system suppresses ambient VO. |
| `design/gdd/systems-index.md` | HUD Core, HUD State Signaling, Document Overlay UI, Menu System, Settings & Accessibility, Cutscenes & Mission Cards, Dialogue & Subtitles | "Each surface needs typography + colors + dismiss + state subscription" | Theme inheritance + FontRegistry + InputContext + Events bus subscription pattern unifies all 7 surfaces. |
| `design/gdd/game-concept.md` | Pillar 5 (Period Authenticity) | "No modern UX conveniences (objective markers, kill cams, ping systems)" | UI Framework forbids these explicitly via fenced surface definitions; Menu System will not include any. |

## Related

- **ADR-0001** (Stencil ID Contract) — UI is screen-space (CanvasLayer), so stencil tiers don't apply to standard UI elements. The Document Overlay's dim ColorRect is the one exception explicitly noted in ADR-0001 as writing stencil 0.
- **ADR-0002** (Signal Bus + Event Taxonomy) — UI surfaces subscribe to many signals defined here. If `ui_context_changed` is needed in the future, it must be added to ADR-0002's taxonomy, not implemented as a local InputContext signal.
- **ADR-0003** (Save Format Contract) — Menu System calls `SaveLoad.slot_metadata()` and `SaveLoad.load_from_slot()` for the period mission-dossier card display. Menu System reads metadata sidecar (~200 bytes) for the card grid; full SaveGame load happens only on slot select.
- **`docs/registry/architecture.yaml`** — new entries: 1 interface (UI surface contract), 1 api_decision (Theme + InputContext + FontRegistry trio), 5 forbidden_patterns.
- **Future system GDDs**: 7 UI system GDDs consume this contract. Each GDD specifies its surface theme overrides, its Events subscriptions, and its InputContext push/pop lifecycle.
- **Post-Process Stack (system 5) GDD** — when authored, MUST expose `enable_sepia_dim()` / `disable_sepia_dim()` API surface as a hard requirement from this ADR.
