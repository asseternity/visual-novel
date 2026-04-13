extends Control

@onready var tab: Button = $Tab
@onready var bg:  PanelContainer  = $Bg
@onready var vbox: VBoxContainer = $Bg/MarginContainer/VBoxContainer

var open: bool = false
var _shelf_x_open:   float
var _shelf_x_closed: float
var _arrow: Label

# The grid for our mini-game
var blerp_grid: GridContainer

func _ready() -> void:
	# Explicitly apply our global theme
	theme    = UITheme.global_theme
	bg.theme = UITheme.global_theme
	if bg.has_theme_stylebox_override("panel"):
		bg.remove_theme_stylebox_override("panel")
	bg.self_modulate = Color.WHITE

	# Set up the animated arrow
	tab.text = ""            
	_arrow = Label.new()
	_arrow.name = "Arrow"
	_arrow.text = "◀"        
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_arrow.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_arrow.grow_vertical   = Control.GROW_DIRECTION_BOTH
	tab.add_child(_arrow)
	_centre_arrow.call_deferred()

	tab.pressed.connect(_on_toggle)

	# Setup off-screen resting position
	_shelf_x_open   = get_viewport_rect().size.x - size.x
	_shelf_x_closed = get_viewport_rect().size.x 
	position.x = _shelf_x_closed

	UITheme.pop_in(tab)
	
	# Build the minigame grid
	_build_blerp_grid()

func _centre_arrow() -> void:
	if not is_instance_valid(_arrow) or not is_instance_valid(tab):
		return
	await get_tree().process_frame
	if not is_instance_valid(_arrow):
		return
	_arrow.pivot_offset = _arrow.size / 2.0
	_arrow.position = (tab.size - _arrow.size) / 2.0

func _on_toggle() -> void:
	open = not open
	Audio.play("shelf_open" if open else "shelf_close")

	# Slide the whole shelf control
	var target_x := _shelf_x_open if open else _shelf_x_closed
	var slide := create_tween()
	slide.tween_property(self, "position:x", target_x, UITheme.TWEEN_MED)\
		.set_trans(UITheme.BOUNCE_TRANS).set_ease(UITheme.BOUNCE_EASE)

	# Animate the arrow flip
	if is_instance_valid(_arrow):
		_arrow.pivot_offset = _arrow.size / 2.0
		var flip := _arrow.create_tween()
		flip.tween_property(_arrow, "scale:x", 0.0, UITheme.TWEEN_FAST * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		flip.tween_callback(func():
			if is_instance_valid(_arrow):
				_arrow.text = "▶" if open else "◀"
		)
		flip.tween_property(_arrow, "scale:x", 1.0, UITheme.TWEEN_FAST * 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	UITheme.squish(tab, 0.4)

func _build_blerp_grid() -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 16)
	vbox.add_child(sep)
	
	var title = Label.new()
	title.text = "BLERP DECK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_2)
	if UITheme._fonts.has("title"): title.add_theme_font_override("font", UITheme._fonts["title"])
	vbox.add_child(title)
	
	blerp_grid = GridContainer.new()
	blerp_grid.columns = 4
	blerp_grid.add_theme_constant_override("h_separation", 8)
	blerp_grid.add_theme_constant_override("v_separation", 8)
	blerp_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(blerp_grid)
	
	for i in 12:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		var symbols = ["★", "♥", "♪", "⚡", "☀", "☁", "☠", "♠", "♣", "♦", "☢", "☯"]
		btn.text = symbols[i]
		btn.theme = UITheme.global_theme 
		
		# Hook up to global Blerp System
		btn.pressed.connect(_on_blerp_pressed.bind(i))
		blerp_grid.add_child(btn)

func _on_blerp_pressed(blerp_id: int) -> void:
	# Close the shelf menu automatically for dramatic effect
	if open: _on_toggle()
	
	var blerp_sys = get_tree().root.get_node_or_null("Main/BlerpLayer/BlerpSystem")
	if blerp_sys:
		blerp_sys.trigger_blerp(blerp_id)
