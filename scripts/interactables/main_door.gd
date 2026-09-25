class_name MainDoor
extends Interactable
## La grande porte du manoir, fermée par une serrure à quatre gardes.
## Avec les quatre clés : cinématique de fuite (fin « Évasion » ou « Délivrance »).
## Repère local : origine au sol au centre de l'ouverture, +Z vers l'extérieur (sud).

var _pivots: Array[Node3D] = []
var _key_meshes: Array[MeshInstance3D] = []
var _opening: bool = false


func setup(width: float, height: float) -> void:
	prompt = "Examiner la grande porte"
	var lw := width * 0.5 - 0.02
	for i: int in range(2):
		var left := i == 0
		var pivot := Node3D.new()
		pivot.position = Vector3(-width * 0.5 + 0.01 if left else width * 0.5 - 0.01, 0, 0)
		add_child(pivot)
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_layer = Layers.DOORS | Layers.INTERACT
		body.collision_mask = 0
		var sx := 1.0 if left else -1.0
		body.position = Vector3(sx * lw * 0.5, height * 0.5, 0)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(lw, height, 0.12)
		cs.shape = sh
		body.add_child(cs)
		pivot.add_child(body)
		var b := MeshBatcher.new()
		b.add_box("wood_black", Transform3D.IDENTITY, Vector3(lw, height, 0.1), Color(0.9, 0.9, 0.9))
		for k: int in range(4):
			var y := -height * 0.5 + 0.4 + float(k) * (height - 0.8) / 3.0
			b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, y, 0.055)), Vector3(lw, 0.08, 0.012))
			b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, y, -0.055)), Vector3(lw, 0.08, 0.012))
			for r: int in range(4):
				var rx := -lw * 0.5 + 0.12 + float(r) * (lw - 0.24) / 3.0
				b.add_sphere("iron_black", Vector3(rx, y, -0.065), Vector3(0.018, 0.018, 0.012), Color.WHITE, 6, 4)
		b.add_box("wood_dark", Transform3D(Basis.IDENTITY, Vector3(0, 0.3, -0.055)), Vector3(lw - 0.2, height * 0.35, 0.012), Color(0.6, 0.6, 0.6))
		b.add_box("wood_dark", Transform3D(Basis.IDENTITY, Vector3(0, -0.8, -0.055)), Vector3(lw - 0.2, height * 0.25, 0.012), Color(0.6, 0.6, 0.6))
		var mi := MeshInstance3D.new()
		mi.mesh = b.build(func(k2: String) -> Material: return Assets.mat(k2))
		body.add_child(mi)
		_pivots.append(pivot)
	# Plaque de serrure à quatre trous (côté intérieur, -Z).
	var pb := MeshBatcher.new()
	pb.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0, 1.3, -0.08)), Vector3(0.3, 0.46, 0.02))
	var holes: Array[Vector3] = [Vector3(-0.07, 1.42, -0.092), Vector3(0.07, 1.42, -0.092), Vector3(-0.07, 1.2, -0.092), Vector3(0.07, 1.2, -0.092)]
	for h: Vector3 in holes:
		pb.add_box("black", Transform3D(Basis.IDENTITY, h), Vector3(0.018, 0.045, 0.004))
	var plate := MeshInstance3D.new()
	plate.mesh = pb.build(func(k: String) -> Material: return Assets.mat(k))
	add_child(plate)
	var key_ids: Array[String] = ["key_iron", "key_silver", "key_brass", "key_bone"]
	for i: int in range(4):
		var km := MeshInstance3D.new()
		km.mesh = ItemVisuals.mesh_for(key_ids[i])
		km.position = holes[i] + Vector3(0, 0, -0.04)
		km.rotation = Vector3(PI * 0.5, PI * 0.5, 0)
		km.visible = false
		add_child(km)
		_key_meshes.append(km)
	add_detect_box(Vector3(width, height, 0.3), Vector3(0, height * 0.5, -0.05))


func get_prompt(_player: Player) -> String:
	var n := GameManager.key_count()
	if n >= 4:
		return "Ouvrir la grande porte (4/4 clés)"
	return "Grande porte (%d/4 clés)" % n


func can_interact(_player: Player) -> bool:
	return not _opening


func interact(_player: Player) -> void:
	var n := GameManager.key_count()
	if not GameManager.get_flag("tried_main_door"):
		GameManager.set_flag("tried_main_door")
	if n < 4:
		AudioManager.play_3d("door_locked", global_position + Vector3(0, 1.3, 0), 0.0)
		noise(4.0, "door")
		say("Une serrure à quatre gardes. Quatre trous, quatre clés : fer, argent, laiton, os. J'en ai %d." % n, 4.5)
		GameManager.set_objective("Trouver les quatre clés de la grande porte (%d/4)." % n)
		return
	_opening = true
	var ending := "delivrance" if GameManager.get_flag("register_burned") else "evasion"
	Events.ending_started.emit(ending)
	var tw := create_tween()
	for i: int in range(4):
		var km := _key_meshes[i]
		tw.tween_callback(func() -> void:
			km.visible = true
			AudioManager.play_3d("key_pickup", global_position + Vector3(0, 1.3, 0), -2.0, 0.8))
		tw.tween_interval(0.45)
	tw.tween_callback(func() -> void:
		AudioManager.play_3d("lever", global_position + Vector3(0, 1.3, 0), 2.0, 0.8)
		AudioManager.play_3d("door_open", global_position + Vector3(0, 1.3, 0), 2.0, 0.7, 30.0))
	tw.tween_interval(0.3)
	tw.set_parallel(true)
	tw.tween_property(_pivots[0], "rotation:y", -1.6, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_pivots[1], "rotation:y", 1.6, 3.0).set_trans(Tween.TRANS_SINE)
