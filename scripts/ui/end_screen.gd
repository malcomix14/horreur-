class_name EndScreen
extends CanvasLayer
## Écran de mort (« Il vous a attrapé ») et écrans de fin (deux fins).

signal retry_requested
signal restart_requested
signal menu_requested

var root: Control
var title: Label
var text: Label
var stats: Label
var retry_btn: Button
var restart_btn: Button
var bg: ColorRect


func _ready() -> void:
	layer = 35
	root = Control.new()
	root.theme = UITheme.get_theme()
	UITheme.full_rect(root)
	add_child(root)
	bg = ColorRect.new()
	UITheme.full_rect(bg)
	bg.color = Color(0, 0, 0, 1)
	root.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.position = Vector2(-420, -250)
	vb.custom_minimum_size = Vector2(840, 500)
	vb.add_theme_constant_override("separation", 16)
	root.add_child(vb)
	title = UITheme.label("", 58, Color(0.7, 0.08, 0.06), HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(title)
	text = UITheme.label("", 21, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(840, 0)
	vb.add_child(text)
	stats = UITheme.label("", 18, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(stats)
	var bb := VBoxContainer.new()
	bb.alignment = BoxContainer.ALIGNMENT_CENTER
	bb.add_theme_constant_override("separation", 10)
	var center := CenterContainer.new()
	center.add_child(bb)
	vb.add_child(center)
	retry_btn = UITheme.button("Reprendre au dernier point de sauvegarde", func() -> void: retry_requested.emit(), 460)
	restart_btn = UITheme.button("Recommencer depuis le début", func() -> void: restart_requested.emit(), 460)
	bb.add_child(retry_btn)
	bb.add_child(restart_btn)
	bb.add_child(UITheme.button("Menu principal", func() -> void: menu_requested.emit(), 460))
	visible = false


func show_death() -> void:
	title.text = "IL VOUS A ATTRAPÉ"
	title.add_theme_color_override("font_color", Color(0.7, 0.08, 0.06))
	text.text = "Le Veilleur vous ramène dans la maison. Comme les autres.\nIl ne vous tue pas en vous regardant : il doit vous atteindre. Fuyez, fermez les portes, cachez-vous hors de sa vue."
	stats.text = "Temps de jeu : %s" % _fmt_time(GameManager.play_time)
	retry_btn.visible = SaveSystem.has_save()
	retry_btn.text = "Réessayer (dernier point de sauvegarde)"
	restart_btn.visible = true
	_show()


func show_victory(ending: String) -> void:
	if ending == "delivrance":
		title.text = "DÉLIVRANCE"
		title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
		text.text = "Le registre a brûlé. Derrière vous, dans le hall, un grand corps s'affaisse enfin et ferme ses yeux sans paupières. Pour la première fois depuis seize ans, Gaspard dort.\nÀ l'étage, une petite voix fredonne « Au clair de la lune »... puis se tait, apaisée.\nL'aube se lève sur le Morvan. Le manoir Vespérine n'attend plus personne.\n\n— Fin 2 / 2 : la vraie fin —"
	else:
		title.text = "ÉVASION"
		title.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		text.text = "Vous courez dans la boue sans vous retourner. Derrière vous, la grande porte se referme doucement, sans un bruit.\nÀ une fenêtre, deux yeux pâles vous regardent partir. Il veille. Il veillera toujours. La maison attend son prochain invité.\n\n— Fin 1 / 2 — Il existe une autre fin : le registre d'Aurèle cachait peut-être un moyen de libérer le Veilleur..."
	stats.text = "Temps de jeu : %s   •   Captures : %d" % [_fmt_time(GameManager.play_time), GameManager.deaths]
	retry_btn.visible = false
	restart_btn.visible = true
	restart_btn.text = "Rejouer"
	_show()


func _show() -> void:
	visible = true
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 1.2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	restart_btn.text = "Recommencer depuis le début"


static func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%d min %02d s" % [int(float(s) / 60.0), s % 60]
