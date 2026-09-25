class_name Candle
extends Interactable
## Grand chandelier de la chapelle (énigme des cierges). La plaque indique le rôle.

var role: String = ""
var lit: bool = false
var puzzle: CandlePuzzle
var light: FlickerLight
var _flames: Array[Node3D] = []


func setup(p_role: String, plaque_text: String, p_puzzle: CandlePuzzle) -> void:
	role = p_role
	puzzle = p_puzzle
	prompt = "Allumer le cierge"
	var b := MeshBatcher.new()
	b.add_cylinder("iron_black", Transform3D.IDENTITY, 0.18, 0.12, 0.05, 10)
	b.add_cylinder("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), 0.025, 0.025, 1.15, 8)
	b.add_cylinder("iron_black", Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0)), 0.09, 0.13, 0.05, 10)
	b.add_cylinder("wax", Transform3D(Basis.IDENTITY, Vector3(0, 1.25, 0)), 0.04, 0.04, 0.32, 10)
	b.add_cylinder("wax", Transform3D(Basis.IDENTITY, Vector3(0.1, 1.25, 0)), 0.025, 0.025, 0.2, 8)
	b.add_cylinder("wax", Transform3D(Basis.IDENTITY, Vector3(-0.1, 1.25, 0)), 0.025, 0.025, 0.16, 8)
	b.add_box("brass", Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.55, 0.14)), Vector3(0.3, 0.12, 0.015))
	make_mesh(b)
	var tops: Array[Vector3] = [Vector3(0, 1.62, 0), Vector3(0.1, 1.5, 0), Vector3(-0.1, 1.46, 0)]
	for p: Vector3 in tops:
		var f := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.09)
		f.mesh = q
		f.material_override = Assets.mat("flame")
		f.position = p
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		_flames.append(f)
	var lab := Label3D.new()
	lab.text = plaque_text
	lab.font = Assets.font_serif()
	lab.font_size = 48
	lab.pixel_size = 0.0014
	lab.modulate = Color(0.12, 0.08, 0.04)
	lab.outline_size = 0
	lab.position = Vector3(0, 0.55, 0.15)
	lab.rotation.x = -0.5
	lab.shaded = true
	add_child(lab)
	light = FlickerLight.new()
	light.setup(Color(1.0, 0.7, 0.4), 1.1, 6.5, FlickerLight.Mode.CANDLE)
	light.position = Vector3(0, 1.75, 0)
	light.glow_nodes = _flames.duplicate()
	add_child(light)
	add_detect_box(Vector3(0.4, 1.8, 0.4), Vector3(0, 0.9, 0), true)
	set_lit(false)


func set_lit(on: bool) -> void:
	lit = on
	light.set_switched(on)
	for f: Node3D in _flames:
		f.visible = on


func get_prompt(_player: Player) -> String:
	if lit:
		return "Cierge allumé"
	return "Allumer le cierge"


func interact(_player: Player) -> void:
	if puzzle.solved:
		say("Les cierges brûlent calmement.")
		return
	if lit:
		return
	if not GameManager.has_item("matches"):
		say("Un grand cierge éteint. Il me faudrait des allumettes.")
		return
	puzzle.light_candle(self)
