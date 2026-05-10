# Asset Specs — Level: Plaza (Eiffel Tower Ground Level)

> **Source**: `design/art/art-bible.md` (§2 Plaza atmosphere; §4.3 Plaza color temperature; §6.1 Architectural Style; §6.2 Texture Philosophy; §6.3 Prop Density Rules; §8 Asset Standards)
> **Note**: `design/levels/plaza.md` does NOT exist — Sprint 09 spec authoring extracts directly from art bible §6 per pragmatic scope decision (level docs are a future deliverable when encounter layouts are designed via `/team-level`).
> **Sprint**: 09 (`production/sprints/sprint-09-asset-commission-hybrid.md`)
> **Generated**: 2026-05-10
> **Status**: 3 assets specced / 0 approved / 0 in production / 0 done

## Plaza Section Visual Identity (extract for context)

Per art bible §2: "Paris Night, Ground Level" — the player's first encounter with the Eiffel Tower at street level. Sparse, architectural, evening atmosphere with sodium street lamps creating warm Paris Amber pools against blue-grey iron ceiling.

Per §4.3 Plaza: warm ground (Paris Amber `#E8A020` lamp pools, orange cobblestone floor) vs. cool overhead (Moonlight Blue `#B0C4D8` floodlit steel canopy). The contrast is load-bearing for the section's read.

Per §6.3 Plaza density: **sparse, architectural** — one hero prop cluster (guard post, lamp standard, cobblestone pattern). Max 3 interactive props in any 10m radius. Environmental props are large-scale and few.

Per §6.1 Architectural Style: the canonical bay module for plaza-tier ironwork is **"wide, heavy base"** — one diagonal cross-brace, two horizontal rails, one vertical post, at correct plaza-tier aspect ratio.

## Tier Summary

| Asset | Tier | Sprint 09 Deliverable | Pipeline |
|---|---|---|---|
| ASSET-007 — Eiffel bay module (plaza-tier, wide heavy base) | **T1** | Final `.glb` to `assets/models/level-plaza/` | Image-first → image-to-3D → MCP cleanup (Path 4) |
| ASSET-008 — Period sodium street lamp | **T1** | Final `.glb` exported | Image-first → image-to-3D → MCP cleanup |
| ASSET-009 — Plaza kiosk / guard post | **T1** | Final `.glb` exported | Image-first → image-to-3D → MCP cleanup |

## Out of Scope (deferred or not in Sprint 09)

- **Cobblestone tiling material/texture** — flat painted texture per §6.2, not a mesh asset; deferred to texture pass (Sprint 10+)
- **Benches, planters, period signage** — additional prop density beyond the "max 3 interactive props per 10m" rule; deferred to follow-on level-asset sprint when encounter layouts are designed
- **Comedic absurdist signage** — per §6.3 "concentric stripe (mod / atomic motif) used only on comedic hero props" — separate spec when narrative writes the comedy beats
- **Floodlights illuminating the steel canopy** — per §8G Plaza lighting "2-3 SpotLights (floodlights, shadow-casting)" — these are scene-level lights, not prop assets
- **Mid-scaffold and upper-structure bay modules** — covered in Context 5 (Restaurant) and Context 6 (Bomb Chamber) respectively
- **3 LODs handcrafted per §8H** — Sprint 09 ships LOD0 only; LOD1+LOD2 deferred per established Sprint 09 convention

---

## ASSET-007 — Eiffel Bay Module (Plaza-Tier, Wide Heavy Base)

| Field | Value |
|---|---|
| Asset ID | ASSET-007 |
| Category | Environment — tiling architecture module |
| Tier | T1 (final asset) |
| File path (target) | `assets/models/level-plaza/env_eiffel_bay_module_plaza.glb` |
| Material name | `mat_env_eiffel_bay_module_plaza` (single tiling material — Eiffel Grey + rivet repeat pattern; pattern in texture pass) |
| Naming convention | `env_eiffel_bay_module_plaza.glb` (per §8B `env_[name]_[variant].glb` convention; matches the example explicitly given in §8B) |
| Triangle budget LOD0 | **800** (art bible §8D — Tiling Eiffel bay module) |
| LOD count | 1 in Sprint 09 (2 LODs handcrafted is §8H deliverable — deferred) |
| Texture resolution | 512 × 512 (art bible §8D — environment tileable) |
| Material slots | 1 (single tiling material per module type — §8D) |
| Texture content | Flat painted color + hand-painted rivet repeat pattern. NO PBR. NO photographic source. |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO — static architecture |
| Outline tier | **LIGHTEST** (1.5 px @ 1080p, color `#1A1A1A`) — art bible §8C (environment geometry) |
| Outline implementation | ADR-0001 stencil tier 3 |
| Tiling | Yes — module is designed to tile/repeat across all plaza ironwork. Tile axis along the horizontal (X) for spanning width and vertical (Z) for stacking altitude. Seams are at the module's vertical posts (clean alignment guaranteed). |
| Use case | Plaza section ironwork — entire plaza floor + ceiling canopy + supporting columns. The module IS the Plaza's Eiffel-Tower-ness. |
| UV mapping | Single UV unwrap (UV0). Rivet repeat pattern UV-tiles within the module. 4 px margin at 512 px. Pattern continues seamlessly when modules tile. |
| Status | **Done** (2026-05-10) — code-authored from primitives, NOT image-to-3D |
| Visual reference (canonical) | `design/assets/specs/references/eiffel_bay_module_plaza_reference_2026-05-10.png` (used as design intent reference; final asset code-authored to match) |
| Final `.glb` on disk | `assets/models/level-plaza/env_eiffel_bay_module_plaza.glb` (4 KB, 60 tris, 4.000×0.200×3.000m exact, 1 flat unlit emission material `mat_env_eiffel_bay_module_plaza` Eiffel Grey `#6B7280`) |
| Production method | **Code-authored from primitives (5 cuboids triangulated)** — 2 vertical posts at X=0 and X=4 (tile-clean seams) + 2 horizontal rails + 1 diagonal cross-brace. Member cross-section 0.2m × 0.2m. |
| Why code-authored vs image-to-3D | Image-to-3D pipeline failed for this asset (see "Image-to-3D Pipeline Notes" below). Code-authored produces deterministic clean topology + perfect dimensions + manifold geometry + tile-ready seams + 92.5% budget headroom. |
| Cleanup pipeline date | 2026-05-10 |

### Approved Visual Reference

The canonical reference image at `design/assets/specs/references/eiffel_bay_module_plaza_reference_2026-05-10.png` was approved on first attempt as the design-intent reference for ASSET-007's structural composition. The final `.glb` was code-authored to match the reference's spec rather than passed through image-to-3D conversion.

### Image-to-3D Pipeline Notes (failure mode documented)

Two image-to-3D conversions of the approved reference were generated by the user (`bay_module_v1_i2to3d.glb` 15k tris and `bay_module_v2_i2to3d.glb` 451k tris). v1 had broken silhouette on import (geometry collapsed/distorted). v2 had clean silhouette at high poly but **decimating from 451k → 800 tris destroyed structural members** (top rail + right post collapsed) regardless of decimate algorithm choice (COLLAPSE, DISSOLVE/PLANAR pre-pass with NORMAL delimit, both failed).

**Root cause**: image-to-3D services produce dense uniformly-distributed topology that doesn't preserve "structural feature" edges under aggressive decimation (>99% retain). Architectural primitives composed of thin beams have no "mass" to anchor the decimation algorithm; the algorithm collapses thin beams into nothing because their volume is negligible relative to surrounding empty space.

**Lesson — workflow rule**: for **simple architectural geometric primitives** (bay modules, crates, beams, frames, simple boxes/cuboids), **bypass image-to-3D entirely** and code-author directly via `mcp__blender__execute_blender_code` with bmesh primitives. This produces:
- Deterministic clean topology
- Exact dimensions per spec
- Manifold geometry (no holes, no flipped normals)
- Tile-ready seams (posts at exact X=0 and X=W boundaries)
- Massive budget headroom (60 tris vs 800 budget = 7.5% used)
- Reproducible results (rerun the script, get identical output)

**Apply this rule to future architectural assets**:
- ASSET-010 (Eiffel bay module mid-scaffold) — Context 5 (Restaurant)
- ASSET-014 (Eiffel bay module upper-structure) — Context 6 (Bomb Chamber)
- Crates, scaffolding pieces, equipment frames, any simple-primitive props

The image-first → image-to-3D pipeline (Path 4) remains the canonical workflow for **organic / character / detailed-prop assets** where geometric variability matters. For architectural primitives, code-authoring is the correct method.

### Visual Description

A single triangulated bay segment of Eiffel Tower ironwork at the **plaza-tier** (ground-level) proportions: WIDE and HEAVY. The module consists of four canonical structural members per §6.1:

1. **One vertical post** (vertical structural column, hard rectangular cross-section, hard edges)
2. **Two horizontal rails** (top + bottom horizontal beams connecting two vertical posts in a tile)
3. **One diagonal cross-brace** (the diagonal that connects opposite corners of the rectangle formed by posts + rails — this is the iconic Eiffel triangulation)

The module's aspect ratio is **wide and squat** (compared to upper tiers): wider than tall, heavy proportions, signaling structural mass at the tower's base. Reads at silhouette as a triangulated rectangle dominated by horizontal lines and one strong diagonal. NOT a delicate lattice — at this tier the geometry is robust, military-engineered ironwork.

Surface treatment per §6.2: flat painted Eiffel Grey color field with **rivet repeat pattern** as the dominant texture. Per §6.1 "Do not model individual rivets; add the rivet repeat as a flat painted pattern on the surface." Rivets are texture, not geometry. This is non-negotiable per art bible.

Per §6.1 "Outline-first silhouette check": when rendered with only the comic-book outline pass active against a flat white field, the lattice rhythm must read as legible geometry rather than noisy line-spaghetti. If outlines merge into solid shapes, the module is wrong — simplify. This test is the acceptance gate.

Per §6.1 "Collision geometry follows the module, not the detail": all canonical edges (top rail, bottom rail, vertical posts, diagonal brace) are traversal-grade. Level designers build encounters around this module grid, not around hero-detail geometry added after the fact.

### Art Bible Anchors

- **§6.1 Architectural Style**: "One canonical bay module per altitude tier. Model a single triangulated bay — one diagonal cross-brace, two horizontal rails, one vertical post — at the correct aspect ratio for each tier. All ironwork geometry tiles from this module. Three modules total: plaza-tier (wide, heavy base), mid-scaffold (tapering), upper-structure (narrow, compressed)."
- **§6.1 Outline-first silhouette check**: outline test against flat white background is the acceptance gate.
- **§6.1 Collision geometry follows the module**: traversal surfaces correspond to canonical module edges.
- **§6.2 Texture Philosophy**: rivet repeat as flat painted pattern, NOT modeled rivets. "Tiling surfaces: ironwork lattice (canonical bay module surface)…"
- **§3.4 Hero Shapes**: environment geometry = LIGHTEST outline weight.
- **§4.1 Primary Palette**: Eiffel Grey `#6B7280` for ironwork.
- **§4.3 Plaza Color Temperature**: "blue-grey iron ceiling" — module reads cool against warm Paris Amber lamp pools.
- **§5.4 LOD Sentence**: "preserve lattice rhythm at distance; rivet pattern detail can drop with mip level."
- **§8D Polycount**: 800 tris LOD0.
- **§8D Texture cap**: 512 × 512 (environment tileable).
- **§8D Material slots**: 1.
- **§8H LOD Distance**: 15m → 40m → cull 80m (visible from altitude — bay modules at the tower's top/upper-structure tier need to render the plaza-tier from above at long range; LOD2 cull is permissive).

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Ironwork primary | `#6B7280` (Eiffel Grey) | Art bible §4.1 |
| Rivet pattern overlay | `#5A6068` (slightly darker grey, faked specular via flat) | Derived |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment module reference, ISOLATED OBJECT on plain flat
white background, no shadows on ground, three-quarter front view, full
prop visible head to base.

PROP: A single triangulated bay segment of Eiffel Tower iron lattice at
the GROUND-LEVEL / PLAZA tier. Period 1889 Gustave Eiffel structural
ironwork, depicted in stylized 1965 spy comic-book aesthetic.

GEOMETRY (one canonical bay module — strict structural composition):
- TWO VERTICAL POSTS at the left and right edges of the module —
  rectangular cross-section (NOT round/cylindrical), hard geometric edges,
  matte Eiffel Grey color (#6B7280). The posts run from base to top of
  the module.
- TWO HORIZONTAL RAILS spanning between the two vertical posts — one at
  the top, one at the bottom of the module. Same rectangular profile as
  the posts.
- ONE DIAGONAL CROSS-BRACE running from the bottom-left corner to the
  top-right corner of the rectangle formed by the posts and rails. This
  is the iconic Eiffel triangulation member. Same matte Eiffel Grey,
  same rectangular cross-section.
- The module forms a rectangle wider than tall (PLAZA-TIER proportions —
  WIDE AND HEAVY, signaling structural mass at the tower's base).
  Approximately 4m wide × 3m tall.

PROPORTIONS: WIDE and HEAVY at the base (NOT tapering, NOT delicate).
Reads as robust, military-engineered structural ironwork at the tower's
ground floor. Compare: tower's upper-structure modules would be narrower
and more compressed; this is the OPPOSITE — the heaviest, widest tier.

SURFACE TREATMENT:
- Solid matte Eiffel Grey (#6B7280) painted color field.
- Hand-painted rivet pattern as repeating dots along the lengths of all
  four members. Rivets are TEXTURE, NOT modeled geometry. They appear as
  small darker grey dots in regular spacing — period rivet placement.
- NO photorealistic metal, NO PBR, NO normal maps, NO procedural noise.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors.
- Strong dark outline around the module silhouette (comic-book outline
  ~1.5px, light weight — environment geometry).
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1965 comic-panel ironwork; period engineering
  illustrations of the Eiffel Tower; NOLF1 (2000) environment geometry.

FRAMING:
- Three-quarter front view at slight angle.
- Plain flat white background.
- The module fills the frame head to base.
- Camera framing tight on the module, full prop visible.

NEGATIVE / DO NOT INCLUDE:
- NO modeled rivets (rivets are flat painted pattern only).
- NO photorealistic metal, NO PBR, NO normal maps, NO realistic light
  scattering.
- NO modern steel construction, NO welded I-beams — this is 1889
  engineered cast/wrought iron.
- NO ornamentation, NO Belle Epoque decorative scrollwork on the module
  itself (decorative ornamentation lives on architectural details, not
  the structural lattice).
- NO tapering or narrowing — this tier is the WIDE HEAVY BASE.
- NO curved members — all four members are straight, hard-edged.
- NO weathering, NO rust, NO patina — the surface is a flat saturated
  color field.
- NO embellishment or signage on the module.
```

---

## ASSET-008 — Period Sodium Street Lamp

| Field | Value |
|---|---|
| Asset ID | ASSET-008 |
| Category | Environment — period prop, vertical |
| Tier | T1 (final asset) |
| File path (target) | `assets/models/level-plaza/env_period_street_lamp.glb` |
| Material name | `mat_env_period_street_lamp` |
| Naming convention | `env_period_street_lamp.glb` |
| Triangle budget LOD0 | **500** (art bible §8D — generic environment prop range 300–600; lamp sits middle for the column + ornate base detail) |
| LOD count | 1 in Sprint 09 |
| Texture resolution | 512 × 512 |
| Material slots | 1 |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO — static prop |
| Outline tier | **LIGHTEST** (environment / decorative geometry) |
| Outline implementation | ADR-0001 stencil tier 3 |
| Use case | Plaza section signature element — sodium street lamps creating warm Paris Amber pools per §2 atmosphere. Multiple instances scattered across the plaza floor at canonical pool spacing. |
| UV mapping | Single UV unwrap. Lamp head + column separated in UV island for clean texture coverage. |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/period_street_lamp_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-plaza/env_period_street_lamp.glb` (39 KB, 500 tris exactly, 1 flat unlit material `mat_env_period_street_lamp` placeholder near-black `#1A1A1A` — Paris Amber emissive panels deferred to texture pass) |
| Image-to-3D source | **Hunyuan3D-2 (mini)** via `gen3dhub` CLI — 129,408 tris raw input |
| Cleanup pipeline date | 2026-05-10 |
| Image approval | First-pass approved (no iterations needed) |

### Visual Description

A 1900s Belle Epoque-style cast-iron Parisian street lamp, retrofitted with a 1960s sodium-vapor head fixture. The lamp reads at silhouette as: an ornate cast-iron base + fluted column + curved arm + period lamp head, ~3m tall standing on the cobblestone plaza floor. The fixture's purpose is to cast a warm Paris Amber `#E8A020` light pool on the orange cobblestone floor (per §4.3 Plaza color temperature) — the lamp head must support an emissive material slot OR be paired with a runtime point light at scene-load.

The base is a small Art Nouveau-influenced ornate cast-iron pedestal: roughly hexagonal or octagonal cross-section, decorative scrollwork (geometric stylized — NOT super-detailed real-world Belle Epoque ornament; the stylization rule from §6.1 applies). The fluted column rises vertically from the base, narrowing slightly toward the top. A curved horizontal arm extends from the column near the top, ending in a hanging lamp head: a hexagonal-faceted glass housing in matte black metalwork, with sodium-yellow glass panels.

Reads as period-1900s overall but with the slight 1960s sodium-fixture retrofit signaling "this is the 1965 Plaza, where the lamps got modernized but the bases are original." This collision-of-eras principle (per §6.1 Restaurant note "the collision of eras is the joke") applies to the Plaza too at smaller scale.

### Art Bible Anchors

- **§2 Plaza atmosphere**: "Paris Night, Ground Level" — sodium street lamps creating warm Paris Amber pools.
- **§4.3 Plaza Color Temperature**: "Paris Amber (street lamp pools)" — Paris Amber is the lamp's emissive color.
- **§4.1 Primary Palette**: Paris Amber `#E8A020` for the lamp's emitted light pool color.
- **§6.3 Plaza Density**: "lamp standard" listed as part of the hero prop cluster.
- **§3.4 Hero Shapes**: environment / decorative = LIGHTEST outline tier.
- **§8D Polycount**: 300–600 tris (generic environment prop range); 500 chosen for ornate-base detail.
- **§8G Lighting Budget**: "Plaza | 4-5 OmniLights (street lamp pools, no shadows)" — the lamp itself is a prop; the OmniLight is wired at scene-load.

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Cast iron column + base | `#1A1A1A` (period dark cast iron) | Derived |
| Lamp head metalwork | `#1A1A1A` (matches column) | Derived |
| Sodium glass panels | `#E8A020` (Paris Amber, emissive) | Art bible §4.1 |
| Decorative scrollwork accent | `#3A3A3A` (slightly lighter for definition) | Derived |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment prop reference, ISOLATED OBJECT, plain flat
white background, no shadows on ground, three-quarter front view, full
prop visible head to base.

PROP: A 1900s Belle Epoque cast-iron Parisian street lamp retrofitted
with a 1960s sodium-vapor head. Approximately 3m tall total height.
1965 Paris Plaza setting — period-authentic at the tower's ground level.

GEOMETRY (top to bottom):
- LAMP HEAD: hexagonal-faceted glass housing in matte black ironwork
  framing. Sodium-yellow glass panels (Paris Amber #E8A020 — saturated,
  almost glowing). Hangs from a curved horizontal arm.
- CURVED ARM: cast iron, gentle S-curve, extending horizontally then
  bending down toward the lamp head. Hard geometric simplification of
  Art Nouveau scrollwork. About 50cm horizontal extension.
- FLUTED COLUMN: vertical cast iron column rising from base to arm.
  Slight taper toward the top. Hexagonal or octagonal cross-section
  with vertical flutes (period detail). Approximately 2.5m tall.
- ORNATE BASE: small Art Nouveau-influenced cast-iron pedestal at the
  bottom. Hexagonal or octagonal cross-section, decorative geometric
  scrollwork (NOT super-detailed; stylized comic-book interpretation
  of period ornament). About 50cm tall × 60cm wide.

PROPORTIONS: tall vertical reading. Slim profile from front. The lamp
head is the dominant identification element at distance — the hexagonal
glass cluster reads against the night sky.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading. The Paris Amber sodium glass appears emissive
  but is rendered as a saturated solid color (not photoreal glow).
- NO PBR materials, NO photorealism.
- Strong dark outline around the prop silhouette (comic-book outline
  ~1.5px, light weight).
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1900s Paris street lamps; period architectural
  illustrations; vintage Air France travel posters; NOLF1 (2000)
  period environmental props.

FRAMING:
- Three-quarter front view at slight angle, eye level looking up at the
  lamp head and down to the base.
- Plain flat white background.
- Full prop visible from lamp head at top to base at bottom.

NEGATIVE / DO NOT INCLUDE:
- NO modern LED street light, NO modern aluminum pole — this is period
  cast-iron 1900s construction with a 1960s sodium head retrofit.
- NO photorealistic glass, NO realistic light scattering or god-rays —
  flat painted Paris Amber color only.
- NO realistic patina or rust — the surface is flat saturated color.
- NO actual graffiti or signage on the column.
- NO bird's nest, NO overgrowth — the lamp is in active service.
- NO American 1950s street lamp style (cantilevered swan-neck commercial
  steel) — this is European Belle Epoque cast iron with a sodium head.
- NO concrete base — the base is decorative cast iron.
```

---

## ASSET-009 — Plaza Kiosk / Guard Post

| Field | Value |
|---|---|
| Asset ID | ASSET-009 |
| Category | Environment — period structure prop |
| Tier | T1 (final asset) |
| File path (target) | `assets/models/level-plaza/env_plaza_guard_post.glb` |
| Material name | `mat_env_plaza_guard_post` |
| Naming convention | `env_plaza_guard_post.glb` |
| Triangle budget LOD0 | **600** (art bible §8D — generic environment prop range 300–600; kiosk sits at top of range due to enclosed structure complexity) |
| LOD count | 1 in Sprint 09 |
| Texture resolution | 512 × 512 |
| Material slots | 1 |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO — static structure |
| Outline tier | **LIGHTEST** (environment) |
| Outline implementation | ADR-0001 stencil tier 3 |
| Use case | Plaza section hero prop cluster identifier — the location PHANTOM grunts patrol from. Per §6.3 "guard post" listed explicitly in plaza prop cluster. The kiosk also serves as comedy potential (PHANTOM occupying a converted period civilian kiosk) per game-concept.md Pillar 1 (Comedy Without Punchlines). |
| UV mapping | Single UV unwrap. Roof + walls + door separated in UV island for clean texture coverage. |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/plaza_guard_post_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-plaza/env_plaza_guard_post.glb` (46 KB, 600 tris exactly, 1 flat unlit material `mat_env_plaza_guard_post` placeholder walnut `#3A2A1A` — multi-color faction details deferred to texture pass) |
| Image-to-3D source | **Hunyuan3D-2 (mini)** via `gen3dhub` CLI — 609,936 tris raw input |
| Cleanup pipeline date | 2026-05-10 |
| Image approval | First-pass approved (no iterations needed) — bonus stencil reads "PHANTOM POSTE 17" with French period-correct "poste" terminology |

### Visual Description

A small 1900s-era Parisian period kiosk — originally a civilian newspaper or flower kiosk at the Eiffel Tower's plaza floor — now occupied by PHANTOM as a guard post. The structure reads at silhouette as a tall narrow rectangular box on a small cobblestone footprint, ~2m × 2m × 2.5m tall. A pyramidal or domed roof caps the structure (period civilian kiosk styling). The walls are dark wooden panelling with one window facing the plaza (the guard's view-out). One door on the side opposite the window.

The PHANTOM occupation is signaled by **two clear faction tells** consistent with Pillar 5 (Period Authenticity Over Modernization — no modern UX) and §4.2 Semantic Color (PHANTOM Red = threat):
1. A small **PHANTOM Red `#C8102E` flag or pennant** flying from the roof peak — the only saturated red on the entire structure
2. A **PHANTOM-stenciled wayfinding sign** on the door — block-serif lettering in Cyrillic or English, faction-coded

The structure's wood is dark period walnut/oak with subtle visible woodgrain pattern (per §6.2 hand-painted geometric pattern). The window has small wooden mullions creating a 4-pane or 6-pane grid (period style). The door is a period-correct paneled wooden door. No modern signage, no glass cleaning, no electric outlets visible.

Per §6.3 "max 3 interactive props in any 10m radius" — the kiosk is interactive (player can take cover behind it) and counts as one of the 3 in the radius around it.

### Art Bible Anchors

- **§6.3 Plaza Density**: "guard post" explicitly listed as part of the hero prop cluster.
- **§4.2 Semantic Color**: PHANTOM Red on the kiosk = PHANTOM has appropriated this civilian structure.
- **§6.1 Stylization rule**: simplify period architectural detail without losing recognizability — the kiosk reads "Parisian 1900s" without being super-detailed.
- **§3.4 Hero Shapes**: environment = LIGHTEST outline.
- **§8D Polycount**: 600 tris (top of generic environment prop range).
- **Pillar 1 (Comedy Without Punchlines)**: PHANTOM occupying a civilian kiosk has implicit comedy — period architecture co-opted by villains is one of the genre's classic visual jokes.

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Wooden walls primary | `#3A2A1A` (dark period walnut) | Derived |
| Wooden trim accent | `#5A4A2A` (slightly lighter) | Derived |
| Roof | `#1A1A1A` (period dark slate or cast iron) | Derived |
| Window frame | `#3A2A1A` (matches wall) | Derived |
| Window glass panes | `#3A4A5A` (dark blue night reflection) | Derived |
| PHANTOM flag / pennant | `#C8102E` (PHANTOM Red) | Art bible §4.1 |
| PHANTOM stenciled sign | `#C8102E` on `#3A2A1A` background | Art bible §4.1 |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment prop reference, ISOLATED OBJECT, plain flat
white background, no shadows on ground, three-quarter front view, full
prop visible head to base.

PROP: A small 1900s Belle Epoque Parisian period kiosk, originally a
civilian newspaper or flower vendor kiosk at the Eiffel Tower's ground
level — NOW OCCUPIED by the PHANTOM organization as a guard post in
1965. The PHANTOM occupation is signaled through small added details on
an otherwise-period civilian structure.

DIMENSIONS: approximately 2m × 2m footprint, 2.5m tall.

GEOMETRY (top to bottom):
- ROOF: pyramidal or domed roof cap in dark slate or period cast iron
  (#1A1A1A). Slight overhang over the walls. Period civilian kiosk
  styling — NOT a modern roof.
- ROOF PEAK: a small PHANTOM RED (#C8102E) flag or rectangular pennant
  flying from a thin pole at the peak. This is the FACTION IDENTIFIER —
  the only saturated red on the entire structure.
- WALLS: dark period walnut/oak wooden panelling (#3A2A1A). Vertical
  wooden plank pattern with subtle hand-painted woodgrain texture.
- WINDOW: one square or rectangular window on the front face — the
  guard's view-out. Small wooden mullions creating a 4-pane or 6-pane
  grid (period style). Window glass appears as a dark blue-grey
  reflection of the night.
- DOOR: one period-correct paneled wooden door on the side opposite the
  window. Brass or iron handle (small period detail).
- PHANTOM STENCILED SIGN: a small PHANTOM RED (#C8102E) wayfinding
  stencil on the door — block-serif lettering in Cyrillic or English,
  faction-coded. Reads as recently added to a period civilian door.
- BASE: structure rests directly on the cobblestone — no concrete plinth,
  no modern foundation visible.

PROPORTIONS: tall narrow rectangular box. Reads at silhouette as a
single hard rectangle with a triangular roof cap.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors.
- Strong dark outline around the structure silhouette (comic-book
  outline ~1.5px, light weight — environment geometry).
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1900s Paris street kiosks; period architectural
  illustrations; vintage Air France travel posters; NOLF1 (2000)
  appropriated-civilian-structure-as-villain-base trope.

FRAMING:
- Three-quarter front view showing the front face (with window) and
  one side (with door + PHANTOM stencil).
- Plain flat white background.
- Full structure visible from roof peak to base.

NEGATIVE / DO NOT INCLUDE:
- NO modern construction, NO concrete, NO modern signage beyond the
  PHANTOM stencil.
- NO modern security camera, NO electronic equipment visible.
- NO ATM, NO modern POS terminal, NO modern advertising.
- NO PBR materials, NO photorealism, NO realistic wood grain
  (period style is hand-painted plank pattern).
- NO oversized comedic exaggeration — the structure reads as period
  civilian first, with subtle PHANTOM markers.
- NO weathering, NO graffiti beyond the official PHANTOM stencil.
- NO open door showing interior — the door is closed.
- NO guard visible (the guard is a separate asset).
- NO weapons mounted on the kiosk.
- NO Soviet red star or historical fascist iconography — the PHANTOM
  red mark is fictional faction-coded only.
```

---

## Cross-Asset Notes

### Outline pipeline implementation (per ADR-0001)

All 3 Plaza assets render through the standard stencil-based outline pipeline (ADR-0001) at **stencil tier 3 LIGHTEST** (1.5 px @ 1080p). This is distinct from PHANTOM characters (tier 2 MEDIUM) and Eve (tier 1 HEAVIEST) — environment props do not compete with characters/heroes for foreground attention.

### Plaza color story (cross-reference)

The 3 assets together compose the Plaza section's color story per §4.3:

- **ASSET-007 (bay module)**: cool Eiffel Grey ironwork — the ceiling canopy reads cool against warm floor
- **ASSET-008 (sodium lamp)**: emits warm Paris Amber pool — primary warm light source
- **ASSET-009 (kiosk)**: dark walnut wood + PHANTOM Red faction marker — anchors the threat identifier

The cobblestone floor (separate texture pass deferred) provides the orange floor tone that pairs with Paris Amber lamp pools and contrasts with the cool blue-grey iron ceiling.

### Section integration (Sprint 10+)

These 3 assets, plus the cobblestone floor texture (deferred), are sufficient to compose a recognizable Plaza section. Additional density (benches, planters, period signage, comedic absurdist hero props per §6.3) can be added in a follow-on level-asset sprint when encounter layouts are designed via `/team-level` for the Plaza vertical slice.

### Generation order recommendation

Per the spec's Generation Strategy patterns (validated in stealth-ai context), do these in order:

1. **ASSET-007 (Eiffel bay module)** first — most architecturally constrained (per §6.1's strict 4-member composition rule). Validate the prompt template before reusing partial elements (Eiffel Grey + rivet pattern) on other architectural assets in Restaurant/Bomb Chamber contexts.
2. **ASSET-008 (street lamp)** second — period prop, clear silhouette, expected first-pass success.
3. **ASSET-009 (kiosk / guard post)** third — most complex Plaza asset (multi-feature structure with PHANTOM faction overlay). Use ASSET-008's period-Paris aesthetic as style anchor.

### Forward dependencies

- `design/levels/plaza.md` (NOT YET AUTHORED — future deliverable for encounter layouts)
- Sprint 10+ scene integration: replace placeholder geometry in `scenes/sections/plaza.tscn` with these `.glb`s; tile the bay module across plaza floor + ceiling; instance the street lamp at canonical pool spacing per §8G ("4-5 OmniLights (street lamp pools)"); place 1 kiosk at the canonical guard-post position
- Sprint 10+ outline pipeline: stencil tier 3 ref assignment at scene-load per ADR-0001
- Sprint 10+ texture pass: full `mat_env_eiffel_bay_module_plaza` rivet repeat pattern + cobblestone floor tile
- Sprint 10+ lighting: `WorldEnvironment` setup per §8G Plaza light plan (2-3 SpotLights floodlights + 4-5 OmniLights for street lamp pools + 1 directional ambient city glow)
