class_name LightManager
extends Node
## Gère toutes les FlickerLight : n'allume que les N plus pertinentes autour du joueur
## (celles de la pièce où il se trouve d'abord, puis les plus proches), coupures de courant
## (screamers), retour du courant (fusible), éclairs sur les vitres.

const SAME_ROOM_BONUS: float = 0.55

var player: Node3D
var layout: ManorLayout
var _timer: float = 0.0


func _ready() -> void:
	Events.power_restored.connect(_on_power)
	Events.lightning_flash.connect(_on_lightning)


func init_power_state() -> void:
	var on := GameManager.get_flag("power_on")
	for l: FlickerLight in _lights():
		if l.power_group != "":
			l.powered = on


func _lights() -> Array[FlickerLight]:
	var out: Array[FlickerLight] = []
	for n: Node in get_tree().get_nodes_in_group("flicker_lights"):
		if n is FlickerLight:
			out.append(n as FlickerLight)
	return out


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or player == null:
		return
	_timer = 0.2
	_select()


## Recalcule tout de suite les lumières actives, sans fondu (après une téléportation).
func refresh_now() -> void:
	if player == null:
		return
	_select()
	for l: FlickerLight in _lights():
		l.snap_fade()


func _player_room() -> String:
	if layout == null:
		return ""
	var r := layout.room_at(player.global_position + Vector3(0, 0.5, 0))
	return r.id if r != null else ""


func _select() -> void:
	var pp := player.global_position
	var proom := _player_room()
	var radius := Settings.light_cull_radius()
	var max_count := Settings.max_active_lights()
	var cands: Array[FlickerLight] = []
	var scores: Dictionary = {}
	for l: FlickerLight in _lights():
		l.culled = true
		if not l.is_logically_on():
			continue
		if l.room_id == "" and layout != null:
			var lr := layout.room_at(l.global_position)
			l.room_id = lr.id if lr != null else "-"
		var d := l.global_position.distance_to(pp)
		if d > radius + l.omni_range * 0.5:
			continue
		var s := d * l.priority
		if proom != "" and l.room_id == proom:
			s *= SAME_ROOM_BONUS
		scores[l] = s
		cands.append(l)
	cands.sort_custom(func(a: FlickerLight, b: FlickerLight) -> bool:
		return float(scores[a]) < float(scores[b]))
	for i: int in range(mini(max_count, cands.size())):
		cands[i].culled = false


## Coupe les lumières autour d'un point pendant `duration` secondes.
func blackout(center: Vector3, radius: float, duration: float) -> int:
	var count := 0
	var until := FlickerLight.now() + duration
	for l: FlickerLight in _lights():
		if l.global_position.distance_to(center) < radius and l.is_logically_on():
			l.blackout_until = until
			count += 1
	return count


func _on_power(group: String) -> void:
	for l: FlickerLight in _lights():
		if l.power_group == group:
			l.powered = true
			l.blackout_until = FlickerLight.now() + randf_range(0.1, 0.6)


func _on_lightning(strength: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_glass, 0.0, strength, 0.05)
	tw.tween_method(_set_glass, strength, 0.2, 0.12)
	tw.tween_method(_set_glass, 0.2, strength * 0.8, 0.06)
	tw.tween_method(_set_glass, strength * 0.8, 0.0, 0.5)


func _set_glass(v: float) -> void:
	Assets.std_mat("glass_window").albedo_color = Color(0.55, 0.6, 0.75).lerp(Color(2.2, 2.3, 2.6), v)
	Assets.std_mat("glass_stained").albedo_color = Color(0.5, 0.5, 0.5).lerp(Color(1.6, 1.6, 1.6), v)
