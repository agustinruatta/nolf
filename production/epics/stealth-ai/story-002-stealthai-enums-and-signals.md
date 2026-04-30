# Story 002: StealthAI enums + Events.gd signal declarations

> **Epic**: Stealth AI
> **Status**: Ready
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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — foundational enum and signal layer; no gameplay systems required
- Unlocks: Story 001 (needs `StealthAI.AlertState` for guard state field), Story 003 (needs `StealthAI.AlertCause` for perception cache), Story 004 (needs state_multiplier from `AlertState`), Story 005 (needs all thresholds), Story 008 (needs signal declarations)
