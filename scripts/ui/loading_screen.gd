class_name LoadingScreen
extends CanvasLayer
## Écran de chargement (génération des textures/sons au premier lancement, construction du manoir).

var bar: ProgressBar
var info: Label
var tip: Label

const TIPS: Array[String] = [
	"Le Veilleur ne tue pas en regardant. Il doit vous attraper.",
	"Courir fait du bruit. Marcher accroupi (Ctrl / C) est presque silencieux.",
	"Fermez les portes derrière vous : il doit les enfoncer pour passer.",
	"Ne vous cachez pas sous ses yeux : il vous a vu entrer, il viendra vous chercher.",
	"Votre lampe s'use. Gardez des piles et éteignez-la (F) pour vous faire discret.",
	"Écoutez : son souffle et ses pas trahissent sa présence.",
]


func _ready() -> void:
	layer = 50
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	UITheme.full_rect(bg)
	add_child(bg)
	var box := VBoxContainer.new()
	box.theme = UITheme.get_theme()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-360, -80)
	box.custom_minimum_size = Vector2(720, 160)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var title := UITheme.label("VESPÉRINE", 54, Color(0.75, 0.12, 0.1), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(title)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(720, 10)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	box.add_child(bar)
	info = UITheme.label("", 18, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(info)
	tip = UITheme.label("", 18, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	visible = false


func show_loading(text: String) -> void:
	visible = true
	bar.value = 0.0
	info.text = text
	tip.text = TIPS[randi() % TIPS.size()]


func set_progress(ratio: float, text: String) -> void:
	bar.value = clampf(ratio, 0.0, 1.0)
	info.text = text


func hide_loading() -> void:
	visible = false
