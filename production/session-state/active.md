# Session State

**Last updated:** 2026-04-21 (Combat & Damage GDD authoring COMPLETE + /consistency-check resolution pass complete — 8 conflicts resolved via CR-3 blade split adoption + §F.7-authoritative propagation. Pending /design-review in fresh session.)

## Current task

✅ `design/gdd/combat-damage.md` — **/design-system COMPLETE (2026-04-21)** + **/consistency-check conflicts resolved (2026-04-21)**. 1,179 lines; all 11 sections. Entity registry updated with 19 new constants + 1 new formula + 8 existing-entry referenced_by updates, plus 8 conflict resolutions (C1–C8).

**Next action** (user runs in a FRESH session, not here): `/design-review design/gdd/combat-damage.md`

### /consistency-check resolution (2026-04-21, this session)

8 conflicts detected and resolved per user-approved plan (Option A + §F.7 authoritative + single changeset):

- **C1**: `damage_formula.output_range` [16, 240] → [13, 240] (fist_base_damage safe floor = 13, not 16).
- **C2 (CR-3 blade split)**: `silenced_pistol_takedown_damage` DEPRECATED → new `blade_takedown_damage = 100`. New `DamageType.MELEE_BLADE` carries the blade weapon. New SAI `TakedownType.STEALTH_BLADE` replaces `SILENCED_PISTOL`. New weapon Resource (OQ-CD-11): blade (no ammo, base_damage = 100, gated by SAI context prompt).
- **C3**: `guard_pistol_damage_vs_eve` safe range [14, 25] → [14, 20] to honor AC-CD-14.1 ("Eve cannot die in fewer than 5 hits").
- **C4**: `pistol_starting_reserve` 16 → 32 (Aggressive player now dry by Section 4–5, not 3).
- **C5**: `dart_starting_reserve` 8 → 16 (Ghost path viable at 80% pickup rate without fist-KO reliance).
- **C6**: `guard_drop_dart_ko_rounds` DEPRECATED → split into `guard_drop_dart_on_dart_ko = 1` (break-even) + `guard_drop_dart_on_fist_ko = 0` (no farm).
- **C7**: `respawn_ammo_floor_pistol = 8` (mag-only) DEPRECATED → `respawn_floor_pistol_total = 16` (TOTAL mag+reserve).
- **C8**: `respawn_ammo_floor_dart = 4` DEPRECATED → `respawn_floor_dart_total = 8` (TOTAL).

### Files modified in this resolution pass

- `design/gdd/combat-damage.md` — §D.1 Summary Table (9 rows updated), §E.31, §C.3 SAI-delegation row, AC-CD-2.5, AC-CD-6.1, AC-CD-11.3, AC-CD-12.3, AC-CD-17.1, OQ-CD-6, §F.7 interaction warning. ~12 edit sites.
- `design/gdd/stealth-ai.md` — `TakedownType` enum SILENCED_PISTOL → STEALTH_BLADE (line 151); 4 prose references updated (lines 148, 156, 237, 251, 531); Audio pre-impl gate item (c) at line 538 updated.
- `design/gdd/audio.md` — 3 references to `SILENCED_PISTOL` takedown variant renamed to `STEALTH_BLADE` with blade-stroke SFX description (signal handler row + SFX catalog row + AC-38). SFX filename convention changed from `sfx_takedown_silenced_pistol_*` to `sfx_takedown_stealth_blade_*`.
- `design/gdd/systems-index.md` — line 5 running changelog updated to describe blade split.
- `design/registry/entities.yaml` — C1 formula output_range; C2 deprecate + new `blade_takedown_damage`; C3 notes; C4 value; C5 value; C6 deprecate + two new split knobs; C7+C8 deprecate + two new `_total` knobs. 9 new/updated entries; 4 deprecations.

### Downstream implications (forward-dep GDDs still unauthored)

- **Inventory & Gadgets (system #12)** — OQ-CD-11 blade Resource authoring required: blade weapon (no ammo, base_damage = 100, damage_type = MELEE_BLADE, no magazine / no reserve, blade-draw input binding, context-prompt gating by SAI `receive_takedown` prompt).
- **Failure & Respawn (system #14)** — must consume `respawn_floor_pistol_total = 16` and `respawn_floor_dart_total = 8` with TOTAL (magazine+reserve) semantics, applied via `max(snapshot_total, floor)` then clamp to `[0, per_weapon_max_reserve]`. First-death-per-checkpoint gating via `floor_applied_this_checkpoint` flag.
- **ADR-0002 amendment (pending)** — already-tracked amendment for severity + 4-param takedown_performed now also bundles enum value rename SILENCED_PISTOL → STEALTH_BLADE.
- **OQ-CD-1 SAI amendment bundle** — grows by one item: `TakedownType` enum rename is now in scope alongside `AlertState.UNCONSCIOUS` + `receive_damage -> bool`.

### Combat & Damage authoring summary

- **Specialists consulted (via Task delegation)**:
  - Section B Player Fantasy: `creative-director` (produced 3 candidate framings — user selected Framing C "Composed Removal of an Obstacle")
  - Section C Detailed Design: PARALLEL delegation to `game-designer` + `systems-designer` + `ai-programmer` + `art-director`
  - Section D Formulas: PARALLEL delegation to `systems-designer` (5 formulas) + `economy-designer` (ammo economy)
  - Section E Edge Cases: `systems-designer` comprehensive audit (40 edge cases + 4 open questions)
  - Section H Acceptance Criteria: `qa-lead` (17 AC groups / 50+ individual criteria with test evidence paths)

- **Key design decisions (user-approved, 2026-04-21)**:
  - **Pillar 3 framing**: combat is fail-forward, delivered VIA Pillar 5 period-authentic restraint. "Eve does not change register. The world around her does."
  - **Weapon roster (4 MVP)**: silenced pistol (hitscan, 34 HP body / 68 HP headshot, TTK 3 body / 2 head), dart gun (projectile, 150 HP → UNCONSCIOUS, 1-shot KO), rifle (hitscan, 120 HP, 1-shot body + ADS 1.5× zoom, pickup-only), fists (melee cone, 16 HP, 7-hit KO)
  - **Gunfight TTK model** (option A): real TTK tension with 2× headshot rewarding aim — NOT the 1-shot precision fantasy (which would make gunfights binary)
  - **Takedown damage SEPARATE** from gunfight base damage: `silenced_pistol_takedown_damage = 100` preserves 1-shot lethal takedowns even though gunfight pistol is 34 HP
  - **Headshot plumbing**: internal to Combat — `enemy_damaged.amount` carries post-multiplier value (systems-designer authoritative, rejected DamageType.HEADSHOT as enum-semantic rot)
  - **Dart KO → UNCONSCIOUS**: SAI.AlertState gains 6th state UNCONSCIOUS (NEW) — requires SAI GDD amendment (OQ-CD-1 bundle)
  - **Crosshair**: period center dot ON BY DEFAULT, accessibility-togglable off (Settings → Accessibility → Crosshair)
  - **Rifle ADS**: 1.5× zoom (85° → 55° FOV over 200 ms ease-out) — rifle is the ONLY ADS-eligible weapon
  - **Friendly fire**: ON by default, per-section configurable via Mission Scripting SectionConfig
  - **Guard return-fire**: hitscan-then-perturb (NOT roll-to-hit) — preserves environmental audio feedback (near-misses hit walls, SFX fires). Spread cone: 2°/3°/3.5°/6° base × movement + 4° cover + 0→3° linear falloff 8m→16m. Cadence: 0.65 s first-shot / 1.4 s LOS / 2.8 s suppression max 3 shots.
  - **Guard vs Eve damage**: 18 HP per hit (5.5-hit kill) — Pillar 3 survivability. PROTOTYPE-GATED (OQ-CD-6).
  - **Return-fire timer handshake** (CR-14): guard subscribes to Events.player_damaged; resets _combat_lost_target_timer iff source == self && state == COMBAT
  - **Ammo economy** (Pillar 2 enforcement):
    - Starting: pistol 8/16, dart 4/8, rifle 0 (pickup-only)
    - Guard drops: 8 pistol / 3 rifle (partial) / 1 dart on KO (BREAK-EVEN anti-farm invariant)
    - Placed caches: Sections 1–4 pistol+dart, Section 5 pressure (no caches)
    - Carryover: FULL between sections (scarcity compounds)
    - Respawn floor: pistol 8, dart 4, rifle preserved
  - **Sampling method** (F.3): `sqrt(randf())` Gaussian-biased disk (NOT uniform flat disk — uniform produces equal miss-density at edge vs center)
  - **Zero-gravity dart** at 20 m/s × 4.0 s lifetime = 80 m max range. Subtle 0.5 arc option prototype-gated (OQ-CD-9).
  - **Headshot detection**: Area3D on BoneAttachment3D(bone: head) with `is_in_group("headshot_zone")`. Radius 0.15 m at Y offset 1.65 m. Jolt-validation pending (OQ-CD-2).

- **Pre-implementation gates OPEN** (block Combat stories entering sprints):
  - **OQ-CD-1 SAI amendment bundle**: (1) AlertState.UNCONSCIOUS 6th state + (2) receive_damage → bool is_dead return + (3) enemy_killed semantics on UNCONSCIOUS entry. Owner: user + technical-director via /design-system revision of SAI.
  - **OQ-CD-2 Jolt Area3D validation**: 30-min prototype to confirm Jolt's intersect_ray includes Area3D on BoneAttachment3D children. Owner: godot-specialist via prototypes/guard-combat-prototype/.

- **Forward-dep gates** (resolve when Inventory / Mission Scripting GDDs are authored):
  - OQ-CD-3 Weapon fallthrough (auto-switch to fists when all ammo exhausted)
  - OQ-CD-4 Fist-swing multi-target selection (nearest vs first)
  - OQ-CD-5 Mission objective save race (checkpoint timing vs enemy_killed emit)

- **Tier 1 playtest-gated** (5 values — final numbers deferred to prototype + playtest):
  - OQ-CD-6 guard_pistol_damage_vs_eve = 18 (range [14, 25])
  - OQ-CD-7 eve_spread_deg = 0.0 (range [0.0, 1.5] for sprint-fire tax)
  - OQ-CD-8 dart_speed_m_s = 20.0 (range [15, 30])
  - OQ-CD-9 dart_gravity_scale = 0.0 (or 0.5 subtle arc)
  - OQ-CD-10 head_zone_radius_m = 0.15 (range [0.10, 0.20])

- **Art Bible amendments flagged** (V.9 — not blocking Combat approval, but block /asset-spec run):
  - §4.4: add `#FFFFFF` transient-only HUD color (1-frame hit flash)
  - §7D: add camera-dip hit feedback (3°, 6/10 frame dip/recovery)
  - NEW §8K VFX Asset Class — Combat Feedback (4 asset types + tier-0 vs tier-3 rule)
  - §3.4: add silhouette-legibility clarification for fallen-guard poses

- **Registry updates applied 2026-04-21**:
  - NEW constants (19): weapon damage (5), head-zone detection (2), ammo magazine/reserve (6), guard drops (3), respawn floor (2), dart physics (1)
  - NEW formula (1): damage_formula (F.1) — owner Combat, referenced by PC + SAI
  - UPDATED referenced_by (8): eve_sterling, phantom_guard (+ pending AlertState.UNCONSCIOUS note), player_max_health, player_critical_health_threshold, collision_layer_world/player/ai/interactables/projectiles

## Status

- ✅ Engine configured: Godot 4.6, GDScript
- ✅ Game concept: `design/gdd/game-concept.md` (The Paris Affair)
- ✅ Art bible complete (9 sections — amendments flagged by Combat GDD, not yet applied)
- ✅ Systems index: 23 + 1 (FootstepComponent) systems
- ✅ ADRs: 6 authored (0001–0006), all Proposed
- ⏳ System GDDs: **10/23 authored** — 5 Approved (PC, FC, SAI, Audio, Level Streaming), 5 Designed/Revised pending review (Signal Bus, Input, Outline, Post-Process, Save/Load, Localization, Combat & Damage NEW)
- ⏳ Architecture document: not started
- 🔶 **Downstream still blocked**: Inventory & Gadgets (12), Mission & Level Scripting (13), Failure & Respawn (14), Civilian AI (15), HUD Core (16), Document Collection (17), Dialogue & Subtitles (18) — some now unblocked by Combat & Damage landing

## Key files modified in this session (2026-04-21)

- `design/gdd/combat-damage.md` — NEW, 1,179 lines (created this session)
- `design/gdd/systems-index.md` — row 11 updated, Progress Tracker updated, Last Updated notes
- `design/registry/entities.yaml` — 19 new constants + 1 new formula + 8 referenced_by updates
- `production/session-state/active.md` — this file

## Next steps (fresh session)

1. **Primary**: `/clear` — this session is done. 1,179-line GDD + 6 specialist consultations + 20 registry entries is a lot.
2. **In fresh session**: Run `/design-review design/gdd/combat-damage.md` to validate independently. Lean depth is probably sufficient (the authoring pass baked in a lot of specialist rigor already, including qa-lead's AC audit).
3. **Alternatives** (can happen in parallel with #2 or next):
   - `/consistency-check` — verify Combat values don't conflict with upstream (PC, SAI, Audio) — this already passed pre-review per cross-reference checks during authoring.
   - **`/design-system stealth-ai` REVISION** to close OQ-CD-1 (SAI amendment bundle: UNCONSCIOUS state + receive_damage → bool + enemy_killed semantics). 1-session effort. Unblocks AC-CD-7.1 and AC-CD-11.4.
   - `/design-system inventory-gadgets` (system #12) — next MVP system. Combat & Damage defines the Weapon Resource schema it will consume.
   - `/design-system mission-level-scripting` (system #13) — Combat's friendly-fire SectionConfig authoring concern, plus objective progression on enemy_killed.
   - `/architecture-decision adr-0002-amendment` — the pending ADR-0002 severity+takedown_type amendment flagged by SAI + now by Combat. Bundles well with OQ-CD-1 SAI revision.
   - `/gate-check pre-production` — 10/16 MVP GDDs designed; not yet ready for gate (need 16/16 + ADRs Accepted).

## Open design questions (active)

Combat & Damage brings 10 new OQs (OQ-CD-1 through OQ-CD-10, documented in §Open Questions of the GDD). Plus the previously-tracked deferred items:
- OQ-2 Fall damage — deferred to VS
- OQ-3 Lean system — deferred, revisit after Stealth AI + first playtest
- OQ-4 Mirror full body mesh — deferred to VS
- OQ-5 Surface detection method — moved to footstep-component.md (closed by CR-10 in level-streaming.md)
- OQ-6 Eve verbalizes — deferred, narrative dep
- OQ-FC-2 Noise level sampling timing — deferred, Audio playtest dep
- OQ-FC-3 FC execution order vs PC state — deferred, playtest dep
- OQ-FC-4 Non-player footstep sources — deferred, Stealth AI dep

## Specialist verification artifacts (this session)

All specialist reports delivered inline via Task tool; outputs distilled into GDD sections. Not persisted to separate files — they are authoring artifacts, not authoritative specs. The GDD itself is the authoritative spec.
