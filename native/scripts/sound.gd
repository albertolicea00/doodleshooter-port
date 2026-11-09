class_name DoodleSound
extends Node

var enabled = true

func play_tone(frequency: float, duration: float, noise: bool = false) -> void:
	if not enabled:
		return
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes = PackedByteArray()
	var count = int(duration * 22050)
	bytes.resize(count * 2)
	for i in count:
		var t = float(i) / 22050
		var value = (randf_range(-1, 1) * 0.65 if noise else (1.0 if sin(t * frequency * TAU) > 0 else -1.0))
		var sample = int(value * pow(1.0 - float(i) / count, 2) * 6000)
		bytes.encode_s16(i * 2, sample)
	stream.data = bytes
	var audio = AudioStreamPlayer.new()
	audio.stream = stream
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
