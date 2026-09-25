class_name NoteItem
extends Interactable
## Document lisible (lettre, journal, dessin...). Le texte est dans data/notes.json.

var note_id: String = ""
var scare_on_close: String = ""
var on_read: Callable = Callable()
var _glint: MeshInstance3D


## kind : "paper", "book", "card", "drawing", "newspaper"
func setup(p_note_id: String, kind: String = "paper") -> void:
	note_id = p_note_id
	prompt = "Lire : %s" % GameManager.note_title(note_id)
	var b := MeshBatcher.new()
	match kind:
		"book":
			b.add_box("leather", Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), Vector3(0.17, 0.04, 0.24), Color(0.5, 0.15, 0.1))
			b.add_box("paper", Transform3D(Basis.IDENTITY, Vector3(0.005, 0.02, 0)), Vector3(0.165, 0.032, 0.225), Color(0.85, 0.8, 0.65))
		"card":
			b.add_box("paper", Transform3D(Basis(Vector3.RIGHT, -1.2), Vector3(0, 0.05, 0)), Vector3(0.13, 0.002, 0.11), Color(0.95, 0.85, 0.85), 1.0, true)
		"drawing":
			b.add_box("drawing", Transform3D(Basis.IDENTITY, Vector3(0, 0.001, 0)), Vector3(0.26, 0.002, 0.26), Color.WHITE, 1.0, true)
		"newspaper":
			b.add_box("paper", Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 0.002, 0)), Vector3(0.32, 0.004, 0.42), Color(0.75, 0.73, 0.68), 1.0, true)
		_:
			b.add_box("paper", Transform3D(Basis(Vector3.UP, 0.15), Vector3(0, 0.001, 0)), Vector3(0.21, 0.002, 0.29), Color.WHITE, 1.0, true)
	var mi := make_mesh(b)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_detect_box(Vector3(0.36, 0.12, 0.4), Vector3(0, 0.04, 0))
	# Reflet froid et discret tant que le document n'a pas été lu.
	_glint = add_glint(0.08 if kind != "card" else 0.14, true)


func _ready() -> void:
	if _glint != null:
		_glint.visible = not GameManager.notes_read.has(note_id)


func interact(_player: Player) -> void:
	AudioManager.play_2d("paper", -4.0)
	GameManager.mark_note_read(note_id)
	if _glint != null:
		_glint.visible = false
	if scare_on_close != "":
		var trig := scare_on_close
		scare_on_close = ""
		Events.note_closed.connect(func(_id: String) -> void: Events.scare_trigger.emit(trig, self), CONNECT_ONE_SHOT)
	Events.note_requested.emit(note_id)
	if on_read.is_valid():
		on_read.call()
