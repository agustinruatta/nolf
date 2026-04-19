# Session State

**Last updated:** 2026-04-19

## Current task
✅ `design/gdd/post-process-stack.md` complete (2026-04-19) — all 8 required sections. Status: Designed (pending review). Player Fantasy: "A Photograph That Breathes." Completed: **ALL 7 MVP Foundation GDDs DONE** (signal-bus, input, audio, localization-scaffold, save-load, outline-pipeline, post-process-stack = 7/16 MVP). Next phase: MVP Core layer GDDs — Player Character (system 8) and Level Streaming (system 9). After those, MVP Feature layer: Stealth AI (the gating risk per concept doc), Combat & Damage, Inventory & Gadgets, etc.

## Status
- ✅ Engine configured: Godot 4.6, GDScript (`CLAUDE.md`, `.claude/docs/technical-preferences.md`)
- ✅ Game concept written: `design/gdd/game-concept.md` (The Paris Affair)
- ✅ Art bible complete (all 9 sections): `design/art/art-bible.md`
- ✅ Systems index created and revised after director review: `design/gdd/systems-index.md` — **23 systems** (16 MVP / 7 VS) + 4 required ADRs
- ✅ Required ADRs: **4/4 ALL AUTHORED** (all Proposed; verification gates pending)
  - ✅ ADR-0001: Stencil ID Contract — Proposed (4 verification gates pending)
  - ✅ ADR-0002: Signal Bus + Event Taxonomy — Proposed (smoke test pending; 32 signals across 8 domains)
  - ✅ ADR-0003: Save Format Contract — Proposed (3 verification gates pending; binary .res, sectional, 8 slots)
  - ✅ ADR-0004: UI Framework — Proposed (3 verification gates pending; Theme inheritance + InputContext autoload + FontRegistry static class)
- 🟢 **All MVP Foundation system GDDs are now unblocked** — start with `/design-system signal-bus` (system 1 in design order) or any of systems 1-7 (all parallel-designable after the 4 ADRs)
- ⏳ System GDDs: 0/23 authored
- ⏳ Architecture document: not started (run `/create-architecture` after 4 ADRs + 5–8 GDDs)

## Key files modified
- `CLAUDE.md` — Technology Stack updated to Godot 4.6 / GDScript
- `.claude/docs/technical-preferences.md` — fully populated (engine, naming, performance, specialists)
- `design/gdd/game-concept.md` — concept doc; corrected Visual Identity Anchor to remove alert-state lighting (NOLF1 fidelity)
- `design/art/art-bible.md` — all 9 sections; Alarm Orange added as 8th palette color for HUD critical state
- `design/gdd/systems-index.md` — 19 systems decomposed, dependency-mapped, priority-tiered
- `production/review-mode.txt` — `lean`

## Next steps (any of these)
- Run `/design-system input` (or any of systems 1–5 — Foundation tier — designable in parallel)
- Run `/map-systems next` to pick up the highest-priority undesigned system automatically
- Run `/create-architecture` once 5–8 GDDs exist to inform technical architecture
- Stealth AI (system #8) is the gating technical risk — prototype immediately after its GDD

## Open design questions (captured in art bible 7E)
- Document reading during alert state — does AI pause or continue?
- Gadget cycling visual feedback — needs UX pass before prototyping
- Subtitle placement during document overlay
- HUD contrast verification per section (playtest deliverable)
