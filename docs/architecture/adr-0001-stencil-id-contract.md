# ADR-0001: Stencil ID Contract for Tiered Outline Rendering

## Status

**Proposed** — must remain Proposed until two verification gates pass (see Risks). Stories that depend on this ADR are blocked until status is Accepted.

## Date

2026-04-19

## Last Verified

2026-04-19

## Decision Makers

User (project owner) · godot-shader-specialist (technical validation) · `/architecture-decision` skill

## Summary

Every renderable object in *The Paris Affair* writes one of four reserved stencil-buffer values (0 = no outline, 1 = heaviest tier 4 px, 2 = medium tier 2.5 px, 3 = light tier 1.5 px) so the comic-book outline `CompositorEffect` can apply the correct kernel width per pixel. Tier assignment lives in GDScript at spawn time for dynamic objects, scene-baked for static environment, and can be reassigned at runtime via an escape-hatch method.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering |
| **Knowledge Risk** | HIGH — Stencil buffer support is a Godot 4.5 feature (post-LLM-cutoff). `CompositorEffect` (4.3+) is in training data; per-material stencil write API and `CompositorEffect` stencil read API are post-cutoff. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/modules/rendering.md`, Art Bible Sections 3.4, 8C, 8F, 8J |
| **Post-Cutoff APIs Used** | Stencil buffer write from `ShaderMaterial` or `BaseMaterial3D` (4.5); stencil buffer read from `CompositorEffect` shader (4.5); D3D12 backend default on Windows (4.6); Shader Baker for `CompositorEffect` shaders (4.5) |
| **Verification Required** | (1) Confirm whether `BaseMaterial3D` exposes a stencil write value property in the 4.6 editor inspector — if not, mandatory `ShaderMaterial` path. (2) Confirm `CompositorEffect` GLSL shader can bind/sample the stencil buffer on **both** Vulkan (Linux) and D3D12 (Windows) backends — cross-platform correctness risk. (3) Profile the outline pass on integrated graphics (Intel Iris Xe-class) at 1080p native and at 75% render scale. (4) Confirm Shader Baker handles `CompositorEffect` shaders the same as `ShaderMaterial` resources. |

> **Note**: HIGH Knowledge Risk. This ADR must be re-validated if the project upgrades engine versions. If APIs change, flag as Superseded and write a new ADR.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — foundational |
| **Enables** | ADR-2 (Signal Bus + Event Taxonomy), ADR-3 (Save Format Contract), ADR-4 (UI Framework), and all subsequent ADRs touching renderable objects |
| **Blocks** | All system GDDs that spawn outlined objects: Player Character, Stealth AI, Combat & Damage, Inventory & Gadgets, Document Collection, Civilian AI, Mission & Level Scripting, and the Outline Pipeline implementation itself. None can be authored until this ADR reaches Accepted. |
| **Ordering Note** | First ADR for the project. Two follow-on verification tasks must complete before status moves Proposed → Accepted (see Risks). |

## Context

### Problem Statement

The comic-book outline post-process (Art Bible 8F) is the single most important visual fingerprint of *The Paris Affair* (Art Bible Section 1, Visual Identity Statement). It must render outlines at three different pixel weights (Section 3.4 / 8C: 4 px, 2.5 px, 1.5 px at 1080p) on a per-object-class basis — Eve and key interactive objects in the heaviest tier, PHANTOM guards in medium, environment in light. Without a project-wide contract for **how** each system marks its objects' tier identity, outline rendering will be inconsistent: some systems may not mark their objects at all (default unstyled outlines), others may use conflicting schemes, and the outline shader cannot select the right kernel width.

This decision must be made **before** any system that spawns visible objects is designed (Player Character, Stealth AI, Combat, Inventory, Document Collection, Civilian AI, Mission Scripting). Otherwise each system GDD will retroactively need a "how do I mark my outline tier?" section.

### Current State

Project is in pre-production. No source code exists. No existing rendering architecture to migrate from. The outline shader itself has not been written.

### Constraints

- **Engine: Godot 4.6, Forward+ renderer.** Stencil buffer support added in Godot 4.5 (post-LLM-cutoff per `VERSION.md`). The outline pass is implemented as a `CompositorEffect` (4.3+ pattern, in training data — see `rendering.md`).
- **Performance: outline pass ≤2 ms per frame (12% of 16.6 ms 60 fps budget)** per Art Bible 8F. Target 0.8–1.5 ms on RTX 2060-class hardware.
- **Cross-platform: Linux (Vulkan) + Windows (D3D12 default since 4.6).** Stencil read in shaders must work identically on both backends.
- **Minimum-spec hardware: Intel Iris Xe integrated graphics.** Resolution-scale fallback (render at 75% internal, upscale to native) must be supported.
- **First-time solo Godot dev with 6–9 month MVP timeline.** Architecture must be simple enough to implement and debug without specialist knowledge.

### Requirements

- Every visible object must declare its outline tier (or "no outline") through one project-wide mechanism.
- The outline `CompositorEffect` shader must select kernel width per pixel based on the tier marker of the rendered object underneath.
- Tier assignment must work for **dynamic objects** (spawned at runtime by systems like Stealth AI, Combat, Inventory) AND **static environment geometry** (scene-baked).
- An escape-hatch mechanism must exist for the rare case where an object needs its tier reassigned at runtime (e.g., the swinging lamp in Lower Scaffolds becoming a focal moment).
- The contract must remain valid across both Vulkan (Linux) and D3D12 (Windows) backends.

## Decision

**Use the GPU stencil buffer as the per-pixel tier marker, with four reserved integer values:**

| Stencil Value | Tier | Outline Weight at 1080p | Assigned To |
|---|---|---|---|
| **0** | None | No outline (skipped) | Default cleared value; invisible collision meshes; the document-overlay dim ColorRect; any object that intentionally receives no outline |
| **1** | Heaviest | 4 px | Eve Sterling, gadget pickups, bomb device, uncollected documents, comedic hero props (signage, labeled crates) when locally promoted |
| **2** | Medium | 2.5 px | PHANTOM guards (all variants, all helmet types) |
| **3** | Light | 1.5 px | Environment geometry (ironwork, furniture, dressing), Paris civilians |

### Architecture

```
                    ┌────────────────────────────────┐
                    │  GAMEPLAY SYSTEMS (spawners)   │
                    │  Stealth AI, Combat, Inventory,│
                    │  Document Collection, Civilian │
                    │  AI, Mission Scripting,        │
                    │  Player Character              │
                    └──────────────┬─────────────────┘
                                   │ spawn-time:
                                   │ material.set_stencil_tier(N)
                                   ▼
                    ┌────────────────────────────────┐
                    │  ShaderMaterial (per object)   │
                    │  Writes stencil = N during     │
                    │  opaque pass                   │
                    └──────────────┬─────────────────┘
                                   │ rendered into
                                   ▼
              ┌───────────────────────────────────────────────┐
              │  Frame buffer: color + depth + STENCIL plane  │
              │  (D24_S8 format on Vulkan/D3D12)              │
              └──────────────────┬────────────────────────────┘
                                 │ read by
                                 ▼
                    ┌────────────────────────────────┐
                    │  Outline CompositorEffect      │
                    │  Reads stencil per pixel.      │
                    │  Branch: 0→discard, 1→4 px,    │
                    │  2→2.5 px, 3→1.5 px.           │
                    │  Sobel edge-detect at chosen   │
                    │  kernel. Writes near-black     │
                    │  outline color (#1A1A1A).      │
                    └────────────────────────────────┘
```

### Key Interfaces

```gdscript
# Project-wide constants (autoload or static class)
class_name OutlineTier extends RefCounted

const NONE      : int = 0   # no outline
const HEAVIEST  : int = 1   # 4   px @ 1080p — Eve, key interactives
const MEDIUM    : int = 2   # 2.5 px @ 1080p — PHANTOM guards
const LIGHT     : int = 3   # 1.5 px @ 1080p — environment, civilians

# Convenience setter for any MeshInstance3D (helper, not a base class)
static func set_tier(mesh: MeshInstance3D, tier: int) -> void:
    # Implementation depends on verification gate result:
    # If BaseMaterial3D exposes stencil_write_value: set on each material slot
    # If only ShaderMaterial: ensure mesh uses tier-aware shader, set uniform
    pass
```

```glsl
// Outline CompositorEffect fragment shader (pseudocode — exact stencil read API
// pending verification gate; see Risks).

uniform sampler2D depth_stencil_texture;    // exact hint name TBD
uniform vec4 outline_color = vec4(0.10, 0.10, 0.10, 1.0); // near-black per Art Bible 4.4
uniform float resolution_scale = 1.0;        // 1.0 native, 0.75 integrated default

void fragment() {
    int tier = sample_stencil(SCREEN_UV);    // exact API TBD
    if (tier == 0) discard;

    float kernel_px;
    if      (tier == 1) kernel_px = 4.0;
    else if (tier == 2) kernel_px = 2.5;
    else                kernel_px = 1.5;     // tier == 3

    float kernel = kernel_px * resolution_scale / SCREEN_PIXEL_SIZE.y;
    float edge = sobel_edge_detect(SCREEN_UV, kernel);
    if (edge < EDGE_THRESHOLD) discard;
    COLOR = outline_color;
}
```

### Implementation Guidelines

1. **Tier assignment ownership.** Every gameplay system that spawns visible objects is responsible for calling `OutlineTier.set_tier(mesh, OutlineTier.X)` at spawn time. Systems may NOT default to "the engine handles this" — there is no engine default; unmarked meshes will write stencil 0 (no outline).
2. **Static environment.** Set the stencil tier on the level scene's environment meshes once in the `.tscn`. Do not re-set at runtime unless the escape hatch is invoked.
3. **Escape hatch — runtime reassignment.** A controller script may call `OutlineTier.set_tier(mesh, new_tier)` at any time to change a mesh's outline tier. Example: the swinging lamp in Lower Scaffolds is normally tier 3 (Light); during a scripted focal moment, a lamp controller can reassign it to tier 1 (Heaviest) to draw the player's eye. The shader does not change — only the stencil value on the material.
4. **Comedic hero props (Art Bible 3.4 / 1.3).** Comedic environmental elements (oversized signage, labeled crates) get tier 1 (Heaviest) **locally** in their composition, regardless of being environment geometry. Set this in the prop's scene.
5. **Default for new systems.** When in doubt, use tier 3 (Light) for environment-class objects and tier 2 (Medium) for hostile/character-class objects. Tier 1 (Heaviest) is reserved for explicit "look here" objects.
6. **Resolution scale.** On Intel Iris Xe and equivalent integrated graphics (detected at startup), the outline shader receives `resolution_scale = 0.75` and the engine's render resolution is set accordingly. On RTX 2060 and above, `resolution_scale = 1.0`. Detection logic lives in `Settings & Accessibility` (system 23).

## Alternatives Considered

### Alternative 1: Visual layers / `VisualInstance3D.layers` bitmask

- **Description**: Use Godot's existing visual-layer bitmask (4 distinct layer indices for tiers 1/2/3 + None). Outline `CompositorEffect` runs N times, once per layer mask, each pass restricted to objects in that layer.
- **Pros**: No stencil buffer dependency — works on every Godot version since 3.x. No post-cutoff API risk. Straightforward to debug (layers are visible in the inspector).
- **Cons**: Requires N full-screen passes (N = number of tiers = 3) instead of one branching pass. Each pass consumes draw call budget. Layer-based filtering happens at the visibility check, not per-pixel — fragments outside the active layer still execute the shader and discard, costing bandwidth.
- **Estimated Effort**: Lower than chosen approach (no API uncertainty), but higher per-frame cost.
- **Rejection Reason**: Three full-screen passes risk exceeding the 2 ms budget on integrated graphics. The chosen single-pass branching approach has lower runtime cost and is more idiomatic for the engine version we are pinned to.

### Alternative 2: Single-pass uniform-weight outline (no tier hierarchy)

- **Description**: Give up tiered outline weights entirely. One outline weight (e.g., 2 px) for everything. No stencil buffer, no per-object marker.
- **Pros**: Simplest possible implementation. No API risk. Lowest per-frame cost.
- **Cons**: Loses the visual hierarchy that Art Bible 3.4 establishes as the project's core figure-ground system. Eve does not stand out from PHANTOM guards by outline weight; gadget pickups do not pop out from environment dressing. The outline becomes wallpaper instead of communication.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Violates Art Bible Section 1 Principle 2 (Silhouette Owns Readability) and Pillar 3 (Stealth is Theatre — the player must read the scene clearly to make dramatic choices). Listed here as a documented fallback if both verification gates fail and the chosen approach is unimplementable.

### Alternative 3: Multi-pass per tier with discard masking

- **Description**: Three separate `CompositorEffect` passes, one per tier. Each pass uses stencil masking to process only its tier's pixels, discarding others early.
- **Pros**: Each tier's outline can be tuned independently (kernel shape, falloff curve). More debuggable — toggle individual tiers on/off.
- **Cons**: Three shader resources to maintain; three `CompositorEffect` slots in the chain. Slightly more complex Compositor configuration. Total runtime cost is comparable to single-pass branching since pixels not in the tier discard early, but startup compile cost is 3× higher.
- **Estimated Effort**: Higher than chosen approach.
- **Rejection Reason**: For a single-player game with three fixed tiers, the single-pass branching approach is simpler. If runtime debugging proves harder than expected, this can be retrofitted.

### Alternative 4: Vertex color channel as tier signal

- **Description**: Encode tier in a vertex color channel (e.g., red 0.0/0.5/1.0 for tiers 3/2/1) written by mesh authors. Render a separate "tier buffer" pre-pass; outline pass reads it.
- **Pros**: Avoids the stencil API uncertainty entirely.
- **Cons**: Adds a pre-pass draw call. Burdens art pipeline (every authored mesh needs the right vertex color). Couples runtime tier to mesh authoring rather than spawn-time logic — can't easily reassign at runtime without modifying mesh data.
- **Estimated Effort**: Higher than chosen approach.
- **Rejection Reason**: The escape-hatch use case (runtime tier reassignment) becomes painful. The art-pipeline burden is significant.

## Consequences

### Positive

- One project-wide contract eliminates per-system "how do I outline?" decisions and the inconsistency they would cause.
- Single-pass per-pixel branching is the cheapest runtime cost option that preserves the tier hierarchy.
- Spawn-time GDScript assignment keeps tier logic where the system that owns the object can see it.
- Escape hatch for runtime tier reassignment supports specific design moments (e.g., the swinging lamp).
- Static environment can be scene-baked, no runtime cost for the bulk of geometry.
- `STENCIL_VALUE_NONE = 0` is the default cleared stencil value, so unmarked geometry safely receives no outline rather than producing visual garbage.

### Negative

- HIGH knowledge risk: two API uncertainties must be resolved by editor verification before the ADR can move to Accepted. Implementation work cannot start until then.
- Cross-platform stencil readback risk: a stencil read that works on Vulkan/Linux may silently fail on D3D12/Windows. Cross-platform testing is required during the earliest Outline Pipeline prototype.
- Every gameplay system gains a one-line responsibility (call `OutlineTier.set_tier`) at spawn time. Easy to forget during initial implementation; will require code review discipline.
- `BaseMaterial3D` may not expose stencil control in the inspector, in which case all outlined objects must use a custom `ShaderMaterial`. This trades editor convenience for control.

### Neutral

- The outline color is a single near-black uniform (`#1A1A1A`) — not tier-specific. Tiers vary only by kernel width.
- Project commits to using stencil values 0–3. The remaining 252 stencil values (8-bit stencil plane) remain unused by this contract; future ADRs may claim others (e.g., for portal/depth effects).

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| `BaseMaterial3D` does not expose stencil_write_value in 4.6 inspector → all outlined meshes need custom `ShaderMaterial` | MEDIUM | MEDIUM | Verification gate 1: open Godot 4.6 editor, inspect `BaseMaterial3D` for stencil property. If absent, design the project's standard `ShaderMaterial` template (with PBR-equivalent uniforms) before any system GDD authoring proceeds. Document the template as a follow-up ADR. |
| `CompositorEffect` shader cannot read stencil buffer in 4.6 (no `hint_stencil_texture` uniform, no `RenderingDevice` accessor) | MEDIUM | HIGH | Verification gate 2: write a 30-minute editor prototype. If unreadable from `CompositorEffect`, fall back to **Alternative 1 (visual layers)** and update this ADR. Do NOT proceed to Outline Pipeline GDD without resolving. |
| Stencil readback works on Vulkan but fails on D3D12 (or vice versa) — cross-platform correctness bug | MEDIUM | HIGH | Verification gate 3: prototype on both Linux/Vulkan and Windows/D3D12 during initial Outline Pipeline implementation. If divergence: either constrain to one backend per platform with platform-specific shader paths, or fall back to Alternative 1 (layer-based, backend-agnostic). |
| Per-pixel stencil branching exceeds 2 ms budget on Intel Iris Xe at 1080p | LOW | MEDIUM | Resolution-scale 75% is **default-on** for integrated graphics; brings pixel count down ~43%. Detection at startup. |
| Gameplay systems forget to call `OutlineTier.set_tier` at spawn time, producing unstyled (no-outline) objects | MEDIUM | LOW | Code review checklist; project lint rule (where feasible) flagging `MeshInstance3D` instantiations not paired with a `set_tier` call. |
| 4.6 D3D12 backend has stencil-read quirks not yet documented | LOW | HIGH | Test on Windows D3D12 in week 1 of prototyping. If quirks surface, file engine-reference module update and revise this ADR. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (frame time) — outline pass setup | N/A (no project) | <0.1 ms (CompositorEffect dispatch overhead) | 0.2 ms |
| GPU (frame time) — outline pass execution at 1080p RTX 2060 | N/A | 0.8–1.5 ms (Sobel edge-detect + per-pixel stencil branch) | 2.0 ms (Art Bible 8F) |
| GPU (frame time) — outline pass at 75% scale on Iris Xe | N/A | ~1.2–2.0 ms (1.17M pixels vs 2.07M native) | 2.0 ms (must fit) |
| Memory — stencil contract overhead | N/A | Zero — uses existing depth-stencil attachment, no new buffers | N/A |
| Load Time | N/A | +0 to +50 ms (Shader Baker pre-compiles outline shader; without baker, +200–500 ms first scene load) | <1 s total |

## Migration Plan

This is the project's first ADR. No existing code to migrate. Implementation order:

1. Verification gates: 30-minute editor prototype to confirm stencil write API on `BaseMaterial3D`/`ShaderMaterial` and stencil read API in `CompositorEffect` shader on Vulkan and D3D12.
2. If both gates pass: implement `OutlineTier` constants/helper class as autoload or static class. Author the outline `CompositorEffect` shader.
3. Set ADR status Proposed → Accepted.
4. Begin authoring dependent system GDDs (Player Character, Stealth AI, etc.) — each GDD's spawn logic must call `OutlineTier.set_tier`.

**Rollback plan**: If gate 2 fails irrecoverably, supersede this ADR with a new one selecting Alternative 1 (visual layers). All system GDDs would then need to specify their visual layer instead of stencil tier, but the conceptual contract (object class → outline weight) remains identical — only the engine mechanism changes.

## Validation Criteria

- [ ] **Gate 1 — Material API verified.** Document whether `BaseMaterial3D` exposes stencil control or whether `ShaderMaterial` is mandatory. (Pending.)
- [ ] **Gate 2 — `CompositorEffect` stencil read verified on Vulkan/Linux.** Working shader that reads stencil and applies different kernel widths per tier. (Pending.)
- [ ] **Gate 3 — Same shader verified on D3D12/Windows** with identical visual output. (Pending.)
- [ ] **Gate 4 — Performance verified.** Outline pass under 2 ms on RTX 2060 at 1080p native, and under 2 ms on Iris Xe at 75% scale. (Pending — measure during initial prototype.)
- [ ] All MVP gameplay systems' GDDs reference this ADR and specify which tier their spawned objects belong to. (Pending GDD authoring.)
- [ ] Code review checklist includes "Does every `MeshInstance3D` instantiation have a paired `OutlineTier.set_tier` call?" (Pending checklist authoring.)

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/art/art-bible.md` | Visual Identity (Section 1, Principle 2: Silhouette Owns Readability) | "Lighting in this game is diegetic — silhouette legibility carries the entire burden of figure-ground separation" | Per-pixel outline tier ensures Eve and key objects pop visually regardless of diegetic lighting variance |
| `design/art/art-bible.md` | Shape Language (Section 3.4: Hero Shapes vs Supporting Shapes) | "Outline weight is the hierarchy system" | Stencil contract is the engine implementation of the outline-weight hierarchy |
| `design/art/art-bible.md` | Asset Standards (Section 8C, 8F) | "Outline weights at 1080p reference: 4 px / 2.5 px / 1.5 px" + "Outline pass ≤2 ms (12% of 16.6 ms frame budget)" | Stencil values 1/2/3 map directly to those pixel weights; per-pixel branching keeps cost within budget on RTX 2060 and at scaled resolution on Iris Xe |
| `design/gdd/systems-index.md` | Outline Pipeline (system 4) | "Stencil-ID contract is cross-cutting requirement; every system spawning outlined objects must write a stencil tier at spawn time" | This ADR IS that contract — defines the values, the assignment mechanism, and the escape hatch |

## Related

- **Art Bible** Sections 1, 3.4, 4 (color palette including outline color `#1A1A1A`), 8C, 8F, 8J — establish the visual requirements this ADR implements
- **Systems Index** ADR-1 row — this ADR
- **ADR-0005 (FPS Hands Outline Rendering)** — **single documented exception to this contract**. Eve's FPS hands mesh does NOT write the stencil buffer and does NOT call `OutlineTier.set_tier`. Hands render in a `SubViewport` at FOV 55° using an inverted-hull shader (`HandsOutlineMaterial`); the outline is extruded hull geometry rather than a stencil kernel. Visually matches Tier 1 (4 px at 1080p, `#1A1A1A`) but the mechanism diverges. This carve-out exists because `SubViewport` has a separate framebuffer from the main camera's `CompositorEffect`, so stencil writes from hands never reach the outline pass. Cross-reference added 2026-04-20 per `/review-all-gdds` cross-review B1. **No other exceptions exist or should be created** — ADR-0005 is explicitly bounded to this one MeshInstance3D.
- **Future ADR**: `Outline Shader Implementation` (detail-level decision about Sobel vs Laplacian kernel, edge threshold tuning) — out of scope here; this ADR establishes the contract, not the algorithm internals
- **Future system GDD**: Outline Pipeline (system 4) — implementation of the `CompositorEffect`, consuming this contract
