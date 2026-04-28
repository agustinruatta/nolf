# Level Streaming

> **Status**: **Approved 2026-04-21** — `/design-review` MAJOR REVISION NEEDED verdict (23 blockers across 8 specialist domains + creative-director senior synthesis) accepted with inline revision. 23 blockers + 18 advisories resolved inline in same session; user elected to accept revisions without fresh re-review. Implementation gates open: LS-Gate-1 (ADR-0002 amendment), LS-Gate-2 (Input GDD LOADING context), LS-Gate-3 (Audio GDD handler-table amendment), LS-Gate-4 (Save/Load GDD timing annotation). See §Dependencies for gate details.
> **Author**: User + `/design-system` skill + specialists (game-designer, systems-designer, godot-specialist, level-designer, qa-lead, performance-analyst, ux-designer, audio-director) + creative-director (senior synthesis, 2026-04-21 revision pass)
> **Last Updated**: 2026-04-21 (Approved after inline revision pass)
> **Implements Pillar**: Pillar 3 (Stealth is Theatre, Not Punishment — sectional checkpoints + queued-respawn-during-transition make failure a beat, never a swallowed input); Pillar 4 (Iconic Locations as Co-Stars — the Eiffel Tower's geometry IS the level structure); Pillar 5 (Period Authenticity — literal film-cut grammar, 2-frame hard cuts, no modern loading-bar UX)

## Overview

Level Streaming is the scene-swap backbone of *The Paris Affair* — a single `LevelStreamingService` autoload that swaps the active section scene (one of the Eiffel Tower's five sections: Plaza → Lower Scaffolds → Restaurant → Upper Structure → Bomb Chamber) while presenting a **2-frame hard-cut to black** that hides the load and marks the literal film-cut between sections. The service owns four things: (1) the fade overlay (a `CanvasLayer` parented to an autoload, living outside any section scene so cuts survive the swap), (2) the `PackedScene` load + instantiation + teardown, (3) the registered-callback coordination for step-9 caller state restore (a new API added in this revision pass), and (4) the publication of section-lifecycle signals on the Events bus that other systems key off to save, restore state, transition music, and suppress replayed cutscenes.

Architecturally, this system implements the "sectional" half of the save contract locked by **ADR-0003 (Save Format Contract)**: the `section_id: StringName` that Level Streaming emits is the same identifier Save/Load writes to `SaveGame.section_id` and reads back on load. **ADR-0002 (Signal Bus + Event Taxonomy)** defines the canonical `section_entered(section_id)` and `section_exited(section_id)` events that drive the gameplay cycle — **Level Streaming is the sole emitter of both**. The ADR-0002 amendment bundled with this GDD adds a second parameter `reason: TransitionReason` (enum: `FORWARD | RESPAWN | NEW_GAME | LOAD_FROM_SAVE`) to both signals so subscribers can branch audibly/visually/behaviorally without guessing caller intent. Within the swap itself, the service loads one section scene at a time: blocking `PackedScene` instantiation is the MVP contract, explicitly scoped in `systems-index.md` ("async streaming is not required for a 5-section linear mission"). Async `ResourceLoader.load_threaded_*` is documented in §Open Questions as a post-MVP migration path, not a required path. The swap sequence is fixed and now **13 steps** (step 3a added: disconnect LS-owned signals from outgoing scene BEFORE queue_free): `disconnect → hard cut → free old → load new → instantiate → register-callback restore → emit entered → hard cut in`. No in-flight timers, tweens, or awaiting coroutines bleed across the section boundary.

Player-experience-wise, the cut is the product. Per Pillar 5 (Period Authenticity) and Pillar 3 (Stealth is Theatre, Not Punishment), the player never sees a loading bar, a percentage, or a "Loading…" string — they see a **2-frame snap to black** (≈33 ms at 60 fps), a brief hold during the load (capped at ~500 ms on min-spec hardware — Intel Iris Xe per ADR-0001), and a **2-frame snap back** into a new room. The black hold IS the cut: the fade isn't a dissolve, it's a film cut with a load hidden inside it. Total transition budget: **≤0.57 s** from `transition_to_section` call to player regaining control. Getting caught in the Restaurant section fails to Restaurant, not to mission start; ascending from Plaza to Lower Scaffolds feels like a literal Saul Bass cut. Level Streaming does NOT own the section scenes themselves (those are level-designer content authored per section scene authoring discipline, including stable `actor_id: StringName` per guard/civilian per ADR-0003), the transition music (Audio's responsibility via its `section_entered` subscription), the save payload assembly (Mission & Level Scripting's responsibility), or the kill-plane Y value (owned by Player Character; Level Streaming does NOT validate geometry against it — geometry-gap detection is level-designer authoring QA, not a runtime assertion). It owns the swap, the cut, the step-9 restore coordination, and the lifecycle signals.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Effort: `L` (revised up from `M` given registered-callback API surface, queued-respawn logic, ADR-0002 amendment scope-docs, and 4 new ACs) · Key upstream deps: `Save/Load`, `Signal Bus (ADR-0002 amendment)`, `Save Format Contract (ADR-0003)`, `Input (LOADING context)`, `ADR-0006 (collision)` · No dedicated ADR at MVP; a Level Streaming ADR may be spun out if the registered-callback API proves non-trivial during implementation.

## Player Fantasy

Level Streaming's job is simple: **make the transition between Eiffel Tower sections feel like a literal film cut, not a crossfade.** The player wraps up the Plaza, the screen snaps to black in 2 frames, and the Lower Scaffolds snap into view 2 frames later with Eve already in position — the way a 1966 spy film cuts hard from the limousine pulling away to the hero halfway up the trellis. The player isn't *loaded* into the next section; they are *edited* into it. Time and space compress the way cinema compresses them, and Eve arrives exactly where the story needs her.

The fade duration is **not** a stylistic knob — it is locked at **2 frames** (~33 ms at 60 fps) specifically because that is the length of a film cut. A dissolve (the previous 0.3/0.5 s spec) implied *passage of time* or *dreamlike transition* in film grammar — neither of which is the intent. A hard cut with a black hold IS the cut. This is the senior-director-adjudicated revision of the original spec (2026-04-21) after specialist review identified the previous timing as a dissolve masquerading as a cut.

- **Pillar 5 (Period Authenticity Over Modernization)**: 1965 audiences were fluent in hard cuts. A BQA agent's mission doesn't have a load screen; it has **scenes**, and they cut — hard. No percentage. No "Loading…" text. No loading bar. No dissolve. The snap-black-hold-snap-reveal IS the cut, read by the player the way a cinema-goer reads a match cut.
- **Pillar 3 (Stealth is Theatre, Not Punishment)**: When Eve is caught, the reel doesn't end — it loops back to the top of the take. "Take two, from the top of this section." The scene is redrawn, not abandoned. **A death that arrives during a forward transition is queued**, not swallowed: if the player dies mid-cut, the cut was their death cut, and the system resolves to the checkpoint section at the end of the in-flight transition. Failure is dramatic; failure is never a silently dropped input.
- **Pillar 4 (Iconic Locations as Co-Stars)**: Each of the Eiffel Tower's five sections is a set piece. The cut announces the arrival without ever needing literal text — "next: the Restaurant Level, 22:14" is implied by the geometry, not narrated. The Tower's architecture is the film's sequence; Level Streaming is the editor, and the editor cuts hard.

Reference touchstones: ***Our Man Flint***'s scene transitions (decisive hard blacks, no crossfades), **Saul Bass**'s title-sequence hard cuts (not fades), the self-assured jump cuts of **Matt Helm**'s travel montages. Tone: cinematic, unhurried, self-assured — the game trusts the player to follow the cut the way 1966 audiences trusted a director.

Players never praise Level Streaming by name. They praise the game for **feeling like a film they're starring in**.

## Detailed Design

### Core Rules

**CR-1 — `LevelStreamingService` is an autoload.** Line order per **ADR-0007 (Autoload Load Order Registry)** — `LevelStreamingService` is registered at line 5, after `Events`, `EventLogger`, `SaveLoad`, and `InputContext`. Consuming `InputContext` from `_ready()` is safe because `InputContext` is at line 4 (earlier line → already in the tree when LSS `_ready()` fires; see ADR-0007 §Cross-Autoload Reference Safety). It owns a fade overlay (a `CanvasLayer` with `layer = 127` and a full-screen `ColorRect` at `(0, 0, 0, 0)`) parented as a child of the autoload node at `_ready()`. Because the overlay is parented to the autoload — which is never part of `get_tree().current_scene` — it survives every section swap, the main-menu → gameplay transition, and any future cutscene scene pushes. **Layer value 127 is used (not 128)** because Godot's `CanvasLayer.layer` range is signed 8-bit (−128 to 127); 128 overflows. ErrorFallback uses layer 126 so it renders one layer below the fade overlay. (The max-range claim is flagged as OQ-LS-9 for godot-specialist verification against Godot 4.6 docs before sprint kickoff; if verified max is higher, layers can be rebalanced.) ErrorFallback.tscn is also `preload()`-ed at autoload `_ready()` so that error-path recovery does not incur a disk-read spike on top of an already-failed transition.

**CR-2 — Public API is three surfaces (methods + registration).** Per the caller-assembled pattern (ADR-0003 / Save/Load CR-2), the service does I/O only; callers pre-assemble the `SaveGame` they want restored. Plus a registration API for the step-9 coordination contract:

```gdscript
enum TransitionReason { FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE }

func transition_to_section(section_id: StringName, save_game: SaveGame = null,
    reason: TransitionReason = TransitionReason.FORWARD) -> void
func reload_current_section(save_game: SaveGame) -> void
func register_restore_callback(callback: Callable) -> void
# Test-only hook — flips _registry_valid and bypasses the registry load to enable AC-LS-1.8:
func _simulate_registry_failure() -> void  # @tool / test builds only
# Cache API stub (CR-12 eviction surface — no-op at MVP; API exists so Tier 2 additions don't change the public surface):
func evict_section_from_cache(section_id: StringName) -> void
```

`reload_current_section(save_game)` is a thin facade over `transition_to_section(current_section_id, save_game, reason = TransitionReason.RESPAWN)`. The distinct name is a caller-intent marker for Failure & Respawn; internally it is one code path with a queue-aware early branch (see CR-6).

`register_restore_callback(callback)` is called once per caller at autoload boot (Mission Scripting, Failure & Respawn, Menu System — one callable each). At step 9, LS iterates its registered callbacks synchronously in registration order, passing `(target_section_id: StringName, save_game: SaveGame, reason: TransitionReason)`. Each callback must complete synchronously (no await) before LS proceeds to step 10. This replaces the previous "caller restores state, LS hopes it finishes" hand-wave.

**CR-3 — Section scenes are resolved through a `SectionRegistry` resource.** A `SectionRegistry` at `res://assets/data/section_registry.tres` maps `section_id: StringName → PackedScene path` and `section_id → display_name_loc_key` (for Save/Load's metadata sidecar). LS reads the registry at autoload `_ready()`. The registry is the single authority for "what sections exist in the game"; adding a new section is a registry edit + a `.tscn` file, not a code change. At MVP Tier 0, the registry contains `plaza` + a **stub second section** with the following minimum spec:

- Root node: `Node3D` named `StubSectionRoot`, in group `"section_root"`.
- `@export var section_id: StringName = &"stub_b"` equal to the registry key.
- `@export var player_entry_point: NodePath` pointing to a child `Marker3D` named `EntryPoint` at local origin (0,1.5,0).
- `@export var player_respawn_point: NodePath` pointing to a **distinct** child `Marker3D` named `RespawnPoint` (may be co-located with EntryPoint at MVP — but MUST be a distinct node, see CR-9 authoring rule).
- `@export var section_bounds: AABB` — computed at `_ready()` from a child `MeshInstance3D` named `SectionBoundsHint` (see CR-9 for authoring pattern).
- `@export var environment: Environment` — nullable; stub uses null (global fallback).
- One `StaticBody3D` named `Floor` with a `CollisionShape3D` containing a `BoxShape3D` of `size = Vector3(20, 1, 20)`, positioned at `Y = -0.5`, with `set_meta("surface_tag", &"default")`.

Stub is ~30 nodes total. Ships as `res://scenes/sections/stub_b.tscn`. Its sole purpose is exercising the swap pipeline in integration tests (AC-LS-3.*).

**CR-4 — Only three systems call `transition_to_section`.** Mission & Level Scripting (forward progression), Failure & Respawn (player death → checkpoint reload), and Menu System ("Load Game" → target section). No other system may call LS's public API. This caller-list discipline mirrors Save/Load CR-1 and is enforced by: (a) code review on every PR touching LS, (b) a debug-build `assert(_caller_is_allowlisted(get_stack()))` at the top of `transition_to_section` that inspects the calling script's path and matches against `["mission_scripting", "failure_respawn", "menu_system"]` path fragments (shipping builds skip). Cutscene-triggered transitions (e.g., Restaurant's kitchen explosion cinematic transitioning to Upper Structure) route through Mission & Level Scripting, not through LS directly — Cutscenes signals a mission beat, Mission Scripting fires the transition.

**CR-5 — Swap sequence is a fixed 13-step contract (manual pattern, not `change_scene_to_packed`).** Per godot-specialist review, `change_scene_to_packed` creates a one-frame window where `get_tree().current_scene` is `null` — unacceptable for a service that emits ordered lifecycle signals. The service performs the swap manually. Note: step 7's direct `current_scene` assignment is flagged as OQ-LS-11 pending godot-specialist verification against Godot 4.6 SceneTree invariants before sprint kickoff; if unsafe, the sequence will require a dedicated spike.

```
 1. Push InputContext.LOADING onto the Input context stack.
 2. SNAP overlay ColorRect alpha 0 → 1 over 2 frames (~33 ms @ 60 fps) — await 2× process_frame.
 3. Emit Events.section_exited(outgoing_id, reason) — scene STILL in tree, synchronous subscribers
    read final state. Subscribers MUST be synchronous (no await); see CR-13.
 3a. Disconnect all LS-owned signal connections FROM the outgoing scene (not to it).
    Specifically: any Events.* connections established by LS that point at outgoing scene nodes
    are disconnected here, BEFORE queue_free, to mitigate _exit_tree / tree_exiting signal races.
 4. Pre-check: if not SectionRegistry.has(target_id) → _abort_transition() + push_error, return.
    Then get_tree().current_scene.queue_free(). (Registry check moved BEFORE queue_free so a
    bad target doesn't orphan us in a sceneless state — fixes systems-designer §Edge Cases regression.)
 5. packed := ResourceLoader.load(SectionRegistry.path(target_id)) as PackedScene. Null → _abort_transition.
 6. instance := packed.instantiate(). Null → _abort_transition.
 7. get_tree().root.add_child(instance); get_tree().current_scene = instance  (explicit reassignment;
    see OQ-LS-11 for verification status).
 8. await get_tree().process_frame  (defer one frame to let deferred-call chains propagate — note
    that _ready() itself fires synchronously during add_child(), NOT deferred. The await protects
    against call_deferred() chains inside _ready(), not _ready() itself. Rationale corrected 2026-04-21
    per godot-specialist feedback.)
 9. For each callback in _restore_callbacks (registered via register_restore_callback, CR-2):
    callback.call(target_id, save_game, reason) — SYNCHRONOUS; LS does NOT await. Any callback
    that awaits is a contract violation and is flagged in debug builds via a pre/post-call stack
    timestamp assertion (>1 frame between pre and post → push_error).
10. Emit Events.section_entered(target_id, reason) — state is now guaranteed live.
11. SNAP overlay ColorRect alpha 1 → 0 over 2 frames — await 2× process_frame.
12. Pop InputContext.LOADING.
13. Process _pending_respawn queue (see CR-6): if a respawn call was queued during steps 2–11,
    and player-state is DEAD (or any state the restore callbacks flagged as requiring immediate
    respawn), fire reload_current_section(_pending_respawn_save_game) now from IDLE.
```

Step 9 is where Mission & Level Scripting (or Failure & Respawn, or Menu System) applies the loaded `SaveGame` to each owning system — PC, Inventory, Stealth AI, Document Collection, etc. — each of which must call `duplicate_deep()` per ADR-0003. LS does not hand-roll this itself; it invokes registered callbacks in order and awaits their synchronous completion before emitting `section_entered`. This eliminates the previous "caller runs restore somewhere around step 9 and hopes it finishes before step 10" ordering hazard.

**CR-6 — Queued-respawn during transition (CD-adjudicated revision).** LS maintains a private `_transitioning: bool` and a private `_pending_respawn_save_game: SaveGame = null`. While `_transitioning == true`:

- Additional `transition_to_section` calls are DROPPED with `push_warning` (caller authoring error — two adjacent trigger volumes, Mission Scripting duplicate emit).
- **`reload_current_section(save_game)` is QUEUED**, not dropped: `_pending_respawn_save_game = save_game`. A second queue-while-queued overwrites (last-wins; F&R shouldn't fire twice but if it does, the most recent save slot is authoritative).

At step 13 of the swap sequence, if `_pending_respawn_save_game != null`, LS IMMEDIATELY fires `reload_current_section(_pending_respawn_save_game)` from IDLE — this implements the creative-director adjudication: "If the player died mid-cut, the cut WAS their death cut; resolve to the checkpoint section at the end of the in-flight transition." The player sees: forward transition to new section (complete swap) → 2-frame snap to black → respawn to the checkpoint section of the new section's predecessor. **A death during a transition is never silently swallowed.** Total worst-case time: ~1.14 s (0.57 s forward transition + 0.57 s respawn transition) — still well under the 2 s UX-tolerance threshold for perceived responsiveness.

If, during forward-transition execution, the Failure & Respawn system emits `respawn_triggered(section_id)` (see ADR-0002:183) but does NOT call `reload_current_section` (e.g., F&R is asynchronously assembling the save), LS does not react; LS reacts only to its own public API calls. F&R is responsible for calling `reload_current_section` after its save assembly completes.

**CR-7 — Fresh game boot: the main menu is its own scene (not in the registry).** `MainMenu.tscn` is loaded by `get_tree().change_scene_to_file()` at application startup — bypassing LS because the menu is not a section. On "New Game," Menu System calls `LS.transition_to_section(first_section_id, null, TransitionReason.NEW_GAME)`. On "Load Game," Menu System first calls `SaveLoad.load_from_slot(N)` → receives a `SaveGame` → calls `LS.transition_to_section(loaded_save.section_id, loaded_save, TransitionReason.LOAD_FROM_SAVE)`. Both paths converge at the same LS call but emit distinct `TransitionReason` values so subscribers (Audio, Cutscenes, Mission Scripting) can branch. A null `save_game` is only valid with `reason = NEW_GAME`; combining `save_game = null` with any other `reason` is a debug-build assertion failure.

**CR-8 — Respawn fires the same pipeline as a forward transition, with `reason = TransitionReason.RESPAWN`.** Failure & Respawn calls `LS.reload_current_section(slot_0_save_game)`. LS runs the full 13-step sequence; the `reason = RESPAWN` is propagated to both `section_exited` and `section_entered`. Subscribers differentiate based on the enum:

| Subscriber | `FORWARD` | `RESPAWN` | `NEW_GAME` | `LOAD_FROM_SAVE` |
|---|---|---|---|---|
| Audio | Full music-location crossfade | 2.0 s ease-in from silence | Menu→section handoff (Audio OQ) | Resume-from-save (no ceremony) |
| Cutscenes | First-arrival check vs `MissionState.triggers_fired`; play if not fired | Suppress replay | Suppress | Suppress |
| Mission Scripting | Fire autosave-on-section-entered (write slot 0) | Do NOT autosave (slot 0 already authoritative) | Initialize fresh defaults | Do NOT autosave |

Audio GDD §Mission domain handler table (currently 1-param signatures at lines 188–189) **requires amendment** in the same ADR-0002 pass that adds the `reason` parameter to LS's signals. See §Dependencies for the explicit pre-implementation gate that enumerates all amendment targets — this gate is LS-owned and must not be bundled silently into Stealth AI's gate.

**CR-9 — Section scene authoring contract.** Every section scene's root node MUST satisfy all of the following (enforced by authoring discipline + LS assertion at `_ready()`; no runtime validation in shipping builds):

| Field | Declaration | Purpose |
|---|---|---|
| Root type | `Node3D` or subclass (MUST be spatial) | Ensures `section_bounds` is meaningful in 3D space. LS asserts `root is Node3D` at instantiation. |
| Group membership | `Groups: ["section_root"]` (set in editor) | LS scans for the group after instantiation as an integrity check. |
| `section_id` | `@export var section_id: StringName = &""` | Must equal the SectionRegistry key. LS asserts match at `_ready()`. (`@export const` rejected because `const` values are compile-time fixed — they cannot be assigned per-instance at all, making per-section override impossible. Rationale corrected 2026-04-21 per godot-specialist feedback; conclusion — use `@export var` — unchanged.) |
| `player_entry_point` | `@export var player_entry_point: NodePath` | Points to a `Marker3D` named `EntryPoint`. Mission Scripting reads this to place Eve on fresh arrival. |
| `player_respawn_point` | `@export var player_respawn_point: NodePath` | Points to a **DISTINCT `Marker3D` node named `RespawnPoint`** — even at MVP where it may be co-located with `EntryPoint`, the two NodePaths MUST resolve to different `Marker3D` instances. This prevents the shared-reference footgun when Restaurant and higher sections introduce mid-section checkpoints (Tier 1). LS asserts at `_ready()` that `get_node(player_entry_point) != get_node(player_respawn_point)` in debug builds. |
| `section_bounds` | Computed from `SectionBoundsHint` (a child `MeshInstance3D` with a `BoxMesh`) at `_ready()` | The AABB is derived from `SectionBoundsHint.get_aabb() * SectionBoundsHint.global_transform` at `_ready()`, exposed as a read-only property. Authoring is done visually in the 3D viewport by scaling/positioning the hint mesh — NOT by editing raw AABB floats in the inspector. The hint mesh can be flagged `visible = false` at runtime. If `SectionBoundsHint` is absent, LS falls back to a derived AABB encompassing all `StaticBody3D` children. (Raw `@export var section_bounds: AABB` is supported for programmatic overrides but is not the recommended authoring path — the inspector widget is a 6-field numeric entry with no viewport visualization.) |
| `environment` | `@export var environment: Environment` (nullable) | Per-section sky/fog resource. Exterior sections (Plaza, Upper Structure) = open-sky environment; interior sections (Restaurant) = enclosed-room environment. Nil = LS applies a global fallback. After `section_entered`, LS assigns `environment` (or global fallback) to `get_viewport().get_camera_3d().get_world_3d().environment`. |

Additional scene-discipline rules:
- Every guard / civilian `CharacterBody3D` in the scene MUST export `actor_id: StringName` set to a section-scoped unique value (per ADR-0003).
- The section scene MUST remain **passive** until `section_entered` fires. No signals emitted from `_enter_tree` or `_ready`; no autonomous animations, AI updates, or audio triggers. Mission Scripting is responsible for waking up the section after state restore completes.
- Vertical-climb sections (Plaza → Lower Scaffolds, Lower Scaffolds → Restaurant, etc.) must ensure the predecessor's section-exit trigger Y and the successor's `EntryPoint` Y are within 5 m of each other — this is a Mission Scripting authoring contract, not an LS assertion, but flagged here because it is the most likely footgun.

**CR-10 — Surface metadata authoring (resolves FootstepComponent OQ-FC-1).** Every `StaticBody3D` (or `CollisionObject3D` subclass) that Eve can stand on is tagged at authoring time via `set_meta("surface_tag", StringName)`. FootstepComponent's `ShapeCast3D` / raycast reads `body.get_meta("surface_tag", &"default")` on hit. The authoritative tag vocabulary is owned by **FootstepComponent §Surface Tag Set**; LS consumes that vocabulary for the authoring workflow.

**Multi-shape bodies (known limitation):** `set_meta` lives on the body, not on the shape — a `StaticBody3D` with multiple `CollisionShape3D` children cannot carry per-shape tags with this scheme. Workaround: split the body at authoring time into one body per surface, OR accept the dominant-material wins. Per-shape metadata is a Tier 1 / Tier 2 extension (documented as OQ-LS-12).

**Tool plugin (Tools Programmer owned, Tier 0 deliverable):** A level-designer tool plugin at `res://addons/surface_tagger/` ships at Tier 0 and mass-assigns tags by the body's primary material. Plugin scope:

- **UI mode**: editor dock — select multiple bodies, pick tag from preset dropdown, click "Apply" → calls `set_meta` on each.
- **Mass-assign mode**: scan scene, match body materials against a material→tag mapping, apply automatically, report tagged/skipped counts.
- **Validation mode (CLI / headless)**: `godot --headless --script addons/surface_tagger/validate.gd` — scans every scene in `section_registry.tres`, prints `[untagged body] <scene>:<body_path>` per violation, exits code 0 if all tagged, code 1 if any untagged. This is the `plugin validator` referenced by AC-LS-4.3; AC-LS-4.3 has been moved to FootstepComponent scope per qa-lead review but is cross-referenced here.

**Owner**: Tools Programmer. Surface tagger plugin is an explicit Tier 0 deliverable owned by that agent. If unstaffed at Tier 0, fallback is manual `set_meta` per body (documented in OQ-FC-1 Option A) — LS's authoring workflow contract is satisfied by either path.

Area3D volume overrides are permitted for temporary state (wet carpet after a rain cue, puddle zones). The override Area3D itself carries `set_meta("surface_tag", &"water_puddle")`; FootstepComponent's `get_overlapping_areas()` read is a higher-priority pass before falling back to body meta. This lookup is one additional area check per footstep — ~10 Hz — negligible.

**CR-11 — Cache mode is `ResourceLoader.CACHE_MODE_REUSE` (default) with an explicit eviction API surface.** `ResourceLoader.load(SectionRegistry.path(target_id), "", ResourceLoader.CACHE_MODE_REUSE)` uses Godot's default caching. Re-entering a section (quick death respawn, scrubbing back from Menu) avoids disk I/O — `PackedScene.instantiate()` returns a fresh instance from the cached resource.

Memory eviction is **not yet policy-defined** at MVP — first-visited sections stay cached for the session. However, the public eviction method `evict_section_from_cache(section_id: StringName)` exists at MVP (see CR-2) as a no-op wrapper around `ResourceLoader.has_cached()` + internal cache reference drop, so Tier 1 hardening and Tier 2 expansion can drive an eviction policy without changing the public API surface. (Peak-memory concern documented in §Edge Cases Application Focus Loss + OQ-LS-2.)

**CR-12 — (DELETED) `kill_plane_y` runtime validation removed.** The previous CR-11 assertion (`section_bounds.position.y >= kill_plane_y - 5.0`) was semantically vacuous — it validated a designer-set AABB against a designer-set constant and could not catch geometry-gap fall-throughs (the actual failure mode it was advertised to guard against). Geometry-gap detection is **level-designer authoring QA discipline**, not an LS runtime assertion. LS no longer reads `kill_plane_y` and has no dependency on it. The registry entry `kill_plane_y` retains its `referenced_by` row but LS is removed from that list (cross-reference will be updated in the revision pass entity registry sweep).

**CR-13 — `section_exited` subscribers MUST be synchronous.** No `await`, no deferred calls that depend on the outgoing scene being alive. Subscribers receive the signal, read final state, mutate their own state, and return — all within the step-3 call frame. This rule protects the "scene STILL in tree" guarantee in CR-5 step 3: if a subscriber awaits, control returns to LS, step 3a (disconnect) and step 4 (queue_free) execute, and the suspended subscriber resumes against a dead tree. Subscribers that need asynchronous cleanup MUST spawn their own work on a separate coroutine launched FIRE-AND-FORGET from the synchronous handler — e.g., `_cleanup_later()` called via `call_deferred` — and MUST NOT retain references to outgoing-scene nodes across the coroutine boundary. Debug builds flag contract violations via a pre/post-frame timestamp check in LS around step 3's emit call.

**CR-14 — Same-section no-op guard (shipping).** In shipping builds, `transition_to_section` checks: `if section_id == _current_section_id and reason != TransitionReason.RESPAWN: return early`. This prevents the ~500 ms-wasted-on-redundant-swap case (Mission Scripting authoring bug) from shipping as a silent cost. Debug builds still assert `section_id != _current_section_id || reason == RESPAWN` so the underlying Mission Scripting bug is caught loud.

**CR-15 — Application-focus-loss behavior (`pause_on_focus_lost = true`).** LS requires the project setting `application/run/pause_on_focus_lost = true` (set in `project.godot`). When focus is lost during FADING_OUT or FADING_IN, the scene tree is paused; when focus is regained, the coroutine resumes. On focus regain, LS snaps the overlay alpha to the target value for the current step (1.0 during FADING_OUT+SWAPPING, 0.0 during IDLE) before resuming the coroutine — this prevents the partial-alpha stall UX gap flagged by ux-designer review. If `pause_on_focus_lost` is NOT set, the coroutine continues running unfocused; documented as OQ-LS-10.

### States and Transitions

LS is a thin state machine with four states:

| State | Description | Duration | What It Blocks |
|---|---|---|---|
| `IDLE` | No transition in progress; player has control. Pending-respawn queue may fire from here. | Persistent | Nothing |
| `FADING_OUT` | 2-frame snap-to-black running (alpha 0 → 1) | ~33 ms (2 frames @ 60 fps) | Additional forward `transition_to_section` calls (CR-6 drop); `reload_current_section` is QUEUED, not dropped (CR-6); Save/Load via `InputContext.LOADING` gate; Quicksave F5 / Quickload F9 QUEUED at LS level (see CR-16 below) |
| `SWAPPING` | Signals disconnected (3a), old scene freed, registry check, load, instantiate, `add_child`, restore-callback invocation | 200–500 ms typical | Same as FADING_OUT |
| `FADING_IN` | 2-frame snap-reveal running (alpha 1 → 0) | ~33 ms | Same as FADING_OUT |

Transitions:

- `IDLE → FADING_OUT` on `transition_to_section` call (`_transitioning = true` set atomically with the state change).
- `FADING_OUT → SWAPPING` on 2-frame snap-to-black completion.
- `SWAPPING → FADING_IN` after `section_entered` emit (step 10).
- `FADING_IN → IDLE` on 2-frame snap-reveal completion + `InputContext.LOADING` pop + pending-respawn queue check.

Total transition budget: ~33 ms snap-out + ≤500 ms SWAPPING + ~33 ms snap-in = **≤0.57 s from `transition_to_section` call to player regaining control** (down from the previous 1.3 s dissolve budget). Save/Load's ≤2 ms I/O is hidden inside the SWAPPING state per ADR-0003.

**CR-16 — Queued F5 / F9 during transition.** LS queues Quicksave (F5) and Quickload (F9) presses that arrive during FADING_OUT / SWAPPING / FADING_IN: `_pending_quicksave: bool` and `_pending_quickload_slot: int = -1`. On FADING_IN → IDLE, LS fires the queued action (invokes Save/Load through the normal path). The player hears the save-confirm chime post-transition, not mid-cut. This replaces the previous "silent drop" behavior flagged by ux-designer as creating a state-divergence UX. Rationale: the player's F5 press is preserved as intent, and the authoritative save occurs at a clean section boundary rather than mid-section.

### Interactions with Other Systems

| System | Direction | Nature of interaction |
|---|---|---|
| **Signal Bus (ADR-0002)** | LS → Events | LS is the sole emitter of `Events.section_exited(section_id: StringName, reason: TransitionReason)` and `Events.section_entered(section_id: StringName, reason: TransitionReason)`. Both signatures require the ADR-0002 amendment (LS-owned pre-implementation gate; see §Dependencies). |
| **Save / Load (system 6)** | LS → SaveLoad (indirect) | LS does NOT call SaveLoad directly. Mission Scripting / Failure & Respawn / Menu System assemble the `SaveGame` and pass it to LS as the `save_game` parameter. LS merely provides the swap + registered-callback coordination (step 9) that state restore runs against. Save/Load's F5/F9 handlers now receive QUEUED presses from LS if fired during a transition (see CR-16). |
| **Mission & Level Scripting (13)** | Mission → LS; LS → Mission | Primary caller. Fires `transition_to_section` on section-exit `TriggerVolume3D` body_entered events with `reason = FORWARD`. Subscribes to `section_entered` to assemble and save autosave (slot 0) when `reason == FORWARD` only. Reads `player_entry_point` from the loaded section scene to place Eve. Registers a step-9 restore callback via `LS.register_restore_callback(_on_restore)` at autoload boot. |
| **Failure & Respawn (14)** | F&R → LS; LS → F&R | Secondary caller. On `player_died` (after writing slot 0 from live state), calls `reload_current_section(slot_0_save_game)`. `reason = RESPAWN` propagates. If called during an in-flight transition, LS QUEUES the respawn (CR-6) and fires at step 13 of the in-flight sequence. F&R's `respawn_triggered` signal (ADR-0002:183) is emitted by F&R BEFORE calling `reload_current_section`; LS does NOT subscribe to `respawn_triggered` — F&R is the orchestrator, LS is the executor. Registers a step-9 restore callback. |
| **Menu System (21)** | Menu → LS | Tertiary caller. Main Menu "New Game" → `transition_to_section(first_section_id, null, TransitionReason.NEW_GAME)`. Main Menu / Pause Menu "Load Game" → `SaveLoad.load_from_slot(N)` → `transition_to_section(loaded.section_id, loaded, TransitionReason.LOAD_FROM_SAVE)`. Registers a step-9 restore callback. Also owns the Main Menu scene's own music fade-out BEFORE calling LS — see Audio handoff below. |
| **Audio (system 3)** | Events → Audio | Audio subscribes to `section_entered` and `section_exited` with the revised 2-parameter signature. Branching per `TransitionReason` enum (see CR-8 table). **Amendment required** to Audio GDD §Mission domain handler table lines 188–189: single-param signatures must be updated to 2-param with `reason` parameter + the branching table. See §Dependencies for explicit cross-GDD pre-implementation gate. Main-menu → first-section music handoff: Menu System fades out main-menu music BEFORE calling `LS.transition_to_section(…, NEW_GAME)`; Audio's `section_entered` handler with `reason = NEW_GAME` triggers first-section music from silence. Positional 3D ambience sources parented to section-scene nodes die at `queue_free` (step 4) without a fade — accepted sonic behavior at MVP; Tier 1 polish addition is OQ-LS-8. |
| **FootstepComponent (8b)** | LS's authoring contract → FC runtime | CR-10 (surface metadata authoring) resolves FC's OQ-FC-1 blocker. FC reads `body.get_meta("surface_tag", &"default")` at runtime; LS does not participate at runtime. The plugin validator previously referenced by AC-LS-4.3 has been moved to FC scope as a cross-reference. |
| **Stealth AI (10)** | Events → Stealth AI (subscribes to `game_loaded`) | Stealth AI does NOT subscribe to `section_entered` directly. It subscribes to Save/Load's `game_loaded` signal (fired after state restore completes) and reads its `StealthAIState.guards` dict to snap each guard to its saved state. LS's job ends at `section_entered` + snap-reveal; Stealth AI's restore happens during the `SWAPPING` state's step-9 registered-callback window (invoked by Mission Scripting's callback, which assembles and dispatches the per-system restores). |
| **Cutscenes & Mission Cards (22)** | Events → Cutscenes | Subscribes to `section_entered`. On `reason == RESPAWN`, checks `MissionState.triggers_fired` to suppress replays of first-arrival cutscenes. On `reason == NEW_GAME` / `LOAD_FROM_SAVE`, suppresses unconditionally (those are authoritative load paths; first-arrival cutscenes fire on `FORWARD` only). |
| **Input (system 2)** | LS ↔ Input | LS pushes `InputContext.LOADING` (a context value owned by Input GDD, **not currently defined** — see §Dependencies upstream gap) onto the context stack at step 1 of the swap; pops it at step 12. If Input GDD does not yet define `LOADING`, this GDD declares it as an upstream dependency that Input GDD must add before moving to Approved. |
| **Failure & Respawn `respawn_triggered` signal (ADR-0002:183)** | F&R → Events (LS does NOT subscribe) | Published by F&R as a "death announced" broadcast. Subscribers like Audio can pre-emptively duck music before F&R assembles the save and calls `reload_current_section`. LS is not a subscriber — LS acts on its own public API calls, not on broadcast signals. |
| **ADR-0003 (Save Format Contract)** | LS reads | `section_id: StringName` is the save key. LS is the sole authority for when `section_id` changes at runtime. |
| **ADR-0006 (Collision Layer Contract)** | LS enforces via scene authoring | Section scenes' colliders are authored on contract-defined layers. LS does not enforce layers at runtime — that discipline belongs to the scene-authoring workflow per ADR-0006. |

## Formulas

**None.** Level Streaming has no gameplay formulas, balance values, or derived calculations. Its quantitative rules are performance budgets and authoring assertions, specified where they belong:

- **Transition time budget** (≤1.3 s total, composed of `t_fade_out + t_load_hold + t_fade_in`) — defined in §Detailed Design (States and Transitions) and §Tuning Knobs. Each component has an independent safe range; they sum to the total. No weighting, no formula.
- **Fade alpha curve** — linear `Tween` over `t_fade_out` and `t_fade_in`. No easing function at MVP. Specified at the implementation level in §Tuning Knobs, not here.
<!-- Removed 2026-04-27 (/consistency-check adjacent #2): the prior "Kill-plane validation (CR-11) — section_bounds.position.y >= kill_plane_y - 5.0 m" bullet described an assertion that CR-12 (L162) deleted. Geometry-gap detection is level-designer authoring QA, not an LS dev-build assertion. L311 already acknowledges CR-11 deletion; this bullet was the last residual reference. -->
- **Section ID lookup** — string-equality compare (`section_id == registry_key`), bounded by registry size (5 MVP entries, plus main-menu and Tier 1 stubs). Not a formula.
- **Cache memory footprint** — proportional to `count(sections_visited_this_session) × avg_packed_scene_size`, but MVP does not specify an eviction policy, so there is no bound to check. Surfaced in §Open Questions for Tier 2.

If Tier 1 playtest reveals that fade timings need easing curves (e.g., cubic ease-in on fade-out to match the "shutter closing" feel of a film cut, linear fade-in so the new scene "snaps" into visibility), this section will gain its first real formula. Until then, Level Streaming is infrastructure with no math.

## Edge Cases

### Concurrent / Reentrant Calls

- **If `transition_to_section` (forward) is called while `_transitioning == true`** → the second call is dropped with `push_warning("[LevelStreamingService] forward transition to '%s' dropped — transition already in progress." % target_id)` per CR-6. No queue. The in-flight transition completes as intended; the dropped call is treated as a caller authoring error (two adjacent trigger volumes, duplicate Mission Scripting emit). Resolution intended.
- **If Failure & Respawn calls `reload_current_section` while a forward transition is already in-flight** (player dies at the exact frame a section-exit trigger fires — a ≤300 ms race) → **the respawn is QUEUED, not dropped** (CR-6 / creative-director adjudication 2026-04-21). `_pending_respawn_save_game` is set to the provided save. At step 13 of the in-flight forward transition, LS fires `reload_current_section(_pending_respawn_save_game)` immediately from IDLE. The player experiences: forward-cut → arrive at new section → death-cut back to the checkpoint section. Total worst-case time ~1.14 s. **Death is never silently swallowed.** This replaces the previous "drop + Tier 1 revisit" design; OQ-LS-3 is closed.
- **If `reload_current_section` is called a second time while already queued** → last-wins (`_pending_respawn_save_game` is overwritten). F&R should not fire twice, but if it does, the most recent save slot is authoritative.
- **If `target_id == current_section_id` and `reason != RESPAWN`** (forward transition to the same section the player is already in) → CR-14 shipping guard returns early (no-op). Debug builds assert `section_id != _current_section_id || reason == RESPAWN` so the underlying Mission Scripting bug is caught. No ~500 ms waste in shipping (previous design's silent cost eliminated).
- **If `section_exited` subscriber awaits** → CR-13 contract violation. Debug builds detect via pre/post-emit frame-timestamp comparison around step 3; if the frame delta > 0 across the emit, `push_error` is raised. Shipping builds run the violation unchecked — the subscriber code is running against a dead tree when it resumes.

### Failure Modes in the 12-Step Swap

- **If `ResourceLoader.load(path)` returns null at step 5** (registry points at a missing or malformed `.tscn`) → the old scene was queue_freed at step 4; `current_scene` is invalid. LS calls `_abort_transition()`, then `get_tree().change_scene_to_file("res://scenes/ErrorFallback.tscn")`. `ErrorFallback.tscn` shows a period mission-dossier "File not found — returning to main menu" card in debug builds and silently routes to the main menu in shipping builds. `_abort_transition()` is also invoked on step 6 (`instantiate()` returns null) and step 7 (`add_child` failure) by the same mechanism.
- **If the newly instantiated section scene's `_ready()` produces runtime errors but does not halt** (missing child nodes, null export dereferences) → Godot logs the error and continues. LS proceeds to step 10; the section may be partially initialized. CR-9's authoring discipline + the `section_root` group check are the first line of defense. A more robust asserting pass (verify `player_entry_point` and `player_respawn_point` resolve to non-null nodes) is flagged as Tier 1 hardening, not MVP-blocking.
- **If any step in 3–11 raises an unhandled error or the coroutine aborts mid-sequence** → without recovery, `_transitioning` remains `true` and `InputContext.LOADING` stays on the stack, permanently suppressing input — the game is stuck. `_abort_transition()` is the single recovery function, called from every error path: it sets `_transitioning = false`, pops `InputContext.LOADING`, sets the fade overlay `ColorRect.color.a = 0`, and returns the state machine to `IDLE`. All `if is_instance_valid(...)` guards and null-checks in the coroutine route to `_abort_transition()` on failure.

### State Restore Failures (Step 9)

- **If the caller's state restore is asynchronous** (e.g., awaits a signal before completing) → LS's `await get_tree().process_frame` is a single-frame window. Async restores leak into the `section_entered` emit and fade-in. **Resolution**: the state restore contract is synchronous by caller responsibility. Mission Scripting / Failure & Respawn / Menu System MUST complete all per-system state assignment within the single frame between step 8 and step 10. Any large-dictionary reads or chunked work must occur BEFORE calling `transition_to_section`, not inside its step-9 window. Code review enforces; LS does not.
- **If the caller's restore handler raises a runtime error** (e.g., `StealthAIState.guards[actor_id]` lookup fails because the section scene no longer contains that actor) → GDScript logs the error and continues; LS proceeds to step 10. The section is live with partial state. Callers must defensively guard every lookup (`if state.guards.has(actor_id)`); this is a per-caller contract, not LS's responsibility.
- **If the `SaveGame.player` contains an unsafe `current_state`** (e.g., `CLIMBING` on a section with no ladder node at `player_entry_point`) → Player Character's `reset_for_respawn(checkpoint)` core rule clamps the state to a safe arrival set (IDLE / STANDING / CROUCHING) before applying. LS does not modify player state; it cites PC's existing contract.

### SectionRegistry Boundary Cases

- **If `section_id` is not present in `SectionRegistry`** → LS asserts `registry.has(section_id)` at step 5's entry. On failure: `_abort_transition()` + `push_error`. The caller's call is effectively a no-op from the player's perspective; the old scene remains live (because step 4 has not yet run — the check is before step 4).
- **If `SectionRegistry` itself fails to load at autoload `_ready()`** (file missing, corrupt `.tres`) → LS sets an internal `_registry_valid: bool = false`, logs `push_error`, but still completes autoload initialization (to avoid breaking later autoload-order dependencies). Every subsequent `transition_to_section` call with `_registry_valid == false` immediately `push_error`s and returns. The main menu still loads because it bypasses LS; the player sees a "cannot start new game" error on New Game / Load Game attempts.
- **If `SectionRegistry` is valid but empty** (zero entries) → same as per-ID missing. The registry's existence is separate from its contents.

### Ordering Races with Save/Load

- **If Save/Load is in `SAVING` state when `transition_to_section` is called** → Save/Load's SAVING is ≤10 ms and synchronous; it completes before LS's step 1 matters in practice. No race. The LS step-1 `InputContext.LOADING` push does not interact with Save/Load's internal state.
- **If Mission Scripting fires an autosave on `section_entered` (step 10) while LS is still in SWAPPING / FADING_IN** → Save/Load's SAVING state blocks a second save but does not block LS. The autosave completes within the snap-in's ~33 ms window (autosave is ≤10 ms synchronous; fits). Safe by construction.
- **If the player attempts Quicksave (F5) or Quickload (F9) during any LS transition state** → per CR-16, LS QUEUES the F5/F9 press (`_pending_quicksave = true` or `_pending_quickload_slot = N`) and fires it on FADING_IN → IDLE. Player hears the save-confirm chime post-transition. This replaces the previous silent-drop behavior which ux-designer flagged as a state-divergence UX bug.

### Player Physics at Swap Boundary

- **If Eve is mid-jump, mid-fall, or attached to a ladder at the frame of the transition** → her `CharacterBody3D` is freed with the outgoing scene (step 4); all physics constraints drop. Step 9's registered-callback restore places her at `player_entry_point` (on `FORWARD` / `NEW_GAME` / `LOAD_FROM_SAVE`) or `player_respawn_point` (on `RESPAWN`) via PC's `reset_for_respawn` with a safe-arrival state enum (IDLE / STANDING / CROUCHING). Velocity is not serialized; Eve arrives grounded and stationary. No hard-landing noise fires in the new section. Resolution intended. **Note**: the ladder-mid-climb case (Plaza → Lower Scaffolds vertical transition where player is mid-ladder-climb) is Mission Scripting's trigger-placement concern — LS cannot itself observe "the player was on a ladder"; it only sees the section-exit trigger fire. Mission Scripting authoring discipline should place section-exit triggers at *stable-footing* waypoints, not mid-traversal.

### Application Focus Loss During Fade

- **If the player alt-tabs during FADING_OUT, SWAPPING, or FADING_IN** → CR-15 requires `application/run/pause_on_focus_lost = true` in `project.godot`. With this setting: the scene tree pauses, the coroutine suspends, Tween updates stop. When focus returns, LS **snaps the overlay alpha to the target value for the current step** (1.0 during FADING_OUT+SWAPPING; completes FADING_IN instantly if mid-way) before resuming. This eliminates the partial-alpha stall ux-designer flagged. `InputContext.LOADING` remains on the stack for the duration — saves/input remain blocked. No state corruption. Verification-task: pause_on_focus_lost setting must be set at project config time; flagged as OQ-LS-10 for godot-specialist to confirm during implementation spike.

### Fallback / Ship Discipline

- **If LS is instantiated twice** (duplicate autoload config, `project.godot` error) → `_ready()` asserts `get_node_or_null("/root/LevelStreamingService") == self`. On failure, `queue_free()` + `push_error`. The first-loaded instance remains authoritative.
- **If Tier 0 ships with only Plaza + stub** and a caller attempts to transition to a section that was in the registry but whose `.tscn` was removed → step 5 returns null → `_abort_transition()` + `ErrorFallback.tscn`. The registry's `.tres` entry is intentionally retained even when the target `.tscn` is a minimal placeholder, so the pipeline remains exercisable in QA builds.

### Save-State Semantic Consistency (Ownership Boundary)

- **If the slot 0 autosave written by Failure & Respawn captures semantically impossible state** (guard corpses still alive, opened doors marked closed, mid-combat alert states) → this is NOT an LS concern. LS runs the same 12-step sequence regardless of save content; it does not validate semantic consistency. Mission & Level Scripting and the per-system restore handlers own that validation. The ownership boundary is documented here for clarity: **LS owns the swap and the lifecycle signals; Mission Scripting and per-system restore handlers own save-state semantic consistency.**

## Dependencies

### Upstream Dependencies (LS needs these to exist)

| System / ADR | Nature | Notes |
|---|---|---|
| **Signal Bus (ADR-0002)** | Hard — LS publishes `Events.section_exited` and `Events.section_entered` | Signal signatures require an **LS-owned ADR-0002 amendment** (see pre-implementation gate below). |
| **Save Format Contract (ADR-0003)** | Hard — `section_id: StringName` is the save key; sectional save scope | LS is the sole authority for when `section_id` changes at runtime. The save scope assumption ("one save = one section's state") is foundational to LS's existence. |
| **Save / Load (system 6, Approved)** | Hard (indirect) — LS does not call SaveLoad; callers do | Save/Load's §Visual/Audio states the fade is owned by LS; **this GDD now supersedes the 0.3 s / 0.5 s timing** with 2-frame hard-cut snap (~33 ms each) after creative-director ruling. Save/Load GDD §Visual/Audio will need a timing revision amendment to match (not breaking — Save/Load references LS as owner, so LS's new timing is automatically authoritative; documentation amendment only). |
| **Input (system 2, Designed — pending review)** | Hard — LS pushes `InputContext.LOADING` to the context stack | **Confirmed gap**: `InputContext.LOADING` is NOT currently defined in Input GDD or ADR-0004 (Context enum has GAMEPLAY, MENU, … but no LOADING). This GDD declares LOADING as an upstream requirement. **Input GDD must add LOADING to its Context enum** before Input GDD can move to Approved. Flagged as cross-GDD blocker. |
| **Collision Layer Contract (ADR-0006)** | Soft — LS enforces via scene authoring, not runtime | Section scenes' colliders conform to ADR-0006's layer scheme; LS does not validate at runtime. |
| **Godot 4.6 engine APIs** | Hard — `ResourceLoader.load`, `PackedScene.instantiate`, `Node.queue_free`, `CanvasLayer`, `Tween`, `get_tree().root.add_child` | All APIs are stable since 4.0. `CanvasLayer.layer = 127` (revised from 128 per godot-specialist review; 128 overflows signed 8-bit range). ErrorFallback uses layer 126. Layer range verification OQ-LS-9. |
| **Project setting `application/run/pause_on_focus_lost = true`** | Hard — required for CR-15 focus-loss behavior | Must be set in `project.godot`. Flagged as OQ-LS-10 for verification during sprint kickoff. |

### LS-Owned Pre-Implementation Gates (must be resolved before the first LS story enters sprint)

These gates are explicitly owned by Level Streaming (not by Stealth AI, not by Audio). They must each be closed independently before implementation work begins. **The previous wording "bundled with Stealth AI's amendment" has been replaced with explicit gate ownership** after audio-director flagged the bundling as an amendment-scope ambiguity risk.

| Gate ID | Description | Owner | Resolves |
|---|---|---|---|
| **LS-Gate-1 (ADR-0002 amendment)** | Amend `signal section_entered(section_id: StringName)` and `signal section_exited(section_id: StringName)` in ADR-0002 Mission domain (currently lines 177–178) to take a second parameter: `reason: TransitionReason` (new enum in LS scope, referenced by the signal). Enum values: `FORWARD, RESPAWN, NEW_GAME, LOAD_FROM_SAVE`. Amendment payload is LS-specific; Stealth AI's separate amendment for its signals is bundled or sequenced separately per technical-director coordination. | technical-director + lead-programmer | CR-2 / CR-8 signal signatures; AC-LS-2.1/2.2/2.3 BLOCKED items; AC-LS-3.1 (c)/(d) |
| **LS-Gate-2 (Input GDD LOADING context)** | Add `LOADING` to the Input GDD's `InputContext.Context` enum (ADR-0004 line 134+ currently lists GAMEPLAY/MENU but not LOADING). | input-GDD author (game-designer + godot-specialist) | CR-1 / CR-5 step 1 / step 12; AC-LS-1.0 (new), AC-LS-1.4 |
| **LS-Gate-3 (Audio GDD handler-table amendment)** | Audio GDD §Mission domain handler table (currently 1-param signatures at lines 188–189) must gain a `reason: TransitionReason` parameter and the full branching table from CR-8 (forward / respawn / new_game / load_from_save). Audio GDD is Approved but this amendment is required synchronized with LS-Gate-1. | audio-director | Audio's respawn ease-in branch; new-game handoff; Audio AC for respawn music timing (to be added per audio-director advisory) |
| **LS-Gate-4 (Save/Load GDD timing annotation)** | Save/Load §Visual/Audio currently states "0.3 s fade out → section load → 0.5 s fade in" referencing LS as owner. With LS's revised 2-frame hard-cut timing, Save/Load's line should either: (a) update to "2-frame hard-cut to black → section load → 2-frame hard-cut reveal" OR (b) be neutralized to "fade timing owned by Level Streaming GDD — consult there for current spec." Option (b) is the lower-maintenance choice. | save-load author (game-designer + godot-specialist) | Consistency across Save/Load and LS GDDs; otherwise cosmetic. |

All 4 gates are MUST-CLOSE before sprint kickoff. Gates 1 and 2 are BLOCKING (implementation cannot begin without them). Gates 3 and 4 are documentation-synchronization blockers — LS code can ship before them if tests mock the contract, but shipping un-synchronized docs risks future-developer confusion.

### Downstream Dependents (these systems depend on LS)

| System | Direction | Nature |
|---|---|---|
| **Mission & Level Scripting (13, Not Started)** | Mission → LS | Primary caller. Triggers forward transitions via `transition_to_section(section_id, assembled_save_game, TransitionReason.FORWARD)`. Subscribes to `section_entered` to fire autosave-on-section-entry when `reason == FORWARD` only (not on RESPAWN / NEW_GAME / LOAD_FROM_SAVE). Reads `player_entry_point` from the loaded section scene. Registers a step-9 restore callback via `LS.register_restore_callback(…)` at autoload boot. **Forward contract** — must consume the API shape as specified in CR-2. |
| **Failure & Respawn (14, Not Started)** | F&R → LS | Secondary caller. On `player_died`, assembles slot 0 autosave from live state, writes via Save/Load, then calls `reload_current_section(slot_0_save_game)`. `reason = RESPAWN` propagates. F&R emits `respawn_triggered(section_id)` BEFORE calling reload_current_section (per ADR-0002:183) so that Audio (and other subscribers) can pre-react. **Queued-respawn contract**: must tolerate CR-6's queue-and-resolve-to-checkpoint behavior when called mid-transition. Registers a step-9 restore callback. |
| **Menu System (21, Not Started)** | Menu → LS | Tertiary caller. "New Game" → `transition_to_section(first_section_id, null, TransitionReason.NEW_GAME)`. "Load Game" → `SaveLoad.load_from_slot(N)` → `transition_to_section(loaded.section_id, loaded, TransitionReason.LOAD_FROM_SAVE)`. MUST fade out main-menu music BEFORE calling LS (Menu-owned, not LS-owned). Registers a step-9 restore callback. |
| **Audio (3, Approved → Amendment Pending)** | Events → Audio | Subscribes to `section_entered` and `section_exited` with 2-parameter signature (post-LS-Gate-3). Branches per `TransitionReason`: FORWARD = full music-location crossfade; RESPAWN = 2.0 s ease-in from silence (existing Audio Respawn handler); NEW_GAME = main-menu handoff path; LOAD_FROM_SAVE = resume from save without ceremony. **Audio GDD §Mission domain handler table (lines 188–189) requires amendment** synchronized with LS-Gate-3. |
| **Cutscenes & Mission Cards (22, Not Started)** | Events → Cutscenes | Subscribes to `section_entered`. On `reason == FORWARD`, checks `MissionState.triggers_fired` for first-arrival firing; on `reason == RESPAWN / NEW_GAME / LOAD_FROM_SAVE`, suppresses. **Forward contract**. |
| **Stealth AI (10, Approved)** | Events (indirect) → Stealth AI | Stealth AI subscribes to **Save/Load's `game_loaded`**, NOT to LS's `section_entered`. Its guard-restore happens inside Mission Scripting's registered step-9 callback (Stealth AI does not register its own callback; Mission Scripting orchestrates per-system restores within its single callback). No direct LS dependency; no amendment needed. |
| **FootstepComponent (8b, Approved)** | Scene authoring convention → FC runtime | CR-10 (surface metadata via `set_meta`) **resolves FootstepComponent OQ-FC-1**. FC reads `body.get_meta("surface_tag", &"default")` at runtime; LS contributes the authoring contract + tool plugin. The plugin validator mode (CLI/headless) is owned here but the AC (previously AC-LS-4.3) has been moved to FC scope. FC GDD's OQ-FC-1 can be closed on this GDD's approval. |
| **Player Character (8, Approved)** | LS → PC (indirect, via Mission Scripting callback) | LS no longer reads `kill_plane_y` (previous CR-11 deleted). LS depends on PC's existing `reset_for_respawn(checkpoint)` core rule for safe player-state arrival after a transition (§Edge Cases) — Mission Scripting invokes this inside its registered step-9 callback. PC entity-registry row's `kill_plane_y.referenced_by` list should drop `design/gdd/level-streaming.md` as part of the post-revision registry sweep. |
| **Tools Programmer (owner — not a GDD)** | LS authoring scope → Tools Programmer deliverable | Surface tagger plugin at `res://addons/surface_tagger/` is a Tier 0 deliverable owned by Tools Programmer (editor UI + mass-assign + headless validator). Scope explicitly assigned 2026-04-21 after level-designer review flagged unowned-scope risk. Fallback if unstaffed: manual `set_meta` per body per OQ-FC-1 Option A. |

### Hard vs Soft Dependencies

- **Hard** (LS cannot function without it): Signal Bus, ADR-0002, ADR-0003, Save/Load, Input's LOADING context, Godot 4.6 engine APIs.
- **Soft** (LS enhances or is enhanced by it, but works without): Collision Layer Contract (scene-authoring discipline), SectionRegistry-per-section asset catalog (LS runs with a single-entry registry for Tier 0).
- **Forward contracts** (downstream systems not yet authored — their GDDs must respect LS's API): Mission Scripting, Failure & Respawn, Menu System, Cutscenes.

### Resolution of Existing Open Questions in Other GDDs

- **FootstepComponent OQ-FC-1** (Surface metadata authoring workflow, flagged as "Level Streaming dep" in FC GDD) → **Resolved** by CR-10 (per-body `set_meta('surface_tag', StringName)` + level-designer tool plugin + Area3D volume override). On this GDD's approval, FC GDD can mark OQ-FC-1 Closed and cite this section.
- **PC GDD OQ-FC-1 reference** (inherited from FC) → same resolution.

### Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Signal taxonomy | `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` | `Events.section_entered(section_id, is_respawn)`, `Events.section_exited(section_id, is_respawn)` | Data dependency (LS publishes). **Requires amendment** — bundle with Stealth AI's amendment. |
| Save format contract | `docs/architecture/adr-0003-save-format-contract.md` | `section_id: StringName` as save key; caller-assembled pattern | Rule dependency (LS implements). |
| Save/Load fade ownership | `design/gdd/save-load.md` §Visual/Audio | Pointer-only reference to LS §Tuning Knobs (no inline timing values; canonical spec lives here in LS GDD per LS-Gate-4 Option B closure 2026-04-27) | Bidirectional pointer (Save/Load defers to LS as owner; LS GDD's §Tuning Knobs is authoritative). |
| Input context stack | `design/gdd/input.md` | `InputContext.LOADING` must exist | Rule dependency. **Verify before Input GDD approval.** |
| Audio respawn handler | `design/gdd/audio.md` §Interactions / Persistence domain | 2.0 s ease-in from silence on respawn | Rule dependency (Audio subscribes; LS's `is_respawn` flag activates). |
| PC safe-arrival state | `design/gdd/player-character.md` | `reset_for_respawn(checkpoint)` core rule | Rule dependency. |
| Forbidden patterns | (future `docs/registry/architecture.yaml` entries) | `level_streaming_caller_outside_allowlist`, `section_scene_missing_actor_id`, `level_streaming_runtime_async_restore` | Rule dependency (to be added in Phase 5b). |
<!-- Removed 2026-04-27 (/consistency-check C3): the prior "Kill-plane constant — Data dependency (LS reads)" row contradicted CR-12 (L162) which deleted LS's kill_plane_y read. Geometry-gap detection is level-designer authoring QA, not an LS runtime concern. -->


## Tuning Knobs

### Fade timing (revised 2026-04-21 — hard-cut grammar)

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `FADE_OUT_FRAMES` | 2 | 1–4 frames | Hard-cut snap to black. At 60 fps = ~33 ms (2 frames). Locked at 2 for MVP per CD adjudication (2026-04-21): "The black hold IS the cut." Single-frame would be a strict instant cut; 2 frames gives a perceptible but decisive boundary. Values beyond 4 frames leak back into dissolve territory. |
| `FADE_IN_FRAMES` | 2 | 1–4 frames | Hard-cut snap reveal. Symmetric with fade-out. Locked at 2 for MVP. Any asymmetric timing (previous 0.3/0.5 s design) is REJECTED — cuts are symmetric. |
| `LOAD_HOLD_BUDGET_MS` | 500 | 200–800 | Soft target for SWAPPING phase (steps 3–10: disconnect + registry check + queue_free + load + instantiate + add_child + process_frame + restore callbacks + section_entered emit). Measured on min-spec = Intel Iris Xe (per ADR-0001). If observed load exceeds this, async migration (post-MVP, OQ-LS-1) is justified. |
| `TOTAL_TRANSITION_BUDGET` | ≤0.57 s | Derived | Sum: ~33 ms snap-out + ≤500 ms SWAPPING + ~33 ms snap-in. The "from trigger to player control" ceiling. Down from 1.3 s in the original spec. |

### Fade overlay appearance

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `FADE_CANVAS_LAYER` | 127 | Locked at 127 | Revised down from 128 per godot-specialist review — Godot's `CanvasLayer.layer` is signed 8-bit (range −128…127); 128 overflows. 127 places overlay above all in-scene `CanvasLayer` nodes. ErrorFallback uses 126. Max-range value flagged OQ-LS-9 for godot-specialist spike confirmation. |
| `ERROR_FALLBACK_CANVAS_LAYER` | 126 | Locked at 126 | One layer below fade overlay so the fade can appear above the error card if both exist simultaneously (transient mid-error state). |
| `FADE_COLOR` | `Color.BLACK` (`Color(0, 0, 0, 1)` at full alpha) | Locked for MVP | Any color other than black violates Pillar 5 (period authenticity) — a colored fade is a modern UX convention. Not a designer knob. |
| `FADE_EASING` | **None (hard cut)** | Locked | Previous spec had linear / cubic variants — now REMOVED. Hard-cut grammar has no easing curve; the 2-frame alpha change is instantaneous for all practical purposes. OQ-LS-5 is CLOSED. |

### Registry / scene paths

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `SECTION_REGISTRY_PATH` | `"res://assets/data/section_registry.tres"` | Locked | Single authority for section → PackedScene mapping. |
| `ERROR_FALLBACK_SCENE_PATH` | `"res://scenes/ErrorFallback.tscn"` | Locked | Must always exist; LS reaches for it on any step-5/6/7 failure. Art direction: period mission-dossier "File not found" card. |
| `SECTION_ROOT_GROUP` | `"section_root"` | Locked | Group membership the root node MUST have per CR-9. LS scans for it as an integrity check. |

### Validation / dev builds

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `ASSERT_CALLER_ALLOWLIST_IN_DEBUG` | `true` | Boolean | CR-4 debug-build guard: `transition_to_section` inspects call stack and asserts caller script path matches `["mission_scripting", "failure_respawn", "menu_system"]` fragments. Shipping builds skip. |
| `ASSERT_SYNC_SUBSCRIBER_IN_DEBUG` | `true` | Boolean | CR-13 debug-build check: pre/post frame-timestamp comparison around step 3 `section_exited` emit; `push_error` if frame delta > 0. |
| `ASSERT_SAME_SECTION_IN_DEBUG` | `true` | Boolean | CR-14 debug-build assertion on redundant swap. Shipping builds return early (CR-14 no-op). |
| `ASSERT_DISTINCT_ENTRY_RESPAWN_IN_DEBUG` | `true` | Boolean | CR-9 debug assertion that `player_entry_point` and `player_respawn_point` resolve to distinct `Marker3D` nodes at `_ready()`. |
| `VERBOSE_TRANSITION_LOGGING` | `false` release / `true` debug | Boolean | Logs every step of the 13-step sequence with ENGINE-TIME timestamps (via `Time.get_ticks_usec()`), not wall-clock — engine timestamps are immune to scheduler jitter on CI runners. Primary measurement tool for AC-LS-5.1/5.2 and AC-LS-6.1/6.2. |
| `SECTION_SCENE_READY_VALIDATION` | `false` at MVP / `true` Tier 1 | Boolean | Tier 1 hardening: after `await process_frame` (step 8), assert `player_entry_point` and `player_respawn_point` resolve to non-null `Marker3D` nodes. On failure, routes to ErrorFallback (currently absent path — flagged for Tier 1 spec revision). |

### Cache

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `RESOURCE_LOAD_CACHE_MODE` | `CACHE_MODE_REUSE` (default) | Locked at MVP | Per CR-12. No eviction policy at MVP; first-visited section stays cached for the session. Tier 2 may need `CACHE_MODE_IGNORE` or manual `ResourceLoader.has_cached` + eviction — Open Question. |

### Surface metadata (resolves FC OQ-FC-1)

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `SURFACE_META_KEY` | `"surface_tag"` | Locked — owned by FootstepComponent | Key used by `set_meta` on bodies and read by FootstepComponent. FC introduced the key; LS consumes it. |
| `SURFACE_TAG_DEFAULT` | `&"default"` | Locked — owned by FootstepComponent | Fallback tag when a body has no `surface_tag` meta. FC's audio bucket for unknown surfaces. |
| Valid surface tag set | `{&"marble", &"tile", &"wood_stage", &"carpet", &"metal_grate", &"gravel", &"water_puddle", &"default"}` | Additive only — tag vocabulary owned by FootstepComponent §Surface Tag Set | The authoritative list lives in the FC GDD. LS consumes it for the tool plugin's presets. Adding a new tag requires coordinated FC + Audio + LS update (FC amends the table, Audio delivers stems, LS adds the tag to the tool plugin). |
| `SURFACE_TAGGER_PLUGIN_PATH` | `"res://addons/surface_tagger/"` | Locked | Level-designer tool plugin for mass assignment. |

### Concurrency

| Parameter | Default | Safe Range | Notes |
|---|---|---|---|
| `DROP_DUPLICATE_FORWARD_TRANSITIONS` | `true` | Locked at MVP | CR-6: forward `transition_to_section` calls during an in-flight transition are DROPPED. |
| `QUEUE_RESPAWN_DURING_TRANSITION` | `true` | Locked at MVP | CR-6 (CD-adjudicated revision 2026-04-21): `reload_current_section` calls during an in-flight transition are QUEUED and fired at step 13. Replaces the previous `RESPAWN_PRIORITY_OVERRIDE` knob. OQ-LS-3 CLOSED. |
| `QUEUE_F5_F9_DURING_TRANSITION` | `true` | Locked at MVP | CR-16: Quicksave / Quickload presses during a transition are queued and fired on FADING_IN → IDLE. Replaces the previous silent-drop behavior. |

### NOT owned by this GDD (cross-references)

- **Kill-plane Y value** (`kill_plane_y` constant) → Player Character. LS does NOT read or modify (per CR-12 — geometry-gap detection is level-designer authoring QA, not an LS runtime assertion). Listed here only because earlier drafts implied LS owned this; CR-12 deleted that dependency. Wording aligned with CR-12 on 2026-04-27 (/consistency-check C3).
- **`InputContext.LOADING` enum value** → Input GDD. LS pushes/pops; does not define.
- **Section scene assets** (`plaza.tscn`, `lower_scaffolds.tscn`, etc.) → Level Designer content authoring.
- **Music transition curves** on `section_entered` / `section_exited` → Audio GDD.
- **Save screenshot composition** during transition (HUD visible? hidden?) → Save/Load + Menu System.
- **First section ID for "New Game"** → Mission & Level Scripting (selects `"plaza"` for Tier 0).

## Visual/Audio Requirements

### Fade overlay

**Direction: hard-cut plain black — locked.** No vignette, no grain, no geometric wipe, no dissolve. The "film cut" framing demands literal cinematic grammar: Saul Bass transitions commit fully and instantaneously to the cut — the screen snaps to black in 2 frames, holds, then snaps to reveal in 2 frames. A vignette would read as a modern game convention ("near-death darkness at edges"). Grain is forbidden by the Post-Process Stack GDD (Core Rule 7, `modern_post_process_stack` anti-pattern fence). A geometric block-wipe in the Saul Bass register would be directionally correct but requires its own `CompositorEffect` pass, sits outside Level Streaming's scope, and adds risk to a Foundation-layer system with no gameplay upside.

The hard-cut black is the correct 1966 grammar. *Our Man Flint* hard-cuts to black between sequences — it doesn't dissolve. The editorial confidence comes from **symmetric 2-frame timing** (revised from the previous 0.3/0.5 s asymmetric dissolve), which creates a decisive boundary the player reads as a cut, not a transition. The black hold between the two snaps IS the cut itself; the snaps are just the rapid alpha change at the cut's edges.

- **`FADE_COLOR`** = `Color.BLACK` — locked. Any other color violates Pillar 5.
- **`FADE_OUT_FRAMES` / `FADE_IN_FRAMES`** = 2 frames each. Hard-cut grammar. No easing.
- **Asset**: a `CanvasLayer` with `layer = 127` + child `ColorRect` (`Color(0, 0, 0, 0)` initial, tween `color:a` property over 2 frames). No texture, no shader.

### ErrorFallback.tscn card

**Direction: period mission-dossier card in the Art Bible §7D letterhead grammar.** Not a Saul Bass geometric error screen; not utility plain text. Importantly — the body copy is IN-WORLD, not DOS-flavored. QA will read it as system state, but the player should read it as a mission setback message. No new art required — it reuses the existing BQA letterhead components.

- **Container**: `Panel` with the BQA mission-dossier card style — Parchment `#F2E8C8` background, BQA Blue `#1B3A6B` header rule (2 px), thin outer rule border in Eiffel Grey `#6B7280`. Centered 640 × 360 at 1080p.
- **Background**: full-screen black `ColorRect` at layer 126 (one below the fade overlay at 127).
- **Header**: "OPERATION: PARIS AFFAIR — MISSION RECORD" in Futura Extra Bold Condensed, BQA Blue `#1B3A6B`, 36 px.
- **Body (revised 2026-04-21 — period-authentic copy)**: "**TRANSMISSION LOST — RETURNING TO BASE**" in American Typewriter Bold, `#1A1A1A`, 20 px, wide tracking (+100 units) for the rubber-stamp feel. Replaces the previous "FILE NOT FOUND — RETURNING TO MAIN MENU" copy (flagged by ux-designer as DOS-era computing jargon that broke the 1965 setting). Alternate acceptable copy: "MISSION FILE CORRUPTED — CONTACT BQA OPS" (narrative-director may ratify either at implementation).
- **Footer (debug builds only)**: small-type metadata line — "ERR: <reason_tag> · <section_id>" in American Typewriter `#6B7280`, 12 px. Shipping builds omit this line entirely.
- **Rubber-stamp overprint (debug builds only)**: rotated "ERROR" stamp in PHANTOM Red `#C8102E`, American Typewriter Bold, ~48 px, 18–25° rotation, ~40 % opacity. Omitted in shipping builds.
- **Player-action behavior**: in shipping, auto-advances to `MainMenu.tscn` after **2.0 s**. In debug, waits for any key (Enter, Space, Esc, LMB) before advancing, so QA can read the error metadata. This resolves the "auto-advance vs wait-for-input" ambiguity flagged by ux-designer.
- **Asset path**: `res://scenes/ErrorFallback.tscn`. Preloaded at autoload boot (CR-1).

### Per-section Environment authoring contract

Level designers authoring `Environment` resources per section must respect the following constraints to preserve the Saturated Pop identity across the vertical climb. LS enforces only that the export is non-null (nil triggers a global fallback); the visual contract is enforced at section art review.

- **Rule ENV-1 — Glow disabled.** Every section `Environment` must have `glow_enabled = false`. Project-wide rule (Post-Process Stack GDD CR-4). PostProcessStack autoload asserts in debug.
- **Rule ENV-2 — Sky/fog color temperature matches section mood target (Art Bible §2):**

| Section | Sky / Ambient | Fog | Fog density |
|---|---|---|---|
| Plaza | `sky_color` near Moonlight Blue `#B0C4D8`; warm fill simulating sodium up-scatter | Off — clear 1965 Paris air | ~0 |
| Lower Scaffolds | Same cool blue sky, reduced ambient | Thin Paris-Amber tint at scaffold extremes for altitude haze | Low |
| Restaurant | `BG_COLOR`, warm Parchment-adjacent `#E8D8A8` — enclosed | Off | None |
| Upper Structure | `sky_color` coolest — Moonlight Blue to near-black. Sky empty/dark so Paris grid reads against it | Off — high-altitude clearest register | None |
| Bomb Chamber | `BG_COLOR` near-black `#0A0A0F` — zero natural light | Off | None |

- **Rule ENV-3 — Tonemapping neutral.** Every section uses `tonemap_mode = TONEMAP_LINEAR` and `adjustment_enabled = false`. No per-scene saturation cranking. The Saturated Pop identity comes from the hand-painted palette, not from post-process boosting.
- **Advisory — Fog color must be drawn from the section's palette anchors (Art Bible §4.3).** A Plaza fog tinted anything other than Paris Amber or Moonlight Blue violates the color vocabulary.

### Audio handoff

LS owns no audio assets directly. All section-transition audio is published on `Events.section_entered(section_id, reason)` / `Events.section_exited(section_id, reason)` signals and consumed by Audio GDD per its location-transition handler and respawn handler (`reason == RESPAWN` triggers the 2.0 s ease-in from silence). LS does not call `AudioStreamPlayer` APIs.

**No dedicated transition audio cue at MVP** (no shutter click, no whoosh, no mechanical-cut FX). This is a deliberate directorial decision, not an omission: the hard-cut grammar reads as silent-cinema confidence. A 1966 transition is visually decisive and aurally restrained — adding a transition SFX would make the system call attention to itself rather than to the scene changes themselves. Documented as a locked choice (not playtest-gated).

**Positional 3D ambience sources (guard-post radio chatter, swinging lamp clanks, chandelier crystal resonance) parented to outgoing-section-scene nodes die at step 4 `queue_free` without a fade.** This is an accepted sonic behavior at MVP: the 2-frame hard cut's audio analog is the same decisiveness — sources terminate at the cut. A Tier 1 polish improvement (emit a 2-frame ambience-fade request on `section_exited` that subscribers can honor before their sources are freed) is documented as OQ-LS-8. Non-positional ambience (AudioManager-owned, lives outside section scenes) is unaffected by `queue_free` and handles its own fade via Audio GDD's `section_exited` handler.

> **📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:level-streaming` to produce per-asset visual descriptions, dimensions, and generation prompts from this section. The primary asset is `ui_error_fallback_card_default.png` + the existing BQA letterhead components it reuses.

## UI Requirements

Level Streaming has minimal direct UI surface. It contributes two player-visible elements:

1. **Fade overlay** — owned entirely by LS; not an interactive UI element (no focus, no input routing). Visual direction in §Visual/Audio Requirements above.
2. **ErrorFallback.tscn card** — shown on step 5/6/7 failure (debug) or flashed briefly during the `change_scene_to_file` transition to the main menu (shipping). Visual spec in §Visual/Audio Requirements.

Level Streaming does NOT contribute:

- Loading bar or progress indicator — forbidden by Pillar 5 at default. (Accessibility opt-in noted below.)
- "Loading…" text string — forbidden by Pillar 5.
- HUD notifications for section transitions — the cut IS the notification.
- Interactive prompts at section boundaries ("Press E to ascend") — forbidden by Pillar 5. Per CR-9's dependency on Mission Scripting's `TriggerVolume3D`, section progression is entirely diegetic.
- Save-card thumbnails or save-screen UI — owned by Menu System (consuming Save/Load's `slot_metadata` API).

### Accessibility opt-in (deferred to Settings & Accessibility GDD)

Ux-designer review flagged that a 0.57 s black screen with no feedback channel can be disorienting for players with cognitive-accessibility needs. The remedy is NOT a default loading bar (which violates Pillar 5) — it is an **opt-in player setting** in Settings & Accessibility (system 23, VS): "Show transition indicator (accessibility)" which adds a single period-styled element during the SWAPPING state (e.g., a blinking BQA sigil in the lower-right corner, NOT a percentage or bar). This satisfies Pillar 5 by keeping the default experience pure while remaining accessible. LS exposes a public property `_accessibility_indicator_enabled: bool` that Settings toggles via the Settings domain's `setting_changed` signal. Default: `false`. Implementation detail is deferred to the Settings & Accessibility GDD; LS contributes only the hook.

### Queued F5 / F9 during transition (post-revision)

Per CR-16: if the player presses F5 or F9 during FADING_OUT / SWAPPING / FADING_IN, the press is queued and executes on FADING_IN → IDLE. The player hears the Audio save-confirm chime (or load fade) post-transition, not mid-cut. **This replaces the previous silent-drop behavior** that ux-designer flagged as state-divergence UX.

> **📌 UX Flag — Level Streaming**: The `ErrorFallback.tscn` card has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the error-fallback card before writing the Menu System epic. Story work that references the error card should cite `design/ux/error-fallback-card.md`, not this GDD directly.

> **📌 UX Flag — Transition UX**: No standalone UX spec exists yet for the transition experience (the hard-cut grammar, the black hold, accessibility opt-in behavior). Ux-designer advisory suggests `design/ux/level-streaming-transition.md` should be authored before Menu System's UX spec is finalized, so the transition's sonic/visual contract is documented consistently across systems. Defer to Phase 4 scope. Not MVP-blocking.

## Acceptance Criteria

**Test evidence paths:**
- Logic: `tests/unit/level_streaming/level_streaming_service_test.gd`
- Integration: `tests/integration/level_streaming/level_streaming_swap_test.gd`
- Config smoke: `production/qa/smoke-[date].md`
- Visual/Feel: `production/qa/evidence/level-streaming-*-[date].{md,png}`

### Logic — State Machine and Guard Behavior *(BLOCKING — automated unit test)*

- **AC-LS-1.0** [Logic] **GIVEN** `LevelStreamingService` in IDLE state, **WHEN** `transition_to_section(&"plaza", null, TransitionReason.NEW_GAME)` is called, **THEN** on the SAME call frame (before any await), `InputContext.current_stack().has(InputContext.Context.LOADING) == true`. *NEW AC — covers step-1 push that was missing. BLOCKED pending LS-Gate-2 (Input GDD LOADING context added).*
- **AC-LS-1.1** [Logic] **GIVEN** `LevelStreamingService` initialized with `_transitioning = false`, **WHEN** `transition_to_section(&"plaza", null, TransitionReason.NEW_GAME)` is called, **THEN** the state machine enters `FADING_OUT` on the same call frame and `_transitioning` becomes `true`.
- **AC-LS-1.2** [Logic] **GIVEN** state is `FADING_OUT`, **WHEN** 2 `process_frame` awaits have resolved (snap-to-black complete), **THEN** state transitions to `SWAPPING` and `_transitioning` remains `true`.
- **AC-LS-1.3** [Logic] **GIVEN** state is `SWAPPING` and `section_entered` has been emitted, **THEN** state transitions to `FADING_IN`.
- **AC-LS-1.4** [Logic] **GIVEN** state is `FADING_IN`, **WHEN** 2 `process_frame` awaits have resolved (snap-reveal complete), **THEN** state returns to `IDLE`, `_transitioning = false`, and `InputContext.current_stack().has(InputContext.Context.LOADING) == false`.
- **AC-LS-1.5** [Logic] **GIVEN** `_transitioning == true`, **WHEN** `transition_to_section` (forward, `reason != RESPAWN`) is called a second time, **THEN** the call is dropped, `push_warning` is invoked with the target ID in the message, and the state machine never enters a second FADING_OUT.
- **AC-LS-1.6** [Logic] **GIVEN** `_transitioning == true` and the coroutine is at any step 2–11, **WHEN** `reload_current_section(save_game)` is called, **THEN** `_pending_respawn_save_game` is set to the provided save_game AND the in-flight transition completes normally AND at step 13 the queued respawn fires with `reason = RESPAWN`. *NEW AC — covers the queued-respawn CR-6 revision.*
- **AC-LS-1.7** [Logic] **GIVEN** `_transitioning == true` and the coroutine is at any step 2–11, **WHEN** `_abort_transition()` is called, **THEN** `_transitioning = false`, `InputContext.LOADING` is popped, the fade overlay `ColorRect.color.a = 0.0`, `_pending_respawn_save_game = null`, `_pending_quicksave = false`, `_pending_quickload_slot = -1`, and state returns to `IDLE`.
- **AC-LS-1.8** [Logic] **GIVEN** `_simulate_registry_failure()` has been called (test-only hook per CR-2), **WHEN** `transition_to_section` is called, **THEN** it immediately calls `push_error` and returns without modifying state. *Injection via CR-2 `_simulate_registry_failure()` test hook (included in debug/test builds, absent in shipping).*
- **AC-LS-1.9** [Logic] **GIVEN** state is `IDLE` with `_pending_respawn_save_game != null`, **WHEN** step 13 reaches the pending-respawn check, **THEN** `reload_current_section(_pending_respawn_save_game)` is fired synchronously and `_pending_respawn_save_game = null`. *NEW AC — covers step-13 queue drain.*
- **AC-LS-1.10** [Logic] **GIVEN** a transition in FADING_IN, **WHEN** the player presses F5, **THEN** `_pending_quicksave = true`, `Save/Load.save_to_slot` is NOT called during the transition, AND on FADING_IN → IDLE transition `Save/Load.save_to_slot(-1)` (quicksave slot) IS called synchronously. *NEW AC — covers CR-16 F5/F9 queue.*

### Logic — Signal Emission Ordering *(BLOCKING — automated unit test)* 🔒 BLOCKED on LS-Gate-1 (ADR-0002 amendment)

- **AC-LS-2.1** [Logic] **GIVEN** a valid transition, **WHEN** step 3 executes, **THEN** `Events.section_exited(outgoing_id, reason)` is emitted AND at emit time `is_instance_valid(outgoing_scene) == true`. *BLOCKED on LS-Gate-1. Test function body: `pending("awaiting LS-Gate-1 ADR-0002 amendment")` until gate closes.*
- **AC-LS-2.2** [Logic] **GIVEN** a valid transition, **WHEN** step 10 executes, **THEN** `Events.section_entered(target_id, reason)` is emitted AND all registered restore callbacks have been invoked AND all invocations returned synchronously (verified via pre/post-call frame-timestamp comparison). *BLOCKED on LS-Gate-1.*
- **AC-LS-2.3** [Logic] **GIVEN** `reload_current_section(save_game)` is called from IDLE, **WHEN** the transition completes, **THEN** both `section_exited` and `section_entered` carry `reason = TransitionReason.RESPAWN`. *BLOCKED on LS-Gate-1.*
- **AC-LS-2.4** [Logic] **GIVEN** a `section_exited` subscriber that calls `await get_tree().process_frame`, **WHEN** the transition executes in debug build, **THEN** `push_error` is raised (CR-13 sync-subscriber violation detection). *NEW AC.*

### Integration — Full Swap Round-Trip *(BLOCKING — integration test)*

- **AC-LS-3.1a** [Integration] **GIVEN** headless GUT with stub `plaza.tscn` + `stub_b.tscn` (both satisfying CR-9), **WHEN** `transition_to_section(&"stub_b", null, TransitionReason.NEW_GAME)` is called, **THEN** after the 13-step sequence: `get_tree().current_scene == stub_b_instance` AND the `plaza` instance is freed (verified via `is_instance_valid(old_scene_ref) == false`).
- **AC-LS-3.1b** [Integration] **GIVEN** the same setup as AC-LS-3.1a, **WHEN** the sequence completes, **THEN** `section_exited` fired exactly once with `(&"plaza", TransitionReason.NEW_GAME)` AND `section_entered` fired exactly once with `(&"stub_b", TransitionReason.NEW_GAME)`. *BLOCKED on LS-Gate-1.*
- **AC-LS-3.1c** [Integration] **GIVEN** the same setup, **WHEN** the sequence completes, **THEN** `_transitioning == false` AND `InputContext.LOADING` is not on the context stack AND `_pending_respawn_save_game == null` AND `_pending_quicksave == false`.
- **AC-LS-3.2** [Integration] **GIVEN** a transition in progress at step 5, **WHEN** `ResourceLoader.load(path)` returns `null` (forced via a `SectionRegistry` entry pointing at a non-existent file, e.g., `res://scenes/sections/__bad__.tscn`), **THEN** `_abort_transition()` runs, `ErrorFallback.tscn` loads via `change_scene_to_file`, `_transitioning == false`, and LOADING is not on the stack.
- **AC-LS-3.3** [Integration] **GIVEN** `plaza.tscn` has been loaded once this session, **WHEN** `transition_to_section(&"plaza", ...)` is called a second time, **THEN** `ResourceLoader.has_cached("res://scenes/sections/plaza.tscn") == true` AND the wall-clock duration of the SWAPPING phase for the second transition is ≤ 50% of the first transition's SWAPPING duration. *Rewritten as observable side-effect (no ResourceLoader mock required). AC-LS-3.3 CONDITIONAL on min-spec measurement availability; tolerance widened if CI variance demands.*
- **AC-LS-3.4** [Integration] **GIVEN** `section_id` is not present in `SectionRegistry`, **WHEN** LS reaches step 4's pre-check (registry-has), **THEN** `_abort_transition()` runs BEFORE `queue_free()` (outgoing scene still in tree at abort time, verified by `is_instance_valid`), and `push_error` is invoked.
- **AC-LS-3.5** [Integration] **GIVEN** a new-game path (`transition_to_section(first_section_id, null, TransitionReason.NEW_GAME)`), **WHEN** the sequence completes, **THEN** `section_entered` fires with `reason = NEW_GAME`, the new scene's `section_id` export equals `first_section_id`, and `_transitioning == false`. *CONDITIONAL: test function body: `pending("awaiting design/gdd/menu-system.md Approved status")` until Menu System GDD exists and status is Approved.*
- **AC-LS-3.6** [Integration] **GIVEN** a stub section scene with a non-null `Environment` resource assigned to `section_root.environment`, **WHEN** `section_entered` fires, **THEN** `get_viewport().get_camera_3d().get_world_3d().environment == section_root.environment`. **GIVEN** a stub section scene with `environment = null`, **THEN** the global fallback Environment is active (not null). *NEW AC.*
- **AC-LS-3.7** [Integration] **GIVEN** a step-9 restore callback registered via `register_restore_callback`, **WHEN** the transition reaches step 9, **THEN** the callback is invoked with `(target_id, save_game, reason)` AND returns synchronously AND `section_entered` fires only after the callback returns. *NEW AC — covers registered-callback coordination.*
- **AC-LS-3.8** [Integration] **GIVEN** a forward transition in progress at step 6, **WHEN** `reload_current_section(save_game_B)` is called during steps 2–11, **THEN** the forward transition completes to FADING_IN → IDLE normally AND `_pending_respawn_save_game == save_game_B` at FADING_IN AND at step 13 a RESPAWN transition with `save_game_B` begins from IDLE. *NEW AC — covers CR-6 queue-and-resolve-to-checkpoint.*

### Config / Data — Registry and Fallback Asset Existence *(ADVISORY — smoke check)*

- **AC-LS-4.1** [Config] **GIVEN** the project in a clean export-ready state, **WHEN** the smoke check runs, **THEN** `res://assets/data/section_registry.tres` exists, is a valid `Resource`, and contains ≥2 entries (`&"plaza"` + `&"stub_b"`) with non-empty `PackedScene` paths.
- **AC-LS-4.2** [Config] **GIVEN** the smoke check runs, **WHEN** it checks for the fallback asset, **THEN** `res://scenes/ErrorFallback.tscn` exists and is a loadable scene file (no editor import error).
- **AC-LS-4.3** [Config] **(MOVED TO FootstepComponent scope)** The surface-tag validator AC is now owned by FootstepComponent — see FC GDD. LS retains the tool plugin scope (CR-10) but the validation AC sits in FC's test file. Cross-reference only.
- **AC-LS-4.4** [Config] **GIVEN** a section scene authored per CR-9, **WHEN** the smoke check inspects the scene, **THEN** (a) the root node is `Node3D` or subclass, (b) root is in group `"section_root"`, (c) `section_id` matches the registry key, (d) `player_entry_point` and `player_respawn_point` resolve to distinct `Marker3D` nodes (CR-9 assertion), (e) `section_bounds` computed from `SectionBoundsHint` is non-zero AABB. *Replaces the deleted CR-11 kill_plane_y assertion test.*

### UI / Feel — Fade Timing and Overlay Behavior *(ADVISORY — engine-time measurement + lead sign-off)*

- **AC-LS-5.1** [Visual/Feel] **GIVEN** a section transition on min-spec hardware (Intel Iris Xe per ADR-0001), **WHEN** observed at runtime, **THEN** the snap-to-black reaches full opacity within ≤ 3 frames (at 60 fps = ≤ 50 ms) of `transition_to_section` being called. Measurement: `VERBOSE_TRANSITION_LOGGING` engine-time timestamps via `Time.get_ticks_usec()` (NOT wall-clock). No flash of geometry visible through the overlay during SWAPPING.
- **AC-LS-5.2** [Visual/Feel] **GIVEN** the new section scene instantiated, **WHEN** snap-reveal begins, **THEN** the overlay returns to full transparency within ≤ 3 frames of `section_entered` firing. No step artifacts in the alpha curve.
- **AC-LS-5.3** [UI] **GIVEN** a transition in progress (any state other than IDLE), **WHEN** the player presses F5 or F9, **THEN** the press is queued (`_pending_quicksave` / `_pending_quickload_slot`), NO save/load action fires during the transition, AND on FADING_IN → IDLE the queued action fires synchronously with full Audio feedback (save-confirm chime / load hard-cut) firing post-transition. Manual walkthrough evidence. *Rewritten: previous version validated the broken silent-drop behavior; now validates CR-16 queued behavior.*

### Performance — Transition Budget *(ADVISORY — but failure is a milestone blocker; escalate to technical-director)*

- **AC-LS-6.1** [Performance] **GIVEN** a transition from `plaza` to `stub_b` (or `lower_scaffolds` when Tier 1 content exists) on min-spec hardware (Intel Iris Xe per ADR-0001), **WHEN** measured from `transition_to_section` call frame to `InputContext.LOADING` pop frame, **THEN** **p90 across 10 consecutive runs is ≤ 0.57 s; no individual run may exceed 0.8 s.** Measurement: `VERBOSE_TRANSITION_LOGGING` engine-time timestamps (steps 1 and 12). If any single run fails, repeat the 10-run set once; only flag as FAIL if both sets contain a failing run. *Revised: previous 5-run + 1.3 s target replaced with 10-run p90 + 0.57 s target (hard-cut grammar reduces total budget).*
- **AC-LS-6.2** [Performance] **GIVEN** the same run, **WHEN** the SWAPPING phase is isolated (step 3 entry to step 10 entry), **THEN** elapsed engine time is ≤ 500 ms (`LOAD_HOLD_BUDGET_MS`). Exceeding this on min-spec is the primary justification for the async `ResourceLoader` post-MVP migration documented in OQ-LS-1. Min-spec explicitly cited: Intel Iris Xe integrated graphics per ADR-0001.
- **AC-LS-6.3** [Performance] **GIVEN** two consecutive forward transitions into the same section (`plaza → stub_b → plaza`), **WHEN** peak heap memory is measured via `OS.get_static_memory_usage()`, **THEN** peak across the second transition is ≤ 110% of peak during the first transition (no unbounded growth from repeated cache operations). *NEW AC — covers performance-analyst's peak-memory concern.*

### Blocker / Conditional Summary

| AC | Status | Blocker |
|---|---|---|
| AC-LS-1.0, 1.4 | **BLOCKED** | LS-Gate-2: Input GDD must define `InputContext.Context.LOADING` |
| AC-LS-2.1, 2.2, 2.3, 2.4 | **BLOCKED** | LS-Gate-1: ADR-0002 amendment — `section_entered` / `section_exited` must gain `reason: TransitionReason` |
| AC-LS-3.1b | **BLOCKED** | Same LS-Gate-1 |
| AC-LS-3.1a, 3.1c, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8 (overall) | CONDITIONAL | Require stub scene files (`plaza.tscn` + `stub_b.tscn`) satisfying CR-9. Level-designer + level-designer tool plugin (Tools Programmer owned) deliverables. |
| AC-LS-3.5 | CONDITIONAL | Test function body: `pending("awaiting design/gdd/menu-system.md Approved status")` — un-pend when Menu System GDD exists and status is Approved. |
| AC-LS-4.3 | MOVED | Relocated to FootstepComponent scope. LS retains CR-10 authoring contract but the test AC lives in FC's smoke check. |
| AC-LS-6.1/6.2/6.3 | CONDITIONAL | Require min-spec hardware for reliable measurement. CI runner results are advisory only; human-hardware QA is authoritative. |

### Structural Notes for Implementation

Two test files must be created (with `pending()` stubs for BLOCKED ACs) before the first Level Streaming story enters sprint — this is the hard gate under the project's Testing Standards:

- `tests/unit/level_streaming/level_streaming_service_test.gd`
- `tests/integration/level_streaming/level_streaming_swap_test.gd`

The ADR-0002 amendment is a sprint prerequisite for any story touching signal emission. Schedule it as a pre-implementation task.

## Open Questions

### Closed by the 2026-04-21 revision pass

- **OQ-LS-3** (respawn-priority override during 300 ms race) — **CLOSED**. Creative-director adjudication (2026-04-21): respawn is QUEUED and fires at step 13 of the in-flight transition (CR-6). `RESPAWN_PRIORITY_OVERRIDE` tuning knob deleted; replaced by `QUEUE_RESPAWN_DURING_TRANSITION` (locked true).
- **OQ-LS-5** (fade easing curves — cubic ease-in candidate) — **CLOSED**. Hard-cut grammar selected per creative-director ruling; no easing applies to a 2-frame snap. `FADE_EASING` tuning knob deleted.

### Active (deferred, not blocking MVP implementation)

| Question | Owner | Deadline | Current direction |
|---|---|---|---|
| **OQ-LS-1** Async `ResourceLoader.load_threaded_*` migration — when does MVP blocking-load become insufficient? | gameplay-programmer + godot-specialist | Tier 1 playtest on min-spec hardware (Intel Iris Xe per ADR-0001) | If AC-LS-6.2 (≤500 ms SWAPPING on min-spec) fails consistently across ≥30% of 10-run p90 measurements, spike async migration in a dedicated ADR. |
| **OQ-LS-2** Cache eviction policy for Tier 1 AND Tier 2 | technical-director + performance-analyst | **Before Tier 1 playtest** (performance-analyst escalation — previous framing "Tier 2 only" was incorrect; 5 Paris sections × mesh/texture sub-resources can exceed 500 MB–1 GB) | Implement `evict_section_from_cache(section_id)` as a no-op stub API at MVP (already in CR-2); Tier 1 adds policy (LRU-N, keep N most recent) if memory measurements exceed 500 MB per 5-section Paris playthrough. |
| **OQ-LS-4** Section scene `_ready()` validation (Tier 1 hardening) | gameplay-programmer | Before Tier 1 content push | Tier 1 adds an assertion pass after step 8: verify `player_entry_point` and `player_respawn_point` resolve to non-null `Marker3D` nodes. Failure routes to ErrorFallback (requires Tier 1 spec revision). Tuning knob `SECTION_SCENE_READY_VALIDATION` exists; toggle on at Tier 1. |
| **OQ-LS-6** Tier 2 (Rome / Vatican) section registry expansion — save format impact | producer + systems-designer | Before Tier 2 development | ADR-0003's refuse-load-on-mismatch versioning means Tier 2 additions that change `SaveGame` schema invalidate Paris saves. |
| **OQ-LS-7** Main menu background scene as a "pseudo-section" | art-director + ux-designer | Before Menu System GDD | Current decision: main menu bypasses LS entirely (CR-7). Stays Menu-owned even if visually section-like. |
| **OQ-LS-8** Positional 3D ambience fade on section exit (Tier 1 polish) | audio-director + gameplay-programmer | Tier 1 playtest | MVP accepts 3D sources die at `queue_free` with no fade (sonic analog of the hard cut). Tier 1 polish adds a 2-frame ambience-fade request on `section_exited` that subscribers can honor before their sources are freed. |
| **OQ-LS-9** Godot 4.6 `CanvasLayer.layer` max-value verification | godot-specialist | Sprint kickoff spike | Revision pass moved fade layer to 127 defensively (signed 8-bit assumption). Before first LS story enters sprint, godot-specialist should verify actual 4.6 range against engine reference + live editor test, then confirm or adjust layers (fade + ErrorFallback). |
| **OQ-LS-10** Godot `application/run/pause_on_focus_lost` project setting | godot-specialist | Sprint kickoff | CR-15 requires `true`. Verify setting exists in Godot 4.6 `project.godot`; set it; confirm Tween-pause behavior on focus loss matches the spec in a local build. |
| **OQ-LS-11** Step-7 direct `current_scene = instance` assignment safety | godot-specialist | Sprint kickoff spike | Godot-specialist flagged as UNVERIFIED. Spike: try the 13-step manual pattern in an isolated test scene; verify `get_tree().get_nodes_in_group(...)` behavior, scene-change notifications, and internal SceneTree state are consistent with engine's own `change_scene_to_packed`. If unsafe, design a replacement pattern — this may require a dedicated LS ADR. |
| **OQ-LS-12** Per-CollisionShape3D surface tagging (multi-shape bodies) | level-designer + sound-designer | Tier 1 content | MVP accepts `set_meta` on body-level only (dominant-material wins). Tier 1 / Tier 2 may introduce per-shape metadata (e.g., shape's own `Metadata` resource) if content authoring demands it. |
