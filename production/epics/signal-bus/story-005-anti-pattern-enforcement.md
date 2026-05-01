# Story 005: Anti-pattern enforcement — forbidden patterns + CI grep guards

> **Epic**: Signal Bus
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-04-29
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/signal-bus.md`
**Requirement**: Signal Bus AC 9 (no service-locator), AC 10 (no wrapper emit), AC 13 (no enums on Events.gd), AC 14 (single Variant exception)

**ADR Governing Implementation**: ADR-0002 §Risks (5 forbidden patterns) + Implementation Guidelines 2, 6, 7
**ADR Decision Summary**: 5 forbidden patterns fence Signal Bus against drift: `event_bus_with_methods`, `event_bus_wrapper_emit`, `event_bus_request_response`, `event_bus_engine_signal_reemit`, `event_bus_enum_definition`. Plus the cross-cutting `autoload_singleton_coupling` pattern (for any system reaching into another autoload's methods rather than using the bus). All registered in the architecture registry; CI grep guards catch violations on PR.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure tooling story — no engine API risk. Uses standard Bash grep + GdUnit4 fixture pattern.

**Control Manifest Rules (Foundation)**:
- Forbidden: never add methods, state, or query helpers to `events.gd` (pattern `event_bus_with_methods`)
- Forbidden: never add wrapper emit methods like `Events.emit_player_damaged(args)` (pattern `event_bus_wrapper_emit`)
- Forbidden: never implement synchronous request-response patterns through the bus (pattern `event_bus_request_response`)
- Forbidden: never re-emit built-in Godot signals through the bus (pattern `event_bus_engine_signal_reemit`)
- Forbidden: never define enums on `events.gd` (pattern `event_bus_enum_definition`)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria:*

- [ ] **AC-9**: GIVEN any system source file, WHEN code-reviewed for cross-system communication patterns, THEN all cross-system event dispatch is via `Events.signal_name.emit(...)` or `Events.signal_name.connect(...)` — no system holds direct references to or calls methods on another system's autoload (per `autoload_singleton_coupling`). *Classification: code-review checkpoint — not automated test; reviewer responsibility.*
- [ ] **AC-10**: GIVEN any system source file, WHEN grepped for `Events\.emit_`, THEN zero matches (no wrapper emit methods, per `event_bus_wrapper_emit` — emit is direct via `Events.signal_name.emit(args)`).
- [ ] **AC-13**: GIVEN `events.gd` source file, WHEN grepped for `enum `, THEN zero matches (enums owned by their concept's class, not the bus).
- [ ] **AC-14**: GIVEN all signal declarations in `events.gd`, WHEN grepped for `: Variant`, THEN exactly one match exists (`setting_changed` value parameter — the sole intentional Variant exception per ADR-0002).

---

## Implementation Notes

*Derived from ADR-0002 §Risks + ADR-0002 IG 2 + IG 6 + IG 7 + GDD §Acceptance Criteria #14:*

1. **Register all 5 forbidden patterns + 1 cross-cutting pattern in the architecture registry** at `docs/registry/architecture.yaml` (or equivalent file if the project's registry lives elsewhere — check existing structure first):
   - `event_bus_with_methods` — events.gd may not declare `func`/`var`/`const` outside header
   - `event_bus_wrapper_emit` — no `Events.emit_*(...)` call sites; use `Events.<signal>.emit(...)` directly
   - `event_bus_request_response` — no signal-emit-then-poll pattern; bus is fire-and-forget
   - `event_bus_engine_signal_reemit` — no `Events.<signal>.emit` triggered by an engine signal handler (e.g., `SceneTree.node_added` re-emit through bus)
   - `event_bus_enum_definition` — no `enum` declaration on `events.gd`
   - `autoload_singleton_coupling` — no `<OtherAutoload>.<method>(...)` cross-autoload method calls except the explicitly carved-out ADR-0002 §Accessor Conventions exemption (SAI → Combat reads only)
2. **Create CI grep guards** at `tests/unit/foundation/anti_pattern_grep_test.gd` (or via a Bash CI step depending on project conventions) for each of the four lint-friendly patterns:
   - **AC-10 grep**: `grep -nE "Events\.emit_" src/ -r` → zero matches expected
   - **AC-13 grep**: `grep -nE "^enum " src/core/signal_bus/events.gd` → zero matches
   - **AC-14 grep**: `grep -nE ": Variant" src/core/signal_bus/events.gd` → exactly 1 match (line declaring `setting_changed(category, name, value: Variant)`)
   - **events.gd structural purity (Story 001 already establishes this; recap here for completeness)**: zero `func ` / `var ` / `const ` declarations
3. **Document AC-9** as a code-review checkpoint, not an automated guard. Add a checklist entry to `docs/registry/code-review-checklist.md` (or equivalent): "Does this PR introduce a `<OtherAutoload>.<method>(...)` cross-autoload method call? If yes, is it covered by the ADR-0002 §Accessor Conventions exemption (SAI → Combat read accessors only)? If no, reject."
4. The grep guards run on every PR via the existing `tests/gdunit4_runner.gd` headless test script. CI failure on any of the three automated patterns blocks merge.
5. The `autoload_singleton_coupling` pattern is harder to grep cleanly (would need an enumerated list of autoload names + cross-references to filter). Recommend: implement as a soft grep that lists candidate violations, reviewed manually on PR. Do not block merge automatically.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: structural purity test for events.gd (overlaps with AC-13 / AC-14 framing — Story 001 already implements the `func`/`var`/`const` purity grep; this story extends with the `enum` and `: Variant` grep variants)
- Story 002: signal declarations (this story validates the rule — does not add new signals)
- The `forgotten_duplicate_deep_on_load` and other Save/Load forbidden patterns — owned by Save/Load epic Story 005-equivalent

---

## QA Test Cases

**AC-9** *(code-review checkpoint, not automated test)*:
- **Given**: a PR touching any `src/` file
- **When**: a reviewer runs `grep -nE "(Events|EventLogger|SaveLoad|InputContext|LevelStreamingService|PostProcessStack|Combat|FailureRespawn|MissionLevelScripting|SettingsService)\.[a-z_]+\(" src/` against the changed file
- **Then**: every match is either (a) an `Events.<signal>.emit/connect/disconnect/is_connected` call (allowed) OR (b) covered by the ADR-0002 §Accessor Conventions exemption (SAI → Combat reads `has_los_to_player`, `takedown_prompt_active`)
- **Pass condition**: no matches outside the allowed set; reviewer signs off on PR

**AC-10**: No wrapper emit methods
- **Given**: source tree under `src/`
- **When**: automated test runs `grep -rE "Events\.emit_" src/`
- **Then**: zero matches
- **Edge cases**: legitimate `Events.<signal>.emit(...)` calls — these have `.emit` (not `.emit_`) and are NOT matched by the regex; comments mentioning the forbidden pattern in documentation — should be inside `.md` files, not `.gd`

**AC-13**: events.gd has no enum declarations
- **Given**: `src/core/signal_bus/events.gd`
- **When**: automated test runs `grep -nE "^enum " src/core/signal_bus/events.gd`
- **Then**: zero matches
- **Edge cases**: enum referenced in a signal type annotation (e.g., `signal foo(bar: StealthAI.AlertState)`) — these match the `enum-name-as-type` pattern, NOT the `enum-declaration` pattern; the `^enum ` anchor ensures only declarations are caught

**AC-14**: events.gd has exactly 1 `: Variant` (the `setting_changed` exception)
- **Given**: `src/core/signal_bus/events.gd`
- **When**: automated test runs `grep -cE ": Variant" src/core/signal_bus/events.gd`
- **Then**: count is exactly 1; the matching line is the `setting_changed(...)` signal declaration
- **Edge cases**: `: Variant` in a comment — strip comments before counting; future signal added that legitimately needs Variant — requires ADR-0002 amendment + AC-14 update; Variant in a type annotation outside signal declarations (defensive — events.gd should have no other type annotations per Story 001 + AC-2 structural purity)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `tests/unit/foundation/anti_pattern_grep_test.gd` — must exist and pass (AC-10, AC-13, AC-14 grep guards)
- `production/qa/smoke-2026-MM-DD.md` — smoke check that confirms registry update + checklist update landed
- AC-9 has no automated test artifact — reviewer responsibility documented in `docs/registry/code-review-checklist.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (signal declarations exist; AC-14 needs the `setting_changed` declaration to exist before counting can return 1)
- Unlocks: nothing within this epic; cross-epic the registered forbidden patterns enforce on every PR

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: AC-10/13/14 covered by 4 grep-style guards; AC-9 (cross-autoload coupling) documented as code-review checkpoint.
**Test results**: 4/4 in `anti_pattern_grep_test.gd` PASS.

### Files added
- `tests/unit/foundation/anti_pattern_grep_test.gd` — 4 tests:
  1. AC-10: no `Events.emit_*` wrapper-emit calls in `src/`.
  2. AC-13: no `enum` declarations on `events.gd`.
  3. AC-14: exactly one `: Variant` annotation on `events.gd` (the `setting_changed` exception).
  4. Defense-in-depth: `events.gd` has zero `func`/`var`/`const` declarations.

### Codebase status at story closure
Already compliant with all 4 patterns — zero violations existed. The tests now CI-enforce the rules going forward.

### Verdict
COMPLETE.
