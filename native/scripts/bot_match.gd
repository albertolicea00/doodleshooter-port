class_name DoodleBotMatch
extends Node

const MAX_BOTS = 30
const MIN_MINUTES = 5
const MAX_MINUTES = 30
const KILLS_PER_MINUTE = 2

var game: Node3D
var active = false
var lan_host = false
var sync_elapsed = 0.0
var difficulty = 1
var remaining = 600.0
var kill_limit = 20
var scores: Dictionary = {}
var bots: Array[DoodleArenaBot] = []
var player_respawn = 0.0
var player_shield = 2.0

func begin(count: int, skill: int, minutes: int = 10) -> void:
	stop()
	active = true
	difficulty = clampi(skill, 0, 3)
	var duration = clampi(minutes, MIN_MINUTES, MAX_MINUTES)
	remaining = duration * 60.0
	kill_limit = duration * KILLS_PER_MINUTE
	scores["player"] = {"name": game.player_name, "kills": 0, "deaths": 0}
	player_shield = 2
	for i in clampi(count, 1, MAX_BOTS):
		var bot = DoodleArenaBot.new()
		bot.game = game
		bot.match_controller = self
		bot.peer_id = "bot_" + str(i)
		game.add_child(bot)
		bots.append(bot)
		game.remote_players[bot.peer_id] = bot
		scores[bot.peer_id] = {"name": "Doodler Bot %d" % (i + 1), "bot_number": i + 1, "kills": 0, "deaths": 0}
		respawn_bot(bot, i + 1)
	game.reset_arena_player(0)
	for i in 7:
		game.spawn_pickup("ammo" if i < 5 else "health", game.level.pickup_spots.pick_random())

func begin_lan(count: int, skill: int) -> void:
	stop()
	active = true
	lan_host = true
	difficulty = clampi(skill, 0, 3)
	for i in clampi(count, 0, MAX_BOTS):
		var bot = DoodleArenaBot.new()
		bot.game = game
		bot.match_controller = self
		bot.peer_id = "bot_" + str(i)
		game.add_child(bot)
		bots.append(bot)
		game.remote_players[bot.peer_id] = bot
		respawn_bot(bot, i + 1)

func stop() -> void:
	active = false
	lan_host = false
	sync_elapsed = 0.0
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
	var candidates: Array = game.remote_players.values()
	if is_instance_valid(game.player):
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
	if not active:
		return
	if lan_host:
		var target_id = game.network.peer_id if id == "player" else id
		var attacker_id = game.network.peer_id if attacker == "player" else attacker
		game.network.send_packet({"type": "damage", "target": target_id, "attacker": attacker_id, "amount": amount, "source": "deflect" if amount == 90 else "rifle"})
		return
	if not scores.has(id) or not scores.has(attacker):
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
	if scores[attacker].kills >= kill_limit:
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
	if lan_host:
		sync_elapsed += delta
		if sync_elapsed >= 0.05:
			sync_elapsed = 0.0
			for bot in bots:
				game.network.send_packet({"type": "bot_state", "id": bot.peer_id, "state": {"position": [bot.position.x, bot.position.y, bot.position.z], "rotation": [0.0, bot.model.rotation.y - PI, 0.0], "velocity": [bot.velocity.x, bot.velocity.y, bot.velocity.z], "grapple": [0.0, 0.0, 0.0], "grappling": false, "aiming": false, "sprinting": false, "weapon": 0}})
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
	game.hud.score_text = tr("Kills %d / %d") % [scores.player.kills, kill_limit]
	game.hud.combo_text = ""
	game.hud.boss_name = ""
	game.hud.info = [["%02d:%02d" % [int(remaining) / 60, int(remaining) % 60], true], [tr("%d bots · %s") % [bots.size(), [tr("Easy"), tr("Normal"), tr("Hard"), tr("Insane")][difficulty]], false]]
	var standings = sorted_scores()
	game.scoreboard.text = tr("OFFLINE FREE FOR ALL\n") + "\n".join(standings.map(func(entry): return tr("%s     %d K / %d D") % [_score_name(entry), entry.kills, entry.deaths]))
	game.scoreboard.visible = Input.is_action_pressed("scoreboard") or game.touchpad_scoreboard
	game.center_text.text = ""
	if not game.player.alive:
		game.center_text.text = tr("You got erased · respawn in %d") % maxi(0, ceili(player_respawn))
	elif player_shield > 0:
		game.center_text.text = tr("Spawn shield")
	game.scope.visible = game.player.weapon_index == 2 and game.player.aiming
	game.hit_marker = maxf(0, game.hit_marker - delta)
	game.hurt_flash = maxf(0, game.hurt_flash - delta)
	game.hurt_overlay.color.a = game.hurt_flash * game.flash_scale
	for dot in game.trajectory_nodes:
		dot.visible = game.player.charging
	game._update_effects(delta)

func sorted_scores() -> Array:
	var result = scores.values()
	result.sort_custom(func(a, b): return a.kills > b.kills if a.kills != b.kills else a.deaths < b.deaths)
	return result

func _score_name(entry: Dictionary) -> String:
	return tr("Doodler Bot %d") % entry.bot_number if entry.has("bot_number") else entry.name

func finish() -> void:
	active = false
	game.playing = false
	var text = ""
	for row in sorted_scores():
		text += tr("%s · %d kills · %d deaths\n") % [_score_name(row), row.kills, row.deaths]
	game._clear_menu(tr("Offline match finished"), text)
	game._button("PLAY AGAIN", func(): game.start_game(0))
	game._button("MAIN MENU", game.show_main_menu)
