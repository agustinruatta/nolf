# Verification Spike Prototypes

This directory holds the prototypes used to close ADR verification gates during Sprint 01 — Technical Verification Spike. These are intentionally minimal artifacts, not production code. They exist to confirm engine APIs behave as the ADRs assume on Godot 4.6 across both Vulkan (Linux) and D3D12 (Windows) backends.

| Field | Value |
|-------|-------|
| **Sprint** | Sprint 01 — Technical Verification Spike |
| **Engine** | Godot 4.6 |
| **Backends Tested** | Vulkan (Linux) + D3D12 (Windows) |
| **Status** | In Progress |

See `production/sprints/sprint-01-technical-verification-spike.md` for the full work plan and `verification-log.md` in this directory for per-gate evidence.

## What's Here

| File | Purpose | Closes |
|------|---------|--------|
| `verification-log.md` | Per-ADR-per-gate evidence log; updated as gates close | All gates |
| `save_format_check.gd` | `ResourceSaver.save(...FLAG_COMPRESS)` round-trip + atomic rename test | ADR-0003 G1 + G2 |
| `ui_framework_check.tscn` + `.gd` | Verifies `accessibility_*` properties, `Theme.fallback_theme`, `auto_translate_mode`, modal dismiss, BBCode→AccessKit | ADR-0004 G1 + G3 + G5 |
| `signal_bus_smoke.tscn` + `.gd` | `Events.emit` → `EventLogger` prints → subscriber receives | ADR-0002 G1, ADR-0007 G(b) |
| `stencil_tier_demo.tscn` + `.gdshader` | 4 cubes writing stencil values 0/1/2/3 + `CompositorEffect` reading them | ADR-0001 G1 + G4 |
| `fps_hands_demo.tscn` + `.gdshader` | `SubViewport` with stand-in hand mesh using inverted-hull outline; side-by-side with stencil-rendered tier-HEAVIEST world object | ADR-0005 G1 |
| `stencil_compositor_outline.gd` + `stencil_compositor_demo.{tscn,gd}` + `shaders/{stencil_pass,outline}.glsl` | Screen-space-stable outline `CompositorEffect`: 3 stencil-test graphics passes write tier markers to an intermediate texture; compute shader paints outlines into the scene color buffer at tier-specific pixel widths. Pattern adapted from [dmlary/godot-stencil-based-outline-compositor-effect](https://github.com/dmlary/godot-stencil-based-outline-compositor-effect) (MIT). | ADR-0001 G2 (Vulkan) + G4 |
| `_screenshot_capture.{gd,tscn}` | Helper that loads a target scene, lets it render a few frames, saves a PNG. Used by the agent to verify visual prototypes without opening the editor: `xvfb-run -a godot --rendering-driver vulkan ... _screenshot_capture.tscn -- --target=<path> --out=user://...`. | All visual gates |

Some files are added incrementally as Group 2 and Group 3 work proceeds.

## How to Run

### 1. Open the project in Godot 4.6

```
godot --editor /home/agu/Projects/Claude-Code-Game-Studios/project.godot
```

The first open will populate input map defaults and any other engine-version-dependent settings the manually-authored `project.godot` left blank. Save the project once Godot has populated it (`Project → Save All` or close the editor cleanly).

### 2. Run individual prototypes

Each prototype scene is self-contained. Open it from the Godot editor's filesystem panel:

`prototypes/verification-spike/<prototype-name>.tscn`

Press **F6** (Run Current Scene) to run only that scene without invoking the autoload-heavy main scene.

For pure-script verifications (e.g., `save_format_check.gd`), attach the script to a `Node` in a temporary test scene or run via `Tools → Execute Script` (if exposed in 4.6).

### 3. Record results

For each gate verified, append an entry to `verification-log.md`:

```markdown
## ADR-XXXX Gate N — <gate description>

- **Date**: 2026-MM-DD
- **Backend**: Vulkan / D3D12 / Both
- **Result**: PASS / FAIL / PARTIAL
- **Evidence**: <path to screenshot, log snippet, or commit>
- **Notes**: <anything unexpected>
```

If a gate fails, see `production/sprints/sprint-01-technical-verification-spike.md` §Risks for the amendment workflow.

## Cleanup After Spike

Once all gates close and the relevant ADRs are promoted to `Accepted`:

- This directory is preserved as historical evidence; do NOT delete.
- The verification log becomes a permanent reference for engine-version upgrade reviews (when Godot 4.7+ ships, re-running the same prototypes confirms whether ADR assumptions still hold).
- Production code does NOT depend on anything in this directory — production implementations live in `src/`.

## Conventions

- File names: `snake_case` per technical-preferences.md.
- Scenes: PascalCase root node, snake_case file name (e.g., `StencilTierDemo` root in `stencil_tier_demo.tscn`).
- Comments: every prototype script has a header comment citing which ADR + gate it verifies.

## Related

- `production/sprints/sprint-01-technical-verification-spike.md` — sprint plan
- `verification-log.md` — running evidence
- `docs/architecture/adr-*.md` — ADRs being verified
- `docs/engine-reference/godot/VERSION.md` — engine version pin
- `.claude/docs/technical-preferences.md` — coding standards applied
