# Session State

**Last updated:** 2026-04-25 (`/design-system hud-core` **COMPLETE** — solo mode, all 11 sections written to `design/gdd/hud-core.md` (1,182 lines). Phase 5 validation done: registry updated (2 referenced_by + 6 new entries), systems-index row 16 + Progress Tracker (Started 14→15, MVP designed 14→15/16) + Last Updated header updated. **2 ADR-0002 amendments now BLOCKING for sprint** (`ui_context_changed`, `takedown_availability_changed`). Next recommended: `/design-review design/gdd/hud-core.md` in a fresh session.)

## Current Task — `/design-system hud-core` **COMPLETE 2026-04-25**

- **Task**: `/design-system hud-core` — system #16, UI/Presentation layer, MVP tier, M effort
- **Review mode**: `solo` (CD-GDD-ALIGN gate at Phase 5a-bis skipped per `.claude/docs/director-gates.md`)
- **File**: `design/gdd/hud-core.md` (**1,182 lines**, 82 section headers — all 11 sections complete)
- **Pillar alignment**: Primary 5 (Period Authenticity) + Primary 2 (Discovery — "no waypoints"); Secondary 1 (Comedy — HUD silent) + 3 (Theatre — critical-state cue) + 4 (Locations — modesty)
- **Status**: **COMPLETE** — all 15 tasks done. Ready for `/design-review` in fresh session.

### Sections written

- §Overview ✅ (1 dense paragraph — both-framing + ADR-0002/0004/0008 cited + boundary statement)
- §Player Fantasy ✅ (Candidate A "The Glance" — cockpit-dial fantasy + 2 primary + 3 secondary pillars + 5 explicit refusals + fantasy test for future additions)
- §Detailed Design ✅ (C.1 20 Core Rules + C.2 5-widget grammar/anchor table + C.3 3-state prompt-strip machine + C.4 damage-flash narrative + C.5 16-row Interactions matrix + 4 BLOCKING + 3 ADVISORY coord items + bidirectional check + C.6 14 Forbidden Patterns)
- §Formulas ✅ (F.1 photosensitivity rate-gate aligned with Audio §F.4 / F.2 critical-state edge-trigger / F.3 viewport scale [0.667, 2.0] / F.4 crosshair radius [3, 12] / F.5 frame-cost composition with 0.259 ms worst-case vs 0.3 ms cap + dry-fire NOT-rate-gated rationale)
- §Edge Cases ✅ (37 cases across 10 clusters: A same-frame storms / B critical-state boundaries / C flash coalescing / D prompt-strip lifecycle / E InputContext+visibility / F save/load / G settings+localization / H performance / I subscriber lifecycle / J pillar-violation guards)
- §Dependencies ✅ (8 hard upstream + 2 soft + 3 forward dependents + 8 ADR + 7 forbidden non-deps + 4 BLOCKING + 3 ADVISORY coord items + 9-row bidirectional consistency check)
- §Tuning Knobs ✅ (G.1 5 HUD-owned + G.2 6 Combat/PC-owned references + G.3 11 Art-Bible-owned visual constants + G.4 4 forward-dep Settings knobs + G.5 ownership matrix)
- §Visual/Audio ✅ (V.1 StyleBoxFlat specs for 5 widget bgs + key-rect / V.2 5-asset list / V.3 per-widget render trees / V.4 damage-flash composition / V.5 critical-state transition / V.6 crosshair _draw() with full GDScript / V.7 14-item visual-restraint compliance check + Asset Spec Flag; A.1 4 audio contracts (HUD owns ZERO audio) + A.2 mix bus reference)
- §UI Requirements ✅ (UI-1 flow boundaries / UI-2 10-row accessibility floor Day 1 vs Polish vs forward-dep / UI-3 HSS extension API via `get_prompt_label()` / UI-4 UX Flag for `/ux-design hud-core` Phase 4)
- §Acceptance Criteria ✅ (73 ACs across 12 groups: H.1 lifecycle 5 / H.2 health 7 / H.3 photosensitivity 6 / H.4 weapon+ammo 6 / H.5 gadget 6 / H.6 prompt-strip 7 / H.7 crosshair 5 / H.8 input-context 4 / H.9 performance 5 / H.10 forbidden-pattern grep gates 13 / H.11 locale+a11y 5 / H.12 save/load 4)
- §Open Questions ✅ (6 OQs — 2 BLOCKING (OQ-HUD-3 Settings boot order, OQ-HUD-4 LSS restore-callback ordering) + 4 ADVISORY; 10 deliberately-omitted items consciously excluded from MVP)

### Specialist consultations (all section-mandatory per skill)

- **creative-director** (§B): 3 candidate framings — A "The Glance" (cockpit-dial register), B "Numeral Goes Orange" (theatrical cue), C "Furniture Not Theatre" (modest dashboard). User selected **Candidate A** (Pillar 5 + 2 primary; matches Inventory "Crouched Swap" precedent register)
- **ux-designer** (§C widget grammar + prompt-strip lifecycle + accessibility floor): 5-widget anchor table; 3-state machine resolver with priority TAKEDOWN > INTERACT > HIDDEN; F.4 crosshair clamp; auto-dismiss timer at 2.0s (deferred to HSS via MEMO defer)
- **game-designer** (§C 20 Core Rules + photosensitivity semantics + state machine): full CR set; F.1 photosensitivity gate algorithm with player_died `_flash_timer.stop()` requirement
- **godot-specialist** (§C Godot 4.6 feasibility): signal subscription via `Events.signal.connect(handler)`; explicit `_exit_tree()` disconnect with `is_connected()` guard (ADR-0002 §Impl Guideline 3 mandates); CanvasLayer at index 1; tree-order z within layer; `add_theme_color_override` over theme swap; `await get_tree().process_frame` for damage flash; child Timer node (oneshot 333 ms) over SceneTreeTimer; `_draw()` over nested ColorRects for crosshair; flagged ADR-0004 Gate 2 (Theme inheritance prop name) + Gate 1 (accessibility_live prop name) as BLOCKING; recommended ADR-0002 amendment for ui_context_changed
- **systems-designer** (§D + §E): F.1 validated with `_flash_timer.stop()` correction; F.2 with `max(max_health, 1.0)` divide-by-zero floor; F.5 frame-cost composition; 37 edge cases across 10 clusters with `is_instance_valid` guard requirement on prompt-strip
- **art-director** (§V): StyleBoxFlat specs for 5 widget backgrounds + key-rect; 5-asset list; per-widget render trees; crosshair `_draw()` with full GDScript; Ink Black `#1A1A1A` confirmed against Art Bible §4.4; 14-item visual-restraint compliance check
- **qa-lead** (§H): 73 ACs across 12 groups; Logic/Integration BLOCKING + UI/Visual ADVISORY; AC-HUD-pillar-1 + AC-HUD-pillar-2 scene-tree CI scans (kill-confirmed + damage-direction guards)

### User-approved design decisions via AskUserQuestion (4 blockers)

1. **HUD visibility on InputContext change** → Add `ui_context_changed(new_ctx, prev_ctx)` signal to ADR-0002 (UI domain) — BLOCKING coord item
2. **TAKEDOWN_CUE eligibility detection** → Add `takedown_availability_changed(eligible, target)` signal to ADR-0002 (SAI domain) — BLOCKING coord item, bundles with #1
3. **MEMO_NOTIFICATION scope** → Defer entirely to HUD State Signaling (system #19, VS); HUD Core MVP prompt-strip = HIDDEN/INTERACT_PROMPT/TAKEDOWN_CUE only
4. **Empty gadget tile rendering** → Render dimmed 40% opacity (geometry stability over hide-when-empty)

### F.2 unit-mismatch fix (registry conflict caught at Phase 5b self-check)

Registry has `player_critical_health_threshold = 25 hp_percent` (canonical at max_health=100). Initial F.2 wrote `(health_ratio < 0.25)` mixing units. Fixed F.2 to `(health_ratio < threshold_ratio)` where `threshold_ratio = player_critical_health_threshold / 100.0`. Pattern aligns with Audio GDD §F.4 clock-tick trigger (identical canonical pattern). Registry note expanded with Audio/HUD divide-by-100 contract.

### Registry Phase 5b (2 referenced_by + 6 NEW entries)

- **2 referenced_by updates**: `player_max_health.referenced_by += hud-core.md` (F.2 ratio computation); `player_critical_health_threshold.referenced_by += hud-core.md + audio.md` (Audio §F.4 was never registered as such); unit clarified `hp` → `hp_percent` with note documenting Audio/HUD divide-by-100 canonical pattern
- **6 NEW entries**:
  - `hud_damage_flash_cooldown_ms = 333` ms safe [200, 500] — Combat-owned, HUD-enforced WCAG 2.3.1 photosensitivity gate
  - `crosshair_dot_size_pct_v = 0.19%` safe [0.15, 0.30] — Combat-owned, HUD F.4 dot radius computation
  - `crosshair_halo_style = tri_band` enum — Combat-owned, HUD V.6 _draw() composition
  - `crosshair_enabled = true` bool — Combat-owned default, Settings-persisted opt-out
  - `gadget_rejected_desat_duration_s = 0.2` s safe [0.1, 0.5] — HUD-owned NEW knob
  - `HUDCore` cross_system_class — CanvasLayer scene at index 1, NOT autoload, public extension API `get_prompt_label()` for HSS forward-extension

### Pre-implementation coord items OPEN (4 BLOCKING + 3 ADVISORY)

**4 BLOCKING for sprint:**
1. ADR-0002 amendment: add `ui_context_changed(new_ctx: InputContextStack.Context, prev_ctx: InputContextStack.Context)` signal (UI domain)
2. ADR-0002 amendment: add `takedown_availability_changed(eligible: bool, target: Node3D)` signal (SAI domain) — bundle with #1
3. ADR-0004 Gate 2: confirm Theme inheritance property name (`base_theme` vs `fallback_theme`) — 5-min editor inspection (godot-specialist flagged unverified against training data which expects `fallback_theme`)
4. ADR-0004 Gate 1: confirm `accessibility_live` property name on Godot 4.6 Label/Control — deferrable to Polish per ADR-0004 §10, BLOCKING for VS

**3 ADVISORY:**
5. Settings & Accessibility GDD (system #23) when authored — define `crosshair_enabled / crosshair_dot_size_pct_v / crosshair_halo_style` + locale-change `setting_changed` emit-site contract
6. HUD-scale slider as Settings forward-dep (OQ-HUD-1) — not in HUD Core MVP scope
7. Combat §UI-6 dual-discovery path requires Settings GDD authoring

### 6 Open Questions captured in §Open Questions

- **OQ-HUD-1 [ADVISORY]**: HUD scale slider Settings forward-dep
- **OQ-HUD-2 [ADVISORY]**: `_pending_flash` clear on visibility=false — playtest decision
- **OQ-HUD-3 [BLOCKING for sprint integration]**: Settings boot ordering vs HUD `_ready()` integration verification
- **OQ-HUD-4 [BLOCKING for VS]**: LSS restore-callback signal-replay ordering — engine verification gate
- **OQ-HUD-5 [ADVISORY]**: `C_label` >0.05 ms breach contingency — performance ADR amendment trigger
- **OQ-HUD-6 [ADVISORY]**: Crosshair default ON vs OFF — playtest decision

### Files modified this session

- `design/gdd/hud-core.md` — **NEW** (1,182 lines)
- `design/registry/entities.yaml` — 2 referenced_by updates + 6 new entries appended; `last_updated` header updated
- `design/gdd/systems-index.md` — row 16 Status updated to Designed; Progress Tracker counts updated (Started 14→15, MVP designed 14→15/16); Last Updated header updated
- `production/session-state/active.md` — this file

### Context locked (Phase 2 summary)

- Upstream Approved: PC §UI Requirements (signals + queries + HUD-must-NOT-render list), Combat §UI-1..UI-6 (crosshair widget, photosensitivity rate-gate `hud_damage_flash_cooldown_ms = 333`), Inventory §UI-1..UI-9 (4 frozen signals + `gadget_activation_rejected` 0.2 s desat), Civilian AI Pillar 5 zero-UI absolute, F&R empty UI absolute
- ADR constraints: ADR-0008 Slot 7 = 0.3 ms HUD per-frame cap (signal-driven only; polling forbidden); ADR-0004 Theme + FontRegistry + `mouse_filter = MOUSE_FILTER_IGNORE`; ADR-0002 HUD subscribes-only (emits zero signals); ADR-0007 HUD is NOT autoload (CanvasLayer scene per main scene)
- Art Bible §7A-D + §4.4: NOLF1 corner anchors locked (BL health / BR weapon+ammo / TR gadget / center-lower contextual); BQA Blue `#1B3A6B` 85% + Parchment `#F2E8C8` + Alarm Orange `#E85D2A` (<25% HP) + PHANTOM Red `#C8102E` (captured equipment); 1-frame numeral flash on damage, 333 ms cooldown
- Forbidden (Pillar 5 anti-pillars): objective markers / minimap / kill cams / ping systems / waypoints / alert visual indicators / civilians / death screen / retry / stamina bar / damage direction / hit marker / hold-E ring / damage numbers / floating text / radial weapon wheel
- Known cross-system facts: `player_max_health = 100`, `player_critical_health_threshold = 25%`, `hud_damage_flash_cooldown_ms = 333` ms WCAG 3 Hz, `crosshair_dot_size_pct_v = 0.19%`, `crosshair_halo_style = tri_band`, `crosshair_enabled = true` default opt-out

### Next steps

- §Overview framing widget (Framing/ADR-ref/Fantasy tabs) → draft → write
- §Player Fantasy (creative-director MANDATORY) → candidate framings
- §Detailed Design (ux-designer + art-director + game-designer + ui-programmer specialists per routing table for UI category)
- §Formulas (systems-designer for photosensitivity coalesce + critical-threshold transition)
- §Edge Cases (systems-designer for same-frame storm, LOAD_FROM_SAVE replay, sub-frame ammo)
- §Dependencies + §Tuning Knobs + §Acceptance Criteria (qa-lead) + §Visual/Audio (art-director) + §UI Requirements + §Open Questions
- Phase 5b registry sweep + systems-index row 16 update

## Previous Task — `/design-system civilian-ai` **COMPLETE 2026-04-25**

(Civilian AI session entry — preserved below)

**Last updated:** 2026-04-25 (`/design-system civilian-ai` **COMPLETE** — solo mode, all 11 sections written to `design/gdd/civilian-ai.md` (749 lines). Phase 5 validation done: registry updated (7 entries — CivilianAI / CivilianAIState / WitnessEventType / civilian + panic_anchor group tags / cai_frame_budget_ms_p95 / bqa_pickup_distance_m), systems-index row 15 + Progress Tracker updated. **Closes SAI OQ-SAI-1 by spec**. Next recommended: `/design-review design/gdd/civilian-ai.md` in a fresh session.)

## Current Task — `/design-system civilian-ai` **COMPLETE 2026-04-25**

- **Task**: `/design-system civilian-ai` — system #15, Gameplay layer, MVP tier, S effort
- **Review mode**: `solo` (CD-GDD-ALIGN gate at Phase 5a-bis skipped per `.claude/docs/director-gates.md`)
- **File**: `design/gdd/civilian-ai.md` (**749 lines**, all 11 sections written — 8 required + Visual/Audio + UI + Open Questions)
- **Pillar alignment**: Primary 3 (Stealth is Theatre — audience-as-witnesses) + 1 (Comedy chorus — Audio Formula 2 diegetic-recedes); Secondary 2 (BQA tells at VS) + 4 + 5
- **Status**: **COMPLETE** — all 11 tasks done. Ready for `/design-review` in fresh session.

### Sections written

- §Overview ✅ (1 dense paragraph — phased MVP/VS scope + ADR citations + chorus-not-co-star framing)
- §Player Fantasy ✅ (Candidate B "Stealth With Witnesses" — schoolteacher anchor moment, audience makes theatre literal)
- §Detailed Design ✅ (C.1 Core Rules 15 CRs + C.2 State Machine 2-state + C.3 Flee Algorithm 3-phase pseudocode + C.4 Witness Event Trigger Rules VS + C.5 Interactions 11-row table + C.6 Forbidden Patterns 10 grep rules)
- §Formulas ✅ (F.1 panic-trigger predicate + F.2 flee re-target proximity gate + F.3 ADR-0008 0.15 ms p95 budget envelope + F.4 anchor scoring with dot-product filter + F.5 VS witness emission distance gate)
- §Edge Cases ✅ (31 cases across 8 clusters: A same-frame storms / B damage / C save-load / D SAI interaction / E Audio interaction / F NavigationAgent3D / G section reload / H VS-tier scope boundary)
- §Dependencies ✅ (8 upstream + 7 downstream + 6 ADR + 8 forbidden non-deps + 10 coord items + 9-GDD bidirectional consistency)
- §Tuning Knobs ✅ (G.1 panic radii + G.2 flee behavior + G.3 VS witness radii + G.4 BQA pickup VS + G.5 perf budget binding + G.6 ownership matrix)
- §Visual/Audio ✅ (5 V + 5 A subsections — 4 archetypes × 2 variants = 8 meshes + 4-state AnimationTree + Tier 3 default + Tier 1 BQA promotion + Pillar 5 forbidden patterns + signal-publisher-only audio handoff + Pillar 1 reading of Audio Formula 2)
- §UI Requirements ✅ (Pillar 5 zero-UI absolute — civilians never appear in HUD; VS forward-deps only)
- §Acceptance Criteria ✅ (33 ACs across 10 groups — 28 BLOCKING + 5 ADVISORY incl. 4 VS-only)
- §Open Questions ✅ (6 OQs — 3 BLOCKING incl. NavigationAgent3D engine-verification gate + VS feature flag + civilian gasp VO sourcing; 3 ADVISORY playtest-resolvable; 7 deliberately-omitted items)

### Specialist consultations (all section-mandatory per skill)

- **creative-director** (§B): Candidate B "Stealth With Witnesses" framing selected (Pillar 3 primary + Pillar 1 secondary); the audience makes the theatre literal
- **systems-designer** (§C Core Rules + §D Formulas): 15 CRs + 5 formulas with strict template format
- **ai-programmer** (§C state machine + §C.3 flee algorithm + §C.4 witness trigger + §C.5 per-frame budget): 2-state model rationale, hybrid flee algorithm with cower phase, VS-coupled witness emission
- **gameplay-programmer** (§C Godot 4.6 feasibility): NavigationAgent3D.velocity_computed RVO callback pattern, Jolt body_entered reliability at Eve walking speed, set_physics_process gating, OutlineTier.set_tier signature with MeshInstance3D not Node, signal lifecycle, group tags from .tscn auto-registered
- **art-director** (§V): 4 archetypes × 2 variants = 8 meshes; 4-state AnimationTree; Pillar 5 forbidden patterns; AD-COORD-01 BQA composed-geometry tell
- **audio-director** (§A): signal-publisher-only handoff; CAI does NOT own AudioStreamPlayer3D / footsteps / death sounds / dialogue / muzzle / radio
- **qa-lead** (§H): 33 ACs across 10 groups with story-type tags + BLOCKING/ADVISORY tags + evidence paths

### User-approved design decisions via AskUserQuestion

1. **CR-4 kill-signal subscription**: `enemy_killed(actor: Node, killer: Node)` (Combat domain per ADR-0002) — derives cause_position via `actor.global_position` with `is_instance_valid()` guard; CAI does NOT subscribe to `guard_incapacitated` (UNCONSCIOUS chloroform takedowns are STEALTH successes — chorus must not ruin them)
2. **CR-10 LOAD_FROM_SAVE restore behavior**: recompute flee target from saved `_cause_position` (serialize `{ panicked: bool, cause: Vector3 }` per civilian); civilian resumes fleeing on restore (preserves Player Fantasy anchor — schoolteacher resumes walking toward viewing platform); NO `civilian_panicked` re-emit (Audio rebuilds `panic_count` via group query of `get_tree().get_nodes_in_group("civilian")`)

### Registry Phase 5b (7 NEW entries written to `design/registry/entities.yaml`)

- **3 cross-system Resource/enum types**: `CivilianAI` (CharacterBody3D entity + class), `CivilianAIState` (save sub-resource — Dictionary[StringName, Dictionary] keyed by actor_id), `WitnessEventType` (cross_system_enum owned by CivilianAI per ADR-0002 enum-ownership rule)
- **2 group tags**: `civilian` (the only allowed group; SAI E.14 vision filter rejects civilians from this group; Audio queries this for panic_count rebuild), `panic_anchor` (level-designer-authored Marker3D group; CAI flee algorithm queries for §C.3 Phase 2 selection)
- **2 perf/VS constants**: `cai_frame_budget_ms_p95 = 0.15` (ADR-0008 Slot #8 sub-claim), `bqa_pickup_distance_m = 3.0` (VS-only outline-tier promotion radius)
- **No existing-entry `referenced_by` updates** — civilians don't carry weapons (Inventory CR-7a) so no WorldItem/Checkpoint/etc. updates needed

### SAI OQ-SAI-1 CLOSED by CAI sign-off

SAI's deferred OQ-SAI-1 — "Guard-to-civilian propagation bidirectional? (Does a panicking civilian cascade-alert multiple guards?)" — is **closed** by CAI's spec:
- F.5 + CR-12: at VS, `civilian_witnessed_event` propagates to ALL guards within their own perception radius (SAI handles propagation)
- CAI emits at most ONCE per civilian per section (one-shot latch `_witnessed_event_already_emitted`)
- Bidirectional cascade is allowed because the per-civilian latch caps signal traffic regardless of guard count
- Coord item §F.5#10: SAI OQ-SAI-1 should be updated to "Closed by civilian-ai.md F.5 + CR-12 — 2026-04-25"

### Pre-implementation coord items open (10 items)

**4 BLOCKING for MVP sprint:**
1. ADR-0002 amendment — `CivilianAI.WitnessEventType` enum stub for `Events.gd` compile (atomic-commit per ADR-0002)
2. ADR-0008 amendment — 0.15 ms Slot #8 sub-claim registration in `docs/registry/architecture.yaml`
3. OQ-CAI-3 engine-verification gate — Godot 4.6 NavigationAgent3D.is_navigation_finished() lag + LSS register_restore_callback ordering
4. PC GDD touch-up coord (already noted by F&R) — get_first_node_in_group("player") fallback for VS BQA pickup

**1 BLOCKING for VS sprint (not MVP):**
5. ADR-0001 status (Proposed → Accepted) — BQA contact outline promotion enforceable when ADR-0001 lands
6. Inventory weapon_drawn_in_public signal — F.5 EVE_BRANDISHING_WEAPON event source (or repurpose gadget_activated)
7. OQ-CAI-4 — VS feature flag mechanism (compile-time gate for CR-12 + CR-14)

**1 BLOCKING for MVP playtest (not sprint start):**
8. OQ-CAI-6 — Civilian gasp VO sourcing (carry-forward from Audio L689 coord item)

**6 ADVISORY:**
9. Audio §Concurrency Rule 5 dead-code annotation
10. Signal Bus L122 handler-table verification post-this-GDD
11. MLS L679 outline-tier reconciliation (says "Medium tier" — OP L112 says "Tier 3 LIGHT", OP authoritative)
12. Save/Load CivilianAIState `cause: Vector3` schema touch-up
13. panic_anchor section-validation CI extension (coord with MLS §C.5.6)
14. SAI OQ-SAI-1 closure note (should reference this GDD)

### 6 Open Questions captured in §Open Questions

- **OQ-CAI-1 [ADVISORY]**: F.5 witness-latch trade-off (closer-event suppression)
- **OQ-CAI-2 [ADVISORY]**: F.4 anchor scoring weight (Euclidean vs path-distance)
- **OQ-CAI-3 [BLOCKING]**: Godot 4.6 NavigationAgent3D engine-verification gate
- **OQ-CAI-4 [BLOCKING for VS]**: VS feature flag mechanism
- **OQ-CAI-5 [ADVISORY]**: CALM-state animation ownership (CAI vs MLS-T6 vs AnimationTree default)
- **OQ-CAI-6 [BLOCKING for MVP playtest]**: Civilian gasp VO sourcing

### Files modified this session

- `design/gdd/civilian-ai.md` — **NEW** (749 lines)
- `design/registry/entities.yaml` — 7 new entries appended
- `design/gdd/systems-index.md` — row 15 Status updated to Designed; Progress Tracker counts updated (Started 13→14, MVP designed 13→14/16); Last Updated header updated
- `production/session-state/active.md` — this file

### Previous task — see "Previous Task" sections below

## Current Task — `/design-system mission-level-scripting` **COMPLETE 2026-04-24**

- **Task**: `/design-system mission-level-scripting` — system #13, Gameplay layer, MVP tier, M effort
- **Review mode**: `solo` (CD-GDD-ALIGN gate at Phase 5a-bis skipped per `.claude/docs/director-gates.md`)
- **File**: `design/gdd/mission-level-scripting.md` (**834 lines**, all 11 sections written — 8 required + Visual/Audio + UI + Open Questions)
- **Pillar alignment**: Primary 1 (Comedy) + 4 (Iconic Locations); Secondary 2 (Discovery) + 3 (Theatre)
- **Status**: **COMPLETE** — all 12 tasks done. Ready for `/design-review` in fresh session.

### Sections written

- §Overview ✅ (1 dense paragraph — MLS 5 responsibilities + pillar binding + ADR citations)
- §Player Fantasy ✅ (Candidate B "briefing ended before the game began" — BQA Nagra reel, Paris canonical)
- §Detailed Design ✅ (C.1 Core Rules 20 rules + C.2 Mission State Machine + C.3 Objective State Machine + C.4 Scripted-Moment Taxonomy 7 types + C.5 Section Authoring Contract 6 subsections + C.6 Per-Section Iconic Beats × 5 + C.7 Interactions table + C.8 Forbidden Patterns 8 FPs)
- §Formulas ✅ (F.1 mission-complete gate + F.2 can-activate + F.3 alert-comedy budget + F.4 SaveGame timing + F.5 supersede-cascade + F.6 cache distribution + F.7 trigger single-fire latch — 7 formulas)
- §Edge Cases ✅ (36 edge cases across 8 clusters: same-frame storms, RESPAWN, save/load, authoring violations, Jolt, state corruption, cross-GDD, autoload lifecycle)
- §Dependencies ✅ (11 upstream + 7 downstream + 6 ADR deps + 7 forbidden non-deps + 12 coord items + bidirectional consistency)
- §Tuning Knobs ✅ (7 subsections — scripted behaviour, SaveGame assembly, cache placement, supersede, Inventory-locked caps, CI constants, Pillar-1 absolutes)
- §Visual/Audio ✅ (4 visual + 5 audio subsections + asset-spec flag + new Audio coord item)
- §UI Requirements ✅ (MVP zero-UI absolute + 4 VS-tier forward deps + public API)
- §Acceptance Criteria ✅ (50 ACs across 13 groups — 42 BLOCKING Logic/Integration + 8 ADVISORY)
- §Open Questions ✅ (12 OQs — 4 BLOCKING pre-impl, 12 coord items, 9 deferred)

### Specialist consultations (all section-mandatory per skill)

- **creative-director** (§B): Candidate B fantasy framing selected, Paris-canonical rewrite applied
- **game-designer** (§C.1): 15 CR proposal synthesized into final 20 CRs
- **level-designer** (§C.5): Section Authoring Contract — 6 subsections structured
- **systems-designer** (§C.2-C.3 state machines + §C.7 Interactions + §D formulas + §E 36 edge cases)
- **narrative-director** (§C.4 taxonomy + §C.6 per-section beats + Pillar-1 enforcement)
- **gameplay-programmer** (§C Godot 4.6 feasibility: autoload vs per-section, Area3D triggers, SaveGame assembly, MissionObjective as Resource, ADR-0008 sub-slot claim)
- **qa-lead** (§H): 50 ACs authored with story-type tags

### User-approved design decisions via AskUserQuestion

1. **Scripted-beat re-fire policy**: savepoint-persistent (do NOT re-fire on RESPAWN) — matches NOLF1 + simpler state
2. **SUPERSEDED objective transition**: implicit (no 5th Mission-domain signal) — keeps ADR-0002 at 4 signals
3. **WorldItem cache placement ownership**: MLS GDD owns policy + Level Designer executes
4. **LOAD_FROM_SAVE re-emit**: suppress `objective_started`; HUD rebuilds from snapshot via `get_active_objectives()`
5. **Q1 F.3 COMBAT T6 suppression**: fully suppressed at COMBAT (no budget tracked)
6. **Q2 F.4 overflow**: push_error + proceed (don't lose save); ADR-0008 amendment flagged as follow-up
7. **Q3 F.5 cascade abort**: partial-supersede (depths 1-3 stand; no rollback)
8. **Q4 F.6 off-path distance**: authoring guideline + playtest (no CI-derived centerline at MVP)

### Registry Phase 5b (14 NEW entries written to `design/registry/entities.yaml`)

- **5 cross-system Resource types**: `MissionResource`, `MissionObjective`, `MissionState`, `MLSTrigger`, `MissionScriptingService` autoload
- **9 constants**: `alert_comedy_budget` (2), `SUPERSEDE_CASCADE_MAX` (3), `off_path_min_distance_m` (10.0), `pistol_per_section_max` (3), `pistol_per_2_section_min` (1), `dart_min_sections_span` (2 fixed), `medkit_per_section_max` (1), `t_capture_i_budget_ms` (1.0), `t_assemble_total_ceiling_ms` (5.0)
- MLS formulas F.1/F.2/F.5/F.7 are MLS-internal predicates — NOT registered per registry README rule ("only register facts that cross system boundaries")
- **No existing-entry `referenced_by` updates needed** (WorldItem, Checkpoint, FailureRespawnState, fr_checkpoint_marker_node_name, phantom_guard all already list MLS)

### F&R BLOCKING coord item #11 CLOSED by MLS sign-off

F&R's pre-impl gate "Mission Scripting PROVISIONAL — `player_respawn_point: Marker3D` authoring + non-deferred + section-validation CI" is **satisfied** by:
- CR-9 (mandatory Marker3D per section scene)
- §C.5.1 (required nodes table)
- §C.5.6 (CI validation rules — BLOCKING)

### Pre-implementation coord items open (12)

1. ADR-0007 amendment naming MLS at slot #9 (bundle with F&R's slot-#8 amendment)
2. ADR-0003 + save-load.md schema for `MissionState` sub-resource (OQ-MLS-2 BLOCKING — F&R `triggers_fired` capture)
3. ADR-0008 §Pooled Residual sub-slot claim
4. Signal Bus GDD L122 handler-table touch-up (6 MLS subscriber rows)
5. Inventory GDD §F bidirectional MLS-owns-placement note
6. F&R coord item #11 closure (on MLS approval)
7. LSS GDD §Interactions `register_restore_callback` row
8. Localization Scaffold review gate
9. Section-validation CI implementation (Tools Programmer)
10. MLSTrigger self-passivity contract (OQ-MLS-6)
11. Cutscenes & Mission Cards (VS) forward API verification
12. Audio GDD §Mission-domain amendment (LOAD suppression + T4 Fire-Drill Klaxon spec + T6 Alert-Comedy bark bank)

### 12 Open Questions captured in §Open Questions

- **BLOCKING pre-impl (4)**: OQ-MLS-2 (triggers_fired capture), OQ-MLS-3 (_is_section_live guard), OQ-MLS-6 (MLSTrigger self-passivity), OQ-MLS-9 (FP-8 grep vs manual)
- **Deferred / post-MVP (8)**: OQ-MLS-1 (LD authoring constraint), -4 (SectionBoundsHint CI), -5 (LD guide narrative-critical distinction), -7 (reachability validator), -8 (mission_load_failed signal), -10 (mission-completed handoff), -11 (Restaurant sub-room scope), -12 (triggers_fired Array vs Dict), -ANIM-1 (Biscuit Tin animation budget)

### Files modified this session

- `design/gdd/mission-level-scripting.md` — **NEW** (834 lines)
- `design/registry/entities.yaml` — 14 new entries appended; `last_updated` comment updated
- `design/gdd/systems-index.md` — row 13 Status updated to Designed; Progress Tracker counts updated (Started 12→13, Approved 7 unchanged + 1 new Designed-pending-review, MVP designed 12→13/16); Last Updated header updated
- `production/session-state/active.md` — this file

## Previous Task — `/design-review failure-respawn.md` **COMPLETE 2026-04-24**

### Forward coord items MLS must close (pre-impl gates from prior GDDs)

1. **F&R BLOCKING item #11** — `player_respawn_point: Marker3D` section-authoring contract + non-deferred + section-validation CI
2. **Inventory forward-hook** — WorldItem cache plan (8 pistol + 2 dart-off-path + medkit-cap 3/mission + rifle-carrier 1/section); mission-gadget satchel (Parfum) in Eiffel restaurant
3. **ADR-0007 amendment** — MLS autoload registration at slot #9 (after F&R at slot #8; originally reserved for Civilian AI / MLS / Document Collection shared; F&R claimed #8 first)
4. **ADR-0008 sub-slot claim** — MLS claims share of 0.8 ms residual pool (6 systems)
5. **Cutscenes & Mission Cards forward API** — define trigger contract MLS will expose (VS tier consumer)

### Locked upstream contracts (non-negotiable)

- **ADR-2 Mission domain signals**: `mission_started/completed`, `objective_started/completed` (MLS-owned emit)
- **ADR-2 subscriber**: `section_entered(reason: TransitionReason)` — MLS gates autosave on FORWARD only
- **ADR-3 SaveGame assembler**: MLS builds SaveGame by reading each system's `capture()`; synchronous only
- **architecture.md L639**: RESPAWN must NOT autosave (would overwrite good state with dead state)

### Specialist consultations planned

- **Section B**: creative-director (mandatory per skill)
- **Section C**: game-designer + level-designer + systems-designer + narrative-director (scripting = Pillar 1 load-bearing)
- **Section D**: systems-designer
- **Section E**: systems-designer + narrative-director
- **Section H**: qa-lead (mandatory per skill)
- **Visual/Audio**: art-director + audio-director (mandatory for narrative category)

## Previous Task — `/design-review failure-respawn.md` **COMPLETE 2026-04-24**

- **Task**: `/design-review design/gdd/failure-respawn.md` with 7-specialist + CD full-mode synthesis
- **File**: `design/gdd/failure-respawn.md` (513 → 553 lines)
- **Verdict**: MAJOR REVISION NEEDED → inline revision applied in same session → user elected Accept + mark Approved pending coord items (CD recommendation to re-review in fresh session overridden by user)
- **New file**: `design/gdd/reviews/failure-respawn-review-log.md` (full review log created)
- **Systems-index**: row 14 Status → "Approved pending Coord items 2026-04-24"; Progress Tracker counts updated (Approved 6 → 7; MVP designed 7 Approved/Approved-pending-coord + 5 pending re-review)

### Specialists consulted

- game-designer (B-1..B-7): Pillar 3 fantasy mismatch with 2.0 s fade; anti-farm vs softlock; missing mission-fail trigger; Restart-from-Checkpoint absence; kill-plane coverage gap
- systems-designer (S-1..S-8): **FLAG SPLIT-BRAIN (S-4)** — diagnostic finding; F.1 non-exhaustive; F.2 correlated variables; queued-respawn N unbounded; States table contradiction; idempotency window; E.20 mis-labeled; schema forward-compat
- godot-specialist (E-1..E-9): **E-1 SaveLoad internal await fence needed**; E-5 Jolt non-determinism in AC-FR-2.1; E-6 stale Callable hot-reload crash; E-8 dart body_exited VERIFY; E-9 FailureRespawnState _init() missing
- gameplay-programmer (G-1..G-8): Independent confirmation of S-4 split-brain; RESTORING contradiction; CR-11 lookup method unspecified; DI hook missing; register_restore_callback survivability; queued-respawn overwrite (G-7); Checkpoint class ownership
- qa-lead (Q-1..Q-17): **7 BLOCKING AC issues + 10 RECOMMENDED**; missing sole-publisher AC (Q-13)
- performance-analyst (P-1..P-7): **P-3 ADR-0001 storage tier undeclared — ESCALATED TO TD**; F.2 best-case arithmetic; correlated I/O; N=2 by fiat; 1.62 s post-resume fade
- audio-director (A-1..A-7): **A-1 sting vs silence policy undefined**; A-3 queued-respawn single-emit unconfirmed; A-5 200 ms below perceptual beat threshold; A-6 permanent-silence failure mode
- creative-director senior synthesis: MAJOR REVISION NEEDED; 2 structural defects (flag split-brain, States-table contradiction); 5 live cross-GDD contradictions; adjudicated B-1/A-5 (Audio amendment needed) + S-8 (accept flat bool); ruled sting-suppression on respawn path; strongly recommended `/clear` + fresh-session re-review protocol

### User-approved revisions applied (via 4-tab AskUserQuestion adjudication)

- **Q1 Flag split-brain**: live-authoritative (F&R autoload holds `_floor_applied_this_checkpoint: bool` as authoritative; save mirrors live via `FailureRespawnState.capture(live_value)`; reads at step 9 from live only; live advances synchronously after Inventory returns)
- **Q2 RESTORING rules**: allow dispatch-only; block state-mutating section_entered branches via `_flow_state == IDLE` guard in CR-7
- **Q3 Cross-GDD scope**: coord items only; edit failure-respawn.md only in this session per CLAUDE.md collaborative principle
- **Q4 Audio handshake**: full CD ruling — sting suppression + silence retune 0.2→0.4 s + fade retune 2.0→1.2 s as Audio GDD amendment coord items

### Edits applied to failure-respawn.md (15+ edits, 513 → 553 lines)

- CR-5/CR-6 rewritten for live-authoritative + Resource `_init()` constructor + read/write contract + schema forward-compat note
- CR-7 rewritten with `_flow_state == IDLE` guard (resolves 2 structural defects simultaneously)
- CR-8 rewritten with sting-suppression + subscriber re-entrancy fence
- CR-10 rewritten with single-emit guarantee + 2.5 s debug watchdog
- CR-11 rewritten with `find_child(recursive=true, owned=false)` contract + shared Checkpoint location
- CR-12 step 9 annotated live-authoritative; step 4 annotated ADR-0003 await-forbid; step 12 reconciled with CR-7 guard
- States table rewritten with disambiguation note
- F.1 rewritten (7 transition rows from 4; default arm; hydrate + null-fallback rows)
- F.2 marked **PROVISIONAL** pending ADR-0001 storage-tier amendment; arithmetic corrected (0.15 → 0.167 s); SSD-cold vs HDD-cold rows separated; correlated-variable caveat; perceived-beat target 1.6 s
- E.20 rationale flipped to explicit permissive-on-corruption tradeoff
- 7 blocking ACs rewritten (1.1, 2.1, 3.1, 5.5, 6.2 BLOCKED, 10.1 hardware-pin, 10.2 → Playtest type)
- 2 new ACs: AC-FR-12.4 sole-publisher CI lint + AC-FR-12.5 re-entrancy CI lint
- BLOCKING items table grew 5 → 12
- Bidirectional consistency check expanded to flag 5 cross-GDD contradictions as coord items
- 9 new OQs (OQ-FR-7 BLOCKING storage-tier + OQ-FR-8 BLOCKING signal-isolation + 7 others)
- 3 new DGs (DG-FR-5/6/7)
- AC count 38 → 40

### Pre-implementation gates (OPEN — 12 items, up from 5)

1. ADR-0007 amendment (F&R autoload at line 8) — pre-existing
2. Inventory GDD coordination — rename `restore_weapon_ammo` → `apply_respawn_floor_if_needed`
3. Save/Load GDD + ADR-0003 (4 sub-items: schema + L100/L151 stale-text + internal-await forbid + atomic-commit fence)
4. Input GDD coordination — add `InputContext.LOADING` context (currently missing from input.md)
5. Signal Bus GDD touch-up — add F&R's section_entered subscription to L122 row
6. Audio GDD amendment — sting-suppression + retune silence/fade
7. **ADR-0001 amendment (ESCALATED TO TD)** — declare min-spec storage tier (SSD vs HDD)
8. LS GDD coordination — document replace-semantics on `register_restore_callback`
9. godot-specialist engine-verification gate — Godot 4.6 signal-isolation on subscriber unhandled exception
10. PC GDD null-checkpoint spec (OQ-FR-5) — pre-existing BLOCKING
11. Mission Scripting (PROVISIONAL) — `player_respawn_point: Marker3D` authoring + non-deferred contract + section-validation CI
12. Shared `Checkpoint` class location at `src/gameplay/shared/checkpoint.gd`

### Files modified this session

- `design/gdd/failure-respawn.md` — major revision (513 → 553 lines)
- `design/gdd/reviews/failure-respawn-review-log.md` — **NEW** (review log with full verdict, specialist findings, resolution summary)
- `design/gdd/systems-index.md` — row 14 Status + Progress Tracker updated
- `production/session-state/active.md` — **this file**

## Next steps (fresh session recommended)

1. **PRIMARY — `/design-system mission-level-scripting`** (system #13). User requested this as next action but skill was deferred due to context depth. Fresh session recommended because: (a) Mission Scripting is M-effort (2-3 sessions); (b) skill mandates specialist consultations per section; (c) starting from exhausted context risks the same drift CD just flagged on F&R. System #13 depends on Stealth AI ✅, Combat ✅, Level Streaming ✅, Save/Load ✅, Signal Bus ✅ — fully unblocked.

2. **Alternative — `/design-review` on a pending GDD** in fresh session. Six GDDs carry "Designed (pending review)" or "Revised (pending re-review)" status:
   - `design/gdd/save-load.md` (most F&R-coupled; L100/L151 stale-text contradiction + schema touch-up surface here)
   - `design/gdd/signal-bus.md`, `design/gdd/input.md`, `design/gdd/outline-pipeline.md`, `design/gdd/post-process-stack.md`, `design/gdd/localization-scaffold.md`

3. **Alternative — close F&R BLOCKING coord items** in a dedicated session. Save/Load + Input + Signal Bus text touch-ups are quick wins; ADR-0001 storage-tier amendment needs TD consultation; Audio GDD amendment needs audio-director consultation.

4. **Alternative — `/architecture-decision adr-0001-amendment`** — declare min-spec storage tier so F.2 + AC-FR-10.x can finalize.

5. **Alternative — `/consistency-check`** — re-run post-F&R-revision to catch new drift (revision added 40 lines, introduced new coord items + schema references).

## Gate-check recommendation

Still not PASS-eligible for `/gate-check pre-production`. Outstanding:
- [ ] 12 F&R BLOCKING coord items (including TD-escalated ADR-0001)
- [ ] `/design-review` on 6 pending-review GDDs (or accept-pending-coord as project pattern)
- [ ] 26 verification gates (ADR Proposed → Accepted)
- [ ] 11 outstanding MVP GDDs (12/23 designed after F&R landed Approved-pending-coord)

## Preserved — prior task history

Prior session state extracts (F&R `/design-system` authoring 2026-04-24 earlier; Inventory `/design-system` + `/design-review` + `/architecture-review` 5th-run 2026-04-24; ADR-0007 amendment 2026-04-23; `/create-architecture` 2026-04-23; etc.) are recorded in git history of this file and in referenced docs. Architecture review verdict remains PASS (5th-run 2026-04-24).
