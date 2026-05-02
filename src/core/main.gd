# res://src/core/main.gd
#
# Main — first vertical-slice boot script.
#
# RESPONSIBILITY (VS scope only):
#   1. Instance Plaza section as a child.
#   2. Find the PlayerSpawn Marker3D inside Plaza, instance PlayerCharacter
#      at that transform, and make its Camera3D the active camera.
#   3. Push InputContext.GAMEPLAY so movement/look/interact actions route
#      to PlayerCharacter (and quicksave/quickload remain globally handled
#      by this Main script).
#   4. Listen for `quicksave` / `quickload` input actions and dispatch to
#      SaveLoad.save_to_slot(0, sg) / SaveLoad.load_from_slot(0).
#   5. Show on-screen feedback when save/load completes (a temporary HUD
#      label that fades out after a few seconds).
#
# OUT OF SCOPE for this VS:
#   • Main menu, pause menu, settings UI — no menu flow yet.
#   • Section transitions via LevelStreamingService (Plaza is loaded once
#     at boot here; LSS is exercised by integration tests).
#   • Any gameplay system beyond walking + camera + interact + save/load.
#   • Outline shader, audio mix, footstep audio routing.
#
# This is a *demo scaffold*, not production architecture. The "real" boot
# flow lives in a future Boot epic that will:
#   - Show a main menu first
#   - Use LevelStreamingService for section swaps (LS-002)
#   - Wire AudioManager + the post-process stack on the camera
#   - Render the FPS hands SubViewport (ADR-0005)
#
# Implements: First Vertical Slice (post-Sprint-02 integration pass)

class_name Main
extends Node


# ── Tunables ───────────────────────────────────────────────────────────────

## Section to load at boot. Plaza is the only populated section right now.
const BOOT_SECTION_ID: StringName = &"plaza"

## How long the save/load toast stays fully visible before fade.
const TOAST_VISIBLE_SECONDS: float = 1.5

## How long the toast takes to fade once the visible window closes.
const TOAST_FADE_SECONDS: float = 0.6


# ── Resources ──────────────────────────────────────────────────────────────

const PLAZA_SCENE: PackedScene = preload("res://scenes/sections/plaza.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/player/PlayerCharacter.tscn")


# ── Live state ─────────────────────────────────────────────────────────────

var _plaza: Node3D = null
var _player: PlayerCharacter = null
var _toast: Label = null
var _toast_tween: Tween = null


# ── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	# Capture the mouse so look-input works without click-to-focus first.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_spawn_world()
	_apply_plaza_outline_tiers()  # Stencil-tag CSG geometry before camera attaches.
	_spawn_player()
	_attach_outline_compositor()
	_spawn_toast_overlay()
	_push_gameplay_context()
	_connect_savesignal_feedback()


# ── World setup ────────────────────────────────────────────────────────────

func _spawn_world() -> void:
	_plaza = PLAZA_SCENE.instantiate() as Node3D
	add_child(_plaza)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerCharacter
	# Add to the tree first so all @onready vars resolve before we read the
	# Camera3D node. PlayerCharacter._ready handles collision-layer setup.
	add_child(_player)

	# Position the player at the Plaza's spawn marker.
	var spawn: Marker3D = _plaza.get_node_or_null("PlayerSpawn") as Marker3D
	if spawn != null:
		_player.global_transform = spawn.global_transform
	else:
		push_warning("Main: PlayerSpawn marker not found in Plaza — using origin.")
		_player.global_position = Vector3(0, 1.0, 0)

	# Make the player camera the active camera. PlayerCharacter doesn't do
	# this itself (it doesn't know it's the only camera in the scene).
	var cam: Camera3D = _player.get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		cam.make_current()


## Tag plaza CSG geometry with stencil-reference values so the outline pass
## has something to draw outlines around. Walls + floor + pillar = Tier 3
## LIGHT (1.5 px); the three crates = Tier 1 HEAVIEST (4 px) so the demo
## visibly shows tier variation.
##
## CSGShape3D nodes carry a `material` property (StandardMaterial3D); the
## outline pipeline reads stencil_mode/flags/compare/reference from that
## material. OutlineTier.set_tier() targets MeshInstance3D specifically, so
## here we set the stencil props directly on the CSG materials.
func _apply_plaza_outline_tiers() -> void:
	if _plaza == null:
		return
	var heaviest: Array[String] = ["Crate1", "Crate2", "Crate3"]
	for child: Node in _plaza.get_children():
		if not (child is CSGShape3D):
			continue
		var csg: CSGShape3D = child as CSGShape3D
		if csg.material == null or not (csg.material is BaseMaterial3D):
			continue
		var mat: BaseMaterial3D = (csg.material as BaseMaterial3D).duplicate() as BaseMaterial3D
		var tier: int = OutlineTier.HEAVIEST if heaviest.has(csg.name) else OutlineTier.LIGHT
		mat.stencil_mode = 3                    # STENCIL_MODE_CUSTOM
		mat.stencil_flags = 2                   # Write
		mat.stencil_compare = 0                 # Always
		mat.stencil_reference = tier
		csg.material = mat


## Attach the OutlineCompositorEffect to the player camera via a Compositor
## resource. The CompositorEffect reads the stencil values written above and
## draws the comic-book outline as POST_OPAQUE pass.
func _attach_outline_compositor() -> void:
	if _player == null:
		return
	var cam: Camera3D = _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		push_warning("Main: cannot attach outline — Camera3D not found.")
		return
	var effect: OutlineCompositorEffect = OutlineCompositorEffect.new()
	var compositor: Compositor = Compositor.new()
	compositor.compositor_effects = [effect]
	cam.compositor = compositor


func _push_gameplay_context() -> void:
	# InputContext stack already starts with GAMEPLAY at index 0 (autoload
	# `_init` invariant in InputContextStack.gd: `_stack: Array[Context] =
	# [Context.GAMEPLAY]`). No push needed at boot.
	#
	# Future menus / pause / document-overlay flows will push their own
	# contexts; quicksave/quickload remain handled globally by Main here
	# (matches CR-6: Quicksave is silently dropped when InputContext is in
	# CUTSCENE / DOCUMENT_OVERLAY / MODAL / LOADING — those gates are not
	# yet exercised in this VS since we never push them).
	if get_node_or_null("/root/InputContext") == null:
		push_warning("Main: InputContext autoload not found.")


# ── Save / load feedback ───────────────────────────────────────────────────

func _connect_savesignal_feedback() -> void:
	# Show a toast when SaveLoad confirms a write or a load.
	Events.game_saved.connect(_on_game_saved)
	Events.game_loaded.connect(_on_game_loaded)
	Events.save_failed.connect(_on_save_failed)


func _on_game_saved(slot: int, section_id: StringName) -> void:
	_show_toast("Saved to slot %d (%s)" % [slot, String(section_id)])


func _on_game_loaded(slot: int) -> void:
	_show_toast("Loaded slot %d" % slot)


func _on_save_failed(reason: int) -> void:
	_show_toast("Save/Load failed (reason %d)" % reason)


# ── Quicksave / quickload routing ──────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Quicksave (F5): build a minimal SaveGame from the live player state
	# and write it to slot 0 (autosave). The full save schema is much wider
	# than this — for the VS we only persist player position + section_id
	# so the round-trip is observable.
	if event.is_action_pressed("quicksave"):
		_quicksave()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("quickload"):
		_quickload()
		get_viewport().set_input_as_handled()
		return

	# Esc releases mouse capture so the user can quit cleanly.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return


func _quicksave() -> void:
	if _player == null:
		return
	var sg: SaveGame = SaveGame.new()
	sg.section_id = BOOT_SECTION_ID
	sg.saved_at_iso8601 = Time.get_datetime_string_from_system()
	# PlayerState is the typed sub-resource that owns position; populate just
	# enough fields for the VS round-trip to be observable.
	sg.player.position = _player.global_position
	sg.player.rotation = _player.rotation
	SaveLoad.save_to_slot(0, sg)


func _quickload() -> void:
	var loaded: SaveGame = SaveLoad.load_from_slot(0)
	if loaded == null:
		_show_toast("No save in slot 0")
		return
	if _player == null:
		return
	# Caller-side duplicate_deep is required by ADR-0003 IG 3 before handing
	# nested state to live systems, even though we only read top-level fields
	# here — the discipline matters for future expansion.
	var sg: SaveGame = loaded.duplicate_deep()
	_player.global_position = sg.player.position
	_player.rotation = sg.player.rotation


# ── Toast overlay (temporary in-game HUD for VS only) ──────────────────────

func _spawn_toast_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.position = Vector2(0, 32)
	_toast.size = Vector2(0, 64)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.modulate = Color(1, 1, 1, 0)
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_VISIBLE_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE_SECONDS)
