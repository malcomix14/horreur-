class_name Safe
extends Interactable
## Coffre-fort à code (4 chiffres). Ouvre le pavé numérique (KeypadUI).

var code: String = "1403"
var door_pivot: Node3D
var key_pickup: Pickup
var _door_body: StaticBody3D


func setup(p_code: String) -> void:
	code = p_code
	prompt = "Utiliser le coffre-fort"
	var b := MeshBatcher.new()
	b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), Vector3(0.62, 0.8, 0.55), Color(0.9, 0.9, 0.9), 2.0, false, MeshBatcher.FACE_ALL, 0.6)
	b.add_box("black", Transform3D(Basis.IDENTITY, Vector3(0, 0.42, 0.2)), Vector3(0.5, 0.64, 0.16), Color(0.5, 0.5, 0.5))
	b.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0, 0.83, 0)), Vector3(0.64, 0.05, 0.57))
	make_mesh(b)
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(-0.28, 0.0, 0.28)
	add_child(door_pivot)
	var db := MeshBatcher.new()
	db.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0.28, 0.42, 0.0)), Vector3(0.54, 0.68, 0.05), Color(0.8, 0.8, 0.8), 2.0)
	db.add_cylinder("brass", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.3, 0.5, 0.025)), 0.07, 0.07, 0.03, 16)
	db.add_box("metal", Transform3D(Basis.IDENTITY, Vector3(0.3, 0.3, 0.035)), Vector3(0.14, 0.1, 0.02))
	db.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0.48, 0.42, 0.04)), Vector3(0.03, 0.14, 0.03))
	make_mesh(db, door_pivot)
	key_pickup = Pickup.new()
	key_pickup.setup("key_silver", "key_silver")
	key_pickup.checkpoint = true
	key_pickup.scare_trigger = "pickup_key_silver"
	key_pickup.pickup_message = "Une clé d'argent, gravée d'un A. Aurèle..."
	add_child(key_pickup)
	key_pickup.position = Vector3(0, 0.11, 0.19)
	key_pickup.active = false
	# Corps solide (partie arrière) + façade détectable. La cavité avant reste libre pour la clé.
	var solid := add_detect_box(Vector3(0.62, 0.8, 0.34), Vector3(0, 0.4, -0.1), true)
	solid.collision_layer = Layers.WORLD
	_door_body = add_detect_box(Vector3(0.62, 0.8, 0.08), Vector3(0, 0.42, 0.29), true)
	if GameManager.get_flag("safe_open"):
		door_pivot.rotation.y = -1.9
		key_pickup.active = true
		_door_body.collision_layer = 0


func get_prompt(_player: Player) -> String:
	if GameManager.get_flag("safe_open"):
		return "Coffre-fort (ouvert)"
	return "Utiliser le coffre-fort"


func can_interact(_player: Player) -> bool:
	return not GameManager.get_flag("safe_open")


func interact(_player: Player) -> void:
	AudioManager.play_2d("safe_beep", -6.0)
	Events.keypad_requested.emit(self)


## Appelé par l'interface du pavé numérique.
func try_code(entered: String) -> bool:
	if entered != code:
		AudioManager.play_2d("safe_error", -4.0)
		return false
	GameManager.set_flag("safe_open")
	AudioManager.play_3d("safe_open", global_position + Vector3(0, 0.5, 0), 0.0)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(door_pivot, "rotation:y", -1.9, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_door_body.collision_layer = 0
		if is_instance_valid(key_pickup):
			key_pickup.active = true)
	noise(5.0, "safe")
	Events.checkpoint_requested.emit()
	return true
