# Story 001: SectionRegistry Resource + LSS autoload boot + CanvasLayer fade overlay scaffold

> **Epic**: Level Streaming
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — autoload registration + Resource scaffold + CanvasLayer setup)
> **Manifest Version**: 2026-04-30
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-001 (LSS autoload at line 5), TR-LS-002 (CanvasLayer 127 fade + 126 ErrorFallback), TR-LS-004 (SectionRegistry resource), TR-LS-012 (persistent fade overlay parented to autoload)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Autoload Load Order Registry) + ADR-0003 (Save Format Contract)
**ADR Decision Summary**: `LevelStreamingService` is at autoload line 5 (after `Events`, `EventLogger`, `SaveLoad`, `InputContext`) per ADR-0007 §Key Interfaces. Consuming `InputContext` from `_ready()` is safe because line 4 < line 5 (Cross-Autoload Reference Safety rule 2). `SectionRegistry` is a `Resource` at `res://assets/data/section_registry.tres` mapping `section_id: StringName → PackedScene path + display_name_loc_key`. Fade overlay = `CanvasLayer(layer=127)` + `ColorRect(0,0,0,0)`; ErrorFallback = `CanvasLayer(layer=126)`. Both parented to the autoload Node so they survive section unload.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CanvasLayer.layer` range is signed 8-bit (−128 to 127); 127 is max, 128 overflows. ResourceLoader for `.tres` is stable Godot 4.0+. Sprint 01 verified ADR-0007 G(a) byte-match — autoload registration discipline is proven.

**Control Manifest Rules (Foundation)**:
- Required: `_init()` MUST NOT reference any other autoload by name; `_ready()` MAY reference autoloads at earlier line numbers only (ADR-0007 IG 3, IG 4)
- Required: `*res://` scene-mode prefix on the autoload entry (ADR-0007 IG 2)
- Required: persistent fade overlay parented to autoload, NEVER section scene (TR-LS-012)
- Forbidden: `Engine.register_singleton()` at runtime — pattern `runtime_singleton_registration`

---

## Acceptance Criteria

*From GDD §Detailed Design CR-1, CR-3 + §Acceptance Criteria 4.1, 4.2:*

- [ ] **AC-1**: `src/core/level_streaming/level_streaming_service.gd` declares `class_name LevelStreamingService extends Node` with the `TransitionReason` enum (`FORWARD`, `RESPAWN`, `NEW_GAME`, `LOAD_FROM_SAVE`).
- [ ] **AC-2**: `project.godot` `[autoload]` block contains `LevelStreamingService="*res://src/core/level_streaming/level_streaming_service.gd"` at line 5 (after `Events` line 1, `EventLogger` line 2, `SaveLoad` line 3, `InputContext` line 4) — verbatim match with ADR-0007 §Key Interfaces.
- [ ] **AC-3**: `src/core/level_streaming/section_registry.gd` declares `class_name SectionRegistry extends Resource` with `@export var sections: Dictionary` (`## StringName -> Dictionary{path: String, display_name_loc_key: String}`).
- [ ] **AC-4**: `res://assets/data/section_registry.tres` exists with at least 2 entries: `&"plaza"` and `&"stub_b"`. Each entry has a non-empty `path` (`PackedScene` resource path) and non-empty `display_name_loc_key` (translation key like `"meta.section.plaza"`). (AC-LS-4.1 from GDD.)
- [ ] **AC-5**: At LSS `_ready()`, the registry is loaded into `_registry: SectionRegistry` and `_registry_valid: bool` is set (true on success, false on null/corrupt-load with `push_error`). Registry validity does NOT block autoload completion (per GDD §Edge Cases SectionRegistry Boundary Cases).
- [ ] **AC-6**: A `CanvasLayer` named `FadeOverlay` with `layer = 127` is created in `_ready()` and added as a child of the autoload Node. It contains a full-screen `ColorRect` with `color = Color(0, 0, 0, 0)` and anchors set to fill the viewport.
- [ ] **AC-7**: A second `CanvasLayer` named `ErrorFallbackLayer` with `layer = 126` is created at `_ready()` and added as a child of the autoload Node. `ErrorFallback.tscn` is `preload`-ed at autoload `_ready()` (NOT instantiated yet — instantiation happens on `_abort_transition`, story 005).
- [ ] **AC-8**: `res://scenes/ErrorFallback.tscn` exists and is a loadable scene (no editor import error). At MVP it can be a minimal `Control` with a `Label` showing "File not found — returning to main menu" placeholder text. (AC-LS-4.2 from GDD.)
- [ ] **AC-9**: LSS `_ready()` references only autoloads at lines 1–4 (`Events`, `EventLogger`, `SaveLoad`, `InputContext`); no references to lines 6+ (`PostProcessStack`, `Combat`, etc.). `_init()` references no autoloads.
- [ ] **AC-10**: The autoload Node persists for the application lifetime (verified by checking `is_instance_valid(LevelStreamingService)` after a `change_scene_to_file` call); the fade overlay's `CanvasLayer` similarly survives.

---

## Implementation Notes

*Derived from GDD §Detailed Design CR-1, CR-3 + ADR-0007 §Key Interfaces:*

**File structure**:

```
src/core/level_streaming/
├── level_streaming_service.gd       (class_name LevelStreamingService extends Node — autoload)
├── section_registry.gd              (class_name SectionRegistry extends Resource)
└── (later stories add: error_fallback.gd, etc.)

assets/data/
└── section_registry.tres            (SectionRegistry resource instance)

scenes/
└── ErrorFallback.tscn               (minimal placeholder for now)
```

**LSS `_ready()` skeleton**:

```gdscript
class_name LevelStreamingService extends Node

enum TransitionReason { FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE }

var _registry: SectionRegistry = null
var _registry_valid: bool = false
var _fade_overlay: CanvasLayer
var _fade_rect: ColorRect
var _error_fallback_layer: CanvasLayer
var _error_fallback_scene: PackedScene

func _ready() -> void:
    _setup_fade_overlay()
    _setup_error_fallback_layer()
    _load_registry()

func _setup_fade_overlay() -> void:
    _fade_overlay = CanvasLayer.new()
    _fade_overlay.name = "FadeOverlay"
    _fade_overlay.layer = 127
    add_child(_fade_overlay)

    _fade_rect = ColorRect.new()
    _fade_rect.color = Color(0, 0, 0, 0)
    _fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _fade_overlay.add_child(_fade_rect)

func _setup_error_fallback_layer() -> void:
    _error_fallback_layer = CanvasLayer.new()
    _error_fallback_layer.name = "ErrorFallbackLayer"
    _error_fallback_layer.layer = 126
    add_child(_error_fallback_layer)
    _error_fallback_scene = preload("res://scenes/ErrorFallback.tscn")

func _load_registry() -> void:
    var path: String = "res://assets/data/section_registry.tres"
    var loaded: Resource = ResourceLoader.load(path)
    if loaded == null or not (loaded is SectionRegistry):
        push_error("[LevelStreamingService] SectionRegistry load failed at %s" % path)
        _registry_valid = false
        return
    _registry = loaded as SectionRegistry
    _registry_valid = true
```

**SectionRegistry shape**:

```gdscript
class_name SectionRegistry extends Resource

# sections: Dictionary[StringName, Dictionary{path: String, display_name_loc_key: String}]
# Untyped Dictionary with doc-comment typing per Inventory CR-11 (TypedDictionary stability unverified post-cutoff).
@export var sections: Dictionary = {}

func has(section_id: StringName) -> bool:
    return sections.has(section_id)

func path(section_id: StringName) -> String:
    return sections.get(section_id, {}).get("path", "")

func display_name_loc_key(section_id: StringName) -> String:
    return sections.get(section_id, {}).get("display_name_loc_key", "")
```

**`section_registry.tres` initial content** — populated via Godot editor (Inspector) OR hand-authored as `.tres` text:

```ini
[gd_resource type="Resource" script_class="SectionRegistry" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/core/level_streaming/section_registry.gd" id="1"]

[resource]
script = ExtResource("1")
sections = {
    &"plaza": {"path": "res://scenes/sections/plaza.tscn", "display_name_loc_key": "meta.section.plaza"},
    &"stub_b": {"path": "res://scenes/sections/stub_b.tscn", "display_name_loc_key": "meta.section.stub_b"}
}
```

**`scenes/ErrorFallback.tscn` MVP placeholder** — minimal `Control` root with a centered `Label` reading "File not found — returning to main menu". The full visual treatment (Art Bible 7D dossier card) is post-MVP.

**`scenes/sections/plaza.tscn` and `stub_b.tscn`**: stub scenes per CR-9 authoring contract land in Story 008. This story scaffolds the registry pointing at expected paths; if the scenes don't exist yet, integration tests in subsequent stories use mock paths or wait for Story 008 to ship the stubs.

**Why `_registry_valid = false` does NOT halt autoload boot**: per GDD §Edge Cases, halting would break later autoload-order dependencies. The flag is a runtime guard checked by `transition_to_section` (Story 002), which `push_error`s and returns if invalid.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: state machine + 13-step swap sequence (the autoload boots; this story does NOT implement transitions)
- Story 003: `register_restore_callback` API + step 9 invocation
- Story 005: `_abort_transition` + ErrorFallback display logic (this story scaffolds the layer + preload; Story 005 instantiates on failure)
- Story 008: stub `plaza.tscn` + `stub_b.tscn` scenes (CR-9 authoring contract)
- `change_scene_to_file` for main-menu boot — owned by Menu System epic

---

## QA Test Cases

**AC-1 — LevelStreamingService class shape**
- **Given**: `level_streaming_service.gd` source
- **When**: a unit test loads the script
- **Then**: `class_name == "LevelStreamingService"`; extends `Node`; `TransitionReason` enum has 4 members in order FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE
- **Edge cases**: missing `class_name` → `Events.gd` signal declarations referencing `LevelStreamingService.TransitionReason` would fail to parse (per ADR-0002 atomic-commit risk row); test catches early

**AC-2 — Autoload registered at line 5**
- **Given**: `project.godot` `[autoload]` block
- **When**: a test parses the block
- **Then**: line 5 entry is `LevelStreamingService="*res://src/core/level_streaming/level_streaming_service.gd"`; lines 1–4 match ADR-0007 entries
- **Edge cases**: missing `*` prefix → script-mode (broken); test asserts presence

**AC-3 — SectionRegistry class shape**
- **Given**: `section_registry.gd` source
- **When**: a test instantiates `SectionRegistry.new()`
- **Then**: `class_name == "SectionRegistry"`; extends `Resource`; `sections: Dictionary` is empty by default; `has()`, `path()`, `display_name_loc_key()` methods exist
- **Edge cases**: TypedDictionary used → fails (per Inventory CR-11 stability rule)

**AC-4 — section_registry.tres has plaza + stub_b entries**
- **Given**: `res://assets/data/section_registry.tres`
- **When**: `ResourceLoader.load(...)` returns the SectionRegistry
- **Then**: `registry.has(&"plaza") == true` AND `registry.has(&"stub_b") == true`; `registry.path(&"plaza")` is non-empty; `registry.display_name_loc_key(&"plaza")` is non-empty (e.g., `"meta.section.plaza"`)
- **Edge cases**: file missing → load returns null; AC-5 covers that path

**AC-5 — Registry load + validity flag**
- **Given**: LSS autoload boots
- **When**: `_ready()` runs
- **Then**: if `section_registry.tres` exists and is valid: `_registry != null` AND `_registry_valid == true`; if missing: `_registry_valid == false` AND `push_error` was called AND autoload still completed `_ready()` (no halt)
- **Edge cases**: registry is a non-SectionRegistry Resource (e.g., a Texture renamed) → `_registry_valid = false` (type-guard catches mismatch)

**AC-6 — Fade overlay setup**
- **Given**: LSS autoload after `_ready()`
- **When**: a test inspects `LevelStreamingService.get_node("FadeOverlay")` and its child `ColorRect`
- **Then**: CanvasLayer exists; `layer == 127`; ColorRect exists as child; `color == Color(0, 0, 0, 0)`; ColorRect anchors fill the viewport
- **Edge cases**: layer set to 128 → fails (overflows signed 8-bit); test asserts exact value 127

**AC-7 — ErrorFallback layer setup + preload**
- **Given**: LSS autoload after `_ready()`
- **When**: a test inspects `LevelStreamingService.get_node("ErrorFallbackLayer")` and `_error_fallback_scene`
- **Then**: CanvasLayer exists; `layer == 126`; `_error_fallback_scene != null` AND `_error_fallback_scene is PackedScene`; no instance is mounted yet (Story 005 does that on failure)
- **Edge cases**: ErrorFallback.tscn missing → preload fails at parse time → autoload itself fails; pre-condition for AC-8

**AC-8 — ErrorFallback.tscn loadable**
- **Given**: file system after this story
- **When**: a test calls `ResourceLoader.load("res://scenes/ErrorFallback.tscn")`
- **Then**: returns a non-null `PackedScene`; instantiating it produces a valid `Control` Node tree with no parse errors
- **Edge cases**: scene contains a missing script reference → load may succeed but instantiate fails; test exercises both load AND instantiate

**AC-9 — Cross-autoload reference safety**
- **Given**: `level_streaming_service.gd` source
- **When**: static analysis inspects `_init()` and `_ready()` bodies
- **Then**: `_init()` body contains zero references to autoload names; `_ready()` body may reference `Events`, `EventLogger`, `SaveLoad`, `InputContext` (lines 1–4) but NOT later autoloads
- **Edge cases**: `_ready()` references `MissionLevelScripting` (line 9) → fails ADR-0007 §Cross-Autoload Reference Safety rule 3

**AC-10 — Autoload + fade overlay survive scene transitions**
- **Given**: LSS autoload booted
- **When**: a test calls `get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")` (or any scene swap)
- **Then**: `is_instance_valid(LevelStreamingService) == true` after the swap; `LevelStreamingService.get_node("FadeOverlay")` is still present
- **Edge cases**: autoload accidentally added as a child of `current_scene` instead of root → would die on scene swap; test catches this misconfiguration

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_streaming/level_streaming_service_boot_test.gd` — must exist and pass (covers all 10 ACs)
- `production/qa/smoke-[date].md` — smoke check confirming `section_registry.tres` and `ErrorFallback.tscn` are present in a clean export-ready state (AC-LS-4.1, AC-LS-4.2)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Save/Load Story 002 (`SaveLoad` autoload at line 3 must exist for line-5 ordering to be valid); ADR-0007 (Accepted)
- Unlocks: Story 002 (state machine uses the autoload + registry + fade overlay)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: All 10 ACs covered by 12 test functions in `level_streaming_service_boot_test.gd`.
**Test results**: 12/12 PASS.

### Files added
- `src/core/level_streaming/section_registry.gd` (Resource class with `has_section`/`path`/`display_name_loc_key`/`section_ids` API).
- `assets/data/section_registry.tres` (registry resource with plaza + stub_b entries).
- `scenes/ErrorFallback.tscn` (minimal placeholder Control + Label + Background).
- `tests/unit/level_streaming/level_streaming_service_boot_test.gd` (12 tests).

### Files modified
- `src/core/level_streaming/level_streaming_service.gd` — replaced Sprint 01 verification stub with the full LS-001 scaffold (TransitionReason enum, SectionRegistry loader with type-guard, persistent FadeOverlay CanvasLayer 127, persistent ErrorFallbackLayer CanvasLayer 126 with preloaded scene, public query API).

### Verdict
COMPLETE.
