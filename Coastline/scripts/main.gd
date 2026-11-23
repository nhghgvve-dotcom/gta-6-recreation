extends Node3D

const WORLD_SIZE := 520.0
const ROAD_WIDTH := 18.0
const PLAYER_SPEED := 5.2
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
var camera_spring: SpringArm3D
var car: Node3D
var car_model: Node3D
var car_wheels: Array[Node3D] = []
var traffic_cars: Array[Node3D] = []
var traffic_speeds: Array[float] = []
var available_cars: Array[Node3D] = []
var car_entry_in_progress := false
var driving := false
var car_velocity := 0.0
var car_yaw := 0.0
var mouse_captured := true
var is_paused := false
var pause_layer: CanvasLayer
var settings_panel: PanelContainer
var fullscreen_button: Button
var pause_buttons: Array[Button] = []
var pause_selected_index := 0
var pause_stick_y := 0.0
var pause_stick_repeat := 0.0
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
var npc_states: Dictionary = {}
var npc_alert_times: Dictionary = {}
var npc_hit_counts: Dictionary = {}
var weapon_menu_open := false
var selected_weapon := "FISTS"
var weapon_menu_layer: CanvasLayer
var weapon_visual: Node3D
var fire_cooldown := 0.0
var engine_audio: AudioStreamPlayer
var footstep_audio: AudioStreamPlayer
var door_audio: AudioStreamPlayer
var energy_audio: AudioStreamPlayer
var footstep_timer := 0.0
var wanted_level := 0
var police_officer_scene: PackedScene
var police_helicopter_scene: PackedScene
var police_car_scene: PackedScene
var police_units: Array[Node3D] = []
var police_foot_units: Array[Node3D] = []
var police_fire_cooldowns: Dictionary = {}
var player_hits := 0
var player_dead := false
var death_layer: CanvasLayer
var police_helicopter: Node3D
var police_rotors: Array[Node3D] = []
var helicopter_orbit := 0.0
var xr_interface: XRInterface
var vr_enabled := false
var vr_left_hand: XRController3D
var vr_right_hand: XRController3D
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var vr_left_hand_model: Node3D
var vr_right_hand_model: Node3D
var tracked_left_hand: XRNode3D
var tracked_right_hand: XRNode3D
var mission_state := "available"
var mission_cash := 0
var mission_tokens := 0
var mission_marker: Node3D
var getaway_marker: Node3D
var mission_pickups: Array[Node3D] = []
var mission_status_label: Label
var mobile_controls_root: Control
var mobile_joystick_knob: Panel
var mobile_joystick_touch_id := -1
var mobile_look_touch_id := -1
var mobile_joystick_center := Vector2.ZERO
var mobile_joystick_radius := 58.0
var remote_server := TCPServer.new()
var remote_clients: Array[Dictionary] = []
var remote_move := Vector2.ZERO
var remote_look := Vector2.ZERO
var remote_last_input_msec := 0
var remote_controller_url := ""
var remote_status_label: Label

func _ready() -> void:
	_setup_controller_inputs()
	_start_remote_controller()
	_setup_vr()
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_environment()
	_setup_audio()
	_build_world()
	_create_mission_world()
	_create_player()
	_create_npcs()
	_create_car()
	_create_traffic()
	_load_police_assets()
	_create_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_vr() -> void:
	# OpenXR activates PC-VR when a compatible runtime/headset is available.
	# If no headset is connected, Coastline remains in regular desktop mode.
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		print("OpenXR runtime not found; starting desktop mode.")
		return
	if not xr_interface.is_initialized() and not xr_interface.initialize():
		push_warning("OpenXR could not initialize. Starting desktop mode.")
		xr_interface = null
		return
	get_viewport().use_xr = true
	vr_enabled = true
	print("Coastline VR enabled through OpenXR.")
	# Tracked controllers are attached under XROrigin once the player rig exists.

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.075, 0.055, 0.19)
	sky_mat.sky_horizon_color = Color(0.92, 0.34, 0.43)
	sky_mat.ground_bottom_color = Color(0.10, 0.12, 0.20)
	sky_mat.ground_horizon_color = Color(0.66, 0.31, 0.39)
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssr_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_bloom = 0.08
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.03
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.035
	add_child(sun)


func _setup_audio() -> void:
	engine_audio = AudioStreamPlayer.new()
	engine_audio.name = "CarEngineAudio"
	engine_audio.stream = _make_sfx_stream(58.0, 1.2, 0.16, 0.12, true)
	engine_audio.volume_db = -13.0
	add_child(engine_audio)
	footstep_audio = AudioStreamPlayer.new()
	footstep_audio.name = "FootstepAudio"
	footstep_audio.stream = _make_sfx_stream(105.0, 0.12, 0.34, 0.48, false)
	footstep_audio.volume_db = -8.0
	add_child(footstep_audio)
	door_audio = AudioStreamPlayer.new()
	door_audio.name = "VehicleDoorAudio"
	door_audio.stream = _make_sfx_stream(92.0, 0.28, 0.42, 0.24, false)
	door_audio.volume_db = -5.0
	add_child(door_audio)
	energy_audio = AudioStreamPlayer.new()
	energy_audio.name = "ArcadeEnergyAudio"
	energy_audio.stream = _make_sfx_stream(620.0, 0.19, 0.38, 0.52, false)
	energy_audio.volume_db = -8.0
	add_child(energy_audio)

func _make_sfx_stream(frequency: float, duration: float, amplitude: float, noise_mix: float, looping: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var envelope := 1.0 if looping else exp(-t * 8.0)
		var tone := sin(TAU * frequency * t) * (1.0 - noise_mix)
		var noise: float = rng.randf_range(-1.0, 1.0) * noise_mix
		var value: float = clampf((tone + noise) * amplitude * envelope, -1.0, 1.0)
		var pcm_sample := int(value * 32767.0)
		samples[i * 2] = pcm_sample & 0xFF
		samples[i * 2 + 1] = (pcm_sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream

func _update_audio(delta: float) -> void:
	if driving:
		if not engine_audio.playing:
			engine_audio.play()
		engine_audio.pitch_scale = clamp(0.72 + abs(car_velocity) / 30.0, 0.72, 1.75)
	else:
		if engine_audio.playing:
			engine_audio.stop()
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0 and player.is_on_floor()
		if moving:
			footstep_timer -= delta
			if footstep_timer <= 0.0:
				footstep_audio.pitch_scale = rng.randf_range(0.88, 1.12)
				footstep_audio.play()
				footstep_timer = 0.38 if Input.is_action_pressed("sprint") else 0.52
		else:
			footstep_timer = 0.0

func _setup_controller_inputs() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("interact", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)
	_add_key_action("weapon_wheel", KEY_K)
	for action in ["fire", "weapon_prev", "weapon_next"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_key_action("vehicle_brake", KEY_SPACE)
	_add_joy_button("vehicle_brake", JOY_BUTTON_B)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button("interact", JOY_BUTTON_Y)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)
	_add_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button("weapon_wheel", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("weapon_prev", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("weapon_next", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)

func _add_key_action(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _add_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func _controller_look(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() < 0.16:
		return
	if driving:
		car_yaw -= stick.x * 2.4 * delta
	else:
		player.rotation.y -= stick.x * 2.4 * delta
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x + stick.y * 1.8 * delta, -0.65, 0.35)

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
	# Denser city blocks: add more compact mid-rise buildings while keeping
	# every footprint outside the road corridors and their safety margins.
	for gx in range(-2, 4):
		for gz in range(-2, 3):
			var cx := float(gx) * 90.0 + 30.0
			var cz := float(gz) * 90.0 + 45.0
			if abs(cx) > 225 or abs(cz) > 215:
				continue
			var count := rng.randi_range(4, 6)
			for i in range(count):
				var bx := cx + rng.randf_range(-31, 31)
				var bz := cz + rng.randf_range(-30, 30)
				var w := rng.randf_range(12, 24)
				var d := rng.randf_range(12, 24)
				var h := rng.randf_range(14, 64)
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
				var palette := [Color(0.88, 0.56, 0.52), Color(0.77, 0.65, 0.78), Color(0.90, 0.78, 0.59), Color(0.49, 0.68, 0.73), Color(0.84, 0.62, 0.49)]
				var building_mat := _mat(palette[rng.randi_range(0, palette.size() - 1)], 0.74)
				_static_box(self, Vector3(bx, h * 0.5, bz), Vector3(w, h, d), building_mat)
				_mesh_box(self, Vector3(bx, h + 0.25, bz), Vector3(w + 0.8, 0.5, d + 0.8), _mat(Color(0.22, 0.25, 0.26)))
				var window_mat := _mat(Color(0.12, 0.22, 0.27), 0.28, 0.25)
				for floor in range(1, int(h / 5.0)):
					_mesh_box(self, Vector3(bx, float(floor) * 5.0, bz - d * 0.505), Vector3(w * 0.72, 1.2, 0.12), window_mat)
					_mesh_box(self, Vector3(bx + w * 0.505, float(floor) * 5.0, bz), Vector3(0.12, 1.2, d * 0.62), window_mat)
	for i in range(46):
		var px := rng.randf_range(-210, 230)
		var pz := rng.randf_range(-225, 225)
		if abs(px) < 14 or abs(pz) < 10:
			continue
		_create_palm(Vector3(px, 0, pz))
	# Raised, walkable-looking sidewalks run beside every main road.
	var sidewalk_mat := _mat(Color(0.62, 0.57, 0.57), 0.9)
	for road_z in [-180.0, -90.0, 0.0, 90.0, 180.0]:
		for side in [-1.0, 1.0]:
			_mesh_box(self, Vector3(30, 0.06, road_z + side * (ROAD_WIDTH * 0.5 + 3.5)), Vector3(420, 0.18, 5.5), sidewalk_mat, "Sidewalk")
	for road_x in [-150.0, -60.0, 30.0, 120.0, 210.0]:
		for side in [-1.0, 1.0]:
			_mesh_box(self, Vector3(road_x + side * (ROAD_WIDTH * 0.5 + 3.5), 0.06, 0), Vector3(5.5, 0.18, 410), sidewalk_mat, "Sidewalk")
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
	camera_spring = SpringArm3D.new()
	camera_spring.spring_length = 6.0
	camera_spring.margin = 0.25
	camera_spring.spring_length = 0.0 if vr_enabled else 6.0
	camera_pivot.add_child(camera_spring)
	camera = Camera3D.new()
	camera.fov = 74
	camera_spring.add_child(camera)
	if vr_enabled:
		camera.current = false
		xr_origin = XROrigin3D.new()
		xr_origin.name = "XROrigin"
		xr_origin.position.y = -0.55
		player.add_child(xr_origin)
		xr_camera = XRCamera3D.new()
		xr_camera.name = "XRCamera"
		xr_origin.add_child(xr_camera)
		xr_camera.current = true
		vr_left_hand = XRController3D.new()
		vr_left_hand.name = "VRLeftController"
		vr_left_hand.tracker = "left_hand"
		vr_left_hand.pose = "default"
		xr_origin.add_child(vr_left_hand)
		vr_left_hand_model = _create_vr_hand_model(vr_left_hand, -1.0)
		vr_right_hand = XRController3D.new()
		vr_right_hand.name = "VRRightController"
		vr_right_hand.tracker = "right_hand"
		vr_right_hand.pose = "default"
		xr_origin.add_child(vr_right_hand)
		vr_right_hand_model = _create_vr_hand_model(vr_right_hand, 1.0)
		# Separate OpenXR hand trackers let Quest users switch to optical hand tracking.
		tracked_left_hand = XRNode3D.new()
		tracked_left_hand.name = "TrackedLeftHand"
		tracked_left_hand.set("tracker", "/user/hand_tracker/left")
		tracked_left_hand.set("pose", "default")
		xr_origin.add_child(tracked_left_hand)
		_create_vr_hand_model(tracked_left_hand, -1.0)
		tracked_right_hand = XRNode3D.new()
		tracked_right_hand.name = "TrackedRightHand"
		tracked_right_hand.set("tracker", "/user/hand_tracker/right")
		tracked_right_hand.set("pose", "default")
		xr_origin.add_child(tracked_right_hand)
		_create_vr_hand_model(tracked_right_hand, 1.0)
	_create_weapon_visual()

func _create_vr_hand_model(parent: Node3D, side: float) -> Node3D:
	# Lightweight stylized hands built from meshes so they work without extra downloads.
	var hand := Node3D.new()
	hand.name = "VRHandModel"
	parent.add_child(hand)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.57, 0.43)
	skin.roughness = 0.88
	var palm := MeshInstance3D.new()
	var palm_mesh := SphereMesh.new()
	palm_mesh.radius = 0.065
	palm_mesh.height = 0.13
	palm.mesh = palm_mesh
	palm.scale = Vector3(1.0, 0.42, 1.22)
	palm.position = Vector3(0, 0, -0.045)
	palm.material_override = skin
	hand.add_child(palm)
	for finger_index in range(4):
		var finger := MeshInstance3D.new()
		var finger_mesh := CapsuleMesh.new()
		finger_mesh.radius = 0.012
		finger_mesh.height = 0.075 if finger_index == 0 or finger_index == 3 else 0.09
		finger.mesh = finger_mesh
		finger.rotation.x = PI * 0.5
		finger.position = Vector3((float(finger_index) - 1.5) * 0.027, 0, -0.135)
		finger.material_override = skin
		hand.add_child(finger)
	var thumb := MeshInstance3D.new()
	var thumb_mesh := CapsuleMesh.new()
	thumb_mesh.radius = 0.014
	thumb_mesh.height = 0.065
	thumb.mesh = thumb_mesh
	thumb.rotation = Vector3(0.0, 0.0, side * -0.72)
	thumb.position = Vector3(side * 0.075, 0, -0.055)
	thumb.material_override = skin
	hand.add_child(thumb)
	return hand

func _update_vr_hands() -> void:
	if not vr_enabled:
		return
	var left_tracker := XRServer.get_tracker("/user/hand_tracker/left") as XRHandTracker
	var right_tracker := XRServer.get_tracker("/user/hand_tracker/right") as XRHandTracker
	var left_optical := left_tracker != null and left_tracker.has_tracking_data
	var right_optical := right_tracker != null and right_tracker.has_tracking_data
	if tracked_left_hand:
		tracked_left_hand.visible = left_optical
	if tracked_right_hand:
		tracked_right_hand.visible = right_optical
	if vr_left_hand_model:
		vr_left_hand_model.visible = not left_optical
	if vr_right_hand_model:
		vr_right_hand_model.visible = not right_optical

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

func _create_weapon_visual() -> void:
	# Attach the fictional energy emitter to the animated character's right hand.
	weapon_visual = Node3D.new()
	weapon_visual.name = "ArcadeEnergyEmitter"
	var skeleton := _find_skeleton(player_visual)
	var hand_bone := -1
	if skeleton:
		for i in range(skeleton.get_bone_count()):
			var bone_name := skeleton.get_bone_name(i).to_lower()
			if bone_name.contains("right") and (bone_name.contains("hand") or bone_name.contains("wrist")):
				hand_bone = i
				break
	if skeleton and hand_bone >= 0:
		var hand_attachment := BoneAttachment3D.new()
		hand_attachment.name = "RightHandWeaponAttachment"
		hand_attachment.bone_name = skeleton.get_bone_name(hand_bone)
		skeleton.add_child(hand_attachment)
		hand_attachment.add_child(weapon_visual)
		weapon_visual.position = Vector3(0.045, 0.015, -0.035)
	else:
		player_visual.add_child(weapon_visual)
		weapon_visual.position = Vector3(0.28, 1.05, -0.28)
		push_warning("Right-hand bone not found; using character-side attachment.")
	var body_mat := _mat(Color(0.055, 0.12, 0.17), 0.28, 0.55)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.08, 0.8, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.02, 0.65, 1.0)
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_box(weapon_visual, Vector3(0, 0, 0), Vector3(0.16, 0.16, 0.48), body_mat, "EmitterBody")
	_mesh_box(weapon_visual, Vector3(0, 0.015, -0.28), Vector3(0.11, 0.11, 0.22), glow_mat, "EnergyCoil")
	_mesh_box(weapon_visual, Vector3(0, -0.13, 0.08), Vector3(0.12, 0.22, 0.14), body_mat, "Grip")
	weapon_visual.visible = selected_weapon != "FISTS"

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _create_weapon_menu() -> void:
	weapon_menu_layer = CanvasLayer.new()
	weapon_menu_layer.name = "WeaponWheel"
	weapon_menu_layer.layer = 15
	weapon_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(weapon_menu_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.012, 0.025, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	weapon_menu_layer.add_child(dim)
	var wheel := Control.new()
	wheel.set_anchors_preset(Control.PRESET_CENTER)
	wheel.position = Vector2(-215, -215)
	wheel.size = Vector2(430, 430)
	dim.add_child(wheel)
	var ring := Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0.035, 0.075, 0.11, 0.94)
	ring_style.border_color = Color(0.22, 0.72, 0.86, 0.95)
	ring_style.set_border_width_all(3)
	ring_style.set_corner_radius_all(215)
	ring.add_theme_stylebox_override("panel", ring_style)
	wheel.add_child(ring)
	var title := Label.new()
	title.text = "WEAPON SELECT"
	title.position = Vector2(110, 76)
	title.size = Vector2(210, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	wheel.add_child(title)
	var hint := Label.new()
	hint.text = "HOLD K  •  CLICK A SLOT"
	hint.position = Vector2(105, 324)
	hint.size = Vector2(220, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.72, 0.82))
	wheel.add_child(hint)
	var fists := _make_weapon_button("FISTS", "Unarmed")
	fists.position = Vector2(34, 174)
	fists.pressed.connect(_select_weapon.bind("FISTS"))
	wheel.add_child(fists)
	var pulse := _make_weapon_button("PULSE", "Energy")
	pulse.position = Vector2(235, 174)
	pulse.pressed.connect(_select_weapon.bind("PULSE"))
	wheel.add_child(pulse)
	var arc := _make_weapon_button("ARC", "Arc bolts")
	arc.position = Vector2(135, 258)
	arc.pressed.connect(_select_weapon.bind("ARC"))
	wheel.add_child(arc)
	weapon_menu_layer.visible = false

func _make_weapon_button(caption: String, subcaption: String) -> Button:
	var button := Button.new()
	button.text = caption + "\n" + subcaption
	button.custom_minimum_size = Vector2(160, 66)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.91, 0.98, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.15, 0.21, 0.98)
	normal.border_color = Color(0.19, 0.43, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.08, 0.32, 0.4, 1.0)
	hover.border_color = Color(0.25, 0.85, 1.0)
	hover.set_border_width_all(3)
	hover.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button

func _select_weapon(weapon_name: String) -> void:
	selected_weapon = weapon_name
	if is_instance_valid(weapon_visual):
		weapon_visual.visible = selected_weapon != "FISTS"
	if weapon_menu_open:
		weapon_menu_layer.visible = false
		weapon_menu_open = false
		mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()

func _fire_selected_weapon() -> void:
	if selected_weapon == "FISTS":
		return
	energy_audio.pitch_scale = rng.randf_range(0.9, 1.12)
	energy_audio.play()
	# Stylized arcade energy shot: a direct, forgiving crosshair check.
	fire_cooldown = 0.22 if selected_weapon == "PULSE" else 0.42
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z.normalized()
	var nearest_npc: Node3D = null
	var nearest_distance := 60.0
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var target_point := npc.global_position + Vector3(0, 0.95, 0)
		var offset := target_point - origin
		var along := offset.dot(direction)
		if along < 0.0 or along > nearest_distance:
			continue
		var closest_point := origin + direction * along
		if closest_point.distance_to(target_point) <= 1.0:
			nearest_distance = along
			nearest_npc = npc
	if nearest_npc:
		_register_npc_hit(nearest_npc)
	# Keep the visible energy bolt cosmetic; hit detection above avoids
	# physics-area interactions that previously caused instability.
	var bolt := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.095 if selected_weapon == "PULSE" else 0.15
	orb.height = orb.radius * 2.0
	bolt.mesh = orb
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.82, 1.0) if selected_weapon == "PULSE" else Color(0.55, 0.25, 1.0)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt.material_override = mat
	bolt.global_position = weapon_visual.global_position + direction * 0.42
	add_child(bolt)
	var tween := create_tween()
	tween.tween_property(bolt, "global_position", bolt.global_position + direction * 48.0, 0.7).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(bolt.queue_free)

func _create_npcs() -> void:
	var positions := [
		Vector3(-125, 0.0, -169), Vector3(-82, 0.0, -169),
		Vector3(-35, 0.0, -79), Vector3(5, 0.0, -79),
		Vector3(68, 0.0, 11), Vector3(105, 0.0, 11),
		Vector3(155, 0.0, 101), Vector3(185, 0.0, 101),
		Vector3(-175, 0.0, 191), Vector3(-195, 0.0, 191),
		Vector3(55, 0.0, -101), Vector3(95, 0.0, -101)
	]
	var models := ["casual-man", "casual-woman", "business-man", "business-woman", "construction-worker", "doctor", "runner-woman"]
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
		npc_states[key] = "walking"

func _load_police_assets() -> void:
	police_officer_scene = load("res://assets/people/police-officer.glb") as PackedScene
	police_helicopter_scene = load("res://assets/vehicles/police-helicopter.glb") as PackedScene
	police_car_scene = load("res://assets/vehicles/police-car.glb") as PackedScene
	if police_officer_scene == null:
		push_warning("Police officer model could not be loaded.")
	if police_helicopter_scene == null:
		push_warning("Police helicopter model could not be loaded.")
	if police_car_scene == null:
		push_warning("Police patrol car model could not be loaded.")

func _raise_wanted_level() -> void:
	# Vehicle takeovers are the non-violent arcade event that raises wanted stars.
	wanted_level = mini(6, wanted_level + 1)
	_update_hud()

func _spawn_police_unit(index: int, target: Vector3) -> void:
	if police_car_scene == null:
		return
	var patrol_car := Node3D.new()
	patrol_car.name = "PolicePatrolCar_%02d" % index
	var model := police_car_scene.instantiate() as Node3D
	if model == null:
		patrol_car.queue_free()
		return
	model.name = "PoliceCarModel"
	# The patrol-car GLB faces +Z; the chase root faces -Z toward its target.
	model.rotation.y = PI
	patrol_car.add_child(model)
	# Add a recognizable red/blue roof lightbar to the 3D patrol vehicle.
	var lightbar := MeshInstance3D.new()
	lightbar.name = "PoliceLightbar"
	var lightbar_mesh := BoxMesh.new()
	lightbar_mesh.size = Vector3(1.15, 0.13, 0.28)
	lightbar.mesh = lightbar_mesh
	lightbar.position = Vector3(0.0, 1.12, 0.0)
	var lightbar_material := StandardMaterial3D.new()
	lightbar_material.albedo_color = Color(0.12, 0.16, 0.2)
	lightbar_material.metallic = 0.35
	lightbar.material_override = lightbar_material
	model.add_child(lightbar)
	for side in [-1.0, 1.0]:
		var beacon := MeshInstance3D.new()
		beacon.name = "PoliceBeacon"
		var beacon_mesh := BoxMesh.new()
		beacon_mesh.size = Vector3(0.42, 0.16, 0.25)
		beacon.mesh = beacon_mesh
		beacon.position = Vector3(side * 0.29, 1.2, 0.0)
		var beacon_material := StandardMaterial3D.new()
		beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beacon_material.albedo_color = Color(0.05, 0.25, 1.0) if side < 0.0 else Color(1.0, 0.04, 0.025)
		beacon_material.emission_enabled = true
		beacon_material.emission = beacon_material.albedo_color
		beacon_material.emission_energy_multiplier = 2.0
		beacon.material_override = beacon_material
		model.add_child(beacon)
	if police_officer_scene != null:
		var driver := police_officer_scene.instantiate() as Node3D
		if driver != null:
			driver.name = "PoliceDriver"
			driver.scale = Vector3.ONE * 0.42
			driver.position = Vector3(-0.38, 0.72, 0.12)
			model.add_child(driver)
	var angle := TAU * float(index) / 6.0
	patrol_car.global_position = target + Vector3(cos(angle) * 34.0, 0.0, sin(angle) * 34.0)
	add_child(patrol_car)
	police_units.append(patrol_car)

func _collect_police_rotors(node: Node) -> void:
	if node is Node3D and String(node.name).to_lower().contains("rotor"):
		police_rotors.append(node as Node3D)
	for child in node.get_children():
		_collect_police_rotors(child)

func _update_police_response(delta: float) -> void:
	var target := car.global_position if driving else player.global_position
	var desired_units := mini(wanted_level, 4)
	while police_units.size() < desired_units:
		_spawn_police_unit(police_units.size(), target)
	while police_units.size() > desired_units:
		var removed: Node3D = police_units.pop_back() as Node3D
		if is_instance_valid(removed):
			removed.queue_free()
	for i in range(police_units.size()):
		var officer := police_units[i]
		if not is_instance_valid(officer):
			continue
		var destination := target + Vector3(float(i - 1) * 7.0, 0.0, float(i % 2) * 8.0)
		var offset := destination - officer.global_position
		offset.y = 0.0
		if offset.length() > 8.0:
			officer.global_position += offset.normalized() * 15.0 * delta
		if offset.length() > 0.25:
			officer.look_at(Vector3(target.x, officer.global_position.y, target.z), Vector3.UP)
		if officer.global_position.distance_to(target) < 19.0:
			_deploy_police_officer(officer, i)

	_update_police_foot_units(delta, target)

	if wanted_level > 3 and police_helicopter == null and police_helicopter_scene != null:
		police_helicopter = police_helicopter_scene.instantiate() as Node3D
		if police_helicopter:
			police_helicopter.name = "PoliceHelicopter"
			police_helicopter.scale = Vector3.ONE * 0.85
			add_child(police_helicopter)
			police_rotors.clear()
			_collect_police_rotors(police_helicopter)
			var searchlight := SpotLight3D.new()
			searchlight.name = "HelicopterSearchlight"
			searchlight.position = Vector3(0.0, -0.8, -0.6)
			searchlight.rotation_degrees.x = -90.0
			searchlight.light_color = Color(0.78, 0.9, 1.0)
			searchlight.light_energy = 2.0
			searchlight.spot_range = 42.0
			searchlight.spot_angle = 30.0
			police_helicopter.add_child(searchlight)
	if wanted_level <= 3 and is_instance_valid(police_helicopter):
		police_helicopter.queue_free()
		police_helicopter = null
		police_rotors.clear()
	if is_instance_valid(police_helicopter):
		helicopter_orbit += delta * 0.34
		police_helicopter.global_position = target + Vector3(cos(helicopter_orbit) * 19.0, 17.0, sin(helicopter_orbit) * 19.0)
		police_helicopter.look_at(target + Vector3(0.0, 17.0, 0.0), Vector3.UP)
		for rotor in police_rotors:
			if is_instance_valid(rotor):
				rotor.rotate_y(delta * 18.0)


func _deploy_police_officer(patrol_car: Node3D, index: int) -> void:
	if police_officer_scene == null or bool(patrol_car.get_meta("officers_deployed", false)):
		return
	patrol_car.set_meta("officers_deployed", true)
	var officer := police_officer_scene.instantiate() as Node3D
	if officer == null:
		return
	officer.name = "PoliceOfficerOnFoot_%02d" % index
	officer.scale = Vector3.ONE * 0.52
	add_child(officer)
	var side := -1.0 if index % 2 == 0 else 1.0
	officer.global_position = patrol_car.global_position + Vector3(side * 2.4, 0.0, 1.0)
	police_foot_units.append(officer)
	police_fire_cooldowns[officer.get_instance_id()] = 0.8
	# The driver model stays with the parked patrol car; this officer is the
	# separate on-foot unit that approaches and fires arcade energy bolts.

func _update_police_foot_units(delta: float, target: Vector3) -> void:
	for officer in police_foot_units:
		if not is_instance_valid(officer):
			continue
		var offset := target - officer.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 7.5:
			officer.global_position += offset.normalized() * minf(5.5 * delta, distance - 7.5)
		if distance > 0.2:
			officer.look_at(Vector3(target.x, officer.global_position.y, target.z), Vector3.UP)
		var key := officer.get_instance_id()
		var cooldown: float = float(police_fire_cooldowns.get(key, 0.0))
		cooldown = maxf(0.0, cooldown - delta)
		if distance < 32.0 and cooldown <= 0.0 and not player_dead:
			_spawn_police_energy_bolt(officer, target)
			cooldown = 1.25
		police_fire_cooldowns[key] = cooldown

func _spawn_police_energy_bolt(officer: Node3D, target: Vector3) -> void:
	var bolt := MeshInstance3D.new()
	bolt.name = "PoliceArcadeBolt"
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	bolt.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.24, 0.12)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.08, 0.025)
	material.emission_energy_multiplier = 2.0
	bolt.material_override = material
	add_child(bolt)
	var start := officer.global_position + Vector3(0.0, 1.15, 0.0)
	var finish := target + Vector3(0.0, 0.9, 0.0)
	bolt.global_position = start
	var tween := create_tween()
	tween.tween_property(bolt, "global_position", finish, 0.24).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(Callable(self, "_apply_police_hit"))
	tween.tween_callback(bolt.queue_free)

func _apply_police_hit() -> void:
	if player_dead:
		return
	player_hits += 1
	impact_flash_time = maxf(impact_flash_time, 0.22)
	impact_shake_time = maxf(impact_shake_time, 0.16)
	impact_shake_strength = maxf(impact_shake_strength, 0.045)
	if player_hits >= 10:
		_show_wasted_screen()

func _show_wasted_screen() -> void:
	if player_dead:
		return
	player_dead = true
	death_layer = CanvasLayer.new()
	death_layer.name = "WastedScreen"
	death_layer.layer = 30
	death_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(death_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.005, 0.012, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	death_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(stack)
	var title := Label.new()
	title.text = "WASTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(0.94, 0.08, 0.10))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.015, 1.0))
	title.add_theme_constant_override("outline_size", 7)
	stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "You were stopped by the Coastline police."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.88, 0.9))
	stack.add_child(subtitle)
	var restart_button := _make_pause_button("RESTART")
	restart_button.custom_minimum_size = Vector2(220, 48)
	restart_button.pressed.connect(_restart_game)
	stack.add_child(restart_button)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _create_car() -> void:
	car = Node3D.new()
	car.name = "PlayerCar"
	# Put the car directly ahead of the player and align its tyres with the road.
	car.position = Vector3(-8, -0.01, -8)
	add_child(car)
	var sedan_scene := load("res://assets/vehicles/sports-car.glb") as PackedScene
	if sedan_scene == null:
		push_error("Could not load sports car model: res://assets/vehicles/sports-car.glb")
		return
	car_model = sedan_scene.instantiate() as Node3D
	if car_model == null:
		push_error("Sports car scene did not contain a Node3D root.")
		return
	car_model.name = "SportsCoupe"
	# Rotate the model 180 degrees so its nose points away from the player.
	car_model.rotation.y = PI
	car.add_child(car_model)
	_create_vehicle_interior(car_model)
	_collect_car_wheels(car_model)
	available_cars.append(car)


func _create_vehicle_interior(vehicle_model: Node3D) -> void:
	# A simple, original cabin is layered inside the exterior mesh so the
	# dashboard, seats, console and steering wheel are visible in close views.
	if vehicle_model.has_node("CoastlineInterior"):
		return
	var cabin := Node3D.new()
	cabin.name = "CoastlineInterior"
	vehicle_model.add_child(cabin)
	var dark_mat := _mat(Color(0.035, 0.045, 0.06), 0.25)
	var trim_mat := _mat(Color(0.16, 0.19, 0.23), 0.35)
	var seat_mat := _mat(Color(0.055, 0.065, 0.08), 0.12)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.025, 0.28, 0.38)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.02, 0.22, 0.34)
	screen_mat.emission_energy_multiplier = 1.2
	_add_cabin_box(cabin, "Dashboard", Vector3(1.55, 0.28, 0.42), Vector3(0.0, 0.88, -0.72), dark_mat)
	_add_cabin_box(cabin, "DashboardTrim", Vector3(1.35, 0.045, 0.035), Vector3(0.0, 0.76, -0.49), trim_mat)
	_add_cabin_box(cabin, "CenterConsole", Vector3(0.28, 0.18, 0.72), Vector3(0.0, 0.53, -0.05), trim_mat)
	_add_cabin_box(cabin, "InfotainmentScreen", Vector3(0.34, 0.22, 0.035), Vector3(0.0, 0.93, -0.49), screen_mat)
	for side in [-1.0, 1.0]:
		var seat_x: float = float(side) * 0.43
		_add_cabin_box(cabin, "SeatCushion", Vector3(0.58, 0.18, 0.58), Vector3(seat_x, 0.48, 0.24), seat_mat)
		var backrest := _add_cabin_box(cabin, "SeatBackrest", Vector3(0.58, 0.78, 0.18), Vector3(seat_x, 0.88, 0.48), seat_mat)
		backrest.rotation.x = -0.10
		_add_cabin_box(cabin, "HeadRest", Vector3(0.34, 0.22, 0.16), Vector3(seat_x, 1.35, 0.50), dark_mat)
	_add_cabin_box(cabin, "SteeringColumn", Vector3(0.10, 0.10, 0.42), Vector3(-0.43, 0.82, -0.40), trim_mat)
	var steering_wheel := MeshInstance3D.new()
	steering_wheel.name = "SteeringWheel"
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.20
	wheel_mesh.outer_radius = 0.245
	steering_wheel.mesh = wheel_mesh
	steering_wheel.material_override = dark_mat
	steering_wheel.position = Vector3(-0.43, 0.91, -0.58)
	steering_wheel.rotation.x = PI * 0.5
	cabin.add_child(steering_wheel)
	_add_cabin_box(cabin, "InstrumentCluster", Vector3(0.38, 0.12, 0.10), Vector3(-0.43, 1.02, -0.76), screen_mat)
	_add_cabin_box(cabin, "DoorArmrestLeft", Vector3(0.12, 0.12, 0.72), Vector3(-0.82, 0.58, 0.12), trim_mat)
	_add_cabin_box(cabin, "DoorArmrestRight", Vector3(0.12, 0.12, 0.72), Vector3(0.82, 0.58, 0.12), trim_mat)

func _add_cabin_box(parent: Node3D, part_name: String, dimensions: Vector3, local_position: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = material
	part.position = local_position
	parent.add_child(part)
	return part

func _collect_car_wheels(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D:
			var part_name := String(child.name).to_lower()
			if part_name.contains("wheel") or part_name.contains("tire") or part_name.contains("tyre"):
				car_wheels.append(child as Node3D)		_collect_car_wheels(child)
func _animate_car_wheels(delta: float) -> void:
	if abs(car_velocity) < 0.01:
		return
	var wheel_rotation := -car_velocity * delta / 0.32
	for wheel in car_wheels:
		if is_instance_valid(wheel):
			wheel.rotate_object_local(Vector3.RIGHT, wheel_rotation)

func _create_traffic() -> void:
	var vehicle_scene := load("res://assets/vehicles/sports-car.glb") as PackedScene
	if vehicle_scene == null:
		push_warning("Traffic cars unavailable: sports car model did not load.")
		return
	var road_x_positions := [-150.0, -60.0, 30.0, 120.0, 210.0]
	var start_z_positions := [-165.0, -85.0, -5.0, 75.0, 155.0]
	for i in range(road_x_positions.size()):
		var traffic_car := Node3D.new()
		traffic_car.name = "TrafficCar_%02d" % i
		traffic_car.position = Vector3(road_x_positions[i], -0.01, start_z_positions[i])
		var speed := 8.0 + float(i % 3) * 1.4
		if i % 2 == 1:
			speed = -speed
		# The imported coupe faces local -Z. Match its nose to the lane direction.
		traffic_car.rotation.y = PI if speed > 0.0 else 0.0
		add_child(traffic_car)
		var model := vehicle_scene.instantiate() as Node3D
		if model == null:
			traffic_car.queue_free()
			continue
		model.name = "TrafficSportsCoupe"
		model.rotation.y = 0.0
		traffic_car.add_child(model)
		traffic_cars.append(traffic_car)
		traffic_speeds.append(speed)
		available_cars.append(traffic_car)

func _update_traffic(delta: float) -> void:
	for i in range(traffic_cars.size()):
		var traffic_car := traffic_cars[i]
		if not is_instance_valid(traffic_car):
			continue
		traffic_car.position.z += traffic_speeds[i] * delta
		if traffic_speeds[i] > 0.0 and traffic_car.position.z > 205.0:
			traffic_car.position.z = -205.0
		elif traffic_speeds[i] < 0.0 and traffic_car.position.z < -205.0:
			traffic_car.position.z = 205.0

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
	mission_status_label = Label.new()
	mission_status_label.position = Vector2(24, 78)
	mission_status_label.custom_minimum_size = Vector2(440, 90)
	mission_status_label.add_theme_font_size_override("font_size", 18)
	mission_status_label.add_theme_color_override("font_color", Color(0.65, 0.94, 1.0))
	mission_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	mission_status_label.add_theme_constant_override("shadow_offset_x", 2)
	mission_status_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(mission_status_label)
	remote_status_label = Label.new()
	remote_status_label.position = Vector2(24, 610)
	remote_status_label.add_theme_font_size_override("font_size", 14)
	remote_status_label.add_theme_color_override("font_color", Color(0.65, 0.94, 1.0))
	layer.add_child(remote_status_label)
	_create_pause_menu()
	_create_weapon_menu()
	_create_mobile_controls(layer)
	_update_hud()

func _create_mission_world() -> void:
	# Fictional arcade mission landmarks; no realistic security or entry mechanics.
	var bank := Node3D.new()
	bank.name = "CoastlineBank"
	bank.position = Vector3(190, 0, 215)
	add_child(bank)
	var stone := _mat(Color(0.72, 0.76, 0.78), 0.62)
	var glass := _mat(Color(0.08, 0.48, 0.62), 0.2, 0.25)
	var gold := _mat(Color(0.98, 0.72, 0.22), 0.3, 0.25)
	_static_box(bank, Vector3(0, 5.5, 0), Vector3(28, 11, 22), stone)
	_mesh_box(bank, Vector3(0, 10.9, 0), Vector3(29, 0.8, 23), gold, "BankRoofTrim")
	_mesh_box(bank, Vector3(0, 4.8, -11.15), Vector3(12, 5.2, 0.3), glass, "BankFrontWindows")
	_mesh_box(bank, Vector3(0, 2.0, -11.3), Vector3(3.0, 4.0, 0.5), gold, "BankEntrance")
	var sign_label := Label3D.new()
	sign_label.text = "COASTLINE BANK"
	sign_label.font_size = 64
	sign_label.pixel_size = 0.006
	sign_label.position = Vector3(0, 9.0, -11.7)
	sign_label.modulate = Color(1.0, 0.83, 0.42)
	bank.add_child(sign_label)
	mission_marker = _create_mission_beacon(Vector3(170, 0.1, 195), Color(0.1, 0.85, 1.0), "START MISSION")
	getaway_marker = _create_mission_beacon(Vector3(120, 0.1, 180), Color(0.25, 1.0, 0.55), "GETAWAY")
	getaway_marker.visible = false
	for index in range(1):
		var pickup := _create_mission_beacon(Vector3(178.0, 0.1, 188.0), Color(1.0, 0.72, 0.18), "DATA CHIP")
		pickup.scale = Vector3(0.48, 0.7, 0.48)
		pickup.visible = false
		mission_pickups.append(pickup)

func _create_mission_beacon(at: Vector3, tint: Color, caption: String) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint * 0.65
	var column := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.55
	cylinder.bottom_radius = 0.75
	cylinder.height = 0.16
	column.mesh = cylinder
	column.material_override = material
	root.add_child(column)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	orb.mesh = sphere
	orb.position.y = 1.0
	orb.material_override = material
	root.add_child(orb)
	var label := Label3D.new()
	label.text = caption
	label.position.y = 2.0
	label.font_size = 48
	label.pixel_size = 0.008
	label.modulate = tint
	root.add_child(label)
	return root

func _try_start_mission() -> bool:
	if mission_state == "available" or mission_state == "complete":
		if player.global_position.distance_to(mission_marker.global_position) <= 7.0:
			mission_state = "collect"
			mission_tokens = 0
			for pickup in mission_pickups:
				pickup.visible = true
			getaway_marker.visible = false
			wanted_level = 0
			return true
	return false

func _update_mission() -> void:
	if mission_state == "collect":
		for pickup in mission_pickups:
			if pickup.visible and (player.global_position.distance_to(pickup.global_position) < 10.0 or (driving and car.global_position.distance_to(pickup.global_position) < 10.0)):
				pickup.visible = false
				mission_tokens += 1
			if mission_tokens >= 1:
				mission_state = "escape"
				getaway_marker.visible = true
	elif mission_state == "escape":
		var target := car.global_position if driving else player.global_position
		if target.distance_to(getaway_marker.global_position) < 24.0:
			mission_state = "complete"
			getaway_marker.visible = false
			mission_cash += 5000
			wanted_level = 0
			for pickup in mission_pickups:
				pickup.visible = false

func _mission_status_text() -> String:
	match mission_state:
		"available", "complete":
			return "MISSION: THE BIG SCORE\n" + ("COMPLETE  •  $5,000 REWARD\nReturn to the blue marker to replay." if mission_state == "complete" else "Blue marker at Coastline Bank  •  Press E / Y to begin.")
		"collect":
			return "THE BIG SCORE  •  OBJECTIVE 1/2\nCollect the 3 glowing data chips: %d/3" % mission_tokens
		"escape":
			return "THE BIG SCORE  •  OBJECTIVE 2/2\nReach the green getaway marker. Find a car!"
	return ""

func _create_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseMenu"
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.layer = 20
	add_child(pause_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.045, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(backdrop)

	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	backdrop.add_child(layout)

	# Left-side city map panel, evoking the classic open-world pause screen.
	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_stretch_ratio = 1.45
	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.055, 0.075, 0.085, 1.0)
	map_style.border_color = Color(0.28, 0.75, 0.72, 0.75)
	map_style.border_width_right = 2
	map_panel.add_theme_stylebox_override("panel", map_style)
	layout.add_child(map_panel)

	var map_stack := VBoxContainer.new()
	map_stack.add_theme_constant_override("separation", 12)
	map_stack.add_theme_constant_override("margin_left", 34)
	map_stack.add_theme_constant_override("margin_right", 30)
	map_stack.add_theme_constant_override("margin_top", 30)
	map_stack.add_theme_constant_override("margin_bottom", 28)
	map_panel.add_child(map_stack)

	var brand := Label.new()
	brand.text = "COASTLINE"
	brand.add_theme_font_size_override("font_size", 36)
	brand.add_theme_color_override("font_color", Color(0.95, 0.97, 0.91))
	brand.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	brand.add_theme_constant_override("shadow_offset_x", 2)
	brand.add_theme_constant_override("shadow_offset_y", 2)
	map_stack.add_child(brand)

	var map_caption := Label.new()
	map_caption.text = "CITY MAP  /  ISLAND DISTRICT"
	map_caption.add_theme_font_size_override("font_size", 13)
	map_caption.add_theme_color_override("font_color", Color(0.37, 0.83, 0.78))
	map_stack.add_child(map_caption)

	var map_area := Control.new()
	map_area.custom_minimum_size = Vector2(0, 300)
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.clip_contents = true
	map_stack.add_child(map_area)
	var map_bg := ColorRect.new()
	map_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_bg.color = Color(0.12, 0.18, 0.17)
	map_area.add_child(map_bg)
	# Stylized road grid and coastline shapes.
	for x in [0.18, 0.38, 0.59, 0.79]:
		var road := ColorRect.new()
		road.anchor_left = x
		road.anchor_right = x + 0.025
		road.anchor_top = 0.0
		road.anchor_bottom = 1.0
		road.color = Color(0.35, 0.39, 0.34)
		map_area.add_child(road)
	for y in [0.2, 0.43, 0.66, 0.86]:
		var road := ColorRect.new()
		road.anchor_top = y
		road.anchor_bottom = y + 0.025
		road.anchor_left = 0.0
		road.anchor_right = 1.0
		road.color = Color(0.35, 0.39, 0.34)
		map_area.add_child(road)
	var coast := ColorRect.new()
	coast.anchor_left = 0.0
	coast.anchor_right = 0.12
	coast.anchor_top = 0.0
	coast.anchor_bottom = 1.0
	coast.color = Color(0.035, 0.30, 0.40, 0.9)
	map_area.add_child(coast)
	var map_pin := Label.new()
	map_pin.text = "◆"
	map_pin.position = Vector2(210, 118)
	map_pin.add_theme_font_size_override("font_size", 27)
	map_pin.add_theme_color_override("font_color", Color(0.2, 0.95, 0.86))
	map_area.add_child(map_pin)

	var location := Label.new()
	location.text = "VICE COAST  •  SUNSET DISTRICT\nExplore the island, find missions, and make your mark."
	location.add_theme_font_size_override("font_size", 14)
	location.add_theme_color_override("font_color", Color(0.72, 0.79, 0.75))
	location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_stack.add_child(location)

	var menu_panel := PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(360, 0)
	menu_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.035, 0.045, 0.06, 1.0)
	menu_style.content_margin_left = 30
	menu_style.content_margin_right = 30
	menu_style.content_margin_top = 34
	menu_style.content_margin_bottom = 28
	menu_panel.add_theme_stylebox_override("panel", menu_style)
	layout.add_child(menu_panel)

	var menu_stack := VBoxContainer.new()
	menu_stack.add_theme_constant_override("separation", 9)
	menu_panel.add_child(menu_stack)

	var menu_heading := Label.new()
	menu_heading.text = "PAUSE MENU"
	menu_heading.add_theme_font_size_override("font_size", 25)
	menu_heading.add_theme_color_override("font_color", Color(0.95, 0.97, 0.91))
	menu_stack.add_child(menu_heading)
	var menu_subtitle := Label.new()
	menu_subtitle.text = "Take a moment."
	menu_subtitle.add_theme_font_size_override("font_size", 13)
	menu_subtitle.add_theme_color_override("font_color", Color(0.53, 0.62, 0.62))
	menu_stack.add_child(menu_subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	menu_stack.add_child(spacer)

	pause_buttons.clear()
	var resume_button := _make_pause_button("RESUME")
	resume_button.pressed.connect(_resume_game)
	menu_stack.add_child(resume_button)
	pause_buttons.append(resume_button)

	var map_button := _make_pause_button("MAP")
	map_button.pressed.connect(_focus_pause_button.bind(0))
	menu_stack.add_child(map_button)
	pause_buttons.append(map_button)

	var settings_button := _make_pause_button("SETTINGS")
	settings_button.pressed.connect(_open_settings)
	menu_stack.add_child(settings_button)
	pause_buttons.append(settings_button)

	var restart_button := _make_pause_button("RESTART")
	restart_button.pressed.connect(_restart_game)
	menu_stack.add_child(restart_button)
	pause_buttons.append(restart_button)

	var quit_button := _make_pause_button("QUIT GAME")
	quit_button.pressed.connect(_quit_game)
	menu_stack.add_child(quit_button)
	pause_buttons.append(quit_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_stack.add_child(footer_spacer)
	var controls := Label.new()
	controls.text = "D-PAD / LEFT STICK  SELECT\nA  CONFIRM     B / START  BACK"
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color(0.46, 0.58, 0.58))
	menu_stack.add_child(controls)
	pause_layer.visible = false
	_create_settings_panel()

func _create_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -250
	settings_panel.offset_top = -170
	settings_panel.offset_right = 250
	settings_panel.offset_bottom = 170
	settings_panel.visible = false
	settings_panel.z_index = 5
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.07, 0.98)
	panel_style.border_color = Color(0.28, 0.75, 0.72, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	pause_layer.add_child(settings_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	settings_panel.add_child(stack)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.95, 0.97, 0.91))
	stack.add_child(heading)
	var display_label := Label.new()
	display_label.text = "DISPLAY"
	display_label.add_theme_font_size_override("font_size", 13)
	display_label.add_theme_color_override("font_color", Color(0.37, 0.83, 0.78))
	stack.add_child(display_label)
	fullscreen_button = _make_pause_button("FULL SCREEN: " + _fullscreen_status())
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	stack.add_child(fullscreen_button)
	var back_button := _make_pause_button("BACK")
	back_button.pressed.connect(_close_settings)
	stack.add_child(back_button)

func _fullscreen_status() -> String:
	return "ON" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "OFF"

func _toggle_fullscreen() -> void:
	var currently_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if currently_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if fullscreen_button:
		fullscreen_button.text = "   FULL SCREEN: " + _fullscreen_status()
		fullscreen_button.grab_focus()

func _open_settings() -> void:
	settings_panel.visible = true
	fullscreen_button.text = "   FULL SCREEN: " + _fullscreen_status()
	fullscreen_button.grab_focus()

func _close_settings() -> void:
	settings_panel.visible = false
	_focus_pause_button(2)

func _make_pause_button(caption: String) -> Button:
	var button := Button.new()
	button.text = "   " + caption
	button.custom_minimum_size = Vector2(0, 52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.82, 0.86, 0.81))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.96))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 0.96))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.09, 0.10, 0.4)
	normal.content_margin_left = 12
	normal.set_border_width_all(0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.11, 0.19, 0.18, 1.0)
	hover.border_color = Color(0.28, 0.85, 0.76, 1.0)
	hover.border_width_left = 4
	hover.content_margin_left = 12
	var focus := hover.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.13, 0.24, 0.22, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	return button

func _focus_pause_button(index: int) -> void:
	if index >= 0 and index < pause_buttons.size():
		pause_selected_index = index
		pause_buttons[index].grab_focus()

func _show_pause_notice(message: String) -> void:
	if pause_buttons.size() > 0:
		pause_buttons[0].text = "   " + message.to_upper()
		pause_buttons[0].grab_focus()

func _pause_menu_move(direction: int) -> void:
	if pause_buttons.is_empty():
		return
	pause_selected_index = posmod(pause_selected_index + direction, pause_buttons.size())
	pause_buttons[pause_selected_index].grab_focus()

func _handle_pause_navigation(event: InputEvent) -> bool:
	if not is_paused:
		return false
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_pause_menu_move(1)
		return true
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_pause_menu_move(-1)
		return true
	if settings_panel != null and settings_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_settings()
			return true
		return false
	if event.is_action_pressed("ui_cancel"):
		_resume_game()
		return true
	return false

func _set_paused(value: bool) -> void:
	is_paused = value
	get_tree().paused = value
	pause_layer.visible = value
	mouse_captured = not value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:
		pause_selected_index = 0
		_focus_pause_button(pause_selected_index)

func _resume_game() -> void:
	_set_paused(false)

func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()

func _update_hud() -> void:
	var wanted_stars := ""
	for star_index in range(6):
		wanted_stars += "★" if star_index < wanted_level else "☆"
	hud.text = "COASTLINE  |  " + ("THE BIG SCORE" if mission_state != "available" and mission_state != "complete" else "FREE ROAM") + "  |  CASH: $" + str(mission_cash) + "  |  EQUIPPED: " + selected_weapon + "  |  WANTED: " + wanted_stars
	if mission_status_label:
		mission_status_label.text = _mission_status_text()
	if vr_enabled:
		help_label.text = "VR: Head tracking active  •  Left stick move  •  Right stick look  •  E / Y interact"
	elif OS.get_name() == "Android" or OS.get_name() == "iOS" or DisplayServer.is_touchscreen_available():
		help_label.text = "Touch joystick: move / steer   •   Drag right side: look   •   ACTION: enter / exit / mission"
		speed_label.text = "%03d km/h" % int(abs(car_velocity) * 3.0) if driving else "ON FOOT"
	elif driving:
		help_label.text = "WASD / Left Stick Drive   •   Right Stick Look   •   E / Y Exit   •   LB Wheel"
		speed_label.text = "%03d km/h" % int(abs(car_velocity) * 3.0)
	else:
		help_label.text = "WASD / Left Stick Move   •   Shift / L3 Run   •   Space / A Jump   •   E / Y Enter or take nearby car   •   K / LB Wheel   •   LMB / RT Fire"
		speed_label.text = "ON FOOT"

func _create_mobile_controls(layer: CanvasLayer) -> void:
	if OS.get_name() != "Android" and OS.get_name() != "iOS" and not DisplayServer.is_touchscreen_available():
		return
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	help_label.visible = false
	speed_label.position = Vector2(1020, 20)
	mobile_controls_root = Control.new()
	mobile_controls_root.name = "MobileTouchControls"
	mobile_controls_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls_root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(mobile_controls_root)

	var base := Panel.new()
	base.name = "MoveJoystickBase"
	base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	base.offset_left = 30
	base.offset_top = -190
	base.offset_right = 190
	base.offset_bottom = -30
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.04, 0.07, 0.12, 0.48)
	base_style.border_color = Color(0.72, 0.88, 1.0, 0.7)
	base_style.set_border_width_all(3)
	base_style.set_corner_radius_all(80)
	base.add_theme_stylebox_override("panel", base_style)
	mobile_controls_root.add_child(base)

	mobile_joystick_knob = Panel.new()
	mobile_joystick_knob.name = "MoveJoystickKnob"
	mobile_joystick_knob.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mobile_joystick_knob.offset_left = 82
	mobile_joystick_knob.offset_top = -138
	mobile_joystick_knob.offset_right = 138
	mobile_joystick_knob.offset_bottom = -82
	mobile_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.35, 0.72, 1.0, 0.82)
	knob_style.border_color = Color(0.9, 0.97, 1.0, 0.95)
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(30)
	mobile_joystick_knob.add_theme_stylebox_override("panel", knob_style)
	mobile_controls_root.add_child(mobile_joystick_knob)

	_add_mobile_button("ACTION", "interact", -34, -44, true)
	_add_mobile_button("JUMP", "jump", -156, -44)
	_add_mobile_button("RUN", "sprint", -34, -122)
	_add_mobile_button("PAUSE", "pause", -156, -122, true)
	_add_mobile_button("BRAKE", "vehicle_brake", -34, -200)
	_add_mobile_button("FIRE", "fire", -156, -200)

func _add_mobile_button(caption: String, action: String, right_offset: float, bottom_offset: float, instant := false) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(108, 64)
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = right_offset - 108
	button.offset_top = bottom_offset - 64
	button.offset_right = right_offset
	button.offset_bottom = bottom_offset
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.08, 0.14, 0.76)
	normal.border_color = Color(0.36, 0.75, 1.0, 0.95)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(16)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.38, 0.58, 0.94)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", normal)
	if instant:
		if action == "pause":
			button.button_down.connect(func(): _set_paused(not is_paused))
		else:
			button.button_down.connect(_mobile_interact)
	else:
		button.button_down.connect(func(): Input.action_press(action))
		button.button_up.connect(func(): Input.action_release(action))
	mobile_controls_root.add_child(button)

func _mobile_interact() -> void:
	if player_dead or is_paused:
		return
	if driving:
		_exit_car()
	elif not _try_start_mission():
		_try_enter_nearest_car()

func _set_mobile_joystick(point: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	mobile_joystick_center = Vector2(110.0, viewport_size.y - 110.0)
	var offset := point - mobile_joystick_center
	if offset.length() > mobile_joystick_radius:
		offset = offset.normalized() * mobile_joystick_radius
	var stick := offset / mobile_joystick_radius
	_set_mobile_axis("move_left", "move_right", stick.x)
	_set_mobile_axis("move_back", "move_forward", -stick.y)
	if mobile_joystick_knob:
		mobile_joystick_knob.offset_left = 82.0 + offset.x
		mobile_joystick_knob.offset_top = -138.0 + offset.y
		mobile_joystick_knob.offset_right = 138.0 + offset.x
		mobile_joystick_knob.offset_bottom = -82.0 + offset.y

func _set_mobile_axis(negative_action: String, positive_action: String, value: float) -> void:
	if value < -0.2:
		Input.action_press(negative_action, -value)
		Input.action_release(positive_action)
	elif value > 0.2:
		Input.action_press(positive_action, value)
		Input.action_release(negative_action)
	else:
		Input.action_release(negative_action)
		Input.action_release(positive_action)

func _release_mobile_joystick() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	if mobile_joystick_knob:
		mobile_joystick_knob.offset_left = 82
		mobile_joystick_knob.offset_top = -138
		mobile_joystick_knob.offset_right = 138
		mobile_joystick_knob.offset_bottom = -82

func _input(event: InputEvent) -> void:
	if mobile_controls_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < viewport_size.x * 0.36 and event.position.y > viewport_size.y - 230.0:
				mobile_joystick_touch_id = event.index
				_set_mobile_joystick(event.position)
				get_viewport().set_input_as_handled()
			elif event.position.x > viewport_size.x * 0.42 and event.position.y < viewport_size.y - 205.0:
				mobile_look_touch_id = event.index
		else:
			if event.index == mobile_joystick_touch_id:
				mobile_joystick_touch_id = -1
				_release_mobile_joystick()
				get_viewport().set_input_as_handled()
			if event.index == mobile_look_touch_id:
				mobile_look_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == mobile_joystick_touch_id:
			_set_mobile_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == mobile_look_touch_id and not is_paused:
			if driving:
				car_yaw -= event.relative.x * 0.004
				camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * 0.003, -0.45, 0.25)
			else:
				player.rotation.y -= event.relative.x * 0.004
				camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * 0.003, -0.65, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if player_dead:
		return
	if event.is_action_pressed("weapon_wheel") and not is_paused:
		weapon_menu_open = true
		weapon_menu_layer.visible = true
		mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("weapon_wheel") and weapon_menu_open:
		weapon_menu_open = false
		weapon_menu_layer.visible = false
		mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_set_paused(not is_paused)
		get_viewport().set_input_as_handled()
		return
	if is_paused:
		if _handle_pause_navigation(event):
			get_viewport().set_input_as_handled()
		return
	if weapon_menu_open and event.is_action_pressed("weapon_next"):
		_select_weapon("ARC" if selected_weapon == "PULSE" else "PULSE" if selected_weapon == "FISTS" else "FISTS")
		get_viewport().set_input_as_handled()
		return
	if weapon_menu_open and event.is_action_pressed("weapon_prev"):
		_select_weapon("FISTS" if selected_weapon == "PULSE" else "PULSE" if selected_weapon == "ARC" else "ARC")
		get_viewport().set_input_as_handled()
		return
	if weapon_menu_open:
		return
	if event is InputEventMouseMotion and mouse_captured:
		if driving:
			car_yaw -= event.relative.x * 0.0025
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * 0.002, -0.45, 0.25)
		else:
			player.rotation.y -= event.relative.x * 0.0025
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * 0.002, -0.65, 0.35)
	if event.is_action_pressed("interact"):
		if driving:
			_exit_car()
		elif not _try_start_mission():
			_try_enter_nearest_car()

func _process(delta: float) -> void:
	_poll_remote_controller()
	if remote_last_input_msec > 0 and Time.get_ticks_msec() - remote_last_input_msec > 700:
		_set_remote_action("move_left", false)
		_set_remote_action("move_right", false)
		_set_remote_action("move_forward", false)
		_set_remote_action("move_back", false)
		for action in ["jump", "sprint", "vehicle_brake", "fire"]:
			_set_remote_action(action, false)
		remote_move = Vector2.ZERO
	if remote_look.length() > 0.001 and not is_paused:
		if driving:
			car_yaw -= remote_look.x * 0.0025
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - remote_look.y * 0.002, -0.45, 0.25)
		else:
			player.rotation.y -= remote_look.x * 0.0025
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - remote_look.y * 0.002, -0.65, 0.35)
		remote_look = Vector2.ZERO
	if remote_status_label:
		remote_status_label.text = "GALAXY REMOTE: " + remote_controller_url + ("  •  CONNECTED" if Time.get_ticks_msec() - remote_last_input_msec < 1800 and remote_last_input_msec > 0 else "  •  WAITING")

func _start_remote_controller() -> void:
	var error := remote_server.listen(8765, "0.0.0.0")
	if error != OK:
		push_warning("Galaxy Remote could not start on port 8765: " + str(error))
		return
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			remote_controller_url = "http://" + address + ":8765"
			break
	if remote_controller_url == "":
		remote_controller_url = "http://<laptop-ip>:8765"
	print("Galaxy Remote controller: " + remote_controller_url)

func _poll_remote_controller() -> void:
	while remote_server.is_connection_available():
		var peer := remote_server.take_connection()
		remote_clients.append({"peer": peer, "buffer": PackedByteArray()})
	for index in range(remote_clients.size() - 1, -1, -1):
		var client: Dictionary = remote_clients[index]
		var peer: StreamPeerTCP = client["peer"]
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_NONE or peer.get_status() == StreamPeerTCP.STATUS_ERROR:
			remote_clients.remove_at(index)
			continue
		var available := peer.get_available_bytes()
		if available > 0:
			var packet := peer.get_data(available)
			if packet[0] == OK:
				var buffer: PackedByteArray = client["buffer"]
				buffer.append_array(packet[1])
				client["buffer"] = buffer
		var data: PackedByteArray = client["buffer"]
		var header_end := data.find("\r\n\r\n".to_utf8_buffer())
		if header_end < 0:
			continue
		var header_text := data.slice(0, header_end).get_string_from_utf8()
		var content_length := 0
		for line in header_text.split("\r\n"):
			if line.to_lower().begins_with("content-length:"):
				content_length = int(line.split(":")[1].strip_edges())
		var body_start := header_end + 4
		if data.size() < body_start + content_length:
			continue
		var request_line := header_text.split("\r\n")[0]
		var body := data.slice(body_start, body_start + content_length).get_string_from_utf8()
		var response_body := ""
		var content_type := "text/plain; charset=utf-8"
		var status := "200 OK"
		if request_line.begins_with("GET / ") or request_line.begins_with("GET /controller"):
			var controller_path := "res://galaxy_controller.html"
			if FileAccess.file_exists(controller_path):
				response_body = FileAccess.get_file_as_string(controller_path)
				content_type = "text/html; charset=utf-8"
			else:
				status = "404 Not Found"
				response_body = "Galaxy controller page is missing."
		elif request_line.begins_with("POST /input"):
			var parsed = JSON.parse_string(body)
			if parsed is Dictionary:
				_apply_remote_payload(parsed)
			response_body = "ok"
		elif request_line.begins_with("GET /health"):
			response_body = "Coastline Galaxy Remote ready"
		else:
			status = "404 Not Found"
			response_body = "Not found"
		var response_bytes := response_body.to_utf8_buffer()
		var header := "HTTP/1.1 " + status + "\r\nContent-Type: " + content_type + "\r\nContent-Length: " + str(response_bytes.size()) + "\r\nConnection: close\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
		peer.put_data(header.to_utf8_buffer())
		peer.put_data(response_bytes)
		peer.disconnect_from_host()
		remote_clients.remove_at(index)

func _apply_remote_payload(data: Dictionary) -> void:
	remote_last_input_msec = Time.get_ticks_msec()
	remote_move = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	remote_look += Vector2(float(data.get("look_x", 0.0)), float(data.get("look_y", 0.0)))
	_set_remote_action("move_left", remote_move.x < -0.18)
	_set_remote_action("move_right", remote_move.x > 0.18)
	_set_remote_action("move_forward", remote_move.y < -0.18)
	_set_remote_action("move_back", remote_move.y > 0.18)
	for action in ["jump", "sprint", "vehicle_brake", "fire"]:
		_set_remote_action(action, bool(data.get(action, false)))
	if bool(data.get("interact", false)) and not bool(data.get("interact_prev", false)):
		if driving:
			_exit_car()
		elif not _try_start_mission():
			_try_enter_nearest_car()
	if bool(data.get("pause", false)):
		_set_paused(not is_paused)

func _set_remote_action(action: String, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	if pressed and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action):
		Input.action_release(action)

func _physics_process(delta: float) -> void:
	if is_paused or player_dead:
		return
	_update_vr_hands()
	_update_mission()
	_update_traffic(delta)
	_update_police_response(delta)
	_update_audio(delta)
	if car_entry_in_progress:
		_update_camera()
		_update_hud()
		return
	_controller_look(delta)
	_update_npcs(delta)
	fire_cooldown = max(0.0, fire_cooldown - delta)
	if driving:
		_drive_car(delta)
	else:
		_move_player(delta)
		if not weapon_menu_open and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("fire")) and fire_cooldown <= 0.0:
			_fire_selected_weapon()
	_animate_car_wheels(delta)
	_update_camera()
	_update_impact_effects(delta)
	_update_hud()

func _move_player(delta: float) -> void:
	# Read movement as a camera-relative input so W always moves away from
	# the camera and A/D stay consistent while the player looks around.
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input.length() > 1.0:
		input = input.normalized()

	var view_basis: Basis = xr_camera.global_transform.basis if vr_enabled and xr_camera != null else camera_pivot.global_transform.basis
	var forward := -view_basis.z
	var right := view_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var direction := (right * input.x) - (forward * input.y)
	if direction.length() > 1.0:
		direction = direction.normalized()

	var sprinting := Input.is_action_pressed("sprint")
	var target_speed := PLAYER_SPEED * (1.55 if sprinting else 1.0)
	var acceleration := 24.0 if direction.length() > 0.01 else 32.0
	var target_x := direction.x * target_speed
	var target_z := direction.z * target_speed
	player.velocity.x = move_toward(player.velocity.x, target_x, acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, target_z, acceleration * delta)

	if direction.length() > 0.01:
		# Convert the world movement direction back into player-local space
		# before turning the imported character model.
		var local_direction := player.global_transform.basis.inverse() * direction
		var target_yaw := atan2(local_direction.x, local_direction.z)
		player_visual.rotation.y = lerp_angle(player_visual.rotation.y, target_yaw, min(1.0, delta * 9.0))
		_play_person_animation(player_anim_player, "run" if sprinting else "walk")
	else:
		_play_person_animation(player_anim_player, "idle")

	if player.is_on_floor():
		if Input.is_action_pressed("jump") and player.velocity.y <= 0.0:
			player.velocity.y = 6.0
	else:
		player.velocity.y -= 18.0 * delta

	player.move_and_slide()
	player.global_position.x = clamp(player.global_position.x, -238, 238)
	player.global_position.z = clamp(player.global_position.z, -238, 238)

func _is_player_aiming_at(npc: Node3D) -> bool:
	if selected_weapon == "FISTS" or driving or weapon_menu_open or not is_instance_valid(camera):
		return false
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z.normalized()
	var target := npc.global_position + Vector3(0, 1.0, 0)
	var offset := target - origin
	var distance_along := offset.dot(forward)
	if distance_along < 0.0 or distance_along > 26.0:
		return false
	var closest := origin + forward * distance_along
	return closest.distance_to(target) < 1.45

func _update_npcs(delta: float) -> void:
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var key := npc.get_instance_id()
		var state: String = npc_states.get(key, "walking")
		var direction: float = npc_directions.get(key, 1.0)
		var remaining: float = npc_walk_times.get(key, 2.0) - delta
		if _is_player_aiming_at(npc):
			if state == "walking":
				state = "startled"
				npc_alert_times[key] = 0.7
			elif state == "startled":
				var alert_left: float = npc_alert_times.get(key, 0.7) - delta
				npc_alert_times[key] = alert_left
				if alert_left <= 0.0:
					state = "fleeing"
					direction = sign(npc.global_position.x - player.global_position.x)
					if abs(direction) < 0.1:
						direction = -1.0 if player.global_position.z < npc.global_position.z else 1.0
					npc_alert_times[key] = 2.8
		elif state == "startled":
			state = "walking"
			npc_alert_times.erase(key)
		elif state == "fleeing":
			var flee_left: float = npc_alert_times.get(key, 0.0) - delta
			npc_alert_times[key] = flee_left
			if flee_left <= 0.0:
				state = "walking"
				npc_alert_times.erase(key)
		if state == "walking":
			if remaining <= 0.0:
				direction *= -1.0
				remaining = rng.randf_range(2.0, 5.0)
			npc.position.x += direction * 0.75 * delta
		elif state == "startled":
			# Brief pause and turn toward the player before deciding to run.
			npc.rotation.y = atan2(player.global_position.x - npc.global_position.x, player.global_position.z - npc.global_position.z)
		else:
			npc.position.x += direction * 3.0 * delta
		npc_states[key] = state
		npc_directions[key] = direction
		npc_walk_times[key] = remaining
		if state != "startled":
			npc.rotation.y = PI / 2.0 if direction > 0.0 else -PI / 2.0
		_play_person_animation(npc_anim_players.get(key), "run" if state == "fleeing" else "walk")

func _check_car_pedestrian_collisions() -> void:
	if abs(car_velocity) < 5.0:
		return
	for npc in npcs.duplicate():
		if is_instance_valid(npc) and npc.global_position.distance_to(car.global_position) < 2.25:
			_spawn_npc_ragdoll(npc)

func _register_npc_hit(npc: Node3D) -> void:
	var key := npc.get_instance_id()
	var hit_count: int = int(npc_hit_counts.get(key, 0)) + 1
	npc_hit_counts[key] = hit_count
	if hit_count >= 4:
		# Four arcade energy hits trigger a brief, non-graphic knockout.
		_spawn_npc_ragdoll(npc)
		return
	# Each earlier hit makes the pedestrian pause, turn, and flee.
	npc_states[key] = "startled"
	npc_alert_times[key] = 0.85
	npc_directions[key] = -1.0 if npc.global_position.x < player.global_position.x else 1.0

func _spawn_npc_ragdoll(npc: Node3D) -> void:
	_trigger_impact_effect()
	var origin := npc.global_position
	var key := npc.get_instance_id()
	npcs.erase(npc)
	npc_directions.erase(key)
	npc_walk_times.erase(key)
	npc_states.erase(key)
	npc_alert_times.erase(key)
	npc_hit_counts.erase(key)
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
		material.albedo_color = Color(1.0, 0.12, 0.08, 1.0)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.035, 0.015)
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
	var impact_strength: float = clampf(abs(car_velocity) / CAR_SPEED, 0.25, 1.0)
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
	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var steer := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	car_velocity = move_toward(car_velocity, throttle * CAR_SPEED, (22.0 if throttle != 0 else 12.0) * delta)
	if abs(car_velocity) > 0.5:
		car_yaw += steer * delta * 1.55 * sign(car_velocity) * clamp(abs(car_velocity) / 12.0, 0.25, 1.0)
	car.rotation.y = car_yaw
	car.position += -car.global_transform.basis.z * car_velocity * delta
	car.position.x = clamp(car.position.x, -238, 238)
	car.position.z = clamp(car.position.z, -238, 238)
	car.position.y = -0.2
	_check_car_pedestrian_collisions()
	if Input.is_action_pressed("vehicle_brake"):
		car_velocity = move_toward(car_velocity, 0, 28 * delta)
	if vr_enabled:
		# Keep the headset rig seated in the moving car and aligned with its heading.
		player.global_position = car.global_position + Vector3(0, 0.65, 0)
		player.rotation.y = car_yaw

func _try_enter_nearest_car() -> void:
	var nearest_car: Node3D = null
	var nearest_distance := 4.5
	for candidate in available_cars:
		if not is_instance_valid(candidate):
			continue
		var distance := player.global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_car = candidate
	if nearest_car == null:
		return
	if nearest_car != car:
		# Arcade-style vehicle takeover: the nearby traffic car pauses and
		# becomes driveable; no real-world theft instructions are represented.
		var traffic_index := traffic_cars.find(nearest_car)
		if traffic_index >= 0:
			traffic_cars.remove_at(traffic_index)
			traffic_speeds.remove_at(traffic_index)
		car = nearest_car
		car_model = car.get_node_or_null("TrafficSportsCoupe") as Node3D
		car_wheels.clear()
		if car_model:
			_create_vehicle_interior(car_model)
			_collect_car_wheels(car_model)
		_react_to_vehicle_takeover()
		_raise_wanted_level()
	_enter_car()

func _react_to_vehicle_takeover() -> void:
	var nearest_npc: Node3D = null
	var nearest_distance := 9.0
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		var distance := npc.global_position.distance_to(car.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_npc = npc
	if nearest_npc:
		var key := nearest_npc.get_instance_id()
		npc_states[key] = "startled"
		npc_alert_times[key] = 0.9
		npc_directions[key] = -1.0 if nearest_npc.global_position.x < car.global_position.x else 1.0

func _enter_car() -> void:
	if car_entry_in_progress:
		return
	car_entry_in_progress = true
	player.velocity = Vector3.ZERO
	door_audio.pitch_scale = rng.randf_range(0.92, 1.08)
	door_audio.play()
	_play_person_animation(player_anim_player, "walk")
	var door_position := car.global_position + car.global_transform.basis.x * 1.25 + Vector3(0, 0.15, 0)
	var seat_position := car.global_position + Vector3(0, 0.65, 0)
	var entry_tween := create_tween()
	entry_tween.tween_property(player, "global_position", door_position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entry_tween.parallel().tween_property(player, "rotation:y", car.rotation.y + PI * 0.5, 0.35)
	entry_tween.tween_property(player, "global_position", seat_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	entry_tween.tween_callback(_finish_enter_car)

func _finish_enter_car() -> void:
	car_entry_in_progress = false
	driving = true
	player.visible = false
	car_yaw = car.rotation.y
	if vr_enabled:
		player.rotation.y = car_yaw
	camera_pivot.rotation.x = -0.12
	engine_audio.play()

func _exit_car() -> void:
	driving = false
	player.visible = true
	player.global_position = car.global_position + car.global_transform.basis.x * 2.4 + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	# The camera pivot is a child of the player. While driving it is positioned
	# in world space beside the moving car; restore its local offset on exit so
	# the car's distance from the original spawn can never create a huge offset.
	camera_pivot.position = Vector3(0, 1.45, 0)
	camera_pivot.rotation = Vector3(-0.12, 0.0, 0)
	camera_spring.spring_length = 6.0
	camera.fov = 74.0
	car_velocity = 0.0
	if engine_audio.playing:
		engine_audio.stop()
	door_audio.pitch_scale = rng.randf_range(0.92, 1.08)
	door_audio.play()

func _update_camera() -> void:
	if driving:
		camera_pivot.global_position = car.global_position + Vector3(0, 1.9, 0)
		camera_pivot.rotation.y = car_yaw - player.rotation.y
	else:
		# The player root already carries the mouse-look yaw. Keeping the child
		# pivot at zero avoids doubling the camera rotation and skewing controls.
		camera_pivot.position = Vector3(0, 1.45, 0)
		camera_pivot.rotation.y = 0.0