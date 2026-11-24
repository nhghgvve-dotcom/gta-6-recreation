extends Control

const SPLASH_DURATION := 20.0
const GAME_SCENE := "res://Main.tscn"
const SPLASH_TEXTURE: Texture2D = preload("res://assets/living_room_studios_boot_splash.svg")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#080f22")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var splash := TextureRect.new()
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.texture = SPLASH_TEXTURE
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(splash)

	# Render the branding as native Godot labels so it remains readable
	# even if SVG text is not rendered by a particular export/import setup.
	_add_splash_label("LIVING ROOM STUDIOS", 0.105, 0.205, 26, Color("#d8e7ff"), 5)
	_add_splash_label("COASTLINE", 0.755, 0.875, 58, Color("#ffffff"), 7)
	_add_splash_label("YOUR CITY. YOUR STORY.", 0.875, 0.945, 22, Color("#72d7dc"), 4)

	await get_tree().create_timer(SPLASH_DURATION).timeout
	get_tree().change_scene_to_file(GAME_SCENE)


func _add_splash_label(label_text: String, top_anchor: float, bottom_anchor: float, font_size: int, font_color: Color, outline_size: int) -> void:
	var label := Label.new()
	label.text = label_text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.anchor_top = top_anchor
	label.anchor_bottom = bottom_anchor
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.offset_top = 0.0
	label.offset_bottom = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color("#081020"))
	label.add_theme_constant_override("outline_size", outline_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
