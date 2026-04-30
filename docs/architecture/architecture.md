# The Paris Affair — Master Architecture

## Document Status

| Field | Value |
|---|---|
| **Version** | 1.0 (initial draft — all 9 sections authored via `/create-architecture`) |
| **Started** | 2026-04-23 |
| **Last Updated** | 2026-04-23 (Phase 7 complete — Architecture Principles + Open Questions written; TD sign-off recorded below) |
| **Engine** | Godot 4.6 · GDScript · Forward+ (Vulkan on both Linux and Windows — D3D12 disabled per project Amendment A2) · Jolt 3D default |
| **Platform** | PC — Linux + Windows (Steam). Single-player, no networking. |
| **Performance Contract** | 60 fps · 16.6 ms · ≤1500 draw calls · ≤4 GB (technical-preferences.md; allocated by ADR-0008). |
| **GDDs Covered** | **23 / 23 authored** — all MVP + VS systems designed (last metadata refresh 2026-04-29 post-`/architecture-review` seventh run). Per-system status tracked in `design/gdd/systems-index.md`. |
| **ADRs Referenced** | ADR-0001 · ADR-0002 · ADR-0003 · ADR-0004 · ADR-0005 · ADR-0006 · ADR-0007 · ADR-0008 (all Proposed; 30+ verification gates outstanding as of 2026-04-29). |
| **TR Registry** | `docs/architecture/tr-registry.yaml` (**348 TRs** across 23 system-slugs, ~99% ADR-covered per `requirements-traceability.md`). |
| **Review Mode** | `solo` (LP-FEASIBILITY step of Phase 7b skipped per skill rules). |
| **Technical Director Sign-Off** | **APPROVED WITH CONCERNS** — 2026-04-23 (self-review, solo mode). Gate TD-ARCHITECTURE against 4 criteria: TR coverage ✅ PASS (~99%), HIGH-risk engine domains ✅ PASS (all fenced), API boundaries ⚠ PASS WITH CONCERN (ADR-0007 amendment required for Combat autoload inclusion — Path A per godot-specialist 2026-04-23; see §6.3 + §7.2.1), Foundation ADR gaps ✅ PASS (all 8 authored and Proposed; 24 verification gates are normal Tech Setup path, not architectural gaps). |
| **Lead Programmer Feasibility** | SKIPPED — Solo mode per `production/review-mode.txt`. LP-FEASIBILITY gate does not run. |

---

## 1. Engine Knowledge Gap Summary

**LLM training cutoff**: ~May 2025 (approximately Godot 4.3). **Project pinned**: Godot 4.6 (Jan 2026). Three post-cutoff versions carry documented breaking or load-bearing changes that the project's architecture must honor:

### HIGH risk domains — each fenced by ≥1 ADR

| Domain | Post-cutoff concerns | Fencing ADR(s) |
|---|---|---|
| **Rendering** | Stencil buffer writes/reads (4.5); `CompositorEffect` post-process chain (4.3+ base, 4.6 production-pinned); ~~D3D12 default on Windows (4.6)~~ project disables D3D12 via Amendment A2 — Vulkan-only on both platforms; glow-before-tonemap (4.6); Shader Baker (4.5); SMAA 1x (4.5); specular occlusion (4.5). | ADR-0001 (stencil tier contract — **Accepted 2026-04-30**); ADR-0005 (FPS hands inverted-hull carve-out); ADR-0008 Slot #3 (outline + sepia 2.5 ms combined cap). |
| **UI** | Dual-focus system (4.6: mouse/touch vs KB/gamepad separated); AccessKit screen reader integration (4.5); FoldableContainer + Recursive Control disable (4.5); live translation preview (4.5). | ADR-0004 (Theme hierarchy + InputContext stack + `_unhandled_input`+`ui_cancel` dismiss grammar explicitly sidesteps 4.6 dual-focus complexity). |

### MEDIUM risk domains — each fenced by ≥1 ADR

| Domain | Post-cutoff concerns | Fencing ADR(s) |
|---|---|---|
| **Physics (Jolt)** | Jolt default for 3D (4.6; was 4.4 opt-in); `HingeJoint3D.damp` differences; `Area3D.body_entered` broadphase tunneling for fast bodies. | ADR-0006 (PhysicsLayers static class, 5 named layers); ADR-0006 A6 Risks row (Combat dart tunneling at 20 m/s mitigated via Combat OQ-CD-2 Jolt prototype); ADR-0008 Slot #4 (Jolt 0.5 ms). |
| **Resources / Save** | `Resource.duplicate_deep()` for nested trees (4.5); `FileAccess.store_*` returns `bool` (4.4 — not load-bearing; project uses `ResourceSaver` not `FileAccess` directly). | ADR-0003 (duplicate_deep MANDATORY on load; forbidden pattern `forgotten_duplicate_deep_on_load`). |
| **Localization** | CSV plural form support without Gettext (4.6); `Control.auto_translate_mode` (4.5); `NOTIFICATION_TRANSLATION_CHANGED` re-resolution. | GDD-scope (`design/gdd/localization-scaffold.md` TR-LOC-005/006/007); ADR-0004 mandates `tr()` wrap via forbidden pattern. |
| **GDScript** | Variadic args, `@abstract`, script backtracing (all 4.5; orthogonal — not load-bearing for architecture). | ADR-0002 (typed signal taxonomy uses stable 4.0+ syntax; script backtracing used for debug only via EventLogger). |

### LOW risk domains — in training data, no post-cutoff load-bearing changes

Audio API (no breaks 4.4–4.6), Navigation (4.5 dedicated 2D server — unused here, project is 3D-only), Input (stable 4.0+ `InputMap` / `Input.get_vector` API except 4.6 dual-focus already fenced by ADR-0004), Animation (4.6 IK restored — not MVP-critical), Core/Scripting (autoloads + signals stable since 4.0, registered via ADR-0007).

### Networking

**N/A** — single-player only (game-concept.md anti-pillar). `docs/engine-reference/godot/modules/networking.md` exists but is not consumed by this architecture.

### Coverage assertion

**Every HIGH-risk and MEDIUM-risk post-cutoff engine domain that this architecture touches is fenced by at least one accepted-or-proposed ADR.** No architectural decision in this document relies on an un-fenced post-cutoff API.

---

## 2. System Layer Map

The 23 authored-or-planned systems (plus the FootstepComponent sibling of Player Character) are assigned to the standard 5-layer model:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                                         │
│  UI · HUD · Menus · VFX · Audio   (9 systems)                               │
│  Audio (3) · Outline Pipeline (4) · Post-Process Stack (5) ·                │
│  HUD Core (16) · HUD State Signaling (19) · Document Overlay UI (20) ·      │
│  Menu System (21) · Cutscenes & Mission Cards (22) ·                        │
│  Settings & Accessibility (23)                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                              │
│  Gameplay · AI · Quests · Narrative   (8 systems)                           │
│  Stealth AI (10) · Combat & Damage (11) · Inventory & Gadgets (12) ·        │
│  Mission & Level Scripting (13) · Failure & Respawn (14) ·                  │
│  Civilian AI (15) · Document Collection (17) · Dialogue & Subtitles (18)    │
├─────────────────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                                 │
│  Input · Player movement · Physics primitives   (3 systems)                 │
│  Input (2) · Player Character (8) · FootstepComponent (8b)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                                           │
│  Signal bus · Save/Load · Scene management · Localization   (4 systems)     │
│  Signal Bus (1) · Save / Load (6) · Localization Scaffold (7) ·             │
│  Level Streaming (9)                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                                             │
│  Godot 4.6 engine API surface (no project code)                             │
│  Forward+ Mobile renderer · Jolt 3D physics · AudioServer ·                 │
│  InputMap · FileAccess / DirAccess · ResourceSaver / ResourceLoader ·       │
│  CompositorEffect scheduler · NavigationServer3D · TranslationServer        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Full assignment table

| Layer | # | System | Tier | Engine risk | GDD status |
|---|---|---|---|---|---|
| **Presentation** | 3 | Audio | MVP | LOW | Approved (2026-04-21) |
| | 4 | Outline Pipeline | MVP | MEDIUM (stencil 4.5, CompositorEffect — Vulkan-only per A2; ADR-0001 Accepted 2026-04-30) | Designed (re-review pending) |
| | 5 | Post-Process Stack | MVP | **HIGH** (Compositor chain, glow-before-tonemap 4.6) | Designed (re-review pending) |
| | 16 | HUD Core | MVP | **HIGH** (4.6 dual-focus, Theme) | Not Started |
| | 19 | HUD State Signaling | VS | MED (signal subscribers only) | Not Started |
| | 20 | Document Overlay UI | VS | **HIGH** (modal + sepia dim lifecycle + Theme) | Not Started |
| | 21 | Menu System | VS | **HIGH** (Theme + focus + SaveLoad dossier) | Not Started |
| | 22 | Cutscenes & Mission Cards | VS | MED (scene stacking + subtitle suppression) | Not Started |
| | 23 | Settings & Accessibility | VS | **HIGH** (AccessKit 4.5, resolution-scale writer, persistence) | Not Started |
| **Feature** | 10 | Stealth AI | MVP | MED (Jolt, NavigationAgent3D async) | Approved (2026-04-22) |
| | 11 | Combat & Damage | MVP | MED (Jolt Area3D, dart CCD, BoneAttachment3D) | Approved (2026-04-22) |
| | 12 | Inventory & Gadgets | MVP | LOW | Not Started |
| | 13 | Mission & Level Scripting | MVP | LOW | Not Started |
| | 14 | Failure & Respawn | MVP | LOW | Not Started |
| | 15 | Civilian AI | MVP (stub) / VS (full) | MED (Jolt) | Not Started |
| | 17 | Document Collection | VS | LOW | Not Started |
| | 18 | Dialogue & Subtitles | VS | LOW | Not Started |
| **Core** | 2 | Input | MVP | MED (4.6 dual-focus awareness) | Designed (re-review pending) |
| | 8 | Player Character | MVP | MED (Jolt CharacterBody3D, SubViewport hands) | Approved (2026-04-21) |
| | 8b | FootstepComponent | MVP | LOW | Approved (2026-04-21) |
| **Foundation** | 1 | Signal Bus | MVP | LOW | Designed (re-review pending) |
| | 6 | Save / Load | MVP | MED (duplicate_deep 4.5, atomic rename) | Designed (re-review pending) |
| | 7 | Localization Scaffold | MVP | MED (4.6 CSV plurals, NOTIFICATION_TRANSLATION_CHANGED) | Designed (re-review pending) |
| | 9 | Level Streaming | MVP | LOW | Approved (2026-04-21) |
| **Platform** | — | Godot 4.6 engine: Forward+ Mobile renderer · Jolt 3D physics · AudioServer · InputMap · FileAccess / DirAccess · ResourceSaver / ResourceLoader · CompositorEffect scheduler · NavigationServer3D · TranslationServer | — | **HIGH aggregate** | N/A (external) |

### Deviations from `design/gdd/systems-index.md` informal layering

The systems index uses **Foundation · Core · Feature · Presentation · Polish**. This architecture applies the skill's standard model. The following systems move between labels (no architectural change — purely nomenclature):

| System | SI label | Architecture layer | Rationale |
|---|---|---|---|
| Audio (3) | Foundation | Presentation | Skill explicitly places "audio" in Presentation; Audio is a subscriber-only output layer in this project. |
| Outline Pipeline (4) | Foundation | Presentation | VFX/rendering; skill's Foundation is reserved for scene-mgmt + save + event bus. |
| Post-Process Stack (5) | Foundation | Presentation | Same. |
| Level Streaming (9) | Core | Foundation | Scene management is Foundation in the skill's model; matches ADR-0007's treatment as an autoload. |
| Settings & Accessibility (23) | Polish | Presentation | No "polish" layer in the skill's model; it is a UI surface that also writes settings.cfg. |

FootstepComponent (8b) is kept as its own Core row — it has its own approved GDD (`design/gdd/footstep-component.md`) and its own TR-FC-* namespace, and ADR-0002 treats it as a distinct publisher of `Events.player_footstep`.

### Layer-crossing rules (previewed; binding rules codified in §3 Data Flow and §5 API Boundaries)

1. **Dependencies flow DOWN** — higher layers consume lower layers. Never upward.
2. **Cross-layer communication goes through the Signal Bus** (Events autoload, ADR-0002) except for the **narrow accessor carve-outs** explicitly documented in ADR-0002's *Accessor Conventions (SAI → Combat)* subsection.
3. **Presentation never publishes state-mutating signals** — it consumes. (Settings & Accessibility is the only exception; it publishes `setting_changed`.)
4. **Foundation exposes autoloads only where ADR-0007 registers them** — 7 autoloads (per 2026-04-23 amendment), canonical line order: Events (1) → EventLogger (2) → SaveLoad (3) → InputContext (4) → LevelStreamingService (5) → PostProcessStack (6) → Combat (7).
5. **Platform is accessed only through the APIs enumerated in engine-reference/godot/modules/** — any post-cutoff API use requires an ADR citation.

### Engine-risk touch-point summary per layer

- **Presentation** touches 4 HIGH-risk domains (rendering stencil, CompositorEffect, 4.6 dual-focus, AccessKit 4.5). Covered by ADR-0001, ADR-0004, ADR-0005, ADR-0008 Slot #3.
- **Feature** touches Jolt (ADR-0006) and NavigationAgent3D async behavior; subscriber-only for cross-system signals. Covered by ADR-0002, ADR-0006, ADR-0008 Slot #2.
- **Core** touches Jolt CharacterBody3D + InputMap + `_unhandled_input`+`ui_cancel` dismiss grammar (sidesteps 4.6 dual-focus). Covered by ADR-0004, ADR-0006, ADR-0008 Slot #5.
- **Foundation** touches `ResourceSaver`/`ResourceLoader`+`duplicate_deep` (4.5), `project.godot [autoload]` line order, `NOTIFICATION_TRANSLATION_CHANGED`. Covered by ADR-0002, ADR-0003, ADR-0007.
- **Platform** is the Godot 4.6 engine itself — not a project-authored layer. Every upward layer touches it only through the API surfaces enumerated in ADRs and engine-reference modules.

---

## 3. Module Ownership

For each module: **Owns** (sole responsibility) · **Exposes** (public API callable from other layers) · **Consumes** (reads from other modules) · **Engine APIs** (post-cutoff flagged in bold with risk tier). Sourced from the 10 approved GDDs, 8 ADRs, and TR registry.

### 3.1 Foundation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Signal Bus** (Events + EventLogger autoloads) | 36 typed signal declarations in `events.gd`. NO state, NO methods (forbidden patterns enforced). | `Events.<signal>.emit(args)` / `.connect(callable)` across 9 domains + Persistence + Settings | Nothing — sink-only bus | `signal` keyword (4.0+); `Signal.emit/connect/disconnect/is_connected`; `OS.is_debug_build()` for EventLogger self-removal |
| **Save / Load** (SaveLoad autoload) | 8 slots (0 autosave + 1–7 manual); atomic write protocol; `SaveLoad.FailureReason` enum; metadata sidecar `.cfg`; `user://settings.cfg` separation | `save_to_slot(slot, save_game)`, `load_from_slot(slot) -> SaveGame`, `slot_metadata(slot)`, `get_available_slots()`; emits `game_saved/loaded/save_failed` | Caller-assembled `SaveGame`; `Events.section_entered(FORWARD)` autosave gate; `InputContext.LOADING`/`CUTSCENE` save-blocks | `ResourceSaver.save(r, p, FLAG_COMPRESS)`; `ResourceLoader.load(p, t, CACHE_MODE_IGNORE)`; `DirAccess.rename()`; **`Resource.duplicate_deep()` [4.5, MEDIUM]**; `ConfigFile.load/save`; `OS.get_user_data_dir()` |
| **Localization Scaffold** (CSVs + convention; no autoload) | CSVs in `res://translations/` per domain; pseudolocalization CSV `_dev_pseudo.csv`; key naming scheme (`domain.context.identifier`) | Not an API module — it is a CONVENTION: every user-visible string wrapped in `tr(key)`; key registry lives in the CSVs | Locale preference read from `settings.cfg`; `NOTIFICATION_TRANSLATION_CHANGED` re-resolution | `tr(key)` built-in; `TranslationServer.set_locale()`; **`Control.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS` [4.5, MEDIUM]**; **CSV plural form columns [4.6, MEDIUM]**; `String.format({"count": n})` |
| **Level Streaming** (LevelStreamingService autoload) | `SectionRegistry` Resource (section_id → PackedScene); 13-step swap sequence; queued-respawn state; CanvasLayer 127 fade overlay (autoload-parented); ErrorFallback at CanvasLayer 126; `TransitionReason` enum | `transition_to_section(id, reason)`, `reload_current_section(reason)`, `register_restore_callback(callable)`; emits `section_entered/exited(id, reason)`, `respawn_triggered(id)` | `InputContext.LOADING` push/pop; restore callbacks at step 9 (synchronous); respawn queue drain at step 13 | `ResourceLoader.load(scene, "PackedScene", CACHE_MODE_REUSE)`; `PackedScene.instantiate()`; `Node.queue_free/add_child`; `await get_tree().process_frame`; `CanvasLayer` (max signed-8bit = 127) |

### 3.2 Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Input** (InputContext autoload + `InputActions` static class) | 30 named InputMap actions (27 gameplay/UI + 3 debug); `InputActions.*` StringName constants; InputContext stack {GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, CUTSCENE, LOADING}; binding persistence in `user://settings.cfg` | `InputContext.push/pop/is_active(context)`; `InputActions.MOVE_FORWARD` etc.; runtime rebinding via `InputMap.action_erase_events` + `action_add_event` | Every `_unhandled_input` handler checks `InputContext.is_active(GAMEPLAY)` before consuming | `InputMap.add_action/action_add_event/action_erase_events`; `Input.get_vector/is_action_just_pressed/is_action_pressed`; `get_viewport().set_input_as_handled()`; **SDL3 gamepad backend [4.5, transparent]**; **4.6 dual-focus sidestepped via `_unhandled_input` + `ui_cancel` (ADR-0004)** |
| **Player Character** (PlayerCharacter scene root = CharacterBody3D) | CapsuleShape3D (1.7 m standing / 1.1 m crouched); health 0–100; movement state machine (IDLE/WALK/SPRINT/CROUCH/JUMP/FALL/DEAD); `NoiseEvent` spike-latch; HandsOutlineMaterial via `material_overlay` (ADR-0005 exception); interact raycast 2.0 m priority 0–3; `apply_damage()` is ONLY health mutator; `reset_for_respawn()` ordered reset | `get_noise_level() -> float`, `get_noise_event() -> NoiseEvent`, `get_silhouette_height() -> float`, `apply_damage(amount, source, damage_type)`; emits `player_damaged/died/health_changed/interacted` | InputActions (MOVE_*, JUMP, CROUCH, SPRINT, INTERACT, FIRE, TAKEDOWN, AIM, USE_GADGET, SWITCH_WEAPON); `InputContext.is_active(GAMEPLAY)` gate | `CharacterBody3D.move_and_slide()` + **Jolt [4.6 default, MEDIUM]**; `is_on_floor()`; `PhysicsRayQueryParameters3D`; `CapsuleShape3D`; `SubViewport` (FPS hands FOV 55°); `material_overlay` slot |
| **FootstepComponent** (FC child of PlayerCharacter) | Step cadence state machine (Walk 2.2 Hz / Sprint 3.0 Hz / Crouch 1.6 Hz); surface tag lookup via `get_meta('surface_tag')`; accumulator for phase preservation | emits `player_footstep(surface: StringName, noise_radius_m: float)` | Parent CharacterBody3D (`velocity`, `is_on_floor`); `player.get_noise_level()`; downward raycast on MASK_FOOTSTEP_SURFACE | `PhysicsRayQueryParameters3D`; `Object.get_meta/set_meta`; `_physics_process` |

### 3.3 Feature Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Stealth AI** (guard instances, scene-authored — NOT autoload) | 6-state alert machine {UNAWARE → SUSPICIOUS → SEARCHING → COMBAT} + terminals {UNCONSCIOUS, DEAD}; 5 formulas F.1–F.5; `StealthAI.AlertState/AlertCause/Severity/TakedownType` enums; per-guard `_perception_cache` struct; `WAKE_UP_SEC = 45 s`; `IRaycastProvider` DI interface | `has_los_to_player() -> bool`, `takedown_prompt_active(attacker) -> bool`, `receive_damage(amount, source, type) -> bool is_dead`, `receive_takedown(type, attacker)`; emits 6 signals (alert_state_changed, actor_became_alerted, actor_lost_target, takedown_performed, guard_incapacitated, guard_woke_up) | `player.get_noise_event()`, `player.global_position`; `Combat.is_lethal_damage_type()`; IRaycastProvider LOS | `NavigationAgent3D`; `PhysicsRayQueryParameters3D`; `Area3D` vision cones (static); `CharacterBody3D` + **Jolt [MEDIUM]**; `Timer` |
| **Combat & Damage** (Combat autoload; `class_name CombatSystemNode`) | Damage-routing hub; weapon roster (blade, silenced pistol, dart, rifle, fists); `DamageType` + `DeathCause` enums; `is_lethal_damage_type()` helper; per-guard GuardFireController state machine; crosshair + tri-band halo; NOLF1 ammo economy constants | `apply_damage_to_actor(actor, amount, source, type)`, `is_lethal_damage_type(type) -> bool`, `damage_type_to_death_cause(type) -> DeathCause`; emits `enemy_damaged/killed/weapon_fired/ammo_changed` | `player.apply_damage` + `guard.receive_damage` (ducktype routing); `SAI.has_los_to_player/takedown_prompt_active`; `Events.respawn_triggered` (self-subscribe per-dart) | `PhysicsRayQueryParameters3D` + **Jolt [MEDIUM]**; `ShapeCast3D` + SphereShape3D 0.35 m (no ConeShape3D in 4.6); `Area3D` head hitbox on `BoneAttachment3D` at bone `"head"`; `RigidBody3D` CCD darts 20 m/s on LAYER_PROJECTILES **(ADR-0006 A6 Risk: Jolt broadphase tunneling)** |
| **Inventory & Gadgets** (Inventory component on PC; not yet authored) | Current weapon, ammo/reserve per weapon, equipped gadget, gadget cooldowns | `switch_weapon(id)`, `use_gadget()`, `get_ammo(id)`; emits `gadget_equipped/used/weapon_switched/ammo_changed` | InputActions.SWITCH_WEAPON / USE_GADGET (mutex on `SAI.takedown_prompt_active`); `Events.enemy_killed` (drop economy); `Events.respawn_triggered` | Signal plumbing; `Timer` for cooldowns |
| **Mission & Level Scripting** (per-mission scripts; scene-authored; not yet authored) | Objective state machine; scripted triggers (Area3D volumes); mission-state serialization | emits `objective_started/completed/mission_started/completed` | `Events.section_entered(FORWARD)` autosave + objective fire; `enemy_killed/document_collected/dialogue_line_finished` | `Area3D` trigger volumes; group membership |
| **Failure & Respawn** (Failure autoload or Mission-owned; not yet authored) | Death-to-respawn orchestration; sectional-restart contract | emits `respawn_triggered` | `Events.player_died`; calls `LevelStreamingService.reload_current_section(RESPAWN)` | Signal plumbing only |
| **Civilian AI** (scene-authored; not yet authored; MVP stub / VS full) | Civilian state {calm, panicked, fleeing}; witness-reporting (VS only — alerts nearest guard) | emits `civilian_panicked/witnessed_event` | `player.global_position`; `Events.weapon_fired`, `Events.alert_state_changed` | `NavigationAgent3D`; `CharacterBody3D` + **Jolt [MEDIUM]** |
| **Document Collection** (Document system + per-doc Resources; not yet authored) | Document registry (15–25 docs); collected-bit state; per-document localized strings | emits `document_collected/opened/closed` | `Events.player_interacted(target)` where target is a Document node; `tr()` for text; ADR-0003 bitmap serialization | `Area3D` or interactable node; `tr()` / TranslationServer |
| **Dialogue & Subtitles** (Dialogue system; not yet authored) | Dialogue-line playback state; subtitle renderer; speaker attribution | emits `dialogue_line_started/finished` | `Events.alert_state_changed` (banter trigger via SAI severity); `InputContext.DOCUMENT_OVERLAY` suppresses subtitle render | `AudioStreamPlayer3D` for VO; `Label`/`RichTextLabel` for subtitle |

### 3.4 Presentation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| **Audio** (AudioManager Node in persistent root scene — NOT autoload per TR-AUD-003) | 5 named buses (Music/SFX/Ambient/Voice/UI); 3-layer music (MusicDiegetic + MusicNonDiegetic + MusicSting); music state grid; 16-voice spatial SFX pool (pre-allocated; oldest-non-critical steal); dominant-guard `Dictionary[Node, AlertState]`; stinger debounce (0.5 s at 120 BPM); per-section reverb preset; section music preload | Subscriber-only — no public API. Inspector helpers `get_active_voices()`, `get_last_stolen_slot_id()` | 30 signals subscribed across 9 domains + Settings. Never publishes. | `AudioServer.get_bus_index/set_bus_volume_db/set_bus_mute`; `AudioStreamPlayer`, `AudioStreamPlayer3D`; `AudioEffectReverb`; `Tween.tween_property("volume_db", ...)` — all stable 4.0+ |
| **Outline Pipeline** (OutlineCompositorEffect + `OutlineTier` static helper) | `CompositorEffect` for outline pass + Sobel/Laplacian edge-detect shader; `OutlineTier.NONE/HEAVIEST/MEDIUM/LIGHT` constants; `resolution_scale` uniform; single near-black outline color `#1A1A1A` | `OutlineTier.set_tier(mesh: MeshInstance3D, tier: int)`; CompositorEffect resource attached to WorldEnvironment | Per-object stencil writes from ShaderMaterial or BaseMaterial3D (per verification gate result); `Settings.get_resolution_scale()`; ADR-0005 — FPS hands exempt | **`ShaderMaterial.set_stencil_write_value()` [4.5, HIGH]**; **`CompositorEffect` + shader stencil read [4.5, HIGH]**; **Shader Baker [4.5]** for pre-compile |
| **Post-Process Stack** (PostProcessStack autoload) | Chain order locked: Outline → Sepia Dim → Resolution Scale Composition; sepia-dim state + 0.5 s ease tween; glow disabled project-wide in WorldEnvironment; `Viewport.scaling_3d_scale` wire-up | `PostProcessStack.enable_sepia_dim()`, `disable_sepia_dim()` | `Events.setting_changed` for resolution_scale updates; Document Overlay triggers sepia via lifecycle call from UI Framework | **`CompositorEffect` chain [HIGH 4.5/4.6]**; `Viewport.scaling_3d_scale`; `WorldEnvironment.environment.tonemap_mode = TONEMAP_LINEAR`; **glow-before-tonemap [4.6] N/A because glow disabled (TR-PP-004)** |
| **HUD Core** (HUD scene; not yet authored) | Health readout, ammo indicator, weapon icon, gadget indicator, interact prompt | Subscriber-only refresh; no public API | `Events.player_health_changed/ammo_changed/weapon_switched/gadget_equipped/player_interacted`; Theme inherits `project_theme.tres` (ADR-0004); `FontRegistry` static class | `Control`, `Label`, `TextureRect`, `Theme`; **`Control.auto_translate_mode` [4.5]**; **no focused widgets — dismiss via `_unhandled_input` (ADR-0004)** |
| **HUD State Signaling** (VS; not yet authored) | Alarm indicator (subtle — no persistent alert bar, Pillar 5); pickup-notification toasts; critical-health clock-tick indicator | Subscriber-only | `Events.alert_state_changed` (severity filter), `document_collected`, `player_health_changed` | Same as HUD Core |
| **Document Overlay UI** (VS; not yet authored) | Document reader modal; sepia-dim lifecycle trigger; Futura + American Typewriter fonts for document body | `DocumentOverlay.open(document_id)`, `DocumentOverlay.close()` | `Events.document_opened/closed`; `InputContext.DOCUMENT_OVERLAY` push/pop; calls `PostProcessStack.enable_sepia_dim()`/`disable_sepia_dim()`; `tr()` for document text; ADR-0004 Theme | `Control`, **`RichTextLabel.push_meta(meta, tooltip)` [4.4 new param]**; **`Control.auto_translate_mode` [4.5]** |
| **Menu System** (VS; not yet authored) | Main menu, pause menu, save-slot dossier cards | Triggered via `InputActions.PAUSE`; delegates save/load to SaveLoadService | `SaveLoad.slot_metadata(slot)` (read-only; never loads full `.res`); `SaveLoad.save_to_slot/load_from_slot`; `InputContext.MENU/PAUSE` push; ADR-0004 Theme | `Control`, `Button`, `Theme`; **4.6 dual-focus handled**: `grab_focus()` for KB/gamepad + `_unhandled_input` for dismiss |
| **Cutscenes & Mission Cards** (VS; not yet authored) | Cutscene playback; mission-card title screens | `Cutscenes.play(cutscene_id)` | `InputContext.CUTSCENE` push/pop (blocks saves); subtitle suppression routed to Dialogue; `Events.section_entered(NEW_GAME)` first-arrival suppression; `tr()` for card text | `AnimationPlayer` for cutscene playback; `Control` for mission cards |
| **Settings & Accessibility** (VS; not yet authored) | Resolution-scale writer; rebinding UI; audio volume sliders; crosshair accessibility toggle; photosensitivity rate-gate toggle (ADR-0008); input rebinding persistence | `Settings.get_resolution_scale()`, `Settings.get_crosshair_mode()`, etc.; emits `Events.setting_changed(category, name, value)` — **sole Variant payload carve-out in the taxonomy** | `user://settings.cfg` (separation from SaveGame per ADR-0003); AccessKit hooks | `ConfigFile`; **`Control.accessibility_*` properties [4.5, HIGH]**; **AccessKit integration [4.5, HIGH]** |

### 3.5 Platform Layer (engine surface — not authored)

The Godot 4.6 engine is the implicit bottom of the stack. It is not a project-authored layer; it is consumed by every layer above via the APIs enumerated in each module's row and fenced against drift by the `docs/engine-reference/godot/` library. Key engine surfaces consumed by this project:

- **Forward+ Mobile renderer** (required on Iris Xe per ADR-0008 constraints; Desktop profile out of budget)
- **Jolt 3D physics** (4.6 default — ADR-0006 A6 Risk: Area3D broadphase tunneling for fast bodies)
- **AudioServer + bus graph** (5 buses registered at boot — TR-AUD-002)
- **InputMap** (30 actions declared at boot — TR-INP-002)
- **FileAccess / DirAccess** (atomic rename for saves — ADR-0003)
- **ResourceSaver / ResourceLoader** (binary `.res` + FLAG_COMPRESS + CACHE_MODE_REUSE — ADR-0003, TR-LS-010)
- **CompositorEffect scheduler** (outline + sepia chain — ADR-0001, TR-OUT-005, TR-PP-001)
- **NavigationServer3D** (SAI pathing; async behavior asserted — TR-SAI-018 performance budget)
- **TranslationServer** + **NOTIFICATION_TRANSLATION_CHANGED** (live-re-resolution — TR-LOC-007)

### 3.6 Layer-Crossing Dependency Diagram

```
                     ┌─────────────────────────────────────────────────────────┐
                     │  PLATFORM — Godot 4.6                                   │
                     │  (Forward+ Mobile · Jolt 3D · AudioServer · InputMap ·  │
                     │  ResourceSaver/Loader · CompositorEffect · NavServer3D) │
                     └──────────────────────────▲──────────────────────────────┘
                                                │ engine API calls
                  ┌───────────────┬─────────────┼─────────────┬──────────────────┐
                  │               │             │             │                  │
      ┌───────────┴───┐  ┌────────┴──────┐  ┌───┴──────┐  ┌───┴──────────────┐   │
      │  FOUNDATION   │  │  CORE         │  │ FEATURE  │  │  PRESENTATION    │   │
      │               │  │               │  │          │  │                  │   │
      │  Signal Bus ◄─┼──┼───────────────┼──┼──────────┼──┼──────────────────┤   │
      │  (Events)     │  │               │  │          │  │                  │   │
      │     ▲  ▲  ▲   │  │               │  │          │  │                  │   │
      │     │  │  └───┼──┼─ publishers ──┼──┼──┐    ┌──┼──┼─ subscribers ◄───┤   │
      │     │  │      │  │  (PC, FC)     │  │  │    │  │  │  (Audio, HUD,    │   │
      │     │  │      │  │               │  │  ▼    │  │  │   Menu, etc.)    │   │
      │     │  │      │  │               │  │ publ. │  │  │                  │   │
      │     │  │      │  │               │  │ (SAI, │  │  │                  │   │
      │     │  │      │  │               │  │ Combat│  │  │                  │   │
      │     │  │      │  │               │  │ Doc…) │  │  │                  │   │
      │     │  │      │  │               │  │       │  │  │                  │   │
      │  SaveLoad ◄───┼──┼─ Menu reads ──┼──┼───────┼──┼──┼─ SaveLoad.slot_  │   │
      │  (autoload)   │  │  slot_meta    │  │       │  │  │   metadata       │   │
      │     ▲         │  │               │  │       │  │  │                  │   │
      │     │         │  │               │  │       │  │  │  PostProcess ◄───┤   │
      │     │         │  │               │  │       │  │  │  Stack           │   │
      │  Localization─┼──┼─ tr() every   │  │       │  │  │  (autoload,      │   │
      │  (convention) │  │  string       │  │       │  │  │   API called by  │   │
      │     ▲         │  │               │  │       │  │  │   DocOverlay)    │   │
      │     │         │  │               │  │       │  │  │                  │   │
      │  LevelStream ─┼──┼── emits ──────┼──┼───────┼──┼──┼── subscribes ────┤   │
      │  -ingService  │  │  section_*    │  │       │  │  │                  │   │
      │  (autoload)   │  │  signals      │  │       │  │  │                  │   │
      └───────────────┘  └───────────────┘  └──────────┘  └──────────────────┘   │
                                                                                 │
   Narrow direct-call carve-outs (ADR-0002 Accessor Conventions — SAI → Combat): │
     • Combat.GuardFireController ─► SAI.has_los_to_player()                     │
     • Combat (takedown gate)     ─► SAI.takedown_prompt_active(attacker)        │
     • Combat.apply_damage_to_actor(actor, ...) duck-types to PC.apply_damage or │
       guard.receive_damage (references held from ray hits / group lookup)     ──┘

   Autoload line order (ADR-0007, canonical — no "load order N" label drift):
     1. Events          2. EventLogger      3. SaveLoad
     4. InputContext    5. LevelStreaming   6. PostProcessStack
```

### 3.7 Notes on Ownership Choices

- **Combat as autoload (not PC-owned component)**: matches ADR-0002 `class_name CombatSystemNode` / autoload-key `Combat` split. Callers invoke via the autoload (`Combat.apply_damage_to_actor(...)`); qualified-enum paths use the class name (`CombatSystemNode.DamageType`). Consistent with the `SignalBusEvents`/`Events` pattern on the Signal Bus itself.
- **Audio as persistent-root Node (not autoload)**: intentional per TR-AUD-003. AudioManager lives as a Node in the persistent root scene, connects subscriptions in `_ready`, disconnects in `_exit_tree` on game quit. This avoids inflating the autoload list beyond ADR-0007's 6 canonical autoloads and keeps Audio lifecycle aligned with the scene tree.
- **Localization as "convention, not module"**: it has no autoload and no module-level API surface. Its contract is distributed — every system is responsible for wrapping user-visible strings in `tr()` and using keyed CSV entries. The scaffold defines the keys, the CSVs, and the pseudolocalization pipeline; enforcement lives in code review + the `hardcoded_visible_string` forbidden pattern.
- **FootstepComponent as standalone Core row**: sibling to Player Character (per GDD status). It has its own approved GDD and its own TR-FC-* namespace. ADR-0002 treats it as a distinct publisher of `Events.player_footstep`. This preserves the "PC owns AI noise channel (get_noise_event); FC owns Audio channel (player_footstep)" seam established in the 2026-04-21 PC approval.

---

## 4. Data Flow

Seven data flows documented: **initialization order · frame update path · event/signal path · save/load path · respawn cycle · document-open coordination · takedown sequence**. Thread boundaries noted at the end.

### 4.1 Initialization order (cold boot → first frame)

Governed by ADR-0007 (canonical autoload line order) + scene-tree order after autoloads. Cold-start budget ≤50 ms (ADR-0008 non-frame budgets).

```
T=0  project.godot boot ───────────────────────────────────────────────────►

[Platform layer initializes] Godot engine: Forward+ Mobile renderer, Jolt
      physics, AudioServer bus graph (5 buses from project settings),
      InputMap (30 actions from project settings), TranslationServer.

[Foundation layer — autoload line order per ADR-0007]
  Line 1: Events         ─► signal decls resolved; no state; no _ready work
  Line 2: EventLogger    ─► if OS.is_debug_build(): connect to every Events
                              signal; else queue_free(self) (self-removes)
  Line 3: SaveLoad       ─► read user://saves/ slot index; parse metadata
                              sidecars; expose slot_metadata() + load_from_slot();
                              NO system-state queries (caller-assembly pattern)
  Line 4: InputContext   ─► empty stack; no context pushed until first scene
  Line 5: LevelStreaming ─► instantiate persistent CanvasLayer 127 (fade
         Service           overlay) + CanvasLayer 126 (ErrorFallback);
                            load SectionRegistry Resource
  Line 6: PostProcess    ─► instantiate CompositorEffect chain; wait for
         Stack             first WorldEnvironment to attach

[Core/Feature/Presentation layers — scene tree load]
  Main scene entry (MainMenu or first section):
    ├─ AudioManager Node in persistent root scene _ready()
    │   └─ connect subscriptions for 30 signals (TR-AUD-001 subscriber-only)
    ├─ WorldEnvironment _ready()
    │   └─ PostProcessStack attaches Compositor chain (glow disabled by
    │       Environment config per TR-PP-004)
    └─ Scene-local nodes per Godot scene-tree ready order:
        ├─ PlayerCharacter _ready() ─► push InputContext.GAMEPLAY
        ├─ Stealth AI guards _ready() ─► connect to required signals,
        │      initialize perception_cache struct
        └─ Mission script _ready() ─► connect to section_entered / enemy_killed /
               document_collected, start first objective
```

**Hazard (ADR-0007)** — `autoload_init_cross_reference` forbidden pattern: no autoload may call into another autoload from `_init()` — only from `_ready()` or later. Line-2 (EventLogger) can safely reference line-1 (Events) in `_ready()`; line-1 can never reference line-2+ in `_init()` or `_ready()` (they don't exist yet).

**Hazard (ADR-0002 Risks row)** — atomic-commit: if `Events.gd` references a qualified enum (e.g., `LevelStreamingService.TransitionReason`) before the owning script declares it, GDScript parse fails on project load → Events autoload never registers → every `Events.*` reference also fails to parse. Mitigation: single-PR bundling of enum + signal + consumer changes.

### 4.2 Frame update path (60 Hz, 16.6 ms Iris Xe cap)

Godot dispatches `_physics_process(delta)` at 60 Hz fixed, then renders at the monitor refresh rate (capped at 60 here). ADR-0008's 9-slot allocation binds the sum.

```
Frame N starts ─────────────────────────────────────────────────────────────►

[_physics_process phase — 60 Hz]
  (1) Input sampled by Godot engine internally.
      Consumer: PlayerCharacter reads via Input.get_vector() +
      _unhandled_input for press/hold actions. Gate: InputContext.is_active
      (GAMEPLAY) before consuming. After consume: set_input_as_handled().

  (2) Jolt physics step — Slot #4 (0.5 ms cap)
      PC + 12 guard CharacterBody3D move_and_slide; dart RigidBody3D CCD
      advance. Engine-internal; no gameplay code.

  (3) Player Character — part of Slot #5 (0.3 ms shared with FC + Combat
      non-GuardFire)
      State machine tick: gravity, coyote-time, jump, crouch transition,
      movement-state update. FPS hands animation update in SubViewport at
      FOV 55°.

  (4) FootstepComponent — part of Slot #5
      Check accumulator against state-keyed cadence (Walk 2.2 Hz / Sprint
      3.0 Hz / Crouch 1.6 Hz). If step fires: downward raycast on
      MASK_FOOTSTEP_SURFACE; lookup get_meta('surface_tag'); call
      PC.get_noise_level(); emit Events.player_footstep(surface,
      noise_radius_m).

  (5) Stealth AI (12 guards) — Slot #2 (6.5 ms combined envelope with
      Combat GuardFireController)
      Per-guard F.1 sight update (10 Hz cache cadence — not every frame);
      F.2 sound poll (10 Hz); accumulator decay; state transition check.
      NavigationAgent3D path query (async — completion via get_next_path_
      position on next poll). Emit alert_state_changed / actor_became_
      alerted / actor_lost_target / guard_incapacitated / guard_woke_up as
      state changes.

  (6) Combat GuardFireController — part of Slot #2 (0.5 ms P95 at 3-guard
      COMBAT density)
      Per-guard fire state machine {IDLE, DRAW, LOS, SUPPRESSION, CAPPED}.
      Calls guard.has_los_to_player() at transition points (cache-hit,
      10 Hz stale-safe). Synchronous direct-method-call carve-out from
      ADR-0002.

  (7) Combat non-GuardFire logic — part of Slot #5
      Damage routing on Fire / Takedown input; hitscan + dart-tick + fist
      ShapeCast (event-driven, not per-frame).

  (8) Civilian AI / Mission Scripting / Document Collection — Slot #8
      (0.8 ms pooled residual)
      Subscriber-driven or tick-on-signal. Not per-physics-frame for MVP.

[_process phase — render frame]
  (9) Animation + Skeleton3D update (engine-internal)

  (10) Camera3D + SubViewport composition (hands SubViewport at FOV 55°
       composited onto main view)

  (11) Opaque pass + directional shadows (1 cascade only — ADR-0008
       forbidden_pattern directional_shadow_second_cascade) + transparent —
       Slot #1 (3.8 ms)
       Forward+ Mobile renderer. Target ≤1500 draw calls.

  (12) PostProcessStack chain — Slot #3 (2.5 ms combined)
       Outline CompositorEffect (Sobel/Laplacian edge-detect reading
       stencil buffer per-pixel, branch kernel width by tier) → Sepia Dim
       (30% luminance + 25% saturation + warm-amber tint, off by default) →
       Resolution Scale Composition (75% on Iris Xe, 100% RTX 2060).

  (13) Audio dispatch — Slot #6 (0.3 ms)
       AudioServer mix; 16-voice spatial pool; Tween updates on music
       volume_db; reverb swap only on section_entered (not per-frame).

  (14) UI refresh — Slot #7 (0.3 ms)
       HUD Control nodes refresh ONLY on signal emission (ADR-0004 forbids
       polling). Menu/Document Overlay process only if modal active.

  (15) Reserve — Slot #9 (1.6 ms)
       Unallocated; absorbs OS jitter, Jolt first-contact spikes,
       AudioServer reverb-swap CPU stall (0.3–0.8 ms documented), and
       unknowns. (D3D12 heap pressure dropped 2026-04-30 Amendment A2 —
       D3D12 not targeted; Vulkan-only on both platforms.)

Frame N ends (≤16.6 ms) ────────────────────────────────────────────────────►
```

**Binding rule (ADR-0008)**: every per-frame slot is a **cap**, not a target. A system that exceeds its slot at the Restaurant reference scene fails CI even if total frame time is below 16.6 ms.

### 4.3 Event / signal path (cross-system communication)

All cross-system communication goes through the Events bus (ADR-0002) except for the narrow Accessor carve-out and the duck-type damage delegation.

```
┌───────────────────────────────────────────────────────────────────────┐
│  STANDARD PUB/SUB PATH (36 signals × many subscribers)                │
│                                                                       │
│  Publisher (any layer)                                                │
│     │ Events.signal_name.emit(args)                                   │
│     │   ──► Godot synchronous dispatch: all subscribers run in        │
│     │       connection-order on the SAME frame. Not queued.           │
│     ▼                                                                 │
│  Events.gd (Foundation) — no state, no methods, just signal decls     │
│     │                                                                 │
│     ▼                                                                 │
│  Subscribers (any layer)                                              │
│     │   connect in _ready(); disconnect with is_connected guard in    │
│     │   _exit_tree() (ADR-0002 IG3, non-negotiable)                   │
│     │                                                                 │
│     │   Node-typed payloads: MUST call is_instance_valid(n) before    │
│     │   dereference (ADR-0002 IG4)                                    │
│     ▼                                                                 │
│  Handler runs synchronously, returns, next subscriber runs            │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│  NARROW DIRECT-CALL CARVE-OUT (ADR-0002 Accessor Conventions)         │
│                                                                       │
│  Combat.GuardFireController  ──► guard.has_los_to_player() -> bool    │
│      (10 Hz stale-safe cache-hit path; read-only; no side effects)    │
│                                                                       │
│  Combat (takedown gate)      ──► guard.takedown_prompt_active(        │
│                                   attacker) -> bool                   │
│      (predicate: state + rear-arc + ≤1.5m + no LOS; read-only)        │
│                                                                       │
│  Both invoked on SPECIFIC guard instances (not autoloads by name).    │
│  Fence: no new accessors without ADR-0002 amendment.                  │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│  DUCK-TYPE DAMAGE DELEGATION (Combat hub — TR-CD-001/002)             │
│                                                                       │
│  Combat.apply_damage_to_actor(actor, amount, source, damage_type)     │
│     ├─ if actor.has_method("apply_damage"):    PC path                │
│     │     actor.apply_damage(amount, source, damage_type)             │
│     │     (synchronous mutation; emits player_damaged or player_died) │
│     │                                                                 │
│     └─ elif actor.has_method("receive_damage"): guard path            │
│           is_dead = actor.receive_damage(amount, source, damage_type) │
│           (SAI guarantees synchronous state mutation before return —  │
│            TR-SAI-014, AC-SAI-1.11 spy-proxy test)                    │
│           Combat owns emit-site: enemy_damaged first, enemy_killed    │
│           iff is_dead. Deterministic ordering per TR-CD-002.          │
└───────────────────────────────────────────────────────────────────────┘
```

**Concurrency note**: signal re-entry from inside a handler (e.g., `guard_incapacitated` handlers cascading into more state transitions) — Godot 4.x internal dispatch is safe; connected callables run to completion before the next emit processes, but subscriber order matters. Flagged for code review when subscribers land.

**Variant payload note**: `setting_changed(category, name, value: Variant)` is the sole Variant payload in the taxonomy — explicitly justified because setting values are genuinely heterogeneous (bool / int / float / String).

### 4.4 Save / load path

Two primary flows: **autosave on section entry** and **player-initiated load from menu**. Both obey ADR-0003's caller-assembly pattern (SaveLoad writes/reads files only; does NOT query systems).

#### 4.4.1 Autosave flow (FORWARD transition)

```
Mission Scripting             LevelStreamingService     SaveLoad      Events
──────────────────            ─────────────────────     ────────      ──────
                              [new section loaded,
                               step 11]
                              │
                              Events.section_entered
                              .emit(id, FORWARD) ──────────────────►  │
                                                                      │
Receives section_                                                     │
  entered(id, FORWARD) ◄────────────────────────────────────────────  │
  │
  Branches on reason:
  FORWARD → gate autosave ON
  RESPAWN | LOAD_FROM_SAVE |
  NEW_GAME → gate OFF
  │
  Assembles SaveGame from current system states:
  │   save.player_state     = player.serialize_state()
  │   save.inventory_state  = inventory.serialize_state()
  │   save.stealth_ai_state = build_guard_records()
  │   save.documents_state  = documents.serialize_state()
  │   save.mission_state    = self.serialize_state()
  │
  SaveLoad.save_to_slot(0, save_game) ─────────────► │
                                                     │
                                            [slot 0 = autosave]
                                            1. ResourceSaver.save(
                                                 save_game, tmp_path,
                                                 FLAG_COMPRESS)
                                            2. DirAccess.rename(tmp, final)
                                            3. ConfigFile sidecar write
                                            4. Optional screenshot write
                                            │
                                            Events.game_saved
                                            .emit(0, id) ───────────► │
                                                                      │
Subscriber: HUD State                                                 │
  Signaling receives game_ ◄──────────────────────────────────────────┘
  saved for toast (VS scope)
```

#### 4.4.2 Player-initiated load flow

```
Menu System                   SaveLoad           LevelStreamingService    Events
───────────                   ────────           ─────────────────────    ──────

User clicks load-
slot-3 dossier card
  │
  SaveLoad.slot_metadata(3) ─► │
                               │ reads cfg sidecar (cheap, no .res load)
  receives Dictionary ◄────────┘
  │
  Shows "Section: Restaurant
  | 00:45:22 elapsed"
  │
  User confirms load
  │
  SaveLoad.load_from_slot(3) ─► │
                                │ ResourceLoader.load(path, "SaveGame",
                                │   CACHE_MODE_IGNORE)
                                │ type-guard: null or not is SaveGame
                                │   → emit save_failed(CORRUPT_FILE)
                                │ save_game.duplicate_deep()  [4.5, MANDATORY]
                                │   per ADR-0003 — isolates loaded state
                                │   from any shared sub-Resources
  save_game ◄─────────────────  │
  │
  LevelStreamingService.transition_to_section(
      save_game.section_id,
      TransitionReason.LOAD_FROM_SAVE) ─────────► │
                                                  │
                                          [13-step swap sequence]
                                          ...step 9: invoke registered
                                          restore callbacks synchronously:
                                            pc.restore_from(save.player_state)
                                            sai.restore_from(save.stealth_ai_)
                                            inv.restore_from(save.inventory_)
                                            docs.restore_from(save.documents_)
                                            mission.restore_from(save.mission_)
                                          ...step 11: emit section_entered
                                                  (id, LOAD_FROM_SAVE) ─► │
                                                                          │
                                          ...step 13 (IDLE):              │
                                            SaveLoad emits                │
                                            game_loaded(3) ────────────►  │
                                                                          │
Mission Scripting receives                                                │
  section_entered(id,                                                     │
  LOAD_FROM_SAVE) — branches ◄───────────────────────────────────────────┘
  to "resume from save" path
  (NO autosave on this path;
  NO objective re-fire)
```

#### 4.4.3 Settings persistence (separate path per ADR-0003)

- Settings live in `user://settings.cfg` (`ConfigFile`), NEVER in `SaveGame`. Prevents settings loss on new-game.
- Settings & Accessibility is the sole writer.
- Readers (Input for rebindings, PostProcessStack for resolution_scale, Audio for volumes, Localization for locale) read via `setting_changed` signal subscriptions — they do NOT poll.

### 4.5 Respawn cycle (Pillar 3 — "Stealth is Theatre, Not Punishment")

Two entry paths: **lethal damage** (player_died) and **F9 quickload** (menu-initiated). Both resolve through the same LSS sequence; queued-respawn semantics handle in-flight transitions.

```
Player Character       Combat             Failure & Respawn       LevelStreamingService      Events
────────────────       ──────             ─────────────────       ─────────────────────      ──────

[guard fires lethal
 hit]                  Combat.apply_damage
                       _to_actor(player,  ─► player.apply_damage
                       amount, guard,        (amount, guard,
                       BULLET)               BULLET)
                                             │
                                             health drops ≤ 0
                                             state → DEAD
                                             │
                                             Events.player_died
                                             .emit(SHOT) ────────────────────────────────►   │
                                                                                              │
                                             [subscribers: HUD, Audio stinger,                │
                                              Failure & Respawn]                              │
                                                                                              │
                                             Failure & Respawn receives ◄────────────────────┘
                                             │
                                             Calls LSS.reload_current_
                                             section(RESPAWN) ───────►  │
                                                                        │
                                                        [LSS branch: if in-flight,
                                                         QUEUE respawn and fire at
                                                         step 13 — CR-6; if IDLE,
                                                         begin 13-step now]
                                                        │
                                                        [13-step sequence]
                                                        step 1: push InputContext.LOADING
                                                        step 2: snap-out (2 frames hard cut)
                                                        step 3–8: queue_free old section,
                                                                  load packed scene, instantiate
                                                        step 9: invoke restore callbacks
                                                                (if LOAD_FROM_SAVE) or
                                                                default-spawn (if RESPAWN)
                                                        step 11: emit section_entered(
                                                                 id, RESPAWN) ────────────► │
                                                        step 12: pop InputContext.LOADING  │
                                                        step 13: drain respawn queue;      │
                                                                 emit respawn_triggered    │
                                                                 (id) ────────────────────► │
                                                                                            │
                                             Per-dart handlers receive                      │
                                             respawn_triggered ◄──────────────────────────┘
                                             (self-subscribed from Combat per TR-CD-016):
                                               dart.queue_free()
                                             GuardFireController resets to IDLE
```

**Key invariants**:
- `player_died` is the single trigger. Falling out of bounds (`FALL_OUT_OF_BOUNDS` damage_type) also routes through `apply_damage` → `player_died(ENVIRONMENTAL)`.
- `section_entered(id, RESPAWN)` and `respawn_triggered(id)` are SEPARATE signals. Mission Scripting gates autosave on FORWARD only (RESPAWN must NOT autosave — would overwrite the good state with the dead state). Subscribers that reset transient per-dart / per-timer state subscribe to `respawn_triggered`, not `section_entered`.
- The queued-respawn guarantee (LS CR-6) is a Pillar 3 enforcement mechanism — a respawn requested while a transition is in-flight is never dropped silently; it fires at step 13 from IDLE.

### 4.6 Document-open coordination (multi-system lifecycle)

Classic cross-layer coordination: player interaction triggers a UI modal that dims the world via PostProcessStack, pushes an InputContext, and triggers an Audio music-state transition. Demonstrates why Events bus + InputContext stack + PostProcessStack lifecycle API work together.

```
Player Character      Document Collection   Document Overlay UI   PostProcessStack   InputContext   Audio     Events
────────────────      ───────────────────   ───────────────────   ────────────────   ────────────   ─────     ──────

[Player presses Interact
 while raycast priority-0
 hit is a Document node]
  │
  interact_target.pickup()
  │ (on Document node)
  Events.player_interacted
  .emit(document_node) ──────────────────────────────────────────────────────────────────────────────────► │
                                                                                                            │
                        Document Collection                                                                 │
                        receives player_interacted ◄──────────────────────────────────────────────────────┘
                        │
                        document_node.document_id
                        registered in collected set
                        │
                        Events.document_collected
                        .emit(document_id) ────────────────────────────────────────────────────────────── ► │
                                                                                                            │
                        Events.document_opened                                                              │
                        .emit(document_id) ────────────────────────────────────────────────────────────── ► │
                                                                                                            │
                        [subscribers fan out to multiple systems]                                           │
                                                                                                            │
                                              Document Overlay UI                                          │
                                              receives document_opened ◄──────────────────────────────────┘
                                              │
                                              InputContext.push(
                                              DOCUMENT_OVERLAY) ──────────────────────► │
                                                                                         │
                                              PostProcessStack.                          │
                                              enable_sepia_dim() ──► │                  │
                                                                     │                  │
                                                          [0.5 s ease-in tween          │
                                                           of sepia parameters]         │
                                                                                        │
                                              [render document content                  │
                                               via tr() resolution]                     │
                                                                                        │
                                              Audio receives         ◄──────────────────┘
                                              document_opened:
                                              music state transitions
                                              to DOCUMENT_OVERLAY
                                              (2.0 s crossfade)

[Player presses ui_cancel
 OR Interact again]
  │
  DocumentOverlay _unhandled_input
  detects ui_cancel
  │
  DocumentOverlay.close()
  │
  Events.document_closed
  .emit(document_id) ────────────────────────────────────────────────────────────────────────────────────► │
                                                                                                            │
                                              Document Overlay UI                                          │
                                              │                                                            │
                                              InputContext.pop() ────────────────────►  │                  │
                                                                                         │ returns to      │
                                                                                         │ GAMEPLAY        │
                                              PostProcessStack.                          │                 │
                                              disable_sepia_dim() ─► │                  │                  │
                                                                     │                  │                  │
                                                          [0.5 s ease-out tween]        │                  │
                                                                                        │                  │
                                              Audio receives         ◄──────────────────────────────────────┘
                                              document_closed:
                                              music state returns
                                              to [location]_UNAWARE
                                              (2.0 s crossfade)
```

**Coordination rules on display**:
- Document Overlay is the owner of the user flow; it **does not** directly write state to PostProcessStack — it calls the clean lifecycle API (`enable_sepia_dim` / `disable_sepia_dim`). This keeps the sepia parameters owned by PostProcessStack (TR-PP-003), not leaked across module boundaries.
- InputContext push/pop is paired and stack-structured. When the overlay is dismissed, the previous context (typically GAMEPLAY) is restored automatically — no system has to remember "what was active before the document opened."
- Audio reacts to the same signals (`document_opened` / `document_closed`) but is not part of the lifecycle chain. Audio is subscriber-only per TR-AUD-001; adding a new subscriber to these signals requires no coordination with Document Overlay.
- Subtitles (Dialogue system, VS scope) observe `InputContext.DOCUMENT_OVERLAY` and suppress rendering while active (per Audio GDD).

### 4.7 Takedown sequence (direct-call accessor carve-out demonstration)

The only place in the architecture where two systems coordinate **without** going through the Events bus first. Demonstrates the ADR-0002 Accessor Conventions carve-out in action.

```
Player Character         Combat                          Stealth AI (specific guard)     Events
────────────────         ──────                          ───────────────────────────     ──────

[Player approaches guard
 from behind with blade
 equipped]
  │
  [Per-frame Combat tick in _process]
  │
  Combat checks for takedown
  eligibility. For each guard in
  proximity:
  │
  guard.takedown_prompt_active(self)   ─► [direct method call,
                                          not via bus]
                                          │
                                          Predicate on SAI:
                                          - alert_state ∈ {UNAWARE, SUSPICIOUS}
                                          - dot(facing, attacker_dir) ≤ 0
                                            (rear 180° half-cone)
                                          - distance ≤ TAKEDOWN_RANGE_M (1.5 m)
                                          - NOT has_los_to_player()
                                          - is_instance_valid(attacker)
                                          │
                                          Returns bool (read-only;
                                          no side effects)
  bool prompt_active ◄─────────────────── │
  │
  if prompt_active:
    Combat shows takedown UX cue
    (Combat CR-3 forward-dep)
  │
  [Player presses Takedown input
   (F / JOY_BUTTON_Y) — distinct
   from Fire per TR-CD-007]
  │
  Combat.takedown.receive_takedown
  (STEALTH_BLADE, eve) ────────────► guard.receive_takedown(
                                       STEALTH_BLADE, eve)
                                     │
                                     [SAI internal state update]
                                     approach_vector captured
                                     at terminal-entry
                                     │
                                     Routes to damage delegation:
                                     Combat.apply_damage_to_actor(
                                       self, blade_takedown_damage=100,
                                       eve, MELEE_BLADE) ────────► [Combat damage hub]
                                                                   │
                                                                   is_lethal = true
                                                                   (MELEE_BLADE lethal)
                                                                   │
                                                                   guard.receive_damage(
                                                                     100, eve,
                                                                     MELEE_BLADE) ──► [SAI guard]
                                                                                      │
                                                                                      _health ≤ 0
                                                                                      current_alert_state
                                                                                      → DEAD (synchronous
                                                                                      mutation — no
                                                                                      call_deferred per
                                                                                      TR-SAI-014)
                                                                                      │
                                                                                      Returns is_dead = true
                                                                   ◄──────────────────┘
                                                                   │
                                                                   Events.enemy_damaged
                                                                   .emit(guard, 100, eve) ────────────────► │
                                                                                                            │
                                                                                                            │
                                                                   Events.enemy_killed                      │
                                                                   .emit(guard, eve) ─────────────────────► │
                                                                                                            │
                                                                 [Also emitted from SAI: takedown_          │
                                                                  performed(guard, eve, STEALTH_BLADE)      │
                                                                  + guard_incapacitated(guard) +            │
                                                                  alert_state_changed(guard, COMBAT, DEAD,  │
                                                                  MAJOR)] ─────────────────────────────────►│
                                                                                                            │
                                                                 Audio subscribes:                          │
                                                                 - takedown_performed with STEALTH_BLADE    │
                                                                   → blade-stroke SFX variant               │
                                                                 - alert_state_changed(_,_, DEAD, MAJOR)    │
                                                                   → dominant-guard recomputation           │
                                                                 - enemy_killed → stinger if MAJOR per      │
                                                                   Severity filter                          │
                                                                   ◄────────────────────────────────────────┘
```

**Why the direct-call carve-out exists**: The bus is fire-and-forget — emit returns to the caller immediately after all subscribers run, but there is no "return value" and no per-subscriber routing. Combat needs to know "is this specific guard eligible for takedown *right now*?" to decide whether to show the UX prompt. Emitting a `request_takedown_eligibility` signal through the bus and waiting for a `takedown_eligibility_response` would be the `synchronous_request_response_through_bus` forbidden pattern.

**Why it is safe**:
- Accessors are called on **specific node instances** the caller holds a reference to (e.g., from a proximity query or group lookup) — never on autoloads by name.
- Accessors are read-only (TR-SAI-012/013).
- Staleness is explicitly tolerated: SAI's F.1 cache is 10 Hz; at-most-1-physics-frame lag is documented and acceptable for the gating decision.
- Fence: no new accessors without an ADR-0002 amendment. Current list is 2 (both on StealthAI, both consumed by Combat).

### 4.8 Thread boundaries

Godot 4.6 gameplay runs on the **main thread**. No explicit thread crossings in this architecture:

- **NavigationServer3D path queries**: internal async path-computation is transparent. `NavigationAgent3D.get_next_path_position()` is main-thread; the result may reflect a path computed one frame ago. SAI tolerates this per TR-SAI-018 perf-budget declaration.
- **ResourceSaver / ResourceLoader**: synchronous. No async loading for sectional saves (save ≤10 ms, load I/O ≤2 ms per ADR-0008 non-frame budgets).
- **AudioServer**: runs on its own audio thread internally, but all project-authored audio code uses main-thread `AudioServer.*` APIs. Bus graph rebuild on reverb swap is a documented 0.3–0.8 ms main-thread stall absorbed by the 1.6 ms Reserve slot (ADR-0008 specialist observation, 2026-04-23).

No GDExtension, no manual threading, no `WorkerThreadPool` usage in MVP. Future ADR required if any system wants to cross a thread boundary.

---

## 5. API Boundaries

GDScript static-typed pseudocode per module, grouped by layer. Doc comments state **invariants callers must respect** and **guarantees the module makes**. For authored modules (PC, FC, SAI, Combat, Audio, Level Streaming, Signal Bus, Save/Load) contracts are exact. For not-yet-authored modules the forward-declared signatures will be refined by their `/design-system` passes.

### 5.1 Foundation Layer

#### Signal Bus (Events autoload)

```gdscript
# res://src/core/signal_bus/events.gd
# Autoload registered at line 1 per ADR-0007; class_name SignalBusEvents,
# autoload key Events.
#
# INVARIANT: This file contains ONLY typed signal declarations.
# No methods, no state, no node references (ADR-0002 forbidden patterns).
# GUARANTEE: Synchronous dispatch in connection-order on emit. Subscribers
# run to completion before next subscriber starts.

class_name SignalBusEvents extends Node

# 36 signals across 9 gameplay domains + Persistence + Settings. Verbatim
# declarations live in ADR-0002 §Key Interfaces and are not duplicated here
# to avoid drift. Summary count per domain:
#   AI/Stealth (6)  Combat (6)    Player (2)    Inventory (4)
#   Documents (3)   Mission (6)   Failure (1)   Civilian (2)
#   Dialogue (2)    Persistence (3)   Settings (1)
```

#### SaveLoad (autoload)

```gdscript
# res://src/core/save_load/save_load_service.gd
# Autoload registered at line 3 per ADR-0007; autoload key SaveLoad.
#
# INVARIANT (caller-assembly pattern, ADR-0003 forbidden pattern
# save_service_assembles_state): SaveLoadService writes/reads files only;
# does NOT query game systems to assemble SaveGame. Callers assemble.

class_name SaveLoadService extends Node

enum FailureReason { DISK_FULL, PERMISSION, CORRUPT_FILE,
                     VERSION_MISMATCH, SLOT_EMPTY, UNKNOWN }

## Serialize a caller-assembled SaveGame to the given slot.
## Atomic write: tmp file → DirAccess.rename → sidecar → screenshot.
## Emits game_saved(slot, section_id) on success; save_failed(reason) on fail.
## Blocked when InputContext.is_active(CUTSCENE) OR LOADING.
func save_to_slot(slot: int, save_game: SaveGame) -> void: ...

## Load a SaveGame from the given slot. Returns null on failure (emits
## save_failed(CORRUPT_FILE|SLOT_EMPTY|VERSION_MISMATCH)).
## GUARANTEE: Returned instance has been through duplicate_deep() per
## ADR-0003 — callers receive a fully-isolated copy.
func load_from_slot(slot: int) -> SaveGame: ...

## Read metadata sidecar only. Avoids full .res load for Menu dossier cards.
## Returns: { section_id: StringName, saved_at_iso8601: String,
##            elapsed_time: float, screenshot_path: String,
##            save_format_version: int }
func slot_metadata(slot: int) -> Dictionary: ...

func get_available_slots() -> Array[int]: ...
```

#### Level Streaming (autoload)

```gdscript
# res://src/core/level_streaming/level_streaming_service.gd
# Autoload registered at line 5 per ADR-0007; autoload key LevelStreamingService.
#
# INVARIANT: 13-step swap sequence is the ONLY way scenes change. Callers
# MUST NOT use change_scene_to_packed or manual queue_free + add_child of
# section roots — all transitions go through this service.

class_name LevelStreamingService extends Node

enum TransitionReason { FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE }

## Transition to another section. If already transitioning: FORWARD requests
## are dropped, RESPAWN queues and fires at step 13. TransitionReason
## propagates to section_entered/exited signals per LS CR-8 + ADR-0002.
func transition_to_section(section_id: StringName, reason: TransitionReason) -> void: ...

## Reload the current section. Called by Failure & Respawn with RESPAWN,
## or by Menu System on explicit restart with LOAD_FROM_SAVE.
func reload_current_section(reason: TransitionReason) -> void: ...

## Register a callback to run synchronously at step 9 of every transition.
## Callbacks run in registration order. Use for state restoration on load.
## GUARANTEE: Callbacks run BEFORE section_entered emission.
## INVARIANT: Callbacks MUST be non-async (no await). Debug pre/post
## timestamp assertion enforces the no-await contract in debug builds.
func register_restore_callback(callable: Callable) -> void: ...

## Cache eviction — MVP no-op (TR-LS-010 CACHE_MODE_REUSE default; no
## eviction policy until Tier 2 / Rome+Vatican scope adds this need).
func evict_section_from_cache(section_id: StringName) -> void: ...

## Test-only. Forces a registry failure to verify ErrorFallback UX.
## Gated by OS.is_debug_build() — no-op in release builds.
func _simulate_registry_failure() -> void: ...
```

#### Localization Scaffold (no autoload — convention only)

```gdscript
# Localization has NO public module API. It is a CONVENTION:
#
#   INVARIANT (TR-LOC-001 forbidden pattern hardcoded_visible_string):
#     every user-visible string MUST be wrapped in tr(key).
#   INVARIANT (TR-LOC-002): keys use domain.context.identifier segments.
#   INVARIANT (TR-LOC-007 forbidden pattern cached_translation_at_ready):
#     subscribers MUST re-resolve strings on NOTIFICATION_TRANSLATION_CHANGED,
#     never cache the resolved string at _ready().
#
#   GUARANTEE: Control.auto_translate_mode = AUTO_TRANSLATE_MODE_ALWAYS
#     on relevant Control nodes → Godot auto-re-resolves on locale change.

# Example caller site:
label.text = tr("hud.health.label")                    # "Health" / "Santé"
label.text = tr("hud.ammo.count").format({"count": n}) # plural-aware (Godot 4.6 CSV)
```

### 5.2 Core Layer

#### Input (InputContext autoload + InputActions static class)

```gdscript
# res://src/core/input/input_context.gd
# Autoload registered at line 4 per ADR-0007; autoload key InputContext.
#
# INVARIANT (ADR-0004 IG2 addendum 2026-04-23): call sites MUST use
# autoload key `InputContext.*`; MUST NOT use `InputContextStack.*`
# (class_name) for discoverability.

class_name InputContextStack extends Node

enum Context { GAMEPLAY, MENU, DOCUMENT_OVERLAY, PAUSE, CUTSCENE, LOADING }

## Push a context onto the stack. Previous context remains on the stack.
func push(context: Context) -> void: ...

## Pop the current context. Restores the previous one. Idempotent-safe on
## empty stack (logs warning in debug; no-op in release).
func pop() -> void: ...

## Is the given context the current (top-of-stack) context?
## GUARANTEE: Checking this is cheap (single comparison).
func is_active(context: Context) -> bool: ...

# ─────────────────────────────────────────────────────────────────────
# res://src/core/input/input_actions.gd — static class, not autoload.
# All cross-system input reads route through these StringName constants.
# Raw KEY_* constants are a forbidden pattern in gameplay code (TR-INP-001).

class_name InputActions extends RefCounted

# Movement
const MOVE_FORWARD  := &"move_forward"
const MOVE_BACK     := &"move_back"
const MOVE_LEFT     := &"move_left"
const MOVE_RIGHT    := &"move_right"
const JUMP          := &"jump"
const CROUCH        := &"crouch"
const SPRINT        := &"sprint"

# Interaction
const INTERACT      := &"interact"      # E / A-Cross
const UI_CANCEL     := &"ui_cancel"     # Esc / B-Circle — modal dismiss
const PAUSE         := &"pause"         # Esc / Start

# Combat
const FIRE          := &"fire"
const AIM           := &"aim"
const TAKEDOWN      := &"takedown"      # F / Y — distinct from FIRE per TR-CD-007
const SWITCH_WEAPON := &"switch_weapon"
const USE_GADGET    := &"use_gadget"    # shared binding with TAKEDOWN;
                                        # mutex on SAI.takedown_prompt_active()
# ... (30 total, see design/gdd/input.md catalog)
```

#### Player Character (scene root — not autoload)

```gdscript
# res://src/gameplay/player/player_character.gd

class_name PlayerCharacter extends CharacterBody3D

## Eve's health is integer 0–100. apply_damage is the ONLY mutator.
## INVARIANT: Callers MUST NOT mutate _health directly.
## GUARANTEE: Synchronous mutation; emits player_damaged then player_died
## iff reached 0 this call. No call_deferred.
## Rounding: round-half-away-from-zero per TR-PC-011; sub-0.5 guarded out.
func apply_damage(amount: float, source: Node,
                  damage_type: CombatSystemNode.DamageType) -> void: ...

## Returns current noise radius in meters. Read by FootstepComponent for
## footstep signal payloads and by Stealth AI for sound-fill input.
## GUARANTEE: Cheap (returns cached value; no computation).
func get_noise_level() -> float: ...

## Returns the current NoiseEvent. Reused RefCounted instance with in-place
## field mutation (zero-allocation at 80 Hz aggregate polling per TR-PC-013).
## INVARIANT: Callers MUST NOT retain the reference across frames. Treat as
## a read-once view.
func get_noise_event() -> NoiseEvent: ...

## Returns current silhouette height: 1.7 m standing / 1.1 m crouched /
## 0.4 m dead; interpolated during 120 ms crouch transition.
func get_silhouette_height() -> float: ...

## Respawn hook. Clears _latched_event → IDLE → _is_hand_busy BEFORE
## Tween.kill() → health = max_health → teleport → single emit of
## player_health_changed (TR-PC-020 ordered sequence).
func reset_for_respawn(checkpoint: Marker3D) -> void: ...
```

#### FootstepComponent (child of PlayerCharacter)

```gdscript
# res://src/gameplay/player/footstep_component.gd

class_name FootstepComponent extends Node

# No public API. Subscriber-only — parent's _physics_process tick drives it.
# Emits Events.player_footstep(surface, noise_radius_m) per step.
#
# INVARIANT (TR-FC-005 forbidden pattern): Stealth AI MUST NOT subscribe
# to Events.player_footstep. That signal is the Audio channel only.
# SAI perception reads PC.get_noise_event() directly.
```

### 5.3 Feature Layer

#### Stealth AI (guard instances — NOT autoload)

```gdscript
# res://src/gameplay/stealth_ai/stealth_ai.gd

class_name StealthAI extends Node

enum AlertState { UNAWARE, SUSPICIOUS, SEARCHING, COMBAT,
                  UNCONSCIOUS, DEAD }
enum AlertCause { SAW_PLAYER, SAW_BODY, HEARD, ALERTED_BY_OTHER, SCRIPTED }
enum Severity   { MINOR, MAJOR }
enum TakedownType { MELEE_NONLETHAL, STEALTH_BLADE }

## Read accessor — Combat's GuardFireController polls this at fire-state
## transitions. Cache-hit path; no new raycast per call. 10 Hz cache
## cadence; ≤1 physics-frame lag.
## INVARIANT (ADR-0002 Accessor Conventions): read-only, no side effects.
## GUARANTEE: Safe to call even before F.1 has ticked — returns false
## (cold-start safe).
func has_los_to_player() -> bool: ...

## Read accessor — Combat's takedown-input gate polls this each frame
## while blade is equipped. Returns true iff:
##   - alert_state ∈ {UNAWARE, SUSPICIOUS}
##   - dot(guard_facing, attacker_direction) ≤ 0 (rear 180° half-cone)
##   - distance ≤ TAKEDOWN_RANGE_M (1.5 m)
##   - NOT has_los_to_player()
##   - is_instance_valid(attacker)
## INVARIANT: read-only; no side effects. Returns false defensively on
## any input validity failure (zero-distance, destroyed attacker, etc.).
func takedown_prompt_active(attacker: Node) -> bool: ...

## Damage receiver. Returns is_dead so Combat can emit enemy_killed
## deterministically.
## GUARANTEE: Synchronous mutation of _health + current_alert_state BEFORE
## return. NO call_deferred (TR-SAI-014, enforced by AC-SAI-1.11 spy-proxy
## test). Combat.is_lethal_damage_type() routes lethal → DEAD,
## non-lethal → UNCONSCIOUS.
func receive_damage(amount: float, source: Node,
                    damage_type: CombatSystemNode.DamageType) -> bool: ...

## Takedown receiver. Called by Combat after takedown input detected +
## takedown_prompt_active() gate passed.
## Internally delegates to Combat.apply_damage_to_actor(self,
## blade_takedown_damage=100, attacker, MELEE_BLADE) for blade, or records
## UNCONSCIOUS transition for MELEE_NONLETHAL (chloroform).
## Captures approach_vector at terminal entry for body-drop animation.
func receive_takedown(takedown_type: TakedownType, attacker: Node) -> void: ...
```

#### Combat (autoload — class_name CombatSystemNode, autoload key Combat)

```gdscript
# res://src/gameplay/combat/combat_system.gd
# class_name CombatSystemNode, autoload key Combat — intentional split per
# combat-damage.md §350, mirroring SignalBusEvents/Events pattern.
# (Autoload inclusion in ADR-0007's 6-autoload registry flagged as an
# audit item in §7 ADR Audit of this document.)

class_name CombatSystemNode extends Node

enum DamageType { BULLET, DART_TRANQUILISER, MELEE_FIST, MELEE_BLADE,
                  FALL_OUT_OF_BOUNDS, TEST }
enum DeathCause { SHOT, TRANQUILISED, MELEE, ENVIRONMENTAL, UNKNOWN }

## Damage routing hub. Duck-types on receiver:
##   if actor.has_method("apply_damage"): PC path (synchronous mutation,
##     PC emits player_damaged or player_died).
##   elif actor.has_method("receive_damage"): guard path (Combat emits
##     enemy_damaged, then enemy_killed iff receive_damage returned true —
##     deterministic order per TR-CD-002).
## INVARIANT: Combat owns the emit-site for enemy_* signals. Guards MUST
## NOT emit enemy_damaged/enemy_killed themselves.
func apply_damage_to_actor(actor: Node, amount: float, source: Node,
                            damage_type: DamageType) -> void: ...

## Classification helper consumed by SAI for UNCONSCIOUS vs DEAD routing.
## GUARANTEE: Pure function; depends only on damage_type.
func is_lethal_damage_type(damage_type: DamageType) -> bool: ...

## Map damage type to death cause (for player_died payload).
func damage_type_to_death_cause(damage_type: DamageType) -> DeathCause: ...
```

#### Feature modules not yet authored (forward-declared)

```gdscript
# Inventory & Gadgets (scope: Inventory component on PC, not autoload)
class_name InventorySystem extends Node
func switch_weapon(weapon_id: StringName) -> void: ...
func use_gadget() -> void: ...                        # mutex on SAI.takedown_prompt_active
func get_ammo(weapon_id: StringName) -> int: ...
func get_reserve(weapon_id: StringName) -> int: ...
# Emits: gadget_equipped, gadget_used, weapon_switched, ammo_changed

# Mission & Level Scripting (scope: per-mission scripts + scripted triggers)
# Per-mission script extends Node; subscribes to section_entered(FORWARD) for
# autosave; emits objective_started/completed.

# Failure & Respawn (scope: autoload OR Mission-owned, TBD by its GDD)
func trigger_respawn() -> void: ...  # calls LSS.reload_current_section(RESPAWN)

# Civilian AI (MVP stub: flee + panic; VS full: witness-reporting)
# Emits civilian_panicked, civilian_witnessed_event

# Document Collection (scope: document registry + per-document Resources)
func register_interaction(target: Node) -> void: ...  # subscriber to player_interacted
# Emits document_collected, document_opened, document_closed

# Dialogue & Subtitles (scope: dialogue system + subtitle renderer)
func play_line(speaker_id: StringName, line_id: StringName) -> void: ...
# Emits dialogue_line_started, dialogue_line_finished
```

### 5.4 Presentation Layer

#### Audio (AudioManager — persistent root Node, NOT autoload)

```gdscript
# res://src/presentation/audio/audio_manager.gd
# Lives as Node in persistent root scene per TR-AUD-003 (intentional; not
# an autoload). Subscriber-only per TR-AUD-001.

class_name AudioManager extends Node

# NO public API for gameplay callers. Audio reacts to 30 signals.
# Inspector helpers only (debug + profiling per Audio GDD approval notes):
func get_active_voices() -> int: ...
func get_last_stolen_slot_id() -> int: ...

# INVARIANT (TR-AUD-001): AudioManager publishes NO cross-system signals.
# If a gameplay system wants something played, it emits the domain signal
# (e.g., weapon_fired, takedown_performed, alert_state_changed) and Audio
# reacts.
```

#### Outline Pipeline (OutlineTier static helper)

```gdscript
# res://src/presentation/outline/outline_tier.gd — static helper.
# Every renderable MeshInstance3D in the project calls set_tier at spawn.

class_name OutlineTier extends RefCounted

const NONE     : int = 0   # default cleared stencil — no outline
const HEAVIEST : int = 1   # 4 px at 1080p — Eve, key interactives
const MEDIUM   : int = 2   # 2.5 px — PHANTOM guards
const LIGHT    : int = 3   # 1.5 px — environment, civilians

## Assigns the outline tier to a mesh. Implementation depends on ADR-0001
## verification gate 1 result (BaseMaterial3D stencil property OR custom
## ShaderMaterial path).
## INVARIANT (ADR-0001 IG1): every system that spawns visible meshes MUST
## call set_tier — no engine default. Unmarked meshes render as NONE.
## EXCEPTION (ADR-0005): FPS hands mesh is the single documented exception
## — uses inverted-hull material_overlay, not stencil.
static func set_tier(mesh: MeshInstance3D, tier: int) -> void: ...
```

#### Post-Process Stack (autoload — autoload key PostProcessStack per ADR-0007)

```gdscript
# res://src/presentation/post_process/post_process_stack.gd
# Autoload registered at line 6 per ADR-0007; autoload key PostProcessStack.
# class_name is ADR-0004/GDD scope (not re-decided here).
#
# INVARIANT (TR-PP-001): Chain order locked: Outline → Sepia Dim →
# Resolution Scale Composition. Not reorderable at runtime.

# (Skeleton omitted — class_name set by the Post-Process Stack GDD.)

## Enable sepia dim — called by Document Overlay on document_opened.
## GUARANTEE: 0.5 s ease-in tween of sepia parameters (30% luminance,
## 25% saturation, warm-amber tint). Idempotent if already enabled.
func enable_sepia_dim() -> void: ...

## Disable sepia dim — called by Document Overlay on document_closed.
## GUARANTEE: 0.5 s ease-out tween. Idempotent if already disabled.
func disable_sepia_dim() -> void: ...

# INVARIANT (TR-PP-010): Only Settings & Accessibility writes resolution_scale.
# PostProcessStack reads it via setting_changed signal subscription.
```

#### UI surfaces (forward-declared — HUD Core is MVP; the rest are VS)

```gdscript
# HUD Core (MVP) — subscriber-only; no public API.
# Subscribes: player_health_changed, ammo_changed, weapon_switched,
#   gadget_equipped, player_interacted.
# INVARIANT (ADR-0004): HUD refreshes ONLY on signal emission — no polling.

# Document Overlay UI (VS)
class_name DocumentOverlay extends Control
func open(document_id: StringName) -> void: ...   # InputContext.push + sepia_dim
func close() -> void: ...                          # InputContext.pop + disable_sepia_dim

# Menu System (VS) — triggered via InputActions.PAUSE.
#   Reads SaveLoad.slot_metadata / load_from_slot.
#   Manages InputContext.MENU / PAUSE push/pop.

# Cutscenes & Mission Cards (VS)
class_name Cutscenes extends Node
func play(cutscene_id: StringName) -> void: ...   # InputContext.push(CUTSCENE)

# Settings & Accessibility (VS) — sole writer of user://settings.cfg.
# Emits setting_changed(category, name, value: Variant). Readers subscribe.
func get_resolution_scale() -> float: ...
func get_crosshair_mode() -> int: ...
func get_photosensitivity_rate_gate_enabled() -> bool: ...
# ... (additional getters per setting; full catalog set by Settings & Accessibility GDD)
```

### 5.5 Project-wide Static Helpers

Two static helpers are not layer-bound — they are consumed by every layer as named-constant registries. Both are defined by foundational ADRs (no autoload cost).

#### PhysicsLayers (ADR-0006)

```gdscript
# res://src/core/physics_layers.gd — static class, not autoload.
# Single source of truth for all collision-layer + collision-mask values.
# project.godot named-layer slots 1–5 mirror these names.
#
# INVARIANT (ADR-0006 forbidden pattern): hardcoded integer layer indices
# in gameplay code are banned. Use PhysicsLayers.* always.
# INVARIANT: bidirectional consistency — renaming a layer requires editing
# both this file AND project.godot's layer_names/3d_physics/layer_N entry.

class_name PhysicsLayers extends RefCounted

# Layer INDICES (1-based; pass to set_collision_layer_value / set_collision_mask_value)
const LAYER_WORLD         : int = 1
const LAYER_PLAYER        : int = 2
const LAYER_AI            : int = 3
const LAYER_INTERACTABLES : int = 4
const LAYER_PROJECTILES   : int = 5

# Bitmask constants (pass to collision_layer / collision_mask properties)
const MASK_WORLD         : int = 1 << 0  # 1
const MASK_PLAYER        : int = 1 << 1  # 2
const MASK_AI            : int = 1 << 2  # 4
const MASK_INTERACTABLES : int = 1 << 3  # 8
const MASK_PROJECTILES   : int = 1 << 4  # 16

# Precomputed composite masks (named by semantic intent, not bit composition)
const MASK_AI_VISION_OCCLUDERS  : int = MASK_WORLD | MASK_PLAYER
const MASK_INTERACT_RAYCAST     : int = MASK_INTERACTABLES | MASK_WORLD
const MASK_FOOTSTEP_SURFACE     : int = MASK_WORLD
# ... (additional composites as consumers require; all new composites added here)
```

#### FontRegistry (ADR-0004)

```gdscript
# res://src/presentation/ui/font_registry.gd — static class, not autoload.
# Typed font getters with Futura → DIN size-floor substitution per Art
# Bible 7B/8C. UI surfaces call into this rather than loading FontFile
# resources directly.
#
# INVARIANT (ADR-0004): at render time below the 18 px floor, Futura is
# replaced by DIN 1451 Engschrift. FontRegistry handles this transparently.

class_name FontRegistry extends RefCounted

enum Face { FUTURA_CONDENSED_BOLD,       # HUD numerals
            FUTURA_EXTRA_BOLD_CONDENSED, # Menu headers
            AMERICAN_TYPEWRITER,         # Document body
            DIN_1451_ENGSCHRIFT }        # Auto-substitution for small Futura

## Returns the appropriate FontFile for the given face and pixel size.
## GUARANTEE: Futura at size < 18 px automatically substitutes DIN 1451.
static func get_font(face: Face, size_px: int) -> FontFile: ...

## Returns the font variation (weight / stretch) resource for the given face.
static func get_font_variation(face: Face, weight: int = 700) -> FontVariation: ...
```

### 5.6 Cross-cutting Invariants (summary)

These are binding on every caller across all layers — enforced by code review + forbidden patterns in `docs/registry/architecture.yaml`:

1. **Subscriber lifecycle** (ADR-0002 IG3): connect in `_ready()`, disconnect with `is_connected` guard in `_exit_tree()`. Non-negotiable.
2. **Node payload validity** (ADR-0002 IG4): call `is_instance_valid(node)` before dereferencing any Node-typed signal payload.
3. **Input context gating** (TR-INP-004): every `_unhandled_input` checks `InputContext.is_active(GAMEPLAY)` before consuming. After consume: `get_viewport().set_input_as_handled()`.
4. **Tier assignment** (ADR-0001 IG1): every gameplay system that spawns visible meshes calls `OutlineTier.set_tier(mesh, tier)` at spawn. No engine default. Hands are the single ADR-0005 exception.
5. **Collision layers** (ADR-0006): every `collision_layer` / `collision_mask` assignment references `PhysicsLayers.*` constants. Hardcoded integers forbidden.
6. **tr() wrap** (TR-LOC-001): every user-visible string wrapped in `tr(key)` with a three-segment key.
7. **Signal emission ownership** (TR-CD-002): Combat owns emit-site for `enemy_damaged`/`enemy_killed`. Guards MUST NOT self-emit these.
8. **Accessor fence** (ADR-0002 Accessor Conventions): no new cross-system read accessors without an ADR-0002 amendment. Current list: 2 (SAI.has_los_to_player, SAI.takedown_prompt_active).
9. **duplicate_deep on load** (ADR-0003): every loaded `SaveGame` passed through `duplicate_deep()` before any system receives sub-resources.
10. **Autoload cross-reference** (ADR-0007): no autoload calls another autoload from `_init()` — only from `_ready()` or later.
11. **No unbudgeted per-frame ticking** (ADR-0008 forbidden pattern): any new `_process` / `_physics_process` hot path MUST cite its ADR-0008 slot and be measured against the Restaurant reference scene.
12. **Single directional-shadow cascade** (ADR-0008 forbidden pattern `directional_shadow_second_cascade`): adding a second cascade busts the 3.8 ms Rendering slot.

---

## 6. ADR Audit

The heavy lifting of traceability is already done by `docs/architecture/requirements-traceability.md` (third-run 2026-04-23 snapshot: **PASS**, ~99% coverage, 0 hard ADR-level gaps). This audit does three things: (1) tabulates the per-ADR quality dimensions the skill requires, (2) references the existing traceability matrix without duplicating it, (3) records one cross-session conflict surfaced during Phase 4 API-Boundaries authoring and its recommended resolution.

### 6.1 Per-ADR Quality Check

| ADR | Title | Engine-Compat section | Version recorded | Post-cutoff APIs flagged | GDD Reqs section | Conflicts vs §§2–5 | Valid for 4.6 |
|---|---|---|---|---|---|---|---|
| 0001 | Stencil ID Contract | ✅ | 4.6 | ✅ stencil 4.5, CompositorEffect 4.3+, RDPipelineDepthStencilState 4.5 (graphics-pipeline stencil-test pattern per F5), Shader Baker 4.5; ~~D3D12 4.6~~ removed by Amendment A2 (Vulkan-only) | ✅ | None | ✅ |
| 0002 | Signal Bus + Event Taxonomy | ✅ | 4.6 | ✅ script backtracing 4.5 (debug-only) | ✅ | None | ✅ |
| 0003 | Save Format Contract | ✅ | 4.6 | ✅ duplicate_deep 4.5 (load-bearing), FileAccess 4.4 (informational) | ✅ | None | ✅ |
| 0004 | UI Framework | ✅ | 4.6 | ✅ AccessKit 4.5, dual-focus 4.6, FoldableContainer 4.5 | ✅ | None | ✅ |
| 0005 | FPS Hands Outline (inverted-hull) | ✅ | 4.6 | ✅ (none load-bearing; Shader Baker 4.5 for compile) | ✅ | None | ✅ |
| 0006 | Collision Layer Contract | ✅ | 4.6 | ✅ Jolt 4.6 default + A6 Area3D broadphase tunneling | ✅ | None | ✅ |
| 0007 | Autoload Load Order Registry | ✅ | 4.6 | ✅ (autoload syntax stable 4.0+) | ✅ | ⚠ **Combat-autoload omission** (§6.3 below) | ✅ |
| 0008 | Performance Budget Distribution | ✅ | 4.6 | ✅ Jolt 4.6, Shader Baker 4.5, CompositorEffect 4.6; ~~D3D12 4.6~~ removed by Amendment A2 (Vulkan-only) | ✅ | None | ✅ |

All 8 ADRs satisfy the skill's quality checkboxes. All 8 remain Proposed; 21 verification gates outstanding across the chain. Four A3–A6 amendments and ADR-0008's Gate 1–4 are captured on the ADRs themselves and tracked in `production/session-state/active.md`.

### 6.2 Traceability Coverage Check

Deferred to `docs/architecture/requirements-traceability.md` (third-run 2026-04-23 snapshot). The authoritative matrix is not duplicated here to avoid drift.

Current state:

| Metric | Count | % |
|---|---:|---:|
| Total TRs registered (`tr-registry.yaml` v2) | 158 | 100% |
| ✅ Covered by ≥1 ADR | ~154 | ~99% |
| ⚠ Partial (intentional GDD-scope: Audio internals, Post-Process internals, Input GDD catalog detail) | ~3 | ~1% |
| ❌ Hard ADR-level gap | **0** | — |

**Producer-tracked GDD-coordination items** (design-level, not ADR-level; do not block architecture progression):

1. `design/gdd/player-character.md` still references `CombatSystem.DamageType` / `CombatSystem.DeathCause` at ~10 sites — needs rename pass to `CombatSystemNode.*`.
2. `design/gdd/audio.md` L188–189 §Mission handler table still 1-param — needs `reason: TransitionReason` 2nd param + 4-way branching per LS GDD CR-8 (LS-Gate-3).
3. `design/gdd/input.md` L90 `use_gadget` → dedicated `takedown` action split per Combat CR-3 (partially applied per session state 2026-04-23 action count 29→30; verify catalog-header edit landed).

Per the `/architecture-review 2026-04-23` third-run verdict: **PASS**. This document inherits that verdict.

### 6.3 Cross-Session Conflict: Combat Autoload Omission in ADR-0007

Surfaced during Phase 4 API Boundaries authoring (this session). Not previously flagged by any of the three 2026-04-23 architecture-review runs.

**Sources in tension:**

- **ADR-0002 Revision History (2026-04-22 OQ-CD-1 bundle)** + **`design/gdd/combat-damage.md` TR-CD-022**: declare `class_name CombatSystemNode` / autoload key `Combat`, "intentional split mirroring `SignalBusEvents`/`Events`".
- **ADR-0007 Summary (2026-04-23)**: "The Paris Affair registers **6 autoloads** in a single canonical order" — Events, EventLogger, SaveLoad, InputContext, LevelStreamingService, PostProcessStack. **Combat is not in the list.**

**Timeline**: ADR-0007 was authored 2026-04-23, **after** the ADR-0002 amendment (2026-04-22) introduced Combat as an autoload. So ADR-0007's exclusion is a scope decision, not a time-ordering oversight.

**Impact**:
- If Combat is registered as an autoload in `project.godot`, the canonical registry has 7 entries, not 6. Line position for Combat is undefined.
- Per ADR-0007's `unregistered_autoload` forbidden pattern, any PR that adds Combat to `project.godot` without an ADR-0007 amendment is a code-review violation.
- In practice Combat has no `_init()` cross-reference hazard (TR-CD-016's `respawn_triggered` subscription is on per-dart / per-fire-controller instances in scene-node `_ready()`, not on CombatSystemNode itself), so the technical risk is low; the issue is editorial correctness.

**Resolution (recorded via godot-specialist consultation, 2026-04-23)**: **Path A — amend ADR-0007 to register Combat as autoload line 7** (after PostProcessStack).

Specialist rationale (summarised):

> Combat's method-call surface — `Combat.apply_damage_to_actor()`, `Combat.is_lethal_damage_type()`, `Combat.damage_type_to_death_cause()` — is invoked from SAI guard nodes, the Player controller, and projectile nodes across every section scene. That fan-out pattern is exactly the case Godot's autoload system exists for: a stateless-ish service reachable from arbitrary scene-tree positions without a known common ancestor.
>
> A scene-tree singleton (Path B) would require fragile group lookups or hardcoded `get_node()` paths — an anti-pattern ADR-0007 implicitly forbids for the same reasons it fences `unregistered_autoload`.
>
> On load order: Combat's `_ready()` does not cross-reference other autoloads' `_init()`. TR-CD-016's subscriptions happen on per-dart / per-fire-controller instances inside scene nodes, which always run after the full autoload chain has initialised. Placing Combat at position 7 after PostProcessStack is safe.
>
> Path C (defer) leaves TR-CD-022 and ADR-0002 in a false conflict state — editorial debt with no payoff.

**Required follow-up** (tracked in §7 Required ADRs):
- `/architecture-decision adr-0007-amendment` — add Combat at canonical line 7; update "6 autoloads" → "7 autoloads" throughout ADR-0007 + downstream ADR/GDD references; note TR-CD-022 is the authoritative rationale for the `CombatSystemNode` / `Combat` class_name split. **✅ LANDED 2026-04-23** (in-place amendment to ADR-0007 + 1 registry row; no downstream "load order N" edits required — ADR-0002 and combat-damage.md already correctly assert the Combat autoload claim).

**Not blocking this architecture document.** Phase 4 §5.3 API Boundaries treats Combat as "autoload per GDD / ADR-0002" consistently — a forthcoming ADR-0007 amendment aligns the registry, no code changes required.

### 6.4 Per-ADR Validity Spot-Checks vs Phases 1–4

Brief notes verifying that phases 1–4 authoring did not reveal drift from any ADR's stated contract:

- **ADR-0001**: Phase 4 §5.4 OutlineTier pseudocode (tier values, escape-hatch API, color uniform) matches ADR-0001 §Key Interfaces exactly. No drift.
- **ADR-0002**: Phase 3 §4.3 event-path diagram + Phase 4 `SignalBusEvents` pseudocode match ADR-0002's 36-signal taxonomy + Accessor Conventions subsection. No drift.
- **ADR-0003**: Phase 3 §4.4 save/load flows honor caller-assembly pattern + `duplicate_deep` mandatory + sidecar metadata separation. Phase 4 `SaveLoadService` API matches ADR-0003 §Decision. No drift.
- **ADR-0004**: InputContext.LOADING value referenced by Phase 3/4 exists in ADR-0004's Context enum. Input GDD touch-up to add LOADING to its catalog remains producer-tracked (flagged in §6.2).
- **ADR-0005**: Inverted-hull carve-out applies only to PC hands. Phase 2 PC ownership row + Phase 4 OutlineTier doc comment (`EXCEPTION (ADR-0005)`) capture it correctly.
- **ADR-0006**: Phase 4 §5.5 PhysicsLayers pseudocode matches ADR-0006's 5-layer schema + precomputed composites. No drift.
- **ADR-0007**: Combat omission recorded in §6.3 above; ✅ RESOLVED 2026-04-23 via in-place amendment (canonical table now 7 entries; Combat at line 7). Otherwise the canonical table matches Phase 2 Foundation-layer module ownership + Phase 3 §4.1 initialization order.
- **ADR-0008**: Phase 3 §4.2 frame update path cites the 9 slots in order. Sum verifies: 3.8 + 6.5 + 2.5 + 0.5 + 0.3 + 0.3 + 0.3 + 0.8 + 1.6 = **16.6 ms**. No drift.

### 6.5 Audit Summary

- **8 ADRs all satisfy quality-checkbox criteria** (Engine-Compat + version + post-cutoff flags + GDD-Reqs mapping).
- **158 TRs, ~99% ADR-covered, 0 hard gaps** — architecture-review 2026-04-23 verdict **PASS** inherits.
- **1 cross-session conflict** (Combat-autoload in ADR-0007) surfaced during Phase 4 authoring. Resolution: **Path A** (amend ADR-0007 to register Combat at line 7) per godot-specialist consultation 2026-04-23. ✅ LANDED 2026-04-23 — ADR-0007 in-place amendment. Concern closed on `/architecture-review 2026-04-23` fourth-run verdict.
- **3 GDD-coordination items** are producer-tracked and design-level (not ADR gaps).
- **21 verification gates** outstanding across the 8 Proposed ADRs — these move ADRs Proposed → Accepted in Technical Setup / Prototype phase, and are not blockers for this architecture document.

---

## 7. Required ADRs

Current state per §6 audit + `requirements-traceability.md` third-run 2026-04-23: **0 hard ADR-level gaps**. Existing 8 ADRs cover ~99% of 158 TRs across all MVP and Vertical Slice systems. What remains is: 1 ADR amendment flagged by Phase 5, 24 verification gates that move existing ADRs Proposed → Accepted, and 4 future-ADR flags that ADR-0001 / ADR-0008 explicitly defer.

### 7.1 Must be in place before coding starts (Foundation + Core decisions)

**All authored and Proposed — none missing.** The 8 ADRs cover every hard architectural decision for MVP scope:

| ADR | Foundation/Core concern it resolves |
|---|---|
| ADR-0001 | Per-pixel outline tier mechanism (stencil contract) |
| ADR-0002 | Cross-system event dispatch + accessor carve-outs |
| ADR-0003 | Save format, atomicity, versioning, actor identity |
| ADR-0004 | UI theme, input context stack, font registry, dismiss grammar |
| ADR-0005 | FPS hands outline (single documented exception to ADR-0001) |
| ADR-0006 | Collision layer contract + static-class source of truth |
| ADR-0007 | Autoload registration order |
| ADR-0008 | Per-frame and non-frame performance budget distribution |

**No new Foundation/Core ADR is required for MVP authoring to begin.**

### 7.2 Must be resolved before Pre-Production gate

#### 7.2.1 ADR-0007 amendment — Combat autoload inclusion ✅ LANDED 2026-04-23

| Field | Value |
|---|---|
| **Status** | ✅ **LANDED 2026-04-23** via `/architecture-decision adr-0007-amendment`. Canonical registration table now 7 entries; Combat at line 7. Registry (`docs/registry/architecture.yaml` `autoload_registration_order` row) aligned. |
| **Trigger** | Phase 5 §6.3 conflict surfaced by Phase 4 API-Boundaries authoring. |
| **Action** | `/architecture-decision adr-0007-amendment` (solo mode). |
| **Scope** | Add Combat at canonical line 7 (after PostProcessStack). Update ADR-0007 summary "6 autoloads" → "7 autoloads" throughout; update canonical registration table; note TR-CD-022 as authoritative source for the `class_name CombatSystemNode` / autoload-key `Combat` split rationale. |
| **Owner** | `technical-director` |
| **Actual effort** | 1 session (in-place ADR amendment: 13 edits to ADR-0007 + 1 row in `docs/registry/architecture.yaml`). No downstream "load order N" text edits required. |
| **Blocks** | Nothing concrete. Clears editorial debt; eliminates false conflict state. |
| **Recommendation source** | godot-specialist consultation 2026-04-23 (Path A endorsed). |

#### 7.2.2 Verification gates outstanding on the 8 Proposed ADRs

Normal Technical Setup / Prototype phase work. These move ADRs from Proposed → Accepted. Summary counts per ADR (full catalogs in each ADR's Validation Criteria):

| ADR | Gates | Nature |
|---|---:|---|
| ADR-0001 | 4 | **All 4 gates closed 2026-04-30 — ADR Accepted.** G1 (BaseMaterial3D stencil property) ✅; G2 (CompositorEffect stencil-test on Vulkan) ✅ via Sprint 01 spike — D3D12 closed by removal per Amendment A2; G3 (Iris Xe profiling) ✅ CONDITIONAL on production using jump-flood (Finding F6 → IG 7); G4 (Shader Baker) ✅ reframed via Finding F5 (RDShaderFile pre-compile path) |
| ADR-0002 | 1 | Smoke test: emit one signal → EventLogger prints → subscriber receives |
| ADR-0003 | 3 | ResourceSaver FLAG_COMPRESS round-trip; DirAccess.rename atomicity; `Dictionary[StringName, GuardRecord]` duplicate_deep isolation (A3-refined) |
| ADR-0004 | 3 | Control.accessibility_* property names; Theme inheritance property name; `_unhandled_input` dismiss across KB/M and gamepad |
| ADR-0005 | 5 | Inverted-hull Vulkan parity (G1 ✅ closed via Sprint 01 spike; G2 D3D12 parity ✅ CLOSED BY REMOVAL Amendment A6 — Vulkan-only); Shader Baker × `material_overlay` compat (G5, A5-added, moved to Prototype); G3 + G4 still pending (resolution-scale toggle + animated rigged hand mesh — production scope) |
| ADR-0006 | 3 | PhysicsLayers compiles and references from gameplay; project.godot named-layer slots populated; end-to-end usage migration verification |
| ADR-0007 | 1 | `project.godot [autoload]` block byte-matches canonical table (incidentally validated by ADR-0002 Gate 1) |
| ADR-0008 | 4 | Restaurant reference scene measurement on Iris Xe; RTX 2060 informative; ~~D3D12 post-stream warm-up allowance~~ CLOSED BY REMOVAL Amendment A2 (Vulkan-only); autoload boot ≤50 ms cold-start |
| **Total** | **24** | 21 pre-existing + 3 added via A3–A6 amendments |

Two infrastructure stories are implied by the gates (flagged in `production/session-state/active.md` 2026-04-23):

- **Reference scene authoring** (`tests/reference_scenes/restaurant_dense_interior.tscn`) — prerequisite for ADR-0008 Gates 1–3; scoped as a separate tooling story (prototyper or qa-lead owner).
- **CI `perf-gate` job configuration** — prerequisite for ADR-0008 Gate 1 CI enforcement; scoped as a separate devops-engineer story.

### 7.3 Should have before the relevant system is built

**None identified.** All VS-scope systems (Inventory & Gadgets, Mission & Level Scripting, Failure & Respawn, Civilian AI, Document Collection, Dialogue & Subtitles, HUD Core, HUD State Signaling, Document Overlay UI, Menu System, Cutscenes & Mission Cards, Settings & Accessibility) are covered by at least one existing ADR for their cross-cutting concerns. New ADRs may be triggered during these systems' `/design-system` passes if they surface engine-specific gotchas, but none are presently foreseeable.

**One provisional flag**: **Failure & Respawn autoload decision.** Phase 2 module ownership marks Failure & Respawn as "Failure autoload OR Mission-owned; not yet authored". If the GDD chooses autoload, a second ADR-0007 amendment will be needed to add Failure at line 8. If Mission-owned, no amendment. This decision belongs in the Failure & Respawn `/design-system` pass, not this architecture document.

### 7.4 Can defer to implementation / Polish phase

| Deferred ADR | Source of deferral | When it might be authored |
|---|---|---|
| **Outline Shader Implementation** — Sobel vs Laplacian kernel choice, edge-threshold tuning, per-tier kernel shape | ADR-0001 §Related explicitly defers: "Future ADR: Outline Shader Implementation (detail-level decision about Sobel vs Laplacian kernel, edge threshold tuning) — out of scope here; this ADR establishes the contract, not the algorithm internals" | During Outline Pipeline implementation (Prototype phase), after Iris Xe measurements reveal which kernel fits the 2.0 ms cap |
| **Memory Budget Distribution** — 4 GB ceiling distribution across systems (memory analogue of ADR-0008) | ADR-0008 §Requirements explicitly defers: "Memory budgets (4 GB ceiling) are out of scope — deferred to a future ADR" | Polish phase, triggered by a soak-test memory-growth finding or a specific system's memory claim approaching the ceiling |
| **Shader Baker policy** (if anything beyond ADR-0005 Gate 5 + ADR-0008 cold-boot references needs codifying) | No ADR explicitly defers this. A dedicated ADR may be unnecessary — current references suffice. | Only if Shader Baker export-time behavior on Vulkan surfaces edge cases that affect multiple systems (D3D12 not targeted per Amendment A2) |
| **AccessKit Integration Specifics** (if the 4.5 API surfaces complications during Settings & Accessibility implementation) | ADR-0004 references AccessKit at the scaffold level but does not specify control-by-control `accessibility_*` wire-up | During Settings & Accessibility `/design-system` pass (VS phase) if the wire-up has sufficient cross-system implications |

None of these is time-sensitive. They are flags to revisit if the relevant trigger surfaces.

### 7.5 Summary — what this architecture needs next

**Before coding starts**: 8 Proposed ADRs exist. No new ADR required for Foundation + Core.

**Before Pre-Production gate**: 1 ADR-0007 amendment (Combat autoload inclusion, Path A) + 24 verification gates across the 8 existing ADRs to move them Proposed → Accepted. Two separate infrastructure stories (reference scene + CI perf-gate job) feed into the ADR-0008 gates.

**Before each VS system is built**: probably nothing new. One provisional ADR-0007 amendment (Failure & Respawn autoload) may be triggered by that GDD.

**Deferred (implementation / Polish)**: 4 candidate future ADRs flagged by the existing ADRs themselves — not gating anything.

---

## 8. Architecture Principles

Five principles that govern all technical decisions for this project. These are not style preferences — violations require documented exemption through ADR amendment or explicit Open Question.

### 8.1 Engine-risk discipline

Every post-cutoff Godot 4.4 / 4.5 / 4.6 API surface used by this project is fenced by at least one ADR. No architectural decision relies on an un-fenced post-cutoff API. If the project ever upgrades engine versions, every ADR with HIGH or MEDIUM Knowledge Risk must be re-validated per its Engine Compatibility section, and any API behavior change triggers a new ADR or a Superseded flag on the existing one.

**Operational consequence**: before adopting any API not present in the LLM's training data (~4.3), confirm it in `docs/engine-reference/godot/` and, if it influences multiple systems or appears in multiple GDDs, gate adoption behind a new ADR.

### 8.2 Loose coupling via typed signal bus

Cross-system communication defaults to the Events bus (ADR-0002) using typed signals with qualified enum parameters. Publishers emit; subscribers react; no publisher knows which subscribers exist. Direct cross-module references are reserved for the narrow, explicitly-carved-out cases documented in ADR-0002 *Accessor Conventions (SAI → Combat)*.

**Operational consequence**: a new cross-system communication need is, by default, a new signal declaration on `Events.gd`. A direct-call accessor requires an ADR-0002 amendment with the four exemption criteria justified (read-only, owner-published, stale-safe, not request-response-over-bus). Autoload minimalism applies: new autoloads require an ADR-0007 amendment.

### 8.3 Named constants over magic values

Every cross-cutting identifier — signal name, input action, collision layer, outline tier, performance budget slot, damage type, alert state, takedown type — lives in a single-source-of-truth static class, enum, or named registry. Hardcoded integers, raw `KEY_*` constants, and string literals for structural concepts are forbidden patterns enforced by code review.

**Operational consequence**: before typing a magic number or a bare string into gameplay code, check whether a named constant exists. If none does and the value is cross-cutting, add it to the relevant registry (`InputActions`, `PhysicsLayers`, `OutlineTier`, `CombatSystemNode.DamageType`, etc.) rather than inlining. Related forbidden patterns: `hardcoded_visible_string` (TR-LOC-001), `unregistered_autoload` (ADR-0007), `hardcoded_collision_layer_integer` (ADR-0006).

### 8.4 Performance as a cap, not a target

ADR-0008's 9-slot 16.6 ms budget binds at the Restaurant reference scene on Iris Xe Gen 12. Each slot is a **cap** — a system that exceeds its slot fails CI even if total frame time is below 16.6 ms, because exceeding one slot robs another system's headroom and masks compounding busts in the field. The 10% reserve (1.6 ms) is for OS jitter and unknowns, not a reservoir for systems to overdraw.

**Operational consequence**: every new per-frame ticking code path cites its ADR-0008 slot in its story file. The `unbudgeted_per_frame_ticking` forbidden pattern flags PRs that add `_process` or `_physics_process` hot paths without budget accounting. No system "borrows" from another system's slot or from the reserve without an ADR-0008 amendment.

### 8.5 Pillar compliance over engineering elegance

When a technical decision conflicts with the game pillars — especially Pillar 3 (*Stealth is Theatre, Not Punishment*) and Pillar 5 (*Period Authenticity Over Modernization*) — the pillar wins. The architecture encodes this in several concrete places:

- **Queued respawn** (LS CR-6): a respawn requested during an in-flight transition is never silently dropped; it fires at step 13. This preserves Pillar 3's no-load-a-save promise.
- **Wake-up clock** (SAI `WAKE_UP_SEC = 45`): UNCONSCIOUS guards wake to SUSPICIOUS at the captured KO-time player position, creating counterplay rather than free consequence-less takedowns.
- **No polling HUD** (ADR-0004): HUD surfaces refresh only on signal emission; no `_process`-driven health bar, no persistent alert-status chrome. Reinforces Pillar 5 by matching NOLF1's diegetic HUD style.
- **No focused-widget modal dismiss** (ADR-0004 `_unhandled_input` + `ui_cancel`): Godot 4.6's dual-focus complexity is sidestepped entirely — a period-authentic dismiss that works identically on KB/M and gamepad.
- **`setting_changed` as sole Variant payload** (ADR-0002 IG7): typed signals are the default; the Variant exception is explicitly justified and fenced.

**Operational consequence**: when a clean engineering choice (e.g., typed enum payload, focused-widget button dismiss, aggressive physics eviction) conflicts with a pillar, document the conflict and choose the pillar-aligned path. Future ADRs must explicitly reference which pillar they protect when introducing asymmetric or non-idiomatic patterns.

---

## 9. Open Questions

Decisions deferred to later ADRs, Prototype-phase empirical work, or Polish-phase optimization. Each has a trigger that should resurface the question.

### 9.1 Verification-gate sequencing

**Question**: in what order should the 24 outstanding verification gates across the 8 Proposed ADRs be exercised, and by whom?

**Status**: deferred to Technical Setup phase. The gates themselves are fully specified in each ADR's Validation Criteria; the open question is execution ordering.

**Recommendation** (non-binding, captured for next-session use):

| Order | Gate(s) | Prerequisite |
|---|---|---|
| 1 | Reference scene authoring (`tests/reference_scenes/restaurant_dense_interior.tscn`) | None — tooling story (prototyper or qa-lead owner) |
| 2 | CI `perf-gate` job configuration | Reference scene exists (devops-engineer owner) |
| 3 | ADR-0002 Gate 1 (smoke test) + ADR-0007 Gate 1 (byte-match canonical autoload table) | Smallest scope; validates Signal Bus + Autoload infra together |
| 4 | ADR-0006 Gates 1–3 (PhysicsLayers + named layer slots + migration) | Zero API risk; establishes collision contract |
| 5 | ADR-0001 Gates 1–4 + ADR-0005 Gates 1–5 | Rendering verification bundle — HIGH risk; do together on Vulkan (D3D12 not targeted per Amendment A2). **ADR-0001 all 4 gates closed 2026-04-30 — Accepted.** ADR-0005 G1 + G2 closed; G3, G4, G5 still production scope. |
| 6 | ADR-0003 Gates 1–3 + ADR-0004 Gates 1–3 | Save + UI verification; can run parallel |
| 7 | ADR-0008 Gates 1–4 | Requires reference scene (order 1) and perf-gate CI (order 2); runs against the full system set |

**Trigger to revisit**: `/gate-check pre-production` invocation. Gates left unchecked block promotion of Proposed → Accepted.

### 9.2 ADR-0007 amendment timing

**Question**: when should the Combat-autoload amendment (§7.2.1, Path A) be authored?

**Status**: not time-sensitive. Not blocking any current work. Blocks `/gate-check pre-production` because Pre-Production requires consistent autoload registry.

**Recommendation**: bundle into the same session as the reference scene tooling story — both are Technical Setup work of small scope. Alternative: author alongside ADR-0002 Gate 1 smoke test.

**Trigger to revisit**: first PR to `project.godot [autoload]` block. Any autoload edit must match ADR-0007 byte-for-byte; the amendment must land first.

### 9.3 Failure & Respawn autoload decision

**Question**: should `Failure & Respawn` (system 14) be an autoload (line 8 in a future ADR-0007 amendment) or a Mission-owned node?

**Status**: deferred to `/design-system failure-respawn` authoring. Phase 2 module ownership records it as "Failure autoload OR Mission-owned; not yet authored".

**Decision criteria** (to help the GDD author):
- If Failure & Respawn has cross-scene state (e.g., failure counter across sections, dynamic difficulty hooks) → autoload.
- If it is purely event-driven (`player_died` → `LSS.reload_current_section(RESPAWN)`) → Mission-owned or even a function on Mission Scripting.
- Autoload implies +1 autoload slot (requires ADR-0007 amendment) but simpler cross-section state; Mission-owned implies tighter lifecycle coupling with section scenes.

**Trigger to revisit**: start of Failure & Respawn `/design-system` session.

### 9.4 Reference hardware access for perf verification

**Question**: ADR-0008 validation requires measurement on Iris Xe Gen 12 (caps) and RTX 2060 (informative). How is this verified without both physical machines?

**Status**: not resolved. Project is solo-dev context.

**Candidate answers**:
- **Iris Xe**: Gen 12 is common on 2020+ Intel laptops; solo dev likely has access or can borrow. Verification on a Gen 11 or Gen 13 is an acceptable proxy (document the substitution).
- **RTX 2060**: measurements are *informative not caps* per ADR-0008. An RTX 3060/4060 minus ~20% expected delta is a workable approximation for target-experience tuning. Explicitly note when RTX 2060 is a proxy measurement.
- ~~**D3D12 post-stream warm-up (ADR-0008 Gate 3)**: Windows machine required.~~ **CLOSED BY REMOVAL 2026-04-30 (Amendment A2)** — D3D12 not targeted; this hardware setup item no longer exists. Windows verification of ADR-0008 Gate 4 still requires a Windows machine running Vulkan, but no D3D12-specific tooling.

**Trigger to revisit**: Technical Setup phase scope planning. May need to reach out for platform-specific measurement help.

### 9.5 Tier 2 / Rome + Vatican architectural implications

**Question**: does the 23-system architecture sufficiently cover Tier 2 scope (Rome Colosseum + Vatican St. Peter's Basilica), or do new systems appear?

**Status**: `design/gdd/systems-index.md` claims "No new systems are needed for Tier 2 — Tier 2 is content built on the same systems." This architecture inherits that claim.

**Risks**:
- If Rome's architecture introduces mission types that current Mission Scripting cannot express (e.g., multi-phase sandbox objectives), a new ADR may be required.
- If Vatican requires audio reverb/ambience beyond the 5-preset bus graph, the Audio GDD's fixed music-state grid may need extension.
- Disguise system is Tier 3 Full Vision, not Tier 2 — still out of scope for this architecture.

**Trigger to revisit**: Tier 2 scope planning session (post-MVP ship). No action required before then.

### 9.6 Known deferred future ADRs (tracked in §7.4)

Re-listed here for completeness; full triggers live in §7.4:

- **Outline Shader Implementation** — deferred by ADR-0001. Trigger: Prototype-phase measurement revealing which edge-detect kernel fits the 2.0 ms cap.
- **Memory Budget Distribution** — deferred by ADR-0008. Trigger: soak-test memory-growth finding or system-level claim approaching the 4 GB ceiling.
- **Shader Baker policy** — unforced. Trigger: Vulkan export-time edge case affecting multiple systems (D3D12 not targeted per Amendment A2).
- **AccessKit Integration specifics** — unforced. Trigger: Settings & Accessibility `/design-system` pass surfacing cross-system wire-up complications.

### 9.7 GDD-level open questions (not architectural — flagged for awareness)

Several open questions live in individual GDDs (combat-damage.md §Open Questions, stealth-ai.md §Open Questions, level-streaming.md §Open Questions). These are design-level — this architecture does not claim to resolve them, but notes the set that may produce downstream architectural echoes:

- **OQ-CD-2** (Jolt Area3D broadphase tunneling for 20 m/s darts) — already flagged by ADR-0006 A6 Risks row; mitigation folded into Combat OQ-CD-2 Jolt prototype scope.
- **OQ-CD-12** (Settings & Accessibility forward deps — 9 contracts including photosensitivity + motor-access gap) — will drive Settings GDD authoring; not blocking.
- **OQ-CD-13** (Pillar 5 Boundary doc) — blocking downstream UI GDDs (HUD State Signaling, Document Overlay, Menu, Settings). May produce an ADR if the boundary rules cross multiple systems.
- **OQ-SAI-9** (3+ guard-room propagation gap) + **OQ-SAI-10** (CURIOSITY_BAIT animation commitment) — playtest-gated; may trigger F.4 formula revision but no new ADR foreseen.
- **OQ-LS-8 through OQ-LS-12** — level-streaming refinements; individually bounded to LS scope; no architectural escalation expected.

**Trigger to revisit**: `/review-all-gdds` next run, or `/architecture-review` spot-check if any GDD OQ closure introduces cross-system implications.
