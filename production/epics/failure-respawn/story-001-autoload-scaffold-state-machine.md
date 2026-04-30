# Story 001: FailureRespawn autoload scaffold — state machine + signal subscriptions + restore callback registration

> **Epic**: Failure & Respawn
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (M — new autoload script + stub scene + boot test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/failure-respawn.md`
**Requirement**: TR-FR-001 (subscribes to `Events.player_died`), TR-FR-010 (autoload registered at ADR-0007 line 8)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Autoload Load Order Registry) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: `FailureRespawn` is registered as autoload entry 8 (after `Combat` at 7, before `MissionLevelScripting` at 9) in `project.godot [autoload]` per ADR-0007 amended canonical table (amendment 2026-04-27). The autoload uses `*res://` scene-mode prefix (Node added to root, `_ready()` fires, tree lifecycle active). Signals are connected in `_ready` with `is_connected` guards before each `_exit_tree` disconnect. `FailureRespawn` subscribes to `Events.player_died` and `Events.section_entered` in `_ready`; registers its step-9 restore callback with `LevelStreamingService.register_restore_callback(_on_ls_restore)` in `_ready`. The class owns `FlowState` enum (IDLE, CAPTURING, RESTORING). `_flow_state` starts `IDLE` at boot.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoload registration mechanism + signal connect/disconnect lifecycle pattern are stable Godot 4.0+. `*res://` scene-mode prefix is ADR-0007 mandated. `register_restore_callback` is the LS-owned API declared in the Level Streaming epic story-003; this story registers the callback unconditionally in `_ready` (replace-semantics — correct for editor hot-reload, per GDD E.24 and LS GDD coord item). No post-cutoff APIs. The `_ready()` of autoload 8 may reference autoloads at lines 1–7 only (ADR-0007 cross-autoload reference safety rule).

**Control Manifest Rules (Feature)**:
- Required (Foundation/Signal Bus): subscribers MUST connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards — ADR-0002 IG 3
- Required (Foundation/Autoload): `project.godot [autoload]` block entry for `FailureRespawn` MUST be generated verbatim from ADR-0007 §Key Interfaces — ADR-0007 IG 1
- Required (Foundation/Autoload): autoload `_ready()` MAY reference autoloads at earlier line numbers only — ADR-0007 IG 4
- Forbidden: `_init()` cross-autoload references — pattern `autoload_init_cross_reference` — ADR-0007 IG 3
- Forbidden: referencing a later-line autoload from `_ready()` — ADR-0007 §Cross-Autoload Reference Safety rule 3

---

## Acceptance Criteria

*From GDD `design/gdd/failure-respawn.md` CR-1, CR-2, CR-12 Step 1, E.23, E.24; TR-FR-001, TR-FR-010:*

- [ ] **AC-1**: `src/gameplay/failure_respawn/failure_respawn_service.gd` declares `class_name FailureRespawnService extends Node` with an inner `enum FlowState { IDLE, CAPTURING, RESTORING }`, `_flow_state: FlowState = FlowState.IDLE`, and `_current_checkpoint: Checkpoint = null`.
- [ ] **AC-2**: `_ready()` subscribes to `Events.player_died` → `_on_player_died` and `Events.section_entered` → `_on_section_entered` with `is_connected` guards; `_exit_tree()` disconnects both with `is_connected` guards before each disconnect call.
- [ ] **AC-3**: `_ready()` calls `LevelStreamingService.register_restore_callback(_on_ls_restore)` unconditionally (replace-semantics handles hot-reload stale-Callable — GDD E.24).
- [ ] **AC-4**: GIVEN F&R autoload `_ready()` has just run, THEN `_flow_state == FlowState.IDLE` AND `_current_checkpoint == null` (no crash on boot without a section loaded, per GDD E.23).
- [ ] **AC-5**: GIVEN `_flow_state == FlowState.IDLE`, WHEN `Events.player_died` is emitted with any valid `CombatSystemNode.DeathCause` value, THEN `_flow_state` transitions to `FlowState.CAPTURING` synchronously within the same call stack (verified via call-stack-local state read immediately after emit).
- [ ] **AC-6**: GIVEN `_flow_state == FlowState.CAPTURING`, WHEN a second `Events.player_died` is emitted, THEN `_flow_state` remains `CAPTURING` (CR-2 idempotency drop — no retry, no queue).
- [ ] **AC-7**: GIVEN `_flow_state == FlowState.RESTORING`, WHEN `Events.player_died` is emitted, THEN `_flow_state` remains `RESTORING` (CR-2 drop applies in all non-IDLE states).
- [ ] **AC-8**: The `project.godot [autoload]` block includes `FailureRespawn="*res://src/gameplay/failure_respawn/failure_respawn_service.gd"` at line 8 per ADR-0007 §Key Interfaces (after `Combat` at line 7, before `MissionLevelScripting` at line 9).

---

## Implementation Notes

*Derived from ADR-0007 §Implementation Guidelines, ADR-0002 §Implementation Guidelines, GDD CR-1 / CR-2 / CR-7 / CR-12:*

**File to create**: `src/gameplay/failure_respawn/failure_respawn_service.gd`

**Class skeleton** (all public methods get doc comments per coding standards):

```gdscript
class_name FailureRespawnService
extends Node

## FailureRespawnService — autoload that catches player death and orchestrates
## the 13-step respawn flow. Sole publisher of respawn_triggered per ADR-0002:183.
## Registered at project.godot autoload line 8 (after Combat, before MLS) per ADR-0007.

enum FlowState { IDLE, CAPTURING, RESTORING }

var _flow_state: FlowState = FlowState.IDLE
var _current_checkpoint: Checkpoint = null

func _ready() -> void:
    Events.player_died.connect(_on_player_died)
    Events.section_entered.connect(_on_section_entered)
    LevelStreamingService.register_restore_callback(_on_ls_restore)

func _exit_tree() -> void:
    if Events.player_died.is_connected(_on_player_died):
        Events.player_died.disconnect(_on_player_died)
    if Events.section_entered.is_connected(_on_section_entered):
        Events.section_entered.disconnect(_on_section_entered)
```

**CR-2 idempotency guard** — `_on_player_died` must check `if _flow_state != FlowState.IDLE: return` as first line. This is the sole entry guard; no separate queue.

**Cross-autoload reference safety** — `FailureRespawn` is at line 8. Its `_ready()` references `Events` (line 1), `LevelStreamingService` (line 5), and will later reference `SaveLoad` (line 3) and `Combat` (line 7). All are at earlier line numbers — valid. It must NOT reference `MissionLevelScripting` (line 9) or `SettingsService` (line 10) from `_ready()`.

**Shared Checkpoint class location**: `src/gameplay/shared/checkpoint.gd` (NOT inside this directory — avoids a `PlayerCharacter` → `FailureRespawn` load-order dependency per GDD CR-11 coord item). This story creates the stub `checkpoint.gd` if it does not already exist: `class_name Checkpoint extends Resource` with `@export var respawn_position: Vector3 = Vector3.ZERO`.

**project.godot update**: Verify (and update if needed) the `[autoload]` block entry for `FailureRespawn` matches `FailureRespawn="*res://src/gameplay/failure_respawn/failure_respawn_service.gd"` at position 8. Do NOT reorder any other entries.

**DI hooks for testability**: expose `_inject_level_streaming(svc: LevelStreamingService) -> void` and `_inject_save_load(svc: SaveLoadService) -> void` setters (called by test harness to replace autoload references with doubles). These are test-only; ship builds call the real autoloads.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: SaveGame assembly + `save_to_slot(0)` + in-memory handoff to LS (`CAPTURING` body implementation)
- Story 003: `respawn_triggered` emission + signal ordering + subscriber re-entrancy fence
- Story 004: `section_entered` handler body — checkpoint assembly + CR-7 IDLE guard + floor flag transitions
- Story 005: LS step-9 `_on_ls_restore` callback body + `PlayerCharacter.reset_for_respawn` + InputContext push/pop + RESTORING → IDLE transition
- Story 006: Anti-pattern fences + `fr_autosaving_on_respawn` forbidden pattern CI lint

---

## QA Test Cases

**AC-1 — Class declaration and FlowState enum**
- Given: `src/gameplay/failure_respawn/failure_respawn_service.gd`
- When: a unit test loads the script and creates an instance via `FailureRespawnService.new()`
- Then: `instance._flow_state == FlowState.IDLE`; `instance._current_checkpoint == null`; `FailureRespawnService.FlowState.IDLE` etc. enum values are accessible
- Edge cases: missing `class_name` → `load()` returns a raw Script, not a typed class; missing `extends Node` → instantiation fails

**AC-2 — Signal connect/disconnect lifecycle**
- Given: a fresh `FailureRespawnService` added to a test scene tree so `_ready()` fires
- When: `_ready()` executes
- Then: `Events.player_died.is_connected(svc._on_player_died) == true` AND `Events.section_entered.is_connected(svc._on_section_entered) == true`
- When: `_exit_tree()` fires (remove from scene tree)
- Then: both connections are gone; no orphan callbacks

**AC-3 — Restore callback registration**
- Given: test double injected for `LevelStreamingService` via `_inject_level_streaming(double)`
- When: `_ready()` fires on the test double's FailureRespawnService instance
- Then: `double.register_restore_callback` was called exactly once with a `Callable` pointing to `_on_ls_restore`
- Edge cases: hot-reload re-run calls `register_restore_callback` again — the double verifies the second call replaces (not appends) the previous one

**AC-4 — Boot initial state**
- Given: F&R autoload `_ready()` has just run, no section loaded yet
- When: test reads `_flow_state` and `_current_checkpoint`
- Then: `_flow_state == FlowState.IDLE`; `_current_checkpoint == null`; no crash or push_error

**AC-5 — IDLE → CAPTURING on player_died (any DeathCause)**
- Given: `_flow_state == FlowState.IDLE`; `SaveLoadService` and `LevelStreamingService` are injected test doubles that no-op
- When: `Events.player_died.emit(CombatSystemNode.DeathCause.SCRIPTED)` is called synchronously
- Then: `_flow_state == FlowState.CAPTURING` immediately after the emit returns (same call stack)
- Edge cases: test each valid `DeathCause` value; all must yield `CAPTURING` (F&R is cause-agnostic)

**AC-6 — Idempotency guard in CAPTURING**
- Given: `_flow_state == FlowState.CAPTURING`
- When: `Events.player_died.emit(CombatSystemNode.DeathCause.SCRIPTED)` a second time
- Then: `_flow_state` remains `CAPTURING`; no additional `save_to_slot` or `reload_current_section` call on the doubles
- Edge cases: emitting 5 rapid `player_died` signals — all dropped; counter on double stays at 1

**AC-7 — Idempotency guard in RESTORING**
- Given: `_flow_state` forced to `FlowState.RESTORING` via direct field assignment (test harness)
- When: `Events.player_died.emit(CombatSystemNode.DeathCause.SCRIPTED)`
- Then: `_flow_state` remains `RESTORING`; no additional calls on any doubles

**AC-8 — project.godot autoload entry**
- Given: `project.godot` source file
- When: grep for `FailureRespawn=` in the `[autoload]` block
- Then: exactly one match: `FailureRespawn="*res://src/gameplay/failure_respawn/failure_respawn_service.gd"`; the line appears after `Combat=` and before `MissionLevelScripting=`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/failure_respawn/autoload_scaffold_test.gd` — must exist and pass (AC-1 through AC-8)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Level Streaming story-003 (`register_restore_callback` API must exist — LS stub satisfies the call signature even if the callback chain is not yet wired)
- Unlocks: Story 002 (CAPTURING body), Story 003 (signal emission), Story 004 (section_entered body), Story 005 (restore callback body)
