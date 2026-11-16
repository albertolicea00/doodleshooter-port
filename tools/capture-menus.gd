extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output = OS.get_environment("DOODLE_CAPTURE_DIR")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://").path_join("../builds/validation")
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for screen in ["credits", "offline", "lan", "maps", "main"]:
		match screen:
			"credits": game.show_credits()
			"offline": game.show_offline_menu()
			"lan": game.show_lan_menu()
			"maps": game.show_map_menu(game.show_main_menu)
			"main": game.show_main_menu()
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("doodleshooter-menu-" + screen + ".png"))
		print("MENU CAPTURE: " + screen)
	quit()
