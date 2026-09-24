class_name NoteViewer
extends CanvasLayer
## Lecture d'un document (le jeu est en pause pendant la lecture).

signal closed(note_id: String)

var panel: PanelContainer
var title: Label
var body: RichTextLabel
var current_id: String = ""


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	UITheme.full_rect(dim)
	add_child(dim)
	panel = PanelContainer.new()
	panel.theme = UITheme.get_theme()
	var sb := StyleBoxTexture.new()
	sb.texture = Assets.tex("paper")
	sb.modulate_color = Color(0.95, 0.9, 0.8)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 560)
	panel.position = Vector2(-360, -290)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	title = UITheme.label("", 30, Color(0.25, 0.08, 0.05), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_override("font", Assets.font_hand())
	vb.add_child(title)
	body = RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = false
	body.scroll_active = true
	body.custom_minimum_size = Vector2(620, 420)
	body.add_theme_font_override("normal_font", Assets.font_hand())
	body.add_theme_font_size_override("normal_font_size", 21)
	body.add_theme_color_override("default_color", Color(0.12, 0.09, 0.07))
	vb.add_child(body)
	var hint := UITheme.label("[E] / [Échap] Fermer", 16, Color(0.35, 0.3, 0.25), HORIZONTAL_ALIGNMENT_RIGHT)
	vb.add_child(hint)
	visible = false


func open(note_id: String) -> void:
	current_id = note_id
	title.text = GameManager.note_title(note_id)
	body.text = GameManager.note_text(note_id)
	body.scroll_to_line(0)
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play_2d("paper", -8.0, 1.2)
	closed.emit(current_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		close()
