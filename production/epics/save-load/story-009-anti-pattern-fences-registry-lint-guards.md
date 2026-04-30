# Story 009: Anti-pattern fences + registry entries + lint guards

> **Epic**: Save / Load
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 1 hour (S — registry edits + 3 lint test cases)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: enforces TR-SAV-003 (`save_service_assembles_state` forbidden pattern), TR-SAV-007 (`save_state_uses_node_references` forbidden pattern), and ADR-0003 IG 3 (`forgotten_duplicate_deep_on_load`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: ADR-0003 §Risks + §Validation Criteria require three forbidden-pattern fences to be registered in `docs/registry/architecture.yaml`: (1) `save_service_assembles_state` — SaveLoadService must not query game systems to assemble a SaveGame; (2) `save_state_uses_node_references` — saved Resources must not contain `NodePath` or `Node`-typed fields; (3) `forgotten_duplicate_deep_on_load` — callers must call `duplicate_deep()` before handing nested state to live systems. Each fence pairs a registry entry (declarative documentation) with a lint test (CI-enforced grep check). Story 002 / Story 004 already include runtime tests for the *behaviors* covered by these patterns — this story adds the *static lint* layer.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Lint tests are pure GDScript file-system reads + regex/string searches; no engine API risk. The architecture registry is `docs/registry/architecture.yaml` (per ADR-0003 §Related, ADR-0007 §Related) — a YAML file edited as flat text.

**Control Manifest Rules (Foundation)**:
- Required: anti-pattern fences are registered in `docs/registry/architecture.yaml` AND have a CI-enforced lint test (per ADR-0003 §Validation Criteria final bullet "Anti-pattern fence registered: ...")
- Required: each fence's lint test must run on every `save_load_service.gd` and `*_State.gd` source change (CI integration is via the test runner discovering the test file)
- Forbidden: silently dropping a fence (e.g., disabling the lint test without an ADR amendment retiring the fence)

---

## Acceptance Criteria

*From ADR-0003 §Validation Criteria + §Risks + §Anti-Pattern fences:*

- [ ] **AC-1**: `docs/registry/architecture.yaml` contains a `forbidden_patterns` entry for `save_service_assembles_state` with: `pattern_name`, `owning_adr: adr-0003`, `description` (1-2 sentences), `detection_strategy` (grep rule), `severity: HIGH`. (Per ADR-0003 §Risks row "SaveLoadService drifts toward becoming a service locator" — probability MEDIUM, impact HIGH.)
- [ ] **AC-2**: `docs/registry/architecture.yaml` contains a `forbidden_patterns` entry for `save_state_uses_node_references` with the same fields; `severity: HIGH`. (Per ADR-0003 §Risks "Subscriber forgets duplicate_deep on load" / NodePath survival rule from IG 6.)
- [ ] **AC-3**: `docs/registry/architecture.yaml` contains a `forbidden_patterns` entry for `forgotten_duplicate_deep_on_load` with the same fields; `severity: MEDIUM`. (Per ADR-0003 IG 3 + §Risks; a load-side discipline that callers must follow.)
- [ ] **AC-4**: `tests/unit/foundation/save_load_anti_pattern_lint_test.gd` exists and contains test cases for each of the three patterns:
    - **Pattern 1 lint**: greps `src/core/save_load/save_load_service.gd` for game-system class names (`PlayerCharacter`, `StealthAI`, `CivilianAI`, `Inventory`, `Combat`, `MissionLevelScripting`, `FailureRespawn`, `DocumentCollection`); fails the test if any match found (excluding comments per AC-9 of Story 002).
    - **Pattern 2 lint**: greps `src/core/save_load/states/*.gd` for `NodePath` (typed `@export var foo: NodePath`) or `Node` (`@export var foo: Node`); fails if any match.
    - **Pattern 3 lint**: this is a discipline-pattern (caller-side); the lint approximation is to grep all callers of `SaveLoad.load_from_slot` (project-wide search) and verify each has a `duplicate_deep()` call within ~10 lines of the load result usage. At MVP, with no callers yet (Mission Scripting / F&R / Menu System haven't been implemented), the test asserts only that the registry entry exists (deferred lint until callers exist; flag in test docstring).
- [ ] **AC-5**: AC-24 from GDD (`save_load_service.gd` source contains no game-system references) is enforced by Pattern 1 lint. AC-25 from GDD (`*_State.gd` files contain no `NodePath` / `Node` `@export` fields) is enforced by Pattern 2 lint.
- [ ] **AC-6**: Each lint test failure produces a clear actionable message: `"Forbidden pattern <name> detected in <file>:<line>: <matched_text>. See ADR-0003 §Risks. Refactor: <hint>."` (per coding standards: failures must be diagnostic, not just boolean).
- [ ] **AC-7**: The lint tests run as part of the standard test suite — no separate invocation. Discovered by `tests/gdunit4_runner.gd` (per `.claude/docs/coding-standards.md` CI/CD rules); failures block CI pass.
- [ ] **AC-8**: Registry entries cross-reference the corresponding control manifest rows (`docs/architecture/control-manifest.md` lines 88, 89, 90 — already present for these three patterns; cross-reference verifies the manifest mention links to a registered pattern).

---

## Implementation Notes

*Derived from ADR-0003 §Risks + §Validation Criteria + §Related (`docs/registry/architecture.yaml` mention):*

**Registry structure** (assumed YAML schema based on ADR-0007 §Validation Criteria language and ADR-0002 references):

```yaml
# docs/registry/architecture.yaml
forbidden_patterns:
  - pattern_name: save_service_assembles_state
    owning_adr: adr-0003
    severity: HIGH
    description: >
      SaveLoadService must not query game systems (PlayerCharacter, StealthAI,
      Inventory, Mission Scripting, Failure & Respawn, etc.) to assemble a
      SaveGame. The caller assembles; the service writes/reads only. Drift
      toward this pattern turns SaveLoadService into a service locator and
      violates the decoupling-by-design contract from ADR-0003.
    detection_strategy: |
      Grep src/core/save_load/save_load_service.gd for any of the gameplay
      system class names (PlayerCharacter, StealthAI, CivilianAI, Inventory,
      Combat, MissionLevelScripting, FailureRespawn, DocumentCollection).
      Zero matches required.
    related_acs:
      - "GDD AC-24"
      - "Story 002 AC-9"
    test_file: tests/unit/foundation/save_load_anti_pattern_lint_test.gd

  - pattern_name: save_state_uses_node_references
    owning_adr: adr-0003
    severity: HIGH
    description: >
      Saved Resources (SaveGame and *_State sub-resources) must not contain
      NodePath-typed or Node-typed @export fields. Per-actor identity uses
      stable actor_id: StringName instead. NodePaths/Nodes do not survive
      scene reloads — saved Resources containing them break on load.
    detection_strategy: |
      Grep src/core/save_load/states/*.gd for the patterns
      `@export var .*: NodePath` or `@export var .*: Node` (or any subclass
      of Node). Zero matches required.
    related_acs:
      - "GDD AC-25"
      - "ADR-0003 IG 6"
    test_file: tests/unit/foundation/save_load_anti_pattern_lint_test.gd

  - pattern_name: forgotten_duplicate_deep_on_load
    owning_adr: adr-0003
    severity: MEDIUM
    description: >
      Callers of SaveLoad.load_from_slot() must call .duplicate_deep() on
      the returned SaveGame before handing nested state to live systems.
      Without duplicate_deep, live mutations would mutate the cached loaded
      resource, corrupting the save view on subsequent reloads.
    detection_strategy: |
      Project-wide grep for callers of SaveLoad.load_from_slot. Each
      caller's usage of the return value should be paired with a
      .duplicate_deep() call within ~10 lines. At MVP, with no callers
      yet (Mission Scripting / F&R / Menu System are post-Foundation
      epics), the lint asserts only that this registry entry exists;
      deferred lint activates when first caller appears.
    related_acs:
      - "GDD AC-17"
      - "GDD AC-18"
      - "ADR-0003 IG 3"
      - "Story 004 (production-scope runtime test)"
    test_file: tests/unit/foundation/save_load_anti_pattern_lint_test.gd
```

**Lint test structure** (gdunit4 pattern):

```gdscript
# tests/unit/foundation/save_load_anti_pattern_lint_test.gd
extends GdUnitTestSuite

const SAVE_LOAD_SERVICE_PATH := "res://src/core/save_load/save_load_service.gd"
const STATES_DIR := "res://src/core/save_load/states/"

const FORBIDDEN_GAMEPLAY_CLASSES := [
    "PlayerCharacter", "StealthAI", "CivilianAI", "Inventory",
    "Combat", "MissionLevelScripting", "FailureRespawn", "DocumentCollection"
]

func test_save_service_assembles_state_pattern_absent() -> void:
    var source := _read_file_no_comments(SAVE_LOAD_SERVICE_PATH)
    for class_name_str in FORBIDDEN_GAMEPLAY_CLASSES:
        assert_str(source).does_not_contain(class_name_str)
        # On failure: "Forbidden pattern save_service_assembles_state detected
        # in save_load_service.gd: <class_name>. See ADR-0003 §Risks. Refactor:
        # remove the gameplay-system reference; SaveLoadService accepts a
        # pre-assembled SaveGame from callers."

func test_save_state_uses_node_references_pattern_absent() -> void:
    var dir := DirAccess.open(STATES_DIR)
    var files := dir.get_files()
    for filename in files:
        if not filename.ends_with(".gd"):
            continue
        var source := _read_file_no_comments(STATES_DIR + filename)
        # Match @export var X: NodePath or @export var X: Node (with optional generic / type variants)
        var nodepath_regex := RegEx.create_from_string("@export\\s+var\\s+\\w+\\s*:\\s*NodePath")
        var node_regex := RegEx.create_from_string("@export\\s+var\\s+\\w+\\s*:\\s*Node\\b")
        assert_object(nodepath_regex.search(source)).is_null()
        assert_object(node_regex.search(source)).is_null()

func test_forgotten_duplicate_deep_on_load_registry_present() -> void:
    var registry := _read_file("res://docs/registry/architecture.yaml")
    assert_str(registry).contains("forgotten_duplicate_deep_on_load")
    # Caller-site lint deferred — activated when Mission Scripting / F&R / Menu System ship.
```

**Comment-stripping for Pattern 1**: Pattern 1's grep should ignore comments because future search-and-replace refactors might leave a class name in a comment by accident — but a strict grep would false-fail. Strip `#` and `##` comments before searching. (Or, document the convention: "no such mentions even in comments" — this story chooses the strict interpretation; comment-stripped grep is the correct heuristic.)

**Architecture registry might not exist yet at this story's implementation time**. If `docs/registry/architecture.yaml` does not exist:
- This story creates it with the schema above (`forbidden_patterns` as the top-level key)
- Future ADRs add their own entries to the same file
- Story 002 / 003 / 005 / 006 of the signal-bus epic may have already created it; check first

**No CI guard for the registry-control-manifest cross-reference itself** (AC-8) — this is a documentation-discipline assertion, not a lint. The control manifest already references all three patterns by name (lines 88, 89, 90). This story verifies the registry has matching entries; manifest staleness is tracked via the `Manifest Version` date field.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: runtime tests for atomic write + IO_ERROR + RENAME_FAILED (the *behavior* tests — this story is the *static lint* layer)
- Story 004: production-scope `duplicate_deep` runtime test on the SaveGame schema (this story registers the static fence; Story 004 proves the API works on the production schema)
- Caller-side lint expansion (Pattern 3) — activates when Mission Scripting / F&R / Menu System epics introduce callers of `load_from_slot`; this story leaves the lint as registry-existence assertion only
- Runtime forbidden-pattern detection at game launch (e.g., a startup check that grep-tests the codebase) — out of MVP scope; CI lint is sufficient
- Other Save/Load anti-patterns not registered yet (e.g., "non-atomic save", "missing version check") — these are tested behaviorally in Stories 002–008; if patterns emerge that warrant registry rows, file an ADR amendment or open a follow-up story

---

## QA Test Cases

**AC-1 — `save_service_assembles_state` registry entry**
- **Given**: `docs/registry/architecture.yaml`
- **When**: a unit test loads the file as text and searches for the pattern entry
- **Then**: file contains a `forbidden_patterns` block with a row whose `pattern_name == save_service_assembles_state`, `owning_adr == adr-0003`, `severity == HIGH`, and a non-empty `description` + `detection_strategy`
- **Edge cases**: registry file does not exist → this story creates it with the row populated

**AC-2 — `save_state_uses_node_references` registry entry**
- **Given**: `docs/registry/architecture.yaml`
- **When**: same as AC-1
- **Then**: contains a row with `pattern_name == save_state_uses_node_references`, `severity == HIGH`, valid description + detection strategy

**AC-3 — `forgotten_duplicate_deep_on_load` registry entry**
- **Given**: same
- **When**: same
- **Then**: contains a row with `pattern_name == forgotten_duplicate_deep_on_load`, `severity == MEDIUM`, valid description + detection strategy; description notes that caller-site lint is deferred until callers exist

**AC-4 — Pattern 1 lint (no game-system refs in service)**
- **Given**: production `save_load_service.gd` (post-Stories 002, 003, 005, 006, 007, 008)
- **When**: lint test runs grep for forbidden gameplay class names
- **Then**: zero matches in non-comment source; test passes
- **Edge cases**: a future PR adds `import PlayerCharacter` to service → lint catches it; a comment containing the class name in passing → comment-stripped grep correctly ignores it

**AC-5 — Pattern 2 lint (no NodePath / Node @export in *_State files)**
- **Given**: 7 sub-resource files in `src/core/save_load/states/` (post-Story 001)
- **When**: lint test regex-searches each file for `@export var X: NodePath` or `@export var X: Node`
- **Then**: zero matches across all files
- **Edge cases**: `@export var X: NodePath = NodePath()` (with default value) → still caught by the regex; `@export var nodes: Array[Node]` → also caught (subclass of Node match)

**AC-6 — Lint failure messages are actionable**
- **Given**: a deliberate test fixture — temporarily add a forbidden pattern (e.g., add `@export var path: NodePath` to a stub state file in a fixture directory, NOT in production)
- **When**: lint test runs against the fixture
- **Then**: assertion failure message identifies (a) the pattern name, (b) the file + matched line, (c) cites ADR-0003, (d) gives a refactor hint
- **Edge cases**: the fixture is in a `tests/fixtures/` subdirectory so it doesn't pollute production code; lint is parameterized to point at production paths in real runs

**AC-7 — Lint runs in standard CI test suite**
- **Given**: CI runs `godot --headless --script tests/gdunit4_runner.gd`
- **When**: the runner discovers tests
- **Then**: `save_load_anti_pattern_lint_test.gd` is included; lint failures cause the runner to exit non-zero (fails CI)
- **Edge cases**: a developer disables the test locally (e.g., adds `@warning_ignore` or comments out an assertion) → code review catches it; no skipping of failing tests is allowed (per `.claude/docs/coding-standards.md` Testing Standards "Never disable or skip failing tests")

**AC-8 — Registry / control manifest cross-reference**
- **Given**: `docs/architecture/control-manifest.md` lines 88–90 (the three Save/Load anti-pattern rows)
- **When**: a documentation-consistency test reads each line and checks the registry for a matching `pattern_name`
- **Then**: each control-manifest mention has a corresponding registry row with the same `pattern_name`
- **Edge cases**: a future control-manifest revision adds a 4th anti-pattern row but forgets the registry → test fires; flag for review

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/foundation/save_load_anti_pattern_lint_test.gd` — must exist and pass
- Registry file `docs/registry/architecture.yaml` updated with 3 new `forbidden_patterns` rows
- Smoke check passes (per `.claude/docs/coding-standards.md` Config/Data row: "smoke check pass `production/qa/smoke-*.md`")

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (sub-resource files exist for Pattern 2 lint to inspect), Story 002 (`save_load_service.gd` exists for Pattern 1 lint to inspect), Story 004 (runtime proof of `duplicate_deep` discipline complements this static lint)
- Unlocks: future epics that touch SaveLoad (Mission Scripting, F&R, Menu System) — they inherit the static fences automatically; if a future PR introduces a forbidden pattern, the lint catches it
