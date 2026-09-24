class_name MeshBatcher
extends RefCounted
## Fusionne des boîtes / quads / cylindres en un seul ArrayMesh (une surface par matériau).
## Moins d'appels de dessin = beaucoup plus rapide sur GPU intégré.
## UV « monde » : la texture se prolonge d'une pièce à l'autre sans raccord visible.
## Couleurs de sommets : utilisées comme occlusion ambiante « cuite » (coins et bas de murs plus sombres).

class Surface:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

# Faces locales d'une boîte : normale, tangente (u), bitangente (v).
const FACE_N: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const FACE_T: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
const FACE_B: Array[Vector3] = [Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(0, -1, 0)]

const FACE_ALL: int = 63
const FACE_PX: int = 1
const FACE_NX: int = 2
const FACE_PY: int = 4
const FACE_NY: int = 8
const FACE_PZ: int = 16
const FACE_NZ: int = 32

var _surfaces: Dictionary = {}
var _order: Array[String] = []


func is_empty() -> bool:
	return _order.is_empty()


func _surf(key: String) -> Surface:
	if _surfaces.has(key):
		return _surfaces[key] as Surface
	var s := Surface.new()
	_surfaces[key] = s
	_order.append(key)
	return s


## Quad quelconque (4 coins dans l'ordre du contour). L'ordre des triangles est
## corrigé automatiquement pour que la face visible soit du côté de `n`.
func add_quad(key: String, p: Array[Vector3], n: Vector3, uv: Array[Vector2], cols: Array[Color], tangent: Vector3) -> void:
	var res := Assets.batch_key(key)
	var s := _surf(str(res[0]))
	var tint: Color = res[1]
	var base := s.verts.size()
	for i: int in range(4):
		s.verts.append(p[i])
		s.normals.append(n)
		s.uvs.append(uv[i])
		s.colors.append(cols[i] * tint)
		s.tangents.append(tangent.x)
		s.tangents.append(tangent.y)
		s.tangents.append(tangent.z)
		s.tangents.append(1.0)
	var cr := (p[1] - p[0]).cross(p[2] - p[0])
	if cr.dot(n) > 0.0:
		s.indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	else:
		s.indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## Quad avec UV projetées dans l'espace monde (tangente/bitangente déduites de la normale).
func add_quad_world(key: String, p: Array[Vector3], n: Vector3, cols: Array[Color], uv_scale: float) -> void:
	var t := world_tangent(n)
	var b := world_bitangent(n)
	var uv: Array[Vector2] = []
	for i: int in range(4):
		uv.append(Vector2(p[i].dot(t), p[i].dot(b)) * uv_scale)
	add_quad(key, p, n, uv, cols, t)


## Rectangle vertical ou horizontal aligné sur les axes, avec dégradé de couleur bas/haut.
func add_rect_world(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col_bottom: Color, col_top: Color, uv_scale: float) -> void:
	var p: Array[Vector3] = [a, b, c, d]
	var cols: Array[Color] = [col_bottom, col_bottom, col_top, col_top]
	add_quad_world(key, p, n, cols, uv_scale)


## Boîte orientée. `xf` : transformation du centre (sans échelle). `size` : dimensions.
## face_uv = true : chaque face reçoit des UV 0..1 (portes, livres, tableaux...).
func add_box(key: String, xf: Transform3D, size: Vector3, color: Color = Color.WHITE, uv_scale: float = 1.0, face_uv: bool = false, faces: int = FACE_ALL, ao_bottom: float = 1.0) -> void:
	var h := size * 0.5
	var basis := xf.basis
	for f: int in range(6):
		if (faces & (1 << f)) == 0:
			continue
		var ln: Vector3 = FACE_N[f]
		var lt: Vector3 = FACE_T[f]
		var lb: Vector3 = FACE_B[f]
		var center := ln * h
		var ext_t := absf(lt.x) * h.x + absf(lt.y) * h.y + absf(lt.z) * h.z
		var ext_b := absf(lb.x) * h.x + absf(lb.y) * h.y + absf(lb.z) * h.z
		var lc: Array[Vector3] = [
			center - lt * ext_t - lb * ext_b,
			center + lt * ext_t - lb * ext_b,
			center + lt * ext_t + lb * ext_b,
			center - lt * ext_t + lb * ext_b,
		]
		var wn := (basis * ln).normalized()
		var wt := (basis * lt).normalized()
		var wb := (basis * lb).normalized()
		var p: Array[Vector3] = []
		var uv: Array[Vector2] = []
		var cols: Array[Color] = []
		for i: int in range(4):
			var wp := xf * lc[i]
			p.append(wp)
			if face_uv:
				var u := (lc[i].dot(lt) / ext_t) * 0.5 + 0.5 if ext_t > 0.0 else 0.0
				var v := (lc[i].dot(lb) / ext_b) * 0.5 + 0.5 if ext_b > 0.0 else 0.0
				uv.append(Vector2(u, v))
			else:
				uv.append(Vector2(wp.dot(wt), wp.dot(wb)) * uv_scale)
			var c := color
			if ao_bottom < 1.0 and lc[i].y < 0.0:
				c = Color(color.r * ao_bottom, color.g * ao_bottom, color.b * ao_bottom, color.a)
			cols.append(c)
		add_quad(key, p, wn, uv, cols, wt)


## Cylindre (ou cône) vertical dans le repère `xf` : base à l'origine locale, axe +Y.
func add_cylinder(key: String, xf: Transform3D, r_bottom: float, r_top: float, height: float, segments: int, color_in: Color = Color.WHITE, caps: bool = true, uv_scale: float = 1.0) -> void:
	var res := Assets.batch_key(key)
	var s := _surf(str(res[0]))
	var color: Color = color_in * (res[1] as Color)
	var basis := xf.basis
	var circ := TAU * maxf(r_bottom, r_top)
	for i: int in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p0 := xf * (d0 * r_bottom)
		var p1 := xf * (d1 * r_bottom)
		var p2 := xf * (d1 * r_top + Vector3(0, height, 0))
		var p3 := xf * (d0 * r_top + Vector3(0, height, 0))
		var slope := (r_bottom - r_top) / maxf(height, 0.001)
		var n0 := (basis * (d0 + Vector3(0, slope, 0))).normalized()
		var n1 := (basis * (d1 + Vector3(0, slope, 0))).normalized()
		var u0 := float(i) / float(segments) * circ * uv_scale
		var u1 := float(i + 1) / float(segments) * circ * uv_scale
		var base := s.verts.size()
		var pts: Array[Vector3] = [p0, p1, p2, p3]
		var ns: Array[Vector3] = [n0, n1, n1, n0]
		var uvs: Array[Vector2] = [Vector2(u0, height * uv_scale), Vector2(u1, height * uv_scale), Vector2(u1, 0.0), Vector2(u0, 0.0)]
		var tng := (basis * Vector3(-sin(a0), 0.0, cos(a0))).normalized()
		for k: int in range(4):
			s.verts.append(pts[k])
			s.normals.append(ns[k])
			s.uvs.append(uvs[k])
			s.colors.append(color)
			s.tangents.append(tng.x)
			s.tangents.append(tng.y)
			s.tangents.append(tng.z)
			s.tangents.append(1.0)
		var mid_n := (n0 + n1).normalized()
		var cr := (p1 - p0).cross(p2 - p0)
		if r_bottom <= 0.0001:
			cr = (p2 - p1).cross(p3 - p1)
		if cr.dot(mid_n) > 0.0:
			s.indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
		else:
			s.indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	if caps:
		if r_top > 0.0001:
			_add_disc(s, xf, r_top, height, segments, color, true, uv_scale)
		if r_bottom > 0.0001:
			_add_disc(s, xf, r_bottom, 0.0, segments, color, false, uv_scale)


func _add_disc(s: Surface, xf: Transform3D, r: float, y: float, segments: int, color: Color, up: bool, uv_scale: float) -> void:
	var n := (xf.basis * (Vector3.UP if up else Vector3.DOWN)).normalized()
	var center := xf * Vector3(0, y, 0)
	var ci := s.verts.size()
	var tng := (xf.basis * Vector3.RIGHT).normalized()
	s.verts.append(center)
	s.normals.append(n)
	s.uvs.append(Vector2(0.5, 0.5))
	s.colors.append(color)
	s.tangents.append_array(PackedFloat32Array([tng.x, tng.y, tng.z, 1.0]))
	for i: int in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		var lp := Vector3(cos(a) * r, y, sin(a) * r)
		s.verts.append(xf * lp)
		s.normals.append(n)
		s.uvs.append(Vector2(cos(a) * r, sin(a) * r) * uv_scale + Vector2(0.5, 0.5))
		s.colors.append(color)
		s.tangents.append_array(PackedFloat32Array([tng.x, tng.y, tng.z, 1.0]))
	for i: int in range(segments):
		var a := ci + 1 + i
		var b := ci + 2 + i
		var cr := (s.verts[a] - center).cross(s.verts[b] - center)
		if cr.dot(n) > 0.0:
			s.indices.append_array(PackedInt32Array([ci, b, a]))
		else:
			s.indices.append_array(PackedInt32Array([ci, a, b]))


## Sphère basse définition (étirable via `radii`).
func add_sphere(key: String, center: Vector3, radii: Vector3, color_in: Color = Color.WHITE, segments: int = 10, rings: int = 6) -> void:
	var res := Assets.batch_key(key)
	var s := _surf(str(res[0]))
	var color: Color = color_in * (res[1] as Color)
	var base := s.verts.size()
	for r: int in range(rings + 1):
		var v := float(r) / float(rings)
		var phi := v * PI
		for i: int in range(segments + 1):
			var u := float(i) / float(segments)
			var th := u * TAU
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			s.verts.append(center + dir * radii)
			s.normals.append((dir / radii).normalized())
			s.uvs.append(Vector2(u, v))
			s.colors.append(color)
			s.tangents.append_array(PackedFloat32Array([-sin(th), 0.0, cos(th), 1.0]))
	for r: int in range(rings):
		for i: int in range(segments):
			var a := base + r * (segments + 1) + i
			var b := a + segments + 1
			s.indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))


func build(material_provider: Callable) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var idx := 0
	for key: String in _order:
		var s := _surfaces[key] as Surface
		if s.indices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.normals
		arrays[Mesh.ARRAY_TANGENT] = s.tangents
		arrays[Mesh.ARRAY_TEX_UV] = s.uvs
		arrays[Mesh.ARRAY_COLOR] = s.colors
		arrays[Mesh.ARRAY_INDEX] = s.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m: Variant = material_provider.call(key)
		if m is Material:
			mesh.surface_set_material(idx, m as Material)
		idx += 1
	return mesh


static func world_tangent(n: Vector3) -> Vector3:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	if ay >= ax and ay >= az:
		return Vector3(1, 0, 0)
	if ax >= az:
		return Vector3(0, 0, -signf(n.x))
	return Vector3(signf(n.z), 0, 0)


static func world_bitangent(n: Vector3) -> Vector3:
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	if ay >= ax and ay >= az:
		return Vector3(0, 0, signf(n.y))
	return Vector3(0, -1, 0)
