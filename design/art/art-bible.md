# Art Bible: The Paris Affair

*Working title — series concept: "Eve Sterling" / BQA Files*
*Created: 2026-04-19*
*Status: Complete — all 9 sections authored 2026-04-19*

> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED — Lean review mode (per `production/review-mode.txt`). Sections were authored by `art-director` agent with section-by-section user approval. Full director gate review can be invoked at any time via `/design-review design/art/art-bible.md`.

> **Visual Identity Anchor (from `design/gdd/game-concept.md`)**: **Saturated Pop**
> One-line rule: *"If a panel from a 1966 spy comic could slot in, you're on direction."*

---

## 1. Visual Identity Statement

**One-line visual rule:** *"If a panel from a 1966 spy comic could slot in, you're on direction."*

The rule names a specific year (1966), a specific medium (comic panel — not film still or painting), and carries an implicit checklist: outlines, flat color, bold geometry, high contrast.

### Principle 1: Ink Before Texture

All surfaces communicate through color and silhouette first; texture exists only to add period pattern, never surface complexity. Walls are not stone — they are BQA beige with a bold chevron frieze. Metal is not rusty — it is Eiffel grey with a rhythmic rivet repeat. If a surface reads primarily through its normal map or roughness value rather than its hue and pattern, the execution is wrong. Pipeline rule: unlit shading with hand-placed flat color palettes per zone; PBR is not the target rendering model.

*Design test: when a surface's material is ambiguous, choose the flattest, most saturated interpretation with a period-geometric pattern applied.*

**Serves Pillar 5: Period Authenticity Over Modernization** — printed ink was the era's medium; PBR realism is a 21st-century default that would read as wrong to the eye trained on 1966 visuals.

### Principle 2: Silhouette Owns Readability, Not Lighting

Lighting in this game is diegetic — driven by in-world sources (pendant lamps, ironwork-filtered sunlight, period spotlights, document overlays). It does not shift to reflect AI alert state; that job belongs to music and audio (faithful to NOLF1's dynamic music system). This means costume design and environment color blocking carry the entire burden of figure-ground separation. Eve's structured jacket and PHANTOM guards' rounded helmets must read clearly against any lighting condition the level's diegetic sources produce — bright pendant pools, deep ironwork shadow, exterior moonlight, indoor sconce wash. If a guard disappears into a wall in any of these conditions, the costume color or surface palette is wrong.

*Design test: when a guard or key object is hard to spot under a level's diegetic lighting, fix the costume or surface color — never invent a non-diegetic lighting effect to compensate.*

**Serves Pillar 3: Stealth is Theatre, Not Punishment** — a player who cannot read the scene cannot make dramatic choices; clarity is the prerequisite for theatricality. **Also serves Pillar 5: Period Authenticity** — non-diegetic alert-state lighting is a modern game convention; NOLF1 did not use it.

### Principle 3: Comedy Is a Visual Category

Absurdity earns its own visual register: oversized props, mise-en-abyme signage, and documents with typeset humor require specific compositional support so the joke lands without spoken delivery. An enormous crate labeled "DEFINITELY NOT A BIOWEAPON" needs enough screenspace, contrast against its surroundings, and Saul Bass–influenced signage design to be readable on a first pass. Every comedic environmental element should be treated as a foreground graphic element — high contrast, readable at distance, period-typeface formatted — not as dressing buried in the geometry.

*Design test: when a comedy element (sign, prop, document title) is ambiguous in visibility, push it to foreground contrast levels so the player cannot miss it without deliberately looking away.*

**Serves Pillar 1: Comedy Without Punchlines** — the protagonist does not signal the joke; the world must, which means the art does.

---

## 2. Mood & Atmosphere

Mood targets are defined per **physical location**, not per AI alert state. Lighting is diegetic — it comes from real in-world sources (lamps, sun, moon, sconces, beacons) and does not change based on what the AI is doing. Alert-state transitions (unaware → suspicious → searching → combat) are signaled through **music and audio**, faithful to NOLF1's dynamic music system.

**Vertical mood arc — progressive Paris visibility.** The mission's vertical progression has its own emotional grammar: as the player ascends the tower, Paris becomes more and more visible around and below. The Plaza is *in* the city; the Lower Scaffolds catch fragments through grating; the Restaurant level looks *out at* the city through its windows; the Upper Structure is *above* the city; the Bomb Chamber is the only zone that closes off the view entirely (compressed climax). This visibility arc is the single most important atmospheric throughline — every level designer and lighting artist must protect the player's sightlines to the city at altitude.

### Plaza — Paris Night, Ground Level

**Mood target:** Glamorous menace — the city is beautiful and something is very wrong.

**Diegetic lighting:** Exterior Paris night. Primary sources: sodium-vapor street lamps (warm amber, ~2200 K) casting pools of orange on wet cobblestone; the tower's own period floodlights (cool white, ~4500 K) raking upward from ground-mounted fixtures, creating hard uplight on ironwork faces. Result: a two-temperature contrast — orange ground plane against blue-grey steel canopy overhead. Shadows are deep and directional. Slight atmospheric haze around each lamp pool; clear 1965 Paris air otherwise.

**Atmospheric descriptors:** Luminous, vast, exposed, theatrical, crisp.

**Energy level:** Measured.

**Signature visual element:** The tower's upward floodlights project iron lattice shadows across the cobblestone plaza — a repeating diamond grid that makes flat ground feel like a stage grid, and tells the player exactly where the light ends and cover begins.

### Lower Scaffolds — Industrial Vertical

**Mood target:** Functional exposure — this is where the tower works, not where it performs.

**Diegetic lighting:** Transition zone between the warm plaza below and the cool structure above. Sources: caged utility bulbs strung along scaffold rails (incandescent, ~2700 K, low wattage), the ambient upwash from the plaza floodlights fading with altitude, first glimpses of open sky at the edges, and fragments of the Paris cityscape visible between platework. Result: isolated amber pools on ironwork grating, wide dark intervals between, no fill. High contrast.

**Atmospheric descriptors:** Clanging, vertiginous, stripped, industrial, alive.

**Energy level:** Kinetic.

**Signature visual element:** A single caged work lamp swinging on a hook — the only moving diegetic light source in the game. Its pendulum arc sweeps a cone of amber across the grating floor, creating a genuine timing puzzle from a practical object.

### Restaurant Level — Warm Interior, Occupied Space

**Mood target:** Wrong glamour — the event is real and Eve is an uninvited guest in someone else's party.

**Diegetic lighting:** Interior period restaurant. Sources: crystal pendant chandeliers (warm incandescent, ~2400 K) over dining tables, wall sconces with fabric shades casting side fill, candles on tables adding intimate low pools. Result: the warmest zone in the entire mission — a saturated golden-amber environment with soft shadow edges. The contrast here is not dark-versus-light but hue — warm interior against the cool blue Paris cityscape glimpsed through the restaurant's tall arched windows. Players must be able to walk to a window and see Paris spread out below — the cityscape is part of the room's atmosphere, not just background dressing.

**Atmospheric descriptors:** Opulent, crowded, warm, incongruous, perfumed.

**Energy level:** Contemplative.

**Signature visual element:** The chandelier above the central dining table — a period crystal fixture whose warm cone of light defines a no-go zone of maximum visibility, around which every route the player finds must navigate.

### Upper Structure — High Altitude, Exposed Ironwork

**Mood target:** Sublime isolation — the city has become abstract and the air has weight.

**Diegetic lighting:** Exterior, high altitude, night. Sources: moonlight as the dominant key (cool blue-white, ~6500 K simulated as a directional from upper-left), distant city glow as a faint warm ambient rising from below, and the tower's period navigation beacons (red, low pulse frequency) as accent fills. Result: the coolest, starkest zone — blue-grey iron against near-black sky, with the warm city glow below inverting the Plaza's color relationship. Shadows are long and horizontal rather than downward. The player has 360-degree visibility of the Paris cityscape — every direction the camera turns, the city is there, rendered as flat layered silhouettes in the comic-panel ink language.

**Atmospheric descriptors:** Exposed, silent, monumental, cold, weightless.

**Energy level:** Suspended.

**Signature visual element:** The Paris city grid seen far below — a warm amber lattice of street lamps that rhymes compositionally with the iron lattice Eve stands on, collapsing figure and ground into a single geometry seen at two scales.

### Bomb Chamber — Enclosed Climax

**Mood target:** Compressed urgency — everything narrows to this room and these hands.

**Diegetic lighting:** Interior maintenance space at the antenna. Sources: a single overhead utility strip light (cool fluorescent, ~5000 K, flickering slightly — a period failing ballast), emergency red standby lamps on the device itself, and no natural light. Result: the harshest, most clinical zone — cool white overhead, red accent from the device, deep shadow in every corner. After the warmth of the restaurant and the vastness of the upper structure, the chamber reads as a compression of both space and palette. The view of Paris is deliberately removed (no windows) — the climactic loss of the city visibility is part of the mood.

**Atmospheric descriptors:** Claustrophobic, clinical, ticking, red-tinged, terminal.

**Energy level:** Frenetic.

**Signature visual element:** The bomb device itself — a period prop dressed with analog gauges, blinking PHANTOM-red indicator lamps, and stenciled Cyrillic typography. It is the room's only warm-colored object, and the only thing the player's eye can go to.

### Document Discovery Overlay — Reading Register

**Mood target:** Suspended parenthesis — Eve has stopped; the world can wait.

**Visual register shift:** The gameplay view dims to ~30% opacity and shifts toward desaturated sepia (a held frame that recedes). The document card renders at full saturation as a foreground graphic object: period typewriter font, paper texture, PHANTOM letterhead or BQA form headers. This shift is diegetic in logic — the player has picked up a physical object and is reading it — and so the visual register change is earned, not arbitrary.

**Atmospheric descriptors:** Still, dry, bureaucratic, deadpan, intimate.

**Energy level:** Contemplative.

**Signature visual element:** The document's typeset header — a Saul Bass–influenced logotype treatment in PHANTOM or BQA house style that makes even a mundane expense report feel like a designed artifact from a real organization.

### Main Menu / Pause Menu — First and Returning Impression

**Mood target:** The mission brief — you are being handed this case, not dropped into chaos.

**Visual register:** A period graphic design composition: Eiffel Tower silhouette as flat graphic element against a saturated field (deep BQA blue), with the mission title in a condensed period typeface. No animated 3D scene; no live gameplay background. The menu belongs to the same comic-panel register as the game itself — flat, bold, composed. Pause menu inherits this graphic frame (partial overlay, same color field) so returning to the menu never feels like leaving the world.

**Atmospheric descriptors:** Composed, authoritative, period, graphic, cool.

**Energy level:** Contemplative.

**Signature visual element:** The Eiffel Tower rendered as a single flat silhouette shape — no detail, no shading — against the BQA blue field, echoing vintage Air France travel poster graphic language and immediately establishing the game's entire visual register before a single frame of gameplay runs.

---

## 3. Shape Language

### 3.1 Character Silhouette Philosophy

Silhouette is the primary identification system. Because lighting is diegetic and varies dramatically across sections — from deep ironwork shadow on the scaffolds to the restaurant's warm pendant pools — costume and body proportion must carry all recognition load without lighting assistance. Each archetype owns one unmistakable shape at thumbnail scale:

**Eve Sterling** — structured A-line silhouette: tailored jacket with slightly flared skirt or tapered trouser, small-profile gadget belt, clean shoulder line. Her shape is the most geometrically precise in any crowd — she reads as deliberate against the noise around her. No helmet, no weapon visible at rest. The "nothing to see here" silhouette that is clearly the most composed shape in the room.

**PHANTOM Grunt Guards** — rounded industrial mass: bowl helmet with a slight forward overhang, padded shoulders, short wide stance. The helmet dome is their identifier; it reads as a circle at distance, PHANTOM red trim ring confirming faction. Chunky, not tall. NOLF1's character grammar: readable exaggeration of period military surplus plus theatrical villain dressing.

**PHANTOM Elite / Named Enemies** — taller than grunts, narrower, with a peaked officer cap or distinctive silhouette accessory (cape edge, exaggerated lapel, monocle shape at close range). Elite status read through verticality contrast against the squat grunt mass.

**Paris Civilians** — period soft shapes: bouffant hair, A-line coat, beret. Rounder, softer, slower-moving. No hard geometric reads. They are visual noise the eye learns to filter; their softness makes any guard's rigid silhouette pop forward.

**BQA Contacts** — civilian-passing but with one deliberate composed-geometry tell (a folded newspaper held at a specific angle, a period briefcase with BQA-proportioned clasp). Discovery reward for players who look carefully.

*Serves Pillar 2: Discovery Rewards Patience — the contact's tell is findable, not flagged.*

### 3.2 Environment Geometry

The dominant language is **angular and rhythmic** — repeating geometric units rather than organic flow. Gustave Eiffel's ironwork is not a smooth curve; it is a systematic grammar of triangulated lattice, rivet grids, and diagonal cross-bracing that repeats at multiple scales. This is *self-similar geometry*, and it is the game's single most important environmental shape fact.

Stylization rule for the ironwork: **simplify the lattice unit, preserve the rhythm.** Rather than modeling every rivet, establish one triangulated bay as the repeating module and tile it. The recognizability of the Eiffel Tower comes from its silhouette and its lattice rhythm, not from rivet count. A single comic-panel outline on a simplified lattice reads as more Eiffel Tower than a hyper-detailed mesh whose outlines turn to noise. This directly honors the comic-panel rule from Section 1.

Interior vs. exterior contrast is deliberate and strong: **restaurant interiors use curves** — chandelier arcs, arched windows, rounded chair backs — creating a warm rounded grammar that reads as human-occupied and period-domestic against the cold angular ironwork outside. When the player moves between interior and exterior zones, the geometry shift signals the mood shift before audio does.

*Serves Pillar 4: Iconic Locations as Co-Stars — the ironwork's lattice rhythm is a geometry that cannot be transplanted to any other setting.*

### 3.3 UI Shape Grammar

The HUD is **NOLF1-styled and period-appropriate**, not absent. Faithful to NOLF1, the player has continuous access to: health, current weapon and ammo count, active gadget, and any temporary status (poisoned, alarmed area). What is forbidden is *modern* HUD vocabulary — no objective markers, no minimap, no kill cams, no ping systems, no quest log overlays.

HUD shape vocabulary is **flat graphic / Saul Bass grammar**:
- Hard-edged rectangles and clean type — no rounded corners, no soft glows, no drop shadows.
- Health and ammo as period-typeset numerals (condensed sans-serif, e.g., Futura or DIN-influenced) on a thin solid color field — readable as printed information, not modern interface chrome.
- Active gadget shown as a flat silhouette icon in BQA or PHANTOM-faction color, never as a 3D rendered miniature.
- HUD lives in the screen corners with consistent margins; never floats in the center of the play space; never anchors to world objects (no diegetic-floating waypoints).

For **framed information** (documents, briefing screens, mission start cards), shape vocabulary is **period letterhead grammar**: rectangular card with thin rule border, letterhead logotype at top (PHANTOM or BQA house style, Saul Bass–influenced), typewriter-set body text. The document IS the framing — its shape should be indistinguishable from a prop someone designed in 1965.

For **menu shapes** (main and pause), the vocabulary is **flat graphic-design poster**: hard-edged rectangles, condensed type, no drop shadows. Menu shapes belong to the same world as vintage Air France poster design — deliberate geometry, not interface chrome.

*Serves Pillar 5: Period Authenticity Over Modernization — the HUD is present but contains no shapes that postdate 1965.*

### 3.4 Hero Shapes vs. Supporting Shapes

**Outline weight is the hierarchy system.** The comic-book outline post-process does not apply uniform line weight; it applies a tiered hierarchy:

- **Eve and key interactive objects** (documents, bomb components, gadget pickups): **heaviest outline weight**. These are always foreground graphic elements. The eye goes here first.
- **PHANTOM guards**: **medium outline weight**. Threats must read clearly, but they should not compete with Eve or objectives.
- **Environment geometry** (ironwork, furniture, background dressing): **lightest outline weight** — only on foreground-facing edges. The lattice reads as texture, not as a figure-level shape.
- **Civilians**: **light outline** with softer color contrast to push them into the mid-ground.

> Concrete pixel-weight specifications for each tier live in **Section 8 (Asset Standards)**, where they can be authoritatively versioned alongside texture and poly budgets.

Comedic environmental elements (absurdist signage, labeled crates) are treated as **hero shapes locally** — they get heavy outlines and maximum contrast color within their immediate composition, regardless of their position in the level. This operationalizes Principle 3 from Section 1 in the shape system.

*Serves Pillar 1: Comedy Without Punchlines — the joke's punchline is visual, delivered by shape hierarchy before the player reads the text.*

---

## 4. Color System

### 4.1 Primary Palette

| Color | Hex | Role | Where it appears |
|---|---|---|---|
| **PHANTOM Red** | `#C8102E` | Antagonist faction identifier; the game's most dangerous color | Guard helmet trim rings, bomb device indicator lamps, PHANTOM document header rules and letterhead, restricted-area door indicators |
| **BQA Blue** | `#1B3A6B` | Player's agency identifier; deep, authoritative | Main menu field, gadget icon tints, BQA briefing headers, radio contact indicators, Eve's BQA-branded equipment |
| **Eiffel Grey** | `#6B7280` | The structural canvas; cool-leaning desaturated steel | Tower ironwork, scaffolding rails, platework, grating |
| **Paris Amber** | `#E8A020` | The warmth of occupied civilian space; period light pools | Sodium street lamps (Plaza), pendant chandelier cones (Restaurant), caged utility bulbs (Lower Scaffolds), candle pools |
| **Parchment** | `#F2E8C8` | Document white; period-correct off-white, separates from every surface | All in-world readable documents (PHANTOM memos, BQA briefings, guard schedules, absurdist forms) |
| **Comedy Yellow** | `#F5D000` | Reserved for absurdist comedy elements; bright, slightly anachronistic | Prop crate labels, oversized signage with joke text, warning signs with comedic copy. **Never used for genuine hazards or HUD state.** |
| **Alarm Orange** | `#E85D2A` | Reserved for HUD critical-state signaling; semantically distinct from PHANTOM Red (faction) and Comedy Yellow (comedy) | Health-critical numeral state in HUD only. **Never used in the world** (no in-world Alarm Orange props, paint, fabric, or lighting). |
| **Moonlight Blue** | `#B0C4D8` | The coolest tone; high-altitude sky and ambient fill | Open sky at altitude, moonlit ironwork, Paris city-glow on upper sections |

### 4.2 Semantic Color Vocabulary

**Faction identity is permanent, not contextual.** PHANTOM Red and BQA Blue do not change meaning at any alert level. Guards are always PHANTOM Red–trimmed. Eve's gadget icons are always BQA Blue–tinted. The vocabulary never reverses.

- **PHANTOM Red = threat and authority.** Every object marked PHANTOM Red is either an enemy, a danger, or a restriction. Players learn this in the Plaza (first red helmet trim sighting) and the rule never breaks.
- **BQA Blue = agency and resource.** Gadget pickups, BQA radio contacts, friendly NPCs, and the menu screen all carry BQA Blue. The player's tools are blue; the enemy's are red.
- **Interactive vs. decorative is signaled by OUTLINE WEIGHT, not color** (per Section 3.4). A red PHANTOM crate is decorative; a red bomb component is interactive. The outline tier — not the hue — tells the player which is which. This prevents the game from needing a hover-glow or HUD waypoint.
- **Document type by header color:** PHANTOM internal documents use red header rules on Parchment. BQA briefings use BQA Blue header rules on Parchment. Civilian documents (restaurant menus, guard schedules, maintenance logs, comedic internal forms) use Eiffel Grey rules on Parchment — no faction color, period typeface. The header color alone tells the player which organization produced the document before they read a word.
- **Hazard cue:** bomb device indicator lamps use PHANTOM Red with a slow blink (the device "breathes" PHANTOM Red in the Bomb Chamber). Explosive or irreversible-consequence objects share this PHANTOM Red + slow blink language. **No other objects blink.**

### 4.3 Per-Location Color Temperature

| Location | Dominant Temp | Palette Anchors | Key Color Contrast |
|---|---|---|---|
| **Plaza** | Warm ground / cool overhead | Paris Amber (street lamp pools) + Moonlight Blue (floodlit steel canopy) | Orange cobblestone floor vs. blue-grey iron ceiling |
| **Lower Scaffolds** | Warm islands in cool dark | Paris Amber (caged work bulbs) + Eiffel Grey (deep dark intervals) | Isolated amber against near-black scaffold spans |
| **Restaurant** | Warmest zone | Paris Amber dominant, Parchment wall panels, BQA Blue glimpsed through arched windows (Paris cityscape) | Warm interior chamber vs. cool Paris-blue night outside |
| **Upper Structure** | Coolest zone | Moonlight Blue dominant, Eiffel Grey ironwork, Paris Amber city-glow rising from below | Cool moonlit iron above / warm amber city-grid below |
| **Bomb Chamber** | Clinical cool + red accent | Moonlight Blue (fluorescent overhead), PHANTOM Red (device lamps), near-black corners | Cool clinical white vs. PHANTOM Red — the entire chamber |
| **Document Overlay** | Sepia world dimmed | World drops to ~30% desaturated sepia; Parchment document at full saturation | Full-color document vs. ghost-world behind it |
| **Menu** | Deep cool authority | BQA Blue field, Parchment type, Eiffel Tower as black flat silhouette | BQA Blue vs. Parchment — graphic poster contrast only |

### 4.4 UI / HUD Palette

The HUD is period-styled (per Section 3.3 — Saul Bass / flat graphic vocabulary). Specific color assignments:

- **HUD field:** thin solid strip of **BQA Blue `#1B3A6B`** at 85% opacity — dark enough to ensure legibility on all section backgrounds. Period-flat: no gradient, no blur. HUD lives in screen corners with consistent margins.
- **Numerals and text** (health, ammo, timer): **Parchment `#F2E8C8`** in condensed period sans-serif. Reads as "printed information," not screen chrome.
- **Active gadget icon:** flat silhouette in **BQA Blue `#1B3A6B`** on a slightly lighter BQA tint field (`#2A4F8A`). One-color flat icon — no gradients. PHANTOM-sourced gadgets or captured enemy equipment use **PHANTOM Red `#C8102E`** icon tint to signal their origin.
- **Health critical state:** when health drops below 25%, the health numeral shifts from Parchment to **Alarm Orange `#E85D2A`** (a fourth palette color reserved exclusively for HUD critical signaling — semantically distinct from PHANTOM Red, which is faction-coded, and Comedy Yellow, which is comedy-coded). No animation, no pulse — just the numeral color change, paired with a faint clock-tick audio cue.
- **Document overlay palette:** Parchment `#F2E8C8` card body; faction header in PHANTOM Red or BQA Blue (per document origin); body text in near-black `#1A1A1A` (period typewriter ink); marginal annotations in Eiffel Grey `#6B7280` (period pencil).

### 4.5 Colorblind Safety

**Universal rule: no semantic meaning is ever carried by hue alone.** Every color assignment in this section is backed by at least one non-hue cue: shape, position, animation pattern, or sound.

**At-risk pair 1 — PHANTOM Red `#C8102E` vs. Paris Amber `#E8A020`** (deuteranopia / protanopia)
A red-green colorblind player may read both as similar warm-yellow.
*Backup cue:* PHANTOM Red objects always carry faction shape (helmet dome, PHANTOM letterhead logotype, slow-blink lamp pulse). Paris Amber is never on a figure — it is always a light source pool on a surface. Shape and behavior distinguish them without hue.

**At-risk pair 2 — PHANTOM Red HUD elements vs. BQA Blue HUD elements** (protanopia)
Both may read as similar dark values.
*Backup cue:* PHANTOM Red does not appear in HUD numerals — it is only used for gadget icon tints on captured enemy equipment, always paired with a Cyrillic or PHANTOM-glyph icon shape. BQA Blue is the HUD field itself. The semantic separation is spatial (field vs. icon), not hue alone.

**At-risk pair 3 — Health critical (Alarm Orange `#E85D2A`) vs. normal (Parchment `#F2E8C8`)** (tritanopia, low-contrast vision)
Both warm values may read similarly under tritanopia. Alarm Orange is darker and more saturated than Parchment, providing stronger luminance separation than Comedy Yellow would have, but is still imperfect.
*Backup cue:* health numerals are the only HUD element that changes color, and the change is accompanied by (a) a faint clock-tick SFX at critical health (consistent with the Bomb Chamber's ticking motif), and (b) a 1-frame numeral flash on every damage event regardless of health level. No colorblind profile loses the warning.

---

## 5. Character Design Direction

### 5.1 Player Character — Eve Sterling

**One outfit, the entire mission.** Eve wears a single, consistent silhouette from Plaza to Bomb Chamber. This is a deliberate identity decision: she is recognizable at any distance in any section because her shape never changes. NOLF1's Cate Archer also held a strong constant silhouette per mission; the same logic applies here.

**The outfit:**
- **Collarless structured jacket** — Courrèges 1965 reference, midnight-navy `#15264A` (a deeper kin to BQA Blue, near-but-not-faction). Square shoulders, no lapel softness, hem just below the hip. Reads as a single hard rectangle in silhouette.
- **Thin BQA-blue piped seam** at the jacket lapel edge — the only faction signaling on Eve's person, present from frame one. Subtle enough that it is not the dominant read; deliberate enough that an observant player notices "she's BQA" without being told.
- **Tapered ankle trouser** — same midnight-navy, narrow line, accentuates height against architecture.
- **Low-slung matte gadget belt** — not a holster, more a mod accessory belt. All compact rectangular hardware. Eiffel Grey `#6B7280` against the navy outfit.
- **Square-toe block heel** — Mary Quant–influenced, low enough for stealth movement, graphic enough to read as intentional. Black leather.

**Hair:** A precise geometric cut — a blunt bob, jaw-length, no movement softness. At any resolution it reads as a single flat shape against her neck: one more geometric element in an already geometric silhouette. Hair color is a near-black with one slight cool-tint highlight (avoids muddy black-on-black against the jacket).

**Pose and animation style.** Stiff and deliberate — theatrical composure, never naturalistic fidget. Default rest pose is weight-neutral, arms slightly away from the body (ready, not casual). Idle is minimal: a slow, measured weight shift, no hand-to-face gestures. Ready stance draws the arms forward but keeps the shoulders level — controlled, not crouched. NOLF1's mid-stylized theatrical posture is the target: exaggerated enough to read from distance, restrained enough that Eve never performs for the camera.

**Facial expression range.** Deadpan is the default. Eve's resting expression is attentive-neutral — eyes slightly wide, mouth closed. Full range available to portrait and cutscene artists: raised single eyebrow (maximum skepticism), a fractional narrowing of the eyes (calculation), and one specific expression reserved for the mission's single genuine beat — a very small, very controlled closed-mouth near-smile. She never grins. She does not mug. The world provides the comedy; Eve provides the witness.

### 5.2 Antagonists — PHANTOM

**Grunt guards — variant system.** The 6–10 enemy types are all PHANTOM, differentiated within the grunt archetype by three axes that do not introduce new factions:

- **Helmet variant** (primary read): standard bowl with flat visor vs. open-face with chin strap (patrolling exterior vs. interior duty). The dome silhouette is always preserved; only the face aperture changes.
- **Trim color** (secondary read): standard grunt carries the PHANTOM Red ring trim. Interior guards (Restaurant, Bomb Chamber) carry a narrower trim in a desaturated crimson — slightly more formal, slightly less field-ready. One trim width = one threat tier, readable at distance.
- **Accessory** (tertiary read): radio-carrier guard has a period walkie-talkie clipped to the chest harness, antenna visible. Takedown priority signaling without a UI marker.

**Elite / named enemies.** Elite status is read through three things: height (elites stand a half-head taller than grunts, achieved through proportion, not literal scale), the peaked PHANTOM officer cap replacing the bowl helmet, and one personal silhouette accessory — a floor-length operational coat with exaggerated lapels. For the Bomb Chamber arrival boss, the coat has a cape-back panel that reads as a single flat geometric shape at distance: unmistakably "this one is named." No monocle at gameplay scale; reserved for cutscene portrait use.

**Civilian-disguise enemies.** One variant in the Restaurant section: a PHANTOM operative dressed as a service waiter. The tell, consistent with Pillar 2 (Discovery Rewards Patience), is sartorial and behavioral: the period waiter's jacket fits correctly, but the cuffs fall too short — an inch of the PHANTOM patrol boot visible below the trouser hem rather than service-appropriate oxford. Patient observers will also notice the operative never makes eye contact with guests and always positions with their back to a wall. No UI flagging; discovery is the reward.

### 5.3 Civilians and Contacts

**Paris civilians.** The Restaurant section needs four distinct civilian models to avoid repetition at density: (1) a formal-dining couple sharing one costume slot (male tuxedo silhouette, female bouffant-hair A-line gown — two shapes, one behavioral unit), (2) an older male diner in a period suit with rounded shoulders, (3) a younger woman in a geometric shift dress, (4) a maître d' in standard service dress. Wardrobe palette: Paris Amber, warm Parchment, muted period burgundy, Eiffel Grey. **Under no circumstances does any civilian carry PHANTOM Red or BQA Blue.** Their outlines are light, their colors muted — they are visual noise that makes any guard's hard silhouette pop immediately forward.

**BQA contacts / friendly NPCs.** The on-the-ground Paris contact appears once, in the Plaza. Visual tell: a specific folded newspaper (Le Monde, held under the left arm at a 45-degree angle — the BQA-standardized recognition posture, noted in a document Eve has presumably read). The radio handler, heard but not seen in gameplay, exists as a document portrait only — flat graphic in BQA Blue framing, half-face composition in the period-spy-novel fashion, deliberately low-detail. One composed-geometry tell per contact is the rule: no BQA armband, no blue glow, no UI ping.

### 5.4 LOD Philosophy and Detail Preservation

The FPS camera means most character LOD decisions are close- to mid-range. The Plaza and Lower Scaffolds are the only sections where guards appear at genuine distance (across the cobblestone expanse or between scaffold spans). The preserved hierarchy at any distance:

- **Silhouette shape** is never sacrificed. The grunt's helmet dome, the elite's officer cap, and Eve's geometric bob must read at thumbnail scale. If a model's silhouette collapses at distance, the mesh is wrong — simplify rather than add LOD.
- **Outline and faction color** are preserved down to minimum render distance. The PHANTOM Red trim ring is the last color to be lost; it should still be legible at the maximum scripted encounter distance (~40m).
- **What can be dropped at distance:** texture pattern detail, prop accessories (radio clip, belt hardware), facial aperture on helmets.

**LOD sentence per archetype:**

- **Eve:** preserve silhouette geometry and gadget belt mass at all distances; face detail is cutscene-only.
- **PHANTOM grunt:** preserve helmet dome shape and Red trim ring; face aperture and chest accessories drop first.
- **PHANTOM elite:** preserve height differential and coat silhouette at distance; lapel and cap peak detail drops to mid-distance.
- **Paris civilian:** soft shapes with light outlines — distance collapse is acceptable because civilians are never primary read targets.
- **BQA contact:** appears only in controlled proximity; no LOD budget required.

---

## 6. Environment Design Language

### 6.1 Architectural Style and Cultural Grounding

**Ironwork stylization rule — extends Section 3.2.** The "simplify the lattice unit, preserve the rhythm" principle translates into three practical constraints for level designers and modelers:

1. **One canonical bay module per altitude tier.** Model a single triangulated bay — one diagonal cross-brace, two horizontal rails, one vertical post — at the correct aspect ratio for each tier. All ironwork geometry tiles from this module. **Do not model individual rivets**; add the rivet repeat as a flat painted pattern on the surface (consistent with Principle 1, Section 1). Three modules total: plaza-tier (wide, heavy base), mid-scaffold (tapering), upper-structure (narrow, compressed).
2. **Outline-first silhouette check.** Before any ironwork mesh is signed off, render it with only the comic-book outline pass active against a flat white field. If the lattice rhythm reads as legible geometry rather than noisy line-spaghetti, it passes. If outlines merge into solid shapes or dissolve into visual static, simplify the module.
3. **Collision geometry follows the module, not the detail.** Traversal surfaces (climbable rails, walkable grating, vaultable beams) must correspond to the canonical module edges — level designers build encounters around the module grid, not around hero-detail geometry added after the fact.

**The Restaurant — design language: Late Belle Epoque Survival, 1965-interpreted.** The fictional predecessor to Le Jules Verne is not a clean Mid-Century Modern renovation; it is the original 1890s tower dining salon that was never fully modernized, retrofitted with 1950s–60s period lighting and furniture without removing the curved ironwork ceiling ribs and arched window surrounds. Reads as: wrought-iron structural arches (inherited from the tower, not designed for the room), warm walnut paneling introduced in a postwar renovation, crystal pendant chandeliers as the dominant lighting fixture, and a 1960s geometric carpet pattern (bold concentric diamond repeat in Paris Amber and BQA Blue) that is the room's most explicit mod-era intervention. The collision of eras is the joke — ironwork from 1889, carpet from 1963, silverware from 1955.

**The Bomb Chamber — canonical identity: original 1889 antenna maintenance alcove, PHANTOM-occupied.** This is not a PHANTOM-built room; it is a real structural maintenance space at the antenna base that PHANTOM has commandeered and minimally modified. Architectural language: raw riveted ironwork walls (no paneling, no finishing), a poured concrete service floor (treat as "someone poured this in the 1930s"), a single overhead utility strip light on a metal conduit chase. PHANTOM's additions are purely instrumental: the device itself (hero prop), a period relay-rack of electronics, and stenciled PHANTOM wayfinding in Cyrillic and a block-serif English secondary. **The room reads as found and occupied, not built. Boiler room, not villain's lair.**

### 6.2 Texture Philosophy

**Format: hand-painted flat with applied geometric pattern.** No photographic source textures. No procedural noise applied at the material level. Every surface is a flat painted color field (a single Hex value from the palette in Section 4.1) with a geometric pattern tile drawn by hand and composited on top. The pattern is the texture; the base color is the surface.

**Tile vs. unique:**

- **Tiling surfaces:** ironwork lattice (canonical bay module surface), cobblestone Plaza floor, Restaurant carpet (diamond repeat), Restaurant wall paneling (two-color horizontal wood-grain stripe), scaffold grating (diamond-plate repeat in Eiffel Grey on slightly lighter Eiffel Grey).
- **Unique surfaces:** the bomb device (one UV unwrap, no tiling), Eve's jacket and gadget belt, named prop labels (document covers, PHANTOM crate stencils, absurdist signage), the Restaurant chandelier body, the Bomb Chamber relay-rack face.

**Qualitative resolution baseline: tight pixel grid, intentional.** Texture resolution should read as printed rather than photographic. Patterns have hard edges with no anti-aliasing applied during painting — the outline post-process handles softness at render time. Pattern boldness is the quality metric, not pixel density. (Explicit texel budgets live in Section 8.)

**Pattern library — when patterns appear and when they don't:**

- **Chevron frieze**: applied to all vertical interior wall surfaces in BQA-administered or civilian-occupied spaces (Plaza guard post, Restaurant walls). Never on raw ironwork. Never in the Bomb Chamber.
- **Diamond op-art**: Restaurant carpet only. The room's most saturated pattern. Not exported to other sections.
- **Rivet repeat**: all exposed ironwork surfaces — all sections. The pattern that never stops. Density decreases with altitude (upper-structure rivet repeat is sparser than the heavy base-tier platework).
- **Concentric stripe (mod / atomic motif)**: used only on comedic hero props (crate labels, absurdist signage). A signal to the player: when you see concentric stripe geometry on a prop, it is likely comedic.
- **Bare Eiffel Grey with no pattern**: raw maintenance surfaces in the Bomb Chamber only. The absence of pattern in the climax room is deliberate contrast — the whole game has had patterns; the climax strips them.

### 6.3 Prop Density Rules

**Per-section density targets:**

| Section | Density Character | Rule |
|---|---|---|
| **Plaza** | Sparse, architectural | One hero prop cluster (guard post, lamp standard, cobblestone pattern). Environmental props are large-scale and few. Max three interactive props in any 10m radius. |
| **Lower Scaffolds** | Industrial minimal | Props are functional objects: tool crates, coiled cable, scaffold clamps. Nothing decorative. One swinging lamp (Section 2 signature). Max two prop clusters per scaffold span. |
| **Restaurant** | Dense, curated | Tables with full place settings, occupied by civilians. Sideboard, drinks trolley, coat rack, chandeliers. Every table is a prop cluster. Density high but organized along clear circulation paths — the player always has a visual read of where to move. |
| **Upper Structure** | Exposed, sparse | Structural ironwork dominates. Only props: navigation beacon housing, one maintenance box, railing system. Paris is the visual content; props would compete with it. |
| **Bomb Chamber** | Sparse-but-packed | The bomb device occupies the room's center axis. Flanked by the PHANTOM relay-rack, two equipment crates (stackable, functional), and one overturned maintenance stool. Nothing else. The device has no competition. |

**Document placement rules.** 15–25 documents across five sections; working target is **5 documents per section (±2 based on narrative need).** Placement by surface type:

- **Desks and work surfaces** → PHANTOM operational documents (orders, guard schedules, requisitions). Documents live where guards pause.
- **Pinned to ironwork or walls** → PHANTOM internal memos, absurdist notice-board items. Higher on the wall = older and less urgent; eye-level = recently posted and plot-relevant.
- **Tucked or hidden** → BQA intelligence drops, civilian personal items (a letter from home found in a guard's jacket pocket — discoverable on takedown). Reward the patient observer.
- **On dining tables or service carts** → Restaurant only. Personal items, handwritten notes, comedic menu specials. Placed in ways that suggest the diner they belong to.
- **No document is placed on the floor unless deliberately staging a scene** (an overturned drink next to an unconscious guard, the scattered papers of a hasty exit).

**Hero props beyond the bomb device** — six total for the entire mission, list does not grow without a design decision:

1. The bomb device (Bomb Chamber)
2. Eve's gadget pickups (one per section, eye-level on a flat surface, heaviest outline weight in the room)
3. The swinging lamp (Lower Scaffolds — only moving light source)
4. The Restaurant central chandelier (defines no-go visibility zone)
5. The PHANTOM relay-rack (Bomb Chamber — device's visual "second")
6. The Plaza BQA contact's folded newspaper (hero prop at pickup distance only)

### 6.4 Environmental Storytelling Guidelines

**NOLF-grammar for comedy and lore beats.** Every environmental story beat must work as a visual gag or a lore delivery on first encounter, **without any text explanation and without the player needing to interact**. If the joke requires the player to pick something up to understand it, the staging is wrong — the scene must work first as a visual read.

**Practical examples:**

- **PHANTOM bulletin board** (Lower Scaffolds): three memos pinned in strict bureaucratic order — a shift schedule with one guard name crossed out and replaced in handwriting, a memo headed *"RE: UNAUTHORIZED USE OF COMMUNAL FONDUE POT,"* a performance review marked "UNSATISFACTORY" in red rubber stamp. The comedy is the bureaucratic form applied to villainy. The visual read is the layout: corkboard, paper, red stamp visible from mid-distance.
- **Overturned wine glass + unconscious diner** (Restaurant): no interaction required. The glass on its side, a spreading wine stain on the tablecloth (unique decal applied to this table only), the diner face-down. The player understands: someone was drugged here before Eve arrived. Comedy and lore simultaneous.
- **Maintenance ladder leaning against an off-limits structural element**: the ladder is the level designer's invitation. Its presence against a wall or platform edge is a visual contract — this is climbable, and you are meant to find it. The ladder is never placed accidentally.

**Threshold rule — what ships vs. what is clutter.** A storytelling beat ships if it passes all three:

1. It is readable as a visual composition within three seconds of the player entering the space, **without interaction**.
2. It either pays off comedy or pays off lore — **not neither**.
3. It does not require any other beat in the same room to make sense.

Beats that depend on each other for the joke must be reduced to the strongest single element. **Cap: 2–3 environmental storytelling beats per section.** Every beat beyond three in a single section requires a cut elsewhere in the same section. This is a density cap, not a quota.

---

## 7. UI/HUD Visual Direction

### 7A. Diegetic vs. Screen-Space Treatment

The HUD is **screen-space, not world-attached.** No floating waypoints, no diegetic health bars, no world-space prompts. Faithful to NOLF1: the player reads the screen edges, not the environment, for status information.

**Corner assignments (1080p reference; scale proportionally at other resolutions):**

- **Bottom-left — Health field:** thin horizontal BQA Blue `#1B3A6B` strip at 85% opacity, ~120 px wide × 28 px tall. Right-aligned numeral in Parchment `#F2E8C8`. A condensed label ("HP" or final period abbreviation) sits to the left of the numeral at 60% numeral size.
- **Bottom-right — Weapon and ammo field:** mirrored geometry. Weapon name (condensed caps, smaller point size) on the upper line; current/reserve ammo (`14 / 38`) on the lower line, slash at 70% numeral width.
- **Top-right — Active gadget field:** square tile (56 × 56 px), BQA Blue at 85% opacity, hard-edged. Gadget silhouette icon centered on a slightly lighter BQA tint `#2A4F8A`. Captured PHANTOM gadgets shift the icon tint to PHANTOM Red `#C8102E`. **Noisy gadgets carry a small period sound-wave glyph in the upper-right corner of the tile** (3 concentric arcs in Parchment); silent gadgets do not.
- **Center-lower (contextual, transient) — Interaction prompts and pickup notifications:** single-line strip anchored 18% up from bottom-center. Appears on trigger entry, dismisses on interaction or exit. Same BQA Blue field + Parchment type as the corners. A picked-up document notification reads as a one-line period memo header (`"MEMO ACQUIRED — PHANTOM INTERNAL COMMUNIQUE"`), reinforcing the document tone rather than breaking it with modern pop-up grammar.

**No center-screen HUD elements are permanent.** The play field's center is protected from chrome at all times.

### 7B. Typography Direction

**Primary HUD typeface — condensed period sans-serif.** Three candidates considered:

1. **Futura Condensed Bold** — closest analogue to NOLF1's HUD register; humanist but geometric (1927 vintage, ubiquitous in 1965 design). Strong cap height, tight set-width.
2. **DIN 1451 Engschrift** — German industrial standard, narrower and more mechanical. Excellent for numerals at small sizes.
3. **Univers 57 Condensed** — Adrian Frutiger 1957; rationally even, slightly less distinctive at small sizes.

**Recommendation: Futura Condensed Bold** as the primary face for HUD numerals, **with a minimum point size floor of 18px equivalent at 1080p**. Below that floor (e.g., HUD numerals if the resolution forces small typography on lower-res displays), substitute **DIN 1451 Engschrift** — Futura's geometric construction degrades on the figures "1," "4," and "7" at small sizes, while DIN was designed for legibility at small scales (German road signage). This split is enforced as an asset standard in Section 8.

Type weight and tracking: **Bold weight only** in HUD numerals. Tracking **tight (−20 to −30 units)** — condensed sans-serif at small sizes reads as a printed block rather than scattered characters. Size hierarchy at 1080p: health/ammo numerals 22 px; labels 13 px; interaction-prompt line 14 px.

**Document overlay typeface — period typewriter:**
- **American Typewriter** (ITC, 1974 design but period-authentic visual register) as primary; if licensing is a constraint, **Courier Prime** (open license, refined Courier) is the fallback.
- Body text in Regular weight. Headers and stamped text (e.g., "CONFIDENTIAL," "UNSATISFACTORY") in Bold.
- Letter-spacing on header stamps: **wide (+80 to +120 units)** — mimics mechanical letterpress stamp spacing.

**Logotype and menu header typeface — Saul Bass register:**
- **Futura Extra Bold Condensed** for mission title cards, PHANTOM and BQA logotypes, and the main menu title treatment. The two weights of the same face (HUD = Condensed Bold; menu = Extra Bold Condensed) create typographic family coherence across all registers.
- If a second display face is needed for contrast (e.g., PHANTOM logotype vs. BQA), **Helvetica Neue Condensed Black** works as a cold foil — rational versus geometric.

**Important typeface split:** Saul Bass / Futura Extra Bold Condensed is for **large display** (document headers, menu, mission cards). The HUD numerals at gameplay scale use **Futura Condensed Bold** (or DIN below the size floor). Do NOT apply the display face to the HUD numerals at small sizes — it produces legibility failures.

### 7C. Iconography Style

**Gadget icons:** flat solid silhouette, single color (BQA Blue tint on tint field; PHANTOM Red on tint for captured equipment). **No gradients. No outlines on the icon itself** — the icon IS the silhouette shape. The icon must read as a recognizable object at 56 × 56 px without any detail line. If it requires a line to read, the silhouette is insufficiently designed.

**Noise-level glyph (per noise-spec decision):** noisy gadgets carry a small 3-arc concentric sound-wave glyph in the icon tile's upper-right corner, in Parchment, ~12 × 12 px. Silent gadgets carry no glyph. Players learn the rule on first encounter; the glyph acts as a permanent visual reminder thereafter.

**Interaction prompt icons:** none. The prompt is text-only — `"PRESS [E] TO LIFT COVER"` — typeset in Futura Condensed Bold, Parchment on BQA Blue strip. The key name renders inside a thin inline rectangle (hard-edged, 1 px Parchment rule stroke). This is how period printed user manuals denoted key inputs — typographically authentic and avoids modern iconographic keyboard-button convention.

**Status icons** (poisoned, takedown-ready, alarmed-area entry): same icon grammar as gadgets — flat solid silhouette, 28 × 28 px, rendered adjacent to the relevant HUD strip rather than as a separate floating badge.

- **Poisoned:** appends a small silhouette to the health field — period PHANTOM-styled skull-and-flask glyph (not the modern trefoil biohazard).
- **Takedown-ready:** no persistent icon. A single Parchment text prompt appears on the center-lower contextual strip (`"TAKEDOWN AVAILABLE"`) when condition is met, then dismisses.
- **Alarmed-area indicator:** solid rectangle of PHANTOM Red `#C8102E` appended to the top-right gadget tile's upper edge — 56 × 6 px. The only time PHANTOM Red appears in the HUD corner cluster, making the faction color do its semantic work (PHANTOM Red = danger).

**Style rule: solid silhouette only in the HUD.** Outlines are a world-geometry language (Section 3.4); introducing outline-only icons into the HUD would blur the visual grammar that separates diegetic space from screen-space information.

### 7D. Animation Feel for UI Elements

**HUD update animations: instant.** Numerals update on a single frame — no count-up, no slide. Ammo decrements by one per trigger pull; health decrements on hit. The audio design carries kinetic weight (gunshot SFX, hit SFX); the HUD does not editorialize.

**Damage feedback (per damage-feedback decision): 1-frame numeral flash.** On every damage event, the health numeral renders as bright white `#FFFFFF` for one frame, then returns to its current color (Parchment if above 25%, Alarm Orange if below). No screen shake, no vignette, no chromatic aberration. The numeral alone confirms the hit; restraint amplifies it.

**Health critical state transition (below 25%):** the health numeral's color shifts from Parchment `#F2E8C8` to **Alarm Orange `#E85D2A`** on a single frame — no crossfade, no pulse. Paired with the clock-tick SFX cue (Section 4.4). No further animation.

**Document overlay enter/exit:**
- **Enter:** overlay fades in over 12 frames (0.2s @ 60 fps). Document card translates in from 15% below its final resting position over the same 12 frames, easing to a hard stop (no overshoot). Reads as the physical act of lifting paper into reading position. SFX: paper-rustle and a soft, dry tock as it settles — one event, not a loop.
- **Exit:** card translates 15% down and fades over 8 frames (faster — dismissal is decisive). World-dim releases over 12 frames.
- **Dismiss controls:** KB/M = `Esc` or `E`; gamepad = `B / Circle`. Long documents that exceed one card scroll with mouse wheel / right stick; a small Parchment scroll-indicator glyph appears in the card's lower-right when scroll content exists below the fold.

**Save/load (per save-load decision): period mission-dossier card.** Save and load use the same letterhead grammar as in-world documents — a BQA mission-dossier page, Futura Extra Bold Condensed header (`"OPERATION: PARIS AFFAIR — MISSION RECORD"`), American Typewriter body listing save metadata (section name, time, screenshot in flat-graphic register). The card enters and exits using the same paper-translate-in motion as the document overlay (visual coherence). No spinner, no progress bar — if loading exceeds 2 seconds, a single small Parchment glyph (a slowly rotating period reel-to-reel symbol) appears in the card's lower-right.

**Menu transitions:**
- Main menu → gameplay: a **hard cut**, not a fade. The poster composition holds for one deliberate beat after the start input, then cuts directly to the Plaza. Saul Bass title sequences cut; they do not wipe or cross-fade.
- Pause menu: BQA Blue overlay extends from the top edge downward over 10 frames, covering gameplay. Exit reverses upward over 10 frames. Reads as a page laid over the scene, then lifted. No motion blur, no DoF change on the underlying gameplay view.
- Between pause sub-panels: immediate cut, Futura Condensed Bold section header stamped in on the cut frame.

### 7E. Open Design Questions (to resolve in subsequent design work)

These were raised by the UX alignment review and require either game-design or systems-design decisions that are out of scope for the art bible:

- **Document reading during alert state.** When a player opens a document while guards are in suspicious/searching state, does the AI pause, continue off-screen, or actively interrupt? This is a game-design decision with pillar tension between "Stealth is Theatre" (theatre needs time) and "Discovery Rewards Patience" (reading must be safe enough to be possible). Resolve before implementing the document overlay system.
- **Gadget cycling visual feedback.** With 3–5 gadgets, the player needs to see what's queued during cycling. A brief temporary stack of icons (period stack of cards) is one option; a numeral-only readout is another. Resolve in a UX design pass before prototyping the gadget system.
- **Subtitle placement during document overlay.** Subtitles for guard banter and ambient VO will collide spatially with the document card. Two options: (a) suppress ambient subtitles while a document is open, (b) position subtitles inside the document card's lower edge. Resolve when subtitle system is designed.
- **HUD contrast verification per section.** The 85% opacity BQA Blue field should provide sufficient separation from gameplay backgrounds, but this must be **playtested in every section** — particularly Restaurant (warm walls vs Parchment numerals) and Bomb Chamber (cool fluorescent vs BQA Blue field). If contrast fails, the field opacity may need to increase to 90–95% in those sections.

---

## 8. Asset Standards

> **Engine context:** Godot 4.6, Forward+ renderer (Vulkan/Linux, D3D12/Windows), Jolt 3D physics, GDScript primary. Performance budget: 60 fps · 16.6 ms frame · ≤1500 draw calls · ≤4 GB memory ceiling. Per `docs/engine-reference/godot/VERSION.md`, Godot 4.4–4.6 is **beyond the LLM training cutoff** — items marked **⚠ verify** must be checked against `docs/engine-reference/godot/` or official 4.6 docs before implementation.

### 8A. File Formats

| Asset | Source format | Engine format | Reason |
|---|---|---|---|
| Textures | `.png` (8-bit, sRGB, no embedded ICC profile) | Godot-imported `.ctex` (BPTC/BC7 on desktop) | Lossless source preserves hard pattern edges; outline shader reads color boundaries — lossy formats cause spurious edges |
| Models / scenes | `.glb` (binary glTF 2.0) from Blender 3.6+ or 4.x (Y-up, Z-forward) | `.tscn` for scene assembly inside Godot | glTF 2.0 is Godot 4's native target; FBX requires the proprietary importer |
| Animations | Baked into the same `.glb` for self-contained characters; separate `.glb` referencing canonical rig for shared rigs | Imported as Animation resources in Godot | — |
| Audio | Defer to audio-director — Godot prefers `.ogg` (Vorbis) for music/loops, `.wav` for short SFX | — | — |

**Color profile rule:** all textures sRGB. **No PBR maps authored or imported** — no normal, roughness, or metallic maps. If an outsourced model arrives with PBR maps, the maps are rejected at import.

**Lighting bake rule:** never bake lighting into textures — all lighting is diegetic and runtime-sourced (Section 2). Pattern tiles (chevrons, rivets, diamond carpet) are flat overlay layers composited into the source texture; the composited flat result exports.

### 8B. Naming Conventions

All asset files use `snake_case` (matches GDScript convention from `.claude/docs/technical-preferences.md`).

**Textures**: `tex_[zone]_[surface]_[variant]_[size].png`
Examples: `tex_plaza_cobblestone_base_2k.png`, `tex_restaurant_carpet_diamond_2k.png`. Reusable pattern tiles drop the zone prefix: `tex_tile_rivet_repeat_512.png`. UI/document textures use the `ui_` or `doc_` prefix: `ui_hud_icons_atlas.png`, `doc_phantom_memo_01_card.png`.

**Models / scenes**: `[archetype]_[name]_[variant].glb`
Examples: `char_eve_sterling.glb`, `char_phantom_grunt_bowl_helmet.glb`, `char_phantom_grunt_open_face.glb`, `char_phantom_elite_peaked_cap.glb`, `env_eiffel_bay_module_plaza.glb`, `prop_bomb_device_hero.glb`.

**Materials**: `mat_[archetype]_[surface]_[variant]`
Examples: `mat_phantom_grunt_standard` (PHANTOM Red trim), `mat_phantom_grunt_interior` (desaturated crimson narrow trim). Materials link to **archetypes**, not individual textures — a material swap produces a trim-tier variant without duplicating mesh.

**LODs**: append `_lod0`, `_lod1`, `_lod2` to the base name. All LODs of one asset live in the same `.glb`.

**Variant rule (mesh vs material swap):** a variant gets a unique mesh only if the silhouette changes (bowl helmet vs open-face → mesh split). Color/pattern-only changes (standard trim vs interior trim) are material swaps, not mesh duplications.

### 8C. Authoritative Specs from Prior Sections

#### Outline weights (1080p reference; scale proportionally at other resolutions)

| Tier | Assets | Weight at 1080p |
|---|---|---|
| **Heaviest** | Eve Sterling, key interactive objects (gadget pickups, bomb components, uncollected documents), comedic hero props (signage, labeled crates) | **4 px** |
| **Medium** | PHANTOM guards (all variants, all helmet types) | **2.5 px** |
| **Light** | Environment geometry, civilians | **1.5 px** |

#### Typography size floors (1080p reference)

| Element | Typeface | Min size at 1080p |
|---|---|---|
| HUD numerals (health, ammo) | Futura Condensed Bold; substitute **DIN 1451 Engschrift** below 18 px | **22 px rendered; 18 px floor** |
| HUD labels ("HP", weapon name) | Futura Condensed Bold | **13 px** |
| Interaction prompt line | Futura Condensed Bold | **14 px** |
| Document body text | American Typewriter Regular (Courier Prime fallback) | **16 px** |
| Document header stamp | American Typewriter Bold | **20 px** |
| Menu / mission card title | Futura Extra Bold Condensed | **36 px** |

### 8D. Engine Hard Budgets

#### Polycount (triangles at LOD0)

| Asset | Triangle Budget |
|---|---|
| Eve — FPS hands (in-play) | 2,000 |
| Eve — full body (cutscene only) | 4,500 |
| PHANTOM grunt guard (per variant) | 2,800 |
| PHANTOM elite / named enemy (per variant) | 3,500 |
| Civilian model (per variant) | 1,800 |
| Hero prop (bomb device) | 2,500 |
| Generic environment prop (table, chair, lamp) | 300–600 |
| Tiling Eiffel bay module | 800 |

**Aggregate scene ceiling:** Restaurant section (densest) ≤180,000 tris in frustum at any moment.

#### Texture resolution caps

| Asset / Surface | Max Resolution | Notes |
|---|---|---|
| Character body | 1024 × 1024 | Unlit flat color + hand-painted pattern; higher buys nothing at silhouette-first rendering |
| Character face/head (if separated) | 512 × 512 | Largely flat color |
| Environment tileable (lattice, cobblestone, carpet, rivet repeat) | 512 × 512 | Tiling covers deficit; >512 compounds VRAM with every repeat |
| Hero prop unique | 1024 × 1024 | One UV unwrap, no tiling |
| UI / document overlay | 1024 × 1024 per page | Pixel-sharp typeface rendering required |
| HUD element atlas | 256 × 256 per sheet | Icons ≤56 × 56 px (Section 7); pack into single atlas |

#### Material slots per asset

| Asset Type | Max Slots | Slot Assignment |
|---|---|---|
| Character (any) | 2 | Body/costume + face/head if separated |
| Hero prop | 2 | Main surface + emissive detail (indicator lamps, blinking elements) |
| Generic environment prop | 1 | Single flat unlit material; no emissive |
| Tiling environment module | 1 | Single tiling material per module type |

#### Texture memory budget (post-BPTC compression; ~4:1 ratio on RGBA)

| Category | Limit |
|---|---|
| Per-section budget (one section loaded) | 512 MB VRAM |
| Cross-section transition (two adjacent sections in memory) | 800 MB VRAM |
| UI / HUD (always resident) | 32 MB VRAM |

### 8E. Importer Settings (Godot 4.6)

#### Texture compression
- Default: **BPTC (BC7)** for character and prop textures on desktop. Handles flat colors and hard pattern edges far better than S3TC/DXT1 (which produces visible block artifacts on solid-color fields).
- S3TC/DXT1 fallback acceptable for environment tiles only; not for character or document overlay textures.
- Color profile: all textures **sRGB**.
- ⚠ verify: the `compress/mode` integer mapping (`mode = 3` → "VRAM Compressed") may have shifted in the 4.4+ importer refactor. Use the editor importer UI label, not the integer alone, when setting compression in `.import` files.

#### Mipmaps

| Asset Type | Mipmaps | Reason |
|---|---|---|
| Character and prop textures | **ON** | Prevents Moiré aliasing on geometric patterns at distance |
| Tiling environment textures | **ON** | Critical for rivet repeat / cobblestone quality at mid-range |
| UI / HUD textures (icons, font atlases) | **OFF (explicit)** | Screen-space; mipmaps soften pixel-precise period typefaces |
| Document overlay card | **OFF (explicit)** | 1:1 sampling; mipmaps degrade typeface sharpness |

> Mipmaps are **ON by default** in Godot's importer. You must explicitly disable them in the `.import` sidecar for UI/document assets — do not leave the default.

#### Model import (glTF 2.0)
- `skins/use_named_skins = true`; skeleton naming must match the rig convention agreed with the animator.
- `materials/location = 0` (mesh-level). Do **not** import Blender PBR material slots — strip on import. Godot materials are authored inside Godot.
- ⚠ verify (4.4+): shader uniform texture types changed from `Texture2D` to `Texture` as the base. Check the 4.6 shader reference before writing any hand-written shader uniform.

#### Animation import
- `animation/import_rest_as_reset = true` — rest pose becomes the `RESET` track in Godot, referenced by IK and blend trees.
- `animation/optimizer/enabled = true` — built-in optimizer removes redundant keyframes; safe for stylized theatrical animations. Visually verify after import; the optimizer can over-simplify slow-ease animations.
- ⚠ verify (4.6): the IK system was fully restored in 4.6 via `SkeletonModifier3D` nodes (CCDIK, FABRIK, TwoBoneIK). Use `SkeletonModifier3D`-based IK rather than any 4.3-era workaround. Verify exact modifier node names in the engine reference.

### 8F. Outline Post-Process Budget

#### Architecture
The comic-book outline pass is implemented as a **`CompositorEffect`** resource attached to a `Compositor` node on `Camera3D` or `WorldEnvironment` (the 4.3+ pattern — do **not** use manual viewport chains or screen-reading shader tricks from older tutorials).

#### Render order
1. Opaque geometry pass
2. **Outline pass** (reads depth/normal buffers, draws outlines screen-space)
3. Transparent geometry (HUD overlay, document dim effect)
4. UI / `CanvasLayer` (HUD, document card)

#### Performance budget
- Reference: full-screen pass at 1920×1080 = ~2M pixels processed
- Target: **0.8–1.5 ms per frame** on mid-range desktop (RTX 2060 equivalent)
- Hard cap: **≤2 ms** (12% of the 16.6 ms frame budget). If the pass exceeds this on minimum-spec hardware, first optimization is reducing the sampling kernel width and accepting thinner outlines — **not** disabling the pass.
- Tiered weights (4 / 2.5 / 1.5 px from 8C) implementation: encode object category into the **stencil buffer** (Godot 4.5+), sample stencil in the outline pass to select kernel width per tier. Avoids running four separate outline passes.
- ⚠ verify: stencil buffer access from a `CompositorEffect` shader was added in 4.5; the exact API surface is post-cutoff.

#### Minimum-spec scaling
On integrated graphics (Intel Iris Xe equivalent), build a **resolution-scale option** (render at 75% internally, upscale to 1080p output) into `ProjectSettings` from the start. Do not retrofit later.

### 8G. Lighting Budget per Section

> Forward+ renderer uses clustered lighting. Exact per-cluster limit in 4.6 ⚠ verify against `rendering/limits/cluster_builder` in `ProjectSettings`.

| Budget Category | Limit |
|---|---|
| Max real-time **shadow-casting** lights per section | 8 |
| Max real-time lights total (shadow + non-shadow) per section | 24 |
| Shadow casters per section (practical recommendation) | 4 |
| Static baked lights (lightmaps) | Not used — unlit shading |

**Per-section practical allocation:**

| Section | Light Plan |
|---|---|
| Plaza | 2–3 SpotLights (floodlights, shadow-casting) + 4–5 OmniLights (street lamp pools, no shadows) + 1 directional (ambient city glow) |
| Lower Scaffolds | 3–4 OmniLights (caged bulbs, no shadows) + **1 shadow-casting OmniLight on the swinging lamp** (the only animated shadow caster — budget 1.5–2 ms for its shadow pass) |
| Restaurant | 2 shadow-casting SpotLights (chandeliers) + 4–6 OmniLights (sconces, candles — no shadows, short falloff) |
| Upper Structure | 1 shadow-casting `DirectionalLight3D` (moonlight) + 2 OmniLights (navigation beacons, no shadows) + ambient via `WorldEnvironment` |
| Bomb Chamber | 1 shadow-casting SpotLight or DirectionalLight3D (fluorescent strip) + 2–3 OmniLights (PHANTOM Red device lamps, no shadows) |

**Static vs dynamic ratio:** target 70% non-shadow / 30% shadow. The Lower Scaffolds swinging lamp is the only animated light source — no other light source moves.

### 8H. LOD Strategy

| Asset | LOD Count | Method |
|---|---|---|
| Eve — FPS hands | 1 LOD only | Never at distance |
| Eve — full body (cutscene) | 1 LOD | Fixed cutscene camera distance |
| PHANTOM grunt guard | 3 LODs | **Handcrafted** — silhouette dome must survive simplification |
| PHANTOM elite | 3 LODs | Handcrafted |
| Civilian | 2 LODs | Auto-LOD acceptable for LOD1 |
| Hero prop (bomb device) | 2 LODs | Handcrafted |
| Generic environment prop | 2 LODs | Auto-LOD acceptable |
| Tiling Eiffel bay module | 2 LODs | Handcrafted — lattice outline quality is non-negotiable |

> ⚠ verify: Godot 4.5 introduced automatic LOD generation; exact API and quality controls are post-cutoff. **Handcraft characters; auto-LOD for env props only** — auto-LOD does not understand silhouette priority and may clip vertices off the helmet dome curve.

**LOD distance thresholds (meters):**

| Asset | LOD0 → LOD1 | LOD1 → LOD2 | LOD2 → Cull |
|---|---|---|---|
| PHANTOM grunt | 18 m | 35 m | 55 m |
| PHANTOM elite | 20 m | 40 m | 60 m |
| Civilian | 12 m | 30 m | 50 m |
| Hero prop | 20 m | 40 m | Never cull |
| Generic env prop | 10 m | 25 m | 45 m |
| Eiffel bay module | 15 m | 40 m | 80 m (visible from altitude) |

**PHANTOM Red trim preservation rule:** LOD1 and LOD2 grunt meshes must retain helmet dome geometry and UV-map the trim ring region. Do not merge the trim into the body UV island at lower LODs.

### 8I. Outsourcing Spec Sheet Template

Every outsourced asset brief must include:

```
ASSET BRIEF — THE PARIS AFFAIR
================================
Asset name:         [snake_case, per 8B convention]
Asset category:     [Character / Prop / Environment Module]
Triangle budget:    [LOD0 max from 8D]
Material slots:     [max from 8D]
Texture resolution: [from 8D]
Texture content:    Flat painted color + hand-painted geometric pattern.
                    NO normal/roughness/metallic maps. NO photographic source.
                    NO procedural noise.
Color palette:      Use hex values from Art Bible Section 4.1 ONLY.
UV mapping:         Single UV unwrap (UV0). No overlapping. Seams hidden inside
                    costume edges or back of head. 4 px margin at 1024 px.
Rigging:            [YES / NO — if YES, provide skeleton spec doc separately]
File format:        glTF 2.0 (.glb preferred). Y-up, Z-forward.
LOD delivery:       [Count from 8H]. Each LOD as a separate mesh in the same .glb,
                    named [assetname]_lod0, _lod1, _lod2.
Naming convention:  snake_case. No spaces. No special characters except underscore.
Outline test:       Before delivery, render the mesh in flat-lit white with a
                    1 px black edge trace. Silhouette must read clearly.
                    Submit this render alongside the model file.
```

### 8J. Engine Version Uncertainty Flags

The following items involve Godot 4.4–4.6 features beyond the LLM training cutoff. **Verify each against `docs/engine-reference/godot/` and the official 4.6 release notes before implementation.**

1. **Stencil buffer access from `CompositorEffect`** (4.5+) — used by the tiered outline implementation in 8F. Confirm the API surface for reading stencil values inside a CompositorEffect shader.
2. **Automatic LOD generation** (4.5) — exact feature name, importer settings, quality controls. Auto-LOD is acceptable only for env props per 8H.
3. **Shader Baker workflow** (4.5) — for pre-compiling outline shader variants to eliminate first-frame stutter.
4. **Texture importer mode integers** (4.4+ refactor) — use the editor UI label, not the integer, when setting `compress/mode` in `.import` files.
5. **Forward+ per-cluster light limits** (4.6) — verify in `ProjectSettings → rendering/limits/cluster_builder` before relying on the 8/24 light budget in 8G.
6. **`SkeletonModifier3D` IK API** (4.6 IK restoration) — verify exact modifier node names before implementing FPS hand procedural placement.
7. **Glow tonemapping order** (4.6 changed glow to process before tonemap) — irrelevant to this project (no glow), but disable glow explicitly in `WorldEnvironment` to prevent emissive-material accidents (e.g., bomb device indicator lamps inadvertently triggering glow).

---

## 9. Reference Direction

### Reference 1 — *No One Lives Forever* (2000), Monolith Productions

**What to take — Section 5 (Character) + Section 6 (Environment):** The relationship between character silhouette and prop density. NOLF1 used readable, exaggerated costumes against controlled-density environments so that figure-ground separation never required UI assistance. Study specifically: the Morocco mission interiors (warm incandescent props against cool architecture — the same two-temperature logic this game uses); the guard patrol behavior as performance rather than threat (they move in legible arcs, not tactical sweeps); and the document prop design — each readable item is a foreground graphic artifact with clear typographic hierarchy.

**What to avoid:** NOLF1's geometry is early-2000s boxy — it achieves silhouette through costume color contrast, not shape, because the models lacked polygon budget for clean silhouette geometry. This game has a better polygon budget and relies on actual shape. Do not model PHANTOM guards as square-shouldered blobs and rely on the red trim to carry the read; build the helmet dome silhouette first.

**Bible sections served:** 5.1 (Eve silhouette logic), 5.2 (guard archetype system), 6.3 (prop density rules), 6.4 (environmental storytelling grammar)

### Reference 2 — Saul Bass, title sequences for *The Man with the Golden Arm* (1955) and *Anatomy of a Murder* (1959)

**What to take — Section 7 (UI) + Section 3 (Shape):** The specific compositional moves: hard-cut transitions (not wipes), flat geometric shapes used as figure-ground dividers, condensed sans-serif type set large against a field of a single color, and the visual weight that comes from negative space rather than decoration. The BQA Blue menu field, the mission card compositions, the document overlay entering from below — these inherit the Bass grammar directly. Bass's title sequences treat text as a shape, not as signage — letters have the same visual weight as the geometric elements. This is the model for how PHANTOM and BQA logotypes should be constructed.

**What to avoid:** Bass's late-period work (post-1970) became painterly and illustrative. The reference is limited to the 1955–1965 phase: flat, geometric, typographic. Do not import illustrated or hand-lettered stylizations.

**Bible sections served:** 7B (typography direction), 7C (iconography), 3.3 (UI shape grammar), 2 (document overlay visual register)

### Reference 3 — *Gloomwood* (2022–2024), New Blood Interactive

**What to take — Section 8 (Standards) + Section 1 (Identity):** Proof of concept for a stylized FPS built on a flat-unlit shading model with a custom post-process pass. Study it with the renderer in mind, not the mood: look at how surface legibility is maintained across dramatic lighting variance with no PBR roughness, how the silhouette system works when the camera is close (FPS hands) versus mid-distance (enemy guards), and how a consistent visual fingerprint is maintained from environment to environment without a photographic texture library. Stylization is a discipline, not an aesthetic accident — Gloomwood's look required active enforcement across all assets.

**What to avoid:** Gloomwood's register is Victorian horror-tension. Its color temperature is persistently cold and desaturated. Do not let proximity to this reference pull any section of this game cold or toward horror. The technique is transferable; the emotional register is not.

**Bible sections served:** 8A–8H (engine and pipeline standards), 1 (visual identity discipline as active enforcement)

### Reference 4 — André Courrèges, Spring/Summer 1965 Collection (press and catalog photography)

**What to take — Section 5.1 (Eve Sterling):** Courrèges 1965 is the literal source for Eve's silhouette: the collarless jacket with squared shoulders and no lapel softness, the tapered trouser, the block-heel square-toe shoe. His 1965 press photography also demonstrates the key silhouette principle for this game — a geometric costume reads as a distinct composed shape even in a busy environment because every edge is a deliberate line. Look at the way his models are photographed against mid-century architectural backgrounds: the costume does not blend into or compete with the architecture; it provides a second, contrasting geometry. That is the figure-ground rule for Eve throughout the game.

**What to avoid:** Courrèges' use of pure white as the dominant costume color. White would destroy figure-ground separation in every interior section (Parchment walls, document overlays). Eve's midnight-navy is Courrèges' geometry in a stealth-appropriate hue. Do not import his palette; take only the cut.

**Why Courrèges over Mary Quant** (an obvious alternative): Quant is rounder and more graphic-print focused — that's the civilian register, not Eve's.

**Bible sections served:** 5.1 (Eve's complete costume specification), 5.4 (LOD silhouette preservation logic)

### Reference 5 — Alfred Hitchcock, *To Catch a Thief* (1955), cinematography by Robert Burks

**What to take — Section 2 (Mood) + Section 4 (Color):** The two-temperature night lighting that this film invented for the glamour-menace register: warm amber street and interior light as the ground plane, cool blue-grey as the architectural overhead and sky. Burks' night exteriors on the French Riviera are the direct precedent for the Plaza lighting specification — sodium-warm cobblestones, cool floodlit architecture above. The film demonstrates how to make a beautiful, dangerous night feel simultaneously inviting and wrong without any atmospheric fog or horror-genre cues. Study the casino terrace and rooftop chase scenes for how the two temperatures are managed in motion.

**What to avoid:** The film's daytime sequences are naturalistic, high-key, and Mediterranean-bright — nothing in this game is daytime, and naturalistic fill would destroy the diegetic-light-only rule. Also avoid importing the film's depth-of-field treatment; Hitchcock and Burks used shallow focus to guide attention, but this game uses outline weight for that job.

**Bible sections served:** 2 (Plaza and Upper Structure mood and lighting rationale), 4.3 (per-location color temperature logic)

### Reference 6 — Vintage Air France travel posters, 1950–1967 (particularly the Paris-route series by Bernard Villemot and Georges Mathieu)

**What to take — Section 2 (Menu mood) + Section 6.1 (cultural grounding):** The specific graphic move is the Paris cityscape rendered as a flat silhouette layer — Eiffel Tower as a single flat shape against a field of saturated color, no detail, no shading, legible from a meter away. This is the direct model for the main menu composition and for the Paris cityscape visible from the Upper Structure and Restaurant windows. The posters also establish the color authority of the project's non-faction palette: the warm yellows and cool blues of the Paris-route series are the direct antecedents of Paris Amber and Moonlight Blue.

**What to avoid:** The posters' depictions of human figures — they are illustrative and proportionally fluid in a way that would conflict with this game's geometric-silhouette character grammar. Reference the posters for architectural and color direction only; do not import their figure style into character design.

**Bible sections served:** 2 (menu/pause visual register), 4.1 (Paris Amber and Moonlight Blue sourcing), 6.1 (cultural and period grounding for the city visibility arc)

### How to use this reference set

Open each reference alongside the specific bible section it serves — that pairing is in the entry, not implied. Start with the **Courrèges catalog (Reference 4)** alongside Section 5.1 before touching any character work, and the **Bass sequences (Reference 2)** alongside Section 7 before touching any UI work. These two have a one-to-one mapping to a deliverable. The **Hitchcock cinematography (Reference 5)** is a 30-minute viewing session with Sections 2 and 4.3 open; stop the film when you have the Plaza and Upper Structure color temperatures in your mind and move on. **NOLF1 (Reference 1)** should be watched as a filmmaker watches reference footage — paused on specific frames of costume, guard patrol, and document prop staging, not played through as a game. The **Air France posters (Reference 6)** and the **Gloomwood pipeline (Reference 3)** are visual calibration tools, not mood pieces: ten minutes each, with a specific question in mind before you open them. **Do not play Gloomwood for an hour to absorb its atmosphere — its atmosphere is wrong for this game. Take the technique; leave the register.**
