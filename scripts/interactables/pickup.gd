class_name Pickup
extends Interactable
## Objet ramassable (clé, pile, fusible...). Disparaît s'il a déjà été ramassé (sauvegarde).

var item_id: String = ""
var amount: int = 1
var scare_trigger: String = ""
var checkpoint: bool = false
var glint: bool = false
var pickup_message: String = ""
var _halo: MeshInstance3D
var _halo_height: float = 0.05


func setup(p_item: String, p_save_id: String, p_amount: int = 1) -> void:
	item_id = p_item
	save_id = p_save_id
	amount = p_amount
	prompt = "Ramasser : %s" % GameManager.item_name(item_id)
	var mi := MeshInstance3D.new()
	mi.mesh = ItemVisuals.mesh_for(item_id)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var aabb := mi.mesh.get_aabb()
	var size := aabb.size + Vector3(0.12, 0.1, 0.12)
	add_detect_box(size, aabb.get_center())
	_halo_height = aabb.end.y + 0.02
	glint = true


func _ready() -> void:
	if GameManager.is_collected(save_id):
		queue_free()
		return
	if glint:
		# Reflet discret pour repérer les objets utiles dans la pénombre.
		_halo = add_glint(_halo_height)
		_halo.visible = active


func _process(_delta: float) -> void:
	if _halo != null:
		_halo.visible = active


func interact(_player: Player) -> void:
	GameManager.add_item(item_id, amount)
	GameManager.mark_collected(save_id)
	var snd := "key_pickup" if item_id.begins_with("key_") else "pickup"
	AudioManager.play_2d(snd, -2.0)
	if pickup_message != "":
		say(pickup_message, 4.0)
	if scare_trigger != "":
		Events.scare_trigger.emit(scare_trigger, self)
	if checkpoint:
		Events.checkpoint_requested.emit()
	queue_free()
