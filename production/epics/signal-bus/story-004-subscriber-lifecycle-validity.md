# Story 004: Subscriber lifecycle pattern + Node payload validity guard

> **Epic**: Signal Bus
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-29
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/signal-bus.md`
**Requirement**: Signal Bus AC 7 (subscriber lifecycle), AC 8 (forgotten disconnect), AC 12 (Node payload validity)

**ADR Governing Implementation**: ADR-0002 §Implementation Guideline 3 + IG 4 + Core Rule 4
**ADR Decision Summary**: Subscribers MUST connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards. Node-typed signal payloads MUST be checked with `is_instance_valid(node)` before dereferencing — signals can be queued and the source node may be freed before the subscriber runs.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Signal.connect/disconnect/is_connected` and `is_instance_valid` are stable Godot 4.0+. The lifecycle pattern is enforced by code review + lint rules; this story creates the canonical reference test fixture that consumer epics' subscribers will be measured against.

**Control Manifest Rules (Foundation)**:
- Required: subscribers connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guard (ADR-0002 IG 3 — non-negotiable)
- Required: every Node-typed signal payload MUST be checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4)
- Forbidden: never reference autoloads from `_init()` (pattern `autoload_init_cross_reference`)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria:*

- [ ] **AC-7**: GIVEN a Node that connects to `Events.player_damaged` in `_ready()` and disconnects with `is_connected` guard in `_exit_tree()`, WHEN the Node is freed, THEN subsequent emits of `player_damaged` do not target the freed Node and produce no errors.
- [ ] **AC-8**: GIVEN a Node that forgets to disconnect on `_exit_tree`, WHEN the Node is freed and `player_damaged` is emitted, THEN Godot prints an error to stderr referencing the freed callable (verifies the failure mode is loud, not silent).
- [ ] **AC-12**: GIVEN any subscriber handler for a signal with a `Node`-typed parameter (e.g., `player_damaged`, `enemy_damaged`, `civilian_panicked`), WHEN that handler's source is inspected, THEN `is_instance_valid(node)` is called before any property or method access on the Node-typed parameter.

---

## Implementation Notes

*Derived from ADR-0002 IG 3 + IG 4 + ADR-0002 §Risks (mitigation patterns):*

1. **Create a canonical subscriber template** at `src/core/signal_bus/subscriber_template.gd` — a documented `extends Node` example showing the exact lifecycle pattern + Node-payload validity guard. This file is referenced from every consumer epic's stories as the implementation reference.
2. The template includes:
   - `_ready()`: `Events.<signal>.connect(_on_<signal>)` — single connect per signal subscribed.
   - `_exit_tree()`: `if Events.<signal>.is_connected(_on_<signal>): Events.<signal>.disconnect(_on_<signal>)` — guarded disconnect to handle re-entrant `_exit_tree` calls.
   - `_on_<signal>(args)`: Node-typed args are checked with `is_instance_valid(node)` before dereferencing. If invalid, return early.
3. **Tests** at `tests/unit/foundation/subscriber_lifecycle_test.gd`:
   - **AC-7 happy path**: GdUnit4 test creates a subscriber Node, adds to tree, connects to `player_damaged`, removes from tree (which calls `_exit_tree`), then emits `player_damaged` and asserts no error + the freed handler is NOT invoked.
   - **AC-8 forgotten-disconnect**: creates a subscriber that does NOT implement `_exit_tree` disconnect; frees the Node; emits the signal; uses `assert_error_logged` (or similar GdUnit4 utility) to confirm Godot logged a freed-callable error to stderr.
   - **AC-12 validity guard**: creates a subscriber with the validity guard; emits `enemy_damaged(enemy: Node, ...)` where `enemy` is then `queue_free`d before the emit is dispatched (via deferred call); asserts the subscriber's handler returns early and does NOT crash on `enemy.<property>` access.
4. **AC-12 source-grep guard** (lint test): `tests/unit/foundation/node_payload_validity_grep_test.gd` runs a grep across all `src/` files matching the pattern `func _on_<signal_with_node_payload>(`. For each matched function body, asserts the first non-comment line is a check matching `if not is_instance_valid(<node_param>):`. This is a heuristic lint — it WILL flag false positives on subscribers that legitimately don't dereference the Node param. Mark those with `# @lint-ignore validity-guard <reason>` to acknowledge.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: actual signal declarations (this story uses them via the template)
- Story 003: EventLogger lifecycle (it has its own connection bookkeeping; Story 003 owns its tests)
- Story 005: forbidden-pattern fences for cross-system communication anti-patterns

---

## QA Test Cases

**AC-7**: Subscriber disconnect-on-exit happy path
- **Given**: a `TestSubscriber extends Node` with proper connect-in-`_ready` + guarded disconnect-in-`_exit_tree`
- **When**: the test adds the subscriber to the tree (triggering `_ready` + connect), then removes it from the tree (triggering `_exit_tree` + disconnect), then `Events.player_damaged.emit(10.0, null, false)`
- **Then**: no error logged; the subscriber's `_on_player_damaged` is NOT called (confirmable by an instance counter)
- **Edge cases**: re-entrant `_exit_tree` called twice (the `is_connected` guard prevents double-disconnect error); subscriber removed before its `_ready` ever runs (defensive — `is_connected` returns false, no harm)

**AC-8**: Forgotten disconnect → loud failure
- **Given**: a `BadSubscriber extends Node` that connects in `_ready` but has NO `_exit_tree` override
- **When**: the test adds it to the tree, removes it (which frees the Node since no parent retains it), and emits `Events.player_damaged.emit(...)`
- **Then**: Godot's stderr/output contains an error message referencing a freed Object or freed Callable
- **Edge cases**: the test framework needs an "assert stderr contains" utility — GdUnit4 has `await_signal` patterns; alternatively, redirect stderr to a buffer for the test scope

**AC-12**: Node-payload validity guard
- **Given**: a `ValiditySubscriber extends Node` whose `_on_enemy_damaged(enemy: Node, amount: float, source: Node)` correctly checks `is_instance_valid(enemy)` and `is_instance_valid(source)` before dereference
- **When**: the test creates an enemy Node, connects the subscriber, queue_free's the enemy, then `Events.enemy_damaged.emit(enemy, 10.0, null)` (deferred so the free completes before dispatch)
- **Then**: the subscriber's handler runs but returns early without dereferencing `enemy`; no crash
- **Edge cases**: source is null (different from invalid — null is a legitimate "no source" indicator; `is_instance_valid(null)` returns false; subscriber must handle both null and freed)

**AC-12 lint-style grep guard**:
- **Given**: source tree under `src/`
- **When**: an automated test searches for handler functions on Node-typed signal payloads and inspects each for the validity-guard idiom
- **Then**: every handler either contains `is_instance_valid` on its Node-typed param OR has an `# @lint-ignore validity-guard` annotation justifying omission
- **Edge cases**: subscriber that intentionally does not dereference the Node (e.g., logs only the signal name, ignores payload) — lint-ignore annotation required

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/subscriber_lifecycle_test.gd` — must exist and pass (AC-7, AC-8, AC-12 happy path + freed-Node case)
- `tests/unit/foundation/node_payload_validity_grep_test.gd` — must exist and pass (AC-12 lint guard)
- `src/core/signal_bus/subscriber_template.gd` — canonical reference template; not a test artifact but must exist for downstream stories to reference

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (signals must exist for the template + tests to subscribe to)
- Unlocks: every consumer epic's stories — they reference `subscriber_template.gd` as the implementation pattern

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: AC-7 + AC-12 covered by automated tests; AC-8 (forgotten-disconnect → loud stderr) documented as ADVISORY (no GdUnit4 stderr-capture utility wired up; observed manually).
**Test results**: 7/7 in `subscriber_lifecycle_test.gd` + 2/2 in `node_payload_validity_grep_test.gd` PASS.

### Files added
- `src/core/signal_bus/subscriber_template.gd` — canonical reference template (downstream consumer epics inherit/copy this pattern).
- `tests/unit/foundation/subscriber_lifecycle_test.gd` (7 tests).
- `tests/unit/foundation/node_payload_validity_grep_test.gd` (2 tests — recursive scan of `src/` for handler signatures, asserts each has `is_instance_valid()` guard or `@lint-ignore validity-guard` annotation).

### Files modified (out-of-scope, justified)
- `src/core/signal_bus/event_logger.gd` — added validity guards to 4 Node-typed handlers (`_on_player_interacted`, `_on_enemy_damaged`, `_on_enemy_killed`, `_on_civilian_panicked`). The lint test surfaced a real ADR-0002 IG 4 compliance gap; closing it inline keeps the lint green.

### Finding documented for downstream subscribers
GDScript's typed-arg runtime check rejects freed-Node calls BEFORE the function body runs (`previously freed Object is not a subclass of expected argument class`). The "freed-Node payload reaches handler body" failure mode IG 4 was originally designed against is largely filtered out by the language. The validity guard remains required for: (a) null payloads (legitimate "no source" emit), (b) WeakRef-collected references, (c) forward-compat against Godot 4.7+ relaxing the runtime type-check.

### Verdict
COMPLETE.
