# Asset Specs — System: Stealth AI (PHANTOM)

> **Source GDD**: `design/gdd/stealth-ai.md` (§Visual/Audio Requirements)
> **Art Bible**: `design/art/art-bible.md` (§5.2 Antagonists — PHANTOM; §3.4 Hero Shapes; §8 Asset Standards)
> **Governing ADR**: `docs/architecture/adr-0001-stencil-id-contract.md` (PHANTOM guards = stencil tier 2 MEDIUM)
> **Sprint**: 09 (`production/sprints/sprint-09-asset-commission-hybrid.md`)
> **Generated**: 2026-05-09
> **Status**: 4 assets specced / 0 approved / 0 in production / 0 done

## Tier Summary

| Asset | Tier | Sprint 09 Deliverable | Pipeline |
|---|---|---|---|
| ASSET-003 — PHANTOM Grunt Bowl Helmet | **T2** | Base mesh `.glb` exported to `assets/models/stealth-ai/` | Image-first → image-to-3D → MCP cleanup (Path 4) |
| ASSET-004 — PHANTOM Grunt Open-Face Helmet | **T2** | Base mesh `.glb` (mesh split per §8B silhouette-change variant rule) | Image-first → image-to-3D → MCP cleanup |
| ASSET-005 — PHANTOM Elite Bomb-Chamber Boss | **T2** | Base mesh `.glb` (taller proportions + officer cap + operational coat) | Image-first → image-to-3D → MCP cleanup |
| ASSET-006 — Walkie-talkie radio (chest accessory) | **T1** | Final `.glb` exported to `assets/models/stealth-ai/` | Image-first → image-to-3D → MCP cleanup; static prop, no rig |

## Out of Scope (deferred per art bible §8B variant rule + Sprint 09 boundary)

- **Trim color variants** (standard PHANTOM Red `#C8102E` vs interior desaturated crimson) — these are **material swaps**, NOT mesh duplications per §8B. Resolved in texture pass (Sprint 10+).
- **PHANTOM Civilian-Disguise (Service Waiter)** — depends on civilian models from art bible §5.3, which are a separate context (Restaurant level). Defer until level Plaza / Restaurant context spec is authored.
- **Radio-carrier "variant" of grunt** — per §5.2 this is the same grunt body with the walkie-talkie ASSET-006 attached as accessory via socket/constraint. Attachment wiring is Sprint 10+ scene integration.
- **Rigging + animations** (patrol_walk, investigate_sweep, combat_fire, dead_slump, chloroformed_slump, chloroformed_rising, weapon_draw, head_turn IK) — Sprint 09b post-base-mesh.
- **Bomb Chamber boss cape-back panel** — per §5.2 the cape "reads as a single flat geometric shape at distance" and is conceptually part of the operational coat. Bake into ASSET-005 base mesh as continuous geometry; do NOT separate as own asset.
- **3 LODs handcrafted per §8H** — Sprint 09 ships LOD0 only (same convention as ASSET-002).

---

## ASSET-003 — PHANTOM Grunt — Bowl Helmet (Exterior Patrol)

| Field | Value |
|---|---|
| Asset ID | ASSET-003 |
| Category | Character — full-body humanoid, base mesh |
| Tier | T2 (base mesh; rig deferred) |
| File path (target) | `assets/models/stealth-ai/char_phantom_grunt_bowl_helmet.glb` |
| Material name | `mat_phantom_grunt_standard` (placeholder navy/black; full palette in texture pass) |
| Naming convention | `char_phantom_grunt_bowl_helmet.glb` (per §8B `char_[name]_[variant].glb` example) |
| Triangle budget LOD0 | **2,800** (art bible §8D — PHANTOM grunt guard per variant) |
| LOD count | 1 in Sprint 09 (3 LODs handcrafted is post-base-mesh §8H deliverable) |
| Texture resolution | 1024 × 1024 body (texture pass deferred) |
| Material slots | 2 max per §8D (body/costume + face/head if separated). Sprint 09 placeholder = 1. |
| Texture content | Flat painted color + hand-painted pattern. NO PBR maps. NO photographic source. NO procedural noise. |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO in Sprint 09 — base mesh only. Full biped + L/R hand attach points deferred to Sprint 09b. |
| Outline tier | **MEDIUM** (2.5 px @ 1080p, color `#1A1A1A`) — art bible §8C |
| Outline implementation | **ADR-0001 stencil tier 2** — at scene-load, MeshInstance3D for grunt sets stencil ref to tier 2 (NOT tier 1 — guards do not compete with Eve for foreground read) |
| Use case | Primary enemy archetype across Plaza, Lower Scaffolds, Upper Structure (3 of 5 sections) |
| UV mapping | Single UV unwrap (UV0). Seams hidden inside helmet rim, costume seams, back-of-head. 4 px margin at 1024 px. |
| Status | **Needed** — visual reference APPROVED 2026-05-10 |
| Visual reference (canonical) | `design/assets/specs/references/phantom_grunt_bowl_helmet_reference_2026-05-10.png` |

### Approved Visual Reference

The canonical character reference image at `design/assets/specs/references/phantom_grunt_bowl_helmet_reference_2026-05-10.png` is the **single source of truth** for ASSET-003's silhouette, helmet shape, trim placement, and proportion. Approved 2026-05-10 after 2 iterations:

- **iter 1**: helmet was full-mask covering entire face; visor at mouth level; PHANTOM Red trim ring at chin/neck (read as collar, not helmet identifier — broke §5.2 "PHANTOM Red trim ring confirming faction at distance" rule)
- **iter 2 (approved)**: bowl helmet ends at brow exposing face below, visor at brow hiding eyes only, PHANTOM Red ring trim around helmet's lower circumference at brow line — silhouette identifier restored

Residual (acceptable) deviations in approved iter 2:
- Trim color rendered slightly darker than canonical PHANTOM Red `#C8102E` — irrelevant for image-to-3D since textures are stripped during cleanup and replaced with hex anchor from §4.1
- Arms slightly outward but not full A-pose with palms facing thighs at 25-30° — image-to-3D may introduce minor shoulder/armpit topology issues; correctable in Blender during cleanup if needed

This image is now the input to image-to-3D conversion (Tripo3D / Hyper3D Rodin image mode / Hunyuan3D 2 / Meshy.ai).

### Visual Description

A short-wide chunky industrial-mass humanoid in dark uniform, helmet-domed and visor-faced. The figure reads at thumbnail scale as a circle (helmet) atop a square (padded shoulders) atop a wider rectangle (torso + boots) — the geometric inversion of Eve's slim vertical precision. The bowl helmet is the dominant identification element: a perfect dome with a flat horizontal visor cutting across the face, edged by a single hard PHANTOM Red ring trim that runs around the helmet's lower circumference. Padded military-surplus shoulders (think 1965 East-Bloc militia rather than NATO infantry — Cold War theatrical villainy, not real-world specificity) widen the upper silhouette. A chest harness with rectangular pouches sits over a black tunic; a side belt at the waist holds a holstered period sidearm. Trousers tuck into mid-shin combat boots with thick chunky soles. Hands gloved. The figure stands at A-pose, weight-neutral, arms slightly out from the body — combat-ready resting posture, not casual.

### Art Bible Anchors

- **§5.2 PHANTOM Grunt**: bowl helmet with flat visor (exterior duty), PHANTOM Red ring trim around helmet dome, padded shoulders, short wide stance, "rounded industrial mass" — chunky not tall.
- **§3.1 Character Silhouette Philosophy**: "rounded industrial mass… chunky, not tall. NOLF1's character grammar: readable exaggeration of period military surplus plus theatrical villain dressing."
- **§3.4 Hero Shapes**: PHANTOM guards = MEDIUM outline weight (do not compete with Eve foreground read).
- **§4.1 Primary Palette**: PHANTOM Red `#C8102E` for trim ring; uniform body in Eiffel Grey-deep variants or near-black.
- **§4.2 Semantic Color Vocabulary**: "PHANTOM Red = threat and authority. Every object marked PHANTOM Red is either an enemy, a danger, or a restriction."
- **§8D Polycount**: 2,800 tris LOD0.
- **§8D Texture cap**: 1024 × 1024 body; 512 × 512 face if separated.
- **§8H LOD Strategy**: 3 LODs handcrafted (deferred); LOD0 → LOD1 at 18m, LOD1 → LOD2 at 35m, cull at 55m.
- **§8B Variant Rule**: bowl helmet vs open-face = mesh split (silhouette change). Standard vs interior trim color = material swap, NOT mesh duplication.
- **§5.4 LOD Sentence**: "PHANTOM grunt: preserve helmet dome shape and Red trim ring; face aperture and chest accessories drop first."
- **GDD §Visual**: ~3k tris (art bible §8D 2,800 is more authoritative; reconciliation deferred to doc-hygiene pass), full biped + L/R hand attach points (deferred), MEDIUM outline tier per ADR-0001.

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Helmet shell | `#1A1A1A` (near-black) | Derived from §5.2 "rounded industrial mass" black palette |
| Helmet trim ring | `#C8102E` (PHANTOM Red) | Art bible §4.1 |
| Helmet visor | `#0A0A0A` (deeper black, glossy implied via flat shading) | Derived |
| Tunic / uniform body | `#1A1A1A` | Derived |
| Shoulder padding | `#1A1A1A` (slightly lighter `#2A2A2A` for break) | Derived |
| Chest harness + belt | `#3A3A3A` (dark grey) | Derived |
| Trousers | `#1A1A1A` | Derived |
| Boots | `#0F0F0F` (deeper than tunic) | Derived |
| Gloves | `#1A1A1A` | Derived |
| Skin (face below visor) | warm parchment-toned `#D4B896` | Derived from civilian skin convention |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt (for image-first workflow — feed to ChatGPT / Flux / Midjourney)

```
Stylized 3D character reference, full body, front-facing A-pose with arms
slightly away from body, neutral standing position. Plain flat white
background, isolated subject, full figure from head to feet visible, no
cropping, no shadows on ground.

CHARACTER: 1965 PHANTOM organization grunt enemy guard, male, mid-20s to
mid-30s, short-wide chunky build (NOT tall slim — military-surplus padded
mass), neutral menacing expression with eyes obscured by helmet visor.

WARDROBE (one consistent uniform — strictly industrial military-surplus
period villain dressing):
- BOWL HELMET in matte near-black: a perfect dome shape covering the top
  of the head with a flat horizontal visor cutting straight across at
  eyebrow level, completely hiding the eyes. A single hard bright PHANTOM
  RED (#C8102E) ring trim runs around the helmet's lower circumference
  where it meets the head — this is the primary identification color
  signal, very saturated.
- PADDED MILITARY-SURPLUS SHOULDERS in matte black: visibly thick,
  squared, exaggerated. Reads as 1965 East-Bloc militia coat, NOT modern
  tactical gear. NO Western infantry chevrons, NO patches.
- BLACK TUNIC torso with high collar; CHEST HARNESS with rectangular pouches
  in dark grey running diagonally across the front. Side belt at waist
  holding a holstered period sidearm.
- BLACK TROUSERS tucked into mid-shin combat boots with thick chunky soles.
- BLACK GLOVES.

BUILD: chunky and slightly squat — broader at shoulders, shorter than
slim heroic proportion. Reads as RoundeD industrial-mass silhouette.

VISUAL STYLE:
- Stylized low-poly 3D character rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors, NO PBR materials, NO
  photorealism, NO subsurface scattering on skin.
- Strong dark outline around the silhouette (comic-book outline ~3px,
  medium weight — not the heaviest).
- Hard edges, no gradient noise, no painterly brushstrokes.
- Aesthetic inspired by: No One Lives Forever (2000) PHANTOM-style guards;
  1960s Cold War villain dressing (Get Smart, The Man from U.N.C.L.E.,
  Our Man Flint); period East-Bloc military-surplus theatricalized.

POSE & FRAMING:
- Standard A-pose for character rigging reference.
- Standing weight-neutral, both feet planted parallel.
- Arms held slightly out from the body, palms facing thighs.
- Camera at eye level, front-facing perspective.
- Full figure visible head to feet.

NEGATIVE / DO NOT INCLUDE:
- NO modern tactical gear, NO MOLLE webbing, NO modern body armor plates.
- NO realistic NATO/US/UK military insignia, NO real-world unit patches.
- NO open-face helmet — this variant has a FULL bowl helmet covering the
  upper face with a horizontal visor.
- NO weapon held in hand — sidearm is HOLSTERED at the waist.
- NO photorealistic skin, NO realistic hair strands, NO realistic fabric
  folds, NO subsurface scattering.
- NO modern athletic build, NO heroic male model proportions — this
  character is chunky, military-padded, short-wide.
- NO smile, NO grin, NO exaggerated emotional expression.
- NO bright colors except the helmet PHANTOM RED ring trim.
- NO accessories beyond the chest harness and side belt (no glasses,
  no jewelry, no scarf, no medals).
- NO walkie-talkie or radio (that is a separate accessory variant — the
  base grunt does not carry one).
```

### Generation Strategy (Path 4 — image-first → image-to-3D)

Same workflow as ASSET-002 (proven 2026-05-09):

1. USER generates image in ChatGPT / Flux / Midjourney with the prompt above
2. CLAUDE evaluates against §5.2 + §3.1 silhouette philosophy; iterates if needed
3. Approved image saved to `design/assets/specs/references/phantom_grunt_bowl_helmet_reference_<YYYY-MM-DD>.png`
4. USER runs image-to-3D (Tripo3D preferred, Hyper3D Rodin image mode, Hunyuan3D 2)
5. CLAUDE imports raw via `mcp__blender__execute_blender_code`; reset homefile, gltf import, inspect via `get_objects_summary`
6. Cleanup pipeline: bake transforms, rotate to face -Y, scale to ~1.75 m height (grunt is slightly shorter than Eve's 1.7 m due to "chunky not tall" but "short-wide" implies similar height with broader proportions — target 1.75 m for now), decimate to 2,800 tris exact, strip textures, assign `mat_phantom_grunt_standard` flat unlit emission shader with helmet near-black + body near-black + trim PHANTOM Red placeholder
7. Render front + side + 3q verification via `render_viewport_to_path`
8. User approval
9. Export to `assets/models/stealth-ai/char_phantom_grunt_bowl_helmet.glb`
10. Manifest update — status `Base mesh — rig deferred`

### Iteration cap

Same as Sprint 09 plan: 3 prompt iterations + 3 image-to-3D service attempts max. If silhouette fails repeatedly, downgrade tier or surface.

---

## ASSET-004 — PHANTOM Grunt — Open-Face Helmet (Interior Duty)

| Field | Value |
|---|---|
| Asset ID | ASSET-004 |
| Category | Character — full-body humanoid, base mesh |
| Tier | T2 (base mesh; rig deferred) |
| File path (target) | `assets/models/stealth-ai/char_phantom_grunt_open_face.glb` |
| Material name | `mat_phantom_grunt_interior` (placeholder for narrower desaturated crimson trim variant) |
| Naming convention | `char_phantom_grunt_open_face.glb` |
| Triangle budget LOD0 | **2,800** (art bible §8D) |
| LOD count | 1 in Sprint 09 |
| Texture resolution | 1024 × 1024 body |
| Material slots | 2 max; Sprint 09 placeholder = 1 |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO in Sprint 09 |
| Outline tier | **MEDIUM** (same as ASSET-003 — both grunts use stencil tier 2) |
| Outline implementation | ADR-0001 stencil tier 2 |
| Use case | Interior guard archetype across Restaurant, Bomb Chamber (2 of 5 sections) |
| UV mapping | Single UV unwrap (UV0) |
| Status | **Needed** |

### Visual Description

The interior-duty counterpart to ASSET-003. Same chunky industrial-mass body proportion, same uniform shape, but the helmet apertures change to expose the lower face. The open-face helmet retains the dome silhouette at the top of the head but trades the flat visor for an open-front aperture with a chin strap visible. The face below is partially exposed: nose, mouth, and lower jaw are visible; eyes are still shaded by the helmet brow but readable as squinting attentive expression. The trim ring is **narrower** than the bowl-helmet variant and rendered in a desaturated crimson rather than full PHANTOM Red — this signals "interior / less field-ready / slightly more formal" per §5.2 trim-width-as-threat-tier rule. All other costume elements (chest harness, belt, holstered sidearm, trousers, boots, gloves) match ASSET-003.

### Art Bible Anchors

- **§5.2 PHANTOM Grunt — Helmet variant**: "standard bowl with flat visor vs open-face with chin strap (patrolling exterior vs interior duty). The dome silhouette is always preserved; only the face aperture changes."
- **§5.2 PHANTOM Grunt — Trim color variant**: "Interior guards (Restaurant, Bomb Chamber) carry a narrower trim in a desaturated crimson — slightly more formal, slightly less field-ready. One trim width = one threat tier, readable at distance."
- **§8B Variant Rule**: helmet aperture change = mesh split. Trim color = material swap (in this case the texture pass).
- All other anchors as ASSET-003.

### Color Palette

Same as ASSET-003 except:
- **Helmet trim ring**: narrower, desaturated crimson `#9A2030` (vs `#C8102E` PHANTOM Red of ASSET-003)
- **Face skin** (lower visible portion): warm parchment-toned `#D4B896`

### Generation Prompt

Same template as ASSET-003 with these specific replacements:

```
Replace the helmet description with:

- OPEN-FACE HELMET in matte near-black: dome shape covering the top of the
  head with an OPEN front aperture (no flat visor). The lower face — nose,
  mouth, jawline — is visible below the helmet brow. A black leather chin
  strap runs from the helmet edge under the chin. A NARROWER ring trim in
  desaturated crimson (#9A2030, NOT bright PHANTOM Red) runs around the
  helmet's lower circumference — narrower and less saturated than the
  exterior-patrol variant.
- FACE: visible nose, mouth, jaw. Squinting attentive expression. Eyes
  shaded under the helmet brow. NO smile, NO snarl. Stylized realistic
  proportions.

Add to NEGATIVE PROMPT:
- NO bowl helmet with closed visor — this variant has an OPEN-FACE
  helmet with the lower face exposed.
- NO bright PHANTOM Red trim — the ring is desaturated darker crimson.
- NO eye contact with viewer — eyes are shaded and squinting.
```

### Generation Strategy

Same Path 4 workflow as ASSET-003. Tip: feed the approved ASSET-003 image as a style anchor to image-to-3D services that support multi-image input (Tripo3D supports this) — guarantees costume continuity across the two grunt variants.

---

## ASSET-005 — PHANTOM Elite — Bomb Chamber Boss

| Field | Value |
|---|---|
| Asset ID | ASSET-005 |
| Category | Character — full-body humanoid, base mesh, named encounter |
| Tier | T2 (base mesh; rig deferred) |
| File path (target) | `assets/models/stealth-ai/char_phantom_elite_peaked_cap.glb` |
| Material name | `mat_phantom_elite_peaked_cap` |
| Naming convention | `char_phantom_elite_peaked_cap.glb` (per §8B) |
| Triangle budget LOD0 | **3,500** (art bible §8D — PHANTOM elite/named enemy per variant) |
| LOD count | 1 in Sprint 09 |
| Texture resolution | 1024 × 1024 body |
| Material slots | 2 max (body/costume + face — face is visible on this archetype) |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO in Sprint 09 |
| Outline tier | **MEDIUM** (per §3.4 — all PHANTOM guards including elites are tier 2; only Eve and hero objects are tier 1 HEAVIEST) |
| Outline implementation | ADR-0001 stencil tier 2 |
| Use case | Bomb Chamber section climax encounter (1 of 5 sections — final boss) |
| UV mapping | Single UV unwrap (UV0). Cape-back panel is contiguous geometry, NOT separate. |
| Status | **Needed** |

### Visual Description

A taller, narrower, more vertical figure than the chunky grunts — height differential is achieved through proportion, NOT literal scale (head is normal-sized; torso and legs are elongated). The peaked PHANTOM officer cap replaces the bowl helmet entirely: a stiff military-style officer cap with a high crown, a hard horizontal visor, and a single PHANTOM Red band ring trim where the cap meets the brow. The officer's face is fully visible below the cap visor — a stern, weather-worn, mid-50s European male, deadpan composure (NOT comically villainous). A floor-length operational coat with exaggerated lapels falls from the shoulders to mid-shin: the lapels are wide and angular (NOT softly folded), the coat is buttoned only at the chest, and from the back of the shoulders to the floor a single CAPE-BACK panel hangs as one continuous flat geometric shape — at distance this cape reads as a single rectangle of negative space behind the officer, signaling "this one is named." The cape is bake-into-mesh contiguous geometry, NOT a separate cloth-sim element. Trousers are dark, tapered, and tucked into mid-shin officer's boots with a higher heel than grunt boots. Gloved hands. Standing A-pose, weight-neutral, arms slightly away from body but with a more deliberate composure than grunts — this character is the commander, not a foot soldier.

### Art Bible Anchors

- **§5.2 PHANTOM Elite / named enemies**: "Elite status is read through three things: height (elites stand a half-head taller than grunts, achieved through proportion, not literal scale), the peaked PHANTOM officer cap replacing the bowl helmet, and one personal silhouette accessory — a floor-length operational coat with exaggerated lapels. For the Bomb Chamber arrival boss, the coat has a cape-back panel that reads as a single flat geometric shape at distance: unmistakably 'this one is named.' No monocle at gameplay scale; reserved for cutscene portrait use."
- **§3.1 Character Silhouette Philosophy**: "Elite status read through verticality contrast against the squat grunt mass."
- **§5.4 LOD Sentence**: "PHANTOM elite: preserve height differential and coat silhouette at distance; lapel and cap peak detail drops to mid-distance."
- **§8D Polycount**: 3,500 tris LOD0 (NOT 2,800 — elites get +700 for the coat geometry).
- **§8H LOD Distance**: 20m → 40m → 60m (slightly longer than grunts because boss visibility is load-bearing).
- **GDD §Visual**: ~3k tris in GDD (art bible §8D 3,500 is authoritative; reconciliation deferred).

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Officer cap shell | `#1A1A1A` (near-black) | Derived |
| Cap visor | `#0A0A0A` | Derived |
| Cap band ring trim | `#C8102E` (PHANTOM Red) | Art bible §4.1 |
| Operational coat body | `#1A1A1A` | Derived |
| Coat lapels (slightly lighter for definition) | `#2A2A2A` | Derived |
| Cape-back panel | `#1A1A1A` (matches coat — single flat geometric shape) | Derived |
| Trousers | `#1A1A1A` | Derived |
| Boots | `#0F0F0F` | Derived |
| Gloves | `#1A1A1A` | Derived |
| Face skin | warm parchment-toned `#D4B896` | Derived |
| Hair (visible under cap) | near-black `#0F1115` (graying optional, art-director discretion) | Derived |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D character reference, full body, front-facing A-pose with arms
slightly away from body, neutral standing position. Plain flat white
background, isolated subject, full figure from head to feet visible.

CHARACTER: 1965 PHANTOM organization elite officer / boss, male,
mid-50s, weather-worn European face, stern deadpan composure (NOT
cackling villain — this is a quietly menacing operational commander).
TALL and NARROW build (proportionally elongated torso and legs — head
is normal-sized).

WARDROBE:
- PEAKED PHANTOM OFFICER CAP in matte near-black: high stiff crown, hard
  horizontal visor at brow, a single PHANTOM RED (#C8102E) band ring
  trim where the cap meets the brow. Stiff military officer-style, NOT
  Soviet ushanka, NOT Western peaked cap. Period-correct 1960s East-Bloc
  officer dressing theatricalized.
- FLOOR-LENGTH OPERATIONAL COAT in matte near-black: hem reaches mid-shin,
  buttoned only at the chest. Lapels are WIDE and ANGULAR (hard geometric
  edges, NOT softly folded), exaggerated in proportion.
- CAPE-BACK PANEL: from the back of the shoulders down to the floor, a
  single continuous panel of fabric falls as ONE FLAT GEOMETRIC SHAPE.
  This is NOT a separate flowing cape — it's a structural panel of the
  coat that reads as a single rectangle of negative space behind the
  officer when viewed from the side or back. It is bake-into-mesh
  contiguous geometry, not cloth simulation.
- BLACK TROUSERS, tapered, tucked into officer's boots.
- OFFICER'S BOOTS in deep black with a slightly higher heel than infantry
  boots, mid-shin height.
- BLACK GLOVES.

FACE:
- Fully visible below the cap visor.
- Stern deadpan, mid-50s.
- NO monocle at this gameplay scale (monocle is for cutscene portrait
  only — exclude here).
- Subtle weather wrinkles, hard jawline.
- Eyes alert but not exaggerated.

VISUAL STYLE:
- Stylized low-poly 3D character rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors, NO PBR materials, NO
  photorealism.
- Strong dark outline around the silhouette (comic-book outline ~3px,
  medium weight).
- Hard edges, no gradient noise.
- Aesthetic inspired by: No One Lives Forever (2000) PHANTOM elite art;
  1960s Cold War villain dressing; classical theatrical operatic villain
  silhouette (long coat + peaked cap is the genre signal).

POSE & FRAMING:
- Standard A-pose for rigging reference.
- Standing weight-neutral, both feet planted parallel.
- Arms slightly out from body, palms facing thighs.
- Camera at eye level, front-facing.
- Full figure head to feet.

NEGATIVE / DO NOT INCLUDE:
- NO bowl helmet (this is the peaked-cap elite, not a grunt).
- NO chunky military-padded shoulder mass — this character is TALL and
  NARROW, not chunky.
- NO modern military insignia, NO real-world unit patches, NO Soviet
  red-star.
- NO flowing cape billowing in wind — the cape-back panel is structural,
  static, hard-edged.
- NO monocle at this gameplay scale.
- NO snarl, NO maniacal grin, NO comic-villain face — deadpan stern only.
- NO weapon in hand — officer is unarmed at standing rest pose.
- NO fur trim, NO ornate medals, NO ribbons, NO sash.
- NO photorealistic skin, NO realistic hair strands.
- NO modern coat silhouette (trench coat with belt, etc.) — this is a
  buttoned operational coat with hard angular lapels.
- NO Kate Archer or NOLF1 villain copy — original character.
```

### Generation Strategy

Same Path 4. Particularly important for this asset: the cape-back panel must read as a single rectangle from the side/back angles. After image generation, request the user generate a second image (back view) to verify cape geometry before image-to-3D conversion — multi-view input increases image-to-3D fidelity.

---

## ASSET-006 — Walkie-talkie Radio (Chest-Clipped Accessory)

| Field | Value |
|---|---|
| Asset ID | ASSET-006 |
| Category | Prop — accessory, static, no rig |
| Tier | T1 (final `.glb`, no rig deferral) |
| File path (target) | `assets/models/stealth-ai/prop_walkie_talkie_phantom.glb` |
| Material name | `mat_prop_walkie_talkie_phantom` |
| Naming convention | `prop_walkie_talkie_phantom.glb` (per §8B `[archetype]_[name]_[variant]` — `prop_` prefix) |
| Triangle budget LOD0 | **400** (art bible §8D — generic environment prop range 300–600; walkie-talkie sits in middle) |
| LOD count | 1 in Sprint 09 (auto-LOD acceptable for env props per §8H but Sprint 09 ships LOD0 only) |
| Texture resolution | 512 × 512 (smaller than character — small accessory prop) |
| Material slots | 1 (single flat unlit material) |
| File format | glTF 2.0 binary (`.glb`); Y-up, Z-forward; sRGB albedo |
| Rig | NO — static prop |
| Outline tier | **MEDIUM** (part of PHANTOM guard ensemble per §3.4 — same tier as the guard it's clipped to) |
| Outline implementation | ADR-0001 stencil tier 2 |
| Use case | Attached to PHANTOM Grunt's chest harness via socket / constraint at scene-load (Sprint 10+) — signals "radio-carrier variant" for takedown priority per §5.2 |
| Attach socket | Conceptual: `RadioClipAnchor` on grunt's chest harness (wiring is Sprint 10+) |
| Origin convention | Bottom-back face flush against attach surface (snug fit when constrained) |
| UV mapping | Single UV unwrap. Hard pattern edges on dial face must survive 512² resolution. |
| Status | **Needed** |

### Visual Description

A small period-correct walkie-talkie unit in matte black Bakelite-finish styling. Imagine a 1965 police-band handie-talkie or East-German military field radio: a rectangular brick body roughly 15 cm tall × 7 cm wide × 4 cm deep at scale, with a vertical telescoping antenna rising from the top corner adding another 12 cm of height (extended position — collapsed antenna would be ~3 cm). The front face has a single circular dial in the upper portion (channel selector or volume), a small rectangular speaker grille below the dial, and a vertical push-to-talk lever on the side. The dial is a chrome-trim ring around a black centre. The speaker grille is a horizontal bar pattern. A small chrome clip on the back face attaches to a chest harness loop. No display screen (period authenticity — analog radios only). Reads at silhouette as a chunky vertical brick with a thin antenna line — a clear silhouette tell against the guard's body shape, signalling "this guard has a radio = takedown priority" per §5.2 tertiary read rule.

### Art Bible Anchors

- **§5.2 PHANTOM Grunt — Accessory variant**: "radio-carrier guard has a period walkie-talkie clipped to the chest harness, antenna visible. Takedown priority signaling without a UI marker."
- **§3.4 Hero Shapes**: PHANTOM accessories share guard outline tier MEDIUM.
- **§4.1 Primary Palette**: matte near-black body matches uniform; chrome trim provides minor specular contrast (faked via flat lighter-grey color, NOT actual specularity per §8A no PBR).
- **§8D Polycount**: 300–600 tris (generic env prop range); walkie-talkie at ~400 tris (rectangular brick + antenna cylinder + dial torus + grille bars).
- **§6.2 Texture Philosophy**: hand-painted flat color + hand-painted geometric pattern. No procedural noise.
- **§5.4 LOD Sentence (grunt accessories)**: "face aperture and chest accessories drop first" — meaning at distance, the walkie-talkie can be culled before helmet detail.

### Color Palette

| Surface | Hex | Source |
|---|---|---|
| Body shell (Bakelite matte black) | `#1A1A1A` | Derived |
| Dial trim chrome (faked, flat) | `#9A9A9A` | Derived |
| Dial centre | `#0A0A0A` | Derived |
| Speaker grille bars | `#3A3A3A` | Derived |
| Antenna | `#2A2A2A` | Derived |
| Push-to-talk lever | `#C8102E` (PHANTOM Red — small accent confirming faction) | Art bible §4.1 |
| Chrome back clip | `#9A9A9A` | Derived |
| Outline color | `#1A1A1A` | Art bible §8C |

### Generation Prompt

```
Stylized 3D prop reference, isolated object, plain flat white background,
no shadows on ground, three-quarter front view, full prop visible head
to base.

PROP: 1965 East-Bloc military / Soviet-era police-band walkie-talkie
handheld radio. Period-authentic analog field radio, NO modern digital
display. Imagine a 1965 PHANTOM operative's field radio in a Cold War
spy fiction setting.

GEOMETRY:
- Rectangular brick body roughly 15 cm tall × 7 cm wide × 4 cm deep,
  matte BLACK BAKELITE finish (slight texture but flat shading).
- Vertical telescoping antenna rising from the top-right corner of the
  body, extended position (about 12 cm above the body), thin metallic
  rod, slight taper.
- Single circular dial in the upper-front of the body — chrome trim ring
  around a black centre. About 3 cm diameter.
- Small rectangular speaker grille below the dial, horizontal bar pattern,
  about 5 cm wide × 2 cm tall.
- Vertical push-to-talk lever on the LEFT side of the body — small red
  rectangle, about 2 cm × 1 cm.
- Small chrome clip on the BACK face for attaching to a harness — visible
  in 3/4 view as a thin chrome strip.
- NO display screen, NO LED indicator, NO modern buttons.

VISUAL STYLE:
- Stylized low-poly 3D rendering, comic-book aesthetic.
- FLAT UNLIT shading, saturated solid colors, NO PBR materials, NO
  photorealism.
- Strong dark outline around the prop silhouette (comic-book outline
  ~2-3px, medium weight).
- Hard edges, no gradient noise.
- Aesthetic inspired by: 1960s Cold War spy fiction props; period East-Bloc
  field radios; NOLF1 (2000) gadget art.

FRAMING:
- Three-quarter front view at slight angle.
- Plain white background.
- Camera framing tight on the prop, full prop visible from antenna tip
  to base.

NEGATIVE / DO NOT INCLUDE:
- NO modern digital display, NO LED screen, NO smartphone-like interface.
- NO modern police/military radio (Motorola, etc.) — this is period-
  authentic 1965.
- NO photorealistic Bakelite — flat painted color only.
- NO realistic chrome with reflections — flat lighter-grey for chrome
  faked via color contrast only.
- NO NATO unit insignia, NO real-world brand markings.
- NO retracted antenna — antenna is in extended position.
- NO embellishments, NO decals, NO patterns on the body shell beyond the
  speaker grille bars and dial.
```

### Generation Strategy

Same Path 4 as character assets. Because this is a small static prop, the image-to-3D conversion is typically more reliable than humanoids — expect first-pass success. Cleanup is simpler: no rig prep, no humanoid rotation issues, no axis correction concerns beyond standard glTF Y-up convention. Final scale: ~15 cm tall body + ~12 cm antenna = ~0.27 m total height; the prop is small in absolute terms.

---

## Cross-Asset Notes

### Outline pipeline implementation (per ADR-0001)

All 4 assets render through the SAME stencil-based outline pipeline (ADR-0001), distinct from Eve's FPS hands (which use ADR-0005 inverted-hull SubViewport):

- All PHANTOM characters + walkie-talkie = stencil tier 2 (MEDIUM, 2.5 px @ 1080p)
- At scene-load, MeshInstance3D for each grunt/elite/walkie sets stencil ref to tier 2
- Stencil ref assignment is Sprint 10+ scene integration — NOT in this sprint's scope

### Variant encoding (per §8B)

The full PHANTOM variant matrix from §5.2 is encoded as:

| Variant Axis | Encoding | This sprint's scope |
|---|---|---|
| Helmet aperture (bowl vs open-face) | **Mesh split** (silhouette change) | ASSET-003 + ASSET-004 |
| Trim color (red vs crimson) | **Material swap** (color, not silhouette) | Material slots placeholder; full trim colors in texture pass |
| Accessory presence (radio-carrier) | **Attached prop via socket** | ASSET-006 |
| Elite vs grunt | **Mesh split** (proportions + cap + coat all change silhouette) | ASSET-005 |
| Civilian-disguise | **Out of scope** — depends on civilian models from §5.3 | DEFERRED |

This produces the full 6–10 enemy types mentioned in `design/gdd/game-concept.md` via:

- 2 grunt mesh meshes (ASSET-003, ASSET-004) × 2 trim colors = 4 grunt variants
- 1 grunt with radio (ASSET-003 or ASSET-004 + ASSET-006 attached)
- 1 elite (ASSET-005)
- (Future: civilian-disguise = 1 more variant, pending §5.3 civilian models)

= 6 base variants from 4 base meshes + 1 prop. Texture pass and accessory wiring expand this to the full 6–10 type count.

### Forward dependencies

- `design/gdd/stealth-ai.md` §Visual line 758 — "Animation state layer" — consumes rigged versions of ASSET-003/004/005 (Sprint 09b post-rig deliverable)
- `design/gdd/stealth-ai.md` §Visual line 759 — "Weapon draw animation" — requires weapon prop (separate spec, NOT in this context — likely future "PHANTOM weapons" context within `inventory-gadgets` or its own context)
- `design/gdd/stealth-ai.md` §Visual line 761 — "Dead-body visibility" — requires the dead_slump animation pose, which preserves silhouette geometry per §5.4 LOD
- ADR-0001 — stencil tier 2 assignment at scene-load (Sprint 10+)
- `design/gdd/stealth-ai.md` §Visual line 760 — "Eye / head turn IK" — depends on rigged head bone in Sprint 09b

### Generation order recommendation

Do these in order to minimize iteration cost:

1. **ASSET-003 (Grunt Bowl Helmet)** first — most-used variant, validates the PHANTOM grunt prompt template before reuse on ASSET-004
2. **ASSET-004 (Grunt Open-Face)** second — reuse approved ASSET-003 image as multi-image-input to image-to-3D for costume continuity
3. **ASSET-006 (Walkie-talkie)** third — small static prop, easy generation, unblocks radio-carrier variant for testing
4. **ASSET-005 (Elite Boss)** last — most complex (cape-back panel + tall narrow proportions), use ASSET-003/004 lessons to refine the prompt before generating
