class_name PostProcess
extends CanvasLayer
## Post-traitement plein écran en shader canvas (compatible renderer Compatibility) :
## Basse = voile sans lecture d'écran ; Moyenne = + grain/étalonnage ; Haute = + aberration.

var rect: ColorRect
var fear: float = 0.0
var red: float = 0.0
var _mat_full: ShaderMaterial
var _mat_overlay: ShaderMaterial


func _ready() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.full_rect(rect)
	add_child(rect)
	_mat_full = ShaderMaterial.new()
	_mat_full.shader = load("res://shaders/post_full.gdshader") as Shader
	_mat_overlay = ShaderMaterial.new()
	_mat_overlay.shader = load("res://shaders/post_overlay.gdshader") as Shader
	Settings.settings_changed.connect(_apply)
	Events.player_caught.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(self, "red", 0.55, 0.3)
		tw.tween_property(self, "red", 0.35, 1.2))
	_apply()


func _apply() -> void:
	match Settings.quality:
		Settings.Quality.LOW:
			rect.material = _mat_overlay
			_mat_overlay.set_shader_parameter("grain_amount", 0.02)
		Settings.Quality.HIGH:
			rect.material = _mat_full
			_mat_full.set_shader_parameter("aberration", 0.0018)
			_mat_full.set_shader_parameter("grain_amount", 0.045)
		_:
			rect.material = _mat_full
			_mat_full.set_shader_parameter("aberration", 0.0)
			_mat_full.set_shader_parameter("grain_amount", 0.035)


func reset() -> void:
	fear = 0.0
	red = 0.0


func _process(_delta: float) -> void:
	var m := rect.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("fear", fear)
	m.set_shader_parameter("red_flash", red)
