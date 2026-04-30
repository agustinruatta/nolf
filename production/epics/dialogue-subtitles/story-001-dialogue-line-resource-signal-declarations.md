# Story 001: DialogueLine resource scaffold + Dialogue-domain signal declarations

> **Epic**: Dialogue & Subtitles
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (M — 2 new files + signal taxonomy additions + unit test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/dialogue-subtitles.md`
**Requirement**: TR-DLG-001, TR-DLG-008
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: D&S is the **sole publisher** of `dialogue_line_started(speaker: StringName, line_id: StringName)` and `dialogue_line_finished()` — these are frozen Dialogue-domain signal declarations on `Events.gd` per ADR-0002 L304. No other system may emit these signals. The `DialogueLine` resource is a data container (`extends Resource`) whose schema is defined here; its consumption by the orchestrator lives in Story 002.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `signal` keyword + typed signal parameters + `class_name ... extends Resource` + `@export` are stable Godot 4.0+. No post-cutoff APIs involved. ADR-0002 G1 smoke test already verified end-to-end signal emit on Godot 4.6.2 stable (Sprint 01). Enum ownership rule (ADR-0002 IG 2): `BanterCategory` and `PriorityBucket` enums are defined on `DialogueLine`, not on `Events.gd` — the qualified-name pattern `DialogueLine.PriorityBucket` is used in signal signatures on `Events.gd` if bucket is ever exposed in a signal (currently it is not — bucket is internal to the orchestrator). For VS scope, the two Dialogue-domain signals use only `StringName` payload types, which are built-in; no cross-system enum reference is needed.

**ADR-0004 (Proposed — G5 deferred)**: ADR-0004 governs the UI Framework including `auto_translate_mode` and `Theme` usage. It is Proposed pending Gate 5 (BBCode→AccessKit). This story does not touch UI rendering — it creates only the data schema and signal declarations. ADR-0004 constraints land in Stories 003 and 004. The deferred G5 affects only post-VS BBCode body parsing, not plain-text VS rendering.

**ADR-0007 (Accepted)**: `DialogueLine` is NOT autoload — it is a `Resource` subclass, loaded per-line by the orchestrator. The 10-autoload table is full and no new entries are permitted.

**ADR-0008 (Proposed — non-blocking)**: D&S claims a sub-slot of Slot 8 pooled residual (0.10 ms peak event-frame). This story creates data-only files with zero frame cost; the budget constraint is enforced in Story 002 (orchestrator). ADR-0008 Proposed status is non-blocking here.

**Control Manifest Rules (Feature layer)**:
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3) — N/A this story (no subscriber code)
- Required: enum types in signal signatures must be defined on the system class that owns the concept (ADR-0002 IG 2)
- Required: direct emit `Events.<signal>.emit(args)` — no wrapper methods (ADR-0002)
- Forbidden: `dialogue_signal_emitted_outside_d&s` — no other system may emit `dialogue_line_started` or `dialogue_line_finished`
- Forbidden: `event_bus_enum_definition` — BanterCategory and PriorityBucket must NOT be defined on `events.gd`
- Forbidden: inner-class typed Resources used as `@export` field types on serialized Resources (ADR-0003 IG 11 — applies to `DialogueLine` as a Resource)

---

## Acceptance Criteria

*From GDD `design/gdd/dialogue-subtitles.md` §H.1 Signal Contract + §C.4 DialogueLine schema, scoped to this story:*

- [ ] **AC-1**: `src/feature/dialogue_subtitles/resources/dialogue_line.gd` declares `class_name DialogueLine extends Resource` with all 11 `@export` fields from GDD §C.4: `id: StringName`, `text_key: StringName`, `audio_stream: AudioStream`, `speaker_id: StringName`, `speaker_label_key: StringName`, `banter_category: DialogueLine.BanterCategory`, `priority_bucket: DialogueLine.PriorityBucket`, `priority_within_bucket: int`, `duration_metadata_s: float`, `section_scope: StringName`, `performance_notes: String`. All fields have doc comments.
- [ ] **AC-2**: `BanterCategory` and `PriorityBucket` are declared as inner enums on `DialogueLine` (NOT on `events.gd`), with values matching GDD §C.4 and §C.5: `BanterCategory { CURIOSITY_BAIT, ALERT_ESCALATION, BODY_DISCOVERY, SPOTTED, CIVILIAN_REACTION, PATROL_AMBIENT, SCRIPTED_SCENE }` and `PriorityBucket { SCRIPTED = 1, COMBAT_DISCOVERY = 2, ESCALATION = 3, CURIOSITY_AMBIENT = 4, IDLE = 5 }`.
- [ ] **AC-3**: `src/core/signal_bus/events.gd` gains two Dialogue-domain signal declarations: `signal dialogue_line_started(speaker: StringName, line_id: StringName)` and `signal dialogue_line_finished()`. Both are frozen per ADR-0002 L304 — payload types are `StringName` (built-in, no cross-system enum reference required at this layer).
- [ ] **AC-4** (from AC-DS-1.1): GIVEN the full `src/` tree, WHEN CI runs `grep -r "dialogue_line_started\.emit\|dialogue_line_finished\.emit" src/`, THEN the only matching file is the D&S implementation file. For this story (no orchestrator yet), the grep returns zero matches in `src/` (signal declarations exist on `events.gd` but no emitter exists yet). The grep gate is written now and will fail until Story 002 adds exactly one emitter.
- [ ] **AC-5**: A unit test at `tests/unit/feature/dialogue_subtitles/dialogue_line_schema_test.gd` creates `DialogueLine.new()`, reflects on its properties, and asserts: `id` defaults to `&""`, `audio_stream` defaults to `null`, `duration_metadata_s` defaults to `0.0`, `priority_within_bucket` defaults to `0`, `BanterCategory.SCRIPTED_SCENE` is accessible, `PriorityBucket.SCRIPTED` equals `1`.

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines + GDD §C.4:*

File structure for this story:

```
src/feature/dialogue_subtitles/
└── resources/
    └── dialogue_line.gd        (class_name DialogueLine extends Resource)

src/core/signal_bus/
└── events.gd                  (append two Dialogue-domain signal declarations)

tests/unit/feature/dialogue_subtitles/
└── dialogue_line_schema_test.gd
```

`DialogueLine` field notes from GDD §C.4:
- `audio_stream: AudioStream` — null is a validation error per FP-DS-2; `select_line()` (Story 002) rejects null streams before emitting any signal
- `text_key: StringName` — raw Localization Scaffold key (e.g., `&"vo.banter.guard_radiator_a"`); NEVER a resolved translated string (FP-DS-12)
- `duration_metadata_s: float = 0.0` — caption-floor for slow readers; 0.0 means caption follows audio length exactly (F.1 degeneracy: B.1)
- `performance_notes: String` — v0.3 addition; QA-readable pacing spec for lines with internal pauses (V.2 Radiator vignette MVP-1); empty string for typical lines

Adding signals to `events.gd` must follow ADR-0002 IG atomic-commit risk: if `events.gd` references an enum type from another class, both must be committed together. For VS scope the two Dialogue-domain signals use only `StringName` built-in types — no cross-system enum reference, so no atomic-commit risk here.

The `events.gd` purity test (from signal-bus epic Story 001, AC-2) asserts zero `func`/`var`/`const` declarations. Signal declarations are not `func`/`var`/`const` and will pass that test cleanly.

Static typing required on all fields per coding standards. Every `@export` field needs a doc comment.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `DialogueAndSubtitles` orchestrator node, `select_line()`, playback lifecycle, rate-gate, range gate, priority resolver, watchdog timer — all runtime behaviour
- Story 003: Self-suppression subscription to `document_opened`/`document_closed`/`ui_context_changed`, visibility state machine
- Story 004: `SubtitleLabel` rendering, Theme resource, period typography
- Story 005: Plaza VS integration smoke test — BQA briefing playthrough

---

## QA Test Cases

**AC-1 + AC-2 — DialogueLine schema + enum ownership**
- **Given**: `src/feature/dialogue_subtitles/resources/dialogue_line.gd` source
- **When**: a unit test creates `DialogueLine.new()` and reflects on its property list via `get_property_list()`
- **Then**: all 11 `@export` fields appear in the list with correct types; `DialogueLine.BanterCategory.SCRIPTED_SCENE` resolves without error; `DialogueLine.PriorityBucket.SCRIPTED == 1`; `BanterCategory` and `PriorityBucket` are NOT present on `Events` or `events.gd` (grep check: `grep -n "BanterCategory\|PriorityBucket" src/core/signal_bus/events.gd` returns zero matches)
- **Edge cases**: inner-class enum fallback (if defined on wrong file, qualified access errors); `audio_stream` default is `null` (not a zero-value AudioStream instance)

**AC-3 — Signal declarations on events.gd**
- **Given**: `src/core/signal_bus/events.gd` after this story's changes
- **When**: a test calls `Events.dialogue_line_started.get_argument_count()` and `Events.dialogue_line_finished.get_argument_count()`
- **Then**: `dialogue_line_started` has 2 arguments; `dialogue_line_finished` has 0 arguments; both are accessible via `Events.<signal>` autoload path
- **Edge cases**: events.gd purity test still passes (signal declarations are not func/var/const — must remain clean per signal-bus Story 001 AC-2)

**AC-4 — Sole-emitter grep gate**
- **Given**: full `src/` tree at this story's completion (no orchestrator yet)
- **When**: CI runs `grep -r "dialogue_line_started\.emit\|dialogue_line_finished\.emit" src/`
- **Then**: zero matches (no emitter exists until Story 002); the gate is written and will enforce uniqueness in Story 002 and beyond
- **Edge cases**: test directory explicitly included to detect accidental test-side emissions that would mislead the gate

**AC-5 — Unit test round-trip**
- **Given**: `DialogueLine.new()` with all fields at defaults
- **When**: test reads `priority_within_bucket`, `duration_metadata_s`, `banter_category`, `priority_bucket`
- **Then**: `priority_within_bucket == 0`, `duration_metadata_s == 0.0`, `banter_category` resolves to a valid enum value (0 = CURIOSITY_BAIT), `priority_bucket` resolves to a valid enum value (1 = SCRIPTED per int backing)
- **Edge cases**: serialisation round-trip of `StringName` fields — `id` and `text_key` survive `ResourceSaver.save` / `ResourceLoader.load` as `StringName` (not `String`)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/dialogue_subtitles/dialogue_line_schema_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Signal Bus epic Story 002 (Dialogue-domain signal declarations on `events.gd` require the production-taxonomy additions pass to be open — but the existing skeleton already has the pattern; this story appends two signals following the same pattern)
- Unlocks: Story 002 (orchestrator needs `DialogueLine` resource + signal declarations to implement the lifecycle)
