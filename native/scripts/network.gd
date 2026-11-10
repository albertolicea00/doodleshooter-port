class_name DoodleNetwork
extends Node

signal received(packet: Dictionary)
signal failed(message: String)
var socket = WebSocketPeer.new()
var connected = false
var connecting = false
var peer_id = ""
var code = ""
var in_match = false
var host_id = ""
var roster: Array = []
var pending: Dictionary = {}
var elapsed = 0.0
var activity = 0.0
var timeout = 0.0
var remaining = 600
var endpoint = "ws://127.0.0.1:8911"

func connect_lobby(url: String, request: Dictionary) -> void:
	close()
	endpoint = url.strip_edges()
	pending = request
	var error = socket.connect_to_url(endpoint)
	if error != OK:
		failed.emit("Unable to connect to that server URL.")
		return
	connecting = true
	timeout = 12.0

func close() -> void:
	socket.close()
	socket = WebSocketPeer.new()
	connected = false
	connecting = false
	in_match = false
	code = ""
	peer_id = ""
	roster.clear()
	remaining = 600
	elapsed = 0
	activity = 0

func send_packet(packet: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(packet))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventKey or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.15):
		activity = 1.0

func _process(delta: float) -> void:
	socket.poll()
	if connecting:
		timeout -= delta
		if timeout <= 0:
			close()
			failed.emit("Server connection timed out. Check the URL and server.")
			return
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		if connected or connecting:
			connected = false
			connecting = false
			in_match = false
			failed.emit("Disconnected from the lobby server.")
		return
	while socket.get_available_packet_count() > 0:
		var packet = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if not packet is Dictionary:
			continue
		match packet.get("type", ""):
			"welcome":
				connecting = false
				connected = true
				peer_id = packet.id
				send_packet({"type": "name", "name": get_parent().player_name})
				send_packet(pending)
			"lobby":
				code = packet.code
				host_id = packet.host
				roster = packet.players
			"start":
				in_match = true
			"clock":
				remaining = int(packet.remaining)
				roster = packet.players
			"kill":
				roster = packet.players
			"result":
				in_match = false
			"left_room", "idle":
				code = ""
				in_match = false
		received.emit(packet)
	if not in_match:
		return
	var game = get_parent()
	elapsed += delta
	if elapsed >= 0.05 and is_instance_valid(game.player):
		elapsed = 0
		var p: DoodlePlayer = game.player
		send_packet({"type": "state", "state": {"position": [p.position.x, p.position.y, p.position.z], "rotation": [p.camera.rotation.x, p.rotation.y, 0], "velocity": [p.velocity.x, p.velocity.y, p.velocity.z], "grapple": [p.grapple_anchor.x, p.grapple_anchor.y, p.grapple_anchor.z], "grappling": p.grapple_active, "aiming": p.aiming, "sprinting": Input.is_action_pressed("sprint"), "weapon": p.weapon_index}})
	activity -= delta
	if activity > 0 and connected:
		send_packet({"type": "activity"})
		activity = 0
