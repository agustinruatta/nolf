# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-04-30
> **Manifest Version**: 2026-04-30
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0006, ADR-0007 *(5 of 8 Accepted; ADR-0004 G5 deferred to S&A production story, ADR-0005 G3/G4/G5 production scope, ADR-0008 G1/G2 need Iris Xe — rules from those ADRs land when each reaches Accepted)*
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

## Coverage Caveat — 5 of 8 ADRs Covered

This manifest is generated from the 5 ADRs Accepted as of 2026-04-30. Foundation,
Core, and the **outline-rendering subset of Presentation** layer rules are now
complete. The remaining gaps are scoped to specific later production stories:

- **ADR-0004 (UI Framework)** — Gates 1-4 closed; G5 (BBCode → AccessKit
  serialization) deferred to the Settings & Accessibility production story
  (needs runtime AT). UI framework rules still pending until G5 closes.
- **ADR-0005 (FPS Hands Outline Rendering)** — G1+G2 closed; G3 (resolution-scale
  toggle on rigged mesh), G4 (animated mesh artifacts), G5 (Shader Baker ×
  `material_overlay`) all require the actual hands-rendering production story.
  FPS hands outline rules still pending.
- **ADR-0008 (Performance Budget Distribution)** — G1+G2 (Restaurant reference
  scene measurement on Iris Xe + RTX 2060 informative) need hardware access; G3
  D3D12 closed by removal; G4 needs Windows Vulkan. Per-slot performance
  guardrails still pending.

Stories that depend on the rules below — Foundation, Core, and outline-rendering
Presentation — can proceed now. Stories touching UI framework, FPS hands
rendering, or per-slot performance gates must wait for the manifest regeneration
after the relevant ADR reaches Accepted.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns

#### Signal Bus (ADR-0002)
- **Subscribers MUST connect in `_ready` and disconnect in `_exit_tree`** with `is_connected` guards before each disconnect call. Non-negotiable for memory-leak prevention. — source: ADR-0002 IG 3.
- **Every Node-typed signal payload MUST be checked with `is_instance_valid(node)` before dereferencing.** Signals can be queued and the source node may be freed before the subscriber runs. — source: ADR-0002 IG 4.
- **Enum types in signal signatures MUST be defined as inner enums on the system class that owns the concept.** Use the qualified name (e.g., `StealthAI.AlertState`) in signal declarations on `events.gd`. Do NOT define enums on `events.gd`. Do NOT create a shared `Types.gd` autoload. — source: ADR-0002 IG 2.
- **Use direct emit (`Events.<signal>.emit(args)`)**, not wrapper methods. — source: ADR-0002 §Risks (forbidden pattern row).
- **`EventLogger` self-removes in non-debug builds** via `OS.is_debug_build()`. Production code MUST NOT call `EventLogger` methods. — source: ADR-0002 IG 8.
- **`setting_changed(category, name, value: Variant)` is the SOLE permitted Variant-payload signal.** New signals MUST use explicit types unless they document an equivalently strong justification. — source: ADR-0002 IG 7.

#### Save / Load (ADR-0003)
- **`SaveGame.FORMAT_VERSION` is a `const`; `save_format_version` is the `@export var` initialized from it.** Only the `var` is serialized. The `const` is the runtime sentinel for compare-on-load. — source: ADR-0003 IG 1.
- **`SaveLoadService` accepts a pre-assembled `SaveGame`** — it does NOT query game systems to assemble one. Mission Scripting (or Failure & Respawn, or a player save action) builds the `SaveGame` by reading current state from each owning system. — source: ADR-0003 IG 2.
- **Callers MUST call `loaded_save.duplicate_deep()` before handing nested state to live systems.** Otherwise mutations to live state would mutate the cached loaded resource. — source: ADR-0003 IG 3.
- **Type-guard after every load**: `if loaded == null or not (loaded is SaveGame): emit save_failed(CORRUPT_FILE); return null`. Binary `.res` returns `null` silently on class mismatch — this is the most likely silent bug. — source: ADR-0003 IG 4.
- **Atomic write pattern**: write to `slot_N.tmp.res` first (tmp filename MUST end in `.res` — `ResourceSaver.save()` selects format from extension; `.tmp` returns `ERR_FILE_UNRECOGNIZED` per Sprint 01 verification finding F1); verify `ResourceSaver.save() == OK`; then `DirAccess.rename(tmp, final)`. — source: ADR-0003 IG 5.
- **Per-actor identity uses `actor_id: StringName`** declared as `@export` on the actor's script and set uniquely per scene. Do NOT use `NodePath` or `Node` references in saved Resources — they cannot survive a scene reload. — source: ADR-0003 IG 6.
- **8 save slots total** — `slot_0` = autosave (overwritten at section transitions + explicit save action); `slot_1`..`slot_7` = player-controlled manual saves. — source: ADR-0003 IG 7.
- **Every `slot_N.res` has a paired `slot_N_meta.cfg` (ConfigFile)** with fields `section_id`, `section_display_name`, `saved_at_iso8601`, `elapsed_seconds`, `screenshot_path`, `save_format_version`. Menu System reads ONLY the sidecar to render save cards (avoids full Resource load). — source: ADR-0003 IG 8.
- **On any save failure**: emit `Events.save_failed(reason)`, return `false`, leave the previous good save intact. Do NOT auto-delete or auto-recover destructively. — source: ADR-0003 IG 9.
- **Settings file is separate** — Settings & Accessibility uses `user://settings.cfg` (ConfigFile). NEVER part of the SaveGame Resource. — source: ADR-0003 IG 10.
- **Every typed-Resource `@export` field on `SaveGame` MUST reference a top-level `class_name`-registered Resource declared in its own file under `src/core/save_load/states/`** (Sprint 01 verification finding F2). Inner-class Resources used as `@export` types come back `null` on load. — source: ADR-0003 IG 11.

#### Autoload Registration (ADR-0007)
- **The `project.godot [autoload]` block MUST be generated from ADR-0007 §Key Interfaces verbatim** — no reordering by the Godot editor UI, no alphabetisation, no rewrites by `@tool` scripts. — source: ADR-0007 IG 1.
- **All 10 autoload entries use `*res://` path-prefix-star syntax** (scene-mode: Node added to root, `_ready()` fires, tree lifecycle active). Script-mode (no `*`) is not supported. — source: ADR-0007 IG 2.
- **An autoload's `_ready()` MAY reference autoloads at earlier line numbers only.** Referencing a later autoload from `_ready()` is undefined (the later autoload is not yet in the tree). — source: ADR-0007 IG 4 + §Cross-Autoload Reference Safety rule 2.
- **Downstream ADRs/GDDs MUST NOT restate specific autoload line numbers.** Reference ADR-0007 instead. — source: ADR-0007 IG 7.

### Forbidden Approaches

#### Signal Bus
- **Never add methods, state, or query helpers to `events.gd`** — pattern `event_bus_with_methods`. Reason: `events.gd` must remain "signals only" or it drifts into a service-locator anti-pattern. — source: ADR-0002 §Risks.
- **Never add wrapper emit methods (e.g., `Events.emit_player_damaged(args)`)** — pattern `event_bus_wrapper_emit`. Reason: marginal convenience does not justify weakening the bus's "signals only" rule. — source: ADR-0002 §Risks.
- **Never implement synchronous request-response patterns through the bus** (e.g., a "query" signal expecting a callback to be set on the payload) — pattern `event_bus_request_response`. Reason: the bus is fire-and-forget only; use direct method calls for request-response. — source: ADR-0002 §Risks.
- **Never re-emit built-in Godot signals (`SceneTree.node_added`, etc.) through the bus** — pattern `event_bus_engine_signal_reemit`. Reason: creates double-dispatch and ambiguity. Systems that need engine signals connect to them directly. — source: ADR-0002 IG 6.
- **Never define enums on `events.gd`** — pattern `event_bus_enum_definition`. Reason: enum ownership belongs to the system that owns the concept; centralizing enums on the bus is the same anti-pattern as defining them in a shared `Types.gd` autoload. — source: ADR-0002 IG 2.
- **Never use distributed signal connections (no bus)** as an alternative architecture. Reason: every system would need wire-up boilerplate and service-discovery state; no central place to debug "who's listening to what." — source: ADR-0002 Alternative 1.
- **Never use the group-broadcast (`get_tree().call_group()`) mediator pattern** as a replacement for the bus. Reason: not typed (string method names), no compile-time check; doesn't compose with editor signal connection UI. — source: ADR-0002 Alternative 2.

#### Save / Load
- **Never let `SaveLoadService` query game systems to assemble a `SaveGame`** — pattern `save_service_assembles_state`. Reason: SaveLoadService must remain file-I/O-only; querying systems makes it a service locator. — source: ADR-0003 §Risks.
- **Never use `NodePath` or `Node` references in saved Resources** — pattern `save_state_uses_node_references`. Reason: paths/refs cannot survive a scene reload. Use stable `actor_id: StringName` instead. — source: ADR-0003 IG 6 + §Risks.
- **Never hand a loaded `SaveGame`'s nested state to live systems without `duplicate_deep()`** — pattern `forgotten_duplicate_deep_on_load`. Reason: live mutations would mutate the cached loaded resource, corrupting the save view. — source: ADR-0003 IG 3 + §Risks.
- **Never use inner-class typed Resources as `@export` field types** on serialized Resources. Reason: they come back `null` after `ResourceLoader.load`. Pull every typed Resource into its own `class_name`-registered file. — source: ADR-0003 IG 11 (Sprint 01 finding F2).
- **Never auto-delete or auto-recover a save destructively on failure.** Emit `save_failed(reason)`, leave the previous good save intact. — source: ADR-0003 IG 9.

#### Autoload Registration
- **Never call `Engine.register_singleton()` at runtime** — pattern `runtime_singleton_registration` (optional). Reason: shadows autoload names; test doubles use dependency injection instead. — source: ADR-0007 IG 5.
- **Never call `ProjectSettings.set_setting()` / `add_autoload_singleton()` from `@tool` scripts or editor plugins on autoload paths without a paired ADR-0007 amendment** — pattern `unregistered_autoload`. Reason: silently mutates the `[autoload]` block; future plugin additions require explicit ADR amendment. — source: ADR-0007 IG 6.
- **Never reference any other autoload from an autoload's `_init()`** — pattern `autoload_init_cross_reference`. Reason: `_init()` fires during object construction, before the node is added to the tree; other autoloads are unreachable from `_init()`. Cross-autoload setup belongs in `_ready()`. — source: ADR-0007 IG 3 + §Cross-Autoload Reference Safety rule 4.
- **Never reference a later-line autoload from an autoload's `_ready()`.** Reason: the later autoload is not yet in the tree when the earlier one's `_ready()` runs. — source: ADR-0007 §Cross-Autoload Reference Safety rule 3.

### Performance Guardrails
- **Signal Bus emit cost**: bounded by per-signal frequency × subscriber count. All 43 events safe at expected frequencies — `weapon_fired` full-auto × 4 subscribers ≈ 0.02 ms/frame; `player_footstep` ≤ 3.5 Hz × 2–3 subscribers negligible; `setting_changed` one-shot per session; `ui_context_changed` ≤ 2 Hz worst case; `cutscene_started/ended` ≤ 7 first-watch pairs per play-through. — source: ADR-0002 IG 5.
- **Save latency**: ≤ 2 ms (5 KB save, SSD); ≤ 10 ms worst case (spinning disk); 100 ms is the perceptible threshold but the budget targets imperceptibility. — source: ADR-0003 §Performance Implications.
- **Load latency** at section start: ≤ 2 ms (load + duplicate_deep + assign), hidden inside Level Streaming load cost (~200–500 ms). — source: ADR-0003 §Performance Implications.
- **Autoload boot cascade**: ~10 × <1 ms ≈ <10 ms total startup autoload cost; <1 MB steady-state autoload memory footprint across all 10 autoloads. Total project startup budget: 50 ms. — source: ADR-0007 §Performance Implications.

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns

#### Physics Collision Layers (ADR-0006)
- **Every gameplay script that touches `collision_layer`, `collision_mask`, `set_collision_layer_value()`, `set_collision_mask_value()`, or `PhysicsRayQueryParameters3D.collision_mask` MUST reference `PhysicsLayers.*` constants.** Bare integer literals (`2`, `4`, `8`...) are forbidden in gameplay code. Exception: the `PhysicsLayers` class itself, which defines the values. — source: ADR-0006 IG 1.
- **Prefer composite masks over manual bitwise composition at call sites.** If `MASK_X | MASK_Y` appears more than once, add it as a named constant on `PhysicsLayers` (e.g., `MASK_AI_VISION_OCCLUDERS`). Composite masks encode design intent. — source: ADR-0006 IG 2.
- **Layer INDICES vs MASKS are distinct types.** Use `LAYER_*` constants with `set_collision_layer_value(index, true)` / `set_collision_mask_value(index, true)` helpers. Use `MASK_*` constants with direct property assignment (`collision_layer = MASK_PLAYER`). They are NOT interchangeable. — source: ADR-0006 IG 3.
- **Adding a new physics layer** requires: (a) new `LAYER_X` + `MASK_X` constant in `PhysicsLayers`; (b) `3d_physics/layer_N="X"` row in `project.godot`; (c) update any composite masks that should include X; (d) ADR-0006 amendment documenting the new layer's purpose. — source: ADR-0006 IG 4.
- **GDScript constants are the source of truth; `project.godot` named layers are documentation.** If they diverge at runtime, the GDScript constant wins. Code review catches drift. — source: ADR-0006 IG 5.
- **Physics bodies set their OWN layer; they MASK the layers they collide AGAINST.** A common mistake is to set `collision_mask` to include self ("Player masks against Player"). A player who collides with World and AI sets `layer = MASK_PLAYER`, `mask = MASK_WORLD | MASK_AI`. — source: ADR-0006 IG 6.
- **Raycasts use `collision_mask` only.** Raycasts have no layer (they are not collision bodies). Set `PhysicsRayQueryParameters3D.collision_mask = PhysicsLayers.MASK_*`. — source: ADR-0006 IG 7.
- **Non-blocking raycast layers**: `LAYER_INTERACTABLES` bodies have `collision_layer = MASK_INTERACTABLES` but `collision_mask = 0` — they participate in raycasts but do NOT block movement. This is the physics encoding of "documents don't push Eve." — source: ADR-0006 IG 8.

### Forbidden Approaches
- **Never use bare integer literals for `collision_layer` / `collision_mask` / `set_collision_*_value()` arguments in gameplay code** — pattern `hardcoded_physics_layer_number`. Reason: schema drift; rename hazard; editor inspector confusion. PRs using bare integers are review-rejected. — source: ADR-0006 IG 1 + §Risks.

### Performance Guardrails
- **Zero runtime cost** for `PhysicsLayers` — `const int` members inline at compile time; not an autoload (no node lifecycle, no memory). — source: ADR-0006 §Performance Implications.

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

*No Feature-layer rules yet — the relevant ADRs (Stealth AI behaviors, Combat damage routing, etc.) are downstream of GDDs that haven't yet driven Feature-layer ADRs to Accepted. Re-check after the next batch of ADR promotions.*

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

### Required Patterns

#### Outline Rendering (ADR-0001 — Stencil ID Contract)

- **Every gameplay system that spawns visible objects MUST call `OutlineTier.set_tier(mesh, OutlineTier.X)` at spawn time.** No engine default exists; unmarked meshes write stencil 0 and receive no outline. Static environment meshes set the stencil tier once in the `.tscn` (scene-baked) and do NOT re-set at runtime unless the escape hatch is invoked. — source: ADR-0001 IG 1 + IG 2.
- **Tier value contract is fixed**: 0=None (no outline) / 1=HEAVIEST (4 px @ 1080p; Eve, gadget pickups, key interactives) / 2=MEDIUM (2.5 px; PHANTOM guards) / 3=LIGHT (1.5 px; environment, civilians). Single near-black outline color `#1A1A1A` for all tiers. — source: ADR-0001 §Decision (per-tier table).
- **Escape-hatch runtime reassignment is supported**: a controller script may call `OutlineTier.set_tier(mesh, new_tier)` at any time to change a mesh's outline tier (e.g., the swinging lamp in Lower Scaffolds promoted to tier 1 during a focal moment). The shader does not change — only the stencil value on the material. — source: ADR-0001 IG 3.
- **Comedic hero props (oversized signage, labeled crates) get tier 1 (HEAVIEST) locally** in their composition, regardless of being environment-class geometry. Set this in the prop's scene. — source: ADR-0001 IG 4.
- **Default tier for new systems**: tier 3 (Light) for environment-class objects; tier 2 (Medium) for hostile/character-class. Tier 1 (HEAVIEST) is reserved for explicit "look here" objects. — source: ADR-0001 IG 5.
- **Resolution-scale fallback**: on Intel Iris Xe-class integrated graphics (detected at startup), the outline shader receives `resolution_scale = 0.75` and the engine's render resolution is set accordingly. On RTX 2060 and above, `resolution_scale = 1.0`. Detection logic lives in `Settings & Accessibility` (system 23). — source: ADR-0001 IG 6.
- **Production outline algorithm MUST be jump-flood (Bgolus-style) or equivalent log2-pass distance-field.** Total work ≈ `9 · log2(max_radius_px) · pixels`. The Sprint 01 spike prototype `prototypes/verification-spike/stencil_compositor_outline.gd` uses a naive scan ONLY because it is throwaway code intended to validate the API surface; it must NOT be migrated to production. Reference implementation: [dmlary/godot-stencil-based-outline-compositor-effect](https://github.com/dmlary/godot-stencil-based-outline-compositor-effect) (MIT, Godot 4.5). — source: ADR-0001 IG 7 (Sprint 01 finding F6).
- **Per-material stencil writes use `STENCIL_MODE_CUSTOM`** (`stencil_mode = 3`, `stencil_flags = 2` Write, `stencil_compare = 0` Always, `stencil_reference = N` for N ∈ {1, 2, 3}). NOT `STENCIL_MODE_OUTLINE` — that activates the world-space native pass which violates screen-space stability. — source: ADR-0001 §Engine Compatibility + Finding F4.
- **CompositorEffect stencil-test uses graphics-pipeline state, NOT shader sampling.** Build per-tier `RDPipelineDepthStencilState` with `enable_stencil = true`, `front_op_compare = COMPARE_OP_EQUAL`, `front_op_reference = N`, `front_op_compare_mask = 0xFF`. Attach the scene's depth-stencil texture (`RenderSceneBuffersRD.get_depth_layer(0)`) as the framebuffer's depth attachment so the GPU stencil-test hardware filters fragments. The compute shader then reads the resulting tier-mask intermediate texture as a regular `image2D`. — source: ADR-0001 §Key Interfaces + Finding F5.

### Forbidden Approaches

#### Outline Rendering (ADR-0001)
- **Never use `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` for player-facing comic outlines.** It is world-space (outlines shrink with distance), which violates the Saturated Pop pillar (Art Bible §1: outline ink weight must remain consistent across the frame, like a comic page). The native API is documented as a fallback for incidental outlines where screen-space stability is not load-bearing (e.g., editor-mode highlights, debug overlays). Production use is forbidden by ADR-0001's pillar alignment. — source: ADR-0001 §Engine Compatibility + verification-log Finding F4.
- **Never `sample_stencil(SCREEN_UV)` from a compute shader.** Godot 4.6 does NOT expose the stencil aspect of the depth-stencil texture as a sampleable resource in any shader stage. ADR-0001's original GLSL pseudocode showing this approach was wrong; the actual API uses graphics-pipeline `RDPipelineDepthStencilState.enable_stencil = true`. — source: verification-log Finding F5 + ADR-0001 §Key Interfaces (post-A1 amendment).
- **Never use the naive `(2·max_radius_px+1)²` neighborhood scan as the production algorithm.** Verified to exceed the 2 ms budget on Intel Iris Xe even with the 75% resolution-scale fallback (~3.7 ms at 1440×810 extrapolated from RTX 4070 measurement). Use jump-flood per IG-7. — source: verification-log Finding F6.
- **Never use Alternative 1 (Visual Layers / `VisualInstance3D.layers` bitmask + N full-screen passes).** Three full-screen passes risk exceeding the 2 ms budget on integrated graphics. Listed in ADR-0001 §Alternatives as a documented fallback only if both verification gates fail. — source: ADR-0001 Alternative 1.
- **Never use single-pass uniform-weight outline (no tier hierarchy).** Violates Art Bible Section 1 Principle 2 (Silhouette Owns Readability) and Pillar 3 (Stealth is Theatre). — source: ADR-0001 Alternative 2.
- **Never use multi-pass per-tier outline with three separate `CompositorEffect` resources.** For a single-player game with three fixed tiers, the single-pass branching approach is simpler. Listed as a future fallback if runtime debugging proves harder than expected. — source: ADR-0001 Alternative 3.
- **Never encode tier in a vertex color channel.** Adds a pre-pass draw call; burdens art pipeline (every authored mesh needs the right vertex color); makes runtime escape-hatch reassignment painful (would require modifying mesh data). — source: ADR-0001 Alternative 4.
- **Never claim stencil values 0/1/2/3 for other purposes** in any future ADR. The remaining 252 stencil values (4–255 on the 8-bit stencil plane) are available for future claims (e.g., portal effects, depth-based effects). — source: ADR-0001 §Decision (Neutral consequence) + §Related.

### Performance Guardrails

- **Outline pass execution at 1080p (Iris Xe @ 75% scale, jump-flood algorithm)**: target ≤2.0 ms (Art Bible §8F). Naive scan algorithm fails this budget; jump-flood expected to land ~0.4 ms with margin. — source: ADR-0001 §Performance Implications (post-A1 amendment) + verification-log F6.
- **Outline pass on RTX 2060 at 1080p native (informative target)**: 0.8–1.5 ms. — source: ADR-0001 §Performance Implications.
- **Outline pass setup CPU**: <0.1 ms (CompositorEffect dispatch overhead). Budget 0.2 ms. — source: ADR-0001 §Performance Implications.
- **Memory overhead**: zero. Uses existing depth-stencil attachment; no new buffers. — source: ADR-0001 §Performance Implications.
- **Load time**: +0 to +50 ms for shader pre-compile (RDShaderFile pre-compile path per F5). — source: ADR-0001 §Performance Implications.

*UI framework rules pending — ADR-0004 G5 deferred to Settings & Accessibility production story.*
*FPS hands outline rules pending — ADR-0005 G3/G4/G5 require the actual hands-rendering production story.*
*Per-slot performance gates pending — ADR-0008 G1/G2 need Iris Xe + Windows Vulkan measurement.*

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController`, `SaveLoadService` |
| Variables / Functions | snake_case | `move_speed`, `take_damage()` |
| Signals | snake_case past tense | `health_changed`, `document_collected` |
| Files | snake_case matching class | `player_controller.gd`, `save_load_service.gd` |
| Scenes | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `LAYER_PLAYER` |

Source: `.claude/docs/technical-preferences.md`.

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Draw calls | ≤ 1500 per frame |
| Memory ceiling | ≤ 4 GB on minimum target hardware |

Source: `.claude/docs/technical-preferences.md`. ADR-0008 (Performance Budget Distribution) will divide this 16.6 ms budget into per-system slots when it reaches Accepted; until then, treat the global cap as advisory and profile against it.

### Approved Libraries / Addons

*None configured yet.* Add new dependencies via ADR (technical-preferences.md "Allowed Libraries / Addons" section is currently empty by design — every dependency must clear an architectural-decision review).

### Forbidden APIs (Godot 4.6)

These APIs are deprecated or unverified for Godot 4.6. Do NOT introduce them in new code; replace existing usages where encountered.

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` / `VisibilityNotifier3D` | `VisibleOnScreenNotifier2D` / `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` (string-based) | `signal.connect(callable)` | 4.0 |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `Skeleton3D.bone_pose_updated` signal | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |
| String-based `connect()` (in any form) | Typed signal connections | 4.0 |
| `$NodePath` lookups in `_process()` | `@onready var` cached reference | always |
| Untyped `Array` / `Dictionary` | `Array[Type]` / `Dictionary[K, V]` | 4.0+ |
| `Texture2D` in shader uniform parameters | `Texture` base type | 4.4 |
| Manual post-process viewport chains | `Compositor` + `CompositorEffect` | 4.3+ |
| GodotPhysics3D for new projects | Jolt Physics 3D (default since 4.6) | 4.6 |
| `BaseMaterial3D.stencil_mode = STENCIL_MODE_OUTLINE` for player-facing outlines | `STENCIL_MODE_CUSTOM` + per-tier `CompositorEffect` (per ADR-0001 IG 1–7); native API is world-space, violates Art Bible screen-space pillar | Sprint 01 finding F4 |
| Sampling stencil from a compute shader (`sample_stencil(SCREEN_UV)`) | Graphics-pipeline `RDPipelineDepthStencilState.enable_stencil = true` (per ADR-0001 §Key Interfaces post-A1) — stencil aspect is not sampleable | Sprint 01 finding F5 |
| Naive `(2·max_radius_px+1)²` outline scan as production algorithm | Jump-flood (Bgolus / dmlary reference) per ADR-0001 IG 7 | Sprint 01 finding F6 |

Source: `docs/engine-reference/godot/deprecated-apis.md`.

### Engine 4.4–4.6 Best Practices (Post-Cutoff)

The LLM's training data predates Godot 4.4. The following 4.4+ APIs are part of the project's mandated toolchain — use them where applicable:

- **GDScript 4.5+**: `@abstract` for required-override methods; variadic `Variant...` arguments; detailed Release-build script backtracing.
- **Resources 4.5+**: `duplicate_deep()` for nested-Resource isolation. Mandatory wherever `SaveGame` state is loaded (per ADR-0003 IG 3).
- **Physics 4.6**: Jolt is the default 3D physics engine. 2D physics unchanged.
- **Rendering 4.6**: Forward+ default; **Vulkan on both Linux and Windows** (D3D12 disabled per project Amendment A2 — `project.godot [rendering] rendering_device/driver.windows="vulkan"`); AgX tonemapper; SMAA 1x option (sharper than FXAA, cheaper than TAA); glow processes before tonemap (was after).
- **Rendering 4.5**: Shader Baker pre-compiles shaders to eliminate startup hitching; stencil buffer support; bent normal maps; specular occlusion.
- **Accessibility 4.5+**: AccessKit screen reader integration via `Control.accessibility_description` (verified Sprint 01 G1); `accessibility_role` is inferred from node type, NOT a settable property.
- **UI 4.6**: dual-focus split (mouse/touch separate from keyboard/gamepad). ADR-0004's `_unhandled_input + ui_cancel` design sidesteps this complexity.
- **Animation 4.6**: IK fully restored — CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK via `SkeletonModifier3D`.

Source: `docs/engine-reference/godot/current-best-practices.md`.

### Cross-Cutting Constraints

These apply to every layer and every story; they come from project-wide standards in `CLAUDE.md` + `.claude/rules/*` + `.claude/docs/coding-standards.md`.

- **Static typing required on all GDScript**: every `var` declares its type; every function declares parameter types and return type. Untyped `Variant` is a code smell unless explicitly justified.
- **Doc comments on public APIs**: every public class, public method, and exported property has a doc comment explaining intent (not just restating the signature).
- **Gameplay values are data-driven**: never hardcoded numeric tunings inside system code. Use exported config (Resources, JSON, ConfigFile) so designers can iterate without touching code.
- **Public methods are unit-testable via dependency injection**: prefer DI over singletons / autoloads for system-internal collaborators. Autoloads in this project are restricted to the 10 entries in ADR-0007 §Key Interfaces; everything else uses DI.
- **Verification-driven development**: write tests first when adding gameplay systems; for UI changes, verify with screenshots; compare expected to actual before marking work complete.
- **Test naming**: `[system]_[scenario]_[expected_result]` (per `.claude/rules/test-standards.md`). Every test has Arrange / Act / Assert structure.
- **Tests must be deterministic, isolated, no external state**: no random seeds, no time-dependent assertions, no filesystem / network / DB dependencies in unit tests. Use DI to mock external dependencies.
- **Every bug fix has a regression test** that would have caught the original bug.
- **Commits reference the relevant design document or task ID.**

### Project Conventions (recap from technical-preferences.md)

- **Engine**: Godot 4.6 (Forward+ rendering; Vulkan on both Linux and Windows per project Amendment A2 2026-04-30; Jolt 3D physics).
- **Language**: GDScript primary. Shader files: `.gdshader`. Native C++ extensions: GDExtension (only when invoked).
- **Target platforms**: PC (Linux + Windows, Steam). Period authenticity pillar forbids modern UX conveniences (objective markers, minimap, kill cams, ping systems).
- **Input**: KB/M primary; gamepad partial (full menu/gameplay nav; rebinding parity post-MVP). Per ADR-0004 IG 14 (Sprint 01 finding F3): every `ui_*` action MUST have both KB/M and gamepad bindings explicitly declared in `project.godot [input]`.
- **Test framework**: GUT (Godot Unit Test) for GDScript unit tests. CI: `godot --headless --script tests/gdunit4_runner.gd` on every push to main and every PR. No merge if tests fail.
