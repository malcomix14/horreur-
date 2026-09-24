class_name InputSetup
## Crée les actions d'entrée au démarrage, avec des codes de touches PHYSIQUES :
## ZQSD (AZERTY) et WASD (QWERTY) correspondent aux mêmes touches physiques,
## donc les deux dispositions fonctionnent sans réglage. Les flèches marchent aussi.


static func ensure_actions() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("sprint", [KEY_SHIFT])
	_add_keys("crouch", [KEY_CTRL])
	_add_keys("crouch_toggle", [KEY_C])
	_add_keys("interact", [KEY_E])
	_add_mouse("interact", MOUSE_BUTTON_LEFT)
	_add_keys("flashlight", [KEY_F])
	_add_mouse("flashlight", MOUSE_BUTTON_RIGHT)
	_add_keys("reload", [KEY_R])
	_add_keys("journal", [KEY_TAB, KEY_J, KEY_I])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	_add_keys("toggle_fps", [KEY_F3])


static func _add_keys(action: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


static func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
