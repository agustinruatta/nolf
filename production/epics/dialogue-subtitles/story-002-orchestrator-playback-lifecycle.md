# Story 002: DialogueAndSubtitles orchestrator — playback lifecycle, rate-gate, range gate, priority resolver

> **Epic**: Dialogue & Subtitles
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 hours (L — core state machine + 7-step lifecycle + timer logic + unit tests)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/dialogue-subtitles.md`
**Requirement**: TR-DLG-005, TR-DLG-012, TR-DLG-013, TR-DLG-014, TR-DLG-015
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0007 (Autoload Load Order Registry), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**:
- ADR-0002: `DialogueAndSubtitles` is the sole publisher of `Events.dialogue_line_started` and `Events.dialogue_line_finished` — no other system emits these. Direct emit pattern: `Events.dialogue_line_started.emit(speaker, line_id)`. Signal emit order: `dialogue_line_started` fires BEFORE `_audio_player.play()` (CR-DS-2 step 3 vs 4 ordering). Subscribers connect/disconnect via `_ready`/`_exit_tree` lifecycle per IG 3.
- ADR-0007: `DialogueAndSubtitles` is NOT autoload — the 10-autoload table is full. It is a per-section scene-tree Node instantiated under `Section/Systems/` matching the canonical path. Lifetime = section lifetime.
- ADR-0008: D&S claims a sub-slot of Slot 8 pooled residual: 0.10 ms peak event-frame (registered 2026-04-28 night per Phase 2 propagation). No `_process` or `_physics_process` callbacks — zero steady-state frame cost. Event-frame cost only when a bark trigger fires.

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM
**Engine Notes**: `AudioStreamPlayer.finished` signal (used in dual-completion guard CR-DS-2 step 7), `Timer.timeout` signal (one-shot `CaptionTimer` and `WatchdogTimer`), `Time.get_ticks_msec()` (wall-clock rate-gate per CR-DS-8), `call_deferred()` (player-ref resolution in `_ready`), and `is_instance_valid()` (actor/player null guard) are all stable Godot 4.0+. VG-DS-4: `AudioStreamPlayer.finished` may or may not fire on `.stop()` in Godot 4.6 — the `_stopping_for_interrupt: bool` guard is implemented unconditionally per godot-specialist recommendation (v0.3 CR-DS-7), so this story does not require VG-DS-4 to be resolved before shipping.

**ADR-0004 (Proposed — G5 deferred)**: This story implements the orchestrator logic only — no subtitle rendering, no theme, no label assignment. ADR-0004 constraints (auto_translate_mode, Theme) land in Story 003 (suppression) and Story 004 (renderer). The deferred G5 BBCode/AccessKit gate does not affect this story.

**ADR-0008 (Proposed — non-blocking)**: Non-blocking per EPIC.md. The 0.10 ms sub-claim budget guides implementation (no per-frame callbacks, no heavy dict operations per-frame) but does not block story delivery.

**Control Manifest Rules (Feature layer)**:
- Required: subscribers connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Required: `is_instance_valid(node)` guard before dereferencing any Node-typed signal payload (ADR-0002 IG 4)
- Required: direct emit — `Events.dialogue_line_started.emit(speaker, line_id)` — no wrapper methods
- Forbidden: `dialogue_signal_emitted_outside_d&s` — `Events.dialogue_line_started` and `Events.dialogue_line_finished` are emitted ONLY from `dialogue_and_subtitles.gd`
- Forbidden: `audio_ducking_in_dialogue_subtitles` — D&S MUST NOT call any Audio method, modify any Audio bus, or read any Audio bus value; ducking is Audio's responsibility as subscriber
- Forbidden: `_process` or `_physics_process` callbacks — D&S is event-driven; no per-frame polling
- Forbidden: `await get_tree().create_timer()` inside signal handlers — all timing uses child `Timer` nodes (FP-DS-16)
- Forbidden: `.connect()` inside `_process` or `_physics_process` (FP-DS-17)
- Performance guardrail: ≤ 0.10 ms peak event-frame (ADR-0008 Slot 8 pooled — TR-DLG-005, TR-DLG-014)

---

## Acceptance Criteria

*From GDD `design/gdd/dialogue-subtitles.md` §H.1–H.5, H.9, scoped to VS depth (simplified priority resolver):*

- [ ] **AC-1** (from AC-DS-1.2 + AC-DS-1.4): GIVEN D&S initialized in a section, WHEN a bark lifecycle runs all 7 steps of CR-DS-2, THEN exactly one `dialogue_line_started` and one `dialogue_line_finished` emit per line; `dialogue_line_started` fires BEFORE `_audio_player.play()` (step 3 before step 4); no `dialogue_line_finished` fires without a preceding `dialogue_line_started`.
- [ ] **AC-2** (from AC-DS-1.5): GIVEN a `DialogueLine` with `audio_stream.get_length() < 0.1 s` (mock injected), WHEN `select_line()` is called, THEN it returns `null` and emits `push_error("D&S: rejected line ... — audio_duration_s < 0.1 s")` with no `dialogue_line_started` emitted (FP-DS-21).
- [ ] **AC-3** (from AC-DS-2.4): GIVEN a line in flight, WHEN only one of `_audio_player.finished` or `_caption_timer.timeout` fires, THEN `dialogue_line_finished` is NOT emitted. WHEN both have fired, THEN `dialogue_line_finished` emits and internal state resets.
- [ ] **AC-4** (from AC-DS-2.5a + AC-DS-2.5b): GIVEN a line in flight, WHEN `_exit_tree` is called, THEN `_audio_player.stop()` is called, `dialogue_line_finished` emits, `_label.text` clears, state returns to HIDDEN, AND all `Events.*` subscriptions are disconnected with `is_connected()` guards.
- [ ] **AC-5** (from AC-DS-2.6): GIVEN a line in flight with `_audio_player.finished` suppressed (mock), AND `audio_duration_s = 1.0`, WHEN mock-clock advances 6.0 s (watchdog fires), THEN: (1) `_audio_player.stop()` called; (2) `dialogue_line_finished` force-emitted; (3) `_label.text` cleared; (4) state HIDDEN — in this exact order.
- [ ] **AC-6** (from AC-DS-5.1): GIVEN `_actor_last_bark_time[GuardA] = 135.0` s (mock clock) and cooldown = 8.0 s, WHEN `select_line()` at mock-clock 142.3 s, THEN `null` (7.3 s < 8.0 s). When clock advances to 143.1 s, eligible.
- [ ] **AC-7** (from AC-DS-5.3): GIVEN actor at `(12.0, 0.0, 5.0)` and player at origin with `dialogue_bark_range_m = 25.0`, WHEN range gate evaluated, THEN in-range (distance 13.0 m). Given actor at `(30.0, 0.0, 0.0)`, out of range (30.0 m > 25.0 m).
- [ ] **AC-8** (from AC-DS-9.2): GIVEN no bark in flight, WHEN profiler samples 60 consecutive frames, THEN D&S contributes 0.0 ms (no `_process`/`_physics_process` callback). Verified by `grep -L "_process\|_physics_process" dialogue_and_subtitles.gd` returning the file.
- [ ] **AC-9** (from AC-DS-11.3 + AC-DS-11.4): GIVEN `dialogue_and_subtitles.gd`, WHEN CI runs grep for `.connect()` inside `_process`/`_physics_process`, THEN zero matches. WHEN CI runs grep for `await get_tree().create_timer`, THEN zero matches.
- [ ] **AC-10** (from AC-DS-10.1): GIVEN `DialogueAndSubtitles.tscn`, WHEN `AudioLinePlayer.bus` property inspected, THEN `bus = "Voice"`. Grep `bus.*=.*SFX|bus.*=.*Music|bus.*=.*Master` in the scene file returns zero matches.

---

## Implementation Notes

*Derived from ADR-0002 + ADR-0007 + GDD §C.1–C.3 Implementation Guidelines:*

Scene tree (GDD §C.3):

```
Section/Systems/DialogueAndSubtitles    (Node, class_name DialogueAndSubtitles)
  ├── SubtitleCanvasLayer               (CanvasLayer, layer = 2)
  │     └── SubtitleLabel               (Label — see Story 004 for full config)
  ├── AudioLinePlayer                   (AudioStreamPlayer, bus = "Voice")
  ├── CaptionTimer                      (Timer, one_shot = true, autostart = false)
  └── WatchdogTimer                     (Timer, one_shot = true, autostart = false)
```

This story implements the GDScript logic only. Story 004 configures `SubtitleLabel` typography and layout. Story 003 adds suppression subscriptions to `document_opened`/`document_closed`/`ui_context_changed`. The scene `.tscn` file is created here with the node structure above (Story 004 will extend it with Label properties).

VS-scoped implementation notes (from GDD §C.16):
- Priority resolver: VS scope uses 2 priority tiers — SCRIPTED (bucket 1) can interrupt any in-flight line; CURIOSITY_AMBIENT (bucket 4) is the only other active bucket at VS. Full 5-tier resolver (Story 002 full VS) is still implemented per CR-DS-7 for correctness, but only SCRIPTED and CURIOSITY_AMBIENT triggers are exercised at VS.
- Depth-1 queue: fully implemented per CR-DS-7 even at VS scope (low cost; required for correctness when future buckets activate).
- `_stopping_for_interrupt: bool`: unconditional VG-DS-4 guard — implemented regardless of engine-version behavior.
- `_player_ready: bool = false` boot-window guard: `_ready()` calls `call_deferred("_resolve_player_ref")`. Non-SCRIPTED triggers return `null` while `_player_ready = false`.

Key implementation rules:
1. `select_line()` is the gatekeeper: null `audio_stream` check (FP-DS-2), `audio_duration_s < 0.1 s` check (FP-DS-21), rate-gate (CR-DS-8), range gate (CR-DS-9), Eve-silence check (CR-DS-10), `is_instance_valid(actor)` check.
2. Emit order: `Events.dialogue_line_started.emit(line.speaker_id, line.id)` fires in step 3 — before `_audio_player.play()` in step 4. This gives Audio's 0.3 s ducking attack a head start (GDD §C.11).
3. Dual-completion guard: `_audio_finished_flag: bool` and `_caption_timer_flag: bool`. `dialogue_line_finished` emits only when both are true. `_on_audio_finished()` short-circuits when `_stopping_for_interrupt = true`.
4. Watchdog `WatchdogTimer.wait_time = max(audio_duration_s, duration_metadata_s, 5.0) + 1.0` — v0.3 floor reduced to 5.0 s. On watchdog fire: call `_audio_player.stop()` FIRST, then force-emit `dialogue_line_finished()` (stop-before-emit ordering per CR-DS-21 v0.3).
5. Rate-gate uses `Time.get_ticks_msec() / 1000.0` (wall-clock monotonic — NOT affected by `Engine.time_scale` or pause). Dictionary purge at every `dialogue_line_finished` emission per CR-DS-8 v0.2.
6. `_section_range_override_m: float = -1.0` exported property for per-section tuning (CR-DS-9).
7. `D&S MUST NOT subscribe to its own signals` — FP-DS-1. `_ready()` must not call `Events.dialogue_line_started.connect(...)` or `Events.dialogue_line_finished.connect(...)`.

Dependency injection seam for testing: `_time_provider: Callable` defaulting to `Time.get_ticks_msec` — injectable mock clock for deterministic AC-6 assertion.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `DialogueLine` resource schema + signal declarations on `Events.gd` (must be DONE before this story)
- Story 003: Self-suppression subscriptions (`document_opened`, `document_closed`, `ui_context_changed`) + `_caption_suppressed` flag + visibility state machine
- Story 004: `SubtitleLabel` typography, Theme resource, `auto_translate_mode`, layout spec (96 px offset, 62%/896 px width, `PRESET_BOTTOM_CENTER`)
- Story 005: Integration test — Plaza BQA briefing smoke; Audio subscriber ducking handshake verification
- Post-VS: full 5-tier priority resolver with COMBAT_DISCOVERY, ESCALATION, IDLE buckets; guard banter library; `civilian_panicked` / `weapon_fired_in_public` subscriptions; `scripted_dialogue_trigger` MLS subscription

---

## QA Test Cases

**AC-1 — 7-step lifecycle + emit ordering**
- **Given**: `DialogueAndSubtitles` test scene with mock `Events`, mock `AudioStreamPlayer` (spy), valid `DialogueLine` (speaker `&"GUARD_PHANTOM_ANON"`, id `&"test_line_01"`, mock audio 2.0 s)
- **When**: `select_line(trigger_context)` is called and the lifecycle runs
- **Then**: `Events.dialogue_line_started` spy records call before `_audio_player.play()` spy; both spies record exactly one call; `dialogue_line_finished` does NOT emit until mock `_audio_player.finished` fires AND `CaptionTimer.timeout` fires
- **Edge cases**: reverse order (play before emit) — test fails if dialogue_line_started spy records after play spy

**AC-2 — Zero-length audio rejection (FP-DS-21)**
- **Given**: `DialogueLine` with mock `AudioStream` returning `get_length() = 0.05` (< 0.1 s)
- **When**: `select_line()` called with this line matching all filters
- **Then**: `select_line()` returns `null`; `push_error` logged with line id; `dialogue_line_started` NOT emitted
- **Edge cases**: exactly 0.1 s (boundary) — must be accepted (not rejected); exactly 0.09 s — rejected

**AC-3 — Dual-completion guard**
- **Given**: line in flight, `CaptionTimer.timeout` fires but `_audio_player.finished` has not yet
- **When**: `_on_caption_timer_timeout()` handler runs
- **Then**: `dialogue_line_finished` NOT emitted; `_caption_timer_flag = true` recorded internally
- **When**: `_audio_player.finished` fires
- **Then**: `dialogue_line_finished` emits exactly once; `_label.text` cleared; state HIDDEN

**AC-4 — exit_tree teardown**
- **Given**: line in flight with active `Events.*` subscriptions
- **When**: `_exit_tree()` called (mock scene tree removal)
- **Then**: `_audio_player.stop()` called; `dialogue_line_finished` emitted; `_label.text` cleared; all `is_connected()` calls for documented subscriptions return `false` after teardown
- **Edge cases**: double-disconnect guard — `is_connected()` checked before each `disconnect()` call, no crash on stale connection

**AC-5 — Watchdog timeout**
- **Given**: line in flight, mock `_audio_player.finished` permanently suppressed, `audio_duration_s = 1.0`, `duration_metadata_s = 0.0`; mock-clock seam injected
- **When**: mock-clock advanced by 6.0 s (watchdog `wait_time = max(1.0, 0.0, 5.0) + 1.0 = 6.0 s`)
- **Then**: `_audio_player.stop()` called FIRST (before force-emit); `dialogue_line_finished` force-emitted with `push_error` containing line id; `_label.text` cleared; state HIDDEN — in that exact order
- **Edge cases**: watchdog fires when caption timer has already fired (partial-completion) — same teardown sequence applies

**AC-6 — Rate-gate mock-clock**
- **Given**: `_actor_last_bark_time[GuardA]` injected at `135.0 s` via mock-clock seam; `dialogue_per_actor_cooldown_s = 8.0`
- **When**: `select_line()` called at mock-clock `142.3 s` (7.3 s elapsed)
- **Then**: `is_eligible(GuardA) = false`; return `null`
- **When**: mock-clock advanced to `143.1 s`
- **Then**: `is_eligible(GuardA) = true`

**AC-7 — Range gate**
- **Given**: player at `Vector3(0, 0, 0)`, `dialogue_bark_range_m = 25.0`
- **When**: actor at `Vector3(12, 0, 5)` — distance = 13.0 m
- **Then**: `in_range = true`
- **When**: actor at `Vector3(30, 0, 0)` — distance = 30.0 m
- **Then**: `in_range = false`
- **Edge cases**: exactly 25.0 m — `in_range = true` (boundary inclusive)

**AC-8 — No per-frame callback (performance)**
- **Given**: `dialogue_and_subtitles.gd` source
- **When**: CI runs `grep -L "_process\|_physics_process" dialogue_and_subtitles.gd`
- **Then**: returns the filename (file contains neither callback — confirming 0.0 ms steady-state cost)

**AC-9 — Forbidden pattern greps**
- **Given**: `dialogue_and_subtitles.gd`
- **When**: `grep -n ".connect(" dialogue_and_subtitles.gd` cross-referenced with `_process`/`_physics_process` lines
- **Then**: zero `.connect()` calls inside process callbacks
- **When**: `grep -n "await get_tree().create_timer"`
- **Then**: zero matches

**AC-10 — Voice bus routing**
- **Given**: `DialogueAndSubtitles.tscn`
- **When**: `AudioLinePlayer.bus` property inspected (via scene inspection or grep `bus =`)
- **Then**: `bus = "Voice"`; `grep -r "bus.*=.*SFX\|bus.*=.*Music\|bus.*=.*Master" DialogueAndSubtitles.tscn` returns zero matches

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/dialogue_subtitles/orchestrator_lifecycle_test.gd` — must exist and pass (AC-1 through AC-9)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (`DialogueLine` resource + `Events.dialogue_line_started`/`finished` declarations must exist)
- Unlocks: Story 003 (suppression logic needs the orchestrator node to exist), Story 005 (Plaza smoke needs orchestrator + renderer)
