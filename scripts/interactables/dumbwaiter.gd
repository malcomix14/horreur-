class_name Dumbwaiter
extends Interactable
## Monte-charge de la cave. Sans courant il est bloqué entre deux étages ;
## avec le courant, on l'appelle : il descend (bruyamment) avec la clé de fer.
## Repère local : origine au sol de la cave, au pied du mur, +Z = vers la pièce (vers -X monde).

const DROP: float = 2.6

var cabin: Node3D
var key_pickup: Pickup
var _moving: bool = false
var _hatch_body: StaticBody3D


func setup() -> void:
	prompt = "Appeler le monte-charge"
	# Gaine derrière le mur.
	var b := MeshBatcher.new()
	var wood := "wood_dark"
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 2.2, -0.9)), Vector3(0.9, 3.4, 0.05), Color(0.4, 0.4, 0.4))
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(-0.45, 2.2, -0.5)), Vector3(0.05, 3.4, 0.8), Color(0.4, 0.4, 0.4))
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0.45, 2.2, -0.5)), Vector3(0.05, 3.4, 0.8), Color(0.4, 0.4, 0.4))
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.78, -0.5)), Vector3(0.9, 0.04, 0.8), Color(0.4, 0.4, 0.4))
	# Bouton d'appel.
	b.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0.65, 1.2, 0.01)), Vector3(0.1, 0.16, 0.02))
	b.add_cylinder("black", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.65, 1.22, 0.02)), 0.02, 0.02, 0.015, 8)
	make_mesh(b)
	cabin = Node3D.new()
	add_child(cabin)
	var cb := MeshBatcher.new()
	cb.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.82, -0.45)), Vector3(0.74, 0.03, 0.7), Color(0.8, 0.8, 0.8))
	cb.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 1.58, -0.45)), Vector3(0.74, 0.03, 0.7), Color(0.8, 0.8, 0.8))
	cb.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 1.2, -0.79)), Vector3(0.74, 0.76, 0.02), Color(0.7, 0.7, 0.7))
	cb.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(-0.36, 1.2, -0.45)), Vector3(0.02, 0.76, 0.7), Color(0.7, 0.7, 0.7))
	cb.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0.36, 1.2, -0.45)), Vector3(0.02, 0.76, 0.7), Color(0.7, 0.7, 0.7))
	cb.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, 1.8, -0.45)), Vector3(0.02, 0.4, 0.02))
	make_mesh(cb, cabin)
	key_pickup = Pickup.new()
	key_pickup.setup("key_iron", "key_iron")
	key_pickup.checkpoint = true
	key_pickup.pickup_message = "Une clé de fer, gravée d'un G. La première des quatre."
	cabin.add_child(key_pickup)
	key_pickup.position = Vector3(0.05, 0.84, -0.35)
	key_pickup.active = false
	add_detect_box(Vector3(0.3, 0.3, 0.12), Vector3(0.65, 1.2, 0.05))
	_hatch_body = add_detect_box(Vector3(0.8, 0.8, 0.1), Vector3(0, 1.2, 0.02))
	if GameManager.get_flag("dumbwaiter_down"):
		cabin.position.y = 0.0
		key_pickup.active = true
		_hatch_body.collision_layer = 0
	else:
		cabin.position.y = DROP


func get_prompt(_player: Player) -> String:
	if GameManager.get_flag("dumbwaiter_down"):
		return "Examiner le monte-charge"
	return "Appeler le monte-charge"


func interact(_player: Player) -> void:
	if _moving:
		return
	if GameManager.get_flag("dumbwaiter_down"):
		say("Le monte-charge est descendu." if is_instance_valid(key_pickup) else "Le monte-charge est vide.")
		return
	if not GameManager.get_flag("power_on"):
		AudioManager.play_3d("flash_off", global_position + Vector3(0.65, 1.2, 0), -2.0)
		say("Le bouton ne répond pas. Pas de courant... La cabine est coincée entre deux étages.", 4.0)
		return
	_moving = true
	AudioManager.play_3d("flash_on", global_position + Vector3(0.65, 1.2, 0), -2.0)
	AudioManager.play_3d("elevator", global_position + Vector3(0, 2.0, 0), 3.0, 1.0, 35.0, 5.0)
	noise(16.0, "machine")
	say("Le moteur grince. Le bruit résonne dans toute la maison...", 3.5)
	var tw := create_tween()
	tw.tween_property(cabin, "position:y", 0.0, 3.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_moving = false
		GameManager.set_flag("dumbwaiter_down")
		noise(16.0, "machine")
		Events.camera_shake.emit(0.1)
		_hatch_body.collision_layer = 0
		if is_instance_valid(key_pickup):
			key_pickup.active = true)
