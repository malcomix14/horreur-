class_name UITheme
extends RefCounted
## Thème d'interface construit par code : police à empattements système, boutons sobres,
## panneaux sombres bordés de rouge sang.

const TEXT: Color = Color(0.82, 0.78, 0.72)
const TEXT_DIM: Color = Color(0.55, 0.52, 0.48)
const ACCENT: Color = Color(0.62, 0.1, 0.08)
const PANEL: Color = Color(0.03, 0.025, 0.025, 0.94)

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = Assets.font_serif()
	t.default_font_size = 22
	var normal := _box(Color(0.06, 0.045, 0.045, 0.75), Color(0.25, 0.07, 0.06), 1)
	var hover := _box(Color(0.16, 0.035, 0.03, 0.9), ACCENT, 1)
	var pressed := _box(Color(0.3, 0.04, 0.03, 0.95), Color(0.85, 0.2, 0.15), 1)
	var disabled := _box(Color(0.04, 0.04, 0.04, 0.5), Color(0.12, 0.12, 0.12), 1)
	var focus := _box(Color(0, 0, 0, 0), Color(0.75, 0.2, 0.15), 1)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.86))
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.7, 0.6))
	t.set_color("font_focus_color", "Button", Color(1.0, 0.92, 0.86))
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.33, 0.3))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(0.3, 0.07, 0.06), 1))
	t.set_stylebox("panel", "Panel", _box(PANEL, Color(0.3, 0.07, 0.06), 1))
	var bar_bg := _box(Color(0.1, 0.08, 0.08, 0.8), Color(0.2, 0.1, 0.1), 1)
	var bar_fill := _box(Color(0.55, 0.12, 0.08, 0.95), Color(0.55, 0.12, 0.08), 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color(1.0, 0.92, 0.86))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", focus)
	var slider := _box(Color(0.15, 0.1, 0.1), Color(0.3, 0.1, 0.1), 1)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", _box(Color(0.5, 0.1, 0.08), Color(0.5, 0.1, 0.08), 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(0.7, 0.15, 0.1), Color(0.7, 0.15, 0.1), 0))
	t.set_stylebox("panel", "ItemList", _box(Color(0.05, 0.04, 0.04, 0.8), Color(0.2, 0.08, 0.07), 1))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color(1, 0.9, 0.85))
	t.set_stylebox("selected", "ItemList", _box(Color(0.3, 0.05, 0.04, 0.9), ACCENT, 0))
	t.set_stylebox("selected_focus", "ItemList", _box(Color(0.35, 0.06, 0.05, 0.95), ACCENT, 0))
	_theme = t
	return t


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func label(text: String, size: int = 22, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, min_width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 46)
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_click"))
	b.pressed.connect(callback)
	b.mouse_entered.connect(func() -> void: AudioManager.play_ui("ui_hover", -14.0))
	return b


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func clear_cache() -> void:
	_theme = null
