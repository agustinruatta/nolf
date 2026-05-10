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
| 6 | 4 | 0 | 0 | **1** | 1 |

## Assets by Context

### System: Player Character (Eve Sterling)

Source GDD: `design/gdd/player-character.md` · Art Bible §5.1
Spec file: `design/assets/specs/player-character-assets.md`

| Asset ID | Name | Category | Tier | Status | `.glb` path | Visual reference |
|---|---|---|---|---|---|---|
| ASSET-001 | Eve FPS Hands | Character — rigged 1st-person | T3 | External commission needed | `assets/models/player-character/char_eve_fps_hands.glb` (target — not yet produced) | inherits ASSET-002 reference for navy/glove palette |
| ASSET-002 | Eve Full Body (base mesh) | Character — base mesh, rig deferred | T2 | **Base mesh — rig deferred** (2026-05-09) | `assets/models/player-character/char_eve_sterling.glb` (196 KB, 4,500 tris) | `design/assets/specs/references/eve_sterling_reference_2026-05-09.png` |

### System: Stealth AI (PHANTOM)

Source GDD: `design/gdd/stealth-ai.md` · Art Bible §5.2
Spec file: `design/assets/specs/stealth-ai-assets.md`

| Asset ID | Name | Category | Tier | Status | `.glb` path | Visual reference |
|---|---|---|---|---|---|---|
| ASSET-003 | PHANTOM Grunt — Bowl Helmet | Character — base mesh, rig deferred | T2 | Reference approved 2026-05-10 — awaiting image-to-3D conversion | `assets/models/stealth-ai/char_phantom_grunt_bowl_helmet.glb` (target) | `design/assets/specs/references/phantom_grunt_bowl_helmet_reference_2026-05-10.png` |
| ASSET-004 | PHANTOM Grunt — Open-Face Helmet | Character — base mesh, rig deferred | T2 | Needed | `assets/models/stealth-ai/char_phantom_grunt_open_face.glb` (target) | (pending) |
| ASSET-005 | PHANTOM Elite — Bomb Chamber Boss | Character — base mesh, rig deferred | T2 | Needed | `assets/models/stealth-ai/char_phantom_elite_peaked_cap.glb` (target) | (pending) |
| ASSET-006 | Walkie-talkie radio (chest accessory) | Prop — static, no rig | T1 | Needed | `assets/models/stealth-ai/prop_walkie_talkie_phantom.glb` (target) | (pending) |

---

## Pending Contexts (specs not yet authored)

Per `production/sprints/sprint-09-asset-commission-hybrid.md` execution order:

| # | Context | Source doc | Spec file (target) |
|---|---|---|---|
| 2 | System: Stealth AI (PHANTOM) | `design/gdd/stealth-ai.md` | `design/assets/specs/stealth-ai-assets.md` |
| 3 | System: Inventory Gadgets | `design/gdd/inventory-gadgets.md` | `design/assets/specs/inventory-gadgets-assets.md` |
| 4 | Level: Plaza | `design/levels/plaza.md` (needs creation) | `design/assets/specs/plaza-assets.md` |
| 5 | Level: Restaurant | `design/levels/restaurant.md` (needs creation) | `design/assets/specs/restaurant-assets.md` |
| 6 | Level: Bomb Chamber | `design/levels/bomb-chamber.md` (needs creation) | `design/assets/specs/bomb-chamber-assets.md` |

## Resume Protocol

To continue Sprint 09 in a new session:

1. Read `production/session-state/active.md` (Sprint 09 Kickoff section)
2. Read `production/sprints/sprint-09-asset-commission-hybrid.md` (formal sprint plan)
3. Read this manifest — first asset whose status is not `Done` / `Base mesh — rig deferred` / `External commission needed` is the next work item
4. Open the relevant spec file at `design/assets/specs/<context>-assets.md`
