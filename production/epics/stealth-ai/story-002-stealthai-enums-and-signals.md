# Story 002: StealthAI enums + Events.gd signal declarations

> **Epic**: Stealth AI
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (S — 2 new files, Events.gd amendment, signal purity tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-002`, `TR-SAI-003`, `TR-SAI-004`, `TR-SAI-005`, `TR-SAI-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: Enum types used in signal payloads are defined as inner enums on the system class that owns the concept — `StealthAI.AlertState`, `StealthAI.AlertCause`, `StealthAI.Severity`, `StealthAI.TakedownType` all live on `stealth_ai.gd`, NEVER on `events.gd`. Signal declarations in `events.gd` reference these qualified names. Publishers emit directly (`Events.alert_state_changed.emit(args)`); no wrapper methods. The ADR-0002 amendment (2026-04-22 + 2026-04-24) landed the full 4-param / 3-param signal signatures with `severity` and `guard_incapacitated(guard: Node, cause: int)` — these are the authoritative forms.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `signal` keyword, inner `enum`, `class_name` registration, and `@static_unload` annotation are all stable Godot 4.0+. No post-cutoff APIs in this story. ADR-0002 is Accepted (Sprint 01 smoke-test passed 2026-04-29 — signal declarations + autoload verified end-to-end on Godot 4.6.2 Linux Vulkan).

**Control Manifest Rules (Foundation)**:
- Required: enum types in signal signatures MUST be defined on the system class that owns the concept; use the qualified name in `events.gd` declarations — ADR-0002 IG 2
- Required: use direct emit (`Events.<signal>.emit(args)`), not wrapper methods — ADR-0002 §Risks
- Forbidden: never add methods, state, or query helpers to `events.gd` — pattern `event_bus_with_methods`
- Forbidden: never define enums on `events.gd` — pattern `event_bus_enum_definition`
- Guardrail: `_compute_severity` is SAI-owned logic, not bus logic; never put it in `events.gd`

---

## Acceptance Criteria

*From GDD §Detailed Rules (Alert state ownership) + §Interactions (Signal Bus row) + TR-SAI-002..006:*

- [ ] **AC-1**: `res://src/gameplay/stealth/stealth_ai.gd` declares `class_name StealthAI extends Node` with inner enums:
  ```gdscript
  enum AlertState { UNAWARE, SUSPICIOUS, SEARCHING, COMBAT, UNCONSCIOUS, DEAD }
  enum AlertCause { HEARD_NOISE, SAW_PLAYER, SAW_BODY, HEARD_GUNFIRE, ALERTED_BY_OTHER, SCRIPTED, CURIOSITY_BAIT }
  enum Severity { MINOR, MAJOR }
  enum TakedownType { MELEE_NONLETHAL, STEALTH_BLADE }
  ```
  All four enums declared here; none declared on `events.gd`.
- [ ] **AC-2**: `res://src/core/signal_bus/events.gd` contains the following SAI-domain signal declarations (4-param / 3-param / 2-param forms per ADR-0002 2026-04-22 + 2026-04-24 amendments):
  ```gdscript
  signal alert_state_changed(actor: Node, old_state: StealthAI.AlertState, new_state: StealthAI.AlertState, severity: StealthAI.Severity)
  signal actor_became_alerted(actor: Node, cause: StealthAI.AlertCause, source_position: Vector3, severity: StealthAI.Severity)
  signal actor_lost_target(actor: Node, severity: StealthAI.Severity)
  signal takedown_performed(actor: Node, attacker: Node, takedown_type: StealthAI.TakedownType)
  signal guard_incapacitated(guard: Node, cause: int)
  signal guard_woke_up(guard: Node)
  ```
  Note: `guard_incapacitated` `cause` is typed as `int` (not `CombatSystemNode.DamageType`) per cross-autoload convention — SAI does not import CombatSystemNode.
- [ ] **AC-3**: Static source grep confirms `events.gd` contains zero `func ` declarations (excluding `_ready`), zero `var ` declarations, zero `const ` declarations beyond debug constants. Enum declarations are also absent.
- [ ] **AC-4**: `_compute_severity(new_state: StealthAI.AlertState, cause: StealthAI.AlertCause) -> StealthAI.Severity` is declared as a static method on `StealthAI`, implementing the rule: `ALERTED_BY_OTHER` → MINOR; `new_state in {SEARCHING, COMBAT, DEAD, UNCONSCIOUS}` → MAJOR; else MINOR. Unit test covers the full 6×7 matrix (42 cells per AC-SAI-3.4).
- [ ] **AC-5** (VS scope): For VS, only `alert_state_changed`, `actor_became_alerted`, and `actor_lost_target` need subscribers wired (Audio stinger — Story 008). The `takedown_performed`, `guard_incapacitated`, `guard_woke_up` declarations MUST exist in `events.gd` to maintain API completeness, but no subscribers are connected in VS scope — they remain dormant until post-VS stories.

---

## Implementation Notes

*Derived from ADR-0002 IG 2 + GDD §Detailed Rules:*

`stealth_ai.gd` is the enum-and-rule owner. Target ≤ 150 LoC (per GDD OQ-SAI-8). In VS it also hosts `_compute_severity`. The Guard class (`guard.gd`, Story 001) will import via `class_name` — no autoload needed for enum access.

The `_compute_severity` implementation from GDD §Detailed Rules is authoritative:
```gdscript
static func _compute_severity(new_state: AlertState, cause: AlertCause) -> Severity:
    if cause == AlertCause.ALERTED_BY_OTHER:
        return Severity.MINOR
    if new_state == AlertState.SEARCHING or new_state == AlertState.COMBAT \
       or new_state == AlertState.DEAD or new_state == AlertState.UNCONSCIOUS:
        return Severity.MAJOR
    return Severity.MINOR
```

Rationale for DEAD / UNCONSCIOUS → MAJOR (per GDD): a guard's removal from play is high-salience for Mission Scripting + Audio clean-up. MINOR transitions avoid the brass-punch stinger (Pillar 1 comedy preservation).

`events.gd` already exists at `src/core/signal_bus/events.gd` (Sprint 01 skeleton). This story extends it with the 6 SAI-domain signal declarations. The ADR-0002 amendment gates are CLOSED (2026-04-22 + 2026-04-24) — no further ADR amendment is required before this story plays.

For VS, `guard_incapacitated` and `guard_woke_up` are post-VS in terms of subscribers but the declarations are required now so the signal bus API is self-consistent when Story 008 (Audio stinger) wires `alert_state_changed`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Guard node hierarchy (the consumer of these enums)
- Story 003: RaycastProvider DI + PerceptionCache (uses `StealthAI.AlertCause` but not authored here)
- Story 004: F.1 sight fill formula (uses `StealthAI.AlertState` for state_multiplier table)
- Story 008: Audio stinger subscriber wiring (`alert_state_changed` subscriber)
- Post-VS: `takedown_performed` subscriber (no chloroform gadget in VS); `guard_incapacitated` / `guard_woke_up` subscribers (no UNCONSCIOUS/DEAD states in VS); `TerminalCause` enum (deferred — save/load serialisation not in VS scope)

---

## QA Test Cases

**AC-1 — Enum declarations on StealthAI class**
- Given: `stealth_ai.gd` source file
- When: a unit test creates a `StealthAI` instance and reads `StealthAI.AlertState.UNAWARE`, `StealthAI.AlertCause.SAW_PLAYER`, `StealthAI.Severity.MAJOR`, `StealthAI.TakedownType.MELEE_NONLETHAL`
- Then: all 4 enum values resolve without error; `StealthAI.AlertState.values().size() == 6` (6 states); `StealthAI.AlertCause.values().size() == 7`
- Edge cases: enum declared on `events.gd` → grep test fails (AC-3); enum with wrong member count → test fails

**AC-2 — Signal declarations in events.gd**
- Given: `src/core/signal_bus/events.gd` source
- When: a static grep and a runtime property-list check
- Then: all 6 signal names present; `Events.alert_state_changed` has 4 parameters; `Events.actor_became_alerted` has 4 parameters; `Events.guard_incapacitated` has 2 parameters (guard + cause:int); zero enum declarations in `events.gd`
- Edge cases: wrong parameter count → GDScript argument-count mismatch at emit-site (caught by runtime type checks in debug builds)

**AC-3 — events.gd purity**
- Given: `src/core/signal_bus/events.gd` post-SAI amendment
- When: source-file grep for `func `, `var `, `const `, `enum `
- Then: zero matches (excluding class header + `extends` line + comments)
- Edge cases: a helper accidentally added → CI fails; `_compute_severity` accidentally placed in `events.gd` → caught here

**AC-4 — _compute_severity 6x7 matrix (AC-SAI-3.4)**
- Given: `StealthAI._compute_severity(state, cause)` called with all 42 (state, cause) combinations
- When: results compared against the expected table
- Then: all 42 cells match; specifically: any `cause == ALERTED_BY_OTHER` → MINOR; `state in {SEARCHING, COMBAT, DEAD, UNCONSCIOUS}` with other cause → MAJOR; `state in {UNAWARE, SUSPICIOUS}` with other cause → MINOR
- Edge cases: UNCONSCIOUS row — even with an unusual cause, result is MAJOR (uniform rule verified)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_enums_test.gd` — enum presence + value counts
- `tests/unit/feature/stealth_ai/stealth_ai_severity_rule_test.gd` — 42-cell matrix (AC-SAI-3.4)
- `tests/unit/foundation/events_sai_signals_test.gd` — signal declarations + purity (AC-2 + AC-3)

**Status**: [x] Complete — 26 new tests across 3 files; suite 470/470 PASS exit 0.

---

## Completion Notes

**Completed**: 2026-05-02
**Criteria**: 5/5 PASSING (all auto-verified via 26 new test functions; full 42-cell severity matrix green)

**Test Evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_enums_test.gd` — 10 tests (AC-1 enum presence + value counts + zero-pin)
- `tests/unit/feature/stealth_ai/stealth_ai_severity_rule_test.gd` — 8 tests (AC-4 full 42-cell matrix + 5 row-invariants + 2 canonical sanity checks)
- `tests/unit/foundation/events_sai_signals_test.gd` — 8 tests (AC-2 signal presence + arg counts + AC-3 enum-purity grep)
- AC-3 `func`/`var`/`const` purity continues to be enforced by `tests/unit/foundation/events_purity_test.gd` (pre-existing) — `events_sai_signals_test.gd` adds the new `enum ` purity pin
- Suite: **470/470 PASS** exit 0 (baseline 444 + 26 new SAI-002 tests; zero errors / failures / flaky / orphans / skipped)

**Files Modified / Created**:
- `src/gameplay/stealth/stealth_ai.gd` (NEW, 99 LOC) — class StealthAI with 4 enums (AlertState×6, AlertCause×7, Severity×2, TakedownType×2) + static `_compute_severity` rule
- `src/core/signal_bus/events.gd` (modified) — appended 6 SAI-domain signal declarations (lines 99-105); updated SKELETON STATUS comment + AI/Stealth domain header comment
- `tests/unit/feature/stealth_ai/stealth_ai_enums_test.gd` (NEW, ~140 LOC, 10 test functions)
- `tests/unit/feature/stealth_ai/stealth_ai_severity_rule_test.gd` (NEW, ~190 LOC, 8 test functions, includes 42-cell matrix oracle)
- `tests/unit/foundation/events_sai_signals_test.gd` (NEW, ~187 LOC, 8 test functions)
- `tests/unit/foundation/events_signal_taxonomy_test.gd` (modified) — removed 6 deferred-absence assertions for SAI signals (lines 434-457 in original); replaced with 5-line comment block pointing to the new positive-presence tests in `events_sai_signals_test.gd`

**Code Review**: APPROVED WITH SUGGESTIONS (godot-gdscript-specialist + qa-tester invoked inline)
- godot-gdscript-specialist: MINOR ISSUES → 2 advisories applied inline:
  1. Typed enum loop variables in test files (`for state: StealthAI.AlertState in ...` instead of `for state: int in ...`) — improves static-typing rigor per CLAUDE.md
  2. Extracted `var actual: StealthAI.Severity = ...` to avoid double-invocation in failure messages (UNCONSCIOUS + DEAD row tests)
- qa-tester: TESTABLE → 3 NITs documented (all advisory, all deferred):
  1. `test_alert_state_members_resolve_by_name` uses `is_greater_equal(0)` rather than specific ordinal pins — UNAWARE=0 and MINOR=0 pinned explicitly; DEAD/UNCONSCIOUS/SEARCHING/COMBAT ordinals not pinned (low risk; reordering would only fail SAI-001's `current_alert_state: int = 0` UNAWARE assumption, which IS pinned)
  2. AC-3 traceability split between `events_purity_test.gd` (pre-existing, covers func/var/const) and new `events_sai_signals_test.gd` (covers enum) — Test Evidence section above documents this
  3. No `AlertCause` ordinal pins beyond `ALERTED_BY_OTHER` — severity rule branches on value identity, so ordinal reordering is safe; flagged for completeness only

**Deviations Logged**:
- **TR-SAI-005 vs Story AC-1 discrepancy**: TR registry text lists 5 `AlertCause` values (HEARD, SAW_PLAYER, SAW_BODY, ALERTED_BY_OTHER, SCRIPTED). Story AC-1 specifies 7 values (splits HEARD into HEARD_NOISE / HEARD_GUNFIRE; adds CURIOSITY_BAIT). Implementation follows the **story spec (7 values)** as authoritative — story spec is the design artefact closer to the GDD intent. The TR registry text predates the design refinement. Documented in `stealth_ai.gd` header (lines 17-22) for `/architecture-review` reconciliation.
- **`_compute_severity` underscore-prefix vs GDScript convention**: GDScript reserves `_method_name` for private members, but the story AC-4 explicitly uses `_compute_severity` and the function is consumed publicly (StealthAI.\_compute_severity called from tests; will be called from Story 005 thresholds + Story 008 audio stinger). Implementation follows AC-4 verbatim (underscore prefix retained). Doc-vs-convention drift; flagged for `/architecture-review`.
- **`events_signal_taxonomy_test.gd` modification**: removed 6 deferred-absence assertions (now-stale) and replaced with comment block. The taxonomy test was a regression fence against premature SAI-signal declaration; SAI-002 is precisely the unlock moment. New positive-presence assertions live in `events_sai_signals_test.gd` (AC-2 coverage). Modification was necessary to keep the suite green and is in-scope for SAI-002 (signals existing now is what AC-2 requires).

**Tech Debt Logged**: None.
- 3 qa-tester NITs are advisory-only (low-risk, no immediate impact)
- 2 godot-gdscript-specialist suggestions (class-level doc comment, terminal-state row helper) deferred as code-quality polish — not tracked

**Unlocks**: Story 003 (RaycastProvider DI + perception cache — needs `StealthAI.AlertCause`), Story 004 (F.1 sight fill — needs `AlertState` for state_multiplier table), Story 005 (F.5 thresholds + escalation — needs all enums + `_compute_severity`), Story 008 (Audio stinger subscriber — needs all 6 signal declarations).

**Story 001 follow-up**: SAI-001's `guard.gd:50` currently has `var current_alert_state: int = 0` as a stub. With SAI-002 landed, this can be upgraded to `var current_alert_state: StealthAI.AlertState = StealthAI.AlertState.UNAWARE` in a follow-up commit (NOT part of SAI-002 scope per Out of Scope §1; will be picked up by SAI-005 or earlier as a small refactor).

---

## Dependencies

- Depends on: None — foundational enum and signal layer; no gameplay systems required
- Unlocks: Story 001 (needs `StealthAI.AlertState` for guard state field), Story 003 (needs `StealthAI.AlertCause` for perception cache), Story 004 (needs state_multiplier from `AlertState`), Story 005 (needs all thresholds), Story 008 (needs signal declarations)
