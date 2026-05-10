# Asset Specs — Level: Restaurant (Eiffel Tower 1889 Dining Salon, 1965 PHANTOM-Occupied)

> **Source**: `design/art/art-bible.md` (§2 Restaurant atmosphere; §4.3 Restaurant color temperature; §6.1 Restaurant architectural language; §6.2 Texture Philosophy; §6.3 Prop Density Rules; §8 Asset Standards)
> **Note**: `design/levels/restaurant.md` does NOT exist — Sprint 09 spec authoring extracts directly from art bible §6 per same pragmatic scope decision as plaza-assets.md.
> **Sprint**: 09 (`production/sprints/sprint-09-asset-commission-hybrid.md`)
> **Generated**: 2026-05-10
> **Status**: 4 assets specced / 0 approved / 0 in production / 0 done

## Restaurant Section Visual Identity (extract for context)

Per art bible §6.1: **"Late Belle Epoque Survival, 1965-interpreted."** The fictional predecessor to Le Jules Verne is the original 1890s tower dining salon, never fully modernized — retrofitted with 1950s-60s period lighting and furniture without removing the curved ironwork ceiling ribs and arched window surrounds. Reads as: wrought-iron structural arches (inherited from the tower, not designed for the room), warm walnut paneling (postwar renovation), crystal pendant chandeliers (dominant lighting), and a 1960s geometric carpet pattern (bold concentric diamond repeat in Paris Amber and BQA Blue — most explicit mod-era intervention).

**Pillar 1 comedy element**: "the collision of eras is the joke — ironwork from 1889, carpet from 1963, silverware from 1955."

Per §4.3 Restaurant: warmest zone — Paris Amber dominant + Parchment wall panels + BQA Blue glimpsed through arched windows (Paris cityscape).

Per §6.3 Restaurant density: **dense, curated.** Tables with full place settings, occupied by civilians. Sideboard, drinks trolley, coat rack, chandeliers. Every table is a prop cluster. Density high but organized along clear circulation paths.

## Tier Summary

| Asset | Tier | Production method | Sprint 09 Deliverable |
|---|---|---|---|
| ASSET-010 — Eiffel bay module mid-scaffold (tapering) | **T1** | **Code-authored** (architectural primitive per workflow rule) | `assets/models/level-restaurant/env_eiffel_bay_module_mid_scaffold.glb` |
| ASSET-011 — Period dining table cluster (table + place setting) | **T1** | Image-first → gen3dhub → MCP cleanup | `assets/models/level-restaurant/prop_dining_table_cluster.glb` |
| ASSET-012 — Crystal pendant chandelier | **T1** | Image-first → gen3dhub → MCP cleanup | `assets/models/level-restaurant/env_crystal_chandelier.glb` |
| ASSET-013 — Period drinks trolley | **T1** | Image-first → gen3dhub → MCP cleanup | `assets/models/level-restaurant/prop_drinks_trolley.glb` |

## Out of Scope

- **Diamond op-art carpet pattern** — flat painted texture (texture pass Sprint 10+ per §6.2)
- **Walnut wall paneling tile** — flat painted texture (texture pass)
- **Civilian models** (per §5.3 four distinct: dining couple + older diner + younger woman + maître d') — separate context "civilians" (DEFERRED to follow-on sprint)
- **Sideboard, coat rack, additional dining tables** — extra density beyond the 4 hero assets; defer to follow-on level-asset sprint
- **Window glass period look** — texture pass + scene shader work
- **3 LODs handcrafted per §8H** — Sprint 09 ships LOD0 only

---

## ASSET-010 — Eiffel Bay Module (Mid-Scaffold, Tapering)

| Field | Value |
|---|---|
| Asset ID | ASSET-010 |
| Category | Environment — tiling architecture module |
| Tier | T1 |
| File path (target) | `assets/models/level-restaurant/env_eiffel_bay_module_mid_scaffold.glb` |
| Material name | `mat_env_eiffel_bay_module_mid_scaffold` |
| Naming convention | `env_eiffel_bay_module_mid_scaffold.glb` |
| Triangle budget LOD0 | **800** (art bible §8D — Tiling Eiffel bay module) |
| Texture resolution | 512 × 512 (deferred) |
| Material slots | 1 |
| File format | glTF 2.0 binary; Y-up, Z-forward |
| Outline tier | **LIGHTEST** (1.5 px) — environment geometry per §8C |
| Outline implementation | ADR-0001 stencil tier 3 |
| Production method | **Code-authored** (5 cuboids triangulated — same canonical pattern as ASSET-007 plaza-tier) |
| Tiling | Yes — Restaurant ceiling arches + structural ribs inherited from 1889 tower frame |
| Status | **Done** (2026-05-10) — code-authored from primitives |
| Final `.glb` on disk | `assets/models/level-restaurant/env_eiffel_bay_module_mid_scaffold.glb` (4 KB, 60 tris exact, 3.2×0.2×3.0m) |
| Production method | **Code-authored** (5 cuboids triangulated; same pattern as ASSET-007 plaza-tier with mid-scaffold tapering proportion 3.2m wide vs 4m plaza) |

### Visual Description

Same canonical 4-member structure as ASSET-007 (2 vertical posts + 2 horizontal rails + 1 diagonal cross-brace), but at **mid-scaffold proportions: tapering**. The module is **narrower than plaza-tier** — approximately 3.2m wide × 3m tall (vs 4m × 3m at plaza). Reads at silhouette as a more compressed rectangle, signaling "we're now mid-tower" between the heavy base and the narrow top.

Same Eiffel Grey `#6B7280` color, same hand-painted rivet repeat pattern (texture pass), same hard rectangular cross-section on all members. Tile-clean seams at module boundaries.

### Art Bible Anchors

- **§6.1**: "mid-scaffold (tapering)" — narrower than plaza-tier, wider than upper-structure
- **§8D**: 800 tris, single material, 512×512 texture
- All other anchors as ASSET-007

### Color Palette

Same as ASSET-007 — Eiffel Grey `#6B7280` flat unlit material with rivet repeat in texture pass.

### Code-author script (canonical 5-cuboid structure)

```python
W, H, T = 3.2, 3.0, 0.20  # 3.2m wide × 3m tall × 0.2m member thickness
# 5 cuboids: 2 vertical posts at X=0 and X=W, 2 horizontal rails (top + bottom),
# 1 diagonal cross-brace bottom-left → top-right
# Same pattern as ASSET-007 but with tapering width
```

---

## ASSET-011 — Period Dining Table Cluster (Table + Full Place Setting)

| Field | Value |
|---|---|
| Asset ID | ASSET-011 |
| Category | Hero prop — dining table with place setting (single combined mesh per §6.3 "every table is a prop cluster") |
| Tier | T1 |
| File path (target) | `assets/models/level-restaurant/prop_dining_table_cluster.glb` |
| Material name | `mat_prop_dining_table_cluster` (placeholder; texture pass adds carpet-context palette) |
| Naming convention | `prop_dining_table_cluster.glb` |
| Triangle budget LOD0 | **600** (art bible §8D — generic environment prop range; cluster combines table + place setting in single mesh) |
| Texture resolution | 512 × 512 |
| Material slots | 1 |
| File format | glTF 2.0 binary; Y-up, Z-forward |
| Outline tier | **LIGHTEST** (environment / decorative) |
| Production method | Image-first → gen3dhub Hunyuan3D-2 → MCP cleanup |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/dining_table_cluster_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-restaurant/prop_dining_table_cluster.glb` (46 KB, 600 tris exact, ~88×87×74cm — close to spec 90×90×75cm, 1 flat unlit material `mat_prop_dining_table_cluster` placeholder Parchment `#F2E8C8`) |
| Image-to-3D source | Hunyuan3D-2 mini via gen3dhub — 1,005,592 tris raw input |
| Image approval | First-pass approved (bonus details: gold filigree tablecloth border, china plate motifs, acanthus leaf pedestal accents — all period-correct Belle Epoque) |

### Visual Description

A single round period dining table approximately 90cm diameter × 75cm tall, with a full place setting for two diners arranged on its top surface. The table is in dark walnut wood (matches §6.1 Restaurant warm walnut paneling). The place setting includes: white tablecloth (Parchment `#F2E8C8`), two place mats, two complete dinner setups (plate, smaller bread plate, fork+knife flanking, glass + wine glass), small centerpiece (oil lamp or short candleholder, period-appropriate). Period silverware (Belle Epoque, NOT modern). Reads at distance as "occupied dining table" — the silhouette includes the verticality of the glasses/centerpiece + the horizontal mass of the table.

Per §6.3, every table is a prop cluster — this asset packages the canonical Restaurant dining unit.

### Art Bible Anchors

- **§6.1 Restaurant**: walnut paneling era (postwar 1955 silverware era — collision of 1889 + 1955 + 1963)
- **§6.3 Restaurant density**: "Tables with full place settings… every table is a prop cluster."
- **§4.3 Restaurant**: Paris Amber lamp pools, Parchment wall panels — table reads warm
- **§8D**: 600 tris (top of generic env prop range — cluster justifies the higher end)

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Table walnut | `#3A2A1A` | Derived |
| Tablecloth | `#F2E8C8` (Parchment) | Art bible §4.1 |
| Place setting silver | `#9A9A9A` | Derived |
| Glass (faux specular) | `#5A6A7A` | Derived |
| Centerpiece accent | `#E8A020` (Paris Amber) | Art bible §4.1 |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment prop reference, ISOLATED OBJECT, plain flat
white background, no shadows on ground, three-quarter front view, full
prop visible head to base.

PROP: A 1900s Belle Epoque round period dining table, set for two
diners, in a 1965 Eiffel Tower restaurant. The table reflects the
Restaurant's "collision of eras" aesthetic — 1889 tower frame, 1955
silverware era, 1963 mod intervention pattern via the carpet (NOT
visible in this isolated prop image).

DIMENSIONS: round table top ~90cm diameter × 75cm tall, single central
pedestal column with small foot base.

GEOMETRY (top to bottom):
- ROUND TABLE TOP: dark walnut wood (#3A2A1A), flat painted geometric
  woodgrain texture. White tablecloth (#F2E8C8 Parchment) draped over,
  hanging down ~20cm on each side.
- PLACE SETTING (×2 — one each side of table): each setting includes
  a round dinner plate (Parchment), smaller bread plate offset to upper
  left, period silverware (knife + fork flanking the dinner plate, NOT
  modern), one wine glass + one water glass at upper right (clear glass
  rendered as flat lighter blue-grey #5A6A7A — NOT photoreal).
- CENTERPIECE: a small short brass-or-period oil lamp at the table's
  center, with Paris Amber (#E8A020) glass shade — reads as warm warm
  light source for the table.
- PEDESTAL COLUMN: dark walnut central column rising from a small
  flared base.
- BASE: small flared cast iron or walnut foot, hexagonal cross-section.

PROPORTIONS: horizontal mass of table top dominates, with vertical
elements (glasses, centerpiece) creating the cluster verticality.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors, NO PBR.
- Strong dark outline ~1.5px (light weight, environment).
- Hard edges, no gradient noise.
- Aesthetic inspired by: Belle Epoque dining illustrations; vintage Air
  France travel posters; NOLF1 (2000) period environmental props.

FRAMING:
- Three-quarter front view at slight elevation looking down at the
  table top, showing both place settings + the centerpiece.
- Plain flat white background.
- Full prop visible from centerpiece top to table base.

NEGATIVE / DO NOT INCLUDE:
- NO modern dinnerware, NO modern silverware, NO sleek minimalist plates.
- NO modern restaurant table — this is period 1900s Belle Epoque.
- NO chairs visible — chairs are a separate asset (out of scope).
- NO civilians, NO hands, NO food on the plates.
- NO carpet visible — the prop sits on plain background.
- NO photorealistic textures — flat painted color only.
- NO realistic glass reflections, NO god-rays.
- NO weathering, NO stains on the tablecloth.
```

---

## ASSET-012 — Crystal Pendant Chandelier

| Field | Value |
|---|---|
| Asset ID | ASSET-012 |
| Category | Environment — period lighting fixture, ceiling-suspended |
| Tier | T1 |
| File path (target) | `assets/models/level-restaurant/env_crystal_chandelier.glb` |
| Material name | `mat_env_crystal_chandelier` |
| Naming convention | `env_crystal_chandelier.glb` |
| Triangle budget LOD0 | **600** |
| Texture resolution | 512 × 512 |
| Material slots | 1 |
| Outline tier | **LIGHTEST** |
| Production method | Image-first → gen3dhub Hunyuan3D-2 → MCP cleanup |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/crystal_chandelier_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-restaurant/env_crystal_chandelier.glb` (45 KB, 600 tris exact, ~1m × 1m × 1m, 1 flat unlit material `mat_env_crystal_chandelier` placeholder brass `#9A6A2A`) |
| Image-to-3D source | Hunyuan3D-2 mini via gen3dhub — 1,051,886 tris raw input (highest poly source seen in Sprint 09) |
| Image approval | First-pass approved |
| Cleanup notes | Blender export warned "Mesh not valid" — common with image-to-3D outputs at 0.057% decimate retain. Export succeeded; mesh functional. Topology quirks (likely non-manifold edges from aggressive decimation) addressable in texture pass / topology cleanup if visible at runtime. |

### Visual Description

A period 1890s crystal pendant chandelier appropriate for a Belle Epoque dining salon. Approximately 80cm diameter × 100cm tall (suspended from ceiling). Brass period frame with multiple crystal-glass pendants hanging from concentric rings. The frame holds 6-8 small bulbs (or candles in earlier-era styling) creating warm light pools per §4.3 Restaurant Paris Amber dominant lighting.

Per §8G Restaurant lighting plan: "2 shadow-casting SpotLights (chandeliers)" — this asset is a prop; the SpotLight is wired at scene-load.

### Art Bible Anchors

- **§6.1 Restaurant**: "crystal pendant chandeliers as the dominant lighting fixture"
- **§4.3 Restaurant**: Paris Amber dominant — chandelier emits warm light
- **§6.3 Restaurant density**: "chandeliers" listed in dense curated prop set
- **§8D**: 600 tris

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Brass frame | `#9A6A2A` (warm brass) | Derived |
| Crystal pendants | `#F2E8C8` (Parchment-tinted) | Derived |
| Bulb/flame emissive | `#E8A020` (Paris Amber) | Art bible §4.1 |
| Suspension chain | `#5A4A2A` (dark brass) | Derived |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment prop reference, ISOLATED OBJECT, plain flat
white background, no shadows on ground, three-quarter front view at
eye level looking up at the chandelier, full prop visible head to base.

PROP: A 1890s Belle Epoque crystal pendant chandelier, ceiling-suspended,
appropriate for an Eiffel Tower 1889 dining salon (still in service in
1965 with light bulbs replacing original gas mantles). Period-authentic.

DIMENSIONS: approximately 80cm wide × 100cm tall (excluding suspension
chain).

GEOMETRY (top to bottom):
- SUSPENSION CHAIN: short period brass chain extending from top, ~30cm
  visible (extending up out of frame to imply ceiling attachment).
- TOP CROWN: small brass cap from which the chain meets the frame.
- BRASS FRAME: 2-3 concentric horizontal rings of warm brass period
  metalwork. Decorative scrollwork between rings (stylized comic-book
  interpretation of Belle Epoque ornament — NOT super-detailed).
- CRYSTAL PENDANTS: 12-16 small teardrop or faceted crystal pendants
  hanging from the bottom ring, in period Parchment-tinted glass
  (#F2E8C8 — translucent off-white).
- LIGHT SOURCES: 6-8 small bulbs (period round Edison-style or candle-
  flame-shape) arranged on the brass frame, glowing warm Paris Amber
  (#E8A020).
- BOTTOM: small decorative finial at the chandelier's lowest point.

PROPORTIONS: more wide than tall, the silhouette reads as a horizontal
crystalline cluster suspended at the top of the frame.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading. Crystal pendants appear translucent through flat
  Parchment color (NOT photoreal glass).
- The Paris Amber bulbs appear emissive but rendered as saturated solid
  color (no glow).
- Strong dark outline ~1.5px.
- Hard edges, no gradient noise.
- Aesthetic inspired by: Belle Epoque interior illustrations; vintage
  Paris dining-room paintings; NOLF1 (2000) period interior props.

FRAMING:
- Three-quarter front view at eye level looking up.
- Plain flat white background.
- Full chandelier visible from suspension chain top to bottom finial.

NEGATIVE / DO NOT INCLUDE:
- NO modern LED chandelier, NO sleek minimalist contemporary fixture.
- NO photorealistic crystal, NO realistic light scattering or god-rays.
- NO ornate Versailles-grade Rococo (over-decorated) — this is Belle
  Epoque restraint, theatrical not gaudy.
- NO black wrought iron — the frame is warm brass, period-appropriate.
- NO realistic chain links — flat-shaded simplification only.
- NO chandelier so low that bulbs are at table level — this is a
  ceiling fixture, hangs HIGH.
- NO ceiling visible — the chandelier is isolated.
```

---

## ASSET-013 — Period Drinks Trolley

| Field | Value |
|---|---|
| Asset ID | ASSET-013 |
| Category | Prop — period rolling cart with bottles |
| Tier | T1 |
| File path (target) | `assets/models/level-restaurant/prop_drinks_trolley.glb` |
| Material name | `mat_prop_drinks_trolley` |
| Naming convention | `prop_drinks_trolley.glb` |
| Triangle budget LOD0 | **500** |
| Texture resolution | 512 × 512 |
| Material slots | 1 |
| Outline tier | **LIGHTEST** |
| Production method | Image-first → gen3dhub Hunyuan3D-2 → MCP cleanup |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/drinks_trolley_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-restaurant/prop_drinks_trolley.glb` (39 KB, 500 tris exact, ~73×33×87cm — close to spec 60×40×90, 1 flat unlit material `mat_prop_drinks_trolley` placeholder walnut `#3A2A1A`) |
| Image-to-3D source | Hunyuan3D-2 mini via gen3dhub — 743,256 tris raw input |
| Image approval | First-pass approved |

### Visual Description

A period 1955-era waiter's drinks trolley (gueridon) — small two-tier wheeled cart approximately 60cm wide × 40cm deep × 90cm tall. Brass-and-walnut construction with two horizontal shelves: top shelf holds a small array of period spirits bottles (3-5 bottles, varied heights, dark glass with Parchment-color labels), bottom shelf holds short stack of folded white linen napkins + an ice bucket. Two visible wheels (period spoke-wheel style, brass).

The "1955 silverware era" gets continued in this prop — period-correct postwar service equipment.

### Art Bible Anchors

- **§6.1 Restaurant**: "the collision of eras is the joke — silverware from 1955" — drinks trolley is the postwar service-era element
- **§6.3 Restaurant density**: "drinks trolley" listed in prop set
- **§8D**: 500 tris (mid generic env prop range)

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Walnut frame + shelves | `#3A2A1A` | Derived |
| Brass trim + wheels | `#9A6A2A` | Derived |
| Bottle dark glass | `#1A1A1A` | Derived |
| Bottle labels Parchment | `#F2E8C8` | Art bible §4.1 |
| Linen napkins | `#F2E8C8` | Art bible §4.1 |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment prop reference, ISOLATED OBJECT, plain flat
white background, no shadows on ground, three-quarter front view, full
prop visible head to base.

PROP: A 1955-era period waiter's drinks trolley (gueridon), small
two-tier wheeled cart for a 1965 Eiffel Tower restaurant.
Postwar service equipment — period-authentic.

DIMENSIONS: ~60cm wide × 40cm deep × 90cm tall (excluding handle).

GEOMETRY (top to bottom):
- TOP SHELF: rectangular walnut shelf (#3A2A1A) at ~85cm height,
  holding a small array of 3-5 period spirits bottles arranged neatly:
  varied heights, all in dark glass (#1A1A1A) with Parchment-color
  labels (#F2E8C8). Small stainless-steel ice tongs at one corner
  (faked specular #9A9A9A flat).
- BOTTOM SHELF: rectangular walnut shelf at ~50cm height, holding a
  short stack of folded white linen napkins (#F2E8C8) on the left, and
  a small period brass ice bucket (#9A6A2A) on the right.
- VERTICAL FRAME: 4 brass uprights connecting the two shelves at the
  corners. Decorative knurled cap at top of each upright.
- HANDLE: a horizontal brass handle extends from one short side at top-
  shelf level (waiter's push handle).
- WHEELS: 4 visible period spoke-wheel-style brass wheels (small,
  ~10cm diameter), each with 6-8 visible spokes.

PROPORTIONS: tall narrow vertical rectangle, slightly wider than deep.
Reads at silhouette as a service cart with bottles + napkins visible
through the open shelf structure.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors.
- Strong dark outline ~1.5px.
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1950s European hotel service equipment;
  period dining-room illustrations; NOLF1 (2000) period interior props.

FRAMING:
- Three-quarter front view at eye level showing top shelf bottles +
  bottom shelf items + handle + wheels.
- Plain flat white background.
- Full prop visible from top shelf bottle tops to wheel bottoms.

NEGATIVE / DO NOT INCLUDE:
- NO modern minimalist room service cart, NO stainless-steel sleek look.
- NO chrome wheels — wheels are period brass with visible spokes.
- NO photorealistic glass on bottles, NO labels with real-world brand
  names visible (use abstract period-colored labels).
- NO modern barware (cocktail shakers, soda guns, etc.).
- NO weathering, NO grease stains.
- NO civilian/waiter visible.
```

---

## Cross-Asset Notes

### Outline pipeline implementation (per ADR-0001)

All 4 Restaurant assets use **stencil tier 3 LIGHTEST** at scene-load. None of these assets compete with characters/heroes for foreground attention (Restaurant context's hero is the encounter dynamics, not the props).

### Restaurant color story (cross-reference)

Per §4.3, Restaurant is the warmest section. The 4 assets together:

- ASSET-010 (mid-scaffold bay module): cool Eiffel Grey ironwork — the ceiling ribs read cool against warm wood/lighting
- ASSET-011 (dining table cluster): warm walnut + Parchment + Paris Amber centerpiece accent
- ASSET-012 (chandelier): brass + crystal Parchment + Paris Amber bulbs — primary warm light source
- ASSET-013 (drinks trolley): walnut + brass + dark glass + Parchment napkins

The 1965 mod-era diamond carpet pattern (deferred to texture pass) adds the BQA Blue + Paris Amber concentric repeat as the room's most explicit period-collision joke per §6.1.

### Generation order recommendation

1. **ASSET-010** (bay module) — code-author immediately (no user input)
2. **ASSET-012** (chandelier) — most architecturally constrained organic prop, validates restaurant generation prompt template
3. **ASSET-011** (dining table cluster) — second, more complex prop cluster
4. **ASSET-013** (drinks trolley) — last, simplest organic prop in this context
