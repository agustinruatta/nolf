# LOC-002 AC-5: Export-preset Filter Evidence — DEFERRED

**Story**: LOC-002 — Pseudolocalization CSV + dev workflow + export filter
**AC**: AC-5 (export build excludes `_dev_pseudo.csv` + its `.translation` artifacts)
**Status**: **DEFERRED** — manual verification required on first export pass.

## Why deferred

Godot's `export_presets.cfg` is created when a developer first uses the
**Project → Export...** dialog and configures a preset (Linux/X11, Windows,
etc.). At LOC-002 implementation time (2026-05-01), no export preset exists yet
in the project — the file is absent from the working tree.

AC-5 requires verifying that exported builds **omit** `_dev_pseudo.*` files.
This requires:
1. Creating the export presets first (Linux + Windows per Tech Preferences)
2. Configuring `exclude_filter` to drop `_dev_pseudo` artifacts
3. Running an actual export
4. Inspecting the output PCK / dir for absence of `_dev_pseudo` files

This work belongs to a future export-pipeline story (or the first release-prep
sprint). It is **not** appropriate to fabricate `export_presets.cfg` at this
stage — the presets carry signing/platform/build configuration that the
release-manager owns.

## Required filter (when presets exist)

Add to **every** preset's `exclude_filter` field in `export_presets.cfg`:

```ini
exclude_filter="*/_dev_pseudo.csv,*/_dev_pseudo.*.translation,*/_dev_pseudo.# context.translation,*/_dev_pseudo.csv.import"
```

This filter matches:
- `translations/_dev_pseudo.csv` — source CSV
- `translations/_dev_pseudo.en.translation` — English column artifact
- `translations/_dev_pseudo.pseudo.translation` — pseudolocale column artifact
- `translations/_dev_pseudo.# context.translation` — context column artifact
- `translations/_dev_pseudo.csv.import` — Godot importer metadata

## Verification protocol (when ready)

1. Create export preset(s) via **Project → Export → Add...** (Linux/X11 first).
2. Add the `exclude_filter` above.
3. Run **Export Project...** to a temp directory.
4. Inspect output:
   ```bash
   # PCK output (look for any _dev_pseudo entry)
   strings <output>.pck | grep _dev_pseudo
   # Should produce zero matches.
   ```
5. Confirm `TranslationServer.get_loaded_locales()` from the EXPORTED build
   does **not** include `pseudo`.
6. Update this file with: date verified, git SHA, builder username, output
   path inspected, grep results.

## Sign-off slot

| Field | Value |
|---|---|
| Verified by | _(pending — not yet exported)_ |
| Date | _(pending)_ |
| Build target | _(pending)_ |
| Git SHA at verification | _(pending)_ |
| Notes | _(pending)_ |

---

**Related**: LOC-002 §AC-5, GDD `localization-scaffold.md` §Detailed Design,
ADR-0004 (UI Framework — Localization clauses).
