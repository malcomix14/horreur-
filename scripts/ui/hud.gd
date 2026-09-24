class_name HUD
extends CanvasLayer
## Interface en jeu : réticule, invite [E], messages, objectif, clés, lampe/piles,
## endurance, compteur FPS, voile de cachette, flash de screamer, fondu au noir.

var player: Player
var root: Control
var crosshair: Control
var prompt_label: Label
var message_label: Label
var objective_label: Label
var keys_label: Label
var lamp_label: Label
var fps_label: Label
var subtitle_label: Label
var save_label: Label
var stamina_bar: ProgressBar
var hide_overlay: ColorRect
var flash_rect: ColorRect
var fade_rect: ColorRect

var _prompt_active: bool = false
var _msg_time: float = 0.0
var _obj_time: float = 0.0
var _sub_time: float = 0.0
var _save_time: float = 0.0
var _flash_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	UITheme.full_rect(root)
	add_child(root)
	hide_overlay = ColorRect.new()
	UITheme.full_rect(hide_overlay)
	hide_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hm := ShaderMaterial.new()
	hm.shader = load("res://shaders/hiding_overlay.gdshader") as Shader
	hide_overlay.material = hm
	hide_overlay.visible = false
	root.add_child(hide_overlay)
	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.custom_minimum_size = Vector2(20, 20)
	crosshair.position = Vector2(-10, -10)
	crosshair.draw.connect(_draw_crosshair)
	root.add_child(crosshair)
	prompt_label = _anchored_label(24, Control.PRESET_CENTER, Vector2(-400, 40), Vector2(800, 40), HORIZONTAL_ALIGNMENT_CENTER)
	message_label = _anchored_label(22, Control.PRESET_CENTER_BOTTOM, Vector2(-500, -150), Vector2(1000, 60), HORIZONTAL_ALIGNMENT_CENTER)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label = _anchored_label(19, Control.PRESET_TOP_LEFT, Vector2(28, 22), Vector2(700, 60), HORIZONTAL_ALIGNMENT_LEFT)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.6))
	keys_label = _anchored_label(20, Control.PRESET_TOP_RIGHT, Vector2(-260, 22), Vector2(230, 30), HORIZONTAL_ALIGNMENT_RIGHT)
	fps_label = _anchored_label(16, Control.PRESET_TOP_RIGHT, Vector2(-160, 52), Vector2(130, 24), HORIZONTAL_ALIGNMENT_RIGHT)
	fps_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	lamp_label = _anchored_label(18, Control.PRESET_BOTTOM_LEFT, Vector2(28, -52), Vector2(420, 30), HORIZONTAL_ALIGNMENT_LEFT)
	subtitle_label = _anchored_label(30, Control.PRESET_CENTER, Vector2(-600, -140), Vector2(1200, 50), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
	save_label = _anchored_label(17, Control.PRESET_BOTTOM_RIGHT, Vector2(-330, -50), Vector2(300, 26), HORIZONTAL_ALIGNMENT_RIGHT)
	save_label.text = "Progression sauvegardée"
	save_label.modulate.a = 0.0
	stamina_bar = ProgressBar.new()
	stamina_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_bar.position = Vector2(-120, -40)
	stamina_bar.custom_minimum_size = Vector2(240, 6)
	stamina_bar.size = Vector2(240, 6)
	stamina_bar.show_percentage = false
	stamina_bar.max_value = 1.0
	stamina_bar.step = 0.001
	stamina_bar.value = 1.0
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stamina_bar)
	flash_rect = ColorRect.new()
	UITheme.full_rect(flash_rect)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	root.add_child(flash_rect)
	fade_rect = ColorRect.new()
	UITheme.full_rect(fade_rect)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0, 0, 0, 0)
	root.add_child(fade_rect)
	Events.interact_prompt_changed.connect(_on_prompt)
	Events.message_requested.connect(show_message)
	Events.objective_changed.connect(_on_objective)
	Events.hide_state_changed.connect(_on_hide)
	Events.screen_flash.connect(flash)
	Events.screen_fade.connect(fade)
	Events.subtitle_requested.connect(_on_subtitle)
	Events.checkpoint_saved.connect(func() -> void: _save_time = 2.5)
	Events.stamina_changed.connect(func(v: float) -> void: stamina_bar.value = v)
	visible = false


func _anchored_label(size: int, preset: Control.LayoutPreset, pos: Vector2, sz: Vector2, align: HorizontalAlignment) -> Label:
	var l := UITheme.label("", size, UITheme.TEXT, align)
	l.set_anchors_preset(preset)
	l.position = pos
	l.size = sz
	l.custom_minimum_size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(l)
	return l


func reset() -> void:
	prompt_label.text = ""
	message_label.text = ""
	subtitle_label.text = ""
	_msg_time = 0.0
	_sub_time = 0.0
	hide_overlay.visible = false
	flash_rect.color.a = 0.0
	fade_rect.color = Color(0, 0, 0, 0)
	_on_objective(GameManager.objective)


func _draw_crosshair() -> void:
	var c := crosshair.size * 0.5
	if _prompt_active:
		crosshair.draw_arc(c, 7.0, 0.0, TAU, 24, Color(0.9, 0.85, 0.75, 0.85), 1.5)
		crosshair.draw_circle(c, 1.6, Color(0.95, 0.9, 0.8, 0.9))
	else:
		crosshair.draw_circle(c, 1.8, Color(0.85, 0.8, 0.72, 0.55))


func _on_prompt(text: String) -> void:
	_prompt_active = text != ""
	prompt_label.text = ("[E]  " + text) if text != "" else ""
	crosshair.queue_redraw()


func show_message(text: String, duration: float) -> void:
	message_label.text = text
	_msg_time = duration


func _on_objective(text: String) -> void:
	objective_label.text = ("Objectif : " + text) if text != "" else ""
	_obj_time = 9.0


func _on_subtitle(text: String, duration: float) -> void:
	subtitle_label.text = text
	_sub_time = duration


func _on_hide(is_hidden: bool, kind: String) -> void:
	hide_overlay.visible = is_hidden
	var sm := hide_overlay.material as ShaderMaterial
	sm.set_shader_parameter("mode", 1.0 if kind == "bed" else 0.0)
	crosshair.visible = not is_hidden


func flash(color: Color, duration: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	flash_rect.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, maxf(duration, 0.05))


func fade(to_alpha: float, duration: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if duration <= 0.0:
		fade_rect.color.a = to_alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", to_alpha, duration)


func _process(delta: float) -> void:
	if not visible:
		return
	_msg_time -= delta
	message_label.modulate.a = clampf(_msg_time / 0.6, 0.0, 1.0)
	_obj_time -= delta
	objective_label.modulate.a = clampf(_obj_time / 1.5, 0.0, 1.0) * 0.9 + 0.1 * (1.0 if objective_label.text != "" else 0.0)
	_sub_time -= delta
	subtitle_label.modulate.a = clampf(_sub_time / 1.0, 0.0, 1.0)
	_save_time -= delta
	save_label.modulate.a = clampf(_save_time, 0.0, 1.0)
	stamina_bar.modulate.a = move_toward(stamina_bar.modulate.a, 1.0 if stamina_bar.value < 0.98 else 0.0, delta * 2.0)
	fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	var keys := GameManager.key_count()
	keys_label.text = "Clés : %d / 4" % keys if (keys > 0 or GameManager.get_flag("tried_main_door")) else ""
	if player != null and GameManager.has_item("flashlight"):
		var bats := GameManager.inventory.count("battery")
		var pct := int(round(player.flashlight.charge))
		var state := "allumée" if player.flashlight.is_on else "éteinte"
		lamp_label.text = "Lampe %s  %d%%   Piles : %d%s" % [state, pct, bats, "  [R]" if bats > 0 and pct < 60 else ""]
		lamp_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3) if pct < 15 else UITheme.TEXT_DIM)
	else:
		lamp_label.text = ""
