class_name Fireplace
extends Interactable
## Cheminée du salon. Y brûler le Registre de la Veille libère le Veilleur (vraie fin)...
## mais le met aussi dans une rage folle.
## Repère local : origine au sol au centre du foyer, +Z vers la pièce.

var fire_light: FlickerLight
var particles: CPUParticles3D
var _crackle: AudioStreamPlayer3D
var _logs_glow: MeshInstance3D


func setup() -> void:
	prompt = "Examiner la cheminée"
	var b := MeshBatcher.new()
	# Manteau et jambages en marbre, foyer en brique noircie.
	b.add_box("marble_white", Transform3D(Basis.IDENTITY, Vector3(-0.85, 0.6, 0.12)), Vector3(0.3, 1.2, 0.3), Color(0.7, 0.68, 0.65))
	b.add_box("marble_white", Transform3D(Basis.IDENTITY, Vector3(0.85, 0.6, 0.12)), Vector3(0.3, 1.2, 0.3), Color(0.7, 0.68, 0.65))
	b.add_box("marble_white", Transform3D(Basis.IDENTITY, Vector3(0, 1.28, 0.15)), Vector3(2.1, 0.16, 0.42), Color(0.7, 0.68, 0.65))
	b.add_box("marble_white", Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0.12)), Vector3(1.4, 0.22, 0.3), Color(0.7, 0.68, 0.65))
	b.add_box("soot", Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -0.12)), Vector3(1.45, 1.0, 0.05))
	b.add_box("soot", Transform3D(Basis.IDENTITY, Vector3(-0.68, 0.5, 0.02)), Vector3(0.05, 1.0, 0.3))
	b.add_box("soot", Transform3D(Basis.IDENTITY, Vector3(0.68, 0.5, 0.02)), Vector3(0.05, 1.0, 0.3))
	b.add_box("soot", Transform3D(Basis.IDENTITY, Vector3(0, 0.99, 0.02)), Vector3(1.4, 0.04, 0.3))
	b.add_box("stone_dark", Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.35)), Vector3(2.2, 0.04, 0.9), Color(0.5, 0.5, 0.5))
	b.add_box("brick", Transform3D(Basis.IDENTITY, Vector3(0, 2.4, 0.0)), Vector3(1.6, 2.1, 0.3), Color(0.8, 0.8, 0.8))
	# Chenets et bûches.
	b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.1, 0.05)), Vector3(0.04, 0.2, 0.35))
	b.add_box("iron_black", Transform3D(Basis.IDENTITY, Vector3(0.3, 0.1, 0.05)), Vector3(0.04, 0.2, 0.35))
	b.add_cylinder("bark", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0.4, 0.16, 0.0)), 0.07, 0.07, 0.8, 8)
	b.add_cylinder("bark", Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5).rotated(Vector3.UP, 0.3), Vector3(0.35, 0.28, 0.08)), 0.06, 0.06, 0.7, 8)
	# Objets sur le manteau.
	b.add_cylinder("brass", Transform3D(Basis.IDENTITY, Vector3(-0.7, 1.36, 0.15)), 0.05, 0.03, 0.25, 8)
	b.add_cylinder("brass", Transform3D(Basis.IDENTITY, Vector3(0.7, 1.36, 0.15)), 0.05, 0.03, 0.25, 8)
	b.add_box("wood_black", Transform3D(Basis.IDENTITY, Vector3(0, 1.52, 0.1)), Vector3(0.35, 0.32, 0.14))
	b.add_cylinder("porcelain", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.55, 0.18)), 0.1, 0.1, 0.01, 16)
	make_mesh(b)
	var gb := MeshBatcher.new()
	gb.add_box("ember", Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0.02)), Vector3(0.7, 0.06, 0.25))
	_logs_glow = make_mesh(gb)
	particles = CPUParticles3D.new()
	particles.amount = 26
	particles.lifetime = 0.8
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.3, 0.05, 0.1)
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.gravity = Vector3(0, 1.2, 0)
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.5
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.4)
	q.material = Assets.mat("flame_particle")
	particles.mesh = q
	particles.position = Vector3(0, 0.18, 0.02)
	particles.emitting = false
	add_child(particles)
	fire_light = FlickerLight.new()
	fire_light.setup(Color(1.0, 0.55, 0.25), 2.2, 8.0, FlickerLight.Mode.FIRE)
	fire_light.position = Vector3(0, 0.7, 0.6)
	add_child(fire_light)
	add_detect_box(Vector3(2.1, 1.3, 0.6), Vector3(0, 0.65, 0.2), true)
	fire_light.set_switched(false)
	_logs_glow.visible = false


func _set_fire(on: bool) -> void:
	particles.emitting = on
	fire_light.set_switched(on)
	_logs_glow.visible = on
	if on and _crackle == null and is_inside_tree():
		_crackle = AudioManager.make_emitter("fire_loop", self, -4.0, 3.0, 18.0)
		_crackle.position = Vector3(0, 0.4, 0.3)


func _ready() -> void:
	_set_fire(GameManager.get_flag("register_burned"))


func get_prompt(_player: Player) -> String:
	if GameManager.has_item("register") and not GameManager.get_flag("register_burned"):
		return "Brûler le Registre de la Veille"
	return "Examiner la cheminée"


func interact(_player: Player) -> void:
	if GameManager.get_flag("register_burned"):
		say("Le registre n'est plus que cendres. Le feu crépite doucement.")
		return
	if GameManager.has_item("register"):
		if not GameManager.has_item("matches"):
			say("Il me faut de quoi allumer un feu.")
			return
		GameManager.remove_item("register")
		GameManager.set_flag("register_burned")
		AudioManager.play_3d("match", global_position + Vector3(0, 0.4, 0.3), 0.0)
		_set_fire(true)
		Events.register_burned.emit()
		Events.checkpoint_requested.emit()
		say("Les pages se tordent dans les flammes... Quelque part, un hurlement déchire la maison.", 5.0)
		GameManager.set_objective("Le Veilleur est fou de rage. Fuir par la grande porte avec les quatre clés.")
		return
	if GameManager.has_item("matches"):
		say("Une cheminée froide. Je n'ai rien à y brûler... pour l'instant.")
	else:
		say("Une cheminée pleine de cendres froides.")
