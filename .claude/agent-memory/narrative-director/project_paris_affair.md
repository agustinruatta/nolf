---
name: Project — The Paris Affair
description: Core game concept, design pillars, mission structure, narrative scope, and current GDD authoring status
type: project
---

**The Paris Affair** — indie stealth-FPS, Godot 4.6, spiritual successor to NOLF1.

**Protagonist**: Eve Sterling, deadpan British BQA (secret intelligence) agent. Eve is SILENT by default during gameplay — no quips, no internal monologue, no reaction lines. Her only speech is scripted BQA radio (`[STERLING.]` telex register, 1–4 words max). The `[STERLING.]` period-not-colon typographic convention is load-bearing.

**Setting**: 1965 Paris, single mission, Eiffel Tower. Five sections: Plaza → Lower Scaffolds → Restaurant → Upper Structure → Bomb Chamber.

**Villain faction**: PHANTOM. Guards know mundane details (canteen, rosters, kettle). They NEVER know the master plan. BQA acronym appears only in BQA-speaker lines.

**Design Pillars (priority order)**:
1. Comedy Without Punchlines — humor in characters/signage/documents; protagonist never quips; composition + typography carry the wit
2. Discovery Rewards Patience — removing UI is not discovery; discovery must be designed (CR-21 per-section Discovery Surfaces)
3. Stealth is Theatre Not Punishment — stealth beats are theatrical; failure is not game-over
4. Iconic Locations as Co-Stars — the Tower is a character; every section uses its architecture
5. Period Authenticity Over Modernization — no objective markers, no minimap, no modern UX vocabulary

**Mission register**: BQA dossier. Bureaucratic-formal. 1960s teleprinter / typewritten. Operation codename: `OPERATION: PARIS AFFAIR`. Closing stamp: `STATUS: CLOSED` (never "MISSION ACCOMPLISHED").

**GDD authoring status (as of 2026-04-28)**:
- GDD #22 Cutscenes & Mission Cards: §A (overview), §B (player fantasy — "The Title Sequence Drops," locked) complete. §C (narrative content roster) drafted in this session — not yet written to file, pending approval.
- dialogue-writer-brief.md: complete (BQA voice rules, 40-line dialogue roster, 7 speaker categories, 8 VT rules, CI lint contract)
- mission-level-scripting.md: approved 2026-04-24 (MLS CR-13 governs cutscene dispatch via mission-domain signals)
- MissionObjective.show_card_on_activate: bool = true is the per-objective card opt-in field

**Cinematic budget for the mission**: 6 total (5 section-transitions + 1 climactic). §C uses 3 (Restaurant→Upper explosion, Upper→Bomb rappel, bomb-disarm climactic). 3 section-transitions are silent LSS fades (Plaza→Lower, Lower→Restaurant, and the Plaza entry which has no transition cinematic at all).

**Card budget**: 8 total (1 briefing + 1 closing + up to 6 per-objective opt-in). §C uses 5 (2 mission cards + 2 per-objective opt-in cards at VS1 + 1 third slot held for VS2 Upper Structure).

**Rome arc**: The closing dossier carries a `cutscenes.mission_card.closing.addendum` field with a BQA routing note seeding the Italy sequel. Model line: `REF: IT-65-002 ROUTED TO SECTION 6. ROME STATION ADVISED.` The numbering system (PA-65-001 → IT-65-002) implies PHANTOM operates across multiple European cities.
