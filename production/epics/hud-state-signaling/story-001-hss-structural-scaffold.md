# Story 001: HUD State Signaling — structural scaffold + HUD Core handshake

> **Epic**: HUD State Signaling
> **Status**: Complete — 2026-05-03 (Sprint 06)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: 2-3 hours (M — new scene file + script skeleton + handshake test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/hud-state-signaling.md`
**Requirement**: TR-HSS-002 (subscriber-only posture; emits zero signals), TR-HSS-003 (Slot 7 sub-claim scaffold)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: HSS is a per-section `Node` (`class_name HUDStateSignaling extends Node`), instantiated as a child of HUD Core's `CanvasLayer` at scene path `Section/Systems/HUDStateSignaling` per the MLS section authoring contract (GDD CR-2). It is NOT an autoload (ADR-0007). It connects to `Events.alert_state_changed` in `_ready()` and disconnects in `_exit_tree()` using `is_connected` guards (ADR-0002 IG 3). It registers its resolver-extension callback with `HUDCore.register_resolver_extension(_resolve_hss_state)` in `_ready()` and unregisters in `_exit_tree()` to prevent dead Callable accumulation across section reloads (GDD CR-4 REV-2026-04-28).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Node` lifecycle, `Signal.connect/disconnect/is_connected`, `Callable`, and `is_instance_valid` are stable Godot 4.0+. The `HUDCore.register_resolver_extension` and `HUDCore.unregister_resolver_extension` APIs are NEW HUD Core APIs that must land before this story can close (Coord item §F.5 #1 — BLOCKING for Day-1 per GDD OQ-HSS-1). The story is Ready in terms of HSS implementation work but Integration AC-HSS-1.3 and AC-HSS-1.4 are BLOCKED-on HUD Core's API delivery. `CONNECT_DEFERRED` is explicitly forbidden for all HSS subscriptions (GDD FP-HSS-15 REV-2026-04-28) — use default synchronous `connect()` only.

**Control Manifest Rules (Presentation)**:
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards before each disconnect call — ADR-0002 IG 3
- Required: every Node-typed signal payload checked with `is_instance_valid(node)` before dereferencing — ADR-0002 IG 4
- Forbidden: `CONNECT_DEFERRED` flag on any `Events.*` subscription in HSS source — pattern `hss_deferred_subscription` (GDD FP-HSS-15)
- Forbidden: HSS registered as an autoload — GDD CR-2 + ADR-0007
- Forbidden: any `Events.*.emit(...)` call in HSS source — pattern `hss_publishing_signals` (GDD FP-HSS-8 + CR-1)
- Forbidden: `get_node("PromptStrip/Label")` or `find_child("..Label..")` style scene-tree walks — pattern `hss_pushing_visibility_to_hud_core` (GDD FP-HSS-3 + CR-3)

---

## Acceptance Criteria

*From GDD `design/gdd/hud-state-signaling.md` §Acceptance Criteria Cluster 1, scoped to this story:*

- [ ] **AC-HSS-1.1**: GIVEN the section is loaded and `Section/Systems/HUDStateSignaling` is in the scene tree, WHEN HSS `_ready()` runs, THEN `Events.alert_state_changed` is connected to `_on_alert_state_changed` exactly once (`Events.alert_state_changed.is_connected(_on_alert_state_changed) == true` AND `Events.alert_state_changed.get_connections().filter(...).size() == 1`). [CR-10]
- [ ] **AC-HSS-1.3**: GIVEN HUD Core is in the scene tree at `Section/Systems/HUDCore`, WHEN HSS `_ready()` runs, THEN `HUDCore.get_prompt_label()` returns a non-null Label reference AND HSS holds it as `_label` AND `HUDCore.register_resolver_extension(_resolve_hss_state)` is called exactly once. [CR-3, CR-4] **BLOCKED-on HUD Core's new APIs — Coord item §F.5 #1**
- [ ] **AC-HSS-1.4**: GIVEN an HSS instance with active resolver-extension registration, WHEN the parent section is unloaded (`queue_free()` propagates), THEN `_exit_tree()` calls `HUDCore.unregister_resolver_extension(_resolve_hss_state)` exactly once AND HUD Core's resolver-extension array no longer contains the dead Callable. [CR-4 REV-2026-04-28, CR-10 REV-2026-04-28] **BLOCKED-on HUD Core's new APIs**
- [ ] **AC-HSS-1.5**: GIVEN ALERT_CUE active with Timer.time_left == 1.5 s, WHEN the player dies AND respawns, THEN the section is freed (HSS instance freed; in-flight Timer destroyed with it); the new section's new HSS instance starts with empty rate-gate dicts AND no active Timer; if a new alert event fires post-respawn, ALERT_CUE fires fresh with no double-Timer. [CR-12, E.18]
- [ ] **Subscriber-only posture**: GIVEN HSS source at `src/ui/hud_state_signaling.gd`, WHEN CI grep runs `Events\..*\.emit\(` against the file, THEN zero matches (FP-HSS-8 enforced). [CR-1]
- [ ] **E.20 null-guard**: GIVEN HUD Core is absent from the scene tree when HSS `_ready()` runs, WHEN `HUDCore.get_prompt_label()` returns null (or `is_instance_valid(HUDCore) == false`), THEN HSS emits `push_error(...)` AND calls `set_process(false)` AND returns without connecting any signals — HSS becomes inert rather than crashing on first dispatch. [E.20 REV-2026-04-28]

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines + GDD CR-1, CR-2, CR-4, CR-10, E.20:*

**File locations:**

```
src/ui/
├── hud_state_signaling.gd          (class_name HUDStateSignaling extends Node)
└── HUDStateSignaling.tscn          (root: HUDStateSignaling, children: AlertCueTimer only at Day-1)
```

**Scene path contract**: `Section/Systems/HUDStateSignaling` (mirrors `Section/Systems/DocumentCollection` per GDD CR-2). MLS section authoring contract must include this node before this story can be validated end-to-end (Coord item §F.5 #3 — OQ-HSS-2).

**`_ready()` pattern** (GDD CR-10 + CR-3 + CR-4 + E.20):

```gdscript
func _ready() -> void:
    # E.20 null-guard — explicit null check, NOT assert() (assert is debug-only in Godot 4.6 release)
    _label = HUDCore.get_prompt_label() if is_instance_valid(HUDCore) else null
    if _label == null:
        push_error("HSS: HUD Core not present at _ready(); HSS disabled for this section.")
        set_process(false)
        return

    # CR-4: register resolver extension BEFORE signal subscriptions
    HUDCore.register_resolver_extension(_resolve_hss_state)

    # CR-10: connect with default synchronous flags only (CONNECT_DEFERRED forbidden — FP-HSS-15)
    Events.alert_state_changed.connect(_on_alert_state_changed)
    Events.ui_context_changed.connect(_on_ui_context_changed)

    # Connect Day-1 Timer
    _alert_cue_timer.timeout.connect(_on_alert_cue_dismissed)
```

**`_exit_tree()` pattern** (GDD CR-10 REV-2026-04-28 + CR-4 REV-2026-04-28):

```gdscript
func _exit_tree() -> void:
    # CR-4 REV-2026-04-28: unregister resolver extension to prevent dead Callable accumulation
    if is_instance_valid(HUDCore):
        HUDCore.unregister_resolver_extension(_resolve_hss_state)

    # CR-10: disconnect with is_connected guard per ADR-0002 IG 3
    if Events.alert_state_changed.is_connected(_on_alert_state_changed):
        Events.alert_state_changed.disconnect(_on_alert_state_changed)
    if Events.ui_context_changed.is_connected(_on_ui_context_changed):
        Events.ui_context_changed.disconnect(_on_ui_context_changed)

    # CR-9 cleanup: clear rate-gate dicts
    _alert_cue_last_fired_per_actor.clear()
    _alert_cue_last_state_per_actor.clear()

    # Force-stop active Timer
    if not _alert_cue_timer.is_stopped():
        _alert_cue_timer.stop()
```

**`_resolve_hss_state()` stub** (returns "no HSS state active" sentinel at this story; Story 002 fills in the ALERT_CUE case):

```gdscript
func _resolve_hss_state() -> Dictionary:
    # Returns {"text": "", "state_id": HSSState.HIDDEN} when no state is active.
    # HUD Core's resolver maps state_id to priority per CR-6.
    return {"text": "", "state_id": HSSState.HIDDEN}
```

**No `_process` override** — FP-HSS-4 absolute. Timer-only dispatch (CR-5).

**Static typing required** on all declarations per coding standards. Use `Array[Node]` not bare `Array`; use `Dictionary[Node, float]` for rate-gate dicts; use `Dictionary[Node, StealthAI.AlertState]` for last-state dict.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: ALERT_CUE state entry logic, rate-gate predicate, AccessKit announce, `tr()` call — the resolver callback returning real text
- Story 003: MEMO_NOTIFICATION state, `document_collected` subscription, document title resolution from DC registry
- VS-scope states (ALARM_STINGER, RESPAWN_BEAT, SAVE_FAILED, CR-18 critical-health pulse) and their Timer nodes — deferred post-VS per VS-narrowing
- `HUDCore.get_health_label()` API consumption (CR-18) — VS only, Coord item §F.5 #2
- Per-state tuning knob file read (deferred to Story 002 for ALERT_CUE knobs)

---

## QA Test Cases

*Solo mode — test cases defined by implementer following GDD AC structure:*

**AC-HSS-1.1** — Signal connected exactly once
- **Given**: a fresh `HUDStateSignaling` instance added to a test scene with a mock `Events` autoload
- **When**: `_ready()` completes
- **Then**: `Events.alert_state_changed.get_connections().size() == 1` AND the connection target is `_on_alert_state_changed` on this instance
- **Edge cases**: calling `_ready()` twice must not double-connect (test via manual `_ready()` call; Godot's `connect()` will warn on duplicate — verify no duplicate in connections list)

**AC-HSS-1.3** — HUD Core handshake (BLOCKED-on HUD Core API)
- **Given**: a test scene with both `HUDCore` and `HUDStateSignaling` as siblings
- **When**: `HUDStateSignaling._ready()` runs
- **Then**: `HUDCore._resolver_extensions` contains a Callable pointing to `HUDStateSignaling._resolve_hss_state` AND `hud_state_signaling._label != null`
- **Edge cases**: HUD Core not yet in tree when HSS `_ready()` fires (scene order issue) → null-guard path triggers; verify `push_error` called AND no crash

**AC-HSS-1.4** — Unregister on exit (BLOCKED-on HUD Core API)
- **Given**: an HSS instance registered with HUD Core's resolver
- **When**: `queue_free()` is called on the HSS instance and the tree processes the deletion
- **Then**: `HUDCore._resolver_extensions.size()` is exactly 1 fewer than before the free; the removed entry was the HSS Callable
- **Edge cases**: HUD Core freed before HSS (section teardown order) → `is_instance_valid(HUDCore)` guard skips the unregister call cleanly

**AC-HSS-1.5** — Clean respawn state
- **Given**: HSS instance with a running `_alert_cue_timer` (time_left = 1.5 s) and non-empty `_alert_cue_last_fired_per_actor`
- **When**: the HSS node is `queue_free()`d (simulating section unload) AND a new HSS instance is instantiated
- **Then**: new instance has `_alert_cue_last_fired_per_actor.size() == 0` AND `_alert_cue_timer.is_stopped() == true`; the old Timer is destroyed with the old node (no orphan signal connections)
- **Edge cases**: Timer.stop on an already-stopped Timer is a no-op — verify no error

**Subscriber-only posture**
- **Given**: `src/ui/hud_state_signaling.gd` source committed
- **When**: `grep -n "Events\..*\.emit(" src/ui/hud_state_signaling.gd` runs
- **Then**: exit code 1 (no matches) — zero emit calls in HSS source
- **Edge cases**: CI script must search all HSS-owned `.gd` files, not just the main file

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/presentation/hud_state_signaling/test_subscriber_lifecycle.gd` — AC-HSS-1.1, AC-HSS-1.5; must exist and pass
- `tests/integration/presentation/hud_state_signaling/test_hud_core_handshake.gd` — AC-HSS-1.3, AC-HSS-1.4; **BLOCKED-on HUD Core new APIs (Coord item §F.5 #1)**
- `tests/integration/presentation/hud_state_signaling/test_section_unload.gd` — AC-HSS-1.4 detailed Callable-count assertion; BLOCKED-on same
- CI grep evidence in `tools/ci/check_forbidden_patterns_hss.sh` (FP-HSS-8 emit check)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: ADR-0002 (Accepted — unblocked); ADR-0007 (Accepted — unblocked); HUD Core's `register_resolver_extension` / `unregister_resolver_extension` APIs (BLOCKING — OQ-HSS-1 / Coord item §F.5 #1)
- Unlocks: Story 002 (ALERT_CUE logic requires the structural scaffold and `_label` reference from this story to be in place)
