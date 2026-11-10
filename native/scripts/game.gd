extends Node3D

var level: DoodleLevel
var player: DoodlePlayer
var touch: DoodleTouchControls
var sound: DoodleSound
var region: NavigationRegion3D
var enemy_stats: Dictionary
var enemies: Array[DoodleEnemy] = []
var projectiles: Array[Dictionary] = []
var grenades: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var playing = false
var paused = false
var wave = 0
var score = 0
var kills = 0
var checkpoint = 0
var best = 0
var spawn_queue: Array[String] = []
var spawn_timer = 2.0
var intermission = 0.0
var map_key = "district"
var hud: Label
var center_text: Label
var scoreboard: Label
var crosshair: Label
var menu: PanelContainer
var menu_items: VBoxContainer
var hit_marker = 0.0
var hurt_flash = 0.0
var hurt_overlay: ColorRect
var ui: Control
var preferences = ConfigFile.new()
var use_touch = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
var starting = false
var save_path = "user://progress.cfg"
var particles: DoodleParticles
var shake = 0.0
var trajectory: Array[Vector3] = []
var trajectory_nodes: Array[MeshInstance3D] = []
var scope: ColorRect
var combo = 0
var combo_timer = 0.0
var modifier = ""
var speed_modifier = 1.0
var damage_modifier = 1.2
var swarm = false
var capture_mode = false
var network: DoodleNetwork
var remote_players: Dictionary = {}
var player_name = "Doodler"
var server_url = "ws://127.0.0.1:8911"
var online_spawn = 0
var death_timer = 0.0
var online_results: Array = []
var server_input: LineEdit
var name_input: LineEdit
var code_input: LineEdit
var status_message = ""
var pending_broken: Array = []
var last_room_code = ""

func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		save_path = "res://.smoke-progress.cfg"
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	_setup_inputs()
	preferences.load(save_path)
	best = int(preferences.get_value("progress", "best", 0))
	checkpoint = int(preferences.get_value("progress", "checkpoint", 0))
	enemy_stats = ReferenceAssets.read_json("enemy_stats")
	sound = DoodleSound.new()
	add_child(sound)
	for setting in ["music_enabled", "music_volume", "effects_volume", "enabled"]:
		sound.set(setting, preferences.get_value("audio", setting, sound.get(setting)))
	particles = DoodleParticles.new()
	add_child(particles)
	network = DoodleNetwork.new()
	add_child(network)
	network.received.connect(_network_packet)
	network.failed.connect(_network_failure)
	player_name = preferences.get_value("online", "name", "Doodler")
	server_url = preferences.get_value("online", "url", "ws://10.0.2.2:8911" if OS.has_feature("android") else "ws://127.0.0.1:8911")
	_setup_ui()
	show_main_menu()
	if "--smoke" in OS.get_cmdline_user_args():
		run_smoke.call_deferred()
	elif capture_mode:
		run_capture.call_deferred()

func _setup_inputs() -> void:
	var keys = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "dash": KEY_C, "grapple": KEY_Q, "reload": KEY_R, "slash": KEY_F, "grenade": KEY_G, "pause": KEY_ESCAPE, "scoreboard": KEY_TAB, "weapon_0": KEY_1, "weapon_1": KEY_2, "weapon_2": KEY_3, "weapon_3": KEY_4}
	for action in keys:
		InputMap.add_action(action)
		var event = InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	for entry in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		InputMap.add_action(entry[0])
		var event = InputEventMouseButton.new()
		event.button_index = entry[1]
		InputMap.action_add_event(entry[0], event)
	InputMap.add_action("next_weapon")
	for button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var event = InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event("next_weapon", event)
	var joy = {"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "reload": JOY_BUTTON_X, "next_weapon": JOY_BUTTON_Y, "grapple": JOY_BUTTON_LEFT_SHOULDER, "slash": JOY_BUTTON_RIGHT_SHOULDER, "grenade": JOY_BUTTON_RIGHT_STICK, "pause": JOY_BUTTON_START, "sprint": JOY_BUTTON_LEFT_STICK}
	for action in joy:
		var event = InputEventJoypadButton.new()
		event.button_index = joy[action]
		InputMap.action_add_event(action, event)
	for entry in [["left", JOY_AXIS_LEFT_X, -1], ["right", JOY_AXIS_LEFT_X, 1], ["forward", JOY_AXIS_LEFT_Y, -1], ["back", JOY_AXIS_LEFT_Y, 1], ["fire", JOY_AXIS_TRIGGER_RIGHT, 1], ["aim", JOY_AXIS_TRIGGER_LEFT, 1]]:
		var event = InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		InputMap.action_add_event(entry[0], event)

func _setup_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme = Theme.new()
	theme.default_font_size = 22
	theme.default_font = load("res://assets/fonts/PatrickHand-Regular.ttf")
	theme.set_color("font_color", "Label", ReferenceAssets.COLORS[0])
	theme.set_color("font_color", "Button", ReferenceAssets.COLORS[0])
	ui.theme = theme
	var paper = ColorRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_mat = ShaderMaterial.new()
	paper_mat.shader = preload("res://shaders/paper.gdshader")
	paper.material = paper_mat
	ui.add_child(paper)
	hud = Label.new()
	hud.position = Vector2(92, 24)
	ui.add_child(hud)
	center_text = Label.new()
	center_text.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center_text.position.y = 50
	center_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(center_text)
	scoreboard = Label.new()
	scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scoreboard.position = Vector2(-220, -190)
	scoreboard.custom_minimum_size = Vector2(440, 380)
	scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scoreboard.add_theme_font_size_override("font_size", 25)
	scoreboard.visible = false
	ui.add_child(scoreboard)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(9, 16)
	crosshair.add_theme_font_size_override("font_size", 30)
	ui.add_child(crosshair)
	touch = DoodleTouchControls.new()
	ui.add_child(touch)
	touch.visible = false
	hurt_overlay = ColorRect.new()
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_overlay.color = Color(0.86, 0.12, 0.2, 0)
	ui.add_child(hurt_overlay)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-285, -290)
	menu.custom_minimum_size = Vector2(570, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.97, 0.96, 0.91, 0.98)
	panel_style.border_color = ReferenceAssets.COLORS[0]
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 25
	panel_style.content_margin_bottom = 25
	menu.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(menu)
	menu_items = VBoxContainer.new()
	menu_items.add_theme_constant_override("separation", 12)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	menu_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(menu_items)
	scope = ColorRect.new()
	scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_material = ShaderMaterial.new()
	scope_material.shader = preload("res://shaders/scope.gdshader")
	scope.material = scope_material
	scope.visible = false
	ui.add_child(scope)
	ui.move_child(scope, 1)

func _clear_menu(title: String, subtitle: String) -> void:
	for child in menu_items.get_children():
		child.free()
	var heading = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 35)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_items.add_child(heading)
	var sub = Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	menu_items.add_child(sub)
	menu.visible = true
	crosshair.visible = false
	if scope != null:
		scope.visible = false
	touch.visible = false
	touch.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _button(text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.pressed.connect(callback)
	menu_items.add_child(button)
	return button

func show_main_menu() -> void:
	if network != null and network.connected:
		network.close()
	_clear_remote_players()
	playing = false
	paused = false
	_clear_menu("doodleshooter-port", "NATIVE PORT · ANDROID + iOS\nBased on Doodle District")
	var maps = OptionButton.new()
	maps.add_item("Doodle District")
	maps.add_item("Doodle Mexico · experimental in the original")
	maps.selected = 0 if map_key == "district" else 1
	maps.item_selected.connect(func(index): map_key = "district" if index == 0 else "mexico")
	maps.custom_minimum_size.y = 44
	menu_items.add_child(maps)
	_button("PLAY · SURVIVAL", func(): start_game(1))
	if checkpoint >= 5:
		_button("CONTINUE · WAVE " + str(checkpoint), func(): start_game(checkpoint))
	_button("PLAY ONLINE", show_online_menu)
	_button("CONTROLS & SETTINGS", show_settings)
	_button("CREDITS", show_credits)
	var foot = Label.new()
	foot.text = "Best score: %d\nDevelopment build · full parity in progress" % best
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 15)
	menu_items.add_child(foot)

func show_settings() -> void:
	_clear_menu("Controls", "WASD / left stick: move · mouse / right stick: look\nFire / R2 · aim / L2 · jump / A\nQ / L1: grapple · C / B: slide or air dash\nR / X: reload · F / R1: quick katana slash\nG / R3: grenade (hold to charge)\n1–4 / mouse wheel / Y: switch weapon\nTab: scoreboard · Esc / Start: pause")
	var toggle = CheckButton.new()
	toggle.text = "Show touch controls"
	toggle.button_pressed = use_touch
	toggle.toggled.connect(func(value): use_touch = value)
	menu_items.add_child(toggle)
	var audio = CheckButton.new()
	audio.text = "Sound effects"
	audio.button_pressed = sound.enabled
	audio.toggled.connect(func(value): sound.enabled = value; save_settings())
	menu_items.add_child(audio)
	var music_toggle = CheckButton.new()
	music_toggle.text = "Original soundtrack"
	music_toggle.button_pressed = sound.music_enabled
	music_toggle.toggled.connect(func(value): sound.music_enabled = value; save_settings())
	menu_items.add_child(music_toggle)
	for item in [["Music volume", "music_volume"], ["Effects volume", "effects_volume"]]:
		var label = Label.new()
		label.text = item[0]
		menu_items.add_child(label)
		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = sound.get(item[1])
		slider.value_changed.connect(func(value): sound.set(item[1], value); save_settings())
		menu_items.add_child(slider)
	_button("BACK", pause_menu if paused else show_main_menu)

func show_credits() -> void:
	_clear_menu("Credits", "Doodle District · original game\nhttps://doodleshooter.vercel.app/\n\nCode and geometry reference:\niifor/doodleshooter (GitHub)\n\nThis is an unofficial native port.\nThe original design, maps and mechanics\nare credited to their original creators.\n\nNative engine: Godot Engine\nWeb reference: Three.js and PeerJS\nSee CREDITS.txt for provenance and notices.")
	_button("OPEN ORIGINAL GAME", func(): OS.shell_open("https://doodleshooter.vercel.app/"))
	_button("BACK", show_main_menu)

func start_game(first_wave: int) -> void:
	if starting:
		return
	starting = true
	_clear_menu("Drawing the world…", "Loading original geometry and native navigation")
	await get_tree().process_frame
	_clear_world()
	score = 0
	kills = 0
	wave = 0
	region = NavigationRegion3D.new()
	var nav = NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	nav.agent_height = 2.0
	nav.agent_radius = 0.5
	nav.agent_max_climb = 0.5
	nav.agent_max_slope = 45
	region.navigation_mesh = nav
	add_child(region)
	level = DoodleLevel.new()
	region.add_child(level)
	level.load_map(map_key, network.in_match)
	sound.set_map(map_key)
	region.bake_navigation_mesh(false)
	player = DoodlePlayer.new()
	player.game = self
	add_child(player)
	player.position = level.start + Vector3.UP * 0.05
	touch.player = player
	await get_tree().physics_frame
	await get_tree().physics_frame
	starting = false
	resume_game()
	if network.in_match:
		apply_online_spawn(online_spawn)
		for id in pending_broken:
			if level.breakables.has(int(id)):
				level.hit_prop(level.breakables[int(id)].body, 9999, false)
		pending_broken.clear()
	else:
		start_wave(first_wave)

func _clear_world() -> void:
	playing = false
	_clear_remote_players()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.laser.free()
			enemy.free()
	enemies.clear()
	for dot in trajectory_nodes:
		dot.free()
	trajectory_nodes.clear()
	for list in [projectiles, grenades, pickups, effects]:
		for item in list:
			if is_instance_valid(item.node):
				item.node.free()
		list.clear()
	if is_instance_valid(player):
		player.rope.free()
		player.free()
	if is_instance_valid(region):
		region.free()

func resume_game() -> void:
	paused = false
	playing = true
	menu.visible = false
	crosshair.visible = true
	touch.visible = use_touch
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if use_touch or capture_mode else Input.MOUSE_MODE_CAPTURED

func pause_menu() -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	paused = true
	playing = false
	_clear_menu("Paused", "Wave %d · %d points" % [wave, score])
	_button("RESUME", resume_game)
	_button("CONTROLS & SETTINGS", show_settings)
	_button("MAIN MENU", show_main_menu)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and playing:
		pause_menu()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not starting:
		if paused:
			resume_game()
		elif playing:
			pause_menu()
		get_viewport().set_input_as_handled()

func start_wave(number: int) -> void:
	wave = number
	spawn_queue.clear()
	var roster = [["grunt", 1, 10], ["rusher", 2, 6], ["bomber", 3, 3], ["sniper", 3, 4], ["flyer", 4, 4], ["heavy", 5, 4], ["shield", 6, 4]]
	var pool: Array[String] = []
	for row in roster:
		if wave >= row[1]:
			for i in row[2]:
				if randf() < minf(1.0, 0.3 + 0.25 * (wave - row[1])):
					pool.append(row[0])
	var allowed = 1 if wave < 4 or wave % 5 == 0 else (3 if wave < 6 else 4)
	var selection = randi_range(0, allowed - 1)
	modifier = ["", "Caffeine · faster enemies", "Heavy Ink · harder hits", "Swarm · more enemies, less health"][selection]
	speed_modifier = [1.0, 1.35, 0.9, 1.15][selection]
	damage_modifier = [1.0, 0.85, 1.4, 0.9][selection] * 1.2
	swarm = selection == 3
	var count = roundi(mini(5 + wave * 2, 32 + wave) * (1.35 if swarm else 1.0))
	if wave % 5 == 0:
		spawn_queue.append(["boss", "eraser", "inkblot"][int((wave - 5) / 5) % 3])
		count = 7 + wave
		checkpoint = maxi(checkpoint, wave)
		save_progress()
	for i in count:
		spawn_queue.append(pool.pick_random() if not pool.is_empty() else "grunt")
	spawn_timer = 2.0
	intermission = 0.0
	player.grenades = mini(5, player.grenades + 1)
	for i in 7:
		spawn_pickup("ammo" if i < 5 else "health", level.pickup_spots.pick_random())
	sound.play_effect("wave")

func _process(delta: float) -> void:
	if not playing:
		return
	if network.in_match:
		update_online(delta)
		return
	combo_timer -= delta
	if combo_timer <= 0:
		combo = 0
	shake = move_toward(shake, 0, delta * 3)
	player.rig.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * minf(shake, 1.2) * 0.025
	scope.visible = player.weapon_index == 2 and player.aiming
	hit_marker = maxf(0, hit_marker - delta)
	hurt_flash = maxf(0, hurt_flash - delta)
	hurt_overlay.color.a = hurt_flash
	crosshair.text = "×" if hit_marker > 0 else "+"
	var ammo = "KATANA · %d%%" % int(player.katana_charge * 100) if player.weapon_index == 3 else "%s · %d / %d" % [player.weapon_names[player.weapon_index].to_upper(), player.magazines[player.weapon_index], player.reserves[player.weapon_index]]
	hud.text = "HEALTH %d / 120     WAVE %d     SCORE %d\n%s     GRENADES %d     GRAPPLE %d%%" % [int(player.hp), wave, score, ammo, player.grenades, int(player.stamina * 100)]
	if player.reload_time > 0:
		hud.text += " · RELOADING"
	center_text.text = "Next wave in %d" % ceili(intermission) if intermission > 0 else "%d remaining" % (enemies.size() + spawn_queue.size())
	for enemy in enemies:
		if enemy.stats.get("boss", false):
			center_text.text += "\n%s · %d / %d" % [enemy.stats.name, int(enemy.hp), int(enemy.max_hp)]
	if modifier != "":
		center_text.text += "\n" + modifier
	if intermission > 0:
		intermission -= delta
		if intermission <= 0:
			start_wave(wave + 1)
	elif not spawn_queue.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0 and enemies.size() < mini(4 + int(wave * 0.9), 18 + int(wave / 3)):
			spawn_enemy(spawn_queue.pop_front())
			spawn_timer = maxf(0.7, 2.9 - wave * 0.13)
	elif enemies.is_empty():
		intermission = 8.0
		score += wave * 200
		player.hp = minf(120, player.hp + 40)
		sound.play_effect("waveClear")
	sound.intensity = clampf(float(enemies.size()) / 15.0 + (0.25 if player.hp < 35 else 0.0), 0, 1)
	for dot in trajectory_nodes:
		dot.visible = player.charging
	_update_effects(delta)

func spawn_enemy(kind: String) -> DoodleEnemy:
	var spots = level.snipers if kind == "sniper" else level.spawns
	var far: Array[Vector3] = []
	for spot in spots:
		if spot.distance_to(player.position) > 14:
			far.append(spot)
	var point: Vector3 = far.pick_random() if not far.is_empty() else spots.pick_random()
	if kind == "flyer":
		point = player.position + Vector3(randf_range(-20, 20), 14, randf_range(-20, 20))
	var enemy = DoodleEnemy.new()
	enemy.kind = kind
	enemy.game = self
	add_child(enemy)
	enemy.position = point + Vector3.UP * 0.1
	enemies.append(enemy)
	return enemy

func enemy_killed(enemy: DoodleEnemy) -> void:
	enemies.erase(enemy)
	kills += 1
	combo += 1
	combo_timer = 3.5
	var points = int(enemy.stats.score) + maxi(0, combo - 1) * 10
	if not player.is_on_floor():
		points += 40
	if player.last_attack == "katana":
		player.katana_charge = minf(1, player.katana_charge + 1.0 / 3.0)
		player.blood_level = minf(1, player.blood_level + 0.3)
	score += points
	burst(enemy.position + Vector3.UP, 1, 26)
	blood_pool(enemy.position, 0.8, 1)
	if randf() < 0.5:
		spawn_pickup("ammo", enemy.position)
	elif randf() < 0.24:
		spawn_pickup("health", enemy.position)
	sound.play_effect("kill")

func save_progress() -> void:
	best = maxi(best, score)
	preferences.set_value("progress", "best", best)
	preferences.set_value("progress", "checkpoint", checkpoint)
	preferences.save(save_path)

func game_over() -> void:
	if network.in_match:
		death_timer = 2.5
		return
	playing = false
	save_progress()
	_clear_menu("You got erased", "%d waves · %d kills · %d points\nBest score: %d" % [wave, kills, score, best])
	_button("DRAW AGAIN", func(): start_game(1))
	if checkpoint >= 5:
		_button("FROM CHECKPOINT", func(): start_game(checkpoint))
	_button("MAIN MENU", show_main_menu)

func make_line(ink: int = 0, radius: float = 0.025) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.height = 1
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 4
	node.mesh = mesh
	node.material_override = ReferenceAssets.material(ink, true)
	add_child(node)
	return node

func line_between(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var direction = to - from
	node.position = (from + to) * 0.5
	if direction.length() > 0.001:
		node.quaternion = Quaternion(Vector3.UP, direction.normalized())
		node.scale = Vector3(1, direction.length(), 1)

func tracer(from: Vector3, to: Vector3, ink: int = 0) -> void:
	var node = make_line(ink, 0.012)
	line_between(node, from, to)
	effects.append({"node": node, "life": 0.07})

func fire_projectile(from: Vector3, direction: Vector3, speed: float, damage: float, reflected: bool = false, blast: float = 0.0) -> void:
	var node = make_line(0 if reflected else 1, 0.04)
	line_between(node, from, from + direction * 0.5)
	projectiles.append({"node": node, "position": from, "velocity": direction * speed, "damage": damage, "life": 5.0, "reflected": reflected, "blast": blast})

func throw_grenade(from: Vector3, velocity: Vector3, mine: bool = true) -> void:
	var node = RigidBody3D.new()
	var visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	visual.mesh = sphere
	visual.material_override = ReferenceAssets.material(3, true)
	node.add_child(visual)
	var shape = CollisionShape3D.new()
	var bound = SphereShape3D.new()
	bound.radius = 0.12
	shape.shape = bound
	node.add_child(shape)
	node.collision_layer = 8
	node.collision_mask = 1
	var bounce = PhysicsMaterial.new()
	bounce.bounce = 0.5
	node.physics_material_override = bounce
	node.gravity_scale = 22.0 / 9.8
	add_child(node)
	node.position = from
	node.linear_velocity = velocity
	grenades.append({"node": node, "life": 2.1, "mine": mine})
	if network.in_match and mine:
		network.send_packet({"type": "grenade", "position": [from.x, from.y, from.z], "velocity": [velocity.x, velocity.y, velocity.z]})

func explode(at: Vector3, radius: float, damage: float, friendly: bool = true) -> void:
	var visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	visual.mesh = sphere
	visual.material_override = ReferenceAssets.material(3, false)
	add_child(visual)
	visual.position = at
	effects.append({"node": visual, "life": 0.2})
	sound.play_effect("explosion", at)
	burst(at, 3, 48)
	blood_pool(at, radius * 0.6, 3)
	shake += 0.7
	if network.in_match and friendly:
		network.send_packet({"type": "blast", "position": [at.x, at.y, at.z]})
	if not network.in_match and player.position.distance_to(at) < radius:
		var distance = (player.position + Vector3.UP).distance_to(at)
		player.take_damage(10 + 34 * (1 - distance / (radius * 0.95)) if friendly else damage)
		player.velocity += ((player.position + Vector3.UP) - at).normalized() * 9
	if friendly and not network.in_match:
		for enemy in enemies.duplicate():
			var distance = enemy.position.distance_to(at)
			if distance < radius:
				enemy.take_damage(damage * clampf(1 - distance / radius, 0.2, 1))
	if friendly:
		for prop in level.breakables.values().duplicate():
			if prop.position.distance_to(at) < radius:
				level.hit_prop(prop.body, damage)

func spawn_pickup(kind: String, at: Vector3) -> void:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.45, 0.3, 0.45)
	node.mesh = mesh
	node.material_override = ReferenceAssets.material(4 if kind == "health" else 3, true)
	add_child(node)
	node.position = at + Vector3.UP * 0.5
	pickups.append({"node": node, "kind": kind, "life": 35.0})

func _physics_process(delta: float) -> void:
	# Touch actions do not generate InputEvents; observe pause/weapon here too.
	if touch != null and touch.visible:
		if Input.is_action_just_pressed("pause") and playing:
			pause_menu()
		if playing and Input.is_action_just_pressed("next_weapon"):
			player.switch_weapon((player.weapon_index + 1) % 4)
	if not playing:
		for grenade in grenades:
			grenade.node.freeze = true
		return
	for grenade in grenades:
		grenade.node.freeze = false
		grenade.life -= delta
		if grenade.life <= 0:
			explode(grenade.node.position, 6.4, 120, grenade.mine)
			grenade.node.queue_free()
	grenades = grenades.filter(func(g): return g.life > 0)
	for projectile in projectiles:
		projectile.life -= delta
		if projectile.blast > 0:
			projectile.velocity.y -= delta * 10
		var from: Vector3 = projectile.position
		var to: Vector3 = from + projectile.velocity * delta
		var query = PhysicsRayQueryParameters3D.create(from, to, 1 | (4 if projectile.reflected else 2))
		query.collide_with_areas = true
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider == player:
				var deflection = player.try_deflect(projectile.velocity)
				if deflection == 2:
					projectile.reflected = true
					projectile.velocity = -projectile.velocity
					to = from + projectile.velocity * delta
					projectile.node.material_override = ReferenceAssets.material(0, true)
				elif deflection == 1:
					projectile.life = 0
				else:
					player.take_damage(projectile.damage)
					projectile.life = 0
			elif hit.collider.has_method("take_damage"):
				hit.collider.take_damage(projectile.damage * 2)
				projectile.life = 0
			else:
				projectile.life = 0
			if projectile.life <= 0 and projectile.blast > 0:
				explode(hit.position, 3.2, projectile.damage, projectile.reflected)
		projectile.position = to
		line_between(projectile.node, to, to + projectile.velocity.normalized() * 0.5)
		if projectile.life <= 0:
			projectile.node.queue_free()
	projectiles = projectiles.filter(func(p): return p.life > 0)
	for pickup in pickups:
		pickup.life -= delta
		pickup.node.rotate_y(delta * 2)
		if pickup.node.position.distance_to(player.position + Vector3.UP * 0.7) < 1.7:
			if pickup.kind == "health":
				player.hp = minf(120, player.hp + 35)
			else:
				for i in 3:
					player.reserves[i] = mini(player.reserves[i] + [35, 6, 5][i], [350, 72, 50][i])
			sound.play_effect("pickup")
			pickup.life = 0
		if pickup.life <= 0:
			pickup.node.queue_free()
	pickups = pickups.filter(func(p): return p.life > 0)

func _update_effects(delta: float) -> void:
	for effect in effects:
		effect.life -= delta
		if effect.life <= 0:
			effect.node.queue_free()
	effects = effects.filter(func(e): return e.life > 0)

func _exit_tree() -> void:
	ReferenceAssets.dispose()

func run_smoke() -> void:
	await start_game(1)
	assert(level.data.boxes.size() == 517)
	assert(player.magazines[0] == 35)
	await get_tree().physics_frame
	var floor_hit = player.ray(10, Vector3.DOWN)
	assert(not floor_hit.is_empty(), "Native map colliders must block rays")
	player.fire()
	assert(player.magazines[0] == 34, "Rifle must consume ammunition")
	player.reload()
	for i in 110:
		await get_tree().physics_frame
	assert(player.magazines[0] == 35 and player.reserves[0] == 174, "Reload must transfer reserve ammunition")
	var before_move = player.position
	Input.action_press("forward")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("forward")
	assert(player.position.distance_to(before_move) > 1.0, "Movement must change the physical body position")
	Input.action_press("jump")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("jump")
	assert(player.velocity.y > 0, "Jump must lift the player")
	for i in 35:
		await get_tree().physics_frame
	Input.action_press("jump")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("jump")
	assert(player.velocity.y > 0 and player.jumps == 0, "Double jump must consume the airborne jump")
	for i in 100:
		await get_tree().physics_frame
	player.camera.rotation.x = -0.7
	Input.action_press("grapple")
	for i in 3:
		await get_tree().physics_frame
	assert(player.grapple_active and player.stamina < 1, "Grapple must acquire a native collider and consume energy")
	Input.action_release("grapple")
	for i in 3:
		await get_tree().physics_frame
	assert(player.grapple_active, "Releasing the grapple must preserve the swing")
	Input.action_press("grapple")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("grapple")
	assert(not player.grapple_active, "A second grapple press must detach it")
	player.camera.rotation.x = 0
	touch.visible = true
	var finger = InputEventScreenTouch.new()
	finger.index = 4
	finger.position = Vector2(100, touch.size.y - 100)
	finger.pressed = true
	touch._input(finger)
	var drag = InputEventScreenDrag.new()
	drag.index = 4
	drag.position = finger.position + Vector2(60, 0)
	touch._input(drag)
	assert(touch.move_vector.x > 0.8, "Touch joystick must generate movement")
	var fire_finger = InputEventScreenTouch.new()
	fire_finger.index = 5
	fire_finger.position = Vector2(touch.size.x - 108, touch.size.y - 180)
	fire_finger.pressed = true
	touch._input(fire_finger)
	assert(Input.is_action_pressed("fire") and touch.move_finger == 4, "A second finger must fire without stealing the joystick")
	fire_finger.pressed = false
	touch._input(fire_finger)
	assert(not Input.is_action_pressed("fire"), "Releasing fire must stop the action")
	touch.reset()
	touch.visible = use_touch
	var enemy = spawn_enemy("grunt")
	var old_score = score
	enemy.take_damage(999)
	assert(score >= old_score + 100 and kills == 1)
	player.take_damage(20)
	assert(player.hp <= 100)
	pause_menu()
	assert(not playing and paused)
	resume_game()
	assert(playing and not paused)
	throw_grenade(player.camera.global_position, Vector3.UP)
	assert(grenades.size() == 1)
	player.switch_weapon(1)
	player.magazines[1] = 2
	player.reserves[1] = 10
	player.reload()
	player.reload_time = 0.001
	for i in 2:
		await get_tree().physics_frame
	assert(player.magazines[1] == 3 and player.reserves[1] == 9, "Shotgun reload must transfer one shell at a time")
	assert(player.reload_time > 0, "Shotgun must continue loading remaining shells")
	player.fire()
	assert(player.magazines[1] == 2 and player.reload_time == 0, "Firing must interrupt the shotgun reload")
	player.switch_weapon(3)
	player.aiming = true
	player.fire_cd = 0
	player.block_time = 0
	player.block_cd = 0
	assert(player.try_deflect(player.camera.global_basis.z) == 2, "A frontal projectile inside the perfect parry window must reflect")
	assert(player.try_deflect(player.camera.global_basis.z) == 0, "Parry cooldown must prevent repeated reflections")
	player.block_cd = 0
	assert(player.try_deflect(-player.camera.global_basis.z) == 0, "Katana must not block projectiles from behind")
	print("SMOKE PASS: district collision, firing, reload, movement, double jump, grapple, multitouch, scoring, damage, pause, grenade")
	map_key = "mexico"
	await start_game(5)
	assert(level.data.boxes.size() == 321)
	assert(not level.breakables.is_empty())
	var prop: Dictionary = level.breakables.values()[0]
	var count = level.breakables.size()
	level.hit_prop(prop.body, 999)
	assert(level.breakables.size() == count - 1)
	assert(spawn_queue[0] == "boss")
	for kind in enemy_stats:
		var e = spawn_enemy(kind)
		assert(e.model != null)
		assert(not e.model.find_children("*", "Area3D", true, false).is_empty(), "Every enemy model needs damage hitboxes")
	var target = spawn_enemy("grunt")
	target.set_physics_process(false)
	target.position = Vector3(0, 80, -8)
	target.model.scale = Vector3.ONE * target.model_scale
	player.set_physics_process(false)
	var saved_position = player.position
	player.position = Vector3(0, 80, 0)
	for i in 2:
		await get_tree().physics_frame
	var head = target.model.find_child("hit_head", true, false).get_child(0)
	var head_hit = player.ray(20, (head.global_position - player.camera.global_position).normalized())
	assert(not head_hit.is_empty() and head_hit.collider == head, "Physics raycasts must resolve the animated head hitbox")
	var previous_hp = target.hp
	head_hit.collider.take_damage(1, head_hit.position)
	assert(target.hp == previous_hp - 1, "Hitbox damage must reach the owning enemy")
	player.position = saved_position
	player.set_physics_process(true)
	var boss = spawn_enemy("boss")
	var projectile_count = projectiles.size()
	boss.begin_attack("throw")
	boss.think_boss(0.7, player.position, 20)
	assert(projectiles.size() == projectile_count + 1, "The Doodler's throw must create a projectile")
	var inkblot = spawn_enemy("inkblot")
	inkblot.begin_attack("spray")
	inkblot.think_boss(0.7, player.position, 20)
	assert(inkblot.shots == 1, "The Inkblot must emit its spray sequence")
	for i in 180:
		await get_tree().physics_frame
	print("SMOKE PASS: mexico collision, destructibles, checkpoint, boss queue, all enemy models")
	_clear_world()
	sound.stop_all()
	# Let the audio thread release stopped playback before engine shutdown.
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func save_settings() -> void:
	for setting in ["music_enabled", "music_volume", "effects_volume", "enabled"]:
		preferences.set_value("audio", setting, sound.get(setting))
	preferences.save(save_path)

func burst(at: Vector3, ink: int, count: int) -> void:
	particles.burst(at, ink, count)

func blood_pool(at: Vector3, radius: float, ink: int) -> void:
	var query = PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 4, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.length_squared() < 0.0001:
		return
	var node = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.012
	disc.radial_segments = 12
	node.mesh = disc
	node.material_override = ReferenceAssets.material(ink, true)
	add_child(node)
	node.position = hit.position + hit.normal * 0.015
	node.quaternion = Quaternion(Vector3.UP, hit.normal)
	effects.append({"node": node, "life": 24.0})

func preview_grenade(from: Vector3, velocity: Vector3) -> void:
	trajectory.clear()
	var at = from
	var speed = velocity
	for i in 26:
		var next = at + speed / 15.0
		speed.y -= 22.0 / 15.0
		var query = PhysicsRayQueryParameters3D.create(at, next, 1)
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			next = hit.position + hit.normal * 0.16
			speed = speed.bounce(hit.normal) * 0.55
		at = next
		trajectory.append(at)
		if trajectory_nodes.size() <= i:
			var dot = make_line(3, 0.045)
			trajectory_nodes.append(dot)
		line_between(trajectory_nodes[i], at, at + Vector3.UP * 0.08)
		trajectory_nodes[i].visible = true

func run_capture() -> void:
	if "--mexico" in OS.get_cmdline_user_args():
		map_key = "mexico"
	await start_game(1)
	use_touch = "--touch" in OS.get_cmdline_user_args()
	touch.visible = use_touch
	for i in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path = OS.get_environment("DOODLE_CAPTURE")
	if path.is_empty():
		path = "/private/tmp/doodleshooter-" + map_key + ".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE: ", path)
	get_tree().quit()

func show_online_menu() -> void:
	playing = false
	_clear_menu("Play online", "Free for all · 10 players · first to 20 kills
Connect to a native lobby server")
	name_input = LineEdit.new()
	name_input.placeholder_text = "Your name"
	name_input.text = player_name
	menu_items.add_child(name_input)
	server_input = LineEdit.new()
	server_input.placeholder_text = "wss://your-lobby-server"
	server_input.text = server_url
	menu_items.add_child(server_input)
	_button("QUICK PLAY", func(): connect_online({"type": "quick", "map": map_key}))
	_button("CREATE PUBLIC LOBBY", func(): connect_online({"type": "host", "public": true, "map": map_key}))
	_button("CREATE PRIVATE LOBBY", func(): connect_online({"type": "host", "public": false, "map": map_key}))
	code_input = LineEdit.new()
	code_input.placeholder_text = "Five-character lobby code"
	code_input.max_length = 5
	menu_items.add_child(code_input)
	_button("JOIN CODE", func(): connect_online({"type": "join", "code": code_input.text.to_upper()}))
	_button("BROWSE PUBLIC LOBBIES", func(): connect_online({"type": "list"}))
	_button("BACK", show_main_menu)

func connect_online(request: Dictionary) -> void:
	player_name = name_input.text.strip_edges().left(24)
	server_url = server_input.text.strip_edges()
	preferences.set_value("online", "name", player_name)
	preferences.set_value("online", "url", server_url)
	preferences.save(save_path)
	network.connect_lobby(server_url, request)
	_clear_menu("Connecting…", "Contacting the lobby server")
	_button("CANCEL", show_main_menu)

func show_lobby() -> void:
	if network.in_match or starting:
		return
	last_room_code = network.code
	var names = ""
	for entry in network.roster:
		names += entry.name + (" · host" if entry.id == network.host_id else "") + "\n"
	_clear_menu("Lobby " + network.code, names + "\nFree for all · first to 20 · 10 minute limit")
	if network.peer_id == network.host_id:
		var maps = OptionButton.new()
		maps.add_item("Doodle District")
		maps.add_item("Doodle Mexico")
		maps.selected = 0 if map_key == "district" else 1
		maps.item_selected.connect(func(index): network.send_packet({"type": "map", "map": "district" if index == 0 else "mexico"}))
		menu_items.add_child(maps)
	_button("START MATCH", func(): network.send_packet({"type": "start"}))
	_button("LEAVE LOBBY", show_main_menu)

func _network_packet(packet: Dictionary) -> void:
	match packet.get("type", ""):
		"lobby":
			map_key = packet.map
			show_lobby()
		"rooms":
			_clear_menu("Public lobbies", "Choose an open room")
			for room in packet.rooms:
				var code: String = room.code
				_button("%s · %s · %d/10" % [code, room.host, int(room.players)], func(): network.send_packet({"type": "join", "code": code}))
			_button("BACK", show_online_menu)
		"start":
			network.in_match = true
			map_key = packet.map
			online_spawn = int(packet.spawn)
			pending_broken = packet.broken
			last_room_code = network.code
			start_game(0)
		"state":
			if not starting and network.in_match and is_instance_valid(player):
				var state: Dictionary = packet.state
				var id: String = state.id
				if not remote_players.has(id):
					var remote = DoodleRemotePlayer.new()
					remote.peer_id = id
					remote.game = self
					add_child(remote)
					remote_players[id] = remote
				remote_players[id].update_state(state)
		"left":
			if remote_players.has(packet.id):
				remote_players[packet.id].queue_free()
				remote_players.erase(packet.id)
		"damage":
			if is_instance_valid(player) and player.alive:
				player.hp = float(packet.hp) + float(packet.amount)
				player.take_damage(float(packet.amount))
		"respawn":
			apply_online_spawn(int(packet.spawn))
			player.hp = 120
			player.alive = true
			player.grenades = 3
			player.magazines = [35, 6, 5, 0]
			player.reserves = [175, 36, 25, 0]
			player.reload_time = 0
			player.cycle_time = 0
			player.fire_cd = 0
			player.charging = false
			player.throw_charge = 0
			player.slide_time = 0
			player.stamina = 1
			player.katana_charge = 0
			trajectory.clear()
			resume_game()
		"shot":
			if remote_players.has(packet.id):
				var remote = remote_players[packet.id]
				tracer(remote.position + Vector3.UP * 1.4, ReferenceAssets.vector(packet.end), 0)
				sound.play_effect(["enemyShot", "shotgun", "sniperShot", "katanaSwing"][clampi(int(packet.weapon), 0, 3)], remote.position)
		"grenade":
			if not starting and network.in_match:
				throw_grenade(ReferenceAssets.vector(packet.position), ReferenceAssets.vector(packet.velocity), false)
		"broken":
			if is_instance_valid(level) and level.breakables.has(int(packet.id)):
				level.hit_prop(level.breakables[int(packet.id)].body, 9999, false)
		"result":
			playing = false
			online_results = packet.players
			var scores = ""
			for entry in online_results:
				scores += "%s · %d kills · %d deaths\n" % [entry.name, int(entry.kills), int(entry.deaths)]
			_clear_menu("Match finished", scores)
			_button("MAIN MENU", show_main_menu)
		"idle":
			playing = false
			_clear_menu("Away from the page", packet.message)
			_button("REJOIN", func(): network.send_packet({"type": "join", "code": packet.code}))
			_button("MAIN MENU", show_main_menu)
		"error":
			_network_failure(packet.message)

func _network_failure(message: String) -> void:
	playing = false
	_clear_menu("Connection", message)
	_button("BACK TO ONLINE", show_online_menu)
	_button("MAIN MENU", show_main_menu)

func _clear_remote_players() -> void:
	for remote in remote_players.values():
		remote.queue_free()
	remote_players.clear()

func apply_online_spawn(index: int) -> void:
	var points: Array = level.data.arena_spawns
	if points.is_empty():
		points = level.data.spawns
	player.position = ReferenceAssets.vector(points[index % points.size()]) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.detach_grapple()

func update_online(delta: float) -> void:
	var own_kills = 0
	for entry in network.roster:
		if entry.id == network.peer_id:
			own_kills = int(entry.kills)
	hud.text = "HEALTH %d / 120     KILLS %d / 20     %02d:%02d\n%s · %d / %d     GRENADES %d" % [int(player.hp), own_kills, network.remaining / 60, network.remaining % 60, player.weapon_names[player.weapon_index].to_upper(), player.magazines[player.weapon_index], player.reserves[player.weapon_index], player.grenades]
	var standings = network.roster.duplicate()
	standings.sort_custom(func(a, b): return int(a.kills) > int(b.kills))
	scoreboard.text = "FREE FOR ALL\n" + "\n".join(standings.map(func(entry): return "%s     %d K / %d D" % [entry.name, entry.kills, entry.deaths]))
	scoreboard.visible = Input.is_action_pressed("scoreboard")
	center_text.text = "Lobby " + network.code
	scope.visible = player.weapon_index == 2 and player.aiming
	hit_marker = maxf(0, hit_marker - delta)
	hurt_flash = maxf(0, hurt_flash - delta)
	hurt_overlay.color.a = hurt_flash
	crosshair.text = "×" if hit_marker > 0 else "+"
	if not player.alive:
		death_timer -= delta
		center_text.text = "You got erased · respawn in %d" % maxi(0, ceili(death_timer))
		if death_timer <= 0 and not menu.visible:
			_clear_menu("You got erased", "Rejoin the fight with a two-second shield")
			_button("RESPAWN", func(): network.send_packet({"type": "respawn"}))
			_button("LEAVE MATCH", show_main_menu)
	for dot in trajectory_nodes:
		dot.visible = player.charging
	_update_effects(delta)
