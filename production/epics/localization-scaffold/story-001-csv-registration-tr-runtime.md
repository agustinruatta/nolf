# Story 001: CSV registration + base tr() runtime + project.godot localization config

> **Epic**: Localization Scaffold
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — project.godot edits + CSV stubs + smoke test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/localization-scaffold.md`
**Requirement**: TR-LOC-002 (key naming `domain.context.identifier`), TR-LOC-003 (one CSV per domain at `res://translations/[domain].csv`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry)
**ADR Decision Summary**: ADR-0004 mandates `tr()` wrap for every visible string from day one and locks domain-prefixed dot-notation keys with one CSV per domain under `res://translations/`. Godot's `TranslationServer` loads CSVs registered in `project.godot [internationalization]` and falls back to the base locale when a key is missing for the active locale.

**ADR Status note**: ADR-0004 is `Proposed` overall pending Gate 5 (BBCode → AccessKit plain-text serialization, runtime AT testing). Gates 1–4 are CLOSED including G4 (`auto_translate_mode` enum identifiers). Localization-relevant scope is fully verified — per Localization-Scaffold EPIC: "Localization stories may proceed against ADR-0004's Localization clauses without G5 closure." This story proceeds under that authorization.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `TranslationServer` + CSV importer stable since Godot 4.0. CSV import generates per-locale `.translation` artifacts (e.g., `overlay.en.translation`, `overlay.# context.translation`). Sprint 01 verified end-to-end on `overlay.csv` (Document Overlay UX work, 2026-04-29). The mechanism is proven; this story extends it to the other domain CSVs.

**Control Manifest Rules (Foundation)**:
- Required: every user-visible string wrapped in `tr("key")` (forbidden pattern `hardcoded_visible_string` enforced by lint — formal registration in Story 005)
- Required: keys follow `domain.context.identifier` minimum 3-segment pattern (TR-LOC-002)
- Required: each CSV row has non-empty `# context` cell (forbidden pattern `context_column_omitted`)
- Forbidden: `tr("English Sentence")` — keys are NEVER English sentences (forbidden pattern `key_in_code_as_english`)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + §Detailed Design Rules 2 + 3:*

- [ ] **AC-1**: `project.godot` `[internationalization]` block lists all production-domain CSV files: `translations/overlay.csv` (already present), plus stubs for `hud.csv`, `menu.csv`, `settings.csv`, `meta.csv`, `dialogue.csv`, `cutscenes.csv`, `mission.csv`, `credits.csv`, `doc.csv`. Locales loaded list contains at least `["en"]`; `locale/fallback = "en"`.
- [ ] **AC-2**: Each domain CSV exists at `res://translations/[domain].csv` with header row `keys,en,# context` and at least one example key per CSV (e.g., `menu.main.start_mission` in `menu.csv`). Stubs are non-empty so Godot's CSV importer doesn't error on import.
- [ ] **AC-3**: GIVEN a known key `menu.main.start_mission` with English value `"Start Mission"`, WHEN GDScript calls `tr("menu.main.start_mission")`, THEN it returns `"Start Mission"`. (AC-6 from GDD.)
- [ ] **AC-4**: GIVEN a key that does not exist in any CSV, WHEN `tr("nonexistent.key.name")` is called, THEN it returns `"nonexistent.key.name"` verbatim (Godot fallback — intended failure mode per GDD Edge Cases). (AC-7 from GDD.)
- [ ] **AC-5**: GIVEN locale `fr` is set but a key `menu.main.start_mission` exists only in `en`, WHEN `tr("menu.main.start_mission")` is called, THEN the English value is returned (fallback to base locale per `locale/fallback` setting). (AC-8 from GDD.)
- [ ] **AC-6**: Every CSV row's `# context` cell is non-empty (per Rule 3). At MVP each stub CSV has at least one row with a meaningful `# context` annotation (location, character limit, tonal note where relevant).
- [ ] **AC-7**: All keys across all CSVs follow the `domain.context.identifier` 3-segment minimum (lowercase, snake_case, dot-separated). Verified by a parse-time test that asserts each key matches the regex `^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$`.
- [ ] **AC-8**: GIVEN the existing `overlay.csv` from Sprint 01, WHEN this story's `project.godot` edits land, THEN existing `overlay.*` keys still resolve correctly (no regression on Document Overlay UX work).

---

## Implementation Notes

*Derived from GDD §Detailed Design Rules 2 + 3 + §Interactions table:*

**`project.godot` `[internationalization]` section**:

```
[internationalization]

locale/translations=PackedStringArray("res://translations/overlay.en.translation", "res://translations/hud.en.translation", "res://translations/menu.en.translation", "res://translations/settings.en.translation", "res://translations/meta.en.translation", "res://translations/dialogue.en.translation", "res://translations/cutscenes.en.translation", "res://translations/mission.en.translation", "res://translations/credits.en.translation", "res://translations/doc.en.translation")
locale/fallback="en"
```

(Note: Godot generates `.translation` artifacts from `.csv` source files on import. The `[internationalization]` section references the generated artifacts, not the CSV directly. This is Godot's standard pattern.)

**Per-domain CSV stubs** — minimal viable files with one example key each:

`translations/menu.csv`:
```csv
keys,en,# context
menu.main.start_mission,Start Mission,"Main menu primary CTA; max 25 chars; positive forward verb"
```

`translations/hud.csv`:
```csv
keys,en,# context
hud.health.label,Health,"HUD health bar label; max 12 chars"
```

(And one row per other domain: `settings.csv`, `meta.csv`, `dialogue.csv`, `cutscenes.csv`, `mission.csv`, `credits.csv`, `doc.csv`.)

**Existing overlay.csv** — already present (verified by `ls translations/`); this story does NOT modify it. The `[internationalization]` block must include the existing `overlay.en.translation` artifact alongside the new stubs.

**Smoke test** (`tests/unit/foundation/localization_runtime_test.gd`):
- Asserts `tr("menu.main.start_mission")` returns `"Start Mission"` at default locale
- Asserts `tr("nonexistent.fake.key")` returns `"nonexistent.fake.key"`
- Asserts `TranslationServer.get_loaded_locales()` contains `"en"`
- Asserts every key in every CSV under `res://translations/` matches the 3-segment regex

**Domain enumeration**: 10 production domains per GDD §Interactions table (overlay, hud, menu, settings, meta, dialogue, cutscenes, mission, credits, doc). Pseudo-locale (`_dev_pseudo.csv`) is Story 002's scope, NOT this story.

**No autoload** (per epic): Localization is a CONVENTION + project settings, not a runtime module. No `LocalizationService` autoload — `tr()` is built into Godot's `Object` base class.

**Locale persistence** (TR-LOC-009, AC-11/12): persists in `user://settings.cfg` `[localization] locale` field — owned by **Settings & Accessibility epic**, NOT this story. This story sets `locale/fallback = "en"` in project.godot but does NOT implement runtime locale switching.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: pseudolocalization (`_dev_pseudo.csv`) + export filter
- Story 003: plural form support (CSV plural columns)
- Story 004: `auto_translate_mode = ALWAYS` + `NOTIFICATION_TRANSLATION_CHANGED` discipline
- Story 005: anti-pattern fences + lint guards (`hardcoded_visible_string` etc.)
- Locale switching UI + persistence to `user://settings.cfg` → Settings & Accessibility epic
- Translation content beyond stub examples — owned by `/localize` skill content pipeline + writer/translator
- Document Collection's `doc.*` body content — owned by Document Collection epic

---

## QA Test Cases

**AC-1 — project.godot internationalization block**
- **Given**: `project.godot` after this story's edits land
- **When**: a unit test reads the file and parses the `[internationalization]` section
- **Then**: `locale/translations` PackedStringArray contains all 10 domain translation artifacts (overlay, hud, menu, settings, meta, dialogue, cutscenes, mission, credits, doc); `locale/fallback == "en"`
- **Edge cases**: Godot's editor reorders entries on save → fixed order is maintained because the array is alphabetical or insertion-order; test accepts either as long as all 10 are present

**AC-2 — Domain CSV files exist with valid headers**
- **Given**: file system after this story
- **When**: a test enumerates `res://translations/*.csv`
- **Then**: 10 CSV files exist (overlay.csv, hud.csv, menu.csv, settings.csv, meta.csv, dialogue.csv, cutscenes.csv, mission.csv, credits.csv, doc.csv); each has the header row `keys,en,# context`; each has at least one data row
- **Edge cases**: existing `overlay.csv` already has multiple rows (from Sprint 01) — test asserts header AND existence of at least one row, not exact row count

**AC-3 — Known key resolves to English value**
- **Given**: `menu.csv` contains row `menu.main.start_mission,Start Mission,"..."`; project loaded with default locale `en`
- **When**: a test calls `tr("menu.main.start_mission")`
- **Then**: returns `"Start Mission"`
- **Edge cases**: leading/trailing whitespace in CSV cell — Godot trims; test should not depend on whitespace fragility

**AC-4 — Missing key returns key verbatim**
- **Given**: no CSV contains `nonexistent.fake.key`
- **When**: a test calls `tr("nonexistent.fake.key")`
- **Then**: returns the literal string `"nonexistent.fake.key"`
- **Edge cases**: keys that look like real ones but with one segment misspelled → also fall back; the test demonstrates the intended "loud and obvious" failure mode

**AC-5 — Fallback to base locale on missing translation**
- **Given**: `menu.main.start_mission` exists in `en` but not in `fr`; `TranslationServer.set_locale("fr")` is called (no `fr` CSV column exists yet — Godot loads what's available)
- **When**: `tr("menu.main.start_mission")` is called
- **Then**: returns `"Start Mission"` (the English value from the fallback locale)
- **Edge cases**: at MVP only `en` is loaded; this AC validates the fallback CONFIGURATION (`locale/fallback = "en"`) not actual `fr` resolution. Test simulates by setting locale to a non-loaded value and verifying fallback still hits `en`.

**AC-6 — Every CSV row has non-empty `# context`**
- **Given**: all 10 CSV files from AC-2
- **When**: a test parses each CSV and inspects every data row
- **Then**: `# context` column is non-empty for every row (length > 0; whitespace-only does NOT count as filled)
- **Edge cases**: existing `overlay.csv` rows must already comply (they were authored during Sprint 01 UX work); fail this AC if any pre-existing rows have empty context

**AC-7 — All keys match 3-segment regex**
- **Given**: all keys across all CSVs
- **When**: a test extracts each `keys` cell and applies regex `^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$`
- **Then**: every key matches; failures list specific keys with line numbers
- **Edge cases**: keys with 4+ segments allowed (e.g., `dialogue.guard.patrol.line_03`); 2-segment keys (e.g., `menu.start`) FAIL — minimum is 3

**AC-8 — Existing overlay.csv resolution preserved**
- **Given**: pre-Sprint-01 `overlay.csv` contains existing keys (e.g., `overlay.dismiss_hint`)
- **When**: after this story's edits, `tr("overlay.<existing_key>")` is called
- **Then**: returns the same English value as before this story's changes (no regression)
- **Edge cases**: Godot's import re-runs may regenerate `.translation` artifacts — the `.csv` source is the authority; tests resolve against the live `tr()` call, not the artifact

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/localization_runtime_test.gd` — must exist and pass (covers all 8 ACs)
- Naming follows Foundation-layer convention
- Determinism: tests do NOT modify `TranslationServer.set_locale` globally (saves and restores in setup/teardown to avoid cross-test pollution)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (existing `overlay.csv` from Sprint 01 satisfies the precondition that the CSV importer + `tr()` mechanism is verified)
- Unlocks: Story 002 (pseudo CSV joins the `[internationalization]` list), Story 003 (plural keys go in domain CSVs), Story 004 (`auto_translate_mode` reads from these CSVs), Story 005 (lint scans these CSVs)
