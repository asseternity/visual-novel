# res://scripts/ui/top_bar.gd
extends Control

const StatBarScene := preload("res://scenes/components/StatBar.tscn")

@onready var hbox: HBoxContainer = $HBox

func _ready() -> void:
	# Slim, doesn't cover character's face
	custom_minimum_size = Vector2(0, 64)
	mouse_filter = Control.MOUSE_FILTER_PASS  # PASS not IGNORE — we still want stat bars hoverable

	theme = UITheme.global_theme

	# ── Reparent HBox into a MarginContainer for breathing room.
	var margin := MarginContainer.new()
	margin.name = "InnerMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	add_child(margin) # Attach to TopBar directly
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
