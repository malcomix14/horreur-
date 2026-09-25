class_name ManorContent
extends RefCounted
## Aménagement pièce par pièce : mobilier, lumières, portes, cachettes, documents,
## objets, énigmes et accessoires de screamers. Coordonnées monde (voir ManorLayout).

const WARM: Color = Color(1.0, 0.72, 0.42)
const BULB: Color = Color(1.0, 0.82, 0.6)
const COLD: Color = Color(0.7, 0.8, 1.0)
const MOON: Color = Color(0.55, 0.66, 1.0)

var world: GameWorld
var b: ManorBuilder


func _init(p_world: GameWorld, p_builder: ManorBuilder) -> void:
	world = p_world
	b = p_builder


func populate(progress: Callable) -> void:
	_doors()
	var steps: Array[Callable] = [
		_dining, _kitchen, _cellar, _library, _secret, _study, _chapel, _master,
		_bath, _gallery, _corridors, _hall, _salon, _lise, _servant, _cobwebs, _exterior,
	]
	var i := 0
	for step: Callable in steps:
		step.call()
		i += 1
		if progress.is_valid():
			progress.call(0.3 + 0.4 * float(i) / float(steps.size()), "Aménagement du manoir…")
		await world.get_tree().process_frame


# ============================================================ utilitaires

func _add(room: String, node: Node3D, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	b.room_node(room).add_child(node)
	node.position = pos
	node.rotation.y = rot_y
	return node


func _pickup(room: String, item: String, save_id: String, pos: Vector3, rot: float = 0.0, amount: int = 1) -> Pickup:
	var p := Pickup.new()
	p.setup(item, save_id, amount)
	_add(room, p, pos, rot)
	return p


func _note(room: String, note_id: String, kind: String, pos: Vector3, rot: float = 0.0) -> NoteItem:
	var n := NoteItem.new()
	n.setup(note_id, kind)
	_add(room, n, pos, rot)
	return n


func _hide(room: String, kind: String, pos: Vector3, rot: float, wood: String = "wood_dark", fabric: String = "fabric_red", width: float = 1.2) -> HidingSpot:
	var h := HidingSpot.new()
	h.setup(kind, wood, fabric, width)
	_add(room, h, pos, rot)
	return h


func _light(room: String, pos: Vector3, color: Color, energy: float, light_range: float, mode: FlickerLight.Mode, glow: String = "bulb", power_group: String = "") -> FlickerLight:
	var l := FlickerLight.new()
	l.setup(color, energy, light_range, mode)
	l.power_group = power_group
	l.room_id = room
	_add(room, l, pos)
	if glow == "bulb":
		var g := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		sm.radial_segments = 8
		sm.rings = 4
		g.mesh = sm
		g.material_override = Assets.mat("bulb")
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 34.0
		_add(room, g, pos)
		l.glow_nodes.append(g)
		var halo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		halo.mesh = q
		halo.material_override = Assets.mat("halo")
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.visibility_range_end = 30.0
		_add(room, halo, pos)
		l.glow_nodes.append(halo)
	elif glow == "flame":
		l.glow_nodes.append(_flame(room, pos + Vector3(0, -0.12, 0), 1.0))
	if mode == FlickerLight.Mode.FAULTY:
		l.buzz = AudioManager.make_emitter("buzz_loop", l, -14.0, 1.5, 7.0, false)
	return l


func _flame(room: String, pos: Vector3, scale: float) -> MeshInstance3D:
	var f := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.085) * scale
	f.mesh = q
	f.material_override = Assets.mat("flame")
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.visibility_range_end = 30.0
	_add(room, f, pos)
	return f


## Candélabre posé (3 bougies) + lumière de bougie.
func _candelabra(room: String, pos: Vector3, energy: float = 1.4, lit: bool = true) -> FlickerLight:
	b.cyl(room, "brass", pos, 0.09, 0.05, 0.04, 8)
	b.cyl(room, "brass", pos + Vector3(0, 0.04, 0), 0.015, 0.015, 0.3, 6)
	b.box(room, "brass", pos + Vector3(0, 0.32, 0), Vector3(0.36, 0.02, 0.02), 0.0, false)
	var tops: Array[Vector3] = [Vector3(-0.17, 0.33, 0), Vector3(0, 0.36, 0), Vector3(0.17, 0.33, 0)]
	var flames: Array[Node3D] = []
	for t: Vector3 in tops:
		b.cyl(room, "wax", pos + t, 0.016, 0.016, 0.1, 6)
		flames.append(_flame(room, pos + t + Vector3(0, 0.14, 0), 1.0))
	var l := _light(room, pos + Vector3(0, 0.6, 0), WARM, energy, 9.0, FlickerLight.Mode.CANDLE, "none")
	for f: Node3D in flames:
		l.glow_nodes.append(f)
	l.set_switched(lit)
	return l


func _sconce(room: String, pos: Vector3, normal: Vector3, mode: FlickerLight.Mode = FlickerLight.Mode.CANDLE, energy: float = 1.2) -> FlickerLight:
	b.box(room, "brass", pos - normal * 0.02 + Vector3(0, -0.12, 0), Vector3(0.1, 0.22, 0.1) if absf(normal.z) > 0.5 else Vector3(0.1, 0.22, 0.1), 0.0, false)
	b.box(room, "brass", pos + normal * 0.08 + Vector3(0, -0.2, 0), Vector3(0.05, 0.04, 0.05), 0.0, false)
	b.cyl(room, "wax", pos + normal * 0.12 + Vector3(0, -0.18, 0), 0.018, 0.018, 0.1, 6)
	var l := _light(room, pos + normal * 0.25, WARM if mode != FlickerLight.Mode.FAULTY else BULB, energy, 8.5, mode, "none")
	l.glow_nodes.append(_flame(room, pos + normal * 0.12 + Vector3(0, -0.02, 0), 1.0))
	return l


## Clair de lune entrant par une fenêtre : lumière froide et diffuse placée juste à l'intérieur.
## Donne une visibilité « naturelle » aux pièces sans casser l'ambiance nocturne.
func _moonlight(room: String, pos: Vector3, energy: float = 0.85, light_range: float = 8.0) -> FlickerLight:
	var l := _light(room, pos, MOON, energy, light_range, FlickerLight.Mode.STEADY, "none")
	l.light_specular = 0.1
	return l


## Bougie sur son bougeoir (flamme + lumière chaude). `with_stick` = false si le bougeoir existe déjà.
func _candle(room: String, pos: Vector3, energy: float = 1.0, light_range: float = 7.0, with_stick: bool = true) -> FlickerLight:
	if with_stick:
		PropFactory.candle_stick(b, room, pos)
	var l := _light(room, pos + Vector3(0, 0.45, 0), WARM, energy, light_range, FlickerLight.Mode.CANDLE, "none")
	l.glow_nodes.append(_flame(room, pos + Vector3(0, 0.29, 0), 1.0))
	return l


## Grand cierge sur pied de fer forgé (chapelle).
func _cierge(room: String, pos: Vector3, energy: float = 1.1, light_range: float = 8.0) -> FlickerLight:
	b.cyl(room, "iron_black", pos, 0.14, 0.1, 0.03, 8)
	b.cyl(room, "iron_black", pos + Vector3(0, 0.03, 0), 0.02, 0.02, 1.05, 6)
	b.cyl(room, "iron_black", pos + Vector3(0, 1.08, 0), 0.07, 0.07, 0.02, 8)
	b.cyl(room, "wax", pos + Vector3(0, 1.1, 0), 0.035, 0.035, 0.3, 8)
	b.collider(room, pos + Vector3(0, 0.6, 0), Vector3(0.25, 1.2, 0.25))
	var l := _light(room, pos + Vector3(0, 1.6, 0), WARM, energy, light_range, FlickerLight.Mode.CANDLE, "none")
	l.glow_nodes.append(_flame(room, pos + Vector3(0, 1.45, 0), 1.3))
	return l


## Lanterne à pétrole accrochée au mur ou au plafond (flamme derrière des montants de fer).
func _lantern(room: String, pos: Vector3, energy: float = 1.2, light_range: float = 8.5) -> FlickerLight:
	b.cyl(room, "iron_black", pos + Vector3(0, -0.14, 0), 0.075, 0.075, 0.03, 8)
	b.cyl(room, "iron_black", pos + Vector3(0, 0.1, 0), 0.075, 0.02, 0.07, 8)
	b.cyl(room, "iron_black", pos + Vector3(0, 0.17, 0), 0.006, 0.006, 0.12, 4)
	for k: int in range(4):
		var a := TAU * float(k) / 4.0 + PI * 0.25
		b.box(room, "iron_black", pos + Vector3(cos(a) * 0.07, -0.02, sin(a) * 0.07), Vector3(0.012, 0.24, 0.012), 0.0, false)
	var l := _light(room, pos, WARM, energy, light_range, FlickerLight.Mode.CANDLE, "none")
	l.glow_nodes.append(_flame(room, pos + Vector3(0, -0.06, 0), 1.2))
	return l


## Lampadaire à abat-jour de tissu (l'abat-jour luit doucement).
func _floor_lamp(room: String, pos: Vector3, energy: float = 1.3, light_range: float = 8.5) -> FlickerLight:
	b.cyl(room, "brass", pos, 0.16, 0.12, 0.04, 10)
	b.cyl(room, "brass", pos + Vector3(0, 0.04, 0), 0.015, 0.015, 1.36, 6)
	b.cyl(room, "lampshade", pos + Vector3(0, 1.3, 0), 0.25, 0.15, 0.28, 12)
	b.collider(room, pos + Vector3(0, 0.7, 0), Vector3(0.32, 1.4, 0.32))
	return _light(room, pos + Vector3(0, 1.42, 0), Color(1.0, 0.76, 0.48), energy, light_range, FlickerLight.Mode.STEADY, "none")


## Soupirail de cave : petite ouverture grillagée en haut du mur, laisse passer un peu de lune.
## `center` est sur la face intérieure du mur, `normal` pointe vers l'intérieur de la pièce.
func _soupirail(room: String, center: Vector3, normal: Vector3, energy: float = 0.7) -> FlickerLight:
	var along := normal.cross(Vector3.UP).normalized()
	var hw := 0.38
	var hh := 0.17
	var c := center + normal * 0.005
	b.quad_uv(room, "glass_window", c - along * hw - Vector3(0, hh, 0), c + along * hw - Vector3(0, hh, 0), c + along * hw + Vector3(0, hh, 0), c - along * hw + Vector3(0, hh, 0), normal)
	for k: int in range(5):
		var t := -hw + (float(k) + 0.5) * (hw * 2.0) / 5.0
		b.box(room, "iron_black", c + along * t + normal * 0.02, Vector3(0.02, hh * 2.0, 0.02), 0.0, false)
	b.box(room, "stone_dark", c + normal * 0.06 - Vector3(0, hh + 0.03, 0), Vector3(absf(along.x) * hw * 2.2 + 0.12, 0.06, absf(along.z) * hw * 2.2 + 0.12), 0.0, false)
	return _moonlight(room, center + normal * 0.8 - Vector3(0, 0.45, 0), energy, 7.0)


func _examine(room: String, p_prompt: String, message: String, pos: Vector3, rot: float, size: Vector3, offset: Vector3 = Vector3.ZERO) -> ExamineProp:
	var e := ExamineProp.new()
	e.setup(p_prompt, message, size, offset)
	_add(room, e, pos, rot)
	return e


func _drawer(room: String, pos: Vector3, rot: float, w: float = 0.42, h: float = 0.14, d: float = 0.4, wood: String = "wood_med") -> Drawer:
	var dr := Drawer.new()
	dr.setup(w, h, d, wood)
	_add(room, dr, pos, rot)
	return dr


func _portrait(room: String, center: Vector3, normal: Vector3, w: float, h: float, mat: String) -> void:
	PropFactory.portrait(b, room, center, normal, w, h, mat)


# ============================================================ portes

func _doors() -> void:
	for o: ManorLayout.Opening in world.layout.openings:
		var rot := 0.0 if o.horizontal else PI * 0.5
		var room := world.layout.room_at(o.world_center() + (Vector3(0, 0.5, -0.3) if o.horizontal else Vector3(-0.3, 0.5, 0)))
		if room == null:
			room = world.layout.room_at(o.world_center() + (Vector3(0, 0.5, 0.3) if o.horizontal else Vector3(0.3, 0.5, 0)))
		if room == null:
			continue
		match o.kind:
			"door", "double":
				var d := Door.new()
				d.setup(o.width, o.top, o.kind == "double", "wood_dark")
				d.name = "Door_" + o.id
				_add(room.id, d, o.world_center(), rot)
				if o.id == "d_chapel":
					d.first_open_trigger = "door_chapel_first"
			"main":
				var md := MainDoor.new()
				md.setup(o.width, o.top)
				md.name = "MainDoor"
				_add(room.id, md, o.world_center(), rot)


# ============================================================ salle à manger (départ)

func _dining() -> void:
	var r := "dining"
	PropFactory.rug(b, r, Vector3(6, 0, 17), 6.6, 3.2, 0.0, "rug")
	PropFactory.table(b, r, PropFactory.at(Vector3(6, 0, 17)), 5.0, 1.3, 0.78, "wood_dark", "fabric_red")
	var xs: Array[float] = [4.2, 5.4, 6.6, 7.8]
	for i: int in range(xs.size()):
		PropFactory.chair(b, r, PropFactory.at(Vector3(xs[i], 0, 15.75), 0.0), "wood_dark", "fabric_red", false)
		if i == 2:
			PropFactory.chair(b, r, PropFactory.at(Vector3(xs[i], 0, 18.9), PI + 0.4), "wood_dark", "fabric_red", true)
		else:
			PropFactory.chair(b, r, PropFactory.at(Vector3(xs[i], 0, 18.25), PI + randf_range(-0.1, 0.1)), "wood_dark", "fabric_red", false)
	PropFactory.chair(b, r, PropFactory.at(Vector3(2.95, 0, 17), PI * 0.5), "wood_dark", "fabric_red")
	PropFactory.sheet_furniture(b, r, PropFactory.at(Vector3(9.3, 0, 17), -PI * 0.5), 0.6, 1.25, 0.6)
	# Couverts, assiettes.
	for x: float in [4.2, 5.4, 6.6, 7.8]:
		b.cyl(r, "porcelain", Vector3(x, 0.785, 16.6), 0.12, 0.12, 0.012, 12)
		b.cyl(r, "porcelain", Vector3(x, 0.785, 17.4), 0.12, 0.12, 0.012, 12)
	b.cyl(r, "metal", Vector3(5.0, 0.785, 17.0), 0.03, 0.04, 0.2, 8)
	# Candélabre allumé : la seule lumière au réveil.
	_candelabra(r, Vector3(6.0, 0.79, 17.0), 1.6, true)
	_pickup(r, "flashlight", "flashlight", Vector3(7.3, 0.795, 17.25), 0.4)
	_note(r, "lettre_notaire", "paper", Vector3(6.7, 0.792, 16.7), -0.3)
	# Buffet + pile + tableau.
	PropFactory.sideboard(b, r, PropFactory.at(Vector3(8.5, 0, 21.6), PI), 2.4, "wood_dark")
	PropFactory.vase(b, r, Vector3(7.7, 0.94, 21.6))
	PropFactory.candle_stick(b, r, Vector3(9.4, 0.94, 21.65))
	_candle(r, Vector3(9.4, 0.94, 21.65), 0.9, 7.0, false)
	_pickup(r, "battery", "bat_dining", Vector3(9.0, 0.95, 21.5), 0.8)
	# Lune par les deux fenêtres ouest.
	_moonlight(r, Vector3(1.0, 2.1, 14.5))
	_moonlight(r, Vector3(1.0, 2.1, 19.5))
	_portrait(r, Vector3(8.5, 2.0, 21.875), Vector3(0, 0, -1), 0.8, 1.0, "portrait_b")
	_portrait(r, Vector3(0.125, 1.9, 17.0), Vector3(1, 0, 0), 0.9, 1.1, "portrait_a")
	_hide(r, "closet", Vector3(10.2, 0, 12.125 + 0.31), 0.0, "wood_dark", "", 0.95)
	# Lustre éteint au-dessus de la table.
	b.cyl(r, "iron_black", Vector3(6, 2.7, 17), 0.02, 0.02, 0.9, 4)
	b.cyl(r, "brass", Vector3(6, 2.55, 17), 0.5, 0.45, 0.06, 12)
	for k: int in range(6):
		var a := TAU * float(k) / 6.0
		b.cyl(r, "wax", Vector3(6 + cos(a) * 0.48, 2.61, 17 + sin(a) * 0.48), 0.02, 0.02, 0.1, 6)


# ============================================================ cuisine

func _kitchen() -> void:
	var r := "kitchen"
	PropFactory.stove(b, r, PropFactory.at(Vector3(0.5, 0, 23.7), PI * 0.5))
	PropFactory.sink_basin(b, r, PropFactory.at(Vector3(0.43, 0, 25.5), PI * 0.5))
	PropFactory.counter(b, r, PropFactory.at(Vector3(7.4, 0, 22.43)), 2.4)
	PropFactory.counter(b, r, PropFactory.at(Vector3(10.05, 0, 22.43)), 2.5)
	PropFactory.shelf_wall(b, r, PropFactory.at(Vector3(7.4, 0, 22.26)), 2.2, 1.65)
	PropFactory.shelf_wall(b, r, PropFactory.at(Vector3(10.0, 0, 22.26)), 2.2, 1.95)
	PropFactory.table(b, r, PropFactory.at(Vector3(3.5, 0, 26.0)), 1.8, 0.9, 0.8, "wood_raw")
	PropFactory.chair(b, r, PropFactory.at(Vector3(3.2, 0, 26.9), PI), "wood_raw", "wood_raw")
	b.cyl(r, "metal", Vector3(3.9, 0.8, 25.9), 0.14, 0.12, 0.12, 10, false, Color(0.5, 0.5, 0.5))
	b.box(r, "wood_raw", Vector3(3.0, 0.82, 26.1), Vector3(0.45, 0.03, 0.3), 0.3, false)
	# Tiroirs : allumettes, main (screamer), pile, vide.
	var fronts: Array[float] = [6.6, 7.8, 9.4, 10.6]
	for i: int in range(fronts.size()):
		var dr := _drawer(r, Vector3(fronts[i], 0.72, 22.74), 0.0, 0.5, 0.14, 0.45)
		match i:
			0:
				var m := Pickup.new()
				m.setup("matches", "matches")
				dr.put_inside(m, Vector3(0.05, 0, 0.0))
			1:
				dr.scare_trigger = "drawer_kitchen_hand"
				var hand := _scare_hand()
				dr.tray.add_child(hand)
				hand.position = Vector3(0, -0.02, -0.25)
				hand.visible = false
				dr.visual_nodes.append(hand)
			2:
				var bt := Pickup.new()
				bt.setup("battery", "bat_kitchen")
				dr.put_inside(bt, Vector3(-0.1, 0, 0.02))
	# Trappe du monte-charge (côté cuisine) + note de Gaspard.
	b.box(r, "wood_dark", Vector3(11.84, 1.2, 23.2), Vector3(0.05, 0.8, 0.8), 0.0, false)
	b.box(r, "brass", Vector3(11.8, 1.2, 23.5), Vector3(0.03, 0.12, 0.03), 0.0, false)
	_examine(r, "Examiner la trappe du monte-charge", "La trappe du monte-charge. La cabine est coincée plus bas, entre deux étages.", Vector3(11.8, 1.2, 23.2), 0.0, Vector3(0.2, 0.8, 0.8))
	_note(r, "note_gaspard_fusible", "paper", Vector3(10.9, 0.93, 22.5), 0.4)
	# Suspension défaillante.
	b.cyl(r, "iron_black", Vector3(6, 2.3, 25.5), 0.01, 0.01, 0.9, 4)
	b.cyl(r, "metal", Vector3(6, 2.25, 25.5), 0.22, 0.05, 0.14, 10, false, Color(0.4, 0.45, 0.4))
	_light(r, Vector3(6, 2.2, 25.5), BULB, 1.1, 9.0, FlickerLight.Mode.FAULTY)
	_moonlight(r, Vector3(1.0, 1.9, 25.5), 0.6, 6.5)
	_candle(r, Vector3(9.4, 0.93, 22.55), 0.7, 6.5)
	# Casseroles suspendues.
	b.box(r, "iron_black", Vector3(3.5, 2.3, 26.0), Vector3(1.6, 0.03, 0.03), 0.0, false)
	for k: int in range(4):
		b.cyl(r, "metal", Vector3(2.9 + float(k) * 0.4, 1.95, 26.0), 0.12, 0.1, 0.1, 10, false, Color(0.55, 0.45, 0.35))
	_hide(r, "closet", Vector3(11.875 - 0.31, 0, 27.05), -PI * 0.5, "wood_med", "", 0.95)
	PropFactory.crate(b, r, Vector3(1.0, 0, 29.2), 0.55, 0.3)
	PropFactory.barrel(b, r, Vector3(2.2, 0, 29.3))


func _scare_hand() -> Node3D:
	var n := Node3D.new()
	var hb := MeshBatcher.new()
	hb.add_box("skin", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.12)), Vector3(0.07, 0.03, 0.26))
	hb.add_box("skin", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3)), Vector3(0.08, 0.025, 0.1))
	for f: int in range(4):
		hb.add_box("skin", Transform3D(Basis(Vector3.UP, (float(f) - 1.5) * 0.12), Vector3(-0.03 + float(f) * 0.02, 0, 0.42)), Vector3(0.012, 0.012, 0.16))
	var mi := MeshInstance3D.new()
	mi.mesh = hb.build(func(k: String) -> Material: return Assets.mat(k))
	n.add_child(mi)
	return n


# ============================================================ caves

func _cellar() -> void:
	var y := ManorLayout.LEVEL_CELLAR
	var rb := "cellar_b"
	var fb := FuseBox.new()
	fb.setup()
	_add(rb, fb, Vector3(6, y + 1.4, 12.125))
	b.box(rb, "iron_black", Vector3(6, y + 2.3, 12.16), Vector3(0.04, 1.4, 0.04), 0.0, false)
	PropFactory.wine_rack(b, rb, PropFactory.at(Vector3(0.35, y, 14.6), PI * 0.5), 3.0)
	PropFactory.wine_rack(b, rb, PropFactory.at(Vector3(0.35, y, 18.8), PI * 0.5), 3.0)
	PropFactory.barrel(b, rb, Vector3(11.2, y, 13.6))
	PropFactory.barrel(b, rb, Vector3(11.2, y, 14.5))
	PropFactory.barrel(b, rb, Vector3(10.4, y, 13.2), true)
	PropFactory.table(b, rb, PropFactory.at(Vector3(6.0, y, 17.2)), 2.2, 0.9, 0.85, "wood_raw")
	b.box(rb, "metal", Vector3(5.4, y + 0.9, 17.1), Vector3(0.3, 0.1, 0.15), 0.3, false)
	b.cyl(rb, "wax", Vector3(6.6, y + 0.85, 17.3), 0.03, 0.03, 0.08, 6)
	_pickup(rb, "battery", "bat_cellar", Vector3(6.2, y + 0.86, 17.0), 1.2)
	_hide(rb, "wardrobe", Vector3(11.875 - 0.31, y, 20.3), -PI * 0.5, "wood_raw", "", 1.2)
	PropFactory.crate(b, rb, Vector3(2.0, y, 21.0), 0.7, 0.2)
	PropFactory.crate(b, rb, Vector3(2.1, y + 0.7, 21.0), 0.5, 0.6)
	_light(rb, Vector3(3.5, y + 2.9, 15.5), BULB, 1.7, 10.0, FlickerLight.Mode.STEADY, "bulb", "cellar")
	_light(rb, Vector3(8.5, y + 2.9, 19.0), BULB, 1.5, 9.5, FlickerLight.Mode.FAULTY, "bulb", "cellar")
	# Sans courant : la bougie de Gaspard sur l'établi, sa lanterne près du tableau électrique, un soupirail.
	var cl := _light(rb, Vector3(6.6, y + 1.25, 17.3), WARM, 1.0, 8.0, FlickerLight.Mode.CANDLE, "none")
	cl.glow_nodes.append(_flame(rb, Vector3(6.6, y + 0.97, 17.3), 1.0))
	_lantern(rb, Vector3(7.5, y + 1.95, 12.45), 1.1, 8.0)
	b.box(rb, "iron_black", Vector3(7.5, y + 2.14, 12.2), Vector3(0.02, 0.02, 0.2), 0.0, false)
	_soupirail(rb, Vector3(0.126, y + 2.75, 16.7), Vector3(1, 0, 0))
	var ra := "cellar_a"
	var dw := Dumbwaiter.new()
	dw.setup()
	_add(ra, dw, Vector3(11.875, y, 23.2), -PI * 0.5)
	b.cyl(ra, "metal", Vector3(2.0, y, 28.4), 0.55, 0.55, 1.9, 14, true, Color(0.45, 0.4, 0.35))
	b.cyl(ra, "iron_black", Vector3(2.0, y + 1.9, 28.4), 0.12, 0.12, 1.5, 8)
	PropFactory.sheet_furniture(b, ra, PropFactory.at(Vector3(3.0, y, 24.2), 0.2), 1.4, 1.0, 0.8)
	PropFactory.sheet_furniture(b, ra, PropFactory.at(Vector3(7.5, y, 24.6), -0.3), 1.0, 1.6, 0.7)
	PropFactory.crate(b, ra, Vector3(4.2, y, 26.8), 0.6, 0.5)
	PropFactory.crate(b, ra, Vector3(8.6, y, 26.9), 0.7, 0.1)
	PropFactory.barrel(b, ra, Vector3(9.6, y, 26.8))
	_hide(ra, "wardrobe", Vector3(0.125 + 0.31, y, 25.8), PI * 0.5, "wood_raw", "", 1.2)
	_light(ra, Vector3(6.0, y + 2.9, 25.5), BULB, 1.7, 10.0, FlickerLight.Mode.STEADY, "bulb", "cellar")
	_lantern(ra, Vector3(10.4, y + 2.05, 24.4), 1.1, 8.0)
	b.cyl(ra, "iron_black", Vector3(10.4, y + 2.3, 24.4), 0.006, 0.006, 1.0, 4)
	_soupirail(ra, Vector3(0.126, y + 2.75, 27.4), Vector3(1, 0, 0))
	world.anchors["cellar_drip_1"] = Vector3(3.0, y + 3.0, 16.0)
	world.anchors["cellar_drip_2"] = Vector3(9.0, y + 3.0, 26.0)


# ============================================================ bibliothèque et cabinet secret

func _library() -> void:
	var r := "lib"
	PropFactory.rug(b, r, Vector3(4.5, 0, 4.6), 4.2, 3.2, 0.0, "rug")
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(0.33, 0, 2.0), PI * 0.5), 3.0, 3.0, 0.4, 7)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(0.33, 0, 7.0), PI * 0.5), 3.0, 3.0, 0.4, 7)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(4.5, 0, 0.33)), 2.3, 3.0, 0.4, 7)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(8.67, 0, 1.3), -PI * 0.5), 1.9, 3.0, 0.4, 7)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(8.67, 0, 6.5), -PI * 0.5), 2.0, 3.0, 0.4, 7)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(1.7, 0, 8.67), PI), 2.6, 3.0, 0.4, 7)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(7.2, 0, 8.67), PI), 2.4, 3.0, 0.4, 7)
	# Bibliothèque secrète + livre rouge (levier).
	var shelf := SecretBookshelf.new()
	shelf.setup()
	_add(r, shelf, Vector3(8.875, 0, 4.5), -PI * 0.5)
	var red := _examine(r, "Tirer le livre rouge", "", Vector3(1.2, 1.55, 8.42), PI, Vector3(0.12, 0.34, 0.25))
	var rbm := MeshBatcher.new()
	rbm.add_box("leather", Transform3D.IDENTITY, Vector3(0.06, 0.29, 0.24), Color(0.8, 0.08, 0.06))
	rbm.add_box("gold_frame", Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0.121)), Vector3(0.062, 0.02, 0.002))
	red.make_mesh(rbm)
	red.one_shot_message = true
	red.extra_callback = func() -> void:
		if GameManager.get_flag("secret_open"):
			Events.message_requested.emit("Le livre rouge ne bouge plus.", 2.0)
		else:
			shelf.open_shelf()
	# Bureau de lecture.
	PropFactory.desk(b, r, PropFactory.at(Vector3(4.5, 0, 4.0)), 1.6, "wood_dark")
	PropFactory.chair(b, r, PropFactory.at(Vector3(4.5, 0, 3.35), 0.0), "wood_dark", "leather")
	b.cyl(r, "brass", Vector3(5.1, 0.78, 3.8), 0.07, 0.07, 0.02, 8)
	b.cyl(r, "brass", Vector3(5.1, 0.8, 3.8), 0.012, 0.012, 0.3, 6)
	b.box(r, "glass_stained", Vector3(5.1, 1.12, 3.85), Vector3(0.3, 0.08, 0.14), 0.0, false, Color(0.2, 0.6, 0.3))
	_light(r, Vector3(5.1, 1.0, 3.95), Color(0.95, 0.9, 0.6), 1.4, 8.5, FlickerLight.Mode.STEADY, "none")
	_moonlight(r, Vector3(4.5, 2.3, 1.2), 0.9, 8.0)
	_moonlight(r, Vector3(1.2, 2.1, 4.5), 0.75, 7.0)
	_note(r, "coupure_journal", "newspaper", Vector3(4.2, 0.785, 4.1), 0.2)
	b.box(r, "leather", Vector3(3.8, 0.8, 3.9), Vector3(0.2, 0.05, 0.28), 0.4, false, Color(0.3, 0.12, 0.08))
	# Guéridon avec la manivelle.
	PropFactory.round_table(b, r, PropFactory.at(Vector3(1.6, 0, 5.0)), 0.35, 0.7, "wood_dark")
	_pickup(r, "crank", "crank", Vector3(1.55, 0.71, 5.0), 0.7)
	_candle(r, Vector3(1.78, 0.71, 4.78), 0.9, 7.0)
	PropFactory.armchair(b, r, PropFactory.at(Vector3(2.3, 0, 6.2), PI * 0.8), "fabric_green", "wood_dark")
	_hide(r, "closet", Vector3(7.9, 0, 0.125 + 0.31), 0.0, "wood_dark", "", 0.95)
	# Globe terrestre.
	b.cyl(r, "wood_dark", Vector3(6.8, 0, 6.9), 0.2, 0.05, 0.7, 8)
	b.sphere(r, "paper", Vector3(6.8, 1.0, 6.9), Vector3(0.28, 0.28, 0.28), Color(0.7, 0.62, 0.45), 14, 8)
	b.collider(r, Vector3(6.8, 0.6, 6.9), Vector3(0.6, 1.2, 0.6))


func _secret() -> void:
	var r := "secret"
	PropFactory.table(b, r, PropFactory.at(Vector3(10.5, 0, 1.6)), 1.8, 0.9, 0.85, "wood_black", "fabric_red")
	var reg := _pickup(r, "register", "register", Vector3(10.5, 0.86, 1.55), 0.1)
	reg.scare_trigger = "pickup_register"
	reg.checkpoint = true
	reg.pickup_message = "Le Registre de la Veille. « Seul le feu défait ce qui fut écrit. »"
	_note(r, "aurele_dernier", "paper", Vector3(10.0, 0.86, 1.8), -0.4)
	var l := _candelabra(r, Vector3(11.1, 0.86, 1.4), 0.6, true)
	l.light_color = Color(1.0, 0.45, 0.3)
	_candelabra(r, Vector3(9.8, 0.86, 1.3), 0.3, true)
	# Aurèle, mort à son bureau.
	PropFactory.chair(b, r, PropFactory.at(Vector3(10.5, 0, 2.55), PI), "wood_black", "leather")
	_skeleton(r, Vector3(10.5, 0.5, 2.5), PI)
	PropFactory.crate(b, r, Vector3(11.3, 0, 7.8), 0.6, 0.3)
	_pickup(r, "battery", "bat_secret", Vector3(11.3, 0.61, 7.8), 0.3)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(11.67, 0, 5.2), -PI * 0.5), 1.6, 2.4, 0.35, 5)
	b.cyl(r, "iron_black", Vector3(10.5, 0, 6.5), 0.4, 0.4, 0.02, 16)
	var ring := _light(r, Vector3(10.5, 0.5, 6.5), WARM, 0.45, 6.0, FlickerLight.Mode.CANDLE, "none")
	for k: int in range(5):
		var a := TAU * float(k) / 5.0
		var cp := Vector3(10.5 + cos(a) * 0.6, 0, 6.5 + sin(a) * 0.6)
		PropFactory.candle_stick(b, r, cp, 0.14)
		ring.glow_nodes.append(_flame(r, cp + Vector3(0, 0.26, 0), 0.9))


func _skeleton(r: String, seat: Vector3, rot: float) -> void:
	var xf := PropFactory.at(seat, rot)
	var bn := "bone"
	b.sphere(r, bn, xf * Vector3(0, 0.78, -0.02), Vector3(0.09, 0.11, 0.1), Color(0.8, 0.78, 0.7))
	b.sphere(r, "black", xf * Vector3(0.03, 0.8, 0.075), Vector3(0.022, 0.022, 0.015))
	b.sphere(r, "black", xf * Vector3(-0.03, 0.8, 0.075), Vector3(0.022, 0.022, 0.015))
	b.box_xf(r, bn, Transform3D(xf.basis * Basis(Vector3.RIGHT, 0.4), xf * Vector3(0, 0.69, 0.05)), Vector3(0.08, 0.03, 0.06), false)
	b.cyl_xf(r, bn, Transform3D(xf.basis * Basis(Vector3.RIGHT, 0.25), xf * Vector3(0, 0.1, -0.12)), 0.018, 0.018, 0.55, 5)
	for i: int in range(4):
		b.cyl_xf(r, bn, Transform3D(xf.basis * Basis(Vector3.RIGHT, 0.25), xf * Vector3(0, 0.3 + float(i) * 0.07, -0.06)), 0.12 - float(i) * 0.012, 0.11 - float(i) * 0.012, 0.015, 8, Color(0.85, 0.82, 0.72))
	b.box(r, bn, xf * Vector3(0, 0.05, -0.1), Vector3(0.24, 0.1, 0.12), rot, false)
	for s: int in range(2):
		var sx := 0.09 * (1.0 if s == 0 else -1.0)
		b.cyl_xf(r, bn, Transform3D(xf.basis * Basis(Vector3.RIGHT, PI * 0.5), xf * Vector3(sx, 0.02, -0.08)), 0.02, 0.02, 0.42, 5)
		b.cyl_xf(r, bn, Transform3D(xf.basis, xf * Vector3(sx, -0.45, 0.35)), 0.017, 0.017, 0.45, 5)
		b.cyl_xf(r, bn, Transform3D(xf.basis * Basis(Vector3.RIGHT, 2.4), xf * Vector3(sx * 1.8, 0.62, -0.05)), 0.015, 0.015, 0.3, 5)
		b.cyl_xf(r, bn, Transform3D(xf.basis * Basis(Vector3.RIGHT, 1.6), xf * Vector3(sx * 1.8, 0.4, 0.15)), 0.013, 0.013, 0.28, 5)


# ============================================================ bureau

func _study() -> void:
	var r := "study"
	PropFactory.rug(b, r, Vector3(15.5, 0, 4.2), 3.6, 3.0, 0.0, "rug_blue")
	PropFactory.desk(b, r, PropFactory.at(Vector3(15.5, 0, 3.0)), 1.8, "wood_dark")
	PropFactory.chair(b, r, PropFactory.at(Vector3(15.5, 0, 3.75), PI), "wood_dark", "leather")
	_note(r, "aurele_veille", "book", Vector3(15.2, 0.8, 2.9), 0.2)
	_note(r, "aurele_coffre", "paper", Vector3(16.0, 0.79, 3.1), -0.5)
	_pickup(r, "battery", "bat_study", Vector3(14.9, 0.79, 3.2), 1.0)
	b.cyl(r, "brass", Vector3(16.3, 0.78, 2.8), 0.08, 0.08, 0.02, 8)
	b.cyl(r, "brass", Vector3(16.3, 0.8, 2.8), 0.012, 0.012, 0.35, 6)
	b.cyl(r, "fabric_green", Vector3(16.3, 1.05, 2.8), 0.16, 0.08, 0.16, 10)
	_light(r, Vector3(16.3, 1.0, 2.8), WARM, 1.4, 8.5, FlickerLight.Mode.FAULTY, "none")
	_moonlight(r, Vector3(15.5, 2.1, 1.1), 0.8, 7.5)
	_sconce(r, Vector3(18.875, 2.1, 1.9), Vector3(-1, 0, 0))
	var safe := Safe.new()
	safe.setup("1403")
	_add(r, safe, Vector3(18.2, 0, 0.125 + 0.3), 0.0)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(12.33, 0, 2.5), PI * 0.5), 3.0, 2.8, 0.4, 6)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(12.33, 0, 6.5), PI * 0.5), 3.0, 2.8, 0.4, 6)
	PropFactory.bookshelf(b, r, PropFactory.at(Vector3(18.67, 0, 4.6), -PI * 0.5), 2.6, 2.8, 0.4, 6)
	_hide(r, "closet", Vector3(17.8, 0, 8.875 - 0.31), PI, "wood_dark", "", 0.95)
	PropFactory.armchair(b, r, PropFactory.at(Vector3(13.6, 0, 7.4), PI * 0.75), "leather", "wood_dark")
	_portrait(r, Vector3(18.875, 1.9, 7.2), Vector3(-1, 0, 0), 0.7, 0.9, "portrait_a")
	b.cyl(r, "wood_dark", Vector3(17.9, 0, 6.8), 0.18, 0.05, 0.7, 8)
	b.sphere(r, "paper", Vector3(17.9, 0.98, 6.8), Vector3(0.25, 0.25, 0.25), Color(0.62, 0.55, 0.4), 12, 8)


# ============================================================ chapelle

func _chapel() -> void:
	var r := "chapel"
	PropFactory.altar(b, r, PropFactory.at(Vector3(23, 0, 1.4)))
	var puzzle := CandlePuzzle.new()
	_add(r, puzzle, Vector3(23, 0, 1.4))
	puzzle.setup_altar(1.1)
	var roles: Array[String] = ["enfant", "pere", "mere"]
	var labels: Array[String] = ["L'ENFANT", "LE PÈRE", "LA MÈRE"]
	var pos: Array[Vector3] = [Vector3(21.3, 0, 3.0), Vector3(23.0, 0, 3.35), Vector3(24.7, 0, 3.0)]
	for i: int in range(3):
		var c := Candle.new()
		c.setup(roles[i], labels[i], puzzle)
		_add(r, c, pos[i], 0.0)
		puzzle.add_candle(c)
	puzzle.apply_saved_state()
	PropFactory.lectern(b, r, PropFactory.at(Vector3(26.2, 0, 3.8), -0.6))
	_note(r, "madeleine_cierges", "book", Vector3(26.2, 1.14, 3.8), -0.6)
	for row: float in [4.9, 6.2]:
		PropFactory.pew(b, r, PropFactory.at(Vector3(21.2, 0, row), PI), 2.0)
		PropFactory.pew(b, r, PropFactory.at(Vector3(24.8, 0, row), PI), 2.0)
	_hide(r, "confessional", Vector3(19.125 + 0.5, 0, 6.6), PI * 0.5, "wood_dark", "fabric_red")
	# Lampe de sanctuaire rouge, très faible.
	b.cyl(r, "iron_black", Vector3(25.2, 3.4, 1.2), 0.01, 0.01, 1.6, 4)
	b.cyl(r, "glass_stained", Vector3(25.2, 3.25, 1.2), 0.06, 0.08, 0.15, 8, false, Color(1.2, 0.2, 0.2))
	_light(r, Vector3(25.2, 3.2, 1.2), Color(1.0, 0.25, 0.2), 0.9, 8.0, FlickerLight.Mode.CANDLE, "none")
	# Lune filtrée par le vitrail (teinte violette) et deux grands cierges à l'entrée.
	var sg := _moonlight(r, Vector3(23.0, 3.2, 1.3), 0.8, 9.0)
	sg.light_color = Color(0.62, 0.55, 1.0)
	_cierge(r, Vector3(20.6, 0, 8.2), 0.85)
	_cierge(r, Vector3(25.4, 0, 8.2), 0.85)
	world.anchors["chapel_altar"] = Vector3(23.0, 0.16, 2.35)
	_portrait(r, Vector3(19.125, 2.6, 3.0), Vector3(1, 0, 0), 0.8, 1.1, "portrait_c")


# ============================================================ chambre des maîtres et salle de bain

func _master() -> void:
	var r := "master"
	PropFactory.rug(b, r, Vector3(33.0, 0, 2.2), 3.4, 2.8, 0.0, "rug")
	_hide(r, "bed", Vector3(33.0, 0, 0.125 + 1.05), -PI * 0.5, "wood_dark", "fabric_blue")
	PropFactory.nightstand(b, r, PropFactory.at(Vector3(31.85, 0, 0.42)), "wood_dark")
	PropFactory.nightstand(b, r, PropFactory.at(Vector3(34.15, 0, 0.42)), "wood_dark")
	_pickup(r, "battery", "bat_master", Vector3(31.85, 0.6, 0.4), 0.5)
	b.cyl(r, "brass", Vector3(34.15, 0.6, 0.4), 0.07, 0.05, 0.05, 8)
	b.cyl(r, "glass_stained", Vector3(34.15, 0.65, 0.4), 0.06, 0.05, 0.16, 8, false, Color(1.5, 1.2, 0.8))
	_light(r, Vector3(34.15, 0.95, 0.5), WARM, 1.2, 8.0, FlickerLight.Mode.CANDLE, "flame")
	_moonlight(r, Vector3(30.5, 2.1, 1.1), 0.9, 8.0)
	_sconce(r, Vector3(27.125, 2.1, 2.3), Vector3(1, 0, 0), FlickerLight.Mode.CANDLE, 1.0)
	_hide(r, "wardrobe", Vector3(27.125 + 0.31, 0, 4.5), PI * 0.5, "wood_dark")
	# Armoire du pendu (screamer).
	var wx := 37.875 - 0.31
	_static_wardrobe(r, Vector3(wx, 0, 7.0), -PI * 0.5)
	var wscare := _examine(r, "Ouvrir l'armoire", "", Vector3(wx, 0, 7.0), -PI * 0.5, Vector3(1.2, 2.1, 0.7), Vector3(0, 1.05, 0.05))
	wscare.scare_trigger = "wardrobe_master"
	var body := Node3D.new()
	wscare.add_child(body)
	body.position = Vector3(0, 0.05, 0.1)
	var bb := MeshBatcher.new()
	bb.add_box("sheet", Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)), Vector3(0.45, 1.6, 0.3), Color(0.6, 0.58, 0.55))
	bb.add_sphere("sheet", Vector3(0, 1.85, 0), Vector3(0.14, 0.17, 0.14), Color(0.6, 0.58, 0.55))
	bb.add_box("mouth", Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0.16)), Vector3(0.3, 0.5, 0.01), Color(0.6, 0.2, 0.2))
	var bmi := MeshInstance3D.new()
	bmi.mesh = bb.build(func(k: String) -> Material: return Assets.mat(k))
	body.add_child(bmi)
	body.visible = false
	wscare.visual_kind = "falling_body"
	wscare.visual_nodes.append(body)
	wscare.message = "Il y a quelque chose dans l'armoire..."
	wscare.one_shot_message = true
	PropFactory.dresser(b, r, PropFactory.at(Vector3(34.5, 0, 8.62), PI), 1.4, 0.9, "wood_dark")
	_note(r, "madeleine_journal_2", "book", Vector3(34.3, 0.92, 8.55), 0.3)
	_candle(r, Vector3(35.0, 0.9, 8.55), 0.9, 7.5)
	b.box(r, "mirror", Vector3(34.5, 1.65, 8.84), Vector3(0.8, 0.9, 0.02), 0.0, false)
	b.box(r, "gold_frame", Vector3(34.5, 1.65, 8.855), Vector3(0.9, 1.0, 0.02), 0.0, false)
	PropFactory.armchair(b, r, PropFactory.at(Vector3(36.6, 0, 1.6), -PI * 0.7), "fabric_blue", "wood_dark")
	_portrait(r, Vector3(27.125, 1.9, 7.4), Vector3(1, 0, 0), 0.7, 0.95, "portrait_c")


func _static_wardrobe(r: String, pos: Vector3, rot: float) -> void:
	var xf := PropFactory.at(pos, rot)
	PropFactory._bx(b, r, "wood_dark", xf, Vector3(0, 1.075, 0), Vector3(1.2, 2.15, 0.62), Color(0.85, 0.85, 0.85), false, 0.7)
	PropFactory._bx(b, r, "wood_dark", xf, Vector3(0, 2.2, 0.02), Vector3(1.3, 0.1, 0.7))
	PropFactory._bx(b, r, "wood_dark", xf, Vector3(-0.29, 1.1, 0.315), Vector3(0.56, 1.9, 0.02), Color(0.7, 0.7, 0.7))
	PropFactory._bx(b, r, "wood_dark", xf, Vector3(0.29, 1.1, 0.315), Vector3(0.56, 1.9, 0.02), Color(0.7, 0.7, 0.7))
	PropFactory._bx(b, r, "brass", xf, Vector3(-0.05, 1.1, 0.33), Vector3(0.03, 0.12, 0.02), Color.WHITE)
	PropFactory._bx(b, r, "brass", xf, Vector3(0.05, 1.1, 0.33), Vector3(0.03, 0.12, 0.02), Color.WHITE)
	PropFactory._solid(b, r, xf, Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 0.62))


func _bath() -> void:
	var r := "bath"
	PropFactory.bathtub(b, r, PropFactory.at(Vector3(41.0, 0, 0.55)))
	PropFactory.washbasin(b, r, PropFactory.at(Vector3(43.6, 0, 7.0), -PI * 0.5))
	# Miroir terni (screamer).
	b.box(r, "gold_frame", Vector3(43.85, 1.65, 7.0), Vector3(0.03, 0.85, 0.65), 0.0, false)
	b.box(r, "mirror", Vector3(43.83, 1.65, 7.0), Vector3(0.02, 0.75, 0.55), 0.0, false)
	var mirror := _examine(r, "Se regarder dans le miroir", "Un miroir terni. Mon reflet est à peine visible...", Vector3(43.7, 1.65, 7.0), -PI * 0.5, Vector3(0.7, 0.8, 0.2))
	mirror.scare_trigger = "mirror_bath"
	mirror.one_shot_message = true
	var face := Node3D.new()
	mirror.add_child(face)
	face.position = Vector3(0.0, -0.12, 0.05)
	face.rotation.y = PI
	MonsterBody.build_head(face)
	var fl := OmniLight3D.new()
	fl.light_energy = 0.8
	fl.omni_range = 0.8
	fl.light_color = Color(0.8, 0.85, 1.0)
	fl.position = Vector3(0, 0.12, -0.3)
	face.add_child(fl)
	face.visible = false
	mirror.visual_nodes.append(face)
	b.box(r, "brass", Vector3(38.3, 1.3, 2.0), Vector3(0.04, 0.03, 0.9), 0.0, false)
	b.box(r, "sheet", Vector3(38.3, 1.0, 2.0), Vector3(0.03, 0.6, 0.5), 0.0, false, Color(0.7, 0.66, 0.6))
	_note(r, "note_victime", "paper", Vector3(39.4, 0.005, 1.4), 1.2)
	b.box(r, "mouth", Vector3(40.1, 0.004, 1.5), Vector3(0.6, 0.004, 0.35), 0.4, false, Color(0.5, 0.1, 0.1))
	PropFactory.rug(b, r, Vector3(41.0, 0, 3.0), 1.6, 0.9, 0.0, "rug_blue")
	_light(r, Vector3(41.0, 2.8, 5.0), BULB, 0.45, 7.5, FlickerLight.Mode.FAULTY)
	_moonlight(r, Vector3(43.1, 2.0, 4.5), 0.4, 6.5)
	_sconce(r, Vector3(43.875, 2.0, 7.9), Vector3(-1, 0, 0), FlickerLight.Mode.CANDLE, 0.5)


# ============================================================ galerie et couloirs

func _gallery() -> void:
	var r := "gallery"
	PropFactory.runner(b, r, Vector3(0.6, 0, 10.5), Vector3(43.4, 0, 10.5), 1.25)
	var north: Array[float] = [9.5, 19.5, 26.5, 33.5]
	var mats: Array[String] = ["portrait_a", "portrait_b", "portrait_c"]
	for i: int in range(north.size()):
		if north[i] == 19.5:
			continue
		_portrait(r, Vector3(north[i], 1.9, 9.125), Vector3(0, 0, 1), 0.7, 0.9, mats[i % 3])
	var south: Array[float] = [2.5, 9.5, 17.5, 26.5, 34.5, 41.5]
	for i: int in range(south.size()):
		_portrait(r, Vector3(south[i], 1.9, 11.875), Vector3(0, 0, -1), 0.7, 0.9, mats[(i + 1) % 3])
	# Portrait hanté (screamer au premier examen).
	var pscare := _examine(r, "Examiner le portrait", "« Gaspard Moreau, au service de la famille. 1912. »", Vector3(19.5, 1.9, 9.2), 0.0, Vector3(0.9, 1.1, 0.15))
	pscare.scare_trigger = "portrait_gallery"
	var canvas := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.9)
	canvas.mesh = q
	q.material = Assets.mat("portrait_b")
	pscare.add_child(canvas)
	canvas.position = Vector3(0, 0, -0.035)
	pscare.visual_nodes.append(canvas)
	PropFactory.portrait(b, r, Vector3(19.5, 1.9, 9.125), Vector3(0, 0, 1), 0.7, 0.9, "black")
	# Consoles.
	PropFactory.table(b, r, PropFactory.at(Vector3(9.5, 0, 9.33)), 1.2, 0.4, 0.85, "wood_dark")
	PropFactory.vase(b, r, Vector3(9.2, 0.85, 9.33))
	_pickup(r, "battery", "bat_gallery", Vector3(9.8, 0.855, 9.35), 0.4)
	PropFactory.table(b, r, PropFactory.at(Vector3(34.5, 0, 11.67)), 1.2, 0.4, 0.85, "wood_dark")
	PropFactory.candle_stick(b, r, Vector3(34.2, 0.85, 11.67))
	_candle(r, Vector3(34.2, 0.85, 11.67), 0.8, 6.5, false)
	_hide(r, "wardrobe", Vector3(36.5, 0, 9.125 + 0.31), 0.0, "wood_dark")
	_sconce(r, Vector3(2.5, 2.2, 9.125), Vector3(0, 0, 1))
	_sconce(r, Vector3(11.0, 2.2, 11.875), Vector3(0, 0, -1))
	_sconce(r, Vector3(19.0, 2.2, 11.875), Vector3(0, 0, -1), FlickerLight.Mode.CANDLE, 1.0)
	_sconce(r, Vector3(27.5, 2.2, 9.125), Vector3(0, 0, 1), FlickerLight.Mode.FAULTY, 1.2)
	_sconce(r, Vector3(33.0, 2.2, 11.875), Vector3(0, 0, -1))
	_sconce(r, Vector3(39.5, 2.2, 11.875), Vector3(0, 0, -1))
	_moonlight(r, Vector3(0.9, 2.1, 10.5), 0.8, 7.0)
	_moonlight(r, Vector3(43.1, 2.1, 10.5), 0.8, 7.0)


func _corridors() -> void:
	PropFactory.runner(b, "wcorr", Vector3(13.5, 0, 12.3), Vector3(13.5, 0, 29.6), 1.0)
	PropFactory.runner(b, "ecorr", Vector3(30.5, 0, 12.3), Vector3(30.5, 0, 29.6), 1.0)
	_hide("wcorr", "wardrobe", Vector3(14.875 - 0.31, 0, 27.4), -PI * 0.5, "wood_dark")
	_sconce("wcorr", Vector3(12.125, 2.2, 21.0), Vector3(1, 0, 0), FlickerLight.Mode.CANDLE, 1.1)
	_sconce("wcorr", Vector3(14.875, 2.2, 16.4), Vector3(-1, 0, 0))
	_sconce("wcorr", Vector3(12.125, 2.2, 27.6), Vector3(1, 0, 0), FlickerLight.Mode.FAULTY, 1.1)
	_moonlight("wcorr", Vector3(13.5, 2.0, 29.1), 0.7, 6.5)
	_sconce("ecorr", Vector3(31.875, 2.2, 21.5), Vector3(-1, 0, 0), FlickerLight.Mode.FAULTY, 1.1)
	_sconce("ecorr", Vector3(29.125, 2.2, 16.6), Vector3(1, 0, 0))
	_moonlight("ecorr", Vector3(30.5, 2.0, 29.1), 0.7, 6.5)
	_portrait("wcorr", Vector3(14.875, 1.9, 15.0), Vector3(-1, 0, 0), 0.6, 0.8, "portrait_c")
	_portrait("ecorr", Vector3(29.125, 1.9, 15.0), Vector3(1, 0, 0), 0.6, 0.8, "portrait_a")
	_portrait("ecorr", Vector3(29.125, 1.9, 27.0), Vector3(1, 0, 0), 0.6, 0.8, "portrait_b")
	PropFactory.table(b, "wcorr", PropFactory.at(Vector3(12.33, 0, 13.8), PI * 0.5), 0.9, 0.36, 0.85, "wood_dark")
	PropFactory.vase(b, "wcorr", Vector3(12.33, 0.85, 13.8))
	PropFactory.table(b, "ecorr", PropFactory.at(Vector3(31.67, 0, 23.8), -PI * 0.5), 0.9, 0.36, 0.85, "wood_dark")
	PropFactory.candle_stick(b, "ecorr", Vector3(31.67, 0.85, 23.8))
	_candle("ecorr", Vector3(31.67, 0.85, 23.8), 0.8, 6.5, false)


# ============================================================ grand hall

func _hall() -> void:
	var r := "hall"
	PropFactory.runner(b, r, Vector3(22, 0, 29.7), Vector3(22, 0, 22.3), 1.8)
	# Grand escalier central effondré (bloc maçonné, marches, rampe).
	var x0 := 20.5
	var x1 := 23.5
	var steps := 19
	var run := 0.4
	for i: int in range(steps):
		var z_front := 22.0 - float(i) * run
		var top := 0.2 * float(i + 1)
		var broken := i >= 8 and i <= 12
		if broken:
			top -= 0.35 + 0.25 * float((i * 7) % 3)
		b.box(r, "marble_white", Vector3((x0 + x1) * 0.5, top * 0.5, z_front - run * 0.5), Vector3(x1 - x0, top, run), 0.0, false, Color(0.55, 0.52, 0.5), false, 0.7)
		if not broken:
			b.box(r, "fabric_red", Vector3((x0 + x1) * 0.5, top + 0.005, z_front - run * 0.5), Vector3(1.6, 0.012, run), 0.0, false, Color(0.7, 0.7, 0.7))
	PropFactory.rubble(b, r, Vector3(22.0, 1.7, 17.8), 1.0, 14, 7)
	for side: int in range(2):
		var sx := x0 + 0.08 if side == 0 else x1 - 0.08
		for i: int in range(0, steps, 2):
			if i >= 7 and i <= 13:
				continue
			var z := 22.0 - float(i) * run - run * 0.5
			var y := 0.2 * float(i + 1)
			b.box(r, "wood_dark", Vector3(sx, y + 0.45, z), Vector3(0.05, 0.9, 0.05), 0.0, false)
		var rail_len := 8.0 * run
		var ang := atan2(0.2, run)
		b.box_xf(r, "wood_dark", Transform3D(Basis(Vector3.RIGHT, ang), Vector3(sx, 0.2 * 4.0 + 0.95, 22.0 - 3.5 * run)), Vector3(0.08, 0.07, rail_len + 0.3), false)
		b.box_xf(r, "wood_dark", Transform3D(Basis(Vector3.RIGHT, ang), Vector3(sx, 0.2 * 16.5 + 0.95, 22.0 - 16.5 * run)), Vector3(0.08, 0.07, 4.0 * run + 0.3), false)
		b.cyl(r, "wood_dark", Vector3(sx, 0, 21.85), 0.09, 0.08, 1.25, 8)
		b.sphere(r, "wood_dark", Vector3(sx, 1.3, 21.85), Vector3(0.1, 0.1, 0.1))
	b.collider(r, Vector3((x0 + x1) * 0.5, 1.2, (22.0 + 14.4) * 0.5), Vector3(x1 - x0, 2.4, 22.0 - 14.4))
	# Palier / balcon du premier étage (inaccessible).
	var bal_z0 := 12.125
	var bal_z1 := 14.4
	b.box(r, "marble_white", Vector3(22.0, 3.7, (bal_z0 + bal_z1) * 0.5), Vector3(13.75, 0.2, bal_z1 - bal_z0), 0.0, true, Color(0.5, 0.48, 0.46))
	b.box(r, "wood_dark", Vector3(22.0, 3.58, bal_z1 - 0.05), Vector3(13.75, 0.1, 0.1), 0.0, false)
	var px := 15.3
	while px < 28.8:
		if px < x0 - 0.05 or px > x1 + 0.05:
			b.box(r, "wood_dark", Vector3(px, 4.25, bal_z1 - 0.06), Vector3(0.05, 0.9, 0.05), 0.0, false)
		px += 0.3
	b.box(r, "wood_dark", Vector3(17.8, 4.72, bal_z1 - 0.06), Vector3(5.2, 0.07, 0.1), 0.0, false)
	b.box(r, "wood_dark", Vector3(26.2, 4.72, bal_z1 - 0.06), Vector3(5.2, 0.07, 0.1), 0.0, false)
	for cx: float in [18.0, 26.0]:
		b.cyl(r, "marble_white", Vector3(cx, 0, 14.2), 0.18, 0.16, 3.6, 10, true, Color(0.6, 0.58, 0.55))
	# Portes factices de l'étage.
	for dx: float in [17.5, 26.5]:
		b.box(r, "wood_black", Vector3(dx, 4.95, 12.14), Vector3(1.1, 2.3, 0.03), 0.0, false)
		b.box(r, "trim", Vector3(dx, 6.15, 12.15), Vector3(1.3, 0.12, 0.05), 0.0, false)
	# Lustre principal (quelques bougies encore allumées).
	b.cyl(r, "iron_black", Vector3(22, 5.2, 25.5), 0.02, 0.02, 1.8, 4)
	b.cyl(r, "brass", Vector3(22, 5.1, 25.5), 0.9, 0.8, 0.08, 16)
	b.cyl(r, "brass", Vector3(22, 5.25, 25.5), 0.5, 0.45, 0.06, 12)
	var cl := _light(r, Vector3(22, 4.8, 25.5), WARM, 2.0, 15.0, FlickerLight.Mode.CANDLE, "none")
	cl.priority = 0.7
	# Lune par les deux hautes fenêtres de la façade, appliques le long des murs.
	_moonlight(r, Vector3(17.5, 2.6, 28.9), 1.0, 9.0)
	_moonlight(r, Vector3(26.5, 2.6, 28.9), 1.0, 9.0)
	_sconce(r, Vector3(15.125, 2.5, 23.6), Vector3(1, 0, 0))
	_sconce(r, Vector3(28.875, 2.5, 24.9), Vector3(-1, 0, 0), FlickerLight.Mode.FAULTY, 1.2)
	_sconce(r, Vector3(15.125, 2.4, 14.4), Vector3(1, 0, 0), FlickerLight.Mode.CANDLE, 1.0)
	_sconce(r, Vector3(28.875, 2.4, 15.2), Vector3(-1, 0, 0), FlickerLight.Mode.CANDLE, 1.0)
	for k: int in range(8):
		var a := TAU * float(k) / 8.0
		var cp := Vector3(22 + cos(a) * 0.85, 5.18, 25.5 + sin(a) * 0.85)
		b.cyl(r, "wax", cp, 0.02, 0.02, 0.12, 6)
		if k % 3 != 0:
			cl.glow_nodes.append(_flame(r, cp + Vector3(0, 0.17, 0), 1.0))
	# Lustre tombé.
	b.cyl(r, "brass", Vector3(26.4, 0.02, 17.4), 0.8, 0.8, 0.06, 14, false, Color(0.5, 0.45, 0.35))
	PropFactory.rubble(b, r, Vector3(26.4, 0.0, 17.4), 0.9, 10, 21)
	PropFactory.grandfather_clock(b, r, PropFactory.at(Vector3(15.33, 0, 26.0), PI * 0.5))
	world.anchors["hall_clock"] = Vector3(15.5, 2.0, 26.0)
	PropFactory.suit_of_armor(b, r, PropFactory.at(Vector3(28.55, 0, 26.0), -PI * 0.5))
	PropFactory.suit_of_armor(b, r, PropFactory.at(Vector3(28.55, 0, 23.8), -PI * 0.5))
	PropFactory.sheet_furniture(b, r, PropFactory.at(Vector3(16.1, 0, 16.5), PI * 0.5), 1.8, 0.9, 0.6)
	PropFactory.sheet_furniture(b, r, PropFactory.at(Vector3(27.9, 0, 17.8), -PI * 0.5), 1.4, 1.2, 0.7)
	_portrait(r, Vector3(15.125, 2.4, 17.0), Vector3(1, 0, 0), 1.2, 1.6, "portrait_a")
	_portrait(r, Vector3(28.875, 2.6, 20.0), Vector3(-1, 0, 0), 1.2, 1.6, "portrait_c")
	_portrait(r, Vector3(22.0, 5.4, 12.14), Vector3(0, 0, 1), 1.6, 1.2, "portrait_b")
	# Porte-manteau près de l'entrée.
	b.cyl(r, "wood_dark", Vector3(19.4, 0, 29.4), 0.2, 0.03, 1.9, 8)
	b.box(r, "cloth_black", Vector3(19.4, 1.4, 29.45), Vector3(0.4, 0.8, 0.12), 0.2, false)
	PropFactory.vase(b, r, Vector3(24.6, 0, 29.45), 0.7)
	_hide(r, "closet", Vector3(x0 - 0.31, 0, 17.6), -PI * 0.5, "wood_dark", "", 0.95)
	world.anchors["hall_center"] = Vector3(22, 0, 25)


# ============================================================ salon

func _salon() -> void:
	var r := "salon"
	PropFactory.rug(b, r, Vector3(41.2, 0, 17.0), 3.4, 4.2, 0.0, "rug")
	var fp := Fireplace.new()
	fp.setup()
	_add(r, fp, Vector3(43.875, 0, 17.0), -PI * 0.5)
	PropFactory.sofa(b, r, PropFactory.at(Vector3(40.4, 0, 17.0), PI * 0.5), 2.2, "fabric_green", "wood_dark")
	PropFactory.armchair(b, r, PropFactory.at(Vector3(41.9, 0, 14.4), PI * 0.5 + 0.9), "fabric_green", "wood_dark")
	PropFactory.armchair(b, r, PropFactory.at(Vector3(41.9, 0, 19.6), PI * 0.5 - 0.9), "fabric_green", "wood_dark")
	PropFactory.round_table(b, r, PropFactory.at(Vector3(41.95, 0, 17.0)), 0.35, 0.5, "wood_dark")
	b.cyl(r, "porcelain", Vector3(41.9, 0.5, 17.1), 0.06, 0.05, 0.08, 8)
	PropFactory.grand_piano(b, r, PropFactory.at(Vector3(34.9, 0, 14.9), 0.35))
	_examine(r, "Examiner le piano", "Une touche est restée enfoncée. Quelqu'un jouait ici.", Vector3(34.8, 1.0, 15.45), 0.35, Vector3(1.4, 0.3, 0.3))
	PropFactory.round_table(b, r, PropFactory.at(Vector3(39.4, 0, 19.6)), 0.3, 0.65, "wood_dark")
	_note(r, "madeleine_journal_1", "book", Vector3(39.4, 0.66, 19.6), 0.6)
	b.cyl(r, "brass", Vector3(33.0, 0, 21.2), 0.18, 0.03, 1.55, 8)
	b.cyl(r, "fabric_cream", Vector3(33.0, 1.5, 21.2), 0.28, 0.16, 0.3, 10, false, Color(0.9, 0.8, 0.6))
	_floor_lamp(r, Vector3(32.7, 0, 21.25))
	_candelabra(r, Vector3(32.45, 0.94, 13.9), 1.2)
	_moonlight(r, Vector3(43.1, 2.2, 13.8), 0.8, 7.5)
	_moonlight(r, Vector3(43.1, 2.2, 20.2), 0.8, 7.5)
	_hide(r, "closet", Vector3(35.6, 0, 21.875 - 0.31), PI, "wood_med", "", 0.95)
	_portrait(r, Vector3(43.5, 2.3, 17.0), Vector3(-1, 0, 0), 0.7, 0.9, "portrait_c")
	PropFactory.sheet_furniture(b, r, PropFactory.at(Vector3(37.8, 0, 21.4), PI), 1.6, 0.9, 0.6)
	PropFactory.sideboard(b, r, PropFactory.at(Vector3(32.4, 0, 13.6), PI * 0.5), 1.8, "wood_dark")


# ============================================================ chambre de Lise

func _lise() -> void:
	var r := "lise"
	PropFactory.rug(b, r, Vector3(35.0, 0, 26.2), 2.6, 2.2, 0.2, "rug_blue")
	# Petit lit.
	var bxf := PropFactory.at(Vector3(36.95, 0, 23.05))
	PropFactory._bx(b, r, "wood_light", bxf, Vector3(0, 0.25, 0), Vector3(1.75, 0.3, 0.95), Color(0.9, 0.85, 0.85), false, 0.6)
	PropFactory._bx(b, r, "fabric_cream", bxf, Vector3(0, 0.45, 0), Vector3(1.65, 0.14, 0.85))
	PropFactory._bx(b, r, "fabric_pink", bxf, Vector3(-0.15, 0.53, 0), Vector3(1.3, 0.05, 0.95))
	PropFactory._bx(b, r, "fabric_cream", bxf, Vector3(0.62, 0.57, 0), Vector3(0.3, 0.1, 0.5))
	PropFactory._bx(b, r, "wood_light", bxf, Vector3(0.88, 0.6, 0), Vector3(0.05, 1.0, 0.95))
	PropFactory._bx(b, r, "wood_light", bxf, Vector3(-0.88, 0.45, 0), Vector3(0.05, 0.7, 0.95))
	PropFactory._solid(b, r, bxf, Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 0.95))
	# Table de chevet : carte d'anniversaire + veilleuse.
	PropFactory.nightstand(b, r, PropFactory.at(Vector3(37.55, 0, 24.1), -PI * 0.5), "wood_light")
	_note(r, "carte_anniversaire", "card", Vector3(37.5, 0.6, 24.0), -PI * 0.5)
	b.sphere(r, "glass_stained", Vector3(37.62, 0.68, 24.3), Vector3(0.07, 0.08, 0.07), Color(1.4, 1.0, 1.0))
	_light(r, Vector3(37.5, 0.8, 24.3), Color(1.0, 0.7, 0.75), 0.6, 6.0, FlickerLight.Mode.CANDLE, "none")
	_moonlight(r, Vector3(35.0, 2.0, 29.1), 0.6, 6.5)
	_hide(r, "wardrobe", Vector3(34.0, 0, 22.125 + 0.31), 0.0, "wood_light")
	# Boîte à musique.
	PropFactory.table(b, r, PropFactory.at(Vector3(36.9, 0, 29.4)), 0.8, 0.5, 0.62, "wood_light")
	var mb := MusicBox.new()
	mb.setup()
	_add(r, mb, Vector3(36.9, 0.62, 29.35), PI)
	_note(r, "etiquette_boite", "card", Vector3(36.55, 0.62, 29.4), PI)
	# Poupée sur sa chaise (screamer : elle tourne la tête).
	PropFactory.chair(b, r, PropFactory.at(Vector3(33.0, 0, 29.3), PI + 0.3), "wood_light", "fabric_pink")
	var doll := _examine(r, "Examiner la poupée", "Une poupée de porcelaine. Son visage est tourné vers la fenêtre.", Vector3(33.0, 0.5, 29.3), 0.3, Vector3(0.35, 0.5, 0.35), Vector3(0, 0.2, 0))
	doll.scare_trigger = "doll_look"
	var dn := Node3D.new()
	doll.add_child(dn)
	var db := MeshBatcher.new()
	db.add_cylinder("fabric_pink", Transform3D.IDENTITY, 0.12, 0.05, 0.25, 8)
	db.add_sphere("porcelain", Vector3(0, 0.33, 0), Vector3(0.075, 0.085, 0.075), Color(0.95, 0.92, 0.9))
	db.add_sphere("black", Vector3(0.028, 0.345, -0.065), Vector3(0.013, 0.015, 0.008))
	db.add_sphere("black", Vector3(-0.028, 0.345, -0.065), Vector3(0.013, 0.015, 0.008))
	db.add_box("mouth", Transform3D(Basis.IDENTITY, Vector3(0, 0.3, -0.07)), Vector3(0.03, 0.008, 0.005))
	db.add_sphere("wood_light", Vector3(0, 0.37, 0.02), Vector3(0.085, 0.07, 0.085), Color(0.9, 0.7, 0.3))
	var dmi := MeshInstance3D.new()
	dmi.mesh = db.build(func(k: String) -> Material: return Assets.mat(k))
	dn.add_child(dmi)
	dn.rotation.y = PI
	doll.visual_kind = "doll_turn"
	doll.visual_nodes.append(dn)
	_note(r, "dessin_lise", "drawing", Vector3(35.1, 0.014, 26.3), 0.4)
	# Jouets.
	for k: int in range(7):
		var mat := ["toy_red", "toy_blue", "toy_yellow"][k % 3] as String
		b.box(r, mat, Vector3(34.2 + float(k) * 0.23, 0.05, 27.0 + 0.2 * sin(float(k) * 2.0)), Vector3(0.1, 0.1, 0.1), float(k) * 0.7, false)
	var hxf := PropFactory.at(Vector3(33.3, 0, 23.7), 0.6)
	PropFactory._bx(b, r, "wood_light", hxf, Vector3(0, 0.55, 0), Vector3(0.25, 0.3, 0.7), Color(0.9, 0.9, 0.9))
	PropFactory._bx(b, r, "wood_light", hxf, Vector3(0, 0.78, -0.3), Vector3(0.18, 0.3, 0.16), Color(0.9, 0.9, 0.9))
	PropFactory._bx(b, r, "toy_red", hxf, Vector3(0, 0.05, 0), Vector3(0.1, 0.08, 1.0), Color(0.8, 0.8, 0.8))
	PropFactory._solid(b, r, hxf, Vector3(0, 0.45, 0), Vector3(0.3, 0.9, 1.0))
	# Dessins d'enfant au mur.
	for dz: float in [24.5, 27.8]:
		var c := Vector3(32.13, 1.35, dz)
		b.quad_uv(r, "drawing", c + Vector3(0, -0.2, 0.2), c + Vector3(0, -0.2, -0.2), c + Vector3(0, 0.2, -0.2), c + Vector3(0, 0.2, 0.2), Vector3(1, 0, 0))


# ============================================================ chambre de Gaspard

func _servant() -> void:
	var r := "servant"
	_hide(r, "bed", Vector3(38.125 + 0.75, 0, 29.875 - 1.05), PI * 0.5, "wood_raw", "fabric_cream")
	PropFactory.nightstand(b, r, PropFactory.at(Vector3(38.4, 0, 27.3), PI * 0.5), "wood_raw")
	var dr := _drawer(r, Vector3(38.62, 0.42, 27.3), PI * 0.5, 0.36, 0.12, 0.34, "wood_raw")
	var fuse := Pickup.new()
	fuse.setup("fuse", "fuse")
	dr.put_inside(fuse, Vector3(0, 0, 0.0))
	PropFactory.desk(b, r, PropFactory.at(Vector3(43.0, 0, 22.5)), 1.4, "wood_raw")
	PropFactory.chair(b, r, PropFactory.at(Vector3(43.0, 0, 23.2), PI), "wood_raw", "wood_raw")
	_note(r, "carnet_gaspard", "book", Vector3(42.8, 0.79, 22.45), 0.3)
	b.cyl(r, "brass", Vector3(43.5, 0.78, 22.4), 0.06, 0.05, 0.05, 8)
	b.cyl(r, "glass_stained", Vector3(43.5, 0.83, 22.4), 0.05, 0.04, 0.14, 8, false, Color(1.5, 1.2, 0.8))
	_light(r, Vector3(43.5, 1.05, 22.45), WARM, 0.7, 7.0, FlickerLight.Mode.CANDLE, "flame")
	_candle(r, Vector3(38.4, 0.59, 27.05), 0.6, 6.5)
	_moonlight(r, Vector3(43.1, 2.0, 26.0), 0.55, 6.5)
	PropFactory.washbasin(b, r, PropFactory.at(Vector3(43.6, 0, 28.6), -PI * 0.5))
	b.box(r, "wood_raw", Vector3(43.85, 1.8, 24.5), Vector3(0.04, 0.03, 1.0), 0.0, false)
	b.box(r, "cloth_black", Vector3(43.8, 1.4, 24.5), Vector3(0.05, 0.8, 0.5), 0.0, false)
	b.box(r, "wood_black", Vector3(40.5, 2.0, 29.86), Vector3(0.04, 0.35, 0.02), 0.0, false)
	b.box(r, "wood_black", Vector3(40.5, 2.08, 29.86), Vector3(0.22, 0.04, 0.02), 0.0, false)
	PropFactory.crate(b, r, Vector3(39.0, 0, 22.7), 0.5, 0.2)


# ============================================================ toiles d'araignée

func _cobwebs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for room: ManorLayout.RoomDef in world.layout.rooms:
		var y := room.floor_y + room.height - 0.02
		var x0 := room.rect.position.x + 0.13
		var x1 := room.rect.end.x - 0.13
		var z0 := room.rect.position.y + 0.13
		var z1 := room.rect.end.y - 0.13
		var corners: Array[Vector3] = [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
		var da: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
		var dbv: Array[Vector3] = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]
		for i: int in range(4):
			if rng.randf() < 0.6:
				PropFactory.cobweb(b, room.id, corners[i], da[i], dbv[i] + Vector3(0, -0.6, 0), rng.randf_range(0.45, 0.9))


# ============================================================ extérieur (visible à la fin)

func _exterior() -> void:
	var ext := Node3D.new()
	ext.name = "Exterior"
	world.add_child(ext)
	var bt := MeshBatcher.new()
	var gp: Array[Vector3] = [Vector3(-30, -0.03, -30), Vector3(74, -0.03, -30), Vector3(74, -0.03, 70), Vector3(-30, -0.03, 70)]
	var gc := Color(0.7, 0.7, 0.7)
	var gcols: Array[Color] = [gc, gc, gc, gc]
	bt.add_quad_world("ground", gp, Vector3.UP, gcols, Assets.uv_scale("ground"))
	bt.add_box("stone_dark", Transform3D(Basis.IDENTITY, Vector3(22, -0.1, 31.0)), Vector3(4.0, 0.2, 1.8), Color(0.6, 0.6, 0.6))
	bt.add_box("stone_dark", Transform3D(Basis.IDENTITY, Vector3(22, -0.25, 32.2)), Vector3(4.4, 0.2, 0.8), Color(0.55, 0.55, 0.55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i: int in range(18):
		var a := rng.randf() * TAU
		var d := rng.randf_range(10.0, 26.0)
		var p := Vector3(22 + cos(a) * d * 1.6, 0, 15 + sin(a) * d * 1.2)
		if p.x > -3 and p.x < 47 and p.z > -3 and p.z < 33:
			continue
		PropFactory.tree(bt, p, rng.randf_range(6.0, 11.0), i)
	for k: int in range(9):
		var gx := 12.0 + float(k) * 2.5
		bt.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(gx, 0.8, 42.0)), Vector3(0.05, 1.6, 0.05))
	bt.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(22, 1.5, 42.0)), Vector3(20.0, 0.05, 0.05))
	var mi := MeshInstance3D.new()
	mi.mesh = bt.build(func(k: String) -> Material: return Assets.mat(k))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ext.add_child(mi)
	var moon := OmniLight3D.new()
	moon.light_color = COLD
	moon.light_energy = 0.6
	moon.omni_range = 14.0
	moon.position = Vector3(22, 4.0, 36.0)
	ext.add_child(moon)
	world.anchors["exit_outside"] = Vector3(22, 0, 35.0)
	world.exterior_light = moon
	moon.visible = false
