# Asset Specs — System: Player Character (Eve Sterling)

> **Source GDD**: `design/gdd/player-character.md` (§Visual/Audio Requirements)
> **Art Bible**: `design/art/art-bible.md` (§5.1 Player Character — Eve Sterling; §3.4 Hero Shapes; §8 Asset Standards)
> **Governing ADR**: `docs/architecture/adr-0005-fps-hands-outline-rendering.md` (FPS hands inverted-hull SubViewport pattern)
> **Sprint**: 09 (`production/sprints/sprint-09-asset-commission-hybrid.md`)
> **Generated**: 2026-05-08
> **Status**: 2 assets specced / 0 approved / 0 in production / 0 done

## Tier Summary

| Asset | Tier | Sprint 09 Deliverable | Pipeline |
|---|---|---|---|
| ASSET-001 — Eve FPS Hands | **T3** | Spec doc only — flagged for external commission | NOT generated via Blender MCP. Requires specialist (Mixamo / FPS-hands marketplace / human modeler). Topology + finger rig + weapon-slot precision out of scope for AI generators. |
| ASSET-002 — Eve Full Body | **T2** | Base mesh `.glb` exported to `assets/models/player-character/char_eve_sterling.glb` | Blender MCP — Hyper3D text-to-3D → import → cleanup → export. Rig deferred to Sprint 09b. |

## Doc-Hygiene Flag (open inconsistency)

`design/gdd/player-character.md` line 707 specifies FPS hands at "~5k tris", but `design/art/art-bible.md` §8D (Engine Hard Budgets) caps Eve FPS hands at **2,000 tris LOD0**. The art bible is the authoritative budget per its own section header ("Engine Hard Budgets"). This spec follows the art bible (2,000) and flags the player-character GDD line for reconciliation in a future doc-hygiene pass.

---

## ASSET-001 — Eve FPS Hands

| Field | Value |
|---|---|
| Asset ID | ASSET-001 |
| Category | Character — first-person rigged mesh |
| Tier | T3 (spec only — external commission) |
| File path (target) | `assets/models/player-character/char_eve_fps_hands.glb` |
| Material name | `mat_eve_fps_hands_navy_glove` |
| Naming convention | `char_eve_fps_hands.glb` (per art bible §8B — `char_[name]_[variant].glb`) |
| Triangle budget LOD0 | **2,000** (art bible §8D — see doc-hygiene flag above) |
| LOD count | 1 (never at distance — art bible §8H) |
| Texture resolution | 1024 × 1024 (art bible §8D character body cap) |
| Material slots | 1 (sleeve + glove unified) |
| Texture content | Flat painted color + minimal seam detail. NO PBR maps. NO photographic source. NO procedural noise. (art bible §6.2) |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | YES — minimal arm + hand skeleton, **18 bones** total: shoulder, elbow, wrist, 5 finger chains (per `player-character.md` §Visual-FPS-Hands) |
| Skin weights | Per-vertex blended; no rigid parenting |
| FOV target | **55°** (rendered inside SubViewport per ADR-0005, narrower than world's 75°, prevents stretched-gorilla-arms and world-clipping) |
| Outline tier | **HEAVIEST** (4 px @ 1080p, color `#1A1A1A`) — art bible §8C |
| Outline implementation | **ADR-0005 inverted-hull SubViewport pattern** — hands do NOT call `OutlineTier.set_tier`, do NOT write stencil values. Outline baked inside SubViewport via `HandsOutlineMaterial` two-pass shader (front-face-culled inverted-hull + standard fill). |
| Outline width uniform | `outline_world_width = 0.006` local mesh units; `resolution_scale` uniform wired to `Settings.get_resolution_scale()` |
| Default pose | Arms down, slightly forward, hands relaxed. "Idle FPS rest" when no gadget is equipped. |
| Attach points | `HandAnchor` (child of `Camera3D`); `LeftHandIK` and `RightHandIK` markers for gadget-specific two-handed poses |
| UV mapping | Single UV unwrap (UV0). Seams hidden inside cuff edges or wrist underside. 4 px margin at 1024 px. |
| Status | **External commission needed** |

### Visual Description

A pair of slim, structured first-person hands and forearms, gloved and sleeved in midnight-navy, framing the lower portion of the FPS view. The silhouette reads as a *tailored interruption* of the world's geometry — square cuffs, deliberate shoulder line where the sleeve meets the camera frame edge, no skin showing between glove and sleeve. The glove fits like a second skin, no creasing. The thumb and forefinger are the most expressive joints (used for interact reach). When the gadget belt is the source pose, the right hand rests slightly higher and angled inward — never casually limp. The single overall read is "she is ready, she is composed, and she is the most precise object on the screen at any moment."

### Art Bible Anchors

- **§5.1 Player Character — Eve Sterling**: Courrèges 1965 reference, midnight-navy `#15264A` jacket/sleeve. Square shoulders, no lapel softness. Stiff and deliberate pose, theatrical composure.
- **§3.4 Hero Shapes vs. Supporting Shapes**: Eve = HEAVIEST outline weight. Eye goes here first.
- **§8C Outline weights**: 4 px @ 1080p, `#1A1A1A`. Implementation per ADR-0005 (inverted-hull, NOT stencil — hands are the single mesh class exception to ADR-0001's stencil contract).
- **§8D Polycount**: 2,000 tris LOD0.
- **§8D Texture cap**: 1024 × 1024.
- **§8D Material slots**: 2 max for character; 1 used here (sleeve + glove unified).
- **§6.2 Texture Philosophy**: flat painted color, no PBR, no photographic source.

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Sleeve and glove primary | `#15264A` (midnight-navy) | Art bible §5.1 |
| Optional white-broken cuff edge break | `#F2E8C8` (Parchment) | Art bible §4.1 |
| Outline color | `#1A1A1A` | Art bible §8C |

### Commission Brief (for external specialist)

```
ASSET BRIEF — THE PARIS AFFAIR
================================
Asset name:         char_eve_fps_hands
Asset category:     Character — first-person rigged mesh
Triangle budget:    2,000 LOD0
Material slots:     1
Texture resolution: 1024 × 1024
Texture content:    Flat painted color + minimal seam detail.
                    NO normal/roughness/metallic maps.
                    NO photographic source.
                    NO procedural noise.
Color palette:      Sleeve/glove: #15264A (midnight-navy).
                    Optional cuff break: #F2E8C8 (Parchment).
UV mapping:         Single UV unwrap (UV0). No overlapping. Seams
                    hidden inside cuff edges or wrist underside.
                    4 px margin at 1024 px.
Rigging:            YES. 18 bones: shoulder, elbow, wrist, 5 finger
                    chains. Y-up, Z-forward.
                    Provide skeleton spec separately on request.
File format:        glTF 2.0 binary (.glb). Y-up, Z-forward.
LOD delivery:       1 LOD (LOD0 only — hands are never at distance).
Naming convention:  snake_case. No spaces. No special characters
                    except underscore.
Outline test:       Render the mesh in flat-lit white with a 4 px
                    black edge trace at 1080p reference. Submit this
                    render alongside the model file.

Pose deliverables:  (1) Default rest — arms down, slightly forward,
                        hands relaxed.
                    (2) Interact reach — right hand forward, fingers
                        slightly extended, ~150 ms ease-out animation.
                    (3) Two-handed gadget pose — both hands centred,
                        wrist anchors usable for IK retarget.

References to send:  art bible §5.1 + this brief + this game's
                     Eve Sterling reference sheet.
```

### Generation Prompt

> NOT APPLICABLE — Tier 3, external commission. AI generators (Hyper3D, Hunyuan3D, Sketchfab) cannot reliably produce FPS-hands topology with finger rigs and weapon-slot precision. This asset is excluded from Sprint 09 MCP generation.

---

## ASSET-002 — Eve Full Body (Base Mesh)

| Field | Value |
|---|---|
| Asset ID | ASSET-002 |
| Category | Character — full-body rigged mesh (rig deferred) |
| Tier | T2 (base mesh; rig deferred to Sprint 09b) |
| File path (target) | `assets/models/player-character/char_eve_sterling.glb` |
| Material name | `mat_eve_sterling_body` (costume) + `mat_eve_sterling_face` (head, separated) |
| Naming convention | `char_eve_sterling.glb` (per art bible §8B example) |
| Triangle budget LOD0 | **4,500** (art bible §8D — Eve full body, cutscene only) |
| LOD count | 1 (fixed cutscene camera distance — art bible §8H) |
| Texture resolution | 1024 × 1024 body + 512 × 512 face (separated, art bible §8D) |
| Material slots | 2 (body/costume + face/head separated) |
| Texture content | Flat painted color + hand-painted geometric pattern. NO PBR maps. NO photographic source. NO procedural noise. (art bible §6.2) |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO in Sprint 09 — base mesh only. Rig deferred (Sprint 09b). T-pose A-pose acceptable. |
| Outline tier | **HEAVIEST** (4 px @ 1080p, `#1A1A1A`) — art bible §8C — Eve = hero shape |
| Outline implementation | **ADR-0001 stencil tier 1** (HEAVIEST) — at scene-load time, MeshInstance3D for Eve sets stencil ref to tier 1 per ADR-0001. (Distinct from ASSET-001's ADR-0005 inverted-hull — full body uses world-pipeline outline.) |
| Use case | VS-tier mirror reflection (per `player-character.md` §Visual-Mirror-Reflection — OQ-4); cutscenes; promotional / key-art reference |
| UV mapping | Two UV unwraps: body (UV0) + face (UV1, separated atlas at 512²). No overlapping. Seams hidden inside costume edges or back of head. 4 px margin at 1024 px. |
| Status | **Needed (base mesh; rig deferred)** |

### Visual Description

Eve Sterling stands at the centre of frame in a perfectly composed weight-neutral rest pose, arms slightly away from the body — *ready, not casual*. Her silhouette is the most geometrically precise shape on screen: a single hard rectangle (the structured collarless jacket) sitting atop a tapered narrow line (the trouser), the whole figure reading as a deliberate verticality against any background. The blunt jaw-length bob is one more flat geometric element — a single shape against the neckline. The Eiffel Grey gadget belt rides low and breaks the navy expanse with rectangular Eiffel Grey hardware in a horizontal band. Black square-toe block-heel boots ground the stance. Her face is deadpan-attentive — eyes slightly wide, mouth closed, neither performing nor hiding. The whole figure reads "the most composed shape in the room" at any distance from thumbnail to close-up.

### Art Bible Anchors

- **§5.1 Player Character — Eve Sterling** (the canonical character sheet — every detail here lifts directly from §5.1):
  - Collarless structured jacket, midnight-navy `#15264A`, Courrèges 1965, square shoulders, no lapel softness, hem just below hip
  - Thin BQA-blue piped seam `#1B3A6B` at jacket lapel edge — only faction signal
  - Tapered ankle trouser, midnight-navy `#15264A`
  - Low-slung matte gadget belt, Eiffel Grey `#6B7280`, rectangular hardware
  - Square-toe block heel boots, black leather
  - Blunt jaw-length bob, near-black with cool-tint highlight (one flat geometric shape against the neck)
  - Stiff and deliberate pose; theatrical composure, never naturalistic fidget; weight-neutral rest, arms slightly away from body
  - Deadpan-attentive default expression
- **§3.1 Character Silhouette Philosophy**: Eve = "structured A-line silhouette: tailored jacket with… tapered trouser, small-profile gadget belt, clean shoulder line. Her shape is the most geometrically precise in any crowd."
- **§3.4 Hero Shapes**: HEAVIEST outline weight (eye goes here first).
- **§4.1 Primary Palette**: BQA Blue, Eiffel Grey, midnight-navy (kin to BQA Blue).
- **§5.4 LOD Philosophy**: preserve silhouette geometry and gadget belt mass at all distances; face detail is cutscene-only.
- **§6.2 Texture Philosophy**: flat painted color + hand-painted pattern; the bomb device and Eve's jacket / gadget belt are listed as **unique surfaces** (one UV unwrap, no tiling).
- **§8D Polycount**: 4,500 tris LOD0.
- **§8D Texture cap**: 1024 body + 512 face.
- **§8D Material slots**: 2 (body + face separated).
- **§8H LOD**: 1 LOD only (fixed cutscene camera distance).

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Jacket primary | `#15264A` (midnight-navy) | Art bible §5.1 |
| Jacket lapel piping | `#1B3A6B` (BQA Blue) | Art bible §5.1 + §4.1 |
| Trouser primary | `#15264A` (midnight-navy) | Art bible §5.1 |
| Gadget belt + hardware | `#6B7280` (Eiffel Grey) | Art bible §5.1 + §4.1 |
| Boots | `#1A1A1A` (near-black) | Art bible §5.1 |
| Hair primary | `#0F1115` (near-black) | Derived from §5.1 "near-black with cool-tint highlight" |
| Hair highlight | `#1A2A3A` (cool-tint deep blue) | Derived from §5.1 |
| Skin (face/hands) | Period flat-painted neutral, NO realism. Suggest `#E5C9A8` warm parchment-toned base. | New (not pinned in §5.1; flagged for art-director sign-off if shifted) |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt (for `mcp__blender__generate_hyper3d_model_via_text`)

```
Stylized low-poly 3D character model of a 1965 British female secret agent
in mid-century mod fashion. Standing T-pose or A-pose, ready for rigging.

OUTFIT (one consistent silhouette):
- Collarless structured jacket in midnight navy (#15264A), square shoulders,
  no lapel softness, hem just below hip. A thin slightly-lighter blue piped
  seam runs along the jacket lapel edge (the only visible faction signal).
- Tapered ankle-length trousers, same midnight navy, narrow line.
- Low-slung matte gadget belt in cool grey (#6B7280) with compact rectangular
  hardware. Reads as a mod accessory belt, not a holster.
- Square-toe block-heel boots in black leather, low heel for stealth movement.
- Optional: black or navy gloves matching the sleeves.

HAIR:
- Precise blunt bob, jaw-length, near-black with cool-tint highlight.
- Reads as a single flat geometric shape against the neck. No movement softness,
  no flyaways.

FACE:
- Deadpan attentive expression: eyes slightly wide, mouth closed.
- Stylized, not realistic. Subtle period-correct makeup.

POSE:
- Stiff and deliberate, theatrical composure.
- Weight-neutral rest, arms slightly away from the body — ready, not casual.
- Standard A-pose for rigging.

STYLE:
- Stylized low-poly, comic-book aesthetic.
- Flat unlit shading reference. NO PBR, NO realism, NO normal maps.
- Inspired by Courrèges 1965 fashion + No One Lives Forever (2000) character art.
- Silhouette must read as deliberate and geometrically precise at thumbnail scale.

CONSTRAINTS:
- Target ~4,500 triangles total.
- Single 1024² body texture + separate 512² face texture.
- Y-up, Z-forward orientation.
- Symmetric topology, ready for humanoid rigging.

NEGATIVE PROMPT:
- No photographic realism, no PBR materials, no normal maps, no roughness maps.
- No combat poses, no weapons, no exaggerated proportions, no anime-style faces.
- No alarmed or stressed facial expression. No smile.
- No high-detail rivets, embroidery, or buckles — silhouette over surface noise.
- No Kate Archer orange catsuit — Eve wears navy structured tailoring, not a
  colored bodysuit.
```

### Generation Strategy

1. **First pass**: full prompt above via `mcp__blender__generate_hyper3d_model_via_text`
2. **Viewport review**: `mcp__blender__get_viewport_screenshot` — check silhouette against art bible §3.1 (geometric A-line, square shoulders, narrow trouser line, gadget belt mass)
3. **Pass criteria** (apply art bible §3.2 outline-first silhouette check): render the mesh in flat-lit white with a 1 px black edge trace; if the silhouette reads as deliberate geometric figure with separable jacket/trouser/belt/hair shapes, pass; if outlines merge or shape collapses, regenerate.
4. **Iteration limit**: 3 retries. If 3 retries fail, downgrade to T3 (spec only) and surface to user.
5. **Fallback**: try Hunyuan3D (`mcp__blender__generate_hunyuan3d_model`) if Hyper3D fails on silhouette.
6. **Cleanup in Blender** (`mcp__blender__execute_blender_code`):
   - Apply scale (1 Blender unit = 1 metre; Eve standing height ~1.7 m per `player-character.md` §F.8)
   - Decimate to 4,500 tris if over budget
   - Remove orphan data (loose verts, duplicate UVs, unused materials)
   - Strip any imported PBR maps; assign single flat unlit material
   - Set sRGB albedo only
7. **Export**: `.glb` (binary glTF 2.0) to `assets/models/player-character/char_eve_sterling.glb`
8. **Manifest update**: status `Base mesh — rig deferred`

### Out of Scope for Sprint 09 (this asset)

- Rigging (humanoid armature, weight painting, IK chains) — Sprint 09b
- Animations (idle, walk, death-cam pose) — post-rig
- Mirror reflection wiring in scene — Sprint 10+ (OQ-4)
- Cutscene-quality micro-expressions (raised brow, narrowed eyes, controlled near-smile) — bundled in mesh; activation via blendshapes is post-rig work
- Outline pipeline stencil-ref assignment at scene-load — Sprint 10+

---

## Cross-Asset Notes

### Outline pipeline split

The two assets use **different outline implementations** by design:

| Asset | Outline Path | Rationale |
|---|---|---|
| ASSET-001 — FPS hands | ADR-0005 inverted-hull SubViewport (single mesh class exception) | FPS hands are inside SubViewport at FOV 55° to prevent world-clipping; cannot share stencil with main viewport's depth/stencil buffer. |
| ASSET-002 — Full body | ADR-0001 stencil tier 1 (standard pipeline) | Full body renders in main world viewport at world FOV; uses standard stencil contract. |

Implementation contracts (per `docs/architecture/control-manifest.md`): hands MUST NOT call `OutlineTier.set_tier`; full body MUST set stencil ref to tier 1 at `_ready`.

### Forward dependencies

- **ADR-0005 G3 / G4 / G5** close inside the PC FPS-hands rendering production story (Sprint 10+) — this spec is one of the inputs to that story.
- **player-character.md OQ-4** (mirror reflection full body) closes when ASSET-002 ships and is wired in scene.
- **Sprint 09b** rigging story consumes the `char_eve_sterling.glb` base mesh from this sprint.
