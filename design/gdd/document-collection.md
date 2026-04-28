# Document Collection

> **Status**: In Design — Revision pass applied 2026-04-27 per `/design-review` (10 BLOCKING items resolved)
> **Author**: User + `/design-system` skill + specialists (narrative-director + game-designer per index routing); revised by user + `/design-review` 2026-04-27
> **Last Updated**: 2026-04-27 (post-design-review revision pass)
> **Last Verified**: 2026-04-27
> **Revision history**:
> - **2026-04-27 design-review revision pass** — 10 BLOCKING items addressed: LSS callback orchestration (CR-5/CR-6 + §C.6 pseudocode rewritten — DC no longer registers its own LS callback, MLS orchestrates); null-deref guards added to spawn-gate + pickup handler; F.1 worked example reconciled + O(N) Big-O claim corrected + range-floor assumption documented + AC-DC-9.4 wall-clock timing AC added; §G.1 cross-constraint invariants added (off-path ratio cap 0.86, per-section sum ≥ total min, Plaza min raised to 3); Plaza Doc 2 distance corrected to 12–15 m; §C.5.7 furniture-surface taxonomy + §C.5.8 DocumentBody.tscn template stub added; AC fixes: test-file naming convention, AC-DC-9.1 explicit ±0.0005 ms tolerance, AC-DC-6.1/6.2 BLOCKED-on tags removed, AC-DC-5.4 upgraded to BLOCKING, AC-DC-6.5/6.6 NEW (CR-17 + E.5 coverage), AC-DC-7.1 word-boundary regex + comment exclusion, AC-DC-9.3 evidence path corrected; AC-DC-1.4/1.5 NEW (cross-constraint + tscn-template lints); audio §A.1 cross-references corrected to actual audio.md sections + dB semantic clarification; §F.5 coord items expanded from "4 MVP + 3 VS" to "7 MVP + 3 VS" (added .tscn template, writer brief, MLS restore orchestration, audio dB-semantic clarification); writer brief authored at `design/narrative/document-writer-brief.md` per BLOCKING #6 scope.
> **Implements Pillar**: 2 (Discovery Rewards Patience — primary, load-bearing); 1 (Comedy Without Punchlines — supporting via dry BQA register and typographic comedy); 4 (Iconic Locations as Co-Stars — supporting via Tower-geometry-bound document placement)
> **Source Concept**: `design/gdd/game-concept.md`
> **Systems Index Row**: #17 · VS · Narrative Layer · S effort
> **Phasing**: Single GDD with per-section [MVP] / [VS] tags. **MVP scope**: ID schema, Resource format, pickup/collect lifecycle, save persistence, 3 frozen ADR-0002 signals, locale-safe content. **VS scope**: full 15–25 document roster, pickup-toast handoff to HSS #19, full-screen reading via Document Overlay UI #20.
> **Dependencies (upstream, locked)**: Player Character ✅, Save/Load ✅, Localization Scaffold ✅, ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0006, ADR-0007, ADR-0008
> **Dependents (forward)**: Audio ✅, Mission & Level Scripting ✅, Save/Load ✅ (passive contributor), HUD State Signaling #19 (VS, Not Started), Document Overlay UI #20 (VS, Not Started)

## Overview

Document Collection is *The Paris Affair*'s **Pillar-2 reward loop layer plus the cross-system data contract** for in-world readable lore. As a **data layer** it owns: the `Document` Resource schema (`class_name Document extends Resource` with `id: StringName`, `title_key: StringName`, `body_key: StringName`, `section_id: StringName`, optional `tier_override: int`, `interact_label_key: StringName`), the **uncollected-document body** (`StaticBody3D` on `LAYER_INTERACTABLES` per **ADR-0006**, stencil **Tier 1 (heaviest, 4 px @ 1080p)** per **ADR-0001** so that off-path documents read against 1960s interior chrome at ten metres), the **3 frozen Document-domain signals** declared in **ADR-0002** for which this system is sole publisher (`document_collected(document_id: StringName)`, `document_opened(document_id: StringName)`, `document_closed(document_id: StringName)`), and the `DocumentCollectionState` sub-resource on `SaveGame` per **ADR-0003** (`@export var collected: Array[StringName]` — locked schema, ID-only persistence, no document content stored in the save). As a **player-facing surface** it is the **patient observer's reward** — Pillar 2 made tactile: every document is a 1965 BQA file, PHANTOM memo, Restaurant menu, telex transcript, or hand-typed dossier that Eve Sterling pockets without comment, and the comedy lives in the typography (per Pillar 1: the requisition-memo register established in Inventory §Player Fantasy). All visible strings flow through `tr("doc.[id].title")` / `tr("doc.[id].body")` per **ADR-0004** + Localization Scaffold; documents are NEVER content-baked into Document Resources — only translation keys are. Document Collection is **NOT autoload** per **ADR-0007**; it lives as a per-section node tree analogous to the `WorldItem` pattern (Inventory CR-7 + MLS section authoring contract). It claims **≤0.05 ms steady-state from the ADR-0008 Slot 7 / Slot 8 residual pool** — a pure subscriber-of-`player_interacted` + emitter-of-3-signals system with no per-frame work outside the pickup event. **MVP scope** [tagged per-section throughout this GDD]: the Document Resource schema, the pickup→pocket→`document_collected` lifecycle, save persistence, locale-safe content keys, and a 3-document tutorial set placed in the **Plaza** section to validate the loop end-to-end. **VS scope**: the full 15–25 document roster across all five Tower sections (Plaza → Lower Scaffolds → Restaurant → Upper Structure → Bomb Chamber per `game-concept.md`), the `document_opened` / `document_closed` signal handoff to **Document Overlay UI #20** (which owns the full-screen reading modal and the `PostProcessStack.enable_sepia_dim()` call), and the pickup-toast handoff to **HUD State Signaling #19**. **Pillar fit**: Primary **2 (Discovery Rewards Patience)** is load-bearing — every document is a reward for observation off the speedrun line, every section's document set is partially placed off-path; Supporting **1 (Comedy Without Punchlines)** is served typographically — the BQA dry-clerical register established in Inventory's pre-packed-bag fantasy carries here verbatim through `# context`-annotated translation keys; Supporting **4 (Iconic Locations as Co-Stars)** is served by binding documents to specific Tower geometry — a literal Restaurant menu in the Restaurant section, a maintenance schedule on the Lower Scaffolds, a PHANTOM telex in the Bomb Chamber.

**This GDD defines:**
- The `Document` Resource schema (fields, defaults, ID convention)
- The uncollected-document body specification (collision shape, layer, interact priority, stencil tier)
- The collection lifecycle (PC interact → pocket → emit `document_collected` → body `queue_free`)
- The 3 ADR-0002 signal emit-sites and their preconditions
- The `DocumentCollectionState.capture()` / `restore()` contract (per ADR-0003 + LSS register-restore-callback pattern)
- The locale-safe content key convention (`doc.[id].title` / `doc.[id].body`) and the locale-change re-resolution rule
- The per-section authoring contract (MLS section scenes embed Document instances; counts and placement bounds)
- The Pillar 5 forbidden patterns (no "5 of 7 documents" UI counter, no objective marker on uncollected docs, no quest-log entry, no achievement popup)

**This GDD does NOT define:**
- The full-screen reading modal layout, font, page-flip animation, or close-input handling — **Document Overlay UI #20 (VS)** owns
- The pickup-toast widget ("DOCUMENT COLLECTED: [TITLE]") — **HUD State Signaling #19 (VS)** owns
- The pickup SFX, music duck, or open/close audio cue — **Audio ✅** subscribes to the 3 signals and owns playback
- The `enable_sepia_dim()` / `disable_sepia_dim()` call sites — **Document Overlay UI #20** owns the lifecycle, **Post-Process Stack ✅** owns the implementation
- Document placement per section — **Mission & Level Scripting ✅** owns the section authoring contract; this GDD specifies the contract bounds (counts, distance from path, interact-distance feasibility)
- The actual document content (titles, bodies, prose) — **Writer + Localization deliverable** at `/localize` time; this GDD specifies the schema and tonal register only
- The comic-book outline shader — **Outline Pipeline ✅** owns; DC writes the stencil-tier value per ADR-0001
- The save file format — **Save/Load ✅ + ADR-0003** own; DC supplies the typed `DocumentCollectionState` sub-resource only

## Player Fantasy

**"Reading the Room."** Eve Sterling does not collect documents — she **notices** them. The fantasy is the discipline of recognising where bureaucracy accumulates: the maître d's lectern, the elevator operator's stool, the clerk's clipboard left on a crate beside a thermos, the in-tray on a desk no one has tidied since Tuesday. Patient observation is the entire mechanic; the document is the page that yields itself to a player who has read the room better than the people who wrote the page. Eve is not an archivist, not a completionist, not a hoarder of lore — she is a field agent working a building that has been lived in by the enemy, and every lived-in surface leaves paper.

The **Tower's paper is PHANTOM's paper**. It was not placed for Eve; it was filed by a clerk who did not expect to be observed. The comedy is structural — PHANTOM is a workplace. Apocalypse-cultists keep duty rosters, complain about the canteen kettle, take attendance at the morning briefing, and file dossiers on field agents in the order their typist gets to them. The hand-typed dossier on Eve sits *behind* the kettle complaint because the clerk's priorities are clerical, not strategic — and that is the joke the page does on its own, without the protagonist's help. (Pillar 1: *Comedy Without Punchlines*, served typographically — the page is funny; Eve is not.)

**References**: Cate Archer's NOLF1 documents (*the* primary touchstone — typewritten BQA-adjacent letterhead, dry tone, factual register, occasional absurdity surfacing through bureaucratic detail). Thief 1's environmental storytelling (paper as worldbuilding rather than questgiver). The historical Stasi Records Agency files (paper as evidence of how an institution *worked*, not as plot delivery).

**Pillars served:**

- **Pillar 2 (Discovery Rewards Patience)** — *load-bearing*. The fantasy IS patient observation. Documents accumulate where bureaucracy accumulates; the player learns to read PHANTOM's habits and finds paper there. This is environmental literacy, not checklist-hunting. Off-path documents (Tower geometry rewarding the patient observer over the speedrunner) are the explicit Pillar-2 instrument. The Pillar's design test holds verbatim: *the patient observer's path must always be more rewarding than the speedrunner's* — and the document is what the patient observer collects.
- **Pillar 1 (Comedy Without Punchlines)** — *supporting, structural*. The comedy is that PHANTOM is a workplace. The dossier on Eve is filed behind the kettle complaint. The bomb-disarm directive carries a footnote about parking validation. The chief scientist's dietary memo predates his apocalypse plan in the in-tray. Eve never quips; the paper does the comedy on its own terms, in the BQA-adjacent register established by Inventory's *Pre-Packed Bag* — except where Inventory **issues** paper to Eve, Documents **reveal** paper from the enemy. Same clerical universe, opposite end of the desk.
- **Pillar 4 (Iconic Locations as Co-Stars)** — *supporting, geometric*. Documents live in Tower-specific furniture. Each section's paper-shape is unique to its room: the Plaza has a tourist-guide register desk; the Lower Scaffolds have maintenance clipboards on crates; the Restaurant has the maître d's lectern and reservation books; the Upper Structure has the comms nook and observation-deck guestbook; the Bomb Chamber has PHANTOM's operational paperwork. A document that could exist in any section's furniture fails this fantasy — it must require *this* section's geometry to read believable.

### Felt moments (anchor vignettes)

1. **The Clipboard** *(Lower Scaffolds, anchor moment).* Eve has bypassed the obvious catwalk and dropped to a forgotten maintenance platform. A clerk's clipboard sits where he left it: on a crate, beside a thermos, beneath a pencil. She lifts the top page — kettle complaint. Second page — duty roster. Third page, folded once, hand-typed: four lines about her left hand and her training in Lyon. She refolds it the way it was folded. She replaces the kettle complaint on top. The clerk will return to a clipboard he is certain he left exactly as he left it. *(Pillar 2: discovery is the act of going down to the platform. Pillar 1: the comedy is that her dossier is filed behind a kettle complaint. Pillar 4: only this section has crates-and-thermoses-and-clipboards.)*
2. **The Lectern** *(Restaurant section, supporting moment).* Eve slips behind the maître d's lectern while a waiter argues with a PHANTOM officer about corkage. On the lectern shelf, half-tucked under the reservations book, sits a typed memo about Dr. Vogel's dietary requirements — sulfite allergy, classified, signed by a clerk who initialed it twice. Three rooms later, in a service corridor, Eve unfolds it. The bioweapon's stabilizer is sulfite-based. *(Pillar 2: the lectern was an off-path detour. Pillar 1: the apocalypse has a corkage problem. Pillar 4: this is what a 1965 Parisian restaurant has.)*
3. **The Telex** *(Bomb Chamber, structural moment).* Eve has reached the operational core. PHANTOM's communications consoles still hum. In the operator's in-tray, a final telex — typed in capitals, stamped, dated tonight, confirming detonation. Eve does not pocket it. She has already read the rest. The detonation telex is the page that completes the case file the player has been assembling for two hours. *(Pillar 4: the comms nook only exists because this is the operational core. Pillar 2: the player who has read the previous documents understands what this one means without exposition.)*

### What this fantasy refuses

The fantasy is *being the kind of agent who finds documents because she reads rooms correctly.* It is NOT the fantasy of:

- **Acquiring** a checklist (no "5 of 7 documents collected" UI counter — Pillar 5 forbids the achievement-game register)
- **Completing** a collection (a player who reads 12 of 23 documents has had a complete experience; the missed 11 are texture, not failure)
- **Theatrical theft** (the *Mission Impossible* heist register oversells the system; most documents are worth a glance, not a setpiece)
- **Lore drop** (a document that exists because a designer wanted to place lore here is a violation; PHANTOM's clerks placed every document, and no document exists outside the clerks' work-shape)
- **Quest delivery** (no document tells Eve where to go next; the bomb-disarm objective is delivered diegetically by Mission Scripting via radio chatter and signage, not by a tutorial-document)

### Design test for any candidate document

*Would a PHANTOM (or BQA, or restaurant-staff, or maintenance-crew) clerk have left this here in the course of doing their job?* If yes, place it. If no — if it reads like a designer-authored lore drop in a strategic location — cut it or relocate it to a piece of furniture where the work-shape would justify it. The Tower's paper must look *worked in*, not *placed*.

### Fantasy test for future system additions

Any addition to Document Collection (a new document type, a new pickup verb, a new presentation surface) must pass three checks: (a) it preserves the curatorial register — Eve does not react to documents, the page does the work; (b) it preserves the observation-not-acquisition gradient — the act of finding is the reward, not the act of completing; (c) it preserves the geometric specificity — the document belongs to this room, not the genre. If any of these fail, the addition belongs elsewhere (Cutscenes for setpieces, Mission Scripting for objectives, HSS for notifications).

Players will never say *"I love the document collection system."* They will say *"this game treats me like an adult — it leaves real paper in real rooms and trusts me to read it."*

## Detailed Design

### C.1 — Core Rules

**CR-1 [MVP]** `Document` Resource schema: `class_name Document extends Resource`. Fields: `id: StringName` (unique mission-wide, snake_case e.g. `&"plaza_security_logbook_001"`), `title_key: StringName` (Localization key `doc.[id].title`), `body_key: StringName` (`doc.[id].body`), `section_id: StringName` (owning section identifier — Plaza/Lower/Restaurant/Upper/Bomb), `interact_label_key: StringName = &"ui.interact.read_document"` (HUD prompt label key; defaults to read; MVP override `&"ui.interact.pocket_document"` until VS Overlay ships), `tier_override: int = -1` (use `-1` for default Tier 1 stencil per ADR-0001; reserved for VS edge cases). All fields are MVP. Content strings are NEVER stored in the Resource — only translation keys.

**CR-2 [MVP]** Uncollected document body: `DocumentBody extends StaticBody3D`. Layer: `LAYER_INTERACTABLES` (ADR-0006), no other layer bits. `interact_priority = 0` (DOCUMENT — highest priority, beats TERMINAL=1 / PICKUP=2 / DOOR=3). `CollisionShape3D` child: thin `BoxShape3D` matching physical paper dimensions (~30×20 cm typical). Stencil tier 1 (4 px @ 1080p, heaviest) per ADR-0001. Carries `@export var document: Document` reference.

**CR-3 [MVP]** Pickup lifecycle (synchronous, single frame): (a) PC `_resolve_interact_target()` raycast hits `DocumentBody` at priority 0; (b) PC `is_hand_busy()` gates — if `true`, input is suppressed at PC level (no buffering at DC); (c) PC fires pre-reach + reach animation (~150 ms decision beat); (d) F&R may cancel mid-reach if damage ≥ 10 HP — `player_interacted` is NOT emitted in that case; (e) on successful reach, PC emits `Events.player_interacted(target: Node3D)`; (f) `DocumentCollection` (DC) subscribes; handler validates `is_instance_valid(target)` per ADR-0002 IG4, then `target is DocumentBody` type-check, then idempotency check via `_collected.has(target.document.id)`; (g) DC appends id to `_collected: Array[StringName]`; (h) DC emits `Events.document_collected(target.document.id)`; (i) DC calls `target.call_deferred("queue_free")`. Step (i) uses `call_deferred` not immediate `queue_free` to align Jolt 4.6 deferred-body removal with Godot's scene-tree reaping (godot-feasibility VG-DC-1).

**CR-4 [MVP]** `is_hand_busy()` idempotency is owned by PC, not DC. A second E press during the reach window is suppressed at PC level — no second `player_interacted` fires; DC does not need to re-suppress. If `is_hand_busy()` ever fails to suppress (engine bug / future regression), DC's CR-3(f) idempotency check via `_collected.has(id)` catches the duplicate emit.

**CR-5 [MVP]** Section-load spawn gate (CANONICAL — REVISED 2026-04-27 per design-review godot-specialist findings 1+3): DC does NOT register its own LSS step-9 callback. Per `level-streaming.md` §Caller table, only Mission & Level Scripting (#13), Failure & Respawn (#14), and Menu System (#21) register LS step-9 callbacks. **MLS orchestrates per-system restore** during its LS callback (analogous to MLS's `assemble_save_game()` capture orchestration per MLS CR-15). DC exposes `restore(state: DocumentCollectionState) -> void` as a public method that MLS calls within MLS's LS step-9 callback, BEFORE LS emits `section_entered`. `restore()` (a) assigns `_collected` from the input state, (b) immediately runs the spawn-gate iteration. Spawn-gate iterates the section's `documents/` Node3D group via `get_tree().get_nodes_in_group(&"section_documents")`, and for each `DocumentBody` child whose `document.id` appears in `_collected`, calls `child.queue_free()` synchronously (NOT deferred — runs before LS emits `section_entered`, so the section is not yet visible to the player). The window where collected bodies exist in the live scene is zero from the player's perspective. Each iteration step null-guards `body.document` (E.15) before reading `body.document.id`. **NEW BLOCKING coord item §F.5#11**: MLS GDD §C.5 must add DC to its per-system restore-orchestration list within MLS's registered LS callback (alongside the existing Save/Load + LSS coordination).

**CR-6 [MVP]** `DocumentCollectionState` save contract: `class_name DocumentCollectionState extends Resource` with `@export var collected: Array[StringName]` — frozen schema per ADR-0003. DC owns `capture() -> DocumentCollectionState` (returns a new state with `state.collected = _collected.duplicate()` — defensive copy at the value-typed-Array boundary, breaks aliasing with DC's live `_collected`). DC owns `restore(state: DocumentCollectionState)` invoked by MLS's LS callback orchestration (per CR-5 revision); assigns `_collected = state.collected.duplicate()`. **Duplicate-discipline discipline (CLARIFIED, supersedes prior VG-DC-2)**: per Save/Load CR-8 + ADR-0003, the `SaveGame` Resource is `duplicate_deep()`-ed by Save/Load at the boundary BEFORE MLS hands per-system sub-resources to systems. By the time `state` arrives at DC, the outer Resource graph is already isolated. DC's additional `.duplicate()` call on the inner `Array[StringName]` breaks the residual reference between DC's live `_collected` and the throwaway dup's array — sufficient at this nesting depth because `StringName` is value-typed. This aligns with the project-wide "isolate state on load" intent without invoking `Resource.duplicate_deep()` (a Resource-method, not Array-method). **VG-DC-2 retired** — replaced by explicit contract above; no engine verification required.

**CR-7 [MVP]** Sole-publisher discipline (ADR-0002 §183): DC is the **sole publisher** of all 3 Document-domain signals (`document_collected`, `document_opened`, `document_closed`). Every other system is subscriber-only — Document Overlay UI #20, Audio, HSS #19, MLS, Save/Load. Any direct emission from another node violates ADR-0002 and must be caught by code review + the existing project-wide sole-publisher CI lint (per F&R AC-FR-12.4 precedent).

**CR-8 [MVP]** `tr()` discipline + key-only persistence: DC stores ONLY `StringName` keys (`title_key`, `body_key`, `interact_label_key`); DC NEVER calls `tr()` itself. All `tr()` resolution is the responsibility of the rendering subscriber (HUD Core for the prompt label via existing `_compose_prompt_text()`; Document Overlay UI for title + body at VS). DC never holds resolved strings, so DC has no locale-change re-resolution work — that responsibility is delegated to subscribers per ADR-0004 + Localization Scaffold CR-9 (`cached_translation_at_ready` forbidden pattern).

**CR-9 [VS]** Full document roster: 21 `Document` Resources authored across the 5 Tower sections per **§C.5 distribution** (Plaza 3 / Lower 4 / Restaurant 6 / Upper 5 / Bomb 3). Density caps: minimum 2 per section, maximum 6 per section, no two `DocumentBody` collision origins within `interact_min_separation = 0.15 m` (PC E.5 stacked-interactables rule). Off-path ratio: ≥75% off-path / ≤25% on-path narrative-critical (§C.5).

**CR-10 [MVP+VS]** The CR-3(f) idempotency guard is a safety net; CR-5 is the canonical guard. In a healthy build, the CR-3(f) `_collected.has()` check in the pickup handler is unreachable because CR-5 frees collected bodies before they can be raycast. CR-3(f) catches: hot-reload edge cases, save-state corruption fallbacks, and any future regression where CR-5's restore-callback-ordering invariant breaks.

**CR-11 [VS]** `document_opened` / `document_closed` emit-site (DECISION ADOPTED, Option C): DC exposes two public methods called by Document Overlay UI #20:

- `open_document(id: StringName) -> bool` — validates `_collected.has(id)`; if false, `push_error` and return false. Else sets `_open_document_id = id`, emits `Events.document_opened(id)`, returns true.
- `close_document() -> bool` — validates `_open_document_id != &""`; if false, `push_error` and return false. Else sets prior `var closed_id = _open_document_id`; clears `_open_document_id = &""`; emits `Events.document_closed(closed_id)`, returns true.

DC remains the sole publisher of both signals (CR-7); Document Overlay UI is a pure subscriber-renderer that calls these public methods on its UI events.

**CR-12 [VS]** Single-document-open invariant: `_open_document_id` tracks at most one open document. If `open_document(id)` is called while `_open_document_id != &""`, `push_error("document already open: %s" % _open_document_id)` and return false. Document Overlay UI MUST call `close_document()` before opening another. (Edge case E.7 covers session save/load with an open document — the saved game does not persist `_open_document_id`; reopening on load requires explicit user re-action.)

**CR-13 [MVP]** No-quest-counter Pillar 5 absolute: DC does NOT expose `get_collected_count()`, `get_total_count()`, `is_complete()`, `get_completion_percent()`, or any aggregate query method. `_collected.size()` is DC-internal and not part of the public API. Any system that needs an aggregate count reads `DocumentCollectionState.collected` directly from `SaveGame` — DC will not act as a count broker. CI lint enforced (NEW lint rule recommended for AC-DC-12.x).

**CR-14 [MVP]** DC is NOT autoload per ADR-0007. `DocumentCollection extends Node` is instantiated as a child of the section scene at canonical path `Section/Systems/DocumentCollection`. Lifetime = section lifetime; freed when LSS unloads the section. `DocumentCollectionState` is the persistent data object on `SaveGame`; DC itself is ephemeral.

**CR-15 [MVP]** ADR-0008 sub-slot claim: DC has zero per-frame CPU cost (no `_process` / `_physics_process` overrides). Pickup-event cost: ~0.03 ms on Iris Xe (one `is_instance_valid` check + one `is DocumentBody` check + one `Array.append` + one `Events.signal.emit()` + one `call_deferred`). Sub-slot claim: **0.05 ms peak event-frame** from the 0.8 ms ADR-0008 residual pool (shared with CAI 0.30 ms p95 (revised 2026-04-25 from 0.15 ms; civilian-ai.md §F.3 + AC-CAI-7.1), MLS 0.1 ms+0.3 ms peak — DC's claim leaves headroom). **BLOCKING coord item**: ADR-0008 §Pooled Residual must register DC's sub-slot.

**CR-16 [MVP]** Subscriber lifecycle: DC's `_ready()` connects via `Events.player_interacted.connect(_on_player_interacted)`; `_exit_tree()` disconnects via `if Events.player_interacted.is_connected(_on_player_interacted): Events.player_interacted.disconnect(_on_player_interacted)` — ADR-0002 IG3 mandatory pattern. The `_exit_tree()` disconnect MUST run before any `DocumentBody` child is freed (parent disconnects first; godot-feasibility confirms tree-order top-down on `Node.free()` — DC at `Section/Systems/DocumentCollection` is higher than `Section/Documents/`).

**CR-17 [MVP+VS]** Signal handler discipline (ADR-0002 IG4): handler signature `_on_player_interacted(target: Node3D)`. First line `if not is_instance_valid(target): return` (target may be `null` per PC E.5 destroyed-during-reach edge case, or freed-but-non-null). Second line `if not target is DocumentBody: return` (filters non-document interactables — keys, switches, terminals, doors, pickups). Third line: idempotency + collection logic per CR-3.

**CR-18 [MVP]** F&R cancel: if F&R cancels the interact mid-reach (damage ≥ 10 HP per PC E.7), `player_interacted` is NOT emitted. The DocumentBody remains in world. No `document_collected` signal fires. The body's stencil Tier 1 outline continues to advertise its presence. The player must walk back and try again. DC has no special handling for this — it simply doesn't receive the signal.

**CR-19 [MVP+VS]** BQA acronym never-expanded rule (ND-recommended, user-adopted): no document — BQA-authored or PHANTOM-authored — may print the full expansion of "BQA". Letterheads use `BQA — Paris Station`, `BQA Directorate — For Internal Distribution Only`. Personal communications use `the Bureau` / `the Office` / `our people`. PHANTOM intelligence references `BQA (identity of acronym unconfirmed)`. **BLOCKING coord item**: Localization Scaffold authoring guideline must add a content rule "no Localization key may resolve to a string containing 'Bureau of Queen's Affairs' or 'Bureau of Quiet Affairs'"; `/localize` skill audit should grep for violations.

### C.2 — `Document` Resource Schema

| Field | Type | Default | MVP/VS | Notes |
|---|---|---|---|---|
| `id` | `StringName` | required | MVP | Unique mission-wide; snake_case; saved to `DocumentCollectionState.collected` |
| `title_key` | `StringName` | required | MVP | `tr("doc.[id].title")` resolved by Document Overlay UI at render time |
| `body_key` | `StringName` | required | VS | Body content; resolved by Document Overlay UI at render time; not used at MVP (no Overlay ships) |
| `section_id` | `StringName` | required | MVP | Owning section — must match scene's section identifier (CI-validated, §C.5.6) |
| `interact_label_key` | `StringName` | `&"ui.interact.read_document"` | MVP | HUD prompt key; MVP fallback `&"ui.interact.pocket_document"` until Overlay ships |
| `tier_override` | `int` | `-1` | VS | `-1` = default Tier 1 per ADR-0001; reserved for future edge cases (e.g., a damaged document at Tier 3) |

### C.3 — `DocumentBody` Specification

| Property | Value | Notes |
|---|---|---|
| Base node | `StaticBody3D` | NOT `RigidBody3D` (Jolt cost; documents don't tumble) |
| Class name | `DocumentBody` | Single canonical class per project |
| Collision layer | `LAYER_INTERACTABLES` only | ADR-0006; no physics or vision bits |
| Collision shape | `BoxShape3D`, ~0.30 × 0.05 × 0.20 m | Thin paper-shape; 5 cm thick to ensure reliable raycast hit |
| Collision center height | [0.4 m, 1.5 m] off ground | §C.5.4 authoring rule; CI-validated |
| Interact priority | `0` (DOCUMENT) | `get_interact_priority() -> int` returns `0` (highest) |
| Stencil tier | `1` (heaviest, 4 px) | ADR-0001 canonical table; uncollected docs |
| Outline color | Default per Outline Pipeline Tier 1 | DC does NOT override outline color (FP-DC-6) |
| Visible mesh | Per-document `MeshInstance3D` child | Art-director owns visual register (§Visual/Audio) |
| Resource ref | `@export var document: Document` | Required; CI-validated non-null + non-empty id (§C.5.6) |
| Group membership | `&"section_documents"` | DC iterates this group for CR-5 spawn gate |
| `_ready()` cost | ~0 ms | No per-body subscriptions (DC subscribes once at the section level) |

### C.4 — Document Type Taxonomy

| # | Category | Fiction | Authored By | Sections | Work-Shape |
|---|---|---|---|---|---|
| 1 | **Operational Memo** | Typed PHANTOM directive — numbered, dated, named recipients | PHANTOM administration | All; heaviest Upper + Bomb | Bureaucracy issuing orders to subordinates |
| 2 | **Personnel Dossier** | Typed intelligence file on a named subject (BQA agent, target, asset) | PHANTOM intelligence directorate; occasional captured BQA | Lower, Upper | Filed when a subject enters operational scope; Eve's own dossier is canonical instance |
| 3 | **Maintenance Log** | Handwritten / carbon shift record (lifts, scaffolding, electrical) | Tower civilian crew + PHANTOM technicians-in-disguise | Plaza, Lower | Left on clipboards at shift handover; entries trail off |
| 4 | **Service Document** | Reservation list, menu amendment, wine inventory, supplier invoice | Restaurant maître d's office; PHANTOM event coordinator | Restaurant | Restaurant under hostile occupation continues to administer itself |
| 5 | **Telex Transcript** | All-caps teletype, carbon, operator-initialled | PHANTOM Paris cell comms clerk; occasional intercepted BQA | Upper, Bomb | Telexes accumulate in operator's in-tray; latest on top |
| 6 | **Technical Specification** | Engineering schematic annotation, requisition, calibration log | PHANTOM science (Dr. Vogel's people) | Upper, Bomb | Filed when a technical decision needs authorisation |
| 7 | **Personal Communication** | Handwritten note / internal card — unguarded register | Any individual in the Tower | All sections; rarest placement | People leave notes for people; CAP at 4–5 across full roster (overuse collapses comedy) |

### C.5 — Per-Section Roster + Authoring Contract

#### C.5.1 — Per-Section Distribution

| Section | Count | On-Path | Off-Path | Furniture register |
|---|---|---|---|---|
| **Plaza** | 3 | 1 (Security logbook) | 2 | Tourist register desk, security-post clipboard, mounted notice board, brochure stand, guard logbook |
| **Lower Scaffolds** | 4 | 0 | 4 | Crate-clipboards, tool-manifest hooks, pinboard schedules, foreman in-trays, attendance registers, blueprint annotations |
| **Restaurant** | 6 | 1 (Vogel dietary memo) | 5 | Maître d lectern, reservation books, wine ledger, head-waiter in-tray, kitchen rota, service-corridor notice board |
| **Upper Structure** | 5 | 0 | 5 | Comms-console in-tray, observation guestbook, duty-board, lift-operator log, wire-basket paper trays |
| **Bomb Chamber** | 3 | 1 (Detonation telex) | 2 | Operator's in-tray at telex console, command clipboard on operations table, chief scientist's desk in-tray |
| **TOTAL** | **21** | **3 (14%)** | **18 (86%)** | — |

On-path budget = 3/21 ≈ 14% (under the 25% ceiling per LD-recommendation; preserves Pillar 2 absolute).

#### C.5.2 — Per-Section Narrative Arc

> *Institution at rest → at work → under strain → at command → at the edge of its purpose.* What shifts section-by-section is not genre (always a workplace) but the distance between the institution's self-image and what it is actually doing.

- **Plaza** — *Surface Legitimacy*. Civilian Tower paper; PHANTOM hidden behind the venue. Player learns institutional texture before PHANTOM's.
- **Lower Scaffolds** — *Workplace Revealed*. PHANTOM's administrative layer surfaces. Duty roster names roles that don't exist in a legitimate venue. PHANTOM at its most mundanely operational.
- **Restaurant** — *Social Cover as Paperwork*. Operation requires the restaurant to function. Catering invoices, reservations under "Monsieur Vogel," genuine corkage disputes. Apocalypse has a catering coordinator who is very good at her job.
- **Upper Structure** — *Command Paperwork*. Telexes, technical specs, distribution-list memos. Register shifts from administrative to directive. One dossier on a named BQA asset (not Eve) — player doesn't know yet whether they're alive.
- **Bomb Chamber** — *Final Document Set*. 3 documents: operational order, calibration sign-off, detonation telex. Each closes a thread the player has been reading for 2 hours. Player who read everything understands without exposition; player who read nothing can still read these and grasp the situation.

#### C.5.3 — Plaza MVP Tutorial Set

| # | Title (working) | On/Off-Path | Furniture | What it teaches |
|---|---|---|---|---|
| 1 | Security post logbook | **On-path** | Fold-out table at checkpoint, visible from critical path | Interact gesture (look at glowing object, press E, body disappears, no UI counter pops up) |
| 2 | Tourist-desk registration | **Off-path** | Tourist register desk, recessed left of main path, **12–15 m lateral detour** (revised 2026-04-27 per design-review level-designer Finding 2 — must clear F.2 `off_path_min_distance_m = 10.0 m` threshold with margin) | Off-path reward loop; outline shader at distance is a deviation signal |
| 3 | Maintenance-crew clipboard | **Off-path** | Clipboard on crate in service alcove behind parked maintenance van | Environmental literacy; documents read the room not the objective |

#### C.5.4 — Interact-Distance Authoring Rule

| Constraint | Value | Rationale |
|---|---|---|
| Body collision center height (min) | **0.4 m** off ground | Below this requires deliberate crouch; below 0.2 m unreachable even crouching |
| Body collision center height (max) | **1.5 m** off ground | Above this requires direct front approach; 1.6 m+ = unreachable |
| Sweet spot | **0.7–1.1 m** | Desk / in-tray / lectern height |
| Surface offset (max inward) | **≤0.1 m** inside surface normal | Beyond this the raycast misses |
| Surface offset (max proud) | **0.01–0.03 m** proud is acceptable | Helps raycast reliability |
| Inside-closed-geometry | **Forbidden** | Either container is separate TERMINAL-priority interactable, or document is on-surface in open-lid state |

#### C.5.5 — Priority-Stack Authoring Rule

PC interact priority DOCUMENT=0 wins over TERMINAL=1 / PICKUP=2 / DOOR=3 even at greater raycast distance. Authoring discipline:

- **No document body within 0.4 m horizontal of a door interaction volume**. If furniture lives beside a door (clipboard on doorframe), offset the body's CollisionShape3D inward toward the room.
- **No document body within 0.3 m of a PICKUP (WorldItem) CollisionShape3D**. If narrative requires both on the same surface (memo beside a pistol), offset along the surface's major axis.
- **QA pass procedure**: for each document, walk to it from natural approach angle, verify prompt resolves to DOCUMENT not a competing interactable. Then walk to each competing interactable within 3.0 m and verify approach from THAT angle does NOT resolve to the document.

#### C.5.6 — Section-Validation CI Rules (NEW lints, BLOCKING)

| # | Rule | Failure |
|---|---|---|
| 1 | Every body in `&"section_documents"` group has non-null `@export var document: Document` with non-empty `id` | Export null OR id empty StringName |
| 2 | All `document.id` values unique across all 5 section scenes | Duplicate id across mission |
| 3 | `document.section_id` matches scene's section identifier | Plaza body has `section_id = &"restaurant"` |
| 4 | No two `DocumentBody` collision origins within 0.15 m (PC E.5 stacked-interactables) | Distance < 0.15 m |
| 5 | Body `collision_layer` is `LAYER_INTERACTABLES` only (no other bits) | Any extra bit set |
| 6 | Body `CollisionShape3D` global Y center in [0.4, 1.5] m | Outside range |

#### C.5.7 — Per-Section Furniture-Surface Taxonomy (NEW 2026-04-27 per design-review level-designer Finding 7)

Per-section authoring contract: each section scene must include AT LEAST the listed surfaces below, marked with the canonical group tag `&"furniture_surface"` and a `String` `surface_id` metadata key, so that LD walkthroughs and the lint-9 path-distance validator (§E.28) can verify document placements against intended surfaces. **The 3 felt-moment vignettes in §B prescribe specific prop dressings (thermos, pencil, "memo half-tucked under reservations book") that are NARRATIVE-ASPIRATIONAL anchors, not LD-binding** — the geometric authoring contract is below; the prop-dressing vignettes inform set-decoration but do not extend the collision spec (e.g., "half-tucked" stacking is incompatible with §C.3 flat-surface BoxShape3D and is interpreted as a visual mesh decoration, not a separate document body).

**Plaza** (3 docs, registration-furniture register):

| Surface ID | Description | Approx. height (m) | On/Off-path | Max docs | Priority-stack notes |
|---|---|---|---|---|---|
| `&"plaza_security_post"` | Fold-out checkpoint table | 0.75 | On-path | 1 | No PICKUP/DOOR within 0.4 m |
| `&"plaza_tourist_register_desk"` | Recessed counter, fr-style brass-trimmed | 1.05 | Off-path (12–15 m detour) | 1 | Standalone — safe |
| `&"plaza_maintenance_alcove_crate"` | Wood crate behind parked van | 0.85 | Off-path (≥10 m) | 1 | Beware adjacent maintenance van as PICKUP-priority asset |

**Lower Scaffolds** (4 docs, industrial-foreman register):

| Surface ID | Description | Approx. height (m) | On/Off-path | Max docs | Priority-stack notes |
|---|---|---|---|---|---|
| `&"lower_foreman_clipboard_crate"` | Crate-platform with clipboard (anchor for §B Clipboard vignette) | 0.85 | Off-path | 2 (max — separated 0.5 m+ along surface major axis) | — |
| `&"lower_pinboard_main"` | Wall-mounted schedule pinboard | 1.45 | Off-path | 1 | Body collision-center MUST be in lower portion of board (≤1.5 m) per §C.5.4 |
| `&"lower_inspection_bench"` | Inspection-tool bench beside catwalk drop | 1.05 | Off-path | 1 | — |
| `&"lower_attendance_register"` | Standing register at platform handover | 1.15 | Off-path | 1 | — |

**Restaurant** (6 docs, hospitality-administrative register):

| Surface ID | Description | Approx. height (m) | On/Off-path | Max docs | Priority-stack notes |
|---|---|---|---|---|---|
| `&"restaurant_maitre_d_lectern"` | Maître d's reservation lectern (anchor for §B Lectern vignette) | 1.10 | On-path | 1 (Vogel memo) | High DOOR/PICKUP density area — verify priority-stack carefully |
| `&"restaurant_wine_ledger_sommelier"` | Recessed sommelier closet ledger stand | 1.05 | Off-path (≥13 m via service detour) | 1 | — |
| `&"restaurant_head_waiter_intray"` | Head-waiter station tray | 1.05 | Off-path | 1 | — |
| `&"restaurant_kitchen_rota"` | Kitchen pass-through rota board (requires service-corridor route) | 1.45 | Off-path | 1 | **Routing-critical**: kitchen-corridor must be authored as a usable LD route per F.2 multi-strand resolution (§F.2.branch) |
| `&"restaurant_service_corridor_notice"` | Service corridor notice board | 1.40 | Off-path | 1 | Same routing constraint as kitchen rota |
| `&"restaurant_reservation_book_lectern"` | Reservation book on the lectern (NOT same body as Vogel memo — sibling on the same surface, separated ≥0.5 m along lectern axis) | 1.10 | Off-path | 1 | Sibling-on-same-surface case: §C.5.6 lint #4 (0.15 m collision separation) is the floor; authoring rule #5.5 enforces ≥0.5 m along surface major axis |

**Upper Structure** (5 docs, command-paperwork register):

| Surface ID | Description | Approx. height (m) | On/Off-path | Max docs | Priority-stack notes |
|---|---|---|---|---|---|
| `&"upper_comms_console_intray"` | Comms operator paper tray | 1.05 | Off-path | 2 (max — telex + memo, separated ≥0.5 m) | — |
| `&"upper_observation_guestbook"` | Observation deck guestbook lectern | 1.10 | Off-path | 1 | — |
| `&"upper_dutyboard_pinned"` | Wall duty board | 1.45 | Off-path | 1 | Lower-board placement per §C.5.4 |
| `&"upper_lift_operator_log"` | Lift operator stool/log shelf | 0.95 | Off-path | 1 | — |

**Bomb Chamber** (3 docs, operational-final register):

| Surface ID | Description | Approx. height (m) | On/Off-path | Max docs | Priority-stack notes |
|---|---|---|---|---|---|
| `&"bomb_telex_intray"` | Telex console operator's in-tray (anchor for §B Telex vignette) | 1.05 | On-path | 1 (Detonation Telex) | Climax surface — DOCUMENT priority must beat any console TERMINAL interactable |
| `&"bomb_command_clipboard"` | Operations table clipboard | 0.85 | Off-path | 1 | — |
| `&"bomb_chief_scientist_desk"` | Vogel's desk in-tray | 1.05 | Off-path | 1 | — |

**Note on multi-strand critical paths (F.2 branching resolution, NEW §F.2.branch):**

For sections with branching critical paths (Restaurant kitchen vs front-of-house), `path_distance(doc.position, critical_path_spline)` is computed against EACH branch's spline; `is_off_path` = true iff `min(path_distance_to_branch_i for all i) >= off_path_min_distance_m`. CI lint #8 (§E.28) is amended to require ALL branch splines present in section scenes. Per-section ratio enforcement (NEW): AC-DC-10.1 amended to enforce per-section ≥75% off-path AS WELL AS mission-wide ≥18/21.

#### C.5.8 — `DocumentBody.tscn` Canonical Template (NEW 2026-04-27 per design-review level-designer Finding 7)

Tools-Programmer must ship `res://src/gameplay/documents/document_body.tscn` as a save-as-instance template before the MVP authoring sprint begins. Canonical structure:

```
DocumentBody  [StaticBody3D, class_name DocumentBody]
├── collision_layer = LAYER_INTERACTABLES (no other bits)
├── collision_mask = 0
├── @export var document: Document = null  ← LD must populate per body
├── @export var get_interact_priority: int = 0  ← DOCUMENT priority
├── group: &"section_documents" (added in scene)
│
├── CollisionShape3D
│   └── shape = BoxShape3D, size = Vector3(0.30, 0.05, 0.20)
│       (thin paper-shape; orient on placement so Y-axis is paper thickness)
│
└── MeshInstance3D
    └── mesh = (per-category — set in derived scene, NOT in template)
        See §V.1 for the 7-category mesh register.
```

**Template usage rule**: every `DocumentBody` in any section scene MUST be instanced from this template (right-click → Save Branch as Scene → Save as instanced scene). Hand-authored `DocumentBody` nodes that bypass the template are flagged by CI lint #10 (NEW — see §F.5 coord items): scan section scenes for `StaticBody3D` nodes with `script = res://src/gameplay/documents/document_body.gd` whose ancestor is NOT a `PackedScene` instance pointing to the template path.

**Template ownership**: Tools-Programmer creates and maintains. Changes to the template require a §F.5 coord item entry (because every section scene re-uses the template — schema drift breaks all section scenes).

**Workflow**: LD opens section scene → instances template at `Section/Documents/[surface_id]_[doc_short_id]` → assigns `document` export to a `Document.tres` resource → assigns `MeshInstance3D.mesh` to the per-category mesh per §V.1 → adds the body to the `section_documents` group. CI lint validates the template instancing path.

### C.6 — Pickup Lifecycle Pseudocode

```gdscript
# res://src/gameplay/documents/document_collection.gd
class_name DocumentCollection
extends Node

const SECTION_DOCUMENTS_GROUP: StringName = &"section_documents"

var _collected: Array[StringName] = []
var _open_document_id: StringName = &""

func _ready() -> void:
    Events.player_interacted.connect(_on_player_interacted)
    # NOTE: DC does NOT register an LSS step-9 callback (per CR-5 revision 2026-04-27).
    # MLS orchestrates per-system restore within MLS's registered LS callback by
    # calling DC.restore(state) BEFORE LS emits section_entered. See MLS GDD §C.5
    # (post-amendment) for the orchestration contract.

func _exit_tree() -> void:
    if Events.player_interacted.is_connected(_on_player_interacted):
        Events.player_interacted.disconnect(_on_player_interacted)

# Public — invoked by MLS during MLS's LS step-9 callback.
# Combines state restore + spawn-gate in one synchronous call so the gate
# always runs against fresh state, before the section is visible.
func restore(state: DocumentCollectionState) -> void:
    if state == null:
        _collected = []
    else:
        _collected = state.collected.duplicate()  # value-typed StringName array — break aliasing
    _gate_collected_bodies_in_section()

func _gate_collected_bodies_in_section() -> void:
    for body in get_tree().get_nodes_in_group(SECTION_DOCUMENTS_GROUP):
        if not body is DocumentBody:
            continue
        if body.document == null:  # E.15 null-guard
            push_warning("DocumentBody at %s has null document export" % body.get_path())
            continue
        if _collected.has(body.document.id):
            body.queue_free()  # immediate, not deferred — runs before section visible

func _on_player_interacted(target: Node3D) -> void:
    if not is_instance_valid(target):  # ADR-0002 IG4
        return
    if not target is DocumentBody:
        return
    if target.document == null:  # E.15 null-guard (matches spawn-gate symmetry)
        push_warning("DocumentBody at %s has null document export" % target.get_path())
        return
    var doc_id: StringName = target.document.id
    if _collected.has(doc_id):  # CR-3(f) safety net (CR-5 is canonical)
        target.call_deferred("queue_free")
        return
    _collected.append(doc_id)
    Events.document_collected.emit(doc_id)
    target.call_deferred("queue_free")  # VG-DC-1: align Jolt + scene-tree reaping

func capture() -> DocumentCollectionState:
    var state := DocumentCollectionState.new()
    state.collected = _collected.duplicate()  # defensive copy at value-typed-Array boundary
    return state

func open_document(id: StringName) -> bool:
    if not _collected.has(id):
        push_error("open_document: id not collected: %s" % id)
        return false
    if _open_document_id != &"":
        push_error("open_document: already open: %s" % _open_document_id)
        return false
    _open_document_id = id
    Events.document_opened.emit(id)
    return true

func close_document() -> bool:
    if _open_document_id == &"":
        push_error("close_document: no document open")
        return false
    var closed_id := _open_document_id
    _open_document_id = &""
    Events.document_closed.emit(closed_id)
    return true
```

### C.7 — Tonal/Voice Rules (content gates)

These govern the writer brief at `/localize` time and serve as Section C editorial gates for document content.

1. **Bureaucratic euphemism for violence is mandatory.** Lethal acts are passive administrative voice. *"The asset was retired."* / *"The individual proved non-cooperative and required relocation."* / *"Casualty figures were within acceptable operational parameters."* The word "kill" never appears in any PHANTOM document.
2. **Logistics complaints proportional to stakes, not inversely.** Kettle complaint and bioweapon calibration share the same urgency register. The clerk processes the kettle complaint with the same procedural weight as the detonation authorization. This is the engine of the comedy.
3. **Every document has a named recipient and a named author.** Even a one-line handwritten card says "Henri —" at the top and "— R." at the bottom. Player builds a cast of clerks through paper, never meeting them. No document is anonymous.
4. **Period-correct office conventions are visible and never broken.** French date format (14 avril 1965 / 14/04/65), francs not euros, references to PTT (post/telegraph), carbon copy notation ("CC:"), occasional sticking "é" key. No reference to anything requiring a post-1969 world.
5. **Stamps and initials are load-bearing comedy.** Red CONFIDENTIEL stamp slightly crooked. Second initial added in different ink. Routing stamp `TRANSMIS — DIRECTION — REÇU` with dates ticked. The more absurd the content, the more formally it has been processed.
6. **The document never knows it is being read by the wrong person.** No "P.S. I am aware the current operational climate makes this seem trivial." The clerk believes in the kettle complaint. No winking, no self-awareness. The document is utterly sincere.

### C.8 — Forbidden Document Content (content gates)

1. **No document may contain a waypoint, objective marker, or directional instruction.** *"The device is located in the observation platform sub-basement"* is forbidden. Mission Scripting owns objective delivery.
2. **No document may deliver tutorial text.** A document explaining how to pick a lock or trigger a takedown is a tutorial wearing a costume. Forbidden.
3. **No document may require or imply player branching.** Documents are read, not interacted with. Choice presentation belongs to dialogue, not document.
4. **No document may be written in Eve's voice or from Eve's perspective.** Eve's voice belongs to audio barks and cutscenes. Documents reveal the enemy's world.
5. **No voiced document.** Typewriter audio + paper-handling foley only (Audio owns the 3 signal subscribers). No VO reading cue.
6. **No post-1965 technology reference.** No networks, databases, computers, satellites, digital anything. PTT is the long-distance channel. Telex is fastest. Carbon paper is how documents are copied.
7. **No isolated lore-bomb.** A document introducing a major world fact (a second bomb, an unestablished faction) is forbidden unless corroborated by at least one other document or one diegetic environmental cue in the same or adjacent section.

### C.9 — Forbidden Patterns (implementation gates)

| FP | Pattern | Why forbidden |
|---|---|---|
| FP-DC-1 | Hold-E-to-collect mechanic | Modern game affordance; Pillar 5 (no progress rings) |
| FP-DC-2 | "X of Y documents collected" UI counter (HUD, pause menu, loading screen, anywhere) | Pillar 5 absolute; achievement-game register |
| FP-DC-3 | Achievement popup / success notification on first document | Pickup must be as unremarkable as pocketing a key |
| FP-DC-4 | Voice-acted documents (VO reading the body text) | Pillar 1 — page does the comedy, not Eve |
| FP-DC-5 | Floating "?" / "!" markers on uncollected documents | Tier 1 stencil outline is the only affordance; Pillar 5 |
| FP-DC-6 | Extra glow / emission / pulse beyond Tier 1 outline | Outline Pipeline (ADR-0001) is sole visual layer; documents must look like they belong in the room |
| FP-DC-7 | Gameplay-mechanical effects from collecting specific documents (read doc 4 unlocks gadget) | Documents are purely narrative; mechanical consequences belong to MLS |
| FP-DC-8 | Fast-travel / navigation cues in document content | Mission Scripting owns objective delivery |
| FP-DC-9 | Documents spawned at runtime via gameplay events | All documents level-design-time authored; no `spawn_document()` API |
| FP-DC-10 | `document_collected` emitted more than once per id per session | CR-3(f) + CR-5 jointly guarantee one-shot; suppressed on LOAD_FROM_SAVE restore |
| FP-DC-11 | BQA acronym expanded in any document letterhead, body, or stamp | CR-19 — never-expanded rule; Localization key audit enforces |

### C.10 — Interactions Matrix

| System | Direction | Interface |
|---|---|---|
| **Player Character** | DC subscribes | `Events.player_interacted(target: Node3D)` fired post-reach; DC validates `target is DocumentBody` |
| **Player Character** | PC reads DC | `target.get_interact_priority() -> int` returns 0 (DOCUMENT) — resolved by PC `_resolve_interact_target()` |
| **Player Character** | DC defers to PC | PC owns `is_hand_busy()` window suppression (CR-4); F&R-injected interact cancel (CR-18) |
| **HUD Core** | HUD reads DC body | HUD's `_compose_prompt_text()` reads `target.document.interact_label_key` via PC accessor; same as any other interactable |
| **Save/Load** | DC writes / restores | `DC.capture() → DocumentCollectionState` (caller — MLS — calls on FORWARD assembly per MLS CR-15); `DC._on_restore_from_save(state)` via LSS register-restore-callback |
| **Mission & Level Scripting** | MLS authors placement | `documents/` Node3D group in section scenes; per-section Document Resources; CI-validated section authoring rules (§C.5.6) |
| **Mission & Level Scripting** | MLS subscribes to DC | `Events.document_collected(id)` is a valid `completion_signal` for objectives (MLS CR-4 — diegetic completion) |
| **Audio** | Audio subscribes | `document_collected` → pickup SFX 3D at body position; `document_opened` → music duck to DOCUMENT_OVERLAY state; `document_closed` → restore prior state |
| **Document Overlay UI #20** (VS) | Overlay calls DC | `DC.open_document(id)` / `DC.close_document()`; subscribes to `document_opened` / `document_closed` for own render lifecycle |
| **Document Overlay UI #20** (VS) | Overlay reads keys | Document Overlay calls `tr(document.title_key)` / `tr(document.body_key)`; handles `NOTIFICATION_TRANSLATION_CHANGED` for live locale-change |
| **HUD State Signaling #19** (VS) | HSS subscribes | `Events.document_collected(id)` → emits "DOCUMENT COLLECTED: [tr(title_key)]" pickup toast |
| **Outline Pipeline** | DC writes stencil | `DocumentBody` writes Tier 1 (stencil value 1) per ADR-0001; uncollected docs get heaviest 4 px outline |
| **Localization Scaffold** | DC stores keys only | DC NEVER calls `tr()` itself; all string resolution at render-time by subscribers |
| **Settings & Accessibility** | DC indirect | DC has no settings dependency; subscribers (Document Overlay UI, HUD, HSS) own their own setting subscriptions |
| **Failure & Respawn** | DC indirect | F&R cancels PC interact mid-reach; `player_interacted` simply doesn't fire (CR-18); DC handles nothing |
| **Civilian AI** | None | DC and CAI are independent |
| **Stealth AI** | None | Documents do not affect alert state; reading does not break stealth (sepia-dim is overlay's concern, not stealth's) |

### C.11 — Bidirectional Consistency Check

| Other GDD claims | DC GDD position | Status |
|---|---|---|
| ADR-0002 declares 3 Document signals; DC is sole publisher | CR-7 confirms; CR-11 + CR-12 own emit-sites for opened/closed | ✅ aligned |
| ADR-0003 schema `DocumentCollectionState.collected: Array[StringName]` | CR-6 implements verbatim | ✅ aligned |
| ADR-0001 canonical table: uncollected documents = Tier 1 (4 px) | CR-2 + §C.3 confirm | ✅ aligned |
| ADR-0004 `tr()` discipline + locale re-resolution | CR-8 delegates resolution to subscribers; DC stores keys only | ✅ aligned |
| ADR-0006 `LAYER_INTERACTABLES` for interact bodies | §C.3 + CR-2 confirm | ✅ aligned |
| ADR-0007 (DC is not autoload) | CR-14 confirms DC is NOT autoload | ✅ aligned |
| ADR-0008 0.8 ms residual pool shared across 6 systems | CR-15 claims 0.05 ms peak event-frame | **NEW BLOCKING coord** — ADR-0008 §Pooled Residual must register DC |
| PC `_resolve_interact_target()` priority DOCUMENT=0 | CR-2 confirms; §C.5.5 authoring rules avoid priority collisions | ✅ aligned |
| PC `interact_ray_length = 2.0 m` | §C.5.4 authoring rule consumes (height range [0.4, 1.5] m) | ✅ aligned |
| PC fires `player_interacted(target)` post-reach; target may be null | CR-3 + CR-17 handle `is_instance_valid` per ADR-0002 IG4 | ✅ aligned |
| Save/Load LSS `register_restore_callback` is canonical restore path | CR-5 + pseudocode use this pattern | ✅ aligned |
| MLS CR-4 `document_collected` valid as `completion_signal` | §C.10 confirms; DC emits as one-shot per id | ✅ aligned |
| MLS CR-9 section authoring contract — required nodes | §C.5.6 adds 6 NEW lint rules for `documents/` group | **NEW BLOCKING coord** — MLS GDD §C.5 must add these lints |
| Audio §Interactions with Other Systems → Documents domain (audio.md L168-175) subscribes to 3 Document signals | §C.10 confirms Audio is pure subscriber | ✅ aligned |
| Audio §Tuning Knobs (Duck amounts row, audio.md L446-447) `document_overlay_music_db = −10 dB`, `document_overlay_ambient_db = −20 dB` | DC emits the signal; Audio owns the dB values | ✅ aligned |
| Localization `doc.[id].title` / `doc.[id].body` key pattern | CR-1 + CR-8 confirm | ✅ aligned |
| Localization CR-9 forbids `cached_translation_at_ready` | CR-8 delegates to subscribers; DC has no cache to forbid | ✅ aligned |
| Localization Scaffold authoring guideline | CR-19 adds NEW rule: BQA acronym never-expanded | **NEW BLOCKING coord** — Localization Scaffold authoring guideline + new key `ui.interact.pocket_document` |
| Inventory WorldItem priority=2 (PICKUP) | DC priority=0 (DOCUMENT) wins; §C.5.5 authoring rules avoid conflicts | ✅ aligned |
| HUD Core REV-2026-04-26 — pickup toast deferred to HSS #19 (VS) | §C.10 confirms; DC at MVP has no pickup-toast subscriber | ✅ aligned |
| Outline Pipeline ADR-0001 Tier 1 = heaviest | §C.3 confirms | ✅ aligned |
| Document Overlay UI #20 — sibling VS system, owns reading modal | CR-11 + CR-12 + §C.10 confirm DC exposes API; Overlay subscribes | ✅ aligned (forward-dep, Overlay GDD must adopt the contract when authored) |
| HSS #19 — VS pickup toast subscriber | §C.10 confirms; HSS GDD must subscribe `document_collected` when authored | ✅ aligned (forward-dep) |

### C.12 — Coordination Items Emerging from §C

> **Note**: §F.5 is the consolidated authoritative list. This subsection enumerates §C-emerging items only and the totals match. **Updated 2026-04-27 per design-review findings — see §F.5 for full rationale on the new items.**

**7 BLOCKING for MVP sprint:**

1. **MLS GDD §C.5 amendment** — Plaza section scene must include `documents/` Node3D group (group `&"section_documents"`) with 3 pre-authored `DocumentBody` children matching Plaza tutorial set (§C.5.3) AT THE PLAZA SECTION FURNITURE SURFACES per §C.5.7 taxonomy.
2. **ADR-0008 amendment** — register DC's sub-slot claim at 0.05 ms peak event-frame from the 0.8 ms residual pool (joins CAI 0.30 ms p95 (revised 2026-04-25 from 0.15 ms; civilian-ai.md §F.3 + AC-CAI-7.1) / MLS 0.1 ms+0.3 ms peak / F&R / DC).
3. **Localization Scaffold authoring guideline** — add CR-19 BQA-never-expanded content rule + add `ui.interact.pocket_document` translation key (MVP fallback) + add `ui.interact.read_document` (default).
4. **Section-validation CI implementation** — Tools-Programmer must implement 11 new lint rules — see §F.5 item #4.
5. **`DocumentBody.tscn` canonical template** — Tools-Programmer creates `res://src/gameplay/documents/document_body.tscn` per §C.5.8 spec BEFORE LD authoring. NEW per design-review level-designer Finding 7.
6. **Writer Brief deliverable** — Narrative Director + Writer author `design/narrative/document-writer-brief.md` per §F.5 item #9 spec BEFORE VS content authoring sprint. NEW per design-review narrative-director findings 1, 4, 7, 8.
7. **MLS GDD §C.5 amendment (DC restore orchestration)** — MLS adds DC to per-system restore-orchestration list within MLS's registered LS step-9 callback per §F.5 item #10. NEW per design-review godot-specialist findings 1+3.

**3 BLOCKING for VS sprint** (forward-deps that must close before VS sprint can start):

8. **MLS GDD §C.5 amendment (VS expansion)** — full 21-doc roster placement across all 5 sections per §C.5.1 distribution + §C.5.4 interact-distance authoring + §C.5.5 priority-stack authoring + per-section LD walkthrough sign-off (E.30) using §C.5.7 furniture taxonomy as the placement contract.
9. **Document Overlay UI #20 GDD** (when authored) — must adopt `DC.open_document(id)` / `DC.close_document()` consumer pattern + `NOTIFICATION_TRANSLATION_CHANGED` handling for live locale + `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` lifecycle.
10. **HUD State Signaling #19 GDD** (when authored) — must subscribe `Events.document_collected` and emit pickup toast.

**3 ADVISORY (engine verification gates) — VG-DC-2 retired 2026-04-27 per CR-6 revision:**

- **VG-DC-1**: confirm `StaticBody3D.call_deferred("queue_free")` during a signal handler is safe in Jolt 4.6 (deferred body removal queue alignment with scene-tree reaping; no spurious "Body was not in world" warnings)
- **VG-DC-3**: ~~confirm `_ready()` ordering~~ **SUPERSEDED 2026-04-27**: the prior _ready() ordering claim was structurally incorrect (LS callbacks fire at step 9, AFTER add_child step 7). Resolved by CR-5 revision — DC no longer registers its own LS callback; MLS orchestrates. No engine verification needed.
- **VG-DC-4**: confirm `.tres` hot-reload re-sets `@export var document` on `DocumentBody` references in editor; no caching of `document.id` at body `_ready()` time (read through reference at pickup time)
- **ADVISORY-DC-AUD-1** (NEW): `audio.md` clarifies dB semantics — line 95 (state-table absolute targets) vs line 255 (Formula 1 VO-overlay relative offsets). Owner: audio.md author. Target: pre-implementation.

## Formulas

> **Scope statement.** Document Collection is a Narrative/data-layer system with no balance math, no scaling curves, no damage or economy formulas. The only quantitative claims this system makes are: (a) the pickup-event frame-budget composition that bounds CR-15's ADR-0008 sub-slot claim (F.1), and (b) two authoring-time placement constraints — off-path qualification (F.2) and interact-distance feasibility (F.3) — that gate level-design CI lints. Per the systems-designer review, this is correct for the system's layer; DC's design is otherwise specified entirely by predicates inherited from §C Core Rules.

### F.1 — Pickup Event Frame Cost

The pickup event frame-cost composition formula is defined as:

`t_pickup = t_signal_dispatch + t_set_membership + t_array_append + t_signal_emit + t_call_deferred`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Signal dispatch overhead | t_signal_dispatch | float (ms) | [0.005, 0.012] | Cost of `Events.player_interacted` receipt on Iris Xe |
| Set membership test | t_set_membership | float (ms) | [0.001, 0.003] | `_collected.has(id)` lookup; **O(N) linear scan** in Godot 4 `Array.has()` — at N≤25 the per-call cost stays in the cited range; if a Polish-tier Tier 2 mission expands the roster meaningfully (>50 ids), swap `_collected` to a `Dictionary` for O(1) membership. **NOT O(1)** — the prior wording was incorrect (revised 2026-04-27 per design-review performance-analyst Finding 2) |
| Array append | t_array_append | float (ms) | [0.001, 0.002] | `_collected.append(id)` |
| Signal emit + per-subscriber dispatch | t_signal_emit | float (ms) | 0.008 × N_subscribers | `document_collected` emitted to N_subscribers; per-subscriber dispatch ≈ 0.008 ms |
| Deferred free scheduling | t_call_deferred | float (ms) | [0.002, 0.005] | `body.call_deferred("queue_free")` scheduling cost (NOT body-free cost — that runs at idle) |
| Active subscriber count | N_subscribers | int | [1, 6] | Locked at 4 at VS (HUD/HSS prompt-pickup, Audio, MLS objective subscriber, Save/Load passive contributor). Upper bound 6 is a tuning-knob warning threshold (see edge case in §E). |
| Pickup frame cost | t_pickup | float (ms) | [0.025, 0.070] | Total cost on the pickup event-frame only. Steady-state = 0 ms (DC has no `_process` / `_physics_process`). |

**Output Range:** **0 ms steady-state** (no per-frame work); **[0.025, 0.070] ms on the pickup event-frame only assuming N_subscribers ≥ 2**. The stated floor of 0.025 ms is an MVP-and-beyond floor: at MVP with no VS subscribers wired (Audio + MLS only, N=2), mid-range component values yield ≈ 0.025–0.030 ms. At earliest-MVP with N=1 (only Audio subscribed) the formula evaluates to ≈ 0.017–0.030 ms, below the stated floor — that case is acknowledged but not budgeted because it doesn't ship as a stable configuration. At N_subscribers = 6, worst-case t_pickup ≈ 0.070 ms breaches the 0.05 ms sub-slot claim and triggers the §E.32 mitigation (the canonical fix is `CONNECT_DEFERRED` on Audio + HSS subscribers — see §E.32 revision 2026-04-27 — NOT an ADR-0008 amendment).

**Component-source provenance**: the per-component ranges in the table above are **estimates** based on Godot 4.x signal-dispatch typical costs, NOT measurements from a profile run. ADR-0008 itself is currently Proposed (not Accepted), and its Validation Gate 1 (Iris Xe profile pass) is pending. The 0.05 ms sub-slot claim is therefore a **designed budget aspiration**, not a measured ceiling. AC-DC-9.1 verifies the formula arithmetic; physical timing verification awaits ADR-0008 promotion to Accepted via custom `Time.get_ticks_usec()` instrumentation around the pickup handler (see AC-DC-9.4 NEW). **Same-frame quicksave concurrency** (E.8): `capture()`'s `_collected.duplicate()` allocation is uncosted in F.1 and lands in Save/Load's slot; the 8% headroom on the pickup-handler-only path holds, but the combined frame cost when E.8 fires is bounded by Save/Load's ≤10 ms save budget per ADR-0008.

**Example:** N_subscribers = 4 (HUD State Signaling, Audio, Mission Scripting, Save/Load). t_signal_dispatch = 0.008, t_set_membership = 0.002, t_array_append = 0.001, t_signal_emit = 0.008 × 4 = 0.032, t_call_deferred = 0.003. **t_pickup = 0.046 ms** — within the 0.05 ms sub-slot claim with 8% headroom (~0.004 ms — single-frame jitter risk acknowledged; the canonical mitigation is to keep N_subscribers ≤ 5 and use `CONNECT_DEFERRED` on heavy subscribers).

### F.2 — Off-Path Qualification

The off-path qualification formula is defined as:

`is_off_path(doc) = path_distance(doc.position, critical_path_spline) >= off_path_min_distance_m`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Document world position | doc.position | Vector3 | section AABB | World-space origin of the `DocumentBody`'s collision center |
| Minimum path distance | off_path_min_distance_m | float (m) | 10.0 (locked) | MLS-owned constant; minimum horizontal distance from critical-path spline to qualify as off-path. Registry: `off_path_min_distance_m = 10.0 m` |
| Path distance | path_distance(·) | float (m) | [0, unbounded] | Shortest horizontal distance from `doc.position` to the MLS-authored `critical_path_spline` for the section |
| Off-path result | is_off_path | bool | {true, false} | true → document qualifies toward the section's ≥75% off-path ratio (CR-9) |

**Output Range:** Boolean. No clamping. A document exactly at 10.0 m qualifies (`>=`, not `>`). Documents < 10.0 m from the path are on-path; each section may carry at most 25% on-path count.

**Example:** Section = Restaurant (6 documents, ≤1 on-path allowed). A reservation book on the maître d's lectern 3.2 m from the maître d's service line fails: `path_distance = 3.2 < 10.0` → `is_off_path = false`. The Vogel dietary memo at 2.1 m from the same path also fails — and is intentionally placed on-path as the section's narrative-critical document (the Restaurant's allowed on-path slot per §C.5.1). A wine-ledger placed in the recessed sommelier closet 13.4 m off-path passes: `13.4 >= 10.0` → `is_off_path = true`.

### F.3 — Interact-Distance Feasibility

The interact-distance feasibility formula is defined as:

`is_reachable(doc) = (body.center_y >= h_min) AND (body.center_y <= h_max) AND (placement_ray_distance <= player_interact_ray_length)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `DocumentBody` collision center height | body.center_y | float (m) | authoring constraint [0.4, 1.5] | Y-component of `StaticBody3D` `CollisionShape3D` center in section-local space; values outside [0.4, 1.5] fail CI lint per §C.5.6 #6 |
| Minimum feasible height | h_min | float (m) | 0.4 (locked) | Below this the interact ray overshoots unless player crouches; §C.5.4 locked constant |
| Maximum feasible height | h_max | float (m) | 1.5 (locked) | Above this the standing ray undershoots; §C.5.4 locked constant |
| Authoring-time ray distance | placement_ray_distance | float (m) | (0, 2.0] | Straight-line distance from Eve's standing eye-height (camera Y=1.6 m) to `body.center` at the closest intended approach point; measured in editor during level-design placement walkthrough |
| Player interact ray length | player_interact_ray_length | float (m) | 2.0 (locked) | PC-owned constant. Registry: `player_interact_ray_length = 2.0 m` |
| Reachable result | is_reachable | bool | {true, false} | true → `DocumentBody` is interactable at normal approach. CI lint verifies the height sub-expression; level-designer verifies the ray-distance sub-expression in-editor (not automatable from scene metadata alone) |

**Output Range:** Boolean. Composed of two independent sub-constraints. Either can independently fail. The height sub-expression is CI-automatable (lint on scene import per §C.5.6 #6). The ray-distance sub-expression requires editor walkthrough by the level-designer.

**Example:** A maintenance clipboard placed on a crate in Lower Scaffolds: `body.center_y = 0.85 m` (within [0.4, 1.5] ✓), `placement_ray_distance = 1.4 m` (≤ 2.0 ✓) → `is_reachable = true`. A telex machine mounted on a high console in Upper Structure: `body.center_y = 1.8 m` → fails height sub-expression → `is_reachable = false` → §C.5.6 lint #6 fires; level-designer must lower the body's collision center or reposition the document onto a reachable surface (the telex paper-tray sitting in front of the console at 1.0 m height passes).

## Edge Cases

### Cluster A — Same-frame / lifecycle storms

- **E.1** *Multiple documents in raycast cone same frame*: PC `_resolve_interact_target()` priority resolver returns the highest-priority body; with all candidates at DOCUMENT=0, ties break by squared ray-distance from camera origin (PC F.5, deterministic). **Resolution**: nearer document wins. Authoring rule §C.5.5 minimum 0.15 m separation prevents identical-distance ties.
- **E.2** *Player presses E twice within reach window* (CR-4): PC `is_hand_busy()` suppresses second press at PC level. **Resolution**: only one `player_interacted` fires; one `document_collected` emits.
- **E.3** *Pickup + section-transition same frame*: player presses E on a document at exactly the moment LSS fires `section_exited`. PC reach completes during the 33 ms snap-out fade window (LSS 2-frame hard-cut). `player_interacted` fires; DC subscriber appends id, emits `document_collected`, calls `body.call_deferred("queue_free")`. LSS then unloads the section; DC's `_exit_tree()` disconnects; the deferred queue_free runs against an already-freeing body — `call_deferred("queue_free")` on a node already being freed is a Godot-safe no-op. **Resolution**: id is collected (saved on next FORWARD autosave), body cleanup is benign. No crash.
- **E.4** *F&R cancels interact mid-reach* (CR-18): damage ≥ 10 HP within the reach window; PC cancels the tween, does NOT emit `player_interacted`. **Resolution**: body remains in world; `_collected` unchanged; `document_collected` does NOT fire. Player walks back to retry. Pillar 3-aligned (failure not punishment).
- **E.5** *Two distinct documents picked up in 60 frames* (rapid-fire reading-room moment): both pickups complete sequentially. **Resolution**: `_collected` grows by 2; `document_collected` fires twice with distinct ids. Subscribers (Audio, HSS, MLS) handle each independently. Audio's pooled 3D pickup SFX may overlap; Audio handles voice-stealing per its own pool config.
- **E.6** *Player presses E during ladder-climb / cutscene / loading*: PC's InputContext gating prevents `player_interacted` emission outside `GAMEPLAY` context. **Resolution**: input is silently swallowed (Input GDD context-gating); DC never receives the signal; nothing happens.

### Cluster B — Save/Load

- **E.7** *Save during pickup reach* (mid-tween, signal not yet emitted): MLS calls `DC.capture()` for the FORWARD autosave; `_collected` does not yet contain the in-progress pickup id. **Resolution**: save reflects pre-pickup state. On load, the body re-spawns active; player must re-pickup. Acceptable (the player can choose to re-collect; document is unchanged). This is the canonical Pillar 3 behavior — save/load is honest about what was actually collected.
- **E.8** *Save immediately after pickup*: `document_collected` already fired, `_collected` contains the id, body is `call_deferred`-freed but autosave runs in the same frame (FORWARD on `section_entered` — but pickup wouldn't trigger `section_entered`, so this only happens via Quicksave F5). **Resolution**: save captures post-pickup state; body absent on load; intended.
- **E.9** *Load with documents already collected in current section*: CR-5 spawn-gate runs after restore-callback applies state; iterates `&"section_documents"` group; frees bodies whose id is in `_collected`. **Resolution**: bodies absent on first frame after load — player never sees them.
- **E.10** *Load with documents NOT yet collected in current section*: CR-5 finds no match; bodies remain active; outline shader marks them. **Resolution**: intended; player can collect normally.
- **E.11** *Corrupt `_collected` contains an id not present in any section's `Document.id`*: extra id is benign — DC just holds it in `Array[StringName]`, no body is freed, no consequence. **Resolution**: defensive; no crash, no error log. Pillar 2: missed documents are texture, not failure — extra-but-unused ids are also texture.
- **E.12** *Save with `_open_document_id` set* (Document Overlay open at quicksave time): `_open_document_id` is NOT persisted in `DocumentCollectionState` (schema is collected-only per CR-6). On load, `_open_document_id == &""` (default), Overlay is closed. **Resolution**: Overlay's UI is not auto-restored on load; player must explicitly re-open the document via the case-file archive (Polish-or-later) or replay the section. Acceptable VS-tier behavior.
- **E.13** *Save format version mismatch on `DocumentCollectionState`*: per ADR-0003 refuse-load-on-mismatch. **Resolution**: `Events.save_failed(VERSION_MISMATCH)` fires; Menu System shows the dialog; player starts new game. The corrupt slot remains visible and overwriteable. Documented ADR-0003 trade-off.

### Cluster C — Section-load + spawn-gate authoring

- **E.14** *Section loads without `documents/` group node* (LD authoring error): `get_tree().get_nodes_in_group(&"section_documents")` returns empty; CR-5 spawn-gate is a no-op. **Resolution**: no documents in section; CI lint at build time catches the missing group; at runtime, no crash.
- **E.15** *Section contains malformed `DocumentBody` with null `@export var document`*: CR-5 iterates the group but `body.document` is null; reading `body.document.id` would crash. **Resolution**: CR-5 must guard `if body.document == null: continue` (folded into pseudocode addendum). CI lint per §C.5.6 #1 catches at build time. Runtime push_warning surfaces silent priority inversion.
- **E.16** *Section contains duplicate `document.id` across two bodies* (CI lint per §C.5.6 #2 catches). At runtime if shipped: CR-5 frees both bodies if id is in `_collected`; if not in `_collected`, both remain active; pickup of either body appends id once due to CR-3(f) idempotency check; subsequent pickup of the other body finds id already in `_collected`, calls `call_deferred("queue_free")` on it without re-emitting `document_collected` (CR-3(f) early-return path). **Resolution**: duplicate-id is benign at runtime; `document_collected` emits exactly once.
- **E.17** *Section contains `documents/` group but no `DocumentCollection` system node at `Section/Systems/DocumentCollection`* (LD authoring error): bodies remain active but no subscriber processes `player_interacted` for `DocumentBody` targets. Press E does nothing. **Resolution**: CI lint must verify presence of `DocumentCollection` system node when `documents/` group is non-empty. **NEW lint rule** (added to §C.5.6 list as #7 in §F coord items).
- **E.18** *Hot-reload of `Document.tres` while game is running* (developer iteration in editor): Godot 4.6 re-sets `@export var document` on the body node per VG-DC-4. **Resolution**: bodies pick up the new resource; if `id` field changed, CR-5's spawn-gate may now diverge from `_collected`. Developer-only edge case; acceptable to require game reload after `.tres` edit. Document in dev-guide.

### Cluster D — Locale + `tr()` lifecycle

- **E.19** *Locale changes while no document is open*: DC unaffected (stores keys only). HUD prompt strip re-resolves on `NOTIFICATION_TRANSLATION_CHANGED` per HUD CR-18. **Resolution**: no DC work; subscribers handle.
- **E.20** *Locale changes while document is open in Document Overlay UI #20* (VS): Overlay's `NOTIFICATION_TRANSLATION_CHANGED` handler re-resolves `tr(title_key)` and `tr(body_key)`; DC has no role. **Resolution**: live-locale switch refreshes overlay text; word-wrap may re-flow per Localization Scaffold per-locale character limits.
- **E.21** *Player picks up document during locale change*: pickup completes, `document_collected` fires with id (locale-independent); HSS pickup toast (VS) calls `tr(title_key)` at toast-render time using the new locale. **Resolution**: toast text reflects new locale; intended.

### Cluster E — Open / Close lifecycle (VS)

- **E.22** *`open_document(id)` for id not in `_collected`*: CR-11 push_error returns false. **Resolution**: Overlay UI surface (when authored) handles false return by suppressing the open animation; user-facing dialog if desired. DC enforces preconditions only.
- **E.23** *`open_document(id)` while `_open_document_id != &""`*: CR-12 push_error returns false. **Resolution**: Overlay must call `close_document()` first. If Overlay UI's UX guarantees one-document-at-a-time (button only visible for one document), this is dead-letter defensive.
- **E.24** *`close_document()` with no document open*: CR-11 push_error returns false. **Resolution**: defensive; happens if Overlay sends close twice or if save/load races a close.
- **E.25** *Player picks up new document while another is open* (VS — Overlay subscribed): the player must close the current Overlay first via `ui_cancel`. Pickup itself is unaffected — `document_collected` fires on pickup, `_collected` updates, body frees. The currently-open document remains open. **Resolution**: pickup and open are independent operations; no interlock at DC level.

### Cluster F — DC subscriber lifecycle

- **E.26** *DC's `_exit_tree()` runs during section unload while `player_interacted` is mid-dispatch* (theoretical race): Godot dispatches signals synchronously; once `_exit_tree()` runs, `is_connected()` returns false; subsequent `disconnect()` is safe. **Resolution**: ADR-0002 IG3 pattern handles; no crash. Tree-order top-down on `Node.free()` ensures DC disconnects before child `DocumentBody` nodes are freed (godot-feasibility VG-DC-3).
- **E.27** *`DocumentBody` is freed during the pickup handler* (mid-handler invalidation): theoretical only — single-threaded GDScript dispatch means no other code runs between handler steps. CR-17 `is_instance_valid(target)` opens the handler defensively per ADR-0002 IG4. **Resolution**: never observed in practice; defensive guard suffices.

### Cluster G — Authoring violations + engine verification gates

- **E.28** *F.2 path_distance undefined: section authored without `critical_path_spline` node*: F.2 `is_off_path(doc)` is undefined for all documents in the section. CI lint must require a `&"critical_path"` node present in every section scene before DC document placement passes validation. **Resolution**: **NEW CI lint** added to §C.5.6 list as item #8 (in §F coord items). Without the lint, off-path ratio enforcement (CR-9) cannot be machine-verified.
- **E.29** *F.3 height-out-of-range body authored*: `body.center_y < 0.4` or `body.center_y > 1.5`. The body exists but is unreachable by interact ray. **Resolution**: CI lint per §C.5.6 #6 fires at build import; build fails. Game does NOT silently suppress unreachable documents (a missing document is worse than a broken build for narrative integrity per Pillar 2). LD must reposition.
- **E.30** *F.3 `placement_ray_distance > 2.0` (not CI-detectable)*: only the level-designer's editor walkthrough catches this. **Resolution**: LD sign-off checklist for each section MUST include a per-document walkthrough verifying interact resolves to DOCUMENT from the natural approach angle. Surface in §F as authoring contract item.
- **E.31** *F.2 + F.3 simultaneous failures*: a document can be both unreachable and on-path. **Resolution**: independent CI failures; both must resolve before merge. Failing F.3 does not excuse failing F.2 and vice-versa.
- **E.32** *F.1 N_subscribers grows to ≥ 6* (new system subscribes to `document_collected`): worst-case `t_pickup` ≈ 0.070 ms, breaches the 0.05 ms ADR-0008 sub-slot claim. **Resolution**: any new subscriber to `document_collected` triggers an ADR-0008 amendment review before the subscribing system ships. Not a runtime error, but a coord-item gate on system #6+. Surface in §F.

### Cluster H — Pillar violations / coord enforcement

- **E.33** *Document content contains BQA acronym expansion* (CR-19 violation): "Bureau of Queen's Affairs" appears in a translation key body. **Resolution**: Localization audit (`/localize` skill) greps for both expansions on every CSV change; build fails on hit. Surface as §F coord item with Localization Scaffold.
- **E.34** *A new system attempts to `Events.document_collected.emit(...)` directly* (CR-7 sole-publisher violation): code review + the existing project-wide sole-publisher CI lint (per F&R AC-FR-12.4 precedent) catches at PR time. **Resolution**: PR blocked; refactor to call `DC` API. Same enforcement as F&R/Inventory/HUD.
- **E.35** *A new system queries `DC.get_collected_count()`* (CR-13 absolute violation): method does not exist; type-check fails at compile time. CI grep can additionally scan for any such pattern (`get_collected_count`, `is_complete`, `get_total_count`) across the codebase. **Resolution**: compile error blocks; refactor to read `DocumentCollectionState.collected` directly from `SaveGame` if a count is genuinely needed.

## Dependencies

### F.1 — Upstream Dependencies (Hard)

| System | Nature | Contract |
|---|---|---|
| **Player Character** ✅ | Hard | DC subscribes to `Events.player_interacted(target: Node3D)`; PC's `_resolve_interact_target()` returns `DocumentBody` first via priority=0; `interact_ray_length = 2.0 m`; PC's `is_hand_busy()` window suppresses re-press; F&R-injected interact cancel terminates the reach without emit |
| **Save/Load** ✅ | Hard | DC owns `capture() → DocumentCollectionState`; restored via `LevelStreamingService.register_restore_callback(_on_restore_from_save)` per LS CR-10 (NOT direct `Events.game_loaded` subscription); DC is passive contributor on the FORWARD SaveGame assembled by MLS CR-15 |
| **Localization Scaffold** ✅ | Hard | DC stores `StringName` keys only (`doc.[id].title`, `doc.[id].body`, `ui.interact.read_document`, `ui.interact.pocket_document`); never calls `tr()` itself; subscribers handle `NOTIFICATION_TRANSLATION_CHANGED` re-resolve per ADR-0004 + Localization Scaffold CR-9 |
| **Outline Pipeline** ✅ | Hard | DC writes stencil Tier 1 (4 px @ 1080p) on uncollected `DocumentBody`; outline shader reads stencil per ADR-0001 — DC consumes the contract, doesn't define it |
| **ADR-0001 (Stencil ID Contract)** | Hard architectural | Tier 1 = heaviest 4 px outline for uncollected documents (canonical table cites Document Collection by name) |
| **ADR-0002 (Signal Bus + Event Taxonomy)** | Hard architectural | DC is sole publisher of 3 frozen Documents-domain signals; subscribes to `player_interacted`; ADR-0002 IG3 (connect/disconnect lifecycle) + IG4 (`is_instance_valid` Node payloads) mandatory |
| **ADR-0003 (Save Format Contract)** | Hard architectural | `DocumentCollectionState extends Resource` with `@export var collected: Array[StringName]` — frozen schema; `duplicate()` discipline on load; Save/Load is sole writer of the file, MLS is sole assembler |
| **ADR-0004 (UI Framework)** | Hard architectural | `tr()` discipline (DC delegates resolution to subscribers); theme inheritance (DC has no UI surface — no theme requirement); `hardcoded_visible_string` forbidden (DC has zero visible strings, so trivially compliant) |
| **ADR-0006 (Collision Layer Contract)** | Hard architectural | `LAYER_INTERACTABLES` for `DocumentBody`; no other layer bits; PC raycast scans this layer exclusively |
| **ADR-0007 (Autoload Registry)** | Hard architectural | DC is NOT autoload per ADR-0007. DC lives as scene-rooted node at `Section/Systems/DocumentCollection` |
| **ADR-0008 (Performance Budget Distribution)** | Hard architectural | DC claims 0 ms steady-state + 0.05 ms peak event-frame from the 0.8 ms residual pool. **NEW BLOCKING coord item: ADR-0008 §Pooled Residual must register DC's sub-slot.** |

### F.2 — Upstream Dependencies (Soft)

| System | Nature | Contract |
|---|---|---|
| **Mission & Level Scripting** ✅ | Soft authoring | MLS owns the section authoring contract — `documents/` Node3D group in section scenes + per-section Document Resources + 8 NEW CI lints (§C.5.6 #1–6 + §E.17 #7 + §E.28 #8). MLS does NOT execute DC — it provides the spawned-content tree |
| **Failure & Respawn** ✅ | Soft mediated | F&R may cancel PC interact mid-reach if damage ≥ 10 HP per PC E.7 + CR-18; PC is the mediator — DC has no direct F&R dep, simply doesn't receive the signal |
| **Level Streaming Service** ✅ | Soft mediated | LS CR-10 owns the `register_restore_callback` pattern that DC uses for save-restore. LS handles the section-load fade and the 33 ms snap-out window during which `_exit_tree()` runs |
| **Input GDD** | Soft mediated | PC owns input; Input GDD owns `InputContext.GAMEPLAY` gating that prevents `player_interacted` outside gameplay context (E.6) |

### F.3 — Downstream Dependents

| System | Status | Direction | Contract |
|---|---|---|---|
| **Audio** ✅ | Designed | Audio subscribes | All 3 Document signals: `document_collected` → pickup SFX 3D at body position (~300 ms); `document_opened` → music duck to DOCUMENT_OVERLAY state (-10 dB / -20 dB additional); `document_closed` → restore prior music state |
| **Mission & Level Scripting** ✅ | Designed | MLS subscribes | `Events.document_collected(id)` is a valid `completion_signal` for objectives per MLS CR-4 (diegetic completion); MLS subscribes when an objective's `completion_signal` is configured to this |
| **Save/Load** ✅ | Designed | Save/Load consumes | DC's `DocumentCollectionState` is one of 6 typed Resources on `SaveGame`; Save/Load is sole file I/O; DC contributes via `capture()` called by MLS on FORWARD assembly |
| **HUD Core** ✅ | Designed | HUD reads via PC accessor | HUD's `_compose_prompt_text()` reads `target.document.interact_label_key` via `pc.get_current_interact_target()`; HUD treats `DocumentBody` like any other interactable — no DC-specific subscription |
| **HUD State Signaling #19** | VS, Not Started | HSS subscribes | `Events.document_collected(id)` → emits "DOCUMENT COLLECTED: [tr(title_key)]" pickup toast (VS); HUD Core MVP does NOT include pickup toast. **NEW BLOCKING coord item for VS sprint: HSS GDD when authored must subscribe `document_collected`** |
| **Document Overlay UI #20** | VS, Not Started | Overlay calls + subscribes | Calls `DC.open_document(id)` / `DC.close_document()` on UI events; subscribes to `document_opened` / `document_closed` for own render lifecycle; calls `tr(title_key)` / `tr(body_key)` and handles `NOTIFICATION_TRANSLATION_CHANGED`; calls `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` per ADR-0004. **NEW BLOCKING coord item for VS sprint: Overlay GDD when authored must adopt this contract** |

### F.4 — Forbidden Non-Dependencies

DC must NEVER take direct dependencies on the following — listed here so future agents do not introduce coupling:

| System | Why forbidden |
|---|---|
| **Stealth AI** | Documents do not affect alert state. Reading does not break stealth. SAI has no role in pickup or open/close lifecycle. |
| **Combat & Damage** | Documents are not weapons. `DocumentBody` is not a damageable target. F&R-mediated cancel is the only Combat-adjacent interaction (PC handles). |
| **Civilian AI** | Documents do not interact with civilians. CAI has its own panic/witness systems orthogonal to DC. |
| **Inventory & Gadgets** | Documents and `WorldItem` pickups are independent priority levels (DOCUMENT=0 vs PICKUP=2); DC is NOT an Inventory subsystem; pocketed documents are NOT in `InventoryState`. |
| **Settings & Accessibility** | DC has no settings. Subscribers (Document Overlay UI, HSS) own their own setting subscriptions if needed. |
| **Menu System** | DC does not interact with Main Menu / Pause Menu. Document Overlay UI #20 is a separate VS surface; the case-file archive (Polish-or-later) would integrate with Pause Menu but is NOT part of DC. |
| **Post-Process Stack** | Document Overlay UI calls `enable_sepia_dim()` / `disable_sepia_dim()` — NOT DC. PPS subscribes to no DC signals. |
| **Cutscenes & Mission Cards** | Documents are read in-game in the Document Overlay (VS); not part of cutscene flow. |
| **Outline Pipeline (runtime)** | DC writes the stencil tier value at body authoring time; the outline shader reads it. DC does NOT call any Outline Pipeline runtime API. |

### F.5 — Coordination Items (Pre-Implementation Gates)

Consolidated from §C.12 + §E.

**7 BLOCKING for MVP sprint** (revised 2026-04-27 from 4 — added items 5, 6, 7 per design-review):

1. **MLS GDD §C.5 amendment (Plaza authoring + restore orchestration)** — Plaza section scene must include `documents/` Node3D group (group `&"section_documents"`) with 3 pre-authored `DocumentBody` children matching the Plaza tutorial set (§C.5.3: Security post logbook on-path + Tourist-desk register at 12–15 m off-path + Maintenance-crew clipboard off-path) — placed at the §C.5.7 furniture taxonomy surfaces. **Plus**: MLS adds DC to per-system restore-orchestration list within MLS's registered LS step-9 callback per CR-5 revision: MLS's callback receives `(target_id, save_game, reason)`; MLS calls `dc.restore(save_game.documents)` BEFORE LS emits `section_entered`. DC's `restore()` runs the spawn-gate immediately after applying state. NEW restore-orchestration sub-item 2026-04-27 per design-review godot-specialist Findings 1+3.
2. **ADR-0008 amendment** — register DC's sub-slot claim at 0.05 ms peak event-frame from the 0.8 ms residual pool. Joins CAI 0.30 ms p95 (revised 2026-04-25 from 0.15 ms; civilian-ai.md §F.3 + AC-CAI-7.1) / MLS 0.1 ms+0.3 ms peak / F&R / DC.
3. **Localization Scaffold authoring guideline** — add CR-19 BQA-never-expanded content rule (`/localize` skill greps both expansions on every CSV change AND across all locale files — not English-only per qa-lead Finding 18); add `ui.interact.pocket_document` translation key (MVP fallback); add `ui.interact.read_document` translation key (default for VS).
4. **Section-validation CI implementation** — Tools-Programmer must implement **11 new lint rules**: §C.5.6 #1-6 (six body-authoring lints) + §E.17 #7 (DocumentCollection presence) + §E.28 #8 (critical_path_spline presence) + AC-DC-1.4 #9 (per-section/total cross-constraint invariants per §G.1.cross) + AC-DC-1.5 #10 (DocumentBody.tscn template-instance only — see §C.5.8) + H.13 GAP-1 #11 (no-quest-counter aggregate-method grep — `get_collected_count` / `get_total_count` / `is_complete` / `get_completion_percent`). Lint ownership joins the existing MLS section-validation CI (per MLS coord item #9). **Updated 2026-04-27 from "8 lints" → "11 lints" per design-review.**
5. **`DocumentBody.tscn` canonical template** — Tools-Programmer must create `res://src/gameplay/documents/document_body.tscn` per §C.5.8 spec BEFORE LD authoring begins. Canonical structure: StaticBody3D root with class_name DocumentBody, LAYER_INTERACTABLES collision_layer, BoxShape3D 0.30×0.05×0.20 m CollisionShape3D child, MeshInstance3D child (mesh assigned in derived/instanced scenes per §V.1 category register), `@export var document: Document = null`, `@export interact_priority = 0`. Owner: Tools-Programmer. Target: pre-MVP-sprint; blocks LD authoring of any `DocumentBody`. NEW 2026-04-27 per design-review level-designer Finding 7.
6. **Writer Brief deliverable** — Narrative Director + Writer must author `design/narrative/document-writer-brief.md` BEFORE any document content beyond the Plaza MVP set is authored. Must include: ≥1 fully-drafted sample document per category (7 samples covering §C.4 type taxonomy), voice exemplar paragraph for each of the 5 sections, named-clerk cast (≥6 named PHANTOM clerks + ≥3 BQA correspondents) with role/tone notes per character, contradiction-policy rule + canonical-fact registry section, BQA-register guide (per CR-19 expansion ban), per-document closing-cross-reference matrix for the Bomb Chamber 3-doc climax (§C.5.2 closing claim). Owner: Narrative Director (drafting) + Writer (authoring). Target: BEFORE VS content authoring sprint kickoff. NEW 2026-04-27 per design-review narrative-director Findings 1, 4, 7, 8. **First version authored as part of this design-review revision pass — see `design/narrative/document-writer-brief.md`.**
7. **`audio.md` dB-semantic clarification (ADVISORY-DC-AUD-1 promotion)** — `audio.md` author must clarify the absolute-target vs relative-offset semantic between state-table line 95 (DOCUMENT_OVERLAY -10 dB / -20 dB absolute) and Formula 1 line 255 (DOCUMENT_OVERLAY -8 dB additional VO-duck relative). DC consumes line 95 semantics; line 255 is layered on top during VO-mid-overlay events. Owner: `audio.md` author. Target: before MVP integration tests. NEW 2026-04-27 per design-review audio-director Finding 2.

**3 BLOCKING for VS sprint** (forward-deps that must close before VS sprint can start):

8. **MLS GDD §C.5 amendment (VS expansion)** — full 21-doc roster placement across all 5 sections per §C.5.1 distribution + §C.5.4 interact-distance authoring + §C.5.5 priority-stack authoring + §C.5.7 furniture-taxonomy surface assignment + §F.2.branch multi-strand path-distance computation for Restaurant kitchen-vs-front-of-house + per-section LD walkthrough sign-off (E.30).
9. **Document Overlay UI #20 GDD** (when authored) — must adopt `DC.open_document(id)` / `DC.close_document()` consumer pattern + `NOTIFICATION_TRANSLATION_CHANGED` handling for live locale change (E.20) + `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` lifecycle.
10. **HUD State Signaling #19 GDD** (when authored) — must subscribe `Events.document_collected` and emit pickup toast "DOCUMENT COLLECTED: [tr(title_key)]" with reduced-motion + locale-change re-resolution discipline.

**ADVISORY (revised 2026-04-27 per design-review — VG-DC-2 + VG-DC-3 retired, ADVISORY-DC-AUD-1 promoted to BLOCKING #7, new advisories added):**

- **VG-DC-1**: confirm `StaticBody3D.call_deferred("queue_free")` during a signal handler is safe in Jolt 4.6 (deferred body removal queue alignment with scene-tree reaping; no spurious "Body was not in world" warnings)
- ~~**VG-DC-2**~~: **RETIRED 2026-04-27** — replaced by explicit duplicate-discipline contract in CR-6 revision (Save/Load duplicate_deep at boundary + DC's value-typed Array[StringName].duplicate() at inner copy). No engine verification needed.
- ~~**VG-DC-3**~~: **RETIRED 2026-04-27** — the prior `_ready()` ordering claim was structurally wrong (LS callbacks fire at step 9, AFTER add_child step 7). Resolved by CR-5 revision: DC no longer registers its own LS callback; MLS orchestrates restore via `dc.restore(state)` call.
- **VG-DC-4**: confirm `.tres` hot-reload re-sets `@export var document` on `DocumentBody` references in editor; no caching of `document.id` at body `_ready()` time
- **N_subscribers ADR-0008 review trigger** (E.32 revised): if a 6th system subscribes to `document_collected`, worst-case `t_pickup` ≈ 0.070 ms breaches the 0.05 ms claim. **Canonical mitigation (NEW 2026-04-27 per design-review performance-analyst Finding 5)**: apply `CONNECT_DEFERRED` to high-cost subscribers (Audio, HSS) — moves their handler off the pickup event-frame and restores per-frame headroom. Amending ADR-0008 to raise the budget cap is NOT the right mitigation (treats accounting, not latency). ADR-0008 amendment is reserved for cases where deferred connection introduces unacceptable user-perceived latency (e.g., visible delay on pickup SFX cue).
- **ADVISORY-AUDIO-CLUSTER-1** (E.5 stress test, NEW 2026-04-27 per audio-director Finding 8): rapid-fire 2-pickup voice-stealing under audio.md's 16-slot SFX pool — verify Audio's DC pickup SFX has explicit steal-priority below combat SFX so that two pickup events within 60 frames both complete. Owner: audio.md (revision pass) + audio QA at MVP smoke-check.
- **ADVISORY-PERF-MEASUREMENT-1** (NEW 2026-04-27 per performance-analyst Finding 8): define and ship a `Time.get_ticks_usec()` instrumentation harness around `_on_player_interacted` for AC-DC-9.4. Without this harness, AC-DC-9.4 cannot pass and ADR-0008 cannot be promoted from Proposed to Accepted. Owner: gameplay-programmer + ADR-0008 author.

### F.6 — Bidirectional Consistency Check (master)

This consolidates §C.11 + adds checks for §D/§E/§F-emerging contracts. Status legend: ✅ aligned / ⚠ needs amendment / 🔴 conflict.

| Other GDD or ADR claim | DC GDD position | Status |
|---|---|---|
| ADR-0002 §Documents domain — 3 frozen signals | CR-7 sole-publisher; CR-11 + CR-12 emit-sites | ✅ |
| ADR-0003 §SaveGame `documents: DocumentCollectionState` | CR-6 schema match (`collected: Array[StringName]`) | ✅ |
| ADR-0001 canonical table — uncollected docs Tier 1 | CR-2 + §C.3 | ✅ |
| ADR-0004 `tr()` discipline + theme inheritance | CR-8 delegates; DC has no UI | ✅ |
| ADR-0006 `LAYER_INTERACTABLES` for interact bodies | §C.3 + CR-2 | ✅ |
| ADR-0007 (DC is not autoload) | CR-14 — DC is NOT autoload | ✅ |
| ADR-0008 0.8 ms residual pool — 6-system shared | CR-15 claims 0.05 ms peak event-frame | ⚠ **NEW BLOCKING** — §F.5 item #2 |
| PC `_resolve_interact_target()` priority DOCUMENT=0 | CR-2 | ✅ |
| PC `interact_ray_length = 2.0 m` | §C.5.4 + F.3 (`is_reachable`) | ✅ |
| PC fires `player_interacted(target)` post-reach | CR-3 + CR-17 with `is_instance_valid` | ✅ |
| PC F.5 stacked-interactables `interact_min_separation = 0.15 m` | §C.5.6 lint #4 + §C.5.5 authoring rule | ✅ |
| PC `is_hand_busy()` suppresses re-press | CR-4 (PC owns idempotency at signal layer) | ✅ |
| PC E.7 F&R cancel on damage ≥ 10 HP | CR-18 (DC handles by simply not receiving signal) | ✅ |
| Save/Load LSS `register_restore_callback` canonical | CR-5 + pseudocode | ✅ |
| Save/Load `DocumentCollectionState` is one of 6 sub-resources on SaveGame | CR-6 | ✅ |
| MLS CR-4 `document_collected` valid as `completion_signal` | §C.10 confirms; DC emits one-shot per id (FP-DC-10) | ✅ |
| MLS CR-9 section authoring contract (required nodes) | §F.5 item #1 — MLS §C.5 needs `documents/` group + 8 lints | ⚠ **NEW BLOCKING** — §F.5 item #1 |
| MLS CR-15 SaveGame assembler reads each system's `capture()` | DC implements `capture() -> DocumentCollectionState` | ✅ |
| Audio §Documents domain (audio.md L168-175) subscribes 3 Document signals | §C.10 — Audio is pure subscriber | ✅ |
| Audio §Tuning Knobs Duck-amounts (audio.md L446-447) `document_overlay_music_db = −10`, `document_overlay_ambient_db = −20` | DC emits `document_opened` / `document_closed` only; Audio owns dB values | ✅ |
| Localization `doc.[id].title` / `doc.[id].body` keys | CR-1 + CR-8 | ✅ |
| Localization CR-9 forbids `cached_translation_at_ready` | CR-8 — DC has no cache (delegates to subscribers) | ✅ |
| Localization Scaffold authoring guideline | CR-19 NEW rule (BQA never-expanded) + 2 NEW keys | ⚠ **NEW BLOCKING** — §F.5 item #3 |
| Inventory WorldItem priority=2 (PICKUP) | DC priority=0 (DOCUMENT) wins; §C.5.5 authoring rules | ✅ |
| HUD Core REV-2026-04-26 — pickup toast deferred to HSS #19 | §C.10 confirms; DC at MVP has no pickup-toast subscriber | ✅ |
| HUD Core CR-21 prompt-strip glyph + interact_label_key | DC's `Document.interact_label_key` slots into HUD's `_compose_prompt_text()` exactly per HUD CR-21 | ✅ |
| Outline Pipeline ADR-0001 Tier 1 = heaviest | §C.3 + CR-2 | ✅ |
| Document Overlay UI #20 — sibling VS, owns reading modal | CR-11 + CR-12 + §F.5 item #6 contract | ✅ (forward-dep) |
| Document Overlay UI #20 — uses `PostProcessStack.enable_sepia_dim()` | DC has no PPS dep; Overlay handles | ✅ |
| HSS #19 — VS pickup toast subscriber | §F.5 item #7 contract | ✅ (forward-dep) |
| Failure & Respawn — F&R cancel mediated by PC | CR-18 — DC has no direct F&R dep | ✅ |
| Level Streaming `_exit_tree()` ordering during section unload | E.26 + CR-16 confirm tree-order top-down per godot-feasibility | ✅ |
| Settings & Accessibility — DC has no settings | §F.4 forbidden non-dep | ✅ |
| Game-concept — 15-25 documents | CR-9 = 21 documents (within range) | ✅ |
| Game-concept — Pillar 2 primary mechanic | §B Player Fantasy + §C.5.1 86% off-path ratio | ✅ |
| Game-concept — Pillar 1 distributed | §B Player Fantasy + §C.7 tonal rules | ✅ |
| Game-concept — Pillar 4 Iconic Locations | §C.5.1 furniture-binding per section | ✅ |

## Tuning Knobs

### G.1 — DC-Owned Tuning Knobs (designer-adjustable)

| Knob | Default | Safe Range | Effect | Out-of-Range Risk |
|---|---|---|---|---|
| `dc_total_document_count` | 21 | [15, 25] | Total documents authored across all 5 sections (CR-9) | Below 15: under-rewards observation, weakens Pillar 2; above 25: writer/localization burden, density violations §C.5.1 |
| `dc_per_section_count[plaza]` | 3 | **[3, 4]** | Plaza section document count (§C.5.1). **Lower bound raised from 2 to 3 per G.1.cross invariant 1** (revised 2026-04-27): the Plaza MVP tutorial set §C.5.3 IS the 3-doc minimum (Security logbook on-path + Tourist register off-path + Maintenance clipboard off-path). Tuning below 3 would skip the dedicated tutorial coverage of the off-path reward loop. | Below 3: insufficient tutorial coverage of off-path verb teaching; above 4: noisy intro, overwhelms loop teaching |
| `dc_per_section_count[lower]` | 4 | [3, 5] | Lower Scaffolds count | Below 3: section feels empty; above 5: density crowds the industrial geometry |
| `dc_per_section_count[restaurant]` | 6 | [4, 6] | Restaurant section count (peak — richest furniture surface count) | Below 4: under-rewards the section's surface density; above 6: §C.5.1 cap |
| `dc_per_section_count[upper]` | 5 | [3, 6] | Upper Structure count | Below 3: under-paces the command-paperwork narrative arc; above 6: distracts from tension build |
| `dc_per_section_count[bomb]` | 3 | [2, 4] | Bomb Chamber count (deliberate compression) | Above 4: dilutes the climax compression effect (§C.5.2) |
| `dc_off_path_ratio_min` | 0.75 | **[0.65, 0.86]** | Minimum fraction of documents that must be off-path (per F.2 `is_off_path`). **Upper bound capped at 0.86** (= 18/21, the actual mission ratio at default distribution) per design-review systems-designer Finding 6 (revised 2026-04-27). At 1.0 the knob would invalidate §C.5.1's 3 structural on-path anchors (Plaza Security Logbook tutorial slot + Restaurant Vogel Dietary Memo narrative-critical + Bomb Chamber Detonation Telex climax). Tuning above 0.86 requires an explicit re-classification of one or more anchors, which is a design decision, not a tuning operation. | Below 0.65: weakens Pillar 2; below 0.50: invalidates the patient-observer fantasy; above 0.86: structurally incompatible with on-path anchor documents (see §C.5.1) |
| `dc_personal_communication_cap` | 5 | [3, 6] | Max number of Personal Communications (Document type 7) across full roster | Above 6: collapses the comedic effect (per Narrative-Director §C.4 — "overuse collapses the effect"); below 3: removes the most unguarded comedic register |

**G.1.cross — Cross-constraint invariants (NEW 2026-04-27 per design-review systems-designer Finding 7):**

The per-section count knobs and `dc_total_document_count` are NOT independently tunable. The following invariants must hold whenever any of these knobs is changed:

1. **Per-section sum ≥ total minimum**: `sum(dc_per_section_count.min) ≥ dc_total_document_count.min`. With current per-section minima (Plaza 2 + Lower 3 + Restaurant 4 + Upper 3 + Bomb 2 = 14) and `dc_total_document_count.min = 15`, this invariant is currently violated by 1. **Resolution applied**: raise Plaza minimum from 2 to 3 (the Plaza tutorial set IS the 3-doc Plaza minimum per §C.5.3 — there is no MVP scope for fewer than 3 Plaza documents). Updated cross-constraint: 3 + 3 + 4 + 3 + 2 = **15** ✓.
2. **Per-section sum ≤ total maximum**: `sum(dc_per_section_count.max) ≤ dc_total_document_count.max`. Current maxima sum to 25 (= 4 + 5 + 6 + 6 + 4); `dc_total_document_count.max = 25`. ✓ (touches ceiling exactly — any per-section max increase requires total-cap raise).
3. **Off-path-ratio + structural-anchor coupling**: `dc_off_path_ratio_min ≤ 1 - (count_of_structural_on_path_anchors / dc_total_document_count)`. With 3 structural anchors and total 21, the upper bound = 1 - 3/21 = 0.857 ≈ **0.86** (matches G.1 revised cap above).
4. **No section may go to zero**: each section's minimum count must be ≥ 2 to preserve §C.5.2's "institution at rest → at work → ... → at the edge of its purpose" 5-beat narrative arc. Plaza upgrade above respects this invariant by raising to 3, not lowering.

These invariants are CI-validatable; AC-DC-1.4 NEW (see §H.1) tests invariants 1–3 at build time.

### G.2 — Inherited Constants (NOT tunable here — owned by source GDD)

| Constant | Value | Owner | Use in DC |
|---|---|---|---|
| `player_interact_ray_length` | 2.0 m | Player Character (registry) | F.3 `is_reachable` upper bound; §C.5.4 authoring rule |
| `interact_min_separation` | 0.15 m | Player Character (registry) | §C.5.6 lint #4 minimum body separation |
| `off_path_min_distance_m` | 10.0 m | Mission & Level Scripting (registry) | F.2 `is_off_path` qualification threshold |
| `h_min` (body height min) | 0.4 m | DC §C.5.4 + Player Character (Eve crouched eye Y=1.0 m) | F.3 `is_reachable` lower height bound; §C.5.6 lint #6 |
| `h_max` (body height max) | 1.5 m | DC §C.5.4 + Player Character (Eve standing eye Y=1.6 m) | F.3 `is_reachable` upper height bound; §C.5.6 lint #6 |
| `document_overlay_music_db` | −10.0 dB | Audio §F | DC fires `document_opened`; Audio applies the duck level |
| `document_overlay_ambient_db` | −20.0 dB | Audio §F | Same — DC has no role in dB tuning |

### G.3 — Locked by ADR (NOT tunable — would require ADR amendment)

| Item | Locked by | Why locked |
|---|---|---|
| 3 Document-domain signals (`document_collected`, `document_opened`, `document_closed`) | ADR-0002 | Frozen taxonomy; adding/removing breaks compilation across multiple subscribers |
| `DocumentCollectionState.collected: Array[StringName]` schema | ADR-0003 | Save format frozen; schema change invalidates existing saves |
| Stencil Tier 1 (4 px @ 1080p) for uncollected documents | ADR-0001 | Canonical table; tier change affects shader and other Tier 1 entities |
| `LAYER_INTERACTABLES` exclusive | ADR-0006 | Single source of truth at `physics_layers.gd`; DC consumes |
| DC is NOT autoload per ADR-0007 | ADR-0007 | DC structure cannot become autoload without a paired ADR-0007 amendment per its own amendment bar |
| ADR-0008 sub-slot claim 0.05 ms peak event-frame | ADR-0008 | Performance budget; growth requires F.1 N_subscribers ≤ 5 OR ADR-0008 amendment |
| `tr()` discipline + key-only persistence | ADR-0004 | Localization scaffold mandate; `hardcoded_visible_string` forbidden |

### G.4 — Pillar 5 / Pillar 2 Absolutes (NOT tunable — pillar amendment required)

These cannot be turned into knobs without changing the game's pillar set:

| Absolute | Source Pillar | Tuning prohibition |
|---|---|---|
| No "X of Y documents collected" UI counter | Pillar 5 (Period Authenticity) + Pillar 2 (Discovery) | CR-13 absolute; cannot be re-enabled |
| No achievement popup on first document | Pillar 5 | FP-DC-3; cannot be added as opt-in |
| No floating ?/! markers on uncollected docs | Pillar 5 | FP-DC-5; outline shader is sole affordance |
| No extra glow / pulse beyond Tier 1 outline | Pillar 5 + Pillar 4 | FP-DC-6; document must look like it belongs in the room |
| No hold-E-to-collect mechanic | Pillar 5 | FP-DC-1; pickup is single press |
| No voice-acted documents | Pillar 1 | FP-DC-4; page does the comedy |
| No fast-travel from documents | Pillar 5 + Pillar 2 | FP-DC-8 |
| No gameplay-mechanical effects from collecting documents | Pillar 2 (intrinsic reward) | FP-DC-7 |
| BQA acronym never-expanded | Pillar 1 (typographic comedy) | CR-19 |

### G.5 — Ownership Matrix

| Knob/Constant | Tunable Here | Owner | Notes |
|---|---|---|---|
| Per-section document counts | ✅ | DC §G.1 | Within Pillar-2-respecting ranges |
| Off-path ratio | ✅ | DC §G.1 | Pillar 2 absolute floor |
| Total document count | ✅ | DC §G.1 | Within game-concept [15, 25] budget |
| Personal Communication category cap | ✅ | DC §G.1 | Narrative-Director §C.4 constraint |
| `player_interact_ray_length` | ❌ | Player Character | Reading inherited |
| `interact_min_separation` | ❌ | Player Character | Reading inherited |
| `off_path_min_distance_m` | ❌ | MLS | Reading inherited |
| Body height authoring constraints | ❌ | DC §C.5.4 (locked) | Coupled to PC eye heights — pillar-relevant |
| 3 ADR-0002 signals | ❌ | ADR-0002 | Frozen |
| `DocumentCollectionState` schema | ❌ | ADR-0003 | Frozen |
| Stencil Tier 1 | ❌ | ADR-0001 | Frozen |
| ADR-0008 sub-slot 0.05 ms | ❌ | ADR-0008 | Amendable but currently locked |
| `tr()` discipline | ❌ | ADR-0004 | Project-wide |
| Pillar 5 / 2 absolutes | ❌ | Pillar set | Pillar amendment required |

## Visual/Audio Requirements

### V — Visual Requirements

#### V.1 — Per-Category Mesh Register

Seven document type categories (per §C.4) map to 7 distinct silhouettes for instant pre-pickup recognition:

| Category | Mesh Type | Silhouette / Geometry | Tier 1 outline edges |
|---|---|---|---|
| **Operational Memo** | Flat plane | Single A4 sheet, folded once horizontally; folded edge + visible top half implies typed text via fine ink stripe band on upper third | Sheet perimeter + folded edge ridge |
| **Personnel Dossier** | Stacked planes | 3–5 sheets stacked, portrait, single staple top-left (1 triangular face); slight stack offset; **manila ochre** (Art Bible §7D) | Top sheet perimeter; staple highlight |
| **Maintenance Log** | Clipboard | Flat board + spring-clip bar (2 small cylinders); 2 pages behind clip; slight upward-curl bottom corners (2-tri curl geometry) | Board perimeter + clip cylinder edges |
| **Service Document** | Closed book | Leather-bound rectangular box mesh + chamfered spine edge + 1 ribbon bookmark planar strip | Book perimeter + spine chamfer |
| **Telex Transcript** | Cylinder | Rolled paper strip resting in/beside telex paper-tray; flattened bottom contact face; visible end-face circles | Cylinder silhouette + end-face circles — only category that's a cylinder |
| **Technical Specification** | Folded blueprint | Blueprint or schematic folded to A5; **blueprint blue paper** (only non-warm-neutral category — instant distinct); single center-line crease ridge (2-face geometry) | Sheet perimeter + crease ridge |
| **Personal Communication** | Envelope + sheet | Flat diamond-flap envelope; letter sheet protrudes ~1/3 above envelope mouth; informal register; warmer white than memo | Envelope perimeter + protruding sheet edge |

#### V.2 — Mesh Complexity Budget

**Target: 50–120 tris per `DocumentBody` mesh.** Rationale: outline shader cost scales with screen coverage and outlined-object count, not interior polygon detail. Per-object vertex processing is bounded; 21 documents × 120 tris = 2,520 tris total contribution well under draw-call ceiling. Tier 1 outline legibility is achieved by stencil, not geometry.

| Mesh Type | Tri budget |
|---|---|
| Telex roll (cylinder + end caps) | 80–100 |
| Clipboard with clip bar + board | 60–80 |
| Service document (leather book) | 60–100 |
| Personnel dossier (stacked sheets) | 40–80 |
| Operational Memo (flat plane) | 20–40 |
| Personal Communication (envelope + sheet) | 30–50 |
| Technical Specification (folded blueprint) | 20–40 |

#### V.3 — Per-Section Color Palette

Paper reads as paper by staying in the warm-neutral band; section accent appears as small highlight (stamp, tab, seal — not paper base). Tier 1 outline = **Ink Black `#1A1A1A`** (4 px, Art Bible §4.4 + HUD Core §V).

| Section | Paper Base | Ink/Type | Section Accent |
|---|---|---|---|
| **Plaza** | `#F5EFD6` (warm parchment) | `#1A1A1A` Ink Black | `#E8C832` Parisian yellow (stamp/tab) |
| **Lower Scaffolds** | `#E8E0CC` (industrial off-white) | `#1A1A1A` | `#E85C1A` warning orange (stamp ink) |
| **Restaurant** | `#FAFAF5` (white linen) | `#1C3A6E` BQA blue ink | `#2B5FAD` BQA blue (letterhead) |
| **Upper Structure** | `#DDE8D8` (faint comms-green tint) | `#1A1A1A` | `#3A7A52` comms-station green (seal) |
| **Bomb Chamber** | `#F5F5F5` (sterile white) | `#1A1A1A` | `#C41C1C` PHANTOM red (stamp/seal) |

The Ink Black 4 px outline reads against all 5 paper bases. Saturated-Pop principle preserved: paper desaturated to read as paper, accents at full saturation make section identity recognizable before interact distance.

#### V.4 — Exterior Visual Tells (pre-pickup category recognition)

The player must be able to identify document category from silhouette + 1–2 exterior cues without reading content:

1. **Silhouette shape** — flat rect / clipboard board / cylinder / closed-book rect / envelope-with-protrusion. Category readable from mesh silhouette alone.
2. **Stamp color** — memos: red wax/ink stamp upper-right (flat circle, section-accent color). Dossiers: BQA-style rectangular frame stamp. Telex rolls: no stamp (the roll is the tell).
3. **Stack depth** — Personnel Dossiers have visible stack offset; single-sheet categories don't.
4. **Clip / binding tell** — clipboard's spring clip bar unique; service folio's spine chamfer unique; envelope's diamond-flap silhouette unique.
5. **Paper color** — Technical Specification in blueprint blue is the only non-warm-neutral base; instantly distinct.
6. **Roll vs. flat binary** — telex is the only cylinder; all others are flat planes; readable at any stencil-visible distance.

#### V.5 — NOLF1 Fidelity Anchors

- **Typewriter register** — exterior paper meshes imply Courier-monospace typed body via flat-geometry ink-stripe band, NOT actual legible type on the mesh texture (legible content lives in Document Overlay UI #20). All-caps section headers, double-spaced body text are Document Overlay concerns.
- **BQA-style letterhead** — Art Bible §7D mission-dossier-card register: centered seal geometry top, horizontal rule bar below, typed body below the rule. Manila ochre `#F5EFD6` is the direct Art Bible §7D color call.
- **Pristine-paper aesthetic** — NOLF1 props are clean and filed, not dog-eared or damaged. PHANTOM considers itself orderly. **Damaged or crumpled paper is wrong for the faction register.**

#### V.6 — Pickup Animation Discipline

**Policy: NO animation. Snap-clear on `document_collected` emission via `call_deferred("queue_free")`.**

Rationale: NOLF1 objects collected disappear on the frame of interaction — no fade, no scale tween, no particle burst. Disappearance IS the confirmation. Fade/scale-down introduces ambiguity (collected vs. phasing out). Snap-clear is also cheaper (zero Tween nodes, zero per-frame cost — aligns ADR-0008 0.05 ms claim). Pillar 5 register: Eve pockets the document; the document is no longer on the surface; no theatrical moment.

#### V.7 — Forbidden Visual Patterns (uncollected `DocumentBody`)

| FP-V | Pattern | Reason |
|---|---|---|
| FP-V-DC-1 | Emission shader on body mesh | No self-illumination beyond Tier 1 stencil outline; documents do not glow |
| FP-V-DC-2 | Pulse / animation cycle on body | Static prop is static; no UV scroll, no scale breathe, no shimmer pass |
| FP-V-DC-3 | World-space UI annotation (?, !, category icon) | FP-DC-5 absolute; outline shader is sole affordance |
| FP-V-DC-4 | PBR crease/damage texture maps | Saturated Pop discipline forbids realism-register paper; flat diffuse only |
| FP-V-DC-5 | Secondary outline, halo, bloom ring | Tier 1 single outline is canonical; no double-outline at any distance |
| FP-V-DC-6 | Animated arrows / path indicators | No diegetic or non-diegetic directional cue toward bodies |
| FP-V-DC-7 | Proximity-triggered fan-out / page-lift / ripple | Paper is where the clerk left it; stays until Eve pockets it |
| FP-V-DC-8 | Fade-to-transparent / scale-down tween on collect | V.6 snap-clear policy; no theatrical exit |

### A — Audio Requirements

DC owns ZERO audio infrastructure. Audio (designed) subscribes to all 3 DC signals; this section validates the contract from `audio.md` §Detailed Design → Interactions with Other Systems → **Documents domain** (lines 168–175) + `audio.md` §Tuning Knobs → **Duck amounts (state-keyed per-layer — Formula 1)** (lines 446–447 for `document_overlay_music_db`/`document_overlay_ambient_db`) + `audio.md` §States and Transitions → State table row `DOCUMENT_OVERLAY` (line 95: `−10 dB / −20 dB`). Cross-reference paths corrected 2026-04-27 per design-review audio-director Finding 1 (the prior `Audio §C.2 + §F.4` citations did not resolve to actual section addresses in `audio.md`). DC-specific constraints follow.

**Note on dB semantic (audio-director Finding 2 surfaced; resolution OWNED BY audio.md, NOT DC)**: `audio.md` line 95 lists DOCUMENT_OVERLAY as `−10 dB / −20 dB` (absolute targets in the State table format), and Formula 1 line 255 lists `−8 dB additional` as a VO-duck overlay (relative). Both rows are CORRECT but apply to DIFFERENT events: line 95 = overlay-open music/ambient duck (absolute targets in `volume_db`); line 255 = additional VO-mid-overlay duck (relative offset on top of line 95). DC consumes line 95 semantics (overlay-open absolute targets). The two rows are not contradictory but are easily confused; flagged for `audio.md` clarification as ADVISORY coord (NOT a DC-side fix). Tracked in §F.5 as ADVISORY coord ADVISORY-DC-AUD-1.

#### A.1 — Audio Cue Validation

| Signal | Audio cue spec | Validation |
|---|---|---|
| `document_collected` | Envelope slide + paper crisp + metallic click, ~300 ms, pooled 3D at body position, SFX bus, priority 3 | ✅ Approved with mix note: **metallic click should mix subordinate to paper crisp** — registers as incidental clasp/catch, not punctuating. Risk if mixed too prominently: theatrical confirmation register that violates "Reading the Room" curatorial fantasy. |
| `document_opened` | Paper rustle + pen-cap tock, ~400 ms + 150 ms, non-spatial, UI bus | ✅ Approved as-is. The 150 ms pen-cap tock earns the curatorial register (implies someone mid-work, interrupted). World-recedes function carried by music duck, not SFX. |
| `document_closed` | Paper slide dismissal, ~250 ms, non-spatial, UI bus | ✅ Approved as-is. Briefer than open — closing is dismissal, not ceremony. |

#### A.2 — Per-Category Audio Variation: 3-Cluster Scheme

DC owns 7 categories; Audio implements 3 acoustic clusters, each with 2 variants (no machine-gun repetition):

| Cluster | Categories | Sound profile |
|---|---|---|
| **A — Single-sheet paper** | Operational Memo, Maintenance Log, Personal Communication, Technical Specification (folded) | Light crisp, fast slide |
| **B — Bound / multi-page** | Personnel Dossier, Service Document (leather book) | Heavier rustle, cloth-binding thud on open, binding creak on close |
| **C — Carbon / rigid** | Telex Transcript | Harder edge, slight rattle, stiffer slide |

Asset count: 6 pickup SFX files + 6 open SFX files + 6 close SFX files = 18 cluster-variant audio assets. **Cluster-routing coord item**: Audio needs to read the document's category at handler time. Two approaches:

- (a) DC exposes `get_document_type(id) -> StringName` query API
- (b) Audio lazy-loads `res://documents/[id].tres` on signal receipt and reads `Document.type`

**Recommended: option (b)** — preserves DC's "subscribe-only" stance; DC has zero audio coupling. Audio coord with Lead Programmer for Resource caching policy.

#### A.3 — Mixing During Document Overlay

**Policy: ducked-music + ducked-ambient + UI-bus open/close SFX are sufficient. Do NOT add a room-tone bed or paper-shuffle layer during overlay.**

Rationale: a room-tone bed during overlay would signal "pay attention to this — something funny is happening," which is exactly the theatrical mode §B Player Fantasy refuses. The −20 dB ambient duck leaves enough room-tone bleed through naturally from the environment bus (no authoring needed). Pillar 1 comedy lives in typography, not in atmospheric scoring.

**VS-Polish optional**: distant-typewriter-from-another-room ambient layer, gated to Restaurant section only, ambient priority 5 (lowest), non-spatial, −6 dB below ambient floor. **Do NOT implement at MVP.** Captured as Open Question OQ-DC-Audio-1.

#### A.4 — Save-Quit-With-Overlay Audio Lifecycle

If player saves and immediately quits to Main Menu with the Document Overlay open:

- Document Overlay UI #20 closes the overlay (calls `DC.close_document()`); DC emits `document_closed`; Audio's overlay-close SFX (~250 ms) starts.
- Menu System begins 800 ms music fade-out per Menu System CR-20.
- The 250 ms SFX should complete BEFORE the Menu fade ends — but the 400 ms `document_opened` SFX may still be in-flight if the player save-quits within 400 ms of opening.

**Resolution**: Audio subscribes to a `gameplay_session_ended` signal (or `SceneTree.node_removed` on the gameplay root) and **immediately stops** any in-flight DC-triggered `AudioStreamPlayer` instances (silent-stop, NOT fade) before Menu System's 800 ms fade begins. **NEW BLOCKING coord item** (Audio): `gameplay_session_ended` signal contract — coordinate with Lead Programmer; ADR-0002 amendment may be required if this signal does not yet exist.

#### A.5 — Forbidden Audio Patterns (DC-specific)

| AFP | Pattern | Reason |
|---|---|---|
| AFP-DC-1 | Synthesized confirmation tone, ding, chime, sparkle, UI-bus micro-stinger on `document_collected` | Pillar 5 — paper sounds only |
| AFP-DC-2 | Volume swell / orchestral lift / music-intensity bump when story-critical or "rare" document is opened | `document_opened` triggers identical music behavior regardless of document narrative weight |
| AFP-DC-3 | Separate pickup SFX for first document collected vs subsequent | Pickup cue is stateless with respect to collection progress (Pillar 5) |
| AFP-DC-4 | Voice-acted or procedural reaction from Eve on any DC signal | Pillar 1 — Eve does not react; the page does the comedy. Audio does not subscribe to any Eve-reaction hook on DC signals. |
| AFP-DC-5 | Audio distinction between critical-path document and side document | Audio cannot read `is_critical_path: bool` from `Document` (the field doesn't exist on the Resource per CR-1) |
| AFP-DC-6 | Completion fanfare or state-change SFX at document-count milestones (50% / 100% collected) | Pillar 5 — collection progress has no audio acknowledgment outside per-pickup cluster cue |

#### A.6 — Audio Knobs (DC-owned: ZERO)

DC owns ZERO audio constants. Audio GDD §F owns all dB levels, durations, bus routing, and cluster-variant selection logic. The only DC-side parameter that touches audio behavior is `Document.type` (read by Audio for cluster routing); DC does not tune any audio consequence. Confirmed.

### Asset Spec Flag

📌 **Asset Spec — Visual/Audio requirements are defined.** After the art bible is approved, run `/asset-spec system:document-collection` to produce per-asset visual descriptions, dimensions, and generation prompts for: 7 mesh categories × per-section color variants = up to ~35 distinct mesh variants; per-section paper-base + ink + accent palette files; BQA seal + letterhead geometry from Art Bible §7D; 18 cluster-variant audio assets (6 pickup × 3 clusters × 2 variants).

## UI Requirements

### UI-1 — Surface Boundaries (DC owns ZERO rendered UI)

DC publishes signals and exposes APIs; it does NOT render any UI surface. Player-facing UI for documents lives entirely in three other systems:

| Surface | Owner | Contract from DC |
|---|---|---|
| **Pickup toast** ("DOCUMENT COLLECTED: [title]") | HUD State Signaling #19 (VS) | HSS subscribes to `Events.document_collected(id)`; reads `Document` resource; calls `tr(title_key)`; renders toast |
| **Full-screen reading modal** | Document Overlay UI #20 (VS) | Overlay subscribes to `document_opened` / `document_closed`; calls `DC.open_document(id)` / `DC.close_document()`; calls `tr(title_key)` + `tr(body_key)`; handles `NOTIFICATION_TRANSLATION_CHANGED`; calls `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` |
| **Interact prompt strip** | HUD Core ✅ (via PC accessor) | HUD's `_compose_prompt_text()` reads `target.document.interact_label_key` via `pc.get_current_interact_target()`; HUD treats `DocumentBody` like any other interactable — no DC-specific subscription |

DC is purely the data + state + signal layer. This boundary is enforced by:

- CR-7 sole-publisher discipline (DC publishes 3 signals, doesn't render)
- CR-13 no-quest-counter absolute (DC exposes no aggregate counts)
- CR-14 NOT autoload, NOT a CanvasLayer (DC is a `Node` per-section system)
- §F.4 forbidden non-deps include Settings, Menu, PPS, Cutscenes — DC has no UI integration with any of them

### UI-2 — HUD Core Integration: `interact_label_key`

HUD Core (designed) renders the interact prompt strip via `_compose_prompt_text()` which reads `target.document.interact_label_key` as an arbitrary `StringName` translation key. DC's `Document` Resource exposes this field per CR-1.

| MVP value | VS value |
|---|---|
| `&"ui.interact.pocket_document"` | `&"ui.interact.read_document"` |

The MVP value is the fallback used until Document Overlay UI #20 ships. Once VS Document Overlay is live, the level-designer flips the default per `Document.tres` to `&"ui.interact.read_document"` (or sets per-document custom keys for narrative flavor — a Personnel Dossier might use `&"ui.interact.examine_dossier"`).

HUD Core's CR-21 + CR-18 already handle:

- Runtime input-glyph rebinding (`[E]` substituted from Input GDD `Input.binding_changed` signal)
- `tr()` cache via `_last_interact_label_key` mirror
- Locale-change re-resolution via `NOTIFICATION_TRANSLATION_CHANGED`

DC has **zero work** on the prompt-strip side — it provides the key; HUD does the rendering.

### UI-3 — Forward-Dep Contracts (UX Specs Required at VS)

When Document Overlay UI #20 and HUD State Signaling #19 GDDs are authored, they must produce per-screen UX specs. The required UX spec list:

| Surface | UX spec path | Tier | Owner GDD |
|---|---|---|---|
| Document Reading Modal | `design/ux/document-overlay.md` | VS | Document Overlay UI #20 |
| Document Pickup Toast | `design/ux/hud-pickup-toasts.md` (joint with weapon-pickup, gadget-pickup) | VS | HUD State Signaling #19 |

DC itself does NOT require a UX spec — it has no rendered surface.

### UI-4 — Pillar 5 / Pillar 2 UI Absolutes (re-stated)

Per CR-13 + FP-DC-2/3/5/6/8:

- **NO** "X of Y documents collected" UI counter anywhere (HUD, Pause Menu, Loading Screen, Pause-Menu-Pause-Menu archive)
- **NO** achievement popup on first document or any milestone
- **NO** floating ?/! markers, holographic projection, glow/pulse beyond Tier 1 outline
- **NO** "case file archive" Pause Menu shortcut at MVP — deferred to Polish-or-later (Menu System system #21 territory; if/when authored, it reads `DocumentCollectionState.collected` directly from `SaveGame`)

These absolutes apply to ALL forward-dep UI surfaces (Document Overlay UI, HSS, Menu System) — they are project-wide constraints, not DC-internal.

### 📌 UX Flag — Document Collection (forward-dep)

This system has **no MVP UI** to spec; the MVP shipping surface is the pickup-only loop (per CR-3 + Plaza tutorial 3-doc set §C.5.3). The HUD interact prompt is already handled by HUD Core CR-18 + CR-21 — no DC-specific UX work required.

For **VS Phase 4 (Pre-Production)**, after Document Overlay UI #20 and HSS #19 GDDs are authored, run:

- `/ux-design design/ux/document-overlay.md` — for the Document Overlay UI #20 reading modal
- `/ux-design design/ux/hud-pickup-toasts.md` — for HSS #19's pickup toast (joint surface with weapon/gadget pickups)

Stories that reference DC UI should cite the UX specs above (when authored), NOT this GDD directly. DC is the data/signal layer; the UX specs are the rendering layer.

## Acceptance Criteria

### H.1 — Resource Schema & Body Authoring (CR-1, CR-2, CR-9; F.3; Lints 1–6)

**AC-DC-1.1** [Logic] [BLOCKING]
**GIVEN** a `Document` Resource at any valid path, **WHEN** it is loaded, **THEN** all six fields are present (`id`, `title_key`, `body_key`, `section_id`, `interact_label_key`, `tier_override`), `id` is a non-empty `StringName` in `snake_case`, `tier_override` defaults to `-1`, and neither `title_key` nor `body_key` resolves to a visible string (raw keys only — no `tr()` call inside the Resource).
Evidence: `tests/unit/document_collection/document_resource_schema_test.gd` — `test_all_fields_present_and_typed_correctly`, `test_content_fields_are_keys_not_resolved_strings`.

**AC-DC-1.2** [Config/Data] [BLOCKING]
**GIVEN** the project build, **WHEN** CI section-validation runs (§C.5.6 lints 1–6), **THEN**:
1. Every `DocumentBody` in `&"section_documents"` has a non-null `@export var document` with non-empty `id`;
2. All `document.id` values are unique across all 5 section scenes;
3. Each `document.section_id` matches the enclosing scene's section identifier;
4. No two `DocumentBody` collision origins are within `0.15 m` of each other;
5. Body `collision_layer` equals `LAYER_INTERACTABLES` with no other bits set;
6. Body `CollisionShape3D` global Y center is within `[0.4, 1.5] m`.

Any violation fails the build. Evidence: CI lint run log at build time.

**AC-DC-1.3** [Config/Data] [BLOCKING]
**GIVEN** any section scene, **WHEN** it contains a non-empty `&"section_documents"` group, **THEN** a `DocumentCollection` node exists at `Section/Systems/DocumentCollection` (CI lint #7 from §E.17) and a `&"critical_path"` spline node is present (CI lint #8 from §E.28). Absence of either is a build failure.
Evidence: CI lint run log at build time.

**AC-DC-1.4** [Config/Data] [BLOCKING] — NEW 2026-04-27 per §G.1.cross
**GIVEN** the project tuning data (per-section count knobs + `dc_total_document_count` + `dc_off_path_ratio_min`), **WHEN** the cross-constraint CI lint runs, **THEN**:
1. `sum(dc_per_section_count.min) ≥ dc_total_document_count.min` (currently 3+3+4+3+2 = 15 ≥ 15 ✓);
2. `sum(dc_per_section_count.max) ≤ dc_total_document_count.max` (currently 4+5+6+6+4 = 25 ≤ 25 ✓);
3. `dc_off_path_ratio_min ≤ 1 − (count_structural_on_path_anchors / dc_total_document_count)` (currently 0.86 ≤ 1−3/21 = 0.857 — the .003 rounding tolerance is built into the lint).
Any violation fails the build.
Evidence: CI cross-constraint lint output at build time; lint #11 NEW (joins §C.5.6 list — see §F.5 item #4 scope).

**AC-DC-1.5** [Config/Data] [BLOCKING] — NEW 2026-04-27 per §C.5.8 template requirement
**GIVEN** every `DocumentBody` node across all 5 section scenes, **WHEN** CI scene-validation runs, **THEN** each body is an instance of the canonical `res://src/gameplay/documents/document_body.tscn` template (instanced, not hand-authored). Hand-authored `DocumentBody` nodes (i.e., a `StaticBody3D` with the DC script attached but no PackedScene-instance ancestor) fail the build.
Evidence: CI scene-instance lint output at build time; lint #10 NEW (joins §C.5.6 list — see §F.5 item #4 scope).

### H.2 — Pickup Lifecycle (CR-3, CR-4, CR-10, CR-16, CR-17, CR-18)

**AC-DC-2.1** [Integration] [BLOCKING]
**GIVEN** DC subscribed to `Events.player_interacted` and a `DocumentBody` with id `&"plaza_logbook"` in the section, **WHEN** PC emits `Events.player_interacted(that_body)`, **THEN**: (a) `_collected` contains `&"plaza_logbook"`; (b) `Events.document_collected` fires exactly once with that id; (c) `body.call_deferred("queue_free")` is scheduled (body no longer valid next frame).
Evidence: `tests/integration/document_collection/pickup_lifecycle_test.gd` — `test_pickup_appends_id_emits_signal_and_defers_free`.

**AC-DC-2.2** [Logic] [BLOCKING]
**GIVEN** DC has `&"plaza_logbook"` already in `_collected`, **WHEN** `Events.player_interacted` fires again with that same `DocumentBody`, **THEN** `document_collected` does NOT fire a second time and `_collected.size()` is unchanged (CR-3(f) idempotency net).
Evidence: `tests/unit/document_collection/idempotency_test.gd` — `test_duplicate_pickup_does_not_re_emit`.

**AC-DC-2.3** [Integration] [BLOCKING]
**GIVEN** F&R cancels a PC reach with `damage >= 10 HP` before `player_interacted` fires (CR-18), **WHEN** QA simulates the cancel path, **THEN** `_collected` is unchanged, no `document_collected` signal fires, and the `DocumentBody` remains in the world with its Tier 1 stencil outline intact.
Evidence: `tests/integration/document_collection/pickup_lifecycle_test.gd` — `test_fr_cancel_leaves_body_uncollected`.

**AC-DC-2.4** [Logic] [BLOCKING]
**GIVEN** DC's `_ready()` has fired, **THEN** `Events.player_interacted.is_connected(_on_player_interacted)` is `true`. **GIVEN** DC's `_exit_tree()` fires (section unload), **THEN** `Events.player_interacted.is_connected(_on_player_interacted)` is `false` and no error is raised (CR-16 ADR-0002 IG3).
Evidence: `tests/unit/document_collection/subscriber_lifecycle_test.gd` — `test_connect_on_ready_disconnect_on_exit_tree`.

### H.3 — Signal One-Shot Semantics & Sole-Publisher Discipline (CR-7, FP-DC-10; E.16)

**AC-DC-3.1** [Logic] [BLOCKING]
**GIVEN** the full session (5 sections, 21 documents), **WHEN** each `DocumentBody` is picked up exactly once, **THEN** `document_collected` fires exactly once per unique `id` across the session. No second emission occurs on re-load of a section containing a previously collected body (CR-5 spawn-gate prevents re-pickup entirely).
Evidence: `tests/integration/document_collection/signal_one_shot_test.gd` — `test_document_collected_fires_once_per_id_per_session`.

**AC-DC-3.2** [Config/Data] [BLOCKING]
**GIVEN** the full `src/` codebase, **WHEN** the sole-publisher CI lint runs (per F&R AC-FR-12.4 precedent), **THEN** zero files other than `document_collection.gd` contain `Events.document_collected.emit(`, `Events.document_opened.emit(`, or `Events.document_closed.emit(` outside of comment lines. Build fails if any match is found.
Evidence: CI grep with comment-line exclusion — `grep -rnE "^[^#]*Events\.document_(collected|opened|closed)\.emit\(" src/ | grep -v "/document_collection.gd:"` must return zero lines. **`^[^#]*` excludes lines starting with whitespace + comment** so that "do not call directly" comments and signal-spy mock helpers are not false positives (revised 2026-04-27 per design-review qa-lead Finding 20).

**AC-DC-3.3** [Logic] [BLOCKING]
**GIVEN** a section with two `DocumentBody` nodes sharing the same `document.id` (duplicate — E.16), **WHEN** the player picks up the first body, **THEN** `document_collected` fires once; **WHEN** the player approaches the second body and presses E, **THEN** `document_collected` does NOT fire again (CR-3(f) catches it) and the second body is deferred-freed.
Evidence: `tests/unit/document_collection/idempotency_test.gd` — `test_duplicate_id_bodies_emit_once`.

### H.4 — Spawn Gate & Section Load (CR-5, CR-6; E.9, E.11, E.14)

**AC-DC-4.1** [Integration] [BLOCKING]
**GIVEN** `_collected` contains `["plaza_logbook", "plaza_register"]` when DC's `_ready()` fires (restored from save), **WHEN** DC executes `_gate_collected_bodies_in_section()`, **THEN** both corresponding `DocumentBody` nodes in `&"section_documents"` are `queue_free()`-d synchronously before the section is visible and are no longer present in the scene tree on the first rendered frame.
Evidence: `tests/integration/document_collection/spawn_gate_test.gd` — `test_collected_bodies_absent_after_ready`.

**AC-DC-4.2** [Logic] [BLOCKING]
**GIVEN** `_collected` contains an id that does not correspond to any `DocumentBody` in the current section (corrupt/extra id — E.11), **WHEN** `_gate_collected_bodies_in_section()` runs, **THEN** no crash, no error log, and zero unintended bodies are freed (extra id is a no-op).
Evidence: `tests/unit/document_collection/spawn_gate_test.gd` — `test_stale_id_in_collected_is_benign`.

**AC-DC-4.3** [Integration] [BLOCKING]
**GIVEN** a section scene containing `DocumentBody` nodes with a null `@export var document` (malformed authoring — E.15), **WHEN** `_gate_collected_bodies_in_section()` iterates the group, **THEN** the null guard `if body.document == null: continue` prevents a crash and a `push_warning` is emitted.
Evidence: `tests/integration/document_collection/spawn_gate_test.gd` — `test_null_document_export_does_not_crash`.

### H.5 — Save / Load Contract (CR-6; E.7, E.9, E.12)

**AC-DC-5.1** [Logic] [BLOCKING]
**GIVEN** DC has `_collected = ["plaza_logbook"]`, **WHEN** `capture()` is called, **THEN** the returned `DocumentCollectionState` has `collected = ["plaza_logbook"]` and is a distinct Array (modifying the original `_collected` does not modify the captured state — `duplicate()` aliasing guard per CR-6).
Evidence: `tests/unit/document_collection/save_contract_test.gd` — `test_capture_returns_deep_copy`.

**AC-DC-5.2** [Logic] [BLOCKING]
**GIVEN** a `DocumentCollectionState` with `collected = ["plaza_logbook", "lower_clipboard"]`, **WHEN** `_on_restore_from_save(state)` is called, **THEN** `_collected` equals `["plaza_logbook", "lower_clipboard"]` and is a distinct Array from `state.collected` (aliasing break).
Evidence: `tests/unit/document_collection/save_contract_test.gd` — `test_restore_populates_collected_without_aliasing`.

**AC-DC-5.3** [Logic] [BLOCKING]
**GIVEN** a save taken mid-reach (before `player_interacted` fires — E.7), **WHEN** the save is loaded, **THEN** the in-progress body re-spawns in the section (id is absent from `_collected`) and the player must re-collect it. `document_collected` has NOT been emitted at save time.
Evidence: `tests/integration/document_collection/save_contract_test.gd` — `test_save_during_reach_restores_body_as_uncollected`.

**AC-DC-5.4** [Logic] [BLOCKING] — upgraded from ADVISORY 2026-04-27 per design-review qa-lead Finding 7; the test is DC-internal and does not require Document Overlay UI #20.
**GIVEN** DC has been programmatically driven into `_open_document_id != &""` (simulating Overlay open), **WHEN** `capture()` is called, **THEN** (a) `capture()` returns a valid `DocumentCollectionState` with NO error, NO crash; (b) the returned state's schema is `collected: Array[StringName]` only — no `_open_document_id` field; (c) on a subsequent simulated `restore(state)` call, `_open_document_id == &""` (default) and the Overlay state is not auto-restored.
Evidence: `tests/unit/document_collection/save_contract_test.gd` — `test_open_document_id_not_persisted_in_save` AND `test_capture_succeeds_with_open_document_state`.

### H.6 — `open_document` / `close_document` VS APIs (CR-11, CR-12; E.22–E.24)

**AC-DC-6.1** [Logic] [BLOCKING]
**GIVEN** `_collected` contains `&"plaza_logbook"` and `_open_document_id == &""`, **WHEN** `open_document(&"plaza_logbook")` is called, **THEN** `_open_document_id` is set to `&"plaza_logbook"`, `Events.document_opened` fires with that id, and the method returns `true`.
Evidence: `tests/unit/document_collection/open_close_api_test.gd` — `test_open_document_valid_id_emits_and_returns_true`. **BLOCKED-on tag removed 2026-04-27** per design-review qa-lead Finding 6 — this AC tests DC internals only and does NOT require Document Overlay UI #20 to exist.

**AC-DC-6.2** [Logic] [BLOCKING]
**GIVEN** `_open_document_id == &"plaza_logbook"`, **WHEN** `close_document()` is called, **THEN** `_open_document_id` is cleared to `&""`, `Events.document_closed` fires with `&"plaza_logbook"`, and the method returns `true`.
Evidence: `tests/unit/document_collection/open_close_api_test.gd` — `test_close_document_clears_state_and_emits`. **BLOCKED-on tag removed 2026-04-27** per design-review qa-lead Finding 6.

**AC-DC-6.3** [Logic] [BLOCKING] — upgraded from ADVISORY 2026-04-27 per qa-lead Finding 6 (DC-internal guard testable without Overlay)
**GIVEN** `_open_document_id != &""` (one document already open), **WHEN** `open_document(other_id)` is called, **THEN** a `push_error` is raised and `false` is returned; `Events.document_opened` does NOT fire (single-document invariant CR-12).
Evidence: `tests/unit/document_collection/open_close_api_test.gd` — `test_open_while_already_open_returns_false`.

**AC-DC-6.4** [Logic] [BLOCKING] — upgraded from ADVISORY 2026-04-27 per qa-lead Finding 6 (DC-internal guard testable without Overlay)
**GIVEN** `open_document(id)` is called with an id NOT in `_collected`, **THEN** a `push_error` is raised, `false` is returned, and `Events.document_opened` does NOT fire (precondition guard CR-11).
Evidence: `tests/unit/document_collection/open_close_api_test.gd` — `test_open_uncollected_id_returns_false`.

**AC-DC-6.5** [Logic] [BLOCKING] — NEW 2026-04-27 per qa-lead Finding 10 (CR-17 has zero AC coverage)
**GIVEN** DC is subscribed to `Events.player_interacted`, **WHEN** the signal fires with `target = null`, **THEN** the handler returns immediately, no error is raised, and `_collected` is unchanged. **WHEN** the signal fires with `target` being a valid `Node3D` that is NOT a `DocumentBody` (e.g., a door node), **THEN** the handler returns immediately and `_collected` is unchanged. **WHEN** the signal fires with a `DocumentBody` target whose `document` export is null, **THEN** the handler emits `push_warning`, returns immediately, and `_collected` is unchanged (CR-17 + E.15 symmetry).
Evidence: `tests/unit/document_collection/signal_handler_guards_test.gd` — `test_null_target_is_rejected`, `test_non_document_body_target_is_filtered`, `test_null_document_export_is_warned_and_filtered`.

**AC-DC-6.6** [Integration] [BLOCKING] — NEW 2026-04-27 per qa-lead Finding 13 (E.5 rapid-fire 2-pickup has no AC)
**GIVEN** two distinct `DocumentBody` nodes with distinct ids in the same section, **WHEN** `Events.player_interacted` fires for both in sequence within 60 frames (no other state changes between firings), **THEN** `Events.document_collected` fires exactly twice — once per distinct id, in order — and `_collected` contains both ids in append order. Neither emission is dropped, neither id is double-emitted.
Evidence: `tests/integration/document_collection/edge_cases_test.gd` — `test_rapid_sequential_pickups_emit_twice_with_distinct_ids`.

### H.7 — tr() Discipline, Locale Safety & BQA Rule (CR-8, CR-19; FP-DC-11; E.19–E.21)

**AC-DC-7.1** [Config/Data] [BLOCKING]
**GIVEN** `src/gameplay/documents/document_collection.gd`, **WHEN** the Localization-discipline CI lint runs, **THEN** zero word-boundary calls to `tr(`, `atr(`, `String.t(`, or `TranslationServer.translate(` exist in the file. DC stores keys; subscribers call `tr()`. Any such call is a build failure.
Evidence: CI grep with word-boundary anchors and comment-line exclusion — `grep -nP "^[^#]*\b(tr|atr|String\.t|TranslationServer\.translate)\s*\(" src/gameplay/documents/document_collection.gd` must return zero matches. **Word-boundary regex prevents false positives on `str(`, `filter(`, etc.; `^[^#]*` excludes lines starting with whitespace + comment** (revised 2026-04-27 per design-review qa-lead Finding 17).

**AC-DC-7.2** [Config/Data] [BLOCKING]
**GIVEN** all Localization CSV files, **WHEN** the `/localize` skill BQA audit runs, **THEN** zero translation keys resolve to strings containing `"Bureau of Queen's Affairs"` or `"Bureau of Quiet Affairs"` or any other expansion of "BQA". Build fails on any match (CR-19).
Evidence: CI grep — `grep -ri "bureau of qu" assets/localization/` must return zero matches.

**AC-DC-7.3** [Config/Data] [BLOCKING]
**GIVEN** all Localization CSV files, **WHEN** the `doc.[id].title` and `doc.[id].body` key pattern is validated, **THEN** every Document Resource `id` has corresponding `doc.[id].title` and `doc.[id].body` (body required at VS only) keys present in the default locale CSV, and no locale key body resolves to an empty string.
Evidence: CI locale-key completeness check at VS build time; smoke-check at MVP for title keys only.

### H.8 — No-Quest-Counter Absolute & Forbidden Implementation Patterns (CR-13; FP-DC-1..11)

**AC-DC-8.1** [Config/Data] [BLOCKING]
**GIVEN** the full codebase, **WHEN** a CI grep runs for aggregate-query method names, **THEN** zero occurrences of `get_collected_count`, `get_total_count`, `is_complete`, `get_completion_percent` exist in any `.gd` file (CR-13 absolute). Any hit is a build failure.
Evidence: CI grep — `grep -rn "get_collected_count\|get_total_count\|is_complete\|get_completion_percent" src/`. **GAP NOTE — CR-13 CI lint is not yet enumerated in §C.5.6 lint table; should be added as lint #9 to §F.5 item #4 scope before Tools-Programmer CI ticket closes.**

**AC-DC-8.2** [Config/Data] [BLOCKING]
**GIVEN** the HUD, pause menu, and any loading screen scenes, **WHEN** the project is built, **THEN** zero UI controls contain text or bindings that display document collection counts, completion percentages, or collection progress (FP-DC-2). Any such binding is a P1 build blocker.
Evidence: Manual UI walkthrough + CI scene parser grep for `collected_count` binding references.

**AC-DC-8.3** [Config/Data] [ADVISORY]
**GIVEN** all `DocumentBody` scenes, **WHEN** visual properties are checked, **THEN**: no `emission_enabled = true` on any body mesh (FP-V-DC-1); no animation player or shader animate cycle on any body (FP-V-DC-2); no `Label3D` / `Sprite3D` annotation child nodes (FP-V-DC-3); no Tween node for collect exit (FP-V-DC-8 — V.6 snap-clear policy).
Evidence: CI scene-property audit pass; QA visual walkthrough per section with lead sign-off in `production/qa/evidence/dc_visual_pass_[section].md`.

**AC-DC-8.4** [Config/Data] [ADVISORY]
**GIVEN** Audio's signal handler for `document_collected`, **WHEN** any document is collected, **THEN** the pickup SFX is exclusively from the paper/foley cluster (no synthesized tone, chime, UI micro-stinger, or VO — AFP-DC-1, AFP-DC-4). The same SFX plays for on-path and off-path documents (AFP-DC-5). No completion fanfare fires at any collection-count milestone (AFP-DC-6).
Evidence: Audio QA playtest report in `production/qa/evidence/dc_audio_pass.md`.

### H.9 — Performance Budget (CR-15; F.1; E.32)

**AC-DC-9.1** [Logic] [BLOCKING]
**GIVEN** `N_subscribers = 4` (locked VS count: HSS, Audio, MLS, Save/Load) AND the F.1 formula example component values (t_signal_dispatch = 0.008, t_set_membership = 0.002, t_array_append = 0.001, t_signal_emit = 0.008 × 4 = 0.032, t_call_deferred = 0.003), **WHEN** the formula is evaluated in code as `t_signal_dispatch + t_set_membership + t_array_append + t_signal_emit + t_call_deferred`, **THEN** the computed sum equals `0.046 ms ± 0.0005 ms` (floating-point tolerance) AND `0.046 < 0.05` (sub-slot claim) AND `(0.05 − 0.046) / 0.05 ≥ 0.08` (≥8% headroom). The formula computation must be documented in the ADR-0008 amendment record. **Note**: this AC verifies formula arithmetic only; physical wall-clock timing verification is AC-DC-9.4 (NEW — pending ADR-0008 promotion to Accepted).
Evidence: `tests/unit/document_collection/performance_formula_test.gd` — `test_f1_pickup_cost_at_n4_within_budget`; ADR-0008 amendment record.

**AC-DC-9.2** [Logic] [BLOCKING]
**GIVEN** `N_subscribers = 6` (hypothetical sixth subscriber — E.32), **WHEN** `t_pickup` is computed via F.1, **THEN** the result reaches `≈0.070 ms`, breaching the 0.05 ms sub-slot claim. This triggers a mandatory ADR-0008 amendment review before the sixth-subscriber system ships. The review is a coord-item gate, not a runtime failure.
Evidence: `tests/unit/document_collection/performance_formula_test.gd` — `test_f1_at_n6_breaches_budget_and_triggers_review`. Coord item logged in production backlog.

**AC-DC-9.3** [Config/Data] [BLOCKING]
**GIVEN** `src/gameplay/documents/document_collection.gd`, **WHEN** the static-analysis CI lint runs, **THEN** zero matches for the regex `^func\s+_(process|physics_process)\b`. The class has no per-frame override (zero steady-state per-frame cost — CR-15).
Evidence: CI grep — `grep -nE '^func\s+_(process|physics_process)\b' src/gameplay/documents/document_collection.gd` must return zero lines. **NOT a GUT test** (revised 2026-04-27 per design-review qa-lead Finding 23 — the prior wording cited a fictional GUT path for a static-analysis check).

**AC-DC-9.4** [Integration] [ADVISORY — pending ADR-0008 promotion to Accepted]
**GIVEN** a custom `Time.get_ticks_usec()` instrumentation harness around `_on_player_interacted` on Iris Xe reference hardware, **WHEN** 100 pickup events are sampled in the Plaza tutorial section, **THEN** P95 wall-clock latency is < 0.05 ms AND P50 < 0.05 ms AND no individual sample exceeds 0.075 ms (single-frame jitter ceiling).
Evidence: `production/qa/evidence/dc_perf_iris_xe_[date].md` — instrumentation harness output + statistical summary. **Blocked-on**: ADR-0008 Validation Gate 1 (Iris Xe profile pass — currently pending). NEW 2026-04-27 per design-review performance-analyst Finding 8 (no measurement instrumentation defined for wall-clock 0.05 ms claim).

### H.10 — Off-Path Qualification & Roster Distribution (CR-9; F.2; E.28)

**AC-DC-10.1** [Config/Data] [BLOCKING]
**GIVEN** all 5 section scenes at VS build, **WHEN** the F.2 off-path CI lint runs (requires §E.28 lint #8 `critical_path_spline` present), **THEN** the per-section document count matches §C.5.1 (Plaza 3 / Lower 4 / Restaurant 6 / Upper 5 / Bomb 3 = 21 total), and at least 75% of all documents per section have `path_distance >= 10.0 m` (≥ 18 of 21 mission-wide — actual target is 18/21 = 86%).
Evidence: CI off-path ratio lint output at VS build.

**AC-DC-10.2** [Config/Data] [ADVISORY]
**GIVEN** each section's 3 on-path documents (§C.5.1: Plaza security logbook, Restaurant Vogel dietary memo, Bomb Chamber detonation telex), **WHEN** a QA level-design walkthrough is performed, **THEN** each on-path document resolves the interact prompt from the natural critical-path approach angle without the player deviating. Off-path documents do NOT resolve the prompt from the critical path (Pillar 2 — observation required).
Evidence: LD sign-off walkthrough report per section in `production/qa/evidence/dc_placement_walkthrough_[section].md`.

### H.11 — Scope Boundary: No Autoload, No Forbidden Non-Deps (CR-14; §F.4; E.3, E.6)

**AC-DC-11.1** [Config/Data] [BLOCKING]
**GIVEN** the Godot project autoload registry, **THEN** `DocumentCollection` does NOT appear in the autoload list (CR-14 — ADR-0007). DC is instantiated as a scene-child node at `Section/Systems/DocumentCollection` only.
Evidence: CI grep of `project.godot` `[autoload]` section — `grep "DocumentCollection" project.godot` must return zero matches.

**AC-DC-11.2** [Integration] [BLOCKING]
**GIVEN** the pickup lifecycle (E.3 — pickup + section-transition same frame), **WHEN** `player_interacted` fires and `LSS.section_exited` fires in the same 33 ms window, **THEN** the id is appended to `_collected`, `document_collected` fires, `call_deferred("queue_free")` is scheduled; DC's `_exit_tree()` fires during section unload; the deferred free against an already-freeing body is a safe no-op. No crash, no error log.
Evidence: `tests/integration/document_collection/edge_cases_test.gd` — `test_pickup_plus_section_transition_same_frame`.

**AC-DC-11.3** [Integration] [ADVISORY]
**GIVEN** DC has no direct dependency on Stealth AI, Combat & Damage, Civilian AI, Inventory, Settings, or Post-Process Stack (§F.4 Forbidden Non-Deps), **WHEN** a dependency graph analysis is run, **THEN** `document_collection.gd` contains zero `preload`, `load`, or `class_name` references to those systems.
Evidence: CI dependency-graph lint or static analysis grep for forbidden class names in `document_collection.gd`.

### H.12 — MVP Plaza Tutorial Set Smoke Check (CR-9 MVP scope; V.6; A.1)

**AC-DC-12.1** [Integration] [BLOCKING]
**GIVEN** a MVP build with the Plaza section loaded, **WHEN** the player walks the critical path and presses E on the security logbook, **THEN** body disappears snap-clear on the same frame (no tween, no animation — V.6); the paper-slide SFX plays within 100 ms (Audio A.1 pickup cue); no UI counter increments; no achievement popup fires. The two off-path documents (tourist register, maintenance clipboard) remain active until the player deviates to their locations.
Evidence: Smoke check pass log at `production/qa/smoke-[date].md` + QA observer sign-off.

**AC-DC-12.2** [Visual/Feel] [ADVISORY]
**GIVEN** the Plaza section at MVP, **WHEN** QA performs a visual walk-through with the comic-book outline post-process active at 1080p, **THEN** each of the 3 `DocumentBody` nodes displays a visible Tier 1 (4 px) Ink Black `#1A1A1A` stencil outline; no extra glow, pulse, emission, or world-space annotation is visible; the outline is legible against the Plaza paper base (`#F5EFD6`) at up to 10 m distance.
Evidence: Screenshot sign-off in `production/qa/evidence/dc_visual_pass_plaza.md` + lead sign-off.

### H.13 — QA-Lead Open Flags

**GAP-1 (CR-13 CI lint)**: AC-DC-8.1's no-quest-counter aggregate-method grep is not currently enumerated in the §C.5.6 lint table. Should be added as **lint #9** to §F.5 item #4 scope before the Tools-Programmer CI implementation ticket closes. Tracked in §Open Questions.

**GAP-2 (Engine VG contingencies)**: AC-DC-2.1 + AC-DC-5.1 assume VG-DC-1 (Jolt-safe `call_deferred("queue_free")`) and VG-DC-2 (`Array[StringName].duplicate()` aliasing break) verify positively. If either VG returns negative, these ACs must be revised. Tracked in §Open Questions and §F.5 advisory list.

**Forward-dep BLOCKED summary**:
- AC-DC-6.1 / 6.2 / 6.3 / 6.4 — BLOCKED on Document Overlay UI #20 GDD (VS sprint gate)
- AC-DC-5.4 integration evidence — BLOCKED on Document Overlay UI #20 GDD
- AC-DC-8.4 full integration evidence — BLOCKED on HSS #19 GDD

## Open Questions

### BLOCKING for MVP sprint (must close before sprint planning)

**OQ-DC-1** [BLOCKING — ADR-0008 amendment] — DC sub-slot claim of 0.05 ms peak event-frame must be registered in `docs/architecture/architecture.yaml` §Pooled Residual. Joins existing claims (CAI 0.30 ms p95 (revised 2026-04-25 from 0.15 ms; civilian-ai.md §F.3 + AC-CAI-7.1), MLS 0.1 ms steady + 0.3 ms peak, F&R). **Owner**: Technical Director (architecture-decision skill). **Target**: before MVP sprint kickoff.

**OQ-DC-2** [BLOCKING — MLS GDD §C.5 amendment] — Plaza section scene must include `documents/` Node3D group with 3 pre-authored `DocumentBody` children (§C.5.3 Plaza tutorial set: Security post logbook on-path + Tourist-desk register off-path + Maintenance-crew clipboard off-path). Plus `Section/Systems/DocumentCollection` system node and `&"critical_path"` spline node. **Owner**: Mission & Level Scripting GDD author (revision pass). **Target**: before MVP sprint kickoff.

**OQ-DC-3** [BLOCKING — Localization Scaffold authoring guideline] — Add CR-19 BQA-never-expanded content rule (`/localize` skill greps `bureau of qu` AND `bureau des affaires` AND any other locale-specific acronym expansion on every CSV change — see writer brief §4 BQA Register Guide for the locale-enforcement scope expanded 2026-04-27); add `ui.interact.pocket_document` translation key (MVP fallback for HUD prompt); add `ui.interact.read_document` translation key (default for VS). Plus, document the `doc.[id].title` / `doc.[id].body` key pattern with tonal `# context` notes referencing `design/narrative/document-writer-brief.md` (authored 2026-04-27 — see Open Question deferred-design list). **Owner**: Localization Scaffold GDD author (revision pass). **Target**: before MVP sprint kickoff.

**OQ-DC-4** [BLOCKING — Section-validation CI implementation] — Tools-Programmer must implement 9 CI lint rules: §C.5.6 #1-6 (non-null Document export + unique IDs + section_id match + 0.15 m separation + layer exclusivity + height [0.4, 1.5] m) + §E.17 #7 (DocumentCollection node presence) + §E.28 #8 (critical_path_spline presence) + H.13 GAP-1 #9 (no-quest-counter grep for `get_collected_count` / `get_total_count` / `is_complete` / `get_completion_percent`). Lint ownership joins the existing MLS section-validation CI. **Owner**: Tools-Programmer. **Target**: MVP sprint scope — must ship before first integration tests.

**OQ-DC-5** [BLOCKING — Audio `gameplay_session_ended` signal contract] — Audio needs to immediately stop in-flight DC-triggered `AudioStreamPlayer` instances when player save-quits to Main Menu with a Document Overlay open (§A.4). Coordinate with Lead Programmer; ADR-0002 amendment may be required if `gameplay_session_ended` (or equivalent) signal does not yet exist. **Owner**: Audio GDD author + Lead Programmer + ADR-0002. **Target**: VS sprint kickoff (not blocking for MVP since Document Overlay UI is VS-scope).

### BLOCKING for VS sprint

**OQ-DC-6** [BLOCKING — VS sprint gate] — MLS GDD §C.5 VS expansion: full 21-doc roster placement across all 5 sections per §C.5.1 distribution (Plaza 3 / Lower 4 / Restaurant 6 / Upper 5 / Bomb 3 = 21 total) + §C.5.4 interact-distance authoring + §C.5.5 priority-stack authoring + per-section LD walkthrough sign-off (E.30). **Owner**: Mission & Level Scripting GDD author + Level Designer. **Target**: VS sprint kickoff.

**OQ-DC-7** [BLOCKING — VS sprint gate] — Document Overlay UI #20 GDD (when authored) must adopt:
- `DC.open_document(id)` / `DC.close_document()` consumer pattern (CR-11/12)
- `NOTIFICATION_TRANSLATION_CHANGED` handling for live locale change (E.20)
- `PostProcessStack.enable_sepia_dim()` / `disable_sepia_dim()` lifecycle on open/close
- `tr(title_key)` + `tr(body_key)` resolution (no key caching at `_ready` per Localization CR-9)
- Single-document-at-a-time UX guarantee (close current Overlay before opening new)

**Owner**: Document Overlay UI #20 GDD author. **Target**: VS sprint kickoff.

**OQ-DC-8** [BLOCKING — VS sprint gate] — HUD State Signaling #19 GDD (when authored) must subscribe `Events.document_collected(id)` and emit pickup toast "DOCUMENT COLLECTED: [tr(title_key)]" with reduced-motion + locale-change re-resolution discipline. **Owner**: HSS #19 GDD author. **Target**: VS sprint kickoff.

### ADVISORY (engine verification gates)

**OQ-DC-VG-1** [ADVISORY — Godot 4.6 verification] — Confirm `StaticBody3D.call_deferred("queue_free")` during a signal handler is safe in Jolt 4.6 (deferred body removal queue alignment with scene-tree reaping; no spurious "Body was not in world" warnings). 5-min editor session. If negative: revise CR-3(i) + AC-DC-2.1 to use immediate `queue_free()` with manual physics-body deferral. **Owner**: gameplay-programmer. **Target**: before MVP integration tests.

**OQ-DC-VG-2** [ADVISORY — Godot 4.6 verification] — Confirm `duplicate()` on `Array[StringName]` inside a Resource sub-resource is sufficient for ADR-0003 deep-copy discipline (vs requiring `duplicate_deep()` — a Godot 4.5+ post-cutoff API). If negative: revise CR-6 to use `duplicate_deep()`. **Owner**: gameplay-programmer. **Target**: before MVP integration tests.

**OQ-DC-VG-3** [ADVISORY — Godot 4.6 verification] — Confirm `_ready()` ordering — DC's `_ready()` fires AFTER restore callback applies state via `LevelStreamingService.register_restore_callback`. Verify section scene tree placement of `Section/Systems/DocumentCollection` provides deterministic ordering relative to `Section/Documents/` group. If non-deterministic: redesign CR-5 to use a 2-phase init or explicit `await` on the restore callback completion. **Owner**: gameplay-programmer + Level Streaming Service GDD owner. **Target**: before MVP integration tests.

**OQ-DC-VG-4** [ADVISORY — Godot 4.6 verification] — Confirm `.tres` hot-reload re-sets `@export var document` on `DocumentBody` references in editor; no caching of `document.id` at body `_ready()` time should leak stale state. Developer-only edge case (E.18). If problematic: document the dev-guide rule "reload section after `.tres` edit". **Owner**: gameplay-programmer. **Target**: before content authoring sprint.

### ADVISORY (deferred design / playtest-resolvable)

**OQ-DC-Audio-1** [ADVISORY — Polish-or-later] — Distant-typewriter-from-another-room ambient layer during Document Overlay reading, gated to Restaurant section only (ambient priority 5 lowest, non-spatial, −6 dB below ambient floor). DO NOT implement at MVP; revisit at Polish based on playtest feedback on overlay atmosphere. **Owner**: Audio GDD owner. **Target**: Polish phase.

**OQ-DC-Archive-1** [ADVISORY — Polish-or-later] — Case-file archive Pause Menu shortcut (browse collected documents by section). Belongs to Menu System #21 (already designed) as a Pause submenu. Reads `DocumentCollectionState.collected` directly from `SaveGame` — does NOT add a count-broker method to DC (CR-13 absolute holds). Design decision: deferred to Polish-or-later; MVP/VS ship without this surface. **Owner**: Menu System GDD revision (Polish phase). **Target**: Polish phase or post-launch.

**OQ-DC-Cluster-1** [ADVISORY — design choice] — Audio cluster routing: how does Audio map a `document_collected(id)` signal to a 3-cluster pickup SFX variant (§A.2)? Two candidates:

- (a) DC exposes `get_document_type(id) -> StringName` query method (couples DC to audio-routing concerns)
- (b) Audio lazy-loads `res://documents/[id].tres` on signal receipt and reads `Document.type` directly (preserves DC's "subscribe-only" boundary)

Recommended (per audio-director): option (b). **Owner**: Audio GDD revision + Lead Programmer. **Target**: pre-VS content authoring (Audio cluster assets are VS-tier).

**OQ-DC-Personal-1** [ADVISORY — content authoring] — Personal Communication category (§C.4 type 7) caps at 4–5 across full roster per narrative-director recommendation. Final count to be set during writer brief at `/localize` time; current G.1 default is 5. Revisit during Restaurant + Upper Structure document authoring. **Owner**: Writer + Narrative Director. **Target**: VS content authoring.

### Deliberately Omitted (consciously not in scope)

The following are NOT open questions — they are conscious refusals per Pillar/Forbidden-Pattern locks. Recorded here so future agents do not re-open them:

- **Voice-acted documents** — FP-DC-4 / AFP-DC-4 (Pillar 1 — page does the comedy, not Eve)
- **Runtime document spawning** — FP-DC-9 (all documents level-design-time authored)
- **Per-document gameplay effects** (read doc → unlock gadget) — FP-DC-7 (documents are purely narrative)
- **Achievement popup on first/Nth collection** — FP-DC-3 / AFP-DC-6 (Pillar 5)
- **"X of Y documents collected" UI counter anywhere** — CR-13 + FP-DC-2 absolute (Pillar 5)
- **Hold-E-to-collect mechanic** — FP-DC-1 (Pillar 5; pickup is single-press)
- **Extra glow / pulse / emission beyond Tier 1 outline** — FP-V-DC-1 / -2 / -5 (Pillar 5; Outline Pipeline is sole visual layer)
- **Floating ?/! markers / world-space annotation** — FP-V-DC-3 (Pillar 5)
- **Differentiated pickup SFX for first-collect / story-critical / completion-fanfare** — AFP-DC-2 / -3 / -6 (Pillar 5)
- **BQA acronym expanded in any document** — CR-19 / FP-DC-11 (Pillar 1 typographic comedy)
- **Documents written in Eve's voice** — §C.8 forbid #4 (Eve receives, doesn't author)
- **Documents that contain waypoints / objective markers / tutorial text** — §C.8 forbids #1/#2 (MLS owns objective delivery)
