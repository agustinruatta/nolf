# prototypes/verification-spike/stencil_compositor_outline.gd
#
# Sprint 01 verification spike — ADR-0001 G2 + G4 prototype.
#
# CompositorEffect that reads the GPU stencil buffer to render screen-space-
# stable outlines at 3 tier widths (HEAVIEST/MEDIUM/LIGHT). Pattern adapted
# from dmlary/godot-stencil-based-outline-compositor-effect (MIT) — the key
# insight is that you cannot bind the stencil aspect to a compute shader
# directly in Godot 4.5/4.6. Instead, use a graphics pipeline with
# RDPipelineDepthStencilState.enable_stencil = true; the GPU's stencil
# hardware filters which fragments execute, and the fragment shader writes
# tier markers to an intermediate color texture. A compute shader then
# turns that mask into outline pixels.
#
# This prototype is intentionally minimal — the goal is to close ADR-0001
# G2 (Vulkan stencil-read works) + G4 (Shader Baker handles these shaders).
# Production implementation will rewrite per ADR conformance.
#
# Knowledge risk: this code touches post-LLM-cutoff Godot 4.5/4.6 APIs
# (stencil buffer, CompositorEffect, RenderingDevice). Verified against
# Godot 4.6.2 stable.

extends CompositorEffect
class_name StencilCompositorOutline

const TIER_HEAVIEST: int = 1
const TIER_MEDIUM: int = 2
const TIER_LIGHT: int = 3

const TIER_MARKERS: Dictionary = {
	TIER_HEAVIEST: 1.0,
	TIER_MEDIUM: 0.66,
	TIER_LIGHT: 0.33,
}

@export var outline_color: Color = Color(0.10, 0.10, 0.10, 1.0)  # ~#1A1A1A linear
@export var max_radius_px: int = 4  # HEAVIEST tier radius — also the scan upper bound

var _shader_dir: String = get_script().get_path().get_base_dir() + "/shaders/"
var _stencil_pass_path: String = _shader_dir + "stencil_pass.glsl"
var _outline_path: String = _shader_dir + "outline.glsl"

var _rd: RenderingDevice

var _stencil_shader: RID
var _outline_shader: RID
var _outline_pipeline: RID

# 3 stencil-test pipelines (one per tier — pipelines bake the reference value)
var _stencil_pipelines: Array[RID] = [RID(), RID(), RID()]
var _stencil_framebuffer: RID

var _vertex_format: int
var _vertex_buffer: RID
var _vertex_array: RID

var _tier_mask_texture: RID
var _color_texture_cached: RID
var _depth_texture_cached: RID
var _resolution: Vector2i = Vector2i(1, 1)

var _needs_rebuild: bool = true


func _init() -> void:
	# POST_OPAQUE: opaque pass has populated depth+stencil; transparent pass
	# has not run yet. Outlines render before transparents (intentional —
	# they should appear behind UI, particles, etc.). dmlary uses this too.
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE

	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		push_error("[stencil_compositor] no RenderingDevice — non-RD backend?")
		return

	_build_vertex_array()


func _notification(what: int) -> void:
	# Inlined cleanup — calling another method on self at PREDELETE intermittently
	# resolves to a "null instance" because GDScript may have torn down the script
	# state by then. Direct field access still works.
	if what == NOTIFICATION_PREDELETE:
		if _rd == null:
			return
		if _stencil_shader.is_valid():
			_rd.free_rid(_stencil_shader)
		if _outline_shader.is_valid():
			_rd.free_rid(_outline_shader)
		if _vertex_buffer.is_valid():
			_rd.free_rid(_vertex_buffer)
		if _tier_mask_texture.is_valid():
			_rd.free_rid(_tier_mask_texture)


func _build_vertex_array() -> void:
	# Fullscreen-covering triangle (counter-clockwise winding so it isn't
	# culled by default rasterizer state).
	var attr := RDVertexAttribute.new()
	attr.location = 0
	attr.format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	attr.stride = 4 * 3
	_vertex_format = _rd.vertex_format_create([attr])

	var verts := PackedVector3Array([
		Vector3(-1, -1, 0),
		Vector3(3, -1, 0),
		Vector3(-1, 3, 0),
	])
	var bytes := verts.to_byte_array()
	_vertex_buffer = _rd.vertex_buffer_create(bytes.size(), bytes)
	_vertex_array = _rd.vertex_array_create(3, _vertex_format, [_vertex_buffer])


func _load_spirv(path: String) -> RDShaderSPIRV:
	var file: RDShaderFile = ResourceLoader.load(path)
	if file == null:
		push_error("[stencil_compositor] failed to load shader: %s" % path)
		return null
	return file.get_spirv()


func _build_stencil_pipeline_for_tier(tier: int, framebuffer_format: int) -> RID:
	var blend := RDPipelineColorBlendState.new()
	var attach := RDPipelineColorBlendStateAttachment.new()
	blend.attachments.push_back(attach)

	var stencil_state := RDPipelineDepthStencilState.new()
	stencil_state.enable_stencil = true
	# Compare scene stencil to the tier reference; only equal pixels execute the fragment shader.
	stencil_state.front_op_compare = RenderingDevice.COMPARE_OP_EQUAL
	stencil_state.front_op_compare_mask = 0xFF
	stencil_state.front_op_reference = tier
	stencil_state.front_op_fail = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.front_op_pass = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.front_op_depth_fail = RenderingDevice.STENCIL_OP_KEEP

	return _rd.render_pipeline_create(
		_stencil_shader,
		framebuffer_format,
		_vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),
		RDPipelineMultisampleState.new(),
		stencil_state,
		blend,
	)


func _build_pipelines() -> void:
	# (Re)build everything that depends on resolution + scene textures.
	if _stencil_shader.is_valid():
		_rd.free_rid(_stencil_shader)
	if _outline_shader.is_valid():
		_rd.free_rid(_outline_shader)
	if _tier_mask_texture.is_valid():
		_rd.free_rid(_tier_mask_texture)

	# Tier-mask intermediate texture
	var tex_format := RDTextureFormat.new()
	tex_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tex_format.width = _resolution.x
	tex_format.height = _resolution.y
	tex_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	tex_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	_tier_mask_texture = _rd.texture_create(tex_format, RDTextureView.new())

	# Stencil-pass shader (vertex+fragment)
	var stencil_spirv := _load_spirv(_stencil_pass_path)
	if stencil_spirv == null:
		return
	_stencil_shader = _rd.shader_create_from_spirv(stencil_spirv)

	# Build framebuffer that combines the tier-mask color attachment with
	# the scene's depth/stencil attachment so the GPU stencil tester can
	# read scene stencil values.
	var color_af := RDAttachmentFormat.new()
	var color_fmt := _rd.texture_get_format(_tier_mask_texture)
	color_af.format = color_fmt.format
	color_af.usage_flags = color_fmt.usage_bits
	color_af.samples = RenderingDevice.TEXTURE_SAMPLES_1

	var depth_af := RDAttachmentFormat.new()
	var depth_fmt := _rd.texture_get_format(_depth_texture_cached)
	depth_af.format = depth_fmt.format
	depth_af.usage_flags = depth_fmt.usage_bits
	depth_af.samples = RenderingDevice.TEXTURE_SAMPLES_1

	var fb_format := _rd.framebuffer_format_create([color_af, depth_af])
	_stencil_framebuffer = _rd.framebuffer_create([_tier_mask_texture, _depth_texture_cached], fb_format)

	# Build 3 stencil-test pipelines (one per tier reference value)
	for i in range(3):
		var tier := i + 1  # 1, 2, 3
		_stencil_pipelines[i] = _build_stencil_pipeline_for_tier(tier, fb_format)

	# Outline compute shader
	var outline_spirv := _load_spirv(_outline_path)
	if outline_spirv == null:
		return
	_outline_shader = _rd.shader_create_from_spirv(outline_spirv)
	_outline_pipeline = _rd.compute_pipeline_create(_outline_shader)


func _render_callback(_p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if _rd == null:
		return

	var sb: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if sb == null:
		return

	var size: Vector2i = sb.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var color_tex: RID = sb.get_color_layer(0)
	var depth_tex: RID = sb.get_depth_layer(0)

	var rebuild := _needs_rebuild
	if size != _resolution:
		_resolution = size
		rebuild = true
	if color_tex != _color_texture_cached:
		_color_texture_cached = color_tex
		rebuild = true
	if depth_tex != _depth_texture_cached:
		_depth_texture_cached = depth_tex
		rebuild = true

	if rebuild:
		_needs_rebuild = false
		_build_pipelines()

	if not _stencil_framebuffer.is_valid() or not _outline_pipeline.is_valid():
		return

	# ─── Step 1: 3 stencil-test passes write tier markers to tier_mask ───
	# First pass clears the tier_mask to (0,0,0,0); subsequent passes preserve.
	var clear_action := RenderingDevice.DRAW_CLEAR_COLOR_0
	var clear_color := Color(0.0, 0.0, 0.0, 0.0)

	for i in range(3):
		var tier := i + 1
		var pipeline_rid: RID = _stencil_pipelines[i]
		if not pipeline_rid.is_valid():
			continue

		var draw_list := _rd.draw_list_begin(
			_stencil_framebuffer,
			clear_action if i == 0 else 0,
			[clear_color] if i == 0 else [],
			1.0,
			0,
			Rect2(),
			RenderingDevice.OPAQUE_PASS,
		)
		_rd.draw_list_bind_render_pipeline(draw_list, pipeline_rid)
		_rd.draw_list_bind_vertex_array(draw_list, _vertex_array)

		var pc := PackedByteArray()
		pc.resize(16)  # std430 push-constant blocks must be 16-aligned
		pc.encode_float(0, TIER_MARKERS[tier])
		_rd.draw_list_set_push_constant(draw_list, pc, pc.size())

		_rd.draw_list_draw(draw_list, false, 3)
		_rd.draw_list_end()

	# ─── Step 2: compute shader paints outline into scene color buffer ───
	var src_uniform := RDUniform.new()
	src_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	src_uniform.binding = 0
	src_uniform.add_id(_tier_mask_texture)

	var dst_uniform := RDUniform.new()
	dst_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	dst_uniform.binding = 1
	dst_uniform.add_id(color_tex)

	var uniform_set := UniformSetCacheRD.get_cache(_outline_shader, 0, [src_uniform, dst_uniform])
	if not uniform_set.is_valid():
		return

	var pc2 := PackedByteArray()
	pc2.resize(32)
	pc2.encode_float(0, outline_color.r)
	pc2.encode_float(4, outline_color.g)
	pc2.encode_float(8, outline_color.b)
	pc2.encode_float(12, outline_color.a)
	pc2.encode_s32(16, max_radius_px)

	@warning_ignore("integer_division")
	var x_groups: int = (_resolution.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups: int = (_resolution.y - 1) / 8 + 1

	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _outline_pipeline)
	_rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
	_rd.compute_list_set_push_constant(cl, pc2, pc2.size())
	_rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
	_rd.compute_list_end()
