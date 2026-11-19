extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func same_rotation(actual: Quaternion, values: Array) -> bool:
	return absf(actual.dot(Quaternion(values[0], values[1], values[2], values[3]))) > 0.99999

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "/private/tmp/doodleshooter-jungle-check.cfg"
	root.add_child(game)
	game.map_key = "jungle"
	await game.start_game(1)
	game.playing = false
	game.player.set_physics_process(false)
	assert(game.level.data.boxes.size() == 647)
	assert(game.level.data.arena_spawns.size() == 28)
	assert(game.level.map_animations.size() == 25)
	assert(game.level.data.grapple_targets.size() == 20)
	assert(game.level.spawns.size() == 17 and game.level.snipers.size() == 12)
	var geometry = game.level.get_child(0)
	var samples = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../tests/jungle_motion.json")))
	for sample in samples:
		game.level.animate_at(float(sample.time))
		for expected in sample.nodes:
			var visual = geometry.get_child(int(expected.node))
			assert(visual.position.distance_to(ReferenceAssets.vector(expected.position)) < 0.0001)
			assert(visual.scale.distance_to(ReferenceAssets.vector(expected.scale)) < 0.0001)
			assert(same_rotation(visual.quaternion, expected.quaternion))
			for i in expected.children.size():
				assert(same_rotation(visual.get_child(i).quaternion, expected.children[i].quaternion))
			if expected.has("rope_position"):
				var animation = game.level.map_animations.filter(func(entry): return int(entry.node) == int(expected.node))[0]
				var rope = animation.rope_visual
				assert(rope.position.distance_to(ReferenceAssets.vector(expected.rope_position)) < 0.0001)
				assert(rope.scale.distance_to(ReferenceAssets.vector(expected.rope_scale)) < 0.0001)
				assert(same_rotation(rope.quaternion, expected.rope_quaternion))
	var from = game.level.start + Vector3.UP * 4
	var hit = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 8, 1))
	assert(not hit.is_empty() and absf(hit.position.y) < 0.001)
	assert(ReferenceAssets.map_colors[0].is_equal_approx(Color(0.06, 0.3, 0.52)))
	game.match_mode = "bots"
	game.bot_count = 2
	await game.start_game(0)
	game.playing = false
	assert(game.level.data.arena and game.bot_match.bots.size() == 2)
	assert(game.level.data.arena_spawns.size() == 28)
	game.map_key = "district"
	await game.start_game(1)
	assert(ReferenceAssets.map_colors[0].is_equal_approx(ReferenceAssets.COLORS[0]))
	assert(ReferenceAssets.map_paper.is_equal_approx(Color(0.97, 0.96, 0.91)))
	game.show_main_menu()
	game._clear_world()
	game.sound.stop_all()
	await create_timer(0.1).timeout
	print("JUNGLE PASS: survival/arena, 647 colliders, spawns, ground ray, 25 original animations at three times, moving grapple targets, palette reset")
	quit()
