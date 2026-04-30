# Visual Reference — Plaza NOLF 1 Calibration Scene

**Hypothesis being tested**: "What does NOLF 1 visual register actually feel like in our Godot 4.6 stack with the inverted-hull outline shader?"

**Status**: in-progress (created 2026-04-30 alongside the NOLF 1 alignment brief).

**Findings**: TBD — populated after user reviews the scene.

---

## How to Run

### Editor (recommended — visuals only render in the editor)
1. Open the project in Godot 4.6
2. Open `prototypes/visual_reference/plaza_visual_reference.tscn`
3. Press **F6** (Run Current Scene)
4. Mouse-orbit / WASD to look around (see in-script controls below)
5. Press **Esc** to exit

### Headless (compile-check only, no visuals)
```bash
godot --headless --quit-after 60 res://prototypes/visual_reference/plaza_visual_reference.tscn
```
Headless catches script parse / shader compile errors. Visual evaluation requires the editor.

### Controls (in-scene)
- **Mouse**: free look (camera tilt/pan)
- **WASD**: walk camera
- **Q/E**: down/up
- **Esc**: quit

---

## What This Scene Contains

A small enclosed "Plaza-flavoured" room (not the actual Plaza level) with:

| Element | Purpose | Outline Tier |
|---|---|---|
| **Eve hand** (capsule, foreground-right) | First-person hand silhouette test — how the inverted-hull outline reads on a HEAVIEST tier mesh in motion | Tier 0 (HEAVIEST, 5 px) |
| **PHANTOM guard placeholder** (capsule body + dome helmet + red trim ring) | Bowl-helmet silhouette readability test — does the dome carry the read at 5–10 m? | Tier 2 (MEDIUM, 3 px) |
| **Plaza document placeholder** (flat plane on a podium, BQA blue) | Document foreground-artifact test — does it pop against the warm wall? | Tier 1 (HEAVY, 4 px) |
| **Pedestal / podium** (boxes, period-grey) | Environment fixture test | Tier 3 (LIGHTEST, 2 px) |
| **Plaza walls + floor** | Two-temperature environment test (warm Parisian yellow walls vs. cool Eiffel grey floor) | Tier 3 |
| **Pendant lamp** (warm light, hanging) | Diegetic light source — warm pool of light per art-bible | n/a |
| **Cool ambient fill** | Cool secondary light per two-temperature philosophy | n/a |

All meshes are **placeholder primitives** (capsules, boxes, planes). This scene is for **art direction calibration**, not asset production. Final assets will be modeled / sculpted / textured per `/asset-spec` outputs.

---

## What to Look For (Tie to the Brief)

Open `production/notes/nolf1-style-alignment-brief.md` alongside the scene. Specifically check:

1. **Outline weight differentiation**: can you tell Eve (Tier 0) from the document (Tier 1) from the guard (Tier 2) from the wall (Tier 3) at a glance? If outlines blur together, the tier deltas are too small.
2. **Color contrast**: does the BQA-blue document pop against the Parisian-yellow wall? Does the PHANTOM-red trim ring read on the guard helmet?
3. **Two-temperature lighting**: does the warm pendant pool feel distinct from the cool ambient fill? Or is the room too uniformly lit to read NOLF1's "Morocco interiors" reference?
4. **Silhouette grammar**: does the guard's bowl-helmet dome read as a circle from across the room? Or does the helmet shape get lost?
5. **NOLF1 cartoony ↔ grounded axis (Brief gap G3)**: how does this stylization feel to you? Too cartoony? Too grounded? Just right?
6. **Comic-book-ness of the outline**: does the inverted-hull outline have the right weight to feel "comic book / NOLF cartoon" rather than "edge-detect fashion"?

---

## What This Scene Does NOT Contain (deliberate)

- Eve's full body or face (only one floating hand)
- Period-accurate prop vocabulary (no café tables, vendor stalls, period signage — that's `/asset-spec` work)
- Actual Plaza geometry (this is an isolated test box, not a level)
- AI behaviour (the guard is static — alert-state visual signaling is in HUD State Signaling, not here)
- Music or audio (`/asset-spec` audio brief is a separate conversation)
- Final textures (everything is solid colour or simple gradient)
- The full post-process chain (Outline Pipeline only — sepia-dim, glow, tone-mapping not applied; that's the Post-Process Stack epic)

---

## Findings (populated after review)

- *(awaiting reviewer feedback)*

---

## Cleanup

When this scene's findings have been folded into `/asset-spec` outputs, archive this prototype per `.claude/rules/prototype-code.md`. Do NOT promote any of this code to production — production assets are rebuilt from spec.
