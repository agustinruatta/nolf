# Story 006: Resolution scale subscription + Viewport.scaling_3d_scale wiring

> **Epic**: Post-Process Stack
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (S — signal subscription + Viewport property wiring + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/post-process-stack.md`
**Requirement**: TR-PP-008, TR-PP-010
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: PostProcessStack subscribes to `Events.setting_changed(category, name, value)` for the key `("graphics", "resolution_scale", value)` and applies the new value via `get_viewport().scaling_3d_scale = value`. ADR-0002 IG 3 requires subscription in `_ready()` with disconnect in `_exit_tree()` and `is_connected` guard. PostProcessStack is at autoload position 6; SettingsService is at position 10 — PostProcessStack's `_ready()` CANNOT call `SettingsService` directly (ADR-0007 IG 4 forward-reference prohibition). The initial resolution_scale value is read via a direct `Events` subscription on first `setting_changed` emission from SettingsService at boot. ADR-0008 Slot 3 notes that resolution_scale affects outline effective pixels (GDD Formula 3: `effective_pixels = width * height * scale²`).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Viewport.scaling_3d_scale` is stable Godot 4.0+. The `setting_changed` signal subscription pattern is used by ADR-0001's outline pass for the same resolution_scale key — both systems subscribe independently to the same signal. `Viewport` reference from an autoload: use `get_viewport()` (or `get_tree().root.get_viewport()`) — the root viewport is always available from an autoload's `_ready()`. Post-cutoff risk: none; `Viewport.scaling_3d_scale` property name and behavior unchanged in 4.4-4.6.

**Control Manifest Rules (Foundation)**:
- Required: subscribe in `_ready()` and disconnect in `_exit_tree()` with `is_connected` guard (ADR-0002 IG 3)
- Required: `setting_changed(category, name, value: Variant)` is the sole permitted Variant-payload signal; this is the correct signal to use (ADR-0002 IG 7)
- Forbidden: PostProcessStack must NOT directly call `SettingsService` in `_ready()` — SettingsService is at autoload position 10 (later than PostProcessStack at 6), violating ADR-0007 IG 4
- Forbidden: only Settings & Accessibility writes `resolution_scale`; PostProcessStack ONLY reads it via `setting_changed` signal — GDD anti-pattern `direct_viewport_scaling_modification`; GDD Acceptance Criterion 21 (lint check)
- Guardrail: `Events.setting_changed("graphics", "resolution_scale", value)` is a one-shot per session change (or at most a few times per session) — negligible signal-bus cost

---

## Acceptance Criteria

*From GDD `design/gdd/post-process-stack.md` §Acceptance Criteria AC-12 through AC-14 + AC-21:*

- [ ] **AC-1**: GIVEN `PostProcessStack._ready()` runs, WHEN `Events.setting_changed` is connected, THEN PostProcessStack has a handler `_on_setting_changed(category: StringName, name: StringName, value: Variant)` connected with the standard `is_connected` guard pattern. On `_exit_tree()`, the handler is disconnected.
- [ ] **AC-2**: GIVEN the game launches on desktop GPU hardware (detected by Settings & Accessibility as RTX 2060 class), WHEN Settings emits `Events.setting_changed(&"graphics", &"resolution_scale", 1.0)`, THEN PostProcessStack calls `get_viewport().scaling_3d_scale = 1.0` and `Viewport.scaling_3d_scale` is confirmed to be `1.0`.
- [ ] **AC-3**: GIVEN the game launches on Intel Iris Xe (detected by Settings & Accessibility), WHEN Settings emits `Events.setting_changed(&"graphics", &"resolution_scale", 0.75)`, THEN PostProcessStack calls `get_viewport().scaling_3d_scale = 0.75` and `Viewport.scaling_3d_scale` is confirmed to be `0.75`.
- [ ] **AC-4**: GIVEN the player manually changes resolution_scale via the Settings menu at runtime, WHEN `Events.setting_changed(&"graphics", &"resolution_scale", new_value)` fires, THEN PostProcessStack reads the new value and `get_viewport().scaling_3d_scale = new_value` immediately. The NEXT rendered frame uses the new scale (no transition blur — resolution-scale changes snap per GDD §Edge Cases).
- [ ] **AC-5**: GIVEN any GDScript file in `src/` outside of `PostProcessStack` and the Settings & Accessibility system, WHEN grepped for direct `Viewport.scaling_3d_scale` property assignment (i.e., `scaling_3d_scale =`), THEN zero matches (GDD anti-pattern `direct_viewport_scaling_modification` lint check, GDD AC-21).
- [ ] **AC-6**: GIVEN the `setting_changed` handler in PostProcessStack, WHEN the handler fires for a category/name that is NOT `("graphics", "resolution_scale")`, THEN the handler returns early without touching `Viewport.scaling_3d_scale`. (Defensive guard — PostProcessStack only consumes one setting key.)

---

## Implementation Notes

*Derived from GDD §Detailed Design Core Rule 6 + §Interactions (Settings & Accessibility row) + ADR-0002 IG 3 + ADR-0007 IG 4:*

**`_ready()` additions to `post_process_stack.gd`**:

```gdscript
func _ready() -> void:
    # ... existing scaffold from Story 001 ...
    if not Events.setting_changed.is_connected(_on_setting_changed):
        Events.setting_changed.connect(_on_setting_changed)

func _exit_tree() -> void:
    if Events.setting_changed.is_connected(_on_setting_changed):
        Events.setting_changed.disconnect(_on_setting_changed)

func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category == &"graphics" and name == &"resolution_scale":
        get_viewport().scaling_3d_scale = float(value)
```

**Initial value problem**: SettingsService is at autoload position 10. PostProcessStack `_ready()` runs at position 6, before SettingsService emits its first `setting_changed`. PostProcessStack cannot read SettingsService directly from `_ready()` (ADR-0007 IG 4 forward-reference prohibition). Resolution: SettingsService emits `setting_changed` for all settings during its own `_ready()` (position 10). PostProcessStack's subscriber catches this initial emission and applies the first value. If SettingsService emits BEFORE PostProcessStack connects (timing race), PostProcessStack would use whatever `scaling_3d_scale` the viewport defaults to (1.0). This is acceptable — the default is the correct desktop value; on Iris Xe hardware, SettingsService would emit 0.75 during its `_ready()` and PostProcessStack (already connected from position 6) would receive it. Verify this ordering assumption during Story 007 integration testing.

**Alternatively**: PostProcessStack could apply a safe default of `1.0` at `_ready()` time (before any signal fires) and let the signal override it. This is defensive and avoids the timing race:
```gdscript
func _ready() -> void:
    get_viewport().scaling_3d_scale = 1.0  # safe default until Settings fires
    Events.setting_changed.connect(_on_setting_changed)
```

**Lint check for `direct_viewport_scaling_modification`** (AC-5): Add to the glow ban lint test or a companion test:
```gdscript
func test_no_direct_scaling_3d_scale_writes_outside_pps():
    # Walk src/ excluding post_process_stack.gd and settings-related files
    # Grep for "scaling_3d_scale ="
    # Assert zero matches outside the permitted files
```

**VS deferral note**: The GDD and EPIC note that `set_render_scale()` Settings hookup via a direct method call (rather than just `setting_changed` subscription) is deferred post-VS. This story implements the `setting_changed` subscription path only, which is sufficient for VS scope. A VS-scope Settings menu integration (full slider/option polish) is post-VS per EPIC.md VS Scope Guidance.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: PostProcessStack `_ready()` scaffold base (must be DONE)
- Settings & Accessibility epic: the Settings detection logic (`RenderingServer.get_video_adapter_name()` heuristic) and the Settings menu slider/option UI — PostProcessStack only consumes the result
- Story 007: Visual verification that the outline pass and world render correctly at `scaling_3d_scale = 0.75` on the plaza scene
- Post-VS `set_render_scale()` direct API hookup: EPIC.md explicitly defers full Settings slider polish post-VS

---

## QA Test Cases

**AC-1 — Signal subscription lifecycle**
- Given: `PostProcessStackService` instance added to scene tree (simulating autoload boot)
- When: `_ready()` fires
- Then: `Events.setting_changed.is_connected(pps._on_setting_changed) == true`
- When: `_exit_tree()` fires (instance removed)
- Then: `Events.setting_changed.is_connected(pps._on_setting_changed) == false`
- Edge cases: double-connect guard (`is_connected` check) — calling `_ready()` twice should not create duplicate connections

**AC-2 + AC-4 — Viewport.scaling_3d_scale updated on signal**
- Given: PostProcessStack subscribed and listening; Viewport accessible via `get_viewport()`
- When: test emits `Events.setting_changed.emit(&"graphics", &"resolution_scale", 0.75)`
- Then: `get_viewport().scaling_3d_scale == 0.75`
- When: test emits `Events.setting_changed.emit(&"graphics", &"resolution_scale", 1.0)`
- Then: `get_viewport().scaling_3d_scale == 1.0`
- Edge cases: value arrives as `float` vs `int` (Variant) → `float(value)` cast must handle both; value 0.5 (below typical range) → still applied without clamping at PostProcessStack level (Settings owns range validation)

**AC-6 — Unrelated setting_changed calls are ignored**
- Given: PostProcessStack subscribed
- When: test emits `Events.setting_changed.emit(&"audio", &"master_volume", 0.5)`
- Then: `get_viewport().scaling_3d_scale` is unchanged from its previous value
- Edge cases: category matches but name doesn't → still ignored; name matches but category doesn't → still ignored

**AC-5 — Lint: no direct scaling_3d_scale writes outside permitted files**
- Given: all `.gd` files under `src/`, excluding `post_process_stack.gd` and Settings-related files
- When: each file is searched for the string `scaling_3d_scale =`
- Then: zero matches
- Edge cases: read access (`var x = viewport.scaling_3d_scale`) is permitted — test must match write assignment only (look for `= ` not just the property name)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/post_process_stack/resolution_scale_subscription_test.gd` — must exist and pass
- Covers: AC-1 (subscription lifecycle), AC-2/AC-4 (viewport updated on signal), AC-6 (unrelated signals ignored), AC-5 (lint grep)
- Determinism: inject a mock/stub `Viewport` or test with `get_viewport()` in a headless GUT context; no time-dependent assertions; `scaling_3d_scale` is a synchronous property write

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PostProcessStack `_ready()` scaffold must be DONE — this story extends it)
- Unlocks: Story 007 (visual + performance verification at resolution_scale = 0.75 requires this to be DONE)
