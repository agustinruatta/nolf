# Story 009: Forbidden pattern fences + CI grep gates

> **Epic**: Stealth AI
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1-2 hours (S — CI shell assertions, static grep tests, no new runtime code)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-005` (AlertCause enum contract + SAW_BODY suppression of `player_footstep` subscription)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0006 (Collision Layer Contract)
**ADR Decision Summary**: ADR-0002 forbids `events.gd` enum declarations (pattern `event_bus_enum_definition`) and forbids `Events.gd` methods/state (pattern `event_bus_with_methods`). ADR-0006 forbids bare integer literals in collision layer/mask assignments (pattern `hardcoded_physics_layer_number`). Stealth AI additionally has a domain-specific forbidden pattern: SAI must NOT subscribe to `player_footstep` — SAI reads noise levels via `player.get_noise_level()` (pull, not push). These patterns are enforced as CI-step shell assertions.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI runs `godot --headless --script tests/gdunit4_runner.gd` on every push per coding standards. Shell `grep` and `find` are standard — no post-cutoff engine APIs involved. `OS.execute()` in a headless GDScript test can run grep commands for in-engine static analysis.

**Control Manifest Rules (All Layers)**:
- Required: forbidden patterns are registered and enforced in CI — a story that introduces a forbidden pattern cannot be marked Done
- Forbidden: `player_footstep` subscription anywhere in `src/ai/` or `src/gameplay/stealth/`
- Forbidden: `NavigationServer3D.map_get_path` synchronous calls in `src/ai/` or `src/gameplay/stealth/`
- Forbidden: `call_deferred` in `receive_damage` context (synchronicity guarantee)
- Forbidden: bare integer literals in `collision_layer`, `collision_mask`, `set_collision_layer_value`, `set_collision_mask_value` in `src/ai/` or `src/gameplay/stealth/`
- Forbidden: enum declarations on `events.gd`

---

## Acceptance Criteria

*From GDD §Interactions (Player Character row — MUST NOT subscribe to `player_footstep`) + AC-SAI-3.12 + TR-SAI-005:*

- [ ] **AC-1** (AC-SAI-3.12.a — `player_footstep` forbidden): Static CI assertion: `find src/ai/ src/gameplay/stealth/ -name '*.gd' | xargs grep -l 'player_footstep'` returns empty (zero matching files). Rationale: SAI reads `player.get_noise_level()` (pull model); subscribing to `player_footstep` (push model) is the explicitly documented Forbidden Pattern in the PC GDD + FC GDD.
- [ ] **AC-2** (AC-SAI-3.12.b — `NavigationServer3D.map_get_path` forbidden): Static CI assertion: `find src/ai/ src/gameplay/stealth/ -name '*.gd' | xargs grep -l 'NavigationServer3D.map_get_path'` returns empty. Gameplay code MUST use `NavigationAgent3D`'s async dispatch; direct sync nav server calls violate the async-nav budget assumption in AC-SAI-4.4.c.
- [ ] **AC-3** (AC-SAI-3.12.c — `call_deferred` in `receive_damage` context): Static CI assertion: grep for `call_deferred` in `src/gameplay/stealth/guard.gd` returns zero hits in the `receive_damage` method body. Enforces the AC-SAI-1.11 synchronicity guarantee as a source-file invariant.
- [ ] **AC-4** (ADR-0006 — no bare physics layer integers): Static CI assertion: `find src/ai/ src/gameplay/stealth/ -name '*.gd' | xargs grep -n 'collision_layer\s*=\s*[0-9]\|collision_mask\s*=\s*[0-9]'` returns empty (excluding `PhysicsLayers.gd` itself). Guards bare integer literals in gameplay stealth code.
- [ ] **AC-5** (ADR-0002 — `events.gd` enum-free): Static assertion already partially covered by Story 002's AC-3, but registered here as a separate CI fence with a distinct failure message: `grep -n 'enum ' src/core/signal_bus/events.gd` returns empty. Prevents future edits from accidentally adding enum declarations to the bus.
- [ ] **AC-6** (AC-SAI-3.3 — signal signature grep): Static grep asserts `Events.gd` contains all 6 SAI-domain signal declarations with their full parameter lists. This is BLOCKED until ADR-0002 amendment and `Events.gd` regeneration from Story 002 are complete. AC-3.3 test carries `pending("BLOCKED: requires ADR-0002 amendment")` until Story 002 is merged. Once Story 002 ships, remove the `pending` marker and re-run.
- [ ] **AC-7**: All 6 grep assertions are implemented as CI steps (either in `.github/workflows/` or as a headless `OS.execute()` GDScript test file). They must pass on every push to `main` and on every PR. A PR that fails any assertion is blocked from merge.

---

## Implementation Notes

*Derived from GDD §Interactions (Player Character Forbidden Pattern) + AC-SAI-3.12:*

Implement as a GDScript test file using `OS.execute()` to run grep, OR as direct CI shell steps in the pipeline configuration. The GDScript approach keeps the assertions visible in the test suite and runnable locally:

```gdscript
# tests/unit/feature/stealth_ai/stealth_ai_forbidden_patterns_test.gd
func test_no_player_footstep_subscription() -> void:
    var output := []
    var exit_code := OS.execute("bash", ["-c",
        "find src/ai/ src/gameplay/stealth/ -name '*.gd' -exec grep -l 'player_footstep' {} +"
    ], output, true)
    assert_that(output.join("").strip_edges()).is_empty()

func test_no_sync_nav_server_calls() -> void:
    var output := []
    OS.execute("bash", ["-c",
        "find src/ai/ src/gameplay/stealth/ -name '*.gd' -exec grep -l 'NavigationServer3D.map_get_path' {} +"
    ], output, true)
    assert_that(output.join("").strip_edges()).is_empty()
```

These tests run headlessly in CI (`godot --headless --script tests/gdunit4_runner.gd`) — `OS.execute` is available in headless mode.

For AC-6 (`pending` story-merge gate): the GDScript `pending()` helper in GUT marks the test as skipped (not failed) until the condition is resolved. The sprint board tracks "SAI-ADR-0002-Amendment" as the hard dependency. Story 002 merging closes this gate.

The `player_footstep` prohibition is load-bearing for the perception-seam architecture: SAI owning the full signal chain from player position read → accumulator fill → state transition → bus signal keeps the footstep system (FootstepComponent) decoupled from AI state. This is also why F.2a reads `player.get_noise_level()` (a pull interface) rather than subscribing to individual footstep events.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: signal signature declaration in `events.gd` (what AC-6 verifies once merged)
- Story 010: performance budget assertions (separate from structural correctness gates)
- Post-VS: forbidden pattern for `enum ` on `events.gd` covering post-VS signals (the fence established here covers the full `events.gd` file, including future signals)
- Post-VS: SAW_BODY cause validation (the `body_factor = 2×` rule is structurally gated; no body to find in VS but the pattern fence prevents misuse when the feature ships)

---

## QA Test Cases

**AC-1 — player_footstep grep (no hits)**
- Given: `src/ai/` and `src/gameplay/stealth/` contain all SAI source files
- When: grep for `player_footstep` runs on all `.gd` files in those directories
- Then: output is empty (zero matching files)
- Edge cases: a comment containing `player_footstep` → grep matches comments; test fails intentionally (comments containing the pattern are also a documentation smell — use the word without the signal name)

**AC-4 — No bare physics integers**
- Given: all `.gd` files in `src/ai/` and `src/gameplay/stealth/`
- When: grep for `collision_layer = [digit]` or `collision_mask = [digit]` patterns
- Then: zero matches outside of `physics_layers.gd` itself (which IS the definition file)
- Edge cases: `collision_layer = 0` (zero-mask) → this IS a legitimate pattern for VisionCone (`layer = 0`); the grep must be scoped to non-definition files only, or exclude `layer = 0` as a special case with a comment annotation

**AC-6 — Signal signature grep (pending until Story 002)**
- Given: `src/core/signal_bus/events.gd` post-Story-002 merge
- When: grep for all 6 SAI signal declarations with full signatures
- Then: all 6 present; `pending()` marker removed; test runs green
- Edge cases: partial merge (events.gd updated but guard.gd not yet updated) → partial-match grep catches the mismatch; atomic-commit requirement (ADR-0002 2026-04-24 amendment) enforced here

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_forbidden_patterns_test.gd` — AC-SAI-3.12 (all 6 grep assertions)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE + Story 002 DONE (source files must exist to meaningfully grep them; AC-6 blocked until Story 002)
- Unlocks: Story 010 (performance test inherits the "no sync nav calls" fence from AC-2)
