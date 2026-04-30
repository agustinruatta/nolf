# Story 005: Plaza VS integration smoke — BQA briefing + document suppress/restore

> **Epic**: Dialogue & Subtitles
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2-3 hours (M — end-to-end integration test + one playthrough evidence screenshot)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/dialogue-subtitles.md`
**Requirement**: TR-DLG-009
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0004 (UI Framework — IG5 self-suppression), ADR-0007 (Autoload Load Order Registry), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**:
- ADR-0002: The Plaza BQA briefing SCRIPTED line triggers via `scripted_dialogue_trigger(scene_id)` — but at VS scope, MLS full signal contract is not yet active (§C.16 — "hardcoded MVP-3 BQA briefing trigger acceptable at VS"). A hardcoded trigger on section load is the VS-scoped implementation. Audio subscribes to `dialogue_line_started`/`dialogue_line_finished` for ducking — D&S never touches Audio mix bus directly; this integration test verifies the subscriber boundary is clean.
- ADR-0004 §IG5: The document_opened → suppress → document_closed → restore flow is the load-bearing VS integration exercise of ADR-0004's self-suppression rule. Document Overlay UI emits `document_opened` and `document_closed`; D&S subscribes and self-suppresses. DOV never calls D&S. The integration test exercises this boundary.
- ADR-0007: `Audio` autoload at line N (currently not in the 10-entry table per EPIC.md — Audio is a scene-tree node per Audio EPIC.md overview). D&S emits signals; Audio subscribes from its own `_ready()`. The integration test verifies the subscriber receives the signal.
- ADR-0008: This integration test exercises the complete event-frame cost chain. The test does not measure milliseconds (advisory profiling deferred to lead sign-off per AC-DS-9.1), but confirms D&S has no per-frame callbacks (structural grep gate).

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM
**Engine Notes**: This is an integration test that exercises the full scene tree: `DialogueAndSubtitles` Node, `SubtitleCanvasLayer`, `Label`, `AudioStreamPlayer`, `CaptionTimer`, `WatchdogTimer`, mock `Events` autoload, and mock `AudioManager`. All individual components have been verified in Stories 001–004. The integration risk is signal routing across the scene tree boundary — stable since Godot 4.0. VG-DS-1 (auto_translate_mode locale re-resolve) is ADVISORY and should be spot-checked during this story's manual verification step.

**ADR-0004 (Proposed — G5 deferred)**: ADR-0004 is Proposed pending Gate 5. This story exercises only plain-text subtitle rendering (no BBCode). The VS playthrough uses `Label.auto_translate_mode = ALWAYS` with a registered translation key — unaffected by G5. Speaker label rendering (CR-DS-16) is post-VS; this story verifies the BQA briefing handler line only.

**Control Manifest Rules (Feature layer)**:
- Required: D&S self-suppresses on `document_opened` — DOV must NOT call D&S; test asserts DOV has no method calls on D&S
- Required: Audio is subscriber-only; D&S is publisher-only — test asserts D&S has no calls into Audio methods
- Forbidden: `subtitle_visibility_pushed_externally` — the integration test includes a grep confirming no external system pushes visibility onto D&S
- Forbidden: `audio_ducking_in_dialogue_subtitles` — the integration test confirms D&S source has zero calls to Audio bus APIs

---

## Acceptance Criteria

*From GDD `design/gdd/dialogue-subtitles.md` §H.13 Plaza MVP Smoke, §H.3 Suppression/Overlay, §H.10 Audio Integration, scoped to VS one-line BQA briefing:*

- [ ] **AC-1** (from AC-DS-13.3): GIVEN the Plaza tutorial section loaded with the BQA briefing trigger active, WHEN the SCRIPTED_SCENE MVP-3 handler line fires (Handler: "Sterling. The Plaza opening. Try not to draw attention."), THEN `dialogue_line_started(speaker=&"BQA_HANDLER_NAMED", line_id=&"dlg.bqa.briefing.opening")` emits; the subtitle renders the resolved English text at bottom-center; `dialogue_line_finished` emits after both audio and timer complete; the subtitle clears.
- [ ] **AC-2** (from AC-DS-13.1 V.2 Radiator partial — VS scope): GIVEN the Plaza section with MVP-1 CURIOSITY_BAIT line active, WHEN the trigger fires AND a mock alert-state-change (UNAWARE→SUSPICIOUS) fires mid-bark, THEN the bark plays to `_audio_player.finished` without interruption; caption remains visible for full F.1 duration; `dialogue_line_finished` fires only after both audio and timer complete.
- [ ] **AC-3** (from AC-DS-3.1 + AC-DS-3.2): GIVEN a SCRIPTED bark in flight with subtitle visible, WHEN `Events.document_opened(&"plaza_doc_001")` fires, THEN subtitle suppresses (CanvasLayer hidden); audio continues; WHEN `Events.document_closed(&"plaza_doc_001")` fires before line ends, THEN subtitle restores and caption re-renders for the remaining duration. This is the one VS self-suppression flow from EPIC.md VS Scope Guidance.
- [ ] **AC-4** (from AC-DS-10.2): GIVEN a spy on `Events.dialogue_line_started` and a spy on `AudioLinePlayer.play()`, WHEN the BQA briefing line fires, THEN `dialogue_line_started` spy records a call BEFORE the `play()` spy records a call (step 3 before step 4 ordering per CR-DS-2).
- [ ] **AC-5** (from AC-DS-1.1 applied to the running integration): GIVEN the integration test scene, WHEN CI runs `grep -r "dialogue_line_started\.emit\|dialogue_line_finished\.emit" src/`, THEN the only matching file is `dialogue_and_subtitles.gd` (sole emitter — no other system emitting these signals).
- [ ] **AC-6** (from AC-DS-9.2): GIVEN the integration test scene idle between barks, WHEN 60 frames pass, THEN no `_process` or `_physics_process` contribution from D&S. Structural verification: `grep -L "_process\|_physics_process" dialogue_and_subtitles.gd` returns the filename.
- [ ] **AC-7** (visual evidence): GIVEN the Plaza section running with the BQA briefing line active, WHEN a screenshot is captured during subtitle display, THEN the subtitle is visible bottom-center in Courier/monospace font with period-authentic styling (no drop shadow, hard-edge backplate, plain text), and the Health/Weapon HUD widgets are not overlapped. Screenshot filed at `production/qa/evidence/plaza-subtitle-intro-[date].png`.

---

## Implementation Notes

*Derived from GDD §C.7 MVP-3 + §C.16 VS boundary + ADR-0002 + ADR-0004 §IG5:*

VS-scoped trigger for MVP-3 BQA briefing: At VS, MLS's full `scripted_dialogue_trigger(scene_id)` signal contract is not yet active (MLS epic stories are not shipped at VS entry). The acceptable VS workaround per GDD §C.16 is a hardcoded trigger on section load — a one-shot `call_deferred("_trigger_bqa_briefing")` in `_ready()` on a `PlazaSceneController` node (or equivalent mission scripting stub). This is temporary scaffolding; when MLS ships the signal contract, the hardcoded trigger is replaced.

The integration test must verify three boundaries in one scene:
1. D&S ↔ Events (signal routing)
2. D&S ↔ AudioLinePlayer (bus = "Voice"; play before ducking — step 3/4 order)
3. D&S ↔ Document Overlay boundary (DOV emits `document_opened`; D&S self-suppresses; DOV never calls D&S)

Test scene structure for the integration test:
```
TestRoot
├── Events (autoload — already registered)
├── DialogueAndSubtitles (the system under test)
│   ├── SubtitleCanvasLayer (Layer=2)
│   │   └── SubtitleLabel
│   ├── AudioLinePlayer (bus="Voice")
│   ├── CaptionTimer
│   └── WatchdogTimer
└── MockDocumentOverlay (emits document_opened/closed; never calls D&S methods)
```

`MockDocumentOverlay` is a bare `Node` that calls `Events.document_opened.emit(&"plaza_doc_001")` and `Events.document_closed.emit(&"plaza_doc_001")` — it has NO reference to `DialogueAndSubtitles` or any of its members. This structural separation is the test of FP-OV-6.

Audio subscriber boundary: In the integration test, a `MockAudioManager` Node subscribes to `Events.dialogue_line_started` and records the call. The test asserts: (a) mock receives `dialogue_line_started` after play; (b) D&S source contains zero calls to `AudioServer`, `Audio.*`, or any bus-modification API. The actual ducking implementation is in the Audio epic and is not tested here.

VO asset for VS: `assets/audio/vo/bqa_handler/dlg.bqa.briefing.opening_en.ogg` — a placeholder/prototype OGG file must exist for the integration test (generated TTS or silent 2.0 s stub is acceptable for VS; final VO asset is Audio Director's pipeline responsibility). The `DialogueLine.tres` resource for the BQA briefing must exist at `assets/data/dialogue/plaza/dlg_bqa_briefing_opening.tres` with `id = &"dlg.bqa.briefing.opening"`, `text_key = &"dlg.bqa.briefing.opening"`, and `audio_stream` bound to the stub OGG.

---

## Out of Scope

*Handled by neighbouring stories and other epics — do not implement here:*

- Story 001: Signal declarations + DialogueLine schema (must be DONE)
- Story 002: Orchestrator lifecycle (must be DONE)
- Story 003: Suppression state machine (must be DONE)
- Story 004: Typography + renderer configuration (must be DONE)
- Post-VS: MLS `scripted_dialogue_trigger` full signal contract (replaces hardcoded trigger); CURIOSITY_BAIT full VS line library (MVP-1 Radiator is one line; guard banter library is post-VS); Voice bus ducking -12 dB during document_opened (CR-DS-17 — Audio epic owns this, not D&S); AccessKit live-region `accessibility_live` polite announcement (pending VG-DS-2); speaker label rendering (CR-DS-15/16); intercom radio chatter; multi-line conversation queue; `SCRIPTED_SCENE 7b` two-line sequential dispatch (MVP-2 GuardA→GuardB — deferred past VS per EPIC.md)

---

## QA Test Cases

**AC-1 — BQA briefing smoke**
- **Given**: Plaza section with mock SCRIPTED trigger; `dlg_bqa_briefing_opening.tres` DialogueLine resource; stub OGG asset
- **When**: trigger fires
- **Then**: `Events.dialogue_line_started` spy records `(speaker=&"BQA_HANDLER_NAMED", line_id=&"dlg.bqa.briefing.opening")`; `SubtitleLabel.text == "dlg.bqa.briefing.opening"` (raw key; auto-resolved visually to English); `AudioLinePlayer.playing == true`; after mock audio finishes and CaptionTimer expires, `Events.dialogue_line_finished` spy records call; `SubtitleLabel.text == ""`
- **Edge cases**: stub OGG is 0.0 s length — FP-DS-21 guard must reject it; use a >= 0.1 s stub

**AC-2 — CURIOSITY_BAIT mid-alert protection (V.2 Radiator)**
- **Given**: Mock SAI emitting `actor_became_alerted(guard_node, CURIOSITY_BAIT, ...)`; D&S starts MVP-1 line; mock audio duration 3.0 s
- **When**: mock SAI emits `alert_state_changed(guard_node, UNAWARE, SUSPICIOUS, MINOR)` mid-bark (at 1.0 s into playback)
- **Then**: `AudioLinePlayer.playing == true` (not stopped); CaptionTimer still running; no `dialogue_line_finished` until both audio + timer complete; bark plays full 3.0 s
- **Edge cases**: SCRIPTED trigger fires mid-CURIOSITY_BAIT (bucket 1 interrupts) — this interrupts correctly; that is expected behavior per CR-DS-7

**AC-3 — VS document suppress/restore flow**
- **Given**: BQA briefing line in flight (subtitle VISIBLE); mock `MockDocumentOverlay` node exists with no reference to `DialogueAndSubtitles`
- **When**: `MockDocumentOverlay` emits `Events.document_opened(&"plaza_doc_001")`
- **Then**: `SubtitleCanvasLayer.visible == false`; `_label.visible == false`; `AudioLinePlayer.playing == true` (audio continues)
- **When**: `MockDocumentOverlay` emits `Events.document_closed(&"plaza_doc_001")` (line still in flight)
- **Then**: `SubtitleCanvasLayer.visible == true`; `_label.visible == true`; `SubtitleLabel.text == "dlg.bqa.briefing.opening"` (caption restored)
- **Pass condition**: `MockDocumentOverlay` has ZERO method/property accesses on `DialogueAndSubtitles` or `SubtitleCanvasLayer` during the test (verified by not injecting D&S reference into mock)

**AC-4 — Signal emit ordering**
- **Given**: spy on `Events.dialogue_line_started`, spy on `AudioLinePlayer.play()`
- **When**: BQA briefing line fires
- **Then**: `dialogue_line_started` spy call timestamp precedes `play()` spy call timestamp (or same frame, ordered by GDScript execution sequence within the frame)
- **Pass condition**: Both spies called exactly once; order confirmed

**AC-7 — Visual evidence screenshot**
- **Setup**: Plaza section running in Godot editor; BQA briefing SCRIPTED trigger active; subtitles enabled; default scrim mode
- **Verify**: Screenshot captures subtitle visible bottom-center; no HUD overlap; Courier font; hard-edge rectangular scrim; no drop shadow or animation artifacts
- **Pass condition**: Screenshot filed at `production/qa/evidence/plaza-subtitle-intro-[date].png`; lead sign-off in evidence doc

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/feature/dialogue_subtitles/plaza_vs_smoke_test.gd` — must exist and pass (AC-1 through AC-6)
- `production/qa/evidence/plaza-subtitle-intro-[date].png` — visual screenshot (AC-7)
- `production/qa/evidence/subtitle-integration-evidence-[date].md` — lead sign-off including AC-7 visual checklist

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 DONE (full renderer must be configured for visual evidence and integration)
- Unlocks: Epic Definition of Done can be verified; `/story-done` can be run for all 5 stories
