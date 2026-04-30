# Story 005: Registry failure paths + ErrorFallback CanvasLayer recovery

> **Epic**: Level Streaming
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2 hours (M — failure paths + ErrorFallback display + change_scene_to_file fallback)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-003 (Public API including `_simulate_registry_failure` test hook), TR-LS-002 (ErrorFallback at CanvasLayer 126)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007
**ADR Decision Summary**: Per CR-3 + §Edge Cases: failures during steps 4–7 (registry-has, ResourceLoader.load, instantiate, add_child) all route to `_abort_transition()` followed by `get_tree().change_scene_to_file("res://scenes/ErrorFallback.tscn")`. ErrorFallback shows a period mission-dossier "File not found — returning to main menu" card in debug builds; in shipping builds it flashes briefly during the change_scene_to_file transition to the main menu. `_simulate_registry_failure()` is a test-only hook (`@tool` / debug builds; absent in shipping) that flips `_registry_valid = false` to enable AC-LS-1.8 testing.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `change_scene_to_file` is the canonical recovery path — it's the same API the main menu uses to start the game (CR-7), bypassing LSS. SceneTree-level scene swap; LSS itself doesn't drive it.

**Control Manifest Rules (Foundation)**:
- Required: any failure in steps 4–7 routes to `_abort_transition()` + ErrorFallback display
- Required: registry validity check at step 4 BEFORE `queue_free` (so a bad target doesn't orphan us in a sceneless state — per CR-5 step 4)
- Required: `_simulate_registry_failure()` is debug-build only (excluded from shipping exports per `OS.is_debug_build()` check)
- Forbidden: silent failure on registry miss (every failure path emits `push_error`)

---

## Acceptance Criteria

*From GDD §Edge Cases + §Acceptance Criteria 1.8, 3.2, 3.4:*

- [ ] **AC-1**: GIVEN `_simulate_registry_failure()` has been called (test-only hook per CR-2; flips `_registry_valid = false`), WHEN `transition_to_section` is called, THEN it immediately calls `push_error` and returns without modifying state. (AC-LS-1.8 from GDD.)
- [ ] **AC-2**: GIVEN `section_id` is not present in `SectionRegistry`, WHEN LSS reaches step 4's pre-check (registry-has), THEN `_abort_transition()` runs BEFORE `queue_free()` (outgoing scene still in tree at abort time, verified by `is_instance_valid`), AND `push_error` is invoked. (AC-LS-3.4 from GDD.)
- [ ] **AC-3**: GIVEN a transition in progress at step 5, WHEN `ResourceLoader.load(path)` returns null (forced via a SectionRegistry entry pointing at a non-existent file, e.g., `res://scenes/sections/__bad__.tscn`), THEN `_abort_transition()` runs, ErrorFallback.tscn loads via `change_scene_to_file`, `_transitioning == false`, AND LOADING is not on the stack. (AC-LS-3.2 from GDD.)
- [ ] **AC-4**: GIVEN `packed.instantiate()` returns null at step 6 (corrupt PackedScene), WHEN failure is detected, THEN same recovery as AC-3: `_abort_transition()` + ErrorFallback display.
- [ ] **AC-5**: GIVEN `add_child(instance)` raises an unhandled error at step 7 (instance is invalid Node), WHEN failure is detected via post-add validation, THEN same recovery as AC-3.
- [ ] **AC-6**: ErrorFallback.tscn display path: in debug builds, the change_scene_to_file → ErrorFallback shows the "File not found" message for at least 2 seconds, then auto-returns to main menu via a second `change_scene_to_file("res://scenes/MainMenu.tscn")`. In shipping builds, the ErrorFallback may flash briefly or be skipped entirely (route directly to MainMenu).
- [ ] **AC-7**: `_abort_transition` is the single recovery function — every failure path in the 13-step coroutine routes to it. Verifiable by code review: every `if instance == null:` / `if packed == null:` / `if not _registry.has(...):` branch ends with `_abort_transition() + push_error + return`.
- [ ] **AC-8**: GIVEN `_simulate_registry_failure()` is called in a shipping build, WHEN the function is invoked, THEN it is a no-op (function body is `if not OS.is_debug_build(): return`); does not affect `_registry_valid`. (Test only runs in debug; shipping verification is via export-build inspection.)
- [ ] **AC-9**: GIVEN any failure path in steps 4–7, WHEN the recovery completes, THEN: `_transitioning == false`, `_state == IDLE`, `InputContext.LOADING` not on stack, `_pending_respawn_save_game == null` (cleared by `_abort_transition`), fade overlay alpha 0.0 (cleared).

---

## Implementation Notes

*Derived from GDD §Edge Cases + §Detailed Design CR-3 + Story 004's `_abort_transition` skeleton:*

**`_simulate_registry_failure` test hook**:

```gdscript
func _simulate_registry_failure() -> void:
    if not OS.is_debug_build():
        return  # test-only hook; shipping no-op
    _registry_valid = false
```

(Test sets up scenario by calling this method, then calls `transition_to_section` and asserts immediate `push_error` + return without coroutine launch.)

**Failure paths in `_run_swap_sequence`** (extending Story 002's coroutine; consolidating Story 004's `_abort_transition` calls):

```gdscript
# Step 4: registry-has check BEFORE queue_free
if not _registry.has(target_id):
    push_error("[LSS] section_id '%s' not in registry" % target_id)
    _abort_transition()
    _show_error_fallback("File not found: %s" % target_id)
    return

# (At this point outgoing_scene is still in tree — abort is safe.)
if outgoing_scene != null:
    outgoing_scene.queue_free()

# Step 5: load
var packed: PackedScene = ResourceLoader.load(_registry.path(target_id)) as PackedScene
if packed == null:
    push_error("[LSS] PackedScene load failed for %s" % target_id)
    _abort_transition()
    _show_error_fallback("Scene load failed")
    return

# Step 6: instantiate
var instance: Node = packed.instantiate()
if instance == null:
    push_error("[LSS] Instantiate failed for %s" % target_id)
    _abort_transition()
    _show_error_fallback("Instantiate failed")
    return

# Step 7: add_child + reassign current_scene
get_tree().root.add_child(instance)
if not is_instance_valid(instance) or not instance.is_inside_tree():
    push_error("[LSS] add_child failed for %s" % target_id)
    _abort_transition()
    _show_error_fallback("Tree mount failed")
    return
get_tree().current_scene = instance

# Continue with step 8+
```

**`_show_error_fallback(message)` helper**:

```gdscript
func _show_error_fallback(message: String) -> void:
    var error_fallback_path: String = "res://scenes/ErrorFallback.tscn"
    if not ResourceLoader.exists(error_fallback_path):
        # Defense-in-depth: if even ErrorFallback is broken, fall back to MainMenu directly
        get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
        return

    if OS.is_debug_build():
        # Pass message to fallback scene via autoload state or signal
        # (MVP: use a simple module-level var read by ErrorFallback's _ready)
        _last_error_message = message
        get_tree().change_scene_to_file(error_fallback_path)
    else:
        # Shipping: route directly to MainMenu (ErrorFallback may flash briefly via change_scene)
        get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
```

**ErrorFallback.tscn behavior** (from Story 001's MVP placeholder, extended here):
- `_ready()` reads `LevelStreamingService._last_error_message` and displays it in a Label
- After 2 seconds (`Timer` node + `timeout` signal), calls `get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")`
- Or: button "Return to Main Menu" lets the player dismiss immediately

**Why `_abort_transition` runs BEFORE `queue_free` at step 4**: per AC-LS-3.4, the registry-has check happens BEFORE step 4's queue_free. If it fails, the outgoing scene is still in the tree — we abort cleanly without orphaning the player in a sceneless state. (Story 002's coroutine already implements this ordering; this story verifies it.)

**Why `_abort_transition` is called even though `_show_error_fallback` will swap scenes**: cleanliness. `_abort_transition` clears LSS internal state (LOADING context, fade alpha, pending queues) regardless of what happens at the SceneTree level. The change_scene_to_file is the user-visible recovery; the abort is the internal-state recovery.

**Last error message storage** — module-level `_last_error_message: String = ""` on the LSS autoload. ErrorFallback.tscn reads it. Cleared after read or on next successful `transition_to_section`.

**Edge case: ErrorFallback itself fails to load** — defense-in-depth: route directly to MainMenu. If MainMenu also fails, the project is fundamentally broken; LSS does not attempt further recovery (`push_error` fires; player sees a Godot crash dialog or blank screen). Documented limitation.

**`SectionRegistry` boot failure** (from Story 001) — `_registry_valid = false` at LSS boot causes EVERY `transition_to_section` call to `push_error` and return. The main menu still loads (via direct `change_scene_to_file` in the application entry point). Player sees a "cannot start new game" error dialog when clicking New Game / Load Game (Menu System renders the error from `Events.save_failed` or a similar surface — out of scope here).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: ErrorFallback CanvasLayer scaffold + ErrorFallback.tscn placeholder (already done)
- Story 002: 13-step coroutine + state machine (already done; this story extends failure paths)
- Story 004: `_abort_transition` core implementation (already done; this story integrates with it via `_show_error_fallback`)
- Visual treatment of ErrorFallback.tscn (Art Bible 7D dossier card) — owned by Menu System / Art Director, post-MVP
- Menu System "cannot start new game" error UI — owned by Menu System epic
- Boot-time `_registry_valid = false` → main-menu error display — Menu System epic

---

## QA Test Cases

**AC-1 — _simulate_registry_failure flips registry-valid flag**
- **Given**: LSS in IDLE; `_registry_valid == true`; debug build
- **When**: `LSS._simulate_registry_failure()` is called; then `transition_to_section(&"plaza", null, NEW_GAME)`
- **Then**: `_registry_valid == false`; `transition_to_section` immediately `push_error`s and returns; `_transitioning` remains false (no state change); LOADING NOT pushed
- **Edge cases**: shipping build → no-op; test runs in debug context

**AC-2 — Registry-miss aborts before queue_free**
- **Given**: LSS in IDLE with `plaza` in tree; registry has only `&"plaza"` (no `&"unknown_id"` entry)
- **When**: `transition_to_section(&"unknown_id", null, FORWARD)` is called and reaches step 4
- **Then**: `is_instance_valid(plaza_instance) == true` (scene NOT freed); `_abort_transition` ran; `push_error` invoked; LSS back in IDLE
- **Edge cases**: this is the load-bearing AC for "abort before queue_free" ordering — a regression here means the player gets dropped into the void

**AC-3 — ResourceLoader null abort + ErrorFallback**
- **Given**: registry has `&"bad_section"` pointing at `res://scenes/sections/__bad__.tscn` (file does not exist)
- **When**: `transition_to_section(&"bad_section", null, FORWARD)` is called
- **Then**: `_abort_transition` runs at step 5 failure; `change_scene_to_file("res://scenes/ErrorFallback.tscn")` is invoked; `_transitioning == false`; LOADING NOT on stack; `Events.section_entered` does NOT fire
- **Edge cases**: integration test creates a registry entry pointing at a deliberately-missing file; cleans up after

**AC-4 — Instantiate-null abort path**
- **Given**: registry has a path to a corrupt `.tscn` (PackedScene loads but `instantiate()` returns null — synthesize via test fixture)
- **When**: transition reaches step 6
- **Then**: same recovery as AC-3
- **Edge cases**: hard to synthesize a "valid PackedScene that fails instantiate" — typical fixture is a deliberately-malformed `.tscn` file in `tests/fixtures/`

**AC-5 — add_child failure path (defensive)**
- **Given**: a Node that fails to add to tree (rare; e.g., a Node already in another tree)
- **When**: transition reaches step 7's add_child + validity check
- **Then**: same recovery as AC-3
- **Edge cases**: this AC is defense-in-depth; in practice add_child rarely fails for fresh instantiates

**AC-6 — ErrorFallback display + auto-return to MainMenu**
- **Given**: ErrorFallback.tscn loaded after a step-5 failure
- **When**: ErrorFallback's `_ready` runs in debug build
- **Then**: Label displays the error message (`_last_error_message`); after 2s a `change_scene_to_file("res://scenes/MainMenu.tscn")` fires
- **Edge cases**: shipping build → ErrorFallback may flash briefly OR be skipped (direct route to MainMenu); evidence doc for shipping behavior since the Timer-based test pattern is dev-only

**AC-7 — Single recovery function code-review check**
- **Given**: `level_streaming_service.gd` source (post-Stories 002, 004, 005)
- **When**: code-review test greps for failure-handling branches
- **Then**: every failure check ends with the pattern `_abort_transition()` + `_show_error_fallback(...)` + `return` (or `_abort_transition()` + `push_error` + `return` for non-recoverable cases like registry-miss before queue_free)
- **Edge cases**: future PRs that add new failure paths → must follow the pattern; lint check enforces

**AC-8 — _simulate_registry_failure no-op in shipping**
- **Given**: shipping build (manually exported); function called
- **When**: function body executes
- **Then**: no state change; `_registry_valid` retains its boot value
- **Edge cases**: this AC is verified via export-build inspection (manual) since CI typically runs debug builds; document in evidence doc

**AC-9 — Clean state after every failure path**
- **Given**: any failure path triggered (AC-1 through AC-5)
- **When**: recovery completes
- **Then**: invariants — `_transitioning == false`, `_state == IDLE`, LOADING not on stack, `_pending_respawn_save_game == null`, fade overlay alpha 0.0
- **Edge cases**: parameterized test runs all 5 failure paths and asserts the invariants after each

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/level_streaming/level_streaming_failure_recovery_test.gd` — must exist and pass (covers AC-1 through AC-7, AC-9; AC-8 covered by manual evidence doc)
- `production/qa/evidence/level_streaming_shipping_error_fallback.md` — manual verification for AC-8 + AC-6 shipping-build behavior
- Naming follows Foundation-layer convention

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (ErrorFallback.tscn placeholder + CanvasLayer 126 + preload), Story 002 (13-step coroutine — failure paths are inserted at steps 4–7), Story 004 (`_abort_transition` core implementation)
- Unlocks: shipping-readiness for the autoload — failure recovery is a Definition-of-Done item per epic
