---
name: MLS epic stories created
description: 5 story files written for mission-level-scripting epic (VS scope); covers autoload scaffold, state machine, Plaza section contract, SaveGame assembler, and Plaza objective integration
type: project
---

5 stories written for `production/epics/mission-level-scripting/` on 2026-04-30.

**Why:** VS scope for The Paris Affair — one Plaza mission, one objective (Recover Plaza Document), autosave chain wired to all 6 capture() calls.

**Story breakdown:**
- story-001: autoload scaffold (TR-MLS-006, 007) — ADR-0007 — Logic
- story-002: mission state machine + 4 Mission-domain signals (TR-MLS-001, 002, 011, 018, 019) — ADR-0002 — Logic
- story-003: Plaza section authoring contract (TR-MLS-015, 016, 017) — ADR-0006 — Logic
- story-004: SaveGame assembler FORWARD gate (TR-MLS-003, 004, 005, 012, 013, 014) — ADR-0003 — Integration
- story-005: Plaza objective integration NEW_GAME→COMPLETED (TR-MLS-008, 009, 010) — ADR-0002+0003 — Integration

**Post-VS deferrals:** multi-section trigger choreography, bomb-disarm sequence, scripted_dialogue_trigger for banter beats, peek_surface/placeable_surface tags, CMC cutscene handshake.

**Open questions still live:** OQ-MLS-2 (F&R dying-state must capture triggers_fired), OQ-MLS-3 (_is_section_live guard), TR-MLS-009 ADR-0006 Triggers-layer amendment.

**How to apply:** Use this to resume sprint planning — start with `/story-readiness story-001-mls-autoload-scaffold.md` then work in dependency order (001→002→003→004→005).
