# Story 002: Signal subscription lifecycle — connect/disconnect registry

> **Epic**: Audio
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — subscription wiring + lifecycle test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/audio.md`
**Requirement**: TR-AUD-001, TR-AUD-003
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: AudioManager subscribes to 30 signals across 9 gameplay domains + Settings on the `Events` autoload. Subscriptions connect in `_ready()` and disconnect in `_exit_tree()` with `is_connected` guards before each disconnect call (ADR-0002 IG 3). Every Node-typed signal payload MUST be checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4). AudioManager publishes nothing — it is a subscriber-only system. The AI/Stealth 4-param / 3-param signal signatures (`alert_state_changed`, `actor_became_alerted`, `actor_lost_target`, `takedown_performed`) require the ADR-0002 amendment carrying the `severity: StealthAI.Severity` parameter; Story 002 skips those 4 handler connections until the amendment lands.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `signal.connect(callable)` / `signal.disconnect(callable)` / `signal.is_connected(callable)` are stable Godot 4.0+. String-based `connect("signal", obj, "method")` is deprecated and must NOT be used (per `docs/architecture/control-manifest.md` Forbidden APIs table). The `Callable` type is stable since 4.0.

**Control Manifest Rules (Foundation)**:
- Required: subscribers MUST connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards before each disconnect (ADR-0002 IG 3)
- Required: every Node-typed signal payload MUST be checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4)
- Forbidden: string-based signal `connect("signal_name", object, "method")` — use `Events.signal_name.connect(callable)` typed form (control-manifest Forbidden APIs, deprecated since 4.0)
- Forbidden: AudioManager publishing any signal on `Events` — it is subscriber-only; pattern `audio_publishing_signals` is forbidden per GDD Rule 9 + EPIC.md

---

## Acceptance Criteria

*From GDD `design/gdd/audio.md` Rules 3, 9 + AC-2 scoped to VS subscriber subset:*

- [ ] **AC-1**: GIVEN `AudioManager._ready()` completes, WHEN the connection state of the VS-subset signals is inspected, THEN `Events.document_opened.is_connected(AudioManager._on_document_opened)` is `true`, `Events.document_closed.is_connected(AudioManager._on_document_closed)` is `true`, `Events.respawn_triggered.is_connected(AudioManager._on_respawn_triggered)` is `true`, `Events.player_footstep.is_connected(AudioManager._on_player_footstep)` is `true`, `Events.dialogue_line_started.is_connected(AudioManager._on_dialogue_line_started)` is `true`, `Events.dialogue_line_finished.is_connected(AudioManager._on_dialogue_line_finished)` is `true`, `Events.section_entered.is_connected(AudioManager._on_section_entered)` is `true`, `Events.section_exited.is_connected(AudioManager._on_section_exited)` is `true`, `Events.actor_became_alerted.is_connected(AudioManager._on_actor_became_alerted)` is `true`.
- [ ] **AC-2**: GIVEN `AudioManager._exit_tree()` is called, WHEN the method runs, THEN every `Events.*` signal that was connected is disconnected. Verified by re-testing `is_connected()` after `_exit_tree()` — all return `false`.
- [ ] **AC-3**: GIVEN `_exit_tree()` is called when some connections were never made (edge case: early-exit during `_ready()` due to error), WHEN the disconnect loop runs, THEN no `ERR_INVALID_PARAMETER` is raised — the `is_connected` guard prevents double-disconnect crashes.
- [ ] **AC-4**: GIVEN any handler method that receives a Node-typed signal payload (e.g., `_on_actor_became_alerted(actor: Node, ...)`), WHEN the handler body is inspected, THEN `is_instance_valid(actor)` is called before any property access or method call on `actor`. Verified via code review and a unit test that passes a freed Node as the payload and confirms the handler does not crash.
- [ ] **AC-5**: GIVEN `AudioManager` source is grepped for `Events.*.emit(`, WHEN the grep returns results, THEN zero matches — AudioManager emits nothing on the bus (subscriber-only invariant; pattern `audio_publishing_signals` must be absent).

---

## Implementation Notes

*Derived from ADR-0002 §Implementation Guidelines IG 3, IG 4 + GDD §Detailed Design Rule 3:*

**VS-scope subscription list** — connect these 9 signals in `_ready()` and disconnect in `_exit_tree()`. The full 30-signal count (GDD Rule 3) connects as each subsequent story adds the handler:

```gdscript
# VS-scope subscriptions (Story 002 wires these; remaining signals wired by Stories 003–005)
func _connect_subscriptions() -> void:
    Events.document_opened.connect(_on_document_opened)
    Events.document_closed.connect(_on_document_closed)
    Events.respawn_triggered.connect(_on_respawn_triggered)
    Events.player_footstep.connect(_on_player_footstep)
    Events.dialogue_line_started.connect(_on_dialogue_line_started)
    Events.dialogue_line_finished.connect(_on_dialogue_line_finished)
    Events.section_entered.connect(_on_section_entered)
    Events.section_exited.connect(_on_section_exited)
    Events.actor_became_alerted.connect(_on_actor_became_alerted)
    # NOTE: alert_state_changed, actor_lost_target, takedown_performed use the
    # post-ADR-0002-amendment 4-param/2-param signatures. Skip until amendment lands.
    # See GDD §Detailed Design Rule 3 ADR-0002-amendment warning block.

func _disconnect_subscriptions() -> void:
    # Pattern: guard every disconnect with is_connected to prevent ERR_INVALID_PARAMETER
    if Events.document_opened.is_connected(_on_document_opened):
        Events.document_opened.disconnect(_on_document_opened)
    if Events.document_closed.is_connected(_on_document_closed):
        Events.document_closed.disconnect(_on_document_closed)
    if Events.respawn_triggered.is_connected(_on_respawn_triggered):
        Events.respawn_triggered.disconnect(_on_respawn_triggered)
    if Events.player_footstep.is_connected(_on_player_footstep):
        Events.player_footstep.disconnect(_on_player_footstep)
    if Events.dialogue_line_started.is_connected(_on_dialogue_line_started):
        Events.dialogue_line_started.disconnect(_on_dialogue_line_started)
    if Events.dialogue_line_finished.is_connected(_on_dialogue_line_finished):
        Events.dialogue_line_finished.disconnect(_on_dialogue_line_finished)
    if Events.section_entered.is_connected(_on_section_entered):
        Events.section_entered.disconnect(_on_section_entered)
    if Events.section_exited.is_connected(_on_section_exited):
        Events.section_exited.disconnect(_on_section_exited)
    if Events.actor_became_alerted.is_connected(_on_actor_became_alerted):
        Events.actor_became_alerted.disconnect(_on_actor_became_alerted)
```

**Handler stub pattern** — each story fills in the handler bodies. For this story, all handlers are stubs that validate the `is_instance_valid` guard on node payloads:

```gdscript
func _on_actor_became_alerted(
        actor: Node,
        cause: StealthAI.AlertCause,
        source_position: Vector3,
        severity: StealthAI.Severity) -> void:
    if not is_instance_valid(actor):
        return
    # TODO: Story 005 fills in stinger scheduling logic
```

**is_instance_valid discipline** (ADR-0002 IG 4): Every handler receiving a `Node`-typed parameter must call `is_instance_valid(node)` as the FIRST statement before any property read. This is not optional — signals can be queued and the source node may be freed before the subscriber runs (see ADR-0002 IG 4 rationale).

**Subscriber-only fence**: AudioManager has NO emit calls to `Events.*`. This is enforced architecturally (AudioManager has no design reason to publish) and verified by the CI lint test in AC-5.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `_on_section_entered` and `_on_section_exited` handler bodies (music swap, reverb swap, dominant-guard dict clear)
- Story 004: `_on_dialogue_line_started`, `_on_dialogue_line_finished`, `_on_document_opened`, `_on_document_closed`, `_on_respawn_triggered` handler bodies
- Story 005: `_on_player_footstep`, `_on_actor_became_alerted` handler bodies

**Deferred post-VS** (do NOT implement in this story):
- TR-AUD-001 (full 30-signal count): the AI/Stealth signals `alert_state_changed(4 params)`, `actor_lost_target(2 params)`, `takedown_performed(3 params)` require the ADR-0002 amendment for the `severity: StealthAI.Severity` 4th parameter to land. Skip these until the amendment is Accepted. The remaining 17 non-VS-scope signals (combat, civilian, mission-objectives, persistence, cutscenes, settings) are deferred to full implementation epics.

---

## QA Test Cases

**AC-1 — VS-scope connections are established after _ready()**
- **Given**: a test scene that instantiates `AudioManager` as a child of a Node that also has `Events` accessible (test uses the live `Events` autoload or a mock)
- **When**: `AudioManager._ready()` completes
- **Then**: `Events.document_opened.is_connected(audio_manager._on_document_opened) == true`; same assertion for each of the 9 VS-scope signals
- **Edge cases**: `Events` autoload not yet in tree (should not occur since autoloads precede scene nodes per ADR-0007 §Cross-Autoload Reference Safety); handler method renamed (connection fails with error — test catches it)

**AC-2 — all connections removed after _exit_tree()**
- **Given**: AudioManager with all VS-scope connections established (AC-1 state)
- **When**: `_exit_tree()` is called on AudioManager
- **Then**: `Events.document_opened.is_connected(audio_manager._on_document_opened) == false`; same for all 9 signals
- **Edge cases**: partial disconnect (some is_connected guards fail) → remaining connections leak; test should iterate all 9 signals explicitly

**AC-3 — disconnect is safe if _ready() aborted early**
- **Given**: an AudioManager whose `_ready()` is stubbed to connect only 3 of 9 signals before returning early
- **When**: `_exit_tree()` is called
- **Then**: no GDScript error ("ERR_INVALID_PARAMETER: Signal not connected"); the 6 unconnected signals pass through the `is_connected` guard silently
- **Edge cases**: guard omitted on any signal → test must trigger the exact disconnect-without-connect path and assert no error

**AC-4 — Node-typed payload safe when source node is freed**
- **Given**: a test that connects AudioManager to `Events.actor_became_alerted`, then emits the signal with a pre-freed Node as the `actor` argument
- **When**: the handler `_on_actor_became_alerted(actor, ...)` runs
- **Then**: no crash; no property access on the freed node; `is_instance_valid(actor)` returns `false` and the handler returns early
- **Edge cases**: `is_instance_valid` check is placed after a property access → crash (test must confirm the guard is first)

**AC-5 — AudioManager emits nothing (subscriber-only invariant)**
- **Given**: `src/audio/audio_manager.gd` source file
- **When**: a CI grep test scans the file for `Events.*.emit(` or `\.emit\(`
- **Then**: zero matches on any `Events.*` signal emit call within the AudioManager source
- **Edge cases**: future story accidentally adds an emit — this test becomes a CI gate

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/audio/audio_subscription_lifecycle_test.gd` — must exist and pass
- Covers AC-1 (connection count), AC-2 (disconnect after exit_tree), AC-3 (guard against double-disconnect), AC-4 (is_instance_valid guard on freed Node payload)
- `tests/ci/audio_subscriber_only_lint.gd` — grep-based CI test for AC-5 (subscriber-only invariant; no Events emit calls in audio_manager.gd)
- Determinism: no random seeds; no time-dependent assertions

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (AudioManager class must exist for subscription wiring)
- Unlocks: Story 003 (section-entered handler body), Story 004 (ducking handlers), Story 005 (footstep + stinger handlers)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: AC-1..AC-5 covered with 16 lifecycle tests + 2 CI lint tests. AC-1 verifies 8 of 9 VS-subset signals connected (deviation: actor_became_alerted not yet declared in events.gd). AC-2 verifies all connections drop on _exit_tree. AC-3 idempotent disconnect verified via mock no-op subclass. AC-4 freed-Node payload safety covered (handler bodies are stubs but pattern proved). AC-5 enforced by CI grep lint test.
**Test Evidence**: `tests/unit/foundation/audio/audiomanager_subscription_lifecycle_test.gd` + `tests/ci/audio_subscriber_only_lint.gd`
**Code Review**: APPROVED inline — 8 connect/disconnect pairs all guarded by is_connected; 9 stub handlers with correct signatures matching events.gd taxonomy; `is_instance_valid` guard pattern documented for Node-payload handlers; subscriber-only invariant holds.
**Deviations**:
1. **`Events.actor_became_alerted` not declared in events.gd** — deferred with the AI/Stealth domain (requires StealthAI.AlertCause + StealthAI.Severity enums per ADR-0002 amendment). Handler stub `_on_actor_became_alerted` exists in audio_manager.gd but is NOT wired by `_connect_signal_bus`. Will land alongside Stealth AI epic.
2. **CI lint format-string parens fix** — initial CI lint test had `%` operator binding tighter than `+` causing parse error. Fixed by wrapping the format strings in parens before applying `%`.
**Suite trajectory**: 400 → 418 (+18 tests).
**Files modified**:
- `src/audio/audio_manager.gd` (extended from 98 to ~250 lines: `_connect_signal_bus()` + `_disconnect_signal_bus()` + 9 stub handlers + `_exit_tree()` lifecycle hook)
**Files created**:
- `tests/unit/foundation/audio/audiomanager_subscription_lifecycle_test.gd` (16 tests: AC-1 8 connect-state checks + AC-2 8 disconnect-state checks + AC-3 idempotent disconnect via mock + AC-4 freed-Node payload safety)
- `tests/ci/audio_subscriber_only_lint.gd` (2 CI lint tests: Events-prefixed-emit grep + bare-emit defence-in-depth)
**Out-of-scope deferred** (correctly): AUD-003 music players + section handlers; AUD-004 VO ducking + document mute + respawn cut; AUD-005 footstep routing + COMBAT stinger.
