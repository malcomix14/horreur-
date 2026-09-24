class_name KeypadUI
extends CanvasLayer
## Pavé numérique du coffre-fort (souris ou touches 0-9 du clavier, rangée du haut
## ou pavé numérique : fonctionne aussi en AZERTY sans Maj).

signal closed

var target: Safe = null
var display: Label
var _code: String = ""
var _locked_time: float = 0.0


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	UITheme.full_rect(dim)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = UITheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 470)
	panel.position = Vector2(-180, -235)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Coffre-fort", 28, Color(0.75, 0.2, 0.15), HORIZONTAL_ALIGNMENT_CENTER))
	display = UITheme.label("_ _ _ _", 40, Color(0.9, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	var keys: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]
	for k: String in keys:
		var btn := UITheme.button(k, _on_key.bind(k), 100)
		btn.custom_minimum_size = Vector2(100, 56)
		grid.add_child(btn)
	vb.add_child(UITheme.button("Fermer", close, 316))
	visible = false


func open(safe: Safe) -> void:
	target = safe
	_code = ""
	_refresh()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	target = null
	closed.emit()


func _refresh() -> void:
	var s := ""
	for i: int in range(4):
		s += (_code[i] if i < _code.length() else "_") + " "
	display.text = s.strip_edges()
	display.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))


func _on_key(k: String) -> void:
	if _locked_time > 0.0:
		return
	match k:
		"C":
			_code = ""
			_refresh()
		"OK":
			_submit()
		_:
			if _code.length() < 4:
				_code += k
				AudioManager.play_2d("safe_beep", -8.0)
				_refresh()
				if _code.length() == 4:
					_submit()


func _submit() -> void:
	if target == null:
		return
	if _code.length() < 4:
		return
	if target.try_code(_code):
		display.text = "OUVERT"
		display.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		_locked_time = 0.9
		get_tree().create_timer(0.9, true).timeout.connect(close)
	else:
		display.text = "ERREUR"
		display.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
		_locked_time = 0.7
		_code = ""
		get_tree().create_timer(0.7, true).timeout.connect(_refresh)


func _process(delta: float) -> void:
	_locked_time = maxf(0.0, _locked_time - delta)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var ke := event as InputEventKey
		var pk := ke.physical_keycode
		var digit := -1
		if pk >= KEY_0 and pk <= KEY_9:
			digit = int(pk - KEY_0)
		elif ke.keycode >= KEY_KP_0 and ke.keycode <= KEY_KP_9:
			digit = int(ke.keycode - KEY_KP_0)
		if digit >= 0:
			_on_key(str(digit))
			get_viewport().set_input_as_handled()
		elif pk == KEY_BACKSPACE:
			_code = _code.substr(0, maxi(0, _code.length() - 1))
			_refresh()
			get_viewport().set_input_as_handled()
		elif pk == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
			_submit()
			get_viewport().set_input_as_handled()
