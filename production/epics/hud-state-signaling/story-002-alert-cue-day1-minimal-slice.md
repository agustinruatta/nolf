# Story 002: ALERT_CUE — Day-1 HoH/deaf minimal slice

> **Epic**: HUD State Signaling
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3-4 hours (M — rate-gate logic + AccessKit + tuning knob read + 9-AC test suite)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-state-signaling.md`
**Requirement**: TR-HSS-001 (MVP-Day-1 alert-cue mandatory for WCAG SC 1.1.1), TR-HSS-006 (all strings via `tr()`), TR-HSS-008 (CR-9 rate-gate with upward-severity exemption), TR-HSS-010 (WCAG 2.2.1 timing-adjustable mechanism BLOCKING Day-1)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: HSS subscribes to `Events.alert_state_changed(actor, old, new, severity)` (frozen 4-param signature per ADR-0002 §Key Interfaces). The ALERT_CUE state fires when `new != AlertState.UNAWARE` and the per-actor CR-9 rate-gate passes. Upward-severity transitions (e.g., SUSPICIOUS→COMBAT) bypass the cooldown regardless of elapsed time (GDD CR-9 REV-2026-04-28 — closes WCAG SC 1.1.1 / 1.3.3 violation). All visible strings flow through `tr()` (GDD CR-7); the translation key `HUD_GUARD_ALERTED` EN reference is `"GUARD ALERTED"`. AccessKit live-region is `"polite"` — never `"assertive"` (GDD CR-8, FP-HSS-5). The `_resolve_hss_state()` callback (registered in Story 001) returns ALERT_CUE text + priority when the state is active; HUD Core's `_process()` resolver mutates `_label.text`. HSS does NOT directly write `_label.text` (GDD CR-4 REV-2026-04-28).

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM (ADR-0004 Proposed)
**Engine Notes**: `Control.accessibility_description` (String property, settable) is verified as of Sprint 01 Gate 1 (ADR-0004 §Gate 1 CLOSED 2026-04-29). `accessibility_live` property name is pending Gate 5 verification for runtime AT (ADR-0004 §Status: Gate 5 deferred). Per GDD CR-8 REV-2026-04-28 and TR-HSS-009, `accessibility_*` sets use `call_deferred` by DEFAULT (deferred-AccessKit pattern — saves ~15 µs on transition frames per F.4 analysis). FP-HSS-15 CI lint for `CONNECT_DEFERRED` on signal subscriptions is separate from this deferred-AccessKit pattern — the former is forbidden; the latter is required. `Timer` node usage (`one_shot = true`, `wait_time`, `.start()`, `.stop()`, `.is_stopped()`, `.time_left`) is stable Godot 4.0+. `is_instance_valid()` for freed Node check is the canonical Godot 4.x pattern (GDD CR-9 + ADR-0002 IG 4).

> This API may have changed in Godot 4.5+ — `accessibility_live` property name: verify against `docs/engine-reference/godot/` reference before implementing; Gate 1 closed `accessibility_description` but `accessibility_live` behavioural verification is Gate 5 (runtime AT).

**Control Manifest Rules (Presentation)**:
- Required: all visible strings through `tr()` — no English literals in source (GDD CR-7, FP-HSS-7)
- Required: `accessibility_description` set on state-entry via `call_deferred` (deferred-AccessKit pattern, default at Day-1 per CR-14 REV-2026-04-28)
- Required: `accessibility_live = "polite"` — NEVER `"assertive"` for ALERT_CUE (GDD CR-8, FP-HSS-5)
- Required: per-actor `is_instance_valid` guard on rate-gate dictionary lookups (ADR-0002 IG 4)
- Forbidden: `_process` or `_physics_process` override — pattern `hss_process_polling` (GDD FP-HSS-4 + CR-5)
- Forbidden: direct `_label.text` write from HSS — ALERT_CUE text is returned via `_resolve_hss_state()` callback only; HUD Core's resolver writes `_label.text` (GDD CR-3/CR-4 REV-2026-04-28)
- Forbidden: `accessibility_live = "assertive"` anywhere in this story's code — pattern restricted to ALARM_STINGER only (GDD FP-HSS-5, VS-scope)
- Guardrail: HSS Slot 7 sub-claim ≤0.15 ms peak on state-transition frame; deferred-AccessKit saves ~15 µs; combined HUD Core + HSS must not exceed 0.3 ms (ADR-0008 Slot 7 cap; CR-14 F.4 measured worst case 296 µs after mitigation)

---

## Acceptance Criteria

*From GDD `design/gdd/hud-state-signaling.md` §Acceptance Criteria Clusters 2, 4 (Day-1), 5 (Day-1), 6, 8, and 9, scoped to this story:*

**ALERT_CUE happy path (Cluster 2)**

- [ ] **AC-HSS-2.1**: GIVEN an UNAWARE guard `G1`, no ALERT_CUE active, `_alert_cue_last_fired_per_actor` empty, WHEN `Events.alert_state_changed.emit(G1, AlertState.UNAWARE, AlertState.SUSPICIOUS, Severity.MINOR)` fires, THEN within the same physics frame: `_alert_cue_timer.time_left == alert_cue_duration_s` (default 2.0) AND `_alert_cue_timer.is_stopped() == false` AND `_alert_cue_last_fired_per_actor[G1] == game_time` AND `_resolve_hss_state()` returns `{"text": tr("HUD_GUARD_ALERTED"), "state_id": HSSState.ALERT_CUE}`. [CR-5, CR-7, CR-9, F.1, F.3]
- [ ] **AC-HSS-2.2**: GIVEN ALERT_CUE just fired for G1 at game_time `T_0`, WHEN `Events.alert_state_changed.emit(G1, AlertState.UNAWARE, AlertState.SUSPICIOUS, Severity.MINOR)` fires again at `T_0 + 0.5` s (within cooldown, same severity), THEN ALERT_CUE does NOT re-fire (Timer.time_left is unchanged from natural decrement; `_alert_cue_last_fired_per_actor[G1]` still equals `T_0`). [CR-9, F.3]
- [ ] **AC-HSS-2.3**: GIVEN ALERT_CUE last fired for G1 at `T_0`, WHEN the same signal fires at `T_0 + 1.5` s (beyond cooldown), THEN ALERT_CUE fires fresh (Timer restarted with `time_left == 2.0`; `_alert_cue_last_fired_per_actor[G1] == T_0 + 1.5`). [CR-9, F.3]
- [ ] **AC-HSS-2.4**: GIVEN ALERT_CUE active for G1, WHEN `Events.alert_state_changed.emit(G2, ...)` fires for a different guard `G2` within G1's cooldown, THEN the per-actor gate passes for G2: `_alert_cue_last_fired_per_actor[G2]` is set (per-actor, not global cooldown). [CR-9, F.3]
- [ ] **AC-HSS-2.5**: GIVEN ALERT_CUE active, WHEN `_alert_cue_timer.timeout` fires, THEN the active state clears to HIDDEN AND `_resolve_hss_state()` returns `{"text": "", "state_id": HSSState.HIDDEN}` AND `_label.accessibility_description` is cleared (via `call_deferred`). [CR-5, CR-8]
- [ ] **AC-HSS-2.6**: GIVEN any `alert_state_changed` signal, WHEN `new == AlertState.UNAWARE`, THEN ALERT_CUE does NOT fire (state-gate: only non-UNAWARE transitions trigger the cue). [§C.2 trigger row]
- [ ] **AC-HSS-2.7**: GIVEN `_alert_cue_last_fired_per_actor[G1]` is set, WHEN G1 is freed (`is_instance_valid(G1) == false`) AND any alert event fires, THEN the signal handler erases the stale entry: `_alert_cue_last_fired_per_actor.has(G1) == false` after the handler runs. [CR-9 cleanup rule, ADR-0002 IG 4]
- [ ] **AC-HSS-2.8** (WCAG SC 1.1.1 / 1.3.3 upward-severity exemption): GIVEN ALERT_CUE just fired for G1 at `T_0` with `_alert_cue_last_state_per_actor[G1] = AlertState.SUSPICIOUS`, WHEN `Events.alert_state_changed.emit(G1, AlertState.SUSPICIOUS, AlertState.COMBAT, Severity.MAJOR)` fires at `T_0 + 0.4` s (within cooldown, but upward severity), THEN ALERT_CUE fires AGAIN (cooldown bypassed): Timer restarted AND `_alert_cue_last_state_per_actor[G1] == AlertState.COMBAT`. [CR-9 REV-2026-04-28, accessibility-specialist Finding 1]
- [ ] **AC-HSS-2.9** (Timer precision): GIVEN ALERT_CUE fires at game_time `T_0` with `wait_time = 2.0`, WHEN the Timer auto-dismisses, THEN `Timer.timeout` fires within `T_0 + 2.0 ± 0.017` s (1-frame tolerance at 60 fps). [CR-5, F.1]

**Tuning knob load (Cluster 4)**

- [ ] **AC-HSS-4.1**: GIVEN the project's tuning knobs config declares `alert_cue_duration_s = 2.0`, WHEN HSS instantiates and reads the value, THEN `_alert_cue_timer.wait_time == 2.0` (±0.0005 float tolerance). [F.1, §G.1]

**AccessKit + locale (Cluster 5)**

- [ ] **AC-HSS-5.1** (locale re-resolve): GIVEN ALERT_CUE active with `_label.text == "GUARD ALERTED"` (EN), WHEN locale changes to FR, THEN `NOTIFICATION_TRANSLATION_CHANGED` fires AND HSS re-resolves `_label.accessibility_description` to `tr("HUD_GUARD_ALERTED")` in FR. Timer remaining time is unchanged. [CR-7, E.12]
- [ ] **AC-HSS-5.2** (AccessKit polite): GIVEN any ALERT_CUE state-entry, WHEN the deferred AccessKit set runs, THEN `_label.accessibility_live == "polite"` (NEVER "assertive"). [CR-8, FP-HSS-5]
- [ ] **AC-HSS-5.3** (CI grep): GIVEN HSS source files, WHEN CI grep runs `accessibility_live\s*=\s*"assertive"` against `src/ui/hud_state_signaling.gd`, THEN zero matches. [FP-HSS-5]

**ui_context kill (Cluster 6)**

- [ ] **AC-HSS-6.1**: GIVEN ALERT_CUE active (Timer.time_left == 1.0 s), WHEN `Events.ui_context_changed.emit(InputContext.Context.DOCUMENT_OVERLAY, InputContext.Context.GAMEPLAY)` fires, THEN `_alert_cue_timer.is_stopped() == true` AND active state cleared within the same physics frame. [CR-11]
- [ ] **AC-HSS-6.2**: GIVEN ui_context returns to GAMEPLAY, WHEN `new == GAMEPLAY`, THEN HSS does NOT auto-resume any prior state — the internal state machine remains HIDDEN until a fresh Events signal fires. [CR-11, §B refusal #1]

**Forbidden-pattern CI lints (Cluster 9, subset)**

- [ ] **AC-HSS-8.2**: GIVEN HSS source, WHEN CI grep runs `func _process\(` and `func _physics_process\(` against `src/ui/hud_state_signaling.gd`, THEN zero matches (FP-HSS-4 enforced). [FP-HSS-4, CR-5]
- [ ] **AC-HSS-9.1 (partial — Day-1 lints)**: GIVEN HSS source + scene tree, WHEN `tools/ci/check_forbidden_patterns_hss.sh` runs FP-HSS-1..9 panel (FP-HSS-5 assertive-whitelist, FP-HSS-4 no-process, FP-HSS-7 tr()-discipline, FP-HSS-8 no-emit, FP-HSS-3 no-scene-walk), THEN exit code 0 (all pass). FP-HSS-5 AccessKit lint deferred from CI until ADR-0004 Gate 5 closes (GDD CR-8 REV-2026-04-28). [CR-15, FP-HSS-1..9]

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines + GDD CR-5, CR-7, CR-8, CR-9, CR-11, CR-14, CR-19, F.3:*

**Rate-gate dictionary declaration** (two dicts per CR-9 REV-2026-04-28):

```gdscript
var _alert_cue_last_fired_per_actor: Dictionary[Node, float] = {}
var _alert_cue_last_state_per_actor: Dictionary[Node, StealthAI.AlertState] = {}
```

**Signal handler** — full CR-9 REV-2026-04-28 logic including upward-severity exemption:

```gdscript
func _on_alert_state_changed(
    actor: Node,
    old_state: StealthAI.AlertState,
    new_state: StealthAI.AlertState,
    severity: StealthAI.Severity
) -> void:
    if new_state == StealthAI.AlertState.UNAWARE:
        return  # CR-9 / §C.2 state-gate

    # ADR-0002 IG 4: guard freed-Node refs
    var now: float = Time.get_ticks_msec() / 1000.0
    _clean_freed_actor_refs(now)

    var last_state: StealthAI.AlertState = _alert_cue_last_state_per_actor.get(
        actor, StealthAI.AlertState.UNAWARE
    )
    var last_fired: float = _alert_cue_last_fired_per_actor.get(actor, -INF)
    var upward_severity: bool = new_state > last_state  # enum int comparison

    # CR-9 REV-2026-04-28: upward severity bypasses cooldown
    if not upward_severity and (now - last_fired) < _alert_cue_actor_cooldown_s:
        return  # suppressed — same-or-lower severity within cooldown

    # Update dicts atomically BEFORE state entry (F.3 Output Range note)
    _alert_cue_last_fired_per_actor[actor] = now
    _alert_cue_last_state_per_actor[actor] = new_state

    _enter_alert_cue_state()


func _clean_freed_actor_refs(_now: float) -> void:
    for key: Node in _alert_cue_last_fired_per_actor.keys():
        if not is_instance_valid(key):
            _alert_cue_last_fired_per_actor.erase(key)
            _alert_cue_last_state_per_actor.erase(key)
```

**State entry** — HSS updates internal state; `_resolve_hss_state()` returns the text to HUD Core:

```gdscript
func _enter_alert_cue_state() -> void:
    _current_hss_state = HSSState.ALERT_CUE
    # Deferred AccessKit — default at Day-1 per CR-14 REV-2026-04-28 (saves ~15 µs on transition frame)
    call_deferred("_set_accesskit_for_current_state")
    _alert_cue_timer.start(_alert_cue_duration_s)


func _set_accesskit_for_current_state() -> void:
    if _label == null:
        return
    _label.accessibility_live = "polite"
    _label.accessibility_description = tr(_current_state_key())
```

**`_resolve_hss_state()` return** — callback registered in Story 001; HUD Core's resolver calls this each `_process()` frame:

```gdscript
func _resolve_hss_state() -> Dictionary:
    if _current_hss_state == HSSState.ALERT_CUE:
        return {"text": tr("HUD_GUARD_ALERTED"), "state_id": HSSState.ALERT_CUE}
    return {"text": "", "state_id": HSSState.HIDDEN}
```

**Timer timeout handler**:

```gdscript
func _on_alert_cue_dismissed() -> void:
    _current_hss_state = HSSState.HIDDEN
    # Deferred clear per CR-8 AccessKit clear timing (prevents Orca cutoff of in-progress announcement)
    call_deferred("_clear_accesskit")


func _clear_accesskit() -> void:
    if _label == null:
        return
    _label.accessibility_description = ""
```

**Tuning knob load** — load `alert_cue_duration_s` from config at `_ready()`; never hardcode (coding standards — gameplay values are data-driven):

```gdscript
@export var _alert_cue_duration_s: float = 2.0  # Loaded from tuning knob config; §G.1 safe range [1.5, 3.0]
```

For MVP: the export annotation allows scene-level override; production should load from a `HSSTuningConfig` resource read at `_ready()`.

**`tr()` discipline**: the only allowed string path to the Label is `tr("HUD_GUARD_ALERTED")`. The key must be registered in the Localization Scaffold per Coord item §F.5 #4 (OQ-HSS-3-locale — BLOCKING Day-1). FP-HSS-7 CI grep will flag any `[A-Z ]{4,}` literal not wrapped in `tr(...)`.

**WCAG 2.2.1 timing-adjustable mechanism** (TR-HSS-010, OQ-HSS-3 PROMOTED TO BLOCKING Day-1 REV-2026-04-28): the `_alert_cue_duration_s` export var (or config read) satisfies the timing-adjustable requirement — it is accessible to Settings as a per-player preference. The Settings UI that exposes this to players is a Settings & Accessibility story; this story implements the mechanism (the tunable float) that Settings will wire up.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: structural scaffold, `_ready()`/`_exit_tree()` lifecycle, HUD Core handshake — must be DONE before this story can be tested end-to-end
- Story 003: MEMO_NOTIFICATION state, `document_collected` subscription, VS-scope priority resolver extensions
- VS-scope states (ALARM_STINGER, RESPAWN_BEAT, SAVE_FAILED) and their multi-state priority resolver (AC-HSS-3.x) — deferred post-VS
- CR-18 critical-health pulse — VS only
- AC-HSS-10.1 playtest validation — Advisory; separate QA activity after implementation
- Settings toggle `accessibility.hud_alert_cue_enabled` wiring (OQ-HSS-3) — Settings & Accessibility story; this story implements the mechanism only
- Translation key FR/DE locale values — Localization Scaffold story; this story only calls `tr("HUD_GUARD_ALERTED")`

---

## QA Test Cases

*Solo mode — test cases following GDD AC structure:*

**AC-HSS-2.1** — ALERT_CUE happy path
- **Given**: HSS instance (Story 001 scaffold in place), `_alert_cue_last_fired_per_actor` empty, guard `G1` mock node valid
- **When**: `Events.alert_state_changed.emit(G1, AlertState.UNAWARE, AlertState.SUSPICIOUS, Severity.MINOR)`
- **Then**: `_alert_cue_timer.is_stopped() == false` AND `_alert_cue_timer.time_left` approximately equals 2.0 AND `_alert_cue_last_fired_per_actor.has(G1) == true` AND `_resolve_hss_state()["state_id"] == HSSState.ALERT_CUE`
- **Edge cases**: `new_state == UNAWARE` → no state entry (AC-HSS-2.6); `actor` null → `is_instance_valid` guard suppresses

**AC-HSS-2.2 / 2.3** — Rate-gate cooldown
- **Given**: `_alert_cue_last_fired_per_actor[G1] = 5.0`, `_alert_cue_actor_cooldown_s = 1.0`
- **When** (within cooldown): signal fires at `T = 5.4`, same severity → suppressed
- **When** (beyond cooldown): signal fires at `T = 6.1` → fires fresh
- **Then**: dict updated to `{G1: 6.1}` on second case; first case dict unchanged
- **Edge cases**: cooldown boundary exactly (T = 6.0) → fires (>= check not > check per F.3 formula)

**AC-HSS-2.8** — Upward-severity exemption (WCAG SC 1.1.1 / 1.3.3)
- **Given**: `_alert_cue_last_state_per_actor[G1] = AlertState.SUSPICIOUS`, last fired `T = 5.0`, now `T = 5.4` (within cooldown)
- **When**: signal fires with `new_state = AlertState.COMBAT` (upward: COMBAT > SUSPICIOUS as int)
- **Then**: ALERT_CUE fires despite cooldown; `_alert_cue_last_state_per_actor[G1] == AlertState.COMBAT`
- **Edge cases**: same-level (SUSPICIOUS → SUSPICIOUS) within cooldown → suppressed; downward (COMBAT → SUSPICIOUS, guard already in COMBAT) → suppressed

**AC-HSS-5.2** — AccessKit polite-only
- **Given**: any ALERT_CUE state entry, `call_deferred` fires
- **When**: `_set_accesskit_for_current_state()` runs
- **Then**: `_label.accessibility_live == "polite"` — assert the string value directly
- **Edge cases**: `_label == null` (E.20 null-guard path active) → no crash, no accessibility set

**AC-HSS-6.1** — ui_context kill
- **Given**: ALERT_CUE active, Timer.time_left ≈ 1.0 s
- **When**: `Events.ui_context_changed.emit(Context.DOCUMENT_OVERLAY, Context.GAMEPLAY)`
- **Then**: `_alert_cue_timer.is_stopped() == true` AND `_resolve_hss_state()["state_id"] == HSSState.HIDDEN`
- **Edge cases**: rapid push/pop (E.9) → Timer.stop on already-stopped Timer is no-op; verify no error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/hud_state_signaling/test_alert_cue.gd` — AC-HSS-2.1, AC-HSS-2.6; must exist and pass
- `tests/unit/presentation/hud_state_signaling/test_rate_gate.gd` — AC-HSS-2.2, AC-HSS-2.3, AC-HSS-2.7; must exist and pass
- `tests/unit/presentation/hud_state_signaling/test_rate_gate_per_actor.gd` — AC-HSS-2.4; must exist and pass
- `tests/unit/presentation/hud_state_signaling/test_rate_gate_escalation.gd` — AC-HSS-2.8; must exist and pass
- `tests/unit/presentation/hud_state_signaling/test_auto_dismiss.gd` — AC-HSS-2.5, AC-HSS-2.9; must exist and pass
- `tests/unit/presentation/hud_state_signaling/test_accesskit.gd` — AC-HSS-5.2; must exist and pass
- `tests/unit/presentation/hud_state_signaling/test_tuning_knob_load.gd` — AC-HSS-4.1; must exist and pass
- `tests/integration/presentation/hud_state_signaling/test_locale_change.gd` — AC-HSS-5.1; must exist and pass
- `tests/integration/presentation/hud_state_signaling/test_ui_context_kill.gd` — AC-HSS-6.1, AC-HSS-6.2; must exist and pass
- `production/qa/evidence/perf-hss-alert-cue-[date].md` — AC-HSS-8.1 performance profile (manual, ADVISORY — OQ-HSS-4 profile gate before MVP sprint sign-off)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (structural scaffold + HUD Core handshake) must be DONE — `_label` reference and resolver-extension registration must exist before ALERT_CUE logic can be tested end-to-end
- Depends on: `HUD_GUARD_ALERTED` translation key registered in Localization Scaffold (OQ-HSS-3-locale — BLOCKING Day-1)
- Unlocks: Story 003 (MEMO_NOTIFICATION can be built on top of the shared state-machine pattern established here); HUD Core MVP unblocked once this story is DONE (HUD Core REV-2026-04-26 D3 HARD DEP)
