# HUD State Signaling — Review Log

This log tracks `/design-review` history for `design/gdd/hud-state-signaling.md`. Future re-reviews append entries here.

---

## Review — 2026-04-28 — Verdict: MAJOR REVISION NEEDED → Revisions applied in same session
Scope signal: XL
Specialists: game-designer, systems-designer, ux-designer, accessibility-specialist, performance-analyst, godot-specialist, qa-lead, creative-director (synthesis)
Blocking items: 14 | Recommended: 25 | Nice-to-have: 3
Re-review status: First review (no prior log entry)

### Summary
First adversarial review of HUD State Signaling GDD (920 lines pre-revision). All 7 specialists found significant issues. Creative-director synthesis named a top-7 priority list with ALARM_STINGER as the cascade driver: its 5.0 s polite-only design simultaneously violated the Margin Note fantasy (game-designer), left HoH players blind during interact-collision (ux-designer), failed AT delivery latency for blind/deafblind users (accessibility-specialist), and had 11 µs over-cap perf budget (performance-analyst). User adjudicated 4 design forks (ALARM_STINGER carve-out, OQ-HSS-3 toggle promotion, WCAG 2.2.1/2.2.2 promotion, INTERACT_PROMPT collision priority) — all selected creative-director's recommended path. 27 of ~37 items applied in the same session across 8 batches (ALARM_STINGER cascade, queue+CR-9, Godot 4.6 API, F.4/CR-14 perf, OQ promotions, FP additions, AC additions, hygiene). ~10 minor RECOMMENDED items deferred for follow-up: SAVE_FAILED 4.0→2.0, RESPAWN_BEAT floor, F.3 docstring, ALERT_CUE AT-latency floor, BQA Blue hex, deafblind braille note, Steam Deck profile gate, SC 2.3.1 area calc, FP-HSS-2 Unicode range, test file naming, profile gate Wayland AC, comedy writer brief.

### Key design fork resolutions (user-adjudicated, recorded for cross-system precedent)

- **ALARM_STINGER carved out of "Margin Note" fantasy** as designated exception (mirrors Settings non-diegetic carve-out from Pillar 5). Duration 5.0→3.0 s; AccessKit assertive (only state with this); priority 1 above INTERACT_PROMPT for its 3.0 s window. CR-18 critical-health pulse is the second carve-out. The Margin Note governs 3 of 5 states (ALERT_CUE, MEMO_NOTIFICATION, RESPAWN_BEAT); the carve-out is narrow — only failure-state safety-of-information signals qualify.
- **OQ-HSS-3 ALERT_CUE Settings toggle promoted to BLOCKING Day-1** (default ON). Closes Pillar 5 §Visual Identity Anchor contradiction for hearing players: previously, hearing players received both alert music AND ALERT_CUE text, redundantly stamping the alert. Now hearing players can opt out. HoH compliance floor preserved.
- **WCAG 2.2.1/2.2.2 Level A promoted to BLOCKING**: OQ-HSS-6 (`accessibility.hud_state_timing_multiplier`) Day-1; OQ-HSS-10 (`accessibility.hud_critical_pulse_enabled`) VS. The premature "EU GAAD compliant" claim downgraded to "compliance posture pending Gate 1 + 2.2.1 + 2.2.2".
- **Queue arithmetic structurally fixed**: `queued_state_max_age_s` raised 1.0→5.0 to match longest auto-dismiss. Previously, ANY state queued behind ALARM_STINGER was guaranteed to discard (1.0 < 5.0); now SAVE_FAILED queued behind 3.0 s ALARM_STINGER survives the wait.
- **CR-9 upward-severity exemption**: SUSPICIOUS→COMBAT (etc.) bypasses cooldown so deaf players are not silently denied SC 1.1.1/1.3.3 information about state escalation.
- **Architectural ambiguity resolved**: HUD Core writes Label via callback return (matches §C.3 pseudocode); HSS provides text via `_resolve_hss_state()` callback. Eliminates dual-write race that the original CR-3/§C.3 had.

### Items applied (27)

ALARM_STINGER cascade: CR-16 duration + carve-out, CR-6 priority promotion, CR-8 assertive whitelist, §C.2 table, §F.1 default, §G.1 knob, §V.2 EN ref shortened, §B carve-out documentation. Queue: §C.3, §G.1, AC-HSS-3.6. CR-9: rule rewrite + AC-HSS-2.8. Godot 4.6: CR-18/V.4 Tween rewrite + assert→push_error in E.20 + unregister_resolver_extension in CR-4/CR-10/§F.5/AC-HSS-1.4 + CR-3 dual-write elimination. Perf: F.4 11 µs + pulse steady-state row + deferred-AccessKit default + §E.24 rare claim. Promotions: OQ-HSS-3/6/10. New FPs: 12/13/14/15. FP-HSS-7 regex defined. AC additions: 1.4, 1.5, 2.8, 2.9, 3.4, 3.5, 3.6, 3.7. AC reframings: 10.1 (n=8 + rejection-list), 10.3 (frame-precise + AT-before-preempt). Hygiene: section rename to "Detailed Rules" (template compliance), Dialogue & Subtitles refs updated to "Designed 2026-04-28; CanvasLayer 2 LOCKED" in 4 locations, AC count reconciled 28→38 with per-cluster Day-1 recount (19 Day-1 BLOCKING, 16 VS, 3 ADVISORY), CI skip mechanism via project flag, smoke check expanded with resolver coverage.

### Items deferred (10) — follow-up session

- SAVE_FAILED 4.0→2.0 reduction (game-designer #2)
- RESPAWN_BEAT safe-range floor 1.0→1.5 (systems-designer #1)
- F.3 re-engagement window docstring (systems-designer #6)
- ALERT_CUE safe-range floor [2.5, 3.5] for AT delivery latency (ux-designer #1)
- BQA Blue hex coordination item with art-director (accessibility-specialist #7)
- Deafblind braille path note in UI-3 (accessibility-specialist nice-to-have #10)
- Steam Deck OLED profile gate addition (performance-analyst nice-to-have #9)
- SC 2.3.1 worst-case area calculation (accessibility-specialist #4)
- FP-HSS-2 Unicode range upgrade (systems-designer #8)
- Test file naming `[system]_[feature]_test.gd` alignment (qa-lead #8)
- Profile gate Wayland+Orca explicit AC text (performance-analyst #6 — partially captured in CR-14 prose, not yet in AC-HSS-8.1 wording)
- Comedy writer brief constraint cross-link from MEMO_NOTIFICATION (game-designer #5)

### Specialist disagreement (resolved)

ALARM_STINGER prominence: game-designer wanted reduction to ≤3 s polite (defend Margin Note); ux-designer + accessibility-specialist wanted assertive AccessKit (HoH safety). Creative-director synthesis: reconcilable — carve out as Margin Note exception, get assertive AccessKit + priority promotion + ~3.0 s. Same pattern as Settings non-diegetic carve-out from Pillar 5. User adjudicated this path.

### Re-review recommendation

The ALARM_STINGER carve-out is a major architectural change that cascades into AT, AccessKit, queue timing, priority resolver, and pillar carve-out documentation simultaneously. A specialist re-review in a fresh session is recommended before claiming Approved status, to verify the cascade did not introduce new inconsistencies (especially around the deferred RECOMMENDED items). systems-index marks NEEDS REVISION pending re-review.
