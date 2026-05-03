# Story 003: Plural forms (CSV plural columns) + named-placeholder discipline

> **Epic**: Localization Scaffold
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1-2 hours (S — one pluralized example end-to-end + named-placeholder pattern doc)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/localization-scaffold.md`
**Requirement**: TR-LOC-004 (named placeholders `{count}` via `String.format()` on `tr()`; positional `%s` forbidden), TR-LOC-005 (plural forms via Godot 4.6 CSV plural columns `en_0`, `en_1`, etc.)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry)
**ADR Decision Summary**: Pluralization is handled via Godot 4.6's built-in CSV plural form columns (no Gettext required). Per GDD §Detailed Design Rule 5: add a `# plural_rule` annotation in the context column and define columns per Godot 4.6's CSV plural format (`en_0`, `en_1`, etc. for zero/one/other). Dynamic strings substitute via named placeholders (`{count}`) using `String.format()` applied to `tr()` result; positional `%s` is forbidden because word order differs between languages.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (CSV plural form support is post-cutoff per ADR-0004 Engine Compatibility — released in 4.6 Jan 2026)
**Engine Notes**: Godot 4.6 adds CSV plural form support without Gettext dependency. Plural columns follow CLDR plural rules — for English: `_0` (zero), `_1` (one), `_other` (everything else). Pluralization is invoked via `tr_n("key", "key_plural", count)` (Godot's plural-aware translation function) OR via direct column selection at runtime. ADR-0004 §Engine Compatibility flags this as a knowledge-risk item; this story's smoke test serves as the verification gate that the Godot 4.6 CSV plural API works as documented.

**Control Manifest Rules (Foundation)**:
- Required: parameterized strings use named placeholders `{name}` via `String.format()`, NOT positional `%s` (forbidden pattern `positional_format_substitution` — formal registration in Story 005)
- Required: plural keys have `# plural_rule` annotation in the `# context` column
- Required: `tr_n()` (or equivalent Godot 4.6 plural API) is used for plural-aware lookup, NOT manual concatenation

---

## Acceptance Criteria

*From GDD §Acceptance Criteria 10 + §Detailed Design Rules 4 + 5:*

- [ ] **AC-1**: A pluralized example key exists in a domain CSV (recommended: `hud.collection.count` in `hud.csv`) with at least three plural-form columns: `en_0` ("no documents"), `en_1` ("1 document"), `en_other` ("{count} documents collected"). The `# context` cell includes a `# plural_rule` annotation and documents the `count` variable.
- [ ] **AC-2**: GIVEN the pluralized key with `count = 0`, WHEN code calls the plural-aware lookup (`tr_n("hud.collection.count", "hud.collection.count", 0)` or Godot 4.6's equivalent), THEN it returns `"no documents"` (the `_0` form).
- [ ] **AC-3**: GIVEN `count = 1`, WHEN the lookup is called, THEN it returns `"1 document"` (the `_1` form).
- [ ] **AC-4**: GIVEN `count = 7`, WHEN the lookup is called with `String.format({"count": 7})` applied to the result, THEN the final string is `"7 documents collected"` (the `_other` form with `{count}` substituted).
- [ ] **AC-5**: A non-plural parameterized key example exists (e.g., `hud.section.entered_label` with English `"Entering: {section_name}"`). GIVEN code calls `tr("hud.section.entered_label").format({"section_name": "Plaza"})`, THEN the result is `"Entering: Plaza"` (named-placeholder substitution).
- [ ] **AC-6**: GIVEN any GDScript file under `src/`, WHEN grepped for `tr(.*)\s*%\s*\[` (positional substitution applied to a `tr()` result with `%` operator + array argument), THEN zero matches in production code (per Rule 4 — formal lint registration in Story 005).
- [ ] **AC-7**: GIVEN the smoke test runs on a clean Godot 4.6.x environment, WHEN it exercises plural lookup with `count = 0, 1, 2, 7`, THEN all four lookups return distinct expected strings AND verify Godot 4.6's CSV plural API works as documented in the engine reference (closes the verification-required item from ADR-0004 §Engine Compatibility for plural support).

---

## Implementation Notes

*Derived from GDD §Detailed Design Rules 4 + 5 + ADR-0004 §Engine Compatibility:*

**CSV plural row format** (per Godot 4.6 CSV plural support):

```csv
keys,en_0,en_1,en_other,# context
hud.collection.count,no documents,1 document,{count} documents collected,"# plural_rule: en (zero/one/other); HUD collection counter; max 35 chars; count = int (variable substituted via String.format); BQA neutral tone"
```

(Adjust column ordering — Godot's CSV importer should accept `en_0`, `en_1`, `en_other` as recognized plural columns. The `keys` column is the canonical key; per-locale plural columns layer on top.)

**Plural lookup at call site** (Godot 4.6 API — verify exact function name during implementation; based on engine reference `tr_n()` is the convention):

```gdscript
func _on_document_collected(total: int) -> void:
    var label_text: String = tr_n("hud.collection.count", "hud.collection.count", total).format({"count": total})
    _label.text = label_text
```

(Note: `tr_n()` typically takes singular_key, plural_key, count — for CSV plural forms a single key is used and the count drives column selection. Exact API: confirm during implementation. The smoke test in AC-7 is the verification gate.)

**Named placeholder discipline** (Rule 4):

```gdscript
# CORRECT:
var msg: String = tr("dialogue.greeting").format({"name": player_name})

# FORBIDDEN (positional):
var msg: String = tr("dialogue.greeting") % [player_name]   # forbidden_pattern: positional_format_substitution
```

**Why named over positional**: word order differs between languages. English: `"Hello, {name}!"` → French: `"Bonjour, {name} !"` — same placeholder name, different surrounding text. Positional `%s` would force the translator to maintain English's argument order, which breaks for languages where the variable lives elsewhere in the sentence.

**`# plural_rule` annotation**: per Rule 5, plural rows include the rule name in the context column for translator clarity. CLDR plural rules per language:
- English (`en`): zero, one, other
- French (`fr`): one, other (treats 0 as one)
- Polish (`pl`): one, few, many, other
- Russian (`ru`): one, few, many, other

At MVP only `en` plural columns are populated. Translators add language-specific plural columns post-launch (e.g., `pl_0`, `pl_1`, `pl_2`, `pl_3` for Polish).

**Why this is verification scope**: ADR-0004 §Engine Compatibility flags Godot 4.6 CSV plural support as MEDIUM knowledge risk. The LLM training cutoff predates 4.6's plural API. This story's smoke test (AC-7) is the production-scope verification — if the API behaves differently than documented, this story BLOCKS until the GDD is amended OR an alternative pluralization mechanism is chosen (e.g., manual count-based branching at call sites — uglier but workable).

**Pseudolocale plural handling** (Story 002 interaction): `_dev_pseudo.csv` does NOT need plural columns — pseudolocale is for length/layout stress-test, not plural correctness. Pseudo just uses the `_other` form's pseudo-translation for any plural key.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: base CSV registration (already done; this story extends one CSV with plural columns)
- Story 002: pseudolocalization (already done; pseudo plural handling noted above but no code change here)
- Story 004: `auto_translate_mode` discipline (orthogonal — labels with auto-translate work the same with or without plurals)
- Story 005: lint registration of `positional_format_substitution` forbidden pattern (this story uses the rule; Story 005 enforces it via CI)
- Plural columns for non-English locales — post-MVP translator deliverable
- Production-scope pluralized strings beyond the one example — added per consumer epic as needed (e.g., Inventory's "X gadgets remaining" if the design surfaces such a string)

---

## QA Test Cases

**AC-1 — Plural CSV row exists with required columns**
- **Given**: `translations/hud.csv` after this story
- **When**: a test parses the CSV and finds the `hud.collection.count` row
- **Then**: row has columns `en_0` (= "no documents"), `en_1` (= "1 document"), `en_other` (contains `{count}`); `# context` cell contains substring `# plural_rule`
- **Edge cases**: column order in CSV header may differ; test reads by column name not position

**AC-2 — Zero count returns en_0 form**
- **Given**: locale = `en`; `hud.csv` plural row populated
- **When**: `tr_n("hud.collection.count", "hud.collection.count", 0)` is called (or Godot 4.6's equivalent plural API)
- **Then**: returns `"no documents"`
- **Edge cases**: count = -1 (negative) → English plural rule typically falls to `_other`; test documents observed behavior, doesn't assume

**AC-3 — Count of 1 returns en_1 form**
- **Given**: same setup
- **When**: count = 1
- **Then**: returns `"1 document"`
- **Edge cases**: count = 1.0 (float) — Godot's plural function expects int; test verifies int path; float should be cast or rejected by API

**AC-4 — Count > 1 returns en_other form with {count} substitution**
- **Given**: same setup
- **When**: `tr_n(..., 7).format({"count": 7})` is called
- **Then**: returns `"7 documents collected"` (`{count}` replaced with `7`)
- **Edge cases**: count = 100 → `"100 documents collected"`; very large counts behave consistently

**AC-5 — Named placeholder substitution (non-plural)**
- **Given**: `hud.csv` has `hud.section.entered_label,Entering: {section_name},...`
- **When**: `tr("hud.section.entered_label").format({"section_name": "Plaza"})` is called
- **Then**: returns `"Entering: Plaza"`
- **Edge cases**: missing placeholder in dict (e.g., `format({"wrong_key": "X"})`) → Godot returns the original `{section_name}` unchanged; test verifies no crash + observable failure mode

**AC-6 — No positional substitution in production code**
- **Given**: all GDScript files under `src/`
- **When**: grep `tr(.*)\s*%\s*\[` (regex matches `tr(...) % [...]` pattern)
- **Then**: zero matches
- **Edge cases**: this story is largely greenfield (no prior `tr()` calls beyond Sprint 01's overlay work); the test passes trivially at story implementation time but BLOCKS future PRs that introduce the pattern

**AC-7 — Godot 4.6 plural API verification (smoke test)**
- **Given**: clean Godot 4.6.x test environment (CI runner or local dev)
- **When**: smoke test runs all four counts (0, 1, 2, 7) against `hud.collection.count`
- **Then**: returns 4 distinct strings: `"no documents"`, `"1 document"`, `"2 documents collected"` (`{count}=2`), `"7 documents collected"` (`{count}=7`)
- **Edge cases**: if Godot 4.6's plural API differs from documented (e.g., `tr_n` not present, or different signature), the test must produce a CLEAR diagnostic ("Godot 4.6 plural API mismatch — see ADR-0004 §Engine Compatibility verification gate; this story is BLOCKED pending alternative pluralization design") and the story is paused

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/localization_plural_forms_test.gd` — must exist and pass (covers all 7 ACs)
- Naming follows Foundation-layer convention
- Determinism: tests use fixed `count` values (0, 1, 2, 7); no random data; locale set to `en` deterministically in setup

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (base CSV registration; `hud.csv` must exist before adding plural rows to it)
- Unlocks: future consumer epics that need pluralized strings (e.g., HUD State Signaling for collection counts, Inventory for remaining-ammo strings); confirms Godot 4.6 plural API works for the project (closes ADR-0004 §Engine Compatibility plural verification at production scope)

---

## Completion Notes — 2026-05-03

**Status**: Complete. 8/8 plural-forms tests PASS; full LOC suite 29/29 PASS; zero regressions.

### Engine API Discovery (corrects GDD + ADR-0004)
The original story spec called for locale-suffixed plural columns (`en_0`, `en_1`, `en_other`). **This is incorrect** — the LLM hallucinated the format from search-snippet noise. The actual Godot 4.6 CSV plural-form convention (verified in `editor/import/resource_importer_csv_translation.cpp` + `docs.godotengine.org/en/4.6/tutorials/i18n/localization_using_spreadsheets.html`) uses:

1. A **`?plural` marker column** in the CSV header — holds the gettext-style msgid_plural value per key.
2. A special **`?pluralrule` directive row** (column-0 == `?pluralrule`) that declares the gettext plural function per locale (e.g. `nplurals=3; plural=(n==0 ? 0 : n==1 ? 1 : 2);` for English zero/one/other).
3. **Row repetition**: subsequent rows with empty msgid carry additional plural-form values in the locale column, indexed by the plural rule.

The importer recognizes only three special tokens in column headers/rows: `?context`, `?plural`, `?pluralrule`. Locale-suffixed columns like `en_0` / `en_zero` are silently treated as separate locales and the values are never reachable via `tr_n()`.

### Implementation
- **`translations/hud.csv`** restructured to header `keys,?plural,en,# context` with a `?pluralrule` directive row + 3 rows for `hud.collection.count` (key row + 2 continuation rows). Non-plural keys keep an empty `?plural` cell. The `# context` column is preserved for the project's existing comment convention; Godot 4.6 silently treats `# context` as a non-resolving locale (already true pre-Sprint 06).
- **`tests/unit/foundation/localization_plural_forms_test.gd`** rewritten to verify the `?plural` + `?pluralrule` + row-repetition format. Calls `tr_n("hud.collection.count", "1 document", N)` (msgid_plural is the value of the `?plural` cell, not the key).
- **`tests/unit/foundation/localization_runtime_test.gd`** — header check generalized to allow optional `?plural` column; existing nonempty-context + 3-segment-regex tests now skip `?`-prefixed directive rows and empty-key continuation rows.
- **`tests/unit/foundation/localization_pseudolocale_test.gd`** — `_collect_keys_from_csvs` skips `?`-prefixed directive rows + continuation rows.
- **`translations/_dev_pseudo.csv`** — added `hud.collection.count` and `hud.section.entered_label` rows (pseudo just uses the form-2 "other" template, per story spec).

### AC verification
- AC-1 ✅ `?plural` column + `?pluralrule` directive + populated cells + `# plural_rule` annotation
- AC-2 ✅ `tr_n(key, "1 document", 0)` → `"no documents"`
- AC-3 ✅ `tr_n(key, "1 document", 1)` → `"1 document"`
- AC-4 ✅ `tr_n(key, "1 document", 7).format({"count": 7})` → `"7 documents collected"`
- AC-5 ✅ `tr("hud.section.entered_label").format({"section_name": "Plaza"})` → `"Entering: Plaza"` + missing-key edge case
- AC-6 ✅ zero `tr(...) % [...]` matches in `src/`
- AC-7 ✅ smoke test verifies counts 0/1/2/7 all return correct distinct forms; closes ADR-0004 §Engine Compatibility plural verification gate

### Tech-debt logged (TD-008)
**TD-008 — GDD + ADR-0004 amendment for actual Godot 4.6 plural CSV format.**
- `design/gdd/localization-scaffold.md` §Detailed Design Rule 5 currently mis-documents the format as `en_0`/`en_1`/`en_other` columns. Should be amended to describe `?plural` marker + `?pluralrule` directive + row-repetition.
- `docs/architecture/adr-0004-ui-framework.md` §Engine Compatibility plural verification gate should be marked RESOLVED with a reference back to this Completion Notes section.
- Defer to next `/architecture-review` cycle (not blocking Sprint 06 progression).

### Files modified
- `translations/hud.csv` (restructured to Godot 4.6 plural format)
- `translations/_dev_pseudo.csv` (added 2 mirror rows)
- `tests/unit/foundation/localization_plural_forms_test.gd` (NEW — 8 tests)
- `tests/unit/foundation/localization_runtime_test.gd` (header check + `?`-row skip)
- `tests/unit/foundation/localization_pseudolocale_test.gd` (`?`-row skip in helper)
