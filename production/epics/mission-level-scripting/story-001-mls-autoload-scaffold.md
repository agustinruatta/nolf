# Story 001: MissionLevelScripting autoload scaffold + load-order registration

> **Epic**: Mission & Level Scripting
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (S — new file + project.godot entry + one test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/mission-level-scripting.md`
**Requirement**: TR-MLS-006, TR-MLS-007
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: `MissionLevelScripting` must be registered in `project.godot` at line 9 of the `[autoload]` block — immediately after `FailureRespawn` (line 8) and before `SettingsService` (line 10). The `*res://` scene-mode prefix is mandatory. All cross-autoload setup belongs in `_ready()`; `_init()` must contain zero references to other autoloads.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoload registration and `_ready()` / `_exit_tree()` lifecycle are stable Godot 4.0+. ADR-0007 §Cross-Autoload Reference Safety rule 3 is load-bearing: MLS's `_ready()` fires after all autoloads at lines 1–8 are already in the scene tree. `_init()` fires during object construction before the node is added to the tree — referencing `Events` or `FailureRespawn` there would crash. No post-cutoff APIs involved in the scaffold itself.

**Control Manifest Rules (Feature)**:
- No Feature-layer ADR rules in the manifest yet (ADR-0008 pending Accepted)
- Required (Foundation, applies globally): all 10 autoload entries use `*res://` prefix syntax (ADR-0007 IG 2)
- Required (Foundation): An autoload's `_ready()` MAY reference only autoloads at earlier line numbers (ADR-0007 IG 4)
- Forbidden (Foundation): `never reference any other autoload from an autoload's _init()` — pattern `autoload_init_cross_reference` (ADR-0007 IG 3)
- Forbidden (Foundation): `never reference a later-line autoload from an autoload's _ready()` (ADR-0007 §Cross-Autoload Reference Safety rule 3)
- Forbidden (Foundation): `never call Engine.register_singleton() at runtime` — pattern `runtime_singleton_registration` (ADR-0007 IG 5)
- Forbidden (Foundation): `never call ProjectSettings.set_setting() / add_autoload_singleton() from @tool scripts without paired ADR-0007 amendment` — pattern `unregistered_autoload` (ADR-0007 IG 6)

---

## Acceptance Criteria

*From GDD `design/gdd/mission-level-scripting.md` CR-17, §C.2 initial IDLE entry, ADR-0007 §Canonical Registration Table:*

- [ ] `src/gameplay/mission_level_scripting/mission_level_scripting.gd` exists, declares `class_name MissionLevelScriptingService extends Node`, has a doc comment on the class, and exports no gameplay fields in this story (scaffold only — state fields land in Story 002).
- [ ] `project.godot` `[autoload]` block contains `MissionLevelScripting="*res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"` at exactly line 9, immediately after `FailureRespawn` at line 8 and before `SettingsService` at line 10. No reordering by the Godot editor UI.
- [ ] `MissionLevelScriptingService._init()` contains zero references to `Events`, `FailureRespawn`, `SaveLoad`, or any other autoload. Zero `get_node()` calls. Zero `Events.*` lookups. (AC-MLS-12.2, ADR-0007 IG 3.)
- [ ] `MissionLevelScriptingService._ready()` connects to `Events.section_entered` and `Events.respawn_triggered` using typed signal connections (`signal.connect(callable)` syntax, NOT string-based `connect("signal", obj, "method")`). `is_connected` guard is NOT required on connect in `_ready()` (only on disconnect in `_exit_tree()`).
- [ ] `MissionLevelScriptingService._exit_tree()` disconnects with `is_connected` guard before each disconnect call per ADR-0002 IG 3.
- [ ] A unit test confirms that when the game initializes, `MissionLevelScripting` is in the scene tree after `FailureRespawn` (confirms load-order invariant AC-MLS-12.1).

---

## Implementation Notes

*Derived from ADR-0007 §Canonical Registration Table, §Implementation Guidelines, §Cross-Autoload Reference Safety:*

### File location

```
src/gameplay/mission_level_scripting/
└── mission_level_scripting.gd      (class_name MissionLevelScriptingService)
```

### project.godot fragment (verbatim, per ADR-0007 IG 1)

```
[autoload]
...
Combat="*res://src/gameplay/combat/combat_system.gd"
FailureRespawn="*res://src/gameplay/failure_respawn/failure_respawn_service.gd"
MissionLevelScripting="*res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
SettingsService="*res://src/core/settings/settings_service.gd"
```

The Godot editor UI will alphabetize entries if you use the GUI. NEVER use the GUI — edit `project.godot` as text per ADR-0007 IG 1.

### `_ready()` skeleton

Connect to `Events.section_entered` and `Events.respawn_triggered` here. Both signals are defined on the `Events` autoload at line 1 — safely reachable from line 9. Connect using callable syntax: `Events.section_entered.connect(_on_section_entered)`. Stub handler bodies may `pass` in this story; logic lands in Story 002.

### `_exit_tree()` skeleton

Disconnect both signals with `is_connected` guards:
```
if Events.section_entered.is_connected(_on_section_entered):
    Events.section_entered.disconnect(_on_section_entered)
```

### Typing discipline

All handler method signatures must declare typed parameters: `func _on_section_entered(section_id: StringName, reason: int) -> void:`. The `reason` parameter type uses the `TransitionReason` enum owned by the Level Streaming system — use `int` and document the expected enum type in a comment until the Level Streaming epic defines the canonical enum import path.

### _init() absolute prohibition

`_init()` fires before the autoload node enters the tree. Do not place ANY of the following there: `Events.*`, `FailureRespawn.*`, `SaveLoad.*`, `get_node()`, or any cross-autoload reference. Leave `_init()` empty or omit it entirely.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Mission state machine fields (`_active_mission`, `_mission_state`, enum declarations, IDLE/RUNNING/COMPLETED transitions), all other signal subscriptions (`enemy_killed`, `alert_state_changed`, etc.), signal emissions (`mission_started`, etc.)
- Story 003: Plaza section scene authoring (respawn point, entry point, WorldItem, `discovery_surface_ids`)
- Story 004: SaveGame assembler chain (`capture()` calls, `save_to_slot()`)
- Story 005: Objective lifecycle (`MissionObjective` resource, `document_collected` subscription)

---

## QA Test Cases

**AC-1 / AC-2 — Autoload scaffold exists and is registered at line 9**
- Given: `project.godot` and `src/gameplay/mission_level_scripting/mission_level_scripting.gd` committed
- When: a unit test boots the scene tree and inspects `get_tree().root.get_children()`
- Then: a child Node named `MissionLevelScripting` is present; its `get_index()` in root's children is greater than `FailureRespawn`'s index and less than `SettingsService`'s index (confirming line-9 load order invariant AC-MLS-12.1)
- Edge cases: missing autoload entry → Godot logs "Script not found" at startup; test asserts presence, not absence of error. Wrong prefix (no `*`) → node not added to tree, `get_node("/root/MissionLevelScripting")` returns null.

**AC-3 — `_init()` has no cross-autoload references**
- Given: `mission_level_scripting.gd` source
- When: CI grep `(Events\.|FailureRespawn\.|SaveLoad\.|get_node\()` inside `func _init():` body runs (FP-8 scope-aware regex, tools-programmer coord item #9)
- Then: zero matches → exit 0; any match → CI fails with file + line number
- Edge cases: `_init()` absent entirely is a clean pass. `_init()` containing only local variable declarations is a clean pass.

**AC-4 / AC-5 — Signal connections use typed callable syntax; `is_connected` guard on disconnect**
- Given: `_ready()` and `_exit_tree()` implementations
- When: a unit test inspects the signal connection count on `Events.section_entered` and `Events.respawn_triggered` after the `MissionLevelScripting` node enters and exits the tree
- Then: after `_ready()` — both signals have exactly 1 connection from `MissionLevelScriptingService`; after `_exit_tree()` — both signals have 0 connections from `MissionLevelScriptingService`
- Edge cases: string-based connect (`connect("section_entered", ...)`) → old API, flagged by deprecated-API lint. Missing `is_connected` guard on disconnect → silent error if already disconnected (not testable at unit level, checked in code review).

**AC-6 — Load-order invariant**
- Given: full scene tree boot
- When: `_ready()` runs on `MissionLevelScripting`
- Then: `Events` is not null, `FailureRespawn` is not null — both are already in the tree (AC-MLS-12.1 basis)
- Edge cases: if `Events` is null at this point, it means the autoload order was corrupted — test should assert `Events != null` explicitly.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/mission_level_scripting/autoload_order_test.gd` — must exist and pass
- Test file name matches pattern `[system]_[feature]_test.gd` per coding standards
- Deterministic: tree boot is deterministic; no random seeds

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 of Signal Bus epic (Events autoload must exist); ADR-0007 line-9 amendment confirmed present (RESOLVED 2026-04-27)
- Unlocks: Story 002 (mission state machine requires this scaffold), Story 003, Story 004, Story 005
