extends SceneTree

# Walks the player up and down synthetic box stairs and checks that it stays grounded,
# keeps walking speed, and ends on the right tread, like the original step-up/step-down.

const BASE := Vector3(0, 300, 0)
const STEPS := 10

func _initialize() -> void:
	run.call_deferred()

func box(parent: Node, size: Vector3, pos: Vector3) -> void:
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)

func build(parent: Node, rise: float, depth: float) -> Node3D:
	var stairs = Node3D.new()
	parent.add_child(stairs)
	box(stairs, Vector3(6, 1, 30), BASE + Vector3(0, -0.5, 0))
	for i in STEPS:
		var height = rise * (i + 1)
		box(stairs, Vector3(6, height, depth), BASE + Vector3(0, height * 0.5, -3 - depth * (i + 0.5)))
	box(stairs, Vector3(6, rise * STEPS, 20), BASE + Vector3(0, rise * STEPS * 0.5, -3 - depth * STEPS - 10))
	return stairs

func walk(game: Node, start: Vector3, action: String, frames: int, label: String) -> void:
	var player = game.player
	player.global_position = BASE + start
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for i in 10:
		await physics_frame
	Input.action_press(action)
	for i in frames:
		await physics_frame
		var speed = Vector2(player.velocity.x, player.velocity.z).length()
		assert(player._grounded(), "%s: player left the ground at frame %d" % [label, i])
		assert(speed < 6.7, "%s: speed jumped to %.2f at frame %d" % [label, speed, i])
	Input.action_release(action)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "/private/tmp/doodleshooter-stairs-check.cfg"
	root.add_child(game)
	await game.start_game(1)
	game.enemies.clear()
	for dimensions in [[0.25, 0.4], [0.4, 0.3], [0.15, 0.3]]:
		var rise: float = dimensions[0]
		var depth: float = dimensions[1]
		var top = rise * STEPS
		var stairs = build(game, rise, depth)
		var label = "%.2f×%.2f" % [rise, depth]
		await walk(game, Vector3(0, 0.05, 0), "forward", 80, label + " up")
		assert(absf(game.player.global_position.y - BASE.y - top) < 0.03, label + " up: did not reach the top tread")
		await walk(game, Vector3(0, top + 0.05, -3 - depth * STEPS - 1), "back", 80, label + " down")
		assert(absf(game.player.global_position.y - BASE.y) < 0.03, label + " down: did not reach the bottom")
		stairs.free()
	game.show_main_menu()
	game._clear_world()
	game.sound.stop_all()
	await create_timer(0.3).timeout
	print("STAIRS PASS: step-up and step-down stay grounded at walking speed on three stair sizes")
	quit()
