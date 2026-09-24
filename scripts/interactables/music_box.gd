class_name MusicBox
extends Interactable
## Boîte à musique de Lise. Il manque la manivelle. Une fois remontée, elle joue
## « Au clair de la lune »... très fort : le Veilleur l'entend. À la fin, un tiroir secret
## s'ouvre et révèle la clé de laiton.

const PLAY_TIME: float = 17.5

var lid: Node3D
var drawer: Node3D
var figure: Node3D
var key_pickup: Pickup
var _playing: bool = false
var _time: float = 0.0
var _noise_timer: float = 0.0
var _scare_sent: bool = false
var _player3d: AudioStreamPlayer3D


func setup() -> void:
	prompt = "Examiner la boîte à musique"
	var b := MeshBatcher.new()
	b.add_box("wood_med", Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Vector3(0.24, 0.1, 0.17), Color(0.9, 0.75, 0.75))
	b.add_box("gold_frame", Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Vector3(0.245, 0.01, 0.175))
	b.add_box("black", Transform3D(Basis.IDENTITY, Vector3(0.121, 0.055, 0)), Vector3(0.004, 0.02, 0.02))
	make_mesh(b)
	lid = Node3D.new()
	lid.position = Vector3(0, 0.105, -0.085)
	add_child(lid)
	var lb := MeshBatcher.new()
	lb.add_box("wood_med", Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.085)), Vector3(0.24, 0.035, 0.17), Color(0.9, 0.75, 0.75))
	lb.add_box("mirror", Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.085)), Vector3(0.2, 0.004, 0.14))
	make_mesh(lb, lid)
	figure = Node3D.new()
	figure.position = Vector3(0, 0.1, 0.01)
	add_child(figure)
	var fb := MeshBatcher.new()
	fb.add_cylinder("porcelain", Transform3D.IDENTITY, 0.025, 0.004, 0.05, 8)
	fb.add_cylinder("porcelain", Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), 0.004, 0.006, 0.03, 6)
	fb.add_sphere("porcelain", Vector3(0, 0.068, 0), Vector3(0.009, 0.01, 0.009))
	fb.add_box("porcelain", Transform3D(Basis.IDENTITY, Vector3(0, 0.055, 0)), Vector3(0.05, 0.003, 0.004))
	make_mesh(fb, figure)
	figure.visible = false
	drawer = Node3D.new()
	add_child(drawer)
	var db := MeshBatcher.new()
	db.add_box("wood_med", Transform3D(Basis.IDENTITY, Vector3(0, 0.025, 0.0)), Vector3(0.2, 0.035, 0.14), Color(0.7, 0.55, 0.55))
	db.add_box("brass", Transform3D(Basis.IDENTITY, Vector3(0, 0.025, 0.072)), Vector3(0.03, 0.008, 0.006))
	make_mesh(db, drawer)
	key_pickup = Pickup.new()
	key_pickup.setup("key_brass", "key_brass")
	key_pickup.checkpoint = true
	key_pickup.pickup_message = "Une petite clé de laiton, gravée d'un L. La clé de Lise."
	add_child(key_pickup)
	key_pickup.position = Vector3(0, 0.0, 0.2)
	key_pickup.visible = false
	key_pickup.active = false
	add_detect_box(Vector3(0.28, 0.16, 0.2), Vector3(0, 0.07, 0))
	if GameManager.get_flag("musicbox_done"):
		lid.rotation.x = -1.6
		figure.visible = true
		drawer.position.z = 0.12
		key_pickup.visible = true
		key_pickup.active = true


func get_prompt(_player: Player) -> String:
	if GameManager.get_flag("musicbox_done"):
		return "Boîte à musique"
	if GameManager.has_item("crank"):
		return "Remonter la boîte à musique"
	return "Examiner la boîte à musique"


func can_interact(_player: Player) -> bool:
	return not _playing


func interact(_player: Player) -> void:
	if GameManager.get_flag("musicbox_done"):
		say("La boîte à musique s'est tue. Une petite danseuse fixe la porte.")
		return
	if not GameManager.has_item("crank"):
		say("Une boîte à musique. Il manque la manivelle pour la remonter.", 3.5)
		return
	GameManager.remove_item("crank")
	_playing = true
	_time = 0.0
	_noise_timer = 0.0
	AudioManager.play_3d("lever", global_position, -10.0, 2.0, 10.0, 1.0)
	var tw := create_tween()
	tw.tween_property(lid, "rotation:x", -1.6, 1.0).set_trans(Tween.TRANS_SINE)
	figure.visible = true
	_player3d = AudioManager.play_3d("music_box", global_position + Vector3(0, 0.1, 0), 4.0, 1.0, 40.0, 5.0)
	say("La mélodie emplit la chambre... bien trop fort.", 3.5)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	figure.rotation.y += delta * 1.6
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = 3.0
		noise(20.0, "music")
	if not _scare_sent and _time > 7.0:
		_scare_sent = true
		Events.scare_trigger.emit("musicbox_playing", self)
	if _time >= PLAY_TIME:
		_playing = false
		GameManager.set_flag("musicbox_done")
		AudioManager.play_3d("safe_open", global_position, -6.0, 1.8, 10.0, 1.0)
		var tw := create_tween()
		tw.tween_property(drawer, "position:z", 0.12, 0.3)
		key_pickup.visible = true
		key_pickup.active = true
		say("Un déclic : un tiroir secret s'est ouvert sous la boîte.", 3.5)
