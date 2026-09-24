class_name Drawer
extends Interactable
## Tiroir coulissant. Les objets placés en enfants du nœud `tray` suivent le tiroir
## et ne deviennent ramassables qu'une fois le tiroir ouvert.
## Repère local : origine au centre de la façade du tiroir (fermé), +Z = vers la pièce.

var is_open: bool = false
var slide: float = 0.32
var scare_trigger: String = ""
var tray: Node3D
var visual_nodes: Array[Node3D] = []
var _tween: Tween
var _width: float = 0.5
var _height: float = 0.16
var _depth: float = 0.4


func setup(w: float, h: float, d: float, wood: String = "wood_dark") -> void:
	_width = w
	_height = h
	_depth = d
	slide = d * 0.8
	prompt = "Ouvrir le tiroir"
	tray = Node3D.new()
	add_child(tray)
	var b := MeshBatcher.new()
	var uv := Assets.uv_scale(wood)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.01)), Vector3(w, h, 0.025), Color(0.85, 0.85, 0.85), uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, -h * 0.5 + 0.01, -d * 0.5)), Vector3(w - 0.04, 0.012, d), Color(0.5, 0.5, 0.5), uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.02, -h * 0.2, -d * 0.5)), Vector3(0.012, h * 0.6, d), Color(0.6, 0.6, 0.6), uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - 0.02, -h * 0.2, -d * 0.5)), Vector3(0.012, h * 0.6, d), Color(0.6, 0.6, 0.6), uv)
	b.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, -h * 0.2, -d + 0.01)), Vector3(w - 0.04, h * 0.6, 0.012), Color(0.6, 0.6, 0.6), uv)
	b.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.015)), Vector3(0.1, 0.018, 0.018))
	make_mesh(b, tray)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.INTERACT
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, h, 0.05)
	cs.shape = sh
	body.add_child(cs)
	tray.add_child(body)


## Ajoute un objet dans le tiroir (position locale au fond du tiroir).
func put_inside(node: Interactable, local_pos: Vector3) -> void:
	tray.add_child(node)
	node.position = Vector3(local_pos.x, -_height * 0.5 + 0.02, -_depth * 0.5 + local_pos.z)
	node.active = false


func get_prompt(_player: Player) -> String:
	return "Fermer le tiroir" if is_open else "Ouvrir le tiroir"


func interact(_player: Player) -> void:
	is_open = not is_open
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(tray, "position:z", slide if is_open else 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	AudioManager.play_3d("creak_3", global_position, -8.0, 1.6, 12.0, 2.0)
	noise(1.5, "drawer")
	for child: Node in tray.get_children():
		if child is Interactable:
			(child as Interactable).active = is_open
	if is_open and scare_trigger != "":
		var trig := scare_trigger
		scare_trigger = ""
		Events.scare_trigger.emit(trig, self)


## Effet visuel de screamer (main qui jaillit du tiroir).
func play_scare_visual(effect: String, _duration: float) -> void:
	if effect != "hand":
		return
	for n: Node3D in visual_nodes:
		n.visible = true
		var base_z := n.position.z
		var tw := create_tween()
		tw.tween_property(n, "position:z", base_z + 0.55, 0.12).set_trans(Tween.TRANS_EXPO)
		tw.tween_interval(0.4)
		tw.tween_property(n, "position:z", base_z, 0.25)
		tw.tween_callback(func() -> void: n.visible = false)
