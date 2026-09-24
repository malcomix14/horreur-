extends Node
## AudioManager : chargement des sons (fichier res://audio/<nom>.ogg|wav|mp3 s'il existe,
## sinon synthèse procédurale mise en cache), pools de lecteurs 2D/3D, musique dynamique à couches.

const CACHE_DIR: String = "user://cache"
const SFX_CACHE_VERSION: int = 4
const POOL_2D: int = 10
const POOL_3D: int = 20
const MUSIC_LAYERS: Array[String] = ["drone", "tension", "chase", "wind"]

var ready_done: bool = false
var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _p2d_i: int = 0
var _p3d_i: int = 0
var _music: Dictionary = {}
var _music_level: Dictionary = {}
var _music_target: Dictionary = {}
var _root3d: Node3D
var _sfx_bus: int = -1
var _lowpass_idx: int = -1
var _reverb_idx: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_root3d = Node3D.new()
	_root3d.name = "Sounds3D"
	add_child(_root3d)
	for i: int in range(POOL_2D):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	for i: int in range(POOL_3D):
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.attenuation_filter_cutoff_hz = 6000.0
		p3.attenuation_filter_db = -18.0
		_root3d.add_child(p3)
		_pool3d.append(p3)
	for layer: String in MUSIC_LAYERS:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Ambience" if layer == "wind" else "Music"
		mp.volume_db = -80.0
		add_child(mp)
		_music[layer] = mp
		_music_level[layer] = 0.0
		_music_target[layer] = 0.0
	Settings.settings_changed.connect(_apply_volumes)
	_apply_volumes()


func _setup_buses() -> void:
	for bus_name: String in ["Music", "SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	_sfx_bus = AudioServer.get_bus_index("SFX")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.55
	rev.damping = 0.65
	rev.spread = 0.7
	rev.wet = 0.12
	rev.dry = 1.0
	AudioServer.add_bus_effect(_sfx_bus, rev)
	_reverb_idx = AudioServer.get_bus_effect_count(_sfx_bus) - 1
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 850.0
	AudioServer.add_bus_effect(_sfx_bus, lp)
	_lowpass_idx = AudioServer.get_bus_effect_count(_sfx_bus) - 1
	AudioServer.set_bus_effect_enabled(_sfx_bus, _lowpass_idx, false)


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, Settings.linear_to_db_safe(Settings.vol_master))
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	var amb := AudioServer.get_bus_index("Ambience")
	var ui := AudioServer.get_bus_index("UI")
	if music >= 0:
		AudioServer.set_bus_volume_db(music, Settings.linear_to_db_safe(Settings.vol_music))
	if sfx >= 0:
		AudioServer.set_bus_volume_db(sfx, Settings.linear_to_db_safe(Settings.vol_sfx))
		if _reverb_idx >= 0:
			AudioServer.set_bus_effect_enabled(sfx, _reverb_idx, Settings.quality >= Settings.Quality.MEDIUM)
	if amb >= 0:
		AudioServer.set_bus_volume_db(amb, Settings.linear_to_db_safe(Settings.vol_sfx))
	if ui >= 0:
		AudioServer.set_bus_volume_db(ui, Settings.linear_to_db_safe(Settings.vol_sfx))


# ============================================================ chargement

## Charge ou génère tous les sons. `progress` reçoit (ratio: float, texte: String).
func prepare(progress: Callable) -> void:
	if ready_done:
		return
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var names := SoundSynth.NAMES
	var total := names.size()
	var i := 0
	for snd: String in names:
		_streams[snd] = _load_stream(snd)
		i += 1
		if progress.is_valid():
			progress.call(float(i) / float(total), "Sons : %s" % snd)
		await get_tree().process_frame
	(_music["drone"] as AudioStreamPlayer).stream = get_stream("drone_loop")
	(_music["tension"] as AudioStreamPlayer).stream = get_stream("tension_loop")
	(_music["chase"] as AudioStreamPlayer).stream = get_stream("chase_loop")
	(_music["wind"] as AudioStreamPlayer).stream = get_stream("wind_loop")
	ready_done = true


func _load_stream(snd: String) -> AudioStream:
	var loop := snd in SoundSynth.LOOPS
	# 1) Fichier fourni par l'utilisateur (prioritaire).
	for ext: String in ["ogg", "wav", "mp3"]:
		var path := "res://audio/%s.%s" % [snd, ext]
		if ResourceLoader.exists(path):
			var res := load(path) as AudioStream
			if res != null:
				_set_loop(res, loop)
				return res
	# 2) Cache de la synthèse.
	var cache_path := "%s/sfx_%s_v%d.res" % [CACHE_DIR, snd, SFX_CACHE_VERSION]
	if FileAccess.file_exists(cache_path):
		var cached := ResourceLoader.load(cache_path) as AudioStream
		if cached != null:
			return cached
	# 3) Synthèse.
	var gen := SoundSynth.generate(snd)
	var err := ResourceSaver.save(gen, cache_path)
	if err != OK:
		push_warning("Cache audio impossible pour %s" % snd)
	return gen


func _set_loop(res: AudioStream, loop: bool) -> void:
	if res is AudioStreamOggVorbis:
		(res as AudioStreamOggVorbis).loop = loop
	elif res is AudioStreamMP3:
		(res as AudioStreamMP3).loop = loop
	elif res is AudioStreamWAV and loop:
		var w := res as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD


func get_stream(snd: String) -> AudioStream:
	if _streams.has(snd):
		return _streams[snd] as AudioStream
	if snd in SoundSynth.NAMES:
		var s := _load_stream(snd)
		_streams[snd] = s
		return s
	push_warning("Son inconnu : %s" % snd)
	return null


# ============================================================ lecture

func play_2d(snd: String, vol_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> AudioStreamPlayer:
	var s := get_stream(snd)
	if s == null:
		return null
	var p := _pick_2d()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()
	return p


func play_ui(snd: String, vol_db: float = -6.0) -> void:
	play_2d(snd, vol_db, 1.0, "UI")


func play_3d(snd: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, max_dist: float = 30.0, unit: float = 4.0) -> AudioStreamPlayer3D:
	var s := get_stream(snd)
	if s == null:
		return null
	var p := _pick_3d()
	p.stream = s
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.unit_size = unit
	p.play()
	return p


## Crée un émetteur 3D (souvent en boucle) attaché à un nœud du monde.
func make_emitter(snd: String, parent: Node3D, vol_db: float, unit: float, max_dist: float, autoplay: bool = true, bus: String = "SFX") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = get_stream(snd)
	p.volume_db = vol_db
	p.unit_size = unit
	p.max_distance = max_dist
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 5000.0
	p.attenuation_filter_db = -20.0
	parent.add_child(p)
	if autoplay and p.stream != null:
		p.play()
	return p


## Arrêt complet avant de quitter (évite les avertissements de fuite à la fermeture).
func shutdown() -> void:
	for layer: String in MUSIC_LAYERS:
		var mp := _music[layer] as AudioStreamPlayer
		mp.stop()
		mp.stream = null
	for p: AudioStreamPlayer in _pool2d:
		p.stop()
		p.stream = null
	for p3: AudioStreamPlayer3D in _pool3d:
		p3.stop()
		p3.stream = null
	_streams.clear()


func stop_all_3d() -> void:
	for p: AudioStreamPlayer3D in _pool3d:
		p.stop()


func _pick_2d() -> AudioStreamPlayer:
	for k: int in range(POOL_2D):
		var idx := (_p2d_i + k) % POOL_2D
		if not _pool2d[idx].playing:
			_p2d_i = (idx + 1) % POOL_2D
			return _pool2d[idx]
	var p := _pool2d[_p2d_i]
	_p2d_i = (_p2d_i + 1) % POOL_2D
	p.stop()
	return p


func _pick_3d() -> AudioStreamPlayer3D:
	for k: int in range(POOL_3D):
		var idx := (_p3d_i + k) % POOL_3D
		if not _pool3d[idx].playing:
			_p3d_i = (idx + 1) % POOL_3D
			return _pool3d[idx]
	var p := _pool3d[_p3d_i]
	_p3d_i = (_p3d_i + 1) % POOL_3D
	p.stop()
	return p


# ============================================================ effets globaux

## Étouffe les bruits du monde (joueur caché dans une armoire).
func set_muffled(on: bool) -> void:
	if _sfx_bus >= 0 and _lowpass_idx >= 0:
		AudioServer.set_bus_effect_enabled(_sfx_bus, _lowpass_idx, on)


# ============================================================ musique dynamique

## Niveaux cibles (0..1) des couches musicales.
func set_music_targets(drone: float, tension: float, chase: float, wind: float) -> void:
	_music_target["drone"] = drone
	_music_target["tension"] = tension
	_music_target["chase"] = chase
	_music_target["wind"] = wind


func start_music() -> void:
	if not ready_done:
		return
	for layer: String in MUSIC_LAYERS:
		var mp := _music[layer] as AudioStreamPlayer
		if mp.stream != null and not mp.playing:
			mp.play()


func stop_music(instant: bool = false) -> void:
	for layer: String in MUSIC_LAYERS:
		_music_target[layer] = 0.0
		if instant:
			_music_level[layer] = 0.0
			var mp := _music[layer] as AudioStreamPlayer
			mp.volume_db = -80.0
			mp.stop()


func _process(delta: float) -> void:
	for layer: String in MUSIC_LAYERS:
		var cur := float(_music_level[layer])
		var tgt := float(_music_target[layer])
		var rate := 1.8 if tgt > cur else 0.35
		if layer == "chase" and tgt < cur:
			rate = 0.25
		cur = move_toward(cur, tgt, rate * delta)
		_music_level[layer] = cur
		var mp := _music[layer] as AudioStreamPlayer
		mp.volume_db = Settings.linear_to_db_safe(cur)
