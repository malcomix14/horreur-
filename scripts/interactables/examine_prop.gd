class_name ExamineProp
extends Interactable
## Objet à examiner : affiche un message, peut déclencher un screamer et/ou un effet visuel
## propre (visage dans le miroir, portrait qui change, poupée qui tourne la tête, corps qui tombe...).
## JumpscareManager appelle play_scare_visual() pour synchroniser l'image avec le son.

var message: String = ""
var scare_trigger: String = ""
var one_shot_message: bool = false
var visual_kind: String = ""
var visual_nodes: Array[Node3D] = []
var extra_callback: Callable = Callable()
var _used: bool = false


func setup(p_prompt: String, p_message: String, detect_size: Vector3, detect_offset: Vector3 = Vector3.ZERO) -> void:
	prompt = p_prompt
	message = p_message
	add_detect_box(detect_size, detect_offset)


func interact(_player: Player) -> void:
	if message != "" and not (one_shot_message and _used):
		say(message, 4.0)
	_used = true
	if extra_callback.is_valid():
		extra_callback.call()
	if scare_trigger != "":
		var trig := scare_trigger
		scare_trigger = ""
		Events.scare_trigger.emit(trig, self)


## Effets visuels spécifiques à l'objet (appelé par JumpscareManager).
func play_scare_visual(effect: String, duration: float) -> void:
	match effect:
		"mirror_face":
			for n: Node3D in visual_nodes:
				n.visible = true
			var _delay_tw7 := create_tween()
			_delay_tw7.tween_interval(duration)
			_delay_tw7.tween_callback(func() -> void:
				for n2: Node3D in visual_nodes:
					n2.visible = false)
		"portrait":
			for n: Node3D in visual_nodes:
				if n is MeshInstance3D:
					(n as MeshInstance3D).material_override = Assets.mat("portrait_scare")
			var _delay_tw8 := create_tween()
			_delay_tw8.tween_interval(duration)
			_delay_tw8.tween_callback(func() -> void:
				for n2: Node3D in visual_nodes:
					if n2 is MeshInstance3D:
						(n2 as MeshInstance3D).material_override = null)
		"doll_turn":
			for n: Node3D in visual_nodes:
				var tw := create_tween()
				tw.tween_property(n, "rotation:y", n.rotation.y + PI * 0.85, 0.15).set_trans(Tween.TRANS_EXPO)
		"falling_body":
			for n: Node3D in visual_nodes:
				n.visible = true
				var start := n.transform
				var tw2 := create_tween()
				tw2.tween_property(n, "rotation:x", 1.35, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw2.tween_interval(duration)
				tw2.tween_callback(func() -> void:
					n.visible = false
					n.transform = start)
		"hand":
			for n: Node3D in visual_nodes:
				n.visible = true
				var base_pos := n.position
				var tw3 := create_tween()
				tw3.tween_property(n, "position:z", base_pos.z + 0.45, 0.12).set_trans(Tween.TRANS_EXPO)
				tw3.tween_interval(0.35)
				tw3.tween_property(n, "position:z", base_pos.z, 0.2)
				tw3.tween_callback(func() -> void: n.visible = false)
