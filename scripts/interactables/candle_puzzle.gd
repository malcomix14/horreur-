class_name CandlePuzzle
extends Node3D
## Énigme de la chapelle : allumer les trois cierges dans l'ordre du journal de Madeleine
## (le Père, puis la Mère, puis l'Enfant). Réussite : l'autel s'ouvre sur la clé d'os.

const ORDER: Array[String] = ["pere", "mere", "enfant"]

var solved: bool = false
var candles: Array[Candle] = []
var lid: Node3D
var key_pickup: Pickup
var _sequence: Array[String] = []
var _busy: bool = false


func setup_altar(altar_top_y: float) -> void:
	lid = Node3D.new()
	lid.position = Vector3(0, altar_top_y, 0)
	add_child(lid)
	var b := MeshBatcher.new()
	b.add_box("marble_white", Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), Vector3(0.5, 0.06, 0.34), Color(0.8, 0.8, 0.8))
	b.add_box("gold_frame", Transform3D(Basis.IDENTITY, Vector3(0, 0.065, 0)), Vector3(0.08, 0.01, 0.2))
	b.add_box("gold_frame", Transform3D(Basis.IDENTITY, Vector3(0, 0.065, 0)), Vector3(0.2, 0.01, 0.06))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build(func(k: String) -> Material: return Assets.mat(k))
	lid.add_child(mi)
	key_pickup = Pickup.new()
	key_pickup.setup("key_bone", "key_bone")
	key_pickup.checkpoint = true
	key_pickup.pickup_message = "Une clé taillée dans l'os, gravée d'un M. Madeleine..."
	add_child(key_pickup)
	key_pickup.position = Vector3(0, altar_top_y + 0.005, 0)
	key_pickup.active = false


func add_candle(c: Candle) -> void:
	candles.append(c)


func apply_saved_state() -> void:
	if GameManager.get_flag("candles_done"):
		solved = true
		for c: Candle in candles:
			c.set_lit(true)
		lid.position.x = 0.45
		key_pickup.active = true


func light_candle(c: Candle) -> void:
	if _busy or solved:
		return
	AudioManager.play_3d("match", c.global_position + Vector3(0, 1.4, 0), -2.0)
	c.set_lit(true)
	_sequence.append(c.role)
	var ok := true
	for i: int in range(_sequence.size()):
		if _sequence[i] != ORDER[i]:
			ok = false
	if not ok:
		_busy = true
		var _delay_tw9 := create_tween()
		_delay_tw9.tween_interval(1.0)
		_delay_tw9.tween_callback(_fail)
		return
	if _sequence.size() == ORDER.size():
		_solve()


func _fail() -> void:
	for c: Candle in candles:
		c.set_lit(false)
	_sequence.clear()
	_busy = false
	AudioManager.play_3d("candle_out", global_position + Vector3(0, 1.5, 0), 2.0)
	AudioManager.play_2d("whisper_2", -8.0)
	Events.noise_emitted.emit(global_position, 6.0, "chapel")
	Events.message_requested.emit("Les flammes s'éteignent d'un seul souffle. Ce n'était pas le bon ordre.", 4.0)


func _solve() -> void:
	solved = true
	GameManager.set_flag("candles_done")
	AudioManager.play_3d("lever", global_position + Vector3(0, 1.0, 0), 0.0, 0.7)
	AudioManager.play_2d("sting_low", -6.0)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(lid, "position:x", 0.45, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: key_pickup.active = true)
	Events.message_requested.emit("Un raclement de pierre : le dessus de l'autel glisse sur le côté.", 4.0)
