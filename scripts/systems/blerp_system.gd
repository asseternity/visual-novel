extends CanvasLayer

const SPEED_LINES_SHADER_CODE = """
shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float speed : hint_range(0.0, 10.0) = 4.0;
uniform float line_density : hint_range(0.0, 1.0) = 0.35;
uniform float line_falloff : hint_range(0.0, 1.0) = 0.2;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float angle = atan(centered_uv.y, centered_uv.x);
	float radius = length(centered_uv);
	float time_offset = TIME * speed;
	float noise = random(vec2(angle, floor(radius * 10.0 - time_offset)));
	float line_alpha = step(1.0 - line_density, noise) * smoothstep(line_falloff, 1.0, radius * 2.0);
	COLOR = mix(bg_color, line_color, line_alpha * line_color.a);
}
"""

var is_playing: bool = false
var dim_bg: ColorRect
var speed_lines: ColorRect
var cutin_root: Control

func _ready() -> void:
	layer = 150
	
	# 1. Dimming Background
	dim_bg = ColorRect.new()
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = Color(0, 0, 0, 0.0)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim_bg)
	
	# 2. Speed Lines (Now compiled entirely at runtime!)
	speed_lines = ColorRect.new()
	speed_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var shader = Shader.new()
	shader.code = SPEED_LINES_SHADER_CODE
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("line_color", Color(1, 1, 1, 0.8))
	speed_lines.material = mat
	speed_lines.modulate.a = 0.0
	add_child(speed_lines)
	
	# 3. Cut-In Root
	cutin_root = Control.new()
	cutin_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cutin_root)

func trigger_blerp(blerp_id: int) -> void:
	if is_playing: return
	is_playing = true
	
	Dialogic.paused = true
	Audio.play("equip", 0.0, 0.2)
	
	var active_chars = _get_active_characters()
	
	if active_chars.is_empty():
		UITheme.toast("Nobody is around to hear that...", UITheme.COLOR_TEXT_DIM)
		_finish_blerp()
		return

	var t = create_tween().set_parallel(true)
	t.tween_property(dim_bg, "color:a", 0.6, 0.2)
	t.tween_property(speed_lines, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(0.2).timeout
	
	for char_data in active_chars:
		await _play_persona_cutin(char_data, blerp_id)
		
	var t_out = create_tween().set_parallel(true)
	t_out.tween_property(dim_bg, "color:a", 0.0, 0.3)
	t_out.tween_property(speed_lines, "modulate:a", 0.0, 0.3)
	await t_out.finished
	
	_finish_blerp()

func _play_persona_cutin(char_data: Dictionary, blerp_id: int) -> void:
	var reaction = _evaluate_reaction(char_data.id, blerp_id)
	var bg_color = UITheme.COLOR_GOOD if reaction.is_positive else UITheme.COLOR_BAD
	
	var slash = ColorRect.new()
	slash.color = bg_color
	slash.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	
	var screen_size = get_viewport().get_visible_rect().size
	slash.size = Vector2(screen_size.x * 2.0, 250)
	slash.pivot_offset = slash.size / 2.0
	slash.position = (screen_size / 2.0) - slash.pivot_offset
	slash.rotation = deg_to_rad(-12.0)
	cutin_root.add_child(slash)
	
	var tex_rect = TextureRect.new()
	tex_rect.texture = char_data.texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size = screen_size * 1.5 
	tex_rect.pivot_offset = tex_rect.size / 2.0
	tex_rect.position = (slash.size / 2.0) - tex_rect.pivot_offset
	tex_rect.rotation = deg_to_rad(12.0) 
	slash.add_child(tex_rect)
	
	var lbl = Label.new()
	lbl.text = reaction.text
	if UITheme._fonts.has("fun"): lbl.add_theme_font_override("font", UITheme._fonts["fun"])
	lbl.add_theme_font_size_override("font_size", 96)
	lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT)
	lbl.add_theme_color_override("font_outline_color", UITheme.COLOR_PANEL_DARK)
	lbl.add_theme_constant_override("outline_size", 24)
	lbl.rotation = deg_to_rad(-12.0)
	cutin_root.add_child(lbl)
	
	lbl.pivot_offset = lbl.size / 2.0
	lbl.position = (screen_size / 2.0) - lbl.pivot_offset + Vector2(200, 100)

	slash.scale.y = 0.0
	tex_rect.position.x += 400 
	lbl.scale = Vector2.ZERO
	
	Audio.play("shop", 0.0, 0.4) 
	UITheme.screen_shake(12.0, 0.2)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(slash, "scale:y", 1.0, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	t.tween_property(tex_rect, "position:x", tex_rect.position.x - 400, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT).set_delay(0.1)
	
	await get_tree().create_timer(0.8).timeout
	
	if reaction.morale_delta != 0:
		GameState.apply_change_string("%s:morale:%+d" % [char_data.id, reaction.morale_delta])
	if reaction.rel_delta != 0:
		GameState.apply_change_string("%s:relationship:%+d" % [char_data.id, reaction.rel_delta])
	
	var t_close = create_tween()
	t_close.tween_property(slash, "scale:y", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t_close.parallel().tween_property(lbl, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await t_close.finished
	slash.queue_free()
	lbl.queue_free()

func _finish_blerp() -> void:
	Dialogic.paused = false
	is_playing = false

func _get_active_characters() -> Array:
	var result = []
	for node in get_tree().get_nodes_in_group("dialogic_portrait"):
		if node.visible:
			var tex = _find_texture_recursive(node)
			if tex:
				var char_id = "Unknown"
				if "Allie" in node.name: char_id = "Allie"
				elif "Bing" in node.name: char_id = "Bing"
				
				result.append({
					"id": char_id,
					"texture": tex
				})
	return result

func _find_texture_recursive(node: Node) -> Texture2D:
	if node is TextureRect and node.texture != null:
		return node.texture
	elif node is Sprite2D and node.texture != null:
		return node.texture
	for child in node.get_children():
		var found = _find_texture_recursive(child)
		if found: return found
	return null

func _evaluate_reaction(char_id: String, blerp_id: int) -> Dictionary:
	var stats = GameState.characters.get(char_id, {})
	var rel = stats.get("relationship", 50)
	var location = Dialogic.VAR.get_variable("Location", "None")
	
	var res = {"is_positive": true, "text": "COOL!", "morale_delta": 5, "rel_delta": 2}
	
	if char_id == "Allie":
		if blerp_id == 7: 
			res = {"is_positive": false, "text": "UGH.", "morale_delta": -10, "rel_delta": -5}
		elif location == "Cafe" and blerp_id == 2:
			res = {"is_positive": true, "text": "VIBES!", "morale_delta": 15, "rel_delta": 10}
	
	elif char_id == "Bing":
		if rel < 30:
			res = {"is_positive": false, "text": "?!", "morale_delta": -5, "rel_delta": -2}
		else:
			res = {"is_positive": true, "text": "HEHEH", "morale_delta": 5, "rel_delta": 5}

	return res