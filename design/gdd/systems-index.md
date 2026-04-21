# Systems Index: The Paris Affair

> **Status**: Revised — director feedback incorporated
> **Created**: 2026-04-19
> **Last Updated**: 2026-04-21 (Player Character + FootstepComponent APPROVED after `/design-review` revision pass + Stealth AI (System 10, MVP) designed — 606 lines, pending `/design-review` in fresh session; see `design/gdd/stealth-ai.md`)
> **Source Concept**: design/gdd/game-concept.md
> **Source Art Bible**: design/art/art-bible.md

> **Director gates (manually invoked, lean mode):**
> - **CD-SYSTEMS** (creative-director, 2026-04-19): CONCERNS — addressed in this revision (added Failure & Respawn; split HUD; promoted Civilian AI to MVP; added Pillar Coverage Matrix; added Deliberately Omitted section).
> - **TD-SYSTEMS-INDEX** (technical-director, 2026-04-19): CONCERNS — addressed in this revision (added Signal Bus; split Visual Effects into Outline Pipeline + Post-Process Stack; promoted Save/Load to L effort; added Save → Localization dep; added Required Architecture Decisions section).

---

## Overview

*The Paris Affair* is a single-player stealth-FPS spiritual successor to *No One Lives Forever* (2000). The mechanical scope is intentionally narrow: a graduated-suspicion stealth AI that is reversible (Pillar 3: *Stealth is Theatre, Not Punishment*), a NOLF1-style HUD with period typography, document collection as the main reward loop (Pillar 2: *Discovery Rewards Patience*), and dynamic music that signals AI alert state (no visual alert-state changes — strict NOLF1 fidelity).

The system set is **complete and minimal for ship**. The 23 systems below cover both the MVP vertical slice (Tier 0 — Plaza only) and the full Tier 1 ship build (Paris/Eiffel Tower mission, ~2–4 hours). **No new systems are needed for Tier 2 (Rome/Vatican)** — Tier 2 is content built on the same systems. No architectural debt deferred to post-launch.

Engine: Godot 4.6, GDScript primary. Platform: PC (Linux + Windows, Steam). Target: 60 fps · 16.6 ms frame budget · ≤1500 draw calls · ≤4 GB memory.

---

## Required Architecture Decisions (author BEFORE dependent GDDs)

These 4 ADRs are authored via `/architecture-decision`, not `/design-system`. They lock cross-cutting contracts that multiple system GDDs consume. **Author these first, in this order, before the dependent system GDDs they unblock.**

| # | ADR | Unblocks (system GDDs) | Effort |
|---|---|---|---|
| ADR-1 | **Stencil ID Contract** — every system that spawns outlined objects writes a stencil tier (Eve = heaviest, guards = medium, env = light). Ties to Outline Pipeline shader. | Player Character, Stealth AI, Combat, Inventory, Document Collection, Civilian AI | 1 session |
| ADR-2 | **Signal Bus + Event Taxonomy** — autoload signal hub + typed gameplay event taxonomy (alert-state-changed, document-collected, player-damaged, etc.). | Audio, Stealth AI, Mission Scripting (and all systems publishing/subscribing to events) | 1 session |
| ADR-3 | **Save Format Contract** — versioning, migration strategy, what each system serializes. | Save/Load, Inventory & Gadgets, Stealth AI (patrol state), Document Collection, Mission Scripting | 1 session |
| ADR-4 | **UI Framework** — Godot Theme resource, font registry (Futura/DIN/American Typewriter), input-context stack for HUD vs Document Overlay vs Menu routing. | HUD Core, Document Overlay UI, Menu System | 1 session |

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|---|---|---|---|---|---|
| 1 | **Signal Bus** *(new — TD recommendation)* | Core | MVP | Revised 2026-04-20 (B3 fix: 32→34 / 8→9 + Player domain row+column; re-review pending) | `design/gdd/signal-bus.md` | ADR-2 |
| 2 | Input | Core | MVP | Designed (pending review) | `design/gdd/input.md` | — |
| 3 | Audio | Audio | MVP | Revised 2026-04-20 (all 8 blockers resolved — Footstep Surface Map authored, Player + Persistence subscriptions added, Formula 4 locked to fixed 90 bpm, VO publisher role clarified; re-review pending) | `design/gdd/audio.md` | Signal Bus, ADR-2 |
| 4 | **Outline Pipeline** *(split from Visual Effects)* | Core | MVP | Revised 2026-04-20 (B1 fix: ADR-0005 hands exception carved out of Stencil-writing table + AC-5; ADR-0001 Related section updated; re-review pending) | `design/gdd/outline-pipeline.md` | ADR-1, ADR-5 |
| 5 | **Post-Process Stack** *(split from Visual Effects)* | Core | MVP | Designed (pending review) | `design/gdd/post-process-stack.md` | — |
| 6 | Save / Load *(L effort — TD escalation)* | Persistence | MVP | Revised 2026-04-20 (B6 spot-check complete — Audio subscription reciprocal wording aligned with Audio's new Persistence domain; re-review pending) | `design/gdd/save-load.md` | Localization Scaffold, ADR-3 |
| 7 | Localization Scaffold | Meta | MVP | Designed (pending review) | `design/gdd/localization-scaffold.md` | — |
| 8 | Player Character | Core | MVP | **Approved 2026-04-21** (Session F re-draft + `/design-review` revision pass: 957 lines; 21 blockers from 7-specialist adversarial review resolved inline. Session F closed GD-B3 / OQ-7 / OQ-8 / CapsuleShape3D; revision pass added F.8 `get_silhouette_height`, same-frame DEAD latch clear, 4-bucket audio scheme, `noise_global_multiplier` ship-lock, F.5 distance tie-break, ShapeCast3D spec, AC-determinism rewrites; ADR-0005 `material_override`→`material_overlay` corrected. Ready for downstream authoring.) | `design/gdd/player-character.md` · `design/gdd/player-character-v0.3-frozen.md` (frozen baseline, read-only) | Input, Outline Pipeline, Post-Process Stack, FootstepComponent, Stencil ID Contract (ADR-1) |
| 8b | **FootstepComponent** *(Session F sibling of Player Character)* | Core | MVP | **Approved 2026-04-21** (R-19 AI/Audio seam resolved — PC owns `get_noise_level`/`get_noise_event` AI channel; FC owns `player_footstep` Audio channel; 4-bucket stem scheme aligned with Audio GDD; explicit forbidden-pattern: Stealth AI MUST NOT subscribe to `player_footstep`. Approved as part of PC `/design-review` revision pass.) | `design/gdd/footstep-component.md` | Player Character, Signal Bus, Audio, ADR-2, ADR-6 |
| 9 | Level Streaming | Core | MVP | Not Started | — | Save/Load |
| 10 | Stealth AI | Gameplay | MVP | **Designed 2026-04-21** (606 lines; graduated-suspicion engine with 4-state lattice UNAWARE→SUSPICIOUS→SEARCHING→COMBAT, dual-channel perception, hand-rolled state machine + scoring, one-hop propagation, takedowns melee + silenced pistol. Consumes PC F.4/F.8 interface. Pending `/design-review` in fresh session.) | `design/gdd/stealth-ai.md` | Player Character, Audio, Signal Bus, ADR-1, ADR-2, ADR-3 |
| 11 | Combat & Damage | Gameplay | MVP | Not Started | — | Player Character, Stealth AI, Audio, ADR-1 |
| 12 | Inventory & Gadgets | Gameplay | MVP | Not Started | — | Player Character, Input, ADR-3 |
| 13 | Mission & Level Scripting | Gameplay | MVP | Not Started | — | Stealth AI, Combat, Level Streaming, Save/Load, Signal Bus, ADR-2, ADR-3 |
| 14 | **Failure & Respawn** *(new — CD recommendation)* | Gameplay | MVP | Not Started | — | Save/Load, Stealth AI, Mission Scripting |
| 15 | **Civilian AI** *(promoted to MVP — CD recommendation; phased: stub MVP / full VS)* | Gameplay | MVP | Not Started | — | Player Character, Audio, Signal Bus |
| 16 | **HUD Core** *(split from HUD — CD recommendation)* | UI | MVP | Not Started | — | Combat, Inventory, ADR-4 |
| 17 | Document Collection | Narrative | Vertical Slice | Not Started | — | Player Character, Save/Load, Localization, ADR-1 |
| 18 | Dialogue & Subtitles | Narrative | Vertical Slice | Not Started | — | Audio, Localization, Stealth AI, Signal Bus |
| 19 | **HUD State Signaling** *(split from HUD — VS scope)* | UI | Vertical Slice | Not Started | — | HUD Core, Stealth AI, Document Collection |
| 20 | Document Overlay UI | UI | Vertical Slice | Not Started | — | Document Collection, Post-Process Stack, Input, Localization, ADR-4 |
| 21 | Menu System | UI | Vertical Slice | Not Started | — | Save/Load, Input, Post-Process Stack, ADR-4 |
| 22 | Cutscenes & Mission Cards | Narrative | Vertical Slice | Not Started | — | Mission Scripting, Audio, Post-Process Stack, Localization |
| 23 | Settings & Accessibility | Meta | Vertical Slice | Not Started | — | Input, Audio, Outline Pipeline, Post-Process Stack, Menu System |

---

## Categories

| Category | Description | Systems |
|---|---|---|
| **Core** | Foundation systems everything depends on | Signal Bus, Input, Outline Pipeline, Post-Process Stack, Player Character, Level Streaming |
| **Gameplay** | The systems that make the game fun | Stealth AI, Combat & Damage, Inventory & Gadgets, Mission Scripting, Failure & Respawn, Civilian AI |
| **Persistence** | Save state and continuity | Save / Load |
| **UI** | Player-facing information displays | HUD Core, HUD State Signaling, Document Overlay UI, Menu System |
| **Audio** | Sound and music systems | Audio (master system covering BGM, SFX, VO, dynamic music) |
| **Narrative** | Story and dialogue delivery | Document Collection, Dialogue & Subtitles, Cutscenes & Mission Cards |
| **Meta** | Systems outside the core game loop | Localization Scaffold, Settings & Accessibility |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems Count |
|---|---|---|---|
| **MVP** | Concept's Tier 0 — Plaza vertical slice. Validates "is stealth fun?" | First playable prototype (1–2 months) | **16** (+ 4 ADRs) |
| **Vertical Slice** | Concept's Tier 1 — full Paris/Eiffel Tower mission. Ship-ready. | Ship build (6–9 months total) | **7** |
| **Alpha** | (Empty — all features are in MVP or VS) | — | 0 |
| **Full Vision** | Tier 2 (Rome/Vatican) and Tier 3 (disguise system) — content additions, not new systems | Post-launch | 0 |

---

## Dependency Map

### Foundation Layer (no dependencies on other game systems)

1. **Signal Bus** — autoload + typed signal hub; everything that publishes events depends on it
2. **Input** — engine `InputMap` only
3. **Audio** — engine audio buses + Signal Bus subscription
4. **Outline Pipeline** — engine renderer; consumes Stencil ID Contract (ADR-1)
5. **Post-Process Stack** — engine renderer; sepia overlay, glow disable, resolution scale
6. **Save / Load** — engine file I/O; consumes Save Format Contract (ADR-3); depends on Localization for save metadata strings
7. **Localization Scaffold** — string-table mechanism

### Core Layer (depends on Foundation)

8. **Player Character** — depends on: Input, Outline Pipeline (FPS hands stencil), Post-Process Stack, Stencil ID Contract
9. **Level Streaming** — depends on: Save/Load. *Note: blocking loads with fade are acceptable for MVP — async streaming is not required for a 5-section linear mission.*

### Feature Layer (depends on Core)

10. **Stealth AI** — depends on: Player Character (target), Audio (alert music transitions), Signal Bus (alert-state-changed event)
11. **Combat & Damage** — depends on: Player Character, Stealth AI (enemies are AI), Audio. *Implementation note: GDD covers weapons + damage as one unit; impl-phase split into `DamageReceiver` component is expected.*
12. **Inventory & Gadgets** — depends on: Player Character, Input
13. **Mission & Level Scripting** — depends on: Stealth AI (event contracts), Combat (event contracts), Level Streaming, Save/Load, Signal Bus. *Can be designed in parallel with Stealth AI / Combat once ADR-2 event taxonomy exists.*
14. **Failure & Respawn** — depends on: Save/Load, Stealth AI (failure trigger), Mission Scripting (sectional restart contract)
15. **Document Collection** — depends on: Player Character, Save/Load, Localization
16. **Civilian AI** — depends on: Player Character, Audio, Signal Bus. *MVP scope: stub (flee + panic SFX). VS scope: witness-reporting (alerts nearest guard).*
17. **Dialogue & Subtitles** — depends on: Audio, Localization, Stealth AI (alert state can trigger banter), Signal Bus

### Presentation Layer (UI wraps gameplay)

18. **HUD Core** *(MVP)* — depends on: Combat (health/ammo), Inventory (gadget readout), UI Framework (ADR-4)
19. **HUD State Signaling** *(VS)* — depends on: HUD Core, Stealth AI (alarm indicator), Document Collection (pickup notifications), Failure & Respawn (critical-health clock-tick)
20. **Document Overlay UI** — depends on: Document Collection, Post-Process Stack (sepia dim), Input, Localization, UI Framework
21. **Menu System** — depends on: Save/Load (mission dossier card), Input, Post-Process Stack, UI Framework

### Polish Layer (depends on everything)

22. **Settings & Accessibility** — depends on: Input (rebinding), Audio (volume), Outline Pipeline (resolution scale), Post-Process Stack, Menu System
23. **Cutscenes & Mission Cards** — depends on: Mission Scripting, Audio, Post-Process Stack, Localization

---

## Recommended Design Order

| Order | Item | Tier | Layer | Suggested Agent(s) | Effort |
|---|---|---|---|---|---|
| **A1** | **ADR-1: Stencil ID Contract** | MVP | Architecture | `technical-director` + `godot-shader-specialist` | 1 session |
| **A2** | **ADR-2: Signal Bus + Event Taxonomy** | MVP | Architecture | `technical-director` + `lead-programmer` | 1 session |
| **A3** | **ADR-3: Save Format Contract** | MVP | Architecture | `technical-director` + `godot-specialist` | 1 session |
| **A4** | **ADR-4: UI Framework** | MVP | Architecture | `ux-designer` + `godot-specialist` | 1 session |
| 1 | Signal Bus | MVP | Foundation | `lead-programmer` + `godot-gdscript-specialist` | S |
| 2 | Input | MVP | Foundation | `game-designer` + `godot-specialist` | S |
| 3 | Audio | MVP | Foundation | `audio-director` + `sound-designer` | M |
| 4 | Outline Pipeline | MVP | Foundation | `technical-artist` + `godot-shader-specialist` | L |
| 5 | Post-Process Stack | MVP | Foundation | `technical-artist` + `godot-shader-specialist` | M |
| 6 | Save / Load | MVP | Foundation | `game-designer` + `godot-specialist` | **L** |
| 7 | Localization Scaffold | MVP | Foundation | `localization-lead` | S |
| 8 | Player Character | MVP | Core | `game-designer` + `gameplay-programmer` | M |
| 9 | Level Streaming | MVP | Core | `level-designer` + `godot-specialist` | M |
| 10 | **Stealth AI** | MVP | Feature | `game-designer` + `ai-programmer` | **L** |
| 11 | Combat & Damage | MVP | Feature | `systems-designer` + `gameplay-programmer` | M |
| 12 | Inventory & Gadgets | MVP | Feature | `game-designer` + `systems-designer` | M |
| 13 | Mission & Level Scripting | MVP | Feature | `game-designer` + `level-designer` | M |
| 14 | Failure & Respawn | MVP | Feature | `game-designer` + `systems-designer` | M |
| 15 | Civilian AI | MVP | Feature | `ai-programmer` + `game-designer` | S |
| 16 | HUD Core | MVP | Presentation | `ux-designer` + `art-director` | M |
| 17 | Document Collection | VS | Feature | `narrative-director` + `game-designer` | S |
| 18 | Dialogue & Subtitles | VS | Feature | `narrative-director` + `writer` | M |
| 19 | HUD State Signaling | VS | Presentation | `ux-designer` + `art-director` | M |
| 20 | Document Overlay UI | VS | Presentation | `ux-designer` + `art-director` | S |
| 21 | Menu System | VS | Presentation | `ux-designer` + `art-director` | M |
| 22 | Cutscenes & Mission Cards | VS | Presentation | `narrative-director` + `art-director` | S |
| 23 | Settings & Accessibility | VS | Polish | `ux-designer` + `accessibility-specialist` | S |

> Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions. ADRs are 1 session each. **Total: ~50–55 sessions across all 23 GDDs + 4 ADRs.**
> Within MVP, Foundation systems (1–7) can be designed in parallel after the 4 ADRs are authored — none depend on each other beyond the ADRs.
> **Stealth AI (#10) is the gating risk** — prototype Tier 0 immediately after its GDD via `/prototype stealth-ai`. The prototype, not the GDD, is the real go/no-go gate for Tier 1 timeline commitment.

---

## Pillar Coverage Matrix

Every pillar must have ≥3 systems serving it. This matrix surfaces coverage gaps.

| Pillar | Served by (count) |
|---|---|
| **1. Comedy Without Punchlines** *(distributed by design — no single-system owner)* | Document Collection, Dialogue & Subtitles, Mission Scripting, Civilian AI, Cutscenes & Mission Cards (5) |
| **2. Discovery Rewards Patience** | Document Collection, Stealth AI, Civilian AI (BQA contact tells), Mission Scripting (alt routes), HUD Core (no waypoints) (5) |
| **3. Stealth is Theatre, Not Punishment** | Stealth AI, Failure & Respawn, Audio, Save/Load (sectional checkpoints) (4) |
| **4. Iconic Locations as Co-Stars** | Level Streaming, Mission Scripting, Outline Pipeline (architecture readability), Post-Process Stack (Paris cityscape backdrop) (4) |
| **5. Period Authenticity Over Modernization** | HUD Core, HUD State Signaling, Menu System, Cutscenes, Audio, Outline Pipeline, Post-Process Stack (7) |

> **Comedy Cross-Reference**: Pillar 1 has no single-system owner — comedy is emergent across 5 systems. Each of these GDDs must explicitly reference Pillar 1 in its Acceptance Criteria. `/review-all-gdds` (run after all MVP GDDs complete) must specifically interrogate cross-system Pillar 1 delivery.

---

## Deliberately Omitted Systems

These systems are **intentionally absent** from this index. Document them to prevent re-litigation.

| Omitted System | Reason | Authority |
|---|---|---|
| Photo Mode | Post-launch polish; no MVP/VS value | Scope |
| Hint UI / Tutorial Overlay | Pillar 5 violation (modern UX paternalism). Diegetic tutorialization handled by Mission Scripting in the Plaza section. | Pillar 5 |
| Difficulty Tiers / Difficulty Selection | Tier 3 Full Vision; MVP ships at one well-tuned difficulty. Clarification 2026-04-20 (cross-review GD-B1): the existing `noise_global_multiplier` (PC Tuning Knobs, safe 0.7–1.3) is a **designer-tuning scalar only**, NOT a player-facing difficulty selector. Likewise `clock_tick_enabled` (Audio) is a pure accessibility toggle, not difficulty. No player UI for either. Any future accessibility-facing noise scaling requires explicit scope expansion + new ADR. | Scope |
| Disguise System | Tier 3 Full Vision (concept doc Tier 3) | Scope |
| Progression / XP / Skill Trees | Anti-pillar (game-concept.md) | Anti-pillar |
| Economy / Currency / Crafting / Shops | Anti-pillar — no resource economy | Anti-pillar |
| Multiplayer / Co-op / Networking | Anti-pillar — single-player premium | Anti-pillar |
| Open World / Map / Fast Travel | N/A — linear vertical mission | Scope |
| Procedural Generation | Anti-pillar | Anti-pillar |
| DLC / Live-Service Hooks | Anti-pillar | Anti-pillar |
| Replays / Spectator Mode | Out of scope | Scope |

---

## Circular Dependencies

**None found.** The dependency graph is a clean DAG. Audio reacts to Stealth AI events (subscriber pattern via Signal Bus); Audio's own design does not depend on AI's existence — it is a generic event-driven system that AI plugs into through the typed event taxonomy in ADR-2.

---

## High-Risk Systems

| System | Risk Type | Description | Mitigation |
|---|---|---|---|
| **Stealth AI** | Technical + Design | Graduated-suspicion AI in Godot 4.6 for a first-time dev is the longest pole in the tent. | **Prototype Tier 0 (Plaza) FIRST**, before committing Tier 1 timeline. `/prototype stealth-ai` after the GDD. |
| **Outline Pipeline** | Technical | `CompositorEffect` + tiered outlines via stencil buffer involves multiple Godot 4.5+ features beyond LLM training cutoff. Stencil-ID contract is cross-cutting. | Author **ADR-1** before any system spawning outlined objects is designed. Verify each ⚠ flagged item in Art Bible 8J against `docs/engine-reference/godot/`. Build a resolution-scale fallback for low-spec PCs. |
| **Audio (dynamic music)** | Technical + Design | NOLF1's dynamic music is famous and load-bearing for state communication. Bad implementation = loss of identity. | Audio system GDD must consume the Signal Bus event taxonomy (ADR-2) precisely. Music transitions need specific composer brief. |
| **Save / Load** | Technical | Serialization of inventory + AI patrol state + document bitmap + mission state is "where first-time Godot projects lose two weeks." | **ADR-3 (Save Format Contract) FIRST** — must precede Inventory, Stealth AI, Document Collection, Mission Scripting GDDs. |
| **Mission & Level Scripting** | Design | Scripted moments are where the comedy lands. Bad scripting = loss of identity. | Heavy collaboration with `narrative-director` + `writer` during design. Playtest aggressively. |
| **Document Collection** | Design (content) | The comedy lives in the documents themselves. 15–25 documents at high quality is significant writing work. | Hire / collaborate with a writer early. Iterate via playtest. |

---

## Progress Tracker

| Metric | Count |
|---|---|
| Required ADRs | **4/4 ALL AUTHORED** (all Proposed; verification gates pending — see individual ADRs and `production/session-state/active.md` for status) |
| Total systems identified | 23 |
| Design docs started | 8 |
| Design docs reviewed | 8 (cross-review 2026-04-20 — see `gdd-cross-review-2026-04-20.md`; verdict FAIL, 6 GDDs flagged Needs Revision) |
| Design docs approved | 0 (Player Character was marked Approved 2026-04-20 mid-day; subsequent cross-review downgraded to Needs Revision for propagation/sweep issues — see B4/B5/GD-B3) |
| MVP systems designed | 8/16 (5 Needs Revision, 3 Designed pending review) |
| Vertical Slice systems designed | 0/7 |

---

## Next Steps

- [ ] Author the 4 architecture decisions FIRST: `/architecture-decision stencil-id-contract`, `/architecture-decision signal-bus-event-taxonomy`, `/architecture-decision save-format-contract`, `/architecture-decision ui-framework`
- [ ] Then start MVP Foundation GDDs: `/design-system signal-bus` (or any of systems 1–7 in parallel)
- [ ] Run `/design-review design/gdd/[system].md` after each GDD is authored
- [ ] **Stealth AI is the gating risk** — reach it in the design sequence; prototype immediately after its GDD via `/prototype stealth-ai`
- [ ] Run `/gate-check pre-production` when all 16 MVP GDDs + 4 ADRs are complete
- [ ] Run `/create-architecture` once enough GDDs exist to inform the master architecture doc (typically after the 4 ADRs and 5–8 GDDs)
- [ ] Run `/map-systems next` at any time to pick up the highest-priority undesigned system automatically
