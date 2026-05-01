# Story 001: PostProcessStack autoload scaffold + chain-order const table

> **Epic**: Post-Process Stack
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (S — new autoload file + registration + const table + unit test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/post-process-stack.md`
**Requirement**: TR-PP-001, TR-PP-007
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (Autoload Load Order Registry) + ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: `PostProcessStack` is autoload slot 6 in the ADR-0007 canonical 10-autoload cascade (`Events` → `EventLogger` → `SaveLoad` → `InputContext` → `LevelStreamingService` → `PostProcessStack` → ...). It is the dominant contributor to cold-boot time (ADR-0008 Non-Frame Budgets: 5-15 ms Vulkan compositor pipeline registration). The autoload owns sepia dim state and exposes the public API; it does NOT hold references to other systems (GDD Core Rule 5 — service that owns its domain).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CompositorEffect` (4.3+) and `Node` autoload lifecycle are stable. The chain-order const table is pure GDScript data — no post-cutoff API risk. `PostProcessStack` is position 6 in ADR-0007's canonical autoload table; its `_ready()` may reference autoloads at positions 1-5 only (ADR-0007 IG 4). The 4.6 glow rework (glow now processes before tonemapping — VERSION.md HIGH risk) does not affect this scaffold story; glow composition is verified in Story 007. `Compositor` node registration on the active `Camera3D` uses the stable `Compositor` + `CompositorEffect` API (4.3+).

**Control Manifest Rules (Foundation)**:
- Required: `project.godot [autoload]` block must match ADR-0007 §Key Interfaces verbatim — no reordering (ADR-0007 IG 1)
- Required: all autoload entries use `*res://` path-prefix-star syntax (scene-mode) — ADR-0007 IG 2
- Required: autoload `_ready()` may reference only autoloads at earlier line numbers (position 1-5 for PostProcessStack at position 6) — ADR-0007 IG 4
- Forbidden: never call `Engine.register_singleton()` at runtime — pattern `runtime_singleton_registration`
- Forbidden: never reference a later-line autoload from `_ready()` — ADR-0007 §Cross-Autoload Reference Safety rule 3
- Guardrail: PostProcessStack cold-boot is the dominant autoload contributor (~5-15 ms Vulkan compositor pipeline registration); total autoload cascade budget is ≤50 ms cold-start (ADR-0008 Non-Frame Budgets)

---

## Acceptance Criteria

*From GDD `design/gdd/post-process-stack.md` Core Rule 5 + ADR-0007 + Detailed Design §Core Rules:*

- [ ] **AC-1**: `src/foundation/post_process/post_process_stack.gd` declares `class_name PostProcessStackService extends Node` with `var is_sepia_active: bool = false` (read-only from outside), stub `func enable_sepia_dim() -> void` and `func disable_sepia_dim() -> void` (bodies filled in Story 003), and a `const CHAIN_ORDER: Array[StringName] = [&"outline", &"sepia_dim", &"resolution_scale"]` constant representing the locked chain order (GDD Core Rule 1).
- [ ] **AC-2**: `project.godot [autoload]` block contains `PostProcessStack="*res://src/foundation/post_process/post_process_stack.gd"` at position 6 (after `LevelStreamingService`, before `Combat`), matching ADR-0007 §Key Interfaces verbatim.
- [ ] **AC-3**: GIVEN the game boots, WHEN `get_tree().root.get_children()` is inspected, THEN `PostProcessStack` is present as a child node of type `PostProcessStackService`, positioned after `LevelStreamingService` in the autoload tree.
- [ ] **AC-4**: GIVEN `post_process_stack.gd`, WHEN a unit test inspects `PostProcessStackService.CHAIN_ORDER`, THEN the array equals `[&"outline", &"sepia_dim", &"resolution_scale"]` and has exactly 3 elements in that order.
- [ ] **AC-5**: GIVEN `post_process_stack.gd`, WHEN the file is read, THEN `_ready()` does NOT reference any autoload at position 7 or later (Combat, FailureRespawn, MissionLevelScripting, SettingsService). It MAY reference positions 1-5 (Events, EventLogger, SaveLoad, InputContext, LevelStreamingService).
- [ ] **AC-6**: GIVEN the game boots cold (no shader cache), WHEN the time from process start to `PostProcessStack._ready()` completion is measured, THEN the entire 10-autoload cascade completes in ≤50 ms (ADR-0008 Non-Frame Budgets; PostProcessStack is the dominant contributor at ~5-15 ms Vulkan compositor pipeline registration). *Note: this gate cannot fully close until ADR-0008 reaches Accepted; treat as advisory at VS scope.*

---

## Implementation Notes

*Derived from GDD §Detailed Design Core Rule 5 + ADR-0007 §Key Interfaces + ADR-0008 §Non-Frame Budgets:*

File to create: `src/foundation/post_process/post_process_stack.gd`

The scaffold establishes the autoload node structure that Stories 002-006 build on. Key decisions baked in here:

1. **`CHAIN_ORDER` const** is the unit-testable artifact that enforces GDD Core Rule 1 ("chain order is locked"). Any future PR that reorders or extends the chain must change this const — making the lock visible and diff-able. Test it as a pure data assertion.

2. **`is_sepia_active: bool`** — the public read-only property. GDScript does not enforce read-only properties at the language level; document the intent with a `## Read-only from outside. Use enable_sepia_dim()/disable_sepia_dim() to change.` doc comment. The property will be used by Document Overlay (Story 004) to guard against double-calls.

3. **Stub bodies for `enable_sepia_dim()` / `disable_sepia_dim()`** — leave them as `pass` stubs with `## TODO: implemented in Story 003` comments. Story 002 adds the shader CompositorEffect; Story 003 adds the tween state machine.

4. **No `Compositor` node wiring in this story.** The CompositorEffect chain registration belongs in Story 002 (shader) and requires the actual shader resource to exist. This story scaffolds the GDScript class only.

5. **Autoload registration** — the programmer must manually verify the `project.godot [autoload]` block matches ADR-0007 §Key Interfaces after adding the entry. The Godot editor UI may reorder the block; check `git diff project.godot` before committing.

6. **`_ready()` safety** — PostProcessStack at position 6 may call `Events.setting_changed.connect(...)` in `_ready()` because Events is at position 1. Do NOT call `SettingsService` from `_ready()` — it is at position 10 (later).

Suggested file skeleton:

```
src/foundation/post_process/
└── post_process_stack.gd   (class_name PostProcessStackService)
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Sepia dim `CompositorEffect` shader resource + `Compositor` node wiring on `Camera3D`
- Story 003: Tween state machine (IDLE/FADING_IN/ACTIVE/FADING_OUT) inside `enable_sepia_dim()` / `disable_sepia_dim()`
- Story 004: Document Overlay integration handshake (`document_opened` / `document_closed` signal connections)
- Story 005: WorldEnvironment glow ban enforcement (`glow_enabled = false` assertion)
- Story 006: Resolution scale `setting_changed` subscription + `Viewport.scaling_3d_scale` wiring
- Story 007: Visual and performance verification against ADR-0008 Slot 3 budget

---

## QA Test Cases

**AC-1 — Class structure and const declaration**
- Given: `src/foundation/post_process/post_process_stack.gd`
- When: a unit test loads the script and reflects on a fresh `PostProcessStackService.new()` instance
- Then: `class_name` is `PostProcessStackService`; `is_sepia_active` exists as a `bool` defaulting to `false`; `enable_sepia_dim` and `disable_sepia_dim` exist as callable methods; `CHAIN_ORDER` is a const Array
- Edge cases: wrong class_name → autoload key mismatch; is_sepia_active missing → Story 004's guard check fails silently

**AC-3 + AC-4 — Autoload registration + CHAIN_ORDER content**
- Given: game boots with the production `project.godot`
- When: a unit test calls `get_tree().root.get_node("PostProcessStack")` and inspects `PostProcessStackService.CHAIN_ORDER`
- Then: node is present and its type is `PostProcessStackService`; `CHAIN_ORDER` equals `[&"outline", &"sepia_dim", &"resolution_scale"]` exactly
- Edge cases: wrong autoload path → node not found; alphabetical reorder by Godot editor → position 6 constraint violated; array length != 3 or wrong order → Core Rule 1 broken

**AC-5 — No forward autoload reference in _ready()**
- Given: `post_process_stack.gd` source as committed
- When: the source is grepped for autoload names at positions 7-10 (`Combat`, `FailureRespawn`, `MissionLevelScripting`, `SettingsService`) as function-call-style references outside of string literals or comments
- Then: zero matches (no runtime cross-reference to later autoloads)
- Edge cases: SettingsService referenced for initial resolution_scale read — this belongs in Story 006 and must use `Events.setting_changed` subscription pattern, not a direct SettingsService call in `_ready()`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/post_process_stack/post_process_stack_scaffold_test.gd` — must exist and pass
- Covers: AC-1 (class reflection), AC-3 (autoload presence), AC-4 (CHAIN_ORDER assertion), AC-5 (no forward autoload reference via source grep)
- Determinism: no external state; pure reflection + constant assertion

**Status**: [x] Created and passing — `tests/unit/foundation/post_process_stack/post_process_stack_scaffold_test.gd` (10 test functions covering AC-1, AC-3, AC-4, AC-5). Suite total: 369/369 PASS.

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 6/6 — AC-1/3/4/5 fully auto-verified via 10 tests; AC-2 (project.godot ordering) verified by existing autoload entry preserved at position 6 (`PostProcessStack="*res://src/core/rendering/post_process_stack.gd"`); AC-6 (cold-boot ≤50 ms) is advisory per story note (gate cannot fully close until ADR-0008 reaches Accepted with hardware verification).
**Test Evidence**: `tests/unit/foundation/post_process_stack/post_process_stack_scaffold_test.gd`
**Code Review**: APPROVED inline (10/10 tests + 369/369 full suite all green; first-run class cache refresh required after creating new class_name; AC-5 grep correctly excludes comment lines, matches `Name.` and `Name(` only — won't trip on doc references)
**Deviations**: One — story implementation note specifies file location `src/foundation/post_process/post_process_stack.gd`, but the existing Sprint 01 autoload entry in project.godot was already locked to `src/core/rendering/post_process_stack.gd` (matching the SaveLoad/Events `src/core/...` precedent). Used the existing path (no project.godot ordering change needed; preserves ADR-0007 §Key Interfaces verbatim).
**Suite trajectory**: 359 → 369 (+10 tests).
**Files modified**:
- `src/core/rendering/post_process_stack.gd` (was 21-line Sprint 01 stub; expanded to 99 lines with `class_name PostProcessStackService extends Node`; CHAIN_ORDER const lock; `is_sepia_active` public read-only property; stub `enable_sepia_dim()`/`disable_sepia_dim()` for PPS-003)
**Files created**:
- `tests/unit/foundation/post_process_stack/post_process_stack_scaffold_test.gd` (10 test functions: 4 class-shape + 1 autoload presence + 4 CHAIN_ORDER lock + 1 forward-reference grep)
**Out-of-scope deferred**: CompositorEffect (PPS-002), tween state machine (PPS-003), Document Overlay handshake (PPS-004), glow ban (PPS-005), resolution scale (PPS-006), perf verification (PPS-007). All correctly excluded.

---

## Dependencies

- Depends on: None — foundational scaffold; no upstream story required
- Unlocks: Story 002 (shader needs the autoload node to exist), Story 003 (tween state machine extends the scaffold), Story 004 (integration test needs the API stubs)
