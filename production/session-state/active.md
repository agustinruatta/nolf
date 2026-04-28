# Session State

**Last updated:** 2026-04-27 evening (`/design-system document-overlay-ui` **COMPLETE 2026-04-27 evening** — solo mode, system #20 UI/Presentation, pure VS scope. **All 11 sections written incrementally with user approval — 1,160 lines, 11 ## headers + 85 sub-sections**. Phase 5 validation done: registry sweep applied (4 referenced_by + 6 NEW entries — DocumentCollection / Document / HUDCore / SettingsService all += document-overlay-ui.md; DocumentOverlayUI cross_system_class + document_overlay_canvas_layer=5 LOCKED + overlay_card_width_px=960 + overlay_card_height_px=680 + overlay_scroll_bar_width_px=4 + document_body_word_count_ceiling=250 words English Writer-owned); systems-index row 20 updated to "Designed 2026-04-27 evening" with full design notes; Progress Tracker (Started 18→19, VS designed 3→4/7); Last Updated header refreshed. CD-GDD-ALIGN gate at Phase 5a-bis SKIPPED per solo mode. **Pillar fit**: 2 + 3 Primary load-bearing; 1 + 5 Supporting. **Player Fantasy "The Lectern Pause"** (CD Candidate 1; posture / attention is the verb; sepia-dim suspended parenthesis; 5 explicit refusals; tonal anchor "Does this respect the Lectern Pause?"). **15 Core Rules** + Modal Scene Structure (CanvasLayer 5 → ModalBackdrop → CenterContainer → DocumentCard 960×680 px → VBox: Header 64 px BQA Blue + Body Parchment ScrollContainer + RichTextLabel + Footer 30 px DismissHintLabel "ESC / B — Return to Operation") + 4-state machine IDLE/OPENING/READING/CLOSING + C.4 8-step open lifecycle + C.5 6-step close lifecycle (Input CR-7 silent-swallow prevention) + Scroll Grammar + NOTIFICATION_TRANSLATION_CHANGED re-resolve + AccessKit per-widget table + 16 Forbidden Patterns FP-OV-1..FP-OV-16 + Interactions Matrix vs 14 systems + Bidirectional Consistency Check vs 16 upstream GDDs/ADRs. **§D Formulas (4)**: F.1 open-frame budget T_open ≤ 5 ms one-time spike; F.2 steady-state ≤ 0.3 ms Slot 7 cap (no _process); F.3 close-frame ≤ 1 ms; F.4 card_width clamp(960, 800, viewport_width). **§E 33 Edge Cases / 8 clusters**. **§H 36 ACs / 14 clusters** + 5 GAPs identified for Polish. **Specialists consulted (all section-mandatory)**: creative-director (§B), game-designer (§C), ux-designer (§C), godot-specialist (§C + 6 verification gates), systems-designer (§D + §E), qa-lead (§H). **4 user-adjudicated decisions**: Q1 Option A pickup auto-opens NOLF1 model; Q2 Include 30 px footer hint; Q3 Thin 4 px Ink Black auto-hide scroll bar; Q4 Option B card hides synchronously on dismiss. **CLOSES DC §F.5 item #6 forward-dep contract**. **11 BLOCKING coord items** (OQ-DOV-COORD-1..11): DC adopts auto-open / PPS reduced-motion API / MLS section_unloading signal / Writer word-count ceiling / Localization 3 keys / ADR-0004 §IG3 doc fix / DC sync close emit / OPENING-state teardown branch / CI lint single-instance / CI script authoring / ADR-0004 promotion. **1 ADVISORY**: OQ-DOV-COORD-7 scroll-bar StyleBoxFlat. **6 verification gates** (4 BLOCKING + 2 ADVISORY): Gate A accessibility_* / Gate B base_theme / Gate C ui_cancel dismiss / Gate D auto_translate_mode / Gate E RichTextLabel locale-change / Gate F ScrollContainer scroll routing. Files modified: design/gdd/document-overlay-ui.md (NEW 1,160 lines) / design/registry/entities.yaml (4 referenced_by + 6 NEW entries + last_updated header) / design/gdd/systems-index.md (row 20 + Progress Tracker + Last Updated header) / production/session-state/active.md (this file). **Next recommended**: `/design-review design/gdd/document-overlay-ui.md` in fresh session; `/consistency-check` post-Overlay sweep; resolve 11 BLOCKING coord items before VS sprint planning. Original IN PROGRESS thread preserved: (`/design-system document-overlay-ui` IN PROGRESS — solo mode, system #20 UI/Presentation, pure VS tier (no MVP slice — DC's MVP ships pickup-only). Phase 2 context summary done (4 hard upstream deps DC ✅ APPROVED + PPS ✅ Designed + Input ✅ Approved-pending-coord + Localization ✅ Designed + ADR-0001/2/3/4/7/8). Phase 3 skeleton written 2026-04-27 to `design/gdd/document-overlay-ui.md`. Locked context: **CanvasLayer 5 LOCKED** per ADR-0004 IG7 + modal_scaffold registry; **InputContext.DOCUMENT_OVERLAY** push/pop on open/close; **modal dismiss = `_unhandled_input()` + `ui_cancel`** (NEVER focused button); **Esc consume order**: `set_input_as_handled()` BEFORE `InputContext.pop()` per Input AC-7.1; **PostProcessStack.enable_sepia_dim()/disable_sepia_dim()** lifecycle calls (0.5s ease_in_out fade); **DC sole publisher** of `document_opened`/`document_closed` (CR-7); Overlay calls `DC.open_document(id)`/`DC.close_document()` per DC CR-11; **single-document-open invariant** (DC CR-12); **`tr()` at render time, NEVER `_ready()`** (Localization CR-9 + DC CR-8); **`NOTIFICATION_TRANSLATION_CHANGED` re-resolve** for live locale; **NOT autoload** per ADR-0007; **ADR-0008 Slot 7 = 0.3 ms shared UI cap**; **mouse mode push VISIBLE on open / restore on close** per Input CR-8; **Audio document_overlay_music_db=-10dB / _ambient_db=-20dB** owned by Audio; **Subtitles auto-suppressed** per ADR-0004 IG5 (Subtitle subscribes itself); **sepia dim does NOT affect overlay card** (CanvasLayer 5 above sepia at 4); **RichTextLabel for body** (American Typewriter Regular via FontRegistry.document_body()); **Label for header** (American Typewriter Bold via FontRegistry.document_header()); **document_overlay_theme.tres inherits project_theme.tres**. Inherited Pre-Impl Gates: ADR-0004 Proposed→Accepted (Gates 1+2+3) + ADR-0004 LOADING amendment. **Next**: §A Overview framing widget (Framing/ADR-ref/Fantasy tabs) → draft → write. Earlier 2026-04-27 entry preserved below.

---

## Earlier 2026-04-27 — `/design-system document-collection` COMPLETE

**Last updated:** 2026-04-27 (`/design-system document-collection` **COMPLETE 2026-04-27** — solo mode, system #17 Narrative-layer VS-tier with single GDD per-section MVP/VS phasing. **All 11 sections written incrementally with user approval**. **1,218 lines, 11 ## headers**. Phase 5 validation done: registry sweep applied (2 referenced_by updates: player_interact_ray_length += document-collection.md / off_path_min_distance_m += document-collection.md + notes expanded with F.2 qualification + critical_path_spline lint #8 requirement; 8 NEW entries: DocumentCollection cross_system_class Node Section/Systems/DocumentCollection NOT autoload + DocumentBody cross_system_entity StaticBody3D LAYER_INTERACTABLES exclusive interact_priority=0 stencil Tier 1 height [0.4, 1.5] m + Document cross_system_resource 7-field schema id/title_key/body_key/section_id/interact_label_key/tier_override/type + DocumentCollectionState cross_system_resource frozen ADR-0003 collected: Array[StringName] + section_documents group_tag + dc_total_document_count=21 safe [15, 25] + dc_off_path_ratio_min=0.75 safe [0.65, 1.0] Pillar 2 absolute floor + dc_pickup_event_budget_ms=0.05 ADR-0008 sub-slot peak event-frame); systems-index row 17 updated to "Designed 2026-04-27" with full design notes; Progress Tracker (Started 17→18, VS designed 2→3/7); Last Updated header refreshed. CD-GDD-ALIGN gate at Phase 5a-bis SKIPPED per solo mode. **5 BLOCKING MVP coord items emerging** (OQ-DC-1 ADR-0008 amendment 0.05 ms sub-slot / OQ-DC-2 MLS GDD §C.5 amendment Plaza documents/ group + 8 CI lints / OQ-DC-3 Localization Scaffold authoring guideline BQA-never-expanded + ui.interact.pocket_document + ui.interact.read_document keys / OQ-DC-4 Section-validation CI 9 lint rules implementation Tools-Programmer / OQ-DC-5 Audio gameplay_session_ended signal contract NEW from §A.4). **3 BLOCKING VS coord items** (OQ-DC-6 MLS §C.5 VS expansion 21-doc roster + OQ-DC-7 Document Overlay UI #20 GDD adopts DC.open_document/close_document API + NOTIFICATION_TRANSLATION_CHANGED + PostProcessStack lifecycle / OQ-DC-8 HSS #19 GDD subscribes document_collected for pickup toast). **5 ADVISORY** (4 engine VGs VG-DC-1..4 + N_subscribers ≥6 ADR-0008 review trigger per E.32). Specialists consulted (all section-mandatory): creative-director (§B Candidate 2 "Reading the Room"), narrative-director (§C 7 categories + 6 tonal rules + 7 forbidden content + per-section arc + BQA never-expanded), game-designer (§C 18 CRs + Option C opened/closed emit-site + MVP pickup-only scope + 10 forbidden patterns), gameplay-programmer (§C Godot 4.6 feasibility 4 VGs + ADR-0008 0.05 ms claim), level-designer (§C per-section distribution + furniture-binding + interact-distance + priority-stack + 6 lints + Plaza tutorial), systems-designer (§D 3 formulas + §E 5 edge cases), art-director (§V 7 mesh categories + 50-120 tris + per-section palette + V.6 snap-clear + 7 forbidden visuals), audio-director (§A 3 cue specs + 3-cluster scheme + no room-tone-bed + 6 forbidden audio + zero DC knobs), qa-lead (§H 38 ACs across 12 clusters + 2 GAP notes). 4 user-adjudicated decisions: Q1 BQA never-expanded; Q2 21-doc distribution Plaza 3/Lower 4/Restaurant 6/Upper 5/Bomb 3; Q3 Plaza tutorial 1 on-path + 2 off-path; Q4 9 architecture choices locked. Sections beyond §C/§D: **§E Edge Cases ✅** (35 cases / 8 clusters: A same-frame storms 6 / B save-load 7 / C section-load authoring 5 / D locale + tr() 3 / E open-close VS lifecycle 4 / F DC subscriber lifecycle 2 / G authoring + engine VGs 5 / H pillar enforcement 3; 2 NEW lint rules emerged for §C.5.6 #7 DocumentCollection presence + #8 critical_path_spline presence). **§F Dependencies ✅** (6 sub-sections: 11 hard upstream + 4 soft + 6 forward dependents + 9 forbidden non-deps + 7 BLOCKING + 5 ADVISORY coord items consolidated + 38-row bidirectional consistency check). **§G Tuning Knobs ✅** (5 sub-sections: 8 DC-owned + 7 inherited + 7 ADR-locked + 9 Pillar absolutes + ownership matrix). **§H Acceptance Criteria ✅** (38 ACs / 12 clusters + GAP cluster). **§Visual/Audio ✅** (V.1-V.7 7-category mesh register flat plane / stacked planes / clipboard / closed book / cylinder telex / folded blueprint / envelope at 50-120 tris + per-section paper palette Plaza warm parchment #F5EFD6 / Lower industrial off-white #E8E0CC / Restaurant white linen #FAFAF5 / Upper comms-green tint #DDE8D8 / Bomb sterile white #F5F5F5 with Ink Black #1A1A1A 4 px Tier 1 outline + 6 exterior tells + NOLF1 fidelity + V.6 snap-clear NO animation policy + 8 forbidden visual patterns FP-V-DC-1..8; A.1 3 cue specs validated + A.2 3-cluster scheme A single-sheet / B bound-multi-page / C carbon-rigid telex with 2 variants each = 18 cluster-variant assets + A.3 no room-tone-bed during overlay + A.4 NEW BLOCKING coord Audio gameplay_session_ended signal + A.5 6 forbidden audio patterns AFP-DC-1..6 + A.6 DC owns ZERO audio knobs + Asset Spec Flag). **§UI Requirements ✅** (UI-1 boundaries DC owns zero rendered UI / UI-2 HUD Core integration via interact_label_key MVP fallback ui.interact.pocket_document + VS default ui.interact.read_document / UI-3 forward-dep UX spec list / UI-4 re-stated Pillar absolutes / UX Flag for VS Phase 4). **§Open Questions ✅** (5 BLOCKING MVP + 3 BLOCKING VS + 4 advisory engine VGs + 4 advisory deferred design + 12 deliberately-omitted items). Files modified: design/gdd/document-collection.md (NEW 1,218 lines) / design/registry/entities.yaml (2 referenced_by + 8 NEW + last_updated header) / design/gdd/systems-index.md (row 17 + Progress Tracker + Last Updated header) / production/session-state/active.md (this file). **Next recommended**: `/design-review design/gdd/document-collection.md` in a fresh session. Original IN PROGRESS thread preserved: (`/design-system document-collection` solo mode — solo mode, system #17 Narrative layer VS tier with per-section MVP/VS tagging strategy. Phase 2 context summary done (3 hard upstream deps PC ✅ + Save/Load ✅ + Localization ✅ + ADR-0001/2/3/4/6/7/8; 5 forward dependents Audio ✅ + MLS ✅ + Save/Load ✅ + HSS #19 + Document Overlay UI #20). 3 frozen ADR-0002 Document-domain signals locked: `document_collected(StringName)` / `document_opened(StringName)` / `document_closed(StringName)`. ADR-0003 schema frozen: `DocumentCollectionState.collected: Array[StringName]`. PC interact priority DOCUMENT=0 highest. Stencil Tier 1 (4 px) for uncollected. Localization key pattern `doc.[id].title` / `doc.[id].body`. **Phasing decided**: Single GDD with per-section [MVP]/[VS] tags (MVP = ID schema/Resource/pickup/collect/save/3 signals/locale-safe; VS = 15-25 doc roster + pickup toast HSS + Document Overlay UI). Phase 3 skeleton written to `design/gdd/document-collection.md` 2026-04-27. **§A Overview ✅ written** (Both-framing + 7 ADRs cited 1/2/3/4/6/7/8 + Pillar 2 Primary + Pillars 1+4 Supporting + Tier 1 stencil + 3 ADR-0002 signals + DocumentCollectionState ID-only schema + NOT autoload per ADR-0007 + ≤0.05 ms ADR-0008 sub-slot claim + per-section MVP/VS phasing + 8-item This-GDD-defines / 8-item This-GDD-does-NOT-define boundary listing Document Overlay UI #20 + HSS #19 + Audio + PPS + MLS + Writer/Localization + Outline Pipeline + Save/Load as boundary owners). **§B Player Fantasy ✅ written** ("Reading the Room" CD-recommended Candidate 2; curatorial register; Pillar 2 load-bearing + Pillar 1 supporting structural + Pillar 4 supporting geometric; 3 anchor vignettes Clipboard/Lectern/Telex tied to Lower Scaffolds/Restaurant/Bomb Chamber; 5 refusals incl. checklist + completion + theatrical theft + lore drop + quest delivery; design test "would a clerk have left this here" + 3-check fantasy test for future additions). Inventory issues paper TO Eve; Documents reveal paper FROM the enemy — clean differentiation. **§C Detailed Design ✅ written** (12 subsections C.1-C.12: 19 Core Rules MVP/VS-tagged + Document Resource Schema 6-row table + DocumentBody Specification 12-row table + 7-category Document Type Taxonomy + Per-Section Roster (Plaza 3 / Lower 4 / Restaurant 6 / Upper 5 / Bomb 3 = 21 with 86% off-path) + Per-Section Narrative Arc + Plaza MVP Tutorial 3-doc set (Security Logbook on-path + Tourist Register + Maintenance Clipboard off-path) + Interact-Distance Authoring Rule (height 0.4-1.5m sweet 0.7-1.1m) + Priority-Stack Authoring Rule (no doc within 0.4m of door / 0.3m of pickup) + 6 NEW CI lints + Pickup Lifecycle Pseudocode (DocumentCollection class) + 6 Tonal/Voice Rules + 7 Forbidden Document Content Rules + 11 Forbidden Patterns FP-DC-1..11 + 17-row Interactions Matrix + 23-row Bidirectional Consistency Check). Specialists consulted (4 in parallel): narrative-director (7 categories + 6 tonal rules + 7 forbidden content + per-section narrative arc + BQA never-expanded recommendation), game-designer (18 CRs + Option C decision for opened/closed emit-site + MVP pickup-only scope decision + 10 forbidden patterns), gameplay-programmer (Option A scene-rooted DC + Option ii spawn gate + type-check pattern + call_deferred queue_free + 4 verification gates VG-DC-1..4 + ADR-0008 0.05ms claim), level-designer (per-section distribution 3/4/6/5/3=21 + 75/25 off-path ratio + furniture-binding rules per section + interact-distance authoring + priority-stack authoring + 6 CI lint rules + Plaza tutorial 3-doc set). 4 user-adjudicated decisions: Q1 BQA never-expanded, Q2 21-doc distribution, Q3 1on+2off Plaza set, Q4 all 9 architectural choices locked. **7 BLOCKING coord items emerging** (4 MVP + 3 VS): MLS §C.5 amendment Plaza documents/ group + 6 CI lints / ADR-0008 amendment 0.05ms sub-slot / Localization Scaffold authoring guideline BQA-never-expanded + 2 new keys / Section-validation CI implementation Tools-Programmer / MLS §C.5 VS expansion 21-doc roster / Document Overlay UI #20 GDD adopts DC.open_document/close_document API + NOTIFICATION_TRANSLATION_CHANGED + PPS lifecycle / HSS #19 GDD subscribes document_collected. **4 ADVISORY engine VGs**: VG-DC-1 Jolt call_deferred queue_free safe / VG-DC-2 Array[StringName] duplicate sufficient vs duplicate_deep / VG-DC-3 _ready ordering after restore callback / VG-DC-4 .tres hot-reload @export reference safety. **§D Formulas ✅ written** (3 formulas: F.1 Pickup Event Frame Cost with N_subscribers tuning [t_pickup = t_signal_dispatch + t_set_membership + t_array_append + t_signal_emit + t_call_deferred] output range [0.025, 0.070] ms clamped vs ADR-0008 0.05 ms sub-slot claim; F.2 Off-Path Qualification predicate is_off_path(doc) = path_distance >= off_path_min_distance_m=10.0 m; F.3 Interact-Distance Feasibility composed predicate height [0.4, 1.5] m AND ray distance ≤ 2.0 m). Honest scope statement: DC has no balance math. Specialist consulted: systems-designer (3-formula recommendation + 5 §E edge cases). **§E Edge Cases ✅ written** (35 cases across 8 clusters: A same-frame/lifecycle storms 6 / B save-load 7 / C section-load authoring 5 / D locale + tr() 3 / E open-close VS lifecycle 4 / F DC subscriber lifecycle 2 / G authoring + engine VGs 5 / H pillar enforcement 3). 2 NEW BLOCKING coord items emerging: §C.5.6 lint #7 (DocumentCollection system node presence when documents/ group non-empty per E.17) + lint #8 (critical_path_spline presence per E.28). 1 ADVISORY: F.1 N_subscribers ≥ 6 triggers ADR-0008 amendment review per E.32. **§F Dependencies NEXT**: 11 upstream + 5 downstream + 8 ADR + bidirectional consistency check. Recommended specialists per index: narrative-director + game-designer. CD-GDD-ALIGN gate at Phase 5a-bis SKIPPED per solo mode. Earlier 2026-04-26 PM entry preserved: `/design-system menu-system` **COMPLETE 2026-04-26 PM** — solo mode, system #21 UI/Presentation, VS tier with HARD Day-1 MVP slice. All 11 sections written incrementally with user approval. **1,715 lines, 11 ## headers**. Phase 5 validation done: registry sweep applied (2 referenced_by + 4 NEW entries — HUDCore + SettingsService updated; MenuSystem cross_system_class + ModalScaffold cross_system_class + modal_scaffold_canvas_layer=20 LOCKED + menu_music_fade_out_ms=800ms safe[200,2000]); systems-index row 21 updated to "Designed 2026-04-26 PM"; Progress Tracker (Started 16→17, VS designed 1→2/7); Last Updated header refreshed. CD-GDD-ALIGN gate at Phase 5a-bis SKIPPED per solo mode. **CLOSES Settings OQ-SA-3 + HUD Core REV-2026-04-26 D2 HARD MVP DEP + PPS OQ-PPS-2 simultaneously.** **14 BLOCKING coord items remain OPEN** before sprint planning (5 inherited + 9 NEW): ADR-0004 amendment Context.MODAL + Context.LOADING (bundles Settings modal scaffold + Menu modal lifecycle + F&R revision item #4) / ADR-0004 Gate 1 + Gate 2 (inherited) / ADR-0002 settings_loaded amendment (inherited) / ADR-0007 SettingsService slot #8 (inherited) / F&R has_checkpoint() VS query API / LS transition_failed signal/bool / Save/Load required-keys validation predicate / Save/Load relative-time strings prohibition / Settings dismiss_warning() returns bool / 4 Godot 4.6 verification gates (Tween.set_duration(0.0) / Tween.stop vs kill / call_deferred("set", ...) syntax / TextServer get_line_count + autowrap mode before localization ships). **10 ADVISORY**. §F.7 + §G.5 + §Open Questions all consolidate the same 14+10 list. Sections beyond §C/§D: **§E Edge Cases ✅** (40 cases / 10 clusters; 6 NEW BLOCKING coord items emerged + 2 in-house FP amendments applied to FP-3 SubViewport ext + FP-8 create_tween ext + CR-6 button-disable + §C.4 _pending_modal_content depth-1 queue). **§F Dependencies ✅** (7 sub-sections; 12 BLOCKING + 5 ADVISORY consolidated). **§G Tuning Knobs ✅** (6 sub-sections; 7 tunable + 17 LOCKED + 9 Pillar 5 absolutes; menu_music_fade_out_ms 800ms / quicksave_feedback_duration_s 1.4s / desk_overlay_alpha 0.52 / 4-7 animation timings 80-180ms). **§H Acceptance Criteria ✅** (61 ACs / 22 groups; QA-lead's 3 GAPs addressed: CR-13 BLOCKED-on-F&R AC-MENU-22.1 + CR-19 zero-emission AC-MENU-21.1 + F.2 locale gate AC-MENU-6.6). **§Visual/Audio ✅** (V.1-V.9 + A.1-A.7; mission-dossier card visual register + 8 UI-bus foley cues incl. typewriter clack / drawer slide / grid nav / card flip / stamp / paper shuffle / modal open + 5 audio FPs AFP-1..AFP-5 + reduced-motion audio rule cues NOT suppressed + Audio GDD coord item for UI foley registration amendment). **§UI Requirements ✅** (UI-1 boundaries + UI-2 Day-1 vs Polish accessibility floor matrix + UI-3 8 per-screen UX specs for `/ux-design` Phase 4 — boot-warning + Main Menu + Quit-Confirm = Day-1 MVP priority). **§Open Questions ✅** (14 BLOCKING for sprint OQ-MENU-1..14 + 10 ADVISORY OQ-MENU-15..24 + 3 RESOLVED Settings/HUD/PPS + 9 deliberately-omitted items). Specialists consulted (all section-mandatory): creative-director (§B 3 framings → C1 The Case File), ux-designer + game-designer + art-director + godot-specialist + accessibility-specialist (§C), systems-designer (§D 8 formulas + §E 40 edge cases), audio-director + art-director (§V/A), qa-lead (§H 61 ACs + 3 GAPs). 4 user-adjudicated decisions: Q1 Quit-confirm = standard modal scaffold + CASE CLOSED visual; Q2 Save grid = 2×N (2×4 Load / 2×3+1 Save); Q3 overwrite = in-card; Q4 New Game confirm = yes when slot 0 only progress. Next recommended: `/design-review design/gdd/menu-system.md` in a fresh session.) Original task IN PROGRESS thread preserved: (`/design-system menu-system` solo mode, system #21 (UI/Presentation, VS tier with HARD Day-1 MVP slice for HUD Core REV-D2 + Settings CR-18/OQ-SA-3). Phase 2 context summary done (10 hard upstream deps + 5 forward dependents + ADR-0002/0003/0004/0007 + 2 ADR-0004 verification gates STILL OPEN inherited as BLOCKING + InputContext.LOADING coord NEW BLOCKING). Phase 3 skeleton written to `design/gdd/menu-system.md` (single GDD with per-section [MVP]/[VS] tags chosen). User-approved start: 2026-04-26 PM. **§A Overview ✅ written** (both-framing + ADR-0002/0003/0004/0007 + LS CR-4/CR-7 + Save/Load CR-10/11/9/8 + Settings CR-18 cited + 7-screen owned-surfaces enumeration + boundary statement listing 8 NOT-defined items + Day-1 MVP vs full VS phasing per-section). **§B Player Fantasy ✅ written** ("The Case File" CD-recommended Candidate 1 of 3; Primary 5 + **Primary 1** + Supporting 3; NO carve-out needed; bureaucratic register: Save Dispatch / Resume Surveillance / Abort Mission / Close File; 5 refusals + fantasy test). **§C Detailed Design ✅ written** (11 subsections C.1-C.11: 25 Core Rules MVP/VS-tagged + 12-row Owned Surfaces table + 6-step Boot Sequence + ModalScaffold architecture + 4-state Save Card Grid + 11-row Esc-Key Discipline + 7-row InputContext Push/Pop Matrix + Locked English Strings + 14-row AccessKit Per-Widget Table + 22-row Interactions Matrix + 18 Forbidden Patterns). Specialists consulted: ux-designer (modal lifecycle + InputContext + focus management + 10 forbidden UX patterns + 4 OQs), game-designer (locked English strings + 20 CRs + Restart-from-Checkpoint = "Re-Brief Operation" VS + Continue label-swap + Quit confirm + 8 FPs + Pause music behaviour + boot order), art-director (manila folder color + tab + page texture + 52% Ink Black overlay + period stamps + BQA seal + bottom-right slide-in geometry + save card 360×96 px + per-state visual + grid layouts + photosensitivity advisory card + DISPATCH NOT FILED + CLOSE FILE Y/N + animation choreography + asset list + 10 visual restraints), godot-specialist (Godot 4.6 feasibility 12-item batch incl. boot pattern clarification, CanvasLayer 8 Pause + 20 Modal, Custom Control modal not Window/AcceptDialog, GridContainer + Button focus_mode FOCUS_ALL, auto_translate_mode caveats, Gate 1+2 verification 10-min editor session, PauseMenuController not autoload, synchronous _boot_warning_pending poll, get_stack() known-risk), accessibility-specialist (AccessKit per-widget table for 7 surfaces, keyboard nav rules, save card announcement template, photosensitivity AccessKit semantics, save-failed assertive policy, 6 FP-M items, color-and-shape compliance for save card states, accessibility_name re-resolve via NOTIFICATION_TRANSLATION_CHANGED, reduced-motion conditional). 4 user-adjudicated decisions: Q1 Quit-confirm = standard modal scaffold + CASE CLOSED visual; Q2 Save grid = 2×N grid (2×4 Load / 2×3+1 Save); Q3 overwrite confirm = in-card; Q4 New Game confirm = yes when slot 0 only progress. **6 BLOCKING coord items emerging**: ADR-0004 add Context.MODAL + Context.LOADING / ADR-0004 Gate 1 (accessibility_*) + Gate 2 (Theme inheritance prop) / ADR-0002 settings_loaded amendment / F&R GDD has_checkpoint() public query API for VS / **CLOSES Settings OQ-SA-3 + CLOSES HUD Core REV-D2 HARD MVP DEP**. **3 ADVISORY**: ADR-0004 IG7 layer-10 collision Settings vs Cutscenes / PauseMenuController architecture (Node vs SectionRoot script) / Localization L212 cap scope. **§D Formulas ✅ written** (8 formulas: F.1 grid cell position 2×N + 7-slot occupancy predicate / F.2 photosensitivity body fit predicate 11px→300chars / 10px→345chars / F.3 reduced-motion duration gate (binary, evaluated at _play_*) / F.4 quicksave feedback timeline 1.4s default + debounce-replace + save-failed override / F.5 in-card overwrite-confirm 2-press exit predicate + state machine / F.6 per-frame budget claim 0.0ms gameplay + ~0.040ms typical pause + ZERO ADR-0008 sub-slot recommendation / F.7 modal AccessKit one-shot timing assertive→deferred-off-next-frame / F.8 accessibility_name re-resolve pattern via NOTIFICATION_TRANSLATION_CHANGED). 9 verification gates accumulated (1 HIGH + 5 MEDIUM + 3 LOW). Next: §E Edge Cases (systems-designer for boot-burst storms / save-failed during pause / locale-change with menu open / focus loss + alt-tab / gamepad disconnect mid-menu / boot-warning + immediate-New-Game collision / mid-load Esc / corrupt slot 0 with Continue button / etc). Pillar alignment: Primary 5 + Supporting 1 + 3. Day-1 MVP scope: photosensitivity boot-warning modal scaffold + Settings entry-point + minimal Main Menu shell. VS scope: full Main Menu / Pause / Load Game grid / Save Game grid / save-failed dialog / mission dossier card. Earlier 2026-04-26 entry preserved below.) Original: (`/design-system settings-accessibility` **COMPLETE 2026-04-26** — solo mode, all 11 sections written incrementally with user approval. 1,146 lines, 84 section headers. Phase 5 validation: registry sweep (4 referenced_by updates + 3 NEW entries — SettingsService cross_system_class autoload slot #8 + settings_loaded one-shot signal + damage_flash_enabled bool kill-switch); systems-index row 23 updated to "Designed 2026-04-26"; Progress Tracker (Started 15→16, VS designed 0→1/7); Last Updated header updated. CD-GDD-ALIGN gate at Phase 5a-bis SKIPPED per solo mode. **8 BLOCKING coord items remain OPEN** before sprint planning: ADR-0007 slot #8 amendment / ADR-0002 settings_loaded amendment / ADR-0004 Gates 1+2 (accessibility_* property names + base_theme vs fallback_theme) / Outline Pipeline get_hardware_default_resolution_scale() query API per CR-11 / Combat damage_flash_enabled subscription suppresses EHF per CR-16 / Input GDD register use_gadget+takedown separately per CR-22 + document rebind boot pattern per CR-19 / Menu System reads _boot_warning_pending + provides modal scaffold per CR-18 (OQ-SA-3). Plus **3 ADVISORY**: PC GDD Toggle contract acknowledge / Localization Scaffold locale-switcher VS contract / Inventory acknowledge OQ-INV-5 + OQ-INV-6 closure. Next recommended: `/design-review design/gdd/settings-accessibility.md` in a fresh session.) Original task IN PROGRESS thread preserved below: (`/design-system settings-accessibility` solo mode. **§A Overview ✅ + §B Player Fantasy ✅ + §C Detailed Design ✅ written.** §C contents: C.1 23 Core Rules (sole-publisher discipline + Consumer Default Strategy + 8-slot autoload + dual-discovery crosshair + 333 ms safety floor + Toggle-Sprint/Crouch/ADS MVP + separate-rebind use_gadget/takedown MVP + subtitles default ON VS); C.2 6 categories table; C.3 boot-time burst sequence; C.4 HSplitContainer modal panel; C.5 3-state rebind capture (NORMAL_BROWSE→CAPTURING→CONFLICT_RESOLUTION); C.6 photosensitivity boot-warning flow with 38-word locked copy; C.7 9-row interactions matrix + bidirectional consistency check; C.8 8 Forbidden Patterns. Specialists consulted: ux-designer (HSplitContainer + rebind state machine + revert banner 10s), accessibility-specialist (WCAG 2.1 AA + AccessKit per-widget contract + photosensitivity rules + Toggle-Sprint motor accessibility + subtitles-on-default), game-designer (defaults discipline + boot order + Consumer Default Strategy + locale semantics + 7 forbidden patterns). 4 user-adjudicated decisions: revert banner (only for resolution_scale, not other settings), photosensitivity kill-switch gates HUD+EHF, Toggle-input MVP scope, Subtitles default ON. **6 BLOCKING coord items emerging**: ADR-0007 amendment (slot #8), ADR-0002 amendment (settings_loaded signal + settings domain register), Outline Pipeline get_hardware_default_resolution_scale() query API, Combat damage_flash_enabled subscription, Input GDD register use_gadget+takedown separately + document rebind boot pattern, Menu System GDD must read _boot_warning_pending. **§A Overview ✅ + §B Player Fantasy ✅ ("The Stage Manager" Candidate 1, CD-recommended; Pillar 5 carve-out primary + Pillar 3 + Pillar 1 supporting; 5 refusals + fantasy test)** written. §A Overview ✅ written earlier (cites ADR-0002 setting_changed sole-publisher Variant exception + ADR-0003 user://settings.cfg + ADR-0004 InputContext.SETTINGS + Pillar 5 carve-out + Day-1 MVP vs VS phasing per-section tags + 6 categories Audio/Graphics/Accessibility/HUD/Controls/Language + boundary statement). Phase 2 context summary covered: 8 forward-dep GDDs with declared contracts (Combat OQ-CD-12 ×7 incl. **photosensitivity warning + dual-discovery crosshair BLOCKING**, HUD Core REV-2026-04-26 D2 **HARD MVP DEP** for photosensitivity toggle UI + boot-warning UI, Inventory ×3 + OQ-INV-5 separate-rebind, PC AC-9.2 BLOCKED on `Settings.get_resolution_scale()`, Outline `graphics.resolution_scale`, Audio 6 buses + clock_tick, Localization locale switcher, Input rebinding UI). 2 ADR-0004 verification gates STILL OPEN and BLOCKING per IG10 (Gate 1 `accessibility_*` property names; Gate 2 `base_theme` vs `fallback_theme`). User decisions: §A framing both/data+player; ADRs 2/3/4 cited; fantasy = direct (Pillar 5 carve-out); phasing = single GDD with per-section MVP/VS tags. Next: §B Player Fantasy with MANDATORY creative-director consultation.)

## Previous Task — `/design-system hud-core` **COMPLETE 2026-04-25**

**Last updated:** 2026-04-25 (`/design-system hud-core` **COMPLETE** — solo mode, all 11 sections written to `design/gdd/hud-core.md` (1,182 lines). Phase 5 validation done: registry updated (2 referenced_by + 6 new entries), systems-index row 16 + Progress Tracker (Started 14→15, MVP designed 14→15/16) + Last Updated header updated. **2 ADR-0002 amendments now BLOCKING for sprint** (`ui_context_changed`, `takedown_availability_changed`). Next recommended: `/design-review design/gdd/hud-core.md` in a fresh session.)

## Current Task — `/design-system hud-core` **COMPLETE 2026-04-25**

- **Task**: `/design-system hud-core` — system #16, UI/Presentation layer, MVP tier, M effort
- **Review mode**: `solo` (CD-GDD-ALIGN gate at Phase 5a-bis skipped per `.claude/docs/director-gates.md`)
- **File**: `design/gdd/hud-core.md` (**1,182 lines**, 82 section headers — all 11 sections complete)
- **Pillar alignment**: Primary 5 (Period Authenticity) + Primary 2 (Discovery — "no waypoints"); Secondary 1 (Comedy — HUD silent) + 3 (Theatre — critical-state cue) + 4 (Locations — modesty)
- **Status**: **COMPLETE** — all 15 tasks done. Ready for `/design-review` in fresh session.

### Sections written

- §Overview ✅ (1 dense paragraph — both-framing + ADR-0002/0004/0008 cited + boundary statement)
- §Player Fantasy ✅ (Candidate A "The Glance" — cockpit-dial fantasy + 2 primary + 3 secondary pillars + 5 explicit refusals + fantasy test for future additions)
- §Detailed Design ✅ (C.1 20 Core Rules + C.2 5-widget grammar/anchor table + C.3 3-state prompt-strip machine + C.4 damage-flash narrative + C.5 16-row Interactions matrix + 4 BLOCKING + 3 ADVISORY coord items + bidirectional check + C.6 14 Forbidden Patterns)
- §Formulas ✅ (F.1 photosensitivity rate-gate aligned with Audio §F.4 / F.2 critical-state edge-trigger / F.3 viewport scale [0.667, 2.0] / F.4 crosshair radius [3, 12] / F.5 frame-cost composition with 0.259 ms worst-case vs 0.3 ms cap + dry-fire NOT-rate-gated rationale)
- §Edge Cases ✅ (37 cases across 10 clusters: A same-frame storms / B critical-state boundaries / C flash coalescing / D prompt-strip lifecycle / E InputContext+visibility / F save/load / G settings+localization / H performance / I subscriber lifecycle / J pillar-violation guards)
- §Dependencies ✅ (8 hard upstream + 2 soft + 3 forward dependents + 8 ADR + 7 forbidden non-deps + 4 BLOCKING + 3 ADVISORY coord items + 9-row bidirectional consistency check)
- §Tuning Knobs ✅ (G.1 5 HUD-owned + G.2 6 Combat/PC-owned references + G.3 11 Art-Bible-owned visual constants + G.4 4 forward-dep Settings knobs + G.5 ownership matrix)
- §Visual/Audio ✅ (V.1 StyleBoxFlat specs for 5 widget bgs + key-rect / V.2 5-asset list / V.3 per-widget render trees / V.4 damage-flash composition / V.5 critical-state transition / V.6 crosshair _draw() with full GDScript / V.7 14-item visual-restraint compliance check + Asset Spec Flag; A.1 4 audio contracts (HUD owns ZERO audio) + A.2 mix bus reference)
- §UI Requirements ✅ (UI-1 flow boundaries / UI-2 10-row accessibility floor Day 1 vs Polish vs forward-dep / UI-3 HSS extension API via `get_prompt_label()` / UI-4 UX Flag for `/ux-design hud-core` Phase 4)
- §Acceptance Criteria ✅ (73 ACs across 12 groups: H.1 lifecycle 5 / H.2 health 7 / H.3 photosensitivity 6 / H.4 weapon+ammo 6 / H.5 gadget 6 / H.6 prompt-strip 7 / H.7 crosshair 5 / H.8 input-context 4 / H.9 performance 5 / H.10 forbidden-pattern grep gates 13 / H.11 locale+a11y 5 / H.12 save/load 4)
- §Open Questions ✅ (6 OQs — 2 BLOCKING (OQ-HUD-3 Settings boot order, OQ-HUD-4 LSS restore-callback ordering) + 4 ADVISORY; 10 deliberately-omitted items consciously excluded from MVP)

### Specialist consultations (all section-mandatory per skill)

- **creative-director** (§B): 3 candidate framings — A "The Glance" (cockpit-dial register), B "Numeral Goes Orange" (theatrical cue), C "Furniture Not Theatre" (modest dashboard). User selected **Candidate A** (Pillar 5 + 2 primary; matches Inventory "Crouched Swap" precedent register)
- **ux-designer** (§C widget grammar + prompt-strip lifecycle + accessibility floor): 5-widget anchor table; 3-state machine resolver with priority TAKEDOWN > INTERACT > HIDDEN; F.4 crosshair clamp; auto-dismiss timer at 2.0s (deferred to HSS via MEMO defer)
- **game-designer** (§C 20 Core Rules + photosensitivity semantics + state machine): full CR set; F.1 photosensitivity gate algorithm with player_died `_flash_timer.stop()` requirement
- **godot-specialist** (§C Godot 4.6 feasibility): signal subscription via `Events.signal.connect(handler)`; explicit `_exit_tree()` disconnect with `is_connected()` guard (ADR-0002 §Impl Guideline 3 mandates); CanvasLayer at index 1; tree-order z within layer; `add_theme_color_override` over theme swap; `await get_tree().process_frame` for damage flash; child Timer node (oneshot 333 ms) over SceneTreeTimer; `_draw()` over nested ColorRects for crosshair; flagged ADR-0004 Gate 2 (Theme inheritance prop name) + Gate 1 (accessibility_live prop name) as BLOCKING; recommended ADR-0002 amendment for ui_context_changed
- **systems-designer** (§D + §E): F.1 validated with `_flash_timer.stop()` correction; F.2 with `max(max_health, 1.0)` divide-by-zero floor; F.5 frame-cost composition; 37 edge cases across 10 clusters with `is_instance_valid` guard requirement on prompt-strip
- **art-director** (§V): StyleBoxFlat specs for 5 widget backgrounds + key-rect; 5-asset list; per-widget render trees; crosshair `_draw()` with full GDScript; Ink Black `#1A1A1A` confirmed against Art Bible §4.4; 14-item visual-restraint compliance check
- **qa-lead** (§H): 73 ACs across 12 groups; Logic/Integration BLOCKING + UI/Visual ADVISORY; AC-HUD-pillar-1 + AC-HUD-pillar-2 scene-tree CI scans (kill-confirmed + damage-direction guards)

### User-approved design decisions via AskUserQuestion (4 blockers)

1. **HUD visibility on InputContext change** → Add `ui_context_changed(new_ctx, prev_ctx)` signal to ADR-0002 (UI domain) — BLOCKING coord item
2. **TAKEDOWN_CUE eligibility detection** → Add `takedown_availability_changed(eligible, target)` signal to ADR-0002 (SAI domain) — BLOCKING coord item, bundles with #1
3. **MEMO_NOTIFICATION scope** → Defer entirely to HUD State Signaling (system #19, VS); HUD Core MVP prompt-strip = HIDDEN/INTERACT_PROMPT/TAKEDOWN_CUE only
4. **Empty gadget tile rendering** → Render dimmed 40% opacity (geometry stability over hide-when-empty)

### F.2 unit-mismatch fix (registry conflict caught at Phase 5b self-check)

Registry has `player_critical_health_threshold = 25 hp_percent` (canonical at max_health=100). Initial F.2 wrote `(health_ratio < 0.25)` mixing units. Fixed F.2 to `(health_ratio < threshold_ratio)` where `threshold_ratio = player_critical_health_threshold / 100.0`. Pattern aligns with Audio GDD §F.4 clock-tick trigger (identical canonical pattern). Registry note expanded with Audio/HUD divide-by-100 contract.

### Registry Phase 5b (2 referenced_by + 6 NEW entries)

- **2 referenced_by updates**: `player_max_health.referenced_by += hud-core.md` (F.2 ratio computation); `player_critical_health_threshold.referenced_by += hud-core.md + audio.md` (Audio §F.4 was never registered as such); unit clarified `hp` → `hp_percent` with note documenting Audio/HUD divide-by-100 canonical pattern
- **6 NEW entries**:
  - `hud_damage_flash_cooldown_ms = 333` ms safe [200, 500] — Combat-owned, HUD-enforced WCAG 2.3.1 photosensitivity gate
  - `crosshair_dot_size_pct_v = 0.19%` safe [0.15, 0.30] — Combat-owned, HUD F.4 dot radius computation
  - `crosshair_halo_style = tri_band` enum — Combat-owned, HUD V.6 _draw() composition
  - `crosshair_enabled = true` bool — Combat-owned default, Settings-persisted opt-out
  - `gadget_rejected_desat_duration_s = 0.2` s safe [0.1, 0.5] — HUD-owned NEW knob
  - `HUDCore` cross_system_class — CanvasLayer scene at index 1, NOT autoload, public extension API `get_prompt_label()` for HSS forward-extension

### Pre-implementation coord items OPEN (4 BLOCKING + 3 ADVISORY)

**4 BLOCKING for sprint:**
1. ADR-0002 amendment: add `ui_context_changed(new_ctx: InputContextStack.Context, prev_ctx: InputContextStack.Context)` signal (UI domain)
2. ADR-0002 amendment: add `takedown_availability_changed(eligible: bool, target: Node3D)` signal (SAI domain) — bundle with #1
3. ADR-0004 Gate 2: confirm Theme inheritance property name (`base_theme` vs `fallback_theme`) — 5-min editor inspection (godot-specialist flagged unverified against training data which expects `fallback_theme`)
4. ADR-0004 Gate 1: confirm `accessibility_live` property name on Godot 4.6 Label/Control — deferrable to Polish per ADR-0004 §10, BLOCKING for VS

**3 ADVISORY:**
5. Settings & Accessibility GDD (system #23) when authored — define `crosshair_enabled / crosshair_dot_size_pct_v / crosshair_halo_style` + locale-change `setting_changed` emit-site contract
6. HUD-scale slider as Settings forward-dep (OQ-HUD-1) — not in HUD Core MVP scope
7. Combat §UI-6 dual-discovery path requires Settings GDD authoring

### 6 Open Questions captured in §Open Questions

- **OQ-HUD-1 [ADVISORY]**: HUD scale slider Settings forward-dep
- **OQ-HUD-2 [ADVISORY]**: `_pending_flash` clear on visibility=false — playtest decision
- **OQ-HUD-3 [BLOCKING for sprint integration]**: Settings boot ordering vs HUD `_ready()` integration verification
- **OQ-HUD-4 [BLOCKING for VS]**: LSS restore-callback signal-replay ordering — engine verification gate
- **OQ-HUD-5 [ADVISORY]**: `C_label` >0.05 ms breach contingency — performance ADR amendment trigger
- **OQ-HUD-6 [ADVISORY]**: Crosshair default ON vs OFF — playtest decision

### Files modified this session

- `design/gdd/hud-core.md` — **NEW** (1,182 lines)
- `design/registry/entities.yaml` — 2 referenced_by updates + 6 new entries appended; `last_updated` header updated
- `design/gdd/systems-index.md` — row 16 Status updated to Designed; Progress Tracker counts updated (Started 14→15, MVP designed 14→15/16); Last Updated header updated
- `production/session-state/active.md` — this file

### Context locked (Phase 2 summary)

- Upstream Approved: PC §UI Requirements (signals + queries + HUD-must-NOT-render list), Combat §UI-1..UI-6 (crosshair widget, photosensitivity rate-gate `hud_damage_flash_cooldown_ms = 333`), Inventory §UI-1..UI-9 (4 frozen signals + `gadget_activation_rejected` 0.2 s desat), Civilian AI Pillar 5 zero-UI absolute, F&R empty UI absolute
- ADR constraints: ADR-0008 Slot 7 = 0.3 ms HUD per-frame cap (signal-driven only; polling forbidden); ADR-0004 Theme + FontRegistry + `mouse_filter = MOUSE_FILTER_IGNORE`; ADR-0002 HUD subscribes-only (emits zero signals); ADR-0007 HUD is NOT autoload (CanvasLayer scene per main scene)
- Art Bible §7A-D + §4.4: NOLF1 corner anchors locked (BL health / BR weapon+ammo / TR gadget / center-lower contextual); BQA Blue `#1B3A6B` 85% + Parchment `#F2E8C8` + Alarm Orange `#E85D2A` (<25% HP) + PHANTOM Red `#C8102E` (captured equipment); 1-frame numeral flash on damage, 333 ms cooldown
- Forbidden (Pillar 5 anti-pillars): objective markers / minimap / kill cams / ping systems / waypoints / alert visual indicators / civilians / death screen / retry / stamina bar / damage direction / hit marker / hold-E ring / damage numbers / floating text / radial weapon wheel
- Known cross-system facts: `player_max_health = 100`, `player_critical_health_threshold = 25%`, `hud_damage_flash_cooldown_ms = 333` ms WCAG 3 Hz, `crosshair_dot_size_pct_v = 0.19%`, `crosshair_halo_style = tri_band`, `crosshair_enabled = true` default opt-out

### Next steps

- §Overview framing widget (Framing/ADR-ref/Fantasy tabs) → draft → write
- §Player Fantasy (creative-director MANDATORY) → candidate framings
- §Detailed Design (ux-designer + art-director + game-designer + ui-programmer specialists per routing table for UI category)
- §Formulas (systems-designer for photosensitivity coalesce + critical-threshold transition)
- §Edge Cases (systems-designer for same-frame storm, LOAD_FROM_SAVE replay, sub-frame ammo)
- §Dependencies + §Tuning Knobs + §Acceptance Criteria (qa-lead) + §Visual/Audio (art-director) + §UI Requirements + §Open Questions
- Phase 5b registry sweep + systems-index row 16 update

## Previous Task — `/design-system civilian-ai` **COMPLETE 2026-04-25**

(Civilian AI session entry — preserved below)

**Last updated:** 2026-04-25 (`/design-system civilian-ai` **COMPLETE** — solo mode, all 11 sections written to `design/gdd/civilian-ai.md` (749 lines). Phase 5 validation done: registry updated (7 entries — CivilianAI / CivilianAIState / WitnessEventType / civilian + panic_anchor group tags / cai_frame_budget_ms_p95 / bqa_pickup_distance_m), systems-index row 15 + Progress Tracker updated. **Closes SAI OQ-SAI-1 by spec**. Next recommended: `/design-review design/gdd/civilian-ai.md` in a fresh session.)

## Current Task — `/design-system civilian-ai` **COMPLETE 2026-04-25**

- **Task**: `/design-system civilian-ai` — system #15, Gameplay layer, MVP tier, S effort
- **Review mode**: `solo` (CD-GDD-ALIGN gate at Phase 5a-bis skipped per `.claude/docs/director-gates.md`)
- **File**: `design/gdd/civilian-ai.md` (**749 lines**, all 11 sections written — 8 required + Visual/Audio + UI + Open Questions)
- **Pillar alignment**: Primary 3 (Stealth is Theatre — audience-as-witnesses) + 1 (Comedy chorus — Audio Formula 2 diegetic-recedes); Secondary 2 (BQA tells at VS) + 4 + 5
- **Status**: **COMPLETE** — all 11 tasks done. Ready for `/design-review` in fresh session.

### Sections written

- §Overview ✅ (1 dense paragraph — phased MVP/VS scope + ADR citations + chorus-not-co-star framing)
- §Player Fantasy ✅ (Candidate B "Stealth With Witnesses" — schoolteacher anchor moment, audience makes theatre literal)
- §Detailed Design ✅ (C.1 Core Rules 15 CRs + C.2 State Machine 2-state + C.3 Flee Algorithm 3-phase pseudocode + C.4 Witness Event Trigger Rules VS + C.5 Interactions 11-row table + C.6 Forbidden Patterns 10 grep rules)
- §Formulas ✅ (F.1 panic-trigger predicate + F.2 flee re-target proximity gate + F.3 ADR-0008 0.15 ms p95 budget envelope + F.4 anchor scoring with dot-product filter + F.5 VS witness emission distance gate)
- §Edge Cases ✅ (31 cases across 8 clusters: A same-frame storms / B damage / C save-load / D SAI interaction / E Audio interaction / F NavigationAgent3D / G section reload / H VS-tier scope boundary)
- §Dependencies ✅ (8 upstream + 7 downstream + 6 ADR + 8 forbidden non-deps + 10 coord items + 9-GDD bidirectional consistency)
- §Tuning Knobs ✅ (G.1 panic radii + G.2 flee behavior + G.3 VS witness radii + G.4 BQA pickup VS + G.5 perf budget binding + G.6 ownership matrix)
- §Visual/Audio ✅ (5 V + 5 A subsections — 4 archetypes × 2 variants = 8 meshes + 4-state AnimationTree + Tier 3 default + Tier 1 BQA promotion + Pillar 5 forbidden patterns + signal-publisher-only audio handoff + Pillar 1 reading of Audio Formula 2)
- §UI Requirements ✅ (Pillar 5 zero-UI absolute — civilians never appear in HUD; VS forward-deps only)
- §Acceptance Criteria ✅ (33 ACs across 10 groups — 28 BLOCKING + 5 ADVISORY incl. 4 VS-only)
- §Open Questions ✅ (6 OQs — 3 BLOCKING incl. NavigationAgent3D engine-verification gate + VS feature flag + civilian gasp VO sourcing; 3 ADVISORY playtest-resolvable; 7 deliberately-omitted items)

### Specialist consultations (all section-mandatory per skill)

- **creative-director** (§B): Candidate B "Stealth With Witnesses" framing selected (Pillar 3 primary + Pillar 1 secondary); the audience makes the theatre literal
- **systems-designer** (§C Core Rules + §D Formulas): 15 CRs + 5 formulas with strict template format
- **ai-programmer** (§C state machine + §C.3 flee algorithm + §C.4 witness trigger + §C.5 per-frame budget): 2-state model rationale, hybrid flee algorithm with cower phase, VS-coupled witness emission
- **gameplay-programmer** (§C Godot 4.6 feasibility): NavigationAgent3D.velocity_computed RVO callback pattern, Jolt body_entered reliability at Eve walking speed, set_physics_process gating, OutlineTier.set_tier signature with MeshInstance3D not Node, signal lifecycle, group tags from .tscn auto-registered
- **art-director** (§V): 4 archetypes × 2 variants = 8 meshes; 4-state AnimationTree; Pillar 5 forbidden patterns; AD-COORD-01 BQA composed-geometry tell
- **audio-director** (§A): signal-publisher-only handoff; CAI does NOT own AudioStreamPlayer3D / footsteps / death sounds / dialogue / muzzle / radio
- **qa-lead** (§H): 33 ACs across 10 groups with story-type tags + BLOCKING/ADVISORY tags + evidence paths

### User-approved design decisions via AskUserQuestion

1. **CR-4 kill-signal subscription**: `enemy_killed(actor: Node, killer: Node)` (Combat domain per ADR-0002) — derives cause_position via `actor.global_position` with `is_instance_valid()` guard; CAI does NOT subscribe to `guard_incapacitated` (UNCONSCIOUS chloroform takedowns are STEALTH successes — chorus must not ruin them)
2. **CR-10 LOAD_FROM_SAVE restore behavior**: recompute flee target from saved `_cause_position` (serialize `{ panicked: bool, cause: Vector3 }` per civilian); civilian resumes fleeing on restore (preserves Player Fantasy anchor — schoolteacher resumes walking toward viewing platform); NO `civilian_panicked` re-emit (Audio rebuilds `panic_count` via group query of `get_tree().get_nodes_in_group("civilian")`)

### Registry Phase 5b (7 NEW entries written to `design/registry/entities.yaml`)

- **3 cross-system Resource/enum types**: `CivilianAI` (CharacterBody3D entity + class), `CivilianAIState` (save sub-resource — Dictionary[StringName, Dictionary] keyed by actor_id), `WitnessEventType` (cross_system_enum owned by CivilianAI per ADR-0002 enum-ownership rule)
- **2 group tags**: `civilian` (the only allowed group; SAI E.14 vision filter rejects civilians from this group; Audio queries this for panic_count rebuild), `panic_anchor` (level-designer-authored Marker3D group; CAI flee algorithm queries for §C.3 Phase 2 selection)
- **2 perf/VS constants**: `cai_frame_budget_ms_p95 = 0.15` (ADR-0008 Slot #8 sub-claim), `bqa_pickup_distance_m = 3.0` (VS-only outline-tier promotion radius)
- **No existing-entry `referenced_by` updates** — civilians don't carry weapons (Inventory CR-7a) so no WorldItem/Checkpoint/etc. updates needed

### SAI OQ-SAI-1 CLOSED by CAI sign-off

SAI's deferred OQ-SAI-1 — "Guard-to-civilian propagation bidirectional? (Does a panicking civilian cascade-alert multiple guards?)" — is **closed** by CAI's spec:
- F.5 + CR-12: at VS, `civilian_witnessed_event` propagates to ALL guards within their own perception radius (SAI handles propagation)
- CAI emits at most ONCE per civilian per section (one-shot latch `_witnessed_event_already_emitted`)
- Bidirectional cascade is allowed because the per-civilian latch caps signal traffic regardless of guard count
- Coord item §F.5#10: SAI OQ-SAI-1 should be updated to "Closed by civilian-ai.md F.5 + CR-12 — 2026-04-25"

### Pre-implementation coord items open (10 items)

**4 BLOCKING for MVP sprint:**
1. ADR-0002 amendment — `CivilianAI.WitnessEventType` enum stub for `Events.gd` compile (atomic-commit per ADR-0002)
2. ADR-0008 amendment — 0.15 ms Slot #8 sub-claim registration in `docs/registry/architecture.yaml`
3. OQ-CAI-3 engine-verification gate — Godot 4.6 NavigationAgent3D.is_navigation_finished() lag + LSS register_restore_callback ordering
4. PC GDD touch-up coord (already noted by F&R) — get_first_node_in_group("player") fallback for VS BQA pickup

**1 BLOCKING for VS sprint (not MVP):**
5. ADR-0001 status (Proposed → Accepted) — BQA contact outline promotion enforceable when ADR-0001 lands
6. Inventory weapon_drawn_in_public signal — F.5 EVE_BRANDISHING_WEAPON event source (or repurpose gadget_activated)
7. OQ-CAI-4 — VS feature flag mechanism (compile-time gate for CR-12 + CR-14)

**1 BLOCKING for MVP playtest (not sprint start):**
8. OQ-CAI-6 — Civilian gasp VO sourcing (carry-forward from Audio L689 coord item)

**6 ADVISORY:**
9. Audio §Concurrency Rule 5 dead-code annotation
10. Signal Bus L122 handler-table verification post-this-GDD
11. MLS L679 outline-tier reconciliation (says "Medium tier" — OP L112 says "Tier 3 LIGHT", OP authoritative)
12. Save/Load CivilianAIState `cause: Vector3` schema touch-up
13. panic_anchor section-validation CI extension (coord with MLS §C.5.6)
14. SAI OQ-SAI-1 closure note (should reference this GDD)

### 6 Open Questions captured in §Open Questions

- **OQ-CAI-1 [ADVISORY]**: F.5 witness-latch trade-off (closer-event suppression)
- **OQ-CAI-2 [ADVISORY]**: F.4 anchor scoring weight (Euclidean vs path-distance)
- **OQ-CAI-3 [BLOCKING]**: Godot 4.6 NavigationAgent3D engine-verification gate
- **OQ-CAI-4 [BLOCKING for VS]**: VS feature flag mechanism
- **OQ-CAI-5 [ADVISORY]**: CALM-state animation ownership (CAI vs MLS-T6 vs AnimationTree default)
- **OQ-CAI-6 [BLOCKING for MVP playtest]**: Civilian gasp VO sourcing

### Files modified this session

- `design/gdd/civilian-ai.md` — **NEW** (749 lines)
- `design/registry/entities.yaml` — 7 new entries appended
- `design/gdd/systems-index.md` — row 15 Status updated to Designed; Progress Tracker counts updated (Started 13→14, MVP designed 13→14/16); Last Updated header updated
- `production/session-state/active.md` — this file

### Previous task — see "Previous Task" sections below

## Current Task — `/design-system mission-level-scripting` **COMPLETE 2026-04-24**

- **Task**: `/design-system mission-level-scripting` — system #13, Gameplay layer, MVP tier, M effort
- **Review mode**: `solo` (CD-GDD-ALIGN gate at Phase 5a-bis skipped per `.claude/docs/director-gates.md`)
- **File**: `design/gdd/mission-level-scripting.md` (**834 lines**, all 11 sections written — 8 required + Visual/Audio + UI + Open Questions)
- **Pillar alignment**: Primary 1 (Comedy) + 4 (Iconic Locations); Secondary 2 (Discovery) + 3 (Theatre)
- **Status**: **COMPLETE** — all 12 tasks done. Ready for `/design-review` in fresh session.

### Sections written

- §Overview ✅ (1 dense paragraph — MLS 5 responsibilities + pillar binding + ADR citations)
- §Player Fantasy ✅ (Candidate B "briefing ended before the game began" — BQA Nagra reel, Paris canonical)
- §Detailed Design ✅ (C.1 Core Rules 20 rules + C.2 Mission State Machine + C.3 Objective State Machine + C.4 Scripted-Moment Taxonomy 7 types + C.5 Section Authoring Contract 6 subsections + C.6 Per-Section Iconic Beats × 5 + C.7 Interactions table + C.8 Forbidden Patterns 8 FPs)
- §Formulas ✅ (F.1 mission-complete gate + F.2 can-activate + F.3 alert-comedy budget + F.4 SaveGame timing + F.5 supersede-cascade + F.6 cache distribution + F.7 trigger single-fire latch — 7 formulas)
- §Edge Cases ✅ (36 edge cases across 8 clusters: same-frame storms, RESPAWN, save/load, authoring violations, Jolt, state corruption, cross-GDD, autoload lifecycle)
- §Dependencies ✅ (11 upstream + 7 downstream + 6 ADR deps + 7 forbidden non-deps + 12 coord items + bidirectional consistency)
- §Tuning Knobs ✅ (7 subsections — scripted behaviour, SaveGame assembly, cache placement, supersede, Inventory-locked caps, CI constants, Pillar-1 absolutes)
- §Visual/Audio ✅ (4 visual + 5 audio subsections + asset-spec flag + new Audio coord item)
- §UI Requirements ✅ (MVP zero-UI absolute + 4 VS-tier forward deps + public API)
- §Acceptance Criteria ✅ (50 ACs across 13 groups — 42 BLOCKING Logic/Integration + 8 ADVISORY)
- §Open Questions ✅ (12 OQs — 4 BLOCKING pre-impl, 12 coord items, 9 deferred)

### Specialist consultations (all section-mandatory per skill)

- **creative-director** (§B): Candidate B fantasy framing selected, Paris-canonical rewrite applied
- **game-designer** (§C.1): 15 CR proposal synthesized into final 20 CRs
- **level-designer** (§C.5): Section Authoring Contract — 6 subsections structured
- **systems-designer** (§C.2-C.3 state machines + §C.7 Interactions + §D formulas + §E 36 edge cases)
- **narrative-director** (§C.4 taxonomy + §C.6 per-section beats + Pillar-1 enforcement)
- **gameplay-programmer** (§C Godot 4.6 feasibility: autoload vs per-section, Area3D triggers, SaveGame assembly, MissionObjective as Resource, ADR-0008 sub-slot claim)
- **qa-lead** (§H): 50 ACs authored with story-type tags

### User-approved design decisions via AskUserQuestion

1. **Scripted-beat re-fire policy**: savepoint-persistent (do NOT re-fire on RESPAWN) — matches NOLF1 + simpler state
2. **SUPERSEDED objective transition**: implicit (no 5th Mission-domain signal) — keeps ADR-0002 at 4 signals
3. **WorldItem cache placement ownership**: MLS GDD owns policy + Level Designer executes
4. **LOAD_FROM_SAVE re-emit**: suppress `objective_started`; HUD rebuilds from snapshot via `get_active_objectives()`
5. **Q1 F.3 COMBAT T6 suppression**: fully suppressed at COMBAT (no budget tracked)
6. **Q2 F.4 overflow**: push_error + proceed (don't lose save); ADR-0008 amendment flagged as follow-up
7. **Q3 F.5 cascade abort**: partial-supersede (depths 1-3 stand; no rollback)
8. **Q4 F.6 off-path distance**: authoring guideline + playtest (no CI-derived centerline at MVP)

### Registry Phase 5b (14 NEW entries written to `design/registry/entities.yaml`)

- **5 cross-system Resource types**: `MissionResource`, `MissionObjective`, `MissionState`, `MLSTrigger`, `MissionScriptingService` autoload
- **9 constants**: `alert_comedy_budget` (2), `SUPERSEDE_CASCADE_MAX` (3), `off_path_min_distance_m` (10.0), `pistol_per_section_max` (3), `pistol_per_2_section_min` (1), `dart_min_sections_span` (2 fixed), `medkit_per_section_max` (1), `t_capture_i_budget_ms` (1.0), `t_assemble_total_ceiling_ms` (5.0)
- MLS formulas F.1/F.2/F.5/F.7 are MLS-internal predicates — NOT registered per registry README rule ("only register facts that cross system boundaries")
- **No existing-entry `referenced_by` updates needed** (WorldItem, Checkpoint, FailureRespawnState, fr_checkpoint_marker_node_name, phantom_guard all already list MLS)

### F&R BLOCKING coord item #11 CLOSED by MLS sign-off

F&R's pre-impl gate "Mission Scripting PROVISIONAL — `player_respawn_point: Marker3D` authoring + non-deferred + section-validation CI" is **satisfied** by:
- CR-9 (mandatory Marker3D per section scene)
- §C.5.1 (required nodes table)
- §C.5.6 (CI validation rules — BLOCKING)

### Pre-implementation coord items open (12)

1. ADR-0007 amendment naming MLS at slot #9 (bundle with F&R's slot-#8 amendment)
2. ADR-0003 + save-load.md schema for `MissionState` sub-resource (OQ-MLS-2 BLOCKING — F&R `triggers_fired` capture)
3. ADR-0008 §Pooled Residual sub-slot claim
4. Signal Bus GDD L122 handler-table touch-up (6 MLS subscriber rows)
5. Inventory GDD §F bidirectional MLS-owns-placement note
6. F&R coord item #11 closure (on MLS approval)
7. LSS GDD §Interactions `register_restore_callback` row
8. Localization Scaffold review gate
9. Section-validation CI implementation (Tools Programmer)
10. MLSTrigger self-passivity contract (OQ-MLS-6)
11. Cutscenes & Mission Cards (VS) forward API verification
12. Audio GDD §Mission-domain amendment (LOAD suppression + T4 Fire-Drill Klaxon spec + T6 Alert-Comedy bark bank)

### 12 Open Questions captured in §Open Questions

- **BLOCKING pre-impl (4)**: OQ-MLS-2 (triggers_fired capture), OQ-MLS-3 (_is_section_live guard), OQ-MLS-6 (MLSTrigger self-passivity), OQ-MLS-9 (FP-8 grep vs manual)
- **Deferred / post-MVP (8)**: OQ-MLS-1 (LD authoring constraint), -4 (SectionBoundsHint CI), -5 (LD guide narrative-critical distinction), -7 (reachability validator), -8 (mission_load_failed signal), -10 (mission-completed handoff), -11 (Restaurant sub-room scope), -12 (triggers_fired Array vs Dict), -ANIM-1 (Biscuit Tin animation budget)

### Files modified this session

- `design/gdd/mission-level-scripting.md` — **NEW** (834 lines)
- `design/registry/entities.yaml` — 14 new entries appended; `last_updated` comment updated
- `design/gdd/systems-index.md` — row 13 Status updated to Designed; Progress Tracker counts updated (Started 12→13, Approved 7 unchanged + 1 new Designed-pending-review, MVP designed 12→13/16); Last Updated header updated
- `production/session-state/active.md` — this file

## Previous Task — `/design-review failure-respawn.md` **COMPLETE 2026-04-24**

### Forward coord items MLS must close (pre-impl gates from prior GDDs)

1. **F&R BLOCKING item #11** — `player_respawn_point: Marker3D` section-authoring contract + non-deferred + section-validation CI
2. **Inventory forward-hook** — WorldItem cache plan (8 pistol + 2 dart-off-path + medkit-cap 3/mission + rifle-carrier 1/section); mission-gadget satchel (Parfum) in Eiffel restaurant
3. **ADR-0007 amendment** — MLS autoload registration at slot #9 (after F&R at slot #8; originally reserved for Civilian AI / MLS / Document Collection shared; F&R claimed #8 first)
4. **ADR-0008 sub-slot claim** — MLS claims share of 0.8 ms residual pool (6 systems)
5. **Cutscenes & Mission Cards forward API** — define trigger contract MLS will expose (VS tier consumer)

### Locked upstream contracts (non-negotiable)

- **ADR-2 Mission domain signals**: `mission_started/completed`, `objective_started/completed` (MLS-owned emit)
- **ADR-2 subscriber**: `section_entered(reason: TransitionReason)` — MLS gates autosave on FORWARD only
- **ADR-3 SaveGame assembler**: MLS builds SaveGame by reading each system's `capture()`; synchronous only
- **architecture.md L639**: RESPAWN must NOT autosave (would overwrite good state with dead state)

### Specialist consultations planned

- **Section B**: creative-director (mandatory per skill)
- **Section C**: game-designer + level-designer + systems-designer + narrative-director (scripting = Pillar 1 load-bearing)
- **Section D**: systems-designer
- **Section E**: systems-designer + narrative-director
- **Section H**: qa-lead (mandatory per skill)
- **Visual/Audio**: art-director + audio-director (mandatory for narrative category)

## Previous Task — `/design-review failure-respawn.md` **COMPLETE 2026-04-24**

- **Task**: `/design-review design/gdd/failure-respawn.md` with 7-specialist + CD full-mode synthesis
- **File**: `design/gdd/failure-respawn.md` (513 → 553 lines)
- **Verdict**: MAJOR REVISION NEEDED → inline revision applied in same session → user elected Accept + mark Approved pending coord items (CD recommendation to re-review in fresh session overridden by user)
- **New file**: `design/gdd/reviews/failure-respawn-review-log.md` (full review log created)
- **Systems-index**: row 14 Status → "Approved pending Coord items 2026-04-24"; Progress Tracker counts updated (Approved 6 → 7; MVP designed 7 Approved/Approved-pending-coord + 5 pending re-review)

### Specialists consulted

- game-designer (B-1..B-7): Pillar 3 fantasy mismatch with 2.0 s fade; anti-farm vs softlock; missing mission-fail trigger; Restart-from-Checkpoint absence; kill-plane coverage gap
- systems-designer (S-1..S-8): **FLAG SPLIT-BRAIN (S-4)** — diagnostic finding; F.1 non-exhaustive; F.2 correlated variables; queued-respawn N unbounded; States table contradiction; idempotency window; E.20 mis-labeled; schema forward-compat
- godot-specialist (E-1..E-9): **E-1 SaveLoad internal await fence needed**; E-5 Jolt non-determinism in AC-FR-2.1; E-6 stale Callable hot-reload crash; E-8 dart body_exited VERIFY; E-9 FailureRespawnState _init() missing
- gameplay-programmer (G-1..G-8): Independent confirmation of S-4 split-brain; RESTORING contradiction; CR-11 lookup method unspecified; DI hook missing; register_restore_callback survivability; queued-respawn overwrite (G-7); Checkpoint class ownership
- qa-lead (Q-1..Q-17): **7 BLOCKING AC issues + 10 RECOMMENDED**; missing sole-publisher AC (Q-13)
- performance-analyst (P-1..P-7): **P-3 ADR-0001 storage tier undeclared — ESCALATED TO TD**; F.2 best-case arithmetic; correlated I/O; N=2 by fiat; 1.62 s post-resume fade
- audio-director (A-1..A-7): **A-1 sting vs silence policy undefined**; A-3 queued-respawn single-emit unconfirmed; A-5 200 ms below perceptual beat threshold; A-6 permanent-silence failure mode
- creative-director senior synthesis: MAJOR REVISION NEEDED; 2 structural defects (flag split-brain, States-table contradiction); 5 live cross-GDD contradictions; adjudicated B-1/A-5 (Audio amendment needed) + S-8 (accept flat bool); ruled sting-suppression on respawn path; strongly recommended `/clear` + fresh-session re-review protocol

### User-approved revisions applied (via 4-tab AskUserQuestion adjudication)

- **Q1 Flag split-brain**: live-authoritative (F&R autoload holds `_floor_applied_this_checkpoint: bool` as authoritative; save mirrors live via `FailureRespawnState.capture(live_value)`; reads at step 9 from live only; live advances synchronously after Inventory returns)
- **Q2 RESTORING rules**: allow dispatch-only; block state-mutating section_entered branches via `_flow_state == IDLE` guard in CR-7
- **Q3 Cross-GDD scope**: coord items only; edit failure-respawn.md only in this session per CLAUDE.md collaborative principle
- **Q4 Audio handshake**: full CD ruling — sting suppression + silence retune 0.2→0.4 s + fade retune 2.0→1.2 s as Audio GDD amendment coord items

### Edits applied to failure-respawn.md (15+ edits, 513 → 553 lines)

- CR-5/CR-6 rewritten for live-authoritative + Resource `_init()` constructor + read/write contract + schema forward-compat note
- CR-7 rewritten with `_flow_state == IDLE` guard (resolves 2 structural defects simultaneously)
- CR-8 rewritten with sting-suppression + subscriber re-entrancy fence
- CR-10 rewritten with single-emit guarantee + 2.5 s debug watchdog
- CR-11 rewritten with `find_child(recursive=true, owned=false)` contract + shared Checkpoint location
- CR-12 step 9 annotated live-authoritative; step 4 annotated ADR-0003 await-forbid; step 12 reconciled with CR-7 guard
- States table rewritten with disambiguation note
- F.1 rewritten (7 transition rows from 4; default arm; hydrate + null-fallback rows)
- F.2 marked **PROVISIONAL** pending ADR-0001 storage-tier amendment; arithmetic corrected (0.15 → 0.167 s); SSD-cold vs HDD-cold rows separated; correlated-variable caveat; perceived-beat target 1.6 s
- E.20 rationale flipped to explicit permissive-on-corruption tradeoff
- 7 blocking ACs rewritten (1.1, 2.1, 3.1, 5.5, 6.2 BLOCKED, 10.1 hardware-pin, 10.2 → Playtest type)
- 2 new ACs: AC-FR-12.4 sole-publisher CI lint + AC-FR-12.5 re-entrancy CI lint
- BLOCKING items table grew 5 → 12
- Bidirectional consistency check expanded to flag 5 cross-GDD contradictions as coord items
- 9 new OQs (OQ-FR-7 BLOCKING storage-tier + OQ-FR-8 BLOCKING signal-isolation + 7 others)
- 3 new DGs (DG-FR-5/6/7)
- AC count 38 → 40

### Pre-implementation gates (OPEN — 12 items, up from 5)

1. ADR-0007 amendment (F&R autoload at line 8) — pre-existing
2. Inventory GDD coordination — rename `restore_weapon_ammo` → `apply_respawn_floor_if_needed`
3. Save/Load GDD + ADR-0003 (4 sub-items: schema + L100/L151 stale-text + internal-await forbid + atomic-commit fence)
4. Input GDD coordination — add `InputContext.LOADING` context (currently missing from input.md)
5. Signal Bus GDD touch-up — add F&R's section_entered subscription to L122 row
6. Audio GDD amendment — sting-suppression + retune silence/fade
7. **ADR-0001 amendment (ESCALATED TO TD)** — declare min-spec storage tier (SSD vs HDD)
8. LS GDD coordination — document replace-semantics on `register_restore_callback`
9. godot-specialist engine-verification gate — Godot 4.6 signal-isolation on subscriber unhandled exception
10. PC GDD null-checkpoint spec (OQ-FR-5) — pre-existing BLOCKING
11. Mission Scripting (PROVISIONAL) — `player_respawn_point: Marker3D` authoring + non-deferred contract + section-validation CI
12. Shared `Checkpoint` class location at `src/gameplay/shared/checkpoint.gd`

### Files modified this session

- `design/gdd/failure-respawn.md` — major revision (513 → 553 lines)
- `design/gdd/reviews/failure-respawn-review-log.md` — **NEW** (review log with full verdict, specialist findings, resolution summary)
- `design/gdd/systems-index.md` — row 14 Status + Progress Tracker updated
- `production/session-state/active.md` — **this file**

## Next steps (fresh session recommended)

1. **PRIMARY — `/design-system mission-level-scripting`** (system #13). User requested this as next action but skill was deferred due to context depth. Fresh session recommended because: (a) Mission Scripting is M-effort (2-3 sessions); (b) skill mandates specialist consultations per section; (c) starting from exhausted context risks the same drift CD just flagged on F&R. System #13 depends on Stealth AI ✅, Combat ✅, Level Streaming ✅, Save/Load ✅, Signal Bus ✅ — fully unblocked.

2. **Alternative — `/design-review` on a pending GDD** in fresh session. Six GDDs carry "Designed (pending review)" or "Revised (pending re-review)" status:
   - `design/gdd/save-load.md` (most F&R-coupled; L100/L151 stale-text contradiction + schema touch-up surface here)
   - `design/gdd/signal-bus.md`, `design/gdd/input.md`, `design/gdd/outline-pipeline.md`, `design/gdd/post-process-stack.md`, `design/gdd/localization-scaffold.md`

3. **Alternative — close F&R BLOCKING coord items** in a dedicated session. Save/Load + Input + Signal Bus text touch-ups are quick wins; ADR-0001 storage-tier amendment needs TD consultation; Audio GDD amendment needs audio-director consultation.

4. **Alternative — `/architecture-decision adr-0001-amendment`** — declare min-spec storage tier so F.2 + AC-FR-10.x can finalize.

5. **Alternative — `/consistency-check`** — re-run post-F&R-revision to catch new drift (revision added 40 lines, introduced new coord items + schema references).

## Gate-check recommendation

Still not PASS-eligible for `/gate-check pre-production`. Outstanding:
- [ ] 12 F&R BLOCKING coord items (including TD-escalated ADR-0001)
- [ ] `/design-review` on 6 pending-review GDDs (or accept-pending-coord as project pattern)
- [ ] 26 verification gates (ADR Proposed → Accepted)
- [ ] 11 outstanding MVP GDDs (12/23 designed after F&R landed Approved-pending-coord)

## Preserved — prior task history

Prior session state extracts (F&R `/design-system` authoring 2026-04-24 earlier; Inventory `/design-system` + `/design-review` + `/architecture-review` 5th-run 2026-04-24; ADR-0007 amendment 2026-04-23; `/create-architecture` 2026-04-23; etc.) are recorded in git history of this file and in referenced docs. Architecture review verdict remains PASS (5th-run 2026-04-24).

## Session Extract — /review-all-gdds 2026-04-27
- Verdict: FAIL
- GDDs reviewed: 21
- Flagged for revision: signal-bus, input, audio, save-load, inventory-gadgets, combat-damage, hud-core, menu-system, settings-accessibility, failure-respawn, mission-level-scripting, document-overlay-ui (12 blocking) + ADR-0003, ADR-0007 (architecture); player-character, document-collection, civilian-ai, localization-scaffold, stealth-ai (warning-tier, not flagged in index)
- Blocking issues: 13 — B1 signal-count drift / B2 ADR-0007 slot conflict / B3 HUD crosshair category / B4 menu Context.MODAL / B5 fade layer 1024 / B6 audio filter / B7 layer 10 collision / B8 fired_beats schema / B9 ammo schema / GD-B1 P4 thin / GD-B2 attention budget / GD-B3 Pre-Packed Bag / GD-B4 medkit budget; +S1-B HUD mid-flash / S2-B mid-combat overlay
- Recommended next: bundle ADR-0007 amendment (B2) + Signal Bus sweep (B1) + HUD/Audio category sweeps (B3/B6) + creative-director adjudication on GD-B1/GD-B3/GD-B4
- Report: design/gdd/gdd-cross-review-2026-04-27.md

## Session Extract — ADR-0007 amendment 2026-04-27 (post /review-all-gdds)
- Verdict: B2 RESOLVED. ADR-0007 amended: 7 → 10 autoloads.
- Slot order: ...Combat(7) → FailureRespawn(8) → MissionLevelScripting(9) → SettingsService(10)
- Adjudication: MLS-after-F&R is hard edge (MLS subscribes to respawn_triggered). Settings goes last (consumers use settings_loaded one-shot, not _ready() reads).
- Files modified:
  * docs/architecture/adr-0007-autoload-load-order-registry.md (Last Verified, Summary, Revision History 2026-04-27 entry, Constraints, Requirements, Canonical Registration Table 3 rows added, Rationale 3 bullets added, Key Interfaces block 3 lines added, Alternatives 2026-04-27 §, Consequences Positive bullet, Performance 7→10 nodes, Validation Gate 1 7→10 entries, GDD Requirements 3 rows added, Downstream sites 4 GDDs added, Related 4 entries added) — 344 → 402 lines
  * design/gdd/failure-respawn.md (3 sites swept to "per ADR-0007"; coord item #1 marked RESOLVED)
  * design/gdd/mission-level-scripting.md (5 sites swept; CR-17, ADR-0007 dep row, coord item #1, AC-MLS-12.1 rewritten; coord item #1 RESOLVED)
  * design/gdd/settings-accessibility.md (5 sites swept; CR-3 rewritten with Settings now at end-of-block not slot #8; AC-SA-8.6 reframed; coord BLOCKING #1 marked RESOLVED)
  * design/gdd/document-collection.md (6 sites stripped of "F&R = #8, MLS = #9" parenthetical per W7)
- Remaining blockers for re-flag-removal (NOT addressed in this amendment):
  * MLS: B8 fired_beats schema → save-load.md + ADR-0003 (separate amendment)
  * Settings: B7 layer 10 mutex annotation; W8 cooldown name harmonization
  * F&R: W6 FailureRespawnState in SaveGame schema (warning only)
  * Outside this amendment: B1 signal-count drift, B3 HUD crosshair category, B4 Context.MODAL, B5 fade layer, B6 audio filter, B9 ammo schema, GD-B1..B4
- Recommended next: ADR-0003 amendment (B8 + B9 + W6 — single bundled save-format amendment); then signal-bus.md sweep (B1) + audio.md filter fix (B6) + hud-core.md crosshair category sweep (B3); then creative-director adjudication on GD-B1/GD-B3/GD-B4

## Session Extract — ADR-0003 amendment A4 2026-04-27 (post /review-all-gdds)
- Verdict: B8 + B9 + W6 RESOLVED. ADR-0003 schema grown — SaveGame holds 7 typed sub-resources (was 6); InventoryState ammo split; MissionState gains fired_beats. FORMAT_VERSION 1 → 2.
- Files modified:
  * docs/architecture/adr-0003-save-format-contract.md — Last Verified date, Summary "7 sub-resources", new Revision History 2026-04-27 entry, SaveGame `@export` block (added `failure_respawn: FailureRespawnState`), FORMAT_VERSION 1→2 with rationale comment, GDD Requirements rows for Inventory + MLS revised + new F&R row, Related entries 4 added — 374 → 400 lines
  * design/gdd/save-load.md — MissionState row gains fired_beats; F&R row gains FailureRespawnState
- F&R coord item #1 (FailureRespawnState in SaveGame schema) CLOSED.
- MLS B8 (fired_beats schema) CLOSED.
- Inventory B9 (ammo schema) CLOSED.
- Status flags unchanged in systems-index — F&R still has 0 remaining blockers (only W6 was on F&R's flag list, now closed → F&R can be unflagged); MLS still has B2 (closed earlier) + B8 (now closed) → MLS could be unflagged BUT may have other coord-pending items not part of this review; leaving Needs Revision until full sweep run.
- Cumulative coord landed today (2026-04-27): ADR-0007 amendment (B2) + ADR-0003 amendment A4 (B8 + B9 + W6). Remaining blockers: B1 signal-count drift, B3 HUD crosshair category, B4 Context.MODAL/LOADING enum, B5 fade layer 1024 → 127, B6 audio filter category, B7 layer 10 mutex annotation; GD-B1..B4 design-theory; S1-B + S2-B scenarios.
- Recommended next: Signal Bus sweep (B1 — 4 line edits, simplest), then audio.md filter fix (B6), then HUD Core crosshair category sweep (B3 — 8 sites). After these 3 sweeps: ~half of remaining consistency blockers closed in <30 min of mechanical edits.

## Session Extract — B1 + B6 + B3 sweeps 2026-04-27 (post /review-all-gdds)
- B1 RESOLVED — signal-bus.md sweep: 6 sites updated (lines 17, 40, 48, 137, 165, 179, 220) — 32/34/36 → 38; revision-history parenthetical extended to include 2026-04-24 Inventory amendment.
- B6 RESOLVED — audio.md line 377 filter rule rewritten to allow `audio` OR `accessibility` category (key-allowlist within both); pre-sweep filter would have silently dropped `accessibility.clock_tick_enabled` events Audio claims to consume at line 237.
- B3 RESOLVED — hud-core.md crosshair/damage_flash category sweep: 12 sites total updated (8 `setting_changed("hud", ...)` + 4 `Settings.get_setting("hud", ...)` accessor calls) → all moved to `accessibility` category per Settings CR-2 single-canonical-home rule. Zero `("hud", "crosshair_enabled"|"damage_flash_enabled")` references remain.
- Cumulative coord landed today (2026-04-27): ADR-0007 amendment (B2) + ADR-0003 amendment A4 (B8 + B9 + W6) + signal-bus sweep (B1) + audio filter (B6) + HUD category sweep (B3). Six blockers closed.
- Remaining blockers: B4 menu Context.MODAL/LOADING (input.md addition), B5 menu fade layer 1024→127, B7 ADR-0004 §IG7 layer-10 mutex annotation; GD-B1..B4 design adjudication (CD); S1-B + S2-B scenarios (depend on HUD Core mid-flash + Doc Overlay during combat — partially addressed by B3 sweep).
- Recommended next: B5 (1-line edit in menu-system.md) + B4 (input.md adds Context.MODAL to pending-amendment list — single line). Both trivial mechanical sweeps.

## Session Extract — B4 + B5 + B7 sweeps 2026-04-27 (post /review-all-gdds — closes all remaining mechanical blockers)
- B4 RESOLVED — input.md §Pre-implementation gates item #1: amendment list expanded from `LOADING` only to `LOADING + MODAL` bundled amendment (one PR per ADR-0004 atomic-context-addition pattern). Menu System's free use of `Context.MODAL` at L55/L117–120/L910 now formally registered as a pending ADR-0004 enum addition.
- B5 RESOLVED — menu-system.md FP-9 footnote at L1335: stale `screen_fade_layer = 1024` corrected to `CanvasLayer.layer = 127` per level-streaming.md CR-1 (Godot 4.x signed 8-bit `CanvasLayer.layer` ceiling — `128` overflows). Note: lines 183 + 1144 + 1145 already cited 127 correctly; only the FP-9 footnote was stale.
- B7 RESOLVED — ADR-0004 §IG7 layer-10 annotation: layer 10 is now formally documented as shared between Settings panel (InputContext.SETTINGS) and Cutscenes letterbox (cutscene context, GDD #22 pending), with explicit InputContext mutual-exclusion gate explanation. Closes Menu System OQ-MENU-15 simultaneously. Implementation rule added: per-surface CanvasLayer instanced lazily so both surfaces never have a node at layer 10 simultaneously even if gate is bypassed.
- Cumulative coord landed today (2026-04-27): ADR-0007 amendment (B2) + ADR-0003 amendment A4 (B8 + B9 + W6) + signal-bus sweep (B1) + audio filter (B6) + HUD category sweep (B3) + input MODAL addition (B4) + menu fade layer fix (B5) + ADR-0004 layer-10 mutex (B7). **All 9 consistency blockers closed in a single day.**
- Remaining blockers: GD-B1..B4 design adjudication (creative-director call required); S1-B + S2-B scenarios (need spec follow-up).
- Recommended next: creative-director adjudication session on GD-B1 (Pillar 4 matrix) + GD-B3 (Pre-Packed Bag) + GD-B4 (medkit budget) + GD-B2 (Plaza attention budget). Or pause and re-run /review-all-gdds to verify all 9 consistency blockers actually clear in fresh assessment.

## Session Extract — /review-all-gdds 2026-04-28

- Verdict: CONCERNS
- GDDs reviewed: 21 (all active system GDDs; v0.3-frozen excluded)
- Flagged for revision: civilian-ai.md, document-collection.md (flipped Approved → Needs Revision); status of menu-system, inventory-gadgets, hud-core, signal-bus, combat-damage, failure-respawn, mission-level-scripting, audio, save-load, stealth-ai (P4 §Pillars edit only) already Needs Revision or noted in report
- Blocking issues: 9 — (1) menu-system.md ~10 stale autoload-slot sites + AC-MENU-1.1 conflict; (2) ADR-0002 §Decision/Migration "36/34" vs "38" sweep; (3) ADR-0004 InputContext enum missing MODAL+LOADING (B4 carryforward unresolved); (4) inventory-gadgets.md SaveLoad↔LSS callback self-contradiction; (5) Document Overlay UI Slot-7 sole-occupant claim depends on uncodified HUD Tween cleanup; (6) ADR-0008 Slot-8 panic-onset frame busts cap by GDD's own math; (7) Health scarcity death-spiral risk in late mission (GD-B4 carryforward); (8) Fist-swing noise event undefined → cost-free dominant non-lethal strategy; (9) Pillar 4 primary coverage at 2 systems only (GD-B1 carryforward gap unfilled)
- Required ADR amendments (out of GDD scope): ADR-0002 (signal count + add settings_loaded + ui_context_changed), ADR-0004 (MODAL + LOADING enum), ADR-0008 (Slot-8 reserve + 10-autoload cascade row)
- Required design decisions: medkit budget (game-designer + CD), MELEE_FIST noise radius (systems-designer + game-designer), headshot-economy cap-or-accept, Crouch-vs-Walk balance, Menu-as-case-officer dual-POV, ADR-0003 additive-field rule, CAI vs LSS callback registration pattern
- Recommended next: open ADR-0002/0004/0008 amendments first (unblocks 5 of 9 blockers); then sweep menu-system + inventory-gadgets + DC + CAI; then game-designer + CD design-decision session for medkit budget + fist-noise + remaining open questions; OR `/design-review` on civilian-ai.md and document-collection.md before sweep
- Report: design/gdd/gdd-cross-review-2026-04-28.md
- Systems-index changes: row 15 (Civilian AI) flipped to Needs Revision; row 17 (Document Collection) flipped to Needs Revision; Last Updated header refreshed

## Session Extract — ADR amendments 2026-04-28 (post-/review-all-gdds)

- **ADR-0002 amendment APPLIED 2026-04-28**: signal count 38 → 40; new `settings_loaded()` (Settings domain) + `ui_context_changed(new: InputContext.Context, old: InputContext.Context)` (NEW UI domain); enum-ownership list grows by `InputContext.Context` (owned by `InputContextStack` per ADR-0004); revision-history entry added; Risks row added for atomic-commit of `InputContext.Context` enum + `events.gd` declaration. Closes W4 carryforward (`settings_loaded` from Settings CR-9) + HUD-Overlay coordination gap (`ui_context_changed` from HUD CR-10). signal-bus.md swept: count 38 → 40, domain table grows by UI row + Settings row gains `settings_loaded`, AC-3 count 38 → 40, consumer matrix grows by UI column with HUD/Audio/Cutscenes/Subtitles/Combat (settings) subscriptions, +Outline Pipeline row.
- **ADR-0004 amendment APPLIED 2026-04-28**: `InputContext.Context` enum extended with `MODAL` and `LOADING` values; push/pop authority table added as Implementation Guideline 13 (closes B4 carryforward); Architecture diagram + Key Interfaces enum + push/pop method bodies updated to emit `Events.ui_context_changed(new, old)` automatically on every push and pop; downstream sweep flagged for `input.md` / `menu-system.md` / `failure-respawn.md` / `level-streaming.md` to drop "ADR-0004 amendment PRE-IMPL GATE" qualifiers once committed atomically with ADR-0002.
- **ADR-0008 amendment APPLIED 2026-04-28**: Slot-8 panic-onset reserve carve-out registered in §Risks (up to 0.6 ms of 1.6 ms global reserve pre-allocated for single-frame `civilian_panicked` emission ≥ 4 within one physics frame; producer + TD sign-off required per CAI §C.0); autoload-cascade row count 7 → 10 reflecting ADR-0007's current canonical table; Slot 8 sub-claims explicitly enumerated in §Negative (CAI 0.30 ms p95 + MLS 0.1 + DC 0.05 ≈ 0.45 ms steady-state, informative); §ADR Dependencies row updated to "10 autoloads"; Revision History entry added; Last Verified updated.
- **Files modified this session (ADR amendments only)**: docs/architecture/adr-0002-signal-bus-event-taxonomy.md / docs/architecture/adr-0004-ui-framework.md / docs/architecture/adr-0008-performance-budget-distribution.md / design/gdd/signal-bus.md / production/session-state/active.md (this file).
- **Remaining BLOCKING items from /review-all-gdds 2026-04-28** (post-amendment): (1) menu-system.md ~10 stale autoload-slot sites + AC-MENU-1.1 sweep; (2) inventory-gadgets.md SaveLoad↔LSS callback self-contradiction (lines 508 + 874); (3) Document Overlay UI Slot-7 sole-occupant claim — HUD Tween cleanup CR; (4) Health scarcity death-spiral (GD-B4 carryforward — design decision); (5) Fist-swing noise event undefined (Combat CR-7 design decision); (6) Pillar 4 primary coverage at 2 (GD-B1 carryforward — SAI claims P4 supporting + matrix update). 3 of 9 blockers closed by ADR amendments (B4 enum / W4 settings_loaded / Slot-8 panic-onset).
- **Recommended next**: sweep work (menu-system, inventory-gadgets, DC's 6 stale "CAI 0.15" enumerations, civilian-ai.md tuning row to 0.30) — these are pure mechanical edits; OR `/design-review civilian-ai.md` and `/design-review document-collection.md` to re-validate the now-flipped Approved → Needs Revision GDDs; OR creative-director + game-designer adjudication session for the 3 design-decision blockers (medkit budget + fist noise + Pillar 4 SAI claim). Atomic-commit reminder: ADR-0002 + ADR-0004 amendments must land in a single PR with HUD CR-10 sweep + Settings CR-9 sweep + DC OQ-DC-7 sweep + `events.gd` source — partial PR causes GDScript parse failure on autoload load.

## Session Extract — Sweep + design decisions 2026-04-28 (post-ADR amendments)

- **Bloque A — Mechanical sweeps APPLIED**:
  - `inventory-gadgets.md`: L508 + L874 `SaveLoad.register_restore_callback` → `LevelStreamingService.register_restore_callback(_on_restore_from_save)` per LS CR-2 (closes review finding 2a-1 BLOCKING); L14 stale "ADR-0007 caps the autoload registry at 7 entries" → "per ADR-0007".
  - `hud-core.md`: L319 stale "caps autoloads at 7" → "per ADR-0007"; L587 stale `setting_changed("hud", _, _)` → `setting_changed("accessibility", _, _)` per Settings CR-2 single canonical home; NEW **CR-22** added (Tween.kill() on every active widget tween when `ui_context_changed` leaves GAMEPLAY — closes Document Overlay UI OQ-DOV-COORD-14 + AC-DOV-9.2 Slot-7 sole-occupant precondition).
  - `menu-system.md`: 6 sites swept for stale autoload-slot numbering (L72 + L136 + L150 boot diagram + L985 ADR-0007 dep row + L1015 dep table + L1057 coord items + L1070 numbered list + L1697 OQ-MENU-5) — all now reference ADR-0007 §Canonical Registration Table per IG7 instead of restating slot numbers; AC-MENU-1.1 rewritten from "8 autoload _ready calls" → "all autoload _ready calls per ADR-0007 (currently 10)" — closes review finding 2f-1 BLOCKING + 2b-2.
  - `civilian-ai.md`: 5 internal sites swept 0.15 ms → 0.30 ms p95 (L130 overview + L573 dep table + L591 coord item + L659 tuning knob row + L663 operational note) with cross-references to ADR-0008 2026-04-28 reserve carve-out for panic-onset frames.
  - `document-collection.md`: 4 stale "CAI 0.15 ms" enumerations → "CAI 0.30 ms p95 (revised 2026-04-25 from 0.15 ms; civilian-ai.md §F.3 + AC-CAI-7.1)".
- **Bloque B — Design decisions APPLIED**:
  - **GD-B4 medkit per-section guarantee**: option A applied (1 medkit guaranteed per section post-Plaza). MLS §C.5 CR-10 + §C.5.4 medkit pickups row + §C.5.6 CI-enforcement matrix + §G.3 tuning knob `medkit_per_section_min` Dictionary + §G.3 `medkit_per_section_max` raised 1 → 2 (Upper carries 2) + §G.5 `medkit_total` cap 3 → 7 (5 guaranteed: Plaza 0 / Lower 1 / Restaurant 1 / Upper 2 / Bomb 1 + 2 off-path bonus) + AC-MLS-7.3 rewritten with new placement constraints. inventory-gadgets.md status header annotated. CI lint added: each post-Plaza section MUST contain at least the specified count.
  - **Combat CR-7 fist-swing noise**: option B applied (2 m radius). Combat CR-7 expanded with NoiseEvent emission spec (`MELEE_FIST` type, 2 m radius, emitted at swing-windup-start, fed to SAI HearingPoller as STEALTH_NOISE-cause perception, NOT directly transitioning guards to COMBAT). New tuning knob `fist_swing_noise_radius_m = 2.0` with safe range [1.5, 3.5]. Closes the cost-free non-lethal dominant-strategy risk identified in cross-review. New coord items emerging: SAI §F.2b EVENT_WEIGHT table needs `MELEE_FIST` row (~5, Crouch-tier-ish); Audio §Concurrency 1-line clarification (NoiseEvent is SAI-internal, not Audio-routed).
- **All 9 BLOCKING items from `/review-all-gdds` 2026-04-28 now CLOSED or in PARTIAL closure** (ADR-0008 reserve allocation needs producer + TD sign-off to actually invoke per civilian-ai.md §C.0 — that's a producer-tracked operational gate, not a documentation gate).
- **Files modified this session (sweeps + design decisions)**: design/gdd/inventory-gadgets.md / design/gdd/hud-core.md / design/gdd/menu-system.md / design/gdd/civilian-ai.md / design/gdd/document-collection.md / design/gdd/stealth-ai.md / design/gdd/systems-index.md / design/gdd/mission-level-scripting.md / design/gdd/combat-damage.md / production/session-state/active.md (this file).
- **Project state post-sweeps**: 9 of 9 review-blocking items CLOSED; 13 WARNINGS still open (most are the 3 ADR amendments now landed — close after `events.gd` source PR + the secondary sweeps that those ADRs flagged downstream); 3 design decisions made (medkit + fist noise + Pillar 4 SAI claim). Remaining open work to start programming: `/create-architecture` master synthesis → `/create-control-manifest` → `/create-epics` → `/create-stories` → `/test-setup` → `/sprint-plan` → `/dev-story`.
- **Stealth AI prototype status (clarified 2026-04-28)**: an early prototype exists in git history (commits `13fa961` / `8f30352` / `38e83e4`) but was deleted by user. Treat the gating-risk validation as **not yet performed**; `/prototype stealth-ai` is no longer the recommended next step (user has chosen to skip the throwaway prototype path and proceed via the formal architecture route). Risk acknowledged: SAI in Godot 4.6 with graduated suspicion is the longest pole per game-concept.md §Technical Risks; if the architecture-first path stalls on SAI implementation later, fall back to a focused SAI sprint with explicit go/no-go gate at end of sprint 1.
