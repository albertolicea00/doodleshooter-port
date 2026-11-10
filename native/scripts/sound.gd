class_name DoodleSound
extends Node

var enabled = true
var music_enabled = true
var music_volume = 0.8
var effects_volume = 0.8
var intensity = 0.0
var music: Array[AudioStreamPlayer] = []
var current_map = ""
var cache: Dictionary = {}

func set_map(key: String) -> void:
	if current_map == key:
		return
	current_map = key
	for voice in music:
		voice.stop()
		voice.stream = null
		voice.queue_free()
	music.clear()
	for i in 3:
		var voice = AudioStreamPlayer.new()
		var stream = load("res://assets/audio/music_%s_%d.ogg" % [key, i]) as AudioStreamOggVorbis
		stream.loop = true
		voice.stream = stream
		voice.volume_db = -80
		add_child(voice)
		voice.play()
		music.append(voice)

func stop_all() -> void:
	for voice in get_children():
		voice.stop()
		voice.stream = null
		voice.queue_free()
	music.clear()
	cache.clear()
	current_map = ""

func _exit_tree() -> void:
	stop_all()

func _process(delta: float) -> void:
	var game = get_parent()
	var target = clampf(intensity, 0, 1) * 2.0
	for i in music.size():
		var weight = maxf(0, 1.0 - absf(float(i) - target))
		var volume = linear_to_db(maxf(0.0001, weight * music_volume)) if music_enabled else -80.0
		music[i].volume_db = lerpf(music[i].volume_db, volume, 1.0 - exp(-delta * 4))
		music[i].stream_paused = not game.playing

func play_effect(effect: String, at: Vector3 = Vector3.INF) -> void:
	if not enabled:
		return
	if not cache.has(effect):
		var file = "res://assets/audio/" + effect + ".wav"
		if not ResourceLoader.exists(file):
			return
		cache[effect] = load(file)
	var voice: Node
	if at.is_finite():
		var spatial = AudioStreamPlayer3D.new()
		spatial.stream = cache[effect]
		spatial.unit_size = 11.0
		spatial.max_distance = 140
		spatial.volume_db = linear_to_db(maxf(0.0001, effects_volume))
		add_child(spatial)
		spatial.global_position = at
		voice = spatial
	else:
		var flat = AudioStreamPlayer.new()
		flat.stream = cache[effect]
		flat.volume_db = linear_to_db(maxf(0.0001, effects_volume))
		add_child(flat)
		voice = flat
	voice.finished.connect(voice.queue_free)
	voice.play()

# Retained for existing call sites until their semantic sound events are mapped.
func play_tone(frequency: float, _duration: float, noise: bool = false) -> void:
	play_effect("shot" if noise else ("kill" if frequency > 700 else "wave"))
