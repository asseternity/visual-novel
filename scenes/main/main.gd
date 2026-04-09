# res://scenes/main/main.gd
extends Node

const BG_DIR := "res://assets/backgrounds/"

@onready var game_layer:    CanvasLayer = $GameLayer
@onready var bg_a:          TextureRect = $GameLayer/BgTextureA
@onready var bg_b:          TextureRect = $GameLayer/BgTextureB
@onready var overlay_root:  Control     = $OverlayLayer/OverlayRoot
@onready var flash_rect:    ColorRect   = $OverlayLayer/OverlayRoot/FlashRect
@onready var toast_box:     VBoxContainer = $OverlayLayer/OverlayRoot/ToastContainer
@onready var floating_root: Control     = $OverlayLayer/OverlayRoot/FloatingTextRoot

var _bg_active_a: bool = true   # which TextureRect currently shows the background

func _ready() -> void:
	# ── Dialogic text effect / signal events
	Dialogic.text_signal.connect(_on_dialogic_text_signal)
	Dialogic.signal_event.connect(_on_dialogic_text_signal)

	# Mirror PlayerName both ways
	Dialogic.VAR.set_variable("PlayerName", GameState.player_name)
	Dialogic.VAR.variable_changed.connect(_on_dialogic_var_changed)

	# Wire up UITheme overlay refs
	UITheme.register_overlays(overlay_root, flash_rect, toast_box, floating_root, game_layer)

	# Stat-change global hooks
	GameState.stat_changed.connect(_on_global_stat_changed)

	# Dialogue squish on every line advance
	if Dialogic.Text.has_signal("about_to_show_text"):
		Dialogic.Text.about_to_show_text.connect(_on_dialogue_advance)
	if Dialogic.Text.has_signal("speaker_updated"):
		Dialogic.Text.speaker_updated.connect(_on_speaker_updated)

	# Start the intro timeline
	Dialogic.start("res://dialogic/timelines/intro.dtl")

	# Welcome toast
	await get_tree().create_timer(0.6).timeout
	UITheme.toast("✦ WELCOME ✦", UITheme.COLOR_ACCENT_3)

# ─── DIALOGIC HOOKS ───────────────────────────────────────────────────
func _on_dialogic_text_signal(arg: String) -> void:
	# Background change: "bg:filename"  (e.g. "bg:cafe" -> res://assets/backgrounds/cafe.png)
	if arg.begins_with("bg:"):
		var bg_name: String = arg.substr(3).strip_edges()
		set_background(bg_name)
		return
	# Stat changes: "CharacterID:stat:+/-N"
	if ":" in arg:
		GameState.apply_change_string(arg)

func _on_dialogic_var_changed(info: Dictionary) -> void:
	if info.get("variable_name", "") == "PlayerName":
		var new_name: String = str(info.get("new_value", ""))
		if new_name != GameState.player_name:
			GameState.player_name = new_name
			GameState.player_name_changed.emit(new_name)

func _on_dialogue_advance(_info: Variant = null) -> void:
	var panel := _find_dialog_text_panel()
	if panel:
		UITheme.squish(panel, 0.10)
		UITheme.burst(panel, UITheme.COLOR_ACCENT_2, 6)

func _on_speaker_updated(_character: Variant) -> void:
	var portrait := _find_active_portrait()
	if portrait:
		UITheme.wiggle(portrait, 3.0, 1)

# ─── BACKGROUND SYSTEM ────────────────────────────────────────────────
const BG_EXTENSIONS := [".png", ".jpg", ".jpeg", ".webp"]
var _bg_index_cache: Dictionary = {}   # lowercase basename -> full path

func set_background(bg_name: String) -> void:
	if bg_name.is_empty():
		_crossfade_to(null)
		return

	if _bg_index_cache.is_empty():
		_build_bg_index()

	# Strip extension if user provided one, then lowercase for lookup.
	var key: String = bg_name.strip_edges().get_basename().to_lower()
	var path: String = _bg_index_cache.get(key, "")

	if path.is_empty():
		push_warning("[Main] Background not found: '%s'. Available: %d files in %s"
			% [bg_name, _bg_index_cache.size(), BG_DIR])
		return

	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("[Main] Failed to load background texture: " + path)
		return
	_crossfade_to(tex)

func _build_bg_index() -> void:
	# One-time scan of the backgrounds directory. Builds a case-insensitive
	# basename → full path map so timeline writers don't have to care about
	# capitalization or file extension.
	_bg_index_cache.clear()
	var dir := DirAccess.open(BG_DIR)
	if dir == null:
		push_warning("[Main] Cannot open background directory: " + BG_DIR)
		return
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if not dir.current_is_dir() and not f.ends_with(".import"):
			var ext: String = "." + f.get_extension().to_lower()
			if ext in BG_EXTENSIONS:
				var key: String = f.get_basename().to_lower()
				_bg_index_cache[key] = BG_DIR + f
		f = dir.get_next()
	dir.list_dir_end()

func _crossfade_to(tex: Texture2D) -> void:
	# Determine which TextureRect is currently visible and which to fade in.
	var fade_in_rect: TextureRect  = bg_b if _bg_active_a else bg_a
	var fade_out_rect: TextureRect = bg_a if _bg_active_a else bg_b

	fade_in_rect.texture = tex
	fade_in_rect.modulate.a = 0.0

	var t := create_tween().set_parallel(true)
	t.tween_property(fade_in_rect,  "modulate:a", 1.0, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(fade_out_rect, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Tiny zoom-in on the new bg for a Ken Burns feel
	fade_in_rect.pivot_offset = fade_in_rect.size / 2.0
	fade_in_rect.scale = Vector2(1.05, 1.05)
	t.tween_property(fade_in_rect, "scale", Vector2.ONE, 0.9)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_bg_active_a = not _bg_active_a

# ─── GLOBAL STAT REACTIONS ────────────────────────────────────────────
func _on_global_stat_changed(cid: String, stat: String, old_v: int, new_v: int) -> void:
	var delta: int = new_v - old_v
	var positive: bool = delta > 0
	var magnitude: int = absi(delta)

	UITheme.spawn_floating_stat(cid, stat, delta)

	if magnitude >= 15:
		var c: Color = UITheme.COLOR_GOOD if positive else UITheme.COLOR_BAD
		var prefix: String = "+" if positive else ""
		var label_name: String = str(GameState.characters.get(cid, {}).get("display_name", cid))
		UITheme.toast("%s  %s%d %s" % [label_name.to_upper(), prefix, delta, stat.to_upper()], c)

	if not positive and magnitude >= 10:
		UITheme.screen_shake(magnitude * 0.6, 0.35)
		UITheme.background_flash(UITheme.COLOR_BAD, 0.25)

	if positive and magnitude >= 10:
		UITheme.background_flash(UITheme.COLOR_GOOD, 0.20)
		UITheme.confetti(overlay_root, 36)

	var portrait: Control = _find_active_portrait()
	if portrait:
		if positive:
			UITheme.wiggle(portrait, 6.0, 2)
		else:
			UITheme.shake(portrait, magnitude * 0.7, 0.35)

# ─── SCENE LOOKUPS ────────────────────────────────────────────────────
func _find_dialog_text_panel() -> Control:
	return _search_for(get_tree().root, func(n: Node) -> bool:
		if n is Panel or n is PanelContainer:
			var nm := String(n.name).to_lower()
			return "dialog" in nm and "text" in nm
		return false
	)

func _find_active_portrait() -> Control:
	for n in get_tree().get_nodes_in_group("dialogic_portrait"):
		if n is Control and (n as Control).visible:
			return n
	return _search_for(get_tree().root, func(n: Node) -> bool:
		return n is Control and "portrait" in String(n.name).to_lower() and (n as Control).visible
	)

func _search_for(root: Node, predicate: Callable) -> Control:
	if predicate.call(root):
		return root as Control
	for child in root.get_children():
		var hit := _search_for(child, predicate)
		if hit:
			return hit
	return null
