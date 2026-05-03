# DC-005 AC-7 Smoke Check — DEFERRED to MVP Build

**Story**: DC-005 Plaza Tutorial Integration
**AC-7 (AC-DC-12.1)**: Manual smoke check requires built MVP with Plaza section reachable + outline pipeline + HUD + audio assets present.
**Status**: DEFERRED — pending MVP build availability.

**Deferred items** (all depend on systems outside DC scope):
- Tier 1 Ink Black (4 px) outline visible on body — requires PostProcessStack outline pipeline (#18)
- HUD prompt shows tr("ui.interact.pocket_document") text — requires HUD State Signaling (#19, VS scope)
- Pressing E causes body to disappear snap-clear (same frame) — requires real input pipeline + PlayerCharacter interact reach
- No UI counter element appears — requires HUD audit (epic-DoD nag check)
- Paper-slide SFX audible within 100 ms — requires AUD-005 footstep + audio stinger work + SFX assets

**Rationale**: All 6 AC-7 sub-checks depend on systems outside DC scope:
- PostProcessStack epic (#18) — currently in Sprint 07 (PPS-005, PPS-006, PPS-007)
- HUD State Signaling epic (#19) — VS scope
- Document Overlay UI epic (#20) — VS scope
- Audio asset library — pending Sprint 07 AUD-005 + sound design pass

DC-005 delivers: 3 Document.tres resources + Plaza scene authoring + 6 localization keys + automated round-trip integration test (`plaza_round_trip_test.gd`). The data + scene + integration layer is fully verified by automated tests.

**Re-test trigger**: First MVP build with PostProcessStack outline pipeline + HUD prompt strip + audio paper-slide SFX present in Plaza section. At that point, run the manual smoke check protocol from DC-005 §QA Test Cases AC-7 and append a results section to this file.

**Owner**: QA Lead — schedule manual smoke retest at MVP gate.
