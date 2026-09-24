class_name MainMenu
extends CanvasLayer
## Menu principal : Nouvelle partie / Continuer / Options / Quitter.

signal new_game_requested
signal continue_requested
signal quit_requested

var root: Control
var buttons: VBoxContainer
var options: OptionsMenu
var continue_btn: Button
var _bg_mat: ShaderMaterial
var _title: Label
var _flash_timer: float = 6.0


func _ready() -> void:
	layer = 40
	root = Control.new()
	root.theme = UITheme.get_theme()
	UITheme.full_rect(root)
	add_child(root)
	var bg := ColorRect.new()
	UITheme.full_rect(bg)
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = load("res://shaders/menu_bg.gdshader") as Shader
	bg.material = _bg_mat
	root.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	vb.position = Vector2(110, -250)
	vb.add_theme_constant_override("separation", 10)
	root.add_child(vb)
	_title = UITheme.label("VESPÉRINE", 86, Color(0.72, 0.1, 0.08))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	vb.add_child(_title)
	vb.add_child(UITheme.label("Celui qui veille", 28, UITheme.TEXT_DIM))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 36)
	vb.add_child(spacer)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	vb.add_child(buttons)
	continue_btn = UITheme.button("Continuer", func() -> void: continue_requested.emit())
	buttons.add_child(continue_btn)
	buttons.add_child(UITheme.button("Nouvelle partie", func() -> void: new_game_requested.emit()))
	buttons.add_child(UITheme.button("Options", _open_options))
	buttons.add_child(UITheme.button("Quitter", func() -> void: quit_requested.emit()))
	var foot := UITheme.label("Casque recommandé.  ZQSD / WASD : se déplacer  •  E : interagir  •  F : lampe  •  Maj : courir  •  Ctrl / C : s'accroupir  •  Tab : journal", 16, UITheme.TEXT_DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(110, -48)
	root.add_child(foot)
	options = OptionsMenu.new()
	options.visible = false
	options.closed.connect(_close_options)
	root.add_child(options)
	visible = false


func open() -> void:
	visible = true
	options.visible = false
	buttons.visible = true
	continue_btn.visible = SaveSystem.has_save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	if continue_btn.visible:
		continue_btn.grab_focus()
	else:
		(buttons.get_child(1) as Button).grab_focus()


func _open_options() -> void:
	options.refresh()
	options.visible = true
	buttons.visible = false


func _close_options() -> void:
	options.visible = false
	buttons.visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_flash_timer -= delta
	var f := 0.0
	if _flash_timer < 0.0:
		f = clampf(1.0 + _flash_timer * 4.0, 0.0, 1.0)
		if _flash_timer < -0.6:
			_flash_timer = randf_range(5.0, 12.0)
	_bg_mat.set_shader_parameter("flash", f)
	_title.modulate.a = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.003) * (1.0 if randf() > 0.02 else -3.0)
