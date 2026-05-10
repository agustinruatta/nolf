# Asset Specs — Level: Bomb Chamber (1889 Antenna Maintenance Alcove, PHANTOM-Occupied 1965)

> **Source**: `design/art/art-bible.md` (§2 Bomb Chamber atmosphere; §4.3 Bomb Chamber color temperature; §6.1 Bomb Chamber architectural language; §6.2 Texture Philosophy; §6.3 Prop Density Rules; §8 Asset Standards)
> **Note**: `design/levels/bomb-chamber.md` does NOT exist — Sprint 09 spec authoring extracts directly from art bible §6 per same pragmatic scope decision as plaza/restaurant.
> **Sprint**: 09 (`production/sprints/sprint-09-asset-commission-hybrid.md`)
> **Generated**: 2026-05-10
> **Status**: 4 assets specced / 0 approved / 0 in production / 0 done

## Bomb Chamber Section Visual Identity (extract for context)

Per art bible §6.1: **"original 1889 antenna maintenance alcove, PHANTOM-occupied."** This is NOT a PHANTOM-built room; it is a real structural maintenance space at the antenna base that PHANTOM has commandeered and minimally modified. Architectural language: raw riveted ironwork walls (no paneling, no finishing), a poured concrete service floor (treat as "someone poured this in the 1930s"), a single overhead utility strip light on a metal conduit chase. PHANTOM's additions are purely instrumental: the device itself (hero prop), a period relay-rack of electronics, and stenciled PHANTOM wayfinding in Cyrillic and a block-serif English secondary. **The room reads as found and occupied, not built. Boiler room, not villain's lair.**

Per §4.3 Bomb Chamber: clinical cool + red accent. Moonlight Blue `#B0C4D8` (fluorescent overhead) + PHANTOM Red `#C8102E` (device lamps) + near-black corners. Cool clinical white vs. PHANTOM Red — the entire chamber's dual-color tension.

Per §6.3 Bomb Chamber density: **sparse-but-packed.** The bomb device occupies the room's center axis. Flanked by the PHANTOM relay-rack, two equipment crates (stackable, functional), and one overturned maintenance stool. Nothing else.

Per §4.2: "bomb device indicator lamps use PHANTOM Red with a slow blink (the device 'breathes' PHANTOM Red in the Bomb Chamber). Explosive or irreversible-consequence objects share this PHANTOM Red + slow blink language. **No other objects blink.**"

## Tier Summary

| Asset | Tier | Production method | Sprint 09 Deliverable |
|---|---|---|---|
| ASSET-014 — Eiffel bay module upper-structure (narrow, compressed) | **T1** | **Code-authored** (architectural primitive per workflow rule) | `assets/models/level-bomb-chamber/env_eiffel_bay_module_upper_structure.glb` |
| ASSET-015 — Bomb device (NAMED hero prop) | **T1** | Image-first → gen3dhub → MCP cleanup | `assets/models/level-bomb-chamber/prop_bomb_device_hero.glb` |
| ASSET-016 — PHANTOM relay-rack (period electronics) | **T1** | Image-first → gen3dhub → MCP cleanup | `assets/models/level-bomb-chamber/prop_phantom_relay_rack.glb` |
| ASSET-017 — Equipment crate (stackable, reusable as 2× instances) | **T1** | Image-first → gen3dhub → MCP cleanup | `assets/models/level-bomb-chamber/prop_equipment_crate.glb` |

## Out of Scope

- **Overturned maintenance stool** — small additional prop; defer to follow-on level-asset sprint
- **Concrete service floor texture** — texture pass (Sprint 10+)
- **Raw riveted ironwork wall texture** — texture pass; uses §6.2 rivet repeat pattern
- **PHANTOM stenciled wayfinding** — texture pass (multiple stencil instances on walls + crates)
- **Overhead fluorescent strip light fixture** — counted as scene lighting prop; defer (covered by §8G Bomb Chamber light plan as a SpotLight at scene-load)
- **3 LODs handcrafted per §8H** — Sprint 09 ships LOD0 only

---

## ASSET-014 — Eiffel Bay Module (Upper-Structure, Narrow Compressed)

| Field | Value |
|---|---|
| Asset ID | ASSET-014 |
| Category | Environment — tiling architecture module |
| Tier | T1 |
| File path (target) | `assets/models/level-bomb-chamber/env_eiffel_bay_module_upper_structure.glb` |
| Material name | `mat_env_eiffel_bay_module_upper_structure` |
| Naming convention | `env_eiffel_bay_module_upper_structure.glb` |
| Triangle budget LOD0 | **800** (art bible §8D) |
| Texture resolution | 512 × 512 (deferred) |
| Material slots | 1 |
| File format | glTF 2.0 binary; Y-up, Z-forward |
| Outline tier | **LIGHTEST** (1.5 px) — environment per §8C |
| Production method | **Code-authored** (5 cuboids triangulated — same canonical pattern as ASSET-007 + ASSET-010) |
| Tiling | Yes — Bomb Chamber raw ironwork walls per §6.1 "raw riveted ironwork walls" |
| Status | **Done** (2026-05-10) — code-authored from primitives |
| Final `.glb` on disk | `assets/models/level-bomb-chamber/env_eiffel_bay_module_upper_structure.glb` (4 KB, 60 tris exact, 2.4×0.2×3.0m) |
| Production method | **Code-authored** (5 cuboids triangulated; narrowest of the 3 altitude tiers — 2.4m wide vs 3.2m mid-scaffold vs 4m plaza-tier) |

### Visual Description

Same canonical 4-member structure (2 vertical posts + 2 horizontal rails + 1 diagonal cross-brace), but at **upper-structure proportions: narrow, compressed**. Approximately 2.4m wide × 3m tall (vs 4m × 3m at plaza-tier and 3.2m × 3m at mid-scaffold). The narrowest of the three altitude tiers — signals "we're at the top of the tower" via maximally compressed lattice.

Same Eiffel Grey `#6B7280` base color. Per §6.1 Bomb Chamber, this tier uses RAW riveted ironwork — i.e., the rivet pattern is denser/more visible (texture pass detail) than at lower tiers. Walls are unfinished, no paneling.

### Code-author script (canonical 5-cuboid structure)

```python
W, H, T = 2.4, 3.0, 0.20  # 2.4m wide × 3m tall × 0.2m member thickness
# Same pattern as ASSET-007 + ASSET-010 — narrowest of the 3 tiers
```

---

## ASSET-015 — Bomb Device (NAMED Hero Prop)

| Field | Value |
|---|---|
| Asset ID | ASSET-015 |
| Category | Hero prop — NAMED, mission-critical, the climax target of the entire game |
| Tier | T1 (final asset) |
| File path (target) | `assets/models/level-bomb-chamber/prop_bomb_device_hero.glb` |
| Material name | `mat_prop_bomb_device_hero` (main) — emissive PHANTOM Red lamp deferred to texture pass material slot |
| Naming convention | `prop_bomb_device_hero.glb` (per art bible §8B example) |
| Triangle budget LOD0 | **2,500** (art bible §8D — Hero prop budget; the highest poly prop in the game) |
| Texture resolution | 1024 × 1024 (art bible §8D — Hero prop unique, one UV unwrap, no tiling) |
| Material slots | 2 max (main surface + emissive PHANTOM Red indicator lamps per §8D) |
| File format | glTF 2.0 binary; Y-up, Z-forward |
| Outline tier | **HEAVIEST** (4 px @ 1080p, `#1A1A1A`) — art bible §3.4 "key interactive objects (gadget pickups, **bomb components**, uncollected documents): heaviest outline weight" |
| Outline implementation | ADR-0001 stencil tier 1 |
| Production method | Image-first → gen3dhub Hunyuan3D-2 → MCP cleanup |
| LODs | 2 LODs handcrafted per §8H — Sprint 09 ships LOD0 only |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/bomb_device_hero_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-bomb-chamber/prop_bomb_device_hero.glb` (191 KB, 2,500 tris exact, ~100×51×110cm — close to spec 110×60×40cm, 1 flat unlit material `mat_prop_bomb_device_hero` placeholder Eiffel Grey `#6B7280`) |
| Image-to-3D source | Hunyuan3D-2 mini via gen3dhub — 803,268 tris raw input |
| Image approval | First-pass approved (bonus details: Cyrillic stencil "БЛОК-65Б" period East-Bloc identifier — exact match to spec; analog timer face 0-55 matches "1960s Eastern-Bloc countdown timer" intent; 4 PHANTOM Red bulb cluster matches "breathing" indicator language per §4.2) |

### Visual Description

The single most important hero prop in the game — the climax target Eve must disarm. A period 1965 East-Bloc improvised explosive device, mounted on a wheeled or stationary chassis. Its silhouette must be **immediately recognizable as "bomb"** at any distance and read as **threatening but not gory or graphic**.

Geometry assembly:
- A central cylindrical or rectangular **main body** (~80cm tall × 50cm diameter / wide), period industrial metal in dark Eiffel Grey
- A **PHANTOM Red `#C8102E` indicator lamp cluster** on the front face — 3-5 small round bulbs that "breathe" red per §4.2 (the only blinking object in the game)
- A **period analog dial face** on the front (large round face, ~25cm diameter, white Parchment background, black numerals, period clock-style hands — the timer mechanism's countdown display)
- **Cabling and conduit**: dark cables exiting the device on multiple sides, going off-screen (terminating at the PHANTOM relay-rack via cable-runs at scene-load)
- **Mounting/chassis**: a small period steel plinth or wheeled cradle holding the main body upright
- **Stenciled PHANTOM marking**: a small PHANTOM RED stenciled identifier on the body (faction-coded, NOT modern signage)

Per §4.2, the device "breathes" PHANTOM Red — slow-blink animation on the indicator lamps is the §4.2 blink language for "explosive or irreversible-consequence objects". Animation is post-rig deliverable (Sprint 09b+); the static mesh has the lamps in steady-on state.

### Art Bible Anchors

- **§6.1 Bomb Chamber**: "the device itself (hero prop)" — central axis of the chamber
- **§6.2 Texture Philosophy**: "Unique surfaces: the bomb device (one UV unwrap, no tiling)"
- **§3.4 Hero Shapes**: bomb components = HEAVIEST outline weight (eye goes here first)
- **§4.2 Semantic Color**: "bomb device indicator lamps use PHANTOM Red with a slow blink (the device 'breathes' PHANTOM Red)" — load-bearing for the section's tension
- **§8D Polycount**: 2,500 tris LOD0 (highest non-character budget in the game)
- **§8D Material slots**: 2 (main + emissive indicator lamps)
- **§8H LOD Distance**: 20m → 40m → never cull (always visible — boss encounter object)
- **Pillar 5 Period Authenticity**: NO modern digital countdown timer, NO modern microcontroller LED display — analog dial face only

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Main body Eiffel Grey | `#6B7280` | Art bible §4.1 |
| Body trim near-black | `#1A1A1A` | Derived |
| **PHANTOM Red indicator lamps** | **`#C8102E`** (PHANTOM Red, semi-emissive) | Art bible §4.1 + §4.2 |
| Analog dial face | `#F2E8C8` (Parchment) | Art bible §4.1 |
| Dial numerals + hands | `#1A1A1A` | Derived |
| Stenciled PHANTOM marking | `#C8102E` (PHANTOM Red) | Art bible §4.1 |
| Cabling | `#1A1A1A` | Derived |
| Mounting chassis | `#3A3A3A` (dark grey) | Derived |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D hero prop reference, ISOLATED OBJECT, plain flat white
background, no shadows on ground, three-quarter front view, full prop
visible head to base.

PROP: A 1965 East-Bloc improvised explosive device, the climax target
in a Cold War spy fiction game. Period-authentic 1960s industrial
construction. Mounted on a small wheeled steel cradle. Designed to
read as THREATENING and SERIOUS (not gory, not silly), the focal
point of a final-encounter chamber.

DIMENSIONS: ~80cm tall main body × 50cm diameter, on a chassis ~30cm
tall. Total assembly ~110cm tall × 60cm wide × 40cm deep.

GEOMETRY (top to bottom):
- MAIN BODY: a vertical cylindrical or rectangular metal container
  in matte Eiffel Grey (#6B7280), with hard rectangular cross-section
  reinforcement plates riveted to its surface. Period-industrial
  construction.
- PHANTOM RED INDICATOR LAMP CLUSTER: 3-5 small round red bulbs
  (#C8102E saturated red, semi-emissive) arrayed on the upper-front
  face of the body. These are the "breathing" indicators — the only
  red light source on the device.
- ANALOG DIAL FACE: a large circular dial mounted on the upper-front
  of the body, ~25cm diameter, with Parchment-colored (#F2E8C8) face
  and black (#1A1A1A) period clock-style numerals + 2-3 hands.
  Reads as a 1960s Eastern-Bloc countdown timer, NOT a modern digital
  display.
- CABLING: 3-5 dark cables (#1A1A1A) exit from the body's sides and
  back, terminating off-screen (going to a separate relay-rack —
  cables hang freely, period industrial wiring style).
- STENCILED PHANTOM MARKING: a small PHANTOM RED (#C8102E) stenciled
  identifier visible on the body — block-serif lettering (Cyrillic or
  English), faction-coded.
- MOUNTING CHASSIS: a small dark grey (#3A3A3A) steel base or wheeled
  cradle holding the main body upright. 4 small period steel wheels
  visible at the base (wheels CAN be there but device is not actively
  mobile — it's a delivered weapon now stationary).

PROPORTIONS: vertical cylinder/box dominating, with the dial face as
the secondary identification element, and the red lamp cluster as the
PHANTOM faction signal.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors.
- The PHANTOM Red lamp cluster appears emissive (saturated solid color,
  no glow halo).
- The analog dial reads as a flat printed face (NOT photoreal glass).
- Strong dark outline ~4px (HEAVIEST tier — this is the climax target,
  must read at any distance).
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1960s Cold War spy fiction props (You Only
  Live Twice, The Spy Who Came in from the Cold);
  period industrial control panels; NOLF1 (2000) bomb device
  precedent. Threatening but not gory.

FRAMING:
- Three-quarter front view at slight elevation showing the dial face,
  red lamps, and chassis.
- Plain flat white background.
- Full prop visible from cable-tops to wheel-bases.

NEGATIVE / DO NOT INCLUDE:
- NO modern digital countdown timer, NO LED displays, NO LCD screens,
  NO modern electronics interface — this is 1965 East-Bloc analog.
- NO photorealistic chrome, NO realistic metal reflections.
- NO blood, NO gore, NO realistic explosion damage on the device.
- NO Soviet red star or historical fascist iconography on the
  PHANTOM marking — fictional faction-coded only.
- NO modern military markings (NATO codes, real-world bomb-disposal
  icons, etc.).
- NO comedic exaggeration — this is the SERIOUS final-encounter
  object, must read as threatening.
- NO open access panel showing internal wiring — the device is
  externally sealed.
- NO power cord plugging into a wall socket — the cables go off-frame
  to a separate relay-rack.
```

---

## ASSET-016 — PHANTOM Relay-Rack (Period Electronics)

| Field | Value |
|---|---|
| Asset ID | ASSET-016 |
| Category | Environment — period industrial electronics, paired with bomb device |
| Tier | T1 |
| File path (target) | `assets/models/level-bomb-chamber/prop_phantom_relay_rack.glb` |
| Material name | `mat_prop_phantom_relay_rack` |
| Naming convention | `prop_phantom_relay_rack.glb` |
| Triangle budget LOD0 | **600** |
| Texture resolution | 512 × 512 |
| Material slots | 1 |
| Outline tier | **LIGHTEST** (environment / decorative) — relay-rack is supportive, not the hero |
| Production method | Image-first → gen3dhub Hunyuan3D-2 → MCP cleanup |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/phantom_relay_rack_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-bomb-chamber/prop_phantom_relay_rack.glb` (46 KB, 600 tris exact, ~139×56×200cm — slightly wider than spec 80cm but height exact, 1 flat unlit material `mat_prop_phantom_relay_rack` placeholder Eiffel Grey `#6B7280`) |
| Image-to-3D source | Hunyuan3D-2 mini via gen3dhub — 573,572 tris raw input |
| Image approval | First-pass approved (bonus details: Czech labels per módulo NAPÁJENÍ/REGULACE/etc., dual identification plaques "PHANTOM ORGANISATION 1965" + "PHANTOM FIELD INSTALLATION EIFFEL TOWER ANTENNA BASE MAINTENANCE ALCOVE NO. 17-A" — exceptional Cold War spy fiction texture) |

### Visual Description

A period 1960s East-Bloc industrial relay-rack — the electronics flank for the bomb device. Approximately 80cm wide × 60cm deep × 200cm tall, dark Eiffel Grey steel cabinet with a vertical front face containing multiple horizontal racks of period-industrial control modules. Each module is a small Bakelite-faced panel (~80cm × 15cm) with knobs, dials, and small status lamps. Period analog ammeters/voltmeters at the top. Dark metal mesh ventilation grille at the bottom. Cables exit the front and side, going off-screen toward the bomb device (matching ASSET-015's cable terminations).

Reads as "the brain" — the supportive technical infrastructure that connects to the bomb device.

### Art Bible Anchors

- **§6.1 Bomb Chamber**: "PHANTOM's additions: the device itself (hero prop), a period relay-rack of electronics"
- **§6.3 Bomb Chamber density**: "Flanked by the PHANTOM relay-rack"
- **§4.2 PHANTOM Red**: small status lamps on the rack's modules use PHANTOM Red — same faction-coded language as elsewhere
- **§8D**: 600 tris (top of generic env prop range)

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Cabinet body Eiffel Grey | `#6B7280` | Art bible §4.1 |
| Module Bakelite faces | `#1A1A1A` | Derived |
| Knobs + dials period brass | `#9A6A2A` | Derived |
| Status lamps PHANTOM Red | `#C8102E` | Art bible §4.1 |
| Analog meter face Parchment | `#F2E8C8` | Art bible §4.1 |
| Cable runs | `#1A1A1A` | Derived |
| Mesh ventilation grille | `#3A3A3A` | Derived |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment prop reference, ISOLATED OBJECT, plain flat
white background, no shadows on ground, three-quarter front view, full
prop visible head to base.

PROP: A 1960s East-Bloc industrial relay-rack — period electronics
cabinet for control of an industrial device. 1965 PHANTOM organization
field installation in the Eiffel Tower's antenna-base maintenance
alcove. Period-authentic Eastern-Bloc analog.

DIMENSIONS: ~80cm wide × 60cm deep × 200cm tall (full height steel
cabinet).

GEOMETRY (top to bottom):
- TOP CAP: small flat metal cap, slight overhang.
- ANALOG METERS: 2-3 round period analog meters at the top of the
  front face — Parchment-colored (#F2E8C8) faces with black numerals
  and needles, each ~15cm diameter. Period ammeter/voltmeter style.
- CONTROL MODULE STACK (the bulk of the cabinet face): 4-6 horizontal
  rectangular modules stacked vertically, each ~80cm × 15-20cm tall,
  with Bakelite-black (#1A1A1A) faces. Each module has:
  * 3-5 small period brass knobs (#9A6A2A) in a row
  * 1-2 small round status lamps (some PHANTOM Red #C8102E, some
    unlit)
  * A small Parchment-colored label strip with stenciled text
- VENTILATION GRILLE: a horizontal dark grey (#3A3A3A) metal mesh
  grille at the bottom front, ~80cm × 20cm.
- CABINET BODY: matte Eiffel Grey (#6B7280) steel, with riveted
  reinforcement edges visible at the corners.
- CABLE EXITS: 3-5 dark cables (#1A1A1A) emerging from the side or
  top of the cabinet, going off-screen (terminating at the bomb device
  off-frame — these match ASSET-015's cable terminations).
- BASE: small flat steel feet, no wheels (this is a permanent
  installation).

PROPORTIONS: tall narrow vertical rectangle, reads as a service
cabinet at silhouette.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading. Status lamps appear as solid saturated colors
  (no glow).
- Analog meter faces read as flat printed (not photoreal glass).
- Strong dark outline ~1.5px (LIGHTEST tier — environment).
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1960s Eastern-Bloc industrial control panels;
  period military relay racks; NOLF1 (2000) "found and occupied"
  villain installations.

FRAMING:
- Three-quarter front view at eye level showing the meter cluster +
  module stack.
- Plain flat white background.
- Full cabinet visible from top cap to base feet.

NEGATIVE / DO NOT INCLUDE:
- NO modern server rack, NO sleek minimalist 19" enterprise rack.
- NO digital displays, NO LCD/LED panels, NO modern push-buttons.
- NO computer monitors, NO keyboards.
- NO modern cable management.
- NO Soviet red star or fascist iconography.
- NO realistic metal patina or rust — flat painted color only.
- NO civilian/operator visible, NO clipboard, NO modern HMI interface.
- NO comedic exaggeration — this is the supportive technical prop.
```

---

## ASSET-017 — Equipment Crate (Stackable, Reusable)

| Field | Value |
|---|---|
| Asset ID | ASSET-017 |
| Category | Prop — small stackable functional crate, reusable mesh (instanced 2× in scene per §6.3 "two equipment crates") |
| Tier | T1 |
| File path (target) | `assets/models/level-bomb-chamber/prop_equipment_crate.glb` |
| Material name | `mat_prop_equipment_crate` |
| Naming convention | `prop_equipment_crate.glb` |
| Triangle budget LOD0 | **400** (generic env prop range — small simple crate) |
| Texture resolution | 512 × 512 |
| Material slots | 1 |
| Outline tier | **LIGHTEST** |
| Production method | Image-first → gen3dhub Hunyuan3D-2 → MCP cleanup |
| Status | **Done** (2026-05-10) |
| Visual reference (canonical) | `design/assets/specs/references/equipment_crate_reference_2026-05-10.png` |
| Final `.glb` on disk | `assets/models/level-bomb-chamber/prop_equipment_crate.glb` (31 KB, 399 tris ≤ 400 budget, ~64×45×40cm — close to spec 60×40×40, 1 flat unlit material `mat_prop_equipment_crate` placeholder walnut `#3A2A1A`) |
| Image-to-3D source | Hunyuan3D-2 mini via gen3dhub — 1,053,792 tris raw input |
| Image approval | First-pass approved (literal "PHANTOM CRATE 04" stencil match per spec example) |

### Visual Description

A 1965 period East-Bloc shipping crate — small wooden + metal-banded box for transporting ammunition, instruments, or PHANTOM equipment. Approximately 60cm × 40cm × 40cm. Dark wood (period crate construction in stained pine `#3A2A1A`) with horizontal metal reinforcement bands (Eiffel Grey `#6B7280`) at top, middle, and bottom. Stenciled PHANTOM markings on one side face (PHANTOM Red `#C8102E` block-serif lettering — Cyrillic or English faction-coded).

The crate is **instanceable**: the scene-load uses 2 instances of this single asset (per §6.3 "two equipment crates, stackable"). Stackable design means the top face is flat (no protrusions) and the bottom face is flat (no feet).

Per the Sprint 09 workflow rule, this asset COULD be code-authored (it's mostly geometric primitives). However, the stenciling + crate-banding details may benefit from image-to-3D fidelity. Decision: try image-first first; if fidelity is poor, fall back to code-author.

### Art Bible Anchors

- **§6.1 Bomb Chamber**: "two equipment crates (stackable, functional)"
- **§6.3 Bomb Chamber density**: included in sparse-but-packed prop set
- **§8D**: 400 tris (lower end of generic env prop range)

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Wood crate body | `#3A2A1A` (dark stained pine) | Derived |
| Metal reinforcement bands | `#6B7280` (Eiffel Grey) | Art bible §4.1 |
| PHANTOM stenciled marking | `#C8102E` (PHANTOM Red) | Art bible §4.1 |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D environment prop reference, ISOLATED OBJECT, plain flat
white background, no shadows on ground, three-quarter front view, full
prop visible head to base.

PROP: A 1960s East-Bloc shipping crate — small wooden + metal-banded
container for PHANTOM organization equipment, stockpiled in a 1965
field installation. Period-authentic, stackable, functional.

DIMENSIONS: ~60cm wide × 40cm deep × 40cm tall (single stackable
unit).

GEOMETRY (top to bottom):
- TOP FACE: flat, no protrusions (designed to support stacking another
  crate on top). Dark stained pine wood (#3A2A1A) plank pattern.
- HORIZONTAL METAL REINFORCEMENT BANDS: 3 horizontal bands of Eiffel
  Grey (#6B7280) steel — one near the top edge, one mid-height, one
  near the bottom edge. Each band wraps fully around the 4 sides.
  Period riveted construction — small flat painted rivet pattern on
  the bands.
- WOODEN PLANK SIDES: vertical wooden planks (#3A2A1A) between the
  metal bands, with subtle hand-painted woodgrain.
- STENCILED PHANTOM MARKING: a clear PHANTOM RED (#C8102E) stenciled
  identifier on one side face — block-serif lettering (Cyrillic or
  English equivalent), faction-coded. ~20cm × 5cm letterform area.
  May include numeric identifier (e.g., "PHANTOM CRATE 04").
- BOTTOM FACE: flat (no feet, no skids — designed to sit directly
  on the floor or stack on top of another crate).

PROPORTIONS: small horizontal rectangular box, slightly wider than
deep. Reads at silhouette as a single hard rectangle with banding
texture.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors.
- Strong dark outline ~1.5px (LIGHTEST tier).
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1960s East-Bloc industrial shipping crates;
  period military supply crates; NOLF1 (2000) appropriated equipment
  storage.

FRAMING:
- Three-quarter front view showing the front face (with PHANTOM
  stencil) and one side (showing wood planks + bands).
- Plain flat white background.
- Full crate visible from top to bottom.

NEGATIVE / DO NOT INCLUDE:
- NO modern shipping container, NO plastic cases, NO modern padlocks.
- NO modern barcode labels, NO modern fragile-handle-with-care icons.
- NO Soviet red star or fascist iconography.
- NO realistic wood patina or weathering — flat painted color.
- NO open lid showing contents — the crate is closed.
- NO straps, NO chains.
- NO multiple crates stacked in this image — single isolated crate.
- NO comedic exaggeration — this is functional storage equipment.
```

---

## Cross-Asset Notes

### Outline pipeline implementation (per ADR-0001)

| Asset | Stencil tier | Outline weight |
|---|---|---|
| ASSET-014 bay module | 3 (LIGHTEST) | 1.5 px |
| **ASSET-015 bomb device** | **1 (HEAVIEST)** | **4 px** |
| ASSET-016 relay-rack | 3 (LIGHTEST) | 1.5 px |
| ASSET-017 equipment crate | 3 (LIGHTEST) | 1.5 px |

The bomb device is the ONLY non-character HEAVIEST-tier asset in the entire game per art bible §3.4. Its outline draws the eye to the climax target from any angle.

### Bomb Chamber color story (cross-reference)

Per §4.3, Bomb Chamber is the chamber's distinctive cool clinical + PHANTOM Red dual-color:

- ASSET-014 (upper-structure bay module): Eiffel Grey ironwork — raw riveted (cool, structural)
- **ASSET-015 (bomb device)**: Eiffel Grey body + Parchment dial + **PHANTOM Red lamps + stencil** — the dual-color tension is concentrated in this hero prop
- ASSET-016 (relay-rack): Eiffel Grey + Bakelite black + brass knobs + small PHANTOM Red status lamps — supportive cool with red accents
- ASSET-017 (equipment crate): walnut wood + Eiffel Grey bands + PHANTOM Red stencil — warm wood interrupts the chamber's cool palette, signaling "this is foreign material brought in by PHANTOM"

The fluorescent overhead (deferred — scene-level light at scene-load) provides the Moonlight Blue `#B0C4D8` cool wash that makes PHANTOM Red pop maximally.

### Bomb device animation (post-rig deliverable)

§4.2 mandates the bomb device "breathes" PHANTOM Red — slow-blink animation on its indicator lamps. This is **not in Sprint 09 scope** (animation is post-rig). Sprint 10+ will:
1. Wire up the emissive PHANTOM Red material slot for the lamp cluster
2. Author a slow-blink animation (sine-wave pulse, ~1.2s period — matches the chamber's "ticking" musical motif per §6.1)
3. Set up scene-load to play the animation continuously while the device is alive

### Generation order recommendation

1. **ASSET-014** (upper-structure bay module) — code-author immediately (no user input)
2. **ASSET-017** (equipment crate) — simplest, validates Bomb Chamber generation prompt template
3. **ASSET-016** (relay-rack) — second, supportive electronics complexity
4. **ASSET-015** (BOMB DEVICE — last and most important) — most complex hero prop, use lessons from prior 3 assets to refine prompt before generating
