# Asset Manifest — The Paris Affair

> **Last updated**: 2026-05-08
> **Sprint**: 09 (`production/sprints/sprint-09-asset-commission-hybrid.md`)
> **Pipeline**: Hybrid Blender MCP — see Sprint 09 plan for tier definitions
> **Asset directories**: `assets/models/<context>/` for `.glb` exports; `design/assets/specs/<context>-assets.md` for spec docs

## Tier Legend

| Tier | Approach | Sprint deliverable |
|---|---|---|
| **T1** | Spec → MCP-generate → Blender cleanup → export `.glb` | Final-look `.glb` ready for scene integration |
| **T2** | Spec → MCP-generate base mesh → save reference | Base mesh `.glb`; rig deferred (Sprint 09b or external) |
| **T3** | Spec only — generation deferred to external | Spec doc; user procures via marketplace / specialized tool |

## Status Vocabulary

| Status | Meaning |
|---|---|
| **Needed** | Specced; generation pending |
| **In Progress** | Active MCP generation or cleanup |
| **Done** | `.glb` on disk + status verified against spec |
| **Base mesh — rig deferred** | T2 mesh delivered; rigging is a future-sprint deliverable |
| **External commission needed** | T3 — spec ready; awaiting non-MCP procurement |

## Progress Summary

| Total | Needed | In Progress | Done | Base mesh | External |
|---|---|---|---|---|---|
| 9 | 2 | 0 | **2** | **4** | 1 |

**Sprint 09 hero-set commission COMPLETE** (assets 1-6) — all 6 hero assets either shipped or flagged for external commission. ASSET-001 (Eve FPS hands T3) remains as external commission per spec; all other 5 assets delivered as base mesh / done T1 props.

**Sprint 09 continuation — Levels** (assets 7+): Contexts 4-6 (Plaza, Restaurant, Bomb Chamber) authoring per-level asset specs. Plaza spec authored 2026-05-10 with 3 assets (ASSET-007/008/009).

## Assets by Context

### System: Player Character (Eve Sterling)

Source GDD: `design/gdd/player-character.md` · Art Bible §5.1
Spec file: `design/assets/specs/player-character-assets.md`

| Asset ID | Name | Category | Tier | Status | `.glb` path | Visual reference |
|---|---|---|---|---|---|---|
| ASSET-001 | Eve FPS Hands | Character — rigged 1st-person | T3 | External commission needed | `assets/models/player-character/char_eve_fps_hands.glb` (target — not yet produced) | inherits ASSET-002 reference for navy/glove palette |
| ASSET-002 | Eve Full Body (base mesh) | Character — base mesh, rig deferred | T2 | **Base mesh — rig deferred** (re-done 2026-05-10 via Hunyuan3D-2) | `assets/models/player-character/char_eve_sterling.glb` (343 KB, 4,500 tris) | `design/assets/specs/references/eve_sterling_reference_2026-05-09.png` |

### System: Stealth AI (PHANTOM)

Source GDD: `design/gdd/stealth-ai.md` · Art Bible §5.2
Spec file: `design/assets/specs/stealth-ai-assets.md`

| Asset ID | Name | Category | Tier | Status | `.glb` path | Visual reference |
|---|---|---|---|---|---|---|
| ASSET-003 | PHANTOM Grunt — Bowl Helmet | Character — base mesh, rig deferred | T2 | **Base mesh — rig deferred** (re-done 2026-05-10 via Hunyuan3D-2) | `assets/models/stealth-ai/char_phantom_grunt_bowl_helmet.glb` (214 KB, 2,800 tris) | `design/assets/specs/references/phantom_grunt_bowl_helmet_reference_2026-05-10.png` |
| ASSET-004 | PHANTOM Grunt — Open-Face Helmet | Character — base mesh, rig deferred | T2 | **Base mesh — rig deferred** (re-done 2026-05-10 via Hunyuan3D-2) | `assets/models/stealth-ai/char_phantom_grunt_open_face.glb` (214 KB, 2,800 tris) | `design/assets/specs/references/phantom_grunt_open_face_reference_2026-05-10.png` |
| ASSET-005 | PHANTOM Elite — Bomb Chamber Boss | Character — base mesh, rig deferred | T2 | **Base mesh — rig deferred** (re-done 2026-05-10 via Hunyuan3D-2) | `assets/models/stealth-ai/char_phantom_elite_peaked_cap.glb` (267 KB, 3,500 tris) | front: `design/assets/specs/references/phantom_elite_peaked_cap_reference_2026-05-10.png` · back: `design/assets/specs/references/phantom_elite_peaked_cap_reference_back_2026-05-10.png` |
| ASSET-006 | Walkie-talkie radio (chest accessory) | Prop — static, no rig | T1 | **Done** (re-done 2026-05-10 via Hunyuan3D-2) | `assets/models/stealth-ai/prop_walkie_talkie_phantom.glb` (31 KB, 400 tris) | `design/assets/specs/references/walkie_talkie_phantom_reference_2026-05-10.png` |

---

## Assets by Context (continued)

### Level: Plaza

Source: `design/art/art-bible.md` §6.1/§6.2/§6.3/§4.3 (level doc skipped — extracted directly from art bible per Sprint 09 pragmatic scope decision)
Spec file: `design/assets/specs/plaza-assets.md`

| Asset ID | Name | Category | Tier | Status | `.glb` path | Visual reference |
|---|---|---|---|---|---|---|
| ASSET-007 | Eiffel bay module — plaza-tier (wide heavy base) | Environment — tiling architecture | T1 | **Done** (2026-05-10) — code-authored | `assets/models/level-plaza/env_eiffel_bay_module_plaza.glb` (4 KB, 60 tris) | `design/assets/specs/references/eiffel_bay_module_plaza_reference_2026-05-10.png` (design intent) |
| ASSET-008 | Period sodium street lamp | Environment — period prop | T1 | Needed | `assets/models/level-plaza/env_period_street_lamp.glb` (target) | (pending) |
| ASSET-009 | Plaza kiosk / guard post | Environment — period structure | T1 | Needed | `assets/models/level-plaza/env_plaza_guard_post.glb` (target) | (pending) |

---

## Pending Contexts (specs not yet authored)

Per `production/sprints/sprint-09-asset-commission-hybrid.md` execution order:

| # | Context | Source doc | Spec file (target) |
|---|---|---|---|
| 3 | System: Inventory Gadgets | `design/gdd/inventory-gadgets.md` | `design/assets/specs/inventory-gadgets-assets.md` (DEFERRED — bomb device covered in Bomb Chamber context per spec scope decision) |
| 5 | Level: Restaurant | art bible §6 (level doc skipped) | `design/assets/specs/restaurant-assets.md` |
| 6 | Level: Bomb Chamber | art bible §6 (level doc skipped) | `design/assets/specs/bomb-chamber-assets.md` |

## Resume Protocol

To continue Sprint 09 in a new session:

1. Read `production/session-state/active.md` (Sprint 09 Kickoff section)
2. Read `production/sprints/sprint-09-asset-commission-hybrid.md` (formal sprint plan)
3. Read this manifest — first asset whose status is not `Done` / `Base mesh — rig deferred` / `External commission needed` is the next work item
4. Open the relevant spec file at `design/assets/specs/<context>-assets.md`
