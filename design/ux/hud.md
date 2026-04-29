# HUD Design

> **Status**: In Design
> **Author**: ux-designer + agustin.ruatta@vdx.tv (solo studio)
> **Last Updated**: 2026-04-29
> **Template**: HUD Design
> **Linked Documents**: `design/gdd/hud-core.md` (APPROVED) · `design/gdd/hud-state-signaling.md` (DESIGNED) · `design/gdd/settings-accessibility.md` · `design/ux/interaction-patterns.md` · `design/accessibility-requirements.md` · `design/gdd/combat-damage.md` · `design/gdd/inventory-gadgets.md` · `design/gdd/document-collection.md` · `design/gdd/save-load.md` · `design/gdd/failure-respawn.md`
> **Governing ADRs**: ADR-0002 (Signal Bus) · ADR-0004 (UI Framework) · ADR-0008 (Performance Budget — HUD Slot 7 = 0.3 ms cap)

---

## HUD Philosophy

*The Paris Affair*'s HUD adopts a **minimal-cockpit** philosophy. The HUD is a
deadpan reference dial Eve Sterling **glances at**, never studies — a 1960s
spy-fiction read-out that confirms state through numerals, color states, and
typographic cues, never through animated urgency, modern toasts, or
interrupting feedback. The HUD never breaks register: it is restrained,
composed, unbothered, and refuses to perform the emotional labour of telling
the player how to feel about what just happened.

**Pillar binding**:

- **Pillar 5 (Period Authenticity Over Modernization)** is load-bearing. The
  HUD ships with no objective markers, no minimap, no compass, no kill cam,
  no damage direction indicator, no floating damage numbers, no XP / level
  UI, no faction reputation tracker, and no celebratory pop-ups. Information
  that does not fit the dossier-and-cockpit register is not on the HUD.
- **Pillar 3 (Stealth is Theatre, Not Punishment)**: the HUD refuses punitive
  visual language. Damage is a one-frame numeric flash, not a red vignette.
  Critical health is a categorical color swap (Parchment → Alarm Orange),
  not flashing urgency. Detection is signalled by audio + body language;
  the HUD's HoH / deaf alert-cue is a deadpan typographic margin note, not
  an alarm icon.
- **Pillar 2 (Discovery Rewards Patience)**: the HUD does not navigate. It
  tells the player *what they are holding*, not *where to go*. Quest
  objectives are dossier prose accessed through the Pause Menu; the HUD
  never prints "GO HERE → 42 m".

**Density posture**: **Minimal but present** — only critical information
visible during gameplay. Five always-on widgets (Health BL, Weapon+Ammo BR,
Gadget Tile TR, Crosshair Center, Prompt-Strip CB) plus a transient
state-signaling layer that surfaces six brief auto-dismissed margin-note
states (alert cue, alarm stinger, memo notification, respawn beat,
save-failed advisory, interact prompt). HUD auto-hides on context change
(modal, menu, cutscene, document overlay) — Eve's cockpit dial is
gameplay-only.

**The "Margin Note" fantasy** (HSS): every transient state is a typographic
annotation stamped by an unseen BQA file clerk — brief, deadpan,
auto-dismissed. Never a notification (does not demand acknowledgment), never
a banner (no decoration), never a reward (no "+1" gamification).

**Conflict-surfacing rule**: any future system that wants to add a permanent
HUD widget must justify it against the Must Show categorization (Section B).
Any modern UX convenience (waypoint, marker, ping) requires Pillar 5
carve-out via Settings opt-in (default `false`) — see
`interaction-patterns.md` `stage-manager-carve-out`.

---

## Information Architecture

### Full Information Inventory

Master list of every piece of information the HUD layer can communicate,
aggregated across HUD Core, HUD State Signaling, and cross-system UI
Requirements (Combat & Damage, Inventory & Gadgets, Document Collection,
Save / Load, Failure & Respawn, Mission & Level Scripting, Stealth AI,
Settings & Accessibility).

| # | Information Item | Source System (GDD) | Visual Form | Default Visibility |
|---|------------------|---------------------|-------------|--------------------|
| 1 | Player health (current / max) | Player Character → HUD Core | Numeric Label + color state | Always (gameplay) |
| 2 | Damage flash | Combat & Damage → HUD Core | 1-frame white flash on health numeral | Transient (on `player_damaged`) |
| 3 | Critical-health colour swap | HUD Core | Parchment → Alarm Orange edge-trigger at <25% HP | Persistent while critical |
| 4 | Critical-health pulse (VS-tier) | HSS CR-18 | Tween pulse on health numeral, 0.6 s period | Persistent while critical, opt-out |
| 5 | Active weapon name | Inventory & Gadgets → HUD Core | Localized text Label (13 px Futura Condensed Bold, uppercase) | Always (gameplay) |
| 6 | Ammo (current / reserve) | Inventory & Gadgets → HUD Core | Combined text `"%d / %d"` (22 px), or `"—"` for blade / empty | Always (gameplay) |
| 7 | Active gadget icon | Inventory & Gadgets → HUD Core | TextureRect 56×56 px in BQA-blue panel | Always (gameplay) |
| 8 | Gadget "noisy" indicator | Inventory & Gadgets | 12×12 px sound-wave glyph overlay on gadget icon | Contextual (per-gadget property) |
| 9 | Captured-equipment tint | Inventory & Gadgets | PHANTOM Red `#C8102E` tint on gadget icon | Contextual (captured-only) |
| 10 | Gadget rejection feedback | Inventory & Gadgets CR-4b | Tile desat to grey for 0.2 s | Transient (on `gadget_activation_rejected`) |
| 11 | Crosshair (dot + tri-band halo) | Combat & Damage → HUD Core | Custom-drawn dot + halo at screen center | Always (toggle-able opt-out) |
| 12 | Interact prompt (label + key glyph) | HUD Core | Margin-note Label + bordered key-rect | Contextual (interactable in range, hand free) |
| 13 | Alert cue (HoH / deaf accommodation) | HSS ALERT_CUE | Margin-note Label, 2.0 s auto-dismiss | Transient (on guard alert escalation) |
| 14 | Alarm stinger (section-wide) | HSS ALARM_STINGER (VS) | Margin-note Label, 3.0 s auto-dismiss | Transient (on first guard reaching COMBAT) |
| 15 | Memo notification (document collected) | Document Collection → HSS (VS) | Margin-note Label `"Memo collected — [title]"`, 3.0 s | Transient (on `document_collected`) |
| 16 | Respawn beat | Failure & Respawn → HSS | Margin-note Label `"Operation resumed"`, 1.5 s | Transient (on `respawn_triggered`) |
| 17 | Save failed advisory | Save / Load → HSS | Margin-note Label, 4.0 s | Transient (on `save_failed`) |

**Items deliberately NOT on the HUD** (Pillar 5 forbidden — see HUD Core
`FP-1..14`, HSS `FP-HSS-1..15`):

| Excluded Item | Why Not on HUD | Where the Player Gets It Instead |
|---------------|----------------|----------------------------------|
| Active objective text | Pillar 5 (no waypoints, no markers) | Pause Menu → Mission tab; Briefing / Closing Mission Cards (Cutscenes) |
| Compass / bearing | Pillar 5 absolute | World geometry (Eiffel Tower verticality is the wayfinding signal) |
| Minimap / level map | Pillar 5 absolute | Pause Menu's Mission tab carries dossier-register prose, not pings |
| Stealth alert state (visible meter / icon) | Pillar 5 — alert state is audio-and-body-language by design | HSS ALERT_CUE text-only margin note (HoH carve-out only); audio stinger is the authoritative channel |
| Damage direction indicator | Pillar 5 absolute | Audio bearing + screen-edge nothing; Settings-gated "Enhanced Hit Feedback" opt-in (default `false`) is the only carve-out |
| Floating damage numbers | Pillar 5 absolute | Health numeral + 1-frame flash carry the information |
| "Kill confirmed" / "Guard eliminated" toast | Pillar 5 absolute | Diegetic body — the guard slumps, the world reacts |
| Reload progress bar | Pillar 5 absolute | Diegetic reload animation |
| Civilian panic / faction-rep meter | Pillar 5 + design — single-faction game | Diegetic — civilians flee; PHANTOM responds via audio cues |
| Weapon-wheel / radial selector | Pillar 5 — too modern | `1`–`5` number keys / DPad up-down (instant switch) |
| XP / level / progression | Anti-pillar (no XP system) | N / A — game has no XP |
| Achievement unlock pop-up | Pillar 5 — Steam overlay handles this | Steam overlay is platform-side, not HUD |
| Subtitles | Owned by Dialogue & Subtitles on **separate CanvasLayer 2** | D & S widget, NOT HUD |
| Document Overlay reading UI | Owned by Document Overlay UI on **separate CanvasLayer 5** | DOV widget, NOT HUD |

### Categorization

| Category | Item Numbers (from inventory above) | Count |
|----------|-------------------------------------|-------|
| **Must Show** (always visible during gameplay) | 1, 5, 6, 7, 11 | 5 widgets |
| **Contextual** (visible only when relevant state holds) | 2, 3, 4, 8, 9, 10, 12, 13, 14, 15, 16, 17 | 12 transient or state-conditional surfaces |
| **On Demand** (player must request) | (none) | 0 |
| **Hidden** (in-world / audio / out-of-HUD) | All forbidden items above; subtitles; document overlay; objective text | — |

**No "On Demand" HUD entries by design.** Anything the player needs to
actively pull up (objective, inventory, settings) lives in the Pause Menu
(`menu-system.md`), not on the HUD. The HUD does not host toggles or
expandable widgets.

**Conflict check**: 5 Must Show widgets is a low count by stealth-FPS
standards (comparable to *Thief* and *Dark Souls*). No conflict with the
Section A "minimal but present" posture. If a future system wants to add a
6th Must Show widget, the producer + creative-director must approve a
Pillar 5 review.

**Cognitive-load note**: The HUD is the lowest cognitive-load surface in
the game. The high-cognitive-load systems are off-HUD (multi-actor stealth
observation per Stealth AI #10, multi-civilian tracking per Civilian AI
#15, document reading per Document Overlay UI #20). The HUD's job is to
never add to the player's surveillance budget.

---

## Layout Zones

The HUD uses a 5-zone anchor grid: four corner-anchored gameplay widgets
plus a center-bottom transient prompt-strip. Layout is driven by Section
B's Must Show categorization (5 always-on widgets) and constrained by
ADR-0008's Slot 7 perf cap (0.3 ms / frame for HUD Core + HSS + DOV +
Menu).

### Zone Anchor Grid

| Zone | Anchor (Godot preset) | Contents | Background | Notes |
|------|------------------------|----------|------------|-------|
| **BL — Health** | `ANCHOR_PRESET_BOTTOM_LEFT` | "HP" label (13 px) + numeric Label (22 px) | BQA Blue `#1B3A6B` 85% opacity StyleBoxFlat | 6 px L / R, 4 px T / B margins; HBoxContainer |
| **BR — Weapon + Ammo** | `ANCHOR_PRESET_BOTTOM_RIGHT` | Weapon name Label (13 px, uppercase) + Ammo Label (22 px, right-aligned) | BQA Blue `#1B3A6B` 85% opacity StyleBoxFlat | Mirrored geometry from BL; VBoxContainer; consolidated single ammo Label per HUD Core REV-2026-04-25 |
| **TR — Gadget Tile** | `ANCHOR_PRESET_TOP_RIGHT` | TextureRect 56 × 56 px icon + optional 12 × 12 px sound-wave glyph | Layered StyleBoxFlat (`#2A4F8A` base + `#1B3A6B` 85% overlay) | No outer margin; corner-anchored; PanelContainer-in-PanelContainer |
| **CB — Prompt-Strip** | `PRESET_BOTTOM_CENTER` | HUD Core interact prompt **OR** HSS state text (resolver-driven, single Label) | BQA Blue `#1B3A6B` 85% opacity StyleBoxFlat | Y-offset 18% of viewport height from bottom (tunable [10%, 25%]); max-width 62% viewport, capped 896 px; clears HUD corner widgets by 96 px |
| **Center — Crosshair** | `PRESET_CENTER` | Custom-drawn dot + tri-band halo | None (no panel) | `Control` subclass with `_draw()` override; no children |

### CanvasLayer Stacking (per ADR-0004)

| CanvasLayer | Owner | Layer Index | Purpose |
|-------------|-------|-------------|---------|
| 1 | HUD Core (this spec) | 1 | Health, Weapon + Ammo, Gadget Tile, Prompt-Strip, Crosshair |
| 2 | Dialogue & Subtitles | 2 | Caption rendering — **NOT this spec** |
| 5 | Document Overlay UI | 5 | Reading view — **NOT this spec** |
| 10 | Cutscenes & Mission Cards | 10 | Mission Cards / cinematics — **NOT this spec** (lazy-instanced) |
| 11 | Cutscenes op-art sub-layer | 11 | CT-05 only — **NOT this spec** |

The HUD owns CanvasLayer 1 only. When higher CanvasLayers are pushed
(cutscene, document overlay), the HUD is hidden via `visible = false`
driven by `ui_context_changed` (HUD Core CR-10) — not by stacking order,
by explicit context-state.

### Viewport-Scale Rule

All HUD widgets scale uniformly via `Control.scale =
viewport_height_px / 1080.0`, clamped `[0.667, 2.0]` (covers 720p → 4K).
Individual widget scaling is forbidden — cohesive scaling preserves
proportions. Per-element fonts scale alongside via `FontRegistry`
resolver.

### Safe Zone (Steam Deck soft target)

Steam Deck verifies are post-launch, but the layout is designed to fit a
90% safe zone:

| Edge | Safe-zone offset (1080p, 100% scale) | Rationale |
|------|--------------------------------------|-----------|
| Bottom (BL, BR) | 6 px outer margin | Closest viable to edge — typography readable but not cramped |
| Top-right (TR) | 0 px corner | Gadget tile corner-anchored; tile padding handles inset |
| Bottom-center (CB) | 18% viewport height | Y-offset locked by HUD Core tuning knob `prompt_strip_y_offset_pct` |
| Center (crosshair) | 0 px | Center-screen always |

No 4:3 / 16:10 / ultrawide variants in MVP scope — 16:9 only. Ultrawide
post-launch evaluation pending.

### ASCII Wireframe (1080p, gameplay state, all Must Show widgets visible)

```
+------------------------------------------------------------------------------+
|                                                                              |
|                                                                  +--------+  |
|                                                                  |        |  |
|                                                                  | [icon] |  |  <- TR Gadget Tile (56 x 56 px)
|                                                                  |        |  |
|                                                                  +--------+  |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                  .                                           |
|                                 (o)                                          |  <- Center Crosshair (dot + tri-band halo)
|                                  '                                           |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|                       +--------------------------------+                     |
|                       | Open door            [ E ]     |                     |  <- CB Prompt-Strip (interact OR HSS state)
|                       +--------------------------------+                     |
|                                                                              |
|                                                                              |
|                                                                              |
|                                                                              |
|  +-----------+                                       +------------------+    |
|  | HP   100  |                                       | SILENCED PISTOL  |    |
|  +-----------+                                       |          12 / 36 |    |  <- BL Health, BR Weapon+Ammo
|                                                      +------------------+    |
+------------------------------------------------------------------------------+
```

**State variants** (specified in Section D — HUD Elements):

- **Critical health (<25%)**: Health numeral colour swaps Parchment → Alarm Orange; optional Tween pulse (VS, opt-out).
- **HSS state active**: Prompt-Strip text replaced by margin-note (alert cue / alarm stinger / memo / respawn / save-failed).
- **No interactable + no HSS state**: Prompt-Strip hidden (`visible = false`).
- **Empty gadget slot**: Gadget tile alpha 0.4.
- **Crosshair disabled (Settings)**: Crosshair widget `visible = false`.
- **Context != GAMEPLAY**: All HUD widgets hidden via `visible = false`.

---

## HUD Elements

### Element 1 — Health Field (BL)

| Property | Value |
|----------|-------|
| **Category** | Must Show (1 of 5) |
| **Anchor** | `ANCHOR_PRESET_BOTTOM_LEFT` |
| **Container** | `MarginContainer` → `HBoxContainer` → 2 × `Label` |
| **Content** | `"HP"` static label + numeric current-health string |
| **Visual form** | "HP" Label 13 px Futura Condensed Bold (Parchment); numeric Label 22 px Futura Condensed Bold (Parchment OR Alarm Orange) |
| **Background** | StyleBoxFlat BQA Blue `#1B3A6B` 85% opacity, 6 px L / R + 4 px T / B margins |
| **Update rule** | Subscribes to `Events.player_health_changed(current, max)`; change-guarded (`if current != _current_health`) |
| **State variants** | **Default**: Parchment numeral. **Critical (<25% HP)**: Alarm Orange numeral, edge-triggered. **Damage flash (1 frame)**: White numeral. **Critical pulse (VS, opt-out)**: 0.6 s Tween between Parchment ↔ Alarm Orange. **Hidden** when `InputContext != GAMEPLAY`. |
| **AccessKit** | `accessibility_role = TEXT`; `accessibility_name = "Health"`; `accessibility_description = "[N] of [M]"`; `accessibility_live = "polite"` (announces only on edge-triggered critical entry / exit, NOT on every damage tick — rate-limited per HUD Core CR-9). |
| **Edge cases** | Health = 0 → renders "0" (death triggers respawn elsewhere; HUD does not handle death state). Health > max (overheal) → renders current value verbatim; no special "overhealed" colour. |

### Element 2 — Weapon + Ammo Field (BR)

| Property | Value |
|----------|-------|
| **Category** | Must Show (2 of 5) |
| **Anchor** | `ANCHOR_PRESET_BOTTOM_RIGHT` |
| **Container** | `MarginContainer` → `VBoxContainer` → 2 × `Label` |
| **Content** | Localized weapon name (uppercase) + ammo string `"%d / %d"` or `"—"` |
| **Visual form** | Weapon Label 13 px Futura Condensed Bold uppercase (Parchment); Ammo Label 22 px Futura Condensed Bold right-aligned (Parchment) |
| **Background** | StyleBoxFlat BQA Blue `#1B3A6B` 85% opacity, mirrored geometry from BL |
| **Update rule** | Subscribes to `Events.weapon_switched(weapon_id)` (caches `tr(weapon_id)`) and `Events.ammo_changed(current, reserve, weapon_id)` (composes single-Label string). Consolidated to a single ammo Label per HUD Core REV-2026-04-25 to tighten ADR-0008 budget. |
| **State variants** | **Default**: `"12 / 36"`. **No reserve**: `"12 / —"`. **Blade / empty**: `"—"`. **Hidden** when `InputContext != GAMEPLAY`. |
| **AccessKit** | `accessibility_role = TEXT`; `accessibility_name = "Weapon"`; `accessibility_description = "[weapon] [current] of [reserve]"`; `accessibility_live = "polite"` (announces on weapon switch and on first depletion threshold; NOT on every shot). |
| **Open coord** | OQ-HUD-7 — Art Director must approve 22 px slash rendering OR specify thinner typographic substitute (Art Bible §7A spec calls for slash at ~70% numeral width). **BLOCKING before sprint.** |

### Element 3 — Gadget Tile (TR)

| Property | Value |
|----------|-------|
| **Category** | Must Show (3 of 5) |
| **Anchor** | `ANCHOR_PRESET_TOP_RIGHT` |
| **Container** | `PanelContainer` (base `#2A4F8A`) → `PanelContainer` (overlay `#1B3A6B` 85%) → `Control` → `TextureRect` (icon) + optional `TextureRect` (sound-wave) |
| **Content** | 56 × 56 px gadget icon; optional 12 × 12 px sound-wave glyph (TR-anchored within tile) for noisy gadgets |
| **Visual form** | TextureRect with `expand_mode = EXPAND_FIT_WIDTH_PROPORTIONAL` |
| **Update rule** | Subscribes to `Events.gadget_equipped(gadget_id)` (loads icon from Gadget Resource); reads `gadget.is_noisy` → toggles sound-wave overlay |
| **State variants** | **Empty slot**: `modulate.a = 0.4`. **Captured equipment**: icon `modulate = PHANTOM_RED #C8102E` (TextureRect only, NOT background). **Rejection feedback**: tile desaturates to `(0.4, 0.4, 0.4, 1.0)` for 0.2 s on `gadget_activation_rejected`. **Hidden** when `InputContext != GAMEPLAY`. |
| **AccessKit** | `accessibility_role = IMAGE`; `accessibility_name = "Gadget"`; `accessibility_description = "[gadget name]"` (resolved from `tr(gadget_id)`); `accessibility_live = "polite"` (on equip change). Empty-slot description = `"No gadget equipped"`. |
| **Edge cases** | If `gadget.icon == null` → fallback to placeholder texture (FontRegistry-equivalent for icons TBD; out of scope). If gadget swapped during rejection desat → desat cancelled, new gadget renders at full saturation. |

### Element 4 — Crosshair (Center)

| Property | Value |
|----------|-------|
| **Category** | Must Show (4 of 5) — toggle-able opt-out |
| **Anchor** | `PRESET_CENTER` (no margin) |
| **Container** | `Control` subclass with `_draw()` override; no children |
| **Visual form** | **Dot**: Ink Black `#1A1A1A`, radius `0.19% × viewport_height` clamped `[3 px, 12 px]`. **Halo**: 1 px outer (Parchment `#E8DFC8`) + 1 px inner (Ink Black) — tri-band guarantees contrast on light + dark backgrounds. |
| **Implementation** | `_draw()` calls `draw_arc` (64 segments) + `draw_circle`. No texture, no theme override. |
| **Update rule** | No update — purely render-driven. Visibility toggled via `Events.setting_changed("accessibility", "crosshair_enabled", _)`. |
| **State variants** | **Enabled (default)**: visible during gameplay. **Disabled**: `visible = false`. **No expansion / no hover state / no hit-marker flash** (FP-6). **Hidden** when `InputContext != GAMEPLAY` (e.g., document overlay). |
| **AccessKit** | None — purely visual aim aid; no semantic value to announce. |
| **Settings binding** | `Settings.get_setting("accessibility", "crosshair_enabled", true)`. Default `true` (opt-out toggle). |

### Element 5 — Prompt-Strip (CB) — HUD Core 2-state + HSS 6-state extension

| Property | Value |
|----------|-------|
| **Category** | Contextual (1 widget, 7 states total: HIDDEN + 6 active states) |
| **Anchor** | `PRESET_BOTTOM_CENTER`; Y-offset 18% viewport height from bottom (tunable `prompt_strip_y_offset_pct ∈ [10%, 25%]`) |
| **Container** | `CenterContainer` → `MarginContainer` → `HBoxContainer` → `Label` (text) + optional `PanelContainer` → `Label` (key glyph) |
| **Content** | Single Label rendering whichever state wins the resolver per frame |
| **Visual form** | Text Label 14 px Futura Condensed Bold (Parchment); optional key-glyph Label 14 px in 1-px Parchment-bordered transparent-fill PanelContainer |
| **Background** | StyleBoxFlat BQA Blue `#1B3A6B` 85%; 8 px H + 3 px V margins; max-width 62% viewport, capped 896 px |
| **Update rule** | HUD Core's `_process()` resolver picks highest-priority state via `_resolve_hss_state()` callback registered by HSS at `_ready()`. State priority: **ALARM_STINGER (1) > INTERACT_PROMPT (2) > ALERT_CUE (3) > SAVE_FAILED (4) > RESPAWN_BEAT (5) > MEMO_NOTIFICATION (6) > HIDDEN (7)**. Winner's text written to `_label.text` + AccessKit announce only if text changed. |
| **State table** | (see below) |
| **AccessKit** | `accessibility_role = STATUS`; `accessibility_name` per state; `accessibility_live = "polite"` for INTERACT_PROMPT / ALERT_CUE / MEMO / RESPAWN / SAVE_FAILED; `accessibility_live = "assertive"` for ALARM_STINGER (sole carve-out — safety-of-information). |
| **Performance** | <0.3 ms per frame (HUD Core Slot 7 cap); HSS claims ≤0.10 ms steady, ≤0.15 ms peak (deferred-AccessKit mitigation locked). |
| **Visibility** | `visible = (state != HIDDEN)`. Hidden when `InputContext != GAMEPLAY`. |

#### Prompt-Strip State Table

| Priority | State | Trigger | Text key (`tr()`) | Duration | AccessKit Live |
|----------|-------|---------|-------------------|----------|----------------|
| 1 | **ALARM_STINGER** (VS) | `alert_state_changed(_, _, COMBAT, MAJOR)` — first guard in section reaches COMBAT | `"HUD_ALARM_RAISED"` ("ALARM RAISED") | 3.0 s auto-dismiss; preempts INTERACT_PROMPT | **assertive** (sole carve-out) |
| 2 | **INTERACT_PROMPT** | `PC.get_current_interact_target()` non-null AND `PC.is_hand_busy() == false` | `tr(target.interact_label_key)` + key-glyph from Input GDD | While valid; cleared on target loss / hand busy | polite |
| 3 | **ALERT_CUE** (MVP-Day-1) | `alert_state_changed(actor, _, new_state, severity)` where `new_state != UNAWARE`; per-actor 1.0 s rate-gate (upward-severity exempt) | `"HUD_GUARD_ALERTED"` | 2.0 s auto-dismiss | polite |
| 4 | **SAVE_FAILED** | `save_failed(reason)` | `"HUD_SAVE_IO_ERROR"` / `"HUD_SAVE_DISK_FULL"` (varies by reason) | 4.0 s auto-dismiss | polite |
| 5 | **RESPAWN_BEAT** | `respawn_triggered` | `"HUD_RESPAWN"` ("Operation resumed") | 1.5 s auto-dismiss | polite |
| 6 | **MEMO_NOTIFICATION** | `document_collected(doc)` | `"HUD_DOCUMENT_COLLECTED"` + `" — "` + `tr(doc.title_key)` | 3.0 s auto-dismiss; queue depth 1 (latest wins, dropped if >1 s late) | polite |
| 7 | **HIDDEN** | No active state | (none) | Until next state | none |

### Element 6 — Critical-Health Pulse (HSS CR-18, VS-tier, OPT-OUT)

Not a separate widget — a visual augmentation of Element 1 (Health
field). Listed here for completeness because it has its own opt-out
toggle and lifecycle.

| Property | Value |
|----------|-------|
| **Category** | Contextual (Persistent while critical, opt-out) |
| **Trigger** | `health / max ≤ critical_threshold (0.25)` AND `Settings.get_setting("accessibility", "hud_critical_pulse_enabled", true)` |
| **Visual form** | `Tween` driving `add_theme_color_override("font_color", color)` between Parchment ↔ Alarm Orange |
| **Period** | `clock_tick_period_s = 0.6` (matches Audio's clock-tick) — pulse period floor-clamped at 0.4 s to guard against Audio mistuning below WCAG 2.3.1 (2.5 Hz threshold) |
| **Stop conditions** | health > threshold; player death; `InputContext != GAMEPLAY`; toggle disabled mid-pulse; HSS freed |
| **Settings binding** | `Settings.hud_critical_pulse_enabled: bool` (default `true`, opt-out per WCAG 2.2.2 Pause / Stop / Hide) — **BLOCKING VS dep per OQ-HSS-10**. |
| **Reduced-motion** | When `Settings.reduced_motion = true` AND pulse would otherwise run, pulse is **suppressed** (categorical Parchment ↔ Alarm Orange remains via Element 1's edge-trigger; numeric value continues to update; player gets the information without animation). |

---

## Dynamic Behaviors

Describes everything that changes the HUD across time — animations,
lifecycles, and context-driven hide / show. All animations have explicit
reduced-motion behaviour per `interaction-patterns.md`
`reduced-motion-conditional-branch`.

### Behavior 1 — Damage Flash (1-frame white)

| Property | Value |
|----------|-------|
| **Trigger** | `Events.player_damaged` signal |
| **Element** | Element 1 (Health Field) — numeric Label only |
| **Mechanic** | `add_theme_color_override("font_color", Color.WHITE)` → `await get_tree().process_frame` → revert to `_current_health_color` (captured before await to handle critical-threshold race) |
| **Rate gate** | 333 ms minimum inter-flash interval (WCAG 2.3.1 ceiling, 3 Hz max) per `hud_damage_flash_cooldown_ms = 333`. Hits during cooldown set `_pending_flash = true`; on timer timeout, one deferred flash fires (coalescing) |
| **Duration** | 1 frame |
| **Reduced-motion** | No special variant — 1-frame flash is already vestibular-safe |
| **Photosensitivity opt-out** | `Settings.hud_damage_flash_enabled: bool` (default `true`). When `false`, flash is suppressed; numeric value continues to update; rate-gate still respected |
| **Audio pairing** | Combat & Damage emits damage audio in same frame (paired channel — neither carries information alone) |

### Behavior 2 — Critical-State Edge Trigger (categorical colour swap)

| Property | Value |
|----------|-------|
| **Trigger** | `Events.player_health_changed` — edge-detected on `health_ratio < 0.25` transition (entering OR exiting critical) |
| **Element** | Element 1 (Health Field) — numeric Label only |
| **Mechanic** | Single-frame edge-triggered swap: `add_theme_color_override("font_color", alarm_orange)` OR revert to `parchment` |
| **Duration** | Persistent until edge transition reverses |
| **Animation** | None — categorical swap, no fade, no bounce |
| **Reduced-motion** | N / A — already a hard-cut |

The colour swap reads as a "cue for the second act" — categorical and
factual, not animated urgency. Pillar 3 (Stealth as Theatre, Not
Punishment).

### Behavior 3 — Critical-Health Pulse (Tween, VS-tier, opt-out)

| Property | Value |
|----------|-------|
| **Trigger** | `health / max ≤ critical_threshold (0.25)` AND `Settings.hud_critical_pulse_enabled == true` AND `not Settings.reduced_motion` |
| **Element** | Element 1 (Health Field) — numeric Label only |
| **Mechanic** | `Tween.create().set_loops(0)` (infinite); `tween_method` driving `add_theme_color_override("font_color", color)` between Parchment ↔ Alarm Orange |
| **Period** | 0.6 s (matches Audio's clock-tick), floor-clamped at 0.4 s |
| **Stop conditions** | health > threshold; player death; `ui_context_changed != GAMEPLAY`; toggle disabled mid-pulse; HSS freed |
| **Reduced-motion** | Pulse is **suppressed**. Categorical colour from Behavior 2 remains. |
| **Audio pairing** | Pulse period = Audio clock-tick period (`clock_tick_period_s` shared knob) — pulse is the visual equivalent of the audio tick |

### Behavior 4 — Prompt-Strip Lifecycle (state-driven)

| Property | Value |
|----------|-------|
| **Element** | Element 5 (Prompt-Strip) |
| **Per-state Timer** | Each transient state owns a `Timer` node, `one_shot = true`, `wait_time = <state duration>` |
| **State entry** | `_label.text = tr(key)`; `_label.accessibility_description = tr(key)`; AccessKit announce (deferred via `call_deferred`); `timer.start()` |
| **Timer timeout** | Clear state; HUD Core resolver re-evaluates; falls to next-priority state OR HIDDEN |
| **Context-leave** | On `ui_context_changed != GAMEPLAY` (HUD Core CR-11), all active Tweens killed, all timers stopped, state cleared. **No resume on context restore** — transient states are not paused, they are dropped. |
| **Animation** | No enter / exit animation in MVP (hard-cut text swap). VS-tier: optional 100 ms fade-in if perf budget allows; reduced-motion replaces fade with hard-cut. |

### Behavior 5 — Gadget Tile Rejection Feedback

| Property | Value |
|----------|-------|
| **Trigger** | `Events.gadget_activation_rejected(gadget_id)` (e.g., insufficient resource, gadget on cooldown) |
| **Element** | Element 3 (Gadget Tile) |
| **Mechanic** | `_gadget_reject_timer` (`Timer`, `one_shot = true`, `wait_time = 0.2`); set tile `modulate = (0.4, 0.4, 0.4, 1.0)`; on timeout revert to default |
| **Duration** | 0.2 s |
| **Reduced-motion** | N / A — already a hard-cut state change |
| **Audio pairing** | No HUD audio (preserves stealth silence). Gamepad haptic 50 ms low intensity. |

### Behavior 6 — Context-Leave Hide / Restore

| Property | Value |
|----------|-------|
| **Trigger** | `Events.ui_context_changed(old, new)` |
| **Behavior** | When `new != GAMEPLAY` → all HUD widgets `visible = false`; kill all Tweens; stop all timers; clear all transient states. When `new == GAMEPLAY` → all Must Show widgets `visible = true`; transient states do NOT auto-restore (drop semantics). |
| **Cache-on-restore** | On context restore, HUD requests current state from Player Character + Inventory via the API contract: `player_health_changed`, `weapon_switched`, `ammo_changed`, `gadget_equipped` must fire from those systems within 1 frame of restore (ADR-0007 load-order). If signals fire late, HUD renders stale snapshot for 1 frame — visible only as `"0 / 0"` ammo flicker. **Mitigation**: Player Character and Inventory MUST emit on context-restore handshake. |
| **CanvasLayer interaction** | HUD does NOT change CanvasLayer. Stacking is handled elsewhere (cutscene CanvasLayer 10 stacks above HUD CanvasLayer 1 visually); the hide is for AccessKit clarity (no double-announce) and perf (no resolver work during cutscenes). |

### Behavior 7 — Settings Live Updates

| Property | Value |
|----------|-------|
| **Trigger** | `Events.setting_changed(category, key, value)` |
| **Affected widgets** | Element 4 (Crosshair) — `accessibility.crosshair_enabled`. Behavior 1 (Damage Flash) — `accessibility.hud_damage_flash_enabled`. Behavior 3 (Critical Pulse) — `accessibility.hud_critical_pulse_enabled`. Element 5 (Prompt-Strip) — `locale` (cache invalidation for cached `tr()` strings). |
| **Behavior** | Listener on `Events.setting_changed` filtered by `category == "accessibility"` AND `key == "<knob>"`; toggle visibility / behaviour live; no restart required. |
| **Boot ordering** | Settings must be ready before HUD requests initial values. If HUD `_ready()` runs before Settings, HUD defaults to **conservative-disabled state** (crosshair off, pulse off, flash off) — Settings emits `setting_changed` for each knob during its own `_ready()`, HUD picks them up. Verified by CI gate per OQ-HUD-3. |

### Behavior 8 — Resolver Tick (HUD Core ↔ HSS)

| Property | Value |
|----------|-------|
| **Trigger** | Every frame (`_process(delta)`) — but only resolves when state-set is non-empty |
| **Mechanic** | HUD Core calls registered HSS callback `_resolve_hss_state() -> ResolverResult` (at most once per frame); picks highest-priority state per the priority table (see Element 5 state table). On winner change → text + AccessKit announce. On winner unchanged → no work. |
| **Performance** | Steady ~10 µs (idle), peak 52 µs (state transition); HUD Core total worst-case ≤0.289 ms (vs 0.3 ms cap, 11 µs headroom) — **OQ-HUD-5 measurement gate BLOCKING before sprint.** |
| **No-op fast path** | If state-set unchanged AND text-key unchanged AND locale unchanged → no resolver call (cached snapshot). |

---

## Platform & Input Variants

**Target platforms**: PC (Linux + Windows, Steam). 16:9 only at MVP.
Steam Deck soft target (post-launch verification). No 4:3, 16:10, or
ultrawide variants in MVP scope.

**Input methods**: KB+M primary (rebinding MVP), Gamepad partial
(rebinding post-MVP per `technical-preferences.md`). No touch.

### KB+M Default Bindings (HUD-relevant subset)

| Action | Key | HUD impact |
|--------|-----|------------|
| `interact` | `E` | Drives INTERACT_PROMPT key-glyph (Element 5) |
| `takedown` | `F` | Separately bindable (Settings CR-22 + Input GDD §C.2.4) |
| `weapon_select_1`–`5` | `1`–`5` | Triggers `weapon_switched` → updates Element 2 |
| `gadget_prev` / `gadget_next` | `[` / `]` | Triggers `gadget_equipped` → updates Element 3 |
| `ads` | `RMB` (hold) | No HUD effect (camera FOV + scope overlay are out of HUD spec) |
| `fire` | `LMB` | Triggers `ammo_changed` → updates Element 2 |
| `crouch` | `Ctrl` (hold or toggle per Settings) | No HUD effect |
| `sprint` | `Shift` (hold or toggle per Settings) | No HUD effect |
| `quicksave` | `F5` | May trigger SAVE_FAILED state (Element 5) on failure; no HUD on success (silent acknowledgement at MVP) |
| `quickload` | `F9` | May trigger MEMO of failure on no-save-found |
| `pause` | `Esc` | Triggers `ui_context_changed → MENU`; HUD hides |

### Gamepad Default Bindings (Partial — KB+M is primary)

| Action | Button (Xbox / generic) | HUD impact |
|--------|-------------------------|------------|
| `interact` | `A` / Cross | Drives INTERACT_PROMPT key-glyph (Element 5); **at MVP, glyph displays KB binding `[E]` until Input GDD CR-21 closes** — known gamepad-player exclusion |
| `takedown` | `Y` / Triangle | Same as above |
| `weapon_next` / `weapon_prev` | DPad up / down | Triggers `weapon_switched` |
| `gadget_prev` / `gadget_next` | DPad left / right OR `LT` / `RT` (TBD by Input GDD) | Triggers `gadget_equipped` |
| `ads` | `LT` (hold) | No HUD effect |
| `fire` | `RT` | Triggers `ammo_changed` |
| `crouch` | `B` / Circle (hold or toggle) | No HUD effect |
| `sprint` | `A` / Cross (hold or toggle) | No HUD effect |
| `pause` | `Start` / `Menu` | Triggers `ui_context_changed → MENU` |

### Runtime Key-Glyph Rebinding (Open dependency)

The Prompt-Strip's INTERACT_PROMPT state displays the bound key as a
glyph (e.g., `[E]`, `[F]`, `[A]`). At MVP, glyphs are **static localized
strings** — `[E]` is rendered even when a gamepad is connected. This is
a known gamepad-player exclusion until the Input GDD publishes either:

- A `binding_changed(action_name, glyph_string)` signal, OR
- A query API: `Input.get_glyph_for_action(action_name) -> String`

When that contract closes, HUD Core CR-21 (rebinding contract for
runtime key glyphs) lifts the restriction and prompts update on
input-method switch.

**Input-method switching** (KB+M ↔ gamepad mid-session): Steam Input
handles system-level remapping; in-game UI must update prompts
dynamically once CR-21 closes. At MVP, switching does NOT update glyphs
— recorded as `OQ-HUD-known-exclusion-1`.

### Steam Deck (Soft Target, Post-Launch)

The HUD layout is designed to verify on Steam Deck (1280 × 800, 16:10
aspect ratio with letterboxing, gamepad-only):

- **Resolution**: 1280 × 800 → viewport-scale = 0.74 (within `[0.667, 2.0]` clamp). Element 1, 2, 3, 5 sizes scale uniformly.
- **Aspect**: 16:10 letterboxed to 16:9 (top + bottom bars). HUD anchors stay within 16:9 active area.
- **Input**: Gamepad-only — runs into the runtime key-glyph rebinding exclusion above (CR-21 must close). Steam Input templates are the v1.0 mitigation.
- **Steam Deck Verified**: post-launch evaluation, not a v1.0 commitment.

### No HUD Variants (Documented Non-Variants)

| Variant | Why Not |
|---------|---------|
| Mobile / touch | No touch support per `technical-preferences.md`; HUD assumes mouse / gamepad cursor |
| 4:3 / 16:10 / ultrawide | Not in MVP scope; HUD anchors at 16:9 corners would float oddly. Post-launch evaluation. |
| Console (Xbox / PS5 / Switch) | No platform commitment per `game-concept.md` |
| VR | N / A — not a VR title |
| Reduced-density "minimalist" mode | Section A's philosophy is already minimalist; further reduction would compromise Must Show widgets. Not committed. |

---

## Accessibility

**Tier**: **Standard** (per `design/accessibility-requirements.md`).
Project-elevated extras committed: photosensitivity boot warning,
AccessKit per-widget table, HoH / deaf alert cue, critical-pulse opt-out,
damage-flash opt-out.

### G.1 — Visual Accessibility

| Concern | Solution | Source |
|---------|----------|--------|
| Text contrast (UI) | Body ≥ 4.5:1 (WCAG AA); large text ≥ 3:1; HUD numerals on BQA Blue 85% panel verified Parchment-on-blue 7.2:1 (AAA) | `accessibility-requirements.md` §Visual |
| Minimum text size — HUD | 18 px floor enforced via FontRegistry scale-aware call (REV-2026-04-26 D2). HUD numerals 22 px, "HP" label 13 px (acceptable as ancillary glyph) | HUD Core CR-19 |
| Color-as-only-indicator | Health: numeric value + colour swap + flash + audio clock-tick (4 channels). Captured-equipment PHANTOM Red: redundant with `[CAPTURED]` text in Inventory tooltip. Crosshair: tri-band halo (light + dark contrast guaranteed) | `accessibility-requirements.md` §Color audit |
| Colorblind modes | Protanopia / Deuteranopia / Tritanopia: shift Alarm Orange `#E85D2A` → verified via Coblis simulator. PHANTOM Red `#C8102E` not used as the only indicator | Settings GDD §G.3 |
| UI scaling | `Settings.ui_scale` 75–150% (default 100%). HUD scales independently from menu via viewport-scale rule (Section C) | Settings GDD §G.3 |
| Brightness / gamma | Settings G.3 with reference calibration image; range -50% to +50%. HUD legible at all values via 85% opacity background scrim | Settings GDD §G.3 |
| Motion / animation reduction | `Settings.reduced_motion`: suppresses critical-health pulse (Behavior 3); damage flash + edge-trigger swap remain (already vestibular-safe by hard-cut design) | `accessibility-requirements.md` §Visual + Section E |
| Photosensitivity opt-out | `Settings.hud_damage_flash_enabled` (Day-1 MVP toggle). Damage flash rate-gated 333 ms (3 Hz WCAG ceiling) regardless. Boot-warning modal at first launch | HUD Core REV-2026-04-26 D2 (HARD MVP DEP) |
| Crosshair toggle | `Settings.crosshair_enabled` (default `true`, opt-out). Aim is gun-position-anchored; crosshair is a visual aid, not a gameplay requirement | Settings GDD §G.3 |

### G.2 — Motor Accessibility

| Concern | Solution |
|---------|----------|
| Hold-to-press alternatives | HUD does not own input; ADS / Sprint / Crouch / Gadget-charge toggles owned by Settings (CR-22, Day-1 MVP) |
| Aim assist | HUD does not own; Settings G.3 `aim_assist_*` granular sliders. Crosshair (Element 4) renders regardless of aim-assist state |
| One-hand mode (partial) | Toggle alternatives cover the most severe motor barriers; HUD itself requires no input |
| HUD repositioning | **NOT committed at v1.0** — Comprehensive-tier feature, out of scope per `accessibility-requirements.md`. HUD anchoring is fixed; UI scale slider (75–150%) is the partial mitigation |
| Adaptive-controller cinematic dismiss | HUD does not own (Cutscenes Finding 6); HSS states are auto-dismiss only — no player input required to clear |

### G.3 — Cognitive Accessibility

| Concern | Solution |
|---------|----------|
| HUD information density | 5 Must Show widgets (lowest in stealth-FPS class); 0 On-Demand surfaces; transient states auto-dismiss without demanding acknowledgment |
| Reading time for transient states | All HSS states have **minimum** read time (1.5 s respawn, 2.0 s alert, 3.0 s alarm / memo, 4.0 s save-failed). Auto-dismiss is **silent-drop**, not auto-cancel — text remains visible for the full duration regardless of player action |
| Quest / objective clarity | HUD does NOT show objectives (Pillar 5). Objectives accessible via Pause Menu → Mission tab; first-encounter prompts persist until acknowledged (HUD prompt-strip lifecycle) |
| Visual indicators for audio-only information | (1) HSS ALERT_CUE (HoH / deaf alert-cue HARD MVP DEP per HUD State Signaling REV-2026-04-26 D3). (2) Document pickup → MEMO_NOTIFICATION. (3) Save-failed audio → SAVE_FAILED state. (4) Critical-health audio clock-tick → critical-health pulse (visual, opt-out) |
| Pause anywhere | HUD hides on `ui_context_changed → PAUSE`; pause is gameplay-side, not HUD |
| Tutorial persistence | Plaza tutorial dialogue accessible from Pause Menu → Help section (per `accessibility-requirements.md` §Cognitive) |

### G.4 — Auditory Accessibility

| Concern | Solution |
|---------|----------|
| Subtitles | Owned by Dialogue & Subtitles on **separate CanvasLayer 2**; HUD does NOT render subtitles. Default ON (Settings VS commitment) |
| Closed captions for gameplay-critical SFX | (1) Damage SFX → damage flash visual + numeric value (Element 1). (2) Alert stinger → ALERT_CUE state (Element 5). (3) Document pickup chime → MEMO_NOTIFICATION (Element 5). (4) Save-failed audio → SAVE_FAILED state (Element 5). (5) Cutscene narrative SFX → D&S Category 8 captions (out of HUD scope) |
| Mono audio | **NOT committed at v1.0** — Comprehensive-tier; spatial audio is Pillar 3 load-bearing. HUD's HoH alert-cue + damage flash + critical-pulse are the visual fallback for spatial audio |
| Independent volume controls | HUD does NOT own audio mixing; Settings G.3 owns 4-bus architecture |

### G.5 — AccessKit Per-Widget Table (Godot 4.6 AccessKit integration per ADR-0004)

| Element | `accessibility_role` | `accessibility_name` | `accessibility_description` | `accessibility_live` | Announcement Cadence |
|---------|----------------------|----------------------|------------------------------|----------------------|----------------------|
| Element 1 (Health) | `TEXT` | `"Health"` | `"[N] of [M]"` | `polite` | Edge-trigger only (entering / exiting critical); NOT every damage tick |
| Element 2 (Weapon + Ammo) | `TEXT` | `"Weapon"` | `"[weapon] [current] of [reserve]"` | `polite` | On weapon switch; on first depletion threshold (≤25% reserve); NOT every shot |
| Element 3 (Gadget) | `IMAGE` | `"Gadget"` | `"[gadget name]"` (or `"No gadget equipped"`) | `polite` | On equip change |
| Element 4 (Crosshair) | (none) | (none) | (none) | (none) | No semantic value |
| Element 5 (Prompt-Strip) | `STATUS` | per-state localized name | per-state text | `polite` for INTERACT / ALERT / MEMO / RESPAWN / SAVE_FAILED; `assertive` for ALARM_STINGER (sole carve-out) | On state-text change only |

**AccessKit verification gates (BLOCKING before sprint per ADR-0004 Gates 1+2 and OQ-HUD-8 / OQ-HSS-8)**:

- Confirm Godot 4.6 supports the full role taxonomy used here (`TEXT`, `IMAGE`, `STATUS`).
- Confirm `accessibility_live` property name on Godot 4.6 Label / Control.
- Confirm deferred-AccessKit (`call_deferred` for `accessibility_*` sets) preserves announcements without cutoff.

### G.6 — Color-as-Only-Indicator Audit (HUD-specific subset)

| Location | Color Signal | What It Communicates | Non-Color Backup |
|----------|--------------|----------------------|------------------|
| Element 1 health bar | Red ramp (Alarm Orange) at low HP | Player near death | Numeric value (the dominant channel) + flash + audio clock-tick + critical pulse |
| Element 5 alert state | (no colour signal — text-only) | Stealth alert escalation | Margin-note Label text + AccessKit polite live-region |
| Element 3 gadget capture tint | PHANTOM Red on icon | Captured equipment | Inventory tooltip `[CAPTURED]` text label (off-HUD); HUD tint is supplementary |
| Element 4 crosshair | Default white / Ink Black | Aim target | Dot is Ink Black + halo is tri-band — contrast guaranteed against any background. Toggle-able via Settings (gun-position aim works without crosshair) |

### G.7 — Localization Constraints

| Concern | Mitigation |
|---------|------------|
| Text expansion (German / French ~30%) | All HUD labels via `tr()`. Weapon names: design constraint ≤ 20 chars at 13 px Futura Condensed; if German exceeds, Art Director approves condensed-variant per OQ-HUD-7. HUD_ALARM_RAISED shortened to 12 chars (≤25 abs max) per HUD Core REV-2026-04-28 |
| Locale-specific number / date formats | Health / ammo numerals are integers — no locale-specific format. No date / currency on HUD |
| RTL languages (Arabic, Hebrew) | Not committed at v1.0 — no RTL locale planned. HUD anchors are LTR (BL / BR mirrored variants would require RTL audit) |
| Reading-speed validation | HSS state durations (1.5–4.0 s) target English baseline; non-English locale validation is a `qa-tester` test case per `accessibility-requirements.md` test plan |

### G.8 — Accessibility Test Plan (HUD-specific subset)

| Feature | Test Method | Pass Criteria |
|---------|-------------|---------------|
| HUD text contrast | Automated — `tools/ci/contrast_check.sh` on screenshots | Health / weapon / ammo / prompt-strip text ≥ 4.5:1 (body); ≥ 3:1 (large) |
| Colorblind modes | Manual — Coblis on each section + each HUD state | Element 1 critical state distinguishable in all modes; PHANTOM Red gadget tint readable in all modes |
| Photosensitivity boot warning | Manual — first-launch user flow | Modal fires before main menu; opt-out persists; damage flash respects toggle |
| Damage-flash rate-gate | Automated — fire 10 hits in 1 s, count flashes | ≤ 3 flashes (333 ms gate enforced) |
| Critical-health pulse opt-out | Manual — toggle, observe Element 1 at <25% HP | Pulse runs when ON; suppresses when OFF; categorical colour swap remains in both modes |
| HSS ALERT_CUE visibility (HoH) | Manual — trigger guard alert with audio muted | Margin-note text appears in prompt-strip within 1 frame of `alert_state_changed` |
| AccessKit screen-reader (Linux Orca / Windows Narrator) | Manual — navigate gameplay with screen reader | Element 1 announces on critical edge-trigger only; Element 5 announces on state change; ALARM_STINGER announces with `assertive` priority |
| Reduced-motion compatibility | Manual — toggle, observe Element 1 + Element 5 lifecycles | Critical pulse suppressed; damage flash + edge-trigger remain; transient state hard-cut entry / exit (no fade) |

---

## Open Questions

Open questions tracked from `hud-core.md` `OQ-HUD-1..8` and
`hud-state-signaling.md` `OQ-HSS-1..10`. Owner / deadline columns
reflect existing GDD assignments; this UX spec inherits the GDD's
tracking.

### BLOCKING (must close before sprint plan)

| # | Question | Owner | Deadline | Notes |
|---|----------|-------|----------|-------|
| 1 | **OQ-HUD-5** — F.5 per-frame cost constants must be measured on Iris Xe Gen 12 / Godot 4.6 / 810p Restaurant reference scene. Worst-case ≤ 0.289 ms vs 0.3 ms cap (11 µs headroom). If `C_label > 0.05 ms` or `C_a11y > 0.030 ms`, ADR-0008 amendment required. | performance-analyst + godot-specialist | Before sprint plan closes | Affects whether HUD ships at MVP — perf cap breach is ship-blocking |
| 2 | **OQ-HUD-7** — Art Director must approve 22 px slash rendering OR specify thinner typographic substitute (Art Bible §7A spec calls for slash at ~70% numeral width). | art-director | Before sprint | Element 2 spec has a coordination gap |
| 3 | **OQ-HUD-8 / OQ-HSS-8** — `accessibility_live` property name on Godot 4.6 Label / Control + ADR-0004 Gates 1+2 closure pending. | godot-specialist + ux-designer | Before sprint kickoff | Day-1 default suppression behaviour required even though AccessKit feature is Polish-tier |
| 4 | **OQ-HSS-4** — HSS per-frame cost measurement (CR-14): steady ~10 µs (pulse Tween) + peak 52 µs (state transition). Combined with HUD Core worst-case (259 µs) = 311 µs (**11 µs over cap**). Mitigation: deferred-AccessKit (default at Day-1, not emergency fallback). | performance-analyst | Before sprint kickoff | Same gate as OQ-HUD-5 |
| 5 | **OQ-HSS-6** — WCAG 2.2.1 (Timing Adjustable / Pause Stop Hide) mechanism for HSS transient states. Currently all states auto-dismiss with no player pause option. | ux-designer + accessibility-specialist | Before sprint plan closes | Settings GDD coord item |
| 6 | **OQ-HSS-10** — `accessibility.hud_critical_pulse_enabled` toggle (WCAG 2.2.2 Pause / Stop / Hide opt-out). Settings GDD must ship before HSS pulse goes live; CR-18 implementation deferred until Settings authoring. | ux-designer + Settings-author | Before VS sprint | Behavior 3 (Critical-Health Pulse) cannot enable until Settings ships the toggle |

### ADVISORY (close before VS playtest)

| # | Question | Owner | Notes |
|---|----------|-------|-------|
| 7 | **OQ-HUD-1** — Should HUD scale be exposed as a separate Settings slider (`hud_scale_multiplier`, [0.5, 2.0]) for accessibility (low-vision, ultrawide edge cases)? Currently NOT in MVP; viewport-scale rule is the only scaling. | ux-designer | Forward dep — post-MVP if needed |
| 8 | **OQ-HUD-2** — If context changes to GAMEPLAY while `_pending_flash` is queued, should the flash fire immediately on context-restore? Currently fires on timer (correct diegetic frame-advance behavior). | game-designer + playtest sign-off | Decision pending VS playtest |
| 9 | **OQ-HUD-3** — Settings & Accessibility boot sequencing vs HUD `_ready()`: crosshair initial value is `false` until Settings emits first `setting_changed` event. CI gate required. | godot-specialist | Verification — not a design choice |
| 10 | **OQ-HUD-4** — LSS restore-callback signal re-emission timing: `player_health_changed`, `ammo_changed`, `weapon_switched`, `gadget_equipped` must fire AFTER HUD `_ready()` completes. ADR-0007 load-order enforced; gate required. | godot-specialist | Verification — not a design choice |
| 11 | **OQ-HUD-6** — Godot 4.6 API verification batch (5 items): `Color(hex, alpha)` constructor, `TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL`, `set_anchors_preset()` method, `process_frame` signal, `focus_mode = FOCUS_NONE`, `corner_radius_*` on StyleBoxFlat. | godot-specialist | Engine-reference cross-check |
| 12 | **OQ-HSS-1** — Is 1.0 s per-actor alert-cue cooldown appropriate, or should it be tunable per Stealth AI oscillation rate? Currently locked; recommend playtest validation. | qa-tester + game-designer | VS playtest decision |
| 13 | **OQ-HSS-2** — Should MEMO_NOTIFICATION queue depth be >1? Currently single-deep buffer — design intent: "if you missed the first one, the game is still running." | game-designer | Confirm acceptable post-playtest |
| 14 | **OQ-HSS-3** — ALARM_STINGER 3.0 s duration: feels right, or should it scale with section size? | game-designer + audio-director | Locked pending playtest |
| 15 | **OQ-HSS-5** — Should `accessibility.hud_critical_pulse_enabled` be a per-motion-frame reduction knob or binary on / off? Currently binary. | ux-designer | Playtest may reveal need for intensity slider |
| 16 | **OQ-HSS-7** — If `ui_context_changed` to PAUSE while ALERT_CUE active, should timer pause (resume on GAMEPLAY return) or stop (state drops)? Currently stops (CR-11 — no resume). | ux-designer + accessibility-specialist | Confirm acceptable for HoH players |
| 17 | **OQ-HSS-9** — CR-18 pulse period floor clamp (`pulse_period_s = max(clock_tick_period_s, 0.4)`) guards against Audio mistuning below 2.5 Hz (WCAG 2.3.1). Confirm Audio §F.4 default 0.6 s is locked. | audio-director | Confirmation |

### Cross-spec deps (closed by other docs but tracked here)

| # | Dep | Status |
|---|-----|--------|
| 18 | Input GDD CR-21 (runtime key-glyph rebinding contract) | OPEN — gamepad players see KB glyphs at MVP per Section F |
| 19 | Settings & Accessibility GDD authoring (HARD MVP DEP per HUD Core REV-2026-04-26 D2) | DESIGNED — production-side dependency |
| 20 | ADR-0002 amendment to add `gadget_activation_rejected` signal (NEW, per HUD Element 3 + Inventory CR-4b) | PROPOSED |
| 21 | ADR-0002 amendment to add `ui_context_changed` signal | PROPOSED — required by Behavior 6 |
| 22 | ADR-0004 Gates 1+2 (AccessKit role / live-region taxonomy verification) | OPEN — ties to BLOCKING #3 |

### Note on UX-only open questions

No NEW open questions are introduced by this UX spec. All open questions
reflect upstream GDD decisions that are still in motion. If the user
runs `/ux-review hud` and the reviewer surfaces a UX-only question, this
section will be amended.
