# Story 002: Signal subscription lifecycle + forbidden-pattern fences

> **Epic**: HUD Core
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 2–3 hours (S — 14 connect/disconnect blocks + test file)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-core.md`
**Requirement**: TR-HUD-002, TR-HUD-003, TR-HUD-013, TR-HUD-015
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: HUD Core is a subscriber-only node — it emits zero signals and never pushes state to other systems (TR-HUD-003, TR-HUD-015). All 9 Events autoload signals are connected in `_ready()` and disconnected in `_exit_tree()` with `is_connected()` guards (ADR-0002 §IG3). Every Node-typed signal payload is checked with `is_instance_valid()` before dereferencing (ADR-0002 §IG4). The full subscription list is exactly 14 connections: 9 Events bus signals, 1 Settings signal, 3 local Timer child signals, 1 viewport `size_changed` signal (GDD CR-1 REV-2026-04-26). The 9 Events bus signals are the 8 frozen domain signals (`player_health_changed`, `player_damaged`, `player_died`, `player_interacted`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected`) plus `ui_context_changed` from the 2026-04-28 ADR-0002 amendment (UI domain).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal `connect` / `disconnect` / `is_connected` API is stable since Godot 4.0. String-based `connect()` is forbidden — use typed signal connections (`Events.player_health_changed.connect(_on_health_changed)`) per the control manifest Forbidden APIs table. ADR-0002 Status: Accepted (promoted 2026-04-29 after Sprint 01 verification).

**Control Manifest Rules (Foundation — Signal Bus ADR-0002)**:
- Required: connect in `_ready()`, disconnect in `_exit_tree()` with `is_connected()` guard before each disconnect (ADR-0002 §IG3)
- Required: `is_instance_valid(node)` check before dereferencing any Node-typed signal payload (ADR-0002 §IG4)
- Required: use direct emit pattern (`Events.<signal>.emit(args)`) at emit sites — but HUD Core emits zero signals; this rule is documented as the reason HUD never calls `Events.*.emit()`
- Forbidden: `hud_subscribing_to_internal_state` — HUD connects only to Events signals + Settings signal + Timer child signals + viewport signal; never to internal game-system methods or properties
- Forbidden: `hud_pushing_visibility_to_other_ui` — HUD never sets `visible` on any node outside its own widget tree; subscribers manage own visibility (ADR-0004 §IG5)
- Forbidden: `event_bus_wrapper_emit` — no `Events.emit_player_damaged(args)` style wrapper calls
- Guardrail: Signal Bus emit cost bounded by per-signal frequency × subscriber count; all 43 events safe at expected frequencies (ADR-0002 §IG5)

---

## Acceptance Criteria

*From GDD `design/gdd/hud-core.md` §H.1, §H.10, CR-1–CR-2, TR-HUD-002/003/013/015:*

- [ ] **AC-1** (TR-HUD-002, AC-HUD-1.1): GIVEN the HUD Core scene is loaded and `Events` autoload is initialised per ADR-0007, WHEN HUD `_ready()` completes, THEN all 14 connections per CR-1 are verified: (A) 9 Events signals (`player_health_changed`, `player_damaged`, `player_died`, `player_interacted`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected`, `ui_context_changed`) — `Events.[signal].is_connected(handler) == true` for each; (B) 1 Settings signal (`Settings.setting_changed.is_connected(_on_setting_changed) == true`); (C) 3 local Timer signals (`_flash_timer.timeout`, `_dry_fire_timer.timeout`, `_gadget_reject_timer.timeout` each `is_connected(...) == true`); (D) 1 viewport signal (`get_viewport().size_changed.is_connected(_update_hud_scale) == true`). Total: 14 connections.

- [ ] **AC-2** (TR-HUD-002, AC-HUD-1.2): GIVEN HUD Core is connected with all 14 signals per CR-1, WHEN `_exit_tree()` is called, THEN all 14 are explicitly disconnected (each with an `is_connected()` guard before the `disconnect()` call) and `[source].[signal].is_connected(handler) == false` for each with no GDScript error emitted.

- [ ] **AC-3** (AC-HUD-1.3): GIVEN `src/ui/hud_core/**/*.gd` (excluding `tests/`), WHEN a CI grep runs for `.connect(` calls outside function bodies named `_ready`, THEN zero matches are found. All signal connections live exclusively in `_ready()`.

- [ ] **AC-4** (AC-HUD-1.4): GIVEN a live session where `section_entered` fires once, WHEN the HUD scene is interrogated after the transition, THEN each signal still has exactly 1 connection to its handler — no double-connect, no spurious disconnect. HUD persists across section transitions without re-subscribing (CR-15).

- [ ] **AC-5** (TR-HUD-003, AC-HUD-10.1): GIVEN `src/ui/hud_core/**/*.gd` (excluding `tests/`), WHEN grep runs pattern `Events\.[a-zA-Z_]+\.emit\(`, THEN zero matches (FP-1: subscriber-only contract; HUD emits zero signals).

- [ ] **AC-6** (TR-HUD-015, AC-HUD-10.7): GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `InputContext\.(push|pop|set)\(`, THEN zero matches (FP-7: HUD never modifies InputContext; it reacts via `ui_context_changed` signal only).

- [ ] **AC-7** (TR-HUD-013, AC-HUD-10.3): GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(InventorySystem|CombatSystemNode|StealthAI|CivilianAI|FailureRespawnService|MissionScriptingService)\.[a-zA-Z_]+\(`, THEN zero matches (FP-3: no polling of non-authorised systems).

- [ ] **AC-8** (TR-HUD-013, AC-HUD-10.5): GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `weapon_dry_fire_click\.connect`, THEN zero matches (FP-5: Audio's exclusive subscription; HUD detects dry-fire via unchanged-value `ammo_changed` per CR-8 — Story 005).

- [ ] **AC-9** (AC-HUD-10.2): GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `pc\.(health|max_health|current_health|stamina|is_crouching|is_sprinting|inventory)`, THEN zero matches (FP-2: no direct PC property access beyond the two authorised query methods).

- [ ] **AC-10** (AC-HUD-10.10 + AC-HUD-12.1): GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(register_restore_callback|func capture\(\))`, THEN zero matches (FP-12: HUD has no save/load registration; CR-20).

- [ ] **AC-11** (AC-HUD-10.6): GIVEN `src/ui/hud_core/**/*.gd` and `**/*.tscn`, WHEN grep runs pattern `(waypoint|minimap|objective_marker|alert_indicator|radar|compass|map_overlay|nav_arrow)`, THEN zero matches (FP-6: Pillar 2 + Pillar 5 absolute exclusion).

- [ ] **AC-12** (AC-HUD-10.11): GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(Engine\.get_singleton|get_tree\(\)\.root\.get_node)`, THEN zero matches (FP-14: no raw tree-walk singleton lookup).

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines + GDD §C.1 CR-1–CR-2:*

**Subscription block pattern in `_ready()` (one block per connection group):**

```gdscript
func _ready() -> void:
    # (A) Events autoload — 9 connections
    Events.player_health_changed.connect(_on_health_changed)
    Events.player_damaged.connect(_on_player_damaged)
    Events.player_died.connect(_on_player_died)
    Events.player_interacted.connect(_on_player_interacted)
    Events.ammo_changed.connect(_on_ammo_changed)
    Events.weapon_switched.connect(_on_weapon_switched)
    Events.gadget_equipped.connect(_on_gadget_equipped)
    Events.gadget_activation_rejected.connect(_on_gadget_activation_rejected)
    Events.ui_context_changed.connect(_on_ui_context_changed)  # ADR-0002 2026-04-28 amendment

    # (B) Settings — 1 connection
    Settings.setting_changed.connect(_on_setting_changed)

    # (C) Timer child signals — 3 connections
    _flash_timer.timeout.connect(_on_flash_timer_timeout)
    _dry_fire_timer.timeout.connect(_on_dry_fire_timer_timeout)
    _gadget_reject_timer.timeout.connect(_on_gadget_reject_timeout)

    # (D) Viewport — 1 connection
    get_viewport().size_changed.connect(_update_hud_scale)
```

**Disconnect block pattern in `_exit_tree()` (one `is_connected()` guard per disconnect):**

```gdscript
func _exit_tree() -> void:
    if Events.player_health_changed.is_connected(_on_health_changed):
        Events.player_health_changed.disconnect(_on_health_changed)
    # ... (one guard+disconnect per connection — all 14)
    if get_viewport().size_changed.is_connected(_update_hud_scale):
        get_viewport().size_changed.disconnect(_update_hud_scale)
```

**Handler stubs (this story):** All handler functions (`_on_health_changed`, `_on_player_damaged`, etc.) are declared as stubs with `pass` body in this story. Their logic is implemented in Stories 003, 004, and 005. The test for AC-1/AC-2 verifies connection plumbing, not handler behaviour.

**`is_instance_valid()` contract (ADR-0002 §IG4):** every handler that receives a Node-typed payload (e.g., `_on_player_interacted(target: Node3D)`) must open with `if not is_instance_valid(target): return`. The stub in this story includes the guard pattern as a comment, to be filled in by the story that implements the handler logic.

**Timer child nodes:** three `Timer` child nodes must be added to the `hud_core.tscn` scene: `_flash_timer` (`one_shot = true`, `wait_time = 0.333`), `_dry_fire_timer` (`one_shot = true`, `wait_time = 0.333`), `_gadget_reject_timer` (`one_shot = true`, `wait_time = 0.2`). These are declared as `@onready var` references in `hud_core.gd` — not `$NodePath` lookups inside `_process()` (control manifest Forbidden APIs).

**Forbidden pattern test file:** `tests/unit/presentation/hud_core/test_forbidden_patterns.gd` aggregates all CI grep gates from §H.10. Each grep gate is one GUT test function that reads a source file list and asserts zero matches for the registered pattern. The file is extended by later stories but the scaffold and AC-HUD-10.1, 10.2, 10.3, 10.5, 10.6, 10.7, 10.10, 10.11 patterns are established here.

**`hud_subscribing_to_internal_state` fence:** registered as a CI grep pattern in the forbidden-pattern test. Definition: any `connect()` call in `hud_core.gd` that connects to a signal NOT in the 14-connection list. Implementation: the grep test asserts that only the listed 9 Events signals + `Settings.setting_changed` appear as `.connect()` targets in `hud_core.gd`. All other `connect()` calls are Timer child signals and the viewport signal — both scoped to `self`-owned or child nodes.

**`hud_pushing_visibility_to_other_ui` fence:** registered as a CI grep pattern. Definition: any `[node_reference].visible =` write in `hud_core.gd` where `[node_reference]` resolves to a node outside the HUD Core scene tree. The pattern `(?<!\bself\b)\.visible\s*=` with a sibling-scope guard is complex; the pragmatic CI gate is: `grep -n "\.visible\s*=" src/ui/hud_core/hud_core.gd` and a manual review that every match targets a widget child of `self`, not an external node. Document this as an advisory grep (not fully automatable at this stage).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Scene scaffold (the node tree that signals connect to must exist before this story runs)
- **Story 003**: Handler logic for `_on_health_changed`, `_on_player_damaged`, `_on_player_died`, Tween.kill() wiring
- **Story 004**: Handler logic for `_on_weapon_switched`, `_on_ammo_changed`, `_on_gadget_equipped`, `_on_gadget_activation_rejected`, `_on_player_interacted`; `_on_ui_context_changed` full implementation; `_process` resolver
- **Story 005**: Handler logic for `_on_setting_changed`; photosensitivity opt-out wiring
- Post-VS: `_on_gadget_equipped` full icon-load logic (gadget tile deferred); `_on_gadget_activation_rejected` desat logic (gadget tile deferred)

---

## QA Test Cases

**AC-1 — 14 connections verified after _ready()**
- Given: `hud_core.tscn` loaded with `Events` autoload and `Settings` autoload present; `_flash_timer`, `_dry_fire_timer`, `_gadget_reject_timer` child Timer nodes present
- When: `_ready()` completes on the HUDCore node
- Then: `Events.player_health_changed.is_connected(_on_health_changed) == true` (and 8 more Events checks); `Settings.setting_changed.is_connected(_on_setting_changed) == true`; `_flash_timer.timeout.is_connected(_on_flash_timer_timeout) == true`; `_dry_fire_timer.timeout.is_connected(_on_dry_fire_timer_timeout) == true`; `_gadget_reject_timer.timeout.is_connected(_on_gadget_reject_timeout) == true`; `get_viewport().size_changed.is_connected(_update_hud_scale) == true`
- Edge cases: Events autoload not yet ready when `_ready()` fires → per ADR-0007, Events is autoload line 1, guaranteed to be in tree before scene nodes; test explicitly checks that no GDScript error fires (autoload nil)

**AC-2 — All 14 disconnections on _exit_tree()**
- Given: HUDCore node with all 14 connections established
- When: `_exit_tree()` fires (node removed from tree or scene freed)
- Then: All 14 `is_connected()` guards execute; all 14 `disconnect()` calls execute; all 14 checks `[signal].is_connected(handler) == false` pass; no GDScript error from double-disconnect or missing-connection guard
- Edge cases: `_exit_tree()` called before `_ready()` (node added then immediately removed) → no connections exist; `is_connected()` returns `false`; `disconnect()` not called; no error

**AC-3 — No .connect() calls outside _ready()**
- Given: `src/ui/hud_core/**/*.gd` source files
- When: grep pattern `\.connect\(` across all function bodies except `func _ready()`
- Then: zero matches (excludes comments)
- Edge cases: Timer `timeout` signals connected inside `_ready()` via `_timer.timeout.connect(...)` — these are valid; ensure grep excludes `_ready()` body correctly

**AC-4 — No double-connect on section_entered**
- Given: HUDCore instance alive across a `section_entered` signal emission
- When: `section_entered` fires once
- Then: Each Events signal still has exactly 1 connection to its handler (not 2); signal count check via `Events.player_health_changed.get_connections().size() == 1`
- Edge cases: if HUD scene is re-instanced (should not happen on `section_entered` per CR-15), the new instance connects fresh; old instance disconnects in `_exit_tree()`

**AC-5 — Zero Events emit calls (FP-1)**
- Given: `src/ui/hud_core/**/*.gd` (excluding `tests/`)
- When: grep `Events\.[a-zA-Z_]+\.emit\(`
- Then: zero matches
- Edge cases: comments containing `emit(` must be excluded

**AC-6–AC-12 — Forbidden pattern grep gates**
- For each FP: given the source files; when the documented grep pattern runs; then zero matches
- All patterns documented in GDD §C.6 and AC-HUD-10.x; test file aggregates them in deterministic, isolated test functions (each function is a separate GUT test)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/hud_core/test_subscription_lifecycle_unit.gd` — must exist and pass (AC-1, AC-2, AC-3, AC-4)
- `tests/unit/presentation/hud_core/test_forbidden_patterns.gd` — must exist and pass (AC-5 through AC-12; this file is extended by later stories)
- Integration test `tests/integration/presentation/hud_core/test_subscription_lifecycle.gd` — AC-1, AC-2, AC-4 at integration level (full scene loading with live autoloads)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (scene scaffold + node tree must exist before signals can be connected)
- Unlocks: Story 003 (health widget logic needs subscription plumbing in place), Story 004 (prompt-strip logic), Story 005 (settings wiring)
