# NOLF 1 Style Alignment Brief — Path A Quick Visual Brief

**Date**: 2026-04-30
**Purpose**: Synthesise what the existing design docs say about NOLF 1 alignment, surface gaps, and recommend asset-spec next steps.
**Reader**: project lead before `/asset-spec` step or `/sprint-plan`.

---

## 1. Already On File (NOLF 1 references in current docs)

NOLF 1 is **not a new direction** — it's already woven through the design docs. References live in:

### `design/gdd/game-concept.md`
- "Single-player stealth-FPS **spiritual successor to *No One Lives Forever* (2000)**"
- Comparable Titles: NOLF 1, Gloomwood, Thief, Deus Ex (stealth/lore)
- "It's like *No One Lives Forever*, **and also** the entire campaign happens vertically inside a single iconic real-world landmark — the Eiffel Tower"
- "The player grows in knowledge, toolkit, mastery — no skill trees; **NOLF1 didn't have them**"
- "Saturated primaries and complementary contrasts (PHANTOM red against BQA blue; warm Parisian yellow against cool Eiffel grey)"
- "Alert state changes signaled through **music and audio**, NOT through lighting or color shifts (faithful to NOLF1's dynamic music system)"
- "Will graduated-suspicion AI feel as good in Godot 4.6 as it did in Lithtech (NOLF1's engine)?" (resolved by Tier 0 prototype)
- "NOLF nostalgia is a marketing asset; lean into press/community outreach"

### `design/art/art-bible.md`
- Section 9 has a **dedicated NOLF 1 reference entry** with explicit "what to take" and "what to avoid":
  - **Take**: Morocco mission interiors (warm incandescent props vs. cool architecture — same two-temperature logic); guard patrol behaviour as performance not threat (legible arcs, not tactical sweeps); document prop design (foreground graphic artifacts with clear typographic hierarchy)
  - **Avoid**: NOLF1's early-2000s boxy geometry — it relied on costume colour contrast because polygon budget was tight. We have polygon budget for actual silhouette shape; "build the helmet dome silhouette first, don't rely on red trim to carry the read"
- Lighting is **diegetic** — pendants, ironwork-filtered sunlight, period spotlights. Does NOT shift with alert state (faithful to NOLF1; modern non-diegetic alert lighting is forbidden)
- "PHANTOM Grunt Guards — rounded industrial mass: **bowl helmet** with slight forward overhang, padded shoulders, short wide stance. The helmet dome is their identifier; reads as a circle at distance, PHANTOM red trim ring confirming faction. **NOLF1's character grammar**: readable exaggeration of period military surplus plus theatrical villain dressing"
- "**One outfit, the entire mission**" — Eve's single silhouette Plaza to Bomb Chamber. "**NOLF1's Cate Archer also held a strong constant silhouette per mission**; the same logic applies here"
- "**Stiff and deliberate** — theatrical composure, never naturalistic fidget. **NOLF1's mid-stylized theatrical posture** is the target"
- HUD: "**NOLF1-styled and period-appropriate**, not absent. Faithful to NOLF1, the player has continuous access to: health, current weapon and ammo count, active gadget, status. **What is forbidden is *modern* HUD vocabulary** — no objective markers, no minimap, no kill cams, no ping systems, no quest log overlays"
- HUD positioning: "screen-space, not world-attached. **Faithful to NOLF1: the player reads the screen edges**, not the environment, for status information"
- Typography: "**Futura Condensed Bold** — closest analogue to NOLF1's HUD register; humanist but geometric (1927 vintage, ubiquitous in 1965 design)"
- "Every environmental story beat must work as a visual gag or lore delivery on first encounter, **without text explanation and without the player needing to interact** — NOLF-grammar for comedy and lore beats"

### Pillar fit (from `design/gdd/game-concept.md`)
- **Pillar 1 — Comedy Without Punchlines**: NOLF tone (guard banter > protagonist quips)
- **Pillar 3 — Stealth is Theatre, Not Punishment**: NOLF stealth permission structure (detection opens drama, never instant-fail)
- **Pillar 5 — Period Authenticity Over Modernization**: NOLF anti-pillars (no objective markers, no minimap, no kill cams)

---

## 2. Where the Docs Are Strong — No Action Needed

These are well-defined and don't need re-litigation:

| Domain | Status |
|---|---|
| Eve's silhouette grammar (single outfit, theatrical pose, NOLF1 stiffness) | ✅ specified |
| PHANTOM guard silhouette (bowl helmet, padded shoulders, short wide stance, red trim) | ✅ specified |
| HUD register (NOLF1 corner widgets + Futura Condensed Bold + screen-edge anchoring) | ✅ specified |
| Lighting philosophy (diegetic only, music-driven alert state) | ✅ specified |
| Color system (saturated primaries, two-temperature contrast, PHANTOM red vs. BQA blue) | ✅ specified |
| Comedy delivery vector (visual gags + dry documents, no protagonist snark) | ✅ specified |
| Document prop register (foreground graphic artifact, period typographic hierarchy) | ✅ specified |
| Anti-list (no minimap, no objective markers, no kill cams, etc.) | ✅ specified |

---

## 3. Where the Docs Are Vague — NOLF 1 Alignment Gaps

These are where `/asset-spec` will need decisions before producing per-asset prompts:

### G1 — Eve's specific costume colorways
The art-bible specifies "structured jacket" and "single silhouette" but does NOT pin:
- Exact jacket colour (the docs mention warm Parisian yellow / cool Eiffel grey as environment palette, but Eve's costume colour is not stated against those)
- Whether Eve gets a Cate-Archer-style **mod-colour signature** (Cate's purple catsuit / orange hair was distinctive)
- Glove / shoe / accessory specifics

**Decision needed before Eve `/asset-spec`**: pick Eve's signature costume colour against the Plaza palette.

### G2 — Plaza environment density / set-dressing register
The art-bible says "controlled-density environments" (NOLF1 Morocco reference) but does NOT pin:
- How densely the Plaza is dressed (number of props per sqm)
- Specific period prop vocabulary for Plaza (vendor stalls? café tables? newspaper kiosks? Eiffel-base ironwork?)
- The "warm pendant pools, deep ironwork shadow" lighting beats — where specifically in Plaza they sit

**Decision needed before Plaza environment `/asset-spec`**: a 2-3 sentence "Plaza set-dressing brief" naming 5-8 specific period props that will appear.

### G3 — NOLF 1 cartoony-vs-grounded calibration
The art-bible says "**better polygon budget than NOLF1, build silhouette first**" but doesn't quantify:
- Where on the cartoony ↔ grounded axis we sit (NOLF1 was deliberately cartoony with Bond-spoof tone; *Gloomwood* is grounded; *Dishonored* is stylised but grim)
- Are PHANTOM guards **funny-looking** or just **distinctively-shaped**? (NOLF1 H.A.R.M. agents were funny-looking)
- Does Eve have any of NOLF1's deadpan-comedy facial register, or is she stoic period-Bond-girl?

**Decision needed before character `/asset-spec`**: where on the cartoony ↔ grounded axis Eve and PHANTOM guards sit. Recommend a one-line target ("PHANTOM = NOLF1 H.A.R.M. agents minus 20% silliness; Eve = NOLF1 Cate Archer plus 10% grounding").

### G4 — Document prop layout reference samples
The art-bible says "foreground graphic artifact with clear typographic hierarchy" but no document mockups exist. NOLF1's documents (memos, telexes, BQA files) have a very specific period-typography register that takes specific reference work to nail.

**Decision needed before document `/asset-spec`**: 2-3 mockup samples of what a Plaza tutorial document looks like (BQA letterhead style, telex style, or hand-typed memo style).

### G5 — Sound + music period calibration
Lighting is locked to diegetic; alert state is locked to music-driven. But the **period authenticity** of the music itself isn't specified beyond "no anachronistic synth pads or modern game-trailer cues" (audio.md). NOLF1's music was deliberately bombastic-spy-spoof — 1960s big-band horns, harpsichord stabs, Bond-pastiche themes.

**Decision needed before audio `/asset-spec`**: pick the music genre target (1960s big-band? library music? jazz combo?). Audio Director conversation, not visual.

---

## 4. Recommendation

**Light path** (where you are now): the docs are NOLF1-aligned. Run `/asset-spec` per asset and answer G1–G4 inline as each spec is authored. Each `/asset-spec` invocation reads the art-bible and the asset's GDD and produces a structured prompt; gaps surface naturally and you decide there.

**Heavier path** (only if Production gate-check questions Art Bible sign-off): run `/design-review design/art/art-bible.md` first — formal review pass that was skipped in lean mode. It will produce a written verdict against the project's design-doc standards, including a NOLF1-alignment cross-check. Locks AD-ART-BIBLE sign-off too. ~30-60 min process. Probably overkill for VS but worth doing before Production gate.

**The thing that DOES need to happen before VS asset production**: build at least one **runnable visual reference scene** (NOT specs, but actual placeholders in Godot with the outline shader running) so we can tune the art direction by reaction rather than by spec. Sprint 01 already produced `prototypes/verification-spike/fps_hands_demo.tscn` (signed off 2026-05-01); a Plaza-context extension is the next step. **A visual reference scene now exists at `prototypes/visual_reference/plaza_visual_reference.tscn` — see that file's README.**

---

## 5. Next Action

1. **Open `prototypes/visual_reference/plaza_visual_reference.tscn` in Godot, hit F6.** Look at it. Give feedback against G1–G4 above (and anything else that jumps out). This is the cheapest possible NOLF 1 calibration check.
2. Based on feedback, either: refine the visual reference scene, OR proceed to `/asset-spec` on individual assets with the calibrated answers locked in.
3. Then `/sprint-plan` for Sprint 02 (asset-spec stories integrated into the sprint backlog).

---

*This brief is a synthesis of existing docs as of 2026-04-30; it is not new design. If any reference above is contradicted by an updated `art-bible.md` or `game-concept.md`, the GDD is authoritative.*
