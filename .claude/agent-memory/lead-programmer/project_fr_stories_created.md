---
name: Failure & Respawn stories created
description: 6 VS-scoped stories created for the failure-respawn epic on 2026-04-30; TR-ID coverage, dependency chain, and post-VS deferrals recorded
type: project
---

6 VS-scoped story files written to `production/epics/failure-respawn/` on 2026-04-30.

| # | Slug | Type | TR-IDs |
|---|------|------|--------|
| 001 | autoload-scaffold-state-machine | Logic | TR-FR-001, TR-FR-010 |
| 002 | slot0-autosave-assembly-mls-capture-chain | Logic | TR-FR-003, TR-FR-004 |
| 003 | respawn-triggered-signal-ordering-contract | Logic | TR-FR-002, TR-FR-008, TR-FR-014 |
| 004 | plaza-checkpoint-assembly-section-entered-cr7-guard | Logic | TR-FR-006, TR-FR-007 |
| 005 | ls-step9-restore-callback-reset-for-respawn-vs-beat | Integration | TR-FR-005, TR-FR-009, TR-FR-011, TR-FR-012, TR-FR-013 |
| 006 | anti-pattern-fences-fr-autosaving-on-respawn | Config/Data | TR-FR-002 (lint), TR-FR-003 (fence), TR-FR-008 (fence) |

**Dependency chain**: 001 → 002 → 003; 001 → 004; {002, 003, 004} → 005 → 006.

**Post-VS deferrals**:
- Combat-driven death paths (bullet/blade DeathCause) — no combat in VS
- Kill-plane fall-out-of-bounds detector (Plaza is bounded)
- Ammo respawn floor actual math — VS no-op; Inventory epic coord item
- Multi-checkpoint progression — Mission Scripting extension point

**Why:** VS narrowing from EPIC.md VS Scope Guidance applied strictly. All 14 TR-IDs covered across the 6 stories.

**How to apply:** When continuing F&R implementation, start with story-001 (autoload scaffold), follow dependency chain. Post-VS stories must wait for combat and Inventory epics.
