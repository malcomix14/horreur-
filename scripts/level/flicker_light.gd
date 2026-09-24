class_name FlickerLight
extends OmniLight3D
## Lumière ponctuelle SANS ombre (bon marché) : bougie, ampoule défaillante, feu...
## LightManager n'active que les plus proches du joueur (culling) pour rester rapide.

enum Mode { STEADY, CANDLE, FAULTY, FIRE }

var mode: Mode = Mode.STEADY
var base_energy: float = 1.0
var power_group: String = ""
var switched_on: bool = true
var powered: bool = true
var culled: bool = false
var blackout_until: float = 0.0
var glow_nodes: Array[Node3D] = []
var buzz: AudioStreamPlayer3D = null
var _t: float = 0.0
var _seed: float = 0.0
var _fault_timer: float = 0.0
var _fault_off: float = 0.0


func setup(color: Color, energy: float, light_range: float, p_mode: Mode = Mode.STEADY) -> void:
	light_color = color
	base_energy = energy
	light_energy = energy
	omni_range = light_range
	omni_attenuation = 1.6
	shadow_enabled = false
	light_specular = 0.35
	mode = p_mode
	_seed = randf() * 100.0
	add_to_group("flicker_lights")


static func now() -> float:
	return float(Time.get_ticks_msec()) * 0.001


func is_logically_on() -> bool:
	return switched_on and powered and now() >= blackout_until


func set_switched(on: bool) -> void:
	switched_on = on
	_refresh_glow()


func _refresh_glow() -> void:
	var on := is_logically_on()
	for g: Node3D in glow_nodes:
		if is_instance_valid(g):
			g.visible = on
	if buzz != null:
		if on and not buzz.playing:
			buzz.play()
		elif not on and buzz.playing:
			buzz.stop()


func _process(delta: float) -> void:
	_t += delta
	var on := is_logically_on()
	_refresh_glow()
	visible = on and not culled
	if not visible:
		return
	var n := 0.5 + 0.25 * sin(_t * 13.1 + _seed) + 0.25 * sin(_t * 7.3 + _seed * 2.0)
	match mode:
		Mode.CANDLE:
			light_energy = base_energy * (0.82 + 0.18 * n)
		Mode.FIRE:
			light_energy = base_energy * (0.65 + 0.35 * n * (0.8 + 0.2 * sin(_t * 23.0)))
		Mode.FAULTY:
			_fault_timer -= delta
			if _fault_off > 0.0:
				_fault_off -= delta
				light_energy = base_energy * 0.04
				for g: Node3D in glow_nodes:
					if is_instance_valid(g):
						g.visible = false
			else:
				light_energy = base_energy * (0.9 + 0.1 * n)
				if _fault_timer <= 0.0:
					_fault_timer = randf_range(1.5, 7.0)
					if randf() < 0.6:
						_fault_off = randf_range(0.05, 0.35)
		_:
			light_energy = base_energy
