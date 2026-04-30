# Story 005: Settings live-update wiring, pickup memo subscription, context-hide full implementation

> **Epic**: HUD Core
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3–4 hours (M — three interacting systems: settings dispatch, document_collected memo, full context-change handler)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-core.md`
**Requirement**: TR-HUD-004, TR-HUD-010 (partial — `set_process` opt-out), TR-HUD-011, TR-HUD-014 (full — gadget reject Tween kill)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus — `setting_changed` subscription, `document_collected` subscription) + ADR-0004 (UI Framework — Settings category `"accessibility"` is the canonical home per Settings CR-2; crosshair visibility mirror; locale invalidation) + ADR-0008 (Performance Budget — Slot 7; `set_process(false)` opt-out reclaims the resolver's per-frame cost when HUD is hidden)

**ADR Decision Summary**: Three systems complete in this story:

1. **Settings live-update (`_on_setting_changed` handler, TR-HUD-011)**: The single `Settings.setting_changed(category, key, value)` subscription (established in Story 002) is dispatched by `(category, key)`. Four keys are handled: `("accessibility", "crosshair_enabled", value: bool)` → toggles `_crosshair_widget.visible`; `("accessibility", "hud_damage_flash_enabled", value: bool)` → sets `_flash_suppressed` mirror on the health widget; `("locale", _, _)` → invalidates `_cached_static_prompt_prefix` and `_last_interact_label_key` (forces `tr()` re-call on next target encounter); `("accessibility", "hud_critical_pulse_enabled", value: bool)` → sets `_critical_pulse_enabled` mirror (HSS-tier feature; this story provisions the mirror variable for correctness but the Tween pulse itself is deferred to the HSS epic). No other `(category, key)` pair is dispatched — unknown keys are silently ignored.

2. **Pickup memo via `document_collected` (VS scope, partial HSS bridge)**: The VS scope mandates that HUD Core display a brief pickup memo on `document_collected`. At VS tier, HUD Core owns a lightweight single-state MEMO path on the prompt strip: the `document_collected(doc)` signal handler (subscribed in `_ready()` — this is the 15th connection, **amending Story 002's count to 15**) sets `_prompt_label.text = tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key)`, makes the strip visible, and starts a `_memo_timer` (3.0 s). On `_memo_timer.timeout` the strip returns to `HIDDEN` unless the prompt resolver has already taken over. When HSS is implemented in the HUD State Signaling epic it replaces this lightweight path via `get_prompt_label()` — HUD Core's direct `document_collected` handler is REMOVED in that epic and HSS takes over memo notification. This story documents this transition point explicitly.

3. **Full `_on_ui_context_changed` handler (TR-HUD-004, TR-HUD-014)**: Story 003 added Tween kills for `_damage_flash_tween` and `_dry_fire_flash_tween`. This story completes the handler: kills `_gadget_reject_desat_tween` (gadget tile); calls `set_process(new_ctx == InputContext.Context.GAMEPLAY)` to reclaim Slot 7 budget when hidden; stops all active Timers (`_flash_timer`, `_dry_fire_timer`, `_gadget_reject_timer`, `_memo_timer`) on leave; clears transient state (`_pending_flash = false`, `_pending_dry_fire = false`) on leave so stale flash latches do not fire on restore.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `set_process(false)` is stable since Godot 4.0 and immediately suppresses `_process()` on the current node. `Timer.stop()` is stable. `Settings.setting_changed` signal signature is `(category: String, key: String, value: Variant)` — the handler must use `Variant`-typed third parameter per ADR-0002 §IG7 (the sole permitted Variant-payload signal in this project). `document_collected` signal signature: `document_collected(doc: Node)` or equivalent — verify against ADR-0002 taxonomy and Document Collection GDD before implementation; `is_instance_valid(doc)` guard required if `doc` is Node-typed.

> "The document_collected signal signature (particularly whether doc is a Resource or a Node) must be verified against ADR-0002 taxonomy before implementation — this may have changed in the 2026-04-28 amendments."

**Control Manifest Rules (Presentation)**:
- Required: `Settings.setting_changed` dispatched by `(category, key)` — no per-key `connect(Callable.bind(...))` subscriptions (would miscount connections, per GDD CR-1 B note)
- Required: `set_process(false)` when `new_ctx != GAMEPLAY`; `set_process(true)` on restore (Slot 7 opt-out)
- Required: all Timers stopped on context-leave (no deferred timeout after HUD hide)
- Required: all Tween references killed on context-leave (CR-22; Story 003 adds health flash Tweens; this story adds gadget reject Tween)
- Required: `is_instance_valid(doc)` guard if `document_collected` payload is Node-typed (ADR-0002 §IG4)
- Forbidden: `InputContext.push/pop/set` (FP-7)
- Forbidden: locale-specific `tr()` calls in `_process` (FP-8; locale invalidation triggers from `_on_setting_changed`, not per frame)
- Guardrail: Slot 7 = 0.3 ms cap; `set_process(false)` during non-GAMEPLAY contexts ensures HUD's `_process` budget is 0 during menus and cutscenes

---

## Acceptance Criteria

*From GDD `design/gdd/hud-core.md` §C.1 CR-10/CR-11/CR-22, §D.7 (Settings live-updates), §D.4 (Prompt-strip lifecycle), §H.1, TR-HUD-004/010/011/014:*

- [ ] **AC-1** (TR-HUD-011, crosshair toggle): GIVEN `Events.setting_changed("accessibility", "crosshair_enabled", false)` fires, WHEN `_on_setting_changed` dispatches, THEN `_crosshair_widget.visible = false`. GIVEN `setting_changed("accessibility", "crosshair_enabled", true)` fires, THEN `_crosshair_widget.visible = true` (provided `_hud_root.visible == true` — HUD is in GAMEPLAY context).

- [ ] **AC-2** (TR-HUD-011, damage flash opt-out): GIVEN `Events.setting_changed("accessibility", "hud_damage_flash_enabled", false)` fires, WHEN `_on_setting_changed` dispatches, THEN `_flash_suppressed = true` on the health widget state. GIVEN `setting_changed("accessibility", "hud_damage_flash_enabled", true)` fires, THEN `_flash_suppressed = false`.

- [ ] **AC-3** (TR-HUD-011, locale invalidation): GIVEN `Events.setting_changed("locale", _, _)` fires (locale changed), WHEN `_on_setting_changed` dispatches, THEN `_cached_static_prompt_prefix` is re-resolved via `tr("HUD_INTERACT_PROMPT")` AND `_last_interact_label_key` is reset to `&""` (forces `tr()` re-call on next target encounter in `_compose_prompt_text()`). No per-frame `tr()` cost; invalidation happens once on locale change.

- [ ] **AC-4** (TR-HUD-011, unknown category/key ignored): GIVEN `Events.setting_changed("graphics", "shadow_quality", 2)` fires, WHEN `_on_setting_changed` dispatches, THEN the handler silently returns (no error, no state mutation). The handler only branches on the 4 declared `(category, key)` pairs.

- [ ] **AC-5** (VS scope — pickup memo on `document_collected`): GIVEN `Events.document_collected(doc)` fires where `doc` is a valid object with a `title_key: StringName` property, WHEN `_on_document_collected(doc)` runs, THEN: (a) `_prompt_label.visible = true`; (b) `_prompt_label.text = tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(doc.title_key)`; (c) `_memo_timer.start()` is called (3.0 s). When `_memo_timer.timeout` fires, `_prompt_label.visible = false` (unless the prompt resolver has already set a different state in the intervening frames).

- [ ] **AC-6** (VS scope — pickup memo is_instance_valid guard): GIVEN `document_collected` fires with a freed Node payload (`doc != null` but `is_instance_valid(doc) == false`), WHEN `_on_document_collected` runs, THEN the handler returns immediately without writing to `_prompt_label.text` and without starting `_memo_timer`.

- [ ] **AC-7** (TR-HUD-004, full context-hide): GIVEN `Events.ui_context_changed(Context.MENU, Context.GAMEPLAY)` fires, WHEN `_on_ui_context_changed` completes, THEN ALL of the following hold simultaneously:
    - (a) `visible = false` on HUD root
    - (b) `_damage_flash_tween.kill()` called if non-null (Story 003)
    - (c) `_dry_fire_flash_tween.kill()` called if non-null (Story 003 provision)
    - (d) `_gadget_reject_desat_tween.kill()` called if non-null (this story)
    - (e) `set_process(false)` called
    - (f) `_flash_timer.stop()`, `_dry_fire_timer.stop()`, `_gadget_reject_timer.stop()`, `_memo_timer.stop()` called
    - (g) `_pending_flash = false`, `_pending_dry_fire = false`

- [ ] **AC-8** (TR-HUD-004, context-restore): GIVEN context transitions back to GAMEPLAY (`Events.ui_context_changed(Context.GAMEPLAY, Context.MENU)`), WHEN `_on_ui_context_changed` runs, THEN: (a) `visible = true`; (b) `set_process(true)`; (c) transient state (flash, memo, pending latches) NOT restored — all transient states use drop semantics on context-leave; the health widget, prompt strip, and crosshair re-render from the next incoming signal or the next `_process` frame naturally. Must Show widgets (health, weapon+ammo, gadget tile) remain statically rendered at their last-received state — they update on the next `player_health_changed`, `weapon_switched`, etc., which are re-emitted on context-restore per CR-14 / ADR-0007 handshake.

- [ ] **AC-9** (TR-HUD-014 completion — gadget reject Tween): GIVEN a gadget rejection desat Tween is in progress AND `ui_context_changed` fires leaving GAMEPLAY, WHEN `_on_ui_context_changed` runs, THEN `_gadget_reject_desat_tween.kill()` is called; `_gadget_reject_desat_tween = null`; gadget tile reverts to `modulate = Color.WHITE` on context restore (no residual grey tint).

- [ ] **AC-10** (Slot 7 process opt-out, TR-HUD-010 partial): GIVEN HUD is in a non-GAMEPLAY context, WHEN measured over 100 consecutive non-GAMEPLAY frames, THEN `HUDCore._process` has NOT been called (verified via `set_process(false)` confirmed by `is_processing() == false`). This ensures the prompt-strip resolver incurs zero per-frame cost during menus and cutscenes.

- [ ] **AC-11** (Story 002 count amendment — 15th connection): GIVEN `_ready()` completes, WHEN `Events.document_collected.is_connected(_on_document_collected)` is checked, THEN the result is `true`. Total connections at `_ready()` is now 15 (14 from Story 002 + 1 `document_collected`). Story 002's integration test must be updated to assert 15, not 14.

---

## Implementation Notes

*Derived from GDD §C.1 CR-10/CR-11/CR-22, §D.4, §D.7, §C.3 prompt lifecycle + `_on_setting_changed` CR-1(B) dispatch pattern:*

**New variables added by this story:**

```gdscript
# Settings mirrors (TR-HUD-011)
var _crosshair_enabled_mirror: bool = false  # false until Settings emits during its boot (OQ-HUD-3)
var _critical_pulse_enabled_mirror: bool = true  # HSS-tier, provisioned here; pulse Tween deferred

# Memo state (VS scope bridge to HSS)
var _memo_active: bool = false  # suppressed when HSS takes over get_prompt_label() in HSS epic
```

**`_memo_timer` node**: a 4th Timer child node (`one_shot = true`, `wait_time = 3.0`) must be added to `hud_core.tscn`. Declared as `@onready var _memo_timer: Timer = $MemoTimer`. This is the 4th Timer (Story 002 established 3: `_flash_timer`, `_dry_fire_timer`, `_gadget_reject_timer`). Total Timer count after this story: 4.

**`_on_setting_changed(category: String, key: String, value: Variant)` dispatch pattern (CR-1 B — single subscription):**

```gdscript
func _on_setting_changed(category: String, key: String, value: Variant) -> void:
    if category == "accessibility":
        match key:
            "crosshair_enabled":
                _crosshair_enabled_mirror = bool(value)
                _crosshair_widget.visible = _crosshair_enabled_mirror and visible
            "hud_damage_flash_enabled":
                _flash_suppressed = not bool(value)
            "hud_critical_pulse_enabled":
                _critical_pulse_enabled_mirror = bool(value)
                # Tween pulse start/stop deferred to HSS epic
    elif category == "locale":
        # Locale changed — invalidate tr() caches
        _cached_static_prompt_prefix = tr("HUD_INTERACT_PROMPT") + " "
        _last_interact_label_key = &""  # force re-call on next target
```

**`_on_document_collected(doc: Node)` — VS-tier lightweight memo path:**

```gdscript
func _on_document_collected(doc: Node) -> void:
    if not is_instance_valid(doc):
        return
    var title_key: StringName = doc.title_key if "title_key" in doc else &""
    var text: String
    if title_key != &"":
        text = tr("HUD_DOCUMENT_COLLECTED") + " — " + tr(title_key)
    else:
        text = tr("HUD_DOCUMENT_COLLECTED")
    _prompt_label.visible = true
    _prompt_label.text = text
    _memo_timer.start()
    _memo_active = true

func _on_memo_timer_timeout() -> void:
    _memo_active = false
    # Prompt resolver takes over on next _process frame; if no target → HIDDEN
    _prompt_label.visible = false
```

**NOTE — HSS transition contract**: When HUD State Signaling is implemented, `document_collected` handling moves entirely to HSS via the `get_prompt_label()` hook. At that point, `_on_document_collected` in `hud_core.gd` is REMOVED (or replaced by a pass-stub). The Story 002 subscription to `document_collected` is also removed. This story's `_memo_timer` child node may be repurposed or removed depending on HSS's timer architecture. Document this as a forward-removal note for the HSS epic's stories.

**Full `_on_ui_context_changed` (completes CR-22 + CR-10 + TR-HUD-004):**

```gdscript
func _on_ui_context_changed(new_ctx: InputContext.Context, _old_ctx: InputContext.Context) -> void:
    visible = (new_ctx == InputContext.Context.GAMEPLAY)
    if new_ctx != InputContext.Context.GAMEPLAY:
        # Tween kills (CR-22)
        if _damage_flash_tween != null:
            _damage_flash_tween.kill()
            _damage_flash_tween = null
        if _dry_fire_flash_tween != null:
            _dry_fire_flash_tween.kill()
            _dry_fire_flash_tween = null
        if _gadget_reject_desat_tween != null:
            _gadget_reject_desat_tween.kill()
            _gadget_reject_desat_tween = null
        # Timer stops
        _flash_timer.stop()
        _dry_fire_timer.stop()
        _gadget_reject_timer.stop()
        _memo_timer.stop()
        # Latch clears
        _pending_flash = false
        _pending_dry_fire = false
        _memo_active = false
        # _process opt-out (Slot 7)
        set_process(false)
    else:
        # Restore processing; Must Show widgets updated by next incoming signals
        set_process(true)
        # Crosshair respects Settings mirror
        _crosshair_widget.visible = _crosshair_enabled_mirror
```

**`_gadget_reject_desat_tween` variable**: declared as `@onready var _gadget_reject_desat_tween: Tween = null` (null at startup). This story provisions the variable and the kill call; the actual Tween creation (on `gadget_activation_rejected`) is deferred post-VS (gadget tile widget is deferred). The null-guard in the kill block makes this safe.

**Connection count amendment (Story 002 re-verification gate)**: Story 005 adds a 15th connection (`Events.document_collected.connect(_on_document_collected)`). Add to `_ready()` subscriptions block (A) alongside the other 9 Events signals. Add to `_exit_tree()` disconnect block with `is_connected()` guard. Story 002's integration test file `tests/integration/presentation/hud_core/test_subscription_lifecycle.gd` must be amended to assert 15 connections, not 14. This is a Story 005 deliverable — the test amendment.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Scene scaffold (crosshair widget node reference, `_memo_timer` Timer child node)
- **Story 002**: Base signal subscription plumbing (15th connection is added in this story's `_ready()` block, but the pattern is established in Story 002)
- **Story 003**: Health widget Tween kills for `_damage_flash_tween` and `_dry_fire_flash_tween`; `_flash_suppressed` variable declaration (this story writes to it but Story 003 declares it)
- **Story 004**: Prompt-strip resolver (`_process`, `_compose_prompt_text`, `get_prompt_label()`); `set_process` called here but `_process` body is owned by Story 004
- Post-VS deferrals: Critical-health Tween pulse (HSS-tier, depends on Settings GDD shipping); Gadget tile rejection Tween creation (gadget tile story); dry-fire flash detection (ammo widget story); full HSS multi-state priority resolver (HSS epic)
- HUD State Signaling epic: replaces `_on_document_collected` lightweight path with full HSS resolver via `get_prompt_label()`

---

## QA Test Cases

**AC-1 — Crosshair toggle**
- Given: HUD in GAMEPLAY context (`visible = true`); `_crosshair_widget` node present
- When: `Events.setting_changed.emit("accessibility", "crosshair_enabled", false)`
- Then: `_crosshair_widget.visible == false`
- When: `Events.setting_changed.emit("accessibility", "crosshair_enabled", true)`
- Then: `_crosshair_widget.visible == true`
- Edge cases: context != GAMEPLAY at time of toggle → `_crosshair_enabled_mirror` updated but widget remains hidden (visible is gated on HUD root visible)

**AC-2 — Damage flash opt-out**
- Given: `_flash_suppressed = false`
- When: `Events.setting_changed.emit("accessibility", "hud_damage_flash_enabled", false)`
- Then: `_flash_suppressed == true`
- When: emit `(true)`
- Then: `_flash_suppressed == false`

**AC-3 — Locale invalidation**
- Given: `_last_interact_label_key = &"INTERACT_OPEN_DOOR"` (cached); `_cached_static_prompt_prefix = "PRESS "`
- When: `Events.setting_changed.emit("locale", "language", "fr")`
- Then: `_last_interact_label_key == &""`; `_cached_static_prompt_prefix` re-evaluated via `tr("HUD_INTERACT_PROMPT")`

**AC-4 — Unknown key ignored**
- Given: settings dispatch running
- When: `Events.setting_changed.emit("graphics", "shadow_quality", 2)`
- Then: no state mutation; no GDScript error; handler returns silently

**AC-5 — Pickup memo display**
- Given: prompt strip hidden; `_memo_timer.is_stopped() == true`; mock `doc` with `title_key = &"DOC_INVOICE_12B"`
- When: `Events.document_collected.emit(mock_doc)`
- Then: `_prompt_label.visible == true`; `_prompt_label.text` contains `tr("HUD_DOCUMENT_COLLECTED") + " — " + tr("DOC_INVOICE_12B")`; `_memo_timer.is_stopped() == false`
- When: `_memo_timer.timeout` fires
- Then: `_prompt_label.visible == false`

**AC-6 — Freed doc guard**
- Given: `mock_doc` is freed before `document_collected` subscriber runs
- When: `_on_document_collected(freed_doc)` runs
- Then: `is_instance_valid(freed_doc) == false`; returns immediately; no text write; no timer start

**AC-7 — Full context-hide**
- Given: HUD in GAMEPLAY; `_damage_flash_tween != null`; `_gadget_reject_desat_tween != null`; `_flash_timer.is_stopped() == false`; `_memo_timer.is_stopped() == false`; `_pending_flash = true`
- When: `Events.ui_context_changed.emit(Context.MENU, Context.GAMEPLAY)`
- Then: all Tween refs killed and set to null; all Timers stopped; `_pending_flash = false`; `visible = false`; `is_processing() == false`

**AC-8 — Context restore**
- Given: HUD hidden (non-GAMEPLAY context); `is_processing() == false`
- When: `Events.ui_context_changed.emit(Context.GAMEPLAY, Context.MENU)`
- Then: `visible = true`; `is_processing() == true`; transient states not restored (memo not resumed, flash not resumed)

**AC-9 — Gadget reject Tween kill (provision)**
- Given: `_gadget_reject_desat_tween` is a live Tween
- When: context leaves GAMEPLAY
- Then: `_gadget_reject_desat_tween.kill()` called; ref set to null

**AC-10 — Process opt-out verified**
- Given: `set_process(false)` has been called (non-GAMEPLAY context)
- When: `hud_core_instance.is_processing()` checked
- Then: returns `false`

**AC-11 — 15 connections after _ready()**
- Given: HUDCore fully initialised with all autoloads and child Timers present
- When: `_ready()` completes
- Then: `Events.document_collected.is_connected(_on_document_collected) == true`; total connection count verifiable as 15

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/hud_core/test_settings_wiring.gd` — GUT tests for AC-1 through AC-4; deterministic (mock Settings signals; no real Settings autoload needed)
- `tests/unit/presentation/hud_core/test_context_hide.gd` — GUT tests for AC-7 through AC-10; Timer stubs and Tween mock references injected
- `tests/unit/presentation/hud_core/test_pickup_memo.gd` — GUT tests for AC-5 and AC-6
- `tests/integration/presentation/hud_core/test_subscription_lifecycle.gd` — AMENDED to assert 15 connections (was 14 in Story 002); must exist and pass after amendment
- `tests/unit/presentation/hud_core/test_forbidden_patterns.gd` — extended with locale-invalidation `tr()` path check (no per-frame `tr()` without a key-change guard)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (crosshair widget node and `_memo_timer` Timer child required); Story 002 DONE (subscription plumbing; Story 005 adds 15th connection); Story 003 DONE (`_flash_suppressed` variable declared; Tween kill pattern established); Story 004 DONE (`_process` resolver and `get_prompt_label()` must exist before `_on_memo_timer_timeout` and `_on_ui_context_changed` can operate on prompt state safely)
- Unlocks: Story 006 (Plaza VS integration smoke requires full context-hide and Settings wiring); HUD State Signaling epic (assumes `get_prompt_label()` works and `_on_document_collected` lightweight path is removable on HSS integration)

## Open Questions

- **`document_collected` signal signature**: GDD §C.3 references `document_collected(doc)`. Verify the exact type of `doc` against ADR-0002 taxonomy — is it a `Resource` subclass (Document resource), a `Node3D` (the world prop), or an abstract `Object`? If it is a `Resource`, `is_instance_valid()` is still appropriate but the `"title_key" in doc` duck-type check may be replaced with a typed cast. BLOCKING before implementation.
- **`doc.title_key` property name**: assumed `StringName` property on whatever type `doc` is. Verify against Document Collection GDD §C (doc schema) before implementation.
- **`set_process(false)` during context-leave — restore ordering**: on `ui_context_changed → GAMEPLAY`, `set_process(true)` is called after `visible = true`. Per Godot 4.6, `set_process(true)` takes effect from the NEXT frame — there is no `_process` call in the same frame as context-restore. This is correct (no dangling `_process` call on the frame when context changes). Confirm that this 1-frame delay does not cause a visible 1-frame blank prompt strip on context restore — mitigated by CR-14's signal replay which re-emits player state signals within 1 frame of restore.
