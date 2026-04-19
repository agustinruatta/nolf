# Game Concept: The Paris Affair

*Working title — series concept: "Eve Sterling" / BQA Files*
*Created: 2026-04-19*
*Status: Draft*

---

## Elevator Pitch

> It's a single-player stealth-FPS spiritual successor to *No One Lives Forever* (2000) where you play 1960s British secret agent Eve Sterling infiltrating the Eiffel Tower to disarm a bioweapon planted by the criminal organization PHANTOM, with the comedic tone, deadpan dialogue, document-driven worldbuilding, and graduated-suspicion stealth that defined the era's spy-comedy genre.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Single-player stealth FPS / spy-comedy |
| **Platform** | PC (Linux + Windows, Steam) |
| **Target Audience** | See Player Profile section |
| **Player Count** | Single-player |
| **Session Length** | 30–90 min sessions, 2–4 hr full mission |
| **Monetization** | Premium one-time purchase, no microtransactions |
| **Estimated Scope** | Medium (6–9 months MVP, solo) |
| **Comparable Titles** | *No One Lives Forever 1* (2000), *Gloomwood*, *Thief: The Dark Project*, *Deus Ex* (stealth/lore aspects) |

---

## Core Fantasy

You are Eve Sterling, a sharp-witted British secret agent in 1965, ascending the Eiffel Tower one floor at a time to stop a megalomaniacal plot. Every shadow you slip through, every chloroformed guard, every absurd document you pocket reinforces the fantasy of being **the most competent, most stylish, most quietly dangerous person in the room**. You are not a soldier; you are a craftsperson of espionage. You don't quip — the world quips around you, and you let it.

---

## Unique Hook

It's like *No One Lives Forever*, **and also** the entire campaign happens vertically inside a single iconic real-world landmark — the Eiffel Tower itself becomes the dungeon, with each ascent unlocking a new floor of comedic scenarios and stealth puzzles tailored to its real architecture (scaffolds, restaurant level, observation deck, antenna structure).

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Narrative** | 1 | Mission arc, dialogue, document trail, radio chatter |
| **Discovery** | 2 | Hidden documents, alt routes, environmental gags, lore |
| **Fantasy** | 3 | 1960s spy aesthetic, gadgets, period costumes |
| **Challenge** | 4 | Graduated stealth, escalating section difficulty |
| **Sensation** | 5 | Saturated Pop visuals, period jazz/lounge score |
| **Expression** | 6 | Multiple stealth solutions per encounter |
| **Submission** | N/A | Not a relaxation game |
| **Fellowship** | N/A | Single-player only |

### Key Dynamics (Emergent player behaviors)
- Players observe patrol patterns and improvise quiet solutions
- Players read documents aloud (in their head) and get the joke
- Players discover that "alarmed" isn't game-over but the start of a new comedy
- Players replay sections to find missed documents and overheard dialogue

### Core Mechanics (Systems we build)
1. **Graduated-suspicion stealth AI** (unaware → suspicious → searching → combat, all reversible)
2. **Document collection system** (15–25 readable in-world documents that drive lore + comedy)
3. **Gadget inventory + light combat** (3–5 gadgets, 3–5 weapons, ammo-scarce to discourage Rambo)

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Most encounters have 2–3 valid stealth solutions; no objective markers force a path | Core |
| **Competence** | Skill grows as the player learns AI patterns and level geometry — no XP system inflates the feeling | Supporting |
| **Relatedness** | Connection is to the *world* (PHANTOM, BQA, the comedy) and to Eve as a competent character | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** — Hidden documents, alt routes, environmental storytelling reward poking every corner
- [x] **Storytellers / Narrative seekers** — Strong narrative spine, period setting, comedic worldbuilding
- [x] **Achievers** (light) — Mission completion, optional document-collection achievement
- [ ] **Socializers** — N/A, single-player only
- [ ] **Killers / Competitors** — N/A; combat exists but is not the point

### Flow State Design

- **Onboarding curve**: First section (Plaza) is a guided micro-tutorial — one guard, one gadget, one document. Teaches stealth grammar without text prompts.
- **Difficulty scaling**: Each section adds one new variable (more guards, new gadget, new patrol type, new vertical traversal challenge).
- **Feedback clarity**: Guard alert state shown via subtle audio cues + body language, not UI HUD bars (period authenticity).
- **Recovery from failure**: Detection escalates dynamically; player can hide and de-escalate. Death is rare and respawn is sectional, not full-mission.

---

## Core Loop

### Moment-to-Moment (30 seconds)
**Observe** a guard's patrol → **Move** through cover/shadow → **Act** (slip past, takedown, gadget bypass) → **Listen** to incidental dialogue → **Repeat**.

### Short-Term (5–15 minutes)
Enter a section → assess room → execute a stealth solution → loot documents and gear → unlock the next section. "One more room" psychology fueled by per-section gadget twists.

### Session-Level (30–90 minutes)
A typical session covers 1–2 Eiffel Tower sections. Natural save points between sections. Hook between sessions: a cliffhanger document or radio chatter teasing the next floor.

### Long-Term Progression
The player grows in **knowledge** (story, world, PHANTOM's plans), **toolkit** (new gadgets per section), and **mastery** (player skill — not character XP). No skill trees; NOLF1 didn't have them. Game is "done" when the bomb is disarmed (~2–4 hours).

### Retention Hooks
- **Curiosity**: Missed documents, alt routes, overheard dialogue
- **Investment**: Comedic world the player wants to spend more time in
- **Social**: N/A
- **Mastery**: Higher-difficulty mode, no-takedown speedrun routes

---

## Game Pillars

### Pillar 1: Comedy Without Punchlines
Humor lives in characters, signage, documents, and overheard guard banter — not in the protagonist quipping at the camera.

*Design test*: when adding dialogue, prefer absurd guard banter or dry documents over Eve cracking wise.

### Pillar 2: Discovery Rewards Patience
Every room hides a document, a line, or a hidden route; observation pays more than speed.

*Design test*: the patient observer's path must always be more rewarding than the speedrunner's.

### Pillar 3: Stealth is Theatre, Not Punishment
Getting spotted opens new dramatic possibilities (chase, escape, comedy), never an instant fail.

*Design test*: if a system makes detection feel like "load a save," redesign it.

### Pillar 4: Iconic Locations as Co-Stars
Geography drives encounter design; an encounter that could happen anywhere is wrong for this game.

*Design test*: every major encounter must require this specific location's geometry to work.

### Pillar 5: Period Authenticity Over Modernization
1960s spy fantasy is non-negotiable; no modern UX conveniences (objective markers, kill cams, ping systems) break the period feel.

*Design test*: if a modern convention makes the game easier but breaks the period fantasy, cut it.

### Anti-Pillars (What This Game Is NOT)

- **NOT XP / skill trees / persistent upgrades** — would compromise *Discovery Rewards Patience* by gamifying intrinsic reward.
- **NOT multiplayer / co-op / live-service** — incompatible with single-player premium model and 3–9 month MVP.
- **NOT a quip-heavy protagonist** (post-2010 AAA snark) — would compromise *Comedy Without Punchlines*.
- **NOT procedurally generated levels** — would compromise *Iconic Locations as Co-Stars*.
- **NOT modern UX conveniences** (objective markers, minimap, AI companion chatter) — would compromise *Period Authenticity*.

---

## Visual Identity Anchor

**Direction: Saturated Pop**

*One-line rule: "If a panel from a 1966 spy comic could slot in, you're on direction."*

**Supporting principles:**

- **Bold flat colors over PBR realism** — *Design test:* if a material needs PBR roughness to read correctly, redesign the color story.
- **Comic-book outline as signature** — a single full-screen outline post-process shader is the project's visual fingerprint. *Design test:* outlines must read clearly at 1080p; if a model is too dense for clean outlines, simplify it.
- **Op-art and geometric pattern library** — interiors use 1960s mod patterns (chevrons, bold stripes, atomic motifs) as the dominant texturing strategy. *Design test:* if a surface looks "neutral," replace it with a period pattern.

**Color philosophy:** Saturated primaries and complementary contrasts (PHANTOM red against BQA blue; warm Parisian yellow against cool Eiffel grey). No muddy mid-tones. Lighting is diegetic and theatrical — driven by in-world sources (pendant lamps, sunlight through ironwork, period spotlights). Alert state changes (unaware → suspicious → searching → combat) are signaled through **music and audio**, NOT through lighting or color shifts (faithful to NOLF1's dynamic music system).

This anchor is the seed for the full art bible (run `/art-bible` next).

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| *No One Lives Forever* (2000) | Tone, comedy, document collectibles, period setting, gadget design | Single iconic location vertical instead of globe-trotting; tighter scope | Validates the entire design space |
| *Gloomwood* | Stylized indie immersive-sim, premium short-form scope | Comedic instead of horror; period spy instead of Victorian | Proves the indie market for stylized stealth |
| *Thief: The Dark Project* | Light/sound stealth grammar, environmental storytelling | More forgiving detection; comedic tone | Verticality and architecture can drive stealth design |
| *Hitman* (Blood Money) | Encounter density, comedic NPC chatter | No disguises; linear instead of sandbox | Validates absurd guard banter as comedy vector |

**Non-game inspirations**: *Get Smart* (1965 TV), *Our Man Flint* (1966 film), Saul Bass title sequences, *The Avengers* (1960s ITV series), Dean Martin's *Matt Helm* films, vintage Air France travel posters.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 28–55 |
| **Gaming experience** | Mid-core to hardcore PC gamers |
| **Time availability** | 30–90 min weekday sessions, longer weekend sessions |
| **Platform preference** | PC (Steam, Linux/Windows) |
| **Current games they play** | *Gloomwood*, *Cruelty Squad*, *Peripeteia*, returning to *Thief* / *Deus Ex* |
| **What they're looking for** | A short, complete, premium single-player stealth experience with personality — not a 100-hour live-service grind |
| **What would turn them away** | Quest markers, modern UX paternalism, microtransactions, multiplayer pivots, snarky protagonist |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 — open-source, native Linux dev, free, lean for a solo first-time dev. C# or GDScript. |
| **Key Technical Challenges** | Graduated stealth AI (perception, alert state machine), comic-book outline shader, vertical level streaming, save system |
| **Art Style** | 3D stylized (low-poly + flat unlit + outline shader) |
| **Art Pipeline Complexity** | Low–Medium (Blender low-poly + hand-painted textures + single signature shader) |
| **Audio Needs** | Moderate — period jazz/lounge score, 30–50 VO lines, ambient SFX |
| **Networking** | None (single-player only) |
| **Content Volume** | 1 mission, 5 sections, 6–10 enemy types, 3–5 gadgets, 3–5 weapons, 15–25 documents, 2–4 hours playtime |
| **Procedural Systems** | None (anti-pillar) |

---

## Risks and Open Questions

### Design Risks
- Comedy writing quality is binary — bad comedy is worse than none. *Mitigation:* hire/collaborate with a writer; iterate via playtest.
- Stealth-only encounters may feel repetitive across 5 sections. *Mitigation:* per-section gadget twists and architectural variety.

### Technical Risks
- Graduated suspicion AI is the longest pole. *Mitigation:* prototype Tier 0 first (one section, one enemy) before committing to full mission.
- Vertical level streaming + outdoor visibility on the Eiffel Tower is non-trivial in Godot. *Mitigation:* sectionalize aggressively; use occlusion volumes.
- First-time Godot/FPS dev learning curve. *Mitigation:* follow the engine reference docs; use existing addons where ethical.

### Market Risks
- Two-mission premium scope is unusual; players may expect more for the price. *Mitigation:* price accordingly ($9.99–$14.99) and lean into "premium short experience" framing à la *Inscryption Act 1*, *Iron Lung*.
- Indie stealth audience is small. *Mitigation:* NOLF nostalgia is a marketing asset; lean into press/community outreach.

### Scope Risks
- 6–9 month MVP for a first-time dev with stealth AI on the critical path is aggressive. *Mitigation:* Tier 0 vertical slice first to validate before committing.
- Audio production (VO) underestimated. *Mitigation:* AI VO for prototyping, commission small VO cast for final.

### Open Questions
- Will graduated-suspicion AI feel as good in Godot 4.6 as it did in Lithtech (NOLF1's engine)? *Resolved by:* Tier 0 prototype.
- Will a single iconic location sustain 2–4 hours of variety without exterior scenes? *Resolved by:* Tier 0 + first section's playtest.
- What's the right pricing tier for a 2–4 hour premium indie stealth game? *Resolved by:* market research closer to launch.

---

## MVP Definition

**Core hypothesis**: Players find graduated-suspicion stealth in a vertical iconic landmark (Eiffel Tower), wrapped in NOLF-style comedic dialogue and document collectibles, engaging for a complete 2–4 hour single-mission session.

**Required for MVP**:
1. Full Eiffel Tower mission, 5 sections, complete bomb-disarm narrative
2. Graduated-suspicion stealth AI (unaware → suspicious → searching → combat)
3. Document collection system, 15–25 in-world readable docs
4. 3–5 gadgets, 3–5 weapons, 6–10 enemy types
5. Saturated Pop visual style with comic-book outline shader
6. Period-appropriate audio: 1–2 music tracks per section, 30–50 VO lines, ambient SFX

**Explicitly NOT in MVP** (defer to later):
- Rome / Vatican mission (Tier 2, post-launch)
- Disguise system (Hitman-style)
- Skill trees / XP / persistent character upgrades
- Multiplayer of any kind
- Procedural generation
- Modern UX conveniences (objective markers, minimap)

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **Tier 0 — Vertical Slice** | 1 section (Plaza) | 1 enemy type, 1 gadget, 1 weapon, graduated AI, no documents | 1–2 months |
| **Tier 1 — MVP / Ship** | Full Eiffel Tower mission (5 sections) | All MVP features above | 6–9 months total |
| **Tier 2 — Stretch / Post-launch** | Rome + Vatican mission | Same systems, new content | +6–12 months |
| **Tier 3 — Full Vision** | Both missions + bonus content | Disguise system, additional gadgets, harder difficulty | +12–24 months |

---

## Setting & Cast (Quick Reference)

| Element | Detail |
| ---- | ---- |
| **Year** | 1965 |
| **Protagonist** | Eve Sterling, BQA field agent |
| **Player's agency** | Bureau of Quiet Affairs (BQA) — British civil-service-tone counterintelligence outfit |
| **Antagonist organization** | PHANTOM — global criminal syndicate with theatrical menace |
| **MVP setting** | Paris, France — Eiffel Tower (Plaza → Lower scaffolds → Restaurant level → Upper structure → Bomb chamber) |
| **MVP plot beat** | Disarm a PHANTOM bioweapon at the top of the Eiffel Tower before it contaminates Paris |
| **Tier 2 settings** | Rome (Colosseum, including underground chambers) and Vatican City (St. Peter's Basilica) |

---

## Next Steps

- [ ] Run `/setup-engine` to confirm Godot 4.6 setup and populate engine reference docs
- [ ] Run `/art-bible` to expand the Visual Identity Anchor into a full art bible
- [ ] Run `/design-review design/gdd/game-concept.md` to validate this concept
- [ ] Run `/map-systems` to decompose into individual systems (stealth AI, documents, gadgets, level streaming, dialogue, save)
- [ ] Author per-system GDDs with `/design-system`
- [ ] Plan technical architecture with `/create-architecture`
- [ ] Prototype Tier 0 (Plaza vertical slice) with `/prototype stealth-ai`
- [ ] Validate prototype with `/playtest-report`
- [ ] If validated, plan first sprint with `/sprint-plan new`
