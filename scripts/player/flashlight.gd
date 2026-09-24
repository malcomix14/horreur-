class_name Flashlight
extends Node3D
## Lampe torche : SpotLight3D (seule lumière avec ombres du jeu), batterie limitée,
## vacillements quand la pile faiblit, léger retard de suivi pour un rendu naturel.

const DRAIN_PER_SEC: float = 100.0 / 330.0
const BATTERY_REFILL: float = 100.0

var light: SpotLight3D
var bounce: OmniLight3D
var follow: Node3D
var is_on: bool = false
var charge: float = 75.0
var _forced_flicker: float = 0.0
var _flicker_t: float = 0.0
var _low_warned: bool = false


func _ready() -> void:
	top_level = true
	light = SpotLight3D.new()
	light.spot_range = 21.0
	light.spot_angle = 31.0
	light.spot_angle_attenuation = 1.3
	light.spot_attenuation = 0.85
	light.light_energy = 4.2
	light.light_color = Color(1.0, 0.93, 0.8)
	light.light_specular = 0.45
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.0
	light.shadow_blur = 1.2
	light.distance_fade_enabled = false
	add_child(light)
	bounce = OmniLight3D.new()
	bounce.omni_range = 3.5
	bounce.light_energy = 0.16
	bounce.light_color = Color(1.0, 0.9, 0.78)
	bounce.shadow_enabled = false
	bounce.light_specular = 0.0
	bounce.position = Vector3(0, 0, -0.6)
	add_child(bounce)
	Settings.settings_changed.connect(_apply_settings)
	_apply_settings()
	_update_visibility()


func _apply_settings() -> void:
	light.shadow_enabled = Settings.shadows


func has_lamp() -> bool:
	return GameManager.has_item("flashlight")


func toggle() -> void:
	if not has_lamp():
		return
	if not is_on and charge <= 0.0:
		AudioManager.play_2d("flash_off", -6.0)
		Events.message_requested.emit("La pile est vide. [R] pour la remplacer.", 2.5)
		return
	is_on = not is_on
	AudioManager.play_2d("flash_on" if is_on else "flash_off", -6.0)
	_update_visibility()
	Events.flashlight_changed.emit(is_on, charge)


func set_on(on: bool) -> void:
	if on == is_on:
		return
	if on and (charge <= 0.0 or not has_lamp()):
		return
	is_on = on
	_update_visibility()
	Events.flashlight_changed.emit(is_on, charge)


func use_battery() -> void:
	if not has_lamp():
		return
	if charge > 92.0:
		Events.message_requested.emit("La pile est encore pleine.", 2.0)
		return
	if not GameManager.remove_item("battery"):
		Events.message_requested.emit("Je n'ai pas de pile de rechange.", 2.0)
		return
	charge = BATTERY_REFILL
	_low_warned = false
	AudioManager.play_2d("battery", -4.0)
	Events.message_requested.emit("Pile remplacée.", 2.0)
	Events.flashlight_changed.emit(is_on, charge)


func flicker(duration: float) -> void:
	_forced_flicker = maxf(_forced_flicker, duration)


func _update_visibility() -> void:
	light.visible = is_on
	bounce.visible = is_on


func _process(delta: float) -> void:
	if follow != null:
		var target := follow.global_transform
		var offset := target.basis * Vector3(0.18, -0.16, -0.1)
		global_position = target.origin + offset
		var q := global_basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), clampf(delta * 16.0, 0.0, 1.0))
		global_basis = Basis(q)
	if not is_on:
		return
	charge = maxf(0.0, charge - DRAIN_PER_SEC * delta)
	if charge <= 0.0:
		is_on = false
		_update_visibility()
		AudioManager.play_2d("flash_off", -6.0)
		Events.message_requested.emit("La lampe s'éteint... La pile est morte.", 3.0)
		Events.flashlight_changed.emit(false, 0.0)
		return
	if charge < 15.0 and not _low_warned:
		_low_warned = true
		Events.message_requested.emit("La lampe faiblit. [R] pour changer la pile.", 3.0)
	var energy := 4.2
	var low := clampf(charge / 20.0, 0.35, 1.0)
	energy *= low
	_flicker_t -= delta
	if _forced_flicker > 0.0:
		_forced_flicker -= delta
		energy *= 0.05 if randf() < 0.45 else randf_range(0.3, 1.0)
	elif charge < 12.0 and _flicker_t <= 0.0:
		_flicker_t = randf_range(0.4, 2.5)
		_forced_flicker = randf_range(0.05, 0.3)
	light.light_energy = energy
	bounce.light_energy = 0.16 * low
