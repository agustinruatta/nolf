# Architecture Traceability Index

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-04-29 (seventh run — post-`/review-all-gdds` 2026-04-28 + 11 new MVP/VS GDDs + 4 ADR amendments) |
| **Engine** | Godot 4.6 |
| **Populated by** | `/architecture-review` (full mode) |

---

## Coverage Summary

| | Count | % |
|---|-------|---|
| Total TRs registered | **348** | 100% |
| ✅ Covered (ADR-addressed) | ~344 | ~99% |
| ⚠️ Partial (ADR coverage exists but some details live GDD-only by design) | ~3 | ~1% |
| ❌ Gap (no ADR addresses) | **0** | — |

*The ~ figures reflect that coverage is reported at system-level granularity; individual TR-level coverage may shift slightly when stories are authored. The ⚠️ Partials are intentional GDD-scope decisions (Audio internals, Post-Process Stack internals, Input GDD-scope action catalog) — not architectural gaps. **2026-04-29 delta**: +173 new TRs across 11 systems (TR-MLS-* / TR-FR-* / TR-CAI-* / TR-DC-* / TR-HUD-* / TR-HSS-* / TR-DOU-* / TR-MENU-* / TR-DLG-* / TR-CMC-* / TR-SET-*); all mapped to existing ADRs + 4 ADR amendments (ADR-0002 ×3 / ADR-0003 A4 / ADR-0004 A5+A6 / ADR-0007 / ADR-0008). Engine-verification gates from 5th-run inherited; new Gate 5 (BBCode→AccessKit plain-text) added for Document Overlay UI.*

---

## Full Matrix

System → ADR coverage with per-TR detail. Systems with hard GAPs are expanded; systems with full coverage are summarised at the system level.

### System 1 — Signal Bus (TR-SB-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-SB-001 — Signal Bus as sole cross-system dispatch | ADR-0002 | ✅ |
| TR-SB-002 — 36-signal taxonomy | ADR-0002 | ✅ (amendment landed 2026-04-22; verified 2026-04-23) |
| TR-SB-003 — Autoload ordering Events=1, EventLogger=2 | ADR-0002, ADR-0007 | ✅ |
| TR-SB-004 — Events.gd contains only signal declarations | ADR-0002 | ✅ |
| TR-SB-005 — Subscriber _ready / _exit_tree lifecycle | ADR-0002 | ✅ |
| TR-SB-006 — is_instance_valid() on Node-typed payloads | ADR-0002 | ✅ |
| TR-SB-007 — Enum ownership on publishing class, not Events.gd | ADR-0002 | ✅ |
| TR-SB-008 — Five forbidden patterns | ADR-0002 | ✅ |
| TR-SB-009 — EventLogger debug self-removal | ADR-0002 | ✅ |
| TR-SB-010 — SAI→Combat Accessor Conventions carve-out | ADR-0002 | ✅ |

### System 2 — Input (TR-INP-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-INP-001 — Named InputMap actions, no raw KEY_* | ADR-0004 (by-pattern) | ✅ |
| TR-INP-002 — 29 actions via InputActions StringName constants | (GDD-scope) | ⚠️ Not ADR-locked (acceptable) |
| TR-INP-003 — Input.get_vector vs press/hold routing | (GDD-scope) | ✅ (implementation detail) |
| TR-INP-004 — InputContext gating via _unhandled_input | ADR-0004 | ✅ |
| TR-INP-005 — ui_cancel / interact / pause action bindings | ADR-0004 | ✅ |
| TR-INP-006 — Rebinding persists to settings.cfg | ADR-0003 | ✅ |
| TR-INP-007 — Modal dismiss via _unhandled_input + ui_cancel | ADR-0004 | ✅ |
| TR-INP-008 — get_viewport().set_input_as_handled() after consume | ADR-0004 | ✅ |
| TR-INP-009 — Gamepad partial at MVP | (GDD-scope) | ✅ |
| TR-INP-010 — InputContext.LOADING context | ADR-0004 (defines context enum) | ⚠️ Partial — LS-Gate-2 adds LOADING value; pending Input GDD amendment |

**Additional note**: Combat GDD CR-3 introduces a dedicated `takedown` input action. This is NOT yet in the Input GDD's 29-action catalog. A small Input GDD touch-up is needed (downstream coordination, not an ADR gap). Flag tracked in the review report.

### System 3 — Audio (TR-AUD-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-AUD-001 — Subscriber-only (30 signals) | ADR-0002 | ✅ |
| TR-AUD-002 — Five named buses | (GDD-scope) | ⚠️ Not ADR-locked (acceptable — audio pipeline is Audio GDD scope) |
| TR-AUD-003 — AudioManager as persistent-root Node (not autoload) | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-004 — Two music layers + sting architecture | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-005 — Music state grid | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-006 — Crossfade-only music transitions | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-007 — 16-voice spatial SFX pool | **ADR-0008 Slot #6** (dispatch cost) + GDD-scope (pool size) | ✅ (dispatch-budget line locked; pool size remains GDD-scope) |
| TR-AUD-008 — Section music preload at section_entered | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-009 — Per-section reverb swap | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-010 — Dominant-guard dictionary | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-011 — Stinger debounce + SCRIPTED suppression | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-AUD-012 — Takedown SFX routing by takedown_type | ADR-0002 (signature) | ✅ |

**System status**: ✅ Signal-contract side fully covered by ADR-0002. Frame-dispatch cost covered by ADR-0008 Slot #6 (0.3 ms). Audio architecture internals (buses, music state machine) intentionally GDD-scope.

### System 4 — Outline Pipeline (TR-OUT-*)

All 10 TRs: ✅ Covered by ADR-0001 (stencil contract) + ADR-0005 (hands exception) + **ADR-0008 Slot #3** (outline ≤2.0 ms aggregate cap, combined with sepia 0.5 ms). Outline shader algorithm (Sobel vs Laplacian, edge_threshold tuning) deferred to a future ADR — explicitly acknowledged.

### System 5 — Post-Process Stack (TR-PP-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-PP-001 — Chain order | (GDD-scope) | ⚠️ Partial |
| TR-PP-002 — Sepia Dim lifecycle via enable/disable API | ADR-0004 | ✅ |
| TR-PP-003 — Sepia parameters 30%/25%/warm amber | (GDD-scope) | ⚠️ Not ADR-locked |
| TR-PP-004 — Glow disabled project-wide | Art Bible 8J / GDD-scope | ⚠️ Not ADR-locked |
| TR-PP-005 — Forbidden effects (bloom, CA, SSR, etc.) | Pillar 5 / GDD-scope | ✅ (Pillar-level) |
| TR-PP-006 — Tonemap neutral linear | (GDD-scope) | ⚠️ |
| TR-PP-007 — PostProcessStack autoload + API | ADR-0004, ADR-0007 (line 6) | ✅ |
| TR-PP-008 — Resolution scale via Viewport.scaling_3d_scale + settings.cfg | ADR-0003 (persistence) + GDD-scope | ⚠️ Partial |
| TR-PP-009 — Performance budget (chain ≤2.5 ms Iris Xe) | **ADR-0008 Slot #3** | ✅ |
| TR-PP-010 — Only Settings writes resolution_scale | (GDD-scope anti-pattern) | ✅ |

**System status**: ✅ API lifecycle ADR-locked; autoload position ADR-locked; perf budget ADR-locked. Rendering details remain GDD-scope (intentional).

### System 6 — Save / Load (TR-SAV-*)

All 15 TRs: ✅ Covered by ADR-0003 (format, atomicity, versioning, metadata, actor_id, duplicate_deep, settings separation) + ADR-0002 (Persistence signals) + ADR-0007 (autoload line 3) + **ADR-0008 non-frame budgets** (save ≤10 ms, load ≤2 ms). Specialist §5 Gate 3 scope-refinement (A3) applied: explicit `Dictionary[StringName, GuardRecord]` duplicate_deep isolation sub-gates.

### System 7 — Localization Scaffold (TR-LOC-*)

All 10 TRs: ✅ Covered. ADR-0004 mandates `tr()` usage + forbidden pattern; ADR-0003 owns the locale-preference location (settings.cfg, not SaveGame). Remaining details (CSV structure, plural forms, pseudolocalization) are scaffold-level.

### System 8 — Player Character (TR-PC-*)

All 20 TRs: ✅ Covered. Touches 6 ADRs:
- ADR-0001 (all non-hands meshes write stencil tiers)
- ADR-0002 (player signals: player_damaged, player_died, player_health_changed, player_interacted, player_footstep)
- ADR-0003 (PlayerState sub-resource schema)
- ADR-0005 (FPS hands exception — inverted-hull via material_overlay)
- ADR-0006 (Eve on LAYER_PLAYER; interact raycast on MASK_INTERACT_RAYCAST)
- **ADR-0008** (Slot #5 Player/FC/Combat non-GF 0.3 ms + Slot #4 Jolt physics 0.5 ms for move_and_slide engine cost)

### System 8b — FootstepComponent (TR-FC-*)

All 8 TRs: ✅ Covered. ADR-0002 (`player_footstep` signal), ADR-0006 (MASK_FOOTSTEP_SURFACE), **ADR-0008 Slot #5** (shared aggregate cap with PC + Combat non-GF). Surface metadata authoring contract resolved by Level Streaming CR-10 (cross-GDD handoff).

### System 9 — Level Streaming (TR-LS-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-LS-001 — Autoload; registration order | ADR-0002, ADR-0007 (line 5 canonical) | ✅ |
| TR-LS-002 — CanvasLayer 127 fade overlay | (GDD-scope) | ✅ |
| TR-LS-003 — Public API (transition/reload/register_restore_callback) | (GDD-scope) | ✅ |
| TR-LS-004 — SectionRegistry Resource | (GDD-scope) | ✅ |
| TR-LS-005 — 13-step fixed-sequence swap | (GDD-scope) | ✅ |
| TR-LS-006 — Queued-respawn during transition | (GDD-scope) | ✅ |
| TR-LS-007 — TransitionReason enum param on section_entered/exited | ADR-0002 (amended 2026-04-22 4th-pass) | ✅ |
| TR-LS-008 — Section scene authoring contract CR-9 | (GDD-scope) | ✅ |
| TR-LS-009 — InputContext.LOADING push/pop | ADR-0004 (context enum) | ⚠️ Partial — LOADING value pending Input GDD amendment |
| TR-LS-010 — CACHE_MODE_REUSE default | (GDD-scope) | ✅ |
| TR-LS-011 — ≤0.57 s p90 performance budget | **ADR-0008 non-frame budgets** | ✅ |
| TR-LS-012 — Persistent fade overlay parented to autoload | (GDD-scope) | ✅ |
| TR-LS-013 — Step-9 synchronous registered-callback | (GDD-scope) | ✅ |
| TR-LS-014 — Same-section no-op + focus-loss handling | (GDD-scope + project.godot setting) | ✅ |
| TR-LS-015 — Surface metadata contract (resolves OQ-FC-1) | (GDD-scope) | ✅ |

**System status**: ✅ All TRs covered; autoload load-order closed by ADR-0007; transition reason closed by ADR-0002 4th-pass; perf budget closed by ADR-0008 non-frame budgets.

### System 10 — Stealth AI (TR-SAI-*)

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-SAI-001 — Guard hierarchy | (GDD-scope) | ✅ |
| TR-SAI-002 — 6-state alert machine | (GDD-scope) | ✅ |
| TR-SAI-003 — Six SAI signals | ADR-0002 | ✅ (guard_incapacitated + guard_woke_up declared in 4th-pass amendment 2026-04-22; verified 2026-04-23) |
| TR-SAI-004 — Severity enum | ADR-0002 | ✅ (amended 2026-04-22) |
| TR-SAI-005 — AlertCause enum | ADR-0002 | ✅ |
| TR-SAI-006 — TakedownType enum | ADR-0002 | ✅ (amended 2026-04-22) |
| TR-SAI-007 — F.1 Sight fill formula | (GDD-scope) | ✅ |
| TR-SAI-008 — F.2 Sound fill | (GDD-scope) | ✅ |
| TR-SAI-009 — F.3 Accumulator decay | (GDD-scope) | ✅ |
| TR-SAI-010 — F.4 Alert propagation | (GDD-scope) | ✅ |
| TR-SAI-011 — F.5 Transition thresholds | (GDD-scope) | ✅ |
| TR-SAI-012 — has_los_to_player() accessor | ADR-0002 (Accessor Conventions) | ✅ (amended 2026-04-22) |
| TR-SAI-013 — takedown_prompt_active() accessor | ADR-0002 (Accessor Conventions) | ✅ (amended 2026-04-22) |
| TR-SAI-014 — receive_damage synchronous mutation | (GDD-scope, Combat cross-ref) | ✅ |
| TR-SAI-015 — Wake-up clock 45 s | (GDD-scope) | ✅ |
| TR-SAI-016 — RaycastProvider DI interface | (GDD-scope) | ✅ |
| TR-SAI-017 — _perception_cache struct | (GDD-scope) | ✅ |
| TR-SAI-018 — 6 ms performance budget per 12 guards | **ADR-0008 Slot #2** (6.5 ms combined envelope with Combat GuardFireController 0.5 P95) | ✅ |

**System status**: ✅ All 18 TRs covered. Recommended Follow-up #5 (line 684) CLOSED 2026-04-23 by ADR-0008.

### System 11 — Combat & Damage (TR-CD-*)

All 22 TRs: ✅ Covered (with one downstream GDD-coordination item). Touches 5 ADRs:
- ADR-0001 (guard outline tier MEDIUM, dart outline LIGHT, muzzle-flash stencil)
- ADR-0002 (4 Combat signals + 4-param amendment consumption)
- ADR-0003 (ammo + reserve state serialization)
- ADR-0006 (MASK_PROJECTILES for darts, hitscan masks per-shot from SectionConfig)
- **ADR-0008** (Slot #2 GuardFireController 0.5 ms P95 + Slot #5 Combat non-GuardFire damage routing / hitscan / dart tick / fist ShapeCast)

Cross-system reconciliation flag (L233 GuardFireController independence claim) **CLOSED 2026-04-23** by ADR-0008 Slot #2's 6.5 ms combined guard-systems envelope.

Downstream coordination gap (NOT an ADR gap): Combat's dedicated `takedown` input action is not yet in Input GDD's 29-action catalog. **CLOSED 2026-04-23** — Input GDD action catalog grew 29 → 30.

### System 12 — Inventory & Gadgets (TR-INV-*)

**Added 2026-04-24 by fifth `/architecture-review` run after `/design-system inventory-gadgets` landed `design/gdd/inventory-gadgets.md`.**

| TR-ID | ADR | Status |
|-------|-----|--------|
| TR-INV-001 — InventorySystem as PC Node child (not autoload) | ADR-0007 + arch.md §3.3 | ✅ |
| TR-INV-002 — 4 frozen Inventory signals + `weapon_fired` emit-site | ADR-0002 | ✅ |
| TR-INV-003 — 2 new signals (`gadget_activation_rejected`, `weapon_dry_fire_click`) | ADR-0002 (amended 2026-04-24) | ✅ |
| TR-INV-004 — `guard_incapacitated(guard, cause: int)` 2-param extension | ADR-0002 (amended 2026-04-24) | ✅ |
| TR-INV-005 — `CombatSystemNode.DamageType.MELEE_PARFUM` enum member | ADR-0002 (amended 2026-04-24) + Combat GDD downstream-coord | ✅ |
| TR-INV-006 — `InventoryState extends Resource` two-dict ammo split (untyped Dictionary) | ADR-0003 | ✅ |
| TR-INV-007 — Save registration via `LevelStreamingService.register_restore_callback` | ADR-0003 + LS CR-10 | ✅ |
| TR-INV-008 — Tier 1 outline for held weapons + gadgets + WorldItem pickups | ADR-0001 | ✅ |
| TR-INV-009 — Physics layer contracts (LAYER_PROJECTILES + MASK_INTERACTABLES + MASK_GUARDS + MASK_WORLD) | ADR-0006 | ✅ |
| TR-INV-010 — HUD Core consumes via `project_theme.tres` + `FontRegistry`; Inventory does NOT render | ADR-0004 | ✅ |
| TR-INV-011 — Event-driven; < 0.3 ms worst-case in Slot #8 pooled residual | ADR-0008 | ✅ |
| TR-INV-012 — Subscribes to `enemy_killed`, `guard_incapacitated`, `player_interacted` | ADR-0002 | ✅ |
| TR-INV-013 — Combat autoload `_unhandled_input` dispatches shared-binding `use_gadget`/`takedown` | ADR-0007 (Combat line 7) | ✅ (engine-verification gate — Coord #12) |
| TR-INV-014 — `SkeletonModifier3D` IK target cross-subtree (HandAnchor vs body Skeleton3D) | — | ⚠️ Engine-verification gate — Coord #11 (rifle IK optional MVP; fallback: scope-out) |
| TR-INV-015 — `InteractPriority.Kind.PICKUP = 2` enum slot | PC GDD + Inventory GDD (GDD-scope) | ✅ |

**System status**: ✅ All 15 TRs covered at system level. Two engine-verification gates (Coord #11 rifle IK + #12 autoload `_unhandled_input`) are Tech Setup scope — not ADR gaps. Inventory sprint gated on 4 remaining BLOCKING coord items (Combat GDD `apply_fire_path` declaration, SAI GDD BAIT_SOURCE EVENT_WEIGHT row, Input GDD L91 single-dispatch clarification, save-load.md two-dict InventoryState schema) — all text-alignment edits, not architectural changes.

---

### System 13 — Mission & Level Scripting (TR-MLS-*)

All 19 TRs: ✅ Covered. Touches 5 ADRs:
- ADR-0002 (Mission domain signals: mission_started, mission_completed, objective_started, objective_completed; section_entered subscriber)
- ADR-0003 (split-write authority with F&R; FORMAT_VERSION=2 A4 amendment; MissionState.fired_beats + triggers_fired)
- ADR-0006 (MLSTrigger Area3D collision-layer; engine-verification gate for trigger-layer assignment pending)
- ADR-0007 (autoload line 9; MLS-after-F&R hard edge per 2026-04-27 amendment)
- ADR-0008 (Slot #8 sub-claim 0.1 ms steady + 0.3 ms peak)

### System 14 — Failure & Respawn (TR-FR-*)

All 14 TRs: ✅ Covered. Touches 6 ADRs:
- ADR-0002 (player_died subscriber, respawn_triggered sole publisher)
- ADR-0003 (FailureRespawnState sub-resource; A4 amendment)
- ADR-0004 (InputContext.LOADING push/pop; A6 amendment)
- ADR-0006 (player_respawn_point Marker3D; layer-neutral)
- ADR-0007 (autoload line 8)
- ADR-0008 (mechanical flow ~0.58 s; LS swap budget; watchdog 2.5 s)

### System 15 — Civilian AI (TR-CAI-*)

All 15 TRs: ✅ Covered. Touches 5 ADRs:
- ADR-0001 (BQA contact outline tier upgrade Tier 3 → Tier 1 at 3.0 m pickup)
- ADR-0002 (civilian_panicked, civilian_witnessed_event; WitnessEventType enum atomic-commit)
- ADR-0003 (CivilianAIState capture/restore; LSS callback registration)
- ADR-0006 (LAYER_AI = 3; group tag 'civilian')
- ADR-0008 (Slot #8 sub-claim 0.30 ms p95; 0.6 ms reserve carve-out for panic-onset 8-civilian Restaurant frame per 2026-04-28 amendment)

### System 16 — HUD Core (TR-HUD-*)

All 15 TRs: ✅ Covered. Touches 4 ADRs:
- ADR-0002 (9 subscriptions including ui_context_changed; subscriber-only; FP-1 no emit)
- ADR-0004 (Theme.fallback_theme inheritance; FontRegistry.hud_numeral; AccessKit; mouse_filter IGNORE; CR-22 Tween.kill on context-leave)
- ADR-0007 (NOT autoload — per-main-scene CanvasLayer)
- ADR-0008 (Slot 7 0.3 ms; F.5 worst-case C_frame=0.259ms with 41µs headroom; photosensitivity 333ms rate-gate)

### System 17 — Document Collection (TR-DC-*)

All 15 TRs: ✅ Covered. Touches 7 ADRs:
- ADR-0001 (Stencil Tier 1 heaviest)
- ADR-0002 (document_collected/_opened/_closed sole publisher; player_interacted subscriber)
- ADR-0003 (Document Resource schema; DocumentCollectionState capture/restore via MLS orchestration)
- ADR-0004 (translation keys only — no resolved strings)
- ADR-0006 (DocumentBody on LAYER_INTERACTABLES)
- ADR-0007 (NOT autoload)
- ADR-0008 (Slot #8 sub-claim ≤0.05 ms peak)

### System 18 — Document Overlay UI (TR-DOU-*)

All 19 TRs: ✅ Covered. Touches 4 ADRs:
- ADR-0002 (subscriber-only document_opened/_closed; FP-OV-1 no emit)
- ADR-0004 (CanvasLayer index 5; InputContext.DOCUMENT_OVERLAY push/pop; ui_cancel modal dismiss; Theme.fallback_theme A5; FontRegistry.document_header/_body; AccessKit Gate 1 + Gate 5 BBCode→AT; PostProcessStack.enable_sepia_dim/disable lifecycle; dual-focus Tab/focus consumption; reduced-motion)
- ADR-0007 (per-section instantiation, NOT autoload)
- ADR-0008 (Slot 7 sole-occupant when READING; depends on HUD CR-22 Tween.kill — closed 2026-04-28)

### System 19 — Menu System (TR-MENU-*)

All 15 TRs: ✅ Covered. Touches 3 ADRs:
- ADR-0003 (SaveLoad.slot_metadata; LOAD_FROM_SAVE flow)
- ADR-0004 (InputContext.MENU/PAUSE/SETTINGS/MODAL push/pop; Theme.fallback_theme; FontRegistry compliance; AccessKit; reduced-motion)
- ADR-0007 (LS-allowlisted call-site for change_scene_to_file; LSS step-9 restore callback)

### System 20 — Settings & Accessibility (TR-SET-*)

All 18 TRs: ✅ Covered. Touches 5 ADRs:
- ADR-0002 (SettingsService sole publisher of setting_changed + settings_loaded — added 2026-04-28; boot-burst pattern)
- ADR-0003 (sole reader/writer of user://settings.cfg; separation from SaveGame)
- ADR-0004 (InputContext.SETTINGS push/pop; Theme.fallback_theme A5; AccessKit Gate 1; modal dismiss via ui_cancel)
- ADR-0007 (autoload line 10 — last in canonical table; consumers use settings_loaded one-shot pattern)
- ADR-0008 (333 ms WCAG 2.3.1 photosensitivity floor; UI debouncing)

### System 21 — Dialogue & Subtitles (TR-DLG-*)

All 15 TRs: ✅ Covered. Touches 5 ADRs:
- ADR-0002 (Dialogue domain dialogue_line_started + dialogue_line_finished sole publisher; ui_context_changed subscriber for self-suppression)
- ADR-0003 (subtitle_speaker_labels persists via settings.cfg)
- ADR-0004 (subtitle_size_scale 200% WCAG SC 1.4.4; tr() Localization compliance)
- ADR-0007 (NOT autoload — per-section instantiation)
- ADR-0008 (Slot #8 sub-claim 0.10 ms peak event-frame — registered 2026-04-28 night)

### System 22 — Cutscenes & Mission Cards (TR-CMC-*)

All 15 TRs: ✅ Covered (pending ADR-0002 2026-04-29 amendment commit). Touches 5 ADRs:
- ADR-0001 (Outline escape-hatch via OutlineTier.set_tier for cinematic emphasis)
- ADR-0002 (NEW Cutscenes domain: cutscene_started + cutscene_ended — uncommitted 2026-04-29 amendment; Audio + MLS subscribers)
- ADR-0003 (read-only access to MissionState.triggers_fired; MLS sole writer per CR-CMC-21)
- ADR-0004 (InputContext.CUTSCENE A6 amendment; CanvasLayer 10 mutually-exclusive with Settings via lazy-instance + InputContext gate; PostProcessStack lifecycle)
- ADR-0008 (Slot 7 sub-claim ≤0.20 ms when card/letterbox renders; Slot #8 trigger-evaluation; cadence ≤7 cinematic activations per first-watch)

### System 23 — HUD State Signaling (TR-HSS-*)

All 13 TRs: ✅ Covered. Touches 3 ADRs:
- ADR-0002 (alert_state_changed subscriber; subscriber-only)
- ADR-0004 (FontRegistry — BQA Blue strip + Parchment text; Theme.fallback_theme; AccessKit assertive priority for alarm-state cue; CR-9 rate-gate exempts upward-severity transitions; HUD CR-22 Tween cleanup; tr() locale-change re-resolve via NOTIFICATION_TRANSLATION_CHANGED 4.5+)
- ADR-0008 (Slot 7 shared cap with HUD Core: ≤0.05 ms steady-state, ≤0.15 ms peak; SaveLoad.FailureReason enum advisory line)

---

## Known Gaps (❌ only)

**None at ADR level.** ADR architecture coverage is complete:

### Foundation-layer gaps
*(None — Signal Bus, Save/Load, Collision, UI, Stencil, Autoload foundations all complete at system level.)*

### Core-layer gaps
*(None.)*

### Feature / Presentation-layer gaps
*(None.)*

### Cross-cutting (not system-specific) gaps

1. ~~**Performance Budget Distribution ADR**~~ — **CLOSED 2026-04-23** by ADR-0008. 9-slot allocation totaling 16.6 ms (Rendering 3.8 + Guard systems 6.5 + Post-Process 2.5 + Jolt 0.5 + Player/FC/Combat non-GF 0.3 + Audio dispatch 0.3 + UI 0.3 + Pooled residual 0.8 + Reserve 1.6). Non-frame budgets consolidated (save ≤10 ms, load ≤2 ms, LS transition ≤570 ms p90, shader bake 0–500 ms one-time, autoload boot ≤50 ms cold-start, D3D12 post-stream warm-up 3 frames). Two new forbidden patterns (`unbudgeted_per_frame_ticking`, `directional_shadow_second_cascade`) fence the contract.

2. ~~**Autoload registration contract**~~ — **CLOSED 2026-04-23** by ADR-0007 (Autoload Load Order Registry), **amended same-day to 7 autoloads** adding Combat at line 7. Canonical line order: Events=1, EventLogger=2, SaveLoad=3, InputContext=4, LevelStreamingService=5, PostProcessStack=6, Combat=7. Two forbidden patterns fence ad-hoc registration, and Cross-Autoload Reference Safety is codified. Conflict 1 (InputContext vs LevelStreamingService line-4 collision) also CLOSED by same ADR.

### Cross-GDD coordination gaps — all CLOSED 2026-04-23

3. ~~**`design/gdd/player-character.md`** `CombatSystem.*` → `CombatSystemNode.*` rename~~ — **CLOSED 2026-04-23** — all ~10 sites in PC GDD renamed.

4. ~~**`design/gdd/audio.md`** §Mission handler table L188–189 `section_entered` / `section_exited` signatures (LS-Gate-3)~~ — **CLOSED 2026-04-23** — both handlers now 2-param with `reason: LevelStreamingService.TransitionReason` and 4-way branching (FORWARD / RESPAWN / NEW_GAME / LOAD_FROM_SAVE) documented per LS GDD CR-8.

5. ~~**`design/gdd/input.md`** L90 `use_gadget` context-resolves to takedown~~ — **CLOSED 2026-04-23** — split into dedicated `takedown` action per Combat CR-3 + `use_gadget` with mutex on `SAI.takedown_prompt_active()`; action catalog 29 → 30 (TR-INP-002 revised).

### Specialist-recommended ADR amendments — ALL CLOSED 2026-04-23

6. ~~**A3**~~ — **CLOSED**. ADR-0003 Gate 3 refined in-place with explicit `Dictionary[StringName, GuardRecord]` duplicate_deep isolation sub-gates (outer cloned, inner GuardRecord cloned, StringName keys intentionally NOT cloned per interning).
7. ~~**A4**~~ — **CLOSED**. ADR-0004 Implementation Guideline 2 grew addendum mandating `InputContext.*` call-site usage and forbidding `InputContextStack.*` (mirrors `CombatSystemNode`/`Combat` split).
8. ~~**A5**~~ — **CLOSED**. ADR-0005 Gate 5 added and moved Polish → Prototype (Shader Baker × `material_overlay` export-build compat verification).
9. ~~**A6**~~ — **CLOSED**. ADR-0006 Risks row added for Jolt `Area3D.body_entered` broadphase tunneling of fast bodies (Combat darts at 20 m/s on `LAYER_PROJECTILES`); mitigation folded into Combat OQ-CD-2 Jolt prototype scope.

---

## Execution-Phase Items (not architectural gaps)

These are story-level and production-level concerns that do not block `/architecture-review`'s PASS verdict:

- **21 verification gates outstanding** across 8 Proposed ADRs. These move ADRs Proposed → Accepted and are the normal Technical Setup / Prototype phase work.
- **Reference scene authoring** (`tests/reference_scenes/restaurant_dense_interior.tscn`) — prerequisite for ADR-0008 Gates 1–3; scoped to a separate tooling story.
- **CI `perf-gate` job** — prerequisite for ADR-0008 Gate 1 CI enforcement; scoped to a separate devops-engineer story.

---

## Superseded Requirements

*(None — this is the initial registry population.)*

---

## History

| Date | Total TRs | Full Chain % (ADR-covered) | Notes |
|------|-----------|-----------------------------|-------|
| 2026-04-22 | 158 | ~92% | Initial registry population. System-level granularity. 2 hard gaps on pending ADR-0002 amendment; 1 coordination gap on Input GDD takedown action. |
| 2026-04-23 | 158 | ~93% | Delta verification. ADR-0002 4th-pass amendment verified in-place (36 signals, section_entered/exited 2-param, guard_incapacitated + guard_woke_up declared, atomic-commit Risks row). TR-LS-007 + TR-SAI-003 moved ❌ → ✅; Conflicts 2 + 3 closed. Conflict 1 (autoload collision), Gaps 2 + 3, and specialist-recommended amendments A3–A6 unchanged. Verdict: CONCERNS (same as 2026-04-22, scope reduced). |
| 2026-04-23 (post-ADR-0007) | 158 | ~94% | Second delta verification after ADR-0007 (Autoload Load Order Registry) was authored and A3–A6 amendments applied in-place. **Conflict 1 + Gap 3 + A3 + A4 + A5 + A6 all CLOSED.** Only Gap 2 (Performance Budget Distribution ADR) + three GDD-coordination items remain. ADR count 6 → **7** (ADR-0007 added; all 7 still Proposed; 17 verification gates outstanding). Verdict: CONCERNS (scope further reduced — 6 of 7 action items from prior run closed). |
| 2026-04-23 (post-ADR-0008) | 158 | **~99%** | **Third delta verification after ADR-0008 (Performance Budget Distribution) landed same day.** Gap 2 **CLOSED**: 9-slot 16.6 ms allocation + non-frame budgets + verification contract + 2 new forbidden patterns + 1 new api_decision. TR-SAI-018, TR-PP-009, TR-LS-011, TR-AUD-007 (dispatch), combat-damage.md L233 all moved ⚠️ Partial → ✅. **SAI Recommended Follow-up #5 CLOSED.** ADR count 7 → **8** (all 8 still Proposed; 21 verification gates outstanding including ADR-0008's 4 new gates). Verdict: **PASS** (upgraded from CONCERNS — zero remaining ADR-level architectural gaps). 3 GDD-coordination items remain producer-tracked and non-blocking at ADR level. |
| 2026-04-23 (fourth — post-ADR-0007 Combat amendment + 3 GDD closures) | 160 | ~99% | Fourth delta verification. ADR-0007 amended in-place to add Combat at line 7 (closes TD-ARCHITECTURE Concern 1 from `/create-architecture` session). 3 GDD coordination items all CLOSED in-session: PC `CombatSystem.*` → `CombatSystemNode.*` rename (10 sites); Audio LS-Gate-3 (2-param `section_entered`/`section_exited` with 4-way reason branching); Input takedown split (29 → 30 actions). 13 surgical straggler edits across 5 files bring narrative in sync with amended 7-entry canonical table. Zero cross-ADR conflicts; zero ADR-level gaps. Verdict: **PASS** (re-affirmed; upgrades `/create-architecture` verdict from APPROVED WITH CONCERNS to APPROVED). |
| 2026-04-24 (fifth — post-Inventory GDD + ADR-0002 amendment) | **175** | **~98%** | **Fifth delta verification after `/design-system inventory-gadgets` + `/architecture-decision adr-0002-amendment` landed 2026-04-24.** 15 new TR-INV-001..015 appended; all map to existing ADRs + ADR-0002 2026-04-24 amendment. ADR-0002 signal count 36 → 38 (`gadget_activation_rejected`, `weapon_dry_fire_click`); `guard_incapacitated` signature extended 1→2 params (`cause: int`); `CombatSystemNode.DamageType` gains `MELEE_PARFUM`. Atomic-commit guard documented in amendment Risks row. Zero cross-ADR conflicts introduced. Registry Phase 5b landed (`guard_drop_pistol_rounds` stale-fix 8→3; 6 new entries + `guard_drop_dart_on_parfum_ko = 0 LOCKED`). Verification gate count 24 → **26** with +2 new godot-specialist engine-verification gates (Coord #11 `SkeletonModifier3D` scene-graph + #12 autoload `_unhandled_input` ordering) — Tech Setup scope, not architectural. 2 producer-tracked GDD coordination items surface as pre-sprint BLOCKING (Input GDD L91 single-dispatch clarification + save-load.md L102 two-dict InventoryState schema) — equivalent scale to 4th-run closures. Verdict: **PASS** (re-affirmed). |
| 2026-04-27 evening (sixth — post-`/propagate-design-change` from Document Overlay UI design-review) | 175 (no new TRs) | ~98% | **/propagate-design-change against `design/gdd/document-overlay-ui.md`** following the same-day design-review revision pass (verdict: MAJOR REVISION NEEDED → 46 items resolved in-session). **ADR-0004 Amendment A5 applied in-place**: `base_theme` corrected to `fallback_theme` in 9 locations (Gate 2 closure); Gate 4 (`Node.AUTO_TRANSLATE_MODE_*` enum names) closed; **new Gate 5** added (BBCode → AccessKit plain-text serialization, BLOCKING for SC 1.3.1 conformance on formatted Document Overlay UI bodies). **Architectural decision unchanged** — ADR-0004's core contracts (single `project_theme.tres` + per-surface inherited Themes, `InputContext` autoload, `FontRegistry` static class, modal dismiss via `_unhandled_input()` + `ui_cancel`, sepia dim as PPS lifecycle call) all stand. ADR-0004 verification gates: 3 BLOCKING (Gate 1 AccessKit property names + Gate 3 modal dismiss + new Gate 5 BBCode-to-AT) + 2 CLOSED (Gate 2 + Gate 4). Document Overlay UI status: NEEDS REVISION (revisions applied, awaiting re-review). 3 NEW BLOCKING **GDD-coordination** items emerged (OQ-DOV-COORD-12 Settings text_scale_multiplier for WCAG SC 1.4.4 / COORD-13 call-order recorder helper / COORD-14 HUD Tween-on-InputContext-change) — these are GDD-to-GDD coord items, not ADR-level gaps. Verdict: **PASS** (re-affirmed; ADR-0004's "Proposed" status preserved with refined gate list). |
| 2026-04-29 (seventh — post-`/review-all-gdds` 2026-04-28 + 11 new MVP/VS GDDs + 4 ADR amendments) | **348** | ~99% | **Seventh delta verification — first multi-system delta since the 2026-04-24 baseline.** **23/23 systems designed.** 11 new system GDDs landed (MLS, F&R, CAI, DC, HUD Core, Document Overlay UI, Menu System, Dialogue & Subtitles, Cutscenes & Mission Cards, Settings & Accessibility, HUD State Signaling): **+173 new TR-* entries appended**; all map to existing ADR-0001..0008. **Four ADR amendments** since 2026-04-24: ADR-0002 ×3 (settings_loaded + ui_context_changed 2026-04-28; cutscene_started + cutscene_ended 2026-04-29 uncommitted; signal count 38 → 41 → 43; domain count 9+3 → 9+3+UI → 10+3 = 13); ADR-0003 A4 (FailureRespawnState + ammo two-dict split + fired_beats + FORMAT_VERSION 1→2); ADR-0004 A5+A6 (`base_theme`→`fallback_theme`; InputContext MODAL+LOADING values); ADR-0007 (10-entry canonical table: F&R=8, MLS=9, SettingsService=10); ADR-0008 (Slot-8 panic-onset 0.6 ms reserve carve-out + autoload-cascade row 7→10 + Slot-8 sub-claims). **All 9 BLOCKING + 13 WARNINGS from `/review-all-gdds` 2026-04-28 confirmed CLOSED** by `6f08bae` + `a9bc7d4` resolution batch (verified by grep: 0 occurrences of stale strings). **Zero hard ADR-level gaps; zero cross-ADR conflicts.** Engine consistent (Godot 4.6 across 8 ADRs; no deprecated APIs). Architecture.md L13 GDDs-Covered metadata line is stale (says 10/23; reality 23/23) — minor doc-hygiene only. Verdict: **PASS** (re-affirmed). |

---

## How to Read This Matrix

- **✅** — ADR explicitly addresses this requirement (directly or via its decision text)
- **⚠️ Partial** — ADR covers some aspect but scope incomplete, pending amendment, or reasonably GDD-scope
- **❌ Gap** — no ADR addresses this requirement; must be authored before Pre-Production gate

TR-IDs are stable across review runs. When a GDD requirement's text is reworded (same intent), the TR-ID stays the same and `revised` date is bumped in `tr-registry.yaml`. When a requirement is removed, the entry is marked `status: deprecated`.

## Related

- `docs/architecture/architecture-review-2026-04-29.md` — **latest** review (seventh run — post-`/review-all-gdds` 2026-04-28 + 11 new MVP/VS GDDs + 4 ADR amendments); verdict PASS
- `docs/architecture/change-impact-2026-04-27-document-overlay-ui.md` — sixth run (change-impact only — ADR-0004 A5 fallback_theme); verdict PASS
- `docs/architecture/architecture-review-2026-04-24.md` — fifth run (post-Inventory GDD + ADR-0002 2026-04-24 amendment); verdict PASS
- `docs/architecture/architecture-review-2026-04-23.md` — fourth run (post-ADR-0007 Combat amendment + 3 GDD closures); verdict PASS
- `docs/architecture/architecture-review-2026-04-22.md` — initial full-matrix baseline + engine specialist findings
- `docs/architecture/tr-registry.yaml` — authoritative TR-ID source (348 entries as of 2026-04-29)
- `docs/architecture/adr-0001-*.md` through `adr-0008-*.md` — architectural decisions:
  - ADR-0002 amended 2026-04-22 / -24 / -28 / **-29 (uncommitted)** — 43 signals, 13 domains
  - ADR-0003 amended 2026-04-27 (A4: FailureRespawnState + ammo split + fired_beats + FORMAT_VERSION 1→2)
  - ADR-0004 amended 2026-04-27 (A5: fallback_theme) + 2026-04-28 (A6: MODAL + LOADING InputContext)
  - ADR-0007 amended 2026-04-23 (Combat=7) + 2026-04-27 (10-entry table; F&R=8, MLS=9, SettingsService=10)
  - ADR-0008 amended 2026-04-23 (added) + 2026-04-28 (Slot-8 panic-onset 0.6 ms reserve + autoload-cascade row 7→10 + Slot-8 sub-claims)
- `docs/registry/architecture.yaml` — performance_budgets / api_decisions / forbidden_patterns registry
- `design/gdd/systems-index.md` — system enumeration + status (**23/23 designed**)
- `design/gdd/gdd-cross-review-2026-04-28.md` — concentrated synthesis of 9 BLOCKING + 13 WARNINGS, all closed
