class_name InteractionSystem
extends RayCast3D
## Rayon d'interaction depuis la caméra : détecte l'objet visé, affiche l'invite « [E] ... ».

var player: Player
var current: Interactable = null
var _last_prompt: String = "__none__"


func _ready() -> void:
	target_position = Vector3(0, 0, -2.3)
	collision_mask = Layers.WORLD | Layers.DOORS | Layers.INTERACT
	collide_with_areas = false
	collide_with_bodies = true
	hit_from_inside = false
	if player != null:
		add_exception(player)


func _physics_process(_delta: float) -> void:
	if player == null or not GameManager.is_playing() or player.caught or not player.control_enabled and not player.is_hidden:
		current = null
		_set_prompt("")
		return
	if player.is_hidden:
		current = null
		_set_prompt("Sortir de la cachette")
		return
	var hit: Interactable = null
	if is_colliding():
		var col := get_collider()
		if col is Node:
			hit = Interactable.find_from(col as Node)
	if hit != null and (not hit.active or not hit.can_interact(player) or not hit.is_visible_in_tree()):
		hit = null
	current = hit
	_set_prompt(hit.get_prompt(player) if hit != null else "")


func _set_prompt(text: String) -> void:
	if text == _last_prompt:
		return
	_last_prompt = text
	Events.interact_prompt_changed.emit(text)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not GameManager.is_playing() or player == null or player.caught:
		return
	if player.is_hidden:
		player.exit_hiding()
		get_viewport().set_input_as_handled()
		return
	if current != null and is_instance_valid(current) and player.control_enabled:
		current.interact(player)
		get_viewport().set_input_as_handled()
