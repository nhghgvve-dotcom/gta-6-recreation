extends SceneTree

const FRAMES_PER_SHOT := 72
const OUTPUT_DIR := "res://../trailer/frames"

var frame_number := 1
var trailer_helicopters: Array[Node3D] = []
var trailer_rotors: Array[Node3D] = []

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
	_create_trailer_helicopters(game)
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
	# Helicopter reveal: pull back over downtown as two police choppers cross the skyline.
	await _shot(camera, Vector3(175, 88, -210), Vector3(80, 68, -135), Vector3(25, 48, -55), Vector3(-15, 42, -20))
	await _shot(camera, Vector3(-115, 58, -95), Vector3(-25, 48, -35), Vector3(15, 46, -55), Vector3(40, 42, -35))

	print("Rendered ", frame_number - 1, " Coastline frames.")
	quit(0)

func _create_trailer_helicopters(game: Node3D) -> void:
	var helicopter_scene := load("res://assets/vehicles/police-helicopter.glb") as PackedScene
	if helicopter_scene == null:
		push_error("The Coastline police helicopter asset is missing; trailer cannot render its helicopter reveal.")
		quit(1)
		return
	for index in range(2):
		var helicopter := helicopter_scene.instantiate() as Node3D
		if helicopter == null:
			continue
		helicopter.name = "TrailerPoliceChopper_%02d" % index
		helicopter.scale = Vector3.ONE * (0.85 if index == 0 else 0.72)
		helicopter.visible = false
		game.add_child(helicopter)
		trailer_helicopters.append(helicopter)
		_collect_trailer_rotors(helicopter)

func _collect_trailer_rotors(node: Node) -> void:
	if node is Node3D and String(node.name).to_lower().contains("rotor"):
		trailer_rotors.append(node as Node3D)
	for child in node.get_children():
		_collect_trailer_rotors(child)

func _animate_trailer_helicopters() -> void:
	if frame_number < 289:
		return
	var reveal_progress := clampf(float(frame_number - 289) / 143.0, 0.0, 1.0)
	var first_start := Vector3(-145.0, 67.0, -125.0)
	var first_end := Vector3(105.0, 61.0, -35.0)
	var second_start := Vector3(145.0, 79.0, -185.0)
	var second_end := Vector3(-95.0, 72.0, -75.0)
	for index in range(trailer_helicopters.size()):
		var helicopter := trailer_helicopters[index]
		helicopter.visible = true
		var from_position := first_start if index == 0 else second_start
		var to_position := first_end if index == 0 else second_end
		helicopter.global_position = from_position.lerp(to_position, reveal_progress)
		helicopter.look_at(Vector3(15.0, helicopter.global_position.y - 8.0, -45.0), Vector3.UP)
	for rotor in trailer_rotors:
		if is_instance_valid(rotor):
			rotor.rotate_y(0.72)

func _shot(camera: Camera3D, start_pos: Vector3, end_pos: Vector3, start_target: Vector3, end_target: Vector3) -> void:
	for i in range(FRAMES_PER_SHOT):
		var blend := float(i) / float(FRAMES_PER_SHOT - 1)
		var eased := blend * blend * (3.0 - 2.0 * blend)
		camera.global_position = start_pos.lerp(end_pos, eased)
		camera.look_at(start_target.lerp(end_target, eased), Vector3.UP)
		_animate_trailer_helicopters()
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
