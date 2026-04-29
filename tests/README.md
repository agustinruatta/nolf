# Test Infrastructure

**Engine**: Godot 4.6 (Forward+ / Vulkan-Linux + D3D12-Windows; Jolt 3D physics; GDScript)
**Test Framework**: GdUnit4 (standard for GDScript per `.claude/docs/technical-preferences.md`)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-04-28

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system + save/load round-trip tests
  smoke/          # Critical-path checklist for /smoke-check gate
  evidence/       # Screenshot logs + manual test sign-off records
  gdunit4_runner.gd  # Headless CLI runner — invoked by CI + /smoke-check
```

## Installing GdUnit4

GdUnit4 is the project-standard test framework for GDScript. Install once before
writing the first test:

1. Open Godot → AssetLib → search **GdUnit4** → Download & Install.
2. Project → Project Settings → Plugins → enable **GdUnit4** ✓.
3. Restart the Godot editor.
4. Verify: `res://addons/gdunit4/` exists.

## Running Tests

**From the editor:** open any test file under `tests/unit/` or `tests/integration/`,
then click the green play-arrow gutter icons GdUnit4 injects, or use the GdUnit
Inspector dock to run the full suite.

**Headless (CLI / CI):**

```sh
godot --headless --script tests/gdunit4_runner.gd
```

The runner exits 0 on all-pass, non-zero on any failure. CI runs this via
`MikeSchulze/gdUnit4-action@v1` (see `.github/workflows/tests.yml`).

## Test Naming

| Element | Convention | Example |
|---|---|---|
| File | `[system]_[feature]_test.gd` | `combat_damage_test.gd` |
| Class | inherits `GdUnitTestSuite` | `extends GdUnitTestSuite` |
| Function | `test_[scenario]_[expected_result]` | `test_base_attack_returns_expected_damage()` |

Per `.claude/docs/coding-standards.md`:
- **Determinism**: tests must produce the same result every run — no random seeds, no time-dependent assertions.
- **Isolation**: each test sets up and tears down its own state; tests must not depend on execution order.
- **No hardcoded data**: fixtures use constant files or factory functions, not inline magic numbers (exception: boundary-value tests where the exact number is the point).
- **Independence**: unit tests never call external APIs / databases / file I/O — use dependency injection.

## Story Type → Test Evidence

Per `.claude/docs/coding-standards.md`:

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| **UI** (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `tests/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

## What NOT to Automate

Per coding standards:
- Visual fidelity (shader output, VFX appearance, animation curves).
- "Feel" qualities (input responsiveness, perceived weight, timing).
- Platform-specific rendering (test on target hardware, not headlessly).
- Full gameplay sessions (covered by playtesting, not automation).

## CI

Tests run automatically on every push to `main` and every pull request via
`MikeSchulze/gdUnit4-action@v1` on Ubuntu runners. A failed suite blocks merging.

Never disable or skip a failing test to make CI pass — fix the underlying issue.

## Per-System Subdirectories

When writing the first test for a new system, create a per-system subdirectory:

```
tests/unit/combat/
tests/unit/stealth_ai/
tests/unit/save_load/
tests/integration/document_flow/
```

This keeps the test tree mirror-shaped to `src/`.

## Engine Version Notes

GdUnit4 is verified against Godot 4.6 (project pin). If the engine is upgraded
beyond 4.6, re-verify GdUnit4 compatibility against
`docs/engine-reference/godot/VERSION.md` and `breaking-changes.md` before
committing the upgrade.
