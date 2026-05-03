# Localization Scaffold

> **Status**: In Design
> **Author**: User + `/design-system` skill + localization-lead
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Foundation infrastructure — enables post-launch localization without project-wide refactor; enforces `tr()` discipline per ADR-0004

## Summary

Localization Scaffold is the string-table architecture and `tr()` discipline that lets *The Paris Affair* ship with English at MVP but support additional locales post-launch as a **content-only** delivery — no engineering refactor, no string-hunting expedition. Every visible string in the codebase routes through a translation key; the key maps to a CSV translation table loaded at startup. ADR-0004 locks `tr()` usage from day one via the forbidden pattern `hardcoded_visible_string`.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Effort: `S` · Key deps: `None (engine only)` · Enforced by: ADR-0004 forbidden_pattern `hardcoded_visible_string`

## Overview

Localization Scaffold is a Foundation-layer system with no balance values, no player interaction, and no shipping content at MVP beyond the single English translation table. Its purpose is entirely preventive: it stops *The Paris Affair* from accumulating hundreds of hardcoded strings in source files that would require a project-wide refactor to localize later. The scaffold has three parts:

1. **A translation key naming convention** that every system follows when introducing user-visible text.
2. **A CSV translation table** (`res://translations/en.csv` at MVP; locale files added per supported locale post-launch) loaded by Godot's `TranslationServer` at startup.
3. **The `tr()` function discipline** mandated by ADR-0004 — every user-visible string in GDScript goes through `tr("key")`, never `"hardcoded english"`.

At MVP, the scaffold ships with English keys only. Adding a second locale (French, Spanish, etc.) post-launch is a translator deliverable, not an engineering task: a new CSV column is added, the translator fills it in, and the game is set to load that locale. Godot 4.5+ provides a live translation preview in the editor, which the team uses for sanity-checking layout fit during UI development even before a second locale is authored. Godot 4.6's CSV plural form support (no Gettext required) covers the few plural cases the game has (e.g., *"1 document collected"* / *"7 documents collected"*) without a heavier toolchain.

**The scaffold does NOT include**: a player-facing locale-switcher UI (that's Settings & Accessibility's job once a second locale exists), voice-over localization (separate asset production), or translation content itself (writer + translator work, governed by the `/localize` skill at the appropriate phase).

## Player Fantasy

Localization Scaffold is judged by what *never ships* in a localized release. At MVP, it is invisible — English-only players experience nothing different. Its value is realized later, when a French or Spanish edition of *The Paris Affair* ships as a translator's deliverable, not an engineer's refactor. The failures the scaffold refuses:

- **English never leaks.** No *"Press E to interact"* hardcoded in a tutorial script that a 2027 French build ships with untranslated. Every visible string is keyed from Day 1.
- **Layout never breaks on long words.** German *"Dokumentensammlung"* does not overflow the collection HUD or clip the document title bar. Layout is stress-tested via Godot's live translation preview during MVP development, not discovered post-launch.
- **Plurals never read awkwardly.** Never *"1 documents collected"* — plural rules are driven by CSV plural-form columns, not string concatenation.
- **Period authenticity survives translation.** (Pillar 5) BQA dossier tone, PHANTOM's theatrical menace, and the dry civil-service comedy remain intact in a translator's hands because keys are documented with tonal context, not stripped of it.
- **Locale switch never requires a rebuild.** A post-launch translator delivers a CSV column; a player toggles a locale in Settings. No engineering sprint.

Players will never praise the Scaffold. They will praise *The Paris Affair* feeling **like it was written in their language** — because it was, and the pipeline to make that true was laid before the first string shipped.

## Detailed Design

### Core Rules

1. **Every user-visible string goes through `tr()`, no exceptions.** Any string a player can read — labels, HUD values, menu items, document titles, subtitle lines, error dialogs, tooltips, accessibility descriptions — must be wrapped in `tr("key")`. Hardcoded English literals in GDScript are forbidden. ADR-0004 registers `hardcoded_visible_string` as a forbidden pattern enforced in code review and by the `/localize` scan skill.

2. **Translation key naming: domain-prefixed dot-notation.** Keys follow a three-segment minimum: `domain.context.identifier`.

   | Segment | Purpose | Example values |
   |---|---|---|
   | Domain | Top-level system | `ui`, `hud`, `doc`, `menu`, `dialogue`, `settings`, `credits` |
   | Context | Sub-feature or screen | `menu.main`, `hud.ammo`, `doc.phantom_memo_01`, `dialogue.guard.patrol` |
   | Identifier | Specific string | `title`, `label`, `action_start`, `line_01` |

   Examples: `menu.main.start_mission`, `hud.ammo.label`, `doc.phantom_memo_01.title`, `dialogue.guard.patrol.line_03`, `settings.audio.volume_label`. Keys are lowercase, snake_case segments, dot-separated. No spaces, no camelCase, no numeric-only segments. Keys are NEVER English sentences (no `tr("Start Mission")`).

3. **CSV file layout and location.** One CSV per domain area at `res://translations/[domain].csv`. Godot's `TranslationServer` loads all CSV files listed in Project Settings → Localization. Column order:

   | Column | Purpose |
   |---|---|
   | `keys` | Translation key (e.g. `menu.main.start_mission`) |
   | `en` | English source string |
   | `# context` | Developer note column (Godot ignores columns starting with `#`) — must include: where the string appears, character limit if constrained, variables used, and tonal notes where BQA/PHANTOM voice is load-bearing (e.g., *"BQA civil-service understatement; do not punch up the comedy"*) |

4. **Dynamic strings use named placeholders, never positional.** Parameterized strings substitute via GDScript's `%` operator or `String.format()` applied to `tr()`. Named placeholders (`{count}`) are mandatory; positional (`%s`) is forbidden because word order differs between languages.

   ```
   # translations/hud.csv row:
   hud.collection.count | "{count} document{plural} collected" | count = int; plural = "" or "s"; max 35 chars
   ```
   ```gdscript
   var text = tr("hud.collection.count") % {"count": n, "plural": "" if n == 1 else "s"}
   ```

5. **Plural forms use Godot 4.6 CSV plural marker + directive row format** (verified 2026-05-03 LOC-003 against `editor/import/resource_importer_csv_translation.cpp`). The CSV header gains a `?plural` marker column; one `?pluralrule` directive row per locale specifies the locale's plural-rule expression; each plural key is encoded as N consecutive rows (one per plural form, distinguished by `?plural` value 0/1/2/...). Per-locale plural-form count varies (English = 2, Polish = 4). MVP applies only to a small set (document count, item count). Reference implementation: `translations/hud.csv` (`hud.collection.count`). See LOC-003 Completion Notes for the worked example. *(Note: prior text described `en_0`/`en_1`/`en_other` locale-suffixed columns — that was a hallucinated format that does not exist in Godot 4.6's importer.)*

6. **Developer workflow for adding a new user-visible string:**
   1. Choose the domain CSV for the string's feature area.
   2. Add a row: key in `keys`, English in `en`, tonal/contextual note in `# context`.
   3. Use `tr("the.key")` at the call site.
   4. If parameterized, use named placeholders and document variables in context.
   5. Run the project. If `tr()` returns the key verbatim, the key is missing/typoed.

7. **Translator workflow for adding a new locale (post-launch):**
   1. Translator receives all CSVs with `keys`, `en`, `# context` columns.
   2. Translator adds a new column (`fr`, `de`, `ja`, etc.) and fills in translations, respecting character limits and tonal notes.
   3. Developer adds the new locale to Project Settings → Localization and sets the column header as the locale identifier.
   4. `TranslationServer` handles the rest at runtime. No new code.

8. **LTR-only at MVP, but NO hardcoded LTR layout assumptions.** No Arabic/Hebrew support at MVP. However, UI code may not bake left-to-right layout in ways that would require surgery to fix. Use `Control.layout_direction` on container roots rather than hard anchors where RTL mirroring would be needed. RTL is an explicit post-launch scope call when/if Arabic/Hebrew locales are prioritized.

9. **Anti-pattern fences** (registered in `architecture.yaml`):

   | Pattern | Example of violation |
   |---|---|
   | `hardcoded_visible_string` (ADR-0004) | `label.text = "Start Mission"` |
   | `key_in_code_as_english` | `tr("Start Mission")` — English as the key |
   | `positional_format_substitution` | `tr("...") % [n]` when word-reorder is possible |
   | `context_column_omitted` | A CSV row with an empty `# context` cell |
   | `cached_translation_at_ready` | `var start_label = tr("menu.main.start_mission")` stored in `_ready()` without re-resolve on locale change |

10. **Key source-of-truth: manual CSV + `/localize` audit.** At MVP, developers maintain CSV files manually. The `/localize` skill scans for drift (orphan keys in CSVs, `tr()` calls with missing keys, `hardcoded_visible_string` violations). Build-time extraction is NOT used at MVP — revisit if locale count exceeds three post-launch.

### States and Transitions

Localization state is a single scalar: **the active locale** held by `TranslationServer`. At MVP there is only one locale (`en`); the state machine is trivial but must support the post-launch case.

| State | Description |
|---|---|
| `LOCALE_ACTIVE(locale_id)` | `TranslationServer` has a loaded translation for `locale_id`. All `tr()` calls resolve against it. |
| `LOCALE_FALLBACK` | Requested locale has no entry for a key; `TranslationServer` falls back to the base locale (`en`). Player never sees a raw key. |

**Locale switch transition (post-launch):**

1. Player selects new locale in Settings & Accessibility.
2. Settings calls `TranslationServer.set_locale(locale_id)`.
3. Godot emits `NOTIFICATION_TRANSLATION_CHANGED` to all nodes in scene tree.
4. Any `Control` node with `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` (Godot 4.5+) re-renders automatically.
5. GDScript nodes that cached `tr()` results in `_ready()` must re-read on `NOTIFICATION_TRANSLATION_CHANGED` — this is what Rule 9's `cached_translation_at_ready` forbids.

**Re-render rule.** HUD values that update via `Events` signals already re-resolve per event — no extra work. Static labels (menu titles, settings labels) MUST either use Godot's `auto_translate_mode` or implement `_notification()` to re-resolve. No string resolved in `_ready()` may be treated as final.

### Interactions with Other Systems

#### String ownership by domain

| System | CSV file | Key prefix | Fetch pattern |
|---|---|---|---|
| HUD Core | `translations/hud.csv` | `hud.*` | Resolve on Events signal; no caching |
| Document Overlay UI | `translations/doc.csv` | `doc.*` | Resolve at document open; one-shot |
| Menu System | `translations/menu.csv` | `menu.*` | `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` on Label nodes |
| Settings & Accessibility | `translations/settings.csv` | `settings.*` | `auto_translate_mode` or `_notification()` |
| Dialogue & Subtitles | `translations/dialogue.csv` | `dialogue.*` | Resolve at line delivery time |
| Cutscenes & Mission Cards | `translations/cutscenes.csv` | `cutscenes.*` | One-shot at scene trigger |
| Save / Load (slot metadata) | `translations/meta.csv` | `meta.*` | Resolve at menu-render time (not at save creation) |
| Credits | `translations/credits.csv` | `credits.*` | One-shot at scene load |

#### Settings & Accessibility locale switcher integration

Settings & Accessibility (system 23) owns the locale-picker UI. It calls `TranslationServer.set_locale()` directly AND emits `Events.setting_changed("settings", "locale", locale_id)` so other systems can react if needed (e.g., Dialogue system might preload VO for the new locale if VO is localized). Locale preference persists in `user://settings.cfg` per ADR-0003 settings separation.

#### Godot 4.5 live-preview editor workflow

During UI development, the team uses Godot's Translation Preview panel (4.5+) with a **pseudolocalization** CSV entry (`res://translations/_dev_pseudo.csv`, excluded from shipped builds via export filter). The pseudolocale substitutes each English string with a padded version (~140% of English length, bracket-wrapped, all-caps) to stress-test overflow, clipping, and truncation in HUD elements (ammo count, document title bar, menu button labels) BEFORE any second locale is authored.

#### `/localize` skill integration (post-launch content pipeline)

The `/localize` skill (used at post-launch content-delivery phase) audits all GDScript files for `hardcoded_visible_string` violations, diffs current CSV keys against a baseline to identify new strings needing translation, and produces a translator-ready export package: CSV files + screenshot references + character limits extracted from context columns. It does NOT write translations — it prepares the package and hands it to the translator.

## Formulas

**None.** Localization Scaffold is pure infrastructure with no balance values, no calculations. The one quasi-formula — plural form selection — is delegated entirely to Godot 4.6's built-in CSV plural format; this GDD inherits that engine behavior and does not redefine it. Character-limit budgets for specific UI elements (e.g., HUD ammo label max 35 chars) live in each consuming system's GDD and the CSV `# context` column, not here.

## Edge Cases

- **If `tr("some.key")` is called but the key doesn't exist in any CSV** → Godot returns the key string verbatim (e.g., `"menu.main.start_mission"` appears on screen). **Resolution**: intended failure mode. Loud and obvious — a developer sees the key in-game and knows the row is missing. The `/localize` skill flags all such cases in audit.
- **If a CSV row has an English value but no entry for the active locale** → `TranslationServer` falls back to English. Player sees English inside a French/German/etc. build. **Resolution**: intended. Better to show English than a raw key. `/localize` audit reports untranslated keys per locale so the translator can complete them before re-ship.
- **If a translation is longer than its container allows** (e.g., German text overflows the HUD ammo label) → Godot clips based on `Label.clip_contents` or the container's `CLIP_CONTENTS` rule. **Resolution**: prevented during development via pseudolocalization stress-test. If an overflow ships, it's caught by `/localize` audit (character-limit check against CSV context column) and reported to the translator.
- **If a developer adds `tr("Start Mission")`** (English sentence as key) → `TranslationServer` treats that English string as the key. The `/localize` audit flags this as a `key_in_code_as_english` violation. **Resolution**: code-review checkpoint; audit fail blocks merge.
- **If a developer stores `tr()` result in a `var` at `_ready()` and locale switches mid-session** → the cached string remains in English while the rest of the UI becomes French. **Resolution**: `/localize` audit flags `cached_translation_at_ready` pattern (grep for `var.*= tr\(` in `_ready()` function bodies). Developers must either use `auto_translate_mode` or re-resolve in `_notification(NOTIFICATION_TRANSLATION_CHANGED)`.
- **If `TranslationServer.set_locale()` is called with a locale that has no loaded CSV** → `TranslationServer` silently keeps the previous locale. No error, no log. **Resolution**: Settings & Accessibility's locale picker MUST only offer locales for which `TranslationServer.get_loaded_locales()` returns an entry. Hardcoded fallback list is forbidden.
- **If a CSV row has a `# context` column that's empty** → Godot parses fine; translator has no context for the string. Translation quality drops or errors slip in. **Resolution**: `/localize` audit flags empty context cells as `context_column_omitted` violations. Authors MUST fill it.
- **If two CSVs define the same key** (naming collision across domain files) → `TranslationServer` behavior is undefined (last-loaded wins, but not guaranteed). **Resolution**: domain-prefixed naming (Rule 2) makes collisions structurally impossible IF the convention is followed. `/localize` audit scans for duplicate keys across all CSVs regardless.
- **If a plural form rule differs between languages** (e.g., English has singular/plural; Polish has singular/few/many/other) → Godot 4.6 CSV plural columns handle this per-locale. **Resolution**: intended. Translator adds `pl_0`, `pl_1`, `pl_2`, `pl_3` columns for Polish where needed; English only populates `en_0`, `en_1`.
- **If a locale CSV adds a key that English doesn't have** (e.g., translator adds rows for locale-specific content like translator credits) → `tr()` returns the locale-specific string; English falls back to the key (not present). **Resolution**: this is architecturally possible but a bad pattern. Audit flags any key absent from English. English is the authoritative key set.
- **If the game is launched with a locale the OS doesn't support** → Godot's `OS.get_locale()` returns something; Settings' picker only offers loaded locales; default is `en`. **Resolution**: never a real issue — the loaded-locales-only filter handles it.

## Dependencies

### Upstream dependencies

| System | Nature |
|---|---|
| Godot 4.6 `TranslationServer` + CSV importer | Hard engine dependency. Stable since 4.0; 4.6 adds CSV plural form support (no Gettext required). |
| Godot 4.5 `Control.auto_translate_mode` property | Soft dependency — enables automatic re-render on locale change. MVP requires 4.5+; project is pinned to 4.6. |

### Downstream dependents

| System | Nature |
|---|---|
| **HUD Core** (system 16) | Consumes `hud.*` keys. All labels go through `tr()`. |
| **HUD State Signaling** (19) | Consumes `hud.alert.*`, `hud.pickup.*` keys. |
| **Document Collection** (17) | Consumes `doc.*` keys — document titles, body text (when documents are authored). |
| **Document Overlay UI** (20) | Consumes `doc.header.*`, overlay UI labels. |
| **Menu System** (21) | Consumes `menu.*` keys — all button labels, screen titles. |
| **Settings & Accessibility** (23) | Consumes `settings.*` keys AND owns the locale-picker UI that calls `TranslationServer.set_locale()`. |
| **Dialogue & Subtitles** (18) | Consumes `dialogue.*` keys — subtitle lines, speaker names. |
| **Cutscenes & Mission Cards** (22) | Consumes `cutscenes.*` keys. |
| **Save / Load** (6) | Consumes `meta.*` keys for save-slot metadata display (section name localized on slot card). |
| **Mission & Level Scripting** (13) | Consumes `mission.*` keys — objective titles, mission briefing text. |

### No direct interaction

- **ADR-0001 (Stencil)**: independent.
- **ADR-0002 (Signal Bus)**: Localization does not publish to the bus. `setting_changed("settings", "locale", id)` is published by Settings (not Localization) when the locale picker changes.
- **Audio (system 3)**: VO localization is separate content production (future scope). At MVP, VO is English-only. When localized, VO files are named `vo_[speaker]_[line_id]_[locale].ogg` — Audio's asset naming handles locale variance without involving this scaffold.
- **Signal Bus (system 1)**: Localization does not publish events. It is a query-on-demand service via `tr()`.

## Tuning Knobs

### Project Settings → Localization

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| Loaded locales list | `["en"]` at MVP | 1–N strings | Each entry is a CSV column name / locale code |
| Fallback locale | `"en"` | Must be a loaded locale | Used when a key is missing in the active locale |
| Active locale (runtime) | `OS.get_locale()` substring match at startup, else `"en"` | Must be loaded | Persisted in `user://settings.cfg` when player changes it |

### CSV authoring conventions (designer-adjustable)

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| Max chars per HUD label (e.g., `hud.ammo.label`) | 35 | 20–60 | Per-element; documented in each CSV `# context` cell |
| Max chars per menu button | 25 | 15–40 | Menu buttons are tight; pseudolocalization catches overflow |
| Max chars per document title bar | 40 | 25–60 | Document Overlay card is wider; more budget |
| Pseudolocalization length factor | 1.4 (×140%) | 1.2–1.8 | Dev-build pseudolocale padding for overflow stress-test |

### NOT owned by this GDD

- Specific translation content → owned by `/localize` skill content pipeline + translator contract
- Per-system character-limit budgets → live in each consumer GDD + CSV `# context` cells
- Fonts per locale (e.g., CJK fallback for Japanese) → owned by UI Framework (ADR-0004) + future FontRegistry extensions
- VO localization asset production → owned by Audio GDD + future voice-direction sprint

## Visual/Audio Requirements

**None.** Localization Scaffold has no visual or audio output of its own. Font selection per locale is owned by the UI Framework's FontRegistry (ADR-0004); glyph fallback for CJK locales (Japanese, Korean, Chinese), if supported post-launch, will require FontRegistry extensions. VO localization is separate asset production owned by Audio.

## UI Requirements

**None directly owned by Localization Scaffold.** Settings & Accessibility (system 23) owns the locale-picker UI. Requirements from this scaffold that the picker must satisfy:

- Picker MUST only offer locales returned by `TranslationServer.get_loaded_locales()` (no hardcoded locale list)
- Picker MUST persist selection to `user://settings.cfg` under `[localization]` section, key `locale`
- Picker MUST call `TranslationServer.set_locale(locale_id)` on change and emit `Events.setting_changed("settings", "locale", locale_id)` so other systems can react
- Picker MUST display each locale in its own language (e.g., "Français" for French, not "French"), not in the current locale's translation

At MVP, the locale picker ships with only one option ("English"), so the UI can be a disabled/readonly display. The picker goes live when a second locale is authored.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| `tr()` mandate | `docs/architecture/adr-0004-ui-framework.md` Rule 9 | "All visible strings via tr() from day one" | Rule dependency |
| Forbidden pattern `hardcoded_visible_string` | `docs/registry/architecture.yaml` | Registered by ADR-0004; enforced by `/localize` audit | Rule dependency |
| Settings separation | `docs/architecture/adr-0003-save-format-contract.md` | Settings in `user://settings.cfg`, not SaveGame | Rule dependency |
| FontRegistry for per-locale fonts (future) | ADR-0004 UI Framework | `FontRegistry` static class with typed getters | Extension point (not MVP) |
| Engine localization API | `docs/engine-reference/godot/modules/ui.md` + engine docs | `TranslationServer`, `tr()`, `Control.auto_translate_mode`, CSV plural format | Engine dependency |
| `/localize` skill | `.claude/skills/localize/` | Audit + translator-package pipeline | Tooling dependency (post-launch) |

## Acceptance Criteria

### Structural / lint (automated grep checks)

1. **GIVEN** any GDScript file in `res://src/`, **WHEN** grepped for user-visible `String` literals assigned to `Label.text`, `Button.text`, `RichTextLabel.text`, or similar display fields, **THEN** zero matches — all assignments use `tr("key")`. *Classification: lint check.*
2. **GIVEN** any GDScript file, **WHEN** grepped for `tr("[^\.]` (tr() calls where the argument does not contain at least one dot), **THEN** zero matches — keys MUST use domain-prefixed dot-notation per Rule 2. *Classification: lint check.*
3. **GIVEN** any GDScript file, **WHEN** grepped for `tr(".*")` containing sentences (spaces and capital letters in the argument), **THEN** zero matches — keys are NEVER English sentences. *Classification: lint check (catches `tr("Start Mission")` violations).*
4. **GIVEN** any CSV in `res://translations/`, **WHEN** parsed, **THEN** every row has a non-empty `# context` column. *Classification: `/localize` audit.*
5. **GIVEN** all CSVs in `res://translations/`, **WHEN** aggregated, **THEN** no two rows across different CSVs share the same `keys` value (no cross-domain key collisions). *Classification: `/localize` audit.*

### Runtime behavior

6. **GIVEN** a key `menu.main.start_mission` with English value `"Start Mission"`, **WHEN** code calls `tr("menu.main.start_mission")`, **THEN** it returns `"Start Mission"`.
7. **GIVEN** a key that does not exist in any CSV, **WHEN** `tr("nonexistent.key.name")` is called, **THEN** it returns `"nonexistent.key.name"` (Godot fallback). *Intended failure mode per Edge Cases.*
8. **GIVEN** the active locale is `fr` and a key exists in `en` but not `fr`, **WHEN** `tr("key")` is called, **THEN** the English value is returned (fallback to base locale).
9. **GIVEN** a `Label` node with `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` and text set to a translation key, **WHEN** `TranslationServer.set_locale()` is called with a new locale, **THEN** the Label text updates to the new locale's value without a scene reload.

### Plural forms

10. **GIVEN** a plural key `hud.collection.count` encoded with the Godot 4.6 `?plural` marker column populated for two row-repetitions (singular + other forms) and a `?pluralrule` directive row declaring English's `n != 1` rule (or a custom 3-form `n==0?0:n==1?1:2` rule), **WHEN** code calls `tr_n("hud.collection.count", "1 document", count)`, **THEN** count=0 returns "no documents", count=1 returns "1 document", count=7 returns "7 documents collected" (after `String.format({"count": 7})` substitution on the form-2 template).

### Locale switching

11. **GIVEN** the player selects French in the Settings locale picker, **WHEN** the selection commits, **THEN** `TranslationServer.get_locale()` returns `"fr"` AND `Events.setting_changed("settings", "locale", "fr")` is emitted AND `user://settings.cfg` `[localization] locale` field is updated.
12. **GIVEN** the player relaunches the game after setting locale to `fr`, **WHEN** the game starts, **THEN** `TranslationServer.get_locale()` returns `"fr"` (persisted across sessions).
13. **GIVEN** the locale picker is rendered, **WHEN** enumerating its options, **THEN** each offered locale is present in `TranslationServer.get_loaded_locales()` (no hardcoded options).

### Pseudolocalization dev workflow

14. **GIVEN** a dev build with `_dev_pseudo.csv` loaded, **WHEN** pseudolocalization is activated in the editor, **THEN** all UI text renders with ~140% length expansion (wrapped, all-caps, bracketed). **AND** release exports exclude `_dev_pseudo.csv` via export filter.

### `/localize` audit behavior

15. **GIVEN** the `/localize` skill runs in audit mode on the project, **WHEN** it completes, **THEN** it reports: orphan keys (in CSV but not referenced by any `tr()` call), missing keys (called via `tr()` but not in any CSV), `hardcoded_visible_string` violations, `key_in_code_as_english` violations, `context_column_omitted` violations.

### Accessibility integration

16. **GIVEN** the Settings & Accessibility screen reader integration is active (Godot 4.5+ AccessKit), **WHEN** a screen reader reads a Label with a `tr()`-resolved string, **THEN** the translated string is announced — not the key.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Which target locales post-launch, and in what order? | Producer + Community Manager | Before post-launch localization sprint | Decision drives font-availability (CJK fallback if Japanese/Chinese/Korean), RTL preparedness (Arabic/Hebrew), and translation budget. MVP decision: English only; future decision driven by post-launch sales data. |
| Is VO localization in scope post-launch, or is the game subtitle-localized only? | Producer + Audio Director | Before post-launch localization sprint | VO localization is ~10× the cost of text localization. Likely scope: subtitle-localized for additional languages; VO English-only forever. Decision belongs to Production, not this GDD. |
| When a document's English body text is authored, should the translator-facing context column include art-bible tonal references directly, or link to a style guide? | Writer + Localization Lead | During Document Collection GDD authoring | Recommendation: brief inline reference + link to a standalone `design/writing/translator-style-guide.md` authored alongside Document Collection GDD. Too verbose inline bloats CSVs; too brief loses tone in translation. |
| Should player names (e.g., "Eve Sterling") be translatable, or held as proper nouns? | Narrative Director | Before first non-English locale is authored | Recommendation: proper nouns stay English (per NOLF1 convention — Cate Archer was "Cate Archer" in French). Exception: localized spelling variants may be added per culture (e.g., transliteration to katakana for Japanese). Document in translator style guide. |
| What's the font fallback chain for non-Latin scripts? | UI Framework / FontRegistry extension | Post-launch if CJK locales are scoped | FontRegistry currently declares Futura/DIN/American Typewriter/Futura Extra Bold Condensed — all Latin-only. CJK fallback would add Noto Sans CJK (free license) or similar. Deferred until CJK locale is committed. |
