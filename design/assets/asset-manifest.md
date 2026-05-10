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
| 17 | 0 | 0 | **12** | **4** | 1 |

**🎉 SPRINT 09 PIPELINE COMPLETE 2026-05-10** — all 17 assets either shipped (16) or flagged for external commission (1). 12 done T1 + 4 base mesh T2 + 1 external commission T3 (ASSET-001 Eve hands).

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
| ASSET-008 | Period sodium street lamp | Environment — period prop | T1 | **Done** (2026-05-10) | `assets/models/level-plaza/env_period_street_lamp.glb` (39 KB, 500 tris) | `design/assets/specs/references/period_street_lamp_reference_2026-05-10.png` |
| ASSET-009 | Plaza kiosk / guard post | Environment — period structure | T1 | **Done** (2026-05-10) | `assets/models/level-plaza/env_plaza_guard_post.glb` (46 KB, 600 tris) | `design/assets/specs/references/plaza_guard_post_reference_2026-05-10.png` |

---

### Level: Restaurant (1889 Eiffel Tower dining salon, 1965 occupied)

Source: `design/art/art-bible.md` §6.1/§6.2/§6.3/§4.3 (level doc skipped — extracted directly from art bible)
Spec file: `design/assets/specs/restaurant-assets.md`

| Asset ID | Name | Category | Tier | Status | `.glb` path | Visual reference |
|---|---|---|---|---|---|---|
| ASSET-010 | Eiffel bay module — mid-scaffold (tapering) | Environment — tiling architecture | T1 | **Done** (2026-05-10) — code-authored | `assets/models/level-restaurant/env_eiffel_bay_module_mid_scaffold.glb` (4 KB, 60 tris) | (no image needed — code-authored) |
| ASSET-011 | Period dining table cluster | Hero prop — table + place setting | T1 | **Done** (2026-05-10) | `assets/models/level-restaurant/prop_dining_table_cluster.glb` (46 KB, 600 tris) | `design/assets/specs/references/dining_table_cluster_reference_2026-05-10.png` |
| ASSET-012 | Crystal pendant chandelier | Environment — period lighting fixture | T1 | **Done** (2026-05-10) | `assets/models/level-restaurant/env_crystal_chandelier.glb` (45 KB, 600 tris) | `design/assets/specs/references/crystal_chandelier_reference_2026-05-10.png` |
| ASSET-013 | Period drinks trolley | Prop — period rolling cart | T1 | **Done** (2026-05-10) | `assets/models/level-restaurant/prop_drinks_trolley.glb` (39 KB, 500 tris) | `design/assets/specs/references/drinks_trolley_reference_2026-05-10.png` |

### Level: Bomb Chamber (1889 antenna maintenance alcove, 1965 PHANTOM-occupied)

Source: `design/art/art-bible.md` §6.1/§6.2/§6.3/§4.3 (level doc skipped)
Spec file: `design/assets/specs/bomb-chamber-assets.md`

| Asset ID | Name | Category | Tier | Status | `.glb` path | Visual reference |
|---|---|---|---|---|---|---|
| ASSET-014 | Eiffel bay module — upper-structure (narrow compressed) | Environment — tiling architecture | T1 | **Done** (2026-05-10) — code-authored | `assets/models/level-bomb-chamber/env_eiffel_bay_module_upper_structure.glb` (4 KB, 60 tris) | (no image needed — code-authored) |
| ASSET-015 | **Bomb device (NAMED hero prop)** | Hero prop — climax target, HEAVIEST outline tier 1 | T1 | **Done** (2026-05-10) | `assets/models/level-bomb-chamber/prop_bomb_device_hero.glb` (191 KB, 2,500 tris) | `design/assets/specs/references/bomb_device_hero_reference_2026-05-10.png` |
| ASSET-016 | PHANTOM relay-rack | Environment — period electronics | T1 | **Done** (2026-05-10) | `assets/models/level-bomb-chamber/prop_phantom_relay_rack.glb` (46 KB, 600 tris) | `design/assets/specs/references/phantom_relay_rack_reference_2026-05-10.png` |
| ASSET-017 | Equipment crate (stackable, instanced 2× in scene) | Prop — small functional crate | T1 | **Done** (2026-05-10) | `assets/models/level-bomb-chamber/prop_equipment_crate.glb` (31 KB, 399 tris) | `design/assets/specs/references/equipment_crate_reference_2026-05-10.png` |

---

## Pending Contexts (specs not yet authored)

Per `production/sprints/sprint-09-asset-commission-hybrid.md` execution order:

| # | Context | Source doc | Spec file (target) |
|---|---|---|---|
| 3 | System: Inventory Gadgets | `design/gdd/inventory-gadgets.md` | `design/assets/specs/inventory-gadgets-assets.md` (DEFERRED — bomb device covered in Bomb Chamber context as ASSET-015 per spec scope decision) |

## Resume Protocol

To continue Sprint 09 in a new session:

1. Read `production/session-state/active.md` (Sprint 09 Kickoff section)
2. Read `production/sprints/sprint-09-asset-commission-hybrid.md` (formal sprint plan)
3. Read this manifest — first asset whose status is not `Done` / `Base mesh — rig deferred` / `External commission needed` is the next work item
4. Open the relevant spec file at `design/assets/specs/<context>-assets.md`
