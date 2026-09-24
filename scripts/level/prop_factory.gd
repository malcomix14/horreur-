class_name PropFactory
extends RefCounted
## Mobilier construit à partir de primitives, fusionné dans le lot de la pièce (ManorBuilder).
## Convention : `xf` = repère du meuble (origine au sol, au centre ; avant = +Z local).

static func at(pos: Vector3, rot_y: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y), pos)


static func _bx(b: ManorBuilder, room: String, mat: String, xf: Transform3D, center: Vector3, size: Vector3, color: Color = Color(0.9, 0.9, 0.9), face_uv: bool = false, ao: float = 0.85) -> void:
	b.box_xf(room, mat, Transform3D(xf.basis, xf * center), size, false, color, face_uv, ao)


static func _solid(b: ManorBuilder, room: String, xf: Transform3D, center: Vector3, size: Vector3) -> void:
	b.collider_xf(room, Transform3D(xf.basis, xf * center), size)


static func _cyl(b: ManorBuilder, room: String, mat: String, xf: Transform3D, base: Vector3, rb: float, rt: float, h: float, seg: int = 8, color: Color = Color(0.9, 0.9, 0.9)) -> void:
	b.cyl_xf(room, mat, Transform3D(xf.basis, xf * base), rb, rt, h, seg, color)


# ============================================================ tables et sièges

static func table(b: ManorBuilder, room: String, xf: Transform3D, w: float, d: float, h: float, wood: String, cloth: String = "") -> void:
	_bx(b, room, wood, xf, Vector3(0, h - 0.03, 0), Vector3(w, 0.06, d))
	_bx(b, room, wood, xf, Vector3(0, h - 0.12, 0), Vector3(w - 0.12, 0.12, d - 0.12), Color(0.6, 0.6, 0.6))
	for sx: int in range(2):
		for sz: int in range(2):
			var lx := (w * 0.5 - 0.08) * (1.0 if sx == 0 else -1.0)
			var lz := (d * 0.5 - 0.08) * (1.0 if sz == 0 else -1.0)
			_cyl(b, room, wood, xf, Vector3(lx, 0, lz), 0.035, 0.045, h - 0.06, 8, Color(0.8, 0.8, 0.8))
	if cloth != "":
		_bx(b, room, cloth, xf, Vector3(0, h + 0.005, 0), Vector3(w * 0.7, 0.01, d + 0.04), Color(0.9, 0.9, 0.9))
		_bx(b, room, cloth, xf, Vector3(0, h - 0.12, d * 0.5 + 0.02), Vector3(w * 0.7, 0.25, 0.01), Color(0.8, 0.8, 0.8))
		_bx(b, room, cloth, xf, Vector3(0, h - 0.12, -d * 0.5 - 0.02), Vector3(w * 0.7, 0.25, 0.01), Color(0.8, 0.8, 0.8))
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, d))


static func round_table(b: ManorBuilder, room: String, xf: Transform3D, r: float, h: float, wood: String) -> void:
	_cyl(b, room, wood, xf, Vector3(0, h - 0.04, 0), r, r, 0.04, 16)
	_cyl(b, room, wood, xf, Vector3(0, 0.05, 0), 0.05, 0.06, h - 0.08, 8)
	_cyl(b, room, wood, xf, Vector3(0, 0.0, 0), 0.3 * r + 0.1, 0.12, 0.08, 10)
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(r * 1.5, h, r * 1.5))


static func chair(b: ManorBuilder, room: String, xf: Transform3D, wood: String, fabric: String, knocked: bool = false) -> void:
	var cxf := xf
	if knocked:
		cxf = Transform3D(xf.basis * Basis(Vector3.RIGHT, -1.45), xf.origin + xf.basis * Vector3(0, 0.22, -0.2))
	_bx(b, room, fabric, cxf, Vector3(0, 0.47, 0), Vector3(0.44, 0.06, 0.42))
	for sx: int in range(2):
		for sz: int in range(2):
			var lx := 0.18 * (1.0 if sx == 0 else -1.0)
			var lz := 0.17 * (1.0 if sz == 0 else -1.0)
			_bx(b, room, wood, cxf, Vector3(lx, 0.22, lz), Vector3(0.04, 0.44, 0.04))
	_bx(b, room, wood, cxf, Vector3(0.18, 0.78, -0.19), Vector3(0.04, 0.62, 0.04))
	_bx(b, room, wood, cxf, Vector3(-0.18, 0.78, -0.19), Vector3(0.04, 0.62, 0.04))
	_bx(b, room, fabric, cxf, Vector3(0, 0.82, -0.19), Vector3(0.34, 0.42, 0.03))
	_bx(b, room, wood, cxf, Vector3(0, 1.08, -0.19), Vector3(0.44, 0.05, 0.05))
	if not knocked:
		_solid(b, room, xf, Vector3(0, 0.5, 0), Vector3(0.46, 1.0, 0.46))
	else:
		_solid(b, room, xf, Vector3(0, 0.25, -0.3), Vector3(0.5, 0.5, 0.9))


static func sheet_furniture(b: ManorBuilder, room: String, xf: Transform3D, w: float, h: float, d: float) -> void:
	# Meuble recouvert d'un drap poussiéreux (silhouette fantomatique).
	_bx(b, room, "sheet", xf, Vector3(0, h * 0.55, 0), Vector3(w, h * 0.9, d), Color(0.8, 0.8, 0.8), false, 0.6)
	_bx(b, room, "sheet", xf, Vector3(0, h * 0.95, 0.02), Vector3(w * 0.9, h * 0.15, d * 0.85), Color(0.85, 0.85, 0.85))
	_bx(b, room, "sheet", xf, Vector3(0, h * 0.06, 0), Vector3(w + 0.1, h * 0.12, d + 0.1), Color(0.7, 0.7, 0.7), false, 0.5)
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, d))


static func armchair(b: ManorBuilder, room: String, xf: Transform3D, fabric: String, wood: String) -> void:
	_bx(b, room, fabric, xf, Vector3(0, 0.3, 0.02), Vector3(0.8, 0.24, 0.72))
	_bx(b, room, fabric, xf, Vector3(0, 0.75, -0.3), Vector3(0.8, 0.7, 0.18))
	_bx(b, room, fabric, xf, Vector3(0.36, 0.55, 0.0), Vector3(0.14, 0.26, 0.72))
	_bx(b, room, fabric, xf, Vector3(-0.36, 0.55, 0.0), Vector3(0.14, 0.26, 0.72))
	_bx(b, room, fabric, xf, Vector3(0, 0.46, 0.06), Vector3(0.56, 0.1, 0.56), Color(1, 1, 1))
	for sx: int in range(2):
		for sz: int in range(2):
			_bx(b, room, wood, xf, Vector3(0.33 * (1.0 if sx == 0 else -1.0), 0.09, 0.3 * (1.0 if sz == 0 else -1.0)), Vector3(0.06, 0.18, 0.06))
	_solid(b, room, xf, Vector3(0, 0.55, 0), Vector3(0.82, 1.1, 0.75))


static func sofa(b: ManorBuilder, room: String, xf: Transform3D, w: float, fabric: String, wood: String) -> void:
	_bx(b, room, fabric, xf, Vector3(0, 0.3, 0.02), Vector3(w, 0.24, 0.8))
	_bx(b, room, fabric, xf, Vector3(0, 0.72, -0.33), Vector3(w, 0.64, 0.16))
	_bx(b, room, fabric, xf, Vector3(w * 0.5 - 0.08, 0.55, 0), Vector3(0.16, 0.3, 0.8))
	_bx(b, room, fabric, xf, Vector3(-w * 0.5 + 0.08, 0.55, 0), Vector3(0.16, 0.3, 0.8))
	for i: int in range(3):
		var cx := (float(i) - 1.0) * (w - 0.3) / 3.0
		_bx(b, room, fabric, xf, Vector3(cx, 0.46, 0.06), Vector3((w - 0.36) / 3.0 - 0.02, 0.1, 0.6), Color(1, 1, 1))
	for sx: int in range(2):
		_bx(b, room, wood, xf, Vector3((w * 0.5 - 0.1) * (1.0 if sx == 0 else -1.0), 0.09, 0.3), Vector3(0.06, 0.18, 0.06))
		_bx(b, room, wood, xf, Vector3((w * 0.5 - 0.1) * (1.0 if sx == 0 else -1.0), 0.09, -0.3), Vector3(0.06, 0.18, 0.06))
	_solid(b, room, xf, Vector3(0, 0.5, 0), Vector3(w, 1.0, 0.85))


# ============================================================ rangements

static func bookshelf(b: ManorBuilder, room: String, xf: Transform3D, w: float, h: float, d: float, shelves: int, wood: String = "wood_dark") -> void:
	var bt := b.batcher(room)
	var pos := xf.origin
	var rot := xf.basis
	var local := MeshBatcher.new()
	bookshelf_mesh(local, Vector3.ZERO, w, h, d, shelves, wood)
	# Copie dans le lot de la pièce avec la transformation du meuble.
	_merge(bt, local, Transform3D(rot, pos))
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, d))


static func bookshelf_mesh(bt: MeshBatcher, off: Vector3, w: float, h: float, d: float, shelves: int, wood: String = "wood_dark") -> void:
	var uv := Assets.uv_scale(wood)
	var c := Color(0.8, 0.8, 0.8)
	bt.add_box(wood, Transform3D(Basis.IDENTITY, off + Vector3(0, h * 0.5, -d * 0.5 + 0.015)), Vector3(w, h, 0.03), c * 0.6, uv)
	bt.add_box(wood, Transform3D(Basis.IDENTITY, off + Vector3(-w * 0.5 + 0.02, h * 0.5, 0)), Vector3(0.04, h, d), c, uv, false, MeshBatcher.FACE_ALL, 0.7)
	bt.add_box(wood, Transform3D(Basis.IDENTITY, off + Vector3(w * 0.5 - 0.02, h * 0.5, 0)), Vector3(0.04, h, d), c, uv, false, MeshBatcher.FACE_ALL, 0.7)
	bt.add_box(wood, Transform3D(Basis.IDENTITY, off + Vector3(0, h + 0.03, 0.01)), Vector3(w + 0.08, 0.06, d + 0.04), c, uv)
	var step := (h - 0.12) / float(shelves)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(off.x * 131.0 + off.z * 71.0 + w * 17.0 + h * 3.0)) + 5
	for s: int in range(shelves):
		var y := 0.08 + float(s) * step
		bt.add_box(wood, Transform3D(Basis.IDENTITY, off + Vector3(0, y, 0)), Vector3(w - 0.08, 0.03, d - 0.02), c, uv)
		# Livres (couleurs variées via couleurs de sommets).
		var x := -w * 0.5 + 0.06
		while x < w * 0.5 - 0.1:
			var bw := rng.randf_range(0.025, 0.06)
			if rng.randf() < 0.08:
				x += rng.randf_range(0.05, 0.2)
				continue
			var bh := minf(rng.randf_range(0.18, 0.3), step - 0.05)
			var bd := rng.randf_range(d * 0.6, d * 0.85)
			var tilt := 0.0
			if rng.randf() < 0.07:
				tilt = rng.randf_range(0.15, 0.35)
			var col := Color.from_hsv(rng.randf_range(0.0, 0.12) if rng.randf() < 0.7 else rng.randf_range(0.3, 0.65), rng.randf_range(0.35, 0.7), rng.randf_range(0.15, 0.45))
			bt.add_box("books", Transform3D(Basis(Vector3.BACK, tilt), off + Vector3(x + bw * 0.5, y + 0.015 + bh * 0.5, (d - bd) * 0.5 - 0.02)), Vector3(bw, bh, bd), col, 1.0, true)
			x += bw + 0.003
	return


static func _merge(dst: MeshBatcher, src: MeshBatcher, xf: Transform3D) -> void:
	for key: String in src._order:
		var s := src._surfaces[key] as MeshBatcher.Surface
		var ds := dst._surf(key)
		var base := ds.verts.size()
		for i: int in range(s.verts.size()):
			ds.verts.append(xf * s.verts[i])
			ds.normals.append((xf.basis * s.normals[i]).normalized())
			ds.uvs.append(s.uvs[i])
			ds.colors.append(s.colors[i])
			var t := xf.basis * Vector3(s.tangents[i * 4], s.tangents[i * 4 + 1], s.tangents[i * 4 + 2])
			ds.tangents.append_array(PackedFloat32Array([t.x, t.y, t.z, 1.0]))
		for idx: int in s.indices:
			ds.indices.append(base + idx)


static func sideboard(b: ManorBuilder, room: String, xf: Transform3D, w: float, wood: String) -> void:
	var h := 0.92
	var d := 0.5
	_bx(b, room, wood, xf, Vector3(0, h * 0.5 + 0.06, 0), Vector3(w, h - 0.12, d), Color(0.85, 0.85, 0.85), false, 0.7)
	_bx(b, room, wood, xf, Vector3(0, h + 0.01, 0.01), Vector3(w + 0.06, 0.04, d + 0.04))
	var n := maxi(2, int(w / 0.6))
	for i: int in range(n):
		var cx := -w * 0.5 + (float(i) + 0.5) * w / float(n)
		_bx(b, room, wood, xf, Vector3(cx, 0.45, d * 0.5 + 0.01), Vector3(w / float(n) - 0.06, 0.6, 0.02), Color(0.65, 0.65, 0.65))
		_bx(b, room, "brass", xf, Vector3(cx, 0.62, d * 0.5 + 0.03), Vector3(0.06, 0.015, 0.015), Color.WHITE)
	for sx: int in range(2):
		_bx(b, room, wood, xf, Vector3((w * 0.5 - 0.05) * (1.0 if sx == 0 else -1.0), 0.03, 0.2), Vector3(0.06, 0.06, 0.06))
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, d))


static func dresser(b: ManorBuilder, room: String, xf: Transform3D, w: float, h: float, wood: String) -> void:
	var d := 0.5
	_bx(b, room, wood, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, d), Color(0.85, 0.85, 0.85), false, 0.7)
	var rows := maxi(2, int(h / 0.25))
	for r: int in range(rows):
		var y := 0.12 + (float(r) + 0.5) * (h - 0.16) / float(rows)
		_bx(b, room, wood, xf, Vector3(0, y, d * 0.5 + 0.01), Vector3(w - 0.08, (h - 0.2) / float(rows) - 0.03, 0.02), Color(0.7, 0.7, 0.7))
		_bx(b, room, "brass", xf, Vector3(-w * 0.25, y, d * 0.5 + 0.03), Vector3(0.05, 0.015, 0.015), Color.WHITE)
		_bx(b, room, "brass", xf, Vector3(w * 0.25, y, d * 0.5 + 0.03), Vector3(0.05, 0.015, 0.015), Color.WHITE)
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, d))


static func nightstand(b: ManorBuilder, room: String, xf: Transform3D, wood: String) -> void:
	_bx(b, room, wood, xf, Vector3(0, 0.3, 0), Vector3(0.45, 0.5, 0.4), Color(0.85, 0.85, 0.85), false, 0.7)
	_bx(b, room, wood, xf, Vector3(0, 0.57, 0), Vector3(0.5, 0.04, 0.44))
	for sx: int in range(2):
		for sz: int in range(2):
			_bx(b, room, wood, xf, Vector3(0.19 * (1.0 if sx == 0 else -1.0), 0.03, 0.16 * (1.0 if sz == 0 else -1.0)), Vector3(0.04, 0.06, 0.04))
	_solid(b, room, xf, Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.44))


static func desk(b: ManorBuilder, room: String, xf: Transform3D, w: float, wood: String) -> void:
	var h := 0.78
	var d := 0.75
	_bx(b, room, wood, xf, Vector3(0, h - 0.03, 0), Vector3(w, 0.06, d))
	_bx(b, room, "leather", xf, Vector3(0, h + 0.002, 0.05), Vector3(w * 0.6, 0.004, d * 0.55), Color(0.4, 0.5, 0.35))
	_bx(b, room, wood, xf, Vector3(-w * 0.5 + 0.22, (h - 0.06) * 0.5, 0), Vector3(0.42, h - 0.06, d - 0.06), Color(0.8, 0.8, 0.8), false, 0.7)
	_bx(b, room, wood, xf, Vector3(w * 0.5 - 0.22, (h - 0.06) * 0.5, 0), Vector3(0.42, h - 0.06, d - 0.06), Color(0.8, 0.8, 0.8), false, 0.7)
	_bx(b, room, wood, xf, Vector3(0, h - 0.2, -d * 0.5 + 0.05), Vector3(w - 0.8, 0.28, 0.03), Color(0.6, 0.6, 0.6))
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, d))


# ============================================================ grandes pièces de mobilier

static func grand_piano(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	var w := "wood_black"
	_bx(b, room, w, xf, Vector3(0, 0.8, 0.0), Vector3(1.5, 0.3, 1.0))
	_bx(b, room, w, xf, Vector3(0.2, 0.8, -0.6), Vector3(1.0, 0.3, 0.6))
	_bx(b, room, w, xf, Vector3(0.45, 0.8, -1.05), Vector3(0.5, 0.3, 0.5))
	_bx(b, room, w, xf, Vector3(0.1, 1.25, -0.35), Vector3(1.3, 0.03, 1.5), Color(0.8, 0.8, 0.8))
	_bx(b, room, w, xf, Vector3(0.1, 1.05, -0.35), Vector3(0.02, 0.4, 0.02))
	_bx(b, room, "porcelain", xf, Vector3(0, 0.96, 0.55), Vector3(1.3, 0.03, 0.16), Color(0.95, 0.93, 0.85))
	for i: int in range(18):
		_bx(b, room, "black", xf, Vector3(-0.6 + float(i) * 0.07, 0.985, 0.52), Vector3(0.025, 0.02, 0.09))
	var legs: Array[Vector3] = [Vector3(-0.65, 0, 0.4), Vector3(0.65, 0, 0.4), Vector3(0.5, 0, -1.1)]
	for l: Vector3 in legs:
		_cyl(b, room, w, xf, l, 0.05, 0.06, 0.66, 8)
	_bx(b, room, w, xf, Vector3(0, 0.25, 0.95), Vector3(0.7, 0.05, 0.35))
	_bx(b, room, w, xf, Vector3(0, 0.12, 0.95), Vector3(0.05, 0.24, 0.3))
	_solid(b, room, xf, Vector3(0, 0.6, -0.3), Vector3(1.55, 1.2, 1.7))


static func grandfather_clock(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	var w := "wood_dark"
	_bx(b, room, w, xf, Vector3(0, 0.2, 0), Vector3(0.55, 0.4, 0.35), Color(0.8, 0.8, 0.8), false, 0.6)
	_bx(b, room, w, xf, Vector3(0, 1.1, 0), Vector3(0.45, 1.4, 0.28))
	_bx(b, room, w, xf, Vector3(0, 2.05, 0), Vector3(0.55, 0.5, 0.35))
	_bx(b, room, w, xf, Vector3(0, 2.35, 0), Vector3(0.62, 0.1, 0.4))
	_cyl(b, room, "porcelain", xf, Vector3(0, 2.05, 0.18), 0.17, 0.17, 0.01, 16, Color(0.9, 0.87, 0.78))
	_bx(b, room, "black", xf, Vector3(0.0, 2.08, 0.19), Vector3(0.01, 0.12, 0.005))
	_bx(b, room, "black", xf, Vector3(0.04, 2.05, 0.19), Vector3(0.09, 0.01, 0.005))
	_bx(b, room, "black", xf, Vector3(0, 1.1, 0.141), Vector3(0.3, 1.1, 0.005), Color(0.3, 0.3, 0.3))
	_cyl(b, room, "brass", xf, Vector3(0, 0.75, 0.13), 0.08, 0.08, 0.01, 12)
	_bx(b, room, "brass", xf, Vector3(0, 1.2, 0.13), Vector3(0.01, 0.9, 0.01))
	_solid(b, room, xf, Vector3(0, 1.2, 0), Vector3(0.6, 2.4, 0.4))


static func suit_of_armor(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	var m := "metal"
	_bx(b, room, "wood_dark", xf, Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.5))
	_cyl(b, room, m, xf, Vector3(0.12, 0.1, 0), 0.07, 0.08, 0.85, 8)
	_cyl(b, room, m, xf, Vector3(-0.12, 0.1, 0), 0.07, 0.08, 0.85, 8)
	_cyl(b, room, m, xf, Vector3(0, 0.95, 0), 0.2, 0.25, 0.6, 10)
	b.sphere(room, m, xf * Vector3(0, 1.72, 0), Vector3(0.14, 0.17, 0.15), Color(0.8, 0.8, 0.8))
	_bx(b, room, "black", xf, Vector3(0, 1.72, 0.14), Vector3(0.16, 0.02, 0.03))
	_cyl(b, room, m, xf, Vector3(0.3, 0.9, 0), 0.05, 0.06, 0.62, 8)
	_cyl(b, room, m, xf, Vector3(-0.3, 0.9, 0), 0.05, 0.06, 0.62, 8)
	_bx(b, room, "iron_black", xf, Vector3(0.36, 1.2, 0.1), Vector3(0.03, 2.2, 0.03))
	_bx(b, room, "metal", xf, Vector3(0.36, 2.25, 0.1), Vector3(0.18, 0.25, 0.01))
	_solid(b, room, xf, Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.5))


static func stove(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	_bx(b, room, "iron_black", xf, Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.7), Color(0.8, 0.8, 0.8), false, 0.6)
	_bx(b, room, "metal", xf, Vector3(0, 0.91, 0), Vector3(1.44, 0.03, 0.74))
	for i: int in range(3):
		_cyl(b, room, "iron_black", xf, Vector3(-0.4 + float(i) * 0.4, 0.925, 0.05), 0.13, 0.13, 0.02, 12, Color(0.5, 0.5, 0.5))
	_bx(b, room, "black", xf, Vector3(-0.3, 0.45, 0.351), Vector3(0.45, 0.35, 0.01))
	_bx(b, room, "brass", xf, Vector3(0.35, 0.6, 0.36), Vector3(0.3, 0.03, 0.03))
	_cyl(b, room, "iron_black", xf, Vector3(0.5, 0.93, -0.25), 0.1, 0.1, 2.3, 10)
	_cyl(b, room, "metal", xf, Vector3(-0.4, 0.95, 0.05), 0.15, 0.14, 0.18, 12, Color(0.6, 0.6, 0.6))
	_solid(b, room, xf, Vector3(0, 0.45, 0), Vector3(1.45, 0.9, 0.75))


static func counter(b: ManorBuilder, room: String, xf: Transform3D, w: float) -> void:
	_bx(b, room, "wood_med", xf, Vector3(0, 0.44, 0), Vector3(w, 0.88, 0.6), Color(0.75, 0.75, 0.75), false, 0.6)
	_bx(b, room, "marble_white", xf, Vector3(0, 0.9, 0.01), Vector3(w + 0.04, 0.05, 0.64), Color(0.75, 0.75, 0.75))
	_solid(b, room, xf, Vector3(0, 0.45, 0), Vector3(w, 0.9, 0.62))


static func shelf_wall(b: ManorBuilder, room: String, xf: Transform3D, w: float, y: float) -> void:
	_bx(b, room, "wood_med", xf, Vector3(0, y, 0), Vector3(w, 0.03, 0.26))
	_bx(b, room, "iron_black", xf, Vector3(-w * 0.4, y - 0.08, -0.08), Vector3(0.02, 0.16, 0.1))
	_bx(b, room, "iron_black", xf, Vector3(w * 0.4, y - 0.08, -0.08), Vector3(0.02, 0.16, 0.1))
	var x := -w * 0.5 + 0.1
	var i := 0
	while x < w * 0.5 - 0.1:
		var r := 0.04 + 0.03 * float(i % 3) * 0.5
		var hh := 0.12 + 0.08 * float((i * 7) % 3)
		var mat := "porcelain" if i % 3 == 0 else ("metal" if i % 3 == 1 else "wax")
		_cyl(b, room, mat, xf, Vector3(x, y + 0.015, 0.02), r, r * 0.8, hh, 8, Color(0.7, 0.68, 0.6))
		x += r * 2.0 + 0.05
		i += 1


static func sink_basin(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	_bx(b, room, "stone_dark", xf, Vector3(0, 0.75, 0), Vector3(0.9, 0.2, 0.55), Color(0.8, 0.8, 0.8))
	_bx(b, room, "black", xf, Vector3(0, 0.851, 0.02), Vector3(0.7, 0.01, 0.4), Color(0.3, 0.3, 0.3))
	_bx(b, room, "stone_dark", xf, Vector3(-0.35, 0.33, 0), Vector3(0.12, 0.66, 0.45))
	_bx(b, room, "stone_dark", xf, Vector3(0.35, 0.33, 0), Vector3(0.12, 0.66, 0.45))
	_bx(b, room, "brass", xf, Vector3(0, 1.0, -0.22), Vector3(0.03, 0.3, 0.03))
	_bx(b, room, "brass", xf, Vector3(0, 1.14, -0.15), Vector3(0.03, 0.03, 0.15))
	_solid(b, room, xf, Vector3(0, 0.43, 0), Vector3(0.9, 0.86, 0.55))


static func bathtub(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	_bx(b, room, "porcelain", xf, Vector3(0, 0.4, 0), Vector3(1.7, 0.5, 0.78), Color(0.85, 0.85, 0.82))
	_bx(b, room, "porcelain", xf, Vector3(0, 0.66, 0), Vector3(1.75, 0.05, 0.82), Color(0.9, 0.9, 0.88))
	_bx(b, room, "water", xf, Vector3(0, 0.55, 0), Vector3(1.55, 0.02, 0.62))
	for sx: int in range(2):
		for sz: int in range(2):
			b.sphere(room, "brass", xf * Vector3(0.7 * (1.0 if sx == 0 else -1.0), 0.08, 0.3 * (1.0 if sz == 0 else -1.0)), Vector3(0.06, 0.08, 0.06))
	_bx(b, room, "brass", xf, Vector3(-0.8, 0.85, 0), Vector3(0.03, 0.4, 0.03))
	_solid(b, room, xf, Vector3(0, 0.35, 0), Vector3(1.75, 0.7, 0.82))


static func washbasin(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	_cyl(b, room, "porcelain", xf, Vector3(0, 0, 0), 0.12, 0.1, 0.78, 10)
	_bx(b, room, "porcelain", xf, Vector3(0, 0.82, 0.05), Vector3(0.6, 0.1, 0.45))
	_bx(b, room, "water", xf, Vector3(0, 0.875, 0.06), Vector3(0.45, 0.01, 0.3))
	_bx(b, room, "brass", xf, Vector3(0, 0.98, -0.12), Vector3(0.03, 0.2, 0.03))
	_solid(b, room, xf, Vector3(0, 0.45, 0.05), Vector3(0.6, 0.9, 0.45))


static func pew(b: ManorBuilder, room: String, xf: Transform3D, w: float) -> void:
	var wood := "wood_dark"
	_bx(b, room, wood, xf, Vector3(0, 0.45, 0), Vector3(w, 0.05, 0.45))
	_bx(b, room, wood, xf, Vector3(0, 0.75, -0.22), Vector3(w, 0.6, 0.05))
	_bx(b, room, wood, xf, Vector3(w * 0.5 - 0.03, 0.5, 0), Vector3(0.06, 1.0, 0.5))
	_bx(b, room, wood, xf, Vector3(-w * 0.5 + 0.03, 0.5, 0), Vector3(0.06, 1.0, 0.5))
	_bx(b, room, wood, xf, Vector3(0, 0.12, 0.3), Vector3(w - 0.1, 0.08, 0.15), Color(0.6, 0.6, 0.6))
	_solid(b, room, xf, Vector3(0, 0.5, 0), Vector3(w, 1.0, 0.55))


static func altar(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	_bx(b, room, "stone_dark", xf, Vector3(0, 0.08, 0), Vector3(3.0, 0.16, 1.8), Color(0.8, 0.8, 0.8))
	_bx(b, room, "marble_white", xf, Vector3(0, 0.6, 0), Vector3(1.8, 0.88, 0.8), Color(0.75, 0.73, 0.7), false, 0.6)
	_bx(b, room, "marble_white", xf, Vector3(0, 1.07, 0), Vector3(1.95, 0.06, 0.9), Color(0.8, 0.78, 0.75))
	_bx(b, room, "fabric_red", xf, Vector3(0, 0.9, 0.45), Vector3(1.2, 0.4, 0.02))
	_bx(b, room, "gold_frame", xf, Vector3(0, 0.9, 0.465), Vector3(0.2, 0.3, 0.01))
	_bx(b, room, "wood_black", xf, Vector3(0, 2.2, -0.5), Vector3(0.12, 2.0, 0.12))
	_bx(b, room, "wood_black", xf, Vector3(0, 2.7, -0.5), Vector3(1.0, 0.12, 0.12))
	_solid(b, room, xf, Vector3(0, 0.55, 0), Vector3(1.95, 1.1, 0.9))
	_solid(b, room, xf, Vector3(0, 0.08, 0), Vector3(3.0, 0.16, 1.8))


static func lectern(b: ManorBuilder, room: String, xf: Transform3D) -> void:
	_cyl(b, room, "wood_dark", xf, Vector3(0, 0, 0), 0.22, 0.18, 0.06, 8)
	_bx(b, room, "wood_dark", xf, Vector3(0, 0.55, 0), Vector3(0.1, 1.0, 0.1))
	b.box_xf(room, "wood_dark", Transform3D(xf.basis * Basis(Vector3.RIGHT, -0.45), xf * Vector3(0, 1.1, 0)), Vector3(0.5, 0.04, 0.4), false)
	_solid(b, room, xf, Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.45))


static func barrel(b: ManorBuilder, room: String, pos: Vector3, lying: bool = false) -> void:
	if lying:
		b.cyl_xf(room, "wood_raw", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), pos + Vector3(0.45, 0.38, 0)), 0.36, 0.36, 0.9, 12, Color(0.7, 0.6, 0.5))
		b.collider(room, pos + Vector3(0, 0.38, 0), Vector3(0.9, 0.76, 0.76))
		return
	b.cyl(room, "wood_raw", pos, 0.34, 0.38, 0.45, 12, false, Color(0.7, 0.6, 0.5))
	b.cyl(room, "wood_raw", pos + Vector3(0, 0.45, 0), 0.38, 0.34, 0.45, 12, false, Color(0.7, 0.6, 0.5))
	b.cyl(room, "iron_black", pos + Vector3(0, 0.15, 0), 0.36, 0.365, 0.04, 12)
	b.cyl(room, "iron_black", pos + Vector3(0, 0.72, 0), 0.365, 0.36, 0.04, 12)
	b.collider(room, pos + Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.7))


static func crate(b: ManorBuilder, room: String, pos: Vector3, size: float, rot: float = 0.0) -> void:
	var xf := at(pos, rot)
	_bx(b, room, "wood_raw", xf, Vector3(0, size * 0.5, 0), Vector3(size, size, size), Color(0.75, 0.7, 0.62), false, 0.6)
	for i: int in range(2):
		var y := size * (0.25 + 0.5 * float(i))
		_bx(b, room, "wood_raw", xf, Vector3(0, y, size * 0.5 + 0.01), Vector3(size, 0.06, 0.02), Color(0.55, 0.5, 0.45))
		_bx(b, room, "wood_raw", xf, Vector3(0, y, -size * 0.5 - 0.01), Vector3(size, 0.06, 0.02), Color(0.55, 0.5, 0.45))
	b.collider(room, pos + Vector3(0, size * 0.5, 0), Vector3(size, size, size), rot)


static func wine_rack(b: ManorBuilder, room: String, xf: Transform3D, w: float) -> void:
	var h := 2.0
	_bx(b, room, "wood_raw", xf, Vector3(0, h * 0.5, -0.2), Vector3(w, h, 0.04), Color(0.5, 0.45, 0.4))
	var cols := int(w / 0.25)
	for c: int in range(cols + 1):
		_bx(b, room, "wood_raw", xf, Vector3(-w * 0.5 + float(c) * w / float(cols), h * 0.5, 0), Vector3(0.03, h, 0.4), Color(0.6, 0.55, 0.5))
	for r: int in range(7):
		var y := 0.15 + float(r) * 0.27
		_bx(b, room, "wood_raw", xf, Vector3(0, y - 0.1, 0), Vector3(w, 0.02, 0.4), Color(0.6, 0.55, 0.5))
		for c2: int in range(cols):
			if (r * 7 + c2 * 3) % 5 == 0:
				continue
			var bx := -w * 0.5 + (float(c2) + 0.5) * w / float(cols)
			b.cyl_xf(room, "water", Transform3D(xf.basis * Basis(Vector3.RIGHT, PI * 0.5), xf * Vector3(bx, y, -0.15)), 0.04, 0.04, 0.3, 6, Color(0.2, 0.3, 0.2))
	_solid(b, room, xf, Vector3(0, h * 0.5, 0), Vector3(w, h, 0.45))


# ============================================================ décor mural et petits objets

static func portrait(b: ManorBuilder, room: String, center: Vector3, normal: Vector3, w: float, h: float, mat: String) -> void:
	var right := normal.cross(Vector3.UP).normalized() * -1.0
	var fw := 0.07
	var c := center + normal * 0.02
	var basis := Basis(right, Vector3.UP, normal)
	var xf := Transform3D(basis, c)
	b.box_xf(room, "gold_frame", Transform3D(basis, xf * Vector3(0, h * 0.5 + fw * 0.5, 0)), Vector3(w + fw * 2.0, fw, 0.05), false)
	b.box_xf(room, "gold_frame", Transform3D(basis, xf * Vector3(0, -h * 0.5 - fw * 0.5, 0)), Vector3(w + fw * 2.0, fw, 0.05), false)
	b.box_xf(room, "gold_frame", Transform3D(basis, xf * Vector3(w * 0.5 + fw * 0.5, 0, 0)), Vector3(fw, h, 0.05), false)
	b.box_xf(room, "gold_frame", Transform3D(basis, xf * Vector3(-w * 0.5 - fw * 0.5, 0, 0)), Vector3(fw, h, 0.05), false)
	var p0 := c - right * w * 0.5 - Vector3.UP * h * 0.5 + normal * 0.005
	var p1 := c + right * w * 0.5 - Vector3.UP * h * 0.5 + normal * 0.005
	var p2 := c + right * w * 0.5 + Vector3.UP * h * 0.5 + normal * 0.005
	var p3 := c - right * w * 0.5 + Vector3.UP * h * 0.5 + normal * 0.005
	b.quad_uv(room, mat, p0, p1, p2, p3, normal)


static func rug(b: ManorBuilder, room: String, center: Vector3, w: float, d: float, rot: float, mat: String) -> void:
	b.box_xf(room, mat, Transform3D(Basis(Vector3.UP, rot), center + Vector3(0, 0.006, 0)), Vector3(w, 0.012, d), false, Color(0.85, 0.85, 0.85), true, 1.0)


## Tapis de couloir : motif répété dans la longueur (axe X si along_x).
static func runner(b: ManorBuilder, room: String, a: Vector3, bb: Vector3, width: float) -> void:
	var dir := bb - a
	var length := dir.length()
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized() * width * 0.5
	var y := Vector3(0, 0.012, 0)
	var p: Array[Vector3] = [a - side + y, a + side + y, bb + side + y, bb - side + y]
	var rep := length / width
	var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, rep), Vector2(0, rep)]
	var col := Color(0.85, 0.85, 0.85)
	var cols: Array[Color] = [col, col, col, col]
	b.batcher(room).add_quad("carpet", p, Vector3.UP, uv, cols, dir)


static func vase(b: ManorBuilder, room: String, pos: Vector3, h: float = 0.35) -> void:
	b.cyl(room, "porcelain", pos, 0.07, 0.12, h * 0.45, 10, false, Color(0.55, 0.62, 0.7))
	b.cyl(room, "porcelain", pos + Vector3(0, h * 0.45, 0), 0.12, 0.05, h * 0.4, 10, false, Color(0.55, 0.62, 0.7))
	b.cyl(room, "porcelain", pos + Vector3(0, h * 0.85, 0), 0.05, 0.07, h * 0.15, 10, false, Color(0.55, 0.62, 0.7))
	for i: int in range(3):
		var a := float(i) * 2.1
		b.cyl_xf(room, "bark", Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 0.3), pos + Vector3(0, h, 0)), 0.006, 0.003, 0.35, 4, Color(0.4, 0.35, 0.3))


static func candle_stick(b: ManorBuilder, room: String, pos: Vector3, h: float = 0.2) -> void:
	b.cyl(room, "brass", pos, 0.06, 0.02, 0.03, 8)
	b.cyl(room, "brass", pos + Vector3(0, 0.03, 0), 0.015, 0.015, 0.12, 6)
	b.cyl(room, "wax", pos + Vector3(0, 0.15, 0), 0.018, 0.018, h * 0.5, 8)


static func cobweb(b: ManorBuilder, room: String, corner: Vector3, dir_a: Vector3, dir_b: Vector3, size: float) -> void:
	# Toile tendue entre deux murs, dans un angle au plafond.
	var p0 := corner
	var p1 := corner + dir_a * size
	var p3 := corner + dir_b * size
	var p2 := corner + (dir_a + dir_b) * size * 0.7 + Vector3(0, -size * 0.3, 0)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	var p: Array[Vector3] = [p0, p1, p2, p3]
	var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var c := Color(1, 1, 1)
	var cols: Array[Color] = [c, c, c, c]
	b.batcher(room).add_quad("cobweb", p, n, uv, cols, dir_a)


static func rubble(b: ManorBuilder, room: String, center: Vector3, radius: float, count: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i: int in range(count):
		var a := rng.randf() * TAU
		var r := rng.randf() * radius
		var s := rng.randf_range(0.08, 0.35)
		var p := center + Vector3(cos(a) * r, s * 0.4, sin(a) * r)
		b.box_xf(room, "rubble" if i % 3 != 0 else "plaster", Transform3D(Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * PI), p), Vector3(s, s * 0.6, s * 0.8), false, Color(0.7, 0.7, 0.7))
	b.collider(room, center + Vector3(0, 0.2, 0), Vector3(radius * 1.4, 0.4, radius * 1.4))


static func tree(bt: MeshBatcher, pos: Vector3, h: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	bt.add_cylinder("bark", Transform3D(Basis.IDENTITY, pos), 0.25, 0.12, h, 7, Color(0.5, 0.5, 0.5))
	for i: int in range(7):
		var y := h * rng.randf_range(0.45, 0.95)
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.0), rng.randf_range(-1, 1)).normalized()
		var basis := Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir)) if absf(dir.y) < 0.99 else Basis.IDENTITY
		bt.add_cylinder("bark", Transform3D(basis, pos + Vector3(0, y, 0)), 0.06, 0.01, h * rng.randf_range(0.25, 0.45), 5, Color(0.45, 0.45, 0.45))
