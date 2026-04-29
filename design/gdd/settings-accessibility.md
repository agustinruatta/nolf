# Settings & Accessibility

> **Status**: In Design — Revised post-`/design-review` re-review (2026-04-27)
> **Author**: User + `/design-system settings-accessibility` (solo mode) + `/design-review` revision pass (2026-04-26 PM) + `/design-review` re-review revision pass (2026-04-27)
> **Last Updated**: 2026-04-27 (re-review revisions: 9 BLOCKING items resolved per 9-specialist + creative-director synthesis. **Theme 1 close-as-confirm propagation**: F.3 panel-close behavior block + F.3 variable table + F.3 mid-timer + F.3 example + Cluster D first bullet + AC-SA-4.6 all aligned with CR-15. **Theme 2 Cluster I dual-discovery stale text**: rewritten for single-canonical-home. **Theme 3 CR-25 photosensitivity safety cluster**: now preserves all 3 keys (`photosensitivity_warning_dismissed`, `damage_flash_enabled`, `damage_flash_cooldown_ms`); modal copy "preferences" plural; AC-SA-11.1/11.2/11.4 revised. **Theme 4 `clock_tick_enabled` category**: moved from `audio` to `accessibility` to match Audio GDD; C.2 + G.1 + G.3 + AC-SA-3.4 updated. **Theme 5 0 dB clipping risk**: escalated to NEW BLOCKING coord OQ-SA-14 + warning at top of G.1; defaults flagged TENTATIVE. **Theme 6 F.1 inverse default branch**: corrected return value 0 → 1 for sub-Segment-A audible-but-quiet hand-edited cfg. **Theme 7 F.1 NaN handling**: explicit `is_nan()` precondition added to forward + inverse (clamp alone insufficient per IEEE 754); AC-SA-11.13 revised. **Theme 8 F.1 silence sentinel mute**: AudioServer.set_bus_mute() called at p=0; AC-SA-3.2 revised. **Theme 9 invented API**: `Input.get_action_display_name()` removed; existing `tr("INPUT_ACTION_NAME_<ACTION>")` pattern at C.5 line 306 promoted to primary; OQ-SA-11 revised. **AC reclassifications**: AC-SA-5.3 / 10.4 / 11.7 ADVISORY → BLOCKING per safety-floor + ADR-0004 IG10 chain. **Localization**: `SETTINGS_NAV_DEAD_END` split into `_TOP` + `_BOTTOM` keys; "yet" removed from modifier feedback per Stage Manager register. **NEW coord items**: OQ-SA-13 (clock_tick category), OQ-SA-14 (0 dB clipping). **Coord total**: 12 → 14 BLOCKING + 4 ADVISORY)
> **System index**: #23 (Polish/Meta layer; Vertical Slice tier — but Day-1 minimal-MVP slice promoted to HARD MVP dep by HUD Core REV-2026-04-26 D2)
> **Implements Pillar**: (TBD §B) — Pillar 5 carve-out (accessibility scaffolding is non-diegetic, decided on accessibility grounds per CD ruling 2026-04-21)
> **Dependents (forward — already locked)**: HUD Core (HARD MVP DEP D2), Combat (OQ-CD-12 — 7 contracts), Inventory & Gadgets (3 contracts + OQ-INV-5), Player Character (AC-9.2 BLOCKED), Outline Pipeline, Audio, Localization Scaffold, Input

## Overview

Settings & Accessibility is *The Paris Affair*'s **persistence + signal-emit layer for player preferences AND the player-facing modal panel that exposes them**. As a data layer it is the **sole publisher** of `setting_changed(category: StringName, name: StringName, value: Variant)` — the only `Variant`-payload signal in the entire ADR-0002 taxonomy, singled out because settings values are genuinely heterogeneous (dB floats, enum strings, bool toggles, int sliders, `InputEvent` rebinds) — and the **sole owner** of `user://settings.cfg` (per ADR-0003: a Godot `ConfigFile` strictly separate from `SaveGame`, never wiped by new-game actions). As a player-facing surface it is a modal panel reached through Menu System / Pause that pushes `InputContext.SETTINGS` (per ADR-0004) and renders six categorical sub-screens — **Audio, Graphics, Accessibility, HUD, Controls, Language** — each composed of standard Theme-inherited Controls (sliders, toggles, dropdowns, key-rebind capture rows) with AccessKit screen-reader integration (ADR-0004 IG10, Day-1 mandate; gated on Gate 1 `accessibility_*` property name verification + Gate 2 Theme inheritance property verification — both still OPEN). Settings sits **outside** Pillar 5's diegetic period fiction by explicit creative-director carve-out (2026-04-21, in Combat §B): accessibility scaffolding is decided on accessibility grounds, not on whether Eve could plausibly experience it in 1965; the panel is intentionally non-diegetic, while the **defaults** it ships with remain period-authentic (modern conveniences like Enhanced Hit Feedback or non-diegetic gadget-ready glyphs are opt-IN, never default; the established opt-OUT exception is the crosshair, Combat-locked). This GDD authors a single design covering both **Day-1 minimum-MVP slice** (photosensitivity toggle + first-boot photosensitivity warning dialog + crosshair toggle + 6 audio bus sliders + clock-tick toggle + resolution-scale dropdown — the slice that closes HUD Core REV-2026-04-26 D2's HARD MVP-dep gate) and **full Vertical Slice scope** (8 GDDs worth of declared forward-dep contracts: Combat OQ-CD-12 ×7, Inventory ×3 + OQ-INV-5 separate-rebind, PC look-sensitivity overrides + `get_resolution_scale()` query, full keyboard rebinding UI with conflict detection, locale switcher behind Localization Scaffold, Outline Pipeline hardware-default detection); each subsequent section tags its content **[MVP]** vs **[VS]** so implementation can ship the MVP slice without fragmenting the spec. **This GDD defines**: the six setting categories and their canonical key namespaces, the `setting_changed` emit contract, the boot-time load-and-apply order, the persistence schema in `user://settings.cfg`, the modal-panel UX flow + InputContext lifecycle, the rebinding-capture state machine + conflict-detection rules, the photosensitivity-warning first-boot flow, the AccessKit semantic-label contract for all settings widgets, and the hardware-default detection rule. **This GDD does NOT define**: the actual values being toggled (Combat owns crosshair defaults; Audio owns bus volumes; Outline owns resolution_scale curve; HUD owns flash-cooldown floor — Settings persists + emits, the consumers apply); the visual styling of slider/toggle widgets (ADR-0004 Theme owns); the Menu System hub that contains the Settings entry-point (Menu System #21 owns); the screen-reader integration for *gameplay* HUD (HUD Core owns, deferred to Polish per ADR-0004 IG10); and any sliders for values that are not safe for the player to tune (e.g., `hud_damage_flash_cooldown_ms` is exposed only ABOVE its 333 ms safety floor — the floor itself is locked).

## Player Fantasy

**Anchor: "The Stage Manager."**

The fantasy is *the brief moment between scenes when the stage manager — not the actor — asks if your seat is comfortable, then disappears.*

When the player opens the Settings panel, the game steps offstage and asks a quiet, professional question: *"How do you want this to work?"* Eve, PHANTOM, the Eiffel Tower — they all pause. The player isn't being immersed; they're being briefed. Defaults were chosen carefully (period-authentic, hardware-aware, accessibility-first); the panel is the place those defaults can be overruled. When the player applies a change, the panel closes without ceremony and the game resumes exactly where it was, accommodation now silently in effect.

### Anchor moment

Mid-mission, the player realizes the damage flash is too aggressive. They press Esc, navigate to *Accessibility → Photosensitivity → Damage Flash Cooldown*, drag the slider to 1000 ms, dismiss the panel. They are back in Eve's body inside three seconds. No "settings saved" satisfaction sting. No congratulatory copy. The game just listened, adjusted, and got out of the way. The next time Eve takes a hit, the visual flash is gentler — and the panel is forgotten until the next time the player needs it.

### Pillar alignment

- **Primary — Pillar 5 carve-out.** The panel is non-diegetic by design. That admission *is* the discipline. There is no "MI6 Personnel File" wrapper, no typewriter-paper conceit, no Eve-voiced confirmation. The panel is plainly modern, plainly a menu, and unapologetic about it — because pretending otherwise would force accessibility scaffolding through a fiction it doesn't belong in. (Established by creative-director ruling 2026-04-21 in Combat §B; this GDD inherits the carve-out verbatim.)
- **Supporting — Pillar 3 (Stealth is Theatre, Not Punishment).** The panel is theatre's stage manager — invisible, professional, removes friction so the show can run. It is the structural reason a photosensitive player isn't punished for being photosensitive, the reason a player on Iris Xe isn't punished for not having an RTX 2060.
- **Supporting — Pillar 1 (Comedy Without Punchlines).** The menu doesn't crack a joke, doesn't wink, doesn't apologize. Its restraint is the same restraint that makes Eve deadpan — competence expressed through what is *not* said. The Settings panel is the most laconic thing in the game.

### Tone register

Quiet, professional, brisk. Same register as a good theatre crew during a scene change — competent, invisible, never asking to be appreciated. Compatible with HUD Core's "The Glance" (both refuse spectacle), Combat's "the most competent person in the room" (the panel itself is competent), and Eve's deadpan (the panel speaks in the same restrained voice the rest of the game does, even though Eve is offstage while it's open).

### Refusals — five things this fantasy is NOT

1. **NOT diegetic.** No briefing-folder framing, no "Agent Sterling, configure your gear", no Nagra-reel sound effects on toggles. The panel doesn't pretend to be in 1965.
2. **NOT theatrical or celebratory.** No swelling music when accessibility is enabled. No "Accessibility ON ✓" sting. No congratulatory copy ("Great choice!"). No animated check-mark flourishes.
3. **NOT apologetic.** No "we know menus break immersion, but…" language. The panel doesn't ask for forgiveness for existing.
4. **NOT a moral statement about inclusivity.** The panel does the work; it doesn't make a speech. Strings like "we want everyone to enjoy this game" are forbidden — the warmth must be structural (the accommodation exists, the defaults are smart, the friction is gone), never textual.
5. **NOT a moment for Eve's voice or PHANTOM's presence.** The fiction is paused, not playing. There is no in-character VO when settings are opened, no PHANTOM red bleeding into the panel chrome, no period-jazz score over the menu. The panel is silence-relative-to-the-game (UI bus only; music + SFX + ambient + voice all cease or duck per ADR-0004 InputContext.SETTINGS lifecycle).

### Fantasy test (for future Settings additions)

*Does this addition behave like a stage manager — quietly competent, never demanding attention, never speaking in the protagonist's voice? If it postures, performs, or congratulates itself, it fails.*

Concretely: a new toggle passes the test if it (a) does its job when applied, (b) does not produce celebratory feedback, (c) does not require a player to read a paragraph of explanation to use, and (d) does not invoke Eve, BQA, PHANTOM, or any in-game faction in its label or copy.

## Detailed Design

### C.1 — Core Rules

**Architectural rules (sole-publisher discipline):**

**CR-1.** SettingsService is the **sole publisher** of `Events.setting_changed(category: StringName, name: StringName, value: Variant)` per ADR-0002. No other system may emit this signal. Code-review forbidden pattern: any `Events.setting_changed.emit(...)` call outside `SettingsService.gd` is a defect.

**CR-2.** SettingsService is the **sole reader and writer** of `user://settings.cfg` per ADR-0003. No other system may call `ConfigFile.load("user://settings.cfg")` or `ConfigFile.save("user://settings.cfg")`. Code-review forbidden pattern: grep for either call outside `SettingsService.gd`.

**CR-3.** SettingsService is registered as autoload per ADR-0007 (amended 2026-04-27 — see ADR-0007 §Canonical Registration Table). Position at the **end of the registration block** is intentional — Settings depends on `Events` being live (CR-1), and consumers use the **`settings_loaded` one-shot signal pattern** (CR-9), not direct `_ready()` reads of `SettingsService`. End-of-block placement is therefore safe: by the time SettingsService's `_ready()` fires, every consumer autoload (Combat, F&R, MLS, etc.) is already in the tree and has connected its `setting_changed` subscriber, so the boot burst (B.3 §C.3 step 3) reaches every subscriber synchronously. Per ADR-0007 IG7: this GDD does NOT restate specific line numbers — refer to ADR-0007 §Canonical Registration Table for the authoritative ordering. (Earlier draft of this GDD claimed slot #8 — that misclaim was the centerpiece of /review-all-gdds 2026-04-27 Blocker B2; resolved by the 2026-04-27 ADR-0007 amendment placing SettingsService at the end of the canonical table.)

**CR-4.** Every setting key uses **two-part namespacing**: `(category, name)` where `category ∈ {audio, graphics, accessibility, hud, controls, language}` and `name` is the canonical setting key. The pair `(category, name)` is the unique identifier across the whole settings layer. There is no global setting key; settings are always category-scoped.

**Consumer pattern rules:**

**CR-5.** Every consumer of `setting_changed` MUST use the filter-first pattern:
```gdscript
func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
    if category != &"<my_category>": return  # MANDATORY first statement
    match name:
        &"<key_a>": _apply_a(value)
        &"<key_b>": _apply_b(value)
        # NO else branch — silently ignore unknown names (forward-compat)
```
The `if category != ...: return` guard MUST be the first statement. The `match` MUST NOT have an `else` branch — forward-compat with future setting keys.

**CR-6.** Consumers MUST ship hardcoded defaults (the **Consumer Default Strategy**). Each consumer that reads a setting at runtime defines a fallback constant in `res://src/core/settings_defaults.gd` (or its own equivalent constant block). At `_ready()`, consumers initialize from this constant. SettingsService's boot-burst (CR-9) overrides within the same boot frame. Consumers MUST NOT call `SettingsService.get_value(...)` synchronously during their own `_ready()` — that creates a load-order race even with the autoload slot ordering.

**CR-7.** Consumers MUST NOT cache `value: Variant` into a strongly-typed variable without a type guard. Save-forward compatibility requires `if value is float: my_float = value` (or equivalent for int / String / bool / InputEvent / Vector2). A `Variant`-as-`float` direct cast can crash on a corrupt or version-mismatched `settings.cfg`.

**Persistence rules:**

**CR-8.** **Write-through on commit, with widget-class-aware commit semantics.** SettingsService writes the new value to `user://settings.cfg` immediately on the **commit event** for each widget class — not on every continuous-change tick. Commit events:
- **Continuous sliders** (`HSlider`): commit on `drag_ended(value_changed: bool)` if `value_changed == true`. During drag, `setting_changed` IS emitted on every `value_changed` tick (so consumers like AudioServer get live-preview audio), but `ConfigFile.save()` is called ONLY on `drag_ended`. Eliminates disk hammer (was: up to 100 sync writes/s during a 1-s drag; now: 1 write per drag).
- **Discrete controls** (`CheckButton`, `OptionButton`): commit immediately on `toggled` / `item_selected`. One event per interaction → one write. No batching.
- **Rebind captures** (`RebindRow`): commit on CAPTURING→NORMAL_BROWSE transition (one event per rebind).
- **Resolution-scale revert flow** (`OptionButton` for `graphics.resolution_scale`): commit on the explicit "Keep This Resolution" button OR on revert-timer elapse (CR-15). Mid-flow value changes do NOT write to disk until confirmed.

No Apply button at the panel level. Rationale: eliminates the "I didn't click Apply before the game crashed" failure mode while avoiding main-thread I/O spikes during slider drag. SIGKILL durability (AC-SA-2.6) holds for the last committed value (drag_ended boundary).

**CR-9.** **Boot-time burst.** At `_ready()`, after loading `settings.cfg`, SettingsService iterates all stored `(category, name, value)` triples and emits `Events.setting_changed` synchronously for each. After the last emit, SettingsService emits `Events.settings_loaded()` exactly once (one-shot signal, no payload). **Coord item: ADR-0002 amendment required to register the `settings` domain + `settings_loaded` signal.**

**CR-10.** **Defaults file is a `const` declaration only.** `res://src/core/settings_defaults.gd` is a `RefCounted` script with `const` fields and no runtime logic (no `_init`, no `static func` returning computed values). Pure constants enable test-time inspection and prevent default drift. The single exception is `resolution_scale` — see CR-11.

**CR-11.** **Hardware-aware first-launch defaults for `resolution_scale`.** When `settings.cfg` is absent or `graphics.resolution_scale` key is missing on first launch, SettingsService queries `OutlinePipeline.get_hardware_default_resolution_scale() -> float` exactly once and writes the result. Outline Pipeline's detection logic uses `RenderingServer.get_video_adapter_name()` heuristics (Iris Xe → 0.75; RTX 2060+ → 1.0; unknown → 1.0). **Coord item: Outline Pipeline GDD must expose `get_hardware_default_resolution_scale()` query.**

**Locale rules:**

**CR-12.** **Locale change is immediate-apply via `TranslationServer.set_locale()`.** No restart. All Control nodes re-resolve `tr()` keys within the same frame. Settings panel re-renders its own labels live.

**CR-13.** **Locale dropdown is hidden at MVP.** Until a second locale ships, the Language sub-screen renders a single non-interactive `Label` with text `tr("LANGUAGE_MVP_NOTICE")` (resolves to *"English (additional languages coming in a future update)"*). The `language.locale = "en"` key persists in `settings.cfg`; the `setting_changed` emit at boot is a no-op (no consumer reads it for behaviour at MVP). Locale switcher graduates to interactive `OptionButton` when Localization Scaffold ships its 2nd-locale CSV.

**Apply pattern + revert:**

**CR-14.** **Immediate apply for ALL settings except `graphics.resolution_scale`.** Every other setting writes through and emits `setting_changed` instantly. `resolution_scale` triggers a 10-second inline revert banner per **CR-15**.

**CR-15.** **Resolution-scale revert banner (TV-style fallback) — REVISED 2026-04-26 PM.** When `graphics.resolution_scale` changes, SettingsService:
1. Applies the new value immediately (`setting_changed` emit; consumers update; visual scale changes). **Does NOT write to disk yet** (per CR-8 — `OptionButton` is normally commit-on-`item_selected`, but `resolution_scale` is the documented exception that defers commit to confirmation).
2. Renders an inline revert banner at the bottom of the Settings panel with three elements: a label `tr("SETTINGS_RESOLUTION_REVERT_PROMPT")` resolving to *"Resolution scale changed to {value_pct}. Confirm or revert in {N} seconds."*, a **`[Keep This Resolution]` confirm button** (left), and a **`[Revert]` button** (right). `{value_pct}` is interpolated as the OptionButton's currently-selected localized item label (e.g., `"75%"`), NOT the raw float (CR-26 — see locale-format rule).
3. Starts a `Timer` with `RESOLUTION_REVERT_TIMEOUT_SEC` duration (tuning knob, default **7**, range [5, 30] — lowered from 10 per "back in three seconds" anchor moment).
4. **Confirmation paths** (value persists, banner dismisses, write-through fires):
   - Player presses `[Keep This Resolution]`
   - Player **closes the Settings panel** (Esc / B / Back) — close-as-confirm; this is the universal "I'm done" signal and the panel does NOT silently revert the player's deliberate change. Disclosed in banner copy via the `[Keep This Resolution]` affordance and a one-line legend below the banner: *"Closing this panel will keep the new resolution."*
   - Timer elapses with no input
5. **Revert path** (one-step undo; not a stack):
   - Player presses `[Revert]` — only positive revert action.
   - Reverts to previous value (the value before the first unconfirmed change in this panel session per F.3 mid-timer rule), `setting_changed` re-emits with old value, banner dismisses, no write.

The banner is the ONLY UX branch where Settings deviates from immediate-apply-commit-on-event. Rationale: a player picking 0.5 on Iris Xe at extreme zoom may render the panel itself unreadable; the revert banner is a recovery mechanism, not a confirmation gate. Auto-revert fires only on timer elapse with no input — close-as-confirm matches the Stage Manager fantasy ("the game just listened, adjusted, and got out of the way"). Banner is keyboard-navigable (initial focus on `[Keep This Resolution]` — the safer/preserves-intent choice; `ui_left`/`ui_right` cycles between Keep and Revert) and AccessKit-announced as `accessibility_role = "alert"` with `accessibility_live = "assertive"`.

**Photosensitivity rules:**

**CR-16.** **Photosensitivity kill-switch gates HUD damage flash + Enhanced Hit Feedback.** A single key `accessibility.damage_flash_enabled` (default `true`) gates BOTH the HUD numeral flash (HUD Core CR-7) AND the Combat Enhanced Hit Feedback pulse path (Combat V.6). When `false`, neither effect renders regardless of other settings. **Coord item: Combat GDD must add `setting_changed("accessibility", "damage_flash_enabled", _)` subscription that suppresses the EHF pulse when value is `false`.**

**Muzzle flashes, screen-shake, and bloom-on-hit (NEW BLOCKING coord — per accessibility-specialist S-1 + S-2):** WCAG 2.3.1 counts flash *frequency* per second, not duration; single-frame events repeated at >3 Hz exceed the threshold regardless of per-flash duration. The original framing "single-frame events at typical fire-rate are below threshold" was incorrect. Until the Combat GDD's weapon roster confirms maximum sustained automatic-fire rate is ≤180 RPM (3 Hz) AND screen-shake/bloom-on-hit effects are confirmed photosensitivity-safe (or explicitly exempt with rationale), these effects MUST be gated under `accessibility.damage_flash_enabled` as a precaution. **NEW BLOCKING coord items**: (a) Combat GDD declares max sustained fire rate per weapon class; (b) Combat GDD documents whether screen-shake on hit + bloom-on-hit subscribe to the kill-switch. Photosensitivity safety contract is non-negotiable; Combat may revise with Creative Director ruling but cannot skip the analysis.

**CR-17.** **Photosensitivity slider has 333 ms hard floor.** `accessibility.damage_flash_cooldown_ms` slider has `min_value = 333` clamped both in the UI widget AND on load (defensive clamp protects against manually-edited cfg files). Range [333, 1000]. Default 333. The 333 ms floor is the WCAG 2.3.1 ceiling (3 Hz) — non-negotiable safety contract.

**CR-18.** **First-boot photosensitivity warning.** On first launch (when `accessibility.photosensitivity_warning_dismissed` key is **absent** from `settings.cfg` — absence, not `false`), SettingsService sets `_boot_warning_pending = true`. Menu System #21 polls this flag during its own `_ready()` and displays a modal warning BEFORE the main menu becomes interactive. The modal text is the locked 38-word "Stage Manager"-register copy:

> *"This game contains flashing images, including rapid screen flashes during combat. You can reduce flash intensity in Settings → Accessibility, or disable it entirely. This notice can be reviewed again at any time from the Settings menu."*

Two buttons: **Continue** (sets `accessibility.photosensitivity_warning_dismissed = true`, dismisses) and **Go to Settings** (sets the same key, opens Settings → Accessibility pre-navigated). Default focus: **Continue**. Modal does not auto-dismiss. AccessKit semantic: `accessibility_role = "dialog"`, `accessibility_live = "assertive"` on appearance. **Coord item: Menu System GDD must read `_boot_warning_pending` and provide the modal scaffold.**

**Rebind rules:**

**CR-19.** **Rebinds are NOT routed through `setting_changed`.** Control rebinds use a separate flow: the rebind capture state machine (C.5) writes directly to Godot's `InputMap` AND persists the captured `InputEvent` subclass-fields manually to a `[controls]` section of `settings.cfg`. The `setting_changed` signal is NEVER emitted for rebind changes. Rationale: Variant-as-InputEvent is type-unsafe across system boundaries; the publish-subscribe bus is not the right channel. At boot, SettingsService reads the `[controls]` section, reconstructs `InputEvent` instances, and applies via `InputMap.action_erase_events()` + `action_add_event()` — this happens BEFORE the burst emit (CR-9). No `setting_changed` is emitted for any rebind.

**CR-20.** **One keyboard binding + one gamepad binding per action.** No two-key multi-bind (rebinding to "F OR G fires the gun" is not supported). Each action has at most one `InputEventKey/MouseButton` and at most one `InputEventJoypadButton/Motion`. The rebinding UI captures and replaces; conflict detection (C.5) handles the "this key is already bound to X" case.

**CR-21.** **Toggle-Sprint / Toggle-Crouch / Toggle-ADS ship Day-1 [MVP].** Three new boolean keys in `controls` category: `sprint_is_toggle`, `crouch_is_toggle`, `ads_is_toggle` (all default `false` — hold-to-press is the period-authentic default, toggle is opt-IN motor accessibility). PC's Sprint/Crouch handlers + Combat's ADS handler subscribe to `setting_changed("controls", ...)` and switch behavior accordingly. **Coord items: PC GDD touch-up + Combat GDD touch-up acknowledging the contract.**

**CR-22.** **`use_gadget` and `takedown` are independently rebindable AND default to DIFFERENT keys [MVP] — REVISED 2026-04-26 PM.** Per accessibility-specialist ruling + creative-director adjudication, motor-accessibility one-handed players require not just rebind separation but also pre-rebind differentiation; if both default to the same key, the conflict-detection system would surface a phantom conflict on any subsequent rebind, and the accessibility benefit would be theoretical until the player rebinds. **Differentiated defaults**: `use_gadget = KEY_F` / `JOY_BUTTON_Y` (preserves Inventory CR-4's gadget convention); `takedown = KEY_Q` / `JOY_BUTTON_X` (left-hand QWERTY adjacent + adjacent Xbox face buttons). Combat's single-dispatch handler still reads SAI state (not action name), so the dispatch logic is unchanged — but the physical inputs no longer collide regardless of player rebinding choices. **Coord items**: (a) **Input GDD must register `use_gadget` and `takedown` as two distinct InputMap actions** (currently shared); (b) **Inventory GDD CR-4 must be amended** to document the differentiated defaults; (c) **Combat GDD touch-up** to acknowledge the contract (no logic change, but disambiguates the binding-vs-dispatch story).

**Subtitles rule:**

**CR-23.** **Subtitles default ON — write at MVP, consume at VS — REVISED 2026-04-26 PM.** WCAG SC 1.2.2 (Captions Prerecorded) recommended-default. Player opts OUT explicitly. This is the **second exception** to the "modern accommodations opt-IN" rule (alongside crosshair); both are accessibility-first carve-outs. **Phasing decision (CD-adjudicated)**: SettingsService writes `accessibility.subtitles_enabled = true` to `settings.cfg` at MVP first launch, even though the Dialogue & Subtitles consumer ships at VS. The MVP-write is enforced by AC + CI gate to prevent any future revision from accidentally defaulting subtitles to OFF. The VS-consume contract is owned by D&S. Two contracts, both enforceable independently.

**Photosensitivity review-again rule:**

**CR-24.** **`accessibility.photosensitivity_warning_dismissed` is reset by an explicit "Show Photosensitivity Notice" button [MVP] — NEW 2026-04-26 PM.** Per accessibility-specialist + creative-director ruling, the locked CR-18 modal copy promises "This notice can be reviewed again at any time from the Settings menu." The mechanism is a button in the Accessibility sub-screen (G.3 — see widget table) labeled `tr("SETTINGS_REVIEW_PHOTOSENSITIVITY_NOTICE")` resolving to *"Show Photosensitivity Notice"*. Pressing the button immediately re-fires the modal (reusing CR-18's scaffold) without changing the dismissed flag — i.e., the player can review the notice at any time without re-triggering the boot-warning flow on next launch. Closing the modal via Continue or Go to Settings takes the same action paths as CR-18. Closes safety-critical S-3 + S-4 (medical-onset re-trigger path).

**Restore Defaults rule:**

**CR-25.** **Restore Defaults button is MVP-shipped with documented behavior — REVISED 2026-04-27 (preserves full photosensitivity safety cluster, not just the dismissed flag).** Per ux-designer + accessibility-specialist re-review BLOCKING-2 + ux-designer BLOCKING-2: the prior CR-25 only preserved `accessibility.photosensitivity_warning_dismissed` while resetting `accessibility.damage_flash_enabled` (back to true) and `accessibility.damage_flash_cooldown_ms` (back to the 333 ms safety floor). A photosensitive player who set cooldown to 1000 ms (maximum protection) reading the modal copy *"Your photosensitivity preference will be preserved"* received an active safety-communication failure — the next combat hit fired flashes faster than their threshold. The full **photosensitivity safety cluster** is now preserved as a single load-bearing unit. Behavior:
1. **Confirmation modal** appears: *"Restore all settings to defaults? Your photosensitivity preferences will be preserved."* Two buttons: `[Restore]` and `[Cancel]`. Default focus: `[Cancel]` (the safer non-destructive choice). Modal uses CR-18 scaffold pattern. *(Modal copy now says "preferences" plural, reflecting the cluster rule below.)*
2. On `[Restore]`: SettingsService:
   - Writes every key from `settings_defaults.gd` to `settings.cfg` (synchronous), **EXCEPT** the **photosensitivity safety cluster** (all three keys preserved as-is): `accessibility.photosensitivity_warning_dismissed`, `accessibility.damage_flash_enabled`, `accessibility.damage_flash_cooldown_ms`. Rationale: a Restore Defaults action is a settings convenience, not a safety reset; a player who tuned their photosensitivity protection (medical-onset configuration) does not have it silently reverted by a defaults-restore convenience action. Only explicit re-tuning OR full `settings.cfg` deletion can change these three keys.
   - Re-runs CR-11 hardware-default detection for `graphics.resolution_scale` (treats this as a fresh-install path).
   - Re-runs `_emit_burst()` per CR-9 — every consumer receives a `setting_changed` for every reset key. Live-applies without restart. The three preserved keys re-emit with their preserved values (consumers re-affirm state).
   - Does NOT re-emit `Events.settings_loaded` (one-shot per session per AC-SA-1.5).
3. On `[Cancel]`: modal dismisses; no state change.

The **photosensitivity safety cluster** rule is the design intent: photosensitivity-related settings are tuned for medical reasons, not aesthetic preference, and survive convenience actions. A player who already saw the warning at boot does not see it again on Restore Defaults; a player who set cooldown to 1000 ms keeps that setting through Restore Defaults. Only `settings.cfg` deletion (full wipe) re-triggers the safety flow + resets the cluster. *(If a player explicitly wants to reset photosensitivity settings, they can drag the slider back to the 333 ms floor or toggle damage_flash_enabled — both UI-reachable paths.)*

**Locale-format rule:**

**CR-26.** **Numeric / enum values in player-facing copy interpolate via tr-formatter, not raw type — NEW 2026-04-26 PM.** Per localization-lead BLK-4: when a setting value appears in player-facing copy (e.g., revert banner `"Resolution scale changed to {value_pct}"`), the interpolation `{value_pct}` MUST resolve to the localized OptionButton item label string (e.g., `"75%"`, `"75 %"`, `"75％"` per locale), NOT the raw float `0.75`. Implementation: every value-displaying tr-key takes a string-typed argument that the panel resolves from the widget's current display label, not the underlying stored value. Code-review verification at FP-8 grep boundary.

---

### C.2 — Six Categories & Key Namespaces

The 6 categories below are locked in this GDD. Adding a new category requires an amendment to this GDD + an ADR-0002 touch-up to register the category StringName.

| Category | Purpose | MVP keys (Day-1) | VS keys (Vertical Slice) |
|---|---|---|---|
| **`audio`** | All sound-related settings | `master_volume_db`, `music_volume_db`, `sfx_volume_db`, `ambient_volume_db`, `voice_volume_db`, `ui_volume_db` | — |
| **`graphics`** | Rendering settings | `resolution_scale` | `outline_thickness_multiplier` *(reserved)*, `glow_enabled` *(reserved — currently project-locked false)* |
| **`accessibility`** | Cross-cutting accessibility opt-IN/opt-OUT toggles + sliders | `damage_flash_enabled`, `damage_flash_cooldown_ms`, `crosshair_enabled` *(single canonical home — REVISED 2026-04-26 PM)*, `photosensitivity_warning_dismissed`, `subtitles_enabled` *(MVP-write per CR-23, VS-consume)*, `subtitle_size_scale` *(NEW 2026-04-28 night — MVP-write per D&S §C.10 / WCAG SC 1.4.4)*, `subtitle_background` *(NEW 2026-04-28 night — MVP-write)*, `subtitle_speaker_labels` *(NEW 2026-04-28 night — **MVP UI toggle** per D&S v0.3 D4 / WCAG SC 1.2.2)*, `subtitle_line_spacing_scale` *(NEW 2026-04-28 night — MVP-write / WCAG SC 1.4.12)*, `subtitle_letter_spacing_em` *(NEW 2026-04-28 night — MVP-write / WCAG SC 1.4.12)*, `clock_tick_enabled` *(REVISED 2026-04-27 — moved from `audio` to `accessibility` category to match Audio GDD's existing emit pattern at audio.md line 237; treats clock-tick as accessibility opt-OUT per cognitive-load concern — see Cluster J Pillar 5 carve-out)* | `enhanced_hit_feedback_enabled`, `gadget_ready_indicator_enabled`, `haptic_feedback_enabled`, `damage_flash_duration_frames`, `ads_tween_duration_multiplier`, `high_contrast_ui_enabled` *(reserved)* |
| **`hud`** | HUD-specific settings (the "I want this in HUD options" mental-model entry) | — *(crosshair_enabled REMOVED from hud category 2026-04-26 PM — single-home merge)* | `hud_scale`, `crosshair_dot_size_pct_v`, `crosshair_halo_style` |
| **`controls`** | Input bindings + input-mode toggles | `sprint_is_toggle`, `crouch_is_toggle`, `ads_is_toggle`, `mouse_sensitivity_x`, `mouse_sensitivity_y`, `gamepad_look_sensitivity`, `invert_y_axis`, `[rebinds]` *(separate sub-section, see CR-19)* | — |
| **`language`** | Localization | `locale` *(default `"en"`, dropdown hidden at MVP per CR-13)* | locale dropdown enabled when 2nd locale ships |

**Single canonical home for `crosshair_enabled` — REVISED 2026-04-26 PM (creative-director ruling).** Per game-designer adversarial finding + CD adjudication, the previous dual-discovery design (one stored value emitted under both `accessibility` and `hud`) created cognitive overhead with no player benefit and fails the "plainly a menu" mandate of the Stage Manager fantasy. **New rule**: `accessibility.crosshair_enabled` is the sole canonical key. The HUD sub-screen does NOT show a separate crosshair toggle row; instead it shows a one-line **cross-reference label** at the top of the HUD detail pane: *"Crosshair visibility — see Accessibility → Crosshair."* The label is non-interactive but keyboard-focusable; pressing Enter / A jumps to the canonical toggle in Accessibility (focus-redirect — does not duplicate the value). Combat's `_on_setting_changed` filter checks `category == &"accessibility"` only. HUD Core's filter likewise. Eliminates Cluster I dual-emit risk. AC-SA-5.8 + AC-SA-8.1 are merged into a single AC (see H.5/H.8).

---

### C.3 — Boot-Time Load + Apply Order

```
Engine init
  ├─ Autoload slot 1: Events           ._ready()
  ├─ Autoload slot 2: EventLogger      ._ready()  → Events.setting_changed.connect(...)
  ├─ Autoload slot 3: SaveLoad         ._ready()
  ├─ Autoload slot 4: InputContext     ._ready()
  ├─ Autoload slot 5: LSS              ._ready()
  ├─ Autoload slot 6: PostProcessStack ._ready()  → Events.setting_changed.connect(_on_set)
  ├─ Autoload slot 7: Combat           ._ready()  → Events.setting_changed.connect(_on_set)
  ├─ Autoload slot 8: FailureRespawn   ._ready()
  ├─ Autoload slot 9: MissionLevelScripting ._ready()
  └─ Autoload slot 10: SettingsService ._ready():
        1. _load_settings():
             - ConfigFile.load("user://settings.cfg")
             - if absent: populate from settings_defaults.gd, write
             - if missing keys: populate from defaults, write
             - if [accessibility.photosensitivity_warning_dismissed] absent:
                  _boot_warning_pending = true
             - if [graphics.resolution_scale] absent:
                  resolution_scale = OutlinePipeline.get_hardware_default_resolution_scale()
                  write
        2. _apply_rebinds():
             - read [controls] section
             - reconstruct InputEvent subclass-fields → call InputMap.action_erase_events()
               + action_add_event() for each action
             - (rebinds applied BEFORE burst; no setting_changed emit per CR-19)
        3. _emit_burst():
             - for each (category, name, value) in cfg, except [controls]:
                  Events.setting_changed.emit(category, name, value)
             - Each consumer receives synchronously, _on_setting_changed runs
        4. Events.settings_loaded.emit()  # one-shot, no payload
        ──── _ready() returns ────

Engine continues:
  ├─ Main scene loads (Menu System root)
  └─ Menu System polls SettingsService._boot_warning_pending:
        if true: display photosensitivity warning modal (CR-18)
        else: main menu interactive
```

**Why end-of-block placement works**: every consumer autoload (Combat at slot 7, F&R at slot 8, MLS at slot 9, plus PostProcessStack at slot 6) connected to `setting_changed` in its own `_ready()`. When SettingsService bursts at slot 10 (per ADR-0007 amended 2026-04-27 canonical table), every subscriber fires synchronously. There is no player-visible frame at risk — engine init is pre-gameplay. End-of-block is the safest position because it guarantees no later autoload could miss the burst.

---

### C.4 — Modal Panel Architecture

**Layout pattern: `HSplitContainer` sidebar-with-detail-pane.**

```
SettingsPanel (Control, root)              # CanvasLayer index 10
└── PanelContainer (theme-inherited)
    └── VBoxContainer
        ├── HeaderLabel ("Settings")
        ├── HSplitContainer
        │   ├── CategoryList (ItemList)    # left column, 6 rows
        │   │   • Audio
        │   │   • Graphics
        │   │   • Accessibility
        │   │   • HUD
        │   │   • Controls
        │   │   • Language
        │   └── DetailPane (ScrollContainer + VBoxContainer)
        │       └── (dynamically-loaded sub-screen for the selected category)
        ├── (revert banner, conditionally rendered per CR-15 — contains [Keep This Resolution] + [Revert] buttons + countdown legend)
        └── FooterRow (RestoreDefaults button + Back button — RestoreDefaults behavior per CR-25)
```

**Focus model (column-first navigation) — REVISED 2026-04-26 PM:**
- An internal `_focus_column: int ∈ {0, 1}` tracks whether keyboard/gamepad focus is in the category list (0) or the detail pane (1).
- **`ui_up` / `ui_down` semantics**: navigate within the current column. Column 0 (category list) vertically wraps. Column 1 (detail pane) does NOT vertically wrap. **Dead-end behavior**: pressing `ui_down` at the last focusable widget in detail pane (or `ui_up` at the first) is a no-op visually + plays no audio cue (Stage Manager refusal: no UI audio) BUT AccessKit announces a `live="polite"` dead-end string. **Two distinct tr-keys (REVISED 2026-04-27 per localization-lead NEW-1)**: `tr("SETTINGS_NAV_DEAD_END_BOTTOM")` resolving to *"End of section"* (ui_down at last widget); `tr("SETTINGS_NAV_DEAD_END_TOP")` resolving to *"Start of section"* (ui_up at first widget). The keys are split because some locales (German, Russian, Polish) require different grammatical forms for "end" vs "start" that cannot share a single tr-key with a direction argument. Prevents silent navigation failure for screen-reader users + makes the strings translatable.
- **`ui_right` from category list** → moves focus to the first focusable widget in detail pane and sets `_focus_column = 1`.
- **`ui_left` from detail pane** → moves focus back to the currently-selected category row and sets `_focus_column = 0`. **Scroll-position preservation**: when navigating away from a detail pane and back to the same category, `ScrollContainer.scroll_vertical` is preserved per category (designer-only state, not persisted to disk).
- **`ui_cancel` (Esc / B / Circle) at any focus** → calls `close()` per ADR-0004 IG3. Exception: during CAPTURING state, `ui_cancel` cancels capture only (per CR-19 + C.5).
- **Tab key — NEW 2026-04-26 PM**: Tab cycles through focusable widgets within the **current column only** (does not cross between category list and detail pane). Tab in detail pane wraps from last widget to first widget within the current sub-screen. Tab in category list wraps within the 6 rows. Shift+Tab reverses direction. Tab does NOT reach the FooterRow (Restore Defaults / Back) from either column — those are reached via `ui_focus_next` chain only after explicit column escape (use ui_cancel or click). This isolates Tab cycling from accidental footer activation.
- **Godot 4.6 dual-focus audit (NEW BLOCKING coord — per godot-specialist BLOCKING-1)**: Godot 4.6 separates mouse/touch focus from keyboard/gamepad focus. Every programmatic `grab_focus()` call in this Settings panel and the photosensitivity modal (CR-18, CR-24) sets keyboard/gamepad focus only — mouse hover focus is independent. **Coord item OQ-SA-10**: ui-programmer must audit each focus-jump point (initial focus on panel open, banner-appearance focus on revert banner, modal default-focus on Continue, Settings-pre-navigated focus on damage_flash_enabled toggle) and confirm dual-focus behavior matches design intent on the project's PRIMARY input (mouse). Implementation may need explicit mouse-focus reset alongside `grab_focus()`.
- Mouse hover on a category row highlights but does NOT auto-swap the detail pane (only click swaps; prevents thrash on accidental mouse moves). **Asymmetry note**: keyboard `ui_right` swaps detail pane immediately while mouse requires click. This is intentional (prevents accidental-hover thrash) but documented here so a future contributor doesn't "fix" it.
- Detail pane swap is **zero-frame** (no animation, no fade) per Stage Manager refusal #2.

**Restore Defaults behavior — per CR-25**: button in FooterRow renders with confirmation modal pattern. Pressing → confirmation modal (Restore / Cancel, default focus Cancel) → on Restore, full reset per CR-25 step 2 (preserves `accessibility.photosensitivity_warning_dismissed`).

**Widget styling (delegated to ADR-0004 Theme inheritance):**
- `HSlider` for continuous sliders (volumes in dB displayed as 0–100%, flash-cooldown in ms).
- `OptionButton` for discrete enums (resolution scale, halo style).
- `CheckButton` for toggles.
- Custom `RebindRow` (HBoxContainer with action label + binding label + capture button) for rebinds — see C.5.

**`mouse_filter`**: every Settings widget sets `mouse_filter = MOUSE_FILTER_PASS` (default for interactive controls). The panel root sets `mouse_filter = MOUSE_FILTER_STOP` so clicks outside any widget within the panel are absorbed (not propagated to gameplay).

**InputContext lifecycle**: opening Settings calls `InputContext.push(InputContext.Context.SETTINGS)` per ADR-0004; closing calls `InputContext.pop()`. While `SETTINGS` is active, gameplay `_unhandled_input()` handlers early-return.

---

### C.5 — Rebind Capture State Machine

**Three states:**

```
NORMAL_BROWSE  ──[player presses Enter on RebindRow capture button]──▶  CAPTURING
                                                                              │
        ┌─[player releases a key (key-up event)]─────────────────────────────┤
        ▼
   [check InputMap for conflict on the captured event]
        ├─[no conflict]──▶ apply rebind → NORMAL_BROWSE
        └─[conflict]────▶ CONFLICT_RESOLUTION
                                │
              ┌─[player picks Replace]─▶ erase conflicting binding,
              │                            apply new rebind → NORMAL_BROWSE
              └─[player picks Cancel]──▶ NORMAL_BROWSE (no change)
```

**State rules:**
- **Capture uses `_input(event)` + `set_input_as_handled()`** to swallow ALL keys including `ui_cancel` during the capture window. (`_unhandled_input` would let `ui_cancel` close the panel, which is wrong during capture.) Capture handler MUST sit at SettingsPanel root level (not nested in a child Control) to guarantee `_input` processing precedence over `_gui_input` Tab navigation (per godot-specialist ADVISORY-3).
- Capture binds on **key-UP** (key-release), not key-press. Switch-access devices and tremor-prone players generate spurious key-repeat on press; releasing a key is the intentional act.
- `Esc` during `CAPTURING` cancels the capture and returns to `NORMAL_BROWSE` without binding `Esc` itself (handled in the `_input` handler before the bind logic).
- **Esc-cancel onscreen disclosure (NEW 2026-04-26 PM — per ux-designer GAP-1)**: when CAPTURING starts, the RebindRow displays a transient inline label `tr("SETTINGS_CAPTURE_HINT")` resolving to *"Press a key to bind. Esc to cancel."* The label is AccessKit-announced on state entry (`accessibility_live = "polite"`) so screen-reader users hear the hint. Cleared on transition to NORMAL_BROWSE or CONFLICT_RESOLUTION.
- **Modifier silent data-loss prevention (NEW 2026-04-26 PM, REVISED 2026-04-27 — per ux-designer BLOCK-3 + Stage Manager fantasy register fix)**: at MVP F.4 ignores modifiers (keycode-only). When a captured `InputEventKey` has any of `shift_pressed / ctrl_pressed / alt_pressed / meta_pressed == true`, the RebindRow displays a transient inline label `tr("SETTINGS_MODIFIERS_DROPPED")` resolving to *"Modifier keys ignored. Bound as: {key_label}."* (REVISED: was *"aren't supported yet"* — "yet" implies a future promise that violates Stage Manager refusal #2 / forward-roadmap disclosure mid-rebind. New copy is neutral statement of current behavior.) The label persists for 4 seconds OR until next user input on the row, whichever comes first. AccessKit-announced as `accessibility_live = "assertive"`. Prevents silent intent loss. `{key_label}` is a tr-resolved string from a project-side keycode-to-display-name map (e.g., `tr("INPUT_KEY_F")` resolving to "F"); it is NOT the OS-locale-dependent `OS.get_keycode_string()` output (that returns OS-locale text, not game-locale text).
- `CONFLICT_RESOLUTION` shows an **inline banner** within the RebindRow (NOT a separate modal, BUT it modally-blocks other RebindRow capture buttons until resolved per Cluster E row 4): *"Conflict: {action_label} is already bound to this key. [Replace] [Cancel]"*. While CONFLICT_RESOLUTION is active, all other RebindRow capture buttons render with `disabled = true` AND `accessibility_description = "Resolve current conflict first"` so screen-reader and visual users both perceive the modal-block. Triple-encoded per accessibility-specialist (color + warning-triangle icon + text). AccessKit semantic on banner: `accessibility_role = "alert"`, `accessibility_live = "assertive"`.
- `{action_label}` is the **player-facing display name** of the conflicting action, resolved via `tr("INPUT_ACTION_NAME_<ACTION>")` — Input GDD owns the tr-key map per coord item OQ-SA-11 (REVISED 2026-04-27 to reference this tr() pattern as PRIMARY mechanism, not fallback; the previously-referenced `Input.get_action_display_name()` is an invented Godot 4.6 API that does not exist — see OQ-SA-11 revision). Falls back to the raw StringName (e.g., `"action_fire"`) ONLY if no tr-key is registered, and in that case the build is loc-defective per coord OQ-SA-11 (raw StringName in any shipped locale is a VS loc defect, never an acceptable runtime state).
- Conflict-detection scope: KB/M conflicts only checked against KB/M bindings; gamepad conflicts only checked against gamepad bindings (mixing causes false-conflicts since they're different input domains).

**AccessKit per-widget summary table (NEW 2026-04-26 PM — per accessibility-specialist F-1 + F-2):** the full per-widget contract lives at `design/ux/accessibility-requirements.md` (NEW BLOCKING coord — must be authored before implementation per OQ-SA-12). Inline summary below documents the role + name + live-region pattern for each widget class used in this Settings panel; the standalone UX doc adds keyboard-shortcut, focus-ring, and screen-reader-hint specifications per widget instance.

| Widget class | `accessibility_role` | `accessibility_name` source | `accessibility_description` source | `accessibility_live` | Notes |
|---|---|---|---|---|---|
| `HSlider` (volume / cooldown / sensitivity) | `"slider"` | `tr("<key>_LABEL")` (e.g., `MASTER_VOLUME_LABEL`) | `tr("<key>_DESC")` (e.g., *"Adjusts master output level. 0 percent is silent. 100 percent is full volume."*) | `"off"` (no live region) | Value is announced by AccessKit automatically via slider's value property. Re-resolve `accessibility_name` on `NOTIFICATION_TRANSLATION_CHANGED` per godot-specialist ADVISORY-2. |
| `CheckButton` (toggle) | `"switch"` | `tr("<key>_LABEL")` | `tr("<key>_DESC")` | `"off"` | State (on/off) announced by AccessKit via toggled property. |
| `OptionButton` (dropdown) | `"combobox"` | `tr("<key>_LABEL")` | `tr("<key>_DESC")` | `"off"` | Selected item announced via current item label; popup gets its own dialog role when open. |
| `Button` (Restore Defaults / Back / Keep Resolution / Revert / Show Notice) | `"button"` | `tr("<button_key>")` | (omit unless action is non-obvious from label) | `"off"` | |
| `RebindRow` (composite) | `"group"` on container; capture button is `"button"` with `accessibility_name = tr("REBIND_<ACTION>_LABEL") + " — " + current_binding_label` | composite name on container provides full context for screen reader | description on container: *"Press to rebind. Current: {key_label}."* | `"polite"` on container (announces when transient hint labels appear) | Composite pattern requires explicit role on container; child widgets inherit context from parent's accessibility_name. |
| `[Conflict]` inline banner | `"alert"` | resolved tr-string per CR-19 | (none) | `"assertive"` | Banner copy is the announcement. Clear `accessibility_live` after dismissal. |
| Photosensitivity warning modal (CR-18) | `"dialog"` | `tr("SETTINGS_PHOTOSENSITIVITY_WARNING_TITLE")` | the locked 38-word body (CR-18) | `"assertive"` | Modal scaffold owned by Menu System (CR-18 boundary). |
| `[Resolution Revert]` inline banner | `"alert"` | resolved tr-string per CR-15 | (banner copy) | `"assertive"` | Initial focus on `[Keep This Resolution]` button. |
| Restore Defaults confirmation modal (CR-25) | `"dialog"` | `tr("SETTINGS_RESTORE_CONFIRM_TITLE")` | `tr("SETTINGS_RESTORE_CONFIRM_BODY")` | `"assertive"` | Default focus on `[Cancel]`. |
| Category list (`ItemList`) | `"listbox"` | `tr("SETTINGS_CATEGORY_LIST_LABEL")` resolving to *"Settings categories"* | (none) | `"off"` | Each row announced as the category label string. |
| Cross-reference label in HUD sub-screen (`Label` for `crosshair_enabled` redirect) | `"link"` | `tr("HUD_CROSSHAIR_REDIRECT_LABEL")` | *"Activate to jump to Accessibility crosshair toggle"* | `"off"` | Non-interactive visually but Enter / A activates focus-redirect. |

---

### C.6 — Photosensitivity Boot-Warning Flow + Player-Initiated Review

Per CR-18 (boot-warning) + CR-24 (player-initiated review).

**Boot-warning sequence (per CR-18):**

1. **First launch** (no `settings.cfg` OR `accessibility.photosensitivity_warning_dismissed` key absent): SettingsService sets `_boot_warning_pending = true` during `_ready()`.
2. **Menu System #21's `_ready()`** polls this flag.
3. If `true`: display modal BEFORE the main menu becomes interactive (main menu render is gated on the modal closing).
4. Modal copy is the locked 38-word "Stage Manager"-register text.
5. Two buttons: **[Continue]** (default focus) — sets `accessibility.photosensitivity_warning_dismissed = true`, dismisses; **[Go to Settings]** — sets the dismissed flag, then opens Settings panel pre-navigated to Accessibility category with focus on `damage_flash_enabled` toggle.
6. Modal does NOT auto-dismiss. Modal is keyboard-navigable. AccessKit: `accessibility_role = "dialog"`, `accessibility_live = "assertive"` on appearance, focus moves into dialog.
7. Re-show condition: only if `settings.cfg` is deleted (e.g., player wipes user data). Save-data wipe / new-game does NOT re-show (the dismissed flag is in `settings.cfg`, not `SaveGame`). **Player-initiated re-review** is supported via the CR-24 button (see below) — does NOT require cfg deletion.

**Player-initiated review sequence (per CR-24 — NEW 2026-04-26 PM):**

1. Player navigates to Settings → Accessibility category.
2. The Accessibility sub-screen contains a **`[Show Photosensitivity Notice]` button** (see G.3 widget set) labeled `tr("SETTINGS_REVIEW_PHOTOSENSITIVITY_NOTICE")` resolving to *"Show Photosensitivity Notice"*.
3. Pressing the button immediately re-fires the same modal (reusing CR-18 scaffold) **without resetting the dismissed flag** — the boot-warning flow remains complete; this is purely a review path.
4. Modal copy is the same locked 38-word text. Same two buttons (**Continue** / **Go to Settings**), same default focus, same AccessKit semantics.
5. Closing the modal returns focus to the `[Show Photosensitivity Notice]` button in the Settings panel. Settings panel remains open; player resumes whatever they were doing.

**Modal copy translation constraint (NEW 2026-04-26 PM — per localization-lead BLK-2)**: the locked English copy is 38 words / ~220 characters. **Translator briefing constraint**: translated variants of `SETTINGS_PHOTOSENSITIVITY_WARNING_BODY` MUST fit within **300 characters** (≈150% English length, accommodates +30-40% German/Russian verbosity, +20% French). Modal `min_size = (480, 300)` (V.2 — height adjusted from 240 to 300 per this constraint to absorb translation slack). If a future locale exceeds 300 chars, the modal scaffold (Menu System owns) MUST switch to ScrollContainer-with-fixed-height layout. Translation QA gate: copy that exceeds the ceiling fails locale review.

**Boundary**: Settings owns the dismissed-flag persistence + the modal definition + the player-facing copy + the `[Show Photosensitivity Notice]` button + the player-initiated re-fire logic. Menu System owns the timing trigger (boot poll) + the modal scaffold node (rendered in both boot and player-initiated flows) + the focus-on-pre-game-state logic for the boot path.

---

### C.7 — Interactions Matrix (Settings ↔ all forward-dep GDDs)

| System | Direction | What flows | Coord item required |
|---|---|---|---|
| **HUD Core** | Settings → HUD | `setting_changed("hud", "hud_scale", _)` *(VS only)* + `setting_changed("accessibility", "crosshair_enabled" / "damage_flash_enabled" / "damage_flash_cooldown_ms", _)` *(crosshair now single-canonical-home in `accessibility` per 2026-04-26 PM revision)* + cross-reference label in HUD sub-screen redirecting to Accessibility | **HUD Core revision required**: rewire `_on_setting_changed` filter to listen on `accessibility` for `crosshair_enabled`, NOT `hud`; update HUD CR-15 cross-system contract |
| **Combat** | Settings → Combat | `setting_changed("accessibility", "crosshair_enabled" / "enhanced_hit_feedback_enabled" / "damage_flash_enabled" / "damage_flash_duration_frames" / "ads_tween_duration_multiplier", _)` + `("controls", "ads_is_toggle", _)` | **Combat must add `damage_flash_enabled` subscription** (suppress EHF pulse — CR-16); **Combat must declare max sustained automatic-fire RPM per weapon class** (CR-16 muzzle-flash WCAG 2.3.1 verification — NEW BLOCKING); **Combat must confirm or gate screen-shake + bloom-on-hit** under `damage_flash_enabled` (NEW BLOCKING) |
| **Audio** | Settings → Audio | `setting_changed("audio", "{bus}_volume_db" / "clock_tick_enabled", _)` | Audio §219+§642 already specifies subscription; satisfied |
| **Player Character** | Settings → PC | `setting_changed("controls", "mouse_sensitivity_x" / "mouse_sensitivity_y" / "gamepad_look_sensitivity" / "invert_y_axis" / "sprint_is_toggle" / "crouch_is_toggle", _)` + `("graphics", "resolution_scale", _)` for hands-outline | PC §AC-9.2 BLOCKED on this GDD; closes by CR-11 hardware default + CR-21 toggle inputs |
| **Outline Pipeline** | Settings → Outline | `setting_changed("graphics", "resolution_scale", _)` | Outline GDD §F already specifies; **NEW coord: Outline must expose `get_hardware_default_resolution_scale()` query for CR-11** |
| **Inventory & Gadgets** | Settings → Inventory | `setting_changed("accessibility", "haptic_feedback_enabled" / "gadget_ready_indicator_enabled", _)` | Inventory §UI-7 satisfied; **NEW coord: Input GDD must register `use_gadget` and `takedown` as separate actions per CR-22** |
| **Localization Scaffold** | Settings → Localization | `setting_changed("language", "locale", _)` (no-op at MVP per CR-13) | Localization scaffold satisfied; locale switcher graduates when 2nd locale ships |
| **Input** | Settings → Input | Direct `InputMap.action_erase_events()` + `action_add_event()` calls (NOT via `setting_changed` per CR-19) + `[controls]` ConfigFile subsection on disk | **NEW coord: Input GDD must document the rebind read pattern (Settings boots → reads [controls] → applies via InputMap → no setting_changed emit)** |
| **Menu System** | Menu → Settings | Menu's `_ready()` polls `SettingsService._boot_warning_pending` per CR-18 + Menu provides Settings entry-point + Menu provides modal scaffold for boot-warning | **NEW coord: Menu System GDD must be authored with this contract; OQ-SA-3** |

**Bidirectional consistency check** (every forward-dep above MUST list this GDD as inbound when their next revision lands):

| GDD | Currently lists Settings as forward-dep? | Action |
|---|---|---|
| HUD Core | ✅ Yes (REV-2026-04-26 D2 HARD MVP DEP) | No action |
| Combat | ✅ Yes (OQ-CD-12 ×7) | Combat next revision: confirm CR-16 EHF subscription |
| Audio | ✅ Yes (§Settings & Accessibility section) | No action |
| Player Character | ✅ Yes (§Forward dependencies) | PC next revision: close AC-9.2 stub |
| Outline Pipeline | ✅ Yes (§Settings & Accessibility integration) | Outline next revision: add `get_hardware_default_resolution_scale()` query API |
| Inventory & Gadgets | ✅ Yes (§UI-7 + OQ-INV-5) | Inventory next revision: confirm CR-22 separate-rebind |
| Localization Scaffold | ✅ Yes (locale switcher) | No action |
| Input | ✅ Yes (§UI rebinding) | Input next revision: register `use_gadget` + `takedown` separately + document rebind boot pattern |
| Menu System | N/A (Not Started) | Menu System GDD authoring must absorb CR-18 + Settings entry-point contract |

---

### C.8 — Forbidden Patterns (8 grep-enforceable rules)

**FP-1.** `Events.setting_changed.emit(` outside `src/core/settings/settings_service.gd` — sole-publisher violation.

**FP-2.** `ConfigFile.load("user://settings.cfg")` or `ConfigFile.save("user://settings.cfg")` outside `settings_service.gd` — sole-reader/writer violation.

**FP-3.** `SettingsService.get_value(` called from any consumer's `_ready()` — load-order race; consumers must use Consumer Default Strategy + `setting_changed` subscriber.

**FP-4.** Any setting key written to `SaveGame` (in `capture()` / `restore()` callbacks) — Settings persistence is strictly separate per ADR-0003.

**FP-5.** A `setting_changed` consumer's `_on_setting_changed` lacking the `if category != &"...": return` guard as its first statement — CR-5 violation.

**FP-6.** A `setting_changed` consumer's `match name:` block containing an `else:` clause — forward-compat violation.

**FP-7.** `setting_changed` emitted with `name == &"<rebind action>"` and `value` containing an `InputEvent` instance — CR-19 violation; rebinds must use the dedicated `[controls]` ConfigFile pathway.

**FP-8.** Settings panel widget label string assigned without `tr()` — ADR-0004 `hardcoded_visible_string` violation.

**FP-9 (NEW 2026-04-26 PM — per godot-specialist ADVISORY-6).** `await` keyword (or `call_deferred`) inside any `_on_setting_changed` handler — burst-emit re-entrancy violation. The CR-9 boot-time burst is synchronous; an awaiting consumer would suspend mid-burst, allowing other consumers to receive emits before the awaiting handler resumes. For photosensitivity-critical state updates this is a safety risk. Grep-enforceable: any `await` or `call_deferred(` inside the body of a function named `_on_setting_changed` is a build-blocking defect.

## Formulas

### F.1 — dB ↔ Percentage Volume Conversion

**Design decision:** Two-segment perceptual fader (industry standard from DAW software). Linear-in-dB rejected (50% → −40 dB feels inaudible to players); pure power-law rejected (50% → −6 dB wastes lower-half slider travel).

The slider [0%, 100%] splits at a knee point (75% / −12 dB):
- Segment A: [1%, 75%] linearly maps to [−24 dB, −12 dB]
- Segment B: [75%, 100%] linearly maps to [−12 dB, 0 dB]
- 0% → hard-silence sentinel −80 dB (never −∞)

**Forward (player slider → stored dB) — REVISED 2026-04-27 with explicit `is_nan()` guard (per systems-designer BLOCKING-3 + audio-director B-3):**

```
dB(p) =
  # IEEE 754 / GDScript NaN semantics: clamp(NaN, ...) returns NaN, NOT 0. Explicit is_nan() check required.
  PRECONDITION_1: p_sanitized = 0 if is_nan(p) else p   # explicit NaN rejection
  PRECONDITION_2: p_clamped = clamp(round(p_sanitized), 0, 100)  # rejects p < 0, p > 100, fractional

  IF p_clamped = 0:
    # Silence sentinel — F.1 stores -80.0 dB AND mutes the bus (defensive against DAC noise floor)
    AudioServer.set_bus_mute(bus_idx, true)
    RETURN -80.0
  ELSE:
    # Non-silent: ensure bus is unmuted (in case prior state was p=0)
    AudioServer.set_bus_mute(bus_idx, false)
    IF 1 ≤ p_clamped < 75:
      RETURN -24.0 + (p_clamped - 1) * (12.0 / 74.0)
    ELSE IF 75 ≤ p_clamped ≤ 100:
      RETURN -12.0 + (p_clamped - 75) * (12.0 / 25.0)
```

The `is_nan()` guard is non-optional: in Godot 4.6 GDScript (IEEE 754 float semantics), `clamp(NaN, ...)` returns NaN because NaN comparisons fail all branches; clamp then would not normalize to a valid value. The explicit pre-clamp NaN check normalizes NaN to 0 (silence sentinel — safest fallback). The mute call at p=0 is non-optional: -80.0 dB is below most consumer DAC noise floors but NOT below all DAC noise floors; deaf players using visual cues only AND shared-space players setting Master to 0% expect guaranteed silence, not faint audible output. Eliminates the undefined-output case for p ∈ {-1, 101, NaN, +∞} AND closes the silence-not-actually-silent gap.

**Inverse (stored dB → display percentage) — REVISED 2026-04-27 with explicit `is_nan()` guard + corrected default branch (per systems-designer BLOCKING-2 + BLOCKING-3):**

```
p(dB) =
  PRECONDITION_1: dB_sanitized = -80.0 if is_nan(dB) else dB    # explicit NaN rejection
  PRECONDITION_2: dB_clamped = clamp(dB_sanitized, -80.0, 0.0)  # rejects dB > 0, dB < -80, +∞

  IF dB_clamped ≤ -80.0:                       RETURN 0
  IF -80.0 < dB_clamped < -24.0:               RETURN 1   # below Segment A floor; reachable from hand-edited cfg with sub-Segment-A audible value (e.g., -50 dB) — return minimum AUDIBLE position, NOT silence sentinel
  IF -24.0 ≤ dB_clamped < -12.0:               RETURN 1 + (dB_clamped + 24.0) * (74.0 / 12.0)
  IF -12.0 ≤ dB_clamped ≤ 0.0:                 RETURN 75 + (dB_clamped + 12.0) * (25.0 / 12.0)
```

**Default-branch revision rationale (was `RETURN 0`, now `RETURN 1`)**: A hand-edited cfg with `master_volume_db = -50.0` is a value above the silence floor (-80 dB) and below Segment A's lowest audible (-24 dB at p=1). The previous `RETURN 0` mapped this to the silence-sentinel slider position, which (per the forward formula) ALSO mutes the bus — so a user with -50 dB (very quiet but audible) cfg-edit got total silence on display + mute. The corrected behavior: return p=1 (minimum audible slider position), which forwards to -24 dB (audible) and unmutes the bus. The user sees their slider at "1%" and gets quiet-but-audible playback, not silence. Inverse formula is self-contained — does NOT depend on undocumented upstream load-time clamping. A caller passing dB = +5.0 or NaN gets a defined output (clamp to ceiling/floor + valid branch).

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Slider percentage | `p` | int | [0, 100] | Player-facing slider position |
| Output decibels | `dB` | float | [−80.0, 0.0] | Written to `settings.cfg`; fed to `AudioServer.set_bus_volume_db()` |
| Segment A base | `SEGMENT_A_BASE` | float | −24.0 (locked) | dB value at p = 1 |
| Segment A slope | `SEGMENT_A_SLOPE` | float | 12.0/74.0 ≈ 0.1622 dB/% | dB rise per pct point in Segment A |
| Segment B base | `SEGMENT_B_BASE` | float | −12.0 (locked) | dB value at the knee p = 75 |
| Segment B slope | `SEGMENT_B_SLOPE` | float | 12.0/25.0 = 0.48 dB/% | dB rise per pct point in Segment B |
| Knee point | `p_knee` | int | 75 (tuning knob) | Segment A→B transition |
| Silence sentinel | `DB_FLOOR` | float | −80.0 (locked) | Stored dB at p = 0 |

**Output Range:** [−80.0, 0.0] dB (clamped, closed). Floor −80.0 because Godot AudioServer treats below ~−80 dB as inaudible and −∞ would NaN the inverse. Ceiling 0.0 dB is unity gain (no amplification). Outside-range values are clamped before write.

**Example:**
- p = 0 → −80.0 dB (silence sentinel)
- p = 50 → −24.0 + 49 × 0.1622 = **−16.05 dB** (perceived "moderately quiet")
- p = 75 → **−12.0 dB** (knee)
- p = 100 → −12.0 + 25 × 0.48 = **0.0 dB** (unity)
- Round-trip: dB = −16.05 → p = 1 + 7.95 × 6.167 = **50** ✓

**Edge cases at extremes:** p = 0 bypasses formula (sentinel route). Corrupted `settings.cfg` values outside [−80.0, 0.0] are clamped on load and self-healed (rewritten to disk).

---

### F.2 — Hardware-Default Resolution Scale Heuristic

```
hardware_default_resolution_scale(adapter_name) =
  0.75    if IS_INTEGRATED(adapter_name)
  1.0     if IS_DEDICATED(adapter_name)
  1.0     otherwise  (unknown / fallback)
```

**Sub-predicates** (all `String.contains()` on `adapter_name.to_lower()`):

```
IS_INTEGRATED(s) =
  s.contains("intel iris xe") OR
  s.contains("intel iris") OR
  s.contains("intel uhd") OR
  s.contains("intel hd") OR
  s.contains("amd radeon graphics") OR  # AMD APU integrated branding
  s.contains("apple m")                  # Apple Silicon (post-MVP-safe)

IS_DEDICATED(s) =
  s.contains("rtx") OR
  s.contains("gtx") OR
  s.contains("rx 6") OR
  s.contains("rx 7") OR
  s.contains("rx 5") OR
  s.contains("radeon rx") OR
  s.contains("arc a")                    # Intel Arc discrete
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| GPU adapter name | `adapter_name` | String | any (incl. `""`) | From `RenderingServer.get_video_adapter_name()` |
| Integrated predicate | `IS_INTEGRATED` | bool | {true, false} | Substring match against integrated GPU list |
| Dedicated predicate | `IS_DEDICATED` | bool | {true, false} | Substring match against discrete GPU list |
| Result | `result` | float | {0.75, 1.0} | Written to `graphics.resolution_scale` first launch only |

**Output Range:** Discrete {0.75, 1.0}. Heuristic is a conservative first-launch default — does NOT produce 0.5 or 0.6 (those are reserved for manual player selection only). Unknown hardware defaults to 1.0 (full quality) rather than degrading.

**Evaluation order:** `IS_INTEGRATED` checked first. Pathological string matching both predicates returns 0.75 (safer for hardware-uncertain case).

**Example:**
- `"Intel(R) Iris(R) Xe Graphics"` → contains `"intel iris xe"` → **0.75**
- `"NVIDIA GeForce RTX 3070"` → contains `"rtx"` → **1.0**
- `"AMD Radeon RX 6600 XT"` → contains `"rx 6"` → **1.0**
- `""` (empty string) → both false → **1.0** (fallback; logged warning)
- `"Llano"` (old AMD APU) → both false → **1.0** (fallback; player can lower manually)

**Edge cases at extremes:** Empty string → fallback 1.0 + log `[Settings] GPU name empty — defaulting resolution_scale to 1.0`. Outside-{0.5, 0.6, 0.75, 1.0} return path (future code edit) is clamped to nearest valid step before write.

**Discrete-step clamp on load (NEW 2026-04-26 PM — per systems-designer B5):** When SettingsService loads `settings.cfg` and reads `graphics.resolution_scale`, if the loaded value is not an exact element of the valid set `V = {0.5, 0.6, 0.75, 1.0}`, apply nearest-neighbor rounding:

```
clamp_to_valid_step(stored: float) -> float:
    valid_set = [0.5, 0.6, 0.75, 1.0]
    return min(valid_set, key=lambda v: abs(stored - v))
    # ties (e.g., 0.55 equidistant from 0.5 and 0.6) round DOWN per Python min stability
    # (lower value = safer for hardware-uncertain case)
    # values < 0.5 → 0.5; values > 1.0 → 1.0
```

After rounding, write the clamped value back to disk (self-heal per Cluster B) and log `[Settings] WARN: graphics.resolution_scale was {stored}; clamped to {valid}`. Eliminates the "corrupted cfg with `resolution_scale = 0.42`" undefined-behavior case.

---

### F.3 — Resolution-Revert Countdown

```
T_remaining(time_now, T_change_applied, T_revert_timeout) =
  clamp(T_revert_timeout - (time_now - T_change_applied), 0.0, T_revert_timeout)

display_seconds = ceil(T_remaining)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current time | `time_now` | float | [0.0, ∞) | `Time.get_ticks_msec() / 1000.0` |
| Change timestamp | `T_change_applied` | float | [0.0, ∞) | Recorded at last `resolution_scale` change in panel session |
| Revert timeout | `T_revert_timeout` | float | [5.0, 30.0] | Tuning knob; default **7.0 s** (per CR-15 revision 2026-04-26 PM; was 10.0; lowered per anchor-moment alignment — see G.7) |
| Time remaining | `T_remaining` | float | [0.0, T_revert_timeout] | Clamped to prevent negative |
| Banner display | `display_seconds` | int | [0, T_revert_timeout] | Banner reads "Reverting in N..."; uses `ceil` so banner shows 1 when <1 s remains |

**Output Range:** [0.0, T_revert_timeout] seconds (clamped). Reaches 0.0 exactly when timer elapses; auto-revert fires same frame.

**Refresh rate:** Banner connects to `Timer` with `wait_time = 1.0`, `one_shot = false`. On each `timeout` signal, banner reads `T_remaining` and updates `display_seconds`. NOT in `_process()` — 60 Hz redraws are wasteful for a 7-second countdown.

**Mid-timer re-trigger rule:** If player changes `resolution_scale` again while timer running:
1. Record **oldest unconfirmed value** as canonical revert target (the value before first unconfirmed change in panel session).
2. Cancel current timer; set `T_change_applied = time_now`.
3. New `T_revert_timeout`-second window from second change.
4. On revert (auto or manual), restore **oldest** value, not intermediate.

Prevents "laundering" an ugly resolution by changing twice quickly — revert always goes back to last confirmed value.

**Panel-close behavior — REVISED 2026-04-27 (close-as-confirm per CR-15 + AC-SA-11.10/11.11):**
- `T_remaining > 0` on close → **new value confirmed** (close-as-confirm). `ConfigFile.save()` fires synchronously, banner dismisses, timer is cancelled. Player's deliberate panel-close is the universal "I'm done" signal per CR-15 step 4.
- `T_remaining = 0` on close → timer already elapsed and confirmation already fired; no further action.
- **Auto-revert fires only on:** explicit `[Revert]` button press (CR-15 step 5). Timer-elapse-with-no-input is *also* a confirmation path per CR-15 step 4 (timer elapse confirms; auto-revert was the pre-revision behavior and has been replaced).
- See AC-SA-11.10 (close-as-confirm test) + AC-SA-11.11 (Keep button test) for verification contracts.

**Example:**
- `T_revert_timeout = 7.0`, `T_change_applied = 142.0`, `time_now = 144.3`
- `T_remaining = clamp(7.0 − 2.3, 0.0, 7.0) = 4.7 s`
- `display_seconds = ceil(4.7) = 5` → banner: "Confirming in 5..." (banner copy now reads as confirmation countdown, not revert countdown — see CR-15 + CR-26 for `SETTINGS_RESOLUTION_REVERT_PROMPT` tr-key revision).
- At `time_now = 149.0`: `T_remaining = 0.0` → confirmation fires (timer elapse path); banner dismisses; `ConfigFile.save()` writes new value.

**Edge cases at extremes:** Slow machine where frame delta is large may jump `T_remaining` from 1.2 to 0.0 in one Timer tick — clamp handles. `display_seconds = 0` is terminal state.

---

### F.4 — Rebind Conflict Detection Predicate

```
has_conflict(captured_event, target_action) =
  EXISTS action ∈ InputMap.get_actions() SUCH THAT ALL of:
    (1)  action ≠ target_action
    (2)  IS_USER_FACING(action)
    (3)  EVENT_MATCHES(captured_event, e)
         for some e ∈ InputMap.action_get_events(action)
    (4)  DEVICE_DOMAIN_MATCH(captured_event, e)
```

**Sub-predicates:**

```
IS_USER_FACING(action) =
  NOT action.begins_with("ui_")     # Godot reserved menu nav
  AND NOT action.begins_with("debug_") # Internal debug toggles
  AND NOT action.begins_with("editor_") # Editor internals (not at runtime)

EVENT_MATCHES(e_captured, e_existing) =
  [MVP — keycode-only]
  e_captured is InputEventKey AND e_existing is InputEventKey
    AND e_captured.keycode == e_existing.keycode
  OR e_captured is InputEventMouseButton AND e_existing is InputEventMouseButton
    AND e_captured.button_index == e_existing.button_index
  OR e_captured is InputEventJoypadButton AND e_existing is InputEventJoypadButton
    AND e_captured.button_index == e_existing.button_index
  OR e_captured is InputEventJoypadMotion AND e_existing is InputEventJoypadMotion
    AND e_captured.axis == e_existing.axis
    AND e_captured.axis_value * e_existing.axis_value > 0  # same half-axis direction
  [VS — modifier-aware] tuple-compare (keycode, shift_pressed, ctrl_pressed, alt_pressed)

DEVICE_DOMAIN_MATCH(e_captured, e_existing) =
  IS_KB_MOUSE(e_captured) == IS_KB_MOUSE(e_existing)

IS_KB_MOUSE(e) =
  e is InputEventKey OR e is InputEventMouseButton OR e is InputEventMouseMotion
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Captured event | `captured_event` | InputEvent | any valid | Recorded during CAPTURING state (key-up) |
| Action being rebound | `target_action` | StringName | valid InputMap action name | Excluded from conflict search |
| Candidate action | `action` | StringName | any InputMap action name | Iterated from `InputMap.get_actions()` |
| User-facing predicate | `IS_USER_FACING` | bool | {true, false} | Excludes `ui_*`, `debug_*`, `editor_*` |
| Event-match predicate | `EVENT_MATCHES` | bool | {true, false} | Same physical input (keycode-only at MVP) |
| Device-domain predicate | `DEVICE_DOMAIN_MATCH` | bool | {true, false} | Both events are KB+mouse OR both are joypad |
| Result | `has_conflict` | structured | {NO_CONFLICT, CONFLICT_WITH(action)} | Banner copy uses `conflicting_action` for label |

**Output:** `ConflictResult` — structured value, not bare bool:
```
ConflictResult = NO_CONFLICT | CONFLICT_WITH(conflicting_action: StringName)
```

UI uses `CONFLICT_WITH.conflicting_action` to render banner copy: *"This key is already bound to [Human-readable label]. Rebind anyway?"* Banner is inline (does not block input); two buttons: **Replace** (overwrites old action) and **Cancel** (returns to NORMAL_BROWSE without writing).

**Output Range:** Short-circuit EXISTS — returns on first match found. **REVISED 2026-04-26 PM (per systems-designer B4 + qa-lead AC-SA-6.4 flake risk)**: alphabetical sort is **MVP-required**, not deferred to VS. Implementation iterates `InputMap.get_actions()` and sorts the result alphabetically before applying the EXISTS short-circuit. This makes `has_conflict()` deterministic in CI tests and prevents AC-SA-6.4 flake. The sort cost is O(N log N) where N ≈ 30-50 actions — single-digit µs, negligible.

**Example:**
- Player rebinds `action_interact` and presses `E`.
- `get_actions() = ["ui_accept", "ui_cancel", "debug_toggle_ai", "action_fire", "action_interact", "action_move_forward", ...]`
- `"ui_accept"` → `IS_USER_FACING = false` → skip.
- `"debug_toggle_ai"` → `IS_USER_FACING = false` → skip.
- `"action_fire"` → `IS_USER_FACING = true`. Events = `[InputEventKey(keycode=KEY_E)]`. `EVENT_MATCHES(E, KEY_E) = true`. `DEVICE_DOMAIN_MATCH = true`. → **CONFLICT_WITH("action_fire")**.
- Banner: "E is already bound to Fire. Rebind anyway?"

**Edge cases at extremes:** `InputMap.get_actions()` returns empty list (engine misconfig) → `NO_CONFLICT` returned + log `[Settings] WARN: InputMap.get_actions() returned empty — conflict check skipped`. `captured_event` is `InputEventAction` (synthetic) → `EVENT_MATCHES` returns false in all branches; rebind proceeds. Synthetic events cannot be physically bound — should be filtered at capture-machine level before `has_conflict` runs.

## Edge Cases

38 cases across 10 clusters (A–J).

### Cluster A — First-launch / fresh-install behavior

- **If `user://settings.cfg` is absent**: populate from `settings_defaults.gd`, write synchronously, hardware-default detection runs once, `_boot_warning_pending = true`. Clean-install golden path.
- **If `ConfigFile.load()` returns non-OK error**: log warning, fall back to defaults, overwrite file. Player loses prior settings; game launches cleanly.
- **If schema mismatch (deprecated key from pre-release build)**: unknown keys silently ignored on read; pruned from disk on next write. Forward-compat behavior.
- **If filesystem read-only (chmod 444)**: load succeeds, burst fires, but write-throughs fail silently with log. Session functional; changes do not persist. Stage Manager does not interrupt for permission errors.
- **If file locked by another process (Windows exclusive lock)**: `ConfigFile.load()` returns error → ERR_FILE_CANT_OPEN branch → fallback to defaults.

### Cluster B — ConfigFile corruption / partial state

- **If numeric value out-of-range** (e.g. `master_volume_db = -200.0`): clamp to declared range on load, write back to disk (self-healing), no player-facing error.
- **If wrong type for key** (e.g. `master_volume_db = "loud"`): substitute default, write back, log warning. CR-7 type-guard at load time.
- **If entire category section missing**: populate all keys from `settings_defaults.gd`, write. Handles partial-update older-build case.
- **If unknown category section** (e.g. `[cheats]` from dev build): read into memory by ConfigFile but never emitted; pruned on next normal write.
- **If recognized key with `null` value**: `null is float` fails type guard → default substitution → key reset. Prevents `null` reaching consumer handlers.

### Cluster C — Boot-time burst order issues

- **If non-autoload consumer instantiated AFTER burst** (HUD scene, mid-game InventoryPanel): no retroactive replay. CR-6 Consumer Default Strategy is mandatory; consumer's hardcoded constants from `settings_defaults.gd` provide bridge value. **Divergence between consumer hardcoded default and `settings_defaults.gd` is the correctness risk** — code-review defect.
- **If consumer at slot 6/7 connects via `call_deferred`**: connect runs next frame, misses synchronous burst. Forbidden pattern: `call_deferred("connect", ...)` in slot-6/7 autoloads is rejected at code review.
- **If consumer node freed mid-burst**: `is_instance_valid(self)` guard at top of every `_on_setting_changed` handler. Consumer contract, not Settings-enforced.
- **If Events autoload fails to initialize**: `setting_changed.emit()` no-ops silently; game runs on hardcoded defaults. Higher-level architectural failure (Events fail = fatal at higher level).
- **If burst takes >2 ms** (hypothetical key explosion): MVP key counts (~20) bound burst in microseconds. VS profiling concern only; no throttling at MVP.

### Cluster D — Resolution-revert edge cases — REVISED 2026-04-27 (close-as-confirm propagation)

- **If panel closes while timer running, then reopens**: panel close fires **immediate confirmation** per CR-15 + AC-SA-11.10 — `ConfigFile.save()` writes the new value, timer is cancelled, banner dismisses. On reopen, panel shows the confirmed (new) value. No "pending change" state survives close-and-reopen — the close completed the transaction.
- **If quit-to-desktop (or OS kill) while timer running**: per CR-8, `resolution_scale` defers commit until confirmation (does NOT write-through during the mid-flow window). OS-kill before any confirmation path (close / Keep button / timer elapse) means **no value was persisted**; on next launch the previous confirmed value applies. **Residual risk** is therefore the opposite of pre-revision: a player who set 0.5 and OS-killed gets back their previous (presumably readable) resolution. Documented; the `resolution_scale_pending_confirmation` sentinel (OQ-SA-8 post-MVP) is no longer required for safety — it would only add finer-grained "did the player confirm" tracking.
- **If player selects same resolution_scale value (no-op change)**: SettingsService compares against current; equal = no write, no emit, no banner, no timer. Prevents spurious double-selection effects.
- **If player changes resolution_scale twice within `T_revert_timeout` window**: F.3 mid-timer rule — oldest unconfirmed value locked as canonical revert target; current timer cancelled, new `T_revert_timeout` window. On revert (explicit `[Revert]` press only — close + timer-elapse both confirm), restore oldest, not intermediate. Prevents laundering.
- **If SettingsService crashes mid-revert** (impossible in normal operation): Timer is child of SettingsService; freed with parent. No write occurred per CR-8 deferred commit; previous confirmed value persists on disk. No residual risk.

### Cluster E — Rebind capture state-machine edge cases

- **If two physical keys pressed simultaneously (chord)**: capture machine uses key-UP. First key-up bound + `set_input_as_handled()` consumes; second key-up discarded. Non-deterministic on simultaneous press; player can rebind if unsatisfied.
- **If player presses already-held key during CAPTURING**: held-key key-up fires when player releases — correct intended behavior. No special case.
- **If captured event from disconnected gamepad**: normalize device_id to -1 (any device) before InputMap write + cfg serialize. Prevents ghost bindings on different controllers. **Normalization rule**: all `InputEventJoypadButton/Motion` bindings stored with `device = -1`.
- **If conflict-resolution races with another CAPTURING start**: impossible — CAPTURING is modal; CONFLICT_RESOLUTION blocks all other RebindRow capture buttons until resolved. Single-threaded GDScript model + modal UI = no race.
- **If player presses Esc during CAPTURING**: `_input()` intercepts `ui_cancel` before panel close handler. Esc detected as cancel-capture intent → NORMAL_BROWSE without binding Esc. Panel does NOT close. Player must exit CAPTURING first.

### Cluster F — Locale change edge cases

- **If `tr()` returns key unchanged (missing translation)**: raw key string renders. Panel ugly but functional. Translation completeness is Localization Scaffold's AC, not Settings'.
- **If mid-cinematic locale change** (VS only — MVP-impossible per CR-13): Dialogue & Subtitles forward-dep contract; D&S decides its policy. Settings emits, doesn't buffer.
- **If stored locale code no longer supported**: validate against `TranslationServer.get_loaded_locales()` on load; fall back to `"en"`, write back, log warning. Not surfaced to player.
- **If `set_locale()` silently fails** (hypothetical 4.6 edge): no return value to check. Setting written; on next boot retry. Diagnosed by QA, not runtime logic.

### Cluster G — Photosensitivity warning lifecycle

- **If force-quit before dismissing modal**: dismissed flag NOT written. Re-shows on next launch. Correct safety behavior.
- **If `settings.cfg` deleted between launches**: dismissed flag absent. Re-shows. Documented intentional re-show condition.
- **If Menu System fails to render before showing modal**: `_boot_warning_pending` is runtime bool only; on next launch, flag re-evaluates from `settings.cfg` key absence. **Self-healing across crash restarts.**
- **If "Go to Settings" pressed but Settings panel fails to open**: dismissed flag already written before opening (C.6 step 5). Modal won't re-show; player can reach Settings via normal menu. Acceptable failure mode.

### Cluster H — Save/Load + new-game interactions

- **If new-game**: SaveGame wiped per ADR-0003; `settings.cfg` untouched. All settings persist across new-game starts. Photosensitivity warning does not re-show. Intended separation.
- **If only SaveGame deleted (not settings.cfg)**: `settings.cfg` survives; no warning re-show. Intended separation of concerns.
- **If both SaveGame and settings.cfg deleted simultaneously**: independent recovery paths; warning re-shows; full first-launch flow.
- **If future "Reset to Defaults" feature accidentally calls `ConfigFile.save()` directly**: FP-2 violation; grep-enforced at code review. Correct path is `SettingsService.reset_to_defaults()` method.

### Cluster I — Cross-system signal/value mismatch — REVISED 2026-04-27 (single-canonical-home propagation)

- **`crosshair_enabled` is single-canonical-home under `accessibility`**: SettingsService emits `setting_changed("accessibility", "crosshair_enabled", v)` exactly once per change. The `hud` category does **NOT** receive this key — emitting under `hud` is a CR-1 sole-publisher violation AND an FP-1 grep defect AND fails AC-SA-5.8 + AC-SA-9.1. Both HUD Core and Combat filter on `category == &"accessibility"` for this key. The HUD sub-screen renders only a non-interactive cross-reference label (focus-redirect to Accessibility — see C.2 single-canonical-home rule + C.5 widget table cross-reference-label row). *(Pre-revision dual-discovery dual-emit was abolished by CD ruling 2026-04-26 PM; this bullet replaces the former dual-emit prescription.)*
- **If consumer expects a key that was renamed**: `match name:` never matches; CR-5 forbids `else` branch → silent forward-compat degradation. **Resolution**: key renames require a migration pass in SettingsService (read old key, write new key, emit under new name) — GDD amendment + migration function.
- **If `settings_defaults.gd` has typo** (e.g. `damage_flash_on` vs `damage_flash_enabled`): consumer never matches. **Safety-critical for photosensitivity**. Mitigation: key names defined as `const KEY_DAMAGE_FLASH_ENABLED = &"damage_flash_enabled"` shared constants, NOT inline string literals. Integration test verifies emit-name == subscribe-name.

### Cluster J — Pillar 5 carve-out enforcement

- **If future contributor adds non-period-authentic default**: Pillar 5 carve-out is design-authoring gate, not runtime gate. `settings_defaults.gd` is enforcement surface; defaults reviewed against rule at GDD amendment. Any new modern-convenience default requires explicit creative-director ruling per Pillar 5 precedent.
- **If `setting_changed` payload contains moralizing string**: signal carries raw value (bool/float/int/StringName), NOT UI copy. Moralizing copy only possible in Settings panel labels (governed by FP-8 + locked 38-word photosensitivity copy). Caught at localization string review, not runtime.
- **If contributor adds `setting_changed` emit from within a consumer**: FP-1 violation. Correct pattern: compute derived value inside `_on_setting_changed`, update local state, OR request SettingsService store derived value. Consumer emitting `setting_changed` creates secondary publisher → breaks sole-publisher contract + EventLogger attribution. FP-1 grep enforces.

## Dependencies

### Upstream hard dependencies (Settings cannot function without)

| Dependency | What Settings consumes | Status | Risk |
|---|---|---|---|
| **Signal Bus / Events autoload (ADR-0002)** | `setting_changed` signal (sole publisher) + `settings_loaded` signal (NEW, BLOCKING) | ADR-0002 Proposed; **amendment required** for `settings_loaded` registration | BLOCKING |
| **SaveLoad / ADR-0003** | `user://settings.cfg` path convention; ConfigFile is separate from SaveGame; new-game does not wipe settings | ADR-0003 Proposed | None — Settings is sole owner of cfg per L168 |
| **InputContext autoload (ADR-0004)** | `Context.SETTINGS` enum value (already defined L192); push/pop modal lifecycle | ADR-0004 Proposed; 2 verification gates STILL OPEN (Gate 1 `accessibility_*` property names; Gate 2 `base_theme` vs `fallback_theme`) | BLOCKING |
| **ADR-0007 Autoload Load Order Registry** | Slot #8 registration | **Amendment required** (Settings becomes 8th autoload after Combat) | BLOCKING |
| **Input** | `InputMap` action catalog; default bindings; `InputMap.action_erase_events()` + `action_add_event()` API | Designed | Coord required (CR-22 separate `use_gadget`/`takedown` registration) |
| **Audio** | 5-bus structure + `AudioServer.set_bus_volume_db()` API + clock-tick consumer subscription pattern | Approved | None |
| **Outline Pipeline** | `get_hardware_default_resolution_scale()` query API (NEW per CR-11) | Designed pending review | Coord required (Outline must expose query) |
| **Localization Scaffold** | `tr()` mandate (FP-8) + `TranslationServer.set_locale()` for locale changes | Designed | None at MVP (English-only); coord on 2nd-locale ship |
| **ADR-0004 UI Framework** | Theme inheritance + AccessKit Day-1 (IG10) + `_unhandled_input` + `ui_cancel` modal dismiss + `tr()` mandate | Proposed | BLOCKING — 2 verification gates open |

### Soft dependencies (Settings enhanced by but works without)

- **EventLogger** (slot #2) — listens to all signal emits including `setting_changed`. Settings does not require EventLogger to function, but its absence loses audit trail.
- **PostProcessStack** (slot #6) — subscribes to `setting_changed("graphics", "resolution_scale", _)` to apply shader uniform. Settings does not enforce this subscription but expects it.

### Forward dependents (systems that depend on Settings)

| Dependent | Status | What flows | Coord status |
|---|---|---|---|
| **HUD Core** | APPROVED 2026-04-26 (REV-2026-04-26) | `setting_changed("hud", "crosshair_enabled" / "hud_scale")` + `("accessibility", "damage_flash_enabled" / "damage_flash_cooldown_ms")` | **Settings closes BLOCKING MVP DEP D2** |
| **Combat** | Approved 2026-04-22 | `setting_changed("accessibility", "enhanced_hit_feedback_enabled" / "damage_flash_enabled" / "damage_flash_duration_frames" / "ads_tween_duration_multiplier")` + `("controls", "ads_is_toggle")` | **NEW: Combat must add `damage_flash_enabled` subscription** to suppress EHF (CR-16) |
| **Audio** | Approved 2026-04-21 | `setting_changed("audio", "{bus}_volume_db" / "clock_tick_enabled")` | Satisfied per Audio §219 + §642 |
| **Player Character** | Approved 2026-04-21 | `setting_changed("controls", "mouse_sensitivity_x/y" / "gamepad_look_sensitivity" / "invert_y_axis" / "sprint_is_toggle" / "crouch_is_toggle")` + `("graphics", "resolution_scale")` for hands-outline | PC AC-9.2 BLOCKED on this GDD; closes by CR-11 + CR-21 |
| **Outline Pipeline** | Designed pending review | `setting_changed("graphics", "resolution_scale", _)` | NEW coord: must expose `get_hardware_default_resolution_scale()` per CR-11 |
| **Inventory & Gadgets** | Approved pending coord 2026-04-24 | `setting_changed("accessibility", "haptic_feedback_enabled" / "gadget_ready_indicator_enabled")` + separate `use_gadget`/`takedown` rebind support | Closes OQ-INV-5 + OQ-INV-6 (BLOCKING) |
| **Localization Scaffold** | Designed pending review | `setting_changed("language", "locale", _)` (no-op at MVP per CR-13) | Locale switcher graduates when 2nd locale ships |
| **Input** | Designed | Direct `InputMap.action_erase_events()` + `action_add_event()` calls (NOT via `setting_changed` per CR-19) + `[controls]` ConfigFile section on disk | NEW coord: must register `use_gadget`/`takedown` separately + document rebind boot pattern |
| **Menu System** | Not Started | Menu's `_ready()` polls `_boot_warning_pending` per CR-18; provides Settings entry-point + boot-warning modal scaffold | NEW BLOCKING coord (OQ-SA-3) |

### ADR dependencies

| ADR | Status | Settings requirement |
|---|---|---|
| ADR-0001 (Stencil ID) | Proposed | None (Settings doesn't render outlines directly) |
| ADR-0002 (Signal Bus Event Taxonomy) | Proposed | `setting_changed` (sole publisher) + `settings_loaded` (NEW — BLOCKING amendment) |
| ADR-0003 (Save Format Contract) | Proposed | `user://settings.cfg` separate from SaveGame; settings persistence boundary |
| ADR-0004 (UI Framework) | Proposed | Theme inheritance, AccessKit Day-1 (IG10), InputContext.SETTINGS, `tr()` mandate, modal dismiss pattern; **2 verification gates open** |
| ADR-0006 (Collision Layer Contract) | Proposed | None (Settings has no physics) |
| ADR-0007 (Autoload Load Order) | Proposed | **Slot #8 amendment BLOCKING** |
| ADR-0008 (Performance Budget) | Proposed | Settings claims 0 ms during gameplay; modal-only cost during settings panel display |

### Forbidden non-dependencies (Settings MUST NOT depend on)

1. **Stealth AI** — Settings has no perception or alert state; should never read `SAI.alert_state`.
2. **Combat (gameplay)** — Settings configures Combat behavior via `setting_changed`; never queries Combat's state directly. Forbidden: `Combat.is_in_combat()` calls from Settings.
3. **Player Character (gameplay)** — Settings persists PC's input multipliers but never reads PC's position/health/state.
4. **Mission/Level Scripting** — Settings is mission-agnostic; no `MissionState` reads.
5. **Failure & Respawn** — Settings is respawn-agnostic.
6. **Civilian AI** — N/A.
7. **Document Collection / Document Overlay** — Settings does not gate documents; Document Overlay uses InputContext.DOCUMENT_OVERLAY which is Settings-orthogonal.

### Bidirectional consistency check

| GDD | Lists Settings as forward-dep? | Action on next revision |
|---|---|---|
| HUD Core | ✅ Yes (REV-2026-04-26 D2 HARD MVP DEP) | No action — Settings closes the dep |
| Combat | ✅ Yes (OQ-CD-12 ×7) | Confirm CR-16 EHF subscription |
| Audio | ✅ Yes (§Settings & Accessibility section) | No action |
| Player Character | ✅ Yes (§Forward dependencies) | Close AC-9.2 stub |
| Outline Pipeline | ✅ Yes (§Settings & Accessibility integration) | Add `get_hardware_default_resolution_scale()` query API |
| Inventory & Gadgets | ✅ Yes (§UI-7 + OQ-INV-5) | Confirm CR-22 separate-rebind |
| Localization Scaffold | ✅ Yes (locale switcher) | No action |
| Input | ✅ Yes (§UI rebinding) | Register `use_gadget` + `takedown` separately + document rebind boot pattern |
| Menu System | N/A (Not Started) | Menu System GDD authoring must absorb CR-18 + Settings entry-point contract |

### Coord items rolled up — REVISED 2026-04-27 (14 BLOCKING + 4 ADVISORY; +2 BLOCKING from re-review)

**14 BLOCKING for sprint:**
1. ~~**ADR-0007 amendment** — register SettingsService at autoload slot #8~~ ✅ RESOLVED 2026-04-27 — ADR-0007 amended to register SettingsService per canonical registration table (end of block, after F&R + MLS); B2 from /review-all-gdds 2026-04-27 closed. Earlier slot-#8 misclaim corrected; consumers use `settings_loaded` one-shot pattern not `_ready()` reads, so end-of-block is safe.
2. **ADR-0002 amendment** — register `settings` domain + `settings_loaded` signal
3. **ADR-0004 Gate 1** — confirm Godot 4.6 `accessibility_*` property names (BLOCKING for AccessKit Day-1)
4. **ADR-0004 Gate 2** — confirm Theme inheritance property name (`base_theme` vs `fallback_theme`)
5. **Outline Pipeline coord** — expose `get_hardware_default_resolution_scale()` query API (CR-11)
6. **Combat coord** — add `setting_changed("accessibility", "damage_flash_enabled", _)` subscription that suppresses EHF pulse (CR-16); **AND declare max sustained automatic-fire RPM per weapon class** (CR-16 muzzle-flash WCAG verification — OQ-SA-9 NEW); **AND confirm or gate screen-shake + bloom-on-hit** under `damage_flash_enabled` (CR-16 NEW)
7. **Input GDD coord — REVISED 2026-04-27 (drop invented API)** — register `use_gadget` + `takedown` as two distinct InputMap actions WITH differentiated defaults (`use_gadget = KEY_F / JOY_BUTTON_Y`, `takedown = KEY_Q / JOY_BUTTON_X` per CR-22 revision) + document the rebind boot pattern (CR-19) + register `tr("INPUT_ACTION_NAME_<ACTION>")` tr-key per user-facing action (OQ-SA-11 — REVISED: was previously framed as `Input.get_action_display_name()` API which does NOT exist in Godot 4.6; mechanism is now the existing `tr()` pattern at point-of-use)
8. **Menu System GDD coord** — must read `_boot_warning_pending` flag during `_ready()` and provide modal scaffold for boot-warning (CR-18 / OQ-SA-3); same scaffold serves CR-24 player-initiated review path
9. **Combat weapon-roster muzzle-flash WCAG 2.3.1 verification — NEW (OQ-SA-9)** — confirm max RPM ≤3 Hz OR gate muzzle flashes
10. **Godot 4.6 dual-focus audit — NEW (OQ-SA-10)** — ui-programmer audit of `grab_focus()` call sites for mouse/touch focus separation
11. **`design/ux/accessibility-requirements.md` authoring — NEW (OQ-SA-12)** — full per-widget AccessKit contract spec; `/ux-design settings-accessibility` produces it
12. **HUD Core GDD revision** — rewire `_on_setting_changed` filter to listen on `accessibility` for `crosshair_enabled` (single-canonical-home revision); update HUD CR-15 cross-system contract; render cross-reference label only
13. **Audio GDD coord — NEW 2026-04-27 (OQ-SA-13)** — `clock_tick_enabled` category mismatch: Settings GDD now emits under `accessibility` category to match Audio GDD's existing handler at audio.md line 237. Audio GDD must re-validate its handler stays on `accessibility`. Cross-GDD coord per audio-director re-review B-4. *(Cross-document signal-contract integrity; was silent-runtime-failure pre-revision.)*
14. **Audio GDD 0 dB clipping risk coord — NEW 2026-04-27 (OQ-SA-14)** — six-bus 0 dB unity defaults guarantee output-stage clipping in peak combat scenes (Music + SFX + Voice + Ambient + UI peaking simultaneously). Audio GDD owner must resolve via either: (a) define a Master limiter `AudioEffect`, or (b) lower sub-bus defaults to `-3 dB` to `-6 dB` (industry practice). Settings G.1 defaults are TENTATIVE pending Audio GDD coord closure. Per audio-director re-review B-1 (upgraded from prior review's incorrect ADVISORY classification).

**4 ADVISORY:**
15. **PC GDD touch-up** — acknowledge Toggle-Sprint / Toggle-Crouch contract (CR-21)
16. **Localization Scaffold** — confirm locale-switcher graduation contract for VS (CR-13); document formal-address policy for translator briefing (BLK-1 advisory); RTL deferral note via `Control.layout_direction`; tr-key splitting for `SETTINGS_NAV_DEAD_END_TOP` / `SETTINGS_NAV_DEAD_END_BOTTOM` (NEW 2026-04-27 per re-review localization-lead NEW-1); accessibility description strings as separate translator briefing category (NEW 2026-04-27 per re-review localization-lead NEW-3); OptionButton item labels `tr()`-wrapped for resolution-scale items (NEW 2026-04-27 per CR-26 revision); `tr_n()` plural rule for revert banner countdown copy (NEW 2026-04-27)
17. **Inventory GDD** — acknowledge OQ-INV-5 closure (CR-22) and OQ-INV-6 closure (Settings owns rebind); CR-4 amendment for differentiated defaults
18. **CR-22 KEY_Q tentative pending Input GDD authoring** — NEW 2026-04-27 — game-designer re-review BLOCKING-4 flagged Q as left-hand QWERTY adjacent to WASD with conflict risk if Input GDD uses Q for lean / weapon-cycle / alt-fire. Mark CR-22 default as TENTATIVE; Input GDD review may revise. Soft-couple flagged.

## Tuning Knobs

Tuning knobs grouped by category. Settings is mostly a **persistence layer** — most "tuning" is the player's choice of value within a designer-specified range. The knobs below are the ranges, defaults, and safe boundaries the Settings UI exposes; the player is the tuner.

### G.1 — Audio category (6 knobs, all MVP) — REVISED 2026-04-27 (clock_tick_enabled moved to G.3 accessibility per cross-GDD coord with Audio GDD)

> **⚠ BLOCKING coord pending — see §F coord item #17 (Audio GDD 0 dB clipping risk).** All six bus defaults below are listed as `0.0 dB` (unity gain) but this risks output-stage clipping during peak combat scenes (Music + SFX + Voice + Ambient + UI all peaking at unity → Master sums above 0 dB → clipping). Industry practice is `-3 dB` to `-6 dB` sub-bus defaults with a Master limiter. **Audio GDD owns the resolution**: either (a) define a Master limiter `AudioEffect`, or (b) lower sub-bus defaults to `-3` / `-6 dB`. Settings GDD defaults below are TENTATIVE pending Audio GDD coord item #17 closure.

| Knob | Default | Safe range | Internal storage | Player display | Owner / source-of-truth |
|---|---|---|---|---|---|
| `audio.master_volume_db` | 0.0 dB *(tentative — see coord #17)* | [−80.0, 0.0] | float dB | 0–100% (F.1 fader) | Audio GDD (5 buses + Master) |
| `audio.music_volume_db` | 0.0 dB *(tentative — see coord #17)* | [−80.0, 0.0] | float dB | 0–100% (F.1 fader) | Audio GDD |
| `audio.sfx_volume_db` | 0.0 dB *(tentative — see coord #17)* | [−80.0, 0.0] | float dB | 0–100% (F.1 fader) | Audio GDD |
| `audio.ambient_volume_db` | 0.0 dB *(tentative — see coord #17)* | [−80.0, 0.0] | float dB | 0–100% (F.1 fader) | Audio GDD |
| `audio.voice_volume_db` | 0.0 dB *(tentative — see coord #17)* | [−80.0, 0.0] | float dB | 0–100% (F.1 fader) | Audio GDD |
| `audio.ui_volume_db` | 0.0 dB *(tentative — see coord #17)* | [−80.0, 0.0] | float dB | 0–100% (F.1 fader) | Audio GDD |

### G.2 — Graphics category (1 MVP knob + 2 reserved VS)

| Knob | Default | Safe range | Internal storage | Player display | Owner |
|---|---|---|---|---|---|
| `graphics.resolution_scale` | hardware-detected (F.2) | {0.5, 0.6, 0.75, 1.0} | float | OptionButton: "50% / 60% / 75% / 100%" | Outline Pipeline |
| `graphics.outline_thickness_multiplier` *(VS reserved)* | 1.0 | [0.5, 2.0] | float | slider | Outline Pipeline (future) |
| `graphics.glow_enabled` *(VS reserved — currently project-locked false per Art Bible 8J)* | `false` | {false} (locked) | bool | greyed-out toggle | PostProcessStack |

### G.3 — Accessibility category (6 MVP knobs + action button + 6 VS knobs) — REVISED 2026-04-27 (clock_tick_enabled added MVP)

| Knob | Default | Safe range | Phasing | Owner |
|---|---|---|---|---|
| `accessibility.damage_flash_enabled` | `true` | {true, false} | **MVP (HARD DEP for HUD Core)** | HUD Core / Combat |
| `accessibility.damage_flash_cooldown_ms` | 333 | [333, 1000] (333 SAFETY FLOOR) | **MVP** | Combat (locked floor) |
| `accessibility.crosshair_enabled` *(single canonical home — REVISED 2026-04-26 PM)* | `true` (opt-OUT) | {true, false} | **MVP** | Combat |
| `accessibility.photosensitivity_warning_dismissed` | `false` *(absent on first launch)* | {true, false, absent} | **MVP** | Settings (this GDD) |
| `[Show Photosensitivity Notice] button` *(NEW 2026-04-26 PM, CR-24; widget-only, not a stored key — listed here for UI completeness)* | n/a (action-only widget) | n/a | **MVP** | Settings (this GDD) |
| `accessibility.subtitles_enabled` | `true` (opt-OUT, WCAG SC 1.2.2) | {true, false} | **MVP-write / VS-consume** (CR-23 revised — key written at MVP, consumed when D&S ships) | Dialogue & Subtitles (consume); Settings (write) |
| `accessibility.subtitle_size_scale` *(NEW 2026-04-28 night — D&S Phase 2 propagation per dialogue-subtitles.md §C.10 + v0.3 D4)* | `1.0` (M) | discrete enum {`0.8` S / `1.0` M / `1.5` L / `2.0` XL} | **MVP-write / VS-consume** (mirror of `subtitles_enabled` phasing — written at MVP per WCAG SC 1.4.4 reflow floor, consumed when D&S ships) | Dialogue & Subtitles (consume); Settings (write + UI scale picker) |
| `accessibility.subtitle_background` *(NEW 2026-04-28 night — D&S Phase 2 propagation per dialogue-subtitles.md §C.10)* | `scrim` | enum {`none`, `scrim`, `opaque`} | **MVP-write / VS-consume** | Dialogue & Subtitles (consume); Settings (write + UI radio group) |
| `accessibility.subtitle_speaker_labels` *(NEW 2026-04-28 night — D&S Phase 2 propagation per dialogue-subtitles.md §C.10 + v0.3 D4 — UI toggle promoted from VS to MVP-Day-1)* | `true` | {true, false} | **MVP-write + MVP UI toggle** (v0.3 D4 — single accessibility-panel checkbox at MVP-Day-1 restores player agency without requiring full Settings UI revision deferred to VS) / **VS-consume** (D&S applies the toggle to caption rendering — anonymous-context PATROL_AMBIENT lines render unlabeled regardless per D&S CR-DS-15) | Dialogue & Subtitles (consume); Settings (write + UI checkbox) |
| `accessibility.subtitle_line_spacing_scale` *(NEW 2026-04-28 night — D&S Phase 2 propagation per dialogue-subtitles.md §C.10 + v0.2 — WCAG SC 1.4.12 Text Spacing)* | `1.0` | [1.0, 1.5] (≤1.5× per WCAG AA floor) | **MVP-write / VS-consume** | Dialogue & Subtitles (consume — applied via theme override on Courier monospace caption Label); Settings (write + UI slider) |
| `accessibility.subtitle_letter_spacing_em` *(NEW 2026-04-28 night — D&S Phase 2 propagation per dialogue-subtitles.md §C.10 + v0.2 — WCAG SC 1.4.12 Text Spacing)* | `0.0` em | [0.0, 0.12] em (≤0.12em per WCAG AA floor) | **MVP-write / VS-consume** | Dialogue & Subtitles (consume — applied via theme override on caption Label); Settings (write + UI slider) |
| **`audio.voice_overlay_duck_db`** *(forward-dep reference — owned by Audio §F Duck amounts L459; surfaced in Settings UI as "Voice ducking during reading"; NOT stored under Settings keys — Audio reads/applies)* | `−12.0` dB *(canonical — Audio-owned; v0.3 deepened from −6 dB to broadcast intelligibility floor per audio-director re-review)* | [−18.0, 0.0] dB | **MVP-Audio / VS-Settings-UI-surface** (Audio applies the duck on `document_opened` regardless of Settings UI; the optional Settings UI slider that exposes this is VS — playtest decision per dialogue-subtitles.md §F.6 P2 / OQ-DS-13 ADVISORY) | Audio (own + apply); Settings (UI surface, VS) |
| `accessibility.clock_tick_enabled` *(REVISED 2026-04-27 — moved from G.1 audio category to G.3 accessibility per cross-GDD coord with Audio GDD line 237; cognitive-load opt-OUT for ADHD/autism/anxiety players; Pillar 5 carve-out applies — period-authentic ambient sound is preserved as default but tunable for cognitive accessibility reasons; defaults to `true` per Audio GDD existing default)* | `true` (opt-OUT) | {true, false} | **MVP** | Audio GDD (consume); Settings (write + emit) |
| `accessibility.enhanced_hit_feedback_enabled` | `false` (opt-IN) | {true, false} | VS | Combat |
| `accessibility.gadget_ready_indicator_enabled` | `false` (opt-IN) | {true, false} | VS | Inventory |
| `accessibility.haptic_feedback_enabled` | `true` (opt-OUT) | {true, false} | VS | Inventory |
| `accessibility.damage_flash_duration_frames` | 1 | [1, 6] | VS | Combat |
| `accessibility.ads_tween_duration_multiplier` | 1.0× | [1.0, 3.0] | VS (vestibular) | Combat |
| `accessibility.high_contrast_ui_enabled` *(reserved)* | `false` | {true, false} | VS (post-MVP) | Settings (future) |

### G.4 — HUD category (1 MVP knob + 3 VS knobs)

| Knob | Default | Safe range | Phasing | Owner |
|---|---|---|---|---|
| Cross-reference label *(non-interactive; redirects to Accessibility → Crosshair — REVISED 2026-04-26 PM)* | n/a | n/a | **MVP** | Settings (label widget); Combat owns the actual `accessibility.crosshair_enabled` value |
| `hud.hud_scale` | 1.0 | [0.75, 1.5] | VS | HUD Core (OQ-HUD-1) |
| `hud.crosshair_dot_size_pct_v` | 0.19% | [0.15%, 0.30%] | VS | Combat |
| `hud.crosshair_halo_style` | `tri_band` | {none, parchment_only, tri_band} | VS | Combat |

### G.5 — Controls category (7 MVP knobs + rebinds)

| Knob | Default | Safe range | Phasing | Owner |
|---|---|---|---|---|
| `controls.sprint_is_toggle` | `false` (hold-to-press) | {true, false} | **MVP** (CR-21) | Settings (this GDD) |
| `controls.crouch_is_toggle` | `false` | {true, false} | **MVP** (CR-21) | Settings |
| `controls.ads_is_toggle` | `false` | {true, false} | **MVP** (CR-21) | Settings |
| `controls.mouse_sensitivity_x` | 1.0 | [0.1, 5.0] | **MVP** | Player Character |
| `controls.mouse_sensitivity_y` | 1.0 | [0.1, 5.0] | **MVP** | Player Character |
| `controls.gamepad_look_sensitivity` | 1.0 | [0.1, 5.0] | **MVP** | Player Character |
| `controls.invert_y_axis` | `false` | {true, false} | **MVP** | Player Character |
| `[controls]` ConfigFile section (rebinds) | per Input GDD default catalog | per InputMap action set | **MVP** (CR-19; separate from `setting_changed`) | Input GDD |
| `[controls].use_gadget` *(NEW — CR-22 differentiated default)* | KEY_F / JOY_BUTTON_Y | InputEvent | **MVP** | Input GDD |
| `[controls].takedown` *(NEW — CR-22 differentiated default)* | KEY_Q / JOY_BUTTON_X | InputEvent | **MVP** | Input GDD |

### G.6 — Language category (1 knob, dropdown hidden at MVP)

| Knob | Default | Safe range | Phasing | Owner |
|---|---|---|---|---|
| `language.locale` | `"en"` (dropdown hidden per CR-13) | per `TranslationServer.get_loaded_locales()` | MVP key persisted; dropdown VS | Localization Scaffold |

### G.7 — Internal Settings tuning knobs (designer-only, not player-facing)

| Knob | Default | Safe range | Description |
|---|---|---|---|
| `RESOLUTION_REVERT_TIMEOUT_SEC` | **7.0** *(REVISED 2026-04-26 PM — was 10.0; lowered per game-designer A-3 to align with "back in three seconds" anchor moment)* | [5.0, 30.0] | F.3 revert banner countdown duration. Designer tuning per CR-15. |
| `BURST_PROFILING_THRESHOLD_MS` *(VS reserved)* | 2.0 | [1.0, 5.0] | If burst takes longer, log warning. Diagnostic only. |
| `SEGMENT_A_BASE` (F.1 fader) | −24.0 dB | locked | dB at p=1; fader-curve constant. |
| `SEGMENT_B_BASE` (F.1 fader) | −12.0 dB | locked | dB at knee p=75; fader-curve constant. |
| `DB_FLOOR` (F.1 sentinel) | −80.0 dB | locked | Stored dB at p=0; never `-inf`. |
| `p_knee` (F.1 fader) | 75 | **locked** *(REVISED 2026-04-26 PM — was [50, 90] tuning range; locked per audio-director BLOCKING-A1, since changing p_knee requires rederiving SEGMENT_A_SLOPE + SEGMENT_B_SLOPE which are currently locked. Treat as a structural constant, not a runtime knob. To change, must update p_knee + recompute slopes via parameterized fader function in code.)* | Knee point percentage. Locked design constant. |

### G.8 — Ownership matrix

| Owner | Knobs |
|---|---|
| **Audio GDD** | All of G.1 |
| **Outline Pipeline GDD** | `graphics.resolution_scale` + reserved outline knobs (G.2) |
| **Combat GDD** | All flash + crosshair + EHF + ADS knobs (Combat-locked defaults) |
| **HUD Core GDD** | `hud.hud_scale` (VS) |
| **Inventory GDD** | Haptic + gadget-ready-indicator (G.3 VS) |
| **Player Character GDD** | Mouse/gamepad sensitivity + invert Y (G.5) |
| **Localization Scaffold GDD** | `language.locale` (G.6) |
| **Settings & Accessibility GDD (this)** | `controls.{sprint,crouch,ads}_is_toggle`, `accessibility.photosensitivity_warning_dismissed`, `RESOLUTION_REVERT_TIMEOUT_SEC`, F.1 fader curve constants |

## Visual/Audio Requirements

Settings has a deliberately **minimal** Visual/Audio surface. Most styling is delegated to ADR-0004 Theme inheritance; the system's distinctive contribution is what it **refuses** (no audio on interactions, no animation flourishes) per the Stage Manager fantasy.

### V.1 — Visual styling (delegated to ADR-0004 Theme)

All Settings panel widgets inherit from `project_theme.tres` per ADR-0004 IG6. Settings does NOT own widget visual specs; it owns layout (HSplitContainer per C.4) and per-widget AccessKit semantics. The visual register matches Menu System (when authored) — both use the same Theme.

**Locked visual rules** (enforced via Theme + per-section assertions):
- BQA Blue `#1B3A6B` 85%-opacity panel background (Art Bible §4.4)
- Parchment `#F2E8C8` text on background (≥4.5:1 contrast per WCAG 1.4.3)
- Futura Condensed Bold for category labels + slider labels (≥18 px floor per ADR-0004 FontRegistry)
- DIN Engschrift fallback below 18 px (FontRegistry.hud_numeral pattern)
- Alarm Orange `#E85D2A` for conflict-detection badge background only (triple-encoded with icon + text per accessibility-specialist). **Contrast verification required (NEW 2026-04-26 PM ADVISORY — per accessibility-specialist F-5)**: Alarm Orange against `#1B3A6B` 85%-opacity panel background composited on the dark game background must be calculated and documented. WCAG 1.4.11 Non-text Contrast requires ≥3:1 for UI element backgrounds; current spec asserts compliance without computation. Add measured ratio to Art Bible §4 or this GDD's V.1 before Settings sprint sign-off.
- Focus indicator: 2 px BQA Blue ring with shape-distinct corner cap (passes 3:1 per WCAG 1.4.11; reads under all 3 colorblind variants)

### V.2 — Layout footprint

- Modal panel positioned at viewport center with `min_size = (800, 600)` px (1080p) and `max_size = (1600, 1000)` px; scales proportionally to viewport
- HSplitContainer split position: 25% left (CategoryList) / 75% right (DetailPane)
- Revert banner (CR-15): inline at panel bottom, `min_size.y = 48 px`, full panel width
- Photosensitivity warning modal (CR-18 + CR-24): centered, `min_size = (480, 300)` px *(REVISED 2026-04-26 PM — was 240; raised to absorb +30-40% translation length slack per localization-lead BLK-2; 300 character ceiling for translated body)*. Same scaffold serves both boot-warning and player-initiated review (CR-24).
- Restore Defaults confirmation modal (CR-25): centered, `min_size = (480, 200)` px

### V.3 — Animation (forbidden patterns from §B refusals)

**Forbidden**:
- Animated transitions between category sub-screens (must be zero-frame swap)
- Animated check-mark flourishes on toggle state change
- Slide-in / fade-in entry of the Settings panel itself (instant render only)
- Pulse / glow on focused widget (focus indicator is static)
- Confetti / particle effects of any kind

**Allowed**:
- 1-frame focus-ring redraw on focus change (instant, not tweened)
- 1 Hz countdown text update on revert banner (the only time-varying visual)

### A.1 — Audio contracts (HUD bus only; minimal use)

Per §B refusal #5 (panel is silence-relative-to-the-game) + §H AC-SA-10.2/10.3 (no celebratory feedback / no slider-drag audio):

**Forbidden**:
- Soft-click on toggle press
- Slider-drag tick / scrubbing audio
- Confirmation tone on rebind capture
- Sting on Settings panel open or close
- "Accessibility ON" or "Apply complete" cue of any kind
- Period jazz score over the menu (the score ducks to silence per Audio §VO ducking on InputContext.SETTINGS push — confirm Audio's existing duck logic covers this; if not, this is a coord item)

**Allowed**:
- Audio bus-volume changes are AUDIBLE during slider drag — the player hears the actual game audio bus changing, NOT a UI feedback sound. This is the live preview itself, not a feedback chime.

### A.2 — Mix-bus assignment

Settings panel has no `AudioStreamPlayer` nodes; it does not produce audio. Any future Settings-originated UI audio (post-MVP) MUST route to `UI` bus per Audio §1 bus structure rule, never `Master`. Currently this is a non-concern — Settings is silent.

### A.3 — Coord item

Audio's existing VO-ducking math (`audio.md` §F.1) ducks Music + Ambient on `dialogue_line_started`. Confirm that opening the Settings panel does NOT trigger a duck (Settings produces no VO). If Audio decides Settings panel-open SHOULD duck game audio (so the player hears their slider changes more clearly), that's an Audio amendment, not a Settings change. Recommended default: NO duck on Settings open — game audio plays at its current bus volumes, and the player drags sliders to hear the effect on the live mix. Flagged as ADVISORY coord item.

### V.4 — Asset Spec Flag

**📌 Asset Spec** — Visual/Audio requirements are defined. After the Art Bible is approved, run `/asset-spec system:settings-accessibility` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

This GDD's UI is the entire game system — Settings IS a UI surface. Most UI specification lives in §C (modal architecture C.4, rebind state machine C.5, photosensitivity warning C.6). This section captures the meta-contract and forward-handoffs.

### UI-1 — Flow boundaries

| Concern | Owner |
|---|---|
| Settings entry-point in Pause menu / Main menu | **Menu System #21** (Not Started; OQ-SA-3 BLOCKING coord) |
| Settings panel itself — layout, navigation, widgets, focus model, AccessKit semantics | **This GDD** |
| Settings panel visual styling (Theme inheritance, fonts, colors) | **ADR-0004** (Theme) + Art Bible §7 + §4 (palette) |
| Photosensitivity boot-warning modal scaffold node | **Menu System #21** (provides the Control hierarchy; this GDD provides the copy + button behavior + dismissed-flag logic per CR-18) |
| Rebind UI for `use_gadget` / `takedown` separately | **This GDD** (CR-22 + Input GDD coord — register actions separately) |

### UI-2 — Accessibility floor (per accessibility-specialist §C consultation)

| Floor element | MVP commitment | Implementation surface |
|---|---|---|
| Keyboard-only navigation | Day-1 BLOCKING | All widgets reach focus via Tab + ui_up/ui_down/ui_left/ui_right (per C.4 focus model) |
| Gamepad-only navigation | Day-1 BLOCKING | Same focus model handles gamepad via existing ui_* InputMap actions |
| Screen reader (AccessKit) | Day-1 BLOCKING per ADR-0004 IG10 | Per-widget contract from accessibility-specialist (slider/toggle/dropdown/button/rebind-row/conflict-banner/modal — all with role + name + description + live region as specified) |
| WCAG 2.3.1 photosensitivity floor | Day-1 BLOCKING | 333 ms hard floor on `damage_flash_cooldown_ms` (CR-17 + AC-SA-5.2/5.3) + photosensitivity kill-switch gating BOTH HUD + EHF (CR-16 + AC-SA-5.1) + first-boot warning before main menu (CR-18 + AC-SA-5.4) |
| WCAG 1.4.1 (use of color) | Day-1 BLOCKING | Triple-encoding rule on conflict badge + focus indicator (per accessibility-specialist) |
| WCAG 1.4.3 (contrast) | Day-1 BLOCKING | All text ≥4.5:1; verified via Theme palette + composited-color testing |
| WCAG 1.4.4 (resize) | Day-1 ADVISORY | Container `SIZE_FILL` flags; verify at 200% zoom |
| Toggle-Sprint / Toggle-Crouch / Toggle-ADS | Day-1 MVP | CR-21 + AC-SA-6.1/6.2 |
| Separate `use_gadget` / `takedown` rebind | Day-1 MVP | CR-22 + AC-SA-6.3 |
| Subtitles default ON (when D&S ships) | VS BLOCKING | CR-23 + AC-SA-5.7 |
| HUD Core screen-reader | Polish per ADR-0004 IG10 | Settings does not own HUD a11y; HUD Core handles |

### UI-3 — InputContext lifecycle

```
[Player presses Esc / B in gameplay]
  → Menu System pushes InputContext.MENU
  → Player navigates to "Settings"
  → Menu System pushes InputContext.SETTINGS (this GDD)
  → Settings panel renders, gameplay paused, audio buses continue playing
  → [Player presses Esc / B / clicks Back]
  → InputContext.pop() back to MENU
  → Menu System renders main menu
  → [Player presses Resume]
  → InputContext.pop() back to GAMEPLAY
```

The double-pop (SETTINGS → MENU → GAMEPLAY) is correct — the player should land in the menu they came from. If the player opened Settings from main menu, the pop sequence is SETTINGS → MAIN_MENU (the MAIN_MENU context handled by Menu System).

### UI-4 — UX Flag

**📌 UX Flag — Settings & Accessibility:** This system has UI requirements that are the entire system. In Phase 4 (Pre-Production), run `/ux-design settings-accessibility` to create a UX spec covering:
- Visual mockups for each of the 6 sub-screens (Audio / Graphics / Accessibility / HUD / Controls / Language)
- Slider / toggle / dropdown / rebind-row widget mockups
- Photosensitivity boot-warning modal mockup
- Resolution-revert banner mockup
- Conflict-detection inline banner mockup

Stories that reference Settings UI should cite `design/ux/settings-accessibility.md`, not this GDD directly.

### UI-5 — Public API exposed to other systems

```gdscript
# Public query interface (read-only)
SettingsService.get_value(category: StringName, name: StringName) -> Variant
# Returns the current stored value. Consumers should NOT call this in _ready()
# (CR-6 / FP-3); it is for runtime queries by tools, debug overlays, and tests only.

# Public state inspection (boot warning)
SettingsService._boot_warning_pending: bool  # Read-only after _ready() completes
# Menu System polls this to decide whether to show the photosensitivity modal.
# Reset to false by the modal's Continue / Go-to-Settings button handlers.

# Signals (Settings is sole publisher per ADR-0002)
Events.setting_changed(category: StringName, name: StringName, value: Variant)
Events.settings_loaded()  # one-shot; no payload; emitted once after boot burst

# Public methods (Settings panel mount/dismiss + pre-navigation)
SettingsService.open_panel(pre_navigate: StringName = &"") -> void
# Mounts the Settings modal panel and pushes Context.SETTINGS per ADR-0004.
# Called by Menu System's Personnel File button (Menu CR-7) and by the
# photosensitivity boot-warning modal's "Go to Settings" button (Menu CR-8 +
# `design/ux/photosensitivity-boot-warning.md` Section B3).
#
# `pre_navigate` parameter format (LOCKED 2026-04-29 per `design/ux/photo-
# sensitivity-boot-warning.md` OQ #10): a dotted-string of the form
# "category.key" matching the §C.2 category-key namespace (e.g.,
# "accessibility.damage_flash_enabled" navigates to the Accessibility
# sub-screen with focus on the damage_flash_enabled toggle). Empty string
# (default) opens the Settings panel at its top-level entry without
# pre-navigation. The pre_navigate parameter is informational — the panel
# mounts even if the key is unknown (in which case it falls back to the
# top-level entry and logs a warning in debug builds).

SettingsService.dismiss_warning() -> bool
# Sets accessibility.photosensitivity_warning_dismissed = true and writes
# to disk synchronously. Returns true on success, false on disk-full or
# other I/O failure (per Menu System AC-MENU-6.4). Called by the photo-
# sensitivity boot-warning modal's Continue and Go-to-Settings button
# handlers (Menu CR-8). Idempotent — safe to call multiple times.
```

No other public methods exposed at MVP. Future additions (e.g., `reset_to_defaults()`, `export_settings()`, `import_settings()`) are deferred to post-VS.

## Acceptance Criteria

**REVISED 2026-04-27 (re-review revision pass)**: 65 ACs across 11 groups (52 BLOCKING / 13 ADVISORY). *(Was 49 BLOCKING / 16 ADVISORY at 2026-04-26 PM revision; net +3 BLOCKING from re-review reclassifications: AC-SA-5.3 [UI] ADVISORY → BLOCKING (WCAG 2.3.1 in-session UI floor), AC-SA-10.4 [UI] ADVISORY → [Integration] BLOCKING (modal non-auto-dismiss safety), AC-SA-11.7 [Logic] ADVISORY → BLOCKING (Tab order Day-1 keyboard nav per ADR-0004 IG10).* AC count unchanged at 65; revisions in-place to AC-SA-2.1 / 3.2 / 3.4 / 4.6 / 5.3 / 5.7 / 6.4 / 8.1 / 10.4 / 11.1 / 11.2 / 11.4 / 11.7 / 11.8 / 11.13. Earlier 2026-04-26 PM context: was 47 / 10 groups; net +18 ACs from prior revisions: AC-SA-5.7 split into 5.7a/5.7b/5.7c (+2), AC-SA-5.9 + AC-SA-5.10 review-again (+2), and new H.11 group with 14 ACs covering Restore Defaults, modifier feedback, Tab order, dead-end announce, slider drag perf, CR-22 differentiated defaults, CR-15 close-as-confirm + Keep button, F.1/F.2 clamp guards, FP-9 await CI gate.

### H.1 — Boot Lifecycle

- **AC-SA-1.1 [Logic] BLOCKING** **GIVEN** `user://settings.cfg` is absent on disk, **WHEN** `SettingsService._ready()` executes, **THEN** SettingsService populates all keys from `settings_defaults.gd`, writes `settings.cfg` synchronously, sets `_boot_warning_pending = true`, and completes without emitting a player-visible error. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
- **AC-SA-1.2 [Logic] BLOCKING** **GIVEN** `user://settings.cfg` is present but `ConfigFile.load()` returns a non-OK error code, **WHEN** `SettingsService._ready()` executes, **THEN** SettingsService logs exactly one `[Settings] ERR:` line, falls back to `settings_defaults.gd`, overwrites the file, and the burst phase fires using default values. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
- **AC-SA-1.3 [Logic] BLOCKING** **GIVEN** `user://settings.cfg` is present and valid, **WHEN** `SettingsService._ready()` executes, **THEN** rebinds are applied to `InputMap` before the first `setting_changed` burst emit fires (i.e., `_apply_rebinds()` completes before the first `Events.setting_changed.emit()` call in `_emit_burst()`). Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
- **AC-SA-1.4 [Logic] BLOCKING** **GIVEN** a valid `settings.cfg` with N non-controls key-value pairs, **WHEN** `_emit_burst()` runs, **THEN** exactly N `setting_changed` signals are emitted — one per `(category, name, value)` triple — and zero emits are made for the `[controls]` section. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
- **AC-SA-1.5 [Logic] BLOCKING** **GIVEN** the burst emit has completed, **WHEN** `SettingsService._ready()` reaches the final step, **THEN** `Events.settings_loaded` is emitted exactly once with no payload, and it is not emitted again during the same session. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
- **AC-SA-1.6 [Logic] BLOCKING** **GIVEN** `user://settings.cfg` is present but the `accessibility.photosensitivity_warning_dismissed` key is absent, **WHEN** `SettingsService._ready()` completes, **THEN** `SettingsService._boot_warning_pending` is `true`. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
- **AC-SA-1.7 [Logic] BLOCKING** **GIVEN** `user://settings.cfg` is present and `accessibility.photosensitivity_warning_dismissed` is `true`, **WHEN** `SettingsService._ready()` completes, **THEN** `SettingsService._boot_warning_pending` is `false`. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`

### H.2 — Persistence

- **AC-SA-2.1 [Logic] BLOCKING — REVISED 2026-04-26 PM** **GIVEN** the Settings panel is open and the player commits a value change, **WHEN** the commit event fires (`drag_ended` for HSlider with `value_changed == true`; `toggled` for CheckButton; `item_selected` for OptionButton; CAPTURING→NORMAL_BROWSE transition for RebindRow; explicit Keep / timer elapse for resolution_scale), **THEN** `ConfigFile.save("user://settings.cfg")` is called exactly once per commit event, synchronously, with no Apply button and no batching across multiple widgets. **AND** during continuous slider drag (between `drag_started` and `drag_ended`), `ConfigFile.save()` is NOT called for each `value_changed` tick — only `setting_changed` is emitted (for live-preview consumers like AudioServer). Evidence: `tests/unit/settings/persistence_test.gd` + frame-time test in `tests/performance/settings/slider_drag_frame_time_test.gd`
- **AC-SA-2.2 [Logic] BLOCKING** **GIVEN** a key-value pair has been written to `settings.cfg`, **WHEN** the file is reloaded in a fresh `ConfigFile` instance, **THEN** the retrieved value is byte-for-byte identical to the value that was written (round-trip fidelity for bool, int, float, String, and StringName types). Evidence: `tests/unit/settings/persistence_test.gd`
- **AC-SA-2.3 [Logic] BLOCKING** **GIVEN** `settings.cfg` contains `master_volume_db = -200.0` (out-of-range), **WHEN** SettingsService loads the file, **THEN** the value is clamped to `[-80.0, 0.0]`, written back to disk (self-heal), and no unclamped value reaches any consumer via `setting_changed`. Evidence: `tests/unit/settings/persistence_test.gd`
- **AC-SA-2.4 [Logic] BLOCKING** **GIVEN** `settings.cfg` contains `master_volume_db = "loud"` (wrong type), **WHEN** SettingsService loads the file, **THEN** the default value from `settings_defaults.gd` is substituted, written back to disk, and a `[Settings] WARN:` log line is emitted — no crash, no untyped value emitted. Evidence: `tests/unit/settings/persistence_test.gd`
- **AC-SA-2.5 [Logic] BLOCKING** **GIVEN** all six categories are present in `settings.cfg`, **WHEN** SettingsService loads the file, **THEN** every stored key uses two-part namespacing in the form `(category, name)` where `category ∈ {audio, graphics, accessibility, hud, controls, language}` — no global, un-namespaced keys exist. Evidence: `tests/unit/settings/persistence_test.gd`
- **AC-SA-2.6 [Integration] BLOCKING** **GIVEN** a running game session where `settings.cfg` is writable, **WHEN** the process is killed immediately after a slider change (OS-level SIGKILL), **THEN** on next launch the value written before the kill is present in `settings.cfg` (write-through guarantees durability up to the last successful `ConfigFile.save()` call). Evidence: `tests/integration/settings/persistence_durability_test.gd`
- **AC-SA-2.7 [Logic] BLOCKING** **GIVEN** `settings.cfg` exists and a new-game action is triggered (SaveGame wiped), **WHEN** the new-game flow completes, **THEN** `user://settings.cfg` is untouched: all prior settings survive the new-game wipe and `_boot_warning_pending` remains `false`. Evidence: `tests/unit/settings/persistence_test.gd`

### H.3 — Audio Settings

- **AC-SA-3.1 [Logic] BLOCKING** **GIVEN** a slider position `p` sampled at each of {0, 1, 50, 74, 75, 76, 100}, **WHEN** the F.1 forward formula is applied and then the inverse formula is applied to the result, **THEN** the round-trip value `p_recovered = inverse(forward(p))` equals `p` within ±0.5 integer percentage points for every sampled value. Evidence: `tests/unit/settings/audio_formula_test.gd`
- **AC-SA-3.2 [Logic] BLOCKING — REVISED 2026-04-27 (silence sentinel must mute, not just emit -80 dB per audio-director B-3)** **GIVEN** any audio bus slider is set to position `p = 0`, **WHEN** F.1 forward formula evaluates, **THEN** (a) `setting_changed("audio", "{bus}_volume_db", value)` fires with `value == -80.0` (silence sentinel, not `-inf` or `null`) AND (b) `AudioServer.set_bus_mute(bus_idx, true)` is called for that bus. Symmetrically, **GIVEN** the slider transitions from `p = 0` to any `p > 0`, **WHEN** F.1 evaluates, **THEN** `AudioServer.set_bus_mute(bus_idx, false)` is called BEFORE the volume is set, ensuring the bus is unmuted before the new volume applies. Evidence: `tests/unit/settings/audio_formula_test.gd` (verified via mock AudioServer call counter, not by listening for absence of audio).
- **AC-SA-3.3 [Integration] BLOCKING** **GIVEN** the Master bus slider is moved to `p = 75` in the Settings panel, **WHEN** the `setting_changed` burst reaches AudioServer's subscriber, **THEN** `AudioServer.get_bus_volume_db(0)` returns `-12.0 dB` (±0.01 dB tolerance) within the same frame. Evidence: `tests/integration/settings/audio_bus_apply_test.gd`
- **AC-SA-3.4 [Logic] ADVISORY — REVISED 2026-04-27 (category moved to `accessibility` per cross-GDD coord with Audio GDD)** **GIVEN** the `clock_tick_enabled` toggle is set to `false`, **WHEN** `setting_changed("accessibility", "clock_tick_enabled", false)` fires, **THEN** the Audio system's clock-tick bus mutes (verified via subscriber state, not by listening for absence of audio). Audio GDD's existing handler at audio.md line 237 already filters on `accessibility` category — Settings now emits with the same category. Evidence: `tests/unit/settings/audio_formula_test.gd`
- **AC-SA-3.5 [Logic] BLOCKING** **GIVEN** a corrupt `settings.cfg` with `master_volume_db = 9999.0`, **WHEN** SettingsService loads and applies, **THEN** the value clamped to `0.0 dB` is what reaches `AudioServer.set_bus_volume_db()` — no value above `0.0 dB` is ever passed. Evidence: `tests/unit/settings/audio_formula_test.gd`

### H.4 — Graphics Settings

- **AC-SA-4.1 [Logic] BLOCKING** **GIVEN** `settings.cfg` is absent (first launch) and `RenderingServer.get_video_adapter_name()` returns a string containing `"intel iris xe"`, **WHEN** `SettingsService._ready()` runs CR-11 hardware detection, **THEN** `graphics.resolution_scale` is written as `0.75` and `setting_changed("graphics", "resolution_scale", 0.75)` fires during burst. Evidence: `tests/unit/settings/graphics_test.gd`
- **AC-SA-4.2 [Logic] BLOCKING** **GIVEN** `settings.cfg` is absent and `RenderingServer.get_video_adapter_name()` returns `""` (empty string), **WHEN** CR-11 runs, **THEN** `graphics.resolution_scale` defaults to `1.0` and a `[Settings] GPU name empty` warning is logged. Evidence: `tests/unit/settings/graphics_test.gd`
- **AC-SA-4.3 [Integration] BLOCKING** **GIVEN** `resolution_scale` is set to `0.75` in the Settings panel and the revert timer elapses without player interaction, **WHEN** the Timer's `timeout` signal fires at `T_revert_timeout` seconds, **THEN** the new value `0.75` is confirmed, the revert banner dismisses, and `settings.cfg` retains `0.75`. Evidence: `tests/integration/settings/graphics_revert_test.gd`
- **AC-SA-4.4 [Logic] BLOCKING** **GIVEN** the resolution-revert banner is displayed with `T_remaining = 2.7 s`, **WHEN** the countdown formula `ceil(T_remaining)` is evaluated, **THEN** `display_seconds = 3` (banner reads "Reverting in 3..."). Evidence: `tests/unit/settings/graphics_test.gd`
- **AC-SA-4.5 [Logic] BLOCKING** **GIVEN** the player changes `resolution_scale` once (value A → B), then changes it again while the revert timer is running (B → C), **WHEN** the player presses the revert button, **THEN** the restored value is A (the oldest unconfirmed value), not B. Evidence: `tests/unit/settings/graphics_test.gd`
- **AC-SA-4.6 [UI] ADVISORY — REVISED 2026-04-27 (close-as-confirm per CR-15)** **GIVEN** the Settings panel is showing the Graphics sub-screen with the revert banner active, **WHEN** the player presses `ui_cancel` (Esc or B) to close the panel, **THEN** the panel closes, **the new value is confirmed** (NOT reverted), `ConfigFile.save()` writes the new value, and the timer is cancelled. This AC's MVP-BLOCKING coverage of the same behavior lives at AC-SA-11.10 (close-as-confirm test) and AC-SA-11.11 (Keep button test); AC-SA-4.6 remains as the manual UI-evidence walk-through complementing the automated tests. Evidence: `production/qa/evidence/settings-accessibility/graphics-panel-close-confirm.md` *(file renamed from graphics-panel-close-revert.md to reflect the inverted semantics)*

### H.5 — Accessibility Settings

- **AC-SA-5.1 [Integration] BLOCKING** **GIVEN** `accessibility.damage_flash_enabled` is set to `false`, **WHEN** the player takes damage in-game, **THEN** (a) HUD Core does NOT render the damage-flash numeral effect (CR-16 / HUD Core CR-7) AND (b) Combat does NOT render the Enhanced Hit Feedback pulse (CR-16 / Combat V.6) — both are suppressed by the single toggle, verified independently via subscriber state flags. Evidence: `tests/integration/settings/photosensitivity_kill_switch_test.gd`
- **AC-SA-5.2 [Logic] BLOCKING** **GIVEN** a manually-edited `settings.cfg` sets `accessibility.damage_flash_cooldown_ms = 100` (below the 333 ms WCAG safety floor), **WHEN** SettingsService loads the file, **THEN** the loaded value is clamped to `333`, written back to disk, and the value emitted in `setting_changed` is `333` — no sub-333 value reaches any consumer. Evidence: `tests/unit/settings/photosensitivity_floor_test.gd`
- **AC-SA-5.3 [UI] BLOCKING — REVISED 2026-04-27 (was ADVISORY; upgraded per accessibility-specialist B-2 + qa-lead BLOCKING-3 — UI clamp is the only in-session guard against live-preview WCAG 2.3.1 violations during slider drag, since the load-time clamp at AC-SA-5.2 does NOT cover values emitted via `setting_changed` during drag-not-yet-saved)** **GIVEN** the Accessibility sub-screen is rendered, **WHEN** the player inspects the `damage_flash_cooldown_ms` slider, **THEN** the slider `min_value` property is exactly `333` — it cannot be dragged below 333 ms via any UI interaction. Verification automatable via scene-loaded widget property query, NOT pixel inspection. Evidence: `tests/unit/settings/photosensitivity_floor_test.gd` (same file as AC-SA-5.2; both load-time + UI-time guards co-tested).
- **AC-SA-5.4 [Integration] BLOCKING** **GIVEN** `user://settings.cfg` has no `accessibility.photosensitivity_warning_dismissed` key (first launch), **WHEN** Menu System's `_ready()` runs after SettingsService, **THEN** the photosensitivity warning modal is displayed BEFORE the main menu becomes interactive (main menu input is blocked until modal is dismissed). Evidence: `tests/integration/settings/boot_warning_test.gd`
- **AC-SA-5.5 [Logic] BLOCKING** **GIVEN** the photosensitivity warning modal is visible, **WHEN** the player presses the "Continue" button, **THEN** `accessibility.photosensitivity_warning_dismissed = true` is written to `settings.cfg` synchronously and the modal dismisses — on the next launch, the modal does not re-appear. Evidence: `tests/unit/settings/photosensitivity_warning_test.gd`
- **AC-SA-5.6 [Logic] BLOCKING** **GIVEN** the photosensitivity warning modal is visible, **WHEN** the player presses the "Go to Settings" button, **THEN** (a) `accessibility.photosensitivity_warning_dismissed = true` is written before the Settings panel opens, and (b) the Settings panel opens pre-navigated to the Accessibility sub-screen with focus on the `damage_flash_enabled` toggle. Evidence: `tests/unit/settings/photosensitivity_warning_test.gd`
- **AC-SA-5.7 [Logic] BLOCKING — REVISED 2026-04-26 PM (split into MVP-write + VS-consume)** Two contracts, both enforceable independently per CR-23:
  - **AC-SA-5.7a [Logic] BLOCKING (MVP)**: **GIVEN** `accessibility.subtitles_enabled` key is absent from `settings.cfg` on first launch, **WHEN** SettingsService writes defaults at MVP, **THEN** `accessibility.subtitles_enabled` is written as `true` (opt-OUT default, WCAG SC 1.2.2) — it is never written as `false` on first launch, regardless of whether the Dialogue & Subtitles consumer ships at MVP or VS. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
  - **AC-SA-5.7b [Logic] BLOCKING (CI gate, MVP)**: **GIVEN** the full GDScript source tree, **WHEN** CI runs grep for any literal `accessibility.subtitles_enabled = false` or `subtitles_enabled = false` in `settings_defaults.gd` or any first-launch initialization path, **THEN** zero matches are found — the default-write of `true` is locked at the source level. Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
  - **AC-SA-5.7c [Integration] VS-BLOCKING (gated on D&S shipping)**: **GIVEN** Dialogue & Subtitles ships and a dialogue line is playing, **WHEN** `setting_changed("accessibility", "subtitles_enabled", false)` fires, **THEN** D&S's subtitle renderer hides — verified via D&S consumer state, not pixel inspection. Evidence: `tests/integration/dialogue/subtitles_setting_test.gd` *(deferred to D&S sprint)*
- **AC-SA-5.8 [Integration] BLOCKING — REVISED 2026-04-26 PM (single canonical home; was dual-discovery)** **GIVEN** the crosshair toggle is set to `false` in the Accessibility sub-screen, **WHEN** SettingsService processes the change, **THEN** `setting_changed("accessibility", "crosshair_enabled", false)` is emitted exactly once — and `setting_changed("hud", "crosshair_enabled", _)` is NEVER emitted (the `hud` category does not own this key). HUD Core's `_on_setting_changed` filter listens on category `accessibility` for `crosshair_enabled`; Combat's filter likewise. The HUD sub-screen renders only a cross-reference label that focus-redirects to Accessibility — pressing it does NOT emit any signal. Evidence: `tests/integration/settings/single_canonical_crosshair_test.gd` *(was: dual_discovery_crosshair_test.gd)*
- **AC-SA-5.9 [Logic] BLOCKING — NEW 2026-04-26 PM (CR-24)** **GIVEN** the Settings panel is open on the Accessibility sub-screen and `accessibility.photosensitivity_warning_dismissed = true` (already accepted), **WHEN** the player presses the `[Show Photosensitivity Notice]` button, **THEN** the photosensitivity warning modal re-fires with the locked CR-18 copy AND `accessibility.photosensitivity_warning_dismissed` remains `true` — pressing Continue or Go to Settings on the re-fired modal does NOT change the dismissed flag (the player's prior acceptance is preserved; this is a review path, not a re-acceptance flow). Evidence: `tests/unit/settings/photosensitivity_review_again_test.gd`
- **AC-SA-5.10 [UI] ADVISORY — NEW 2026-04-26 PM (CR-24)** **GIVEN** the player completes the player-initiated review flow (presses `[Show Photosensitivity Notice]` then dismisses the re-fired modal via Continue), **WHEN** the modal closes, **THEN** focus returns to the `[Show Photosensitivity Notice]` button in the Settings panel, the Settings panel remains open, and the player's prior cursor/scroll position in the Accessibility sub-screen is preserved. Evidence: `production/qa/evidence/settings-accessibility/review-again-flow.md`

### H.6 — Controls + Rebinding

- **AC-SA-6.1 [Integration] BLOCKING** **GIVEN** `controls.sprint_is_toggle` is changed to `true` in the Settings panel, **WHEN** `setting_changed("controls", "sprint_is_toggle", true)` fires, **THEN** Player Character's sprint handler switches to toggle-mode behavior within the same frame — no restart required. Evidence: `tests/integration/settings/toggle_controls_test.gd`
- **AC-SA-6.2 [Integration] BLOCKING** **GIVEN** `controls.ads_is_toggle` is set to `true`, **WHEN** `setting_changed("controls", "ads_is_toggle", true)` fires, **THEN** Combat's ADS handler switches to toggle-mode — verified via Combat's internal ADS state-machine query, not via player-visible rendering. Evidence: `tests/integration/settings/toggle_controls_test.gd`
- **AC-SA-6.3 [Logic] BLOCKING** **GIVEN** `use_gadget` and `takedown` are registered as two distinct InputMap actions (per CR-22), **WHEN** the player enters the rebind UI for `use_gadget` and captures a new key, **THEN** only the `use_gadget` action's binding changes — the `takedown` action's binding is unaffected. Evidence: `tests/unit/settings/rebind_isolation_test.gd`
- **AC-SA-6.4 [Logic] BLOCKING — REVISED 2026-04-26 PM** **GIVEN** a controlled InputMap fixture where ONLY `action_fire` is bound to `KEY_E` and `action_interact` is unbound, **WHEN** `has_conflict("action_interact", InputEventKey(keycode=KEY_E))` is evaluated against the fixture (with alphabetical sort applied per F.4 revision), **THEN** the predicate returns `CONFLICT_WITH("action_fire")` deterministically, and the inline conflict banner is shown (not a separate modal — see C.5 modal-block semantics). The alphabetical-sort guarantee is what makes this AC deterministic; without it, this AC would flake when multiple actions are bound to KEY_E. Evidence: `tests/unit/settings/rebind_conflict_test.gd` (test must construct an isolated InputMap fixture, not run against the live project InputMap, to keep test independence per CLAUDE.md test rules)
- **AC-SA-6.5 [Logic] BLOCKING** **GIVEN** the rebind capture machine is in CAPTURING state, **WHEN** the player releases a key (key-UP event), **THEN** that key-up event is used as the captured binding — a key-DOWN event does NOT trigger binding. Evidence: `tests/unit/settings/rebind_capture_test.gd`
- **AC-SA-6.6 [Logic] BLOCKING** **GIVEN** the rebind capture machine is in CAPTURING state, **WHEN** the player presses and releases `Esc`, **THEN** the machine transitions to NORMAL_BROWSE without binding `Esc`, and the Settings panel does NOT close. Evidence: `tests/unit/settings/rebind_capture_test.gd`
- **AC-SA-6.7 [Logic] BLOCKING** **GIVEN** a gamepad binding is captured during CAPTURING state, **WHEN** the `InputEventJoypadButton` is written to `settings.cfg`, **THEN** the serialized `device` field is `-1` (any device), not the physical device_id of the controller that was plugged in. Evidence: `tests/unit/settings/rebind_capture_test.gd`
- **AC-SA-6.8 [Logic] ADVISORY** **GIVEN** the locale is changed mid-session while a rebind banner is visible, **WHEN** `TranslationServer.set_locale()` runs, **THEN** the conflict-banner copy re-resolves via `tr()` in the new locale without requiring panel close/reopen. Evidence: `production/qa/evidence/settings-accessibility/rebind-locale-change.md`

### H.7 — Locale

- **AC-SA-7.1 [Logic] ADVISORY** **GIVEN** the Language sub-screen is opened at MVP, **WHEN** the player views the language options, **THEN** the sub-screen renders a single non-interactive `Label` containing `tr("LANGUAGE_MVP_NOTICE")` — no `OptionButton` or interactive dropdown is present. Evidence: `production/qa/evidence/settings-accessibility/locale-mvp-screen.md`
- **AC-SA-7.2 [Logic] ADVISORY** **GIVEN** a stored `language.locale` value that is not present in `TranslationServer.get_loaded_locales()`, **WHEN** SettingsService loads `settings.cfg`, **THEN** the locale falls back to `"en"`, the corrected value is written back to disk, and a `[Settings] WARN:` log line is emitted — no crash, no non-English locale applied. Evidence: `tests/unit/settings/locale_test.gd`
- **AC-SA-7.3 [Integration] ADVISORY** **GIVEN** a second locale is shipped and the dropdown is enabled (VS), **WHEN** the player selects a new locale from the `OptionButton`, **THEN** `TranslationServer.set_locale()` fires within the same frame, all visible `tr()` strings in the Settings panel re-resolve in the new locale, and `setting_changed("language", "locale", new_code)` is emitted. Evidence: `tests/integration/settings/locale_change_test.gd`

### H.8 — Cross-System Signal Contracts

- **AC-SA-8.1 [Integration] BLOCKING — REVISED 2026-04-26 PM (consolidated with AC-SA-5.8 under single-canonical-home model)** **GIVEN** the crosshair toggle is changed to any value `v`, **WHEN** SettingsService processes the change, **THEN** `setting_changed("accessibility", "crosshair_enabled", v)` fires exactly once. HUD Core AND Combat both receive the `accessibility`-category emit and update to `v`. Cross-tested with AC-SA-5.8: same observable, two consumer perspectives. Evidence: `tests/integration/settings/single_canonical_crosshair_test.gd` (shared with AC-SA-5.8)
- **AC-SA-8.2 [Integration] BLOCKING** **GIVEN** `accessibility.damage_flash_enabled` is set to `false`, **WHEN** Combat's `_on_setting_changed` handler fires, **THEN** Combat's internal EHF-suppression flag is set such that no EHF pulse renders on the next `damage_taken` event — verified by querying Combat's post-damage render state flag, not audio or pixel output. Evidence: `tests/integration/settings/photosensitivity_kill_switch_test.gd`
- **AC-SA-8.3 [Integration] BLOCKING** **GIVEN** `controls.mouse_sensitivity_x` is changed to `2.5`, **WHEN** `setting_changed("controls", "mouse_sensitivity_x", 2.5)` fires, **THEN** Player Character's look-sensitivity multiplier updates to `2.5` within the same frame — no restart, no deferred apply. Evidence: `tests/integration/settings/pc_sensitivity_test.gd`
- **AC-SA-8.4 [Integration] BLOCKING** **GIVEN** `graphics.resolution_scale` is confirmed (timer elapsed), **WHEN** the `setting_changed("graphics", "resolution_scale", v)` burst or live emit fires, **THEN** PostProcessStack (Outline Pipeline) applies the new scale to its shader uniform within the same frame. Evidence: `tests/integration/settings/outline_resolution_test.gd`
- **AC-SA-8.5 [Logic] BLOCKING** **GIVEN** SettingsService has completed its `_ready()`, **WHEN** any consumer inspects the `Events.settings_loaded` signal, **THEN** the signal has fired exactly once since engine boot — it is not re-emitted on Settings panel open/close, on scene change, or on any subsequent `setting_changed` emit. Evidence: `tests/unit/settings/boot_lifecycle_test.gd`
- **AC-SA-8.6 [Integration] BLOCKING** **GIVEN** a consumer autoload (e.g. Combat) connects to `setting_changed` in its own `_ready()`, **WHEN** SettingsService fires its burst at end-of-block per ADR-0007 (amended 2026-04-27) canonical registration table, **THEN** the consumer's `_on_setting_changed` handler is invoked synchronously for every burst emit — there is no frame gap between burst emit and consumer application. Evidence: `tests/integration/settings/burst_consumer_order_test.gd`

### H.9 — Forbidden Patterns CI Gates

These ACs map one-to-one to FP-1..FP-8 (§C.8). Each is verified by a grep-based CI static-analysis step, not by GUT runtime.

- **AC-SA-9.1 [Logic] BLOCKING** **GIVEN** the full GDScript source tree under `src/`, **WHEN** CI runs grep for `Events.setting_changed.emit(` anywhere outside `src/core/settings/settings_service.gd`, **THEN** zero matches are found — any match is a build-blocking defect (FP-1: sole-publisher violation). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
- **AC-SA-9.2 [Logic] BLOCKING** **GIVEN** the full GDScript source tree, **WHEN** CI runs grep for `ConfigFile.load("user://settings.cfg")` OR `ConfigFile.save("user://settings.cfg")` outside `settings_service.gd`, **THEN** zero matches are found (FP-2: sole-reader/writer violation). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
- **AC-SA-9.3 [Logic] BLOCKING** **GIVEN** the full GDScript source tree, **WHEN** CI runs grep for `SettingsService.get_value(` inside any consumer `_ready()` function body, **THEN** zero matches are found — consumers must use the Consumer Default Strategy, not synchronous queries at `_ready()` (FP-3: load-order race). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
- **AC-SA-9.4 [Logic] BLOCKING** **GIVEN** all `SaveGame` capture/restore callback implementations, **WHEN** CI runs grep for any `settings.cfg` key name (e.g., `"master_volume_db"`, `"damage_flash_enabled"`) inside `save_game.gd` capture/restore methods, **THEN** zero matches are found — settings keys must never appear in SaveGame payloads (FP-4: persistence boundary violation). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
- **AC-SA-9.5 [Logic] BLOCKING** **GIVEN** every `_on_setting_changed` function in the codebase, **WHEN** CI static-analysis checks the first executable statement of each function, **THEN** every function's first statement is `if category != &"<category_name>": return` — functions missing this guard are build-blocking defects (FP-5: missing category filter). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
- **AC-SA-9.6 [Logic] BLOCKING** **GIVEN** every `match name:` block inside an `_on_setting_changed` function, **WHEN** CI static-analysis scans each match block, **THEN** zero `else:` clauses are found — any `else:` is a build-blocking defect (FP-6: forward-compat violation). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
- **AC-SA-9.7 [Logic] BLOCKING** **GIVEN** any call to `Events.setting_changed.emit(`, **WHEN** CI inspects the third argument (`value`) for `InputEvent` subclass instances, **THEN** zero such calls are found — rebind events must flow through the `[controls]` ConfigFile pathway only (FP-7: InputEvent-in-signal violation). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`
- **AC-SA-9.8 [Logic] BLOCKING** **GIVEN** all Settings panel widget label assignments in `src/`, **WHEN** CI runs grep for string literals assigned to widget label properties without a `tr()` wrapper, **THEN** zero bare-string label assignments are found — all player-visible strings must pass through `tr()` (FP-8: hardcoded visible string violation). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`

### H.10 — Pillar 5 / Stage Manager Defaults

- **AC-SA-10.1 [Config] ADVISORY** **GIVEN** a clean first-launch `settings.cfg` generated from `settings_defaults.gd`, **WHEN** the defaults file is inspected, **THEN** all modern-convenience features (`enhanced_hit_feedback_enabled`, `gadget_ready_indicator_enabled`) are `false` (opt-IN), and all period-authentic defaults (`crosshair_enabled = true` by Combat ruling, `clock_tick_enabled = true`, all volumes at 0 dB) match their declared values in §G — no default is a modern accommodation unless explicitly ruled by Creative Director. Evidence: `production/qa/evidence/settings-accessibility/defaults-pillar5-audit.md`
- **AC-SA-10.2 [UI] ADVISORY** **GIVEN** any accessibility toggle (e.g., `damage_flash_enabled`, `subtitles_enabled`) is switched on or off in the Settings panel, **WHEN** the toggle state changes, **THEN** no congratulatory feedback plays — no sound effect, no animation, no copy ("Accessibility ON" or equivalent), no signal beyond the bare `setting_changed` emit. Evidence: `production/qa/evidence/settings-accessibility/no-celebratory-feedback.md`
- **AC-SA-10.3 [UI] ADVISORY** **GIVEN** an audio volume slider is dragged in the Settings panel, **WHEN** the slider value changes continuously, **THEN** no UI sound effect plays during dragging — audio feedback on slider drag is forbidden per Stage Manager refusal #2 (the player hears the bus-volume change itself, nothing else). Evidence: `production/qa/evidence/settings-accessibility/slider-drag-no-audio.md`
- **AC-SA-10.4 [Integration] BLOCKING — REVISED 2026-04-27 (was [UI] ADVISORY; upgraded per qa-lead ADVISORY-3 + WCAG 2.3.1 safety chain)** **GIVEN** the photosensitivity warning modal is displayed at boot, **WHEN** the modal is visible, **THEN** the modal does not auto-dismiss after any timeout — it remains blocking until the player explicitly presses "Continue" or "Go to Settings". A photosensitive player must read and consent to the warning; auto-dismiss would mean a player never seeing the full safety notice (medical-onset risk). Verification: integration test polls the modal visibility for 30+ seconds and asserts no state change without input. Evidence: `tests/integration/settings/boot_warning_test.gd` (same file as AC-SA-5.4).
- **AC-SA-10.5 [Config] ADVISORY** **GIVEN** the resolution_scale hardware-default detection (F.2) runs on an unknown GPU adapter string, **WHEN** `IS_INTEGRATED` and `IS_DEDICATED` both evaluate to `false`, **THEN** the default is `1.0` (full quality) — the system never penalizes unknown hardware by defaulting to a degraded resolution. Evidence: `production/qa/evidence/settings-accessibility/defaults-pillar5-audit.md`

### H.11 — Restore Defaults + UX-Specifics (NEW 2026-04-26 PM revision)

- **AC-SA-11.1 [Logic] BLOCKING — REVISED 2026-04-27 (CR-25 photosensitivity safety cluster)** **GIVEN** the player presses `[Restore Defaults]` and confirms in the modal, **WHEN** SettingsService processes the reset, **THEN** every key matches the value in `settings_defaults.gd` (with `graphics.resolution_scale` re-derived via CR-11 hardware detection) **EXCEPT** the three preserved photosensitivity safety cluster keys (see AC-SA-11.2), `setting_changed` is emitted for every reset key (and re-emitted at preserved values for the cluster keys), and consumers update without restart. Evidence: `tests/unit/settings/restore_defaults_test.gd`
- **AC-SA-11.2 [Logic] BLOCKING — REVISED 2026-04-27 (CR-25 photosensitivity safety cluster, was dismissed-flag-only)** **GIVEN** the player has set `accessibility.photosensitivity_warning_dismissed = true`, `accessibility.damage_flash_enabled = false`, and `accessibility.damage_flash_cooldown_ms = 1000` before Restore Defaults is invoked, **WHEN** the reset completes, **THEN** all three photosensitivity safety cluster keys retain their pre-reset values: dismissed = true, damage_flash_enabled = false, damage_flash_cooldown_ms = 1000 — the cluster is exempt from the defaults reset because photosensitivity-related settings are tuned for medical reasons, not aesthetic preference, and survive convenience actions. Verified per-key (3 separate assertions). Evidence: `tests/unit/settings/restore_defaults_test.gd`
- **AC-SA-11.3 [Logic] BLOCKING — NEW (CR-25)** **GIVEN** Restore Defaults emits its full burst, **WHEN** consumers receive emits, **THEN** `Events.settings_loaded` is NOT re-emitted — `settings_loaded` is one-shot per session per AC-SA-1.5; a defaults-reset burst is not a fresh boot. Evidence: `tests/unit/settings/restore_defaults_test.gd`
- **AC-SA-11.4 [UI] ADVISORY — REVISED 2026-04-27 (CR-25 confirmation modal copy reflects cluster-rule)** **GIVEN** the Restore Defaults confirmation modal is visible, **WHEN** the modal renders, **THEN** default focus is on `[Cancel]` (the safer non-destructive choice), the modal does not auto-dismiss, and the modal's body text reads *"Restore all settings to defaults? Your photosensitivity preferences will be preserved."* (plural "preferences" — accurately describes the 3-key cluster preservation per CR-25 step 2). Evidence: `production/qa/evidence/settings-accessibility/restore-defaults-modal.md`
- **AC-SA-11.5 [UI] BLOCKING — NEW (modifier feedback per ux-designer BLOCK-3)** **GIVEN** the player is in CAPTURING state on a RebindRow, **WHEN** the player presses any key with a modifier held (Shift / Ctrl / Alt / Meta), **THEN** the captured binding records only the keycode (no modifier), the RebindRow displays a transient inline label *"Modifier keys aren't supported yet. Bound as: {key_label}."* for 4 seconds, AND the label is announced via AccessKit `accessibility_live = "assertive"`. Evidence: `tests/integration/settings/rebind_modifier_feedback_test.gd`
- **AC-SA-11.6 [Performance] ADVISORY — NEW (CR-8 perf gate per performance-analyst)** **GIVEN** the Settings panel is open and the player drags any HSlider continuously for 1.0 second on min-spec hardware (Iris Xe baseline, Linux ext4 SSD), **WHEN** frame times are sampled at 60 Hz throughout the drag interaction, **THEN** no single frame exceeds 16.6 ms (the panel maintains 60 fps; no perceptible slider-drag stutter). Evidence: `tests/performance/settings/slider_drag_frame_time_test.gd`
- **AC-SA-11.7 [Logic] BLOCKING — REVISED 2026-04-27 (was ADVISORY; upgraded per qa-lead ADVISORY-4 — Tab order is fundamental keyboard navigation and Day-1 BLOCKING per ADR-0004 IG10 + UI-2 floor table)** **GIVEN** keyboard focus is on a widget within the detail pane, **WHEN** the player presses Tab repeatedly, **THEN** focus cycles through ONLY the detail pane widgets (does not cross to the category list), wraps from last-to-first widget, and Shift+Tab reverses direction. The category list is reached only via `ui_left`. Test is automatable via focus-chain inspection (no pixel inspection required). Evidence: `tests/unit/settings/tab_order_test.gd`
- **AC-SA-11.8 [Logic] ADVISORY — REVISED 2026-04-27 (split tr-keys per localization-lead NEW-1)** **GIVEN** keyboard focus is on the LAST focusable widget in the detail pane, **WHEN** the player presses `ui_down`, **THEN** focus does not move (no-op visually) AND AccessKit announces `tr("SETTINGS_NAV_DEAD_END_BOTTOM")` (resolves to *"End of section"* in English) via `accessibility_live = "polite"`. Symmetric for `ui_up` at the first widget: announces `tr("SETTINGS_NAV_DEAD_END_TOP")` (resolves to *"Start of section"*). Both tr-keys must be present in the project translation file before this AC can pass. Evidence: `tests/unit/settings/dead_end_announce_test.gd`
- **AC-SA-11.9 [Logic] BLOCKING — NEW (CR-22 differentiated defaults)** **GIVEN** `user://settings.cfg` is absent on first launch, **WHEN** SettingsService writes default rebinds for `use_gadget` and `takedown` to the `[controls]` section, **THEN** `use_gadget` defaults to `KEY_F` (and `JOY_BUTTON_Y`), `takedown` defaults to `KEY_Q` (and `JOY_BUTTON_X`) — the two actions have DIFFERENT default keybindings on both KB/M and gamepad. Evidence: `tests/unit/settings/rebind_defaults_test.gd`
- **AC-SA-11.10 [UI] BLOCKING — NEW (CR-15 close-as-confirm)** **GIVEN** the player changes `graphics.resolution_scale` in the panel, **WHEN** the revert banner is active and the player presses `ui_cancel` (Esc) to close the panel before the revert timer elapses, **THEN** the new value is **kept** (not reverted), `ConfigFile.save()` writes the new value, and the banner dismisses on close. Auto-revert fires ONLY on timer elapse with zero player input OR explicit `[Revert]` button press — close-as-confirm matches the Stage Manager fantasy. Evidence: `tests/integration/settings/close_as_confirm_test.gd`
- **AC-SA-11.11 [Logic] BLOCKING — NEW (CR-15 Keep button)** **GIVEN** the revert banner is visible, **WHEN** the player presses the `[Keep This Resolution]` button, **THEN** the new value persists (`ConfigFile.save()` fires), the banner dismisses, the timer is canceled, and no `setting_changed` re-emit occurs (the value is already applied). Evidence: `tests/unit/settings/resolution_keep_test.gd`
- **AC-SA-11.12 [Logic] BLOCKING — NEW (F.2 discrete-step clamp)** **GIVEN** `settings.cfg` contains `graphics.resolution_scale = 0.42` (out of valid step set), **WHEN** SettingsService loads the file, **THEN** the value is rounded to the nearest valid step (`0.5`), written back to disk, a `[Settings] WARN:` log line is emitted, and the value emitted in `setting_changed` is `0.5` — no out-of-step value reaches any consumer. Evidence: `tests/unit/settings/graphics_test.gd`
- **AC-SA-11.13 [Logic] BLOCKING — REVISED 2026-04-27 (F.1 explicit `is_nan()` precondition; was clamp-only which IEEE 754 makes incorrect)** **GIVEN** F.1 forward formula is invoked with `p = -1`, `p = 101`, `p = NaN`, or `p = +inf`, **WHEN** the function evaluates, **THEN** the input is FIRST checked via `is_nan()` (NaN replaced with 0), THEN clamped to the valid range [0, 100] before branch selection — output is in [-80.0, 0.0] dB and never undefined. Symmetric for F.1 inverse with dB inputs `+5.0`, `-100.0`, `NaN`, `+inf` (NaN replaced with -80.0 before clamp). Test must verify both the `is_nan()` check AND the clamp behavior — clamp alone (per the IEEE 754 standard followed by Godot 4.6 GDScript) does not handle NaN. Evidence: `tests/unit/settings/audio_formula_test.gd`. Additional sub-AC: F.1 inverse with `dB = -50.0` returns `p = 1` (minimum audible position, not 0 silence sentinel) per the corrected default branch.
- **AC-SA-11.14 [Logic] BLOCKING — NEW (FP-9 await forbidden)** **GIVEN** the full GDScript source tree, **WHEN** CI scans every function named `_on_setting_changed`, **THEN** zero `await` keywords or `call_deferred(` calls are found in any function body — burst-emit synchronicity is preserved (FP-9). Evidence: `tests/unit/settings/forbidden_patterns_ci_test.gd`

## Open Questions

14 open questions (post-2026-04-27 re-review): 10 BLOCKING for sprint, 1 BLOCKING for VS, 3 ADVISORY playtest-resolvable. *(Was 12; +2 NEW from re-review: OQ-SA-13 Audio GDD `clock_tick_enabled` category alignment, OQ-SA-14 Audio GDD six-bus 0 dB clipping risk resolution. Earlier 2026-04-26 PM history: was 8; +4 from prior revisions: OQ-SA-9 muzzle-flash WCAG verification, OQ-SA-10 dual-focus audit, OQ-SA-11 action-name tr-keys [REVISED 2026-04-27], OQ-SA-12 accessibility-requirements.md authoring.)*

### OQ-SA-1 [BLOCKING for sprint] — Outline Pipeline `get_hardware_default_resolution_scale()` query API

**Question**: Settings needs to query Outline Pipeline for the hardware-default `resolution_scale` value at first launch (CR-11). Outline Pipeline's GDD does not currently expose this query. The hardware-detection logic (F.2) lives in this GDD by recommendation, but the query API surface lives in Outline.

**Owner**: Outline Pipeline GDD author + this GDD (mutual coord)
**Target resolution**: Before Settings sprint starts.
**Suggested API**: `OutlinePipeline.get_hardware_default_resolution_scale() -> float` returning one of {0.5, 0.6, 0.75, 1.0}, internally calling `RenderingServer.get_video_adapter_name()` and applying F.2 substring matching.
**Status**: Coord item #5 in §F BLOCKING list.

### OQ-SA-2 [BLOCKING for sprint] — ADR-0002 amendment for `settings_loaded` signal + `settings` domain registration

**Question**: This GDD's CR-9 specifies a one-shot `Events.settings_loaded()` signal emitted after the boot burst. ADR-0002's signal taxonomy currently lists `setting_changed` under the Settings domain (line 290) but does not include `settings_loaded`. ADR-0002 amendment required to register the signal + lock its no-payload semantics.

**Owner**: producer (sequences ADR-0002 amendment with other pending amendments — `ui_context_changed`, `takedown_availability_changed` from HUD Core were already removed/added in REV-2026-04-26)
**Target resolution**: ADR-0002 amendment landing before Settings sprint.
**Status**: Coord item #2 in §F BLOCKING list.

### OQ-SA-3 [BLOCKING for sprint] — Menu System scaffold for boot-warning modal

**Question**: CR-18 specifies that Menu System reads `SettingsService._boot_warning_pending` during its `_ready()` and provides the Control scaffold for the photosensitivity warning modal (button rendering, focus management, modal layer). Menu System #21 is **Not Started**. Until Menu System GDD is authored with this contract documented, the boot-warning is a design intent, not an implementation contract.

**Owner**: Menu System GDD author
**Target resolution**: Menu System GDD authoring (coord items absorbed into Menu System §C).
**Risk**: If Menu System ships without reading `_boot_warning_pending`, the warning never fires. This is a safety-critical regression risk.
**Status**: Coord item #8 in §F BLOCKING list.

### OQ-SA-4 [BLOCKING for sprint] — ADR-0004 verification gates Gate 1 + Gate 2

**Question**: ADR-0004 has two open verification gates that BLOCK Settings Day-1 per IG10:
- **Gate 1**: Confirm Godot 4.6 `accessibility_*` property names on custom Controls (`accessibility_name`, `accessibility_role`, `accessibility_description`, `accessibility_live`). The accessibility-specialist's per-widget contract (§C.5 widget table) uses these as placeholders.
- **Gate 2**: Confirm Theme inheritance property name (`base_theme` vs `fallback_theme`). Settings Theme inherits from `project_theme.tres` — the property name affects `.tres` serialization.

**Owner**: godot-specialist (5-min editor-inspector check on a real Godot 4.6 build)
**Target resolution**: Before Settings sprint starts.
**Status**: Coord items #3 + #4 in §F BLOCKING list.

### OQ-SA-5 [BLOCKING for VS sprint] — Gamepad rebind UI column layout

**Question** (from ux-designer): At MVP, the Controls sub-screen shows ONE binding column per action (the keyboard binding only — gamepad parity is post-MVP per technical-preferences.md). At VS, it grows to TWO columns (keyboard + gamepad). The transition point matters: if the layout is designed for one column at MVP and retro-fitted for two at VS, the UX may feel cramped. If designed for two from MVP (with the gamepad column inactive), the MVP UX may have visual weight that doesn't match the actual interactivity.

**Owner**: ux-designer + this GDD author
**Target resolution**: At VS sprint start, when gamepad rebinding parity is being implemented.
**Risk**: ADVISORY — design choice with playtest implications, not safety-critical.

### OQ-SA-6 [ADVISORY playtest-resolvable] — `T_revert_timeout` duration

**Question**: 10 seconds is the recommended `T_revert_timeout` (per CR-15 + F.3). Real-world TVs use anywhere from 10 to 20 seconds. Playtest may reveal that 10 s is too short (player accidentally lets it expire while reading the warning text) or too long (Iris Xe player on bad-resolution panel suffers for too long). Range allowed in tuning is [5, 30].

**Owner**: This GDD author + playtest data
**Target resolution**: After first MVP playtest with the resolution-scale slider exercised.
**Risk**: ADVISORY — tuning concern.

### OQ-SA-7 [ADVISORY playtest-resolvable] — Audio panel-open ducking policy

**Question** (from §A.3 coord item): When the Settings panel opens, should game audio (Music + Ambient buses) duck so the player can hear slider changes more clearly? Recommended default is NO duck (player drags sliders to hear the live mix). Audio's existing VO-ducking math (audio.md §F.1) does not currently cover Settings open. If playtest shows players struggling to discern slider changes against full mix, this becomes an Audio amendment.

**Owner**: audio-director + this GDD author
**Target resolution**: After first MVP playtest with audio sliders exercised.
**Risk**: ADVISORY — UX preference question.

### OQ-SA-8 [ADVISORY post-MVP] — `resolution_scale_pending_confirmation` sentinel

**Question** (from §E Cluster D residual risk): Currently the resolution-revert mechanism has a residual risk: if the player changes resolution and then OS-kills the game (kill -9, power cut) before the timer elapses, the unconfirmed value persists. On next launch, the unconfirmed value applies. If unreadable, the player has no in-game recovery path. Post-MVP option: write a `graphics.resolution_scale_pending_confirmation` sentinel to disk; only promote it to the canonical key on timer elapse.

**Owner**: This GDD author (post-MVP enhancement)
**Target resolution**: Post-MVP, only if playtest data shows OS-kill mid-revert as a real player issue.
**Risk**: ADVISORY — residual edge case, low probability.

### OQ-SA-9 [BLOCKING for sprint — NEW 2026-04-26 PM] — Combat weapon-roster muzzle-flash WCAG 2.3.1 verification

**Question** (per accessibility-specialist S-1): CR-16 originally exempted muzzle flashes as "below threshold" but the framing was incorrect — WCAG 2.3.1 counts flash *frequency* (Hz), not duration. Until Combat GDD's weapon-roster confirms maximum sustained automatic-fire rate ≤180 RPM (3 Hz), muzzle flashes are an unverified photosensitivity hazard. Three options: (a) Combat declares all weapons fire at ≤3 Hz sustained → muzzle flashes confirmed safe ungated; (b) Combat declares one or more weapons exceed 3 Hz → muzzle flashes MUST be gated under `accessibility.damage_flash_enabled`; (c) Combat declares 3 Hz is unachievable for the SMG-class weapon and proposes per-weapon flash-suppression at the weapon level (alternative implementation).

**Owner**: combat-designer + this GDD author
**Target resolution**: Before Settings sprint starts; required input to CR-16 finalization.
**Status**: NEW BLOCKING coord item.

### OQ-SA-10 [BLOCKING for sprint — NEW 2026-04-26 PM] — Godot 4.6 dual-focus audit

**Question** (per godot-specialist BLOCKING-1): Godot 4.6 introduced separation of mouse/touch focus from keyboard/gamepad focus. Every programmatic `grab_focus()` call in the Settings panel + photosensitivity modal + Restore Defaults modal sets keyboard/gamepad focus only — mouse hover focus is independent. Mouse-primary players (this project's PRIMARY input) may see broken focus throughout. Resolution required: ui-programmer audits each focus-jump point and confirms dual-focus behavior matches design intent on mouse, OR documents required mouse-focus reset alongside `grab_focus()`.

**Owner**: ui-programmer + this GDD author
**Target resolution**: Before Settings sprint starts. Likely revealed by a prototype run on a real Godot 4.6 build.
**Status**: NEW BLOCKING coord item.

### OQ-SA-11 [BLOCKING for sprint — REVISED 2026-04-27] — Action-name tr-key registration in Input GDD

**Question** (per localization-lead BLK-3 + ux-designer + godot-specialist re-review BLOCKING-B): F.4's conflict-detection example "E is already bound to Fire" requires a player-facing display name for every InputMap action StringName (e.g., `action_fire` → "Fire"). The Input GDD must register a tr-key per user-facing action with the convention `tr("INPUT_ACTION_NAME_<ACTION>")` — e.g., `tr("INPUT_ACTION_NAME_action_fire")` resolving to *"Fire"* (English) / *"Feu"* (French) / *"Schießen"* (German) etc.

**Resolution mechanism (REVISED 2026-04-27)**: Use the existing `tr()` pattern documented at C.5 line 306 as the **primary** lookup. Do NOT introduce a project-side `Input.get_action_display_name()` helper — `Input.get_action_display_name(StringName) -> String` is **NOT a Godot 4.6 API** (originally referenced in error in this coord item; godot-specialist + localization-lead independently flagged the invented API). Lookup at point-of-use in Settings panel: `var label = tr("INPUT_ACTION_NAME_" + str(action_name))`. Input GDD's deliverable is the tr-key registration only — populate the project `.csv` translation file with one row per user-facing action (`INPUT_ACTION_NAME_action_fire,Fire`, etc.). Localization Scaffold delivers per-locale `.csv` rows for VS.

**Owner**: Input GDD author + localization-lead
**Target resolution**: Before Settings sprint starts (rebind UI implementation needs the tr-keys registered).
**Status**: BLOCKING coord item — revision lowers code surface (no new helper class) but does not change the deliverable: every user-facing InputMap action needs a tr-key.

### OQ-SA-12 [BLOCKING for sprint — NEW 2026-04-26 PM] — `design/ux/accessibility-requirements.md` authoring

**Question** (per accessibility-specialist F-1 + ux-designer): The full per-widget AccessKit contract referenced in this GDD's C.5 inline summary table needs a complete UX-domain spec at `design/ux/accessibility-requirements.md`. The C.5 inline summary covers widget classes (slider/toggle/dropdown/button/RebindRow/etc) at the role+name+live pattern level; the standalone doc must add per-widget-instance specs (every named widget with its tr-key for accessibility_name + accessibility_description, focus-ring color spec, screen-reader hint copy, keyboard-shortcut conventions). This file does not exist yet. Implementation cannot proceed without it.

**Owner**: ux-designer + accessibility-specialist (collaborative authoring)
**Target resolution**: Before Settings sprint starts. Pattern: run `/ux-design settings-accessibility` after this GDD is approved → produces the accessibility-requirements.md doc.
**Status**: NEW BLOCKING coord item.

### OQ-SA-13 [BLOCKING for sprint — NEW 2026-04-27] — Audio GDD `clock_tick_enabled` category alignment

**Question** (per audio-director re-review B-4): Settings GDD now emits `setting_changed("accessibility", "clock_tick_enabled", _)` per the 2026-04-27 revision (was `audio` category; moved to align with Audio GDD's existing handler at audio.md line 237). Audio GDD must re-validate that its existing handler stays on the `accessibility` category — no Audio GDD change is required if the existing line 237 specification is correct, but a producer-led cross-check is needed to close the cross-document signal-contract verification gap.

**Owner**: audio-director + this GDD author (mutual coord)
**Target resolution**: Before Settings sprint starts. 5-minute Audio GDD review.
**Status**: NEW BLOCKING coord item; Cross-document signal-contract integrity. Pre-revision was a silent-runtime-failure waiting to happen (Settings emits "audio.clock_tick_enabled", Audio listens on "accessibility.clock_tick_enabled" → handler never fires → toggle silently broken at MVP).

### OQ-SA-14 [BLOCKING for sprint — NEW 2026-04-27] — Audio GDD six-bus 0 dB clipping risk resolution

**Question** (per audio-director re-review B-1): All six audio bus defaults in Settings G.1 are `0.0 dB` (unity gain). Combat scenes with simultaneous Music + SFX + Voice + Ambient + UI peaks will sum at the Master bus to values above 0 dB → output-stage clipping → harsh crackling on player headphones. Industry practice is `-3 dB` to `-6 dB` sub-bus defaults with a Master limiter `AudioEffect`.

**Two resolution options (Audio GDD owner decides)**:
- **(a)** Define a Master bus limiter `AudioEffect` (e.g., `AudioEffectLimiter` with threshold `-1 dB`, ceiling `0 dB`). Sub-bus defaults remain at `0.0 dB`; the limiter handles peak summation safely. Settings G.1 defaults stay at `0.0 dB`.
- **(b)** Lower sub-bus defaults to `-3 dB` (Music, SFX, Ambient) and `-6 dB` (Voice, UI). No Master limiter required. Settings G.1 defaults change to match Audio's choice.

**Owner**: audio-director (decides between option a and option b) + this GDD author (updates G.1 defaults if option b)
**Target resolution**: Before Settings sprint starts. Audio GDD amendment + Settings G.1 default sync.
**Status**: NEW BLOCKING coord item. Settings G.1 defaults are TENTATIVE pending Audio GDD coord closure (per the warning at top of G.1).

---

### Deliberately omitted scope

These items were considered and explicitly deferred or rejected:

| Omitted | Reason | Authority |
|---|---|---|
| Per-action multi-bind support (e.g., "F OR G fires the gun") | Adds significant complexity to F.4 conflict detection + UI; not standard in NOLF1-era games | CR-20 (one keyboard + one gamepad binding per action) |
| Cloud sync of `settings.cfg` | Out of scope for a single-player premium game; player-installation-local persistence only | Anti-pillar (no live-service hooks) |
| Settings profiles (per-player presets) | Single-player game; one player per installation | Scope |
| Difficulty selection in Settings | Anti-pillar (game-concept.md "MVP ships at one well-tuned difficulty") | Scope per systems-index L211 |
| Field-of-view (FOV) slider in Graphics | Combat ADS already handles 85°/55° FOV tween; gameplay FOV is locked at 85° per Combat | Scope (Combat-locked) |
| Gamma / brightness slider in Graphics | Saturated Pop visual identity uses unlit flat shading; gamma controls would conflict with the locked color story | Pillar 5 alignment + Art Bible §1 |
| Mouse acceleration toggle | Player Character handles raw mouse input (no accel by default); not exposing it as opt-in modern accel | PC GDD scope |
| Cinematic cutscene skip toggle | Out of scope for Settings; Cutscenes & Mission Cards (#22 VS) owns its own skip behavior | Scope (Cutscenes-owned) |
| HDR / wide-color-gamut output | Not in MVP rendering scope; Saturated Pop uses standard sRGB | Art Bible scope |
