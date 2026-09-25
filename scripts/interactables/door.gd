class_name Door
extends Interactable
## Porte battante (simple ou double). S'ouvre toujours à l'opposé de celui qui la pousse.
## Le monstre les ouvre violemment (bruit fort : prévient le joueur).
## Repère local : X le long du mur, Z = normale, origine au sol au centre de l'ouverture.

const OPEN_ANGLE: float = 1.745

static var _mesh_cache: Dictionary = {}

var width: float = 1.2
var height: float = 2.4
var is_double: bool = false
var is_open: bool = false
var locked: bool = false
var locked_message: String = "La porte est verrouillée."
var first_open_trigger: String = ""
var busy_until: float = 0.0

var _pivots: Array[Node3D] = []
var _signs: Array[float] = []
var _tween: Tween
var _time: float = 0.0


func setup(w: float, h: float, double_leaf: bool, wood: String = "wood_dark") -> void:
	width = w
	height = h
	is_double = double_leaf
	prompt = "Ouvrir"
	add_to_group("doors")
	var leaf_count := 2 if is_double else 1
	var lw := (width / float(leaf_count)) - 0.02
	for i: int in range(leaf_count):
		var pivot := Node3D.new()
		var left := i == 0
		pivot.position = Vector3(-width * 0.5 + 0.01 if left else width * 0.5 - 0.01, 0.0, 0.0)
		add_child(pivot)
		var body := AnimatableBody3D.new()
		# Sans synchronisation physique : le battant suit son pivot (et la position de la porte
		# fixée après l'ajout à la scène) ; sinon il reste figé à l'origine du monde.
		body.sync_to_physics = false
		body.collision_layer = Layers.DOORS
		body.collision_mask = 0
		var cx := lw * 0.5 if left else -lw * 0.5
		body.position = Vector3(cx, height * 0.5, 0.0)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(lw, height - 0.02, 0.07)
		cs.shape = sh
		body.add_child(cs)
		pivot.add_child(body)
		var mi := MeshInstance3D.new()
		mi.mesh = _leaf_mesh(lw, height - 0.02, left, wood)
		mi.visibility_range_end = 32.0
		body.add_child(mi)
		_pivots.append(pivot)
		_signs.append(1.0 if left else -1.0)


static func _leaf_mesh(lw: float, h: float, left: bool, wood: String) -> ArrayMesh:
	var key := "%s_%.2f_%.2f_%s" % [wood, lw, h, str(left)]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var b := MeshBatcher.new()
	var uv := Assets.uv_scale(wood)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(lw, h, 0.05), Color(0.9, 0.9, 0.9), uv)
	# Panneaux en relief (2 x 2) sur les deux faces.
	var pw := (lw - 0.32) * 0.5
	var ph := (h - 0.5) * 0.5
	for side: int in range(2):
		var z := 0.028 if side == 0 else -0.028
		for cx: int in range(2):
			for cy: int in range(2):
				var px := (-1.0 if cx == 0 else 1.0) * (pw * 0.5 + 0.05)
				var py := (-1.0 if cy == 0 else 1.0) * (ph * 0.5 + 0.06) + 0.04
				b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(px, py, z)), Vector3(pw, ph, 0.012), Color(0.72, 0.72, 0.72), uv)
	# Poignées et serrure du côté libre.
	var free_x := (lw * 0.5 - 0.09) * (1.0 if left else -1.0)
	for side2: int in range(2):
		var zs := 0.05 if side2 == 0 else -0.05
		b.add_sphere("brass", Vector3(free_x, -h * 0.5 + 1.0, zs), Vector3(0.035, 0.035, 0.035), Color.WHITE, 8, 5)
		b.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(free_x, -h * 0.5 + 0.93, zs * 0.62)), Vector3(0.05, 0.16, 0.008), Color.WHITE, 2.0)
	var mesh := b.build(func(k: String) -> Material: return Assets.mat(k))
	_mesh_cache[key] = mesh
	return mesh


func _process(delta: float) -> void:
	_time += delta


func get_prompt(_player: Player) -> String:
	if locked:
		return "Ouvrir (verrouillée)"
	return "Fermer" if is_open else "Ouvrir"


func interact(player: Player) -> void:
	if locked:
		AudioManager.play_3d("door_locked", global_position + Vector3(0, 1, 0), -2.0)
		say(locked_message)
		return
	if _time < busy_until:
		return
	if is_open:
		var slam := player.sprinting
		close_door(0.35 if slam else 0.6, slam)
		noise(11.0 if slam else 3.5, "door")
	else:
		open_from(player.global_position, 0.75)
		noise(3.0, "door")
		if first_open_trigger != "":
			var trig := first_open_trigger
			first_open_trigger = ""
			Events.scare_trigger.emit(trig, self)


func is_closed() -> bool:
	return not is_open


func open_from(from_pos: Vector3, duration: float, sound: String = "door_open") -> void:
	if is_open:
		return
	is_open = true
	var local := to_local(from_pos)
	var dir := 1.0 if local.z > 0.0 else -1.0
	_animate(OPEN_ANGLE * dir, duration)
	busy_until = _time + duration * 0.6
	if sound != "":
		AudioManager.play_3d(sound, global_position + Vector3(0, 1.2, 0), -1.0, randf_range(0.92, 1.08), 26.0, 3.5)


func close_door(duration: float, slam: bool = false) -> void:
	if not is_open:
		return
	is_open = false
	_animate(0.0, duration)
	busy_until = _time + duration * 0.6
	var snd := "door_slam" if slam else "door_close"
	var _delay_tw10 := create_tween()
	_delay_tw10.tween_interval(duration * 0.9)
	_delay_tw10.tween_callback(func() -> void:
		AudioManager.play_3d(snd, global_position + Vector3(0, 1.2, 0), 0.0 if slam else -3.0, randf_range(0.95, 1.05), 32.0, 4.0))


## Le monstre enfonce la porte : ouverture brutale + fracas. Renvoie la durée de l'action.
func monster_open(from_pos: Vector3) -> float:
	if is_open:
		return 0.0
	open_from(from_pos, 0.28, "")
	AudioManager.play_3d("door_bash", global_position + Vector3(0, 1.2, 0), 2.0, randf_range(0.9, 1.05), 40.0, 5.0)
	Events.camera_shake.emit(0.12)
	return 0.55


## Utilisé par les screamers : la porte claque toute seule.
func slam_shut() -> bool:
	if not is_open:
		return false
	close_door(0.22, true)
	return true


func _animate(target: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for i: int in range(_pivots.size()):
		_tween.tween_property(_pivots[i], "rotation:y", target * _signs[i], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func clear_cache() -> void:
	_mesh_cache.clear()
