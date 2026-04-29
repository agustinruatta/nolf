# Verification Log — Sprint 01 Technical Verification Spike

Per-ADR-per-gate evidence trail. Append a new entry every time a gate is verified (PASS or FAIL). Do NOT overwrite earlier entries — failed-then-fixed sequences are useful history.

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Sprint** | Sprint 01 — Technical Verification Spike |
| **Started** | 2026-04-29 |
| **Last Updated** | 2026-04-29 (initial) |

## Status Summary

| ADR | Gate | Status | Verified Date |
|-----|------|--------|--------------|
| 0001 | G1 — `BaseMaterial3D` stencil write property in 4.6 inspector OR mandatory `ShaderMaterial` path | Pending | — |
| 0001 | G2 — `CompositorEffect` GLSL stencil bind/sample on Vulkan + D3D12 | Pending | — |
| 0001 | G3 — Outline pass profiling on Intel Iris Xe-class @ 1080p + 75% scale | Pending | — |
| 0001 | G4 — Shader Baker handles `CompositorEffect` shaders | Pending | — |
| 0002 | G1 — `Events` autoload skeleton + EventLogger pub/sub end-to-end | Pending | — |
| 0003 | G1 — `ResourceSaver.save(... FLAG_COMPRESS)` returns OK on `.res` in 4.6 editor | Pending | — |
| 0003 | G2 — `DirAccess.rename(tmp, final)` is the correct atomic-rename API in 4.6 | Pending | — |
| 0004 | G1 — `accessibility_description` / `accessibility_role` settability check | Pending | — |
| 0004 | G3 — `_unhandled_input()` modal dismiss on KB/M + gamepad | Pending | — |
| 0004 | G5 — `RichTextLabel` BBCode → AccessKit plain-text serialization | Pending | — |
| 0005 | G1 — Inverted-hull hand outline matches tier-HEAVIEST stencil outline | Pending | — |
| 0005 | G2 — Cross-platform Vulkan + D3D12 render parity | Pending | — |
| 0006 | G1 — `physics_layers.gd` exists with all 5 named constants + masks | Pending | — |
| 0006 | G2 — `project.godot` named 3D physics layer slots 1–5 match constants | Pending | — |
| 0006 | G3 — One real gameplay file uses constants end-to-end | Pending | — |
| 0007 | G(a) — `project.godot [autoload]` block matches §Key Interfaces byte-for-byte (10 entries, `*res://`) | Pending | — |
| 0007 | G(b) — ADR-0002 G1 smoke test passes (incidentally validates cross-autoload reference safety) | Pending | — |
| 0008 | (amended — gates inherit from ADR-0001/0002/0003/0004/0007 verification) | Pending | — |

## Evidence Entries

*(Empty — populated as gates close. Template for each entry below.)*

```markdown
### ADR-XXXX Gate N — <gate description>

- **Date**: 2026-MM-DD
- **Verified by**: <user / agent>
- **Backend(s)**: Vulkan / D3D12 / Both / N/A
- **Result**: PASS / FAIL / PARTIAL
- **Prototype run**: `prototypes/verification-spike/<file>`
- **Evidence**:
  - Output snippet: `...`
  - Screenshot: <path-or-link>
  - Editor inspector observation: <observation>
- **Notes**: <anything unexpected, deviations from ADR assumption>
- **Action taken**: <ADR amendment? Workaround? Move to Accepted?>
```

## Outcome — ADR Status Promotions

Append entries here when an ADR moves to a new status. The ADR file's own `Status:` and `Last Verified:` fields are also updated in the same pass.

```markdown
### ADR-XXXX → Accepted

- **Date**: 2026-MM-DD
- **All gates passed**: G1 ✅ G2 ✅ ...
- **Verification log entries**: <link refs to evidence above>
- **ADR file edits**: `docs/architecture/adr-XXXX-*.md` lines: Status (Proposed → Accepted), Last Verified date stamp
- **Downstream impact**: <which stories / GDDs / other ADRs unblock>
```

## Outcome — ADR Amendments / Supersessions

If a gate fails and the ADR needs amendment (small fix) or supersession (rewrite), record here.

```markdown
### ADR-XXXX → Amended (or Superseded by ADR-YYYY)

- **Date**: 2026-MM-DD
- **Failed gate**: G_N
- **Failure detail**: <what happened>
- **Resolution path**: Amend / Supersede / Defer
- **Edits applied**: <diff summary or commit ref>
- **Re-verification status**: <re-run gate result>
```

## Related

- `production/sprints/sprint-01-technical-verification-spike.md` — sprint plan
- `README.md` (this directory) — how to run prototypes
- `docs/architecture/adr-*.md` — ADRs under verification
- `docs/engine-reference/godot/VERSION.md` — engine version pin
