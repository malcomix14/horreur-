class_name Interactable
extends Node3D
## Classe de base de tout objet avec lequel le joueur peut interagir (touche E).
## Le rayon d'interaction touche un corps physique enfant ; on remonte les parents
## jusqu'au premier Interactable.

var prompt: String = "Interagir"
var active: bool = true
var save_id: String = ""


func get_prompt(_player: Player) -> String:
	return prompt


func can_interact(_player: Player) -> bool:
	return active


func interact(_player: Player) -> void:
	pass


## Corps de détection (couche INTERACT). `solid` : bloque aussi le joueur et sert au navmesh.
func add_detect_box(size: Vector3, offset: Vector3 = Vector3.ZERO, solid: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.INTERACT | (Layers.WORLD if solid else 0)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	body.add_child(cs)
	add_child(body)
	return body


func make_mesh(b: MeshBatcher, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(func(k: String) -> Material: return Assets.mat(k))
	# Les petits objets lointains sont invisibles dans le noir et le brouillard : on ne les dessine pas.
	mi.visibility_range_end = 26.0
	if parent == null:
		add_child(mi)
	else:
		parent.add_child(mi)
	return mi


func say(text: String, duration: float = 3.0) -> void:
	Events.message_requested.emit(text, duration)


func noise(radius: float, source: String) -> void:
	Events.noise_emitted.emit(global_position, radius, source)


static func find_from(node: Node) -> Interactable:
	var n := node
	while n != null:
		if n is Interactable:
			return n as Interactable
		n = n.get_parent()
	return null
