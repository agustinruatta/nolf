# Story 003: Sepia dim tween state machine (IDLE/FADING_IN/ACTIVE/FADING_OUT)

> **Epic**: Post-Process Stack
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 hours (M — state machine + tween logic + 5 unit-testable acceptance criteria covering transitions + edge cases)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/post-process-stack.md`
**Requirement**: TR-PP-002, TR-PP-003
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (FPS Hands Outline Rendering) — chain ordering context; ADR-0008 (Performance Budget Distribution) — sepia pass cost when active
**ADR Decision Summary**: ADR-0005 established that the sepia dim pass reads the post-outline color buffer; the state machine's `IDLE` state must ensure the pass is bypassed at zero cost. ADR-0008 Slot 3 notes the sepia pass costs ~0.3 ms at 1080p when ACTIVE — the bypass (IDLE) should contribute 0 ms. The tween uses 0.5 s ease-in/out (GDD Formula 2, `x * x * (3 - 2 * x)` smoothstep).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Tween` + `create_tween()` + `tween_property()` are stable Godot 4.0+. The GDD specifies `Tween` as the implementation mechanism (GDD Core Rule 2, Detailed Design §States and Transitions). Godot 4.6 `Tween` kill and restart semantics are unchanged from 4.0. The `ease_in_out` curve is implemented as `Tween.EASE_IN_OUT` with `Tween.TRANS_SINE` or via the smoothstep formula directly (GDD Formula 2 specifies the `x * x * (3 - 2 * x)` smoothstep — use `Tween.TRANS_SINE` which approximates this, OR implement a custom `method_interval` tween with the formula directly; the GDD's formula is the target, not the Tween constant). No post-cutoff Tween API changes affect this story.

**Control Manifest Rules (Foundation)**:
- Required: `PostProcessStack` is a service that owns its domain; it does NOT hold references to other systems (GDD Core Rule 5 — not a service locator)
- Required: static typing required on all GDScript vars and functions; every public method has a doc comment
- Forbidden: sepia dim must never be active by default (`sepia_dim_as_default_on` anti-pattern — GDD Core Rule 2)
- Forbidden: no new public methods may query or act on other systems from `PostProcessStack` — pattern `pps_publishing_signals` (GDD §Anti-patterns)
- Guardrail: sepia pass ≤0.5 ms at 1080p RTX 2060 when ACTIVE; 0 ms contribution when IDLE (ADR-0008 Slot 3, TR-PP-009)

---

## Acceptance Criteria

*From GDD `design/gdd/post-process-stack.md` §Acceptance Criteria AC-1 through AC-5 + §States and Transitions:*

- [ ] **AC-1**: GIVEN `PostProcessStack` autoload is loaded, WHEN `enable_sepia_dim()` is called from IDLE state, THEN `is_sepia_active` transitions to `true`, internal state is `FADING_IN`, a `Tween` begins tweening `dim_intensity` from 0.0 toward 1.0, and after 0.5 s the state is `ACTIVE` with `dim_intensity = 1.0`.
- [ ] **AC-2**: GIVEN internal state is `ACTIVE` (`dim_intensity = 1.0`), WHEN `disable_sepia_dim()` is called, THEN internal state transitions to `FADING_OUT`, `Tween` tweens `dim_intensity` from 1.0 toward 0.0, and after 0.5 s state is `IDLE` with `dim_intensity = 0.0` and `is_sepia_active = false`.
- [ ] **AC-3**: GIVEN state is `FADING_IN` at approximately t=0.2s (dim_intensity ≈ 0.35 per GDD Formula 2 smoothstep at normalized time 0.4), WHEN `disable_sepia_dim()` is called, THEN the active `Tween` is killed and a new `Tween` begins tweening from the CURRENT `dim_intensity` value (≈ 0.35) toward 0.0 — no teleport to 1.0 first (GDD §Edge Cases "reverse tween").
- [ ] **AC-4**: GIVEN state is `IDLE` (`dim_intensity = 0.0`), WHEN `disable_sepia_dim()` is called, THEN no-op — state remains `IDLE`, `dim_intensity` remains 0.0, no `Tween` fires, no error logged.
- [ ] **AC-5**: GIVEN state is `ACTIVE` (`dim_intensity = 1.0`), WHEN `enable_sepia_dim()` is called, THEN no-op — state remains `ACTIVE`, `dim_intensity` remains 1.0, no new `Tween` fires.
- [ ] **AC-6**: GIVEN state is `FADING_OUT` at approximately t=0.2s (dim_intensity ≈ 0.65), WHEN `enable_sepia_dim()` is called, THEN the active `Tween` is killed and a new `Tween` begins from the CURRENT `dim_intensity` (≈ 0.65) toward 1.0 (symmetric reverse — GDD §Transition Rules).
- [ ] **AC-7**: GIVEN the state machine at any state, WHEN `enable_sepia_dim()` is called during `FADING_IN` (already transitioning toward ACTIVE), THEN no-op — the in-flight `Tween` continues uninterrupted toward 1.0. (Only one `Tween` instance manages `dim_intensity` at a time — GDD §Transition Rules.)

---

## Implementation Notes

*Derived from GDD §Detailed Design Core Rules 2 and 5 + §States and Transitions + Formulas 1-2:*

**State machine** — add to `post_process_stack.gd` (Story 001 scaffold):

```
enum SepiaState { IDLE, FADING_IN, ACTIVE, FADING_OUT }
var _sepia_state: SepiaState = SepiaState.IDLE
var _dim_intensity: float = 0.0
var _dim_tween: Tween = null
```

**`enable_sepia_dim()` logic**:
1. If state is `IDLE`: kill any existing tween, start new tween from `_dim_intensity` (should be 0.0) to 1.0 over 0.5 s, set state `FADING_IN`, `is_sepia_active = true`.
2. If state is `FADING_OUT`: kill the current tween, start new tween from `_dim_intensity` (current intermediate value) to 1.0 over proportional duration (or fixed 0.5 s — GDD does not mandate proportional duration, fixed 0.5 s is simpler), set state `FADING_IN`.
3. If state is `FADING_IN` or `ACTIVE`: no-op.

**`disable_sepia_dim()` logic** (symmetric):
1. If state is `ACTIVE`: kill any existing tween, start new tween from 1.0 to 0.0 over 0.5 s, set state `FADING_OUT`.
2. If state is `FADING_IN`: kill current tween, start new tween from `_dim_intensity` (current intermediate) to 0.0, set state `FADING_OUT`.
3. If state is `FADING_OUT` or `IDLE`: no-op (`FADING_OUT` lets the in-flight tween finish; `IDLE` is idempotent).
4. On tween completion when state is `FADING_OUT`: set state `IDLE`, `is_sepia_active = false`.

**Tween `dim_intensity` → shader uniform**: When `_dim_intensity` changes (via the tween), call `SepiaDimEffect.set_dim_intensity(_dim_intensity)`. Use the tween's `tween_method()` targeting a `_on_dim_intensity_changed(value: float)` callback, OR use `tween_property()` on a local `@export var dim_intensity: float` and connect a `set()` custom setter that calls through to the effect.

**Tween kill safety**: Always check `if _dim_tween != null and _dim_tween.is_valid(): _dim_tween.kill()` before starting a new tween. Godot 4.6 Tweens auto-free when finished; a killed tween may already be freed. Use `is_valid()` guard.

**FADING_OUT → IDLE transition**: Use the tween's `finished` signal to detect when FADING_OUT completes: `_dim_tween.finished.connect(_on_fade_out_complete, CONNECT_ONE_SHOT)`.

**Testing with time**: Unit tests cannot wait 0.5 s real-time for tween completion. Test the state machine's transition logic by:
- Calling `enable_sepia_dim()` and asserting state is immediately `FADING_IN` and `is_sepia_active = true`
- Testing the reverse-tween edge case by checking that the new tween starts from the current `_dim_intensity` value, not from 0.0 or 1.0
- Using `Tween.set_speed_scale()` or a mock SepiaDimEffect to test without real time passage

GDD Formula 2 (ease-in/out: `x * x * (3 - 2 * x)`) is the easing curve; use `Tween.TRANS_CUBIC, Tween.EASE_IN_OUT` which produces the same shape, or validate with a custom method tween. The exact formula match is advisory; the GDD specifies the aesthetic (smoothstep), not a pixel-exact calculation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `SepiaDimEffect.set_dim_intensity()` method itself — the shader uniform update (must be DONE before this story can wire the tween to the effect)
- Story 004: Document Overlay calling `enable_sepia_dim()` / `disable_sepia_dim()` from the outside
- Story 007: Visual validation that the tween produces correct intermediate frames (dim_intensity = 0.5 screenshot comparison)

---

## QA Test Cases

**AC-1 — IDLE → FADING_IN → ACTIVE transition**
- Given: `PostProcessStack` freshly initialized (state = IDLE, dim_intensity = 0.0)
- When: `enable_sepia_dim()` is called
- Then: `is_sepia_active == true`; internal state == `FADING_IN`; a Tween is active; `_dim_intensity` begins moving from 0.0 toward 1.0
- Edge cases: calling `enable_sepia_dim()` a second time immediately → no-op (state stays FADING_IN, no second tween created); after 0.5 s simulated time → state == ACTIVE, `_dim_intensity == 1.0`

**AC-2 — ACTIVE → FADING_OUT → IDLE transition**
- Given: state == ACTIVE, `_dim_intensity == 1.0`
- When: `disable_sepia_dim()` is called
- Then: state == `FADING_OUT`; a Tween is active tweening toward 0.0; after 0.5 s simulated time → state == IDLE, `_dim_intensity == 0.0`, `is_sepia_active == false`
- Edge cases: calling `disable_sepia_dim()` again mid-fade → no-op; tween finishes → state IDLE confirmed

**AC-3 — Reverse tween from FADING_IN**
- Given: state == FADING_IN, `_dim_intensity` is approximately 0.35 (mid-fade)
- When: `disable_sepia_dim()` is called
- Then: the previous Tween is killed; a new Tween starts from the CURRENT `_dim_intensity` (≈ 0.35), NOT from 1.0 or 0.0; state == FADING_OUT
- Edge cases: `_dim_intensity` at exactly 0.0 when reversed (edge: just-started fade) → behaves like IDLE → direct to IDLE; verify no teleport at any intermediate value

**AC-4 — IDLE idempotency**
- Given: state == IDLE
- When: `disable_sepia_dim()` is called
- Then: state remains IDLE; `_dim_intensity` remains 0.0; no Tween is created; no error or warning logged

**AC-5 — ACTIVE idempotency**
- Given: state == ACTIVE, `_dim_intensity == 1.0`
- When: `enable_sepia_dim()` is called
- Then: state remains ACTIVE; `_dim_intensity` remains 1.0; no new Tween is created

**AC-6 — Reverse tween from FADING_OUT**
- Given: state == FADING_OUT, `_dim_intensity` ≈ 0.65 (mid-fade back)
- When: `enable_sepia_dim()` is called
- Then: the previous Tween is killed; a new Tween starts from the current `_dim_intensity` (≈ 0.65) toward 1.0; state == FADING_IN
- Edge cases: verify `is_sepia_active` remains `true` throughout (never set to false during a FADING_OUT→FADING_IN reversal)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/post_process_stack/sepia_dim_state_machine_test.gd` — must exist and pass
- Covers: AC-1 through AC-6 (state transitions, idempotency, reverse-tween behavior)
- Determinism: use `Tween.set_speed_scale(0)` or inject a mock SepiaDimEffect; assert state immediately after method call, not after real-time delay; verify `_dim_intensity` value at start of each tween
- Naming: `post_process_sepia_dim_state_[transition]_[expected]` per test-standards

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (SepiaDimEffect with `set_dim_intensity()` must be DONE; state machine is wired to call it)
- Unlocks: Story 004 (Document Overlay integration tests require a functional enable/disable API), Story 007 (visual verification requires the tween to produce correct intermediate frames)
