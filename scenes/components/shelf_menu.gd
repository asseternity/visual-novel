# res://scripts/ui/shelf_menu.gd
extends Control

@onready var tab: Button = $Tab
@onready var bg:  Panel  = $Bg

var open: bool = false
var _shelf_x_open:   float
var _shelf_x_closed: float

# Task 2 & 3: arrow label that lives inside the Tab button.
var _arrow: Label

func _ready() -> void:
	# Explicitly apply our global theme (belt-and-braces for early nodes).
	theme    = UITheme.global_theme
	bg.theme = UITheme.global_theme
	if bg.has_theme_stylebox_override("panel"):
		bg.remove_theme_stylebox_override("panel")
	bg.self_modulate = Color.WHITE

	# ── Task 2: replace button text with a Label child we can rotate.
	tab.text = ""            # let our Label drive the display
	_arrow = Label.new()
	_arrow.name = "Arrow"
	_arrow.text = "◀"        # closed state: left arrow = "pull open"
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Let the label auto-size then we'll centre it once layout settles.
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_arrow.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_arrow.grow_vertical   = Control.GROW_DIRECTION_BOTH
	tab.add_child(_arrow)
	_centre_arrow.call_deferred()

	tab.pressed.connect(_on_toggle)

	# ── FIX FOR ISSUE 4: Push the menu entirely off-screen. 
	# Because Tab has offset_left = -40, it will naturally stick out exactly 40px!
	_shelf_x_open   = get_viewport_rect().size.x - size.x
	_shelf_x_closed = get_viewport_rect().size.x 
	position.x = _shelf_x_closed

	UITheme.pop_in(tab)

func _centre_arrow() -> void:
	if not is_instance_valid(_arrow) or not is_instance_valid(tab):
		return
	# Wait one extra frame so RichTextLabel / Font metrics are final.
	await get_tree().process_frame
	if not is_instance_valid(_arrow):
		return
	_arrow.pivot_offset = _arrow.size / 2.0
	_arrow.position = (tab.size - _arrow.size) / 2.0

func _on_toggle() -> void:
	open = not open

	# Slide the whole shelf control. 
	var target_x := _shelf_x_open if open else _shelf_x_closed
	var slide := create_tween()
	slide.tween_property(self, "position:x", target_x, UITheme.TWEEN_MED)\
		.set_trans(UITheme.BOUNCE_TRANS).set_ease(UITheme.BOUNCE_EASE)

	# ── Task 2: animate the arrow by x-scale flip (◀ ↔ ▶).
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
