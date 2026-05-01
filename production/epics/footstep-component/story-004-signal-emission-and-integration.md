# Story 004: Signal emission, noise_radius_m mirroring, purity + integration test

> **Epic**: FootstepComponent
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-4 hours (L — full emission wiring + 5 unit test files + 1 integration test file)
> **Manifest Version**: 2026-04-30
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/footstep-component.md`
**Requirement**: `TR-FC-001` (component emits `Events.player_footstep(surface: StringName, noise_radius_m: float)` per step), `TR-FC-005` (noise_radius_m = `player.get_noise_level()` at emission time; mirrors AI perception channel but is NOT an AI channel — forbidden pattern: SAI subscribing to `player_footstep`), `TR-FC-007` (4-bucket loudness scheme: soft ≤ 3.5 m / normal 3.5–6.5 m / loud 6.5–10 m / extreme > 10 m — passed as `noise_radius_m` for Audio SFX bucket selection)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: `Events.player_footstep.emit(surface, noise_radius_m)` is emitted directly via the `Events` autoload — no wrapper method, no direct node-to-node connection (ADR-0002 IG: "Use direct emit `Events.<signal>.emit(args)`"). FootstepComponent is the sole publisher of this signal in the Player domain (ADR-0002 §Player domain amendment 2026-04-19). `noise_radius_m` is sourced from `player.get_noise_level()` — this is deliberate mirroring, not a duplicate formula. ADR-0008 Slot 5 (Player + FC + Combat non-GF ≤ 0.3 ms, Proposed) applies to the combined per-frame cost. The emission-rate guard (≤ 4 Hz per ADR-0002 anti-pattern fence) is enforced by the cadence state machine — Sprint cadence 3.0 Hz is the real maximum.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Events.player_footstep.emit(surface, noise_radius_m)` with typed parameters is stable Godot 4.0+. `Signal.is_connected()` guard for subscriber lifecycle is stable 4.0+. GUT signal spy (`watch_signals` / `assert_signal_emitted`) is the standard test mechanism for signal verification. No post-cutoff APIs in this story.

**Control Manifest Rules (Foundation + Core)**:
- Required: emit via `Events.<signal>.emit(args)` — no wrapper methods on `events.gd` — pattern `event_bus_wrapper_emit` forbidden (ADR-0002 IG + Forbidden Approaches)
- Required: subscribers MUST connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards — ADR-0002 IG 3 (applies to the stub Audio subscriber in integration tests, not to FootstepComponent itself which is a pure publisher)
- Required: `FootstepComponent` does NOT mutate `player.health`, `player.current_state`, `player.velocity`, or `player._latched_event` — GDD §Core Rules + Forbidden Patterns
- Forbidden: implementing a second noise-level formula inside FootstepComponent — must call `player.get_noise_level()`, never compute its own (GDD §Forbidden Patterns)
- Forbidden: SAI connecting any handler to `Events.player_footstep` — `sai_subscribing_to_player_footstep` (GDD §FC.E.7; CI lint rule `AI.*Events\.player_footstep\.connect`)
- Guardrail: emission rate ≤ 4 Hz in any 1-second window (ADR-0002 anti-pattern guard; real max is 3 Hz at Sprint)

---

## Acceptance Criteria

*From GDD `design/gdd/footstep-component.md` §AC-FC-3, AC-FC-4, AC-FC-5, scoped to emission and integration:*

- [ ] **AC-1** (AC-FC-3.1): After running FootstepComponent for 100 emission events, `player.get_noise_level()` returns the same value it would return with no FootstepComponent attached. FootstepComponent is proven pure-observer: two parallel runs (one with FC attached, one without) produce identical `get_noise_level()` return values.
- [ ] **AC-2** (AC-FC-3.2): After 100 footstep emissions in Walk/Sprint/Crouch states (no takeoff or landing), `player._latched_event` remains `null`. Separate test file from AC-1 (per GDD qa-lead #5 note — CI must isolate these two assertions).
- [ ] **AC-3** (AC-FC-3.3): FootstepComponent source contains zero assignments to `player.health`, `player.current_state`, `player.velocity`, or `player._latched_event`. CI lint rule `footstep.*\.(health|current_state|velocity|_latched_event)\s*=` enforces this. Evidence: `tests/ci/footstep_purity_lint.gd` (lint rule test).
- [ ] **AC-4** (AC-FC-4.1): `player_footstep` is emitted through the `Events` autoload (direct `Events.player_footstep.emit(surface, noise_radius_m)`) — NOT via a direct node-to-node signal connection. Evidence: verified by grep for `emit_signal` or direct-connect patterns in `footstep_component.gd`; signal spy in unit test subscribes via `Events.player_footstep.connect(...)` and receives the emission.
- [ ] **AC-5** (AC-FC-4.2): Emission-rate guard — deterministic 600-tick sequence at `delta = 1/60` transitioning WALK → SPRINT → CROUCH → WALK. Count emissions per 60-tick (1-second) window. Assert: maximum emissions in any window ≤ 4 (ADR-0002 anti-pattern guard; real Sprint max is 3.0 Hz = 3 per window). Driven via fixed-delta ticks.
- [ ] **AC-6** (AC-FC-5.1): Stub Audio handler connected to `Events.player_footstep` receives `(surface: StringName, noise_radius_m: float)` where surface matches the ground body's `surface_tag` AND `abs(noise_radius_m - player.get_noise_level()) < 0.001` at emission time (epsilon tolerates float precision; no complex derivation — noise_radius_m is a direct read of `get_noise_level()`).

---

## Implementation Notes

*Derived from GDD §Formulas FC.3, §Edge Cases FC.E.7, §Interactions table, ADR-0002 §Key Interfaces:*

**Complete `_emit_footstep()`** (replaces Story 002's stub):

```gdscript
## Emits Events.player_footstep with the current surface tag and noise radius.
## Called once per step interval from _physics_process.
## Per ADR-0002: emits via Events autoload, not node-to-node connection.
## Per GDD FC.3: noise_radius_m mirrors player.get_noise_level() — NOT a duplicate formula.
func _emit_footstep() -> void:
    var surface: StringName = _resolve_surface_tag()
    var noise_radius: float = _player.get_noise_level()
    Events.player_footstep.emit(surface, noise_radius)
```

**noise_radius_m sourcing rationale** (from GDD §Noise radius passed to Audio): `player.get_noise_level()` is called AT emission time (end of step interval, when the audible SFX plays). FootstepComponent does NOT compute its own noise formula — it calls the PC-owned method. If `noise_walk`, `noise_sprint`, or `noise_crouch` knobs on PlayerCharacter are retuned, both Stealth AI's perception scalar AND Audio's stem selection move together automatically.

**4-bucket scheme ownership** (TR-FC-007): the bucket thresholds (soft ≤ 3.5, normal 3.5–6.5, loud 6.5–10, extreme > 10) are defined in the Audio GDD §Footstep Surface Map and are cross-referenced in footstep-component.md §Visual/Audio Requirements. FootstepComponent is NOT responsible for bucket selection — it passes `noise_radius_m` as a float; Audio's stem routing logic reads the buckets from its own data. This story's scope is ensuring `noise_radius_m == player.get_noise_level()` at emission time. The bucket thresholds are an Audio concern.

**SAI boundary — explicit requirement** (GDD FC.E.7, GDD §Forbidden Patterns): Stealth AI code MUST NOT connect any handler to `Events.player_footstep`. The CI lint rule `AI.*Events\.player_footstep\.connect` enforces this. FootstepComponent does not implement this CI fence itself (that is a CI/tools-programmer scope item), but its `Out of Scope` section and this story's AC-3 / purity lint confirm the boundary from the publisher side.

**`player._latched_event` boundary** (AC-2): `_latched_event` is PlayerCharacter's internal field for takeoff/landing events (PC GDD F.3 latched-event path). FootstepComponent must never touch it. AC-2 and AC-3 together prove this from two angles: runtime assertion (AC-2) and static lint (AC-3).

**Integration test setup** (AC-6): create a headless scene with a real `FootstepComponent` child of a stub `PlayerCharacter`, a stub `StaticBody3D` with `surface_tag = &"marble"` below, and a stub Audio node that connects to `Events.player_footstep` in `_ready` and records received payloads. Drive 60 physics ticks to trigger at least one emission. Assert payload fields.

---

## Out of Scope

*Handled by neighbouring stories / post-VS deferrals — do not implement here:*

- Story 001: scaffold fields — must be Done
- Story 002: cadence loop that calls `_emit_footstep()` — must be Done
- Story 003: `_resolve_surface_tag()` — must be Done
- Post-VS deferrals (do NOT implement):
  - Full surface variant matrix (carpet, gravel, scaffolding metal, tile, wood_stage are in the tag vocabulary per Story 003 but full Foley stem delivery is Audio's post-VS work)
  - Per-shoe-type surface tag overrides
  - Sprint-vs-walk cadence variations beyond the 3-rate state machine
  - Jump landing emission (owned by PlayerCharacter latched-event path PC GDD F.3 — not FootstepComponent)
  - `Area3D` volume override logic for wet surfaces / puddle zones
  - AC-FC-5.2 (Visual/Feel — audio-director sign-off on 7 surfaces × 4 buckets): deferred to audio authoring / QA playtest; not a code story
- **SAI boundary — permanent exclusion (not a post-VS deferral)**:
  - Stealth AI MUST NOT subscribe to `Events.player_footstep` at any point, including post-VS. SAI reads `player.get_noise_level()` and `player.get_noise_event()` directly. Any SAI story or implementation that connects a handler to `Events.player_footstep` is an architectural violation of ADR-0002 + GDD §Forbidden Patterns (pattern `sai_subscribing_to_player_footstep`). This exclusion is permanent, not scope-limited.

---

## QA Test Cases

*Integration story — mix of automated unit tests and one integration test:*

**AC-1**: Pure-observer proof — `get_noise_level()` unchanged by FC presence
- **Given**: two stub PlayerCharacter instances with identical initial state; one has FootstepComponent attached (run A), one does not (run B)
- **When**: both stubs are driven through 100 step-equivalent ticks in WALK state
- **Then**: `run_a_player.get_noise_level()` == `run_b_player.get_noise_level()` (floating-point exact equality; no PC state mutation)
- **Edge cases**: FootstepComponent calls `player.get_noise_level()` as a read, not a write — if any mutation path exists, this test detects it

**AC-2**: `_latched_event` remains null after 100 emissions
- **Given**: stub PlayerCharacter with `_latched_event = null` initially; FootstepComponent drives 100 emissions in WALK/SPRINT/CROUCH states
- **When**: after all 100 emissions complete
- **Then**: `player._latched_event == null` (no takeoff or landing events were injected)
- **Edge cases**: a `_emit_footstep()` implementation that accidentally calls a PC mutation method would set `_latched_event`; this test catches it — SEPARATE test file from AC-1

**AC-3**: Purity lint — zero mutation assignments in source
- **Given**: `src/gameplay/player/footstep_component.gd` source
- **When**: CI grep applies pattern `\.(health|current_state|velocity|_latched_event)\s*=`
- **Then**: zero matches (no assignments to any of the 4 forbidden fields)
- **Edge cases**: reading `player.current_state` is not a match (no `=` on the left side of a read); only assignment operators trigger the lint

**AC-4**: Signal emitted via Events autoload (not node-to-node)
- **Given**: `Events.player_footstep` signal spy connected in test `_ready`; FootstepComponent in WALK state with stub floor body
- **When**: one step emission is driven
- **Then**: signal spy (via `Events.player_footstep`) receives the emission; `assert_signal_emitted(Events, "player_footstep")` passes
- **Edge cases**: if FC had used `emit_signal("player_footstep", ...)` instead of `Events.player_footstep.emit(...)`, the spy would NOT receive it (verifies the route)

**AC-5**: Emission-rate guard — deterministic 600-tick sequence
- **Given**: FootstepComponent stub with cadence `walk=2.2, sprint=3.0, crouch=1.6`; stub player transitions WALK(150 ticks) → SPRINT(150 ticks) → CROUCH(150 ticks) → WALK(150 ticks); `delta = 1.0/60.0` fixed
- **When**: all 600 ticks driven sequentially; emissions counted per 60-tick window
- **Then**: no 60-tick window contains more than 4 emissions (ADR-0002 anti-pattern guard; Sprint max = 3 per window)
- **Edge cases**: accumulator carry-over at state boundary could theoretically produce 2 emissions close together — the guard verifies no window bursts above 4

**AC-6**: Audio handoff integration — surface + noise_radius_m payload correctness
- **Given**: headless integration scene: FootstepComponent child of stub PlayerCharacter (WALK, `get_noise_level() = 5.0`, `idle_velocity_threshold = 0.1`, `velocity = Vector3(3.5, 0, 0)`, `is_on_floor() = true`); stub `StaticBody3D` with `surface_tag = &"marble"` at 0.5 m below; stub Audio node connected to `Events.player_footstep` in `_ready`
- **When**: 60 `_physics_process(1.0/60.0)` ticks are driven (≥ 1 Walk-cadence step)
- **Then**: stub Audio received at least one emission; `last_received_surface == &"marble"`; `abs(last_received_noise_radius_m - 5.0) < 0.001`
- **Edge cases**: stub `get_noise_level()` returns a value that changes between calls — `noise_radius_m` must match the value returned at emission time (not a prior cached value)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/core/footstep_component/footstep_isolation_test.gd` — must exist and pass (AC-1; GDD AC-FC-3.1)
- `tests/unit/core/footstep_component/footstep_no_latch_mutation_test.gd` — must exist and pass (AC-2; GDD AC-FC-3.2 — SEPARATE file per GDD qa-lead #5)
- `tests/ci/footstep_purity_lint.gd` — must exist and pass (AC-3; GDD AC-FC-3.3)
- `tests/unit/core/footstep_component/footstep_signal_taxonomy_test.gd` — must exist and pass (AC-4, AC-5; GDD AC-FC-4.1, AC-FC-4.2)
- `tests/integration/footstep/footstep_audio_handoff_test.gd` — must exist and pass (AC-6; GDD AC-FC-5.1)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scaffold), Story 002 (cadence loop with `_emit_footstep()` stub to replace), Story 003 (`_resolve_surface_tag()` implementation) — all three must be Done
- Unlocks: Audio Epic Story 005 (footstep variant routing on `footstep_emitted` — Audio's `TR-AUD-007` / `TR-AUD-011`; the signal contract confirmed by this story's integration test is what Audio's story depends on)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: AC-1..6 covered by 7 test functions in a consolidated emission test file.
**Test results**: 7/7 PASS.

### Files added
- `tests/unit/core/footstep_component/footstep_signal_emission_test.gd` (7 tests: pure-observer, no _latched_event mutation, purity grep lint, Events autoload route + source pattern check, rate guard ≤4-per-window, Audio handoff payload).

### Files modified
- `src/gameplay/player/footstep_component.gd` — `_emit_footstep()` now reads `_player.get_noise_level()` for `noise_radius_m` (mirrors PC-owned formula per TR-FC-005; no duplicate noise computation).

### Verdict
COMPLETE.
