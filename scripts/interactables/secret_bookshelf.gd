class_name SecretBookshelf
extends Node3D
## Bibliothèque pivotante qui masque le cabinet secret d'Aurèle.
## S'ouvre en tirant le « livre rouge » (un ExamineProp relié à open_shelf()).
## Repère local : origine au sol, centre devant l'ouverture ; X le long du mur, +Z vers la bibliothèque.

var shelf_body: AnimatableBody3D
var slide_distance: float = 1.35
## Obstacle invisible lu uniquement par le navmesh : le monstre ne passe pas tant que c'est fermé.
var _nav_blocker: StaticBody3D


func setup() -> void:
	shelf_body = AnimatableBody3D.new()
	shelf_body.collision_layer = Layers.WORLD
	shelf_body.collision_mask = 0
	add_child(shelf_body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 2.5, 0.4)
	cs.shape = sh
	cs.position = Vector3(0, 1.25, 0.2)
	shelf_body.add_child(cs)
	var b := MeshBatcher.new()
	PropFactory.bookshelf_mesh(b, Vector3(0, 0, 0.2), 1.4, 2.5, 0.38, 7)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(func(k: String) -> Material: return Assets.mat(k))
	shelf_body.add_child(mi)
	if GameManager.get_flag("secret_open"):
		shelf_body.position.x = -slide_distance
	else:
		_nav_blocker = StaticBody3D.new()
		_nav_blocker.collision_layer = Layers.NAV_BLOCK
		_nav_blocker.collision_mask = 0
		var bcs := CollisionShape3D.new()
		var bsh := BoxShape3D.new()
		bsh.size = Vector3(1.6, 2.4, 0.6)
		bcs.shape = bsh
		bcs.position = Vector3(0, 1.2, 0.0)
		_nav_blocker.add_child(bcs)
		add_child(_nav_blocker)


func open_shelf() -> void:
	if GameManager.get_flag("secret_open"):
		return
	GameManager.set_flag("secret_open")
	AudioManager.play_3d("lever", global_position + Vector3(0, 1.2, 0.5), 0.0)
	AudioManager.play_3d("creak_2", global_position + Vector3(0, 1.2, 0.5), 0.0, 0.7, 20.0)
	Events.noise_emitted.emit(global_position, 10.0, "shelf")
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(0.5)
	tw.tween_property(shelf_body, "position:x", -slide_distance, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		if _nav_blocker != null:
			remove_child(_nav_blocker)
			_nav_blocker.queue_free()
			_nav_blocker = null
		Events.secret_opened.emit())
	Events.message_requested.emit("Un déclic. La bibliothèque glisse lourdement sur le côté...", 4.0)
