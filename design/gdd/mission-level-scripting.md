# Mission & Level Scripting

> **Status**: **Approved 2026-04-24** (post `/design-review` revision pass — accepted on author confidence per user; 16 BLOCKING items resolved in-doc; 5 cross-system coord items + 4 OQs remain open as known-pending dependencies for sprint start; see `design/gdd/reviews/mission-level-scripting-review-log.md`)
> **Author**: user + game-designer + level-designer (+ narrative-director, systems-designer, gameplay-programmer, qa-lead, art-director, audio-director as specialist consultants)
> **Last Updated**: 2026-04-24 (revision pass)
> **Implements Pillar**: Pillar 1 (Comedy Without Punchlines) + Pillar 4 (Iconic Locations as Co-Stars) — primary; Pillar 2 (Discovery Rewards Patience) + Pillar 3 (Stealth is Theatre, Not Punishment) — secondary

## Overview

**Mission & Level Scripting (MLS)** is the Gameplay-layer system that owns the mission lifecycle, drives the scripted moments where *The Paris Affair*'s comedy lands, and defines what every section scene must contain on disk. Mechanically it has five responsibilities: (1) the mission state machine, publishing the four Mission-domain signals declared in ADR-0002 (`mission_started`, `mission_completed`, `objective_started`, `objective_completed`); (2) the scripted-event trigger system, built from Area3D volumes and Signal Bus subscriptions (`section_entered(reason)`, `guard_woke_up`, `enemy_killed`, `alert_state_changed(severity)`) that fire comedic beats, guard choreography, and the bomb-disarm sequence; (3) the **section authoring contract** — every section scene must include a `player_respawn_point: Marker3D` child (consumed by Failure & Respawn), WorldItem pickup caches within the Inventory-authored budget, and `peek_surface` / `placeable_surface` collision-shape tags; (4) the **SaveGame assembler role** designated by ADR-0003 — on `section_entered(FORWARD)` MLS reads every owning system's `capture()` static, assembles a `SaveGame` synchronously, and hands it to `SaveLoadService` (autosave is explicitly gated on `FORWARD` only — `RESPAWN` must never autosave per architecture.md §7.2.1); (5) the objective/cutscene surface consumed downstream by HUD Core and Cutscenes & Mission Cards (VS tier). MLS registers as autoload per ADR-0007 (amended 2026-04-27 — after `FailureRespawn`, both after `Combat`), and claims a share of the 0.8 ms residual performance pool per ADR-0008. Players experience MLS as the spine of the game's identity: the caterer's absurd monologue in the Restaurant section, the bomb's theatrical tick-tick at the top of the Tower, the observation that Eve never sees a quest marker yet always knows where the next scene is — all are scripted beats emitted through this system. MLS is the one place in the codebase where Pillar 1 *(Comedy Without Punchlines)* and Pillar 4 *(Iconic Locations as Co-Stars)* are deliberately authored rather than emergent.

## Player Fantasy

**Player fantasy**: *You are a competent BQA agent reading the world faster than the world reads you — and the mission is already unfolding whether or not you keep up.*

Eve Sterling's mission briefing ends before the game begins. The Nagra reel from the BQA listening room tells her three things — infiltrate the Eiffel Tower, disarm the PHANTOM bioweapon in the Upper structure, exfiltrate before the 06:00 police rotation. It doesn't tell her which door, which guard, which floor, or whether the disarm sequence is in a technician's notebook, a folded memo in the Restaurant kitchen, or tattooed behind an observation-deck guard's ear. She finds out by going there.

At the Plaza a caterer loudly complains that the sommelier has padded the wine order; on the Lower scaffolds a foreman reads aloud from a racing form; the Restaurant's maître d' rehearses a welcome speech for a dignitary who is in fact buried under Les Invalides. Objectives complete themselves when Eve does the thing — she plants the listening device because she's near the transmitter, not because a HUD arrow tells her to. When she finally reaches the bomb chamber and the clock starts ticking, she doesn't see a "PRIMARY OBJECTIVE UPDATED" banner; she hears the Tower's service klaxon, catches a guard on the observation deck griping "Christ, not the fire-drill bell again," and knows without being told that the last act has begun.

**Serves**: Pillar 2 (discovery over UI) as the dominant fantasy; Pillar 1 (the caterer, foreman, and maître d' are the gags — Eve is silent by default per CR-14); Pillar 4 (Tower-specific beats — sommelier, fire-drill bell, sky-high service klaxon); Pillar 5 by absence (no objective markers, no progress banners, no quest log — the world confirms).

**Discovery Surface guarantee (CR-21 + §C.9)**: removing UI does not by itself create discovery. Each pre-Section-4 section MUST contain at least one diegetic clue that narrows the bomb's location for a patient observer (foreman's clipboard, kitchen memo, courier's overheard call). The §C.9 catalog defines the per-section discovery surface that makes "she finds out by going there" a designed mechanic, not an emergent accident.

## Detailed Design

### C.1 Core Rules

**CR-1 — Single active mission at a time.** The MLS autoload holds exactly one `_active_mission: MissionResource`. On `section_entered(_, NEW_GAME | LOAD_FROM_SAVE)` MLS loads the mission defined in the section's scene metadata and emits `Events.mission_started(mission_id)`. Starting a second mission while one is RUNNING is `push_error` + drop.

**CR-2 — Mission state: IDLE → RUNNING → COMPLETED; no FAILED at MVP.** MLS boots IDLE (autoload `_ready()`). Transitions to RUNNING on first `mission_started`. Transitions to COMPLETED when every objective with `required_for_completion == true` is COMPLETED — re-checked synchronously in every `objective_completed` handler. COMPLETED is terminal; re-entry requires new game / load. No FAILED state: per F&R CR-1, `player_died` routes entirely through F&R's respawn — MLS never observes mission-fail.

**CR-3 — Objective state: PENDING → ACTIVE → COMPLETED; no FAILED, no SUPERSEDED state.** When an alt-route `objective_completed(alt_id)` fires for an objective whose `MissionObjective` lists `supersedes: Array[StringName]`, MLS synchronously emits `objective_completed(sibling_id)` for each entry **in the same frame**. HUD and all subscribers treat a superseded completion identically to a normal completion (per user decision 2026-04-24 — keeps ADR-0002 Mission domain at 4 signals).

**CR-4 — Objective completion is diegetic.** Completion fires via a subscribed `Events` signal, never via "press F to complete", distance-to-marker, or "collect 3 of 5" UI counter. The `completion_signal` must be an event Eve's action already produces (`document_collected`, `enemy_killed`, scripted-beat-owned signal). MLS subscribes on ACTIVE, unsubscribes on COMPLETED.

**CR-5 — Pillar 5 absolute: no waypoints, no minimap pins, no HUD banners.** MLS forbidden from calling any API that sets a world-space objective marker, minimap pin, compass widget, or "QUEST UPDATED"/"OBJECTIVE COMPLETE" banner. Progress confirms exclusively via diegetic cues (NPC dialogue, environmental change, audio sting). **No exceptions at MVP.**

**CR-6 — Trigger volumes: `class_name MLSTrigger extends Area3D`, body_entered single-fire, no body_exited.** `@export var trigger_id: StringName`, `@export var one_shot: bool = true`, collision layer per ADR-0006 (see coord item #15 — ADR-0006 Triggers-layer amendment pending). On `body_entered(body)`: (1) `is_instance_valid(body)`; (2) `body.is_in_group("player")`; (3) **`trigger_id not in MissionState.triggers_fired`**; (4) on first valid entry add `trigger_id` to `MissionState.triggers_fired` synchronously; (5) call `set_deferred("monitoring", false)`; (6) THEN run beat body. The synchronous step-3 check provides same-frame idempotency; `set_deferred` is the cross-frame structural latch. **`MissionState.triggers_fired: Dictionary[StringName, bool]`** — closed from OQ-MLS-12; O(1) membership check. **MUST NOT subscribe to `body_exited`** — Jolt 4.6 non-determinism on mid-overlap despawn (F&R OQ-FR-9; see coord item #15 — formal Jolt citation pending). Exit logic uses frame-coherent distance checks or explicit deactivation.

**CR-7 — Scripted beats are savepoint-persistent; do NOT re-fire on RESPAWN.** Each beat records its `beat_id` in `MissionState.fired_beats` before the body runs. On `section_entered(_, RESPAWN)` MLS restores `fired_beats` from slot 0 — any beat whose `beat_id ∈ fired_beats` is NOT re-fired. Beats fire "fresh" only on first entry to their section in the current run. *Rationale: simpler state, matches NOLF1, user-confirmed 2026-04-24.*

**CR-8 — Guard choreography via `SAI.force_alert_state`, escalation-only.** Calls `guard.force_alert_state(new_state, AlertCause.SCRIPTED)` per SAI §Interactions, restricted to `new_state > guard.current_alert_state`. MLS may NOT force de-escalation; stand-down uses section-level guard despawn/respawn. `force_alert_state(SCRIPTED)` does NOT trigger SAI propagation (SAI F.4); simultaneous multi-guard escalation calls each within same physics frame.

**CR-9 — Section authoring contract — required nodes (see §C.5).** Every section scene in `res://scenes/sections/` must contain required nodes detailed in §C.5, build-CI-enforced per F&R BLOCKING coord item #11. Anchor node: `Marker3D` named `player_respawn_point` MUST be a direct child of the section root (NOT in a sub-scene); F&R CR-11 calls `find_child("player_respawn_point", true, true)` — third arg `owned=true` restricts to nodes owned by the section root, preventing false matches in instanced sub-scenes per /design-review godot-specialist finding #6.

**CR-10 — WorldItem cache placement policy (MLS-authored, Level Designer executes).** Inventory-locked caps are total-mission counts (8 pistol + 2 dart-off-path + **7 medkit** + 1 rifle-carrier-per-section + 1 Parfum-Restaurant). MLS §C.5 defines placement policy (off-path minimums, distribution ratios, mission-gadget pinning). Level Designer places `WorldItem` scene instances per policy. **MLS does NOT spawn WorldItems at runtime** — scene-authored static placements only. Mission scripts may `queue_free` a WorldItem via a scripted beat but may not spawn new ones. *(2026-04-28 — medkit cap raised 3 → 7 per `/review-all-gdds` 2026-04-28 GD-B4 design decision: 1 medkit **guaranteed** per section post-Plaza (Lower 1 / Restaurant 1 / Upper 2 / Bomb 1 = 5 guaranteed) + 2 off-path bonus medkits = 7 total. Closes the late-mission health-scarcity death-spiral risk identified in the 2026-04-28 cross-review.)*

**CR-11 — Surface tags authored by level designers following MLS convention.** `peek_surface` tags (Compact viewfinder) and `placeable_surface` tags (Cigarette Case, up-vector ≥ 0.7) authored via `set_meta("surface_tag", &"...")` on `CollisionShape3D`. Inventory queries at runtime; MLS owns the authoring convention (§C.5) but does not consume directly.

**CR-12 — Autosave gate: slot 0 on `section_entered(FORWARD)` only.** On `reason == FORWARD` MLS assembles SaveGame (CR-15) and calls `SaveLoadService.save_to_slot(0, ...)` per save-load.md CR-3 + L152. On `reason ∈ {RESPAWN, NEW_GAME, LOAD_FROM_SAVE}` MLS performs NO save write. **Absolute rule**: RESPAWN autosave would corrupt F&R's anti-farm invariant. F&R writes slot 0 independently on `player_died`; shared `SAVING`-state queue (save-load.md L134) resolves simultaneous writes.

**CR-13 — Mission-card / cutscene dispatch via Mission-domain signals only.** Briefing cards and section-transition cutscenes triggered by MLS emitting `mission_started` / `mission_completed` / `objective_started` / `objective_completed`; VS-tier Cutscenes subscribes and renders. MLS does NOT hold a reference to, import, or call Cutscenes (ADR-0002 direct-reference anti-pattern). If Cutscenes absent in pre-VS builds, signal fires into void — gameplay beat still resolves.

**CR-14 — Eve is silent BY DEFAULT; scripted dialogue lives on NPCs / environment (Pillar 1 default disposition).** Scripted comedy beats author dialogue on NPC `DialogueAnchor` nodes or environment `AudioStreamPlayer3D`. MLS does NOT author Eve VO during normal beat authoring; default routing is non-Eve NPC source. **Authorized exceptions per creative-director ruling 2026-04-24**: (a) up to 4 non-verbal Eve cues per mission (sharp exhale, tool-handling sound, breath-hold release) anchored to anim/audio events — these are NOT VO lines and bypass FP-3; (b) up to 2 deadpan Eve reaction lines per mission requiring explicit narrative-director sign-off. FP-3 grep is **demoted from absolute to advisory** (warns; does not block CI). The Coen-Brothers-deadpan channel is preserved by exception; the default of NPC-led comedy is preserved by absence.

**CR-15 — MLS is the sole SaveGame assembler on FORWARD; synchronous; no await; no call_deferred.** On `section_entered(_, FORWARD)` MLS calls `capture()` / `serialize_state()` on each owning system (Inventory, SAI, F&R, PlayerCharacter, DocumentCollection, MissionScripting itself) **synchronously within the same handler**, assembles `SaveGame`, calls `SaveLoadService.save_to_slot(0, ...)`. No `await`, no `call_deferred` — would break single-threaded atomicity (ADR-0003 + F&R CR-4). If any `capture()` returns `null`, emit `save_failed(SaveLoad.FailureReason.IO_ERROR)` and **abort**. F&R is sole writer on `player_died`; MLS is sole writer on FORWARD. **Frame-budget honesty**: this synchronous chain runs on the main thread during the LS 33 ms snap-out fade window; the fade is a renderer-only effect — the game loop is still running. The capture chain therefore consumes the next frame's budget. F.4 budgets the assembly cost as a per-frame hit during the fade frame, not as exempt; ADR-0008 amendment (coord item #3) must reflect this.

**CR-16 — LOAD_FROM_SAVE suppresses `objective_started` re-emit; HUD rebuilds from snapshot on `game_loaded`.** On `section_entered(_, LOAD_FROM_SAVE)` MLS restores `MissionState` but does NOT re-emit `objective_started` for restored ACTIVE objectives. HUD Core (VS) subscribes to `game_loaded(slot)` separately and queries MLS's `get_active_objectives() -> Array[StringName]` to rebuild display. Prevents Dialogue re-playing briefing barks; keeps Mission-domain signals as fresh-activation events only.

**CR-17 — MLS registers as autoload per ADR-0007 (amended 2026-04-27; B2 from /review-all-gdds 2026-04-27 closed).** Registers as `MissionScripting` of type `class_name MissionScriptingService extends Node` per ADR-0007 canonical registration table (after `FailureRespawn`, after `Combat`). MLS subscribes to F&R's `respawn_triggered` — load-order dependency requires F&R precede MLS, which is enforced by the canonical table line ordering. Per ADR-0007 Cross-Autoload Reference Safety rule 4: MLS MUST NOT reference other autoloads in `_init()` — all cross-autoload setup in `_ready()`. Per ADR-0007 IG7: this GDD does NOT restate specific line numbers — refer to ADR-0007 §Canonical Registration Table for the authoritative ordering.

**CR-18 — Objectives authored as `class_name MissionObjective extends Resource` .tres files.** `@export` fields: `objective_id: StringName`, `display_name_key: StringName` (Localization), `prereq_objective_ids: Array[StringName]`, `completion_signal: StringName`, `completion_filter_method: StringName` (optional predicate — method name resolved at runtime against MLS service; **NOT a Callable** — Godot 4.6 cannot serialize Callable in .tres), `supersedes: Array[StringName]` (alt-route chain per CR-3), `required_for_completion: bool` (per CR-2). Stored in `assets/data/missions/<mission_id>/objectives/`. Missions as `class_name MissionResource extends Resource`. **Mission-load pattern (single canonical)**: section root `@export var mission_id: StringName`; MLS reads it and calls `ResourceLoader.load("res://assets/data/missions/" + mission_id + "/mission.tres")` at `mission_started`. The mission resource is NOT @export'd on the section root (would force load on scene-load, before section_entered fires). **Load-time validation (closes F.1 phantom-completion)**: on `mission_started`, MLS asserts `MissionResource.objectives.size() ≥ 1` AND `objectives.any(o -> o.required_for_completion)` AND no objective has `prereq_objective_ids.has(self.objective_id)` AND no mutual prereq cycle (DFS check); on any failure `push_error` and remain IDLE.

**CR-19 — Per-guard variant uniforms + voice pools MLS-authored; LD places instances, not variants.** Mission-specific guard variants (caterer, custodian, restaurant staff) authored as MLS-owned `CharacterBody3D` scene instances with variant-specific materials + voice pools. LD places the variant scene instance in a section — does NOT freelance variant meshes or audio. MLS owns the variant manifest; LD executes placement.

**CR-20 — Forbidden patterns grep-CI-enforced (§C.8).** MLS code must refuse: `body_exited` subscriptions, `call_deferred`/`await` in save pipeline, `NavigationServer3D.map_get_path()`, objective_marker/waypoint/minimap APIs, `get_node()` into section tree from autoload `_ready()`, `Events.*.emit()` from `respawn_triggered` handler (F&R CR-8 re-entrancy fence), authored Eve VO without narrative-director sign-off (CR-14 — advisory grep, not blocking).

**CR-21 — Discovery Surface guarantee (Pillar 2 positive design).** Every section preceding the bomb chamber (Sections 1–4) MUST contain at least one **Discovery Surface** — a diegetic artefact that narrows the bomb's spatial location for a patient observer. Discovery Surfaces are catalogued per-section in §C.9 and are a NEW required scene-authoring property: `@export var discovery_surface_ids: Array[StringName]` on the section root, length ≥ 1 for sections 1–4, length 0 permitted for the bomb chamber (Section 5) since it IS the destination. Discovery Surfaces are AUTHORED, not emergent — a foreman's clipboard with a maintenance-route notation, a kitchen memo referencing "Upper observation deck — 06:00 rotation," a courier's overheard call mentioning a floor number. Build CI (§C.5.6) enforces presence; narrative payload (the actual clue text) is narrative-director sign-off territory. **Rationale**: removing UI does not by itself create discovery; this CR makes "Eve reads the world faster than it reads her" a designed mechanic rather than a removal artefact (closes /design-review BLOCKING #1, creative-director MAJOR REVISION verdict).

### C.2 Mission State Machine

| From | To | Trigger signal | Guard | Side-effect |
|------|-----|----------------|-------|-------------|
| — | **IDLE** | Autoload `_ready()` | Always | Subscribe to `Events.section_entered`, `respawn_triggered`, `enemy_killed`, `guard_incapacitated`, `guard_woke_up`, `alert_state_changed` |
| IDLE | **RUNNING** | `section_entered(id, NEW_GAME)` | `_active_mission == null` | Load MissionResource; emit `mission_started(mission_id)`; activate first PENDING→ACTIVE objectives whose prereqs are empty |
| IDLE | **RUNNING** | `section_entered(id, LOAD_FROM_SAVE)` | `_active_mission == null` | Load MissionResource; restore MissionState via LSS step-9 callback; **suppress** `mission_started` + `objective_started` emit (CR-16) |
| RUNNING | RUNNING | `section_entered(id, FORWARD)` | `_active_mission != null` | Assemble SaveGame synchronously (CR-15); `save_to_slot(0, ...)`; fire Type-7 Section Threshold Beats |
| RUNNING | RUNNING | `section_entered(id, RESPAWN)` | Any | NO autosave; `fired_beats` already restored via slot-0 reload — beat replay suppressed naturally (CR-7) |
| RUNNING | RUNNING | `respawn_triggered(section_id)` | Any | No-op from MLS (F&R owns reload); MUST NOT emit further `Events.*` from this handler (F&R CR-8 re-entrancy fence) |
| RUNNING | RUNNING | `objective_completed(id)` | Any | Check if `supersedes` list of the completing objective is non-empty; if so, emit `objective_completed` for each sibling in same frame (CR-3); check COMPLETED gate |
| RUNNING | **COMPLETED** | `objective_completed(id)` — last `required_for_completion` | All `required_for_completion` objectives are COMPLETED | Emit `mission_completed(mission_id)`; HUD Core + Cutscenes subscribe |
| COMPLETED | (terminal) | — | — | Further Events ignored; new game / load returns to IDLE → RUNNING |

### C.3 Objective State Machine (per-objective instance)

| From | To | Trigger | Guard | Side-effect |
|------|-----|---------|-------|-------------|
| — | **PENDING** | `mission_started` OR `section_entered(LOAD_FROM_SAVE)` | Objective in MissionResource | Initialize `MissionState.objective_states[id] = PENDING` |
| PENDING | **ACTIVE** | `objective_completed(prereq_id)` OR `mission_started` | All `prereq_objective_ids` are COMPLETED | Emit `objective_started(id)`; subscribe to `completion_signal`; HUD + Dialogue may react |
| PENDING | **ACTIVE** | LOAD_FROM_SAVE restore | Loaded state was ACTIVE | Restore; **suppress** `objective_started` emit (CR-16) |
| ACTIVE | **COMPLETED** | `completion_signal` emit matching `completion_filter` | Any | Emit `objective_completed(id)`; unsubscribe; if `supersedes` non-empty, emit `objective_completed` for each sibling same-frame (CR-3) |
| ACTIVE | **COMPLETED** | `objective_completed(supersede_parent_id)` | `self.id ∈ supersede_parent.supersedes` | Emit `objective_completed(id)` for HUD consistency; unsubscribe |
| ACTIVE | **COMPLETED** | LOAD_FROM_SAVE restore | Loaded state was COMPLETED | Restore; **suppress** `objective_completed` emit (CR-16) |
| COMPLETED | (terminal) | — | — | Idempotent |

### C.4 Scripted-Moment Taxonomy (7 types)

Each scripted beat authored in a MissionResource is one of these types. The table fixes lifecycle rules; the §C.6 per-section catalog shows the anchor beat per section.

| Type | Name | Trigger primitive | Re-fires on RESPAWN? | Persists across save-load? | Example (Eiffel Tower mission) |
|------|------|-------------------|----------------------|----------------------------|-------------------------------|
| **T1** | Overheard Banter | MLSTrigger Area3D (body_entered) OR `guard_patrol_reached_node` | No (`fired_beats`) | Yes — flag in SaveGame | Plaza: two guards debate whether "Eiffel" has a terminal e |
| **T2** | Environmental Gag | None — static prop + legible text + placement | N/A (static) | N/A | Restaurant kitchen chalkboard: "NO MORE PHANTOM BUSINESS IN THE WALK-IN FREEZER — Management" |
| **T3** | Comedic Choreography | Timer on `section_entered` OR `guard_reached_waypoint` | No (`fired_beats`) | Yes | Lower scaffolds: construction worker opens empty biscuit tin, 4-sec pause, closes tin, resumes work |
| **T4** | Objective Reveal Beat | Signal subscription: `objective_started(id)` OR `objective_completed(id)` | No (objective state is already saved) | Yes (objective state is authoritative) | Upper Structure: bomb objective activates → Tower service klaxon → guard radios "Christ, not the fire-drill bell again" |
| **T5** | Mission-Gadget Beat | MLSTrigger Area3D around the WorldItem + proximity VO | No, unless Inventory reports `not collected` (see Edge Cases) | Yes — Inventory is authoritative | Restaurant private dining: PHANTOM courier's one-sided phone call establishes Parfum satchel before Eve reaches table |
| **T6** | Alert-State Comedy | Signal subscription: `alert_state_changed(actor, old, new, severity)` filtered to `new == SUSPICIOUS ∨ SEARCHING`; `severity == MAJOR` filter optional | **Yes** — stateless per-trigger (the only type that re-fires) | Not saved — always emergent | Plaza SUSPICIOUS: bystander tourist mutters to wife "Marguerite, I think that woman is following us"; wife replies "You always think that" |
| **T7** | Section Threshold Beat | Signal subscription: `section_entered(id, FORWARD)` | No (FORWARD-only; RESPAWN and LOAD are excluded) | Yes — saved with FORWARD autosave | Bomb chamber entry: no music sting; bomb visible on cross-brace with PHANTOM luggage tag "FRAGILE / PHANTOM INDUSTRIES / HANDLE WITH CARE" |

**Type 6 exception — re-fire is intentional.** T6 is the only type where re-fire on re-achieving the alert state is a feature, not a bug. It IS subject to per-mission rate-limiting via `MissionObjective.alert_comedy_budget` (§G Tuning Knobs) to prevent audio fatigue if Eve repeatedly triggers SUSPICIOUS in the same section. Default budget: 2 fires per alert-state-per-section.

**T6 same-frame burst bound** (closes ai-programmer finding #5): when SAI propagation flips N guards from UNAWARE→SUSPICIOUS in a single physics frame, T6 fires AT MOST ONCE per frame regardless of N. The handler maintains `_t6_fired_this_frame: bool`, set on first fire, reset by a deferred call at end-of-frame. The per-section budget (default 2) and per-frame burst limit (1) compose: 2 separate alert events across separate frames burn the budget normally; a single propagation event firing N guards uses 1 budget point.

#### C.4.1 — `scripted_dialogue_trigger` Authoring Contract *(NEW 2026-04-28 night — D&S Phase 2 propagation per dialogue-subtitles.md §F.6 P3 + §C.5 row 7 SCRIPTED_SCENE)*

Mission & Level Scripting is the **sole publisher** of `Events.scripted_dialogue_trigger(scene_id: StringName)` (registered in ADR-0002 2026-04-28 night amendment, Mission domain). Dialogue & Subtitles is the **sole subscriber**. This signal carries the StringName lookup-key into D&S's per-section dialogue-scene roster and is the **only way** for MLS to drive Dialogue domain category 7 (SCRIPTED_SCENE) lines per D&S §C.5 — MLS does NOT publish DialogueLine IDs or AudioStreamPlayer references; MLS owns *triggers*, D&S owns *playback orchestration*.

**Per-section scene_id roster** (canonical names; D&S validates each `scene_id` against its roster on receipt and silently drops unknown keys with a debug log per D&S CR-DS-19):

| Section | scene_id (StringName) | Trigger primitive | Lifecycle | Notes |
|---------|-----------------------|-------------------|-----------|-------|
| Plaza | `&"plaza_bqa_briefing_intro"` | `section_entered(plaza, FORWARD)` synchronous after `_player_ready` (D&S CR-DS-9 boot-window guard) | T7 Section Threshold Beat (one-shot, fired_beats-persisted) | MVP-Day-1 — single 3-line BQA radio briefing scene `[STERLING.]` register; subscribes to `Events.scripted_dialogue_trigger` exactly once at section enter |
| Plaza | `&"plaza_radiator_curiosity_bait"` | MLSTrigger Area3D body_entered on radiator-near volume (1.5 m radius) | T1 Overheard Banter (one-shot, fired_beats-persisted) | MVP-Day-1 — single CURIOSITY_BAIT line. Vocal-completion protected per D&S CR-DS-6 (only SCRIPTED interrupts) |
| Lower | `&"lower_construction_chatter"` | Timer on `section_entered(lower, FORWARD)` + 4 s delay | T3 Comedic Choreography (one-shot, fired_beats-persisted) | VS — biscuit-tin construction worker exchange (3 lines) |
| Lower | `&"lower_scaffolding_radio"` | MLSTrigger on stairwell landing | T1 Overheard Banter (one-shot, fired_beats-persisted) | VS — guard pair Radio sub-register banter (2 lines) |
| Restaurant | `&"restaurant_vogel_phone_call"` | MLSTrigger on private-dining-room hallway | T5 Mission-Gadget Beat (one-shot, fired_beats-persisted) | VS — PHANTOM courier one-sided phone call (5 lines) establishes Parfum satchel narrative |
| Restaurant | `&"restaurant_kitchen_chefs"` | MLSTrigger on kitchen door volume | T1 Overheard Banter (one-shot, fired_beats-persisted) | VS — chef-vs-cook walk-in-freezer dispute (3 lines) |
| Restaurant | `&"restaurant_dining_couple"` | MLSTrigger on dining-floor center | T1 Overheard Banter (one-shot, fired_beats-persisted) | VS — Marguerite/husband following bit (2 lines) |
| Restaurant | `&"restaurant_clerks_smoke_break"` | MLSTrigger on terrace door | T1 Overheard Banter (one-shot, fired_beats-persisted) | VS — two PHANTOM clerks debate office printer politics (2 lines) |
| Upper | `&"upper_klaxon_radio"` | T4 Objective Reveal Beat: `objective_started(disable_bomb_lights)` | T4 (one-shot, fired_beats-persisted) | VS — guard radio "Christ, not the fire-drill bell again" (1 line) |
| Upper | `&"upper_lattice_patrol"` | MLSTrigger on lattice catwalk | T1 Overheard Banter (one-shot, fired_beats-persisted) | VS — patrol pair lattice-paint history bit (3 lines) |
| Upper | `&"upper_lt_moreau_inspection"` | T7 Section Threshold Beat: `section_entered(upper, FORWARD)` | T7 (one-shot, fired_beats-persisted) | VS — Lt Moreau Named-NPC inspection narrative scene (4 lines incl. `[LT.MOREAU]` register) |
| Bomb | `&"bomb_chamber_entry_silence"` | T7 Section Threshold Beat: `section_entered(bomb, FORWARD)` | T7 (one-shot, fired_beats-persisted) — emits empty / no lines | VS — explicitly emits trigger but D&S roster maps to ZERO lines (per D&S §B.5 anchor vignette: bomb entry is silent — the absence is the beat) |
| Bomb | `&"bomb_handler_extraction_radio"` | T4 Objective Reveal Beat: `objective_completed(disarm_bomb)` | T4 (one-shot, fired_beats-persisted) | VS — `[HANDLER]` BQA extraction acknowledgment (2 lines + Eve `[STERLING.]` 1-word reply) |

**Total scripted scenes**: 13 (1 MVP-Day-1 + 12 VS) producing 31 lines (3 MVP + 28 VS) — within the D&S §C.5 per-section line-count distribution targets.

**Authoring rules** (CI lint via `tools/ci/lint_mission_scripted_dialogue.sh` — NEW BLOCKING coord item, Tools-Programmer scope):

1. Every `MissionResource.scripted_scenes: Array[ScriptedSceneEntry]` entry MUST have a non-empty `scene_id: StringName` matching the roster above (lint fails on unrecognised IDs).
2. Each `scene_id` MUST appear in **exactly one** section's roster (no cross-section reuse — duplicate keys break the per-section authoring assumption).
3. The trigger primitive MUST be one of {`MLSTrigger`, `Timer-on-section_entered`, `objective_started`, `objective_completed`, `section_entered(id, FORWARD)`} — the same set as Scripted-Moment Taxonomy types T1/T3/T4/T5/T7. T6 (Alert-State Comedy) is forbidden as a `scripted_dialogue_trigger` source — T6 is emergent and lives outside the SCRIPTED priority bucket.
4. Each scripted-scene entry MUST be `fired_beats`-persisted (one-shot per save-game). The roster does NOT support repeating scripted dialogue — repeated lines are PATROL_AMBIENT category in D&S, not SCRIPTED.
5. Emission form: `Events.scripted_dialogue_trigger.emit(scene_id)` from MLS's beat-handler after the `fired_beats` latch is set. NEVER emit before the latch (re-emission on RESPAWN would replay the beat). Same-frame `dialogue_line_started` arrival from D&S is normal (D&S enqueues with SCRIPTED priority and resolves per its own resolver).
6. D&S's roster file at `design/narrative/dialogue-writer-brief.md` (per D&S §F.6 P7) MUST have a 1:1 entry for each `scene_id` above — Tools-Programmer CI joins the two rosters and fails the build on any orphaned scene_id (MLS-side or D&S-side).

**Why the indirection** (publish a key, not a line ID): keeps MLS as the canonical authoring location for *what fires when* and D&S as the canonical authoring location for *what is said*. The decoupling lets the writer revise dialogue content without touching mission scripts, and lets level designers re-time scripted beats without touching dialogue files.

**Closes BLOCKING coord item §F.6 P3** from `dialogue-subtitles.md` v0.3.

### C.5 Section Authoring Contract

Every section scene in `res://scenes/sections/` must satisfy this contract. CI fails the build on any BLOCKING violation.

> **📌 Pending Extraction (coord item #12)**: this contract is consumed by 6 systems (MLS, F&R, Inventory, SAI, LSS, Audio) and per /design-review level-designer finding #10 + creative-director ruling will be extracted to `design/gdd/section-authoring-contract.md` in a separate session. Until that extraction lands, MLS owns the canonical contract here. Cross-referencing systems must continue to point to this section.

#### C.5.1 Required nodes

| Node name | Type | Purpose | Consumer system | BLOCKING? |
|-----------|------|---------|-----------------|-----------|
| `player_entry_point` | `Marker3D` | Eve's placement on fresh FORWARD / NEW_GAME arrival | MLS (reads via `@export var entry_point: NodePath`) | **YES** |
| `player_respawn_point` | `Marker3D` | Checkpoint position; **must be a distinct node instance** from `player_entry_point` even if co-located | F&R CR-11 `find_child("player_respawn_point", true, false)` | **YES** (F&R coord #11) |
| `SectionBoundsHint` | `MeshInstance3D` (BoxMesh child), `visible=false` at runtime | Authoring-time AABB for LS `section_bounds` derivation | Level Streaming CR-9 | **YES** |
| `NavMeshRegion` | `NavigationRegion3D` with non-null baked `NavigationMesh` (≥1 polygon) | Guard pathfinding in this section | Stealth AI | **YES** |
| `AmbientSource_[n]` | `AudioStreamPlayer3D` (at least one per section) | Diegetic ambient audio origin | Audio | **YES** (≥1 required) |

#### C.5.2 Required root properties

Root must be `Node3D` or subclass; `@export` declarations:

- `section_id: StringName` — must equal a key in `section_registry.tres`
- `entry_point: NodePath` — resolves to `player_entry_point`
- `respawn_point: NodePath` — resolves to `player_respawn_point` (distinct instance: `get_node(entry_point) != get_node(respawn_point)` asserted in debug)

Root must be in group `"section_root"` (LS CR-9).

**Section passivity rule**: section scene must be PASSIVE until `section_entered(id, ...)` fires — no signals from `_ready()`, no autonomous AI or audio from `_enter_tree()`. Enforced by grep CI matching **both** Godot 4.x idioms: legacy `emit_signal\(` AND modern `\.\s*emit\(` on a signal symbol — pattern: `(emit_signal\s*\(|[a-zA-Z_][a-zA-Z0-9_]*\s*\.emit\s*\()` inside `_ready` / `_enter_tree` function bodies of any `.gd` script attached to a section-scene node. **Scope clarification** (closes level-designer finding #3): "section-scene scripts" means any script attached to a node within the section's `.tscn` whose root is in group `"section_root"`. Sub-scene `.tscn` files (instanced into the section but stored separately) are exempt — their internal `_ready` initialization is permitted; section passivity applies only to wires that ROUTE to gameplay-visible signals from autonomous startup paths.

#### C.5.3 Required groups and metadata

| Tag / Group | Applied to | Method | Purpose | Consumer |
|-------------|------------|--------|---------|----------|
| `"section_root"` | Root Node3D | `add_to_group()` in editor | LS integrity check post-instantiation | Level Streaming |
| `set_meta("surface_tag", &"<tag>")` | Every walkable StaticBody3D's CollisionShape3D | Surface-tagger plugin (editor-time) | Footstep SFX routing | FootstepComponent |
| `set_meta("surface_tag", &"peek_surface")` | Wall/door CollisionShape3D designated as Compact-peek positions | `set_meta` in editor | Compact contextual gate (1.5 m raycast) | Inventory |
| `set_meta("surface_tag", &"placeable_surface")` | Horizontal surfaces (up-vector ≥ 0.7) | `set_meta` in editor | Cigarette Case placement | Inventory |
| `set_meta("bait_source", true)` | AudioStreamPlayer3D nodes designated as SAI noise attractors | `set_meta` in editor | SAI BAIT_SOURCE event origin (Inventory coord #7) | Stealth AI |
| `"guard_patrol"` | Each guard CharacterBody3D with a patrol path | `add_to_group()` | SAI patrol registration | Stealth AI |
| Per-zone group (e.g., `"zone_bomb_chamber"`) | Each guard CharacterBody3D whose zone membership matters for objective tracking | `add_to_group()` | Zone-membership resolution for "all guards in Zone X neutralized" objectives | MLS |

Per-actor invariant (ADR-0003): every guard / civilian CharacterBody3D must export `actor_id: StringName` set to a **section-scoped unique** value.

#### C.5.4 WorldItem cache placement policy

Inventory locks the counts; MLS locks the distribution. Level Designer places WorldItem scene instances per policy.

| Item | Count | Distribution policy |
|------|-------|---------------------|
| **Pistol ammo caches** | **8 total mission** | Minimum 1 per 2 sections; maximum 3 per section; minimum off-path distance: **10 m** from main-path centerline |
| **Dart ammo caches** | **2 total mission, off-path only** | Behind at least one stealth-required choice point (peek/hide/blade-takedown); never on main path; split across ≥2 sections |
| **Medkit pickups** | **7 total mission** | **5 guaranteed** (1 in Lower / 1 in Restaurant / 2 in Upper / 1 in Bomb Chamber — Plaza is tutorial, intentionally 0) + **2 off-path bonus** (placed in any post-Plaza section, off-path-only). Each guaranteed medkit at section midpoint relative to section flow (not at entrance, not at exit); off-path bonus medkits ≥10 m off main path. Never in combat-committed zones. *(2026-04-28: cap raised 3 → 7 per GD-B4 closure; Upper Structure receives 2 because vertical traversal + heaviest guard density create the highest-attrition section and the 2-medkit cluster prevents the late-mission soft-lock identified in the cross-review.)* |
| **Rifle-carrier guard** | **≤1 per section** | Authored as a specific guard archetype; encounter must produce rifle reserve of 12 on pickup (Inventory CR-8) |
| **Mission-gadget (Parfum)** | **1 total mission, Restaurant section, private dining room** | Pillar-4 narrative binding per Inventory CR-13; NOLF-style dead-drop cache; not in main restaurant dining room |

Build-CI enforcement:

- **BLOCKING**: mission-gadget count == 1 across all 5 sections; rifle-carrier ≤1 per section.
- **ADVISORY** (playtest-gated per Inventory OQ-INV-2): pistol ≤ 8, dart ≤ 2, medkit ≤ 7 mission totals (5 guaranteed + 2 off-path bonus).
- **BLOCKING** (added 2026-04-28 per GD-B4): each post-Plaza section MUST contain at least 1 medkit (Plaza 0 / Lower ≥1 / Restaurant ≥1 / Upper ≥2 / Bomb ≥1). CI lint validates `count(medkit_world_items in section) >= medkit_per_section_min[section_id]` for each section.

#### C.5.5 Forbidden content (must not be placed by Level Designer)

- Objective-marker meshes, beacon lights pointing to mission targets — Pillar 5.
- Minimap-readable icon nodes or metadata — Pillar 5 anti-pillar.
- Kill-cam `Camera3D` nodes (`kill_cam_*` or similar) — Pillar 5 + no kill-cam in F&R design.
- Disguise props or uniform-kit WorldItems — Tier 3 scope.
- Per-variant guard costume prefabs as standalone scene instances — variants authored inside the guard's own CharacterBody3D scene per CR-19; LD places the guard scene, not a costume variant.
- Hardcoded `kill_plane_y` Area3D volumes — owned by Player Character.
- `XRay*` or `ThermalGoggles*` nodes — explicitly excluded gadget archetypes (Inventory C.3).
- Per-section `NavigationServer3D.map_get_path` calls in any node script — ADR-0008 + Inventory CR-17 forbidden pattern.
- Any `call_deferred` in `_ready()` that emits a signal before `section_entered` fires — breaks section passivity (§C.5.2).

#### C.5.6 Validation CI rules

All checks run on every push touching `res://scenes/sections/`. Exit code 1 = build fails.

| Rule | Check | BLOCKING? |
|------|-------|-----------|
| Respawn point present | Every `.tscn` has `Marker3D` via `find_child("player_respawn_point", true, true)` (owned=true; root-direct only — closes /design-review godot-specialist finding #6) | **YES — F&R coord #11** |
| Entry point present | Same for `Marker3D` named `player_entry_point` | YES |
| Entry ≠ Respawn distinct instances | `get_node(entry_point) != get_node(respawn_point)` | YES |
| SectionBoundsHint present | `find_child("SectionBoundsHint")` is `MeshInstance3D` with `BoxMesh` | YES |
| `section_root` group membership | Root is in group `"section_root"` | YES |
| `section_id` registry match | `section_id` StringName equals a key in `section_registry.tres` | YES |
| NavMesh baked | `NavigationRegion3D` named `NavMeshRegion` has non-null `navigation_mesh` with ≥1 polygon | YES |
| Surface tags complete | Surface-tagger plugin validator (`addons/surface_tagger/validate.gd`) exits 0 | YES |
| Actor IDs unique | No two CharacterBody3D in same section share `actor_id` | YES |
| Section passivity | Grep `(emit_signal\s*\(\|[a-zA-Z_][a-zA-Z0-9_]*\s*\.emit\s*\()` inside `_ready` / `_enter_tree` of section-scene scripts (covers Godot 4.x `.emit()` AND legacy `emit_signal()`) | YES |
| Discovery Surface present (CR-21) | Sections 1–4 root has `discovery_surface_ids: Array[StringName]` with length ≥1; Section 5 (bomb chamber) length may be 0 | **YES — CR-21** |
| Forbidden node names | No `kill_cam_*`, `ObjectiveMarker*`, `MinimapIcon*`, `XRay*` | YES |
| Rifle-carrier cap | Count of guards with `carried_weapon_id == "rifle"` ≤1 per section | YES |
| Mission-gadget WorldItem | Exactly 1 WorldItem with `item_id == "gadget_mission_pickup"` across all 5 sections (skipped on partial-build branches via `wip` metadata flag on section root — closes level-designer finding #7) | YES |
| Pistol per-section max | Count of `WorldItem[item_id="pistol_ammo"]` ≤3 per section | **YES — promoted from ADVISORY per /design-review economy-designer finding #4** |
| Pistol off-path 10 m | Pistol caches Euclidean distance to LD-tagged `main_path_centerline` Path3D ≥ `off_path_min_distance_m` (default 10 m); LD authors centerline node per-section | **YES — promoted from unmeasured per /design-review economy-designer finding #4** |
| Pistol / Dart / Medkit total caps | Counts ≤ 8 / 2 / 7 mission totals (medkit raised 3 → 7 per 2026-04-28 GD-B4 decision) | ADVISORY (playtest-gated) |
| Medkit per-section minimum | Plaza 0, Lower ≥1, Restaurant ≥1, Upper ≥2, Bomb ≥1 (5 guaranteed + 2 off-path bonus = 7 total) | **YES — added 2026-04-28 per GD-B4 closure** |
| SectionBoundsHint AABB sanity | `BoxMesh.size > Vector3(1, 1, 1)` AND AABB contains both `player_entry_point` and `player_respawn_point` positions | **YES — promoted from OQ-MLS-4** |

### C.6 Per-Section Iconic Beats (Pillar 4 anchors)

Each section carries at least one anchor beat whose solution / comedy is geography-bound — could ONLY happen HERE. Additional beats per section are Level-Designer latitude within the §C.4 taxonomy.

| Section | Anchor beat | Type | Pillar binding |
|---------|-------------|------|----------------|
| **Plaza** | *The Plaque Debate* — two guards at the maintenance gate argue whether "Eiffel" has a terminal e; one consults a postcard; the postcard is of the Louvre. Tower's own plaque visible 10 m away on the ironwork. Eve passes behind them while they squint at the postcard. **Composition requirement (added per /design-review narrative-director finding #1)**: the level-design layout MUST place the player's natural transit line such that the postcard (in guard's hand) AND the Tower's plaque are co-visible in a single forward-facing camera frame at ≥1 point during the trigger volume. The visual irony depends on co-visibility, not just audio overhearing. | T1 Overheard Banter | 1 + 4 (Tower plaque prop; impossible elsewhere) |
| **Lower scaffolds** | *The Foreman's Lunch Inventory* (placeholder T1 per /design-review creative-director ruling) — exterior girder at height; foreman to apprentice, going through his lunch tin: *"Pâté. Bread. Two cornichons. No biscuits — Marie says I eat them on the train, but the train is two hours, what am I supposed to do, look at the seat?"* Apprentice grunts non-committally. Tower silhouette 200 m above frames the conversation; Paris skyline behind. **Status**: DRAFT placeholder; narrative-director sign-off required per OQ-MLS-13 before final lock. Pillar binding preserved (industrial height + domestic absurdism); no animation budget required. | T1 Overheard Banter | 1 + 4 (Frenchman who packed lunch for sabotage; height + bread mathematics) |
| **Restaurant** | *The Parfum Consignment* — entering the private dining room (gated by a locked side-door that opens only when the courier's call body completes — closes /design-review economy-designer finding #7 cinematic-reveal break), overheard PHANTOM courier's one-sided phone call: *"— the Parfum consignment is on the table, Herr Direktor, decanted into the cobalt bottle as requested, gold atomizer — very discreet — yes, no one will suspect a —"* Call cuts when a door slams. Bottle is on the table. Eve picks it up. BQA intercepted PHANTOM's own supply. **Absurdist core (added per /design-review narrative-director finding #3)**: the courier closes by adjusting the bottle's exact angle on the table for "discretion" — adding a beat of competent-villain fastidiousness that is the comedy. | T5 Mission-Gadget Beat | 1 + 2 + 4 (Pillar-4 narrative-binding per Inventory CR-13) |
| **Upper structure** | *The Fire-Drill Bell* — when the bomb objective activates, the Tower's service klaxon sounds; an observation-deck guard radios down "Christ, not the fire-drill bell again." No UI, no banner. Player understands from the guard's boredom that the klaxon sounds often — which is exactly why PHANTOM used it as a trigger cover. | T4 Objective Reveal Beat | 1 + 4 + 5 by absence (exposed open-sky observation deck; sound carries; guard's radio is the only human voice against open air) |
| **Bomb chamber** | *The Luggage Tag* — on crossing the section threshold, no music sting; Eve's FPS hands in frame; bomb visible on the cross-brace with a PHANTOM luggage tag "FRAGILE / PHANTOM INDUSTRIES / HANDLE WITH CARE / Routing: M. Beaumont, Logbook 47-B." From below, a guard voice floats up the shaft: "—has anyone seen Beaumont's logbook? Forty-seven-B, the one with the routing slips—" Tag and offscreen line are explicitly cross-referenced via "logbook 47-B" (added per /design-review narrative-director finding #6 — the climax beat's two halves now narratively connect: PHANTOM is a corporate enterprise that misplaces its own paperwork while planting a bomb). | T7 Section Threshold Beat | 1 + 4 (corporate-bureaucracy register; cross-brace geometry; comedy in the connected tag↔logbook reference) |

### C.9 Discovery Surface Catalog (per CR-21 — Pillar 2 positive design)

Each Section 1–4 carries at least one Discovery Surface — a diegetic clue narrowing the bomb's spatial location for the patient observer. Section 5 (Bomb Chamber) is exempt (it IS the destination). Discovery Surfaces are NOT objective markers (Pillar 5 absolute) — they are environmental artefacts that REWARD reading rather than DIRECT navigation. A speedrunner can ignore them; a patient observer is rewarded with foreknowledge of where she is going.

| Section | Discovery Surface ID | Surface type | Diegetic content (DRAFT — narrative-director sign-off pending OQ-MLS-13) | Bomb-location info delivered |
|---------|----------------------|--------------|--------------------------------------------------------------------------|------------------------------|
| **Plaza** | `ds_plaza_maintenance_schedule` | Static prop (clipboard on guard hut wall, T2-style) | A maintenance roster lists "OBSERVATION DECK — service entrance: 06:00 / 18:00 — N. Beaumont" | Bomb is in the Upper Structure, accessed via a service entrance |
| **Lower scaffolds** | `ds_lower_foreman_clipboard` | Static prop (foreman's clipboard, readable when picked up; T2 visual gag) | A worker complaint: "Cargo elevator B locked since Tuesday — they say maintenance, but Marcel saw a 'PHANTOM' label" | The villain has rigged a cargo elevator; suggests upper-level interference |
| **Restaurant** | `ds_restaurant_kitchen_memo` | Static prop (chalkboard memo, T2) | "STAFF NOTICE: kitchen staff DO NOT enter Upper Service Corridor 04:00–07:00. Private function. — M." | Restricted Upper-Structure activity at the bomb's eventual disarm hour |
| **Upper structure** | `ds_upper_overheard_radio` | T1 Overheard Banter (guard radio chatter at the catwalk approach) | Radio: "—and tell Hugo the cross-brace is the cross-brace, not the lower truss, I don't care what the schematic says—" | The bomb is on the cross-brace specifically, not the lower truss — last spatial narrowing before bomb chamber |

**Authoring rules**:
- Each Discovery Surface MUST be reachable on the section's main path (not exclusively off-path) — the patient observer doesn't need to scour every corner to find at least one clue.
- Discovery Surfaces MUST NOT be UI elements (no quest journal entry, no banner, no toast). Player extracts the clue by reading / overhearing.
- Multiple Discovery Surfaces per section are permitted; the §C.5.6 BLOCKING CI check is for ≥1, not exactly 1.
- Narrative payload (the actual line text) is narrative-director sign-off territory — current entries are DRAFT placeholders; finalise during narrative sprint.

**Discovery Surface vs Anchor Beat**: §C.6 anchor beats deliver Pillar 1 (comedy) tied to a section's geographic identity; §C.9 Discovery Surfaces deliver Pillar 2 (legibility) tied to spatial deduction toward the bomb. A section may have anchors that double as Discovery Surfaces (Restaurant kitchen memo doubles as T2 environmental gag and as a Discovery Surface) — counted in both catalogs.

### C.7 Interactions with Other Systems

| System | Direction | Contract | Notes |
|--------|-----------|----------|-------|
| **Signal Bus / Events** | MLS publishes | `mission_started(mission_id)`, `mission_completed(mission_id)`, `objective_started(objective_id)`, `objective_completed(objective_id)` | 4 MLS-owned signals per ADR-0002 Mission domain. Emitted synchronously in handler; subscribers run before handler returns. |
| **Signal Bus / Events** | MLS subscribes | `section_entered(section_id, reason: TransitionReason)`, `respawn_triggered(section_id)`, `enemy_killed(enemy, killer)`, `guard_incapacitated(guard, cause)`, `guard_woke_up(guard)`, `alert_state_changed(actor, old, new, severity: StealthAI.Severity)` | Connect in `_ready()`; disconnect with `is_connected` guard in `_exit_tree()` per ADR-0002 IG3. Node-typed payloads call `is_instance_valid()` before dereference per IG4. |
| **Level Streaming Service** | MLS subscribes | `Events.section_entered(id, reason)` — sole emitter is LSS (LS CR-2) | MLS branches on `reason`: FORWARD → autosave ON; RESPAWN / LOAD_FROM_SAVE / NEW_GAME → autosave OFF. MLS does NOT call `LSS.reload_current_section()` directly (F&R + Menu responsibility). MLS MAY call `LSS.register_restore_callback(Callable)` at `_ready()` to receive a `MissionState` sub-resource back on section-load restore. |
| **Save / Load** | MLS writes state | `SaveLoadService.save_to_slot(0, assembled_save: SaveGame)` | Synchronous; only on `section_entered(_, FORWARD)` (CR-12 + CR-15). MLS reads each system's `capture()` / `serialize_state()` to assemble SaveGame. NEVER on RESPAWN / LOAD_FROM_SAVE. No `await` / `call_deferred`. Shared slot 0 with F&R resolved via `SAVING`-state queue (save-load.md L134). |
| **Save / Load** | MLS reads state | Receives `MissionState` sub-resource via LSS step-9 restore callback; calls `self.restore_from(save.mission_state)` | On `section_entered(_, LOAD_FROM_SAVE)`: applies `objectives_completed` + `fired_beats` + `triggers_fired` arrays; suppresses objective_started / beat / trigger re-fires (CR-16). |
| **Failure & Respawn** | MLS subscribes to `respawn_triggered` | `Events.respawn_triggered(section_id)` | No-op from MLS side. MUST NOT emit `Events.*` from within handler (F&R CR-8 re-entrancy fence). MUST NOT call `LSS.reload_current_section()` (F&R owns). MUST NOT call `SaveLoadService.save_to_slot()` (autosave gate CR-12). |
| **Stealth AI** | MLS subscribes | `alert_state_changed(actor, old, new, severity)`, `guard_incapacitated(guard, cause: int)`, `guard_woke_up(guard)` | Zone-objective evaluation: "all guards in zone X neutralized" uses the per-zone group tag (C.5.3 — e.g., `zone_bomb_chamber`) to map guard→zone. `severity == MAJOR` filter optional for MAJOR-only objective triggers. `guard_woke_up` may invalidate "all guards neutralized" if woken guard re-enters zone's active count. |
| **Stealth AI** | MLS calls | `guard.force_alert_state(new_state, AlertCause.SCRIPTED)` for choreography (CR-8, escalation-only) | Per SAI §Interactions. Does NOT propagate (SAI F.4). |
| **Combat & Damage** | MLS subscribes | `enemy_killed(enemy: Node, killer: Node)` | "Eliminate hostiles" objective variants (if authored). `is_instance_valid(enemy)` before dereferencing (node may be freed). |
| **Inventory & Gadgets** | MLS reads state at capture | `Inventory.capture() / serialize_state()` synchronously during SaveGame assembly | Data contract only; no runtime method calls. MLS authors WorldItem caches in level scenes (scene-tree static placements per CR-10). |
| **Player Character** | MLS reads state at capture | `PlayerCharacter.capture()` synchronously during SaveGame assembly | Data contract; no runtime method calls beyond save assembly. |
| **HUD Core** (VS) | MLS publishes (indirect) | Consumes `objective_started(id)`, `objective_completed(id)` via Signal Bus | No direct MLS → HUD call. HUD subscribes independently. MLS provides public `get_active_objectives() -> Array[StringName]` for HUD rebuild on `game_loaded` (CR-16). MLS MUST NOT call HUD methods directly (ADR-0002 anti-pattern). |
| **Cutscenes & Mission Cards** (VS) | MLS publishes (indirect) | Consumes `mission_started`, `mission_completed`, `objective_started`, `objective_completed` via Signal Bus | No new signal needed at MVP (CR-13). Cutscenes checks `MissionState.triggers_fired` / `fired_beats` on `game_loaded` to suppress replay. |
| **Dialogue & Subtitles** (VS) | MLS publishes (indirect) | May subscribe to `objective_started` / `objective_completed` for briefing/confirm barks | No direct MLS → Dialogue call. Briefing bark suppression on LOAD_FROM_SAVE is Dialogue's responsibility (CR-16 contract). |

**Forbidden interactions**:

- No direct MLS → HUD / Audio / Cutscenes / Dialogue / F&R reference (ADR-0002 anti-pattern).
- MLS MUST NOT call `SaveLoadService.save_to_slot()` on RESPAWN / LOAD_FROM_SAVE / NEW_GAME paths (CR-12 absolute).
- MLS MUST NOT call `LSS.reload_current_section()` from `respawn_triggered` handler (F&R CR-8 re-entrancy fence).
- MLS MUST NOT read guard state by direct node-property access (use signal payloads; Inventory CR-17 pattern).

### C.8 Forbidden Patterns (grep CI rules)

| # | Pattern | Scope | Rationale |
|---|---------|-------|-----------|
| **FP-1** | `waypoint\|objective_marker\|minimap_pin\|compass_marker\|map_icon` | `src/`, excluding `tests/` | Pillar 5 absolute (CR-5). |
| **FP-2** | `quest_updated\|objective_complete_banner\|hud_banner\|notification_push` | `src/`, excluding `tests/` | Pillar 5 absolute (CR-5). |
| **FP-3** | `DialogueAnchor.*eve\|eve.*dialogue\|player.*voice_line\|eve_sterling.*line` (case-insensitive) | `src/gameplay/mission/`, `assets/data/missions/` | Pillar 1 absolute (CR-14). |
| **FP-4** | `save_to_slot.*RESPAWN\|RESPAWN.*save_to_slot` + static-analysis lint for any `save_to_slot` reachable from `reason == RESPAWN` | `src/`, excluding `tests/` | Autosave gate (CR-12). |
| **FP-5** | `body_exited` | `src/gameplay/mission/` | Jolt 4.6 non-determinism (CR-6). |
| **FP-6** | `\b(await\|call_deferred)\b` | `src/gameplay/mission/save_assembly*` | Frame-boundary hazard in save pipeline (CR-15). |
| **FP-7** | `NavigationServer3D\.map_get_path\|NavigationServer3D\.map_get_closest_point` | `src/gameplay/mission/` | Main-thread stall on nav worker (CR-20). |
| **FP-8** | Scope-aware grep (function-body-bounded): `Events\.` references inside `func _init():` body of `mission_scripting_service.gd` AND `get_node\(` references inside `func _ready():` body of the same file targeting section-tree paths | `src/gameplay/mission/mission_scripting_service.gd` | ADR-0007 rule 4 (no cross-autoload calls in `_init`); section scene doesn't exist at MLS `_ready` time (CR-17). **OQ-MLS-9 closed as grep-promoted**; tools-programmer must build the scope-aware regex (added to coord item #9). |

## Formulas

### F.1 — Mission COMPLETED gate

The `is_mission_complete` formula is defined as:

`is_mission_complete = ∀ obj ∈ MissionResource.objectives : (obj.required_for_completion == true) ⟹ (MissionState.objective_states[obj.id] == COMPLETED)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Objective set | `MissionResource.objectives` | `Array[MissionObjective]` | 1–20 elements | All objectives declared in the loaded MissionResource |
| Completion flag | `obj.required_for_completion` | `bool` | {true, false} | Whether this objective must complete for mission completion |
| Objective state | `MissionState.objective_states[obj.id]` | `enum` | {PENDING, ACTIVE, COMPLETED} | Runtime state keyed by StringName |
| Result | `is_mission_complete` | `bool` | {true, false} | True only when all required objectives are COMPLETED |

**Output Range:** Boolean. False until all required objectives are COMPLETED; then true permanently (COMPLETED is terminal per CR-2). Re-evaluated synchronously in every `objective_completed` handler. Complexity: O(N) where N = total objective count; MVP N ≤ 10.

**Example:** Mission has 4 objectives: `infiltrate` (required=true, COMPLETED), `disarm_bomb` (required=true, COMPLETED), `exfiltrate` (required=true, COMPLETED), `read_memo` (required=false, PENDING). Result: `true`.

### F.2 — Objective ACTIVE gate

The `can_activate` formula is defined as:

`can_activate(obj) = ∀ id ∈ obj.prereq_objective_ids : MissionState.objective_states[id] == COMPLETED`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Prerequisite list | `obj.prereq_objective_ids` | `Array[StringName]` | 0–5 elements | IDs of objectives that must complete before this one activates |
| Prerequisite state | `MissionState.objective_states[id]` | `enum` | {PENDING, ACTIVE, COMPLETED} | Runtime state at query time |
| Result | `can_activate` | `bool` | {true, false} | True when all prereqs COMPLETED (vacuously true when prereq list is empty) |

**Output Range:** Boolean. Vacuously true for objectives with empty prereq lists — these activate on `mission_started`. Called: (1) at `mission_started` for each objective; (2) after every `objective_completed(id)` for all PENDING objectives listing `id` as a prereq. Complexity: O(P); P ≤ 3 at MVP.

**Example:** `plant_transmitter.prereq_objective_ids = ["reach_restaurant"]`. At `mission_started`, `reach_restaurant` is PENDING → `can_activate = false`. After `objective_completed("reach_restaurant")` → `can_activate = true`. MLS emits `objective_started("plant_transmitter")`.

### F.3 — Alert-Comedy budget (T6 rate limit)

The `remaining_budget` formula is defined as:

`remaining_budget(section_id, alert_state) = max(0, alert_comedy_budget − fires_this_section[section_id][alert_state])`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Per-state budget cap | `alert_comedy_budget` | `int` | 1–5 (tunable, default 2); validated as `> 0` at MissionResource load — negative or zero values `push_error` and clamp to 1 (closes systems-designer finding F.3 negative-budget gap) | Max T6 fires per alert-state per section-life |
| Fire count | `fires_this_section[section_id][alert_state]` | `int` | 0–N | T6 beats fired in current section for this alert state |
| Alert state | `alert_state` | `StealthAI.AlertState` | {SUSPICIOUS, SEARCHING} | Independent budget per alert state. **Terminology corrected per /design-review systems-designer finding F.3**: this is `AlertState`, NOT `Severity` — `Severity` (MINOR/MAJOR) is a separate SAI enum on the `alert_state_changed` payload; T6 keys budget on `new_state` filtered to SUSPICIOUS\|SEARCHING |
| Result | `remaining_budget` | `int` | 0 – `alert_comedy_budget` | Fires still permitted; 0 = T6 silenced for this section + alert_state |

**Output Range:** Integer, clamped to `[0, alert_comedy_budget]`. Resets counter to 0 on `section_entered(id, FORWARD | NEW_GAME)`. Does NOT reset on `section_entered(id, RESPAWN)` — restored from slot-0 `MissionState.fired_beats` per CR-7. When `remaining_budget == 0`, T6 handler returns early without emitting audio/dialogue. **Per-frame burst limit**: see §C.4 T6 burst bound — at most 1 T6 fire per physics frame regardless of N concurrent state changes.

**COMBAT exception**: T6 is **suppressed entirely at COMBAT** (per §C.4 + narrative-director F-5). No budget tracked; T6 handler ignores `alert_state_changed` events where `new == COMBAT`.

**Tuning note**: `alert_comedy_budget` is a §G Tuning Knob. Default 2. Increasing risks audio fatigue if Eve camps a patrol; reducing to 1 silences emergent alert comedy almost entirely.

**Example:** Eve triggers SUSPICIOUS twice in Plaza. First: `remaining_budget = max(0, 2 − 0) = 2`; counter → 1; fires. Second: `remaining_budget = max(0, 2 − 1) = 1`; counter → 2; fires. Third trigger: `remaining_budget = 0`; suppressed.

### F.4 — SaveGame assembly timing budget

The `t_assemble_total` formula is defined as:

`t_assemble_total = Σ t_capture_i + t_disk_io, for i ∈ {Inventory, SAI, F&R, PlayerCharacter, DocumentCollection, MissionScripting}`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Per-system capture time | `t_capture_i` | `float` (ms) | 0.0 – 1.0 ms each (cap) | Wall-time for one system's synchronous `capture()` / `serialize_state()` |
| System count | N | `int` | 6 (fixed at MVP) | Owning systems MLS calls |
| Capture chain total | `t_capture_total` | `float` (ms) | 0.0 – 6.0 ms | Σ `t_capture_i`; with all 6 at cap = 6.0 ms |
| Disk I/O | `t_disk_io` | `float` (ms) | 0.0 – 15.0 ms (HDD worst case) | `SaveLoadService.save_to_slot()` write — atomic tmp+rename + sidecar (see save-load.md) |
| Total assembly time | `t_assemble_total` | `float` (ms) | 0.0 – 21.0 ms (ceiling) | Sum; must complete within the LS 33 ms hard-cut fade window |

**Output Range:** Float, bounded `[0.0, 21.0 ms]` worst case (HDD). **Honest framing per /design-review performance-analyst findings #1, #2**: this synchronous chain runs on the **main thread** during the LS 33 ms snap-out fade. The fade is a renderer-only effect — the game loop is still running. The capture chain therefore consumes the budget of the frame in which it executes; "off the per-frame clock" is rescinded as a misstatement. The 33 ms fade window is the BUDGET the chain must fit inside; on that frame, frame-time is allowed to spike to ≤33 ms (the player sees a fade, so a single long frame is invisible). On any other frame, this code is not running.

**Budget reconciliation** (closes systems-designer + performance-analyst F.4 contradiction): per-system 1.0 ms × 6 systems = 6.0 ms capture chain ceiling (was incorrectly stated as 5.0 ms). Plus disk I/O at 2–15 ms HDD worst case. Combined ceiling 21.0 ms < 33 ms fade window with 12 ms headroom. The per-system 1.0 ms cap is binding; the chain ceiling is derived. Headroom is reserved for ADR-0008 Slot-1 (rendering) which still runs during fade.

**Overflow handling**: if any single `capture()` exceeds 1.0 ms during production profiling, `push_error("MLS: capture(i) exceeded 1.0 ms budget — see ADR-0008 amendment path")` and **proceed with the save** (do NOT abort — losing progress is worse than a slow save). If `t_assemble_total > 33 ms` (fade window), the player will see a perceptible hitch on the section-transition frame; this is a `push_warning` event with a profile-trace dump for tools-programmer follow-up — NOT blocking.

If any `capture()` returns `null`, abort the save entirely and emit `Events.save_failed(SaveLoad.FailureReason.IO_ERROR)` (per CR-15).

**Example:** Inventory 0.4 ms + SAI 0.3 ms + F&R 0.2 ms + PlayerCharacter 0.1 ms + DocumentCollection 0.2 ms + MissionScripting 0.1 ms = `t_capture_total = 1.3 ms`. Plus disk write on SSD ≈ 1.5 ms = `t_assemble_total ≈ 2.8 ms`. On HDD with 8 ms write = `t_assemble_total ≈ 9.3 ms`. Both well under 33 ms fade window.

### F.5 — Supersede-cascade same-frame propagation bound

The `cascade_depth` invariant is defined as:

`cascade_depth(chain) ≤ SUPERSEDE_CASCADE_MAX = 3`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Chain depth | `cascade_depth` | `int` | 0 – SUPERSEDE_CASCADE_MAX | Recursion depth: 0 = direct completer; 1 = its superseded siblings; 2 = siblings of siblings; 3 = maximum permitted |
| Maximum depth | `SUPERSEDE_CASCADE_MAX` | `int` | 3 (constant) | Hard cap; enforced with `push_error` + chain abort |
| Supersedes list | `obj.supersedes` | `Array[StringName]` | 0–N objective IDs | Sibling objectives this objective's completion cancels same-frame |

**Output Range:** Integer invariant. If `cascade_depth` would exceed 3, MLS calls `push_error("MLS: supersede cascade depth exceeded SUPERSEDE_CASCADE_MAX=3 at [obj.id] — chain aborted; depths 1-3 stand (partial supersede)")` and stops propagation. **Partial-supersede on abort**: siblings already completed at depths 1–3 remain COMPLETED (no rollback); any depth-4+ siblings are silently dropped. Rollback is explicitly out of MVP scope. All emissions within the permitted depth occur in the same physics frame per CR-3.

**Rationale for 3-level cap**: prevents cascade storms; keeps alt-route trees shallow for designer comprehension; matches typical NOLF1-era mission-branching depth.

**Example:** Alt-route `scale_exterior` completes (depth 0). Its `supersedes = ["climb_internal_stairs", "bribe_elevator_guard"]` fires at depth 1. `climb_internal_stairs.supersedes = ["pick_lock_3b"]` fires at depth 2. `pick_lock_3b.supersedes = []` — chain terminates naturally at depth 2. If `pick_lock_3b.supersedes = ["call_cipher"]`, depth 3 fires; depth 4 would `push_error` and abort with partial supersede.

### F.6 — WorldItem cache distribution density

The placement policy is expressed as four simultaneous constraints:

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Pistol cap per section | `pistol_per_section_max` | `int` | 1–3 (cap = 3) | No single section > 3 pistol caches |
| Pistol 2-section window floor | `pistol_per_2_section_min` | `int` | 1 (floor) | Every consecutive 2-section window must contain ≥ 1 pistol cache |
| Off-path distance | `off_path_min_distance_m` | `float` (m) | ≥ 10.0 m | Min Euclidean distance from main-path centerline for pistol cache placement |
| Dart span floor | `dart_min_sections_span` | `int` | ≥ 2 sections | Two dart caches must not both be in same section; span ≥ 2 distinct sections |
| Mission totals (hard cap, Inventory-locked) | `pistol_total`, `dart_total`, `medkit_total` | `int` | 8, 2, **7** (medkit raised 3 → 7 per 2026-04-28 GD-B4 decision) | Absolute mission-wide totals (Inventory CR-10) |
| Medkit per-section minimum | `medkit_per_section_min[section_id]` | `Dictionary[StringName, int]` | Plaza 0, Lower 1, Restaurant 1, Upper 2, Bomb 1 (sum = 5 guaranteed) | Added 2026-04-28 per GD-B4 closure — guarantees 5 medkits + 2 off-path bonus = 7 total. Each post-Plaza section MUST contain at least the specified count |

**Output Range:** Constraint satisfaction — placement either passes or fails CI validation. The 2-section window constraint on a 5-section mission produces 4 windows ({1–2, 2–3, 3–4, 4–5}); each requires ≥1 cache. With 8 pistol caches total, always satisfiable. Binding constraint: `pistol_per_section_max = 3`. Mission-total caps are **ADVISORY** in CI (playtest-gated per Inventory OQ-INV-2); rifle-carrier (≤1/section) and mission-gadget (=1 in Restaurant) are **BLOCKING** per §C.5.6.

**Off-path distance authoring**: the `off_path_min_distance_m = 10 m` floor is an **authoring guideline** enforced by level-designer judgement + playtest review. MVP scope does NOT include CI-derived centerline measurement from NavMesh waypoints (nice-to-have deferred).

**Example (valid distribution):** Section 1 (Plaza): 2 pistol. Section 2 (Lower scaffolds): 1. Section 3 (Restaurant): 2. Section 4 (Upper structure): 2. Section 5 (Bomb chamber): 1. Total = 8. 2-section windows: {1–2: 3}, {2–3: 3}, {3–4: 4}, {4–5: 3} — all ≥ 1. Dart caches: 1 in Section 2 (behind a stealth choice), 1 in Section 4. Span = 2 sections.

### F.7 — Trigger single-fire latch invariant

The `trigger_fires` invariant is defined as:

`trigger_fires(trigger_id, section_life) ≤ 1`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Trigger ID | `trigger_id` | `StringName` | non-empty | Unique ID for this MLSTrigger within the section |
| Section life | `section_life` | opaque | one continuous FORWARD entry to next FORWARD or RESPAWN reload | Span over which latch applies |
| Fire count | `trigger_fires` | `int` | 0–1 | Fires in current section life |
| Fired set | `MissionState.triggers_fired` | `Dictionary[StringName, bool]` | keys = fired trigger_ids | Persistent; survives save-load (CR-7) |

**Output Range:** Integer invariant, always 0 or 1. On `body_entered(body)`: (1) check `body.is_in_group("player")`; (2) check `trigger_id not in MissionState.triggers_fired`; (3) call `set_deferred("monitoring", false)` and add `trigger_id` to `triggers_fired` **before the beat body runs**. On `section_entered(RESPAWN)`, `triggers_fired` restored from slot-0 SaveGame — already-fired triggers are latched and do not re-fire. Latch enforced structurally (`monitoring = false` via `set_deferred`) rather than by counter check.

**Example:** Eve walks through `MLSTrigger("t_caterer_monologue")`. Not in `triggers_fired` → fires; `set_deferred("monitoring", false)`; `triggers_fired["t_caterer_monologue"] = true`. Eve respawns. SaveGame restored; `triggers_fired` still contains the id. Eve re-enters — `monitoring` is false, no `body_entered` fires. Beat does not replay.

## Edge Cases

Each edge case names an exact condition + exact resolution. Resolutions are marked **Intended** (explicit design decision), **Defended** (handled by existing CR/FP with citation), or **Deferred** (out of MVP scope; logged as OQ).

### Cluster A — Same-frame signal storms

- **E.1 — Multiple objectives complete in the same frame** (e.g., supersede cascade per CR-3): each `objective_completed(id)` handler runs sequentially via GDScript single-threaded signal dispatch. F.1 mission-complete gate re-evaluated after each emission; first completion to satisfy all `required_for_completion` flags wins; subsequent evaluations are no-ops (COMPLETED is terminal per CR-2). **Defended** by CR-2 + dispatch ordering.
- **E.2 — Last guard killed + MLSTrigger entered same frame**: both signals queue in physics-frame backlog. Dispatch processes in connection order. Each is independent; trigger's `beat_id` latch (F.7) and objective state don't depend on each other. **Intended**: ordering between unrelated handlers is deliberately irrelevant.
- **E.3 — `section_entered(FORWARD)` + `objective_completed` same frame**: CR-15 mandates synchronous SaveGame assembly. MLS `section_entered` handler runs first (it initiates the autosave). If `objective_completed` fires in the same dispatch cycle *after* `section_entered` completes, its state change arrives after SaveGame assembly — that completion is **NOT** captured in slot 0. On subsequent RESPAWN from that slot, the objective restores as ACTIVE. **Intended** + **OQ-MLS-1**: designers MUST NOT author completion triggers co-located with section boundaries. Flag for LD authoring guide.
- **E.4 — `alert_state_changed(COMBAT)` + T6 beat trigger same frame**: T6 COMBAT suppression per F.3 is a filter inside the T6 handler. If COMBAT signal arrives before T6 handler runs, suppression takes effect. If T6 runs first, one beat fires before COMBAT is observed. **Intended**: one-fire case is acceptable (T6 is stateless and emergent). COMBAT filter is best-effort, not a hard lock. No retroactive suppression.
- **E.5 — Supersede cascade in flight while `player_died` fires**: GDScript single-threaded dispatch ensures the cascade completes atomically before `player_died` handler begins. MLS doesn't emit `Events.*` from `respawn_triggered` handler (CR-20 FP-8; F&R CR-8 re-entrancy fence). **Defended** by single-threaded dispatch.

### Cluster B — RESPAWN

- **E.6 — Eve dies mid-T3 animation (4-sec Empty Biscuit Tin)**: MLS records `beat_id` in `MissionState.fired_beats` **before** animation runs (F.7 pattern). On RESPAWN, section scene reloads; NPC resets to idle. `fired_beats` contains the id → T3 does not re-trigger. Partial animation is lost — NPC found in post-beat idle state. **Intended** per CR-7; designer must author a plausible "already-happened" idle pose.
- **E.7 — Eve dies in Restaurant after picking up Parfum**: Inventory captured in slot 0 by F&R on `player_died`. On RESPAWN, Inventory restores from slot 0. If pickup occurred after last FORWARD save, Parfum is in slot 0 and restores; the WorldItem in scene is gone. **Defended** by F&R + Inventory save contracts. No MLS special case.
- **E.8 — Eve dies while MLSTrigger is mid-fade-out (`set_deferred("monitoring", false)` queued)**: `trigger_id` was added to `triggers_fired` synchronously before `set_deferred` (F.7 step 3) — latch is already written in memory. **Critical**: slot 0 was last written at section entry (before this trigger fired); if F&R's dying-state save does NOT include current `triggers_fired`, the beat re-fires on RESPAWN. **OQ-MLS-2**: save/load + F&R coord — confirm F&R's `player_died` capture includes current `MissionState.triggers_fired`.
- **E.9 — RESPAWN while a mission-domain signal handler is executing**: impossible in GDScript single-threaded dispatch. `respawn_triggered` cannot interrupt a running handler. MLS's eventual handler is no-op (C.2 RUNNING→RUNNING). **Defended** by execution model.
- **E.10 — Objective `completion_signal` fires during RESPAWN transition queue**: MLS could spuriously complete an ACTIVE objective pre-section-load. **OQ-MLS-3**: MLS must check `_is_section_live: bool` flag (set true on `section_entered`, false on `respawn_triggered`) and drop completion signals when false. Implementation-level decision.

### Cluster C — Save/Load

- **E.11 — LOAD_FROM_SAVE where saved objective was COMPLETED but scripted beat was NOT fired**: MLS restores `objective_states` (COMPLETED) and `fired_beats` (beat absent). CR-16 suppresses re-emit → T4 beat subscribing to `objective_completed(id)` does NOT fire. Diegetic cue silently skipped. **Intended** per CR-7 + CR-16: beats tied to objective transitions are fresh-activation only. World state must be authored as static "already happened" content for loaded saves.
- **E.12 — Guard dies mid-SaveGame-assembly**: CR-15 is synchronous; `enemy_killed` can't interrupt. But if the guard's node was freed between `Inventory.capture()` and `SAI.capture()`, SAI.capture must snapshot keyed-by-`actor_id` state, not by live node reference. **Cross-system coordination item with SAI**: SAI.capture must be actor_id-keyed.
- **E.13 — Save fails (disk full / write error)**: CR-15 emits `Events.save_failed(IO_ERROR)` and leaves runtime state as-is. Slot 0 untouched per save-load.md atomic-write. No rollback; next FORWARD section entry retries. **Defended** by CR-15 + save-load.md.
- **E.14 — LOAD_FROM_SAVE of slot 0 that F&R wrote in dying-state**: F&R writes slot 0 with a `dying_state: bool` flag per save-load.md. LSS restore callback checks this and reroutes to RESPAWN rather than LOAD_FROM_SAVE. MLS receives `section_entered(RESPAWN)`. **Defended** by LSS restore-callback contract.
- **E.15 — Two saves queued (MLS FORWARD + F9 Quicksave)**: save-load.md `SAVING`-state queue (L134) serializes writes to slot 0. First wins; second waits. Both complete; last-writer (F9) wins slot 0. **Intended**: MLS + F9 capture near-identical state. **Defended** by save-load.md queue contract.

### Cluster D — Section authoring contract violations at runtime

- **E.16 — `player_respawn_point` missing at runtime (CI passed but hotfix reverted)**: F&R CR-11 calls `find_child` → returns null → F&R must `push_error` and fall back to `player_entry_point`. **Deferred**: fallback behavior is F&R's contract; MLS flags as coord item for F&R GDD.
- **E.17 — `SectionBoundsHint` zero-sized or upside-down (inverted AABB)**: LSS streaming logic may misclassify section. **OQ-MLS-4**: add non-zero AABB extents check to §C.5.6 BLOCKING rules.
- **E.18 — Duplicate `actor_id` within a section at runtime (CI missed it)**: SAI uses `actor_id` as state dict key; duplicate causes silent overwrite → corrupted SaveGame. **Intended resolution**: MLS asserts uniqueness across all CharacterBody3D nodes in loaded section during `section_entered(NEW_GAME | LOAD_FROM_SAVE)` with `push_error` + continue. §C.5.6 CI is primary defence; runtime assert is safety net.
- **E.19 — WorldItem count exceeds cap at runtime (designer reverted guard-rail)**: Inventory enforces caps at runtime; excess sits in scene but Inventory refuses pickup once cap hit (emits `pickup_rejected`). **Defended** by Inventory's own cap enforcement.
- **E.20 — Level Designer places `kill_cam_main` node despite forbidden-content list**: §C.5.6 CI grep catches this at push time (BLOCKING). If runtime (CI bypassed), node is inert — no system consumes it. **Defended** by CI + system non-consumption.

### Cluster E — Trigger system / Jolt 4.6

- **E.21 — Eve phases through MLSTrigger due to Jolt high-velocity tunneling**: `body_entered` never fires. For non-critical T1/T3/T5 beats, the miss is acceptable. For T4 beats (objective-signal-driven) tunneling is irrelevant. **OQ-MLS-5**: LD authoring guide must specify narrative-critical beats use signal subscriptions (T4), not Area3D volumes.
- **E.22 — `body_entered` fires after player despawn (respawn race)**: `body` may be freed. MLS must call `is_instance_valid(body)` before `is_in_group` (per ADR-0002 IG4). If invalid, discard silently. **Defended** by ADR-0002 IG4 + CR-6.
- **E.23 — Two MLSTriggers overlap physically; Eve enters both same-frame**: both `body_entered` fire; both have independent latches; both beats fire. If they share audio/AnimationPlayer resources, second may clobber first. **Intended**: designers must not author overlapping triggers with shared resources. Authoring-time constraint; document in LD authoring guide.
- **E.24 — MLSTrigger `monitoring = true` before `section_entered` fires**: §C.5.2 passivity rule is `emit_signal`-focused, doesn't catch `monitoring = true`. **OQ-MLS-6**: MLSTrigger base class must self-enforce passivity in `_ready()` — set `monitoring = false`, wait for `section_entered` before enabling.

### Cluster F — Mission state corruption

- **E.25 — `objective_completed` for already-COMPLETED objective (race)**: handler checks `objective_states[id] == COMPLETED` → idempotent no-op, no re-emit, no push_error. **Defended** by C.3 terminal state.
- **E.26 — MissionObjective authored with `supersedes = [self.id]`**: cascade iteration encounters self-id; COMPLETED terminal check (E.25) returns early → no recursion. **Intended**: `push_error("MLS: objective [id] supersedes itself — entry ignored")` at MissionResource load time.
- **E.27 — `required_for_completion` objective has no reachable activation path**: all prereqs depend on a COMPLETED objective it also supersedes → objective remains PENDING forever → F.1 never satisfied → softlock. **OQ-MLS-7**: no static prereq-graph reachability validator at MVP (post-MVP tooling).
- **E.28 — MLS `_ready()` runs before Events `_ready()` (autoload order violation)**: MLS calls `Events.section_entered.connect(...)` on uninitialized autoload → crash. **Defended** by ADR-0007 load order + CR-17 amendment. Pre-implementation blocking gate.
- **E.29 — `MissionResource` .tres fails to load** (`ResourceLoader.load()` returns null): CR-1 holds `_active_mission == null`; MLS `push_error("MLS: MissionResource failed to load — mission cannot start")` and remains IDLE. Game is in broken state — no mission, no objectives. **OQ-MLS-8**: `mission_load_failed` signal for Main Menu error screen (post-MVP).

### Cluster G — Cross-GDD contracts

- **E.30 — F&R emits `respawn_triggered` while MLS is mid-FORWARD-autosave**: impossible. CR-15 is synchronous; entire `section_entered(FORWARD)` handler completes before any subsequent signal handler can begin. **Defended** by CR-15 + single-threaded dispatch.
- **E.31 — LSS emits `section_entered(FORWARD)` same frame as prior section's `objective_completed`**: `section_entered` processed first (connected first in `_ready()`). FORWARD autosave assembles state before the late completion processes — late completion is not in slot 0. **Same semantic as E.3** (see OQ-MLS-1).
- **E.32 — Dialogue & Subtitles (VS) subscribes to `objective_started` but VS absent at MVP**: `connect` never called by VS; MLS emits into void. GDScript signals with no subscribers emit silently. **Defended** by CR-13 "fire into void" guarantee.
- **E.33 — Cutscenes (VS) subscribes to `mission_completed` but file absent at MVP**: same as E.32. **Defended** by CR-13.

### Cluster H — Autoload lifecycle

- **E.34 — MLS `_init()` tries to read `Events`**: ADR-0007 rule 4 prohibits cross-autoload calls from `_init()`. **Defended** by CR-17 + ADR-0007. FP-8 grep-CI enforcement should extend to catch `Events.` references inside MLS `_init()` body.
- **E.35 — MLS `_ready()` runs before LSS `_ready()` (register_restore_callback on uninit LSS)**: ADR-0007 load order places LSS before MLS. **Defended** by ADR-0007. Pre-implementation gate per CR-17: verify slot assignment in ADR-0007 amendment.
- **E.36 — Game quits mid-scripted-beat (unflushed `fired_beats`)**: beat_id in memory, not yet in slot 0. On next session, beat re-fires. **Intended**: acceptable regression (CR-7's scope is within-session RESPAWN, not cross-session quit). One re-fire on re-entry after a quit is accepted behavior.

## Dependencies

### Upstream dependencies (MLS consumes)

| System / ADR | Hard/Soft | Interface contract | Source |
|--------------|-----------|--------------------|--------|
| **Signal Bus / Events (#1)** | Hard | `Events` autoload; 4 Mission-domain signals emitted; 6 external signals subscribed | ADR-0002 Mission domain L260–272 |
| **Level Streaming Service (#9)** | Hard | `section_entered(id, reason)` subscription (sole emitter); `register_restore_callback(Callable)` for per-section state restore | LS CR-2, CR-6..CR-16 |
| **Save / Load (#6)** | Hard | `SaveLoadService.save_to_slot(0, SaveGame)` synchronous write on FORWARD; synchronous `capture()` reads from all subsystems | save-load.md CR-2, CR-3, L152; ADR-0003 |
| **Failure & Respawn (#14)** | Hard | `respawn_triggered(section_id)` subscription; coord: F&R's dying-state slot-0 save must capture current `MissionState.triggers_fired` (**OQ-MLS-2**) | F&R CR-4, CR-8, CR-11, F&R coord item #11 |
| **Stealth AI (#10)** | Hard | `alert_state_changed(severity)`, `guard_incapacitated(cause)`, `guard_woke_up` subscriptions; `guard.force_alert_state(SCRIPTED)` escalation-only call | SAI §F, CR-8 |
| **Combat & Damage (#11)** | Hard | `enemy_killed(enemy, killer)` subscription for "eliminate" objectives | Combat §F |
| **Player Character (#8)** | Hard | `PlayerCharacter.capture()` read during SaveGame assembly; Marker3D positioning for respawn_point | PC §F, F&R CR-11 |
| **Inventory & Gadgets (#12)** | Hard | `Inventory.capture()` read during SaveGame assembly; WorldItem entity contract (scene-authored, placed per MLS policy) | Inventory CR-7, CR-13, §F |
| **Document Collection (#17)** | Soft (VS) | `DocumentCollection.capture()` read during SaveGame assembly when VS system exists | DC GDD (not yet authored) |
| **Localization Scaffold (#7)** | Hard | `display_name_key: StringName` on MissionObjective resolves via Localization at HUD render time | Localization GDD (pending review) |
| **Audio (#3)** | Soft | MLS emits Mission-domain signals; Audio subscribes for mission stings and section-handoff cues | Audio §Mission domain |

### Downstream dependents (systems that consume MLS)

| System | Interface | Notes |
|--------|-----------|-------|
| **Failure & Respawn (#14)** | Reads `player_respawn_point: Marker3D` from each section scene (MLS-authored); section-validation CI enforces presence (F&R BLOCKING coord item #11) | Bidirectional — F&R depends on MLS-authored section contract AND MLS depends on F&R's `respawn_triggered` signal |
| **HUD Core (#16, VS)** | Subscribes to `objective_started`, `objective_completed`; calls `MLS.get_active_objectives() -> Array[StringName]` on `game_loaded` | No direct MLS→HUD call (CR-13) |
| **Dialogue & Subtitles (#18, VS)** | Subscribes to `objective_started`, `objective_completed` for briefing/confirm barks; must suppress replays on LOAD_FROM_SAVE (CR-16 contract) | VS-tier; absent at MVP — signals fire into void safely |
| **Cutscenes & Mission Cards (#22, VS)** | Subscribes to all 4 Mission-domain signals for card triggers | VS-tier; absent at MVP |
| **HUD State Signaling (#19, VS)** | Subscribes to `alert_state_changed`, `document_collected` (not MLS-owned) | MLS is NOT a direct dependency — HSS reads SAI + Documents |
| **Inventory & Gadgets (#12)** | Inventory's `WorldItem` entities are authored (placed) by MLS across section scenes; `WorldItem.source: mission-level-scripting.md` in registry | Authoring-time dependency (scene-tree static); no runtime call |
| **Stealth AI (#10)** | MLS calls `guard.force_alert_state(SCRIPTED)` for scripted choreography (CR-8) | SAI forward-exposes this API per SAI §Interactions |

### ADR dependencies

| ADR | Status | MLS dependency | Amendment needed? |
|-----|--------|----------------|-------------------|
| **ADR-0001 Stencil ID Contract** | Accepted | MLS-spawned WorldItems + authored guard variants must write stencil tier; MLS reuses registered tiers (no new stencil assignments) | No |
| **ADR-0002 Signal Bus Event Taxonomy** | Accepted (w/ amendment queue) | 4 Mission-domain signals declared + subscriber contracts on 6 signals. MLS will NOT add a 5th signal at MVP (SUPERSEDED is implicit per user decision 2026-04-24) | No (unless OQ-MLS-8 post-MVP adds `mission_load_failed`) |
| **ADR-0003 Save Format Contract** | Accepted | MLS is designated SaveGame assembler on FORWARD path. `MissionState` sub-resource schema: `mission_id`, `objective_states: Dictionary`, `fired_beats: Array[StringName]`, `triggers_fired: Array[StringName]` (or `Dictionary[StringName, bool]` — TBD, see §Open Questions) | **Coord item**: Save/Load GDD + ADR-0003 schema touch-up to formalize `MissionState` sub-resource shape. Confirm F&R's dying-state save captures current `triggers_fired` (**OQ-MLS-2**) |
| **ADR-0006 Collision Layer Contract** | Accepted | `MLSTrigger` Area3D uses the Triggers layer per ADR-0006 | No |
| **ADR-0007 Autoload Load Order Registry** | Accepted (amended 2026-04-27) | MLS registers as autoload `MissionScripting` per ADR-0007 canonical registration table (after `FailureRespawn`, both after `Combat`). Load-order dependency: MLS subscribes to F&R's `respawn_triggered`, satisfied by the canonical line ordering. | ✅ RESOLVED 2026-04-27 — ADR-0007 amended to register F&R + MLS + SettingsService; B2 from /review-all-gdds 2026-04-27 closed |
| **ADR-0008 Performance Budget Distribution** | Accepted | MLS claims 0.1 ms steady-state from the 0.8 ms residual pool (shared across 6 systems); 0.3 ms peak during SaveGame assembly (off per-frame clock — runs in LS 33 ms fade window) | **Coord item**: document the sub-slot claim in ADR-0008 §Pooled Residual + §G Tuning Knobs |

### Forbidden non-dependencies (things MLS must NOT depend on)

- **NOT HUD Core** directly (CR-13 — signal-only via Events bus per ADR-0002)
- **NOT Audio** directly (CR-13 — signal-only via Events bus)
- **NOT Cutscenes & Mission Cards** directly (CR-13 — signal-only via Events bus)
- **NOT Dialogue & Subtitles** directly (CR-13 — signal-only via Events bus)
- **NOT Civilian AI** directly (emits `alert_state_changed` via SAI contract; MLS subscribes to Events, not CAI)
- **NOT Settings & Accessibility** (MLS has no user-tunable runtime settings)
- **NOT the old ScriptedEventManager pattern** if any — MLS is the authoritative mission-scripting owner (no parallel system allowed per CR-1)

### Pre-implementation coord items (MLS sprint cannot start until these close)

1. ~~**ADR-0007 amendment — MLS autoload at line 9**~~ — ✅ RESOLVED 2026-04-27 (ADR-0007 amended; MLS registered per canonical registration table; B2 from /review-all-gdds 2026-04-27 closed).
2. **ADR-0003 + Save/Load GDD schema touch-up** — formalize `MissionState` sub-resource shape on SaveGame; confirm F&R's `player_died` capture includes `MissionState.triggers_fired` (**OQ-MLS-2**, confirms E.8 resolution).
3. **ADR-0008 §Pooled Residual sub-slot claim** — document MLS's 0.1 ms steady-state + 0.3 ms peak claim.
4. **Signal Bus GDD touch-up** — add MLS's subscriber rows for `alert_state_changed`, `guard_incapacitated`, `guard_woke_up`, `respawn_triggered`, `enemy_killed`, `section_entered` to the L122 handler table.
5. **Inventory GDD bidirectional check** — Inventory's `WorldItem.referenced_by` already lists `mission-level-scripting.md` ✅; confirm Inventory GDD §F reciprocally notes that MLS owns placement policy per CR-10. Touch-up needed.
6. **F&R GDD coord item #11 closure** — F&R's BLOCKING item is the `player_respawn_point: Marker3D` authoring + non-deferred + section-validation CI. This GDD closes that item via CR-9 + §C.5.1 + §C.5.6. F&R coord item #11 can be marked CLOSED on MLS approval.
7. **LSS GDD §Interactions touch-up** — add MLS's `register_restore_callback` consumer row to LSS Interactions table.
8. **Localization Scaffold sign-off** — MissionObjective's `display_name_key: StringName` depends on Localization's string-table mechanism. Review Localization (pending review status) before MLS sprint.
9. **Section-validation CI implementation** — the §C.5.6 BLOCKING rules must be implemented as CI checks before first sprint commits section scenes. Owner: **Tools Programmer** (same as LS surface-tagger plugin).
10. **MLSTrigger self-passivity contract** — implementation-level requirement per OQ-MLS-6. Should MLSTrigger base class be in this GDD's scope or deferred to implementation story?
11. **Cutscenes & Mission Cards (VS) forward API** — CR-13 confirms no 5th Mission-domain signal needed. Cutscenes consumption contract to be verified when that GDD is authored.
12. **Section Authoring Contract extraction** — §C.5 (currently 90+ lines in this GDD) is consumed by 6 systems (MLS, F&R, Inventory, SAI, LSS, Audio) and should be extracted to `design/gdd/section-authoring-contract.md` per /design-review level-designer finding #10 + creative-director approval. **Deferred to a separate skill/session** (per user decision 2026-04-24); blocking for production scaling but not for MLS revision sign-off.
13. **Starting reserve audit (cross-system Inventory)** — /design-review economy-designer finding #1: pistol starts at 40/48 cap; 8 caches ≤24 top-up. Patient stealth player never depletes far enough to feel rewarded — Pillar 2 inert. **Owner**: inventory-gadgets.md amendment (starting reserves OR cache totals); requires playtest evidence per Inventory OQ-INV-2.
14. **ADR-0006 Triggers layer amendment** — /design-review ai-programmer finding #6: ADR-0006 enumerates layers 1–5; CR-6 references a "Triggers" layer that doesn't exist. **Owner**: technical-director; bundle with ADR-0007 + ADR-0002 amendments.
15. **ADR-0006 Jolt 4.6 body_exited citation** — /design-review ai-programmer finding #1: CR-6's body_exited ban cites "Jolt 4.6 non-determinism" without an ADR or engine-reference citation. **Owner**: technical-director adds a Risks-table row to ADR-0006 with the formal Jolt citation OR reframes the rationale.
16. **ADR-0002 alert_state_changed 4-param amendment** — /design-review ai-programmer finding #10: Events.gd currently emits 3-param `alert_state_changed`; T6 subscription expects 4-param `(actor, old, new, severity)`. Frame-zero crash without amendment. **Owner**: signal-bus-author + technical-director (Stealth AI sprint already flagged this).

### Bidirectional consistency check

| Does upstream system's GDD reciprocally list MLS as a consumer? | Status |
|-----------------------------------------------------------------|--------|
| Signal Bus (#1) L122 — ADR-0002 subscriber table | ⚠️ Touch-up needed (coord #4) |
| Level Streaming (#9) §F — LSS → MLS callbacks | ⚠️ Touch-up needed (coord #7) |
| Save / Load (#6) §Interactions L152 | ✅ Already lists MLS as caller |
| Failure & Respawn (#14) §F — F&R subscribes to nothing from MLS (F&R emits `respawn_triggered`, MLS subscribes); F&R consumes MLS-authored section contract | ✅ F&R coord item #11 will close on MLS approval |
| Stealth AI (#10) §Interactions — SAI → MLS via Events | ✅ SAI's public accessors + `force_alert_state(SCRIPTED)` are declared |
| Combat & Damage (#11) §F — Combat → MLS via Events | ✅ Already lists MLS as `enemy_killed` subscriber domain |
| Inventory (#12) §F — Inventory authors WorldItem data contract, MLS places | ⚠️ Minor touch-up recommended (coord #5) |
| Player Character (#8) §F — PC.capture() read by MLS | ⚠️ Touch-up recommended (PC §F may not explicitly list MLS as capture-caller) |
| Document Collection (#17) — not yet authored | N/A (VS dependency) |
| Audio (#3) §Mission domain — handler table | ✅ Already subscribes to MLS Mission-domain signals |

## Tuning Knobs

### G.1 Scripted-moment behaviour

| Knob | Default | Safe range | Extreme behaviour |
|------|---------|------------|-------------------|
| `alert_comedy_budget` (F.3) — T6 fires per alert-severity per section-life | **2** | [1, 5] | <1: T6 silenced entirely (emergent alert comedy disappears). >5: audio fatigue risk if Eve camps a patrol and cycles detection. >10: hard-reject — register lint error. |
| `alert_comedy_suppress_at_combat` (F.3 COMBAT exception) | **true** | {true, false} | false: T6 beats may fire at COMBAT — violates narrative-director F-5 forbidden pattern. **Do not ship false.** |
| `section_threshold_beat_on_forward_only` (T7 rule) | **true** | {true, false} | false: T7 beats would fire on RESPAWN and LOAD_FROM_SAVE — violates CR-7. **Do not ship false.** |

### G.2 SaveGame assembly

| Knob | Default | Safe range | Extreme behaviour |
|------|---------|------------|-------------------|
| `t_capture_i_budget_ms` (F.4 per-system cap) | **1.0 ms** | [0.5, 2.0] | <0.5: unrealistic for Inventory + SAI at Tier 1 content volume. >2.0: violates ADR-0008 residual-pool contract — escalate via amendment. |
| `t_capture_total_ceiling_ms` (F.4 chain ceiling, derived) | **6.0 ms** | [3.0, 12.0] | Derived from per-system × 6. Hard upper bound 12.0 ms (eats half the fade window). |
| `t_assemble_total_ceiling_ms` (F.4 chain + disk I/O) | **21.0 ms** (HDD worst case) | [3.0, 33.0] | <3.0: too tight for 6 systems + disk write. >33.0: exceeds LS fade window — produces visible save-hitch on transition frame; emit profile-trace push_warning. |
| `autosave_on_forward_enabled` (CR-12) | **true** | {true, false} | false: MLS never autosaves → player loses progress on next death → breaks Pillar 3. **Debug-only toggle.** |
| `autosave_on_respawn_enabled` (CR-12 absolute) | **false** | {false} | true: **corrupts F&R anti-farm invariant**. Register lint error; refuse to ship true. |
| `autosave_on_load_enabled` (CR-12 absolute) | **false** | {false} | true: redundant save (load already has state); no harm but wastes I/O. Default stays false. |

### G.3 Cache placement policy (F.6)

| Knob | Default | Safe range | Extreme behaviour |
|------|---------|------------|-------------------|
| `pistol_per_section_max` | **3** | [2, 4] | <2: with 8 mission total across 5 sections and per-2-section ≥1 floor, becomes infeasible. >4: bunching makes early-section pistol-farm viable (counter-Pillar-2). |
| `pistol_per_2_section_min` | **1** | [1, 2] | 0: may leave a 2-section gap where ammo is scarce — softlock risk mid-mission. ≥2: tightens authoring; may be impossible depending on layout. |
| `off_path_min_distance_m` | **10.0 m** | [5.0, 20.0] | <5.0: caches feel on-path (violates Pillar 2 "discovery over speed"). >20.0: caches may be unreachable in tight sections (softlock). |
| `dart_min_sections_span` | **2 sections** | [2] (fixed) | 1: both dart caches in same section — concentration violates Pillar 4 narrative-binding (dart scarcity is a mission-long tension). Not tunable. |
| `medkit_per_section_max` | **2** (raised from 1 — Upper Structure carries 2 per 2026-04-28 GD-B4 decision) | [1, 3] | 0: medkit anywhere except designated midpoints forbidden. >3: opens bunching — > 3 medkits in any one section breaks Pillar 2 scarcity. Per-section MIN is now floor (Plaza 0 / Lower 1 / Restaurant 1 / Upper 2 / Bomb 1 = 5 guaranteed) — 2 off-path bonus medkits placed anywhere post-Plaza per Level Designer judgement. |

### G.4 Supersede cascade

| Knob | Default | Safe range | Extreme behaviour |
|------|---------|------------|-------------------|
| `SUPERSEDE_CASCADE_MAX` (F.5) | **3** | [2, 5] | <2: most alt-route branching becomes infeasible (can't express a 2-deep alt-route chain). >5: cascade storms; author comprehension degrades; longer same-frame propagation. |
| `supersede_abort_rollback_enabled` (F.5) | **false** (partial supersede on abort) | {false} at MVP | true: full rollback on depth-exceeded; significantly more implementation complexity for rare case. Deferred post-MVP. |

### G.5 Inventory-locked content caps (documented here; NOT tunable without Inventory GDD amendment)

These caps are owned by Inventory and reflected in §C.5.4 / §F.6. Listed for designer reference.

| Cap | Value | Locked by |
|-----|-------|-----------|
| `pistol_total` | **8 mission** | Inventory F.6 economy audit (2026-04-24) |
| `dart_total` | **2 mission, off-path only** | Inventory F.6 |
| `medkit_total` | **7 mission** (raised 3 → 7 per 2026-04-28 GD-B4 decision: 5 guaranteed per-section minimum + 2 off-path bonus) | Inventory Coord item #5 + 2026-04-28 GD-B4 |
| `rifle_carrier_max_per_section` | **1** | Inventory CR-1 |
| `mission_gadget_count` (Parfum) | **1 total mission, Restaurant only** | Inventory CR-13 |

Changing any of these requires an Inventory GDD amendment and must propagate to `design/registry/entities.yaml`.

### G.6 Section authoring contract (documented here; NOT runtime-tunable — CI constants)

| Constant | Value | Source |
|----------|-------|--------|
| `fr_checkpoint_marker_node_name` | `"player_respawn_point"` | Registry; F&R CR-11 |
| `player_entry_point_name` | `"player_entry_point"` | This GDD §C.5.1 |
| `section_bounds_hint_name` | `"SectionBoundsHint"` | LS CR-9 + this GDD §C.5.1 |
| `navmesh_region_name` | `"NavMeshRegion"` | This GDD §C.5.1 |
| `ambient_source_prefix` | `"AmbientSource_"` | This GDD §C.5.1 |
| `section_root_group_name` | `"section_root"` | LS CR-9 + this GDD §C.5.1 |

Name changes require CI updates and are high-cost refactors — treat as near-locked.

### G.7 Pillar-1 enforcement toggles (NOT tunable — absolute)

| Knob | Value | Source |
|------|-------|--------|
| `eve_scripted_vo_default` | **false, default disposition (NOT absolute)** | CR-14 (revised 2026-04-24 per /design-review creative-director ruling) — narrative-director may approve up to 2 deadpan reaction lines per mission; FP-3 demoted to advisory |
| `eve_non_verbal_cues_max_per_mission` | **4** | CR-14 amendment; non-VO Eve audio cues (breath, tool-handling) are explicitly authorized — anchored to anim/audio events, not DialogueAnchor |
| `objective_markers_enabled` | **false, absolute** | CR-5 + FP-1 |
| `hud_quest_banners_enabled` | **false, absolute** | CR-5 + FP-2 |
| `minimap_enabled` | **false, absolute** | Pillar 5 anti-pillar |

The Eve-VO entries are now **default dispositions** (overridable by narrative-director sign-off); the Pillar 5 entries remain **absolute rules**. Listed here so designers see the boundary explicitly.

## Visual/Audio Requirements

MLS does not author visual or audio content directly — it **triggers** content authored elsewhere. This section declares what MLS must expose so downstream systems can render / play the right cue at the right time.

### V.1 Mission Cards (VS-tier forward dep — Cutscenes & Mission Cards)

- **MLS expose**: 4 Mission-domain signals (`mission_started`, `mission_completed`, `objective_started`, `objective_completed`) with `mission_id` / `objective_id` StringName payloads.
- **Card art direction** (art-director ownership, specified in Cutscenes & Mission Cards GDD when authored): Saul Bass–influenced 1960s title-card typography, Futura/DIN, Art Bible §Typography. Cards appear on `mission_started` (mission briefing card) and per-objective transitions if the designer opts in via `MissionObjective.show_card_on_activate: bool`.
- **MVP scope**: Cards are **VS-tier** — not authored at MVP. MLS fires the signals into void per CR-13 and AC-MLS-9.3. The bomb-disarm mission starts directly in the Plaza with no card at MVP.
- **Outline interaction**: Mission Cards are 2D UI (CanvasLayer) per ADR-0004 UI Framework; no 3D stencil involvement.

### V.2 Section Threshold VFX (LS-owned; MLS triggers only)

- **MLS expose**: `section_entered(id, FORWARD)` subscription fires the T7 Section Threshold Beat. VFX (the 2-frame hard-cut per LS CR-8) is owned by Level Streaming and Post-Process Stack.
- **MLS authoring**: none — the T7 beat body is authored in the destination section scene's MissionResource, typically as a short setup (NPC VO fragment, prop reveal, ambient cue start).
- **Cross-ref**: level-streaming.md §C CR-8 (2-frame hard-cut snap); post-process-stack.md (sepia dim during fade).

### V.3 Scripted-Beat Animation Requirements (Animation system–owned; MLS triggers only)

- **T3 Comedic Choreography** (Empty Biscuit Tin): requires a bespoke 4-second NPC idle-contemplation animation (construction worker opening/holding/closing biscuit tin while looking at Paris skyline).
  - **Cross-ref OQ-MLS-ANIM-1**: animation budget for this beat is unconfirmed. If out of scope, §C.6 Lower scaffolds beat converts to a T1 Overheard Banter fallback with an equivalent joke. Flag for art-director + animator scope review at sprint planning.
- **T4 Objective Reveal Beat** (Fire-Drill Klaxon): no bespoke animation. Uses existing guard idle + radio-holding animation.
- **T7 Section Threshold Beat** (Luggage Tag, bomb chamber): no bespoke animation. Uses Eve's FPS hands idle + bomb static mesh with a small luggage-tag sub-mesh.
- **All NPC banter (T1)**: uses shared NPC "talking" animation from the Dialogue system's authoring library (not MLS's responsibility).

### V.4 Outline Stencil Tier (ADR-0001 compliance)

- **MLS-spawned content**: MLS does NOT spawn runtime content at MVP (CR-10) — WorldItems and guards are scene-authored. Each WorldItem and guard CharacterBody3D must write its stencil tier per ADR-0001:
  - Guards (including per-variant uniforms per CR-19): **Medium tier (2)**.
  - Civilians: **Light tier (3)** by default; **Heaviest tier (1)** at BQA pickup distance only per CR-14 (CivilianAI authoritative; Outline Pipeline ADR-0001 owns the tier mapping).
  - WorldItems (pistol, dart, medkit, Parfum satchel): **Light tier** (Inventory-locked per ADR-0001).
  - Mission-specific props (bomb cylinder in bomb chamber): **Medium tier**.
- **MLS responsibility**: section-authoring CI must verify stencil-writing `material_overlay` is present on every guard + WorldItem + mission prop. Escalate to art-director / technical-artist if a specific mission prop is missing its stencil assignment.

### A.1 Mission-Lifecycle Audio Stings

- **`mission_started` subscriber (Audio)**: plays the mission-briefing sting if VS-tier Mission Cards is present; at MVP, silence (no sting — player starts directly in Plaza per V.1).
- **`mission_completed` subscriber (Audio)**: plays the mission-success sting (credit-roll cue). Composed per Audio GDD §A. This IS in MVP scope — the bomb-disarm mission ends with a sting and returns to Main Menu.
- **Forbidden**: no "QUEST UPDATED" audio cue on `objective_started` / `objective_completed` — per Pillar 5 and CR-5 the audio confirms via **diegetic** sources (klaxons, radio barks, NPC reactions), not UI feedback.

### A.2 Objective-Lifecycle Audio Cues

- **`objective_started` / `objective_completed` subscribers (Audio, Dialogue)**: Audio subscribes for optional subtle stings (per Audio GDD mission-domain handler table). Dialogue subscribes for briefing/confirm barks routed through NPC `DialogueAnchor` nodes (never Eve).
- **LOAD_FROM_SAVE suppression**: per CR-16, MLS does NOT re-emit `objective_started` on LOAD_FROM_SAVE — Dialogue's briefing barks will therefore NOT replay on load. This is a contract Dialogue must respect (cross-ref AC-MLS-11.3).

### A.3 Scripted-Beat Audio Hooks (per T1–T7 taxonomy)

- **T1 Overheard Banter**: pre-recorded VO authored on NPC DialogueAnchor nodes. Audio routing: Dialogue bus. Spatial: 3D-positional with ~15 m falloff.
- **T2 Environmental Gag**: static prop — no audio required (the comedy is visual-only).
- **T3 Comedic Choreography**: incidental SFX (biscuit-tin lid metal-on-metal close, shoe on girder). Audio authored on NPC-local `AudioStreamPlayer3D`.
- **T4 Objective Reveal Beat** (Fire-Drill Klaxon): the Tower service klaxon is a mission-scripted environmental audio layer. Spec: continuous 110 Hz industrial-bell loop with 3-second fade-in starting on `objective_started("disarm_bomb")`; duration 8 seconds; distance-weighted attenuation (audible throughout Upper Structure and Bomb chamber). Cross-ref Audio GDD A.3.
- **T5 Mission-Gadget Beat** (Parfum): one-shot courier VO (pre-recorded, ~12 seconds) on a Restaurant private-dining `AudioStreamPlayer3D`; door-slam SFX cuts the VO. Audio routing: Dialogue bus.
- **T6 Alert-State Comedy**: pre-recorded VO per SUSPICIOUS/SEARCHING severity × per-section variant. F.3 budget: 2 per severity per section-life. Audio bus: Dialogue.
- **T7 Section Threshold Beat** (Luggage Tag, bomb chamber): no VO at beat entry — **deliberate silence**. A single offscreen guard voice floats up the maintenance shaft (~2 seconds, distance-attenuated) on a 1-second delay after `section_entered(FORWARD)` fires. Audio routing: Dialogue bus.

### A.4 Section-Transition Audio Handoff (Audio-owned; MLS subscribes indirectly)

- **Per Audio GDD**: Audio subscribes to `section_entered(id, reason)` and handles music-stem crossfade per section. MLS does NOT interact with music routing directly — music is Audio's domain.
- **Respawn silence fade per F&R**: Audio's sting-suppression on respawn path (F&R Audio GDD amendment coord) is already handled by Audio's subscriber; MLS has no role.

### A.5 Pre-implementation audio gate (Audio GDD coord item — new)

Audio GDD must:

1. **Confirm `objective_started` / `objective_completed` handler-table rows** are present with LOAD_FROM_SAVE suppression compliance (cross-ref CR-16). MVP allows Audio to suppress barks on `game_loaded` independently, but the contract is owned here.
2. **Add T4 Fire-Drill Klaxon** as a mission-scripted environmental audio cue with the 3-sec fade-in + 8-sec duration spec.
3. **Add T6 Alert-State Comedy bark bank** — SUSPICIOUS/SEARCHING × per-section variant (5 sections × 2 severities = 10 barks minimum for Tier 1; Plaza already drafted in §C.6).

**📌 Asset Spec Flag** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:mission-level-scripting` to produce per-asset visual descriptions, dimensions, and generation prompts for: the Parfum satchel (cobalt glass bottle + gold atomizer + "Nuit de PHANTOM" label), the bomb cylinder (brushed-steel hatbox-sized with PHANTOM luggage tag), per-section comedic props (Plaza postcard-of-the-Louvre, Lower scaffolds biscuit tin, Restaurant kitchen chalkboard, Upper structure klaxon housing).

## UI Requirements

MLS's MVP UI footprint is **zero**. All objective surfaces are VS-tier forward dependencies.

1. **MVP scope — No UI** (Pillar 5 absolute): no objective log, no quest log, no mission-title banner, no "QUEST UPDATED" toast, no minimap, no objective markers in world.
2. **VS-tier forward dependencies** (authored when those GDDs land):
   - **HUD Core (#16)** — consumes `objective_started` / `objective_completed` via Events; calls `MLS.get_active_objectives() -> Array[StringName]` on `game_loaded`.
   - **Cutscenes & Mission Cards (#22)** — consumes all 4 Mission-domain signals; renders mission briefing card on `mission_started`, optional per-objective activation card.
   - **Dialogue & Subtitles (#18)** — consumes `objective_started` / `objective_completed` for briefing / confirm barks.
3. **Public API MLS must expose** for VS-tier UI consumers:
   - `get_active_objectives() -> Array[StringName]` — currently ACTIVE objective IDs
   - `get_objective_display_name_key(id: StringName) -> StringName` — Localization key
   - `is_mission_running() -> bool` — convenience
   - `get_mission_id() -> StringName` — for cutscene / card filtering
4. **Accessibility** (for VS tier): MLS itself has no runtime accessibility behavior at MVP; future UI layers inherit Settings & Accessibility flags (subtitles-on default, high-contrast option) from those systems.

**📌 UX Flag — Mission & Level Scripting**: MLS exposes no UI at MVP; when HUD Core / Cutscenes & Mission Cards / Dialogue GDDs are authored (VS tier), run `/ux-design` to create UX specs for the objective surface + mission-card screens before writing epics. Note this in the systems-index row for this system.

## Acceptance Criteria

63 ACs across 14 groups (post-/design-review revision 2026-04-24). Each tagged by story-type per CLAUDE.md Testing Standards: **Logic** (unit test, BLOCKING), **Integration** (integration test or documented playtest, BLOCKING), **Visual/Feel** (screenshot + lead sign-off, ADVISORY), **UI** (manual walkthrough, ADVISORY), **Config/Data** (smoke check, ADVISORY).

### Group 1 — Mission State Machine (CR-1, CR-2, F.1)

- **AC-MLS-1.1** [Logic] [BLOCKING]: **GIVEN** MLS is IDLE and `_active_mission == null`, **WHEN** `section_entered(section_id, NEW_GAME)` fires, **THEN** MLS loads the `MissionResource`, emits `Events.mission_started(mission_id)`, and transitions to RUNNING within the same handler frame; `_active_mission != null` afterward. Evidence: `tests/unit/mission/mission_state_machine_test.gd`.
- **AC-MLS-1.2** [Logic] [BLOCKING]: **GIVEN** MLS is RUNNING with 3 objectives (2 `required_for_completion=true` both COMPLETED; 1 `required_for_completion=false` PENDING), **WHEN** F.1 evaluates in the `objective_completed` handler, **THEN** `is_mission_complete` returns `true`, MLS emits `Events.mission_completed(mission_id)`, state transitions to COMPLETED (terminal). Evidence: `tests/unit/mission/mission_state_machine_test.gd`.
- **AC-MLS-1.3** [Logic] [BLOCKING]: **GIVEN** MLS is RUNNING, **WHEN** a second `section_entered(_, NEW_GAME)` fires with `_active_mission != null`, **THEN** MLS calls `push_error` and drops the request; existing mission state unchanged; no `mission_started` re-emit. Evidence: `tests/unit/mission/mission_state_machine_test.gd`.
- **AC-MLS-1.4** [Logic] [BLOCKING]: **GIVEN** MLS is COMPLETED (terminal), **WHEN** a late `objective_completed` arrives, **THEN** MLS ignores it — no state transition, no re-emit, no `push_error`. Evidence: `tests/unit/mission/mission_state_machine_test.gd`.

### Group 2 — Objective State Machine (CR-3, CR-4, F.2)

- **AC-MLS-2.1** [Logic] [BLOCKING]: **GIVEN** MLS is RUNNING and objective `A` has `prereq_objective_ids = []`, **WHEN** `mission_started` fires, **THEN** F.2 `can_activate(A) = true` vacuously, MLS transitions `A` from PENDING to ACTIVE, emits `Events.objective_started("A")`. Evidence: `tests/unit/mission/objective_state_machine_test.gd`.
- **AC-MLS-2.2** [Logic] [BLOCKING]: **GIVEN** objective `B` has `prereq_objective_ids = ["A"]` and `A` is PENDING, **WHEN** `objective_completed("A")` fires and MLS re-evaluates F.2 for all PENDING, **THEN** `can_activate(B) = true`, MLS transitions `B` to ACTIVE, emits `Events.objective_started("B")`. Evidence: `tests/unit/mission/objective_state_machine_test.gd`.
- **AC-MLS-2.3** [Logic] [BLOCKING]: **GIVEN** an ACTIVE objective with `completion_signal = document_collected` + matching `completion_filter`, **WHEN** `document_collected` fires and the filter returns `true`, **THEN** MLS emits `objective_completed(id)`, unsubscribes from `completion_signal`, sets `objective_states[id] = COMPLETED` — no "press F" interaction, no UI counter. Evidence: `tests/unit/mission/objective_state_machine_test.gd`.
- **AC-MLS-2.4** [Logic] [BLOCKING]: **GIVEN** objective `C` in COMPLETED, **WHEN** its `completion_signal` fires again (race), **THEN** handler detects `objective_states["C"] == COMPLETED` and performs idempotent no-op: no re-emit, no `push_error`. Evidence: `tests/unit/mission/objective_state_machine_test.gd`.
- **AC-MLS-2.5** [Logic] [BLOCKING]: **GIVEN** a fresh NEW_GAME with 4 objectives (N=4), **WHEN** F.1 evaluates after the two required objectives COMPLETE (2 optional remain PENDING), **THEN** `is_mission_complete = true`. Confirms F.1 universal quantifier applies to required objectives only; O(N) with N ≤ 10. Evidence: `tests/unit/mission/mission_state_machine_test.gd`.
- **AC-MLS-2.6** [Logic] [BLOCKING]: **GIVEN** a `MissionResource` whose objectives form a prereq cycle (A.prereqs=[B], B.prereqs=[A]) OR include a self-prereq (`prereq_objective_ids.has(self.objective_id)`), **WHEN** `mission_started` fires and CR-18 load-time validation runs, **THEN** MLS calls `push_error("MLS: prereq cycle detected at [obj.id]")` and remains IDLE; mission does NOT transition to RUNNING. Closes /design-review systems-designer F.2 cycle-softlock gap. Evidence: `tests/unit/mission/mission_resource_validation_test.gd`.
- **AC-MLS-2.7** [Logic] [BLOCKING]: **GIVEN** a `MissionResource` with empty `objectives` array OR `objectives` with all `required_for_completion = false`, **WHEN** `mission_started` fires and CR-18 load-time validation runs, **THEN** MLS calls `push_error("MLS: MissionResource has no required objectives — mission cannot complete")` and remains IDLE. Closes /design-review systems-designer F.1 vacuous-truth phantom-completion gap. Evidence: `tests/unit/mission/mission_resource_validation_test.gd`.

### Group 3 — Pillar 5 Absolutes: No Waypoints / Banners / Minimap (CR-5)

- **AC-MLS-3.1** [Logic] [BLOCKING]: **GIVEN** CI grep for FP-1 (`waypoint|objective_marker|minimap_pin|compass_marker|map_icon`) runs on `src/` (excluding `tests/`), **WHEN** any MLS file is pushed, **THEN** grep exits 1 on match (blocking build); zero matches → exit 0. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.
- **AC-MLS-3.2** [Logic] [BLOCKING]: **GIVEN** CI grep for FP-2 (`quest_updated|objective_complete_banner|hud_banner|notification_push`) runs on `src/`, **WHEN** any such string is in MLS source files, **THEN** build fails exit 1 + reports file + line. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.
- **AC-MLS-3.3** [Logic] [BLOCKING]: **GIVEN** a `MissionObjective` completes and MLS emits `objective_completed(id)` in a unit-test harness with a spy on the `Events` bus, **WHEN** the handler chain runs to completion, **THEN** the spy records zero calls in the same handler frame to any symbol matching `waypoint|objective_marker|minimap_pin|compass_marker|map_icon|quest_updated|objective_complete_banner|hud_banner|notification_push`. Replaces ambiguous "5s post-emission" wall-clock language per /design-review qa-lead rewrite. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.

### Group 4 — Trigger System: Area3D Single-Fire, No body_exited (CR-6, F.7, E.21–E.24)

- **AC-MLS-4.1** [Logic] [BLOCKING]: **GIVEN** an `MLSTrigger` with `one_shot = true`, `trigger_id = "t_caterer_monologue"`, empty `triggers_fired`, **WHEN** the player body enters the Area3D and `body_entered` fires, **THEN** trigger: (1) checks `body.is_in_group("player")`; (2) adds `trigger_id` to `MissionState.triggers_fired` synchronously; (3) calls `set_deferred("monitoring", false)`; (4) a second entry to the same volume in the same section life fires no additional beat. Evidence: `tests/unit/mission/mls_trigger_test.gd`.
- **AC-MLS-4.2** [Logic] [BLOCKING]: **GIVEN** CI grep for FP-5 (`body_exited`) runs against `src/gameplay/mission/`, **WHEN** any MLS file is pushed, **THEN** build fails if `body_exited` appears subscribed in that directory; zero matches → exit 0. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.
- **AC-MLS-4.3** [Logic] [BLOCKING]: **GIVEN** an `MLSTrigger` for a T1 beat exists in a section, **WHEN** no `body_entered` event fires for that trigger during the entire section life (simulating Jolt high-velocity tunneling per E.21), **THEN** MLS completes the section normally — `section_entered(FORWARD)` exit fires, autosave executes, no `push_error` logged, no recovery attempt; the beat is silently missed (acceptable). Replaces non-deterministic Jolt-reproduction language per /design-review qa-lead rewrite. Evidence: `tests/unit/mission/mls_trigger_test.gd`.
- **AC-MLS-4.4** [Logic] [BLOCKING]: **GIVEN** `body_entered` fires for a body that has since been freed (post-despawn race per E.22), **WHEN** MLS processes the callback, **THEN** `is_instance_valid(body)` is called before `body.is_in_group("player")`; callback returns silently if invalid. Evidence: `tests/unit/mission/mls_trigger_test.gd`.

### Group 5 — Scripted Beat Lifecycle: Savepoint-Persistent, No Re-Fire on RESPAWN (CR-7, T1–T7)

- **AC-MLS-5.1** [Logic] [BLOCKING]: **GIVEN** a T1 beat `beat_id = "t1_plaque_debate"` has fired and its ID is in `MissionState.fired_beats`, **WHEN** player dies and `section_entered(section_id, RESPAWN)` fires, **THEN** `fired_beats` restored from slot-0; T1's `MLSTrigger` has `monitoring = false`; beat does not replay in respawned section life. Evidence: `tests/unit/mission/beat_lifecycle_test.gd`.
- **AC-MLS-5.2** [Visual/Feel] [ADVISORY]: **GIVEN** a T2 Environmental Gag (Restaurant kitchen chalkboard), **WHEN** QA enters the Restaurant in any entry mode, **THEN** static prop is present AND text is **legible** (definition: readable at 2.0 m from the default approach vector, under authored ambient lighting with the comic-book outline shader active, text rendering ≥48 pt equivalent at 1080p — closes /design-review qa-lead AC-MLS-5.2 ambiguity); no `beat_id` recorded; no `fired_beats` entry for T2 content. Evidence: `production/qa/evidence/t2_environmental_gag_walkthrough.md`.
- **AC-MLS-5.3** [Logic] [BLOCKING]: **GIVEN** a T1 Overheard Banter beat in Lower Scaffolds (per /design-review §C.6 Biscuit Tin → Foreman's Lunch Inventory conversion; was T3) whose `beat_id` was written to `fired_beats` before the VO began, **WHEN** player dies mid-VO and respawns, **THEN** on re-entry T1 does not re-trigger; foreman/apprentice in post-beat idle state; no partial VO replay. Evidence: `tests/unit/mission/beat_lifecycle_test.gd`.
- **AC-MLS-5.4** [Logic] [BLOCKING]: **GIVEN** a T6 Alert-State Comedy with F.3 budget = 2 per severity, **WHEN** player triggers SUSPICIOUS three times in same section without FORWARD transition, **THEN** beat fires on first two (budget consumed), third silently suppressed (`remaining_budget = 0`); no error logged. Evidence: `tests/unit/mission/beat_lifecycle_test.gd`.
- **AC-MLS-5.5** [Logic] [BLOCKING]: **GIVEN** a T7 Section Threshold Beat subscribed to `section_entered(id, FORWARD)`, **WHEN** `section_entered(id, RESPAWN)` fires for the same section, **THEN** T7 handler does not execute; beat fires exclusively on FORWARD, confirming `section_threshold_beat_on_forward_only = true`. Evidence: `tests/unit/mission/beat_lifecycle_test.gd`.

### Group 6 — Section Authoring Contract + CI Rules (CR-9, §C.5, §C.5.6)

- **AC-MLS-6.1** [Logic] [BLOCKING]: **GIVEN** a section `.tscn` is pushed to `res://scenes/sections/`, **WHEN** CI `find_child("player_respawn_point", true, false)` runs, **THEN** build fails exit 1 if no `Marker3D` with that name found; valid section → exit 0. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.
- **AC-MLS-6.2** [Logic] [BLOCKING]: **GIVEN** a section scene has `entry_point` and `respawn_point` NodePath exports, **WHEN** CI distinct-instance check runs in debug, **THEN** `get_node(entry_point) != get_node(respawn_point)` asserts `true`; co-pointing NodePaths → build fails. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.
- **AC-MLS-6.3** [Logic] [BLOCKING]: **GIVEN** a section scene's `section_id` StringName export, **WHEN** CI validates against `section_registry.tres`, **THEN** build fails if `section_id` not a key in registry. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.
- **AC-MLS-6.4** [Logic] [BLOCKING]: **GIVEN** two `CharacterBody3D` nodes in same section share `actor_id`, **WHEN** CI uniqueness check runs, **THEN** build fails exit 1 + names both conflicting actors. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.
- **AC-MLS-6.5** [Logic] [BLOCKING]: **GIVEN** a section-scene script contains `emit_signal` inside `_ready()` or `_enter_tree()`, **WHEN** passivity grep-CI runs, **THEN** build fails; clean scripts → pass. Confirms section is passive until `section_entered` fires. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.
- **AC-MLS-6.6** [Logic] [BLOCKING]: **GIVEN** a section scene contains nodes named `kill_cam_main`, `ObjectiveMarker_A`, or `MinimapIcon_B`, **WHEN** forbidden-node-name grep-CI runs, **THEN** build fails exit 1; clean section → pass. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.

### Group 7 — WorldItem Cache Placement Policy (CR-10, §C.5.4, F.6)

- **AC-MLS-7.1** [Config/Data] [ADVISORY]: **GIVEN** 5-section scene set is authored, **WHEN** CI pistol-cache counter runs across sections, **THEN** total `WorldItem[item_id="pistol_ammo"]` ≤ 8 mission-wide; any section with >3 pistol caches fails CI independently. Evidence: `production/qa/smoke-2026-04-24.md`.
- **AC-MLS-7.2** [Config/Data] [ADVISORY]: **GIVEN** 2 dart-ammo placements, **WHEN** CI validates distribution, **THEN** both in distinct sections (span ≥ 2), neither on main-path centerline, each behind ≥1 stealth-required choice point (level-designer sign-off). Evidence: `production/qa/smoke-2026-04-24.md`.
- **AC-MLS-7.3** [Config/Data] [ADVISORY] *(revised 2026-04-28 per GD-B4 decision — medkit cap 3 → 7)*: **GIVEN** 7 medkit placements (5 guaranteed: Lower 1 / Restaurant 1 / Upper 2 / Bomb 1 + 2 off-path bonus), **WHEN** QA walks each section and logs positions, **THEN** Plaza has 0 medkits; Lower ≥1; Restaurant ≥1; Upper ≥2; Bomb ≥1; no section has >3 medkits (max cap raised 1 → 3); each guaranteed medkit at section midpoint; off-path bonus medkits ≥10 m off main-path centerline; none in combat-committed zones. Evidence: `production/qa/smoke-[date].md`.
- **AC-MLS-7.4** [Logic] [BLOCKING]: **GIVEN** 5 section scenes authored, **WHEN** CI mission-gadget count check runs, **THEN** exactly 1 `WorldItem[item_id="gadget_mission_pickup"]` (Parfum) exists mission-wide, in Restaurant section's private dining room; any other count or placement → exit 1. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.

### Group 8 — Autosave Gate: Slot 0 on FORWARD Only; Synchronous; No Await (CR-12, CR-15, E.3, E.8, E.30)

- **AC-MLS-8.1** [Logic] [BLOCKING]: **GIVEN** MLS is RUNNING and `section_entered(section_id, FORWARD)` fires, **WHEN** the handler executes, **THEN** MLS calls `capture()` on all 6 owning systems synchronously in same handler frame, assembles SaveGame, calls `SaveLoadService.save_to_slot(0, ...)` — all in single uninterrupted path (no `await`, no `call_deferred`). Evidence: `tests/unit/mission/autosave_gate_test.gd`.
- **AC-MLS-8.2** [Logic] [BLOCKING]: **GIVEN** `section_entered(section_id, RESPAWN)` fires, **WHEN** MLS handler executes, **THEN** `SaveLoadService.save_to_slot()` is NOT called; MissionState restored from slot 0 but no new write. Evidence: `tests/unit/mission/autosave_gate_test.gd`.
- **AC-MLS-8.3** [Logic] [BLOCKING]: **GIVEN** FP-6 grep (`\b(await|call_deferred)\b`) runs against `src/gameplay/mission/save_assembly*`, **WHEN** any save-pipeline file is pushed, **THEN** build fails on match; clean → exit 0. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.
- **AC-MLS-8.4** [Integration] [BLOCKING]: **GIVEN** MLS mid-FORWARD autosave (CR-15 synchronous handler in progress), **WHEN** `respawn_triggered` fires from F&R (E.30), **THEN** the respawn handler does NOT interrupt the FORWARD handler; full SaveGame assembly completes atomically before any subsequent handler begins. Evidence: `tests/integration/mission/autosave_respawn_race_test.gd`.
- **AC-MLS-8.5** [Logic] [BLOCKING]: **GIVEN** any `capture()` call returns `null`, **WHEN** MLS detects the null return, **THEN** MLS emits `Events.save_failed(SaveLoad.FailureReason.IO_ERROR)` and aborts the save (no slot-0 write); subsequent FORWARD transitions retry normally. Evidence: `tests/unit/mission/autosave_gate_test.gd`.

### Group 9 — Mission-Domain Signal Dispatch: 4 Signals, No Direct Calls (CR-13)

- **AC-MLS-9.1** [Integration] [BLOCKING]: **GIVEN** a mission transitions through its lifecycle, **WHEN** QA instruments the `Events` bus and runs NEW_GAME → COMPLETED, **THEN** all 4 Mission-domain signals emit at correct lifecycle moments; none skipped or reordered. Retagged from [Logic] per /design-review qa-lead finding — full lifecycle is integration-scoped. Evidence: `tests/integration/mission/signal_dispatch_integration_test.gd`.
- **AC-MLS-9.2** [Logic] [BLOCKING]: **GIVEN** MLS source files under `src/gameplay/mission/`, **WHEN** code-review CI scans for direct refs to HUD/Audio/Cutscenes/Dialogue node paths or class names, **THEN** zero direct-reference calls found; all interactions via `Events.*`. Evidence: `tests/unit/mission/signal_dispatch_test.gd`.
- **AC-MLS-9.3** [Logic] [BLOCKING]: **GIVEN** VS-tier subscribers absent (pre-VS build), **WHEN** MLS emits `mission_started` / `objective_completed` with no subscribers, **THEN** GDScript emits silently — no error, no crash; mission beat resolves correctly. Evidence: `tests/unit/mission/signal_dispatch_test.gd`.
- **AC-MLS-9.4** [Integration] [BLOCKING]: **GIVEN** a playthrough of one section (integration or documented playtest), **WHEN** a narrative-critical objective completes (e.g., bomb objective in Upper Structure), **THEN** `objective_started` fires, T4 klaxon/guard-radio beat resolves via subscriber chain (Audio receives + plays cue) — no direct MLS→Audio call. Evidence: `tests/integration/mission/signal_dispatch_integration_test.gd`.

### Group 10 — Pillar 1: Eve Silent; All Scripted Dialogue from NPCs (CR-14, FP-3)

- **AC-MLS-10.1** [Logic] [BLOCKING]: **GIVEN** FP-3 grep (case-insensitive `DialogueAnchor.*eve|eve.*dialogue|player.*voice_line|eve_sterling.*line`) runs on `src/gameplay/mission/` + `assets/data/missions/`, **WHEN** any mission file pushed, **THEN** grep exits 1 on match; zero matches → exit 0, confirming no authored Eve dialogue in mission system. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.
- **AC-MLS-10.2** [Config/Data] [ADVISORY]: **GIVEN** all authored `DialogueAnchor` nodes across every section, **WHEN** QA manually inspects each anchor's `speaker_id`, **THEN** no anchor has `speaker_id` referencing Eve Sterling (`"eve"`, `"eve_sterling"`, `"player"`); every line traces to named NPC or environment source. Evidence: `production/qa/evidence/eve_silent_walkthrough.md`.

### Group 11 — LOAD_FROM_SAVE Suppress: objective_started Not Re-Emitted (CR-16, E.11)

- **AC-MLS-11.1** [Logic] [BLOCKING]: **GIVEN** a SaveGame in slot 0 with 2 ACTIVE + 1 COMPLETED objectives, **WHEN** `section_entered(section_id, LOAD_FROM_SAVE)` fires and MLS restores MissionState, **THEN** `Events.objective_started` is NOT emitted for the 2 restored ACTIVE; `mission_started` also suppressed; objective states restored silently. Evidence: `tests/unit/mission/load_from_save_suppress_test.gd`.
- **AC-MLS-11.2** [Integration] [BLOCKING]: **GIVEN** `game_loaded(slot)` fires after LOAD_FROM_SAVE, **WHEN** HUD Core (or test proxy) calls `MLS.get_active_objectives() -> Array[StringName]`, **THEN** returned array contains exactly the IDs in ACTIVE state in the restored snapshot; HUD rebuilds without replaying briefing barks. Evidence: `tests/integration/mission/load_from_save_hud_rebuild_test.gd`.
- **AC-MLS-11.3** [Integration] [BLOCKING]: **GIVEN** a saved game where `disarm_bomb` was ACTIVE at save time, **WHEN** player loads and a Dialogue proxy subscribes to `objective_started`, **THEN** briefing bark for `disarm_bomb` is NOT triggered (signal suppressed); bark fires only on fresh NEW_GAME activation. Evidence: `tests/integration/mission/load_from_save_hud_rebuild_test.gd`.

### Group 12 — Autoload + Forbidden-Pattern Grep CI (CR-17, CR-20, FP-1..FP-8)

- **AC-MLS-12.1** [Logic] [BLOCKING]: **GIVEN** ADR-0007 (amended 2026-04-27) registers `MissionScripting` after `FailureRespawn` per the canonical registration table, **WHEN** game initializes and `MissionScripting._ready()` executes, **THEN** `Events` autoload, `FailureRespawn` autoload, and all preceding autoloads are already initialized; `MissionScripting` connects to `Events.section_entered` + `Events.respawn_triggered` without null-ref crash, confirming load-order correctness. Evidence: `tests/unit/mission/autoload_order_test.gd`.
- **AC-MLS-12.2** [Logic] [BLOCKING]: **GIVEN** CI FP-8 formalized as scope-aware grep for `Events.` references inside `_init()` of `mission_scripting_service.gd`, **WHEN** any `Events.*` call appears in `_init()`, **THEN** build fails; clean `_init()` (cross-autoload setup deferred to `_ready()`) → exit 0. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`. *(OQ-MLS-9 closed 2026-04-24 — FP-8 promoted to grep; tools-programmer owns scope-aware regex implementation per coord item #9.)*
- **AC-MLS-12.3** [Logic] [BLOCKING]: **GIVEN** FP-4 static-analysis lint (`save_to_slot.*RESPAWN|RESPAWN.*save_to_slot`) runs on `src/`, **WHEN** any code path reachable from `reason == RESPAWN` branch calls `save_to_slot`, **THEN** CI reports violation + fails; no such reachable path in compliant code. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.
- **AC-MLS-12.4** [Logic] [BLOCKING]: **GIVEN** FP-7 grep (`NavigationServer3D\.map_get_path|NavigationServer3D\.map_get_closest_point`) runs on `src/gameplay/mission/`, **WHEN** any MLS file pushed, **THEN** build fails if either call appears; absence → exit 0. Evidence: `tests/unit/mission/forbidden_patterns_ci_test.gd`.

### Group 13 — Supersede Cascade + MissionObjective Resource (CR-3, CR-18, F.5, E.26, E.27)

- **AC-MLS-13.1** [Logic] [BLOCKING]: **GIVEN** a `MissionObjective` `.tres` with all required `@export` fields (`objective_id`, `display_name_key`, `prereq_objective_ids`, `completion_signal`, `supersedes`, `required_for_completion`), **WHEN** `ResourceLoader.load()` called at `mission_started`, **THEN** resource loads successfully (non-null); exported fields populated with authored values; missing field → load warning + MLS `push_error`. Evidence: `tests/unit/mission/mission_objective_resource_test.gd`.
- **AC-MLS-13.2** [Logic] [BLOCKING]: **GIVEN** alt-route `scale_exterior` with `supersedes = ["climb_internal_stairs", "bribe_elevator_guard"]`, and `climb_internal_stairs.supersedes = ["pick_lock_3b"]` (cascade depth 2), **WHEN** `scale_exterior` completes, **THEN** all 3 superseded objectives receive `objective_completed` in same physics frame (depth ≤ 3 per F.5); cascade terminates naturally without `push_error`. Evidence: `tests/unit/mission/supersede_cascade_test.gd`.
- **AC-MLS-13.3** [Logic] [BLOCKING]: **GIVEN** a `MissionObjective` authored with `supersedes = [self.id]`, **WHEN** `MissionResource` loaded at `mission_started`, **THEN** MLS calls `push_error("MLS: objective [id] supersedes itself — entry ignored")` and removes self-ref from `supersedes`; objective activates normally without infinite recursion. Evidence: `tests/unit/mission/supersede_cascade_test.gd`.
- **AC-MLS-13.4** [Logic] [BLOCKING]: **GIVEN** a supersede cascade that would exceed depth 3, **WHEN** MLS processes and `cascade_depth` reaches `SUPERSEDE_CASCADE_MAX = 3`, **THEN** MLS calls `push_error("MLS: supersede cascade depth exceeded SUPERSEDE_CASCADE_MAX=3 at [obj.id] — chain aborted; depths 1-3 stand (partial supersede)")`, stops propagation, leaves depth 1–3 completions intact (no rollback). Evidence: `tests/unit/mission/supersede_cascade_test.gd`.

### Group 14 — Coverage gaps from /design-review (CR-8, CR-11, CR-19, CR-21, F.4 timing, T6 burst)

- **AC-MLS-14.1** [Logic] [BLOCKING] (CR-8): **GIVEN** MLS calls `guard.force_alert_state(new_state, AlertCause.SCRIPTED)` where `new_state ≤ guard.current_alert_state`, **WHEN** SAI processes the call, **THEN** SAI rejects de-escalation per its own contract OR MLS's wrapper layer asserts `new_state > guard.current_alert_state` before the call and `push_error`s on violation. Closes /design-review qa-lead CR-8 coverage gap. Evidence: `tests/unit/mission/guard_choreography_test.gd`.
- **AC-MLS-14.2** [Config/Data] [ADVISORY] (CR-11): **GIVEN** every section's authored `peek_surface` and `placeable_surface` `set_meta` tags, **WHEN** the surface-tagger plugin validator runs (`addons/surface_tagger/validate.gd`), **THEN** validator exits 0; sampled QA verifies tags align with the geometric intent (peek surfaces are at wall/door positions; placeable surfaces have up-vector ≥ 0.7). Closes /design-review qa-lead CR-11 coverage gap. Evidence: `production/qa/evidence/surface_tag_audit.md` + `tests/unit/mission/surface_tag_ci_test.gd`.
- **AC-MLS-14.3** [Logic] [BLOCKING] (CR-19): **GIVEN** every CharacterBody3D guard placed in a section scene, **WHEN** CI scans for guard variant authority, **THEN** each guard's scene file must be one of the MLS-owned variant scenes in `res://scenes/actors/guards/variants/` (caterer, custodian, restaurant_staff, foreman, observation_deck_guard, etc.); freelanced standalone CharacterBody3D meshes outside the variant manifest fail CI. Closes /design-review qa-lead CR-19 coverage gap. Evidence: `tests/unit/mission/guard_variant_ci_test.gd`.
- **AC-MLS-14.4** [Logic] [BLOCKING] (CR-21 — Discovery Surfaces): **GIVEN** sections 1–4 are pushed to `res://scenes/sections/`, **WHEN** CI checks `discovery_surface_ids: Array[StringName]` on the section root, **THEN** length ≥ 1 for each of sections 1–4; section 5 (Bomb Chamber) length = 0 permitted. Closes Pillar 2 navigation gap from /design-review BLOCKING #1. Evidence: `tests/unit/mission/section_authoring_ci_test.gd`.
- **AC-MLS-14.5** [Integration] [BLOCKING] (F.4 timing): **GIVEN** the ADR-0008 reference scene (Restaurant kitchen with worst-case actor + WorldItem density), **WHEN** `section_entered(FORWARD)` fires and MLS performs the synchronous capture chain + disk write, **THEN** `t_assemble_total ≤ 21 ms p95` on the minimum-target HDD profile AND ≤ 33 ms p99 (fade window). Closes /design-review performance-analyst finding #10 (no timing AC existed). Evidence: `tests/integration/mission/save_timing_test.gd` + perf trace dump in `production/qa/evidence/save_timing_profile_2026-04-24.md`.
- **AC-MLS-14.6** [Logic] [BLOCKING] (T6 burst limit per §C.4): **GIVEN** SAI propagation flips N ≥ 2 guards from UNAWARE to SUSPICIOUS in the same physics frame, **WHEN** T6 handlers process the N `alert_state_changed` events, **THEN** AT MOST 1 T6 beat fires that frame; remaining N-1 events are dropped (counted toward neither budget nor fire count). Closes /design-review ai-programmer finding #5. Evidence: `tests/unit/mission/t6_burst_limit_test.gd`.
- **AC-MLS-14.7** [Logic] [BLOCKING] (F.7 type ambiguity closure): **GIVEN** `MissionState.triggers_fired` typed as `Dictionary[StringName, bool]`, **WHEN** MLSTrigger checks `trigger_id not in MissionState.triggers_fired`, **THEN** lookup is O(1) average; the check is the FIRST guard in the body_entered handler after `is_instance_valid` (per CR-6 revised step ordering); closing OQ-MLS-12. Evidence: `tests/unit/mission/mls_trigger_test.gd` (existing).
- **AC-MLS-14.8** [Config/Data] [ADVISORY] (CR-14 amendment): **GIVEN** narrative-director-approved Eve VO lines (≤2 per mission) plus non-verbal cues (≤4 per mission), **WHEN** QA reviews the audio bank, **THEN** total Eve-attributed VO lines ≤ 2 AND non-verbal Eve cues ≤ 4 AND each approved line carries narrative-director sign-off in `production/qa/evidence/eve_vo_signoff.md`. Replaces the absolute FP-3 grep gate. Evidence: `production/qa/evidence/eve_vo_signoff.md`.

**AC totals (post-revision 2026-04-24)**: 63 ACs across 14 groups (recount after revision; pre-revision header claimed 50 but actual was 53). Additions: AC-MLS-2.6 (cycle detection BLOCKING), AC-MLS-2.7 (vacuous-truth BLOCKING), AC-MLS-14.1–14.8 (8 new ACs covering CR-8, CR-11, CR-19, CR-21, F.4 timing, T6 burst, F.7 type, CR-14 amendment). **BLOCKING**: 51. **ADVISORY**: 12 (Visual/Feel + Config/Data + pistol/dart/medkit policy soft-gates + new CR-11 + CR-14 amendment).

## Open Questions

13 OQs accumulated across §C / §D / §E / §F / §V-A. Categorized by priority. **Revision pass 2026-04-24 closed OQ-MLS-9 (FP-8 promoted to grep) and OQ-MLS-12 (triggers_fired type closed as Dictionary). Added OQ-MLS-13 (Lower Scaffolds anchor narrative finalisation).**

### Pre-implementation BLOCKING (must resolve before MLS sprint start)

- **OQ-MLS-2** (E.8, §F coord #2): F&R dying-state slot-0 save must capture current `MissionState.triggers_fired`. Without this, MLSTriggers firing between last FORWARD save and `player_died` re-fire on RESPAWN — breaks F.7 single-fire invariant. **Owner**: save/load + F&R GDDs; touch-up required to ADR-0003 + F&R §C.
- **OQ-MLS-3** (E.10): `_is_section_live: bool` guard needed in MLS completion handlers. Prevents spurious objective completion if `completion_signal` fires during RESPAWN transition queue before new section loads. **Owner**: MLS implementation decision — either add a CR (tightens GDD contract) or leave to implementation story. Recommended: promote to CR at sprint-planning time.
- **OQ-MLS-6** (E.24): `MLSTrigger` base class must self-enforce passivity in `_ready()` — set `monitoring = false`, wait for `section_entered` before enabling. Not enforced by current CI. **Owner**: MLS implementation decision — either add a CR or leave to implementation story.
- **OQ-MLS-9** ~~(qa-lead Q5, AC-MLS-12.2)~~: **CLOSED 2026-04-24** — FP-8 promoted to scope-aware grep CI (function-body-bounded regex). AC-MLS-12.2 stands; tools-programmer adds the scope-aware regex implementation (coord item #9 amendment).
- **OQ-MLS-12** ~~(gameplay-programmer Q4)~~: **CLOSED 2026-04-24** — `MissionState.triggers_fired` is `Dictionary[StringName, bool]` (O(1) membership). CR-6 + F.7 + AC-MLS-14.7 reflect this.

### Cross-GDD coordination (not BLOCKING but must propagate before sprint)

Summary of the 12 items from §F Pre-implementation coord items + §A.5 new Audio gate.

| # | Item | Owner |
|---|------|-------|
| 1 | ~~ADR-0007 amendment naming MLS at slot #9~~ ✅ RESOLVED 2026-04-27 (ADR-0007 amended; MLS + F&R + SettingsService registered per canonical table) | technical-director |
| 2 | ADR-0003 + save-load.md schema touch-up for `MissionState` sub-resource; F&R `triggers_fired` capture (OQ-MLS-2) | TD + save-load author |
| 3 | ADR-0008 §Pooled Residual sub-slot claim (0.1 ms steady-state, 0.3 ms peak) | TD |
| 4 | Signal Bus GDD L122 handler-table — add MLS subscriber rows (6 signals) | signal-bus author |
| 5 | Inventory GDD §F — reciprocal note that MLS owns WorldItem placement policy | inventory author |
| 6 | F&R coord item #11 closure (on MLS approval) | F&R author |
| 7 | LSS GDD §Interactions — add MLS `register_restore_callback` consumer row | LSS author |
| 8 | Localization Scaffold review (Designed, pending review) — confirm `display_name_key` StringName contract | localization-lead |
| 9 | Section-validation CI implementation — §C.5.6 BLOCKING rules | tools-programmer |
| 10 | MLSTrigger self-passivity contract (OQ-MLS-6) — GDD vs implementation scope | MLS implementer |
| 11 | Cutscenes & Mission Cards (VS) forward API verification when authored | Cutscenes author (VS) |
| 12 | Audio GDD §Mission-domain amendment (A.5 items: LOAD suppression, T4 klaxon, T6 bark bank) | audio author |

### Deferred / post-MVP

- **OQ-MLS-1** (E.3, E.31): Objective completion same-frame as `section_entered(FORWARD)` lost from autosave. LD authoring-guide constraint: no completion triggers co-located with section boundaries. **Owner**: LD authoring guide (documentation task), not a GDD gate.
- **OQ-MLS-4** (E.17): `SectionBoundsHint` non-zero AABB CI check missing from §C.5.6. Add to BLOCKING CI rules before first LS-dependent playtest. **Owner**: tools-programmer CI story.
- **OQ-MLS-5** (E.21): LD authoring guide must specify narrative-critical beats use T4 (signal subscription), not T1/T3 (Area3D) — Jolt tunneling risks losing T1 triggers on high-velocity traversal. **Owner**: LD authoring-guide documentation task.
- **OQ-MLS-7** (E.27): Unreachable-objective softlock detector. No static prereq-graph reachability validator at MVP. Post-MVP tooling item. **Owner**: tools-programmer (deferred).
- **OQ-MLS-8** (E.29): `mission_load_failed` signal for Main Menu error-screen path when `MissionResource.tres` fails to load. Deferred post-MVP. **Owner**: future ADR-0002 amendment (+5th Mission-domain signal) when Main Menu is authored.
- **OQ-MLS-10** (game-designer Q2): Mission-completed handoff — MLS fires `mission_completed`; who owns credits roll / return-to-Main-Menu? Cutscenes & Mission Cards (VS) or Menu System responsibility? **Owner**: game-designer + producer; resolvable when Cutscenes GDD is authored.
- **OQ-MLS-11** (narrative-director Q4): Restaurant sub-room scope — anchor beat at Parfum pickup only, or do kitchen / main dining each get separate T1/T2 beats? **Owner**: narrative-director + LD, resolvable during Restaurant section authoring sprint.
- **OQ-MLS-13** (creative-director ruling 2026-04-24): Lower Scaffolds anchor beat — currently a DRAFT placeholder T1 ("The Foreman's Lunch Inventory") in §C.6. Final dialogue authoring requires narrative-director sign-off; line is implementable as TBD until narrative sprint. **Owner**: narrative-director + writer; sprint: pre-MVP content authoring.
- **OQ-MLS-ANIM-1** (V.3, narrative Q3) — **OBSOLETE 2026-04-24**: Lower Scaffolds beat converted from T3 (4-sec animation) to T1 placeholder per /design-review creative-director ruling. No bespoke animation required; OQ remains in catalog for historical reference but is no longer blocking. Subsumed by OQ-MLS-13.
