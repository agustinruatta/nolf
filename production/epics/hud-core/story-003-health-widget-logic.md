# Story 003: Health widget logic (damage flash, critical-state edge trigger, Tween.kill on context-leave)

> **Epic**: HUD Core
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3–4 hours (M — three interacting state machines: flash gate, critical-edge, Tween kill)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-core.md`
**Requirement**: TR-HUD-009, TR-HUD-012, TR-HUD-014
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus — subscriber handler logic) + ADR-0004 (UI Framework — `add_theme_color_override`, no polling) + ADR-0008 (Performance Budget — Slot 7 = 0.3 ms cap)

**ADR Decision Summary**: The health widget subscribes to `player_health_changed` and `player_damaged` (both wired in Story 002). This story fills in the handler logic for both stubs. Three mechanics interlock:

1. **Damage flash (CR-7 / CR-7b)**: `player_damaged` triggers a 1-frame `Color.WHITE` override on the health numeral Label via `add_theme_color_override(&"font_color", Color.WHITE)`. Photosensitivity rate-gate: a child `_flash_timer` (Timer, `one_shot = true`, `wait_time = 0.333`) limits flashes to 3 Hz (WCAG 2.3.1 ceiling). If the timer is running, the hit sets `_pending_flash = true`; on `_flash_timer.timeout`, if `_pending_flash` is true a single deferred flash fires and the timer restarts. The 1-frame "wait" is implemented via `await get_tree().process_frame` followed by a revert to `_current_health_color` (captured before the await to avoid a critical-threshold race condition).

2. **Critical-state edge trigger (CR-5 / CR-6)**: `player_health_changed(current, max_health)` computes `health_ratio = float(current) / float(max_health)` and compares against `player_critical_health_threshold_pct = 25` (registry constant; render as `0.25` ratio). On crossing below: `_was_critical` flips `false → true`, numeral colour swaps Parchment `#F2E8C8` → Alarm Orange `#E85D2A` via `add_theme_color_override`. On crossing back above: `_was_critical` flips `true → false`, colour reverts immediately. Re-entrant calls while already critical or already non-critical are no-ops (edge-triggered, not level-triggered).

3. **Tween.kill on context-leave (CR-22)**: `_on_ui_context_changed(new_ctx, old_ctx)` kills `_damage_flash_tween` (if any) and `_dry_fire_flash_tween` (if any) when `new_ctx != InputContext.Context.GAMEPLAY`. Tweens do NOT resume on context restore; the next signal emission starts a fresh flash.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `add_theme_color_override(&"font_color", Color.WHITE)` is stable since Godot 4.0. `await get_tree().process_frame` suspends until the next rendered frame — verified in GDD §C.4 pseudocode. `Tween.kill()` terminates a running Tween and frees it (Godot 4.x new-style Tween) — call this on the Tween reference, not on the node; confirmed by ADR-0004 context (implementation notes on CR-22). `Timer.is_stopped()` is stable. Setting `visible = false` on a Control does NOT stop running Tweens attached to that Control in Godot 4.6 — this is the exact reason CR-22 mandates explicit `Tween.kill()` calls.

> "Tween.kill() behaviour on hidden Controls has changed across 4.x versions — verify against engine-reference before assuming kill vs pause semantics in Godot 4.6."

**Control Manifest Rules (Presentation)**:
- Required: `add_theme_color_override(&"font_color", ...)` — use StringName literal (`&"font_color"`), not bare String
- Required: capture `_current_health_color` before `await get_tree().process_frame` to handle the critical-threshold race (if `player_health_changed` fires during the 1-frame await, the revert reads stale colour)
- Required: `Tween.kill()` on every active widget Tween in `_on_ui_context_changed` when `new_ctx != GAMEPLAY` (CR-22)
- Required: `is_instance_valid(node)` guard before any Node-typed payload dereference (ADR-0002 §IG4)
- Forbidden: `_process` for flash timing — use Timer child nodes exclusively (CR-7b)
- Forbidden: `SceneTreeTimer` allocation per damage event — `_flash_timer` child node is the rate-gate (CR-7b)
- Guardrail: Slot 7 = 0.3 ms cap — `_on_health_changed` and `_on_player_damaged` together must not exceed their share; verified in Story 006

---

## Acceptance Criteria

*From GDD `design/gdd/hud-core.md` §C.1 CR-5 through CR-9, CR-22, §F.1, and TR-HUD-009/012/014:*

- [ ] **AC-1** (TR-HUD-009, CR-7): GIVEN a `player_damaged` signal fires, WHEN the `_flash_timer` is stopped (gate open), THEN the health numeral Label receives `add_theme_color_override(&"font_color", Color.WHITE)` for exactly 1 frame (via `await get_tree().process_frame`), then reverts to `_current_health_color` (the colour that was active at flash-start, pre-captured, to handle a simultaneous critical-threshold crossing).

- [ ] **AC-2** (TR-HUD-009, CR-7 rate-gate): GIVEN a second `player_damaged` fires while `_flash_timer` is running (within 333 ms of the previous flash), THEN no immediate flash occurs — `_pending_flash` is set to `true`. WHEN `_flash_timer.timeout` fires and `_pending_flash == true`, THEN one deferred flash fires, `_flash_timer.start()` is called again, and `_pending_flash` is reset to `false`. Verified by firing 10 `player_damaged` signals in a 1-second window and asserting ≤ 3 flashes (3 Hz maximum).

- [ ] **AC-3** (TR-HUD-009, photosensitivity opt-out): GIVEN `Settings.setting_changed("accessibility", "hud_damage_flash_enabled", false)` has been received by the handler, WHEN `player_damaged` fires, THEN no colour override is applied (flash is suppressed); the numeral value still updates on subsequent `player_health_changed`. The rate-gate `_flash_timer` still runs to prevent the pending-flash latch from accumulating during the suppressed window.

- [ ] **AC-4** (TR-HUD-012, CR-5): GIVEN `player_health_changed(current, max_health)` fires where `float(current) / float(max_health) < 0.25`, WHEN `_was_critical` was previously `false`, THEN `_was_critical` is set to `true` AND the numeral Label receives `add_theme_color_override(&"font_color", Color(0.910, 0.365, 0.165, 1.0))` (Alarm Orange `#E85D2A`) on that same frame. No Tween; this is an instantaneous categorical swap.

- [ ] **AC-5** (TR-HUD-012, CR-5 level-triggered guard): GIVEN `player_health_changed` fires repeatedly while `float(current) / float(max_health) < 0.25` (already critical), THEN `add_theme_color_override` is NOT re-called on each emission — the critical colour is already applied and the edge guard prevents redundant overrides.

- [ ] **AC-6** (TR-HUD-012, CR-6): GIVEN `player_health_changed(current, max_health)` fires where `float(current) / float(max_health) >= 0.25`, WHEN `_was_critical` was previously `true`, THEN `_was_critical` is set to `false` AND the numeral Label reverts to Parchment `#F2E8C8` immediately on that frame (no hysteresis, no debounce).

- [ ] **AC-7** (TR-HUD-012, flash-during-critical race): GIVEN a damage flash is in progress (within the 1-frame await), WHEN `player_health_changed` fires with a critical-threshold crossing before the await completes, THEN: (a) the flash revert applies `_current_health_color` which was captured as Parchment before the await, NOT Alarm Orange; (b) the critical colour swap from the threshold-crossing handler fires independently via `_on_health_changed`; (c) final displayed colour is Alarm Orange. The two code paths do not interfere because each reads its own captured colour at function-entry time.

- [ ] **AC-8** (TR-HUD-014, CR-22): GIVEN a damage flash is in progress AND `Events.ui_context_changed(Context.MENU, Context.GAMEPLAY)` fires (leaving GAMEPLAY), WHEN `_on_ui_context_changed` runs, THEN `_damage_flash_tween.kill()` is called (if `_damage_flash_tween != null`), and `_dry_fire_flash_tween.kill()` is called (if `_dry_fire_flash_tween != null`). The health numeral's colour override is not reverted by the kill — the HUD is hidden (`visible = false`). On returning to GAMEPLAY, no flash resumes; the next `player_damaged` event starts a fresh flash from scratch.

- [ ] **AC-9** (all): Manual walkthrough — launch Plaza VS scene; take damage; observe: (a) health numeral flashes white for 1 frame then returns to Parchment or Alarm Orange as appropriate; (b) at <25% HP the numeral colour is Alarm Orange; (c) recovering above 25% reverts to Parchment immediately. Screenshot to `production/qa/evidence/hud_core/screenshot_health_widget_<date>.png`.

---

## Implementation Notes

*Derived from GDD §C.1 CR-5/CR-6/CR-7/CR-7b/CR-22, §C.4 pseudocode, §F.1:*

**New cached variables added to `hud_core.gd` by this story:**

```gdscript
# Health widget state
var _current_health: int = 0
var _max_health: int = 100
var _was_critical: bool = false
var _current_health_color: Color = Color(0.949, 0.910, 0.784, 1.0)  # Parchment #F2E8C8

# Flash gate state (mirrors CR-7 / CR-7b)
var _pending_flash: bool = false
var _flash_suppressed: bool = false  # set by Settings "hud_damage_flash_enabled" = false

# Tween references for CR-22 kill-on-context-leave
var _damage_flash_tween: Tween = null
var _dry_fire_flash_tween: Tween = null
```

**`_on_health_changed(current: int, max_health: int)` handler logic:**

```gdscript
func _on_health_changed(current: int, max_health: int) -> void:
    _current_health = current
    _max_health = max_health
    _health_numeral_label.text = str(current)  # via tr() wrapping at _ready(); numeric str() is acceptable
    var ratio: float = float(current) / float(max_health) if max_health > 0 else 0.0
    var is_critical: bool = ratio < PLAYER_CRITICAL_HEALTH_THRESHOLD  # const 0.25
    if is_critical and not _was_critical:
        _was_critical = true
        _current_health_color = Color(0.910, 0.365, 0.165, 1.0)  # Alarm Orange
        _health_numeral_label.add_theme_color_override(&"font_color", _current_health_color)
    elif not is_critical and _was_critical:
        _was_critical = false
        _current_health_color = Color(0.949, 0.910, 0.784, 1.0)  # Parchment
        _health_numeral_label.add_theme_color_override(&"font_color", _current_health_color)
```

**`_on_player_damaged(amount: float, source: Node, is_critical: bool)` handler logic (rate-gate):**

```gdscript
func _on_player_damaged(_amount: float, _source: Node, _is_crit: bool) -> void:
    if _flash_suppressed:
        return
    if _flash_timer.is_stopped():
        _fire_damage_flash()
        _flash_timer.start()
    else:
        _pending_flash = true

func _fire_damage_flash() -> void:
    var pre_flash_color: Color = _current_health_color  # capture before await
    _health_numeral_label.add_theme_color_override(&"font_color", Color.WHITE)
    await get_tree().process_frame
    # Guard: if node freed during await (e.g., scene reload mid-frame)
    if not is_instance_valid(self):
        return
    _health_numeral_label.add_theme_color_override(&"font_color", pre_flash_color)

func _on_flash_timer_timeout() -> void:
    if _pending_flash:
        _pending_flash = false
        _fire_damage_flash()
        _flash_timer.start()
```

**Tween references note**: This story introduces `_damage_flash_tween` and `_dry_fire_flash_tween` as `null` placeholders. Story 002 already provisions the Timer child nodes (`_flash_timer`, `_dry_fire_timer`). The actual Tween usage (for the critical-health pulse, owned by HSS/Story 005) is forwarded to the correct story. For this story, the `Tween.kill()` in `_on_ui_context_changed` guards `!= null` before calling kill, making it safe to call even before Tweens are assigned.

**`_on_ui_context_changed(new_ctx: InputContext.Context, old_ctx: InputContext.Context)`** — this handler stub was established in Story 002. This story adds the Tween-kill block to it:

```gdscript
func _on_ui_context_changed(new_ctx: InputContext.Context, _old_ctx: InputContext.Context) -> void:
    visible = (new_ctx == InputContext.Context.GAMEPLAY)
    if new_ctx != InputContext.Context.GAMEPLAY:
        if _damage_flash_tween != null:
            _damage_flash_tween.kill()
            _damage_flash_tween = null
        if _dry_fire_flash_tween != null:
            _dry_fire_flash_tween.kill()
            _dry_fire_flash_tween = null
        # Gadget reject tween is killed in Story 005
```

**`player_critical_health_threshold` constant**: declared as `const PLAYER_CRITICAL_HEALTH_THRESHOLD: float = 0.25` in `hud_core.gd`. This value originates from the GDD registry constant (25%). If the PC GDD ever exposes a `pc.critical_threshold` property, this const should migrate to read from it; for now, it is the agreed-upon design value.

**`_health_numeral_label` node reference**: declared as `@onready var _health_numeral_label: Label = $WidgetRoot/HealthWidget/HBoxContainer/HealthNumeral` (exact path TBD by Story 001's scene structure; the label node is the right-side numeral within the BL `HBoxContainer`).

**Dry-fire flash (CR-8)**: The dry-fire flash path (`_on_ammo_changed` unchanged-value detection) uses a separate `_dry_fire_timer` and `_pending_dry_fire` latch, mirroring the damage-flash gate. This story provisions the `_dry_fire_flash_tween` kill in `_on_ui_context_changed`, but the full dry-fire detection logic is deferred to the Ammo Widget story (post-VS). For now, `_on_ammo_changed` stub updates the cached `_last_ammo_*` values only.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Scene scaffold (health Label node references must exist)
- **Story 002**: Signal connection plumbing (`_on_health_changed` and `_on_player_damaged` connect calls)
- **Story 004**: Prompt-strip state machine and `_process` resolver
- **Story 005**: Settings live-update wiring for `hud_damage_flash_enabled` dispatch; critical-health Tween pulse (HSS-tier feature, deferred); full `_on_ui_context_changed` including gadget tile Tween kill
- Post-VS deferrals: Dry-fire flash full detection logic (ammo widget story); ammo widget numeral display; gadget tile logic

---

## QA Test Cases

**AC-1 — Single damage flash (gate open)**
- Given: `_flash_timer.is_stopped() == true`; health numeral showing Parchment; `_flash_suppressed = false`
- When: `Events.player_damaged.emit(10.0, null, false)` fires
- Then: health numeral colour immediately overrides to `Color.WHITE`; 1 process frame later reverts to Parchment (or Alarm Orange if critical threshold was crossed by simultaneous `player_health_changed`)
- Edge cases: `max_health = 0` → health ratio guard prevents division-by-zero; ratio treated as `0.0` (critical)

**AC-2 — Rate-gate coalescing (gate closed)**
- Given: `_flash_timer.is_stopped() == false` (timer running from a prior flash)
- When: `Events.player_damaged.emit(5.0, null, false)` fires
- Then: `_pending_flash = true`; no immediate colour override
- When: `_flash_timer.timeout` fires and `_pending_flash == true`
- Then: one deferred flash executes; `_flash_timer.start()` called; `_pending_flash = false`
- Automated verification: emit 10 `player_damaged` signals within 1 s; assert flash count ≤ 3 via `_flash_count` counter incremented in `_fire_damage_flash`

**AC-3 — Photosensitivity suppression**
- Given: `_flash_suppressed = true` (simulating `setting_changed` handler setting the flag)
- When: `Events.player_damaged.emit(10.0, null, false)` fires
- Then: no colour override applied; `_flash_timer` not started; `_pending_flash` unchanged
- Edge cases: re-enable suppression mid-timer (`_flash_suppressed = false`) → next `player_damaged` starts fresh gate

**AC-4 — Critical threshold entry (edge trigger)**
- Given: `_was_critical = false`; `_current_health = 50`; `_max_health = 100`
- When: `Events.player_health_changed.emit(24, 100)` fires (ratio 0.24 < 0.25)
- Then: `_was_critical = true`; numeral colour = Alarm Orange `#E85D2A`; only ONE `add_theme_color_override` call
- Edge cases: `emit(25, 100)` (ratio = 0.25, boundary) → NOT critical (`< 0.25` strict); colour stays Parchment

**AC-5 — No re-override while already critical**
- Given: `_was_critical = true` (already critical); numeral showing Alarm Orange
- When: `Events.player_health_changed.emit(20, 100)` fires (still < 0.25)
- Then: `add_theme_color_override` is NOT called again; `_was_critical` remains `true`
- Automated: spy on `add_theme_color_override` call count; assert 0 calls for this emission

**AC-6 — Critical threshold exit (immediate revert)**
- Given: `_was_critical = true`; numeral showing Alarm Orange
- When: `Events.player_health_changed.emit(26, 100)` fires (ratio 0.26 > 0.25)
- Then: `_was_critical = false`; numeral colour = Parchment `#F2E8C8`; immediate, no Tween

**AC-7 — Flash-during-critical-crossing race**
- Given: flash in progress (within `await get_tree().process_frame`); `_current_health_color` captured as Parchment before await; THEN `player_health_changed(24, 100)` fires (critical crossing, sets Alarm Orange via `_on_health_changed`)
- When: flash revert fires after the await
- Then: revert applies the pre-captured Parchment (`pre_flash_color`), NOT the Alarm Orange that was set by `_on_health_changed` during the await — a race condition where revert would incorrectly overwrite Alarm Orange. The SEPARATE `_on_health_changed` call then immediately sets Alarm Orange. Final result: Alarm Orange. The two handlers are independent; no shared mutable state accessed by both during the await.

**AC-8 — Tween.kill on context-leave**
- Given: `_damage_flash_tween` is a live `Tween` reference (not null)
- When: `Events.ui_context_changed.emit(InputContext.Context.MENU, InputContext.Context.GAMEPLAY)` fires
- Then: `_damage_flash_tween.kill()` is called; `_damage_flash_tween` set to `null`; `visible = false` on HUD root; no subsequent colour override callbacks fire

**AC-9 — Visual walkthrough**
- Given: Plaza VS scene running; health = 100
- When: take a hit (damage event)
- Then: screenshot shows 1-frame white flash on health numeral; numeral reverts to Parchment
- When: health drops below 25%
- Then: screenshot shows numeral in Alarm Orange; no flash or animation — instant swap
- Pass condition: screenshot captured to `production/qa/evidence/hud_core/screenshot_health_widget_<date>.png`; solo developer sign-off

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/hud_core/test_health_widget_logic.gd` — GUT tests for AC-1 through AC-8; must exist and pass; deterministic (fixed timer stubs, no real process frames)
- `tests/unit/presentation/hud_core/test_forbidden_patterns.gd` — extended with AC: no `SceneTreeTimer` allocation in `_on_player_damaged` (grep `SceneTreeTimer` in `src/ui/hud_core/hud_core.gd` → zero matches)
- `production/qa/evidence/hud_core/screenshot_health_widget_<date>.png` — manual walkthrough evidence (AC-9)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (health Label node references required); Story 002 DONE (signal subscriptions plumbed)
- Unlocks: Story 005 (settings live-update wiring needs `_flash_suppressed` variable declared here; critical-health Tween pulse from HSS builds on `_was_critical` state); Story 006 (Plaza VS smoke test validates this story's visual output)

## Open Questions

- **OQ-HUD-2 (advisory)**: If context changes to GAMEPLAY while `_pending_flash` is queued, should the flash fire immediately on context-restore? Current implementation: flash fires on `_flash_timer.timeout` (correct diegetic behaviour — the hit landed while the HUD was hidden, the body catches up). Confirm post-VS playtest.
- **`player_damaged` signal signature**: GDD §C.1 CR-7 references `player_damaged(amount, source, is_critical)`. Verify the exact parameter types against the ADR-0002 taxonomy before implementation: `amount` may be `float` or `int`; `source` may be `Node` or `Node3D`. If `source` is `Node`-typed, `is_instance_valid(source)` guard is required per ADR-0002 §IG4 even though `_on_player_damaged` does not dereference `source` in this story.
