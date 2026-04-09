# res://scripts/ui/top_bar.gd
extends Control

const StatBarScene := preload("res://scenes/components/StatBar.tscn")

@onready var hbox: HBoxContainer = $HBox
@onready var bg:   Panel         = $Panel

func _ready() -> void:
	# Slim, doesn't cover character's face
	custom_minimum_size = Vector2(0, 64)
	mouse_filter = Control.MOUSE_FILTER_PASS  # PASS not IGNORE — we still want stat bars hoverable

	theme    = UITheme.global_theme
	bg.theme = UITheme.global_theme

	# ── High-contrast custom panel that screams "arcade marquee"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0a0418")               # Almost black
	style.border_color = Color("#00f0ff")
	style.border_width_bottom = 5
	style.border_width_left   = 0
	style.border_width_right  = 0
	style.border_width_top    = 0
	style.corner_radius_bottom_left  = 32
	style.corner_radius_bottom_right = 32
	style.shadow_color = Color(UITheme.COLOR_ACCENT.r, UITheme.COLOR_ACCENT.g, UITheme.COLOR_ACCENT.b, 0.65)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left   = 32
	style.content_margin_right  = 32
	style.content_margin_top    = 6
	style.content_margin_bottom = 10
	bg.add_theme_stylebox_override("panel", style)

	# Force FX overlay (scanlines + edge glow) on this panel right now.
	UITheme.attach_fx(bg)

	# ── Reparent HBox into a MarginContainer for breathing room.
	# IMPORTANT: do this BEFORE referencing $HBox anywhere, and re-cache
	# the reference because $HBox no longer resolves after the move.
	var margin := MarginContainer.new()
	margin.name = "InnerMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	bg.add_child(margin)
	remove_child(hbox)
	margin.add_child(hbox)

	# Now apply layout to hbox via the cached @onready reference (still valid).
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 48)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# ── Spawn one StatBar per character
	for cid in GameState.characters.keys():
		var sb: StatBar = StatBarScene.instantiate()
		sb.character_id = cid
		hbox.add_child(sb)

	# ── Slide-down + bounce entrance
	position.y = -size.y - 20
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", 0.0, 0.7)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.4).from(0.0)

	# Subtle idle bob so the bar feels alive
	await get_tree().create_timer(0.9).timeout
	_start_idle_bob()

func _start_idle_bob() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "position:y", 2.0, 2.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position:y", 0.0, 2.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
