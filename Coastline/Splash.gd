extends Control

const SPLASH_DURATION := 20.0
const GAME_SCENE := "res://Main.tscn"
const SPLASH_IMAGE := "res://assets/living_room_studios_boot_splash.svg"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#080f22")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var splash_texture := load(SPLASH_IMAGE) as Texture2D
	if splash_texture != null:
		var splash := TextureRect.new()
		splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		splash.texture = splash_texture
		splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(splash)
	else:
		push_warning("Coastline splash artwork could not be loaded.")

	await get_tree().create_timer(SPLASH_DURATION).timeout
	get_tree().change_scene_to_file(GAME_SCENE)
