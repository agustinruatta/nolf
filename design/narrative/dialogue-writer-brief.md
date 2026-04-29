# Dialogue Writer Brief — *The Paris Affair*

> **Status**: Initial Draft (NEW 2026-04-28 night — closes BLOCKING coord §F.6 P7 from `design/gdd/dialogue-subtitles.md` v0.3)
> **Author**: Narrative Director (drafting) + Writer (authoring)
> **Last Updated**: 2026-04-28 night
> **Owns**: §F.6 P7 BLOCKING coord item from `design/gdd/dialogue-subtitles.md`
> **Source GDD**: `design/gdd/dialogue-subtitles.md` (system #18)
> **Sibling brief**: `design/narrative/document-writer-brief.md` (Document Collection #17 — for written paper register)
> **Pillar fit**: Pillar 1 (Comedy Without Punchlines) **load-bearing — banter is THE primary comedy delivery vector**; Pillar 5 (Period Authenticity) load-bearing via 1960s telex/teleprinter caption register; Pillar 3 (Stealth is Theatre) supporting via banter as diegetic SAI-state signal

This brief is the writing-craft contract for every spoken line authored across the 40-line dialogue roster. It complements `document-writer-brief.md`: documents reveal paper FROM the enemy (read silently); dialogue reveals voice FROM the enemy (overheard, like a keyhole). **No banter line beyond the 5-line Plaza MVP-Day-1 tutorial set may be authored without first reading this brief in full.**

---

## 1. Player Fantasy Anchor — "The Eavesdrop"

The player should feel like an eavesdropper standing at a keyhole in 1965 Paris, intercepting fragments of an alien organization's mundane workplace chatter. The fantasy is **the keyhole posture**, not the loudspeaker. Three explicit refusals frame the register:

- **Not a notification** — banter is not the game telling the player what to do; it is overheard activity.
- **Not karaoke** — captions are NOT lyric prompts that scroll in advance; they are intercept transcripts.
- **Not a drama** — banter is not Aaron-Sorkin-style witty exchange; it is workplace bureaucracy with absurd content.
- **Not Eve's voice in free play** — Eve is silent during free-play banter (VT-1); she only speaks in scripted radio briefings (`[STERLING.]` period register).
- **Not a chyron** — captions are 1960s teleprinter intercept format, not modern broadcast lower-thirds.

**The tonal-anchor question for every line written**: *"Does this respect The Eavesdrop?"* If the line tells the player what to do, breaks the fourth wall, names a game system, or sounds like a TV drama, it fails the anchor.

**Three vignettes** (writer's tuning forks):
1. **The Margaux Bit** (Restaurant) — civilian husband to wife: "Marguerite, I think that woman is following us." Wife: "You always think that." (4 lines, deadpan, character-driven, marriage-specific.)
2. **The Radiator Line** (Plaza, MVP-1) — guard, after an unexplained noise: "Could've sworn I heard something." [pause] "Probably the radiator." (CURIOSITY_BAIT category; teaches the player that banter signals SAI state diegetically.)
3. **The Guard Room Cable** (Upper Structure) — patrol pair on lattice catwalk debating which generation of family painted the Tower's ironwork ("My grandfather bid on the 1898 paint contract. Lost to a Belgian." "We've all lost to Belgians."). Workplace nostalgia; PHANTOM as multi-generational employer.

---

## 2. Speaker Categories (7) — Caption Prefix Format

Every authored line MUST be tagged with one of these `speaker_id` values. Caption rendering format below is enforced by `DialogueAndSubtitles.gd` per D&S CR-DS-15/16; the writer authors the line content; the prefix is system-rendered. **Never** include the bracket-tag prefix in the authored line content (it is added at render time).

| # | speaker_id | Caption Prefix | Voice Register | Used in Categories |
|---|------------|----------------|----------------|--------------------|
| 1 | `GUARD_PHANTOM_ANON` | `[GUARD]:` | PHANTOM rank-and-file. Workmanlike. Frequent kettle/cigarette/canteen complaints. Knows trivia not master plan (VT-5). | 1, 2, 4, 6 |
| 2 | `CLERK_PHANTOM_ANON` | `[CLERK]:` | PHANTOM administrative. Dryer than guards. Office politics, requisition forms, printer disputes. | 6, 7 |
| 3 | `LIEUTENANT_PHANTOM_NAMED` | `[LT. MOREAU]:` (per-name) | 1–2 named individuals. Rank attribution. Slightly more strategic visibility but still bounded by VT-5. | 2, 7a |
| 4 | `CIVILIAN_TOURIST_ANON` | `[VISITOR]:` | Bourgeois affronted-Parisian. Fluent French complaint register. Marriage banter. NEVER speaks of the operation. | 5 (Plaza/Restaurant) |
| 5 | `CIVILIAN_STAFF_ANON` | `[STAFF]:` | Restaurant/Tower civilian employees. Complicit-worker register — they know SOMETHING is off but their job is to keep working. | 5, 6 |
| 6 | `BQA_HANDLER_NAMED` | `[HANDLER]:` (or codename) | Eve's BQA radio contact. Consistent voice across mission. Bureaucratic precision. Closing/opening transmission conventions. | 7c |
| 7 | `EVE` | `[STERLING.]` (**period, NOT colon**) | Eve in scripted radio ONLY (VT-1 carve-out). Telex end-of-transmission convention. 1–4 word replies, never longer. | 7c only |

**The `[STERLING.]` period is deliberate** — 1960s telex notation for end-of-transmission acknowledgment. Period vs colon is the typographic differentiator that makes Eve's captions visually distinct from every other speaker. Pillar 5 typographic comedy: the same word in `[GUARD]:` vs `[STERLING.]` reads as two different gestures because the punctuation is doing the work.

**Anonymous-context exception**: lines with `banter_category = PATROL_AMBIENT` render WITHOUT the speaker prefix regardless of `subtitle_speaker_labels` setting (D&S CR-DS-15). The prefix-less line preserves the "overheard ambient" quality where the player hears WORDS not SPEAKERS.

---

## 3. Voice / Tone Rules (VT-1 through VT-8) — Hard Constraints

Every authored line MUST satisfy all 8 rules. Writer-self-check pass before delivery:

### VT-1 — Eve does not speak in ambient banter during free play

Eve is silent except for scripted radio (Category 7c BQA). Even if the player triggers a CURIOSITY_BAIT volume that an enemy might react to, Eve does NOT respond. Her silence is load-bearing — Pillar 1 typographic comedy depends on the rare `[STERLING.]` line landing as punctuation against an otherwise-Eve-silent soundscape.

**Carve-out**: SCRIPTED_SCENE 7c BQA briefings only. The MVP-3 example: `[HANDLER]: Sterling. You're in. Confirm.` / `[STERLING.] Confirmed.` — Eve speaks one word.

**Forbidden authorings**:
- Eve quips when she sees a funny prop. ❌
- Eve mutters when she takes damage. ❌
- Eve has an internal monologue. ❌
- Eve responds to a joke from a guard. ❌

### VT-2 — No fourth-wall breaks; no acknowledgment of game-systemic states

Banter NEVER acknowledges the player as a player, the game as a game, or any system as a system. Guards never say "the player is over there"; they say "I think I saw someone by the brochure stand."

**Forbidden authorings**:
- "Did you hear that footstep?" (uses the system's noise term) ❌
- "I'm at suspicious alert state." ❌
- "Save your progress before going up." ❌

### VT-3 — No in-game-meta references

No achievements, quest log language, "objective" phrasing, save points, mechanic-naming, SAI state names spoken aloud. Banter speakers do not know they are in a game system.

**Forbidden authorings**:
- "I'm investigating the disturbance." (paraphrases SAI Searching state) ❌
- "Better complete the patrol objective." ❌
- "Press X to interact." (anything resembling tutorial language) ❌

**Compliant authoring**:
- "Probably the radiator." ✅ — guard explains the noise as something not-the-player; uses civilian vocabulary.

### VT-4 — BQA acronym is never spelled by enemy speakers

PHANTOM never says "BQA" out loud. Enemies don't know what BQA is — they refer to "the Bureau" or "the British" or vaguely. The acronym lives entirely in Eve's BQA briefings (where she and the Handler use it freely) and in `[STERLING.]` register.

**Forbidden authoring (PHANTOM speaker)**:
- "Watch out for BQA agents." ❌

**Compliant authorings (PHANTOM speakers)**:
- "Watch out for British operatives." ✅
- "The Bureau is asking about us again." ✅
- "Our problem is the British." ✅

**Compliant authoring (BQA speaker)**:
- `[HANDLER]: BQA Section 4 has confirmed your extraction window.` ✅

### VT-5 — PHANTOM knows absurd minor details, never the master plan

Guards and clerks know the canteen kettle is broken. They know the day-shift Henri vs. night-shift Marc roster. They know which freezer was used for the "PHANTOM business" memo (per `document-writer-brief.md`). They do NOT know what PHANTOM does, what the master plan is, or who the next target is. This is an **absolute boundary**: it preserves the curtain-Pillar 4 (the Tower as iconic location) and Pillar 1 (the absurd specificity of workplace details).

**Carve-out**: Named LIEUTENANT may know more than ANON guards but NEVER the master plan. Lt Moreau can know "the Wednesday inspection schedule"; he cannot know "the Lyon operation goes live in ten days."

**Forbidden authorings**:
- `[GUARD]: After we finish the Eiffel job we move to Lyon.` ❌
- `[CLERK]: Mr. Vogel said the bomb is for the German embassy.` ❌

**Compliant authorings**:
- `[GUARD]: Henri's late again. Third time this week.` ✅
- `[CLERK]: The new requisition forms have a different watermark. I keep filing the old ones.` ✅

### VT-6 — Banter never tells the player what to do next

Banter is overheard, not directive. If the player needs to know what to do, the diegetic channel is a Category 7a SCRIPTED_SCENE radio cue (and even those should be oblique). Banter is allowed to *imply* something the player can use, but never to *instruct*.

**Forbidden authorings**:
- `[GUARD]: The maintenance access is unlocked from the south side.` ❌ (instruction disguised as banter)
- `[GUARD]: You should sneak through the kitchen.` ❌

**Compliant authoring (banter that reveals world detail without instructing)**:
- `[CLERK]: Why is the south maintenance door always sticking? I keep oiling the hinge.` ✅ (player can infer the south door is reachable; the speaker is complaining about hinge maintenance)

### VT-7 — SPOTTED-bucket lines: 4-word hard cap, no wit

When a guard is in `SPOTTED` state (D&S Category 4, COMBAT_DISCOVERY priority bucket), the line MUST be ≤ 4 words and contain zero wit, irony, or characterization. SPOTTED is the genre-correct moment for stripped-down clarity — the guard has seen the player and the wit-machine drops out.

**Compliant authorings**:
- `[GUARD]: There she is.` ✅ (3 words)
- `[GUARD]: Stop right there!` ✅ (3 words)
- `[GUARD]: Intruder!` ✅ (1 word)

**Forbidden authorings**:
- `[GUARD]: She's a fast one, this Sterling.` ❌ (8 words; characterization)
- `[GUARD]: I knew it would come to this someday.` ❌ (introspective)

### VT-8 — All banter lines: 12-word ceiling

Excluding SCRIPTED_SCENE 7a/7b/7c radio/cable broadcasts (which may go longer to fit broadcast format), every banter line is ≤ 12 words. Above 12 words, the player cannot read the caption before it auto-clears (per D&S F.1 caption clock = max(audio_finished_t, line_start + duration_metadata_s)).

**Compliant authorings (most banter)**:
- `[GUARD]: Could've sworn I heard something. Probably the radiator.` ✅ (8 words, fits comfortably)
- `[GUARD A]: You take the brochure stand.` / `[GUARD B]: Someone has to.` ✅ (6 / 4 words; pair exchange)

**Forbidden authoring (over 12 words in single line)**:
- `[GUARD]: I keep telling Lt. Moreau that the south stairwell rotation needs three guards not two but he never listens to me.` ❌ (split into two lines or cut)

---

## 4. Per-Section Line Roster (40 lines total)

| # | Section | Tonal Direction | Line Count | MVP/VS | Active Categories |
|---|---------|-----------------|------------|--------|-------------------|
| 1 | **Plaza** | *Surface Legitimacy* — guards perform normalcy, tourist-adjacent | **5** | 3 MVP + 2 stretch | 1, 2, 5, 6 (limited), 7c |
| 2 | **Lower Scaffolds** | *Workplace Revealed* — workmanlike grumbling, the canteen kettle | **8** | VS | 1, 2, 6 (heavy), 7a |
| 3 | **Restaurant** | *Social Cover* — dinner-party deadpan, civilian/staff/PHANTOM social collision | **12** | VS | 1, 2, 3, 5, 6, 7b |
| 4 | **Upper Structure** | *Command Paperwork* — military command + bureaucratic absurdity | **10** | VS | 2, 3, 4, 6 (sparse), 7a, 7c |
| 5 | **Bomb Chamber** | *Final — Deadly Serious and Still Absurd* — residual proceduralism | **5** | VS | 2, 4, 6 (minimal), 7a |
| **TOTAL** |  |  | **40 lines** | within 30–50 game-concept target |  |

Per-section narrative arc:
- **Plaza** — the tower is a tourist venue; banter is mostly civilians + low-grade PHANTOM staffing. Workplace mundanity is the surprise.
- **Lower Scaffolds** — PHANTOM workplace becomes visible (rosters, kettles, missing guards). Comic register is the canteen.
- **Restaurant** — civilian/staff/PHANTOM social collision. Marguerite is here. Vogel is here. The dining-room overhears.
- **Upper Structure** — command paperwork. Lt Moreau inspections. PHANTOM hierarchy briefly visible. BQA radio briefings start landing.
- **Bomb Chamber** — register *narrows*; humor *thins*. The mission is still absurd in its bureaucratic scaffolding (radio handler still using extraction protocols), but the playful banter recedes. Silent entry per D&S §B.5.

---

## 5. Plaza MVP-Day-1 Tutorial Set (5 lines: 3 core + 2 stretch)

These 5 lines are the only MVP-Day-1 lines. Every other roster entry is VS. The 3 core lines (MVP-1, MVP-2, MVP-3) MUST ship at MVP-Day-1; the 2 stretch lines (MVP-4, MVP-5) ship if delivered + recorded by Day-1 deadline.

### MVP-1 (CORE) — CURIOSITY_BAIT — The Radiator Line

- **scene_id**: `&"plaza_radiator_curiosity_bait"`
- **Trigger**: MLSTrigger Area3D body_entered on radiator-near volume (1.5 m radius)
- **Speaker**: `GUARD_PHANTOM_ANON`
- **Line (working)**: `[GUARD]: Could've sworn I heard something.` [pause 1.0 s] `[GUARD]: Probably the radiator.`
- **Word count**: 5 + 4 = 9 words across 2 sub-lines (within 12-word ceiling per line)
- **Teaches**: The Eavesdrop fantasy + CR-DS-6 carve-out (CURIOSITY_BAIT vocal-completion protected from interrupt)
- **Audio note**: 2 audio files, 1.0 s gap; `dialogue_line_started` fires at the start of each; one `dialogue_line_finished` at the end of each (not a single 2-line composite)

### MVP-2 (CORE) — SCRIPTED_SCENE 7b — Guard Pair Brochure Stand

- **scene_id**: `&"plaza_guard_pair_brochure"`
- **Trigger**: MLSTrigger volume in Plaza (player crosses scripted-volume per MLS T1 Overheard Banter)
- **Speakers**: `GUARD_PHANTOM_ANON` × 2 (Guard A, Guard B)
- **Lines (working)**:
  - `[GUARD A]: You take the brochure stand.`
  - `[GUARD B]: Someone has to.`
- **Word count**: 6 + 4 = 10 words (well within ceiling)
- **Teaches**: Ambient register; guards have own conversations independent of player
- **Phasing note (v0.2)**: re-categorized from PATROL_AMBIENT to SCRIPTED_SCENE 7b for MVP because PATROL_AMBIENT requires patrol-cycle infrastructure that is VS-only. Two-line MLS-triggered exchange ships at MVP without VS infrastructure dependency.

### MVP-3 (CORE) — SCRIPTED_SCENE 7c BQA — Briefing Confirmation

- **scene_id**: `&"plaza_bqa_briefing_intro"`
- **Trigger**: `section_entered(plaza, FORWARD)` synchronous after `_player_ready` (D&S CR-DS-9 boot-window guard)
- **Speakers**: `BQA_HANDLER_NAMED` + `EVE`
- **Lines (working)**:
  - `[HANDLER]: Sterling. You're in. Confirm.`
  - `[STERLING.] Confirmed.`
- **Word count**: 5 + 1 = 6 words
- **Teaches**: BQA briefing carve-out (Eve speaks in radio); `[STERLING.]` typographic format; the period vs colon convention

### MVP-4 (stretch) — ALERT_DE-ESCALATION — Maintenance Bucket

- **scene_id**: `&"plaza_deescalation_maintenance"`
- **Trigger**: `alert_state_changed(SUSPICIOUS, UNAWARE)` after a CURIOSITY_BAIT investigation completes
- **Speaker**: `GUARD_PHANTOM_ANON`
- **Line (working)**: `[GUARD]: False alarm. Maintenance bucket.`
- **Word count**: 4 words
- **Teaches**: Self-correcting bureaucrat register; world quips Eve listens to

### MVP-5 (stretch) — CIVILIAN_REACTION — Affronted Parisian

- **scene_id**: `&"plaza_civilian_reaction_affronted"`
- **Trigger**: `civilian_panicked(civilian, _)` near the speaker civilian (within 4 m)
- **Speaker**: `CIVILIAN_TOURIST_ANON`
- **Line (working)**: `[VISITOR]: Monsieur — really.`
- **Word count**: 3 words
- **Teaches**: Affronted-Parisian register; civilian comedy of manners as Pillar 1 vector

---

## 6. Caption Punctuation Discipline (1960s Teleprinter Register)

Captions follow a consistent typographic register that supports Pillar 5:

- **Period at end of sentence** — always. Even short utterances ("False alarm.").
- **Em-dash for interruption / aposiopesis** — ` — ` (space, em-dash, space). Used when a speaker trails off or another speaker cuts in.
- **No exclamation marks** — except in SPOTTED-bucket lines (where the urgency is genre-correct) and in narrowly-scoped CIVILIAN_REACTION (Marguerite's "really.").
- **No question marks for rhetorical questions** — only for genuine information requests ("Did Henri call in sick today?"). Rhetorical questions land as statements ("I keep telling him.").
- **No ellipsis (…)** — replaced by em-dash or by silent gap between lines (the audio engineer adds the silence; the caption shows two clean sentences).
- **Eve's `[STERLING.]` register** — ALWAYS terminate with period inside the bracket (not colon). One- to four-word replies. Never exclamatory.
- **No emoji, no parentheses around stage directions** — `(sigh)` and `(laughs)` are forbidden in the caption text. If a line needs vocal performance notes, those go in the `DialogueLine.performance_notes: String` schema field (NEVER displayed to player).

---

## 7. Localization Considerations

Lines authored in English ship as the canonical reference. French + German translations are produced via the localization pipeline (Localization Scaffold #7). Writer should be aware:

- **12-word ceiling is English-anchored** — German + French translations may run 15–20% longer. Localization pipeline coordinates with D&S F.1 caption clock to ensure displayed time accommodates locale-specific length (D&S `dialogue_caption_metadata_floor_s_default = 0.0` per registry; metadata duration provides per-line override per F.1 `max(audio_finished_t, line_start + duration_metadata_s)`).
- **`[STERLING.]` period convention** — translates as period in French (`[STERLING.]`) and as period in German (`[STERLING.]`). The bracket form is preserved across all locales; the period is universal.
- **`vo.speaker.delimiter` localizable key** — caption rendering format uses `tr("vo.speaker.delimiter")` (default English: `": "`); CJK + RTL locales may translate to different separators per D&S CR-DS-16.
- **CURIOSITY_BAIT lines should avoid English-specific idiom** — "Could've sworn I heard something" translates cleanly. "Heads up, mate" does NOT (Britishism; locale-specific connotation).
- **BQA register is bureaucratic-formal across locales** — the Handler's voice uses the host language's bureaucratic register (French: `Monsieur Sterling, confirmation.` / German: `Herr Sterling, Bestätigung.`). The register is the constant; the words shift.

Translator brief lives separately at `design/narrative/dialogue-translator-brief.md` (NOT YET AUTHORED — VS scope).

---

## 8. CI Lint Contract (joins MLS section-validation CI)

Per `mission-level-scripting.md` §C.4.1 lint contract, the following CI checks join the existing MLS section-validation pipeline (Tools-Programmer scope, NEW BLOCKING coord item):

1. **Roster join lint** — `tools/ci/lint_dialogue_writer_brief.sh` cross-references this brief's per-section roster (§4) against `mission-level-scripting.md` §C.4.1 scene_id table. Every `scene_id` in MLS MUST appear in this brief; every `scene_id` in this brief MUST appear in MLS. Build fails on orphaned IDs (either side).
2. **Caption-prefix lint** — every authored line's `speaker_id` MUST resolve to one of the 7 categories in §2 of this brief. Build fails on unrecognised speaker_id.
3. **VT-7 SPOTTED 4-word lint** — every line tagged `banter_category = SPOTTED` MUST have ≤ 4 words. Build fails on overlong SPOTTED lines.
4. **VT-8 12-word lint** — every line NOT tagged SCRIPTED_SCENE 7a/7b/7c radio/cable MUST have ≤ 12 words. Build fails on overlong banter.
5. **`[STERLING.]` period lint** — every line tagged `speaker_id = EVE` MUST render with period (`[STERLING.]`), not colon. Build fails on `[STERLING:]` typo.
6. **BQA acronym lint** — no PHANTOM-tagged speaker (`GUARD_PHANTOM_ANON`, `CLERK_PHANTOM_ANON`, `LIEUTENANT_PHANTOM_NAMED`) line may contain the literal string `BQA`. Build fails on VT-4 violation.
7. **Eve-silence lint** — no `EVE` line may exist outside `banter_category = SCRIPTED_SCENE` with sub-register 7c. Build fails on VT-1 violation.

Lint failures block the build. Authors fix before merging.

---

## 9. Common Mistakes to Avoid (Editor Checklist)

Before submitting any line to the writer brief, self-check:

- [ ] Speaker prefix is implicit in `speaker_id` tagging — NOT in line content.
- [ ] Line is ≤ 12 words (or ≤ 4 if SPOTTED).
- [ ] No fourth-wall break.
- [ ] No game-system vocabulary.
- [ ] No master-plan disclosure (PHANTOM speakers).
- [ ] No instruction to player.
- [ ] BQA acronym appears only in BQA-speaker lines.
- [ ] Period at end of every line (em-dash for interruption only).
- [ ] No `[STERLING:]` (colon-with-Eve) — always `[STERLING.]` (period).
- [ ] Eve speaks only in scripted radio (Category 7c).
- [ ] No emoji, no parentheses for stage directions, no ellipsis.
- [ ] If MLS-triggered: `scene_id` matches `mission-level-scripting.md` §C.4.1 roster.
- [ ] Locale-portable phrasing (avoid English idiom that wouldn't translate to French/German cleanly).

---

## 10. Open Questions for Writer (Track in §F.6 of D&S GDD)

- **OQ-WRITER-1** — VS-tier civilian banter library scope: how many CIVILIAN_REACTION lines per section? Currently §4 reserves Cat 5 for Plaza + Restaurant only. Tower civilians elsewhere? *Owner: Narrative Director + Writer. Resolution: VS first-playtest gate.*
- **OQ-WRITER-2** — Lt Moreau named-speaker depth: how many lines does Moreau get per section? `LIEUTENANT_PHANTOM_NAMED` shows up in §2 as 1–2 named individuals total — exactly which sections, exactly how many lines? *Owner: Narrative Director. Resolution: pre-VS sprint.*
- **OQ-WRITER-3** — French translation cadence: does the BQA Handler speak French, English, or code-switch? Period authenticity favors French; player accessibility favors English; current `dialogue-subtitles.md` is locale-agnostic on this. *Owner: Narrative Director + Localization Lead. Resolution: pre-VS sprint.*

---

*End of brief. Companion brief for written paper register: `design/narrative/document-writer-brief.md`. Source GDD: `design/gdd/dialogue-subtitles.md`.*
