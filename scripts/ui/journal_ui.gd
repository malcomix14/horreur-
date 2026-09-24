class_name JournalUI
extends CanvasLayer
## Journal (Tab) : objectif, inventaire, documents lus (relisibles).

signal closed
signal note_open_requested(note_id: String)

var objective: Label
var items: ItemList
var item_desc: Label
var notes: ItemList
var _note_ids: Array[String] = []
var _item_ids: Array[String] = []


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	UITheme.full_rect(dim)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme = UITheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(980, 600)
	panel.position = Vector2(-490, -300)
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	vb.add_child(UITheme.label("Journal", 34, Color(0.75, 0.2, 0.15)))
	objective = UITheme.label("", 20, Color(0.85, 0.78, 0.6))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size = Vector2(920, 0)
	vb.add_child(objective)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	vb.add_child(hb)
	var left := VBoxContainer.new()
	hb.add_child(left)
	left.add_child(UITheme.label("Inventaire", 24, Color(0.75, 0.2, 0.15)))
	items = ItemList.new()
	items.custom_minimum_size = Vector2(440, 300)
	items.item_selected.connect(_on_item_selected)
	left.add_child(items)
	item_desc = UITheme.label("", 18, UITheme.TEXT_DIM)
	item_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_desc.custom_minimum_size = Vector2(440, 60)
	left.add_child(item_desc)
	var right := VBoxContainer.new()
	hb.add_child(right)
	right.add_child(UITheme.label("Documents (double-clic pour relire)", 24, Color(0.75, 0.2, 0.15)))
	notes = ItemList.new()
	notes.custom_minimum_size = Vector2(440, 360)
	notes.item_activated.connect(_on_note_activated)
	right.add_child(notes)
	vb.add_child(UITheme.label("[Tab] / [Échap] Fermer", 16, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	visible = false


func open() -> void:
	objective.text = "Objectif : " + GameManager.objective
	items.clear()
	_item_ids.clear()
	for id: String in GameManager.inventory.ids():
		var n := GameManager.inventory.count(id)
		var label := GameManager.item_name(id)
		if n > 1:
			label += "  x%d" % n
		items.add_item(label)
		_item_ids.append(id)
	if _item_ids.is_empty():
		items.add_item("(vide)")
	item_desc.text = ""
	notes.clear()
	_note_ids.clear()
	for nid: String in GameManager.notes_read:
		notes.add_item(GameManager.note_title(nid))
		_note_ids.append(nid)
	if _note_ids.is_empty():
		notes.add_item("(aucun document lu)")
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_item_selected(idx: int) -> void:
	if idx >= 0 and idx < _item_ids.size():
		item_desc.text = GameManager.item_desc(_item_ids[idx])


func _on_note_activated(idx: int) -> void:
	if idx >= 0 and idx < _note_ids.size():
		note_open_requested.emit(_note_ids[idx])


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
