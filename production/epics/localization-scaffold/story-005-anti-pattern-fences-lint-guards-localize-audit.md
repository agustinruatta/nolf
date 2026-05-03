# Story 005: Anti-pattern fences + lint guards + /localize audit hook

> **Epic**: Localization Scaffold
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 1-2 hours (S — registry edits + 5 lint test cases + audit invocation doc)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/localization-scaffold.md`
**Requirement**: enforces TR-LOC-001 (`tr()` mandate / `hardcoded_visible_string` forbidden), TR-LOC-008 (LTR-only at MVP, no hardcoded LTR assumptions), and the discipline rules from TR-LOC-002 (key naming) and TR-LOC-007 (no caching)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry)
**ADR Decision Summary**: ADR-0004 registers `hardcoded_visible_string` as a forbidden pattern. Per GDD §Detailed Design Rule 9, the Localization Scaffold defines five forbidden patterns (`hardcoded_visible_string`, `key_in_code_as_english`, `positional_format_substitution`, `context_column_omitted`, `cached_translation_at_ready`) registered in `docs/registry/architecture.yaml` and enforced by code review + the `/localize` audit skill. This story registers the patterns + adds CI grep guards + documents the `/localize` audit invocation as a pre-merge step.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Lint tests are pure file-system reads + regex/grep; no engine API risk. The `/localize` skill exists at `.claude/skills/localize/` and provides the audit harness; this story integrates it as a pre-merge audit step.

**Control Manifest Rules (Foundation)**:
- Required: anti-pattern fences are registered in `docs/registry/architecture.yaml` AND have CI-enforced lint tests (per ADR-0004 G4 closure + GDD Rule 9)
- Required: `/localize` audit runs as part of pre-merge validation (per GDD §Detailed Design "/localize skill integration")
- Forbidden: silently dropping a fence (e.g., disabling the lint test or removing a registry row without an ADR amendment retiring the fence)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria 1, 2, 3, 4, 5, 15 + §Detailed Design Rule 9:*

- [ ] **AC-1**: `docs/registry/architecture.yaml` contains a `forbidden_patterns` entry for `hardcoded_visible_string` with: `pattern_name`, `owning_adr: adr-0004`, `severity: HIGH`, `description`, `detection_strategy`, `related_acs`, `test_file`. (GDD AC-1; the most load-bearing fence — every UI epic depends on this discipline.)
- [ ] **AC-2**: Registry entry for `key_in_code_as_english` with same fields; `severity: MEDIUM`. (GDD AC-3; catches `tr("Start Mission")` violations.)
- [ ] **AC-3**: Registry entry for `positional_format_substitution` with same fields; `severity: MEDIUM`. (GDD §Detailed Design Rule 4 / Rule 9; catches `tr("...") % [n]` patterns that don't survive translation.)
- [ ] **AC-4**: Registry entry for `context_column_omitted` with same fields; `severity: HIGH`. (GDD AC-4 + Rule 3; CSVs without context cells are translator-blockers.)
- [ ] **AC-5**: Registry entry for `cached_translation_at_ready` with same fields; `severity: MEDIUM`. (GDD §Detailed Design Rule 9 + Edge Cases; catches stale-cache bugs on locale switch.)
- [ ] **AC-6**: `tests/unit/foundation/localization_lint_test.gd` exists and contains test cases for each of the five patterns:
    - **Pattern 1 lint**: greps `src/**/*.gd` for assignments to `Label.text`, `Button.text`, `RichTextLabel.text` of bare string literals (excluding empty string and tr() calls); fails on any match (GDD AC-1)
    - **Pattern 2 lint**: greps `src/**/*.gd` for `tr("...")` where the argument contains a space or capital letter (GDD AC-3)
    - **Pattern 3 lint**: greps `src/**/*.gd` for `tr(...) % [...]` (positional substitution applied to tr() result) (GDD §Rule 4)
    - **Pattern 4 lint**: parses every CSV in `res://translations/` and asserts every data row has a non-empty `# context` cell (GDD AC-4)
    - **Pattern 5 lint**: greps `src/**/*.gd` for `var\s+\w+\s*[:=]\s*tr\(` inside `_ready()` bodies AND the same file does NOT contain `NOTIFICATION_TRANSLATION_CHANGED` (GDD AC-9 + Rule 9)
- [ ] **AC-7**: A test verifies no two CSV rows across all production CSVs share the same `keys` value (GDD AC-5 — cross-domain key collision detection).
- [ ] **AC-8**: A test verifies every key in every CSV matches the 3-segment regex `^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$` (GDD AC-2 — domain-prefixed dot-notation; also enforced in Story 001 but registered as a permanent lint here).
- [ ] **AC-9**: Lint test failure messages cite the relevant rule + ADR + GDD AC, and identify the specific file + line + pattern instance. Format: `"Forbidden pattern <name> detected in <file>:<line>: <matched_text>. See ADR-0004 §Risks + GDD AC-<N>. Refactor: <hint>."`
- [ ] **AC-10**: Documentation row in `production/qa/evidence/` OR a comment in the lint test file documents how to run the `/localize` audit skill (`/localize audit` invocation) as the heavier pre-merge audit step that the CI lint tests complement (the lint tests are fast greps; the audit is a thorough scan with key drift detection per GDD AC-15).

---

## Implementation Notes

*Derived from GDD §Detailed Design Rule 9 + Edge Cases + ADR-0004 §Risks:*

**Registry structure** (extending the schema from save-load Story 009):

```yaml
# docs/registry/architecture.yaml
forbidden_patterns:
  # ... existing entries from save-load Story 009 ...

  - pattern_name: hardcoded_visible_string
    owning_adr: adr-0004
    severity: HIGH
    description: >
      User-visible strings (Label.text, Button.text, RichTextLabel.text, etc.)
      must be wrapped in tr("key"). Bare English literals freeze the string
      as untranslatable for any future locale and force a project-wide
      string-hunting refactor.
    detection_strategy: |
      Grep src/**/*.gd for assignments matching:
        \.text\s*=\s*"[^"]+"
      where the right-hand string is non-empty and not wrapped in tr().
      Also catches RichTextLabel.bbcode_text, AcceptDialog.dialog_text,
      and similar visible-text properties.
    related_acs:
      - "GDD AC-1"
      - "ADR-0004 Rule 9"
    test_file: tests/unit/foundation/localization_lint_test.gd

  - pattern_name: key_in_code_as_english
    owning_adr: adr-0004
    severity: MEDIUM
    description: >
      Translation keys must follow domain.context.identifier dot-notation,
      not English sentences. tr("Start Mission") treats the English string
      as the key, which fragments the translation table and breaks fallback.
    detection_strategy: |
      Grep src/**/*.gd for tr("...") arguments containing a space or
      a capital letter (excluding the leading lowercase domain segment).
      Keys are lowercase snake_case dot-separated.
    related_acs:
      - "GDD AC-3"
    test_file: tests/unit/foundation/localization_lint_test.gd

  - pattern_name: positional_format_substitution
    owning_adr: adr-0004
    severity: MEDIUM
    description: >
      Parameterized strings must use named placeholders ({count}) via
      String.format(), not positional %s. Word order differs between
      languages; positional substitution forces English's order on
      translators.
    detection_strategy: |
      Grep src/**/*.gd for tr(...) %  [...] pattern (regex captures
      tr() call followed by % and an array literal).
    related_acs:
      - "GDD Rule 4"
    test_file: tests/unit/foundation/localization_lint_test.gd

  - pattern_name: context_column_omitted
    owning_adr: adr-0004
    severity: HIGH
    description: >
      Every CSV row in res://translations/ must have a non-empty
      `# context` cell. Empty context strands translators without
      tonal, length, or placement information — translation quality
      drops or errors slip in.
    detection_strategy: |
      Parse every CSV in res://translations/ and assert every data
      row's `# context` column is non-empty (length > 0,
      whitespace-only does NOT satisfy).
    related_acs:
      - "GDD AC-4"
      - "GDD Rule 3"
    test_file: tests/unit/foundation/localization_lint_test.gd

  - pattern_name: cached_translation_at_ready
    owning_adr: adr-0004
    severity: MEDIUM
    description: >
      Storing tr() result in a var at _ready() without a
      _notification(NOTIFICATION_TRANSLATION_CHANGED) handler causes
      stale strings on locale switch (label remains in old locale
      while UI re-renders to new). Either use auto_translate_mode
      (declarative) or _notification (programmatic).
    detection_strategy: |
      Grep src/**/*.gd for `var\s+\w+\s*[:=]\s*tr\(` inside _ready()
      function bodies AND the same script does NOT contain
      NOTIFICATION_TRANSLATION_CHANGED. False positives possible
      where the cached var IS refreshed via auto_translate_mode on
      a child node — manual review on lint failure.
    related_acs:
      - "GDD AC-9"
      - "GDD Rule 9"
    test_file: tests/unit/foundation/localization_lint_test.gd
```

**Lint test structure** (gdunit4 pattern):

```gdscript
# tests/unit/foundation/localization_lint_test.gd
extends GdUnitTestSuite

const SRC_DIR := "res://src/"
const TRANSLATIONS_DIR := "res://translations/"

func test_hardcoded_visible_string_pattern_absent() -> void:
    var matches := _grep_recursive(SRC_DIR, "*.gd",
        RegEx.create_from_string("\\.(text|bbcode_text|dialog_text)\\s*=\\s*\"[^\"]+\""))
    # Filter out tr() wrapped assignments, empty strings
    var violations := matches.filter(func(m): return not _is_tr_wrapped(m) and not _is_empty(m))
    assert_array(violations).is_empty()
    # On failure: list each violation with file:line + offending source

func test_key_in_code_as_english_pattern_absent() -> void:
    var tr_calls := _grep_recursive(SRC_DIR, "*.gd",
        RegEx.create_from_string("tr\\(\"([^\"]+)\"\\)"))
    var violations := tr_calls.filter(func(m): return _looks_like_english(m.captured))
    assert_array(violations).is_empty()

func test_positional_format_substitution_absent() -> void:
    var matches := _grep_recursive(SRC_DIR, "*.gd",
        RegEx.create_from_string("tr\\([^)]+\\)\\s*%\\s*\\["))
    assert_array(matches).is_empty()

func test_context_column_present_in_all_csv_rows() -> void:
    var csv_files := _list_csvs(TRANSLATIONS_DIR)
    for csv_path in csv_files:
        if csv_path.contains("_dev_pseudo"):
            continue  # pseudo CSV is dev-only; skip context check
        var rows := _parse_csv(csv_path)
        for row in rows:
            assert_str(row.get("# context", "")).is_not_empty()

func test_cached_translation_at_ready_absent() -> void:
    var files := _list_gd_files(SRC_DIR)
    for file_path in files:
        var source := _read_file(file_path)
        if not source.contains("_ready()"):
            continue
        var ready_body := _extract_function_body(source, "_ready")
        if not ready_body.contains("tr("):
            continue
        # File has tr() in _ready — must also have NOTIFICATION_TRANSLATION_CHANGED
        assert_str(source).contains("NOTIFICATION_TRANSLATION_CHANGED")

func test_no_cross_domain_key_collisions() -> void:
    var all_keys: Dictionary = {}  # key -> source CSV
    for csv_path in _list_csvs(TRANSLATIONS_DIR):
        if csv_path.contains("_dev_pseudo"):
            continue
        var rows := _parse_csv(csv_path)
        for row in rows:
            var key: String = row.get("keys", "")
            assert_bool(all_keys.has(key)).is_false()
            all_keys[key] = csv_path

func test_all_keys_match_3_segment_regex() -> void:
    var key_regex := RegEx.create_from_string("^[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*\\.[a-z][a-z0-9_]*(\\.[a-z0-9_]+)*$")
    for csv_path in _list_csvs(TRANSLATIONS_DIR):
        if csv_path.contains("_dev_pseudo"):
            continue
        var rows := _parse_csv(csv_path)
        for row in rows:
            var key: String = row.get("keys", "")
            assert_object(key_regex.search(key)).is_not_null()
```

**`/localize audit` integration**: per GDD §Detailed Design "/localize skill integration", the audit is a heavier scan than the CI lint. CI lint catches lit-pattern violations on every PR; `/localize audit` (manual or scheduled) catches drift (orphan keys, missing keys, untranslated keys). At MVP, `/localize audit` is a manual pre-merge step for PRs that touch `src/**/*.gd` or `translations/`. Document this in a comment block at the top of `localization_lint_test.gd`:

```gdscript
# Localization Lint Test
#
# This test enforces structural patterns from GDD §Detailed Design Rule 9.
# It runs in CI on every PR and catches the LIT version of forbidden patterns.
#
# For deeper validation (orphan keys, drift, missing translations), run
# `/localize audit` manually before merging large UI / content PRs.
# See GDD §Detailed Design "/localize skill integration".
```

**Why split lint and audit**: lint is fast (regex grep, runs in seconds, blocks PRs cheaply). Audit is thorough (parses all CSVs, walks all `tr()` call sites, generates translator-ready reports — runs in seconds-to-minutes, used selectively).

**False-positive triage** (Pattern 1 — `hardcoded_visible_string`): some legitimate uses set `text = ""` (clearing) or assign a runtime-built string (concatenation, format result) that isn't a literal. The test must distinguish:
- `text = ""` → empty literal → ALLOWED (clearing)
- `text = tr("key")` → wrapped → ALLOWED
- `text = some_var` → not a literal → ALLOWED (variable; variable's source is checked elsewhere)
- `text = "Start Mission"` → bare literal → FORBIDDEN

Regex: match the literal pattern but exclude tr-wrapped and empty-literal forms. False-positives reviewed manually.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: production CSV registration (already done; this story scans those CSVs)
- Story 002: pseudolocalization (already done; pseudo CSV is excluded from context-omitted lint per implementation note)
- Story 003: plural forms (already done; this story's lint catches positional substitution but doesn't verify plural correctness — that's Story 003's domain)
- Story 004: `auto_translate_mode` discipline (already done; this story's `cached_translation_at_ready` lint complements Story 004's pattern enforcement)
- Runtime forbidden-pattern detection (e.g., a startup check) — out of MVP scope; CI lint is sufficient
- LTR-only lint (TR-LOC-008) — there's no syntactic anti-pattern for LTR violations beyond hardcoded layout direction; deferred to UI epic code review
- Full `/localize` skill implementation — already exists at `.claude/skills/localize/`; this story integrates the invocation as a documented pre-merge step

---

## QA Test Cases

**AC-1 — `hardcoded_visible_string` registry entry**
- **Given**: `docs/registry/architecture.yaml` after this story
- **When**: a unit test reads the file and searches for the pattern entry
- **Then**: file contains a `forbidden_patterns` row whose `pattern_name == hardcoded_visible_string`, `owning_adr == adr-0004`, `severity == HIGH`, with non-empty description + detection strategy
- **Edge cases**: registry file does not exist (Story 009 of save-load epic creates it; if this story runs first, this story creates it)

**AC-2 — `key_in_code_as_english` registry entry**
- **Given**: same
- **When**: same
- **Then**: contains row with `pattern_name == key_in_code_as_english`, `severity == MEDIUM`

**AC-3 — `positional_format_substitution` registry entry**
- **Given**: same
- **When**: same
- **Then**: contains row with `pattern_name == positional_format_substitution`, `severity == MEDIUM`

**AC-4 — `context_column_omitted` registry entry**
- **Given**: same
- **When**: same
- **Then**: contains row with `pattern_name == context_column_omitted`, `severity == HIGH`

**AC-5 — `cached_translation_at_ready` registry entry**
- **Given**: same
- **When**: same
- **Then**: contains row with `pattern_name == cached_translation_at_ready`, `severity == MEDIUM`

**AC-6 — Lint tests run for all 5 patterns**
- **Given**: `tests/unit/foundation/localization_lint_test.gd` after this story
- **When**: gdunit4 runner discovers the file
- **Then**: 5 lint test functions are present, each named for one of the 5 patterns; each runs to assertion and passes (or fails with diagnostic) on the current production tree
- **Edge cases**: deliberately constructed test fixture (a temporary file with a forbidden pattern) — lint catches it; document in test comments how to add such a fixture for regression coverage

**AC-7 — Cross-domain key collision detection**
- **Given**: production CSVs after Story 001
- **When**: collision-detection test runs
- **Then**: zero collisions (every key is unique across all CSVs); failure lists colliding keys with their source CSVs
- **Edge cases**: domain-prefixed naming convention prevents collisions structurally — test catches drift if a future PR adds a key without the proper domain prefix

**AC-8 — All keys match 3-segment regex**
- **Given**: production CSVs
- **When**: regex validation test runs
- **Then**: every key matches `^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$`
- **Edge cases**: 4-segment keys (e.g., `dialogue.guard.patrol.line_03`) match (`(\.[a-z0-9_]+)*` is greedy); 2-segment keys fail; `_dev_pseudo` keys are excluded from this test (pseudo file is dev-only)

**AC-9 — Lint failure messages are actionable**
- **Given**: a deliberately injected forbidden pattern in a test-fixture file
- **When**: lint test runs against the fixture
- **Then**: failure message identifies (a) the pattern name, (b) the file + line, (c) the matched text, (d) cites ADR-0004 + GDD AC, (e) gives a refactor hint
- **Edge cases**: real production code rarely fails (codebase is small at MVP); the message format is verified via a test-only fixture in `tests/fixtures/localization/`

**AC-10 — `/localize audit` invocation documented**
- **Given**: project documentation
- **When**: a developer searches for "localize audit"
- **Then**: at least one location (test file comment OR `production/qa/evidence/` doc OR contributor README) documents the `/localize audit` invocation as the heavier pre-merge audit step that complements the CI lint
- **Edge cases**: minimum viable doc is a comment block at the top of `localization_lint_test.gd` (cited in AC-10 above)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/foundation/localization_lint_test.gd` — must exist and pass
- Registry file `docs/registry/architecture.yaml` updated with 5 new `forbidden_patterns` rows
- Smoke check passes (per `.claude/docs/coding-standards.md` Config/Data row: "smoke check pass `production/qa/smoke-*.md`")

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (production CSVs must exist for lint to scan), Story 002 (pseudo CSV exclusion from context-column lint), Story 003 (positional-substitution lint complements plural-form work), Story 004 (cached-translation-at-ready lint complements `auto_translate_mode` discipline)
- Unlocks: every future UI epic — they inherit the static fences automatically; PRs introducing forbidden patterns are caught by CI before merge
