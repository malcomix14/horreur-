class_name PauseMenu
extends CanvasLayer
## Menu pause (Échap).

signal resume_requested
signal menu_requested
signal quit_requested

var root: Control
var buttons: VBoxContainer
var options: OptionsMenu


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.theme = UITheme.get_theme()
	UITheme.full_rect(root)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	UITheme.full_rect(dim)
	root.add_child(dim)
	buttons = VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_CENTER)
	buttons.position = Vector2(-160, -150)
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	buttons.add_child(UITheme.label("Pause", 44, Color(0.75, 0.15, 0.1), HORIZONTAL_ALIGNMENT_CENTER))
	buttons.add_child(UITheme.button("Reprendre", func() -> void: resume_requested.emit()))
	buttons.add_child(UITheme.button("Options", _open_options))
	buttons.add_child(UITheme.button("Menu principal", func() -> void: menu_requested.emit()))
	buttons.add_child(UITheme.button("Quitter le jeu", func() -> void: quit_requested.emit()))
	options = OptionsMenu.new()
	options.visible = false
	options.closed.connect(func() -> void:
		options.visible = false
		buttons.visible = true)
	root.add_child(options)
	visible = false


func open() -> void:
	visible = true
	options.visible = false
	buttons.visible = true
	(buttons.get_child(1) as Button).grab_focus()


func close() -> void:
	visible = false


func is_in_options() -> bool:
	return options.visible


func _open_options() -> void:
	options.refresh()
	options.visible = true
	buttons.visible = false
