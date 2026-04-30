# Story 006: Health system (apply_damage, apply_heal, signals)

> **Epic**: Player Character
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (M — apply_damage rounding, death transition, signal emission order, apply_heal, DEAD guard)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/player-character.md`
**Requirements**: TR-PC-010, TR-PC-011, TR-PC-015
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: All four player signals (`player_damaged`, `player_died`, `player_health_changed`, `player_interacted`) are emitted via the `Events` autoload using direct emit (`Events.<signal>.emit(args)`). Signal enum payloads (`CombatSystemNode.DamageType`, `CombatSystemNode.DeathCause`) are defined on `CombatSystemNode`, NOT on `Events`. Node-typed signal payloads (`source: Node`) require `is_instance_valid(source)` checks in subscribers (ADR-0002 IG 4). `player_died` must fire at most ONCE per death — the DEAD-state early-return guard prevents re-entry.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `round()` in GDScript 4.6 uses round-half-away-from-zero for positive floats (`round(0.5) == 1`, `round(0.49) == 0`) — this is the GDD's intended boundary (systems-designer B1, 2026-04-21 verification). No post-cutoff API risk. `CombatSystemNode.DamageType` and `CombatSystemNode.damage_type_to_death_cause()` are forward dependencies (stub `DamageType.TEST` value acceptable until Combat & Damage GDD lands).

**Control Manifest Rules (Foundation + Core)**:
- Required: `Events.<signal>.emit(args)` — direct emit, no wrapper methods (ADR-0002 forbidden pattern `event_bus_wrapper_emit`)
- Required: subscribers check `is_instance_valid(source)` before dereferencing the `source: Node` payload (ADR-0002 IG 4) — enforced at code review, not a PC responsibility
- Forbidden: health mutation outside `apply_damage` or `apply_heal` — pattern `health_mutation_outside_apply_damage`
- Forbidden: `player_died` emitted more than once per death (DEAD-state guard is the enforcement mechanism)

---

## Acceptance Criteria

*From GDD `design/gdd/player-character.md` §Acceptance Criteria AC-5, AC-10:*

- [ ] **AC-5.1 [Logic]** `apply_damage(25.0, stub_source, CombatSystemNode.DamageType.TEST)` from `health=100`: `health == 75` afterwards; `player_damaged(25.0, stub_source, false)` fires BEFORE `player_health_changed(75.0, 100.0)` — signal-order verified via spy.
- [ ] **AC-5.2 [Logic]** **Rounding boundary (parametrized over {0.3, 0.49, 0.5, 1.5})**:
  - `apply_damage(0.3, ...)`: `health` unchanged; zero signals emitted.
  - `apply_damage(0.49, ...)`: `health` unchanged; zero signals emitted.
  - `apply_damage(0.5, ...)`: `health` decreases by exactly 1; both `player_damaged(0.5, ...)` and `player_health_changed(99, 100)` emit.
  - `apply_damage(1.5, ...)`: `health` decreases by exactly 2; both signals emit with raw `1.5` in `player_damaged.amount` payload.
- [ ] **AC-5.3 [Logic]** `apply_damage(999.0, stub_source, DamageType.TEST)` from full health: `health == 0`; `player_died` fires exactly once with `cause == CombatSystemNode.damage_type_to_death_cause(DamageType.TEST)`; `current_state == PlayerEnums.MovementState.DEAD`; subsequent `apply_damage` calls emit no additional signals (DEAD-state guard).
- [ ] **AC-10.1 [Logic]** All player signals are emitted through the `Events` autoload, not via direct node-to-node connections. Verified by spying on `Events` autoload signal emissions during a full `apply_damage` + interact sequence.
- [ ] **AC-10.2 [Logic]** **Signal rate guard**: drive 300 `_physics_process` ticks at `delta = 1.0/60.0` exercising all state transitions (Idle → Walk → Sprint → Crouch → Jump → Fall → Landing → Interact → Damage → Respawn). Assert: `player_damaged_count ≤ 150`, `player_health_changed_count ≤ 150`, `player_interacted_count ≤ 150`, `player_died_count ≤ 5`.
- [ ] **AC-heal [Logic]** `apply_heal(20.0, stub_source)` from `health=80`, `max_health=100`: `health == 100` (capped at `max_health`); `player_health_changed(100.0, 100.0)` fires once. `apply_heal(0.0, ...)` emits `push_warning` and does nothing. `apply_heal(0.49, ...)` rounds to 0 and does nothing. DEAD state blocks heal: `apply_heal(20.0, ...)` while DEAD → no health change, no signal.
- [ ] **AC-latch-clear [Logic]** DEAD-state latch clearance: latch a `JUMP_TAKEOFF` spike; then `apply_damage(999.0, ...)` on the next physics tick; assert `get_noise_event() == null` AND `get_noise_level() == 0.0` on the same post-damage frame (Story 004 coordination).
- [ ] **AC-damage-cancel-interact [Logic]** E.6 damage-cancel: if `amount >= interact_damage_cancel_threshold` (default 10 HP) and `_is_hand_busy == true`, the in-flight interact Tween is killed and `_is_hand_busy = false` is set in the SAME method call as `Tween.kill()` (not in a `tween_finished` callback). `player_interacted` does NOT fire for the cancelled interact.

---

## Implementation Notes

*Derived from GDD §Formulas F.6, F.7 + §Edge Cases E.6, E.7, E.13:*

**F.6 `apply_damage()`** (only health mutator):
```gdscript
func apply_damage(amount: float, source: Node, damage_type: CombatSystemNode.DamageType) -> void:
    if current_state == PlayerEnums.MovementState.DEAD:
        return
    if amount <= 0.0:
        push_warning("apply_damage called with non-positive amount %f — ignored" % amount)
        return
    var rounded: int = int(round(amount))
    if rounded <= 0:
        return
    health = max(0, health - rounded)
    Events.player_damaged.emit(amount, source, false)   # is_critical false at MVP
    Events.player_health_changed.emit(float(health), float(max_health))
    if health == 0:
        current_state = PlayerEnums.MovementState.DEAD
        _latched_event = null   # ai-programmer B-1 fix: clear stale spike on death
        var cause: CombatSystemNode.DeathCause = CombatSystemNode.damage_type_to_death_cause(damage_type)
        Events.player_died.emit(cause)
```

Signal emission ORDER is load-bearing (AC-5.1): `player_damaged` fires BEFORE `player_health_changed`. HUD reads the new health from `player_health_changed`; analytics subscribers read the raw amount from `player_damaged`. Swapping the order is a forbidden pattern.

**Damage-cancel interact (E.6)**:
```gdscript
if amount >= interact_damage_cancel_threshold and _is_hand_busy:
    _is_hand_busy = false   # flag-first ordering per GDD Detailed Design §Respawn contract
    _interact_tween.kill()
    # player_interacted is NOT emitted for a cancelled interact
```
`_is_hand_busy` must be cleared in the SAME stack frame as `Tween.kill()`. Never in a `tween_finished` callback — `kill()` suppresses that callback.

**E.7 Simultaneous damage on same frame**: each `apply_damage()` processes sequentially. Two `player_damaged` signals fire; `player_health_changed` fires twice (intermediate + final); `player_died` fires at most once (guarded by DEAD-state early return).

**F.7 `apply_heal()`**:
```gdscript
func apply_heal(amount: float, source: Node) -> void:
    if current_state == PlayerEnums.MovementState.DEAD:
        return
    if amount <= 0.0:
        push_warning("apply_heal called with non-positive amount %f — ignored" % amount)
        return
    var rounded: int = int(round(amount))
    if rounded <= 0:
        return
    health = min(max_health, health + rounded)
    Events.player_health_changed.emit(float(health), float(max_health))
```

No dedicated `player_healed` signal at MVP — HUD listens to `player_health_changed` for both damage and heal paths. `apply_damage` and `apply_heal` are kept separate so callers cannot smuggle heals through negative-damage calls.

`CombatSystemNode.DamageType` is a forward dependency. Until Combat & Damage GDD lands, a stub file at `res://src/gameplay/combat/combat_system_node.gd` provides `class_name CombatSystemNode` with `enum DamageType { TEST, OUT_OF_BOUNDS }` and a stub `damage_type_to_death_cause()` returning `0` (UNKNOWN). This stub carries a `# TODO: replace when Combat & Damage GDD lands` comment.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Scene root (health initialized on `max_health` in `_ready()` — variable declaration here, initialization in scaffold)
- Story 003: Dead state camera animation (800 ms pitch-down) — movement story owns state transitions
- Story 005: `_interact_tween` reference and `_is_hand_busy` field (interact story owns those; this story reads them for E.6 but does not create them)
- Story 007: `reset_for_respawn()` restoring `health = max_health` after death

---

## QA Test Cases

**AC-5.1 — Basic damage + signal order**
- Given: `PlayerCharacter` at `health = 100`; `Events` signal spy connected to `player_damaged` and `player_health_changed`
- When: `apply_damage(25.0, stub_source, DamageType.TEST)` called
- Then: `health == 75`; spy log shows `player_damaged` fired before `player_health_changed`; `player_damaged.amount == 25.0`, `player_damaged.is_critical == false`; `player_health_changed.current == 75.0`, `.max_health == 100.0`
- Edge cases: `source` is a freed node → subscriber must `is_instance_valid()` check (documented in ADR-0002 IG 4; not tested here but noted)

**AC-5.2 — Rounding boundary parametrized**
- Given: `health = 100` for each sub-test
- When: `apply_damage(0.3, ...)`, `apply_damage(0.49, ...)`, `apply_damage(0.5, ...)`, `apply_damage(1.5, ...)`
- Then: 0.3 → health unchanged, 0 signals; 0.49 → health unchanged, 0 signals; 0.5 → health 99, 2 signals (`player_damaged(0.5)` + `player_health_changed(99, 100)`); 1.5 → health 98, 2 signals (`player_damaged(1.5)` + `player_health_changed(98, 100)`)
- Edge cases: `round(0.5) == 1` in Godot 4.6 (round-half-away-from-zero) — test verifies this is the actual engine behavior

**AC-5.3 — Lethal damage + DEAD guard**
- Given: `health = 100`
- When: `apply_damage(999.0, stub_source, DamageType.TEST)`
- Then: `health == 0`; `current_state == DEAD`; `player_died` fires once; spy confirms `cause == damage_type_to_death_cause(DamageType.TEST)` 
- When: additional `apply_damage(10.0, ...)` called while DEAD
- Then: no signals fire; `health` stays `0`; `current_state` stays `DEAD`
- Edge cases: two lethal damage calls on same frame (E.7) → `player_died` fires exactly once

**AC-10.1 — Signals via Events autoload**
- Given: `Events` spy connected to all player signals; signal spy watching `PlayerCharacter` node directly
- When: `apply_damage(25.0, ...)` + interact sequence
- Then: emissions are on `Events.*` not on the player node directly; verify via spy call counts: `Events.player_damaged` fires ≥ 1; `PlayerCharacter.player_damaged` fires 0 (no direct node signals)
- Edge cases: if signals are declared on PlayerCharacter AND re-emitted via Events → double emission; test ensures single-path only

**AC-10.2 — Signal rate over 300 ticks**
- Given: mock state driver scripting a 300-tick sequence through all state transitions
- When: simulated via `_physics_process(1.0/60.0)` called 300 times
- Then: total signal counts within bounds: damaged ≤ 150, health_changed ≤ 150, interacted ≤ 150, died ≤ 5
- Edge cases: per-frame health spam (e.g., DoT tick emitting `player_health_changed` every frame) → count would exceed 300; test catches runaway emission

**AC-heal — apply_heal contract**
- Given: `health = 80`, `max_health = 100`
- When: `apply_heal(20.0, stub_source)`
- Then: `health == 100`; `player_health_changed(100.0, 100.0)` fires once; no over-heal above max
- When: `apply_heal(0.0, ...)` 
- Then: `push_warning` fired; health unchanged; no signal
- When: DEAD state; `apply_heal(20.0, ...)`
- Then: health stays 0; no signal

**AC-latch-clear — DEAD clears noise latch**
- Given: `JUMP_TAKEOFF` spike latched (`get_noise_event() != null`)
- When: `apply_damage(999.0, ...)` on next physics tick
- Then: on same post-damage frame: `get_noise_event() == null`; `get_noise_level() == 0.0`

**AC-damage-cancel-interact — Tween killed on threshold damage**
- Given: interact in flight (`_is_hand_busy == true`, `_interact_tween` running)
- When: `apply_damage(10.0, ...)` (>= `interact_damage_cancel_threshold`)
- Then: `_is_hand_busy == false` immediately (same stack frame); `_interact_tween` is no longer running; `player_interacted` signal NOT emitted
- Edge cases: sub-threshold damage (5 HP, `interact_damage_cancel_threshold = 10`) → interact continues; `_is_hand_busy` stays true

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/player_character/player_damage_basic_test.gd` — must pass (AC-5.1)
- `tests/unit/core/player_character/player_damage_rounding_guard_test.gd` — must pass (AC-5.2)
- `tests/unit/core/player_character/player_damage_lethal_test.gd` — must pass (AC-5.3)
- `tests/unit/core/player_character/player_signal_taxonomy_test.gd` — must pass (AC-10.1, AC-10.2)
- `tests/unit/core/player_character/player_dead_state_latch_clear_test.gd` — must pass (AC-latch-clear)
- `tests/unit/core/player_character/player_heal_test.gd` — must pass (AC-heal)
- `tests/unit/core/player_character/player_damage_cancel_interact_test.gd` — must pass (AC-damage-cancel-interact)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene root + `current_state` field), Story 004 (`_latched_event` field for DEAD-state clear), Story 005 (`_is_hand_busy` + `_interact_tween` for E.6 damage-cancel)
- Unlocks: Story 007 (`reset_for_respawn()` needs health restored to `max_health`), Combat & Damage epic (stub `CombatSystemNode` will be superseded when that GDD lands), Failure & Respawn epic (`player_died` signal)
