# Story 002: Pseudolocalization CSV (_dev_pseudo.csv) + dev workflow + export filter

> **Epic**: Localization Scaffold
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 hours (M — pseudo CSV generator + export preset filter + smoke test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/localization-scaffold.md`
**Requirement**: TR-LOC-010 (Pseudolocalization CSV `res://translations/_dev_pseudo.csv`; ~140% length, bracket-wrapped, all-caps; excluded from exports)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry)
**ADR Decision Summary**: Pseudolocalization is a dev-build feature for stress-testing UI layout against ~140% string-length expansion BEFORE any second locale is authored. The pseudolocale CSV registers as a regular locale in Godot's `TranslationServer` but is excluded from production exports via the export-preset's resource filter. Per GDD §Detailed Design: "pseudolocalization CSV (`res://translations/_dev_pseudo.csv`, excluded from shipped builds via export filter). The pseudolocale substitutes each English string with a padded version (~140% of English length, bracket-wrapped, all-caps)".

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot's export system supports per-preset resource filters (`exclude_filter` in `export_presets.cfg`). `TranslationServer.set_locale()` works with any registered locale; pseudolocale uses a non-standard locale code (e.g., `_pseudo` or `qps-Latn` per CLDR pseudolocale convention) so it's distinct from real locales. Godot 4.5+ Translation Preview panel can activate the pseudolocale at editor time without modifying project settings.

**Control Manifest Rules (Foundation)**:
- Required: pseudolocalization CSV at `res://translations/_dev_pseudo.csv`; ~140% length factor; bracket-wrapped; all-caps (per GDD §Detailed Design)
- Required: pseudolocale excluded from shipped builds via export filter (per GDD §Detailed Design + Tuning Knobs)
- Required: pseudo content is REVERSIBLE (a developer can read past the bracketing/caps to verify intent)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria 14 + §Detailed Design + §Tuning Knobs:*

- [ ] **AC-1**: `res://translations/_dev_pseudo.csv` exists with header `keys,en,_pseudo,# context` (or equivalent — pseudolocale registered as a column alongside `en`).
- [ ] **AC-2**: For every key in every production CSV (overlay, hud, menu, settings, meta, dialogue, cutscenes, mission, credits, doc), `_dev_pseudo.csv` contains a corresponding pseudo translation. (Or alternatively: `_dev_pseudo.csv` IS its own CSV with `keys` + `_pseudo` columns and the per-domain CSVs gain a `_pseudo` column at MVP — choose the simpler approach: one consolidated `_dev_pseudo.csv` with all keys.)
- [ ] **AC-3**: Pseudo strings follow the GDD's substitution rules: ~140% length expansion (configurable per GDD §Tuning Knobs `Pseudolocalization length factor = 1.4 (×140%)`); bracket-wrapped (e.g., `[• ENGLISH PADDED ENGLISH ÉNGLÏSH •]`); all-caps; reversible (the original English is recognizable).
- [ ] **AC-4**: GIVEN the project is opened in Godot editor with `_dev_pseudo.csv` loaded, WHEN a developer activates the pseudolocale via Translation Preview panel (4.5+) OR via `TranslationServer.set_locale("_pseudo")` in a debug build, THEN UI Labels display the padded/bracketed/caps version. (AC-14 from GDD.)
- [ ] **AC-5**: GIVEN `export_presets.cfg`, WHEN exported builds are produced, THEN `_dev_pseudo.csv` AND `_dev_pseudo.# context.translation` AND `_dev_pseudo._pseudo.translation` are NOT in the exported PCK / output directory. Verifiable by exporting a debug or release build and grep-checking the output for `_dev_pseudo`.
- [ ] **AC-6**: GIVEN editor / debug builds, WHEN the project runs, THEN `TranslationServer.get_loaded_locales()` includes `_pseudo` (so dev tools and tests can switch to it). GIVEN exported release/debug builds, WHEN the build runs, THEN `_pseudo` is NOT in `get_loaded_locales()` (excluded by filter).
- [ ] **AC-7**: A pseudo-localized smoke test renders a known label (e.g., `tr("menu.main.start_mission")` → `[• STÄRT MÏSSIÖN START MISSION •]`) and asserts the result starts with `[`, ends with `]`, contains the original English visible, and is at least ~140% the length of the source.

---

## Implementation Notes

*Derived from GDD §Detailed Design "Godot 4.5 live-preview editor workflow" + §Tuning Knobs:*

**Approach choice: consolidated `_dev_pseudo.csv` vs per-domain `_pseudo` columns**:

The GDD describes "pseudolocalization CSV (`res://translations/_dev_pseudo.csv`)" suggesting a separate file. This is simpler at MVP because adding a `_pseudo` column to every per-domain CSV would force every translator/writer interaction to also touch pseudo content. The separate file approach: developer-owned, regenerable, doesn't pollute translator-facing CSVs.

**Recommended structure**: ONE consolidated CSV at `res://translations/_dev_pseudo.csv` with columns:

```csv
keys,en,_pseudo,# context
menu.main.start_mission,Start Mission,[• STÄRT MÏSSIÖN START MISSION SS •],"Pseudo-loc dev-only; ~140% length"
hud.health.label,Health,[• HÉALTH HEALTH H •],"Pseudo-loc dev-only; ~140% length"
...
```

The `keys` + `en` columns mirror the production CSVs (synthesized at story implementation time by reading all production CSVs); `_pseudo` is the dev-stress version. When TranslationServer loads this CSV, locale `_pseudo` becomes available alongside locale `en`.

**Pseudo string algorithm**:
- Insert 1 diacritic substitution per word (a→ä, e→é, i→ï, o→ö, u→ü) at a deterministic position (e.g., first vowel)
- Pad to ~140% length by repeating the first word: e.g., "Start Mission" (14 chars) → padded to ~20 chars: `START MISSION ST`
- Wrap in bracket markers: `[• ... •]`
- Uppercase the entire result

A small script (e.g., `tools/generate_pseudoloc.gd` or one-shot Python script) can synthesize `_dev_pseudo.csv` from the union of all production CSVs. At MVP, hand-authoring the file is also acceptable since key count is small (~10 stub keys + existing `overlay.csv` rows).

**Export preset filter** (`export_presets.cfg`):

```ini
[preset.0]   # Linux/X11
...
exclude_filter="*/_dev_pseudo.csv,*/_dev_pseudo.*.translation,*/_dev_pseudo.# context.translation"

[preset.1]   # Windows
...
exclude_filter="*/_dev_pseudo.csv,*/_dev_pseudo.*.translation,*/_dev_pseudo.# context.translation"
```

(Adjust per the project's actual export preset names — Linux + Windows per project Tech Preferences.)

**Locale code choice**: GDD doesn't pin the exact locale code; "_pseudo" is an internal convention that's clearly non-CLDR (regular locale codes are 2-letter or BCP 47). Alternative: `qps-Latn` (CLDR pseudolocale region code) — but `_pseudo` is more readable for devs. Choose `_pseudo` for clarity.

**Translation Preview panel workflow**: in Godot 4.5+ editor, Project → Tools → Translations → Translation Preview → select `_pseudo`. Live updates all `Control` nodes with `auto_translate_mode = ALWAYS` (Story 004's discipline).

**Why this is dev-only and excluded from exports**: `_dev_pseudo.csv` is a layout stress-test tool. Shipping it in a release build would (a) bloat the PCK by ~20 KB, (b) expose an internal dev locale to players, (c) potentially confuse end-users if a debug menu accidentally exposes it. Export filter is the canonical Godot way to exclude per-preset.

**Re-generation hygiene**: when production CSVs gain new keys (every dev iteration that adds UI strings), `_dev_pseudo.csv` should be regenerated to stay in sync. At MVP, this is manual (one-shot regeneration after major UI work). Post-MVP: a `/localize` skill subcommand could automate it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: production CSV registration (already done; this story consumes the CSV list to generate pseudo entries)
- Story 003: plural form support (pseudolocale does NOT need plural columns — pseudo is dev-only)
- Story 004: `auto_translate_mode` discipline (orthogonal — pseudolocale activates at TranslationServer level, individual nodes still need their auto-translate or notification handling)
- Story 005: lint guards (pseudolocale itself is not subject to `hardcoded_visible_string` checks; lint targets `src/` not `translations/`)
- Translator-facing locale CSVs (fr, de, es, etc.) — post-MVP content delivery, not this story's scope

---

## QA Test Cases

**AC-1 — _dev_pseudo.csv exists with valid header**
- **Given**: file system after this story
- **When**: a test reads `res://translations/_dev_pseudo.csv`
- **Then**: file exists; first line is `keys,en,_pseudo,# context` (or equivalent valid header with at least `keys`, `en`, and a pseudo-locale column); subsequent rows are non-empty
- **Edge cases**: header with extra columns (e.g., a future translator adds `fr` to `_dev_pseudo.csv` by accident) — fail with clear message, this CSV is dev-only

**AC-2 — Every production key has a pseudo entry**
- **Given**: production CSVs (10 domains from Story 001) and `_dev_pseudo.csv`
- **When**: a test enumerates all production keys and looks each up in `_dev_pseudo.csv`'s `keys` column
- **Then**: every production key has a corresponding row in `_dev_pseudo.csv`; missing keys are listed with their domain CSV
- **Edge cases**: production CSV gains a new key after `_dev_pseudo.csv` was last regenerated → test fails with the missing keys; CI catches drift

**AC-3 — Pseudo strings match length / format rules**
- **Given**: each row in `_dev_pseudo.csv`
- **When**: a test inspects the `_pseudo` cell
- **Then**: starts with `[` and ends with `]` (bracket markers); length is ≥1.2× the `en` cell length and ≤1.8× (per Tuning Knobs safe range); contains the English source as a recognizable substring (with optional diacritic substitutions); is uppercase (no lowercase letters in non-bracket regions)
- **Edge cases**: very short English (e.g., "OK" → "[ÖK]") — length factor relaxed for short strings; tests verify the bracketing without forcing 1.4× on 2-char inputs

**AC-4 — Pseudolocale activates at runtime**
- **Given**: editor or debug build with `_dev_pseudo.csv` loaded
- **When**: a test calls `TranslationServer.set_locale("_pseudo")` then `tr("menu.main.start_mission")`
- **Then**: returns the pseudo string (starts with `[•`, etc.); does NOT return the English value; `TranslationServer.get_locale() == "_pseudo"`
- **Edge cases**: locale switch leaves residual cached state — Story 004's discipline handles re-render; this AC just verifies tr() resolves correctly

**AC-5 — Export excludes _dev_pseudo files**
- **Given**: `export_presets.cfg` with the `exclude_filter` populated; a debug build is exported to a known output directory
- **When**: the export completes
- **Then**: the output PCK / dir does NOT contain `_dev_pseudo.csv`, `_dev_pseudo.*.translation`, or any artifact with `_dev_pseudo` in its name
- **Edge cases**: smoke test for this AC is hard to fully automate in CI without running the export pipeline; at MVP, manual verification is acceptable + a documentation row in `production/qa/evidence/` confirming "verified on YYYY-MM-DD by running export-debug locally and inspecting the output"

**AC-6 — Locale availability differs between editor and exports**
- **Given**: editor / debug build
- **When**: `TranslationServer.get_loaded_locales()` is queried
- **Then**: returns array containing `_pseudo`
- **Given**: production export (release build, `_dev_pseudo` excluded by filter)
- **When**: `TranslationServer.get_loaded_locales()` is queried at runtime
- **Then**: returns array NOT containing `_pseudo`
- **Edge cases**: this AC requires testing in both contexts; release-build verification can be deferred to first export pass and tracked as an evidence doc

**AC-7 — Smoke test for known pseudo string**
- **Given**: editor mode with `_pseudo` locale active; `menu.csv` contains `menu.main.start_mission` with English `"Start Mission"`
- **When**: `tr("menu.main.start_mission")` is called
- **Then**: result starts with `[`; ends with `]`; length ≥ 1.2× `len("Start Mission")` (= 17); the substring `"START MISSION"` (or with diacritic variants) appears within the brackets
- **Edge cases**: the exact pseudo content is regenerable; test asserts STRUCTURAL properties not exact byte-content (which would break on diacritic algorithm changes)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/localization_pseudolocale_test.gd` — must exist and pass (covers AC-1 through AC-4, AC-6 in editor/debug context, AC-7)
- `production/qa/evidence/localization_export_filter_evidence.md` — manual export verification for AC-5 (run export-debug locally, confirm `_dev_pseudo` absence in output, log date + git SHA + builder)
- Naming follows Foundation-layer convention

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (production CSVs must exist for pseudo to mirror; `[internationalization]` block must be valid)
- Unlocks: dev workflow for UI development — pseudolocale is the layout stress-test mechanism every UI epic uses (HUD, Menu, Document Overlay, Settings)
