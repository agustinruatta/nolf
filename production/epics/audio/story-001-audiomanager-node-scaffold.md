# Story 001: AudioManager node scaffold + 5-bus structure

> **Epic**: Audio
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — new file + bus verification test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/audio.md`
**Requirement**: TR-AUD-002, TR-AUD-003
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Autoload Load Order Registry) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: `AudioManager` is a scene-tree `Node` living in the persistent root scene — NOT an autoload. The 10-autoload canonical chain (ADR-0007 §Key Interfaces) does NOT include Audio; `AudioManager` is instantiated as a child of the main scene node. It extends `Node`, declares `class_name AudioManager`, and connects/disconnects Signal Bus subscriptions in `_ready` / `_exit_tree` per ADR-0002 IG 3. Five `AudioServer` buses (Music, SFX, Ambient, Voice, UI) are the volume contract; no `AudioStreamPlayer` may route to `Master` directly (GDD Rule 1).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `AudioServer.add_bus()`, `AudioServer.set_bus_name()`, `AudioServer.set_bus_volume_db()` are stable Godot 4.0+ APIs. `AudioServer.bus_count` is read-only; bus insertion index is determined by argument order. Godot 4.6 adds no breaking changes to the audio bus API per `docs/engine-reference/godot/VERSION.md`. Node `_ready()` and `_exit_tree()` lifecycle are stable.

**Control Manifest Rules (Foundation)**:
- Required: subscribers MUST connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Required: `_ready()` MUST NOT reference autoloads that do not appear at earlier positions in ADR-0007 §Key Interfaces — `Events` is line 1 so it is safely reachable from any scene-tree node's `_ready()` (ADR-0007 §Cross-Autoload Reference Safety rule 2)
- Forbidden: never add methods, state, or query helpers to `Events.gd` (ADR-0002 forbidden pattern `events_with_state_or_methods`)
- Forbidden: never route any `AudioStreamPlayer` or `AudioStreamPlayer3D` to the `Master` bus — must route to one of the 5 named buses (GDD Rule 1)
- Guardrail: audio dispatch slot 0.3 ms cap on Iris Xe (ADR-0008 Slot 6 — pending Accepted; advisory until Gates 1+2 pass)

---

## Acceptance Criteria

*From GDD `design/gdd/audio.md` Rules 1, 3, 5 + AC-1, AC-3, AC-4 scoped to VS:*

- [ ] **AC-1**: GIVEN the project is launched and the persistent root scene is loaded, WHEN `AudioManager._ready()` completes, THEN `AudioServer.bus_count` equals 6 (Master + 5 named buses: Music, SFX, Ambient, Voice, UI in that order after Master), and each named bus can be retrieved by index via `AudioServer.get_bus_index(&"Music")` etc. returning a non-negative integer.
- [ ] **AC-2**: GIVEN `src/audio/audio_manager.gd` source, WHEN the `class_name` declaration is inspected, THEN it reads `class_name AudioManager extends Node` (not an autoload; not `extends AutoLoad`). The `_ready()` method is present with explicit `void` return type and static type annotations on all local variables.
- [ ] **AC-3**: GIVEN 16 pooled `AudioStreamPlayer3D` nodes pre-allocated in `_ready()`, WHEN each node's `bus` property is inspected, THEN it equals `&"SFX"` (not `&"Master"`). The pool is stored as `var _sfx_pool: Array[AudioStreamPlayer3D]`.
- [ ] **AC-4**: GIVEN any `AudioStreamPlayer` or `AudioStreamPlayer3D` in the persistent root scene tree, WHEN its `bus` property is read, THEN it is one of the 5 named buses — never `&"Master"`. Evidence: headless scene-tree scan in unit test.
- [ ] **AC-5**: GIVEN `AudioManager._exit_tree()` is called (game quit), WHEN the method runs, THEN no orphan `AudioStreamPlayer3D` nodes remain in the tree (all pool nodes are children of `AudioManager`, freed with it).

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines + GDD §Detailed Design Rules 1, 3, 5:*

**File location**: `src/audio/audio_manager.gd`

**Scene placement**: `AudioManager` is instantiated as a direct child of the persistent root scene node (e.g., `res://src/core/main.tscn`). It is NOT listed in `project.godot [autoload]`. Being in the persistent root scene means `_exit_tree()` fires only on game quit — not on section transitions.

**Bus setup** — called once in `_ready()` after `super._ready()`:

```gdscript
const BUS_NAMES: Array[StringName] = [&"Music", &"SFX", &"Ambient", &"Voice", &"UI"]

func _setup_buses() -> void:
    # Master bus already exists at index 0 in Godot by default.
    # Named buses are added starting at index 1.
    for bus_name: StringName in BUS_NAMES:
        var idx: int = AudioServer.get_bus_index(bus_name)
        if idx == -1:
            AudioServer.add_bus()
            idx = AudioServer.bus_count - 1
            AudioServer.set_bus_name(idx, bus_name)
```

Note: in production, buses are declared in the Godot Project Settings (Audio tab) so they persist in `project.godot`. The `_setup_buses()` pattern is a fallback for headless unit tests where the audio bus layout may not be loaded from project settings. In production builds, the bus layout in `project.godot` is authoritative; `_setup_buses()` validates that the expected buses exist.

**SFX pool setup** — pre-allocate 16 `AudioStreamPlayer3D` nodes in `_ready()`:

```gdscript
const SFX_POOL_SIZE: int = 16

var _sfx_pool: Array[AudioStreamPlayer3D] = []

func _setup_sfx_pool() -> void:
    for i: int in SFX_POOL_SIZE:
        var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
        player.bus = &"SFX"
        player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
        player.max_distance = 50.0
        player.unit_size = 10.0
        add_child(player)
        _sfx_pool.append(player)
```

**Important**: `AudioStreamPlayer.new()` at runtime is forbidden per GDD Rule 9 (anti-pattern fence). The pre-allocation in `_ready()` is explicitly permitted — it is the one-time pool initialization, not a per-SFX-event allocation.

**Signal subscriptions** are intentionally left to Story 002 to keep this story single-responsibility. The `_ready()` here only calls `_setup_buses()` and `_setup_sfx_pool()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Signal Bus subscription connect/disconnect lifecycle (all 30 signal connections)
- Story 003: Music layer players (`MusicDiegetic`, `MusicNonDiegetic`, `MusicSting` nodes), ambient loop player, section-entered handler, reverb swap
- Story 004: VO ducking handlers, document overlay world-bus mute, respawn cut-to-silence
- Story 005: Footstep variant routing, COMBAT stinger scheduling

**Deferred post-VS** (do NOT implement in this story):
- TR-AUD-008 (music preload per section) — full music preload logic deferred; VS uses placeholder streams
- TR-AUD-009 (per-section reverb presets) — reverb authoring deferred to Story 003
- TR-AUD-005 (full 5-location × 4-alert-state music grid) — VS only validates UNAWARE/COMBAT for Plaza

---

## QA Test Cases

**AC-1 — 5 named buses present after AudioManager._ready()**
- **Given**: a headless test scene that instantiates `AudioManager` as a child of a root `Node`
- **When**: `AudioManager._ready()` completes
- **Then**: `AudioServer.get_bus_index(&"Music")` returns >= 1; same for SFX, Ambient, Voice, UI; `AudioServer.bus_count` >= 6
- **Edge cases**: duplicate bus names (guard with `get_bus_index` returning -1 before `add_bus`); Master bus at index 0 is not renamed; headless Godot starts with only Master

**AC-2 — class_name and extends declaration**
- **Given**: `src/audio/audio_manager.gd` source
- **When**: a unit test loads the script via `load("res://src/audio/audio_manager.gd")`
- **Then**: `script.get_global_name() == &"AudioManager"`; the script's base class is `Node` (not autoload, not RefCounted)
- **Edge cases**: wrong base class → GDScript instantiation will fail to attach to scene tree; missing `class_name` → `get_global_name()` returns empty StringName

**AC-3 — SFX pool pre-allocated, all routed to SFX bus**
- **Given**: a headless test scene with `AudioManager` instantiated
- **When**: `_ready()` completes
- **Then**: `AudioManager._sfx_pool.size() == 16`; for every pool entry: `player.bus == &"SFX"` AND `player.get_parent() == AudioManager` (children, not orphans)
- **Edge cases**: pool undercount → size() < 16; wrong bus name → pool entries on Master (fails AC-4)

**AC-4 — no AudioStreamPlayer routes to Master**
- **Given**: the full scene tree after AudioManager is in the persistent root
- **When**: a unit test walks `get_tree().get_nodes_in_group` (or recursive `find_children`) for nodes of type AudioStreamPlayer or AudioStreamPlayer3D
- **Then**: zero nodes found with `bus == &"Master"`
- **Edge cases**: newly spawned nodes that bypass pool initialization; scene-imported nodes with wrong bus; Godot default AudioStreamPlayer bus is "Master" — test catches any missed initialization

**AC-5 — pool nodes freed with AudioManager**
- **Given**: AudioManager instantiated in a test scene
- **When**: AudioManager is freed (simulating game quit via `queue_free()` on its parent)
- **Then**: all 16 pool AudioStreamPlayer3D references are `not is_instance_valid(player)` after the next frame
- **Edge cases**: pool nodes added as children of another node instead of AudioManager → freed at wrong time

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/audio/audiomanager_bus_structure_test.gd` — must exist and pass
- Covers AC-1 (bus count + named buses), AC-2 (class_name), AC-3 (pool size + bus routing), AC-4 (no Master routing), AC-5 (pool freed with parent)
- Determinism: no random seeds; headless-safe (Godot audio server is initialized in headless mode)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the structural foundation for all other Audio stories
- Unlocks: Story 002 (subscription lifecycle requires AudioManager to exist), Story 003 (music players require the bus structure)
