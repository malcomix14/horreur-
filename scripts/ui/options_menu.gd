class_name OptionsMenu
extends PanelContainer
## Menu d'options (graphismes, contrôles, audio). Les réglages s'appliquent immédiatement.

signal closed

var _building: bool = false
var _scale_label: Label
var _widgets: Dictionary = {}


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(760, 620)
	position = Vector2(-380, -310)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	vb.add_child(UITheme.label("Options", 34, Color(0.8, 0.2, 0.15), HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	_building = true
	_section(grid, "Graphismes")
	_scale_label = _row_slider(grid, "render_scale", "Résolution 3D", 0.4, 1.0, 0.05)
	_row_option(grid, "quality", "Qualité", ["Basse (PC faible)", "Moyenne", "Haute"])
	_row_check(grid, "shadows", "Ombres de la lampe")
	_row_check(grid, "fullscreen", "Plein écran")
	_row_check(grid, "vsync", "Synchronisation verticale")
	_row_option(grid, "max_fps", "Images/s max", ["30", "60", "120", "Illimité"])
	_row_slider(grid, "brightness", "Luminosité", 0.5, 2.0, 0.05)
	_row_slider(grid, "fov", "Champ de vision", 60.0, 95.0, 1.0)
	_row_check(grid, "head_bob", "Balancement de la tête")
	_row_check(grid, "show_fps", "Afficher les FPS (F3)")
	_section(grid, "Contrôles")
	_row_slider(grid, "mouse_sensitivity", "Sensibilité souris", 0.03, 0.5, 0.01)
	_row_check(grid, "invert_y", "Inverser l'axe vertical")
	_section(grid, "Audio")
	_row_slider(grid, "vol_master", "Volume général", 0.0, 1.0, 0.05)
	_row_slider(grid, "vol_music", "Musique et ambiance", 0.0, 1.0, 0.05)
	_row_slider(grid, "vol_sfx", "Effets sonores", 0.0, 1.0, 0.05)
	_building = false
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	hb.add_child(UITheme.button("Préréglage PC faible", _preset_low, 260))
	hb.add_child(UITheme.button("Retour", _close, 200))
	refresh()


func _section(grid: GridContainer, text: String) -> void:
	grid.add_child(UITheme.label(text, 24, Color(0.75, 0.2, 0.15)))
	grid.add_child(Control.new())


func _row_label(grid: GridContainer, text: String) -> void:
	var l := UITheme.label(text, 20)
	l.custom_minimum_size = Vector2(300, 0)
	grid.add_child(l)


func _row_slider(grid: GridContainer, key: String, text: String, lo: float, hi: float, step: float) -> Label:
	_row_label(grid, text)
	var hb := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(260, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UITheme.label("", 18, UITheme.TEXT_DIM)
	val.custom_minimum_size = Vector2(70, 0)
	hb.add_child(s)
	hb.add_child(val)
	grid.add_child(hb)
	s.value_changed.connect(func(v: float) -> void:
		val.text = _fmt(key, v)
		if not _building:
			Settings.set(key, v)
			Settings.apply_all())
	_widgets[key] = s
	_widgets[key + "_label"] = val
	return val


func _row_check(grid: GridContainer, key: String, text: String) -> void:
	_row_label(grid, text)
	var c := CheckBox.new()
	c.toggled.connect(func(on: bool) -> void:
		if not _building:
			Settings.set(key, on)
			Settings.apply_all())
	grid.add_child(c)
	_widgets[key] = c


func _row_option(grid: GridContainer, key: String, text: String, items: Array[String]) -> void:
	_row_label(grid, text)
	var o := OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.item_selected.connect(func(idx: int) -> void:
		if _building:
			return
		if key == "max_fps":
			var fps_values: Array[int] = [30, 60, 120, 0]
			Settings.max_fps = fps_values[idx]
		else:
			Settings.set(key, idx)
		Settings.apply_all())
	grid.add_child(o)
	_widgets[key] = o


func _fmt(key: String, v: float) -> String:
	match key:
		"render_scale", "vol_master", "vol_music", "vol_sfx", "brightness":
			return "%d %%" % int(round(v * 100.0))
		"fov":
			return "%d°" % int(v)
	return "%.2f" % v


## Relit les valeurs actuelles de Settings dans les widgets.
func refresh() -> void:
	_building = true
	for key: Variant in _widgets.keys():
		var k := str(key)
		if k.ends_with("_label"):
			continue
		var w: Variant = _widgets[k]
		if w is HSlider:
			var s := w as HSlider
			s.value = float(Settings.get(k))
			(_widgets[k + "_label"] as Label).text = _fmt(k, s.value)
		elif w is CheckBox:
			(w as CheckBox).button_pressed = bool(Settings.get(k))
		elif w is OptionButton:
			var o := w as OptionButton
			if k == "max_fps":
				var map: Dictionary = {30: 0, 60: 1, 120: 2, 0: 3}
				o.selected = int(map.get(Settings.max_fps, 1))
			else:
				o.selected = int(Settings.get(k))
	_building = false


func _preset_low() -> void:
	Settings.render_scale = 0.6
	Settings.quality = Settings.Quality.LOW
	Settings.shadows = false
	Settings.max_fps = 30
	Settings.show_fps = true
	Settings.apply_all()
	refresh()


func _close() -> void:
	Settings.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
