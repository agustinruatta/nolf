# Sprint 09 — Hero Asset Commission (Hybrid Blender MCP Pipeline)

**Dates**: 2026-05-03 to TBD (user-paced, not autonomous-executable)
**Generated**: 2026-05-03
**Mode**: solo review (per `production/review-mode.txt`)
**Source roadmap**: `production/sprints/multi-sprint-roadmap-pre-art.md` §Post-Roadmap Sprint Preview (lines 140–145, originally "Asset spec authoring + pause for art commission")
**Roadmap status**: `production/sprint-roadmap-status.yaml` sprint #9 (pivot — see Pivot Note below)

## Pivot Note

The original roadmap entry for Sprint 09 (line 143) reads: *"Asset spec authoring + pause for art commission. NOT autonomous-executable."* That assumed a workflow where the user procures `.glb` files **outside** the agent session via AI generators or marketplace.

### Pivot history (chronological)

1. **2026-05-03 — first pivot (in-session generation)**: A session-state extract suggested the Blender MCP exposed `generate_hyper3d_model_via_text` / `generate_hunyuan3d_model` / `import_generated_asset` / `download_polyhaven_asset` / `download_sketchfab_model`. The plan was rewritten as a fully in-session hybrid pipeline.
2. **2026-05-08 — second pivot (Path 4 split)**: when MCP tool schemas were actually loaded for use, the connected Blender MCP variant turned out to expose **Python automation + inspection + screenshots only** — NOT the generative tools. The 2026-05-03 plan was based on a stale tool list. After surfacing 4 options to the user, **Path 4 (split pipeline)** was approved.

### Path 4 — Split pipeline (canonical from 2026-05-08)

Generation happens **externally** (USER): the user runs the spec's "Generation Prompt" in Hyper3D Rodin web / Hunyuan3D web / Mixamo / marketplace / etc., and saves the resulting raw `.glb` to disk.

Cleanup + export happens **in-session** via the connected MCP (CLAUDE): import the raw `.glb`, decimate, strip PBR, assign flat unlit material, render outline-test, screenshot for validation, export final `.glb` to `assets/models/<context>/`.

**Available MCP tools (this variant):**
- `mcp__blender__execute_blender_code` (and `_for_cli` background variant)
- `mcp__blender__get_objects_summary` / `get_object_detail_summary` / `get_blendfile_summary_*`
- `mcp__blender__get_screenshot_of_window/area_as_image` / `render_viewport_to_path` / `render_thumbnail_to_path`
- `mcp__blender__get_python_api_docs` / `search_api_docs` / `search_manual_docs`
- `mcp__blender__jump_to_*` (navigation)

**NOT available** in this MCP variant: any `generate_*`, any `download_*`, any `import_generated_asset`, any Polyhaven/Sketchfab tool. If the user later swaps to a generative MCP variant, this section must be updated.

The user memory `project_asset_creation_approach.md` was rewritten 2026-05-08 to reflect Path 4 and supersedes both the original "no Blender" memory and the 2026-05-03 in-session-MCP memory.

## Sprint Goal

**Produce a hero-asset commission package + first-pass `.glb` deliverables. By close, every hero asset is either (a) a finished `.glb` on disk (Tier 1), (b) a base mesh awaiting rig (Tier 2), or (c) a high-quality spec ready for external commission (Tier 3).**

## Tiered Pipeline

| Tier | Approach | Asset categories | Sprint deliverable |
|------|----------|------------------|--------------------|
| **Tier 1** | Spec → MCP-generate → Blender cleanup → export `.glb` to `assets/models/<context>/` | Static props, architecture, small devices | Final-look `.glb` ready for Sprint 10 scene integration |
| **Tier 2** | Spec → MCP-generate base mesh → save reference asset (no rig) | Riggable humanoids (Eve full body, PHANTOM grunt + variants) | Base mesh `.glb`; rigging deferred (manual or Mixamo-style service) |
| **Tier 3** | Spec only — generation deferred to external solution | FPS-specific (Eve FPS hands) | Spec doc only; user procures via marketplace / specialized tool |

## Contexts (execution order — option A confirmed by user)

### Context 1 — Player Character (Eve)

- **Source GDD**: `design/gdd/player-character.md`
- **Assets covered**:
  - Eve FPS hands (rigged, 1st-person, weapon-slot topology) — **Tier 3** (spec only)
  - Eve full body (3rd-person silhouette, cutscenes / death-cam) — **Tier 2** (base mesh)
- **Run**: `/asset-spec system:player-character`
- **Pre-step**: none — source GDD exists.

### Context 2 — Stealth AI (PHANTOM)

- **Source GDD**: `design/gdd/stealth-ai.md`
- **Assets covered**:
  - PHANTOM grunt base — **Tier 2** (base mesh)
  - PHANTOM grunt variants (officer, sniper, etc. as defined in stealth-ai.md) — **Tier 2** if differentiated by texture/proportion; **Tier 1** for any separate accessory props (helmets, weapon attachments, gear)
- **Run**: `/asset-spec system:stealth-ai`
- **Pre-step**: none — source GDD exists.

### Context 3 — Inventory Gadgets

- **Source GDD**: `design/gdd/inventory-gadgets.md`
- **Assets covered**:
  - Bomb device (mission-critical) — **Tier 1**
  - Other gadgets per GDD — **Tier 1**
- **Run**: `/asset-spec system:inventory-gadgets`
- **Pre-step**: none — source GDD exists.

### Context 4 — Plaza level

- **Source doc**: needs creation — `design/levels/plaza.md`
- **Assets covered**: Plaza props (statues, benches, lampposts, period signage, kiosks, planters) — all **Tier 1**
- **Run**: `/asset-spec level:plaza`
- **Pre-step**: author level doc (lightweight per `/quick-design` or `/level-design` if scope warrants). The existing `scenes/sections/plaza.tscn` is a placeholder section root; the level doc should enumerate the prop set this section needs.

### Context 5 — Restaurant bay module

- **Source doc**: needs creation — `design/levels/restaurant.md`
- **Assets covered**: Restaurant arch + props (tables, chairs, bar counter, kitchen pass-through, period decor) — all **Tier 1**
- **Run**: `/asset-spec level:restaurant`
- **Pre-step**: author level doc.

### Context 6 — Bomb Chamber bay module

- **Source doc**: needs creation — `design/levels/bomb-chamber.md`
- **Assets covered**: Chamber arch + lighting props + bomb-rig environment (cabling, control panels, period industrial dressing) — all **Tier 1**
- **Run**: `/asset-spec level:bomb-chamber`
- **Pre-step**: author level doc.

## Per-Asset Workflow (Tier 1 + Tier 2) — Path 4 Split

For each asset within a context that goes through generation:

1. **Discuss** high-level direction in chat (propose concrete options per `feedback_artistic_decisions.md`; user decides)
2. **Spec authoring (CLAUDE)** — append to `design/assets/specs/<context>-assets.md` in English. The spec MUST include a copy-paste-ready generation prompt under a "Generation Prompt" section.
3. **Hand prompt to user (CLAUDE → USER)** — surface the prompt in chat; tell the user which generator is recommended (Hyper3D Rodin web is the default; Hunyuan3D as fallback; marketplace search if both fail)
4. **Generate externally (USER, out of session)** — user runs the prompt in their tool of choice, downloads the raw `.glb` to a known path (`/tmp/`, `~/Downloads/`, or a project staging dir), reports the path back in chat
5. **Import + cleanup (CLAUDE via `mcp__blender__execute_blender_code`)**:
   - Import the raw `.glb` into a clean Blender scene
   - Inspect with `get_objects_summary` / `get_object_detail_summary` (verify mesh-count, tri-count, materials, dimensions)
   - Apply project-units scale (1 Blender unit = 1 metre; Eve standing height ~1.7 m per `player-character.md` §F.8)
   - Decimate to art-bible §8D budget if over (Eve full body 4,500; PHANTOM grunt 2,800; props 300–600; bay module 800)
   - Strip any PBR maps (no normal, roughness, metallic per art bible §8A)
   - Assign single flat unlit material with hex anchors from art bible §4.1 / §5.1 (the spec lists exact hex values)
   - Set sRGB albedo only; mipmaps per art bible §8E
   - Remove orphan data (loose verts, duplicate UVs, unused materials)
6. **Outline-test render (CLAUDE via `render_viewport_to_path`)** — render the mesh in flat-lit white with a 1 px black edge trace; verify silhouette against art bible §3.2 outline-first check
7. **Viewport screenshot (CLAUDE via `get_screenshot_of_area_as_image`)** — capture the area screenshot and surface to user
8. **User approval (USER)** — review screenshot; approve or request regenerate (back to step 4 with refined prompt)
9. **Export (CLAUDE via `execute_blender_code`)** — `.glb` to `assets/models/<context>/<asset-name>.glb` per art bible §8B naming convention
10. **Manifest update (CLAUDE)** — append/update entry in `design/assets/asset-manifest.md` with status `Done` (Tier 1) or `Base mesh — rig deferred` (Tier 2)

### Iteration cap

If steps 4–8 cycle more than 3 times without convergence, downgrade tier (T1 → T2 base mesh acceptable; T2 → T3 spec only; surface to user). Do not burn unbounded effort on a single asset.

## Out of Scope

- **Rigging Tier 2 humanoids** — armatures, weight painting, IK chains. Separate post-Sprint 09 effort (manual or Mixamo-style auto-rigging).
- **Animations** — idle, walk, attack, death cycles. Defer to Sprint 09b / Sprint 10+.
- **Texture authoring** beyond what generative tools provide; period-authentic touch-ups deferred.
- **Outline shader stencil ref assignment at scene-load time** — Sprint 10+ integration story.
- **Replacing placeholder geometry in `scenes/sections/*.tscn`** — Sprint 10+.
- **Eve FPS hands generation** — Tier 3, spec only.
- **Audio assets** — out of scope for this sprint (not part of hero-set).
- **VFX particle textures** — out of scope.

## Stop Conditions

- **External generation fails consistently** for an asset (>3 prompt iterations without acceptable result) → escalate: downgrade Tier 1 → Tier 2 (base mesh acceptable) or Tier 2 → Tier 3 (defer to external commission).
- **Quality fails art-bible compliance** (visual review fails twice) → re-spec and regenerate, or downgrade tier.
- **Cleanup-step failure** — if Blender cleanup cannot bring poly count under budget without breaking silhouette → re-generate or downgrade.
- **Style drift** — generated meshes don't match art bible silhouette / proportion rules → regenerate with stronger prompts or downgrade tier.
- **Source doc missing** for level contexts (Plaza/Restaurant/Bomb-Chamber) → pause for `design/levels/*.md` authoring.
- **Test failure or regression** — adding `.glb` to `assets/models/` should not regress smoke check; if it does, investigate and fix root cause (no skipping tests).
- **MCP tool gap discovered mid-asset** — if the active MCP variant lacks a tool the workflow requires, surface immediately and switch to a workaround (this is what triggered the Path 4 pivot 2026-05-08).

## Acceptance Criteria

Sprint closes when:

- [ ] All 6 contexts have a written spec file at `design/assets/specs/<target>-assets.md`
- [ ] `design/assets/asset-manifest.md` exists and reflects every asset with current status
- [ ] Every Tier 1 asset has a `.glb` in `assets/models/<context>/` and is marked `Done`
- [ ] Every Tier 2 asset has a base mesh `.glb` in `assets/models/<context>/` and is marked `Base mesh — rig deferred`
- [ ] Every Tier 3 asset has a spec entry marked `External commission needed`
- [ ] Smoke check still passes (no regressions from added asset files)
- [ ] Tech-debt register stays at or below 12 items (currently 11)
- [ ] `production/stage.txt` decision surfaced to user (Pre-Production → Art-Production or Art-Integration-Active)

## Buffer / Carryforward from Sprint 08

Opportunistic if time permits (do not push the sprint to do these — they are pure gravy):

- **TD-008** — `spawn_gate.tscn` parse error (apply LS-008 duck-typing pattern to `tests/integration/feature/document_collection/spawn_gate_test.gd`)
- **TD-009** — split `level_streaming` integration tests into separate gdunit4 CI matrix job to break PhysicsServer3D coupling with player_character tests
- **TD-010 + TD-011** — HC-006 KEY_F* migration to InputMap; `hud_core.gd` hardcoded "100" → `tr()`
- **LS-006 AC-9 memory-invariant test activation** — remove early `return` in `tests/integration/level_streaming/level_streaming_focus_memory_test.gd::test_no_unbounded_memory_growth_round_trip_plaza_stub_b_plaza`
- **MVP build manual evidence** — populate stubs at `production/qa/evidence/level_streaming_shipping_error_fallback.md`, `level_streaming_f5_during_transition.md`, plus PPS-007 + DC-005 visual evidence

## Documentation Gaps (surface only — not in scope)

3 gameplay systems lack GDDs (per session-start hook detection 2026-05-03):

- `src/gameplay/mission_level_scripting/` (6 files)
- `src/gameplay/documents/` (7 files)
- `src/gameplay/stealth/` (19 files)

Suggested action (NOT in this sprint's scope): `/reverse-document design <path>` for each. Surface to user at sprint close.

## Estimated Capacity

- **Mode**: user-paced (discuss-then-implement per context); NOT autonomous
- **Per context**: ~2–4 hours agent-time (spec authoring + MCP generation iterations + Blender cleanup + export). Level contexts add ~1h for level-doc authoring.
- **Total**: ~12–24 hours agent-time, spread across multiple sessions
- **Cross-session continuity**: this plan + `active.md` + `design/assets/asset-manifest.md` are the resume artifacts

## Resume Protocol (cross-session)

To continue Sprint 09 in a new session:

1. Read `production/session-state/active.md` (the START HERE section will reference this sprint plan)
2. Read this file (`production/sprints/sprint-09-asset-commission-hybrid.md`)
3. Read `design/assets/asset-manifest.md` (if it exists yet) to identify the next asset whose status is not `Done` / `Base mesh — rig deferred` / `External commission needed`
4. Resume at the next context (or next asset within a context)

## Stage Transition (decision required from user)

Sprint 08 close-out flagged: `production/stage.txt` should advance from `Pre-Production`. Two candidate values now make sense:

- **`Art-Integration-Active`** — accurate if hybrid pipeline is the new norm and we'll be producing + integrating in alternating cycles
- **`Pre-Production`** (no change) — if user prefers to defer the stage flip until after Sprint 09 closes with assets actually integrated into a scene

Surfacing now; no auto-change. User to decide on first session continuation.

## Collaboration Protocol Reminder

Per `CLAUDE.md` and `feedback_artistic_decisions.md`:
- For each context: discuss high-level direction with concrete options before implementing
- Never write spec files or generate models without explicit user approval
- Never auto-commit; all commits remain user-driven
- Spanish in chat; English in every artifact (per `feedback_language_split.md`)
