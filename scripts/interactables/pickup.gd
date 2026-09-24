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
	if item_id.begins_with("key_") or item_id == "register":
		glint = true


func _ready() -> void:
	if GameManager.is_collected(save_id):
		queue_free()
		return
	if glint:
		# Petit reflet discret pour aider à repérer les objets importants dans le noir.
		_halo = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.14, 0.14)
		_halo.mesh = q
		_halo.material_override = Assets.mat("halo")
		_halo.position = Vector3(0, 0.03, 0)
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_halo)


func _process(_delta: float) -> void:
	if _halo != null:
		var t := float(Time.get_ticks_msec()) * 0.001
		_halo.scale = Vector3.ONE * (0.6 + 0.4 * absf(sin(t * 1.7 + position.x)))
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
