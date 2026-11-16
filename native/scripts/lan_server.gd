class_name DoodleLanServer
extends Node

# One device hosts one room. Clients use the same protocol as online lobbies.
const PORT = 8912
const DAMAGE = {"rifle": [19.0, 1.8], "shotgun": [160.0, 1.6], "sniper": [150.0, 1.5], "katana": [55.0, 1.0], "revolver": [48.0, 1.6], "smg": [12.0, 1.6], "deflect": [90.0, 1.0]}
const INTERVAL = {"rifle": 1.0 / 11, "shotgun": 0.78, "sniper": 0.85, "katana": 0.33, "revolver": 0.3, "smg": 1.0 / 15, "deflect": 0.19}
var listener = TCPServer.new()
var peers: Dictionary = {}
var members: Dictionary = {}
var host = ""
const MAPS = ["district", "mexico", "castle", "harbor", "pyramid", "station"]
var map_key = "district"
var started = false
var ended = false
var remaining = 600.0
var status_time = 0.0
var broken: Array = []
var serial = 0

func start(port: int = PORT, bind_address: String = "0.0.0.0") -> Error:
	return listener.listen(port, bind_address)

func stop() -> void:
	listener.stop()
	for peer in peers.values():
		peer.socket.close(1001, "The LAN host closed the room.")
	peers.clear()
	members.clear()

func _exit_tree() -> void:
	stop()

func send_to(id: String, packet: Dictionary) -> void:
	if peers.has(id) and peers[id].socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peers[id].socket.send_text(JSON.stringify(packet))

func broadcast(packet: Dictionary, exclude: String = "") -> void:
	for id in members:
		if id != exclude:
			send_to(id, packet)

func roster() -> Array:
	var result: Array = []
	for id in members:
		var p: Dictionary = members[id]
		result.append({"id": id, "name": p.name, "hp": p.hp, "kills": p.kills, "deaths": p.deaths})
	return result

func lobby_info() -> void:
	broadcast({"type": "lobby", "code": "LAN", "host": host, "public": false, "map": map_key, "started": started, "players": roster()})

func _process(delta: float) -> void:
	while listener.is_connection_available():
		var stream = listener.take_connection()
		if peers.size() >= 16:
			stream.disconnect_from_host()
			continue
		var socket = WebSocketPeer.new()
		socket.inbound_buffer_size = 16384
		if socket.accept_stream(stream) != OK:
			stream.disconnect_from_host()
			continue
		serial += 1
		peers[str(serial)] = {"socket": socket, "welcomed": false, "name": "Doodler", "age": 0.0}
	for id in peers.keys():
		if not peers.has(id):
			continue
		var peer: Dictionary = peers[id]
		peer.age += delta
		peer.socket.poll()
		var state = peer.socket.get_ready_state()
		if state == WebSocketPeer.STATE_CLOSED or (not peer.welcomed and peer.age > 12):
			leave(id)
			peers.erase(id)
			continue
		if state != WebSocketPeer.STATE_OPEN:
			continue
		if not peer.welcomed:
			peer.welcomed = true
			send_to(id, {"type": "welcome", "id": id})
		var count = 0
		while peers.has(id) and peer.socket.get_available_packet_count() > 0 and count < 64:
			count += 1
			var packet = JSON.parse_string(peer.socket.get_packet().get_string_from_utf8())
			if packet is Dictionary:
				handle(id, packet)
	if not started or ended:
		return
	if members.size() >= 2:
		remaining = maxf(0, remaining - delta)
	var now = Time.get_ticks_msec() / 1000.0
	for id in members.keys():
		if not members.has(id):
			continue
		var member: Dictionary = members[id]
		if now - member.activity > 150:
			send_to(id, {"type": "idle", "message": "Removed after 150 seconds without input.", "code": "LAN"})
			leave(id)
			continue
		if member.hp > 0 and member.hp < 120 and now - member.hurt > 4.5 and not member.state.get("sprinting", false):
			member.hp = minf(120, member.hp + 11 * delta)
	status_time -= delta
	if remaining <= 0:
		finish()
	elif status_time <= 0:
		status_time = 1
		broadcast({"type": "clock", "remaining": ceili(remaining), "players": roster()})

func leave(id: String) -> void:
	if not members.has(id):
		return
	members.erase(id)
	if id == host:
		stop()
		return
	broadcast({"type": "left", "id": id})
	lobby_info()

func vector_valid(value: Variant, limit: float = 1000) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for coordinate in value:
		if not (coordinate is float or coordinate is int) or not is_finite(coordinate) or absf(coordinate) >= limit:
			return false
	return true

func handle(id: String, packet: Dictionary) -> void:
	if not peers.has(id):
		return
	var type = packet.get("type", "")
	var now = Time.get_ticks_msec() / 1000.0
	if type == "name":
		peers[id].name = str(packet.get("name", "Doodler")).strip_escapes().strip_edges().left(24)
		if peers[id].name.is_empty():
			peers[id].name = "Doodler"
		return
	if type in ["host", "join"]:
		if ended or members.size() >= 10 or members.has(id) or (type == "host" and not host.is_empty()) or (type == "join" and host.is_empty()):
			send_to(id, {"type": "error", "message": "This LAN room is full, unavailable, or finished."})
			return
		if type == "host":
			host = id
			map_key = packet.map if packet.get("map") in MAPS else "district"
		members[id] = {"name": peers[id].name, "hp": 120.0, "kills": 0, "deaths": 0, "shield": now + 2, "died": 0.0, "hurt": now, "activity": now, "state": {}, "fire": {}}
		lobby_info()
		if started:
			send_to(id, {"type": "start", "map": map_key, "spawn": members.size() - 1, "late": true, "broken": broken})
		return
	if not members.has(id):
		return
	var p: Dictionary = members[id]
	if type == "leave":
		leave(id)
		send_to(id, {"type": "left_room"})
		return
	if type == "map" and id == host and not started:
		map_key = packet.map if packet.get("map") in MAPS else "district"
		lobby_info()
		return
	if type == "start" and id == host and not started:
		started = true
		var index = 0
		for member_id in members:
			members[member_id].shield = now + 2
			send_to(member_id, {"type": "start", "map": map_key, "spawn": index, "late": false, "broken": []})
			index += 1
		return
	if not started or ended:
		return
	match type:
		"activity":
			p.activity = now
		"state":
			var state = packet.get("state")
			if not state is Dictionary:
				return
			for key in ["position", "rotation", "velocity", "grapple"]:
				if not vector_valid(state.get(key)):
					return
			for key in ["grappling", "aiming", "sprinting"]:
				if not state.get(key, false) is bool:
					return
			if not weapon_valid(state.get("weapon")):
				return
			p.state = state.duplicate()
			p.state.merge({"id": id, "hp": p.hp, "alive": p.hp > 0}, true)
			broadcast({"type": "state", "state": p.state}, id)
		"damage":
			var victim = str(packet.get("target", ""))
			var source = str(packet.get("source", ""))
			var amount = packet.get("amount")
			if p.hp <= 0 or victim == id or not DAMAGE.has(source) or not (amount is float or amount is int) or not is_finite(amount):
				return
			if now - p.fire.get(source, -100.0) < INTERVAL[source] * 0.85:
				return
			p.fire[source] = now
			hurt(victim, clampf(amount, 0, DAMAGE[source][0] * DAMAGE[source][1]), id, source)
		"respawn":
			if p.hp <= 0 and now - p.died >= 2.5:
				p.hp = 120.0
				p.shield = now + 2
				send_to(id, {"type": "respawn", "shield": 2, "spawn": randi_range(0, 15)})
		"shot":
			if p.hp > 0 and weapon_valid(packet.get("weapon")) and vector_valid(packet.get("end")):
				broadcast({"type": "shot", "id": id, "weapon": packet.weapon, "end": packet.end}, id)
		"grenade":
			if p.hp > 0 and vector_valid(packet.get("position")) and vector_valid(packet.get("velocity"), 100):
				broadcast({"type": "grenade", "id": id, "position": packet.position, "velocity": packet.velocity}, id)
		"blast":
			if p.hp <= 0 or not vector_valid(packet.get("position")) or not p.state.has("position") or now - p.fire.get("grenade", -100.0) < 0.595:
				return
			var at = ReferenceAssets.vector(packet.position)
			if at.distance_to(ReferenceAssets.vector(p.state.position)) > 75:
				return
			p.fire.grenade = now
			for victim in members.keys():
				if members[victim].state.has("position"):
					var distance = at.distance_to(ReferenceAssets.vector(members[victim].state.position))
					if distance < 6.4:
						hurt(victim, 62 * (1 - distance / 6.4), id, "grenade")
				if ended:
					break
		"broken":
			var prop = packet.get("id")
			if (prop is float or prop is int) and prop == int(prop) and prop >= 0 and prop < 128 and not broken.has(int(prop)):
				broken.append(int(prop))
				broadcast({"type": "broken", "id": int(prop)}, id)

func weapon_valid(value: Variant) -> bool:
	return (value is float or value is int) and value >= 0 and value <= 5 and value == int(value)

func hurt(id: String, amount: float, attacker: String, source: String) -> void:
	if not members.has(id) or ended:
		return
	var p: Dictionary = members[id]
	var now = Time.get_ticks_msec() / 1000.0
	if p.hp <= 0 or p.shield > now:
		return
	p.hp = maxf(0, p.hp - amount)
	p.hurt = now
	send_to(id, {"type": "damage", "amount": amount, "hp": p.hp, "by": attacker, "source": source})
	if p.hp <= 0:
		p.died = now
		p.deaths += 1
		if attacker != id:
			members[attacker].kills += 1
		broadcast({"type": "kill", "victim": id, "killer": attacker, "source": source, "players": roster()})
		if members[attacker].kills >= 20:
			finish()

func finish() -> void:
	ended = true
	var scores = roster()
	scores.sort_custom(func(a, b): return a.kills > b.kills if a.kills != b.kills else a.deaths < b.deaths)
	broadcast({"type": "result", "players": scores})
