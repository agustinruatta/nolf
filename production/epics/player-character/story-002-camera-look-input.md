# Story 002: First-person camera + look input

> **Epic**: Player Character
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 hours (M — _unhandled_input path, pitch clamp, yaw, turn overshoot tween)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/player-character.md`
**Requirements**: TR-PC-006
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract) — no direct collision work, but the body-yaw rotation means Eve's collider faces her look direction, which aligns AI line-of-sight raycasts with the rendered camera. No ADR directly governs the camera/look system, but the GDD's input-processing location decision (look in `_unhandled_input`, movement in `_physics_process`) is load-bearing for feel.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_unhandled_input(event)`, `InputEventMouseMotion`, `InputEventJoypadMotion`, `Camera3D.fov`, `camera.rotation.x` pitch clamping via `clampf`, and `Tween` for overshoot settle are all stable Godot 4.0+ APIs. No post-cutoff risk. The gamepad right-stick look input path uses `InputEventJoypadMotion` consumed in `_unhandled_input` — consistent with the project's input grammar (ADR-0004-adjacent but not ADR-gated here).

**Control Manifest Rules (Core)**:
- Required: look input consumed in `_unhandled_input(event)` (not `_physics_process`) to avoid mouse-delta accumulation on high-refresh displays — GDD §Detailed Design Core Rules
- Required: body rotates on Y (yaw); camera rotates on X (pitch); roll always 0
- Forbidden: no walk head-bob, no sprint FOV punch, no damage vignette — GDD Forbidden Patterns

---

## Acceptance Criteria

*From GDD `design/gdd/player-character.md` §Acceptance Criteria AC-7 + §Camera spec:*

- [ ] **AC-7.1 [Logic]**: At `_ready()`, `abs(Camera3D.fov - 75.0) <= 0.1`. Horizontal FOV 75°, configurable via `@export var camera_fov: float = 75.0` (designer-tunable per Tuning Knobs §Camera).
- [ ] **AC-7.2 [Integration]**: Injecting synthetic pitch input via `Input.parse_input_event(ev)` where `ev = InputEventMouseMotion.new()` with `ev.relative = Vector2(0, 1_000_000)` (large downward push past clamp limit): after one `_physics_process` tick, `camera.rotation.x <= deg_to_rad(85.0) + 0.001` (pitch clamped to +85° looking down). Reverse: `ev.relative = Vector2(0, -1_000_000)` → `camera.rotation.x >= -deg_to_rad(85.0) - 0.001` (looking up). Tolerance 0.001 rad ≈ 0.057° for float epsilon.
- [ ] **AC-7.3 [Integration]**: Look-left/right mouse motion (`ev.relative.x != 0`) rotates `body.rotation.y`, not `camera.rotation.x`. Look-up/down (`ev.relative.y != 0`) rotates `camera.rotation.x`, not `body.rotation.y`. After rotating body by +π/2 rad yaw, the camera's global forward basis aligns with the body's new forward, and a `_resolve_interact_target()` call (stub) uses the camera origin along the updated body forward.
- [ ] **AC-7.4 [Visual/Feel]**: Rapid yaw input (> 180°/s, injected as a sequence of `InputEventMouseMotion` events) produces a perceptible yaw overshoot within `turn_overshoot_deg ± 0.5°` and the overshoot settles monotonically within `90 ± 10 ms`. Art-director sign-off criterion: (a) overshoot amplitude within stated tolerance on frame-by-frame measurement, (b) settle returns monotonically (no secondary oscillation), (c) reads as "deliberate camera settle" and not "drunk".
- [ ] **AC-7.5 [Logic]**: No walk head-bob, no sprint FOV punch. `camera_fov` is constant at `75.0` regardless of movement state. A unit test asserts `Camera3D.fov` does not change between IDLE → WALK → SPRINT state transitions.

---

## Implementation Notes

*Derived from GDD §Detailed Design Core Rules — Node hierarchy + camera rotation + Input processing location:*

Look input is consumed in `_unhandled_input(event: InputEvent) -> void`, NOT in `_physics_process`. Rotation deltas are applied immediately to `body.rotation.y` (yaw) and `camera.rotation.x` (pitch):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event as InputEventMouseMotion
        rotation.y -= motion.relative.x * mouse_sensitivity_x
        _camera.rotation.x -= motion.relative.y * mouse_sensitivity_y
        _camera.rotation.x = clampf(_camera.rotation.x, -deg_to_rad(pitch_clamp_deg), deg_to_rad(pitch_clamp_deg))
    elif event is InputEventJoypadMotion:
        # Gamepad right-stick look — handled here for consistent feel with mouse
        pass  # full implementation delegates to separate analog-input method
```

Rationale (GDD §Input processing location, 2026-04-21): consuming look input in `_physics_process` would accumulate mouse deltas between 60 Hz physics ticks and apply them in a lump, producing "notchy" feel on high-refresh-rate displays.

**Turn overshoot** (`turn_overshoot_deg = 4.0°`, `turn_overshoot_return_ms = 90`): when yaw delta in a single frame exceeds the threshold derived from `> 180°/s` (i.e., `> 3°` per 60 Hz frame), a `Tween` runs a short overshoot-then-settle on `camera.rotation.y` (the camera's local Y, not the body's Y — overshoot is a camera-only effect). Settle eases out monotonically; no spring oscillation. This is the single permitted camera-feel deviation from "no sway": it reads as "deliberate weight" per GDD Player Fantasy.

**Sprint lateral pace-sway** (~0.5° amplitude, ~0.8 s period): applied as a `sin()`-driven offset to `camera.rotation.z` ONLY when `current_state == SPRINT`. Walk, Crouch, Idle have zero sway. Roll (`rotation.z`) is always 0 outside the sprint-sway window.

Mouse and gamepad look sensitivities are consumed from `Settings.get_mouse_sensitivity_x()` etc. (forward dependency). Defaults ship from `res://src/core/settings_defaults.gd` until Settings & Accessibility GDD lands.

`_camera` is cached via `@onready var _camera: Camera3D = $Camera3D` — no `$NodePath` lookups in `_process` or `_unhandled_input`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Scene root scaffold (Camera3D node must exist before this story implements)
- Story 003: Movement state (sprint sway references `current_state` which movement owns)
- Story 004: NoiseEvent / perception surface
- Story 007: Dead-state camera pitch-down-60° animation (respawn story)
- Story 008: Hands SubViewport FOV 55° (separate from main Camera3D FOV 75°)

---

## QA Test Cases

**AC-7.1 — FOV configuration**
- Given: `PlayerCharacter` scene instantiated in a test SceneTree
- When: `_ready()` completes
- Then: `_camera.fov == 75.0 ± 0.1`; source grep for `camera_fov` confirms it is an `@export var` on the script (designer-tunable per Tuning Knobs)
- Edge cases: fov set to 0 or negative in inspector → clamp to 70 (Safe Range minimum)

**AC-7.2 — Pitch clamp (up and down)**
- Given: `PlayerCharacter` added to a test SceneTree; `_ready()` complete
- When: `Input.parse_input_event(InputEventMouseMotion{ relative = Vector2(0, 1_000_000) })` is injected, then one `_physics_process(1.0/60.0)` tick runs
- Then: `_camera.rotation.x <= deg_to_rad(85.0) + 0.001`
- Reverse: `relative = Vector2(0, -1_000_000)` → `_camera.rotation.x >= -deg_to_rad(85.0) - 0.001`
- Edge cases: clamp expressed as truncated literal `1.484 rad` → wrong (deg_to_rad(85.0) = 1.4835298...); must use `deg_to_rad(pitch_clamp_deg)` expression or the correct float constant

**AC-7.3 — Body-yaw vs camera-pitch split**
- Given: `PlayerCharacter` in test SceneTree
- When: `InputEventMouseMotion{ relative = Vector2(100, 0) }` injected (yaw input only)
- Then: `body.rotation.y` changes; `_camera.rotation.x` does NOT change; `_camera.rotation.z == 0.0`
- When: `InputEventMouseMotion{ relative = Vector2(0, 100) }` injected (pitch input only)
- Then: `_camera.rotation.x` changes; `body.rotation.y` does NOT change
- Edge cases: misassignment writes pitch delta to body.y instead of camera.x → sightlines disagree with collider facing

**AC-7.4 — Turn overshoot visual feel (art-director sign-off)**
- Setup: run `tests/scenes/player_camera_overshoot_review.tscn` which drives 5 rapid yaw sequences of varying speeds (180°/s, 360°/s, 540°/s, 720°/s, stop-and-reverse) and records `camera.basis.get_euler().y` per frame
- Verify: (a) each sequence shows a peak-then-settle curve; (b) settle is monotonic (no secondary oscillation); (c) overshoot amplitude for 360°/s input is within `turn_overshoot_deg ± 0.5°` = `3.5° – 4.5°`
- Pass condition: art director reviews the captured frames (or the running scene) and signs off with a paragraph in the evidence file confirming a/b/c; "deliberate camera settle" and "not motion-sick" as qualitative judgment

**AC-7.5 — No FOV change across movement states**
- Given: `PlayerCharacter` with mock movement state driver
- When: state is forced through IDLE → WALK → SPRINT → CROUCH sequence over 10 simulated frames
- Then: `_camera.fov` equals `camera_fov` (75.0) at every frame; no Tween or setter modifies `fov`
- Edge cases: accidental `_camera.fov = fov + punch` in sprint-entry handler

---

## Test Evidence

**Story Type**: Integration (AC-7.2, AC-7.3 require Input injection + SceneTree; AC-7.4 requires visual art-director sign-off)
**Required evidence**:
- `tests/integration/core/player_character/player_camera_pitch_clamp_test.gd` — automated, must pass (AC-7.2)
- `tests/integration/core/player_character/player_camera_rotation_split_test.gd` — automated, must pass (AC-7.3)
- `tests/unit/core/player_character/player_camera_fov_test.gd` — automated, must pass (AC-7.1, AC-7.5)
- `production/qa/evidence/player-camera-overshoot-[date].md` — art-director sign-off required (AC-7.4)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene root scaffold — Camera3D node must exist)
- Unlocks: Story 003 (movement references camera forward for look direction in interaction; sprint sway applies to camera), Story 005 (interact raycast uses `_camera.global_position` + camera forward)
