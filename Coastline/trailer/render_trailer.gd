extends SceneTree

const FRAMES_PER_SHOT := 72
const OUTPUT_DIR := "res://../trailer/frames"

var frame_number := 1

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://Main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load Coastline Main.tscn")
		quit(1)
		return

	var game := packed.instantiate()
	root.add_child(game)
	for i in range(8):
		await process_frame
		await RenderingServer.frame_post_draw

	var camera: Camera3D = game.get("camera")
	if camera == null:
		push_error("Coastline camera was not created")
		quit(1)
		return

	camera.top_level = true
	camera.current = true
	camera.fov = 58.0
	for child in game.get_children():
		if child is CanvasLayer:
			child.visible = false

	# Six cinematic camera passes through the actual procedurally-built Coastline map.
	await _shot(camera, Vector3(-30, 150, 285), Vector3(30, 118, 210), Vector3(0, 0, 0), Vector3(25, 0, -15))
	await _shot(camera, Vector3(-225, 18, -155), Vector3(-95, 13, -165), Vector3(-80, 5, -180), Vector3(45, 8, -180))
	await _shot(camera, Vector3(115, 52, 100), Vector3(65, 36, 35), Vector3(25, 12, 0), Vector3(-40, 10, -45))
	await _shot(camera, Vector3(-220, 18, 25), Vector3(-180, 13, 15), Vector3(-85, 7, 10), Vector3(-35, 10, -10))
	await _shot(camera, Vector3(205, 82, -205), Vector3(125, 58, -125), Vector3(60, 12, -70), Vector3(10, 8, -25))
	await _shot(camera, Vector3(250, 42, 185), Vector3(165, 28, 95), Vector3(95, 10, 35), Vector3(20, 8, -20))

	print("Rendered ", frame_number - 1, " Coastline frames.")
	quit(0)

func _shot(camera: Camera3D, start_pos: Vector3, end_pos: Vector3, start_target: Vector3, end_target: Vector3) -> void:
	for i in range(FRAMES_PER_SHOT):
		var blend := float(i) / float(FRAMES_PER_SHOT - 1)
		var eased := blend * blend * (3.0 - 2.0 * blend)
		camera.global_position = start_pos.lerp(end_pos, eased)
		camera.look_at(start_target.lerp(end_target, eased), Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_viewport().get_texture().get_image()
		if frame.is_empty():
			push_error("Viewport returned an empty frame at " + str(frame_number))
			quit(1)
			return
		var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/frame_%04d.png" % frame_number)
		var error := frame.save_png(path)
		if error != OK:
			push_error("Could not save " + path + ": " + str(error))
			quit(1)
			return
		frame_number += 1
