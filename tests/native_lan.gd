extends SceneTree

class Client extends Node:
	var player_name = "LAN tester"
	var player: DoodlePlayer
	var network: DoodleNetwork
	var packets: Array = []

	func _ready() -> void:
		network = DoodleNetwork.new()
		add_child(network)
		network.received.connect(func(packet): packets.append(packet))

	func receive(kind: String) -> Dictionary:
		var until = Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < until:
			for i in packets.size():
				if packets[i].type == kind:
					return packets.pop_at(i)
			await get_tree().create_timer(0.01).timeout
		assert(false, "Timed out waiting for LAN packet: " + kind)
		return {}

func _initialize() -> void:
	run.call_deferred()

func client(url: String, request: Dictionary) -> Client:
	var actor = Client.new()
	root.add_child(actor)
	actor.network.connect_lobby(url, request)
	return actor

func run() -> void:
	var server = DoodleLanServer.new()
	root.add_child(server)
	assert(server.start(0, "127.0.0.1") == OK)
	var url = "ws://127.0.0.1:%d" % server.listener.get_local_port()
	var host = client(url, {"type": "host", "map": "mexico"})
	var lobby = await host.receive("lobby")
	assert(lobby.code == "LAN" and lobby.map == "mexico")
	var guest = client(url, {"type": "join", "code": "LAN"})
	lobby = await guest.receive("lobby")
	assert(lobby.players.size() == 2)
	host.network.send_packet({"type": "map", "map": "jungle"})
	assert((await guest.receive("lobby")).map == "jungle")
	assert(server.map_key == "jungle")
	# Only the hosting player may start the LAN match.
	guest.network.send_packet({"type": "start"})
	await create_timer(0.05).timeout
	assert(not server.started)
	host.network.send_packet({"type": "start"})
	await host.receive("start")
	await guest.receive("start")
	assert(host.network.in_match and guest.network.in_match)
	var late = client(url, {"type": "join", "code": "LAN"})
	assert((await late.receive("start")).late)
	var state = {"position": [0, 2, 0], "rotation": [0, 0, 0], "velocity": [0, 0, 0], "grapple": [0, 5, 0], "grappling": false, "aiming": false, "sprinting": false, "weapon": 0}
	host.network.send_packet({"type": "state", "state": state})
	var relay = await guest.receive("state")
	assert(relay.state.id == host.network.peer_id and relay.state.hp == 120)
	var victim_id = guest.network.peer_id
	var attacker_id = host.network.peer_id
	host.network.send_packet({"type": "damage", "target": victim_id, "source": "sniper", "amount": 999})
	await create_timer(0.05).timeout
	assert(server.members[victim_id].hp == 120, "Spawn shields must reject damage")
	server.members[victim_id].shield = 0
	server.members[attacker_id].fire.clear()
	host.network.send_packet({"type": "damage", "target": victim_id, "source": "sniper", "amount": 999})
	var damage = await guest.receive("damage")
	assert(damage.amount == 225 and damage.hp == 0)
	await host.receive("kill")
	assert(server.members[attacker_id].kills == 1)
	server.members[victim_id].died -= 3
	guest.network.send_packet({"type": "respawn"})
	await guest.receive("respawn")
	assert(server.members[victim_id].hp == 120)
	# A self blast must not score, and a shielded opponent stays healthy.
	server.members[attacker_id].hp = 10
	server.members[attacker_id].shield = 0
	host.network.send_packet({"type": "blast", "position": [0, 2, 0]})
	damage = await host.receive("damage")
	assert(damage.hp == 0)
	await host.receive("kill")
	assert(server.members[attacker_id].kills == 1)
	assert(server.members[victim_id].hp == 120)
	server.members[attacker_id].hp = 120
	server.members[attacker_id].kills = 19
	server.members[attacker_id].fire.clear()
	server.members[victim_id].shield = 0
	host.network.send_packet({"type": "damage", "target": victim_id, "source": "sniper", "amount": 150})
	var result = await host.receive("result")
	assert(result.players[0].kills == 20 and server.ended)
	# A finished room rejects late joiners instead of leaving them stuck.
	var extra = client(url, {"type": "join", "code": "LAN"})
	await extra.receive("error")
	for actor in [host, guest, late, extra]:
		actor.network.close()
		actor.queue_free()
	server.stop()
	server.queue_free()
	await process_frame
	print("LAN PASS: native host/client handshake, guest permissions, late join, state relay, shield, damage cap, kills, respawn, self blast, results")
	quit()
