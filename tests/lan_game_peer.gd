extends SceneTree

var game: Node3D
var host = false
var deadline = 0

func _initialize() -> void:
	host = "--host" in OS.get_cmdline_user_args()
	deadline = Time.get_ticks_msec() + 35000
	run.call_deferred()

func wait_for(condition: Callable, reason: String) -> void:
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			push_error("LAN game timed out: " + reason)
			quit(1)
			return
		await create_timer(0.01).timeout

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.lan-test-%s.cfg" % ("host" if host else "guest")
	root.add_child(game)
	game.show_lan_menu()
	game.name_input.text = "Host tester" if host else "Guest tester"
	if host:
		game.host_lan_game()
		print("LAN HOST READY")
	else:
		game.server_input.text = "127.0.0.1"
		game.join_lan_game()
	await wait_for(func(): return game.network.roster.size() == 2, "two-player lobby")
	if host:
		game.network.send_packet({"type": "start"})
	await wait_for(func(): return game.playing and not game.starting and is_instance_valid(game.player), "arena load")
	game.player.set_physics_process(false)
	game.player.position = Vector3(0, 80, 0 if host else -8)
	await wait_for(func(): return game.remote_players.size() == 1, "remote avatar")
	if host:
		await create_timer(2.2).timeout
		game.player.last_attack = "sniper"
		game.remote_players.values()[0].take_damage(150)
		await wait_for(func(): return game.network.roster.any(func(p): return p.deaths == 1), "kill scoreboard")
		await wait_for(func(): return game.network.roster.any(func(p): return p.deaths == 1 and p.hp == 120), "guest respawn scoreboard")
	else:
		await wait_for(func(): return not game.player.alive, "damage delivery")
		await create_timer(2.6).timeout
		game.network.send_packet({"type": "respawn"})
		await wait_for(func(): return game.player.alive and game.player.hp == 120, "respawn delivery")
		# Keep the guest connected until the host sees the updated roster.
		await create_timer(1.2).timeout
	game.show_main_menu()
	game._clear_world()
	game.sound.stop_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	await create_timer(0.1).timeout
	print("LAN GAME PASS: %s arena, remote avatar, damage, scoreboard, respawn" % ("host" if host else "guest"))
	quit()
