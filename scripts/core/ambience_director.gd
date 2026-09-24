class_name AmbienceDirector
extends Node
## Ambiance dynamique : couches musicales selon la menace, battements de cœur qui
## s'accélèrent quand le Veilleur approche, orage, craquements de la maison, gouttes à la cave.

var world: GameWorld
var fear: float = 0.0
var _heart_timer: float = 0.0
var _creak_timer: float = 14.0
var _lightning_timer: float = 35.0
var _drip_timer: float = 4.0
var _clock: AudioStreamPlayer3D
var _chime_timer: float = 150.0


func _ready() -> void:
	AudioManager.start_music()
	if world.anchors.has("hall_clock"):
		var holder := Node3D.new()
		world.add_child(holder)
		holder.global_position = world.anchors["hall_clock"] as Vector3
		_clock = AudioManager.make_emitter("clock_tick", holder, -6.0, 2.5, 18.0)


func _process(delta: float) -> void:
	var p := world.player
	var m := world.monster
	if p == null or m == null:
		return
	var dist := 999.0
	var chasing := false
	var alert := false
	if m.is_active():
		dist = m.global_position.distance_to(p.global_position)
		chasing = m.state == Monster.State.CHASE or m.state == Monster.State.CAPTURE
		alert = m.state == Monster.State.INVESTIGATE or m.state == Monster.State.SEARCH
	var tension := 0.0
	if chasing:
		tension = 0.35
	elif alert and dist < 22.0:
		tension = lerpf(0.75, 0.35, clampf((dist - 5.0) / 17.0, 0.0, 1.0))
	elif dist < 15.0:
		tension = lerpf(0.6, 0.15, clampf((dist - 4.0) / 11.0, 0.0, 1.0))
	var in_cellar := p.global_position.y < -1.5
	AudioManager.set_music_targets(0.55, tension, 1.0 if chasing else 0.0, 0.12 if in_cellar else 0.4)
	# Peur (post-process) et battements de cœur.
	var target_fear := 1.0 if chasing else clampf(1.0 - (dist - 2.0) / 13.0, 0.0, 1.0) * 0.75
	fear = move_toward(fear, target_fear, delta * (1.5 if target_fear > fear else 0.4))
	if fear > 0.08:
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			_heart_timer = lerpf(1.15, 0.36, fear)
			AudioManager.play_2d("heartbeat", lerpf(-22.0, 0.0, fear), 1.0 + fear * 0.1)
	# Craquements aléatoires autour du joueur.
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(9.0, 24.0)
		var ang := randf() * TAU
		var pos := p.global_position + Vector3(cos(ang), 0.2, sin(ang)) * randf_range(3.0, 8.0)
		var snd := ["creak_1", "creak_2", "creak_3", "knock"][randi() % 4] as String
		if randf() < 0.15:
			snd = "whisper_2"
		AudioManager.play_3d(snd, pos, randf_range(-14.0, -6.0), randf_range(0.85, 1.1), 20.0, 2.0)
	# Orage.
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(45.0, 110.0)
		var strength := randf_range(0.6, 1.0)
		Events.lightning_flash.emit(strength)
		var _delay_tw6 := create_tween()
		_delay_tw6.tween_interval(randf_range(0.6, 2.4))
		_delay_tw6.tween_callback(func() -> void:
			AudioManager.play_2d("thunder", lerpf(-16.0, -6.0, strength), randf_range(0.85, 1.1), "Ambience"))
	# Gouttes d'eau à la cave.
	if in_cellar:
		_drip_timer -= delta
		if _drip_timer <= 0.0:
			_drip_timer = randf_range(1.5, 5.0)
			var key := "cellar_drip_1" if randf() < 0.5 else "cellar_drip_2"
			if world.anchors.has(key):
				var dp: Vector3 = world.anchors[key]
				AudioManager.play_3d("drip", dp + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), -8.0, randf_range(0.8, 1.3), 18.0, 2.0)
	# Horloge du hall.
	_chime_timer -= delta
	if _chime_timer <= 0.0 and _clock != null:
		_chime_timer = randf_range(160.0, 260.0)
		AudioManager.play_3d("clock_chime", _clock.global_position, -3.0, 1.0, 40.0, 5.0)
