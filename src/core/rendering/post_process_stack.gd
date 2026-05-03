# res://src/core/rendering/post_process_stack.gd
#
# PostProcessStackService — sepia-dim + outline post-process owner.
#
# Implements: Story PPS-001 (autoload scaffold + chain-order const)
# Requirements: TR-PP-001, TR-PP-007
# Governing ADRs: ADR-0007 (Autoload Load Order), ADR-0008 (Performance Budget)
#                 ADR-0004 IG 7 + design/gdd/post-process-stack.md §5
#
# RESPONSIBILITY (this story, PPS-001 — scaffold only):
#   • Declare the canonical chain-order constant (CHAIN_ORDER) — the locked
#     visual-stack order per GDD Core Rule 1; any reorder must change this
#     const so the lock is git-diffable.
#   • Expose the public sepia-dim API surface (`is_sepia_active`,
#     `enable_sepia_dim()`, `disable_sepia_dim()`) as stubs. Bodies land in
#     PPS-002 (CompositorEffect shader) and PPS-003 (tween state machine).
#
# AUTOLOAD POSITION (ADR-0007 §Key Interfaces):
#   1: Events
#   2: EventLogger
#   3: SaveLoad
#   4: InputContext
#   5: LevelStreamingService
#   6: PostProcessStack          ← this file
#   7: Combat
#   8: FailureRespawn
#   9: MissionLevelScripting
#  10: SettingsService
#
# CROSS-AUTOLOAD REFERENCE SAFETY (ADR-0007 IG 4):
#   _ready() at position 6 may reference Events / EventLogger / SaveLoad /
#   InputContext / LevelStreamingService (positions 1–5). It MUST NOT
#   reference Combat / FailureRespawn / MissionLevelScripting /
#   SettingsService (positions 7–10) — those load AFTER this file.
#
# OUT OF SCOPE in PPS-001 (deferred):
#   • Sepia-dim CompositorEffect shader resource — PPS-002
#   • Tween state machine inside enable/disable — PPS-003
#   • Document Overlay handshake — PPS-004
#   • WorldEnvironment glow ban — PPS-005
#   • Resolution scale wiring — PPS-006
#
# Class name / autoload key split mirrors Events/SignalBusEvents and
# SaveLoad/SaveLoadService precedents — class_name `PostProcessStackService`
# is distinct from autoload key `PostProcessStack`, avoiding any
# class-hides-singleton parser conflict.

class_name PostProcessStackService
extends Node

# ── Chain Order (GDD Core Rule 1) ──────────────────────────────────────────

## The locked render-chain order for the post-process stack. Outline runs
## first (writes outline pixels onto the scene buffer), then sepia_dim
## (full-screen tint over the outline), then resolution_scale (final upscale).
##
## DO NOT reorder this array without a Core Rule 1 amendment in
## design/gdd/post-process-stack.md and a fresh visual-sign-off cycle. The
## CHAIN_ORDER assertion in PostProcessStackScaffoldTest is the trip-wire.
const CHAIN_ORDER: Array[StringName] = [&"outline", &"sepia_dim", &"resolution_scale"]


# ── Public state ───────────────────────────────────────────────────────────

## True when the sepia-dim overlay is currently active (FADING_IN, ACTIVE, or
## FADING_OUT in the Story PPS-003 state machine). Document Overlay (PPS-004)
## reads this to guard against double-calls to enable_sepia_dim().
##
## Read-only from outside — use enable_sepia_dim() / disable_sepia_dim() to
## change. GDScript does not enforce read-only at the language level; this is
## a documented contract.
var is_sepia_active: bool = false


# ── Lifecycle ──────────────────────────────────────────────────────────────

## SA-003 photosensitivity → glow handshake. True iff the player has
## damage_flash_enabled = true; mirrors the value the glow shader is
## configured to render. SettingsService's burst (slot 10) reaches us synchronously
## because we're at slot 6 — by the time settings_loaded fires, this state matches
## the persisted user preference.
var _glow_intensity: float = 1.0


func _ready() -> void:
	# Position 6 — only Events/EventLogger/SaveLoad/InputContext/
	# LevelStreamingService are constructed at this point. No subscriptions
	# at this story; PPS-006 will subscribe to Events.setting_changed for
	# resolution_scale once the Settings epic exposes the key.
	#
	# SA-003 handshake: subscribe to setting_changed for the
	# accessibility.damage_flash_enabled toggle. Slot 6 < slot 10 means the
	# burst from SettingsService arrives synchronously after our subscriber
	# is connected.
	Events.setting_changed.connect(_on_setting_changed)


## SA-003 / TR-SET-008 handshake: SettingsService publishes the persisted
## photosensitivity preference; PostProcessStack honors it by routing to
## set_glow_intensity. Forward-compat per FP-6: no `else:` in match name.
func _on_setting_changed(category: StringName, name: StringName, value: Variant) -> void:
	if category != &"accessibility": return
	match name:
		&"damage_flash_enabled":
			if value is bool:
				set_glow_intensity(1.0 if value else 0.0)


## SA-003 public API stub — accepts the photosensitivity-driven intensity value
## (1.0 = on, 0.0 = off). Body that wires this to the actual WorldEnvironment
## glow uniform / Compositor pass lives in the Post-Process Stack epic
## (PPS-007+). At Sprint 06 we verify the handshake fires; the visual glow
## body lands later. Range expected: [0.0, 1.0].
func set_glow_intensity(value: float) -> void:
	_glow_intensity = clampf(value, 0.0, 1.0)
	# TODO PPS-007: wire to WorldEnvironment.environment.glow_intensity or
	# Compositor uniform. SA-003 acceptance only requires the call to land
	# with the correct value.


# ── Public API — sepia dim ─────────────────────────────────────────────────

## Begins fading in the sepia-dim overlay. Idempotent — calling while sepia
## is already active is a no-op (PPS-003 state machine handles state checks).
##
## STUB at PPS-001 — body lands in PPS-003.
func enable_sepia_dim() -> void:
	# TODO: implemented in PPS-003 (tween state machine).
	pass


## Begins fading out the sepia-dim overlay. Idempotent — calling while sepia
## is already inactive is a no-op (PPS-003 state machine handles state checks).
##
## STUB at PPS-001 — body lands in PPS-003.
func disable_sepia_dim() -> void:
	# TODO: implemented in PPS-003 (tween state machine).
	pass
