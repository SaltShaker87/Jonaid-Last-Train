extends Node
## Fire-and-forget sound effects from assets/audio/<name>.wav.
## Placeholder blips until the Phase 5 sound pass.

const VOLUME := {"ping": -9.0, "chime": -8.0, "buzz": -11.0, "jam": -8.0, "turnstile": -8.0, "announce": -6.0}

var _players := {}


func play(sfx_name: String, pitch: float = 1.0) -> void:
	var p := _players.get(sfx_name) as AudioStreamPlayer
	if p == null:
		var path := "res://assets/audio/%s.wav" % sfx_name
		if not ResourceLoader.exists(path):
			return
		p = AudioStreamPlayer.new()
		p.stream = load(path)
		p.volume_db = float(VOLUME.get(sfx_name, -8.0))
		add_child(p)
		_players[sfx_name] = p
	p.pitch_scale = pitch
	p.play()
