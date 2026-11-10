class_name DoodleBotMatch
extends Node

var game: Node3D
var active = false
var difficulty = 1
var remaining = 600.0
var scores: Dictionary = {}
var bots: Array[DoodleArenaBot] = []
var player_respawn = 0.0
var player_shield = 2.0

func begin(count: int, skill: int) -> void:
	stop()
	active = true
	difficulty = clampi(skill, 0, 2)
	remaining = 600
	scores["player"] = {"name": game.player_name, "kills": 0, "deaths": 0}
	player_shield = 2
	for i in clampi(count, 1, 9):
		var bot = DoodleArenaBot.new()
		bot.game = game
		bot.match_controller = self
		bot.peer_id = "bot_" + str(i)
		game.add_child(bot)
		bots.append(bot)
		game.remote_players[bot.peer_id] = bot
		scores[bot.peer_id] = {"name": "Doodler Bot %d" % (i + 1), "kills": 0, "deaths": 0}
		respawn_bot(bot, i + 1)
	game.reset_arena_player(0)
	for i in 7:
		game.spawn_pickup("ammo" if i < 5 else "health", game.level.pickup_spots.pick_random())

func stop() -> void:
	active = false
	bots.clear()
	scores.clear()

func spawn_position(index: int = -1) -> Vector3:
	var points: Array = game.level.data.arena_spawns
	if points.is_empty():
		points = game.level.data.spawns
	var selected = randi_range(0, points.size() - 1) if index < 0 else index % points.size()
	return ReferenceAssets.vector(points[selected]) + Vector3.UP * 0.1

func respawn_bot(bot: DoodleArenaBot, index: int = -1) -> void:
	bot.position = spawn_position(index)
	bot.hp = 120
	bot.alive = true
	bot.model.visible = true
	bot.collision_layer = 32
	bot.velocity = Vector3.ZERO
	bot.invulnerable = 2
	bot.fire_time = 1
	bot.think_time = 0

func choose_target(bot: DoodleArenaBot) -> Node3D:
	var candidates: Array = []
	candidates.append_array(bots)
	candidates.append(game.player)
	var nearest: Node3D
	var distance = INF
	for actor in candidates:
		if actor == bot or not actor.alive:
			continue
		var offset = bot.position.distance_squared_to(actor.position)
		if offset < distance:
			distance = offset
			nearest = actor
	return nearest

func damage(id: String, amount: float, attacker: String) -> void:
	if not active or not scores.has(id) or not scores.has(attacker):
		return
	if id == "player":
		if not game.player.alive or player_shield > 0:
			return
		game.player.take_damage(amount)
		if game.player.alive:
			return
		player_respawn = 2.5
	else:
		var bot: DoodleArenaBot = game.remote_players[id]
		if not bot.alive or bot.invulnerable > 0:
			return
		bot.hp = maxf(0, bot.hp - amount)
		game.hit_marker = 0.15 if attacker == "player" else game.hit_marker
		if bot.hp > 0:
			return
		bot.alive = false
		bot.model.visible = false
		bot.collision_layer = 0
		bot.respawn_time = 2.5
		game.burst(bot.position + Vector3.UP, 1, 24)
	scores[id].deaths += 1
	if attacker != id:
		scores[attacker].kills += 1
	if scores[attacker].kills >= 20:
		finish()

func blast(at: Vector3) -> void:
	for id in scores:
		var actor = game.player if id == "player" else game.remote_players[id]
		var distance = (actor.position + Vector3.UP).distance_to(at)
		if distance < 6.4:
			damage(id, 62 * (1 - distance / 6.4), "player")
		if not active:
			break

func update(delta: float) -> void:
	if not active:
		return
	remaining = maxf(0, remaining - delta)
	player_shield = maxf(0, player_shield - delta)
	if remaining <= 0:
		finish()
		return
	if not game.player.alive:
		player_respawn -= delta
		if player_respawn <= 0:
			game.reset_arena_player(randi_range(0, 15))
			player_shield = 2
	game.hud.text = "HEALTH %d / 120     KILLS %d / 20     %02d:%02d\n%s · %d / %d     GRENADES %d" % [int(game.player.hp), scores.player.kills, int(remaining) / 60, int(remaining) % 60, game.player.weapon_names[game.player.weapon_index].to_upper(), game.player.magazines[game.player.weapon_index], game.player.reserves[game.player.weapon_index], game.player.grenades]
	var standings = sorted_scores()
	game.scoreboard.text = "OFFLINE FREE FOR ALL\n" + "\n".join(standings.map(func(entry): return "%s     %d K / %d D" % [entry.name, entry.kills, entry.deaths]))
	game.scoreboard.visible = Input.is_action_pressed("scoreboard")
	game.center_text.text = "Offline · %d bots · %s" % [bots.size(), ["Easy", "Normal", "Hard"][difficulty]]
	if not game.player.alive:
		game.center_text.text = "You got erased · respawn in %d" % maxi(0, ceili(player_respawn))
	elif player_shield > 0:
		game.center_text.text += " · Spawn shield"
	game.scope.visible = game.player.weapon_index == 2 and game.player.aiming
	game.hit_marker = maxf(0, game.hit_marker - delta)
	game.hurt_flash = maxf(0, game.hurt_flash - delta)
	game.hurt_overlay.color.a = game.hurt_flash
	game.crosshair.text = "×" if game.hit_marker > 0 else "+"
	for dot in game.trajectory_nodes:
		dot.visible = game.player.charging
	game._update_effects(delta)

func sorted_scores() -> Array:
	var result = scores.values()
	result.sort_custom(func(a, b): return a.kills > b.kills if a.kills != b.kills else a.deaths < b.deaths)
	return result

func finish() -> void:
	active = false
	game.playing = false
	var text = ""
	for row in sorted_scores():
		text += "%s · %d kills · %d deaths\n" % [row.name, row.kills, row.deaths]
	game._clear_menu("Offline match finished", text)
	game._button("PLAY AGAIN", func(): game.start_game(0))
	game._button("MAIN MENU", game.show_main_menu)
