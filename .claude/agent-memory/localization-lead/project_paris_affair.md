---
name: The Paris Affair — i18n project context
description: Game name, engine, language scope, key i18n architecture decisions, Settings and Menu System GDD loc review outcomes
type: project
---

Godot 4.6 stealth game. MVP ships English-only. Second locale (likely French) gates the Settings language dropdown graduation per CR-13.

**CRITICAL UNRESOLVED SCOPE CONFLICT (2026-04-27):** Menu System GDD preamble claims "FR + DE at VS via locale switcher." Localization Scaffold GDD consistently scopes all additional locales as "post-launch content-only delivery." These contradict each other. Producer must resolve before any FR/DE work enters sprint planning. Until resolved, treat second-locale scope as post-launch.

Settings & Accessibility GDD reviewed 2026-04-26. Key loc findings:

**Why:** Reviewed for Phase 2 readiness before a second locale ships.

**How to apply:** Any future Settings amendment must address the four BLOCKING items below before the 2nd-locale sprint begins.

BLOCKING loc gaps identified in Settings GDD:
1. `NOTIFICATION_TRANSLATION_CHANGED` does not re-push imperative `accessibility_name = tr("KEY")` assignments set in `_ready()`. Custom Controls and AccessKit semantic labels require per-Control listener or explicit refresh on locale change. GDD CR-12 implies auto-propagation handles all labels — it does not.
2. Photosensitivity warning modal has a fixed `min_size = (480, 240)` px with no documented translated-copy character ceiling. French/German translations of the 38-word locked copy will overflow at default font size.
3. Conflict-banner copy ("E is already bound to Fire") uses action display names with no tr-key mapping defined in this GDD or referenced Input GDD.
4. Resolution-scale OptionButton displays "50% / 60% / 75% / 100%" — no tr() wrapper or locale-aware percent formatter specified.

Advisory gaps in Settings GDD: formal/informal address policy not locked, category label tr-keys not enumerated, RTL layout not forward-planned, AC-SA-7.3 is ADVISORY (should be BLOCKING for VS).

Menu System GDD reviewed 2026-04-27. Key loc findings:

BLOCKING loc gaps identified in Menu System GDD:
1. Stamp PNG assets (V.8) are English-only pre-rendered images with no localization path defined. Affects: ui_stamp_dispatch_not_filed_normal.png, ui_stamp_close_file_normal.png, ui_stamp_auto_filed_normal.png, and CR-15 quicksave feedback stamps. Either per-locale image variants or explicit "intentional EN-only" Pillar 5 justification required.
2. `menu.new_game_confirm.body_alt` is 28 chars in English (already over the 25-char L212 cap), and OQ-MENU-17 (L212 cap scope: label-only vs all visible strings) is flagged ADVISORY rather than BLOCKING. Must be closed before MVP implementation.
3. Pseudolocale stress test is required in prose (§E Cluster G case 3, C.10 Dependencies) but has no corresponding AC in §H. No CI gate exists for the menu.* namespace.
4. "OPERATIONAL ADVISORY — BQA/65" header band in V.4 has no tr() key in §C.8 and no ownership attribution (Menu vs Settings).
5. menu.save.card_slot_zero "Autosave — {section}" in §C.8 conflicts with V.2 visual spec which shows "DISPATCH AUTO — [section_name] — [time_gmt]" — one of them is wrong.
6. Pseudolocale expansion factor is 200% in §E Cluster G case 5 but 140% in Localization Scaffold GDD — must align before CI is built.
7. F.2 fit predicate is Latin-script only; no CJK caveat documented.

Advisory gaps in Menu System GDD: French folder tab text treatment unspecified; silent modal re-translation on locale switch is undocumented AT limitation; Russian expansion budget not forward-planned; "GMT" in save card time template has no locale policy.
