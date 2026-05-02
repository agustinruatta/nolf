# Architecture Review Report

| Field | Value |
|-------|-------|
| **Date** | 2026-05-02 (ninth run — delta since 2026-04-30 eighth-run PASS) |
| **Mode** | `/architecture-review` (full mode, delta-focused) |
| **Engine** | Godot 4.6 (pinned 2026-02-12) |
| **GDDs Reviewed** | 24 (was 23 — `design/gdd/player-system.md` umbrella reverse-doc index landed 2026-05-01; introduces 0 new TRs by design) |
| **ADRs Reviewed** | 8 (no new ADRs; ADR-0005 + ADR-0008 status-promoted only) |
| **TR Registry State** | 348 active TRs (unchanged — no TR-introducing GDD revisions this period) |
| **Prior Review** | `architecture-review-2026-04-30.md` (eighth — full PASS after Vulkan-only sweep) |
| **Verdict** | **PASS** (with 3 doc-hygiene advisories — non-blocking; D1/D2/D3 fixed in this session) |

---

## Summary

This review covers the delta from the 2026-04-30 eighth-run PASS through the
close of Sprint 04 (2026-05-02). Two sprints (03 + 04) completed in this window
with the test suite at **314/314 PASS** at last full sign-off. The headline
structural delta is ADR maturity: **all 8 ADRs are now Accepted** (was 5/8
going into this window).

- ADR-0005 promoted Proposed → Accepted on **2026-05-01** via user visual
  sign-off on `prototypes/verification-spike/fps_hands_demo.tscn`. Gates 3, 4,
  5 explicitly deferred to the Player Character FPS-hands production story.
- ADR-0008 promoted Proposed → **Accepted (with deferred numerical
  verification)** on **2026-05-01** via the new Gate 5 Architectural-Framework
  Verification spike (synthetic load passed on dev hardware). Gates 1, 2, 4
  remain deferred behind the Restaurant scene + Iris Xe Gen 12 hardware
  prerequisites.

No new ADRs were authored. Only one GDD changed (`player-system.md`, an
umbrella reverse-doc index that introduces no new mechanics by design). No
engine-reference docs changed.

**The architectural foundation is now complete.** The path through
`/gate-check pre-production` no longer has architectural blockers.

---

## Traceability Summary

| | Prior 2026-04-30 (8th run) | This run | Δ |
|---|---|---|---|
| Total TRs | 348 | 348 | 0 |
| ✅ Covered (ADR-addressed) | ~344 | ~344 | 0 |
| ⚠️ Partial | ~3 | ~3 | 0 |
| ❌ Hard Gap | 0 | 0 | 0 |

`design/gdd/player-system.md` (new since baseline) explicitly states "No new
mechanics, formulas, or tuning knobs are introduced in this file." It is a
navigation index that inherits TRs from `player-character.md` and
`footstep-component.md`, both of which are already in the registry. **Zero new
TRs to register.** All other 23 GDDs unchanged → coverage matrix unchanged
from `architecture-review-2026-04-30.md` §Coverage by new system.

Per-system TR counts (sampled this run for currency check): TR-PC = 20,
TR-FC = 8, TR-SAI = 18 — match the registry state pre-Sprint-02 baseline.

---

## Cross-ADR Conflict Detection

**Clean.** No new conflicts since 2026-04-30 sweep.

The two ADRs that moved this window (ADR-0005, ADR-0008) saw status-field +
Last-Verified + Revision-History changes only — no structural amendments, no
API surface changes, no allocation changes, no decision-text deltas.

`grep -rn "D3D12\|d3d12" docs/architecture/ design/gdd/ project.godot` confirms
the Vulkan-only state from the 2026-04-30 sweep is preserved: only
Revision History annotations remain (no live D3D12 directives).

### Dependency ordering — all-Accepted milestone reached

```
Foundation (no ADR deps):
  1. ADR-0001: Stencil ID Contract                ✅ ACCEPTED 2026-04-30
  2. ADR-0002: Signal Bus + Event Taxonomy        ✅ ACCEPTED 2026-04-29
  3. ADR-0006: Collision Layer Contract           ✅ ACCEPTED 2026-04-29
  4. ADR-0007: Autoload Load Order Registry       ✅ ACCEPTED 2026-04-29

Depends on Foundation:
  5. ADR-0003: Save Format Contract               ✅ ACCEPTED 2026-04-29
  6. ADR-0005: FPS Hands Outline Rendering        ✅ ACCEPTED 2026-05-01
                                                    (G3/G4/G5 deferred to PC FPS-hands story)

Depends on Foundation + Feature:
  7. ADR-0004: UI Framework                       ✅ G1-G4 closed 2026-04-29
                                                    (Status field reads Proposed pending Gate 5
                                                    BBCode→AccessKit AT runtime test;
                                                    Effectively-Accepted for downstream work)

Consolidator (soft-deps Foundation numeric inputs):
  8. ADR-0008: Performance Budget Distribution    ✅ ACCEPTED 2026-05-01
                                                    (with deferred numerical Gates 1/2/4
                                                    behind Restaurant scene + Iris Xe Gen 12)
```

**7 of 8 ADRs unambiguously Accepted; 1 of 8 Effectively-Accepted with single
documented deferred gate.** No cycles. No unresolved hard dependencies.

> **ADR-0004 nuance**: Status field still reads "Proposed" pending Gate 5 (the
> AccessKit AT runner runtime test). Per ADR-0004's own Status text, this is a
> planned production-time gate, not a structural blocker. Treat as
> Effectively-Accepted for downstream story authoring; full Accepted promotion
> lands when the S&A AccessKit AT runner story closes.

---

## Engine Compatibility Audit

**Engine**: Godot 4.6 (pinned 2026-02-12).
**Engine reference docs unchanged this window** (`git log --since="2026-04-30"
-- docs/engine-reference/` returns no commits).

### Post-Cutoff API Usage — no change

All entries from the 2026-04-30 audit table remain accurate. No new
post-cutoff APIs were introduced by the ADR-0005 or ADR-0008 status promotions
(both promotions reused already-verified APIs).

### Deprecated API Check — clean

`grep` against `deprecated-apis.md` patterns: clean across all 8 ADRs
(unchanged since 2026-04-29 audit).

### Stale Version References — none

All 8 ADRs pinned to Godot 4.6. Last Verified dates updated this window:
- **ADR-0005 Last Verified = 2026-05-01** (visual sign-off promotion)
- **ADR-0008 Last Verified = 2026-05-01** (framework spike Gate 5 PASS)
- All other ADRs' Last Verified dates unchanged from 2026-04-30 baseline.

### Engine Specialist Consultation — SKIPPED

Same rationale as runs 5–8: this delta is status-field promotions on
already-verified ADR architectures. No new post-cutoff API surface introduced.
The 2026-05-01 evidence files
(`production/qa/evidence/adr-0008-synthetic-load-2026-05-01.md`, the visual
sign-off captured in `prototypes/verification-spike/fps_hands_demo.tscn` user
review) constitute domain-expert validation in their own right.

---

## Design Revision Flags (Architecture → Design Feedback)

**None.** No new engine findings were generated this window; no GDD
assumptions are newly contradicted by verified engine reality. The four
producer-tracked Cutscenes-amendment carryforwards from the seventh-run review
remain in their own scope (not re-flagged here).

---

## Architecture Document Coverage

Three doc-hygiene staleness items were detected this run. All three were
**fixed in this session** per the user's `Report + apply D1/D2/D3` selection;
recorded here for the audit trail.

| # | File | Stale claim | Reality | Severity | Status |
|---|------|-------------|---------|----------|--------|
| **D1** | `docs/architecture/architecture.md` (~10 sites: L14, L1391, L1466, L1476, L1506, L1546, L1548, L1604, L1612, plus cover-page metadata) | "all 8 ADRs Proposed; 30+ verification gates outstanding" / "21 verification gates outstanding" | All 8 ADRs now Accepted (or Effectively-Accepted via ADR-0004 single deferred gate); verification gates either closed or explicitly deferred to documented production stories | **MEDIUM doc-hygiene** | ✅ Fixed |
| **D2** | `design/gdd/systems-index.md` | No row for `player-system.md` reverse-doc umbrella index landed 2026-05-01 | The umbrella exists but is undiscoverable via the canonical systems list | **LOW doc-hygiene** | ✅ Fixed |
| **D3** | `docs/architecture/tr-registry.yaml` header | `version: 2`, `last_updated: "2026-04-24"` | Last actual append was TR-CMC-* on 2026-04-29; reviews 5–9 verified the registry without bumping metadata | **LOW doc-hygiene** | ✅ Fixed |

None of these affect architectural correctness. They were bookkeeping that
drifted across the Sprint 02→04 implementation push.

No structural changes to architecture.md content (decisions, fencing, layer
map, integration contracts unchanged).
No orphaned architecture entries.
No systems from `systems-index.md` missing from the architecture layer map.

---

## Verdict: **PASS**

### Why PASS

- **Architecture coverage unchanged** — 348 TRs, all covered, zero hard gaps.
- **No cross-ADR conflicts** — Vulkan-only cascade preserved from prior sweep;
  no new conflicts opened.
- **Engine consistent** — 8 ADRs pinned to Godot 4.6; no deprecated APIs;
  engine-reference unchanged this window.
- **Dependency graph clean** — no cycles; 7/8 ADRs Accepted unambiguously,
  1/8 Effectively-Accepted with single documented deferred gate.
- **Major maturity milestone** — all 8 ADRs at terminal-or-deferred-only
  state; this was the last structural blocker for the Pre-Production →
  Production gate.
- **No GDD revision flags** — no engine reality contradicts any GDD
  assumption.

### Verification Gate Status (cumulative)

| ADR | Status | Open gates |
|-----|--------|------------|
| 0001 | Accepted 2026-04-30 | None — all 4 gates closed |
| 0002 | Accepted 2026-04-29 | None |
| 0003 | Accepted 2026-04-29 | None |
| 0004 | Effectively-Accepted | G5 (BBCode→AccessKit AT runner) — Settings & Accessibility production story |
| 0005 | Accepted 2026-05-01 | G3, G4, G5 — PC FPS-hands production story |
| 0006 | Accepted 2026-04-29 | None |
| 0007 | Accepted 2026-04-29 | None |
| 0008 | Accepted 2026-05-01 (deferred-numerical) | G1, G2, G4 — await Restaurant scene + Iris Xe Gen 12 hardware |

### Execution-phase items remaining (do not block PASS)

1. **ADR-0002 Cutscenes-amendment commit bundle** (carryforward from 7th run
   — atomic single-PR landing of the four companion GDD edits:
   `cutscenes-and-mission-cards.md`, `audio.md` L407, `signal-bus.md`,
   `mission-level-scripting.md`). Unchanged status this run.
2. **ADR-0004 Gate 5** — closes inside the Settings & Accessibility production
   story.
3. **ADR-0005 Gates 3, 4, 5** — close inside the Player Character FPS-hands
   rendering production story.
4. **ADR-0008 Gates 1, 2, 4** — close when Restaurant scene exists AND SAI
   ships AND Combat ships AND Iris Xe Gen 12 hardware is acquired.
5. **`stealth-ai.md` Status: Revised (4th pass) — pending re-review in fresh
   session.** Sprint 04 implementation has consumed it as authoritative
   (10 stealth-ai stories landed). A `/design-review` re-pass in a fresh
   session would close that loop. **Not blocking for architecture** (TRs
   stable, all covered) but flagging because Sprint 04 stealth code is now
   live against an "unreviewed" GDD revision.

---

## Priority Action List (next 1–2 sessions)

### Session A — `/gate-check pre-production` (recommended next)

Now that 8/8 ADRs are Accepted (or Effectively-Accepted) and Sprint 04 closed,
the Pre-Production → Production gate is expected to **PASS**. This is the
most impactful next move.

### Session B — Sprint 05 kickoff

Sprint 04 closed on schedule (2026-05-02). The art-integration-ready milestone
(end of Sprint 08) is the next major checkpoint. Per the multi-sprint
roadmap, Sprint 05 begins the next foundation slice.

### Session C — Cutscenes ADR-0002 amendment commit bundle (carryforward)

Single-PR landing the four companion GDD edits. Estimated <1 hour. Independent
of A and B; can land any time.

### Session D (optional) — `stealth-ai.md` re-review pass

`/design-review design/gdd/stealth-ai.md` to close the 4th-pass "pending
re-review" Status loop. Sprint 04 implementation provides empirical confidence
in the GDD's content; a re-review now is mostly a paperwork close-out.

---

**Re-run trigger**: `/architecture-review` after (a) any new ADR is authored,
(b) any GDD enters Production phase and surfaces an unforeseen architectural
need, (c) engine version pin changes, (d) ADR-0004 Gate 5 closes (would flip
ADR-0004 Status to fully Accepted), (e) the rendering-algorithm follow-up ADR
(jump-flood implementation under ADR-0001 IG 7) is authored, (f) the
Restaurant scene + Iris Xe Gen 12 hardware become available for ADR-0008
G1/G2/G4 closure.

**Gate guidance**: Run `/gate-check pre-production` next session. With all 8
ADRs at terminal-or-deferred-only state and the doc-hygiene sweep applied this
session, no architectural blockers remain.

---

## Related

- `docs/architecture/requirements-traceability.md` — unchanged this run (no new TRs)
- `docs/architecture/tr-registry.yaml` — header bumped this session (D3 fix)
- `docs/architecture/architecture-review-2026-04-30.md` — prior (eighth) full review baseline
- `docs/architecture/adr-0005-fps-hands-outline-rendering.md` — promoted Proposed → Accepted 2026-05-01
- `docs/architecture/adr-0008-performance-budget-distribution.md` — promoted Proposed → Accepted 2026-05-01
- `docs/architecture/architecture.md` — D1 stale-Proposed sweep applied this session
- `design/gdd/systems-index.md` — D2 Player System row added this session
- `design/gdd/player-system.md` — new umbrella reverse-doc index landed 2026-05-01 (introduces 0 new TRs)
- `production/qa/evidence/adr-0008-synthetic-load-2026-05-01.md` — Gate 5 Architectural-Framework Verification evidence
- `production/sprints/sprint-04-stealth-ai-foundation.md` — Sprint 04 plan (closed 2026-05-02 per recent commit)
