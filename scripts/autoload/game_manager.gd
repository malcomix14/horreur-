extends Node
## GameManager : état global d'une partie.
## Phase de jeu, inventaire, drapeaux d'énigmes, objets ramassés, notes lues, objectif.

signal phase_changed(new_phase: int)
signal flag_changed(flag_name: String, value: bool)
signal inventory_changed

enum Phase { BOOT, MENU, LOADING, PLAYING, PAUSED, UI, CUTSCENE, DEAD, VICTORY }

const KEY_ITEMS: Array[String] = ["key_iron", "key_silver", "key_brass", "key_bone"]
const ITEMS_PATH: String = "res://data/items.json"
const NOTES_PATH: String = "res://data/notes.json"

var phase: Phase = Phase.BOOT
var inventory: Inventory = Inventory.new()
var flags: Dictionary = {}
var collected: Dictionary = {}
var notes_read: Array[String] = []
var scares_used: Dictionary = {}
var objective: String = ""
var play_time: float = 0.0
var deaths: int = 0
var items_db: Dictionary = {}
var notes_db: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	items_db = _load_json(ITEMS_PATH)
	notes_db = _load_json(NOTES_PATH)
	inventory.changed.connect(func() -> void: inventory_changed.emit())


func _process(delta: float) -> void:
	if phase == Phase.PLAYING:
		play_time += delta


func set_phase(p: Phase) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(p)


func is_playing() -> bool:
	return phase == Phase.PLAYING


# ---------------------------------------------------------------- Nouvelle partie / sauvegarde

func new_game() -> void:
	inventory.clear()
	flags.clear()
	collected.clear()
	notes_read.clear()
	scares_used.clear()
	objective = ""
	play_time = 0.0
	deaths = 0


func serialize() -> Dictionary:
	return {
		"inventory": inventory.to_dict(),
		"flags": flags.duplicate(),
		"collected": collected.keys(),
		"notes_read": notes_read.duplicate(),
		"scares_used": scares_used.keys(),
		"objective": objective,
		"play_time": play_time,
		"deaths": deaths,
	}


func deserialize(d: Dictionary) -> void:
	new_game()
	var inv: Variant = d.get("inventory", {})
	if inv is Dictionary:
		inventory.from_dict(inv as Dictionary)
	var fl: Variant = d.get("flags", {})
	if fl is Dictionary:
		var fd: Dictionary = fl
		for k: Variant in fd.keys():
			flags[str(k)] = bool(fd[k])
	var col: Variant = d.get("collected", [])
	if col is Array:
		for c: Variant in (col as Array):
			collected[str(c)] = true
	var nr: Variant = d.get("notes_read", [])
	if nr is Array:
		for n: Variant in (nr as Array):
			notes_read.append(str(n))
	var su: Variant = d.get("scares_used", [])
	if su is Array:
		for s: Variant in (su as Array):
			scares_used[str(s)] = true
	objective = str(d.get("objective", ""))
	play_time = float(d.get("play_time", 0.0))
	deaths = int(d.get("deaths", 0))


# ---------------------------------------------------------------- Inventaire

func add_item(id: String, amount: int = 1, announce: bool = true) -> void:
	inventory.add(id, amount)
	if announce:
		var label := item_name(id)
		if amount > 1:
			label += " x%d" % amount
		Events.message_requested.emit("Obtenu : %s" % label, 2.5)


func remove_item(id: String, amount: int = 1) -> bool:
	return inventory.remove(id, amount)


func has_item(id: String) -> bool:
	return inventory.has_item(id)


func key_count() -> int:
	var n := 0
	for k: String in KEY_ITEMS:
		if inventory.has_item(k):
			n += 1
	return n


func item_name(id: String) -> String:
	var entry: Variant = items_db.get(id, null)
	if entry is Dictionary:
		return str((entry as Dictionary).get("name", id))
	return id


func item_desc(id: String) -> String:
	var entry: Variant = items_db.get(id, null)
	if entry is Dictionary:
		return str((entry as Dictionary).get("desc", ""))
	return ""


# ---------------------------------------------------------------- Drapeaux / collecte

func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)


func get_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))


func mark_collected(save_id: String) -> void:
	if save_id != "":
		collected[save_id] = true


func is_collected(save_id: String) -> bool:
	return save_id != "" and collected.has(save_id)


func mark_note_read(note_id: String) -> void:
	if not notes_read.has(note_id):
		notes_read.append(note_id)


func set_objective(text: String) -> void:
	if text == objective:
		return
	objective = text
	Events.objective_changed.emit(text)


# ---------------------------------------------------------------- Données

func note_title(note_id: String) -> String:
	var entry: Variant = notes_db.get(note_id, null)
	if entry is Dictionary:
		return str((entry as Dictionary).get("title", note_id))
	return note_id


func note_text(note_id: String) -> String:
	var entry: Variant = notes_db.get(note_id, null)
	if entry is Dictionary:
		return str((entry as Dictionary).get("text", ""))
	return "(Le texte est illisible.)"


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Fichier de données manquant : %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("JSON invalide : %s" % path)
	return {}
