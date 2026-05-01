# Story 002: InputContextStack autoload — production implementation

> **Epic**: Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (M — replace stub with production implementation + 2 test files)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/input.md`
**Requirements**: `TR-INP-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry) + ADR-0007 (Autoload Load Order Registry) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: `InputContextStack` is the production implementation of the `InputContext` autoload at line 4 of `project.godot [autoload]` per ADR-0007. It maintains a `push`/`pop` stack of `Context` enum values starting at `GAMEPLAY`. On every push/pop it emits `Events.ui_context_changed(new_ctx, old_ctx)` per ADR-0002's 2026-04-28 UI domain amendment. The autoload key is `InputContext`; the class name is `InputContextStack` — callers MUST use the autoload key, never the class name (per ADR-0004 IG 2 + ADR-0002 class/key split pattern). Holds no node references, calls no methods on UI surfaces, emits no signals directly (only through `Events`).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Autoload lifecycle (`_ready()` fires after the node is added to the scene tree root) is stable since Godot 4.0. `Array[Context]` typed arrays with enum element type are supported in GDScript 4.0+. The `assert()` on stack underflow in `pop()` must NOT be removed — it is the guard against "never pop GAMEPLAY" per ADR-0004 IG 12. `Events.ui_context_changed` signal was added to ADR-0002 on 2026-04-28 with signature `(new: InputContext.Context, old: InputContext.Context)` — verify `events.gd` declares this signal before integrating.

**Control Manifest Rules (Core)**:
- Required: autoload `_ready()` may only reference autoloads at earlier line numbers (ADR-0007 IG 4) — `InputContext` is line 4; it may reference `Events` (line 1), `EventLogger` (line 2), `SaveLoad` (line 3). It MUST NOT reference `LevelStreamingService` (line 5) or any later autoload.
- Required: static typing on all GDScript; `var _stack: Array[Context]` must be typed
- Required: doc comments on all public methods (`push`, `pop`, `current`, `is_active`)
- Required: autoload uses `*res://` scene-mode prefix in `project.godot` (ADR-0007 IG 2)
- Forbidden: `autoload_init_cross_reference` — never reference any autoload from `_init()`; cross-autoload setup belongs in `_ready()` only
- Forbidden: `InputContextStack` autoload emitting signals directly — use `Events.ui_context_changed.emit(...)` only

---

## Acceptance Criteria

*From GDD `design/gdd/input.md` §Acceptance Criteria, scoped to this story:*

- [x] **AC-INPUT-2.1 [Logic] BLOCKING**: `InputContext.push(Context.MENU)` called; `InputContext.is_active(Context.GAMEPLAY)` returns `false`; `InputContext.is_active(Context.MENU)` returns `true`. Evidence: `tests/unit/core/input/input_context_gate_test.gd`.
- [x] **AC-INPUT-9.2 [Logic] BLOCKING**: `Engine.get_main_loop().get_root().get_node("/root/InputContext")` resolves successfully from a `_ready()` callback in a test scene (autoload load-order guarantee per ADR-0007). Evidence: `tests/unit/core/input/input_context_autoload_load_order_test.gd`.
- [x] **Stack invariant [Logic] BLOCKING** (implied by ADR-0004 IG 12): `InputContext._stack` is never empty; `pop()` called with a single-element stack fires the `assert` (stack underflow guard). The base `GAMEPLAY` context is never popped. Evidence: same test file as AC-INPUT-2.1.
- [x] **`Events.ui_context_changed` emitted [Logic] BLOCKING** (implied by ADR-0002 UI domain + GDD §Definition of Done): every `push()` and every `pop()` emits `Events.ui_context_changed(new_ctx: InputContext.Context, old_ctx: InputContext.Context)`. Evidence: `tests/unit/core/input/input_context_gate_test.gd` (subscribe to `Events.ui_context_changed`, assert payload values).
- [x] **Debug action registration [Logic] BLOCKING**: in a debug build, `InputContextStack._ready()` calls `InputActions._register_debug_actions()` wrapped in `if OS.is_debug_build():`. Evidence: `tests/unit/core/input/input_context_gate_test.gd` (verify via `InputMap.has_action(&"debug_toggle_ai")` in debug build).

---

## Implementation Notes

*Derived from ADR-0004 §Key Interfaces + §Implementation Guidelines:*

**File to replace**: `res://src/core/ui/input_context.gd` (Sprint 01 stub — `extends Node` pass-through). The stub is replaced by the full production implementation. Note: the EPIC states the stub exists at `src/core/ui/input_context.gd` but the canonical path per GDD + ADR-0004 IG 2 should be `src/core/ui_framework/input_context.gd` — confirm with the project's existing file layout before writing; the autoload entry in `project.godot` references whichever path is correct.

**Production implementation** (from ADR-0004 §Key Interfaces verbatim):

```gdscript
## InputContext autoload — manages the push/pop stack of input-routing contexts.
## Autoload key: InputContext. Class name: InputContextStack (intentional split per ADR-0004 IG 2).
## Call sites MUST use the autoload key (InputContext.push), never the class name.
## Holds NO node references. Calls NO methods on UI surfaces. Emits via Events only.
class_name InputContextStack extends Node

enum Context {
    GAMEPLAY,
    MENU,
    DOCUMENT_OVERLAY,
    PAUSE,
    SETTINGS,
    MODAL,
    LOADING,
}

## The stack always starts with GAMEPLAY at index 0. Never empty.
var _stack: Array[Context] = [Context.GAMEPLAY]

func _ready() -> void:
    # Debug actions registered at runtime — skipped in release builds.
    if OS.is_debug_build():
        InputActions._register_debug_actions()

## Push a new context. Emits Events.ui_context_changed(new_ctx, old_ctx).
func push(ctx: Context) -> void:
    var old_ctx: Context = current()
    _stack.push_back(ctx)
    Events.ui_context_changed.emit(ctx, old_ctx)

## Pop the current context. NEVER pops the base GAMEPLAY context.
## Emits Events.ui_context_changed(new_ctx, old_ctx).
func pop() -> void:
    assert(_stack.size() > 1, "InputContext stack underflow — never pop GAMEPLAY")
    var old_ctx: Context = _stack.pop_back()
    Events.ui_context_changed.emit(current(), old_ctx)

## Returns the currently active context (top of stack).
func current() -> Context:
    return _stack.back()

## Returns true if the given context is currently active (i.e., at top of stack).
func is_active(ctx: Context) -> bool:
    return current() == ctx
```

**project.godot `[autoload]` validation**: confirm line 4 reads `InputContext="*res://src/core/[correct-path]/input_context.gd"`. If the stub was at `src/core/ui/input_context.gd` and the canonical path differs, update the `[autoload]` entry in this story's PR. ADR-0007 §Key Interfaces is authoritative for the exact path.

**`Events.ui_context_changed` signal**: verify `src/core/signal_bus/events.gd` declares `signal ui_context_changed(new: InputContext.Context, old: InputContext.Context)`. This signal was added in the 2026-04-28 ADR-0002 amendment. If the signal is absent, the Signal Bus epic's Story 002 (production signal taxonomy) must add it before this story can pass its emission test.

**Push/pop authority table** (ADR-0004 IG 13): each `Context` value has exactly one authorised pusher and popper. `InputContextStack` itself only manages the stack mechanics — it does NOT push/pop on behalf of other systems. Every system that calls `InputContext.push(ctx)` must be the authorised pusher for that context per the table in ADR-0004 IG 13.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `InputActions` static class + `_register_debug_actions()` method body
- Story 003: Integration tests for context-gated routing across multiple loaded scenes (AC-INPUT-2.2, 2.3, 3.1, 3.2)
- Story 005: Order-of-operations discipline (consume-before-pop); mouse mode restore integration test

---

## QA Test Cases

**AC-INPUT-2.1 + Stack invariant + Events emission**
- **Given**: `InputContextStack` autoload present; `Events.ui_context_changed` signal declared on `events.gd`; a test subscribes to `Events.ui_context_changed` before acting
- **When**: `InputContext.push(InputContext.Context.MENU)` is called
- **Then**: `InputContext.is_active(InputContext.Context.GAMEPLAY)` returns `false`; `InputContext.is_active(InputContext.Context.MENU)` returns `true`; `Events.ui_context_changed` was emitted once with `new = MENU`, `old = GAMEPLAY`
- **When**: `InputContext.pop()` is called
- **Then**: `InputContext.is_active(InputContext.Context.GAMEPLAY)` returns `true`; `Events.ui_context_changed` emitted with `new = GAMEPLAY`, `old = MENU`
- **Edge cases**: pop with empty stack (only GAMEPLAY) → `assert` fires (test uses `expect_signal_not_emitted` pattern or wraps in a trap); push two contexts then pop once → correct intermediate context restored

**AC-INPUT-9.2 — Autoload load order**
- **Given**: project booted with `project.godot [autoload]` block as written; test scene's `_ready()` runs
- **When**: test calls `Engine.get_main_loop().get_root().get_node("/root/InputContext")`
- **Then**: returns a non-null `InputContextStack` node; `InputContext.current() == InputContext.Context.GAMEPLAY`
- **Edge cases**: `InputContext` autoload path missing or incorrect → `get_node()` returns null (test fails clearly)

**Debug action registration**
- **Given**: test running in a debug build (`OS.is_debug_build()` returns `true`); `InputContextStack._ready()` has run
- **When**: test queries `InputMap.has_action(&"debug_toggle_ai")`
- **Then**: returns `true` (registered by `_register_debug_actions()`)
- **When**: test runs in a release/headless build where `OS.is_debug_build()` returns `false`
- **Then**: `InputMap.has_action(&"debug_toggle_ai")` returns `false`
- **Edge cases**: test runner is always headless (may be debug or release build — document which and assert accordingly); if headless runner is release build, skip this assertion or invert it with a guard

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/input/input_context_gate_test.gd` — must exist and pass (AC-INPUT-2.1 + stack invariant + Events emission)
- `tests/unit/core/input/input_context_autoload_load_order_test.gd` — must exist and pass (AC-INPUT-9.2)

**Status**: [x] Created — 2026-04-30 (10 functions across 2 test files; suite 89/89 PASS)

---

## Dependencies

- Depends on: Story 001 (InputActions static class + `_register_debug_actions()` method must exist before `_ready()` calls it); Signal Bus epic Story 002 (production `Events.gd` must declare `ui_context_changed` signal before emission test can pass)
- Unlocks: Story 003 (integration tests require a working `InputContextStack`), Story 005 (order-of-operations tests require a working stack), Story 007 (LOADING context integration requires the full enum)

---

## Completion Notes

**Completed**: 2026-04-30
**Criteria**: 5/5 PASS (all auto-verified)
**Suite**: 89/89 PASS, exit 0
**Files changed (7)**: input_context.gd stub→production, events.gd ui_context_changed signal, event_logger.gd handler+register, EXPECTED_CONNECTION_COUNT 32→33, events_signal_taxonomy_test (new UI domain test), 2 new test files at tests/unit/core/input/.
**Cross-epic handshake closed**: SB-002's deferred ui_context_changed signal restored with `int` payload (avoids Events↔InputContextStack circular import — same pattern as SL-002's save_failed). EventLogger now subscribes to all 33 Events.* signals.
**Deviations**: ADVISORY — events.gd + event_logger.gd modifications planned per SB-002 deferred-UI-domain handshake, not scope creep.
**Code Review**: APPROVED (solo mode; suite-pass = full green gate).
**Tech debt**: None.
**Critical proof points**: Stack invariant (always GAMEPLAY base, never empty); class_name `InputContextStack` / autoload key `InputContext` split per ADR-0004 IG 2; ADR-0007 cross-autoload safety respected.
**Unblocks**: PC-001 + entire Player Character chain.
