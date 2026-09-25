class_name JumpscareManager
extends Node
## Screamers configurables dans data/jumpscares.json.
##  - « random »  : tirage périodique avec probabilité, délai minimal entre deux screamers,
##                  jamais pendant une poursuite, jamais deux fois le même d'affilée.
##  - « trigger » : déclenché par une action (tiroir, miroir, clé, porte, note...).
## Chaque screamer = effet visuel + son + secousse de caméra (+ flash optionnel).

const CONFIG_PATH: String = "res://data/jumpscares.json"

var world: GameWorld
var settings: Dictionary = {}
var scares: Array[Dictionary] = []
var _now: float = 0.0
var _last_time: float = -999.0
var _last_id: String = ""
var _next_check: float = 10.0
var _cooldown_until: Dictionary = {}
var _uses: Dictionary = {}
var _figures: Array[Node3D] = []


func _ready() -> void:
	_load_config()
	Events.scare_trigger.connect(_on_trigger)
	_next_check = _cfg_f(settings, "start_delay", 90.0)


func _load_config() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			data = parsed
	if data.is_empty():
		push_warning("jumpscares.json introuvable ou invalide : screamers par défaut.")
		data = {"settings": {}, "scares": [
			{"id": "murmure", "mode": "random", "effect": "whisper", "sound": "whisper_1", "shake": 0.1},
			{"id": "coup", "mode": "random", "effect": "bang", "sound": "bang", "shake": 0.4},
		]}
	var st: Variant = data.get("settings", {})
	settings = st if st is Dictionary else {}
	var list: Variant = data.get("scares", [])
	if list is Array:
		for e: Variant in (list as Array):
			if e is Dictionary:
				scares.append(e as Dictionary)


static func _cfg_f(d: Dictionary, key: String, def: float) -> float:
	return float(d.get(key, def))


static func _cfg_s(d: Dictionary, key: String, def: String) -> String:
	return str(d.get(key, def))


# ============================================================ planification

func _process(delta: float) -> void:
	_now += delta
	_update_figures()
	if not GameManager.is_playing():
		return
	if _now < _next_check:
		return
	_next_check = _now + _cfg_f(settings, "random_check_interval", 8.0)
	if not _can_scare(false):
		return
	if randf() > _cfg_f(settings, "random_chance", 0.15):
		return
	var pool: Array[Dictionary] = []
	var weights: Array[float] = []
	var zone := world.zone_at(world.player.global_position)
	for s: Dictionary in scares:
		if _cfg_s(s, "mode", "random") != "random":
			continue
		var id := _cfg_s(s, "id", "")
		if id == _last_id or _now < float(_cooldown_until.get(id, 0.0)):
			continue
		if int(_uses.get(id, 0)) >= int(s.get("max_uses", 99)):
			continue
		var zones: Variant = s.get("zones", [])
		if zones is Array and not (zones as Array).is_empty() and not (zones as Array).has(zone):
			continue
		pool.append(s)
		weights.append(_cfg_f(s, "weight", 1.0))
	if pool.is_empty():
		return
	# Tirage pondéré ; si l'effet est impossible ici (pas de porte ouverte...), on essaie le suivant.
	for attempt: int in range(3):
		var total := 0.0
		for w: float in weights:
			total += w
		var r := randf() * total
		var pick := 0
		for i: int in range(weights.size()):
			r -= weights[i]
			if r <= 0.0:
				pick = i
				break
		if _execute(pool[pick], null):
			return
		pool.remove_at(pick)
		weights.remove_at(pick)
		if pool.is_empty():
			return


func _can_scare(is_trigger: bool) -> bool:
	var p := world.player
	if p == null or p.caught:
		return false
	var m := world.monster
	if m != null and m.is_active():
		if m.state == Monster.State.CHASE or m.state == Monster.State.CAPTURE:
			return false
		if not is_trigger and m.global_position.distance_to(p.global_position) < 10.0:
			return false
	if is_trigger:
		return _now - _last_time >= _cfg_f(settings, "trigger_min_gap", 12.0)
	if p.is_hidden:
		return false
	return _now - _last_time >= _cfg_f(settings, "min_gap_seconds", 75.0)


func _on_trigger(trigger_id: String, context: Node) -> void:
	for s: Dictionary in scares:
		if _cfg_s(s, "mode", "") != "trigger" or _cfg_s(s, "trigger", "") != trigger_id:
			continue
		var id := _cfg_s(s, "id", trigger_id)
		if GameManager.scares_used.has(id):
			return
		if not _can_scare(true):
			return
		if _execute(s, context):
			GameManager.scares_used[id] = true
		return


# ============================================================ exécution

func _execute(s: Dictionary, context: Node) -> bool:
	var effect := _cfg_s(s, "effect", "")
	var duration := _cfg_f(s, "duration", 1.5)
	var ok := true
	match effect:
		"silhouette":
			ok = _fx_silhouette(duration)
		"face_flash":
			ok = _fx_face_flash()
		"lights_out":
			ok = _fx_lights_out(duration)
		"bang":
			_fx_positional(_cfg_s(s, "sound", "bang"), 3.0, 4.0)
		"whisper":
			_fx_positional(_cfg_s(s, "sound", "whisper_1"), 0.7, -2.0)
		"door_slam":
			ok = _fx_door_slam()
		"footsteps_above":
			ok = _fx_footsteps_above()
		"crawler":
			ok = _fx_crawler()
		"apparition":
			ok = _fx_apparition(_cfg_s(s, "anchor", ""), duration)
		"blackout_breath":
			_fx_blackout_breath(duration)
		"house_scream":
			_fx_house_scream()
		"context":
			if context != null and context.has_method("play_scare_visual"):
				context.call("play_scare_visual", _cfg_s(s, "visual", ""), duration)
			else:
				ok = false
		"sound_only":
			pass
		_:
			ok = false
	if not ok:
		return false
	var snd := _cfg_s(s, "sound", "")
	if snd != "" and effect not in ["bang", "whisper"]:
		AudioManager.play_2d(snd, _cfg_f(s, "volume", 0.0))
	var shake := _cfg_f(s, "shake", 0.0)
	if shake > 0.0:
		Events.camera_shake.emit(shake)
	var fl: Variant = s.get("flash", null)
	if fl is Array and (fl as Array).size() >= 4:
		var a: Array = fl
		Events.screen_flash.emit(Color(float(a[0]), float(a[1]), float(a[2]), float(a[3])), _cfg_f(s, "flash_time", 0.25))
	var id := _cfg_s(s, "id", "")
	_last_time = _now
	_last_id = id
	_uses[id] = int(_uses.get(id, 0)) + 1
	_cooldown_until[id] = _now + _cfg_f(s, "cooldown", 180.0)
	return true


# ------------------------------------------------------------ effets

func _cam() -> Camera3D:
	return world.player.camera


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.DOORS)
	return world.get_world_3d().direct_space_state.intersect_ray(q)


func _floor_at(p: Vector3) -> Vector3:
	var hit := _ray(p + Vector3(0, 0.5, 0), p + Vector3(0, -3.0, 0))
	if hit.is_empty():
		return p
	return hit["position"] as Vector3


func _spawn_figure(pos: Vector3, pose: MonsterBody.Pose, face_to: Vector3, life: float) -> MonsterBody:
	var mb := MonsterBody.new()
	world.add_child(mb)
	mb.global_position = pos
	var d := face_to - pos
	mb.rotation.y = atan2(-d.x, -d.z)
	mb.pose = pose
	mb.set_meta("expire", _now + life)
	for i: int in range(6):
		mb.animate(0.1)
	_figures.append(mb)
	return mb


func _update_figures() -> void:
	for i: int in range(_figures.size() - 1, -1, -1):
		var f := _figures[i]
		if not is_instance_valid(f):
			_figures.remove_at(i)
			continue
		var expire := float(f.get_meta("expire", 0.0))
		var near := world.player != null and f.global_position.distance_to(world.player.global_position) < 4.5 and f.has_meta("vanish_near")
		if _now >= expire or near:
			if f.has_meta("vanish_near"):
				world.player.flashlight.flicker(0.35)
			f.queue_free()
			_figures.remove_at(i)


func _fx_silhouette(duration: float) -> bool:
	var cam := _cam()
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var origin := cam.global_position
	var hit := _ray(origin, origin + fwd * 16.0)
	var dist := 16.0
	if not hit.is_empty():
		dist = origin.distance_to(hit["position"] as Vector3)
	if dist < 7.0:
		return false
	var p := _floor_at(origin + fwd * minf(dist - 1.2, 12.0))
	var fig := _spawn_figure(p, MonsterBody.Pose.STATIC, origin, duration)
	fig.set_meta("vanish_near", true)
	world.player.flashlight.flicker(0.25)
	return true


func _fx_face_flash() -> bool:
	var p := world.player
	if not p.is_flashlight_on():
		return false
	var holder := Node3D.new()
	world.add_child(holder)
	var cam := _cam()
	holder.global_position = cam.global_position - cam.global_basis.z * 0.55 + Vector3(0, -0.08, 0)
	holder.look_at(cam.global_position, Vector3.UP)
	MonsterBody.build_head(holder)
	holder.scale = Vector3.ONE * 1.3
	holder.set_meta("expire", _now + 0.22)
	_figures.append(holder)
	p.flashlight.flicker(0.5)
	return true


func _fx_lights_out(duration: float) -> bool:
	var p := world.player
	var n := world.lights.blackout(p.global_position, 16.0, duration)
	world.dim_ambient(0.45, duration)
	p.flashlight.flicker(minf(duration * 0.5, 1.8))
	AudioManager.play_2d("static", -8.0)
	var _delay_tw1 := create_tween()
	_delay_tw1.tween_interval(1.2)
	_delay_tw1.tween_callback(func() -> void:
		AudioManager.play_3d("whisper_2", p.global_position - p.global_basis.z * -0.8 + Vector3(0, 1.5, 0), -4.0))
	return n > 0 or p.is_flashlight_on()


func _fx_positional(snd: String, dist: float, vol: float) -> void:
	var p := world.player
	var ang := randf() * TAU
	var pos := p.eye_position() + Vector3(cos(ang), 0.0, sin(ang)) * dist
	if snd.begins_with("whisper"):
		pos = p.eye_position() + p.global_basis.z * dist
	AudioManager.play_3d(snd, pos, vol, 1.0, 20.0, 2.0)


func _fx_door_slam() -> bool:
	var p := world.player
	var best: Door = null
	var best_d := 12.0
	for n: Node in get_tree().get_nodes_in_group("doors"):
		var d := n as Door
		if not d.is_open:
			continue
		var dist := d.global_position.distance_to(p.global_position)
		if dist < best_d and dist > 1.8:
			best_d = dist
			best = d
	if best == null:
		return false
	return best.slam_shut()


func _fx_footsteps_above() -> bool:
	var p := world.player
	if p.global_position.y < -1.0:
		return false
	var room := world.layout.room_at(p.global_position)
	if room == null or room.height > 4.0:
		return false
	var parts := CPUParticles3D.new()
	parts.amount = 40
	parts.lifetime = 1.8
	parts.one_shot = false
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(1.5, 0.05, 1.5)
	parts.gravity = Vector3(0, -1.5, 0)
	parts.initial_velocity_min = 0.0
	parts.initial_velocity_max = 0.1
	parts.scale_amount_min = 0.3
	parts.scale_amount_max = 0.6
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	q.material = Assets.mat("dust")
	parts.mesh = q
	world.add_child(parts)
	parts.global_position = Vector3(p.global_position.x, room.floor_y + room.height - 0.1, p.global_position.z)
	parts.emitting = true
	parts.set_meta("expire", _now + 2.6)
	_figures.append(parts)
	return true


func _fx_crawler() -> bool:
	var cam := _cam()
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var origin := cam.global_position
	var hit := _ray(origin, origin + fwd * 12.0)
	var dist := 12.0
	if not hit.is_empty():
		dist = origin.distance_to(hit["position"] as Vector3)
	if dist < 6.0:
		return false
	var center := origin + fwd * minf(dist - 1.0, 8.0)
	var lh := _ray(center, center - right * 6.0)
	var rh := _ray(center, center + right * 6.0)
	var left_p := center - right * 6.0 if lh.is_empty() else (lh["position"] as Vector3) + right * 0.4
	var right_p := center + right * 6.0 if rh.is_empty() else (rh["position"] as Vector3) - right * 0.4
	if left_p.distance_to(right_p) < 1.4:
		return false
	var start := _floor_at(left_p)
	var finish := _floor_at(right_p)
	var fig := _spawn_figure(start, MonsterBody.Pose.CRAWL, start + right, 1.2)
	fig.speed = 5.0
	var tw := fig.create_tween()
	tw.tween_property(fig, "global_position", finish, 0.55)
	AudioManager.play_3d("whoosh", center + Vector3(0, 0.5, 0), 0.0)
	AudioManager.play_3d("step_monster_1", center, 0.0)
	world.player.flashlight.flicker(0.3)
	return true


func _fx_apparition(anchor: String, duration: float) -> bool:
	if not world.anchors.has(anchor):
		return false
	var pos: Vector3 = world.anchors[anchor]
	_spawn_figure(pos, MonsterBody.Pose.STATIC, world.player.global_position, duration)
	var _delay_tw2 := create_tween()
	_delay_tw2.tween_interval(duration * 0.8)
	_delay_tw2.tween_callback(func() -> void:
		Events.lightning_flash.emit(1.0))
	return true


func _fx_blackout_breath(duration: float) -> void:
	var p := world.player
	world.lights.blackout(p.global_position, 20.0, duration)
	world.dim_ambient(0.35, duration)
	p.flashlight.flicker(duration * 0.8)
	AudioManager.play_3d("breath_monster", p.eye_position() + p.global_basis.z * 0.7, 6.0, 1.0, 10.0, 2.0)
	var _delay_tw3 := create_tween()
	_delay_tw3.tween_interval(duration)
	_delay_tw3.tween_callback(func() -> void:
		AudioManager.play_2d("sting_high", -2.0)
		Events.camera_shake.emit(0.35))


func _fx_house_scream() -> void:
	var p := world.player
	world.lights.blackout(p.global_position, 60.0, 1.4)
	world.dim_ambient(0.5, 1.4)
	p.flashlight.flicker(1.2)
	AudioManager.play_2d("monster_scream", -3.0, 0.75)
