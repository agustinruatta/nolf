# Epic: Localization Scaffold

> **Layer**: Foundation
> **GDD**: `design/gdd/localization-scaffold.md`
> **Architecture Module**: Localization Scaffold (CSVs + convention; no autoload — `architecture.md` §3.1)
> **Engine Risk**: MEDIUM (CSV plural form support 4.6; `Control.auto_translate_mode` 4.5; `NOTIFICATION_TRANSLATION_CHANGED` re-resolution)
> **Status**: Ready (with note: governing ADR-0004 is Proposed pending G5 for unrelated scope)
> **Stories**: Not yet created — run `/create-stories localization-scaffold`
> **Manifest Version**: 2026-04-29

## Overview

Localization Scaffold is the string-table architecture and `tr()` discipline
that lets *The Paris Affair* ship with English at MVP but support additional
locales post-launch as a **content-only** delivery — no engineering refactor,
no string-hunting expedition. Every visible string in the codebase routes
through a translation key; the key maps to a CSV translation table loaded at
startup. ADR-0004 locks `tr()` usage from day one via the forbidden pattern
`hardcoded_visible_string`.

The scaffold is a CONVENTION, not a runtime module — it does NOT register an
autoload. Implementation amounts to: (a) one or more CSV files under
`res://translations/` registered in `project.godot [internationalization]`;
(b) a `tr(key)` call wrapping every player-visible string at every site;
(c) per-control `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` for
declarative bindings; (d) `NOTIFICATION_TRANSLATION_CHANGED` handling in
custom Controls that compose strings programmatically; (e) a
pseudolocalization CSV (`_dev_pseudo.csv`) for in-development layout
stress-testing.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0004: UI Framework (Theme + InputContext + FontRegistry) | Mandates `tr()` wrap for every visible string from day one via the forbidden pattern `hardcoded_visible_string`; uses `Control.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` (Gate 4 closed 2026-04-27) for declarative bindings; pluralization handled via Godot 4.6 CSV plural form columns | MEDIUM |

**Status note**: ADR-0004 is currently `Proposed`. Gates 1, 2, 3, 4 are all
closed (Gate 4 — `auto_translate_mode` enum identifiers — is the
Localization-relevant gate; verified 2026-04-27). Gate 5 (BBCode → AccessKit
plain-text serialization) is deferred to runtime AT testing and applies only
to formatted body content (Document Overlay), NOT to the Localization
mechanism. Localization stories may proceed against ADR-0004's Localization
clauses without G5 closure.

## GDD Requirements

The `localization-scaffold.md` GDD specifies:

- Key naming scheme: `domain.context.identifier` (e.g., `overlay.dismiss_hint`, `hud.health_label`)
- One CSV per domain under `res://translations/` (e.g., `overlay.csv`, `hud.csv`, `menu.csv`) — already exists for `overlay.csv` from the Document Overlay UX work
- `_dev_pseudo.csv` for pseudolocalization (visible expansion testing without a real translator)
- Pluralization via 4.6 CSV plural columns (e.g., `weapon.ammo_count.one`, `weapon.ammo_count.other`)
- `String.format({"count": n})` for runtime variable substitution
- `NOTIFICATION_TRANSLATION_CHANGED` re-resolution for programmatically composed strings
- Locale preference read from `user://settings.cfg` (per ADR-0003 + Settings GDD)
- Forbidden pattern: `hardcoded_visible_string` — registered in the architecture registry; bare visible string literals (e.g., `label.text = "Quit"`) are review-rejected

Specific requirement IDs `TR-LOC-001` through `TR-LOC-010` (10 TRs) are in
`docs/architecture/tr-registry.yaml`.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`.
- All acceptance criteria from `design/gdd/localization-scaffold.md` are verified.
- All player-visible strings in `src/` are wrapped in `tr(key)` (zero bare visible string literals — verifiable by grep against the forbidden-pattern fence).
- Per-domain CSVs exist under `res://translations/`; registered in `project.godot [internationalization]`.
- Pseudolocalization CSV (`_dev_pseudo.csv`) renders all keys with reversible character substitutions for layout testing.
- 4.6 CSV plural form columns work for at least one pluralized string (smoke test); fallback to singular form on locale change behaves correctly.
- `NOTIFICATION_TRANSLATION_CHANGED` re-resolution verified in at least one custom Control with a programmatically composed string.
- `auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` set on declarative Control bindings; verified by inspector or test fixture.
- Forbidden pattern `hardcoded_visible_string` registered + a CI grep guard catches bare literals on PRs touching `src/`.
- Logic stories have passing unit tests; UI stories have manual walkthrough docs in `production/qa/evidence/`.

## Verification Spike Status (Sprint 01, 2026-04-29)

ADR-0004 G4 (`Node.AUTO_TRANSLATE_MODE_*` enum identifiers verified) closed
2026-04-27. The `overlay.csv` translation table already exists from the
Document Overlay UX work (2026-04-29) and was successfully imported by Godot
4.6.2 on first project open (`overlay.# context.translation` and
`overlay.en.translation` artifacts present in `translations/`). The
Localization mechanism is verified end-to-end on the Document Overlay path;
remaining work is extending the convention to other surfaces as their
production stories implement them.

## Next Step

Run `/create-stories localization-scaffold` to break this epic into implementable stories.
