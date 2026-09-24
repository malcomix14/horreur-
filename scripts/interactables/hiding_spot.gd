class_name HidingSpot
extends Interactable
## Cachette : armoire à persiennes, placard, dessous de lit, confessionnal.
## Repère local : origine au sol au centre du meuble, +Z = face avant (côté pièce).
## Le monstre ne voit pas un joueur caché... sauf s'il l'a vu entrer (cachette « compromise »).

var kind: String = "wardrobe"
var label: String = "l'armoire"
var occupied: bool = false
var compromised: bool = false
var eye_local: Transform3D = Transform3D.IDENTITY
var exit_local: Vector3 = Vector3(0, 0, 1.0)
var yaw_limit: float = 0.55
var pitch_limit: float = 0.35

var _door_pivots: Array[Node3D] = []
var _door_signs: Array[float] = []
var _tween: Tween


func setup(p_kind: String, wood: String = "wood_dark", fabric: String = "fabric_red", width: float = 1.2) -> void:
	kind = p_kind
	add_to_group("hiding_spots")
	match kind:
		"bed":
			_build_bed(wood, fabric)
			label = "sous le lit"
		"confessional":
			_build_confessional(wood, fabric)
			label = "dans le confessionnal"
		"closet":
			_build_wardrobe(wood, width, true)
			label = "dans le placard"
		_:
			_build_wardrobe(wood, width, false)
			label = "dans l'armoire"


func get_prompt(_player: Player) -> String:
	return "Sortir" if occupied else "Se cacher %s" % label


func interact(player: Player) -> void:
	if occupied:
		player.exit_hiding()
	else:
		player.enter_hiding(self)


func eye_global() -> Transform3D:
	return global_transform * eye_local


func exit_global() -> Vector3:
	return global_transform * exit_local


## Point où le monstre se place pour fouiller la cachette.
func search_point() -> Vector3:
	return global_transform * (exit_local + Vector3(0, 0, 0.25))


func play_enter() -> void:
	_swing(0.5, 0.25)


func play_exit() -> void:
	_swing(1.2, 0.9)


## Le monstre arrache la porte / le rideau pour sortir le joueur.
func play_yank() -> void:
	_swing(1.6, 1.5)
	AudioManager.play_3d("door_bash", global_position + Vector3(0, 1.2, 0), 1.0)


func _swing(angle: float, hold: float) -> void:
	if _door_pivots.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	for i: int in range(_door_pivots.size()):
		_tween.tween_property(_door_pivots[i], "rotation:y", angle * _door_signs[i], 0.25).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_interval(hold)
	_tween.set_parallel(true)
	for i: int in range(_door_pivots.size()):
		_tween.tween_property(_door_pivots[i], "rotation:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------ modèles

func _build_wardrobe(wood: String, w: float, single: bool) -> void:
	var h := 2.15
	var d := 0.62
	var b := MeshBatcher.new()
	var uv := Assets.uv_scale(wood)
	var c := Color(0.9, 0.9, 0.9)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, -d * 0.5 + 0.015)), Vector3(w, h, 0.03), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.02, h * 0.5, 0)), Vector3(0.04, h, d), c, uv, false, MeshBatcher.FACE_ALL, 0.7)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - 0.02, h * 0.5, 0)), Vector3(0.04, h, d), c, uv, false, MeshBatcher.FACE_ALL, 0.7)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, h - 0.025, 0)), Vector3(w, 0.05, d), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Vector3(w, 0.1, d), c * 0.7, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, h + 0.05, 0.02)), Vector3(w + 0.1, 0.1, d + 0.08), c, uv)
	b.add_box("black", Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, -d * 0.5 + 0.035)), Vector3(w - 0.1, h - 0.2, 0.005), Color(0.3, 0.3, 0.3))
	b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, h - 0.25, 0.0)), Vector3(w - 0.1, 0.02, 0.02))
	make_mesh(b)
	var n_doors := 1 if single else 2
	var dw := (w - 0.08) / float(n_doors)
	for i: int in range(n_doors):
		var left := i == 0
		var pivot := Node3D.new()
		pivot.position = Vector3(-w * 0.5 + 0.04 if left else w * 0.5 - 0.04, 0.0, d * 0.5)
		add_child(pivot)
		var db := MeshBatcher.new()
		var sx := 1.0 if left else -1.0
		var cx := dw * 0.5 * sx
		db.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(cx - sx * (dw * 0.5 - 0.035), 1.05, 0)), Vector3(0.07, 1.9, 0.03), c, uv)
		db.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(cx + sx * (dw * 0.5 - 0.035), 1.05, 0)), Vector3(0.07, 1.9, 0.03), c, uv)
		db.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(cx, 1.97, 0)), Vector3(dw, 0.07, 0.03), c, uv)
		db.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(cx, 0.3, 0)), Vector3(dw, 0.4, 0.03), c, uv)
		db.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(cx, 0.52, 0)), Vector3(dw, 0.05, 0.03), c, uv)
		var y := 0.62
		while y < 1.92:
			db.add_box(wood, Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(cx, y, 0)), Vector3(dw - 0.12, 0.012, 0.075), c * 0.85, uv)
			y += 0.085
		db.add_sphere("brass", Vector3(cx + sx * (dw * 0.5 - 0.1), 1.1, 0.03), Vector3(0.022, 0.022, 0.022), Color.WHITE, 6, 4)
		make_mesh(db, pivot)
		_door_pivots.append(pivot)
		_door_signs.append(1.0 if left else -1.0)
	add_detect_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), true)
	eye_local = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.58, 0.0))
	exit_local = Vector3(0, 0, d * 0.5 + 0.55)


func _build_bed(wood: String, fabric: String) -> void:
	var L := 2.1
	var W := 1.5
	var b := MeshBatcher.new()
	var uv := Assets.uv_scale(wood)
	var c := Color(0.9, 0.9, 0.9)
	for sx: int in range(2):
		for sz: int in range(2):
			var lx := (L * 0.5 - 0.05) * (1.0 if sx == 0 else -1.0)
			var lz := (W * 0.5 - 0.05) * (1.0 if sz == 0 else -1.0)
			b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(lx, 0.22, lz)), Vector3(0.09, 0.44, 0.09), c, uv, false, MeshBatcher.FACE_ALL, 0.6)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.38, W * 0.5 - 0.03)), Vector3(L, 0.14, 0.05), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.38, -W * 0.5 + 0.03)), Vector3(L, 0.14, 0.05), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.44, 0)), Vector3(L - 0.1, 0.03, W - 0.1), c * 0.5, uv)
	b.add_box("fabric_cream", Transform3D(Basis.IDENTITY, Vector3(0, 0.56, 0)), Vector3(L - 0.12, 0.2, W - 0.12), Color(0.85, 0.85, 0.85), 3.0)
	b.add_box(fabric, Transform3D(Basis.IDENTITY, Vector3(0.15, 0.665, 0)), Vector3(L - 0.4, 0.04, W + 0.04), Color(0.85, 0.85, 0.85), 3.0)
	b.add_box(fabric, Transform3D(Basis.IDENTITY, Vector3(0.15, 0.56, W * 0.5 + 0.03)), Vector3(L - 0.4, 0.2, 0.02), Color(0.75, 0.75, 0.75), 3.0)
	b.add_box(fabric, Transform3D(Basis.IDENTITY, Vector3(0.15, 0.56, -W * 0.5 - 0.03)), Vector3(L - 0.4, 0.2, 0.02), Color(0.75, 0.75, 0.75), 3.0)
	b.add_box("fabric_cream", Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(-L * 0.5 + 0.3, 0.72, 0.33)), Vector3(0.35, 0.1, 0.55), c, 3.0)
	b.add_box("fabric_cream", Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(-L * 0.5 + 0.3, 0.72, -0.33)), Vector3(0.35, 0.1, 0.55), c, 3.0)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(-L * 0.5, 0.75, 0)), Vector3(0.08, 1.5, W + 0.04), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(-L * 0.5, 1.55, 0)), Vector3(0.12, 0.1, W + 0.12), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(L * 0.5, 0.5, 0)), Vector3(0.08, 1.0, W + 0.04), c, uv)
	make_mesh(b)
	add_detect_box(Vector3(L, 0.8, W), Vector3(0, 0.4, 0), true)
	eye_local = Transform3D(Basis(Vector3.UP, PI), Vector3(0.1, 0.22, 0.2))
	exit_local = Vector3(0.1, 0, W * 0.5 + 0.6)
	yaw_limit = 0.7
	pitch_limit = 0.18


func _build_confessional(wood: String, fabric: String) -> void:
	var w := 1.2
	var h := 2.45
	var d := 1.0
	var b := MeshBatcher.new()
	var uv := Assets.uv_scale(wood)
	var c := Color(0.85, 0.85, 0.85)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, -d * 0.5 + 0.03)), Vector3(w, h, 0.06), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.03, h * 0.5, 0)), Vector3(0.06, h, d), c, uv, false, MeshBatcher.FACE_ALL, 0.7)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - 0.03, h * 0.5, 0)), Vector3(0.06, h, d), c, uv, false, MeshBatcher.FACE_ALL, 0.7)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, h, 0.02)), Vector3(w + 0.16, 0.12, d + 0.12), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, h + 0.2, 0.02)), Vector3(0.5, 0.3, 0.1), c, uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.45, -d * 0.5 + 0.2)), Vector3(w - 0.12, 0.08, 0.3), c, uv)
	b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, h - 0.12, d * 0.5 - 0.05)), Vector3(w, 0.025, 0.025))
	b.add_box("black", Transform3D(Basis.IDENTITY, Vector3(0.0, 1.6, -d * 0.5 + 0.065)), Vector3(0.3, 0.3, 0.01))
	make_mesh(b)
	for i: int in range(2):
		var left := i == 0
		var pivot := Node3D.new()
		pivot.position = Vector3(-w * 0.5 + 0.08 if left else w * 0.5 - 0.08, 0.0, d * 0.5 - 0.05)
		add_child(pivot)
		var cb := MeshBatcher.new()
		var sx := 1.0 if left else -1.0
		var cw := w * 0.5 - 0.12
		for k: int in range(4):
			var fold_x := sx * (cw * (float(k) + 0.5) / 4.0)
			var fold_z := 0.03 * (1.0 if k % 2 == 0 else -1.0)
			cb.add_box(fabric, Transform3D(Basis.IDENTITY, Vector3(fold_x, (h - 0.2) * 0.5 + 0.05, fold_z)), Vector3(cw / 4.0 + 0.01, h - 0.3, 0.02), Color(0.8, 0.8, 0.8), 3.0)
		make_mesh(cb, pivot)
		_door_pivots.append(pivot)
		_door_signs.append(1.0 if left else -1.0)
	add_detect_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), true)
	eye_local = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.5, 0.05))
	exit_local = Vector3(0, 0, d * 0.5 + 0.55)
