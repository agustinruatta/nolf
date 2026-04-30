# Story 006: Same-section no-op guard + focus-loss handling + cache mode + memory invariant

> **Epic**: Level Streaming
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 hours (M — three small features + a memory-invariant integration test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/level-streaming.md`
**Requirement**: TR-LS-010 (`CACHE_MODE_REUSE` default; no eviction at MVP), TR-LS-014 (same-section no-op + focus-loss handling)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007
**ADR Decision Summary**: CR-11 — `ResourceLoader.CACHE_MODE_REUSE` (Godot default) for section loads; first-visited section cached for the session; `evict_section_from_cache(section_id)` exists as a no-op stub for Tier 2 expansion. CR-14 — same-section guard in shipping: if `section_id == _current_section_id and reason != RESPAWN`, return early; debug builds assert and crash on the underlying caller bug. CR-15 — `pause_on_focus_lost = true` in `project.godot`; on focus regain, snap overlay alpha to target value before resuming the coroutine.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)` is the canonical caching API. `OS.is_debug_build()` for the assert/return branch. `application/run/pause_on_focus_lost` is a project setting that pauses the SceneTree on focus loss.

**Control Manifest Rules (Foundation)**:
- Required: same-section guard returns early in shipping; asserts in debug (TR-LS-014)
- Required: `pause_on_focus_lost = true` set in `project.godot` (CR-15)
- Required: `evict_section_from_cache(section_id)` exists as a public stub (TR-LS-010 — Tier 2 API surface)
- Performance: peak heap memory ≤110% across two consecutive transitions into the same section (AC-LS-6.3)

---

## Acceptance Criteria

*From GDD §Detailed Design CR-11, CR-14, CR-15 + §Acceptance Criteria 3.3, 6.3:*

- [ ] **AC-1**: GIVEN `_current_section_id == &"plaza"` and shipping build, WHEN `transition_to_section(&"plaza", null, FORWARD)` is called (same section, non-RESPAWN reason), THEN the function returns early (no state change, no LOADING push, no coroutine launch).
- [ ] **AC-2**: GIVEN `_current_section_id == &"plaza"` and DEBUG build, WHEN `transition_to_section(&"plaza", null, FORWARD)` is called, THEN `assert(false, ...)` fires (caller bug — Mission Scripting authoring error). Test verifies via `assert` capture or by running in debug context.
- [ ] **AC-3**: GIVEN `_current_section_id == &"plaza"`, WHEN `transition_to_section(&"plaza", save_game, RESPAWN)` is called (same section, RESPAWN reason), THEN the transition proceeds normally — same-section guard does NOT block respawns. (CR-14 + CR-8 — respawn-in-place is a valid design path.)
- [ ] **AC-4**: GIVEN a transition's step-5 ResourceLoader.load call, WHEN the cache mode is inspected, THEN `CACHE_MODE_REUSE` is used (the third argument to `ResourceLoader.load` or via `Resource.set_path` discipline). First load: disk read; subsequent loads: cached return.
- [ ] **AC-5**: GIVEN `plaza.tscn` has been loaded once this session, WHEN `transition_to_section(&"plaza", ...)` is called a second time, THEN `ResourceLoader.has_cached("res://scenes/sections/plaza.tscn") == true` AND wall-clock duration of the SWAPPING phase for the second transition ≤50% of the first transition's SWAPPING duration. (AC-LS-3.3 from GDD.)
- [ ] **AC-6**: `evict_section_from_cache(section_id: StringName) -> void` exists as a public method. At MVP it is a no-op stub (function body: `pass` or a comment "Tier 2: implement eviction policy"). Tier 2 will populate it without changing the public API surface.
- [ ] **AC-7**: `project.godot` `[application]` section contains `run/pause_on_focus_lost=true` (CR-15 requirement; verifiable by parsing the file).
- [ ] **AC-8**: GIVEN `pause_on_focus_lost = true`, WHEN application focus is lost during FADING_OUT/FADING_IN, THEN `get_tree().paused == true`. WHEN focus is regained, the coroutine resumes and the overlay alpha is snapped to the target for the current state (1.0 during FADING_OUT/SWAPPING, 0.0 during IDLE — handled before resuming the coroutine). (CR-15.)
- [ ] **AC-9**: GIVEN two consecutive forward transitions into the same section (`plaza → stub_b → plaza` round-trip), WHEN peak heap memory is measured via `OS.get_static_memory_usage()`, THEN peak across the second transition ≤110% of peak during the first transition (no unbounded growth from repeated cache operations). (AC-LS-6.3 from GDD.)

---

## Implementation Notes

*Derived from GDD §Detailed Design CR-11, CR-14, CR-15 + ADR-0001 perf budget context:*

**Same-section guard** (extends Story 002's `transition_to_section`):

```gdscript
func transition_to_section(
    section_id: StringName,
    save_game: SaveGame = null,
    reason: TransitionReason = TransitionReason.FORWARD
) -> void:
    # CR-14: same-section guard
    if section_id == _current_section_id and reason != TransitionReason.RESPAWN:
        if OS.is_debug_build():
            assert(false, "[LSS] same-section forward transition is a caller bug: %s" % section_id)
            return  # unreachable in debug; safety net for unconfigured asserts
        else:
            return  # shipping: silent early return

    # Story 004's re-entrance guard
    if _transitioning:
        ...
    # Normal entry path
```

**Cache mode in step 5** (extends Story 002's coroutine):

```gdscript
# Step 5: load PackedScene with explicit cache mode
var packed: PackedScene = ResourceLoader.load(
    _registry.path(target_id),
    "",
    ResourceLoader.CACHE_MODE_REUSE
) as PackedScene
```

`CACHE_MODE_REUSE` is the default; specifying it explicitly is documentation that we know what's happening. First load: disk read + parse + cache. Subsequent loads: the cached `PackedScene` is returned. `instantiate()` produces a fresh Node tree from the cached resource each call, so we get a clean section instance every time without disk re-read.

**`evict_section_from_cache` stub**:

```gdscript
func evict_section_from_cache(section_id: StringName) -> void:
    # Tier 2: implement eviction policy (e.g., LRU based on play time, memory pressure trigger).
    # MVP: no-op. ResourceLoader.CACHE_MODE_REUSE keeps first-visit entries for session lifetime.
    pass
```

**Focus-loss handling** — primarily a project-setting concern (`pause_on_focus_lost = true`). The CR-15 "snap-on-resume" logic:

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_IN:
        if _transitioning:
            # Snap the fade overlay to the target alpha for the current state
            match _state:
                State.FADING_OUT, State.SWAPPING:
                    _fade_rect.color.a = 1.0
                State.FADING_IN:
                    _fade_rect.color.a = 0.0  # transitional; will be overwritten as fade-in resumes
                State.IDLE:
                    _fade_rect.color.a = 0.0
```

(Coroutine resumes naturally when the SceneTree unpauses; this snap ensures no visible "alpha stalled at 0.5" UX gap.)

**Memory-invariant test** (AC-9 — `OS.get_static_memory_usage()` baseline + delta):

```gdscript
func test_no_unbounded_memory_growth() -> void:
    # First round: plaza → stub_b → plaza
    LevelStreamingService.transition_to_section(&"plaza", null, NEW_GAME)
    await Events.section_entered
    var baseline_peak: int = OS.get_static_memory_usage()

    LevelStreamingService.transition_to_section(&"stub_b", null, FORWARD)
    await Events.section_entered

    # Second round: plaza again (cached)
    LevelStreamingService.transition_to_section(&"plaza", null, FORWARD)
    await Events.section_entered
    var second_peak: int = OS.get_static_memory_usage()

    # Allow 10% headroom for misc allocations
    assert_int(second_peak).is_less_or_equal(int(baseline_peak * 1.1))
```

**Edge case: focus loss during the queue drain at step 13** — `pause_on_focus_lost` pauses the SceneTree; the queue drain is part of the coroutine and will resume on focus regain. The pending state (`_pending_respawn_save_game`) survives the pause unchanged.

**Why same-section RESPAWN bypasses the guard**: CR-8 (respawn-in-place) is a designed flow. Player dies in plaza → F&R loads slot 0 → respawns at plaza section start (same section). The guard would block the respawn if it didn't exclude RESPAWN.

**Why no eviction at MVP**: per ADR-0001 + GDD §Tuning Knobs, MVP has 5 sections × ~1–2 MB each ≈ 5–10 MB cached scene memory — well under the 4 GB memory ceiling. Eviction policy is OQ-LS-2 for Tier 2 (Rome/Vatican expansion). The public API surface (`evict_section_from_cache`) is reserved now so Tier 2 implementations don't break existing callers.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 13-step coroutine (already done; this story extends step 5's cache mode + adds same-section guard atop the public method)
- Story 004: concurrency control (already done; same-section guard runs BEFORE re-entrance guard since it can short-circuit before `_transitioning` even matters)
- Story 005: failure paths (already done; orthogonal)
- Eviction policy implementation — Tier 2 expansion
- `pause_on_focus_lost` UX testing (full focus-loss-during-transition QA) — primarily a manual playtest concern, not unit testable

---

## QA Test Cases

**AC-1 — Same-section forward returns early in shipping**
- **Given**: `_current_section_id == &"plaza"`; shipping build; signal-spy on warnings/errors and on `Events.section_entered`
- **When**: `transition_to_section(&"plaza", null, FORWARD)`
- **Then**: function returns immediately; `_transitioning == false`; LOADING NOT pushed; no signal emits
- **Edge cases**: shipping build verification — test runs in debug context with a `_simulate_shipping_build` helper that wraps the OS check

**AC-2 — Same-section forward asserts in debug**
- **Given**: same as AC-1 but debug build
- **When**: same call
- **Then**: `assert(false, ...)` fires; test captures the assertion failure
- **Edge cases**: gdunit4 may handle `assert` differently — use `push_error` or a wrapping helper if `assert` cannot be intercepted; functionally equivalent

**AC-3 — Same-section RESPAWN proceeds normally**
- **Given**: `_current_section_id == &"plaza"`; either build mode
- **When**: `transition_to_section(&"plaza", some_save, RESPAWN)`
- **Then**: full 13-step coroutine runs; `Events.section_exited(&"plaza", RESPAWN)` and `Events.section_entered(&"plaza", RESPAWN)` both fire
- **Edge cases**: this is the canonical respawn-in-place path; guard MUST allow it

**AC-4 — CACHE_MODE_REUSE used at step 5**
- **Given**: `level_streaming_service.gd` source
- **When**: a code-review test inspects step 5's `ResourceLoader.load` call
- **Then**: third argument is `ResourceLoader.CACHE_MODE_REUSE` (not `CACHE_MODE_IGNORE` or `CACHE_MODE_REPLACE`)
- **Edge cases**: developers may omit the third arg (default is REUSE) — the lint accepts both omission and explicit specification; explicit is preferred for documentation

**AC-5 — Cached second-load is faster**
- **Given**: integration test with timing instrumentation; `plaza.tscn` exists
- **When**: first transition_to_section to plaza (cold) measured; second transition (warm) measured
- **Then**: `ResourceLoader.has_cached(plaza_path) == true` after first; second SWAPPING duration ≤50% of first
- **Edge cases**: CI runner variance — test logs both durations; if ratio > 50% (cache miss?), check for cache invalidation; tolerance widened to 70% on slow CI

**AC-6 — evict_section_from_cache exists as no-op**
- **Given**: LSS booted
- **When**: `LSS.evict_section_from_cache(&"plaza")` is called
- **Then**: function returns without error; no observable side effects (cache state unchanged)
- **Edge cases**: passing invalid `StringName(&"")` or non-existent section → still no-op (no validation needed at MVP)

**AC-7 — pause_on_focus_lost project setting**
- **Given**: `project.godot` after this story
- **When**: a test reads the file and inspects `[application]` section
- **Then**: contains `run/pause_on_focus_lost=true`
- **Edge cases**: setting absent → defaults to false in Godot; test catches missing setting

**AC-8 — Focus regain snaps overlay alpha**
- **Given**: transition in FADING_OUT (`_fade_rect.color.a = 0.5`); test simulates focus loss + regain via `notification(NOTIFICATION_APPLICATION_FOCUS_IN)`
- **When**: focus regain notification fires
- **Then**: `_fade_rect.color.a == 1.0` (snapped to target for FADING_OUT/SWAPPING state); coroutine resumes; final state reaches IDLE normally
- **Edge cases**: focus regain during IDLE → no snap action needed; current alpha stays 0.0

**AC-9 — Memory invariant under repeat transitions**
- **Given**: integration test with `OS.get_static_memory_usage()` instrumentation; stub plaza + stub_b scenes
- **When**: round-trip plaza → stub_b → plaza
- **Then**: peak after second plaza ≤110% of peak after first plaza (no unbounded growth)
- **Edge cases**: per Story 008's stub scenes (~30 nodes); memory delta should be small (<500 KB); large excess indicates leak

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_streaming/level_streaming_guard_cache_test.gd` — must exist and pass (AC-1 through AC-7)
- `tests/integration/level_streaming/level_streaming_focus_memory_test.gd` — must exist and pass (AC-8, AC-9)
- Naming follows Foundation-layer convention
- Determinism: timing tests record raw values; memory tests use the engine's static memory tracker (deterministic given fixed input)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (13-step coroutine — same-section guard wraps `transition_to_section`; cache mode at step 5), Story 004 (re-entrance guard ordering — same-section guard runs FIRST), Story 008 (stub plaza + stub_b scenes for memory test)
- Unlocks: Tier 2 (Rome/Vatican) future work — public eviction API surface is in place
