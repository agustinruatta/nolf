# Sprint 06 — UI Shell (HUD + Settings + Localization)

**Dates**: 2026-05-02 to 2026-05-09 (7 calendar days; autonomous-execution sprint)
**Generated**: 2026-05-02
**Mode**: solo review (per `production/review-mode.txt`)
**Source roadmap**: `production/sprints/multi-sprint-roadmap-pre-art.md` Sprint 06 section (lines 56–71)

## Sprint Goal

**The screen reads as final on placeholder geometry.**

Sprint 04 made the level alive (perception → suspicion → patrol → reset).
Sprint 05 made the level durable (death → respawn → mission state preserved).
Sprint 06 makes the screen *speak the game*: a real HUD renders during the
Plaza VS demo (numeric health bottom-left, interact prompt center-lower,
pickup memo on document_collected); the alert cue from Sprint 04's stealth
state machine drives the HSS Day-1 minimal slice (HoH/deaf-friendly visual
indicator); the settings menu round-trips photosensitivity opt-out + master
volume + subtitle defaults through `ConfigFile`; and three remaining
Localization-Scaffold stories (plural forms + auto-translate + lint guards)
close the LIT/i18n surface needed before any final-look UI text ships.

By close, running the Plaza VS demo shows real HUD chrome, the alert cue
responds to Sprint-04 stealth-state transitions, and the settings menu's
photosensitivity toggle survives a process restart. **No story in this sprint
ships final art** — Theme uses placeholder Futura/DIN substitutes; HUD
opacity uses the GDD §7E provisional 85% pending Restaurant + Bomb Chamber
contrast verification (deferred to post-art sprint).

This sprint brings us closer to the **art-integration-ready milestone** (end
of Sprint 08): every code-ready system implemented and proven on placeholder
geometry. After Sprint 06, two systems remain (Audio body + Document logic +
Level Streaming hardening) before the project waits on art alone.

## Capacity

- Total agent-time: ~4 days work-equivalent
- Buffer (20%): 1 day reserved for HUD opacity visual sign-off escalation,
  ADR-0004 closure status surfacing, settings-cluster validation regressions,
  HSS↔HUD-Core handshake friction
- Available: 3 days for committed work
- Total committed estimate: **~32–46 hours of agent work** (17 stories,
  mix of Logic + UI + Integration; lower count than the roadmap's 18
  because LOC-001 already DONE 2026-05-01 and LOC-002 already DONE in
  Sprint 02 carry-in)

## Roadmap Reconciliation

The multi-sprint roadmap §Sprint 06 (lines 56–71) lists "Localization-scaffold
remaining ready: LOC-001, 003, 004, 005 (4 stories)". This is stale —
**LOC-001 was closed** 2026-05-01 (Sprint 02 Should-Have push); **LOC-002 was
closed** in Sprint 02 carry-in. The **actual remaining Localization stories**
at Sprint 06 start are:

- **LOC-003** — Plural forms (CSV plural columns) + named-placeholder discipline
- **LOC-004** — `auto_translate_mode` + NOTIFICATION_TRANSLATION_CHANGED re-resolution discipline
- **LOC-005** — Anti-pattern fences + lint guards + `/localize` audit hook

= **3 Localization stories**, not 4.

Sprint 06 also defers SA-005 (Settings panel UI shell — `Status: BLOCKED`)
because ADR-0004 Gate 1 (AccessKit property names on custom Controls) +
Gate 5 (BBCode → AccessKit plain-text serialization) are still OPEN. Per
roadmap line 68: "ADR-0004 closure required for Document-Overlay-UI,
Menu-System, and the **6th Settings story**. This roadmap explicitly defers
those 9 stories to a later sprint." SA-005 is the 6th Settings story.

Total Sprint 06 story count therefore lands at **17**, not the roadmap's 18
(the 1-story shortfall is purely "already done" — no scope reduction). The
SA-005 deferral is roadmap-specified, not new scope removal.

> **Note**: This is the *opposite* of scope creep — the sprint is delivering
> the same epic outcomes with 1 fewer story because earlier sprints overshot
> on the Localization front. Document for `/scope-check` at sprint close: 0
> additions, 1 subtraction (already-DONE: LOC-001).

## Tasks

### Must Have — Localization tail (3)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| LOC-003 | Plural forms (CSV plural columns) + named-placeholder discipline | godot-gdscript-specialist | 2-3h | Logic | LOC-001 ✅, LOC-002 ✅ | `tr_n()` calls work for `count` placeholder; CSV plural columns recognized; named placeholders only (no positional `{0}`); unit test sweeps en/fr/ja singular/plural variants |
| LOC-004 | `auto_translate_mode` + NOTIFICATION_TRANSLATION_CHANGED re-resolution discipline | godot-gdscript-specialist | 2-3h | Logic | LOC-001 ✅, LOC-003 | Control `auto_translate_mode` property set per ADR-0004 Implementation Guideline; runtime locale switch fires `NOTIFICATION_TRANSLATION_CHANGED`; widgets that cache `tr()` at `_ready` re-resolve; unit test exercises locale switch + cache invalidation |
| LOC-005 | Anti-pattern fences + lint guards + `/localize` audit hook | godot-gdscript-specialist | 1-2h | Logic | LOC-003, LOC-004 | CI shell scripts + 1 unit test; `hardcoded_user_facing_string` / `positional_placeholder` / `tr_cached_at_ready_no_notification` patterns blocked; tr-registry entries; `/localize audit` skill hook produces report; grep-tested |

### Must Have — Settings & Accessibility (5; SA-005 deferred per roadmap)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| SA-001 | SettingsService autoload scaffold + ConfigFile persistence layer | godot-gdscript-specialist | 3-4h | Logic | ADR-0007 ✅, ADR-0002 ✅, ADR-0003 ✅ | SettingsService autoload registered at slot 10 per ADR-0007; ConfigFile read/write to `user://settings.cfg`; categories: audio/graphics/accessibility/controls/language; `get_value()`/`set_value()` typed accessors; `setting_changed(key, value)` signal; unit tests cover load/save round-trip |
| SA-002 | Boot lifecycle — burst emit, settings_loaded signal, photosensitivity warning flag | godot-gdscript-specialist | 2-3h | Logic | SA-001 | `_ready()` reads ConfigFile, fires synchronous burst of `setting_changed` per key, then emits `settings_loaded`; `photosensitivity_warning_dismissed` absence on first launch = needs warning; consumers at slot ≥10 receive burst synchronously; unit test asserts burst order + slot ordering compliance |
| SA-003 | Photosensitivity kill-switch + PostProcessStack glow handshake | godot-gdscript-specialist | 2-3h | Logic | SA-001, SA-002, PPS-001 ✅ | `accessibility.photosensitivity_reduce` toggle: PostProcessStack subscribes to `setting_changed`; glow shader bypassed when true; HUD shutters muted when true; unit test mocks PPS subscriber + asserts glow-disable on toggle change |
| SA-004 | Audio volume sliders — dB formula + bus apply integration | godot-gdscript-specialist | 2-3h | Logic | SA-001, SA-002, AUD-001 ✅ | Master/SFX/Music/Voice/UI sliders [0.0–1.0] map to dB via `linear_to_db()`; AudioServer bus volumes updated on `setting_changed`; per-category sliders persist via ConfigFile; unit test asserts dB formula + bus index mapping |
| SA-006 | Subtitle defaults write + subtitle settings persistence | godot-gdscript-specialist | 2-3h | Logic | SA-001, SA-002 | Subtitle cluster: `subtitles_enabled=true` (WCAG SC 1.2.2 captions-default-on); `subtitle_size_scale ∈ {0.8,1.0,1.5,2.0}`; `subtitle_background ∈ {none,scrim,opaque}`; `subtitle_line_spacing_scale ∈ [1.0,1.5]`; `subtitle_letter_spacing_em ∈ [0.0,0.12]` (WCAG SC 1.4.12); cluster validation + Cluster B self-heal; unit test sweeps clamp + enum + bool fields |

### Must Have — HUD Core (6)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| HC-001 | CanvasLayer scene root scaffold + Theme resource + FontRegistry wiring | godot-gdscript-specialist + godot-shader-specialist | 3-4h | UI | ADR-0004 ⏸️ Effectively-Accepted (G3/G4/G5 deferred), LOC-001 ✅ | `HUDCore.tscn` with `CanvasLayer` root; placeholder Theme resource (Futura → DIN size-floor substitution); FontRegistry static class with typed getters; period-authentic typographic restraint per Pillar 5; manual evidence doc `production/qa/evidence/hud-core-canvas-2026-05-XX.md` |
| HC-002 | Signal subscription lifecycle + forbidden-pattern fences | godot-gdscript-specialist | 2-3h | Logic | HC-001 | `_ready()` connects 8 frozen Events signals (PC + Combat + Inventory domains); `_exit_tree()` disconnects all; `register_resolver_extension` / `unregister_resolver_extension` public API for HSS handshake; `hud_subscribing_to_internal_state` + `hud_pushing_visibility_to_other_ui` patterns blocked; unit test asserts connect/disconnect symmetry + register API |
| HC-003 | Health widget logic (damage flash, critical-state edge trigger, Tween.kill on context-leave) | godot-gdscript-specialist | 3-4h | Logic | HC-001, HC-002 | `health_widget.gd` subscribes to `player_health_changed` + `player_damaged` + `player_died`; numeric label updates on change; damage flash Tween fires once per `player_damaged` (CR-7 idempotency); critical-state edge trigger fires on HP threshold cross only; `Tween.kill()` on context-leave (CR-22); unit test covers all 4 transitions |
| HC-004 | Interact prompt strip — PC query resolver, _process state machine, get_prompt_label() extension hook | godot-gdscript-specialist | 3-4h | Logic | HC-001, HC-002, PC-005 ✅ | Prompt strip subscribes to PC `get_current_interact_target()` per-frame query; state machine: HIDDEN → SHOWN → HIDDEN; `get_prompt_label(target)` extension hook callable by HSS resolver chain; key-glyph mirror placeholder (CR-21 — Input GDD pending); null-PC error gate (CR-3); unit test covers state-machine + extension hook |
| HC-005 | Settings live-update wiring, pickup memo subscription, context-hide full implementation | godot-gdscript-specialist | 2-3h | Logic | HC-001, HC-002, SA-001, SA-002, HSS-001 | Subscribes to `setting_changed` for `hud_alert_cue_enabled` + `subtitles_enabled`; pickup memo subscriber connects to `document_collected` (delegated to HSS-003 for the toast itself); `set_process(false)` opt-out when HUD context hidden (TR-HUD-010); unit test covers settings live-update + memo subscription + context-hide |
| HC-006 | Plaza VS integration smoke — end-to-end visual sign-off + Slot 7 0.3 ms perf measurement | godot-gdscript-specialist | 3-4h | UI/Integration | HC-001..005, HSS-001..003, SA-001..006 (all of Sprint 06) | Plaza VS demo runs HUDCore scene; health widget shows 100, prompt strip shows "Press E to read" near document, pickup memo briefly displays on collect; Slot 7 frame-budget measured ≤0.3 ms via perf instrumentation; manual evidence doc `production/qa/evidence/hud-core-plaza-vs-2026-05-XX.md`; **may surface visual sign-off stop condition** (HUD opacity 85% per art bible §7E — Restaurant + Bomb Chamber contrast unverified) |

### Must Have — HUD State Signaling (3)

| ID | Task | Owner | Est. | Type | Dependencies | Acceptance Criteria (summary) |
|----|------|-------|------|------|-------------|------------------------------|
| HSS-001 | HUD State Signaling — structural scaffold + HUD Core handshake | godot-gdscript-specialist | 2-3h | Integration | HC-001, HC-002 (register_resolver_extension API) | HSS scene attached as child of HUDCore; calls `HUDCore.register_resolver_extension(self)` at `_ready`; `unregister_resolver_extension` at `_exit_tree`; resolver-chain order asserted; unit test exercises register/unregister symmetry + handshake order |
| HSS-002 | ALERT_CUE — Day-1 HoH/deaf minimal slice | godot-gdscript-specialist | 2-3h | Logic | HSS-001, SA-001 (`hud_alert_cue_enabled` toggle) | Subscribes to Stealth-AI `alert_state_changed` (Sprint-04 signal); shows visual chevron on alert state ≥ INVESTIGATING; chevron color/size driven by alert tier; `hud_alert_cue_enabled` Settings toggle gates render; default-true; unit test covers alert-tier → chevron mapping + settings gate |
| HSS-003 | MEMO_NOTIFICATION — document pickup toast (VS scope) | godot-gdscript-specialist | 2-3h | Logic | HSS-001, HC-002 (`document_collected` subscriber) | Subscribes to `document_collected` synchronously (no CONNECT_DEFERRED — FP-HSS-15); transient toast renders with title from collected document; toast auto-dismisses after T_DISMISS_MS (per GDD); unit test covers subscribe/dismiss timing + signal-purity |

### Should Have

*(Empty — buffer reserved for HUD opacity visual sign-off escalation, ADR-0004 closure status surfacing, settings-cluster validation regressions, HSS↔HUD-Core handshake friction. If Must-Have closes early, pull the next Sprint 07 candidate forward — recommended: AUD-003 alert-tier music ducking.)*

### Nice to Have

*(Empty — keep buffer.)*

## Carryover from Sprint 05

*Implementation-side: none — Sprint 05 closed all 14 Must-Have stories.*

**User-side carryover (informational, not Sprint 06 blockers):**
- Filesystem permissions on `tests/integration/level_streaming/level_streaming_swap_test.gd` + `tests/unit/core/player_character/player_interact_cap_warning_test.gd` (vdx-owned; flaky in full-suite runs)
- Plaza scene authoring (`scenes/sections/plaza.tscn` is vdx-owned, group-read-only) — unblocks HC-006 manual playtest evidence + MLS-003 CI validator
- ADR-0004 Gate 5 BBCode→AccessKit AT runner — closes inside Settings & Accessibility production story (deferred until ADR-0004 advances)
- ADR-0005 G3/G4/G5 — closes inside PC FPS-hands rendering production story
- ADR-0008 G1/G2/G4 — closes when Restaurant + Iris Xe Gen 12 hardware acquired
- LOAD_FROM_SAVE menu UI (out of VS scope; gates MLS AC-MLS-11.1/11.2/11.3)
- `fr_autosaving_on_respawn` registry entry (added 2026-05-02 — verify on next architecture-review cycle)

These do not gate Sprint 06 work. They gate Sprint 06 → Sprint 07+ stage
advancement only at the user's discretion.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| **HUD opacity visual sign-off** (85% per art bible §7E open question — Restaurant + Bomb Chamber contrast unverified) | MED | **HARD STOP CONDITION per task brief.** | Per roadmap stop condition #2: surface to user when HC-006 (or any HUD widget render story) reaches the opacity decision point. Plaza VS contrast is acceptable per current art-bible read; Restaurant/Bomb Chamber contrast is unverified — defer those scenes to post-art sprint. |
| **ADR-0004 closure status** (G1 + G5 OPEN; SA-005 + Document-Overlay + Menu-System blocked) | LOW | Surface required at sprint close per roadmap stop condition | Sprint 06 includes 5 of 6 Settings stories (SA-005 deferred) + 0 Document-Overlay + 0 Menu-System stories. ADR-0004 Effectively-Accepted state per `/architecture-review` 9th run lets Sprint 06's stories proceed under documented deferral pattern. SA-005 stays deferred. |
| **Settings cluster validation surfaces a forbidden-pattern violation** (SA-006 subtitle cluster has 6 fields with WCAG-driven ranges) | MED | Could blow SA-006 estimate by 50%; may force per-field self-heal logic | Cluster B self-heal pattern documented in story spec; defensive defaults via SettingsDefaults; if a clamp range surfaces an ADR-0003 conflict, surface to user before relaxing the range. |
| **HSS↔HUD-Core handshake** — register_resolver_extension API surface drift between HC-002 and HSS-001 | LOW-MED | HSS-001 cannot land if HC-002's API contract changes mid-sprint | Land HC-001 + HC-002 BEFORE HSS-001 per Implementation Order Phase B; lock the API surface in HC-002's unit test before HSS-001 begins. |
| **Settings ↔ HSS Day-1** — HSS-002 needs `hud_alert_cue_enabled` Settings toggle (cross-epic dep noted in active.md OQ-2) | LOW | HSS-002 falls back to default-true if SA-001 toggle absent | SA-001 lands first per Implementation Order Phase A; HSS-002's settings-gate test validates toggle present + default-true. |
| **Tech-debt register grows past 12 items** | LOW | **HARD STOP CONDITION per task brief.** | Currently 7 items (TD-001..TD-007); 5-item buffer. Triage if new debt exceeds it. LOC-005 + HC-002 + HSS forbidden-pattern fences add registry entries, NOT debt. |
| **17-story marathon causes context exhaustion** | MED | Mid-sprint context drop | Pattern from Sprint 02/03/04/05 marathons: write to `active.md` after each story; rely on file-backed state per `.claude/docs/context-management.md`. |
| **Plaza scene permission constraint blocks HC-006 manual evidence** | MED | HC-006 manual evidence deferred (not blocking) | Same vdx-ownership pattern surfaced in Sprint 05; HC-006's automated parts (Slot 7 perf measurement, signal-wiring tests) ship; manual playtest evidence deferred to permission resolution. |

## Dependencies on External Factors

- **None.** All ADRs the sprint depends on are at terminal-or-deferred-only state:
  - ADR-0002 Accepted, ADR-0003 Accepted, ADR-0007 Accepted, ADR-0008 Accepted (with deferred numerical verification)
  - ADR-0004 **Effectively-Accepted** (Gate 5 deferred to runtime AT runner; LOC stories proceed under documented authorization)
- All upstream stories Complete: LOC-001/002, PPS-001 (PostProcessStack scaffold), AUD-001 (AudioManager), PC-005 (interact raycast).
- **No art assets required.** Theme resource uses placeholder Futura/DIN per Pillar 5 typographic restraint; final-look HUD opacity defers to post-art sprint.

## Stop Conditions (per task brief, MUST stop and surface to user)

1. **ADR ambiguity or amendment required** — especially ADR-0004 Gate 1/Gate 5 closure attempt; if SA-005 unblocks mid-sprint, surface BEFORE pulling it in
2. **Scope drift** — `/scope-check` flags creep beyond the 17 listed story IDs (LOC-003/004/005, SA-001/002/003/004/006, HC-001..006, HSS-001/002/003)
3. **Visual sign-off needed** — HUD opacity (85% per art bible §7E) surfacing in HC-001 / HC-006 requires user confirmation before merging the Theme/opacity choice
4. **Art asset surfaces as a hard blocker** — should not happen this sprint; Theme uses placeholder Futura/DIN
5. **Test failure or regression** — smoke check fails or suite regresses; do NOT patch by skipping tests
6. **Cross-sprint dependency emerges** — if a Sprint 06 decision invalidates Sprint 07+ plan
7. **Tech-debt register grows beyond 12 items** — currently 7; pause at 13 for triage
8. **Manifest-version bump decision for save format** — should not happen (no SaveGame schema changes in scope), but surface immediately if it does

## Definition of Done for Sprint 06

- [ ] All 17 Must-Have stories closed via `/story-done`
- [ ] Test suite ≥ 863 + Sprint-06 additions, zero net regressions (Sprint 05 closed at 863 with 7 known-flaky pre-existing tests)
- [ ] All Logic stories have passing unit tests in `tests/unit/foundation/localization/`, `tests/unit/foundation/settings/`, `tests/unit/presentation/hud_core/`, `tests/unit/presentation/hud_state_signaling/`
- [ ] All UI stories have manual evidence docs in `production/qa/evidence/`
- [ ] All Integration stories have integration tests + or playtest evidence
- [ ] HUDCore CanvasLayer scene exists + renders during Plaza VS gameplay (HC-001 + HC-006)
- [ ] Health widget shows 100 in Plaza VS smoke (HC-003 + HC-006 manual evidence)
- [ ] Interact prompt strip shows "Press E to read" near a document (HC-004 + HC-006)
- [ ] Pickup memo briefly displays on `document_collected` (HSS-003 + HC-005)
- [ ] Alert cue chevron responds to Sprint-04 stealth state (HSS-002)
- [ ] Settings menu round-trips photosensitivity opt-out + master volume + subtitle defaults (SA-001 + SA-003 + SA-004 + SA-006)
- [ ] LOC `tr_n()` plurals work for en/fr/ja sweep (LOC-003)
- [ ] Locale switch fires re-resolution on `auto_translate_mode = ALWAYS` widgets (LOC-004)
- [ ] Forbidden patterns registered: `hardcoded_user_facing_string`, `positional_placeholder`, `tr_cached_at_ready_no_notification` (LOC); `hud_subscribing_to_internal_state`, `hud_pushing_visibility_to_other_ui` (HUD); `hss_emitting_outside_signaling_domain` (HSS)
- [ ] Slot 7 frame budget verified ≤0.3 ms via HC-006 perf measurement
- [ ] QA plan exists (`production/qa/qa-plan-sprint-06-2026-05-02.md`)
- [ ] Smoke check passes (`production/qa/smoke-2026-05-XX-sprint-06.md`)
- [ ] `/scope-check sprint-06-ui-shell` clean — no IDs added beyond the 17 listed
- [ ] `production/sprint-status.yaml` updated by `/story-done` invocations
- [ ] `production/session-state/active.md` close-out section appended
- [ ] **ADR-0004 closure status surfaced to user** at sprint close (per roadmap stop condition #5)

## QA Plan Status

**Not yet written.** Run `/qa-plan sprint` immediately after this plan is written, before any `/dev-story` invocation.

## Implementation Order (intra-epic + cross-epic dependency-respecting)

**Phase A — Localization tail + Settings foundation** (independent of HUD/HSS; can land in parallel):
1. LOC-003 (plural forms)
2. LOC-004 (auto_translate_mode + NOTIFICATION_TRANSLATION_CHANGED)
3. LOC-005 (LOC anti-pattern fences)
4. SA-001 (SettingsService scaffold) — unblocks SA-002..006 + HSS-002 + HC-005
5. SA-002 (boot lifecycle + settings_loaded)
6. SA-003 (photosensitivity kill-switch)
7. SA-004 (audio volume sliders)
8. SA-006 (subtitle defaults persistence)

**Phase B — HUD Core scaffold + handshake API** (HC-001/002 must land before HSS-001):
9. HC-001 (CanvasLayer scaffold + Theme + FontRegistry)
10. HC-002 (signal subscription lifecycle + register_resolver_extension API + forbidden-pattern fences)

**Phase C — HUD widgets + HSS scaffold** (parallel-safe after Phase B):
11. HC-003 (health widget)
12. HC-004 (interact prompt strip + get_prompt_label hook)
13. HSS-001 (HSS scaffold + HUD Core handshake)

**Phase D — Settings-driven HUD + HSS Day-1 widgets** (needs SA + HSS scaffolds):
14. HC-005 (settings wiring + pickup memo + context-hide)
15. HSS-002 (alert-cue Day-1 minimal slice)
16. HSS-003 (memo notification toast)

**Phase E — Integration + Plaza smoke** (closes the loop):
17. HC-006 (Plaza VS integration smoke + Slot 7 perf measurement)

> **Cross-epic note**: HC-002's `register_resolver_extension` API surface is
> the handshake contract HSS-001 consumes. Land HC-001/002 first, then HSS-001
> can land at any time after; HSS-002/003 follow HSS-001. HC-005 needs both
> SA-001 (settings) and HSS-001 (memo delegate). HC-006 is the integration
> centerpiece — implement after every other story.

## Reference Documents

- `production/sprints/multi-sprint-roadmap-pre-art.md` — Sprint 06 source
- `production/sprints/sprint-05-mission-loop-and-persistence.md` — predecessor (closed 2026-05-02)
- `production/qa/qa-signoff-sprint-05-2026-05-02.md` — Sprint 05 QA sign-off (APPROVED WITH CONDITIONS)
- `production/epics/hud-core/EPIC.md` — epic governance
- `production/epics/hud-state-signaling/EPIC.md` — epic governance
- `production/epics/settings-accessibility/EPIC.md` — epic governance
- `production/epics/localization-scaffold/EPIC.md` — epic governance
- `design/gdd/hud-core.md` — HUD Core GDD
- `design/gdd/hud-state-signaling.md` — HSS GDD
- `design/gdd/settings-and-accessibility.md` — Settings GDD
- `design/gdd/localization-scaffold.md` — Localization GDD
- `docs/architecture/adr-0002-signal-bus-event-taxonomy.md` — UI domain signal ownership
- `docs/architecture/adr-0003-save-format-contract.md` — ConfigFile persistence contract
- `docs/architecture/adr-0004-ui-framework.md` — Theme + InputContext + FontRegistry contracts (Effectively-Accepted; G3/G4/G5 deferred)
- `docs/architecture/adr-0007-autoload-load-order-registry.md` — SettingsService at slot 10
- `docs/architecture/adr-0008-performance-budget-distribution.md` — Slot 7 = 0.3 ms HUD cap
- `docs/tech-debt-register.md` — TD-001..TD-007 register

> **Scope check note**: This sprint adds zero stories beyond the roadmap's
> commitment AND removes 1 story (already-DONE: LOC-001 explicitly + LOC-002
> implicitly). Run `/scope-check sprint-06-ui-shell` at sprint close to
> confirm no creep occurred during execution.

> **Scope check**: If this sprint includes stories added beyond the original epic scope, run `/scope-check [epic]` to detect scope creep before implementation begins.
