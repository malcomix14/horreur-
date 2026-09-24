class_name FuseBox
extends Interactable
## Boîtier électrique de la cave. Il manque un fusible : une fois posé, le courant revient
## (lumières de la cave + monte-charge).

var _fuse_mesh: MeshInstance3D
var _indicator: MeshInstance3D


func setup() -> void:
	prompt = "Examiner le boîtier électrique"
	var b := MeshBatcher.new()
	b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.09)), Vector3(0.5, 0.65, 0.18), Color(0.8, 0.8, 0.8), 2.0)
	b.add_box("black", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.181)), Vector3(0.42, 0.57, 0.004))
	b.add_box("iron_black", Transform3D(Basis(Vector3.UP, -1.9), Vector3(0.38, 0, 0.26)), Vector3(0.48, 0.63, 0.02), Color(0.7, 0.7, 0.7), 2.0)
	for i: int in range(3):
		var y := 0.15 - float(i) * 0.14
		b.add_box("porcelain", Transform3D(Basis.IDENTITY, Vector3(-0.08, y, 0.2)), Vector3(0.1, 0.05, 0.04))
		if i != 1:
			b.add_cylinder("porcelain", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.03, y, 0.22)), 0.015, 0.015, 0.1, 8)
	b.add_box("metal", Transform3D(Basis.IDENTITY, Vector3(0.12, -0.05, 0.21)), Vector3(0.05, 0.2, 0.03))
	make_mesh(b)
	var fb := MeshBatcher.new()
	fb.add_cylinder("porcelain", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.03, 0.01, 0.22)), 0.015, 0.015, 0.1, 8)
	fb.add_cylinder("brass", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.025, 0.01, 0.22)), 0.017, 0.017, 0.012, 8)
	_fuse_mesh = make_mesh(fb)
	var ib := MeshBatcher.new()
	ib.add_sphere("bulb", Vector3(0.12, 0.22, 0.2), Vector3(0.018, 0.018, 0.018))
	_indicator = make_mesh(ib)
	add_detect_box(Vector3(0.6, 0.75, 0.35), Vector3(0, 0, 0.15))
	_apply_state()


func _apply_state() -> void:
	var on := GameManager.get_flag("power_on")
	_fuse_mesh.visible = on
	_indicator.visible = on


func interact(_player: Player) -> void:
	if GameManager.get_flag("power_on"):
		say("Le courant est rétabli. Un bourdonnement sourd emplit la cave.")
		return
	if GameManager.has_item("fuse"):
		GameManager.remove_item("fuse")
		GameManager.set_flag("power_on")
		_apply_state()
		AudioManager.play_3d("fuse", global_position, 0.0)
		AudioManager.play_3d("power_on", global_position, -2.0, 1.0, 30.0)
		noise(9.0, "machine")
		Events.power_restored.emit("cellar")
		Events.camera_shake.emit(0.15)
		say("Le fusible s'enclenche. Les ampoules de la cave grésillent et s'allument.", 4.0)
		GameManager.set_objective("Le courant est revenu. Le monte-charge de la cave devrait fonctionner.")
		Events.checkpoint_requested.emit()
	else:
		AudioManager.play_3d("door_locked", global_position, -8.0, 1.5)
		say("Un boîtier électrique. Un des fusibles manque : il faudrait un fusible de rechange.", 4.0)
