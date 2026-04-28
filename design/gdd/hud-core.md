# HUD Core

> **Status**: **APPROVED — REV-2026-04-26** (user accepted post-revision state without third re-review; creative-director's senior verdict had recommended a fresh-session re-review pass — see `reviews/hud-core-review-log.md` for the explicit decision record. 7 BLOCKING coord items remain open and must close before sprint planning regardless of GDD review status — see §C.5 BLOCKING coord items rolled-up summary.)
> **System**: #16 (Presentation / UI)
> **Tier**: MVP
> **Author**: User + `/design-system hud-core` (solo mode, 2026-04-25); revisions REV-2026-04-25 + REV-2026-04-26 incorporated post-review
> **Last Updated**: 2026-04-26 (REV-2026-04-26 — second revision pass addressing 15 BLOCKING themes from re-review; see `reviews/hud-core-review-log.md`)
> **Implements Pillars**: Primary 5 (Period Authenticity Over Modernization), Primary 2 (Discovery Rewards Patience — "no waypoints"); Secondary cross-cuts on every gameplay system whose state the HUD reflects.

> **REV-2026-04-26 SCOPE NOTE** (second revision pass, post-re-review): Addresses 15 BLOCKING themes from the 2026-04-25 re-review (7 specialists + creative-director synthesis). User-adjudicated design decisions for this pass: **(D1)** Dry-fire flash rate-gated at 3 Hz via dedicated `_dry_fire_timer` (CR-8 rewritten; AC-HUD-4.5 updated; "Why NOT rate-gated" footnote removed; AC-HUD-3.7 authoritative). **(D2)** Settings & Accessibility (system #23) photosensitivity-toggle minimal UI promoted from forward-dep to HARD upstream MVP dep — HUD Core MVP blocked until #23 ships the minimal Day-1 toggle + boot-warning link. **(D3)** HUD State Signaling (system #19) HoH/deaf alert-cue minimal slice promoted from forward-dep to HARD upstream MVP dep. **(D4)** TAKEDOWN_CUE latch + `takedown_availability_changed` signal + AC-HUD-6.3/6.4 fully removed from MVP — cockpit-dial fantasy holds that takedown eligibility never required HUD acknowledgment; SAI body-language alone signals affordance; OQ-HUD-7 closed (Path A finalised, no MVP implementation surface). Plus technical fixes: F.5 rebuilt with single canonical formula, gadget-slot phantom Label removed (N=4, was 5); §C.4 vs §V.4 coroutine pseudocode aligned; §V.3 enum prefix + §C.2 method form propagated from coord items into spec body; `_compose_prompt_text()` defined with `_last_interact_label_key` mirror cache (FP-8 compliant); CR-3 PC injection contract + null guard mandated; AC defects rewritten (AC-HUD-2.7 named tool, AC-HUD-3.1 single mechanism, AC-HUD-3.2 no float literal, AC-HUD-6.7 explicit `await` after `queue_free()`, AC-HUD-9.4 single rule, AC-HUD-11.5 moved to OQ-HUD-8); smoke vs full-suite gate designation added (§H.0); reduced-motion claim disambiguated; gadget empty-tile contrast gate added; key-glyph input-rebinding mechanism specified.

> **Upstream (consumed)**: Player Character ✅, Combat & Damage ✅, Inventory & Gadgets ✅(pending coord), Stealth AI ✅ *(removed as upstream — TAKEDOWN_CUE cut per D4)*, **HUD State Signaling (system #19) — HARD MVP dep for HoH alert-cue minimal slice (REV-B)**, **Settings & Accessibility (system #23) — HARD MVP dep for photosensitivity-toggle minimal UI (REV-B)**, ADR-0002 Signal Bus, ADR-0004 UI Framework (Proposed — 3 gates pending), ADR-0008 Performance Budget (Slot 7 = 0.3 ms cap), Localization Scaffold (Designed), Input (TBD — for prompt-strip key-glyph rebinding contract)
> **Dependents (forward)**: HUD State Signaling (system #19) — extension via `get_prompt_label()` (in addition to MVP alert-cue dep above), Document Overlay UI (system #20 — sibling modal surface, not extension)

## Overview

HUD Core is the screen-space reading surface that lets the player track every gameplay state without ever leaving Eve Sterling's first-person frame. It is simultaneously (a) the **subscriber layer** — a `CanvasLayer`-rooted scene that listens to 8 frozen signals from the `Events` autoload (`player_health_changed`, `player_damaged`, `player_died`, `player_interacted` from Player Character; `ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected` from Inventory & Gadgets) and reads two PC-owned queries per frame (`get_current_interact_target()`, `is_hand_busy()`) to drive the interact prompt — and (b) the **player-facing chrome** — three corner widgets and a single contextual prompt strip rendered in NOLF1 (2000) typographic register: bottom-left numeric health, bottom-right weapon name + `current / reserve` ammo, top-right active-gadget tile, and a center-lower transient prompt strip (interaction prompts, pickup memos, "TAKEDOWN AVAILABLE"). The crosshair widget — a resolution-independent dot (0.19% × viewport_v) plus tri-band halo — is the fourth and only center-screen element, opt-out by default-on, rendered exclusively when `InputContext.current() == GAMEPLAY`. The system **emits zero signals** (subscriber-only per ADR-0002) and **never polls game state** beyond the two PC accessors authorised in PC §UI Requirements (ADR-0004 forbids polling; ADR-0008 caps the entire UI per-frame cost at Slot 7 = 0.3 ms on Iris Xe). All visible strings flow through `tr()` (Localization Scaffold). All typefaces flow through `FontRegistry.hud_numeral(rendered_size_px)` so the Futura Condensed Bold → DIN 1451 Engschrift substitution at the 18 px floor (Art Bible §7B / §8C) is encapsulated. Theme styling inherits `project_theme.tres` per ADR-0004; HUD-specific overrides live in `hud_theme.tres`. Every HUD widget sets `mouse_filter = MOUSE_FILTER_IGNORE` — the HUD is exempt from Godot 4.6's dual-focus split because it never takes focus and never consumes input. A photosensitivity rate-gate (`hud_damage_flash_cooldown_ms = 333` ms = 3 Hz WCAG 2.3.1 ceiling, Combat-owned constant, HUD-enforced) coalesces rapid damage events into a single deferred numeral flash so multi-guard alpha strikes cannot exceed the photosensitivity threshold. **Pillar fit:** Primary 5 (Period Authenticity Over Modernization) is the load-bearing pillar — every visual rule (corner-only anchors, hard-edged BQA Blue strips, period typography, no center-screen chrome, instant updates with no count-up animation, no diegetic floating health bars) descends from NOLF1's HUD register and the 1965 spy-comedy fiction; Primary 2 (Discovery Rewards Patience) is served by the categorical absence of waypoints, objective markers, alert-state visual indicators, and minimap — players read the world for cues, not the screen edges. **This GDD defines:** widget grammar, signal-subscription contract, screen-space anchors and scale rules, the photosensitivity rate-gate, the critical-health colour-shift trigger, the interact-prompt resolver coupling to PC, the crosshair widget composition, and the explicit "HUD must NOT render" forbidden surfaces. **This GDD does NOT define:** the actual values of upstream state (`player_max_health` is PC's; `pistol_starting_reserve` is Inventory's; `crosshair_dot_size_pct_v` is Combat's via Settings); the visual style of the modal surfaces that overlay the HUD (Document Overlay UI / Menu System / Pause / Settings own their own CanvasLayer indices and themes); the alarm-state stinger UI, document-collected toast, or critical-health clock-tick orchestration (HUD State Signaling owns those at VS tier); the death screen, retry button, or kill cam (Failure & Respawn deliberately omits these per Pillar 5); the civilian readout (Civilian AI Pillar 5 zero-UI absolute — civilians never appear in the HUD); the persistence of `Settings.crosshair_*` toggles (Settings & Accessibility owns serialization); the Audio mixing of HUD-coupled cues (Audio GDD owns the SFX bus per CR routing).

## Player Fantasy

**Distilled fantasy:** *I read my tools the way Eve does — peripherally, without ceremony, because I already know.*

### Anchor moment — "The Glance" (Section 3, east platform, ~17 minutes in)

> Third floor, east platform. You round the iron column and a guard you didn't hear is six metres away, his back to you, lighting a cigarette. Your eyes don't leave him. Bottom-left of your vision, you catch — without reading — that the parchment numeral is still high. Bottom-right: `WALTHER PPK  7 / 21`. You already know the number was 7. You knew it when you took the last shot, two rooms ago. The HUD didn't tell you; it confirmed you. Your thumb is on the silenced pistol. The lighter clicks. You move.

### The reading

Eve Sterling is a craftsperson — the most quietly competent person in any room she enters. The HUD is not her instructor; it is her **cockpit dial**, glanced at the way a 1965 jet pilot glances at a fuel gauge — peripherally, infrequently, and only to confirm what they already feel. Every design rule that follows in this GDD descends from that frame: instant numeral updates with no count-up animation (a dial does not wind for ceremony); corner anchors only with no centre-screen permanent chrome (the cockpit's centre is the windscreen, the world); single-frame critical-state colour shifts from Parchment to Alarm Orange (a warning placard, not a panic spiral); 1-frame white flash on damage events (a needle deflection, not a screen-bleeds-red emergency); no waypoints, no objective markers, no minimap, no alert-state indicator, no damage direction (the world has the answers — the HUD only confirms state already known to the attentive player). The HUD does not editorialise. The HUD does not flatter. The HUD does not reward kills with hit-marker chimes or floating numbers. The HUD trusts the player to be paying attention to the world, and behaves as though insulted by the suggestion that it should compete for their gaze.

This anchors the player to **Eve's professionalism**, not to a separate aspirational character. The fantasy is not "look how stylish my HUD is" — it is *"I am the kind of operator who reads the corners without breaking stride."* The competent player and the competent character converge through the HUD's restraint.

### Pillar binding

- **Primary — Pillar 5 (Period Authenticity Over Modernization)**: every visual rule (corner anchors, hard-edged BQA Blue strips, condensed period typography, instant updates, single-frame colour transitions, no centre-screen permanent chrome) descends from NOLF1's HUD register and the 1965 spy-fiction the game inhabits. The HUD is the most-felt period detail in the game because the player looks at it every frame.
- **Primary — Pillar 2 (Discovery Rewards Patience)**: the HUD's categorical refusal of waypoints, minimap, objective markers, and alert-state indicators forces the player to read **the world** for cues — guard banter, signage, document trails, environmental geometry — instead of the screen edges. A patient observer never needs to look directly at the corners; an inattentive player will be punished by surprise.
- **Secondary — Pillar 1 (Comedy Without Punchlines)**: the HUD is mute; comedy lives in documents, signage, guard banter, and overheard radio. A loud HUD would steal jokes that belong to the world.
- **Secondary — Pillar 3 (Stealth is Theatre, Not Punishment)**: the HUD's critical-state colour shift is the *cue for the second act*, not a fail-state warning. Low health does not mean "you are dying" — it means "the scene has changed; a service door, a cold larder, a dumbwaiter are now your stage." The orchestration of that beat (clock-tick layering, alarm stinger, document-collected toast) is owned by **HUD State Signaling** at VS tier; HUD Core delivers the visual artifact that triggers it.
- **Secondary — Pillar 4 (Iconic Locations as Co-Stars)**: every frame the player spends on HUD chrome is a frame they are not spending on the Eiffel Tower's ironwork, the restaurant's brass railings, the bomb chamber's industrial pipes. The HUD's modesty is the location's spotlight.

### This fantasy refuses

- **Modern AAA glanceable-telemetry comfort** — constant reassuring ticks, kill-feed scrolls, ammo-low icon flashes, motion-tracker pings. The HUD does not soothe the anxious player.
- **Diegetic-purist wristwatch hiding** — health-as-Eve's-pulse, ammo-as-magazine-shake-on-the-pistol-mesh, gadget-readiness-as-Eve-sniffing-the-perfume-bottle. The HUD is screen-space and unapologetic about it; period authenticity is in the typographic register, not in pretending the chrome is not there.
- **Juicy hit-feedback / damage-feel rewards** — no hit markers, no damage numbers, no floating XP, no screen shake on hits, no chromatic aberration on damage. Eve does not need the HUD to confirm that her shots landed; the audio and the world tell her.
- **HUD-as-aspirational-art-piece** — no period-typographic flourishes that draw the eye for their own sake, no decorative chrome around the corners, no "look at how lovingly we've reproduced 1960s spy paraphernalia." The HUD is well-tailored, period-correct, and exactly as visible as it needs to be — and no more.
- **Modal HUD overload** — no sub-menus inside HUD, no rotary weapon wheel, no inventory grid. Inventory ownership of slots 1–5 + scroll cycling is delivered through the existing weapon-name + ammo widget; no separate weapon-select chrome appears at runtime.

### Fantasy test for any future addition

Before adding anything to HUD Core, ask: *would Eve glance at this peripherally and walk on, or would she stop and read?* If she would have to stop and read, it does not belong in HUD Core — it belongs in Document Overlay, Pause Menu, or it does not belong at all.

## Detailed Design

The HUD Core scene root is `class_name HUDCore extends CanvasLayer`, instanced once per main game scene at `CanvasLayer.layer = 1` (within the 0..3 range reserved for HUD by ADR-0004 §Implementation Guideline 7). It hosts a single `Control` child as the working root for all widgets; per-widget tree-order determines z within the layer (later sibling = drawn on top). The HUD scene is **session-persistent** — instanced once on game start, kept alive across `LevelStreamingService.section_entered` transitions.

### C.1 Core Rules

**CR-1: Signal-only subscription in `_ready()` — REV-2026-04-26 recounted.** HUD subscribes inside `_ready()`, using `Events.[signal].connect(_on_[signal])` (or equivalent for non-Events sources). Zero subscriptions occur outside `_ready()`. The full subscription list at MVP — **with accurate connection counts** (each `connect()` call is one connection regardless of how many handler-side dispatches it routes):

- **(A) `Events` autoload signals — 9 connections**: `player_health_changed`, `player_damaged`, `player_died`, `player_interacted`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected`, `ui_context_changed` *(NEW — ADR-0002 amendment, see §C.5)*. **REV-2026-04-26 — `takedown_availability_changed` REMOVED per D4** (TAKEDOWN_CUE cut from MVP scope; see §C.3 state machine).
- **(B) Settings autoload signal — 1 connection** *(REV-2026-04-26 corrected from 2; REV-2026-04-27 category sweep — closes B3 from /review-all-gdds 2026-04-27)*: `Settings.setting_changed.connect(_on_setting_changed)`. The handler dispatches by `(category, key)` for `("accessibility", "crosshair_enabled", _)`, `("accessibility", "damage_flash_enabled", _)`, and `("locale", _, _)` (CR-18). The single-canonical-home rule for both keys lives in `accessibility` per Settings GDD CR-2 + line 180; pre-sweep this GDD subscribed under `("hud", ...)` which would have silently dropped Settings's actual emits. Implementer note: **do NOT use `connect(Callable.bind(...))` per-category** — that creates multiple connections to the same signal which (a) miscounts vs the spec and (b) duplicates work in the dispatch path.
- **(C) Local Timer child-node signals — 3 connections** *(REV-2026-04-26 added `_dry_fire_timer`)*: `_flash_timer.timeout` → `_on_flash_timer_timeout` (CR-7b deferred damage-flash dispatch), `_dry_fire_timer.timeout` → `_on_dry_fire_timer_timeout` (CR-8 deferred dry-fire flash dispatch — NEW per D1), `_gadget_reject_timer.timeout` → `_on_gadget_reject_timeout` (CR-9 desat revert).
- **(D) Viewport signal — 1 connection**: `get_viewport().size_changed` → `_update_hud_scale` (§C.2 scale rule).

**Total: 14 connections** *(REV-2026-04-26 — was incorrectly stated as 16)*. AC-HUD-1.1 must verify all 14 (was: only the 9 Events bus signals). (Justification: ADR-0002 subscriber-only contract; ADR-0008 0.3 ms cap forbids polling; late-connect creates missed-event races.)

**CR-2: Explicit signal disconnect in `_exit_tree()`.** Every signal connected in CR-1 is explicitly disconnected in `_exit_tree()` with `is_connected()` guard:
```gdscript
func _exit_tree() -> void:
    if Events.player_health_changed.is_connected(_on_health_changed):
        Events.player_health_changed.disconnect(_on_health_changed)
    # ... (one block per signal)
```
(Justification: ADR-0002 §Implementation Guideline 3 mandates explicit disconnect for **every** subscriber in this project — HUD does not get an exemption. The autoload outlives the HUD scene; godot-specialist confirmed auto-disconnect is technically safe but project-wide convention overrides.)

**CR-3: Two PC accessors are the only authorised polling — PC reference acquired via `@export` injection (REV-2026-04-26 — implementable contract).** HUD calls `pc.get_current_interact_target()` and `pc.is_hand_busy()` once per `_process()` frame exclusively for the prompt-strip widget (§C.3). No other system property is polled. All other widget state is held in HUD-local mirror variables updated by signal handlers.

**Injection contract (REV-2026-04-26 mandated):** HUD declares `@export var pc: PlayerCharacter` (typed export; `null` until injected). The injecting party (main game scene OR `LevelStreamingService` on `LOAD_FROM_SAVE`) **MUST set `hud.pc = pc_node` BEFORE calling `add_child(hud)`** — Godot's `_ready()` fires immediately when the node enters the tree, and assignment after `add_child()` produces a `null pc` at `_ready()` time. The two valid injection sites are:

1. **Main game scene boot**: editor-time inspector assignment of `pc` on the HUD scene instance is acceptable for static main-scene configuration. Runtime alternative: `var hud := preload(...).instantiate(); hud.pc = pc_node; main_scene.add_child(hud)`.
2. **`LOAD_FROM_SAVE` re-instantiation**: `LevelStreamingService` MUST follow the same `pc =` then `add_child` ordering when rebuilding the HUD scene; this is now an LSS contract item documented in §C.5 forward-dep coord.

**Null-guard requirement (REV-2026-04-26 visible in §C.3 pseudocode):** the prompt-strip resolver opens with `if pc == null: state = HIDDEN; return`. This is shown explicitly in §C.3's resolver pseudocode (was previously implicit prose). All `_process` paths that would reach `pc.is_hand_busy()` or `pc.get_current_interact_target()` first verify `pc != null`. **Re-injection after `_ready()`**: there is none — if `pc` is `null` at `_ready()` time, the HUD logs a `push_error` and remains in `pc == null` state; this is an integration bug that must be caught at scene boot, not papered over with retry logic.

**`is_instance_valid` requirement (matches AC-HUD-6.7):** Before any property access on the value returned by `pc.get_current_interact_target()` in `_compose_prompt_text()`, HUD MUST guard with `if is_instance_valid(target):` — a `null` check is insufficient because Godot 4.x can return a freed Object reference that passes `!= null` but fails `is_instance_valid()`.

(Justification: ADR-0008 0.3 ms cap; ADR-0004 §Implementation Guideline 12 explicitly authorises exactly these two accessors; FP-14 forbids singleton/tree-walk lookups. The pre-`add_child` ordering is the only `@export` pattern that guarantees `_ready()` sees a non-null `pc` without runtime polling or retry.)

**CR-4: Single source of truth per widget — REV-2026-04-26.** Each widget derives from exactly one authoritative signal:
- Health numeral ← `player_health_changed(current, max_health)`
- Damage-flash gate ← `player_damaged(amount, source, is_critical)` (rate-gated, see CR-7)
- Weapon name ← `weapon_switched(weapon_id)`
- Ammo readout ← `ammo_changed(weapon_id, current, reserve)`
- Gadget tile icon ← `gadget_equipped(gadget_id)`
- Gadget tile rejection desat ← `gadget_activation_rejected(gadget_id)`
- Prompt-strip resolver ← `pc.get_current_interact_target()` + `pc.is_hand_busy()` (per frame) — **REV-2026-04-26: `takedown_availability_changed` removed per D4 (TAKEDOWN_CUE cut from MVP).**
- HUD parent visibility ← `ui_context_changed(new_ctx, prev_ctx)` (signal latch)
- Crosshair visibility ← HUD parent visibility AND `setting_changed("accessibility", "crosshair_enabled", _)` mirror

No widget reads from two competing signals for the same datum. (Justification: prevents split-brain state; mirrors live-authoritative pattern enforced in F&R and CAI GDDs.)

**CR-5: Edge-triggered critical-state colour swap.** When `player_health_changed(current, max_health)` fires and `current / max_health` crosses below `player_critical_health_threshold / 100.0` (registry constant `25`, treated as percentage — at `max_health = 100` this resolves to `0.25` ratio), the health numeral colour transitions Parchment `#F2E8C8` → Alarm Orange `#E85D2A` on that render frame via `add_theme_color_override(&"font_color", alarm_orange)`. Edge-triggered: HUD stores `_was_critical: bool` and only reacts on threshold cross — does NOT re-apply colour on every `player_health_changed` while already below threshold. Pattern matches Audio GDD §Formula 4 (clock-tick trigger uses identical `health_pct < threshold_pct / 100.0` form). (Justification: level-triggered re-application would produce redundant per-tick writes; edge-triggering ensures cleanness under both gradual drain and instant restoration.)

**CR-6: Critical-state recovery is also edge-triggered, no hysteresis.** When `current / max_health` crosses back ≥ 0.25, the numeral colour reverts Alarm Orange → Parchment **immediately on that frame** (no sticky-critical, no debounce). `_was_critical` updates to `false` on the same frame. (Justification: medkit use mid-firefight must give immediate feedback; stickiness contradicts cockpit-dial fantasy — a dial snaps to new state.)

**CR-7: Damage flash is rate-gated at 333 ms (WCAG 2.3.1).** The 1-frame `#FFFFFF` numeral flash triggered by `player_damaged` is subject to a minimum inter-flash interval of `hud_damage_flash_cooldown_ms = 333` ms. Damage events arriving while the gate is closed do NOT fire a flash; a `_pending_flash: bool` latch is set. When the cooldown expires, if `_pending_flash` is true, a single deferred flash fires immediately and the cooldown restarts. Audio SFX and camera dip are NOT gated here — only the visual flash. Full algorithm: §F.1. (Justification: WCAG 2.3.1; Combat GDD E.42 specifies this exact semantics.)

**CR-7b: Photosensitivity gate uses a child Timer node, not `SceneTreeTimer` allocation.** The HUD root has a single child `Timer` node (`one_shot = true`, `wait_time = 0.333`) — call it `_flash_timer`. On `player_damaged`: `if _flash_timer.is_stopped(): fire_flash() ; _flash_timer.start()`. On `_flash_timer.timeout`: if `_pending_flash`: `fire_flash() ; _flash_timer.start() ; _pending_flash = false`. Zero allocation per damage event; zero `_process` dependency. (Justification: godot-specialist recommendation — `SceneTreeTimer` allocates per-event; manual `_process` poll violates signal-driven contract.)

**CR-8: Dry-fire feedback via `ammo_changed` unchanged-value detection — RATE-GATED at 3 Hz (REV-2026-04-26 per D1).** HUD MUST NOT subscribe to `weapon_dry_fire_click` (Audio's exclusive subscription per ADR-0002 amendment 2026-04-24). Instead: in `_on_ammo_changed(weapon_id, current, reserve)`, HUD compares against locally cached prior values `(_last_ammo_weapon_id, _last_ammo_current, _last_ammo_reserve)`. If all three identical AND the cache is initialised (sentinel: `_last_ammo_weapon_id != &""`) → unchanged-value detected. The 1-frame magazine-numeral flash that confirms a dry-fire **is rate-gated at 3 Hz** via a dedicated `_dry_fire_timer: Timer` child node (`one_shot = true`, `wait_time = 0.333`). The gate semantics mirror the damage-flash gate (CR-7 / CR-7b): if `_dry_fire_timer.is_stopped()` → fire flash + start timer; else → set `_pending_dry_fire: bool = true`. On `_dry_fire_timer.timeout`: if `_pending_dry_fire` → fire deferred flash + restart timer + clear flag. The cache `_last_ammo_*` is updated on every `ammo_changed` event regardless of whether the flash fired. **Sentinel: `_last_ammo_weapon_id` defaults to `&""` at `_ready()` and after `LOAD_FROM_SAVE`; the unchanged-value detection requires the cache to be non-default (i.e., at least one prior `ammo_changed` has been received) to prevent a false-positive on the first restored signal at `("", 0, 0)`.** (Justification: REV-2026-04-26 D1 — held-trigger keyboard repeat at 30-60 Hz can produce sustained 30+ Hz flashes; this violates WCAG 2.3.1's 3 Hz ceiling. The dedicated `_dry_fire_timer` keeps damage and dry-fire channels semantically distinct so the two flash paths do not block each other within the same 333 ms window. The "Why dry-fire flash is NOT rate-gated" rationale that previously appeared after §F.5 is REMOVED in this revision; AC-HUD-3.7 is authoritative; AC-HUD-4.5 is updated to assert the gate.)

**CR-9: Gadget-rejected visual is a 0.2 s desaturation via Timer.** On `gadget_activation_rejected(gadget_id)`, the active gadget tile sets `modulate = Color(0.4, 0.4, 0.4, 1.0)` for `gadget_rejected_desat_duration_s = 0.2` seconds, then reverts to `modulate = Color.WHITE`. Timer runs via a dedicated `_gadget_reject_timer: Timer` child (oneshot). No audio from HUD Core; Inventory §UI-9 owns the rejection SFX. (Justification: Inventory §UI-1..UI-9 specifies 0.2 s desat visual; dedicated Timer keeps frame budget clean.)

**CR-10: HUD parent visibility tied to InputContext via signal subscription.** On `ui_context_changed(new_ctx, prev_ctx)`: HUD root sets `visible = (new_ctx == InputContext.Context.GAMEPLAY)`. Initial value at `_ready()`: `visible = (InputContext.current() == InputContext.Context.GAMEPLAY)` (one-time read at scene init, not per-frame). HUD never polls `InputContext.current()` in `_process()`. **REV-2026-04-25 — naming correction**: previously this CR used `InputContextStack.Context.GAMEPLAY` (class-name form). Per ADR-0004 §Implementation Guideline 2, call sites must use the autoload key (`InputContext.Context.*`), not the class name (`InputContextStack.Context.*`). The autoload key is `InputContext`; the class is `InputContextStack`. (Justification: signal-driven contract; ADR-0002 amendment to add `ui_context_changed` is Coord item §C.5#1; ADR-0004 autoload-key naming convention.)

**CR-11: Crosshair widget gates on parent visibility AND Settings.crosshair_enabled.** The crosshair `Control` child is visible iff `(hud_root.visible == true) AND (_crosshair_enabled_mirror == true)`. The mirror is updated on `setting_changed("accessibility", "crosshair_enabled", value)` from Settings & Accessibility (forward-dep on system #23). The `accessibility` category is the single canonical home per Settings CR-2 (revised 2026-04-26 PM); HUD subscribes under `accessibility`, NOT `hud` (B3 from /review-all-gdds 2026-04-27 — closed by 2026-04-27 sweep). Initial value at `_ready()`: false (until Settings & Accessibility emits the initial value during its boot, which happens before the HUD scene receives input — verified at integration time, OQ-HUD-3). (Justification: Pillar 5 — crosshair is the only opt-out exception to the no-centre-chrome rule; settings toggle must take effect immediately.)

**CR-12: Prompt-strip state machine — 2 MVP states (REV-2026-04-26 per D4).** Prompt-strip is in exactly one of two states at any instant: `HIDDEN` or `INTERACT_PROMPT`. **TAKEDOWN_CUE removed from MVP entirely** — `_takedown_eligible` latch deleted, `takedown_availability_changed` ADR-0002 amendment withdrawn from MVP scope (see §C.5 Coord items), AC-HUD-6.3 and AC-HUD-6.4 deleted. The cockpit-dial fantasy holds that takedown eligibility never required HUD acknowledgment; SAI body-language alone signals affordance (CAI/SAI Pillar 5 absolute). OQ-HUD-7 is closed (Path A finalised — no MVP implementation surface). Priority is trivial with two states: `INTERACT_PROMPT` if eligible, else `HIDDEN`. Resolver evaluates each `_process()` frame from the PC queries (CR-3). Full transition logic: §C.3. **MEMO_NOTIFICATION is deliberately deferred to HUD State Signaling (system #19)** — HUD Core MVP does not include pickup-toast lifecycle. (Justification: D4 user adjudication; cockpit-dial fantasy enforcement; eliminates Path-C gravity-well risk identified in re-review.)

**CR-13: INTERACT_PROMPT suppressed during `pc.is_hand_busy()` window — REV-2026-04-26 simplified.** When `pc.is_hand_busy()` returns `true` (PC's pre-reach + reach window), the `INTERACT_PROMPT` state is suppressed even if `pc.get_current_interact_target()` returns non-null. (Justification: PC §UI Requirements specifies `is_hand_busy()` suppresses interact prompt. The TAKEDOWN_CUE exemption clause that previously appeared here is removed — TAKEDOWN_CUE no longer exists in MVP scope per D4.)

**CR-14: LOAD_FROM_SAVE rebuilds via signal replay, not direct query.** HUD Core does NOT register a `register_restore_callback` with `LevelStreamingService`. On `LOAD_FROM_SAVE`: at scene `_ready()`, all widget values initialise to zero/empty defaults. The Level Streaming Service's restore-callback sequence re-emits relevant signals (`player_health_changed`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `ui_context_changed`) with restored values; HUD receives these and updates widgets identically to live gameplay. (Justification: keeps HUD's contract purely signal-driven; eliminates the special-case initialisation path that contributed to the F&R split-brain defect.)

**CR-15: HUD persists across section transitions without re-subscribing.** HUD Core is instanced once per main scene (game session). On `section_entered`, HUD does NOT disconnect/reconnect signals. Cached state from prior-section signals (`_last_ammo_current`, etc.) remains in memory; the next signal emission overwrites it naturally. Section transitions where no weapon is drawn produce a momentary blank ammo widget — this is correct (no ammo to show). (Justification: ADR-0007 HUD is NOT autoload but IS session-persistent; re-subscribing risks double-connect bugs.)

**CR-16: HUD emits zero signals.** HUD Core calls zero `Events.[signal].emit(...)`. Defines zero `signal` of its own. Does not push or pop `InputContext`. (Justification: ADR-0002 subscriber-only contract; HUD is presentation, not logic.)

**CR-17: HUD does not store gameplay state — only display caches.** HUD caches only the most recent values of each widget's display variables (`_current_health`, `_max_health`, `_weapon_id`, `_ammo_current`, `_ammo_reserve`, `_gadget_id`, `_was_critical`, `_flashing`, `_pending_flash`, `_pending_dry_fire`, `_last_ammo_*`, `_last_interact_label_key`, `_cached_interact_label_text`, `_cached_static_prompt_prefix`, `_current_interact_glyph`, `_last_state`, `_last_prompt_text`, `_crosshair_enabled_mirror`). **REV-2026-04-26**: `_takedown_eligible` removed per D4. It does NOT store derived gameplay conclusions ("player is in danger", "ammo is low"). Conclusions are made by upstream systems and communicated via signals. HUD renders what it receives; it does not interpret. (Justification: any gameplay logic in HUD creates hidden coupling and inverts dependency arrows.)

**CR-18: All rendered strings pass through `tr()`; static labels cached at `_ready()`.** Every visible string — weapon names (`tr(weapon_id)`), gadget names (`tr(gadget_id)`), prompt labels (`tr("HUD_INTERACT_PROMPT")`, `tr("HUD_TAKEDOWN_AVAILABLE")`) — flows through `tr()`. String identifiers follow Localization Scaffold convention. **`tr()` is called once at scene `_ready()` for static labels and cached** (per godot-specialist Item 3 — `tr()` traversal cost is non-trivial; per-frame calls would breach the 0.3 ms cap). Static labels re-resolve only on `setting_changed("locale", _, _)`. The HUD never renders a raw GDScript string literal as visible text. (Justification: Localization Scaffold upstream dep; per-frame `tr()` is FP-8 forbidden.)

**CR-19: All HUD numerals use `FontRegistry.hud_numeral(physical_size_px)` with scale-aware size — REV-2026-04-25.** Health, ammo (consolidated), and any numeric widget calls `FontRegistry.hud_numeral(physical_size_px)` to resolve typeface; the 18 px floor substitution (Futura → DIN per Art Bible §7B/§8C) is transparent. **REV-2026-04-25 — scale-aware argument**: previously the call passed the design-pixel size (e.g., 22) ignoring the F.3 `scale_factor`, which meant the 18 px floor never fired at 720p (effective rendered size was 14.7 px but FontRegistry was told "22"). The corrected pattern is to pass the **physical** size: `FontRegistry.hud_numeral(int(round(design_size_px * scale_factor)))` where `scale_factor` comes from F.3. **Called once per Label at scene `_ready()`** AND **re-called on `viewport.size_changed`** (single batched call within the existing `_update_hud_scale()` handler, not per-frame). Never called from `_process` (FP-9). At 720p with design size 22 px: `int(round(22 × 0.667)) = 15` → below 18 px floor → FontRegistry returns DIN 1451 Engschrift. At 1080p: `int(round(22 × 1.0)) = 22` → above floor → returns Futura Condensed Bold. The 720p slash glyph (consolidated single Label, 22 px design): `int(round(22 × 0.667)) = 15` → DIN substitution applies. (Justification: ADR-0004 FontRegistry encapsulates substitution; the substitution must fire on actual rendered pixels, not design-pixel notation; layout-time + resize-time calls only.)

**CR-20: HUD has no `capture()` and registers no restore callback.** Nothing in HUD is serialised. On session restore, HUD rebuilds entirely from signal replay per CR-14. (Justification: HUD state is a pure function of upstream state; ADR-0003 SaveGame schema does not include a HUD sub-resource — and must not.)

**CR-21: Prompt-strip input glyph is runtime-rebound from Input system, NOT a static literal — REV-2026-04-26 (NEW).** The prompt-strip text composed by `_compose_prompt_text()` (§C.3) does NOT use a literal `[E]` or `[F]` token. Instead, HUD Core mirrors `_current_interact_glyph: String` from the Input system (forward-dep — Input GDD pending). Two valid Input GDD contracts close this:
- **(a) Query API**: `Input.get_glyph_for_action(action_name: StringName) -> String` — HUD calls once per `weapon_switched`-style event AND on Input's `binding_changed` signal (subscribed in CR-1 once Input GDD is authored — currently a forward-dep placeholder). HUD never calls this in `_process` (per FP-9-style cost rule).
- **(b) Signal-driven cache**: HUD subscribes to `Input.binding_changed(action: StringName, glyph: String)` and updates `_current_interact_glyph` on each emission. The mirror cache is read by `_compose_prompt_text()` per frame at zero `tr()` cost.

HUD Core MVP requires the Input GDD to commit to one of these contracts before sprint planning closes (gamepad players otherwise see keyboard `[E]` glyphs in every prompt). The default at MVP-development time, until Input GDD is authored, is a placeholder constant `_current_interact_glyph = "[E]"` (matching legacy literals); this placeholder MUST be replaced before MVP ship. (Justification: Pillar — gamepad input is a supported input method per technical-preferences; static keyboard literals exclude gamepad players Day-1.)

**CR-22: HUD Tweens are killed on every `ui_context_changed` transition leaving GAMEPLAY — NEW 2026-04-28 per `/review-all-gdds` 2026-04-28 finding 2b-4.** Setting `hud_root.visible = false` does NOT stop running `Tween` nodes in Godot 4.6 — Tween animations continue to tick and consume frame budget on hidden Control children. Document Overlay UI's CR-14 Slot-7 sole-occupant claim (`document-overlay-ui.md`) requires HUD Core to hold zero residual cost during DOCUMENT_OVERLAY READING; without this rule, HUD's damage-flash Tween, dry-fire Tween, and any future widget tweens continue running under the overlay and break the Slot-7 budget. **Implementation**: HUD Core's `_on_ui_context_changed(new_ctx, old_ctx)` handler (CR-1 / CR-10 subscriber to `Events.ui_context_changed` per ADR-0002 2026-04-28 amendment) MUST call `Tween.kill()` on every active widget tween (`_damage_flash_tween`, `_dry_fire_tween`, `_gadget_reject_desat_tween`, plus any other tween references HUD root holds) when `new_ctx != Context.GAMEPLAY`. Tweens are NOT resumed on return to GAMEPLAY — visual flash effects are transient and re-fire from the next signal, not from a paused state. Justification: Pillar 5 (the period HUD must be unequivocally absent during Document Overlay's Lectern Pause), and ADR-0008 Slot-7 budget compliance. **Forbidden pattern (added under FP-9-style rule)**: subscribing tween-driven Control nodes that survive context changes without explicit `Tween.kill()` registration. AC-HUD-9.X (NEW) covers the kill-on-transition assertion; CI grep enforces presence of `Tween.kill()` calls inside `_on_ui_context_changed` handler. (Closes Document Overlay UI OQ-DOV-COORD-14 + AC-DOV-9.2 Slot-7 sole-occupant precondition.)

### C.2 Widget Grammar & Anchors

All anchors specified at 1080p reference; scale rule below the table.

| Widget | Anchor preset | Position offset @1080p | Internal layout | Tree-order z | Persistence | Signals consumed |
|---|---|---|---|---|---|---|
| **Health field** | `ANCHOR_PRESET_BOTTOM_LEFT` | margin-left 32 px / margin-bottom 32 px / size 120 × 28 px | `HBoxContainer`: `Label "HP"` (60% size, Parchment) + `Label numeral` (Parchment, right-aligned, 22 px Futura/DIN) | 0 (back) | Always-visible while HUD parent visible | `player_health_changed`, `player_damaged` (flash) |
| **Weapon + Ammo field** | `ANCHOR_PRESET_BOTTOM_RIGHT` | margin-right 32 px / margin-bottom 32 px / size 160 × 56 px (two lines) | `VBoxContainer`: `Label weapon_name` (condensed caps, 13 px) + **`Label ammo_combined`** (single Label with formatted string `"%d / %d" % [current, reserve]`, 22 px Futura/DIN, right-aligned). **REV-2026-04-25 — Label consolidation**: previously 3 separate Labels (`current` / `"/"` / `reserve`) — merged into 1 to reduce F.5 worst-case Label count by 2 and stay under ADR-0008 Slot 7 cap. The 70%-numeral-width slash precision per Art Bible §7A is now achieved via a single typeface choice; if Art Director requires precise 70% scaling on the slash glyph specifically, restore the 3-Label form via a future revision and amend ADR-0008 (see OQ-HUD-5 path b). | 1 | Always-visible while HUD parent visible (Slot 4 blade renders dash `—` for ammo; Slot 3 rifle pre-pickup renders dash for both name and ammo) | `weapon_switched`, `ammo_changed` |
| **Gadget tile** | `ANCHOR_PRESET_TOP_RIGHT` | margin-right 32 px / margin-top 32 px / size 56 × 56 px | `Control` with `_draw()` override drawing tile background + icon `TextureRect` + sound-wave glyph `TextureRect` (upper-right, ~12 × 12 px, only on noisy gadgets) | 2 | Always-rendered; **modulate alpha 0.4 when no gadget equipped** | `gadget_equipped`, `gadget_activation_rejected` |
| **Prompt-strip** | `ANCHOR_PRESET_CENTER_BOTTOM` | y-offset −18% from bottom-edge / horizontally centered / size auto @ 14 px font | Single `Label` (Futura Condensed Bold, 14 px, Parchment on BQA Blue strip — uses StyleBoxFlat from `hud_theme.tres`) | 3 | Visible only in non-HIDDEN state (§C.3 state machine) | `pc.get_current_interact_target()` (poll), `pc.is_hand_busy()` (poll). **REV-2026-04-26**: `takedown_availability_changed` removed per D4. |
| **Crosshair** | `ANCHOR_PRESET_CENTER` | viewport center | `Control` subclass with `_draw()` override (`draw_circle(center, dot_radius)` + tri-band halo via `draw_arc`) | 4 (front of HUD widgets, but below ADR-0004 §7 layer 4 sepia dim) | Visible iff parent.visible AND `_crosshair_enabled_mirror` (CR-11) | `setting_changed("accessibility", "crosshair_enabled", _)` |

**Scale rule — REV-2026-04-26 method form propagated.** HUD root's `Control` child calls `set_anchors_preset(Control.PRESET_FULL_RECT)` (method form, not the property assignment `anchors_preset = ANCHOR_PRESET_FULL_RECT` which is a silent no-op in Godot 4.6 per godot-specialist Finding). All widget anchor presets in this GDD are likewise authored via `set_anchors_preset(Control.PRESET_*)`. **Pixel offsets (margins) are the design values at 1080p reference; viewport-height scaling is handled by setting each widget Control's `scale = Vector2(1, 1) * (get_viewport().size.y / 1080.0)` once at `_ready()` and again on `get_viewport().size_changed`** (single signal subscription, not per-frame). Widget contents (font sizes, padding) are sized in *design pixels*; the parent scale propagates. **Crosshair is NOT parented under the scaled root** — the crosshair `Control` is a sibling of the scale-root, anchored to viewport center directly, and uses physical-pixel `dot_radius_px` per F.4 without secondary scale multiplication (REV-2026-04-26 — closes the F.4×F.3 sub-pixel risk: at 720p with `dot_radius_px = 3` clamped, the crosshair renders at a true 3 physical pixels, not 2 after scale). **Ultrawide (21:9 / 32:9) clamping**: corner widgets stay anchored to corners (always inside safe area); the prompt-strip's `ANCHOR_PRESET_CENTER_BOTTOM` keeps it centered horizontally regardless of aspect, so 21:9/32:9 widen the playable area without affecting prompt visibility. **No HUD-scale slider at MVP** — Settings & Accessibility may add one as a forward-dep (OQ-HUD-1).

**Dual-focus split exemption (REV-2026-04-26 — explicit per-widget annotation per godot-specialist Finding 8 + Godot 4.6 HIGH-RISK):** every HUD `Control` (root, MarginContainers, HBox/VBox, Labels, PanelContainers, the crosshair Control) sets BOTH `mouse_filter = MOUSE_FILTER_IGNORE` AND `focus_mode = Control.FOCUS_NONE`. The root `Control` additionally uses Godot 4.5+ recursive disable (`set_meta("focus_disabled_recursively", true)` — exact API name pending ADR-0004 Gate 1 verification) to propagate to dynamically-added children (HSS extension nodes). This is BLOCKING-for-sprint verification on Godot 4.6 dual-focus split.

### C.3 Prompt-Strip State Machine — REV-2026-04-26 (2 states, was 3)

| State | Renders | Trigger source |
|---|---|---|
| `HIDDEN` | Nothing (Label `visible = false`) | Default; no eligible state |
| `INTERACT_PROMPT` | `tr("HUD_INTERACT_PROMPT")` + the runtime-rebound input glyph (see CR-21) + cached `tr(target.interact_label_key)` (e.g., "PRESS [E] TO LIFT COVER" with `[E]` substituted by the player's bound key) | `pc != null` AND `pc.get_current_interact_target() != null` AND `!pc.is_hand_busy()` (CR-13) |

**Transition resolver — REV-2026-04-26.** Each `_process(_delta)` frame, HUD evaluates:
```gdscript
# REV-2026-04-26 — TAKEDOWN_CUE removed per D4. Two-state machine.
# CR-3 null guard: pc may be null pre-injection.
if pc == null:
    state = HIDDEN
elif pc.get_current_interact_target() != null and not pc.is_hand_busy():
    state = INTERACT_PROMPT
else:
    state = HIDDEN
```

**`_compose_prompt_text()` — DEFINED REV-2026-04-26 (was undefined; FP-8 violation closed).** The dynamic component `tr(target.interact_label_key)` is cached against `_last_interact_label_key: StringName`. The static prefix `tr("HUD_INTERACT_PROMPT")` is cached at `_ready()` per CR-18. The runtime-rebound key glyph is read from `_current_interact_glyph: String` mirror (CR-21).

```gdscript
func _compose_prompt_text(state: int, target: Node) -> String:
    if state != INTERACT_PROMPT:
        return ""
    if not is_instance_valid(target):
        return ""
    var key: StringName = target.interact_label_key
    if key != _last_interact_label_key:
        _cached_interact_label_text = tr(key)  # tr() called ONLY on key change
        _last_interact_label_key = key
    return _cached_static_prompt_prefix + _current_interact_glyph + " " + _cached_interact_label_text
```

This guarantees `tr()` is called only when the interact target's label key changes — never per-frame. FP-8 compliant. The change-guard below operates on the composed string output, not on `Label.text` reads (avoiding the `Label.text` getter cost per godot-specialist):

```gdscript
var new_state := _resolve_prompt_state()
var new_text := _compose_prompt_text(new_state, _current_target)  # cached internally
if new_state != _last_state or new_text != _last_prompt_text:
    _label.text = new_text
    _label.visible = (new_state != HIDDEN)
    _last_state = new_state
    _last_prompt_text = new_text  # mirror; avoids reading Label.text
```

**Show/hide animation.** Instant per Art Bible §7D ("HUD update animations: instant"). Prompt-strip appears and dismisses on the same frame the resolver decides. No 12-frame fade (that's Document Overlay's grammar, not HUD's). (Justification: cockpit-dial fantasy — a dial does not animate when it changes state.)

**No auto-dismiss timer at MVP in HUD Core.** REV-2026-04-26 — INTERACT_PROMPT is the only MVP state and is *latch-driven* (hides as soon as its underlying conditions become false). HUD State Signaling (system #19) DOES introduce auto-dismiss timers for its own states (e.g., the HoH/deaf alert-state cue per UI-2 row, ~2 s auto-dismiss). The HSS-side timer lives inside HSS, NOT in HUD Core's §C.3 — HSS adds itself to the resolver via the `get_prompt_label()` extension API and manages its own dismiss timer state.

### C.4 Damage-Flash Coalescing Lifecycle **REV-2026-04-25 — re-entry guard + freed-self guard added**

The HUD holds a single `_flash_timer: Timer` child (oneshot, `wait_time = 0.333`), a single `_pending_flash: bool` latch, and a single `_flashing: bool` re-entry guard *(REV-2026-04-25 — added)*. On `player_damaged`:
1. If `_flash_timer.is_stopped()` (gate open) AND `not _flashing`: execute the 1-frame flash (set `_flashing = true`; `add_theme_color_override(&"font_color", Color.WHITE)` + capture `revert_color := _current_health_color` BEFORE `await` + `await get_tree().process_frame` + `if not is_instance_valid(self): return` *(REV-2026-04-25 — freed-self guard)* + revert via `add_theme_color_override(&"font_color", revert_color)` + set `_flashing = false`); start the timer.
2. Else if `_flash_timer.is_stopped()` AND `_flashing` (rare race — concurrent emission while a flash coroutine is suspended): set `_pending_flash = true`; do not start a second coroutine. (Re-entry guard.)
3. Else (gate closed): set `_pending_flash = true`; do not flash.

On `_flash_timer.timeout`:
- If `_pending_flash` AND `not _flashing`: execute the deferred flash (same path as immediate flash, including the `is_instance_valid(self)` guard after `await`); restart the timer; clear `_pending_flash = false`.
- Else: timer simply ends; system idle.

**REV-2026-04-25 — re-entry/freed-self rationale**: GDScript signal handlers can fire re-entrantly when the engine processes multiple events in the same physics tick. `await get_tree().process_frame` suspends the coroutine for one rendered frame; during that gap, a second `player_damaged` could arrive. Without `_flashing`, two coroutines race to call `add_theme_color_override` on the same Label — the timing is non-deterministic. The `_flashing` flag funnels the second event into the `_pending_flash` latch, preserving the rate-gate invariant. The `is_instance_valid(self)` guard after `await` covers the case where HUD is freed (scene reload, `LOAD_FROM_SAVE` re-instantiation) between the flash start and the revert frame — without the guard, the resumed coroutine would call `add_theme_color_override` on a freed `self` and crash.

**Reset semantics.**

| Trigger | `_flash_timer` | `_pending_flash` |
|---|---|---|
| `_ready()` | stopped | `false` |
| `player_died` | stopped (suppress queued flash on death) | `false` |
| `section_entered` | not reset (gate carries across sections) | not reset |
| `LOAD_FROM_SAVE` | stopped (HUD scene re-instantiated per CR-14) | `false` |

**Maximum flash rate**: 3.0 Hz under any damage pattern (WCAG 2.3.1 compliant). Audio SFX and camera dip are NOT rate-limited — only the visual flash. Full algorithm with worked example: §F.1.

### C.5 Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| **Player Character ✅** | inbound (signals + queries) | Subscribes: `player_health_changed`, `player_damaged`, `player_died`, `player_interacted`. Polls (`_process`): `pc.get_current_interact_target()`, `pc.is_hand_busy()`. **Frozen API per PC §UI Requirements.** |
| **Combat & Damage ✅** | inbound (one constant + one signal indirect) | Reads constant `hud_damage_flash_cooldown_ms = 333` from registry (compile-time). Reads `crosshair_dot_size_pct_v = 0.19%`, `crosshair_halo_style = tri_band` from registry. **HUD owns the crosshair widget; Combat owns the constants** per Combat §UI-1..UI-6. No direct API calls. |
| **Inventory & Gadgets ✅(pending coord)** | inbound (signals only) | Subscribes: `ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected`. **HUD does NOT subscribe to `weapon_dry_fire_click`** (Audio's exclusive subscription per ADR-0002 amendment 2026-04-24); dry-fire detection via CR-8 unchanged-value pattern. |
| **Stealth AI ✅** | none **(REV-2026-04-26 — was inbound; D4 cut TAKEDOWN_CUE from MVP)** | HUD Core MVP does not subscribe to any SAI signal. SAI body-language cues alone signal takedown affordance (Pillar 5 absolute). The previously-flagged `takedown_availability_changed` ADR-0002 amendment is WITHDRAWN from MVP scope. **Forbidden non-dep at MVP.** |
| **Civilian AI ✅** | none | Pillar 5 zero-UI absolute — civilians never appear in HUD. **Forbidden non-dep.** |
| **Failure & Respawn ✅(pending coord)** | none (HUD is hidden during respawn flow) | F&R has empty UI. HUD's parent visibility toggles to `false` on `ui_context_changed` to non-GAMEPLAY contexts during the respawn input-blocked window. **Forbidden non-dep.** |
| **InputContext (ADR-0004 autoload)** | inbound (signal — NEW) | Subscribes: `ui_context_changed(new_ctx: InputContextStack.Context, prev_ctx: InputContextStack.Context)` *(NEW — ADR-0002 amendment, see Coord item §C.5#1)*. Drives HUD parent visibility (CR-10). |
| **Settings & Accessibility (system #23, Not Started) — HARD MVP DEP (REV-2026-04-26 per D2; category swept 2026-04-27 closing B3)** | inbound (signal + UI delivery path) | Subscribes: `setting_changed("accessibility", "crosshair_enabled", value)`, `setting_changed("accessibility", "damage_flash_enabled", value)`, `setting_changed("locale", _, _)`. The `accessibility` category is the single canonical home for both keys per Settings CR-2 + line 180. **HUD Core MVP is BLOCKED until Settings #23 ships a minimal Day-1 slice**: the photosensitivity-toggle UI (`damage_flash_enabled`), the crosshair-toggle UI, and a boot-screen photosensitivity warning that links to the toggle. The stub `Settings.get_setting()` accessor is a development scaffold ONLY; cert/legal/GAAD compliance requires a player-findable UI before first photosensitive stimulus. |
| **Localization Scaffold ✅** | inbound (function only) | All visible strings via `tr()`. Re-resolves static labels on `setting_changed("locale", _, _)`. |
| **HUD State Signaling (system #19, Not Started) — HARD MVP DEP (REV-2026-04-26 per D3)** | outbound (extension) + inbound (HoH/deaf alert-cue minimal slice) | **HoH/deaf alert-cue minimal slice is HARD MVP dep**: HSS #19 must ship a Day-1 brief text-only alert-state cue (`tr("HUD_GUARD_ALERTED")`, ~2 s auto-dismiss, period-typographic) that writes through `get_prompt_label()` to satisfy WCAG 1.1.1 / 1.3.3 + EU GAAD. HSS Day-1 scope is narrow — the alert-cue only; MEMO_NOTIFICATION + alarm-state stinger remain VS-tier. The HSS-side auto-dismiss timer lives inside HSS, NOT in HUD Core's §C.3 (HUD Core's 2-state machine has no auto-dismiss path; HSS must add itself to the resolver via the published extension API). **HUD Core MVP defines the `_prompt_strip_label: Label` child node and exposes `get_prompt_label() -> Label`** (single forward extension point). |
| **Audio (system 3) ✅** | none directly | Audio owns the clock-tick SFX paired with critical-state colour shift; HUD's job is the visual; Audio subscribes to `player_health_changed` independently and runs its own threshold detection. **HUD does NOT trigger Audio.** |
| **ADR-0001 Stencil** | none | UI is screen-space; no stencil writes from HUD. |
| **ADR-0002 Signal Bus** | inbound (subscriber) | HUD subscribes to 9 Events bus signals (8 frozen + 1 amendment `ui_context_changed`; `takedown_availability_changed` removed per D4). Plus 5 non-Events connections (1 Settings, 3 Timer, 1 viewport) for 14 total per CR-1. Emits zero. |
| **ADR-0003 Save Format** | none | HUD has no `capture()`; no SaveGame sub-resource; no restore callback (CR-20). |
| **ADR-0004 UI Framework (Proposed)** | inbound (Theme + FontRegistry + InputContext) | HUD inherits `project_theme.tres` via `hud_theme.tres`. Uses `FontRegistry.hud_numeral(size)`. Reads `InputContext.current()` once at `_ready()` only. Subscribes to `ui_context_changed` thereafter. |
| **ADR-0007 Autoload Order** | none | HUD is NOT an autoload. |
| **ADR-0008 Performance Budget** | binding (Slot 7 = 0.3 ms) | HUD enforces signal-driven-only refresh + 1 per-frame poll for prompt-strip resolver. CI gate validates p95 cost on Restaurant reference scene. |

#### Pre-implementation Coord items (BLOCKING)

1. **ADR-0002 amendment**: add `signal ui_context_changed(new_context: InputContext.Context, previous_context: InputContext.Context)` to UI domain. Argument type uses the autoload-key form `InputContext.Context` per ADR-0004 Implementation Guideline 2. Emitter: `InputContext` autoload at end of `push()` and `pop()`. Subscribers (initial): HUD Core (CR-10). (Owner: tech-lead via `/architecture-decision adr-0002-amendment` bundle.)
2. ~~**ADR-0002 amendment**: add `signal takedown_availability_changed(eligible: bool, target: Node3D)` to Stealth AI domain.~~ **WITHDRAWN REV-2026-04-26 per D4** — TAKEDOWN_CUE removed from MVP entirely; no SAI signal subscription needed at MVP.
2b. **NEW REV-2026-04-26 — Settings & Accessibility (system #23) Day-1 minimal-UI dep**: Settings #23 must ship a Day-1 minimal slice covering (a) `damage_flash_enabled: bool` toggle UI, (b) `crosshair_enabled: bool` toggle UI, (c) boot-screen photosensitivity warning that links to (a). HUD Core MVP is BLOCKED until this ships. Owner: producer (schedule); ux-designer (Settings #23 minimal-UI authoring).
2c. **NEW REV-2026-04-26 — HUD State Signaling (system #19) Day-1 alert-cue dep**: HSS #19 must ship a Day-1 minimal slice covering the brief text-only alert-state cue (`tr("HUD_GUARD_ALERTED")`, ~2 s auto-dismiss, written through `HUDCore.get_prompt_label()`). HUD Core MVP is BLOCKED until this ships. Owner: producer (schedule); narrative-director or audio-director (HSS #19 minimal-slice authoring).
3. **ADR-0004 Gate 2 (Theme inheritance property name)**: confirm whether the property is `base_theme` or `fallback_theme` on the `Theme` resource in Godot 4.6 — godot-specialist flagged the ADR's `base_theme` claim as unverified against training data which expects `fallback_theme`. **REV-2026-04-25 — silent-failure risk**: the wrong name does NOT raise an error in Godot — the property write succeeds against a non-existent property, theme inheritance silently does not apply, and `hud_theme.tres` overrides fall back to project_theme defaults producing visually wrong output. Resolution required before authoring `hud_theme.tres`. (Owner: lead programmer via 5-minute editor inspection — open a `Theme` resource in the 4.6 inspector and read the inheritance property name.)
4. **ADR-0004 Gate 1 (`accessibility_live` property name)**: confirm the exact property name on Godot 4.6 Label/Control for AccessKit live-region suppression. **REV-2026-04-25 — promoted from "deferrable to Polish"**: the property name MUST be confirmed before any code references it (even if AccessKit feature work itself is Polish-tier), to avoid baking `accessibility_live = "off"` into source as a typo. (Owner: lead programmer.)
5. **REV-2026-04-25 — NEW: Godot 4.6 API verification batch (BLOCKING before §V authoring)**: confirm via 4.6 editor inspection or doc lookup the following API names referenced throughout this GDD. All are flagged unverified by godot-specialist; wrong names produce silent failures. (Owner: lead programmer; ~30-min batch task.)
   - `Color(hex_string, alpha)` 2-argument constructor — verify it exists in 4.6 OR migrate every `Color("#hex", alpha)` call in §V.1 to `Color("#hex").with_alpha(alpha)` or 4-float form `Color(r, g, b, a)`.
   - `TextureRect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL` — verify the enum identifier exists exactly as written; the GDD's prior bare form `FIT_WIDTH_PROPORTIONAL` (without the `TextureRect.EXPAND_` prefix) is incorrect.
   - `set_anchors_preset(Control.PRESET_FULL_RECT)` (method, not property assignment) — verify that `anchors_preset = ANCHOR_PRESET_*` is NOT settable as a property in code (silent no-op) and that the method form is the correct API. Update §C.2 scale rule and any code-form references accordingly.
   - `Performance.TIME_PROCESS` constant — godot-specialist flagged this as not a valid 4.x `Performance` monitor identifier. Verify; if invalid, AC-HUD-9.1's measurement methodology already uses `Time.get_ticks_usec()` bracketing as the corrected approach.
   - `await get_tree().process_frame` — verify `process_frame` is the correct `SceneTree` signal name in 4.6 (not `idle_frame`). godot-specialist confirmed this is correct in 4.x but version-pinned verification is required.
   - `Label.add_theme_color_override(&"font_color", color)` — verify `font_color` is the correct theme key for `Label` font colour in 4.6 (not `Label/font_color` or `colors/font_color` from older versions).
   - `Control.focus_mode = Control.FOCUS_NONE` — verify this is the default for `Label` nodes; if not, every HUD Control must explicitly set it (per godot-specialist Finding 8: dual-focus split exemption requires both `mouse_filter = MOUSE_FILTER_IGNORE` AND `focus_mode = FOCUS_NONE`).
   - `Theme` `corner_radius_*` shorthand: confirm `StyleBoxFlat` exposes the four properties as `corner_radius_top_left`, `corner_radius_top_right`, `corner_radius_bottom_left`, `corner_radius_bottom_right` (the §V.1 tables use the wildcard notation; implementation must set all four individually).

#### Pre-implementation Coord items (ADVISORY)

5. **Settings & Accessibility GDD (system #23)** — when authored, must define: (a) `crosshair_enabled: bool` setting persisted via SaveGame, (b) `crosshair_dot_size_pct_v: float` slider with safe range and default 0.19%, (c) `crosshair_halo_style: enum` with values `{none, parchment_only, tri_band}` and default `tri_band`, (d) `setting_changed` emit-site contract per ADR-0002 (signal already declared). HUD Core depends on this contract.
6. **HUD scale slider** as a Settings forward-dep (OQ-HUD-1) — not in HUD Core MVP scope.
7. **Combat §UI-6 dual-discovery path** for Crosshair — Settings & Accessibility GDD must surface both `Settings → HUD → Crosshair` and `Settings → Accessibility → Crosshair` entries with single source of truth.

#### Bidirectional consistency check

HUD Core's dependency list maps to:
- PC GDD §UI Requirements (frozen API) — match ✅
- Combat §UI-1..UI-6 (HUD owns crosshair, Combat owns constants) — match ✅
- Inventory §UI-1..UI-9 (HUD subscribes to 4 signals + dry-fire detection) — match ✅
- Civilian AI §UI Requirements (Pillar 5 zero-UI) — match ✅
- Failure & Respawn §UI (empty UI) — match ✅
- ADR-0004 (Theme + FontRegistry + InputContext + CanvasLayer indices) — match ✅
- ADR-0008 Slot 7 (0.3 ms cap) — match ✅
- HUD State Signaling (system #19, VS) — forward-extension via `get_prompt_label()` — sole forward API.

### C.6 Forbidden Patterns

Each pattern is grep-able for CI lint. Scope is `src/ui/hud_core/**/*.gd` and `src/ui/hud_core/**/*.tscn` unless noted.

**FP-1: No signal emission.** Pattern `Events\.[a-zA-Z_]+\.emit\(` — HUD is subscriber-only (CR-16; ADR-0002 contract).

**FP-2: No direct PC property access.** Pattern `pc\.(health|max_health|current_health|stamina|is_crouching|is_sprinting|inventory)` — All gameplay state arrives via signals (CR-4); only `pc.get_current_interact_target()` and `pc.is_hand_busy()` are authorised (CR-3).

**FP-3: No polling of Inventory/Combat/SAI/Civilian/F&R/MLS public methods.** Pattern `(InventorySystem|CombatSystemNode|StealthAI|CivilianAI|FailureRespawnService|MissionScriptingService)\.[a-zA-Z_]+\(` — Polling beyond the 2 PC accessors violates ADR-0008 0.3 ms cap (CR-3). **REV-2026-04-26**: takedown is no longer surfaced in HUD Core MVP per D4 (TAKEDOWN_CUE removed).

**FP-4: No runtime Resource instantiation.** Pattern `(WeaponResource|GadgetResource|preload|load)\([^)]*\.tres` — All resource references arrive in signal payloads (`gadget_equipped(gadget_id: StringName)`); HUD resolves display strings via `tr(gadget_id)`, not by loading the `.tres`.

**FP-5: No subscription to `weapon_dry_fire_click`.** Pattern `weapon_dry_fire_click\.connect` — Audio's exclusive subscription per ADR-0002 amendment 2026-04-24; HUD detects dry-fire via unchanged-value `ammo_changed` (CR-8).

**FP-6: No waypoint, minimap, objective marker, or alert-state visual indicator.** Pattern `(waypoint|minimap|objective_marker|alert_indicator|radar|compass|map_overlay|nav_arrow)` — Pillar 2 + Pillar 5 absolute exclusion. Not a tuning decision; categorical.

**FP-7: No InputContext push or pop.** Pattern `InputContext\.(push|pop|set)\(` — HUD reacts; never modifies (CR-16). Inverted dependency.

**FP-8: No `tr()` call in `_process` or `_physics_process`.** Pattern `(_process|_physics_process)\s*\([^)]*\)\s*->[^{]*\{[^}]*tr\(` — `tr()` is non-trivial cost per call (godot-specialist Item 3); per-frame call would breach 0.3 ms cap. Cache static labels at `_ready()` (CR-18).

**FP-9: No `FontRegistry.hud_numeral` with dynamic argument.** Pattern `FontRegistry\.hud_numeral\([^)]*delta[^)]*\)` (or any `_process`-derived expression) — Font resolution is layout-time; per-frame variable size argument defeats caching (CR-19).

**FP-10: No `Label.text = …` in `_process` without change-guard.** Pattern matches `_process` body containing `\.text\s*=` without preceding `if .* != .* :` — Setting `Label.text` invalidates TextServer; unconditional per-frame writes burn the 0.3 ms cap (godot-specialist Item 3).

**FP-11: No `RichTextLabel` in HUD.** Pattern `RichTextLabel` in any `.tscn` under HUD scope — ADR-0004 §11 reserves `RichTextLabel` for Document Overlay body; BBCode parsing overhead unacceptable for HUD frame budget.

**FP-12: HUD must not register a restore callback or implement `capture()`.** Pattern `(register_restore_callback|func capture\(\))` — CR-20; ADR-0003 SaveGame schema does not include a HUD sub-resource. HUD rebuilds from signal replay.

**FP-13: No HUD as autoload.** Pattern: any HUD path appearing in `project.godot` `[autoload]` section — HUD is per-main-scene `CanvasLayer`, not autoload; autoload count and slot allocation are owned by ADR-0007 (consult ADR-0007 §Canonical Registration Table for current count and ordering).

**FP-14: No `Engine.get_singleton(...)` or `get_tree().root.get_node(...)` for upstream-system lookup.** Pattern `(Engine\.get_singleton|get_tree\(\)\.root\.get_node)` — Project uses Events autoload signal pattern; raw tree-walk lookups bypass the signal contract and are anti-pattern.

## Formulas

### F.1 — Photosensitivity Rate-Gate (Damage-Flash Coalescing)

**Validation note** (systems-designer): the algorithm is a *state machine with a one-deep queue*, not a numerical formula. The eligibility predicate plus the deferred-emission invariant constitute the formula. **Batching of N hits in a single physics frame collapses to one decision**: the first opens the gate and fires; every subsequent one sets `_pending_flash = true`; on timeout, exactly one deferred flash fires. Queue depth is exactly 1 — flashing twice would still satisfy WCAG only if the inter-flash gap is ≥ 333 ms, which the timer guarantees. **Reset on `player_died`**: must call `_flash_timer.stop()` (not just `_pending_flash = false`) — `stop()` on an already-idle timer is a no-op in Godot 4.x.

The flash_eligibility formula is defined as:

`flash_may_fire = _flash_timer.is_stopped()`

`flash_fires = flash_may_fire OR (_flash_timer.timeout AND _pending_flash)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Timer stopped state | `_flash_timer.is_stopped()` | bool | {true, false} | True when the 333 ms rate-gate window has elapsed or the timer was never started |
| Pending flash flag | `_pending_flash` | bool | {true, false} | Set to true when a hit arrives while the gate is closed; cleared after the deferred flash fires |
| Flash cooldown | `T_gate` | float | 0.333 s (fixed) | Minimum interval between consecutive visible flashes — WCAG 2.3.1 ceiling of 3 Hz |
| Flash output | `flash_fired` | bool | {true, false} | Whether a visible flash is emitted in the current evaluation |

**Output Range:** 0 or 1 flashes per evaluation. Over any 1-second window, at most 3 flashes fire (3 Hz = WCAG 2.3.1 ceiling). Queue depth is exactly 1: if N hits arrive while the gate is closed, N − 1 are discarded and only one deferred flash fires on timeout.

**Example — 3 rapid hits at t = 0 ms, t = 150 ms, t = 250 ms:**
- t = 0 ms: gate open → flash fires, timer starts (fires at t = 333 ms), `_pending_flash = false`
- t = 150 ms: gate closed → `_pending_flash = true`
- t = 250 ms: gate closed, `_pending_flash` already true → no change (hit discarded)
- t = 333 ms: timer timeout → `_pending_flash` is true → deferred flash fires, timer restarts, `_pending_flash = false`

**Result: 2 flashes total** (t = 0 ms and t = 333 ms). Inter-flash gap = 333 ms. WCAG 2.3.1 compliant.

### F.2 — Critical-State Threshold Crossing (Edge-Triggered)

The critical_state_transition formula is defined as:

`health_ratio = clamp(current, 0, max_health) / max(max_health, 1.0)`

`threshold_ratio = player_critical_health_threshold / 100.0`

`critical = (health_ratio < threshold_ratio)`

`colour_state = Alarm_Orange if critical else Parchment`

Transition fires only when `critical != _was_critical` (edge-triggered, not level-triggered). **Pattern is identical to Audio GDD §Formula 4 entry condition** (`health_pct < clock_tick_threshold_pct / 100.0`) — both consume the registry constant `player_critical_health_threshold = 25` as a percentage value, divided by 100 at compute time.

**REV-2026-04-25 — hysteresis asymmetry vs Audio §F4 (intentional, documented)**: the original "pattern matches" claim was imprecise. Audio §F4 has an additional `tick_last_stopped_age_s >= clock_tick_debounce_s` (1 second) hysteresis on the *restart* path — Audio will not re-start the clock-tick within 1 second of a previous stop. HUD has zero hysteresis (CR-6 explicit). Under rapid 24↔25 HP oscillation (e.g., medkit micro-dosing while taking sustained damage), HUD will colour-flip Parchment ↔ Alarm Orange on every threshold crossing (every signal); Audio will suppress tick-restarts for 1 second. **This divergence is intentional**: HUD is a truthful dial that snaps to current state (cockpit-dial fantasy — see §Player Fantasy CR-6 rationale); Audio's clock-tick is a paced cue whose musical/diegetic identity is harmed by re-trigger spam. The two systems make independent decisions from the same signal source. Implementers must NOT add HUD-side hysteresis to "match Audio" — they are deliberately different.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current health | `current` | float | [0.0, max_health] | Eve's current HP from the `player_health_changed` signal payload |
| Maximum health | `max_health` | float | [1.0, unbounded] | Eve's maximum HP; clamped to ≥ 1.0 before division to prevent divide-by-zero |
| Health ratio | `health_ratio` | float | [0.0, 1.0] | Proportion of maximum health remaining |
| Critical threshold (registry) | `player_critical_health_threshold` | int | 25 (registry constant, percentage units) | The percentage threshold below which the alarm colour activates; PC-owned (registered as `25 hp` in entities.yaml — value is dimensioned as percentage / hp at the canonical max_health=100) |
| Critical threshold (ratio) | `threshold_ratio` | float | 0.25 (derived: `25 / 100.0`) | The HUD-side derived ratio for comparison against `health_ratio` |
| Previous critical state | `_was_critical` | bool | {true, false} | HUD-owned edge-detector; prevents redundant colour swaps on every signal |
| Colour output | `colour_state` | enum | {Parchment, Alarm_Orange} | The rendered health-bar accent colour |

**Output Range:** Two discrete values — Parchment `#F2E8C8` (ratio ≥ 0.25) or Alarm Orange `#E85D2A` (ratio < 0.25). No continuous gradient. The edge-triggered gate means the swap fires at most once per threshold crossing, not once per HP point.

**Divide-by-zero guard:** The `max(max_health, 1.0)` floor handles `max_health = 0.0` defensively. The signal contract (PC §UI Requirements) guarantees `max_health > 0` in practice; the floor is a belt-and-suspenders safety net, not the primary guard.

**Example:** Eve at 30 HP (threshold = 0.25, max = 100): `health_ratio = 30/100 = 0.30`. `critical = false`. `_was_critical = false`. No swap. Eve takes 6 damage → 24 HP: `health_ratio = 24/100 = 0.24`. `critical = true`. `_was_critical = false` → edge fires → swap to Alarm Orange, `_was_critical = true`. Eve takes 1 more damage → 23 HP: `critical = true`, `_was_critical = true` → no swap.

### F.3 — Viewport-Height Scale Function

The viewport_scale formula is defined as:

`scale_factor = clamp(viewport_height_px / reference_height_px, 0.667, 2.0)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Viewport height | `viewport_height_px` | int | [720, 2160] | Current render height in physical pixels from `viewport.size.y` |
| Reference height | `reference_height_px` | int | 1080 (fixed) | The resolution at which all design-pixel sizes were authored |
| Scale factor | `scale_factor` | float | [0.667, 2.0] | Applied to `Control.scale` (uniform x = y); 1.0 = design-pixel identity |

**Output Range:** 0.667 (720p) to 2.0 (4K/2160p) under supported resolutions. **Clamped — values below 720p or above 2160p do not extrapolate**; the clamp holds the HUD at the authored minimum or maximum size. Ultrawide aspect ratios are unaffected: only height drives the scale; widgets remain corner-anchored.

**Out-of-range behaviour:** Viewport heights below 720p (e.g. 540p) produce `scale_factor = 0.667` (clamped to minimum). Heights above 2160p produce `scale_factor = 2.0` (clamped to maximum). This is a deliberate policy: no HUD element shrinks below 720p proportions, which protects legibility on non-standard window sizes.

**Example:** 1440p: `scale_factor = 1440 / 1080 = 1.333`. 720p: `scale_factor = clamp(720/1080, 0.667, 2.0) = clamp(0.667, 0.667, 2.0) = 0.667`. 4K: `scale_factor = clamp(2160/1080, 0.667, 2.0) = 2.0`.

### F.4 — Crosshair Dot Radius (Resolution-Independent)

The crosshair_dot_radius formula is defined as:

`dot_radius_px = clamp(crosshair_dot_size_pct_v × viewport_height_px / 100.0, dot_radius_px_min, dot_radius_px_max)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Dot size percentage | `crosshair_dot_size_pct_v` | float | (0.0, 100.0] — effective design range [0.1, 1.0] | Dot diameter as a percentage of viewport height; **owned by Combat GDD** (default 0.19 per registry) |
| Viewport height | `viewport_height_px` | int | [720, 2160] | Current render height in physical pixels |
| Minimum radius | `dot_radius_px_min` | int | 3 (fixed) | Combat §UI-1 minimum — below 3 px the dot is sub-pixel at most screen densities |
| Maximum radius | `dot_radius_px_max` | int | 12 (fixed) | Combat §UI-1 maximum — above 12 px the dot obscures the aim point |
| Output radius | `dot_radius_px` | int | [3, 12] | Rendered dot radius in physical pixels; truncated to int after clamp |

**Output Range:** Always [3, 12] integer pixels. The clamp prevents the percentage formula from producing sub-pixel or aim-obscuring sizes at any supported resolution. If `crosshair_dot_size_pct_v` is set below 0.1% or above 1.0% (via Settings), the formula remains arithmetically well-defined; the clamp simply fires at one end. No special-case needed — the clamp is the guard.

**Example:** 1080p default: `0.19 × 1080 / 100 = 2.052 → clamp(2.052, 3, 12) = 3`. 4K: `0.19 × 2160 / 100 = 4.104 → clamp(4.104, 3, 12) = 4`. 1440p: `0.19 × 1440 / 100 = 2.736 → clamp(2.736, 3, 12) = 3`. Extreme value (pct = 1.0%, 4K): `1.0 × 2160 / 100 = 21.6 → clamp(21.6, 3, 12) = 12`.

### F.5 — HUD Per-Frame Cost Composition **REV-2026-04-26 — single canonical formula; phantom Label removed; AC-HUD-9.2 reconciled**

**The single canonical worst-case formula** (no scenario variants — all worked examples below derive from this):

`C_frame = C_draw + C_poll + (C_label × N_label_updates) + (C_flash × flash_active) + (C_theme_override × N_theme_override_writes) + (C_resize × resize_events_this_frame) + C_a11y`

**Variables:**

| Variable | Symbol | Type | Range (estimated, **UNMEASURED on Godot 4.6 — see OQ-HUD-5**) | Description |
|----------|--------|------|-------|-------------|
| Crosshair `_draw()` cost | `C_draw` | float (ms) | **estimate [0.005, 0.020]** | Cost of 2 × 64-segment `draw_arc` + `draw_circle` per GAMEPLAY frame (§V.6). Always runs while crosshair visible; zero when crosshair disabled or HUD invisible. **Viewport-dependent**: `C_draw` at 4K may be 2–3× the 1080p figure; CI gate at 810p is conservative. |
| Interact-prompt poll cost | `C_poll` | float (ms) | estimate [0.002, 0.004] | Fixed per-frame: `pc != null` guard + `get_current_interact_target()` + `is_hand_busy()` + state eval + change-guard. Always runs. |
| Per-Label update cost | `C_label` | float (ms) | estimate [0.02, 0.05] **UNMEASURED on Godot 4.6** | Cost of a single `Label.text` write (TextServer invalidation). TextServer was reworked in Godot 4.4–4.5; upper-bound estimate may be low under Forward+ Mobile. **OQ-HUD-5 BLOCKING gate** measures this on Iris Xe Gen 12 / 4.6 / 810p before sprint. |
| Number of Label updates this frame | `N_label_updates` | int | **[0, 4]** *(REV-2026-04-26 — was 5; gadget-tile icon is a `TextureRect.texture` swap NOT a Label.text write, so gadget-slot is NOT counted)* | Maximum 4 simultaneous: health-numeral (1), weapon-name (1), consolidated ammo (1), prompt-strip (1). The "HP" sub-label and key-rect Label inside prompt-strip are static at `_ready()` (not signal-driven) and excluded from this count. 0 on idle frames. |
| Flash deferred-frame cost | `C_flash` | float (ms) | estimate [0.001, 0.005] | Cost of one `await process_frame` + revert `add_theme_color_override` write. Active at most 3 Hz (≤ 1 frame per 333 ms) per damage-flash gate or dry-fire gate independently. |
| Flash active this frame | `flash_active` | int | {0, 1, 2} *(REV-2026-04-26 — was bool)* | 0 normally; 1 on a damage-flash OR dry-fire-flash frame; 2 on the rare same-frame coincidence (independent timers). |
| Theme-override write cost | `C_theme_override` | float (ms) | estimate [0.005, 0.015] **UNMEASURED** | Cost of `add_theme_color_override(&"font_color", color)`: hash-map insert + `NOTIFICATION_THEME_CHANGED` propagation. Active on critical-state edges + flash start/revert. |
| Theme-override writes this frame | `N_theme_override_writes` | int | [0, 2] *(REV-2026-04-26 — corrected from 4)* | Same-frame maximum is 2: (a) critical-state edge transition (CR-5/6) + (b) flash start (the revert is on the *next* frame, not the same frame, so revert is NOT a same-frame term). |
| Resize handler cost | `C_resize` | float (ms) | estimate [0.001, 0.003] | Cost of `_update_hud_scale()` per `viewport.size_changed` emission. Layout-invalidation cascade fires on the subsequent frame and is bounded separately (see "Cascade cost" note below). |
| Resize events this frame | `resize_events_this_frame` | int | [0, ~30] | Typically 0 during gameplay; up to ~30 during window-resize drag (drag is mutually exclusive with active gameplay; CI gate excludes this term per below). |
| AccessKit overhead | `C_a11y` | float (ms) | estimate [0.005, 0.030] **UNMEASURED** *(REV-2026-04-26 — added)* | Per-frame accessibility-tree maintenance cost from AccessKit (active Day-1 even when `accessibility_live = "off"` per ADR-0004). Platform-dependent (Windows MSAA/UIAutomation polled while window focused). **Must be measured alongside `C_label` in OQ-HUD-5 batch.** |
| Total frame cost | `C_frame` | float (ms) | estimate [~0.013, ~0.30] **UNMEASURED** | HUD's contribution to ADR-0008 Slot 7 (cap = 0.3 ms). |

**Worked examples — derived from the single canonical formula:**

| Scenario | `C_draw` | `C_poll` | `C_label × N` | `C_flash × flash` | `C_t.o. × N_t.o.` | `C_a11y` | **Total** |
|---|---|---|---|---|---|---|---|
| Normal idle (crosshair on, no signals) | 0.013 | 0.003 | 0 | 0 | 0 | 0.015 | **~0.031 ms** |
| Typical combat frame (1 ammo change) | 0.013 | 0.003 | 0.035 (1×) | 0 | 0 | 0.015 | **~0.066 ms** |
| Flash + crit edge (flash fires + crit transition + 1 Label) | 0.013 | 0.003 | 0.035 (1×) | 0.003 | 0.020 (2×) | 0.015 | **~0.089 ms** |
| **Canonical worst case** (5 simul events + 1 flash + 1 crit edge): mid-estimate `C_label`, worst-case mid-range elsewhere | 0.020 | 0.004 | 0.140 (4×0.035) | 0.005 | 0.030 (2×0.015) | 0.030 | **~0.229 ms** |
| **Pessimistic worst case** (all UPPER bounds simultaneously): | 0.020 | 0.004 | 0.200 (4×0.050) | 0.005 | 0.030 (2×0.015) | 0.030 | **~0.289 ms** |

**Cap headroom**: pessimistic worst case (~0.289 ms) leaves **~11 µs headroom against the 0.3 ms cap** under fully-upper-bound estimated constants. This is materially thinner than the prior 21 µs figure once `C_a11y` is properly accounted. **OQ-HUD-5 measurement gate is BLOCKING for sprint** — if measured `C_label` exceeds 0.05 ms or `C_a11y` exceeds 0.030 ms on Iris Xe / 4.6 / 810p, the cap is breached and one of the resolution paths in OQ-HUD-5 must be picked before sprint planning closes.

**Cascade cost (separate from steady-state formula).** `viewport.size_changed` triggers a layout-invalidation cascade on the *subsequent* frame: 5+ levels of nested Containers (`CanvasLayer → Control → MarginContainer → HBox/VBox → Label`) recompute. Estimated at 0.1–0.5 ms one-time cost per cascade event. Mutually exclusive with active gameplay (resize-drag suspends gameplay focus); CI gate AC-HUD-9.x explicitly excludes resize. Documented for completeness; not part of steady-state worst case.

**Resize-drag is excluded from steady-state worst case**: window-resize drag is mutually exclusive with active gameplay; no Restaurant combat scenario includes a live resize. CI gate AC-HUD-9.x excludes the resize term.

## Edge Cases

### Cluster A — Same-Frame Signal Storms

**If `player_damaged` and `player_health_changed` arrive on the same frame from a single `apply_damage` call**: `player_damaged` fires first, then `player_health_changed` fires second — this is the PC GDD F.6 guaranteed emission order (PC §"AC-5.1" verifies via signal-order spy: `player_damaged(...)` THEN `player_health_changed(...)`). HUD processes `player_damaged` first (sets `_pending_flash` or fires the flash), then processes `player_health_changed` (updates `_current_health`, evaluates the critical-state edge per F.2). The flash fires against the health value that was already recorded in the prior frame; the updated numeral is ready before the flash frame resolves. No split-brain: flash is rate-gated against timer state, not against `_current_health`.

**If `weapon_switched` and `ammo_changed` arrive on the same frame**: HUD processes them in signal-connection order (deterministic — both connected in `_ready()` with `weapon_switched` subscribed before `ammo_changed` per CR-1 subscription list order). The weapon name updates first; the ammo readout updates second. The resulting display is consistent. If `ammo_changed` carries a `weapon_id` that does not match the just-updated `_weapon_id` mirror (hypothetical ordering inversion from a future Inventory bug), HUD renders the mismatched ammo without crashing — the `weapon_id` mismatch is visible but not a fatal state. No additional guard needed; the true fix is upstream Inventory emit ordering.

**If five signals arrive on the same frame (worst-case F.5 scenario — multi-hit flash + `ammo_changed` + `weapon_switched` + `gadget_equipped` + `player_health_changed`)**: HUD processes each handler in turn during the same `_process` call stack. All five `Label.text` change-guards fire, up to five writes occur. Per F.5 worst-case analysis: `C_frame = 0.004 + 5 × 0.050 + 0.005 = 0.259 ms` — below the 0.3 ms Slot 7 cap by 41 µs headroom. CI must assert this scenario does not exceed cap on the Restaurant reference scene.

**If `player_died` arrives on the same frame as `player_damaged` (HP reaches 0 in one hit)**: PC F.6 emits `player_damaged` → `player_health_changed(0, max_health)` → `player_died` in that stack-frame sequence. HUD processes all three. `player_health_changed(0, max_health)` sets `_current_health = 0` and renders "0"; `player_died` resets `_flash_timer.stop()` and clears `_pending_flash`. Any in-flight deferred flash from `player_damaged` that is mid-`await process_frame` at `player_died` time is orphaned against a zeroed health display — see Cluster C for the `await` hazard.

### Cluster B — Critical-State Edge Cases

**If Eve takes damage that brings her to exactly 25% HP (`current = 25`, `max_health = 100`)**: `health_ratio = 25 / 100 = 0.25`. F.2 evaluates `critical = (health_ratio < threshold)` = `(0.25 < 0.25)` = `false`. The colour does NOT swap. The swap boundary is **strictly less than** 0.25, not less-than-or-equal. Eve must reach 24 HP or below to trigger Alarm Orange.

**If Eve is at 24 HP and receives a heal that brings her to exactly 25 HP**: `health_ratio = 25 / 100 = 0.25`. `critical = false`. `_was_critical = true` (previously below threshold). Edge fires: colour reverts Alarm Orange → Parchment immediately on this frame. `_was_critical` sets to `false`. Recovery edge is symmetric with entry edge. No hysteresis (CR-6).

**If `player_health_changed(0.0, 100.0)` fires (Eve at 0 HP)**: `health_ratio = 0.0 / 100.0 = 0.0`. `critical = true` (0.0 < 0.25). HUD renders the numeral from `int(round(0.0))` which is `0` — the health label shows `"0"` in Alarm Orange. The label is not hidden; "0" is a valid display value. It does not show "000" — HUD renders the integer as a string via GDScript `str(int(current))`, no zero-padding.

**If `max_health` were ever changed mid-game (hypothetical — PC GDD specifies fixed `player_max_health = 100`)**: F.2's `max(max_health, 1.0)` floor ensures no divide-by-zero. `_was_critical` state is computed fresh on every signal. A `max_health` change delivered via `player_health_changed(current, new_max)` would re-evaluate the ratio and potentially flip the critical edge. If `max_health` dropped to 1 while `current = 0`, `health_ratio = 0.0` — no crash. This scenario is currently impossible by design; the guard exists as a defensive floor, not a live path.

### Cluster C — Damage-Flash Coalescing Edge Cases

**If `player_damaged` arrives at exactly `t = 333.0 ms` after the timer started**: The timer `timeout` signal fires at `t = 333.0 ms`. Godot's `Timer` node processes `timeout` during the same frame's idle-time signal dispatch. `player_damaged` arriving in the same frame's `_process` runs before `timeout` is dispatched (Godot processes `_process` before idle signals in the same frame). Therefore at `t = 333.0 ms`, the timer has NOT yet fired when `player_damaged` is processed: `_flash_timer.is_stopped()` is `false` → sets `_pending_flash = true`. Then `timeout` fires: deferred flash executes, timer restarts. Net result: two flashes at `t = 0` and `t = 333 ms` — WCAG compliant. If the ordering were reversed (timeout before `_process`), `is_stopped()` would be `true` and the hit would open a new gate — also compliant. **Both orderings are safe.**

**If 100 hits arrive in one physics frame (Inventory-side burst or test-harness bug)**: All 100 `player_damaged` signals dispatch synchronously during the frame. The first hit: `_flash_timer.is_stopped() == true` → flash fires, timer starts. Hits 2–100: `_flash_timer.is_stopped() == false` → each sets `_pending_flash = true`. Since `_pending_flash` is a bool (not a counter), hits 3–100 are no-ops on an already-true flag. Net result: 1 immediate flash, 1 deferred flash at `t + 333 ms`. 98 hits are silently discarded per the rate-gate contract. No crash, no queue overflow, no unbounded loop.

**If `player_died` arrives while a deferred flash is mid-`await process_frame`**: The `await get_tree().process_frame` in the flash path suspends the coroutine. On the next `process_frame`, the coroutine resumes and reverts the colour override to `_current_health_color`. If `player_died` arrived between those two frames and `_was_critical` changed, `_current_health_color` may point to the wrong colour at revert time. **Mitigation**: the flash coroutine must capture the target revert colour at the start of the `await` (before suspension), not after: `var revert_color := _current_health_color; await get_tree().process_frame; add_theme_color_override(&"font_color", revert_color)`. The `player_died` handler must also call `_flash_timer.stop()` and `_pending_flash = false`, but it cannot cancel an in-flight coroutine. The one-frame colour artifact (white flash on a frame that may already be post-death) is acceptable since the death camera fade begins simultaneously and occludes it. **Implementation AC**: assert `_flash_timer.is_stopped() == true` and `_pending_flash == false` after `player_died` fires, regardless of in-flight awaits.

**If `player_damaged` arrives during the `LOAD_FROM_SAVE` restore sequence**: Per CR-14, the LSS restore-callback re-emits `player_health_changed` with restored values. LSS does NOT re-emit `player_damaged` — it is an event signal, not a state signal. There is therefore no `player_damaged` in the restore path by contract. If a timing bug in LSS caused a spurious `player_damaged` emission during `_ready()` before `_flash_timer` is initialised: `_flash_timer` is a child Timer node, initialised at scene instantiation before `_ready()` runs. It is in stopped state by default. The handler would find it stopped, fire a flash, and start the timer — producing a spurious flash at scene entry. The guard against this is the LSS contract (do not emit `player_damaged` during restore), not HUD-side defence.

### Cluster D — Prompt-Strip Lifecycle Edge Cases

**If `pc.get_current_interact_target()` returns null while `pc.is_hand_busy()` is true**: Resolver evaluates per the simplified 2-state machine (REV-2026-04-26): `pc != null` → check INTERACT_PROMPT → `get_current_interact_target() == null` → `HIDDEN`. The `is_hand_busy()` check is irrelevant because `get_current_interact_target()` already returned null; the null check short-circuits before `is_hand_busy()` is evaluated. HUD shows HIDDEN. Correct — player already lost the target.

**REV-2026-04-26 — TAKEDOWN_CUE eligibility/conflict edge cases REMOVED**: prior cases describing `takedown_availability_changed` interactions and INTERACT_PROMPT vs TAKEDOWN_CUE simultaneous-eligibility are no longer applicable per D4. SAI affordance signalling is fully diegetic (body-language + audio) at MVP; HUD has no part in it.

**If `pc.get_current_interact_target()` returns a freed `Node3D` (race between PC raycast update and HUD read)**: HUD calls `get_current_interact_target()` in `_process`. If PC freed the target between physics frames, `is_instance_valid()` would return false on the returned reference. Per CR-3, HUD only checks for null on the return value — it does not call `is_instance_valid()`. If a freed node is returned as non-null, `_compose_prompt_text()` attempts to call `target.interact_label_key` (or similar property access) on the freed node, which crashes in Godot 4.x. **Mitigation required at implementation: `_compose_prompt_text()` MUST guard with `if is_instance_valid(target):` before any property access on the target.** This is a defensive requirement added at edge-case time; not redundant with the null check.

### Cluster E — InputContext + Visibility Edge Cases

**If `ui_context_changed(GAMEPLAY, GAMEPLAY)` fires (no-op context transition)**: CR-10 sets `visible = (new_ctx == GAMEPLAY)`. Since `new_ctx == GAMEPLAY`, `visible` is set to `true`. If HUD was already visible, this is a no-op write in Godot — setting a property to its current value does not trigger a redraw or notification. No double-toggle, no flicker. If HUD was not visible (hypothetical desync state), this acts as a corrective restore. Both outcomes are safe.

**If context changes to non-GAMEPLAY mid-flash (parent `visible = false` during the 1-frame `await process_frame` window)**: When `hud_root.visible = false`, Godot does not dispatch the per-node `process_frame` signal to invisible nodes' children in the normal render path. However, the awaited `process_frame` signal on `get_tree()` (not the node) fires regardless of the HUD's visibility. The coroutine resumes, calls `add_theme_color_override`, and reverts the colour on an invisible label — a silent no-op. When HUD becomes visible again (context returns to GAMEPLAY), the label has the correct post-flash colour. No artefact.

**If context returns to GAMEPLAY while `_pending_flash` is true**: `ui_context_changed(GAMEPLAY, _)` fires → `visible = true`. `_flash_timer` was running while HUD was invisible (the Timer node continues ticking regardless of parent visibility). On `_flash_timer.timeout`, if `_pending_flash` is true: deferred flash fires (flash on a now-visible HUD), timer restarts, `_pending_flash = false`. **Advisory**: the deferred flash correctly fires after context restore. If this is undesirable (flashing immediately on context-restore is jarring), a design decision is needed: should `_pending_flash` be cleared on visibility-false? Currently it is not. Flagged as OQ-HUD-2 for playtest review — do not silently discard the flash without a design sign-off, because it may be health information the player needs.

**If HUD receives `ui_context_changed` but its parent CanvasLayer is being freed (scene reload)**: `_exit_tree()` has already fired, disconnecting all signals (CR-2). The signal cannot reach the handler after disconnect. If the signal arrives during the narrow window after `_exit_tree()` begins but before disconnect completes — impossible in GDScript's single-threaded execution model; `_exit_tree()` runs synchronously. No race possible.

### Cluster F — Save/Load Edge Cases

**If the HUD scene is freed and re-instantiated on `LOAD_FROM_SAVE`**: Per CR-14, `_ready()` initialises all widget values to zero/empty defaults. `_flash_timer` is stopped, `_dry_fire_timer` is stopped, `_pending_flash = false`, `_pending_dry_fire = false`, `_flashing = false`, `_was_critical = false`, `_last_interact_label_key = &""` (sentinel), `_last_ammo_weapon_id = &""` (sentinel for CR-8 first-emission false-positive guard). LSS restore-callback sequence then re-emits `player_health_changed`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `ui_context_changed` with restored values. HUD receives these identically to live gameplay and populates widgets. No special-case path; signal replay is the full restore contract. **REV-2026-04-26**: `_takedown_eligible` removed from this list per D4.

**If LSS restore-callback signals are re-emitted before HUD `_ready()` finishes**: In GDScript, `_ready()` is a synchronous method. Signal emissions that arrive during `_ready()` (if LSS emits them synchronously in `_ready()` call order on a sibling node) would execute before HUD's `_ready()` completes only if LSS emits before HUD subscribes — i.e., before `Events.[signal].connect(...)` runs. In that case HUD would miss the restore signals and remain at defaults. The ADR-0007 autoload load order and scene `_ready()` invocation order must guarantee LSS restore-callback fires after all scene nodes complete `_ready()`. **Flagged as OQ-HUD-4** — verification gate against LSS restore-sequencing contract.

**If `weapon_switched` fires before `ammo_changed` during restore (one-frame weapon-name with no ammo)**: HUD displays the weapon name from `weapon_switched` but `_ammo_current` and `_ammo_reserve` remain at their prior (default-zero) values until `ammo_changed` fires. For one frame the ammo readout shows `"0 / 0"`. Since LSS restore fires both signals before the first rendered frame after load, this transient state is never visible to the player. If restore is interrupted before `ammo_changed` fires (crash, timeout), the `"0 / 0"` display is a cosmetic error, not a gameplay error. Acceptable.

### Cluster G — Settings + Localization Edge Cases

**If `setting_changed("accessibility", "crosshair_enabled", false)` fires while the crosshair Control is mid-`_draw()` call**: Godot 4.x `_draw()` runs as part of the render server's draw call, after `_process`. The `setting_changed` signal is processed in `_process` time, updating `_crosshair_enabled_mirror = false` and calling `crosshair.visible = false`. The visibility change is applied before the next `_draw()` dispatch — the next frame the crosshair does not draw. There is no mid-draw interrupt. The current frame's crosshair draw completes normally; visibility takes effect on the next frame. Single-frame crosshair artefact on the toggle frame is acceptable.

**If `setting_changed("locale", "en", "fr")` fires**: CR-18 specifies that static labels re-resolve on `setting_changed("locale", _, _)`. HUD must call `tr()` for each cached static label string (`tr("HUD_INTERACT_PROMPT")`, `tr("HUD_TAKEDOWN_AVAILABLE")`) and update the cache. Dynamic labels (weapon name `tr(weapon_id)`, gadget name `tr(gadget_id)`) must also re-resolve — HUD should re-call `tr(_weapon_id)` and `tr(_gadget_id)` using their cached ID mirrors and write the new strings to the Labels. This re-resolution happens in the `_on_setting_changed` handler, not in `_process`. The prompt-strip's `_last_state` change-guard must be invalidated (force-set `_last_state = -1` sentinel) so the prompt re-composes on the next `_process` frame with the new locale string. No `tr()` call is made in `_process` itself (FP-8 compliance maintained).

**If Settings & Accessibility has not completed its boot sequence when HUD `_ready()` runs**: CR-11 specifies crosshair initial value is `false` until Settings emits the initial `setting_changed` event. If Settings has not emitted by the time the first GAMEPLAY context is entered, the crosshair remains hidden. This is correct default behaviour — the player chose to enable the crosshair via Settings; if Settings has not booted, no preference is known, so the conservative default (hidden) applies. **Flagged as OQ-HUD-3** — integration-time verification of Settings boot ordering against HUD ready.

### Cluster H — Performance Edge Cases

**If F.5 worst-case frame fires every frame for 60 consecutive frames (1 second sustained)**: Per F.5, worst-case `C_frame = 0.259 ms`. ADR-0008 Slot 7 cap is `0.3 ms per frame`, not a per-second budget — sustained worst-case is each frame individually below cap. **CI must assert the p95 frame cost on the Restaurant reference scene.** Sustained worst-case for one second in real play requires a continuous 60 Hz damage barrage with weapon switches and gadget equips on every frame — not a realistic play pattern but a valid stress test. The 41 µs per-frame headroom is thin; if godot-specialist implementation measures `C_label` at the high end (0.05 ms), the cap is respected. **If `C_label` exceeds 0.05 ms on minimum hardware, a performance ADR amendment is required** — flagged as OQ-HUD-5.

**If 10 simultaneous `gadget_activation_rejected` events arrive in one frame (Inventory-side bug)**: The handler `_on_gadget_activation_rejected(gadget_id)` calls `_gadget_reject_timer.stop()`, sets `modulate`, and calls `_gadget_reject_timer.start()` each invocation. With 10 invocations: each call stops and restarts the timer, effectively resetting the 0.2 s desat to the last invocation. Final state: desat timer running, revert in 0.2 s from the 10th call. No crash, no runaway allocation, no visual difference from a single rejection event. The 10 `stop()`/`start()` calls cost approximately 10 × ~0.001 ms = ~0.01 ms — negligible.

**If `viewport.size_changed` fires multiple times in the same frame (e.g. during a window resize drag)**: HUD subscribes to `viewport.size_changed` once (CR-3 / §C.2 scale rule). Each emission calls `_update_hud_scale()` which re-reads `viewport.size.y` and updates `Control.scale`. Multiple firings in one frame: each call overwrites the scale with the latest value — the final call sets the correct final scale. No accumulation, no crash. Cost: each call is ~0.002 ms; 5 rapid firings = ~0.01 ms. Acceptable. HUD does not batch or debounce viewport-changed signals.

### Cluster I — HUD-as-Subscriber Edge Cases

**If the `Events` autoload is destroyed before HUD's `_exit_tree()` runs (autoload teardown during scene close)**: In Godot 4.x, autoloads are freed *after* scene nodes in the main scene tree. HUD is a scene node (CanvasLayer child of the main scene), so HUD's `_exit_tree()` fires before `Events` is freed. The CR-2 explicit disconnects execute while `Events` is still valid. This is the correct and guaranteed ordering in Godot 4.6. The `is_connected()` guard in CR-2 is a defensive belt-and-suspenders, not a workaround for a real ordering hazard.

**If `Events.player_health_changed` does not exist when HUD subscribes in `_ready()` (autoload not ready)**: ADR-0007 defines the autoload load order. `Events` autoload is at load position 1 (first). HUD is a scene node; its `_ready()` fires after all autoloads complete their `_ready()`. Therefore `Events` is fully initialised before any scene node's `_ready()` runs. If an authoring error places HUD in a scene that loads before `Events` (impossible under ADR-0007 but defensible), the `Events.player_health_changed.connect(...)` call crashes with a null-receiver error. This is a level-authoring bug, not a HUD bug. No runtime guard is warranted — the crash is the correct failure mode for a violated autoload contract.

**If a signal handler in HUD raises an uncaught exception on one invocation**: GDScript does not have try/catch. An uncaught error in a signal handler halts that handler's execution and prints a Godot error, but does NOT disconnect the signal. Subsequent emissions reach the handler normally. The HUD's display state may be partially updated (the exception interrupted the handler mid-execution), potentially producing a split display (e.g., colour updated but numeral not). This is acceptable at MVP — no error-recovery logic is specified for handler exceptions. AC test coverage of all handlers prevents this in practice.

### Cluster J — Pillar-Violation Guard Cases

**If a future story adds a "kill confirmed" notification to the prompt-strip**: FP-6 (`(waypoint|minimap|objective_marker|alert_indicator|...)`) does not cover kill-confirmed notifications by pattern. The relevant pillar violation is Primary 5 (no modern AAA feedback) and the fantasy test from §Player Fantasy: *would Eve glance at this peripherally and walk on, or stop and read?* A kill-confirmed notification fails both. Encode as an acceptance criterion: **AC-HUD-pillar-1** in §H — "No signal of the form `guard_killed`, `target_eliminated`, `kill_confirmed`, or any derivative word pattern appears in HUD Core source." Add this pattern to FP-6's grep list before VS tier work begins.

**If a future Settings toggle for "Show damage direction indicator" is added**: This is a Primary 5 pillar violation regardless of the toggle — offering the option at all signals to the player that the game endorses consulting screen-edge damage indicators, which contradicts the period-authenticity and Discovery-Rewards-Patience pillars. The correct response is to reject the story at design review, not implement the toggle with a hidden default. Encode as a test-suite invariant: **AC-HUD-pillar-2** in §H — "No node named with patterns `damage_direction`, `hit_indicator`, `direction_indicator`, `compass`, `radar`, `nav_arrow` exists in any HUD scene." Enforced via scene-tree CI scan, not just source grep, since scene files could add the node without a code change.

## Dependencies

> **Note**: §C.5 Interactions matrix enumerates the per-system contracts in detail (signals, queries, ownership splits). This section codifies the dependency *taxonomy* (hard vs soft, upstream vs downstream vs ADR, forbidden non-deps, bidirectional consistency).

### Upstream — hard (system cannot function without these)

| System | Status | Hardness | Why |
|---|---|---|---|
| **Player Character** ✅ | Approved | HARD | All health/interact data flows from PC; HUD has no fallback. PC §UI Requirements is the frozen API contract. |
| **Inventory & Gadgets** ✅(pending coord) | Approved-pending-coord | HARD | All weapon/ammo/gadget data flows from Inventory's 4 frozen Inventory-domain signals + `gadget_activation_rejected`. |
| **Combat & Damage** ✅ | Approved | HARD | Combat owns the rate-gate constant (`hud_damage_flash_cooldown_ms = 333`), the crosshair behavioural contract, and the photosensitivity policy. HUD enforces what Combat specifies. |
| ~~**Stealth AI** ✅~~ | ~~Approved~~ | ~~HARD~~ | **REMOVED REV-2026-04-26 per D4** — TAKEDOWN_CUE cut from MVP; HUD Core MVP no longer subscribes to any SAI signal. SAI body-language alone signals takedown affordance (Pillar 5). |
| **ADR-0002 Signal Bus** | Proposed | HARD | All HUD subscriptions route through `Events` autoload. 2 amendment items to be bundled. |
| **ADR-0004 UI Framework** | Proposed (3 gates pending) | HARD | Theme inheritance + FontRegistry + InputContext + CanvasLayer indices + `mouse_filter` + `tr()` mandate are all ADR-0004 contracts. |
| **ADR-0008 Performance Budget** | Proposed | HARD | Slot 7 = 0.3 ms cap binds HUD's per-frame cost. CI gate validates p95 on Restaurant reference scene. |
| **Localization Scaffold** ✅ | Designed | HARD | All visible strings via `tr()` (CR-18). |
| **HUD State Signaling (system #19)** | Not Started | **HARD MVP DEP (REV-2026-04-26 per D3)** | Day-1 minimal slice: brief text-only HoH/deaf alert-state cue (`tr("HUD_GUARD_ALERTED")`, ~2 s auto-dismiss) via `HUDCore.get_prompt_label()`. WCAG 1.1.1 / 1.3.3 + EU GAAD compliance. HUD Core MVP BLOCKED until ships. See §C.5 BLOCKING coord item #2c. |
| **Settings & Accessibility (system #23)** | Not Started | **HARD MVP DEP (REV-2026-04-26 per D2)** | Day-1 minimal slice: photosensitivity-toggle UI (`damage_flash_enabled`), crosshair-toggle UI (`crosshair_enabled`), boot-screen photosensitivity warning linking to the toggle. Sony TRC R4128 / MS TCS / EU GAAD 2025 compliance. HUD Core MVP BLOCKED until ships. See §C.5 BLOCKING coord item #2b. |
| **Input (TBD GDD)** | Not Started | HARD (CR-21 forward — runtime key-glyph rebinding contract) | The prompt-strip's runtime input glyph (replacing the static `[E]`/`[F]` literals) requires Input GDD to specify either (a) a query API (`Input.get_glyph_for_action(action_name) -> String`) or (b) a `binding_changed` signal. HUD Core MVP needs this contract before sprint planning closes; gamepad players otherwise see keyboard glyphs. |

### Upstream — soft (system functions degraded but does not crash)

| System | Status | Reason |
|---|---|---|
| **Audio** ✅ | Approved | HUD does not call Audio; Audio is the recipient of pairings (clock-tick on critical state). HUD works without Audio's clock-tick — soft dependency for the *experience*, not the *function*. |
| **InputContext autoload** (ADR-0004) | Proposed | If `ui_context_changed` is missing, HUD remains visible during all contexts (correct fallback per CR-10's `_ready()` initial value of `(InputContext.current() == GAMEPLAY)`). Crosshair would render over modal surfaces — visible but not crash. |

### Forward dependents (this GDD constrains them)

| System | Status | Constraint imposed by HUD Core |
|---|---|---|
| **HUD State Signaling** (system #19, VS) | Not Started | HUD Core defines the `Label` child node and `get_prompt_label() -> Label` extension method. HSS subscribes to `document_collected`, `alert_state_changed (severity)`, `respawn_triggered` and adds MEMO_NOTIFICATION + alarm-stinger states to the prompt-strip resolver. HSS may NOT redefine §C.3's existing 3 states or alter §C.4's photosensitivity gate. |
| **Settings & Accessibility** (system #23) | Not Started | Must define `crosshair_enabled: bool`, `crosshair_dot_size_pct_v: float`, `crosshair_halo_style: enum {none, parchment_only, tri_band}`. Must emit `setting_changed("accessibility", _, _)` per ADR-0002 — `accessibility` is the single canonical home per Settings CR-2 (corrected 2026-04-28 per `/review-all-gdds` 2026-04-28 finding 2c-4). Must support locale-change re-emission for `tr()` invalidation per CR-18. |
| **Document Collection** (system #17) | Not Started | When authored, must clarify whether `player_interacted(target)` carries memo data (provisional contract — currently `player_interacted` is in PC domain). HSS — not HUD Core — consumes this. |

### ADR dependencies

| ADR | Status | HUD's binding to it |
|---|---|---|
| **ADR-0001 Stencil ID Contract** | Accepted | None directly — HUD is screen-space, no stencil writes from HUD scene. Document Overlay's sepia dim ColorRect is the only UI-side stencil writer (ADR-0001 §UI Framework). |
| **ADR-0002 Signal Bus + Event Taxonomy** | Proposed | HUD subscribes to 9 Events bus signals (8 frozen + 1 amendment `ui_context_changed`; `takedown_availability_changed` removed per D4). Plus 5 non-Events connections (1 Settings, 3 Timer, 1 viewport) for 14 total per CR-1. Emits zero. |
| **ADR-0003 Save Format Contract** | Accepted | None — HUD has no `capture()`, no SaveGame sub-resource, no restore callback (CR-20). |
| **ADR-0004 UI Framework** | Proposed (3 gates) | Theme inheritance + FontRegistry + CanvasLayer indices + `mouse_filter` + `tr()` + `accessibility_live`. **Gate 2 (Theme inheritance property name) is BLOCKING for HUD `hud_theme.tres` authoring.** |
| **ADR-0005 FPS Hands Outline** | Accepted | None — HUD is screen-space, FPS hands are 3D world. |
| **ADR-0006 Collision Layer Contract** | Accepted | None — HUD has no colliders. |
| **ADR-0007 Autoload Load Order** | Accepted | None directly — HUD is NOT an autoload (FP-13). HUD relies on the autoload load-order guarantee for `Events` to be initialised before HUD `_ready()`. |
| **ADR-0008 Performance Budget Distribution** | Proposed | Slot 7 = 0.3 ms HUD per-frame cap. F.5 worst-case `C_frame = 0.259 ms` (~14% headroom). |

### Forbidden non-dependencies (HUD MUST NOT depend on these)

| System | Why HUD must not depend |
|---|---|
| **Civilian AI** | Pillar 5 zero-UI absolute — civilians never appear in HUD (CAI Player Fantasy locks this; FP-6 grep enforces). |
| **Failure & Respawn** | F&R has empty UI per Pillar 5 (no death screen, no retry button, no kill cam). HUD's parent visibility toggle handles the input-blocked window via `ui_context_changed`, not via direct F&R coupling. |
| **Mission & Level Scripting** | MLS owns mission state + objective tracking but at MVP HUD does NOT render objective markers (Pillar 2/5 absolute — FP-6). HUD State Signaling at VS may surface objective notifications via different signals (not direct MLS coupling). |
| **Save/Load Service** | HUD has no `capture()` and registers no restore callback (CR-20, FP-12). HUD reads **no** persisted state. |
| **Document Collection** at MVP | MEMO_NOTIFICATION deferred to HSS — HUD Core MVP does not subscribe to `document_collected`. |
| **`Engine.get_singleton(...)`** / direct tree-walk lookups | FP-14 — bypasses Events autoload signal pattern. |
| **Any Resource preloaded at runtime in HUD code** | FP-4 — all Resource refs arrive in signal payloads. |

### Coordination items summary (rolled up from §C.5) — REV-2026-04-26

**BLOCKING (7)** — sprint cannot start until these close:
1. ADR-0002 amendment: `ui_context_changed(new_ctx, prev_ctx)` (UI domain) — argument type `InputContext.Context` (autoload-key form).
2. ~~ADR-0002 amendment: `takedown_availability_changed`~~ **WITHDRAWN per D4** — TAKEDOWN_CUE removed from MVP.
2b. **NEW — Settings #23 Day-1 minimal-UI dep** (per D2): photosensitivity + crosshair toggles + boot-warning UI shipped before HUD MVP.
2c. **NEW — HSS #19 Day-1 alert-cue dep** (per D3): brief text-only HoH/deaf alert-state cue shipped before HUD MVP.
3. ADR-0004 Gate 2: confirm Theme inheritance property name (`base_theme` vs `fallback_theme`).
4. ADR-0004 Gate 1: confirm `accessibility_live` property name on Godot 4.6 Label/Control (Day-1 default-suppression behaviour required even though AccessKit feature is Polish-tier — see OQ-HUD-8).
5. **Godot 4.6 API verification batch** (see §C.5 Coord item #5): `Color(hex,alpha)` constructor, `TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL` enum, `set_anchors_preset()` method form (NOT property), `process_frame` signal name, `font_color` theme key, `focus_mode = FOCUS_NONE` per-widget annotation under 4.6 dual-focus split (HIGH-RISK), `corner_radius_*` property names. `Performance.TIME_PROCESS` removed from batch — already replaced by `Time.get_ticks_usec()` in AC-HUD-9.1.
6. **OQ-HUD-5**: F.5 constants (`C_label`, `C_draw`, `C_poll`, `C_theme_override`, `C_a11y` REV-2026-04-26 added) MUST be measured on Iris Xe Gen 12 / Godot 4.6 / 810p Restaurant before sprint-plan closes.
7. **NEW REV-2026-04-26 — Input GDD CR-21 contract**: Input GDD must commit to either query API or signal-driven binding contract for runtime key-glyph rebinding before sprint planning closes (gamepad-player exclusion otherwise).

**ADVISORY (3)**:
- HUD-scale slider as Settings forward-dep (OQ-HUD-1).
- Combat §UI-6 dual-discovery path requires Settings GDD authoring.
- F.4 default 0.19% crosshair size hits 3 px floor at 1080p (~17.8% slider dead zone) — flag for Settings #23 slider UX design.

### Bidirectional consistency check

| HUD Core declares as dep | Reciprocal in upstream GDD | Match |
|---|---|---|
| PC GDD §UI Requirements (frozen API) | PC GDD §UI Requirements lists HUD Core as consumer | ✅ |
| Inventory §UI-1..UI-9 (4 signals + dry-fire detection) | Inventory §F lists HUD Core as outbound forward-dep | ✅ |
| Combat §UI-1..UI-6 (HUD owns crosshair, Combat owns constants) | Combat §UI lists HUD Core as renderer + AC-CD-13.2B HUD-path discovery surface | ✅ |
| ~~SAI `takedown_availability_changed`~~ | **WITHDRAWN per D4** — TAKEDOWN_CUE removed from MVP | n/a |
| InputContext `ui_context_changed` (NEW signal) | ADR-0002 amendment — Coord item §C.5#1 ⏳ | ⏳ pending amendment |
| Civilian AI Pillar 5 zero-UI absolute | CAI §UI Requirements explicitly states zero-UI | ✅ |
| F&R empty UI (Pillar 5 forbids death screen / retry) | F&R §UI states empty | ✅ |
| **HSS Day-1 alert-cue minimal slice (HARD MVP DEP per D3)** | HSS not yet authored — must include AC for alert-cue rendering through `get_prompt_label()` | ⏳ pending HSS minimal-slice authoring |
| **Settings #23 Day-1 minimal UI (HARD MVP DEP per D2)** | Settings GDD not yet authored — must include AC for `damage_flash_enabled` + `crosshair_enabled` toggles + boot-warning | ⏳ pending Settings minimal-slice authoring |
| **Input GDD CR-21 rebinding contract (HARD)** | Input GDD not yet authored — must commit to query API or `binding_changed` signal | ⏳ pending Input GDD |

## Tuning Knobs

HUD Core has **few owned tuning knobs** — most adjustable values are owned by upstream systems (PC owns critical threshold, Combat owns photosensitivity cooldown and crosshair sizes, Art Bible §4.4 owns palette, Settings & Accessibility will own crosshair toggles). HUD Core points to those sources of truth rather than duplicating them.

### G.1 — HUD-owned tuning knobs

| Knob | Default | Safe range | Effect |
|---|---|---|---|
| `gadget_rejected_desat_duration_s` | **0.2** s | [0.1, 0.5] s | Duration the gadget tile stays at `modulate = (0.4, 0.4, 0.4, 1.0)` after `gadget_activation_rejected` (CR-9). Below 0.1 s the desat is imperceptible; above 0.5 s it lingers into the next interaction. **NEW — flagged for §Registry sweep.** |
| `gadget_empty_tile_alpha` | **0.4** | [0.2, 0.6] | Modulate alpha when no gadget equipped (§C.2). Below 0.2 the tile is invisible (defeats geometry-stability rationale); above 0.6 it reads as "active." |
| `hud_canvas_layer_index` | **1** | [1, 3] | CanvasLayer index for HUD root (per ADR-0004 §7 stack: 0..3 reserved for HUD; 4 = sepia dim, 5+ = modal surfaces). Adjusting within [1, 3] lets HSS or future overlays insert above HUD without restructuring. |
| `prompt_strip_y_offset_pct` | **18%** | [10%, 25%] | Distance of prompt-strip from bottom edge as percent of viewport height (Art Bible §7A — confirmed but adjustable for HUD-scale playtest). Below 10% collides with bottom-edge widgets; above 25% drifts toward centre and loses peripheral-glance fantasy. |
| `viewport_scale_min` / `viewport_scale_max` | **0.667** / **2.0** | LOCKED at 720p / 4K bounds | F.3 clamp values. Locked — extending below 0.667 produces sub-legible text at 540p; extending above 2.0 wastes pixels on 8K displays where Combat hasn't validated. |

### G.2 — Constants HUD references but does NOT own (single source of truth — see registry)

| Constant | Source GDD | Default | Notes |
|---|---|---|---|
| `hud_damage_flash_cooldown_ms` | Combat & Damage §G | **333** ms | WCAG 2.3.1 ceiling — locked at 333 ms unless first-boot photosensitivity warning toggle exposes a Settings slider (OQ-CD-12 forward-dep). |
| `player_critical_health_threshold` | Player Character §UI Requirements / registry | **25** (percentage; HUD divides by 100 at compute time → 0.25 ratio at max_health=100) | Below this ratio (`current / max_health < threshold / 100`), F.2 fires colour swap. PC-owned. Pattern matches Audio GDD §Formula 4. |
| `player_max_health` | Player Character / registry | **100** HP | Used for critical-state ratio computation. |
| `crosshair_dot_size_pct_v` | Combat & Damage §UI-1 / registry | **0.19%** of viewport_v | Resolution-independent dot size. Combat-owned, exposed via Settings. |
| `crosshair_halo_style` | Combat & Damage §UI-1 / registry | **tri_band** | Halo composition. Combat-owned, exposed via Settings. |
| `crosshair_enabled` | Combat & Damage §UI-6 (default) / Settings (persisted) | **true** | Default opt-out. Settings & Accessibility GDD owns persistence. |

### G.3 — Visual constants (Art Bible §4.4 / §7A-D — single source of truth)

These colour and typographic constants originate in the Art Bible and are referenced by HUD via `project_theme.tres` + `hud_theme.tres` + `FontRegistry`. Adjusting them requires Art Bible review, not a HUD-Core change.

| Constant | Art Bible source | Value |
|---|---|---|
| HUD field background | §4.4 | BQA Blue `#1B3A6B` at 85% opacity |
| HUD numeral colour (default) | §4.4 / §7B | Parchment `#F2E8C8` |
| HUD numeral colour (critical state) | §4.4 / §7D | Alarm Orange `#E85D2A` |
| HUD damage-flash colour (transient 1 frame) | §7D | `#FFFFFF` |
| Gadget tile background | §4.4 / §7A | BQA Blue `#1B3A6B` at 85% over slightly lighter tint `#2A4F8A` |
| Gadget tile captured-equipment tint | §4.4 / §7A | PHANTOM Red `#C8102E` |
| Gadget sound-wave glyph | §7A / §7C | Parchment `#F2E8C8`, ~12 × 12 px (3 concentric arcs) |
| Health numeral typography | §7B | Futura Condensed Bold @ 22 px ≥ 18 px floor; DIN 1451 Engschrift below floor (FontRegistry) |
| Health label "HP" typography | §7B | Futura Condensed Bold @ 13 px (60% of numeral) |
| Weapon name typography | §7B | Futura Condensed Bold condensed caps @ 13 px |
| Prompt-strip typography | §7B | Futura Condensed Bold @ 14 px |

### G.4 — Forward-dep tuning knobs (Settings & Accessibility will own)

| Knob | Owner (when authored) | HUD's interest |
|---|---|---|
| `hud_scale_multiplier` (1.0 default; range [0.5, 2.0]) | Settings & Accessibility GDD (system #23) | Surfaces a player-facing HUD scale slider for accessibility (low-vision users, ultra-wide-monitor edge cases). HUD applies this multiplicatively to the F.3 viewport-scale factor. **Not in HUD Core MVP.** |
| `hud_damage_flash_enabled` (true default) | **REV-2026-04-25 — Day-1 MVP requirement** (was: Settings & Accessibility forward-dep; category swept 2026-04-27 closing B3) | Photosensitivity opt-out toggle. When false, the F.1 rate-gate is bypassed and `_pending_flash` is never set; visual flash is fully suppressed. **Day-1 MVP via stub `Settings.get_setting("accessibility", "damage_flash_enabled", true)` accessor** (single canonical home per Settings CR-2 + line 180). Settings & Accessibility GDD authoring later wires up persistence; HUD Core depends on the contract not the implementation. Industry/cert/legal floor — see UI-2 row. |
| `crosshair_enabled` (Settings persistence) | Settings & Accessibility GDD | Combat owns the default; Settings owns persistence + UI placement at both `Settings → HUD → Crosshair` and `Settings → Accessibility → Crosshair`. |
| `locale` (string; default "en") | Settings & Accessibility GDD | Triggers `setting_changed("locale", _, _)` which HUD subscribes to for `tr()` cache invalidation (CR-18). |

### G.5 — Tuning ownership matrix (consolidated)

| Concern | Owner | Editable by |
|---|---|---|
| HUD widget anchors / pixel offsets / scale rule | HUD Core GDD | Designer (this GDD §G.1) |
| HUD palette + typography | Art Bible §4.4 / §7A-D | Art Director (Art Bible review) |
| Photosensitivity cooldown | Combat & Damage GDD §G | Combat designer + Combat AC gate |
| Critical-health threshold | Player Character GDD / registry | PC designer |
| Crosshair size / style / opt-out | Combat (default) / Settings (persistence) | Combat (default) + Player (Settings) |
| Player accessibility opt-outs (HUD scale, flash disable) | Settings & Accessibility GDD (forward) | Player (Settings) |

## Visual / Audio Requirements

### V.1 — `hud_theme.tres` StyleBoxFlat Specifications

All `StyleBoxFlat` resources below are authored into `hud_theme.tres`, which inherits `project_theme.tres` per ADR-0004. Every `corner_radius_*` is 0 — hard-edged rectangles throughout (Art Bible §3.3). No `shadow_color`, no `shadow_size`, no `expand_margin_*` overrides beyond those listed.

**Health field background** (applied to `MarginContainer` panel, BL widget)

| Property | Value |
|---|---|
| `bg_color` | `Color("#1B3A6B", 0.85)` — BQA Blue 85% opacity (§4.4) |
| `border_color` | `Color(0, 0, 0, 0)` — no border |
| `border_width_left/right/top/bottom` | `0` |
| `corner_radius_*` (all four) | `0` |
| `content_margin_left/right` | `6` px |
| `content_margin_top/bottom` | `4` px |

**Weapon+Ammo field background** (applied to `MarginContainer` panel, BR widget — mirrored geometry per §7A)

| Property | Value |
|---|---|
| `bg_color` | `Color("#1B3A6B", 0.85)` |
| `border_width_*` | `0` |
| `corner_radius_*` | `0` |
| `content_margin_left/right` | `6` px |
| `content_margin_top/bottom` | `4` px |

**Gadget tile background — layered approach** (TR widget, §4.4)

Art Bible §4.4 specifies BQA Blue `#1B3A6B` at 85% over a slightly lighter tint `#2A4F8A`. The layered approach: the 56 × 56 px `Control` host draws a solid `#2A4F8A` fill as its base in `_draw()` (or via a second StyleBoxFlat on a `PanelContainer` drawn first in the tree), then the primary StyleBoxFlat draws `Color("#1B3A6B", 0.85)` on top. Because both layers use Godot's `CanvasItem` alpha compositing, the result is a BQA Blue strip at 85% opacity with the lighter tint bleeding through at the edges in proportion to opacity — producing subtle visible depth without a soft glow.

Outer `PanelContainer` (lighter tint base):

| Property | Value |
|---|---|
| `bg_color` | `Color("#2A4F8A", 1.0)` — fully opaque |
| `border_width_*` | `0` |
| `corner_radius_*` | `0` |
| `content_margin_*` | `0` |

Inner `PanelContainer` (BQA Blue over-layer, same size):

| Property | Value |
|---|---|
| `bg_color` | `Color("#1B3A6B", 0.85)` |
| `border_width_*` | `0` |
| `corner_radius_*` | `0` |
| `content_margin_*` | `0` |

**Prompt-strip background** (applied to the CB `MarginContainer` panel)

| Property | Value |
|---|---|
| `bg_color` | `Color("#1B3A6B", 0.85)` |
| `border_width_*` | `0` |
| `corner_radius_*` | `0` |
| `content_margin_left/right` | `8` px |
| `content_margin_top/bottom` | `3` px |

**Key-rectangle StyleBoxFlat** (inline within prompt-strip, wraps the `[E]` or `[F]` key token — §7C)

| Property | Value |
|---|---|
| `bg_color` | `Color(0, 0, 0, 0)` — transparent fill |
| `border_color` | `Color("#F2E8C8", 1.0)` — Parchment 1 px rule (§7C) |
| `border_width_left/right/top/bottom` | `1` |
| `corner_radius_*` | `0` |
| `content_margin_left/right` | `3` px |
| `content_margin_top/bottom` | `1` px |

### V.2 — Asset List for HUD Core MVP

All filenames follow Art Bible §8B: `[category]_[name]_[variant]_[size].[ext]`.

| Filename | Format | Dimensions @1080p | Owner |
|---|---|---|---|
| `ui_gadget_cigarette_case_default_56.png` | PNG, alpha channel | 56 × 56 px | Art Director (define silhouette) → Technical Artist (rasterise) |
| `ui_gadget_compact_default_56.png` | PNG, alpha channel | 56 × 56 px | Art Director → Technical Artist |
| `ui_gadget_parfum_default_56.png` | PNG, alpha channel | 56 × 56 px | Art Director → Technical Artist |
| `ui_gadget_mission_pickup_default_56.png` | PNG, alpha channel | 56 × 56 px (placeholder) | Art Director → Technical Artist — one slot reserved for mission-specific gadget; slug to be finalised when mission gadget is named |
| `ui_glyph_sound_wave_default_12.png` | PNG, alpha channel | 12 × 12 px, Parchment `#F2E8C8` on transparent background | Art Director → Technical Artist |

**Not in this list:**
- Crosshair: drawn programmatically in `_draw()` per §C.2 — no texture asset
- Fonts: loaded via `FontRegistry.hud_numeral(size_px)` from `assets/fonts/` per ADR-0004 — not HUD-Core assets
- Background strips: defined as `StyleBoxFlat` resources in `hud_theme.tres` — no texture assets

**Gadget icon spec** (applies to all four icon textures): flat solid silhouette, single colour (Parchment `#F2E8C8`), fully opaque fill, alpha-transparent outside the silhouette. No gradients. No outline strokes on the icon itself — the silhouette edge IS the icon's boundary (Art Bible §7C). Source format: vector (`.svg`) delivered to Technical Artist for rasterisation at 56 × 56 px. The designer delivers the silhouette definition; the Technical Artist produces the final `.png`.

**Sound-wave glyph spec:** 3 concentric arcs, single colour Parchment `#F2E8C8`, 12 × 12 px bounding box, 1 px arc stroke at this size, transparent background. Rendered upper-right corner of gadget tile as a `TextureRect` (visible only on gadgets flagged as noisy in the registry).

### V.3 — Per-Widget Render Tree

**Health field (BL)**

```
MarginContainer                   [StyleBoxFlat: health_bg]
  HBoxContainer
    Label("HP")                   [font: FontRegistry.hud_numeral(13), color: Parchment, h_size_flags: SHRINK_BEGIN]
    Label(_current_health_str)    [font: FontRegistry.hud_numeral(22), color: _current_health_color, h_size_flags: EXPAND_FILL, horizontal_alignment: RIGHT]
```

`_current_health_color` is Parchment or Alarm Orange per F.2 and is applied via `add_theme_color_override(&"font_color", ...)`. `_current_health_str` is `str(int(round(current)))`.

**Weapon+Ammo field (BR) — REV-2026-04-25 consolidated**

```
MarginContainer                   [StyleBoxFlat: weapon_ammo_bg]
  VBoxContainer
    Label(_weapon_name_str)       [font: FontRegistry.hud_numeral(13), color: Parchment, uppercase via theme]
    Label(_ammo_combined_str)     [font: FontRegistry.hud_numeral(22), color: Parchment, horizontal_alignment: RIGHT]
```

`_ammo_combined_str` is composed in the `_on_ammo_changed` handler as `"%d / %d" % [current, reserve]` (or the dash-glyph form `"—"` for blade/empty-rifle states). Single Label avoids 2 of 3 prior `Label.text` writes per `ammo_changed` event — required for F.5 ADR-0008 Slot 7 compliance. Weapon name via `tr(_weapon_id)` cached at `weapon_switched` time. **Art Direction note (REV-2026-04-25 coord item)**: Art Bible §7A previously specified the slash at ~70% of numeral width (16 px vs 22 px). The consolidated single-Label form renders the slash at the same 22 px as the numerals. **BLOCKING coord item — Art Director must approve before sprint** that the equal-size slash is acceptable, OR specify a typographic substitute (e.g., a thinner "/" via fontvariant) that preserves the §7A geometry without splitting into multiple Labels. If neither is acceptable, OQ-HUD-5 path b (further consolidation) or path a (ADR amendment) re-opens.

**Gadget tile (TR)**

```
PanelContainer                    [StyleBoxFlat: gadget_tile_tint_base — #2A4F8A fully opaque]
  PanelContainer                  [StyleBoxFlat: gadget_tile_overlay — #1B3A6B 85%]
    Control                       [custom _draw() — no additional draw; children handle content]
      TextureRect(_icon_texture)  [expand_mode: TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL, stretch_mode: TextureRect.STRETCH_KEEP_ASPECT_CENTERED, size 56×56]   # REV-2026-04-26 enum prefix corrected per godot-specialist coord item
      TextureRect(_sound_wave)    [size 12×12, anchor: TOP_RIGHT of parent, visible only if gadget is flagged noisy]
```

`modulate.a = 0.4` on the outer `PanelContainer` when no gadget is equipped (CR-empty-tile). PHANTOM Red `#C8102E` applied via `modulate` on the icon `TextureRect` only when equipment is captured, not on the tile background, to preserve the BQA Blue background while tinting the icon.

**Prompt-strip (CB)**

```
CenterContainer
  MarginContainer                 [StyleBoxFlat: prompt_bg]
    HBoxContainer
      Label(_prompt_text)         [font: FontRegistry.hud_numeral(14), color: Parchment]
      PanelContainer               [StyleBoxFlat: key_rect — 1px Parchment border, transparent fill; visible only when prompt contains a key token]
        Label(_key_str)           [font: FontRegistry.hud_numeral(14), color: Parchment]
```

The key-rect `PanelContainer` is a separate sibling child for key-name tokens (e.g., `[E]`) per §7C printed-manual aesthetic. Prompt text before and after the key token splits into two `Label` nodes if needed; at MVP only single-key prompts are specified. The entire `CenterContainer` has `visible = (state != HIDDEN)` per §C.3.

**Crosshair (Center)**

```
Control (subclass CrosshairWidget) [custom _draw() override, ANCHOR_PRESET_CENTER]
```

No children. Programmatic only — see V.6.

### V.4 — Damage-Flash Visual Composition

The 1-frame damage flash applies `add_theme_color_override(&"font_color", Color.WHITE)` to the health numeral `Label`, `await`s one `process_frame`, then reverts via `add_theme_color_override(&"font_color", revert_color)` where `revert_color` is captured before the `await`.

**`_current_health_color` revert rules — REV-2026-04-26 aligned with §C.4 caller responsibility.** The §C.4 `_on_player_damaged` handler performs the gate check (`_flash_timer.is_stopped()` AND `not _flashing`); `_execute_flash()` itself ONLY checks `_flashing` (defensive re-entry guard) and assumes the gate is open. The revert colour is captured before `await`; `_flashing` prevents concurrent coroutines; `is_instance_valid(self)` covers the freed-during-await case. The implementer MUST also clear `_flashing` on the early-return path so a freed-then-recreated HUD instance does not inherit a stale flag (the new instance's `_ready()` re-initialises, but defensive practice favours explicit clearing).

```gdscript
# Caller (CR-7 / §C.4 step 1) verified _flash_timer.is_stopped() AND not _flashing
# before calling _execute_flash(). This function performs only the re-entry guard.
func _execute_flash() -> void:
    if _flashing:
        _pending_flash = true
        return
    _flashing = true
    var revert_color: Color = alarm_orange if _was_critical else parchment
    add_theme_color_override(&"font_color", Color.WHITE)
    await get_tree().process_frame
    if not is_instance_valid(self):  # HUD freed mid-flash — bail
        return  # _flashing is on a freed instance; new instance starts false
    add_theme_color_override(&"font_color", revert_color)
    _flashing = false
```

If `_was_critical` flips between the flash start and the revert frame (e.g., medkit received mid-flash), the captured `revert_color` reflects the state at flash initiation, not the post-flip state. This produces a one-frame artefact at most; subsequent `player_health_changed` signal resolves the correct colour immediately. See §E Cluster C for the full reasoning.

**Why numeral-only, not screen flash or background flash:** the cockpit-dial fantasy (§Player Fantasy) demands that the HUD confirm state without editorialising. A screen flash would break the player's world-view — Eve's eyes do not blur when she takes a hit; the information lands in the corner without demanding the player's full attention. A background flash on the BQA Blue strip would conflate the damage event with the critical-state strip colour, creating ambiguity (is the background changing state, or acknowledging an event?). The numeral flash is a needle deflection: momentary, specific, peripheral (Art Bible §7D — "The numeral alone confirms"). Audio carries kinetic weight (§A.1).

**Cooldown-gate behaviour from HUD's perspective:** when the rate-gate is closed and a `_pending_flash` deferred flash fires at `_flash_timer.timeout`, HUD executes the same `add_theme_color_override + await + revert` path as an immediate flash. No distinct code path for deferred flashes — identical visual output. The player sees one flash per gated window regardless of how many hits arrived within it.

### V.5 — Critical-State Colour Transition

The swap is a single-frame edge-triggered event at the `player_health_changed` handler, not an animation. There is no intermediate colour, no fade duration, no bounce.

**Visual reading:** Alarm Orange in the corner reads as a warning placard — categorical, factual, static once set. It is not an urgent blink or a pulsing animation. The numeral is still readable; only its colour changes. The player's response to the colour shift is their own (re-route, find cover, use medkit); the HUD does not prescribe urgency through motion. This is the "cue for the second act" framing from §Player Fantasy.

**Implementation:** on `player_health_changed`, if F.2's edge condition fires:
```gdscript
add_theme_color_override(&"font_color", alarm_orange)  # Alarm Orange #E85D2A
_was_critical = true
```

Recovery on same-frame `player_health_changed` crossing back ≥ 0.25 (CR-6):
```gdscript
add_theme_color_override(&"font_color", parchment)  # Parchment #F2E8C8
_was_critical = false
```

**Audio coupling:** HUD does NOT call any Audio function. The Audio system independently subscribes to `player_health_changed` via `Events` and runs its own threshold check to orchestrate the clock-tick SFX. They happen to fire at the same signal emission but through entirely separate handlers. HUD owns the visual; Audio owns the audio. Loose coupling via shared signal source is the full contract (Art Bible §7D — clock-tick paired with colour swap; ADR-0002 subscriber-only HUD contract).

**Recovery behaviour:** no hysteresis (CR-6). The colour snaps back to Parchment on the same frame as the threshold crossing. A player who oscillates around exactly 25 HP (via incremental damage and medkit micro-dosing) will see rapid alternating colour swaps. This is correct and intentional — the dial is truthful, not smoothed.

### V.6 — Crosshair Widget Visual Composition

The crosshair `Control` subclass overrides `_draw()`. No children, no textures.

**Draw order:** halo first, dot on top. The dot must occlude the halo centre — drawing the dot last ensures it is fully opaque at centre regardless of arc overlap.

**Tri-band halo composition (Art Bible §7A / §7C):** the tri-band halo is two concentric `draw_arc` calls around the dot centre. "Parchment outer + Ink Black inner" means: draw the wider arc (Parchment) first, then the narrower arc (Ink Black) directly over it, then the dot last. Both arcs and the dot are centred on the crosshair control's `size / 2`.

```gdscript
func _draw() -> void:
    var center := size / 2.0
    var dot_r := _dot_radius_px  # computed via F.4; int [3, 12]
    var halo_outer_r := float(dot_r) + 2.0  # 1 px Parchment band outside dot edge
    var halo_inner_r := float(dot_r) + 1.0  # 1 px Ink Black band inside Parchment
    # Draw outer halo (Parchment #F2E8C8)
    draw_arc(center, halo_outer_r, 0.0, TAU, 64, Color("#F2E8C8"), 1.0, false)
    # Draw inner halo (Ink Black #1A1A1A — project body-text near-black per Art Bible §4.4)
    draw_arc(center, halo_inner_r, 0.0, TAU, 64, Color("#1A1A1A"), 1.0, false)
    # Draw dot (Parchment — on top, fully opaque)
    draw_circle(center, float(dot_r), Color("#F2E8C8"))
```

The 64-segment arc approximates a smooth circle at the sizes involved. `draw_circle` in Godot 4.6 uses the same polygon approximation internally — anti-aliasing is NOT applied by default on `draw_circle` or `draw_arc` in Godot 4.x (these are Canvas2D draw calls, not render-server anti-aliased primitives). At the small radii involved ([3, 12] px dot, [4, 14] px halo), the pixel-grid aliasing is a feature, not a defect — it reinforces the hard-edged period aesthetic (Art Bible §3.3).

**Default crosshair colour:** Parchment `#F2E8C8` for both dot and halo outer band. Ink Black `#1A1A1A` for halo inner band only.

**Behaviour during damage flash on health numeral:** the crosshair does NOT flash under any condition. Pillar 5 (no screen shake, no vignette, no chromatic aberration) extends to the crosshair — the centre-screen element must remain a stable aim reference. The 1-frame white flash is confined to the health numeral `Label` in the bottom-left corner (Art Bible §7D — "The numeral alone confirms."). The crosshair `Control`'s `_draw()` is unaffected by `player_damaged` — it subscribes to no damage signals.

### V.7 — Visual Restraint Compliance Check

The following elements are deliberately absent from HUD Core MVP. Each absence is a conscious art-direction decision enforcing Pillar 5 + Art Bible compliance.

| Omitted element | Authority |
|---|---|
| Outlines or strokes on gadget icons | Art Bible §7C — the silhouette IS the icon; no outline permitted |
| Drop shadows under any HUD element | Art Bible §3.3 — no soft glows, no drop shadows |
| Rounded corners on any strip or tile | Art Bible §3.3 — hard-edged rectangles only |
| Interpolated colour transitions / fade-ins on widget state changes | Art Bible §7D — "HUD update animations: instant. No count-up. No slide. No interpolation." |
| Count-up animation on health or ammo numerals | Art Bible §7D — numerals update immediately to new value |
| Screen-edge damage direction indicators | Pillar 5 + FP-6; period authenticity forbids directional screen-edge chrome |
| Alert-state visual indicators (alert level / suspicion meter) | Pillar 5 absolute — audio-only; NOLF1 fidelity; any visual equivalent would be a modern-era UI pattern |
| Hit markers / kill confirmations | Primary 5 + §Player Fantasy "This Fantasy Refuses" — Eve does not need the HUD to confirm shots landed |
| Floating damage numbers | Pillar 5 + FP-6; diegetically incoherent; modern gamification |
| Minimap / compass / radar | Pillar 2 + FP-6; categorical; discovery depends on world-reading |
| Objective markers / waypoints | Pillar 2 + FP-6; categorical |
| Stamina bar | Not modelled — Eve has no stamina system at MVP |
| Radial weapon wheel chrome | §Player Fantasy "This Fantasy Refuses" — no in-HUD sub-menus |
| Permanent centre-screen chrome beyond the crosshair | Art Bible §7A — crosshair is the sole opt-out exception |

> **📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:hud-core` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

### A.1 — Audio Requirements: HUD-to-Audio Signal Contracts

HUD Core owns **zero audio assets**. All audio is owned and mixed by the Audio system. This section documents the visual-event/audio-event pairings as contracts, not as HUD implementation items.

**Critical-state colour swap — paired with clock-tick SFX.** When F.2's edge-trigger fires and `_was_critical` flips `false → true`, the health numeral swaps to Alarm Orange. The Audio system independently subscribes to the same `player_health_changed` signal and detects the same threshold crossing. It orchestrates the clock-tick SFX onset from its own handler. HUD does NOT call any Audio function; Audio does NOT read any HUD state. They are co-subscribers to the same signal; their handlers run independently in subscription-connection order. The visual and audio effects are "paired" only in the sense that they share a common signal cause.

**Damage flash — NOT paired with audio from HUD's perspective.** The 1-frame `#FFFFFF` numeral flash is purely visual. Audio handles its damage SFX via `player_damaged` directly and independently. HUD's flash gate (333 ms cooldown) does NOT affect Audio's response — Audio fires its SFX on every `player_damaged` emission; HUD fires its flash at most 3 Hz. The two systems make independent decisions from the same signal.

**Gadget-rejection desaturation — silent by design.** The 0.2 s `modulate = (0.4, 0.4, 0.4, 1.0)` desat on `gadget_activation_rejected` produces no audio from HUD. Inventory §UI-9 owns the rejection SFX cue. Furthermore, per ADR-0002 amendment 2026-04-24, a diegetic click on failed gadget activation is a stealth liability — the Inventory CR-4b ruling makes this audio omission a design decision, not an oversight. Silence is correct.

**Prompt-strip transitions — silent.** Prompt appearing (`HIDDEN → INTERACT_PROMPT`) and dismissing produce no audio event. There is no UI click, no pop sound, no confirmation chime. The prompt is a contextual peripheral readout, not an interactive element. **REV-2026-04-26**: TAKEDOWN_CUE state removed per D4; HSS-owned states (alert-cue, MEMO_NOTIFICATION) follow their own audio rules per HSS GDD.

**Crosshair toggle — silent.** Enabling or disabling the crosshair via Settings produces no audio feedback. `visible = true/false` on the crosshair `Control` is a rendering change only.

### A.2 — Mix Bus Routing for HUD-Coupled SFX

Per Audio GDD §A.5, the SFX cues that correspond to HUD visual events route as follows. Stated here for cross-reference; Audio GDD is authoritative.

| Audio cue | Trigger signal (Audio's subscription) | Mix bus | Owned by |
|---|---|---|---|
| Clock-tick SFX (critical health onset) | `player_health_changed` (threshold crossing) | `SFX` bus | Audio system |
| Damage SFX | `player_damaged` | `SFX` bus | Audio system |
| Gadget activation SFX | `gadget_activated` (Inventory domain) | `SFX` bus | Audio system |
| Gadget rejection SFX | `gadget_activation_rejected` (Inventory domain) | `SFX` bus | Inventory / Audio system — see Inventory §UI-9 |
| Prompt-strip transition | (none — no audio event) | — | — |
| Crosshair toggle | (none — no audio event) | — | — |

HUD Core subscribes to zero of these. The routing table is reproduced here solely so the HUD-Core implementer can confirm that every visual event with a sensory pairing has a documented audio owner — and that HUD is not that owner for any of them.

## UI Requirements

HUD Core *is* a UI system — its content overlaps significantly with §C (Detailed Design) and §V (Visual Requirements). This section is a **meta-section**: it documents the UX flow boundaries, the public extension API for HUD State Signaling (system #19, VS), the accessibility floor, and the UX Flag for Phase 4 pre-production planning.

### UI-1 — UX Flow Boundaries

HUD Core has **no modal UI** — it is exclusively heads-up corner chrome plus a centre crosshair. It does not present screens, menus, dialogs, or selection grids. HUD Core's surface is:

- 5 widgets visible during `InputContext.GAMEPLAY` (Health BL / Weapon+Ammo BR / Gadget tile TR / Prompt-strip CB / Crosshair centre)
- Zero widgets visible during all other contexts (CR-10)

HUD Core does NOT own:
- Document Overlay UI (system #20) — distinct CanvasLayer at index 5
- Pause Menu / Main Menu (system #21) — distinct CanvasLayer at index 8
- Settings & Accessibility (system #23) — distinct screens within Pause/Menu
- Cutscenes & Mission Cards (system #22) — distinct CanvasLayer at index 10
- Subtitles (system #18, Dialogue & Subtitles) — distinct CanvasLayer at index 15
- HUD State Signaling (system #19, VS) — extends HUD Core via `get_prompt_label()` (UI-3)

### UI-2 — Accessibility Floor at MVP

| Requirement | Day 1 / Polish | Implementation |
|---|---|---|
| Colorblind safety on critical-health colour shift | **Day 1** | Alarm Orange paired with numeric value + clock-tick audio (Art Bible §4.5 — semantic from luminance + value, not hue alone) |
| Crosshair opt-out | **Day 1** | Default-on; toggle via `Settings → Accessibility → Crosshair` AND `Settings → HUD → Crosshair` (single source of truth, two discovery paths per Combat §UI-6) |
| Resolution-independent crosshair sizing | **Day 1** | F.4 clamps to [3, 12] px regardless of DPI; `crosshair_dot_size_pct_v` slider in Settings |
| Photosensitivity rate-gate | **Day 1** | `hud_damage_flash_cooldown_ms = 333` (3 Hz WCAG ceiling); F.1 enforced in HUD |
| Localization (`tr()`) | **Day 1** | All visible strings via `tr()`; static labels cached at `_ready()`; locale changes re-resolve via `setting_changed("locale", _, _)` |
| Hard-edged design (no motion blur / no chromatic aberration on damage) | **Day 1** | Pillar 5 absolute (Art Bible §7D) — no per-flash camera or post-process effect from HUD |
| AccessKit screen-reader live-region for HUD numerals | **Polish** (deferred per ADR-0004 §10) | `accessibility_live = "off"` on numeral Labels (per-frame updates would flood AccessKit tree); exact property name verification = ADR-0004 Gate 1 (BLOCKING for VS). **REV-2026-04-25**: Day-1 default behaviour must be confirmed (announcement-flooding suppressed) the moment Gate 1 resolves; do not wait for Polish. |
| HUD-scale slider for low-vision accessibility | **Forward-dep** (Settings & Accessibility GDD) | OQ-HUD-1; not in HUD Core MVP scope |
| **Photosensitivity opt-out toggle** | **Day 1** **(REV-2026-04-26 — Settings #23 minimal UI is HARD MVP DEP per D2; category swept 2026-04-27 closing B3)** | `hud_damage_flash_enabled: bool` (default `true`). When `false`, F.1 rate-gate is bypassed AND `_pending_flash` is never set — visual flash is fully suppressed (damage AND dry-fire). HUD Core MVP is **BLOCKED until Settings & Accessibility (system #23) ships a Day-1 minimal slice** containing: (a) the player-findable toggle UI for `damage_flash_enabled`, (b) the toggle UI for `crosshair_enabled`, and (c) a boot-screen photosensitivity warning that links to the toggle. The stub `Settings.get_setting("accessibility", "damage_flash_enabled", true)` accessor is a development scaffold ONLY (single canonical home per Settings CR-2 + line 180) — Sony TRC R4128 / Microsoft TCS / EU GAAD 2025 all require the toggle be **findable and operable by the player BEFORE the first photosensitive stimulus**. A code-only toggle without a player-accessible UI is not certification-compliant. See §C.5 BLOCKING coord item #2b. |
| **HoH/Deaf accessibility — alert-state cue** | **Day 1 — HSS minimal slice is HARD MVP DEP (REV-2026-04-26 per D3)** | Pillar 5 forbids visual alert-state indicators in HUD Core itself. The HoH/deaf accommodation is delivered via **HUD State Signaling (system #19) Day-1 minimal slice**: a brief text-only alert-state cue (`tr("HUD_GUARD_ALERTED")`) fires once on alert-state entry and auto-dismisses after ~2 s, written through `HUDCore.get_prompt_label()` (UI-3 extension API). The auto-dismiss timer lives inside HSS (NOT in HUD Core's §C.3 — HUD Core's 2-state machine has no auto-dismiss path). HUD Core MVP is **BLOCKED until HSS #19 ships this minimal slice**. The "formal accessibility exception" path that previously allowed slipping HSS is WITHDRAWN — EU GAAD enforcement requires concrete remediation, not paper exceptions. See §C.5 BLOCKING coord item #2c. |
| Reduced-motion mode | **Day 1** **(REV-2026-04-26 — disambiguated)** | The single user-facing control covering both photosensitivity AND reduced-motion needs is the `damage_flash_enabled` toggle (row above). Players who need reduced-motion accommodation set the toggle to `false` and the visual flash is fully suppressed. The F.1 rate-gate (3 Hz WCAG 2.3.1 ceiling) is a passive **harm-prevention safety floor** that is always-on — it is NOT itself the reduced-motion accommodation, which is the toggle. The two mechanisms work together: the gate prevents triggering thresholds even when the toggle is on; the toggle is the user-controlled opt-out. The dry-fire flash (CR-8) is similarly gated at 3 Hz via `_dry_fire_timer` and is suppressed by the same toggle. |

### UI-3 — Public extension API for HUD State Signaling (system #19, VS)

HUD State Signaling extends HUD Core's prompt-strip with additional states (MEMO_NOTIFICATION, alarm-state stinger banner, respawn "house lights up" beat). HUD Core defines the **single forward extension point**:

```gdscript
class_name HUDCore extends CanvasLayer

# Public extension API — HUD State Signaling subscribes via this method
func get_prompt_label() -> Label:
    return _prompt_strip_label
```

HUD State Signaling MAY:
- Read the current text/visibility of the prompt-strip Label
- Subscribe to its own signals (`document_collected`, `alert_state_changed (severity)`, `respawn_triggered`) and write to the prompt-strip via `_prompt_strip_label.text = ...` — provided HSS adds itself to the §C.3 priority resolver (extending the 3 MVP states to 5+).

HUD State Signaling MAY NOT:
- Redefine §C.3's existing 3 states
- Alter §C.4's photosensitivity gate or §F.1's algorithm
- Subscribe to any signal HUD Core already subscribes to (no double-handling)
- Modify HUD Core's mirror variables (`_current_health`, `_pending_flash`, etc.)
- Push or pop `InputContext`

HUD State Signaling extends HUD Core; it does not replace it. The extension contract is one-way: HSS reads HUD Core's exposed `get_prompt_label()` and writes through it; HUD Core does not know HSS exists.

### UI-4 — Forward dependents: UI-spec authoring per `/ux-design`

> **📌 UX Flag — HUD Core**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the HUD layout and prompt-strip behaviour **before** writing epics. Stories that reference HUD UI should cite `design/ux/hud.md`, not this GDD directly. Note this in the systems index for HUD Core (row #16) at Phase 5d.

The UX spec under `design/ux/hud.md` will produce:
- Per-resolution mockups (1080p / 1440p / 4K / 720p / ultrawide 21:9 / ultrawide 32:9) showing widget anchor placement
- Prompt-strip text-composition mockups (interact prompt key + label rendering at the inline key-rect; takedown prompt rendering)
- Critical-state colour shift before/after screenshots
- Damage flash before/after screenshots
- Gadget tile state mockups (empty 0.4 alpha / equipped / rejected desat / captured PHANTOM Red tint)
- Crosshair render at all 6 resolutions

The UX spec is implementation-side detail; this GDD owns the *behaviour*.

## Acceptance Criteria

### H.0 — Smoke-Check vs Full-Suite Gate Designation **REV-2026-04-26 — NEW**

The 22+ BLOCKING ACs in §H.1–§H.12 split into two CI gate tiers to prevent CI timeout and clarify pre-merge vs pre-story-done expectations:

**Smoke-check gate (pre-merge, must pass on every PR — fast: ~30 s total)**: AC-HUD-1.1, AC-HUD-1.2 (subscription lifecycle); AC-HUD-2.1, AC-HUD-2.2, AC-HUD-2.3, AC-HUD-2.4, AC-HUD-2.6 (health widget core paths); AC-HUD-3.1, AC-HUD-3.3, AC-HUD-3.8 (rate-gate + opt-out); AC-HUD-4.1, AC-HUD-4.2 (weapon/ammo core); AC-HUD-5.1, AC-HUD-5.2 (gadget tile core); AC-HUD-6.1, AC-HUD-6.2, AC-HUD-6.5 (prompt-strip 2-state); AC-HUD-8.1, AC-HUD-8.2 (visibility); AC-HUD-10.1, AC-HUD-10.6, AC-HUD-10.7 (FP catch-alls).

**Full-suite gate (pre-story-done, must pass before /story-done — slower: ~3-5 min total)**: All BLOCKING ACs in §H.1–§H.12 including the smoke subset.

**Performance ACs (AC-HUD-9.1 through 9.5)** run nightly on the dedicated perf rig (Iris Xe Gen 12 baseline or fallback per AC-HUD-9.1) — NOT per-PR. Sprint cannot close while any nightly perf AC fails.

### H.1 — Subscription Lifecycle

**AC-HUD-1.1 [Integration] [BLOCKING]** **REV-2026-04-26 — all 14 connections verified (was: only 10 Events bus)**: GIVEN the HUD Core scene is loaded and `Events` autoload is initialised per ADR-0007, WHEN HUD `_ready()` completes, THEN all 14 connections per CR-1 are verified: **(A) 9 `Events` autoload signals** (`player_health_changed`, `player_damaged`, `player_died`, `player_interacted`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `gadget_activation_rejected`, `ui_context_changed` — `takedown_availability_changed` removed per D4) — `Events.[signal].is_connected(handler) == true` for each; **(B) 1 Settings signal** (`Settings.setting_changed.is_connected(_on_setting_changed) == true`); **(C) 3 local Timer signals** (`_flash_timer.timeout`, `_dry_fire_timer.timeout`, `_gadget_reject_timer.timeout` each `is_connected(...) == true`); **(D) 1 viewport signal** (`get_viewport().size_changed.is_connected(_update_hud_scale) == true`). Total 14 verified. Evidence: `tests/integration/hud_core/test_subscription_lifecycle.gd`

**AC-HUD-1.2 [Integration] [BLOCKING]** **REV-2026-04-26 — all 14 disconnections verified**: GIVEN HUD Core is connected with all 14 signals/connections per CR-1, WHEN `_exit_tree()` is called, THEN all 14 are explicitly disconnected and `[source].[signal].is_connected(handler) == false` for each, with no GDScript error emitted from a missing-connection guard. Evidence: `tests/integration/hud_core/test_subscription_lifecycle.gd`

**AC-HUD-1.3 [Logic] [BLOCKING]**: GIVEN HUD Core source files in `src/ui/hud_core/**/*.gd`, WHEN a CI grep is run for signal connection calls outside `_ready()` (pattern: `\.connect\(` appearing in any function body other than `func _ready()`), THEN zero matches are found. Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd` (grep gate)

**AC-HUD-1.4 [Integration] [BLOCKING]**: GIVEN a live session where `section_entered` fires once (section transition), WHEN the HUD scene is interrogated immediately after the transition, THEN each signal still has exactly one connection to its handler — no double-connect, no disconnect. Evidence: `tests/integration/hud_core/test_subscription_lifecycle.gd`

**AC-HUD-1.5 [Integration] [BLOCKING]** **REV-2026-04-26 — connection count updated**: GIVEN a `LOAD_FROM_SAVE` trigger that frees and re-instantiates the HUD scene, WHEN the new HUD instance's `_ready()` completes and LSS re-emits `player_health_changed(50, 100)`, `ammo_changed("walther_ppk", 6, 21)`, `weapon_switched("walther_ppk")`, `gadget_equipped("cigarette_case")`, `ui_context_changed(InputContext.Context.GAMEPLAY, InputContext.Context.MENU)` *(args: new_ctx=GAMEPLAY, prev_ctx=MENU — i.e. transitioning INTO gameplay, which is the visible-HUD state per AC-HUD-8.1)*, THEN all five widgets reflect the replayed values, `hud_root.visible == true`, and all 9 `Events`-bus signals (was 10; `takedown_availability_changed` removed per D4) are connected exactly once in the new instance. The full 14-connection inventory per AC-HUD-1.1 is also satisfied (14 connections total). Evidence: `tests/integration/hud_core/test_save_load_lifecycle.gd`

### H.2 — Health Widget

**AC-HUD-2.1 [Logic] [BLOCKING]**: GIVEN HUD is visible and health is at 60, WHEN `player_health_changed(55, 100)` is emitted, THEN the health `Label` reads `"55"` within 1 physics frame of the signal dispatch. Evidence: `tests/unit/hud_core/test_health_widget.gd`

**AC-HUD-2.2 [Logic] [BLOCKING]**: GIVEN `_was_critical = false` and current health is 25 HP (ratio = 0.25), WHEN `player_health_changed(24, 100)` is emitted, THEN `_was_critical` flips to `true` and `add_theme_color_override(&"font_color", alarm_orange)` is called exactly once (Alarm Orange `#E85D2A`), verifiable by checking the Label's `font_color` override equals `Color("#E85D2A")`. Evidence: `tests/unit/hud_core/test_health_widget.gd`

**AC-HUD-2.3 [Logic] [BLOCKING]**: GIVEN `_was_critical = false` and current health is 25 HP, WHEN `player_health_changed(25, 100)` is emitted, THEN `_was_critical` remains `false` and no colour override is changed (health numeral stays Parchment `#F2E8C8`). This asserts the strict `<` boundary — 25/100 = 0.25 is NOT critical. Evidence: `tests/unit/hud_core/test_health_widget.gd`

**AC-HUD-2.4 [Logic] [BLOCKING]**: GIVEN `_was_critical = true` and current health is 24 HP, WHEN `player_health_changed(25, 100)` is emitted, THEN `_was_critical` flips to `false` and the colour override reverts to Parchment `#F2E8C8` on that same frame. Recovery is immediate; no hysteresis. Evidence: `tests/unit/hud_core/test_health_widget.gd`

**AC-HUD-2.5 [Logic] [BLOCKING]**: GIVEN a damage flash is in-flight (1-frame `await process_frame` coroutine), WHEN the revert fires, THEN the colour reverts to `_current_health_color` as captured at the start of the `await` (before suspension) — not re-read after suspension. Verified by asserting: (a) if `_was_critical` was `false` at flash-start and flips to `true` before revert, the revert still applies the pre-captured Parchment colour; (b) post-revert, the Label's colour matches the captured value, not the post-flip colour. Evidence: `tests/unit/hud_core/test_damage_flash.gd`

**AC-HUD-2.6 [Logic] [BLOCKING]**: GIVEN `player_health_changed(0, 100)` is emitted, WHEN the health Label is read, THEN it displays the string `"0"` (not `"00"`, `"000"`, or empty). Evidence: `tests/unit/hud_core/test_health_widget.gd`

**AC-HUD-2.7 [UI] [ADVISORY]** **REV-2026-04-26 — named tool + deterministic sampling**: GIVEN the HUD is rendered in the Restaurant reference scene at 1080p, default lighting configuration (post-process sepia stack at default intensity per Outline-Pipeline GDD), with Alarm Orange active (`_was_critical = true`), WHEN a screenshot is taken at the canonical pixel coordinate of the health widget centre (BL anchor + 32 px margin + half widget width + half widget height; coordinates recorded numerically in evidence), THEN Alarm Orange `#E85D2A` achieves a minimum luminance contrast ratio of **3.0:1** (WCAG 2.1 SC 1.4.11 Non-text Contrast threshold) against the sampled wall colour at that pixel coordinate, AND a colorblind simulation (deuteranopia, protanopia, tritanopia) preserves a minimum **delta-luminance ≥ 0.1** between the critical and non-critical Parchment `#F2E8C8` states. **Tool: WebAIM Contrast Checker (web tool, version-pinned by URL date) for the contrast ratio; `colorblindly` (npm package, version-pinned in evidence) for the colorblind simulation**. The pinned tool versions and the screenshot pixel coordinates are recorded in the evidence file. Evidence: `production/qa/evidence/hud_core/screenshot_critical_health_restaurant_<date>.png` + `contrast_<date>.txt` (raw measurement + tool version + pixel coordinate + delta-luminance computation).

### H.3 — Photosensitivity Rate-Gate (F.1)

**AC-HUD-3.1 [Logic] [BLOCKING]** **REV-2026-04-26 — single timer mechanism**: GIVEN `_flash_timer` is stopped, WHEN `player_damaged` is emitted at simulated test-harness times `t=0 ms`, `t=150 ms`, and `t=250 ms` advanced via **`_flash_timer.timeout.emit()` ONLY** (the prior disjunction with `gut.simulate()` is removed because `emit()` and `simulate()` produce different `Timer.time_left` state and are NOT equivalent for state-assertion purposes; **real-time `await get_tree().create_timer(...)` is also NOT permitted** — tests must be deterministic), THEN exactly 2 flash events fire: one immediate at `t=0` (gate opens, timer starts) and one deferred at `t=333 ms` (timer timeout fires, `_pending_flash` was `true`). The 3rd hit at `t=250 ms` produces no additional flash output. Verified by a signal-spy on `_execute_flash` counting 2 invocations total. Evidence: `tests/unit/hud_core/test_damage_flash.gd`

**AC-HUD-3.2 [Logic] [BLOCKING]** **REV-2026-04-26 — float literal removed**: GIVEN 100 `player_damaged` signals are emitted in a single test frame via `for i in 100: Events.player_damaged.emit(...)` (no `await` between iterations — fully synchronous loop), WHEN the loop completes, THEN exactly 1 immediate flash has fired (iteration 1 found `is_stopped() == true`), `_pending_flash == true`, `_flash_timer.is_stopped() == false`, and `_flash_timer.time_left == _flash_timer.wait_time` (the timer was started at iteration 1 and no simulated time has elapsed within the synchronous loop — assert against the timer's own `wait_time`, NOT a literal `0.333` which is not exactly representable in IEEE 754 binary). After advancing simulated time via `_flash_timer.timeout.emit()` to the timeout boundary, exactly 1 deferred flash fires and `_pending_flash` resets to `false`. Total flash output: 2. Evidence: `tests/unit/hud_core/test_damage_flash.gd`

**AC-HUD-3.3 [Logic] [BLOCKING]**: GIVEN `_flash_timer` is running (`is_stopped() == false`) and `_pending_flash == true`, WHEN `player_died` is emitted, THEN `_flash_timer.is_stopped() == true` (timer is stopped) AND `_pending_flash == false` after the `_on_player_died` handler returns. No deferred flash fires after death. Evidence: `tests/unit/hud_core/test_damage_flash.gd`

**AC-HUD-3.4 [Integration] [BLOCKING]**: GIVEN a `LOAD_FROM_SAVE` that re-instantiates the HUD scene, WHEN the new instance's `_ready()` completes, THEN `_flash_timer.is_stopped() == true` AND `_pending_flash == false`. Evidence: `tests/integration/hud_core/test_save_load_lifecycle.gd`

**AC-HUD-3.5 [Integration] [BLOCKING]**: GIVEN a flash gate that is running at `t=200 ms` into its 333 ms window (gate closed), WHEN a `section_entered` signal fires, THEN `_flash_timer.is_stopped() == false` (the timer was NOT reset) AND `_pending_flash` retains its pre-transition value. The gate carries across section transitions per §C.4 reset semantics table. Evidence: `tests/integration/hud_core/test_subscription_lifecycle.gd`

**AC-HUD-3.6 [Integration] [BLOCKING]**: GIVEN a `player_damaged` event triggers a flash, WHEN the flash gate is active, THEN Audio's damage SFX handler fires independently — verified by asserting the Audio signal observer is invoked once regardless of the HUD gate state. HUD's flash gate does NOT suppress Audio's SFX response to the same `player_damaged` emission. Evidence: `tests/integration/hud_core/test_cross_system_flash_independence.gd`

**AC-HUD-3.7 [Logic] [BLOCKING]** **REV-2026-04-26 — single mandated implementation (was disjunction); category swept 2026-04-27 closing B3**: GIVEN cached ammo state is `("walther_ppk", 0, 0)` and `Settings.get_setting("accessibility", "damage_flash_enabled", true) == true`, WHEN `ammo_changed("walther_ppk", 0, 0)` is emitted 60 consecutive times across 1 second of simulated input (held trigger with empty magazine — dry-fire pattern at 60 Hz keyboard repeat rate), THEN the consolidated ammo Label dry-fire flash fires at most **3 times in that 1-second window** — rate-gated to the WCAG 2.3.1 ceiling (3 Hz) via the **dedicated `_dry_fire_timer: Timer` child node** (`one_shot = true`, `wait_time = 0.333`) per CR-8. The dedicated-timer path is mandated (not the shared `_flash_timer`) so damage and dry-fire flash channels remain semantically distinct: a damage flash does NOT block a dry-fire flash within the same 333 ms window, and vice versa. Evidence: `tests/unit/hud_core/test_weapon_ammo_widget.gd`

**AC-HUD-3.8 [Logic] [BLOCKING]** **REV-2026-04-25 — NEW (Day-1 photosensitivity opt-out); category swept 2026-04-27 closing B3**: GIVEN `Settings.get_setting("accessibility", "damage_flash_enabled", true) == false`, WHEN `player_damaged(amount, source, is_critical)` is emitted, THEN no visual flash fires — `_flashing` remains `false`, `_pending_flash` remains `false`, `_flash_timer` remains stopped, and the health Label's `font_color` override is unchanged. Audio SFX handler still fires independently (same `player_damaged` signal — see AC-HUD-3.6). When the toggle flips back to `true`, the next `player_damaged` event resumes normal F.1 rate-gated behaviour. Evidence: `tests/integration/hud_core/test_photosensitivity_optout.gd`

### H.4 — Weapon + Ammo Widget

**AC-HUD-4.1 [Logic] [BLOCKING]**: GIVEN current weapon is `"walther_ppk"`, WHEN `weapon_switched("silenced_ppk")` is emitted, THEN the weapon-name Label reads `tr("silenced_ppk")` within 1 physics frame of the signal. Evidence: `tests/unit/hud_core/test_weapon_ammo_widget.gd`

**AC-HUD-4.2 [Logic] [BLOCKING]** **REV-2026-04-25**: GIVEN weapon `"walther_ppk"` is active with ammo `7 / 21`, WHEN `ammo_changed("walther_ppk", 6, 21)` is emitted, THEN the consolidated ammo Label reads exactly `"6 / 21"` (single Label, formatted string per §V.3) within 1 physics frame. Evidence: `tests/unit/hud_core/test_weapon_ammo_widget.gd`

**AC-HUD-4.3 [Logic] [BLOCKING]** **REV-2026-04-25**: GIVEN the active weapon slot is Slot 4 (blade/melee weapon), WHEN `weapon_switched("blade_slot4")` is emitted followed by `ammo_changed("blade_slot4", 0, 0)`, THEN the consolidated ammo Label displays the dash glyph `"—"` (single dash, no `"/"`) and not a numeric string. Evidence: `tests/unit/hud_core/test_weapon_ammo_widget.gd`

**AC-HUD-4.4 [Logic] [BLOCKING]** **REV-2026-04-25**: GIVEN no weapon is equipped in Slot 3 (rifle, pre-pickup state), WHEN `weapon_switched("rifle_slot3_empty")` is emitted, THEN both the weapon-name Label and the consolidated ammo Label display the dash glyph `"—"`. Evidence: `tests/unit/hud_core/test_weapon_ammo_widget.gd`

**AC-HUD-4.5 [Logic] [BLOCKING]** **REV-2026-04-26 — rate-gated per D1**: GIVEN cached ammo state is `("walther_ppk", 0, 0)` (sentinel non-default — first prior `ammo_changed` already received) and `_dry_fire_timer` is stopped, WHEN `ammo_changed("walther_ppk", 0, 0)` is emitted (unchanged values — dry-fire pattern), THEN the consolidated ammo Label triggers a 1-frame magazine-numeral flash distinct from the damage flash, verified by a spy on the dry-fire flash path executing once, AND `_dry_fire_timer.is_stopped() == false` immediately after. The dry-fire flash is **rate-gated by the dedicated `_dry_fire_timer`** (separate from `_flash_timer`); subsequent unchanged-value `ammo_changed` events arriving while `_dry_fire_timer` is running set `_pending_dry_fire = true` and do NOT fire an immediate flash. Evidence: `tests/unit/hud_core/test_weapon_ammo_widget.gd`. (Note: AC-HUD-3.7 covers the sustained-input WCAG 3 Hz ceiling with the same gate.)

**AC-HUD-4.6 [Visual] [ADVISORY]** **REV-2026-04-25**: GIVEN the consolidated weapon + ammo widget is rendered at 1080p, WHEN a screenshot is taken, THEN the slash glyph `"/"` between current and reserve ammo renders within the same 22 px Futura Condensed Bold register as the numerals (post-consolidation). **Art-direction acceptance**: §7A originally specified 70%-width slash via separate Labels; the consolidated form trades that precision for F.5 budget compliance. Pass condition: visual reading of the ammo readout remains legible at 1080p and 720p, and Art Director approves the consolidated typographic register OR specifies a fontvariant fallback. Evidence: `production/qa/evidence/hud_core/screenshot_ammo_consolidated_<date>.png` + Art Director sign-off (or recorded objection that triggers OQ-HUD-5 path b).

### H.5 — Gadget Tile Widget

**AC-HUD-5.1 [Logic] [BLOCKING]**: GIVEN gadget slot is empty (no gadget equipped), WHEN `gadget_equipped("cigarette_case")` is emitted, THEN the gadget tile icon updates to `tr("cigarette_case")` glyph within 1 physics frame and `modulate` returns to `Color.WHITE` (alpha 1.0). Evidence: `tests/unit/hud_core/test_gadget_tile_widget.gd`

**AC-HUD-5.2 [Logic] [BLOCKING]**: GIVEN no gadget is currently equipped (empty slot state), WHEN the gadget tile is rendered, THEN `gadget_tile.modulate.a == 0.4` (alpha 0.4 per §C.2 empty-slot rule). Evidence: `tests/unit/hud_core/test_gadget_tile_widget.gd`

**AC-HUD-5.3 [Logic] [BLOCKING]**: GIVEN `gadget_tile.modulate == Color.WHITE`, WHEN `gadget_activation_rejected("cigarette_case")` is emitted, THEN `gadget_tile.modulate` equals `Color(0.4, 0.4, 0.4, 1.0)` immediately after the handler returns, and reverts to `Color.WHITE` after `gadget_rejected_desat_duration_s = 0.2` seconds (verified by awaiting `_gadget_reject_timer.timeout` in the test). Evidence: `tests/unit/hud_core/test_gadget_tile_widget.gd`

**AC-HUD-5.4 [Visual] [ADVISORY]**: GIVEN the Cigarette Case gadget is equipped, WHEN the gadget tile is rendered, THEN the sound-wave glyph (3 concentric arcs, ~12 × 12 px, Parchment `#F2E8C8`) is visible in the upper-right corner of the tile. For a non-noisy gadget (e.g. `"compact"` or `"parfum"`), the sound-wave glyph does NOT appear. Evidence: `production/qa/evidence/hud_core/screenshot_gadget_sound_wave_<date>.png` + art-director sign-off.

**AC-HUD-5.5 [Visual] [ADVISORY]**: GIVEN a captured-equipment gadget is equipped, WHEN the gadget tile is rendered, THEN the tile background tint is PHANTOM Red `#C8102E`, visually distinct from the default BQA Blue `#1B3A6B`. Evidence: `production/qa/evidence/hud_core/screenshot_gadget_phantom_red_<date>.png` + art-director sign-off.

**AC-HUD-5.6 [Logic] [BLOCKING]**: GIVEN 10 `gadget_activation_rejected("cigarette_case")` signals emitted synchronously in one frame, WHEN all handlers complete, THEN the `_gadget_reject_timer` is running (not stopped), `gadget_tile.modulate == Color(0.4, 0.4, 0.4, 1.0)`, and no crash or exception has occurred. The desat timer resets on each rejection; the 10th call owns the 0.2 s window. Evidence: `tests/unit/hud_core/test_gadget_tile_widget.gd`

**AC-HUD-5.7 [UI] [BLOCKING]** **REV-2026-04-26 — NEW (gadget empty-tile WCAG 3:1 contrast gate)**: GIVEN the gadget tile is rendered in the empty state (`modulate.a = gadget_empty_tile_alpha`) at 1080p in the Restaurant reference scene with default lighting, WHEN a screenshot is taken at the canonical pixel coordinate of the gadget-tile centre (TR anchor + 32 px margin from edges + half tile size), THEN the rendered tile achieves a minimum luminance contrast ratio of **3.0:1** (WCAG 2.1 SC 1.4.11) against the sampled adjacent surface colour at that pixel coordinate. Tool: WebAIM Contrast Checker (version-pinned per AC-HUD-2.7). If the default `gadget_empty_tile_alpha = 0.4` fails 3:1, raise the tuning knob to `0.55` (still inside the [0.2, 0.6] safe range per §G.1) and re-test; if still failing, escalate to art-director for a 1 px Parchment outline per §V.7's "no outline" rule exception. Evidence: `production/qa/evidence/hud_core/screenshot_gadget_empty_tile_contrast_<date>.png` + `contrast_<date>.txt`.

### H.6 — Prompt-Strip State Machine (CR-12)

**AC-HUD-6.1 [Logic] [BLOCKING]** **REV-2026-04-26 — TAKEDOWN_CUE precondition removed**: GIVEN `pc != null` and `pc.get_current_interact_target()` returns `null`, WHEN `_process` evaluates the resolver, THEN the prompt-strip `Label.visible == false` and prompt state is `HIDDEN`. Evidence: `tests/unit/hud_core/test_prompt_strip_state_machine.gd`

**AC-HUD-6.2 [Logic] [BLOCKING]** **REV-2026-04-26 — TAKEDOWN_CUE precondition removed**: GIVEN `pc != null`, `pc.get_current_interact_target()` returns a non-null stub target with `interact_label_key = &"HUD_INTERACT_LIFT_COVER"`, and `pc.is_hand_busy()` returns `false`, WHEN `_process` evaluates the resolver, THEN the prompt-strip `Label.visible == true` and `Label.text` equals the composed string `tr("HUD_INTERACT_PROMPT") + _current_interact_glyph + " " + tr("HUD_INTERACT_LIFT_COVER")` per `_compose_prompt_text()` (CR-3 + §C.3 + CR-21). Evidence: `tests/unit/hud_core/test_prompt_strip_state_machine.gd`

~~**AC-HUD-6.3**~~ **REMOVED REV-2026-04-26 per D4** — TAKEDOWN_CUE state cut from MVP; latch + signal subscription deleted; AC asserting TAKEDOWN_CUE rendering is no longer applicable.

~~**AC-HUD-6.4**~~ **REMOVED REV-2026-04-26 per D4** — same rationale as AC-HUD-6.3.

**AC-HUD-6.5 [Logic] [BLOCKING]** **REV-2026-04-26 — simplified (TAKEDOWN_CUE removed)**: GIVEN `pc.get_current_interact_target()` returns a non-null target AND `pc.is_hand_busy()` returns `true`, WHEN `_process` evaluates the resolver, THEN the prompt-strip `Label.visible == false` (INTERACT_PROMPT is suppressed during hand-busy window). Evidence: `tests/unit/hud_core/test_prompt_strip_state_machine.gd`

**AC-HUD-6.6 [Logic] [BLOCKING]**: GIVEN the prompt-strip is in `INTERACT_PROMPT` state with text `"PRESS [E] TO LIFT COVER"`, WHEN `_process` fires on a subsequent frame with identical target and state, THEN `Label.text =` is NOT called again (change-guard prevents redundant TextServer invalidation). Verified by spying on `Label.text` setter: assert setter called at most once total across N identical frames. Evidence: `tests/unit/hud_core/test_prompt_strip_state_machine.gd`

**AC-HUD-6.7 [Logic] [BLOCKING]** **REV-2026-04-26 — explicit `await` after `queue_free()`**: GIVEN `pc.get_current_interact_target()` returns a valid stub target, WHEN the test calls `target.queue_free()` THEN `await get_tree().process_frame` (Godot 4.6 frees nodes at end-of-frame; without the `await`, `is_instance_valid()` still returns `true` on the same frame as `queue_free()` — making the assertion meaningless), AND THEN `_compose_prompt_text()` is invoked, THEN `is_instance_valid(target)` is checked before any property access on `target` and `_compose_prompt_text` returns the empty string `""` without a null-deref crash. Evidence: `tests/unit/hud_core/test_prompt_strip_state_machine.gd`

### H.7 — Crosshair Widget

**AC-HUD-7.1 [Logic] [BLOCKING]**: GIVEN `crosshair_dot_size_pct_v = 0.19` and `viewport_height_px = 1080`, WHEN F.4 is evaluated, THEN `dot_radius_px = clamp(0.19 × 1080 / 100, 3, 12) = clamp(2.052, 3, 12) = 3`. GIVEN `viewport_height_px = 2160` (4K), THEN `dot_radius_px = clamp(0.19 × 2160 / 100, 3, 12) = clamp(4.104, 3, 12) = 4`. GIVEN `viewport_height_px = 1440`, THEN `dot_radius_px = 3`. All three values asserted in one parameterised test. Evidence: `tests/unit/hud_core/test_crosshair_widget.gd`

**AC-HUD-7.2 [Logic] [BLOCKING]**: GIVEN `crosshair_dot_size_pct_v = 1.0` and `viewport_height_px = 2160`, WHEN F.4 is evaluated, THEN `dot_radius_px = clamp(21.6, 3, 12) = 12` (upper clamp fires). GIVEN `crosshair_dot_size_pct_v = 0.01` and `viewport_height_px = 720`, THEN `dot_radius_px = 3` (lower clamp fires). Evidence: `tests/unit/hud_core/test_crosshair_widget.gd`

**AC-HUD-7.3 [Logic] [BLOCKING]**: GIVEN `hud_root.visible = true` AND `_crosshair_enabled_mirror = true`, WHEN the crosshair widget's visibility is evaluated, THEN `crosshair.visible == true`. GIVEN either `hud_root.visible = false` OR `_crosshair_enabled_mirror = false`, THEN `crosshair.visible == false` (AND logic). All four combinations tested. Evidence: `tests/unit/hud_core/test_crosshair_widget.gd`

**AC-HUD-7.4 [Logic] [BLOCKING]**: GIVEN `_crosshair_enabled_mirror = true`, WHEN `setting_changed("accessibility", "crosshair_enabled", false)` is emitted, THEN `_crosshair_enabled_mirror == false` and `crosshair.visible == false` within the same frame (no deferred update). WHEN `setting_changed("accessibility", "crosshair_enabled", true)` is emitted, THEN `_crosshair_enabled_mirror == true` and crosshair visibility reverts to `hud_root.visible`. Evidence: `tests/unit/hud_core/test_crosshair_widget.gd`

**AC-HUD-7.5 [Visual] [ADVISORY]**: GIVEN the crosshair is rendered at 1080p with `tri_band` halo style, WHEN a screenshot is taken, THEN the tri-band halo composition is visible (Parchment outer ring + Ink Black inner ring + Parchment center dot), legible against the Restaurant reference scene background. Evidence: `production/qa/evidence/hud_core/screenshot_crosshair_triband_<date>.png` + art-director sign-off.

### H.8 — InputContext Visibility (CR-10)

**AC-HUD-8.1 [Logic] [BLOCKING]**: GIVEN `hud_root.visible = false`, WHEN `ui_context_changed(GAMEPLAY, MENU)` is emitted (transition from MENU to GAMEPLAY), THEN `hud_root.visible == true` on the same frame. Evidence: `tests/unit/hud_core/test_input_context_visibility.gd`

**AC-HUD-8.2 [Logic] [BLOCKING]**: GIVEN `hud_root.visible = true`, WHEN `ui_context_changed(MENU, GAMEPLAY)` is emitted (transition from GAMEPLAY to MENU), THEN `hud_root.visible == false` on the same frame. Evidence: `tests/unit/hud_core/test_input_context_visibility.gd`

**AC-HUD-8.3 [Logic] [BLOCKING]**: GIVEN `hud_root.visible = true`, WHEN `ui_context_changed(GAMEPLAY, GAMEPLAY)` is emitted (no context change), THEN `hud_root.visible` remains `true` and no visible flicker occurs (visibility property is set to an identical value — a no-op write in Godot). Evidence: `tests/unit/hud_core/test_input_context_visibility.gd`

**AC-HUD-8.4 [Logic] [BLOCKING]**: GIVEN HUD Core source files, WHEN a CI grep searches for `InputContext\.current\(\)` outside of the single `_ready()` one-time-read site, THEN zero matches are found. HUD polls `InputContext.current()` exactly once (at `_ready()` initialisation), never in `_process`. Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd` (grep gate)

### H.9 — Performance (F.5 + ADR-0008 Slot 7)

**AC-HUD-9.1 [Logic] [BLOCKING]** **REV-2026-04-26 — fallback rewritten (no nonexistent table reference)**: GIVEN the Restaurant reference scene running on Iris Xe Gen 12 hardware at 810p, WHEN HUD frame cost is sampled over 300 consecutive frames at idle (no signal emissions, only prompt-strip poll), THEN p95 frame cost ≤ 0.3 ms as measured by **HUD-scoped `Time.get_ticks_usec()` bracketing** in a test-only debug build (entry timestamp at start of `_process`, exit at end; difference recorded into a sample array; p95 computed in the test harness). **Hardware fallback (REV-2026-04-26 — no table reference)**: if Iris Xe Gen 12 is unavailable, the test runs on the available CI runner GPU and asserts the p95 frame cost recorded as raw evidence. The 0.3 ms ADR-0008 Slot 7 cap remains the contractual ceiling on Iris Xe; a fallback measurement that *passes* on weaker hardware is informative. A fallback measurement that *fails* must be repeated on Iris Xe Gen 12 before the AC can be marked failed (the fallback hardware may be slower; failure on slower hardware is not necessarily failure on the reference). The CI runner baseline GPU model and driver version MUST be recorded in the evidence file. Evidence: `tests/unit/hud_core/test_performance_budget.gd` (headless timing harness with `OS.is_debug_build()` guard) + `production/qa/evidence/hud_core/perf_baseline_<hardware>_<date>.txt`.

**AC-HUD-9.2 [Logic] [BLOCKING]** **REV-2026-04-26 — formula corrected (N=4, `C_draw` included, `C_a11y` included)**: GIVEN a synthetic worst-case frame (5 simultaneous signal emissions: `player_damaged`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `player_health_changed` with critical-state threshold crossing — note `gadget_equipped` swaps a `TextureRect.texture` and is NOT counted as a `C_label` term), WHEN F.5 is computed, THEN `C_frame` ≤ 0.3 ms as asserted by the canonical formula: `C_draw + C_poll + (C_label × N_label_updates) + (C_flash × flash_active) + (C_theme_override × N_theme_override_writes) + C_a11y` with `N_label_updates ≤ 4` (health, weapon-name, ammo, prompt-strip — gadget icon is `TextureRect`), `N_theme_override_writes ≤ 2` (crit edge + flash start), `flash_active ≤ 2`. Pessimistic-upper-bound figure: `0.020 + 0.004 + 4 × 0.050 + 2 × 0.005 + 2 × 0.015 + 0.030 = 0.294 ms`. The test emits all 5 signals on a single frame and asserts measured frame time does not exceed 0.3 ms on the reference hardware profile (or fallback per AC-HUD-9.1). Evidence: `tests/unit/hud_core/test_performance_budget.gd`

**AC-HUD-9.3 [Logic] [BLOCKING]**: GIVEN the worst-case frame scenario (AC-HUD-9.2), WHEN it fires 60 consecutive times (1 second sustained at 60 Hz), THEN no individual frame exceeds 0.3 ms and the average cost does not drift upward (no memory leak, no timer accumulation). Evidence: `tests/unit/hud_core/test_performance_budget.gd`

**AC-HUD-9.4 [Logic] [BLOCKING]** **REV-2026-04-26 — single authoritative rule (was disjunction)**: GIVEN HUD Core source files in `src/ui/hud_core/**/*.gd` (excluding `tests/`), WHEN a CI grep is run for the literal pattern `.text =` inside any function body whose signature is `_process(` or `_physics_process(`, THEN **zero matches** are required. The rule is the strict form: NO `.text =` writes appear inside `_process` or `_physics_process` under any circumstances. Implementers route ALL Label updates exclusively through signal handlers (which can write `Label.text` freely outside `_process`). The prior "AST gate OR stricter rule" disjunction is collapsed to this single rule because a CI auditor cannot determine which of two non-equivalent pass conditions is the spec's intent. Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd` (single grep gate).

**AC-HUD-9.5 [Logic] [BLOCKING]**: GIVEN HUD's signal subscriptions, WHEN `_process` is profiled over 1000 frames with no signal activity, THEN `_process` accesses exactly 2 external method calls per frame (`pc.get_current_interact_target()` and `pc.is_hand_busy()`) and no additional system polls are present. Verified by static analysis grep for any method call on non-PC nodes inside `_process`. Evidence: `tests/unit/hud_core/test_performance_budget.gd`

### H.10 — Forbidden Patterns (CI Grep Gates)

**REV-2026-04-25 — scope scoping rule for ALL H.10 ACs**: every grep in this section is scoped to `src/ui/hud_core/**/*.gd` (and `**/*.tscn` where noted) ONLY. The `tests/` directory is explicitly excluded from all H.10 grep runs — test-helper stubs may legitimately reference forbidden classes/signals as mocks. Implementations must use either explicit path filters (`grep -E ... src/ui/hud_core/`) or `git ls-files src/ui/hud_core/ | xargs grep ...`. Patterns that name specific class names (e.g., `StealthAI`) use word-boundary anchors (`\b...\b`) where the class-name match must be exact, to avoid catching renamed/derived classes that should be allowed.

**AC-HUD-10.1 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd` (excluding `tests/`), WHEN grep runs pattern `Events\.[a-zA-Z_]+\.emit\(`, THEN zero matches (FP-1: no signal emission). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.2 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `pc\.(health|max_health|current_health|stamina|is_crouching|is_sprinting|inventory)`, THEN zero matches (FP-2: no direct PC property access). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.3 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(InventorySystem|CombatSystemNode|StealthAI|CivilianAI|FailureRespawnService|MissionScriptingService)\.[a-zA-Z_]+\(`, THEN zero matches (FP-3: no polling of non-authorised systems). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.4 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(WeaponResource|GadgetResource|preload|load)\([^)]*\.tres`, THEN zero matches (FP-4: no runtime Resource instantiation). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.5 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `weapon_dry_fire_click\.connect`, THEN zero matches (FP-5: Audio's exclusive subscription). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.6 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd` and `src/ui/hud_core/**/*.tscn`, WHEN grep runs pattern `(waypoint|minimap|objective_marker|alert_indicator|radar|compass|map_overlay|nav_arrow)`, THEN zero matches (FP-6: Pillar 2 + Pillar 5 absolute exclusion). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.7 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `InputContext\.(push|pop|set)\(`, THEN zero matches (FP-7: HUD reacts, never modifies InputContext). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.8 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(_process|_physics_process)\s*\([^)]*\)\s*->[^{]*\{[^}]*tr\(`, THEN zero matches (FP-8: no per-frame `tr()` calls). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.9 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `FontRegistry\.hud_numeral\([^)]*delta[^)]*\)` (or any `_process`-derived dynamic expression), THEN zero matches (FP-9: FontRegistry called with static arg only). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.10 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(register_restore_callback|func capture\(\))`, THEN zero matches (FP-12: no save/load registration). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.11 [Logic] [BLOCKING]**: GIVEN `src/ui/hud_core/**/*.gd`, WHEN grep runs pattern `(Engine\.get_singleton|get_tree\(\)\.root\.get_node)`, THEN zero matches (FP-14: no raw tree-walk singleton lookup). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.12 [Logic] [BLOCKING]** (AC-HUD-pillar-1 from §E Cluster J): GIVEN HUD scene files `src/ui/hud_core/**/*.tscn` and source files, WHEN a CI scene-tree scan searches for node names matching `(guard_killed|target_eliminated|kill_confirmed|kill_feed|hit_marker|floating_damage)`, THEN zero node names match. Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-10.13 [Logic] [BLOCKING]** (AC-HUD-pillar-2 from §E Cluster J): GIVEN HUD scene files and source files, WHEN a CI scene-tree scan searches for node names matching `(damage_direction|hit_indicator|direction_indicator|compass|radar|nav_arrow)`, THEN zero node names match (Pillar 5 absolute exclusion enforced via scene-tree scan, not just source grep). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

### H.11 — Locale + Accessibility

**AC-HUD-11.1 [Logic] [BLOCKING]**: GIVEN locale is `"en"` and static label `"HUD_INTERACT_PROMPT"` is cached, WHEN `setting_changed("locale", "en", "fr")` is emitted, THEN all static label caches are re-resolved via `tr()` and the prompt-strip `_last_state` sentinel is invalidated (set to `-1` or equivalent) so the next `_process` frame re-composes the prompt text in French. Evidence: `tests/unit/hud_core/test_locale_accessibility.gd`

**AC-HUD-11.2 [Logic] [BLOCKING]**: GIVEN locale changes to `"fr"`, WHEN `tr(_weapon_id)` and `tr(_gadget_id)` are re-resolved in the locale-change handler, THEN the weapon-name Label and gadget-tile Label update to their French translations within the same frame the `setting_changed` handler executes. No `tr()` call occurs in `_process` (FP-8 maintained). Evidence: `tests/unit/hud_core/test_locale_accessibility.gd`

**AC-HUD-11.3 [Logic] [BLOCKING]** **REV-2026-04-25 — regex corrected**: GIVEN HUD Core source files in `src/ui/hud_core/**/*.gd` (excluding `tests/`), WHEN grep runs pattern `\.text\s*=\s*"` (any `.text = "literal"` string-literal assignment, regardless of whether the literal contains `t` or `r`), THEN zero matches are found. The earlier pattern `\.text = "[^t][^r]\(` was malformed (incorrectly negating two character positions) and would produce both false positives and false negatives. The corrected rule is: NO raw string literals are ever assigned to `.text` — every visible string flows through `tr()`, which produces the form `.text = tr("KEY")` (function call, NOT a string literal, so the corrected regex does not match it). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-11.4 [Logic] [BLOCKING]**: GIVEN HUD Core source files, WHEN grep runs for `FontRegistry\.hud_numeral\(` invocations outside of `_ready()`, THEN zero matches. `FontRegistry.hud_numeral(rendered_size_px)` is called exactly once per numeric Label at scene `_ready()` with a static constant argument. Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

~~**AC-HUD-11.5**~~ **MOVED to OQ-HUD-8 REV-2026-04-26** — this was a deferred-to-Polish open issue masquerading as an AC; AC sets are inflated by entries that cannot Pass/Fail this sprint. The AccessKit live-region behaviour is now tracked as OQ-HUD-8 (see Open Questions section).

### H.12 — Save/Load + LOAD_FROM_SAVE

**AC-HUD-12.1 [Logic] [BLOCKING]**: GIVEN HUD Core source files, WHEN grep runs pattern `(register_restore_callback|func capture\(\))`, THEN zero matches. HUD has no `capture()` method and registers no restore callback (CR-20, FP-12). Evidence: `tests/unit/hud_core/test_forbidden_patterns.gd`

**AC-HUD-12.2 [Integration] [BLOCKING]** **REV-2026-04-26 — `_takedown_eligible` removed; `_dry_fire_timer` + sentinel caches added**: GIVEN a `LOAD_FROM_SAVE` trigger frees the HUD scene and re-instantiates it, WHEN `_ready()` completes on the new instance, THEN all widget mirror variables (`_current_health`, `_max_health`, `_weapon_id`, `_ammo_current`, `_ammo_reserve`, `_gadget_id`, `_was_critical`, `_flashing`, `_pending_flash`, `_pending_dry_fire`, `_last_ammo_weapon_id == &""` sentinel, `_last_interact_label_key == &""` sentinel) are at their zero/empty defaults before any LSS restore signals arrive. `_flash_timer` and `_dry_fire_timer` are stopped. Evidence: `tests/integration/hud_core/test_save_load_lifecycle.gd`

**AC-HUD-12.3 [Integration] [BLOCKING]**: GIVEN the default-zero state after re-instantiation (AC-HUD-12.2), WHEN LSS re-emits `player_health_changed(72, 100)`, `weapon_switched("silenced_ppk")`, `ammo_changed("silenced_ppk", 6, 8)`, `gadget_equipped("cigarette_case")`, and `ui_context_changed(GAMEPLAY, GAMEPLAY)` in that order, THEN the health Label reads `"72"`, weapon-name Label reads `tr("silenced_ppk")`, ammo Labels read `"6"` / `"8"`, gadget tile icon reflects the cigarette case, and `hud_root.visible == true`. Widget state matches what a live-play session would show for those values. Evidence: `tests/integration/hud_core/test_save_load_lifecycle.gd`

**AC-HUD-12.4 [Integration] [BLOCKING]**: GIVEN LSS restore-signals (from AC-HUD-12.3) arrive after all scene nodes' `_ready()` calls complete (OQ-HUD-4 verification), WHEN the restore sequence fires, THEN no HUD widget displays a stale default value after restore completes. Specifically: if `weapon_switched` arrives before `ammo_changed`, the transient `"0 / 0"` ammo state is never rendered to screen (restore fires before first rendered frame). Evidence: `tests/integration/hud_core/test_save_load_lifecycle.gd`

**AC-HUD-12.5 [Integration] [BLOCKING]** **REV-2026-04-25 — NEW (OQ-HUD-4 race coverage)**: GIVEN a test harness that emits LSS restore signals (`player_health_changed`, `ammo_changed`, `weapon_switched`, `gadget_equipped`, `ui_context_changed`) **BEFORE** the HUD scene's `_ready()` completes (simulated by routing the signals through a deferred-call wrapper that fires before the new HUD instance has finished its connect-block), WHEN HUD `_ready()` completes, THEN the test asserts EITHER (a) all five widgets show the restored values (implementation correctly buffers / replays pre-`_ready()` emissions — preferred outcome), OR (b) all five widgets show defaults AND the test FAILS with a clear "LSS-vs-HUD restore-ordering race detected" message (current spec contract requires LSS to emit AFTER HUD `_ready()`; if this fails, OQ-HUD-4 is not closed and the bug surfaces immediately rather than as a silent stale-default at runtime). Evidence: `tests/integration/hud_core/test_save_load_lifecycle.gd`

## Open Questions

### OQ-HUD-1 [ADVISORY — Settings forward-dep]

**HUD scale slider for accessibility**: should Settings & Accessibility (system #23) expose a `hud_scale_multiplier` slider (range [0.5, 2.0], default 1.0) applied multiplicatively to F.3's viewport-scale factor? Useful for low-vision accessibility and ultra-wide-monitor edge cases. Not in HUD Core MVP scope. **Owner**: Settings & Accessibility designer when system #23 GDD is authored. **Resolution path**: include in Settings GDD §Detailed Design as part of the accessibility toggle set. **Default if unresolved**: HUD applies F.3 viewport-scale factor only (no player-side multiplier).

### OQ-HUD-2 [ADVISORY — playtest decision]

**`_pending_flash` lifetime when context returns to GAMEPLAY**: per §E Cluster E, `_flash_timer` continues ticking while HUD is invisible (Pause / DocumentOverlay / Menu). On context restore, a queued deferred flash will fire on the now-visible HUD if `_pending_flash` was true. This may feel jarring (a flash 200 ms after un-pausing for a hit that happened pre-pause). Should `_pending_flash` and `_flash_timer` be cleared on `ui_context_changed` to non-GAMEPLAY? **Resolution path**: playtest with the default behaviour (carry across context); if jarring, add a 1-line clear in the `_on_ui_context_changed` handler. **Default if unresolved**: carry the flash across context boundaries (current spec). **Owner**: HUD Core implementer + playtest QA.

### OQ-HUD-3 [BLOCKING for sprint integration — verify before VS]

**Settings & Accessibility boot ordering vs HUD `_ready()`**: CR-11 specifies the crosshair widget reads `_crosshair_enabled_mirror = false` initially and updates via `setting_changed("accessibility", "crosshair_enabled", value)` from Settings (`accessibility` category is the single canonical home per Settings CR-2; B3 from /review-all-gdds 2026-04-27 swept 2026-04-27). If Settings has not booted by the time HUD `_ready()` runs and the player enters GAMEPLAY, the crosshair stays hidden until Settings emits its initial value. **Verification gate**: confirm the load-order cascade — Settings autoload (or its scene/manager) emits initial `setting_changed` for all relevant keys before any UI scene's `_ready()` runs. **Owner**: lead programmer at sprint integration time; coordinate with Settings & Accessibility GDD authoring. **Resolution path**: confirm via integration test (`tests/integration/hud_core/test_settings_boot_order.gd`) once Settings GDD is implemented.

### OQ-HUD-4 [BLOCKING for VS — engine verification gate]

**LSS restore-callback signal-replay ordering**: per CR-14 + §E Cluster F, HUD Core depends on the Level Streaming Service re-emitting `player_health_changed` / `ammo_changed` / `weapon_switched` / `gadget_equipped` / `ui_context_changed` AFTER the HUD scene's `_ready()` completes — otherwise HUD subscribes too late and misses the restore signals. **Verification gate**: confirm that LSS's restore-callback sequence runs after all main-scene nodes' `_ready()` completes. The LS GDD's restore-callback contract should explicitly order this. **Owner**: lead programmer + LS designer. **Resolution path**: cross-check LS GDD §Restore Callback ordering when LS GDD is implemented; if ambiguous, ADR amendment to LS contract. **Default if unresolved**: HUD widgets show defaults until first live signal emission post-restore (cosmetic-only at MVP; correctness gap at VS).

### OQ-HUD-5 [BLOCKING for sprint — performance verification gate] **REV-2026-04-25 — escalated from ADVISORY**

**`C_label` and `C_draw` measurement gate**: F.5's worst-case frame budget previously assumed `C_label = 0.05 ms` and excluded the crosshair `_draw()` cost entirely. Both assumptions were unmeasured estimates from training data predating Godot 4.6's TextServer rework (per `docs/engine-reference/godot/VERSION.md`). **REV-2026-04-25** consolidates the weapon+ammo widget into a single Label (§V.3 / §C.2) which lowers the worst-case Label count from 5 → 4, and adds an explicit `C_draw` term to F.5. The cap-breach surfaced in adversarial review (worst-case 0.309 ms vs 0.3 ms cap) is *theoretically* resolved by the consolidation, but the constants `C_label`, `C_draw`, and `C_poll` remain unmeasured against Iris Xe Gen 12 / Godot 4.6 / Forward+ Mobile renderer. **Verification gate (BLOCKING before sprint planning closes)**: profile the four constants on a minimal HUD micro-benchmark scene running on Iris Xe Gen 12 / Godot 4.6 / 810p Restaurant reference. Feed measured values back into F.5 and re-derive the headroom figure. **Resolution path if measurements breach the cap**: options (a) widen ADR-0008 Slot 7 cap via amendment (negotiate with other slot owners; technical-director approval); (b) further consolidate Labels (e.g., merge the "HP" sub-label into the health numeral via formatted string `"HP 80"` rendered as one Label — requires Art Director sign-off on Art Bible §7B compliance); (c) pre-render the crosshair to a `Texture2D` at `_ready()` and switch to `Sprite2D` rendering (eliminates `C_draw` entirely; minimal art impact). **Default if unresolved**: BLOCK sprint until measured. **Owner**: performance-analyst + technical-director.

### OQ-HUD-6 [ADVISORY — playtest decision]

**Crosshair default ON vs OFF**: per Combat §UI-6, the crosshair is opt-out by default (`crosshair_enabled = true`). This serves players who expect a crosshair on a first boot. However, Pillar 5 (Period Authenticity) might argue for default-OFF — period-authentic FPS games of the era did not have crosshairs. **Resolution path**: defer to first playtest sessions; if first-time players consistently express discomfort or fire wildly without the crosshair, keep default-ON; if they prefer the period-authentic feel, flip to default-OFF. **Owner**: playtest QA + game-designer + Combat designer. **Default if unresolved**: keep `crosshair_enabled = true` (Combat §UI-6 baseline; user can opt out via Settings).

### OQ-HUD-7 [CLOSED REV-2026-04-26 per D4] — TAKEDOWN_CUE removed from MVP entirely

**Resolution**: per user-adjudicated D4, the latch + `takedown_availability_changed` signal subscription + AC-HUD-6.3/6.4 + the Stealth AI inbound `§C.5` row are all **removed from MVP scope**. SAI body-language cues alone signal takedown affordance (CAI/SAI Pillar 5 absolute). The fantasy gravity-well risk identified by game-designer + creative-director is closed because the implementation surface no longer exists in production code — Path C ("TAKEDOWN AVAILABLE" text) cannot be added later via a one-line change because the latch + signal are not present.

**Re-opening criteria** (post-MVP only): if first-playtest data shows takedown-opportunity-discovery rate < 60%, a future GDD revision may re-introduce a takedown affordance — but at that point the design must explicitly choose between Path B (glyph), a SAI body-language tuning pass, or audio-cue augmentation, and the choice must be made *before* the implementation surface is added, not after.

### OQ-HUD-8 [ADVISORY — Polish-deferred] **NEW REV-2026-04-26 (was AC-HUD-11.5)**

**AccessKit live-region behaviour for HUD numerals**: per ADR-0004 §10, AccessKit screen-reader live-region integration is deferred to Polish. The Day-1 default behaviour for the `accessibility_live` property (exact name pending ADR-0004 Gate 1) MUST be confirmed at the moment Gate 1 resolves — the announcement-flooding suppression behaviour is required even if the broader AccessKit feature is Polish-tier. Tracked here rather than as an AC because there is no Pass/Fail criterion this sprint can produce. **Owner**: lead programmer at Gate 1 resolution. **Default if unresolved**: Day-1 default behaviour confirmed when Gate 1 closes; Polish sprint owns full AccessKit integration. **Scope**: the consolidated ammo Label introduces a screen-reader regression vs the prior 3-Label form ("six slash twenty-one" is ambiguous) — this is a Polish-tier concern to address via `accessibility_label` overrides when AccessKit work begins.

### Deliberately omitted (NOT captured as OQs — out of scope by design)

The following items were considered during authoring and **deliberately excluded** from HUD Core MVP. They are not OQs because the answer is settled:

- **MEMO_NOTIFICATION state in prompt-strip** — Deferred to HUD State Signaling (system #19, VS). HSS owns "alarm indicator + pickup notifications" per its systems-index entry. No OQ; HSS authoring will close the loop.
- **Alarm-state visual indicator** (suspicion meter / alert level bar) — Pillar 5 absolute exclusion; audio-only per NOLF1 fidelity. Will not be added regardless of playtest feedback. FP-6 enforces.
- **Damage direction indicator** — Pillar 5 absolute exclusion (PC §"HUD must NOT render"). FP-6 + AC-HUD-pillar-2 enforce.
- **Hit markers / kill-confirmation chrome** — Pillar 5 absolute. AC-HUD-pillar-1 enforces (CI scene-tree scan).
- **Stamina bar** — Eve has no stamina system at MVP (PC §"HUD must NOT render"). If stamina is added post-MVP via a system amendment, HUD scope re-opens via that GDD's revision.
- **Death screen / retry button** — F&R has empty UI (Pillar 5 absolute). HUD's parent visibility toggle handles the input-blocked respawn window.
- **Civilians in HUD** — CAI Pillar 5 zero-UI absolute. FP-6 enforces.
- **In-HUD inventory grid / radial weapon wheel** — §Player Fantasy "This Fantasy Refuses". Inventory provides slot 1–5 + scroll cycling via existing weapon-name + ammo widget; no separate weapon-select chrome.
- **Crosshair animation on weapon fire (recoil bloom / spread)** — Combat owns crosshair *behaviour*; HUD owns *rendering*. If recoil bloom is added at VS, Combat will specify the contract; HUD will receive new constants via Settings (no new signal). Not currently in scope.
- **HUD-driven achievements / progression toasts** — Anti-pillar (no XP / skill trees). HSS may surface narrative-progression cues via the prompt-strip extension API; HUD Core does not subscribe to achievement systems.
