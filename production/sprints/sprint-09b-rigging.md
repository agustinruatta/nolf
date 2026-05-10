# Sprint 09b — Humanoid Rigging Post-Base-Mesh

**Dates**: 2026-05-10 to TBD (user-paced; not autonomous-executable)
**Generated**: 2026-05-10
**Mode**: solo review (per `production/review-mode.txt`)
**Source**: Sprint 09 close-out + `production/sprint-roadmap-status.yaml` post_roadmap_preview sprint 9b
**Predecessor**: Sprint 09 (asset commission) CLOSED 2026-05-10 with 4 humanoid base meshes shipped

## Sprint Goal

**Rig the 4 humanoid base meshes shipped in Sprint 09 with biped skeletons, weight painting, and L/R hand attach points — making them ready for Sprint 09c (animations) and Sprint 10+ (scene integration).**

By close, every Tier 2 humanoid `.glb` from Sprint 09 has a paired rigged version with:
- Standard biped skeleton (humanoid hierarchy compatible with Mixamo / Godot's `Skeleton3D`)
- Clean weight painting (no unintended deformation at joints)
- L/R hand attach points (`LeftHandIK`, `RightHandIK`) for weapon slots per `design/gdd/stealth-ai.md` §Visual lines 758-761
- Eve gets additional `HandAnchor` for FPS-hands integration when ASSET-001 ships externally

Sprint 09c will add the actual animation cycles (patrol_walk, investigate_sweep, combat_fire, dead_slump, chloroformed_slump, chloroformed_rising, weapon_draw, head_turn IK).

## Targets — 4 Humanoid Base Meshes from Sprint 09

| Asset | Base mesh path | Tris | Method |
|---|---|---|---|
| ASSET-002 Eve Sterling | `assets/models/player-character/char_eve_sterling.glb` | 4,500 | Manual or Mixamo (verify Mixamo handles slim female proportions) |
| ASSET-003 PHANTOM Grunt — Bowl Helmet | `assets/models/stealth-ai/char_phantom_grunt_bowl_helmet.glb` | 2,800 | **Mixamo** (chunky industrial-mass proportions are Mixamo's sweet spot) |
| ASSET-004 PHANTOM Grunt — Open-Face | `assets/models/stealth-ai/char_phantom_grunt_open_face.glb` | 2,800 | **Mixamo** + retarget rig from ASSET-003 (same body topology, only helmet aperture differs — riggers should reuse the rig + minor weight adjustments) |
| ASSET-005 PHANTOM Elite — Bomb Chamber Boss | `assets/models/stealth-ai/char_phantom_elite_peaked_cap.glb` | 3,500 | **Manual rig in Blender** (tall narrow elite proportions may confuse Mixamo's auto-rigger; long coat geometry needs careful weight painting near hem to avoid clipping at leg movement) |

## Story Breakdown (per asset)

### Sprint 09b Stories

| # | Story | Asset | Method | Estimate | Acceptance |
|---|---|---|---|---|---|
| 09b-01 | PHANTOM Grunt Bowl Helmet rigged | ASSET-003 | Mixamo auto-rig | 0.5 day | Biped skeleton present; idle pose holds; no clipping at shoulder/hip |
| 09b-02 | PHANTOM Grunt Open-Face rigged | ASSET-004 | Mixamo + reuse 09b-01 rig | 0.25 day | Same biped topology as 09b-01; helmet aperture geometry deformed correctly when head bone rotates |
| 09b-03 | PHANTOM Elite rigged | ASSET-005 | Manual in Blender | 1.5 days | Biped skeleton + manual weight painting; long coat hem does not clip into legs at walk-cycle leg flexion (test pose: 30° forward leg lift) |
| 09b-04 | Eve Sterling rigged | ASSET-002 | Mixamo auto-rig (validate first) | 0.5 day OR 1.5 days if manual | Biped skeleton + L/R hand attach points; no clipping; ready for FPS-hands integration when ASSET-001 ships |

**Total estimated agent-time**: ~3 days

## Out of Scope

- **Animations** (patrol_walk, investigate_sweep, combat_fire, dead_slump, chloroformed_slump, chloroformed_rising, weapon_draw, head_turn IK) — Sprint 09c
- **ASSET-001 Eve FPS hands** — external commission, not in-session pipeline
- **Texture pass / multi-color material slots** — Sprint 10+
- **Outline stencil ref assignment at scene-load** — Sprint 10+ (per ADR-0001)
- **Scene integration** (replacing placeholder geometry in `scenes/sections/*.tscn`) — Sprint 10+

## Per-Asset Workflow

For each of the 4 humanoids:

### Path A — Mixamo (Grunts + maybe Eve)

1. Upload base mesh `.glb` to Mixamo (mixamo.com)
2. Confirm bone placement (head, shoulders, elbows, wrists, hips, knees, ankles)
3. Auto-rig
4. Download rigged `.fbx` (Mixamo doesn't export `.glb` directly)
5. Convert `.fbx` → `.glb` via Blender import + export (preserves skeleton, weight painting)
6. Add L/R hand attach point empty children (`LeftHandIK`, `RightHandIK` at world position of palm-center for weapon attachment)
7. Eve also gets `HandAnchor` empty (camera-attached FPS-hands anchor per `player-character.md` §Visual line 711)
8. Export final rigged `.glb` to canonical asset path (overwriting Sprint 09 base mesh OR alongside as `<asset>_rigged.glb` — decide naming convention at sprint open)
9. Validate via Blender pose-mode test: idle, T-pose, A-pose, basic walk-pose all hold without clipping

### Path B — Manual rigging in Blender (Elite)

1. Import base mesh into Blender
2. Add humanoid armature via `bpy.ops.object.armature_human_metarig_add()` (Rigify metarig) OR manually build biped from primitives
3. Position bones to match mesh anatomy (head, torso, arms, legs)
4. Parent mesh to armature with automatic weights
5. Manual weight painting fixup at problem zones (long-coat hem, lapels)
6. Add L/R hand IK attach points
7. Validate via pose-mode test (especially: leg flexion + coat hem clipping)
8. Export rigged `.glb`

## Stop Conditions

- Mixamo auto-rig fails on a humanoid (e.g., Eve's slim proportions, Elite's tall narrow build) → fall back to Path B manual rigging for that asset
- Weight painting cannot resolve clipping at >2 problem zones → escalate (may need mesh topology adjustment, which would push the asset back to Sprint 09 territory)
- Hand attach point IK chains break in Godot import test → investigate Godot 4.6 SkeletonModifier3D documentation per `docs/engine-reference/godot/VERSION.md` ⚠ verify list (4.6 IK restoration via `SkeletonModifier3D` nodes — CCDIK/FABRIK/TwoBoneIK)

## Acceptance Criteria

Sprint closes when:

- [ ] All 4 humanoids have a rigged `.glb` deliverable
- [ ] Each rigged `.glb` imports cleanly into Godot 4.6 (no error logs, skeleton visible in scene tree)
- [ ] Each rig has L/R hand attach points (`LeftHandIK`, `RightHandIK`) at correct palm-center world positions
- [ ] Eve has additional `HandAnchor` ready for ASSET-001 external integration
- [ ] Pose-mode test validates: idle pose holds; basic walk-pose has no clipping; head turn IK is functional
- [ ] `design/assets/asset-manifest.md` updated — ASSET-002/003/004/005 status changes from "Base mesh — rig deferred" → "Rigged"
- [ ] No new tech-debt added; tech-debt register stays at or below 12 items

## Recommended Order

1. **09b-01 (PHANTOM Grunt Bowl)** — most predictable Mixamo case (chunky humanoid is sweet spot); validates the workflow before reuse on 09b-02
2. **09b-02 (PHANTOM Grunt Open-Face)** — same body, just different helmet — should be a 1-hour rig copy from 09b-01
3. **09b-04 (Eve)** — try Mixamo first; if her slim proportions confuse the auto-rigger, fall back to manual
4. **09b-03 (PHANTOM Elite)** — last and hardest (manual rig + long coat); use lessons from prior 3 to refine

## Resume Protocol (cross-session)

To continue Sprint 09b in a new session:

1. Read `production/session-state/active.md` (Sprint 09b kickoff section)
2. Read this file (`production/sprints/sprint-09b-rigging.md`)
3. Read `design/assets/asset-manifest.md` to identify next un-rigged humanoid
4. Open the next un-rigged asset's `.glb` in Blender to start

## Stage Transition (still pending from Sprint 09)

`production/stage.txt` decision: still at `Pre-Production`. Recommend bumping to `Art-Production` now that Sprint 09 hero-set commission is complete and Sprint 09b begins post-base-mesh production work. **Surfacing for user approval.**

## Collaboration Protocol Reminder

Per `CLAUDE.md` and user's memories:
- For each asset: discuss high-level rigging direction with concrete options before implementing
- Never auto-commit; all commits remain user-driven
- Spanish in chat; English in every artifact (per `feedback_language_split.md`)
