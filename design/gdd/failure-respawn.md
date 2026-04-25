# Failure & Respawn

> **Status**: Revised pending re-review (major revision 2026-04-24 — see `design/gdd/reviews/failure-respawn-review-log.md`)
> **Author**: User + `/design-system` skill + specialists (game-designer, systems-designer per routing). Revisions by `/design-review` (7 specialists + creative-director senior synthesis).
> **Last Updated**: 2026-04-24 (major revision addressing `/design-review` MAJOR REVISION NEEDED verdict — 21 blockers resolved inline. Structural fixes: CR-5/CR-6 rewritten to live-authoritative flag; CR-7 IDLE-guard resolves States-table↔CR-12 contradiction AND queued-respawn G-7 checkpoint-overwrite defect; CR-8 gains sting-suppression + subscriber re-entrancy fence; CR-10 gains single-emit + watchdog; F.1 rewritten for live-authoritative; F.2 marked PROVISIONAL pending ADR-0001 storage-tier escalation; E.20 rationale flipped to explicit tradeoff; 7 blocking ACs rewritten (AC-FR-1.1 synchronous, AC-FR-2.1 isolated-scenario, AC-FR-3.1 DI hook, AC-FR-5.5 null-injection spec, AC-FR-6.2 BLOCKED pending engine-gate, AC-FR-10.1 hardware-pin, AC-FR-10.2 → Playtest type); 2 new ACs (AC-FR-12.4 sole-publisher CI lint, AC-FR-12.5 re-entrancy CI lint); BLOCKING items table grew 5→12; 6 new OQs (OQ-FR-7 storage tier escalation, OQ-FR-8 signal isolation, OQ-FR-9 Jolt body_exited, OQ-FR-10 stealth-stuck-alive, OQ-FR-11 Restart-from-Checkpoint, OQ-FR-12 LOAD_FROM_SAVE farm-exploit, OQ-FR-13 progressive-punishment, OQ-FR-14 geometry-clip watchdog, OQ-FR-15 dart-mid-sedation race); 3 new DGs (DG-FR-5 signal-isolation, DG-FR-6 schema forward-compat, DG-FR-7 GD recommendations). AC count 38→40. Specialist-convergent structural defect (flag split-brain, S-4/G-1/G-2) is the diagnostic finding — first-death floor grant was inverted in original spec.)
> **Last Verified**: 2026-04-24 (post-revision, pending `/design-review` in fresh session per creative-director protocol)
> **Implements Pillar**: Pillar 3 (Stealth is Theatre, Not Punishment — detection escalates, death is rare, respawn is sectional and fast); Pillar 2 (Discovery Rewards Patience — low-friction retry encourages experimentation)

## Overview

Failure & Respawn is the **Gameplay-layer orchestrator** that catches the moment Eve dies and puts her back into the section in 2–3 seconds without breaking the theatre. When `Events.player_died` fires — from bullets, a blade, a fall out of bounds, or (rare at MVP) from a scripted mission-fail condition — F&R assembles a slot-0 autosave from the current world state, applies the Combat-owned ammo respawn floor (first-death-per-checkpoint only, anti-farm), emits `Events.respawn_triggered(section_id)` to cue Audio's cut-to-silence and 2.0 s fade-in, hands the SaveGame to Level Streaming's `reload_current_section()`, restores its own local state inside the LS step-9 restore callback, and finally calls `PlayerCharacter.reset_for_respawn(checkpoint)` to put Eve on her feet. F&R is one of three authorized callers of `LevelStreamingService.reload_current_section` (alongside Mission & Level Scripting and Menu System) and is the **sole publisher** of the Failure/Respawn signal domain per ADR-0002:183. The player never sees a "You Died" screen, never a full-mission reload, never a tutorial quip — Pillar 3 governs the beat, which means **house lights up between scenes**, not punishment. Death is rare by design (graduated-suspicion stealth + ammo-scarce combat + kill-plane as bug-recovery only); when it does land, F&R's job is to make the retry invisible enough that the player's next thought is *"try a different route,"* not *"load a save."*

> **Quick reference** — Layer: `Gameplay` · Priority: `MVP` · Effort: `M` · Key deps: `Save/Load`, `Stealth AI` (`player_died` trigger), **`Mission & Level Scripting` (sectional checkpoint contract — PROVISIONAL, upstream not yet designed)**, `Player Character` (`reset_for_respawn`), `Combat & Damage` (`DeathCause`, `respawn_floor_*`), `Level Streaming` (`reload_current_section`, step-9 restore callback), `Audio` (respawn SFX handshake) · Signal owned: `Events.respawn_triggered(section_id: StringName)` (ADR-0002:183)

## Player Fantasy

Eve does not die well. She does not die badly either. She simply stops — mid-step, mid-breath, mid-plan — and the scene, with the politeness of a long-running West End production, re-sets itself around her absence. A beat of silence. The music collects itself. She is on her feet again at the previous landing, somewhat the wiser, entirely unacknowledged by the world that just killed her.

The game will not tell her she has failed. It will not tell the player, either. The guard who shot her is back on patrol, humming. The dossier she was reaching for is exactly where she left it. It is, in the gentlest possible sense, as if nothing happened — which, in the grammar of 1960s spy fiction, is how one is *supposed* to behave after a setback.

This is the quiet promise underneath Pillar 3: getting caught is not a reprimand, it is a reshuffle. And once the player trusts that, Pillar 2 opens up. Every corridor becomes a thing to test rather than fear. Every odd sightline becomes an invitation. Eve, after all, has the entire evening.

- **Pillar 3 (Stealth is Theatre, Not Punishment)**: the death→respawn beat is ~2–3 seconds of silent fade, scene-reset, and return to the last checkpoint. No "You Died" screen; no modal "Retry?" button; no kill-cam. Detection costs dramatic possibility; death costs a breath.
- **Pillar 2 (Discovery Rewards Patience)**: because failure is cheap, the patient observer feels *permitted* to experiment. A wrong guess is three seconds of silence. A right one rewrites the floor.
- **Pillar 5 (Period Authenticity Over Modernization)**: every modern failure-UX convention — death screen, damage-direction vignette, "You were detected" banner, mission-fail cutscene — is absent by design. The period idiom is restraint; the system performs it.

Players never praise the respawn system by name. They praise the game for **staying out of the way** when they fail.

## Detailed Design

### Core Rules

**CR-1 — Single trigger source.** F&R subscribes to `Events.player_died(cause: CombatSystemNode.DeathCause)` at autoload `_ready()`. This is the sole entry point into the respawn flow at MVP.
*Why: Mission-fail events are not designed at MVP (user scope decision 2026-04-24). A single source keeps idempotency simple.*

**CR-2 — Idempotency guard.** On `player_died` receipt, F&R drops the signal silently if internal `_flow_state != IDLE`. No retry, no queue.
*Why: Two-layer defense alongside PC's `_latched_event`. PC's latch prevents re-emit per-death; F&R's `_flow_state` check tolerates duplicate subscriptions or test-harness anomalies.*

**CR-3 — Kill-plane death is identical to combat death.** PC's kill-plane Area3D (at `kill_plane_y = -50 m`) calls `apply_damage(999.0, pc, DamageType.FALL_OUT_OF_BOUNDS)`, which routes through PC F.6 and emits `Events.player_died(DeathCause.ENVIRONMENTAL)`. F&R treats it identically to a combat death.
*Why: No special-case branch needed; the signal contract is already uniform.*

**CR-4 — F&R writes a fresh slot-0 save at death time, then hands the same in-memory SaveGame to LS.** On CAPTURING entry, F&R calls `SaveLoadService.save_to_slot(0, assembled_save)` synchronously. F&R then passes the *same in-memory `SaveGame` object* to `LevelStreamingService.reload_current_section(assembled_save)` — no re-read from disk. **No `await` may be interposed between the save call and the LS call** (godot-specialist-verified: would break the ordering guarantee on Godot's single-threaded main loop).
*Why: Per Save/Load §Edge Cases — "player's most recent intent wins." A fresh death-time slot-0 write captures `_current_checkpoint` and ammo snapshot; re-reading disk would be redundant and add a rename-race surface.*

**CR-5 — Respawn floor is applied on load via Inventory, not baked into the save. LIVE-authoritative read at step 9.** The SaveGame written at step 4 holds the raw ammo snapshot (dying-state totals). At LS step-9 restore callback, F&R computes `should_apply_floor` by reading its **live autoload member** `_floor_applied_this_checkpoint: bool` (NOT from the restored `FailureRespawnState` sub-resource — see CR-6 for the live↔save relationship) and calls `Inventory.apply_respawn_floor_if_needed(snapshot, should_apply_floor)`. If `should_apply_floor == true`, Inventory performs the `max(snapshot_total, floor) → clamp [0, max_reserve]` math against its live state AND F&R advances its live `_floor_applied_this_checkpoint = true` immediately after Inventory returns (synchronously, same call-stack). Combat's `respawn_floor_pistol_total = 16`, `respawn_floor_dart_total = 8`, `respawn_floor_rifle_total = -1` constants remain Combat-owned.
*Why: Keeps mid-section manual saves clean (floor isn't persisted on pickup-only saves), co-locates the ammo math with Inventory's live weapon state, and matches Inventory's existing `register_restore_callback` pattern. F&R owns the policy; Inventory owns the mechanism. The **live-authoritative** read-source resolves the split-brain risk that a restored SaveGame-side flag would have (if F&R read from the restored save at step 9, the dying-state value already advanced to `true` at step 3's capture and should_apply_floor would incorrectly evaluate `false` on first death — behavior inverted from intent). See §F.1 for the flag-transition state machine. (OQ-FR-B resolution.)*

**CR-6 — `FailureRespawnState` sub-resource is the serialized mirror of the live flag, not its authoritative source.** F&R owns `FailureRespawnState extends Resource` with `@export var floor_applied_this_checkpoint: bool = false` AND an explicit `func _init(flag: bool = false) -> void: floor_applied_this_checkpoint = flag` constructor (per ADR-0003 Resource contract). F&R also holds a live autoload member `_floor_applied_this_checkpoint: bool = false`. This sub-resource is added to `SaveGame` (save-schema coordination item — see §Interactions table). **Read/write contract** — (a) **At capture (step 3)**: F&R's `FailureRespawnState.capture(live_value: bool)` static returns a new FailureRespawnState mirroring the current live value; no advance happens at capture; (b) **At restore (load path, game_loaded handler)**: F&R hydrates its live member from `save.failure_respawn_state.floor_applied_this_checkpoint`; (c) **At step 9 (RESPAWN restore callback)**: F&R reads LIVE only; advances live to `true` after Inventory applies the floor; (d) **On `section_entered(non-RESPAWN)` while `_flow_state == IDLE`**: F&R resets LIVE to `false` per CR-7. Live is authoritative; save always mirrors. Schema is forward-extensible (Resource additivity) — `checkpoint_id: StringName` or `Dictionary[StringName, bool]` may be added post-MVP when Mission Scripting introduces mid-section checkpoints; no FORMAT_VERSION bump required under ADR-0003's additive-field rule.
*Why: A session that quits after the first death and reloads must still respect the anti-farm invariant. An unserialized flag would grant a second free floor refill on the next death after reload. The live-vs-save split in this CR ensures the live member is the sole read-source during a respawn flow while the save remains the persistence vehicle across quit/reload. (OQ-FR-A resolution.)*

**CR-7 — Flag reset and checkpoint capture are gated by `_flow_state == IDLE`.** F&R subscribes to `Events.section_entered(section_id, reason: LevelStreamingService.TransitionReason)`. Handler behavior:
- **If `_flow_state != IDLE`** (RESTORING, or — only during CR-10 queued-respawn — forward-section's `section_entered(FORWARD)` arrives mid-RESTORING): handler dispatches only the `reset_for_respawn` path (step 12) when `reason == RESPAWN`; all other work (flag reset, `_current_checkpoint` overwrite) is SKIPPED. Guard is `if _flow_state != IDLE: … handle RESPAWN dispatch only; return`.
- **If `_flow_state == IDLE` AND `reason ∈ {FORWARD, NEW_GAME, LOAD_FROM_SAVE}`**: F&R writes `_floor_applied_this_checkpoint = false` (live) AND re-captures `_current_checkpoint` from the scene's `player_respawn_point: Marker3D` (CR-11).
- **If `_flow_state == IDLE` AND `reason == RESPAWN`**: no-op (RESPAWN during IDLE is unreachable under normal play — RESPAWN fires only during CR-12 step 11, which is always within RESTORING).

*Why: `RESPAWN` means F&R itself caused the transition; resetting the flag there re-opens the farm loop (per Combat §F.6 anti-farm rule). The `_flow_state == IDLE` guard on state-mutating branches resolves: (a) the States-table / CR-12 contradiction (RESTORING permits `reset_for_respawn` dispatch but forbids mutation), AND (b) the CR-10 queued-respawn overwrite defect where a forward-section's `FORWARD` emit mid-RESTORING would otherwise overwrite `_current_checkpoint` to the wrong section and Eve would teleport to the wrong respawn point.*

**CR-8 — `respawn_triggered` is emitted BEFORE `reload_current_section` is called. Mission-failure sting is SUPPRESSED on the respawn path.** Order: (1) F&R pushes `InputContext.LOADING`, (2) F&R assembles + writes slot-0 save, (3) F&R emits `Events.respawn_triggered(current_section_id)`, (4) F&R calls `LevelStreamingService.reload_current_section(save_game)`. **Subscriber re-entrancy is forbidden**: no `respawn_triggered` subscriber may (a) call any `LevelStreamingService` method, or (b) emit further `Events.*` signals, from within its handler. F&R-authored grep lint enforces this on Combat + SAI + Audio sources (see AC-FR-12.4). **Sting suppression**: the mission-failure sting Audio plays on `player_died` is suppressed when `player_died` enters F&R's CAPTURING path at MVP — Audio's `player_died` handler must check a no-op condition when `respawn_triggered` fires within ≤100 ms of the same `player_died` (per Audio GDD coord item, see §Dependencies). The theatre beat is silence + calm fade, not a layered sting-over-silence.
*Why: Audio subscribes to `respawn_triggered` to begin the silence gap. Audio must start the gap BEFORE LS begins its own fade tween, otherwise silence and LS fade overlap incorrectly. In-flight darts (self-subscribed) and `GuardFireController` (self-subscribed) also need the signal before LS starts freeing scene nodes. The sting-suppression rule resolves the audio-contract defect where the 2–3 s trumpet swell on `player_died` (Audio GDD L506) would otherwise clip at ~15 ms (no drama) OR layer on top of the calm fade-in (incoherent). Per creative-director senior ruling 2026-04-24: "house lights up between scenes" requires the silence beat to be intact; the trumpet belongs only to terminal mission failure (not designed at MVP). Subscriber re-entrancy fence prevents runaway synchronous signal chains that would re-enter F&R's own flow mid-emit (godot-specialist E-2).*

**CR-9 — InputContext stack: F&R and LS each push/pop independently (Option B).** F&R pushes `InputContext.LOADING` on `player_died` receipt and pops it when the flow completes (post `reset_for_respawn`). LS's own `LOADING` push/pop at its step 1 and step 13 is independent. Stack resolves correctly: `[GAMEPLAY, LOADING(F&R), LOADING(LS)]` → LS pops at step 13 → `[GAMEPLAY, LOADING(F&R)]` → F&R pops → `[GAMEPLAY]`. ADR-0004 is a true push/pop stack (not replace-top; `_stack.size() > 1` underflow assert at pop), so symmetric pairs compose.
*Why: F&R's ~100 ms window between `player_died` and `reload_current_section` must already be input-blocked, or gameplay input leaks into the capture/emit phase.*

**CR-10 — Queued-respawn (mid-transition double-fire) is tolerated passively; `respawn_triggered` fires exactly once.** If `reload_current_section` is called while LS is already mid-transition, LS queues the call and fires it at step 13 of the in-flight transition (LS GDD CR-6). Worst-case mechanical flow ~1.14 s (0.57 s forward + 0.57 s respawn); perceived beat ~2.7 s with Audio's fade overlapping. F&R does not retry, cancel, or detect this condition. F&R's `LOADING` push persists through both transitions; it pops when the final `reset_for_respawn` returns. **Single-emit guarantee**: `Events.respawn_triggered(section_id)` fires exactly ONCE at step 5 of the initial death flow — NOT again when the queued respawn fires from LS step-13. Audio's in-flight ease-in from the first emit covers the extended mechanical duration. **N-bound**: LS's queue is depth-1 per LS CR-6 (a second queue-while-queued overwrites — last-wins). F&R therefore never observes N>2 mechanical transitions. A debug-build `push_error` fires if `_flow_state` has been RESTORING for >2.5 s (watchdog — indicates LS queue depth exceeded the documented contract OR a subscriber stalled the callback chain).
*Why: LS owns the queueing contract. F&R's state machine stays in RESTORING across any number of LS transitions until the callback fires; the extra `LOADING` push on the stack is harmless. Single-emit is load-bearing for Audio — a second `respawn_triggered` would re-trigger the silence + fade-in and either restart the ease-in (disruptive) or race the in-flight tween (indeterminate). The N-bound depends on LS's depth-1 queue; the 2.5 s watchdog catches violations loud rather than letting F&R strand in RESTORING indefinitely.*

**CR-11 — `Checkpoint` is assembled at section entry (IDLE only), not at death time.** [PROVISIONAL] On `Events.section_entered(_, FORWARD | NEW_GAME | LOAD_FROM_SAVE)` AND `_flow_state == IDLE` (per CR-7 guard), F&R reads the current section scene's `player_respawn_point: Marker3D` node via `get_tree().current_scene.find_child("player_respawn_point", true, false)` (recursive=true, owned=false — matches section-authoring contract) and stores a `Checkpoint` resource as `_current_checkpoint`. On death, `_current_checkpoint` is passed to `PC.reset_for_respawn()` at step 12. `Checkpoint` resource lives in `src/gameplay/shared/checkpoint.gd` (NOT in F&R's autoload directory) to avoid a PC → F&R load-order dependency; PC's `reset_for_respawn(checkpoint: Checkpoint)` signature type-checks against the shared class.
*Why: Death-time assembly would require scene-tree queries during CAPTURING while cleanup may be in progress. Pre-assembly at section entry is deterministic and survives the dying-state save. IDLE-guard prevents queued-respawn (CR-10) forward-transition `section_entered(FORWARD)` from overwriting the checkpoint to the wrong section mid-RESTORING. `find_child` with `recursive=true, owned=false` is the explicit lookup contract — forbids deferred-add-child patterns from satisfying the contract (Mission Scripting coord item must section-validation-CI enforce presence in the non-deferred tree). Marked PROVISIONAL pending Mission Scripting GDD confirming the Marker3D authoring contract.*

**CR-12 — Ordered respawn flow with timing budgets.**

| Step | Action | Timing |
|------|--------|--------|
| 1 | `player_died` received; check `_flow_state == IDLE` | ~0 ms |
| 2 | Transition to CAPTURING; push `InputContext.LOADING` | ~0 ms |
| 3 | Assemble SaveGame from live state (`*_State.capture()` on each sub-resource; `FailureRespawnState.capture(_floor_applied_this_checkpoint)` mirrors the **live** value per CR-6 — no advance at capture) | ~1 ms |
| 4 | `SaveLoadService.save_to_slot(0, assembled_save)` — synchronous, ≤15 ms (ADR-0003 must forbid internal `await` per coord item — see §Dependencies) | ~5–15 ms |
| 5 | Emit `Events.respawn_triggered(current_section_id)` | ~0 ms |
| 6 | `LevelStreamingService.reload_current_section(assembled_save)` — hands to LS | — |
| 7 | LS runs 13-step swap (2-frame snap-out + SWAPPING instantiate ≤500 ms + 2-frame snap-in); total ≤0.57 s per LS §Quick reference | ~570 ms worst |
| 8 | LS step 9: F&R's restore callback fires synchronously | ~0 ms |
| 9 | F&R reads **LIVE** `_floor_applied_this_checkpoint` (not from the restored save — see CR-5/CR-6); computes `should_apply_floor`; calls `Inventory.apply_respawn_floor_if_needed(snapshot, should_apply_floor)`. If `should_apply_floor == true`, advance LIVE `_floor_applied_this_checkpoint = true` synchronously after Inventory returns. | ~0 ms |
| 10 | Next assembled save (on next `section_entered` or death) mirrors live and therefore carries `floor_applied_this_checkpoint = true` | deferred |
| 11 | LS step 12: `section_entered(id, RESPAWN)` emits | — |
| 12 | F&R's `section_entered` handler is entered; `_flow_state == RESTORING`, so per CR-7 the handler dispatches only the `RESPAWN` path → calls `PlayerCharacter.reset_for_respawn(_current_checkpoint)`. Checkpoint overwrite + flag reset are SKIPPED. | ~0 ms |
| 13 | Pop `InputContext.LOADING`; `_flow_state` → IDLE | ~0 ms |

**Total mechanical flow**: ~0.58 s (typical) from `player_died` to input-active — dominated by LS's ≤0.57 s swap. **Total player-perceivable flow**: ~2.2 s because Audio's 200 ms silence + 2.0 s ease-in (starting at step 5) overlaps steps 5–12 and extends past step 13 — the ear hears the fade complete after gameplay has already resumed. The perceived "respawn beat" is audio-driven by design (Pillar 3 theatre feel).

### States and Transitions

| State | Description | Blocks | Allows |
|-------|-------------|--------|--------|
| **IDLE** | Normal running state; no respawn in progress | Nothing | Processes `player_died`; processes `section_entered` for checkpoint update + flag reset |
| **CAPTURING** | `player_died` received; writing slot-0 save and emitting `respawn_triggered` | Further `player_died` (CR-2 drop) | Save/Load calls; signal emit; LS handoff |
| **RESTORING** | LS transition in progress; waiting for step-9 restore callback | Further `player_died` (CR-2 drop); **state-mutating** `section_entered` branches — flag reset AND checkpoint overwrite are SKIPPED per CR-7 IDLE-guard, regardless of `reason` | LS step-9 callback; `Inventory.apply_respawn_floor_if_needed`; **only the `section_entered(_, RESPAWN)` dispatch path** that calls `PC.reset_for_respawn` (step 12); InputContext pop |

> **Disambiguation note**: RESTORING is the ONLY state where `section_entered` fires with state-mutating-branches intentionally suppressed. Under CR-10 queued-respawn, a forward-section `section_entered(FORWARD)` CAN arrive mid-RESTORING — the CR-7 `_flow_state != IDLE` guard is the critical defense: it prevents `_current_checkpoint` from being overwritten with the forward section's marker (which would teleport Eve to the wrong respawn point on the queued respawn).

**Transition table:**

| From | Event | To | Guard |
|------|-------|----|-------|
| IDLE | `Events.player_died` | CAPTURING | `_flow_state == IDLE` (else drop) |
| CAPTURING | `reload_current_section` handed to LS | RESTORING | SaveGame written; signal emitted |
| RESTORING | `reset_for_respawn` returns; LOADING popped | IDLE | Restore callback fired; PC teleported |
| CAPTURING ∨ RESTORING | `Events.player_died` | (stay) | CR-2 drop |

There is no explicit QUEUED state; the LS queued-respawn scenario (CR-10) is opaque to F&R's state machine — RESTORING covers the full duration of any number of LS transitions until the callback fires.

### Interactions with Other Systems

| System | GDD | Direction | Contract |
|--------|-----|-----------|----------|
| **Player Character** | `design/gdd/player-character.md` ✅ Approved | upstream source + downstream target | Receives `Events.player_died(cause)` (PC emits on health ≤ 0 per PC F.6 including kill-plane path). Calls `PC.reset_for_respawn(checkpoint: Checkpoint)` at step 12. `Checkpoint` type is **owned by this GDD**; PC carries placeholder subclass per PC §Tuning Knobs. |
| **Combat & Damage** | `design/gdd/combat-damage.md` ✅ Approved | upstream (constants) | Consumes `respawn_floor_pistol_total = 16`, `respawn_floor_dart_total = 8`, `respawn_floor_rifle_total = -1`, and `CombatSystemNode.DeathCause` enum. F&R owns the *policy* (`floor_applied_this_checkpoint` state + first-death-per-checkpoint rule); Combat owns the *constants*; Inventory owns the *mechanism* (ammo math). |
| **Inventory & Gadgets** | `design/gdd/inventory-gadgets.md` ✅ Approved pending coord | downstream (API call) | **COORDINATION ITEM**: Inventory GDD must add `apply_respawn_floor_if_needed(snapshot, should_apply_floor) -> void` as a public API on `InventoryService`. F&R calls this at LS step-9. Logic: for each weapon, `restored_total = max(snapshot.total, floor)` then clamp to `[0, max_reserve]`; rifle with sentinel `-1` preserves snapshot unchanged. |
| **Save/Load** | `design/gdd/save-load.md` ✅ Approved pending re-review | bidirectional | Calls `SaveLoadService.save_to_slot(0, assembled_save)` at step 4 (synchronous). **COORDINATION ITEM**: `SaveGame` schema must gain a new `FailureRespawnState` sub-resource (single field `floor_applied_this_checkpoint: bool`). Save/Load GDD §Interactions table row + ADR-0003 §SaveGame schema need the addition. Touch-up only — no version bump needed if schema is `FORMAT_VERSION = 1` pre-MVP-lock. |
| **Level Streaming** | `design/gdd/level-streaming.md` ✅ Approved | downstream (caller + callback registrant) | Calls `LevelStreamingService.reload_current_section(save_game)` at step 6. Registers restore callback at autoload `_ready()` via `LevelStreamingService.register_restore_callback(_on_restore)`. Subscribes to `Events.section_entered(id, reason)` for checkpoint capture (CR-11) and floor-flag reset (CR-7). |
| **Audio** | `design/gdd/audio.md` ✅ Approved | downstream (signal only) | Emits `Events.respawn_triggered(section_id)` at step 5; Audio subscribes (200 ms silence + 2.0 s fade-in to `[section]_calm`). Audio also handles `player_died(cause)` directly for the mission-failure sting. F&R does not call Audio APIs. |
| **Stealth AI** | `design/gdd/stealth-ai.md` ✅ Approved | downstream (signal only; self-subscribe) | `GuardFireController` and individual guards self-subscribe to `respawn_triggered` per SAI GDD. On signal: cadence timers stop, cross-guard propagation dict clears. F&R does not touch guards directly; restoration of alert-state + patrol-index is handled by SAI's own save-restore path via each guard's `actor_id`-keyed `GuardRecord`. |
| **Input** | `design/gdd/input.md` Designed | downstream (stack caller) | Pushes `InputContext.LOADING` at step 2; pops at step 13. Per ADR-0004 true-stack semantics; coexists with LS's own push/pop via Option B (CR-9). |
| **Signal Bus** | `design/gdd/signal-bus.md` Revised pending re-review | bidirectional | **Publishes** `Events.respawn_triggered(section_id: StringName)` (Failure/Respawn domain, sole publisher, per ADR-0002:183). **Subscribes** `Events.player_died`, `Events.section_entered`. |
| **Mission & Level Scripting** | `design/gdd/mission-level-scripting.md` ⏳ Not Started | upstream (scene contract) [PROVISIONAL] | Assumes section scenes carry `player_respawn_point: Marker3D` (per LS CR-9 authoring). F&R composes `Checkpoint` from this at `section_entered`. Mid-section checkpoints are Mission Scripting's extension point if designed later; `Checkpoint` resource supports `checkpoint_id: StringName` for this. |
| **Document Collection** | `design/gdd/document-collection.md` ⏳ Not Started | indirect (via SaveGame) [PROVISIONAL] | Dying-state slot-0 save captures whatever `DocumentCollectionState` is at death time. If a document was collected mid-section before death, it remains collected after respawn. Document Collection GDD (VS scope) must confirm this is intended behavior. Flagged as OQ-FR-3. |

## Formulas

F&R is a thin orchestrator; the mathematical surface is small by design. The ammo-floor transformation (`max(snapshot_total, floor) → clamp [0, max_reserve]`) lives in Inventory per CR-5 / OQ-FR-B. The `should_apply_floor` predicate is a direct field read from `FailureRespawnState.floor_applied_this_checkpoint` — already fully specified by CR-5 through CR-7 and not restated here. What remains are two pieces: a state-transition table for the floor flag, and a performance-gate timing budget for the total respawn flow.

### F.1 — Floor flag transition rule (LIVE-authoritative)

The **live** autoload member `_floor_applied_this_checkpoint: bool` on F&R is the authoritative read-source at step 9 (CR-5/CR-6). The `FailureRespawnState` sub-resource inside `SaveGame` mirrors the live value at capture time; on load it hydrates the live member. All transitions below are on the **live** member. The serialized copy never transitions independently — it is always `capture(live)` or hydrated-from-save.

| Trigger | `prev (live)` | `next (live)` | Guard | Condition |
|---|---|---|---|---|
| `section_entered(_, FORWARD ∨ NEW_GAME ∨ LOAD_FROM_SAVE)` | any | **false** | `_flow_state == IDLE` (per CR-7) | Fresh checkpoint — the next death in this section may apply the floor once. If guard fails (mid-RESTORING), NO-OP. |
| `section_entered(_, RESPAWN)` | any | **unchanged** | — | F&R caused this transition; resetting the flag here re-opens the farm loop. |
| `section_entered(_, any)` during `_flow_state != IDLE` | any | **unchanged** | — | Explicit NO-OP for mid-RESTORING arrivals (queued-respawn forward-section, or any future `TransitionReason` extension). Safe default preserves anti-farm. |
| Step 9 restore callback with `prev == false` | `false` | **true** | `_flow_state == RESTORING` | First death of this checkpoint — floor applies at step 9 (CR-5); live advances to `true` synchronously after `Inventory.apply_respawn_floor_if_needed` returns. |
| Step 9 restore callback with `prev == true` | `true` | **true** | `_flow_state == RESTORING` | Subsequent death in the same checkpoint — snapshot-only restore; live remains set. |
| Load-from-slot path (game_loaded handler) | any | **save.failure_respawn_state.floor_applied_this_checkpoint** | hydrate only | Cross-session restore — live mirrors the save; next `section_entered` then runs reset-guard per row 1. |
| `FailureRespawnState` deserializes with missing/null flag | any | **false** | hydrate fallback | Per E.20 defensive rule — corrupt save defaults to permissive floor grant on next death. |

**Output range**: `{true, false}` — two states.
**Default arm for novel `TransitionReason`**: any unrecognized value arriving via `section_entered` — `push_warning("F&R: unrecognized TransitionReason %s — live flag preserved" % reason)` and preserve live. Conservative-on-anti-farm default; explicit forward-compatibility seam for Mission Scripting extension.
**Example**: Player enters Restaurant section (`section_entered(FORWARD)`, `_flow_state == IDLE` → live = false). Dies to a guard (`player_died`, step 9 reads live=false → floor applies, pistol restored from 6 → 16 total, dart from 3 → 8 total; live advances to true synchronously after Inventory returns). Dying-state save at step 3 already captured live=false; next save (on next `section_entered` FORWARD or next death) will capture live=true and mirror it. Kills six guards, spends magazine down to 4 rounds, dies again (`player_died`, step 9 reads live=true → floor does NOT apply; pistol restored to 4 rounds — the anti-farm invariant holds). Reaches section exit; next `section_entered(FORWARD)` guarded by `_flow_state == IDLE` resets live to false.

### F.2 — Total respawn duration (timing budget) — **PROVISIONAL pending ADR-0001 min-spec storage tier amendment**

This is a **performance gate**, not a balance formula. It sums constants owned by upstream systems to produce the end-to-end felt latency F&R must stay under.

> **PROVISIONAL label**: the table below assumes **SSD warm-cache** storage on min-spec Intel Iris Xe class hardware. ADR-0001 does NOT currently declare a min-spec storage tier (SSD vs HDD). A min-spec HDD would push `t_swap` to 2–4 s (4–8× the value shown), inverting the entire budget. **Escalated to technical-director**: an ADR-0001 amendment is required to declare the storage tier before AC-FR-10.1 / AC-FR-10.2 can be treated as hard pass/fail gates. Until it lands, AC-FR-10.1 is a **warm-SSD gate only** and AC-FR-10.2 is a playtest-gated observation (not a pass/fail assertion). See §Open Questions OQ-FR-7.

`total_respawn_duration_s = t_save + t_snap_out + t_swap + t_snap_in + t_reset`

| Variable | Owner | Value (SSD warm) | Source |
|---|---|---|---|
| `t_save` | Save/Load | ≤ 0.015 s (budget); ≤0.010 s typical per ADR-0008 non-frame table | ADR-0003 ≤10 ms typical, ≤15 ms budget; ADR-0008 Slot 8 pooled residual. **ADR-0003 coord item**: must forbid internal `await` inside `save_to_slot(0, ...)` (see §Dependencies). |
| `t_snap_out` | Level Streaming | ~0.033 s (2 frames @ 60 fps) | LS §Tuning `FADE_OUT_FRAMES = 2` (2026-04-21 senior-director hard-cut ruling; supersedes the prior 0.3 s dissolve spec) |
| `t_swap` | Level Streaming | ≤ 0.5 s (SWAPPING state budget) on SSD warm; **UNBOUNDED on HDD cold pending ADR-0001** | LS §States; min-spec Intel Iris Xe per ADR-0001 (storage tier pending) |
| `t_snap_in` | Level Streaming | ~0.033 s (2 frames @ 60 fps) | LS §Tuning `FADE_IN_FRAMES = 2` |
| `t_reset` | Player Character | ~0.001 s | PC synchronous reset per PC F.6 |
| **Total mechanical (best / typical, warm SSD)** | | **~0.167 s** | Warm section cache, fast SSD; arithmetic: 0.015 (ceil-save) + 0.033 + ~0.1 (warm `t_swap` floor, observed) + 0.033 + 0.001. Best-case `t_swap` on warm cache is implementation-observable ~0.1 s; the figure depends on section scene size and is not a formal lower bound. |
| **Total mechanical (worst single-transition, SSD cold)** | | **~0.58 s** | Cold cache SSD; matches LS `total_transition_budget_s ≤ 0.57 s` + t_save + t_reset. Independent-variable assumption: I/O contention can push joint worst toward 0.7 s if `t_save` and `t_swap` compete on a slow SATA SSD. |
| **Total mechanical (worst with queued-respawn CR-10)** | | **~1.14 s** | Double-transition worst case per LS CR-6 (0.57 s forward + 0.57 s respawn). LS queue depth=1 per LS CR-6 bounds N=2; F&R's 2.5 s watchdog per CR-10 catches any violation. |
| **Total mechanical (min-spec HDD cold, PROVISIONAL)** | | **UNBOUNDED** | Flagged for TD. On 7200 RPM SATA HDD, multi-MB scene file load can reach 2–4 s. If min-spec declares HDD support, F.2 budget + AC-FR-10.x must be re-derived. |
| **Player-perceived (audio-dominated)** | | **~1.6 s target** | Audio's silence gap + fade ease-in; F&R requests Audio GDD amendment to retune current 0.2 s / 2.0 s → ~0.4 s silence + ~1.2 s ease-in per creative-director ruling 2026-04-24 (house-lights-up theatre beat requires a perceptible silence + brisk fade, not a short stutter + slow sigh). Pending Audio GDD amendment — see §Dependencies. |

**Design intent**: single-transition mechanical completes in ≤0.58 s on warm SSD (LS-dominated). The **player's perceived respawn beat target is ~1.6 s** (post-amendment) — driven by Audio's fade, not the scene swap. The ear hears the fade complete shortly after gameplay has resumed; this is the Pillar 3 theatre feel (music rebuilds to calm as Eve takes her first step back). Anything longer than ~2.5 s perceived starts to read as "load a save" rather than "scene reset." The CR-10 queued-respawn mechanical worst (~1.14 s) bounds the pathological case. **Correlated-variable caveat**: the ≤0.58 s figure sums per-system budgets as if independent; cold-disk joint worst can exceed this. AC-FR-10.1 is a warm-SSD gate; HDD / cold / joint-worst scenarios are playtest-gated observations until the ADR-0001 storage-tier decision lands.

## Edge Cases

### A. Same-frame / race conditions

- **[E.1 · CR-2] If `Events.player_died` fires while `_flow_state == CAPTURING`**: F&R drops the signal silently; in-progress save completes normally. Two-layer defense (PC `_latched_event` + F&R `_flow_state`) makes duplicate emits harmless.
- **[E.2 · CR-2] If `Events.player_died` fires while `_flow_state == RESTORING`**: Identical drop. Arrives only from test harnesses or duplicate subscribers in practice.
- **[E.3 · CR-11] If Eve takes lethal damage on the exact frame she crosses a `section_exited` boundary**: `section_exited` fires first (LS Area3D overlap is higher tick priority); `section_entered` overwrites `_current_checkpoint` with the new section; then `player_died` fires. Eve respawns in the *destination* section. Correct — she committed to the new section.
- **[E.4 · CR-2] If Eve "dies" during LS step-9 restore callback of an in-flight respawn**: Structurally impossible under normal play — `_flow_state == RESTORING` drops at CR-2; PC `_latched_event` already cleared. In test-harness forcing, the drop fires correctly and PC is not re-reset.
- **[E.5 · CR-3] If kill-plane `apply_damage` and a guard bullet both resolve same physics tick**: PC `_latched_event` latches on the first signal received; the second is dropped at PC level. `DeathCause` reflects whichever resolved first. F&R is agnostic to cause; no behavioral difference.

### B. Save/Load failures during respawn

- **[E.6 · CR-4] If `SaveLoadService.save_to_slot(0, …)` returns `IO_ERROR` during CAPTURING**: F&R logs the error and continues with the already-assembled **in-memory `SaveGame` object** passed to `reload_current_section`. Respawn succeeds; slot-0 on disk is stale. **OQ-FR-4: should F&R surface a non-blocking "Auto-save failed" HUD warning?** *(Advisory; UX-owned.)*
- **[E.7 · CR-4] If disk is full during slot-0 write**: Identical outcome to E.6 — IO_ERROR surfaced by Save/Load (its §Edge Cases owns the `save_failed` signal dialog); F&R continues with in-memory save. Respawn is not aborted.
- **[E.8 · CR-4] If existing slot 0 is `CORRUPT` when F&R calls `save_to_slot(0, …)`**: Save/Load overwrites via atomic write; CORRUPT is a read-time flag, not a write-gate. New save is clean. No special F&R handling.

### C. Checkpoint / section anomalies

- **[E.9 · CR-11, CR-2] If `_current_checkpoint` is `null` when `player_died` fires** (e.g., debug cheat at game boot before any `section_entered`): CAPTURING proceeds; at step 12 PC receives `reset_for_respawn(null)`. **OQ-FR-5 (BLOCKING for pre-sprint): PC GDD must specify null-checkpoint fallback — recommend teleport-to-`Vector3.ZERO` + `push_warning`.**
- **[E.10 · CR-11] If `player_respawn_point: Marker3D` is missing from a section scene (authoring error)**: F&R's `section_entered` handler finds no matching node; `_current_checkpoint` keeps its prior value or stays null. F&R logs `push_error`; section-validation CI must catch this (authoring-gate, not runtime-gate).
- **[E.11 · CR-11] If `player_respawn_point` is positioned inside geometry or off navmesh**: PC teleports exactly there; Jolt resolves the collision push reactively, Eve may clip or fall briefly. Authoring error — section-validation CI + playtest catches. F&R has no navmesh awareness and must not acquire it.

### D. Input / context stack anomalies

- **[E.12 · CR-9] If MENU context is on the stack when `player_died` fires** (possible only via debug paths; pause menu cannot pop during combat damage in practice): Stack `[GAMEPLAY, MENU]` → F&R pushes → `[GAMEPLAY, MENU, LOADING]` → LS push/pop → F&R pop → `[GAMEPLAY, MENU]`. Pause menu still on top post-respawn, which is correct — player can resume or unpause as they wish.
- **[E.13 · CR-9] If player attempts to open Pause during the 2.5 s respawn flow**: `InputContext.LOADING` masks `ui_pause` per Input GDD; action does not route. Pause cannot be opened during the flow.
- **[E.14 · CR-9, CR-12] If window focus is lost mid-LS-transition** (LS CR-15 pause-on-focus-lost): LS pauses the transition tween; F&R remains RESTORING with its LOADING push intact. On focus return, LS resumes, step-9 callback fires, F&R completes. Respawn duration extends by focus-lost duration — outside the F.2 budget but not a defect.

### E. Ammo floor edges

- **[E.15 · CR-5] If Eve has 0 darts AND 0 pistol rounds AND `floor_applied_this_checkpoint == false` on death**: Floor applies. Pistol raised 0 → 16, darts 0 → 8. Intentional softlock-prevention per Combat §F.6 — a player who exhausted all ammo would otherwise be unable to proceed. Trades anti-farm purity for forward momentum.
- **[E.16 · CR-5] If Eve has ammo ABOVE the floor on death** (e.g., 20 pistol rounds): `Inventory.apply_respawn_floor_if_needed` computes `max(20, 16) = 20`. No change — floor is a minimum, not an assignment.
- **[E.17 · CR-5] If rifle is in inventory with `snapshot.rifle_total == 0` and sentinel `respawn_floor_rifle_total = -1`**: Sentinel means "preserve snapshot." Rifle stays at 0 until pickup. Intentional — rifle is a bonus weapon, not safety-net.
- **[E.18 · CR-5] If rifle was never picked up (no rifle entry in snapshot)**: Inventory iterates entries; no rifle key processed; no synthesized entry. Logic skips cleanly.

### F. FailureRespawnState corruption / legacy saves

- **[E.19 · CR-6] If a save predating the `FailureRespawnState` field is loaded**: Per ADR-0003 refuse-load-on-mismatch, SaveLoad rejects the load before F&R sees it. Pre-ship QA hits this after any `FORMAT_VERSION` bump; QA must re-create saves — documented in QA onboarding, not runtime.
- **[E.20 · CR-6] If `FailureRespawnState.floor_applied_this_checkpoint` deserializes as `null` or the field is absent**: F&R's load-path hydrator treats `null`/missing as `false` and sets live `_floor_applied_this_checkpoint = false` with `push_warning`. **Explicit tradeoff** (rationale per 2026-04-24 revision): this is a **permissive-on-corruption** default — a corrupt save grants a free floor on next death. The alternative (`null → true`, deny floor) is **safe-on-anti-farm** but risks a softlock on genuine corruption. We prefer "accidental floor grant" over "accidental softlock": a player whose save is corrupt has already had a worse-than-average session; the game should err toward forward momentum, not reinforce the corruption with ammo denial. The `push_warning` ensures the event is logged for post-session diagnosis. The FailureRespawnState resource has an explicit `func _init(flag: bool = false)` constructor per ADR-0003 Resource-subclass contract, so a freshly-constructed instance is always `false` — `null` only arises from schema evolution or hex-edit tampering.

### G. Kill-plane specific

- **[E.21 · CR-3] If Eve crosses kill-plane while `_is_hand_busy == true`** (mid-gadget interaction): PC `reset_for_respawn` clears `_is_hand_busy` per PC L166; interaction cancelled cleanly. No special F&R handling.
- **[E.22 · CR-3] If a bullet is mid-flight when Eve crosses kill-plane**: Both events may fire same or adjacent ticks; PC `_latched_event` latches on whichever resolves first. F&R is cause-agnostic. **OQ-FR-6: confirm Jolt tick ordering (Area3D overlap vs RigidBody body_entered same physics step).** *(Advisory; godot-specialist engine-verification gate.)*

### H. Autoload lifecycle

- **[E.23 · CR-11] If F&R autoload `_ready()` runs before any section is loaded** (normal at boot): `_current_checkpoint = null`, `_flow_state = IDLE`. Both valid initial states. `player_died` at this moment routes through E.9 handling.
- **[E.24 · CR-2] If Godot editor hot-reload fires while `_flow_state == CAPTURING` or `RESTORING`**: Editor reload destroys autoloads; fresh F&R instance boots with `_flow_state = IDLE`. Any in-flight LS step-9 callback fires to the new instance (callback re-registered unconditionally in `_ready()`). Dev-only pathology; ship builds have no hot-reload. QA note: after hot-reload mid-respawn, trigger a new death or use `_debug_force_idle()`. Document in dev onboarding, not runtime recovery code.

### I. Cross-GDD signal timing

- **[E.25 · CR-8] If a `respawn_triggered` subscriber is not yet in the scene tree** (e.g., first frame of a new section; dart already freed): Godot fires to currently-connected callables; absent subscribers simply miss the signal. Dart already gone = fine (nothing to clean up); GuardFireController not yet instantiated = fine (guards haven't started firing). No defect.
- **[E.26 · CR-8] If an Audio `respawn_triggered` handler crashes (unhandled exception)**: Godot signal delivery is per-callable; one crashing callable does not block delivery to the other subscribers. Respawn flow continues; Audio may be in a broken state (no fade-in) — that's Audio's bug, not F&R's. F&R has no responsibility to catch or retry subscriber exceptions.

## Dependencies

The §Detailed Design → Interactions table lists per-system data flows. This section groups them by nature (hard / soft / ADR / forbidden) to support sequencing and architecture review.

### Upstream dependencies (hard — F&R cannot function without them)

| System | GDD | Nature | Why hard |
|---|---|---|---|
| **Signal Bus** (system 1, ADR-0002) | `design/gdd/signal-bus.md` | `Events.player_died` subscription; `Events.respawn_triggered` emit; `Events.section_entered` subscription | Without the typed bus, F&R cannot be triggered, cannot notify Audio/darts/GuardFireController, and cannot detect section transitions |
| **Player Character** | `design/gdd/player-character.md` ✅ | `Events.player_died` publisher; `reset_for_respawn(Checkpoint)` callee | The trigger source and the restore target |
| **Save/Load** | `design/gdd/save-load.md` ✅ pending re-review | `save_to_slot(0, save_game)` callee; `SaveGame` schema (coord item: add `FailureRespawnState` sub-resource) | F&R assembles + persists the dying-state save; no flow without it |
| **Level Streaming** | `design/gdd/level-streaming.md` ✅ | `reload_current_section(save_game)` callee; `register_restore_callback(_on_restore)` callee; `Events.section_entered(id, reason)` publisher | The scene-reload orchestrator; F&R cannot execute the visual respawn without LS |
| **Combat & Damage** | `design/gdd/combat-damage.md` ✅ | `CombatSystemNode.DeathCause` enum consumer; `respawn_floor_pistol_total = 16`, `respawn_floor_dart_total = 8`, `respawn_floor_rifle_total = -1` constants | Trigger metadata + anti-farm constants |
| **Inventory & Gadgets** | `design/gdd/inventory-gadgets.md` ✅ pending coord | `Inventory.apply_respawn_floor_if_needed(snapshot, should_apply_floor)` callee (coord item — Inventory GDD must add the public API) | Executes the ammo-floor mechanism per CR-5 / OQ-FR-B |

### Upstream dependencies (provisional — upstream not yet designed)

| System | GDD | Nature | Provisional assumption |
|---|---|---|---|
| **Mission & Level Scripting** | `design/gdd/mission-level-scripting.md` ⏳ Not Started | Section scenes authored to carry a `player_respawn_point: Marker3D` child (per LS CR-9 section contract) | F&R assembles `Checkpoint` resource from this node at `section_entered`. Mid-section checkpoints are a Mission Scripting extension point; `Checkpoint` reserves `checkpoint_id: StringName` for that future use. **Flagged as a forward-dependency coordination item pending Mission Scripting GDD.** |

### Downstream dependents

| System | GDD | Direction | Nature |
|---|---|---|---|
| **Audio** | `design/gdd/audio.md` ✅ | Audio → `respawn_triggered` subscriber | Plays mission-failure sting on `player_died`; 200 ms silence + 2.0 s ease-in to `[section]_calm` on `respawn_triggered`. F&R does not call Audio directly. |
| **Stealth AI** | `design/gdd/stealth-ai.md` ✅ | SAI → `respawn_triggered` subscriber (per-guard + GuardFireController self-subscription) | Guards stop cadence timers; cross-guard propagation dict clears. SAI state restore (alert-state, patrol-index) rides Save/Load's save-restore path keyed by `actor_id`, not a direct F&R call. |
| **HUD State Signaling** | `design/gdd/hud-state-signaling.md` ⏳ Not Started (VS scope) | Indirect | Consumes `Events.player_health_changed` which PC re-emits during `reset_for_respawn`. F&R has no direct coupling. Noted for completeness. |
| **In-flight effects (darts, VFX)** | owned by Combat + Inventory | self-subscription pattern | Each in-flight dart `RigidBody3D` self-subscribes to `respawn_triggered` and `queue_free()`s itself (Combat GDD §F.6 pattern). F&R's only role is emitting the signal. |

### Soft dependencies (F&R works without them, but they enhance it)

| System | GDD | Enhancement |
|---|---|---|
| **Input** | `design/gdd/input.md` Designed | `InputContext` autoload — F&R works without push/pop in single-player debug builds; ship must push LOADING to block gameplay input during the flow |
| **Localization Scaffold** | `design/gdd/localization-scaffold.md` Designed | None at MVP — F&R has no player-facing strings; a future OQ-FR-4 HUD warning would localize through this system |

### ADR dependencies

| ADR | Nature |
|---|---|
| **ADR-0002** (Signal Bus + Event Taxonomy) | F&R is the sole publisher of the Failure/Respawn signal domain (`respawn_triggered`); enum ownership (`CombatSystemNode.DeathCause`, `LevelStreamingService.TransitionReason`) consumed |
| **ADR-0003** (Save Format Contract) | `SaveGame` schema — F&R adds a new `FailureRespawnState` sub-resource (coord item); atomic write semantics; `duplicate_deep()` on load contract |
| **ADR-0004** (UI Framework) | `InputContext` stack push/pop semantics (true stack, not replace-top) — underpins CR-9 Option B |
| **ADR-0007** (Autoload Load Order Registry) | F&R autoload placement at line 8 after `Combat` — **coord item: ADR-0007 amendment required** before sprint |
| **ADR-0008** (Performance Budget Distribution) | Total respawn duration (F.2) consumes LS + Audio + PC sub-budgets; F&R's own per-frame cost is ~0 ms outside the flow |

### Forbidden non-dependencies (explicitly NOT deps)

These are systems F&R must not hold references to or call into. Recorded for code-review and to prevent drift.

| System | Why forbidden |
|---|---|
| **HUD Core / HUD State Signaling** | F&R publishes `respawn_triggered`; HUD subscribes if it wants. F&R must not reach into HUD to "show respawn text" — Pillar 5 forbids a "You Died" surface. |
| **Document Collection** | Document persistence rides the SaveGame assembly path; F&R doesn't touch documents directly. Deferred cross-check via OQ-FR-3 when Document Collection is designed. |
| **Civilian AI** | Civilians are state-restored via the SaveGame path, same as Stealth AI. F&R does not touch civilians. |
| **Cutscenes & Mission Cards** | Cutscenes are gated by `MissionState.triggers_fired` (Save/Load → Mission). F&R has no concept of "which cutscene plays next." |
| **Menu System** | Menu does not route through F&R for respawn. "Load Game" is a Menu flow into Save/Load, not F&R. |

### Bidirectional consistency check

- PC GDD (§Dependencies + §Respawn contract): ✓ lists F&R as `subscribes + calls; reset_for_respawn(checkpoint)` consumer
- Combat GDD (§Dependencies): ✓ lists Failure & Respawn as "Subscribes to `player_died(cause: DeathCause)`; reads `respawn_floor_*` constants"
- Save/Load GDD: ⚠ **CONFLICT** — save-load.md L100 + L151 still say F&R uses `load_from_slot(0)` during respawn (stale; F&R CR-4 uses in-memory handoff — no re-read from disk). Save/Load GDD touch-up required (coord item). Also ⚠ missing `FailureRespawnState` sub-resource in §Interactions / schema.
- Level Streaming GDD: ✓ lists Failure & Respawn as authorized caller of `reload_current_section` + `register_restore_callback`. ⚠ LS GDD must document replace-semantics on `register_restore_callback` (coord item — stale-Callable hot-reload crash depends on this).
- Audio GDD: ✓ subscribes to `respawn_triggered` (Failure/Respawn domain) + `player_died`. ⚠ amendment required: sting-suppression on respawn path + retune `respawn_silence_s` 0.2 → ~0.4 s + `respawn_fade_in_s` 2.0 → ~1.2 s per creative-director 2026-04-24 ruling (coord item).
- Signal Bus GDD: ⚠ L122 currently says F&R "Subscribes to Combat (player_died)" only — must add F&R's `section_entered` subscription (coord item, minor touch-up).
- Input GDD: ⚠ `InputContext.LOADING` not currently mentioned anywhere in input.md; F&R CR-9 assumes it exists as an upstream capability. Input GDD must add LOADING context spec (coord item).
- Inventory GDD: ⚠ must gain `apply_respawn_floor_if_needed` API (coord item). Inventory L312 currently describes `restore_weapon_ammo(floor_dict)` — reconcile naming + policy/mechanism split.
- ADR-0003: ⚠ add `FailureRespawnState` sub-resource schema; forbid internal `await` inside `save_to_slot(0, ...)`; atomic-commit fence for `FailureRespawnState.gd` + `save_game.gd` same-PR landing (coord items).
- ADR-0001: ⚠ **ESCALATED TO TECHNICAL-DIRECTOR** — declare min-spec storage tier (SSD vs HDD); F.2 timing budget + AC-FR-10.x are PROVISIONAL until this lands.
- Mission Scripting: ⏳ not yet designed (provisional forward-dep); authoring contract includes non-deferred `player_respawn_point: Marker3D` + section-validation CI (coord item).
- Shared `Checkpoint` class: ⚠ must live at `src/gameplay/shared/checkpoint.gd` (NOT in F&R autoload directory) to avoid PC → F&R load-order dep (coord item).

## Tuning Knobs

F&R has a deliberately thin tuning surface. Most player-felt knobs (audio fade timings, floor ammo values, scene-swap timing) are **owned by upstream systems** and not restated here — changing them is those systems' concern. F&R's own knobs are policy-locks and debug toggles.

### F&R-owned knobs (policy)

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `FR_AUTOLOAD_POSITION` | line 8 (after `Combat`) | Locked | Per ADR-0007 amendment (coord item). Tunable only via ADR amendment. |
| `FR_FAILURE_TRIGGER_SIGNALS` | `{Events.player_died}` | Locked at MVP | Adding mission-fail triggers is an MVP scope expansion requiring design review. |
| `FR_FLOW_STATE_INITIAL` | `IDLE` | Locked | Autoload always boots in IDLE. |
| `FR_CHECKPOINT_MARKER_NODE_NAME` | `"player_respawn_point"` | Locked (string match) | The `Marker3D` node name F&R searches for per CR-11. Section-authoring contract. |

### F&R-owned knobs (debug / testing)

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `FR_VERBOSE_LOGGING` | `false` (release), `true` (debug) | Boolean | Emit detailed `print()` of state transitions, flag reads, Inventory API calls. Release builds default off. |
| `FR_SIMULATE_SAVE_FAILURE` | `false` | Boolean | Debug-only. Forces `save_to_slot(0, ...)` path to simulate an IO_ERROR (via Save/Load's own `SIMULATE_IO_FAILURE` hook) so F&R's E.6 fallback can be exercised. |
| `FR_DEBUG_FORCE_IDLE()` | (method) | Dev-only | Manual unstick for editor hot-reload pathology (E.24). Resets `_flow_state → IDLE` and pops any stale LOADING push F&R may have left on the stack. Never exposed in ship builds. |
| `FR_DEBUG_FORCE_DEATH()` | (method) | Dev-only | Manual trigger firing a synthetic `Events.player_died(DeathCause.UNKNOWN)` for testing the flow without combat or kill-plane. QA tool. |

### Registry-owned knobs consumed by F&R (reference only)

| Parameter | Owner | Purpose in F&R |
|---|---|---|
| `respawn_floor_pistol_total = 16` (safe `[8, 32]`) | Combat & Damage | Anti-farm floor minimum pistol total. Consumed by Inventory via CR-5. |
| `respawn_floor_dart_total = 8` (safe `[4, 16]`) | Combat & Damage | Same for darts. |
| `respawn_floor_rifle_total = -1` (sentinel) | Combat & Damage | Preserve-snapshot marker for rifle. |
| `respawn_silence_s = 0.2` (safe `[0.0, 0.5]`) | Audio | Silence gap between `respawn_triggered` and fade-in. F&R does not tune — Audio owns. |
| `respawn_fade_in_s = 2.0` (safe `[1.0, 3.0]`) | Audio | Ease-in to `*_calm` after respawn. F&R does not tune — Audio owns. |
| `kill_plane_y = -50.0` m | Player Character | Kill-plane world Y; triggers `DamageType.FALL_OUT_OF_BOUNDS`. F&R receives the resulting `player_died`. |
| LS `fade_out_s`, `snap_frames`, `fade_in_s` | Level Streaming | Per LS GDD — drive F.2 timing-budget sum. |

### Knobs that DO NOT exist at MVP (anti-feature registry)

These are "absent knobs" — modern games ship them; F&R deliberately doesn't.

| Absent knob | Why absent |
|---|---|
| `DEATH_SCREEN_DURATION_S` | There is no death screen (Pillar 5). |
| `RETRY_BUTTON_ENABLED` | No "Retry?" modal (Pillar 5). |
| `DEATH_CAM_ENABLED` | No kill-cam (Pillar 5). |
| `MISSION_FAILURE_STATE_ENABLED` | No terminal game-over at MVP (scope-locked 2026-04-24). |
| `RESTART_FROM_CHECKPOINT_MENU_ACTION` | No Pause-Menu restart button at MVP (scope-locked 2026-04-24). Player uses Load Game. |
| `MAX_DEATHS_BEFORE_GAME_OVER` | There is no death counter. |
| `DIFFICULTY_SCALED_RESPAWN_FLOOR` | Difficulty tiers explicitly deliberately-omitted per systems-index. |
| `PLAYER_INITIATED_RESPAWN_HOTKEY` | No "kill yourself" button. |

## Visual/Audio Requirements

**None directly owned.** F&R has zero visual or audio assets of its own; its entire player-facing surface is handled through signal-emit to downstream systems that own the assets.

| Player-facing effect | Owned by | Trigger |
|---|---|---|
| Mission-failure sting (Music bus) | Audio — `design/gdd/audio.md` | Audio subscribes to `Events.player_died(cause)` |
| 200 ms silence gap + 2.0 s fade-in to `*_calm` | Audio | Audio subscribes to `Events.respawn_triggered(section_id)` |
| Fade-out + 2-frame snap + fade-in scene transition | Level Streaming — `design/gdd/level-streaming.md` | LS executes its 13-step swap on `reload_current_section(save_game)` |
| In-flight dart `queue_free()` (no visible artifact) | Combat — `design/gdd/combat-damage.md` §Dart cleanup | Each dart self-subscribes to `respawn_triggered` |
| GuardFireController timer stop + dict clear | Stealth AI — `design/gdd/stealth-ai.md` | Self-subscription to `respawn_triggered` |
| Camera dip on damage, HUD health flash | Player Character + HUD Core | Not F&R's concern; PC re-emits `player_health_changed` during `reset_for_respawn` |

No asset spec is authored here. No `/asset-spec system:failure-respawn` run needed.

## UI Requirements

**None.** F&R has no player-facing UI surface by design.

Pillar 5 (Period Authenticity Over Modernization) forbids:
- "You Died" / "Mission Failed" text overlays
- Retry / Continue modal dialogs
- Death cam or "slain by" attribution widgets
- Damage-direction vignettes (moved to Enhanced Hit Feedback accessibility toggle, owned by Settings — not F&R)
- Respawn loading progress bars (the 2.0 s audio fade IS the respawn UI)

Player feedback during the 2.5 s flow is entirely aural (Audio's silence + fade) and visual-but-incidental (LS's scene-swap fade). The player's last frame of gameplay hard-cuts to black via LS; the next thing they see is Eve at the checkpoint, already interactive. This is intentional and load-bearing for the "house lights up between scenes" metaphor anchored in §Player Fantasy.

If **OQ-FR-4** resolves toward a non-blocking "Auto-save failed" HUD warning on IO_ERROR, that widget is owned by HUD State Signaling (system 19, VS scope), not by F&R. Any such widget routes through `Events.save_failed` (Save/Load publishes it) or a new advisory signal that F&R would emit — to be decided by UX at that time.

## Acceptance Criteria

Evidence paths base: `tests/unit/failure_respawn/` (Logic), `tests/integration/failure_respawn/` (Integration), `production/qa/evidence/failure_respawn/` (Visual/Feel, UI).

### 1. Trigger & Idempotency

**AC-FR-1.1 [Logic]** — **GIVEN** F&R is in `_flow_state == IDLE`, **WHEN** `Events.player_died(DeathCause.SHOT)` is emitted **synchronously** via test harness (direct `Events.player_died.emit(DeathCause.SHOT)` — NOT `call_deferred`), **THEN** `_flow_state` reads as `CAPTURING` **before the `emit()` call returns** (synchronous same-call-stack transition; verified via call-stack-local state read immediately after the emit call) AND `SaveLoadService.save_to_slot` is called exactly once within the same call stack. `[CR-1, CR-2]` Evidence: `tests/unit/failure_respawn/trigger_idempotency_test.gd`

**AC-FR-1.2 [Logic]** — **GIVEN** `_flow_state == CAPTURING`, **WHEN** a second `Events.player_died(DeathCause.SHOT)` is emitted, **THEN** `_flow_state` remains `CAPTURING`, `save_to_slot` call count does not increase, AND no `push_error` is raised. `[CR-2, E.1]` Evidence: `tests/unit/failure_respawn/trigger_idempotency_test.gd`

**AC-FR-1.3 [Logic]** — **GIVEN** `_flow_state == RESTORING`, **WHEN** `Events.player_died(DeathCause.SHOT)` is emitted, **THEN** `_flow_state` remains `RESTORING` AND no further state machine transition occurs. `[CR-2, E.2, E.4]` Evidence: `tests/unit/failure_respawn/trigger_idempotency_test.gd`

**AC-FR-1.4 [Logic]** — **GIVEN** `_flow_state == IDLE`, **WHEN** `Events.player_died` is emitted with each valid `CombatSystemNode.DeathCause` enum value, **THEN** `CAPTURING` is entered for all values (F&R is cause-agnostic). `[CR-1]` Evidence: `tests/unit/failure_respawn/trigger_idempotency_test.gd`

### 2. Kill-Plane Path

**AC-FR-2.1 [Integration]** — **GIVEN** Eve's world Y position is above `kill_plane_y = -50 m` and NO other damage source is active (isolated scenario), **WHEN** Eve's Y drops to -50 m or below, **THEN** `Events.player_died(DeathCause.ENVIRONMENTAL)` is emitted exactly once AND F&R enters `CAPTURING` via the standard CR-12 flow. The `DeathCause.ENVIRONMENTAL` assertion is valid only in this isolated test (no simultaneous bullet). **Simultaneous-with-bullet case** is covered by separate test `tests/integration/failure_respawn/kill_plane_simultaneous_bullet_test.gd` which asserts "exactly one `player_died` fires with ANY valid `DeathCause`" — per Godot 4.6 Jolt's non-deterministic contact-resolution ordering, the specific cause is engine-observable-but-not-guaranteed. `[CR-3, E.5, E.22, DG-FR-2]` Evidence: `tests/integration/failure_respawn/kill_plane_path_test.gd`, `tests/integration/failure_respawn/kill_plane_simultaneous_bullet_test.gd`

**AC-FR-2.2 [Logic]** — **GIVEN** a kill-plane `player_died` arrives while `_is_hand_busy == true` on PC (injected via test double), **WHEN** the respawn flow completes at step 12, **THEN** `PC._is_hand_busy` is `false` (cleared by `reset_for_respawn`) AND no F&R-specific hand-busy handling is present in source. `[CR-3, E.21]` Evidence: `tests/integration/failure_respawn/kill_plane_path_test.gd`

### 3. Save Write & In-Memory Handoff

**AC-FR-3.1 [Logic]** — **GIVEN** F&R is constructed with injected test doubles for `SaveLoadService` and `LevelStreamingService` (DI hook pattern — F&R must expose `_inject_save_load(svc)` and `_inject_level_streaming(svc)` setters for test use, or accept optional service references in `_ready()` via autoload lookup with test-override), **WHEN** `Events.player_died` fires and `CAPTURING` processes normally, **THEN** `save_to_slot(0, save_game)` is called exactly once with the assembled `SaveGame` object, AND `reload_current_section(save_game)` is called immediately after with the **same object reference** (identity check via `assert_same`, not value equality). The no-`await` requirement is enforced by AC-FR-12.3 grep lint on F&R source — NOT by runtime observation (runtime `await`-vs-no-`await` is not observable via a frame-tick spy because synchronous code within a single `_process` tick executes without yielding regardless of internal `await` in callees). `[CR-4]` Evidence: `tests/unit/failure_respawn/save_handoff_test.gd`

**AC-FR-3.2 [Logic]** — **GIVEN** `FR_SIMULATE_SAVE_FAILURE = true` (forces `IO_ERROR` from `save_to_slot`), **WHEN** `Events.player_died` fires, **THEN** the in-memory `SaveGame` is still passed to `reload_current_section` (respawn is not aborted) AND `push_error` is called AND `_flow_state` continues through `RESTORING` to `IDLE`. `[CR-4, E.6, E.7]` Evidence: `tests/unit/failure_respawn/save_handoff_test.gd`

**AC-FR-3.3 [Integration]** — **GIVEN** a slot-0 file on disk flagged `CORRUPT`, **WHEN** `Events.player_died` fires and F&R calls `save_to_slot(0, …)`, **THEN** `SaveLoadService` performs an atomic overwrite (no special F&R guard required) AND the post-write slot-0 file loads without corruption error. `[CR-4, E.8]` Evidence: `tests/integration/failure_respawn/save_handoff_test.gd`

### 4. Ammo Floor Logic

**AC-FR-4.1 [Logic]** — **GIVEN** `floor_applied_this_checkpoint == false` and a dying-state ammo snapshot of `{pistol_total: 6, dart_total: 3, rifle_total: absent}`, **WHEN** `Inventory.apply_respawn_floor_if_needed(snapshot, should_apply_floor=true)` is called, **THEN** live inventory reads `pistol_total = 16`, `dart_total = 8`, no rifle entry synthesized. `[CR-5, E.15, E.18]` Evidence: `tests/unit/failure_respawn/ammo_floor_test.gd`

**AC-FR-4.2 [Logic]** — **GIVEN** dying-state `{pistol_total: 20, dart_total: 10}` and `should_apply_floor = true`, **WHEN** `apply_respawn_floor_if_needed` is called, **THEN** live inventory reads `pistol_total = 20`, `dart_total = 10` (floor is a minimum, not an assignment). `[CR-5, E.16]` Evidence: `tests/unit/failure_respawn/ammo_floor_test.gd`

**AC-FR-4.3 [Logic]** — **GIVEN** dying-state `{rifle_total: 0}` and sentinel `respawn_floor_rifle_total = -1` and `should_apply_floor = true`, **WHEN** `apply_respawn_floor_if_needed` is called, **THEN** live inventory `rifle_total` remains `0` (sentinel preserves snapshot unchanged). `[CR-5, E.17]` Evidence: `tests/unit/failure_respawn/ammo_floor_test.gd`

### 5. Floor Flag State Machine

**AC-FR-5.1 [Logic]** — **GIVEN** `FailureRespawnState.floor_applied_this_checkpoint == false`, **WHEN** `Events.section_entered(section_id, TransitionReason.FORWARD)` fires, **THEN** the next assembled save carries `floor_applied_this_checkpoint = false`. `[CR-7, F.1]` Evidence: `tests/unit/failure_respawn/floor_flag_state_machine_test.gd`

**AC-FR-5.2 [Logic]** — **GIVEN** `floor_applied_this_checkpoint == true`, **WHEN** `Events.section_entered(section_id, TransitionReason.RESPAWN)` fires, **THEN** the flag in the next assembled save remains `true` (RESPAWN transition must NOT reset the flag). `[CR-7, F.1, E.19]` Evidence: `tests/unit/failure_respawn/floor_flag_state_machine_test.gd`

**AC-FR-5.3 [Logic]** — **GIVEN** `floor_applied_this_checkpoint == false` and a first death in the section, **WHEN** `Events.player_died` fires and CAPTURING proceeds, **THEN** the assembled save carries `floor_applied_this_checkpoint = true` AND `apply_respawn_floor_if_needed` is called with `should_apply_floor = true`. `[CR-6, F.1]` Evidence: `tests/unit/failure_respawn/floor_flag_state_machine_test.gd`

**AC-FR-5.4 [Logic]** — **GIVEN** `floor_applied_this_checkpoint == true` and a second death in the same section, **WHEN** `Events.player_died` fires, **THEN** `apply_respawn_floor_if_needed` is called with `should_apply_floor = false` AND the flag does not change from `true`. `[CR-6, CR-7, F.1]` Evidence: `tests/unit/failure_respawn/floor_flag_state_machine_test.gd`

**AC-FR-5.5 [Logic]** — **GIVEN** a test injects a `FailureRespawnState` into F&R's hydrator with the field explicitly set to `null` via **direct field assignment on a test-double subclass** (bypassing GDScript's `@export` type coercion: the test uses a `FailureRespawnStateNullable extends FailureRespawnState` subclass that overrides `_init()` to leave the field unset), **WHEN** F&R's load-path hydrator runs, **THEN** live `_floor_applied_this_checkpoint` is set to `false`, `push_warning` is emitted (verified via a log-spy on `Engine.get_main_loop().log_messages`), AND the next `player_died` path applies the floor (regression guard — verifies the null→false→floor-applies sequence is one self-consistent cycle). `[CR-6, E.20]` Evidence: `tests/unit/failure_respawn/floor_flag_state_machine_test.gd`

**AC-FR-5.6 [Integration]** — **GIVEN** `floor_applied_this_checkpoint == true`, then a session quit and reload via `LOAD_FROM_SAVE`, **WHEN** `section_entered(_, LOAD_FROM_SAVE)` fires on reload, **THEN** the next assembled save carries `floor_applied_this_checkpoint = false` (anti-farm invariant survives cross-session reload). `[CR-6, CR-7, E.19, F.1]` Evidence: `tests/integration/failure_respawn/floor_flag_state_machine_test.gd`

### 6. Signal Ordering & respawn_triggered

**AC-FR-6.1 [Logic]** — **GIVEN** a test subscriber to `Events.respawn_triggered` that records call order, **WHEN** `Events.player_died` fires and CAPTURING runs, **THEN** `Events.respawn_triggered(section_id)` is emitted **before** `LevelStreamingService.reload_current_section` is called (call order: push → assemble → save → emit → reload_current_section). `[CR-8]` Evidence: `tests/unit/failure_respawn/signal_ordering_test.gd`

**AC-FR-6.2 [Logic]** 🚫 **BLOCKED pending godot-specialist engine-verification gate** (Godot 4.6 signal delivery isolation on subscriber exceptions is not independently verified) — **GIVEN** a mock Audio subscriber that emits `push_error` (non-crashing) or throws an unhandled exception in its `respawn_triggered` handler, **WHEN** F&R emits `respawn_triggered`, **THEN** F&R continues to call `reload_current_section` after the handler returns AND `_flow_state` progresses to `RESTORING`. The `push_error` (soft-error) path is testable now. The "throws unhandled exception" path is BLOCKED — whether Godot 4.6 swallows or propagates unhandled GDScript exceptions across signal callbacks must be confirmed by godot-specialist engine-verification before this AC's harder branch is treated as pass/fail. `[CR-8, E.26, DG-FR-5]` Evidence: `tests/unit/failure_respawn/signal_ordering_test.gd` (push_error branch only until gate closes)

**AC-FR-6.3 [Logic]** — **GIVEN** no subscriber is connected to `respawn_triggered`, **WHEN** `Events.player_died` fires, **THEN** the respawn flow completes to `IDLE` without error. `[CR-8, E.25]` Evidence: `tests/unit/failure_respawn/signal_ordering_test.gd`

### 7. InputContext Stacking

**AC-FR-7.1 [Integration]** — **GIVEN** the InputContext stack is `[GAMEPLAY]` at the moment `Events.player_died` fires, **WHEN** the full respawn flow completes, **THEN** the stack is `[GAMEPLAY]` again (net-zero), verified by reading `InputContext._stack` before and after. `[CR-9]` Evidence: `tests/integration/failure_respawn/input_stack_test.gd`

**AC-FR-7.2 [Integration]** — **GIVEN** the stack is `[GAMEPLAY, MENU]` when `player_died` fires (debug path), **WHEN** the flow completes, **THEN** the stack is `[GAMEPLAY, MENU]` (MENU context preserved). `[CR-9, E.12]` Evidence: `tests/integration/failure_respawn/input_stack_test.gd`

**AC-FR-7.3 [Integration]** — **GIVEN** `InputContext.LOADING` is active during the ≈2.5 s respawn window, **WHEN** `ui_pause` action is triggered (simulated via `InputEventAction`), **THEN** the action does not route to the pause handler. `[CR-9, E.13]` Evidence: `tests/integration/failure_respawn/input_stack_test.gd`

### 8. Queued-Respawn

**AC-FR-8.1 [Integration]** — **GIVEN** LS is already mid-transition when `reload_current_section` is called by F&R, **WHEN** LS processes the queue and fires the step-9 callback, **THEN** F&R completes the floor application and `reset_for_respawn` call, then returns to `IDLE` with the InputContext stack back to `[GAMEPLAY]`; total mechanical flow time ≤ 1.14 s (per LS CR-6 queued-respawn budget: 0.57 s forward + 0.57 s respawn). `[CR-10, F.2]` Evidence: `tests/integration/failure_respawn/queued_respawn_test.gd`

### 9. Checkpoint Assembly

**AC-FR-9.1 [Logic]** — **GIVEN** a section scene containing a `Marker3D` named `"player_respawn_point"` at world position `(10.0, 0.5, -5.0)`, **WHEN** `Events.section_entered(section_id, TransitionReason.FORWARD)` fires, **THEN** `_current_checkpoint` is non-null AND `_current_checkpoint.respawn_position` is within `0.01 m` of `(10.0, 0.5, -5.0)`. `[CR-11]` Evidence: `tests/unit/failure_respawn/checkpoint_assembly_test.gd`

**AC-FR-9.2 [Logic]** — **GIVEN** a section scene with no `"player_respawn_point"` node, **WHEN** `Events.section_entered` fires, **THEN** F&R calls `push_error` with a message identifying the missing node AND `_current_checkpoint` retains its previous value. `[CR-11, E.10]` Evidence: `tests/unit/failure_respawn/checkpoint_assembly_test.gd`

**AC-FR-9.3 [Logic]** 🚫 **BLOCKED pending OQ-FR-5 (PC GDD null-checkpoint spec)** — **GIVEN** `_current_checkpoint == null` at boot (no section yet entered), **WHEN** `Events.player_died` fires, **THEN** F&R proceeds through CAPTURING and calls `PC.reset_for_respawn(null)` AND `push_warning` is emitted. PC behavior on `null` is governed by the PC GDD spec; F&R must NOT substitute a fallback position unilaterally. `[CR-11, E.9, E.23]` Evidence: `tests/unit/failure_respawn/checkpoint_assembly_test.gd`

**AC-FR-9.4 [Integration]** — **GIVEN** Eve crosses a `section_exited` boundary and takes lethal damage on the same frame, **WHEN** both events resolve, **THEN** `_current_checkpoint` reflects the **destination** section's respawn point AND Eve respawns in the destination section. `[E.3, CR-11]` Evidence: `tests/integration/failure_respawn/checkpoint_assembly_test.gd`

### 10. Performance / Timing Budget

**AC-FR-10.1 [Integration]** — **GIVEN** a single-transition respawn on **SSD with a warm section cache, running on the Intel Iris Xe reference machine per ADR-0001** (hardware pin: CPU Intel Core i5-1135G7 class, GPU Iris Xe 80-EU integrated, RAM 16 GB DDR4, storage SATA SSD or faster — exact reference spec documented in `docs/architecture/adr-0001-minimum-spec-hardware.md` §Reference Machines), **WHEN** the full flow runs from `player_died` emission to `_flow_state == IDLE`, **THEN** total mechanical elapsed wall time ≤ 0.58 s (LS ≤0.57 s + t_save ≤0.015 s + t_reset ~0.001 s), measured via `Time.get_ticks_msec()` delta logged at step 1 and step 13; assertion uses 10-run p90 (not single-run) to absorb normal I/O jitter. `[CR-12, F.2]` Evidence: `tests/integration/failure_respawn/timing_budget_test.gd`

**AC-FR-10.2 [Playtest]** — **GIVEN** a cold-cache respawn on minimum-spec hardware OR a queued-respawn double-transition scenario, **WHEN** the flow completes, **THEN** the observed mechanical time is recorded (not asserted as pass/fail) AND the perceived respawn beat (including Audio's fade-in) is qualitatively evaluated against the Pillar 3 "house lights up" target. This AC is **observational until ADR-0001 declares the min-spec storage tier** — if min-spec is SSD, the ≤1.14 s mechanical bound from F.2 applies as a secondary gate; if min-spec includes HDD, F.2 is re-derived and this AC is rewritten with an HDD-specific bound. `[CR-10, F.2, OQ-FR-7]` Evidence: Documented playtest at `production/qa/evidence/failure_respawn/timing_hdd_playtest.md`

**AC-FR-10.3 [Logic]** — **GIVEN** the respawn flow runs, **WHEN** `SaveLoadService.save_to_slot(0, …)` returns, **THEN** the elapsed time for that call alone is ≤ 15 ms (ADR-0003 save budget). `[CR-12, F.2]` Evidence: `tests/unit/failure_respawn/timing_budget_test.gd`

### 11. Autoload + Section-Entered Hygiene

**AC-FR-11.1 [Logic]** — **GIVEN** F&R autoload `_ready()` has just run, **THEN** `_flow_state == IDLE` AND `_current_checkpoint == null` (valid initial state; no crash on boot without a section loaded). `[E.23, CR-11]` Evidence: `tests/unit/failure_respawn/autoload_hygiene_test.gd`

**AC-FR-11.2 [Logic]** — **GIVEN** F&R's restore callback is registered via `LevelStreamingService.register_restore_callback` at `_ready()`, **WHEN** a fresh F&R instance is created (simulating editor hot-reload), **THEN** the new instance re-registers the callback unconditionally; no duplicate registration from the old instance persists. `[E.24]` Evidence: `tests/unit/failure_respawn/autoload_hygiene_test.gd`

**AC-FR-11.3 [Integration]** — **GIVEN** F&R is in `RESTORING` when `section_entered(_, RESPAWN)` fires, **WHEN** the section_entered handler runs, **THEN** `_current_checkpoint` is NOT overwritten AND `floor_applied_this_checkpoint` is NOT reset. `[CR-7, E.23, F.1]` Evidence: `tests/integration/failure_respawn/autoload_hygiene_test.gd`

### 12. Anti-Pattern Enforcement (grep-based lints)

**AC-FR-12.1 [Logic]** — **GIVEN** the F&R source file (`src/gameplay/failure_respawn/failure_respawn_service.gd`), **WHEN** a grep lint runs for `PlayerCharacter`, `StealthAI`, `GuardFireController`, `HUDCore`, `DocumentCollection`, `CivilianAI`, or `CutsceneSystem` as direct node references or `get_node()` calls, **THEN** zero matches are found (forbidden non-dependencies must not appear in F&R source). `[§Dependencies → Forbidden]` Evidence: `tests/unit/failure_respawn/anti_pattern_lint_test.gd`

**AC-FR-12.2 [Logic]** — **GIVEN** the F&R source file, **WHEN** a grep lint checks for any usage of `_current_checkpoint.` not preceded by `_current_checkpoint != null` or `if _current_checkpoint`, **THEN** zero unguarded usages are found. `[E.9, CR-11]` Evidence: `tests/unit/failure_respawn/anti_pattern_lint_test.gd`

**AC-FR-12.3 [Logic]** — **GIVEN** the F&R source file, **WHEN** a grep lint checks for any `await` between `save_to_slot` and `reload_current_section`, **THEN** zero `await` statements appear in that code path. `[CR-4]` Evidence: `tests/unit/failure_respawn/anti_pattern_lint_test.gd`

**AC-FR-12.4 [Logic]** — **GIVEN** the full project source tree (`src/**/*.gd`), **WHEN** a CI grep lint searches for the regex `respawn_triggered\.emit\b`, **THEN** the only matching file is `src/gameplay/failure_respawn/failure_respawn_service.gd` (F&R is the sole publisher per ADR-0002:183). `[§Dependencies ADR-0002, CR-8]` Evidence: `tools/ci/lint_respawn_triggered_sole_publisher.sh` — CI-invoked (NOT a GUT unit test; grep is simpler as a CI script).

**AC-FR-12.5 [Logic]** — **GIVEN** the Combat, SAI, and Audio source files (direct `respawn_triggered` subscribers per §Dependencies), **WHEN** a CI grep lint searches each subscriber's `_on_respawn_triggered*` handler body for `LevelStreamingService` method calls OR `Events\..*\.emit` calls, **THEN** zero matches are found (no subscriber re-enters LS or emits further Events signals within the same signal-handling call stack — CR-8 re-entrancy fence). `[CR-8, E-2]` Evidence: `tools/ci/lint_respawn_triggered_no_reentrancy.sh`

---

### BLOCKING items before sprint start

| Blocker | Blocks AC(s) | Resolution required |
|---|---|---|
| **ADR-0007 amendment** — F&R autoload at line 8 (after Combat) | All ACs | ADR-0007 amended; coord landing confirmed |
| **Inventory GDD coordination** — add `apply_respawn_floor_if_needed(snapshot, should_apply_floor)` public API (rename from existing `restore_weapon_ammo(floor_dict)` per Inventory L312) | AC-FR-4.1, 4.2, 4.3, 5.3, 5.4 | Inventory GDD updated with public API signature; existing `restore_weapon_ammo` reference in Inventory L312 + F.2 variable table reconciled with F&R's policy/mechanism split |
| **Save/Load GDD + ADR-0003 schema coordination** — (a) add `FailureRespawnState` sub-resource to `SaveGame`; (b) remove/rewrite save-load.md L100 + L151 which still describe F&R using `load_from_slot(0)` during respawn (contradicts F&R CR-4 in-memory handoff); (c) forbid internal `await` inside `save_to_slot(0, ...)` in ADR-0003; (d) atomic-commit fence: `FailureRespawnState.gd` + `save_game.gd` schema update must land in the same PR | AC-FR-3.1, 5.1–5.6 | Save/Load GDD §Interactions + ADR-0003 schema updated |
| **Input GDD coordination** — add `InputContext.LOADING` context to Input GDD (currently not mentioned anywhere in `input.md`) | AC-FR-7.1, 7.2, 7.3 | Input GDD adds LOADING context with ADR-0004 stack-semantics reference; F&R's CR-9 Option B stacking assumption is backed by upstream spec |
| **Signal Bus GDD touch-up** — signal-bus.md L122 currently says F&R "Subscribes to Combat (player_died)"; must add F&R's `section_entered` subscription (per CR-7) | Implicit (affects authoring) | signal-bus.md L122 row extended |
| **Audio GDD amendment** — (a) mission-failure sting suppression when `respawn_triggered` fires within ≤100 ms of `player_died` (CR-8 policy, per creative-director 2026-04-24 senior ruling); (b) retune `respawn_silence_s` 0.2 → ~0.4 s; (c) retune `respawn_fade_in_s` 2.0 → ~1.2 s — theatre-beat target is ~1.6 s perceived, not the current ~2.2 s | AC-FR-6.1 felt-feel (Pillar 3 qualitative gate; playtest-gated) | Audio GDD §Failure/Respawn domain handler table + Tuning Knobs amended; Audio re-review recommended |
| **ADR-0001 amendment — declare min-spec storage tier (SSD vs HDD)** — F.2 timing budget is PROVISIONAL until TD rules. If HDD is supported, F.2 + AC-FR-10.x re-derive. | AC-FR-10.1, AC-FR-10.2 | Technical-director authors ADR-0001 amendment declaring reference-hardware storage tier; F&R F.2 table finalized post-amendment |
| **LS GDD coordination — `register_restore_callback` replace-semantics** | AC-FR-11.2 + all ACs implicitly | Level Streaming GDD must document that `register_restore_callback(callable)` uses replace-semantics keyed by caller-identity (not append), so hot-reload re-registration correctly replaces the stale Callable from the destroyed F&R instance. E.24 stale-Callable crash risk depends on this contract |
| **godot-specialist engine-verification gate — Godot 4.6 signal-delivery isolation on subscriber exception** | AC-FR-6.2 (hard branch BLOCKED) | godot-specialist confirms whether Godot 4.6 signal delivery is per-callable-isolated when a subscriber throws an unhandled exception; AC-FR-6.2 hard branch unblocks upon confirmation |
| **PC GDD null-checkpoint spec** — OQ-FR-5 | AC-FR-9.3 (marked BLOCKED) | PC GDD specifies `reset_for_respawn(null)` fallback behavior |
| **Mission Scripting (provisional)** — `player_respawn_point: Marker3D` authoring contract; section-validation CI must verify presence of the node in the non-deferred tree (forbids deferred-add-child patterns per CR-11 godot-specialist E-4 finding) | AC-FR-9.1, 9.2, 9.4 | Mission Scripting GDD confirms node-name + non-deferred contract; section-validation CI job authored |
| **Shared `Checkpoint` class location** — `Checkpoint` resource must live at `src/gameplay/shared/checkpoint.gd`, NOT inside F&R's autoload directory, to avoid PC → F&R load-order dep (godot-specialist G-8) | PC GDD signature type-check | PC GDD and F&R both import from shared path |

### Design Gaps (surfaces for designer review — non-AC)

- **DG-FR-1** — OQ-FR-4 (save-failure HUD warning): E.6 specifies F&R continues respawn on IO_ERROR but defers the UX question. No [UI] AC exists until the UX decision is made.
- **DG-FR-2** — OQ-FR-6 (Jolt tick ordering, Area3D vs RigidBody same physics step): AC-FR-2.1 was rewritten 2026-04-24 to scope the `DeathCause.ENVIRONMENTAL` assertion to the isolated-scenario test only; the simultaneous-bullet case now has a separate test asserting "any valid DeathCause" per Godot 4.6 Jolt's non-deterministic contact ordering.
- **DG-FR-3** — No AC covers the *Visual/Feel* quality of the Audio fade-in during respawn. Intentionally out of F&R scope (Audio GDD owns the timing); after the 2026-04-24 Audio GDD amendment request (silence 0.4 s + fade 1.2 s), a formal feel sign-off belongs in Audio's ACs.
- **DG-FR-4** — F.1's example calculation (pistol 6 → 16, dart 3 → 8) is in the GDD but AC-FR-4.1 should use these exact literal values as the regression fixture to keep doc and code in sync.
- **DG-FR-5** — Godot 4.6 signal-delivery isolation on subscriber unhandled exception: AC-FR-6.2's hard branch is BLOCKED pending godot-specialist engine-verification gate. The `push_error` (soft-error) branch is testable now; unhandled-exception isolation requires engine-verification before it can be treated as a runtime-behavior AC.
- **DG-FR-6** — Schema forward-compat: per creative-director adjudication 2026-04-24, `FailureRespawnState` remains a flat `bool` at MVP. When Mission Scripting introduces mid-section checkpoints post-MVP, the schema will extend additively (new `Dictionary[StringName, bool] per_checkpoint_flags` field, or `checkpoint_id: StringName` field on the existing resource) — no FORMAT_VERSION bump required under ADR-0003 additive-field rule. Documented here as a conscious deferral, not a gap.
- **DG-FR-7** — B-2/B-3/B-4/B-5/B-6/B-7 (game-designer recommendations) were not promoted to blockers by creative-director but remain open design concerns: single-floor-grant progressive-punishment, stealth-stuck-alive case, missing Restart-from-Checkpoint, geometry-clip/scripting-hang coverage, dart-mid-sedation race, LOAD_FROM_SAVE flag-reset farm-exploit path. Logged in §Open Questions as playtest-gated / Tier 2 scope.

### AC Count Summary

| Group | # ACs | Story types |
|---|---|---|
| 1. Trigger & Idempotency | 4 | Logic |
| 2. Kill-Plane | 2 | Logic, Integration |
| 3. Save Write & Handoff | 3 | Logic, Integration |
| 4. Ammo Floor Logic | 3 | Logic |
| 5. Floor Flag State Machine | 6 | Logic, Integration |
| 6. Signal Ordering | 3 | Logic |
| 7. InputContext Stacking | 3 | Integration |
| 8. Queued-Respawn | 1 | Integration |
| 9. Checkpoint Assembly | 4 | Logic, Integration (9.3 BLOCKED) |
| 10. Performance / Timing | 3 | Integration, Playtest |
| 11. Autoload Hygiene | 3 | Logic, Integration |
| 12. Anti-Pattern Lints | 5 | Logic (12.4/12.5 are CI lint scripts, not GUT) |
| **Total** | **40** | All BLOCKING-class except AC-FR-6.2 hard-branch (engine-gate BLOCKED) and AC-FR-10.2 (Playtest type, observational pending ADR-0001) |

F&R has no Visual/Feel or UI ACs by design — the player-visible surface is owned by Audio (fade timings) and Pillar 5 deliberately prohibits F&R-owned UI (no death screen, no retry button).

## Open Questions

| # | Question | Severity | Owner | Target resolution |
|---|---|---|---|---|
| **OQ-FR-3** | When a document is collected mid-section before death, does the dying-state slot-0 save persist that collection (so the player keeps it post-respawn), or should F&R reset it to the section-entry baseline? | Advisory (deferred) | Document Collection GDD author | Before Document Collection GDD §Interactions is finalized (VS scope — not blocking MVP F&R) |
| **OQ-FR-4** | Should F&R surface a non-blocking "Auto-save failed" HUD warning on IO_ERROR during CAPTURING (E.6), or stay silent and let Save/Load's own `save_failed` dialog handle it? | Advisory | UX designer + HUD State Signaling GDD author | Before HUD State Signaling sprint |
| **OQ-FR-5** | What does `PlayerCharacter.reset_for_respawn(null)` do when called with a null `Checkpoint`? Must PC GDD specify a fallback (teleport-to-world-origin + `push_warning`)? | **BLOCKING for pre-sprint** | PC GDD maintainer | Before Failure & Respawn sprint starts — AC-FR-9.3 is marked BLOCKED until this lands |
| **OQ-FR-6** | In Godot 4.6 with Jolt physics, if Eve crosses the kill-plane Area3D on the same physics tick that a bullet RigidBody `body_entered` fires against her CapsuleShape3D, which event resolves first? (Affects `DeathCause` recorded on slot-0 but not F&R flow correctness.) | Advisory (engine-verification gate) | godot-specialist | Before Failure & Respawn sprint starts (engine verification) |
| **OQ-FR-7** | ADR-0001 does not currently declare a min-spec storage tier (SSD vs HDD). F.2 timing budget assumes SSD warm cache; on 7200 RPM HDD, `t_swap` could reach 2–4 s and invert the budget. What storage tier does *The Paris Affair* support at min-spec? | **BLOCKING for F.2 + AC-FR-10.x finalization** (escalated to technical-director) | technical-director | Before Failure & Respawn sprint; ADR-0001 amendment authored |
| **OQ-FR-8** | Godot 4.6 signal-delivery isolation: when a `respawn_triggered` subscriber throws an unhandled GDScript exception, does the engine isolate the exception (continuing to fire remaining subscribers) or propagate it (blocking subsequent subscribers and the emit-caller)? E.26 and AC-FR-6.2's hard branch depend on the former. | **BLOCKING for AC-FR-6.2 hard-branch unblock** (engine-verification gate) | godot-specialist | Before Failure & Respawn sprint |
| **OQ-FR-9** | Godot 4.6 Jolt: does `body_exited` fire for a `RigidBody3D` dart that calls `queue_free()` from inside a signal handler (`respawn_triggered`)? Affects whether guard sight-cone tracked-bodies dictionaries need `is_instance_valid()` guards or whether `body_exited` naturally drains. | Advisory (engine-verification) | godot-specialist | Playtest-gated — QA observes stale-dart state if any; fix if observed |
| **OQ-FR-10** | Game-designer B-3 — stealth-stuck-alive case (no ammo, full alert, no stealth route, no death). At MVP `FR_FAILURE_TRIGGER_SIGNALS = {player_died}` leaves this case to Load Game (per scope). Is this actually the right Pillar 3 experience, or should Mission Scripting gain a scripted `force_respawn_fail` trigger that fires into F&R? | Playtest-gated (Tier 0 / Tier 1) | game-designer + playtest | After Tier 0 Plaza playtest; revisit if stealth-stuck-alive is observed as a common failure mode |
| **OQ-FR-11** | Game-designer B-4 — "Restart from Checkpoint" pause-menu action was scope-locked as absent per Pillar 5. But NOLF1 had one. Is the current Load Game path actually less immersion-disruptive than a simple Restart button would be? | Playtest-gated (Tier 0) | game-designer + playtest + creative-director | After Tier 0 Plaza playtest; playtest observers log how often players quit-to-menu to Load after a botched stealth |
| **OQ-FR-12** | Game-designer B-7 — CR-7 resets `floor_applied_this_checkpoint` to `false` on `LOAD_FROM_SAVE`, which creates an unlimited floor-grant bypass via manual save/load. Is this acceptable as "player intent wins" (Save/Load CR-4 philosophy), or does the anti-farm invariant need to hold across manual loads? | Advisory — design tension; decide during Tier 1 balance | systems-designer + game-designer | Tier 1 balance pass |
| **OQ-FR-13** | Game-designer B-2 — a player who drains ammo in two deaths has no forward momentum and no mechanical escape (single-floor-grant-per-checkpoint). Is the anti-farm invariant worth this "progressive punishment under genuine depletion" risk, or should the floor grant a half-floor on the second depletion? | Playtest-gated | game-designer + systems-designer | Tier 0 playtest; observe how often second-death-in-section leaves players softlocked-in-ammo |
| **OQ-FR-14** | Game-designer B-5 — kill-plane at -50 m covers out-of-bounds falls only. Geometry-clip (Eve stuck inside solid mesh), scripting-hang (mission logic infinite loop), and permanent-alert-lock (alive but cornered with no progress path) have no F&R entry point. Does MVP need a watchdog or a dev-only unstuck command? | Advisory (MVP-deferred) | qa-lead + gameplay-programmer | QA process can cover in shipping; add dev-only `FR_DEBUG_FORCE_DEATH()` already exists |
| **OQ-FR-15** | Game-designer B-6 — dart-mid-sedation-at-respawn race: if a dart has contacted a guard but sedation hasn't applied when `respawn_triggered` fires, the guard could be left in an indeterminate state post-respawn. Does Stealth AI's `GuardRecord` save-restore cover this cleanly, or does the mid-section partial-sedation state survive? | Advisory (engine-verification + SAI coord) | ai-programmer + godot-specialist | Before Failure & Respawn sprint |
