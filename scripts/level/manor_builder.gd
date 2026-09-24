class_name ManorBuilder
extends RefCounted
## Construit la géométrie statique du manoir à partir de ManorLayout :
## murs (découpés autour des ouvertures), sols, plafonds, plinthes, corniches, fenêtres,
## rais de lune, escalier de la cave. Chaque pièce = 1 MeshInstance3D (multi-surfaces) + 1 StaticBody3D.
## ManorContent ajoute ensuite le mobilier via box()/cyl()/sphere() dans les mêmes lots.

const T: float = 0.25
const HT: float = 0.125

const STYLES: Dictionary = {
	"library": {"floor": "floor_parquet_dark", "lower": "wainscot_dark", "upper": "wp_green", "ceiling": "ceiling_dark", "ws": 1.1, "base": true, "crown": true, "trim": "trim", "curtain": "fabric_green"},
	"secret": {"floor": "floor_planks", "lower": "secret_wall", "upper": "secret_wall", "ceiling": "ceiling_wood", "ws": 0.0, "base": false, "crown": false, "trim": "trim", "curtain": ""},
	"study": {"floor": "floor_parquet", "lower": "wainscot_dark", "upper": "wp_burgundy", "ceiling": "ceiling", "ws": 1.1, "base": true, "crown": true, "trim": "trim", "curtain": "fabric_red"},
	"chapel": {"floor": "floor_chapel", "lower": "stone_wall", "upper": "plaster_dirty", "ceiling": "ceiling_dark", "ws": 1.5, "base": false, "crown": true, "trim": "trim", "curtain": ""},
	"master": {"floor": "floor_parquet", "lower": "wainscot", "upper": "wp_blue", "ceiling": "ceiling", "ws": 1.0, "base": true, "crown": true, "trim": "trim", "curtain": "fabric_blue"},
	"bath": {"floor": "floor_bath", "lower": "tiles_wall", "upper": "plaster", "ceiling": "ceiling", "ws": 1.3, "base": false, "crown": true, "trim": "trim_white", "curtain": ""},
	"gallery": {"floor": "floor_parquet_dark", "lower": "wainscot_dark", "upper": "wp_red", "ceiling": "ceiling_dark", "ws": 1.1, "base": true, "crown": true, "trim": "trim", "curtain": "fabric_red"},
	"dining": {"floor": "floor_parquet", "lower": "wainscot", "upper": "wp_olive", "ceiling": "ceiling", "ws": 1.1, "base": true, "crown": true, "trim": "trim", "curtain": "fabric_red"},
	"kitchen": {"floor": "floor_tiles", "lower": "tiles_wall", "upper": "plaster_dirty", "ceiling": "ceiling_wood", "ws": 1.2, "base": false, "crown": false, "trim": "trim", "curtain": ""},
	"corridor": {"floor": "floor_parquet_dark", "lower": "wainscot_dark", "upper": "wp_red", "ceiling": "ceiling_dark", "ws": 1.1, "base": true, "crown": true, "trim": "trim", "curtain": ""},
	"hall": {"floor": "floor_marble", "lower": "wainscot_dark", "upper": "wp_gold", "ceiling": "ceiling_dark", "ws": 1.4, "base": true, "crown": true, "trim": "trim", "curtain": "fabric_red"},
	"salon": {"floor": "floor_parquet", "lower": "wainscot", "upper": "wp_teal", "ceiling": "ceiling", "ws": 1.0, "base": true, "crown": true, "trim": "trim", "curtain": "fabric_green"},
	"lise": {"floor": "floor_parquet", "lower": "wainscot_white", "upper": "wp_pink", "ceiling": "ceiling", "ws": 1.0, "base": true, "crown": true, "trim": "trim_white", "curtain": "fabric_pink"},
	"servant": {"floor": "floor_planks", "lower": "plaster_dirty", "upper": "plaster_dirty", "ceiling": "ceiling_wood", "ws": 0.0, "base": true, "crown": false, "trim": "trim", "curtain": "fabric_cream"},
	"cellar": {"floor": "floor_stone", "lower": "stone_wall", "upper": "stone_wall", "ceiling": "ceiling_stone", "ws": 0.0, "base": false, "crown": false, "trim": "trim", "curtain": ""},
}

const MOONLIT: Array[String] = ["w_hall_s1", "w_hall_s2", "w_gallery_w", "w_gallery_e", "w_dining_w1", "w_master_n1", "w_lise_s", "w_lib_w", "w_chapel", "w_salon_e2"]


class RoomNodes:
	var node: Node3D
	var batcher: MeshBatcher
	var body: StaticBody3D


class WallPiece:
	var a: float = 0.0
	var b: float = 0.0
	var neg: ManorLayout.RoomDef = null
	var pos: ManorLayout.RoomDef = null
	var op: ManorLayout.Opening = null


var layout: ManorLayout
var root: Node3D
var _rooms: Dictionary = {}
var _occluders: Array[Dictionary] = []


func _init(p_layout: ManorLayout, p_root: Node3D) -> void:
	layout = p_layout
	root = p_root
	for r: ManorLayout.RoomDef in layout.rooms:
		var rn := RoomNodes.new()
		rn.node = Node3D.new()
		rn.node.name = "Room_" + r.id
		root.add_child(rn.node)
		rn.batcher = MeshBatcher.new()
		rn.body = StaticBody3D.new()
		rn.body.name = "Static"
		rn.body.collision_layer = Layers.WORLD
		rn.body.collision_mask = 0
		rn.node.add_child(rn.body)
		_rooms[r.id] = rn


static func style(style_name: String) -> Dictionary:
	if STYLES.has(style_name):
		return STYLES[style_name] as Dictionary
	return STYLES["corridor"] as Dictionary


# ============================================================ API pour le mobilier

func batcher(room_id: String) -> MeshBatcher:
	return (_rooms[room_id] as RoomNodes).batcher


func room_node(room_id: String) -> Node3D:
	return (_rooms[room_id] as RoomNodes).node


func room_body(room_id: String) -> StaticBody3D:
	return (_rooms[room_id] as RoomNodes).body


## Boîte décorative (et solide si `solid`). `center` : centre de la boîte.
func box(room_id: String, mat: String, center: Vector3, size: Vector3, rot_y: float = 0.0, solid: bool = true, color: Color = Color.WHITE, face_uv: bool = false, ao: float = 0.8) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot_y), center)
	box_xf(room_id, mat, xf, size, solid, color, face_uv, ao)


func box_xf(room_id: String, mat: String, xf: Transform3D, size: Vector3, solid: bool = true, color: Color = Color.WHITE, face_uv: bool = false, ao: float = 0.8) -> void:
	batcher(room_id).add_box(mat, xf, size, color, Assets.uv_scale(mat), face_uv, MeshBatcher.FACE_ALL, ao)
	if solid:
		collider_xf(room_id, xf, size)


func cyl(room_id: String, mat: String, base: Vector3, r_bottom: float, r_top: float, height: float, segments: int = 10, solid: bool = false, color: Color = Color.WHITE) -> void:
	batcher(room_id).add_cylinder(mat, Transform3D(Basis.IDENTITY, base), r_bottom, r_top, height, segments, color, true, Assets.uv_scale(mat))
	if solid:
		var r := maxf(r_bottom, r_top)
		collider(room_id, base + Vector3(0, height * 0.5, 0), Vector3(r * 1.6, height, r * 1.6))


func cyl_xf(room_id: String, mat: String, xf: Transform3D, r_bottom: float, r_top: float, height: float, segments: int = 8, color: Color = Color.WHITE) -> void:
	batcher(room_id).add_cylinder(mat, xf, r_bottom, r_top, height, segments, color, true, Assets.uv_scale(mat))


func sphere(room_id: String, mat: String, center: Vector3, radii: Vector3, color: Color = Color.WHITE, segments: int = 10, rings: int = 6) -> void:
	batcher(room_id).add_sphere(mat, center, radii, color, segments, rings)


func collider(room_id: String, center: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	collider_xf(room_id, Transform3D(Basis(Vector3.UP, rot_y), center), size)


func collider_xf(room_id: String, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	room_body(room_id).add_child(cs)


## Quad avec UV 0..1 (tableaux, dessins, reflets...). Coins dans l'ordre du contour.
func quad_uv(room_id: String, mat: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, color: Color = Color.WHITE) -> void:
	var p: Array[Vector3] = [p0, p1, p2, p3]
	var uv: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var cols: Array[Color] = [color, color, color, color]
	batcher(room_id).add_quad(mat, p, n, uv, cols, (p1 - p0).normalized())


# ============================================================ construction

func build_structure() -> void:
	for level: float in layout.levels():
		var lrooms := layout.rooms_at_level(level)
		var zs: Dictionary = {}
		var xs: Dictionary = {}
		for r: ManorLayout.RoomDef in lrooms:
			zs[r.rect.position.y] = true
			zs[r.rect.end.y] = true
			xs[r.rect.position.x] = true
			xs[r.rect.end.x] = true
		for zv: Variant in zs.keys():
			_build_line(level, lrooms, true, float(zv))
		for xv: Variant in xs.keys():
			_build_line(level, lrooms, false, float(xv))
	for r: ManorLayout.RoomDef in layout.rooms:
		_build_floor_ceiling(r)
	_build_cellar_stairs()


## Crée les MeshInstance3D et les occulteurs. À appeler après l'ajout du mobilier.
func finalize() -> void:
	for id: Variant in _rooms.keys():
		var rn := _rooms[id] as RoomNodes
		if rn.batcher.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = rn.batcher.build(func(k: String) -> Material: return Assets.mat(k))
		rn.node.add_child(mi)
	for o: Dictionary in _occluders:
		var oi := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new()
		bo.size = o["size"] as Vector3
		oi.occluder = bo
		oi.position = o["center"] as Vector3
		var rid: String = o["room"]
		room_node(rid).add_child(oi)


# ------------------------------------------------------------ murs

func _build_line(level: float, lrooms: Array[ManorLayout.RoomDef], horizontal: bool, c: float) -> void:
	var intervals: Array[Vector2] = []
	var breaks: Array[float] = []
	for r: ManorLayout.RoomDef in lrooms:
		var lo_edge: float = r.rect.position.y if horizontal else r.rect.position.x
		var hi_edge: float = r.rect.end.y if horizontal else r.rect.end.x
		if is_equal_approx(lo_edge, c) or is_equal_approx(hi_edge, c):
			var a0: float = r.rect.position.x if horizontal else r.rect.position.y
			var b0: float = r.rect.end.x if horizontal else r.rect.end.y
			intervals.append(Vector2(a0, b0))
			breaks.append(a0)
			breaks.append(b0)
	var ops := layout.openings_on_line(level, horizontal, c)
	for o: ManorLayout.Opening in ops:
		breaks.append(o.a())
		breaks.append(o.b())
	breaks.sort()
	var ub: Array[float] = []
	for v: float in breaks:
		if ub.is_empty() or v - ub[ub.size() - 1] > 0.001:
			ub.append(v)
	var pieces: Array[WallPiece] = []
	for i: int in range(ub.size() - 1):
		var a := ub[i]
		var b := ub[i + 1]
		var mid := (a + b) * 0.5
		var covered := false
		for iv: Vector2 in intervals:
			if mid > iv.x and mid < iv.y:
				covered = true
		if not covered:
			continue
		var neg := _room_side(lrooms, horizontal, mid, c - 0.05)
		var pos := _room_side(lrooms, horizontal, mid, c + 0.05)
		if neg == null and pos == null:
			continue
		var op: ManorLayout.Opening = null
		for o: ManorLayout.Opening in ops:
			if mid > o.a() and mid < o.b():
				op = o
		if not pieces.is_empty():
			var last := pieces[pieces.size() - 1]
			if is_equal_approx(last.b, a) and last.neg == neg and last.pos == pos and last.op == op:
				last.b = b
				continue
		var wp := WallPiece.new()
		wp.a = a
		wp.b = b
		wp.neg = neg
		wp.pos = pos
		wp.op = op
		pieces.append(wp)
	# Prolonge les extrémités libres pour fermer les angles extérieurs.
	for i: int in range(pieces.size()):
		var p := pieces[i]
		if p.op != null:
			continue
		var has_prev := i > 0 and is_equal_approx(pieces[i - 1].b, p.a)
		var has_next := i < pieces.size() - 1 and is_equal_approx(pieces[i + 1].a, p.b)
		if not has_prev:
			p.a -= HT
		if not has_next:
			p.b += HT
	for p: WallPiece in pieces:
		var h_max := maxf(p.neg.height if p.neg != null else 0.0, p.pos.height if p.pos != null else 0.0)
		if p.op == null:
			_wall_box(level, horizontal, c, p, 0.0, h_max, h_max)
		elif p.op.is_passage():
			if p.op.top < h_max - 0.01:
				_wall_box(level, horizontal, c, p, p.op.top, h_max, h_max)
		else:
			_wall_box(level, horizontal, c, p, 0.0, p.op.bottom, h_max)
			if p.op.top < h_max - 0.01:
				_wall_box(level, horizontal, c, p, p.op.top, h_max, h_max)
	for o: ManorLayout.Opening in ops:
		var mid_o := o.center
		var neg_r := _room_side(lrooms, horizontal, mid_o, c - 0.05)
		var pos_r := _room_side(lrooms, horizontal, mid_o, c + 0.05)
		if o.kind in ["window", "stained"]:
			if neg_r != null and pos_r == null:
				_window(neg_r, o, horizontal, c, -1.0)
			elif pos_r != null and neg_r == null:
				_window(pos_r, o, horizontal, c, 1.0)
		else:
			if neg_r != null and not (o.kind == "secret" and neg_r.id == "lib"):
				_casing(neg_r, o, horizontal, c, -1.0)
			if pos_r != null and not (o.kind == "secret" and pos_r.id == "lib"):
				_casing(pos_r, o, horizontal, c, 1.0)


func _room_side(lrooms: Array[ManorLayout.RoomDef], horizontal: bool, along: float, across: float) -> ManorLayout.RoomDef:
	var x := along if horizontal else across
	var z := across if horizontal else along
	for r: ManorLayout.RoomDef in lrooms:
		if r.contains_xz(x, z):
			return r
	return null


## Point du mur : `along` le long du mur, `off` décalage perpendiculaire, `y` hauteur absolue.
func _wp(horizontal: bool, c: float, along: float, off: float, y: float) -> Vector3:
	if horizontal:
		return Vector3(along, y, c + off)
	return Vector3(c + off, y, along)


func _axis_n(horizontal: bool, sgn: float) -> Vector3:
	if horizontal:
		return Vector3(0, 0, sgn)
	return Vector3(sgn, 0, 0)


func _wall_box(level: float, horizontal: bool, c: float, p: WallPiece, y0: float, y1: float, h_max: float) -> void:
	if y1 - y0 < 0.01:
		return
	var owner_room: ManorLayout.RoomDef = p.neg if p.neg != null else p.pos
	var seg_len := p.b - p.a
	var mid := (p.a + p.b) * 0.5
	var center := _wp(horizontal, c, mid, 0.0, level + (y0 + y1) * 0.5)
	var size := Vector3(seg_len, y1 - y0, T) if horizontal else Vector3(T, y1 - y0, seg_len)
	collider(owner_room.id, center, size)
	if seg_len >= 1.5 and y1 - y0 >= 2.3:
		_occluders.append({"room": owner_room.id, "center": center, "size": size * Vector3(0.98, 0.98, 0.5)})
	# Faces principales, stylées selon la pièce de chaque côté.
	for side: int in range(2):
		var sgn := -1.0 if side == 0 else 1.0
		var room: ManorLayout.RoomDef = p.neg if side == 0 else p.pos
		var other: ManorLayout.RoomDef = p.pos if side == 0 else p.neg
		var n := _axis_n(horizontal, sgn)
		if room == null:
			if other != null:
				_plain_face(other.id, "exterior", horizontal, c, sgn * HT, p.a, p.b, level + y0, level + y1, n)
			continue
		var top := minf(y1, room.height)
		if top - y0 < 0.01:
			continue
		_styled_face(room, horizontal, c, sgn * HT, p.a, p.b, level + y0, level + top, n)
	# Chants (tableaux de porte / fenêtre) et dessous de linteau.
	var st := style(owner_room.style)
	var trim_mat: String = st["trim"]
	if owner_room.zone == "cellar":
		trim_mat = "stone_wall"
	for end: int in range(2):
		var along := p.a if end == 0 else p.b
		var sg := -1.0 if end == 0 else 1.0
		var n_end := Vector3(sg, 0, 0) if horizontal else Vector3(0, 0, sg)
		var e0 := _wp(horizontal, c, along, -HT, level + y0)
		var e1 := _wp(horizontal, c, along, HT, level + y0)
		var e2 := _wp(horizontal, c, along, HT, level + y1)
		var e3 := _wp(horizontal, c, along, -HT, level + y1)
		batcher(owner_room.id).add_rect_world(trim_mat, e0, e1, e2, e3, n_end, Color(0.8, 0.8, 0.8), Color(0.9, 0.9, 0.9), Assets.uv_scale(trim_mat))
	if y0 > 0.01:
		var b0 := _wp(horizontal, c, p.a, -HT, level + y0)
		var b1 := _wp(horizontal, c, p.b, -HT, level + y0)
		var b2 := _wp(horizontal, c, p.b, HT, level + y0)
		var b3 := _wp(horizontal, c, p.a, HT, level + y0)
		batcher(owner_room.id).add_rect_world(trim_mat, b0, b1, b2, b3, Vector3.DOWN, Color(0.7, 0.7, 0.7), Color(0.7, 0.7, 0.7), Assets.uv_scale(trim_mat))
	if y1 < h_max - 0.01:
		var t0 := _wp(horizontal, c, p.a, -HT, level + y1)
		var t1 := _wp(horizontal, c, p.b, -HT, level + y1)
		var t2 := _wp(horizontal, c, p.b, HT, level + y1)
		var t3 := _wp(horizontal, c, p.a, HT, level + y1)
		batcher(owner_room.id).add_rect_world(trim_mat, t0, t1, t2, t3, Vector3.UP, Color(0.9, 0.9, 0.9), Color(0.9, 0.9, 0.9), Assets.uv_scale(trim_mat))


func _plain_face(room_id: String, mat: String, horizontal: bool, c: float, off: float, a: float, b: float, y0: float, y1: float, n: Vector3) -> void:
	var p0 := _wp(horizontal, c, a, off, y0)
	var p1 := _wp(horizontal, c, b, off, y0)
	var p2 := _wp(horizontal, c, b, off, y1)
	var p3 := _wp(horizontal, c, a, off, y1)
	batcher(room_id).add_rect_world(mat, p0, p1, p2, p3, n, Color(0.6, 0.6, 0.6), Color(0.6, 0.6, 0.6), Assets.uv_scale(mat))


static func ao_at(h: float, room_h: float) -> float:
	var k := 1.0
	if h < 0.5:
		k = lerpf(0.5, 1.0, clampf(h / 0.5, 0.0, 1.0))
	var top_d := room_h - h
	if top_d < 0.45:
		k = minf(k, lerpf(0.62, 1.0, clampf(top_d / 0.45, 0.0, 1.0)))
	return k


func _styled_face(room: ManorLayout.RoomDef, horizontal: bool, c: float, off: float, a: float, b: float, y_lo: float, y_hi: float, n: Vector3) -> void:
	var st := style(room.style)
	var fl := room.floor_y
	var ceil_y := fl + room.height
	var ws: float = st["ws"]
	var lower: String = st["lower"]
	var upper: String = st["upper"]
	var cuts: Array[float] = [fl, fl + 0.5, ceil_y - 0.45, ceil_y]
	if ws > 0.0:
		cuts.append(fl + ws)
	cuts.sort()
	var bt := batcher(room.id)
	for i: int in range(cuts.size() - 1):
		var u := maxf(cuts[i], y_lo)
		var v := minf(cuts[i + 1], y_hi)
		if v - u < 0.001:
			continue
		var mid_h := (u + v) * 0.5 - fl
		var mat := lower if (ws > 0.0 and mid_h < ws) else upper
		var cb := ao_at(u - fl, room.height)
		var ct := ao_at(v - fl, room.height)
		var p0 := _wp(horizontal, c, a, off, u)
		var p1 := _wp(horizontal, c, b, off, u)
		var p2 := _wp(horizontal, c, b, off, v)
		var p3 := _wp(horizontal, c, a, off, v)
		bt.add_rect_world(mat, p0, p1, p2, p3, n, Color(cb, cb, cb), Color(ct, ct, ct), Assets.uv_scale(mat))
	# Plinthes, cimaise, corniche.
	var trim: String = st["trim"]
	var sgn := signf(off)
	var covers_floor := y_lo <= fl + 0.01
	var covers_ceiling := y_hi >= ceil_y - 0.01
	var mid := (a + b) * 0.5
	var seg_len := b - a
	if bool(st["base"]) and covers_floor:
		_trim_box(room.id, trim, horizontal, c, off + sgn * 0.0125, mid, seg_len, fl + 0.08, 0.16, 0.025)
	if ws > 0.0 and covers_floor and y_hi > fl + ws:
		_trim_box(room.id, trim, horizontal, c, off + sgn * 0.015, mid, seg_len, fl + ws, 0.05, 0.03)
	if bool(st["crown"]) and covers_ceiling:
		_trim_box(room.id, trim, horizontal, c, off + sgn * 0.04, mid, seg_len, ceil_y - 0.07, 0.14, 0.08)


func _trim_box(room_id: String, mat: String, horizontal: bool, c: float, off: float, mid: float, seg_len: float, y: float, h: float, depth: float) -> void:
	var center := _wp(horizontal, c, mid, off, y)
	var size := Vector3(seg_len, h, depth) if horizontal else Vector3(depth, h, seg_len)
	batcher(room_id).add_box(mat, Transform3D(Basis.IDENTITY, center), size, Color(0.85, 0.85, 0.85), Assets.uv_scale(mat))


func _casing(room: ManorLayout.RoomDef, o: ManorLayout.Opening, horizontal: bool, c: float, sgn: float) -> void:
	var st := style(room.style)
	var trim: String = st["trim"]
	if room.zone == "cellar":
		trim = "wood_dark"
	var w := 0.1 if o.kind != "main" else 0.2
	var depth := 0.035
	var off := sgn * (HT + depth * 0.5)
	var lvl := o.level
	var top := o.top
	if o.bottom > 0.0:
		_trim_box(room.id, trim, horizontal, c, off, o.center, o.width + w * 2.0, lvl + o.bottom - w * 0.5, w, depth)
	_trim_box(room.id, trim, horizontal, c, off, o.a() - w * 0.5, w, lvl + (o.bottom + top + w) * 0.5, top - o.bottom + w, depth)
	_trim_box(room.id, trim, horizontal, c, off, o.b() + w * 0.5, w, lvl + (o.bottom + top + w) * 0.5, top - o.bottom + w, depth)
	_trim_box(room.id, trim, horizontal, c, off, o.center, o.width + w * 2.0, lvl + top + w * 0.5, w, depth)
	if o.kind == "main":
		_trim_box(room.id, trim, horizontal, c, sgn * (HT + 0.06), o.center, o.width + 0.7, lvl + top + 0.3, 0.12, 0.12)


func _window(room: ManorLayout.RoomDef, o: ManorLayout.Opening, horizontal: bool, c: float, sgn: float) -> void:
	var st := style(room.style)
	var frame_mat := "wood_dark"
	var lvl := room.floor_y
	var y0 := lvl + o.bottom
	var y1 := lvl + o.top
	var n := _axis_n(horizontal, sgn)
	var rid := room.id
	# Vitre (UV 0..1) légèrement en retrait vers l'extérieur.
	var glass_off := -sgn * 0.02
	var mat := "glass_stained" if o.kind == "stained" else "glass_window"
	quad_uv(rid, mat, _wp(horizontal, c, o.a(), glass_off, y0), _wp(horizontal, c, o.b(), glass_off, y0), _wp(horizontal, c, o.b(), glass_off, y1), _wp(horizontal, c, o.a(), glass_off, y1), n)
	var glass_size := Vector3(o.width, o.top - o.bottom, 0.06) if horizontal else Vector3(0.06, o.top - o.bottom, o.width)
	collider(rid, _wp(horizontal, c, o.center, 0.0, (y0 + y1) * 0.5), glass_size)
	# Châssis et croisillons.
	var fo := sgn * 0.02
	var fw := 0.07
	_trim_box(rid, frame_mat, horizontal, c, fo, o.a() + fw * 0.5, fw, (y0 + y1) * 0.5, o.top - o.bottom, 0.08)
	_trim_box(rid, frame_mat, horizontal, c, fo, o.b() - fw * 0.5, fw, (y0 + y1) * 0.5, o.top - o.bottom, 0.08)
	_trim_box(rid, frame_mat, horizontal, c, fo, o.center, o.width, y1 - fw * 0.5, fw, 0.08)
	_trim_box(rid, frame_mat, horizontal, c, fo, o.center, o.width, y0 + fw * 0.5, fw, 0.08)
	if o.kind == "window":
		_trim_box(rid, frame_mat, horizontal, c, fo, o.center, 0.045, (y0 + y1) * 0.5, o.top - o.bottom, 0.06)
		_trim_box(rid, frame_mat, horizontal, c, fo, o.center, o.width, lerpf(y0, y1, 0.62), 0.045, 0.06)
	else:
		for k: int in range(1, 4):
			_trim_box(rid, "iron_black", horizontal, c, fo, o.center, o.width, lerpf(y0, y1, float(k) / 4.0), 0.03, 0.04)
	# Appui de fenêtre.
	_trim_box(rid, frame_mat, horizontal, c, sgn * (HT + 0.06), o.center, o.width + 0.25, y0 - 0.025, 0.05, 0.14)
	# Rideaux.
	var curtain: String = st["curtain"]
	if curtain != "" and o.kind == "window":
		var ch := minf(o.top + 0.25, room.height - 0.15)
		for s: int in range(2):
			var along := o.a() - 0.2 if s == 0 else o.b() + 0.2
			var cc := _wp(horizontal, c, along, sgn * (HT + 0.1), lvl + ch * 0.5 + 0.03)
			var cs := Vector3(0.36, ch - 0.06, 0.07) if horizontal else Vector3(0.07, ch - 0.06, 0.36)
			batcher(rid).add_box(curtain, Transform3D(Basis.IDENTITY, cc), cs, Color(0.8, 0.8, 0.8), Assets.uv_scale(curtain), false, MeshBatcher.FACE_ALL, 0.6)
		_trim_box(rid, "brass", horizontal, c, sgn * (HT + 0.12), o.center, o.width + 1.0, lvl + ch + 0.02, 0.03, 0.03)
	if o.id in MOONLIT:
		_moon_shaft(rid, o, horizontal, c, sgn, lvl)


## Faux rai de lune : prisme additif de la fenêtre au sol + tache lumineuse au sol.
func _moon_shaft(rid: String, o: ManorLayout.Opening, horizontal: bool, c: float, sgn: float, lvl: float) -> void:
	var tan_a := 0.9
	var yb := o.bottom
	var yt := o.top
	var d_near := yb / tan_a + HT
	var d_far := yt / tan_a + HT
	var a := o.a() + 0.05
	var b := o.b() - 0.05
	var wa0 := _wp(horizontal, c, a, sgn * HT, lvl + yb)
	var wb0 := _wp(horizontal, c, b, sgn * HT, lvl + yb)
	var wb1 := _wp(horizontal, c, b, sgn * HT, lvl + yt)
	var wa1 := _wp(horizontal, c, a, sgn * HT, lvl + yt)
	var fa0 := _wp(horizontal, c, a, sgn * d_near, lvl + 0.02)
	var fb0 := _wp(horizontal, c, b, sgn * d_near, lvl + 0.02)
	var fb1 := _wp(horizontal, c, b, sgn * d_far, lvl + 0.02)
	var fa1 := _wp(horizontal, c, a, sgn * d_far, lvl + 0.02)
	var strong := Color(1, 1, 1, 0.075)
	var none := Color(1, 1, 1, 0.0)
	var bt := batcher(rid)
	var sides: Array = [
		[wa0, wb0, fb0, fa0], [wa1, wb1, fb1, fa1], [wa0, wa1, fa1, fa0], [wb0, wb1, fb1, fb0],
	]
	for q: Variant in sides:
		var arr: Array = q
		var p: Array[Vector3] = [arr[0] as Vector3, arr[1] as Vector3, arr[2] as Vector3, arr[3] as Vector3]
		var nrm := ((p[1] - p[0]).cross(p[3] - p[0])).normalized()
		if nrm.length() < 0.5:
			nrm = Vector3.UP
		var uv: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
		var cols: Array[Color] = [strong, strong, none, none]
		bt.add_quad("moon_shaft", p, nrm, uv, cols, Vector3.RIGHT)
	var pool_p: Array[Vector3] = [fa0, fb0, fb1, fa1]
	var pool_uv: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var pc := Color(1, 1, 1, 1)
	var pool_c: Array[Color] = [pc, pc, pc, pc]
	bt.add_quad("moon_pool", pool_p, Vector3.UP, pool_uv, pool_c, Vector3.RIGHT)


# ------------------------------------------------------------ sols et plafonds

func _build_floor_ceiling(r: ManorLayout.RoomDef) -> void:
	var st := style(r.style)
	var floor_mat: String = st["floor"]
	var ceil_mat: String = st["ceiling"]
	var fh: Array = layout.floor_holes.get(r.id, [])
	var ch: Array = layout.ceiling_holes.get(r.id, [])
	var fl := r.floor_y
	var top := fl + r.height
	if fh.is_empty():
		_ao_rect(r.id, floor_mat, r.rect, fl, true, 0.5, 0.58)
		collider(r.id, Vector3(r.rect.get_center().x, fl - 0.15, r.rect.get_center().y), Vector3(r.rect.size.x, 0.3, r.rect.size.y))
	else:
		for sub: Rect2 in _subtract(r.rect, fh):
			_ao_rect(r.id, floor_mat, sub, fl, true, 0.0, 1.0)
			collider(r.id, Vector3(sub.get_center().x, fl - 0.15, sub.get_center().y), Vector3(sub.size.x, 0.3, sub.size.y))
	if ch.is_empty():
		_ao_rect(r.id, ceil_mat, r.rect, top, false, 0.5, 0.55)
		collider(r.id, Vector3(r.rect.get_center().x, top + 0.15, r.rect.get_center().y), Vector3(r.rect.size.x, 0.3, r.rect.size.y))
	else:
		for sub2: Rect2 in _subtract(r.rect, ch):
			_ao_rect(r.id, ceil_mat, sub2, top, false, 0.0, 1.0)
			collider(r.id, Vector3(sub2.get_center().x, top + 0.15, sub2.get_center().y), Vector3(sub2.size.x, 0.3, sub2.size.y))


## Rectangle horizontal découpé en 3x3 : bords assombris (occlusion ambiante « cuite »).
func _ao_rect(room_id: String, mat: String, rect: Rect2, y: float, up: bool, inset: float, dark: float) -> void:
	var bt := batcher(room_id)
	var n := Vector3.UP if up else Vector3.DOWN
	var uvs := Assets.uv_scale(mat)
	if inset <= 0.0 or rect.size.x < inset * 2.5 or rect.size.y < inset * 2.5:
		var p: Array[Vector3] = [
			Vector3(rect.position.x, y, rect.position.y), Vector3(rect.end.x, y, rect.position.y),
			Vector3(rect.end.x, y, rect.end.y), Vector3(rect.position.x, y, rect.end.y),
		]
		var w := Color(0.9, 0.9, 0.9)
		var cols: Array[Color] = [w, w, w, w]
		bt.add_quad_world(mat, p, n, cols, uvs)
		return
	var xs: Array[float] = [rect.position.x, rect.position.x + inset, rect.end.x - inset, rect.end.x]
	var zs: Array[float] = [rect.position.y, rect.position.y + inset, rect.end.y - inset, rect.end.y]
	for j: int in range(3):
		for i: int in range(3):
			var p2: Array[Vector3] = [
				Vector3(xs[i], y, zs[j]), Vector3(xs[i + 1], y, zs[j]),
				Vector3(xs[i + 1], y, zs[j + 1]), Vector3(xs[i], y, zs[j + 1]),
			]
			var idx: Array[Vector2i] = [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var cols2: Array[Color] = []
			for g: Vector2i in idx:
				var edge := g.x == 0 or g.x == 3 or g.y == 0 or g.y == 3
				var k := dark if edge else 1.0
				cols2.append(Color(k, k, k))
			bt.add_quad_world(mat, p2, n, cols2, uvs)


func _subtract(rect: Rect2, holes: Array) -> Array[Rect2]:
	var out: Array[Rect2] = [rect]
	for h: Variant in holes:
		var hole: Rect2 = h
		var next: Array[Rect2] = []
		for r: Rect2 in out:
			if not r.intersects(hole):
				next.append(r)
				continue
			var ix := r.intersection(hole)
			if ix.position.y > r.position.y:
				next.append(Rect2(r.position.x, r.position.y, r.size.x, ix.position.y - r.position.y))
			if ix.end.y < r.end.y:
				next.append(Rect2(r.position.x, ix.end.y, r.size.x, r.end.y - ix.end.y))
			if ix.position.x > r.position.x:
				next.append(Rect2(r.position.x, ix.position.y, ix.position.x - r.position.x, ix.size.y))
			if ix.end.x < r.end.x:
				next.append(Rect2(ix.end.x, ix.position.y, r.end.x - ix.end.x, ix.size.y))
		out = next
	return out


# ------------------------------------------------------------ escalier de la cave

func _build_cellar_stairs() -> void:
	var x_top := 5.0
	var x_bot := 11.2
	var drop := 3.6
	var z0 := 28.2
	var z1 := 29.8
	var zc := (z0 + z1) * 0.5
	var width := z1 - z0
	var run := x_bot - x_top
	var ang := atan2(drop, run)
	var length := sqrt(run * run + drop * drop) + 0.5
	# Rampe de collision (invisible) : on marche dessus, les marches sont décoratives.
	var basis := Basis(Vector3(0, 0, 1), -ang)
	var surf_n := basis * Vector3.UP
	var mid := Vector3((x_top + x_bot) * 0.5, -drop * 0.5, zc) - surf_n * 0.1
	collider_xf("cellar_a", Transform3D(basis, mid), Vector3(length, 0.2, width))
	# Marches visibles.
	var steps := 18
	var step_run := run / float(steps)
	var rise := drop / float(steps)
	for i: int in range(steps):
		var top_y := -rise * float(i + 1) + rise * 0.5
		var cx := x_top + step_run * (float(i) + 0.5)
		batcher("cellar_a").add_box("wood_raw", Transform3D(Basis.IDENTITY, Vector3(cx, top_y - 0.1, zc)), Vector3(step_run + 0.02, 0.2, width), Color(0.85, 0.85, 0.85), Assets.uv_scale("wood_raw"))
		batcher("cellar_a").add_box("wood_dark", Transform3D(Basis.IDENTITY, Vector3(cx + step_run * 0.5 - 0.02, top_y - 0.1, zc)), Vector3(0.04, 0.22, width), Color(0.6, 0.6, 0.6), 1.0)
	# Limon côté nord.
	batcher("cellar_a").add_box("wood_dark", Transform3D(basis, Vector3((x_top + x_bot) * 0.5, -drop * 0.5 - 0.1, z0 - 0.05)), Vector3(length - 0.4, 0.35, 0.08), Color(0.7, 0.7, 0.7), 1.0)
	# Murets sous la rampe (côté cave).
	var ly := ManorLayout.LEVEL_CELLAR
	var wall_top := -0.3
	var wall_h := wall_top - ly
	box("cellar_a", "stone_wall", Vector3((5.0 + 10.3) * 0.5, ly + wall_h * 0.5, 28.05), Vector3(10.3 - 5.0, wall_h, 0.2), 0.0, true, Color(0.8, 0.8, 0.8), false, 0.7)
	box("cellar_a", "stone_wall", Vector3(5.05, ly + wall_h * 0.5, 29.0), Vector3(0.2, wall_h, 1.8), 0.0, true, Color(0.8, 0.8, 0.8), false, 0.7)
	# Rambarde côté cuisine.
	var rail_z := 28.1
	box("kitchen", "wood_dark", Vector3(8.44, 0.95, rail_z), Vector3(6.88, 0.07, 0.09), 0.0, false)
	box("kitchen", "wood_dark", Vector3(8.44, 0.12, rail_z), Vector3(6.88, 0.06, 0.06), 0.0, false)
	var px := 5.05
	while px < 11.9:
		box("kitchen", "wood_dark", Vector3(px, 0.5, rail_z), Vector3(0.05, 0.9, 0.05), 0.0, false)
		px += 0.4
	collider("kitchen", Vector3(8.44, 0.55, rail_z), Vector3(6.88, 1.1, 0.12))
	# Chants de la dalle autour de la trémie.
	box("kitchen", "wood_raw", Vector3(8.5, -0.15, 28.1), Vector3(7.0, 0.3, 0.02), 0.0, false)
