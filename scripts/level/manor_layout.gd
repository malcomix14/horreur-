class_name ManorLayout
extends RefCounted
## Plan du manoir Vespérine : pièces (rectangles X/Z), ouvertures (portes, passages, fenêtres),
## trémie d'escalier, points de patrouille. Unité : mètre. X = est, Z = sud, Y = haut.
##
##  z=0  +---------+---+-------+--------+-----------+------+
##       |  BIBLI  |SEC| BUREAU| CHAPELLE|  CHAMBRE  | SdB  |
##  z=9  +---------+---+-------+--------+-----------+------+
##       |                 G A L E R I E                   |
##  z=12 +-----------+---+---------------+---+-------------+
##       |  SALLE A  | C |               | C |   SALON     |
##       |  MANGER   | O |   GRAND HALL  | O |             |
##  z=22 +-----------+ U |   (escalier)  | U +------+------+
##       |  CUISINE  | L |               | L | LISE |GASPARD|
##  z=30 +-----------+---+----[PORTE]----+---+------+------+
##       x=0        12  15              29  32     38     44
##  Sous la cuisine et la salle à manger : les caves (y = -3.6).

class RoomDef:
	var id: String = ""
	var label: String = ""
	var rect: Rect2 = Rect2()
	var floor_y: float = 0.0
	var height: float = 3.4
	var style: String = ""
	var zone: String = "room"

	func contains_xz(x: float, z: float, margin: float = 0.0) -> bool:
		return x > rect.position.x - margin and x < rect.end.x + margin and z > rect.position.y - margin and z < rect.end.y + margin

	func contains(p: Vector3) -> bool:
		return contains_xz(p.x, p.z) and p.y > floor_y - 0.6 and p.y < floor_y + height

	func center() -> Vector3:
		var c := rect.get_center()
		return Vector3(c.x, floor_y, c.y)


class Opening:
	var id: String = ""
	var kind: String = "door"
	var horizontal: bool = true
	var line: float = 0.0
	var center: float = 0.0
	var width: float = 1.2
	var bottom: float = 0.0
	var top: float = 2.4
	var level: float = 0.0

	func a() -> float:
		return center - width * 0.5

	func b() -> float:
		return center + width * 0.5

	func world_center() -> Vector3:
		if horizontal:
			return Vector3(center, level, line)
		return Vector3(line, level, center)

	func is_passage() -> bool:
		return kind in ["door", "double", "arch", "secret", "main"]


const LEVEL_GROUND: float = 0.0
const LEVEL_CELLAR: float = -3.6

var rooms: Array[RoomDef] = []
var openings: Array[Opening] = []
var floor_holes: Dictionary = {}
var ceiling_holes: Dictionary = {}
var patrol_points: Array[Vector3] = []


func _init() -> void:
	_rooms()
	_openings()
	_holes()
	_patrol()


func _room(id: String, label: String, x0: float, z0: float, x1: float, z1: float, y: float, h: float, style: String, zone: String) -> void:
	var r := RoomDef.new()
	r.id = id
	r.label = label
	r.rect = Rect2(x0, z0, x1 - x0, z1 - z0)
	r.floor_y = y
	r.height = h
	r.style = style
	r.zone = zone
	rooms.append(r)


func _rooms() -> void:
	_room("lib", "Bibliothèque", 0, 0, 9, 9, 0.0, 3.6, "library", "room")
	_room("secret", "Cabinet secret", 9, 0, 12, 9, 0.0, 3.0, "secret", "room")
	_room("study", "Bureau", 12, 0, 19, 9, 0.0, 3.4, "study", "room")
	_room("chapel", "Chapelle", 19, 0, 27, 9, 0.0, 5.0, "chapel", "room")
	_room("master", "Chambre des maîtres", 27, 0, 38, 9, 0.0, 3.4, "master", "room")
	_room("bath", "Salle de bain", 38, 0, 44, 9, 0.0, 3.2, "bath", "room")
	_room("gallery", "Galerie", 0, 9, 44, 12, 0.0, 3.4, "gallery", "corridor")
	_room("dining", "Salle à manger", 0, 12, 12, 22, 0.0, 3.6, "dining", "room")
	_room("kitchen", "Cuisine", 0, 22, 12, 30, 0.0, 3.2, "kitchen", "room")
	_room("wcorr", "Couloir ouest", 12, 12, 15, 30, 0.0, 3.4, "corridor", "corridor")
	_room("hall", "Grand hall", 15, 12, 29, 30, 0.0, 7.0, "hall", "hall")
	_room("ecorr", "Couloir est", 29, 12, 32, 30, 0.0, 3.4, "corridor", "corridor")
	_room("salon", "Salon", 32, 12, 44, 22, 0.0, 3.6, "salon", "room")
	_room("lise", "Chambre de Lise", 32, 22, 38, 30, 0.0, 3.2, "lise", "room")
	_room("servant", "Chambre de Gaspard", 38, 22, 44, 30, 0.0, 3.2, "servant", "room")
	_room("cellar_b", "Cave à vin", 0, 12, 12, 22, LEVEL_CELLAR, 3.3, "cellar", "cellar")
	_room("cellar_a", "Cave", 0, 22, 12, 30, LEVEL_CELLAR, 3.3, "cellar", "cellar")


func _op(id: String, kind: String, horizontal: bool, line: float, center: float, width: float, bottom: float, top: float, level: float = 0.0) -> void:
	var o := Opening.new()
	o.id = id
	o.kind = kind
	o.horizontal = horizontal
	o.line = line
	o.center = center
	o.width = width
	o.bottom = bottom
	o.top = top
	o.level = level
	openings.append(o)


func _openings() -> void:
	var H := true
	var V := false
	# --- façade nord (z = 0)
	_op("w_lib_n1", "window", H, 0.0, 2.5, 1.2, 0.9, 2.6)
	_op("w_lib_n2", "window", H, 0.0, 6.5, 1.2, 0.9, 2.6)
	_op("w_study_n", "window", H, 0.0, 15.5, 1.2, 0.9, 2.5)
	_op("w_chapel", "stained", H, 0.0, 23.0, 1.8, 1.6, 4.4)
	_op("w_master_n1", "window", H, 0.0, 30.5, 1.2, 0.9, 2.5)
	_op("w_master_n2", "window", H, 0.0, 34.5, 1.2, 0.9, 2.5)
	_op("w_bath_n", "window", H, 0.0, 41.0, 1.0, 1.2, 2.4)
	# --- ligne z = 9 (pièces nord / galerie)
	_op("d_lib", "door", H, 9.0, 4.5, 1.2, 0.0, 2.4)
	_op("d_study", "door", H, 9.0, 15.5, 1.2, 0.0, 2.4)
	_op("d_chapel", "double", H, 9.0, 23.0, 1.8, 0.0, 2.7)
	_op("d_master", "door", H, 9.0, 30.0, 1.2, 0.0, 2.4)
	_op("d_bath", "door", H, 9.0, 41.5, 1.2, 0.0, 2.4)
	# --- ligne z = 12 (galerie / pièces sud)
	_op("d_dining_n", "door", H, 12.0, 6.0, 1.2, 0.0, 2.4)
	_op("a_wcorr", "arch", H, 12.0, 13.5, 2.2, 0.0, 3.0)
	_op("a_hall", "arch", H, 12.0, 22.0, 3.2, 0.0, 3.1)
	_op("a_ecorr", "arch", H, 12.0, 30.5, 2.2, 0.0, 3.0)
	_op("d_salon_n", "door", H, 12.0, 38.0, 1.2, 0.0, 2.4)
	# --- ligne z = 22
	_op("d_kitchen", "door", H, 22.0, 3.0, 1.2, 0.0, 2.4)
	_op("d_servant", "door", H, 22.0, 41.0, 1.2, 0.0, 2.4)
	# --- façade sud (z = 30)
	_op("w_kitchen_s", "window", H, 30.0, 2.5, 1.2, 0.9, 2.4)
	_op("w_wcorr_s", "window", H, 30.0, 13.5, 1.0, 0.9, 2.5)
	_op("w_hall_s1", "window", H, 30.0, 17.5, 1.4, 0.9, 4.0)
	_op("d_main", "main", H, 30.0, 22.0, 2.4, 0.0, 3.4)
	_op("w_hall_s2", "window", H, 30.0, 26.5, 1.4, 0.9, 4.0)
	_op("w_ecorr_s", "window", H, 30.0, 30.5, 1.0, 0.9, 2.5)
	_op("w_lise_s", "window", H, 30.0, 35.0, 1.2, 0.9, 2.4)
	_op("w_servant_s", "window", H, 30.0, 41.0, 1.2, 0.9, 2.4)
	# --- façade ouest (x = 0)
	_op("w_lib_w", "window", V, 0.0, 4.5, 1.2, 0.9, 2.6)
	_op("w_gallery_w", "window", V, 0.0, 10.5, 1.0, 0.9, 2.6)
	_op("w_dining_w1", "window", V, 0.0, 14.5, 1.2, 0.9, 2.7)
	_op("w_dining_w2", "window", V, 0.0, 19.5, 1.2, 0.9, 2.7)
	_op("w_kitchen_w", "window", V, 0.0, 25.5, 1.2, 0.9, 2.4)
	# --- lignes intérieures verticales
	_op("s_secret", "secret", V, 9.0, 4.5, 1.2, 0.0, 2.3)
	_op("d_dining_e", "door", V, 12.0, 17.0, 1.2, 0.0, 2.4)
	_op("d_kitchen_e", "door", V, 12.0, 25.0, 1.2, 0.0, 2.4)
	_op("a_hall_w", "arch", V, 15.0, 21.0, 2.4, 0.0, 3.0)
	_op("a_hall_e", "arch", V, 29.0, 21.0, 2.4, 0.0, 3.0)
	_op("d_salon_w", "door", V, 32.0, 17.0, 1.2, 0.0, 2.4)
	_op("d_lise", "door", V, 32.0, 26.0, 1.2, 0.0, 2.4)
	_op("d_bath_w", "door", V, 38.0, 4.5, 1.2, 0.0, 2.4)
	# --- façade est (x = 44)
	_op("w_bath_e", "window", V, 44.0, 4.5, 1.0, 1.2, 2.4)
	_op("w_gallery_e", "window", V, 44.0, 10.5, 1.0, 0.9, 2.6)
	_op("w_salon_e1", "window", V, 44.0, 13.8, 1.2, 0.9, 2.7)
	_op("w_salon_e2", "window", V, 44.0, 20.2, 1.2, 0.9, 2.7)
	_op("w_servant_e", "window", V, 44.0, 26.0, 1.2, 0.9, 2.4)
	# --- caves
	_op("a_cellar", "arch", H, 22.0, 6.0, 2.2, 0.0, 2.6, LEVEL_CELLAR)
	_op("h_dumbwaiter", "hatch", V, 12.0, 23.2, 0.8, 0.8, 1.6, LEVEL_CELLAR)


func _holes() -> void:
	# Trémie de l'escalier de la cave (le long du mur sud de la cuisine).
	var stair := Rect2(5.0, 28.1, 7.0, 1.9)
	floor_holes["kitchen"] = [stair]
	ceiling_holes["cellar_a"] = [stair]


func _patrol() -> void:
	var pts: Array[Vector3] = [
		Vector3(4.5, 0, 5.0), Vector3(15.5, 0, 5.0), Vector3(23.0, 0, 6.0), Vector3(31.0, 0, 5.5),
		Vector3(41.0, 0, 5.0), Vector3(2.5, 0, 10.5), Vector3(12.0, 0, 10.5), Vector3(22.0, 0, 10.5),
		Vector3(32.0, 0, 10.5), Vector3(41.5, 0, 10.5), Vector3(8.0, 0, 16.0), Vector3(4.0, 0, 25.0),
		Vector3(13.5, 0, 15.5), Vector3(13.5, 0, 26.0), Vector3(17.5, 0, 15.0), Vector3(26.5, 0, 15.0),
		Vector3(18.0, 0, 26.5), Vector3(26.0, 0, 26.5), Vector3(30.5, 0, 15.5), Vector3(30.5, 0, 26.0),
		Vector3(36.0, 0, 16.5), Vector3(35.0, 0, 26.0), Vector3(41.0, 0, 26.0),
		Vector3(3.0, LEVEL_CELLAR, 25.5), Vector3(9.5, LEVEL_CELLAR, 24.5), Vector3(6.0, LEVEL_CELLAR, 17.0),
	]
	patrol_points = pts


func get_room(id: String) -> RoomDef:
	for r: RoomDef in rooms:
		if r.id == id:
			return r
	return null


func room_at(p: Vector3) -> RoomDef:
	for r: RoomDef in rooms:
		if r.contains(p):
			return r
	return null


func rooms_at_level(y: float) -> Array[RoomDef]:
	var out: Array[RoomDef] = []
	for r: RoomDef in rooms:
		if is_equal_approx(r.floor_y, y):
			out.append(r)
	return out


func levels() -> Array[float]:
	return [LEVEL_GROUND, LEVEL_CELLAR]


func get_opening(id: String) -> Opening:
	for o: Opening in openings:
		if o.id == id:
			return o
	return null


func openings_on_line(level: float, horizontal: bool, line: float) -> Array[Opening]:
	var out: Array[Opening] = []
	for o: Opening in openings:
		if o.horizontal == horizontal and is_equal_approx(o.line, line) and is_equal_approx(o.level, level):
			out.append(o)
	return out
