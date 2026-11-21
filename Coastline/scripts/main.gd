extends Node3D

const WORLD_SIZE := 520.0
const ROAD_WIDTH := 18.0
const PLAYER_SPEED := 9.0
const CAR_SPEED := 34.0

var player: CharacterBody3D
var player_visual: Node3D
var player_left_leg: Node3D
var player_right_leg: Node3D
var player_left_arm: Node3D
var player_right_arm: Node3D
var player_anim_player: AnimationPlayer
var npc_anim_players: Dictionary = {}
var walk_phase := 0.0
var camera_pivot: Node3D
var camera: Camera3D
var car: Node3D
var driving := false
var car_velocity := 0.0
var car_yaw := 0.0
var mouse_captured := true
var hud: Label
var help_label: Label
var speed_label: Label
var sun: DirectionalLight3D
var impact_overlay: ColorRect
var impact_shake_time := 0.0
var impact_shake_strength := 0.0
var impact_flash_time := 0.0
var rng := RandomNumberGenerator.new()
var npcs: Array[Node3D] = []
var npc_directions: Dictionary = {}
var npc_walk_times: Dictionary = {}
var npc_animation_parts: Dictionary = {}
var npc_walk_phases: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	_setup_environment()
	_build_world()
	_create_player()
	_create_npcs()
	_create_car()
	_create_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.10, 0.30, 0.55)
	sky_mat.sky_horizon_color = Color(0.72, 0.83, 0.91)
	sky_mat.ground_bottom_color = Color(0.16, 0.20, 0.19)
	sky_mat.ground_horizon_color = Color(0.66, 0.72, 0.67)
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssr_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.22
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)

func _mat(color: Color, roughness := 0.82, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _mesh_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, node_name := "Box") -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	parent.add_child(n)
	return n

func _static_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_mesh_box(body, Vector3.ZERO, size, material)

func _build_world() -> void:
	var grass := _mat(Color(0.19, 0.36, 0.23))
	var sand := _mat(Color(0.79, 0.70, 0.49))
	var asphalt := _mat(Color(0.105, 0.12, 0.13), 0.96)
	var concrete := _mat(Color(0.48, 0.51, 0.49))
	var white := _mat(Color(0.91, 0.90, 0.80))
	var yellow := _mat(Color(0.95, 0.73, 0.22))
	var ocean := _mat(Color(0.035, 0.36, 0.51), 0.24, 0.18)
	_static_box(self, Vector3(0, -1.2, 0), Vector3(WORLD_SIZE, 2, WORLD_SIZE), grass)
	_mesh_box(self, Vector3(-WORLD_SIZE * 0.5 - 35, -1.4, 0), Vector3(110, 1, WORLD_SIZE + 100), ocean, "Ocean")
	_mesh_box(self, Vector3(-WORLD_SIZE * 0.5 + 18, -0.48, 0), Vector3(42, 0.35, WORLD_SIZE + 10), sand, "Beach")
	for z in [-180.0, -90.0, 0.0, 90.0, 180.0]:
		_mesh_box(self, Vector3(30, -0.12, z), Vector3(420, 0.22, ROAD_WIDTH), asphalt, "Boulevard")
		for x in range(-170, 231, 20):
			_mesh_box(self, Vector3(float(x), 0.015, z), Vector3(9, 0.035, 0.22), yellow, "LaneMark")
	for x in [-150.0, -60.0, 30.0, 120.0, 210.0]:
		_mesh_box(self, Vector3(x, -0.10, 0), Vector3(ROAD_WIDTH, 0.22, 410), asphalt, "CrossStreet")
		for z in range(-190, 211, 20):
			_mesh_box(self, Vector3(x, 0.02, float(z)), Vector3(0.22, 0.035, 9), white, "LaneMark")
	for gx in range(-2, 4):
		for gz in range(-2, 3):
			var cx := float(gx) * 90.0 + 30.0
			var cz := float(gz) * 90.0 + 45.0
			if abs(cx) > 225 or abs(cz) > 215:
				continue
			var count := rng.randi_range(2, 4)
			for i in range(count):
				var bx := cx + rng.randf_range(-26, 26)
				var bz := cz + rng.randf_range(-25, 25)
				var w := rng.randf_range(16, 30)
				var d := rng.randf_range(16, 30)
				var h := rng.randf_range(12, 52)
				# Keep building footprints out of every road corridor and its safety margin.
				var overlaps_road := false
				for road_z in [-180.0, -90.0, 0.0, 90.0, 180.0]:
					if abs(bz - road_z) < ROAD_WIDTH * 0.5 + d * 0.5 + 4.0:
						overlaps_road = true
						break
				if not overlaps_road:
					for road_x in [-150.0, -60.0, 30.0, 120.0, 210.0]:
						if abs(bx - road_x) < ROAD_WIDTH * 0.5 + w * 0.5 + 4.0:
							overlaps_road = true
							break
				if overlaps_road:
					continue
				var palette := [Color(0.78, 0.72, 0.61), Color(0.69, 0.74, 0.73), Color(0.84, 0.82, 0.74), Color(0.53, 0.62, 0.64), Color(0.78, 0.63, 0.49)]
				var building_mat := _mat(palette[rng.randi_range(0, palette.size() - 1)], 0.74)
				_static_box(self, Vector3(bx, h * 0.5, bz), Vector3(w, h, d), building_mat)
				_mesh_box(self, Vector3(bx, h + 0.25, bz), Vector3(w + 0.8, 0.5, d + 0.8), _mat(Color(0.22, 0.25, 0.26)))
				for floor in range(1, int(h / 5.0)):
					_mesh_box(self, Vector3(bx, float(floor) * 5.0, bz - d * 0.505), Vector3(w * 0.72, 1.2, 0.12), _mat(Color(0.12, 0.22, 0.27), 0.28, 0.25))
	for i in range(46):
		var px := rng.randf_range(-210, 230)
		var pz := rng.randf_range(-225, 225)
		if abs(px) < 14 or abs(pz) < 10:
			continue
		_create_palm(Vector3(px, 0, pz))
	_mesh_box(self, Vector3(-206, -0.1, 0), Vector3(3.5, 0.25, 500), concrete, "Promenade")

func _create_palm(pos: Vector3) -> void:
	var trunk_mat := _mat(Color(0.39, 0.25, 0.13))
	var leaf_mat := _mat(Color(0.10, 0.34, 0.18), 0.9)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.38
	cyl.height = 7.5
	trunk.mesh = cyl
	trunk.material_override = trunk_mat
	trunk.position = pos + Vector3(0, 3.75, 0)
	add_child(trunk)
	for j in range(7):
		var angle := TAU * float(j) / 7.0
		var leaf := MeshInstance3D.new()
		var blade := BoxMesh.new()
		blade.size = Vector3(0.8, 0.16, 5.0)
		leaf.mesh = blade
		leaf.material_override = leaf_mat
		leaf.position = pos + Vector3(cos(angle) * 1.6, 7.2, sin(angle) * 1.6)
		leaf.rotation.y = -angle
		leaf.rotation.x = -0.18
		add_child(leaf)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(-8, 0.725, 0)
	add_child(player)
	player_visual = Node3D.new()
	player_visual.name = "PlayerModel"
	player_visual.position.y = -0.925
	player.add_child(player_visual)
	var person := _instantiate_person("casual-man")
	if person:
		player_visual.add_child(person)
		player_anim_player = _find_animation_player(person)
		_play_person_animation(player_anim_player, "idle")
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.85
	collision.shape = shape
	player.add_child(collision)
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.45, 0)
	player.add_child(camera_pivot)
	var spring := SpringArm3D.new()
	spring.spring_length = 6.0
	spring.margin = 0.25
	camera_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 74
	spring.add_child(camera)

func _instantiate_person(model_name: String) -> Node3D:
	var path := "res://assets/people/" + model_name + ".glb"
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Missing person model: " + path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance:
		instance.name = model_name
	return instance

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _play_person_animation(anim_player: AnimationPlayer, wanted: String) -> void:
	if anim_player == null:
		return
	for animation_name in anim_player.get_animation_list():
		if String(animation_name).to_lower().contains(wanted.to_lower()):
			if anim_player.current_animation != animation_name:
				anim_player.play(animation_name)
			return

func _create_npcs() -> void:
	var positions := [
		Vector3(-125, 0.0, -145), Vector3(-82, 0.0, -128),
		Vector3(-35, 0.0, -55), Vector3(5, 0.0, -58),
		Vector3(68, 0.0, 38), Vector3(105, 0.0, 57),
		Vector3(155, 0.0, 128), Vector3(185, 0.0, 145),
		Vector3(-175, 0.0, 55), Vector3(-195, 0.0, 78),
		Vector3(55, 0.0, 175), Vector3(95, 0.0, 195)
	]
	var models := ["casual-man", "casual-woman", "business-man", "business-woman", "construction-worker", "doctor", "runner"]
	for i in range(positions.size()):
		var npc := Node3D.new()
		npc.name = "Pedestrian_%02d" % i
		npc.position = positions[i]
		add_child(npc)
		var person := _instantiate_person(models[i % models.size()])
		if person:
			npc.add_child(person)
			var anim_player := _find_animation_player(person)
			npc_anim_players[npc.get_instance_id()] = anim_player
			_play_person_animation(anim_player, "walk")
		npcs.append(npc)
		var key := npc.get_instance_id()
		npc_directions[key] = (1.0 if i % 2 == 0 else -1.0)
		npc_walk_times[key] = rng.randf_range(2.0, 5.0)

func _create_car() -> void:
	car = Node3D.new()
	car.name = "PlayerCar"
	car.position = Vector3(10, 0.65, 4)
	add_child(car)
	var paint := _mat(Color(0.72, 0.16, 0.10), 0.27, 0.48)
	var glass := _mat(Color(0.08, 0.16, 0.20), 0.2, 0.2)
	_mesh_box(car, Vector3(0, 0.35, 0), Vector3(2.15, 0.65, 4.2), paint, "CarBody")
	_mesh_box(car, Vector3(0, 0.92, -0.25), Vector3(1.72, 0.78, 2.0), glass, "Cabin")
	for x in [-1.05, 1.05]:
		for z in [-1.35, 1.35]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.39
			wheel_mesh.bottom_radius = 0.39
			wheel_mesh.height = 0.24
			wheel.mesh = wheel_mesh
			wheel.material_override = _mat(Color(0.035, 0.04, 0.045))
			wheel.position = Vector3(x, 0.25, z)
			wheel.rotation.z = PI / 2
			car.add_child(wheel)
	var light_mat := _mat(Color(1.0, 0.88, 0.58), 0.25)
	for x in [-0.72, 0.72]:
		_mesh_box(car, Vector3(x, 0.43, -2.12), Vector3(0.42, 0.18, 0.08), light_mat, "Headlight")

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color(1, 1, 1))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)
	help_label = Label.new()
	help_label.position = Vector2(24, 650)
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(help_label)
	speed_label = Label.new()
	speed_label.position = Vector2(1090, 645)
	speed_label.add_theme_font_size_override("font_size", 24)
	speed_label.add_theme_color_override("font_color", Color(1, 1, 1))
	layer.add_child(speed_label)
	impact_overlay = ColorRect.new()
	impact_overlay.name = "ImpactRedFlash"
	impact_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	impact_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_overlay.color = Color(0.72, 0.015, 0.025, 0.0)
	impact_overlay.z_index = 100
	layer.add_child(impact_overlay)
	_update_hud()

func _update_hud() -> void:
	hud.text = "COASTLINE  |  FREE ROAM"
	if driving:
		help_label.text = "WASD Drive   •   Mouse Look   •   E Exit   •   ESC Release Mouse"
		speed_label.text = "%03d km/h" % int(abs(car_velocity) * 3.0)
	else:
		help_label.text = "WASD Move   •   Shift Run   •   Space Jump   •   E Enter Car   •   Mouse Look   •   ESC Mouse"
		speed_label.text = "ON FOOT"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		mouse_captured = not mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and mouse_captured:
		if driving:
			car_yaw -= event.relative.x * 0.0025
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * 0.002, -0.45, 0.25)
		else:
			player.rotation.y -= event.relative.x * 0.0025
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * 0.002, -0.65, 0.35)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if driving:
			_exit_car()
		elif player.global_position.distance_to(car.global_position) < 4.5:
			_enter_car()

func _physics_process(delta: float) -> void:
	_update_npcs(delta)
	if driving:
		_drive_car(delta)
	else:
		_move_player(delta)
	_update_camera()
	_update_impact_effects(delta)
	_update_hud()

func _move_player(delta: float) -> void:
	var input := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var direction := (player.global_transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := PLAYER_SPEED * (1.65 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if direction.length() > 0.01:
		player.velocity.x = direction.x * speed
		player.velocity.z = direction.z * speed
		player_visual.rotation.y = lerp_angle(player_visual.rotation.y, atan2(direction.x, direction.z), delta * 10.0)
		_play_person_animation(player_anim_player, "run" if Input.is_key_pressed(KEY_SHIFT) else "walk")
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, 24 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, 24 * delta)
		walk_phase = 0.0
		_play_person_animation(player_anim_player, "idle")
	if player.is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			player.velocity.y = 6.0
	else:
		player.velocity.y -= 18.0 * delta
	player.move_and_slide()
	player.global_position.x = clamp(player.global_position.x, -238, 238)
	player.global_position.z = clamp(player.global_position.z, -238, 238)

func _update_npcs(delta: float) -> void:
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var key := npc.get_instance_id()
		var direction: float = npc_directions.get(key, 1.0)
		var remaining: float = npc_walk_times.get(key, 2.0) - delta
		if remaining <= 0.0:
			direction *= -1.0
			remaining = rng.randf_range(2.0, 5.0)
		npc_directions[key] = direction
		npc_walk_times[key] = remaining
		npc.position.x += direction * 0.75 * delta
		npc.rotation.y = PI / 2.0 if direction > 0.0 else -PI / 2.0

func _check_car_pedestrian_collisions() -> void:
	if abs(car_velocity) < 5.0:
		return
	for npc in npcs.duplicate():
		if is_instance_valid(npc) and npc.global_position.distance_to(car.global_position) < 2.25:
			_spawn_npc_ragdoll(npc)

func _spawn_npc_ragdoll(npc: Node3D) -> void:
	_trigger_impact_effect()
	var origin := npc.global_position
	var key := npc.get_instance_id()
	npcs.erase(npc)
	npc_directions.erase(key)
	npc_walk_times.erase(key)
	npc_anim_players.erase(key)
	_spawn_impact_sparks(origin + Vector3(0, 0.9, 0))
	# Keep the imported human model intact and give it a brief, non-graphic fall reaction.
	var fall_tween := create_tween()
	fall_tween.tween_property(npc, "rotation:z", PI * 0.42, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall_tween.tween_interval(2.0)
	fall_tween.tween_callback(npc.queue_free)

func _spawn_impact_sparks(origin: Vector3) -> void:
	# Abstract red impact particles: decorative game feedback, not injury detail.
	for i in range(12):
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.035, 0.065)
		mesh.height = mesh.radius * 2.0
		spark.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.035, 0.045, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.8, 0.015, 0.02)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.material_override = material
		spark.global_position = origin
		add_child(spark)
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.1, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", origin + direction * rng.randf_range(0.55, 1.25), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(spark.queue_free)

func _trigger_impact_effect() -> void:
	var impact_strength := clamp(abs(car_velocity) / CAR_SPEED, 0.25, 1.0)
	impact_shake_time = max(impact_shake_time, 0.28)
	impact_shake_strength = max(impact_shake_strength, 0.035 + impact_strength * 0.075)
	impact_flash_time = max(impact_flash_time, 0.32)

func _update_impact_effects(delta: float) -> void:
	impact_shake_time = max(0.0, impact_shake_time - delta)
	impact_flash_time = max(0.0, impact_flash_time - delta)
	if impact_shake_time > 0.0:
		var fade := impact_shake_time / 0.28
		camera.rotation = Vector3(
			rng.randf_range(-1.0, 1.0) * impact_shake_strength * fade,
			rng.randf_range(-1.0, 1.0) * impact_shake_strength * fade,
			rng.randf_range(-1.0, 1.0) * impact_shake_strength * fade * 0.45
		)
	else:
		camera.rotation = Vector3.ZERO
	if impact_flash_time > 0.0:
		impact_overlay.color = Color(0.72, 0.015, 0.025, 0.42 * (impact_flash_time / 0.32))
	else:
		impact_overlay.color = Color(0.72, 0.015, 0.025, 0.0)

func _drive_car(delta: float) -> void:
	var throttle := float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var steer := float(Input.is_key_pressed(KEY_A)) - float(Input.is_key_pressed(KEY_D))
	car_velocity = move_toward(car_velocity, throttle * CAR_SPEED, (22.0 if throttle != 0 else 12.0) * delta)
	if abs(car_velocity) > 0.5:
		car_yaw += steer * delta * 1.55 * sign(car_velocity) * clamp(abs(car_velocity) / 12.0, 0.25, 1.0)
	car.rotation.y = car_yaw
	car.position += -car.global_transform.basis.z * car_velocity * delta
	car.position.x = clamp(car.position.x, -238, 238)
	car.position.z = clamp(car.position.z, -238, 238)
	car.position.y = 0.65
	_check_car_pedestrian_collisions()
	if Input.is_key_pressed(KEY_SPACE):
		car_velocity = move_toward(car_velocity, 0, 28 * delta)

func _enter_car() -> void:
	driving = true
	player.visible = false
	car_yaw = car.rotation.y
	camera_pivot.rotation.x = -0.12

func _exit_car() -> void:
	driving = false
	player.visible = true
	player.global_position = car.global_position + car.global_transform.basis.x * 2.4 + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	car_velocity = 0.0

func _update_camera() -> void:
	if driving:
		camera_pivot.global_position = car.global_position + Vector3(0, 1.9, 0)
		camera_pivot.rotation.y = car_yaw
	else:
		camera_pivot.rotation.y = player.rotation.y
