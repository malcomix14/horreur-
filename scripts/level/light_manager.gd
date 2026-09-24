class_name LightManager
extends Node
## Gère toutes les FlickerLight : n'allume que les N plus proches du joueur,
## coupures de courant (screamers), retour du courant (fusible), éclairs sur les vitres.

var player: Node3D
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
	_timer = 0.25
	var pp := player.global_position
	var radius := Settings.light_cull_radius()
	var max_count := Settings.max_active_lights()
	var cands: Array[FlickerLight] = []
	for l: FlickerLight in _lights():
		l.culled = true
		if l.is_logically_on() and l.global_position.distance_to(pp) < radius + l.omni_range * 0.5:
			cands.append(l)
	cands.sort_custom(func(a: FlickerLight, b: FlickerLight) -> bool:
		return a.global_position.distance_squared_to(pp) < b.global_position.distance_squared_to(pp))
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
