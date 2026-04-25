# Save / Load

> **Status**: In Design
> **Author**: User + `/design-system` skill + specialists (systems-designer, gameplay-programmer, godot-specialist per routing)
> **Last Updated**: 2026-04-19
> **Last Verified**: 2026-04-19
> **Implements Pillar**: Pillar 3 (Stealth is Theatre, Not Punishment — failure is never catastrophic at sectional boundaries); Pillar 2 (Discovery Rewards Patience — multiple slots for alternate-route experiments)

## Summary

Save / Load is the persistence backbone of *The Paris Affair* — a single `SaveLoadService` autoload that writes and reads sectional checkpoint saves in binary `.res` format with atomic write semantics. It is **subscriber-agnostic**: callers (Mission & Level Scripting, Failure & Respawn, the player's explicit save action) assemble a complete `SaveGame` Resource from each owning system's current state, then hand it to Save/Load for persistence. Eight save slots exist (0 = autosave, 1–7 manual, NOLF1-style). Failure modes emit via the Signal Bus (`Events.save_failed`); settings are persisted in a separate `user://settings.cfg` file. ADR-0003 locks the format contract; this GDD covers the design-level behavior and cross-system integration.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Effort: `L` · Key deps: `Localization Scaffold` · Implementation contract: ADR-0003

## Overview

Save / Load is a Foundation-layer infrastructure system that the player engages with rarely but feels constantly. Rarely: at section transitions (autosave fires), at an explicit "Save Game" menu action (manual save to slot 1–7), at the pause menu's Quicksave/Quickload shortcuts (F5/F9), and at the "Load Game" screen after starting the game. Constantly: via the knowledge that the game **is not punishing** — a failed stealth attempt restarts the player at the current section's start, not at the mission's start; an alternate-route experiment in slot 2 leaves the player's clean run in slot 1 intact; a save file from last week loads exactly where the player left off.

Architecturally, this system implements **ADR-0003 (Save Format Contract)** in full. The key design properties inherited from the ADR:

- **Sectional scope** — a save captures the current section's state only, not the full mission.
- **Binary `.res` format with compression** via `ResourceSaver.FLAG_COMPRESS`.
- **Refuse-load-on-mismatch versioning** — incompatible saves are refused; the player starts a new game rather than getting a broken state.
- **Caller-assembled SaveGame** — the service writes/reads only; Mission Scripting reads state from Player Character, Inventory, Stealth AI, Civilian AI, Document Collection, and Mission Scripting itself to assemble the save payload.
- **Atomic write via tmp-file + `DirAccess.rename()`** — no corrupt saves on crash.
- **Stable `actor_id: StringName` per guard/civilian** (NO NodePath — survives scene reload).
- **`duplicate_deep()` on load** before live assignment (state isolation from cached loaded resource).
- **Metadata sidecar `ConfigFile`** — menu renders save cards from ~200-byte sidecar, not from full Resource load.
- **Settings in separate `user://settings.cfg`** — volume, input rebindings, accessibility toggles are explicitly NOT part of SaveGame; new-game actions never wipe settings.

Save / Load publishes three signals on the Events bus (ADR-0002): `game_saved(slot: int, section_id: StringName)`, `game_loaded(slot: int)`, and `save_failed(reason: SaveLoad.FailureReason)`. Menu System, HUD State Signaling, and Cutscenes subscribe as needed. Save / Load does NOT hold references to any game system — the ADR-0003 forbidden pattern `save_service_assembles_state` enforces this anti-pattern fence in code review on every PR touching the service.

## Player Fantasy

Save / Load's job is simple: **let the player save their progress at any moment they choose, and let them come back to that exact moment later.** Eight save slots mean players never have to overwrite their progress to try something new — they can save before a risky encounter, try the encounter, and reload if it goes badly. Or save at the end of a play session, close the game, and come back tomorrow to find the game exactly as they left it.

- **Pillar 3 (Stealth is Theatre, Not Punishment)**: when things go wrong, the player restarts at the most recent section's start, not back at mission start. Failure costs minutes, not an hour.
- **Pillar 2 (Discovery Rewards Patience)**: a player who wants to explore alternate routes or search every corner for documents can save at any point, experiment freely, and reload if they miss something.

Players never praise the save system by name. They praise the game for **respecting their time** and **trusting them to play however they want**.

## Detailed Design

### Core Rules

**CR-1 — Who triggers a save, and at which slot.**

| Trigger | Who calls it | Slot | Notes |
|---|---|---|---|
| Section transition (entry) | Mission & Level Scripting | 0 (autosave) | Fires on `section_entered`; see CR-3 for timing |
| Player death / mission failure | Failure & Respawn | 0 (autosave) | Writes checkpoint the respawn will load |
| "Save Game" in Pause Menu | Pause Menu (player-facing) | 1–7 (player-chosen) | **Also writes slot 0 as side effect** — CR-4 |
| Quicksave (F5) | Player input handler | 0 (autosave only) | See CR-5 |

**CR-2 — The caller assembles the SaveGame; the service writes it.** Per ADR-0003 forbidden pattern `save_service_assembles_state`: the entity triggering the save reads current state from each owning system, populates a `SaveGame` Resource, and passes it to `SaveLoad.save_to_slot(slot, save_game)`. `SaveLoadService` is file I/O only.

**CR-3 — Autosave fires on section ENTRY, not section exit.** When Mission & Level Scripting receives `section_entered`, it assembles and saves the opening state of that section to slot 0. This ensures the respawn point is the section's *beginning*, not an arbitrary mid-section state left by the previous save. Save-on-exit would capture mid-combat or post-objective state, producing inconsistent restart points.

**CR-4 — A manual save to slot 1–7 ALSO overwrites slot 0.** *(Design decision locked.)* Rationale: Pillar 3 (Stealth is Theatre, Not Punishment) — a player who just saved to slot 3 and then dies respawns at their manual save state, not back at section start. Death respawn always loads slot 0, and slot 0 tracks "the most recent save regardless of who made it." This respects player intent and is less punishing than a rigid "slot 0 = section-entry only" rule.

**CR-5 — Quicksave (F5) always writes slot 0; Quickload (F9) always reads slot 0.** Quicksave is not a named save — it is an expedient checkpoint update that fuses with the autosave semantics (CR-4). Pointing it at "last-used slot" would require state tracking and confusing behavior when no manual save exists yet.

**CR-6 — The player cannot save during a cutscene.** When `InputContext.current() == CUTSCENE`, the Pause Menu's "Save Game" and Quicksave (F5) inputs are not routed. Mission Scripting notifies SaveLoad when the cutscene ends; no deferred save is enqueued.

**CR-7 — The player CAN save during active combat.** No "combat state" block on saves. Consistent with Pillar 2 (Discovery Rewards Patience) and Pillar 3 — punishing a player for saving at an awkward moment is paternalistic. Stealth AI state (alert level, patrol position, last-known-target) is part of the save payload; the guard configuration at save time is exactly what loads.

**CR-8 — On load, a full scene transition occurs.** Loading any slot triggers: (1) fade to black, (2) Mission & Level Scripting reads `MissionState.section_id` from the loaded `SaveGame` and calls Level Streaming to load that section, (3) all owning systems read their `*_State` sub-resources from `saved_game.duplicate_deep()` and restore state, (4) fade in. The player is never dropped in-place with partial scene state. Load can be initiated from Pause Menu "Load Game" or from Main Menu "Load Game" screen — both produce the same full scene transition.

**CR-9 — Save failure is surfaced immediately; the previous good save is never destroyed.** On any failure (`IO_ERROR`, `RENAME_FAILED`, etc.), `Events.save_failed(reason)` fires. Menu System (and Pause Menu) subscribes and shows a non-blocking dialog: *"Save failed — [reason string]."* The prior slot file is intact (atomic write from ADR-0003 ensures rename only completes on success). The player is never silently left without a save.

**CR-10 — Slot 0 (autosave) is a visible, loadable card in the Load Game grid.** *(Design decision locked.)* Not hidden behind a "Continue" shortcut. Renders alongside slots 1–7; same card format; can be loaded or overwritten like any other slot. Players who prefer "just hit Continue" behavior get it via the Main Menu's primary "Continue" button (which points at slot 0), while the full 8-slot grid remains available for deliberate browsing.

**CR-11 — Pause Menu "Save Game" uses a slot-picker grid.** *(Design decision locked, NOLF1-faithful.)* Opening "Save Game" from Pause Menu shows a grid of slots 1–7 with current contents. Player picks a slot explicitly. No auto-next-available — this is an intentional save, the player chooses where it goes.

### States and Transitions

Save/Load is a thin service, not a state machine in the player-experience sense. Internal states matter for blocking rules:

| State | Description | Typical Duration | What It Blocks |
|---|---|---|---|
| `IDLE` | No I/O in progress | Persistent | Nothing |
| `SAVING` | Atomic write in progress (tmp write → rename → sidecar → screenshot) | ≤10 ms per ADR-0003 | A second concurrent save call; Quickload |
| `LOADING` | `ResourceLoader` reading slot file + caller doing `duplicate_deep()` + scene transition | ≤2 ms I/O (hidden inside Level Streaming's 200–500 ms scene load) | Any save call; a second load call |

Because save latency is ≤10 ms synchronous, `SAVING` is effectively invisible — no loading indicator needed. `LOADING` is always paired with a screen fade, so the player sees a visual transition rather than a "loading" state UI.

**Slot states** (used by Menu System rendering save cards):

| Slot State | Condition | Menu Behavior |
|---|---|---|
| `EMPTY` | `slot_exists(N) == false` | Shows "Empty" card; selecting begins new save flow |
| `OCCUPIED` | Sidecar + `.res` both present, version matches | Shows section name, timestamp, elapsed time, thumbnail |
| `CORRUPT` | `.res` present but `load_from_slot` returns null or version mismatch | Shows "Corrupt — cannot load" card; no load option; overwriteable by new save |

### Interactions with Other Systems

| System | Save trigger | State contributed to SaveGame | State restored on load |
|---|---|---|---|
| **Mission & Level Scripting** | Triggers save on `section_entered`; triggers load after slot selection | `MissionState`: `section_id`, `objectives_completed: Array[StringName]`, `triggers_fired: Array[StringName]` | Restores mission progress, marks suppressed triggers as "already fired", loads correct section via Level Streaming |
| **Failure & Respawn** | Triggers save (slot 0) on `player_died`, before respawn sequence; triggers load from slot 0 during respawn | Reads from all systems; assembles full `SaveGame` | Calls `SaveLoad.load_from_slot(0)`, hands deep-duplicated state to each system, initiates scene reload |
| **Player Character** | Passive contributor (does NOT trigger saves) | `PlayerState`: `position: Vector3`, `rotation: Vector3`, `health: int`, `current_state: int` (stored as `PlayerCharacter.MovementState` enum value). Types reconciled with PC GDD in Session C (2026-04-19): `health` `float` → `int`; `current_state` `String` → `int` enum. Stamina field removed 2026-04-19 (Session A, review B-14). | Position and health restored before fade-in; player spawns at saved position |
| **Inventory & Gadgets** | Passive contributor | `InventoryState`: equipped gadget, **`ammo_magazine: Dictionary` (`## StringName -> int`, per-weapon rounds currently in magazine)**, **`ammo_reserve: Dictionary` (`## StringName -> int`, per-weapon reserve count)**, collected gadget flags, `mission_pickup_available` flag. Untyped `Dictionary` with doc-comment typing (NOT `TypedDictionary`) per Inventory CR-11 — `TypedDictionary` `ResourceSaver` serialization stability is unverified post-cutoff (godot feasibility review Q7, 2026-04-23). **Registration path**: Inventory calls `LevelStreamingService.register_restore_callback(_on_restore_from_save)` at `_ready()` (pattern owned by LS GDD CR-10), **NOT** `SaveLoad.*` directly. | Equipped state and per-weapon magazine + reserve counts restored; no pickup animations replayed. Inventory's registered callback receives the deep-duplicated `InventoryState` via LS's section-reload path (which Save/Load composes with the rest of `SaveGame`). |
| **Stealth AI** | Passive contributor; subscribes to `game_loaded` to re-apply restored patrol state | `StealthAIState.guards: Dictionary[StringName, GuardRecord]` — per-guard alert level, patrol index, position, last-known-target | Each guard reads its `GuardRecord` by `actor_id` and snaps to saved state; guards never "remember" the player across a load unless the save captured that state |
| **Civilian AI** | Passive contributor (MVP scope: stub — panic state only) | `CivilianAIState`: per-civilian panic flag keyed by `actor_id` | Panicked civilians restored to panic; calm civilians restored to idle |
| **Document Collection** | Passive contributor | `DocumentCollectionState.collected: Array[StringName]` of document IDs | Documents collected before save remain collected; un-collected documents respawn pickupable |
| **Menu System** | Initiates load from Load Game screen; reads slot metadata (sidecar only — NOT full load) to display save cards; initiates save from Pause Menu | None | Calls `SaveLoad.load_from_slot(N)` on confirmation; hands loaded game to Mission Scripting to drive scene transition |
| **Cutscenes & Mission Cards** | Subscribes to `game_loaded` to check `MissionState.triggers_fired` and suppress replays | None | Cutscenes that have already played stay played after load (never re-triggered) |

#### Quicksave/Quickload UX sketch

- **F5 (Quicksave)**: fire immediately if `InputContext.current() != CUTSCENE`; no confirmation dialog (expediency is the point). On success: brief HUD notification ("Quicksave to slot 0"). On failure: `Events.save_failed` → Pause Menu dialog.
- **F9 (Quickload)**: if slot 0 is `OCCUPIED`, load immediately with scene transition. If `EMPTY` or `CORRUPT`: brief HUD notification ("No quicksave available"), no action. No confirmation dialog — if the player hits F9 by accident, they can just reload the slot they came from.

## Formulas

**None.** Save / Load has no balance values or calculations. The only quantitative rules are performance budgets (≤10 ms save, ≤2 ms I/O load, ≤10 KB binary `.res`) inherited from ADR-0003 and tracked there. Versioning uses an integer compare (`save_format_version == FORMAT_VERSION`), not a formula. Slot indexing is a bounded `int` (0–7), not a computed range.

## Edge Cases

- **If the player triggers Quicksave (F5) during a cutscene** → input is not routed (`InputContext == CUTSCENE`). **Resolution**: Quicksave is silent no-op. No error dialog; the keypress is simply ignored per Input GDD context-gating rules.
- **If the player triggers Quickload (F9) when slot 0 is empty** → brief HUD notification *"No quicksave available."* No attempt to load. **Resolution**: intended. This replaces the common "silent failure" of quickload in many games.
- **If the player dies (`player_died` event fires) within 2 seconds of the previous autosave/save** → Failure & Respawn still triggers a new save to slot 0 (the dying state). Death respawn then loads slot 0, which restores the player at the section-entry state if that was the last save, or at the mid-section state if a manual save was the last save (per CR-4). **Resolution**: intended. Player's most recent intent wins.
- **If the disk is full when `save_to_slot` is called** → `ResourceSaver.save()` returns a non-OK error; `Events.save_failed(FailureReason.IO_ERROR)` fires; the previous good slot file is untouched (tmp file + rename atomicity). **Resolution**: intended. Player sees error dialog; previous save is preserved.
- **If `DirAccess.rename()` succeeds but metadata sidecar write fails** → the `.res` is committed but `slot_N_meta.cfg` is stale or missing. **Resolution**: treat as partial success: emit `Events.game_saved` with a warning; Menu System's save card shows "No metadata" fallback (timestamp only, no screenshot). On next load attempt, `slot_metadata()` returns a minimal fallback Dictionary built from the `.res`'s own `saved_at_iso8601` field.
- **If the player manually saves to slot 2, then starts a new game from main menu, then loads slot 2** → slot 2's state is loaded correctly regardless of what happened in the new-game session. **Resolution**: intended. Slots are independent; starting a new game does not wipe manual saves.
- **If the player is in section 3 (Restaurant) and manually saves to slot 5, then dies, then starts a new game, then loads slot 5** → section 3 is loaded with the state from the manual save. Mission & Level Scripting's `triggers_fired` array is used to determine which cutscenes/events should NOT replay. **Resolution**: intended. Cross-session save loading is the primary use case.
- **If a `SaveGame` assembled by the caller contains a stale actor reference** (e.g., a guard that was killed mid-section but whose `actor_id` still appears in the StealthAI dict) → the save persists the stale record. On load, the stealth AI system encounters an `actor_id` with no corresponding scene node. **Resolution**: on load, Stealth AI iterates `StealthAIState.guards` and tries to resolve each `actor_id` to a scene node via section scene lookup. If no match, the record is discarded with a debug log. Guards not in the dict spawn in their default state.
- **If the player starts a new game while save-in-progress (`SAVING` state)** → new-game action is queued. SaveLoad finishes the write, emits `game_saved`, returns to `IDLE`, then the new-game action processes. **Resolution**: save atomicity is respected — never interrupted mid-write.
- **If the save format version increments between a player's last save and a patch** → loading the old save returns null (refuse-load-on-mismatch per ADR-0003). `Events.save_failed(FailureReason.VERSION_MISMATCH)` fires. Menu System shows an explanatory dialog: *"Save was created in an earlier version of the game and cannot be loaded."* The corrupt slot remains visible in the grid and can be overwritten. **Resolution**: intended trade-off from ADR-0003. Documented in release notes if/when version increments.
- **If the player opens the Load Game screen while SaveLoad is in `LOADING` state** (shouldn't happen, but defense-in-depth) → the menu blocks input until load completes. No double-load attempt. **Resolution**: `LOADING` state blocks any save/load call (per States table).
- **If a slot's `.res` file is missing but the sidecar `.cfg` exists** (incomplete backup, manual file deletion) → `slot_metadata()` returns the sidecar data but `load_from_slot()` returns null. Menu System shows the card as `CORRUPT` (per slot states). **Resolution**: intended defense against partial file deletion.
- **If the screenshot file (`slot_N_thumb.png`) is missing but the `.res` and `.cfg` are present** → sidecar returns `screenshot_path = ""`. Menu System falls back to a default "no screenshot" placeholder graphic. `load_from_slot()` still succeeds. **Resolution**: intended. Screenshot is a nice-to-have, not a requirement for load.
- **If `duplicate_deep()` is forgotten by a caller on load** → the caller passes the cached loaded resource directly to a live system. That system mutates it. A subsequent reload-from-cached-resource (if the caller kept a reference) restores post-mutation state. **Resolution**: this is a bug per ADR-0003 forbidden_pattern `forgotten_duplicate_deep_on_load`. Code review catches it. Every system GDD that restores from a `*_State` sub-resource MUST document the `duplicate_deep()` call.
- **If two simultaneous save requests arrive in the same frame** (Mission Scripting autosave + player F5 Quicksave) → the first one acquires `SAVING` state; the second sees `SAVING` and is queued. When the first completes, the second processes. **Resolution**: sequential. Both saves complete; the latter one wins if both target slot 0.

## Dependencies

### Upstream dependencies

| System | Nature |
|---|---|
| **ADR-0003 (Save Format Contract)** | Hard architectural dependency — ADR is authoritative; this GDD implements its contract. |
| **Localization Scaffold** (system 7) | Hard dependency. Save metadata `section_display_name` is a localization key; menu save cards display the localized name, not a hardcoded English string. |
| **Signal Bus** (system 1, ADR-0002) | Hard dependency — Save/Load publishes `game_saved`, `game_loaded`, `save_failed` signals. |
| Godot 4.6 `ResourceSaver` / `ResourceLoader` / `DirAccess` / `ConfigFile` / `Resource.duplicate_deep()` | Hard engine dependency. `duplicate_deep()` is 4.5+ (load-bearing). |

### Downstream dependents

| System | Direction | Nature |
|---|---|---|
| **Failure & Respawn** (14) | F&R → SaveLoad | Calls `save_to_slot(0, assembled_save)` on `player_died`; calls `load_from_slot(0)` during respawn sequence. |
| **Mission & Level Scripting** (13) | Mission → SaveLoad | Calls `save_to_slot(0, ...)` on `section_entered`; assembles the SaveGame payload by reading from each system. |
| **Menu System** (21) | Menu → SaveLoad | Reads `slot_metadata(N)` for save-card display; calls `load_from_slot(N)` on player confirmation; calls `save_to_slot(1-7, ...)` from Pause Menu's "Save Game" flow. |
| **Player Character** (8) | Passive | Exposes `PlayerState` struct via public getter for Mission Scripting to read at save time; accepts restored `PlayerState` after load. |
| **Inventory & Gadgets** (12) | Passive | Same — exposes `InventoryState`; accepts restored state. |
| **Stealth AI** (10) | Passive | Exposes `StealthAIState` (guards dict keyed by `actor_id`); subscribes to `Events.game_loaded` to apply restored patrol state. |
| **Civilian AI** (15) | Passive | Same. |
| **Document Collection** (17) | Passive | Same. |
| **Cutscenes & Mission Cards** (22) | Cutscenes → SaveLoad | Subscribes to `Events.game_loaded` to check `MissionState.triggers_fired` and suppress already-played cutscene replays. |

### No direct interaction

- **ADR-0001 (Stencil)**: independent.
- **ADR-0004 (UI Framework)**: Menu System (which owns the save card UI) depends on ADR-0004 for its UI architecture; Save/Load does NOT depend on ADR-0004 directly. UI Framework knows nothing about save formats.
- **Audio**: publisher-subscriber only (no direct calls). Save/Load publishes `game_saved` / `game_loaded` / `save_failed`; Audio subscribes via its Persistence domain (confirmed in Audio GDD Rule 3 + Interactions §Persistence, reconciled 2026-04-20 cross-review B6). Audio plays: save-confirm chime on `game_saved`, descending minor error sting on `save_failed`, and no SFX on `game_loaded` (Save-Load flow proceeds straight to `section_entered` which handles music swap).
- **Input**: Quicksave/Quickload keys are defined in Input's action catalog (`quicksave = F5`, `quickload = F9`); Input has no other interaction with Save/Load.

### Settings file scope

Settings (volume, input rebindings, accessibility toggles) are persisted in a separate `user://settings.cfg` ConfigFile, NOT in SaveGame (per ADR-0003). **Save / Load does not own settings persistence** — Settings & Accessibility owns it. This GDD documents the separation as a clarity aid; implementation is Settings' responsibility.

## Tuning Knobs

### Save scope

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `SLOT_COUNT` | 8 | 4 to 16 | 1 autosave + 7 manual per ADR-0003 locked decision. Changing requires Menu UI rework. |
| `AUTOSAVE_SLOT` | 0 | 0 (locked) | Slot 0 is autosave. CR-4 says manual saves also write here. |
| `MANUAL_SLOT_RANGE` | 1–7 | Bounded by `SLOT_COUNT` | Displayed in Pause Menu save picker. |

### File system

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `SAVE_DIR` | `user://saves/` | Locked (per ADR-0003) | Standard Godot user path. |
| `SETTINGS_PATH` | `user://settings.cfg` | Locked | Owned by Settings, not this system. Listed for clarity. |
| `FORMAT_VERSION` | `1` at MVP | int ≥ 1 | Increment on any schema change to `SaveGame`. Refuse-load-on-mismatch. |

### Quicksave/Quickload behavior

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `QUICKSAVE_KEY_DEBOUNCE_MS` | 500 | 200–1500 | Prevents F5-spam from producing rapid duplicate saves. |
| `QUICKSAVE_CONFIRMATION` | HUD notification, non-blocking | Boolean | Brief toast-style notification; no modal. |
| `QUICKLOAD_CONFIRMATION` | No confirmation | Boolean | Immediate load; player can reload the slot they came from if they hit F9 accidentally. |

### Screenshot

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `SCREENSHOT_ENABLED` | `true` | Boolean | Captured at save time; stored at `slot_N_thumb.png`. Disabling saves ~40 KB per slot. |
| `SCREENSHOT_RESOLUTION` | 320×180 | 160×90 to 640×360 | Low-res thumbnail for menu card display. |
| `SCREENSHOT_FORMAT` | PNG | PNG / JPG | PNG preferred for pixel fidelity on the stylized visual identity; JPG saves ~3× disk. |

### Debug & testing

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `SAVE_VERBOSE_LOGGING` | `false` in release, `true` in debug | Boolean | Emits detailed write-path logs to Godot output. |
| `SIMULATE_IO_FAILURE` | `false` | Boolean | Debug-only; forces `ResourceSaver.save()` to report failure. Used to test `save_failed` error UI. |

### NOT owned by this GDD

- Volume, input binding, accessibility toggle values → Settings & Accessibility
- Scene-loading duration + fade-to-black timing → Level Streaming (system 9) + Menu System
- Save-card visual design, typography, layout → Menu System + ADR-0004 UI Framework
- Screenshot compositing (is the HUD visible in the screenshot?) → design question for Menu System GDD

## Visual/Audio Requirements

**Minimal** — Save/Load owns no VFX and no audio assets directly. Player-facing feedback for save/load events is owned by downstream systems:

- **Save-confirm chime** (short "period bell" SFX on Quicksave success) — owned by Audio system, triggered by Audio's subscription to `Events.game_saved` (SFX bus, ~200 ms). See **Audio GDD §Interactions → Persistence domain** (added 2026-04-20 as cross-review B6 resolution — section reference updated from the obsolete "Section C.3 Mission domain" that never existed).
- **Save-failed error sting** (descending minor two-note) — owned by Audio system, triggered by Audio's subscription to `Events.save_failed`. Plays on SFX bus in addition to the Menu System dialog below.
- **Save-failed error dialog** — owned by Menu System. Shown as a period mission-dossier card (per Art Bible 7D). Menu System subscribes to `Events.save_failed`.
- **Scene fade-to-black on load** — owned by Level Streaming (system 9). Timing: 0.3 s fade out → section load → 0.5 s fade in.
- **HUD toast for Quicksave/Quickload** — owned by HUD State Signaling (system 19). Brief center-lower strip text ("Quicksave to slot 0" / "No quicksave available").
- **Save thumbnail screenshot** — captured by Save/Load itself at save time (`get_viewport().get_texture().get_image()` downsampled to 320×180), saved as `slot_N_thumb.png`. No visual effects applied.

## UI Requirements

**Owned by Menu System** (system 21), **consumed from Save/Load's API**:

- **Load Game screen** — 8-slot grid (0 = autosave visible as a normal card per CR-10; 1–7 manual). Each card shows section display name (localized), timestamp, elapsed time, thumbnail. Empty slots show "Empty" card. Corrupt slots show "Corrupt — cannot load" card. Cards read via `SaveLoad.slot_metadata(N)` (sidecar only, no full load).
- **Save Game screen (Pause Menu only)** — 7-slot grid (slots 1–7 visible, slot 0 is not user-selectable from save picker — it's autosave only, per CR-4 and CR-11). Player selects a slot; confirm dialog if slot is OCCUPIED; save fires.
- **Save-failed dialog** — modal card appearing on `Events.save_failed`. Text localized via Localization Scaffold. Non-blocking close; game continues.
- **Save thumbnail** — 320×180 PNG auto-generated at save time; stored at `slot_N_thumb.png`. Menu renders it in the card frame.

**Save/Load provides** (API surface consumed by Menu System):

| Method | Purpose |
|---|---|
| `slot_exists(N: int) -> bool` | Menu checks before rendering card |
| `slot_metadata(N: int) -> Dictionary` | Returns fast sidecar read (no full Resource load) for card display |
| `save_to_slot(N: int, save_game: SaveGame) -> bool` | Menu calls after player assembles a SaveGame via Mission Scripting |
| `load_from_slot(N: int) -> SaveGame` | Menu calls on player confirmation; returns null on failure |

**📌 UX Flag — Save / Load**: The Load Game screen, the Pause Menu Save Game screen, and the save-failed dialog all need UX specs in Phase 4. Run `/ux-design` on these screens before writing Menu System epics. Stories that reference save UX should cite `design/ux/load-game-screen.md`, `design/ux/save-game-screen.md`, and `design/ux/save-failed-dialog.md`, not the save-load GDD directly.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Save format contract | `docs/architecture/adr-0003-save-format-contract.md` | Binary .res, sectional scope, refuse-load-on-mismatch, 8 slots, atomic write, `actor_id` convention, `duplicate_deep()` on load | Implementation contract — this GDD inherits all decisions |
| Signal taxonomy | `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` + `design/gdd/signal-bus.md` | `Events.game_saved`, `Events.game_loaded`, `Events.save_failed` | Data dependency (Save/Load publishes) |
| String keys for save metadata | `design/gdd/localization-scaffold.md` | `meta.*` key prefix for `section_display_name`, etc. | Data dependency |
| Input bindings (F5 / F9) | `design/gdd/input.md` | `quicksave` = `F5`, `quickload` = `F9` actions | Data dependency |
| InputContext cutscene gate | `docs/architecture/adr-0004-ui-framework.md` | `InputContext.CUTSCENE` blocks save inputs | Rule dependency |
| Settings separation | `docs/architecture/adr-0003-save-format-contract.md` | Settings in `user://settings.cfg`, never part of SaveGame | Rule dependency |
| Actor identity scheme | `docs/architecture/adr-0003-save-format-contract.md` | `@export var actor_id: StringName` on each guard/civilian scene | Rule dependency |
| Forbidden patterns | `docs/registry/architecture.yaml` | `save_service_assembles_state`, `save_state_uses_node_references`, `forgotten_duplicate_deep_on_load` | Rule dependency |

## Acceptance Criteria

### Core save/load behavior

1. **GIVEN** Mission Scripting fires `section_entered(restaurant_id)`, **WHEN** the save handler runs, **THEN** `user://saves/slot_0.res` is written AND `user://saves/slot_0_meta.cfg` contains `section_id = "restaurant"` AND `Events.game_saved.emit(0, "restaurant")` fires.
2. **GIVEN** player selects slot 3 in Pause Menu Save Game screen, **WHEN** save fires, **THEN** both `slot_3.res` AND `slot_0.res` are written with the same `SaveGame` payload (per CR-4).
3. **GIVEN** player hits F5 during active gameplay, **WHEN** the save completes, **THEN** `slot_0.res` is updated AND the HUD shows a brief "Quicksave to slot 0" notification.
4. **GIVEN** player hits F5 during a cutscene, **WHEN** the input is processed, **THEN** no save fires (InputContext gate blocks).
5. **GIVEN** player hits F9 when slot 0 is empty, **WHEN** input is processed, **THEN** no load fires AND HUD shows "No quicksave available" notification.
6. **GIVEN** player selects a valid save slot from Load Game screen, **WHEN** load fires, **THEN** screen fades to black, section reloads via Level Streaming, all `*_State` sub-resources are `duplicate_deep()`-ed and applied to live systems, `Events.game_loaded.emit(N)` fires, and fade-in completes.

### Atomicity & failure handling

7. **GIVEN** `ResourceSaver.save()` returns a non-OK error during save, **WHEN** Save/Load responds, **THEN** `Events.save_failed.emit(FailureReason.IO_ERROR)` fires AND the previous slot file (if any) is untouched.
8. **GIVEN** a save operation is in progress, **WHEN** a second `save_to_slot` call is made, **THEN** the second call is queued and processes sequentially after the first completes (no overlapping writes).
9. **GIVEN** a save file exists but its `save_format_version` field is lower than current `SaveGame.FORMAT_VERSION`, **WHEN** `load_from_slot` is called, **THEN** it returns null AND `Events.save_failed.emit(FailureReason.VERSION_MISMATCH)` fires.
10. **GIVEN** `ResourceLoader.load(slot_path)` returns null or wrong type, **WHEN** `load_from_slot` processes, **THEN** it returns null AND `Events.save_failed.emit(FailureReason.CORRUPT_FILE)` fires.

### Slot metadata & Menu integration

11. **GIVEN** `SaveLoad.slot_metadata(3)` is called on an occupied slot, **WHEN** the call returns, **THEN** only the `slot_3_meta.cfg` sidecar is read (verify via file I/O trace) — `slot_3.res` is NOT loaded.
12. **GIVEN** `slot_3.res` exists but `slot_3_meta.cfg` is missing, **WHEN** `slot_metadata(3)` is called, **THEN** a minimal fallback Dictionary is returned with `saved_at_iso8601` read from the `.res` itself (partial-save-recovery path).
13. **GIVEN** Menu System's Load Game screen renders, **WHEN** 8 cards are displayed, **THEN** slot 0 appears as a normal card alongside slots 1–7 (not hidden).
14. **GIVEN** Menu System's Pause Menu Save Game screen renders, **WHEN** slots are displayed, **THEN** only slots 1–7 appear (slot 0 is not in the Save picker).

### Serialization correctness

15. **GIVEN** a `SaveGame` is written and then loaded, **WHEN** each `*_State` sub-resource is compared, **THEN** all fields round-trip bit-exactly (Resource equality check).
16. **GIVEN** a guard with `actor_id = "plaza_guard_01"` has `alert_state = SUSPICIOUS` and `patrol_index = 3` at save time, **WHEN** the save is loaded, **THEN** the guard's restored state matches exactly AND no other guard's state is corrupted by the restoration.
17. **GIVEN** a loaded `SaveGame`, **WHEN** the caller calls `loaded.duplicate_deep()`, **THEN** mutations to the duplicated copy's nested resources do NOT affect the original.
18. **GIVEN** a caller forgets `duplicate_deep()` on load, **WHEN** code review runs, **THEN** the violation is flagged per forbidden_pattern `forgotten_duplicate_deep_on_load`. *Classification: code-review checkpoint.*

### Cross-system integration

19. **GIVEN** player dies in Restaurant section, **WHEN** Failure & Respawn triggers save-to-slot-0 followed by load-from-slot-0, **THEN** the player respawns at the Restaurant section start (or at their manual save state if a manual save has occurred mid-section) AND all systems restore correctly.
20. **GIVEN** a cutscene has played in a section, **WHEN** the player loads a save from that section, **THEN** `MissionState.triggers_fired` contains the cutscene's trigger AND Cutscenes & Mission Cards does NOT replay it.
21. **GIVEN** the player saves to slot 2 mid-section, then quits and relaunches the game, then loads slot 2, **WHEN** the load completes, **THEN** the section, player state, inventory, AI state, and document collection all match the save exactly.

### Performance

22. **GIVEN** a normal save operation on SSD, **WHEN** save completes, **THEN** the elapsed time from `save_to_slot` call to `Events.game_saved` emit is ≤10 ms (per ADR-0003 budget).
23. **GIVEN** a normal load operation, **WHEN** the I/O phase completes (before scene transition), **THEN** elapsed time is ≤2 ms.

### Anti-pattern enforcement

24. **GIVEN** `SaveLoadService.gd` source, **WHEN** grepped, **THEN** it contains no references to `PlayerCharacter`, `StealthAI`, or any other gameplay system node name (per `save_service_assembles_state` forbidden pattern). *Classification: lint check.*
25. **GIVEN** any `*_State` Resource source file, **WHEN** grepped, **THEN** it contains no `NodePath` or `Node`-typed `@export` properties (per `save_state_uses_node_references` forbidden pattern). *Classification: lint check.*

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Screenshot composition — should the HUD be visible in the save thumbnail, or hidden? | Menu System GDD author + game designer | Before Menu System implementation | Recommendation: hide HUD for cleaner thumbnail showing the scene. Requires a temporary HUD-hidden render at save time. Defer to Menu System GDD. |
| Should Cloud Save (Steam Cloud) integration be scoped for MVP? | Producer | Before Steam store page preparation | Current scope: no. `user://saves/` is local-only at MVP. Steam Cloud is a Valve-owned metadata config post-launch and does not require engineering changes to this GDD. |
| What happens if `user://` storage is read-only or unavailable? (permissions, sandbox issues on specific Linux distros) | Gameplay-programmer | Before public beta | Detect at startup; show a clear warning dialog "Save files cannot be written — game will run in no-save mode." Pause-menu Save Game and F5 are disabled; section transitions skip autosave. Player can play but cannot save. Graceful degradation. |
| Should quickload require a confirmation modal? | Game designer + UX designer | Before Menu System GDD is finalized | Current draft: no confirmation (CR-5 + Tuning Knobs). Fast quickload is the point. If playtest shows accidental F9 is a common complaint, revisit. |
| When a save is attempted during InputContext == CUTSCENE and input is blocked, should the system log a missed-keypress warning or silently ignore? | Gameplay-programmer | Debug-only concern | Recommendation: silent in release, verbose log in debug (per `SAVE_VERBOSE_LOGGING` tuning knob). |
| Tier 2 (Rome/Vatican mission) — when/if scoped, will the save format increment `FORMAT_VERSION`? | Producer + systems-designer | Before Tier 2 development | ADR-0003 documented this as a risk: refuse-load-on-mismatch versioning means Tier 2 could invalidate Paris saves. Mitigation: keep SaveGame schema stable; add new fields only as optional (default values). |
